-- Dropamine 3.3.6 — SURBRILLANCE DE LA GRILLE SELON LA CIBLE.
-- À chaque changement de cible (PLAYER_TARGET_CHANGED), les cases dont le
-- rang / l'XP peut monter grâce à cette cible reçoivent un voile vert discret et
-- un liseré coloré (GAIN_COLORS) ; le « +1 » et le pop vert clair sont réservés au vrai gain :
--   * Niveau : la cible donne de l'XP (pas grise pour ton niveau, pas tapée par
--     un autre, pas un joueur, niveau maximal pas atteint) ;
--   * compétence d'arme / farouche (et distance pour un chasseur), Défense :
--     cible vivante attaquable et rang < plafond ET < 5 × niveau de la cible ;
--   * Cuisine / Secourisme : un objet de son butin sert à une recette CONNUE non
--     grise (même calcul que l'icône du scanner) ;
--   * Dépeçage : bête dépeçable (vue dépeçable, base Forever) qui peut encore
--     rapporter un point (alertes de récolte).
-- Liens INDIRECTS (repère plus faible : voile léger, « + » pâle) : un objet de
-- la cible sert à un autre métier du personnage (cuir → Travail du cuir,
-- tissu → Couture ; recettes lues en jeu, ou nature de la matière).
-- Le survol de la case explique pourquoi (section « Cible : … »).
-- Coût : RIEN au repos (aucun OnUpdate, aucune minuterie) ; un calcul par
-- changement de cible (mis en cache par créature / niveau / rangs) ; les
-- marques sont des enfants de NOS cases, créés une fois par case et réutilisés.
-- /drop alertes on|off coupe aussi ce repère.
-- Seuil gris et plafond 5 × niveau : règles de Classic (Forever = client
-- Classic) ; le serveur ne les expose pas.
-- 3.3.10 (donnée Forever en jeu : Combat farouche monté sur un ennemi GRIS) :
-- arme (Masse) et Combat farouche montent sur un ennemi GRIS, Défense non.
-- Règle « cible grise = pas de gain » : XP du niveau et Défense seulement.
-- Arme / Combat farouche : seul le plafond 5 × niveau de la cible reste,
-- affiché « estimé » dans l'explication de la case.
local ADDON, ns = ...
local Tr = ns.L   -- 3.5.19 : textes traduits (Locales/)
local UI, W, S = ns.UI, ns.Window, ns.Scanner
local T = {}
ns.Target = T

local function N(v) return ns.N(v) end
-- 3.6.0 : sans table temporaire (appelé sur les événements fréquents : survol,
-- barres de nom, cible) et sans troncature aux valeurs nil intermédiaires.
local function Ret(ok, ...) if not ok then return nil end return ... end
local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  return ns.Unsecret(Ret(pcall(fn, ...)))
end
local function Str(v) if type(v) ~= "string" or (ns.IsSecret and ns.IsSecret(v)) or v == "" then return nil end return v end

T.stats = { events = 0, computes = 0, cached = 0, paints = 0, marksCreated = 0 }
T.VEIL = { direct = 0.16, indirect = 0.07 }
T.GREEN = { 0.25, 1.00, 0.25 }
T.EDGE = 2
T.CLOTH = { [2589] = true, [2592] = true, [4306] = true, [4338] = true, [14047] = true, [14256] = true }
T.LEATHER = { [2934] = true, [783] = true, [2318] = true, [2319] = true, [4232] = true, [4234] = true, [4235] = true,
  [4304] = true, [8169] = true, [8170] = true, [8171] = true }
T.MATERIAL_SKILL = { cloth = "tailoring", leather = "leatherworking" }
T.MATERIAL_FR = { cloth = "tissu", leather = "cuir" }

-- 3.9.0 : réglage à part « Liseré selon la cible » (avant : lié aux alertes de récolte, rangées côté métiers ;
-- les décocher éteignait aussi le liseré du Niveau, des armes et de la Défense)
function T.Enabled() return ns.Opt("targetGlow") end

-- Niveau gris (Classic) : la cible ne donne PAS d'XP si niveau ≤ ce seuil.
function T.GreyLevel(pl)
  pl = N(pl) or 1
  if pl <= 5 then return 0 end
  if pl <= 39 then return pl - math.floor(pl / 10) - 5 end
  if pl <= 59 then return pl - math.floor(pl / 5) - 1 end
  return pl - 9
end

local function Rank(id) return (S.RankOf and S.RankOf(id)) or nil end

-- Lecture de la cible (une seule fois par événement).
function T.ReadTarget()
  local u = "target"
  if not Call(_G.UnitExists, u) then return nil end
  -- Joueur d'abord : UnitCreatureType est nil, et un GUID « Player » ne doit
  -- pas être relu comme un PNJ (dépeçage / butin / type de créature).
  local isPlayer = (S.IsPlayerUnit and S.IsPlayerUnit(u)) or (Call(_G.UnitIsPlayer, u) and true or false)
  local npc, pinfo
  if not isPlayer then npc, pinfo = S.UnitNpcID(u) end
  local pvp
  if type(_G.UnitIsPVP) == "function" then pvp = Call(_G.UnitIsPVP, u) and true or false end
  local enemy = type(_G.UnitIsEnemy) == "function" and Call(_G.UnitIsEnemy, "player", u) and true or false
  local t = {
    name = Str(Call(_G.UnitName, u)), level = N(Call(_G.UnitLevel, u)), npc = npc,
    dead = Call(_G.UnitIsDead, u) and true or false,
    player = isPlayer and true or false,
    attackable = Call(_G.UnitCanAttack, "player", u) and true or false,
    tapped = Call(_G.UnitIsTapDenied, u) and true or false,
    pvp = pvp, enemy = enemy,
    faction = Str(Call(_G.UnitFactionGroup, u)),
    myFaction = Str(Call(_G.UnitFactionGroup, "player")),
    playerLevel = N(Call(_G.UnitLevel, "player")),
    classif = Str(Call(_G.UnitClassification, u)),   -- 3.10.0 : élite (danger Hardcore)
  }
  if npc and not isPlayer and S.NoteUnit then local _, seen = S.NoteUnit(u) if seen then t.ctype, t.family = seen.ctype, seen.family end end
  return t
end

-- Calcul : { [clé de case] = { level = "direct"|"indirect", why = { lignes } } }
-- clés : "level", "kind:melee", "kind:feral", "kind:ranged", "kind:defense", "id:<métier>"
-- 3.3.8 : forme de druide. En Félin / Ours / Ours redoutable, on frappe
-- avec la forme : seule la compétence farouche (et la Défense) peut monter,
-- jamais l'arme. En forme humanoïde (et toute autre forme), c'est l'arme
-- équipée. Rien d'autre n'est supposé sur les règles farouches de Forever.
T.FERAL_FORM_IDS = { [1] = "félin", [5] = "ours", [8] = "ours redoutable" }
-- sorts de forme (Classic) : Félin 768, Ours 5487, Ours redoutable 9634
T.FERAL_SPELLS = { [768] = "félin", [5487] = "ours", [9634] = "ours redoutable" }
T.FERAL_FORM_NAMES = { "Forme de félin", "Forme d'ours", "Forme d'ours redoutable", "Cat Form", "Bear Form", "Dire Bear Form" }
local FORM_OF = { ["Forme de félin"] = "félin", ["Forme d'ours"] = "ours", ["Forme d'ours redoutable"] = "ours redoutable",
  ["Cat Form"] = "félin", ["Bear Form"] = "ours", ["Dire Bear Form"] = "ours redoutable" }
local function FoldName(s) s = tostring(s or "") s = (ns.Fold and ns.Fold(s)) or s:lower() return (s:gsub("[’']", "'")) end
T._formByName = nil
local function FormByName(nm)
  if type(nm) ~= "string" or nm == "" then return nil end
  if not T._formByName then
    T._formByName = {}
    for k, v in pairs(FORM_OF) do T._formByName[FoldName(k)] = v end
    -- noms localisés réels des sorts, si le client les donne
    for id, v in pairs(T.FERAL_SPELLS) do local n = Call(_G.GetSpellInfo, id) if type(n) == "string" then T._formByName[FoldName(n)] = v end end
  end
  return T._formByName[FoldName(nm)]
end
-- Lecture d'une ligne de GetShapeshiftFormInfo (formats 1.12–3.x : icône, nom,
-- actif, lançable ; formats récents : icône, actif, lançable, sortID).
local function FormFromInfo(...)
  local n = select("#", ...)
  local active, form
  for i = 1, n do
    local v = select(i, ...)
    if type(v) == "number" and T.FERAL_SPELLS[v] then form = form or T.FERAL_SPELLS[v] end
    if type(v) == "string" and i > 1 then form = form or FormByName(v) end
    if type(v) == "string" and i == 1 then
      local low = v:lower()
      if low:find("catform", 1, true) then form = form or "félin"
      elseif low:find("direbearform", 1, true) then form = form or "ours redoutable"
      elseif low:find("bearform", 1, true) then form = form or "ours" end
    end
  end
  local a2, a3 = select(2, ...), select(3, ...)
  if type(a2) == "boolean" then active = a2 elseif type(a3) == "boolean" or a3 == 1 or a3 == nil then active = a3 and true or false end
  if type(a2) == "number" and a2 == 1 then active = true end
  return form, active
