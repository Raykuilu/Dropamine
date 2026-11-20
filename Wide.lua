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
Wd.BAR_H = 4
Wd.PAD = 5
Wd.SLIM = 0.50      -- hauteur de la rangée = 50 % d'une case
Wd.MIN_H = 28
-- Référence à 40 px (100 %) : tout zoome uniformément avec la taille de case.
-- Polish.lua peut relever la référence (barre Flare 8, police 11, min 20).
Wd.REF_TILE  = 40
Wd.REF_BAR_H = 5          -- 0.125 × case (entre 0,12 et 0,15)
Wd.REF_PAD   = 5
Wd.REF_FONT  = 13         -- même rapport que le chiffre de case (COUNT_MAX)
Wd.REF_EDGE  = 3
Wd.MIN_BAR_H = 12
Wd.MIN_BAR_W = 60
Wd.MIN_FONT  = 13
Wd.MIN_PAD   = 3
Wd.MIN_ISZ   = 24
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

-- Mesures de la rangée total : zoom uniforme au-dessus de planchers ABSOLUS
-- (référence « medium » : barre 12 px, texte 13 px, fiole 24 px, rangée 28 px,
-- barre longue d'au moins 60 px). On ne réduit jamais la barre ni la police
-- pour les faire tenir dans une case trop petite : la rangée (et le cadre)
-- grandit. Polices posées en px (SetFont), jamais étirées par SetScale.
function Wd.Metrics(tile)
  tile = N(tile) or (ns.Icons and ns.Icons.TILE) or Wd.REF_TILE or 40
  local refT = Wd.REF_TILE or 40
  if refT <= 0 then refT = 40 end
  local k = tile / refT
  local function px(ref, minv)
    return math.max(minv or 0, math.floor((ref or 0) * k + 0.5))
  end
  local minH = Wd.MIN_H or 28
  local minBh = Wd.MIN_BAR_H or 12
  local minIsz = Wd.MIN_ISZ or 24
  local h = math.max(minH, math.floor(tile * (Wd.SLIM or 0.5) + 0.5))
  local bh = px(Wd.REF_BAR_H or Wd.BAR_H or 5, minBh)
  local pad = px(Wd.REF_PAD or Wd.PAD or 5, Wd.MIN_PAD or 3)
  -- Police du total : plus petite que le rang de case, jamais le plancher 13
  -- qui égalait ou dépassait le rang aux petites tailles.
  local sizes = I and I.NumberSizes and I.NumberSizes(tile) or nil
  local font = (sizes and sizes.total) or math.max(8, math.floor((Wd.REF_FONT or 11) * k + 0.5))
  local isz = math.max(minIsz, h - 2)
  -- Si le zoom donnerait une rangée trop basse, on l'agrandit (jamais l'inverse).
  h = math.max(h, isz + 2, bh + 2, font + 4)
  isz = math.max(minIsz, h - 2)
  local edge = px(Wd.REF_EDGE or Wd.EDGE_OUT or 3, 2)
  local I = ns.Icons
  return {
    tile = tile, k = k, h = h, bh = bh, pad = pad, font = font, isz = isz,
    minBarW = Wd.MIN_BAR_W or 60, edgeOut = edge,
    fontPath = (I and I.COUNT_PATH) or "Fonts\\ARIALN.TTF",
    fontFlags = (I and I.TEXT_FLAGS) or "",
  }
end
function Wd.RowHeight(tile)
  return Wd.Metrics(tile).h
end

-- Réserve de largeur pour « 0000 / 0000 » à la police courante (jamais réduite).
function Wd.ReserveTextW(font)
  font = font or 11
  -- Arial Narrow ~0,62 em, 12 glyphes, + 8 px de marge pour ne pas sous-estimer.
  return math.max(56, math.floor((font or 11) * 12 * 0.62 + 8.5))
end

