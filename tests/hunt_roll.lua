-- Objet recherché au jet de groupe : cadre doré sur la bonne fenêtre, un seul toast par jet,
-- rien sur un objet non suivi, rien si l'option est coupée.
-- Usage, depuis la racine de l'addon : lua tests/hunt_roll.lua   (code de retour 1 en cas d'échec)
_G.time = os.time
local function Obj()
  local o = {}
  return setmetatable(o, { __index = function(t, k)
    if k == "IsPlaying" then return function() return false end end
    if k == "IsShown" then return function(s) return s._shown ~= false end end
    return function(s, ...) if k == "Show" then s._shown = true elseif k == "Hide" then s._shown = false end
      if k:find("^Create") then return Obj() end end
  end })
end
_G.CreateFrame = function() local f = Obj() f._shown = true return f end
_G.ForeverDungeonJournal_NS = { DB = {} }
local links = { [11] = "|cffa335ee|Hitem:1001::::::::|h[Wanted Sword]|h|r", [12] = "|cff0070dd|Hitem:2002::::::::|h[Other Helm]|h|r" }
_G.GetLootRollItemLink = function(rid) return links[rid] end
_G.GroupLootFrame1 = Obj() GroupLootFrame1.rollID = 11 GroupLootFrame1._shown = true
_G.GroupLootFrame2 = Obj() GroupLootFrame2.rollID = 12 GroupLootFrame2._shown = true
local store = { hunt = { items = { { id = 1001, name = "Wanted Sword" } }, kills = {}, log = {} } }
local ui = {}
local toasts = 0
local ns = { db = { ui = ui }, N = tonumber, On = function() end, Print = print, CharDB = function() return store end, SlashExt = {}, HelpExt = {},
  Opt = function(k) return ui[k] ~= false end, Fold = function(s) return s:lower() end,
  Progress = { Toast = function(t) toasts = toasts + 1 print("TOAST", t) return Obj() end } }
assert(loadfile("Hunt.lua"))("Dropamine", ns)
local H = ns.Hunt
local fail = 0
local function check(ok, what) if not ok then fail = fail + 1 print("ÉCHEC :", what) end end
check(H.IsWanted(1001) and not H.IsWanted(2002), "IsWanted")
H.ScanRolls()
H.ScanRolls()   -- le même jet ne redonne pas de toast
check(toasts == 1, "un seul toast pour le jet suivi (vu " .. toasts .. ")")
-- option coupée : aucun nouveau toast
ui.huntRoll = false
GroupLootFrame1.rollID = 13 links[13] = links[11]
H.ScanRolls()
check(toasts == 1, "option coupée : pas de toast")
print(fail == 0 and "OK : objet recherché repéré au jet de groupe" or (fail .. " échec(s)"))
os.exit(fail == 0 and 0 or 1)
