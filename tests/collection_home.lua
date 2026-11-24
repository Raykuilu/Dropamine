-- Accueil du collection log : calcule les totaux, les catégories et « presque terminés »
-- (la fonction est extraite de ProgressUI.lua et lancée avec de faux objets d'interface).
-- Usage, depuis la racine de l'addon : texlua tests/collection_home.lua
local src = io.open("ProgressUI.lua", "rb"):read("*a"):gsub("\r\n", "\n")   -- fichier en CRLF (Windows) ou LF
local body = src:match("(function PU%.RefreshCollectionHome.-\nend)\n\nfunction PU%.RefreshCollection%(")
assert(body, "fonction introuvable")
local Tr = setmetatable({}, { __index = function(_, k) return k end })
local PU = { SetBar = function(b, f) b.frac = f end, SetClipped = function(fs, t) fs.text = t end }
_G.TextColor = function() end _G.Paint = function() end
local function FS() return { SetText = function(s, t) s.text = t end, Show = function() end, Hide = function() end } end
local function Row() return { fs = FS(), val = FS(), bar = {}, hl = {}, Show = function(s) s.shown = true end, Hide = function() end } end
local c = { rtitle = FS(), rcount = FS(), rbar = {}, rempty = FS(), hkpi = FS(), hlab1 = FS(), hlab2 = FS(), hcat = {}, halm = {} }
for i = 1, 6 do c.hcat[i] = Row() end
for i = 1, 3 do c.halm[i] = Row() end
local secs = {
  { header = "Donjons 10-30", entries = {
    { key = "dj:A", label = "Mortemines", x = 6, y = 6, bosses = { { kills = 40 } } },
    { key = "dj:B", label = "Cavernes", x = 7, y = 8, bosses = { { kills = 20 } } },
    { key = "dj:C", label = "Ombrecroc", x = 2, y = 9, bosses = {} } } },
  { header = "Raids", entries = { { key = "dj:D", label = "Coeur du Magma", x = 0, y = 12, bosses = {} } } },
  { header = "Découvertes", entries = { { key = "st:x", label = "Créatures", x = 5, y = 100, stat = true } } },
}
local f = assert(load("local PU, Tr, c, secs, pal, H = ... ; " .. body:gsub("^function PU%.RefreshCollectionHome%(c, secs, pal, H%)", "return (function(c, secs, pal, H)", 1) .. ")(c, secs, pal, H)"))
f(PU, Tr, c, secs, {}, { HasSource = function() return true end })
print("titre :", c.rtitle.text, "| compte :", c.rcount.text)
print("chiffres :", c.hkpi.text)
for i, b in ipairs(c.hcat) do if b.shown then print("cat", i, b.fs.text, b.val.text, b.target) end end
for i, b in ipairs(c.halm) do if b.shown then print("presque", i, b.fs.text, b.val.text, b.target) end end
