-- Dropamine — toasts : notifications de gain, de palier, de récolte, bannières
-- 3.9.0 : sorti de UI.lua (même code, même ordre). Les outils communs viennent de UI._T.
local ADDON, ns = ...
local Tr = ns.L
local UI = ns.UI
if not (UI and UI._T) then return end
local T = UI._T
local ColorPixelBorder, CreateSlotButton, EnsurePixelBorder, FillTexture = T.ColorPixelBorder, T.CreateSlotButton, T.EnsurePixelBorder, T.FillTexture
local GOLD, ResizeSlotButton, RestoreFramePos, SafeStep = T.GOLD, T.ResizeSlotButton, T.RestoreFramePos, T.SafeStep
local SaveFramePos, SetBackdropSafe, SetSkillBarProgress, SetTileIcon = T.SaveFramePos, T.SetBackdropSafe, T.SetSkillBarProgress, T.SetTileIcon
local SizeOf, TexOrFileID, Text, TryCreate = T.SizeOf, T.TexOrFileID, T.Text, T.TryCreate
local TrySetTex, initDBSafe = T.TrySetTex, T.initDBSafe

-- Drops d'XP / compétences, style notifications Forever au repos -------------
-- Au repos : fond noir translucide (~0.6) comme le chat, filet sombre mince,
-- titre or, sous-titre jaune, barre kaki, icône dans un anneau d'or.
-- Le voile bleu-gris n'apparaît QUE dans le mode édition (grille Forever).
-- Jamais le portrait : XP = icône livre du Niveau, compétences = leur icône.
-- v2.7.1 : 56 = hauteur d'un drop complet type (titre 12 + ligne 14 + marges 12
-- + astuce 11 + barre 7) ; c'est aussi la taille du support en mode édition.
local TOAST_W, TOAST_H = 260, 56
local TOAST_GAP = 6
local TOAST_FADEIN, TOAST_HOLD, TOAST_FADEOUT = 0.15, 2.6, 0.70
UI.TOAST_SLIDE = 7  -- px : glissement court à l'apparition / à la disparition
local TOAST_BG_A = 0.35   -- v2.7.1 : un peu plus translucide, comme le chat
local TOAST_LIGHT_H = 26

function UI.ToastScaleK()
  local pct = (ns.Layout and ns.Layout.Scale and ns.Layout.Scale()) or 100
  local k = (ns.N and ns.N(pct) or tonumber(pct) or 100) / 100
  if k < 0.9 then k = 0.9 end
  if k > 2 then k = 2 end
  return k
end
function UI.ToastPx(base, minv)
  local v = math.floor((base or 0) * UI.ToastScaleK() + 0.5)
  if minv and v < minv then v = minv end
  return v
end
function UI.ToastMetrics(opts)
  opts = opts or {}
  local light, hint, maxv, big = opts.light, opts.hint, opts.maxv, opts.big
  local icon = UI.ToastPx(light and 20 or (big and 40 or 32), light and 16 or 22)
  local titleSize = UI.ToastPx(light and 11 or (big and 16 or 13), 10)
  local subSize = UI.ToastPx(11, 9)
  local barH = UI.ToastPx(4, 3)
  local pad = UI.ToastPx(7, 5)
  local fh
  if light then
    fh = UI.ToastPx(TOAST_LIGHT_H, 22)
  else
    fh = pad + titleSize + 2 + subSize
    if hint and hint ~= "" then fh = fh + 1 + subSize end
    if maxv and maxv > 0 then fh = fh + barH + 8 end
    fh = fh + pad
    if fh < UI.ToastPx(46, 40) then fh = UI.ToastPx(46, 40) end
    if big then fh = math.max(fh, UI.ToastPx(UI.LEVELUP_H or TOAST_H, 56)) end
  end
  return { icon = icon, titleSize = titleSize, subSize = subSize, barH = barH, pad = pad, fh = math.floor(fh + 0.5) }
end
local function ApplyToastFont(fs, size, fallback)
  if not (fs and size) then return end
  local path, flags
  if fs.GetFont then
    local ok, pth, _, fl = pcall(fs.GetFont, fs)
    if ok then path, flags = pth, fl end
  end
  if (not path or path == "") and fallback then
    local fo = type(fallback) == "string" and _G[fallback] or fallback
    if fo and fo.GetFont then
      local ok, pth, _, fl = pcall(fo.GetFont, fo)
      if ok then path, flags = pth, fl end
    end
  end
  if path and fs.SetFont then pcall(fs.SetFont, fs, path, size, flags or "") end
end


-- Durée d'affichage (options) et opacité du fond, bornées.
function UI:DropHold()
  local v = ns.db and ns.db.ui and ns.N(ns.db.ui.dropDuration)
  if not v then return TOAST_HOLD end
  return math.max(1, math.min(10, v))
end
function UI:DropBgAlpha()
  local v = ns.db and ns.db.ui and ns.N(ns.db.ui.dropBgAlpha)
  if v == nil then v = 0.68 end   -- 0 est une vraie valeur (fond invisible)
  if v > 1 then v = math.min(1, v / 100) end
  return math.max(0, math.min(1, v))
end
local TOAST_BORDER = { 0.12, 0.10, 0.08, 0.95 }
local TOAST_YELLOW = { 1.00, 0.82, 0.20 }
local TOAST_KHAKI = { 0.76, 0.64, 0.30, 1 }
local EDIT_BG = { 0.45, 0.62, 0.78, 0.32 }
local EDIT_BORDER = { 0.55, 0.82, 0.95, 0.95 }
local RING_TEX = {
  "Interface\\Minimap\\MiniMap-TrackingBorder",
  "Interface\\Common\\WhiteIconFrame",
  "Interface\\Buttons\\UI-ActionButton-Border",
  "Interface\\ContainerFrame\\UI-Icon-QuestBorder",
}
-- v2.4.1 : les templates d'alerte natifs (AlertFrameTemplate...) déclarent un
-- OnClick réservé aux Button : sur un Frame ils lèvent un avertissement LUA
-- (non intercepté par pcall). On ne garde que BackdropTemplate.
local TOAST_TEMPLATES = { "BackdropTemplate" }
local LOOT_BAR_TEX = {
  "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar",
  "Interface\\TargetingFrame\\UI-StatusBar",
  "Interface\\Buttons\\WHITE8X8",
}
local CHAT_BG_FILES = {
  "Interface\\ChatFrame\\ChatFrameBackground",
  "Interface\\Tooltips\\UI-Tooltip-Background",
  "Interface\\Buttons\\WHITE8X8",
}
local CHAT_EDGE_FILES = {
  "Interface\\Tooltips\\UI-Tooltip-Border",
  "Interface\\ChatFrame\\ChatFrameBorder",
  "Interface\\DialogFrame\\UI-DialogBox-Border",
}

-- v2.5.0 : chrome des drops = cadre du chat Forever (fond noir translucide,
-- filet doré fin aux coins arrondis). Pièces relevées en jeu sur ChatFrame1
-- (NineSlice ou textures $parentTopLeftTexture…), recopiées telles quelles ;
-- repli : bord arrondi des info-bulles teinté or + fond du chat.
local CHAT_PIECES = {
  { key = "TopLeftCorner", suffix = "TopLeftTexture", corner = "TOPLEFT" },
  { key = "TopRightCorner", suffix = "TopRightTexture", corner = "TOPRIGHT" },
  { key = "BottomLeftCorner", suffix = "BottomLeftTexture", corner = "BOTTOMLEFT" },
  { key = "BottomRightCorner", suffix = "BottomRightTexture", corner = "BOTTOMRIGHT" },
  { key = "TopEdge", suffix = "TopTexture", edge = "TOP" },
  { key = "BottomEdge", suffix = "BottomTexture", edge = "BOTTOM" },
  { key = "LeftEdge", suffix = "LeftTexture", edge = "LEFT" },
  { key = "RightEdge", suffix = "RightTexture", edge = "RIGHT" },
}
local CHAT_FALLBACK_EDGE = "Interface\\Tooltips\\UI-Tooltip-Border"
local CHAT_FALLBACK_BG = "Interface\\ChatFrame\\ChatFrameBackground"
-- v2.7.1 : bronze du bord du chat, relevé au pixel sur la capture des drops
-- (055c59bc….png) : #655131 (101, 81, 49).
local CHAT_GOLD = { 101 / 255, 81 / 255, 49 / 255, 1 }

local function PieceInfo(tex)
  if type(tex) ~= "table" then return nil end
  local path, atlas = TexOrFileID(tex)
  if not path then return nil end
  local info = { tex = path, atlas = atlas }
  if tex.GetTexCoord then
    local ok, a, b, c, d, e, f2, g, h = pcall(tex.GetTexCoord, tex)
    if ok and a then info.coords = { a, b, c, d, e, f2, g, h } end
  end
  local w, h2 = SizeOf(tex)
  info.w, info.h = w, h2
  if tex.GetVertexColor then
    local ok, r, g2, b2, a2 = pcall(tex.GetVertexColor, tex)
    if ok and r then info.color = { r, g2, b2, a2 or 1 } end
  end
  return info
end

