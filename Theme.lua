-- Dropamine 3.3.10 : thèmes « cadre » / « sans », style de case unifié
-- (bord bronze 1 px, coins légèrement arrondis, ombre douce), pastille « N prêt »
-- au-dessus de la case, vraie poignée de redimensionnement, déplacement du
-- panneau depuis n'importe où, toasts et panneau sur le même fond / la même
-- opacité. Rien par image : tout est posé à la construction / au changement.
local _, ns = ...
local Tr = ns.L   -- 3.5.19 : textes traduits (Locales/)
local Th = {}
ns.Theme = Th

local function DB() return ns.EnsureDB().ui end
local function N(v) return ns.N and ns.N(v) or tonumber(v) end
local MEDIA = "Interface\\AddOns\\Dropamine\\Media\\"

-- 3.3.13 : deux thèmes seulement — « flare » (fond + bord arrondi FlareUI,
-- défaut) et « leger » (sans cadre, sobre, cases flottantes). Alias : cadre → flare,
-- sans → leger.
Th.MODES = { flare = true, leger = true, classic = true }   -- 3.3.17 : + « classic » (textures Blizzard)
Th.ALIASES = { cadre = "flare", frame = "flare", avec = "flare", flareui = "flare",
  sans = "leger", ["léger"] = "leger", light = "leger", sanscadre = "leger", ["sans-cadre"] = "leger", none = "leger", aucun = "leger",
  classique = "classic", blizzard = "classic", natif = "classic", native = "classic", default = "classic", ["défaut"] = "classic" }
Th.BRONZE = ns.STYLE.BORDER                              -- #A67D45, jeton unique (STYLE.md)
Th.BRONZE_DARK = { 40 / 255, 31 / 255, 20 / 255, 0.55 } -- liseré intérieur (petit ombrage)
Th.SHADOW_TEX = MEDIA .. "SoftShadow"   -- 64 px : rectangle arrondi flouté (zone pleine 12..52)
Th.SHADOW_ALPHA = 0.30                  -- ombre douce : discrète, pas un halo sombre
Th.SHADOW_DY = -1
Th.MASK_FILES = { MEDIA .. "OSRS-IconMask", MEDIA .. "RoundMask", "Interface\\Common\\common-iconmask" }
Th.MASK_ATLAS = { "UI-HUD-CoolDownManager-Mask", "UI-HUD-CoolDownManager-IconMask" }
Th.CROP = { 0.08, 0.92, 0.08, 0.92 }    -- repli : carré recadré (bords de l'icône rognés)
Th.BADGE_H = 10
Th.BADGE_OVERLAP = -1                   -- 3.3.17 : plaquette posée 1 px AU-DESSUS de la case (ne mord plus dessus)

function Th.Mode()
  local m = DB().theme
  if m == "classic" then return "classic" end
  return (m == "leger" or m == "sans") and "leger" or "flare"
end
function Th.IsSans() return Th.Mode() == "leger" end

------------------------------------------------------------------------------
-- Bord bronze 1 px « arrondi » : 4 traits qui s'arrêtent 1 px avant les coins
-- (le coin vide adoucit l'angle à la taille native), + liseré sombre intérieur.
------------------------------------------------------------------------------
local function Solid(t, c)
  local ok = t.SetColorTexture and pcall(t.SetColorTexture, t, c[1], c[2], c[3], c[4] or 1)
  if not ok then
    pcall(t.SetTexture, t, "Interface\\Buttons\\WHITE8X8")
    if t.SetVertexColor then pcall(t.SetVertexColor, t, c[1], c[2], c[3], c[4] or 1) end
  end
  if t.SetSnapToPixelGrid then pcall(t.SetSnapToPixelGrid, t, true) end
end
function Th.Frame(owner, target, key, level)
  key = key or "_thEdge"
  local e = owner[key]
  if not e then
    e = { outer = {}, inner = {} }
    for i = 1, 4 do
      e.outer[i] = owner:CreateTexture(nil, "OVERLAY", nil, level or 1)
      e.inner[i] = owner:CreateTexture(nil, "OVERLAY", nil, (level or 1) - 1)
    end
    owner[key] = e
  end
  local o, n = e.outer, e.inner
  for i = 1, 4 do Solid(o[i], Th.BRONZE) Solid(n[i], Th.BRONZE_DARK) o[i]:ClearAllPoints() n[i]:ClearAllPoints() end
  -- extérieur (coins laissés vides)
  o[1]:SetPoint("BOTTOMLEFT", target, "TOPLEFT", 1, 0)     o[1]:SetPoint("BOTTOMRIGHT", target, "TOPRIGHT", -1, 0)   o[1]:SetHeight(1)
  o[2]:SetPoint("TOPLEFT", target, "BOTTOMLEFT", 1, 0)     o[2]:SetPoint("TOPRIGHT", target, "BOTTOMRIGHT", -1, 0)   o[2]:SetHeight(1)
  o[3]:SetPoint("TOPRIGHT", target, "TOPLEFT", 0, -1)      o[3]:SetPoint("BOTTOMRIGHT", target, "BOTTOMLEFT", 0, 1)  o[3]:SetWidth(1)
  o[4]:SetPoint("TOPLEFT", target, "TOPRIGHT", 0, -1)      o[4]:SetPoint("BOTTOMLEFT", target, "BOTTOMRIGHT", 0, 1)  o[4]:SetWidth(1)
  -- intérieur : 1 px sombre sur le bord de l'icône
  n[1]:SetPoint("TOPLEFT", target, "TOPLEFT", 0, 0)        n[1]:SetPoint("TOPRIGHT", target, "TOPRIGHT", 0, 0)       n[1]:SetHeight(1)
  n[2]:SetPoint("BOTTOMLEFT", target, "BOTTOMLEFT", 0, 0)  n[2]:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 0, 0) n[2]:SetHeight(1)
  n[3]:SetPoint("TOPLEFT", target, "TOPLEFT", 0, -1)       n[3]:SetPoint("BOTTOMLEFT", target, "BOTTOMLEFT", 0, 1)   n[3]:SetWidth(1)
  n[4]:SetPoint("TOPRIGHT", target, "TOPRIGHT", 0, -1)     n[4]:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 0, 1) n[4]:SetWidth(1)
  for i = 1, 4 do o[i]:Show() n[i]:Show() end
  e.target = target
  return e
