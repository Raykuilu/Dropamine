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
local store = { hunt = { items = { { id = 2262, name = "Mark of Kern", attempts = 0, drops = 0 } }, kills = {}, log = {} } }
local handlers = {}
local ui = { huntOn = false }
local ns; ns = { db = { ui = ui }, N = tonumber, On = function(e, f) handlers[e] = handlers[e] or {} table.insert(handlers[e], f) end, Print = function() end,
  CharDB = function() return store end, SlashExt = {}, HelpExt = {}, Progress = { Toast = function() end }, Fold = function(x) return tostring(x):lower() end,
  SetOpt = function(k, v) ui[k] = v end }
ns.Opt = function(k) return ui[k] ~= false end
local function fire(e, ...) for _, f in ipairs(handlers[e] or {}) do f(e, ...) end end
assert(loadfile("Hunt.lua"))("Dropamine", ns)
local H = ns.Hunt
_G.GetNumLootItems = function() return 0 end
_G.GetInstanceInfo = function() return "Scarlet Monastery", "party" end
-- 3.11.1 : chasse coupée (complétionnistes) : aucun essai compté, la liste reste intacte
assert(not H.On(), "réglage lu")
fire("LOOT_OPENED")
assert(H.List()[1].attempts == 0, "chasse coupée : pas d'essai")
ns.SlashExt.chasse("on")
assert(H.On(), "/drop chasse on")
fire("LOOT_OPENED")
assert(H.List()[1].attempts == 1, "chasse rallumée : l'essai compte")
ns.SlashExt.chasse("off")
assert(not H.On() and #H.List() == 1, "/drop chasse off : liste gardée")
print("OK : la chasse BiS se coupe sans toucher à la liste")
