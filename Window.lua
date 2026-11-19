-- Dropamine 3.2.0 — fenêtre UNIQUE, autonome, 100 % dessinée.
--
-- Règle : l'onglet Comp. natif (SkillsFrame / SkillFrame et ses lignes) n'est
-- plus JAMAIS touché : ni Hide, ni SetPoint, ni reparentage, ni relevé, ni
-- crochet. Toute la vue OSRS vit dans DropamineWindow (déplaçable,
-- bordure de dialogue native, bouton de fermeture, Échap, position mémorisée).
-- Ouverture : bouton de minicarte, /drop, clic sur un drop (3.4.2 : plus de
-- bouton dans le micro menu).
-- Les fonctions « dans l'onglet » des versions 2.x / 3.0 / 3.1 (bascule de vue,
-- voiles du natif, relevés, correctif d'en-tête de la vue classique) sont
-- remplacées ici par des versions neutres : elles ne s'exécutent plus.
local ADDON, ns = ...
local Tr = ns.L   -- 3.5.19 : textes traduits (Locales/)
local UI = ns.UI
local H = UI._H
local V = ns.View
local NL = ns.NativeLook
local SafeStep, SizeOf, Text = H.SafeStep, H.SizeOf, H.Text

local W = {}
ns.Window = W
UI.Window = W

W.NAME = "DropamineWindow"
W.SIZE = { w = 640, h = 470 }
W.LIST_W = 262
W.TOP, W.PAD = 44, 14

local function N(v) return ns.N(v) end
local function ObjType(o)
  if type(o) ~= "table" or not o.GetObjectType then return nil end
  local ok, t = pcall(o.GetObjectType, o)
  return ok and t or nil
end
local function RectOf(o)
  if type(o) ~= "table" or not o.GetLeft then return nil end
  local okL, l = pcall(o.GetLeft, o)
  local okR, r = pcall(o.GetRight, o)
  local okT, t = pcall(o.GetTop, o)
  local okB, b = pcall(o.GetBottom, o)
  l, r, t, b = okL and N(l), okR and N(r), okT and N(t), okB and N(b)
  if l and r and t and b then return l, r, t, b end
end

------------------------------------------------------------------------------
-- La fenêtre
------------------------------------------------------------------------------
local function SavePos(f)
  if not (ns.db and ns.db.ui) then return end
  local ok, point, _, rel, x, y = pcall(f.GetPoint, f, 1)
  if ok and point then ns.db.ui.winPos = { point = point, relativePoint = rel or point, x = N(x) or 0, y = N(y) or 0 } end
end
function W.PlaceDefault(f)
  f:ClearAllPoints()
  local p = ns.db and ns.db.ui and ns.db.ui.winPos
  if p and p.x and p.y then
    if pcall(f.SetPoint, f, p.point or "CENTER", UIParent, p.relativePoint or "CENTER", p.x, p.y) then
      W.posSource = "position mémorisée"
      return
    end
    f:ClearAllPoints()
  end
  -- 3.5.6 : JAMAIS d'ancre sur CharacterFrame. La fiche du client Forever n'a
  -- aucune position tant qu'elle n'a pas été ouverte (UIPanel) et FlareUI /
  -- AtlasLoot peuvent la déplacer ou la cacher : ancré dessus, le panneau était
  -- « affiché » (IsShown) mais sans rectangle, donc invisible. Désormais : à
  -- côté de la fiche seulement si elle est visible ET placée, en coordonnées
  -- fixes d'UIParent (aucun lien vivant) ; sinon au centre de l'écran.
  local cf = _G.CharacterFrame
  local okV, vis = false, false
  if type(cf) == "table" and cf.IsVisible then okV, vis = pcall(cf.IsVisible, cf) end
  local l, r, t, b = nil, nil, nil, nil
  if okV and vis then l, r, t, b = RectOf(cf) end
  local up = UIParent
  local okW, uw = pcall(up.GetWidth, up)
  local okE1, ces = false, nil
  local okE2, fes = false, nil
  if r then
    okE1, ces = pcall(cf.GetEffectiveScale, cf)
    okE2, fes = pcall(f.GetEffectiveScale, f)
  end
  local k = (okE1 and okE2 and N(ces) and N(fes) and fes > 0) and (ces / fes) or nil
  local x, y = r and k and (r * k + 56), t and k and (t * k)
  local fw = W.SIZE.w
  local upw = okW and N(uw) or nil
  if x and y and upw and okE2 and N(fes) then
    local okUE, ues = pcall(up.GetEffectiveScale, up)
    local kw = (okUE and N(ues) and fes > 0) and (ues / fes) or 1
    if x + fw <= upw * kw - 8 and y > 100 then
      f:SetPoint("TOPLEFT", up, "BOTTOMLEFT", x, y)
      W.posSource = "à côté de la fiche (coordonnées écran)"
      return
    end
  end
  f:SetPoint("CENTER", up, "CENTER", 0, 40)
  W.posSource = "centre"
