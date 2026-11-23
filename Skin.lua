-- Dropamine 3.3.15 : habillage façon FlareUI (STYLE.md) pour le panneau,
-- les toasts et la fenêtre de réglages : UNE seule recette, partout.
--   fond  : Interface\DialogFrame\UI-DialogBox-Background-Dark (texture du
--           jeu, comme FlareUI), couleur (1, 1, 1), alpha = /drop fond ;
--   bord  : Media\Dropamine-Frame.tga (3.3.17 : NOTRE dessin, tools/make_frame_border.py,
--           même rendu que le bord FlareUI qu'il remplace), art gris teinté #A67D45 (ns.BORDER_COLOR
--           de FlareUI), bord 16 px, marges 3 px — mêmes réglages que FlareUI
--           (Modules/DamageMeter.lua, SkinBackdrop). Aucun code de FlareUI.
-- Le panneau n'est jamais mis à l'échelle (taille dynamique, 3.3.12) : le bord
-- garde son épaisseur native à toutes les tailles.
local _, ns = ...
local Sk = {}
ns.Skin = Sk

local MEDIA = "Interface\\AddOns\\Dropamine\\Media\\"
Sk.BG_FILE = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark"
Sk.EDGE_FILE = MEDIA .. "Dropamine-Frame"   -- 3.3.17 : NOTRE dessin (tools/make_frame_border.py), même rendu que le bord FlareUI, art gris teinté #A67D45
Sk.EDGE_SIZE = 16
Sk.INSET = 3
Sk.BORDER = ns.STYLE.BORDER      -- #A67D45 (FlareUI ns.BORDER_COLOR)
-- Teinte du bord : l'art de Dropamine-Frame est GRIS, teinté #A67D45 comme dans
-- FlareUI (SetBackdropBorderColor). Bug 3.3.14 (bord blanc) : P.RefreshTipColors
-- remplaçait la teinte par la couleur d'infobulle par défaut (blanc) et
-- P.ApplyTipAlpha la posait. Désormais : jamais de couleurs d'infobulle sur
-- l'habillage, teinte reposée après chaque SetBackdrop / fondu / thème.
Sk.TINT = Sk.BORDER
Sk.BORDER_HOVER = { 0.98, 0.74, 0.36, 1 } -- survol (FlareUI EDGE_HOVER)
Sk.BG = { 1, 1, 1, 1 }                    -- la texture porte la couleur ; alpha = /drop fond
Sk.stats = { hosts = 0 }
Sk.enabled = true                         -- false : ancien cadre d'infobulle (repli, tests)

-- « FlareUI (New) » : le cadre du chat FlareUI = bord FlareUI-Thick (MIT : Media/LICENSE-FlareUI-Border.txt)
-- + trait à nœuds au bas ET au haut, pris dans l'image du jeu (voir Sk.UpdateArt).
Sk.EDGE_FILE_THICK = MEDIA .. "Dropamine-Frame-Thick"
-- host : seuls le panneau et la fenêtre Progression (host._skinNew) prennent le cadre New ; toasts et autres fenêtres gardent le cadre standard
function Sk.Backdrop(host)
  local thick = host and host._skinNew and ns.Theme and ns.Theme.IsNew and ns.Theme.IsNew()
  return { bgFile = Sk.BG_FILE, edgeFile = thick and Sk.EDGE_FILE_THICK or Sk.EDGE_FILE, tile = false, tileSize = 0, edgeSize = Sk.EDGE_SIZE,
    insets = { left = Sk.INSET, right = Sk.INSET, top = Sk.INSET, bottom = Sk.INSET } }
end

