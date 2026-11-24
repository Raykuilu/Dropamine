-- Charge chaque fichier listé dans Dropamine.toc (syntaxe seulement).
-- Usage, depuis la racine de l'addon : texlua tests/check_syntax.lua
local bad = 0
for line in io.lines("Dropamine.toc") do
  if line:match("%.lua%s*$") and not line:match("^#") then
    local f = line:gsub("\\", "/"):gsub("%s+$", "")
    local fn, err = loadfile(f)
    if not fn then bad = bad + 1 print("ERREUR", f, err) end
  end
end
print(bad == 0 and "OK : tous les fichiers se chargent" or (bad .. " fichier(s) en erreur"))
os.exit(bad == 0 and 0 or 1)