end

-- Couleurs mesurées sur la fiche native (refs/native-284.png)
W.COLORS = {
  panel   = { 34 / 255, 23 / 255, 15 / 255 },   -- volet de droite
  list    = { 19 / 255, 11 / 255, 2 / 255 },    -- volet de gauche (liste)
  title   = { 49 / 255, 28 / 255, 13 / 255 },   -- barre de titre ≈ en-tête (47,28,13)
  border  = { 135 / 255, 100 / 255, 57 / 255 }, -- bordure bronze/or
  divider = { 24 / 255, 17 / 255, 9 / 255 },    -- séparation des volets
  edge    = { 78 / 255, 67 / 255, 57 / 255 },   -- filet d'en-tête
}
local WHITE = "Interface\\Buttons\\WHITE8X8"
local function Tint(t, c, a)
  pcall(t.SetTexture, t, WHITE)
  if t.SetVertexColor then pcall(t.SetVertexColor, t, c[1], c[2], c[3], a or 1) end
  t._tint = { c[1], c[2], c[3], a or 1 }
  return t
end
W.Tint = Tint

function W.Chrome(f)
  local C = W.COLORS
  if f.SetBackdrop then
    pcall(f.SetBackdrop, f, { bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = false, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    if f.SetBackdropColor then pcall(f.SetBackdropColor, f, C.panel[1], C.panel[2], C.panel[3], 1) end
    if f.SetBackdropBorderColor then pcall(f.SetBackdropBorderColor, f, C.border[1], C.border[2], C.border[3], 1) end
    W.backdrop = { bg = C.panel, border = C.border }
  end
  W.bg = Tint(f:CreateTexture(nil, "BACKGROUND", nil, -8), C.panel)
  W.bg:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
  W.bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)
  -- 3.3.1 : aucune texture recopiée d'un autre cadre (même de la fiche) :
  -- couleurs natives mesurées uniquement.
  W.bgSource = "couleurs natives mesurées"
  -- barre de titre (comme « Comp. ») et son filet bronze
  local tb = CreateFrame("Frame", nil, f)
  tb:SetPoint("TOPLEFT", f, "TOPLEFT", 5, -5)
  tb:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
  tb:SetHeight(24)
  if tb.EnableMouse then tb:EnableMouse(false) end
  tb.fill = Tint(tb:CreateTexture(nil, "BACKGROUND", nil, 1), C.title)
  tb.fill:SetAllPoints(tb)
  tb.line = Tint(tb:CreateTexture(nil, "BORDER"), C.border, 0.9)
  tb.line:SetPoint("BOTTOMLEFT", tb, "BOTTOMLEFT", 0, 0)
  tb.line:SetPoint("BOTTOMRIGHT", tb, "BOTTOMRIGHT", 0, 0)
  tb.line:SetHeight(1)
  W.titleBar = tb
end

function W.Build()
  if W.frame then return W.frame end
  -- 3.3.0 : plus de gabarit (le fond « pierre grise » de PortraitFrameTemplate
  -- ne ressemble pas à Forever) : notre cadre, aux couleurs MESURÉES sur la
  -- fiche native (refs/native-284.png), bordure native teintée bronze.
  local okF, f = pcall(CreateFrame, "Frame", W.NAME, UIParent, "BackdropTemplate")
  if not (okF and f) then f = CreateFrame("Frame", W.NAME, UIParent) end
  local used = "cadre 3.3.0 (couleurs natives mesurées)"
  f._osrsOwn = true
  W.template = used
  f:SetSize(W.SIZE.w, W.SIZE.h)
  f:SetFrameStrata("HIGH")
  if f.SetToplevel then pcall(f.SetToplevel, f, true) end
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(fr) fr:StartMoving() end)
  f:SetScript("OnDragStop", function(fr) fr:StopMovingOrSizing() SavePos(fr) end)
  if f.SetClampedToScreen then f:SetClampedToScreen(true) end
  W.Chrome(f)
  -- fermeture : bouton natif du gabarit, sinon UIPanelCloseButton ; Échap
  local close = rawget(f, "CloseButton")
  if type(close) ~= "table" then
    local ok, c = pcall(CreateFrame, "Button", W.NAME .. "Close", f, "UIPanelCloseButton")
    close = ok and c or nil
    if close then close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2) end
  end
  if close then close:SetScript("OnClick", function() f:Hide() end) end
  W.close = close
  if type(UISpecialFrames) == "table" then
    local seen = false
    for _, n in ipairs(UISpecialFrames) do if n == W.NAME then seen = true end end
    if not seen then UISpecialFrames[#UISpecialFrames + 1] = W.NAME end
  end
  -- titre et portrait
  local tt = Text(f, "GameFontNormal", "CENTER")
  tt:SetPoint("CENTER", W.titleBar, "CENTER", 0, 0)
  tt:SetText(Tr["Niveau total"])
  W.title = tt
  W.portrait = nil
  W.subtitle = Text(f, "GameFontHighlightSmall", "LEFT")
  W.subtitle:SetPoint("LEFT", W.titleBar, "LEFT", 10, 0)
  W.subtitle:SetTextColor(0.85, 0.80, 0.65)
  -- zones : liste (gauche) et détail (droite)
  local list = CreateFrame("Frame", W.NAME .. "List", f)
  list._osrsOwn = true
  -- tailles FIXES (la fenêtre ne se redimensionne pas) : grille déterministe
  list:SetPoint("TOPLEFT", f, "TOPLEFT", W.PAD, -W.TOP)
  list:SetSize(W.LIST_W, W.SIZE.h - W.TOP - W.PAD)
  if list.EnableMouse then list:EnableMouse(false) end
  W.listBg = Tint(f:CreateTexture(nil, "BACKGROUND", nil, 2), W.COLORS.list)
  W.listBg:SetPoint("TOPLEFT", list, "TOPLEFT", -4, 4)
  W.listBg:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", 4, -4)
  local detail = CreateFrame("Frame", W.NAME .. "Detail", f)
  detail._osrsOwn = true
  detail:SetPoint("TOPLEFT", list, "TOPRIGHT", 12, 0)
  detail:SetSize(W.SIZE.w - W.LIST_W - 2 * W.PAD - 12, W.SIZE.h - W.TOP - W.PAD)
  if detail.EnableMouse then detail:EnableMouse(false) end
  W.list, W.detail = list, detail
  -- filets fins (couleurs du filet natif mesuré) : haut / bas de la liste,
  -- séparation verticale, filet du détail sous le titre
  local M = V.MEASURED
  local function line(parent, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    return Tint(t, W.COLORS.border, 0.75)
  end
  W.divTop = line(f) W.divTop:SetPoint("TOPLEFT", list, "TOPLEFT", 0, 1) W.divTop:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, 1) W.divTop:SetHeight(1)
  W.divBottom = line(f) W.divBottom:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", 0, -1) W.divBottom:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", 0, -1) W.divBottom:SetHeight(1)
  W.divV = line(f) W.divV:SetPoint("TOPLEFT", list, "TOPRIGHT", 5, 4) W.divV:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", 5, -4) W.divV:SetWidth(2)
  W.divV2 = Tint(f:CreateTexture(nil, "ARTWORK"), W.COLORS.divider)
  W.divV2:SetPoint("TOPLEFT", W.divV, "TOPRIGHT", 0, 0) W.divV2:SetPoint("BOTTOMLEFT", W.divV, "BOTTOMRIGHT", 0, 0) W.divV2:SetWidth(3)
  W.detailDiv = line(detail) W.detailDiv:SetPoint("TOPLEFT", detail, "TOPLEFT", 8, -40) W.detailDiv:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -8, -40) W.detailDiv:SetHeight(2)
  f:SetScript("OnShow", function()
    if W.portrait and SetPortraitTexture then pcall(SetPortraitTexture, W.portrait, "player") end
    UI:Refresh(true)
    UI:ApplyView()
  end)
  f:Hide()
  W.frame = f
  W.PlaceDefault(f)
  return f
