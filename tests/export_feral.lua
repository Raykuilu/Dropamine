-- 3.13.0 : l'export /drop hiscores lit les compétences sans la fenêtre ouverte.
-- Forever donne combat farouche sur 2 lignes (134 à 1, 3014 à 184) : l'export doit garder 184, pas la première vue.
_G.GetLocale = function() return "enUS" end
_G.DropamineDB = nil
local ev
_G.CreateFrame = function() return { RegisterEvent = function() end, UnregisterAllEvents = function() end,
  SetScript = function(_, _, f) ev = f end } end
local ns = { N = function(v) return tonumber(v) end, CharDB = function() return {} end }
for _, f in ipairs({ "Locales/Locale.lua", "Locales/enUS.lua", "Locales/frFR.lua", "Catalog.lua" }) do
  assert(loadfile(f))("Dropamine", ns)
end
if ev then ev({ UnregisterAllEvents = function() end }, "ADDON_LOADED", "Dropamine") end
local src = io.open("Core.lua"):read("*a")
local function chunk(from, to)
  local s = src:find(from) local e = src:find(to, s)
  assert(s and e, from) return src:sub(s, e - 1)
end
assert(load("local ns = ...\n" .. chunk("function ns%.CatalogById%(", "\nfunction ns%.LiveForEntry%(")))(ns)
ns.IsLanguageOrArmorJunk = function() return false end
ns.CollectLiveSkills = function()
  return {
    { name = "Feral Combat", rank = 1, max = 185, skillID = 134, headerName = "Weapon Skills" },
    { name = "Feral Combat", rank = 184, max = 185, skillID = 3014, headerName = "Weapon Skills" },
    { name = "Staves", rank = 110, max = 185, skillID = 136, headerName = "Weapon Skills" },
    { name = "Defense", rank = 185, max = 185, skillID = 95, headerName = "Weapon Skills" },
    { name = "Skinning", rank = 1, max = 300, skillID = 393, headerName = "Professions" },
    { name = "Skinning", rank = 226, max = 300, skillID = 2947, headerName = "Professions" },
  }
end
assert(load("local ns, Call = ...\n" .. chunk("local function SheetRec%(", "\nfunction ns%.CaptureCharSheet%(")))(ns, function(f, ...) return f(...) end)

local profs, weapons, defense = ns.SkillsForCharSheet(nil)
local W, P = {}, {}
for _, w in ipairs(weapons) do assert(not W[w.id], "arme en double : " .. tostring(w.id)) W[w.id] = w.rank end
for _, p in ipairs(profs) do assert(not P[p.id], "métier en double : " .. tostring(p.id)) P[p.id] = p.rank end
assert(W.feral == 184, "combat farouche exporté : " .. tostring(W.feral))
assert(W.staves == 110, "bâtons : " .. tostring(W.staves))
assert(P.skinning == 226, "dépeçage exporté : " .. tostring(P.skinning))
assert(defense and defense.rank == 185, "défense")
print("OK : export sans fenêtre, combat farouche 184 et dépeçage 226 (la ligne la plus haute)")
