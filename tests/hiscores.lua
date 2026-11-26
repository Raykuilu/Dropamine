-- 3.11.0 : export Hiscores (/drop hiscores) : ligne complète, somme de contrôle, champs nettoyés.
-- Usage, depuis la racine de l'addon : lua tests/hiscores.lua   (code de retour 1 en cas d'échec)
_G.UnitName = function() return "Ray" end
_G.UnitLevel = function() return 36 end
_G.GetGuildInfo = function() return "Everybody;Knows" end   -- un « ; » doit être neutralisé
_G.GetCurrentRegion = function() return 3 end
_G.time = function() return 1795600000 end
local shown
local ns = { VERSION = "3.11.0", N = tonumber }
ns.L = setmetatable({}, { __index = function(_, k) return k end })
ns.SkillsForCharSheet = function()
  return { { id = 393, name = "Dépeçage", rank = 223 }, { id = 129, name = "Secourisme", rank = 208 } },
    { { id = 136, name = "Bâtons", rank = 176 }, { id = 54, name = "Masses", rank = 102 } },
    { id = 95, name = "Défense", rank = 177 }
end
ns.DebugWindow = { Show = function(lines) shown = lines end }
assert(loadfile("Hiscores.lua"))("Dropamine", ns)
local HS = ns.Hiscores
local fail = 0
local function check(ok, what) if not ok then fail = fail + 1 print("ÉCHEC :", what) end end

