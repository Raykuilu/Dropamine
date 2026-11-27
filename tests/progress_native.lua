-- 3.13.0 : fenêtre Progression, thème « jeu » (cadre 100 % Blizzard) et thème « dropamine » (charte du site) : construction complète
-- avec de faux objets d'interface, puis thème, onglets et en-tête ; aucune erreur Lua attendue dans les deux cadres.
local NUM = { GetWidth = 60, GetHeight = 20, GetStringWidth = 50, GetFrameLevel = 5, GetNumPoints = 0, GetAlpha = 1, GetScale = 1, GetLeft = 0, GetTop = 0, GetRight = 0, GetBottom = 0 }
local stub
local function mk(kind, tpl)
  local o = { _kind = kind, _tpl = tpl, _shown = true }
  return setmetatable(o, { __index = function(t, k)
    if type(k) ~= "string" or not k:match("^%u") then return nil end   -- champs (minuscules) : vides, comme en jeu
    if NUM[k] then return function() return NUM[k] end end
    if k == "IsShown" or k == "IsVisible" then return function(self) return rawget(self, "_shown") end end
    if k == "Show" then return function(self) rawset(self, "_shown", true) end end
    if k == "Hide" then return function(self) rawset(self, "_shown", false) end end
    if k == "GetText" then return function() return "" end end
    if k == "GetName" then return function(self) return rawget(self, "_name") end end
    if k == "GetParent" then return function(self) return rawget(self, "_parent") or stub() end end
    if k == "GetFontString" then return function() return stub() end end
    if k == "SetScript" or k == "HookScript" then return function(self, n, f) local s = rawget(self, "_scripts") or {} rawset(self, "_scripts", s) s[n] = f end end
    if k == "GetScript" then return function(self, n) local s = rawget(self, "_scripts") return s and s[n] end end
    if k:match("^Create") then return function(self) local c = stub() rawset(c, "_parent", self) return c end end
    if k:match("^Is") or k:match("^Has") then return function() return false end end
    if k:match("^Get") then return function() return nil end end
    return function() end
  end })
