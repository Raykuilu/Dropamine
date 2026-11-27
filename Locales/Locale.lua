-- Dropamine — langue des textes (3.5.19).
-- Clés = texte français d'origine (le français reste mot pour mot) ;
-- Locales/enUS.lua donne l'anglais. Choix : DropamineDB.ui.lang = "auto" | "en" | "fr" | "de" | "es" | "it" | "pt" | "ru".
-- auto : la langue du client si l'addon la connaît, anglais sinon.
-- 3.12.0 : allemand, espagnol, italien, portugais, russe. Chaque fichier de langue s'enregistre (ns.DefineLocale) sans se remplir ;
-- seule la langue utilisée est remplie (celle du client tout de suite, celle des réglages au chargement de DropamineDB),
-- les autres sont oubliées : elles n'occupent pas de mémoire. Texte absent d'une langue : l'anglais, puis le français.
-- Rien n'est mis en cache dans ns.L : le choix peut changer en cours de partie.

local ADDON, ns = ...
if type(ns) ~= "table" then
  ns = _G.Dropamine or {}
  _G.Dropamine = ns
  ADDON = ADDON or "Dropamine"
end

ns.LOCALES = ns.LOCALES or {}
ns.LOCALES.enUS = ns.LOCALES.enUS or {}
ns.LOCALES.frFR = ns.LOCALES.frFR or {}
local EN, FR = ns.LOCALES.enUS, ns.LOCALES.frFR

-- langue de l'addon ↔ code du client
ns.LANGS = { "en", "fr", "de", "es", "it", "pt", "ru" }
local LANG_OF_CLIENT = { frFR = "fr", deDE = "de", esES = "es", esMX = "es", itIT = "it", ptBR = "pt", ptPT = "pt", ruRU = "ru" }
local LOCALE_OF = { en = "enUS", fr = "frFR", de = "deDE", es = "esES", it = "itIT", pt = "ptBR", ru = "ruRU" }
ns.LOCALE_OF = LOCALE_OF
local KNOWN = {} for _, c in ipairs(ns.LANGS) do KNOWN[c] = true end
local clientLang
function ns.ClientLocale()
  local ok, loc = false, nil
  if type(GetLocale) == "function" then ok, loc = pcall(GetLocale) end
  return (ok and type(loc) == "string") and loc or "enUS"
end
function ns.ClientLang()
  if not clientLang then clientLang = LANG_OF_CLIENT[ns.ClientLocale()] or "en" end
  return clientLang
end

-- Réglage enregistré (avant ADDON_LOADED : DropamineDB absent → « auto »).
function ns.LangSetting()
  local db = rawget(_G, "DropamineDB")
  local ui = type(db) == "table" and rawget(db, "ui") or nil
  local v = type(ui) == "table" and rawget(ui, "lang") or nil
  if KNOWN[v] then return v end
  return "auto"
end
function ns.LangCode()
  local s = ns.LangSetting()
  if s == "auto" then return ns.ClientLang() end
  return s
end
function ns.IsFrench() return ns.LangCode() == "fr" end
function ns.IsEnglish() return ns.LangCode() == "en" end
-- virgule décimale partout sauf en anglais
function ns.DecimalComma() return ns.LangCode() ~= "en" end
-- table de la langue affichée (nil : français, la langue source)
local function Table()
  local c = ns.LangCode()
  if c == "fr" then return nil end
  return ns.LOCALES[LOCALE_OF[c]] or EN
end
ns.LangTable = Table

-- fichiers de langue : enregistrés, remplis seulement si besoin
ns.LOCALE_LOADERS = ns.LOCALE_LOADERS or {}
function ns.LoadLocale(loc)
  local fn = ns.LOCALE_LOADERS[loc]
  if type(fn) ~= "function" then return end
  ns.LOCALE_LOADERS[loc] = false
  ns.LOCALES[loc] = ns.LOCALES[loc] or {}
  local ok, err = pcall(fn, ns.LOCALES[loc])
  if not ok and ns.Print then ns.Print("locale " .. loc .. " : " .. tostring(err)) end
end
function ns.DefineLocale(loc, fn)
  ns.LOCALE_LOADERS[loc] = fn
  if LOCALE_OF[LANG_OF_CLIENT[ns.ClientLocale()] or ""] == loc then ns.LoadLocale(loc) end