local line, info = HS.Build()
check(line and line:sub(1, #HS.PREFIX) == HS.PREFIX, "la ligne commence par le préfixe")
check(info.weapons == 278 and info.defense == 177 and info.count == 2, "armes 278 (2), Défense 177")
check(line:find(HS.PREFIX .. "n=Ray;", 1, true) and line:find(";l=36;", 1, true) and line:find(";r=eu;", 1, true), "nom, niveau, région")
check(line:find(";g=Everybody Knows;", 1, true), "guilde nettoyée (pas de « ; » parasite)")
check(line:find(";w=136=176,54=102;", 1, true), "armes par identifiant")
check(line:find(";p=393=223,129=208;", 1, true), "métiers par identifiant")
local body, sum = line:sub(#HS.PREFIX + 1):match("^(.*);c=(%x+)$")
check(body and HS.Checksum(body) == sum, "somme de contrôle cohérente")
check(HS.Checksum(body .. "x") ~= sum, "une ligne modifiée change la somme")
HS.Open()
check(shown and shown[1] == line, "la fenêtre de copie affiche la ligne en premier")

-- 3.11.1 : /played
check(not line:find(";tp=", 1, true), "pas de /played connu : pas de champ tp")
local char, handlers, asked = {}, {}, 0
ns.CharDB = function() return char end
ns.db = { ui = {} }
ns.On = function(e, f) handlers[e] = f end
_G.RequestTimePlayed = function() asked = asked + 1 end
assert(loadfile("Hiscores.lua"))("Dropamine", ns)
HS = ns.Hiscores
HS.Open()
check(asked == 1, "fenêtre ouverte sans /played : on le demande au serveur")
handlers.TIME_PLAYED_MSG("TIME_PLAYED_MSG", 300000, 4000)
local l2, i2 = HS.Build()
check(l2:find(";tp=300000;", 1, true) and i2.played == 300000, "le /played est dans la ligne")
local b2, s2 = l2:sub(#HS.PREFIX + 1):match("^(.*);c=(%x+)$")
check(HS.Checksum(b2) == s2, "somme de contrôle avec /played")
check(HS.FormatPlayed(300000) == "3 j 11 h", "format 3 j 11 h")
ns.db.ui.hsPlayed = false
check(not HS.Build():find(";tp=", 1, true), "case décochée : pas de /played dans la ligne")

-- 3.11.1 : les autres groupes (collection, succès, records, chasse, JcJ)
ns.Hunt = {
  LogSections = function() return {
    { header = "30-49", entries = { { key = "dj:Gnomeregan", x = 5, y = 29, bosses = {} }, { key = "dj:Scarlet Monastery", x = 0, y = 28, bosses = {} } } },
    { header = "Raids", entries = { { key = "dj:Onyxia's Lair", x = 1, y = 12, bosses = {} } } },
    { header = "Général", entries = { { key = "st:Quêtes", x = 400, y = 500, stat = true } } },
  } end,
  List = function() return { { id = 9449, name = "Roueur manuel; [test]", attempts = 42, drops = 1 } } end,
  OwnedIds = function() return { 9449, 274043 } end,
}
ns.Progress = {
  Achievements = function() return { { id = "goal1", unlocked = true }, { id = "sess25", unlocked = true }, { id = "hour10" } } end,
  Records = function() return { bestSession = 61, bestHour = 19, bestDay = 88, longestCombo = 7, sessions = 30, goalsHit = 4, playtime = 123456.7 } end,
}
ns.PvP = { st = { hkWeek = 12, honorWeek = 340, honor = 900, dkLife = 1, highest = 3 }, Read = function() end }   -- jamais exporté
local l3, i3 = HS.Build()
check(l3:find(";ct=6~69;", 1, true), "collection : total donjons et raids (sans les statistiques)")
check(l3:find(";cl=Gnomeregan~5~29,Onyxia's Lair~1~12;", 1, true), "collection : seulement les donjons commencés")
check(l3:find(";ci=7ah.5vgb;", 1, true), "collection : objets obtenus en base 36 (9449, 274043)")
check(HS.B36(9449) == "7ah" and HS.B36(274043) == "5vgb", "base 36")
check(l3:find(";ac=2~3~goal1.sess25;", 1, true), "succès : nombre, total, identifiants")
check(l3:find(";rc=61~19~88~7~30~4~123456;", 1, true), "records")
check(l3:find(";hu=9449~Roueur manuel [test]~42~1;", 1, true), "chasse : nom nettoyé")
check(not l3:find(";pv=", 1, true), "JcJ jamais exporté (le site prend l'armurerie)")
check(#i3.extra == 4, "4 groupes inclus (temps de jeu décoché)")
for _, k in ipairs({ "hsLog", "hsAch", "hsRec", "hsHunt" }) do ns.db.ui[k] = false end
local l4 = HS.Build()
check(not (l4:find(";ct=", 1, true) or l4:find(";ac=", 1, true) or l4:find(";rc=", 1, true) or l4:find(";hu=", 1, true) or l4:find(";pv=", 1, true)), "tout décoché : rien en plus")
local b4, s4 = l4:sub(#HS.PREFIX + 1):match("^(.*);c=(%x+)$")
check(HS.Checksum(b4) == s4, "somme de contrôle")

ns.SkillsForCharSheet = function() return {}, {}, nil end
local none, why = HS.Build()
check(none == nil and type(why) == "string", "sans compétences lues : pas de ligne, un message")

-- 3.11.1 : rappel d'export : seulement après un premier export, s'il y a du nouveau, une fois par jour
do
  local cdb = {}
  local owned = { 1, 2 }
  ns.CharDB = function() return cdb end
  ns.Hunt = { OwnedIds = function() return owned end }
  check(HS.CheckReminder("20261126") == nil, "jamais exporté : pas de rappel")
  HS.MarkExported(100)
  check(HS.CheckReminder("20261126") == nil, "rien de nouveau : pas de rappel")
  owned = { 1, 2, 3, 4 }
  local m = HS.CheckReminder("20261126")
  check(m and m:find("^2 nouvel"), "2 nouveaux objets : rappel")
  check(HS.CheckReminder("20261126") == nil, "une fois par jour")
  check(HS.CheckReminder("20261127") ~= nil, "le lendemain, encore")
  HS.MarkExported(200)
  check(HS.CheckReminder("20261128") == nil, "après un nouvel export : plus de rappel")
end
if fail > 0 then os.exit(1) end
print("OK : export Hiscores")
