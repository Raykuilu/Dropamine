-- Série de temps actif (30 min / 1 h sans pause > 5 min) et succès Explorateur.
-- Usage, depuis la racine de l'addon : texlua tests/progress_run.lua
_G.NOW = 1000000
_G.time = function() return _G.NOW end
_G.GetServerTime = function() return _G.NOW end
local store = { ach = {} }
local toasts = {}
local ns
ns = { db = { ui = {} }, N = tonumber, On = function() end, Print = print, SlashExt = {}, HelpExt = {},
  Opt = function() return true end, OptOff = function() return false end, L = setmetatable({}, { __index = function(_, k) return k end }),
  CharDB = function() return store end, GetPlayerLevel = function() return 30 end, GetLevelCap = function() return 60 end }
setmetatable(ns, { __index = function() return nil end })
local ok, err = pcall(function() assert(loadfile("Progress.lua"))("Dropamine", ns) end)
if not ok then print("Chargement impossible dans le harnais :", err) os.exit(2) end
local P = ns.Progress
P.Toast = function(t) toasts[#toasts + 1] = t end
_G.NOW = 1000000
local function Gain(t) _G.NOW = t P.Gain("prof", "mining", "Minage", 1, true, t) end
P.C().achSeeded = true
local t = 1000000
for i = 0, 70 do Gain(t + i * 60) end          -- 70 min, un gain par minute
print("record série (s) :", P.Records().longestRun, "attendu >= 4200")
print("succès run30/run60 :", P.C().ach.run30 ~= nil, P.C().ach.run60 ~= nil)
Gain(t + 70 * 60 + 400)                        -- pause de 400 s : la série repart
print("série après pause (s) :", P.Session().run, "attendu 0")

-- Succès horaires : un gain à 6 h puis à 2 h (heure locale du harnais)
_G.date = function(_, t) return { hour = _G.HOUR } end
_G.HOUR = 6 Gain(_G.NOW + 10)
_G.HOUR = 2 Gain(_G.NOW + 10)
print("Lève-tôt / Noctambule :", P.C().ach.early ~= nil, P.C().ach.night ~= nil)
-- Hunt : premier objet trouvé après 60 tentatives
local R = P.C().records
R.huntFound, R.huntTries = 1, 60
_G.NOW = _G.NOW + 5 P.CheckAchievements("hunt")
print("Premier sang / Persévérant :", P.C().ach.firstfind ~= nil, P.C().ach.persist50 ~= nil)

-- Présence sans aucun gain : 40 min de déplacement (un signe toutes les 10 s) -> série de 30 min
store.progress = nil
_G.UnitIsAFK = function() return false end
_G.UnitAffectingCombat = function() return false end
_G.GetUnitSpeed = function() return 7 end
P.C().achSeeded = true
local t0 = 5000000
for i = 0, 240 do _G.NOW = t0 + i * 10 P.Presence() end
print("sans gain, 40 min de déplacement :", P.Records().longestRun, "s ; run30 =", P.C().ach.run30 ~= nil, "(attendu 2400 s, true)")
_G.GetUnitSpeed = function() return 0 end
_G.NOW = _G.NOW + 400 P.Presence()           -- immobile : rien ne compte
_G.GetUnitSpeed = function() return 7 end
_G.NOW = _G.NOW + 10 P.Presence()            -- il repart après plus de 5 min : nouvelle série
print("après une pause de 5 min, nouvelle série :", P.Session().run, "(attendu 0)")
