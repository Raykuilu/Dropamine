-- Dropamine 3.0.0 — vue OSRS réécrite (base propre).
--
-- Architecture (une seule règle par point) :
--   * UN cadre autonome (UI.embed, parent = SkillFrame), montré seulement en
--     vue OSRS. Il n'est jamais dans la liste native.
--   * Vue OSRS : la liste native est CACHÉE (Hide) hors combat ; vue classique :
--     elle est réaffichée (Show) et tous nos cadres sont cachés et sans souris.
--     En combat, le natif n'est pas touché : la demande attend la fin du combat.
--   * Chaque tuile = UN Button avec ses propres régions (icône, nom, barre,
--     surbrillance). Chaque en-tête = UN Button (textures de l'en-tête natif,
--     +/- jaune natif à droite uniquement).
--   * Aucun écran anti-clic, aucune couche de boutons, aucune opacité 0, aucun
--     disjoncteur qui coupe la mise en page ou la souris.
local ADDON, ns = ...
local Tr = ns.L   -- 3.5.19 : textes traduits (Locales/)
local UI = ns.UI
local H = UI._H
local Text, FillTexture, TrySetTex, SetFontSafe = H.Text, H.FillTexture, H.TrySetTex, H.SetFontSafe
local SafeStep, SizeOf, NF = H.SafeStep, H.SizeOf, H.NF
local NativeVeil, GOLD = H.NativeVeil, H.GOLD

local V = {}
ns.View = V
UI.View = V

-- Valeurs MESURÉES sur la capture en jeu refs/native-284.png (pixels écran,
-- même échelle que notre capture ours-284.png : en-têtes 28 px dans les deux).
V.MEASURED = {
  barFillLeft  = { 0 / 255, 50 / 255, 97 / 255 },     -- bord gauche du remplissage (ligne centrale)
  barFillRight = { 31 / 255, 92 / 255, 159 / 255 },   -- bord droit d'une barre pleine
  barBg        = { 25 / 255, 14 / 255, 0 / 255 },     -- fond de barre (partie vide)
  barEdgeTop   = { 184 / 255, 161 / 255, 136 / 255 }, -- filet clair du haut
  barEdgeBottom = { 121 / 255, 98 / 255, 72 / 255 },  -- filet du bas
  barEdgeSide  = { 105 / 255, 89 / 255, 67 / 255 },   -- filets gauche / droit
  barInner     = { 8 / 255, 5 / 255, 0 / 255 },       -- liseré sombre intérieur
  barShade     = 0.45,                                -- assombrissement haut/bas (~55 % au bord)
  headerFill   = { 47 / 255, 28 / 255, 13 / 255 },
  headerEdge   = { 78 / 255, 67 / 255, 57 / 255 },
  headerEdgeBottom = { 53 / 255, 45 / 255, 38 / 255 },
  toggle       = { 1, 223 / 255, 0 },                 -- « − » jaune natif
  highlight    = 0.22,                                -- surbrillance : +56/255 sur le fond (85,78,71 sur 29,19,10)
  px = { headerH = 28, headerW = 404, headerToFirstBar = 12, rowStep = 40,
         barOuterH = 24, barFillH = 17, barOuterW = 183, fillInsetX = 3,
         fillInsetTop = 4, fillInsetBottom = 3, toggleW = 15, toggleH = 3,
         toggleRight = 6, headerTextLeft = 9, hlTop = 5, hlBottom = 6, hlRightOverHeader = 4 },
}
local M = V.MEASURED
V.BAR_H = M.px.barOuterH          -- hauteur extérieure de la barre (unités ≈ pixels mesurés)
V.NAME_H = 13
UI.HL_HOVER, UI.HL_SELECTED = 0.12, M.highlight
UI.HEADER_H = 26                  -- repli ; remplacé par la hauteur native relevée

local WHITE = "Interface\\Buttons\\WHITE8X8"
local TILE_HGAP0 = 8

local function Solid(tex, c, a)
  pcall(tex.SetTexture, tex, WHITE)
  if tex.SetVertexColor then pcall(tex.SetVertexColor, tex, c[1], c[2], c[3], a or c[4] or 1) end
end

-- Dégradé (API moderne CreateColor, ancienne SetGradientAlpha, sinon aplat).
local function Gradient(tex, orient, a, b)
  pcall(tex.SetTexture, tex, WHITE)
  if tex.SetVertexColor then pcall(tex.SetVertexColor, tex, 1, 1, 1, 1) end
  if tex.SetGradient and type(CreateColor) == "function" then
    local ok = pcall(tex.SetGradient, tex, orient, CreateColor(a[1], a[2], a[3], a[4] or 1), CreateColor(b[1], b[2], b[3], b[4] or 1))
    if ok then tex._grad = { a, b } return "gradient" end
  end
  if tex.SetGradientAlpha then
    local ok = pcall(tex.SetGradientAlpha, tex, orient, a[1], a[2], a[3], a[4] or 1, b[1], b[2], b[3], b[4] or 1)
    if ok then tex._grad = { a, b } return "gradientAlpha" end
  end
  local m = {}
  for i = 1, 4 do m[i] = ((a[i] or 1) + (b[i] or 1)) / 2 end
  if tex.SetVertexColor then pcall(tex.SetVertexColor, tex, m[1], m[2], m[3], m[4]) end
  tex._grad = { a, b }
  return "flat"
end
V.Gradient = Gradient

local function Lerp(a, b, t) return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, 1 } end

------------------------------------------------------------------------------
-- Barre de rang (régions de la tuile, aucun cadre enfant)
------------------------------------------------------------------------------
-- 3.0.1 : la barre de tuile n'IMITE plus le natif : c'est un vrai StatusBar
-- habillé avec la texture de remplissage, la couleur, le fond et le cadre LUS
-- sur une ligne de la liste native (NativeLook.ProbeList, lecture seule ;
-- mémorisés dans les SavedVariables). Taille FIXE = taille native (hauteur
-- native ; largeur native bornée à la colonne native), jamais étirée avec la
-- tuile ou la fenêtre. Police du texte = police du texte de barre native.
V.BAR_TEMPLATES = { "SkillStatusBarTemplate" }
V.BAR_FALLBACK = {
  tex = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar",
  color = { 0.0, 0.0, 1.0, 0.5 },
  bgColor = { 0.0, 0.0, 0.75, 0.25 },
  border = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-BarBorder",
}
function V.NativeBar()
  local L = ns.NativeLook and ns.NativeLook.ProbeList and ns.NativeLook.ProbeList()
  local b = L and L.bar
  if b and (b.tex or b.atlas) then return b, L end
  return nil, L
