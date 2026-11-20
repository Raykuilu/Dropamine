-- Dropamine 3.3.0 — grille d'ICÔNES (façon barre d'action native) et
-- tout le détail dans le volet de droite.
--
-- Chaque tuile = une case d'icône (notre petit cadre carré), sans nom ni barre.
-- Le rang est affiché en bas à droite, comme le compteur d'un bouton d'action
-- (NumberFontNormal : blanc, contour noir). Survol : info-bulle native.
-- Sélection : surbrillance de case cochée native. Le volet de droite garde le
-- titre au-dessus du filet, le rang / max sur la barre bleue, la progression,
-- la description et les recettes.
local ADDON, ns = ...
local Tr = ns.L   -- 3.5.19 : textes traduits (Locales/)
local UI = ns.UI
local H = UI._H
local V = ns.View
local W = ns.Window
local SafeStep, SizeOf = H.SafeStep, H.SizeOf

local I = {}
ns.Icons = I
UI.Icons = I

I.ICON = 36           -- icône (comme un bouton d'action)
I.TILE = 40           -- case (icône + cadre)
I.HGAP = 8            -- écart horizontal (celui de la mise en page de base)
I.VGAP = 12           -- écart vertical (3.3.10 : place pour la pastille « N prêt » au-dessus de la case)
I.STEP = I.TILE + I.VGAP
I.COUNT_FONT = "NumberFontNormal"
I.HOVER_TEX = "Interface\\Buttons\\ButtonHilight-Square"
I.CHECK_TEX = "Interface\\Buttons\\CheckButtonHilight"
I.GOLD = { 1, 0.82, 0 }

local function GOLDC() return H.GOLD or I.GOLD end

-- 3.3.12 : taille DYNAMIQUE (« resize dynamique » plutôt qu'un SetScale qui
-- grossissait aussi la bordure) : /drop taille, le curseur et la poignée
-- recalculent ici les mesures de la grille (case, icône, écarts, chiffres) ;
-- le panneau, son bord et ses coins restent à l'échelle 1 (épaisseur native).
I.BASE = { ICON = 36, TILE = 40, HGAP = 8, VGAP = 12, COUNT_MAX = 13, COUNT_MIN = 8 }   -- 3.3.17 : écart vertical 12 (pastille entière dans l’écart)
I.VGAP_MIN = 12       -- place de la pastille « N prêt » (taille fixe) au-dessus de la case
function I.SetMetrics(k)
  k = ns.N(k) or 1
  if k <= 0 then k = 1 end
  local B = I.BASE
  local function R(v) return math.floor(v * k + 0.5) end
  I.ICON = math.max(16, R(B.ICON))
  I.TILE = math.max(I.ICON + 2, R(B.TILE))
  I.HGAP = math.max(2, R(B.HGAP))
  I.VGAP = math.max(I.VGAP_MIN, R(B.VGAP))
  I.STEP = I.TILE + I.VGAP
  I.COUNT_MAX = math.max(I.RANK_MIN or 11, R(B.COUNT_MAX))
  I.COUNT_MIN = math.max(6, math.min(I.COUNT_MAX, R(B.COUNT_MIN)))
  if ns.View then ns.View.ROW_PITCH = I.STEP end
  I.metricsK = k
  return I.TILE
end

-- Pas de rangée : celui de la case (plus de barre).
V.ROW_PITCH = I.STEP
function V.MinPitch() return I.STEP end

function UI:FitGrid(wrap, n)
  local compact = ns.Panel and ns.Panel.IsExpanded and not ns.Panel.IsExpanded()
  local Lyt = ns.Layout
  -- En compact : les colonnes choisies (L.Cols), la case courante (I.TILE après
  -- SetMetrics). On ne déduit plus les colonnes d'une largeur de liste périmée
  -- (262 px / 5 col. à 40 px), qui décalait cadre et grille quand la taille change.
  if compact and Lyt and Lyt.Cols then
    if Lyt.SyncMetrics then Lyt.SyncMetrics() end
    local cols = Lyt.Cols()
    local groups = wrap and wrap._snap and self:GroupTiles(wrap._snap.tiles) or nil
    local rowsAll = 0
    if groups and #groups > 0 then
      for gi = 1, #groups do rowsAll = rowsAll + math.ceil(#groups[gi].tiles / cols) end
    else
      rowsAll = math.ceil((n or 1) / cols)
    end
    return cols, I.TILE, I.TILE, I.STEP, math.max(1, rowsAll)
  end
  local w = (wrap and wrap._innerW) or self:GetGridInnerWidth(wrap)
  local cols = math.max(1, math.floor((w + I.HGAP) / (I.TILE + I.HGAP)))
  local groups = wrap and wrap._snap and self:GroupTiles(wrap._snap.tiles) or nil
  local rowsAll = 0
  if groups and #groups > 0 then
    for gi = 1, #groups do rowsAll = rowsAll + math.ceil(#groups[gi].tiles / cols) end
  else
    rowsAll = math.ceil((n or 1) / cols)
  end
  return cols, I.TILE, I.TILE, I.STEP, math.max(1, rowsAll)
end

local function EnsureIconParts(t)
  if t._icon330 then return end
  t._icon330 = true
  local ok, fs = pcall(t.CreateFontString, t, nil, "OVERLAY", I.COUNT_FONT)
  if not (ok and fs) then fs = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall") end
  -- contour garanti, même si NumberFontNormal manque
  if fs.GetFont and fs.SetFont then
    local okF, path, size = pcall(fs.GetFont, fs)
    if okF and path then pcall(fs.SetFont, fs, path, math.max(11, ns.N(size) or 12), I.TEXT_FLAGS or "") end
  end
  if fs.SetJustifyH then fs:SetJustifyH("RIGHT") end
  I.CleanText(fs)
  t.countFS = fs
  t.hoverTex = t:CreateTexture(nil, "HIGHLIGHT")
  pcall(t.hoverTex.SetTexture, t.hoverTex, I.HOVER_TEX)
  if t.hoverTex.SetBlendMode then pcall(t.hoverTex.SetBlendMode, t.hoverTex, "ADD") end
  t.hoverTex:Hide()
  t.checkTex = t:CreateTexture(nil, "OVERLAY", nil, 7)
  pcall(t.checkTex.SetTexture, t.checkTex, I.CHECK_TEX)
  if t.checkTex.SetBlendMode then pcall(t.checkTex.SetBlendMode, t.checkTex, "ADD") end
  -- 3.3.14 : sélection teintée « bord actif » FlareUI (plus le halo BLEU de
  -- CheckButtonHilight, confondu avec la surbrillance de cible)
  if t.checkTex.SetVertexColor then pcall(t.checkTex.SetVertexColor, t.checkTex, 1, 0.86, 0.46, 1) end
  t.checkTex:Hide()
  t:SetScript("OnEnter", I.OnEnter)
  t:SetScript("OnLeave", I.OnLeave)
end

local function Center(tex, t, s)
  tex:ClearAllPoints()
  tex:SetPoint("CENTER", t, "CENTER", 0, 0)
  tex:SetSize(s, s)
end

function UI:ResizeTile(t, tw, th)
  t:SetSize(tw, th)
  -- même strate que la fenêtre (posée explicitement : rien ne passe dessous)
  local e = UI.embed
  if e and e.GetFrameStrata and t.SetFrameStrata then
    local okS, st = pcall(e.GetFrameStrata, e)
    if okS and st then pcall(t.SetFrameStrata, t, st) end
  end
  EnsureIconParts(t)
  V.IconLook(t, I.ICON)              -- notre petit cadre carré (emplacement natif)
  Center(t.slotBg, t, I.ICON)
  Center(t.icon, t, I.ICON)
  local a = ns.Style and ns.Style.DiscoverItemSlot and ns.Style.DiscoverItemSlot() or {}
  local fb = ns.Style and ns.Style.SLOT_FALLBACK or {}
  Center(t.slotBorder, t, math.floor(I.ICON * (a.ratio or fb.ratio or 1.6) + 0.5))
  Center(t.hoverTex, t, I.ICON)
  Center(t.checkTex, t, I.ICON)
  -- sélection : toute la case (sous l'icône), comme avant
  t.hlTex:ClearAllPoints()
  t.hlTex:SetAllPoints(t)
  t.countFS:ClearAllPoints()
  t.countFS:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -1, 1)
  t.capIcon:ClearAllPoints() t.capIcon:SetPoint("TOPLEFT", t.icon, "TOPLEFT", 1, -1) t.capIcon:SetSize(12, 12)
  t.warnTex:ClearAllPoints() t.warnTex:SetPoint("TOPRIGHT", t.icon, "TOPRIGHT", -1, -1) t.warnTex:SetSize(12, 12)
  t._textX, t._textW, t._barH, t._blockTop, t._rankInBar = 0, 0, 0, 0, false
  t._nameMaxW = tw
end

-- 3.3.2 : « rang/max » en bas à droite (« et mets x / x dans le lvl »).
-- Niveau : niveau du personnage / niveau maximum. Emplacement libre : 0/max
-- (75 pour un métier non appris, 5 × niveau pour une arme pas encore lue).
function I.CapFor(d)
  local cap = ns.N(d.apiMax) or 0
  if cap > 0 then return math.floor(cap + 0.5) end
  if d.kind == "level" then return (ns.GetLevelCap and ns.GetLevelCap()) or 60 end
  if d.kind == "profession" or d.kind == "secondary" then return 75 end
  local lvl = UI.snapshot and ns.N(UI.snapshot.level) or 1
  return math.max(5, 5 * (lvl or 1))
end
function I.CountText(d, curOverride)
  if not d then return "" end
  local cur = d.placeholder and 0 or math.floor((ns.N(curOverride) or ns.N(d.current) or 0) + 0.5)
  return tostring(cur) .. "/" .. tostring(I.CapFor(d))
end

-- 3.3.3 : « rang » sur la 1re ligne, « /max » sur la 2e (« on peut mettre le
-- texte x/y à la ligne, comme ça c'est plus gros et lisible »). La largeur
-- libérée sert à GROSSIR la police (Arial Narrow du jeu, contour), alignée à
-- droite dans le coin ; chiffre ≈ 0,5 em, ligne ≈ 1 em ; jamais plus large ni
-- plus haute que la case.
-- 3.3.5 : correctif « 27… / 85… / 951… ». Une SEULE FontString avec « \n » et
-- SetWordWrap(false) n'affiche en jeu que la 1re ligne, tronquée par des
-- points de suspension. Désormais DEUX FontStrings d'une ligne chacune
-- (countFS = rang, countFS2 = « /max »), SANS largeur imposée (elles prennent
-- la largeur de leur texte : rien ne peut être tronqué), ancrées en bas à
-- droite de la case, l'une au-dessus de l'autre.
I.COUNT_PATH = "Fonts\\ARIALN.TTF"
-- 3.3.9 : rendu PROPRE (comme avant 3.3.8) : pas de contour épais, une seule
-- ombre fine de 1 px. I.TEXT_FLAGS = "" (aucun OUTLINE) ; I.CleanText pose l'ombre.
I.TEXT_FLAGS = ""
I.SHADOW = { 0, 0, 0, 1 }   -- 3.3.17 : même ombre nette partout (chiffres, pastille, barre)
function I.CleanText(fs)
  if type(fs) ~= "table" then return fs end
  if fs.SetShadowOffset then pcall(fs.SetShadowOffset, fs, 1, -1) end
  if fs.SetShadowColor then pcall(fs.SetShadowColor, fs, I.SHADOW[1], I.SHADOW[2], I.SHADOW[3], I.SHADOW[4]) end
  return fs
end
I.COUNT_EM = 0.5
I.COUNT_MAX, I.COUNT_MIN = I.COUNT_MAX or 13, I.COUNT_MIN or 8
I.RANK_MIN = 11

function I.ApplyNumberFont(fs, size)
  if type(fs) ~= "table" then return fs end
  if size and fs.SetFont then pcall(fs.SetFont, fs, I.COUNT_PATH, size, I.TEXT_FLAGS or "") end
  I.CleanText(fs)
  return fs
end

-- Rang (case) > total (rangée) > « /max », même face / style / ombre,
-- tous proportionnels à la taille de case. Jamais de police de modèle.
function I.NumberSizes(tile)
  tile = tile or I.TILE or 40
  -- Rang dérivé de CETTE taille de case (pas du COUNT_MAX d'une autre échelle).
  local B = I.BASE or { TILE = 40, COUNT_MAX = 13 }
  local refT = B.TILE or 40
  if refT <= 0 then refT = 40 end
  local k = (tile or refT) / refT
  if k <= 0 then k = 1 end
  local rank = math.max(I.RANK_MIN or 11, math.floor((B.COUNT_MAX or 13) * k + 0.5))
  local total = math.max(8, math.floor(rank * 0.85 + 0.5))
  if total >= rank then total = rank - 1 end
  if total < 8 then total = 8 end
  local k = (ns.Polish and ns.Polish.MAX_K) or 0.78
  local maxs = math.max(7, math.floor(rank * k + 0.5))
  if maxs >= total then maxs = total - 1 end
  if maxs < 7 then maxs = 7 end
  return { rank = rank, total = total, max = maxs }
end

function I.CountSize(longest, avail, availH, lines)
  local size = math.floor(avail / (math.max(1, longest) * I.COUNT_EM))
  if availH and lines then size = math.min(size, math.floor(availH / lines)) end
  if size > I.COUNT_MAX then size = I.COUNT_MAX end
  if size < I.COUNT_MIN then size = I.COUNT_MIN end
  return size
end
local function CountLine(t, key)
  local fs = t[key]
  if fs then return fs end
  local ok, f2 = pcall(t.CreateFontString, t, nil, "OVERLAY", I.COUNT_FONT)
  if not (ok and f2) then f2 = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall") end
  I.CleanText(f2)
  t[key] = f2
  return f2
end
-- 3.3.8 : en jeu, une largeur 0 laissait le texte DÉBORDER à droite de la case.
-- Désormais chaque ligne a la largeur EXACTE de la case moins un petit retrait
-- (deux ancres : bas-gauche et bas-droit), alignée à droite ; la taille de
-- police est réduite tant que le texte mesuré ne tient pas (jamais de « … »).
I.COUNT_INSET = 4   -- 3.3.17 : dans le biseau, plus collé au bord
local function PrepLine(fs, size)
  if fs.SetFont then pcall(fs.SetFont, fs, I.COUNT_PATH, size, I.TEXT_FLAGS) end
  I.CleanText(fs)
  if fs.SetJustifyH then pcall(fs.SetJustifyH, fs, "RIGHT") end
  if fs.SetWordWrap then pcall(fs.SetWordWrap, fs, false) end
  if fs.SetMaxLines then pcall(fs.SetMaxLines, fs, 1) end
  if fs.SetSpacing then pcall(fs.SetSpacing, fs, 0) end
end
function I.FitCount(t, text)
  local fs = t.countFS
  local fs2 = CountLine(t, "countFS2")
  local tw, th = SizeOf(t)
  tw, th = tw or I.TILE, th or I.TILE
  local avail, availH = tw - 2, th - 4
  local a, b = text:match("^(%d+)(/%d+)$")
  local lines, longest = 1, #text
  if a then lines, longest = 2, math.max(#a, #b) end
  local inset = I.COUNT_INSET
  local boxW = tw - 2 * inset
  avail = boxW
  local size = I.CountSize(longest, avail, availH, lines)
  local function place()
    PrepLine(fs, size)
    PrepLine(fs2, size)
    fs:ClearAllPoints()
    fs2:ClearAllPoints()
    if a then
      fs2:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", inset, inset - 1)
      fs2:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -inset, inset - 1)
      fs2:SetText(b)
      fs2:Show()
      fs:SetPoint("BOTTOMLEFT", fs2, "TOPLEFT", 0, 0)
      fs:SetPoint("BOTTOMRIGHT", fs2, "TOPRIGHT", 0, 0)
      fs:SetText(a)
    else
      fs:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", inset, inset - 1)
      fs:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -inset, inset - 1)
      fs:SetText(text)
      fs2:SetText("")
      fs2:Hide()
    end
    for _, x in ipairs({ fs, fs2 }) do if x.SetHeight then pcall(x.SetHeight, x, size + 2) end end
  end
  place()
  -- mesure réelle : on réduit la police tant qu'une ligne dépasse la case
  local function widest()
    local m = 0
    for _, x in ipairs(a and { fs, fs2 } or { fs }) do
      local ok, v = pcall(x.GetStringWidth, x)
      if ok and ns.N(v) and v > m then m = v end
    end
    return m
  end
  while size > I.COUNT_MIN and widest() > boxW do size = size - 1 place() end
  t._countBoxW = boxW
  local shown = a and (a .. "\n" .. b) or text
  t._countSize, t._countLines, t._countAvail, t._countText = size, lines, avail, shown
  t._countTop, t._countBottom = a or text, b
  return size
end
function I.SetCountColor(t, r, g, b)
  if t.countFS then t.countFS:SetTextColor(r, g, b) end
  if t.countFS2 then t.countFS2:SetTextColor(r, g, b) end
end

local baseUpdateTile = UI.UpdateTile
function UI:UpdateTile(t, d)
  -- 3.3.10 : le remplissage de base (vue à barres) ne doit jamais empêcher le
  -- nettoyage « icônes seules » ci-dessous (sinon « 93/135 » de levelFS restait
  -- affiché sous les deux lignes du compteur). Erreur rapportée une fois.
  local okB, errB = pcall(baseUpdateTile, self, t, d)
  if not okB then
    UI.lastTileError = errB
    if not UI._tileErrReported then
      UI._tileErrReported = true
      local h = type(_G.geterrorhandler) == "function" and _G.geterrorhandler()
      if h then pcall(h, errB) end
    end
  end
  EnsureIconParts(t)
  -- icônes seules : ni nom, ni rang « x/y », ni barre, ni repère d'objectif
  t.nameFS:SetText("") t.nameFS:Hide()
  t.levelFS:Hide()
  t.tagFS:Hide()
  V.ShowBar(t.barv, false)
  if t.barv.frame then t.barv.frame:Hide() end
  if t.barv.goal then t.barv.goal:Hide() end
  local fs = t.countFS
  I.FitCount(t, I.CountText(d, I.HeldValue and I.HeldValue(d) or nil))
  if d.placeholder then I.SetCountColor(t, 0.62, 0.55, 0.45) else I.SetCountColor(t, 1, 1, 1) end
  fs:Show()
  -- 3.3.5 : la pastille « N prêts » n'est plus cachée à chaque mise à jour de
  -- la case (elle disparaissait jusqu'à la prochaine lecture des sacs / du métier).
  SafeStep("prêts (case)", UI.UpdateCraftBadge, UI, t, d)
  V.PaintTile(t)
end

local basePaint = V.PaintTile
function V.PaintTile(t)
  basePaint(t)
  if not (t and t._icon330) then return end
  local selected = t.data and UI:IsSelectedData(t.data)
  if selected then t.checkTex:Show() else t.checkTex:Hide() end
  if t._hover and not selected then t.hoverTex:Show() else t.hoverTex:Hide() end
end

-- Info-bulle native au survol (le volet de droite suit la SÉLECTION).
function I.TooltipLines(d)
  local out = {}
  if not d then return out end
  local cur, cap = ns.N(d.current) or 0, ns.N(d.apiMax) or 0
  if d.placeholder then
    out[#out + 1] = { d.notLearnedTag or Tr["Pas encore appris"], 0.62, 0.55, 0.45 }
  elseif d.kind == "level" then
    out[#out + 1] = { Tr["Niveau "] .. cur .. (cap > 0 and (" / " .. cap) or ""), 1, 1, 1 }
    local xp = cap > 0 and UI.LevelBarXP and UI:LevelBarXP(cur, cap) or nil
    if xp and xp.max and xp.max > 0 then out[#out + 1] = { "XP " .. xp.cur .. " / " .. xp.max, 0.8, 0.8, 0.8 } end
  elseif cap > 0 then
    out[#out + 1] = { Tr["Rang "] .. cur .. " / " .. cap, 1, 1, 1 }
  else
    out[#out + 1] = { tostring(cur), 1, 1, 1 }
  end
  return out
end

function I.OnEnter(self)
  UI._hoverTile = self
  self._hover = true
  V.PaintTile(self)
  local d = self.data
  if d and GameTooltip then
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local g = GOLDC()
    GameTooltip:SetText(d.name or "?", g[1], g[2], g[3])
    for _, l in ipairs(I.TooltipLines(d)) do GameTooltip:AddLine(l[1], l[2], l[3], l[4]) end
    if self._warnText then GameTooltip:AddLine(self._warnText, 1, 0.82, 0.2, true) end
    if self._capped then GameTooltip:AddLine(Tr["Palier atteint : va voir ton maître."], 0.25, 1, 0.25, true) end
    -- 3.5.5 : plus de « Clic : détail à droite » (il n'y a plus de volet de détail)
    GameTooltip:Show()
    self._tipShown = true
  end
end

function I.OnLeave(self)
  if GameTooltip and self._tipShown then GameTooltip:Hide() end
  self._tipShown = nil
  self._hover = false
  V.PaintTile(self)
  UI._hoverTile = nil
end

------------------------------------------------------------------------------
-- Volet de droite : barre bleue native mesurée (même style que 3.2.0)
------------------------------------------------------------------------------
local baseSetDetailBar = UI.SetDetailBar
function UI:SetDetailBar(f, cur, cap)
  local r = { baseSetDetailBar(self, f, cur, cap) }
  local hold = f and f.barHold
  if not hold then return unpack(r) end
  if not f._bar330 then
    f._bar330 = V.NewBar(hold)
    V.SkinBar(f._bar330)
  end
  local b = f._bar330
  -- l'ancienne barre reste en place (géométrie) mais invisible
  local regs = { pcall(hold.GetRegions, hold) }
  for k = 2, #regs do local x = regs[k] if x ~= b.goal and x.SetAlpha then x:SetAlpha(0) end end
  local kids = { pcall(hold.GetChildren, hold) }
  for k = 2, #kids do local x = kids[k] if x ~= b.frame and x.SetAlpha then x:SetAlpha(0) end end
  if f.barText and f.barText.SetAlpha then f.barText:SetAlpha(0) end
  local w = select(1, SizeOf(hold)) or self:DetailBarWidth(f) or 200
  hold:SetHeight(V.BAR320.h)
  V.PlaceBar(b, 0, 0, math.floor(w + 0.5), V.BAR320.h)
  V.ShowBar(b, true)
  b.frame:SetAlpha(1)
  cur, cap = ns.N(cur) or 0, ns.N(cap) or 0
  local d = self._detailData
  local xp = d and d.kind == "level" and self:LevelBarXP(cur, cap) or nil
  if xp then V.SetBar(b, xp.cur, xp.max, nil, xp.rested)
  else V.SetBar(b, cur, cap) end
  if b.frame.SetFrameLevel and hold.GetFrameLevel then pcall(b.frame.SetFrameLevel, b.frame, (hold:GetFrameLevel() or 0) + 5) end
  return unpack(r)
end

-- Plus de gris : le fond du porte-barre et des boutons d'en-tête = brun natif.
local baseLayout = W.Layout
function W.Layout()
  baseLayout()
  local f = W.frame
  if not (f and f:IsShown()) then return end
  local od = UI.ownDetail
  if od and od.barHold and od.barHold.bg then W.Tint(od.barHold.bg, V.MEASURED.barBg, 1) end
end

I.DebugLines = function()
  return { "grille 3.3.0 : icônes seules " .. I.ICON .. " px, case " .. I.TILE .. ", pas " .. I.STEP .. ", rang « x/max » en bas à droite (Arial Narrow contourné)" }
end

------------------------------------------------------------------------------
-- 3.3.1 : marge du texte du volet de droite (« plus qu'à corriger la marge »)
------------------------------------------------------------------------------
-- Le texte (description, Progression, lignes de combat, Statistiques…) était
-- collé au bord gauche du volet : la zone de défilement partait 22 px à gauche
-- de la barre, elle-même à 16 px du bord. Désormais : bandeaux d'en-tête à
-- 6 px des bords du volet (inchangés à l'œil), et TOUT le texte courant à la
-- marge native de 22 px, avec la même marge à droite (retour à la ligne).
I.TEXT_INSET = 22        -- marge native mesurée (texte du détail)
I.BAND_INSET = 6         -- bandeaux d'en-tête / zone de défilement
UI.DETAIL_BODY_INSET = I.TEXT_INSET - I.BAND_INSET

local baseNativeLayout = UI.ApplyNativeDetailLayout
function UI:ApplyNativeDetailLayout(f)
  baseNativeLayout(self, f)
  local pane = W and W.detail
  if not (f and f.scroll and pane) then return end
  local pl, pr = H.RectOf(pane)
  local fl, fr, ft = H.RectOf(f)
  local geo = f._geo
  if not (pl and pr and fl and fr and ft) then return end
  local top = geo and geo.barB and (geo.barB - V.DETAIL_PX.descTop) - ft or -60
  f.scroll:ClearAllPoints()
  f.scroll:SetPoint("TOPLEFT", f, "TOPLEFT", (pl + I.BAND_INSET) - fl, top)
  f.scroll:SetPoint("TOPRIGHT", f, "TOPRIGHT", (pr - I.BAND_INSET) - fr, top)
  if f.scroll.SetWidth then f.scroll:SetWidth((pr - pl) - 2 * I.BAND_INSET) end
  f._textLeft = (pl + I.TEXT_INSET) - fl
  if geo then geo.descLeft, geo.descRight = pl + I.TEXT_INSET, pr - I.TEXT_INSET end
  local bin = UI.DETAIL_BODY_INSET
  if f.desc and f.scrollChild then
    f.desc:ClearAllPoints()
    f.desc:SetPoint("TOPLEFT", f.scrollChild, "TOPLEFT", bin, 0)
    f.desc:SetPoint("TOPRIGHT", f.scrollChild, "TOPRIGHT", -bin, 0)
  end
  if f.scrollChild and f.scrollChild.SetWidth then
    f.scrollChild:SetWidth(math.max(40, (pr - pl) - 2 * I.BAND_INSET))
  end
end

------------------------------------------------------------------------------
-- 3.3.2 : titre et description GARANTIS pour TOUS les volets, total compris
------------------------------------------------------------------------------
-- Cause : la garantie 3.1.0 (titre / description visibles, opaques, non vides)
-- ne s'appliquait qu'à FillOwnDetail ; le volet « Niveau total » passe par
-- ShowDetailBreakdown, qui ne l'avait pas. Et ApplyNativeDetailLayout
-- réapplique au titre ET à la description la couleur native mémorisée (brute,
-- alpha compris) APRÈS EnsureDetailTitle : une couleur relevée transparente
-- ou noire rendait ces deux textes invisibles alors que les sections (textes
-- colorés |c…) restaient lisibles. Désormais : même police / couleur
-- (couleur assainie), même position (13 px au-dessus du filet), pour chaque
-- volet, après chaque remplissage.
local function SaneColor(fs, dr, dg, db)
  if not (fs and fs.SetTextColor) then return end
  local ok, r, g, b, a = pcall(fs.GetTextColor, fs)
  r, g, b, a = ns.N(r), ns.N(g), ns.N(b), ns.N(a) or 1
  if not ok or not r or a < 0.5 or (r + (g or 0) + (b or 0)) < 0.6 then fs:SetTextColor(dr, dg, db, 1) end
end
I.TITLE_GAP = 13
function I.EnsurePaneText(f, title, desc)
  if not (f and f.title) then return end
  if (f.title:GetText() or "") == "" and title and title ~= "" then f.title:SetText(title) end
  UI:EnsureDetailTitle(f)            -- police native, couleur assainie, alpha 1, Show
  SaneColor(f.title, 1, 0.82, 0)
  if not f._geo then
    -- repli : même position que les autres volets, 13 px au-dessus du filet
    local _, _, dt = H.RectOf(W.detailDiv)
    local fl, _, ft = H.RectOf(f)
    if dt and ft then
      f.title:ClearAllPoints()
      f.title:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 8, dt + I.TITLE_GAP - ft)
      f.title:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -8, dt + I.TITLE_GAP - ft)
    end
  end
  if f.desc then
    if (f.desc:GetText() or "") == "" and desc and desc ~= "" then f.desc:SetText(desc) end
    SaneColor(f.desc, 1, 1, 1)
    if f.desc.SetAlpha then f.desc:SetAlpha(1) end
    if (f.desc:GetText() or "") ~= "" then f.desc:Show() end
  end
  for _, o in ipairs({ f, f.scroll, f.scrollChild }) do
    if o and o.SetAlpha then pcall(o.SetAlpha, o, 1) end
  end
  I.lastPane = { title = f.title:GetText(), desc = f.desc and f.desc:GetText() }
end

local baseBreakdown332 = UI.ShowDetailBreakdown
function UI:ShowDetailBreakdown(snap)
  -- la tuile affichée avant ne doit plus piloter le volet du total (barre
  -- d'XP du Niveau sur le total, re-remplissage par l'ancienne tuile)
  if snap then self._detailData, self._detailLive = nil, nil end
  local r = { baseBreakdown332(self, snap) }
  local f = self.ownDetail
  if f and snap and f:IsShown() then I.EnsurePaneText(f, Tr["Niveau total"], Tr[ns.TOTAL_SHORT_FR]) end
  return unpack(r)
end
local baseFill332 = UI.FillOwnDetail
function UI:FillOwnDetail(d, live)
  local r = { baseFill332(self, d, live) }
  local f = self.ownDetail
  if f and d and f:IsShown() then I.EnsurePaneText(f, self:DetailLabelFor(d) or d.name, nil) end
  return unpack(r)
end

------------------------------------------------------------------------------
-- 3.3.2 : plus de catégories (« compacter le tout à la OSRS »)
------------------------------------------------------------------------------
-- Une seule grille continue, dans l'ordre des tuiles (Niveau, Mêlée, tuile de
-- combat de la classe, Défense, métiers 1 et 2, Cuisine, Pêche, Secourisme) ;
-- aucun en-tête ni bouton −/+. Le code des sections reste intact : option
-- cachée « /drop categories on » (ns.db.ui.categories = true) pour le retrouver.
function I.Categories() return ns.db and ns.db.ui and ns.db.ui.categories == true or false end

local baseGroupTiles = UI.GroupTiles
function UI:GroupTiles(tiles)
  local groups = baseGroupTiles(self, tiles)
  if I.Categories() then return groups end
  local all = {}
  for _, g in ipairs(groups) do for _, t in ipairs(g.tiles) do all[#all + 1] = t end end
  return { { title = "", tiles = all, flat = true } }
end

local baseCollapsed = UI.IsGroupCollapsed
function UI:IsGroupCollapsed(key)
  if not I.Categories() then return false end
  return baseCollapsed(self, key)
end

local function NoHeaders(fn)
  return function(self, ...)
    if I.Categories() then return fn(self, ...) end
    local h, g = UI.HEADER_H, UI.HEADER_GAP
    UI.HEADER_H, UI.HEADER_GAP = 0, 0
    local r = { pcall(fn, self, ...) }
    UI.HEADER_H, UI.HEADER_GAP = h, g
    if not r[1] then error(r[2], 0) end
    return unpack(r, 2)
  end
end
UI.GridContentHeight = NoHeaders(UI.GridContentHeight)
local baseLayoutGrid = NoHeaders(UI.LayoutGrid)
function UI:LayoutGrid(wrap, snap)
  local r = { baseLayoutGrid(self, wrap, snap) }
  if not I.Categories() and wrap then
    for _, hd in ipairs(wrap.headers or {}) do
      hd:Hide()
      if hd.EnableMouse then hd:EnableMouse(false) end
    end
  end
  return unpack(r)
end

ns.SlashExt = ns.SlashExt or {}
ns.SlashExt.categories = function(rest)
  ns.db.ui = ns.db.ui or {}
  rest = (rest or ""):lower()
  if rest == "on" then ns.db.ui.categories = true elseif rest == "off" then ns.db.ui.categories = nil
  else ns.db.ui.categories = not I.Categories() or nil end
  print(Tr["|cffffd100Dropamine|r : catégories "] .. (I.Categories() and Tr["affichées"] or Tr["masquées (grille compacte)"]))
  if W.IsShown() then W.Layout() end
end
