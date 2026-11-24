-- Armes à monter : niveau gris (Classic), plage de niveaux conseillée, liste triée par retard.
-- Usage, depuis la racine de l'addon : lua tests/weapons_level.lua   (code de retour 1 en cas d'échec)
_G.time = os.time
local level = 30
local ns = { db = { ui = {} }, N = tonumber, Opt = function() return true end, CharDB = function() return {} end,
  Fold = function(s) return tostring(s):lower() end, On = function() end, SlashExt = {}, HelpExt = {},
  GetPlayerLevel = function() return level end, WEAPON_RANK_PER_LEVEL = 5, DebugExt = {} }
ns.L = setmetatable({}, { __index = function(_, k) return k end })
ns.CATALOG = {
  { id = "swords", name = "Épées", kind = "melee" }, { id = "maces", name = "Masses", kind = "melee" },
  { id = "bows", name = "Arcs", kind = "ranged" }, { id = "defense", name = "Défense", kind = "defense" },
}
ns.CATALOG_EN = { swords = "Swords", maces = "Maces", bows = "Bows", defense = "Defense" }
ns.CatalogDisplayName = function(e) return e.name end
-- client anglais : les rangs lus sont rangés sous les noms anglais
ns.SkillRankSnapshot = function() return {
  swords = { rank = 150, max = 150 }, maces = { rank = 40, max = 150 }, defense = { rank = 120, max = 150 } } end
assert(loadfile("QoL.lua"))("Dropamine", ns)
local fail = 0
local function check(ok, what) if not ok then fail = fail + 1 print("ÉCHEC :", what) end end
check(ns.GreyLevel(5) == 0, "gris niv. 5")
check(ns.GreyLevel(30) == 22, "gris niv. 30 = 22 (" .. tostring(ns.GreyLevel(30)) .. ")")
check(ns.GreyLevel(50) == 39, "gris niv. 50 = 39 (" .. tostring(ns.GreyLevel(50)) .. ")")
check(ns.GreyLevel(60) == 51, "gris niv. 60 = 51")
local Q = ns.QoL
-- arme : sous 5 × le niveau du monstre, même gris (règle Forever) ; Défense : en plus non gris
local lo, hi = Q.WeaponLevelRange(40, "melee")
check(lo == 9 and hi == 32, "Masses 40 au niv. 30 : monstres 9-32 (vu " .. lo .. "-" .. hi .. ")")
lo, hi = Q.WeaponLevelRange(120, "defense")
check(lo == 25 and hi == 32, "Défense 120 au niv. 30 : monstres 25-32 (vu " .. lo .. "-" .. hi .. ")")
lo, hi = Q.WeaponLevelRange(20, "defense")
check(lo == 23, "Défense basse : jamais sous le premier niveau non gris (vu " .. lo .. ")")
local list = Q.WeaponsToLevel()
check(#list == 2, "deux à monter (Masses, Défense), vu " .. #list)
check(list[1] and list[1].id == "maces", "Masses en tête (le plus en retard)")
check(list[2] and list[2].id == "defense", "Défense ensuite")
print(fail == 0 and "OK : armes à monter" or (fail .. " échec(s)"))
os.exit(fail == 0 and 0 or 1)
