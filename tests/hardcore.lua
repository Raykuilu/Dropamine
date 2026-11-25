-- 3.10.0 : paliers en guilde, maîtres d'armes des capitales, onglet Hardcore (liseré danger).
-- Usage, depuis la racine de l'addon : lua tests/hardcore.lua   (code de retour 1 en cas d'échec)
_G.time = os.time
_G.date = os.date
local hc, inGuild = false, true
_G.C_GameRules = { IsHardcoreActive = function() return hc end }
_G.UnitLevel = function() return 30 end
_G.UnitClass = function() return "Guerrier", "WARRIOR" end
_G.UnitFactionGroup = function() return "Horde" end
_G.IsInGuild = function() return inGuild end
local sent = {}
_G.SendChatMessage = function(msg, chan) sent[#sent + 1] = { msg, chan } end
_G.C_Timer = { After = function() end }

local ui = { hcDanger = true }
local ns = { db = { ui = ui }, N = tonumber, Unsecret = function(...) return ... end,
  Opt = function(k) return ui[k] ~= false end, OptOff = function(k) return ui[k] == true end,
  Fold = function(s) return tostring(s):lower() end, On = function() end,
  SlashExt = {}, HelpExt = {}, Print = function() end,
  GetPlayerLevel = function() return 30 end, WEAPON_RANK_PER_LEVEL = 5, TOTAL_MAX = 2460, DebugExt = {} }
ns.L = setmetatable({}, { __index = function(_, k) return k end })
-- un personnage = une table (Hardcore manuel par personnage)
local chars, current = { A = {}, B = {} }, "A"
ns.CharDB = function() return chars[current] end
ns.IsFrench = function() return true end
ns.CATALOG = { { id = "swords", name = "Épées", kind = "melee" }, { id = "bows", name = "Arcs", kind = "ranged" },
  { id = "axes", name = "Haches", kind = "melee" }, { id = "defense", name = "Défense", kind = "defense" } }
ns.CatalogById = function(id) for _, e in ipairs(ns.CATALOG) do if e.id == id then return e end end end
ns.CatalogDisplayName = function(e) return e.name end
ns.SkillRankSnapshot = function() return { [ns.Fold("Épées")] = { rank = 100, max = 150 }, [ns.Fold("Défense")] = { rank = 120, max = 150 } } end
-- détection Hardcore (Core.lua) : on ne charge que ns.IsHardcore
do
  local src = io.open("Core.lua"):read("a")
  local a = src:find("%-%- 3%.10%.0 : mode Hardcore")
  local b = src:find("\nend\n", src:find("function ns.IsHardcore()", a, true), true)
  assert(load(src:sub(a, b + 4), "hc", "t", setmetatable({ ns = ns }, { __index = _G })))()
end
local db = {}
ns.EnsureDB = function() return db end
local dinged = {}
ns.UI = { snapshot = { total = 812, totalMax = 2460 } }
ns.Progress = { C = function() return { dinged = dinged } end,
  TotalDing = function(prev, cur) if cur >= 1000 and prev < 1000 then dinged[1000] = true end end }
ns.Options = { EXTRA = {}, EXTRA_HOME = {}, GROUPS = { grpAnnounce = { items = {} } }, MAP = { advanced = {} }, TEST = {} }
assert(loadfile("QoL.lua"))("Dropamine", ns)
assert(loadfile("WeaponMasters.lua"))("Dropamine", ns)
assert(loadfile("GuildMilestones.lua"))("Dropamine", ns)
assert(loadfile("Hardcore.lua"))("Dropamine", ns)
local H = ns.Hardcore
local fail = 0
local function check(ok, what) if not ok then fail = fail + 1 print("ÉCHEC :", what) end end

check(not ns.IsHardcore(), "personnage normal : pas Hardcore")
-- Hardcore manuel : par personnage
H.SetManual(true)
check(ns.IsHardcore() and ns.HardcoreManual(), "case cochée : Hardcore actif")
current = "B"
check(not ns.IsHardcore(), "autre personnage : pas touché")
current = "A"
ns.SlashExt.hc("off")
check(not ns.IsHardcore(), "/drop hc off : coupé")
ns.SlashExt.hc("on")
check(ns.IsHardcore(), "/drop hc on : actif")
H.SetManual(false)
check(ns.Options.GROUPS.grpHardcore.items[1][1] == "hcManual", "case manuelle en tête de l'onglet")
check(ns.Options.GROUPS.grpHardcore and ns.Options.MAP.advanced[1][1] == "Hardcore", "onglet Hardcore dans Avancé")
check(#ns.Options.GROUPS.grpHardcore.items == 5 and ns.Options.GROUPS.grpHardcore.items[3][1] == "hcSound", "onglet Hardcore : case manuelle, alerte, son, lueurs")
check(ns.Options.EXTRA_HOME.hcDanger == "advanced" and ns.Options.EXTRA_HOME.guildMilestones == "progress", "pages des réglages")

-- danger : inactif hors Hardcore, actif en Hardcore (ou simulé)
local tg = { level = 33, playerLevel = 30, attackable = true }
check(H.DangerOf(tg) == nil, "hors Hardcore : jamais de danger")
ns._forceHC = true
check(H.DangerOf(tg) ~= nil, "Hardcore simulé : +3 niveaux = danger")
ns._forceHC = nil
hc = true
check(ns.IsHardcore(), "Hardcore détecté (C_GameRules)")
tg.level = 32
check(H.DangerOf(tg) == nil, "+2 niveaux = pas de danger")
tg.classif = "elite"
check(H.DangerOf(tg) == "élite", "élite = danger")
tg.level = -1 tg.classif = nil
check(H.DangerOf(tg) ~= nil, "niveau ?? = danger")
tg.classif = "elite"
check(H.Reason(tg) == "Élite · niveau ??", "bandeau : élite et niveau ??")
tg.classif = nil tg.level = 35
check(H.Reason(tg) == "+5 niveaux", "bandeau : +5 niveaux")
tg.level = -1
ui.hcDanger = false
check(H.DangerOf(tg) == nil, "option coupée : pas de danger")
ui.hcDanger = true
tg.attackable = false
check(H.DangerOf(tg) == nil, "cible amicale : pas de danger")
hc = false

-- maîtres d'armes (Horde) et armes manquantes du guerrier
local m = ns.WeaponMasters.MastersFor("bows")
check(m[1] and (m[1].npc == "Sayoc" or m[1].npc == "Hanashi"), "Arcs : maître d'Orgrimmar")
check(ns.WeaponMasters.StaticMaster("swords") and ns.WeaponMasters.StaticMaster("swords").npc == "Archibald", "Épées : Archibald")
local miss = ns.WeaponMasters.MissingWeapons()
local hasSwords = false
for _, w in ipairs(miss) do if w.id == "swords" then hasSwords = true end end
check(#miss > 0 and not hasSwords, "armes manquantes : sans les Épées déjà apprises")

-- paliers en guilde (coupé par défaut)
ns.Progress.TotalDing(990, 1005)
check(#sent == 0, "rien en guilde par défaut")
dinged[1000] = nil
ui.guildMilestones = true
ns.Progress.TotalDing(990, 1005)
check(#sent == 1 and sent[1][2] == "GUILD" and sent[1][1]:find("1000"), "palier 1000 annoncé en guilde")
dinged[1000] = nil
inGuild = false
ns.Progress.TotalDing(990, 1005)
check(#sent == 1, "sans guilde : rien envoyé")

print(fail == 0 and "OK : paliers en guilde, maîtres d'armes, Hardcore" or (fail .. " échec(s)"))
os.exit(fail == 0 and 0 or 1)
