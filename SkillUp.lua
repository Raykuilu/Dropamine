-- Dropamine 3.10.0 : lien avec SkillUp Forever (si installé), par son API publique (SkillUpForever.API, version 1).
--   * Infobulle de la case métier : l'étape en cours du trajet SkillUp (remplace notre « Prochain +1 »).
--   * Toast seulement quand l'étape demande de se déplacer (apprendre, acheter chez un vendeur, quête).
--   * Alt+clic sur la case métier : point sur la carte vers le lieu de l'étape (SkillUp le pose).
-- Lecture paresseuse : au survol, et pour les toasts au plus une fois toutes les 2 s, jamais en combat.
-- Rien ne s'affiche sans SkillUp ; chaque appel est protégé.
local ADDON, ns = ...
local Tr = ns.L
local SU = {}
ns.SkillUp = SU

-- Case Dropamine -> ligne de compétence (identifiants de SkillUp)
SU.LINES = { blacksmithing = 164, leatherworking = 165, alchemy = 171, tailoring = 197, engineering = 202,
  enchanting = 333, cooking = 185, firstaid = 129, herbalism = 182, mining = 186, skinning = 393, fishing = 356 }
SU.THROTTLE = 2

local function InCombat() return ns.InCombat and ns.InCombat() and true or false end
local function After(sec, fn) if _G.C_Timer and _G.C_Timer.After then _G.C_Timer.After(sec, fn) else fn() end end

-- L'API SkillUp, si elle est là et dans une version comprise
function SU.API()
  local root = rawget(_G, "SkillUpForever")
  local api = type(root) == "table" and root.API
  if type(api) ~= "table" or api.version ~= 1 or type(api.Professions) ~= "function" then return nil end
  return api
end
function SU.Enabled() return ns.Opt("skillupLink") and SU.API() ~= nil end

