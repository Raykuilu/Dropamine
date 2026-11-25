-- 3.11.0 : export Hiscores (/drop hiscores) : ligne complète, somme de contrôle, champs nettoyés.
-- Usage, depuis la racine de l'addon : lua tests/hiscores.lua   (code de retour 1 en cas d'échec)
_G.UnitName = function() return "Ray" end
_G.UnitLevel = function() return 36 end
_G.GetGuildInfo = function() return "Everybody;Knows" end   -- un « ; » doit être neutralisé
_G.GetCurrentRegion = function() return 3 end
_G.time = function() return 1795600000 end
local shown
local ns = { VERSION = "3.11.0", N = tonumber }
ns.L = setmetatable({}, { __index = function(_, k) return k end })
ns.SkillsForCharSheet = function()
  return { { id = 393, name = "Dépeçage", rank = 223 }, { id = 129, name = "Secourisme", rank = 208 } },
    { { id = 136, name = "Bâtons", rank = 176 }, { id = 54, name = "Masses", rank = 102 } },
    { id = 95, name = "Défense", rank = 177 }
end
ns.DebugWindow = { Show = function(lines) shown = lines end }
assert(loadfile("Hiscores.lua"))("Dropamine", ns)
local HS = ns.Hiscores
local fail = 0
local function check(ok, what) if not ok then fail = fail + 1 print("ÉCHEC :", what) end end

local line, info = HS.Build()
check(line and line:sub(1, #HS.PREFIX) == HS.PREFIX, "la ligne commence par le préfixe")
check(info.weapons == 278 and info.defense == 177 and info.count == 2, "armes 278 (2), Défense 177")
check(line:find(HS.PREFIX .. "n=Ray;", 1, true) and line:find(";l=36;", 1, true) and line:find(";r=eu;", 1, true), "nom, niveau, région")
check(line:find(";g=Everybody Knows;", 1, true), "guilde nettoyée (pas de « ; » parasite)")
check(line:find(";w=136=176,54=102;", 1, true), "armes par identifiant")
check(line:find(";p=393=223,129=208;", 1, true), "métiers par identifiant")
local body, sum = line:sub(#HS.PREFIX + 1):match("^(.*);c=(%x+)$")
check(body and HS.Checksum(body) == sum, "somme de contrôle cohérente")
check(HS.Checksum(body .. "x") ~= sum, "une ligne modifiée change la somme")
HS.Open()
check(shown and shown[1] == line, "la fenêtre de copie affiche la ligne en premier")

ns.SkillsForCharSheet = function() return {}, {}, nil end
local none, why = HS.Build()
check(none == nil and type(why) == "string", "sans compétences lues : pas de ligne, un message")

if fail > 0 then os.exit(1) end
print("OK : export Hiscores")
