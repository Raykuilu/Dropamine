-- Collection log : tri par niveau (défaut) ou par % (« Tri : % »), et texte partagé dans le chat.
-- Usage, depuis la racine de l'addon : lua tests/collection_sort_share.lua   (code de retour 1 en cas d'échec)
_G.time = os.time
_G.GetItemInfo = function() return nil end
_G.ForeverDungeonJournal_NS = { DB = {
  ["Low Dungeon"] = { level = "15-20", bosses = { { name = "A", loot = { { 1, "Sword", "One-Hand, Sword", 3 }, { 2, "Helm", "Head, Leather", 3 } } } } },
  ["High Dungeon"] = { level = "24-28", bosses = { { name = "B", loot = { { 3, "Mace", "One-Hand, Mace", 3 }, { 4, "Boots", "Feet, Leather", 3 } } } } },
} }
local store = { hunt = { items = {}, kills = {}, log = { [3] = true, [4] = true } } }   -- High : 2/2, Low : 0/2
local ui = {}
local ns = { db = { ui = ui }, N = tonumber, On = function() end, Print = print, CharDB = function() return store end, SlashExt = {}, HelpExt = {},
  Opt = function() return true end, Fold = function(s) return s:lower() end, Progress = { Toast = function() end } }
assert(loadfile("Hunt.lua"))("Dropamine", ns)
local H = ns.Hunt
local fail = 0
local function check(ok, what) if not ok then fail = fail + 1 print("ÉCHEC :", what) end end
local function first() for _, s in ipairs(H.LogSections()) do if s.entries[1] and not s.entries[1].stat then return s.entries[1] end end end
check(first() and first().label == "Low Dungeon", "tri par niveau : Low d'abord")
ui.logSort = "pct"
check(first() and first().label == "High Dungeon", "tri par % : High (2/2) d'abord")
-- texte partagé (fonction extraite de ProgressUI.lua)
local src = io.open("ProgressUI.lua", "rb"):read("*a"):gsub("\r\n", "\n")
local body = src:match("(function PU%.CollectionShareText.-\nend)\n")
check(body ~= nil, "CollectionShareText introuvable")
if body then
  local PU = {}
  local Tr = setmetatable({}, { __index = function(_, k) return k end })
  assert(load("local PU, Tr = ... ; " .. body .. " return PU", "share", "t", _G))(PU, Tr)
  local t = PU.CollectionShareText({ label = "Shadowfang Keep", x = 12, y = 39 })
  check(t == "[Dropamine] Collection Log · Shadowfang Keep 12/39 (31 %)", "texte : " .. tostring(t))
  check(PU.CollectionShareText({ label = "Rien", x = 0, y = 0 }) == nil, "rien à partager sans total")
end
print(fail == 0 and "OK : collection log, tri et partage" or (fail .. " échec(s)"))
os.exit(fail == 0 and 0 or 1)
