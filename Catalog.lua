-- Dropamine — catalogue statique des compétences Forever (noms FR + alias EN).
-- Aucun plafond non documenté n'est inventé ici : voir les constantes commentées dans Core.lua.

local ADDON, ns = ...
if type(ns) ~= "table" then
  ns = _G.Dropamine or {}
  _G.Dropamine = ns
  ADDON = ADDON or "Dropamine"
end

function ns.Fold(s)
  s = tostring(s or "")
  s = s:gsub("É", "e"):gsub("È", "e"):gsub("Ê", "e"):gsub("Ë", "e")
  s = s:gsub("é", "e"):gsub("è", "e"):gsub("ê", "e"):gsub("ë", "e")
  s = s:gsub("Á", "a"):gsub("À", "a"):gsub("Â", "a"):gsub("Ä", "a")
  s = s:gsub("á", "a"):gsub("à", "a"):gsub("â", "a"):gsub("ä", "a")
  s = s:gsub("Í", "i"):gsub("Ì", "i"):gsub("Î", "i"):gsub("Ï", "i")
  s = s:gsub("í", "i"):gsub("ì", "i"):gsub("î", "i"):gsub("ï", "i")
  s = s:gsub("Ó", "o"):gsub("Ò", "o"):gsub("Ô", "o"):gsub("Ö", "o")
  s = s:gsub("ó", "o"):gsub("ò", "o"):gsub("ô", "o"):gsub("ö", "o")
  s = s:gsub("Ú", "u"):gsub("Ù", "u"):gsub("Û", "u"):gsub("Ü", "u")
  s = s:gsub("ú", "u"):gsub("ù", "u"):gsub("û", "u"):gsub("ü", "u")
  s = s:gsub("Ç", "c"):gsub("ç", "c")
  s = s:gsub("Œ", "oe"):gsub("œ", "oe")
  s = s:lower()
  s = s:gsub("'", " "):gsub("’", " "):gsub("-", " ")
  -- 3.3.7 : tirets et espaces typographiques (‑ – — et espace insécable)
  s = s:gsub("\226\128\145", " "):gsub("\226\128\147", " "):gsub("\226\128\148", " "):gsub("\194\160", " ")
  s = s:gsub("%s+", " ")
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  return s
end

ns.FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

