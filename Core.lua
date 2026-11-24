-- Dropamine 2.8.0 — collecte, formules, événements, /drop, /drop debug
-- Client : WoW Forever (Interface 16001). Chaque API est protégée (type + pcall).

local ADDON, ns = ...
if type(ns) ~= "table" then
  ns = _G.Dropamine or {}
  ADDON = ADDON or "Dropamine"
end
_G.Dropamine = ns
ns.ADDON = ADDON
local Tr = ns.L   -- 3.5.19 : textes traduits (Locales/)
ns.VERSION = (function()
  local f = (_G.C_AddOns and _G.C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
  if f then local ok, v = pcall(f, ADDON or "Dropamine", "Version") if ok and type(v) == "string" and v ~= "" then return v end end
  return "3.10.0"
end)()
-- DEV ONLY : une seule ligne à passer à true pour rétablir la section Options « Test » et /drop test.
-- Éteint sur la version publique.
ns.DEV_TEST = false


-- v2.5.0 : valeurs « secrètes » de Forever (UnitStat, UnitXP… en combat).
-- Toute comparaison ou opération sur une valeur secrète lève une erreur et
-- souille l'exécution : chaque nombre venu d'une API passe par ns.N().
local function cmpProbe(n) return n < 0 end
function ns.IsSecret(v)
  local f = _G.issecretvalue
  if type(f) == "function" then
    local ok, r = pcall(f, v)
    if ok and r then return true end
  end
  return false
end
-- 3.7.3 : en instance, le client renvoie des valeurs secrètes (booléens, noms…)
-- pour les unités ; tout test (if / and / ==) dessus lève une erreur. Les enveloppes
-- Call() des modules d'unités passent le 1er retour ici : secret -> nil.
function ns.Unsecret(a, ...)
  if a ~= nil and ns.IsSecret(a) then return nil, ... end
  return a, ...
end
-- 3.3.14 : jeton de bord UNIQUE (STYLE.md) — panneau, toasts, cases, pastilles,
-- barre total, case JcJ. Vert / gris = sens (cible, barres de nom), jamais le repos.
ns.STYLE = ns.STYLE or {}
ns.STYLE.BORDER = { 0.65, 0.49, 0.27, 1 }          -- #A67D45
ns.STYLE.BORDER_INNER = { 66 / 255, 52 / 255, 34 / 255, 1 }
-- 3.3.15 : bord d'icône = filet bronze de 1 px (même jeton), ombre noire dehors,
-- liseré dedans, coins biseautés (Theme.IconSkin) ; icône recadrée 0.08–0.92.
ns.STYLE.ICON_CROP = { 0.08, 0.92, 0.08, 0.92 }
ns.STYLE.SELECT = { 1, 0.86, 0.46, 1 }
function ns.N(v)
  if v == nil then return nil end
  if ns.IsSecret(v) then return nil end
  local n = tonumber(v)
  if n == nil then return nil end
  -- Dernier filet : une valeur secrète non signalée lève à la comparaison.
  if not pcall(cmpProbe, n) then return nil end
  return n
end

local PREFIX = "|cffffd100Dropamine|r: "
-- v2.7.1 : combat. Tout ce qui ouvre / pilote une fenêtre native attend la
-- fin du combat (PLAYER_REGEN_ENABLED) au lieu de s'exécuter souillé.
function ns.InCombat()
  if type(InCombatLockdown) ~= "function" then return false end
  local ok, v = pcall(InCombatLockdown)
  return ok and v == true
end
ns._afterCombat = {}
function ns.AfterCombat(key, fn)
  if not ns.InCombat() then fn() return true end
  ns._afterCombat[key] = fn
  if not ns._regenFrame and type(CreateFrame) == "function" then
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function()
      local q = ns._afterCombat
      ns._afterCombat = {}
      for _, g in pairs(q) do pcall(g) end
    end)
    ns._regenFrame = f
  end
  return false
end

function ns.Print(msg)
  if type(print) == "function" then print(PREFIX .. tostring(msg)) end
end

-- 3.10.0 : mode Hardcore (à venir sur Forever) : règle HC active. Test : ns._forceHC (/drop hc simu).
function ns.IsHardcore()
  if ns._forceHC then return true end
  local gr = _G.C_GameRules
  if type(gr) ~= "table" then return false end
  if type(gr.IsHardcoreActive) == "function" then
    local ok, v = pcall(gr.IsHardcoreActive)
    if ok and v == true then return true end
  end
  local E = _G.Enum and _G.Enum.GameRule
  if E and E.HardcoreRuleset and type(gr.IsGameRuleActive) == "function" then
    local ok, v = pcall(gr.IsGameRuleActive, E.HardcoreRuleset)
    if ok and v == true then return true end
  end
  return false
end

