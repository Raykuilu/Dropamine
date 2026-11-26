-- 3.11.2 : sur Forever, les liens du chat ont une couleur de qualité nommée (« |cnIQ4: ») au lieu de « |cffa335ee ».
-- Avant, aucun butin du chat n'était reconnu : les boss tués ne comptaient pas (essais de chasse à 0), ni les objets reçus.
local clock = 1000
_G.time = function() return clock end
local handlers = {}
_G.LOOT_ITEM_SELF = "You receive loot: %s."
_G.LOOT_ITEM = "%s receives loot: %s."
_G.GetItemInfo = function() return nil, nil, 3 end
_G.UnitName = function() return "Ray" end
_G.ForeverDungeonJournal_NS = { DB = { ["Gnomeregan"] = { level = "29-38", bosses = {
  { name = "Crowd Pummeler 9-60", loot = { { 9449, "Manual Crowd Pummeler", "Two-Hand", 3 }, { 9450, "Gnomebot Operating Boots", "Feet", 3 } } } } } } }
local store = { hunt = { items = { { id = 9449, name = "Manual Crowd Pummeler", bossKey = "Gnomeregan|Crowd Pummeler 9-60", baseKills = 0, attempts = 0, drops = 0 } },
  kills = {}, log = {}, attemptsFix311 = true } }
local ui = {}
local ns; ns = { db = { ui = ui }, N = tonumber, On = function(e, f) handlers[e] = handlers[e] or {} table.insert(handlers[e], f) end, Print = function() end,
  CharDB = function() return store end, SlashExt = {}, HelpExt = {}, Progress = { Toast = function() return {} end }, Fold = function(x) return tostring(x):lower() end,
  SetOpt = function(k, v) ui[k] = v end }
ns.Opt = function(k) return ui[k] ~= false end
local function fire(e, ...) for _, f in ipairs(handlers[e] or {}) do f(e, ...) end end
assert(loadfile("Hunt.lua"))("Dropamine", ns)
local H = ns.Hunt
local boots = "|cnIQ3:|Hitem:9450::::::::36:1484::1::1:28:6326:::::|h[Gnomebot Operating Boots]|h|r"
-- run 1 : les bottes tombent pour un autre joueur → le boss est mort, un essai
fire("CHAT_MSG_LOOT", "Bob receives loot: " .. boots .. ".", "Bob")
assert(store.hunt.kills["Gnomeregan|Crowd Pummeler 9-60"] == 1, "lien |cnIQ3: reconnu : boss compté")
assert(H.List()[1].attempts == 1, "un essai")
-- run 2, plus tard
clock = clock + 1800
fire("CHAT_MSG_LOOT", "Bob receives loot: " .. boots .. ".", "Bob")
assert(H.List()[1].attempts == 2, "deux essais")
-- run 3 : le Roueur tombe pour moi → trouvé, après 3 essais
clock = clock + 1800
fire("CHAT_MSG_LOOT", "You receive loot: |cnIQ3:|Hitem:9449::::::::36:1484::1::1:28:6326:::::|h[Manual Crowd Pummeler]|h|r.", "Ray")
local it = H.List()[1]
assert(it.drops == 1, "objet reçu reconnu avec le lien de Forever")
assert(it.attempts == 3, "essais gardés après l'obtention : " .. tostring(it.attempts))
-- l'ancien format marche toujours
clock = clock + 1800
fire("CHAT_MSG_LOOT", "Bob receives loot: |cff0070dd|Hitem:9450::::::::|h[Gnomebot Operating Boots]|h|r.", "Bob")
assert(store.hunt.kills["Gnomeregan|Crowd Pummeler 9-60"] == 4, "ancien format")
print("OK : butin du chat reconnu avec les liens de Forever (|cnIQ)")