end
stub = function() return mk("obj") end
local created = {}
_G.CreateFrame = function(kind, name, parent, tpl)
  local f = mk(kind, tpl) rawset(f, "_name", name) rawset(f, "_parent", parent)
  created[#created + 1] = f
  if name then _G[name] = f end
  return f
end
_G.UIParent = stub()
_G.UISpecialFrames = {}
_G.GameTooltip = stub()
_G.PanelTemplates_SelectTab = function(t) rawset(t, "_sel", true) end
_G.PanelTemplates_DeselectTab = function(t) rawset(t, "_sel", false) end
_G.PanelTemplates_TabResize = function() end
_G.UnitName = function() return "Ray" end
_G.UnitClass = function() return "Druide", "DRUID" end
_G.UnitLevel = function() return 37 end
_G.InCombatLockdown = function() return false end
_G.GetTime = function() return 100 end
_G.time = os.time
_G.date = os.date

local function boot(style, pre)
  created = {}
  local ns = { db = { ui = {} }, Theme = { Choice = function() return style end, Mode = function() return style == "dropamine" and "flare" or "classic" end }, N = tonumber, On = function() end, Print = function() end, SlashExt = {}, HelpExt = {}, DebugExt = {},
    Opt = function() return true end, L = setmetatable({}, { __index = function(_, k) return k end }),
    CharDB = function() return { progress = {}, lastTotal = 1464 } end, GetPlayerLevel = function() return 37 end, TOTAL_MAX = 2460,
    UI = { snapshot = { total = 1464, totalMax = 2460, tiles = {} } } }
  setmetatable(ns, { __index = function() return nil end })
  if pre then pre(ns) end
  assert(loadfile("DebugWindow.lua"))("Dropamine", ns)
  assert(loadfile("ProgressUI.lua"))("Dropamine", ns)
  local PU = ns.ProgressUI
  local ok, err = pcall(PU.Build)
  assert(ok, style .. " : construction : " .. tostring(err))
  assert(PU.frame, style .. " : pas de fenêtre")
  return ns, PU
end

-- cadre « jeu »
local ns, PU = boot("jeu")
assert(PU.native == true, "cadre jeu : mode natif")
assert(PU.frame._tpl == "PortraitFrameTemplate", "cadre jeu : PortraitFrameTemplate")
local tabs, buttons = 0, 0
for _, f in ipairs(created) do
  if f._tpl == "TabButtonTemplate" then tabs = tabs + 1 end
  if f._tpl == "UIPanelButtonTemplate" then buttons = buttons + 1 end
end
assert(tabs >= 6, "onglets du jeu : " .. tabs)
assert(buttons >= 3, "boutons du jeu : " .. buttons)
local bd = 0
for _, c in ipairs(PU.cards) do if c._bd then bd = bd + 1 end end
assert(bd == #PU.cards and bd > 0, "encadrés du jeu : " .. bd .. "/" .. #PU.cards)
for _, call in ipairs({ "ApplyTheme", "LayoutTabs", "SyncPills" }) do
  local ok, err = pcall(PU[call]) assert(ok, "cadre jeu : " .. call .. " : " .. tostring(err))
end
-- onglet choisi = onglet du jeu sélectionné
local any = false
for _, b in ipairs(PU.frame.tabs) do if b.isTab then PU.SetOn(b, true) any = rawget(b, "_sel") == true break end end
assert(any, "onglet du jeu sélectionné")

-- thème « dropamine » : la fenêtre garde le cadre du jeu (le thème ne touche que les cases)
local _, PU2 = boot("dropamine")
assert(PU2.native, "thème dropamine : fenêtre au cadre du jeu")
for _, call in ipairs({ "ApplyTheme", "LayoutTabs" }) do
  local ok, err = pcall(PU2[call]) assert(ok, "cadre dropamine : " .. call .. " : " .. tostring(err))
end
print("OK : fenêtre Progression — cadre jeu (onglets, boutons, encadrés, barre du total, nom lisible), quel que soit le thème")

-- 3.13.0 : 6 onglets, vues en pastilles, onglet Compétences
do
  local ns3, PU3 = boot("jeu")
  local ids = {}
  for _, t in ipairs(PU3.TABS) do ids[#ids + 1] = t.id end
  assert(table.concat(ids, ",") == "overview,skills,farm,collection,ach,chars", "onglets : " .. table.concat(ids, ","))
  assert(PU3.GroupOf("charts") == "overview" and PU3.GroupOf("weekly") == "overview" and PU3.GroupOf("hunt") == "collection", "vues rangées")
  -- historique : cuisine +20 aujourd'hui, +37 il y a 3 jours ; bâtons +5 hier
  local days = { ["2026-11-27"] = { skills = { cooking = 20 } }, ["2026-11-26"] = { skills = { staves = 5 } }, ["2026-11-24"] = { skills = { cooking = 37 } } }
  local function off(day, n) local y, m, d = day:match("(%d+)-(%d+)-(%d+)") local t = os.time({ year = y, month = m, day = d + n, hour = 12 }) return os.date("%Y-%m-%d", t) end
  ns3.Progress = { C = function() return {}, { history = days } end, Today = function() return "2026-11-27" end, DayOffset = off }
  ns3.UI.snapshot = { total = 1464, totalMax = 2460, allTiles = {
    { id = "level", kind = "level", name = "Niveau", current = 37 },
    { id = "staves", kind = "melee", name = "Bâtons", current = 110, apiMax = 185 },
    { id = "cooking", kind = "secondary", name = "Cuisine", current = 218, apiMax = 225 },
    { id = "str", kind = "stat", name = "Force", current = 50 },
    { id = "riding", kind = "secondary", name = "Monte", current = 75, apiMax = 75 },
  } }
  local list = PU3.SortSkills(PU3.SkillList(), "gain")
  assert(#list == 3, "3 compétences (pas de caractéristique ni de monte) : " .. #list)
  assert(list[1].key == "cooking" and list[1].today == 20 and list[1].w7 == 57, "cuisine en tête : +20 jour, +57 sur 7 j")
  assert(list[2].key == "staves" and list[2].w7 == 5, "bâtons ensuite")
  assert(PU3.SortSkills(PU3.SkillList(), "gap")[1].key == "staves", "plus loin du max : bâtons (75 points)")
  local det = PU3.SkillDetail(list[1])
  local labels = {} for _, l in ipairs(det) do labels[#labels + 1] = l[1] end
  local txt = table.concat(labels, "|")
  assert(txt:find("Rythme récent") and txt:find("Maximum estimé"), "détail : " .. txt)
  -- rafraîchir l'onglet, changer de vue
  PU3.frame.IsShown = function() return true end
  assert(pcall(PU3.RefreshSkills, PU3.frame.pages.skills), "onglet Compétences rafraîchi")
  -- clic sur l'onglet : la page Compétences reste choisie (une liste blanche la renvoyait sur Aperçu)
  for _, btn in ipairs(PU3.frame.tabs) do if btn.id == "skills" then local s = rawget(btn, "_scripts") s.OnClick(btn) end end
  assert(PU3.State().tab == "skills", "onglet Compétences : " .. tostring(PU3.State().tab))
  assert(PU3.SetTab("weekly", true) == "weekly" and PU3.GroupDefault("overview") == "weekly", "Aperçu se rouvre sur la dernière vue")
  assert(PU3.SetTab("hunt", true) == "hunt" and PU3.GroupDefault("collection") == "hunt", "Collection se rouvre sur la Chasse")
end
print("OK : 6 onglets, vues Aperçu / Collection, onglet Compétences (gains, tri, détail)")

-- 3.13.0 : Farm — vues Maintenant · Spots · Efficacité ; session ici, ce qu'il manque, objectifs ; meilleures zones et tendance
do
  local spots = {
    herbalism = { { zone = "Les Tarides", pts = 30, avg = 1.0, trend = "slower" }, { zone = "Mulgore", pts = 12, avg = 2.0, trend = "steady" } },
    fishing = { { zone = "Les Tarides", pts = 5, avg = 3.0 } },
  }
  local _, PU4 = boot("jeu", function(ns)
    ns.Progress = { Zone = function() return "Les Tarides" end, Session = function() return { zoneGather = { ["Les Tarides"] = 12 } } end,
      Spots = function(id) return spots[id] or {} end, AllSpots = function() return {} end, UnlockedCount = function() return 1, 2 end,
      SkillLabel = function(k) return k end, Dur = function(s) return math.floor(s / 60) .. " min" end }
    ns.Efficiency = {
      Sess = function() return { zoneSecs = { ["Les Tarides"] = 1800 }, lootByZone = { ["Les Tarides"] = { value = 50000 } }, bagMiss = 2 } end,
      SessionItems = function() return { { id = 2447, n = 14 }, { id = 765, n = 6 } } end,
      GoalList = function() return { { i = 1, id = 2770, qty = 20, have = 8, frac = 0.4, name = "Minerai de cuivre" } } end,
      FormatMoney = function(c) return math.floor(c / 10000) .. "po" end,
      Report = function() return { moneyByZone = { ["Les Tarides"] = { net = 80000 } }, zoneSecs = { ["Les Tarides"] = 3600 } } end,
    }
    ns.Slot = { FreeBagSlots = function() return 2 end }
  end)
  local ids = {}
  for _, t in ipairs(PU4.TABS) do if t.id == "farm" then ids = t.pages end end
  assert(table.concat(ids, ",") == "now,spots,efficiency", "vues Farm : " .. table.concat(ids, ","))
  assert(PU4.GroupDefault("farm") == "now", "Farm s'ouvre sur Maintenant")
  assert(pcall(PU4.RefreshFarmNow, PU4.frame.pages.now), "vue Maintenant rafraîchie")
  local best = PU4.BestSpots()
  assert(#best == 2 and best[1].skill == "herbalism" and best[1].zone == "Les Tarides", "meilleure zone d'herboristerie")
  assert(best[1].pts == 30 and best[1].ptsh == nil, "meilleure zone : 30 points, plus de points/heure")
  assert(best[1].gold and math.abs(best[1].gold.gph - 80000) < 1e-6, "or/h de la zone (30 j)")
  assert(pcall(PU4.RefreshSpots, PU4.frame.pages.spots), "vue Spots rafraîchie")
end
print("OK : Farm — Maintenant (session, butin, sacs, objectifs), Spots (meilleures zones par points, or/h)")
