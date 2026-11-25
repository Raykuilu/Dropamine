-- 3.10.0 : aiguille GPS dans la goutte : cap, couleurs, suivi du point natif, autre flèche, arrivée, retrait.
-- Usage, depuis la racine de l'addon : lua tests/needle.lua   (code de retour 1 en cas d'échec)
local now = 100
_G.GetTime = function() return now end
local facing = 0
_G.GetPlayerFacing = function() return facing end
local wp      -- point natif : { uiMapID, position = { x, y } }
local player = { x = 0, y = 0 }   -- coordonnées du monde (X nord, Y ouest)
local cleared = 0
_G.C_Map = {
  HasUserWaypoint = function() return wp ~= nil end,
  GetUserWaypoint = function() return wp end,
  ClearUserWaypoint = function() wp = nil cleared = cleared + 1 end,
  GetBestMapForUnit = function() return 1 end,
  GetPlayerMapPosition = function() return { x = 0.5, y = 0.5 } end,
  -- la carte 1 : la position du joueur ; la carte 2 : la position du point (monde = position * 1000)
  GetWorldPosFromMapPos = function(map, pos)
    if map == 1 and pos.x == 0.5 and pos.y == 0.5 then return 1, { x = player.x, y = player.y } end
    return (map == 9 and 2 or 1), { x = pos.x * 1000, y = pos.y * 1000 }
  end,
}
local ui = {}
local printed, toasts = {}, {}
local ns = { db = { ui = ui }, Opt = function(k) return ui[k] ~= false end, Print = function(m) printed[#printed + 1] = m end }
ns.L = setmetatable({}, { __index = function(_, k) return k end })
ns.UI = { SpawnDrop = function(_, icon, title, sub) toasts[#toasts + 1] = { title, sub } return true end }
assert(loadfile("Needle.lua"))("Dropamine", ns)
local Nd = ns.Needle
local fail = 0
local function check(ok, what) if not ok then fail = fail + 1 print("ÉCHEC :", what) end end
local function near(a, b) return math.abs(a - b) < 1e-6 end

-- cap : nord devant (orientation 0) -> 0 ; ouest -> +90° (à gauche) ; est -> -90° ; sud -> 180°
local r, d = Nd.Bearing(0, 0, 100, 0, 0)
check(near(r, 0) and near(d, 100), "point au nord, regard au nord : droit devant, 100 m")
r = Nd.Bearing(0, 0, 0, 100, 0)
check(near(r, math.pi / 2), "point à l'ouest : à gauche (+90°)")
r = Nd.Bearing(0, 0, 0, -100, 0)
check(near(r, -math.pi / 2), "point à l'est : à droite (-90°)")
r = Nd.Bearing(0, 0, 0, 100, math.pi / 2)
check(near(r, 0), "regard vers l'ouest, point à l'ouest : devant")
check(select(2, Nd.ColorFor(0)) == "ahead" and select(2, Nd.ColorFor(math.rad(60))) == "side"
  and select(2, Nd.ColorFor(math.pi)) == "behind", "couleurs : devant / côté / derrière")

-- pas de point posé : pas d'aiguille
check(not Nd.Track("X") and not Nd.Active(), "sans point natif : rien")
-- point posé par Dropamine : 200 m au nord
wp = { uiMapID = 1, position = { x = 0.2, y = 0 } }
check(Nd.Track("Vendeur-Tron 1000") and Nd.Active(), "point suivi : aiguille active")
local st = Nd.State()
check(st and near(st.dist, 200) and st.side == "ahead", "200 m droit devant")
-- un point que le joueur pose lui-même ensuite : on arrête de suivre
wp = { uiMapID = 1, position = { x = 0.3, y = 0 } }
check(not Nd.Active() and Nd.target == nil, "point remplacé par le joueur : plus d'aiguille")

-- TomTom chargé : pas d'aiguille
wp = { uiMapID = 1, position = { x = 0.2, y = 0 } }
Nd.Track("A")
_G.TomTom = {}
check(not Nd.Active(), "TomTom : pas d'aiguille")
_G.TomTom = nil
-- option coupée
ui.needle = false
check(not Nd.Active(), "option coupée : pas d'aiguille")
ui.needle = nil
-- donjon : pas d'orientation
facing = nil
check(not Nd.Active(), "sans orientation : pas d'aiguille")
facing = 0
-- autre continent
wp = { uiMapID = 9, position = { x = 0.2, y = 0 } }
Nd.Track("Loin")
check(not Nd.Active() and Nd.State() and Nd.State().other, "autre continent : pas de direction")

-- arrivée : toast puis point retiré
wp = { uiMapID = 1, position = { x = 0.2, y = 0 } }
Nd.Track("Vendeur-Tron 1000")
player.x = 195
st = Nd.State()
check(Nd.CheckArrival(st) and toasts[1] and toasts[1][1] == "Arrivé" and toasts[1][2] == "Vendeur-Tron 1000", "à 5 m : toast Arrivé")
check(wp == nil and Nd.target == nil, "point retiré à l'arrivée")
player.x = 0

-- Alt+clic : retirer
wp = { uiMapID = 1, position = { x = 0.2, y = 0 } }
Nd.Track("B")
local c0 = cleared
check(Nd.Clear() and cleared == c0 + 1 and Nd.target == nil, "retrait : point natif effacé")
-- garde-fou de durée
wp = { uiMapID = 1, position = { x = 0.2, y = 0 } }
Nd.Track("C")
now = now + Nd.MAX_AGE + 1
check(not Nd.Active(), "au-delà de 30 min : plus d'aiguille")

print(fail == 0 and "OK : aiguille GPS" or (fail .. " échec(s)"))
os.exit(fail == 0 and 0 or 1)