-- Largeur minimale de la rangée : fiole | texte (taille pleine) | barre (>= 60 px).
-- Le cadre doit atteindre au moins cette largeur (il grandit si les cases sont petites).
function Wd.MinRowWidth(m, tw)
  m = m or (Wd.Metrics and Wd.Metrics()) or {}
  local isz = math.max(m.isz or 24, Wd.MIN_ISZ or 24)
  local slotW = isz + 2
  local pad = m.pad or Wd.MIN_PAD or 3
  local edge = m.edgeOut or 0
  local minBar = Wd.MIN_BAR_W or 60
  if type(tw) ~= "number" or tw <= 0 then
    tw = Wd.ReserveTextW(m.font)
  end
  return slotW + 3 * pad + 2 * edge + tw + minBar
end

-- Disposition fixe : fiole | texte à la police de référence (jamais réduite) |
-- barre d'au moins MIN_BAR_W. Pas de superposition, pas de texte tassé.
-- Si w est trop étroit, le plan utilise minW (le cadre doit avoir grandi).
function Wd.PlanTotalRow(w, m, twOf)
  m = m or (Wd.Metrics and Wd.Metrics()) or {}
  w = math.max(0, math.floor((w or 0) + 0.5))
  local isz = math.max(m.isz or 24, Wd.MIN_ISZ or 24)
  local slotW = isz + 2
  local pad = m.pad or Wd.MIN_PAD or 3
  local edge = m.edgeOut or 0
  local font = m.font or (I and I.NumberSizes and I.NumberSizes(m.tile).total) or 11
  local bh = math.max(m.bh or 0, Wd.MIN_BAR_H or 12)
  local h = math.max(m.h or 0, Wd.MIN_H or 28)
  local minBar = Wd.MIN_BAR_W or 60
  local tw
  if type(twOf) == "function" then
    tw = N(twOf(font)) or 0
  else
    tw = N(twOf) or 0
  end
  if tw <= 0 then tw = Wd.ReserveTextW(font) end
  local minW = Wd.MinRowWidth(m, tw)
  local used = w
  if used < minW then used = minW end
  local gap = pad + edge
  local left = slotW + pad + tw + gap
  local inner = used - left - pad - edge
  if inner < minBar then inner = minBar end
  left = math.floor(left + 0.5)
  inner = math.floor(inner + 0.5)
  local by = math.floor((h - bh) / 2 + 0.5)
  local textX = slotW + pad
  return {
    isz = isz, slotW = slotW, pad = pad, edge = edge, font = font, tw = tw,
    left = left, inner = inner, overlay = false, minBar = minBar, minW = minW,
    after = used - slotW - 2 * pad - edge, bh = bh, by = by, h = h, w = used,
    textX = textX,
  }
end

function Wd.PlaceTotalRow(t, p, m, w, h, cur, max)
  if not (t and p and p.text and p.track) then return nil end
  m = m or Wd.Metrics((ns.Icons and ns.Icons.TILE) or h)
  -- Toujours Arial Narrow + ombre de case, jamais la face du modèle de police.
  local path = (I and I.COUNT_PATH) or m.fontPath or "Fonts\\ARIALN.TTF"
  local flags = (I and I.TEXT_FLAGS) or m.fontFlags or ""
  local label = string.format("%d / %d", N(cur) or 0, N(max) or 0)
  if p.text.SetText then p.text:SetText(label) end
  local function twOf(sz)
    if I and I.ApplyNumberFont then
      I.ApplyNumberFont(p.text, sz)
    elseif p.text.SetFont and path then
      pcall(p.text.SetFont, p.text, path, sz, flags)
      if I and I.CleanText then I.CleanText(p.text) end
    end
    local okW, tw = pcall(p.text.GetStringWidth, p.text)
    tw = (okW and N(tw)) or 56
    if tw < 0 then tw = 0 end
    return tw
  end
  local plan = Wd.PlanTotalRow(w, m, twOf)
  -- Repose la police retenue (Plan a déjà mesuré via twOf, donc SetFont est à jour
  -- sauf si la 1re taille convenait : on la remet pour être sûr).
  if p.text.SetFont and path then
    pcall(p.text.SetFont, p.text, path, plan.font, flags or "")
  end
  p._fontH = plan.font
  if p.text.ClearAllPoints then p.text:ClearAllPoints() end
  -- Texte à gauche de la barre, jamais superposé, à la police planifiée (plancher 13 px).
  p.text:SetPoint("LEFT", t, "LEFT", plan.textX, 0)
  if p.track.ClearAllPoints then p.track:ClearAllPoints() end
  p.track:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", plan.left, plan.by)
  p.track:SetSize(plan.inner, plan.bh)
  plan.path, plan.flags, plan.label = path, flags, label
  return plan
