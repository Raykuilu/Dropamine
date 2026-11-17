-- Dropamine 3.3.19 / 3.4.0 / 3.4.3 — MÉTIER EN COURS + LIENS MÉTIERS.
-- Cause du bug (Pêche jamais verte en pêchant, Cuisine jamais verte en
-- cuisinant) : la surbrillance verte ne venait QUE de la cible
-- (PLAYER_TARGET_CHANGED) ; rien n'écoutait les sorts lancés par le joueur ni
-- la fenêtre de métier ouverte.
--   * FORT (vert plein, « +1 ») : le joueur lance / canalise une action de
--     métier (UNIT_SPELLCAST_START / CHANNEL_START, unité "player") : Pêche
--     (canalisation), toute recette lancée pendant qu'une fenêtre de métier est
--     ouverte (Cuisine, Secourisme, Couture…), cueillette / minage / dépeçage.
--     Reconnaissance SANS texte anglais : identifiant de sort, puis nom LOCALISÉ
--     lu par GetSpellInfo(id du sort de métier) comparé au nom lu en jeu
--     (même langue que le client), puis recettes lues dans la fenêtre du métier.
--   * DISCRET (« + » pâle) : canne à pêche équipée (GetItemInfoInstant : classe
--     2, sous-classe 20) → Pêche ; fenêtre du métier ouverte → ce métier.
--   * LIEN (voile très léger, sans marque) : fenêtre de métier ouverte → les
--     métiers qui lui fournissent ses matières (Secourisme ← Couture / tissu,
--     Cuisine ← Pêche, Travail du cuir ← Dépeçage, Forge / Ingénierie ← Minage,
--     Alchimie ← Herboristerie…), plus les métiers dont les recettes LUES en
--     jeu partagent un composant (données de Links / recettes du personnage).
-- Le détail (pourquoi) n'apparaît qu'au survol de la case.
-- Coût : aucun OnUpdate ; quelques événements du joueur seulement ; liens
-- calculés une fois par ouverture de fenêtre (cache) ; rien n'est recalculé en
-- combat (la peinture réutilise le résultat) ; nos cases seulement.
local ADDON, ns = ...
local UI, T, W = ns.UI, ns.Target, ns.Window
if not (UI and T) then return end
local A = {}
ns.Activity = A

local function N(v) return ns.N and ns.N(v) or tonumber(v) end
local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local r = { pcall(fn, ...) }
  if not r[1] then return nil end
  return unpack(r, 2)
end
local function Str(v) if type(v) ~= "string" or (ns.IsSecret and ns.IsSecret(v)) or v == "" then return nil end return v end
local function Fold(s) return (ns.Fold and ns.Fold(s or "")) or tostring(s or ""):lower() end

-- Sorts de métier (identifiants Classic) : le 1er sert de nom localisé de référence.
A.SPELLS = {
  fishing = { 7620, 7731, 7732, 18248 },
  cooking = { 2550, 3102, 3413, 18260 },
  firstaid = { 3273, 3274, 7924, 10846 },
  tailoring = { 3908, 3909, 3910, 12180 },
  leatherworking = { 2108, 3104, 3811, 10662 },
  blacksmithing = { 2018, 3100, 3538, 9785 },
  alchemy = { 2259, 3101, 3464, 11611 },
  engineering = { 4036, 4037, 4038, 12656 },
  enchanting = { 7411, 7412, 7413, 13920 },
  mining = { 2575, 2576, 3564, 10248, 2656 },      -- Minage (récolte) + Fondre
  herbalism = { 2366, 2368, 3570, 11993 },
  skinning = { 8613, 8617, 8618, 10768 },
}
-- Fournisseurs de matières (relation de jeu, aucune valeur chiffrée).
A.FEEDS = {
  firstaid = { "tailoring" }, cooking = { "fishing" }, leatherworking = { "skinning" },
  blacksmithing = { "mining" }, engineering = { "mining" }, alchemy = { "herbalism" },
  tailoring = { "firstaid" }, enchanting = { "tailoring" },
}
A.FR = {
  fishing = "Pêche", cooking = "Cuisine", firstaid = "Secourisme", tailoring = "Couture", leatherworking = "Travail du cuir",
  blacksmithing = "Forge", alchemy = "Alchimie", engineering = "Ingénierie", enchanting = "Enchantement", mining = "Minage",
  herbalism = "Herboristerie", skinning = "Dépeçage",
}
A.VEIL_LINK = 0.05
A.stats = { events = 0, paints = 0, linkComputes = 0 }
A.cast = nil          -- { skill, spell, name }
A.window = nil        -- métier dont la fenêtre est ouverte
A.pole = false

