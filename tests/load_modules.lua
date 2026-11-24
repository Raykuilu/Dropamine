-- Charge VRAIMENT chaque fichier (pas seulement la syntaxe) avec une enveloppe de faux objets permissive :
-- une erreur d'exécution au niveau du fichier (variable globale nil, code collé au mauvais endroit...) est signalée.
-- Usage, depuis la racine de l'addon : texlua tests/load_modules.lua
local function Stub(name)
  local t = {}
  return setmetatable(t, {
    __index = function(_, k) return Stub(name .. "." .. tostring(k)) end,
    __call = function() return Stub(name .. "()") end,
    __concat = function(a, b) return tostring(a) .. tostring(b) end,
    __tostring = function() return name end,
    __lt = function() return false end, __le = function() return false end,
    __add = function() return 0 end, __sub = function() return 0 end, __mul = function() return 0 end, __div = function() return 0 end,
    __unm = function() return 0 end,
  })
end
-- Comme dans le jeu : un nom global inconnu vaut nil, SAUF les API du jeu (majuscule dans le nom, ou liste ci-dessous).
local LOWER = {}
for w in ([[strsplit strjoin strtrim strfind strlower strupper strmatch strsub strlen strbyte strrep strchar strrev
  tinsert tremove wipe date time format gsub gmatch unpack select hooksecurefunc issecretvalue canaccessvalue
  geterrorhandler securecall forceinsecure debugstack tContains sort max min floor ceil abs random sqrt]]):gmatch("%S+") do LOWER[w] = true end
local env = setmetatable({}, { __index = function(t, k)
  local v = _G[k]
  if v ~= nil then return v end
  if type(k) == "string" and (k:find("%u") or LOWER[k]) then return Stub(k) end
  return nil
end })
env._G = env
local ns = Stub("ns")
local nsReal = {}
setmetatable(nsReal, getmetatable(ns))
nsReal.L = setmetatable({}, { __index = function(_, k) return k end })
nsReal.SlashExt, nsReal.HelpExt, nsReal.db = {}, {}, { ui = {} }
nsReal.On = function() end
nsReal.Opt = function() return true end
nsReal.CharDB = function() return {} end
local bad = 0
for line in io.lines("Dropamine.toc") do
  if line:match("%.lua%s*$") and not line:match("^#") then
    local f = line:gsub("\\", "/"):gsub("%s+$", "")
    if not f:match("^Locales/") and not f:match("^Data/") then
      local fn, err = loadfile(f, "t", env)
      if not fn then fn = loadfile(f) if fn then setfenv = setfenv end end
      if not fn then bad = bad + 1 print("SYNTAXE", f, err)
      else
        local ok, e = pcall(fn, "Dropamine", nsReal)
        if not ok then bad = bad + 1 print("ERREUR AU CHARGEMENT", f, e) end
      end
    end
  end
end
print(bad == 0 and "OK : tous les fichiers s'exécutent jusqu'au bout" or (bad .. " fichier(s) en erreur"))
os.exit(bad == 0 and 0 or 1)
