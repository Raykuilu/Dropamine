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
local store = { hunt = { items = { { id = 2262, name = "Mark of Kern", attempts = 0, drops = 0 } }, kills = {}, log = {} } }
local ns; ns = { db = { ui = {} }, N = tonumber, On = function() end, Print = function() end,
  CharDB = function() return store end, SlashExt = {}, HelpExt = {}, Opt = function() return false end, Progress = { Toast = function() end }, Fold = function(x) return tostring(x):lower() end }
assert(loadfile("Hunt.lua"))("Dropamine", ns)
local H = ns.Hunt
local b36 = function(n) local d, s = "0123456789abcdefghijklmnopqrstuvwxyz", "" repeat local r = n % 36 s = d:sub(r + 1, r + 1) .. s n = (n - r) // 36 until n == 0 return s end
-- 3.11.1 : code de dropamine.app (« Ma chasse ») -> objets ajoutés à la chasse, sans doublon
local a, d, full = H.ImportCode("DROP-CH1:" .. b36(9449) .. "." .. b36(2262))
assert(a == 1 and d == 1 and not full, "un ajouté, un déjà suivi")
assert(#H.List() == 2 and H.List()[2].id == 9449, "Manual Crowd Pummeler ajouté")
assert(H.ImportCode("n'importe quoi") == nil, "code inconnu refusé")
local a2 = H.ImportCode("  drop-ch1:zz") assert(a2 == nil, "préfixe exact exigé")
local a3 = H.ImportCode("DROP-CH1:" .. b36(9449):upper()) assert(a3 == 0, "majuscules acceptées, doublon ignoré")
print("OK : import des listes de dropamine.app")
