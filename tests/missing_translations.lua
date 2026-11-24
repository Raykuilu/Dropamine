-- Liste les textes Tr["..."] du code qui n'ont pas de traduction dans Locales/enUS.lua.
-- Version Lua de missing_translations.py (aucun Python nécessaire). Usage : lua tests/missing_translations.lua
-- Les textes construits à l'exécution (Tr[variable]) sont vérifiés par check_options.lua pour les réglages.
local have = {}
for line in io.lines("Locales/enUS.lua") do
  local k = line:match('^E%["(.-)"%]%s*=')
  if k then have[k] = true end
end
local miss, seen = {}, {}
for line in io.lines("Dropamine.toc") do
  local f = line:match("^([%w_/\\]+%.lua)%s*$")
  if f and not f:match("^Locales") then
    f = f:gsub("\\", "/")
    local src = io.open(f, "rb"):read("*a")
    local i = 1
    while true do
      local a, b, k = src:find('Tr%["(.-[^\\])"%]', i)
      if not a then break end
      i = b + 1
      if k:find("%a") and not have[k] and not seen[k] then seen[k] = true miss[#miss + 1] = k .. "   (" .. f .. ")" end
    end
  end
end
table.sort(miss)
for _, m in ipairs(miss) do print(m) end
print(#miss == 0 and "OK : tous les textes ont leur traduction anglaise" or (#miss .. " texte(s) sans traduction anglaise"))
os.exit(#miss == 0 and 0 or 1)
