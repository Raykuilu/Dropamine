-- 3.12.0 : 7 langues. Seule la langue du client (ou celle des réglages) est remplie ; les autres sont oubliées.
-- Chaque fichier de langue a toutes les clés de l'anglais, et les formats (%s, %d…) passent string.format.
local LUA_LOCALES = { "deDE", "esES", "itIT", "ptBR", "ruRU" }
local function load(client, setting)
  _G.GetLocale = function() return client end
  _G.DropamineDB = setting and { ui = { lang = setting } } or nil
  local handlers = {}
  _G.CreateFrame = function() return { RegisterEvent = function() end, UnregisterAllEvents = function() end,
    SetScript = function(self, _, f) handlers.ev = f end } end
  local ns = {}
  for _, f in ipairs({ "Locales/Locale.lua", "Locales/enUS.lua", "Locales/frFR.lua" }) do assert(loadfile(f))("Dropamine", ns) end
  for _, l in ipairs(LUA_LOCALES) do assert(loadfile("Locales/" .. l .. ".lua"))("Dropamine", ns) end
  if handlers.ev then handlers.ev({ UnregisterAllEvents = function() end }, "ADDON_LOADED", "Dropamine") end
  return ns
end
-- client allemand : allemand rempli, les autres jamais
local ns = load("deDE")
assert(ns.LangCode() == "de", "langue du client")
assert(ns.L["Langue"] ~= "Langue" and ns.L["Langue"] ~= ns.LOCALES.enUS["Langue"], "texte allemand : " .. tostring(ns.L["Langue"]))
for _, l in ipairs({ "esES", "itIT", "ptBR", "ruRU" }) do assert(not ns.LOCALES[l] or next(ns.LOCALES[l]) == nil, l .. " ne doit pas être rempli") end
assert(next(ns.LOCALE_LOADERS) == nil, "chargeurs oubliés après ADDON_LOADED")
assert(ns.CatalogDisplayName({ id = "skinning", name = "Dépeçage" }) == ns.LOCALES.deDE["@skill:skinning"], "nom de compétence allemand")
-- client anglais, réglage russe : le russe est rempli au chargement des réglages
ns = load("enUS", "ru")
assert(ns.LangCode() == "ru" and ns.LOCALES.ruRU and next(ns.LOCALES.ruRU), "réglage russe sur client anglais")
-- client français : rien à remplir
ns = load("frFR")
assert(ns.L["Langue"] == "Langue", "français : texte source")
-- client coréen (inconnu) : anglais
ns = load("koKR")
assert(ns.LangCode() == "en", "langue inconnue → anglais")
-- toutes les clés, et les formats utilisables
local en = load("enUS").LOCALES.enUS
local fmtOk = function(s, ref)
  local args = {}
  for spec in tostring(ref):gmatch("%%[%-%d%.]*([sdfxXg])") do args[#args + 1] = (spec == "s") and "x" or 1 end
  if #args == 0 then return true end
  return pcall(string.format, s, (table.unpack or unpack)(args))
end
for _, l in ipairs(LUA_LOCALES) do
  local code = ({ deDE = "de", esES = "es", itIT = "it", ptBR = "pt", ruRU = "ru" })[l]
  local t = load("enUS", code).LOCALES[l]
  local miss, bad = 0, 0
  for k, v in pairs(en) do
    if t[k] == nil then miss = miss + 1 elseif fmtOk(v, v) and not fmtOk(t[k], v) then bad = bad + 1 print(l, "format", k) end
  end
  assert(miss == 0, l .. " : " .. miss .. " textes manquants")
  assert(bad == 0, l .. " : " .. bad .. " formats cassés")
end
print("OK : 7 langues, seule la langue utilisée remplie, toutes les clés et formats")