-- 3.3.14 : repli SANS BackdropTemplate (sinon on retombait sur le bord gris de
-- l'infobulle) : 8 textures découpées dans Media/Dropamine-Frame.tga + fond, avec les mêmes
-- méthodes SetBackdrop / SetBackdropColor / SetBackdropBorderColor.
Sk.CELLS = { left = 0, right = 1, top = 2, bottom = 3, tl = 4, tr = 5, bl = 6, br = 7 }
function Sk.TexHost(f)
  local ok, h = pcall(CreateFrame, "Frame", nil, f)
  if not (ok and h) then return nil end
  h._skinTex = true
  h.bgTex = h:CreateTexture(nil, "BACKGROUND", nil, -8)
  h.pieces = {}
  for k in pairs(Sk.CELLS) do h.pieces[k] = h:CreateTexture(nil, "BORDER") end
  function h:SetBackdrop(bd)
    if not bd then self.bgTex:Hide() for _, t in pairs(self.pieces) do t:Hide() end return end
    local e, ins = bd.edgeSize or 16, (bd.insets and bd.insets.left) or 0
    self._bd = bd
    pcall(self.bgTex.SetTexture, self.bgTex, bd.bgFile)
    self.bgTex:ClearAllPoints()
    self.bgTex:SetPoint("TOPLEFT", self, "TOPLEFT", ins, -ins)
    self.bgTex:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -ins, ins)
    self.bgTex:Show()
    for k, t in pairs(self.pieces) do
      pcall(t.SetTexture, t, bd.edgeFile)
      local c = Sk.CELLS[k]
      local l, r = c / 8, (c + 1) / 8
      if k == "top" or k == "bottom" then
        if t.SetTexCoord then pcall(t.SetTexCoord, t, l, 0, r, 0, l, 1, r, 1) end   -- cellule pivotée (format des fichiers de bord)
      elseif t.SetTexCoord then pcall(t.SetTexCoord, t, l, r, 0, 1) end
      t:ClearAllPoints()
      t:Show()
    end
    local P = self.pieces
    P.tl:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0) P.tl:SetSize(e, e)
    P.tr:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 0) P.tr:SetSize(e, e)
    P.bl:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, 0) P.bl:SetSize(e, e)
    P.br:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0) P.br:SetSize(e, e)
    P.top:SetPoint("TOPLEFT", P.tl, "TOPRIGHT", 0, 0) P.top:SetPoint("TOPRIGHT", P.tr, "TOPLEFT", 0, 0) P.top:SetHeight(e)
    P.bottom:SetPoint("BOTTOMLEFT", P.bl, "BOTTOMRIGHT", 0, 0) P.bottom:SetPoint("BOTTOMRIGHT", P.br, "BOTTOMLEFT", 0, 0) P.bottom:SetHeight(e)
    P.left:SetPoint("TOPLEFT", P.tl, "BOTTOMLEFT", 0, 0) P.left:SetPoint("BOTTOMLEFT", P.bl, "TOPLEFT", 0, 0) P.left:SetWidth(e)
    P.right:SetPoint("TOPRIGHT", P.tr, "BOTTOMRIGHT", 0, 0) P.right:SetPoint("BOTTOMRIGHT", P.br, "TOPRIGHT", 0, 0) P.right:SetWidth(e)
    self._bdFile, self._bdEdge, self._bdEdgeSize, self._bdInset = bd.bgFile, bd.edgeFile, e, ins
  end
  function h:SetBackdropColor(r, g, b, a) self.bgTex:SetVertexColor(r, g, b, a or 1) self._bdColor = { r, g, b, a or 1 } end
  function h:SetBackdropBorderColor(r, g, b, a)
    for _, t in pairs(self.pieces) do t:SetVertexColor(r, g, b, a or 1) end
    self._bdBorder = { r, g, b, a or 1 }
  end
  function h:GetBackdropBorderColor() local c = self._bdBorder or { 1, 1, 1, 1 } return c[1], c[2], c[3], c[4] end
  return h
end

-- Cadre d'habillage (enfant de f, sous son contenu, ne prend pas la souris).
function Sk.Host(f, wantNew)
  if type(f) ~= "table" or not f.CreateTexture then return nil end
  local host = f._skinHost
  if not host and (Sk.forceTextures or not _G.BackdropTemplateMixin) then
    host = Sk.TexHost(f)
    if host then
      host._osrsOwn, host._osrsFor, host._osrsSkin = true, f, true
      if host.EnableMouse then host:EnableMouse(false) end
      f._skinHost = host
      Sk.stats.hosts = Sk.stats.hosts + 1
      Sk.mode = "textures (Dropamine-Frame découpé, sans BackdropTemplate)"
    end
  end
  if not host then
    local tmpl = _G.BackdropTemplateMixin and "BackdropTemplate" or nil
    local ok, h = pcall(CreateFrame, "Frame", nil, f, tmpl)
    if not (ok and h) then return nil end
    host = h
    if not host.SetBackdrop and _G.BackdropTemplateMixin and _G.Mixin then pcall(_G.Mixin, host, _G.BackdropTemplateMixin) end
    if not host.SetBackdrop then host = Sk.TexHost(f) if not host then return nil end Sk.mode = "textures (repli)" else Sk.mode = Sk.mode or "BackdropTemplate" end
    host._osrsOwn, host._osrsFor, host._osrsSkin = true, f, true
    if host.EnableMouse then host:EnableMouse(false) end
    f._skinHost = host
    Sk.stats.hosts = Sk.stats.hosts + 1
  end
  if wantNew then host._skinNew = true end
  host:ClearAllPoints()
  host:SetAllPoints(f)
  if host.SetScale then pcall(host.SetScale, host, 1) end
  local lvl = (f.GetFrameLevel and f:GetFrameLevel()) or 1
  pcall(host.SetFrameLevel, host, math.max(0, lvl - 0))
  if Sk.Guard then Sk.Guard(host) end
  if not pcall(host.SetBackdrop, host, Sk.Backdrop(host)) then return nil end
  return host
