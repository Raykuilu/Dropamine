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

-- 3.13.0 : visite (Setup) : cadre du jeu, 8 pages, aperçus de thème, Récompenses (5 cases, 3 essais), récap final
local theme = "dropamine"
local ui = { dropsEnabled = false, levelUpSound = true, sounds = true }
_G.BackdropTemplateMixin = {}
-- trait à losange : atlas du jeu simulé (280 px de large, plus large que l'aperçu)
_G.C_Texture = { GetAtlasInfo = function() return { file = "atlas", width = 280, height = 40, leftTexCoord = 0, rightTexCoord = 1, topTexCoord = 0, bottomTexCoord = 1 } end }
local skinned = 0
local ns = { db = { ui = ui }, EnsureDB = function() return { ui = ui } end,
  STYLE = { BORDER = { 0.65, 0.49, 0.27, 1 }, ICON_CROP = { 0.08, 0.92, 0.08, 0.92 } },
  Theme = { Choice = function() return theme end, Mode = function() return "flare" end, Set = function(v) theme = v return v end,
    Round = function() return "masque arrondi" end, IconSkin = function(t) skinned = skinned + 1 rawset(t, "_bevel", {}) return t._bevel end },
  N = tonumber, On = function() end, Print = function() end, SlashExt = {}, HelpExt = {}, DebugExt = {},
  Opt = function() return true end, L = setmetatable({}, { __index = function(_, k) return k end }),
  CharDB = function() return { progress = {}, lastTotal = 1464 } end, GetPlayerLevel = function() return 37 end, TOTAL_MAX = 2460,
  SetOpt = function(k, v) ui[k] = v end, UI = { snapshot = { total = 1464, totalMax = 2460, tiles = {} } } }
setmetatable(ns, { __index = function() return nil end })
assert(loadfile("Skin.lua"))("Dropamine", ns)
assert(loadfile("DebugWindow.lua"))("Dropamine", ns)
assert(loadfile("ProgressUI.lua"))("Dropamine", ns)
assert(loadfile("Setup.lua"))("Dropamine", ns)
local S = ns.Setup
assert(#S.STEPS == 8, "8 pages : " .. #S.STEPS)
local ok, err = pcall(S.Open)
assert(ok, "ouverture : " .. tostring(err))
local f = _G.DropamineSetupFrame
assert(f and f._tpl == "PortraitFrameTemplate", "cadre du jeu à portrait")
assert(#f.dots == 8 and #f.themeCards == 3, "points et aperçus")
for i = 1, #S.STEPS do
  local okS, e = pcall(S.Show, i) assert(okS, "page " .. i .. " : " .. tostring(e))
end
-- Récompenses : 5 cases, 3 boutons d'essai
local rw
for i, st in ipairs(S.STEPS) do if st.title == "Récompenses" then rw = i end end
S.Show(rw)
local shown = 0
for _, r in ipairs(f.checks) do if r.cb:IsShown() then shown = shown + 1 end end
assert(shown == 5, "Récompenses : cases " .. shown)
-- aperçus fidèles : vrai cadre du thème (épais + trait pour Dropamine, fin pour Neutre, aucun pour Léger),
-- 3 cases habillées comme les vraies, quel que soit le thème actif
local Sk = ns.Skin
local cards = {}
for _, c in ipairs(f.themeCards) do cards[c.mode] = c end
local d, n, l = cards.dropamine, cards.neutre, cards.leger
assert(d.preview and d.preview._previewEdge == Sk.EDGE_FILE_THICK, "aperçu Dropamine : bord épais")
assert(d.preview._art and #d.preview._art == 2, "aperçu Dropamine : trait à losange en haut et en bas")
for _, o in ipairs(d.preview._art) do
  assert(o._lineTex and o._lineTex.L and o._lineTex.R, "aperçu Dropamine : bouts du trait")
end
assert(n.preview and n.preview._previewEdge == Sk.EDGE_FILE and not n.preview._art, "aperçu Neutre : bord fin, sans trait")
assert(l.preview == nil, "aperçu Léger : sans cadre")
for _, c in ipairs({ d, n, l }) do
  assert(#c.previewTiles == 3, c.mode .. " : 3 cases")
  local par = c.previewTiles[1]._parent
  assert(par == (c.preview or c), c.mode .. " : cases dans le mini-panneau")
end
assert(skinned == 9, "cases habillées comme les vraies : " .. skinned)
assert(Sk.PreviewHost(stub(), "leger") == nil and Sk.PreviewHost(stub(), "neutre"), "PreviewHost : léger sans cadre")
-- la page « Les cases » tient dans la fenêtre (420 px) : boutons au-dessus des points de progression
assert(f.cardH <= 92 + 20, "cartes : +20 px au plus (" .. f.cardH .. ")")
-- aperçu de thème : un clic change le thème
f.themeCards[2]:GetScript("OnMouseUp")()
assert(theme == "neutre", "clic sur l’aperçu Neutre : " .. theme)
-- récap : thème, activé / coupé
local recap = S.RecapText()
assert(recap:find("Neutre", 1, true) and recap:find("Coupé :", 1, true) and recap:find("Notifications de gain", 1, true), "récap : " .. recap)
print("OK : visite — cadre du jeu, 8 pages, Récompenses, aperçus de thème (vrai cadre + vraies cases), récap final")
