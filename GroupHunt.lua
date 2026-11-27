-- Dropamine — chasse partagée avec le groupe (3.13.0).
-- Les addons Dropamine d'un même groupe s'échangent les objets recherchés (numéros seulement, canal d'addon
-- invisible) : au jet de groupe, chacun voit qui chasse l'objet (« Recherché par Bob »), et l'infobulle de l'objet
-- le dit aussi. Rien n'est envoyé hors du groupe ; option « huntShare » pour couper.
local ADDON, ns = ...
local Tr = ns.L or setmetatable({}, { __index = function(_, k) return k end })
local GH = {}
ns.GroupHunt = GH
GH.PREFIX = "DROPAMINE"
GH.lists = {}          -- nom court → { ids = { [id] = true }, at = secondes }
GH.stats = { sent = 0, got = 0, asked = 0 }

local function N(v) return (ns.N and ns.N(v)) or tonumber(v) end
local function Now() return (type(_G.GetTime) == "function" and _G.GetTime()) or os.time() end
local function Short(name) return type(name) == "string" and (name:match("^([^%-]+)") or name) or nil end
local function Me() local ok, n = pcall(_G.UnitName or function() end, "player") return ok and n or nil end
function GH.On() return not (ns.Opt and ns.Opt("huntShare") == false) and not (ns.Hunt and ns.Hunt.On and not ns.Hunt.On()) end

local function CI() local c = rawget(_G, "C_ChatInfo") return type(c) == "table" and c or nil end
local function Channel()
  if type(_G.IsInGroup) == "function" then
    local cat = rawget(_G, "LE_PARTY_CATEGORY_INSTANCE")
    if cat and _G.IsInGroup(cat) then return "INSTANCE_CHAT" end
    if not _G.IsInGroup() then return nil end
  end
  if type(_G.IsInRaid) == "function" and _G.IsInRaid() then return "RAID" end
  return "PARTY"
end