end
-- Forme farouche active : « félin » / « ours » / « ours redoutable » / nil, et la méthode.
-- 3.3.15 : TOUTES les sondes sont évaluées (debug : résultat de chacune) ; la
-- première qui répond gagne. Ordre : identifiant de forme, forme active de la
-- barre, barre parcourue, auras (UnitAura/UnitBuff, C_UnitAuras par sort et par
-- index, AuraUtil par nom FR/EN), puis type de ressource du druide
-- (UnitPowerType : 3 = énergie → félin, 1 = rage → ours) — en jeu le
-- GetShapeshiftFormID peut être absent ou nil.
local function Probe_FormID()
  local id = N(Call(_G.GetShapeshiftFormID))
  if id and T.FERAL_FORM_IDS[id] then return T.FERAL_FORM_IDS[id], "id " .. id end
  return nil, "id " .. tostring(id)
end
local function Probe_FormIndex()
  local idx = N(Call(_G.GetShapeshiftForm))
  if idx and idx > 0 then
    local form = FormFromInfo(Call(_G.GetShapeshiftFormInfo, idx))
    if not form then
      local _, _, _, sid = Call(_G.GetShapeshiftFormInfo, idx)
      if type(sid) == "number" then form = T.FERAL_SPELLS[sid] or FormByName(Call(_G.GetSpellInfo, sid)) end
    end
    if form then return form, "index " .. idx end
    return nil, "index " .. idx .. " (non reconnu)"
  end
  return nil, "index " .. tostring(idx)
end
local function Probe_FormBar()
  local nForms = N(Call(_G.GetNumShapeshiftForms)) or 0
  for i = 1, math.min(nForms, 10) do
    local form, active = FormFromInfo(Call(_G.GetShapeshiftFormInfo, i))
    if form and active then return form, "case " .. i .. "/" .. nForms end
  end
  return nil, nForms .. " formes, aucune active"
end
local function Probe_UnitAura()
  local fn = _G.UnitAura or _G.UnitBuff
  if type(fn) ~= "function" then return nil, "absent" end
  for i = 1, 40 do
    local name, _, _, _, _, _, _, _, _, spellId = Call(fn, "player", i, "HELPFUL")
    if not name then return nil, (i - 1) .. " auras" end
    local form = (type(spellId) == "number" and T.FERAL_SPELLS[spellId]) or FormByName(name)
    if form then return form, tostring(spellId or name) end
  end
  return nil, "40 auras"
