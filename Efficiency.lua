-- Dropamine 3.6.3 : efficacité — part de temps actif, mesures normalisées.
-- Le score est la part de temps actif (combat / récolte / artisanat) sur le
-- temps de session, jamais un rythme XP/h ou points/h. Les rythmes XP sont
-- exprimés en % du niveau courant par heure (XP / UnitXPMax) et en temps
-- restant pour le niveau ; au niveau maximum, ces chiffres XP sont masqués.
-- Métiers : tentatives et paliers mesurés, par couleur de difficulté.
-- Armes : compétence relative au plafond (5 × niveau). Rien n'est inventé.
local ADDON, ns = ...
local Tr = ns.L
local E = {}
ns.Efficiency = E

E.MIN_SECS = 60
E.HOUR = 3600
E.DEAD = { "death", "loading", "flight", "transport", "afk" }
E.ACTIVE = { "combat", "gather", "craft" }
E.ALL = { "combat", "gather", "craft", "death", "loading", "flight", "transport", "afk", "other" }
E.LABEL = {
  combat = "Combat", gather = "Récolte", craft = "Artisanat",
  death = "Mort", loading = "Chargement", flight = "Vol",
  transport = "Trajet", afk = "Absence", other = "Autre",
}
E.DIFF = { optimal = "orange", medium = "jaune", easy = "vert", trivial = "gris" }

local function N(v) return (ns.N and ns.N(v)) or tonumber(v) end
local function Wall() return (type(_G.time) == "function" and _G.time()) or 0 end
local function Now()
  if type(_G.GetTime) == "function" then
    local ok, t = pcall(_G.GetTime)
    if ok and N(t) then return N(t) end
  end
  return Wall()
end
-- 3.7.1 : sans table temporaire (retours passés tels quels).
local function CallRet(ok, ...)
  if not ok then return nil end
  return ...
end
local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  return CallRet(pcall(fn, ...))
end
local function Fold(s)
  if ns.Fold then return ns.Fold(s) end
  return type(s) == "string" and s:lower() or ""
end

local function EmptySecs()
  local t = {}
  for i = 1, #E.ALL do t[E.ALL[i]] = 0 end
  return t
end

local function EmptyAttempts()
  return { att = 0, up = 0, optimal = 0, medium = 0, easy = 0, trivial = 0, unknown = 0 }
end