end

-- Trait à nœuds du chat FlareUI (thème New). L'image est celle du jeu (bande de titre du suivi de quêtes,
-- C_Texture.GetAtlasInfo) : rien n'est copié. Même découpe et mêmes cotes que FlareUI (Chat.ApplyFrameStyleArt,
-- ObjectiveTracker Build.PlaceStrip, MIT) : deux bouts à leur taille + une fine tranche du milieu étirée,
-- sur la bande du bas de l'image (le trait et ses nœuds), posée sur le bord à 2,5 px du cadre.
Sk.ART = "ui-questtracker-primary-objective-header"
Sk.ART_FRAME, Sk.ART_CAP, Sk.ART_TITLE_RIGHT, Sk.ART_TITLE_LEFT, Sk.ART_KNOB_IN = 260, 0.3, 8, 1, 2
Sk.ART_BAND = { 31 / 40, 38 / 40 }
Sk.ART_INSET, Sk.ART_EDGE_Y = 8, 2.5
function Sk.ArtInfo()
  if Sk._artInfo == nil then
    local ok, found = pcall(function() return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(Sk.ART) end)
    Sk._artInfo = (ok and type(found) == "table" and found.file and (found.width or 0) > 0) and found or false
  end
  return Sk._artInfo or nil
end
local function PlaceLine(owner, info)
  local st = {}
  for _, part in ipairs({ "L", "M", "R" }) do
    local t = owner:CreateTexture(nil, "BACKGROUND", nil, -1)
    if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false) end
    if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
    st[part] = t
  end
  local l, r, t0, b0 = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
  local tall = b0 - t0
  local t1, b1 = t0 + tall * Sk.ART_BAND[1], t0 + tall * Sk.ART_BAND[2]
  local height = info.height * (Sk.ART_BAND[2] - Sk.ART_BAND[1])
  local reach = math.max(0, (info.width - Sk.ART_FRAME) / 2)
  local leftOut = reach - Sk.ART_KNOB_IN + Sk.ART_TITLE_LEFT
  local rightOut = reach + Sk.ART_TITLE_RIGHT - Sk.ART_KNOB_IN - Sk.ART_TITLE_LEFT
  local span = r - l
  local cap = math.floor(info.width * Sk.ART_CAP + 0.5)
  local capSpan = span * cap / info.width
  local mid = l + span / 2
  for _, t in pairs(st) do t:SetTexture(info.file) t:ClearAllPoints() t:SetHeight(height) end
  st.L:SetTexCoord(l, l + capSpan, t1, b1) st.L:SetWidth(cap) st.L:SetPoint("LEFT", owner, "LEFT", -leftOut, 0)
  st.R:SetTexCoord(r - capSpan, r, t1, b1) st.R:SetWidth(cap) st.R:SetPoint("RIGHT", owner, "RIGHT", rightOut, 0)
  st.M:SetTexCoord(mid - span * 0.005, mid + span * 0.005, t1, b1)
  st.M:SetPoint("LEFT", st.L, "RIGHT") st.M:SetPoint("RIGHT", st.R, "LEFT")
  owner._lineTex = st