-- Réglages -----------------------------------------------------------------------
SU.OPTIONS = {
  { type = "check", key = "skillupLink", label = "Lien avec SkillUp", default = true, cmd = "Réglage de ce panneau",
    help = "Si SkillUp Forever est installé : son étape en cours dans l'infobulle des cases métier (à la place du « Prochain +1 ») et Alt+clic pour le point sur la carte." },
  { type = "check", key = "skillupToasts", label = "Toast quand il faut se déplacer", default = true, cmd = "Réglage de ce panneau",
    help = "Un toast quand l'étape SkillUp suivante demande d'aller voir un maître, un vendeur ou un donneur de quête." },
}
local O = ns.Options
if O then
  O.EXTRA_HOME = O.EXTRA_HOME or {}
  for _, it in ipairs(SU.OPTIONS) do O.EXTRA[#O.EXTRA + 1] = it O.EXTRA_HOME[it.key] = "prof" end
  if O.GROUPS then
    O.GROUPS.grpSkillUp = { label = "SkillUp Forever", help = "Actif seulement si l'addon SkillUp Forever est installé.",
      items = { { "skillupLink", "Lien avec SkillUp" }, { "skillupToasts", "Toast quand il faut se déplacer" } } }
  end
  if O.MAP and O.MAP.prof then O.MAP.prof[#O.MAP.prof + 1] = { "SkillUp Forever", { "grpSkillUp" } } end
  O.TEST_FN = O.TEST_FN or {}
  if O.TEST then O.TEST.grpSkillUp = "group" O.TEST.skillupToasts = "skillupdemo" end
end

-- Lecture -------------------------------------------------------------------------
SU.cache, SU.dirty = nil, true
-- [skillLineID] = entrée SkillUp (nom, icône, étapes). Relue seulement si SkillUp a signalé un changement.
function SU.Read()
  local api = SU.API()
  if not api then return nil end
  SU.Hook()
  if SU.dirty and not InCombat() then
    local ok, list = pcall(api.Professions, { steps = 2, recipes = 1 })
    if ok and type(list) == "table" then
      local map = {}
      for _, e in ipairs(list) do
        if type(e) == "table" and type(e.skillLineID) == "number" then map[e.skillLineID] = e end
      end
      SU.cache, SU.dirty = map, false
    end
  end
  return SU.cache
end
function SU.Entry(skill)
  local id = SU.LINES[skill]
  if not id or not SU.Enabled() then return nil end
  local map = SU.Read()
  local e = map and map[id]
  if e and type(e.steps) == "table" and type(e.steps[1]) == "table" then return e, id end
  return nil
end
-- Première étape qui a un lieu (pour l'Alt+clic)
local function NavIndex(e)
  for i, s in ipairs(e.steps) do if type(s) == "table" and s.nav then return i, s end end
  return nil
end

-- Infobulle : remplace le « Prochain +1 » quand SkillUp a un trajet pour ce métier
function SU.Lines(skill)
  local e = SU.Entry(skill)
  if not e then return nil end
  local s1, s2 = e.steps[1], e.steps[2]
  local L = { "|cff33ff99SkillUp|r " .. Tr["Étape : "] .. tostring(s1.text or "?") }
  if s1.detail and s1.detail ~= "" then L[#L + 1] = "|cffaaaaaa  " .. tostring(s1.detail) .. "|r" end
  if type(s2) == "table" and s2.text then L[#L + 1] = "|cffaaaaaa" .. Tr["Ensuite : "] .. tostring(s2.text) .. "|r" end
  if NavIndex(e) then L[#L + 1] = "|cff808080" .. Tr["Alt+clic : point sur la carte"] .. "|r" end
  return L
end

-- Alt+clic sur une case métier : true si le clic a été pris en charge
function SU.OnAltClick(data)
  local skill = type(data) == "table" and data.id
  if not (skill and SU.LINES[skill]) or not SU.Enabled() then return false end
  local e, id = SU.Entry(skill)
  local api = SU.API()
  local i, s = nil, nil
  if e then i, s = NavIndex(e) end
  if not i or type(api.Navigate) ~= "function" then
    ns.Print(Tr["SkillUp : pas de lieu pour cette étape."])
    return true
  end
  local ok, done = pcall(api.Navigate, id, i)
  if ok and done then
    -- SkillUp annonce déjà le point dans le chat : pas de second message.
    -- 3.10.0 : la goutte devient une aiguille vers ce point (point natif seulement)
    if ns.Needle and ns.Needle.Track then
      local label = s.detail and s.detail ~= "" and tostring(s.detail):match("^([^·]+)") or s.text
      pcall(ns.Needle.Track, label and (tostring(label):gsub("%s+$", "")) or nil)
    end
  else ns.Print(Tr["SkillUp : pas de lieu pour cette étape."]) end
  return true
end

-- Toasts : seulement les étapes où il faut se déplacer --------------------------------
SU.last, SU.seeded = {}, false
-- Un rang de métier (Compagnon, Expert…) appris chez un maître : Dropamine a déjà son rappel de rang
-- (RankToast, maîtres seulement), donc pas de second toast. Rangs par livre ou quête : toast SkillUp,
-- Dropamine n'en fait pas. Une recette à apprendre a son sort (spellID).
function SU.IsRankStep(s) return s.kind == "train" and s.spellID == nil and s.questID == nil and s.itemID == nil end
local function Travel(s)
  if SU.IsRankStep(s) then return false end
  return s.kind == "train" or (s.kind == "buy" and s.nav == true)
end
function SU.StepKey(s)
  local id = s.spellID or s.itemID or s.questID
  return tostring(s.kind) .. ":" .. tostring(id or s.text or "")
end
function SU.Toast(e, s, force)
  local ui = ns.UI
  if not (ui and ui.SpawnDrop) then return nil end
  local title = tostring(e.name or "?") .. Tr[" : étape suivante"]
  return ui:SpawnDrop(e.icon, title, tostring(s.text or ""), nil, nil, nil,
    { kind = "qol", hint = s.detail, dedupeKey = "skillup:" .. tostring(e.skillLineID), force = force })
end
function SU.Check()
  local map = SU.Read()
  if not map or SU.dirty then return end   -- SkillUp encore en chargement : on réessaiera
  local first = not SU.seeded
  for id, e in pairs(map) do
    local s = type(e.steps) == "table" and e.steps[1]
    local key = type(s) == "table" and SU.StepKey(s) or nil
    if key and key ~= SU.last[id] then
      if not first and Travel(s) and ns.Opt("skillupToasts") then pcall(SU.Toast, e, s) end
    end
    SU.last[id] = key
  end
  SU.seeded = true
end
local pending, waitCombat = false, false
function SU.Schedule()
  if pending or not SU.Enabled() then return end
  pending = true
  After(SU.THROTTLE, function()
    pending = false
    if InCombat() then waitCombat = true return end
    pcall(SU.Check)
  end)
end

-- Abonnement aux changements SkillUp (une fois)
function SU.Hook()
  if SU.hooked then return true end
  local api = SU.API()
  if not (api and type(api.Subscribe) == "function") then return false end
  local ok = pcall(api.Subscribe, function() SU.dirty = true SU.srcCache = {} SU.rev = (SU.rev or 0) + 1 SU.Schedule() end)
  if not ok then return false end
  SU.hooked = true
  if ns.db and not ns.db.skillupHello then
    ns.db.skillupHello = true
    ns.Print(Tr["SkillUp détecté : son trajet s'affiche dans les cases métier (Réglages > Métiers pour couper)."])
  end
  SU.Schedule()
  return true
end

-- Collection log : liste complète des recettes d'un métier (lecture seule, rien n'est recopié) ----------
local function Str(v) if type(v) == "string" and v ~= "" and not (ns.IsSecret and ns.IsSecret(v)) then return v end end
local function Call(fn, ...) if type(fn) ~= "function" then return nil end local ok, a, b = pcall(fn, ...) if ok then return a, b end end
-- identifiants de toutes les recettes du métier, ou nil sans SkillUp
function SU.AllRecipes(skill)
  local id, api = SU.LINES[skill], SU.API()
  if not (id and api and ns.Opt("skillupLink") and type(api.Recipes) == "function") then return nil end
  local list = Call(api.Recipes, id)
  return type(list) == "table" and list or nil
end
function SU.RecipeName(rid)
  local CS = _G.C_Spell
  return Str(CS and Call(CS.GetSpellName, rid)) or Str(Call(_G.GetSpellInfo, rid))
end
function SU.RecipeSkill(rid)
  local api = SU.API()
  local r = api and Call(api.RecipeRequirement, rid)
  return type(r) == "table" and tonumber(r.skill) or nil, type(r) == "table" and r or nil
end
-- [skillLineID SkillUp] -> case Dropamine
SU.SKILL_OF = {}
for k, v in pairs(SU.LINES) do SU.SKILL_OF[v] = k end
function SU.RecipeOwner(rid)
  local api = SU.API()
  local r = api and Call(api.Recipe, rid)
  return type(r) == "table" and SU.SKILL_OF[r.skillLineID] or nil
end
-- où l'obtenir, en une ligne (mis en cache ; rien tant que SkillUp charge son catalogue)
SU.srcCache = {}
function SU.SourceText(rid)
  local c = SU.srcCache[rid]
  if c then return c end
  local api = SU.API()
  if not api then return nil end
  local _, req = SU.RecipeSkill(rid)
  local s, why = Call(api.RecipeSources, rid)
  local text
  if type(s) == "table" then
    local v, q, d = s.vendors and s.vendors[1], s.quests and s.quests[1], s.drops and s.drops[1]
    if v then text = Tr["Vendeur : "] .. tostring(v.name or "?") .. (v.zone and (" (" .. tostring(v.zone) .. ")") or "")
    elseif q then text = Tr["Quête : "] .. tostring(q.title or "?")
    elseif d then text = Tr["Butin : "] .. tostring(d.name or "?") .. (d.chance and string.format(" (%s %%)", tostring(d.chance)) or "")
    elseif s.world then text = Tr["Butin aléatoire"] end
  elseif why == "loading" then
    return nil
  end
  if not text and req and req.source == "trainer" then text = Tr["Maître de métier"] end
  -- un patron (objet) sans lieu connu : SkillUp ne nomme vendeurs, quêtes et butins qu'avec Questie / AtlasLoot
  if not text and req and req.source == "item" then text = Tr["Patron (vendeur, butin ou quête)"] end
  text = text or Tr["Source inconnue"]
  SU.srcCache[rid] = text
  return text
end
-- un autre personnage du compte qui la connaît (nom court), ou nil
function SU.KnownByAlt(rid)
  local api = SU.API()
  if not (api and type(api.Characters) == "function" and type(api.Knows) == "function") then return nil end
  local me = rawget(_G, "ForeverCore") and type(_G.ForeverCore.CharacterKey) == "function" and Call(_G.ForeverCore.CharacterKey)
  for _, key in ipairs(Call(api.Characters) or {}) do
    if key ~= me and Call(api.Knows, key, rid) == true then return (tostring(key):match("^([^%-]+)")) end
  end
  return nil
end
-- Questie ou AtlasLoot chargés : SkillUp donne alors les vendeurs, quêtes et butins
function SU.RichSources()
  local A = _G.C_AddOns
  local loaded = (A and A.IsAddOnLoaded) or _G.IsAddOnLoaded
  if type(loaded) ~= "function" then return false end
  for _, n in ipairs({ "Questie", "QuestieDB", "AtlasLootClassic" }) do
    local ok, v = pcall(loaded, n)
    if ok and v then return true end
  end
  return false
end
-- tranches de rang des métiers (Apprenti, Compagnon, Expert, Artisan)
SU.TRANCHES = { { 1, 75, "Apprenti" }, { 76, 150, "Compagnon" }, { 151, 225, "Expert" }, { 226, 300, "Artisan" } }
function SU.TrancheOf(lvl)
  lvl = tonumber(lvl) or 0
  for i, t in ipairs(SU.TRANCHES) do if lvl <= t[2] then return i end end
  return #SU.TRANCHES
end
-- recettes manquantes : { { rid, name, lvl } } triées par niveau requis ; known = noms connus (repliés)
function SU.Missing(skill, known)
  local list = SU.AllRecipes(skill)
  if not list then return nil end
  local out = {}
  for _, rid in ipairs(list) do
    local name = SU.RecipeName(rid)
    if name and not known[ns.Fold(name)] then
      out[#out + 1] = { rid = rid, name = name, lvl = SU.RecipeSkill(rid) or 0 }
    end
  end
  table.sort(out, function(a, b) if a.lvl ~= b.lvl then return a.lvl < b.lvl end return a.name < b.name end)
  return out
end

-- Test du réglage : un toast d'exemple
if O and O.TEST_FN then
  O.TEST_FN.skillupdemo = function()
    return SU.Toast({ name = Tr["Couture"], icon = "Interface\\Icons\\Trade_Tailoring", skillLineID = 197 },
      { text = Tr["Apprendre Expert"], detail = Tr["Maître couturier, Hurlevent · 5 po"] }, true)
  end
end

if ns.On then
  local function TryHook() if not SU.Hook() then After(5, function() SU.Hook() end) end end
  ns.On("PLAYER_LOGIN", TryHook)
  ns.On("PLAYER_ENTERING_WORLD", function() SU.Hook() end)
  ns.On("PLAYER_REGEN_ENABLED", function() if waitCombat then waitCombat = false SU.Schedule() end end)
end