end

------------------------------------------------------------------------------
-- Contenu : la grille dessinée 3.0.1 + notre volet de détail, DANS la fenêtre
------------------------------------------------------------------------------
function W.Layout()
  local f = W.frame
  if not f or not f:IsShown() then return end
  -- la fenêtre tient lieu de « fiche » pour tout le code de la vue
  UI.skillFrame, UI.nativeLeft, UI.nativeDetail = f, W.list, W.detail
  local lw, lh = SizeOf(W.list)
  UI.leftPaneW, UI.leftPaneH, UI.leftPaneSource = lw, lh, "fenêtre OSRS"
  if not UI.embed then
    UI.embed = UI:BuildGrid(W.list, "DropamineEmbed")
  elseif UI.embed.GetParent and UI.embed:GetParent() ~= W.list then
    UI.embed:SetParent(W.list)
  end
  local embed = UI.embed
  embed:ClearAllPoints()
  embed:SetPoint("TOPLEFT", W.list, "TOPLEFT", 0, 0)
  embed:SetSize(lw or W.LIST_W, lh or 400)
  embed:Show()
  embed:EnableMouse(true)
  if not UI.snapshot then
    local okC, snap = pcall(ns.Collect)
    if okC then UI.snapshot = snap end
  end
  if UI.snapshot then SafeStep("grille", UI.LayoutGrid, UI, embed, UI.snapshot) end
  SafeStep("niveaux", UI.SetEmbedLevels, UI)
  SafeStep("bandeau", UI.LayoutFooter, UI, embed)
  local snap = UI.snapshot
  if snap and W.subtitle then
    local name = snap.playerName or ""
    W.subtitle:SetText(name ~= "" and (name .. Tr["  ·  niveau "] .. tostring(snap.level or 0)) or "")
  end
  SafeStep("détail", function()
    UI:EnsureOwnDetail(W.detail)
    if UI:ResolveSelected() then
      UI._detailShownKey = nil
      UI:ShowDetail(UI.selected, "restore")
    elseif snap and snap.tiles and snap.tiles[1] then
      UI:SelectTile(snap.tiles[1])
    end
  end)
