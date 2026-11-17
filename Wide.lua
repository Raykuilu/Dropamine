-- Dropamine 3.3.13 : case « Niveau total » en BARRE pleine largeur.
-- Quand la dernière rangée ne contiendrait QUE le Niveau total (ex. 3 colonnes :
-- 9 compétences en carré 3 × 3), la case s'étire sur toute la largeur de la
-- grille, en barre FINE et discrète (une ligne) : petite icône OSRS du niveau
-- total (3 colonnes rouge / vert / bleu) à gauche, « 974 / 2460 », puis une
-- jauge fine. MASQUÉE par défaut ; /drop total on|off (ou l'option) l'affiche / la retire : la grille
-- se recalcule sans elle (3 colonnes = carré 3 × 3 exact). Même cadre que les autres
-- cases (StyleTile / habillage). Aucun OnUpdate : posé après chaque mise en
-- page de grille et repeint à chaque mise à jour de case.
local _, ns = ...
local UI, I = ns.UI, ns.Icons
local Wd = {}
ns.Wide = Wd
Wd.BAR_H = 3
Wd.PAD = 5
Wd.SLIM = 0.45      -- hauteur de la barre = 45 % d'une case (min 14 px)
Wd.MIN_H = 14
Wd.FILL = ns.STYLE.BORDER   -- #A67D45 (palette FlareUI, voir STYLE.md)
Wd.TRACK = { 0, 0, 0, 0.55 }
Wd.TEX = "Interface\\TargetingFrame\\UI-StatusBar"
local function N(v) return ns.N and ns.N(v) or tonumber(v) end

-- la dernière rangée n'aurait que le total ?
function Wd.ShouldWiden(cols, n)
  cols, n = N(cols) or 1, N(n) or 0
  return cols > 1 and n > 1 and ((n - 1) % cols) == 0
end

local function Parts(t)
  if t._wideParts then return t._wideParts end
  local p = {}
  p.track = t:CreateTexture(nil, "ARTWORK")
  pcall(p.track.SetTexture, p.track, Wd.TEX)
  p.fill = t:CreateTexture(nil, "ARTWORK", nil, 1)
  pcall(p.fill.SetTexture, p.fill, Wd.TEX)
  p.text = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  if p.text.SetJustifyH then p.text:SetJustifyH("CENTER") end
  t._wideParts = p
  return p
end

local ICON_PARTS = { "slotBg", "icon", "slotBorder", "hoverTex", "checkTex" }

function Wd.Paint(t)
  if not (t and t._wideOn and t.data) then return end
  local p = Parts(t)
  local d = t.data
  local cur, max = N(d.current) or 0, N(d.apiMax) or N(ns.TOTAL_MAX) or 0
  local w, h = N(t._wideW) or (t.GetWidth and N(t:GetWidth())) or 0, N(t._wideH) or (t.GetHeight and N(t:GetHeight())) or 0
  local isz = math.max(8, h - 2)                       -- petite icône carrée à gauche
  local iconX = math.floor(h / 2 + 0.5)
  for _, k in ipairs(ICON_PARTS) do
    local r = t[k]
    if r and r.ClearAllPoints then
      r:ClearAllPoints() r:SetPoint("CENTER", t, "LEFT", iconX, 0)
      if r.SetSize then r:SetSize(k == "slotBorder" and math.floor(isz * 1.6 + 0.5) or isz, k == "slotBorder" and math.floor(isz * 1.6 + 0.5) or isz) end
    end
  end
  -- 3.3.14 : textes du mode case (rang + « /max ») cachés en mode barre
  if t.countFS then t.countFS:Hide() end
  if t.countFS2 then t.countFS2:Hide() end
  local pct = (max > 0) and math.max(0, math.min(1, cur / max)) or 0
  p.text:ClearAllPoints()
  p.text:SetPoint("LEFT", t, "LEFT", h + Wd.PAD - 2, 0)
  p.text:SetText(string.format("%d / %d", cur, max))
  local okW, tw = pcall(p.text.GetStringWidth, p.text)
  tw = (okW and N(tw)) or 56
  local left = h + Wd.PAD - 2 + tw + Wd.PAD
  local inner = math.max(10, w - left - Wd.PAD)
  local bh = Wd.BAR_H
  local by = math.floor((h - bh) / 2)
  p.track:ClearAllPoints()
  p.track:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", left, by)
  p.track:SetSize(inner, bh)
  p.track:SetVertexColor(Wd.TRACK[1], Wd.TRACK[2], Wd.TRACK[3], Wd.TRACK[4])
  p.fill:ClearAllPoints()
  p.fill:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", left, by)
  p.fill:SetSize(math.max(0.01, inner * pct), bh)
  p.fill:SetVertexColor(Wd.FILL[1], Wd.FILL[2], Wd.FILL[3], Wd.FILL[4])
  if pct <= 0 then p.fill:Hide() else p.fill:Show() end
  p.track:Show() p.text:Show()
  Wd.last = { w = w, h = h, cur = cur, max = max, pct = pct, inner = inner }
end

local function Unwide(t)
  if not t._wideOn then return end
  t._wideOn, t._wideW, t._wideH = nil, nil, nil
  local p = t._wideParts
  if p then p.track:Hide() p.fill:Hide() p.text:Hide() end
  if t.countFS then t.countFS:Show() end
  if t.countFS2 then t.countFS2:Show() end
end

-- après la mise en page : étire la case total si elle est seule sur sa rangée
function Wd.Apply(wrap)
  local lay = wrap and wrap._layout
  if not (lay and wrap.tiles) then return nil end
  local cols, n, total = lay.cols or 1, 0, nil
  local maxR, tw, th = nil, lay.tw, lay.th
  local stepX
  for _, t in ipairs(wrap.tiles) do
    if t.data and t.IsShown and t:IsShown() then
      n = n + 1
      if t.data.kind == "total" then total = t end
    end
  end
  for _, c in ipairs(lay.cells or {}) do
    maxR = math.max(maxR or 0, c.x + c.w)
    if c.x > 0 and (not stepX or c.x < stepX) then stepX = c.x end
  end
  for _, t in ipairs(wrap.tiles) do if t ~= total then Unwide(t) end end
  if not total then wrap._wide = nil return nil end
  if not Wd.ShouldWiden(cols, n) then Unwide(total) wrap._wide = nil return false end
  local gw = stepX and ((cols - 1) * stepX + tw) or maxR or tw
  local ok, _, _, _, _, y = pcall(total.GetPoint, total, 1)
  y = (ok and N(y)) or 0
  total:ClearAllPoints()
  total:SetPoint("TOPLEFT", total:GetParent() or wrap, "TOPLEFT", 0, y)
  local sh = math.max(Wd.MIN_H, math.floor(th * Wd.SLIM + 0.5))
  total:SetSize(gw, sh)
  local hx = lay.hitPad and lay.hitPad.x or 0
  if total._cell then total._cell.x, total._cell.w = -hx, gw + 2 * hx end
  total._wideOn, total._wideW, total._wideH = true, gw, sh
  Wd.Paint(total)
  wrap._wide = { w = gw, h = sh, cols = cols, n = n }
  return true
end

local baseLayoutGrid = UI.LayoutGrid
function UI:LayoutGrid(wrap, snap)
  local r = { baseLayoutGrid(self, wrap, snap) }
  local ok, err = pcall(Wd.Apply, wrap)
  if not ok then Wd.lastError = err end
  return unpack(r)
end
local baseUpdateTile = UI.UpdateTile
function UI:UpdateTile(t, d)
  local r = { baseUpdateTile(self, t, d) }
  if t and t._wideOn then
    if d and d.kind ~= "total" then
      Unwide(t)
      local lay = UI.embed and UI.embed._layout
      if lay and lay.tw then pcall(UI.ResizeTile, UI, t, lay.tw, lay.th) end
    else pcall(Wd.Paint, t) end
  end
  return unpack(r)
end
-- le cadre des cases (thème) suit la nouvelle largeur
local Th = ns.Theme
if Th and Th.StyleTile then
  local baseStyle = Th.StyleTile
  function Th.StyleTile(t, ...)
    local r = { baseStyle(t, ...) }
    if t and t._wideOn then pcall(Wd.Paint, t) end
    return unpack(r)
  end
end

------------------------------------------------------------------------------
-- /drop total on|off : Niveau total affiché ou retiré de la grille
------------------------------------------------------------------------------
local function DB() ns.db = ns.db or {} ns.db.ui = ns.db.ui or {} return ns.db.ui end
-- masquée PAR DÉFAUT (3.3.13) : /drop total on la réactive
function Wd.Shown()
  if Wd.forceShown ~= nil then return Wd.forceShown end   -- tests (anciennes sections)
  return (ns.db and ns.db.ui and ns.db.ui.showTotal) == true end
function Wd.SetShown(on)
  DB().showTotal = on and true or nil
  local W, L = ns.Window, ns.Layout
  if L and L.Apply and W and W.frame then pcall(L.Apply)
  elseif W and W.IsShown and W.IsShown() then pcall(W.Layout) end
  if UI.Refresh then pcall(UI.Refresh, UI, true) end
  if L and L.Center then pcall(L.Center) end
  return Wd.Shown()
end
local baseGroup = UI.GroupTiles
function UI:GroupTiles(tiles)
  local groups = baseGroup(self, tiles)
  if Wd.Shown() then return groups end
  local out = {}
  for _, g in ipairs(groups) do
    local copy = {}
    for _, d in ipairs(g.tiles) do if d.kind ~= "total" then copy[#copy + 1] = d end end
    if #copy > 0 then out[#out + 1] = { title = g.title, tiles = copy, flat = g.flat } end
  end
  return out
end
local function NTiles()
  return (UI.snapshot and UI.snapshot.tiles and #UI.snapshot.tiles or 9) + (Wd.Shown() and 1 or 0)
    + ((ns.PvP and ns.PvP.Enabled and ns.PvP.Enabled()) and 1 or 0)
end
local P, L, W = ns.Panel, ns.Layout, ns.Window
if L then
  function L.Rows(cols) return math.max(1, math.ceil(NTiles() / (cols or L.Cols()))) end
end
if P and P.CompactListHeight then
  function P.CompactListHeight()
    local n = NTiles()
    local ins = UI:ListInsets()
    local inner = W.LIST_W - ins.left - ins.right
    local cols = math.max(1, math.floor((inner + I.HGAP) / (I.TILE + I.HGAP)))
    local rows = math.max(1, math.ceil(n / cols))
    return ins.top + rows * I.STEP + 4, cols, rows
  end
end
ns.SlashExt = ns.SlashExt or {}
ns.SlashExt.total = function(rest)
  local a = ((rest or ""):match("^%s*(%S*)") or ""):lower()
  local on
  if a == "on" then on = true elseif a == "off" then on = false elseif a == "" then on = not Wd.Shown() end
  if on == nil then print("|cffffd100Dropamine|r : usage : /drop total on|off") return end
  local s = Wd.SetShown(on)
  print("|cffffd100Dropamine|r : Niveau total " .. (s and "affiché" or "masqué (grille recalculée sans lui)"))
end
ns.HelpExt = ns.HelpExt or {}
ns.HelpExt[#ns.HelpExt + 1] = "/drop total on|off : afficher ou masquer la case Niveau total (barre fine en 3 colonnes)"

ns.DebugExt = ns.DebugExt or {}
ns.DebugExt[#ns.DebugExt + 1] = function()
  local e = UI.embed and UI.embed._wide
  return { "— Barre Niveau total (3.3.13) — " .. (not Wd.Shown() and "masquée (/drop total off)" or e and string.format("pleine largeur %d px (%d colonnes, %d cases)", e.w, e.cols, e.n) or "case normale") }
end