-- Plafonds pour le total personnalisé (plus de conversion 1-99).
-- Niveau 60 : documenté dans les notes Forever (buffs de camp, raciaux, plantes).
-- Métiers / secondaires / défense / armes : palier 300 attesté (objets de camp
-- « compétence 140 et 300 »). Le racial Culture mentionne des plantes « > 300 » :
-- le plafond réel peut être plus haut, mais aucun chiffre n'est publié.
-- Monte : aucun plafond documenté → affichée si apprise, exclue du total.
ns.DOCUMENTED_LEVEL_CAP = 60
ns.PROFESSION_REF_CAP = 300
ns.WEAPON_RANK_PER_LEVEL = 5
-- 60 + 2×300 (métiers) + 3×300 (Cuisine, Pêche, Secourisme) + 3×300 (Mêlée, Distance/Farouche, Défense) = 2460
ns.TOTAL_MAX = 60 + 2 * 300 + 3 * 300 + 3 * 300
-- 3.8.1 : maximum réaliste selon la classe. Le total compte 3 cases de combat (mêlée, distance/farouche,
-- défense) ; une classe qui n'a pas de 2e compétence d'arme utile ne peut pas remplir la case concernée
-- (paladin et chaman : pas d'arme à distance ; prêtre, mage, démoniste : seule la baguette monte).
-- À ajuster ici si la règle change.
ns.CLASS_MISSING_WEAPON = { PALADIN = "distance", SHAMAN = "distance", PRIEST = "mêlée", MAGE = "mêlée", WARLOCK = "mêlée" }
function ns.ClassMax()
  local ok, _, file = pcall(_G.UnitClass, "player")
  if not ok or type(file) ~= "string" then return nil end
  local missing = ns.CLASS_MISSING_WEAPON[file]
  if not missing then return nil end
  return ns.TOTAL_MAX - ns.PROFESSION_REF_CAP, missing
end

local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c, d, e, f, g, h, i, j, k, l, m = pcall(fn, ...)
  if not ok then return nil end
  return a, b, c, d, e, f, g, h, i, j, k, l, m
end

function ns.GetPlayerLevel()
  local lvl = ns.N(Call(UnitLevel, "player"))
  if lvl and lvl > 0 then
    ns._lastPlayerLevel = lvl
    return lvl
  end
  -- Valeur secrète en combat (ou lecture ratée) : dernier niveau connu.
  if ns._lastPlayerLevel and ns._lastPlayerLevel > 0 then return ns._lastPlayerLevel end
  return 0
end

function ns.GetLevelCap()
  local mpl = ns.N(MAX_PLAYER_LEVEL)
  if mpl and mpl > 0 then return mpl end
  if type(GetMaxLevelForPlayerExpansion) == "function" then
    local v = ns.N(Call(GetMaxLevelForPlayerExpansion))
    if v and v > 0 then return v end
  end
  return ns.DOCUMENTED_LEVEL_CAP
end

function ns.GetPlayerName()
  local n = Call(UnitName, "player")
  if type(n) == "string" and not ns.IsSecret(n) and n ~= "" then return n end
  return nil
end

function ns.GetStat(index)
  local okS, stat, effective, pos, neg = pcall(Call, UnitStat, "player", index)
  if not okS then return nil end
  stat, effective, pos, neg = ns.N(stat), ns.N(effective), ns.N(pos), ns.N(neg)
  if not effective and not stat then return nil end
  return {
    base = ns.N(stat) or 0,
    effective = ns.N(effective) or ns.N(stat) or 0,
    pos = ns.N(pos) or 0,
    neg = ns.N(neg) or 0,
  }
end

-- Couleur du chiffre rang/max (pas des barres, qui restent bleues).
-- palier (défaut) : rouge < 50 %, jaune 50-75 %, vert > 75 %.
-- Teintes calquées sur la réputation Forever (hostile / neutre / amical).
ns.NUMBER_COLOR_THRESHOLDS = {
  redBelow = 0.50,
  greenAbove = 0.75,
  red = { 0.95, 0.22, 0.18 },
  yellow = { 1.00, 0.82, 0.15 },
  green = { 0.15, 0.95, 0.30 },
}

function ns.GetColorMode()
  local m = ns.db and ns.db.ui and ns.db.ui.colorMode
  if m == "vert" or m == "jaune" or m == "palier" then return m end
  return "palier"
end

function ns.SetColorMode(mode)
  if mode ~= "vert" and mode ~= "jaune" and mode ~= "palier" then return ns.GetColorMode() end
  if not ns.db then DropamineDB = DropamineDB or {} DropamineDB.ui = DropamineDB.ui or {} ns.db = DropamineDB end
  ns.db.ui = ns.db.ui or {}
  ns.db.ui.colorMode = mode
  return mode
end

function ns.NumberColorForProgress(cur, cap)
  local t = ns.NUMBER_COLOR_THRESHOLDS
  local mode = ns.GetColorMode()
  if mode == "vert" then return t.green, mode, 1 end
  if mode == "jaune" then return t.yellow, mode, 1 end
  cur, cap = ns.N(cur) or 0, ns.N(cap) or 0
  local pct = 0
  if cap > 0 then
    pct = cur / cap
    if pct < 0 then pct = 0 end
  end
  if pct < t.redBelow then return t.red, "palier", pct end
  if pct <= t.greenAbove then return t.yellow, "palier", pct end
  return t.green, "palier", pct
end

-- v2.8.0 : couleur du rang selon la situation (mode « palier » seulement).
-- Seuils des rangs de métier : données WoW Forever uniquement (Wowhead Forever,
-- relevé du 16/11/2026). Clé = maximum actuel (75/150/225) ; skill = points
-- requis pour apprendre le rang suivant ; level = niveau requis s'il est indiqué ;
-- nil = seuil non documenté → jamais vert pour ce rang.
ns.PROF_FINAL_CAP = 300
local PRIMARY_TIERS = {
  -- Liste des sorts de métier Forever (/forever/spells/professions/…) : Compagnon
  -- « learnedat » 50, Expert 125, Artisan 200, enseignés par le maître (source 6).
  -- Aucun niveau de personnage n'y est indiqué : non vérifié.
  [75] = { skill = 50, rank = "Compagnon", src = "maître" },
  [150] = { skill = 125, rank = "Expert", src = "maître" },
  [225] = { skill = 200, rank = "Artisan", src = "maître" },
}
ns.PROF_TIERS = {
  alchemy = PRIMARY_TIERS, blacksmithing = PRIMARY_TIERS, enchanting = PRIMARY_TIERS,
  engineering = PRIMARY_TIERS, herbalism = PRIMARY_TIERS, leatherworking = PRIMARY_TIERS,
  mining = PRIMARY_TIERS, skinning = PRIMARY_TIERS, tailoring = PRIMARY_TIERS,
  cooking = {
    [75] = { skill = 50, rank = "Compagnon", src = "maître" },              -- sort 3102 « Requires Cooking (50) »
    [150] = { skill = 125, rank = "Expert", src = "livre" },                -- Expert Cookbook (16072) « Requires Cooking (125) »
    [225] = { skill = nil, level = 35, rank = "Artisan", src = "quête" },   -- quête 6610 « Requires level 35 », points non indiqués
  },
  firstaid = {
    [75] = { skill = 50, rank = "Compagnon", src = "maître" },              -- sort 3274 « Requires First Aid (50) »
    [150] = { skill = 125, rank = "Expert", src = "livre" },                -- Expert First Aid - Under Wraps (16084)
    [225] = { skill = nil, level = 35, rank = "Artisan", src = "quête" },   -- quête Triage 6622/6624 « Requires level 35 »
  },
  fishing = {
    [75] = { skill = 50, rank = "Compagnon", src = "maître" },              -- sort 7731, learnedat 50
    [150] = { skill = 125, level = 20, rank = "Expert", src = "livre" },    -- Expert Fishing - The Bass and You (16083) : niveau 20, Pêche 125
    [225] = { skill = nil, level = 35, rank = "Artisan", src = "quête" },   -- sort 18248, quête 6607 « Nat Pagle, Angler Extreme » : niveau 35, points non indiqués
  },
}
ns.RANK_TEXT = {
  available = "Rang supérieur disponible chez le maître",
}
ns.WEAPON_RED_GAP = 25   -- choix de l'addon (pas une règle de jeu) : rouge à 25 points ou plus sous le maximum actuel
ns.GOLD_NEUTRAL = { 1, 0.82, 0 }

local function PlayerLevel() return ns.N(Call(UnitLevel, "player")) end
ns.PlayerLevel = PlayerLevel

-- XP du niveau en cours (lecture hors combat, jamais de comparaison de valeur secrète).
function ns.LevelXPInfo()
  local cur, max = ns.GetPlayerXPSafe()
  local rested = ns.N(Call(_G.GetXPExhaustion))
  if cur and max and max > 0 then
    ns._lastXP = { cur = cur, max = max, rested = rested or 0 }
  end
  return ns._lastXP
end

function ns.RankStatus(d, cur, cap)
  local t = ns.NUMBER_COLOR_THRESHOLDS
  if not d then return nil end
  local mode = ns.GetColorMode()
  if mode ~= "palier" then return nil end
  cur, cap = ns.N(cur) or 0, ns.N(cap) or 0
  local id, kind = d.id, d.kind
  if kind == "level" then
    local lvl = ns.N(d.current) or PlayerLevel() or 0
    local lcap = ns.GetLevelCap and ns.GetLevelCap() or 60
    if lvl >= lcap then return { col = ns.GOLD_NEUTRAL, state = "max", note = Tr["Niveau maximum atteint."] } end
    local xp = ns.LevelXPInfo()
    if not xp then return nil end
    local pct = xp.cur / xp.max
    local col = (pct < t.redBelow) and t.red or ((pct <= t.greenAbove) and t.yellow or t.green)
    local note = string.format(Tr["XP : %d / %d (%d %%)"], xp.cur, xp.max, math.floor(pct * 100 + 0.5))
    if xp.rested and xp.rested > 0 then
      note = note .. string.format(Tr["\nXP reposée : %d (%d %% du niveau)"], xp.rested, math.floor(xp.rested / xp.max * 100 + 0.5))
    end
    return { col = col, state = "xp", pct = pct, note = note, xp = xp }
  end
  local tiers = ns.PROF_TIERS[id]
  if tiers and (kind == "profession" or kind == "secondary") and cap > 0 then
    local final = ns.PROF_FINAL_CAP
    if cap >= final then
      if cur >= final then return { col = ns.GOLD_NEUTRAL, state = "max", note = Tr["Rang maximum ("] .. final .. ")." } end
      return { col = t.yellow, state = "final", note = string.format(Tr["encore %d points avant %d"], final - cur, final) }
    end
    local nx = tiers[cap]
    local atCap = cur >= cap
    if not nx or not nx.skill then
      local why = Tr["Seuil du rang suivant non documenté par WoW Forever."]
      if nx and nx.level then why = why .. Tr[" (niveau "] .. nx.level .. Tr[" requis)"] end
      return { col = atCap and t.red or t.yellow, state = atCap and "blocked" or "unknown", note = why }
    end
    local lvl = PlayerLevel()
    local missSkill = math.max(0, nx.skill - cur)
    local missLevel = (nx.level and lvl and lvl < nx.level) and nx.level or nil
    if missSkill == 0 and not missLevel then
      local note = Tr[ns.RANK_TEXT.available]
      if nx.src == "livre" then note = Tr["Rang supérieur disponible ("] .. Tr[nx.rank] .. Tr[" : livre)"] end
      if nx.src == "quête" then note = Tr["Rang supérieur disponible ("] .. Tr[nx.rank] .. Tr[" : quête)"] end
      return { col = t.green, state = "available", note = note }
    end
    local parts = {}
    if missSkill > 0 then parts[#parts + 1] = string.format(Tr["encore %d points de métier"], missSkill) end
    if missLevel then parts[#parts + 1] = string.format(Tr["niveau %d requis"], missLevel) end
    local note = Tr[nx.rank] .. Tr[" : "] .. table.concat(parts, Tr[" et "])
    -- Rouge : bloqué au maximum actuel sans rang apprenable (il manque des niveaux).
    if atCap and missLevel then return { col = t.red, state = "blocked", note = note } end
    return { col = t.yellow, state = "missing", note = note }
  end
  if (kind == "melee" or kind == "ranged" or kind == "defense") and cap > 0 then
    -- Forever ne documente pas la règle toucher / compétence : on compare
    -- seulement le rang au maximum actuel lu en jeu (aucun % de toucher annoncé).
    local gap = cap - cur
    if gap <= 0 then return { col = t.green, state = "weaponMax", note = Tr["Au maximum actuel ("] .. cap .. ")." } end
    local note = string.format(Tr["encore %d points avant ton maximum actuel (%d)"], gap, cap)
    if gap >= ns.WEAPON_RED_GAP then return { col = t.red, state = "weaponFar", note = note } end
    return { col = t.yellow, state = "weaponBelow", note = note }
  end
  return nil
end

-- nil, nil si les valeurs sont secrètes (combat) : on ne compare rien.
function ns.GetPlayerXPSafe()
  return ns.N(Call(UnitXP, "player")), ns.N(Call(UnitXPMax, "player"))
end
function ns.GetPlayerXP()
  local cur, maxxp = ns.GetPlayerXPSafe()
  if cur and maxxp and maxxp > 0 then
    ns._lastPlayerXP, ns._lastPlayerXPMax = cur, maxxp
    return cur, maxxp
  end
  if ns._lastPlayerXP and ns._lastPlayerXPMax then
    return ns._lastPlayerXP, ns._lastPlayerXPMax
  end
  return cur or 0, maxxp or 0
end

-- Icône d'une tuile / d'une compétence (pour les drops : jamais le portrait).
ns.LEVEL_ICON = "Interface\\AddOns\\Dropamine\\Media\\XP-Icon"
ns.SPELLS_ICON = "Interface\\AddOns\\Dropamine\\Media\\Spells-Icon"
ns.RANK_BADGE = "Interface\\AddOns\\Dropamine\\Media\\Rank-Badge"
ns.FARM_ICON = "Interface\\AddOns\\Dropamine\\Media\\Farm-Spots-Icon"

-- 3.5.18 : icône absente = nil, 0, chaîne vide ou point d'interrogation (134400)
function ns.IconMissing(icon)
  if icon == nil or icon == 0 or icon == "" then return true end
  if icon == 134400 then return true end
  if type(icon) == "string" then
    local l = icon:lower():gsub("/", "\\")
    if l:find("inv_misc_questionmark", 1, true) then return true end
  end
  if ns.IsSecret and ns.IsSecret(icon) then return true end
  return false
end
local WEAPON_WORDS = { "hache", "masse", "epee", "dague", "baton", "arc", "arbalete", "arme", "baguette", "pugilat", "hast",
  "axe", "mace", "sword", "dagger", "stave", "staff", "bow", "gun", "crossbow", "thrown", "wand", "fist", "polearm", "unarmed", "mains nues" }
function ns.LooksLikeWeapon(name, header)
  local h = ns.Fold(header or "")
  if h == "competences d armes" or h == "weapon skills" or h == "armes" then return true end
  local n = ns.Fold(name or "")
  for _, w in ipairs(WEAPON_WORDS) do
    if n == w or n:find("^" .. w) then return true end
  end
  return false
end
-- icône d'une compétence : catalogue (nom exact, alias), ligne de compétence,
-- icônes annexes (Ambidextrie), puis icône générique d'arme, jamais « ? »
function ns.ResolveSkillIcon(name, header, skillLine)
  local e = ns.LookupCatalog and ns.LookupCatalog(name)
  if e and not ns.IconMissing(e.icon) then return e.icon, e.id, "catalogue" end
  local ln = ns.N(skillLine)
  if ln and ns.CATALOG_BY_LINE and ns.CATALOG_BY_LINE[ln] then
    local le = ns.CATALOG_BY_LINE[ln]
    return le.icon, le.id, "ligne " .. ln
  end
  if ln and ns.EXTRA_SKILL_LINES and ns.EXTRA_SKILL_LINES[ln] then return ns.EXTRA_SKILL_LINES[ln], nil, "ligne " .. ln end
  local x = ns.EXTRA_SKILL_ICONS and ns.EXTRA_SKILL_ICONS[ns.Fold(name or "")]
  if x then return x, nil, "annexe" end
  if ns.Style and ns.Style.SkillIdForText then
    local ok, id = pcall(ns.Style.SkillIdForText, name)
    local se = ok and id and ns.CATALOG_BY_ID and ns.CATALOG_BY_ID[id]
    if se and not ns.IconMissing(se.icon) then return se.icon, se.id, "texte" end
  end
  if ns.LooksLikeWeapon(name, header) then return ns.WEAPON_FALLBACK_ICON, nil, "arme (générique)" end
  return nil, nil, "aucune"
end

function ns.IconForSkillName(name, kind, header, skillLine)
  if kind == "level" or ns.Fold(name or "") == "niveau" then
    return ns.LEVEL_ICON
  end
  local icon = ns.ResolveSkillIcon(name, header, skillLine)
  return icon or ns.FALLBACK_ICON
end

-- Arme équipée → compétence (emplacements 16 = main, 18 = distance) ----------
-- Sous-classes d'armes (GetItemInfo classID 2 / subclassID), classiques Forever.
local WEAPON_SUBCLASS_TO_ID = {
  [0] = "axes", [1] = "axes2h", [2] = "bows", [3] = "guns",
  [4] = "maces", [5] = "maces2h", [6] = "polearms", [7] = "swords",
  [8] = "swords2h", [10] = "staves", [13] = "fist", [15] = "daggers",
  [16] = "thrown", [17] = "polearms", [18] = "crossbows", [19] = "wands",
}

local WEAPON_SUBTYPE_TO_ID = {
  ["haches"] = "axes", ["hache"] = "axes", ["haches a une main"] = "axes",
  ["haches a deux mains"] = "axes2h", ["hache a deux mains"] = "axes2h",
  ["masses"] = "maces", ["masse"] = "maces", ["masses a une main"] = "maces",
  ["masses a deux mains"] = "maces2h", ["masse a deux mains"] = "maces2h",
  ["epees"] = "swords", ["epee"] = "swords", ["epees a une main"] = "swords",
  ["epees a deux mains"] = "swords2h", ["epee a deux mains"] = "swords2h",
  ["armes d hast"] = "polearms", ["arme d hast"] = "polearms", ["hast"] = "polearms",
  ["batons"] = "staves", ["baton"] = "staves",
  ["armes de pugilat"] = "fist", ["arme de pugilat"] = "fist", ["pugilat"] = "fist",
  ["dagues"] = "daggers", ["dague"] = "daggers",
  ["mains nues"] = "unarmed",
  ["arcs"] = "bows", ["arc"] = "bows",
  ["armes a feu"] = "guns", ["arme a feu"] = "guns", ["fusils"] = "guns", ["fusil"] = "guns",
  ["arbaletes"] = "crossbows", ["arbalete"] = "crossbows",
  ["armes de jet"] = "thrown", ["arme de jet"] = "thrown",
  ["baguettes"] = "wands", ["baguette"] = "wands",
  ["axes"] = "axes", ["one handed axes"] = "axes",
  ["two handed axes"] = "axes2h",
  ["maces"] = "maces", ["one handed maces"] = "maces",
  ["two handed maces"] = "maces2h",
  ["swords"] = "swords", ["one handed swords"] = "swords",
  ["two handed swords"] = "swords2h",
  ["polearms"] = "polearms",
  ["staves"] = "staves", ["staff"] = "staves",
  ["fist weapons"] = "fist", ["fist"] = "fist",
  ["daggers"] = "daggers",
  ["unarmed"] = "unarmed",
  ["bows"] = "bows", ["bow"] = "bows",
  ["guns"] = "guns", ["gun"] = "guns",
  ["crossbows"] = "crossbows", ["crossbow"] = "crossbows",
  ["thrown"] = "thrown",
  ["wands"] = "wands", ["wand"] = "wands",
}

local RANGED_IDS = { bows = true, guns = true, crossbows = true, thrown = true, wands = true }

function ns.GetInventorySlot(kind)
  if kind == "ranged" then
    if type(INVSLOT_RANGED) == "number" then return INVSLOT_RANGED end
    local id = Call(GetInventorySlotInfo, "RangedSlot")
    if type(id) == "number" then return id end
    return 18
  end
  if type(INVSLOT_MAINHAND) == "number" then return INVSLOT_MAINHAND end
  local id = Call(GetInventorySlotInfo, "MainHandSlot")
  if type(id) == "number" then return id end
  return 16
end

function ns.MapWeaponSubtype(subType, classID, subclassID)
  if type(subclassID) == "number" and (classID == nil or classID == 2) then
    local id = WEAPON_SUBCLASS_TO_ID[subclassID]
    if id then return id end
  end
  local folded = ns.Fold(subType or "")
  if folded ~= "" then
    if WEAPON_SUBTYPE_TO_ID[folded] then return WEAPON_SUBTYPE_TO_ID[folded] end
    local e = ns.LookupCatalog and ns.LookupCatalog(subType)
    if e and (e.kind == "melee" or e.kind == "ranged") then return e.id end
  end
  return nil
end

function ns.GetEquippedItemInfo(slot)
  if not slot then return nil end
  local itemID = Call(GetInventoryItemID, "player", slot)
  local link = Call(GetInventoryItemLink, "player", slot)
  local tex = Call(GetInventoryItemTexture, "player", slot)
  if itemID == nil and (link == nil or link == "") then
    return nil
  end
  local name, itemType, itemSubType, itemEquipLoc, itemTexture, classID, subclassID
  if type(GetItemInfo) == "function" then
    local n, _, _, _, _, typ, sub, _, eq, tex2, _, cid, sid = Call(GetItemInfo, link or itemID)
    name, itemType, itemSubType, itemEquipLoc, itemTexture, classID, subclassID = n, typ, sub, eq, tex2, cid, sid
  end
  if (not itemSubType or classID == nil) and type(C_Item) == "table" and type(C_Item.GetItemInfoInstant) == "function" then
    local _, typ, sub, eq, icon, cid, sid = Call(C_Item.GetItemInfoInstant, itemID or link)
    itemType = itemType or typ
    itemSubType = itemSubType or sub
    itemEquipLoc = itemEquipLoc or eq
    itemTexture = itemTexture or icon
    classID = classID or cid
    subclassID = subclassID or sid
  end
  return {
    id = itemID,
    link = link,
    texture = tex or itemTexture,
    name = name,
    subType = itemSubType,
    itemType = itemType,
    classID = classID,
    subclassID = subclassID,
    equipLoc = itemEquipLoc,
  }
end

function ns.CatalogById(id)
  if not id or not ns.CATALOG then return nil end
  for i = 1, #ns.CATALOG do
    if ns.CATALOG[i].id == id then return ns.CATALOG[i] end
  end
  return nil
end

function ns.LiveForEntry(byName, entry)
  if not entry or not byName then return nil end
  local live = byName[ns.Fold(entry.name or "")]
  if live then return live end
  if entry.aliases then
    for j = 1, #entry.aliases do
      live = byName[ns.Fold(entry.aliases[j])]
      if live then return live end
    end
  end
  return nil
end

function ns.BestLearnedMeleeEntry(byName)
  local bestE, bestLive, bestRank
  for i = 1, #ns.CATALOG do
    local e = ns.CATALOG[i]
    if e.kind == "melee" and e.id ~= "feral" then
      local live = ns.LiveForEntry(byName, e)
      local r = live and (ns.N(live.rank) or 0) or 0
      if r > 0 and (not bestRank or r > bestRank) then
        bestE, bestLive, bestRank = e, live, r
      end
    end
  end
  return bestE, bestLive
end

-- Instantané des rangs (pour les drops de compétence). Jamais le portrait.
function ns.SkillRankSnapshot()
  local live = ns.CollectLiveSkills()
  local map = {}
  if not live then return map end
  for i = 1, #live do
    local s = live[i]
    if s and s.name and not s.header then
      map[ns.Fold(s.name)] = {
        name = s.name,
        rank = ns.N(s.rank) or 0,
        max = ns.N(s.max) or 0,
        icon = s.icon or ns.IconForSkillName(s.name, nil, s.headerName, s.skillID),
        index = s.index,
      }
    end
  end
  -- 3.5.3 : la dernière lecture complète sert aussi aux infobulles (cache)
  if not (ns.InCombat and ns.InCombat()) then
    ns._rankSnap, ns._rankSnapAt = map, ns.NowSec()
  end
  return map
end

-- 3.5.3 : lecture pour les infobulles (survol d'unité, d'objet, de case).
-- Avant : chaque Scanner.RankOf relisait TOUTES les lignes de compétence
-- (des dizaines de fois par infobulle → micro-gels). Maintenant : au plus
-- une lecture par seconde, et une relecture dès qu'un événement de
-- compétence / niveau / équipement marque le cache comme périmé.
-- Lecture seule pour l'appelant (table partagée).
ns.RANK_SNAP_TTL = 1
function ns.NowSec()
  if type(GetTime) == "function" then local ok, v = pcall(GetTime) if ok and type(v) == "number" then return v end end
  return 0
end
function ns.SkillRankSnapshotCached()
  local snap, at = ns._rankSnap, ns._rankSnapAt
  if snap and at and (ns.NowSec() - at) < ns.RANK_SNAP_TTL then return snap end
  if snap and ns.InCombat and ns.InCombat() then return snap end   -- valeurs secrètes : on garde la dernière
  return ns.SkillRankSnapshot()
end
function ns.InvalidateRankSnapshot() ns._rankSnapAt = nil end

ns.TOTAL_FORMULA_FR = "Niveau total = niveau du personnage + rangs des 2 métiers principaux + Cuisine + Pêche + Secourisme + les tuiles de combat affichées (Mêlée, 2e tuile de combat, Défense). Mêlée = compétence de l'arme en main principale (emplacement 16) ; si rien n'est équipé, Mains nues ; si le type d'arme est inconnu, meilleure mêlée. 2e tuile selon la classe : Baguettes (Démoniste, Mage, Prêtre), Combat farouche (Druide), arme à distance équipée sinon meilleure compétence à distance connue (Chasseur, Guerrier, Voleur) ; Paladin et Chaman : aucune. Si la compétence n'est pas trouvée, la tuile n'est pas affichée ni comptée. Les caractéristiques sont affichées mais non comptées. La Monte, si elle est apprise, est affichée mais exclue du total (aucun plafond n'est documenté pour Forever). Plafond de comparaison au niveau 60 avec 3 tuiles de combat : 60 + 2×300 + 3×300 + 3×300 = 2460."

ns.WEAPON_TOTAL_RULE_FR = "Tuiles de combat : Mêlée (arme en main, sinon mains nues), une 2e tuile selon la classe (Baguettes, Combat farouche ou arme à distance — absente pour Paladin et Chaman ou si la compétence est introuvable), et Défense."

ns.MONTE_NOTE_FR = "La Monte est affichée si elle est apprise, mais elle n'entre pas dans le total : aucun plafond n'est documenté pour Forever."

-- Interprétation d'une entrée C_SkillInfo.GetSkillLineInfo (table) OU des retours multiples (si l'ancienne API globale existe).
function ns.NormalizeSkillInfo(a, b, c, d, e, f, g, h)
  if type(a) == "table" then
    local t = a
    local name = t.name or t.skillName or t.Name
    if type(name) ~= "string" or name == "" then return nil end
    return {
      name = name,
      header = (t.isHeader == true or t.isHeader == 1 or t.header == true or t.header == 1),
      isCollapsed = (t.isCollapsed == true or t.isCollapsed == 1),
      rank = ns.N(t.rank or t.skillRank or t.skillLevel) or 0,
      temp = ns.N(t.tempPoints or t.numTempPoints) or 0,
      modifier = ns.N(t.modifier or t.skillModifier) or 0,
      max = ns.N(t.maxRank or t.skillMaxRank or t.maxSkillLevel) or 0,
      skillID = t.skillID or t.skillLine or t.professionID,
      icon = t.icon or t.iconTexture or t.texture or t.Icon,
      description = (type(t.description) == "string" and t.description) or nil,
      index = t.index,
    }
  end
  if type(a) == "string" and a ~= "" then
    return {
      name = a,
      header = (b == true or b == 1),
      isCollapsed = (c == true or c == 1),
      rank = ns.N(d) or 0,
      temp = ns.N(e) or 0,
      modifier = ns.N(f) or 0,
      max = ns.N(g) or 0,
      description = (type(h) == "string" and not tostring(h):find("Interface", 1, true) and h) or nil,
      icon = (type(h) == "string" and tostring(h):find("Interface", 1, true) and h) or nil,
    }
  end
  return nil
end

-- Source 1 : C_SkillInfo (API Forever, 1.60.1) — à privilégier.
local function CollectFromCSkillInfo()
  local CSI = _G.C_SkillInfo
  if type(CSI) ~= "table" then return nil, "C_SkillInfo absent" end
  local getn = CSI.GetNumSkillLines
  local geti = CSI.GetSkillLineInfo
  if type(getn) ~= "function" or type(geti) ~= "function" then
    return nil, "C_SkillInfo.GetNumSkillLines/GetSkillLineInfo absents"
  end
  -- v2.7.1 : plus de C_SkillInfo.ExpandSkillHeader depuis l'addon : l'appel
  -- déclenche la mise à jour native de la ScrollBox dans notre contexte souillé
  -- (erreur « secret number value » en combat). On lit ce qui est déplié ;
  -- les en-têtes repliés sont signalés dans /drop debug.
  local n = Call(getn) or 0
  local list, header, headerIndex = {}, nil, nil
  ns.collapsedHeaders = {}
  ns.openHeaders = {}
  for i = 1, n do
    local raw = Call(geti, i)
    local info = ns.NormalizeSkillInfo(raw)
    if info then
      info.index = i
      if info.header then
        header, headerIndex = info.name, i
        if info.isCollapsed then ns.collapsedHeaders[#ns.collapsedHeaders + 1] = tostring(info.name)
        else ns.openHeaders[tostring(info.name)] = true end
      else
        info.headerName = header
        info.headerIndex = headerIndex
        list[#list + 1] = info
      end
    end
  end
  return list, nil
end

-- Source 2 : GetNumSkillLines / GetSkillLineInfo (absents sur Forever, gardés en repli).
local function CollectFromGlobalSkillLines()
  if type(GetNumSkillLines) ~= "function" or type(GetSkillLineInfo) ~= "function" then
    return nil, "GetNumSkillLines/GetSkillLineInfo absents"
  end
  local n = Call(GetNumSkillLines) or 0
  local list, header = {}, nil
  for i = 1, n do
    local info = ns.NormalizeSkillInfo(Call(GetSkillLineInfo, i))
    if info then
      info.index = i
      if info.header then header = info.name
      else info.headerName = header; list[#list + 1] = info end
    end
  end
  return list, nil
end

-- Source 3 : GetProfessions + GetProfessionInfo (métiers appris seulement).
local function CollectFromGetProfessions()
  if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then
    return nil, "GetProfessions/GetProfessionInfo absents"
  end
  local a, b, c, d, e, f = Call(GetProfessions)
  local idxs, list = { a, b, c, d, e, f }, {}
  for i = 1, #idxs do
    local idx = idxs[i]
    if type(idx) == "number" then
      local name, icon, skillLevel, maxSkillLevel, _, _, skillLine, skillModifier = Call(GetProfessionInfo, idx)
      if type(name) == "string" then
        list[#list + 1] = {
          name = name, rank = ns.N(skillLevel) or 0, max = ns.N(maxSkillLevel) or 0,
          modifier = ns.N(skillModifier) or 0, icon = icon, skillID = skillLine,
          headerName = "Métiers", index = idx,
        }
      end
    end
  end
  if #list == 0 then return list, "GetProfessions : aucun métier appris" end
  return list, nil
end

-- Source 4 : C_TradeSkillUI (lignes de métier, y compris éventuellement non apprises).
local function CollectFromTradeSkillUI()
  local TS = _G.C_TradeSkillUI
  if type(TS) ~= "table" then return nil, "C_TradeSkillUI absent" end
  local getAll = TS.GetAllProfessionTradeSkillLines
  local getInfo = TS.GetProfessionInfoBySkillLineID
  if type(getAll) ~= "function" or type(getInfo) ~= "function" then
    return nil, "C_TradeSkillUI.GetAllProfessionTradeSkillLines/GetProfessionInfoBySkillLineID absents"
  end
  local ids = Call(getAll)
  if type(ids) ~= "table" then return nil, "GetAllProfessionTradeSkillLines n'a rien renvoyé" end
  local list = {}
  for i = 1, #ids do
    local info = Call(getInfo, ids[i])
    if type(info) == "table" then
      local name = info.professionName or info.parentProfessionName or info.name
      if type(name) == "string" then
        list[#list + 1] = {
          name = name,
          rank = ns.N(info.skillLevel) or 0,
          max = ns.N(info.maxSkillLevel) or 0,
          modifier = ns.N(info.skillModifier) or 0,
          skillID = info.professionID or ids[i],
          headerName = "Métiers",
        }
      end
    end
  end
  return list, nil
end

-- Source 5 : UnitDefense / UnitDefenseSkill / UnitAttackBothHands / UnitRangedAttack (équipé seulement).
local function CollectFromUnitCombat()
  local list, any = {}, false
  if type(UnitDefenseSkill) == "function" then
    local rank, maxr = Call(UnitDefenseSkill, "player")
    rank = ns.N(rank)
    if rank then
      list[#list + 1] = { name = "Défense", rank = rank, max = ns.N(maxr) or 0, headerName = "Défense" }
      any = true
    end
  elseif type(UnitDefense) == "function" then
    local base, modifier = Call(UnitDefense, "player")
    base = ns.N(base)
    if base then
      list[#list + 1] = { name = "Défense", rank = base, max = 0, modifier = ns.N(modifier) or 0, headerName = "Défense" }
      any = true
    end
  end
  -- Ces APIs donnent le skill de l'arme équipée, pas le nom de la compétence : on les annote seulement.
  if type(UnitAttackBothHands) == "function" then
    local mainBase, mainMod = Call(UnitAttackBothHands, "player")
    mainBase = ns.N(mainBase)
    if mainBase then
      list[#list + 1] = { name = "Arme en main (équipée)", rank = mainBase, max = 0, modifier = ns.N(mainMod) or 0, headerName = "Armes", equippedOnly = true }
      any = true
    end
  end
  if type(UnitRangedAttack) == "function" then
    local rangedBase, rangedMod = Call(UnitRangedAttack, "player")
    rangedBase = ns.N(rangedBase)
    if rangedBase then
      list[#list + 1] = { name = "Arme à distance (équipée)", rank = rangedBase, max = 0, modifier = ns.N(rangedMod) or 0, headerName = "Armes", equippedOnly = true }
      any = true
    end
  end
  if not any then return nil, "APIs UnitDefense/UnitAttack* : rien lu" end
  return list, nil
end

-- v2.8.1 : cache de rangs persistant (par personnage). Une compétence absente
-- d'une lecture (en-tête natif replié, liste pas encore remplie) garde son
-- dernier rang connu, marquée « cached » : ni le total ni « aujourd'hui » ne
-- baissent, et sa réapparition au même rang ne déclenche aucun drop. Elle n'est
-- oubliée que si son en-tête est lu DÉPLIÉ sans elle (vraiment désapprise).
function ns.RankCache()
  local c = ns.CharDB()
  c.rankCache = c.rankCache or {}
  return c.rankCache
end

function ns.MergeRankCache(list, source)
  if type(list) ~= "table" then return list end
  local cache = ns.RankCache()
  local now = (type(time) == "function" and time()) or 0
  local present = {}
  for i = 1, #list do
    local s = list[i]
    if s and s.name and not s.header and not s.equippedOnly then
      local k = ns.Fold(s.name)
      present[k] = true
      local r = ns.N(s.rank)
      if r and r > 0 then
        cache[k] = { name = s.name, rank = r, max = ns.N(s.max) or 0, headerName = s.headerName, when = now,
          modifier = ns.N(s.modifier), skillID = s.skillID }
      elseif cache[k] and (ns.N(cache[k].rank) or 0) > 0 then
        -- Lecture illisible (valeur secrète en combat) : on garde le dernier rang,
        -- pour que la grille et le total ne retombent pas à 0.
        local e = cache[k]
        s.rank, s.max = e.rank, ((ns.N(s.max) or 0) > 0 and s.max) or e.max
        if e.modifier ~= nil and (ns.N(s.modifier) or 0) == 0 then s.modifier = e.modifier end
        if e.skillID and not s.skillID then s.skillID = e.skillID end
        s.cached = true
      end
    end
  end
  -- Seule la liste complète des compétences peut prouver une absence.
  if source ~= "C_SkillInfo" and source ~= "GetNumSkillLines" then
    ns.cachedSkills = {}
    return list
  end
  local open = ns.openHeaders or {}
  local cached = {}
  for k, e in pairs(cache) do
    if not present[k] then
      if e.headerName and open[tostring(e.headerName)] then
        cache[k] = nil   -- en-tête déplié, compétence absente : vraiment partie
      else
        list[#list + 1] = { name = e.name, rank = e.rank, max = e.max, headerName = e.headerName,
          modifier = e.modifier, skillID = e.skillID, cached = true }
        cached[#cached + 1] = e.name
      end
    end
  end
  table.sort(cached)
  ns.cachedSkills = cached
  return list
end

function ns.CollectLiveSkills()
  local list, source, reports = ns.CollectLiveSkillsRaw()
  if list and #list > 0 then ns.MergeRankCache(list, source) end
  return list, source, reports
end

function ns.CollectLiveSkillsRaw()
  local reports = {}
  local function try(name, fn)
    local list, err = fn()
    if list then
      reports[#reports + 1] = { source = name, ok = true, count = #list, err = err }
      return list
    else
      reports[#reports + 1] = { source = name, ok = false, count = 0, err = err or "échec" }
      return nil
    end
  end
  -- Cascade : Forever d'abord, puis replis.
  local list = try("C_SkillInfo", CollectFromCSkillInfo)
  if list and #list > 0 then
    return list, "C_SkillInfo", reports
  end
  local globalSL = try("GetNumSkillLines", CollectFromGlobalSkillLines)
  if globalSL and #globalSL > 0 then
    return globalSL, "GetNumSkillLines", reports
  end
  -- Les sources suivantes sont partielles : on les fusionne si besoin.
  local merged, source = {}, "mélange partiel"
  local function merge(more)
    if not more then return end
    for i = 1, #more do
      merged[#merged + 1] = more[i]
    end
  end
  merge(try("GetProfessions", CollectFromGetProfessions))
  merge(try("C_TradeSkillUI", CollectFromTradeSkillUI))
  merge(try("UnitDefense/Attack", CollectFromUnitCombat))
  if #merged > 0 then
    return merged, source, reports
  end
  return {}, nil, reports
end

-- Ordre fixe, une seule grille, sans en-têtes ni armes « hors total » :
-- Niveau, 5 stats, métiers appris (max 2), secondaires appris, Mêlée, Distance/Farouche, Défense.
local DISPLAY_ORDER = {
  -- v2.8.2 : Niveau, Mêlée, 2e combat, Défense, puis Métier 1, Métier 2, Cuisine, Pêche, Secourisme.
  level = 1, stat = 2, melee = 3, ranged = 4, feral = 4, defense = 5, profession = 6, secondary = 7,
}

local function makeTile(entry, rank, apiMax, extra)
  extra = extra or {}
  local id = entry.id or ("skill:" .. (entry.name or "?"))
  local inTotal = entry.countsInTotal and true or false
  -- Monte : affichée si apprise, jamais dans le total (plafond non documenté).
  if id == "riding" or ns.Fold(entry.name or "") == "monte" or ns.Fold(entry.name or "") == "riding" then
    inTotal = false
  end
  local t = {
    key = id,
    id = entry.id,
    name = ns.CatalogDisplayName(entry),   -- 3.5.19 : nom affiché selon la langue
    catName = entry.name,                  -- nom FR du catalogue (clés internes)
    section = entry.section,
    kind = entry.kind,
    capKind = entry.capKind,
    icon = entry.icon or ns.FALLBACK_ICON,
    current = ns.N(rank) or 0,
    apiMax = ns.N(apiMax) or 0,
    inTotal = inTotal,
    horsTotal = false,
    learned = (ns.N(rank) or 0) > 0,
    modifier = extra.modifier,
    temp = extra.temp,
    description = extra.description,
    skillIndex = extra.index,
    skillID = extra.skillID,
    headerName = extra.headerName,
    cached = extra.cached,
    extra = extra.extra and true or false,
    equippedOnly = extra.equippedOnly,
    base = extra.base,
    pos = extra.pos,
    neg = extra.neg,
  }
  return t
end

local function makeCombatTile(label, kind, entry, live, icon)
  local extra = {
    modifier = live and live.modifier,
    temp = live and live.temp,
    description = live and live.description,
    index = live and live.index,
    skillID = live and live.skillID,
    headerName = live and live.headerName,
  }
  local t = makeTile(entry, live and live.rank or 0, live and live.max or 0, extra)
  t.name = label
  -- Même nom de ligne que l'infobulle / le toast (ex. « Mains nues »).
  t.skillName = (live and live.name) or (entry and ns.CatalogDisplayName(entry)) or label
  t.kind = kind
  -- Icône : API de la ligne de compétence, sinon le catalogue (poing pour Mains nues).
  if ns.IconMissing(icon) then icon = nil end
  local liveIcon = live and live.icon
  if ns.IconMissing(liveIcon) then liveIcon = nil end
  local eIcon = entry and not ns.IconMissing(entry.icon) and entry.icon or nil
  t.icon = icon or liveIcon or eIcon or ns.WEAPON_FALLBACK_ICON
  t.inTotal = true
  t.horsTotal = false
  t.learned = (ns.N(t.current) or 0) > 0
  t.combatTile = true
  t._ord = 800
  return t
end

-- v2.8.2 : statistiques de combat du détail (comme l'ancien détail natif des
-- compétences d'arme). Lecture hors combat seulement ; en combat : dernières valeurs.
ns._combatStats = ns._combatStats or nil
local function Num(fn, ...)
  if type(fn) ~= "function" then return nil end
  local r = { pcall(fn, ...) }
  if not r[1] then return nil end
  for i = 2, #r do if ns.IsSecret(r[i]) then r[i] = nil end end
  return r
end
local function V(r, i) return r and ns.N(r[i]) or nil end
function ns.ReadCombatStats()
  if ns.InCombat() then return ns._combatStats, true end
  local st = {}
  local d = Num(_G.UnitDamage, "player")
  local sp = Num(_G.UnitAttackSpeed, "player")
  st.mMin, st.mMax, st.oMin, st.oMax = V(d, 2), V(d, 3), V(d, 4), V(d, 5)
  st.mSpeed, st.oSpeed = V(sp, 2), V(sp, 3)
  local rd = Num(_G.UnitRangedDamage, "player")
  st.rSpeed, st.rMin, st.rMax = V(rd, 2), V(rd, 3), V(rd, 4)
  local ar = Num(_G.UnitArmor, "player")
  st.armor = V(ar, 3)
  st.dodge = V(Num(_G.GetDodgeChance), 2)
  st.parry = V(Num(_G.GetParryChance), 2)
  st.block = V(Num(_G.GetBlockChance), 2)
  ns._combatStats = st
  return st, false
end
-- 3.5.19 : virgule décimale en français seulement
local function Dec(s) if ns.IsFrench and ns.IsFrench() then s = s:gsub("%.", ",") end return s end
local function F1(x) return Dec(string.format("%.1f", x)) end
local function F2(x) return Dec(string.format("%.2f", x)) end
local function DmgLines(out, label, mn, mx, speed)
  if not (mn and mx) or mx <= 0 then return end
  out[#out + 1] = label .. Tr[" : "] .. math.floor(mn + 0.5) .. " – " .. math.floor(mx + 0.5)
  if speed and speed > 0 then
    out[#out + 1] = Tr["Vitesse : "] .. F2(speed) .. Tr[" s   DPS : "] .. F1((mn + mx) / 2 / speed)
  end
end
-- kind : "melee" | "feral" | "ranged" | "defense". Texte vide si rien de lisible.
function ns.CombatStatsText(kind)
  local st, cached = ns.ReadCombatStats()
  if not st then return "" end
  local out = {}
  if kind == "melee" or kind == "feral" then
    DmgLines(out, Tr["Dégâts"], st.mMin, st.mMax, st.mSpeed)
    if st.oSpeed and st.oSpeed > 0 then DmgLines(out, Tr["Main gauche"], st.oMin, st.oMax, st.oSpeed) end
  elseif kind == "ranged" then
    DmgLines(out, Tr["Dégâts"], st.rMin, st.rMax, st.rSpeed)
  elseif kind == "defense" then
    if st.armor then out[#out + 1] = Tr["Armure : "] .. math.floor(st.armor + 0.5) end
    if st.dodge then out[#out + 1] = Tr["Esquive : "] .. F2(st.dodge) .. " %" end
    if st.parry then out[#out + 1] = Tr["Parade : "] .. F2(st.parry) .. " %" end
    if st.block then out[#out + 1] = Tr["Blocage : "] .. F2(st.block) .. " %" end
  end
  if #out == 0 then return "" end
  local head = Tr["|cffffd100Statistiques|r"] .. (cached and Tr[" |cff808080(avant le combat)|r"] or "")
  return head .. "\n" .. table.concat(out, "\n")
end

ns.SECOND_SLOT_BY_CLASS = {
  WARLOCK = "wands", MAGE = "wands", PRIEST = "wands",
  DRUID = "feral",
  HUNTER = "ranged", WARRIOR = "ranged", ROGUE = "ranged",
  -- PALADIN, SHAMAN : aucune compétence d'arme à distance → emplacement masqué.
}
local RANGED_ONLY = { bows = true, guns = true, crossbows = true, thrown = true }
function ns.PlayerClassFile()
  if type(UnitClass) ~= "function" then return nil end
  local ok, _, cls = pcall(UnitClass, "player")
  if ok and type(cls) == "string" and not ns.IsSecret(cls) then return cls end
  return nil
end
local function Rank(live) return live and (ns.N(live.rank) or 0) or 0 end
function ns.ResolveSecondCombat(byName)
  local mode = ns.SECOND_SLOT_BY_CLASS[ns.PlayerClassFile() or ""]
  if not mode then return nil end
  local t
  if mode == "wands" or mode == "feral" then
    local e = ns.CatalogById(mode)
    local live = ns.LiveForEntry(byName, e)
    if e and Rank(live) > 0 then
      t = makeCombatTile(live.name or ns.CatalogDisplayName(e), (mode == "feral") and "feral" or "ranged", e, live, e.icon)
    end
  else
    local req = ns.GetEquippedItemInfo(ns.GetInventorySlot("ranged"))
    local e, live, icon
    if req then
      local id = ns.MapWeaponSubtype(req.subType, req.classID, req.subclassID)
      if id and RANGED_ONLY[id] then
        e = ns.CatalogById(id)
        live = ns.LiveForEntry(byName, e)
        icon = req.texture
      end
    end
    if not (e and Rank(live) > 0) then
      e, live, icon = nil, nil, nil
      local best
      for id in pairs(RANGED_ONLY) do
        local ce = ns.CatalogById(id)
        local cl = ns.LiveForEntry(byName, ce)
        if ce and Rank(cl) > 0 and (not best or Rank(cl) > best) then e, live, best = ce, cl, Rank(cl) end
      end
    end
    if e and live then
      t = makeCombatTile(live.name or ns.CatalogDisplayName(e), "ranged", e, live, icon or e.icon)
      t.equippedTexture = icon
    end
  end
  if t then t._ord = 820 t.secondMode = mode end
  return t
end

-- Résout les 3 tuiles de combat à partir de l'équipement et des compétences live.
function ns.ResolveCombatTiles(byName)
  byName = byName or {}
  local melee, second, defense

  local defE = ns.CatalogById("defense")
  local defLive = ns.LiveForEntry(byName, defE)
  if defE and defLive and (ns.N(defLive.rank) or 0) > 0 then
    defense = makeCombatTile(Tr["Défense"], "defense", defE, defLive, defE.icon)
    defense._ord = 830
  end

  -- Mêlée : slot 16 → sous-type → compétence ; rien d'équipé → mains nues ;
  -- type inconnu → meilleure mêlée (hors Combat farouche).
  local slotMH = ns.GetInventorySlot("mainhand")
  local eq = ns.GetEquippedItemInfo(slotMH)
  local meleeE, meleeLive, meleeIcon
  if eq then
    local id = ns.MapWeaponSubtype(eq.subType, eq.classID, eq.subclassID)
    if id and not RANGED_IDS[id] then
      meleeE = ns.CatalogById(id)
      meleeLive = ns.LiveForEntry(byName, meleeE)
      meleeIcon = eq.texture or (meleeE and meleeE.icon)
    end
    if not meleeE then
      meleeE, meleeLive = ns.BestLearnedMeleeEntry(byName)
      meleeIcon = eq.texture or (meleeE and meleeE.icon)
    end
  else
    meleeE = ns.CatalogById("unarmed")
    meleeLive = ns.LiveForEntry(byName, meleeE)
    meleeIcon = (meleeLive and meleeLive.icon) or (meleeE and meleeE.icon)
  end
  if meleeE and meleeLive and (ns.N(meleeLive.rank) or 0) > 0 then
    melee = makeCombatTile(Tr["Mêlée"], "melee", meleeE, meleeLive, meleeIcon)
    melee._ord = 810
    melee.equippedTexture = meleeIcon
  end

  -- v2.8.2 : 2e tuile selon la classe, libellée du VRAI nom de la compétence lue
  -- (C_SkillInfo). Inconnu / introuvable → rien (la grille se tasse), jamais deviné.
  second = ns.ResolveSecondCombat(byName)
  return melee, second, defense, eq, ns.GetEquippedItemInfo(ns.GetInventorySlot("ranged"))
end

ns.PLACEHOLDER_NOTE = {
  profession = "Emplacement de métier principal libre. Apprends un métier auprès d'un maître de métier, en ville. Rangs suivants chez le maître : Compagnon à 50 points, Expert à 125, Artisan à 200.",
  secondary = "Non appris. Apprends-le auprès de son maître, en ville (apprenti : 75 points au plus).",
  ranged = "Équipe une arme à distance (arc, arbalète, arme à feu, arme de jet) pour suivre cette compétence ; un druide voit ici Combat farouche dès qu'il a des points.",
  melee = "Compétence de mêlée pas encore lue : équipe une arme ou frappe à mains nues.",
  defense = "Défense pas encore lue : elle progresse quand tu es attaqué.",
}
local SECONDARY_SLOTS = { "cooking", "fishing", "firstaid" }
local function Placeholder(kind, id, name, icon, cap, ord)
  return {
    key = "slot:" .. id, id = (kind == "secondary") and id or nil, name = name, kind = kind,
    icon = icon, current = 0, apiMax = cap or 0, inTotal = false, horsTotal = false, learned = false,
    placeholder = true, placeholderNote = Tr[ns.PLACEHOLDER_NOTE[kind]], _ord = ord,
    combatTile = (kind == "melee" or kind == "ranged" or kind == "defense") or nil,
  }
end
ns.PlaceholderTile = Placeholder

function ns.AddPlaceholders(shown, tiles, nProfs, melee, second, defense)
  for i = (nProfs or 0) + 1, 2 do
    shown[#shown + 1] = Placeholder("profession", "prof" .. i, Tr["Métier à choisir"], nil, 75, 700 + i)
  end
  local have = {}
  for _, t in ipairs(shown) do if t.id then have[t.id] = true end end
  for _, id in ipairs(SECONDARY_SLOTS) do
    if not have[id] then
      local e = ns.CatalogById(id)
      local ord = 0
      for i, t in ipairs(tiles or {}) do if t.id == id then ord = t._ord or i end end
      local ph = Placeholder("secondary", id, e and ns.CatalogDisplayName(e) or id, e and e.icon, 75, ord)
      ph.notLearnedTag = Tr["non appris"]
      shown[#shown + 1] = ph
    end
  end
  local lvl = ns.GetPlayerLevel and ns.N(ns.GetPlayerLevel()) or 1
  if not melee then
    local e = ns.CatalogById("unarmed")
    shown[#shown + 1] = Placeholder("melee", "melee", Tr["Mêlée"], e and e.icon, (lvl or 1) * 5, 810)
  end
  -- v2.8.2 : pas d'emplacement libre pour la 2e tuile de combat (classe sans
  -- arme à distance / compétence introuvable) : la grille se tasse.
  if not defense then
    local e = ns.CatalogById("defense")
    shown[#shown + 1] = Placeholder("defense", "defense", Tr["Défense"], e and e.icon, (lvl or 1) * 5, 830)
  end
end

function ns.SortDisplayTiles(tiles)
  table.sort(tiles, function(a, b)
    local oa = DISPLAY_ORDER[a.kind] or 50
    local ob = DISPLAY_ORDER[b.kind] or 50
    if oa ~= ob then return oa < ob end
    return (a._ord or 0) < (b._ord or 0)
  end)
end

function ns.ComputeTotals(tiles)
  local total, realSum, counted = 0, 0, 0
  local breakdown = {}
  for i = 1, #tiles do
    local t = tiles[i]
    if t.kind ~= "stat" then
      realSum = realSum + (ns.N(t.current) or 0)
    end
    if t.inTotal then
      local v = ns.N(t.current) or 0
      total = total + v
      counted = counted + 1
      local label = t.name
      if t.combatTile and t.kind == "melee" then
        label = Tr["Mêlée ("] .. (t.skillName or t.name) .. ")"
      elseif t.kind == "feral" or (t.combatTile and t.kind == "ranged") then
        label = t.name
      elseif t.kind == "level" then
        label = Tr["Niveau"]
      end
      breakdown[#breakdown + 1] = { name = label, value = v, kind = t.kind, id = t.id, skill = t.skillName or t.name, skillKey = t.catName or t.skillName or t.name, cached = t.cached }
    end
  end
  return total, ns.TOTAL_MAX, breakdown, realSum, counted
end

-- 3.5.1 : trois sources du total, dans l'ordre natif (Niveau, combat, métiers).
ns.TOTAL_SEGMENT_DEFS = {
  { key = "level",       label = "Niveau",            kinds = { level = true } },
  { key = "combat",      label = "Armes et Défense",  kinds = { melee = true, ranged = true, feral = true, defense = true } },
  { key = "professions", label = "Métiers",           kinds = { profession = true, secondary = true } },
}

function ns.ComputeTotalSegments(tiles)
  local segs = {}
  for i, def in ipairs(ns.TOTAL_SEGMENT_DEFS) do
    segs[i] = { key = def.key, label = Tr[def.label], cur = 0, max = 0 }
  end
  if not tiles then return segs end
  for i = 1, #tiles do
    local t = tiles[i]
    if t.inTotal then
      for s, def in ipairs(ns.TOTAL_SEGMENT_DEFS) do
        if def.kinds[t.kind] then
          segs[s].cur = segs[s].cur + (ns.N(t.current) or 0)
          local cap = ns.N(t.apiMax) or 0
          if t.kind == "level" and cap <= 0 then
            cap = (ns.GetLevelCap and ns.GetLevelCap()) or 60
          end
          segs[s].max = segs[s].max + cap
          break
        end
      end
    end
  end
  return segs
end


-- Déplie les en-têtes puis retrouve l'index C_SkillInfo d'une compétence par nom
-- (à appeler au clic / survol, pas seulement à la collecte).
function ns.ExpandSkillHeaders()
  -- v2.7.1 : désactivé (souillure de la liste native). Voir CollectFromCSkillInfo.
  if true then return false end
  local CSI = _G.C_SkillInfo
  if type(CSI) ~= "table" or type(CSI.ExpandSkillHeader) ~= "function" then return false end
  local getn, geti = CSI.GetNumSkillLines, CSI.GetSkillLineInfo
  if type(getn) ~= "function" or type(geti) ~= "function" then return false end
  local n = Call(getn) or 0
  local i, guard = 1, 0
  while i <= n and guard < 80 do
    guard = guard + 1
    local info = ns.NormalizeSkillInfo(Call(geti, i))
    if info and info.header and info.isCollapsed then
      pcall(CSI.ExpandSkillHeader, i)
      n = Call(getn) or n
    end
    i = i + 1
  end
  return true
end

local function nameMatchesSkill(infoName, wantName)
  local folded = ns.Fold(infoName or "")
  if folded == "" then return false end
  if folded == ns.Fold(wantName or "") then return true end
  local e = ns.LookupCatalog and (ns.LookupCatalog(wantName) or ns.LookupCatalog(infoName))
  if not e then return false end
  if ns.Fold(e.name or "") == folded then return true end
  if e.aliases then
    for i = 1, #e.aliases do
      if ns.Fold(e.aliases[i]) == folded then return true end
    end
  end
  return false
end

function ns.ResolveSkillIndexByName(name)
  if type(name) ~= "string" or name == "" then return nil end
  ns.ExpandSkillHeaders()
  local CSI = _G.C_SkillInfo
  if type(CSI) == "table" and type(CSI.GetNumSkillLines) == "function" and type(CSI.GetSkillLineInfo) == "function" then
    local n = Call(CSI.GetNumSkillLines) or 0
    for i = 1, n do
      local info = ns.NormalizeSkillInfo(Call(CSI.GetSkillLineInfo, i))
      if info and not info.header and nameMatchesSkill(info.name, name) then
        info.index = i
        return i, info
      end
    end
  end
  if type(GetNumSkillLines) == "function" and type(GetSkillLineInfo) == "function" then
    local n = Call(GetNumSkillLines) or 0
    for i = 1, n do
      local info = ns.NormalizeSkillInfo(Call(GetSkillLineInfo, i))
      if info and not info.header and nameMatchesSkill(info.name, name) then
        info.index = i
        return i, info
      end
    end
  end
  return nil
end

function ns.Collect()
  local live, source, reports = ns.CollectLiveSkills()
  ns.lastSource, ns.lastReports = source, reports

  local byName = {}
  for i = 1, #live do
    local s = live[i]
    if s.name then byName[ns.Fold(s.name)] = s end
  end

  local tiles = {}
  local used = {}
  for i = 1, #ns.CATALOG do
    local e = ns.CATALOG[i]
    if e.kind == "level" then
      local lvl = ns.GetPlayerLevel()
      local t = makeTile(e, lvl, ns.GetLevelCap(), {})
      t._ord = i
      t.inTotal = true
      tiles[#tiles + 1] = t
    elseif e.kind == "stat" and not (ns.ShowStats and ns.ShowStats()) then
      -- Caractéristiques non lues du tout sans /drop stats on (valeurs secrètes en combat).
    elseif e.kind == "stat" then
      local st = ns.GetStat(e.statIndex)
      local value = st and st.effective or 0
      local t = makeTile(e, value, nil, { pos = st and st.pos, neg = st and st.neg, base = st and st.base })
      t.current = value
      t.inTotal = false
      t.learned = true
      t._ord = i
      tiles[#tiles + 1] = t
    else
      local liveS = byName[ns.Fold(e.name)]
      if not liveS and e.aliases then
        for j = 1, #e.aliases do
          liveS = byName[ns.Fold(e.aliases[j])]
          if liveS then break end
        end
      end
      local rank, apiMax, extra = 0, 0, {}
      if liveS then
        used[ns.Fold(liveS.name)] = true
        rank = liveS.rank or 0
        apiMax = liveS.max or 0
        extra.modifier = liveS.modifier
        extra.temp = liveS.temp
        extra.description = liveS.description
        extra.index = liveS.index
        extra.skillID = liveS.skillID
        extra.headerName = liveS.headerName
        extra.cached = liveS.cached
      end
      local t = makeTile(e, rank, apiMax, extra)
      t._ord = i
      tiles[#tiles + 1] = t
    end
  end

  -- Extras hors catalogue : on les mémorise mais on ne les affiche plus
  -- (la grille n'accepte que l'ordre fixe : niveau, stats, métiers, secondaires, 3 combats).
  for i = 1, #live do
    local s = live[i]
    if s.name and not used[ns.Fold(s.name)] and not ns.LookupCatalog(s.name) then
      local junk = ns.IsLanguageOrArmorJunk(s.name, s.headerName, s.max)
      if not junk and not s.equippedOnly and (ns.N(s.rank) or 0) > 0 then
        used[ns.Fold(s.name)] = true
      end
    end
  end

  -- Grille : niveau + stats + métiers appris (max 2) + secondaires appris + 3 combats.
  -- Tout rang 0 et tout métier non appris sont masqués. Pas d'armes « hors total », pas de classe.
  local profs, shown = {}, {}
  for i = 1, #tiles do
    local t = tiles[i]
    if t.kind == "level" then
      shown[#shown + 1] = t
    elseif t.kind == "stat" then
      -- Masquées par défaut (déjà sur la fiche) ; /drop stats on pour les réafficher.
      if ns.ShowStats and ns.ShowStats() then shown[#shown + 1] = t end
    elseif t.kind == "profession" then
      if t.learned then profs[#profs + 1] = t end
    elseif t.kind == "secondary" then
      if t.learned then
        if t.id == "riding" or ns.Fold(t.name or "") == "monte" then
          t.inTotal = false
          t.horsTotal = false
          t.excludedMonte = true
        else
          t.inTotal = true
          t.horsTotal = false
        end
        shown[#shown + 1] = t
      end
    end
  end
  table.sort(profs, function(a, b)
    local ra, rb = ns.N(a.current) or 0, ns.N(b.current) or 0
    if ra ~= rb then return ra > rb end
    return (a._ord or 0) < (b._ord or 0)
  end)
  for i = 1, #profs do
    if i <= 2 then
      profs[i].inTotal = true
      profs[i].horsTotal = false
      shown[#shown + 1] = profs[i]
    end
  end

  local melee, second, defense, eqMH, eqR = ns.ResolveCombatTiles(byName)
  if melee then shown[#shown + 1] = melee end
  if second then shown[#shown + 1] = second end
  if defense then shown[#shown + 1] = defense end

  -- v2.8.1 : grille fixe de 9 emplacements sur tous les personnages (Niveau,
  -- Métier 1, Métier 2, Cuisine, Pêche, Secourisme, Mêlée, Distance/Farouche,
  -- Défense). Emplacements manquants grisés, hors total, sélectionnables.
  ns.AddPlaceholders(shown, tiles, #profs, melee, second, defense)

  ns.SortDisplayTiles(shown)
  local total, totalMax, breakdown, realSum, counted = ns.ComputeTotals(shown)
  local segments = ns.ComputeTotalSegments(shown)

  local result = {
    tiles = shown,
    allTiles = tiles,
    bySection = nil,
    total = total,
    totalMax = totalMax,
    breakdown = breakdown,
    segments = segments,
    realSum = realSum,
    counted = counted,
    ficTotal = total,
    ficMax = totalMax,
    realTotal = realSum,
    melee = melee,
    secondCombat = second,
    defense = defense,
    bestMelee = melee,
    bestRanged = (second and second.kind == "ranged") and second or nil,
    equippedMainHand = eqMH,
    equippedRanged = eqR,
    source = source,
    reports = reports,
    playerName = ns.GetPlayerName(),
    level = ns.GetPlayerLevel(),
    levelCap = ns.GetLevelCap(),
    liveCount = #live,
    xp = { ns.GetPlayerXP() },
  }
  if ns.CaptureCharSheet then pcall(ns.CaptureCharSheet, result) end
  return result
end

-- SavedVariables -------------------------------------------------------------
ns.DROP_BG_ALPHA = 0.68
-- 3.3.17 : renommage OSRS_TotalLevel → Dropamine. Les réglages de l'ancien nom
-- (OSRS_TotalLevelDB, encore déclaré dans le .toc) sont COPIÉS une seule fois dans
-- DropamineDB ; l'ancienne table n'est jamais modifiée ni effacée.
ns.OLD_ADDON, ns.OLD_DB = "OSRS_TotalLevel", "OSRS_TotalLevelDB"
local function DeepCopy(v, seen)
  if type(v) ~= "table" then return v end
  seen = seen or {}
  if seen[v] then return seen[v] end
  local c = {}
  seen[v] = c
  for k, x in pairs(v) do c[DeepCopy(k, seen)] = DeepCopy(x, seen) end
  return c
end
function ns.MigrateOldDB()
  local old = rawget(_G, ns.OLD_DB)
  if type(old) ~= "table" or next(old) == nil then return false end
  local cur = rawget(_G, "DropamineDB")
  if type(cur) == "table" and cur._migratedFrom then return false end
  -- DropamineDB déjà rempli par un vrai usage (pas seulement créé à ce chargement) : on n'écrase rien
  if type(cur) == "table" and next(cur) ~= nil and not ns._dbFresh then return false end
  if type(cur) ~= "table" then cur = {} end
  for k in pairs(cur) do cur[k] = nil end          -- même table : les références (ns.db) restent valides
  for k, x in pairs(old) do cur[k] = DeepCopy(x) end
  cur._migratedFrom = ns.OLD_DB
  cur._migratedAt = (type(time) == "function" and time()) or 0
  DropamineDB = cur
  ns._dbFresh = nil
  ns.migratedDB = true
  return true
end
local function initDB()
  if DropamineDB == nil then ns._dbFresh = true end
  ns.MigrateOldDB()
  DropamineDB = DropamineDB or {}
  local db = DropamineDB
  db.ui = db.ui or {}
  if db.ui.osrsView == nil then db.ui.osrsView = true end
  if db.ui.customTabIcon == nil then db.ui.customTabIcon = true end
  if db.ui.dropsEnabled == nil then db.ui.dropsEnabled = true end
  -- v2.8.1 : fond des drops plus opaque (comme le chat) ; l'ancien défaut 0,35 migre.
  if not db.ui.migr281 then
    if db.ui.dropBgAlpha == nil or math.abs((tonumber(db.ui.dropBgAlpha) or 0) - 0.35) < 0.001 then db.ui.dropBgAlpha = ns.DROP_BG_ALPHA end
    db.ui.migr281 = true
  end
  if db.ui.showStats == nil then db.ui.showStats = false end
  if db.ui.paliers == nil then db.ui.paliers = true end
  if db.ui.session == nil then db.ui.session = true end
  if db.ui.rappel == nil then db.ui.rappel = true end
  db.chars = db.chars or {}
  if db.ui.colorMode ~= "vert" and db.ui.colorMode ~= "jaune" and db.ui.colorMode ~= "palier" then
    db.ui.colorMode = "palier"
  end
  ns.db = db
end

-- Extensions (modules Scanner / Options / QoL) : commandes, aide, debug.
ns.SlashExt = ns.SlashExt or {}
ns.HelpExt = ns.HelpExt or {}
ns.DebugExt = ns.DebugExt or {}

function ns.EnsureDB()
  if not ns.db then
    DropamineDB = DropamineDB or {}
    DropamineDB.ui = DropamineDB.ui or {}
    ns.db = DropamineDB
  end
  ns.db.ui = ns.db.ui or {}
  -- 3.4.2 : bouton du micro menu retiré → son ancienne position est oubliée (une fois)
  if ns.db.ui.launcherPos ~= nil then ns.db.ui.launcherPos = nil end
  return ns.db
end

-- « on » / « off » / vide (= bascule). Renvoie la nouvelle valeur.
function ns.ParseOnOff(rest, current)
  rest = (rest or ""):lower()
  if rest == "on" or rest == "1" or rest == "oui" then return true end
  if rest == "off" or rest == "0" or rest == "non" then return false end
  return not current
end

function ns.SetOpt(key, value)
  ns.EnsureDB().ui[key] = value
  if ns.SaveActiveProfile then pcall(ns.SaveActiveProfile) end
  if ns.OnOptionChanged then pcall(ns.OnOptionChanged, key, value) end
  return value
end

-- Options à défaut « off » (ns.Opt suppose « on » par défaut).
function ns.OptOff(name)
  local ui = ns.db and ns.db.ui
  return ui and ui[name] == true or false
end
-- 3.5.0 : interrupteur « Sons ». nil = ouvert (les sons déjà réglés ne se
-- taisent pas). Chaque son reste coupé tant que sa propre case n'est pas cochée.
function ns.SoundOk(name)
  if ns.db and ns.db.ui and ns.db.ui.sounds == false then return false end
  return ns.OptOff(name)
end

-- Rythme mesuré dans la session (pour « ~N min par rang », « 125 dans ~40 min »).
-- Rien n'est stocké hors session ; aucune valeur inventée : il faut au moins
-- deux mesures espacées pour estimer.
ns.Rate = { samples = {} }
function ns.Now()
  local t = (type(GetTime) == "function") and ns.N((pcall(GetTime) and GetTime()) or nil) or nil
  if t then return t end
  return (type(time) == "function" and time()) or 0
end
ns.WEAPON_SKILL_CHANCE_FLOOR = 0.01

-- Chance approx. d'un palier d'arme : (plafond − rang) / plafond, avec un plancher.
function ns.WeaponSkillChance(current, cap)
  current, cap = ns.N(current), ns.N(cap)
  if not current or not cap or cap <= 0 then return nil end
  if current >= cap then return 0 end
  local p = (cap - current) / cap
  local fl = ns.WEAPON_SKILL_CHANCE_FLOOR or 0.01
  if p < fl then p = fl end
  return p
end

-- Somme des 1/p(k) de `from` inclus à `to` exclu (étapes normalisées jusqu'au plafond).
function ns.WeaponSkillExpectedSteps(from, to, cap)
  from, to, cap = ns.N(from), ns.N(to), ns.N(cap)
  if not from or not to or not cap then return nil end
  if to <= from then return 0 end
  local s = 0
  for k = from, to - 1 do
    local p = ns.WeaponSkillChance(k, cap)
    if not p or p <= 0 then return nil end
    s = s + (1 / p)
  end
  return s
end

function ns.Rate.Note(key, value, now, info)
  value = ns.N(value)
  if not key or not value then return end
  if type(now) == "table" and info == nil then
    info, now = now, now.now
  end
  now = now or ns.Now()
  info = (type(info) == "table") and info or nil
  local cap = info and ns.N(info.cap) or nil
  local weapon = info and info.weapon or false
  local s = ns.Rate.samples[key]
  if not s or value < (s.v1 or 0) then
    -- recul (nouveau niveau, réinitialisation) : on repart de ce point
    ns.Rate.samples[key] = { t0 = now, v0 = value, t1 = now, v1 = value, n = 1, cap = cap, weapon = weapon }
    return
  end
  if cap then s.cap = cap end
  if weapon then s.weapon = true end
  if value > s.v1 then s.t1, s.v1, s.n = now, value, s.n + 1 end
end
-- Secondes par unité (rang, point d'XP) ; nil tant que la mesure est insuffisante.
-- Pour les armes, c'est le rythme linéaire brut (les ETA d'arme utilisent AttemptRate).
function ns.Rate.SecondsPerUnit(key)
  local s = ns.Rate.samples[key]
  if not s or s.n < 2 then return nil end
  local dv, dt = s.v1 - s.v0, s.t1 - s.t0
  if dv <= 0 or dt <= 0 then return nil end
  return dt / dv
end
-- Tentatives par seconde, déduites des gains mesurés normalisés par p(rang).
function ns.Rate.AttemptRate(key)
  local s = ns.Rate.samples[key]
  if not s or s.n < 2 or not s.weapon then return nil end
  local cap = s.cap
  if not cap or cap <= 0 then return nil end
  local steps = ns.WeaponSkillExpectedSteps(s.v0, s.v1, cap)
  local dt = s.t1 - s.t0
  if not steps or steps <= 0 or not dt or dt <= 0 then return nil end
  return steps / dt
end
function ns.Rate.ETA(key, current, target, cap)
  current, target = ns.N(current), ns.N(target)
  if not current or not target or target <= current then return nil end
  local s = ns.Rate.samples[key]
  cap = ns.N(cap) or (s and s.cap) or nil
  if s and s.weapon and cap then
    local lam = ns.Rate.AttemptRate(key)
    if not lam or lam <= 0 then return nil end
    local steps = ns.WeaponSkillExpectedSteps(current, target, cap)
    if not steps then return nil end
    return steps / lam
  end
  local spu = ns.Rate.SecondsPerUnit(key)
  if not spu then return nil end
  return spu * (target - current)
end
function ns.FormatDuration(sec)
  sec = ns.N(sec)
  if not sec then return nil end
  if sec < 90 then return Tr["~1 min"] end
  local m = math.floor(sec / 60 + 0.5)
  if m < 90 then return "~" .. m .. Tr[" min"] end
  local h = math.floor(m / 60)
  return string.format(Tr["~%d h %02d"], h, m - h * 60)
end

-- v2.5.0 : options et données par personnage -------------------------------
function ns.Opt(name)
  local ui = ns.db and ns.db.ui
  if not ui then return true end
  return ui[name] ~= false
end

-- 3.8.0 : le royaume peut être vide (chargement) ou secret (instance) : ne jamais
-- créer un second profil « Nom- » à côté de « Nom-Royaume ».
function ns.RealmNow()
  local r = Call(GetRealmName)
  if type(r) ~= "string" or ns.IsSecret(r) then return "" end
  return r
end

function ns.CharKey()
  local n = Call(UnitName, "player")
  local r = ns.RealmNow()
  if type(n) ~= "string" or ns.IsSecret(n) or n == "" then return "?-" .. r end
  if ns._charKey and ns._charKeyName == n then return ns._charKey end
  local chars = ns.db and ns.db.chars
  local plain = n .. "-"
  local full = (r ~= "") and (n .. "-" .. r) or nil
  local best
  if type(chars) == "table" then
    local function upd(k)
      local c = chars[k]
      if type(c) ~= "table" then return nil end
      return (type(c.sheet) == "table" and tonumber(c.sheet.updated)) or 0
    end
    -- candidats : « Nom- », « Nom-Royaume » (royaume connu) ou tout « Nom-… » déjà sauvegardé
    -- (royaume encore inconnu). On garde le plus récent ; égalité : celui avec royaume.
    local bestU = -1
    local function consider(k)
      local u = upd(k)
      if u and (u > bestU or (u == bestU and k ~= plain)) then best, bestU = k, u end
    end
    consider(plain)
    if full then consider(full)
    else
      local pre = #plain
      for k in pairs(chars) do
        if type(k) == "string" and #k > pre and k:sub(1, pre) == plain then consider(k) end
      end
    end
  end
  best = best or full or plain
  if type(chars) == "table" then ns._charKey, ns._charKeyName = best, n end
  return best
end

function ns.CharDB()
  if not ns.db then
    DropamineDB = DropamineDB or {}
    DropamineDB.ui = DropamineDB.ui or {}
    ns.db = DropamineDB
  end
  ns.db.chars = ns.db.chars or {}
  local key = ns.CharKey()
  local c = ns.db.chars[key]
  if not c then c = {} ns.db.chars[key] = c end
  c.goals = c.goals or {}
  c.caps = c.caps or {}
  c.goalsDone = c.goalsDone or {}
  c.session = c.session or {}
  return c
end

-- Instantané du personnage (onglet Progression › Personnages), compte entier
-- (DropamineDB.chars[key].sheet). Mis à jour à la connexion, à chaque Collect,
-- au tick 2 min, et à la déconnexion. Pas de % de complétion.
local function SheetRec(name, rank, maxv, id, kind)
  return {
    name = name or "?",
    rank = ns.N(rank) or 0,
    max = ns.N(maxv) or 0,
    id = id,
    kind = kind,
  }
end

local function ClassifySkill(name, id, kind, header, rank, maxv)
  if not name or name == "" then return nil end
  local e = (id and ns.CatalogById and ns.CatalogById(id)) or (ns.LookupCatalog and ns.LookupCatalog(name))
  kind = kind or (e and e.kind)
  if (ns.IsLanguageOrArmorJunk and ns.IsLanguageOrArmorJunk(name, header, maxv)) then return nil end
  if kind == "stat" or kind == "level" then return nil end
  if kind == "profession" or kind == "secondary" then
    return "profession", SheetRec(name, rank, maxv, id or (e and e.id), kind)
  end
  if kind == "defense" or (e and e.kind == "defense") then
    return "defense", SheetRec(name, rank, maxv, id or (e and e.id), "defense")
  end
  if ns.IsWeaponSkill and ns.IsWeaponSkill(id or (e and e.id), kind, name) then
    return "weapon", SheetRec(name, rank, maxv, id or (e and e.id), kind or (e and e.kind))
  end
  return nil
end

function ns.SkillsForCharSheet(snap)
  local profs, weapons, defense = {}, {}, nil
  local function add(bucket, rec)
    if not rec then return end
    bucket[#bucket + 1] = rec
  end
  local function take(kind, rec)
    if kind == "profession" then add(profs, rec)
    elseif kind == "weapon" then add(weapons, rec)
    elseif kind == "defense" and rec then defense = rec end
  end
  -- 1) Collect() / snapshot de cases (le plus riche : kind déjà résolu)
  local tiles
  if type(snap) == "table" then
    tiles = snap.allTiles or snap.tiles
  end
  if not tiles then
    local ui = ns.UI and ns.UI.snapshot
    tiles = ui and (ui.allTiles or ui.tiles)
  end
  if type(tiles) == "table" then
    for i = 1, #tiles do
      local d = tiles[i]
      if d and not d.placeholder then
        local k, rec = ClassifySkill(
          d.skillName or d.catName or d.name, d.id or d.skillID, d.kind, d.header or d.headerName,
          d.current or d.rank, d.apiMax or d.max)
        take(k, rec)
      end
    end
  end
  -- 2) Compétences live (indépendant de la grille, au login avant le snapshot)
  if #profs == 0 or #weapons == 0 or not defense then
    local live = ns.CollectLiveSkills and select(1, ns.CollectLiveSkills())
    if type(live) == "table" then
      local seenP, seenW = {}, {}
      for i = 1, #profs do seenP[profs[i].name] = true end
      for i = 1, #weapons do seenW[weapons[i].name] = true end
      for i = 1, #live do
        local s = live[i]
        if s and not s.header then
          local k, rec = ClassifySkill(s.name, s.skillID or s.id, s.kind, s.headerName, s.rank, s.max)
          if k == "profession" and rec and not seenP[rec.name] then
            add(profs, rec) seenP[rec.name] = true
          elseif k == "weapon" and rec and not seenW[rec.name] then
            add(weapons, rec) seenW[rec.name] = true
          elseif k == "defense" and rec and not defense then
            defense = rec
          end
        end
      end
    end
  end
  return profs, weapons, defense
end

function ns.CaptureCharSheet(snap)
  local c = ns.CharDB and ns.CharDB()
  if not c then return nil end
  local key = ns.CharKey and ns.CharKey() or "?"
  local name = (ns.GetPlayerName and ns.GetPlayerName()) or Call(UnitName, "player") or "?"
  -- Personnage pas encore connu (écran de chargement) : on ne vide pas la fiche.
  if (not name or name == "?" or name == "") and key:sub(1, 2) == "?-" then
    return c.sheet
  end
  local realm = ns.RealmNow()
  if realm == "" and type(c.sheet) == "table" and type(c.sheet.realm) == "string" then realm = c.sheet.realm end
  local level = (ns.GetPlayerLevel and ns.GetPlayerLevel()) or Call(UnitLevel, "player")
  local xp, xpMax
  if ns.GetPlayerXPSafe then xp, xpMax = ns.GetPlayerXPSafe()
  elseif ns.GetPlayerXP then xp, xpMax = ns.GetPlayerXP() end
  xp, xpMax = ns.N(xp), ns.N(xpMax)
  local gold = ns.N(Call(GetMoney)) or 0
  local className, classFile = Call(UnitClass, "player")
  local profs, weapons, defense = ns.SkillsForCharSheet(snap)
  local prev = c.sheet
  -- 3.8.1 : GetMoney renvoie 0 à la connexion / déconnexion : on garde le dernier or connu
  -- (PLAYER_MONEY l'écrit directement, donc un vrai 0 est quand même enregistré).
  if gold == 0 and type(prev) == "table" and (ns.N(prev.gold) or 0) > 0 then gold = ns.N(prev.gold) end
  -- Liste vide au chargement : conserver la dernière fiche connue.
  if type(prev) == "table" then
    if #profs == 0 and type(prev.professions) == "table" and #prev.professions > 0 then
      profs = prev.professions
    end
    if #weapons == 0 and type(prev.weapons) == "table" and #prev.weapons > 0 then
      weapons = prev.weapons
    end
    if not defense and type(prev.defense) == "table" then defense = prev.defense end
  end
  local playtime = 0
  if c.progress and c.progress.records then playtime = ns.N(c.progress.records.playtime) or 0 end
  if playtime == 0 and ns.Progress and ns.Progress.Records then
    playtime = ns.N(ns.Progress.Records().playtime) or 0
  end
  c.sheet = {
    key = (key:sub(1, 2) ~= "?-") and key or ((name or "?") .. "-" .. realm),
    name = name, realm = realm, class = className, classFile = classFile,
    level = ns.N(level) or 0, xp = xp or 0, xpMax = xpMax or 0,
    gold = gold, professions = profs, weapons = weapons, defense = defense,
    playtime = playtime, updated = (type(time) == "function" and time()) or 0,
  }
  c.level = c.sheet.level
  c.gold = c.sheet.gold
  c.xp, c.xpMax = c.sheet.xp, c.sheet.xpMax
  return c.sheet
end

function ns.AllCharSheets()
  local db = (ns.EnsureDB and ns.EnsureDB()) or ns.db or _G.DropamineDB
  local out = {}
  if not (db and type(db.chars) == "table") then return out end
  for key, c in pairs(db.chars) do
    if type(c) == "table" then
      local s = c.sheet
      if type(s) ~= "table" then
        local name, realm = tostring(key):match("^(.*)%-(.*)$")
        s = {
          key = key, name = name or key, realm = realm or "",
          level = ns.N(c.level) or 0, xp = ns.N(c.xp) or 0, xpMax = ns.N(c.xpMax) or 0,
          gold = ns.N(c.gold) or 0,
          professions = {}, weapons = {}, defense = nil,
          playtime = (c.progress and c.progress.records and ns.N(c.progress.records.playtime)) or 0,
        }
      end
      s.key = s.key or key
      out[#out + 1] = s
    end
  end
  -- 3.8.0 : « Ray- » et « Ray-Royaume » sont le même personnage : on affiche le plus
  -- récent (les données de l'autre restent sauvegardées, simplement masquées).
  do
    local keep, order = {}, {}
    for _, s in ipairs(out) do
      local nm = string.lower(tostring(s.name or s.key or ""))
      local cur = keep[nm]
      if not cur then keep[nm] = s order[#order + 1] = nm
      elseif (tonumber(s.updated) or 0) > (tonumber(cur.updated) or 0)
        or ((tonumber(s.updated) or 0) == (tonumber(cur.updated) or 0) and (s.realm or "") ~= "" and (cur.realm or "") == "") then
        keep[nm] = s
      end
    end
    out = {}
    for _, nm in ipairs(order) do out[#out + 1] = keep[nm] end
  end
  table.sort(out, function(a, b)
    local na, nb = string.lower(tostring(a.name or a.key or "")), string.lower(tostring(b.name or b.key or ""))
    if na == nb then return tostring(a.key or "") < tostring(b.key or "") end
    return na < nb
  end)
  return out
end

-- 3.6.0 : profil d'affichage par personnage --------------------------------
-- DropamineDB.ui reste LA table de réglages (tout le code la lit en direct).
-- Quand un personnage choisit son propre profil, ses valeurs d'affichage
-- (thème, colonnes, taille, opacités, positions…) sont posées dans
-- DropamineDB.ui au chargement ; celles du compte sont gardées de côté dans
-- DropamineDB.uiStash et remises en place à PLAYER_LOGOUT, AVANT l'écriture
-- des SavedVariables. Rien n'est perdu : sans profil perso, rien ne bouge ;
-- à l'activation, le profil perso part des réglages actuels du compte.
ns.DISPLAY_KEYS = { "theme", "cols", "scale", "opacity", "bgAlpha", "fadeDelay", "iconAlpha", "colorMode",
  "showTotal", "locked", "winPos", "notifMode", "dropsPos", "dropDir", "dropStyle", "dropWidth", "dropBgAlpha", "dropDuration",
  "minimapAngle", "seasonal", "smartSort", "expanded" }
local NIL = "\001nil"
local function Pack(v) if v == nil then return NIL end return DeepCopy(v) end
local function Unpack(v) if v == NIL then return nil end return v end
ns.PROFILE_SKIP = { migr281 = true, launcherPos = true, uiStash = true }

-- Clés persistées dans le profil perso : DISPLAY_KEYS + tout réglage déjà dans db.ui.
function ns.ProfileKeys(ui)
  local keys, seen = {}, {}
  for _, k in ipairs(ns.DISPLAY_KEYS) do
    if not seen[k] then seen[k] = true keys[#keys + 1] = k end
  end
  if type(ui) == "table" then
    for k in pairs(ui) do
      if type(k) == "string" and not ns.PROFILE_SKIP[k] and not seen[k] then
        seen[k] = true
        keys[#keys + 1] = k
      end
    end
  end
  return keys
end

function ns.EnsureCharUIProfile(c, ui)
  if type(c) ~= "table" then return nil end
  if type(c.uiProfile) == "table" then return c.uiProfile end
  ui = ui or (ns.db and ns.db.ui) or {}
  local p = {}
  for _, k in ipairs(ns.ProfileKeys(ui)) do
    p[k] = Pack(ui[k])
  end
  c.uiProfile = p
  return p
end

function ns.SeedCharProfiles()
  local db = ns.EnsureDB and ns.EnsureDB() or ns.db
  if not (db and db.chars) then return 0 end
  local n = 0
  for _, c in pairs(db.chars) do
    if type(c) == "table" and c.uiProfile == nil then
      ns.EnsureCharUIProfile(c, db.ui)
      n = n + 1
    end
  end
  return n
end

-- nil (jamais choisi) ou true : profil perso (défaut). false = suivre le compte.
function ns.CharUsesProfile(c)
  if type(c) ~= "table" then return false end
  return c.charUI ~= false
end

function ns.CharProfileOn()
  local c = ns.db and ns.db.chars and ns.db.chars[ns.CharKey()]
  return ns.CharUsesProfile(c)
end

-- Écrit le db.ui courant dans le profil du personnage actif (à chaque réglage, pas seulement à la déconnexion).
function ns.SaveActiveProfile()
  if ns._restoringUI then return false end
  local db = ns.db
  if not (db and db.ui) then return false end
  local key = ns.charProfileActive or ns.CharKey()
  if not key or key:sub(1, 2) == "?-" then return false end
  local c = db.chars and db.chars[key]
  if not ns.CharUsesProfile(c) then return false end
  c.uiProfile = c.uiProfile or {}
  local changed = false
  for _, k in ipairs(ns.ProfileKeys(db.ui)) do
    local v = Pack(db.ui[k])
    if c.uiProfile[k] ~= v then
      -- tables : Pack renvoie une copie ; on n'écrit que si la valeur change vraiment
      if type(v) == "table" or type(c.uiProfile[k]) == "table" then
        c.uiProfile[k] = v
        changed = true
      else
        c.uiProfile[k] = v
        changed = true
      end
    end
  end
  return changed and true or false
end

-- Valeurs du compte mises de côté → remises dans DropamineDB.ui.
function ns.RestoreAccountUI()
  local db = ns.db
  local st = db and db.uiStash
  if type(st) ~= "table" or type(st.values) ~= "table" then return false end
  local ui = db.ui
  local owner = st.owner and db.chars and db.chars[st.owner]
  -- Sauver le profil AVANT le garde _restoringUI (sinon SaveActiveProfile no-op).
  if ns.CharUsesProfile(owner) then
    ns.charProfileActive = st.owner
    pcall(ns.SaveActiveProfile)
  end
  ns._restoringUI = true
  for _, k in ipairs(ns.ProfileKeys(ui)) do
    if st.values[k] ~= nil then ui[k] = Unpack(st.values[k]) end
  end
  -- DISPLAY_KEYS absents du stash : déjà dans st.values via Pack au moment du stash
  for _, k in ipairs(ns.DISPLAY_KEYS) do
    if st.values[k] ~= nil then ui[k] = Unpack(st.values[k]) end
  end
  db.uiStash = nil
  ns.charProfileActive = nil
  ns._restoringUI = nil
  return true
end
-- Profil du personnage posé dans DropamineDB.ui (valeurs du compte gardées).
function ns.ApplyCharProfile()
  local db = ns.db
  if not db or not db.ui then return false end
  -- reste d'une session précédente (déconnexion brutale) : d'abord le compte
  if db.uiStash then ns.RestoreAccountUI() end
  local key = ns.CharKey()
  if key:sub(1, 2) == "?-" then return false end
  db.chars = db.chars or {}
  local c = db.chars[key]
  if type(c) ~= "table" then c = {} db.chars[key] = c end
  -- Réglages existants du compte : défaut de tout personnage encore sans profil.
  ns.EnsureCharUIProfile(c, db.ui)
  if not ns.CharUsesProfile(c) then return false end
  local ui = db.ui
  local values = {}
  for _, k in ipairs(ns.ProfileKeys(ui)) do values[k] = Pack(ui[k]) end
  db.uiStash = { owner = key, values = values }
  for _, k in ipairs(ns.ProfileKeys(c.uiProfile)) do
    local v = c.uiProfile[k]
    if v ~= nil then ui[k] = DeepCopy(Unpack(v)) end
  end
  ns.charProfileActive = key
  return true
end
-- Bascule (option / commande) : true = réglages propres au personnage.
function ns.SetCharProfile(on)
  local c = ns.CharDB()
  on = on and true or false
  local cur = (c.charUI ~= false) and (c.charUI == true or ns.charProfileActive ~= nil or c.uiProfile ~= nil)
  -- comparaison stricte avec l'état demandé : on / off explicite
  if on then
    if c.charUI == true and ns.charProfileActive then return true end
    c.charUI = true
    ns.ApplyCharProfile()
  else
    if c.charUI == false and not ns.charProfileActive then return false end
    ns.RestoreAccountUI()
    c.charUI = false
  end
  if ns.ReapplyDisplay then pcall(ns.ReapplyDisplay) end
  return on
end
-- Réapplique l'affichage après un changement de profil (hors combat).
function ns.ReapplyDisplay()
  if ns.InCombat() then
    ns.AfterCombat("reapply-display", function() ns.ReapplyDisplay() end)
    return false
  end
  local O = ns.Options
  if O and O.Get and O.Set then
    for _, k in ipairs({ "theme", "cols", "scale", "opacity", "bgAlpha", "notifMode" }) do
      pcall(function() O.Set(k, O.Get(k)) end)
    end
  end
  local W = ns.Window
  if W and W.frame and W.PlaceDefault then pcall(W.PlaceDefault, W.frame) end
  if ns.UI and ns.UI.Refresh then pcall(ns.UI.Refresh, ns.UI, true) end
  return true
end

-- Objectifs (clé = clé de tuile : id du catalogue, « level », etc.)
function ns.GetGoal(key)
  if not key then return nil end
  local g = ns.CharDB().goals[key]
  if type(g) == "table" and ns.N(g.rank) then return g end
  return nil
end
function ns.SetGoal(key, name, rank)
  rank = ns.N(rank)
  if not key or not rank or rank <= 0 then return false end
  ns.CharDB().goals[key] = { rank = math.floor(rank), name = name }
  return true
end
function ns.ClearGoal(key)
  local c = ns.CharDB()
  if key == nil then c.goals = {} return true end
  local had = c.goals[key] ~= nil
  c.goals[key] = nil
  return had
end

-- Paliers de métier (75 / 150 / 225 / 300).
ns.PROFESSION_STEPS = { 75, 150, 225, 300 }
function ns.NextGoalStep(d, fromRank)
  if not d then return nil end
  local cur = ns.N(fromRank) or ns.N(d.current) or 0
  if d.kind == "profession" or d.kind == "secondary" then
    for i = 1, #ns.PROFESSION_STEPS do
      if ns.PROFESSION_STEPS[i] > cur then return ns.PROFESSION_STEPS[i] end
    end
    return nil
  end
  if d.kind == "level" then
    local cap = ns.GetLevelCap()
    local nxt = (math.floor(cur / 10) + 1) * 10
    if nxt > cap then nxt = cap end
    if nxt <= cur then return nil end
    return nxt
  end
  local cap = ns.N(d.apiMax) or 0
  if cap <= 0 then cap = (ns.GetPlayerLevel() or 1) * ns.WEAPON_RANK_PER_LEVEL end
  local nxt = (math.floor(cur / 25) + 1) * 25
  if nxt > cap then nxt = cap end
  if nxt <= cur then return nil end
  return nxt
end

-- Gains de session : base posée à la connexion (pas au /reload).
function ns.SessionOnEnterWorld(isLogin, isReload)
  local c = ns.CharDB()
  local s = c.session
  local now = (type(time) == "function" and time()) or 0
  local fresh
  if isLogin == true then
    fresh = true
  elseif isReload == true then
    fresh = false
  else
    -- Client sans arguments : un /reload suit de près le PLAYER_LOGOUT.
    fresh = not (s.lastSeen and now - s.lastSeen >= 0 and now - s.lastSeen < 60 and s.baseline ~= nil)
  end
  if fresh then
    s.baseline = nil
    s.started = now
  end
  s.lastSeen = nil
  ns.sessionFresh = fresh
  return fresh
end
-- Base de session : somme des rangs capturés au départ, si la base
-- n'a jamais été posée (nil ou 0, souvent après une lecture vide).
local function SessionBaselineFromRanks(ranks)
  if type(ranks) ~= "table" then return nil end
  local sum, n = 0, 0
  for _, r in pairs(ranks) do
    local v
    if type(r) == "table" then v = ns.N(r.v) else v = ns.N(r) end
    if v then sum, n = sum + v, n + 1 end
  end
  if n <= 0 or sum <= 0 then return nil end
  return sum
end

function ns.SessionGain(total)
  total = ns.N(total)
  if not total then return nil end
  local s = ns.CharDB().session
  local base = ns.N(s.baseline)
  -- 0 n'est pas une vraie base (lecture partielle ou champ non initialisé).
  if base == nil or base <= 0 then
    local fromRanks = SessionBaselineFromRanks(s.startRanks)
    if fromRanks then
      s.baseline = fromRanks
      base = fromRanks
    elseif total > 0 then
      s.baseline = total
      return 0
    else
      return 0
    end
  end
  local g = total - base
  if g < 0 then g = 0 end   -- v2.8.1 : jamais de baisse due à une lecture partielle
  return g
end

-- v2.8.1 : « aujourd'hui » = base quotidienne persistante par personnage
-- (remise à zéro à minuit, heure locale), par compétence réelle (pas par tuile :
-- changer d'arme ne crée aucun faux gain). Une compétence vue pour la première
-- fois du jour est amorcée en silence. Les rangs viennent de la lecture fusionnée
-- avec le cache : un en-tête replié ne fait ni baisser ni monter le compte.
-- Le +N du bandeau est exactement la somme de la liste.
function ns.TodayKey()
  local fn = (type(date) == "function" and date) or (type(os) == "table" and os.date) or nil
  if not fn then return "?" end
  local ok, v = pcall(fn, "%Y-%m-%d")
  return ok and v or "?"
end

local DAILY_LABEL = { level = "Niveau" }
function ns.DailyGains(snap)
  if not snap or not snap.breakdown or (snap.liveCount or 0) <= 0 then return nil, {} end
  local c = ns.CharDB()
  local day = ns.TodayKey()
  if not c.daily or c.daily.day ~= day then c.daily = { day = day, base = {} } end
  local base = c.daily.base
  local total, list = 0, {}
  for _, b in ipairs(snap.breakdown) do
    local key = (b.kind == "level") and "level" or ns.Fold(tostring(b.skillKey or b.skill or b.name))
    local v = ns.N(b.value) or 0
    if base[key] == nil then base[key] = v end
    local g = v - (ns.N(base[key]) or v)
    if g > 0 then
      total = total + g
      list[#list + 1] = { name = (DAILY_LABEL[b.kind] and Tr[DAILY_LABEL[b.kind]]) or tostring(b.skill or b.name), gain = g, key = key }
    end
  end
  table.sort(list, function(a, b2) if a.gain ~= b2.gain then return a.gain > b2.gain end return a.name < b2.name end)
  return total, list
end

function ns.ShowStats()
  return ns.db and ns.db.ui and ns.db.ui.showStats == true
end

local frame = CreateFrame("Frame")
ns.eventFrame = frame
local handlers = {}
function ns.On(event, fn)
  if not handlers[event] then
    handlers[event] = {}
    local ok = pcall(frame.RegisterEvent, frame, event)
    if not ok then handlers[event] = nil return false end
  end
  handlers[event][#handlers[event] + 1] = fn
  return true
end
-- 3.5.3 : cache des rangs (infobulles) périmé à chaque changement réel
for _, ev in ipairs({ "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL", "PLAYER_LEVEL_UP", "LEARNED_SPELL_IN_TAB",
  "PLAYER_EQUIPMENT_CHANGED", "TRADE_SKILL_UPDATE", "CRAFT_UPDATE" }) do
  ns.On(ev, function() ns.InvalidateRankSnapshot() end)
end
frame:SetScript("OnEvent", function(_, event, ...)
  local list = handlers[event]
  if not list then return end
  for i = 1, #list do
    local ok, err = pcall(list[i], event, ...)
    if not ok and ns.Print then
      ns.Print(Tr["|cffff4040erreur|r ["] .. tostring(event) .. "] " .. tostring(err))
    end
  end
end)

-- 3.6.3 : nom d'objet sans jamais afficher « objet 159 » / « item 159 ».
-- Charge via Item:CreateFromItemID / ContinueOnItemLoad si le client l'a,
-- sinon GetItemInfo + GET_ITEM_INFO_RECEIVED (Forever / classique).
ns._itemNames = ns._itemNames or {}
ns._itemWait = ns._itemWait or {}

local function BareItemIdLabel(s)
  if type(s) ~= "string" then return true end
  s = s:match("^%s*(.-)%s*$") or s
  if s == "" then return true end
  if s:find("^objet%s+%d+$") or s:find("^item%s+%d+$") then return true end
  local pref = Tr["objet "]
  if type(pref) == "string" and pref ~= "" then
    local esc = pref:gsub("(%W)", "%%%1")
    if s:find("^" .. esc .. "%d+$") then return true end
  end
  return false
end
ns.BareItemIdLabel = BareItemIdLabel

function ns.ItemDisplayName(id, fallback)
  id = ns.N(id) or tonumber(id)
  if not id then
    if fallback and not BareItemIdLabel(fallback) then return fallback end
    return nil
  end
  local cached = ns._itemNames[id]
  if type(cached) == "string" and cached ~= "" then return cached end
  local S = ns.Scanner
  local it = S and S.StaticItem and S.StaticItem(id)
  if type(it) == "table" and (it.fr or it.en) then
    local nm = (ns.GameName and ns.GameName(it.en, it.fr)) or it.fr or it.en
    if type(nm) == "string" and nm ~= "" then
      ns._itemNames[id] = nm
      return nm
    end
  end
  local gi = _G.GetItemInfo or (type(_G.C_Item) == "table" and _G.C_Item.GetItemInfo)
  if type(gi) == "function" then
    local ok, nm = pcall(gi, id)
    if ok and type(nm) == "string" and nm ~= "" then
      ns._itemNames[id] = nm
      return nm
    end
  end
  if fallback and not BareItemIdLabel(fallback) then return fallback end
  return nil
end

local function FireItemName(id, name)
  if type(name) == "string" and name ~= "" then ns._itemNames[id] = name end
  name = ns._itemNames[id]
  local wait = ns._itemWait[id]
  ns._itemWait[id] = nil
  if not wait or not name then return name end
  for i = 1, #wait do pcall(wait[i], name, id) end
  return name
end

local function HookItemInfoEvent()
  if ns._itemInfoHooked or not ns.On then return end
  ns._itemInfoHooked = true
  ns.On("GET_ITEM_INFO_RECEIVED", function(_, itemID, success)
    itemID = ns.N(itemID) or tonumber(itemID)
    if not itemID or success == false then return end
    local nm = ns.ItemDisplayName(itemID)
    if nm then FireItemName(itemID, nm) end
  end)
end

local function RequestItemData(id)
  local Item = _G.Item
  if type(Item) == "table" and type(Item.CreateFromItemID) == "function" then
    local ok, obj = pcall(Item.CreateFromItemID, id)
    if not ok then ok, obj = pcall(function() return Item:CreateFromItemID(id) end) end
    if ok and type(obj) == "table" and type(obj.ContinueOnItemLoad) == "function" then
      pcall(obj.ContinueOnItemLoad, obj, function()
        local nm = ns.ItemDisplayName(id)
        if nm then FireItemName(id, nm) end
      end)
    end
  end
  local CI = _G.C_Item
  if type(CI) == "table" and type(CI.RequestLoadItemDataByID) == "function" then
    pcall(CI.RequestLoadItemDataByID, id)
  end
  local gi = _G.GetItemInfo
  if type(gi) == "function" then
    local ok, nm = pcall(gi, id)
    if ok and type(nm) == "string" and nm ~= "" then return nm end
  end
  return nil
end

function ns.WhenItemName(id, cb)
  id = ns.N(id) or tonumber(id)
  if not id then return nil end
  HookItemInfoEvent()
  local nm = ns.ItemDisplayName(id)
  if nm then
    if type(cb) == "function" then pcall(cb, nm, id) end
    return nm
  end
  if type(cb) == "function" then
    local q = ns._itemWait[id]
    if not q then q = {} ns._itemWait[id] = q end
    q[#q + 1] = cb
  end
  return RequestItemData(id) and FireItemName(id, ns.ItemDisplayName(id)) or nil
end

-- 3.6.3 : pause du suivi et des toasts sur un trajet aérien.
local F = {}
ns.Flight = F
F.POLL = 0.5

function F.OptionOn()
  return not (ns.Opt and ns.Opt("pauseFlying") == false)
end

function F.OnTaxi()
  if F._simTaxi then return true end
  if type(_G.UnitOnTaxi) == "function" then
    local ok, v = pcall(_G.UnitOnTaxi, "player")
    if ok and v then return true end
  end
  return false
end

local function CallFn(name, ...)
  local fn = _G[name]
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c, d = pcall(fn, ...)
  if ok then return a, b, c, d end
end

-- Noms pliés (FR + EN) des bateaux, zeppelins et du tram, Forever 1.60 / camelot.
F.TRANSPORT_NAMES = {
  ["deeprun tram"] = true, ["tram des profondeurs"] = true,
  ["the thundercaller"] = true, ["le hurleciel"] = true,
  ["the purple princess"] = true, ["la princesse violette"] = true,
  ["the iron eagle"] = true, ["l'aigle de fer"] = true, ["laigle de fer"] = true,
  ["the maiden's fancy"] = true, ["the maidens fancy"] = true,
  ["la fierte de grom"] = true, ["la fierte de gromm"] = true,
  ["the bravery"] = true, ["la bravoure"] = true,
  ["the lady mehley"] = true, ["lady mehley"] = true,
  ["the moonspray"] = true, ["l'ecumelette"] = true, ["lecumelette"] = true,
  ["feathermoon ferry"] = true, ["ferry de plumelune"] = true, ["bac de plumelune"] = true,
  ["the maiden's virtue"] = true, ["the maidens virtue"] = true,
  ["the maiden's folly"] = true, ["the maidens folly"] = true,
  ["zeppelin tower"] = true, ["tour du zeppelin"] = true, ["tour des zeppelins"] = true,
  ["orgrimmar zeppelin"] = true, ["zeppelin d orgrimmar"] = true,
  ["tirisfal zeppelin"] = true, ["grom'gol"] = true, ["gromgol"] = true,
}
-- mots qui, seuls comme nom de zone / sous-zone / minimap, suffisent
F.TRANSPORT_WORDS = { "zeppelin", "zepplin", "zeplin", "deeprun" }

-- 3.7.1 : listes constantes (aucune table créée à chaque sondage).
local TRANSPORT_ZONE_FNS = { "GetMinimapZoneText", "GetSubZoneText", "GetRealZoneText", "GetZoneText" }
function F.ZoneLooksTransport()
  for i = 1, #TRANSPORT_ZONE_FNS do
    local raw = (CallFn(TRANSPORT_ZONE_FNS[i]))
    if type(raw) == "string" and raw ~= "" then
      local f = (ns.Fold and ns.Fold(raw)) or raw:lower()
      if F.TRANSPORT_NAMES[f] then return true, raw end
      for w in pairs(F.TRANSPORT_WORDS) do
        if f:find(w, 1, true) then return true, raw end
      end
    end
  end
  return false
end

local TRANSPORT_API_NS = { "C_Transport", "C_GameTransport", "C_Unit", "C_Vehicle", "C_Player" }
local TRANSPORT_API_METHODS = { "IsOnTransport", "UnitIsOnTransport", "IsPlayerOnTransport", "GetTransportGUID" }
function F.ApiOnTransport()
  if F._simTransport then return true end
  -- APIs optionnelles, toutes protégées (absentes sur une 1.12 stricte).
  if CallFn("IsOnTransport") then return true end
  if CallFn("IsPlayerOnTransport") then return true end
  if CallFn("UnitIsOnTransport", "player") then return true end
  if CallFn("UnitOnTransport", "player") then return true end
  for ni = 1, #TRANSPORT_API_NS do
    local t = _G[TRANSPORT_API_NS[ni]]
    if type(t) == "table" then
      for mi = 1, #TRANSPORT_API_METHODS do
        local fn = t[TRANSPORT_API_METHODS[mi]]
        if type(fn) == "function" then
          local ok, v = pcall(fn, t, "player")
          if not ok then ok, v = pcall(fn, "player") end
          if not ok then ok, v = pcall(fn) end
          if ok and v then return true end
        end
      end
    end
  end
  -- UnitInVehicle : un transport, pas une monture (IsMounted n'est pas un transport).
  if CallFn("UnitInVehicle", "player") then return true end
  if CallFn("UnitHasVehicleUI", "player") then return true end
  if CallFn("UnitHasVehiclePlayerFrameUI", "player") then return true end
  return false
end

function F.PlayerPos()
  if type(_G.UnitPosition) == "function" then
    local x, y, z = CallFn("UnitPosition", "player")
    if type(x) == "number" and type(y) == "number" then return x, y, z or 0, "unit" end
  end
  if type(_G.C_Map) == "table" and type(_G.C_Map.GetBestMapForUnit) == "function" and type(_G.C_Map.GetPlayerMapPosition) == "function" then
    local ok, map = pcall(_G.C_Map.GetBestMapForUnit, "player")
    if ok and map then
      local ok2, pos = pcall(_G.C_Map.GetPlayerMapPosition, map, "player")
      if ok2 and pos then
        local x = pos.x or (pos.GetXY and select(1, pos:GetXY()))
        local y = pos.y or (pos.GetXY and select(2, pos:GetXY()))
        if type(x) == "number" and type(y) == "number" and (x ~= 0 or y ~= 0) then
          return x, y, 0, "map"
        end
      end
    end
  end
  if type(_G.GetPlayerMapPosition) == "function" then
    local x, y = CallFn("GetPlayerMapPosition", "player")
    if type(x) == "number" and type(y) == "number" and (x ~= 0 or y ~= 0) then
      return x, y, 0, "map2"
    end
  end
  return nil
end

-- 3.7.1 : comparaison partagée (plus de fermeture créée à chaque appel).
local function NumLtZero(v) return v < 0 end
function F.IsSecret(v)
  if v == nil then return false end
  local fn = _G and (_G.issecretvalue or _G.IsSecretValue)
  if type(fn) == "function" then
    local ok, r = pcall(fn, v)
    if ok and r then return true end
  end
  if type(v) == "number" then
    local ok = pcall(NumLtZero, v)
    if not ok then return true end
  end
  return false
end

function F.DriftIsTransport()
  -- Position qui dérive alors que la vitesse unitaire est ~0 (le bateau avance, pas le joueur).
  -- Trois sondages d'affilée, pour ne pas prendre un recul ou un ascenceur pour un trajet.
  local now = (type(GetTime) == "function" and GetTime()) or 0
  local x, y, z, kind = F.PlayerPos()
  local speed = CallFn("GetUnitSpeed", "player") or 0
  -- Forever : en combat, certaines valeurs sont « secrètes » (type number mais toute
  -- comparaison provoque une erreur). Dans ce cas, pas de détection par dérive.
  if F.IsSecret(speed) or F.IsSecret(x) or F.IsSecret(y) then F._drift = nil return false end
  if type(speed) ~= "number" then speed = 0 end
  if not pcall(NumLtZero, speed) then F._drift = nil return false end
  if CallFn("UnitOnTaxi", "player") then F._drift = nil return false end
  if CallFn("IsSwimming") or CallFn("IsFalling") then F._drift = nil return false end
  if not x then F._drift = nil return false end
  local d = F._drift
  if not d then
    F._drift = { x = x, y = y, z = z, t = now, kind = kind, hits = 0, dist = 0 }
    return false
  end
  local dt = now - (d.t or now)
  if dt < 0.4 then return d.hits >= 3 end
  local dx, dy = x - d.x, y - d.y
  local dist = (dx * dx + dy * dy) ^ 0.5
  -- cartes normalisées (0-1) : un bateau bouge typiquement de quelques 0.001 par seconde
  local moved = (kind == "unit" and dist > 3) or (kind ~= "unit" and dist > 0.0008)
  local still = speed < 1.5
  -- marcher sur le pont : la vitesse unitaire est non nulle mais bien inférieure au déplacement de la carte
  if kind == "unit" and speed > 0 and dist > speed * dt * 1.8 + 4 then
    still = true
  end
  d.x, d.y, d.z, d.t, d.kind = x, y, z, now, kind
  if moved and still then
    d.hits = (d.hits or 0) + 1
    d.dist = (d.dist or 0) + dist
  else
    d.hits = 0
    d.dist = 0
  end
  return d.hits >= 3
end

-- 3.7.1 : F.Paused() est appelé ~5 fois par sondage (Sync, Pulse, Slot,
-- barres de nom…). Dans une même image (même GetTime), le monde n'a pas
-- changé : on réutilise le résultat au lieu de relancer API + zones + dérive.
function F.OnTransportRaw()
  if F.ApiOnTransport() then return true end
  if F.ZoneLooksTransport() then return true end
  if F.DriftIsTransport() then return true end
  return false
end
function F.OnTransport()
  if F._simTransport then return true end
  local now = (type(GetTime) == "function" and GetTime()) or nil
  if now and F._otAt == now then return F._otVal end
  local v = F.OnTransportRaw()
  F._otAt, F._otVal = now, v
  return v
end

function F.SafetyPause()
  return (F._loading or F._cinematic or F._simLoading or F._simCinematic) and true or false
end

function F.TravelPause()
  if F._simTaxi or F._simTransport then return true end
  if not F.OptionOn() then return false end
  return (F.OnTaxi() or F.OnTransport()) and true or false
end

function F.ShowHourglass()
  if F.SafetyPause() then return false end
  return F.TravelPause() and true or false
end

function F.Paused()
  if F._simTaxi or F._simTransport or F._simLoading or F._simCinematic then return true end
  return (F.SafetyPause() or F.TravelPause()) and true or false
end

function F.SetLoading(on, why)
  on = on and true or false
  F._loading = on
  F.Sync(why or (on and "loading-on" or "loading-off"))
end

function F.SetCinematic(on, why)
  on = on and true or false
  F._cinematic = on
  F.Sync(why or (on and "cinematic-on" or "cinematic-off"))
end
function ns.PausedForFlight()
  return F.Paused()
end

local function wipeList(t)
  if type(t) ~= "table" then return end
  for k in pairs(t) do t[k] = nil end
end

function F.HideActiveToasts()
  local ui = ns.UI
  if not (ui and ui.dropsActive) then return end
  for i = 1, #ui.dropsActive do
    local f = ui.dropsActive[i]
    if f then
      if f.Hide then pcall(f.Hide, f) end
      if f.SetScript then pcall(f.SetScript, f, "OnUpdate", nil) end
    end
  end
  ui.dropsActive = {}
  if ui.PackDrops then pcall(ui.PackDrops, ui) end
end

function F.ResetHints()
  local ch = ns.CharDB and ns.CharDB()
  if ch then ch.flightPauseHint = nil end
end

-- Premier trajet aérien de ce personnage : un toast explicatif (force = true,
-- seule exception à « pas de toast en vol »). Une fois par personnage.
function F.MaybeShowHint(force)
  -- astuce premier vol : seulement un vrai trajet aérien, pas un bateau ni un chargement
  if F._simTransport then return nil end
  if F.OnTransport and F.OnTransport() and not F._simTaxi then return nil end
  if not F.OnTaxi() or F.SafetyPause() then return nil end
  if not F.Paused() then return nil end
  local ch = ns.CharDB and ns.CharDB()
  if not ch then return nil end
  if not force and ch.flightPauseHint then return nil end
  local ui = ns.UI
  if not (ui and ui.SpawnDrop) then return nil end
  local icon = "Interface\\AddOns\\Dropamine\\Media\\Hourglass"
  local ok, f = pcall(ui.SpawnDrop, ui, icon,
    Tr["Suivi en pause pendant le vol."],
    Tr["Le scan reprend dès l'atterrissage."],
    nil, nil, nil,
    { force = true, kind = "flight-hint", dedupeKey = "flight-hint" })
  if ok and f then
    if not force then ch.flightPauseHint = true end
    return f
  end
  return nil
end

function F.OnBegin()
  F._silentLand = false
  -- Sablier d'abord : un échec du toast d'astuce ne doit jamais bloquer l'animation.
  -- Pas de sablier pendant un écran de chargement ou une cinématique (invisible).
  if F.ShowHourglass and F.ShowHourglass() and F.BeginVisual then pcall(F.BeginVisual) end
  pcall(F.HideActiveToasts)
  if ns.Scanner and ns.Scanner.HideAll then pcall(ns.Scanner.HideAll) end
  if ns.Gather then
    if ns.Gather.queue then
      for i = #ns.Gather.queue, 1, -1 do ns.Gather.queue[i] = nil end
    end
    wipeList(ns.Gather.queued)
    if ns.Gather.HideAll then pcall(ns.Gather.HideAll) end
  end
  if ns.PvP and ns.PvP.HideAll then pcall(ns.PvP.HideAll)
  elseif ns.PvP and ns.PvP.Release then
    -- certains modules n'ont que Release / active
    local active = ns.PvP.active
    if type(active) == "table" then
      for unit in pairs(active) do pcall(ns.PvP.Release, unit) end
    end
  end
  if ns.Target and ns.Target.Clear then pcall(ns.Target.Clear) end
  pcall(F.MaybeShowHint)
end

function F.OnEnd()
  -- Aucune file de toasts : premier balayage d'atterrissage sans toast.
  F._silentLand = true
  if ns.Scanner and ns.Scanner.RescanPlates then pcall(ns.Scanner.RescanPlates) end
  if ns.Gather and ns.Gather.Rescan then pcall(ns.Gather.Rescan) end
  if ns.PvP and ns.PvP.Rescan then pcall(ns.PvP.Rescan)
  elseif ns.PvP and ns.PvP.Evaluate and type(_G.C_NamePlate) == "table" and type(_G.C_NamePlate.GetNamePlates) == "function" then
    local ok, plates = pcall(_G.C_NamePlate.GetNamePlates)
    if ok then
      for _, p in ipairs(plates or {}) do
        local unit = p.namePlateUnitToken or (p.UnitFrame and p.UnitFrame.unit)
        if unit then pcall(ns.PvP.Evaluate, unit) end
      end
    end
  end
  if ns.Target and ns.Target.Refresh then pcall(ns.Target.Refresh, "atterrissage") end
  F._silentLand = false
end

function F.SetTaxi(on, why)
  on = on and true or false
  -- premier appel (login) : pas de « atterrissage » fictif
  if F._taxi == nil then
    F._taxi = on
    F._why = why
    if on then F.OnBegin() end
    return F._taxi
  end
  if F._taxi == on then return F._taxi end
  F._taxi = on
  F._why = why
  if on then F.OnBegin() else F.OnEnd() end
  return F._taxi
end

function F.Sync(why)
  -- 3.7.1 : un événement (zone, contrôle, chargement…) relit l'état du monde.
  if why ~= "poll" then F._otAt = nil end
  -- Une simulation /drop test ne doit pas être annulée par le sondage.
  if F._simTaxi or F._simTransport or F._simLoading or F._simCinematic then
    F.SetTaxi(true, why or "sim")
    F.EnsurePoll()
    if F.ShowHourglass and F.ShowHourglass() then
      if F.BeginVisual then pcall(F.BeginVisual) end
    elseif F.EndVisual then
      pcall(F.EndVisual)
    end
    return F.Paused()
  end
  local want = F.SafetyPause() or F.TravelPause()
  F.SetTaxi(want, why or "sync")
  -- passage chargement → bateau encore en cours : démarrer le sablier sans OnBegin
  if F._taxi and F.ShowHourglass and F.ShowHourglass() then
    if F.BeginVisual then pcall(F.BeginVisual) end
  elseif F._taxi and F.EndVisual then
    pcall(F.EndVisual)
  end
  -- Le sondage reste toujours actif : à l'envol, UnitOnTaxi n'est souvent
  -- pas encore vrai au moment de PLAYER_CONTROL_LOST.
  F.EnsurePoll()
  return F.Paused()
end

F.RECHECK = { 0.1, 0.5, 1.5 }

function F.ScheduleRecheck(why)
  F._burst = F._burst or {}
  -- UNIT_FLAGS peut se répéter : on plafonne la file
  while #F._burst > 9 do table.remove(F._burst, 1) end
  why = why or "recheck"
  for _, d in ipairs(F.RECHECK) do
    F._burst[#F._burst + 1] = { t = d, why = why .. ":+" .. tostring(d) }
  end
  F.EnsurePoll()
end

function F.EnsurePoll()
  if type(CreateFrame) ~= "function" then return F._pollFrame end
  if F._pollFrame then
    -- Un cadre caché ne reçoit pas OnUpdate : on le garde visible.
    if F._pollFrame.Show then pcall(F._pollFrame.Show, F._pollFrame) end
    if F._pollFrame.SetScript and F._onUpdate then
      pcall(F._pollFrame.SetScript, F._pollFrame, "OnUpdate", F._onUpdate)
    end
    F._pollOn = true
    return F._pollFrame
  end
  local ok, f = pcall(CreateFrame, "Frame", "DropamineFlightPoll")
  if not (ok and f) then return nil end
  F._elapsed = 0
  F._burst = F._burst or {}
  function F._onUpdate(_, dt)
    dt = tonumber(dt) or 0
    local burst = F._burst
    if burst and #burst > 0 then
      local i = 1
      while i <= #burst do
        burst[i].t = (burst[i].t or 0) - dt
        if burst[i].t <= 0 then
          local why = burst[i].why
          table.remove(burst, i)
          F.Sync(why)
        else
          i = i + 1
        end
      end
    end
    F._elapsed = (F._elapsed or 0) + dt
    if F._elapsed < F.POLL then return end
    F._elapsed = 0
    local combat = ns.InCombat and ns.InCombat()
    -- 3.7.1 : plus de collectgarbage("step") toutes les 2 s. Le churn venait
    -- des relectures d'auras / transport (corrigées) ; un pas manuel faisait
    -- travailler le GC de TOUT le client au compte de Dropamine (CPU).
    if not combat and ns.Watchdog and ns.Watchdog.Tick then
      pcall(ns.Watchdog.Tick, dt)
    end
    local flying = (ns.Flight and ns.Flight.Paused and ns.Flight.Paused()) or (ns.PausedForFlight and ns.PausedForFlight())
    if combat and not flying then return end
    F.Sync("poll")
    if ns.Efficiency and ns.Efficiency.Pulse then pcall(ns.Efficiency.Pulse, "poll") end
  end
  if f.SetScript then pcall(f.SetScript, f, "OnUpdate", F._onUpdate) end
  if f.Show then pcall(f.Show, f) end
  F._pollFrame = f
  F._pollOn = true
  return f
end

if ns.On then
  local function onFlightEvent(ev)
    HookItemInfoEvent()
    F.EnsurePoll()
    F.Sync(ev)
  end
  for _, ev in ipairs({
    "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED",
    "PLAYER_ENTERING_WORLD", "PLAYER_LOGIN",
    "TAXIMAP_CLOSED",
  }) do
    ns.On(ev, function(event)
      onFlightEvent(event or ev)
      if ev == "PLAYER_CONTROL_LOST" or ev == "TAXIMAP_CLOSED" then
        F.ScheduleRecheck(event or ev)
      end
    end)
  end
  ns.On("UNIT_FLAGS", function(event, unit)
    if unit ~= "player" then return end
    onFlightEvent("UNIT_FLAGS")
    F.ScheduleRecheck("UNIT_FLAGS")
  end)
  -- Chargement / cinématique : pause silencieuse, sans vider une file au retour.
  -- Les événements peuvent manquer : ns.On protège RegisterEvent.
  local hadLoading = ns.On("LOADING_SCREEN_ENABLED", function()
    F._hasLoadingEvents = true
    F.SetLoading(true, "LOADING_SCREEN_ENABLED")
  end)
  ns.On("LOADING_SCREEN_DISABLED", function()
    F._hasLoadingEvents = true
    F.SetLoading(false, "LOADING_SCREEN_DISABLED")
  end)
  ns.On("CINEMATIC_START", function() F.SetCinematic(true, "CINEMATIC_START") end)
  ns.On("CINEMATIC_STOP", function() F.SetCinematic(false, "CINEMATIC_STOP") end)
  -- PEW : terminer une pause de chargement si l'événement DISABLED n'existe pas.
  -- Ne pas masquer les toasts sur un simple changement de zone sans écran de chargement.
  ns.On("PLAYER_ENTERING_WORLD", function()
    if F._loading and not F._hasLoadingEvents then
      F.SetLoading(false, "PLAYER_ENTERING_WORLD")
    elseif not F._loading and not F._hasLoadingEvents then
      F._silentLand = true
      if ns.Scanner and ns.Scanner.RescanPlates then pcall(ns.Scanner.RescanPlates) end
      F._silentLand = false
    end
    F.Sync("PLAYER_ENTERING_WORLD")
  end)
  for _, ev in ipairs({
    "VEHICLE_UPDATE", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE",
    "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA",
  }) do
    ns.On(ev, function(event, unit)
      if ev:find("UNIT_", 1, true) and unit and unit ~= "player" then return end
      F.Sync(event or ev)
    end)
  end
end

-- Démarrer tout de suite, sans attendre LOGIN (et le cadre est affiché).
F.EnsurePoll()

ns.SlashExt = ns.SlashExt or {}
ns.SlashExt.vol = function(rest)
  local cur = F.OptionOn()
  local v = ns.ParseOnOff(rest, cur)
  ns.SetOpt("pauseFlying", v and true or false)
  F.Sync("slash")
  ns.Print(Tr["pause pendant le vol : "] .. (v and Tr["activée."] or Tr["désactivée."]))
end
ns.CMD_ALIAS = ns.CMD_ALIAS or {}
ns.CMD_ALIAS.flight = "vol"
ns.CMD_ALIAS.fly = "vol"
ns.SlashExt = ns.SlashExt or {}
ns.SlashExt["reset-hints"] = function()
  if F.ResetHints then F.ResetHints() end
  ns.Print(Tr["astuces réinitialisées."])
end

ns.HelpExt = ns.HelpExt or {}
ns.HelpExt[#ns.HelpExt + 1] = "/drop vol on|off : pause du suivi et des toasts sur un trajet aérien"
ns.HelpExt[#ns.HelpExt + 1] = "/drop reset-hints : réafficher les astuces (sablier en vol, …)"


-- Simulations DEV (Options › Test, /drop test). Retiré avant la version publique.
do
  local T = {}
  ns.Test = T
  T.STATES = {
    { id = "flight",   label = "Vol",                tip = "Démarre ou arrête la pause en vol (sablier + toast d'astuce)." },
    { id = "death",    label = "Mort",               tip = "Simule la mort : crâne dans la goutte, barre vidée et grisée." },
    { id = "afk",      label = "AFK",                tip = "Simule l'absence : horloge de bronze dans le puits." },
    { id = "fishing",  label = "Pêche",              tip = "Simule la pêche : l'icône de jeu (pêche) remplace la goutte et tangue doucement, comme le sablier. /drop test fishing." },
    { id = "swimming", label = "Nage",               tip = "Simule la nage : bulles dans le puits." },
    { id = "rested",   label = "Repos",              tip = "Simule le repos en auberge : « z » dans le puits de la goutte, dans tous les modes (barre et grilles 1/2/3/5 col.). En barre, les z quittent le portrait Niveau ; en grille, ils restent aussi sur Niveau." },
    { id = "combat",   label = "Combat",             tip = "Simule le combat : l'icône de jeu (armes) remplace la goutte, avec une animation simple comme le sablier. Le compteur reste lisible. /drop test combat." },
    { id = "trainer",  label = "Maître à proximité", tip = "Simule un maître à proximité : éclat sur les cases de métier." },
    { id = "rankup",   label = "Rang supérieur disponible", tip = "Affiche le toast collant « rang supérieur disponible chez le maître »." },
    { id = "bags",     label = "Sacs pleins",               tip = "Simule les sacs pleins : signal dans la goutte et un toast." },
    { id = "transport",label = "Bateau / zeppelin",         tip = "Simule un trajet en bateau ou zeppelin : sablier et pause, comme en vol." },
    { id = "loading",  label = "Chargement",                tip = "Simule un écran de chargement : pause silencieuse, sans sablier ni file de toasts." },
    { id = "eating",   label = "Repas",                     tip = "Remplace la goutte par un disque (fourchette, tasse, ou les deux). /drop test eating food|drink|both." },
    { id = "totaladd", label = "Ajout au total",            tip = "Un point s'ajoute au total : la goutte réagit (vague et bulles)." },
    { id = "levelup",  label = "Montée de niveau",          tip = "La goutte déborde, l'anneau bronze pulse, puis se remet avec une vague. Le toast de niveau reste." },
    { id = "dungeon",  label = "Donjon",                    tip = "Simule l'entrée en donjon : le mode calme instance s'active tout seul." },
    { id = "durability", label = "Équipement usé",          tip = "Simule un équipement sous 20 % : signal dans la goutte et un toast." },
    { id = "efficiency", label = "Efficacité",              tip = "Charge un jeu de mesures d'efficacité (temps actif, morts, sacs, spots) pour l'onglet Progression." },
    { id = "recap",      label = "Récap session",           tip = "Ouvre le récap de session avec des données d'exemple. Vérifie aussi chaque disposition : barre, 1, 2, 3 et 5 colonnes." },
  }
  T.ALIASES = {
    vol = "flight", fly = "flight", flight = "flight",
    mort = "death", death = "death",
    afk = "afk",
    peche = "fishing", fishing = "fishing",
    nage = "swimming", swim = "swimming", swimming = "swimming",
    repos = "rested", rested = "rested", rest = "rested",
    maitre = "trainer", trainer = "trainer",
    combat = "combat",
    rankup = "rankup", rang = "rankup", palier = "rankup",
    toast = "toast", drop = "toast",
    bags = "bags", sacs = "bags", sac = "bags",
    transport = "transport", bateau = "transport", boat = "transport", zeppelin = "transport", zep = "transport",
    loading = "loading", chargement = "loading", cinema = "loading", cinematic = "loading",
    eating = "eating", eat = "eating", repas = "eating", boire = "eating", drink = "eating",
    food = "eating", nourriture = "eating",
    totaladd = "totaladd", add = "totaladd", ajout = "totaladd", goutte = "totaladd",
    levelup = "levelup", niveau = "levelup", ding = "levelup",
    dungeon = "dungeon", donjon = "dungeon", instance = "dungeon",
    durability = "durability", durabilite = "durability", usure = "durability",
    efficiency = "efficiency", efficacite = "efficiency", eff = "efficiency",
    recap = "recap", recapitulatif = "recap",
    off = "off", stop = "off", tout = "off",
  }
  T.LONG_NAME = "Palourdes bouillies aux herbes du jardin de Westfall et un nom volontairement trop long pour le défilement"

  function T.Enabled()
    return ns.DEV_TEST == true
  end

  local function Norm(id)
    id = tostring(id or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    return T.ALIASES[id] or id
  end

  function T.IsOn(id)
    id = Norm(id)
    return T._on and T._on[id] and true or false
  end

  function T.Toast()
    if not T.Enabled() then return nil end
    local ui = ns.UI
    if not (ui and ui.SpawnDrop) then return nil end
    local recipe = {
      name = T.LONG_NAME, req = 50, itemID = 5525,
      reagents = {
        { id = 159, name = "Eau de source", count = 1 },
        { id = 2678, name = "Épices douces", count = 1 },
      },
    }
    local icon = "Interface\\Icons\\INV_Misc_Food_15"
    local ok, f = pcall(ui.SpawnDrop, ui, icon,
      T.LONG_NAME, "1 × possible", nil, nil, nil, {
        force = true, kind = "craft",
        toastData = {
          kind = "craft", skill = "cooking", recipe = recipe,
          n = 0, diff = "optimal", item = 5525,
        },
      })
    if ok and f then
      T._toast = f
      ns.Print(Tr["test : toast de recette (nom long)."])
      return f
    end
    return nil
  end

  function T.StartFlight()
    if not T.Enabled() then return nil end
    T._on = T._on or {}
    T._on.flight = true
    F._simTaxi = true
    if F.SetTaxi then pcall(F.SetTaxi, true, "test") end
    if F.MaybeShowHint then pcall(F.MaybeShowHint, true) end
    ns.Print(Tr["test : vol simulé (sablier + toast)."])
    return true
  end

  function T.StopFlight()
    T._on = T._on or {}
    T._on.flight = nil
    F._simTaxi = nil
    if F.SetTaxi then pcall(F.SetTaxi, false, "test-off") end
    if F.Sync then pcall(F.Sync, "test-off") end
    return true
  end

  local function DriveFlask()
    local S = ns.Slot
    local tt = _G.GameTooltip
    if tt and tt.Hide then pcall(tt.Hide, tt) end
    if S then
      S._suppressTip = true
      if S.Refresh then pcall(S.Refresh, "test") end
      if S.StartDriver then pcall(S.StartDriver) end
      if S.Tick then pcall(S.Tick, 0.05) end
      if tt and tt.Hide then pcall(tt.Hide, tt) end
      S._suppressTip = nil
      if tt and tt.Hide then pcall(tt.Hide, tt) end
    end
    local Lyt = ns.Layout
    if Lyt and Lyt.SnapToContent then pcall(Lyt.SnapToContent) end
  end

  function T.StartEating(extra)
    if not T.Enabled() then return nil end
    extra = tostring(extra or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local S = ns.Slot
    local kind = "both"
    if extra == "food" or extra == "nourriture" or extra == "manger" then kind = "food"
    elseif extra == "drink" or extra == "boisson" or extra == "boire" then kind = "drink"
    elseif extra == "both" or extra == "lesdeux" or extra == "all" or extra == "" then kind = "both"
    end
    T._on = T._on or {}
    T._on.eating = true
    if S and S.SetEatSim then pcall(S.SetEatSim, kind) elseif S and S.SetSim then pcall(S.SetSim, "eating", true) end
    DriveFlask()
    ns.Print(string.format(Tr["test : repas (%s)."], kind))
    return true
  end

  function T.StartTotalAdd(extra)
    if not T.Enabled() then return nil end
    extra = tostring(extra or "red"):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if extra == "" or extra == "xp" or extra == "rouge" then extra = "red" end
    if extra == "bleu" or extra == "armes" or extra == "combat" then extra = "blue" end
    if extra == "vert" or extra == "metier" or extra == "métier" or extra == "skill" then extra = "green" end
    T._on = T._on or {}
    T._on.totaladd = true
    if ns.Slot and ns.Slot.PlayBarSpark then pcall(ns.Slot.PlayBarSpark, extra) end
    DriveFlask()
    ns.Print(Tr["test : étincelle de la barre de total."] .. " (" .. extra .. ")")
    return true
  end

  function T.StartLevelUp()
    if not T.Enabled() then return nil end
    T._on = T._on or {}
    T._on.levelup = true
    local ui = ns.UI
    local lvl = (ns.GetPlayerLevel and ns.GetPlayerLevel()) or 2
    if ui and ui.PlayLevelUp then pcall(ui.PlayLevelUp, ui, lvl)
    elseif ns.Slot and ns.Slot.PlayLevelUp then pcall(ns.Slot.PlayLevelUp) end
    DriveFlask()
    ns.Print(Tr["test : montée de niveau (débordement de la goutte)."])
    return true
  end

  function T.Start(id)
    if not T.Enabled() then return nil end
    local raw = tostring(id or "")
    local head, extra = raw:match("^(%S+)%s*(.-)%s*$")
    id = Norm(head)
    extra = extra or ""
    if id == "off" then return T.StopAll() end
    if id == "toast" then return T.Toast() end
    if id == "eating" then return T.StartEating(extra) end
    if id == "totaladd" then return T.StartTotalAdd(extra) end
    if id == "levelup" then return T.StartLevelUp() end
    if id == "flight" then return T.StartFlight() end
    if id == "transport" then return T.StartTransport() end
    if id == "loading" then return T.StartLoading() end
    if id == "dungeon" then return T.StartDungeon() end
    if id == "efficiency" then return T.StartEfficiency() end
    if id == "recap" then return T.StartRecap() end
    local known
    for _, st in ipairs(T.STATES) do if st.id == id then known = st break end end
    if not known then
      ns.Print(Tr["test : état inconnu. Usage : /drop test flight|toast|off"])
      return nil
    end
    T._on = T._on or {}
    T._on[id] = true
    if id == "rankup" then
      if ns.RankToast and ns.RankToast.SetSim then pcall(ns.RankToast.SetSim, true) end
      if ns.RankToast and ns.RankToast.Refresh then pcall(ns.RankToast.Refresh, "test") end
      ns.Print(Tr["test : toast rang supérieur chez le maître."])
      return true
    end
    if ns.Slot and ns.Slot.SetSim then pcall(ns.Slot.SetSim, id, true) end
    if id == "bags" and ns.Slot and ns.Slot.NotifyBags then pcall(ns.Slot.NotifyBags, true) end
    if id == "durability" and ns.Slot and ns.Slot.NotifyDurability then pcall(ns.Slot.NotifyDurability, true) end
    DriveFlask()
    ns.Print(string.format(Tr["test : %s simulé."], Tr[known.label] or known.label))
    return true
  end

  function T.StartTransport()
    if not T.Enabled() then return nil end
    T._on = T._on or {}
    T._on.transport = true
    F._simTransport = true
    if F.SetTaxi then pcall(F.SetTaxi, true, "test-transport") end
    if ns.Slot and ns.Slot.SetSim then pcall(ns.Slot.SetSim, "transport", true) end
    if ns.Slot and ns.Slot.Refresh then pcall(ns.Slot.Refresh, "test") end
    ns.Print(Tr["test : trajet en bateau / zeppelin simulé (sablier + pause)."])
    return true
  end
  function T.StopTransport()
    T._on = T._on or {}
    T._on.transport = nil
    F._simTransport = nil
    if ns.Slot and ns.Slot.SetSim then pcall(ns.Slot.SetSim, "transport", false) end
    if F.SetTaxi then pcall(F.SetTaxi, false, "test-off") end
    if F.Sync then pcall(F.Sync, "test-off") end
    if ns.Slot and ns.Slot.Refresh then pcall(ns.Slot.Refresh, "test-off") end
    return true
  end
  function T.StartLoading()
    if not T.Enabled() then return nil end
    T._on = T._on or {}
    T._on.loading = true
    F._simLoading = true
    if F.SetLoading then pcall(F.SetLoading, true, "test-loading") end
    ns.Print(Tr["test : écran de chargement simulé (pause silencieuse)."])
    return true
  end
  function T.StopLoading()
    T._on = T._on or {}
    T._on.loading = nil
    F._simLoading = nil
    if F.SetLoading then pcall(F.SetLoading, false, "test-off") end
    if F.Sync then pcall(F.Sync, "test-off") end
    return true
  end
  function T.StartDungeon()
    if not T.Enabled() then return nil end
    T._on = T._on or {}
    T._on.dungeon = true
    local P = ns.Progress
    if P then
      P._simInstance = "party"
      if P.AutoQuietSync then pcall(P.AutoQuietSync, true) end
    end
    ns.Print(Tr["test : entrée en donjon simulée (calme auto)."])
    return true
  end
  function T.StopDungeon()
    T._on = T._on or {}
    T._on.dungeon = nil
    local P = ns.Progress
    if P then
      P._simInstance = nil
      if P.AutoQuietSync then pcall(P.AutoQuietSync, true) end
    end
    return true
  end
  function T.StartEfficiency()
    if not T.Enabled() then return nil end
    T._on = T._on or {}
    T._on.efficiency = true
    local E = ns.Efficiency
    if E and E.SetSim then pcall(E.SetSim, true) end
    local PU = ns.ProgressUI
    if PU and PU.SetTab then pcall(PU.SetTab, "efficiency") end
    if PU and PU.RequestRefresh then pcall(PU.RequestRefresh) end
    ns.Print(Tr["test : données d'efficacité de démonstration chargées."])
    return true
  end
  function T.StopEfficiency()
    T._on = T._on or {}
    T._on.efficiency = nil
    if ns.Efficiency and ns.Efficiency.SetSim then pcall(ns.Efficiency.SetSim, false) end
    return true
  end
  function T.StartRecap()
    if not T.Enabled() then return nil end
    T._on = T._on or {}
    T._on.recap = true
    if ns.ProgressUI and ns.ProgressUI.OpenRecap then pcall(ns.ProgressUI.OpenRecap, "demo") end
    ns.Print(Tr["test : récap de session de démonstration ouvert. Vérifie barre, 1, 2, 3 et 5 colonnes pour le liquide, les z et la vague de repas."])
    return true
  end
  function T.StopRecap()
    T._on = T._on or {}
    T._on.recap = nil
    if ns.ProgressUI and ns.ProgressUI.CloseRecap then pcall(ns.ProgressUI.CloseRecap) end
    return true
  end

  function T.Stop(id)
    id = Norm(id)
    if id == "flight" then return T.StopFlight() end
    if id == "transport" then return T.StopTransport() end
    if id == "loading" then return T.StopLoading() end
    if id == "dungeon" then return T.StopDungeon() end
    if id == "efficiency" then return T.StopEfficiency() end
    if id == "recap" then return T.StopRecap() end
    if T._on then T._on[id] = nil end
    if id == "rankup" then
      if ns.RankToast and ns.RankToast.SetSim then pcall(ns.RankToast.SetSim, false) end
      if ns.RankToast and ns.RankToast.Hide then pcall(ns.RankToast.Hide, "test") end
    elseif ns.Slot and ns.Slot.SetSim then
      pcall(ns.Slot.SetSim, id, false)
      if ns.Slot.Refresh then pcall(ns.Slot.Refresh, "test-off") end
    end
    return true
  end

  function T.Toggle(id)
    local raw = tostring(id or "")
    local head, extra = raw:match("^(%S+)%s*(.-)%s*$")
    head = Norm(head)
    extra = extra or ""
    id = head
    if extra == "off" or extra == "stop" then return T.Stop(id) end
    -- Conserver l'argument (totaladd blue, eating food, …).
    if extra ~= "" then return T.Start(raw) end
    if id == "toast" or id == "off" then return T.Start(id) end
    if T.IsOn(id) then return T.Stop(id) end
    return T.Start(id)
  end

  function T.StopAll()
    if T._on and T._on.flight then T.StopFlight() end
    if T._on and T._on.transport then T.StopTransport() end
    if T._on and T._on.loading then T.StopLoading() end
    if T._on and T._on.dungeon then T.StopDungeon() end
    if T._on and T._on.efficiency then T.StopEfficiency() end
    if T._on and T._on.recap then T.StopRecap() end
    if T._on then
      for id in pairs(T._on) do
        if id ~= "flight" and id ~= "transport" and id ~= "loading" and id ~= "dungeon" and id ~= "efficiency" and id ~= "recap" and T.Stop then T.Stop(id) end
      end
    end
    T._on = {}
    F._simTaxi = nil
    F._simTransport = nil
    F._simLoading = nil
    F._simCinematic = nil
    if ns.Slot and ns.Slot.ClearSim then pcall(ns.Slot.ClearSim) end
    if ns.Slot and ns.Slot.Refresh then pcall(ns.Slot.Refresh, "test-off") end
    if ns.RankToast and ns.RankToast.SetSim then pcall(ns.RankToast.SetSim, false) end
    if ns.RankToast and ns.RankToast.Hide then pcall(ns.RankToast.Hide, "test") end
    if T._toast and ns.UI and ns.UI.DismissDrop then pcall(ns.UI.DismissDrop, ns.UI, T._toast) end
    T._toast = nil
    ns.Print(Tr["test : tout arrêté."])
    return true
  end
end

if ns.DEV_TEST then
  ns.SlashExt = ns.SlashExt or {}
  ns.SlashExt.test = function(rest)
    local arg = (rest or ""):match("^%s*(.-)%s*$") or ""
    if arg == "" then
      ns.Print(Tr["/drop test flight|toast|off : simulations (DEV)"])
      return
    end
    if ns.Test and ns.Test.Toggle then ns.Test.Toggle(arg) end
  end
  ns.HelpExt = ns.HelpExt or {}
  ns.HelpExt[#ns.HelpExt + 1] = "/drop test flight|toast|off : simulations (DEV)"
end

ns.DebugExt = ns.DebugExt or {}
ns.DebugExt[#ns.DebugExt + 1] = function()
  return {
    string.format("— Pause en vol (3.6.3) — option %s ; taxi %s ; en pause %s ; dernier %s",
      tostring(F.OptionOn()), tostring(F.OnTaxi()), tostring(F.Paused()), tostring(F._why or "—"))
  }
end


local function requestRefresh()
  if ns.UI and ns.UI.RequestRefresh then ns.UI:RequestRefresh() end
end

ns.On("ADDON_LOADED", function(_, name)
  -- ancien dossier encore actif (chargé APRÈS Dropamine) : import de ses réglages, une fois
  if name == ns.OLD_ADDON and ns.db then
    if ns.MigrateOldDB() then
      initDB()
      if ns.Window and ns.Window.Layout then pcall(ns.Window.Layout) end
      ns.Print(Tr["réglages de l'ancien OSRS_TotalLevel importés. Supprime le dossier Interface\\AddOns\\OSRS_TotalLevel puis /reload."])
    end
    return
  end
  if name ~= ADDON then return end
  initDB()
  pcall(ns.SeedCharProfiles)   -- réglages actuels du compte → défaut de chaque perso
  pcall(ns.ApplyCharProfile)   -- avant toute construction de l'interface
  if ns.migratedDB then ns._announceMigration = true end
  if ns.UI and ns.UI.Init then ns.UI:Init() end
end)
ns.On("PLAYER_LOGIN", function()
  if ns._announceMigration then
    ns._announceMigration = nil
    ns.Print(Tr["réglages de l'ancien OSRS_TotalLevel importés. Tu peux supprimer le dossier Interface\\AddOns\\OSRS_TotalLevel."])
  end
end)
ns.On("PLAYER_LOGIN", function()
  -- nom du personnage inconnu à ADDON_LOADED (rare) : profil posé maintenant
  if not ns.charProfileActive and ns.CharProfileOn() and ns.ApplyCharProfile() then pcall(ns.ReapplyDisplay) end
  requestRefresh()
  if ns.UI and ns.UI.HookSkillFrame then ns.UI:HookSkillFrame() end
end)
ns.On("PLAYER_ENTERING_WORLD", function(_, isLogin, isReload)
  if not ns._sessionChecked then
    ns._sessionChecked = true
    ns.SessionOnEnterWorld(isLogin, isReload)
    if ns.UI and ns.UI.CheckMilestones then pcall(ns.UI.CheckMilestones, ns.UI) end
  end
  requestRefresh()
  if ns.UI and ns.UI.HookSkillFrame then ns.UI:HookSkillFrame() end
  -- Fiche personnage : tout de suite, puis un peu plus tard (compétences prêtes).
  if ns.CaptureCharSheet then
    pcall(ns.CaptureCharSheet)
    local after = (type(_G.C_Timer) == "table" and _G.C_Timer.After) or (ns.After)
    if type(after) == "function" then
      pcall(after, 2, function() if ns.CaptureCharSheet then pcall(ns.CaptureCharSheet) end end)
      pcall(after, 8, function() if ns.CaptureCharSheet then pcall(ns.CaptureCharSheet) end end)
    end
  end
end)
ns.On("PLAYER_LOGOUT", function()
  if ns.CaptureCharSheet then pcall(ns.CaptureCharSheet) end
  local c = ns.CharDB()
  c.session.lastSeen = (type(time) == "function" and time()) or nil
  -- 3.6.0 : réglages du compte remis en place avant l'écriture du fichier
  pcall(ns.RestoreAccountUI)
end)
-- Fin de combat : toasts de compétence éventuellement manqués (rangs secrets)
-- puis mise en page structurelle si elle a été reportée.
ns.On("PLAYER_REGEN_ENABLED", function()
  if ns.Slot and ns.Slot.FlushDeferred then pcall(ns.Slot.FlushDeferred) end
  if ns.UI and ns.UI._skillDiffAfterCombat and ns.UI.OnSkillDiff then ns.UI._skillDiffAfterCombat = false ns.UI:OnSkillDiff() end
  if ns.UI and ns.UI.dirty and ns.UI.Refresh then ns.UI:Refresh() end
end)
ns.On("SKILL_LINES_CHANGED", function()
  if ns.UI and ns.UI.OnSkillDiff then ns.UI:OnSkillDiff() end
  requestRefresh()
end)
ns.On("CHAT_MSG_SKILL", function()
  if ns.UI and ns.UI.OnSkillDiff then ns.UI:OnSkillDiff() end
  requestRefresh()
end)
ns.On("PLAYER_LEVEL_UP", function(_, newLevel)
  if ns.UI and ns.UI.PlayLevelUp then pcall(ns.UI.PlayLevelUp, ns.UI, newLevel) end
  if ns.UI and ns.UI.OnXPUpdate then ns.UI:OnXPUpdate() end
  if ns.UI and ns.UI.CheckMilestones then ns.UI:CheckMilestones() end
  requestRefresh()
  if ns.CaptureCharSheet then pcall(ns.CaptureCharSheet) end
end)
local function TouchCharSheetEconomy()
  local c = ns.CharDB and ns.CharDB()
  if not (c and type(c.sheet) == "table") then
    if ns.CaptureCharSheet then return ns.CaptureCharSheet() end
    return nil
  end
  local gold = ns.N(Call(GetMoney))
  if gold then c.sheet.gold, c.gold = gold, gold end
  local xp, xpMax
  if ns.GetPlayerXPSafe then xp, xpMax = ns.GetPlayerXPSafe()
  elseif ns.GetPlayerXP then xp, xpMax = ns.GetPlayerXP() end
  xp, xpMax = ns.N(xp), ns.N(xpMax)
  if xp then c.sheet.xp, c.xp = xp, xp end
  if xpMax then c.sheet.xpMax, c.xpMax = xpMax, xpMax end
  local level = (ns.GetPlayerLevel and ns.GetPlayerLevel()) or Call(UnitLevel, "player")
  if level then c.sheet.level, c.level = ns.N(level) or c.sheet.level, ns.N(level) or c.level end
  return c.sheet
end
ns.TouchCharSheetEconomy = TouchCharSheetEconomy
ns.On("PLAYER_MONEY", function() pcall(TouchCharSheetEconomy) end)
ns.On("PLAYER_XP_UPDATE", function() pcall(TouchCharSheetEconomy) end)
ns.On("CHARACTER_POINTS_CHANGED", function() requestRefresh() end)
ns.On("UNIT_STATS", function(_, unit)
  if unit and unit ~= "player" then return end
  -- 3.6.0 : UNIT_STATS tombe sans arrêt en combat / raid (amélioration, buff) ;
  -- les caractéristiques ne sont dans la grille que si /drop stats on : sinon
  -- on marque seulement « à refaire » (aucune collecte complète inutile).
  if not ns.ShowStats() then
    if ns.UI then ns.UI.dirty = true end
    return
  end
  requestRefresh()
end)
-- 3.5.0 : TRADE_SKILL_LIST_UPDATE ne reconstruit plus toute la grille.
-- Le métier ouvert passe par ProfJob (un seul passage différé).
ns.On("PLAYER_XP_UPDATE", function()
  if ns.UI and ns.UI.OnXPUpdate then ns.UI:OnXPUpdate() end
  requestRefresh()
end)
ns.On("PLAYER_EQUIPMENT_CHANGED", function() requestRefresh() end)
-- v2.8.2 : statistiques de combat mémorisées hors combat (affichées en combat).
local function readStats() if not ns.InCombat() then pcall(ns.ReadCombatStats) end end
ns.On("PLAYER_EQUIPMENT_CHANGED", readStats)
-- 3.6.0 : le gestionnaire reçoit (événement, unité) : « unit » valait le nom de
-- l'événement, la relecture des statistiques ne se faisait jamais ici.
ns.On("UNIT_INVENTORY_CHANGED", function(_, unit) if unit == "player" then readStats() end end)
ns.On("PLAYER_ENTERING_WORLD", readStats)
ns.On("PLAYER_REGEN_ENABLED", readStats)
ns.On("CHAT_MSG_COMBAT_XP_GAIN", function(_, msg) if ns.UI and ns.UI.NoteXPMessage then pcall(ns.UI.NoteXPMessage, ns.UI, "CHAT_MSG_COMBAT_XP_GAIN", msg) end end)
ns.On("CHAT_MSG_SYSTEM", function(_, msg) if ns.UI and ns.UI.NoteXPMessage then pcall(ns.UI.NoteXPMessage, ns.UI, "CHAT_MSG_SYSTEM", msg) end end)

-- /drop debug -----------------------------------------------------------------
local DEBUG_APIS = {
  "C_SkillInfo",
  "C_SkillInfo.GetNumSkillLines",
  "C_SkillInfo.GetSkillLineInfo",
  "C_SkillInfo.GetSkillLineInfoByID",
  "C_SkillInfo.GetSelectedSkill",
  "C_SkillInfo.SetSelectedSkill",
  "C_SkillInfo.ExpandSkillHeader",
  "C_SkillInfo.CollapseSkillHeader",
  "C_SkillInfo.AbandonSkill",
  "GetNumSkillLines",
  "GetSkillLineInfo",
  "GetProfessions",
  "GetProfessionInfo",
  "C_TradeSkillUI",
  "C_TradeSkillUI.GetAllProfessionTradeSkillLines",
  "C_TradeSkillUI.GetProfessionInfoBySkillLineID",
  "C_TradeSkillUI.GetBaseProfessionInfo",
  "UnitStat",
  "UnitLevel",
  "UnitDefense",
  "UnitDefenseSkill",
  "UnitAttackBothHands",
  "UnitRangedAttack",
  "GetInventoryItemID",
  "GetInventoryItemLink",
  "GetInventoryItemTexture",
  "GetInventorySlotInfo",
  "GetItemInfo",
  "C_Item",
  "INVSLOT_MAINHAND",
  "INVSLOT_RANGED",
  "GetCombatRating",
  "C_PaperDollInfo",
  "C_SpecializationInfo",
  "SkillFrame",
  "SkillListScrollFrame",
  "SkillDetailFrame",
  "SkillDetailStatusBar",
  "SkillDetailName",
  "SkillDetailDescriptionText",
  "ToggleCharacter",
  "MAX_PLAYER_LEVEL",
  "GetMaxLevelForPlayerExpansion",
  "EditModeManagerFrame",
  "C_EditMode",
  "EventRegistry",
  "LibStub",
  "AlertFrame",
  "GroupLootFrame1",
  "LootFrame",
}

local function resolvePath(path)
  local cur = _G
  for part in string.gmatch(path, "[^.]+") do
    if type(cur) ~= "table" then return nil end
    cur = cur[part]
  end
  return cur
end

local function typeOf(v)
  local t = type(v)
  if t == "table" then
    local n = 0
    for _ in pairs(v) do n = n + 1 if n > 30 then break end end
    return "table (" .. n .. (n > 30 and "+" or "") .. " clés)"
  end
  return t
end

function ns.DumpFrameTree(frame, out, prefix, depth)
  out = out or {}
  if not frame or (depth or 0) > 4 then return out end
  local name = (frame.GetName and Call(frame.GetName)) or "?"
  local typ = (frame.GetObjectType and Call(frame.GetObjectType)) or "?"
  local shown = ""
  if frame.IsShown then
    local ok, s = pcall(frame.IsShown, frame)
    if ok then shown = s and " shown" or " hidden" end
  end
  out[#out + 1] = (prefix or "") .. typ .. " " .. tostring(name) .. shown
  if frame.GetChildren then
    local kids = { pcall(frame.GetChildren, frame) }
    if kids[1] then
      for i = 2, #kids do
        ns.DumpFrameTree(kids[i], out, (prefix or "") .. "  ", (depth or 0) + 1)
      end
    end
  end
  return out
end

function ns.DebugReport()
  local lines = {}
  local function add(s) lines[#lines + 1] = s end
  add("Dropamine " .. ns.VERSION .. " — diagnostic APIs Forever")
  add(" ")
  add("— APIs sondées (type(_G[nom])) —")
  for i = 1, #DEBUG_APIS do
    local path = DEBUG_APIS[i]
    local v = resolvePath(path)
    add(string.format("  %s = %s", path, v == nil and "nil" or typeOf(v)))
  end
  add(" ")
  add("— Clés globales contenant 'Skill' —")
  local keys = {}
  if type(_G) == "table" then
    for k, v in pairs(_G) do
      if type(k) == "string" and string.find(string.lower(k), "skill", 1, true) then
        keys[#keys + 1] = k
      end
    end
  end
  table.sort(keys)
  if #keys == 0 then
    add("  (aucune)")
  else
    for i = 1, #keys do
      local v = _G[keys[i]]
      add(string.format("  %s = %s", keys[i], typeOf(v)))
    end
  end
  add(" ")
  add("— Frame de compétences (SkillFrame et candidats) —")
  local candidates = {
    "SkillFrame", "SkillsFrame", "CharacterSkillFrame", "CharacterSkillsFrame",
    "SkillListScrollFrame", "SkillDetailFrame", "SkillListFrame",
  }
  local seen = {}
  for i = 1, #candidates do
    local f = _G[candidates[i]]
    if f and not seen[f] then
      seen[f] = true
      add("Arbre de " .. candidates[i] .. " :")
      local tree = ns.DumpFrameTree(f, {}, "  ", 0)
      for j = 1, #tree do add(tree[j]) end
    elseif f == nil then
      add("  " .. candidates[i] .. " = nil")
    end
  end
  if type(CharacterFrame) == "table" then
    add("Enfants de CharacterFrame dont le nom contient Skill :")
    local kids = { pcall(CharacterFrame.GetChildren, CharacterFrame) }
    local any = false
    if kids[1] then
      for i = 2, #kids do
        local n = kids[i].GetName and Call(kids[i].GetName)
        if type(n) == "string" and string.find(string.lower(n), "skill", 1, true) then
          any = true
          add("  " .. n)
          local tree = ns.DumpFrameTree(kids[i], {}, "    ", 0)
          for j = 1, #tree do add(tree[j]) end
        end
      end
    end
    if not any then add("  (aucun)") end
  end
  add(" ")
  add("— Boutons d'onglet Comp. / CharacterFrame (Skill) —")
  if ns.UI and ns.UI.DebugTabButtons then
    local tabLines = ns.UI:DebugTabButtons()
    if tabLines and #tabLines > 0 then
      for i = 1, #tabLines do add(tabLines[i]) end
    else
      add("  (aucun candidat pour le moment ; ouvre l'onglet Comp. puis relance /drop debug)")
    end
  else
    add("  UI non initialisée")
  end
  add(" ")
  add("— Mise à jour du panneau Comp. natif —")
  if ns.UI and ns.UI.nativeUpdateNames and #ns.UI.nativeUpdateNames > 0 then
    add("  fonctions trouvées : " .. table.concat(ns.UI.nativeUpdateNames, ", "))
  else
    add("  (aucune SkillFrame_*_Update trouvée pour le moment ; le panneau de droite de l'addon prend le relais)")
  end
  add(" ")
  add("— Équipement combat (emplacements 16 / 18) —")
  local okMH, eqMH = pcall(ns.GetEquippedItemInfo, ns, ns.GetInventorySlot("mainhand"))
  local okR, eqR = pcall(ns.GetEquippedItemInfo, ns, ns.GetInventorySlot("ranged"))
  local function describeEq(ok, eq, label)
    if not ok then add("  " .. label .. " : erreur " .. tostring(eq)) return end
    if not eq then add("  " .. label .. " : (vide)") return end
    add(string.format("  %s : id=%s type=%s sous-type=%s class=%s sub=%s tex=%s",
      label, tostring(eq.id), tostring(eq.itemType), tostring(eq.subType),
      tostring(eq.classID), tostring(eq.subclassID), tostring(eq.texture)))
    add("    → compétence : " .. tostring(ns.MapWeaponSubtype(eq.subType, eq.classID, eq.subclassID)))
  end
  describeEq(okMH, eqMH, "Main (16)")
  describeEq(okR, eqR, "Distance (18)")
  add(" ")
  add("— Intégration onglet Comp. —")
  if ns.UI then
    local U = ns.UI
    add("  SkillFrame : " .. tostring(U.skillFrameName or (U.skillFrame and "oui") or "non trouvé"))
    add("  grille accrochée : " .. ((U.embed and "oui") or "NON") .. " ; bouton : " .. ((U.viewToggle and "oui") or "NON"))
    add("  flèche native : " .. tostring(U.collapseArrowName or "non trouvée") .. " ; bouton ancré : " .. tostring(U.toggleAnchor or "—"))
    do
      local names = {}
      local okB, list = pcall(function() return U.NativeSmallButtons and U:NativeSmallButtons() or {} end)
      for _, b in ipairs(okB and list or {}) do
        local n = b.GetName and b:GetName()
        local overl = U.RectsOverlap and U.viewToggle and U.RectsOverlap(U.viewToggle, b, 1)
        names[#names + 1] = tostring(n or "?") .. (overl and " [CHEVAUCHE]" or "")
      end
      add("  petits boutons natifs détectés : " .. (#names > 0 and table.concat(names, ", ") or "aucun") .. (U.toggleHitInfo and (" ; dernier évité : " .. U.toggleHitInfo) or ""))
      local li = U.listInsets
      add("  origine liste : " .. (li and string.format("gauche %s, droite %s, haut %s (%s)", tostring(li.left), tostring(li.right), tostring(li.top), tostring(li.source)) or "—")
        .. " ; OnUpdate actifs : " .. (function() local a = U.ActiveOnUpdates and U:ActiveOnUpdates() or {} return #a == 0 and "aucun" or table.concat(a, ", ") end)()
        .. " ; OnSizeChanged ignorés : " .. tostring(U.sizeEventsSkipped or 0))
      add("  grille (3.2.0) : encadré niveau " .. tostring(U.embedLevel) .. ", tuiles " .. tostring(U.hitLevel) .. ", liste native " .. (U.nativeListHidden and "cachée (Hide)" or "visible") .. ", cadres natifs cachés sur la zone : " .. tostring(U.listAreaHidden or 0) .. ", en-tête " .. tostring(U.headerAsset) .. ", surbrillance " .. tostring(U.hlSource or "repli") .. (U.gridSqueezed and (", rangées tassées " .. U.gridSqueezed) or ""))
      do
        local L = U.embed and U.embed._layout or {}
        local t1 = U.embed and U.embed.tiles and U.embed.tiles[1]
        add("  3.0.1 : pas fixe " .. tostring(L.step) .. " (tout déplié), défilement " .. tostring(U.gridScroll or "—") .. ", bas de liste " .. tostring(U.listBottomSource or "?") .. ", filets " .. tostring(U.listDecorSource or "non relevés") .. ", barre " .. tostring(t1 and t1.barv and (tostring(t1.barv.source) .. " " .. tostring(t1.barv.w) .. "×" .. tostring(t1.barv.h)) or "?") .. ", détail " .. tostring(U.singlePane or "?") .. ", bouton " .. tostring(U.toggleSkin or "?"))
      end
    end
    add("  volet gauche figé : " .. tostring(U.leftPaneW or "?") .. " × " .. tostring(U.leftPaneH or "?") .. " (" .. tostring(U.leftPaneSource or "repli") .. ")")
    add("  vue : " .. ((U.IsOsrsView and U:IsOsrsView()) and "OSRS" or "classique"))
    local nl = U.nativeLeft and U.nativeLeft.GetName and U.nativeLeft:GetName()
    local nd = U.nativeDetail and U.nativeDetail.GetName and U.nativeDetail:GetName()
    add("  liste native : " .. tostring(nl or "—") .. " ; détail natif : " .. tostring(nd or "—"))
    local nb = U.LearnNativeSkillBar and U:LearnNativeSkillBar()
    if nb then
      add("  barre native : " .. tostring(nb.source) .. " ; texture " .. tostring(nb.tex) .. " ; cadre " .. tostring(nb.border and nb.border.tex)
        .. " (+" .. tostring(nb.border and nb.border.dw) .. " px, x " .. tostring(nb.border and nb.border.x) .. ", hauteur " .. tostring(nb.h) .. ")")
    end
    local any = false
    for label, err in pairs(U.errors or {}) do
      any = true
      add("  ERREUR " .. tostring(label) .. " : " .. tostring(err))
    end
    if not any then add("  aucune erreur d'intégration") end
  end
  add("— Objectifs, paliers, session, rappel (v2.5.0) —")
  do
    local c = ns.CharDB()
    add("  options : paliers " .. (ns.Opt("paliers") and "on" or "off") .. ", session " .. (ns.Opt("session") and "on" or "off")
      .. ", rappel " .. (ns.Opt("rappel") and "on" or "off") .. " ; personnage " .. ns.CharKey())
    local n = 0
    for k, g in pairs(c.goals) do n = n + 1 add("  objectif " .. tostring(g.name or k) .. " → " .. tostring(g.rank)) end
    if n == 0 then add("  aucun objectif") end
    local caps = {}
    for k, v in pairs(c.caps) do caps[#caps + 1] = tostring(k) .. "=" .. tostring(v) end
    add("  paliers annoncés : " .. ((#caps > 0) and table.concat(caps, ", ") or "aucun"))
    add("  session : base " .. tostring(c.session.baseline) .. (ns.sessionFresh == false and " (rechargement)" or " (connexion)"))
    add("  combat : " .. ((type(InCombatLockdown) == "function" and InCombatLockdown()) and "oui (valeurs à jour, mise en page reportée)" or "non")
      .. " ; issecretvalue " .. ((type(_G.issecretvalue) == "function") and "présent" or "absent"))
  end
  if ns.UI and ns.UI.DebugDropLines then
    add("— Drops (chrome du chat, barre native) —")
    local dl = ns.UI:DebugDropLines()
    for i = 1, #dl do add(dl[i]) end
  end
  add("— Filets natifs (Inset / Border / NineSlice) —")
  if ns.UI and ns.UI.DebugInsetLines then
    local lines = ns.UI:DebugInsetLines()
    for i = 1, #lines do add(lines[i]) end
  else
    add("  (UI pas encore initialisée)")
  end
  add("— Mode édition / drops —")
  if ns.UI and ns.UI.DebugEditModeLines then
    if ns.UI.ProbeEditMode then ns.UI:ProbeEditMode() end
    local emLines = ns.UI:DebugEditModeLines()
    for i = 1, #emLines do add(emLines[i]) end
  else
    add("  UI non initialisée")
  end
  add(" ")
  add("— Cascade de collecte —")
  local _, source, reports = ns.CollectLiveSkills()
  add("Source retenue : " .. tostring(source or "aucune"))
  if reports then
    for i = 1, #reports do
      local r = reports[i]
      add(string.format("  %s : %s (%s)", r.source, r.ok and ("OK, " .. r.count .. " lignes") or "échec", tostring(r.err or "")))
    end
  end
  add("Rangs en cache (absents de la dernière lecture, total conservé) : " .. ((ns.cachedSkills and #ns.cachedSkills > 0) and table.concat(ns.cachedSkills, ", ") or "aucun"))
  add("En-têtes repliés (non lus, à déplier dans la liste native) : " .. ((ns.collapsedHeaders and #ns.collapsedHeaders > 0) and table.concat(ns.collapsedHeaders, ", ") or "aucun"))
  add("Souillure : aucun appel natif (SetSelectedSkill / ExpandSkillHeader / SkillFrame_Update), widgets natifs masqués par opacité seulement")
  for i = 1, #ns.DebugExt do
    local okE, extra = pcall(ns.DebugExt[i])
    add(" ")
    if okE and type(extra) == "table" then
      for j = 1, #extra do add(extra[j]) end
    else
      add("  (section indisponible : " .. tostring(extra) .. ")")
    end
  end
  return lines
end

function ns.PrintDebug()
  local lines = ns.DebugReport()
  for i = 1, #lines do
    if type(print) == "function" then print(PREFIX .. lines[i]) end
  end
  ns.Print(Tr["Copie ce bloc (ou une capture) et envoie-le moi si une API manque encore."])
end

-- Slash ---------------------------------------------------------------------
-- 3.4.0 : aide courte et rangée ; « /drop help tout » = toutes les commandes.
ns.HELP_SHORT = {
  "|cffffd100Dropamine|r — /drop (ou /dropamine) ou le bouton de minicarte ouvre / ferme le panneau",
  "  Réglages : /drop options · /drop edit (déplacer / redimensionner) · /drop reset · /drop minimap",
  "  Affichage : /drop theme flare|flare2|leger|classic · colonnes 2|3|5|10 · taille 90-200 · total on|off · verrou on|off · vol on|off",
  "  Métiers : /drop alertes on|off · activite on|off · liens on|off · recettes on|off",
  "  Objectifs : clic droit sur une case · /drop objectif <compétence> <rang> · objectif clear",
  "  JcJ : /drop pvp on|off · pvp marques on|off",
  "  Notifications : /drop drops on|off · notif dessus|dessous|detache · recap",
  "  Dopamine : /drop combo · defi · records · barre · collection · sons on|off",
  "  Progression : /drop progression · but <n>|+5|+10|+25 · semaine · succes · spots · share [say|party|guild|raid]",
  "  Chasse et collection : /drop chasse [ajouter|retirer|reset] · collection · rare <objet> · item <id> · mode auto|route|endgame",
  "  Visite et infos : /drop setup (visite guidée) · about (version, liens) · ding (test des animations) · check",
  "  Mode calme : /drop calme off|instance|groupe · profil perso|compte",
  "  Plus : /drop help tout (toutes les commandes) · /drop debug (rapport copiable) · /drop mem · debug metier",
  "  Langue : /drop lang auto|en|fr (auto = langue du jeu)",
}
local function slashHelpAll()
  ns.Print(Tr["/drop : ouvrir ou fermer le panneau (aussi : clic sur le bouton de minicarte)"])
  ns.Print(Tr["/drop reset : remettre le panneau à sa place par défaut"])
  ns.Print(Tr["/drop minimap : afficher ou cacher le bouton de minicarte"])
  ns.Print(Tr["/drop debug : rapport technique dans une fenêtre copiable (Ctrl+C) ; /drop debug metier : seulement le métier en cours"])
  ns.Print(Tr["/drop drops on|off|move : notifications de gain (afficher, cacher, déplacer)"])
  ns.Print(Tr["/drop stats on|off : afficher les 5 caractéristiques dans la grille (désactivé par défaut)"])
  ns.Print(Tr["/drop couleurs palier|vert|jaune : couleur des chiffres"])
  ns.Print(Tr["/drop objectif <compétence> <rang> : fixer un objectif (ou clic droit sur une case, Maj+clic droit = palier suivant)"])
  ns.Print(Tr["/drop objectif clear [compétence] : effacer les objectifs ; /drop objectif : les lister"])
  ns.Print(Tr["/drop paliers on|off · /drop session on|off · /drop rappel on|off"])
  ns.Print(Tr["/drop lang auto|en|fr : langue des textes de l'addon (auto = langue du jeu ; anglais par défaut hors client français)"])
  for i = 1, #ns.HelpExt do ns.Print(Tr[ns.HelpExt[i]]) end
end
local function slashHelp(rest)
  rest = (rest or ""):lower()
  if rest:find("tout", 1, true) or rest:find("all", 1, true) then return slashHelpAll() end
  for _, l in ipairs(ns.HELP_SHORT) do
    if type(print) == "function" then print(Tr[l]) end
  end
end

-- 3.5.19 : alias anglais des commandes (les noms français restent valables).
ns.CMD_ALIAS = {
  columns = "colonnes", size = "taille", opacity = "opacite", lock = "verrou", alerts = "alertes",
  activity = "activite", recipes = "recettes", links = "liens", unlearned = "nonapprises", tooltip = "infobulle",
  open = "ouvrir", tiers = "paliers", tier = "paliers", reminder = "rappel", bar = "barre", challenge = "defi", sounds = "sons",
  sound = "son", fade = "fondu", bg = "fond", pretier = "prepalier", history = "historique", milestones = "jalons",
  fishing = "peche", shopping = "courses", share = "partage", master = "maitre", weapon = "arme",
  goals = "objectif", colour = "couleurs", colours = "couleurs", categories = "categories",
  quiet = "calme", profile = "profil", week = "semaine", achievements = "succes", progress = "progression",
  sessiongoal = "but", target = "but",
  flight = "vol", fly = "vol",
  resethints = "reset-hints",
  memoire = "mem", memory = "mem",
}
ns.ARG_ALIAS = {
  light = "leger", green = "vert", yellow = "jaune", tier = "palier", above = "dessus", below = "dessous",
  detach = "detache", detached = "detache", up = "haut", down = "bas", stack = "place", full = "complet", skill = "comp",
  duration = "duree", opacity = "opacite", sound = "son", marks = "marques", icons = "icones", compact = "compacte",
  default = "defaut", direction = "sens", main = "principale", challenge = "defi", prof = "metier",
  record = "record", point = "point", why = "pourquoi", all = "tout",
}
local NO_ARG_ALIAS = { objectif = true, objectifs = true, goal = true, debug = true, diag = true, apis = true,
  hitdebug = true, hit = true, lang = true, langue = true, language = true, courses = true }
function ns.NormalizeSlash(msg)
  msg = tostring(msg or "")
  local lead, cmd, rest = msg:match("^(%s*)(%S*)(.*)$")
  if not cmd or cmd == "" then return msg end
  local low = cmd:lower()
  if ns.CMD_ALIAS[low] and not ns.SlashExt[low] then low = ns.CMD_ALIAS[low] cmd = low end
  if not NO_ARG_ALIAS[low] then
    rest = rest:gsub("(%S+)", function(w) return ns.ARG_ALIAS[w:lower()] or w end)
  end
  return lead .. cmd .. rest
end

local function slashHandler(msg)
  msg = ns.NormalizeSlash(msg)
  local cmd = (msg or ""):match("^%s*(%S*)") or ""
  cmd = cmd:lower()
  local ext = ns.SlashExt[cmd]
  if ext then
    local rest = (msg or ""):match("^%s*%S+%s*(.-)%s*$") or ""
    ext(rest, msg)
    return
  end
  if cmd == "" or cmd == "show" or cmd == "toggle" or cmd == "afficher" then
    -- 3.5.5 : plus jamais muet (voir SafeOpen.lua)
    if ns.UI and ns.UI.Toggle then ns.UI:Toggle()
    else ns.Print(Tr["|cffff4040le panneau n'a pas pu se charger|r (erreur au chargement de l'addon) : /reload, puis /drop debug."]) end
  elseif cmd == "comp" or cmd == "skills" or cmd == "competences" or cmd == "compétences" then
    -- 3.2.0 : la vue OSRS est une fenêtre à part ; l'onglet Comp. natif reste intact.
    if ns.UI and ns.UI.Show then ns.UI:Show() end
  elseif cmd == "grille" or cmd == "grid" or cmd == "dessin" then
    -- 3.2.0 : la grille des lignes natives (3.1.0) est retirée : une seule
    -- vue OSRS, entièrement dessinée par l'addon.
    ns.Print(Tr["vue OSRS : fenêtre unique dessinée par l'addon (3.2.0). Les lignes natives ne sont plus déplacées."])
  elseif cmd == "vue" or cmd == "view" or cmd == "toggleview" then
    if ns.UI and ns.UI.ToggleView then
      ns.UI:ToggleView()
      ns.Print(ns.UI:IsOsrsView() and Tr["vue OSRS (onglet Comp.)."] or Tr["vue classique (liste Forever)."])
    end
  elseif cmd == "drops" or cmd == "drop" or cmd == "xp" then
    local rest = (msg or ""):match("^%s*%S+%s*(%S*)") or ""
    rest = rest:lower()
    if not ns.db then DropamineDB = DropamineDB or {} DropamineDB.ui = DropamineDB.ui or {} ns.db = DropamineDB end
    ns.db.ui = ns.db.ui or {}
    local full = (msg or ""):match("^%s*%S+%s*(.-)%s*$") or ""
    if ns.DropsSubcommand and ns.DropsSubcommand(full) then
      -- sous-commande gérée par le module Options (xp, comp, style, duree, opacite)
    elseif rest == "move" or rest == "deplacer" or rest == "déplacer" or rest == "unlock" then
      if ns.UI and ns.UI.ToggleDropsMove then ns.UI:ToggleDropsMove() end
    else
      local on
      if rest == "on" or rest == "1" or rest == "oui" then on = true
      elseif rest == "off" or rest == "0" or rest == "non" then on = false
      else on = not (ns.db.ui.dropsEnabled ~= false) end
      ns.db.ui.dropsEnabled = on
      if ns.UI and ns.UI.ApplyDropsEnabled then ns.UI:ApplyDropsEnabled() end
      ns.Print(Tr["drops "] .. (on and Tr["activés."] or Tr["désactivés."]))
    end
  elseif cmd == "stats" or cmd == "stat" or cmd == "caracs" or cmd == "caractéristiques" then
    local rest = (msg or ""):match("^%s*%S+%s*(%S*)") or ""
    rest = rest:lower()
    if not ns.db then DropamineDB = DropamineDB or {} DropamineDB.ui = DropamineDB.ui or {} ns.db = DropamineDB end
    ns.db.ui = ns.db.ui or {}
    local on
    if rest == "on" or rest == "1" or rest == "oui" then on = true
    elseif rest == "off" or rest == "0" or rest == "non" then on = false
    else on = not (ns.db.ui.showStats == true) end
    ns.db.ui.showStats = on
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh(true) end
    ns.Print(Tr["caractéristiques "] .. (on and Tr["affichées dans la grille."] or Tr["masquées (déjà sur la fiche)."]))
  elseif cmd == "icon" or cmd == "icone" or cmd == "icône" then
    local rest = (msg or ""):match("^%s*%S+%s*(%S*)") or ""
    rest = rest:lower()
    if not ns.db then DropamineDB = DropamineDB or {} DropamineDB.ui = DropamineDB.ui or {} ns.db = DropamineDB end
    ns.db.ui = ns.db.ui or {}
    local on
    if rest == "on" or rest == "1" or rest == "oui" then on = true
    elseif rest == "off" or rest == "0" or rest == "non" then on = false
    else on = not (ns.db.ui.customTabIcon ~= false) end
    ns.db.ui.customTabIcon = on
    if ns.UI and ns.UI.ApplyTabIcon then ns.UI:ApplyTabIcon() end
    ns.Print(Tr["icône de l'onglet Comp. "] .. (on and Tr["personnalisée."] or Tr["d'origine."]))
  elseif cmd == "couleurs" or cmd == "couleur" or cmd == "colors" or cmd == "color" then
    local rest = (msg or ""):match("^%s*%S+%s*(%S*)") or ""
    rest = rest:lower()
    if rest == " palier" then rest = "palier" end
    if rest == "palier" or rest == "vert" or rest == "jaune" then
      ns.SetColorMode(rest)
      if ns.UI and ns.UI.Refresh then ns.UI:Refresh(true) end
      local label = rest
      if rest == "palier" then label = Tr["palier (rouge < 50 %, jaune 50-75 %, vert > 75 %)"]
      elseif rest == "vert" then label = Tr["vert (tous les chiffres)"]
      else label = Tr["jaune (or natif, tous les chiffres)"] end
      ns.Print(Tr["couleur des chiffres : "] .. label .. ".")
    else
      ns.Print(Tr["couleur actuelle : "] .. Tr[ns.GetColorMode()] .. Tr[". Usage : /drop couleurs palier|vert|jaune"])
    end
  elseif cmd == "objectif" or cmd == "objectifs" or cmd == "goal" then
    local rest = (msg or ""):match("^%s*%S+%s*(.-)%s*$") or ""
    if ns.UI and ns.UI.SlashGoal then ns.UI:SlashGoal(rest) end
  elseif cmd == "paliers" or cmd == "palier" or cmd == "session" or cmd == "rappel" then
    local key = (cmd == "palier") and "paliers" or cmd
    local rest = ((msg or ""):match("^%s*%S+%s*(%S*)") or ""):lower()
    if not ns.db then DropamineDB = DropamineDB or {} DropamineDB.ui = DropamineDB.ui or {} ns.db = DropamineDB end
    ns.db.ui = ns.db.ui or {}
    local on
    if rest == "on" or rest == "1" or rest == "oui" then on = true
    elseif rest == "off" or rest == "0" or rest == "non" then on = false
    else on = not ns.Opt(key) end
    ns.db.ui[key] = on
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh(true) end
    local labels = {
      paliers = Tr["annonces de palier"], session = Tr["gains de session"], rappel = Tr["rappel d'arme sous-montée"],
    }
    ns.Print(labels[key] .. (on and Tr[" activé(e)s."] or Tr[" désactivé(e)s."]))
  elseif cmd == "hitdebug" or cmd == "hit" then
    local rest = (msg or ""):match("^%s*%S+%s*(.-)%s*$") or ""   -- 3.5.5 : n'est plus une globale indéfinie
    if ns.UI and ns.UI.HitDebug then ns.UI:HitDebug(rest) end
  elseif cmd == "debug" or cmd == "diag" or cmd == "apis" then
    ns.PrintDebug((msg or ""):match("^%s*%S+%s*(.-)%s*$"))
  elseif cmd == "reset" or cmd == "resetpos" then
    if ns.UI and ns.UI.ResetPositions then
      ns.UI:ResetPositions()
      ns.Print(Tr["positions réinitialisées."])
    end
  elseif cmd == "minimap" or cmd == "minicarte" then
    if ns.UI and ns.UI.ToggleMinimap then
      local shown = ns.UI:ToggleMinimap()
      ns.Print(shown and Tr["bouton de minicarte affiché."] or Tr["bouton de minicarte caché."])
    end
  elseif cmd == "help" or cmd == "aide" or cmd == "?" then
    slashHelp((msg or ""):match("^%s*%S+%s*(.-)%s*$"))
  else
    slashHelp()
  end
end

-- 3.3.18 : seulement /drop et /dropamine
SLASH_DROPAMINE1 = "/drop"
SLASH_DROPAMINE2 = "/dropamine"
if type(SlashCmdList) ~= "table" then SlashCmdList = {} end
SlashCmdList.DROPAMINE = slashHandler
ns.Slash = slashHandler

-- 3.5.18 : /drop debug — chaque compétence d'arme lue et son icône résolue
ns.DebugExt = ns.DebugExt or {}
ns.DebugExt[#ns.DebugExt + 1] = function()
  local okL, live = pcall(ns.CollectLiveSkills)
  local parts = {}
  if okL and type(live) == "table" then
    for _, sk in ipairs(live) do
      if sk and sk.name and not sk.header and not sk.equippedOnly then
        local e = ns.LookupCatalog and ns.LookupCatalog(sk.name)
        local weapon = (e and (e.kind == "melee" or e.kind == "ranged" or e.kind == "defense")) or ns.LooksLikeWeapon(sk.name, sk.headerName)
          or (ns.EXTRA_SKILL_ICONS and ns.EXTRA_SKILL_ICONS[ns.Fold(sk.name)])
        if weapon then
          local icon, id, src = ns.ResolveSkillIcon(sk.name, sk.headerName, sk.skillID)
          local short = tostring(icon or "—"):gsub("^Interface\\Icons\\", "")
          parts[#parts + 1] = string.format("%s [%s] → %s (%s%s)", tostring(sk.name), tostring(sk.skillID or "?"), short, tostring(src), id and (", " .. id) or "")
        end
      end
    end
  end
  return { "— Icônes des armes (3.5.18) — " .. ((#parts > 0) and table.concat(parts, " · ") or "aucune compétence d'arme lue") }
end


------------------------------------------------------------------------------
-- Mémoire retenue : /drop mem
-- GetAddOnMemoryUsage (Ko) avant / après collectgarbage, plus une ventilation
-- estimée des tables retenues (SavedVariables, bases, index, snapshots).
------------------------------------------------------------------------------
local function MemSize(v, seen)
  if v == nil then return 0 end
  local t = type(v)
  if t == "boolean" or t == "number" then return 16 end
  if t == "function" or t == "userdata" or t == "thread" then return 40 end
  if t == "string" then
    if seen[v] then return 0 end
    seen[v] = true
    return 24 + #v
  end
  if t ~= "table" then return 0 end
  if seen[v] then return 0 end
  seen[v] = true
  local n = 40
  for k, x in pairs(v) do
    n = n + 40 + MemSize(k, seen) + MemSize(x, seen)
  end
  return n
end

function ns.MemSize(v)
  return MemSize(v, {})
end

function ns.MemBreakdown()
  local rows, seen = {}, {}
  local function add(name, obj, note)
    rows[#rows + 1] = { name = name, bytes = MemSize(obj, seen), note = note }
  end
  -- seen is shared so overlaps (chars inside DropamineDB) aren't double-counted
  -- if we add DB first then children with a fresh seen for the child-only view.
  local db = rawget(_G, "DropamineDB") or ns.db
  local old = rawget(_G, "OSRS_TotalLevelDB")
  add("DropamineDB", db)
  -- child views use a private seen so the user sees each bag's own weight
  local function own(name, obj, note)
    rows[#rows + 1] = { name = name, bytes = MemSize(obj, {}), note = note, child = true }
  end
  own("  ui", db and db.ui)
  own("  scanner", db and db.scanner)
  local scanner = db and db.scanner
  if type(scanner) == "table" then
    local nc, nn = 0, 0
    for _ in pairs(scanner.creatures or {}) do nc = nc + 1 end
    for _ in pairs(scanner.nodes or {}) do nn = nn + 1 end
    own("    creatures", scanner.creatures, nc > 0 and (tostring(nc) .. " PNJ") or nil)
    own("    nodes", scanner.nodes, nn > 0 and (tostring(nn) .. " nœuds") or nil)
    own("    fishing", scanner.fishing)
  end
  own("  chars", db and db.chars)
  if type(db) == "table" and type(db.chars) == "table" then
    for key, c in pairs(db.chars) do
      if type(c) == "table" then
        local bits = {}
        local function bit(label, obj)
          local b = MemSize(obj, {})
          if b >= 2048 then bits[#bits + 1] = label .. " " .. string.format("%.1f", b / 1024) .. " Ko" end
        end
        bit("sessLog", c.progress and c.progress.sessLog)
        bit("semaines", c.progress and c.progress.sessWeeks)
        bit("spots", c.progress and c.progress.spots)
        bit("historique", c.history)
        bit("recettes", c.recipes)
        bit("pêche", c.fishing)
        own("    " .. tostring(key), c, (#bits > 0) and table.concat(bits, ", ") or nil)
      end
    end
  end
  add("OSRS_TotalLevelDB", old, (old and db and old ~= db) and "copie encore chargée (migration)" or nil)
  add("ScannerDB (base)", ns.ScannerDB)
  add("index noms PNJ", ns.Scanner and ns.Scanner._npcNames)
  add("recettes par composant", ns.Craft and ns.Craft._byReagent)
  add("locales", ns.LOCALES)
  add("catalogue", ns.CATALOG)
  add("snapshot UI", ns.UI and ns.UI.snapshot)
  add("échantillons rythme", ns.Rate and ns.Rate.samples)
  add("cache GUID", ns.Scanner and ns.Scanner._guidCache)
  add("cache objets scanner", ns.Scanner and ns.Scanner._itemCache)
  return rows
end

function ns.AddonMemoryKB()
  local name = ADDON or "Dropamine"
  if type(_G.UpdateAddOnMemoryUsage) == "function" then pcall(_G.UpdateAddOnMemoryUsage) end
  if type(_G.GetAddOnMemoryUsage) == "function" then
    local ok, v = pcall(_G.GetAddOnMemoryUsage, name)
    if ok then return tonumber(v) end
  end
  if type(collectgarbage) == "function" then
    local ok, v = pcall(collectgarbage, "count")
    if ok then return tonumber(v) end
  end
  return nil
end

function ns.StepGC(work)
  if ns.InCombat and ns.InCombat() then return false end
  if type(collectgarbage) ~= "function" then return false end
  pcall(collectgarbage, "step", work or 400)
  return true
end

function ns.PruneRetained()
  local db = ns.EnsureDB and ns.EnsureDB() or ns.db
  local n = 0
  if type(db) == "table" and type(db.chars) == "table" then
    for _, c in pairs(db.chars) do
      if type(c) == "table" then
        if ns.QoL and ns.QoL.PruneHistory then pcall(ns.QoL.PruneHistory, c) n = n + 1 end
        if c.progress and ns.Efficiency and ns.Efficiency.CompactHist then
          pcall(ns.Efficiency.CompactHist, c.progress)
        end
      end
    end
  end
  if ns.Scanner and ns.Scanner.PruneLearned then pcall(ns.Scanner.PruneLearned) end
  if ns.StepGC then pcall(ns.StepGC, 400) end
  return n
end

-- Chien de garde conservateur : seulement des objets clairement coincés, dans
-- les viviers de l'addon (pas d'énumération globale). Jamais en combat, jamais
-- une animation visible encore dans sa durée, jamais une fenêtre ouverte.
ns.Watchdog = ns.Watchdog or {}
local WD = ns.Watchdog
WD.INTERVAL = 8
WD.TOAST_GRACE = 5

local function wdNow()
  if type(GetTime) == "function" then
    local ok, v = pcall(GetTime)
    if ok and type(v) == "number" then return v end
  end
  return 0
end

local function wdShown(f)
  if not f then return false end
  if f.IsShown then
    local ok, v = pcall(f.IsShown, f)
    if ok then return v and true or false end
  end
  return f.shown ~= false
end

local function wdClearOnUpdate(f)
  if f and f.SetScript and not wdShown(f) then
    local ok, s = pcall(f.GetScript, f, "OnUpdate")
    if ok and s then pcall(f.SetScript, f, "OnUpdate", nil) return true end
  end
  return false
end

local function wdAnimMax(ag)
  if not ag or not ag.anims then
    -- WoW AnimationGroup : parcourir les enfants n'est pas possible ici ;
    -- on s'appuie sur _wdMax / _wdStart posés à la lecture.
    return ag and ag._wdMax
  end
  local d = 0
  for _, a in ipairs(ag.anims) do
    d = d + (tonumber(a.duration) or 0) + (tonumber(a.delay) or 0)
  end
  return d > 0 and d or ag._wdMax
end

local function wdStopStuckAnim(host, ag)
  if not ag then return false end
  local playing = false
  if ag.IsPlaying then
    local ok, v = pcall(ag.IsPlaying, ag)
    playing = ok and v and true or false
  else
    playing = ag.playing and true or false
  end
  if not playing then return false end
  local hidden = host and not wdShown(host)
  if hidden then
    if ag.Stop then pcall(ag.Stop, ag) end
    return true
  end
  -- visible : seulement si la durée a dépassé 2× le maximum connu
  local maxd = ag._wdMax or wdAnimMax(ag)
  local start = ag._wdStart
  local now = wdNow()
  if maxd and start and now > 0 and (now - start) > (2 * maxd) then
    if ag.Stop then pcall(ag.Stop, ag) end
    return true
  end
  return false
end

function WD.Sweep()
  if ns.InCombat and ns.InCombat() then return 0 end
  local n, UI, C, S = 0, ns.UI, ns.Compact, ns.Slot
  local function one(f)
    if type(f) ~= "table" then return end
    local ok, err = pcall(function()
      if wdClearOnUpdate(f) then n = n + 1 end
      if wdStopStuckAnim(f, f.ag) then n = n + 1 end
      if wdStopStuckAnim(f, f._bumpAG) then n = n + 1 end
      if f.tex and wdStopStuckAnim(f, f.ag) then end
      -- toast clairement hors délai (âge ou horloge), pas en survol / ancré / aperçu
      if f._osrsToast or f.iconSlot then
        if f._hover or f._sticky or f._editPreview then return end
        local hold = f._hold
        if hold == nil and UI and UI.DropHold then hold = UI:DropHold() end
        hold = tonumber(hold) or 2.6
        local life = 0.15 + hold + 0.70
        local age = tonumber(f._toastAge) or 0
        local born = tonumber(f._toastBorn)
        local now = wdNow()
        local wall = (born and now > 0) and (now - born) or 0
        if age > life + (WD.TOAST_GRACE or 5) or wall > life + (WD.TOAST_GRACE or 5) then
          if UI and UI.DismissDrop then pcall(UI.DismissDrop, UI, f) n = n + 1 end
        end
      end
    end)
    if not ok then n = n end
  end
  if UI then
    for _, f in ipairs(UI.dropsActive or {}) do one(f) end
    for _, f in ipairs(UI._toastPool or {}) do one(f) end
  end
  if C then
    for _, f in ipairs(C.pool or {}) do
      -- éclat en vol : ne pas couper l'OnUpdate ni l'anim
      if not (f._busy or f._entry) then one(f) end
    end
    if C.Tiles then
      local ok, tiles = pcall(C.Tiles)
      if ok and type(tiles) == "table" then
        for _, tile in ipairs(tiles) do
          if tile then
            one(tile._osrsPulse)
            one(tile._osrsGain)
          end
        end
      end
    end
  end
  -- étincelle volante poolée (pas le driver de barre, qui est volontairement actif)
  if S and S._flySpark then one(S._flySpark) end
  return n
end

function WD.Tick(dt)
  if ns.InCombat and ns.InCombat() then return end
  WD._acc = (WD._acc or 0) + (tonumber(dt) or 0)
  if WD._acc < (WD.INTERVAL or 8) then return end
  WD._acc = 0
  pcall(WD.Sweep)
end

function ns.MemReport()
  ns.PruneRetained()
  local before = ns.AddonMemoryKB()
  local rows = ns.MemBreakdown()
  local after
  if type(collectgarbage) == "function" then pcall(collectgarbage, "collect") end
  after = ns.AddonMemoryKB()
  local function fmtKB(kb)
    kb = tonumber(kb)
    if not kb then return "?" end
    if kb >= 1024 then return string.format("%.1f Mo", kb / 1024) end
    return string.format("%.0f Ko", kb)
  end
  local function fmtB(b)
    b = tonumber(b) or 0
    if b >= 1024 * 1024 then return string.format("%.1f Mo", b / (1024 * 1024)) end
    if b >= 1024 then return string.format("%.0f Ko", b / 1024) end
    return string.format("%d o", b)
  end
  local lines = {}
  local head = Tr["Dropamine mémoire : "] .. fmtKB(before)
  if after then
    head = head .. Tr[" (après GC : "] .. fmtKB(after)
    if before and after and before > after then
      head = head .. Tr[", libéré "] .. fmtKB(before - after)
    end
    head = head .. ")"
  end
  lines[#lines + 1] = head
  for i = 1, #rows do
    local r = rows[i]
    if (r.bytes or 0) > 0 or not r.child then
      local line = r.name .. " : " .. fmtB(r.bytes)
      if r.note then line = line .. " (" .. r.note .. ")" end
      lines[#lines + 1] = line
    end
  end
  lines[#lines + 1] = Tr["Cible : moins de 18 Mo (niveau Flare). Le total de l'addon inclut aussi le code Lua et les cadres ; les lignes ci-dessus sont les tables retenues."]
  for i = 1, #lines do
    if ns.Print then ns.Print(lines[i]) else print(lines[i]) end
  end
  return lines, before, after, rows
end

ns.SlashExt = ns.SlashExt or {}
ns.SlashExt.mem = function()
  ns.MemReport()
  return true
end
ns.SlashExt.memoire = ns.SlashExt.mem
ns.SlashExt.memory = ns.SlashExt.mem

ns.HelpExt = ns.HelpExt or {}
ns.HelpExt[#ns.HelpExt + 1] = "/drop mem : mémoire de l'addon (GetAddOnMemoryUsage avant/après GC, ventilation des tables retenues)"

ns.On("PLAYER_LOGIN", function()
  pcall(ns.PruneRetained)
end)