end
function Th.ShowFrame(e, on)
  if not e then return end
  for i = 1, 4 do
    if on then e.outer[i]:Show() e.inner[i]:Show() else e.outer[i]:Hide() e.inner[i]:Hide() end
  end
end
function Th.SetFrameAlpha(e, a)
  if not e then return end
  for i = 1, 4 do e.outer[i]:SetAlpha(a) e.inner[i]:SetAlpha(a) end
end

-- Ombre douce sous une zone (taille ∝ zone : la partie pleine du fichier = la zone).
function Th.Shadow(owner, target, key, alpha)
  key = key or "_thShadow"
  local s = owner[key]
  if not s then
    s = owner:CreateTexture(nil, "BACKGROUND", nil, -8)
    owner[key] = s
  end
  pcall(s.SetTexture, s, Th.SHADOW_TEX)
  if s.SetVertexColor then pcall(s.SetVertexColor, s, 0, 0, 0, 1) end
  s:SetAlpha(alpha or Th.SHADOW_ALPHA)
  s:ClearAllPoints()
  -- 12 px de flou de chaque côté pour 40 px pleins → 0,3 × la zone, plafonné à 6 px
  local w = (target.GetWidth and N(target:GetWidth())) or 36
  local pad = math.min(6, math.max(3, math.floor(w * 0.3 + 0.5)))
  s:SetPoint("TOPLEFT", target, "TOPLEFT", -pad, pad + Th.SHADOW_DY)
  s:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", pad, -pad + Th.SHADOW_DY)
  s:Show()
  s._pad = pad
  return s
end

------------------------------------------------------------------------------
-- Masque arrondi (une fois, mis en cache) ; repli : recadrage carré.
------------------------------------------------------------------------------
function Th.MaskSource()
  if Th._maskSrc ~= nil then return Th._maskSrc end
  local src = false
  local CT = _G.C_Texture
  if type(CT) == "table" and type(CT.GetAtlasInfo) == "function" then
    for _, a in ipairs(Th.MASK_ATLAS) do
      local ok, info = pcall(CT.GetAtlasInfo, a)
      if ok and info then src = { atlas = a } break end
    end
  end
  src = { file = Th.MASK_FILES[1] }   -- 3.3.15 : masque biseauté de l'addon en premier
  Th._maskSrc = src
  return src