end
V.ICON_SIZE = 32
V.TEXT_X = 2 + V.ICON_SIZE + 6
-- Taille fixe de la barre (unités d'interface). Ne dépend QUE du natif.
function V.BarSize()
  local b, L = V.NativeBar()
  local h = b and ns.N(b.h)
  if not h or h < 6 or h > 40 then h = M.px.barOuterH end
  local w = b and ns.N(b.w)
  if not w or w < 40 or w > 400 then w = M.px.barOuterW end
  -- colonne native : moitié de la largeur de l'en-tête natif (2 colonnes)
  local hw = L and L.headerInset and ns.N(L.headerInset.width)
  if not hw or hw < 150 or hw > 700 then hw = M.px.headerW end
  local colMax = math.floor((hw - TILE_HGAP0) / 2) - V.TEXT_X - 2
  -- largeur du volet natif (relevée une fois, indépendante de la fenêtre)
  local lw = ns.N(UI.leftPaneW)
  if lw and lw >= 150 then
    local c2 = math.floor((lw - 2 * (UI.gridPad or 8) - 20 - TILE_HGAP0) / 2) - V.TEXT_X - 2
    if c2 < colMax then colMax = c2 end
  end
  if w > colMax then w = colMax end
  return math.floor(w + 0.5), math.floor(h + 0.5)
end

local function DisableMouseTree(o, depth)
  if type(o) ~= "table" or (depth or 0) > 4 then return end
  if o.EnableMouse then pcall(o.EnableMouse, o, false) end
  if o.EnableMouseWheel then pcall(o.EnableMouseWheel, o, false) end
  if o.GetChildren then
    local kids = { pcall(o.GetChildren, o) }
    for i = 2, #kids do DisableMouseTree(kids[i], (depth or 0) + 1) end
  end
end
V.DisableMouseTree = DisableMouseTree

function V.NewBar(owner)
  local b = { owner = owner }
  local nb = V.NativeBar()
  local sb
  if not nb then
    for _, tmpl in ipairs(V.BAR_TEMPLATES) do
      local ok, f = pcall(CreateFrame, "StatusBar", nil, owner, tmpl)
      if ok and f then sb = f b.template = tmpl break end
    end
  end
  if not sb then
    local ok, f = pcall(CreateFrame, "StatusBar", nil, owner)
    sb = ok and f or CreateFrame("Frame", nil, owner)
  end
  sb._osrsOwn = true
  DisableMouseTree(sb, 0)          -- jamais de souris : la tuile reçoit les clics
  b.frame = sb
  b.bg = sb:CreateTexture(nil, "BACKGROUND", nil, -1)
  b.bg:SetAllPoints(sb)
  b.rested = sb:CreateTexture(nil, "ARTWORK", nil, 1)
  b.rested:Hide()
  b.goal = owner:CreateTexture(nil, "OVERLAY", nil, 1)
  b.goal:Hide()
  b.border = sb:CreateTexture(nil, "OVERLAY", nil, 0)
  b.border:Hide()
  b.text = Text(sb, "GameFontHighlightSmall", "CENTER")
  b.text:SetPoint("CENTER", sb, "CENTER", 0, 0)
  if b.text.SetWordWrap then b.text:SetWordWrap(false) end
  V.SkinBar(b)
  b.parts = { sb }
  return b
end

-- Habillage depuis la barre native relevée (ou le gabarit / repli natif).
function V.SkinBar(b)
  local sb = b.frame
  local nb = V.NativeBar()
  local okT = false
  if nb then
    if nb.atlas and sb.SetStatusBarAtlas then okT = pcall(sb.SetStatusBarAtlas, sb, nb.atlas) end
    if not okT and nb.tex and sb.SetStatusBarTexture then okT = pcall(sb.SetStatusBarTexture, sb, nb.tex) end
    b.source = "barre native relevée"
  end
  if not okT and b.template and sb.GetStatusBarTexture then
    -- gabarit natif : seulement s'il a vraiment posé sa texture de barre
    local okG, tx = pcall(sb.GetStatusBarTexture, sb)
    local p = okG and tx and tx.GetTexture and select(2, pcall(tx.GetTexture, tx)) or nil
    if p ~= nil and p ~= false then okT = true b.source = "gabarit natif " .. b.template end
  end
  if not okT and sb.SetStatusBarTexture then
    okT = pcall(sb.SetStatusBarTexture, sb, V.BAR_FALLBACK.tex)
    b.source = "textures natives de repli"
  end
  local fromTemplate = b.source and string.find(b.source, "gabarit", 1, true)
  local c = (nb and nb.color) or (not fromTemplate and V.BAR_FALLBACK.color) or nil
  if c and sb.SetStatusBarColor then pcall(sb.SetStatusBarColor, sb, c[1], c[2], c[3], c[4] or 1) end
  b.color = c
  b.fill = sb.GetStatusBarTexture and sb:GetStatusBarTexture() or b.fill
  -- fond + cadre : pièces natives clonées (positions relatives exactes)
  if nb and nb.look and nb.look.parts and #nb.look.parts > 0 and ns.NativeLook.ApplyClone then
    b.bg:Hide()
    b.border:Hide()
    b.lookParts = #nb.look.parts
    b._look = nb.look
  else
    b._look = nil
    if not fromTemplate then
      pcall(b.bg.SetTexture, b.bg, WHITE)
      local bc = V.BAR_FALLBACK.bgColor
      b.bg:SetVertexColor(bc[1], bc[2], bc[3], bc[4])
      b.bg:Show()
      if TrySetTex(b.border, V.BAR_FALLBACK.border) then b.border:Show() end
    end
  end
  local tf = nb and nb.textFont
  if not (tf and ns.NativeLook.ApplyFont(b.text, tf, false)) then SetFontSafe(b.text, "GameFontHighlightSmall") end
  b.textFont = tf
end

function V.PlaceBar(b, x, y, w, h)
  local o, sb = b.owner, b.frame
  b.x, b.y, b.w, b.h = x, y, w, h
  sb:ClearAllPoints()
  sb:SetPoint("TOPLEFT", o, "TOPLEFT", x, -y)
  sb:SetSize(w, h)
  if b._look then ns.NativeLook.ApplyClone(sb, b._look) end
  if b.border:IsShown() then
    b.border:ClearAllPoints()
    b.border:SetPoint("TOPLEFT", sb, "TOPLEFT", -5, 7)
    b.border:SetPoint("BOTTOMRIGHT", sb, "BOTTOMRIGHT", 5, -7)
  end
  b.innerW, b.fillH, b.fx, b.ft = w, h, 0, 0
end

function V.SetBar(b, cur, max, label, rested)
  cur, max = ns.N(cur) or 0, ns.N(max) or 0
  local pct = (max > 0) and math.max(0, math.min(1, cur / max)) or 0
  b.pct = pct
  local sb = b.frame
  if sb.SetMinMaxValues then pcall(sb.SetMinMaxValues, sb, 0, math.max(1, max)) end
  if sb.SetValue then pcall(sb.SetValue, sb, math.min(cur, math.max(1, max))) end
  local innerW = ns.N(b.innerW) or 0   -- 3.3.10 : barre jamais posée (grille d'icônes)
  local fw = innerW * pct
  if rested and rested > 0 and max > 0 then
    local x1 = innerW * math.min(1, (cur + rested) / max)
    local w = x1 - fw
    if w >= 1 and ns.N(b.h) then
      local c = UI.RESTED_COLOR or { 0.0, 0.39, 0.88, 0.45 }
      Solid(b.rested, c, c[4])
      b.rested:ClearAllPoints()
      b.rested:SetPoint("TOPLEFT", sb, "TOPLEFT", fw, 0)
      b.rested:SetSize(w, b.h)
      b.rested:Show()
      b.restedW = w
    else b.rested:Hide() b.restedW = 0 end
  else
    b.rested:Hide()
    b.restedW = nil
  end
  b.text:SetText(label or ((max > 0) and (tostring(cur) .. " / " .. tostring(max)) or tostring(cur)))
  b.text:SetTextColor(1, 1, 1)   -- toujours blanc, comme « 16 / 20 » natif
end

function V.ShowBar(b, show)
  if show then b.frame:Show() else b.frame:Hide() end
  if not show then b.rested:Hide() b.goal:Hide() end
  b.shown = show
end

------------------------------------------------------------------------------
-- Tuile = un Button
------------------------------------------------------------------------------
local function OnEnter(self)
  UI._hoverTile = self
  self._hover = true
  V.PaintTile(self)
  if self.data then UI:ShowDetailCached(self.data) end
  if self._warnText and GameTooltip then
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(self._warnText, 1, 0.82, 0.2, true)
    GameTooltip:Show()
  end
end
local function OnLeave(self)
  if self._warnText and GameTooltip then GameTooltip:Hide() end
  self._hover = false
  V.PaintTile(self)
  UI._hoverTile = nil
  local function back()
    if UI._hoverTile then return end
    local d = UI.selected
    if d then UI:ShowDetailCached(d) end
  end
  if type(C_Timer) == "table" and type(C_Timer.After) == "function" then C_Timer.After(0.05, back) else back() end
end
local function OnClick(self, button)
  if not self.data then return end
  local shift = type(IsShiftKeyDown) == "function" and IsShiftKeyDown()
  if button ~= "RightButton" and shift and ns.QoL and ns.QoL.ShareTile and ns.Opt("partage") then
    if ns.QoL.ShareTile(self.data) then return end
  end
  if button == "RightButton" then
    if shift then UI:CycleGoal(self.data) else UI:PromptGoal(self.data) end
    return
  end
  UI:SelectTile(self.data)
  -- 3.6.0 : clic gauche sur la goutte / case du total -> fenêtre Progression
  -- (un glisser est déjà filtré par Theme.WireTileDrag)
  if self.data.kind == "total" and not shift and ns.ProgressUI and ns.ProgressUI.OnTotalClick then
    if ns.ProgressUI.HideMini then pcall(ns.ProgressUI.HideMini) end
    if GameTooltip and self._tipShown and GameTooltip.Hide then GameTooltip:Hide() self._tipShown = nil end
    ns.ProgressUI.OnTotalClick(self, button)
  end
end

function V.NewTile(parent)
  local t = CreateFrame("Button", nil, parent)
  t:SetSize(120, 44)
  t._osrsOwn, t._osrsTile, t._osrsHit = true, true, true
  -- surbrillance : sous tout le contenu (comme la ligne native), toute la tuile
  t.hlTex = t:CreateTexture(nil, "BACKGROUND", nil, -8)
  t.hlTex:SetAllPoints(t)
  Solid(t.hlTex, { 1, 1, 1 }, 1)
  if t.hlTex.SetBlendMode then pcall(t.hlTex.SetBlendMode, t.hlTex, "ADD") end
  t.hlTex:Hide()
  -- icône : emplacement d'objet carré (petit cadre actuel), en régions
  t.slotBg = t:CreateTexture(nil, "BACKGROUND", nil, 1)
  t.icon = t:CreateTexture(nil, "ARTWORK", nil, 3)
  t.slotBorder = t:CreateTexture(nil, "OVERLAY", nil, 6)
  t.nameFS = Text(t, "GameFontNormal", "LEFT")
  if t.nameFS.SetWordWrap then t.nameFS:SetWordWrap(false) end
  t.levelFS = Text(t, "GameFontHighlightSmall", "RIGHT")
  t.tagFS = Text(t, "GameFontDisableSmall", "RIGHT")
  t.tagFS:Hide()
  t.warnTex = t:CreateTexture(nil, "OVERLAY", nil, 2)
  if not TrySetTex(t.warnTex, "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew") then TrySetTex(t.warnTex, "Interface\\DialogFrame\\UI-Dialog-Icon-AlertOther") end
  t.warnTex:SetSize(14, 14)
  t.warnTex:Hide()
  t.capIcon = t:CreateTexture(nil, "OVERLAY", nil, 2)
  TrySetTex(t.capIcon, "Interface\\GossipFrame\\TrainerGossipIcon")
  t.capIcon:SetSize(14, 14)
  t.capIcon:Hide()
  t.barv = V.NewBar(t)
  t:SetScript("OnEnter", OnEnter)
  t:SetScript("OnLeave", OnLeave)
  t:SetScript("OnClick", OnClick)
  if t.RegisterForClicks then pcall(t.RegisterForClicks, t, "LeftButtonUp", "RightButtonUp") end
  if t.SetHitRectInsets then t:SetHitRectInsets(0, 0, 0, 0) end
  t:EnableMouse(true)   -- état final posé APRÈS les SetScript
  t.hit = t             -- compatibilité : « le bouton de la tuile » = la tuile
  return t
end

function V.IconLook(t, size)
  local a = ns.Style and ns.Style.DiscoverItemSlot and ns.Style.DiscoverItemSlot() or {}
  local fb = ns.Style and ns.Style.SLOT_FALLBACK or {}
  local function place(tex, s)
    tex:ClearAllPoints()
    tex:SetPoint("CENTER", t, "LEFT", 2 + size / 2, 0)
    tex:SetSize(s, s)
  end
  place(t.slotBg, size)
  pcall(t.slotBg.SetTexture, t.slotBg, a.empty or fb.empty)
  place(t.icon, size)
  if t.icon.SetTexCoord then pcall(t.icon.SetTexCoord, t.icon, 0.07, 0.93, 0.07, 0.93) end
  local bs = math.floor(size * (a.ratio or fb.ratio or 1.6) + 0.5)
  place(t.slotBorder, bs)
  pcall(t.slotBorder.SetTexture, t.slotBorder, a.border or fb.border)
  t._slotSize = size
end

function UI:ResizeTile(t, tw, th)
  t:SetSize(tw, th)
  -- 3.0.1 : icône, marge du texte et barre de TAILLE FIXE (natif) : rien ne
  -- dépend de la largeur de la tuile ni de la fenêtre.
  local size = V.ICON_SIZE
  V.IconLook(t, size)
  local textX = V.TEXT_X
  local barW, barH = V.BarSize()
  -- 3.2.0 : jamais plus large que la tuile (toutes les tuiles d'une grille ont
  -- la même largeur, donc la même barre).
  if tw - textX - 3 < barW then barW = math.max(40, math.floor(tw - textX - 3)) end
  local textW = barW
  t._textX, t._textW = textX, textW
  local top = math.floor((th - (V.NAME_H + 2 + barH)) / 2)
  if top < 0 then top = 0 end
  t._barH, t._blockTop = barH, top
  t._rankInBar = true
  t._nameMaxW = math.max(40, tw - textX - 2)   -- le nom peut dépasser la barre (largeur de tuile)
  SetFontSafe(t.nameFS, "GameFontNormal")
  t.nameFS:ClearAllPoints()
  t.nameFS:SetPoint("TOPLEFT", t, "TOPLEFT", textX, -top)
  t.nameFS:SetWidth(t._nameMaxW)
  t.levelFS:ClearAllPoints()
  t.levelFS:SetPoint("TOPRIGHT", t, "TOPLEFT", textX + textW, -top)
  t.levelFS:SetWidth(1)
  t.tagFS:ClearAllPoints()
  t.tagFS:SetPoint("TOPRIGHT", t, "TOPLEFT", textX + textW, -top - 1)
  t.capIcon:ClearAllPoints() t.capIcon:SetPoint("TOPRIGHT", t, "TOPRIGHT", -2, -1)
  t.warnTex:ClearAllPoints() t.warnTex:SetPoint("TOPRIGHT", t, "TOPRIGHT", -2, -1)
  local key = V.BAR_STYLE or "repli"
  if t.barv._skinKey ~= key then V.SkinBar(t.barv) t.barv._skinKey = key end
  V.PlaceBar(t.barv, textX, top + V.NAME_H + 2, barW, barH)
end

function UI:NativeRowNameColor()
  local L = ns.NativeLook and ns.NativeLook.ProbeList and ns.NativeLook.ProbeList()
  local c = L and L.row and L.row.font and L.row.font.color
  return c or { 1, 1, 1 }
end

function UI:FitTileName(t)
  local fs = t.nameFS
  local function SW(x) local ok, w = pcall(x.GetStringWidth, x) return ok and ns.N(w) or 0 end
  local L = ns.NativeLook and ns.NativeLook.ProbeList and ns.NativeLook.ProbeList()
  local rowFont = L and L.row and L.row.font
  if not (rowFont and ns.NativeLook.ApplyFont(fs, rowFont)) then SetFontSafe(fs, "GameFontNormal") end
  local maxW = t._nameMaxW or t._textW or 80
  local tagShown = t.tagFS:IsShown() and (t.tagFS:GetText() or "") ~= ""
  local avail = tagShown and (maxW - SW(t.tagFS) - 6) or maxW
  if SW(fs) > avail then
    SetFontSafe(fs, "GameFontNormalSmall")
    if SW(fs) > avail and tagShown then t.tagFS:Hide() avail = maxW end
  end
  fs:SetWidth(math.max(10, avail))
  t._nameFont = fs.font
end

UI.PLACEHOLDER_GREY = { 0.50, 0.50, 0.50 }
function UI:UpdateTile(t, d)
  t.data = d
  t.nameFS:SetText(d.name or "")
  t.tagFS:SetText("") t.tagFS:Hide()
  H.SetTileIcon(t.icon, d.icon)
  if t.icon.SetDesaturated then pcall(t.icon.SetDesaturated, t.icon, false) end
  t.icon:SetAlpha(1) t.icon:Show()
  local rc = self:NativeRowNameColor()
  t.nameFS:SetTextColor(rc[1], rc[2], rc[3])
  local cap = (d.kind ~= "stat") and (ns.N(d.apiMax) or 0) or 0
  local cur = ns.N(d.current) or 0
  t.levelFS:SetText(H.DisplayNumber(d))
  H.ApplyNumberColor(t.levelFS, cur, cap > 0 and cap or 1, d)
  local grey = d.placeholder and UI.PLACEHOLDER_GREY or nil
  if cap > 0 then
    local xp = (d.kind == "level") and self:LevelBarXP(cur, cap) or nil
    V.ShowBar(t.barv, true)
    if xp then V.SetBar(t.barv, xp.cur, xp.max, nil, xp.rested)
    else V.SetBar(t.barv, grey and 0 or cur, cap) end
    if not t._rankInBar then t.barv.text:SetText("") end
  else
    V.ShowBar(t.barv, false)
  end
  if t._rankInBar and cap > 0 then t.levelFS:Hide() else t.levelFS:Show() end
  if grey then
    t._placeholder = true
    if d.icon then
      if t.icon.SetDesaturated then pcall(t.icon.SetDesaturated, t.icon, true) end
      t.icon:SetAlpha(0.55)
    else
      pcall(t.icon.SetTexture, t.icon, nil) t.icon:Hide()
    end
    t.nameFS:SetTextColor(grey[1], grey[2], grey[3])
    t.levelFS:SetText("0/" .. ((cap > 0) and tostring(cap) or "…"))
    t.levelFS:SetTextColor(grey[1], grey[2], grey[3])
    if not t._rankInBar or cap <= 0 then t.levelFS:Show() end
    if d.notLearnedTag then t.tagFS:SetText(d.notLearnedTag) t.tagFS:SetTextColor(grey[1], grey[2], grey[3]) t.tagFS:Show() end
  else
    t._placeholder = nil
  end
  self:FitTileName(t)
  -- objectif (repère sur la barre), palier, rappel d'arme
  local g = (not grey) and cap > 0 and ns.GetGoal and ns.GetGoal(self:GoalKey(d)) or nil
  -- 3.3.10 : la grille d'icônes n'a pas de barre posée (b.x/y/w/h = nil) :
  -- l'objectif reste enregistré (t._goal), le repère n'est dessiné que si la
  -- barre a une géométrie (cause de « View.lua:467 arithmetic on field 'h' »).
  local b = t.barv
  local geo = b and ns.N(b.x) and ns.N(b.y) and ns.N(b.w) and ns.N(b.h) and b.w > 0 and b.h > 0
  if g and g.rank and not geo then
    if b and b.goal then b.goal:Hide() end
    t._goal = g.rank
  elseif g and g.rank then
    if not TrySetTex(b.goal, "Interface\\CastingBar\\UI-CastingBar-Spark", "ADD") then FillTexture(b.goal, GOLD[1], GOLD[2], GOLD[3], 0.9) end
    local frac = math.min(1, math.max(0, g.rank / cap))
    b.goal:ClearAllPoints()
    b.goal:SetSize(10, b.h * 2)
    b.goal:SetPoint("CENTER", t, "TOPLEFT", b.x + b.w * frac, -(b.y + b.h / 2))
    b.goal._frac = frac
    b.goal:Show()
    t._goal = g.rank
  else
    t.barv.goal:Hide()
    t._goal = nil
  end
  local capped = (not grey) and ns.Opt("paliers") and self:IsCapped(d, cur, cap)
  if capped then t.capIcon:Show() else t.capIcon:Hide() end
  t._capped = capped and true or false
  local lag = (not grey) and ns.Opt("rappel") and self:WeaponLagInfo(d) or nil
  if lag and not self:InDruidForm() then
    t._warnText = Tr["Compétence d'arme sous-montée : "] .. tostring(lag.name) .. " " .. tostring(lag.cur) .. "/" .. tostring(lag.max)
    if ns.QoL and ns.QoL.MainWeaponHint then
      local okH, h = pcall(ns.QoL.MainWeaponHint)
      if okH and h then t._warnText = t._warnText .. "\n" .. h end
    end
    t.warnTex:Show()
  else
    t._warnText = nil
    t.warnTex:Hide()
  end
  t._weaponLag = lag
  if d.kind == "level" and self._pendingLevelPulse then SafeStep("pulsation niveau", self.PulseLevelTile, self) end
  SafeStep("prêts (tuile)", self.UpdateCraftBadge, self, t, d)
  V.PaintTile(t)
  t:Show()
end

-- Surbrillance native relevée (texture / fusion / alpha), sinon aplat additif
-- mesuré (+56/255 sur le fond brun).
function V.PaintTile(t)
  if not t or not t.hlTex then return end
  local d = t.data
  local selected = d and UI:IsSelectedData(d)
  -- 3.6.1 : en barre (format allongé), pas d'aplat blanc sur la rangée
  -- (goutte, « 1146 / 2460 », jauge). La case carrée est inchangée.
  local a = (not t._wideOn) and (selected and UI.HL_SELECTED or (t._hover and UI.HL_HOVER) or nil) or nil
  local L = ns.NativeLook and ns.NativeLook.ProbeList and ns.NativeLook.ProbeList()
  local nh = L and L.highlight
  if nh and not t._hlNative then
    local ok = false
    if nh.atlas and t.hlTex.SetAtlas then ok = pcall(t.hlTex.SetAtlas, t.hlTex, nh.atlas) end
    if not ok and nh.tex then ok = pcall(t.hlTex.SetTexture, t.hlTex, nh.tex) end
    if ok then
      if nh.blend and t.hlTex.SetBlendMode then pcall(t.hlTex.SetBlendMode, t.hlTex, nh.blend) end
      t.hlTex:SetVertexColor(1, 1, 1, 1)
      t._hlNative = true
      UI.hlSource = "surbrillance native (" .. tostring(nh.atlas or nh.tex) .. ")"
    end
  end
  if not t._hlNative then UI.hlSource = "aplat additif mesuré (" .. M.highlight .. ")" end
  if a then
    local na = (nh and nh.alpha) or 1
    if t._hlNative then t.hlTex:SetAlpha(selected and na or na * 0.6)
    else t.hlTex:SetAlpha(a) end
    t.hlTex:Show()
  else
    t.hlTex:Hide()
  end
  t._hlAlpha = a
end
function UI:PaintTileBg(t) V.PaintTile(t) end
function UI:PaintHover(t) V.PaintTile(t) end
------------------------------------------------------------------------------
-- En-têtes repliables = un Button chacun
------------------------------------------------------------------------------
function UI:IsGroupCollapsed(key)
  local cg = ns.db and ns.db.ui and ns.db.ui.collapsedGroups
  return cg and cg[key] and true or false
end
function UI:ToggleGroup(key)
  if not ns.db then DropamineDB = DropamineDB or {} ns.db = DropamineDB end
  ns.db.ui = ns.db.ui or {}
  ns.db.ui.collapsedGroups = ns.db.ui.collapsedGroups or {}
  ns.db.ui.collapsedGroups[key] = (not self:IsGroupCollapsed(key)) or nil
  if self.embed and self.embed._snap then self:LayoutGrid(self.embed, self.embed._snap) end
  return self:IsGroupCollapsed(key)
end

function UI:EnsureGroupHeader(wrap, i)
  wrap.headers = wrap.headers or {}
  local h = wrap.headers[i]
  if h then return h end
  h = CreateFrame("Button", nil, wrap.child)
  h._osrsOwn, h._osrsHeader = true, true
  -- repli (si l'en-tête natif n'est pas relevé) : couleurs mesurées
  h._vfb = {}
  for _, k in ipairs({ "fill", "top", "bottom", "left", "right" }) do h._vfb[k] = h:CreateTexture(nil, "BACKGROUND") end
  -- « − » / « + » jaunes : utilisés seulement si le clone natif n'en a pas
  h.minusTex = h:CreateTexture(nil, "OVERLAY")
  h.plusBar = h:CreateTexture(nil, "OVERLAY")
  h.minusTex:Hide() h.plusBar:Hide()
  h.text = Text(h, "GameFontNormal", "LEFT")
  h:SetScript("OnClick", function(self) if self.groupKey then UI:ToggleGroup(self.groupKey) end end)
  if h.RegisterForClicks then pcall(h.RegisterForClicks, h, "LeftButtonUp") end
  if h.SetHitRectInsets then h:SetHitRectInsets(0, 0, 0, 0) end
  h:EnableMouse(true)
  wrap.headers[i] = h
  return h
end

local function IsToggleId(id, tg)
  if type(id) ~= "string" then return false end
  if tg and (id == tg.minus or id == tg.plus) then return true end
  local l = string.lower(id)
  return string.find(l, "minus", 1, true) or string.find(l, "plus", 1, true) or false
end

function UI:SkinGroupHeader(h)
  local L = ns.NativeLook and ns.NativeLook.ProbeList and ns.NativeLook.ProbeList()
  local c = L and L.header
  if not h._osrsHeader then
    -- bandeau du total / en-tête de section du détail : une seule barre (repli mesuré)
    if h.bar then Solid(h.bar, M.headerFill) h.bar:Show() end
    if h.text then h.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) end
    self.headerAsset = self.headerAsset or "repli mesuré (brun 47,28,13)"
    return "repli mesuré"
  end
  h._togglePart, h._togglePartDesc = nil, nil
  if c and c.parts and #c.parts > 0 and ns.NativeLook.ApplyClone and ns.NativeLook.ApplyClone(h, c) then
    for _, x in pairs(h._vfb) do x:Hide() end
    for i, p in ipairs(c.parts) do
      if IsToggleId(p.atlas or p.tex, c.toggle) and h._nlParts and h._nlParts[i] then
        h._togglePart, h._togglePartDesc = h._nlParts[i], p
        break
      end
    end
    if not h._togglePart then
      -- nom de texture inconnu : la petite pièce (≤ 20 px) collée au bord droit
      -- de l'en-tête natif EST son « − » (jamais d'indicateur en double)
      for i, p in ipairs(c.parts) do
        if p.layer ~= "HIGHLIGHT" and (p.w or 99) <= 20 and (p.h or 99) <= 20 and (p.dr or -99) >= -30 and (p.dl or 0) > 40
            and h._nlParts and h._nlParts[i] then
          h._togglePart, h._togglePartDesc = h._nlParts[i], p
          break
        end
      end
    end
    if not (c.font and ns.NativeLook.ApplyFont(h.text, c.font, true)) then
      SetFontSafe(h.text, "GameFontNormal")
      h.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    end
    h.text:ClearAllPoints()
    h.text:SetPoint("LEFT", h, "LEFT", c.textLeft or M.px.headerTextLeft, 0)
    h.text:SetPoint("RIGHT", h, "RIGHT", -24, 0)
    self.headerAsset = "clone en-tête natif (" .. tostring(h._nlAsset) .. ")"
    return self.headerAsset
  end
  if h._nlParts then for _, x in ipairs(h._nlParts) do x:Hide() end end
  local fb = h._vfb
  fb.fill:ClearAllPoints() fb.fill:SetPoint("TOPLEFT", h, "TOPLEFT", 1, -2) fb.fill:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", -1, 2)
  Solid(fb.fill, M.headerFill)
  fb.top:ClearAllPoints() fb.top:SetPoint("TOPLEFT", h, "TOPLEFT", 0, 0) fb.top:SetPoint("TOPRIGHT", h, "TOPRIGHT", 0, 0) fb.top:SetHeight(2)
  Solid(fb.top, M.headerEdge)
  fb.bottom:ClearAllPoints() fb.bottom:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 0, 0) fb.bottom:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 0, 0) fb.bottom:SetHeight(2)
  Solid(fb.bottom, M.headerEdgeBottom)
  fb.left:ClearAllPoints() fb.left:SetPoint("TOPLEFT", h, "TOPLEFT", 0, 0) fb.left:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 0, 0) fb.left:SetWidth(1)
  Solid(fb.left, M.headerEdge)
  fb.right:ClearAllPoints() fb.right:SetPoint("TOPRIGHT", h, "TOPRIGHT", 0, 0) fb.right:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 0, 0) fb.right:SetWidth(1)
  Solid(fb.right, M.headerEdge)
  for _, x in pairs(fb) do x:Show() end
  SetFontSafe(h.text, "GameFontNormal")
  h.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
  h.text:ClearAllPoints()
  h.text:SetPoint("LEFT", h, "LEFT", M.px.headerTextLeft, 0)
  h.text:SetPoint("RIGHT", h, "RIGHT", -24, 0)
  self.headerAsset = "repli mesuré (brun " .. "47,28,13)"
  return self.headerAsset
