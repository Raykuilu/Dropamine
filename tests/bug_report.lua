-- /drop bug : le rapport contient la version, le lien GitHub, le contrôle, les erreurs gardées et les addons chargés.
-- Usage, depuis la racine de l'addon : lua tests/bug_report.lua   (code de retour 1 en cas d'échec)
_G.GetAddOnMetadata = function() return "3.9.0" end
_G.GetBuildInfo = function() return "1.16.0", "60000", "Nov 20 2026", 11600 end
_G.GetLocale = function() return "frFR" end
_G.GetNumAddOns = function() return 3 end
local addons = { "Dropamine", "FlareUI", "Questie" }
_G.GetAddOnInfo = function(i) return addons[i] end
_G.IsAddOnLoaded = function(i) return i ~= 3 end
local ns = { L = setmetatable({}, { __index = function(_, k) return k end }), SlashExt = {}, HelpExt = {}, N = tonumber,
  LangCode = function() return "fr" end, Theme = { Choice = function() return "flare2" end },
  UI = { errors = { ["drops"] = "boom" } }, SafeOpen = { lastError = "ouverture : nil" } }
assert(loadfile("Check.lua"))("Dropamine", ns)
local fail = 0
local function check(ok, what) if not ok then fail = fail + 1 print("ÉCHEC :", what) end end
check(type(ns.SlashExt.bug) == "function", "/drop bug existe")
local L = ns.BugReportLines()
local all = table.concat(L, "\n")
check(all:find("Dropamine 3.9.0", 1, true), "version")
check(all:find("issues/new?template=bug_report.yml", 1, true), "lien du formulaire GitHub")
check(all:find("1.16.0", 1, true) and all:find("frFR", 1, true) and all:find("flare2", 1, true), "jeu, client, thème")
check(all:find("drops : boom", 1, true), "erreur gardée par l'addon")
check(all:find("Dropamine, FlareUI", 1, true) and not all:find("Questie", 1, true), "addons chargés seulement")
check(all:find("Résultat", 1, true), "contrôle inclus")
print(fail == 0 and "OK : rapport de bug" or (fail .. " échec(s)"))
os.exit(fail == 0 and 0 or 1)
