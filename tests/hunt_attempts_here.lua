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
local ns; ns = { db = { ui = {} }, N = tonumber, On = function(e, f) handlers[e] = handlers[e] or {} table.insert(handlers[e], f) end, Print = function() end,
  CharDB = function() return store end, SlashExt = {}, HelpExt = {}, Opt = function(k) return k == "huntOn" end, Progress = { Toast = function() end }, Fold = function(x) return tostring(x):lower() end }
local function fire(e, ...) for _, f in ipairs(handlers[e] or {}) do f(e, ...) end end
assert(loadfile("Hunt.lua"))("Dropamine", ns)
local H = ns.Hunt
local where = nil
_G.GetInstanceInfo = function() if where then return where, "party" end return "Elwynn Forest", "none" end
_G.GetNumLootItems = function() return 0 end
local function tries() return H.List()[1].attempts end
assert(tries() == 0, "les 54 essais faussés sont remis à zéro")
fire("LOOT_OPENED") fire("LOOT_OPENED")
assert(tries() == 0, "en extérieur : aucun essai")
where = "Gnomeregan" fire("LOOT_OPENED")
assert(tries() == 0, "dans un autre donjon : aucun essai")
local clock = 1000000
_G.time = function() return clock end
where = "Scarlet Monastery" fire("LOOT_OPENED") clock = clock + 600 fire("LOOT_OPENED") clock = clock + 1200 fire("LOOT_OPENED")
assert(tries() == 1, "même sortie (butins à moins d'une heure) : un seul essai")
clock = clock + 2 * 3600 fire("LOOT_OPENED")
assert(tries() == 2, "nouvelle sortie plus tard : un essai de plus")
where = "Gnomeregan" fire("LOOT_OPENED") where = "Scarlet Monastery" clock = clock + 60 fire("LOOT_OPENED")
assert(tries() == 2, "un détour ailleurs ne coupe pas la sortie en cours si on revient dans l'heure")
print("OK : essais comptés seulement dans les bons donjons")
