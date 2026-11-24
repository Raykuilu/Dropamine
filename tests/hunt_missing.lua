-- Recettes manquantes (Cuisine) et résumé des créatures par niveau, avec la vraie base ScannerDB.
-- Usage, depuis la racine de l'addon : texlua tests/hunt_missing.lua
_G.time = os.time
_G.GetItemInfo = function() return nil end
local store = { recipes = { cooking = { list = { { name = "Viande de loup épicée" }, { name = "Steak de coyote" } } } } }
local ns
ns = { db = { ui = {} }, N = tonumber, On = function() end, Print = print, CharDB = function() return store end, SlashExt = {}, HelpExt = {},
  Opt = function() return true end, Fold = function(s) return (tostring(s):lower()) end, GameName = function(en, fr) return fr end,
  Progress = { Toast = function() end } }
ns.L = setmetatable({}, { __index = function(_, k) return k end })
assert(loadfile("Data/ScannerDB.lua"))("Dropamine", ns)
assert(loadfile("Hunt.lua"))("Dropamine", ns)
local H = ns.Hunt
local miss = H.MissingRecipes("cooking", "c")
print("recettes de cuisine manquantes :", #miss, "(attendu 130 - 2 connues)")
for i = 1, 4 do print(miss[i].lvl, miss[i].name, miss[i].src) end
print("sans lecture :", select(2, (function() store.recipes = nil return H.MissingRecipes("cooking", "c") end)()))
ns.Scanner = { DB = function() return { creatures = { [3] = { name = "x" } } } end }
for _, b in ipairs(H.LevelSummary("creatures")) do print("niv", b.lo .. "-" .. b.hi, b.x .. "/" .. b.y) end

-- Lignes « Recettes » : totaux exacts (Cuisine, Secourisme) et approximatifs (autres métiers)
store.recipes = { cooking = { list = { { name = "a" } } }, blacksmithing = { list = { { name = "b" }, { name = "c" } } } }
ns.Scanner = { DB = function() return { creatures = {}, nodes = {} } end }
ns.ScannerDB.meta = ns.ScannerDB.meta or {}
for _, r in ipairs(H.CollectionRows()) do
  if tostring(r.label):find("^Recettes ") then print(r.label, r.x .. " / " .. "" .. r.y) end
end
