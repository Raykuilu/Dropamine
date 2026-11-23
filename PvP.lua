-- Dropamine 3.3.13 : module JcJ (/drop pvp on|off).
--  1. Case « JcJ » dans la grille : icône de rang + jauge points de rang /
--     plafond de la semaine (si le jeu les expose), sinon points d'honneur, sinon
--     victoires honorables (VH) du jour. Infobulle : rang, honneur, VH jour /
--     semaine / total, série, K/D (total et session), objectif.
--  2. Repère sur les barres de nom des JOUEURS ENNEMIS : vert = donne de
--     l'honneur, gris = non (niveau gris selon la fonction du jeu
--     GetQuestDifficultyColor ; aucune formule à nous). Règles d'honneur de
--     Forever NON vérifiées.
--  3. Objectif : clic droit sur la case → « N VH aujourd'hui ».
--  4. Série : victoires sans mourir (remise à zéro à PLAYER_DEAD), toasts.
-- En combat : seulement des compteurs (événements) ; lectures, toasts et repères
-- après le combat. Aucune fonction protégée, aucun cadre Blizzard modifié
-- (lecture de textes seulement), nos cadres sont enfants d'UIParent.
local _, ns = ...
local Tr = ns.L   -- 3.5.19 : textes traduits (Locales/)
local UI = ns.UI
local PV = {}
ns.PvP = PV

local function N(v) return ns.N and ns.N(v) or tonumber(v) end
local function InCombat() return ns.InCombat and ns.InCombat() or false end
-- 3.6.0 : sans table temporaire (appelé sur les événements fréquents : survol,
-- barres de nom, cible) et sans troncature aux valeurs nil intermédiaires.
local function Ret(ok, ...) if not ok then return nil end return ... end
local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  return ns.Unsecret(Ret(pcall(fn, ...)))
end
local function Fold(s) return ns.Fold and ns.Fold(tostring(s or "")) or tostring(s or ""):lower() end
local function Say(m) print(Tr["|cffffd100Dropamine|r : "] .. m) end
local function After(dt, fn) if type(_G.C_Timer) == "table" and type(_G.C_Timer.After) == "function" then _G.C_Timer.After(dt, fn) return true end fn() return false end

PV.GREEN, PV.GREY = { 0.25, 0.95, 0.25 }, { 0.55, 0.55, 0.55 }
PV.STREAK_STEPS = { 3, 5, 10, 15, 20, 25, 30, 40, 50 }
PV.ICON_ALLIANCE = "Interface\\Icons\\INV_BannerPVP_02"
PV.ICON_HORDE = "Interface\\Icons\\INV_BannerPVP_01"
PV.RANK_ICON = "Interface\\PvPRankBadges\\PvPRank%02d"
PV.MARK_ICON = "Interface\\Icons\\Ability_DualWield"
PV.MARK = 14
PV.st = { session = { kills = 0, deaths = 0 }, streak = 0, src = {}, probe = {} }
PV.stats = { events = 0, kills = 0, toasts = 0, marks = 0, reads = 0 }
local S = PV.st

function PV.Enabled()
  if PV.forceOff then return false end
  return not (ns.db and ns.db.ui and ns.db.ui.pvp == false)
end
local function CDB()
  local c = ns.CharDB and ns.CharDB() or {}
  c.pvp = c.pvp or {}
  return c.pvp
end
local function Today() return type(_G.date) == "function" and _G.date("%Y-%m-%d") or "?" end

------------------------------------------------------------------------------
-- Lecture (hors combat) : API publiques sous pcall, puis fenêtre JcJ (texte)
------------------------------------------------------------------------------
-- statistiques (onglet Statistiques) : identifiants trouvés PAR LEUR NOM
PV.STAT_NAMES = {
  hk = { "nombre total de victoires honorables", "total honorable kills" },
  deathsFaction = { "nombre total de morts causees par la faction adverse", "deaths from the opposing faction", "total deaths from opposing faction" },
  deathsPlayers = { "nombre total de morts causees par d'autres personnages", "deaths from other players", "total deaths from other players" },
}
PV.STAT_GUESS = { hk = { 588 }, deathsPlayers = { 1501 } }   -- vérifiés par leur nom avant usage
local function NameIs(name, list)
  local f = Fold(name)
  for _, w in ipairs(list) do w = Fold(w) if f == w or f:find(w, 1, true) then return true end end
  return false
end
function PV.FindStats()
  local ids = S.statIds
  if ids then return ids end
  ids = {}
  -- 1) devinettes vérifiées par le nom
  for key, guesses in pairs(PV.STAT_GUESS) do
    for _, id in ipairs(guesses) do
      local _, name = Call(_G.GetAchievementInfo, id)
      if name and NameIs(name, PV.STAT_NAMES[key]) then ids[key] = id end
    end
  end
  -- 2) parcours des catégories de statistiques
  local cats = Call(_G.GetStatisticsCategoryList)
  if type(cats) == "table" then
    for _, cat in ipairs(cats) do
      local n = N(Call(_G.GetCategoryNumAchievements, cat)) or 0
      for i = 1, n do
        local id, name = Call(_G.GetAchievementInfo, cat, i)
        if id and name then
          for key, list in pairs(PV.STAT_NAMES) do
            if not ids[key] and NameIs(name, list) then ids[key] = id end
          end
        end
      end
    end
  end
  S.statIds = ids
  S.probe.stats = (ids.hk and ("VH " .. ids.hk) or "VH ?") .. ", morts faction " .. tostring(ids.deathsFaction or "?") .. ", morts joueurs " .. tostring(ids.deathsPlayers or "?")
  return ids