-- v2.7.2 : le vrai bord du chat est copié à l'exécution. Ordre :
--   1. NineSlice / Border du ChatFrame1 (pièces + couleurs d'origine) ;
--   2. backdrop du ChatFrame1 (GetBackdrop : edgeFile, edgeSize, insets, couleur) ;
--   3. enfants du ChatFrame1 portant un NineSlice ou un backdrop à bord ;
--   sinon repli dessiné : 3 px (filet sombre + or + bronze relevés au pixel).
-- Les textures ChatFrame1TopLeftTexture… ne sont PLUS utilisées : c'est le
-- fond gris qui apparaît au survol du chat, d'où le bord gris/blanc en 2.7.1.
local function BackdropInfo(fr)
  if type(fr) ~= "table" or type(fr.GetBackdrop) ~= "function" then return nil end
  local ok, bd = pcall(fr.GetBackdrop, fr)
  if not ok or type(bd) ~= "table" or not bd.edgeFile then return nil end
  local info = { edgeFile = bd.edgeFile, edgeSize = ns.N(bd.edgeSize) or 12, tile = bd.tile, tileEdge = bd.tileEdge,
    insets = type(bd.insets) == "table" and { left = ns.N(bd.insets.left) or 0, right = ns.N(bd.insets.right) or 0,
      top = ns.N(bd.insets.top) or 0, bottom = ns.N(bd.insets.bottom) or 0 } or nil }
  if fr.GetBackdropBorderColor then
    local okc, r, g, b, a = pcall(fr.GetBackdropBorderColor, fr)
    if okc and ns.N(r) then info.color = { r, g, b, a or 1 } end
  end
  return info
end

local function NinePieces(ns9)
  if type(ns9) ~= "table" then return nil end
  local pieces = {}
  for i = 1, #CHAT_PIECES do
    local pc = CHAT_PIECES[i]
    local info = PieceInfo(ns9[pc.key])
    if info then pieces[pc.key] = info end
  end
  return next(pieces) and pieces or nil
end

function UI:LearnChatChrome()
  if self.chatChrome and self.chatChrome.learned then return self.chatChrome end
  local cc = { learned = false, pieces = {}, source = "repli FlareUI (Border.tga : #181513 / #624F32 / #463824 / #161412)" }
  local cf = _G.ChatFrame1
  if type(cf) == "table" then
    -- 1. NineSlice / Border
    for _, k in ipairs({ "NineSlice", "Border" }) do
      local p9 = not next(cc.pieces) and NinePieces(cf[k])
      if p9 then cc.pieces, cc.source = p9, "ChatFrame1." .. k end
    end
    -- 2. backdrop du chat
    if not next(cc.pieces) then
      local bdi = BackdropInfo(cf) or BackdropInfo(cf.Border)
      if bdi then cc.backdrop, cc.source = bdi, "ChatFrame1:GetBackdrop() " .. tostring(bdi.edgeFile) .. " (" .. tostring(bdi.edgeSize) .. " px)" end
    end
    -- 3. enfants du chat
    if not next(cc.pieces) and not cc.backdrop and cf.GetChildren then
      local kids = { pcall(cf.GetChildren, cf) }
      if kids[1] then
        for i = 2, #kids do
          local c = kids[i]
          local nm = (c and c.GetName and c:GetName()) or "(enfant)"
          local p9 = NinePieces(c and c.NineSlice)
          if p9 then cc.pieces, cc.source = p9, tostring(nm) .. ".NineSlice" break end
          local bdi = BackdropInfo(c)
          if bdi then cc.backdrop, cc.source = bdi, tostring(nm) .. ":GetBackdrop() " .. tostring(bdi.edgeFile) break end
        end
      end
    end
    local bg = _G.ChatFrame1Background or (type(cf.Background) == "table" and cf.Background)
    local bgi = PieceInfo(bg)
    if bgi then cc.bg = bgi end
    -- Couleur du fond : alpha relevée, jamais plus opaque que 0,5 au repos.
    if bgi and bgi.color then
      local a = bgi.color[4] or TOAST_BG_A
      if a > 0.5 or a < 0.2 then a = TOAST_BG_A end
      cc.bgColor = { 0, 0, 0, a }
    end
    cc.learned = next(cc.pieces) ~= nil or cc.backdrop ~= nil
  end
  cc.bgColor = cc.bgColor or { 0, 0, 0, TOAST_BG_A }
  self.chatChrome = cc
  return cc
end

local ApplyRestToastChromeRaw
-- 3.3.9 : bord des toasts = bord de l'infobulle native (Chrome.lua), coins lisses.
local function ApplyRestToastChrome(frame, tint, noBg)
  local r = ApplyRestToastChromeRaw(frame, tint, noBg)
  if frame and not noBg and ns.Chrome and ns.Chrome.Toast then
    local ok, c = pcall(ns.Chrome.Toast, frame, tint)
    if ok and c then return frame._osrsNativeBorder end
  end
  return r
end
ApplyRestToastChromeRaw = function(frame, tint, noBg)
  if not frame then return "none" end
  local cc = UI:LearnChatChrome()
  local bgc = cc.bgColor
  local ua = UI:DropBgAlpha()
  if ua == nil then ua = 0.68 end
  bgc = { bgc[1], bgc[2], bgc[3], 1 }   -- RVB constant ; l'alpha va sur le calque
  if not noBg then
  frame._bgAlpha = ua
  if not frame._toastBg then
    frame._toastBg = frame:CreateTexture(nil, "BACKGROUND")
  end
  frame._toastBg:ClearAllPoints()
  frame._toastBg:SetPoint("TOPLEFT", 3, -3)
  frame._toastBg:SetPoint("BOTTOMRIGHT", -3, 3)
  FillTexture(frame._toastBg, bgc[1], bgc[2], bgc[3], 1)
  end
  if UI.ApplyToastLayerAlpha then UI.ApplyToastLayerAlpha(frame, ua) end
  if next(cc.pieces) then
    frame._chatPieces = frame._chatPieces or {}
    local cw, chh = 16, 16
    local tl = cc.pieces.TopLeftCorner
    if tl and tl.w and tl.w > 0 and tl.w <= 64 then cw = tl.w end
    if tl and tl.h and tl.h > 0 and tl.h <= 64 then chh = tl.h end
    for i = 1, #CHAT_PIECES do
      local pc = CHAT_PIECES[i]
      local info = cc.pieces[pc.key]
      if info then
        local t = frame._chatPieces[pc.key] or frame:CreateTexture(nil, "BORDER")
        frame._chatPieces[pc.key] = t
        t:ClearAllPoints()
        TrySetTex(t, info.tex, nil, info.atlas)
        if info.coords and t.SetTexCoord then pcall(t.SetTexCoord, t, unpack(info.coords)) end
        if pc.corner then
          t:SetSize(cw, chh)
          t:SetPoint(pc.corner, frame, pc.corner, 0, 0)
        elseif pc.edge == "TOP" or pc.edge == "BOTTOM" then
          t:SetHeight(chh)
          t:SetPoint(pc.edge .. "LEFT", frame, pc.edge .. "LEFT", cw, 0)
          t:SetPoint(pc.edge .. "RIGHT", frame, pc.edge .. "RIGHT", -cw, 0)
        else
          t:SetWidth(cw)
          t:SetPoint("TOP" .. pc.edge, frame, "TOP" .. pc.edge, 0, -chh)
          t:SetPoint("BOTTOM" .. pc.edge, frame, "BOTTOM" .. pc.edge, 0, chh)
        end
        -- Couleur d'origine du chat ; seule une variante (or / palier) teinte.
        local col = tint or info.color or { 1, 1, 1, 1 }
        if t.SetVertexColor then pcall(t.SetVertexColor, t, col[1], col[2], col[3], col[4] or 1) end
        t:Show()
      end
    end
    frame._osrsNativeBorder = "chat:" .. tostring(cc.source)
    return frame._osrsNativeBorder
  end
  if cc.backdrop then
    local b = cc.backdrop
    local bd = { edgeFile = b.edgeFile, edgeSize = b.edgeSize, tile = b.tile, tileEdge = b.tileEdge, insets = b.insets }
    local col = tint or b.color or { 1, 1, 1, 1 }
    if SetBackdropSafe(frame, bd, nil, nil, nil, nil, col[1], col[2], col[3], col[4] or 1) then
      frame._osrsNativeBorder = "chat:" .. tostring(cc.source)
      return frame._osrsNativeBorder
    end
  end
  ns.Style.FlareBorder(frame, "BORDER", 2, tint)
  frame._osrsNativeBorder = "repli FlareUI (Border.tga, or 4 px)"
  return frame._osrsNativeBorder
end

function UI:DropsEnabled()
  return not (ns.db and ns.db.ui and ns.db.ui.dropsEnabled == false)
end

function UI:BuildDrops()
  if self.dropsFrame then
    self:HookEditMode()
    return self.dropsFrame
  end
  local existing = _G.DropamineDrops
  if type(existing) == "table" and existing.SetPoint then
    self.dropsFrame = existing
    self.dropsStack = existing.stack or existing
    self.dropsActive = self.dropsActive or {}
    self:HookEditMode()
    return existing
  end
  local parent = UIParent
  if not parent then return nil end
  local f, usedTmpl
  for i = 1, #TOAST_TEMPLATES do
    local ok, cand = pcall(CreateFrame, "Frame", "DropamineDrops", parent, TOAST_TEMPLATES[i])
    if ok and cand then f, usedTmpl = cand, TOAST_TEMPLATES[i] break end
  end
  if not f then f = CreateFrame("Frame", "DropamineDrops", parent) end
  -- v2.7.1 : le support a exactement la taille du premier drop (aucune marge),
  -- pour pouvoir le poser pile sur le cadre de chat.
  local firstH = self:DropFirstHeight()
  f:SetSize(TOAST_W, firstH)
  if f.SetFrameStrata then pcall(f.SetFrameStrata, f, "HIGH") end
  if f.SetMovable then pcall(f.SetMovable, f, true) end
  if f.EnableMouse then pcall(f.EnableMouse, f, false) end
  if f.RegisterForDrag then pcall(f.RegisterForDrag, f, "LeftButton") end
  f:SetScript("OnDragStart", function(self)
    if (self._osrsMoving or self._osrsEditMoving) and self.StartMoving then
      pcall(self.StartMoving, self)
    end
  end)
  f:SetScript("OnDragStop", function(self)
    if self.StopMovingOrSizing then pcall(self.StopMovingOrSizing, self) end
    SaveFramePos(self, "dropsPos")
    UI:SnapDropsToChat()
  end)
  if f.SetClampedToScreen then pcall(f.SetClampedToScreen, f, true) end
  -- Migration : avant 2.7.1 le support faisait 200 px de haut, ancré par le
  -- bas ; on garde son bord haut à la même place (empilement vers le bas).
  if ns.db and ns.db.ui and ns.db.ui.dropsPos and not ns.db.ui.dropsPosV271 then
    local p = ns.db.ui.dropsPos
    if (p.point or "BOTTOMLEFT") == "BOTTOMLEFT" and type(p.y) == "number" then p.y = p.y + (200 - firstH) end
  end
  if ns.db and ns.db.ui then ns.db.ui.dropsPosV271 = true end
  f._osrsHeight = firstH
  RestoreFramePos(f, "dropsPos", { "TOPRIGHT", -40, -80 })
  if ns.db and ns.db.ui and ns.db.ui.dropsSnapChat then
    local _, _, cw = self:ChatRect()
    if cw then f._snapW = math.floor(cw + 0.5) f:SetSize(f._snapW, firstH) end
  end

  -- Poignée /drop drops move : style chat (fond noir), PAS le voile bleu d'édition.
  local handle = CreateFrame("Frame", nil, f)
  handle:SetHeight(18)
  ApplyRestToastChrome(handle)
  local hfs = Text(handle, "GameFontNormalSmall", "CENTER")
  hfs:SetPoint("CENTER", 0, 0)
  hfs:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
  hfs:SetText(Tr["Drops  ·  glisser pour déplacer"])
  handle:Hide()
  f.handle = handle

  -- Voile bleu-gris du mode édition uniquement.
  local ov = CreateFrame("Frame", nil, f)
  ov:SetAllPoints(f)   -- v2.7.1 : voile = taille exacte du premier drop
  if ov.SetFrameLevel and f.GetFrameLevel then
    pcall(ov.SetFrameLevel, ov, (f:GetFrameLevel() or 1) + 1)
  end
  if ov.EnableMouse then pcall(ov.EnableMouse, ov, false) end
  local glow = ov:CreateTexture(nil, "BACKGROUND")
  glow:SetAllPoints(ov)
  FillTexture(glow, EDIT_BORDER[1], EDIT_BORDER[2], EDIT_BORDER[3], 0.18)
  local ovbg = ov:CreateTexture(nil, "ARTWORK")
  ovbg:SetAllPoints()
  FillTexture(ovbg, EDIT_BG[1], EDIT_BG[2], EDIT_BG[3], EDIT_BG[4])
  EnsurePixelBorder(ov, "OVERLAY")
  ColorPixelBorder(ov, EDIT_BORDER[1], EDIT_BORDER[2], EDIT_BORDER[3], EDIT_BORDER[4])
  local ovfs = Text(ov, "GameFontNormal", "CENTER")
  ovfs:SetPoint("CENTER", 0, 0)
  ovfs:SetTextColor(0.85, 0.95, 1)
  ovfs:SetText(Tr["Drops  ·  glisser pour déplacer"])
  ov:Hide()
  f.editOverlay, f.editLabel = ov, ovfs

  local stack = CreateFrame("Frame", nil, f)
  stack:SetPoint("TOPLEFT", 0, 0)
  stack:SetPoint("BOTTOMRIGHT", 0, 0)
  f.stack = stack

  self.dropsFrame, self.dropsStack = f, stack
  self.dropsActive = {}
  self._dropsTemplate = usedTmpl
  self:PlaceDropsHandle()
  if f.Show then pcall(f.Show, f) end
  self:HookEditMode()
  return f
end

function UI:ApplyDropsEnabled()
  self:BuildDrops()
  if not self.dropsFrame then return end
  if self:DropsEnabled() or self._inEditMode or (self.dropsFrame and self.dropsFrame._osrsMoving) then
    if self.dropsFrame.Show then pcall(self.dropsFrame.Show, self.dropsFrame) end
  else
    if self.dropsFrame.Hide then pcall(self.dropsFrame.Hide, self.dropsFrame) end
  end
end

function UI:ToggleDropsMove()
  self:BuildDrops()
  self:ApplyDropsEnabled()
  local f = self.dropsFrame
  if not f then return end
  if not self:DropsEnabled() then
    if ns.db and ns.db.ui then ns.db.ui.dropsEnabled = true end
    self:ApplyDropsEnabled()
  end
  f._osrsMoving = not f._osrsMoving
  if f.EnableMouse then pcall(f.EnableMouse, f, (f._osrsMoving or self._inEditMode) and true or false) end
  if f.handle and not self._inEditMode then
    if f._osrsMoving then f.handle:Show() else f.handle:Hide() end
  end
  if f._osrsMoving then
    ns.Print(Tr["déplace le cadre des drops, puis /drop drops move pour figer."])
  else
    SaveFramePos(f, "dropsPos")
    ns.Print(Tr["position des drops enregistrée."])
  end
end

-- 3.5.1 : sens d'empilement en position libre (« Vers le haut » par défaut,
-- « Vers le bas », « Sur place »). En position accrochée, Notif.lua force
-- haut / bas selon dessus / dessous.
UI.PILE_OFF, UI.PILE_MAX = 4, 3
UI.PILE_FADE = { 1, 0.80, 0.60 }
function UI:DropDir()
  local d = ns.db and ns.db.ui and ns.db.ui.dropDir
  if d == "haut" or d == "bas" or d == "place" then return d end
  return "haut"
end

local function ToastAlpha(frame, a)
  if not frame or not frame.SetAlpha then return end
  local fade = frame._pileHidden and 0 or (frame._pileFade or 1)
  pcall(frame.SetAlpha, frame, (a or 1) * fade)
end

local function EnsurePileShade(t)
  if t._shade then return t._shade end
  if not t.CreateTexture then return nil end
  local sh = t:CreateTexture(nil, "OVERLAY")
  sh:SetAllPoints(t)
  pcall(sh.SetTexture, sh, "Interface\\Buttons\\WHITE8X8")
  if sh.SetDrawLayer then pcall(sh.SetDrawLayer, sh, "OVERLAY", 7) end
  t._shade = sh
  return sh
end

-- v2.7.2 : support posé sur le chat → même largeur que le chat, collé à son
-- bord haut et aligné à gauche (aimant de 16 px). Sinon 260 px.
UI.SNAP_PX = 16
function UI:ChatRect()
  local cf = _G.ChatFrame1
  if type(cf) ~= "table" or not cf.GetLeft then return nil end
  local l, t, w = cf:GetLeft(), cf.GetTop and cf:GetTop(), cf.GetWidth and cf:GetWidth()
  l, t, w = ns.N(l), ns.N(t), ns.N(w)
  if not (l and t and w and w > 50) then return nil end
  return l, t, w
end

function UI:DropSnappedToChat()
  local f = self.dropsFrame
  if not f or not f.GetLeft or not f.GetBottom then return false end
  local cl, ct = self:ChatRect()
  if not cl then return false end
  local l, b = ns.N(f:GetLeft()), ns.N(f:GetBottom())
  if not (l and b) then return false end
  return math.abs(l - cl) <= UI.SNAP_PX and b >= ct - UI.SNAP_PX and b <= ct + UI.SNAP_PX * 3
end

function UI:PanelWidth()
  local W = ns.Window
  local f = W and W.frame
  if f and f.GetWidth then
    local w = ns.N(f:GetWidth())
    if w and w > 0 then return w end
  end
  return nil
end

-- Auto : largeur du panneau, minimum lisible 260 px × échelle.
-- Manuel : db.ui.dropWidth >= 200.
function UI:DropWidth()
  if self.dropsFrame and self.dropsFrame._snapW then return self.dropsFrame._snapW end
  local ui = ns.db and ns.db.ui
  local manual = ns.N(ui and ui.dropWidth)
  if manual and manual >= 200 then return math.floor(manual + 0.5) end
  local scale = (ns.Layout and ns.Layout.Scale and ns.Layout.Scale()) or 100
  local minW = math.floor(260 * (scale / 100) + 0.5)
  if minW < 160 then minW = 160 end
  local pw = self.PanelWidth and self:PanelWidth()
  return math.max(minW, math.floor((pw or 0) + 0.5))
end

-- Si le toast est plus large que le panneau, l'aligner sur le bord du panneau
-- du côté de l'écran, pour ne pas dépasser vers le bord de l'écran.
function UI:AlignDropsToPanel()
  local f = self.dropsFrame
  local W = ns.Window
  local panel = W and W.frame
  if not (f and panel and UIParent) then return end
  if f._osrsMoving or f._osrsEditMoving then return end
  if ns.db and ns.db.ui and ns.db.ui.dropsSnapChat then return end
  if not (f.GetTop and panel.GetLeft and panel.GetRight and UIParent.GetWidth) then return end
  local pl, pr, top = ns.N(panel:GetLeft()), ns.N(panel:GetRight()), ns.N(f:GetTop())
  if not (pl and pr and top) then return end
  local tw = self:DropWidth()
  local pw = pr - pl
  if tw <= pw + 1 then return end
  local sw = ns.N(UIParent:GetWidth()) or 0
  local leftSide = ((pl + pr) / 2) < (sw / 2)
  if f.ClearAllPoints then f:ClearAllPoints() end
  if leftSide then
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pl, top)
  else
    f:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", pr, top)
  end
  if f.SetClampedToScreen then pcall(f.SetClampedToScreen, f, true) end