function A.Enabled()
  if ns.db and ns.db.ui and ns.db.ui.activity == false then return false end
  return T.Enabled == nil or T.Enabled()
end

-- index id de sort → métier ; nom localisé → métier (construit une fois)
local byId, byName
local function Index()
  if byId then return end
  byId, byName = {}, {}
  for skill, ids in pairs(A.SPELLS) do
    for _, id in ipairs(ids) do
      byId[id] = skill
      local nm = Str(Call(_G.GetSpellInfo, id))
      if nm then byName[Fold(nm)] = byName[Fold(nm)] or skill end
    end
  end
end
A._reindex = function() byId, byName = nil, nil end

-- métier d'un nom de fenêtre / de sort lu en jeu (langue du client)
function A.SkillForName(name)
  name = Str(name)
  if not name then return nil end
  Index()
  local s = byName[Fold(name)]
  if s then return s end
  local id = ns.Style and ns.Style.SkillIdForText and ns.Style.SkillIdForText(name)
  if id and A.FR[id] then return id end
  return nil
end

-- recette connue (lue dans la fenêtre du métier) → métier
local function RecipeSkill(name)
  local f = Fold(name)
  if f == "" then return nil end
  local rec = ns.CharDB and ns.CharDB().recipes
  for skill, r in pairs(rec or {}) do
    for _, k in ipairs(r.list or {}) do if Fold(k.name) == f then return skill end end
  end
  return nil
end

local function WindowListKnown(skill)
  local rec = ns.CharDB and ns.CharDB().recipes
  return rec and rec[skill] and rec[skill].list and #rec[skill].list > 0
end
A.learned = {}       -- nom de sort → métier appris par un message « Votre compétence en … »
local function CTradeSkill(id)
  local C = _G.C_TradeSkillUI
  if not (id and type(C) == "table") then return nil end
  if type(C.GetTradeSkillLineForRecipe) == "function" then
    local _, lineName, parent = Call(C.GetTradeSkillLineForRecipe, id)
    local s = A.SkillInText(lineName)
    if s then return s end
  end
  if type(C.GetRecipeInfo) == "function" then
    local info = Call(C.GetRecipeInfo, id)
    if type(info) == "table" and info.learned ~= nil then
      local s = A.window
      if s then return s end
    end
  end
  return nil
end
-- en combat sans fenêtre de métier : seulement la table des sorts (aucune chaîne créée)
function A.QuickSkill(spellID) Index() local id = N(spellID) return id and byId[id] or nil end
function A.SkillForSpell(spellID, name)
  Index()
  local id = N(spellID)
  if id and byId[id] then A._mapSrc = "sort de métier connu" return byId[id] end
  name = Str(name) or (id and Str(Call(_G.GetSpellInfo, id)))
  if name then
    local s = byName[Fold(name)]
    if s then A._mapSrc = "nom du métier" return s end
    -- recette lue dans une fenêtre de métier (nom localisé du client)
    s = RecipeSkill(name)
    if s then A._mapSrc = "recette en cache" return s end
    s = A.learned[Fold(name)]
    if s then A._mapSrc = "appris (message de compétence)" return s end
  end
  local c = CTradeSkill(id)
  if c then A._mapSrc = "C_TradeSkillUI" return c end
  -- fenêtre ouverte mais recettes pas encore lues : on fait confiance à la fenêtre
  if A.window and not WindowListKnown(A.window) then A._mapSrc = "fenêtre ouverte" return A.window end
  return nil
end

