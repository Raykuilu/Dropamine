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
local Tr = ns.L   -- 3.5.19 : textes traduits (Locales/)
local UI, I = ns.UI, ns.Icons
local Wd = {}
ns.Wide = Wd
Wd.BAR_H = 3
Wd.PAD = 5
Wd.SLIM = 0.45      -- hauteur de la barre = 45 % d'une case (min 14 px)
Wd.MIN_H = 14
Wd.FILL = ns.STYLE.BORDER   -- #A67D45 (palette FlareUI, voir STYLE.md) — filet de la jauge
Wd.TRACK = { 0, 0, 0, 0.55 }
Wd.TEX = "Interface\\TargetingFrame\\UI-StatusBar"
-- 3.5.1 : couleurs de Media/SkillsTab (rouge  #D11F1A, bleu #2961E0, vert #29A829),
-- saturation −40 %, légèrement assombries, +18 % de parchemin or #A67D45.
-- Ordre de la jauge : niveau, combat, métiers.
Wd.SEG_COLORS = {
  { 0.616, 0.278, 0.227, 1 },  -- #9D473A  niveau
  { 0.329, 0.408, 0.604, 1 },  -- #54689A  armes + Défense
  { 0.310, 0.498, 0.243, 1 },  -- #4F7F3E  métiers
}
-- 3.5.21 : marges intérieures du remplissage, par thème. Sur Flare (et
-- léger : même filet Dropamine-Thin, edgeSize 8, débord 3 px), l'arrondi
-- (pan coupé ~2,75 px + liseré) masquait le premier segment ou le laissait
-- dépasser avant le cadre. Classic : filet d'infobulle (edgeSize 10).
Wd.FILL_INSET = {
  flare   = { l = 1, r = 1, t = 1, b = 1 },
  leger   = { l = 1, r = 1, t = 1, b = 1 },
  classic = { l = 3, r = 3, t = 1, b = 1 },
}
Wd.SEG_MIN_W = 5  -- largeur minimale (px) d'un segment dont la valeur est > 0

function Wd.FillInset()
  local mode = (ns.Theme and ns.Theme.Mode and ns.Theme.Mode()) or "flare"
  local box = Wd.FILL_INSET[mode] or Wd.FILL_INSET.flare
  return box.l or 0, box.r or 0, box.t or 0, box.b or 0
end

local function N(v) return ns.N and ns.N(v) or tonumber(v) end

-- Réduit les marges si la piste est trop étroite pour les appliquer telles quelles.
local function ClampInsets(il, ir, it, ib, inner, bh)
  il, ir = math.max(0, il or 0), math.max(0, ir or 0)
  it, ib = math.max(0, it or 0), math.max(0, ib or 0)
  if il + ir >= inner then
    local cap = math.max(0, inner - 2)
    if il + ir > 0 and cap > 0 then
      local left = math.floor(cap * (il / (il + ir)))
      il, ir = left, cap - left
    else
      il, ir = 0, 0
    end
  end
  if it + ib >= bh then
    local cap = math.max(0, bh - 1)
    if it + ib > 0 and cap > 0 then
      local top = math.floor(cap * (it / (it + ib)))
      it, ib = top, cap - top
    else
      it, ib = 0, 0
    end
  end
  return il, ir, it, ib
end

-- Chaque segment non nul garde au moins minW px ; le surplus est pris sur
-- les segments plus larges (proportionnellement à l'excédent). Si la part
-- remplie est trop courte, on l'étend dans la piste encore vide, sans
-- dépasser `track`.
local function ApplyMinWidths(widths, present, minW, track, filled)
  local nPos = 0
  for i = 1, 3 do
    if present[i] then nPos = nPos + 1 end
  end
  if nPos == 0 or track <= 0 then return widths, filled end
  -- Si la piste est plus étroite que le nombre de segments, on ne peut pas
  -- garantir 1 px à chacun : on laisse les largeurs proportionnelles.
  minW = math.max(0, math.min(minW, math.floor(track / nPos)))
  if minW < 1 then return widths, filled end
  local need = nPos * minW
  if filled < need then
    for i = 1, 3 do
      widths[i] = present[i] and minW or 0
    end
    return widths, math.min(track, need)
  end
  local deficit, pool = 0, 0
  for i = 1, 3 do
    local w = widths[i] or 0
    if present[i] and w < minW then
      deficit = deficit + (minW - w)
    elseif w > minW then
      pool = pool + (w - minW)
    end
  end
  if deficit <= 0 then return widths, filled end
  for i = 1, 3 do
    if present[i] and (widths[i] or 0) < minW then
      widths[i] = minW
    end
  end
  local removed = 0
  if pool > 0 then
    for i = 1, 3 do
      local extra = (widths[i] or 0) - minW
      if extra > 0 then
        local take = math.floor(extra / pool * deficit + 0.5)
        if take > extra then take = extra end
        if take > deficit - removed then take = deficit - removed end
        if take < 0 then take = 0 end
        widths[i] = widths[i] - take
        removed = removed + take
      end
    end
  end
  local leftover = deficit - removed
  if leftover > 0 then
    for i = 3, 1, -1 do
      if leftover <= 0 then break end
      local extra = (widths[i] or 0) - minW
      if extra > 0 then
        local take = leftover
        if take > extra then take = extra end
        widths[i] = widths[i] - take
        leftover = leftover - take
      end
    end
  end
  local sum = 0
  for i = 1, 3 do sum = sum + (widths[i] or 0) end
  return widths, sum
end

local function Segments()
  local snap = ns.UI and ns.UI.snapshot
  if snap and snap.segments then return snap.segments end
  return ns.ComputeTotalSegments and ns.ComputeTotalSegments(snap and snap.tiles) or {}
end

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

local function HideTip(self)
  if ns.ProgressUI and ns.ProgressUI.HideMini then pcall(ns.ProgressUI.HideMini) end
  local tt = _G.GameTooltip
  if not (tt and tt.Hide) then return end
  if tt.IsOwned then
    if tt:IsOwned(self) then tt:Hide() end
  else
    tt:Hide()
  end
end

-- noMini : survol depuis la fenêtre Progression (pas de mini-graphe ni d'aide au clic)
function Wd.ShowBarTip(owner, noMini)
  local tt = _G.GameTooltip
  if not (tt and owner) then return end
  pcall(tt.SetOwner, tt, owner, "ANCHOR_TOP")
  if tt.ClearLines then tt:ClearLines() end
  tt:AddLine(Tr["Niveau total"])
  local segs = Segments()
  local colors = Wd.SEG_COLORS
  for i = 1, #segs do
    local s, c = segs[i], colors[i] or { 1, 1, 1, 1 }
    tt:AddDoubleLine(
      s.label or "?",
      string.format("%d / %d", N(s.cur) or 0, N(s.max) or 0),
      c[1], c[2], c[3], 1, 1, 1)
  end
  local snap = ns.UI and ns.UI.snapshot
  local cur = snap and (N(snap.total) or N(snap.ficTotal)) or 0
  local mx = snap and (N(snap.totalMax) or N(snap.ficMax)) or N(ns.TOTAL_MAX) or 2460
  if tt.AddLine then tt:AddLine(" ") end
  tt:AddDoubleLine(Tr["Total"], string.format("%d / %d", cur or 0, mx or 0), 1, 0.93, 0.80, 1, 0.93, 0.80)
  if not noMini and ns.ProgressUI then
    tt:AddLine(Tr["Clic : fenêtre Progression"], 0.6, 0.8, 1)
  end
  tt:Show()
  if not noMini and ns.ProgressUI and ns.ProgressUI.ShowMini then pcall(ns.ProgressUI.ShowMini, tt, owner) end
end
Wd.HideTip = HideTip

-- 3.6.0 : clic gauche sur la barre du total -> fenêtre Progression.
-- Maj+clic = partage (si l'option est active) ; un glisser ne clique pas.
function Wd.OnBarClick(self, button)
  if button and button ~= "LeftButton" then return false end
  if self._thDragged then self._thDragged = nil return false end
  if self.IsMouseOver then
    local ok, over = pcall(self.IsMouseOver, self)
    if ok and over == false then return false end
  end
  local t = self.GetParent and self:GetParent()
  if _G.IsShiftKeyDown and _G.IsShiftKeyDown() then
    if ns.Opt and ns.Opt("partage") and ns.QoL and ns.QoL.ShareTile and t and t.data then
      pcall(ns.QoL.ShareTile, t.data)
      return true
    end
    return false
  end
  HideTip(self)
  if t and t._wideOn then Wd.MuteBarHighlight(t) end
  if ns.ProgressUI and ns.ProgressUI.OnTotalClick then return ns.ProgressUI.OnTotalClick(self, "LeftButton") end
  return false
end

function Wd.EnsureSegs(t)
  local p = Parts(t)
  if not p.segs then
    p.segs = { p.fill }
    pcall(p.fill.SetTexture, p.fill, Wd.FILL_TEX or Wd.TEX)
    for i = 2, 3 do
      local tex = t:CreateTexture(nil, "ARTWORK", nil, 1)
      pcall(tex.SetTexture, tex, Wd.FILL_TEX or Wd.TEX)
      p.segs[i] = tex
    end
    p.fill = p.segs[1]
  end
  if not p.hit then
    local ok, hit = pcall(CreateFrame, "Frame", nil, t)
    p.hit = (ok and hit) or nil
    if p.hit then
      if p.hit.EnableMouse then p.hit:EnableMouse(true) end
      p.hit:SetScript("OnEnter", function(self) Wd.ShowBarTip(self) end)
      p.hit:SetScript("OnLeave", HideTip)
      p.hit:SetScript("OnMouseUp", function(self, button) Wd.OnBarClick(self, button) end)
      if ns.Theme and ns.Theme.WireDrag then pcall(ns.Theme.WireDrag, p.hit) end
    end
  end
  return p
end

-- 3.6.0 : largeurs des 3 segments (niveau, armes + Défense, métiers) pour une
-- piste de `track` px — fonction pure, partagée avec la fenêtre Progression.
-- Mêmes règles qu'en 3.5.21 : minimum de 5 px par segment non nul, rouge
-- (niveau) en paliers de 1 px (niv. 1) à 5 px (niv. 60).
function Wd.SegmentWidths(segs, track, cur, max)
  segs = segs or {}
  track = math.max(0, N(track) or 0)
  max = N(max) or 0
  cur = N(cur) or 0
  local filled = (max > 0) and math.max(0, math.min(track, math.floor(track * (cur / max) + 0.5))) or 0
  local widths, sumW, present = {}, 0, {}
  for i = 1, 3 do
    local v = segs[i] and (N(segs[i].cur) or 0) or 0
    present[i] = v > 0
    local w = (max > 0 and filled > 0) and math.floor(track * (v / max)) or 0
    if w < 0 then w = 0 end
    widths[i], sumW = w, sumW + w
  end
  local drift = filled - sumW
  if drift ~= 0 then
    for i = 3, 1, -1 do
      if widths[i] > 0 or (drift > 0 and present[i]) then
        widths[i] = math.max(0, widths[i] + drift)
        break
      end
    end
  end
  -- Rouge (niveau) : minimum par paliers, 1 px au niv. 1 -> 5 px au niv. 60.
  local redOn = present[1]
  present[1] = false
  widths, filled = ApplyMinWidths(widths, present, Wd.SEG_MIN_W or 5, track, filled)
  present[1] = redOn
  if redOn then
    local lvl = N(segs[1] and segs[1].cur) or 1
    local redMin = math.max(1, math.min(5, 1 + math.floor((math.max(1, lvl) - 1) * 4 / 59)))
    local need = redMin - (widths[1] or 0)
    if need > 0 then
      local room = track - filled
      local grow = math.min(need, math.max(0, room))
      widths[1] = (widths[1] or 0) + grow
      need = need - grow
      for i = 3, 2, -1 do
        if need <= 0 then break end
        local extra = (widths[i] or 0) - (Wd.SEG_MIN_W or 5)
        if extra > 0 then
          local take = math.min(extra, need)
          widths[i] = widths[i] - take
          widths[1] = widths[1] + take
          need = need - take
        end
      end
      filled = (widths[1] or 0) + (widths[2] or 0) + (widths[3] or 0)
    end
  end
  return widths, filled
end

-- Pose les 3 segments (largeurs = points / plafond du total) et la zone de survol.
-- 3.5.21 : le remplissage est inset dans la piste (après l'arrondi du cadre)
-- et chaque segment non nul a une largeur minimale visible.
function Wd.LayoutSegments(t, left, by, inner, bh, cur, max)
  local p = Wd.EnsureSegs(t)
  local segs = Segments()
  max = N(max) or 0
  cur = N(cur) or 0
  local il, ir, it, ib = Wd.FillInset()
  il, ir, it, ib = ClampInsets(il, ir, it, ib, inner, bh)
  local track = math.max(0, inner - il - ir)
  local fh = math.max(0, bh - it - ib)
  local fy = by + ib
  local widths, filled = Wd.SegmentWidths(segs, track, cur, max)
  local x = left + il
  local last
  for i = 1, 3 do
    local tex, w = p.segs[i], widths[i] or 0
    local c = Wd.SEG_COLORS[i]
    tex:ClearAllPoints()
    if w > 0 and fh > 0 then
      tex:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", x, fy)
      tex:SetSize(math.max(0.01, w), fh)
      if c then tex:SetVertexColor(c[1], c[2], c[3], c[4] or 1) end
      tex:Show()
      last, x = tex, x + w
    else
      tex:Hide()
    end
  end
  if p.hit then
    p.hit:ClearAllPoints()
    p.hit:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", left, by)
    p.hit:SetSize(math.max(1, inner), math.max(1, bh + 4))
    if p.hit.SetFrameLevel and t.GetFrameLevel then
      pcall(p.hit.SetFrameLevel, p.hit, (t:GetFrameLevel() or 1) + 3)
    end
    p.hit:Show()
  end
  if Wd.last then
    Wd.last.left, Wd.last.by, Wd.last.bh, Wd.last.inner = left, by, bh, inner
    Wd.last.filled, Wd.last.segs = filled, segs
    Wd.last.il, Wd.last.ir, Wd.last.it, Wd.last.ib = il, ir, it, ib
    Wd.last.track, Wd.last.fh, Wd.last.widths = track, fh, widths
  end
  return p, last
end

local ICON_PARTS = { "slotBg", "icon", "slotBorder", "hoverTex", "checkTex" }

-- 3.6.1 : en barre, aucun lavis blanc (icône, texte, jauge, fond).
-- Deux sources : hlTex (aplat ADD sur toute la case, posé au survol / à la
-- sélection) et hoverTex (strate HIGHLIGHT, que le client réaffiche tout
-- seul au survol d'un Button — Hide() ne suffit pas). Réservé à la case
-- carrée ; la barre garde son aspect normal, l'infobulle reste.
function Wd.MuteBarHighlight(t)
  if not t then return end
  if t.hlTex then t.hlTex:Hide() end
  if t.checkTex then t.checkTex:Hide() end
  local hi = t.hoverTex
  if hi then
    if hi.SetDrawLayer then pcall(hi.SetDrawLayer, hi, "ARTWORK", 0) end
    if hi.SetAlpha then pcall(hi.SetAlpha, hi, 0) end
    hi:Hide()
  end
  t._hlAlpha = nil
  if t.UnlockHighlight then pcall(t.UnlockHighlight, t) end
  if t.SetButtonState then pcall(t.SetButtonState, t, "NORMAL") end
end

function Wd.RestoreTileHighlight(t)
  if not t then return end
  local hi = t.hoverTex
  if hi then
    if hi.SetDrawLayer then pcall(hi.SetDrawLayer, hi, "HIGHLIGHT", 0) end
    if hi.SetAlpha then pcall(hi.SetAlpha, hi, 1) end
    hi:Hide()
  end
  if t.UnlockHighlight then pcall(t.UnlockHighlight, t) end
  if t.SetButtonState then pcall(t.SetButtonState, t, "NORMAL") end
end

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
  p.track:Show() p.text:Show()
  Wd.last = { w = w, h = h, cur = cur, max = max, pct = pct, inner = inner }
  Wd.LayoutSegments(t, left, by, inner, bh, cur, max)
  Wd.MuteBarHighlight(t)
end

local function Unwide(t)
  if not t._wideOn then return end
  t._wideOn, t._wideW, t._wideH = nil, nil, nil
  local p = t._wideParts
  if p then
    p.track:Hide()
    if p.fill then p.fill:Hide() end
    if p.segs then for i = 1, #p.segs do p.segs[i]:Hide() end end
    if p.hit then p.hit:Hide() end
    if p.sheen then p.sheen:Hide() end
    p.text:Hide()
  end
  if t.countFS then t.countFS:Show() end
  if t.countFS2 then t.countFS2:Show() end
  Wd.RestoreTileHighlight(t)
  if ns.View and ns.View.PaintTile then pcall(ns.View.PaintTile, t) end
end
Wd.Unwide = Unwide

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
  if on == nil then print(Tr["|cffffd100Dropamine|r : usage : /drop total on|off"]) return end
  local s = Wd.SetShown(on)
  print(Tr["|cffffd100Dropamine|r : Niveau total "] .. (s and Tr["affiché"] or Tr["masqué (grille recalculée sans lui)"]))
end
ns.HelpExt = ns.HelpExt or {}
ns.HelpExt[#ns.HelpExt + 1] = "/drop total on|off : afficher ou masquer la case Niveau total (barre fine en 3 colonnes)"

ns.DebugExt = ns.DebugExt or {}
ns.DebugExt[#ns.DebugExt + 1] = function()
  local e = UI.embed and UI.embed._wide
  local base = "— Barre Niveau total (3.5.1) — " .. (not Wd.Shown() and "masquée (/drop total off)" or e and string.format("pleine largeur %d px (%d colonnes, %d cases)", e.w, e.cols, e.n) or "case normale")
  local lines = { base }
  local segs = Wd.last and Wd.last.segs
  if segs then
    for i = 1, #segs do
      local s = segs[i]
      lines[#lines + 1] = string.format("  %s : %d / %d", s.label or "?", s.cur or 0, s.max or 0)
    end
  end
  return lines
end

-- 3.5.2 : au login, la grille était calculée avant la lecture de showTotal,
-- d'où une barre absente malgré la case cochée. On réapplique une fois la
-- session chargée (même chemin que décocher / recocher).
do
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  ev:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    local function apply() if Wd.Shown() then pcall(Wd.SetShown, true) end end
    if C_Timer and C_Timer.After then C_Timer.After(1, apply) C_Timer.After(3, apply) else apply() end
  end)
end

-- Dernier mot : même si une surbrillance est reposée après Paint (survol,
-- sélection, clic), la barre ne la garde pas.
do
  local V = ns.View
  if V and V.PaintTile then
    local base = V.PaintTile
    function V.PaintTile(t, ...)
      local r = { base(t, ...) }
      if t and t._wideOn then Wd.MuteBarHighlight(t) end
      return unpack(r)
    end
  end
end