end

-- Après un déplacement : aimante le support au chat (même largeur, sans décalage).
function UI:SnapDropsToChat()
  local f = self.dropsFrame
  if not f then return false end
  if self:DropSnappedToChat() then
    local cl, ct, cw = self:ChatRect()
    f._snapW = math.floor(cw + 0.5)
    f:ClearAllPoints()
    f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", cl, ct)
    if ns.db and ns.db.ui then
      ns.db.ui.dropsPos = { point = "BOTTOMLEFT", relativePoint = "BOTTOMLEFT", x = cl, y = ct }
      ns.db.ui.dropsSnapChat = true
    end
  else
    f._snapW = nil
    if ns.db and ns.db.ui then ns.db.ui.dropsSnapChat = false end
  end
  self:ApplyDropsLayout()
  return f._snapW ~= nil
end

-- Option « Coller au chat » : pose le support au ras du bord haut du chat.
function UI:SetDropsSnapChat(on)
  self:BuildDrops()
  local f = self.dropsFrame
  if not f then return false end
  if on then
    local cl, ct, cw = self:ChatRect()
    if not cl then
      if ns.db and ns.db.ui then ns.db.ui.dropsSnapChat = false end
      ns.Print(Tr["cadre de chat introuvable : impossible d'y coller les drops."])
      return false
    end
    f._snapW = math.floor(cw + 0.5)
    f:ClearAllPoints()
    f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", cl, ct)
    if ns.db and ns.db.ui then
      ns.db.ui.dropsPos = { point = "BOTTOMLEFT", relativePoint = "BOTTOMLEFT", x = cl, y = ct }
      ns.db.ui.dropsSnapChat = true
    end
  else
    f._snapW = nil
    if ns.db and ns.db.ui then ns.db.ui.dropsSnapChat = false end
  end
  self:ApplyDropsLayout()
  return f._snapW ~= nil
end

function UI:DropFirstHeight()
  local light = ns.db and ns.db.ui and ns.db.ui.dropStyle == "leger"
  if UI.ToastMetrics then
    return UI.ToastMetrics({ light = light }).fh
  end
  return light and TOAST_LIGHT_H or TOAST_H
end

function UI:PlaceDropsHandle()
  local f = self.dropsFrame
  local h = f and f.handle
  if not h then return end
  h:ClearAllPoints()
  local dir = self:DropDir()
  if dir == "haut" or dir == "place" then
    -- Les drops montent ou s'empilent sur place : la poignée passe sous le support.
    h:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, 0)
    h:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 0, 0)
  else
    h:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 0)
    h:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, 0)
  end
end

-- Recalcule la taille du support (= premier drop, + décalage pile en « sur place »)
-- en gardant fixe le bord d'ancrage (haut en « vers le bas », bas autrement).
function UI:ApplyDropsLayout()
  local f = self.dropsFrame
  if not f then return end
  local newH = self:DropFirstHeight()
  local dir = self:DropDir()
  local extra = (dir == "place") and ((self.PILE_MAX or 3) - 1) * (self.PILE_OFF or 4) or 0
  local oldH = f._osrsHeight or newH
  local oldExtra = f._osrsPile or 0
  if (newH + extra) ~= (oldH + oldExtra) and f.GetLeft and f.GetBottom then
    local l, b = f:GetLeft(), f:GetBottom()
    if type(l) == "number" and type(b) == "number" then
      if dir == "bas" then b = b + (oldH + oldExtra) - (newH + extra) end
      f:ClearAllPoints()
      f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, b)
      if ns.db and ns.db.ui then ns.db.ui.dropsPos = { point = "BOTTOMLEFT", relativePoint = "BOTTOMLEFT", x = l, y = b } end
    end
  end
  f:SetSize(self:DropWidth() + extra, newH + extra)
  f._osrsHeight, f._osrsPile = newH, extra
  if self.AlignDropsToPanel then pcall(self.AlignDropsToPanel, self) end
  self:PlaceDropsHandle()
  self:PackDrops()
end

function UI.ToastSlideAmount(frame)
  if not frame or frame._pileHidden then return 0 end
  if frame._editPreview then return 0 end
  local t = frame._toastAge or 0
  local holdT = frame._hold or (UI.DropHold and UI:DropHold()) or TOAST_HOLD
  local dist = UI.TOAST_SLIDE or 7
  if frame._sticky then
    if t < TOAST_FADEIN then return dist * (1 - t / TOAST_FADEIN) end
    return 0
  end
  if t < TOAST_FADEIN then
    return dist * (1 - t / TOAST_FADEIN)
  elseif t < TOAST_FADEIN + holdT then
    return 0
  elseif t < TOAST_FADEIN + holdT + TOAST_FADEOUT then
    local k = (t - TOAST_FADEIN - holdT) / TOAST_FADEOUT
    return dist * k
  end
  return dist
end

function UI.ApplyToastPoint(frame, slide)
  if not frame then return end
  local pt, rel, rp = frame._packPt, frame._packRel, frame._packRP
  local x, y = frame._packX, frame._packY
  if not pt then return end
  slide = slide or 0
  if frame._slideApplied == slide and frame._packApplied then return end
  local oy = y or 0
  if pt == "BOTTOMLEFT" or pt == "BOTTOMRIGHT" or pt == "BOTTOM" then
    oy = (y or 0) - slide
  else
    oy = (y or 0) + slide
  end
  if frame.ClearAllPoints then pcall(frame.ClearAllPoints, frame) end
  if frame.SetPoint then pcall(frame.SetPoint, frame, pt, rel, rp, x or 0, oy) end
  frame._slideApplied, frame._packApplied = slide, true
end

function UI:PackDrops()
  local parent = self.dropsStack or self.dropsFrame
  if not parent or not self.dropsActive then return end
  local dir = self:DropDir()
  local n = #self.dropsActive
  local pile = dir == "place"
  local off, maxv = self.PILE_OFF or 4, self.PILE_MAX or 3
  local fades = self.PILE_FADE or { 1, 0.80, 0.60 }
  local baseLvl = (parent.GetFrameLevel and parent:GetFrameLevel()) or 1
  if pile then
    for i = 1, n do
      local t = self.dropsActive[i]
      if t and t.ClearAllPoints then
        t:ClearAllPoints()
        local depth = n - i
        if depth >= maxv then
          t._pileHidden, t._pileFade = true, 0
          if t._shade then t._shade:Hide() end
          if t.Hide then pcall(t.Hide, t) end
          ToastAlpha(t, 0)
          if t.EnableMouse then pcall(t.EnableMouse, t, false) end
        else
          t._pileHidden, t._pileFade = nil, fades[depth + 1] or 0.5
          if t.Show then pcall(t.Show, t) end
          t._packPt, t._packRel, t._packRP = "BOTTOMLEFT", parent, "BOTTOMLEFT"
          t._packX, t._packY, t._packApplied = depth * off, depth * off, nil
          UI.ApplyToastPoint(t, (depth == 0) and UI.ToastSlideAmount(t) or 0)
          if t.SetFrameLevel then pcall(t.SetFrameLevel, t, baseLvl + (maxv - depth) + 1) end
          if depth > 0 then
            local sh = EnsurePileShade(t)
            if sh then
              sh:SetVertexColor(0, 0, 0, 0.18 * depth)
              sh:Show()
            end
            if t.EnableMouse then pcall(t.EnableMouse, t, false) end
          else
            if t._shade then t._shade:Hide() end
            if t.EnableMouse and not self._inEditMode then pcall(t.EnableMouse, t, true) end
          end
          ToastAlpha(t, 1)
        end
      end
    end
    return
  end
  local y = 0
  if dir == "haut" then
    -- Le plus récent reste à l'ancre (bas du support), les plus anciens montent.
    for i = n, 1, -1 do
      local t = self.dropsActive[i]
      if t and t.ClearAllPoints then
        t._pileHidden, t._pileFade = nil, 1
        if t._shade then t._shade:Hide() end
        t:ClearAllPoints()
        if t.Show then pcall(t.Show, t) end
        t._packPt, t._packRel, t._packRP = "BOTTOMLEFT", parent, "BOTTOMLEFT"
        t._packX, t._packY, t._packApplied = 0, y, nil
        UI.ApplyToastPoint(t, UI.ToastSlideAmount(t))
        y = y + (t._h or TOAST_H) + TOAST_GAP
        ToastAlpha(t, 1)
      end
    end
  else
    -- Vers le bas : comportement historique (le plus ancien en haut, les suivants en dessous).
    for i = 1, n do
      local t = self.dropsActive[i]
      if t and t.ClearAllPoints then
        t._pileHidden, t._pileFade = nil, 1
        if t._shade then t._shade:Hide() end
        t:ClearAllPoints()
        if t.Show then pcall(t.Show, t) end
        t._packPt, t._packRel, t._packRP = "TOPLEFT", parent, "TOPLEFT"
        t._packX, t._packY, t._packApplied = 0, -y, nil
        UI.ApplyToastPoint(t, UI.ToastSlideAmount(t))
        y = y + (t._h or TOAST_H) + TOAST_GAP
        ToastAlpha(t, 1)
      end
    end
  end
end

-- Teinte de toast = la même palette que le voile de case, le +1 et l'étincelle.
-- Slot.lua pose ns.GAIN_COLORS ; repli identique si lu avant le chargement de Slot.
-- Toasts système (vol, sacs, usure…) restent neutres (pas de famille).
local GAIN_FALLBACK = {
  red   = { 0.616, 0.278, 0.227 },
  blue  = { 0.329, 0.408, 0.604 },
  green = { 0.310, 0.498, 0.243 },
}
function UI.GainPalette()
  return ns.GAIN_COLORS or (ns.Slot and ns.Slot.ADD_COLORS) or GAIN_FALLBACK
end
-- Même teinte (rouge / bleu / vert), valeur abaissée pour coller au fond sombre.
-- L'opacité du calque vient uniquement de « Fond des toasts », jamais d'un RVB.
UI.TINT_VALUE = 0.40
function UI.ShadeTint(c)
  if type(c) ~= "table" then return c end
  local k = UI.TINT_VALUE
  if type(k) ~= "number" or k <= 0 then k = 0.40 end
  if k > 1 then k = 1 end
  return { (c[1] or 0) * k, (c[2] or 0) * k, (c[3] or 0) * k }
end
function UI.ToastTintColor(opts_or_fam)
  local fam = opts_or_fam
  if type(opts_or_fam) == "table" then fam = UI.ToastFamily(opts_or_fam) end
  local G = UI.GainPalette()
  if fam == "level" then return UI.ShadeTint(G.red) end
  if fam == "weapon" then return UI.ShadeTint(G.blue) end
  if fam == "prof" then return UI.ShadeTint(G.green) end
  return nil
end
UI.TOAST_TINT = setmetatable({}, {
  __index = function(_, fam) return UI.ToastTintColor(fam) end,
})