end
local function Stat(id)
  if not id or type(_G.GetStatistic) ~= "function" then return nil end
  local v = Call(_G.GetStatistic, id)
  if v == nil then return nil end
  if v == "--" then return 0 end
  return N((tostring(v):gsub("[^%d]", "")))
end

local function ReadCurrency()
  local want = { "points d'honneur", "honor points", "honneur", "honor" }
  local CI = _G.C_CurrencyInfo
  if type(CI) == "table" and type(CI.GetCurrencyListSize) == "function" then
    local n = N(Call(CI.GetCurrencyListSize)) or 0
    for i = 1, n do
      local info = Call(CI.GetCurrencyListInfo, i)
      if type(info) == "table" and not info.isHeader and NameIs(info.name, want) then
        return N(info.quantity), N(info.maxQuantity), "C_CurrencyInfo"
      end
    end
  end
  if type(_G.GetCurrencyListSize) == "function" then
    local n = N(Call(_G.GetCurrencyListSize)) or 0
    for i = 1, n do
      local name, isHeader, _, _, _, count, _, maxQ = Call(_G.GetCurrencyListInfo, i)
      if name and not isHeader and NameIs(name, want) then return N(count), N(maxQ), "GetCurrencyListInfo" end
    end
  end
  local h = Call(_G.GetHonorCurrency)
  if N(h) then return N(h), nil, "GetHonorCurrency" end
  return nil
end