end
function Sk.UpdateArt(host)
  if not host or not host.CreateTexture then return end
  local on = host._skinNew and ns.Theme and ns.Theme.IsNew and ns.Theme.IsNew() and Sk.ArtInfo() and true or false
  if host._artOn == on then return end
  host._artOn = on
  if on and not host._art then
    local info = Sk.ArtInfo()
    host._art = {}
    for i, side in ipairs({ "TOP", "BOTTOM" }) do
      local o = CreateFrame("Frame", nil, host)
      local sgn = (side == "TOP") and -1 or 1
      o:SetPoint(side .. "LEFT", host, side .. "LEFT", Sk.ART_INSET, sgn * Sk.ART_EDGE_Y)
      o:SetPoint(side .. "RIGHT", host, side .. "RIGHT", -Sk.ART_INSET, sgn * Sk.ART_EDGE_Y)
      o:SetHeight(1)
      if o.EnableMouse then o:EnableMouse(false) end
      PlaceLine(o, info)
      host._art[i] = o
    end
  end
  for _, o in ipairs(host._art or {}) do if on then o:Show() else o:Hide() end end
end
function Sk.RefreshArt()
  local f = ns.Window and ns.Window.frame
  local list = { f and f._skinHost, ns.ProgressUI and ns.ProgressUI.frame and ns.ProgressUI.frame.skin }
  for i = 1, 2 do
    local h = list[i]
    if h then
      if h.SetBackdrop then pcall(h.SetBackdrop, h, Sk.Backdrop(h)) end
      Sk.UpdateArt(h)
    end
  end
end

-- Pose fond + bord ; a = alpha du fond. Renvoie le cadre.
function Sk.Paint(host, a, border)
  if not host then return nil end
  local b = border or Sk.TINT
  pcall(host.SetBackdropColor, host, Sk.BG[1], Sk.BG[2], Sk.BG[3], a or 1)
  pcall(host.SetBackdropBorderColor, host, b[1], b[2], b[3], 1)
  host._skinBgA = a
  Sk.UpdateArt(host)
  return host
end

function Sk.Apply(f)
  local host = Sk.Host(f, f == (ns.Window and ns.Window.frame))
  if not host then return nil end
  -- ancien cadre d'infobulle (3.3.9–3.3.11) : retiré
  local old = f._tipChrome
  if old and old ~= host and old.Hide then old:Hide() end
  f._tipChrome = host
  return { host = host, mode = "FlareUI (fond Dialog sombre + bord bronze)", border = {}, center = nil }
end

------------------------------------------------------------------------------
-- Panneau
------------------------------------------------------------------------------
local P, W = ns.Panel, ns.Window
if P and P.ApplyTooltipLook then
  local base = P.ApplyTooltipLook
  function P.ApplyTooltipLook(f)
    local c = Sk.enabled and Sk.Apply(f)
    if not c then return base(f) end
    local b = Sk.TINT
    P.tip = { mode = c.mode, host = c.host, skin = true, bgColor = { Sk.BG[1], Sk.BG[2], Sk.BG[3], 1 },
      borderColor = { b[1], b[2], b[3], 1 }, bg = {}, border = {} }
    local T = P.toast
    if T then for _, t in ipairs(T.bg) do if t.Hide then t:Hide() end end for _, t in ipairs(T.border) do if t.Hide then t:Hide() end end end
    if W then W.tipLook = P.tip.mode end
    c.host:Show()
    if P.ApplyOpacity then pcall(P.ApplyOpacity) end
    return P.tip
  end
end

-- 3.3.15 : couleurs de l'infobulle par défaut JAMAIS appliquées à l'habillage
if P and P.RefreshTipColors then
  local baseRTC = P.RefreshTipColors
  function P.RefreshTipColors(...)
    if P.tip and P.tip.skin then return false end
    return baseRTC(...)
  end
end
if P and P.ApplyTipAlpha then
  local baseATA = P.ApplyTipAlpha
  function P.ApplyTipAlpha(kb, kr)
    local X = P.tip
    if not (X and X.skin and X.host) then return baseATA(kb, kr) end
    local ba = math.min(1, (Sk.BG[4] or 1) * (kb or 1))
    -- 3.5.3 : tables réutilisées (appelé à chaque image pendant le fondu)
    local bc, tc = X.bgColor, X.borderColor
    if type(bc) ~= "table" then bc = {} X.bgColor = bc end
    if type(tc) ~= "table" then tc = {} X.borderColor = tc end
    bc[1], bc[2], bc[3], bc[4] = Sk.BG[1], Sk.BG[2], Sk.BG[3], 1
    tc[1], tc[2], tc[3], tc[4] = Sk.TINT[1], Sk.TINT[2], Sk.TINT[3], 1
    Sk.Paint(X.host, ba)
    X.bgAlpha, X.borderAlpha = ba, 1
  end
