-- Dropamine — 3.3.16 : icône du bouton de minicarte (3.4.2 : seul bouton
-- d'ouverture, le bouton du micro menu est retiré) = MÊME rendu que la petite
-- icône de la barre total : Media/SkillsTab (3 piliers) recadrée (ICON_CROP),
-- masquée (Media/OSRS-IconMask) et entourée du bord biseauté bronze
-- (Theme.PlaceBevel). L'icône (bord compris) tient DANS le cadre du bouton :
-- plus de débordement. Nos boutons seulement (enfants d'UIParent / minicarte),
-- rien de natif n'est touché.
local ADDON, ns = ...
local UI, W, Th = ns.UI, ns.Window, ns.Theme
if not (UI and Th) then return end
local TI = {}
ns.ToggleIcon = TI
TI.ICON = "Interface\\AddOns\\Dropamine\\Media\\SkillsTab"
TI.BEVEL = 3          -- le bord biseauté déborde de 3 px autour de l'icône
TI.stats = { skinned = 0 }

local function N(v) return (ns.N and ns.N(v)) or tonumber(v) end

-- Crée / recale l'icône (taille donnée) ; la position est posée par TI.Plate.
function TI.Apply(b, size)
  if not b or not size or size < 4 then return nil end
  local ic = b._tiIcon
  if not ic then
    ic = b:CreateTexture(nil, "ARTWORK", nil, 3)
    pcall(ic.SetTexture, ic, TI.ICON)
    local c = ns.STYLE.ICON_CROP or { 0.08, 0.92, 0.08, 0.92 }
    if ic.SetTexCoord then pcall(ic.SetTexCoord, ic, c[1], c[2], c[3], c[4]) end
    if b.CreateMaskTexture and ic.AddMaskTexture then
      local ok, m = pcall(b.CreateMaskTexture, b)
      if ok and m then
        pcall(m.SetTexture, m, Th.ICON_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        m:SetAllPoints(ic)
        pcall(ic.AddMaskTexture, ic, m)
        ic._tiMask = m
      end
    end
    b._tiIcon = ic
    b.icon = b.icon or ic
    TI.stats.skinned = TI.stats.skinned + 1
  end
  ic:SetSize(size, size)
  ic:Show()
  Th.PlaceBevel(b, ic)
  Th.BevelColor(b)
  Th.ShowBevel(b, true)
  -- anciens piliers dessinés : cachés (remplacés par l'icône)
  local P = b._pillars or b.pillars
  if P then
    if P.bg then P.bg:Hide() end
    for _, c in ipairs(P.cols or {}) do c:Hide() end
  end
  return ic
end

-- 3.3.19 : cause du débordement (3.3.16–3.3.18) : l'icône était posée dans la
-- zone du PORTRAIT natif (lue sur le bouton Personnage, haute et décalée vers
-- le haut), alors que le cadre sombre visible est la plaque du BAS de l'art
-- natif ; l'icône sortait donc par le haut de la plaque. Désormais le lanceur
-- porte SA plaque (carrée, côté = largeur du bouton, calée en bas comme l'art
-- des micro-boutons) et l'icône y est centrée avec le MÊME retrait que la petite
-- icône de la barre total : TI.INSET px de marge + TI.BEVEL px de biseau.
TI.INSET = 3            -- marge plaque → biseau (= Wd.EDGE_OUT de la barre total)
TI.PLATE_BG = { 0.06, 0.05, 0.04, 0.94 }   -- même fond que la pastille « N prêt(s) »
TI.CLASSIC_SLOT = "Interface\\Buttons\\UI-Quickslot2"
TI.CLASSIC_K = 66 / 36
local function Mode() return (Th.Mode and Th.Mode()) or "flare" end
function TI.IconSize(plate) return math.max(8, math.floor(plate - 2 * TI.INSET - 2 * TI.BEVEL + 0.5)) end
local function W8(t, c)
  local ok = t.SetColorTexture and pcall(t.SetColorTexture, t, c[1], c[2], c[3], c[4] or 1)
  if not ok then pcall(t.SetTexture, t, "Interface\\Buttons\\WHITE8X8") if t.SetVertexColor then pcall(t.SetVertexColor, t, c[1], c[2], c[3], c[4] or 1) end end
end
-- plaque + icône + bord selon le thème (flare : filet bronze 1 px ; léger : fond
-- seul ; classic : cadre de bouton d'action autour de l'icône, comme les cases)
function TI.Plate(b)
  if not b then return nil end
  local w = N(b.GetWidth and b:GetWidth()) or 28
  local h = N(b.GetHeight and b:GetHeight()) or w
  local side = math.floor(math.min(w, h) + 0.5)
  if side < 14 then return nil end
  local pl = b._tiPlate
  if not pl then
    pl = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    b._tiPlate = pl
  end
  W8(pl, TI.PLATE_BG)
  pl:ClearAllPoints()
  pl:SetPoint("BOTTOM", b, "BOTTOM", 0, 0)
  pl:SetSize(side, side)
  pl:Show()
  local mode = Mode()
  -- art natif du micro-bouton : remplacé par la plaque (surbrillance gardée, posée sur la plaque)
  for _, st in ipairs({ "Normal", "Pushed", "Disabled" }) do
    local get = b["Get" .. st .. "Texture"]
    local okT, t = pcall(get or function() end, b)
    if okT and type(t) == "table" and t.SetAlpha then pcall(t.SetAlpha, t, 0) end
  end
  -- 3.4.1 : surbrillance native (art du micro-bouton / anneau de minicarte,
  -- dessinée dans une texture plus haute que la plaque) invisible ; la nôtre
  -- est posée exactement sur la plaque (TI.Hover).
  local okH, hl = pcall(b.GetHighlightTexture or function() end, b)
  if okH and type(hl) == "table" and hl.SetAlpha then pcall(hl.SetAlpha, hl, 0) end
  b._tiNativeHL = (okH and type(hl) == "table") and hl or nil
  -- zone de survol / clic = la plaque (calée en bas, centrée en largeur)
  if b.SetHitRectInsets then
    local l = math.floor((w - side) / 2 + 0.5)
    pcall(b.SetHitRectInsets, b, l, math.max(0, math.floor(w - side - l + 0.5)), math.max(0, math.floor(h - side + 0.5)), 0)
  end
  -- filet du thème
  if mode == "flare" then
    local inner = b._tiEdgeT or b:CreateTexture(nil, "BACKGROUND", nil, 2)
    b._tiEdgeT = inner
    inner:ClearAllPoints()
    inner:SetPoint("TOPLEFT", pl, "TOPLEFT", 1, -1)
    inner:SetPoint("BOTTOMRIGHT", pl, "BOTTOMRIGHT", -1, 1)
    inner:SetAlpha(0)
    Th.Frame(b, inner, "_tiEdge", 3)
    Th.ShowFrame(b._tiEdge, true)
  elseif b._tiEdge then
    Th.ShowFrame(b._tiEdge, false)
  end
  local size = TI.IconSize(side)
  local ic = TI.Apply(b, size)
  if not ic then return nil end
  ic:ClearAllPoints()
  ic:SetPoint("CENTER", pl, "CENTER", 0, 0)
  local slot = b._tiSlot
  if mode == "classic" then
    if not slot then slot = b:CreateTexture(nil, "OVERLAY", nil, 1) pcall(slot.SetTexture, slot, TI.CLASSIC_SLOT) b._tiSlot = slot end
    local s = math.floor(size * TI.CLASSIC_K + 0.5)
    slot:ClearAllPoints() slot:SetPoint("CENTER", ic, "CENTER", 0, -1) slot:SetSize(s, s) slot:Show()
    Th.ShowBevel(b, false)
    if ic._tiMask then pcall(ic._tiMask.SetTexture, ic._tiMask, "Interface\\Buttons\\WHITE8X8", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE") end
  else
    if slot then slot:Hide() end
    Th.ShowBevel(b, true)
    if ic._tiMask then pcall(ic._tiMask.SetTexture, ic._tiMask, Th.ICON_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE") end
  end
  b._tiArea = { plate = side, size = size, inset = TI.INSET, mode = mode }
  TI.BuildHover(b, mode)
  TI.SetHover(b, b._tiHovering)
  TI.SetPressed(b, b._tiDown)
  return ic
end

-- 3.4.1 : survol / appui dessinés par nous, sur la plaque exactement.
--   flare / léger : filet clair 1 px sur le bord de la plaque + voile additif léger ;
--   classic       : surbrillance carrée des boutons d'action (ButtonHilight-Square)
--                   sur l'icône, appui = UI-Quickslot-Depress.
TI.HOVER = { 0.98, 0.74, 0.36 }          -- = Skin.BORDER_HOVER (survol FlareUI)
TI.HOVER_FILL_A = 0.12
TI.DOWN_A = 0.30
TI.CLASSIC_HL = "Interface\\Buttons\\ButtonHilight-Square"
TI.CLASSIC_DOWN = "Interface\\Buttons\\UI-Quickslot-Depress"
function TI.BuildHover(b, mode)
  local pl, ic = b._tiPlate, b._tiIcon
  if not (pl and ic) then return nil end
  local H = b._tiHover
  if not H then
    H = { edge = {} }
    H.fill = b:CreateTexture(nil, "OVERLAY", nil, 5)
    W8(H.fill, { 1, 1, 1, 1 })
    if H.fill.SetBlendMode then pcall(H.fill.SetBlendMode, H.fill, "ADD") end
    for i = 1, 4 do H.edge[i] = b:CreateTexture(nil, "OVERLAY", nil, 6) W8(H.edge[i], { 1, 1, 1, 1 }) end
    H.cls = b:CreateTexture(nil, "OVERLAY", nil, 6)
    pcall(H.cls.SetTexture, H.cls, TI.CLASSIC_HL)
    if H.cls.SetBlendMode then pcall(H.cls.SetBlendMode, H.cls, "ADD") end
    H.down = b:CreateTexture(nil, "OVERLAY", nil, 4)
    W8(H.down, { 0, 0, 0, 1 })
    b._tiHover = H
  end
  local c = TI.HOVER
  H.fill:ClearAllPoints() H.fill:SetPoint("TOPLEFT", pl, "TOPLEFT", 1, -1) H.fill:SetPoint("BOTTOMRIGHT", pl, "BOTTOMRIGHT", -1, 1)
  if H.fill.SetVertexColor then H.fill:SetVertexColor(c[1], c[2], c[3], TI.HOVER_FILL_A) end
  local e = H.edge
  for i = 1, 4 do e[i]:ClearAllPoints() if e[i].SetVertexColor then e[i]:SetVertexColor(c[1], c[2], c[3], 1) end end
  e[1]:SetPoint("TOPLEFT", pl, "TOPLEFT", 1, 0) e[1]:SetPoint("TOPRIGHT", pl, "TOPRIGHT", -1, 0) e[1]:SetHeight(1)
  e[2]:SetPoint("BOTTOMLEFT", pl, "BOTTOMLEFT", 1, 0) e[2]:SetPoint("BOTTOMRIGHT", pl, "BOTTOMRIGHT", -1, 0) e[2]:SetHeight(1)
  e[3]:SetPoint("TOPLEFT", pl, "TOPLEFT", 0, -1) e[3]:SetPoint("BOTTOMLEFT", pl, "BOTTOMLEFT", 0, 1) e[3]:SetWidth(1)
  e[4]:SetPoint("TOPRIGHT", pl, "TOPRIGHT", 0, -1) e[4]:SetPoint("BOTTOMRIGHT", pl, "BOTTOMRIGHT", 0, 1) e[4]:SetWidth(1)
  H.cls:ClearAllPoints() H.cls:SetAllPoints(ic)
  H.down:ClearAllPoints() H.down:SetAllPoints(ic)
  if H.down.SetVertexColor then H.down:SetVertexColor(0, 0, 0, TI.DOWN_A) end
  H.mode = mode
  return H
end
function TI.SetHover(b, on)
  local H = b and b._tiHover
  b._tiHovering = on and true or nil
  if not H then return end
  local cls = H.mode == "classic"
  local function vis(t, v) if v then t:Show() else t:Hide() end end
  vis(H.fill, on and not cls)
  for i = 1, 4 do vis(H.edge[i], on and not cls) end
  vis(H.cls, on and cls)
  if b._tiNativeHL and b._tiNativeHL.SetAlpha then pcall(b._tiNativeHL.SetAlpha, b._tiNativeHL, 0) end
end
function TI.SetPressed(b, down)
  local H = b and b._tiHover
  b._tiDown = down and true or nil
  if not H then return end
  if down then H.down:Show() else H.down:Hide() end
  local slot = b._tiSlot
  if slot and H.mode == "classic" then pcall(slot.SetTexture, slot, down and TI.CLASSIC_DOWN or TI.CLASSIC_SLOT) end
end
function TI.WireHover(b)
  if not b or b._tiHoverWired or not b.HookScript then return end
  b._tiHoverWired = true
  b:HookScript("OnEnter", function(self) TI.SetHover(self, true) end)
  b:HookScript("OnLeave", function(self) TI.SetHover(self, false) TI.SetPressed(self, false) end)
  b:HookScript("OnMouseDown", function(self) TI.SetPressed(self, true) end)
  b:HookScript("OnMouseUp", function(self) TI.SetPressed(self, false) end)
  if b.HookScript then pcall(b.HookScript, b, "OnHide", function(self) TI.SetHover(self, false) TI.SetPressed(self, false) end) end
end

-- changement de thème : la plaque suit
if Th then
  local prevMC = Th.OnModeChanged
  function Th.OnModeChanged(m, ...)
    if prevMC then pcall(prevMC, m, ...) end
    if UI.minimap then pcall(TI.Plate, UI.minimap) end
  end
end

-- bouton de minicarte : même plaque (32 px → icône 20 px), anneau rond retiré
local baseMM = UI.BuildMinimap
function UI:BuildMinimap(...)
  local r = { baseMM(self, ...) }
  local b = self.minimap
  if b and not b._tiDone then
    b._tiDone = true
    TI.Plate(b)
    TI.WireHover(b)
    if b.overlay then b.overlay:Hide() end
  end
  return unpack(r)
end

function TI.DebugLine()
  local p = {}
  for _, pair in ipairs({ { "minicarte", UI.minimap } }) do
    local b, a = pair[2], pair[2] and pair[2]._tiArea
    p[#p + 1] = pair[1] .. " " .. (a and string.format("zone %d px (plaque), icône %d px, retrait %d + biseau %d, thème %s", a.plate, a.size, a.inset, TI.BEVEL, tostring(a.mode)) or "—")
  end
  return "— Bouton de minicarte (3.4.2) — " .. table.concat(p, " ; ")
end
ns.DebugExt = ns.DebugExt or {}
ns.DebugExt[#ns.DebugExt + 1] = function() return { TI.DebugLine() } end
