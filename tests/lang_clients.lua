-- 3.12.1 : garde-fou des langues. Pour chaque client (en, fr, de, es, it, pt, ru) :
--  * les métiers et compétences sont retrouvés par leur ligne de compétence, quel que soit le nom affiché par le client ;
--  * les noms des cases sont dans la langue de l'addon ;
--  * client passé d'une langue à une autre : les rangs mémorisés sous l'ancien nom sont oubliés (la case ne reste pas figée),
--    et les rangs vraiment masqués (en-tête replié) restent gardés.
-- Si une future mise à jour casse un de ces points, ce test échoue.
local CLIENTS = {
  enUS = { cooking = "Cooking", skinning = "Skinning", firstaid = "First Aid", leatherworking = "Leatherworking", feral = "Feral Combat" },
  frFR = { cooking = "Cuisine", skinning = "Dépeçage", firstaid = "Secourisme", leatherworking = "Travail du cuir", feral = "Combat farouche" },
  deDE = { cooking = "Kochkunst", skinning = "Kürschnerei", firstaid = "Erste Hilfe", leatherworking = "Lederverarbeitung", feral = "Wilder Kampf" },
  esES = { cooking = "Cocina", skinning = "Desuello", firstaid = "Primeros auxilios", leatherworking = "Peletería", feral = "Combate feral" },
  itIT = { cooking = "Cucina", skinning = "Scuoiatura", firstaid = "Primo Soccorso", leatherworking = "Conciatura", feral = "Combattimento Ferino" },
  ptBR = { cooking = "Culinária", skinning = "Esfolamento", firstaid = "Primeiros Socorros", leatherworking = "Couraria", feral = "Combate Feral" },
  ruRU = { cooking = "Кулинария", skinning = "Снятие шкур", firstaid = "Первая помощь", leatherworking = "Кожевничество", feral = "Сила зверя" },
}
local LINE = { cooking = 185, skinning = 393, firstaid = 129, leatherworking = 165, feral = 134 }

local function Boot(client)
  _G.GetLocale = function() return client end
  _G.DropamineDB = nil
  local ev
  _G.CreateFrame = function() return { RegisterEvent = function() end, UnregisterAllEvents = function() end,
    SetScript = function(_, _, f) ev = f end } end
  local store = {}
  local ns = { N = function(v) return tonumber(v) end, CharDB = function() return store end }
  for _, f in ipairs({ "Locales/Locale.lua", "Locales/enUS.lua", "Locales/frFR.lua", "Locales/deDE.lua", "Locales/esES.lua",
    "Locales/itIT.lua", "Locales/ptBR.lua", "Locales/ruRU.lua", "Catalog.lua" }) do
    assert(loadfile(f))("Dropamine", ns)
  end
  if ev then ev({ UnregisterAllEvents = function() end }, "ADDON_LOADED", "Dropamine") end
  -- MergeRankCache, prise telle quelle dans Core.lua
  local src = io.open("Core.lua"):read("*a")
  local s = src:find("function ns%.RankCache%(")
  local e = src:find("\nfunction ns%.CollectLiveSkills%(", s)
  assert(load("local ns = ...\n" .. src:sub(s, e)))(ns)
  return ns, store
end

for client, names in pairs(CLIENTS) do
  local ns = Boot(client)
  for id, nm in pairs(names) do
    -- la ligne retrouve la case, même quand le nom du client n'est connu d'aucun alias
    local e = ns.LookupCatalog(nm, LINE[id])
    assert(e and e.id == id, client .. " : " .. nm .. " → " .. tostring(e and e.id) .. " (attendu " .. id .. ")")
  end
  -- nom de la case dans la langue de l'addon (auto = langue du client)
  local disp = ns.CatalogDisplayName(ns.CATALOG_BY_ID.cooking)
  assert(type(disp) == "string" and disp ~= "", client .. " : nom affiché")
  if client == "frFR" then assert(disp == "Cuisine", "français : " .. disp) end
  if client == "enUS" then assert(disp == "Cooking", "anglais : " .. disp) end
end

-- client passé du français à l'anglais : « Cuisine » 161 mémorisé, « Cooking » 198 lu
do
  local ns, store = Boot("enUS")
  store.rankCache = {
    [ns.Fold("Cuisine")] = { name = "Cuisine", rank = 161, max = 225, headerName = "Compétences secondaires", skillID = 185 },
    [ns.Fold("Pêche")] = { name = "Pêche", rank = 137, max = 225, headerName = "Compétences secondaires" },          -- sans ligne : retrouvée par le nom traduit
    [ns.Fold("Equitation")] = { name = "Equitation", rank = 75, max = 75, headerName = "Secondary Skills", skillID = 762 }, -- masquée (en-tête replié) : gardée
  }
  ns.openHeaders = {}
  local live = { { name = "Cooking", rank = 198, max = 225, headerName = "Secondary Skills", skillID = 185 },
    { name = "Fishing", rank = 140, max = 225, headerName = "Secondary Skills", skillID = 356 } }
  ns.MergeRankCache(live, "C_SkillInfo")
  assert(store.rankCache[ns.Fold("Cuisine")] == nil, "ancien nom français oublié (même ligne)")
  assert(store.rankCache[ns.Fold("Pêche")] == nil, "ancien nom français oublié (nom traduit)")
  assert(store.rankCache[ns.Fold("Equitation")], "compétence masquée gardée")
  local cookingRows = 0
  for _, s in ipairs(live) do if s.skillID == 185 then cookingRows = cookingRows + 1 assert(s.rank == 198, "cuisine : la valeur lue") end end
  assert(cookingRows == 1, "une seule ligne Cuisine/Cooking")
end
-- messages du jeu (montée de compétence, infobulles) : le nom du client seul suffit après une lecture
do
  local ns = Boot("deDE")
  ns.LINE_BY_NAME = { [ns.Fold("Kochkunst")] = 185 }
  local e = ns.LookupCatalog("Kochkunst")
  assert(e and e.id == "cooking", "Kochkunst sans ligne → Cuisine")
end
-- deux lignes pour la même compétence (Forever : combat farouche 134 à 1, 3014 à 179) : la plus haute
do
  local ns = Boot("enUS")
  local src = io.open("Core.lua"):read("*a")
  local s0 = src:find("function ns%.PickLine%(")
  local e0 = src:find("\nend\n", s0)
  assert(load("local ns = ...\n" .. src:sub(s0, e0 + 4)))(ns)
  local byLine = { [134] = { name = "Feral Combat", rank = 1 }, [3014] = { name = "Feral Combat", rank = 179 } }
  assert(ns.PickLine(byLine, ns.SKILL_LINES.feral).rank == 179, "combat farouche : la ligne à 179")
  assert(ns.PickLine({ [3014] = { rank = 5 } }, { 134, 3014 }).rank == 5, "une seule ligne lue")
end
print("OK : 7 langues de client, compétences par ligne, changement de langue sans case figée")
