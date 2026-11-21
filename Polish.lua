-- Dropamine 3.3.17 : finitions « cohérence FlareUI ».
--  • Pastille « N prêt(s) » = petite PLAQUE FlareUI : fond sombre, filet bronze
--    de 1 px + ombre noire de 1 px, texte or Arial Narrow 9 px. Posée ENTIÈRE dans
--    l'écart au-dessus de la case (Theme.BADGE_OVERLAP = -1, Icons.VGAP = 12) :
--    elle ne mord plus ni la case, ni la case du dessus, ni le bord du panneau
--    (marge du haut agrandie par Theme.TopExtra quand une 1re rangée en porte une).
--    Jamais plus large que case + écart (police réduite si besoin).
--  • Chiffres de case : hiérarchie rang (grand, blanc) / « /max » (≈ 78 %, atténué),
--    même ombre nette partout, retrait 4 px dans le biseau, maxima ≥ 10 000
--    abrégés (« /25k ») ; léger dégradé sombre sous les chiffres (texture fixe,
--    masquée comme l'icône) pour la lisibilité sur icône claire.
--  • Barre « Niveau total » : jauge façon FlareUI (piste Media/Dropamine-Bar grise 0.15,
--    remplissage jeton #A67D45 + reflet 1 px, filet Media/Dropamine-Thin bronze), 8 px de haut,
--    icône et texte centrés verticalement, barre 20 px.
-- Aucun OnUpdate : tout est posé aux mises à jour de case / de mise en page.
local _, ns = ...
local UI, I, Th, Wd = ns.UI, ns.Icons, ns.Theme, ns.Wide
local Po = {}
ns.Polish = Po
local MEDIA = "Interface\\AddOns\\Dropamine\\Media\\"
local function N(v) return ns.N and ns.N(v) or tonumber(v) end
Po.stats = { badges = 0, counts = 0, gauges = 0 }

------------------------------------------------------------------------------
-- 1. Chiffres
------------------------------------------------------------------------------
Po.MAX_K = 0.78          -- « /max » ≈ 78 % du rang
Po.MAX_DIM = { 0.80, 0.76, 0.68 }   -- facteur appliqué à la couleur du rang
Po.SHADE_A = 0.55        -- dégradé sous les chiffres (bas de l'icône)
Po.SHADE_K = 0.55        -- hauteur : 55 % de l'icône
function Po.ShortMax(text)
  if type(text) ~= "string" then return text end
  local a, m = text:match("^(%d+)/(%d+)$")
  m = m and tonumber(m)
  if not (a and m and m >= 10000) then return text end
  local s = (m % 1000 == 0) and string.format("%dk", m / 1000) or string.format("%.1fk", m / 1000)
  return a .. "/" .. s
end
local function W8(x)
  local ok = x.SetColorTexture and pcall(x.SetColorTexture, x, 1, 1, 1, 1)
  if not ok then pcall(x.SetTexture, x, "Interface\\Buttons\\WHITE8X8") end
end
local function Gradient(x, a)
  -- bas opaque → haut transparent ; API moderne puis ancienne
  local ok = false
  if x.SetGradient and type(_G.CreateColor) == "function" then
    ok = pcall(x.SetGradient, x, "VERTICAL", _G.CreateColor(0, 0, 0, a), _G.CreateColor(0, 0, 0, 0))
  end
  if not ok and x.SetGradientAlpha then ok = pcall(x.SetGradientAlpha, x, "VERTICAL", 0, 0, 0, a, 0, 0, 0, 0) end
  if not ok and x.SetVertexColor then pcall(x.SetVertexColor, x, 0, 0, 0, a * 0.5) end
  return ok
end
function Po.Shade(t)
  local icon = t and t.icon
  if not icon then return nil end
  local s = t._numShade
  if not s then
    s = t:CreateTexture(nil, "ARTWORK", nil, 7)
    W8(s)
    Gradient(s, Po.SHADE_A)
    local m = icon._thMask
    if m and s.AddMaskTexture then pcall(s.AddMaskTexture, s, m) end
    t._numShade = s
  end
  local _, ih = icon.GetSize and icon:GetSize()
  ih = N(ih) or I.ICON or 36
  s:ClearAllPoints()
  s:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 0, 0)
  s:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
  s:SetHeight(math.max(4, math.floor(ih * Po.SHADE_K + 0.5)))
  if t._wideOn then s:Hide() else s:Show() end
  return s
end
local function Width(fs)
  local ok, v = pcall(fs.GetStringWidth, fs)
  return (ok and N(v)) or 0
end
if I and I.FitCount then
  local baseFit = I.FitCount
  function I.FitCount(t, text, ...)
    -- maxima abrégés : la base mesure une chaîne de chiffres de MÊME longueur
    local short = Po.ShortMax(text)
    local probe = text
    if short ~= text then probe = short:match("^(%d+)/") .. "/" .. string.rep("8", #short:match("/(.+)$")) end
    local size = baseFit(t, probe, ...)
    local fs, fs2 = t.countFS, t.countFS2
    if not (fs and fs2) then return size end
    if short ~= text and t._countBottom then
      local b = short:match("(/.+)$")
      fs2:SetText(b)
      t._countBottom = b
      t._countText = (t._countTop or "") .. "\n" .. b
    end
    Po.stats.counts = Po.stats.counts + 1
    local flags = I.TEXT_FLAGS or ""
    if t._countBottom then
      local box = t._countBoxW or (I.TILE - 2 * I.COUNT_INSET)
      local s2 = math.max(7, math.floor(size * Po.MAX_K + 0.5))
      pcall(fs2.SetFont, fs2, I.COUNT_PATH, s2, flags)
      I.CleanText(fs2)
      if fs2.SetHeight then pcall(fs2.SetHeight, fs2, s2 + 1) end
      -- le « /max » rétréci libère de la place : le rang grossit (jusqu'à COUNT_MAX)
      local s1 = size
      local _, th = t.GetSize and t:GetSize()
      local availH = (N(th) or I.TILE) - 2 * I.COUNT_INSET
      while s1 < (I.COUNT_MAX or 13) do
        pcall(fs.SetFont, fs, I.COUNT_PATH, s1 + 1, flags)
        if Width(fs) > box or (s1 + 1) + s2 + 3 > availH then pcall(fs.SetFont, fs, I.COUNT_PATH, s1, flags) break end
        s1 = s1 + 1
      end
      pcall(fs.SetFont, fs, I.COUNT_PATH, s1, flags)
      I.CleanText(fs)
      if fs.SetHeight then pcall(fs.SetHeight, fs, s1 + 1) end
      -- rapproche les deux lignes (le rang « posé » sur le /max)
      fs:ClearAllPoints()
      fs:SetPoint("BOTTOMLEFT", fs2, "TOPLEFT", 0, -1)
      fs:SetPoint("BOTTOMRIGHT", fs2, "TOPRIGHT", 0, -1)
      t._countSize, t._countSize2 = s1, s2
      size = s1
    else
      t._countSize2 = nil
    end
    Po.Shade(t)
    if t._countColor then I.SetCountColor(t, t._countColor[1], t._countColor[2], t._countColor[3]) end
    return size
  end
end
if I and I.SetCountColor then
  local baseColor = I.SetCountColor
  function I.SetCountColor(t, r, g, b, ...)
    local res = { baseColor(t, r, g, b, ...) }
    t._countColor = { r, g, b }
    if t.countFS2 and r then
      local k = Po.MAX_DIM
      t.countFS2:SetTextColor(r * k[1], g * k[2], b * k[3])
    end
    return unpack(res)
  end
end

------------------------------------------------------------------------------
-- 2. Pastille « N prêt(s) » : plaque FlareUI
------------------------------------------------------------------------------
Po.BADGE_BG = { 0.06, 0.05, 0.04, 0.94 }
Po.BADGE_TEXT = { 1.00, 0.82, 0.00 }
Po.BADGE_FONT = 9
Po.BADGE_PADX = 3
function Po.StyleBadge(t)
  local b = t and t.craftBadge
  if not (b and b.fs) then return nil end
  if not b._po then
    b._po = true
    if b.bg then pcall(b.bg.SetVertexColor, b.bg, Po.BADGE_BG[1], Po.BADGE_BG[2], Po.BADGE_BG[3], Po.BADGE_BG[4]) end
    -- ombre noire 1 px autour du filet bronze (même recette que le biseau des icônes)
    local sh = b:CreateTexture(nil, "BACKGROUND", nil, -2)
    W8(sh)
    sh:SetPoint("TOPLEFT", -2, 2) sh:SetPoint("BOTTOMRIGHT", 2, -2)
    sh:SetVertexColor(0, 0, 0, 0.70)
    b.shadow = sh
    if b.edge then
      local B = ns.STYLE and ns.STYLE.BORDER or { 0.65, 0.49, 0.27 }
      pcall(b.edge.SetVertexColor, b.edge, B[1], B[2], B[3], 1)
    end
  end
  local size = Po.BADGE_FONT
  local maxW = (I.TILE or 40) + (I.HGAP or 8) - 6     -- jamais sur la plaque voisine
  local function fit()
    pcall(b.fs.SetFont, b.fs, I.COUNT_PATH or "Fonts\\ARIALN.TTF", size, "")
    I.CleanText(b.fs)
    return Width(b.fs)
  end
  local w = fit()
  while size > 7 and w + 2 * Po.BADGE_PADX > maxW do size = size - 1 w = fit() end
  if w <= 0 then w = 5 * #(b._text or "x") end
  b.fs:SetTextColor(Po.BADGE_TEXT[1], Po.BADGE_TEXT[2], Po.BADGE_TEXT[3])
  b.fs:ClearAllPoints()
  b.fs:SetPoint("CENTER", b, "CENTER", 0, 0)
  local bh = (Th and Th.BADGE_H) or 10
  b:SetSize(math.min(maxW, math.ceil(w) + 2 * Po.BADGE_PADX), bh)
  b._fontSize = size
  Po.stats.badges = Po.stats.badges + 1
  return b
end
if UI and UI.UpdateCraftBadge then
  local baseBadge = UI.UpdateCraftBadge
  function UI:UpdateCraftBadge(t, ...)
    local r = { baseBadge(self, t, ...) }
    if t and t.craftBadge and t.craftBadge.IsShown and t.craftBadge:IsShown() then Po.StyleBadge(t) end
    return unpack(r)
  end
end

------------------------------------------------------------------------------
-- 3. Barre « Niveau total » : jauge FlareUI
------------------------------------------------------------------------------
if Wd then
  Wd.TEX = MEDIA .. "Dropamine-Bar"             -- piste (notre art gris, tools/make_frame_border.py)
  Wd.FILL_TEX = "Interface\\Buttons\\WHITE8X8"  -- remplissage : jeton pur, sans assombrir
  Wd.BAR_H = 8
  Wd.PAD = 6
  Wd.SLIM = 0.5
  Wd.MIN_H = 25      -- rangée = glyphe de fiole (~70 % de la case 36)
  Wd.MIN_BAR_H = 12
  Wd.MIN_BAR_W = 100
  Wd.MIN_FONT = nil  -- le total suit I.NumberSizes (plus petit que le rang)
  Wd.MIN_ISZ = 32    -- 3.7.2 : taille des icônes de case (plancher I.ICON_MIN)
  Wd.ICON_K = 0.90   -- repli ; Wd.IconSize suit I.ICON / I.TILE
  -- Référence 100 % (zoom uniforme au-dessus des planchers absolus).
  Wd.REF_BAR_H = 8
  Wd.REF_PAD = 6
  Wd.REF_FONT = 11
  Wd.TEXT_SIZE = nil
  Wd.FILL = ns.STYLE.BORDER               -- jeton unique #A67D45 (STYLE.md)
  Wd.SHEEN_A = 0.28                       -- reflet 1 px en haut du remplissage
  Wd.TRACK = { 0.15, 0.15, 0.15, 0.9 }    -- piste FlareUI
  Wd.EDGE_TEX = MEDIA .. "Dropamine-Thin"       -- notre filet fin (même tracé que le bord du panneau)
  Wd.EDGE_SIZE = 8                        -- FlareUI : BorderEdgeSize(Thin, 16) = 8
  Wd.EDGE_OUT = 3                         -- le filet est à 3 px du bord du cadre
  Wd.TEXT_SIZE = nil
  local function Edge(t)
    local p = t._wideParts
    if not p then return nil end
    if p.edge == nil then
      local ok, e = pcall(CreateFrame, "Frame", nil, t, "BackdropTemplate")
      if not (ok and e) then ok, e = pcall(CreateFrame, "Frame", nil, t) end
      p.edge = (ok and e) or false
      if p.edge then
        if p.edge.EnableMouse then p.edge:EnableMouse(false) end
        if p.edge.SetBackdrop then
          pcall(p.edge.SetBackdrop, p.edge, { edgeFile = Wd.EDGE_TEX, edgeSize = Wd.EDGE_SIZE })
          local c = Wd.FILL
          if p.edge.SetBackdropBorderColor then pcall(p.edge.SetBackdropBorderColor, p.edge, c[1], c[2], c[3], 1) end
        end
      end
    end
    return p.edge or nil
  end
  local basePaint = Wd.Paint
  function Wd.Paint(t, ...)
    local r = { basePaint(t, ...) }
    if not (t and t._wideOn and t._wideParts) then return unpack(r) end
    local p = t._wideParts
    local m = Wd.Metrics and Wd.Metrics() or {}
    local h = N(t._wideH) or m.h or 20
    if Wd.PlaceVialIcon then Wd.PlaceVialIcon(t, m) end
    local isz = m.isz or (Wd.IconSize and Wd.IconSize(m.tile or h)) or math.max(Wd.MIN_ISZ or 32, math.floor((m.tile or h) * 0.90 + 0.5))
    -- police et placement : Wd.PlaceTotalRow (déjà appelé par la peinture de base).
    -- On ne recalcule pas left/inner ici, pour ne pas écraser le plancher 40 % / overlay.
    I.CleanText(p.text)
    p.text:SetTextColor(1, 0.93, 0.80)
    local plan = Wd.last
    local left = (plan and plan.left) or 0
    local inner = (plan and plan.inner) or 0
    local bh = (plan and plan.bh) or m.bh or Wd.BAR_H
    local by = (plan and plan.by) or 0
    local pct = (plan and plan.pct) or 0
    local cur = (plan and plan.cur) or 0
    local max = (plan and plan.max) or 0
    if p.track and p.track.ClearAllPoints then
      p.track:ClearAllPoints()
      p.track:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", left, by)
      p.track:SetSize(inner, bh)
    end
    Wd.LayoutSegments(t, left, by, inner, bh, cur, max)
    -- textures unies (jeton de couleur) sur chaque segment
    local texFile = Wd.FILL_TEX or Wd.TEX
    for i = 1, #(p.segs or {}) do
      pcall(p.segs[i].SetTexture, p.segs[i], texFile)
    end
    if not p._poTex then
      p._poTex = true
      p.sheen = t:CreateTexture(nil, "ARTWORK", nil, 2)
      W8(p.sheen)
    end
    -- reflet 1 px sur toute la portion remplie (du 1er au dernier segment visible)
    local first, last
    for i = 1, #(p.segs or {}) do
      local s = p.segs[i]
      if s and s.IsShown and s:IsShown() then
        if not first then first = s end
        last = s
      end
    end
    if first and last and pct > 0 then
      p.sheen:ClearAllPoints()
      p.sheen:SetPoint("TOPLEFT", first, "TOPLEFT", 0, 0)
      p.sheen:SetPoint("TOPRIGHT", last, "TOPRIGHT", 0, 0)
      p.sheen:SetHeight(1)
      p.sheen:SetVertexColor(1, 0.95, 0.85, Wd.SHEEN_A)
      p.sheen:Show()
    else
      p.sheen:Hide()
    end
    local e = Edge(t)
    if e then
      e:ClearAllPoints()
      local edge = (Wd.last and Wd.last.edgeOut) or Wd.EDGE_OUT or 3
      e:SetPoint("TOPLEFT", p.track, "TOPLEFT", -edge, edge)
      e:SetPoint("BOTTOMRIGHT", p.track, "BOTTOMRIGHT", edge, -edge)
      if e.SetFrameLevel and t.GetFrameLevel then pcall(e.SetFrameLevel, e, (t:GetFrameLevel() or 1) + 1) end
      e:Show()
    end
    if t._numShade then t._numShade:Hide() end
    if Wd.last then Wd.last.inner, Wd.last.left, Wd.last.by, Wd.last.bh, Wd.last.isz = inner, left, by, bh, isz end
    Po.stats.gauges = Po.stats.gauges + 1
    return unpack(r)
  end
  -- retour en mode case : filet de jauge caché, dégradé des chiffres rendu
  local baseApply = Wd.Apply
  function Wd.Apply(wrap, ...)
    local r = { baseApply(wrap, ...) }
    for _, t in ipairs(wrap and wrap.tiles or {}) do
      local p = t._wideParts
      if not t._wideOn then
        if p and p.edge then p.edge:Hide() end
        if p and p.sheen then p.sheen:Hide() end
        if p and p.hit then p.hit:Hide() end
        if t._numShade and t.data then t._numShade:Show() end
      end
    end
    return unpack(r)
  end
end

ns.DebugExt = ns.DebugExt or {}
ns.DebugExt[#ns.DebugExt + 1] = function()
  local s = Po.stats
  return { "— Finitions FlareUI (3.3.17) —",
    string.format("pastilles stylées %d (plaque %d px, police %d) · chiffres %d (/max %d %%) · jauges %d (%d px)",
      s.badges, (Th and Th.BADGE_H) or 10, Po.BADGE_FONT, s.counts, math.floor(Po.MAX_K * 100), s.gauges, Wd and Wd.BAR_H or 0) }
end