-- points de rang / plafond : API possibles (sondées, noms enregistrés dans /drop debug)
PV.RANK_API = { "GetPVPRankPoints", "GetRankPoints", "GetHonorRankPoints", "GetSeasonRankPoints" }
local function ReadRankPointsAPI()
  local found = {}
  local C = _G.C_PvP
  if type(C) == "table" then
    for k, v in pairs(C) do
      if type(v) == "function" and (tostring(k):find("Rank") or tostring(k):find("Season")) then found[#found + 1] = "C_PvP." .. k end
    end
    for _, k in ipairs(PV.RANK_API) do
      local a, b = Call(C[k])
      if N(a) and N(b) and N(b) > 0 then S.probe.rankApi = "C_PvP." .. k return N(a), N(b) end
    end
  end
  for _, k in ipairs(PV.RANK_API) do
    local a, b = Call(_G[k])
    if N(a) and N(b) and N(b) > 0 then S.probe.rankApi = k return N(a), N(b) end
  end
  table.sort(found)
  S.probe.cpvp = #found > 0 and table.concat(found, ", ") or "aucune fonction Rank/Season dans C_PvP"
  return nil
end

-- fenêtre JcJ ouverte : « Points de rang : 0 / 750 », « Augmentation du plafond cette semaine : 1500 »
PV.UI_FRAMES = { "PVPFrame", "HonorFrame", "PVPParentFrame", "PVPUIFrame", "CharacterFrame" }
local function ScanText(f, depth, out)
  if not f or depth > 4 or out.n > 400 then return end
  if f.GetRegions then
    for _, r in ipairs({ pcall(f.GetRegions, f) }) do
      if type(r) == "table" and r.GetText and r.IsShown then
        local okS, sh = pcall(r.IsShown, r)
        local okT, t = pcall(r.GetText, r)
        out.n = out.n + 1
        if okS and sh and okT and type(t) == "string" and not (ns.IsSecret and ns.IsSecret(t)) then out[#out + 1] = t end
      end
    end
  end
  if f.GetChildren then
    for _, c in ipairs({ pcall(f.GetChildren, f) }) do
      if type(c) == "table" and c ~= true then ScanText(c, depth + 1, out) end
    end
  end
end
function PV.ParseTexts(list)
  local r = {}
  for i, t in ipairs(list) do
    local okF, f = pcall(Fold, t)
    if not okF or type(f) ~= "string" then f = "" end
    local a, b = f:match("points de rang%s*:?%s*([%d%s%.]+)%s*/%s*([%d%s%.]+)")
    if not a then a, b = f:match("rank points%s*:?%s*([%d,%.]+)%s*/%s*([%d,%.]+)") end
    if a then r.pts, r.cap = N((a:gsub("[^%d]", ""))), N((b:gsub("[^%d]", ""))) end
    local inc = f:match("augmentation du plafond[^:]*:%s*([%d%s%.]+)") or f:match("cap increase[^:]*:%s*([%d,%.]+)")
    if inc then r.inc = N((inc:gsub("[^%d]", ""))) end
    -- « Points de rang : » seul, valeur dans la région suivante
    if not r.pts and (f:find("points de rang", 1, true) or f:find("rank points", 1, true)) and list[i + 1] then
      local okN, nf = pcall(Fold, list[i + 1])
      local x, y = (okN and type(nf) == "string" and nf or ""):match("([%d%s%.]+)%s*/%s*([%d%s%.]+)")
      if x then r.pts, r.cap = N((x:gsub("[^%d]", ""))), N((y:gsub("[^%d]", ""))) end
    end
  end
  return r
end
function PV.ReadWindow()
  for _, name in ipairs(PV.UI_FRAMES) do
    local f = _G[name]
    if type(f) == "table" and f.IsShown and Call(f.IsShown, f) then
      local out = { n = 0 }
      ScanText(f, 0, out)
      local r = PV.ParseTexts(out)
      if r.pts and r.cap and r.cap > 0 then
        local c = CDB()
        c.rankPts, c.rankCap, c.rankInc, c.rankAt, c.rankFrom = r.pts, r.cap, r.inc or c.rankInc, Today(), name
        S.probe.window = name
        return true
      end
    end
  end
  return false
end

function PV.Read()
  if InCombat() then PV._dirty = true return nil end
  PV._dirty = nil
  PV.stats.reads = PV.stats.reads + 1
  local s = S
  s.hkToday, s.honorToday = Call(_G.GetPVPSessionStats)
  s.hkToday, s.honorToday = N(s.hkToday), N(s.honorToday)
  s.hkWeek, s.honorWeek = Call(_G.GetPVPThisWeekStats)
  s.hkWeek, s.honorWeek = N(s.hkWeek), N(s.honorWeek)
  local lhk, ldk, hr = Call(_G.GetPVPLifetimeStats)
  s.hkLife, s.dkLife, s.highest = N(lhk), N(ldk), N(hr)
  s.src.hk = s.hkToday and "GetPVPSessionStats" or "absent"
  -- rang
  local rid = N(Call(_G.UnitPVPRank, "player")) or 0
  local rname, rnum = Call(_G.GetPVPRankInfo, rid)
  s.rankID, s.rankName, s.rankNum = rid, rname, N(rnum) or 0
  s.progress = N(Call(_G.GetPVPRankProgress))
  -- points de rang : API, sinon dernière lecture de la fenêtre JcJ
  local p, c = ReadRankPointsAPI()
  if p then s.rankPts, s.rankCap, s.src.rank = p, c, S.probe.rankApi
  else
    local cdb = CDB()
    if cdb.rankPts and cdb.rankCap then s.rankPts, s.rankCap, s.src.rank = cdb.rankPts, cdb.rankCap, "fenêtre JcJ (" .. tostring(cdb.rankAt) .. ")"
    else s.rankPts, s.rankCap, s.src.rank = nil, nil, "non exposé" end
  end
  s.capInc = CDB().rankInc
  -- honneur (monnaie)
  local h, hm, how = ReadCurrency()
  s.honor, s.honorMax, s.src.honor = h, hm, how or "absent"
  -- statistiques (K/D)
  local ids = PV.FindStats()
  s.statHK = Stat(ids.hk)
  s.statDF = Stat(ids.deathsFaction)
  s.statDP = Stat(ids.deathsPlayers)
  if s.sessionBaseDF == nil and s.statDF then s.sessionBaseDF = s.statDF end
  local cdb = CDB()
  if s.lastToday ~= nil and cdb.goalDay == Today() and cdb.goal and (s.hkToday or 0) >= cdb.goal and cdb.goalDone ~= Today() then
    cdb.goalDone = Today()
    PV.Toast(string.format(Tr["Objectif JcJ atteint : %d VH aujourd'hui"], cdb.goal), "objectif")
  end
  s.lastToday = s.hkToday
  return s
end

------------------------------------------------------------------------------
-- K/D
------------------------------------------------------------------------------
function PV.FmtRatio(k, d)
  k, d = N(k) or 0, N(d) or 0
  if d <= 0 then return string.format("K/D %d/0", k) end
  local r = string.format("%.1f", k / d)
  if ns.IsFrench and ns.IsFrench() then r = r:gsub("%.", ",") end   -- 3.5.19 : virgule décimale en français seulement
  return "K/D " .. r
end
function PV.KD()
  local k = S.statHK or S.hkLife or 0
  local d, how = S.statDF, Tr["morts par la faction adverse"]
  if d == nil then d, how = S.statDP, Tr["morts par d'autres joueurs"] end
  if d == nil then d, how = CDB().deaths or 0, Tr["morts comptées par l'addon (toutes causes)"] end
  local sk = S.session.kills
  local sd = (S.statDF and S.sessionBaseDF) and (S.statDF - S.sessionBaseDF) or S.session.deaths
  return { k = k, d = d, text = PV.FmtRatio(k, d), how = how, sk = sk, sd = sd, stext = PV.FmtRatio(sk, sd) }
end

------------------------------------------------------------------------------
-- Case de la grille
------------------------------------------------------------------------------
PV.tile = { kind = "pvp", id = "pvp", key = "pvp", name = "JcJ", learned = true, inTotal = false, horsTotal = true }
function PV.RankIcon()
  local n = S.rankNum or 0
  if n > 0 then return string.format(PV.RANK_ICON, n) end
  local fac = Call(_G.UnitFactionGroup, "player")
  return fac == "Horde" and PV.ICON_HORDE or PV.ICON_ALLIANCE
end
function PV.Tile()
  local d = PV.tile
  d.name = Tr["JcJ"]   -- 3.5.19 : nom affiché selon la langue
  d.icon = PV.RankIcon()
  local cdb = CDB()
  if S.rankPts and S.rankCap then d.current, d.apiMax, d.gauge = S.rankPts, S.rankCap, "rang"
  elseif S.honor then d.current, d.apiMax, d.gauge = S.honor, (S.honorMax and S.honorMax > 0) and S.honorMax or math.max(1, S.honor), "honneur"
  else
    local g = (cdb.goalDay == Today()) and cdb.goal or nil
    d.current, d.apiMax, d.gauge = S.hkToday or 0, g or math.max(1, S.hkToday or 0), "vh"
  end
  d.placeholder = nil
  return d
end
local baseGroup = UI.GroupTiles
function UI:GroupTiles(tiles)
  local groups = baseGroup(self, tiles)
  if not PV.Enabled() or #groups == 0 then return groups end
  local g = groups[#groups]
  local copy, put = {}, false
  for _, d in ipairs(g.tiles) do
    if d.kind == "pvp" then return groups end
    if d.kind == "total" and not put then copy[#copy + 1] = PV.Tile() put = true end
    copy[#copy + 1] = d
  end
  if not put then copy[#copy + 1] = PV.Tile() end
  groups[#groups] = { title = g.title, tiles = copy, flat = g.flat }
  return groups
end

-- infobulle
local C = ns.Compact
if C and C.TooltipModel then
  local baseModel = C.TooltipModel
  function C.TooltipModel(d)
    if not (d and d.kind == "pvp") then return baseModel(d) end
    local m = { title = Tr["JcJ"], lines = {} }
    local L = m.lines
    local G = { 1, 0.82, 0 }
    local function add(t, r, g, b) if t and t ~= "" then L[#L + 1] = { t, r or 1, g or 1, b or 1, false } end end
    local function header(t) L[#L + 1] = { " ", 1, 1, 1, false, spacer = true } L[#L + 1] = { t, G[1], G[2], G[3], false, header = true } end
    local s = S
    add(Tr["Rang : "] .. tostring(s.rankName or "—") .. Tr[" (rang "] .. tostring(s.rankNum or 0) .. ")")
    if s.rankPts and s.rankCap then
      add(string.format(Tr["Points de rang : %d / %d"], s.rankPts, s.rankCap))
      if s.capInc then add(string.format(Tr["Augmentation du plafond cette semaine : %d"], s.capInc), 0.8, 0.8, 0.8) end
    else
      add(Tr["Points de rang : ouvre la fenêtre JcJ pour les lire"], 0.7, 0.7, 0.7)
    end
    header(Tr["Honneur"])
    if s.honor then add(string.format(Tr["Points d'honneur : %d%s"], s.honor, s.honorMax and s.honorMax > 0 and (" / " .. s.honorMax) or "")) end
    add(string.format(Tr["Victoires honorables : %d aujourd'hui · %d cette semaine"], s.hkToday or 0, s.hkWeek or 0))
    if s.statHK or s.hkLife then add(string.format(Tr["Total : %d"], s.statHK or s.hkLife), 0.8, 0.8, 0.8) end
    local kd = PV.KD()
    header(Tr["Combat"])
    add(kd.text .. string.format("  (%d / %d)", kd.k, kd.d), 1, 1, 1)
    add(Tr["Session : "] .. kd.stext .. string.format("  (%d / %d)", kd.sk, kd.sd), 0.8, 0.8, 0.8)
    add(string.format(Tr["Série : %d sans mourir (record %d)"], S.streak, CDB().bestStreak or 0))
    local cdb = CDB()
    if cdb.goal and cdb.goalDay == Today() then add(string.format(Tr["Objectif : %d / %d VH aujourd'hui"], s.hkToday or 0, cdb.goal), 0.4, 1, 0.4) end
    header(Tr["Clics"])
    add(Tr["Clic : fiche du personnage (hors combat) · clic droit : objectif VH du jour"], 0.7, 0.7, 0.7)
    return m
  end
end

-- clic : fenêtre JcJ (hors combat) ; clic droit : objectif
local baseSelect = UI.SelectTile
function UI:SelectTile(d, ...)
  if d and d.kind == "pvp" then return PV.OpenWindow() end
  return baseSelect(self, d, ...)
end
-- 3.5.5 : chaque moyen est ESSAYÉ puis VÉRIFIÉ (une des fenêtres JcJ change
-- d'état) ; sinon on passe au suivant. Avant, la 1re fonction trouvée était
-- appelée sans contrôle (sans effet sur Forever : TogglePVPFrame peut exister
-- sans rien ouvrir), et le clic semblait mort.
local function PvPShownState()
  local st = {}
  for _, nm in ipairs(PV.UI_FRAMES) do
    local f = _G[nm]
    if type(f) == "table" and f.IsShown then
      local ok, v = pcall(f.IsShown, f)
      st[nm] = ok and v and true or false
    end
  end
  return st
end
local function PvPChanged(before)
  local after = PvPShownState()
  for nm, v in pairs(after) do
    if nm ~= "CharacterFrame" and v ~= (before[nm] or false) then return true end
  end
  return false
end
function PV.OpenWindow()
  if InCombat() then
    if ns.Print then ns.Print(Tr["en combat : la fenêtre JcJ s'ouvrira à la fin du combat."]) end
    if ns.AfterCombat then ns.AfterCombat("pvpwindow", function() PV.OpenWindow() end) end
    return "combat"
  end
  local tries = {}
  if type(_G.ToggleCharacter) == "function" and type(_G.HonorFrame) == "table" then
    tries[#tries + 1] = { "HonorFrame", function() _G.ToggleCharacter("HonorFrame") end }
  end
  for _, fn in ipairs({ "TogglePVPFrame", "TogglePVPUI" }) do
    if type(_G[fn]) == "function" then tries[#tries + 1] = { fn, _G[fn] } end
  end
  if type(_G.ToggleCharacter) == "function" and type(_G.PVPFrame) == "table" then
    tries[#tries + 1] = { "PVPFrame", function() _G.ToggleCharacter("PVPFrame") end }
  end
  for _, t in ipairs(tries) do
    local before = PvPShownState()
    local ok = pcall(t[2])
    if ok and PvPChanged(before) then PV.lastOpen = t[1] return t[1] end
  end
  PV.lastOpen = "aucune"
  if ns.Print then ns.Print(Tr["fenêtre JcJ introuvable sur ce client (touche H du jeu)."]) end
  return nil
end
function PV.SetGoal(n)
  n = N(n)
  local c = CDB()
  if not n or n <= 0 then c.goal, c.goalDay, c.goalDone = nil, nil, nil return nil end
  c.goal, c.goalDay, c.goalDone = math.floor(n), Today(), nil
  if UI.Refresh then pcall(UI.Refresh, UI, true) end
  return c.goal
end
function PV.EnsurePopup()
  if type(_G.StaticPopupDialogs) ~= "table" then return false end
  if _G.StaticPopupDialogs.OSRS_TOTALLEVEL_PVPGOAL then return true end
  local function editOf(p) return p and (p.editBox or p.EditBox or (p.GetName and _G[(p:GetName() or "") .. "EditBox"])) end
  local function accept(p) local eb = editOf(p) if eb and eb.GetText then PV.SetGoal(eb:GetText()) end end
  _G.StaticPopupDialogs.OSRS_TOTALLEVEL_PVPGOAL = {
    text = Tr["Objectif JcJ : victoires honorables aujourd'hui (actuellement %s)"],
    button1 = _G.OKAY or "OK", button2 = _G.CANCEL or Tr["Annuler"], button3 = Tr["Effacer"],
    hasEditBox = 1, maxLetters = 4, timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
    OnShow = function(p) local eb = editOf(p) local c = CDB() if eb and eb.SetText then eb:SetText(tostring((c.goalDay == Today() and c.goal) or "")) end end,
    OnAccept = accept,
    OnAlt = function() PV.SetGoal(nil) end,
    EditBoxOnEnterPressed = function(eb) local p = eb.GetParent and eb:GetParent() accept(p) if p and p.Hide then p:Hide() end end,
    EditBoxOnEscapePressed = function(eb) local p = eb:GetParent() if p and p.Hide then p:Hide() end end,
  }
  return true
end
local basePrompt = UI.PromptGoal
function UI:PromptGoal(d, ...)
  if d and d.kind == "pvp" then
    if PV.EnsurePopup() then
      local ok = pcall(_G.StaticPopup_Show, "OSRS_TOTALLEVEL_PVPGOAL", tostring(S.hkToday or 0))
      if ok then return true end
    end
    return false
  end
  return basePrompt(self, d, ...)
end
local baseCycle = UI.CycleGoal
function UI:CycleGoal(d, ...)
  if d and d.kind == "pvp" then
    local c = CDB()
    local cur = (c.goalDay == Today() and c.goal) or (S.hkToday or 0)
    return PV.SetGoal(math.floor(cur / 10) * 10 + 10)
  end
  return baseCycle(self, d, ...)
end

------------------------------------------------------------------------------
-- Toasts (+1 vert, série, objectif) — différés en combat
------------------------------------------------------------------------------
PV.pendingKills = 0
function PV.Toast(title, kind, sub)
  if not (UI.SpawnDrop and PV.Enabled()) then return nil end
  if InCombat() then
    PV._pendingToasts = PV._pendingToasts or {}
    table.insert(PV._pendingToasts, { title, kind, sub })
    if ns.AfterCombat then ns.AfterCombat("pvptoasts", PV.FlushToasts) end
    return "queued"
  end
  PV.stats.toasts = PV.stats.toasts + 1
  local d = PV.Tile()
  local f = UI:SpawnDrop(d.icon, "|cff40ff40" .. title .. "|r", sub or "", d.current, d.apiMax, nil,
    { kind = "pvp", dedupeKey = (kind == "kill") and "pvp:kill" or nil })
  PV.Pulse()
  return f
end
function PV.FlushToasts()
  local q = PV._pendingToasts or {}
  PV._pendingToasts = nil
  local kills = PV.pendingKills
  PV.pendingKills = 0
  if PV._dirty then PV.Read() end
  if kills > 0 then PV.Toast(string.format(Tr["+%d victoire%s honorable%s"], kills, kills > 1 and "s" or "", kills > 1 and "s" or ""), "kill", string.format(Tr["%d aujourd'hui"], S.hkToday or 0)) end
  for _, e in ipairs(q) do PV.Toast(e[1], e[2], e[3]) end
  if UI.Refresh then pcall(UI.Refresh, UI, true) end
end
-- pulsation verte de la case (AnimationGroup : pas d'OnUpdate)
function PV.Pulse()
  local t
  for _, x in ipairs(UI.embed and UI.embed.tiles or {}) do if x.data and x.data.kind == "pvp" and x.IsShown and x:IsShown() then t = x end end
  if not t then return false end
  if not t._pvpGlow then
    local g = t:CreateTexture(nil, "OVERLAY", nil, 7)
    g:SetAllPoints(t)
    pcall(g.SetTexture, g, "Interface\\Buttons\\WHITE8X8")
    if g.SetBlendMode then pcall(g.SetBlendMode, g, "ADD") end
    g:SetVertexColor(PV.GREEN[1], PV.GREEN[2], PV.GREEN[3], 0.35)
    g:SetAlpha(0)
    t._pvpGlow = g
    if g.CreateAnimationGroup then
      local ag = g:CreateAnimationGroup()
      local a1 = ag:CreateAnimation("Alpha")
      if a1.SetFromAlpha then a1:SetFromAlpha(0) a1:SetToAlpha(1) end
      a1:SetDuration(0.15)
      local a2 = ag:CreateAnimation("Alpha")
      if a2.SetFromAlpha then a2:SetFromAlpha(1) a2:SetToAlpha(0) end
      a2:SetDuration(0.6)
      if a2.SetStartDelay then a2:SetStartDelay(0.15) end
      t._pvpAG = ag
    end
  end
  if t._pvpAG then t._pvpAG:Stop() t._pvpAG:Play() end
  PV.lastPulse = t
  return true
end

------------------------------------------------------------------------------
-- Événements : compteurs seulement en combat
------------------------------------------------------------------------------
function PV.OnKill(delta)
  delta = N(delta) or 1
  if delta <= 0 then return end
  PV.stats.kills = PV.stats.kills + delta
  S.session.kills = S.session.kills + delta
  local before = S.streak
  S.streak = S.streak + delta
  local c = CDB()
  if S.streak > (c.bestStreak or 0) then c.bestStreak = S.streak end
  if InCombat() then
    PV.pendingKills = PV.pendingKills + delta
    PV._dirty = true
    if ns.AfterCombat then ns.AfterCombat("pvptoasts", PV.FlushToasts) end
  else
    PV.Read()
    PV.Toast(delta > 1 and string.format(Tr["+%d victoires honorables"], delta) or Tr["+1 victoire honorable"], "kill", string.format(Tr["%d aujourd'hui"], S.hkToday or 0))
    if UI.Refresh then pcall(UI.Refresh, UI, true) end
  end
  for _, step in ipairs(PV.STREAK_STEPS) do
    if before < step and S.streak >= step then PV.Toast(string.format(Tr["Série : %d victoires sans mourir"], S.streak), "serie") end
  end
end
function PV.OnKillsChanged()
  PV.stats.events = PV.stats.events + 1
  if not PV.Enabled() then return end
  local hk = N((Call(_G.GetPVPSessionStats))) or nil
  if hk and S.lastHK and hk > S.lastHK then PV.OnKill(hk - S.lastHK)
  elseif not hk then PV.OnKill(1) end    -- API absente : l'événement compte pour 1
  if hk then S.lastHK = hk end
end
function PV.OnHonorMsg(msg)
  PV.stats.events = PV.stats.events + 1
  S.lastHonorMsg = msg
  if not InCombat() then PV._dirty = true end
end
function PV.OnDeath()
  if S.streak > 0 then S.lastStreak = S.streak end
  S.streak = 0
  S.session.deaths = S.session.deaths + 1
  local c = CDB()
  c.deaths = (c.deaths or 0) + 1
  PV._dirty = true
end
function PV.OnLogin()
  PV.Read()
  S.lastHK = S.hkToday
  if S.statDF then S.sessionBaseDF = S.statDF end
end
if ns.On then
  ns.On("PLAYER_PVP_KILLS_CHANGED", function() PV.OnKillsChanged() end)
  ns.On("CHAT_MSG_COMBAT_HONOR_GAIN", function(_, msg) PV.OnHonorMsg(msg) end)
  ns.On("PLAYER_DEAD", function() PV.OnDeath() end)
  ns.On("PLAYER_ENTERING_WORLD", function() if not InCombat() then After(1, function() pcall(PV.OnLogin) end) end end)
  ns.On("PLAYER_PVP_RANK_CHANGED", function() PV._dirty = true if not InCombat() then PV.Read() end end)
  ns.On("CURRENCY_DISPLAY_UPDATE", function() if not InCombat() and PV.Enabled() then PV._dirty = true end end)
  ns.On("PLAYER_REGEN_ENABLED", function()
    if PV._dirty and PV.Enabled() then PV.Read() end
    pcall(PV.EvalPending)
  end)
end
-- fenêtre JcJ : lecture des points de rang à l'ouverture (HookScript, lecture seule)
function PV.HookWindows()
  for _, name in ipairs(PV.UI_FRAMES) do
    local f = _G[name]
    if type(f) == "table" and f.HookScript and not PV["_hooked" .. name] then
      PV["_hooked" .. name] = true
      pcall(f.HookScript, f, "OnShow", function()
        After(0.2, function() if not InCombat() and PV.ReadWindow() then PV.Read() if UI.Refresh then pcall(UI.Refresh, UI, true) end end end)
      end)
    end
  end
end
pcall(PV.HookWindows)
if ns.On then ns.On("ADDON_LOADED", function() pcall(PV.HookWindows) end) end

------------------------------------------------------------------------------
-- Repères sur les barres de nom des joueurs ennemis
------------------------------------------------------------------------------
PV.active, PV.pool, PV.pending = {}, {}, {}
-- true = honneur, false = ennemi mais gris, nil = pas un joueur ennemi.
-- Table (cible déjà lue) ou unité.
function PV.HonorFromTarget(tg)
  if type(tg) ~= "table" or not tg.player then return nil end
  if tg.dead then return nil end
  if not tg.attackable and not tg.enemy then return nil end
  if tg.pvp == false then return nil end
  if tg.faction and tg.myFaction and tg.faction == tg.myFaction then return nil end
  local lvl = N(tg.level)
  if not lvl then return nil end
  if lvl <= 0 then return true end
  local pl = N(tg.playerLevel) or N(Call(_G.UnitLevel, "player")) or 1
  local grey = (ns.Target and ns.Target.GreyLevel) and (lvl <= ns.Target.GreyLevel(pl)) or false
  return not grey
end
function PV.HonorFor(unit)
  if type(unit) == "table" then return PV.HonorFromTarget(unit) end
  local player = (ns.Scanner and ns.Scanner.IsPlayerUnit and ns.Scanner.IsPlayerUnit(unit)) or (Call(_G.UnitIsPlayer, unit) and true or false)
  if not player then return nil end
  local attack = Call(_G.UnitCanAttack, "player", unit) and true or false
  local enemy = type(_G.UnitIsEnemy) == "function" and Call(_G.UnitIsEnemy, "player", unit) and true or false
  if not attack and not enemy then return nil end
  local pvp
  if type(_G.UnitIsPVP) == "function" then pvp = Call(_G.UnitIsPVP, unit) and true or false end
  local tg = {
    player = true, dead = Call(_G.UnitIsDead, unit) and true or false,
    attackable = attack, enemy = enemy, pvp = pvp,
    faction = Call(_G.UnitFactionGroup, unit), myFaction = Call(_G.UnitFactionGroup, "player"),
    level = N(Call(_G.UnitLevel, unit)), playerLevel = N(Call(_G.UnitLevel, "player")),
  }
  return PV.HonorFromTarget(tg)
end
local function Acquire()
  local m = table.remove(PV.pool)
  if m then return m end
  m = CreateFrame("Frame", nil, UIParent)
  m._osrsOwn = true
  if m.EnableMouse then m:EnableMouse(false) end
  m:SetSize(PV.MARK, PV.MARK)
  m.ring = m:CreateTexture(nil, "BACKGROUND")
  m.ring:SetAllPoints(m)
  pcall(m.ring.SetTexture, m.ring, "Interface\\Buttons\\WHITE8X8")
  m.icon = m:CreateTexture(nil, "ARTWORK")
  m.icon:SetPoint("TOPLEFT", m, "TOPLEFT", 1, -1)
  m.icon:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", -1, 1)
  pcall(m.icon.SetTexture, m.icon, PV.MARK_ICON)
  if m.icon.SetTexCoord then pcall(m.icon.SetTexCoord, m.icon, 0.07, 0.93, 0.07, 0.93) end
  return m
end
function PV.Release(unit)
  local m = PV.active[unit]
  if not m then return end
  m:Hide() m:ClearAllPoints()
  PV.active[unit] = nil
  PV.pool[#PV.pool + 1] = m
end
function PV.Evaluate(unit)
  if ns.PausedForFlight and ns.PausedForFlight() then
    if unit and PV.Release then pcall(PV.Release, unit) end
    return nil
  end
  if InCombat() then PV.pending[unit] = true return nil end
  if not (PV.Enabled() and ns.Opt and ns.Opt("pvpMarks")) then PV.Release(unit) return nil end
  local honor = PV.HonorFor(unit)
  if honor == nil then PV.Release(unit) return nil end
  local plate = type(_G.C_NamePlate) == "table" and Call(_G.C_NamePlate.GetNamePlateForUnit, unit)
  if type(plate) ~= "table" then PV.Release(unit) return nil end
  local m = PV.active[unit] or Acquire()
  PV.active[unit] = m
  local c = honor and PV.GREEN or PV.GREY
  m.ring:SetVertexColor(c[1], c[2], c[3], 1)
  if m.icon.SetVertexColor then pcall(m.icon.SetVertexColor, m.icon, c[1], c[2], c[3], 1) end
  if m.icon.SetDesaturated then pcall(m.icon.SetDesaturated, m.icon, not honor) end
  m._honor = honor
  m:ClearAllPoints()
  if ns.Gather and ns.Gather.Anchor then pcall(ns.Gather.Anchor, m, plate)
  else pcall(m.SetPoint, m, "BOTTOM", plate, "TOP", 0, 2) end
  m:Show()
  PV.stats.marks = PV.stats.marks + 1
  return m
end
function PV.EvalPending()
  for unit in pairs(PV.pending) do PV.pending[unit] = nil pcall(PV.Evaluate, unit) end
end
if ns.On then
  ns.On("NAME_PLATE_UNIT_ADDED", function(_, unit) if unit then if InCombat() then PV.pending[unit] = true else pcall(PV.Evaluate, unit) end end end)
  ns.On("NAME_PLATE_UNIT_REMOVED", function(_, unit) if unit then PV.pending[unit] = nil if not InCombat() then PV.Release(unit) else local m = PV.active[unit] if m then m:Hide() end end end end)
end

------------------------------------------------------------------------------
-- /drop pvp on|off | objectif N | marques on|off
------------------------------------------------------------------------------
function PV.SetEnabled(on)
  ns.db.ui = ns.db.ui or {}
  if on then ns.db.ui.pvp = nil else ns.db.ui.pvp = false end
  if not on then for u in pairs(PV.active) do PV.Release(u) end else PV.Read() end
  local L, W = ns.Layout, ns.Window
  if L and L.Apply and W and W.frame then pcall(L.Apply) end
  if UI.Refresh then pcall(UI.Refresh, UI, true) end
  if L and L.Center then pcall(L.Center) end
  return PV.Enabled()
end
ns.SlashExt = ns.SlashExt or {}
ns.SlashExt.pvp = function(rest)
  local a, b = (rest or ""):match("^%s*(%S*)%s*(%S*)")
  a = (a or ""):lower()
  if a == "on" or a == "off" then
    Say(Tr["module JcJ "] .. (PV.SetEnabled(a == "on") and Tr["activé"] or Tr["désactivé"]))
  elseif a == "objectif" or a == "goal" then
    local g = PV.SetGoal(b)
    Say(g and (Tr["objectif JcJ : "] .. g .. Tr[" VH aujourd'hui"]) or Tr["objectif JcJ effacé"])
  elseif a == "marques" or a == "reperes" then
    if b == "off" then ns.db.ui.pvpMarks = false else ns.db.ui.pvpMarks = nil end
    for u in pairs(PV.active) do PV.Release(u) end
    Say(Tr["repères JcJ sur les barres de nom : "] .. (ns.Opt("pvpMarks") and "on" or "off"))
  else
    PV.Read()
    local kd = PV.KD()
    Say(string.format(Tr["JcJ : %d VH aujourd'hui, %d cette semaine, %s, série %d (usage : /drop pvp on|off · objectif N · marques on|off)"], S.hkToday or 0, S.hkWeek or 0, kd.text, S.streak))
  end
end
ns.SlashExt.jcj = ns.SlashExt.pvp
ns.HelpExt = ns.HelpExt or {}
ns.HelpExt[#ns.HelpExt + 1] = "/drop pvp on|off · objectif N · marques on|off : module JcJ (case, repères ennemis, série, K/D)"

ns.DebugExt = ns.DebugExt or {}
ns.DebugExt[#ns.DebugExt + 1] = function()
  local p = S.probe
  return {
    "— JcJ (3.3.13) — " .. (PV.Enabled() and "actif" or "désactivé") .. string.format(" ; VH jour %s, semaine %s ; événements %d, repères %d, toasts %d",
      tostring(S.hkToday), tostring(S.hkWeek), PV.stats.events, PV.stats.marks, PV.stats.toasts),
    "  rang : " .. tostring(S.rankName) .. " (" .. tostring(S.rankNum) .. ") ; points de rang : " .. tostring(S.src.rank) .. " ; " .. tostring(p.cpvp or "C_PvP non sondé"),
    "  honneur : " .. tostring(S.src.honor) .. " ; statistiques : " .. tostring(p.stats or "non lues") .. " ; GetPVPRankProgress " .. tostring(S.progress),
  }
end