end
function Th.Round(owner, tex)
  if not (owner and tex) then return "aucun" end
  if tex._thMask then return tex._thMaskMode end
  local mode = "recadrage"
  if type(owner.CreateMaskTexture) == "function" and type(tex.AddMaskTexture) == "function" then
    local ok, m = pcall(owner.CreateMaskTexture, owner)
    if ok and m then
      local src = Th.MaskSource()
      local set = false
      if src.atlas and m.SetAtlas then set = pcall(m.SetAtlas, m, src.atlas) end
      if not set and src.file then set = pcall(m.SetTexture, m, src.file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE") end
      if set then
        m:SetAllPoints(tex)
        pcall(tex.AddMaskTexture, tex, m)
        tex._thMask = m
        mode = src.atlas and ("masque atlas " .. src.atlas) or "masque arrondi"
      end
    end
  end
  tex._thMaskMode = mode
  return mode
end

------------------------------------------------------------------------------
-- 3.3.15 : bord d'icône façon référence (fin filet bronze, coins biseautés,
-- ombre noire dehors, liseré sombre dedans), NET à toute taille : 3 bandes de
-- 1 px par côté (ombre / filet / liseré) + 4 coins de 4 px (Media/OSRS-IconCorner,
-- pivotés par coordonnées), masque Media/OSRS-IconMask sur l'icône, recadrage
-- 0.08–0.92. Le MÊME bord sert au repos (bronze), à la cible (vert) et à la
-- sélection (or) : seule la couleur change — jamais de trait carré à part.
------------------------------------------------------------------------------
Th.ICON_CORNER = MEDIA .. "OSRS-IconCorner"
Th.ICON_MASK = MEDIA .. "OSRS-IconMask"
Th.EDGE_SHADOW = { 0, 0, 0, 0.70 }
Th.EDGE_LINE_A = 0.72     -- filet : jeton #A67D45 à 72 % (= bronze rendu de la référence)
Th.SUBTLE_A = 0.45        -- surbrillance discrète (cible éligible, pas de frappe)
Th.EDGE_INNER_K = 0.35    -- liseré intérieur : même teinte, assombrie (opaque)
local function W8(t) local ok = t.SetColorTexture and pcall(t.SetColorTexture, t, 1, 1, 1, 1) if not ok then pcall(t.SetTexture, t, "Interface\\Buttons\\WHITE8X8") end end
function Th.Bevel(t)
  local e = t._bevel
  if e then return e end
  e = { strips = {}, corners = {} }
  for side = 1, 4 do
    e.strips[side] = {}
    for ring = 1, 3 do
      local x = t:CreateTexture(nil, "OVERLAY", nil, 2)
      W8(x)
      e.strips[side][ring] = x
    end
  end
  for c = 1, 4 do
    local x = t:CreateTexture(nil, "OVERLAY", nil, 2)
    pcall(x.SetTexture, x, Th.ICON_CORNER)
    e.corners[c] = x
  end
  t._bevel = e
  return e
end
function Th.PlaceBevel(t, icon)
  local e = Th.Bevel(t)
  local S = e.strips
  for ring = 1, 3 do
    local o = 4 - ring          -- 3 = ombre (dehors), 2 = filet, 1 = liseré
    local top, bot, lef, rig = S[1][ring], S[2][ring], S[3][ring], S[4][ring]
    for _, x in ipairs({ top, bot, lef, rig }) do x:ClearAllPoints() end
    top:SetPoint("TOPLEFT", icon, "TOPLEFT", 1, o) top:SetPoint("TOPRIGHT", icon, "TOPRIGHT", -1, o) top:SetHeight(1)
    bot:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 1, -o) bot:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, -o) bot:SetHeight(1)
    lef:SetPoint("TOPLEFT", icon, "TOPLEFT", -o, -1) lef:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", -o, 1) lef:SetWidth(1)
    rig:SetPoint("TOPRIGHT", icon, "TOPRIGHT", o, -1) rig:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", o, 1) rig:SetWidth(1)
  end
  -- coins 4 × 4 : haut-gauche, haut-droit, bas-gauche, bas-droit (fichier pivoté)
  local C = e.corners
  local spec = {
    { "TOPLEFT", -3, 3, 0, 1, 0, 1 }, { "TOPRIGHT", 3, 3, 1, 0, 0, 1 },
    { "BOTTOMLEFT", -3, -3, 0, 1, 1, 0 }, { "BOTTOMRIGHT", 3, -3, 1, 0, 1, 0 },
  }
  for k, sp in ipairs(spec) do
    local x = C[k]
    x:ClearAllPoints()
    x:SetPoint(sp[1], icon, sp[1], sp[2], sp[3])
    x:SetSize(4, 4)
    if x.SetTexCoord then pcall(x.SetTexCoord, x, sp[4], sp[5], sp[6], sp[7]) end
  end
  e.icon = icon
  return e
end
-- couleur du bord : cible (vert) > sélection (or) > repos (bronze)
function Th.BevelColor(t)
  local e = t and t._bevel
  if not e then return nil end
  local c = (t._tgtLit and ((ns.Target and ns.Target.GREEN) or { 0.25, 1, 0.25 })) or (t._flSelOn and ns.STYLE.SELECT) or ns.STYLE.BORDER
  local a = ((t._tgtLit == "indirect") and Th.SUBTLE_A or 1) * Th.EDGE_LINE_A
  for side = 1, 4 do
    local sh, li, inn = e.strips[side][3], e.strips[side][2], e.strips[side][1]
    sh:SetVertexColor(Th.EDGE_SHADOW[1], Th.EDGE_SHADOW[2], Th.EDGE_SHADOW[3], Th.EDGE_SHADOW[4])
    li:SetVertexColor(c[1], c[2], c[3], a)
    local k = Th.EDGE_INNER_K
    inn:SetVertexColor(c[1] * k, c[2] * k, c[3] * k, 1)
  end
  for _, x in ipairs(e.corners) do x:SetVertexColor(c[1], c[2], c[3], a) end
  e.color = c
  return c
end
function Th.ShowBevel(t, on)
  local e = t and t._bevel
  if not e then return end
  for side = 1, 4 do for ring = 1, 3 do if on then e.strips[side][ring]:Show() else e.strips[side][ring]:Hide() end end end
  for _, x in ipairs(e.corners) do if on then x:Show() else x:Hide() end end