-- message : « H1:<numéros en base 36, séparés par des points> » (objets pas encore trouvés), 250 caractères au plus
function GH.Encode()
  local H = ns.Hunt
  local ids = {}
  local ok, list = pcall(H and H.List or function() return {} end)
  for _, it in ipairs(ok and list or {}) do
    local id = N(it.id)
    if id and id > 0 and (N(it.drops) or 0) == 0 then
      local s, n = "", id
      repeat local d = n % 36 s = string.sub("0123456789abcdefghijklmnopqrstuvwxyz", d + 1, d + 1) .. s n = math.floor(n / 36) until n == 0
      ids[#ids + 1] = s
    end
  end
  local msg = "H1:" .. table.concat(ids, ".")
  if #msg > 250 then msg = msg:sub(1, 250):gsub("%.[^%.]*$", "") end
  return msg
end
function GH.Decode(msg)
  local body = type(msg) == "string" and msg:match("^H1:([%w%.]*)$")
  if not body then return nil end
  local set = {}
  for tok in body:gmatch("[%w]+") do local id = tonumber(tok, 36) if id and id > 0 then set[id] = true end end
  return set
end

GH._lastSent = 0
function GH.Send(force)
  if not GH.On() then return false end
  local ch, c = Channel(), CI()
  if not (ch and c and type(c.SendAddonMessage) == "function") then return false end
  if not force and Now() - GH._lastSent < 10 then return false end
  GH._lastSent = Now()
  local ok = pcall(c.SendAddonMessage, GH.PREFIX, GH.Encode(), ch)
  if ok then GH.stats.sent = GH.stats.sent + 1 end
  return ok
end
function GH.Ask()
  local ch, c = Channel(), CI()
  if not (GH.On() and ch and c and type(c.SendAddonMessage) == "function") then return false end
  GH.stats.asked = GH.stats.asked + 1
  return pcall(c.SendAddonMessage, GH.PREFIX, "Q", ch)
end
function GH.OnMessage(prefix, msg, _, sender)
  if prefix ~= GH.PREFIX then return end
  local who = Short(sender)
  if not who or who == Me() then return end
  if msg == "Q" then GH.Send(true) return end
  local set = GH.Decode(msg)
  if set then GH.lists[who] = { ids = set, at = Now() } GH.stats.got = GH.stats.got + 1 end
end
-- membres partis : leurs listes sont oubliées
function GH.Prune()
  local keep = {}
  local n = type(_G.GetNumGroupMembers) == "function" and (N(_G.GetNumGroupMembers()) or 0) or 0
  local raid = type(_G.IsInRaid) == "function" and _G.IsInRaid()
  for i = 1, n do
    local unit = raid and ("raid" .. i) or (i == 1 and "player" or ("party" .. (i - 1)))
    local ok, nm = pcall(_G.UnitName, unit)
    if ok and nm then keep[Short(nm)] = true end
  end
  for who in pairs(GH.lists) do if not keep[who] then GH.lists[who] = nil end end
end
-- qui chasse cet objet dans le groupe (noms triés)
function GH.Hunters(id)
  id = N(id)
  local out = {}
  if not (id and GH.On()) then return out end
  for who, l in pairs(GH.lists) do if l.ids[id] then out[#out + 1] = who end end
  table.sort(out)
  return out
end
function GH.Line(id)
  local h = GH.Hunters(id)
  if #h == 0 then return nil end
  return Tr["Recherché dans ton groupe par : "] .. table.concat(h, ", ")
end

-- jet de groupe : une ligne dans le chat (une fois par jet) quand quelqu'un d'autre chasse l'objet
GH._rolled = {}
function GH.OnRoll(rid)
  if not (GH.On() and rid) or GH._rolled[rid] then return end
  local ok, link = pcall(_G.GetLootRollItemLink or function() end, rid)
  local id = ok and type(link) == "string" and tonumber(link:match("item:(%d+)"))
  local line = id and GH.Line(id)
  if not line then return end
  GH._rolled[rid] = true
  if ns.Print then ns.Print(tostring(link) .. " — " .. line) end
end
-- infobulle d'objet
function GH.HookTooltip()
  if GH._tip then return end
  GH._tip = true
  local TDP, E = rawget(_G, "TooltipDataProcessor"), rawget(_G, "Enum")
  local function add(tt, id)
    local line = id and GH.Line(id)
    if line and tt and tt.AddLine then tt:AddLine(line, 0.95, 0.75, 0.3, true) end
  end
  if type(TDP) == "table" and type(TDP.AddTooltipPostCall) == "function" and E and E.TooltipDataType then
    pcall(TDP.AddTooltipPostCall, E.TooltipDataType.Item, function(tt, data) add(tt, data and N(data.id)) end)
  elseif _G.GameTooltip and _G.GameTooltip.HookScript then
    pcall(_G.GameTooltip.HookScript, _G.GameTooltip, "OnTooltipSetItem", function(tt)
      local _, link = tt:GetItem() add(tt, link and tonumber(link:match("item:(%d+)")))
    end)
  end
end

-- option « huntShare » : Réglages > Chasse (Options.lua)

if ns.On then
  local c = CI()
  if c and type(c.RegisterAddonMessagePrefix) == "function" then pcall(c.RegisterAddonMessagePrefix, GH.PREFIX) end
  local function later(fn, d) if _G.C_Timer and _G.C_Timer.After then _G.C_Timer.After(d or 2, fn) else fn() end end
  ns.On("CHAT_MSG_ADDON", function(_, ...) pcall(GH.OnMessage, ...) end)
  ns.On("GROUP_ROSTER_UPDATE", function()
    later(function() pcall(GH.Prune) if not GH._asked then GH._asked = true pcall(GH.Ask) end pcall(GH.Send) end)
  end)
  ns.On("GROUP_LEFT", function() GH.lists = {} GH._asked = nil end)
  ns.On("PLAYER_ENTERING_WORLD", function() later(function() pcall(GH.Send, true) end, 4) end)
  ns.On("START_LOOT_ROLL", function(_, rid) pcall(GH.OnRoll, rid) end)
  ns.On("PLAYER_LOGIN", function() pcall(GH.HookTooltip) end)
end
