-- 3.11.1 : un objet sans boss unique (Marque de Kern : monstres des ailes du Monastère) ne compte un essai
-- que si la fenêtre de butin s'ouvre dans un de ses donjons ; les essais faussés d'avant sont remis à zéro une fois.
_G.time = os.time
local handlers = {}
_G.GetItemInfo = function() return nil, nil, 3 end
_G.UnitName = function() return "Ray" end
_G.ForeverDungeonJournal_NS = { DB = {
  ["Scarlet Monastery Armory"] = { level = "20-42", bosses = { { name = "Trash", loot = { { 2262, "Mark of Kern", "Finger", 3 } } } } },
  ["Scarlet Monastery Library"] = { level = "20-42", bosses = { { name = "Trash", loot = { { 2262, "Mark of Kern", "Finger", 3 } } } } },
  ["Gnomeregan"] = { level = "29-38", bosses = { { name = "Crowd Pummeler 9-60", loot = { { 9449, "Manual Crowd Pummeler", "Two-Hand", 3 } } } } },
} }
local store = { hunt = { items = { { id = 2262, name = "Mark of Kern", attempts = 54, drops = 0 } }, kills = {}, log = {} } }
local store = { hunt = { items = {}, kills = {}, log = {} } }
local printed, toasts = {}, {}
local ns; ns = { db = { ui = {} }, N = tonumber, On = function() end, Print = function(m) printed[#printed + 1] = m end,
  CharDB = function() return store end, SlashExt = {}, HelpExt = {}, Opt = function() return false end,
  Progress = { Toast = function(title, sub) toasts[#toasts + 1] = title .. " | " .. sub end }, Fold = function(x) return tostring(x):lower() end }
_G.date = os.date
assert(loadfile("Hunt.lua"))("Dropamine", ns)
local H = ns.Hunt
-- 3.11.1 : sortie notée depuis le site (heure en base 36), rappel 15 min avant puis à l'heure, une seule fois chacun
local at = 1795800000
local b36 = function(n) local d, s = "0123456789abcdefghijklmnopqrstuvwxyz", "" repeat local r = n % 36 s = d:sub(r + 1, r + 1) .. s n = (n - r) // 36 until n == 0 return s end
ns.SlashExt.sortie("DROP-RUN1:" .. b36(at) .. "~Shadowfang_Keep~Ray")
assert(#H.Outings(at - 7200) == 1 and H.Outings(at - 7200)[1].dun == "Shadowfang Keep" and H.Outings(at - 7200)[1].org == "Ray", "sortie notée")
ns.SlashExt.sortie("DROP-RUN1:" .. b36(at) .. "~Shadowfang_Keep~Ray")
assert(#H.Outings(at - 7200) == 1, "pas de doublon")
H.CheckOutings(at - 3600) assert(#toasts == 0, "trop tôt")
H.CheckOutings(at - 600) assert(#toasts == 1 and toasts[1]:find("Shadowfang Keep dans 10 min", 1, true) and toasts[1]:find("/w Ray", 1, true), "rappel 15 min : " .. tostring(toasts[1]))
H.CheckOutings(at - 300) assert(#toasts == 1, "une seule fois")
H.CheckOutings(at + 30) assert(#toasts == 2 and toasts[2]:find("C'est l'heure", 1, true), "à l'heure")
H.CheckOutings(at + 60) assert(#toasts == 2, "une seule fois")
assert(#H.Outings(at + 4 * 3600) == 0, "oubliée 3 h après")
ns.SlashExt.sortie("n'importe quoi") assert(printed[#printed]:find("Aucune sortie", 1, true), "liste vide")
print("OK : sorties de dropamine.app rappelées en jeu")