end
-- tout SetBackdrop (BackdropTemplate remet les couleurs à blanc) → repeint
function Sk.Guard(host)
  if not host or host._skGuard or not host.SetBackdrop then return end
  host._skGuard = true
  local base = host.SetBackdrop
  host.SetBackdrop = function(self, bd, ...)
    local r = { base(self, bd, ...) }
    if bd and self._skinBgA ~= nil then
      pcall(self.SetBackdropColor, self, Sk.BG[1], Sk.BG[2], Sk.BG[3], self._skinBgA)
      pcall(self.SetBackdropBorderColor, self, Sk.TINT[1], Sk.TINT[2], Sk.TINT[3], 1)
    end
    return unpack(r)
  end
end

------------------------------------------------------------------------------
-- Toasts : même recette (fond Dialog sombre, même alpha que le panneau)
------------------------------------------------------------------------------
local Ch = ns.Chrome
if Ch then
  local baseToast = Ch.Toast
  function Ch.Toast(f, tint)
    if type(f) ~= "table" or f._osrsPanel then return nil end
    local c = Sk.enabled and Sk.Apply(f)
    if not c then return baseToast and baseToast(f, tint) end
    for _, t in pairs(f._chatPieces or {}) do if t.Hide then t:Hide() end end
    if f.SetBackdropBorderColor then pcall(f.SetBackdropBorderColor, f, 0, 0, 0, 0) end
    if f.SetBackdropColor then pcall(f.SetBackdropColor, f, 0, 0, 0, 0) end
    local fl = f._flare and f._flare.border
    if fl then for _, t in pairs(fl) do if type(t) == "table" and t.Hide then t:Hide() end end end
    if f._toastBg then f._toastBg:Hide() end          -- le fond plat est recouvert par l'habillage
    local a
    if ns.UI and ns.UI.ToastBgAlpha then
      a = ns.UI.ToastBgAlpha(f)
    elseif ns.UI and ns.UI.DropBgAlpha then
      a = ns.UI:DropBgAlpha()
    end
    if a == nil then a = 0.68 end
    -- Fond Dialog : le RVB reste (1,1,1) ; l'opacité est SetAlpha du host
    -- (la texture Dialog ignore souvent l'alpha vertex → noir à 0 %).
    Sk.Paint(c.host, 1)
    c.host:Show()
    f._osrsNativeBorder = c.mode
    if ns.UI and ns.UI.ApplyToastLayerAlpha then pcall(ns.UI.ApplyToastLayerAlpha, f, a) end
    if ns.UI and ns.UI.ApplyToastTint then pcall(ns.UI.ApplyToastTint, f, f._tintOpts) end
    return c
  end
  -- bord à épaisseur native : l'habillage n'est jamais compensé ni agrandi
  local baseFix = Ch.FixScale
  function Ch.FixScale(host)
    if not host then return nil end
    if not host._osrsSkin and baseFix then return baseFix(host) end
    if host.SetScale then pcall(host.SetScale, host, 1) end
    local f = host._osrsFor
    if f then host:ClearAllPoints() host:SetAllPoints(f) end
    Ch.stats.rescaled = (Ch.stats.rescaled or 0) + 1
    return 1
  end
end

ns.DebugExt = ns.DebugExt or {}
ns.DebugExt[#ns.DebugExt + 1] = function()
  local f = W and W.frame
  local h = f and f._skinHost
  local rb = { "?" }
  if h and h.GetBackdropBorderColor then local ok, r, g, b = pcall(h.GetBackdropBorderColor, h) if ok and r then rb = { string.format("%.2f/%.2f/%.2f", r, g, b) } end end
  local old = f and f._tipChrome ~= h and f._tipChrome
  return { "— Habillage FlareUI (3.3.15) — " .. tostring(Sk.mode or "pas encore posé") .. " ; bord lu sur le cadre : " .. rb[1]
      .. ((old and old.IsShown and old:IsShown()) and " ; ATTENTION ancien cadre d'infobulle visible" or ""),
    string.format("fond %s (alpha %s), bord %s %d px teinté %.2f/%.2f/%.2f ; cadres : %d",
      Sk.BG_FILE, tostring(h and h._skinBgA), Sk.EDGE_FILE, Sk.EDGE_SIZE, Sk.BORDER[1], Sk.BORDER[2], Sk.BORDER[3], Sk.stats.hosts) }
end
