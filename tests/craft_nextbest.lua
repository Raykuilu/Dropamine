-- Prochain meilleur +1 : choisit la recette la plus rentable, liste ce qui manque et les monstres de la
-- vraie base (ScannerDB) qui le lâchent près du niveau du joueur.
-- Usage, depuis la racine de l'addon : lua tests/craft_nextbest.lua   (code de retour 1 en cas d'échec)
_G.time = os.time
local bags = { [2672] = 0, [2678] = 5, [769] = 1 }
_G.GetItemCount = function(id) return bags[id] or 0 end
_G.UnitLevel = function() return 12 end
_G.GetItemInfo = function() return nil end
local store = { recipes = { cooking = { list = {
  -- verte, il manque 1 viande de sanglier : faible chance de point
  { name = "Roasted Boar Meat", colors = { 0, 45, 65, 85 }, reagents = { { id = 769, count = 2, name = "Chunk of Boar Meat" } } },
  -- orange, il manque 1 viande de loup maigre : point garanti -> doit gagner
  { name = "Spiced Wolf Meat", colors = { 10, 50, 70, 90 }, reagents = { { id = 2672, count = 1, name = "Stringy Wolf Meat" }, { id = 2678, count = 1, name = "Mild Spices" } } },
  -- grise : jamais proposée
  { name = "Charred Wolf Meat", colors = { 0, 10, 15, 20 }, reagents = { { id = 2672, count = 1, name = "Stringy Wolf Meat" } } },
} } } }
local ns = { db = { ui = {} }, N = tonumber, Opt = function() return true end, CharDB = function() return store end,
  Unsecret = function(...) return ... end, Fold = function(s) return tostring(s):lower() end, GameName = function(en) return en end,
  On = function() end, SlashExt = {}, HelpExt = {} }
ns.L = setmetatable({}, { __index = function(_, k) return k end })
ns.Scanner = { RankOf = function() return 45 end, DiffColor = function() return { 1, 1, 1 } end, InCombat = function() return false end }
assert(loadfile("Data/ScannerDB.lua"))("Dropamine", ns)
assert(loadfile("Craft.lua"))("Dropamine", ns)
local C = ns.Craft
local fail = 0
local function check(ok, what) if not ok then fail = fail + 1 print("ÉCHEC :", what) end end
local nb = C.NextBest("cooking")
check(nb and nb.recipe.name == "Spiced Wolf Meat", "recette choisie : " .. tostring(nb and nb.recipe.name))
check(nb and nb.diff == "optimal", "couleur orange")
check(nb and #nb.missing == 1 and nb.missing[1].id == 2672, "un seul composant manquant (viande de loup)")
local src = C.SourcesOf(2672, 2)
check(#src >= 1, "au moins un monstre lâche la viande de loup")
for _, s in ipairs(src) do check(s.hi >= 0 and s.lo <= 15, "monstre à portée du niveau 12 : " .. s.name .. " " .. s.lo .. "-" .. s.hi) end
for _, l in ipairs(C.NextBestLines("cooking") or {}) do print(l) end
print(fail == 0 and "OK : prochain +1 conseillé" or (fail .. " échec(s)"))
os.exit(fail == 0 and 0 or 1)
