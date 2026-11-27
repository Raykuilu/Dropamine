-- 3.13.0 : chasse partagée avec le groupe : liste envoyée (numéros en base 36), reçue des autres, qui chasse quoi.
_G.unpack = _G.unpack or table.unpack
local sent = {}
_G.C_ChatInfo = { RegisterAddonMessagePrefix = function() end, SendAddonMessage = function(p, m, ch) sent[#sent + 1] = { p, m, ch } end }
_G.IsInGroup = function() return true end
_G.IsInRaid = function() return false end
_G.UnitName = function(u) return ({ player = "Ray", party1 = "Bob", party2 = "Alice" })[u] end
_G.GetNumGroupMembers = function() return 3 end
_G.GetLootRollItemLink = function(rid) return rid == 7 and "|cnIQ3:|Hitem:7720::::|h[Hood]|h|r" or nil end
local printed = {}
local ui = {}
local ns = { N = tonumber, Opt = function(k) return ui[k] ~= false end, On = function() end, Print = function(m) printed[#printed + 1] = m end,
  L = setmetatable({}, { __index = function(_, k) return k end }),
  Hunt = { On = function() return true end, List = function() return { { id = 2262, drops = 0 }, { id = 9449, drops = 1 }, { id = 7720, drops = 0 } } end } }
assert(loadfile("GroupHunt.lua"))("Dropamine", ns)
local GH = ns.GroupHunt
-- envoi : seulement les objets pas encore trouvés
assert(GH.Encode() == "H1:1qu.5yg", "encodage : " .. GH.Encode())
assert(GH.Send(true) and sent[1][1] == "DROPAMINE" and sent[1][3] == "PARTY", "envoi au groupe")
-- réception : Bob chasse la capuche ; mon propre message est ignoré
GH.OnMessage("DROPAMINE", "H1:5yg.2ca", "PARTY", "Bob-Forever")
GH.OnMessage("DROPAMINE", "H1:5yg", "PARTY", "Ray")
assert(table.concat(GH.Hunters(7720), ",") == "Bob", "qui chasse la capuche")
-- question d'un nouveau membre : on répond
local before = #sent
GH.OnMessage("DROPAMINE", "Q", "PARTY", "Alice")
assert(#sent == before + 1, "réponse à la question")
-- jet de groupe : une ligne dans le chat, une seule fois
GH.OnRoll(7) GH.OnRoll(7)
assert(#printed == 1 and printed[1]:find("Bob", 1, true), "ligne au jet")
-- membre parti : liste oubliée
_G.UnitName = function(u) return ({ player = "Ray", party1 = "Alice" })[u] end
_G.GetNumGroupMembers = function() return 2 end
GH.Prune()
assert(#GH.Hunters(7720) == 0, "liste de Bob oubliée")
-- option coupée : rien n'est envoyé
ui.huntShare = false
assert(not GH.Send(true), "partage coupé")
print("OK : chasse partagée avec le groupe (envoi, réception, jet, départ, option)")