end
function Th.IconSkin(t)
  local icon = t.icon
  Th.PlaceBevel(t, icon)
  Th.BevelColor(t)
  Th.ShowBevel(t, true)
  -- masque : coins de l'icône coupés comme le biseau
  local m = icon._thMask
  if m then pcall(m.SetTexture, m, Th.ICON_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE") m:ClearAllPoints() m:SetAllPoints(icon) end
  -- anciens cadres carrés : retirés
  if t._thEdge then Th.ShowFrame(t._thEdge, false) end
  if t._thShadow then t._thShadow:Hide() end
  local B = t._bronze
  if B then for _, set in pairs({ B.outer, B.inner }) do for _, x in pairs(set) do x:Hide() end end end
  if t.bg333 then t.bg333:ClearAllPoints() t.bg333:SetAllPoints(icon) end
  return t._bevel
end
-- sélection : le biseau or suit l'état de la case
do
  local V = ns.View
  if V and V.PaintTile then
    local basePT = V.PaintTile
    function V.PaintTile(t, ...)
      local r = { basePT(t, ...) }
      if t and t._bevel and t.checkTex then
        t._flSelOn = t.checkTex:IsShown()
        t.checkTex:Hide()               -- halo carré remplacé par le bord (couleur or)
        Th.BevelColor(t)
      end
      return unpack(r)
    end
  end
end

------------------------------------------------------------------------------
-- Style de case (les deux thèmes) : posé après chaque ResizeTile.
------------------------------------------------------------------------------
Th.stats = { tiles = 0, masks = {} }
function Th.StyleTile(t)
  if not (t and t.icon) then return end
  -- emplacement natif (cadre épais + fond sombre) → remplacé par le style CDM
  if t.slotBorder then t.slotBorder:Hide() t.slotBorder:SetAlpha(0) end
  if t.slotBg then t.slotBg:Hide() t.slotBg:SetAlpha(0) end
  local mode = Th.Round(t, t.icon)
  -- 3.3.15 : recadrage FlareUI (0.08–0.92) dans tous les cas
  local c = ns.STYLE.ICON_CROP
  if t.icon.SetTexCoord and not t._portrait then pcall(t.icon.SetTexCoord, t.icon, c[1], c[2], c[3], c[4]) end
  Th.IconSkin(t)
  if not t._thStyled then Th.stats.tiles = Th.stats.tiles + 1 end
  t._thStyled = true
  t._thMaskMode = mode
  Th.stats.masks[mode] = (Th.stats.masks[mode] or 0) + 1
  Th.WireTileDrag(t)
end

------------------------------------------------------------------------------
-- Déplacement depuis n'importe où (cases comprises) avec seuil : un simple clic
-- reste un clic (objectif clic droit, Maj+clic partage, sélection).
------------------------------------------------------------------------------
local function Frame() return ns.Window and ns.Window.frame end
local function Locked() return DB().locked and true or false end
local function CursorUI()
  local x, y = 0, 0
  if type(_G.GetCursorPosition) == "function" then x, y = _G.GetCursorPosition() end
  local s = (UIParent and UIParent.GetEffectiveScale and N(UIParent:GetEffectiveScale())) or 1
  if not s or s <= 0 then s = 1 end
  return (N(x) or 0) / s, (N(y) or 0) / s
end
Th.CursorUI = CursorUI

function Th.BeginMove(src)
  local f = Frame()
  if not f or Locked() or Th.moving then return false end
  if f.SetMovable then pcall(f.SetMovable, f, true) end
  local ok = pcall(f.StartMoving, f)
  if not ok then return false end
  Th.moving = src or true
  if src and type(src) == "table" then src._thDragged = true end
  return true
end
function Th.EndMove()
  local f = Frame()
  if not Th.moving then return false end
  Th.moving = nil
  if f then
    pcall(f.StopMovingOrSizing, f)
    if ns.Panel and ns.Panel.SavePos then ns.Panel.SavePos(f) end
  end
  return true
end
function Th.WireDrag(fr)
  if not fr or fr._thDragWired then return end
  fr._thDragWired = true
  if fr.RegisterForDrag then pcall(fr.RegisterForDrag, fr, "LeftButton") end
  local hook = fr.HookScript and function(ev, fn) fr:HookScript(ev, fn) end or function(ev, fn)
    local old = fr.GetScript and fr:GetScript(ev)
    fr:SetScript(ev, function(...) if old then old(...) end fn(...) end)
  end
  hook("OnMouseDown", function(self, btn)
    if btn == "LeftButton" or btn == nil then
      local x, y = CursorUI()
      self._thDown = { x = x, y = y }
      self._thDragged = nil
    end
  end)
  -- le client ne lance OnDragStart qu'après un petit déplacement (seuil natif) :
  -- un simple clic reste un clic
  fr:SetScript("OnDragStart", function(self)
    if Locked() then return end
    Th.BeginMove(self)
  end)
  fr:SetScript("OnDragStop", function(self) Th.EndMove() self._thDown = nil end)
  hook("OnHide", function() if Th.moving then Th.EndMove() end end)
end
function Th.WireTileDrag(t)
  if not t or t._thClickWrapped then return end
  Th.WireDrag(t)
  local orig = t.GetScript and t:GetScript("OnClick")
  if orig then
    t._thClickWrapped = true
    t:SetScript("OnClick", function(self, ...)
      -- un glisser ne déclenche pas le clic (sélection / objectif / partage)
      if self._thDragged then self._thDragged = nil return end
      return orig(self, ...)
    end)
  end
end

------------------------------------------------------------------------------
-- Panneau : thème (fond + bord visibles ou non), survol, poignées.
------------------------------------------------------------------------------
function Th.ApplyPanel()
  local f = Frame()
  if not f then return end
  local sans = Th.IsSans()
  -- 3.4.0 : Léger = AUCUN cadre ni fond autour des cases (habillage caché ET
  -- transparent, reposé à chaque fondu / survol / ouverture : rien ne le remontre)
  for _, host in ipairs({ f._tipChrome, f._skinHost }) do
    if host then
      if sans then host:Hide() if host.SetAlpha then host:SetAlpha(0) end
      else if host.SetAlpha then host:SetAlpha(1) end host:Show() end
    end
  end
  local P = ns.Panel
  local X = P and P.tip
  if X and X.host then
    -- repli backdrop : on coupe fond et bord
    if sans then
      pcall(X.host.SetBackdropColor, X.host, 0, 0, 0, 0)
      pcall(X.host.SetBackdropBorderColor, X.host, 0, 0, 0, 0)
    end
  end
  local T = P and P.toast
  -- ancien habillage (repli sans infobulle lisible) : caché en « sans » ; en
  -- « cadre » il ne revient que s'il est le seul cadre (pas de P.tip)
  if T then
    local show = (not sans) and not (P and P.tip)
    for _, t in ipairs(T.bg or {}) do if show then t:Show() else t:Hide() end end
    for _, t in ipairs(T.border or {}) do if show then t:Show() else t:Hide() end end
  end
  -- la zone du panneau prend la souris pour le déplacer (marges comprises)
  if f.EnableMouse then pcall(f.EnableMouse, f, true) end
  Th.WireDrag(f)
  if not f._thHoverWired and f.HookScript then
    f._thHoverWired = true
    f:HookScript("OnEnter", function() if P and P.SetHover then P.SetHover(true) end end)
    f:HookScript("OnLeave", function() if P and P.SetHover then P.SetHover(false) end end)
  end
  if P and P.handle then Th.WireDrag(P.handle) end
  Th.UpdateHandles()
  f._thTheme = Th.Mode()
end

function Th.HideChrome()
  local f = Frame()
  if not f then return end
  for _, host in ipairs({ f._tipChrome, f._skinHost }) do
    if host then host:Hide() if host.SetAlpha then host:SetAlpha(0) end end
  end
end

-- poignées : sans cadre → visibles au survol seulement ; toujours cachées si verrou
function Th.UpdateHandles()
  local L = ns.Layout
  local g = L and L.grip
  local P = ns.Panel
  local hover = P and P._hoverWant
  if g then
    if Locked() then
      g:Hide() if g.EnableMouse then g:EnableMouse(false) end
    else
      g:Show() if g.EnableMouse then g:EnableMouse(true) end
      local a = (Th.IsSans() and not hover and not (L and L.drag)) and 0 or 1
      if g.tex then g.tex:SetAlpha(a) end
      g._thAlpha = a
    end
  end
  local h = P and P.handle
  if h and h.EnableMouse then pcall(h.EnableMouse, h, not Locked()) end
end

function Th.Set(m)
  m = type(m) == "string" and m:lower() or ""
  m = Th.ALIASES[m] or m
  if not Th.MODES[m] then return nil end
  DB().theme = (m ~= "flare") and m or nil       -- défaut (flare) : rien d'enregistré
  if Th.OnModeChanged then pcall(Th.OnModeChanged, m) end
  Th.ApplyPanel()
  Th.RestyleToasts()
  if ns.Panel and ns.Panel.ApplyOpacity then pcall(ns.Panel.ApplyOpacity) end
  return m
end

------------------------------------------------------------------------------
-- Toasts : même fond (couleur + /drop fond), même bord, même pilote d'opacité
-- que le panneau. En « sans », bord bronze 1 px + ombre douce, comme les cases.
------------------------------------------------------------------------------
function Th.PanelLook()
  local P = ns.Panel
  local X = P and P.tip
  if X and X.bgColor then
    return { bg = X.bgColor, bgAlpha = X.bgAlpha or (X.bgColor[4] or 1), border = X.borderColor, borderAlpha = X.borderAlpha or 1 }
  end
  local T = P and P.toast
  if T and T.bgColor then
    local a = (T.bg and T.bg[1] and T.bg[1]._bgAlpha) or T.bgColor[4] or 1
    return { bg = T.bgColor, bgAlpha = a, border = { 1, 1, 1, 1 }, borderAlpha = 1 }
  end
end
function Th.PanelShown()
  local f = Frame()
  return f and f.IsShown and f:IsShown() and true or false
end
function Th.ToastLook(f)
  if type(f) ~= "table" or f._osrsPanel then return end
  local look = Th.PanelShown() and Th.PanelLook()
  local sans = Th.IsSans()
  local c = f._thChrome
  -- 3.3.11 : les toasts gardent la bordure des infobulles dans les deux thèmes
  if f._tipChrome then f._tipChrome:Show() end
  local bg = f._toastBg
  -- 3.3.13 : habillage FlareUI (Skin.lua) : même fond / alpha / bord que le panneau
  if f._skinHost and ns.Skin then
    if look then
      ns.Skin.Paint(f._skinHost, look.bgAlpha, look.border)
      f._bgAlpha = look.bgAlpha
      f._thShared = true
    else
      f._thShared = nil
    end
    if bg then bg:Hide() end
    f._thTheme = Th.Mode()
    if ns.UI and ns.UI.ApplyToastTint then pcall(ns.UI.ApplyToastTint, f, f._tintOpts) end
    return
  end
  if look and bg then
    local col = look.bg
    Solid(bg, { col[1], col[2], col[3], look.bgAlpha })
    bg:SetAlpha(1)
    f._bgAlpha = look.bgAlpha
    f._thShared = true
  else
    f._thShared = nil
  end
  if c and c.border and look and look.border then
    for _, t in pairs(c.border) do
      if type(t) == "table" then
        -- 3.3.11 : bord par défaut de l'infobulle, sans aucune teinte (ni live, ni palier)
        local bcol = look.border
        if t.SetVertexColor then pcall(t.SetVertexColor, t, bcol[1], bcol[2], bcol[3], 1) end
        if t.SetAlpha then t:SetAlpha(look.borderAlpha) end
      end
    end
  end
  Th.ShowFrame(f._thEdge, false)
  if f._thShadow then f._thShadow:Hide() end
  f._thTheme = Th.Mode()
  if ns.UI and ns.UI.ApplyToastTint then pcall(ns.UI.ApplyToastTint, f, f._tintOpts) end
end
function Th.RestyleToasts()
  local UI = ns.UI
  local n = 0
  for _, d in ipairs(UI and UI.dropsActive or {}) do Th.ToastLook(d) n = n + 1 end
  return n
end

------------------------------------------------------------------------------
-- Branchements
------------------------------------------------------------------------------
local UI = ns.UI
if UI and UI.ResizeTile then
  local base = UI.ResizeTile
  function UI:ResizeTile(t, ...)
    local r = { base(self, t, ...) }
    pcall(Th.StyleTile, t)
    return unpack(r)
  end
end

local Ch = ns.Chrome
if Ch and Ch.Toast then
  local baseToast = Ch.Toast
  function Ch.Toast(f, ...)
    local c = baseToast(f, ...)
    if type(f) == "table" then f._thChrome = c f._thTint = select(1, ...) end
    pcall(Th.ToastLook, f)
    return c
  end
end

local P = ns.Panel
if P then
  if P.ApplyOpacity then
    local baseAO = P.ApplyOpacity
    -- pilote d'opacité partagé : chaque mise à jour du panneau recale les toasts
    function P.ApplyOpacity(...)
      local r = { baseAO(...) }
      if Th.IsSans() then
        local X = P.tip
        if X and X.host then pcall(X.host.SetBackdropColor, X.host, 0, 0, 0, 0) pcall(X.host.SetBackdropBorderColor, X.host, 0, 0, 0, 0) end
        Th.HideChrome()
      end
      pcall(Th.RestyleToasts)
      return unpack(r)
    end
  end
  if P.ApplyTooltipLook then
    local baseATL = P.ApplyTooltipLook
    function P.ApplyTooltipLook(...)
      local r = { baseATL(...) }
      pcall(Th.ApplyPanel)
      return unpack(r)
    end
  end
  if P.SetHover then
    local baseSH = P.SetHover
    function P.SetHover(...)
      local r = { baseSH(...) }
      pcall(Th.UpdateHandles)
      return unpack(r)
    end
  end
  -- (c) plus d'infobulle « Niveau total / Glisser : déplacer » sur le bord
  function Th.StripHandleTooltip()
    local h = P.handle
    if not h then return false end
    h:SetScript("OnEnter", function() P.SetHover(true) end)
    h:SetScript("OnLeave", function() P.SetHover(false) end)
    h._thNoTip = true
    return true
  end
  local W0 = ns.Window
  if W0 and W0.Build then
    local baseB = W0.Build
    function W0.Build(...)
      local r = { baseB(...) }
      pcall(Th.StripHandleTooltip)
      pcall(Th.ApplyPanel)
      return unpack(r)
    end
  end
end

------------------------------------------------------------------------------
-- (a) Vraie poignée : glisser redimensionne. 3.3.12 : taille CONTINUE (pas de
-- 1 %, 50 à 200 %), la disposition ne change jamais pendant le glisser (seulement
-- /drop colonnes, la liste des options, ou Alt+glisser). Pas d'infobulle.
------------------------------------------------------------------------------
local L = ns.Layout
Th.SCALE_STEP = 1
if L then
  -- taille du panneau à l'échelle 100 % pour chaque disposition
  function Th.BaseSizes()
    local out = {}
    local f = Frame()
    local cur = L.Cols and L.Cols()
    local fw, fh
    if f and f.GetWidth then fw, fh = N(f:GetWidth()), N(f:GetHeight()) end
    local cands = L.Candidates and L.Candidates() or {}
    -- calage : écart entre la taille réelle (centrée) et l'estimation pour la
    -- disposition actuelle, appliqué à toutes (mêmes marges partout)
    local dw, dh = 0, 0
    for _, c in ipairs(cands) do
      if c.cols == cur and fw and fh and fw > 0 then dw, dh = fw - c.w, fh - c.h end
    end
    for _, c in ipairs(cands) do out[#out + 1] = { cols = c.cols, w = c.w + dw, h = c.h + dh } end
    return out
  end
  -- échelle (en %) dont la taille approche le plus (w, h) : moindres carrés sur
  -- la taille du panneau à 100 % (le coin haut-gauche reste fixe : SetScale)
  function Th.ScaleFor(w, h, bw, bh)
    local den = bw * bw + bh * bh
    if den <= 0 then return nil end
    local s = 100 * (w * bw + h * bh) / den
    return math.max(L.SCALE_MIN or 50, math.min(L.SCALE_MAX or 200, math.floor(s + 0.5)))
  end
  local function AltDown() return type(_G.IsAltKeyDown) == "function" and _G.IsAltKeyDown() and true or false end
  function L.DragStep()
    local d = L.drag
    if not d then return end
    local x, y = CursorUI()
    local w, h = d.w + (x - d.x), d.h + (d.y - y)
    if d.alt then
      -- Alt+glisser : colonnes seulement, à taille fixe
      local best, bd
      local k = (L.Scale() or 100) / 100
      for _, c in ipairs(Th.BaseSizes()) do
        local dd = (c.w * k - w) ^ 2 + (c.h * k - h) ^ 2
        if not bd or dd < bd then best, bd = c, dd end
      end
      if best and best.cols ~= L.Cols() then L.SetCols(best.cols) end
      d.last = best and { cols = best.cols, scale = L.Scale() }
      return
    end
    local s = Th.ScaleFor(w, h, d.bw, d.bh)
    if s and s ~= L.Scale() then L.SetScale(s) end
    d.last = { cols = L.Cols(), scale = s }
  end
  function L.StartDrag()
    if DB().locked then return false end
    local f = Frame()
    if not f then return false end
    local s = (f.GetScale and N(f:GetScale())) or 1
    local w, h = N(f:GetWidth()) or 0, N(f:GetHeight()) or 0
    local x, y = CursorUI()
    -- unités d'UIParent ; bw/bh = taille estimée à 100 % (3.3.12 : taille
    -- dynamique, le panneau reste à l'échelle 1 et grandit avec ses cases)
    local k = (L.Scale() or 100) / 100
    L.drag = { x = x, y = y, w = w * s, h = h * s, bw = w * s / k, bh = h * s / k, alt = AltDown() }
    if L.grip then L.grip:SetScript("OnUpdate", function() L.DragStep() end) end   -- seulement pendant le glisser
    return true
  end
  local baseStop = L.StopDrag
  function L.StopDrag(...)
    local r = { baseStop(...) }
    pcall(Th.UpdateHandles)
    return unpack(r)
  end
  function Th.StripGripTooltip()
    local g = L.grip
    if not g then return false end
    g:SetScript("OnEnter", function() if P and P.SetHover then P.SetHover(true) end end)
    g:SetScript("OnLeave", function() if P and P.SetHover then P.SetHover(false) end end)
    pcall(g.tex.SetTexture, g.tex, "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    g:SetScript("OnMouseDown", function(self)
      pcall(self.tex.SetTexture, self.tex, "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
      L.StartDrag()
    end)
    g:SetScript("OnMouseUp", function(self)
      pcall(self.tex.SetTexture, self.tex, "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
      L.StopDrag()
    end)
    g._thNoTip = true
    return true
  end
  local baseBG = L.BuildGrip
  function L.BuildGrip(...)
    local r = { baseBG(...) }
    pcall(Th.StripGripTooltip)
    pcall(Th.UpdateHandles)
    return unpack(r)
  end
  local basePG = L.PlaceGrip
  function L.PlaceGrip(...)
    local r = { basePG(...) }
    pcall(Th.UpdateHandles)
    return unpack(r)
  end
  if L.grip then pcall(Th.StripGripTooltip) end
end

------------------------------------------------------------------------------
-- 3.3.11 : pastille de la 1re rangée → marge du haut agrandie (plus coupée par
-- le bord du panneau). Recalé seulement quand cet état change.
------------------------------------------------------------------------------
Th.BORDER_ALLOW = 6   -- épaisseur visible du bord d'infobulle + 1 px d'air
function Th.TopRowBadge(gt)
  local UIx = ns.UI
  local H = ns.H or ns.Helpers
  for _, t in ipairs(UIx and UIx.embed and UIx.embed.tiles or {}) do
    local b = t.craftBadge
    if t.data and t.IsShown and t:IsShown() and b and b.IsShown and b:IsShown() then
      local top = t.GetTop and N(t:GetTop())
      if top and gt and math.abs(top - gt) < 1 then return true end
    end
  end
  return false
end
function Th.TopExtra(gt)
  if not Th.TopRowBadge(gt) then return 0 end
  local M = (ns.Layout and ns.Layout.MARGIN) or 10
  local need = (Th.BADGE_H - Th.BADGE_OVERLAP) + Th.BORDER_ALLOW
  return math.max(0, need - M)
end
if L then
  -- 3.5.16 : la place de la pastille « N prêts » reste réservée une fois vue
  -- (mémorisée) : son apparition avec un toast de recette ne décale plus la
  -- grille vers le bas
  L.TopExtra = function(gt)
    local e = Th.TopExtra(gt)
    local ui = ns.db and ns.db.ui
    if ui then
      if e > (tonumber(ui.topExtra) or 0) then ui.topExtra = e end
      e = math.max(e, tonumber(ui.topExtra) or 0)
    end
    L._topExtra = e
    return e
  end
end
if UI and UI.UpdateCraftBadge then
  local baseBadge = UI.UpdateCraftBadge
  function UI:UpdateCraftBadge(t, ...)
    local r = { baseBadge(self, t, ...) }
    local b = t and t.craftBadge
    -- au-dessus du cadre d'infobulle du panneau (jamais dessous)
    local f = Frame()
    if b and f and f._tipChrome and b.SetFrameLevel and f._tipChrome.GetFrameLevel then
      local need = (f._tipChrome:GetFrameLevel() or 0) + 10
      if (b:GetFrameLevel() or 0) < need then pcall(b.SetFrameLevel, b, need) end
    end
    -- état « pastille en 1re rangée » changé → recentrage (pas de calcul sinon)
    if L and L.Center and not Th._centering then
      local gt = select(3, L.GridRect())
      local ui = ns.db and ns.db.ui
      local want = math.max(Th.TopExtra(gt), (ui and tonumber(ui.topExtra)) or 0)
      if want ~= (L._topExtra or 0) then
        Th._centering = true
        pcall(L.Center)
        Th._centering = nil
      end
    end
    return unpack(r)
  end
end

-- état déjà construit (rechargement)
if P and P.handle then pcall(Th.StripHandleTooltip) end
if Frame() then pcall(Th.ApplyPanel) end

------------------------------------------------------------------------------
-- /drop theme cadre|sans
------------------------------------------------------------------------------
ns.SlashExt = ns.SlashExt or {}
local function Say(s) print(Tr["|cffffd100Dropamine|r "] .. s) end
ns.SlashExt.theme = function(rest)
  local a = (rest or ""):match("^%s*(%S*)") or ""
  if a == "" then Say(Tr["thème : "] .. Th.Mode() .. Tr[" (/drop theme flare|leger|classic)"]) return end
  local m = Th.Set(a)
  local DESC = { leger = Tr[" (léger : cases flottantes, sans fond ni bord)"], classic = Tr[" (classique : cadres et barres de l'interface Blizzard)"], flare = Tr[" (FlareUI : fond sombre + bord arrondi)"] }
  if m then Say(Tr["thème : "] .. m .. (DESC[m] or ""))
  else Say(Tr["usage : /drop theme flare|leger|classic (alias : cadre, sans, classique)"]) end
end
ns.SlashExt["thème"] = ns.SlashExt.theme

ns.HelpExt = ns.HelpExt or {}
ns.HelpExt[#ns.HelpExt + 1] = ("/drop theme flare|leger|classic — panneau FlareUI (fond + bord arrondi), léger (cases flottantes) ou classique (textures Blizzard)")

ns.DebugExt = ns.DebugExt or {}
ns.DebugExt[#ns.DebugExt + 1] = (function()
  local out = { "— Thème (3.3.10) —" }
  out[#out + 1] = "thème : " .. Th.Mode() .. " · cases stylées : " .. Th.stats.tiles
  local ms = {}
  for k, v in pairs(Th.stats.masks) do ms[#ms + 1] = k .. "=" .. v end
  out[#out + 1] = "coins : " .. (#ms > 0 and table.concat(ms, ", ") or "—")
  local L2 = ns.Layout
  out[#out + 1] = "poignée : " .. ((L2 and L2.grip and L2.grip._thNoTip) and "redimensionnement (sans infobulle)" or "—")
  out[#out + 1] = "toasts : " .. (Th.PanelShown() and "fond / bord / opacité du panneau" or "style propre (panneau caché)")
  return out
end)

-- 3.4.0 : Léger — le cadre ne revient jamais à l'ouverture du panneau
do
  local Wn = ns.Window
  if Wn and Wn.Show then
    local baseShow = Wn.Show
    function Wn.Show(...)
      local r = { baseShow(...) }
      if Th.IsSans() then pcall(Th.HideChrome) end
      return unpack(r)
    end
  end
end