-- 3.4.3 : fenêtre de métier, DÉTECTION ROBUSTE (cause du bug 3.4.2 : à
-- TRADE_SKILL_SHOW notre gestionnaire passait AVANT que le jeu n'affiche la
-- fenêtre — TradeSkillFrame:IsShown() était encore faux — et l'interface de
-- métiers de Forever n'est pas forcément TradeSkillFrame ; rien n'était donc lu,
-- et « Bandage en laine » n'était pas une recette déjà en cache).
-- Sources, dans l'ordre, chacune notée dans A.diag.src :
--   1. API : GetTradeSkillLine / C_TradeSkillUI.* (Scanner.TradeLineName), GetCraftDisplaySkillLine ;
--   2. titre de la fenêtre visible (TitleText, …TitleText, GetTitleText) ;
--   3. barre de rang de la fenêtre (« Secourisme 139/150 ») ;
-- le texte est rapproché de nos noms de cases (Style.SkillIdForText, sous-chaîne).
A.FRAMES = { "TradeSkillFrame", "ProfessionsFrame", "CraftFrame" }
A.diag = { frame = nil, src = nil, text = nil, castName = nil, castID = nil, castSrc = nil, castSkill = nil, why = nil, events = {} }
local function Shown(f) return type(f) == "table" and f.IsShown and Call(f.IsShown, f) and true or false end
local function TextOf(o)
  if type(o) ~= "table" then return nil end
  if o.GetText then return Str(Call(o.GetText, o)) end
  return nil
end
-- nom d'un métier dans un texte quelconque (titre, barre, message)
function A.SkillInText(text)
  text = Str(text)
  if not text then return nil end
  local s = A.SkillForName(text)
  if s then return s end
  local id = ns.Style and ns.Style.SkillIdForText and ns.Style.SkillIdForText(text)
  if id and A.FR[id] then return id end
  Index()
  local f, best, bl = Fold(text), nil, 0
  for nm, sk in pairs(byName) do if #nm > bl and f:find(nm, 1, true) then best, bl = sk, #nm end end
  return best
end
local function FrameTexts(f, n)
  local out = {}
  local function add(o) local t = TextOf(o) if t then out[#out + 1] = t end end
  add(rawget(f, "TitleText")) add(rawget(f, "TitleContainer") and rawget(f.TitleContainer, "TitleText"))
  add(_G[n .. "TitleText"])
  if f.GetTitleText then add(Call(f.GetTitleText, f)) end
  return out
end
local function BarTexts(n)
  local out = {}
  local base = n:gsub("Frame$", "")      -- TradeSkillFrame → TradeSkillRankFrameSkillName (noms Classic)
  for _, pre in ipairs({ base, n }) do
    for _, k in ipairs({ "RankFrameSkillName", "RankFrameSkillRank", "RankFrameText", "SkillName" }) do
      local t = TextOf(_G[pre .. k]) if t then out[#out + 1] = t end
    end
  end
  local rf = _G[n] and rawget(_G[n], "RankFrame")
  if rf then local t = TextOf(rawget(rf, "Text") or rawget(rf, "SkillName")) if t then out[#out + 1] = t end end
  return out
end
function A.ReadWindow()
  local fname
  for _, n in ipairs(A.FRAMES) do if Shown(_G[n]) then fname = n break end end
  local apiOpen = A._apiOpen
  A.diag.frame = fname or (apiOpen and "(événement, fenêtre pas encore visible)") or nil
  if not fname and not apiOpen then A.diag.src, A.diag.text = nil, nil return nil end
  -- 1. API
  local nm, src
  if ns.Scanner and ns.Scanner.TradeLineName then nm, src = ns.Scanner.TradeLineName() end
  nm = Str(nm)
  if not nm then nm = Str(Call(_G.GetTradeSkillLine)) src = nm and "GetTradeSkillLine" end
  if nm == "UNKNOWN" then nm = nil end
  if not nm and (fname == "CraftFrame" or A._craftOpen) then
    nm = Str(Call(_G.GetCraftDisplaySkillLine)) or Str(Call(_G.GetCraftName)) src = nm and "GetCraftDisplaySkillLine"
  end
  local sk = nm and A.SkillInText(nm)
  -- 2. titre, 3. barre de rang
  if not sk and fname then
    for _, t in ipairs(FrameTexts(_G[fname], fname)) do sk = A.SkillInText(t) if sk then nm, src = t, "titre de " .. fname break end end
    if not sk then
      for _, t in ipairs(BarTexts(fname)) do sk = A.SkillInText(t) if sk then nm, src = t, "barre de rang de " .. fname break end end
    end
  end
  A.diag.src, A.diag.text = sk and src or (nm and (tostring(src) .. " (non reconnu)") or "aucune source"), nm
  return sk
end

-- canne à pêche en main droite : classe 2 (arme), sous-classe 20 (canne)
function A.PoleEquipped()
  local id = N(Call(_G.GetInventoryItemID, "player", 16))
  if not id then return false end
  local fn = _G.GetItemInfoInstant or (type(_G.C_Item) == "table" and _G.C_Item.GetItemInfoInstant)
  if type(fn) ~= "function" then return false end
  local _, _, _, _, _, cid, sid = Call(fn, id)
  return N(cid) == 2 and N(sid) == 20
end

local function HasTile(skill)
  for _, t in ipairs(UI.embed and UI.embed.tiles or {}) do
    local d = t.data
    if d and not d.placeholder and d.id == skill then return true end
  end
  return false
end

-- liens d'un métier ouvert (cache par métier + version des recettes)
A._links = {}
function A.LinksFor(skill)
  local key = tostring(skill) .. ":" .. tostring(ns.Craft and ns.Craft._ver) .. ":" .. tostring(ns.Scanner and ns.Scanner._learnVer)
  local hit = A._links[key]
  if hit then return hit end
  A.stats.linkComputes = A.stats.linkComputes + 1
  local out, seen = {}, { [skill] = true }
  local function add(sk, why)
    if not sk or seen[sk] then return end
    seen[sk] = true
    out[#out + 1] = { skill = sk, why = why }
  end
  for _, sk in ipairs(A.FEEDS[skill] or {}) do
    add(sk, "lien : fournit des matières à " .. tostring(A.FR[skill] or skill))
  end
  -- composants partagés (recettes lues en jeu + base de l'addon)
  local rec = ns.CharDB and ns.CharDB().recipes
  local mine = rec and rec[skill] and rec[skill].list
  local L = ns.Links
  if mine and L and L.UsesOf then
    local ids = {}
    for _, r in ipairs(mine) do for _, rg in ipairs(r.reagents or {}) do if rg.id then ids[rg.id] = true end end end
    for id in pairs(ids) do
      for _, e in ipairs(L.UsesOf(id) or {}) do
        if e.skill ~= skill and e.learned == true then add(e.skill, "lien : composant commun (" .. tostring(e.name) .. ")") end
      end
    end
  end
  A._linksN = (A._linksN or 0) + 1
  if A._linksN > 32 then A._links, A._linksN = {}, 1 end
  A._links[key] = out
  return out
end

-- Entrées de surbrillance (clés au format de Target : "id:<métier>")
function A.Entries()
  if not A.Enabled() then return nil end
  local out = {}
  local function mark(skill, lvl, why)
    if not skill then return end
    local k = "id:" .. skill
    local e = out[k]
    local R = { direct = 3, indirect = 2, link = 1 }
    if not e then e = { level = lvl, why = {}, activity = true } out[k] = e end
    if R[lvl] > R[e.level] then e.level = lvl end
    e.why[#e.why + 1] = why
  end
  if A.cast then mark(A.cast.skill, "direct", "en cours : " .. tostring(A.cast.name or A.FR[A.cast.skill])) end
  if A.window then
    mark(A.window, "indirect", "fenêtre du métier ouverte")
    for _, l in ipairs(A.LinksFor(A.window)) do mark(l.skill, "link", l.why) end
  end
  if A.pole then mark("fishing", "indirect", "canne à pêche équipée") end
  if next(out) == nil then return nil end
  return out
end

-- Fusion avec le résultat de la cible (sans toucher au cache de Target)
local RANK = { direct = 3, indirect = 2, link = 1 }
function A.Merge(base, act)
  if not act then return base end
  local m = {}
  for k, e in pairs(base or {}) do m[k] = e end
  for k, e in pairs(act) do
    local b = m[k]
    if not b then m[k] = e
    elseif RANK[e.level] > RANK[b.level] then m[k] = { level = e.level, why = b.why, combat = b.combat, activity = true } end
  end
  return m
end

T.VEIL.link = A.VEIL_LINK
local basePaint = T.Paint
function T.Paint(...)
  A.stats.paints = A.stats.paints + 1
  A.current = A.Entries()
  local saved = T.current
  T.current = A.Merge(saved, A.current)
  local ok, n = pcall(basePaint, ...)
  T.current = saved
  -- lien : voile très léger, pas de marque, bord discret
  for _, t in ipairs(UI.embed and UI.embed.tiles or {}) do
    local m = t._osrsTgt
    if m and m._level == "link" then
      if m.fs then m.fs:SetText("") end
      t._tgtLit = "indirect"
    end
  end
  return ok and n or 0
end
local baseClear = T.Clear
function T.Clear(...)
  local r = { baseClear(...) }
  if A.Entries() then pcall(T.Paint) end
  return unpack(r)
end

function A.Refresh(why)
  A.stats.events = A.stats.events + 1
  A.lastWhy = why
  if not (UI.embed and W and W.IsShown and W.IsShown()) then return end
  pcall(T.Paint)
end

-- Infobulle de case : section « Activité » (survol seulement)
if ns.Compact and ns.Compact.TooltipModel then
  local baseModel = ns.Compact.TooltipModel
  function ns.Compact.TooltipModel(d)
    local m = baseModel(d)
    local e = d and d.id and A.current and A.current["id:" .. d.id]
    if e and m and m.lines then
      local G = T.GREEN
      local head = (e.level == "direct" and "Métier en cours") or (e.level == "indirect" and "Métier prêt") or "Lien métiers"
      m.lines[#m.lines + 1] = { " ", 1, 1, 1, false, spacer = true }
      m.lines[#m.lines + 1] = { head, G[1], G[2], G[3], false, header = true }
      for _, l in ipairs(e.why) do m.lines[#m.lines + 1] = { l, 0.75, 1, 0.75, true } end
      m.activity = e
    end
    return m
  end
end

-- Grille reconstruite / panneau rouvert : on repeint si une activité existe
local baseApply = UI.ApplyView
function UI:ApplyView(...)
  local r = { baseApply(self, ...) }
  if A.current or A.cast or A.window or A.pole then pcall(T.Paint) end
  return unpack(r)
end

-- Événements (joueur seulement)
-- Lecture du sort en cours, indépendante de l'ordre des valeurs : chaîne = nom
-- (hors « Cast-… »), booléen en 6e position = sort de métier, plus grand entier
-- plausible = identifiant de sort.
local function ParseCast(...)
  local n, name, id, trade = select("#", ...), nil, nil, nil
  for i = 1, n do
    local v = select(i, ...)
    if type(v) == "string" and not name and v ~= "" and not v:find("^Cast%-") and not v:find("^Interface") and not (ns.IsSecret and ns.IsSecret(v)) then name = v end
    if type(v) == "boolean" and i == 6 then trade = v end
    if type(v) == "number" and v > 0 and v < 10000000 and math.floor(v) == v and i >= 7 then id = v end
  end
  return name, id, trade
end
local function LiveCast()
  local name, id, trade = ParseCast(Call(_G.UnitCastingInfo, "player"))
  local src = name and "UnitCastingInfo"
  if not name then name, id, trade = ParseCast(Call(_G.UnitChannelInfo, "player")) src = name and "UnitChannelInfo" end
  return name, id, trade, src
end
local function startCast(ev, unit, a2, a3, ...)
  if unit ~= "player" then return end
  A.diag.events[#A.diag.events + 1] = tostring(ev) if #A.diag.events > 8 then table.remove(A.diag.events, 1) end
  -- Classic : (unit, castGUID, spellID) ; ancien format : (unit, name, rank, …, spellID)
  local spellID = N(a3) or N(a2)
  local name = (type(a2) == "string" and not a2:find("^Cast%-") and a2) or nil
  local castSrc = "événement"
  local lName, lID, lTrade, lSrc = LiveCast()
  if lName then name = name or lName spellID = spellID or lID castSrc = castSrc .. " + " .. lSrc end
  name = name or Str(Call(_G.GetSpellInfo, spellID or 0))
  A.diag.castName, A.diag.castID, A.diag.castSrc, A.diag.castTrade = name, spellID, castSrc, lTrade
  -- la fenêtre a pu s'ouvrir sans événement lisible : on la relit
  if not A.window then local w = A.ReadWindow() if w then A.window = w end end
  A._mapSrc = nil
  local skill
  if ns.InCombat and ns.InCombat() and not A.window and lTrade ~= true then
    skill = A.QuickSkill(spellID)     -- pêche en combat, etc. ; pas de recherche texte en combat
    A._mapSrc = skill and "sort de métier connu" or "combat : recherche texte évitée"
    if not skill then A.diag.castSkill, A.diag.mapSrc = nil, A._mapSrc return end
  else
    skill = A.SkillForSpell(spellID, name)
  end
  if not skill and A.window and lTrade == true then skill, A._mapSrc = A.window, "sort lancé fenêtre ouverte" end
  A.diag.castSkill, A.diag.mapSrc = skill, A._mapSrc
  if not skill then A.pendingCast = { name = name, spell = spellID } return end
  A.pendingCast = nil
  A.cast = { skill = skill, spell = spellID, name = name }
  A.Refresh("sort")
end
local function stopCast(ev, unit)
  if unit ~= "player" then return end
  A.pendingCast = nil
  if not A.cast then return end
  A.cast = nil
  A.Refresh("fin du sort")
end
local function window(ev)
  if ev == "TRADE_SKILL_SHOW" or ev == "TRADE_SKILL_LIST_UPDATE" or ev == "TRADE_SKILL_DATA_SOURCE_CHANGED" or ev == "TRADE_SKILL_NAME_UPDATE" then A._apiOpen = true end
  if ev == "CRAFT_SHOW" then A._apiOpen, A._craftOpen = true, true end
  local s = A.ReadWindow()
  A.diag.why = ev
  if s == A.window then return end
  A.window = s
  A.Refresh("fenêtre")
end
local function closed(ev)
  if ev == "CRAFT_CLOSE" then A._craftOpen = nil end
  A._apiOpen = A._craftOpen and true or nil
  local s = A.ReadWindow()   -- une autre fenêtre de métier peut rester ouverte
  A.diag.why = ev
  if s == A.window then return end
  A.window = s
  A.Refresh("fenêtre fermée")
end
-- relecture une image plus tard : le titre / la barre sont remplis après OnShow
local function later(ev) if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(0, function() window(ev) end) else window(ev) end end
-- « Votre compétence en Secourisme est maintenant de 140. » : le sort en cours
-- (ou le dernier inconnu) appartient à ce métier ; on le retient pour la session.
local function skillMsg(_, msg)
  local nm
  if ns.UI and ns.UI.ParseSkillMessage then nm = ns.UI:ParseSkillMessage(msg) end
  local sk = A.SkillInText(nm) or A.SkillInText(msg)
  if not sk then return end
  A.diag.lastSkillMsg = sk
  local p = A.pendingCast
  if p and p.name then A.learned[Fold(p.name)] = sk end
  if p then
    A.cast = { skill = sk, spell = p.spell, name = p.name }
    A.pendingCast = nil
    A.diag.castSkill, A.diag.mapSrc = sk, "message de compétence"
    A.Refresh("message de compétence")
  end
end
local function pole()
  local p = A.PoleEquipped()
  if p == A.pole then return end
  A.pole = p
  A.Refresh("canne")
end
-- crochets OnShow / OnHide sur les fenêtres de métier qui existent (aussi celles
-- chargées à la demande : Blizzard_TradeSkillUI, Blizzard_Professions, Blizzard_CraftUI)
A.hooked = {}
function A.HookFrames()
  for _, n in ipairs(A.FRAMES) do
    local f = _G[n]
    if type(f) == "table" and f.HookScript and not A.hooked[n] then
      A.hooked[n] = true
      pcall(f.HookScript, f, "OnShow", function() window("OnShow " .. n) later("OnShow " .. n) end)
      pcall(f.HookScript, f, "OnHide", function() closed("OnHide " .. n) end)
    end
  end
end
A.OnCastStart, A.OnCastStop, A.OnWindow, A.OnWindowClosed, A.OnPole, A.OnSkillMsg = startCast, stopCast, window, closed, pole, skillMsg
if ns.On then
  for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START" }) do ns.On(e, startCast) end
  for _, e in ipairs({ "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED" }) do ns.On(e, stopCast) end
  for _, e in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED", "TRADE_SKILL_NAME_UPDATE", "CRAFT_SHOW", "CRAFT_UPDATE" }) do
    ns.On(e, function(ev) window(ev) later(ev) A.HookFrames() end)
  end
  for _, e in ipairs({ "TRADE_SKILL_CLOSE", "CRAFT_CLOSE" }) do
    ns.On(e, function(ev) closed(ev) if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(0, function() closed(ev) end) end end)
  end
  ns.On("CHAT_MSG_SKILL", skillMsg)
  ns.On("ADDON_LOADED", function() A.HookFrames() end)
  ns.On("PLAYER_EQUIPMENT_CHANGED", function(_, slot) if slot == nil or slot == 16 then pole() end end)
  ns.On("PLAYER_ENTERING_WORLD", function() A._reindex() A.HookFrames() pole() end)
end
A.HookFrames()

-- Diagnostic (en tête de /drop debug, et seul avec /drop debug metier)
function A.DebugLines()
  local d = A.diag
  local function tileState(sk)
    if not sk then return "—" end
    local t
    for _, x in ipairs(UI.embed and UI.embed.tiles or {}) do if x.data and x.data.id == sk then t = x end end
    if not t then return tostring(sk) .. " (pas de case dans la grille)" end
    local m = t._osrsTgt
    local lit = (m and m.shown ~= false and (not m.IsShown or m:IsShown()) and m._level) or "aucune"
    return string.format("%s → case « %s », surbrillance %s", sk, tostring(A.FR[sk] or sk), tostring(lit))
  end
  local fr = {}
  for _, n in ipairs(A.FRAMES) do fr[#fr + 1] = n .. "=" .. ((_G[n] == nil) and "absente" or (Shown(_G[n]) and "visible" or "cachée")) .. (A.hooked[n] and "*" or "") end
  local C = _G.C_TradeSkillUI
  return {
    "— Métier en cours (3.4.3) —",
    "  activé : " .. tostring(A.Enabled()) .. " · panneau ouvert : " .. tostring(W and W.IsShown and W.IsShown() or false),
    "  fenêtres : " .. table.concat(fr, ", ") .. "  (* = OnShow/OnHide accrochés)",
    "  C_TradeSkillUI : " .. ((type(C) == "table") and "présent" or "absent") .. " · GetTradeSkillLine : " .. tostring(Str(Call(_G.GetTradeSkillLine)) or "—"),
    "  fenêtre détectée : " .. tostring(d.frame or "aucune") .. " · source du nom : " .. tostring(d.src or "—") .. " (« " .. tostring(d.text or "—") .. " ») · dernier événement : " .. tostring(d.why or "—"),
    "  métier de la fenêtre : " .. tileState(A.window),
    "  dernier sort : " .. tostring(d.castName or "—") .. " (id " .. tostring(d.castID or "—") .. ", " .. tostring(d.castSrc or "—") .. ", métier=" .. tostring(d.castTrade) .. ")",
    "  sort → métier : " .. tostring(d.castSkill or "non reconnu") .. " (" .. tostring(d.mapSrc or "—") .. ") · en cours : " .. tileState(A.cast and A.cast.skill),
    "  canne : " .. tostring(A.pole) .. " · dernier message de compétence : " .. tostring(d.lastSkillMsg or "—") .. " · événements : " .. table.concat(d.events, ", "),
    string.format("  compteurs : %d événements, %d peintures, %d calculs de liens", A.stats.events, A.stats.paints, A.stats.linkComputes),
  }
end

-- /drop activite on|off (accents tolérés)
ns.SlashExt = ns.SlashExt or {}
local function slashAct(rest)
  rest = (rest or ""):lower()
  local ui = ns.EnsureDB().ui
  if rest == "on" then ui.activity = nil elseif rest == "off" then ui.activity = false
  else ui.activity = (ui.activity == false) and nil or false end
  pcall(T.Paint)
  if ns.Print then ns.Print("métier en cours " .. (A.Enabled() and "surligné." or "non surligné.")) end
end
ns.SlashExt.activite = slashAct
ns.SlashExt["activité"] = slashAct