end

------------------------------------------------------------------------------
-- Ouverture / fermeture
------------------------------------------------------------------------------
function W.Show()
  W.Build()
  if not W.frame:IsShown() then W.frame:Show() else W.Layout() end
  return true
end
function W.Hide() if W.frame then W.frame:Hide() end end
function W.Toggle()
  W.Build()
  if W.frame:IsShown() then W.frame:Hide() else W.frame:Show() end
  return W.frame:IsShown()
end
function W.IsShown() return W.frame and W.frame:IsShown() and true or false end

-- Icône « 3 piliers » : trois colonnes verticales rouge / verte / bleue sur un
-- fond brun, dessinées avec NOS aplats (SetColorTexture) : aucune texture du
-- jeu, d'un atlas ou d'un autre addon ne peut s'y substituer.
W.PILLAR_COLORS = {
  bg   = { 30 / 255, 19 / 255, 8 / 255 },
  edge = { 8 / 255, 5 / 255, 0 },
  { 0.82, 0.12, 0.10 },   -- rouge
  { 0.16, 0.66, 0.16 },   -- vert
  { 0.16, 0.38, 0.88 },   -- bleu
}
local function Solid(t, c, a)
  local ok = t.SetColorTexture and pcall(t.SetColorTexture, t, c[1], c[2], c[3], a or 1)
  if not ok then
    pcall(t.SetTexture, t, "Interface\\Buttons\\WHITE8X8")
    if t.SetVertexColor then pcall(t.SetVertexColor, t, c[1], c[2], c[3], a or 1) end
  end
  t._pillarColor = { c[1], c[2], c[3], a or 1 }
  return t
