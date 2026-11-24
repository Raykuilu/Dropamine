-- Réglages : chaque ligne apparaît une seule fois, rien ne tombe dans « Autres », chaque case d'une liste
-- a son réglage, et tout ce qui s'affiche a sa traduction anglaise (titres, libellés, aides, choix).
-- Usage, depuis la racine de l'addon : lua tests/check_options.lua   (code de retour 1 en cas de problème)
local function Stub(name)
  return setmetatable({}, {
    __index = function(_, k) return Stub(name .. "." .. tostring(k)) end,
    __call = function() return Stub(name .. "()") end,
    __concat = function(a, b) return tostring(a) .. tostring(b) end,
    __tostring = function() return name end,
    __lt = function() return false end, __le = function() return false end,
    __add = function() return 0 end, __sub = function() return 0 end, __mul = function() return 0 end, __div = function() return 0 end,
    __unm = function() return 0 end,
  })
end
local LOWER = {}
for w in ([[strsplit strjoin strtrim strfind strlower strupper strmatch strsub strlen strbyte strrep strchar strrev
  tinsert tremove wipe date time format gsub gmatch unpack select hooksecurefunc issecretvalue canaccessvalue
  geterrorhandler securecall forceinsecure debugstack tContains sort max min floor ceil abs random sqrt]]):gmatch("%S+") do LOWER[w] = true end
local env = setmetatable({}, { __index = function(_, k)
  local v = _G[k]
  if v ~= nil then return v end
  if type(k) == "string" and (k:find("%u") or LOWER[k]) then return Stub(k) end
  return nil
end })
env._G = env
local ns = setmetatable({}, getmetatable(Stub("ns")))
ns.L = setmetatable({}, { __index = function(_, k) return k end })
ns.SlashExt, ns.HelpExt, ns.db = {}, {}, { ui = {} }
ns.On = function() end
ns.Opt = function() return true end
ns.CharDB = function() return {} end
for line in io.lines("Dropamine.toc") do
  if line:match("%.lua%s*$") and not line:match("^#") then
    local f = line:gsub("\\", "/"):gsub("%s+$", "")
    if not f:match("^Locales/") and not f:match("^Data/") then
      local fn = loadfile(f, "t", env)
      if fn then pcall(fn, "Dropamine", ns) end
    end
  end
end

local O = rawget(ns, "Options")
local E = {}
for line in io.lines("Locales/enUS.lua") do
  local k = line:match('^E%["(.-)"%]%s*=')
  if k then E[k:gsub('\\"', '"')] = true end
end
local KEEP = { ["English"] = true, ["Français"] = true }   -- noms de langue : affichés tels quels
local bad = 0
local function fail(...) bad = bad + 1 print(...) end
local function tr(s, where) if type(s) == "string" and s ~= "" and not E[s] and not KEEP[s] then fail("SANS TRADUCTION", where, s) end end

local shown = {}
for _, sec in ipairs(O.SECTIONS) do
  tr(sec.title, "onglet")
  for _, it in ipairs(O.SectionItems(sec)) do
    if shown[it.key] then fail("AFFICHÉ DEUX FOIS", it.key) end
    shown[it.key] = true
    if it.group == "Autres" then fail("HORS PLAN (tombe dans « Autres »)", it.key) end
    tr(it.group, "groupe") tr(it.label, it.key) tr(it.help, it.key .. " (aide)")
    for _, ch in ipairs(it.choices or {}) do tr(ch[2], it.key .. " (choix)") end
  end
end
for k, g in pairs(O.GROUPS or {}) do
  for _, ch in ipairs(g.items) do
    if not O.RawItem(ch[1]) then fail("CASE SANS RÉGLAGE", k, ch[1]) end
    if shown[ch[1]] then fail("À LA FOIS SEUL ET DANS UNE LISTE", ch[1]) end
    if not O.Find(ch[1]) then fail("INTROUVABLE (Find)", ch[1]) end
  end
end
print(bad == 0 and "OK : réglages bien rangés et traduits" or (bad .. " problème(s) dans les réglages"))
os.exit(bad == 0 and 0 or 1)
