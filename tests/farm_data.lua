-- 3.13.0 : Farm — tendance d'un coin (10 derniers rythmes), points de récolte de la session par zone,
-- objets ramassés par zone, objectifs de farm (ajout, plafond, retrait, avancement lu dans les sacs).
_G.NOW = 1000000
_G.time = function() return _G.NOW end
_G.GetServerTime = function() return _G.NOW end
_G.GetZoneText = function() return "Les Tarides" end
_G.GetRealZoneText = _G.GetZoneText
_G.GetSubZoneText = function() return "" end
local store = { ach = {} }
local ns = { db = { ui = {} }, N = tonumber, On = function() end, Print = function() end, SlashExt = {}, HelpExt = {},
  Opt = function() return true end, OptOff = function() return false end, L = setmetatable({}, { __index = function(_, k) return k end }),
  CharDB = function() return store end, GetPlayerLevel = function() return 30 end, GetLevelCap = function() return 60 end }
setmetatable(ns, { __index = function() return nil end })
assert(loadfile("Progress.lua"))("Dropamine", ns)
local P = ns.Progress
P.Toast = function() end
P.C().achSeeded = true
-- 20 points à 1 min chacun, puis 10 à 3 min : le coin ralentit
local t = _G.NOW
for i = 1, 20 do t = t + 60 P.NoteGather("herbalism", 1, t) end
for i = 1, 10 do t = t + 180 P.NoteGather("herbalism", 1, t) end
local z = P.Spots("herbalism")[1]
assert(z and z.zone, "coin enregistré")
assert(z.recent and math.abs(z.recent - 3) < 1e-6, "rythme récent 3 min/pt : " .. tostring(z.recent))
assert(z.trend == "slower", "tendance : " .. tostring(z.trend))
assert((P.Session().zoneGather or {})[z.zone] == 30, "points de récolte de la session dans la zone")

-- Efficacité : objets ramassés et objectifs
_G.GetItemCount = function(id) return id == 2770 and 8 or 0 end
_G.GetItemInfo = function(id) return "Objet " .. id end
assert(loadfile("Efficiency.lua"))("Dropamine", ns)
local E = ns.Efficiency
E.NoteSessionItem(2447, 3, "Les Tarides") E.NoteSessionItem(2447, 2, "Les Tarides") E.NoteSessionItem(765, 1, "Les Tarides")
local items = E.SessionItems("Les Tarides")
assert(items[1].id == 2447 and items[1].n == 5 and items[2].id == 765, "objets ramassés triés")
assert(E.GoalAdd(2770, 20), "objectif ajouté")
assert(E.GoalAdd(2770, 30).qty == 30 and #E.Goals() == 1, "même objet : quantité mise à jour")
assert(select(2, E.GoalAdd(2770, 30)) == "same", "même objet, même quantité : rien à annoncer")
local g = E.GoalList()[1]
assert(g.have == 8 and math.abs(g.frac - 8 / 30) < 1e-9 and not g.done, "avancement lu dans les sacs")
for id = 1, 10 do E.GoalAdd(100 + id, 5) end
assert(#E.Goals() == E.GOALS_MAX, "plafond d'objectifs")
assert(select(2, E.GoalAdd(999, 1)) == "full", "objectif refusé au-delà du plafond")
assert(E.GoalRemove(1) and #E.Goals() == E.GOALS_MAX - 1, "objectif retiré")
assert(not E.GoalAdd(nil, 5) and not E.GoalAdd(5, 0), "saisie invalide refusée")
print("OK : Farm — tendance d'un coin, points et objets de la session par zone, objectifs de farm")
