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
      local m = l:match('SETTABUP%s.*; _ENV "([^"]+)"')
      if m and not ALLOWED[m] then
        bad = bad + 1
        print(("GLOBALE ÉCRITE : %s  (%s, ligne %s)"):format(m, f, l:match("%[(%d+)%]") or "?"))
      end
    end
    h:close()
  end
end
print(bad == 0 and "OK : aucune écriture globale inattendue" or (bad .. " écriture(s) globale(s) à vérifier"))
os.exit(bad == 0 and 0 or 1)
