-- Dropamine 3.5.0 — UN seul travail pour la fenêtre de métier.
-- TRADE_SKILL_SHOW / UPDATE / LIST_UPDATE, CRAFT_SHOW / UPDATE et les OnShow
-- des cadres se regroupent (un drapeau, C_Timer.After ~0,25 s). La lecture des
-- recettes n'a lieu que si la clé (métier, nombre de recettes, rang) change,
-- par tranches d'environ 25, hors combat. L'OnUpdate du lot est retiré à la fin.
local _, ns = ...
local J = {}
ns.ProfJob = J
J.DELAY = 0.25
J.BATCH = 25
J.stats = { scans = 0, scanMs = 0, lastMs = 0, skipped = 0, batches = 0, jobs = 0 }
J.cache = {}

local function Ms()
  if type(_G.debugprofilestop) == "function" then
    local ok, v = pcall(_G.debugprofilestop)
    if ok and type(v) == "number" then return v end
  end
  if type(_G.GetTime) == "function" then
    local ok, v = pcall(_G.GetTime)
    if ok and type(v) == "number" then return v * 1000 end
  end
  return 0
end
local function InCombat()
  return ns.InCombat and ns.InCombat() and true or false
end

function J.Schedule(why)
  if why then J._why = why end
  if J._armed then return end
  J._armed = true
  local gen = (J._gen or 0) + 1
  J._gen = gen
  local function go()
    if J._gen ~= gen then return end
    J._armed = false
    J._go = nil
    J.Run()
  end
  J._go = go
  if type(_G.C_Timer) == "table" and type(_G.C_Timer.After) == "function" then
    _G.C_Timer.After(J.DELAY, go)
  else
    go()
  end
end

function J.StopPump()
  J._pumping = false
  if J._frame and J._frame.SetScript then pcall(J._frame.SetScript, J._frame, "OnUpdate", nil) end
end

function J.Frame()
  if J._frame then return J._frame end
  if type(_G.CreateFrame) ~= "function" then return nil end
  local ok, f = pcall(_G.CreateFrame, "Frame")
  if ok then J._frame = f end
  return J._frame
end

function J.Identity()
  local A = ns.Activity
  local craftShown = type(_G.CraftFrame) == "table" and _G.CraftFrame.IsShown and _G.CraftFrame:IsShown()
  if (A and A._craftOpen) or craftShown then
    if ns.Craft and ns.Craft.CraftIdentity and type(_G.GetNumCrafts) == "function" then
      local id, n, rank, name = ns.Craft.CraftIdentity()
      if id or (n and n > 0) then return id, n or 0, rank or 0, "craft", name end
    end
  end
  if ns.Scanner and ns.Scanner.TradeIdentity then
    local id, n, rank, name = ns.Scanner.TradeIdentity()
    return id, n or 0, rank or 0, "trade", name
  end
  return nil, 0, 0, nil, nil
end

function J.Finish(st)
  local ms = Ms() - (st.t0 or 0)
  if ms < 0 then ms = 0 end
  J.stats.scans = (J.stats.scans or 0) + 1
  J.stats.lastMs = ms
  J.stats.scanMs = (J.stats.scanMs or 0) + ms
  J.cache[st.id] = st.key
  local id, n
  if st.kind == "craft" and ns.Craft and ns.Craft.Store then
    if #st.list > 0 then id, n = ns.Craft.Store(st.id, st.list, "GetCraftInfo") end
  elseif ns.Scanner and ns.Scanner.CommitTradeList then
    if ns.Scanner.TradeFiltersPartial and ns.Scanner.TradeFiltersPartial() then st.partial = true end
    id, n = ns.Scanner.CommitTradeList(st.list, st.partial, st.name, "ProfJob", "GetTradeSkillInfo")
  end
  if ns.Scanner then
    ns.Scanner.lastRead = tostring(id) .. " : " .. tostring(n)
    ns.Scanner.reads = (ns.Scanner.reads or 0) + 1
  end
  if ns.Activity and ns.Activity.Refresh then pcall(ns.Activity.Refresh, "scan") end
end

function J.StartPump()
  local f = J.Frame()
  if not f or not f.SetScript then
    while J._scan do J.PumpBody() end
    return
  end
  if J._pumping then return end
  J._pumping = true
  f:SetScript("OnUpdate", function(fr)
    fr:SetScript("OnUpdate", nil)
    J._pumping = false
    J.PumpBody()
  end)
end

function J.PumpBody()
  local st = J._scan
  if not st then J.StopPump() return end
  if InCombat() then
    J._combat = true
    J._scan = nil
    J.StopPump()
    return
  end
  local last = math.min(st.n, st.i + J.BATCH - 1)
  J.stats.batches = (J.stats.batches or 0) + 1
  if st.kind == "craft" and ns.Craft and ns.Craft.ReadCraftRange then
    ns.Craft.ReadCraftRange(st.i, last, st.list)
  elseif ns.Scanner and ns.Scanner.ReadTradeRange then
    local _, partial = ns.Scanner.ReadTradeRange(st.i, last, st.list)
    if partial then st.partial = true end
  end
  st.i = last + 1
  if st.i <= st.n then J.StartPump() return end
  J.Finish(st)
  J._scan = nil
  J.StopPump()
end

function J.Begin(id, n, rank, kind, key, name)
  J.StopPump()
  J._scan = { id = id, n = n, i = 1, rank = rank, kind = kind, key = key, name = name, list = {}, partial = false, t0 = Ms() }
  J.PumpBody()
end

function J.Run()
  if InCombat() then J._combat = true return end
  J.stats.jobs = (J.stats.jobs or 0) + 1
  if ns.Style and ns.Style.Probe then pcall(ns.Style.Probe, false) end
  local A = ns.Activity
  if A and A.OnWindow then pcall(A.OnWindow, A._jobEv or J._why or "job") end
  local id, n, rank, kind, name = J.Identity()
  if not id or not n or n <= 0 then
    -- une fois : le titre de la fenêtre n'est pas encore rempli. Une liste vide
    -- connue (métier déjà nommé) ne relance pas de lecture.
    if not id and not J._retried and A and A._apiOpen then
      J._retried = true
      J.Schedule("retry")
    end
    return
  end
  J._retried = nil
  local key = tostring(id) .. ":" .. tostring(n) .. ":" .. tostring(rank)
  if J.cache[id] == key then
    J.stats.skipped = (J.stats.skipped or 0) + 1
    return
  end
  J.Begin(id, n, rank, kind, key, name)
end

-- Tests : exécute le travail en attente et finit les tranches. Invalide le
-- C_Timer déjà posé pour qu'un flush ultérieur ne relance pas le scan.
function J.Flush()
  if J._armed then
    J._gen = (J._gen or 0) + 1
    J._armed = false
    J._go = nil
    J.Run()
  end
  local guard = 0
  while J._scan and guard < 80 do
    J.PumpBody()
    guard = guard + 1
  end
  J.StopPump()
end

if ns.On then
  ns.On("PLAYER_REGEN_ENABLED", function()
    if J._combat then J._combat = nil J.Schedule("fin de combat") end
  end)
end

if ns.Gather and ns.Gather.PerfLines then
  local base = ns.Gather.PerfLines
  function ns.Gather.PerfLines()
    local out = base()
    local s = J.stats
    local avg = (s.scans or 0) > 0 and (s.scanMs / s.scans) or 0
    out[#out + 1] = string.format("perf : métiers %d scans, %.1f ms/scan (dernier %.1f ms), %d ignorés (cache), %d lots",
      s.scans or 0, avg, s.lastMs or 0, s.skipped or 0, s.batches or 0)
    return out
  end
end