end

-- Un seul indicateur, à DROITE : le « − » jaune de l'en-tête natif copié.
-- Replié : texture « Plus » native si elle existe, sinon barre verticale de la
-- même couleur posée sur le « − » (donne le « + »).
function UI:PaintGroupToggle(h, collapsed)
  local L = ns.NativeLook and ns.NativeLook.ProbeList and ns.NativeLook.ProbeList()
  local tg = L and L.header and L.header.toggle
  local part, p = h._togglePart, h._togglePartDesc
  h.plusBar:Hide()
  h.minusTex:Hide()
  local cx, cy, pw, ph
  if part then
    part:Show()
    local want = collapsed and (tg and tg.plus) or (tg and tg.minus) or (p.atlas or p.tex)
    local cur = part._osrsToggleId or (p.atlas or p.tex)
    local swapped = false
    if collapsed and want and want ~= (p.atlas or p.tex) then
      if p.atlas and part.SetAtlas then swapped = pcall(part.SetAtlas, part, want) end
      if not swapped then swapped = pcall(part.SetTexture, part, want) end
    elseif not collapsed and cur ~= (p.atlas or p.tex) then
      if p.atlas and part.SetAtlas then pcall(part.SetAtlas, part, p.atlas) else pcall(part.SetTexture, part, p.tex) end
    end
    part._osrsToggleId = collapsed and swapped and want or (p.atlas or p.tex)
    h.toggleSource = "en-tête natif"
    if collapsed and not swapped then
      -- « + » = « − » natif + barre verticale identique (même centre)
      pw, ph = p.w or M.px.toggleW, p.h or M.px.toggleH
      h.plusBar:ClearAllPoints()
      h.plusBar:SetPoint("CENTER", part, "CENTER", 0, 0)
      h.plusBar:SetSize(math.max(2, math.floor(ph + 0.5)), math.max(6, math.floor(pw + 0.5)))
      Solid(h.plusBar, M.toggle)
      h.plusBar:Show()
    end
  else
    -- pas de « − » dans l'en-tête copié : le nôtre, mesuré, au même endroit (droite)
    local px = M.px
    h.minusTex:ClearAllPoints()
    h.minusTex:SetPoint("RIGHT", h, "RIGHT", -px.toggleRight, 0)
    h.minusTex:SetSize(px.toggleW, px.toggleH)
    Solid(h.minusTex, M.toggle)
    h.minusTex:Show()
    if collapsed then
      h.plusBar:ClearAllPoints()
      h.plusBar:SetPoint("CENTER", h.minusTex, "CENTER", 0, 0)
      h.plusBar:SetSize(px.toggleH, px.toggleW)
      Solid(h.plusBar, M.toggle)
      h.plusBar:Show()
    end
    h.toggleSource = "repli mesuré"
  end
  h._toggleState = collapsed and "+" or "-"
end

------------------------------------------------------------------------------
-- Mise en page de la grille
------------------------------------------------------------------------------
local TILE_HGAP = 8
local TILE_VGAP = 6
V.PITCH_MAX = 62
-- Pas minimal : nom + barre native + espace.
function V.MinPitch()
  local _, bh = V.BarSize()
  return V.NAME_H + 2 + bh + TILE_VGAP
end

-- 3.0.1 : UN pas de rangée, calculé une fois sur la disposition TOUT DÉPLIÉE
-- (toutes les rangées de tous les groupes remplissent la hauteur entre le haut
-- de la liste et le bandeau du total). Replier un groupe ne le change pas : le
-- contenu reste en haut, l'espace libre se met au-dessus du bandeau.
function UI:FitGrid(wrap, n)
  local w = (wrap and wrap._innerW) or self:GetGridInnerWidth(wrap)
  local cols = 2
  local tw = math.floor((w - (cols - 1) * TILE_HGAP) / cols)
  if tw < 60 then tw = 60 end
  local groups = wrap and wrap._snap and self:GroupTiles(wrap._snap.tiles) or nil
  local rowsAll, nG = 0, 0
  if groups and #groups > 0 then
    nG = #groups
    for gi = 1, #groups do rowsAll = rowsAll + math.ceil(#groups[gi].tiles / cols) end
  else
    rowsAll = math.ceil((n or 1) / cols)
  end
  rowsAll = math.max(1, rowsAll)
  local availH = wrap and wrap._availH
  if not availH or availH <= 0 then availH = self:GridAreaHeight(wrap) end
  local hdrH = nG * (UI.HEADER_H + UI.HEADER_GAP)
  local step = (availH - hdrH) / rowsAll
  step = math.min(step, V.PITCH_MAX)
  step = math.max(step, V.MinPitch())
  step = math.floor(step * 100 + 0.5) / 100
  local th = math.floor(math.min(step - TILE_VGAP, 56))
  local minTh = V.MinPitch() - TILE_VGAP
  if th < minTh then th = minTh end
  return cols, tw, th, step, rowsAll
end

