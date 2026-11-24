-- Tableau de comparaison du récap : remplit les cellules à partir d'un CompareRecap factice.
-- Usage, depuis la racine de l'addon : texlua tests/recap_table.lua
local src = io.open("ProgressUI.lua", "rb"):read("*a"):gsub("\r\n", "\n")   -- fichier en CRLF (Windows) ou LF
local a = src:find("  local cmp = E.CompareRecap and E.CompareRecap(snap) or {}", 1, true)
local b = src:find("  local tipText =", a, true)
assert(a and b, "bloc introuvable")
local block = src:sub(a, b - 1)
local Tr = setmetatable({}, { __index = function(_, k) return k end })
local colors = {}
local function FS() return { SetText = function(s, t) s.text = t end } end
local p = { tbl = { head = {}, rows = {} } }
for c = 0, 4 do p.tbl.head[c] = FS() end
for r = 1, 4 do p.tbl.rows[r] = {} for c = 0, 4 do p.tbl.rows[r][c] = FS() end end
local E = { CompareRecap = function() return {
  score = { mine = 0, prev = 0, d7 = 0.06, d30 = 0.06 },
  pctLevelPerHour = { mine = 0, prev = 0, d7 = 0, d30 = 0 },
  skillUpsPerHour = { mine = 14.2, prev = 1.5, d7 = 11.3, d30 = 11.3 },
  goldPerHour = { mine = 100, prev = nil, d7 = 2245, d30 = 2245 } } end }
local PU = { Pal = function() return { text = "t", title = "ti", sub = "s", gold = "gold", good = "good", bad = "bad" } end }
local function Fmt1(v) return string.format("%.1f", v) end
local function Fmt2(v) return string.format("%.2f", v) end
local function pct(v) return string.format("%d %%", math.floor(v * 100 + 0.5)) end
local function TextColor(fs, c) fs.color = c end
local money = function(v) return tostring(v) .. "c" end
local f = assert(load("local E, p, Tr, PU, Fmt1, Fmt2, pct, TextColor, money, snap = ...\n" .. block))
f(E, p, Tr, PU, Fmt1, Fmt2, pct, TextColor, money, {})
local h = {} for c = 0, 4 do h[#h + 1] = p.tbl.head[c].text end print(table.concat(h, " | "))
for r = 1, 4 do
  local t = {} for c = 0, 4 do t[#t + 1] = p.tbl.rows[r][c].text end
  print(table.concat(t, " | "), "couleur session :", p.tbl.rows[r][1].color)
end
