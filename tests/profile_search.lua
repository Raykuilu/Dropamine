-- Export / import des réglages (aller-retour, caractères spéciaux) et recherche dans les réglages (3.9.0).
-- Usage, depuis la racine de l'addon : lua tests/profile_search.lua   (code de retour 1 en cas d'échec)
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

local O, PF = rawget(ns, "Options"), rawget(ns, "Profile")
ns.EnsureDB = function() return ns.db end
ns.SetOpt = function(k, v) ns.db.ui[k] = v end
-- on teste la mise en forme du profil, pas l'application des réglages (thème, mise en page… : faux objets ici)
O.Get = function(k) local it = O.Find(k) local v = ns.db.ui[k] if v == nil and it then return it.default end return v end
O.Set = function(k, v) ns.db.ui[k] = v return v end
O.panel = nil
local fail = 0
local function check(ok, what) if not ok then fail = fail + 1 print("ÉCHEC :", what) end end
check(PF ~= nil, "module Profile chargé")
if PF then
  local s, n = PF.Export()
  check(s:sub(1, 6) == "DROP1:", "préfixe DROP1:")
  check(n >= 40, "au moins 40 réglages exportés (vu " .. n .. ")")
  ns.db.ui.skillDrops = false
  local s2 = PF.Export()
  ns.db.ui.skillDrops = nil
  local applied = PF.Import(s2)
  check(applied and applied > 0, "import appliqué")
  check(ns.db.ui.skillDrops == false, "aller-retour d'une case décochée")
  local d = PF.Decode("DROP1:a=s1%3B2%3D3;b=b1;c=n2.5;zzz")
  check(d and d.a == "1;2=3" and d.b == true and d.c == 2.5, "décodage des caractères spéciaux")
  check(PF.Decode("bonjour") == nil, "texte étranger refusé")
  check(PF.Keys and not (function() for _, it in ipairs(PF.Keys()) do if it.key == "lang" then return true end end end)(), "langue jamais exportée")
end
check(#O.SearchMatches("sons") >= 1, "recherche « sons »")
check(#O.SearchMatches("dépeçage") >= 1, "recherche avec accent")
check(#O.SearchMatches("zzzzqq") == 0, "recherche sans résultat")
check(#O.SearchMatches("a") == 0, "1 lettre : pas de recherche")
print(fail == 0 and "OK : export / import et recherche" or (fail .. " échec(s)"))
os.exit(fail == 0 and 0 or 1)