------------------------------------------------------------------------------
-- Stockage (par personnage, session + jours dans l'historique existant)
------------------------------------------------------------------------------
local function BindEff(s)
  if type(s) ~= "table" then return nil end
  s.eff = s.eff or {}
  local e = s.eff
  e.secs = e.secs or EmptySecs()
  for i = 1, #E.ALL do if not N(e.secs[E.ALL[i]]) then e.secs[E.ALL[i]] = 0 end end
  e.deaths = e.deaths or { n = 0, secs = 0 }
  e.bagMiss = e.bagMiss or 0
  e.attempts = e.attempts or {}
  e.fishing = e.fishing or {}
  e.xpFrac = e.xpFrac or 0
  e.moneyNet = e.moneyNet or 0
  e.moneyIn = e.moneyIn or 0
  e.moneyOut = e.moneyOut or 0
  e.moneyByZone = e.moneyByZone or {}
  e.lootCoin = e.lootCoin or 0
  e.lootVendor = e.lootVendor or 0
  e.lootValue = e.lootValue or ((N(e.lootCoin) or 0) + (N(e.lootVendor) or 0))
  e.lootByZone = e.lootByZone or {}
  e.zoneSecs = e.zoneSecs or {}
  e.xpFracByZone = e.xpFracByZone or {}
  return e, s
end

function E.Sess()
  if E._sessOverride then return E._sessOverride, E._sessOverrideSrc end
  local P = ns.Progress
  if not (P and P.Session) then
    E._orphan = E._orphan or { secs = EmptySecs(), deaths = { n = 0, secs = 0 }, bagMiss = 0, attempts = {}, fishing = {}, lastTick = nil, openDeath = nil }
    return E._orphan
  end
  local s = P.Session()
  return BindEff(s)
end

function E.Day(day)
  local P = ns.Progress
  if not (P and P.DayEntry) then return nil end
  local h = P.DayEntry(day)
  h.eff = h.eff or {}
  local e = h.eff
  e.secs = e.secs or EmptySecs()
  for i = 1, #E.ALL do if not N(e.secs[E.ALL[i]]) then e.secs[E.ALL[i]] = 0 end end
  e.deaths = e.deaths or { n = 0, secs = 0 }
  e.bagMiss = e.bagMiss or 0
  e.attempts = e.attempts or {}
  e.fishing = e.fishing or {}
  e.xpFrac = e.xpFrac or N(h.xpFrac) or 0
  e.moneyNet = e.moneyNet or 0
  e.moneyIn = e.moneyIn or 0
  e.moneyOut = e.moneyOut or 0
  e.moneyByZone = e.moneyByZone or {}
  e.lootCoin = e.lootCoin or 0
  e.lootVendor = e.lootVendor or 0
  e.lootValue = e.lootValue or ((N(e.lootCoin) or 0) + (N(e.lootVendor) or 0))
  e.lootByZone = e.lootByZone or {}
  e.zoneSecs = e.zoneSecs or {}
  e.xpFracByZone = e.xpFracByZone or {}
  return e, h
end

local function AddSecs(dst, src, k, dt)
  dst[k] = (N(dst[k]) or 0) + dt
  if src then src[k] = (N(src[k]) or 0) + dt end
end

------------------------------------------------------------------------------
-- Détection du seau courant (un seul à la fois, priorité temps mort > actif)
------------------------------------------------------------------------------
function E.LiveCraft()
  if E._sim and E._sim.craft then return true end
  local name = Call(_G.UnitCastingInfo, "player") or Call(_G.UnitChannelInfo, "player")
  if type(name) == "string" then
    -- une fabrication en cours : la fenêtre de métier est typiquement ouverte
    local tf = _G.TradeSkillFrame or _G.CraftFrame
    if tf and type(tf.IsShown) == "function" and Call(tf.IsShown, tf) then return true end
  end
  if E._craftUntil and Now() <= E._craftUntil then return true end
  return false
end

function E.LiveGather()
  if E._sim and E._sim.gather then return true end
  local S = ns.Slot
  if S and S.LiveFishing and S.LiveFishing() then return true end
  if E._gatherUntil and Now() <= E._gatherUntil then return true end
  local name, _, _, icon = Call(_G.UnitChannelInfo, "player")
  if not name then name, _, _, icon = Call(_G.UnitCastingInfo, "player") end
  local n = Fold(name) .. " " .. Fold(icon)
  if n:find("herb", 1, true) or n:find("mine", 1, true) or n:find("skin", 1, true)
    or n:find("ore", 1, true) or n:find("pelt", 1, true)
    or n:find("herbe", 1, true) or n:find("minage", 1, true) or n:find("depec", 1, true)
    or n:find("peche", 1, true) or n:find("fish", 1, true) then
    return true
  end
  return false
end

function E.CurrentBucket()
  if E._sim and E._sim.bucket then return E._sim.bucket end
  local S, F = ns.Slot, ns.Flight
  if S and S.LiveDeath and S.LiveDeath() then return "death" end
  if F and F.SafetyPause and F.SafetyPause() then return "loading" end
  if F and F.OnTaxi and F.OnTaxi() then return "flight" end
  if F and F.OnTransport and F.OnTransport() then return "transport" end
  if S and S.LiveAfk and S.LiveAfk() then return "afk" end
  if S and S.LiveCombat and S.LiveCombat() then return "combat" end
  if E.LiveGather() then return "gather" end
  if E.LiveCraft() then return "craft" end
  return "other"
end

function E.OpenDeath(now)
  local e = E.Sess()
  if not e.openDeath then e.openDeath = now or Now() end
end

function E.CloseDeath(now)
  local e = E.Sess()
  local t0 = e.openDeath
  e.openDeath = nil
  if not t0 then return end
  now = now or Now()
  local dt = now - t0
  if dt < 0 or dt > 3600 then return end
  e.deaths.n = (N(e.deaths.n) or 0) + 1
  e.deaths.secs = (N(e.deaths.secs) or 0) + dt
  e.deaths.last = dt
  local d = E.Day()
  if d then
    d.deaths.n = (N(d.deaths.n) or 0) + 1
    d.deaths.secs = (N(d.deaths.secs) or 0) + dt
  end
end

function E.Pulse(why)
  local now = Now()
  local e = E.Sess()
  local bucket = E.CurrentBucket()
  if bucket == "death" then
    if not e.openDeath then E.OpenDeath(now) end
  elseif e.openDeath then
    E.CloseDeath(now)
  end
  local last = N(e.lastTick)
  e.lastTick = now
  e.lastBucket = bucket
  if not last then return bucket end
  local dt = now - last
  if dt <= 0 then return bucket end
  -- les longs chargements / vols comptent ; un trou > 15 min hors pause est ignoré
  local cap = (bucket == "loading" or bucket == "flight" or bucket == "transport" or bucket == "death") and 900 or 120
  if dt > cap then dt = cap end
  AddSecs(e.secs, nil, bucket, dt)
  local d = E.Day()
  if d then AddSecs(d.secs, nil, bucket, dt) end
  local P = ns.Progress
  local zone = P and P.Zone and P.Zone() or nil
  if zone then
    e.zoneSecs = e.zoneSecs or {}
    e.zoneSecs[zone] = (N(e.zoneSecs[zone]) or 0) + dt
    local d = E.Day()
    if d then
      d.zoneSecs = d.zoneSecs or {}
      d.zoneSecs[zone] = (N(d.zoneSecs[zone]) or 0) + dt
    end
  end
  if bucket == "gather" then
    local S = ns.Slot
    if S and S.LiveFishing and S.LiveFishing() then
      E.AccountFishing(dt)
    end
  end
  return bucket
end

function E.AccountFishing(dt)
  local P = ns.Progress
  local zone = "?"
  if P and P.Zone then zone = P.Zone() or "?" end
  local e = E.Sess()
  local z = e.fishing[zone]
  if not z then z = { n = 0, secs = 0 } e.fishing[zone] = z end
  z.secs = (N(z.secs) or 0) + dt
  local d = E.Day()
  if d then
    d.fishing[zone] = d.fishing[zone] or { n = 0, secs = 0 }
    d.fishing[zone].secs = (N(d.fishing[zone].secs) or 0) + dt
  end
end

function E.NoteBagMiss()
  local now = Now()
  if E._bagMissAt and now - E._bagMissAt < 0.6 then return false end
  E._bagMissAt = now
  local e = E.Sess()
  e.bagMiss = (N(e.bagMiss) or 0) + 1
  local d = E.Day()
  if d then d.bagMiss = (N(d.bagMiss) or 0) + 1 end
  return true
end

function E.NoteXpFrac(frac)
  frac = N(frac)
  if not frac or frac <= 0 then return end
  local e = E.Sess()
  e.xpFrac = (N(e.xpFrac) or 0) + frac
  local P = ns.Progress
  local zone = P and P.Zone and P.Zone() or nil
  if zone then
    e.xpFracByZone = e.xpFracByZone or {}
    e.xpFracByZone[zone] = (N(e.xpFracByZone[zone]) or 0) + frac
  end
  local d = E.Day()
  if d then
    d.xpFrac = (N(d.xpFrac) or 0) + frac
    if zone then
      d.xpFracByZone = d.xpFracByZone or {}
      d.xpFracByZone[zone] = (N(d.xpFracByZone[zone]) or 0) + frac
    end
  end
end

function E.AttOf(tab, skill)
  tab = tab or {}
  local a = tab[skill]
  if not a then a = EmptyAttempts() tab[skill] = a end
  return a
end

function E.NoteAttempt(skill, color, skillup)
  if not skill then return end
  color = color or "unknown"
  if color == "orange" then color = "optimal"
  elseif color == "yellow" or color == "jaune" then color = "medium"
  elseif color == "green" or color == "vert" then color = "easy"
  elseif color == "grey" or color == "gray" or color == "gris" then color = "trivial"
  end
  local e = E.Sess()
  local a = E.AttOf(e.attempts, skill)
  a.att = (N(a.att) or 0) + 1
  if a[color] ~= nil then a[color] = (N(a[color]) or 0) + 1 else a.unknown = (N(a.unknown) or 0) + 1 end
  if skillup then a.up = (N(a.up) or 0) + (N(skillup) or 1) end
  local d = E.Day()
  if d then
    local b = E.AttOf(d.attempts, skill)
    b.att = (N(b.att) or 0) + 1
    if b[color] ~= nil then b[color] = (N(b[color]) or 0) + 1 else b.unknown = (N(b.unknown) or 0) + 1 end
    if skillup then b.up = (N(b.up) or 0) + (N(skillup) or 1) end
  end
  if skill == "fishing" then E._craftUntil = nil E._gatherUntil = Now() + 3
  elseif ns.Progress and ns.Progress.GATHER and ns.Progress.GATHER[skill] then
    E._gatherUntil = Now() + 4
  else
    E._craftUntil = Now() + 3
  end
end

function E.NoteSkillUp(skill, delta)
  if not skill then return end
  delta = N(delta) or 1
  local e = E.Sess()
  local a = E.AttOf(e.attempts, skill)
  a.up = (N(a.up) or 0) + delta
  local d = E.Day()
  if d then
    local b = E.AttOf(d.attempts, skill)
    b.up = (N(b.up) or 0) + delta
  end
end

function E.CurrentCraftDiff()
  local idx = Call(_G.GetTradeSkillSelectionIndex)
  if idx then
    local name, kind = Call(_G.GetTradeSkillInfo, idx)
    if type(kind) == "string" then return Fold(kind), name end
  end
  idx = Call(_G.GetCraftSelectionIndex)
  if idx then
    local name, kind = Call(_G.GetCraftDisplaySkillLine) -- may not be diff
    local n, typ = Call(_G.GetCraftInfo, idx)
    if typ then return Fold(typ), n or name end
  end
  return nil
end

------------------------------------------------------------------------------
-- Agrégats et rapports (session / 7 j / 30 j) — uniquement des mesures
------------------------------------------------------------------------------
local function SumSecs(list)
  local out = EmptySecs()
  local deathsN, deathsS, bag, frac = 0, 0, 0, 0
  local moneyNet, moneyIn, moneyOut = 0, 0, 0
  local attempts, fishing, moneyByZone, zoneSecs, xpFracByZone = {}, {}, {}, {}, {}
  for i = 1, #list do
    local e = list[i]
    if e then
      for j = 1, #E.ALL do
        local k = E.ALL[j]
        out[k] = (out[k] or 0) + (N(e.secs and e.secs[k]) or 0)
      end
      deathsN = deathsN + (N(e.deaths and e.deaths.n) or 0)
      deathsS = deathsS + (N(e.deaths and e.deaths.secs) or 0)
      bag = bag + (N(e.bagMiss) or 0)
      frac = frac + (N(e.xpFrac) or 0)
      local lv = N(e.lootValue)
      if lv == nil and ((N(e.lootCoin) or 0) + (N(e.lootVendor) or 0)) > 0 then
        lv = (N(e.lootCoin) or 0) + (N(e.lootVendor) or 0)
      end
      -- uniquement la valeur marchand mesurée (pas un reliquat GetMoney)
      if lv then moneyNet = moneyNet + lv end
      moneyIn = moneyIn + (N(e.lootCoin) or 0)
      moneyOut = moneyOut + (N(e.lootVendor) or 0)
      for z, v in pairs(e.lootByZone or e.moneyByZone or {}) do
        local t = moneyByZone[z] or { net = 0, inn = 0, out = 0 }
        if type(v) == "table" then
          local val = N(v.value) or N(v.net) or ((N(v.coin) or 0) + (N(v.vendor) or 0))
          t.net = t.net + (val or 0)
          t.inn = t.inn + (N(v.inn) or N(v.coin) or val or 0)
          t.out = t.out + (N(v.out) or 0)
        else
          t.net = t.net + (N(v) or 0)
        end
        moneyByZone[z] = t
      end
      for z, v in pairs(e.zoneSecs or {}) do
        zoneSecs[z] = (zoneSecs[z] or 0) + (N(v) or 0)
      end
      for z, v in pairs(e.xpFracByZone or {}) do
        xpFracByZone[z] = (xpFracByZone[z] or 0) + (N(v) or 0)
      end
      for skill, a in pairs(e.attempts or {}) do
        local t = E.AttOf(attempts, skill)
        t.att = t.att + (N(a.att) or 0)
        t.up = t.up + (N(a.up) or 0)
        for _, c in ipairs({ "optimal", "medium", "easy", "trivial", "unknown" }) do
          t[c] = t[c] + (N(a[c]) or 0)
        end
      end
      for zone, z in pairs(e.fishing or {}) do
        local t = fishing[zone] or { n = 0, secs = 0 }
        t.n = t.n + (N(z.n) or 0)
        t.secs = t.secs + (N(z.secs) or 0)
        fishing[zone] = t
      end
    end
  end
  return { secs = out, deaths = { n = deathsN, secs = deathsS }, bagMiss = bag, xpFrac = frac, attempts = attempts, fishing = fishing,
    moneyNet = moneyNet, moneyIn = moneyIn, moneyOut = moneyOut, moneyByZone = moneyByZone, zoneSecs = zoneSecs, xpFracByZone = xpFracByZone }
end

function E.Days(n)
  local P = ns.Progress
  if not (P and P.Today and P.DayOffset and P.DayEntry) then return {} end
  local out = {}
  for i = 0, (n or 7) - 1 do
    local key = P.DayOffset(P.Today(), -i)
    if key then
      local e = E.Day(key)
      if e then out[#out + 1] = e end
    end
  end
  return out
end

function E.Total(secs)
  local t = 0
  for i = 1, #E.ALL do t = t + (N(secs[E.ALL[i]]) or 0) end
  return t
end

function E.SumKeys(secs, keys)
  local t = 0
  for i = 1, #keys do t = t + (N(secs[keys[i]]) or 0) end
  return t
end

function E.AtMaxLevel()
  local lvl = N(ns.GetPlayerLevel and ns.GetPlayerLevel())
  local cap = N(ns.GetLevelCap and ns.GetLevelCap()) or 60
  return lvl and cap and lvl >= cap
end

function E.WeaponCap(level)
  level = N(level) or N(ns.GetPlayerLevel and ns.GetPlayerLevel())
  if not level then return nil end
  return level * 5
end

-- Score = part de temps actif sur le temps mesuré (indépendant du niveau).
function E.Score(secs)
  local total = E.Total(secs)
  if total < E.MIN_SECS then return nil, total end
  local active = E.SumKeys(secs, E.ACTIVE)
  return active / total, total
end

function E.Tip(rep)
  if not rep or not rep.secs then return nil end
  local total = E.Total(rep.secs)
  if total < E.MIN_SECS then return nil end
  local bestK, bestV = nil, 0
  for i = 1, #E.DEAD do
    local k = E.DEAD[i]
    local v = N(rep.secs[k]) or 0
    if v > bestV then bestK, bestV = k, v end
  end
  if not bestK or bestV <= 0 then return nil end
  local pct = math.floor(bestV / total * 100 + 0.5)
  if pct < 1 then return nil end
  local phrases = {
    death = "mort", loading = "chargement", flight = "vol",
    transport = "trajet", afk = "absence",
  }
  local phrase = phrases[bestK] or (E.LABEL[bestK] or bestK)
  return string.format(Tr["%d %% du temps en %s"], pct, Tr[phrase] or phrase)
end

local function RatePerHour(n, secs)
  secs = N(secs) or 0
  n = N(n) or 0
  if secs < E.MIN_SECS then return nil end
  return n / (secs / E.HOUR)
end

function E.SpotRanks()
  local P = ns.Progress
  if not (P and P.Spots) then return {} end
  local out = {}
  for skill in pairs(P.GATHER or {}) do
    local spots = P.Spots(skill, nil, "rate")
    for i = 1, #spots do
      local s = spots[i]
      local secs = (N(s.minutes) or 0) * 60
      local ups = N(s.pts) or 0
      local gph = RatePerHour(ups, secs)
      out[#out + 1] = {
        skill = skill, zone = s.zone, pts = ups, secs = secs,
        gathersPerHour = gph,  -- paliers / h mesurés (pas un score)
        avgMin = s.avg, sub = s.sub,
      }
    end
  end
  table.sort(out, function(a, b)
    local ra, rb = a.gathersPerHour or -1, b.gathersPerHour or -1
    if ra ~= rb then return ra > rb end
    return (a.pts or 0) > (b.pts or 0)
  end)
  return out
end

function E.FishingRates(rep)
  local out = {}
  for zone, z in pairs((rep and rep.fishing) or {}) do
    local r = RatePerHour(z.n, z.secs)
    out[#out + 1] = { zone = zone, n = N(z.n) or 0, secs = N(z.secs) or 0, perHour = r }
  end
  table.sort(out, function(a, b)
    local ra, rb = a.perHour or -1, b.perHour or -1
    if ra ~= rb then return ra > rb end
    return a.n > b.n
  end)
  return out
end

function E.ProfessionFlags(rep)
  local out = {}
  local P = ns.Progress
  for skill, a in pairs((rep and rep.attempts) or {}) do
    local att, up = N(a.att) or 0, N(a.up) or 0
    local green = (N(a.easy) or 0) + (N(a.trivial) or 0)
    local flag
    -- palier au maître : mesure déjà faite par RankStatus, pas un chiffre inventé
    local rs = ns.RankStatus and ns.RankStatus(skill)
    if type(rs) == "table" and rs.state == "available" and rs.src == "maître" then
      flag = "trainer"
    elseif att > 0 and green / att >= 0.7 and (up / att) <= 0.15 and att >= 5 then
      flag = "green"
    end
    local ratio = (att > 0) and (up / att) or nil
    out[#out + 1] = {
      skill = skill, att = att, up = up, ratio = ratio,
      optimal = N(a.optimal) or 0, medium = N(a.medium) or 0,
      easy = N(a.easy) or 0, trivial = N(a.trivial) or 0,
      flag = flag,
    }
  end
  table.sort(out, function(a, b) return (a.att or 0) > (b.att or 0) end)
  return out
end

function E.Weapons()
  local cap = E.WeaponCap()
  local lvl = N(ns.GetPlayerLevel and ns.GetPlayerLevel())
  local out = {}
  local snap = ns.UI and ns.UI.snapshot
  local tiles = snap and (snap.allTiles or snap.tiles) or {}
  for _, d in ipairs(tiles) do
    if d and (d.kind == "melee" or d.kind == "ranged" or d.kind == "defense" or d.kind == "feral") and not d.placeholder then
      local cur = N(d.current)
      local c = cap
      if d.kind == "defense" and lvl then c = lvl * 5 end
      out[#out + 1] = {
        id = d.id, name = d.name, kind = d.kind,
        current = cur, cap = c,
        frac = (cur and c and c > 0) and (cur / c) or nil,
      }
    end
  end
  table.sort(out, function(a, b)
    local fa, fb = a.frac or 2, b.frac or 2
    return fa < fb
  end)
  return out
end

function E.Report(period)
  if E._sim and E._sim.report and (not period or period == "session" or E._sim.period == period) then
    return E._sim.report
  end
  E.Pulse("report")
  local agg
  if period == "d7" then
    agg = SumSecs(E.Days(7))
  elseif period == "d30" then
    agg = SumSecs(E.Days(30))
  else
    local e = E.Sess()
    agg = {
      secs = e.secs, deaths = { n = N(e.deaths.n) or 0, secs = N(e.deaths.secs) or 0, last = e.deaths.last },
      bagMiss = N(e.bagMiss) or 0, xpFrac = N(e.xpFrac) or 0,
      attempts = e.attempts, fishing = e.fishing,
      moneyNet = N(e.moneyNet) or 0, moneyIn = N(e.moneyIn) or 0, moneyOut = N(e.moneyOut) or 0,
      moneyByZone = e.moneyByZone, zoneSecs = e.zoneSecs, xpFracByZone = e.xpFracByZone,
    }
  end
  local score, total = E.Score(agg.secs)
  local active = E.SumKeys(agg.secs, E.ACTIVE)
  local dead = E.SumKeys(agg.secs, E.DEAD)
  local other = N(agg.secs.other) or 0
  local P = ns.Progress
  local rates = P and P.Rates and P.Rates() or {}
  local maxed = E.AtMaxLevel()
  local pctLevel, eta, xph
  if not maxed then
    xph = rates.xph
    pctLevel = rates.pctLevelPerHour or (rates.lph and rates.lph * 100) or nil
    eta = rates.etaLevel
  end
  -- % niveau / h sur 7/30 j : seulement si xpFrac a été mesuré
  local hours = total / E.HOUR
  local fracPerHour = (period ~= "session" and hours >= (E.MIN_SECS / E.HOUR) and (N(agg.xpFrac) or 0) > 0)
    and ((N(agg.xpFrac) or 0) / hours * 100) or nil
  if period == "session" then fracPerHour = pctLevel end
  local rep = {
    period = period or "session",
    secs = agg.secs, total = total, active = active, dead = dead, other = other,
    score = score,  -- part active, 0..1
    deaths = agg.deaths, bagMiss = agg.bagMiss, xpFrac = agg.xpFrac,
    attempts = agg.attempts, fishing = agg.fishing,
    maxLevel = maxed,
    xph = (not maxed) and xph or nil,
    pctLevelPerHour = (not maxed) and fracPerHour or nil,
    etaLevel = (not maxed) and eta or nil,
    lph = (not maxed) and rates.lph or nil,
    spots = E.SpotRanks(),
    fish = E.FishingRates(agg),
    professions = E.ProfessionFlags(agg),
    weapons = E.Weapons(),
  }
  rep.moneyNet = N(agg.moneyNet) or (agg.moneyNet)
  if rep.moneyNet == nil then
    local sess = E.Sess()
    if period == "session" or not period then
      rep.moneyNet, rep.moneyIn, rep.moneyOut = N(sess.moneyNet) or 0, N(sess.moneyIn) or 0, N(sess.moneyOut) or 0
      rep.moneyByZone, rep.zoneSecs, rep.xpFracByZone = sess.moneyByZone, sess.zoneSecs, sess.xpFracByZone
    end
  else
    rep.moneyIn, rep.moneyOut = N(agg.moneyIn) or 0, N(agg.moneyOut) or 0
    rep.moneyByZone, rep.zoneSecs, rep.xpFracByZone = agg.moneyByZone, agg.zoneSecs, agg.xpFracByZone
  end
  if (period == "session" or not period) and not rep.moneyByZone then
    local sess = E.Sess()
    rep.moneyNet = N(sess.moneyNet) or 0
    rep.moneyIn = N(sess.moneyIn) or 0
    rep.moneyOut = N(sess.moneyOut) or 0
    rep.moneyByZone, rep.zoneSecs, rep.xpFracByZone = sess.moneyByZone, sess.zoneSecs, sess.xpFracByZone
  end
  -- valeur marchand (pièces + prix vendeur), jamais un delta GetMoney
  local lootV = N(agg.lootValue)
  if lootV == nil then
    lootV = (N(agg.lootCoin) or 0) + (N(agg.lootVendor) or 0)
    if lootV == 0 and period ~= "session" then lootV = nil end
  end
  if period == "session" or not period then
    local sess = E.Sess()
    lootV = N(sess.lootValue) or ((N(sess.lootCoin) or 0) + (N(sess.lootVendor) or 0))
    rep.lootCoin, rep.lootVendor = N(sess.lootCoin) or 0, N(sess.lootVendor) or 0
    if sess.lootByZone and next(sess.lootByZone) then
      rep.lootByZone = sess.lootByZone
      local mz = {}
      for z, v in pairs(sess.lootByZone) do
        local val = type(v) == "table" and (N(v.value) or ((N(v.coin) or 0) + (N(v.vendor) or 0))) or N(v)
        mz[z] = { net = val or 0, inn = val or 0, out = 0 }
      end
      rep.moneyByZone = mz
    end
  else
    rep.lootCoin, rep.lootVendor = N(agg.lootCoin) or 0, N(agg.lootVendor) or 0
  end
  if lootV ~= nil then
    rep.lootValue, rep.moneyNet = lootV, lootV
  end
  rep.goldKind = "vendor"
  hours = (N(rep.total) or 0) / E.HOUR
  if hours >= (E.MIN_SECS / E.HOUR) and rep.moneyNet ~= nil then
    rep.goldPerHour = rep.moneyNet / hours
  end
  if P and P.C then
    local prog = P.C()
    rep.prevSession = prog and prog.effPrev or nil
  end
  rep.profit = E.Profitability(rep)
  rep.tip = E.Tip(rep)
  return rep
end

function E.SetSim(on, data)
  if on then
    E._sim = data or E.DemoData()
  else
    E._sim = nil
  end
  return E._sim
end

function E.DemoData()
  local secs = EmptySecs()
  secs.combat, secs.gather, secs.craft = 1800, 900, 300
  secs.flight, secs.transport, secs.afk, secs.death, secs.loading, secs.other = 720, 180, 240, 90, 60, 510
  local total = E.Total(secs)
  local score = E.SumKeys(secs, E.ACTIVE) / total
  local report = {
    period = "session", secs = secs, total = total,
    active = E.SumKeys(secs, E.ACTIVE), dead = E.SumKeys(secs, E.DEAD), other = secs.other,
    score = score,
    deaths = { n = 2, secs = 90, last = 45 },
    bagMiss = 3, xpFrac = 0.42,
    maxLevel = false, xph = 21953, pctLevelPerHour = 35.0, etaLevel = 31 * 60, lph = 0.35,
    attempts = {
      alchemy = { att = 20, up = 8, optimal = 12, medium = 5, easy = 3, trivial = 0, unknown = 0 },
      cooking = { att = 15, up = 1, optimal = 0, medium = 2, easy = 8, trivial = 5, unknown = 0 },
    },
    fishing = { ["Les Paluns"] = { n = 24, secs = 900 } },
    spots = {
      { skill = "skinning", zone = "Les Paluns", pts = 18, secs = 720, gathersPerHour = 90, avgMin = 0.67 },
    },
    fish = { { zone = "Les Paluns", n = 24, secs = 900, perHour = 96 } },
    professions = {
      { skill = "alchemy", name = "Alchimie", att = 20, up = 8, ratio = 0.4, optimal = 12, medium = 5, easy = 3, trivial = 0 },
      { skill = "cooking", name = "Cuisine", att = 15, up = 1, ratio = 1/15, optimal = 0, medium = 2, easy = 8, trivial = 5, flag = "green" },
    },
    weapons = { { id = "swords", name = "Épées", kind = "melee", current = 150, cap = 160, frac = 150/160 } },
    moneyNet = 123456, moneyIn = 18500, moneyOut = 0, goldPerHour = 123456 / (4800/3600),
    lootCoin = 18500, lootVendor = 104956, lootValue = 123456, goldKind = "vendor",
    moneyByZone = { ["Les Paluns"] = { net = 80000, inn = 80000, out = 0 } },
    lootByZone = { ["Les Paluns"] = { coin = 4000, vendor = 76000, value = 80000 } },
    zoneSecs = { ["Les Paluns"] = 720 },
    xpFracByZone = { ["Les Paluns"] = 0.12 },
  }
  report.spots[1].goldNet = 80000
  report.spots[1].goldPerHour = 80000 / (720/3600)
  report.spots[1].pctLevelPerHour = 0.12 / (720/3600) * 100
  report.goldPerHour = report.goldPerHour
  report.profit = E.Profitability(report)
  report.tip = E.Tip(report)
  return { bucket = "combat", report = report, period = "session" }
end


------------------------------------------------------------------------------
-- Or (uniquement pour le rapport Rentabilité — pas un suivi de possessions)
------------------------------------------------------------------------------
function E.FormatMoney(copper, withSign)
  copper = N(copper)
  if copper == nil then return nil end
  local sign = ""
  local v = copper
  if v < 0 then sign, v = "-", -v end
  v = math.floor(v + 0.5)
  local g = math.floor(v / 10000)
  local s = math.floor((v % 10000) / 100)
  local c = v % 100
  local gold = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
  local silver = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
  local cop = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"
  local parts = {}
  if g > 0 or v == 0 then parts[#parts + 1] = tostring(g) .. gold end
  if s > 0 or g > 0 then parts[#parts + 1] = tostring(s) .. silver end
  parts[#parts + 1] = tostring(c) .. cop
  return (withSign ~= false and sign or "") .. table.concat(parts, " ")
end

function E.NoteMoney(init)
  local cur = N(Call(_G.GetMoney))
  if not cur then return nil end
  local e = E.Sess()
  if init or e.moneyPrev == nil then
    e.moneyPrev = cur
    if e.moneyStart == nil then e.moneyStart = cur end
    return 0
  end
  local d = cur - e.moneyPrev
  e.moneyPrev = cur
  if d == 0 then return 0 end
  e.moneyNet = (N(e.moneyNet) or 0) + d
  if d > 0 then e.moneyIn = (N(e.moneyIn) or 0) + d
  else e.moneyOut = (N(e.moneyOut) or 0) + (-d) end
  local P = ns.Progress
  local zone = P and P.Zone and P.Zone() or nil
  if zone then
    e.moneyByZone = e.moneyByZone or {}
    local z = e.moneyByZone[zone]
    if type(z) ~= "table" then z = { net = N(z) or 0, inn = 0, out = 0 } e.moneyByZone[zone] = z end
    z.net = (N(z.net) or 0) + d
    if d > 0 then z.inn = (N(z.inn) or 0) + d else z.out = (N(z.out) or 0) + (-d) end
  end
  local day = E.Day()
  if day then
    day.moneyNet = (N(day.moneyNet) or 0) + d
    if d > 0 then day.moneyIn = (N(day.moneyIn) or 0) + d
    else day.moneyOut = (N(day.moneyOut) or 0) + (-d) end
    if zone then
      day.moneyByZone = day.moneyByZone or {}
      local z = day.moneyByZone[zone]
      if type(z) ~= "table" then z = { net = 0, inn = 0, out = 0 } day.moneyByZone[zone] = z end
      z.net = (N(z.net) or 0) + d
      if d > 0 then z.inn = (N(z.inn) or 0) + d else z.out = (N(z.out) or 0) + (-d) end
    end
  end
  return d
end

function E.RememberPrev(s)
  s = s or (ns.Progress and ns.Progress.Session and ns.Progress.Session())
  local e = s and s.eff
  if not e then return end
  local P = ns.Progress
  if not (P and P.C) then return end
  local p = P.C()
  p.effPrev = {
    moneyNet = N(e.moneyNet) or 0,
    moneyIn = N(e.moneyIn) or 0,
    moneyOut = N(e.moneyOut) or 0,
    total = E.Total(e.secs or {}),
    xpFrac = N(e.xpFrac) or 0,
    start = s.start,
    bagMiss = N(e.bagMiss) or 0,
    deaths = e.deaths and { n = e.deaths.n, secs = e.deaths.secs } or nil,
  }
end

local function PercentileMap(items, key)
  local vals = {}
  for i = 1, #items do
    local v = N(items[i][key])
    if v then vals[#vals + 1] = { i = i, v = v } end
  end
  table.sort(vals, function(a, b) if a.v ~= b.v then return a.v < b.v end return a.i < b.i end)
  local n = #vals
  local out = {}
  local i = 1
  while i <= n do
    local j = i
    while j + 1 <= n and vals[j + 1].v == vals[i].v do j = j + 1 end
    -- centile : (nombre de valeurs strictement inférieures + la moitié des égalités) / n
    local pct = (n <= 1) and 100 or (100 * ((i - 1) + (j - i + 1) * 0.5) / n)
    for k = i, j do out[vals[k].i] = pct end
    i = j + 1
  end
  return out
end

-- Progression normalisée d'un spot : % de niveau / h si mesuré, sinon paliers / h.
function E.SpotProgressRate(it)
  if N(it.pctLevelPerHour) then return N(it.pctLevelPerHour), "pct" end
  if N(it.gathersPerHour) then return N(it.gathersPerHour), "ups" end
  return nil
end

function E.EnrichSpots(rep)
  local spots = {}
  for i, s in ipairs((rep and rep.spots) or {}) do
    spots[#spots + 1] = s
  end
  local moneyByZone = (rep and rep.moneyByZone) or {}
  local zoneSecs = (rep and rep.zoneSecs) or {}
  local xpFracByZone = (rep and rep.xpFracByZone) or {}
  -- enrich existing gather spots
  local seen = {}
  for i = 1, #spots do
    local s = spots[i]
    local z = s.zone
    seen[z] = true
    local lb = ((rep and rep.lootByZone) or {})[z]
    local m = moneyByZone[z]
    local net = type(lb) == "table" and (N(lb.value) or ((N(lb.coin) or 0) + (N(lb.vendor) or 0))) or N(lb)
    if net == nil then net = type(m) == "table" and N(m.net) or N(m) end
    s.goldNet = net
    local secs = N(zoneSecs[z]) or N(s.secs) or 0
    if secs < (N(s.secs) or 0) then secs = N(s.secs) or secs end
    s.zoneSecs = secs
    if net and secs >= E.MIN_SECS then s.goldPerHour = net / (secs / E.HOUR) end
    local frac = N(xpFracByZone[z])
    s.xpFrac = frac
    if frac and secs >= E.MIN_SECS then s.pctLevelPerHour = frac / (secs / E.HOUR) * 100 end
  end
  return spots
end

function E.Profitability(rep)
  if not rep then return nil end
  local spots = E.EnrichSpots(rep)
  local hours = (N(rep.total) or 0) / E.HOUR
  local goldH = rep.goldPerHour
  if goldH == nil and hours >= (E.MIN_SECS / E.HOUR) and N(rep.moneyNet) then
    goldH = N(rep.moneyNet) / hours
  end
  -- candidats : assez de temps mesuré
  local cand = {}
  for i = 1, #spots do
    local s = spots[i]
    local secs = N(s.zoneSecs) or N(s.secs) or 0
    if secs >= E.MIN_SECS then cand[#cand + 1] = s end
  end
  local progKey = {}
  for i = 1, #cand do
    local v, kind = E.SpotProgressRate(cand[i])
    cand[i]._prog, cand[i]._progKind = v, kind
    if v then progKey[i] = true end
  end
  -- centiles parmi les spots qui ont la métrique
  local withProg, withGold = {}, {}
  for i = 1, #cand do
    if cand[i]._prog then withProg[#withProg + 1] = cand[i] end
    if N(cand[i].goldPerHour) then withGold[#withGold + 1] = cand[i] end
  end
  local pMap = PercentileMap(withProg, "_prog")
  -- remap from withProg index to cand objects
  for i = 1, #withProg do withProg[i]._pPct = pMap[i] end
  local gMap = PercentileMap(withGold, "goldPerHour")
  for i = 1, #withGold do withGold[i]._gPct = gMap[i] end
  local bestProg, bestGold, bestMix = nil, nil, nil
  for i = 1, #cand do
    local s = cand[i]
    if s._prog and (not bestProg or s._prog > bestProg._prog) then bestProg = s end
    if N(s.goldPerHour) and (not bestGold or s.goldPerHour > bestGold.goldPerHour) then bestGold = s end
    if s._pPct and s._gPct then
      s.mixScore = s._pPct + s._gPct
      if not bestMix or s.mixScore > bestMix.mixScore then bestMix = s end
    end
  end
  return {
    moneyNet = N(rep.moneyNet), moneyIn = N(rep.moneyIn), moneyOut = N(rep.moneyOut),
    goldPerHour = goldH, hours = hours,
    prev = rep.prevSession,
    spots = spots, candidates = cand,
    bestMix = bestMix, bestProg = bestProg, bestGold = bestGold,
    minSecs = E.MIN_SECS,
  }
end

function E.ScoringTip()
  return Tr["Classement mixte : pour chaque spot avec au moins 1 min mesurée, on calcule le centile de sa progression normalisée (% de niveau / h, ou paliers / h s'il n'y a pas d'XP) et le centile de son or / h, parmi tes propres spots qui ont cette mesure. Le score mixte est la somme des deux centiles. Rien n'est inventé : un spot sans or ou sans progression mesurée n'entre pas dans le mixte."]
end

------------------------------------------------------------------------------
-- Butin : pièces ramassées + valeur marchand (prix vendeur au moment du loot)
-- On n'utilise PAS GetMoney() : courrier, HV, échanges et banque ne faussent rien.
------------------------------------------------------------------------------
function E.ParseLootMoney(msg)
  if type(msg) ~= "string" or msg == "" then return nil end
  local function take(pat)
    local n = N(msg:match(pat))
    return n or 0
  end
  -- préfixes globaux du client (toute langue)
  local okPrefix = false
  if not E._moneyPrefixReady then
    E._moneyPrefixReady = true
    E._moneyPrefixes = {}
    for _, g in ipairs({ "YOU_LOOT_MONEY", "LOOT_MONEY_SPLIT", "YOU_LOOT_MONEY_GUILD", "LOOT_MONEY_SPLIT_GUILD" }) do
      local pfx = ns.GlobalPrefix and ns.GlobalPrefix(g)
      if pfx then E._moneyPrefixes[#E._moneyPrefixes + 1] = pfx end
    end
  end
  if #(E._moneyPrefixes or {}) > 0 then
    for i = 1, #E._moneyPrefixes do
      if msg:find(E._moneyPrefixes[i], 1, true) then okPrefix = true break end
    end
  end
  if not okPrefix then
    -- repli FR/EN si les globaux ne sont pas chargés ; « loot » seul est trop large (courrier, HV)
    local fold = Fold(msg)
    if fold:find("vous ramass", 1, true) or fold:find("ramass", 1, true)
      or fold:find("you loot", 1, true) or fold:find("you receive loot", 1, true)
      or fold:find("part du butin", 1, true) or fold:find("share of the loot", 1, true)
      or fold:find("your share of the loot", 1, true) then
      okPrefix = true
    end
  end
  if not okPrefix then return nil end
  local g = take("(%d+)%s*|T[^|]*[Gg]old") + take("(%d+)%s*[Gg]old") + take("(%d+)%s*[Oo]r[^%w]") + take("(%d+)%s*[Oo]r$")
  local s = take("(%d+)%s*|T[^|]*[Ss]ilver") + take("(%d+)%s*[Ss]ilver") + take("(%d+)%s*[Aa]rgent")
  local c = take("(%d+)%s*|T[^|]*[Cc]opper") + take("(%d+)%s*[Cc]opper") + take("(%d+)%s*[Cc]uivre")
  -- « 12 c. » / nombres seuls dans un libellé déjà monétaire
  if g + s + c == 0 then
    c = take("(%d+)%s*c%.") + take("(%d+)%s*C[^%w]") + take("(%d+)%s*C$")
  end
  local copper = g * 10000 + s * 100 + c
  if copper <= 0 then return nil end
  return copper
end

function E.ItemSellPrice(itemID)
  itemID = N(itemID)
  if not itemID then return nil end
  local gi = _G.GetItemInfo or (type(_G.C_Item) == "table" and _G.C_Item.GetItemInfo)
  if type(gi) ~= "function" then return nil end
  local ok, r = pcall(function() return { gi(itemID) } end)
  if not ok or type(r) ~= "table" then return nil end
  -- name, link, quality, ilvl, min, type, sub, stack, equip, tex, sellPrice
  local price = N(r[11]) or N(r[12])
  if price == nil and type(_G.GetItemVendorPrice) == "function" then
    price = N(Call(_G.GetItemVendorPrice, itemID))
  end
  return price
end

function E.AddLoot(coin, vendor, zone)
  coin, vendor = N(coin) or 0, N(vendor) or 0
  if coin == 0 and vendor == 0 then return end
  local e = E.Sess()
  e.lootCoin = (N(e.lootCoin) or 0) + coin
  e.lootVendor = (N(e.lootVendor) or 0) + vendor
  e.lootValue = (N(e.lootCoin) or 0) + (N(e.lootVendor) or 0)
  -- alias de compatibilité pour le rapport (plus de delta GetMoney)
  e.moneyNet = e.lootValue
  local P = ns.Progress
  zone = zone or (P and P.Zone and P.Zone()) or nil
  if zone then
    e.lootByZone = e.lootByZone or {}
    local z = e.lootByZone[zone]
    if type(z) ~= "table" then z = { coin = 0, vendor = 0, value = 0 } e.lootByZone[zone] = z end
    z.coin = (N(z.coin) or 0) + coin
    z.vendor = (N(z.vendor) or 0) + vendor
    z.value = (N(z.coin) or 0) + (N(z.vendor) or 0)
    e.moneyByZone = e.moneyByZone or {}
    e.moneyByZone[zone] = { net = z.value, inn = z.value, out = 0 }
  end
  local day = E.Day()
  if day then
    day.lootCoin = (N(day.lootCoin) or 0) + coin
    day.lootVendor = (N(day.lootVendor) or 0) + vendor
    day.lootValue = (N(day.lootCoin) or 0) + (N(day.lootVendor) or 0)
    day.moneyNet = day.lootValue
    if zone then
      day.lootByZone = day.lootByZone or {}
      local z = day.lootByZone[zone]
      if type(z) ~= "table" then z = { coin = 0, vendor = 0, value = 0 } day.lootByZone[zone] = z end
      z.coin = (N(z.coin) or 0) + coin
      z.vendor = (N(z.vendor) or 0) + vendor
      z.value = (N(z.coin) or 0) + (N(z.vendor) or 0)
      day.moneyByZone = day.moneyByZone or {}
      day.moneyByZone[zone] = { net = z.value, inn = z.value, out = 0 }
    end
  end
end

function E.NoteLootCoin(msg)
  local copper = E.ParseLootMoney(msg)
  if not copper then return nil end
  E.AddLoot(copper, 0)
  return copper
end

function E.NoteLootItem(msg)
  local Sc = ns.Scanner
  local itemID, qty
  if Sc and Sc.ParseChatLoot then
    itemID, qty = Sc.ParseChatLoot(msg)
  end
  itemID, qty = N(itemID), N(qty) or 1
  if not itemID then return nil end
  local price = E.ItemSellPrice(itemID)
  if price == nil then
    E._pendingVendor = E._pendingVendor or {}
    local P = ns.Progress
    E._pendingVendor[#E._pendingVendor + 1] = {
      id = itemID, qty = qty, zone = P and P.Zone and P.Zone() or nil,
    }
    -- force le cache
    local gi = _G.GetItemInfo or (type(_G.C_Item) == "table" and _G.C_Item.GetItemInfo)
    if type(gi) == "function" then pcall(gi, itemID) end
    return nil
  end
  E.AddLoot(0, price * qty)
  return price * qty
end

function E.FlushPendingVendor(itemID)
  itemID = N(itemID)
  local list = E._pendingVendor
  if not list or #list == 0 then return end
  local keep = {}
  for i = 1, #list do
    local p = list[i]
    if itemID and p.id ~= itemID then
      keep[#keep + 1] = p
    else
      local price = E.ItemSellPrice(p.id)
      if price == nil then
        keep[#keep + 1] = p
      else
        E.AddLoot(0, price * (N(p.qty) or 1), p.zone)
      end
    end
  end
  E._pendingVendor = keep
end

-- Conservé comme no-op : plus aucun delta GetMoney dans la rentabilité.
function E.NoteMoney(init)
  return nil
end

function E.VendorTip()
  return Tr["Valeur marchand : pièces ramassées (CHAT_MSG_MONEY) plus le prix vendeur de chaque objet au moment du butin (GetItemInfo × quantité). Le courrier, l'hôtel des ventes, les échanges et la banque ne sont pas comptés. Un objet ensuite vendu à l'hôtel des ventes reste valorisé au prix vendeur."]
end

------------------------------------------------------------------------------
-- Instantané de session + historique (30 détaillées, puis agrégats hebdo)
------------------------------------------------------------------------------
E.HIST_MAX = 30

function E.Hist()
  local P = ns.Progress
  if not (P and P.C) then return nil end
  local p = P.C()
  p.sessLog = p.sessLog or {}
  p.sessWeeks = p.sessWeeks or {}
  return p
end

function E.WeekKey(ts)
  ts = N(ts)
  local P = ns.Progress
  local day
  if type(_G.date) == "function" and ts and ts > 0 then
    local ok, s = pcall(_G.date, "%Y-%m-%d", ts)
    if ok then day = s end
  end
  if P and P.WeekStart then return P.WeekStart(day or (P.Today and P.Today())) end
  return day or "?"
end

local function SkillList(sess)
  local out = {}
  sess = sess or {}
  for k, sk in pairs(sess.skills or {}) do
    out[#out + 1] = { id = k, name = sk.name or k, n = N(sk.n) or 0 }
  end
  table.sort(out, function(a, b) if a.n ~= b.n then return a.n > b.n end return tostring(a.name) < tostring(b.name) end)
  return out
end

function E.SlimSpot(s)
  if type(s) ~= "table" then return s end
  return {
    skill = s.skill, zone = s.zone, pts = s.pts, secs = s.secs, n = s.n,
    goldNet = s.goldNet, goldPerHour = s.goldPerHour,
    pctLevelPerHour = s.pctLevelPerHour, gathersPerHour = s.gathersPerHour,
    xpFrac = s.xpFrac, mixScore = s.mixScore, name = s.name,
  }
end

function E.SlimSpots(list)
  if type(list) ~= "table" then return list end
  local out, n = {}, 0
  for i = 1, #list do
    n = n + 1
    if n > 12 then break end
    out[n] = E.SlimSpot(list[i])
  end
  return out
end

function E.SlimProfit(profit)
  if type(profit) ~= "table" then return profit end
  return {
    moneyNet = profit.moneyNet, moneyIn = profit.moneyIn, moneyOut = profit.moneyOut,
    goldPerHour = profit.goldPerHour, hours = profit.hours, minSecs = profit.minSecs,
    bestMix = E.SlimSpot(profit.bestMix),
    bestProg = E.SlimSpot(profit.bestProg),
    bestGold = E.SlimSpot(profit.bestGold),
  }
end

E.WEEKS_MAX = 104
function E.CompactHist(p)
  if type(p) ~= "table" then return 0 end
  p.sessLog = p.sessLog or {}
  p.sessWeeks = p.sessWeeks or {}
  local n = 0
  while #p.sessLog > (E.HIST_MAX or 30) do
    table.remove(p.sessLog)
    n = n + 1
  end
  for i = 1, #p.sessLog do
    local s = p.sessLog[i]
    if type(s) == "table" then
      if s.profit then s.profit = E.SlimProfit(s.profit) end
      if s.spots then s.spots = E.SlimSpots(s.spots) end
      s.tip = nil
    end
  end
  local weeks = {}
  for k, v in pairs(p.sessWeeks) do
    weeks[#weeks + 1] = { k = k, v = v }
  end
  table.sort(weeks, function(a, b) return tostring(a.k) < tostring(b.k) end)
  while #weeks > E.WEEKS_MAX do
    local old = table.remove(weeks, 1)
    p.sessWeeks[old.k] = nil
    n = n + 1
  end
  for i = 1, #weeks do
    local v = weeks[i].v
    if type(v) == "table" then
      if v.profit then v.profit = E.SlimProfit(v.profit) end
      if v.spots then v.spots = E.SlimSpots(v.spots) end
      v.tip = nil
    end
  end
  return n
end

function E.CaptureRecap(s)
  local P = ns.Progress
  if s then
    local e = BindEff(s)
    E._sessOverride, E._sessOverrideSrc = e, s
  elseif not E._archiving then
    E.Pulse("capture")
  end
  if not s and not E._archiving then
    s = P and P.Session and P.Session() or nil
  end
  local rep = E.Report("session")
  local r = (P and P.Rates and P.Rates()) or {}
  local ended = Wall()
  local start = N(s and s.start) or ended
  local dur = math.max(0, ended - start)
  if N(rep.total) and rep.total > dur then dur = rep.total end
  local ach = {}
  if P and P.Achievements then
    for _, a in ipairs(P.Achievements()) do
      if a.unlocked and N(a.at) and N(a.at) >= start then
        ach[#ach + 1] = { id = a.id, name = a.name, at = a.at }
      end
    end
  end
  local recipes = {}
  if s and s.recipes then
    for i, rec in ipairs(s.recipes) do recipes[#recipes + 1] = rec end
  end
  local e = (s and s.eff) or E.Sess()
  local lootValue = N(e.lootValue) or N(rep.lootValue) or N(rep.moneyNet)
  local hours = (dur > 0) and (dur / E.HOUR) or nil
  local ups, upsN = SkillList(s), 0
  for i = 1, #ups do upsN = upsN + (ups[i].n or 0) end
  local snap = {
    start = start, ended = ended, duration = dur,
    pts = N(s and s.pts) or 0,
    xp = N(s and s.xp) or 0,
    xpFrac = N(e.xpFrac) or N(s and s.xpFrac) or N(rep.xpFrac) or 0,
    levels = N(s and s.levels) or 0,
    score = rep.score, secs = rep.secs, total = N(rep.total) or dur,
    active = rep.active, dead = rep.dead, other = rep.other,
    deaths = rep.deaths, bagMiss = N(rep.bagMiss) or 0,
    lootCoin = N(e.lootCoin) or 0, lootVendor = N(e.lootVendor) or 0,
    lootValue = lootValue or 0,
    goldPerHour = (hours and hours >= (E.MIN_SECS / E.HOUR) and lootValue) and (lootValue / hours) or nil,
    pctLevelPerHour = (not rep.maxLevel) and (rep.pctLevelPerHour or r.pctLevelPerHour) or nil,
    maxLevel = rep.maxLevel and true or false,
    skills = ups, skillUps = upsN,
    skillUpsPerHour = (hours and hours >= (E.MIN_SECS / E.HOUR) and upsN > 0) and (upsN / hours) or nil,
    recipes = recipes,
    spots = E.SlimSpots(rep.spots), profit = E.SlimProfit(rep.profit),
    achievements = ach,
    goldKind = "vendor",
  }
  E._sessOverride, E._sessOverrideSrc = nil, nil
  return snap
end

function E.MergeRecap(a, b)
  if not a then return b end
  if not b then return a end
  local function add(x, y) return (N(x) or 0) + (N(y) or 0) end
  local out = {
    start = math.min(N(a.start) or 0, N(b.start) or 0),
    ended = math.max(N(a.ended) or 0, N(b.ended) or 0),
    duration = add(a.duration, b.duration),
    pts = add(a.pts, b.pts), xp = add(a.xp, b.xp), xpFrac = add(a.xpFrac, b.xpFrac),
    levels = add(a.levels, b.levels),
    total = add(a.total, b.total), active = add(a.active, b.active),
    dead = add(a.dead, b.dead), other = add(a.other, b.other),
    bagMiss = add(a.bagMiss, b.bagMiss),
    lootCoin = add(a.lootCoin, b.lootCoin), lootVendor = add(a.lootVendor, b.lootVendor),
    lootValue = add(a.lootValue, b.lootValue),
    skillUps = add(a.skillUps, b.skillUps),
    n = add(a.n or 1, b.n or 1),
    goldKind = "vendor", weekly = true,
    week = a.week or b.week,
  }
  out.score = (out.total > 0) and (out.active / out.total) or nil
  local hours = out.duration / E.HOUR
  if hours >= (E.MIN_SECS / E.HOUR) then
    out.goldPerHour = out.lootValue / hours
    if out.xpFrac > 0 then out.pctLevelPerHour = out.xpFrac / hours * 100 end
    if out.skillUps > 0 then out.skillUpsPerHour = out.skillUps / hours end
  end
  return out
end

function E.ArchiveRecap(snap)
  snap = snap or E.CaptureRecap()
  if not snap then return nil end
  local p = E.Hist()
  if not p then return snap end
  table.insert(p.sessLog, 1, snap)
  while #p.sessLog > E.HIST_MAX do
    local old = table.remove(p.sessLog)
    local key = E.WeekKey(old.start or old.ended)
    old.week = key
    p.sessWeeks[key] = E.MergeRecap(p.sessWeeks[key], old)
  end
  p.effPrev = {
    lootValue = snap.lootValue, lootCoin = snap.lootCoin, lootVendor = snap.lootVendor,
    moneyNet = snap.lootValue, total = snap.total, xpFrac = snap.xpFrac,
    start = snap.start, score = snap.score, duration = snap.duration,
    goldPerHour = snap.goldPerHour, pctLevelPerHour = snap.pctLevelPerHour,
    skillUpsPerHour = snap.skillUpsPerHour, bagMiss = snap.bagMiss,
    deaths = snap.deaths, goldKind = "vendor",
  }
  if ns.StepGC then pcall(ns.StepGC, 400) end
  return snap
end

function E.RememberPrev(s)
  return E.ArchiveRecap(E.CaptureRecap(s))
end

function E.HistoryList()
  local p = E.Hist()
  if not p then return { sessions = {}, weeks = {} } end
  local weeks = {}
  for k, v in pairs(p.sessWeeks or {}) do
    weeks[#weeks + 1] = v
    v.week = v.week or k
  end
  table.sort(weeks, function(a, b) return (a.week or "") > (b.week or "") end)
  return { sessions = p.sessLog or {}, weeks = weeks }
end

function E.AverageOf(list, key)
  local sum, n = 0, 0
  for i = 1, #(list or {}) do
    local v = N(list[i][key])
    if v then sum, n = sum + v, n + 1 end
  end
  if n == 0 then return nil end
  return sum / n, n
end

function E.RecapsInDays(days)
  days = N(days) or 7
  local p = E.Hist()
  if not p then return {} end
  local now = Wall()
  local cut = now - days * 86400
  local out = {}
  for i, s in ipairs(p.sessLog or {}) do
    if (N(s.start) or N(s.ended) or 0) >= cut then out[#out + 1] = s end
  end
  -- semaines agrégées qui tombent dans la fenêtre
  for _, w in pairs(p.sessWeeks or {}) do
    if (N(w.ended) or N(w.start) or 0) >= cut then out[#out + 1] = w end
  end
  return out
end

-- Comparaisons uniquement normalisées (part active, % niv./h, paliers/h, valeur/h).
function E.CompareRecap(snap)
  snap = snap or E.CaptureRecap()
  local p = E.Hist()
  local prev = p and p.effPrev or (p and p.sessLog and p.sessLog[1]) or nil
  -- si on compare la session en cours, prev est la dernière archivée
  local d7, d30 = E.RecapsInDays(7), E.RecapsInDays(30)
  local function pack(key)
    return {
      mine = N(snap and snap[key]),
      prev = prev and N(prev[key]) or nil,
      d7 = E.AverageOf(d7, key),
      d30 = E.AverageOf(d30, key),
    }
  end
  return {
    score = pack("score"),
    pctLevelPerHour = pack("pctLevelPerHour"),
    skillUpsPerHour = pack("skillUpsPerHour"),
    goldPerHour = pack("goldPerHour"),
  }
end


function E.NoteRecipeLearn(msg)
  if type(msg) ~= "string" then return nil end
  local fold = Fold(msg)
  local learned = fold:find("vous avez appris", 1, true) or fold:find("you have learned", 1, true)
    or fold:find("apprend une nouvelle recette", 1, true) or fold:find("learned a new recipe", 1, true)
  if not learned then return nil end
  local name = msg:match(":%s*(.+)%s*$") or msg:match("recette%s+(.+)%s*$") or msg:match("recipe%s+(.+)%s*$")
  if type(name) == "string" then name = name:gsub("|c[^|]*|H.-|h%[(.-)%]|h|r", "%1"):gsub("%.$", "") end
  local s = ns.Progress and ns.Progress.Session and ns.Progress.Session()
  if not s then return nil end
  s.recipes = s.recipes or {}
  s.recipes[#s.recipes + 1] = { name = name or "?", at = Wall() }
  return name
end
function E.DemoRecap()
  local demo = E.DemoData and E.DemoData() or {}
  local report = demo.report or {}
  local snap = {
    start = Wall() - 5400, ended = Wall(), duration = 5400,
    pts = 42, xp = 21953, xpFrac = 0.42, levels = 0,
    score = report.score or 0.625, secs = report.secs, total = report.total or 4800,
    active = report.active, dead = report.dead, other = report.other,
    deaths = report.deaths or { n = 2, secs = 90 }, bagMiss = report.bagMiss or 3,
    lootCoin = 18500, lootVendor = 104956, lootValue = 123456,
    goldPerHour = 123456 / 1.5, pctLevelPerHour = 35.0, maxLevel = false,
    skills = { { id = "skinning", name = "Dépeçage", n = 18 }, { id = "cooking", name = "Cuisine", n = 4 } },
    skillUps = 22, skillUpsPerHour = 22 / 1.5,
    recipes = { { name = "Palourdes bouillies", id = 1 } },
    spots = report.spots, profit = report.profit,
    achievements = { { id = "demo", name = "Premier pas", at = Wall() - 1000 } },
    tip = report.tip or "15 % du temps en vol",
    goldKind = "vendor", demo = true,
  }
  if report.profit then snap.profit = report.profit end
  return snap
end

------------------------------------------------------------------------------
-- Branchements
------------------------------------------------------------------------------
if ns.On then
  ns.On("PLAYER_DEAD", function() E.OpenDeath(Now()) E.Pulse("dead") end)
  ns.On("PLAYER_ALIVE", function() E.CloseDeath(Now()) E.Pulse("alive") end)
  ns.On("PLAYER_UNGHOST", function() E.CloseDeath(Now()) E.Pulse("unghost") end)
  ns.On("PLAYER_CONTROL_GAINED", function()
    local S = ns.Slot
    if S and S.LiveDeath and S.LiveDeath() then return end
    if E.Sess().openDeath then E.CloseDeath(Now()) end
    E.Pulse("control")
  end)
  ns.On("PLAYER_REGEN_DISABLED", function() E.Pulse("combat") end)
  ns.On("PLAYER_REGEN_ENABLED", function() E.Pulse("regen") end)
  ns.On("PLAYER_FLAGS_CHANGED", function() E.Pulse("flags") end)
  ns.On("PLAYER_ENTERING_WORLD", function() E.Pulse("pew") end)
  ns.On("CHAT_MSG_MONEY", function(_, msg) E.NoteLootCoin(msg) end)
  ns.On("CHAT_MSG_LOOT", function(_, msg) E.NoteLootItem(msg) end)
  ns.On("GET_ITEM_INFO_RECEIVED", function(_, itemID) E.FlushPendingVendor(itemID) end)
  ns.On("CHAT_MSG_SYSTEM", function(_, msg) E.NoteRecipeLearn(msg) end)
  ns.On("UI_ERROR_MESSAGE", function(_, msg, text)
    if type(text) == "string" then msg = text end   -- 3.12.1 : (type d'erreur, texte) sur les clients récents
    local s = Fold(tostring(msg or _))
    local raw = tostring(msg or _)
    if raw == tostring(_G.ERR_INV_FULL) or raw == tostring(_G.ERR_BAG_FULL) then E.NoteBagMiss()   -- 3.12.1 : toutes langues
    elseif s:find("inventaire", 1, true) and s:find("plein", 1, true) then E.NoteBagMiss()
    elseif s:find("inventory", 1, true) and s:find("full", 1, true) then E.NoteBagMiss()
    elseif s:find("bags are full", 1, true) or s:find("sacs sont pleins", 1, true) then E.NoteBagMiss()
    elseif s:find("inv_full", 1, true) or s == "err_inv_full" then E.NoteBagMiss()
    end
  end)
  ns.On("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, ...)
    if unit and unit ~= "player" then return end
    local name = ...
    if type(name) ~= "string" then name = Call(_G.UnitCastingInfo, "player") end
    local diff = E.CurrentCraftDiff()
    -- on ne force pas un métier si on ne le connaît pas : pas de chiffre inventé
    if diff then
      local snap = ns.UI and ns.UI.snapshot
      -- skill id inconnu : on note sous "craft" générique seulement si la fenêtre est ouverte
      local tf = _G.TradeSkillFrame or _G.CraftFrame
      if tf and type(tf.IsShown) == "function" and Call(tf.IsShown, tf) then
        E.NoteAttempt("craft", diff, false)
      end
    end
    E.Pulse("cast")
  end)
end

-- palier : OnRise plus bas (Progress est déjà chargé : TOC place Efficiency après Progress)
do
  local P = ns.Progress
  if P and P.OnRise then
    local base = P.OnRise
    function P.OnRise(info)
      local r = base(info)
      if type(info) == "table" and info.id then
        local delta = N(info.delta) or ((N(info.to) or 0) - (N(info.from) or 0))
        if delta and delta > 0 then
          if P.GATHER and P.GATHER[info.id] then
            E._gatherUntil = Now() + 4
          elseif P.CRAFT and P.CRAFT[info.id] then
            E._craftUntil = Now() + 3
          end
          E.NoteSkillUp(info.id, delta)
        end
      end
      return r
    end
  end
  if P and P.OnXP then
    local base = P.OnXP
    function P.OnXP(...)
      local d = base(...)
      -- xpFrac est posé dans Progress.OnXP (appel E.NoteXpFrac)
      return d
    end
  end
  if P and P.Tick then
    local base = P.Tick
    function P.Tick(...)
      E.Pulse("tick")
      return base(...)
    end
  end
  if P and P.CloseSession then
    local base = P.CloseSession
    function P.CloseSession(s)
      if E._archiving then return base(s) end
      E._archiving = true
      if s then
        local e = BindEff(s)
        E._sessOverride, E._sessOverrideSrc = e, s
      end
      pcall(E.RememberPrev, s)
      E._sessOverride, E._sessOverrideSrc = nil, nil
      E._archiving = false
      return base(s)
    end
  end
end

return E