end

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
  -- Barre fine sur toute la largeur dès que le total est affiché en plus d'une
  -- colonne (le total est isolé sur sa propre rangée par GroupTiles).
  if not Wd.Shown() then return false end
  return cols > 1 and n > 1
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
  if ns.Slot and ns.Slot.StopTipTicker then pcall(ns.Slot.StopTipTicker) end
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
function Wd.FillTotalTip(tt, noMini)
  if not tt then return end
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
  if ns.Flight and ns.Flight.ShowPauseTip and ns.Flight.ShowPauseTip() then
    tt:AddLine(Tr["En pause pendant le vol"], 1, 0.82, 0)
    tt:AddLine(Tr["Le scan reprend dès l'atterrissage."], 1, 1, 1)
  end
  if not noMini and ns.ProgressUI then
    tt:AddLine(Tr["Clic : fenêtre Progression"], 0.6, 0.8, 1)
  end
end

function Wd.ShowBarTip(owner, noMini)
  local tt = _G.GameTooltip
  if not (tt and owner) then return end
  pcall(tt.SetOwner, tt, owner, "ANCHOR_TOP")
  if tt.ClearLines then tt:ClearLines() end
  local S = ns.Slot
  local hasState = S and S.FillStateTip and S.FillStateTip(tt)
  if hasState and tt.AddLine then tt:AddLine(" ") end
  Wd.FillTotalTip(tt, noMini)
  tt:Show()
  if not noMini and ns.ProgressUI and ns.ProgressUI.ShowMini then pcall(ns.ProgressUI.ShowMini, tt, owner) end
  if S and S.StartTipTicker then
    S.StartTipTicker(owner, function() Wd.ShowBarTip(owner, noMini) end)
  end
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
  local m = Wd.Metrics((ns.Icons and ns.Icons.TILE) or h)
  if (N(t._wideH) or 0) > 0 then h = N(t._wideH) end
  local isz = m.isz
  local slotW = isz + 2
  local iconX = math.floor(slotW / 2 + 0.5)
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
  local plan = Wd.PlaceTotalRow(t, p, m, w, h, cur, max)
  local pad = (plan and plan.pad) or m.pad
  local edge = (plan and plan.edge) or m.edgeOut or 0
  local left = (plan and plan.left) or 0
  local inner = (plan and plan.inner) or 0
  local bh = (plan and plan.bh) or m.bh
  local by = (plan and plan.by) or 0
  isz = (plan and plan.isz) or isz
  if p.track.SetVertexColor then
    p.track:SetVertexColor(Wd.TRACK[1], Wd.TRACK[2], Wd.TRACK[3], Wd.TRACK[4])
  end
  p.track:Show() p.text:Show()
  Wd.last = { w = w, h = h, cur = cur, max = max, pct = pct, inner = inner,
    left = left, by = by, bh = bh, isz = isz, pad = pad, font = plan and plan.font or m.font,
    edgeOut = edge, overlay = plan and plan.overlay, minBar = plan and plan.minBar,
    after = plan and plan.after, textX = plan and plan.textX }
  Wd.LayoutSegments(t, left, by, inner, bh, cur, max)
  Wd.MuteBarHighlight(t)
end