end
-- réglages chargés : la langue choisie est remplie, les autres oubliées (/reload pour en changer)
function ns.FinishLocales()
  ns.LoadLocale(LOCALE_OF[ns.LangCode()] or "")
  for k in pairs(ns.LOCALE_LOADERS) do ns.LOCALE_LOADERS[k] = nil end
end
do
  local f = type(CreateFrame) == "function" and CreateFrame("Frame") or nil
  if f then
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(self, _, name)
      if name ~= ADDON then return end
      self:UnregisterAllEvents()
      ns.FinishLocales()
    end)
  end
end
-- nom d'une liste (compétences, classes, zones…) : « @<sorte>:<code> » dans la langue affichée, sinon l'anglais donné
function ns.LocName(kind, code, en, fr)
  local t = Table()
  if not t then return fr or en end
  local v = t["@" .. kind .. ":" .. tostring(code)]
  if v == nil and t ~= EN then v = EN["@" .. kind .. ":" .. tostring(code)] end
  return v or en or fr
end

ns.L = setmetatable({}, {
  __index = function(_, k)
    if type(k) ~= "string" then return k end
    local t = Table()
    if t then
      local v = t[k]
      if v == nil and t ~= EN then v = EN[k] end
      if v ~= nil then return v end
    else
      local v = FR[k]
      if v ~= nil then return v end
    end
    return k
  end,
  __newindex = function() end,   -- table en lecture seule
})

-- Noms affichés des compétences du catalogue (les noms renvoyés par le jeu ne
-- passent jamais par ici : ils restent tels que le client les donne).
ns.CATALOG_EN = {
  level = "Level", stat1 = "Strength", stat2 = "Agility", stat3 = "Stamina", stat4 = "Intellect", stat5 = "Spirit",
  alchemy = "Alchemy", blacksmithing = "Blacksmithing", enchanting = "Enchanting", engineering = "Engineering",
  herbalism = "Herbalism", leatherworking = "Leatherworking", mining = "Mining", skinning = "Skinning",
  tailoring = "Tailoring", cooking = "Cooking", fishing = "Fishing", firstaid = "First Aid", riding = "Riding",
  axes = "Axes", axes2h = "Two-Handed Axes", maces = "Maces", maces2h = "Two-Handed Maces",
  swords = "Swords", swords2h = "Two-Handed Swords", polearms = "Polearms", staves = "Staves",
  fist = "Fist Weapons", daggers = "Daggers", unarmed = "Unarmed", feral = "Feral Combat",
  bows = "Bows", guns = "Guns", crossbows = "Crossbows", thrown = "Thrown", wands = "Wands",
  defense = "Defense", lockpicking = "Lockpicking", poisons = "Poisons",
}
function ns.CatalogDisplayName(entry)
  if type(entry) ~= "table" then return entry end
  if entry.id and not ns.IsFrench() and ns.CATALOG_EN[entry.id] then return ns.LocName("skill", entry.id, ns.CATALOG_EN[entry.id]) end
  return entry.name
end
function ns.SkillDisplayName(id)
  local e = ns.CatalogById and ns.CatalogById(id) or (ns.CATALOG_BY_ID and ns.CATALOG_BY_ID[id])
  if e then return ns.CatalogDisplayName(e) end
  return id and tostring(id) or nil
end

-- 3.8.2 : noms enregistrés dans une autre langue (fiches de personnages, rangs en cache) :
-- « Dépeçage » lu sur un client français s'affiche « Skinning » en anglais, et inversement.
local skillByName
local function FoldName(s)
  s = tostring(s or "")
  if ns.Fold then local ok, v = pcall(ns.Fold, s) if ok and type(v) == "string" then return v end end
  return s:lower()
end
function ns.LocSkillName(name, id)
  if id and ns.SkillDisplayName then
    local e = ns.CatalogById and ns.CatalogById(id) or (ns.CATALOG_BY_ID and ns.CATALOG_BY_ID[id])
    if e then return ns.CatalogDisplayName(e) end
  end
  if type(name) ~= "string" or name == "" then return name end
  if not skillByName and type(ns.CATALOG) == "table" then
    skillByName = {}
    for _, e in ipairs(ns.CATALOG) do
      if e.id then
        if e.name then skillByName[FoldName(e.name)] = e end
        if ns.CATALOG_EN[e.id] then skillByName[FoldName(ns.CATALOG_EN[e.id])] = e end
        for _, a in ipairs(e.aliases or {}) do skillByName[FoldName(a)] = skillByName[FoldName(a)] or e end
      end
    end
  end
  local e = skillByName and skillByName[FoldName(name)]
  return e and ns.CatalogDisplayName(e) or name
