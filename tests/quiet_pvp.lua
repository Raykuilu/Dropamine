-- Mode calme automatique en champ de bataille / arène (3.9.0), à côté de celui des donjons.
-- Usage, depuis la racine de l'addon : lua tests/quiet_pvp.lua   (code de retour 1 en cas d'échec)
_G.time = os.time
local inst = { false, "none" }
_G.IsInInstance = function() return inst[1], inst[2] end
local ui = {}
local ns
ns = { db = { ui = ui }, N = tonumber, On = function() end, Print = function() end, SlashExt = {}, HelpExt = {},
  Opt = function(k) return ui[k] ~= false end, OptOff = function(k) return ui[k] == true end,
  L = setmetatable({}, { __index = function(_, k) return k end }),
  CharDB = function() return { ach = {} } end, GetPlayerLevel = function() return 30 end, GetLevelCap = function() return 60 end,
  Unsecret = function(...) return ... end }
setmetatable(ns, { __index = function() return nil end })
assert(loadfile("Progress.lua"))("Dropamine", ns)
local P = ns.Progress
local fail = 0
local function check(ok, what) if not ok then fail = fail + 1 print("ÉCHEC :", what) end end
check(P.RecomputeQuiet(true) == false, "dehors : pas de calme")
inst = { true, "pvp" }
local on, why = P.RecomputeQuiet(true)
check(on == true and why == "champ de bataille", "champ de bataille : calme (" .. tostring(why) .. ")")
inst = { true, "arena" }
on, why = P.RecomputeQuiet(true)
check(on == true and why == "arène", "arène : calme")
ui.quietAutoPvp = false
check(P.RecomputeQuiet(true) == false, "option coupée : pas de calme en champ de bataille")
inst = { true, "party" } ui.quietAutoPvp = nil
on, why = P.RecomputeQuiet(true)
check(on == true and why == "donjon", "donjon : toujours le calme auto des donjons")
-- bouton Tester : 15 s simulées, même case décochée
inst = { false, "none" } ui.quietAutoPvp = false
P.SimPvp(15)
on, why = P.RecomputeQuiet(true)
check(on == true and why == "champ de bataille", "simulation : calme actif malgré la case décochée")
-- reprise des anciens réglages (3.9.0) : « Jamais » + calme auto donjon -> une seule liste
P._simInstance, P._simPvpForce = nil, nil   -- fin de la simulation de champ de bataille ci-dessus (pas de minuterie ici)
local function migr(t) for k in pairs(ui) do ui[k] = nil end for k, v in pairs(t) do ui[k] = v end return P.QuietSetting() end
check(migr({}) == "instance", "défaut : en donjon / raid")
check(migr({ quietMode = "off" }) == "instance", "Jamais + auto coché : en donjon / raid (même comportement)")
check(migr({ quietMode = "off", quietAuto = false }) == "off", "Jamais + auto décoché : Jamais")
check(migr({ quietMode = "group" }) == "group", "En groupe : inchangé")
ui.quietMigrated = 1 ui.quietMode = "off"
check(P.QuietSetting() == "off", "après la reprise, « Jamais » choisi reste Jamais")
inst = { true, "party" }
check(P.RecomputeQuiet(true) == false, "Jamais : plus de calme en donjon")
print(fail == 0 and "OK : calme auto en champ de bataille" or (fail .. " échec(s)"))
os.exit(fail == 0 and 0 or 1)