-- Un état ne remplace que l'icône de la fiole : la barre et le texte restent.
local _paintBar = Wd.Paint
function Wd.Paint(t)
  _paintBar(t)
  local S = ns.Slot
  if not (t and S and S.ReplacesFlaskIcon and S.ReplacesFlaskIcon(t)) then return end
  if t.icon and t.icon.Hide then t.icon:Hide() end
  if S.Active and S.Active() == "rested" and S.ApplyRestIcon then
    S.ApplyRestIcon(t)
  end
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
    if t._hgHit and t._hgHit.Hide then pcall(t._hgHit.Hide, t._hgHit) end
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
  local gw
  local Lyt = ns.Layout
  if Lyt and Lyt.GridSize then
    gw = Lyt.GridSize(cols)
  end
  if not gw or gw <= 0 then
    gw = stepX and ((cols - 1) * stepX + tw) or maxR or tw
  end
  local ok, _, _, _, _, y = pcall(total.GetPoint, total, 1)
  y = (ok and N(y)) or 0
  total:ClearAllPoints()
  total:SetPoint("TOPLEFT", total:GetParent() or wrap, "TOPLEFT", 0, y)
  local sh = (Wd.RowHeight and Wd.RowHeight(th)) or math.max(Wd.MIN_H, math.floor(th * Wd.SLIM + 0.5))
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
  local function without_total(gs)
    local out = {}
    for _, g in ipairs(gs) do
      local copy = {}
      for _, d in ipairs(g.tiles) do if d.kind ~= "total" then copy[#copy + 1] = d end end
      if #copy > 0 then out[#out + 1] = { title = g.title, tiles = copy, flat = g.flat } end
    end
    return out
  end
  if not Wd.Shown() then return without_total(groups) end
  -- Isoler le total sur sa propre rangée pour l'étirer en barre fine.
  local cols = (ns.Layout and ns.Layout.Cols and ns.Layout.Cols()) or 1
  if cols <= 1 then return groups end
  local skills, total
  local out = {}
  for _, g in ipairs(groups) do
    local copy, found = {}, nil
    for _, d in ipairs(g.tiles) do
      if d.kind == "total" then found = d else copy[#copy + 1] = d end
    end
    if found then total = found end
    if #copy > 0 then out[#out + 1] = { title = g.title, tiles = copy, flat = g.flat } end
  end
  if total then out[#out + 1] = { title = "", tiles = { total }, flat = true } end
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
if P then
  function P.CompactListHeight()
    if L and L.ContentSize then
      local _, _, _, _, gh, cols, rows = L.ContentSize()
      return gh, cols, rows
    end
    local n = NTiles()
    local cols = (L and L.Cols and L.Cols()) or 1
    local rows = math.max(1, math.ceil(n / cols))
    return rows * I.STEP, cols, rows
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
      if t and t.data and t.data.kind == "total" and Wd.SyncHourglass then pcall(Wd.SyncHourglass, t) end
      return unpack(r)
    end
  end
end


-- 3.6.3 : sablier animé sur la fiole du total pendant la pause en vol.
-- Feuille de 32 images (Media/Hourglass-Sheet, 8×4 cases de 64 px) parcourue
-- par SetTexCoord. Une seule texture, calée exactement sur la goutte
-- (SetAllPoints), sous le cadre bronze (ARTWORK). Pas d'AnimationGroup,
-- pas de SetRotation (le retournement est pré-rendu, 6 images / 0,4 s).
-- Un seul OnUpdate à 20 im/s, arrêté dès que tout est caché.
do
  local F = ns.Flight
  if not F then return end
  local N = function(v) return ns.N and ns.N(v) or tonumber(v) end
  F.SAND_DUR, F.FLIP_DUR, F.CYCLE = 2.6, 0.4, 3.0
  F.HG_FPS, F.HG_STEP = 20, 0.05
  F.DIM_TARGET, F.FADE_DUR = 0.75, 0.5
  F.SAND_FRAMES, F.FLIP_FRAMES, F.SHEET_N = 26, 6, 32
  F.SHEET_COLS, F.SHEET_ROWS = 8, 4
  F.TEX_SHEET = "Interface\\AddOns\\Dropamine\\Media\\Hourglass-Sheet"
  F.TEX_ICON  = "Interface\\AddOns\\Dropamine\\Media\\Hourglass"
  F.TEX_FRAME = F.TEX_ICON

  function F.Phase(t)
    t = (N(t) or 0) % F.CYCLE
    if t < 0 then t = 0 end
    if t < F.SAND_DUR then return "sand", t / F.SAND_DUR end
    return "flip", (t - F.SAND_DUR) / math.max(1e-6, F.FLIP_DUR)
  end

  function F.SheetIndex(t)
    t = (N(t) or 0) % F.CYCLE
    if t < 0 then t = 0 end
    if t < F.SAND_DUR then
      local i = math.floor((t / F.SAND_DUR) * F.SAND_FRAMES)
      if i < 0 then i = 0 end
      if i >= F.SAND_FRAMES then i = F.SAND_FRAMES - 1 end
      return i
    end
    local p = (t - F.SAND_DUR) / math.max(1e-6, F.FLIP_DUR)
    local i = math.floor(p * F.FLIP_FRAMES)
    if i < 0 then i = 0 end
    if i >= F.FLIP_FRAMES then i = F.FLIP_FRAMES - 1 end
    return F.SAND_FRAMES + i
  end

  function F.SheetTexCoord(i)
    i = math.floor(N(i) or 0) % F.SHEET_N
    local col = i % F.SHEET_COLS
    local row = math.floor(i / F.SHEET_COLS)
    return col / F.SHEET_COLS, (col + 1) / F.SHEET_COLS,
           row / F.SHEET_ROWS, (row + 1) / F.SHEET_ROWS
  end

  function F.DimMul()
    return F._dim or 1
  end
  function F.ShowPauseTip()
    return (F._vis or 0) > 0.12 or F.Paused()
  end

  function Wd.TotalTile()
    local wrap = ns.UI and ns.UI.embed
    if not (wrap and wrap.tiles) then return nil end
    for _, t in ipairs(wrap.tiles) do
      if t.data and t.data.kind == "total" and t.IsShown and t:IsShown() then return t end
    end
    return nil
  end

  function Wd.EnsureHourglass(t)
    if t._hg then return t._hg end
    if not t.CreateTexture then return nil end
    local ok, h = pcall(t.CreateTexture, t, nil, "ARTWORK", nil, 4)
    if not (ok and h) then return nil end
    h:Hide()
    pcall(h.SetTexture, h, F.TEX_SHEET)
    t._hg = h
    return h
  end

  local function IconWH(t)
    local w, ht = 14, 14
    if t.icon then
      if t.icon.GetWidth then w = N(t.icon:GetWidth()) or w end
      if t.icon.GetHeight then ht = N(t.icon:GetHeight()) or w end
    elseif t._wideH then
      w = math.max(8, (N(t._wideH) or 16) - 2)
      ht = w
    end
    return w, ht
  end

  local function PlaceOnIcon(h, t)
    h:ClearAllPoints()
    local w, ht = IconWH(t)
    if t.icon then
      -- Même ancre que la goutte ; SetSize ensuite pour que la taille suive
      -- même si SetAllPoints est un no-op (harness de test).
      if h.SetAllPoints then pcall(h.SetAllPoints, h, t.icon) end
      h:SetPoint("CENTER", t.icon, "CENTER", 0, 0)
    else
      local iconX = math.floor((t._wideH or w) / 2 + 0.5)
      h:SetPoint("CENTER", t, "LEFT", iconX, 0)
    end
    if h.SetSize then h:SetSize(w, ht) end
  end

  function Wd.ApplyHourglassTo(t, vis)
    if not t then return nil end
    vis = vis or 0
    local want = vis > 0.01
    local h = t._hg or (want and Wd.EnsureHourglass(t))
    if not h then return nil end
    if not want then
      if h.Hide then h:Hide() end
      if t.icon and t.icon.SetAlpha then pcall(t.icon.SetAlpha, t.icon, 1) end
      if t._hgIconHidden and t.icon and t.icon.Show then pcall(t.icon.Show, t.icon) end
      t._hgIconHidden = nil
      Wd.SyncFlaskHit(t, vis)
      return h
    end
    PlaceOnIcon(h, t)
    if t.icon then
      if t.icon.SetAlpha then pcall(t.icon.SetAlpha, t.icon, 1 - vis) end
      t._hgIconHidden = true
    end
    if h.SetAlpha then pcall(h.SetAlpha, h, vis) end
    if h.SetTexture then pcall(h.SetTexture, h, F.TEX_SHEET) end
    local t0 = F._cycle0 or 0
    local now = (type(GetTime) == "function" and GetTime()) or 0
    local idx = F.SheetIndex(now - t0)
    if h.SetTexCoord then
      local u0, u1, v0, v1 = F.SheetTexCoord(idx)
      pcall(h.SetTexCoord, h, u0, u1, v0, v1)
    end
    if h.Show then h:Show() end
    h._idx = idx
    Wd.SyncFlaskHit(t, vis)
    return h
  end

  function Wd.SyncHourglass(t)
    Wd.ApplyHourglassTo(t, F._vis or 0)
  end

  function Wd.ApplyHourglass()
    local t = Wd.TotalTile()
    if t then return Wd.ApplyHourglassTo(t, F._vis or 0) end
    return nil
  end

  function F.TickVisual(_, elapsed)
    F._acc = (F._acc or 0) + (N(elapsed) or 0)
    if F._acc < F.HG_STEP then return end
    local dt = math.min(F._acc, 0.25)
    F._acc = 0
    F._steps = (F._steps or 0) + 1
    local target = F.Paused() and 1 or 0
    local vis = F._vis or 0
    if vis ~= target then
      local dir = (target > vis) and 1 or -1
      vis = vis + dir * dt / F.FADE_DUR
      if dir > 0 and vis > 1 then vis = 1 end
      if dir < 0 and vis < 0 then vis = 0 end
      F._vis = vis
    else
      F._vis = target
    end
    F._dim = 1 - (1 - F.DIM_TARGET) * (F._vis or 0)
    if F.Paused() and not F._cycle0 then
      F._cycle0 = ((type(GetTime) == "function" and GetTime()) or 0)
    end
    if not F.Paused() and (F._vis or 0) <= 0 then F._cycle0 = nil end
    local slot = ns.Slot
    if slot and slot.Tick then
      pcall(slot.Tick, dt)
    else
      local act = (slot and slot.Active and slot.Active()) or "drop"
      local flightSym = (slot and slot.Want and slot.Want("flight")) or (not slot and F.Paused())
      if flightSym or (act == "drop" and (F._vis or 0) > 0) then
        Wd.ApplyHourglass()
      elseif slot and slot.ApplyTotal then
        pcall(slot.ApplyTotal)
      end
    end
    if ns.Panel and ns.Panel.ApplyOpacity then pcall(ns.Panel.ApplyOpacity) end
    local need = ((F._vis or 0) > 0) or F.Paused() or (slot and slot.NeedsDriver and slot.NeedsDriver())
    if not need then F.StopVisualDriver() end
  end

  function F.StopVisualDriver()
    local f = F._visFrame
    if f then
      if f.SetScript then pcall(f.SetScript, f, "OnUpdate", nil) end
      if f.Hide then f:Hide() end
    end
    F._visDriving = false
    local Lyt = ns.Layout
    if Lyt and Lyt.SnapToContent then pcall(Lyt.SnapToContent) end
  end

  function F.StartVisualDriver()
    if not F._visFrame then
      local ok, f = pcall(CreateFrame, "Frame", "DropamineFlightHourglass")
      if not (ok and f) then return nil end
      f:Hide()
      F._visFrame = f
    end
    local f = F._visFrame
    F._acc = 0
    if f.SetScript then pcall(f.SetScript, f, "OnUpdate", F.TickVisual) end
    if f.Show then f:Show() end
    F._visDriving = true
    return f
  end

  function F.BeginVisual()
    F._cycle0 = (type(GetTime) == "function" and GetTime()) or 0
    F.StartVisualDriver()
  end
  function F.EndVisual()
    F.StartVisualDriver()
  end

  function F.ShowPauseExplanation(owner)
    local tt = _G.GameTooltip
    if not (tt and owner) then return end
    if type(tt.SetOwner) == "function" then pcall(tt.SetOwner, tt, owner, "ANCHOR_RIGHT") end
    if type(tt.ClearLines) == "function" then pcall(tt.ClearLines, tt) end
    if type(tt.SetText) == "function" then
      pcall(tt.SetText, tt, Tr["En pause pendant le vol"], 1, 0.82, 0)
    elseif type(tt.AddLine) == "function" then
      pcall(tt.AddLine, tt, Tr["En pause pendant le vol"], 1, 0.82, 0, true)
    end
    if type(tt.AddLine) == "function" then
      pcall(tt.AddLine, tt, Tr["Le scan reprend dès l'atterrissage."], 1, 1, 1, true)
    end
    if type(tt.Show) == "function" then pcall(tt.Show, tt) end
  end

  function Wd.EnsureFlaskHit(t)
    if not t then return nil end
    if t._hgHit then return t._hgHit end
    local ok, hit = pcall(CreateFrame, "Frame", nil, t)
    if not (ok and hit) then return nil end
    if type(hit.EnableMouse) == "function" then pcall(hit.EnableMouse, hit, true) end
    hit:SetScript("OnEnter", function(self)
      if ns.Slot and ns.Slot.ShowExplanation then pcall(ns.Slot.ShowExplanation, self)
      elseif F.ShowPauseExplanation then pcall(F.ShowPauseExplanation, self) end
    end)
    hit:SetScript("OnLeave", function(self)
      if ns.Slot and ns.Slot.StopTipTicker then pcall(ns.Slot.StopTipTicker) end
      local tt = _G.GameTooltip
      if not tt then return end
      if type(tt.IsOwned) == "function" then
        local okO, owned = pcall(tt.IsOwned, tt, self)
        if okO and not owned then return end
      end
      if type(tt.Hide) == "function" then pcall(tt.Hide, tt) end
    end)
    -- le survol capte la souris ; le clic est renvoyé à la case ( Progressive / partage ).
    hit:SetScript("OnMouseUp", function(self, button)
      local fn = t.GetScript and (t:GetScript("OnMouseUp") or t:GetScript("OnClick"))
      if fn then pcall(fn, t, button) end
    end)
    t._hgHit = hit
    return hit
  end

  function Wd.SyncFlaskHit(t, vis)
    if not t then return nil end
    local slot = ns.Slot
    local act = slot and slot.Active and slot.Active()
    local combatTip = slot and slot.CombatLiquidOn and slot.CombatLiquidOn()
      and ((slot.LiveCombat and slot.LiveCombat()) or (slot.fill and (slot.fill.p or 0) > 0.05))
    local want = F.Paused() or ((vis or F._vis or 0) > 0.01) or (act and act ~= "drop") or combatTip
    local hit = t._hgHit or (want and Wd.EnsureFlaskHit(t))
    if not hit then return nil end
    if not want then
      if type(hit.Hide) == "function" then pcall(hit.Hide, hit) end
      local tt = _G.GameTooltip
      if tt and type(tt.IsOwned) == "function" then
        local okO, owned = pcall(tt.IsOwned, tt, hit)
        if okO and owned and type(tt.Hide) == "function" then pcall(tt.Hide, tt) end
      end
      return hit
    end
    if type(hit.ClearAllPoints) == "function" then pcall(hit.ClearAllPoints, hit) end
    -- Uniquement sur l'icône : jamais la case entière (ça recouvre le compteur
    -- et déclenche l'infobulle dès que la souris est sur la case voisine).
    local anchor = t.icon or t.iconSlot or t
    if type(hit.SetPoint) == "function" and anchor then
      pcall(hit.SetPoint, hit, "CENTER", anchor, "CENTER", 0, 0)
    end
    local w, ht = IconWH(t)
    if ns.Slot and ns.Slot.IconInnerSize then
      local iw, ih = ns.Slot.IconInnerSize(t)
      if iw and ih then w, ht = iw, ih end
    end
    if type(hit.SetSize) == "function" then pcall(hit.SetSize, hit, math.max(8, w), math.max(8, ht)) end
    if type(hit.SetFrameLevel) == "function" and type(t.GetFrameLevel) == "function" then
      pcall(hit.SetFrameLevel, hit, (t:GetFrameLevel() or 1) + 6)
    end
    local mouse = not (slot and slot._suppressTip)
    if type(hit.EnableMouse) == "function" then pcall(hit.EnableMouse, hit, mouse and true or false) end
    if type(hit.Show) == "function" then pcall(hit.Show, hit) end
    return hit
  end

  local baseBegin, baseEnd = F.OnBegin, F.OnEnd
  function F.OnBegin()
    -- Sablier d'abord, puis le reste (toasts / astuce) sous pcall.
    pcall(F.BeginVisual)
    if baseBegin then pcall(baseBegin) end
  end
  function F.OnEnd()
    if baseEnd then pcall(baseEnd) end
    pcall(F.EndVisual)
  end
end