end
local function Probe_CAuras()
  local C = _G.C_UnitAuras
  if type(C) ~= "table" then return nil, "absent" end
  if C.GetPlayerAuraBySpellID then
    for id, form in pairs(T.FERAL_SPELLS) do
      local d = Call(C.GetPlayerAuraBySpellID, id)
      if type(d) == "table" then return form, "sort " .. id end
    end
  end
  if C.GetAuraDataByIndex then
    for i = 1, 40 do
      local d = Call(C.GetAuraDataByIndex, "player", i, "HELPFUL")
      if type(d) ~= "table" then return nil, (i - 1) .. " auras" end
      local form = (type(d.spellId) == "number" and T.FERAL_SPELLS[d.spellId]) or FormByName(d.name)
      if form then return form, "index " .. tostring(d.spellId or d.name) end
    end
  end
  return nil, "aucune"
end
local function Probe_AuraUtil()
  local A = _G.AuraUtil
  if type(A) ~= "table" or type(A.FindAuraByName) ~= "function" then return nil, "absent" end
  local names = {}
  for id in pairs(T.FERAL_SPELLS) do local n = Call(_G.GetSpellInfo, id) if type(n) == "string" then names[#names + 1] = n end end
  for _, n in ipairs(T.FERAL_FORM_NAMES) do names[#names + 1] = n end
  for _, n in ipairs(names) do
    local hit = Call(A.FindAuraByName, n, "player", "HELPFUL")
    if hit then return FormByName(n), n end
  end
  return nil, "aucune"
end
local function Probe_Power()
  local pt = N(Call(_G.UnitPowerType, "player"))
  if pt == 3 then return "félin", "énergie (3)" end
  if pt == 1 then return "ours", "rage (1)" end
  return nil, "type " .. tostring(pt)
end
T.FORM_PROBES = {
  { "GetShapeshiftFormID", Probe_FormID }, { "GetShapeshiftForm", Probe_FormIndex },
  { "barre de formes", Probe_FormBar }, { "UnitAura", Probe_UnitAura },
  { "C_UnitAuras", Probe_CAuras }, { "AuraUtil", Probe_AuraUtil },
  { "UnitPowerType", Probe_Power },
}
-- résultat de chaque sonde (debug) : { { nom, forme|nil, détail }, … }
function T.FormProbe()
  local out = {}
  for _, p in ipairs(T.FORM_PROBES) do
    local ok, form, why = pcall(p[2])
    out[#out + 1] = { p[1], ok and form or nil, ok and why or ("erreur " .. tostring(form)) }
  end
  return out
end
function T.FeralForm()
  local _, class = Call(_G.UnitClass, "player")
  if class ~= "DRUID" then return nil, "pas druide" end
  for _, p in ipairs(T.FORM_PROBES) do
    local ok, form, why = pcall(p[2])
    if ok and form then return form, p[1] .. " : " .. tostring(why) end
  end
  return nil, "humanoïde (aucune sonde)"
end
-- Case Combat farouche : par type, identifiant, ligne de compétence (134),
-- nom FR / EN (accents, casse, apostrophes normalisés) ou icône de forme.
-- 3.3.13 : la case est reconnue quel que soit son type (« melee », « ranged »…)
-- ET la surbrillance utilise la même clé (bug 3.3.12 : calculée « kind:feral »
-- mais peinte sous « kind:<type> » → jamais verte en forme de félin).
T.FERAL_SKILL_LINE = 134
local FERAL_NAMES = { ["combat farouche"] = true, ["feral combat"] = true, ["combat farouche (druide)"] = true }
local function Plain(s)
  s = FoldName(s)
  s = s:gsub("[éèêë]", "e"):gsub("[àâä]", "a"):gsub("[îï]", "i"):gsub("[ôö]", "o"):gsub("[ùûü]", "u"):gsub("ç", "c")
  return (s:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end
function T.IsFeralTile(d)
  if type(d) ~= "table" then return false end
  if d.kind == "feral" or d.id == "feral" then return true end
  if N(d.skillID) == T.FERAL_SKILL_LINE then return true end
  for _, nm in pairs({ d.skillName or false, d.name or false }) do   -- (ipairs s'arrêtait au 1er nil)
    if type(nm) == "string" then
      local p = Plain(nm)
      if FERAL_NAMES[p] or p:find("farouche", 1, true) or p:find("feral", 1, true) then return true end
    end
  end
  local ic = type(d.icon) == "string" and d.icon:lower() or ""
  if ic:find("druid_catform", 1, true) then return true end
  return false
end
function T.FormSig()
  local _, class = Call(_G.UnitClass, "player")
  if class ~= "DRUID" then return "-" end
  return T.FeralForm() or "humanoïde"
end

-- 3.3.15 : arme(s) réellement équipée(s) → compétence(s) éligible(s).
T.SLOTS = { { 16, "main droite" }, { 17, "main gauche" }, { 18, "distance" } }
T.AUTOATTACK = 6603
T.AUTOREPEAT = { 5019, 75, 2764 }     -- Tir (baguette), Tir automatique, Lancer
T.EQUIP_FR = {
  daggers = "Dague équipée", swords = "Épée équipée", swords2h = "Épée à deux mains équipée",
  axes = "Hache équipée", axes2h = "Hache à deux mains équipée", maces = "Masse équipée",
  maces2h = "Masse à deux mains équipée", polearms = "Arme d'hast équipée", staves = "Bâton équipé",
  fist = "Arme de pugilat équipée", unarmed = "Mains nues", bows = "Arc équipé", guns = "Arme à feu équipée",
  crossbows = "Arbalète équipée", thrown = "Arme de jet équipée", wands = "Baguette équipée",
}
T.swing = { melee = false, ranged = false }
function T.Equipped()
  local out = { ids = {}, slots = {}, sig = {} }
  for _, sl in ipairs(T.SLOTS) do
    local eq = ns.GetEquippedItemInfo and ns.GetEquippedItemInfo(sl[1])
    local id = eq and ns.MapWeaponSubtype and ns.MapWeaponSubtype(eq.subType, eq.classID, eq.subclassID) or nil
    if sl[1] == 16 and not eq then id = "unarmed" end
    if sl[1] == 18 and id and not (id == "bows" or id == "guns" or id == "crossbows" or id == "thrown" or id == "wands") then id = nil end
    out.slots[#out.slots + 1] = { slot = sl[1], label = sl[2], item = eq, id = id }
    if id and not out.ids[id] then out.ids[id] = sl[2] end
    out.sig[#out.sig + 1] = tostring(eq and eq.id) .. ":" .. tostring(eq and eq.subclassID) .. ":" .. tostring(id)
  end
  out.sig = table.concat(out.sig, ",")
  return out
end
function T.Meleeing()
  if T.swing.melee then return true end
  return Call(_G.IsCurrentSpell, T.AUTOATTACK) == true
end
function T.Shooting()
  if T.swing.ranged then return true end
  local fn = _G.IsAutoRepeatSpell
  if type(fn) ~= "function" then return false end
  for _, id in ipairs(T.AUTOREPEAT) do
    local n = Call(_G.GetSpellInfo, id)
    if (type(n) == "string" and Call(fn, n)) or Call(fn, id) then return true end
  end
  return false
end
function T.BeingHit()
  if not Call(_G.UnitAffectingCombat, "player") then return false end
  return Call(_G.UnitIsUnit, "targettarget", "player") and true or false
end
function T.SwingSig()
  local vs = (Call(_G.UnitAffectingCombat, "player") and Call(_G.UnitAffectingCombat, "target")) and "c" or "-"
  return (T.Meleeing() and "m" or "-") .. (T.Shooting() and "r" or "-") .. (T.BeingHit() and "h" or "-") .. vs
end
function T.EquipDebug()
  local e = T.Equipped()
  local p = {}
  for _, s in ipairs(e.slots) do
    local it = s.item
    p[#p + 1] = string.format("%s %s", s.label, it and string.format("%s (classe %s/%s, %s)", tostring(it.name or it.id), tostring(it.classID), tostring(it.subclassID), tostring(it.subType)) or "vide")
      .. " → " .. (s.id and ("case " .. tostring((ns.CatalogById and ns.CatalogById(s.id) or {}).name or s.id)) or "aucune")
  end
  return "  équipé : " .. table.concat(p, " ; ") .. " ; frappe " .. T.SwingSig()
end

function T.Compute(tg)
  local out = {}
  local function mark(key, lvl, why)
    local e = out[key]
    if not e then e = { level = lvl, why = {} } out[key] = e end
    if lvl == "direct" then e.level = "direct" end
    e.why[#e.why + 1] = why
  end
  T.notes = {}
  if not tg then return out end
  local pl = N(tg.playerLevel) or N(Call(_G.UnitLevel, "player")) or 1
  local tl = tg.level
  local skull = (tl == nil or tl <= 0)
  local effLevel = skull and (pl + 10) or tl
  -- Un joueur ennemi (attaquable ou UnitIsEnemy, flag JcJ si l'API existe)
  -- suit les règles de combat d'un monstre. Pas d'XP, pas de butin, pas de
  -- dépeçage : UnitCreatureType est nil et le GUID est de type Player.
  local mob = not tg.player
  local hostile = tg.player and not tg.dead and (tg.attackable or tg.enemy) and tg.pvp ~= false
  local fightable = (mob and tg.attackable and not tg.dead) or hostile
  -- Niveau (XP) : jamais sur un joueur
  local cap = (ns.GetLevelCap and ns.GetLevelCap()) or 60
  if mob and tg.attackable and not tg.dead and not tg.tapped and pl < cap then
    local grey = T.GreyLevel(pl)
    if skull or tl > grey then
      mark("level", "direct", Tr["XP : cible niveau "] .. (skull and "??" or tl) .. Tr[" (grise si ≤ "] .. grey .. ")")
    end
  end
  -- Combat : arme / farouche / distance (chasseur), Défense — 3.3.10 : règle
  -- « grise » pour la Défense seulement (observé en jeu sur Forever)
  T.COMBAT_GREY_RULE = false     -- arme / Combat farouche : gain observé sur cible grise
  T.DEFENSE_GREY_RULE = true      -- Défense : aucun gain observé sur cible grise
  if fightable then
    local _, class = Call(_G.UnitClass, "player")
    local form, how
    if class == "DRUID" then form, how = T.FeralForm() end
    T.lastForm, T.lastFormHow = form, how
    -- 3.3.15 : seules les armes ÉQUIPÉES sont éligibles (16 main droite, 17 main
    -- gauche, 18 distance) ; deux niveaux : FORT (« direct ») quand on frappe
    -- vraiment (attaque auto / tir auto / baguette ; Défense : la cible nous
    -- frappe), DISCRET (« indirect ») si la cible convient mais sans frappe.
    local eqp = T.Equipped()
    local swingM, swingR, hit = T.Meleeing(), T.Shooting(), T.BeingHit()
    T.lastEquip, T.lastSwing = eqp, { melee = swingM, ranged = swingR, hit = hit }
    for _, t in ipairs(UI.embed and UI.embed.tiles or {}) do
      local d = t.data
      local isFeral = d and T.IsFeralTile(d)
      local isWeapon = d and (d.kind == "melee" or d.kind == "ranged")
      if d and (d.combatTile or isFeral or isWeapon) and not d.placeholder and t:IsShown() then
        local k = d.kind
        if isFeral then k = "feral" end
        local key = T.KeyFor(d)
        local wid = (k == "melee" or k == "ranged") and d.id or nil
        local cur, mx = N(d.current) or 0, N(d.apiMax) or 0
        if class == "DRUID" and k == "feral" then
          T.lastFeralTile = string.format("%s %d/%d", tostring(d.name), cur, mx)
        end
        local ok, why, strong
        if k == "defense" then
          ok, strong = true, hit
          why = Tr["Défense · monte quand la cible te frappe"] .. (hit and Tr[" (elle te frappe)"] or "")
        elseif k == "feral" then
          ok = (class == "DRUID") and form ~= nil
          strong = ok and swingM
          why = tostring(d.skillName or d.name or Tr["Combat farouche"]) .. Tr[" (forme "] .. Tr[tostring(form)] .. Tr[") · monte sur cette cible"]
          if not ok and class == "DRUID" then T.notes[#T.notes + 1] = tostring(d.name or Tr["Combat farouche"]) .. Tr[" : pas en forme félin / ours"] end
        elseif wid then
          local slot = eqp.ids[wid]
          ok = slot ~= nil and not form                 -- forme farouche : jamais l'arme
          if ok and k == "ranged" and wid ~= "wands" and class ~= "HUNTER" and class ~= "WARRIOR" and class ~= "ROGUE" then ok = false end
          strong = ok and ((k == "melee" and swingM) or (k == "ranged" and swingR))
          why = ((T.EQUIP_FR[wid] and Tr[T.EQUIP_FR[wid]]) or (tostring(d.skillName or d.name) .. Tr[" équipée"])) .. Tr[" · monte sur cette cible"]
          if not ok and form then T.notes[#T.notes + 1] = tostring(d.skillName or d.name) .. Tr[" : arme ignorée en forme "] .. Tr[tostring(form)] end
        end
        if ok and mx > 0 and cur >= mx then
          ok = false
          T.notes[#T.notes + 1] = tostring(d.skillName or d.name) .. Tr[" : déjà au maximum ("] .. cur .. "/" .. mx .. ")"
        end
        if ok and k == "defense" and T.DEFENSE_GREY_RULE and (not skull) and tl <= T.GreyLevel(pl) then
          ok = false
          T.notes[#T.notes + 1] = tostring(d.name or Tr["Défense"]) .. Tr[" : pas de gain sur cible grise (observé)"]
        end
        -- plafond estimé 5 × niveau de la cible (arme / farouche) : au-delà, discret seulement
        if ok and k ~= "defense" and cur >= 5 * effLevel then
          strong = false
          T.notes[#T.notes + 1] = string.format(Tr["%s : %d ≥ %d (plafond estimé 5 × niveau %s) → gain peu probable"], tostring(d.skillName or d.name or k), cur, 5 * effLevel, skull and "??" or tostring(effLevel))
        end
        if ok and key then
          if strong then why = why .. ((k == "defense") and "" or Tr[" (tu frappes)"])
          elseif k ~= "defense" then why = why .. Tr[" (frappe pour la faire monter)"] end
          if tg.player then why = why .. Tr[" · joueur"] end
          mark(key, strong and "direct" or "indirect", why)
          out[key].combat = true
        end
      end
    end
  end
  -- Case JcJ : ennemi honorable. Discret sur la cible, fort en combat avec lui.
  if hostile and ns.PvP and ns.PvP.HonorFromTarget then
    local okH, honor = pcall(ns.PvP.HonorFromTarget, tg)
    if okH and honor then
      local strong = T.Meleeing() or T.BeingHit() or (Call(_G.UnitAffectingCombat, "player") and Call(_G.UnitAffectingCombat, "target"))
      mark("id:pvp", strong and "direct" or "indirect", Tr["JcJ : ennemi honorable"] .. (strong and Tr[" (en combat)"] or Tr[" (ciblé)"]))
    end
  end
  -- Butin : Cuisine / Secourisme (recettes connues non grises)
  local c = tg.npc and S.CreatureFor and S.CreatureFor(tg.npc, { name = tg.name, family = tg.family, ctype = tg.ctype })
  local lootable = not tg.player and not tg.tapped and (tg.attackable or tg.dead)
  local DIFF_FR = { optimal = "orange", medium = Tr["jaune"], easy = Tr["vert"] }
  if c and lootable then
    for _, skill in ipairs({ "cooking", "firstaid" }) do
      if (Rank(skill) or 0) > 0 and S.CreatureDiff then
        local diff, recipe = S.CreatureDiff(c, skill)
        if diff and DIFF_FR[diff] then
          mark("id:" .. skill, "direct", Tr["butin : "] .. tostring(recipe and recipe.name or Tr["recette"]) .. " (" .. DIFF_FR[diff] .. ")")
        end
      end
    end
  end
  -- Dépeçage (bête dépeçable qui peut encore rapporter un point)
  local G = ns.Gather
  if G and tg.name and not tg.player and (Rank("skinning") or 0) > 0 then
    local skinnable = G.Known(tg.name) or G.StaticSkinnable(tg.npc) or (c and c.skills and (c.skills.skinning or 0) > 0)
    if skinnable then
      local st = G.State(tg.name, tl)
      if G.GivesPoints(st) then mark("id:skinning", "direct", st.text) end
    end
  end
  -- Liens indirects : autres métiers qui utilisent un objet de la cible
  if c and lootable then
    local items = ns.Links and ns.Links.CreatureItems(c) or {}
    local seen = {}
    for _, id in ipairs(items) do
      for _, e in ipairs(ns.Links and ns.Links.UsesOf(id) or {}) do
        if e.learned == true and e.skill ~= "cooking" and e.skill ~= "firstaid" and e.diff ~= "trivial" and not seen[e.skill] then
          seen[e.skill] = true
          mark("id:" .. e.skill, "indirect", Tr["lien : objet de la cible pour "] .. tostring(e.name))
        end
      end
      local mat = (T.CLOTH[id] and "cloth") or (T.LEATHER[id] and "leather") or nil
      local sk = mat and T.MATERIAL_SKILL[mat]
      if sk and not seen[sk] and (Rank(sk) or 0) > 0 then
        seen[sk] = true
        local nm = (ns.ItemDisplayName and ns.ItemDisplayName(id)) or (ns.Craft and ns.Craft.ItemName and ns.Craft.ItemName(id)) or nil
        if nm and ns.BareItemIdLabel and ns.BareItemIdLabel(nm) then nm = nil end
        local matLabel = Tr["lien : "] .. Tr[T.MATERIAL_FR[mat]]
        if nm then matLabel = matLabel .. " (" .. tostring(nm) .. Tr["), matière de ce métier"]
        else matLabel = matLabel .. Tr[", matière de ce métier"] end
        mark("id:" .. sk, "indirect", matLabel)
      end
    end
  end
  return out
end

-- Cache par cible : créature / niveau / état + versions (recettes, appris, rangs).
T._cache = {}
-- arme en main / rangs de combat (≤ 4 cases) : changent sans CHAT_MSG_SKILL
function T.CombatSig()
  local p = {}
  for _, t in ipairs(UI.embed and UI.embed.tiles or {}) do
    local d = t.data
    if d and d.combatTile then p[#p + 1] = tostring(d.name) .. "=" .. tostring(d.current) .. "/" .. tostring(d.apiMax) end
  end
  return table.concat(p, ",")
end
local function CacheKey(tg)
  local pl = N(Call(_G.UnitLevel, "player")) or 0
  return table.concat({ tostring(tg.npc or tg.name), tostring(tg.level), tostring(tg.dead), tostring(tg.tapped), tostring(tg.attackable),
    tostring(tg.player), tostring(tg.pvp), tostring(tg.enemy),
    tostring(pl), tostring(ns.Craft and ns.Craft._ver), tostring(S._learnVer), tostring(T._rankVer or 0), T.CombatSig(), T.FormSig(), T.Equipped().sig, T.SwingSig() }, "|")
end
function T.Result(tg)
  if not tg then return {} end
  local k = CacheKey(tg)
  local r = T._cache[k]
  if r then T.stats.cached = T.stats.cached + 1 return r end
  T.stats.computes = T.stats.computes + 1
  r = T.Compute(tg)
  T._cacheN = (T._cacheN or 0) + 1
  if T._cacheN > 64 then T._cache, T._cacheN, T._notes = {}, 1, {} end
  T._cache[k] = r
  T._notes = T._notes or {}
  T._notes[r] = T.notes
  return r
end

function T.KeyFor(d)
  if not d or d.placeholder then return nil end
  if d.kind == "level" then return "level" end
  if T.IsFeralTile(d) then return "kind:feral" end      -- même clé que T.Compute
  if d.combatTile then return "kind:" .. tostring(d.kind) end
  if d.id then return "id:" .. tostring(d.id) end
end

-- Couleur du liseré de pré-sélection : GAIN_COLORS (rouge XP, bleu armes/Défense, vert métiers).
function T.GainColor(d)
  local S = ns.Slot
  if d and S and S.ColorForGain then
    local c = S.ColorForGain(d.kind, d.id, d.name or d.skillName, d.header or d.section)
    if c then return c end
  end
  local G = ns.GAIN_COLORS or (S and S.ADD_COLORS)
  if not G then return T.GREEN end
  local k = d and d.kind
  if k == "level" then return G.red end
  if k == "melee" or k == "ranged" or k == "defense" or k == "feral" or (d and d.combatTile) then
    return G.blue
  end
  return G.green
end

-- Marque d'une case (créée une fois, réutilisée).
function T.Mark(t)
  local m = t._osrsTgt
  if m then return m end
  m = CreateFrame("Frame", nil, t)
  m._osrsOwn = true
  if m.EnableMouse then m:EnableMouse(false) end
  m:SetAllPoints(t.icon or t)
  -- 3.3.15 : la surbrillance recolore le bord de la case (même biseau) en vert ;
  -- aucun trait carré à part.
  m.veil = m:CreateTexture(nil, "OVERLAY")
  m.veil:SetAllPoints(m)
  local okC = m.veil.SetColorTexture and pcall(m.veil.SetColorTexture, m.veil, T.GREEN[1], T.GREEN[2], T.GREEN[3], 1)
  if not okC then pcall(m.veil.SetTexture, m.veil, "Interface\\Buttons\\WHITE8X8") if m.veil.SetVertexColor then pcall(m.veil.SetVertexColor, m.veil, T.GREEN[1], T.GREEN[2], T.GREEN[3], 1) end end
  local ok, fs = pcall(m.CreateFontString, m, nil, "OVERLAY", "GameFontHighlightSmall")
  if not (ok and fs) then fs = m:CreateFontString(nil, "OVERLAY") end
  pcall(fs.SetFont, fs, (ns.Icons and ns.Icons.COUNT_PATH) or "Fonts\\ARIALN.TTF", 10, (ns.Icons and ns.Icons.TEXT_FLAGS) or "")   -- 3.3.9 : sans contour
  if ns.Icons and ns.Icons.CleanText then ns.Icons.CleanText(fs) end
  -- 3.3.15 : « +1 » en haut à gauche DANS la case, sous la pastille « N prêt(s) »
  -- (qui mord BADGE_OVERLAP px sur le haut de la case) : jamais l'un sous l'autre.
  local over = (ns.Theme and ns.Theme.BADGE_OVERLAP) or 4
  fs:SetPoint("TOPLEFT", t, "TOPLEFT", 4, -(math.max(over, 2) + 2))   -- 3.3.17 : sous le biseau
  if fs.SetWordWrap then pcall(fs.SetWordWrap, fs, false) end
  fs:SetTextColor(T.GREEN[1], T.GREEN[2], T.GREEN[3])
  m.fs = fs
  t._osrsTgt = m
  T.stats.marksCreated = T.stats.marksCreated + 1
  return m
end

-- Application à la grille (sans recalcul).
function T.Paint()
  T.stats.paints = T.stats.paints + 1
  local res = T.current or {}
  local tiles = UI.embed and UI.embed.tiles or {}
  local prev = T._lvlSig or {}
  local sig = {}
  for _, t in ipairs(tiles) do
    local key = t.data and t:IsShown() and T.KeyFor(t.data)
    local e = key and res[key]
    sig[t] = e and e.level or "-"
  end
  local n = 0
  for _, t in ipairs(tiles) do
    if prev[t] == sig[t] then
      if sig[t] ~= "-" then n = n + 1 end
    else
    local key = t.data and t:IsShown() and T.KeyFor(t.data)
    local e = key and res[key]
    if e then
      local m = T.Mark(t)
      local base = t.GetFrameLevel and t:GetFrameLevel() or 1
      pcall(m.SetFrameLevel, m, base + 4)
      -- Pré-sélection : liseré coloré seulement (pas de voile, pas de « +1 »).
      if m.veil then
        if m.veil.SetAlpha then pcall(m.veil.SetAlpha, m.veil, 0) end
        if m.veil.Hide then m.veil:Hide() end
      end
      if m.fs then
        if m.fs.SetText then m.fs:SetText("") end
        if m.fs.Hide then m.fs:Hide() end
      end
      t._tgtCol = T.GainColor(t.data)
      t._tgtLit = (e.level == "direct") and "direct" or "indirect"
      if ns.Theme and ns.Theme.BevelColor then pcall(ns.Theme.BevelColor, t) end
      m._level = e.level
      t._tgtWhy = e
      m:Show()
      n = n + 1
    else
      t._tgtWhy = nil
      if t._osrsTgt then t._osrsTgt:Hide() t._osrsTgt._level = nil end
      if t._tgtLit then t._tgtLit, t._tgtCol = nil, nil if ns.Theme and ns.Theme.BevelColor then pcall(ns.Theme.BevelColor, t) end end
    end
    end
  end
  T._lvlSig = sig
  T.shown = n
  return n
end
function T.Clear()
  T.current, T.target, T._lvlSig = nil, nil, nil
  for _, t in ipairs(UI.embed and UI.embed.tiles or {}) do
    t._tgtWhy = nil
    if t._osrsTgt then t._osrsTgt:Hide() t._osrsTgt._level = nil end
    if t._tgtLit then t._tgtLit, t._tgtCol = nil, nil if ns.Theme and ns.Theme.BevelColor then pcall(ns.Theme.BevelColor, t) end end
  end
  T.shown = 0
end
function T.Refresh(why)
  T.stats.events = T.stats.events + 1
  if ns.PausedForFlight and ns.PausedForFlight() then T.Clear() return nil end
  if not T.Enabled() then T.Clear() return nil end
  local tg = T.ReadTarget()
  if not tg then T.Clear() return nil end
  T.target = tg
  if not (W.IsShown() and UI.embed) then T.current = nil return nil end   -- calculé à l'ouverture
  T.current = T.Result(tg)
  return T.Paint()
end

-- Infobulle de case : « Cible : … » et les raisons.
if ns.Compact and ns.Compact.TooltipModel then
  local baseModel = ns.Compact.TooltipModel
  function ns.Compact.TooltipModel(d)
    local m = baseModel(d)
    local key = T.KeyFor(d)
    local e = key and T.current and T.current[key]
    if e and T.target then
      m.lines[#m.lines + 1] = { " ", 1, 1, 1, false, spacer = true }
      local head = Tr["Cible : "] .. tostring(T.target.name or "?") .. (e.level == "direct" and Tr["  (+1 possible)"] or (e.combat and Tr["  (éligible, pas de frappe)"] or Tr["  (lien indirect)"]))
      m.lines[#m.lines + 1] = { head, T.GREEN[1], T.GREEN[2], T.GREEN[3], false, header = true }
      for _, l in ipairs(e.why) do m.lines[#m.lines + 1] = { l, 0.75, 1, 0.75, true } end
      m.target = e
    elseif T.target and d and d.combatTile and T.current then
      -- 3.3.9 : pourquoi une case de combat n'est PAS en vert (plafond, forme)
      local notes = T._notes and T._notes[T.current]
      for _, l in ipairs(notes or {}) do
        if l:find(tostring(d.name), 1, true) == 1 then
          m.lines[#m.lines + 1] = { " ", 1, 1, 1, false, spacer = true }
          m.lines[#m.lines + 1] = { Tr["Cible : "] .. tostring(T.target.name or "?"), 0.7, 0.7, 0.7, false, header = true }
          m.lines[#m.lines + 1] = { l, 0.7, 0.7, 0.7, true }
        end
      end
    end
    return m
  end
end

-- Grille reconstruite / panneau rouvert : on repeint (le résultat est en cache).
local baseApply = UI.ApplyView
function UI:ApplyView(...)
  local r = { baseApply(self, ...) }
  if T.current then pcall(T.Paint) end
  return unpack(r)
end
local baseShow = W.Show
function W.Show(...)
  local r = { baseShow(...) }
  if T.target or Call(_G.UnitExists, "target") then pcall(T.Refresh, "ouverture") end
  return unpack(r)
end

if ns.On then
  ns.On("PLAYER_TARGET_CHANGED", function() pcall(T.Refresh, "cible") end)
  ns.On("PLAYER_LEVEL_UP", function() T._rankVer = (T._rankVer or 0) + 1 if T.target then pcall(T.Refresh, "niveau") end end)
  ns.On("CHAT_MSG_SKILL", function() T._rankVer = (T._rankVer or 0) + 1 if T.target then pcall(T.Refresh, "rang") end end)
  ns.On("PLAYER_REGEN_ENABLED", function() if T.target then pcall(T.Refresh, "fin de combat") end end)
  -- 3.3.8 : changement de forme (druide) → la cible est réévaluée (résultat en cache par forme)
  local function onForm() if T.target or (Call(_G.UnitExists, "target")) then pcall(T.Refresh, "forme") end end
  ns.On("UPDATE_SHAPESHIFT_FORM", onForm)
  ns.On("UPDATE_SHAPESHIFT_FORMS", onForm)
  -- 3.3.15 : passage énergie / rage (sonde UnitPowerType) — joueur seulement
  ns.On("UNIT_DISPLAYPOWER", function(_, unit) if unit == "player" then onForm() end end)
  -- 3.3.15 : arme équipée / frappe en cours (deux niveaux de surbrillance)
  local function refresh(why) if T.target or (Call(_G.UnitExists, "target")) then pcall(T.Refresh, why) end end
  ns.On("PLAYER_ENTER_COMBAT", function() T.swing.melee = true refresh("attaque") end)
  ns.On("PLAYER_LEAVE_COMBAT", function() T.swing.melee = false refresh("fin d'attaque") end)
  ns.On("START_AUTOREPEAT_SPELL", function() T.swing.ranged = true refresh("tir") end)
  ns.On("STOP_AUTOREPEAT_SPELL", function() T.swing.ranged = false refresh("fin de tir") end)
  ns.On("PLAYER_REGEN_DISABLED", function() refresh("combat") end)
  ns.On("UNIT_TARGET", function(_, unit) if unit == "target" then refresh("cible de la cible") end end)
  ns.On("PLAYER_EQUIPMENT_CHANGED", function(_, slot)
    if slot == nil or slot == 16 or slot == 17 or slot == 18 then T._equipSig = nil refresh("équipement") end
  end)
  -- cache objets : ne recalcule que si la lecture de l'équipement a changé
  ns.On("GET_ITEM_INFO_RECEIVED", function()
    if not (T.target or Call(_G.UnitExists, "target")) then return end
    local sig = T.Equipped().sig
    if sig ~= T._equipSig then T._equipSig = sig refresh("objet chargé") end
  end)
end

-- /drop alertes : coupe / rétablit aussi la surbrillance.
if ns.SlashExt and ns.SlashExt.alertes then
  local baseAlert = ns.SlashExt.alertes
  ns.SlashExt.alertes = function(...)
    baseAlert(...)
    pcall(T.Refresh, "alertes")
  end
end

-- /drop perf : ligne de la surbrillance de cible.
-- /drop debug : forme détectée, case farouche, verdict sur la cible
ns.DebugExt = ns.DebugExt or {}
ns.DebugExt[#ns.DebugExt + 1] = function()
  local out = { "— Cible / forme (3.3.15) —" }
  local _, class = Call(_G.UnitClass, "player")
  local form, how = T.FeralForm()
  out[#out + 1] = "  classe " .. tostring(class) .. " ; forme : " .. tostring(form or "humanoïde / aucune") .. " (" .. tostring(how) .. ")"
    .. " ; GetShapeshiftFormID=" .. tostring(Call(_G.GetShapeshiftFormID)) .. ", GetShapeshiftForm=" .. tostring(Call(_G.GetShapeshiftForm))
  local parts = {}
  for _, r in ipairs(T.FormProbe()) do parts[#parts + 1] = r[1] .. "=" .. tostring(r[2] or "non") .. " (" .. tostring(r[3]) .. ")" end
  out[#out + 1] = "  sondes : " .. table.concat(parts, " ; ")
  out[#out + 1] = T.EquipDebug()
  local feral
  local feralT
  for _, t in ipairs(UI.embed and UI.embed.tiles or {}) do if t.data and T.IsFeralTile(t.data) then feral, feralT = t.data, t end end
  out[#out + 1] = "  case farouche : " .. (feral and string.format("%s (type %s, id %s, ligne %s) %s/%s%s", tostring(feral.name), tostring(feral.kind), tostring(feral.id), tostring(feral.skillID), tostring(feral.current), tostring(feral.apiMax), feral.placeholder and " [emplacement vide]" or "") or "introuvable dans la grille")
  if feral then
    local m = feralT and feralT._osrsTgt
    out[#out + 1] = "  case farouche : clé " .. tostring(T.KeyFor(feral)) .. " ; surbrillance " .. ((m and m:IsShown()) and "VERTE" or "éteinte")
  end
  local tg = T.target or T.ReadTarget()
  if tg then
    local r = T.Compute(tg)
    local lit = {}
    for k in pairs(r) do lit[#lit + 1] = k end
    table.sort(lit)
    out[#out + 1] = "  cible " .. tostring(tg.name) .. " niv. " .. tostring(tg.level) .. " : " .. (#lit > 0 and table.concat(lit, ", ") or "rien")
    for _, l in ipairs(T.notes or {}) do out[#out + 1] = "    " .. l end
  end
  return out
end

if ns.Gather and ns.Gather.PerfLines then
  local basePerf = ns.Gather.PerfLines
  function ns.Gather.PerfLines()
    local out = basePerf()
    local st = T.stats
    table.insert(out, #out, string.format("perf : cible %d événements → %d calculs (%d en cache), %d peintures, %d marques créées (une par case au plus)",
      st.events, st.computes, st.cached, st.paints, st.marksCreated))
    return out
  end
end
