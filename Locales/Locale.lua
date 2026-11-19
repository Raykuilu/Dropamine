-- Dropamine — langue des textes (3.5.19).
-- Clés = texte français d'origine (le français reste mot pour mot) ;
-- Locales/enUS.lua donne l'anglais. Choix : DropamineDB.ui.lang = "auto" | "en" | "fr".
-- auto : frFR → français, tout autre client → anglais.
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

local clientLang
function ns.ClientLocale()
  local ok, loc = false, nil
  if type(GetLocale) == "function" then ok, loc = pcall(GetLocale) end
  return (ok and type(loc) == "string") and loc or "enUS"
end
function ns.ClientLang()
  if not clientLang then clientLang = (ns.ClientLocale() == "frFR") and "fr" or "en" end
  return clientLang
end

-- Réglage enregistré (avant ADDON_LOADED : DropamineDB absent → « auto »).
function ns.LangSetting()
  local db = rawget(_G, "DropamineDB")
  local ui = type(db) == "table" and rawget(db, "ui") or nil
  local v = type(ui) == "table" and rawget(ui, "lang") or nil
  if v == "en" or v == "fr" then return v end
  return "auto"
end
function ns.LangCode()
  local s = ns.LangSetting()
  if s == "auto" then return ns.ClientLang() end
  return s
end
function ns.IsFrench() return ns.LangCode() == "fr" end

ns.L = setmetatable({}, {
  __index = function(_, k)
    if type(k) ~= "string" then return k end
    if ns.LangCode() == "en" then
      local v = EN[k]
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
  if ns.LangCode() == "en" and entry.id and ns.CATALOG_EN[entry.id] then return ns.CATALOG_EN[entry.id] end
  return entry.name
end
function ns.SkillDisplayName(id)
  local e = ns.CatalogById and ns.CatalogById(id) or (ns.CATALOG_BY_ID and ns.CATALOG_BY_ID[id])
  if e then return ns.CatalogDisplayName(e) end
  return id and tostring(id) or nil
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
local LANG_NAMES = { auto = "auto (langue du jeu)", en = "English", fr = "Français" }
-- « auto (langue du jeu) → Français » ou « English »
function ns.LangLabel()
  local s = ns.LangSetting()
  local cur = (ns.LangCode() == "fr") and "Français" or "English"
  if s == "auto" then return ns.L[LANG_NAMES.auto] .. " → " .. cur end
  return cur
end
function ns.SetLang(v, quiet)
  v = type(v) == "string" and v:lower() or ""
  if v == "anglais" or v == "english" or v == "enus" or v == "engb" then v = "en" end
  if v == "francais" or v == "français" or v == "french" or v == "frfr" then v = "fr" end
  if v == "defaut" or v == "default" or v == "jeu" or v == "game" or v == "client" then v = "auto" end
  if v ~= "auto" and v ~= "en" and v ~= "fr" then return false end
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
      ns.Print(Tr["langue : "] .. ns.LangLabel() .. "  ·  /drop lang auto|en|fr")
    end
    return true
  end
  if not ns.SetLang(arg) and ns.Print then ns.Print(Tr["usage : /drop lang auto|en|fr"]) end
  return true
end
ns.SlashExt.lang = SlashLang
ns.SlashExt.langue = SlashLang
ns.SlashExt.language = SlashLang
