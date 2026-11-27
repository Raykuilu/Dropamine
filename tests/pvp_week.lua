-- 3.12.2 : semaine JcJ tenue par l'addon (Forever ne répond pas à GetPVPThisWeekStats) : honneur estimé lu dans le
_G.unpack = _G.unpack or table.unpack   -- WoW (Lua 5.1) a unpack
-- message du jeu (texte officiel de la langue du client), remis à zéro à la remise hebdomadaire, envoyé par /drop hiscores.
local clock = 1800000000
_G.time = function() return clock end
local left = 3 * 86400
_G.C_DateAndTime = { GetSecondsUntilWeeklyReset = function() return left end }
_G.COMBATLOG_HONORGAIN = "%s dies, honorable kill Rank: %s (Estimated Honor Points: %d)"
_G.COMBATLOG_HONORGAIN_NO_RANK = "%s dies, honorable kill (Estimated Honor Points: %d)"
local store = {}
local ns = { N = tonumber, Unsecret = function(...) return ... end, CharDB = function() return store end, On = function() end, Print = function() end,
  L = setmetatable({}, { __index = function(_, k) return k end }), db = { ui = {} } }
assert(loadfile("Locales/Locale.lua"))("Dropamine", ns)
local stub = setmetatable({}, { __index = function() return function() end end })
ns.UI = setmetatable({}, { __index = function() return function() end end })
ns.Options = { EXTRA = {}, GROUPS = {}, EXTRA_HOME = {} }
assert(loadfile("PvP.lua"))("Dropamine", ns)
local PV = ns.PvP
assert(PV.HonorOfMsg("Grumpy dies, honorable kill Rank: Scout (Estimated Honor Points: 23)") == 23, "message avec rang")
assert(PV.HonorOfMsg("Bob dies, honorable kill (Estimated Honor Points: 11)") == 11, "message sans rang")
assert(PV.HonorOfMsg("You have been awarded 50 honor points.") == nil, "bonus : pas une victoire")
PV.OnHonorMsg("Grumpy dies, honorable kill Rank: Scout (Estimated Honor Points: 23)")
PV.OnHonorMsg("Bob dies, honorable kill (Estimated Honor Points: 11)")
local w = PV.Week()
assert(w.hk == 2 and w.honor == 34, "semaine : 2 victoires, 34 d'honneur")
-- un jour plus tard, même semaine : le compte continue
clock, left = clock + 86400, left - 86400
PV.OnHonorMsg("Al dies, honorable kill (Estimated Honor Points: 6)")
assert(PV.Week().hk == 3 and PV.Week().honor == 40, "même semaine")
-- après la remise hebdomadaire : remis à zéro
clock, left = clock + 3 * 86400, 7 * 86400 - 86400
assert(PV.Week().hk == 0 and PV.Week().honor == 0, "nouvelle semaine")
-- export : le groupe JcJ envoie la semaine
PV.OnHonorMsg("Zed dies, honorable kill (Estimated Honor Points: 30)")
assert(loadfile("Hiscores.lua"))("Dropamine", ns)
local g
for _, x in ipairs(ns.Hiscores.GROUPS) do if x.key == "hsPvp" then g = x end end
local f = g and g.get()
assert(f and f[1]:match("^pv=1~30~"), "ligne : " .. tostring(f and f[1]))
print("OK : semaine JcJ (victoires, honneur) tenue par l'addon et exportée")
