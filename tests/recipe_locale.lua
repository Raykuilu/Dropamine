-- 3.12.1 : listes de recettes lues sur un client français, client passé en anglais : oubliées (nom reconnu dans la base),
-- et une liste relue fusionne par numéro de recette (le nom anglais remplace le français, pas de doublon)
local store = { recipes = { cooking = { list = { { name = "Feu de camp basique", recipeID = 818 } } } }, recipesLocale = "enUS" }
local ns = { N = tonumber, CharDB = function() return store end, On = function() end, Fold = function(s) return tostring(s):lower() end,
  ClientLocale = function() return "enUS" end, ClientLang = function() return "en" end,
  Links = { DB = function() return { byName = { ["feu de camp basique"] = { en = "Basic Campfire", fr = "Feu de camp basique" }, ["basic campfire"] = { en = "Basic Campfire", fr = "Feu de camp basique" } } } end },
  Scanner = {}, Opt = function() return true end, L = setmetatable({}, { __index = function(_, k) return k end }) }
local Craft = {}
ns.Craft = Craft
-- on teste seulement les deux fonctions : chargées depuis Craft.lua
local src = io.open("Craft.lua"):read("*a")
local function grab(name)
  local s = src:find("function Craft%." .. name .. "%(")
  local e = src:find("\nfunction ", s + 10)
  return src:sub(s, e)
end
local chunk = "local ns, Craft = ...\nlocal function N(v) return ns.N(v) end\n" .. grab("Merge") .. "\n" .. grab("CheckLocale")
assert(load(chunk))(ns, Craft)
Craft.CheckLocale()
assert(next(store.recipes) == nil, "liste française oubliée sur le client anglais (même marquée par 3.12.0)")
assert(store.recipesLocale == "enUS" and store.recipesLocaleV == 2, "langue retenue")
-- fusion par numéro
local out = Craft.Merge({ { name = "Feu de camp basique", recipeID = 818 } }, { { name = "Basic Campfire", recipeID = 818 } })
assert(#out == 1 and out[1].name == "Basic Campfire", "même numéro : remplacé, pas doublé")
print("OK : recettes d'une autre langue oubliées, fusion par numéro")