end
function W.DrawPillars(owner, size, layer, sub)
  local P = owner._pillars
  if not P then
    P = { cols = {} }
    P.bg = owner:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
    for i = 1, 3 do
      P.cols[i] = owner:CreateTexture(nil, layer or "ARTWORK", nil, (sub or 0) + 1)
    end
    owner._pillars = P
  end
  Solid(P.bg, W.PILLAR_COLORS.bg)
  P.bg:ClearAllPoints()
  P.bg:SetPoint("CENTER", owner, "CENTER", 0, 0)
  P.bg:SetSize(size, size)
  local pad = math.max(2, math.floor(size * 0.14 + 0.5))
  local gap = math.max(1, math.floor(size * 0.07 + 0.5))
  local cw = math.floor((size - 2 * pad - 2 * gap) / 3)
  local ch = size - 2 * pad
  local x0 = -math.floor((3 * cw + 2 * gap) / 2)
  for i = 1, 3 do
    local c = P.cols[i]
    Solid(c, W.PILLAR_COLORS[i])
    c:ClearAllPoints()
    c:SetPoint("BOTTOMLEFT", P.bg, "BOTTOMLEFT", math.floor(size / 2) + x0 + (i - 1) * (cw + gap), pad)
    c:SetSize(cw, ch)
    c:Show()
  end
  P.bg:Show()
  P.size, P.colW, P.colH, P.gap = size, cw, ch, gap
  return P
end

-- 3.4.2 : plus de bouton dans le micro menu (retiré à la demande) : on ouvre
-- le panneau par le bouton de minicarte, /drop ou un clic sur un drop.

function W.TotalLine()
  local snap = UI.snapshot
  if not snap then local ok, s = pcall(ns.Collect) if ok then snap = s end end
  local total = snap and snap.total or 0
  local tmax = (snap and snap.totalMax) or ns.TOTAL_MAX or 2460
  return Tr["Niveau total : "] .. tostring(total) .. " / " .. tostring(tmax)
end
function W.ShowTotalTooltip(owner)
  if not GameTooltip then return end
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:SetText(W.TotalLine(), 1, 0.82, 0)
  GameTooltip:AddLine(Tr["Clic : ouvrir / fermer"], 1, 1, 1)
  GameTooltip:Show()
end


