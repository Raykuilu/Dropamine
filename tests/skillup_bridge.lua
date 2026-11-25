-- 3.10.0 : lien avec SkillUp Forever (faux SkillUp) : absent, en chargement, infobulle, toast unique
-- seulement pour une étape où il faut se déplacer, Alt+clic.
-- Usage, depuis la racine de l'addon : lua tests/skillup_bridge.lua   (code de retour 1 en cas d'échec)
_G.time = os.time
_G.C_Timer = { After = function(_, fn) fn() end }
local combat = false
local ui = {}
local printed = {}
local ns = { db = { ui = ui }, N = tonumber,
  Opt = function(k) return ui[k] ~= false end, OptOff = function(k) return ui[k] == true end,
  InCombat = function() return combat end, Print = function(m) printed[#printed + 1] = m end, On = function() end }
ns.L = setmetatable({}, { __index = function(_, k) return k end })
local toasts = {}
ns.UI = { SpawnDrop = function(_, icon, title, sub) toasts[#toasts + 1] = { title, sub } return true end }
ns.Options = { EXTRA = {}, EXTRA_HOME = {}, GROUPS = {}, MAP = { prof = {} }, TEST = {} }
assert(loadfile("SkillUp.lua"))("Dropamine", ns)
local SU = ns.SkillUp
local fail = 0
local function check(ok, what) if not ok then fail = fail + 1 print("ÉCHEC :", what) end end

-- absent
check(SU.Lines("tailoring") == nil, "sans SkillUp : rien")
check(SU.OnAltClick({ id = "tailoring" }) == false, "sans SkillUp : l'Alt+clic reste un clic normal")
check(ns.Options.GROUPS.grpSkillUp and ns.Options.EXTRA_HOME.skillupLink == "prof", "réglages rangés dans Métiers")

-- faux SkillUp
local loading, calls, navigated = true, 0, nil
local steps = { { kind = "craft", text = "Craft 12 Bolt of Linen", detail = "75 to 87", spellID = 2963, nav = false },
  { kind = "train", text = "Train Expert", detail = "Trainer, Stormwind · 5g", nav = true } }
local subscriber
_G.SkillUpForever = { API = { version = 1,
  Professions = function()
    calls = calls + 1
    if loading then return nil, "loading" end
    return { { name = "Tailoring", skillLineID = 197, icon = 1, steps = steps } }
  end,
  Subscribe = function(fn) subscriber = fn return function() end end,
  Navigate = function(id, i) navigated = { id, i } return true end } }

check(SU.Lines("tailoring") == nil, "SkillUp en chargement : rien")
check(subscriber ~= nil, "abonné aux changements")
loading = false
subscriber({ professions = true })
local L = SU.Lines("tailoring")
check(L and L[1]:find("Craft 12 Bolt of Linen") and L[3]:find("Train Expert"), "infobulle : étape en cours et suivante")
check(#toasts == 0, "premier passage : pas de toast")
check(printed[1] and printed[1]:find("SkillUp détecté"), "message de bienvenue une fois")

-- lecture paresseuse : pas de nouvel appel sans changement signalé
local before = calls
SU.Lines("tailoring") SU.Lines("tailoring")
check(calls == before, "pas de relecture sans changement")

-- le compteur de fabrication descend : pas de toast
steps[1] = { kind = "craft", text = "Craft 11 Bolt of Linen", spellID = 2963, nav = false }
subscriber({ professions = true })
check(#toasts == 0, "même fabrication : pas de toast")

-- l'étape devient « apprendre » : un toast
steps[1] = { kind = "train", text = "Train Expert", detail = "Trainer, Stormwind · 5g", nav = true }
subscriber({ professions = true })
check(#toasts == 1 and toasts[1][2] == "Train Expert", "étape où il faut se déplacer : un toast")
subscriber({ professions = true })
check(#toasts == 1, "même étape : pas de second toast")

-- en combat : pas de lecture, rattrapé après
combat = true
steps[1] = { kind = "buy", text = "Buy 20 Silk Cloth", itemID = 4306, nav = true }
local c0 = calls
subscriber({ professions = true })
check(calls == c0 and #toasts == 1, "en combat : rien lu, pas de toast")
combat = false

-- toasts coupés
ui.skillupToasts = false
steps[1] = { kind = "train", text = "Train Artisan", nav = true }
subscriber({ professions = true })
check(#toasts == 1, "toasts coupés : rien")
ui.skillupToasts = nil

-- Alt+clic
check(SU.OnAltClick({ id = "tailoring" }) == true and navigated and navigated[1] == 197 and navigated[2] == 1, "Alt+clic : point posé")
check(SU.OnAltClick({ id = "swords" }) == false, "case non métier : clic normal")

-- lien coupé
ui.skillupLink = false
check(SU.Lines("tailoring") == nil, "lien coupé : rien dans l'infobulle")

print(fail == 0 and "OK : lien avec SkillUp" or (fail .. " échec(s)"))
os.exit(fail == 0 and 0 or 1)