-- kind : "level" | "stat" | "profession" | "secondary" | "melee" | "ranged" | "defense" | "class"
-- countsInTotal (hors armes) : true/false. Les armes passent par la règle « 2 meilleures ».
-- capKind : "level" | "profession" | "weapon" | "none"
local CATALOG = {
  -- Général
  { id = "level", name = "Niveau", aliases = { "level", "character level" }, section = "Général",
    kind = "level", capKind = "level", countsInTotal = true,
    icon = "Interface\\Icons\\INV_Misc_Book_11" },

  -- Caractéristiques (affichées, pas dans le total fictif : aucun plafond documenté)
  { id = "stat1", name = "Force", aliases = { "strength" }, section = "Caractéristiques",
    kind = "stat", capKind = "none", countsInTotal = false, statIndex = 1,
    icon = "Interface\\Icons\\Spell_Nature_Strength" },
  { id = "stat2", name = "Agilité", aliases = { "agility" }, section = "Caractéristiques",
    kind = "stat", capKind = "none", countsInTotal = false, statIndex = 2,
    icon = "Interface\\Icons\\Ability_Rogue_Sprint" },
  { id = "stat3", name = "Endurance", aliases = { "stamina" }, section = "Caractéristiques",
    kind = "stat", capKind = "none", countsInTotal = false, statIndex = 3,
    icon = "Interface\\Icons\\Spell_Holy_Devotion" },
  { id = "stat4", name = "Intelligence", aliases = { "intellect" }, section = "Caractéristiques",
    kind = "stat", capKind = "none", countsInTotal = false, statIndex = 4,
    icon = "Interface\\Icons\\Spell_Holy_MagicalSentry" },
  { id = "stat5", name = "Esprit", aliases = { "spirit" }, section = "Caractéristiques",
    kind = "stat", capKind = "none", countsInTotal = false, statIndex = 5,
    icon = "Interface\\Icons\\Spell_Shadow_BurningSpirit" },

  -- Métiers principaux
  { id = "alchemy", name = "Alchimie", aliases = { "alchemy" }, section = "Métiers",
    kind = "profession", capKind = "profession", countsInTotal = true,
    icon = "Interface\\Icons\\Trade_Alchemy" },
  { id = "blacksmithing", name = "Forge", aliases = { "blacksmithing" }, section = "Métiers",
    kind = "profession", capKind = "profession", countsInTotal = true,
    icon = "Interface\\Icons\\Trade_BlackSmithing" },
  { id = "enchanting", name = "Enchantement", aliases = { "enchanting" }, section = "Métiers",
    kind = "profession", capKind = "profession", countsInTotal = true,
    icon = "Interface\\Icons\\Trade_Engraving" },
  { id = "engineering", name = "Ingénierie", aliases = { "engineering" }, section = "Métiers",
    kind = "profession", capKind = "profession", countsInTotal = true,
    icon = "Interface\\Icons\\Trade_Engineering" },
  { id = "herbalism", name = "Herboristerie", aliases = { "herbalism" }, section = "Métiers",
    kind = "profession", capKind = "profession", countsInTotal = true,
    icon = "Interface\\Icons\\Trade_Herbalism" },
  { id = "leatherworking", name = "Travail du cuir", aliases = { "leatherworking" }, section = "Métiers",
    kind = "profession", capKind = "profession", countsInTotal = true,
    icon = "Interface\\Icons\\Trade_LeatherWorking" },
  { id = "mining", name = "Minage", aliases = { "mining", "fonte", "smelting" }, section = "Métiers",
    kind = "profession", capKind = "profession", countsInTotal = true,
    icon = "Interface\\Icons\\Trade_Mining" },
  { id = "skinning", name = "Dépeçage", aliases = { "skinning" }, section = "Métiers",
    kind = "profession", capKind = "profession", countsInTotal = true,
    icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01" },
  { id = "tailoring", name = "Couture", aliases = { "tailoring" }, section = "Métiers",
    kind = "profession", capKind = "profession", countsInTotal = true,
    icon = "Interface\\Icons\\Trade_Tailoring" },

  -- Compétences secondaires
  { id = "cooking", name = "Cuisine", aliases = { "cooking" }, section = "Compétences secondaires",
    kind = "secondary", capKind = "profession", countsInTotal = true,
    icon = "Interface\\Icons\\INV_Misc_Food_15" },
  { id = "fishing", name = "Pêche", aliases = { "fishing" }, section = "Compétences secondaires",
    kind = "secondary", capKind = "profession", countsInTotal = true,
    icon = "Interface\\Icons\\Trade_Fishing" },
  { id = "firstaid", name = "Secourisme", aliases = { "first aid" }, section = "Compétences secondaires",
    kind = "secondary", capKind = "profession", countsInTotal = true,
    icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice" },
  { id = "riding", name = "Monte", aliases = { "riding", "equitation", "équitation" }, section = "Compétences secondaires",
    kind = "secondary", capKind = "profession", countsInTotal = false,
    icon = "Interface\\Icons\\Ability_Mount_RidingHorse" },

  -- Armes de mêlée (toutes affichées ; une seule compte : la meilleure)
  { id = "axes", name = "Haches", aliases = { "axes" }, section = "Armes",
    kind = "melee", capKind = "weapon", countsInTotal = false,
    icon = "Interface\\Icons\\INV_Axe_01" },
  { id = "axes2h", name = "Haches à deux mains", aliases = { "two handed axes", "two-handed axes" }, section = "Armes",
    kind = "melee", capKind = "weapon", countsInTotal = false,
    icon = "Interface\\Icons\\INV_Axe_09" },
  { id = "maces", name = "Masses", aliases = { "maces" }, section = "Armes",
    kind = "melee", capKind = "weapon", countsInTotal = false,
    icon = "Interface\\Icons\\INV_Mace_01" },
  { id = "maces2h", name = "Masses à deux mains", aliases = { "two handed maces", "two-handed maces" }, section = "Armes",
    kind = "melee", capKind = "weapon", countsInTotal = false,
    icon = "Interface\\Icons\\INV_Mace_04" },
  { id = "swords", name = "Épées", aliases = { "swords" }, section = "Armes",
    kind = "melee", capKind = "weapon", countsInTotal = false,
    icon = "Interface\\Icons\\INV_Sword_04" },
  { id = "swords2h", name = "Épées à deux mains", aliases = { "two handed swords", "two-handed swords" }, section = "Armes",
    kind = "melee", capKind = "weapon", countsInTotal = false,
    icon = "Interface\\Icons\\INV_Sword_10" },
  { id = "polearms", name = "Armes d'hast", aliases = { "polearms" }, section = "Armes",
    kind = "melee", capKind = "weapon", countsInTotal = false,
    icon = "Interface\\Icons\\INV_Spear_06" },
  { id = "staves", name = "Bâtons", aliases = { "staves", "staff" }, section = "Armes",
    kind = "melee", capKind = "weapon", countsInTotal = false,
    icon = "Interface\\Icons\\INV_Staff_08" },
  { id = "fist", name = "Armes de pugilat", aliases = { "fist weapons", "fist" }, section = "Armes",
    kind = "melee", capKind = "weapon", countsInTotal = false,
    icon = "Interface\\Icons\\INV_Gauntlets_04" },
  { id = "daggers", name = "Dagues", aliases = { "daggers" }, section = "Armes",
    kind = "melee", capKind = "weapon", countsInTotal = false,
    icon = "Interface\\Icons\\INV_Weapon_ShortBlade_05" },
  { id = "unarmed", name = "Mains nues", aliases = { "unarmed" }, section = "Armes",
    kind = "melee", capKind = "weapon", countsInTotal = false,
    icon = "Interface\\Icons\\Ability_MeleeDamage" },
  -- Compétence vue en jeu sur Forever (druide, onglet Comp.) : sous Compétences d'armes.
  { id = "feral", name = "Combat farouche", aliases = { "feral combat" }, section = "Armes",
    kind = "melee", capKind = "weapon", countsInTotal = false,
    icon = "Interface\\Icons\\Ability_Druid_CatForm" },

  -- Armes à distance (toutes affichées ; une seule compte : la meilleure)
  { id = "bows", name = "Arcs", aliases = { "bows" }, section = "Armes",
    kind = "ranged", capKind = "weapon", countsInTotal = false,
    icon = "Interface\\Icons\\INV_Weapon_Bow_02" },
  { id = "guns", name = "Armes à feu", aliases = { "guns" }, section = "Armes",
    kind = "ranged", capKind = "weapon", countsInTotal = false,
    icon = "Interface\\Icons\\INV_Weapon_Rifle_01" },
  { id = "crossbows", name = "Arbalètes", aliases = { "crossbows" }, section = "Armes",
    kind = "ranged", capKind = "weapon", countsInTotal = false,
    icon = "Interface\\Icons\\INV_Weapon_Crossbow_01" },
  { id = "thrown", name = "Armes de jet", aliases = { "thrown" }, section = "Armes",
    kind = "ranged", capKind = "weapon", countsInTotal = false,
    icon = "Interface\\Icons\\INV_ThrowingKnife_02" },
  { id = "wands", name = "Baguettes", aliases = { "wands" }, section = "Armes",
    kind = "ranged", capKind = "weapon", countsInTotal = false,
    icon = "Interface\\Icons\\INV_Wand_01" },

  -- Défense (dans l'onglet Comp. elle apparaît sous les armes, mais elle COMPTE toujours dans le total)
  { id = "defense", name = "Défense", aliases = { "defense" }, section = "Défense",
    kind = "defense", capKind = "weapon", countsInTotal = true,
    icon = "Interface\\Icons\\INV_Shield_06" },

  -- Compétences de classe à rang (affichées même non apprises, à 0)
  { id = "lockpicking", name = "Crochetage", aliases = { "lockpicking" }, section = "Classe",
    kind = "class", capKind = "profession", countsInTotal = true,
    icon = "Interface\\Icons\\Spell_Nature_MoonKey" },
  { id = "poisons", name = "Poisons", aliases = { "poisons" }, section = "Classe",
    kind = "class", capKind = "profession", countsInTotal = true,
    icon = "Interface\\Icons\\Ability_Poisons" },
}

ns.CATALOG = CATALOG

-- Ordre d'affichage des sections
ns.SECTION_ORDER = {
  "Général",
  "Caractéristiques",
  "Métiers",
  "Compétences secondaires",
  "Armes",
  "Défense",
  "Classe",
  "Autres",
}

local LANGUAGE_HEADERS = {
  ["langues"] = true, ["languages"] = true, ["language proficiencies"] = true,
  ["competences de langues"] = true,
}
local ARMOR_HEADERS = {
  ["armures"] = true, ["armor"] = true, ["armor proficiencies"] = true,
}
local ARMOR_NAMES = {
  ["tissu"] = true, ["cloth"] = true,
  ["cuir"] = true, ["leather"] = true,
  ["mailles"] = true, ["maille"] = true, ["mail"] = true,
  ["plaques"] = true, ["plate"] = true,
  ["bouclier"] = true, ["boucliers"] = true, ["shield"] = true, ["shields"] = true,
}

ns.LANGUAGE_HEADERS = LANGUAGE_HEADERS
ns.ARMOR_HEADERS = ARMOR_HEADERS
ns.ARMOR_NAMES = ARMOR_NAMES

local aliasMap = {}
local idMap = {}
for i = 1, #CATALOG do
  local e = CATALOG[i]
  idMap[e.id] = e
  aliasMap[ns.Fold(e.name)] = e
  if e.aliases then
    for j = 1, #e.aliases do
      aliasMap[ns.Fold(e.aliases[j])] = e
    end
  end
end
ns.CATALOG_BY_ID = idMap

function ns.LookupCatalog(name)
  if not name then return nil end
  return aliasMap[ns.Fold(name)]
end

function ns.IsLanguageOrArmorJunk(name, header, maxRank)
  local h = ns.Fold(header or "")
  if LANGUAGE_HEADERS[h] then return true, "language" end
  local n = ns.Fold(name or "")
  local maxr = tonumber(maxRank) or 0
  if ARMOR_HEADERS[h] and maxr <= 1 and n ~= "defense" then return true, "armor" end
  if ARMOR_NAMES[n] and maxr <= 1 then return true, "armor" end
  return false
end

function ns.IsWeaponKind(kind)
  return kind == "melee" or kind == "ranged"
end

-- En-têtes natifs → section d'accueil pour une compétence hors catalogue.
local HEADER_TO_SECTION = {
  ["metiers"] = "Métiers",
  ["professions"] = "Métiers",
  ["competences secondaires"] = "Compétences secondaires",
  ["secondary skills"] = "Compétences secondaires",
  ["competences d armes"] = "Armes",
  ["weapon skills"] = "Armes",
  ["competences de classe"] = "Classe",
  ["class skills"] = "Classe",
  ["defense"] = "Défense",
}

function ns.SectionForHeader(header)
  return HEADER_TO_SECTION[ns.Fold(header or "")] or "Autres"
end

-- Deviner mêlée / distance pour une arme hors catalogue.
local RANGED_HINTS = {
  ["arcs"] = true, ["bows"] = true, ["bow"] = true,
  ["armes a feu"] = true, ["guns"] = true, ["gun"] = true, ["fusils"] = true,
  ["arbaletes"] = true, ["crossbows"] = true, ["crossbow"] = true,
  ["armes de jet"] = true, ["thrown"] = true, ["throwing"] = true,
  ["baguettes"] = true, ["wands"] = true, ["wand"] = true,
}

function ns.GuessWeaponKind(name, header)
  local n = ns.Fold(name or "")
  if RANGED_HINTS[n] then return "ranged" end
  local h = ns.Fold(header or "")
  if h == "competences d armes" or h == "weapon skills" then
    return "melee" -- par défaut, une arme inconnue est traitée comme mêlée
  end
  return nil
end