-- Icône manquante / goutte de repli (pas l'art XP).
local function IsMissingToastIcon(path)
  -- identifiant de fichier du jeu (icône d'objet) : valide tant que ce n'est pas le point d'interrogation
  if type(path) == "number" then return not (path > 0 and not (ns.IconMissing and ns.IconMissing(path))) end
  if type(path) ~= "string" or path == "" then return true end
  if ns.IconMissing and ns.IconMissing(path) then return true end
  if path == ns.FALLBACK_ICON then return true end
  local l = path:lower():gsub("/", "\\")
  if l:find("fallback%-icon", 1, true) then return true end
  return false
end

local function IsXpVialIcon(path)
  if type(path) ~= "string" or path == "" then return false end
  if path == ns.LEVEL_ICON then return true end
  local l = path:lower():gsub("/", "\\")
  return l:find("xp%-icon", 1, true) and true or false
end

function UI.CatalogEntry(opts)
  opts = opts or {}
  local id, name = opts.skillId, opts.skillName
  local td = opts.toastData
  if type(td) == "table" then
    id = id or td.skill or td.skillId
    name = name or td.skillName
    if type(td.recipe) == "table" then
      id = id or td.recipe.skill or td.recipe.skillId
      name = name or td.recipe.skillName or td.recipe.profession
    end
    if type(td.matches) == "table" and td.matches[1] and td.matches[1].recipe then
      local r = td.matches[1].recipe
      id = id or r.skill or r.skillId
      name = name or r.skillName or r.profession
    end
  end
  local e
  if id and ns.CATALOG_BY_ID then e = ns.CATALOG_BY_ID[id] end
  if not e and name and ns.LookupCatalog then e = ns.LookupCatalog(name) end
  return e, id, name
end

local function KindOf(opts, e)
  if opts and opts.skillKind then return opts.skillKind end
  if e and e.kind then return e.kind end
  local id = opts and opts.skillId
  if id and ns.CATALOG_BY_ID and ns.CATALOG_BY_ID[id] then return ns.CATALOG_BY_ID[id].kind end
  if id or (opts and opts.skillName) then
    local snap = UI.snapshot
    for _, d in ipairs((snap and (snap.allTiles or snap.tiles)) or {}) do
      if d and (d.id == id or d.name == (opts and opts.skillName)) then return d.kind end
    end
  end
end

local function FamilyFromKind(dkind)
  if dkind == "level" then return "level" end
  if dkind == "melee" or dkind == "ranged" or dkind == "defense" or dkind == "feral" or dkind == "class" then
    return "weapon"
  end
  if dkind == "profession" or dkind == "secondary" then return "prof" end
end

function UI.ToastFamily(opts)
  opts = opts or {}
  local kind = opts.kind or (opts.toastData and opts.toastData.kind)
  if kind == "xp" or kind == "levelup" or kind == "level" or kind == "jalon" or kind == "spells"
    or kind == "xp-milestone" then
    return "level"
  end
  if kind == "flight-hint" or kind == "bags-full" or kind == "durability" or kind == "pvp" or kind == "weekly"
    or kind == "achievement" or kind == "progress" or kind == "recap" or kind == "test"
    or kind == "milestone" or kind == "record" or kind == "max" or kind == "combo" then
    -- jalons / records / max peuvent encore être typés par la compétence plus bas
    if kind == "flight-hint" or kind == "bags-full" or kind == "durability" or kind == "pvp"
      or kind == "weekly" or kind == "achievement" or kind == "progress" or kind == "recap"
      or kind == "test" then
      return nil
    end
  end
  local e = UI.CatalogEntry(opts)
  local fromSkill = FamilyFromKind(KindOf(opts, e))
  -- Objectif, palier, recette, rang maître : famille métier, sauf si la compétence
  -- est clairement une arme ou le niveau.
  if kind == "rank-trainer" or kind == "rankup" or kind == "craft" or kind == "pretier"
    or kind == "prepalier" or kind == "recipe" or kind == "scanner" or kind == "palier"
    or kind == "tier" or kind == "goal" or kind == "objectif" then
    if fromSkill == "level" or fromSkill == "weapon" then return fromSkill end
    return "prof"
  end
  if fromSkill then return fromSkill end
  if kind == "skill" and e then return FamilyFromKind(e.kind) or "prof" end
  return nil
end

function UI.ProfessionToastIcon(opts)
  opts = opts or {}
  local e, id, name = UI.CatalogEntry(opts)
  if e and e.icon and not IsMissingToastIcon(e.icon) and not IsXpVialIcon(e.icon) then return e.icon end
  if name and UI.SkillDropIcon then
    local ic = UI.SkillDropIcon(UI, name, opts.header, opts.skillLine)
    if ic and not IsMissingToastIcon(ic) and not IsXpVialIcon(ic) then return ic end
  end
  if (name or id) and ns.ResolveSkillIcon then
    local ic = ns.ResolveSkillIcon(name or id, opts.header, opts.skillLine)
    if ic and not IsMissingToastIcon(ic) and not IsXpVialIcon(ic) then return ic end
  end
  return nil
end

function UI.ResolveToastIcon(path, opts)
  opts = opts or {}
  local fam = UI.ToastFamily(opts)
  -- Toasts XP / niveau : garder l'icône goutte XP, jamais le fallback vide.
  if fam == "level" then
    if IsXpVialIcon(path) then return path end
    if not IsMissingToastIcon(path) then return path end
    return ns.LEVEL_ICON or ns.FALLBACK_ICON
  end
  -- Recettes / métiers : toujours l'icône du métier (ex. Trade_LeatherWorking),
  -- jamais l'icône d'objet (sac, rouleau de cuir, composant).
  if fam == "prof" then
    local prof = UI.ProfessionToastIcon(opts)
    if prof then return prof end
    if not IsMissingToastIcon(path) and not IsXpVialIcon(path) then return path end
    return ns.FALLBACK_ICON
  end
  -- Autres familles : remplacer le fallback ou une goutte XP par l'icône du métier si on en a une.
  if not IsMissingToastIcon(path) and not IsXpVialIcon(path) then return path end
  local prof = UI.ProfessionToastIcon(opts)
  if prof then return prof end
  return ns.FALLBACK_ICON
end

function UI.EnsureToastFill(frame)
  if not frame then return nil end
  local host = frame._skinHost or frame
  if frame._tintFill then return frame._tintFill end
  if not (host and host.CreateTexture) then return frame._toastBg end
  local ok, fill = pcall(host.CreateTexture, host, nil, "BACKGROUND")
  if not (ok and fill) then return frame._toastBg end
  if fill.SetDrawLayer then pcall(fill.SetDrawLayer, fill, "BACKGROUND", 1) end
  local inset = (ns.Skin and ns.Skin.INSET) or 3
  if fill.ClearAllPoints then fill:ClearAllPoints() end
  if fill.SetPoint then
    fill:SetPoint("TOPLEFT", host, "TOPLEFT", inset, -inset)
    fill:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -inset, inset)
  end
  frame._tintFill = fill
  return fill
end

-- Alpha du calque de fond / teinte / bord (Fond des toasts). 0 = invisible.
-- Jamais l'opacité du panneau, jamais un RVB multiplié.
function UI.ToastBgAlpha(frame)
  local a = UI.DropBgAlpha and UI:DropBgAlpha()
  if a == nil then a = 0.68 end
  if a > 1 then a = math.min(1, a / 100) end
  a = math.max(0, math.min(1, a))
  if frame then frame._bgAlpha = a end
  return a
end

-- Pose l'opacité sur les calques (SetAlpha), pas sur le RVB.
-- Avec habillage, le host porte fond + teinte + bord : un seul SetAlpha.
-- Sans host, chaque texture de fond/bord est réglée séparément.
-- L'icône et le texte (enfants du cadre toast, hors host) restent à 1.
function UI.ApplyToastLayerAlpha(frame, a)
  if not frame then return nil end
  if a == nil then a = UI.ToastBgAlpha(frame) end
  a = ns.N(a)
  if a == nil then a = 0.68 end
  if a > 1 then a = math.min(1, a / 100) end
  a = math.max(0, math.min(1, a))
  frame._bgAlpha = a
  local function layer(t, aa)
    if t and t.SetAlpha then pcall(t.SetAlpha, t, aa) end
  end
  local host = frame._skinHost
  if host and host.SetAlpha then
    pcall(host.SetAlpha, host, a)
    layer(frame._tintFill, 1)
    layer(frame._toastBg, 1)
  else
    layer(frame._toastBg, a)
    layer(frame._tintFill, a)
    if frame._chatPieces then
      for _, t in pairs(frame._chatPieces) do layer(t, a) end
    end
    local chrome = frame._tipChrome
    if type(chrome) == "table" then
      if chrome.SetAlpha and chrome ~= frame then pcall(chrome.SetAlpha, chrome, a) end
      if type(chrome.border) == "table" then
        for _, t in pairs(chrome.border) do layer(t, a) end
      end
      if chrome.center then layer(chrome.center, a) end
      if type(chrome.pieces) == "table" then
        for _, t in pairs(chrome.pieces) do layer(t, a) end
      end
    end
    if frame.SetBackdropBorderColor then
      -- le cadre toast lui-même ne doit pas porter un fond noir opaque
    end
  end
  return a
end

function UI.RefreshToastOpacity()
  local list = {}
  for _, f in ipairs(UI.dropsActive or {}) do list[#list + 1] = f end
  for _, f in ipairs(UI._toastPool or {}) do list[#list + 1] = f end
  for i = 1, #list do
    local f = list[i]
    if f then
      f._tintA = nil
      if f._tintFill then f._tintFill._bgAlpha = nil end
      if ns.Chrome and ns.Chrome.Toast then pcall(ns.Chrome.Toast, f) end
      if UI.ApplyToastTint then pcall(UI.ApplyToastTint, f, f._tintOpts or {}) end
      if UI.ApplyToastLayerAlpha then pcall(UI.ApplyToastLayerAlpha, f) end
    end
  end
end

function UI.ApplyToastTint(frame, opts)
  if not frame then return nil end
  if opts then frame._tintOpts = opts end
  opts = opts or frame._tintOpts or {}
  local fam = UI.ToastFamily(opts)
  frame._tintFamily = fam
  local c = (UI.ToastTintColor and UI.ToastTintColor(opts)) or (fam and UI.TOAST_TINT[fam])
  local fill = UI.EnsureToastFill(frame)
  if not c then
    if frame._tintFill and frame._tintFill.Hide then frame._tintFill:Hide() end
    return fam
  end
  -- RVB de teinte constant (composante vertex 1). L'opacité est un SetAlpha
  -- de calque (host ou textures), pour que 0 % soit transparent, pas noir.
  local a = UI.ToastBgAlpha(frame)
  if fill and frame._tintR == c[1] and frame._tintG == c[2] and frame._tintB == c[3]
    and frame._tintA == a and frame._tintFamily == fam and fill._bgAlpha == a then
    if fill.Show then fill:Show() end
    if UI.ApplyToastLayerAlpha then UI.ApplyToastLayerAlpha(frame, a) end
    return fam
  end
  if fill then
    FillTexture(fill, c[1], c[2], c[3], 1)
    fill._bgAlpha = a
    if fill.Show then fill:Show() end
  end
  frame._tintR, frame._tintG, frame._tintB, frame._tintA = c[1], c[2], c[3], a
  -- L'habillage Skin recouvre _toastBg : le calque _tintFill est sur le host.
  if frame._toastBg and frame._toastBg ~= fill then
    if frame._skinHost then
      if frame._toastBg.Hide then frame._toastBg:Hide() end
    else
      FillTexture(frame._toastBg, c[1], c[2], c[3], 1)
      if frame._toastBg.Show then frame._toastBg:Show() end
    end
  end
  if UI.ApplyToastLayerAlpha then UI.ApplyToastLayerAlpha(frame, a) end
  return fam
end

local DROP_VARIANTS = {
  gold = { border = { 1.00, 0.82, 0.10, 1 }, title = { 1.00, 0.86, 0.20 } },
  palier = { border = { 1.00, 0.55, 0.15, 1 }, title = { 1.00, 0.62, 0.20 } },
}

-- v2.8.1 : finition du drop = composant de référence (STYLEGUIDE.md). Bord
-- seul (noBg) pour les encadrés qui gardent le dégradé brun clair Métiers.
function UI:ApplyDropFinish(frame, noBg)
  if type(frame) ~= "table" or not frame.CreateTexture then return nil end
  local ok, r = pcall(ApplyRestToastChrome, frame, nil, noBg)
  frame._dropFinish = ok and (noBg and "bord" or "fond+bord") or nil
  return ok and r or nil
end

function UI:WireDropMouse(f)
  if not f or not f.SetScript then return end
  if f.EnableMouse then pcall(f.EnableMouse, f, not self._inEditMode) end
  f:SetScript("OnEnter", function(self)
    self._hover = true
    ToastAlpha(self, 1)
    if ns.ToastFit and ns.ToastFit.ShowTooltip then pcall(ns.ToastFit.ShowTooltip, self) end
  end)
  f:SetScript("OnLeave", function(self)
    self._hover = false
    if ns.ToastFit and ns.ToastFit.HideTooltip then pcall(ns.ToastFit.HideTooltip, self) end
  end)
  f:SetScript("OnMouseUp", function(self, button)
    -- mode édition / déplacement : jamais d'ouverture (le clic sert au glisser)
    if self._dragged then self._dragged = nil return end
    if UI._inEditMode or self._editPreview then return end
    local df = UI.dropsFrame
    if df and (df._osrsMoving or df._osrsEditMoving) then return end
    -- sticky (astuce premier vol) : tout clic ferme le toast, sans ouvrir une tuile.
    if button == "RightButton" or self._sticky then UI:DismissDrop(self)
    elseif self._kind == "recap" or self._dedupeKey == "osrs-logout-recap" then
      if ns.ProgressUI and ns.ProgressUI.OpenRecap then pcall(ns.ProgressUI.OpenRecap, "current") end
      UI:DismissDrop(self)
    else
      local shift = (type(_G.IsShiftKeyDown) == "function" and _G.IsShiftKeyDown())
        or (type(_G.IsModifiedClick) == "function" and _G.IsModifiedClick("CHATLINK"))
      -- 3.8.2 : toast d'objet (chasse, butin rare) : clic = fiche de l'objet. Géré ici et non par un
      -- SetScript à part : les toasts sont recyclés et ce gestionnaire est reposé à chaque affichage.
      local ic = self._itemClick
      local now = (type(GetTime) == "function" and GetTime()) or 0
      local wc = self._whisperClick   -- 3.11.1 : rappel de sortie : clic = chuchoter à l'organisateur
      if wc and wc.org and button == "LeftButton" and now <= (wc.till or 0) and not shift then
        if ns.Hunt and ns.Hunt.OpenWhisper then pcall(ns.Hunt.OpenWhisper, wc.org) end
        UI:DismissDrop(self)
      elseif ic and ic.id and button == "LeftButton" and now <= (ic.till or 0) and not shift then
        local name = tostring((ns.Hunt and ns.Hunt.DisplayName and ns.Hunt.DisplayName(ic.id, ic.nm)) or ic.nm or ic.id)
        local link = "|Hitem:" .. ic.id .. "::::::::::::|h[" .. name .. "]|h"
        if type(_G.SetItemRef) == "function" then pcall(_G.SetItemRef, "item:" .. ic.id, link, "LeftButton") end
      elseif shift and ic and ic.id then
        local ok, _, lk = pcall(_G.GetItemInfo, ic.id)
        local link = (ok and lk) or ("item:" .. tostring(ic.id))
        if type(_G.ChatEdit_InsertLink) == "function" then pcall(_G.ChatEdit_InsertLink, link) end
      elseif shift and self._craft and self._craft.item then
        local link
        if type(_G.GetItemInfo) == "function" then
          local ok, results = pcall(function()
            local n, lk = _G.GetItemInfo(self._craft.item)
            return { n, lk }
          end)
          if ok and results then link = results[2] end
        end
        if not link and self._craft.item then
          link = "item:" .. tostring(self._craft.item)
        end
        if link and type(_G.ChatEdit_InsertLink) == "function" then
          pcall(_G.ChatEdit_InsertLink, link)
        elseif link and _G.ChatFrame1EditBox and _G.ChatFrame1EditBox.Insert then
          pcall(_G.ChatFrame1EditBox.Insert, _G.ChatFrame1EditBox, link)
        end
      else
        UI:OpenFromDrop(self._target, self)
      end
    end
  end)
  -- 3.0.0 : le glisser sur un drop déplace le SUPPORT (mode édition ou
  -- /drop drops move) — le drop ne vole plus le glisser au support.
  if f.RegisterForDrag then pcall(f.RegisterForDrag, f, "LeftButton") end
  f:SetScript("OnDragStart", function(self)
    local df = UI.dropsFrame
    if df and (df._osrsMoving or df._osrsEditMoving or UI._inEditMode) and df.StartMoving then
      self._dragged = true
      pcall(df.StartMoving, df)
      df._osrsDragging = true
    end
  end)
  f:SetScript("OnDragStop", function(self)
    local df = UI.dropsFrame
    if df and df._osrsDragging then
      df._osrsDragging = nil
      local h = df.GetScript and df:GetScript("OnDragStop")
      if h then h(df) end
    end
  end)
  -- état final de la souris posé APRÈS les SetScript
  if f.EnableMouse then pcall(f.EnableMouse, f, (not self._inEditMode) or f._editPreview or false) end
end

function UI:DismissDrop(f)
  if not f then return end
  if f._inPool then return end
  if ns.ToastFit and ns.ToastFit.HideTooltip then pcall(ns.ToastFit.HideTooltip, f) end
  if f.SetScript then pcall(f.SetScript, f, "OnUpdate", nil) end
  f._hover = false
  if f.Hide then pcall(f.Hide, f) end
  for i = #(self.dropsActive or {}), 1, -1 do
    if self.dropsActive[i] == f then table.remove(self.dropsActive, i) end
  end
  self:PackDrops()
  self.dismissed = (self.dismissed or 0) + 1
  self:ReleaseToast(f)
end

-- Tuile visée par un drop : XP / niveau → Niveau ; montée de niveau → Niveau
-- total ; arme → tuile de combat ; métier → sa tuile.
function UI:DropTargetData(target)
  target = target or {}
  if target.kind == "levelup" then return UI.TOTAL_DATA end
  local snap = self.snapshot
  if not snap then local ok, s2 = pcall(ns.Collect) snap = ok and s2 or nil self.snapshot = snap end
  local tiles = snap and snap.tiles or {}
  if target.kind == "xp" then
    for _, d in ipairs(tiles) do if d.kind == "level" then return d end end
  end
  local id = target.skillId
  if id then
    for _, d in ipairs(tiles) do if d.id == id and not d.placeholder then return d end end
    local e = ns.CatalogById and ns.CatalogById(id)
    local nm = e and e.name
    for _, d in ipairs(tiles) do if d.combatTile and nm and (d.catName == nm or d.skillName == ns.CatalogDisplayName(e)) then return d end end
    for _, d in ipairs(tiles) do if d.id == id then return d end end
  end
  return nil
end

function UI:OpenFromDrop(target, drop)
  if ns.InCombat and ns.InCombat() then
    ns.AfterCombat("openfromdrop", function() UI:OpenFromDrop(target) end)
    ns.Print(Tr["en combat : la fenêtre s'ouvrira à la fin du combat."])
    return "queued"
  end
  if self._openingFromDrop then return "busy" end
  self._openingFromDrop = true
  -- v2.8.4 : la vue OSRS est forcée, le drop cliqué se ferme (son OnUpdate
  -- de fondu s'arrête) et la tuile est choisie APRÈS l'ouverture.
  if not ns.db then initDBSafe() end
  ns.db.ui = ns.db.ui or {}
  ns.db.ui.osrsView = true
  if drop then SafeStep("fermer le drop", self.DismissDrop, self, drop) end
  local d
  local function selectIt()
    d = UI:DropTargetData(target)
    if d and UI.embed and UI.embed:IsShown() then SafeStep("sélection depuis un drop", UI.SelectTile, UI, d) end
    UI.lastDropOpen = d and (d.name or d.id) or "?"
  end
  local ok, opened = pcall(self.OpenSkillTab, self, selectIt)
  self._openingFromDrop = nil
  if not ok then SafeStep("ouverture depuis un drop", error, opened) return "error" end
  if opened == "waiting" then return "waiting" end
  return opened and "opened" or "none", d
end

-- Cadres de l'addon dont un OnUpdate tourne encore (doit être vide au repos).
function UI:ActiveOnUpdates()
  local out = {}
  local function chk(f, label)
    if type(f) == "table" and f.GetScript then
      local ok, s = pcall(f.GetScript, f, "OnUpdate")
      if ok and s then out[#out + 1] = label end
    end
  end
  for name, f in pairs(self.timers or {}) do chk(f, "minuterie " .. name) end
  for i, f in ipairs(self.dropsActive or {}) do if f:IsShown() then chk(f, "drop " .. i) end end
  chk(self._hitTicker, "hitdebug")
  return out
end

function UI:SetDropsMouse(on)
  for _, f in ipairs(self.dropsActive or {}) do
    if not f._editPreview and f.EnableMouse then pcall(f.EnableMouse, f, on and true or false) end
  end
end

-- Petite impulsion d'échelle sur le titre quand un drop cumule (AnimationGroup,
-- seulement pendant l'animation ; repli silencieux si l'API manque).
function UI:BumpDropTitle(f)
  local fs = f and f.titleFS
  if not fs or not fs.CreateAnimationGroup then f._bumps = (f._bumps or 0) + 1 return end
  if not f._bumpAG then
    local okA, ag = pcall(fs.CreateAnimationGroup, fs)
    if okA and ag then
      local okS, sc = pcall(ag.CreateAnimation, ag, "Scale")
      if okS and sc then
        if sc.SetScale then pcall(sc.SetScale, sc, 1.12, 1.12) end
        if sc.SetScaleFrom then pcall(sc.SetScaleFrom, sc, 1, 1) pcall(sc.SetScaleTo, sc, 1.12, 1.12) end
        if sc.SetDuration then pcall(sc.SetDuration, sc, 0.12) end
        if sc.SetOrigin then pcall(sc.SetOrigin, sc, "LEFT", 0, 0) end
      end
      if ag.SetLooping then pcall(ag.SetLooping, ag, "BOUNCE") end
      f._bumpAG = ag
    end
  end
  local ag = f._bumpAG
  if ag then
    pcall(ag.Stop, ag)
    if ag.SetLooping then pcall(ag.SetLooping, ag, "NONE") end
    pcall(ag.Play, ag)
  end
  f._bumps = (f._bumps or 0) + 1
end

local function StripStrayTimes(s)
  if type(s) ~= "string" or s == "" then return s end
  local prefix, rest = "", s
  local code = s:match("^(|c%x%x%x%x%x%x%x%x)")
  if code then
    prefix, rest = code, s:sub(1 + #code)
  end
  rest = rest:gsub("^%s*×%s*", "", 1)
  return prefix .. rest
end

-- 3.6.3 : les toasts sont recyclés. Chaque SpawnDrop créait un Frame (slot,
-- textures, FontStrings, barre) que Hide ne libère jamais : en quelques
-- minutes de jeu (toasts d'XP / de compétence) la mémoire grimpait de
-- ~20 Mo à plus de 80 Mo. Le vivier plafonne au pic simultané (~5).
UI._toastPool = UI._toastPool or {}
UI._toastCreated = UI._toastCreated or 0
UI.TOAST_POOL_MAX = 8

function UI:AcquireToast(parent)
  local pool = self._toastPool
  local f
  while pool and #pool > 0 do
    f = table.remove(pool)
    if f then
      f._inPool = nil
      if f.SetParent and parent then pcall(f.SetParent, f, parent) end
      f._tfBaseH, f._h, f.font = nil, nil, nil
      f._tintR, f._tintG, f._tintB, f._tintA, f._tintFamily = nil, nil, nil, nil, nil
      if ns.ToastFit and ns.ToastFit.Reset then pcall(ns.ToastFit.Reset, f) end
      return f, true
    end
  end
  f = TryCreate("Frame", nil, parent, "BackdropTemplate")
  if f then
    f._osrsToast = true
    self._toastCreated = (self._toastCreated or 0) + 1
  end
  return f, false
end

function UI:ReleaseToast(f)
  if not f or f._inPool then return end
  if not f._osrsToast and not f.iconSlot then return end
  if f.SetScript then pcall(f.SetScript, f, "OnUpdate", nil) end
  f._dedupeKey, f._acc, f._kills, f._quest = nil, nil, nil, nil
  f._sticky, f._hover, f._toastAge, f._editPreview = nil, nil, 0, nil
  f._toastData, f._target, f._kind, f._tintOpts = nil, nil, nil, nil
  f._tintR, f._tintG, f._tintB, f._tintA, f._tintFamily = nil, nil, nil, nil, nil
  f._fullTitle, f._fullSub, f._hold, f._light = nil, nil, nil, nil
  f._tfBaseH = nil
  if ns.ToastFit and ns.ToastFit.Reset then pcall(ns.ToastFit.Reset, f) end
  f._pileHidden, f._pileFade, f._osrsFly = nil, nil, nil
  if f.barHold and f.barHold.Hide then pcall(f.barHold.Hide, f.barHold) end
  if f.Hide then pcall(f.Hide, f) end
  f._inPool = true
  f._osrsToast = true
  self._toastPool = self._toastPool or {}
  -- Plafond : un pic de toasts ne doit pas rester dans le vivier pour toujours.
  if #self._toastPool >= (self.TOAST_POOL_MAX or 8) then return end
  self._toastPool[#self._toastPool + 1] = f
end

function UI.ToastRestart(frame)
  if not frame then return end
  if (frame._toastAge or 0) > TOAST_FADEIN then frame._toastAge = TOAST_FADEIN end
  ToastAlpha(frame, 1)
end

function UI.ToastDismissSoon(frame)
  if not frame then return end
  frame._hover = nil
  local h = frame._hold or UI:DropHold()
  local t = frame._toastAge or 0
  if t < TOAST_FADEIN + h then frame._toastAge = TOAST_FADEIN + h end
end

function UI.ToastOnUpdate(self, elapsed)
  if self._editPreview then
    ToastAlpha(self, 1)
    return
  end
  if self._pileHidden then
    ToastAlpha(self, 0)
    return
  end
  local t = self._toastAge or 0
  if self._hover then
    if t >= TOAST_FADEIN then ToastAlpha(self, 1)
    else ToastAlpha(self, math.min(1, t / TOAST_FADEIN)) end
    UI.ApplyToastPoint(self, UI.ToastSlideAmount(self))
    return
  end
  if self._sticky then
    if t < TOAST_FADEIN then
      t = t + (elapsed or 0.03)
      self._toastAge = t
      ToastAlpha(self, math.min(1, t / TOAST_FADEIN))
    else
      ToastAlpha(self, 1)
    end
    UI.ApplyToastPoint(self, UI.ToastSlideAmount(self))
    return
  end
  t = t + (elapsed or 0.03)
  self._toastAge = t
  local holdT = self._hold or UI:DropHold()
  local a = 1
  if t < TOAST_FADEIN then
    a = t / TOAST_FADEIN
  elseif t < TOAST_FADEIN + holdT then
    a = 1
  elseif t < TOAST_FADEIN + holdT + TOAST_FADEOUT then
    a = 1 - ((t - TOAST_FADEIN - holdT) / TOAST_FADEOUT)
  else
    if UI.DismissDrop then UI:DismissDrop(self) end
    return
  end
  ToastAlpha(self, a)
  if not self._pileHidden then
    UI.ApplyToastPoint(self, UI.ToastSlideAmount(self))
  end
end

function UI:SpawnDrop(iconPath, title, subtitle, barCur, barMax, rightValue, opts)
  opts = opts or {}
  if type(title) == "string" then title = StripStrayTimes(title) end
  if type(subtitle) == "string" then subtitle = StripStrayTimes(subtitle) end
  if opts.hint and type(opts.hint) == "string" then opts.hint = StripStrayTimes(opts.hint) end
  local function blank(s)
    if s == nil then return true end
    s = tostring(s)
    return s:gsub("%s+", "") == ""
  end
  -- Jamais un toast icône seule : titre et corps vides = on n'affiche rien.
  if not self._inEditMode and not opts.force and blank(title) and blank(subtitle) and blank(opts.hint) then
    return nil
  end
  if ns.PausedForFlight and ns.PausedForFlight() and not self._inEditMode and not (opts and opts.force) then return end
  if not self:DropsEnabled() and not self._inEditMode and not (opts and opts.force) then return end
  self:BuildDrops()
  local parent = self.dropsStack or self.dropsFrame or UIParent
  if not parent then return end
  self.dropsActive = self.dropsActive or {}
  -- v2.8.1 : même compétence déjà affichée → on met ce drop à jour (pas d'empilement).
  if opts.dedupeKey then
    for i = 1, #self.dropsActive do
      local o = self.dropsActive[i]
      if o and o._dedupeKey == opts.dedupeKey and o._restart then
        -- v2.8.1 : drop cumulatif tant qu'il est visible (« Dagues +1 » → « +2 »).
        local acc = opts.accumulate
        if acc and type(acc.fmt) == "function" and ns.N(acc.delta) then
          o._acc = (o._acc or 0) + acc.delta
          o._kills = (o._kills or 0) + (acc.kills or 0)
          o._quest = o._quest or acc.quest
          title = acc.fmt(o._acc, o)
          if o._light and subtitle and subtitle ~= "" then title = title .. "  |cffffffff" .. subtitle .. "|r" end
        end
        if o.titleFS and title then o.titleFS:SetText(title) end
        o._fullTitle = title or o._fullTitle
        o._fullSub = subtitle or o._fullSub
        if opts.toastData then o._toastData = opts.toastData end
        if opts.sticky then o._sticky = true end
        self:BumpDropTitle(o)
        if o.subFS and subtitle then o.subFS:SetText(subtitle) end
        if o.hintFS and opts.hint then o.hintFS:SetText(opts.hint) end
        if o.barHold and o.bar and ns.N(barMax) and ns.N(barMax) > 0 then
          pcall(SetSkillBarProgress, o.barHold, o.bar, barCur, ns.N(barMax), o._bw, (UI.ToastMetrics and UI.ToastMetrics({}).barH) or 4)
        end
        o._restart()
        o._updates = (o._updates or 0) + 1
        o._tintOpts = opts
        o._kind = opts.kind or o._kind
        if UI.ApplyToastTint then UI.ApplyToastTint(o, opts) end
        return o
      end
    end
    -- Limite 1 / 2 s : si le drop a déjà disparu (plafond), on en recrée un seul.
  end
  -- Plafond : 5 drops visibles, le plus ancien part.
  local live = 0
  for i = 1, #self.dropsActive do if not self.dropsActive[i]._editPreview then live = live + 1 end end
  while live >= (UI.DROP_MAX or 5) do
    local idx
    for i = 1, #self.dropsActive do
      local o = self.dropsActive[i]
      if o and not o._editPreview and not o._sticky then idx = i break end
    end
    if not idx then break end
    local o = table.remove(self.dropsActive, idx)
    if o.SetScript then pcall(o.SetScript, o, "OnUpdate", nil) end
    if o.Hide then pcall(o.Hide, o) end
    live = live - 1
  end
  local variant = opts.variant and DROP_VARIANTS[opts.variant] or nil
  local maxv = ns.N(barMax)
  local hint = opts.hint

  -- Style « Léger » : une ligne compacte. S'il y a un titre ET un corps,
  -- on force le toast complet : la rangée 20–26 px coupait le texte
  -- (barre rouge vide, texte seulement en infobulle — « Nouveaux sorts »).
  local light = opts.light or (ns.db and ns.db.ui and ns.db.ui.dropStyle == "leger") or false
  if light and type(title) == "string" and title ~= "" and type(subtitle) == "string" and subtitle ~= "" then
    light = false
  end
  -- Complet : boîte compacte façon toast — icône 32 px à gauche, 3 lignes
  -- (titre or, ligne blanche, astuce verte) et fine barre en bas.
  local tm = UI.ToastMetrics and UI.ToastMetrics({
    light = light, hint = hint, maxv = maxv, big = opts.big,
  }) or nil
  local fh, iconSize, barH, pad
  if tm then
    fh, iconSize, barH, pad = tm.fh, tm.icon, tm.barH, tm.pad
  else
    if light then fh = TOAST_LIGHT_H
    else
      fh = 12 + 14 + 12 + ((hint and hint ~= "") and 11 or 0) + ((maxv and maxv > 0) and 7 or 0)
      if fh < 46 then fh = 46 end
      if opts.big then fh = math.max(fh, UI.LEVELUP_H) end
    end
    iconSize = light and 20 or (opts.big and 40 or 32)
    barH, pad = 4, 7
  end
  local dw = self:DropWidth()
  local f, reused = self:AcquireToast(parent)
  if not f then return end
  f._inPool = nil
  f:SetSize(dw, fh)
  f._h = fh
  f._tfBaseH = fh
  f._light = light and true or false
  f._variant = opts.variant
  f._kind = opts.kind
  if f.SetFrameStrata then pcall(f.SetFrameStrata, f, "HIGH") end
  ApplyRestToastChrome(f, variant and variant.border or nil)
  f._tintOpts = opts
  UI.ApplyToastTint(f, opts)

  -- Icône dans l'anneau rond : masque circulaire + retrait, jamais hors du cercle.
  -- Métiers : icône d'origine du jeu (pas la goutte de repli), sans cadre d'emplacement.
  local slot = f.iconSlot
  if not slot then
    slot = CreateSlotButton(f, iconSize, true)
    f.iconSlot, f.icon = slot, slot.iconTex
  else
    -- Vivier : recaler taille, anneau et points (un toast « big » recyclé
    -- en « Nouveaux sorts » léger débordait du cadre).
    if ResizeSlotButton then ResizeSlotButton(slot, iconSize) end
    if slot.ClearAllPoints then pcall(slot.ClearAllPoints, slot) end
  end
  if light then slot:SetPoint("LEFT", f, "LEFT", math.max(3, math.floor((pad or 7) * 0.6 + 0.5)), 0)
  else slot:SetPoint("TOPLEFT", f, "TOPLEFT", pad or 7, -(pad or 7)) end
  local resolved = UI.ResolveToastIcon and UI.ResolveToastIcon(iconPath, opts) or iconPath
  SetTileIcon(slot.iconTex, resolved or ns.LEVEL_ICON or ns.FALLBACK_ICON, slot)
  f.iconSlot, f.icon = slot, slot.iconTex or f.icon

  local titleFS = f.titleFS
  if not titleFS then
    titleFS = Text(f, "GameFontNormal", "LEFT")
  elseif titleFS.ClearAllPoints then
    titleFS:ClearAllPoints()
  end
  titleFS:SetPoint("TOPLEFT", slot, "TOPRIGHT", 7, 1)
  titleFS:SetPoint("RIGHT", f, "RIGHT", -8, 0)
  if titleFS.Show then titleFS:Show() end
  if titleFS.SetWordWrap then titleFS:SetWordWrap(false) end
  if type(titleFS.SetMaxLines) == "function" then pcall(titleFS.SetMaxLines, titleFS, 1) end
  titleFS:SetText(title or "")
  -- 3.8.2 : opts.titleColor (butin rare : couleur de la qualité) prime sur la variante
  local tc = (type(opts.titleColor) == "table" and opts.titleColor) or (variant and variant.title) or GOLD
  titleFS:SetTextColor(tc[1], tc[2], tc[3])
  -- Vivier : toujours remettre la police (un level-up laissait GameFontNormalLarge).
  do
    local font
    if opts.big and not light then
      font = _G.GameFontNormalLarge or "GameFontNormalLarge"
      titleFS.font = "GameFontNormalLarge"
    elseif light then
      font = _G.GameFontNormalSmall or "GameFontNormalSmall"
      titleFS.font = "GameFontNormalSmall"
    else
      font = _G.GameFontNormal or "GameFontNormal"
      titleFS.font = "GameFontNormal"
    end
    if titleFS.SetFontObject then pcall(titleFS.SetFontObject, titleFS, font) end
    if tm and ApplyToastFont then ApplyToastFont(titleFS, tm.titleSize, font) end
  end

  local subFS = f.subFS
  if not subFS then
    subFS = Text(f, "GameFontHighlightSmall", "LEFT")
  elseif subFS.ClearAllPoints then
    subFS:ClearAllPoints()
  end
  subFS:SetPoint("TOPLEFT", titleFS, "BOTTOMLEFT", 0, -2)
  subFS:SetPoint("RIGHT", f, "RIGHT", -8, 0)
  if subFS.Show then subFS:Show() end
  if subFS.SetWordWrap then subFS:SetWordWrap(false) end
  if type(subFS.SetMaxLines) == "function" then pcall(subFS.SetMaxLines, subFS, 1) end
  subFS:SetText(subtitle or "")
  subFS:SetTextColor(1, 1, 1)
  if tm and ApplyToastFont then ApplyToastFont(subFS, tm.subSize, "GameFontHighlightSmall") end

  local hintFS = f.hintFS
  if not hintFS then
    hintFS = Text(f, "GameFontHighlightSmall", "LEFT")
  elseif hintFS.ClearAllPoints then
    hintFS:ClearAllPoints()
  end
  hintFS:SetPoint("TOPLEFT", subFS, "BOTTOMLEFT", 0, -1)
  hintFS:SetPoint("RIGHT", f, "RIGHT", -8, 0)
  if hintFS.SetWordWrap then hintFS:SetWordWrap(false) end
  if type(hintFS.SetMaxLines) == "function" then pcall(hintFS.SetMaxLines, hintFS, 1) end
  hintFS:SetText(hint or "")
  hintFS:SetTextColor(0.25, 1.00, 0.25)
  if tm and ApplyToastFont then ApplyToastFont(hintFS, tm.subSize, "GameFontHighlightSmall") end
  if not hint or hint == "" then hintFS:Hide() end
  f.hintFS = hintFS

  if light then
    titleFS:ClearAllPoints()
    titleFS:SetPoint("LEFT", slot, "RIGHT", 6, 0)
    titleFS:SetPoint("RIGHT", f, "RIGHT", -6, 0)
    if titleFS.SetFontObject then pcall(titleFS.SetFontObject, titleFS, "GameFontNormalSmall") end
    titleFS.font = "GameFontNormalSmall"
    if tm and ApplyToastFont then ApplyToastFont(titleFS, tm.titleSize, "GameFontNormalSmall") end
    if subtitle and subtitle ~= "" then titleFS:SetText((title or "") .. "  |cffffffff" .. subtitle .. "|r") end
    subFS:SetText("")
    subFS:Hide()
    hintFS:Hide()
  end

  -- Fine barre en bas, alignée sur le texte : elle commence au bord gauche
  -- du titre (jamais sous l'icône ronde) et finit au même retrait droit.
  if maxv and maxv > 0 and not light then
    local hold, sbar = f.barHold, f.bar
    if not hold then
      hold = CreateFrame("Frame", nil, f)
      local okB, sb = pcall(CreateFrame, "StatusBar", nil, hold)
      sbar = (okB and sb) or CreateFrame("Frame", nil, hold)
    end
    if hold.ClearAllPoints then hold:ClearAllPoints() end
    hold:SetPoint("LEFT", titleFS, "LEFT", 0, 0)
    hold:SetPoint("RIGHT", titleFS, "RIGHT", 0, 0)
    hold:SetPoint("BOTTOM", f, "BOTTOM", 0, math.max(4, (pad or 7) - 1))
    if hold.Show then hold:Show() end
    local textRight = 8
    local bw = math.max(8, dw - ((pad or 7) + iconSize + (pad or 7)) - textRight)
    hold._styleSkill = opts.skillId
    SetSkillBarProgress(hold, sbar, barCur, maxv, bw, barH or 4)
    f._bw = bw
    if hold.nbBorder then hold.nbBorder:Hide() end
    if hold.barText then hold.barText:SetText("") hold.barText:Hide() end
    f.barHold, f.bar = hold, sbar
  elseif f.barHold and f.barHold.Hide then
    f.barHold:Hide()
  end
  f.titleFS, f.subFS = titleFS, subFS
  f._fullTitle, f._fullSub = title or "", subtitle or ""
  f._toastData = opts.toastData
  f._sticky = opts.sticky and true or nil
  f._kind = opts.kind

  self.dropsActive[#self.dropsActive + 1] = f
  self:PackDrops()
  ToastAlpha(f, 0)
  if f.Show then pcall(f.Show, f) end

  -- Aperçu d'édition : pas de fondu, on le garde visible.
  if f._editPreview then return f end

  f._toastAge, f._toastBorn = 0, (type(GetTime) == "function" and GetTime()) or 0
  f._dedupeKey = opts.dedupeKey
  f._acc = opts.accumulate and ns.N(opts.accumulate.delta) or nil
  f._kills = opts.accumulate and opts.accumulate.kills or nil
  f._quest = opts.accumulate and opts.accumulate.quest or nil
  f._target = { kind = opts.kind, skillId = opts.skillId, skillName = opts.skillName }
  f._itemClick = nil  -- cadre recyclé : jamais le lien d'objet d'un ancien toast
  f._whisperClick = nil
  if not f._restart then
    f._restart = function() UI.ToastRestart(f) end
  end
  if not f._dismiss then
    f._dismiss = function() UI.ToastDismissSoon(f) end
  end
  f._hold = ns.N(opts.hold)
  -- v2.8.1 : survol = drop tenu (minuterie en pause) ; sortie = durée complète
  -- relancée ; clic gauche = onglet Comp. sur la bonne tuile ; clic droit = fermer.
  -- Jamais en mode édition (le déplacement du support reste inchangé).
  self:WireDropMouse(f)
  f:SetScript("OnUpdate", UI.ToastOnUpdate)
  return f
end

-- v2.8.0 : animation de montée de niveau (complète la bannière officielle, ne
-- la cache jamais) : grand drop doré dans la pile des drops, lueur de bord qui
-- pulse et éclat doré qui s'estompe (AnimationGroup Alpha / Scale, textures
-- Media/Skin). Variante légère pour les rangs de métier.
UI.LEVELUP_H = 64
UI.LEVELUP_SOUNDS = { "UI_EPICLOOT_TOAST", "UI_LEGENDARY_LOOT_TOAST", "IG_QUEST_LIST_COMPLETE" }

function UI:LevelUpSoundKit()
  local S = _G.SOUNDKIT
  if type(S) ~= "table" then return nil end
  for _, k in ipairs(UI.LEVELUP_SOUNDS) do
    local v = ns.N(S[k])
    if v then return v, k end
  end
  return nil
end

local function NewAnim(target, kind)
  if not target or type(target.CreateAnimationGroup) ~= "function" then return nil end
  local ok, ag = pcall(target.CreateAnimationGroup, target)
  if not ok or not ag then return nil end
  return ag
end

local function AddAnim(ag, kind, props)
  if not ag or type(ag.CreateAnimation) ~= "function" then return nil end
  local ok, a = pcall(ag.CreateAnimation, ag, kind)
  if not ok or not a then return nil end
  for k, v in pairs(props) do
    local fn = a[k]
    if type(fn) == "function" then
      if type(v) == "table" then pcall(fn, a, unpack(v)) else pcall(fn, a, v) end
    end
  end
  return a
end

-- Effets sur un drop : lueur de bord (pulse ×2) + éclat doré (grossit, s'estompe).
function UI:AttachFlareFx(f, strong)
  if not f or not f.CreateTexture then return nil end
  if f._fx then
    local out = f._fx
    if out.glowAnim and out.glowAnim.Stop then pcall(out.glowAnim.Stop, out.glowAnim) end
    if out.burstAnim and out.burstAnim.Stop then pcall(out.burstAnim.Stop, out.burstAnim) end
    if out.fx then
      if out.fx.SetAlpha then pcall(out.fx.SetAlpha, out.fx, 0) end
      if out.fx.Show then pcall(out.fx.Show, out.fx) end
    end
    if out.glowAnim and out.glowAnim.Play then pcall(out.glowAnim.Play, out.glowAnim) end
    if strong and out.burst then
      if out.burst.Show then pcall(out.burst.Show, out.burst) end
      if out.burstAnim and out.burstAnim.Play then pcall(out.burstAnim.Play, out.burstAnim) end
    end
    if UI.ApplyToastTint then UI.ApplyToastTint(f, f._tintOpts or {}) end
    return out
  end
  local F = ns.Style.FLARE
  local fx = CreateFrame("Frame", nil, f)
  fx:SetAllPoints(f)
  if fx.SetFrameLevel and f.GetFrameLevel then pcall(fx.SetFrameLevel, fx, (f:GetFrameLevel() or 1) + 2) end
  ns.Style.Nine(fx, "glow", F.glow, 64, 64, 12, 12, "OVERLAY", 1, 10)
  for _, t in pairs(fx._flare.glow) do
    if type(t) == "table" and t.SetBlendMode then pcall(t.SetBlendMode, t, "ADD") end
  end
  fx:SetAlpha(0)
  local out = { fx = fx }
  local ag = NewAnim(fx)
  if ag then
    -- Pic à 0,55 : la lumière joue au-dessus du fond teinté, sans le masquer.
    AddAnim(ag, "Alpha", { SetFromAlpha = 0, SetToAlpha = 0.55, SetDuration = 0.35, SetOrder = 1 })
    AddAnim(ag, "Alpha", { SetFromAlpha = 0.55, SetToAlpha = 0.20, SetDuration = 0.45, SetOrder = 2 })
    AddAnim(ag, "Alpha", { SetFromAlpha = 0.20, SetToAlpha = 0.55, SetDuration = 0.35, SetOrder = 3 })
    AddAnim(ag, "Alpha", { SetFromAlpha = 0.55, SetToAlpha = 0, SetDuration = 0.8, SetOrder = 4 })
    pcall(ag.Play, ag)
    out.glowAnim = ag
  else
    fx:SetAlpha(1)
  end
  if strong and f.iconSlot then
    local bf = CreateFrame("Frame", nil, f)
    bf:SetSize(128, 128)
    bf:SetPoint("CENTER", f.iconSlot, "CENTER", 0, 0)
    if bf.SetFrameLevel and f.GetFrameLevel then pcall(bf.SetFrameLevel, bf, (f:GetFrameLevel() or 1) + 3) end
    local bt = bf:CreateTexture(nil, "OVERLAY")
    pcall(bt.SetTexture, bt, F.burst)
    bt.texPath = F.burst
    bt:SetAllPoints(bf)
    if bt.SetBlendMode then pcall(bt.SetBlendMode, bt, "ADD") end
    local bg = NewAnim(bf)
    if bg then
      local sc = AddAnim(bg, "Scale", { SetDuration = 1.2, SetOrder = 1 })
      if sc then
        if type(sc.SetScaleFrom) == "function" and type(sc.SetScaleTo) == "function" then
          pcall(sc.SetScaleFrom, sc, 0.5, 0.5) pcall(sc.SetScaleTo, sc, 1.4, 1.4)
        elseif type(sc.SetScale) == "function" then
          pcall(sc.SetScale, sc, 1.6, 1.6)
        end
      end
      AddAnim(bg, "Alpha", { SetFromAlpha = 0.95, SetToAlpha = 0, SetDuration = 1.2, SetOrder = 1 })
      if bg.SetScript then pcall(bg.SetScript, bg, "OnFinished", function() bf:Hide() end) end
      pcall(bg.Play, bg)
      out.burstAnim = bg
    else
      bf:Hide()
    end
    out.burst = bf
  end
  f._fx = out
  if UI.ApplyToastTint then UI.ApplyToastTint(f, f._tintOpts or {}) end
  return out
end

function UI:LevelTotalLine()
  local snap = self.snapshot
  local total = snap and ns.N(snap.total or snap.ficTotal)
  if total then return Tr["Niveau total : "] .. tostring(total + 1) .. " (+1)" end
  return Tr["Niveau total : +1"]
end

function UI:PlayLevelUp(level)
  level = ns.N(level) or ns.GetPlayerLevel()
  self._pendingLevelPulse = true
  if not ns.Opt("levelUpAnim") then return nil end
  local f = self:SpawnDrop(ns.LEVEL_ICON, Tr["Niveau "] .. tostring(level) .. Tr[" atteint !"], self:LevelTotalLine(), nil, nil, nil,
    { kind = "levelup", variant = "gold", big = true })
  if f then
    self:AttachFlareFx(f, true)
    if ns.SoundOk("levelUpSound") and type(PlaySound) == "function" then
      local kit = self:LevelUpSoundKit()
      if kit then pcall(PlaySound, kit) end
      self._lastLevelUpSound = kit or "aucun kit"
    end
  end
  if ns.Slot and ns.Slot.PlayLevelUp then pcall(ns.Slot.PlayLevelUp) end
  self:PulseLevelTile()
  -- 3.5.4 : niveaux pairs = nouveaux sorts chez le maître de classe (notif sous le level-up + son)
  if f and level and level >= 2 and level % 2 == 0 then
    local ui = self
    local function spellToast()
      local g = ui:SpawnDrop(ns.SPELLS_ICON, Tr["Nouveaux sorts"], Tr["Va voir ton maître de classe"], nil, nil, nil,
        { kind = "spells", variant = "gold" })
      if g and ns.SoundOk("levelUpSound") and type(PlaySound) == "function" then
        local kit = (type(SOUNDKIT) == "table" and SOUNDKIT.IG_QUEST_LOG_OPEN) or 844
        pcall(PlaySound, kit)
      end
    end
    if type(C_Timer) == "table" and C_Timer.After then C_Timer.After(1.5, spellToast) else spellToast() end
  end
  return f
end

-- Variante légère : nouveau rang apprenable / rang obtenu (métiers).
function UI:PlayRankMilestone(d, text, sub)
  if not ns.Opt("levelUpAnim") then return nil end
  local f = self:SpawnDrop(d and d.icon, text, sub, nil, nil, nil, { kind = "rankup", variant = "gold", light = true, skillId = d and d.id })
  if f then self:AttachFlareFx(f, false) end
  return f
end

-- Tuile Niveau : une pulsation dorée à la prochaine ouverture de l'onglet.
function UI:PulseLevelTile()
  if not self._pendingLevelPulse then return false end
  if not (self.embed and self.embed.IsShown and self.embed:IsShown()) then return false end
  local tile
  for _, t in ipairs((self.embed and self.embed.tiles) or {}) do if t.data and t.data.kind == "level" then tile = t break end end
  if not tile then return false end
  self._pendingLevelPulse = false
  local F = ns.Style.FLARE
  if not tile._pulse then
    local pf = CreateFrame("Frame", nil, tile)
    pf:SetAllPoints(tile)
    ns.Style.Nine(pf, "glow", F.glow, 64, 64, 12, 10, "OVERLAY", 2, 4)
    for _, t in pairs(pf._flare.glow) do if type(t) == "table" and t.SetBlendMode then pcall(t.SetBlendMode, t, "ADD") end end
    pf:SetAlpha(0)
    local ag = NewAnim(pf)
    if ag then
      AddAnim(ag, "Alpha", { SetFromAlpha = 0, SetToAlpha = 1, SetDuration = 0.4, SetOrder = 1 })
      AddAnim(ag, "Alpha", { SetFromAlpha = 1, SetToAlpha = 0, SetDuration = 0.9, SetOrder = 2 })
    end
    tile._pulse = { frame = pf, anim = ag }
  end
  local p = tile._pulse
  if p.anim then pcall(p.anim.Stop, p.anim) pcall(p.anim.Play, p.anim) end
  tile._pulseCount = (tile._pulseCount or 0) + 1
  return true
end

-- v2.8.1 : XP cumulée sur un seul drop tant qu'il est visible :
-- « +40 XP » → « +125 XP (3 monstres) » ; XP de quête : « (quête) ».
function UI.XPTitle(n, o)
  local k = o and o._kills or 0
  local parts = {}
  if k >= 2 then parts[#parts + 1] = tostring(k) .. Tr[" monstres"] end
  if o and o._quest then parts[#parts + 1] = Tr["quête"] end
  return "+" .. tostring(n) .. " XP" .. ((#parts > 0) and (" (" .. table.concat(parts, ", ") .. ")") or "")
end

local function Deformat(fmt)
  if type(fmt) ~= "string" then return nil end
  local p = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", ".-"):gsub("%%%%d", "%%d+")
  return "^" .. p
end
-- Source de la prochaine hausse d'XP : message de combat (monstre tué) ou
-- message système (quête, exploration). Valable 2 s.
function UI:NoteXPMessage(event, msg)
  if type(msg) ~= "string" or (ns.IsSecret and ns.IsSecret(msg)) then return end
  local kind
  if event == "CHAT_MSG_COMBAT_XP_GAIN" then
    local kp = Deformat(_G.COMBATLOG_XPGAIN_FIRSTPERSON) or Deformat(_G.COMBATLOG_XPGAIN_FIRSTPERSON_GROUP)
    if kp and msg:find(kp) then kind = "kill"
    elseif msg:find("meurt") or msg:find("dies") then kind = "kill"
    else kind = "other" end
  elseif event == "CHAT_MSG_SYSTEM" then
    local qp = Deformat(_G.ERR_QUEST_REWARD_EXP_I)
    if (qp and msg:find(qp)) or msg:find("Expérience gagnée") or msg:find("Experience gained") then kind = "quest" end
  end
  if kind then
    local now = (type(GetTime) == "function" and GetTime()) or 0
    -- Quête arrivée juste après la hausse (pas de toast monstre) : poser le toast quête.
    local pend = self._pendingXPToast
    if kind == "quest" and pend and now - (pend.at or 0) <= 2 then
      self._pendingXPToast = nil
      self._xpSrc = { kind = "quest", at = now }
      if ns.Opt("xpDrops") then
        self:SpawnQuestXPToast(pend.delta, pend.cur, pend.maxxp, pend.level, pend.hint)
      end
      return
    end
    if kind == "kill" then
      self._pendingXPToast = nil
    end
    self._xpSrc = { kind = kind, at = now }
  end
end
function UI:TakeXPSource()
  local s = self._xpSrc
  self._xpSrc = nil
  if not s then return nil end
  local now = (type(GetTime) == "function" and GetTime()) or 0
  if now - (s.at or 0) > 2 then return nil end
  return s.kind
end

UI.XP_MILESTONES = { 25, 50, 75 }

function UI.XPMilestoneTitle(level, th)
  return string.format(Tr["Niveau %s · %d %%"], tostring(level or 0), th)
end

function UI:XPMarksFor(level)
  local c = ns.CharDB and ns.CharDB()
  if not c then
    self._xpMarksMem = self._xpMarksMem or {}
    local key = tostring(level or 0)
    self._xpMarksMem[key] = self._xpMarksMem[key] or {}
    return self._xpMarksMem[key]
  end
  c.xpMarks = c.xpMarks or {}
  local key = tostring(level or 0)
  if type(c.xpMarks[key]) ~= "table" then c.xpMarks[key] = {} end
  return c.xpMarks[key]
end

function UI:MarkXPMilestone(rec, th)
  rec[th] = true
  rec[tostring(th)] = true
end

function UI:HasXPMilestone(rec, th)
  return rec and (rec[th] or rec[tostring(th)]) and true or false
end

-- Au login : mémoriser les jalons déjà atteints, sans toast rétroactif.
function UI:SeedXPMilestones(cur, maxxp, level)
  cur, maxxp, level = ns.N(cur), ns.N(maxxp), ns.N(level)
  if not level or not maxxp or maxxp <= 0 then
    self._xpMarksSeeded = true
    return
  end
  local rec = self:XPMarksFor(level)
  local p = cur / maxxp
  for _, th in ipairs(UI.XP_MILESTONES) do
    if p >= (th / 100) then self:MarkXPMilestone(rec, th) end
  end
  self._xpMarksSeeded = true
end

function UI:MaybeXPMilestone(cur, maxxp, level)
  if not ns.Opt("xpDrops") then return end
  cur, maxxp, level = ns.N(cur), ns.N(maxxp), ns.N(level)
  if not level or not maxxp or maxxp <= 0 then return end
  if not self._xpMarksSeeded then
    self:SeedXPMilestones(cur, maxxp, level)
    return
  end
  local rec = self:XPMarksFor(level)
  local p = cur / maxxp
  local book = ns.LEVEL_ICON or "Interface\\Icons\\INV_Misc_Book_11"
  for _, th in ipairs(UI.XP_MILESTONES) do
    if p >= (th / 100) and not self:HasXPMilestone(rec, th) then
      self:MarkXPMilestone(rec, th)
      self:SpawnDrop(book, UI.XPMilestoneTitle(level, th), nil, nil, nil, nil, {
        kind = "xp-milestone", dedupeKey = "xp-m-" .. tostring(level) .. "-" .. tostring(th),
      })
    end
  end
end

function UI:SpawnQuestXPToast(delta, cur, maxxp, level, hint)
  local book = ns.LEVEL_ICON or "Interface\\Icons\\INV_Misc_Book_11"
  maxxp = ns.N(maxxp) or 0
  cur = ns.N(cur) or 0
  local pct = (maxxp > 0) and (cur / maxxp * 100) or 0
  local sub = string.format(Tr["Niveau %s · %.0f %%"], tostring(level or 0), pct)
  -- Un toast par remise de quête (pas de fusion avec un autre gain).
  return self:SpawnDrop(book, UI.XPTitle(delta, { _kills = 0, _quest = true }), sub, cur, maxxp, nil, {
    kind = "xp", hint = hint,
  })
end

function UI:OnXPUpdate()
  local cur, maxxp = ns.GetPlayerXPSafe()
  local level = ns.GetPlayerLevel()
  -- Valeurs secrètes (combat) : on attend la prochaine lecture lisible.
  if not cur or not maxxp then return end
  if not self._xpSeeded then
    self._prevXP, self._prevXPMax, self._prevLevel = cur, maxxp, level
    self._xpSeeded = true
    self:SeedXPMilestones(cur, maxxp, level)
    return
  end
  local delta = cur - (self._prevXP or 0)
  if delta < 0 then
    delta = ((self._prevXPMax or 0) - (self._prevXP or 0)) + cur
  end
  self._prevXP, self._prevXPMax, self._prevLevel = cur, maxxp, level
  if delta > 0 then
    self._sessionXP = (self._sessionXP or 0) + delta
    ns.Rate.Note("xp", self._sessionXP)
    local hint = self:XPHint(cur, maxxp, level)
    if ns.Opt("xpDrops") then
      local src = self:TakeXPSource()
      if src == "quest" then
        self._pendingXPToast = nil
        self:SpawnQuestXPToast(delta, cur, maxxp, level, hint)
        -- +1 et étincelle à l'arrivée du toast (Compact.Land)
      elseif src == "kill" or src == "other" then
        -- Monstre (et exploration) : pas de toast ; +1 rouge sur la case Niveau + étincelle.
        self._pendingXPToast = nil
        if ns.Compact and ns.Compact.Announce then
          pcall(ns.Compact.Announce, { kind = "xp", accumulate = { delta = delta } },
            { { key = "level", gain = delta, suffix = "" } })
        elseif ns.Slot and ns.Slot.PlayBarSpark then
          pcall(ns.Slot.PlayBarSpark, "red")
        end
      else
        -- Source encore inconnue : on attend un message de quête (2 s), sans toast monstre.
        self._pendingXPToast = {
          delta = delta, cur = cur, maxxp = maxxp, level = level, hint = hint,
          at = (type(GetTime) == "function" and GetTime()) or 0,
        }
      end
    end
    -- Les jalons peuvent tomber sur un gain de quête ou de monstre.
    self:MaybeXPMilestone(cur, maxxp, level)
  end
end

-- v2.8.1 : anti-déluge. Un drop de compétence ne part QUE si le rang monte par
-- rapport à une valeur déjà connue (cache persistant fusionné dans la lecture) ;
-- première apparition / réapparition = amorçage silencieux ; jamais « +rang
-- complet » ; plus de 3 compétences nouvelles ou en hausse d'un coup = relecture
-- (silence) ; 1 drop max par compétence toutes les 2 s (sinon mise à jour du
-- drop visible) ; 5 drops visibles au plus.
UI.DROP_MAX = 5
UI.DROP_RATE = 2
UI.RESEED_BURST = 3
local function Now()
  if type(GetTime) == "function" then local ok, v = pcall(GetTime) if ok and ns.N(v) then return v end end
  return (type(time) == "function" and time()) or 0
end
function UI:FlushSkillDiff()
  self._skillDiffPending = false
  if ns.InCombat and ns.InCombat() then
    self._skillDiffAfterCombat = true
    self.dirty = true
    return
  end
  if not ns.SkillRankSnapshot then return end
  -- 3.5.21 : on compare aussi en combat (rangs lisibles). Si des rangs
  -- restent secrets, MergeRankCache / la garde « rang 0 » conservent la
  -- dernière valeur ; un second passage a lieu à PLAYER_REGEN_ENABLED.
  if ns.InCombat and ns.InCombat() then self.dirty = true self._skillDiffAfterCombat = true end
  local now = ns.SkillRankSnapshot()
  -- Rang illisible (0 / nil) : on garde la dernière valeur connue.
  if self._prevSkills then
    for fold, s in pairs(now) do
      local p = self._prevSkills[fold]
      if (ns.N(s.rank) or 0) <= 0 and p and (ns.N(p.rank) or 0) > 0 then now[fold] = p end
    end
  end
  local prev = self._prevSkills
  if not self._skillSeeded or not prev then
    self._prevSkills = now
    self._skillSeeded = true
    return
  end
  local rises, fresh = {}, 0
  for fold, s in pairs(now) do
    local p = prev[fold]
    local cr = ns.N(s.rank) or 0
    if not p then
      fresh = fresh + 1
    else
      local pr = ns.N(p.rank)
      if pr and pr > 0 and cr > pr then rises[#rises + 1] = { fold = fold, s = s, pr = pr, cr = cr } end
    end
  end
  -- Une compétence absente de cette lecture garde sa valeur précédente.
  for fold, p in pairs(prev) do
    if not now[fold] then now[fold] = p end
  end
  self._prevSkills = now
  if fresh > UI.RESEED_BURST or #rises > UI.RESEED_BURST then
    self._reseeds = (self._reseeds or 0) + 1
    rises = {}
  end
  -- Après un changement de zone / repos : on met à jour la base, on ne toaste pas
  -- (une lecture partielle ferait croire à un +1 de métier).
  local quiet = self._skillQuietUntil and Now() < self._skillQuietUntil
  if quiet or ((not rises[1]) and fresh == 0) then
    if quiet then rises = {} end
    if not rises[1] then
      -- pas de palier réel : on n'appelle pas Collect (gros paquet de tables).
      return
    end
  end
  self._dropLast = self._dropLast or {}
  local t = Now()
  for _, r in ipairs(rises) do
    local s, pr, cr, fold = r.s, r.pr, r.cr, r.fold
    local d = cr - pr
    if d > 0 and d < cr then
      local icon, skillId = self:SkillDropIcon(s.name, s.headerName, s.skillID)
      local catEarly = ns.LookupCatalog and ns.LookupCatalog(s.name)
      local isWeapon = ns.IsWeaponSkill and ns.IsWeaponSkill(skillId or (catEarly and catEarly.id), catEarly and catEarly.kind, s.name)
      ns.Rate.Note("skill:" .. tostring(skillId or fold), cr, t, { cap = ns.N(s.max) or 0, weapon = isWeapon and true or false })
      local title = (s.name or "") .. " +" .. tostring(d)
      local maxS = ns.N(s.max) or 0
      local subS = (maxS > 0) and (Tr["Rang "] .. tostring(cr) .. " / " .. tostring(maxS)) or (Tr["Rang "] .. tostring(cr))
      local hintS = self:SkillHint(skillId or fold, skillId, cr, maxS)
      local last = self._dropLast[fold]
      local limited = last and (t - last) >= 0 and (t - last) < UI.DROP_RATE
      if ns.Opt("skillDrops") then
        local nm = s.name or ""
        local f = self:SpawnDrop(icon, title, subS, cr, s.max, nil, { skillId = skillId, skillName = s.name, kind = "skill", hint = hintS,
          dedupeKey = "skill:" .. fold, updateOnly = limited,
          accumulate = { delta = d, fmt = function(n) return nm .. " +" .. tostring(n) end } })
        if f and not limited then self._dropLast[fold] = t end
      elseif ns.Compact and ns.Compact.Announce then
        local opts = { kind = "skill", skillId = skillId, skillName = s.name, accumulate = { delta = d } }
        local tg = ns.Compact.TargetsFor and ns.Compact.TargetsFor(opts) or {}
        pcall(ns.Compact.Announce, opts, tg)
      end
      self._skillDrops = (self._skillDrops or 0) + 1
      local cat = ns.LookupCatalog and ns.LookupCatalog(s.name)
      -- 3.6.0 : suivi de progression (données seulement, aussi en combat)
      if ns.Progress and ns.Progress.OnRise then
        pcall(ns.Progress.OnRise, {
          name = s.name, id = skillId or (cat and cat.id), fold = fold,
          from = pr, to = cr, delta = d, max = maxS, kind = cat and cat.kind,
          counts = not (cat and (cat.countsInTotal == false or cat.kind == "stat")), icon = icon,
        })
      end
      if ns.Dopamine and ns.Dopamine.OnRise then
        pcall(ns.Dopamine.OnRise, {
          name = s.name, id = skillId or (cat and cat.id), fold = fold,
          from = pr, to = cr, delta = d, max = maxS, kind = cat and cat.kind, icon = icon,
        })
      end
    end
  end
  local okC, snap = pcall(ns.Collect)
  if okC and snap then
    self.snapshot = snap
    self._snapVersion = (self._snapVersion or 0) + 1
    SafeStep("objectifs / paliers", self.CheckMilestones, self, snap)
    -- 3.6.3 : repeindre les cases d'arme avec le rang du toast, aussi en combat.
    SafeStep("cases après palier d'arme", self.SyncSkillTiles, self, snap, rises)
  end
end

-- Appliquer le rang / plafond du toast à la case de la MÊME ligne (Mains nues, pas une autre arme).
function UI:SkillLineMatches(d, name, id)
  if not d or d.placeholder then return false end
  if id and (d.id == id or d.skillID == id or d.key == id) then return true end
  local want = name and ns.Fold(name) or ""
  if want == "" then return false end
  if ns.Fold(d.skillName or "") == want or ns.Fold(d.catName or "") == want then return true end
  -- « Mêlée » n'est pas le nom de la ligne : on ne le compare pas au skillName.
  local e = ns.LookupCatalog and ns.LookupCatalog(name)
  if e and d.id == e.id then return true end
  return false
end

function UI:ApplyToastRankToTiles(name, rank, maxv, skillId)
  rank, maxv = ns.N(rank), ns.N(maxv)
  if not rank then return end
  local C = ns.Compact
  local function apply(t)
    local d = t and t.data
    if not d or not self:SkillLineMatches(d, name, skillId) then return end
    d.current = rank
    if maxv and maxv > 0 then d.apiMax = maxv end
    if C and C.holds and C.HoldKey then C.holds[C.HoldKey(d) or ""] = nil end
    pcall(self.UpdateTile, self, t, d)
  end
  for _, wrap in ipairs({ self.embed, self.soloGrid }) do
    for _, t in ipairs((wrap and wrap.tiles) or {}) do apply(t) end
  end
end

function UI:SyncSkillTiles(snap, rises)
  if snap then
    if self.embed then pcall(self.RefreshVisibleTiles, self, self.embed, snap) end
    if self.soloGrid then pcall(self.RefreshVisibleTiles, self, self.soloGrid, snap) end
  end
  for _, r in ipairs(rises or {}) do
    local s = r and r.s
    if s and ns.IsWeaponSkill and ns.IsWeaponSkill(nil, nil, s.name) then
      self:ApplyToastRankToTiles(s.name, r.cr, s.max)
    end
  end
end

-- Ligne verte des drops : objectif > rythme mesuré > palier suivant.
function UI:SkillHint(rateKey, skillId, cur, maxv)
  local key = "skill:" .. tostring(rateKey)
  local g = skillId and ns.GetGoal(skillId)
  local weapon = ns.IsWeaponSkill and ns.IsWeaponSkill(skillId, nil, nil)
  if g and g.rank > cur then
    local eta = ns.FormatDuration(ns.Rate.ETA(key, cur, g.rank, maxv))
    local tag = weapon and Tr[" (~ estimation)"] or ((eta and (" (" .. tostring(eta) .. ")")) or "")
    if weapon and eta then
      return string.format(Tr["Objectif %s : encore %s"], tostring(g.rank), tostring(g.rank - cur)) .. " (" .. eta .. tag .. ")"
    end
    return string.format(Tr["Objectif %s : encore %s"], tostring(g.rank), tostring(g.rank - cur)) .. (eta and (" (" .. eta .. ")") or "")
  end
  if weapon and maxv and maxv > cur then
    local eta = ns.FormatDuration(ns.Rate.ETA(key, cur, maxv, maxv))
    if eta then return tostring(maxv) .. Tr[" dans "] .. eta .. Tr[" (~ estimation)"] end
  end
  local spu = ns.Rate.SecondsPerUnit(key)
  if spu and not weapon then return ns.FormatDuration(spu) .. Tr[" par rang (mesuré)"] end
  if maxv and maxv > cur then return string.format(Tr["Palier %s : encore %s"], tostring(maxv), tostring(maxv - cur)) end
  if maxv and maxv > 0 and cur >= maxv then return Tr["Palier atteint"] end
  return nil
end

function UI:XPHint(cur, maxxp, level)
  cur, maxxp = ns.N(cur) or 0, ns.N(maxxp) or 0
  if maxxp <= 0 then return nil end
  local left = maxxp - cur
  local nextL = (ns.N(level) or 0) + 1
  local spu = ns.Rate.SecondsPerUnit("xp")
  if spu then return string.format(Tr["Niveau %s dans %s"], tostring(nextL), tostring(ns.FormatDuration(spu * left))) end
  return string.format(Tr["Encore %s XP avant le niveau %s"], tostring(left), tostring(nextL))
end

-- Icône d'un drop de compétence = exactement celle de la tuile de la grille.
function UI:SkillDropIcon(name, header, skillLine)
  local want = ns.Fold(name or "")
  local snap = self.snapshot
  if not snap then
    local okC, s2 = pcall(ns.Collect)
    if okC then snap = s2 self.snapshot = s2 end
  end
  for _, list in ipairs({ snap and snap.tiles or {}, snap and snap.allTiles or {} }) do
    for i = 1, #list do
      local d = list[i]
      if ns.Fold(d.skillName or "") == want or ns.Fold(d.name or "") == want then
        if d.icon and not (ns.IconMissing and ns.IconMissing(d.icon)) then return d.icon, d.id end
      end
    end
  end
  local ce = ns.LookupCatalog and ns.LookupCatalog(name)   -- 3.5.19 : nom FR ou EN → même case
  for _, list in ipairs({ snap and snap.tiles or {}, snap and snap.allTiles or {} }) do
    for i = 1, #list do
      local d = list[i]
      if ce and ce.id and d.id == ce.id and d.icon and not (ns.IconMissing and ns.IconMissing(d.icon)) then return d.icon, d.id end
    end
  end
  -- 3.5.18 : catalogue (noms exacts Forever : « Masse »…), ligne de compétence,
  -- icône générique d'arme ; « ? » seulement pour une compétence inconnue hors armes
  local icon, id = ns.ResolveSkillIcon(name, header, skillLine)
  if icon then return icon, id end
  return ns.FALLBACK_ICON, nil
end

-- « Votre compétence en Dépeçage est maintenant de 162. » → nom, rang.
function UI:ParseSkillMessage(msg)
  if type(msg) ~= "string" then return nil end
  -- 3.5.19 : modèle du client (ERR_SKILL_UP_SI) d'abord, quelle que soit la langue
  if ns.MatchGlobal then
    local n0, r0 = ns.MatchGlobal("ERR_SKILL_UP_SI", msg)
    if n0 and ns.N(r0) then return n0, ns.N(r0) end
  end
  local okM, name, rank = pcall(string.match, msg, "en (.-) est maintenant de (%d+)")
  if okM and name then return name, ns.N(rank) end
  okM, name, rank = pcall(string.match, msg, "Your skill in (.-) has increased to (%d+)")
  if okM and name then return name, ns.N(rank) end
  return nil
end

function UI:OnSkillDiff()
  if ns.InCombat and ns.InCombat() then
    self._skillDiffAfterCombat = true
    self.dirty = true
    return
  end
  if self._skillDiffPending then return end
  self._skillDiffPending = true
  local holder = self:TimerFrame("skilldiff")
  if not holder or not holder.SetScript then
    self:FlushSkillDiff()
    return
  end
  holder._osrsSkillAcc = 0
  holder:SetScript("OnUpdate", function(f, elapsed)
    f._osrsSkillAcc = (f._osrsSkillAcc or 0) + (elapsed or 0.05)
    if f._osrsSkillAcc < 0.12 then return end
    f._osrsSkillAcc = 0
    f:SetScript("OnUpdate", nil)   -- un seul passage, puis inactif
    UI:FlushSkillDiff()
  end)
end

function UI:SeedDrops()
  local cur, maxxp = ns.GetPlayerXPSafe()
  if cur and maxxp then
    self._prevXP, self._prevXPMax = cur, maxxp
    self._prevLevel = ns.GetPlayerLevel()
    self._xpSeeded = true
  end
  if ns.SkillRankSnapshot then
    self._prevSkills = ns.SkillRankSnapshot()
    self._skillSeeded = true
  end
end

