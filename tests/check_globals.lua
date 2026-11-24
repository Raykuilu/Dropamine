-- Cherche les variables GLOBALES écrites par erreur (un `local` oublié, du code collé au mauvais endroit),
-- et les petites globales lues (p, c, f…) qui trahissent un local manquant. check_syntax.lua ne les voit pas.
-- Version Lua de check_globals.py (aucun Python nécessaire). Usage : lua tests/check_globals.lua
-- Il faut luac (5.2 ou plus) à côté de lua, ou LUAC=chemin.
local LUAC = os.getenv("LUAC")
if not LUAC then
  for _, c in ipairs({ "luac", "luac5.4", "luac5.3", "texluac", "luac.exe" }) do
    local h = io.popen(c .. " -v 2>&1")
    local out = h and h:read("*a") or ""
    if h then h:close() end
    if out:find("Lua") then LUAC = c break end
  end
end
if not LUAC then print("luac introuvable (installe Lua 5.2+ ou donne LUAC=…)") os.exit(2) end
local ALLOWED = { DropamineDB = true, OSRS_TotalLevelDB = true }
local OK_READ = { ns = true, os = true }
local bad = 0
-- 3.9.0 : noms déclarés « local » en tête d'un fichier de l'addon (hors alias d'API du jeu « local X = X »).
-- Lu comme global ailleurs = import oublié (ex. code déplacé de UI.lua vers Toasts.lua).
local OWN = {}
for line in io.lines("Dropamine.toc") do
  local f = line:match("^([%w_/\\]+%.lua)%s*$")
  if f and not f:match("^Locales") and not f:match("^Data") then
    for l in io.lines((f:gsub("\\", "/"))) do
      local fn = l:match("^local function ([%a_][%w_]*)")
      if fn then OWN[fn] = true end
      local names, rhs = l:match("^local ([%a_][%w_, ]-)%s*=%s*(.-)%s*$")
      if not names then names = l:match("^local ([%a_][%w_, ]-)%s*%-%-") or l:match("^local ([%a_][%w_, ]-)%s*$") end
      if names and not names:find("function") then
        local alias = {}
        if rhs then for r in rhs:gmatch("[^,]+") do alias[#alias + 1] = r:match("^%s*([%a_][%w_%.]*)%s*$") end end
        local i = 0
        for n in names:gmatch("[%a_][%w_]*") do
          i = i + 1
          if alias[i] ~= n then OWN[n] = true end
        end
      end
    end
  end
end
for line in io.lines("Dropamine.toc") do
  local f = line:match("^([%w_/\\]+%.lua)%s*$")
  if f then
    f = f:gsub("\\", "/")
    local h = io.popen(LUAC .. " -l -l -p " .. f .. " 2>&1")
    for l in h:lines() do
      local g = l:match('GETTABUP%s.*; _ENV "([a-z][a-z0-9]?)"')
      if g and not OK_READ[g] then
        bad = bad + 1
        print(("GLOBALE LUE (probable local oublié) : %s  (%s, ligne %s)"):format(g, f, l:match("%[(%d+)%]") or "?"))
      end
      local o = l:match('GETTABUP%s.*; _ENV "([%a_][%w_]*)"')
      if o and OWN[o] and not OK_READ[o] and not (g and g == o) then
        bad = bad + 1
        print(("NOM LOCAL DE L'ADDON LU COMME GLOBAL (import oublié ?) : %s  (%s, ligne %s)"):format(o, f, l:match("%[(%d+)%]") or "?"))
      end
      local m = l:match('SETTABUP%s.*; _ENV "([^"]+)"')
      if m and not ALLOWED[m] then
        bad = bad + 1
        print(("GLOBALE ÉCRITE : %s  (%s, ligne %s)"):format(m, f, l:match("%[(%d+)%]") or "?"))
      end
    end
    h:close()
  end
end
print(bad == 0 and "OK : aucune globale inattendue" or (bad .. " problème(s) de globales à vérifier"))
os.exit(bad == 0 and 0 or 1)