-- bouton de minicarte (seul bouton d'ouverture) : info-bulle « Niveau total : X / 2460 » + « Clic : ouvrir / fermer »
local baseBuildMinimap = UI.BuildMinimap
function UI:BuildMinimap()
  local r = { baseBuildMinimap(self) }
  local m = self.minimap
  if m and not m._osrsTip then
    m._osrsTip = true
    m:SetScript("OnEnter", function(fr) W.ShowTotalTooltip(fr) end)
    m:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  end
  return unpack(r)
end

------------------------------------------------------------------------------
-- Remplacements : plus rien ne touche l'onglet Comp. natif
------------------------------------------------------------------------------
local function noop() end
-- vue OSRS = la fenêtre ; « Vue classique » n'existe plus (l'onglet natif l'est)
function UI:IsOsrsView() return true end
function UI:ToggleView() W.Toggle() end
function UI:ApplyView()
  if self._inApplyView then return end
  self._inApplyView = true
  local ok, err = pcall(W.Layout)
  self._inApplyView = false
  if not ok then SafeStep("fenêtre", error, err) end
end
UI.ApplyViewInner = function() W.Layout() end
function UI:Show() W.Show() end
function UI:Hide() W.Hide() end
function UI:Toggle() W.Toggle() end
function UI:BuildStandalone() W.Build() end
-- ouverture depuis un drop / la commande : la fenêtre, jamais l'onglet natif
function UI:OpenSkillTab(after)
  if ns.InCombat and ns.InCombat() and not W.frame then
    ns.AfterCombat("ouvrir-fenetre", function() UI:OpenSkillTab(after) end)
    return true
  end
  W.Show()
  if after then SafeStep("après ouverture", after) end
  return true
end
function UI:HookSkillFrame()
  return false
end
function UI:GetDetailParent() return W.detail end
function UI:IsRightPaneVisible() return W.IsShown() end
function UI:EnsureEmbed() return self.embed end
function UI:LayoutForPane()
  if not (W.frame and self.embed) then return end
  if self.embed._snap then self:LayoutGrid(self.embed, self.embed._snap) end
  self:LayoutFooter(self.embed)
end
function UI:ListInsets()
  local ins = { left = 4, right = 20, top = 6, source = "fenêtre 3.2.0" }
  self.listInsets = ins
  return ins
end
-- voiles / relevés / crochets du natif : retirés
UI.SetNativeListShown = noop
UI.SetNativeListRowsShown = noop
UI.SetNativeDetailShown = noop
UI.SetNativeDetailShownFull = noop
UI.VeilNativeDetailContent = noop
UI.CoverDetailEdge = noop
UI.RestoreDetailEdge = noop
UI.RequestOrnamentCover = noop
UI.HookNativeUpdatesForHide = noop
UI.HookDetailVisibility = noop
UI.HookCollapseArrow = noop
UI.HookCharacterFrameForTab = noop
UI.ApplyTabIcon = noop
UI.LearnNativeChrome = noop
UI.RefreshNativeProbe = noop
UI.RecheckNativeAsIs = noop
UI.EnsureViewToggle = noop
UI.PlaceViewToggle = noop
UI.SetViewToggleText = noop
UI.ResolveToggleOverlap = noop
function UI:ProbeNativeUpdateFunctions() return {} end
function UI:TryNativeAsIs() self._nativeAsIsKey = nil return false end
function UI:EnforceSinglePane(reason) self.singlePane = "notre volet (fenêtre)" self.singlePaneReason = reason end
function UI:RestoreNativeAll() self.classicRestored = 0 return true end
function UI:HideOwnFrames() if self.embed then self.embed:Hide() end if self.ownDetail then self.ownDetail:Hide() end end
function UI:SyncCollapsedState()
  if not (self.ownDetail and W.IsShown()) then return end
  if self.selected and self.selected.kind == "total" and self.snapshot then self:ShowDetailBreakdown(self.snapshot)
  elseif self._detailData then self:FillOwnDetail(self._detailData, self._detailLive) end
end
function UI:WriteNativeDetail(d) return nil end
if V then
  V.NativeListObjects = function() return {} end
  V.CaptureListDecor = noop
  V.ApplyListDecor = noop
  V.ListBottom = function() return nil end
  -- géométrie du détail : NOTRE filet (titre au-dessus), barre dessous
  function V.NativeDetailGeometry()
    local d = W.detail
    if not (d and W.detailDiv) then return nil end
    local dl, dr, dt = RectOf(d)
    local l, r, t, b = RectOf(W.detailDiv)
    if not (dl and l) then return nil end
    local bl, br = dl + 16, dr - 16
    local bt = b - 14
    return { div = { l = l, r = r, t = t, b = b }, bar = { l = bl, r = br, t = bt, b = bt - V.BAR320.h }, scale = 1 }
  end
end
if NL then
  -- plus aucun relevé sur des cadres natifs (on n'y touche plus du tout)
  NL.ProbeList = function()
    local L = ns.db and ns.db.nativeAssets and ns.db.nativeAssets.list
    return L or nil
  end
  NL.DiscoverHeaderButton = function()
    local c = ns.db and ns.db.nativeAssets and ns.db.nativeAssets.headerButton
    return c or nil
  end
  NL.CaptureNativeDetail = function() return nil end
  NL.NativeShows = function() return false end
end
UI._noNativeScan = true
-- l'ancienne fenêtre de secours n'existe plus : c'est la fenêtre 3.2.0
UI.frame = nil

W.DebugLines = function()
  local out = {}
  out[#out + 1] = "fenêtre 3.2.0 : " .. (W.frame and (W.frame:IsShown() and "ouverte" or "fermée") or "pas encore créée")
    .. ", gabarit " .. tostring(W.template) .. ", position " .. tostring(W.posSource)
  out[#out + 1] = "  fond : " .. tostring(W.bgSource)
  if ns.Icons and ns.Icons.DebugLines then for _, l in ipairs(ns.Icons.DebugLines()) do out[#out + 1] = "  " .. l end end
  return out
end

local baseReset = UI.ResetPositions
function UI:ResetPositions()
  if baseReset then pcall(baseReset, self) end
  if ns.db and ns.db.ui then ns.db.ui.winPos = nil end
  if W.frame then W.PlaceDefault(W.frame) end
end
local basePrintDebug = ns.PrintDebug
function ns.PrintDebug(...)
  if basePrintDebug then pcall(basePrintDebug, ...) end
  for _, l in ipairs(W.DebugLines()) do ns.Print(l) end
end