end

-- Classe d'une fiche : nom dans la langue de l'addon, d'après le code (WARRIOR…) ou le nom enregistré.
local CLASS_EN = { WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
  SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid" }
local CLASS_FR = { WARRIOR = "Guerrier", PALADIN = "Paladin", HUNTER = "Chasseur", ROGUE = "Voleur", PRIEST = "Prêtre",
  SHAMAN = "Chaman", MAGE = "Mage", WARLOCK = "Démoniste", DRUID = "Druide" }
local CLASS_FR_ALT = { ["Chasseresse"] = "HUNTER", ["Voleuse"] = "ROGUE", ["Prêtresse"] = "PRIEST", ["Chamane"] = "SHAMAN",
  ["Druidesse"] = "DRUID", ["Guerrière"] = "WARRIOR", ["Paladine"] = "PALADIN", ["Démoniste"] = "WARLOCK" }
function ns.ClassCode(className, classFile)
  if type(classFile) == "string" and CLASS_EN[classFile] then return classFile end
  if type(className) ~= "string" then return nil end
  for code, n in pairs(CLASS_EN) do if n == className then return code end end
  for code, n in pairs(CLASS_FR) do if n == className then return code end end
  return CLASS_FR_ALT[className]
end
function ns.LocClassName(className, classFile)
  local code = ns.ClassCode(className, classFile)
  if not code then return className end
  if ns.IsFrench() then return CLASS_FR[code] end
  return ns.LocName("class", code, CLASS_EN[code])
end

-- Modèles de texte du client (ERR_SKILL_UP_SI, LOOT_ITEM_SELF, ITEM_MIN_SKILL…) :
-- « %s » / « %d » (et « %1$s ») deviennent des captures, dans l'ordre des arguments.
local patCache = {}
local function BuildPattern(name)
  local s = rawget(_G, name)
  if type(s) ~= "string" or s == "" then return false end
  local order, n = {}, 0
  local function spec(pos, c)
    n = n + 1
    order[n] = tonumber(pos) or n
    return (c == "d") and "\001" or "\002"
  end
  s = s:gsub("%%(%d)%$([sd])", spec)
  s = s:gsub("%%([sd])", function(c) return spec(nil, c) end)
  s = s:gsub("%%%%", "%%")
  s = s:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
  s = s:gsub("\001", "(%%d+)"):gsub("\002", "(.-)")
  return { pat = "^" .. s .. "$", order = order, n = n }
end
function ns.MatchGlobal(name, msg)
  if type(msg) ~= "string" then return nil end
  local p = patCache[name]
  if p == nil then p = BuildPattern(name) patCache[name] = p end
  if not p then return nil end
  local caps = { pcall(string.match, msg, p.pat) }
  if not caps[1] or caps[2] == nil then return nil end
  local out = {}
  for i = 1, p.n do out[p.order[i] or i] = caps[i + 1] end
  return unpack(out, 1, p.n)
end
-- Début fixe d'un modèle (avant le premier %), pour un test « ^… » ; nil si trop court.
function ns.GlobalPrefix(name)
  local s = rawget(_G, name)
  if type(s) ~= "string" then return nil end
  local pre = s:match("^([^%%]*)")
  if not pre or #pre < 4 then return nil end
  return "^" .. pre:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
end

-- Noms de la base (recettes, objets) : comme le client du jeu les écrit
-- (français sur un client français, anglais sinon), indépendamment de /drop lang.
-- 3.12.0 : sur un autre client, les noms lus dans le jeu (GetItemInfo, GetSpellInfo) passent avant (voir ns.ItemName).
function ns.GameName(en, fr)
  if ns.ClientLang() == "fr" then return fr or en end
  return en or fr
end

-- /drop lang auto|en|fr (aussi : /drop langue)
local RELOAD_POPUP = "DROPAMINE_LANG_RELOAD"
local function ReloadPrompt()
  local SP = rawget(_G, "StaticPopupDialogs")
  if type(SP) ~= "table" or type(StaticPopup_Show) ~= "function" then return end
  SP[RELOAD_POPUP] = {
    text = ns.L["Dropamine : langue changée. Recharger l'interface maintenant pour tout traduire ?"],
    button1 = rawget(_G, "ACCEPT") or "OK", button2 = rawget(_G, "CANCEL") or "Cancel",
    OnAccept = function() if type(ReloadUI) == "function" then ReloadUI() end end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
  }
  StaticPopup_Show(RELOAD_POPUP)
end
local LANG_NAMES = { auto = "auto (langue du jeu)", en = "English", fr = "Français", de = "Deutsch", es = "Español", it = "Italiano", pt = "Português", ru = "Русский" }
ns.LANG_NAMES = LANG_NAMES
-- « auto (langue du jeu) → Français » ou « English »
function ns.LangLabel()
  local s = ns.LangSetting()
  local cur = LANG_NAMES[ns.LangCode()] or "English"
  if s == "auto" then return ns.L[LANG_NAMES.auto] .. " → " .. cur end
  return cur
end
function ns.SetLang(v, quiet)
  v = type(v) == "string" and v:lower() or ""
  if v == "anglais" or v == "english" or v == "enus" or v == "engb" then v = "en" end
  if v == "francais" or v == "français" or v == "french" or v == "frfr" then v = "fr" end
  if v == "defaut" or v == "default" or v == "jeu" or v == "game" or v == "client" then v = "auto" end
  local ALIAS = { deutsch = "de", german = "de", allemand = "de", dede = "de", ["español"] = "es", espanol = "es", spanish = "es", espagnol = "es", eses = "es", esmx = "es",
    italiano = "it", italian = "it", italien = "it", itit = "it", ["português"] = "pt", portugues = "pt", portuguese = "pt", portugais = "pt", ptbr = "pt",
    ["русский"] = "ru", russian = "ru", russe = "ru", ruru = "ru" }
  v = ALIAS[v] or v
  if v ~= "auto" and not KNOWN[v] then return false end
  local db = rawget(_G, "DropamineDB")
  if type(db) ~= "table" then return false end
  db.ui = type(db.ui) == "table" and db.ui or {}
  local before = ns.LangCode()
  db.ui.lang = v
  if not quiet then
    local Tr = ns.L
    if ns.Print then ns.Print(Tr["langue : "] .. ns.LangLabel()) end
    if before ~= ns.LangCode() then
      if ns.Print then ns.Print(Tr["tape /reload pour traduire aussi les textes déjà affichés"]) end
      if not (InCombatLockdown and InCombatLockdown()) then pcall(ReloadPrompt) end
    end
    if ns.UI and ns.UI.Refresh then pcall(ns.UI.Refresh, ns.UI, true) end
    if ns.Options and ns.Options.Sync then pcall(ns.Options.Sync) end
  end
  return true
end
ns.SlashExt = ns.SlashExt or {}
local function SlashLang(rest)
  local Tr = ns.L
  local arg = (rest or ""):match("^%s*(%S*)") or ""
  if arg == "" then
    local s = ns.LangSetting()
    if ns.Print then
      ns.Print(Tr["langue : "] .. ns.LangLabel() .. "  ·  /drop lang auto|en|fr|de|es|it|pt|ru")
    end
    return true
  end
  if not ns.SetLang(arg) and ns.Print then ns.Print(Tr["usage : /drop lang auto|en|fr|de|es|it|pt|ru"]) end
  return true
end
ns.SlashExt.lang = SlashLang
-- 3.13.0 : /drop traduction : le lien pour signaler un mot faux (copié depuis le chat, ouvert dans le navigateur)
local function SlashTr()
  local Tr = ns.L
  if ns.Print then
    ns.Print(Tr["Un mot faux dans ta langue ? Signale-le ici (copie le lien dans ton navigateur) :"])
    ns.Print("https://github.com/Raykuilu/Dropamine/issues/new?labels=translation&title=%5B" .. tostring(ns.LangCode()) .. "%5D")
  end
  return true
end
ns.SlashExt.traduction = SlashTr
ns.SlashExt.translation = SlashTr
ns.HelpExt = ns.HelpExt or {}
ns.HelpExt[#ns.HelpExt + 1] = "/drop traduction : signaler un mot faux dans ta langue"
ns.SlashExt.langue = SlashLang
ns.SlashExt.language = SlashLang