-- Hauteur du contenu (groupes repliés compris) pour un pas donné.
function UI:GridContentHeight(groups, cols, step)
  local y = 0
  for _, g in ipairs(groups or {}) do
    y = y + UI.HEADER_H + UI.HEADER_GAP
    if not self:IsGroupCollapsed(g.title) then y = y + math.ceil(#g.tiles / cols) * step end
  end
  return y
end

function UI:LayoutGrid(wrap, snap)
  if not wrap or not snap then return end
  -- 3.5.21 / 3.6.3 : SkillFrame protégé → valeurs seulement, mise en page
  -- après le combat. Le panneau compact (W.frame) n'est pas protégé : on
  -- relance la grille tout de suite pour recaler la hauteur du fond.
  if ns.InCombat and ns.InCombat() and wrap._layout and wrap.tiles and #wrap.tiles > 0 then
    local prot = (wrap.IsProtected and wrap:IsProtected())
      or (wrap.child and wrap.child.IsProtected and wrap.child:IsProtected())
    if prot then
      if self.RefreshVisibleTiles then self:RefreshVisibleTiles(wrap, snap) end
      if ns.AfterCombat then
        ns.AfterCombat("layout-grid", function()
          if wrap._snap then self:LayoutGrid(wrap, wrap._snap) end
          if ns.Layout and ns.Layout.Center then pcall(ns.Layout.Center) end
        end)
      end
      return
    end
  end
  wrap._snap = snap
  local tiles = snap.tiles or {}
  local child = wrap.child
  child:ClearAllPoints()
  local compact = ns.Panel and ns.Panel.IsExpanded and not ns.Panel.IsExpanded()
  local tileHGap = TILE_HGAP
  if compact then
    if ns.Layout and ns.Layout.SyncMetrics then pcall(ns.Layout.SyncMetrics) end
    tileHGap = (ns.Icons and ns.Icons.HGAP) or TILE_HGAP
  end
  local ins = (wrap == self.embed) and self:ListInsets() or nil
  -- Le cadre compact a déjà la même marge des 4 côtés : plus d'inset interne
  -- (20 px à droite pour une barre de défilement cachée, 6+2 en haut/bas)
  -- qui masquait la dernière rangée (case total) une fois le cadre calé.
  if compact then
    ins = { left = 0, right = 0, top = 0, source = "cadre exact" }
  end
  local pad = 8
  local footSpace = compact and 0 or (UI.NO_FOOT and 2 or (pad + 26 + 4))
  if ins then
    child:SetPoint("TOPLEFT", wrap, "TOPLEFT", ins.left, -ins.top)
    child:SetPoint("BOTTOMRIGHT", wrap, "BOTTOMRIGHT", -ins.right, footSpace)
  else
    child:SetPoint("TOPLEFT", wrap, "TOPLEFT", pad, -pad)
    child:SetPoint("BOTTOMRIGHT", wrap, "BOTTOMRIGHT", -pad, footSpace)
  end
  -- hauteur réellement disponible (entre le haut de la liste et le bandeau)
  local availH
  local cl, cr, ct, cb = H.RectOf(child)
  wrap._innerW = (cl and cr and cr > cl) and (cr - cl) or nil
  if ct and cb and ct > cb then availH = ct - cb
  else
    local _, wh = SizeOf(wrap)
    if wh and wh > 0 then availH = wh - (ins and ins.top or pad) - footSpace end
  end
  wrap._availH = availH
  local cols, tw, th, step = self:FitGrid(wrap, math.max(#tiles, 1))
  local groups = self:GroupTiles(tiles)
  local contentH = self:GridContentHeight(groups, cols, step)
  local maxScroll = math.max(0, contentH - (availH or contentH))
  local off = math.max(0, math.min(wrap._scroll or 0, maxScroll))
  wrap._scroll, wrap._maxScroll = off, maxScroll
  self.gridSqueezed = nil
  wrap._layout = { tw = tw, th = th, step = step, cols = cols, availH = availH, contentH = contentH,
    scroll = off, maxScroll = maxScroll, overflow = maxScroll > 0.5 }
  local ti = 0
  local function nextTile()
    ti = ti + 1
    if not wrap.tiles[ti] then wrap.tiles[ti] = V.NewTile(child) end
    return wrap.tiles[ti]
  end
  local y, rowsUsed, cells = 0, 0, {}
  local hx = math.floor(tileHGap / 2)
  local hy = math.max(0, math.floor((step - th) / 2))
  local limit = (availH or 1e9) + 0.5
  -- un élément n'est montré que s'il tient ENTIER dans la fenêtre visible
  local function inView(top, h) return top - off >= -0.5 and top - off + h <= limit end
  local shownTiles, hiddenByScroll = 0, 0
  for gi = 1, #groups do
    local g = groups[gi]
    local h = self:EnsureGroupHeader(wrap, gi)
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -math.floor(y - off))
    local cw = select(1, SizeOf(child))
    h:SetSize((cw and cw > 40) and cw or (cols * tw + (cols - 1) * tileHGap), UI.HEADER_H)
    h.text:SetText(g.title)
    h.groupKey = g.title
    self:SkinGroupHeader(h)
    local collapsed = self:IsGroupCollapsed(g.title)
    self:PaintGroupToggle(h, collapsed)
    if inView(y, UI.HEADER_H) then h:EnableMouse(true) h:Show() else h:Hide() h:EnableMouse(false) end
    h._contentY = y
    y = y + UI.HEADER_H + UI.HEADER_GAP
    for k = 1, (collapsed and 0 or #g.tiles) do
      local col, row = (k - 1) % cols, math.floor((k - 1) / cols)
      -- En compact, le cadre est calé sur rows×case + (rows-1)×écart : on
      -- n'ajoute pas (step-th)/2, qui poussait la dernière rangée hors vue.
      local compact = ns.Panel and ns.Panel.IsExpanded and not ns.Panel.IsExpanded()
      local data = g.tiles[k]
      local placeH = th
      local Wd, Lyt = ns.Wide, ns.Layout
      if compact and data and data.kind == "total" and Wd and Wd.ShouldWiden then
        local nTot = (Lyt and Lyt.TileCount and select(1, Lyt.TileCount())) or 0
        if Wd.ShouldWiden(cols, nTot) then
          local tileH = (ns.Icons and ns.Icons.TILE) or th
          placeH = (Wd.RowHeight and Wd.RowHeight(tileH)) or math.max(Wd.MIN_H or 14, math.floor(tileH * (Wd.SLIM or 0.45) + 0.5))
        end
      end
      local cyAbs = math.floor(y + row * step + (compact and 0 or (step - th) / 2))
      -- Ne pas masquer le total (barre fine) : inView avec une hauteur de case
      -- pleine le faisait tomber hors cadre.
      if (compact and data and data.kind == "total") or inView(cyAbs, placeH) then
        local t = nextTile()
        local cy = cyAbs - math.floor(off)
        t:ClearAllPoints()
        local gx = col * (tw + tileHGap)
        if compact and Lyt and Lyt.GridOriginX then
          gx = gx + (Lyt.GridOriginX(cols) or 0)
        end
        t:SetPoint("TOPLEFT", child, "TOPLEFT", gx, -cy)
        cells[#cells + 1] = { x = gx, y = cy, w = tw, h = placeH }
        self:ResizeTile(t, tw, placeH)
        self:UpdateTile(t, g.tiles[k])
        t._cell = { x = cells[#cells].x - hx, y = cy - hy, w = tw + 2 * hx, h = th + 2 * hy }
        if t.SetHitRectInsets then t:SetHitRectInsets(-hx, -hx, -hy, -hy) end
        t:EnableMouse(true)
        shownTiles = shownTiles + 1
      else
        hiddenByScroll = hiddenByScroll + 1
      end
    end
    local nr = collapsed and 0 or math.ceil(#g.tiles / cols)
    rowsUsed = rowsUsed + nr
    y = y + nr * step
  end
  wrap._layout.hiddenByScroll = hiddenByScroll
  for gi = #groups + 1, #(wrap.headers or {}) do wrap.headers[gi]:Hide() end
  for i = ti + 1, #wrap.tiles do
    local t = wrap.tiles[i]
    t:Hide()
    t:EnableMouse(false)
    t.data = nil
  end
  wrap._layout.cells, wrap._layout.groups, wrap._layout.rows = cells, #groups, rowsUsed
  wrap._layout.hitPad = { x = hx, y = hy }
  if wrap == self.embed then self:SetEmbedLevels() end
  local full, short = self:FooterText(snap)
  if wrap.totalFS.SetWordWrap then wrap.totalFS:SetWordWrap(false) end
  wrap.totalFS:SetText(full)
  local okW, sw = pcall(wrap.totalFS.GetStringWidth, wrap.totalFS)
  sw = okW and ns.N(sw) or nil
  if sw and sw > self:GetGridInnerWidth(wrap) - 12 then wrap.totalFS:SetText(short) end
  if wrap.realFS then wrap.realFS:SetText("") wrap.realFS:Hide() end
  self:LayoutFooter(wrap)
  if wrap == self.embed then SafeStep("défilement", self.UpdateGridScrollBar, self, wrap) end
  self:ResolveSelected()
  for i = 1, #wrap.tiles do V.PaintTile(wrap.tiles[i]) end
  if ns.Window and ns.Window.IsShown and ns.Window.IsShown()
    and ns.Layout and ns.Layout.Center then
    pcall(ns.Layout.Center)
  end
end

-- Niveaux simples, posés une fois par mise en page : encadré = SkillFrame +
-- EMBED_LIFT ; zone = +1 ; tuiles / en-têtes / bandeau = +2. Rien d'autre.
UI.EMBED_LIFT = 10
function UI:SetEmbedLevels()
  local embed, f = self.embed, self.skillFrame
  if not embed then return end
  local fl = 0
  if f and f.GetFrameLevel then local ok, v = pcall(f.GetFrameLevel, f) fl = ok and ns.N(v) or 0 end
  local base = fl + UI.EMBED_LIFT
  if f and f.GetFrameStrata and embed.SetFrameStrata then
    local ok, st = pcall(f.GetFrameStrata, f)
    if ok and st then pcall(embed.SetFrameStrata, embed, st) end
  end
  pcall(embed.SetFrameLevel, embed, base)
  embed:EnableMouse(true)   -- les trous de la grille ne laissent rien passer au natif
  if embed.child then pcall(embed.child.SetFrameLevel, embed.child, base + 1) embed.child:EnableMouse(false) end
  for _, h in ipairs(embed.headers or {}) do pcall(h.SetFrameLevel, h, base + 2) end
  for _, t in ipairs(embed.tiles or {}) do
    pcall(t.SetFrameLevel, t, base + 2)
    if t.craftBadge then pcall(t.craftBadge.SetFrameLevel, t.craftBadge, base + 3) if t.craftBadge.EnableMouse then t.craftBadge:EnableMouse(false) end end
    if t._pulse and t._pulse.frame and t._pulse.frame.EnableMouse then t._pulse.frame:EnableMouse(false) end
  end
  if embed.foot then pcall(embed.foot.SetFrameLevel, embed.foot, base + 2) end
  if self.viewToggle and self.viewToggle.SetFrameLevel then pcall(self.viewToggle.SetFrameLevel, self.viewToggle, base + 6) end
  self.embedLevel, self.hitLevel = base, base + 2
  return base
end
UI.RaiseEmbed = UI.SetEmbedLevels
UI.RaiseTileHits = UI.SetEmbedLevels

------------------------------------------------------------------------------
-- Natif : liste et détail (Hide / Show, jamais en combat)
------------------------------------------------------------------------------
function V.NativeListObjects()
  local f = UI.skillFrame
  local out, seen = {}, {}
  local function add(o) if type(o) == "table" and o.Hide and not seen[o] and not H.IsOwnFrame(o) and not o._osrsOwn then seen[o] = true out[#out + 1] = o end end
  add(UI.nativeLeft)
  -- (la barre de défilement native reste visible : décor de la liste, hors des tuiles — choix 2.8.4 conservé)
  if f then add(f.ScrollBox) end
  add(_G.SkillListScrollFrame)
  add(_G.SkillFrameExpandButtonFrame)
  add(_G.SkillFrameCollapseAllButton)
  local okR, rows = pcall(UI.NativeListRows, UI)
  for _, r in ipairs(okR and rows or {}) do add(r) end
  -- Tout autre cadre natif posé SUR la zone de la liste (enfant direct de la
  -- fiche ou du volet gauche) qui prend la souris ou porte du texte : caché
  -- lui aussi. Les cadres de pur décor (textures sans souris ni texte) restent.
  for _, o in ipairs(V.ListAreaFrames()) do add(o) end
  return out
end

local function MouseInTree(o, depth)
  if type(o) ~= "table" or depth > 3 then return false end
  if o.IsMouseEnabled then
    local ok, m = pcall(o.IsMouseEnabled, o)
    if ok and m then return true end
  end
  if o.GetChildren then
    local kids = { pcall(o.GetChildren, o) }
    for i = 2, #kids do if MouseInTree(kids[i], depth + 1) then return true end end
  end
  return false
end
V.MouseInTree = MouseInTree

function V.ListAreaFrames()
  local out = {}
  local f, e = UI.skillFrame, UI.embed
  if not (f and e) then return out end
  local el, er, et, eb = H.RectOf(e)
  if not (el and er and et and eb) or er <= el or et <= eb then return out end
  local protect = { UI.ownDetail, UI.embed, UI.viewToggle, UI.collapseArrow, UI.nativeDetail,
    UI.GetDetailParent and UI:GetDetailParent() or nil, _G.SkillDetailScrollFrame, _G.CharacterFrameCloseButton }
  local function protected(o)
    for _, p in pairs(protect) do
      if p and (o == p or H.IsDescendantOf(p, o)) then return true end
    end
    if H.IsCollapseWidget(o) then return true end
    local n = string.lower(tostring((o.GetName and o:GetName()) or ""))
    if string.find(n, "tab", 1, true) or string.find(n, "close", 1, true) or string.find(n, "detail", 1, true)
        or string.find(n, "scrollbar", 1, true) or (f and o == f.ScrollBar) then return true end
    return false
  end
  local function scan(root)
    if type(root) ~= "table" or not root.GetChildren then return end
    local kids = { pcall(root.GetChildren, root) }
    for i = 2, #kids do
      local o = kids[i]
      if type(o) == "table" and o.Hide and not H.IsOwnFrame(o) and not o._osrsOwn and not protected(o) then
        local l, r, t, b = H.RectOf(o)
        if l and r and t and b and r > l and t > b then
          local ow = math.max(0, math.min(r, er) - math.max(l, el))
          local oh = math.max(0, math.min(t, et) - math.max(b, eb))
          local frac = (ow * oh) / ((r - l) * (t - b))
          if frac >= 0.5 and (MouseInTree(o, 0) or H.HasContent(o, 0)) then out[#out + 1] = o end
        end
      end
    end
  end
  scan(f)
  if UI.nativeLeft and UI.nativeLeft ~= f then scan(UI.nativeLeft) end
  UI.listAreaHidden = #out
  return out
end
function UI:SetNativeListShown(show)
  for _, o in ipairs(V.NativeListObjects()) do NativeVeil(o, not show) end
  self.nativeListHidden = not show
end
-- compatibilité avec les crochets de mise à jour native
function UI:SetNativeListRowsShown(show) self:SetNativeListShown(show) end

function UI:HideOwnFrames()
  local e = self.embed
  if e then
    for _, t in ipairs(e.tiles or {}) do t:EnableMouse(false) end
    for _, h in ipairs(e.headers or {}) do h:EnableMouse(false) end
    e:EnableMouse(false)
    e:Hide()
  end
  if self.ownDetail then self.ownDetail:Hide() end
  if self.detailBottom then self.detailBottom:Hide() end
end

function UI:RestoreNativeAll()
  if ns.InCombat and ns.InCombat() then
    ns.AfterCombat("vue-classique", function() if not UI:IsOsrsView() then UI:RestoreNativeAll() end end)
    self.classicRestorePending = true
    return false
  end
  self.classicRestorePending = nil
  self:SetNativeListShown(true)
  SafeStep("détail natif", self.SetNativeDetailShown, self, true)
  SafeStep("ornements", self.RestoreDetailEdge, self)
  local n = 0
  for obj in pairs(UI._VEIL) do NativeVeil(obj, false) n = n + 1 end
  self.classicRestored = n
  return true
end

-- Nos cadres visibles ET sensibles à la souris sur la fiche (vide en vue classique).
function UI:OwnMouseBlockers()
  local out = {}
  local c = { self.embed, self.ownDetail, self.embed and self.embed.foot }
  for _, t in ipairs(self.embed and self.embed.tiles or {}) do c[#c + 1] = t end
  for _, h in ipairs(self.embed and self.embed.headers or {}) do c[#c + 1] = h end
  if self.ownDetail then c[#c + 1] = self.ownDetail.scroll c[#c + 1] = self.ownDetail.titleHit end
  for _, o in ipairs(c) do
    if type(o) == "table" then
      local okV, vis = pcall(function() return o:IsVisible() end)
      local okM, mo = pcall(function() return o.IsMouseEnabled and o:IsMouseEnabled() end)
      if okV and vis and okM and mo then out[#out + 1] = o end
    end
  end
  return out
end

------------------------------------------------------------------------------
-- Passage de vue
------------------------------------------------------------------------------
function UI:ApplyViewInner()
  self._nativeRescan = true
  local f = self.skillFrame or self:FindSkillFrame()
  if not f then return end
  self.skillFrame = f
  local okL, left, detail = pcall(self.LocateNativePanes, self, f)
  if not okL then left, detail = _G.SkillListScrollFrame, _G.SkillDetailFrame end
  if H.IsOwnFrame(left) then left = nil end
  if H.IsOwnFrame(detail) then detail = nil end
  self.nativeLeft, self.nativeDetail = left, detail
  -- relevé du natif seulement quand il est visible (jamais sur une liste cachée)
  if not self.nativeListHidden then SafeStep("relevé liste native", self.RefreshNativeProbe, self) end
  SafeStep("bouton Vue classique", self.EnsureViewToggle, self, f)
  local osrs = self:IsOsrsView()
  if osrs then
    local okE = SafeStep("grille Comp.", self.EnsureEmbed, self, f)
    if not okE or not self.embed then
      self:SetNativeListShown(true)
      if self.viewToggle then self.viewToggle:Show() end
      SafeStep("placement du bouton", self.PlaceViewToggle, self)
      return
    end
    local embed = self.embed
    embed:Show()
    embed:EnableMouse(true)
    SafeStep("mise en page", self.LayoutForPane, self)
    if not self.snapshot then
      local okC, snap = pcall(ns.Collect)
      if okC then self.snapshot = snap else SafeStep("collecte", error, snap) end
    end
    if self.snapshot then SafeStep("grille (tuiles)", self.LayoutGrid, self, embed, self.snapshot) end
    SafeStep("niveaux", self.SetEmbedLevels, self)
    SafeStep("liste native cachée", self.SetNativeListShown, self, false)
  else
    SafeStep("vue classique (nos cadres)", self.HideOwnFrames, self)
    SafeStep("vue classique (natif)", self.RestoreNativeAll, self)
  end
  if self.viewToggle then self.viewToggle:Show() end
  SafeStep("placement du bouton", self.PlaceViewToggle, self)
  SafeStep("texte du bouton", self.SetViewToggleText, self)
  SafeStep("chrome natif", self.LearnNativeChrome, self)
  SafeStep("sonde natives", self.ProbeNativeUpdateFunctions, self)
  if osrs then
    SafeStep("détail", function()
      self:EnsureOwnDetail(self.nativeDetail)
      self:SetNativeDetailShown(false)
      self:HookDetailVisibility(self:GetDetailParent())
      if self.detailBottom then self.detailBottom:Hide() end
      if self:ResolveSelected() then
        self:ShowDetail(self.selected, "restore")
      elseif self.snapshot and self.snapshot.tiles and self.snapshot.tiles[1] then
        self:SelectTile(self.snapshot.tiles[1])
      end
      self:HookNativeUpdatesForHide()
      self:CoverDetailEdge("vue OSRS")
    end)
  end
  SafeStep("onglet (hook)", self.HookCharacterFrameForTab, self)
  SafeStep("icône d'onglet", self.ApplyTabIcon, self)
end

------------------------------------------------------------------------------
-- /drop hitdebug
------------------------------------------------------------------------------
function UI:MouseFocusName()
  local fo
  if type(GetMouseFoci) == "function" then
    local ok, t = pcall(GetMouseFoci)
    if ok and type(t) == "table" then fo = t[1] end
  end
  if not fo and type(GetMouseFocus) == "function" then
    local ok, x = pcall(GetMouseFocus)
    if ok then fo = x end
  end
  if type(fo) ~= "table" then return "aucun" end
  if fo._osrsTile then return "tuile « " .. tostring(fo.data and fo.data.name) .. " » (à nous, OK)" end
  if fo._osrsHeader then return "en-tête « " .. tostring(fo.groupKey) .. " » (à nous, OK)" end
  local n = fo.GetName and fo:GetName()
  if type(n) ~= "string" or n == "" then
    local p = fo.GetParent and fo:GetParent()
    n = "(sans nom, " .. tostring(fo.GetObjectType and fo:GetObjectType()) .. ", parent " .. tostring(p and p.GetName and p:GetName()) .. ")"
  end
  local okL, lv = pcall(fo.GetFrameLevel, fo)
  return n .. " niveau " .. tostring(okL and lv) .. ((H.IsOwnFrame(fo) or fo._osrsOwn) and " [à nous]" or " [NATIF]")
end

-- Cadres NON à nous, visibles et sensibles à la souris, sous le centre d'une
-- tuile avec une strate / un niveau ≥ celui de la tuile (= voleurs de clic).
local STRATA_N = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
function V.ForeignMouseOver(t)
  local out = {}
  local f = UI.skillFrame
  if not (t and f) then return out end
  local l, r, tp, b = H.RectOf(t)
  if not l then return out end
  local cx, cy = (l + r) / 2, (tp + b) / 2
  local function sv(o)
    local okS, s = pcall(o.GetFrameStrata, o)
    return STRATA_N[okS and s or "MEDIUM"] or 3
  end
  local ts, tl = sv(t), t:GetFrameLevel() or 0
  local function walk(o, depth)
    if type(o) ~= "table" or depth > 5 or not o.GetChildren then return end
    local kids = { pcall(o.GetChildren, o) }
    for i = 2, #kids do
      local c = kids[i]
      if type(c) == "table" and not H.IsOwnFrame(c) and not c._osrsOwn then
        local okV, vis = pcall(c.IsVisible, c)
        if okV and vis then
          local okM, m = pcall(c.IsMouseEnabled, c)
          local cl, cr, ct, cb = H.RectOf(c)
          if okM and m and cl and cx >= cl and cx <= cr and cy <= ct and cy >= cb then
            local cs, clv = sv(c), (c.GetFrameLevel and c:GetFrameLevel()) or 0
            if cs > ts or (cs == ts and clv >= tl) then out[#out + 1] = c end
          end
          walk(c, depth + 1)
        end
      end
    end
  end
  walk(f, 0)
  return out
end

function UI:HitDebug(arg)
  local on = not self._hitDebug
  if arg == "off" or arg == "0" then on = false elseif arg == "on" or arg == "1" then on = true end
  self._hitDebug = on
  local P = ns.Print or print
  local embed = self.embed
  for _, t in ipairs(embed and embed.tiles or {}) do
    if on and not t._dbg then
      t._dbg = t:CreateTexture(nil, "OVERLAY", nil, 7)
      t._dbg:SetAllPoints(t)
      FillTexture(t._dbg, 1, 0, 0, 0.30)
    end
    if t._dbg then if on then t._dbg:Show() else t._dbg:Hide() end end
  end
  if not on then
    if self._hitTicker then self._hitTicker:SetScript("OnUpdate", nil) end
    P("hitdebug : désactivé.")
    return
  end
  if not self:IsOsrsView() then
    local bl = self:OwnMouseBlockers()
    P("hitdebug (vue classique) : " .. (#bl == 0 and "aucun cadre de l'addon ne capte la souris sur la fiche (OK)."
      or (#bl .. " cadre(s) de l'addon captent encore la souris !")))
  else
    P(string.format("hitdebug : niveau des tuiles %s (encadré %s), liste native %s.",
      tostring(self.hitLevel), tostring(self.embedLevel), self.nativeListHidden and "cachée" or "visible"))
    local thieves = 0
    for _, t in ipairs(embed and embed.tiles or {}) do
      if t:IsShown() then
        local w, h = SizeOf(t)
        local fm = V.ForeignMouseOver(t)
        thieves = thieves + #fm
        local who = ""
        if #fm > 0 then
          local names = {}
          for _, c in ipairs(fm) do names[#names + 1] = tostring((c.GetName and c:GetName()) or "?") .. "@" .. tostring(c:GetFrameLevel()) end
          who = " — VOLÉ PAR " .. table.concat(names, ", ")
        end
        P(string.format("  bouton %dx%d « %s », niveau %s, souris %s%s", w or -1, h or -1, tostring(t.data and t.data.name),
          tostring(t:GetFrameLevel()), tostring(t:IsMouseEnabled()), who))
      end
    end
    P(thieves == 0 and "hitdebug : aucun cadre natif au-dessus des tuiles (OK)." or ("hitdebug : " .. thieves .. " cadre(s) natif(s) au-dessus de tuiles !"))
  end
  self._hitTicker = self._hitTicker or CreateFrame("Frame")
  local last, acc = nil, 0
  self._hitTicker:SetScript("OnUpdate", function(_, el)
    acc = acc + (el or 0)
    if acc < 0.15 then return end
    acc = 0
    local n = UI:MouseFocusName()
    if n ~= last then last = n P("souris sur : " .. n) end
  end)
end

------------------------------------------------------------------------------
-- 3.0.1 — corrections ciblées (architecture des clics et toast inchangés)
------------------------------------------------------------------------------
local RectOf = H.RectOf
local function N(v) return ns.N(v) end
local function ObjType(o)
  if type(o) ~= "table" or not o.GetObjectType then return nil end
  local ok, t = pcall(o.GetObjectType, o)
  return ok and t or nil
end
local function Regions(o)
  if type(o) ~= "table" or not o.GetRegions then return {} end
  local r = { pcall(o.GetRegions, o) }
  if not r[1] then return {} end
  table.remove(r, 1)
  return r
end
local function Children(o)
  if type(o) ~= "table" or not o.GetChildren then return {} end
  local r = { pcall(o.GetChildren, o) }
  if not r[1] then return {} end
  table.remove(r, 1)
  return r
end
local function TexInfo(t)
  local d = {}
  local okA, at = pcall(function() return t.GetAtlas and t:GetAtlas() end)
  if okA and type(at) == "string" and at ~= "" then d.atlas = at end
  if t.GetTexture then
    local ok, p = pcall(t.GetTexture, t)
    if ok and p ~= nil and not (ns.IsSecret and ns.IsSecret(p)) then d.tex = p end
  end
  if t.GetTexCoord then
    local ok, a, b, c, e, f, g, h, i = pcall(t.GetTexCoord, t)
    if ok and N(a) then d.coords = { a, b, c, e, f, g, h, i } end
  end
  if t.GetVertexColor then
    local ok, r, g, b, a = pcall(t.GetVertexColor, t)
    if ok and N(r) then d.color = { N(r), N(g) or 1, N(b) or 1, N(a) or 1 } end
  end
  if t.GetBlendMode then
    local ok, bm = pcall(t.GetBlendMode, t)
    if ok and type(bm) == "string" then d.blend = bm end
  end
  if t.GetDrawLayer then
    local ok, l, s = pcall(t.GetDrawLayer, t)
    if ok then d.layer, d.sub = l, s end
  end
  if not (d.atlas or d.tex) then return nil end
  return d
end
local function PaintTex(t, d)
  if not t or not d then return false end
  local ok = false
  if d.atlas and t.SetAtlas then ok = pcall(t.SetAtlas, t, d.atlas) end
  if not ok and d.tex then ok = pcall(t.SetTexture, t, d.tex) end
  if not ok then return false end
  if d.coords and not d.atlas and t.SetTexCoord then
    if #d.coords == 8 then pcall(t.SetTexCoord, t, unpack(d.coords)) end
  end
  if d.color and t.SetVertexColor then pcall(t.SetVertexColor, t, unpack(d.color)) end
  if d.blend and t.SetBlendMode then pcall(t.SetBlendMode, t, d.blend) end
  return true
end
V.TexInfo, V.PaintTex = TexInfo, PaintTex

-- (1) Zone de liste : l'encadré couvre la liste native jusqu'au filet bas. ---
-- Filets clairs du haut et du bas de la liste : relevés (positions écran
-- exactes) sur les conteneurs natifs AVANT qu'ils soient cachés, puis
-- redessinés à l'identique sur notre encadré (pur décor, sans souris).
function V.CaptureListDecor()
  local e = UI.embed
  if not e then return UI._listDecor end
  local ew = select(1, SizeOf(e)) or UI.leftPaneW or 300
  local f = UI.skillFrame
  local rowsSet = {}
  local okR, rows = pcall(UI.NativeListRows, UI)
  for _, r in ipairs(okR and rows or {}) do rowsSet[r] = true end
  local found, seen = {}, {}
  local function consider(t)
    if seen[t] or ObjType(t) ~= "Texture" then return end
    seen[t] = true
    local okS, sh = pcall(t.IsShown, t)
    if okS and not sh then return end
    local l, r, tp, b = RectOf(t)
    if not (l and r and tp and b) then return end
    local w, h = r - l, tp - b
    if h <= 0 or h > 8 or w < ew * 0.5 then return end
    local d = TexInfo(t)
    if not d or d.layer == "HIGHLIGHT" then return end
    local p = string.lower(tostring(d.tex or d.atlas or ""))
    if string.find(p, "scrollbar", 1, true) or string.find(p, "highlight", 1, true) then return end
    d.l, d.r, d.t, d.b = l, r, tp, b
    found[#found + 1] = d
  end
  local function visit(o, depth)
    if type(o) ~= "table" or depth > 2 or seen[o] or rowsSet[o] or H.IsOwnFrame(o) or o._osrsOwn then return end
    seen[o] = true
    for _, rg in ipairs(Regions(o)) do consider(rg) end
    for _, k in ipairs(Children(o)) do
      -- seulement les cadres de pur décor (ni souris ni texte)
      if not rowsSet[k] and not V.MouseInTree(k, 0) and not H.HasContent(k, 0) then visit(k, depth + 1) end
    end
  end
  visit(UI.nativeLeft, 0)
  if f then visit(f.ScrollBox, 0) end
  visit(_G.SkillListScrollFrame, 0)
  if #found > 0 then
    table.sort(found, function(a, b) return a.t > b.t end)
    UI._listDecor = found
    UI.listDecorSource = #found .. " filet(s) natif(s) relevé(s)"
  end
  return UI._listDecor
end

function V.ApplyListDecor()
  local e = UI.embed
  local list = UI._listDecor
  if not e or not list then return 0 end
  local el, _, et = RectOf(e)
  if not el then return 0 end
  if not e.decor then
    e.decor = CreateFrame("Frame", nil, e)
    e.decor._osrsOwn = true
    e.decor:SetAllPoints(e)
    e.decor:EnableMouse(false)
    e.decor.parts = {}
  end
  for i, d in ipairs(list) do
    local t = e.decor.parts[i]
    if not t then t = e.decor:CreateTexture(nil, "ARTWORK") e.decor.parts[i] = t end
    if PaintTex(t, d) then
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", e, "TOPLEFT", d.l - el, d.t - et)
      t:SetSize(d.r - d.l, d.t - d.b)
      t:Show()
      t._native = d
    end
  end
  for i = #list + 1, #e.decor.parts do e.decor.parts[i]:Hide() end
  e.decor:Show()
  return #list
end

-- Bas de la liste native (unités écran) : juste au-dessus du filet bas ; repli :
-- bas de la barre de défilement native, puis bas du volet natif.
function V.ListBottom()
  local f = UI.skillFrame
  local _, _, _, fb = RectOf(f)
  local cands = {}
  local list = UI._listDecor
  if list and #list >= 2 then cands[#cands + 1] = { y = list[#list].t, src = "filet bas natif" } end
  if f and f.ScrollBar then
    local _, _, _, b = RectOf(f.ScrollBar)
    if b then cands[#cands + 1] = { y = b, src = "barre de défilement native" } end
  end
  local _, _, _, lb = RectOf(UI.nativeLeft)
  if lb then cands[#cands + 1] = { y = lb, src = "volet natif" } end
  for _, c in ipairs(cands) do
    if not fb or c.y > fb then return c.y, c.src end
  end
end

function UI:LayoutForPane()
  local f, embed = self.skillFrame, self.embed
  if not f or not embed or not self:IsOsrsView() then return end
  local w, h = self:GetLeftPaneSize()
  local left = self.nativeLeft
  embed:ClearAllPoints()
  if left and not H.IsOwnFrame(left) then
    embed:SetPoint("TOPLEFT", left, "TOPLEFT", 0, 0)
  else
    embed:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -56)
  end
  embed:SetSize(w, h)
  SafeStep("filets de liste (relevé)", V.CaptureListDecor)
  local bottom, src = V.ListBottom()
  local _, _, et = RectOf(embed)
  if bottom and et and et - bottom > h + 0.5 and et - bottom < h * 2 then
    embed:SetHeight(et - bottom)
    self.listBottomSource = src
  else
    self.listBottomSource = "volet natif"
  end
  SafeStep("filets de liste", V.ApplyListDecor)
  if embed._snap then self:LayoutGrid(embed, embed._snap) end
  self:LayoutFooter(embed)
  self:PlaceViewToggle()
end

-- La colonne de défilement native reste réservée (notre barre s'y place).
local baseListInsets = UI.ListInsets
function UI:ListInsets()
  local ins = baseListInsets(self)
  if ins.source == "repli" then
    local f, e = self.skillFrame, self.embed
    local el, er = RectOf(e)
    local sl = f and f.ScrollBar and RectOf(f.ScrollBar)
    if el and sl and sl > el and sl < er then
      local v = math.floor(er - sl + 2.5)
      if v > ins.right and v <= 60 then ins.right = v ins.source = "colonne de défilement native" end
    end
  end
  self.listInsets = ins
  return ins
end

-- (2) Défilement : barre native cachée ; la nôtre (aspect natif) n'apparaît
-- que si le contenu déborde. Molette active seulement dans ce cas.
local SB_TEX = "Interface\\Buttons\\UI-ScrollBar-"
local function ArrowButton(parent, dir)
  local b = CreateFrame("Button", nil, parent)
  b._osrsOwn = true
  b:SetSize(18, 16)
  local base = SB_TEX .. (dir < 0 and "ScrollUpButton-" or "ScrollDownButton-")
  local function st(setter, getter, suffix, blend)
    if b[setter] then pcall(b[setter], b, base .. suffix) end
    local t = b[getter] and b[getter](b)
    if t then
      if t.SetTexCoord then pcall(t.SetTexCoord, t, 0.20, 0.80, 0.25, 0.75) end
      if blend and t.SetBlendMode then pcall(t.SetBlendMode, t, blend) end
    end
  end
  st("SetNormalTexture", "GetNormalTexture", "Up")
  st("SetPushedTexture", "GetPushedTexture", "Down")
  st("SetDisabledTexture", "GetDisabledTexture", "Disabled")
  st("SetHighlightTexture", "GetHighlightTexture", "Highlight", "ADD")
  b:SetScript("OnClick", function() UI:ScrollGrid(dir) end)
  if b.RegisterForClicks then pcall(b.RegisterForClicks, b, "LeftButtonUp") end
  b:EnableMouse(true)
  return b
end

function UI:EnsureGridScrollBar(wrap)
  if wrap.sb then return wrap.sb end
  local okS, sb = pcall(CreateFrame, "Slider", nil, wrap)
  if not (okS and sb) then sb = CreateFrame("Frame", nil, wrap) end
  sb._osrsOwn = true
  if sb.SetOrientation then pcall(sb.SetOrientation, sb, "VERTICAL") end
  sb:SetWidth(16)
  sb.track = sb:CreateTexture(nil, "BACKGROUND")
  sb.track:SetAllPoints(sb)
  pcall(sb.track.SetTexture, sb.track, WHITE)
  sb.track:SetVertexColor(0, 0, 0, 0.35)
  local thumb = sb:CreateTexture(nil, "OVERLAY")
  pcall(thumb.SetTexture, thumb, SB_TEX .. "Knob")
  if thumb.SetTexCoord then pcall(thumb.SetTexCoord, thumb, 0.20, 0.80, 0.125, 0.875) end
  thumb:SetSize(18, 24)
  if sb.SetThumbTexture then pcall(sb.SetThumbTexture, sb, thumb) end
  sb.thumb = thumb
  sb.up = ArrowButton(sb, -1)
  sb.down = ArrowButton(sb, 1)
  sb.up:SetPoint("BOTTOM", sb, "TOP", 0, 0)
  sb.down:SetPoint("TOP", sb, "BOTTOM", 0, 0)
  if sb.SetScript then
    pcall(sb.SetScript, sb, "OnValueChanged", function(_, v)
      if sb._setting then return end
      UI:SetGridScroll(N(v) or 0)
    end)
  end
  if sb.EnableMouse then sb:EnableMouse(true) end
  sb:Hide()
  wrap.sb = sb
  if wrap.SetScript then
    pcall(wrap.SetScript, wrap, "OnMouseWheel", function(_, delta)
      if (wrap._maxScroll or 0) > 0 then UI:ScrollGrid((N(delta) or 0) > 0 and -1 or 1) end
    end)
  end
  return sb
end

function UI:SetGridScroll(v)
  local wrap = self.embed
  if not wrap or not wrap._snap then return end
  local maxS = wrap._maxScroll or 0
  v = math.max(0, math.min(N(v) or 0, maxS))
  if math.abs(v - (wrap._scroll or 0)) < 0.01 then return end
  wrap._scroll = v
  self:LayoutGrid(wrap, wrap._snap)
end
function UI:ScrollGrid(dir)
  local wrap = self.embed
  if not wrap or not wrap._layout then return end
  self:SetGridScroll((wrap._scroll or 0) + dir * (wrap._layout.step or 40))
end

function UI:UpdateGridScrollBar(wrap)
  local L = wrap and wrap._layout
  if not L then return end
  local sb = self:EnsureGridScrollBar(wrap)
  if not L.overflow then
    sb:Hide()
    if wrap.EnableMouseWheel then pcall(wrap.EnableMouseWheel, wrap, false) end
    self.gridScroll = "contenu tient : pas de barre"
    return
  end
  local el, er = RectOf(wrap)
  local f = self.skillFrame
  local x
  local nsl = f and f.ScrollBar and RectOf(f.ScrollBar)
  if el and nsl and nsl > el and nsl < er then x = nsl - el
  elseif el then x = (er - el) - (self.listInsets and self.listInsets.right or 20) + 6 end
  sb:ClearAllPoints()
  local top = (self.listInsets and self.listInsets.top or 8) + 16
  sb:SetPoint("TOPLEFT", wrap, "TOPLEFT", x or 0, -top)
  sb:SetHeight(math.max(20, (L.availH or 100) - 32))
  sb._setting = true
  if sb.SetMinMaxValues then pcall(sb.SetMinMaxValues, sb, 0, wrap._maxScroll or 0) end
  if sb.SetValueStep then pcall(sb.SetValueStep, sb, L.step or 1) end
  if sb.SetValue then pcall(sb.SetValue, sb, wrap._scroll or 0) end
  sb._setting = false
  local at0, atEnd = (wrap._scroll or 0) <= 0.01, (wrap._scroll or 0) >= (wrap._maxScroll or 0) - 0.01
  if sb.up.SetEnabled then pcall(sb.up.SetEnabled, sb.up, not at0) end
  if sb.down.SetEnabled then pcall(sb.down.SetEnabled, sb.down, not atEnd) end
  local base = self.embedLevel or 0
  pcall(sb.SetFrameLevel, sb, base + 3)
  pcall(sb.up.SetFrameLevel, sb.up, base + 4)
  pcall(sb.down.SetFrameLevel, sb.down, base + 4)
  sb:Show()
  if wrap.EnableMouseWheel then pcall(wrap.EnableMouseWheel, wrap, true) end
  self.gridScroll = string.format("débordement %.0f : barre affichée", wrap._maxScroll or 0)
end

-- La barre de défilement native suit la liste (cachée en vue OSRS, rendue en
-- vue classique) : elle était visible mais inerte.
local baseNativeListObjects = V.NativeListObjects
function V.NativeListObjects()
  local out = baseNativeListObjects()
  local f = UI.skillFrame
  local sb = f and f.ScrollBar
  if type(sb) == "table" and sb.Hide and not H.IsOwnFrame(sb) then
    local dup = false
    for _, o in ipairs(out) do if o == sb then dup = true break end end
    if not dup then out[#out + 1] = sb end
  end
  return out
end

-- (A) Vue classique : on ne touche au natif QUE lors du passage OSRS → classique.
-- Ensuite (rafraîchissements, minuteries, événements), plus aucun Show natif :
-- l'état replié / déplié des en-têtes natifs reste celui du joueur.
function UI:RestoreNativeAll()
  if ns.InCombat and ns.InCombat() then
    ns.AfterCombat("vue-classique", function() if not UI:IsOsrsView() then UI:RestoreNativeAll() end end)
    self.classicRestorePending = true
    return false
  end
  local pending = self.classicRestorePending
  self.classicRestorePending = nil
  local any = pending or self.nativeListHidden or next(UI._VEIL) ~= nil or (UI._DVEIL and next(UI._DVEIL) ~= nil)
  if not any then
    self.classicRestored = 0
    self.classicRestoreSkipped = (self.classicRestoreSkipped or 0) + 1
    return true
  end
  self:SetNativeListShown(true)
  SafeStep("détail natif", self.SetNativeDetailShown, self, true)
  SafeStep("ornements", self.RestoreDetailEdge, self)
  local n = 0
  for obj in pairs(UI._VEIL) do NativeVeil(obj, false) n = n + 1 end
  local DV = ns.DetailVeil
  if DV and UI._DVEIL then for obj in pairs(UI._DVEIL) do DV(obj, false) n = n + 1 end end
  self.classicRestored = n
  return true
end

-- (URGENT) UN seul panneau de détail : arme / Défense que le natif affiche →
-- natif seul ; sinon notre panneau seul, contenu natif à opacité 0.
function UI:TryNativeAsIs(d, f)
  local NL = ns.NativeLook
  if not NL or ns.InCombat() then return false end
  local key = self:SelectionKey(d)
  -- survol (remplissage en cache) : résultat mémorisé tant que le natif n'a
  -- pas changé (crochets de mise à jour native) ; clic : toujours relu.
  self._nsMemo = self._nsMemo or {}
  local m = self._nsMemo[key]
  local ver = self._nativeDetailVer or 0
  local shows
  if self._cachedDetailFill then
    shows = (m and m.ver == ver and m.shows) or (self._nativeAsIsKey == key)
  else
    shows = NL.NativeShows(d.skillName or d.name) and true or false
    self._nsMemo[key] = { ver = ver, shows = shows }
  end
  if shows then
    self._nativeAsIsKey = key
    self:SetNativeDetailShown(true)
    if f then f:Hide() end
    self.detailMode = "natif tel quel"
    return true
  end
  self._nativeAsIsKey = nil
  self.detailMode = "notre panneau (style natif)"
  return false
end

function UI:EnforceSinglePane(reason)
  if not self:IsOsrsView() or not self:IsRightPaneVisible() then return end
  local f = self.ownDetail
  if self._nativeAsIsKey then
    if f and f:IsShown() then f:Hide() end
    self.singlePane = "natif seul"
  elseif f and f:IsShown() then
    if reason == "natif" then self._nativeRescan = true end
    self:SetNativeDetailShown(false)
    self.singlePane = "notre panneau seul"
  end
  self.singlePaneReason = reason
end

local baseFill = UI.FillOwnDetail
function UI:FillOwnDetail(d, live)
  local r = { baseFill(self, d, live) }
  SafeStep("un seul panneau", self.EnforceSinglePane, self, "remplissage")
  return unpack(r)
end
local baseBreakdown = UI.ShowDetailBreakdown
function UI:ShowDetailBreakdown(snap)
  self._nativeAsIsKey = nil
  local r = { baseBreakdown(self, snap) }
  SafeStep("un seul panneau", self.EnforceSinglePane, self, "niveau total")
  return unpack(r)
end
local baseRecheck = UI.RecheckNativeAsIs
function UI:RecheckNativeAsIs()
  self._nativeDetailVer = (self._nativeDetailVer or 0) + 1
  baseRecheck(self)
  SafeStep("un seul panneau", self.EnforceSinglePane, self, "natif")
end
-- Mise à jour native (post-crochets) hors mode « tel quel » : contenu natif
-- (nouveaux textes compris) re-voilé.
local baseHookUpd = UI.HookNativeUpdatesForHide
function UI:HookNativeUpdatesForHide()
  baseHookUpd(self)
  if type(hooksecurefunc) ~= "function" then return end
  self._singlePaneHooked = self._singlePaneHooked or {}
  for name in pairs(self._osrsHookedUpdateNames or {}) do
    if not self._singlePaneHooked[name] and type(_G[name]) == "function" then
      if pcall(hooksecurefunc, name, function()
        UI._nativeDetailVer = (UI._nativeDetailVer or 0) + 1
        if UI:IsOsrsView() and not UI._nativeAsIsKey then SafeStep("un seul panneau", UI.EnforceSinglePane, UI, "natif") end
      end) then self._singlePaneHooked[name] = true end
    end
  end
end

-- (3) Panneau de droite : géométrie du natif (titre AU-DESSUS du filet natif,
-- barre à la place exacte de la barre native, texte aligné comme le natif).
-- Mesures (refs/native-284.png, native-detail-300.png, même échelle que nos
-- captures) : bas du titre 13 px au-dessus du filet ; description 22 px à
-- gauche de la barre, bord droit = bord droit de la barre, 18 px sous la barre,
-- interligne 14 px. Échelle = largeur de la barre native (200 px mesurés).
V.DETAIL_PX = { titleGap = 13, descLeft = 22, descTop = 18, lineStep = 14, barW = 200, subGap = 4, subToBar = 6 }
function V.NativeDetailGeometry()
  local root = UI.GetDetailParent and UI:GetDetailParent()
  if not root then return nil end
  local rl, rr, rt, rb = RectOf(root)
  if not (rl and rr and rt and rb) or rr <= rl or rt <= rb then return nil end
  local own = UI.ownDetail
  local div, bar
  local function isOwn(o) return o == own or (own and H.IsDescendantOf(o, own)) or H.IsOwnFrame(o) or o._osrsOwn end
  local function visit(o, depth)
    if type(o) ~= "table" or depth > 4 or isOwn(o) then return end
    for _, rg in ipairs(Regions(o)) do
      if ObjType(rg) == "Texture" and not isOwn(rg) then
        local l, r, t, b = RectOf(rg)
        if l and t and (t - b) > 0 and (t - b) <= 6 and (r - l) >= (rr - rl) * 0.5 and t <= rt and t >= rt - (rt - rb) * 0.45 then
          if not div or t > div.t then div = { l = l, r = r, t = t, b = b } end
        end
      end
    end
    for _, k in ipairs(Children(o)) do
      if not bar and ObjType(k) == "StatusBar" and not isOwn(k) then bar = k end
      visit(k, depth + 1)
    end
  end
  local divs = {}
  local function visit2(o, depth)
    if type(o) ~= "table" or depth > 4 or isOwn(o) then return end
    for _, rg in ipairs(Regions(o)) do
      if ObjType(rg) == "Texture" and not isOwn(rg) then
        local l, r, t, b = RectOf(rg)
        if l and t and (t - b) > 0 and (t - b) <= 6 and (r - l) >= (rr - rl) * 0.5 and t <= rt and t >= rt - (rt - rb) * 0.45 then
          divs[#divs + 1] = { l = l, r = r, t = t, b = b }
        end
      end
    end
    for _, k in ipairs(Children(o)) do
      if not bar and ObjType(k) == "StatusBar" and not isOwn(k) then bar = k end
      visit2(k, depth + 1)
    end
  end
  visit2(root, 0)
  local nb = _G.SkillDetailStatusBar
  if type(nb) == "table" and not isOwn(nb) then bar = nb end
  if not bar then return nil end
  local l, r, t, b = RectOf(bar)
  if not l then return nil end
  -- 3.1.0 : le filet retenu est celui JUSTE AU-DESSUS de la barre native (le
  -- plus haut était parfois le bord supérieur du volet : titre hors du volet).
  div = nil
  for _, d in ipairs(divs) do
    if d.b >= t - 0.5 and (not div or d.t < div.t) then div = d end
  end
  if not div then return nil end
  -- rectangle extérieur : barre + son cadre (enfant légèrement plus grand)
  for _, k in ipairs(Children(bar)) do
    local kl, kr, kt, kb = RectOf(k)
    if kl and l - kl <= 12 and kr - r <= 12 and kt - t <= 12 and b - kb <= 12 then
      l, r, t, b = math.min(l, kl), math.max(r, kr), math.max(t, kt), math.min(b, kb)
    end
  end
  local s = (r - l) / V.DETAIL_PX.barW
  if s < 0.4 or s > 2.5 then s = 1 end
  return { div = div, bar = { l = l, r = r, t = t, b = b }, scale = s }
end

local baseAnchorBar = UI.AnchorDetailBar
function UI:AnchorDetailBar(f)
  local g = f and f.barHold and V.NativeDetailGeometry()
  local fl, fr, ft = RectOf(f)
  if not (g and fl and ft) then f._geo = nil return baseAnchorBar(self, f) end
  local P, s = V.DETAIL_PX, g.scale
  local titleBottom = g.div.t + P.titleGap * s
  -- 3.1.0 : le titre reste TOUJOURS dans notre volet (jamais au-dessus de son
  -- bord, où le cadre natif le cachait) ; sinon mise en page de base.
  local th = math.min(self:FSHeight(f.title, 14), 18)   -- une ligne
  if titleBottom + th > ft - 2 then titleBottom = ft - 2 - th end
  if titleBottom < g.div.t + 1 then f._geo = nil V._titleFallback = true return baseAnchorBar(self, f) end
  V._titleFallback = nil
  f.title:ClearAllPoints()
  f.title:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 8, titleBottom - ft)
  f.title:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -8, titleBottom - ft)
  local barT = g.bar.t
  if f.sub and f.sub:IsShown() then
    local subTop = g.div.b - P.subGap * s
    f.sub:ClearAllPoints()
    f.sub:SetPoint("TOPLEFT", f, "TOPLEFT", 8, subTop - ft)
    f.sub:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, subTop - ft)
    local sh = self:FSHeight(f.sub, 10)
    barT = math.min(barT, subTop - sh - P.subToBar * s)
  end
  local bh = g.bar.t - g.bar.b
  f.barHold:ClearAllPoints()
  f.barHold:SetPoint("TOPLEFT", f, "TOPLEFT", g.bar.l - fl, barT - ft)
  f.barHold:SetSize(g.bar.r - g.bar.l, bh)
  f._geo = { titleBottom = titleBottom, divTop = g.div.t, barL = g.bar.l, barR = g.bar.r, barT = barT, barB = barT - bh, scale = s }
end

local baseNativeLayout = UI.ApplyNativeDetailLayout
function UI:ApplyNativeDetailLayout(f)
  baseNativeLayout(self, f)
  local geo = f and f._geo
  local fl, fr, ft = RectOf(f)
  if not (geo and fl and fr and ft and f.scroll) then return end
  local P, s = V.DETAIL_PX, geo.scale
  local left = geo.barL - P.descLeft * s - fl
  local right = fr - geo.barR
  f.scroll:ClearAllPoints()
  f.scroll:SetPoint("TOPLEFT", f, "TOPLEFT", left, geo.barB - P.descTop * s - ft)
  f.scroll:SetPoint("TOPRIGHT", f, "TOPRIGHT", -right, geo.barB - P.descTop * s - ft)
  f._textLeft = left
  geo.descLeft, geo.descRight, geo.descTop = fl + left, fr - right, geo.barB - P.descTop * s
  if f.desc and f.desc.SetSpacing then
    local one = (f.desc.GetLineHeight and select(2, pcall(f.desc.GetLineHeight, f.desc))) or nil
    one = N(one)
    if one and one > 0 and one < P.lineStep * s then pcall(f.desc.SetSpacing, f.desc, P.lineStep * s - one) end
  end
end

-- (6) Bouton de bascule : bouton carré, MÊMES textures / taille / cadre / états
-- que la petite flèche native voisine (copiés à l'exécution), icône + infobulle.
V.TOGGLE_ICON = { osrs = "Interface\\Buttons\\UI-GuildButton-PublicNote-Up", classic = "Interface\\AddOns\\Dropamine\\Media\\SkillsTab" }
V.TOGGLE_FALLBACK = { normal = "Interface\\Buttons\\UI-SquareButton-Up", pushed = "Interface\\Buttons\\UI-SquareButton-Down",
  highlight = "Interface\\Buttons\\UI-Common-MouseHilight", disabled = "Interface\\Buttons\\UI-SquareButton-Disabled" }
local STATES = {
  { "GetNormalTexture", "SetNormalTexture", "SetNormalAtlas", "normal" },
  { "GetPushedTexture", "SetPushedTexture", "SetPushedAtlas", "pushed" },
  { "GetHighlightTexture", "SetHighlightTexture", "SetHighlightAtlas", "highlight" },
  { "GetDisabledTexture", "SetDisabledTexture", "SetDisabledAtlas", "disabled" },
}
function UI:SizeViewToggle()
  local b = self.viewToggle
  if not b then return end
  local arrow = self.collapseArrow
  local w, h
  if arrow then w, h = SizeOf(arrow) end
  if not w or w < 10 or w > 40 or not h or h < 10 or h > 40 then w, h = 22, 22 end
  b:SetSize(w, h)
  self.toggleSize = { w = w, h = h, from = arrow and "flèche native" or "repli carré" }
end

function UI:SkinViewToggle(btn)
  if not btn then return end
  local arrow = self.collapseArrow
  if btn._skinFrom == (arrow or false) and btn._osrsSkinned then return end
  btn._osrsSkinned, btn._skinFrom = true, arrow or false
  for _, k in ipairs({ "Left", "Middle", "Right", "LeftDisabled", "MiddleDisabled", "RightDisabled" }) do
    if type(btn[k]) == "table" and btn[k].Hide then pcall(btn[k].Hide, btn[k]) end
  end
  if btn.osrsBg then btn.osrsBg:Hide() end
  -- restes d'un ancien habillage (gabarit, filet bronze) : cachés
  local keep = {}
  for _, p in ipairs(btn._nlParts or {}) do keep[p] = true end
  if btn.icon then keep[btn.icon] = true end
  for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
    if btn[getter] then local ok, t = pcall(btn[getter], btn) if ok and t then keep[t] = true end end
  end
  for _, rg in ipairs(Regions(btn)) do
    if ObjType(rg) == "Texture" and not keep[rg] and rg.Hide then rg:Hide() end
  end
  local copied = 0
  btn._states = {}
  local stateTex = {}
  for _, st in ipairs(STATES) do
    local src
    if arrow and arrow[st[1]] then
      local ok, t = pcall(arrow[st[1]], arrow)
      if ok and t then src = TexInfo(t) stateTex[t] = true end
    end
    local d = src or { tex = V.TOGGLE_FALLBACK[st[4]], blend = (st[4] == "highlight") and "ADD" or nil }
    local okSet = false
    if d.atlas and btn[st[3]] then okSet = pcall(btn[st[3]], btn, d.atlas) end
    if not okSet and d.tex and btn[st[2]] then okSet = pcall(btn[st[2]], btn, d.tex) end
    local dst = btn[st[1]] and btn[st[1]](btn)
    if okSet and dst then
      PaintTex(dst, d)
      dst:ClearAllPoints()
      dst:SetAllPoints(btn)
      if src then copied = copied + 1 end
    end
    btn._states[st[4]] = d
  end
  -- cadre / fond : autres textures de la flèche (hors états), positions relatives
  if arrow and ns.NativeLook and ns.NativeLook.Describe then
    local al, ar, at, ab = RectOf(arrow)
    local parts = {}
    for _, rg in ipairs(Regions(arrow)) do
      if ObjType(rg) == "Texture" and not stateTex[rg] then
        local okS, sh = pcall(rg.IsShown, rg)
        if not okS or sh then
          local d = al and ns.NativeLook.Describe(rg, al, ar, at, ab)
          if d then parts[#parts + 1] = d end
        end
      end
    end
    if al and #parts > 0 then ns.NativeLook.ApplyClone(btn, { w = ar - al, h = at - ab, parts = parts, from = "flèche native" }) end
    btn._frameParts = #parts
  end
  btn._copiedStates = copied
  if btn.SetText then pcall(btn.SetText, btn, "") end
  local fs = (btn.GetFontString and btn:GetFontString()) or btn.fs
  if fs and fs.Hide then fs:Hide() end
  if btn.fs then btn.fs:Hide() end
  if not btn.icon then
    btn.icon = btn:CreateTexture(nil, "ARTWORK", nil, 2)
  end
  if not btn._tipHooked and btn.HookScript then
    btn._tipHooked = true
    pcall(btn.HookScript, btn, "OnEnter", function(b)
      if GameTooltip and b.tooltipText then
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        GameTooltip:SetText(b.tooltipText, 1, 0.82, 0)
        GameTooltip:Show()
      end
    end)
    pcall(btn.HookScript, btn, "OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  end
  self.toggleSkin = copied > 0 and ("copié de la flèche native (" .. copied .. " états)") or "repli carré natif"
end

function UI:SetViewToggleText()
  local b = self.viewToggle
  if not b then return end
  local osrs = self:IsOsrsView()
  b.tooltipText = osrs and Tr["Vue classique"] or Tr["Vue OSRS"]
  b.label = b.tooltipText
  if b.SetText then pcall(b.SetText, b, "") end
  if b.fs then b.fs:SetText("") b.fs:Hide() end
  self:SkinViewToggle(b)
  if b.icon then
    local w = select(1, SizeOf(b)) or 22
    local inset = math.floor(w * 0.22 + 0.5)
    b.icon:ClearAllPoints()
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", inset, -inset)
    b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -inset, inset)
    TrySetTex(b.icon, osrs and V.TOGGLE_ICON.osrs or V.TOGGLE_ICON.classic)
    b.icon:Show()
  end
  self:SizeViewToggle()
end

-- Écart natif entre petits boutons carrés voisins (relevé à côté de la flèche).
function V.NativeButtonGap(arrow)
  local al, _, at, ab = RectOf(arrow)
  if not al then return nil end
  local best
  for _, b in ipairs(UI:NativeSmallButtons()) do
    if b ~= arrow and b ~= UI.viewToggle then
      local _, br, bt, bb = RectOf(b)
      if br and br <= al + 0.5 and bt > ab and bb < at then
        local g = al - br
        if g >= 0 and g <= 12 and (not best or g < best) then best = g end
      end
    end
  end
  return best
end
local basePlaceToggle = UI.PlaceViewToggle
function UI:PlaceViewToggle()
  local arrow = self:FindCollapseArrow()
  local g = arrow and V.NativeButtonGap(arrow)
  UI.TOGGLE_GAP = g and math.floor(g + 0.5) or 4
  self.toggleGapSource = g and "écart natif relevé" or "repli 4"
  return basePlaceToggle(self)
end

-- La barre du détail garde la taille de la barre native (géométrie relevée).
local baseDetailBarW = UI.DetailBarWidth
function UI:DetailBarWidth(f)
  local g = f and f._geo
  if g and g.barR and g.barL then return g.barR - g.barL end
  return baseDetailBarW(self, f)
end
local baseSetDetailBar = UI.SetDetailBar
function UI:SetDetailBar(f, cur, cap)
  local r = { baseSetDetailBar(self, f, cur, cap) }
  local g = f and f._geo
  if g and f.barHold then f.barHold:SetSize(g.barR - g.barL, g.barT - g.barB) end
  return unpack(r)
end

-- La barre (cadre StatusBar enfant) reste juste au-dessus de sa tuile.
local baseLevels = UI.SetEmbedLevels
function UI:SetEmbedLevels()
  local base = baseLevels(self)
  for _, t in ipairs(self.embed and self.embed.tiles or {}) do
    local sb = t.barv and t.barv.frame
    if sb and sb.SetFrameLevel and base then pcall(sb.SetFrameLevel, sb, base + 3) end
    if t.craftBadge and base then pcall(t.craftBadge.SetFrameLevel, t.craftBadge, base + 4) end
  end
  if self.embed and self.embed.sb and base then pcall(self.embed.sb.SetFrameLevel, self.embed.sb, base + 3) end
  return base
end
UI.RaiseEmbed = UI.SetEmbedLevels
UI.RaiseTileHits = UI.SetEmbedLevels

-- 3.1.0 (régression 3.0.1) : nos volets (Niveau, métiers) ont TOUJOURS leur
-- propre titre et leur propre description. Le texte natif voilé (opacité) ne
-- peut plus « prêter » sa description : repli sur le texte lu en jeu, puis sur
-- une phrase propre à l'addon.
V.DESC_FR = {
  alchemy = "Métier de fabrication : transforme les herbes et autres composants en potions, élixirs et flacons.",
  blacksmithing = "Métier de fabrication : forge armes et armures de mailles et de plaques à partir de barres de métal.",
  enchanting = "Métier de fabrication : désenchante les objets en composants magiques et enchante l'équipement.",
  engineering = "Métier de fabrication : assemble gadgets, explosifs, lunettes et armes à feu.",
  herbalism = "Métier de récolte : cueillette des herbes sur les plantes repérées dans le monde.",
  leatherworking = "Métier de fabrication : transforme cuirs et peaux en armures et en sacs.",
  mining = "Métier de récolte : extraction du minerai et des pierres sur les filons, fonte en barres.",
  skinning = "Métier de récolte : dépeçage des cuirs et peaux sur les bêtes tuées.",
  tailoring = "Métier de fabrication : coud le tissu en armures de tissu et en sacs.",
  cooking = "Compétence secondaire : prépare des plats qui rendent de la vie, souvent avec un bonus temporaire.",
  fishing = "Compétence secondaire : pêche de poissons et d'objets dans les eaux du monde.",
  firstaid = "Compétence secondaire : fabrique des bandages pour se soigner sans magie.",
  defense = "Défense : augmente quand tu es attaqué ; réduit les chances d'être touché.",
}
V.DESC_KIND_FR = {
  melee = "Compétence d'arme : augmente en combattant avec ce type d'arme ; elle influe sur les chances de toucher.",
  ranged = "Compétence d'arme à distance : augmente en l'utilisant ; elle influe sur les chances de toucher.",
  feral = "Combat farouche : augmente en combattant sous forme animale ; elle influe sur les chances de toucher.",
  profession = "Métier : progresse en récoltant ou en fabricant.",
  secondary = "Compétence secondaire : progresse en la pratiquant.",
}
local baseDescFor = UI.DetailDescriptionFor
function UI:DetailDescriptionFor(d, live)
  local t = baseDescFor(self, d, live)
  if (t and t ~= "") or not d then return t or "" end
  local NL = ns.NativeLook
  -- 3.6.2 : retrouvé aussi par identifiant ; seulement dans la langue du client
  local nd = NL and NL.NativeDesc and NL.NativeDesc(d)
  if nd and not (UI.ForeignText and UI.ForeignText(nd)) then
    self.descSource = "détail natif lu"
    return nd
  end
  local fb = V.DESC_FR[d.id or ""] or V.DESC_KIND_FR[d.kind or ""]
  if fb then self.descSource = "texte de l'addon" return Tr[fb] end
  return ""
end

-- Garantie : titre de NOTRE volet visible, opaque, non vide, dans le volet.
local baseFill2 = UI.FillOwnDetail
function UI:FillOwnDetail(d, live)
  local r = { baseFill2(self, d, live) }
  local f = self.ownDetail
  if f and d and f.title and f:IsShown() then
    if (f.title:GetText() or "") == "" then f.title:SetText(self:DetailLabelFor(d) or d.name or "") end
    if f.title.SetAlpha then f.title:SetAlpha(1) end
    f.title:Show()
    if f.SetAlpha then pcall(f.SetAlpha, f, 1) end
    if f.desc then if f.desc.SetAlpha then f.desc:SetAlpha(1) end f.desc:Show() end
    if f.scroll and f.scroll.SetAlpha then pcall(f.scroll.SetAlpha, f.scroll, 1) end
  end
  return unpack(r)
end

------------------------------------------------------------------------------
-- 3.2.0 : fenêtre unique 100 % dessinée. UNE seule barre pour TOUTES les
-- tuiles (Niveau, armes, Défense, métiers, emplacements libres) : rien n'est
-- relu ni cloné sur le natif (le relevé variait d'une ligne à l'autre et
-- donnait des barres de styles différents). Couleurs MESURÉES sur
-- refs/native-284.png : remplissage en dégradé (0,50,97) → (31,92,159) sur
-- fond (25,14,0), filets du cadre natif, texte blanc ; hauteur 24, largeur
-- fixe (183, bornée à la colonne native), jamais étirée.
------------------------------------------------------------------------------
V.BAR_STYLE = "osrs-3.2.0"
V.BAR320 = { h = M.px.barOuterH, w = M.px.barOuterW, insetX = M.px.fillInsetX,
  insetTop = M.px.fillInsetTop, insetBottom = M.px.fillInsetBottom }
V.ROW_PITCH = M.px.rowStep          -- 40 : pas de rangée FIXE (natif mesuré)

function V.BarSize()
  local w, h = V.BAR320.w, V.BAR320.h
  local colMax = math.floor((M.px.headerW - TILE_HGAP0) / 2) - V.TEXT_X - 2
  local lw = ns.N(UI.leftPaneW)
  if lw and lw >= 150 then
    local c2 = math.floor((lw - 2 * (UI.gridPad or 8) - 20 - TILE_HGAP0) / 2) - V.TEXT_X - 2
    if c2 < colMax then colMax = c2 end
  end
  if w > colMax then w = colMax end
  return math.floor(w + 0.5), h
end

function V.NewBar(owner)
  local b = { owner = owner, style = V.BAR_STYLE, source = "barre OSRS 3.2.0 (dégradé mesuré)" }
  local sb = CreateFrame("Frame", nil, owner)
  sb._osrsOwn = true
  DisableMouseTree(sb, 0)
  b.frame = sb
  b.bg = sb:CreateTexture(nil, "BACKGROUND", nil, -1)
  b.bg:SetAllPoints(sb)
  b.edges = {}
  for _, k in ipairs({ "top", "bottom", "left", "right" }) do b.edges[k] = sb:CreateTexture(nil, "BORDER", nil, 1) end
  b.inner = sb:CreateTexture(nil, "BORDER", nil, 0)
  b.fillTex = sb:CreateTexture(nil, "ARTWORK", nil, 0)
  b.shadeTop = sb:CreateTexture(nil, "ARTWORK", nil, 2)
  b.shadeBottom = sb:CreateTexture(nil, "ARTWORK", nil, 2)
  b.rested = sb:CreateTexture(nil, "ARTWORK", nil, 1)
  b.rested:Hide()
  b.goal = owner:CreateTexture(nil, "OVERLAY", nil, 1)
  b.goal:Hide()
  b.border = sb:CreateTexture(nil, "OVERLAY", nil, 0)   -- compatibilité (inutilisé)
  b.border:Hide()
  b.text = Text(sb, "GameFontHighlightSmall", "CENTER")
  b.text:SetPoint("CENTER", sb, "CENTER", 0, 0)
  if b.text.SetWordWrap then b.text:SetWordWrap(false) end
  if b.text.SetDrawLayer then pcall(b.text.SetDrawLayer, b.text, "OVERLAY", 7) end
  b.parts = { sb }
  V.SkinBar(b)
  return b
end

function V.SkinBar(b)
  Solid(b.bg, M.barBg, 1)
  Solid(b.edges.top, M.barEdgeTop, 1)
  Solid(b.edges.bottom, M.barEdgeBottom, 1)
  Solid(b.edges.left, M.barEdgeSide, 1)
  Solid(b.edges.right, M.barEdgeSide, 1)
  Solid(b.inner, M.barInner, 1)
  SetFontSafe(b.text, "GameFontHighlightSmall")
  b.text:SetTextColor(1, 1, 1)
  b.color = M.barFillRight
  b._look, b.lookParts = nil, nil
  b.style = V.BAR_STYLE
end

local function PaintFill320(b)
  local pct = b.pct or 0
  local fw = (b.innerW or 0) * pct
  if fw < 1 then
    b.fillTex:Hide() b.shadeTop:Hide() b.shadeBottom:Hide()
  else
    local sb = b.frame
    b.fillTex:ClearAllPoints()
    b.fillTex:SetPoint("TOPLEFT", sb, "TOPLEFT", b.fx, -b.ft)
    b.fillTex:SetSize(fw, b.fillH)
    Gradient(b.fillTex, "HORIZONTAL", M.barFillLeft, Lerp(M.barFillLeft, M.barFillRight, pct))
    b.fillTex:Show()
    local half = b.fillH / 2
    b.shadeTop:ClearAllPoints()
    b.shadeTop:SetPoint("TOPLEFT", b.fillTex, "TOPLEFT", 0, 0)
    b.shadeTop:SetSize(fw, half)
    Gradient(b.shadeTop, "VERTICAL", { 0, 0, 0, 0 }, { 0, 0, 0, M.barShade })
    b.shadeBottom:ClearAllPoints()
    b.shadeBottom:SetPoint("BOTTOMLEFT", b.fillTex, "BOTTOMLEFT", 0, 0)
    b.shadeBottom:SetSize(fw, half)
    Gradient(b.shadeBottom, "VERTICAL", { 0, 0, 0, M.barShade }, { 0, 0, 0, 0 })
    b.shadeTop:Show() b.shadeBottom:Show()
  end
  b.fillW = fw
end

function V.PlaceBar(b, x, y, w, h)
  local o, sb = b.owner, b.frame
  b.x, b.y, b.w, b.h = x, y, w, h
  sb:ClearAllPoints()
  sb:SetPoint("TOPLEFT", o, "TOPLEFT", x, -y)
  sb:SetSize(w, h)
  local e = b.edges
  e.top:ClearAllPoints() e.top:SetPoint("TOPLEFT", sb, "TOPLEFT", 0, 0) e.top:SetSize(w, 1)
  e.bottom:ClearAllPoints() e.bottom:SetPoint("BOTTOMLEFT", sb, "BOTTOMLEFT", 0, 0) e.bottom:SetSize(w, 1)
  e.left:ClearAllPoints() e.left:SetPoint("TOPLEFT", sb, "TOPLEFT", 0, 0) e.left:SetSize(1, h)
  e.right:ClearAllPoints() e.right:SetPoint("TOPRIGHT", sb, "TOPRIGHT", 0, 0) e.right:SetSize(1, h)
  local B = V.BAR320
  b.fx, b.ft = B.insetX, B.insetTop
  b.innerW = math.max(1, w - 2 * B.insetX)
  b.fillH = math.max(1, h - B.insetTop - B.insetBottom)
  b.inner:ClearAllPoints()
  b.inner:SetPoint("TOPLEFT", sb, "TOPLEFT", b.fx - 1, -(b.ft - 1))
  b.inner:SetSize(b.innerW + 2, b.fillH + 2)
  PaintFill320(b)
end

function V.SetBar(b, cur, max, label, rested)
  cur, max = ns.N(cur) or 0, ns.N(max) or 0
  b.pct = (max > 0) and math.max(0, math.min(1, cur / max)) or 0
  PaintFill320(b)
  local fw = b.fillW or 0
  if rested and rested > 0 and max > 0 and b.innerW then
    local x1 = b.innerW * math.min(1, (cur + rested) / max)
    local w = x1 - fw
    if w >= 1 and ns.N(b.h) then
      local c = UI.RESTED_COLOR or { 0.0, 0.39, 0.88, 0.45 }
      Solid(b.rested, c, c[4])
      b.rested:ClearAllPoints()
      b.rested:SetPoint("TOPLEFT", b.frame, "TOPLEFT", b.fx + fw, -b.ft)
      b.rested:SetSize(w, b.fillH)
      b.rested:Show()
      b.restedW = w
    else b.rested:Hide() b.restedW = 0 end
  else
    b.rested:Hide()
    b.restedW = nil
  end
  b.text:SetText(label or ((max > 0) and (tostring(cur) .. " / " .. tostring(max)) or tostring(cur)))
  b.text:SetTextColor(1, 1, 1)
end

-- Pas de rangée FIXE de 40 (natif) ; tuile = rangée entière (clic plein cadre).
function V.MinPitch() return V.ROW_PITCH end
function UI:FitGrid(wrap, n)
  local w = (wrap and wrap._innerW) or self:GetGridInnerWidth(wrap)
  local cols = 2
  local tw = math.floor((w - (cols - 1) * TILE_HGAP) / cols)
  if tw < 60 then tw = 60 end
  local groups = wrap and wrap._snap and self:GroupTiles(wrap._snap.tiles) or nil
  local rowsAll = 0
  if groups and #groups > 0 then
    for gi = 1, #groups do rowsAll = rowsAll + math.ceil(#groups[gi].tiles / cols) end
  else
    rowsAll = math.ceil((n or 1) / cols)
  end
  local step = V.ROW_PITCH
  return cols, tw, step, step, math.max(1, rowsAll)
end
