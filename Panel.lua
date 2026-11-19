-- Dropamine 3.3.5 — panneau compact permanent (façon onglet Compétences
-- d'OSRS), opacité,
-- bordures bronze mesurées, portrait du personnage sur la case Niveau.
--
-- Rien ici ne touche un cadre natif : on dessine NOS cadres et NOS textures.
local ADDON, ns = ...
local Tr = ns.L   -- 3.5.19 : textes traduits (Locales/)
local UI = ns.UI
local H = UI._H
local V = ns.View
local W = ns.Window
local I = ns.Icons
local SafeStep, SizeOf, RectOf = H.SafeStep, H.SizeOf, H.RectOf
local N = ns.N

local P = {}
ns.Panel = P
W.Panel = P

local function DB()
  if not ns.db then DropamineDB = DropamineDB or {} ns.db = DropamineDB end
  ns.db.ui = ns.db.ui or {}
  return ns.db.ui
end
P.DB = DB

------------------------------------------------------------------------------
-- 1) Bronze natif MESURÉ (refs/native-bronze-333.png : icônes de sorts et
--    barre « Main droite ») : filet clair 1 px (115,91,56) + ombre intérieure
--    1 px (66,52,34), soit 2 px. Remplace tout cadre gris de nos cases, du
--    panneau.
------------------------------------------------------------------------------
P.BRONZE = { outer = ns.STYLE.BORDER, inner = ns.STYLE.BORDER_INNER, px = 1, thickness = 2 }   -- 3.3.14 : jeton #A67D45 (était 115,91,56 : grisâtre)
W.COLORS.border = P.BRONZE.outer
W.BRONZE = P.BRONZE

local function Solid(t, c, a)
  if t.SetColorTexture then pcall(t.SetColorTexture, t, c[1], c[2], c[3], a or 1)
  else pcall(t.SetTexture, t, "Interface\\Buttons\\WHITE8X8") if t.SetVertexColor then pcall(t.SetVertexColor, t, c[1], c[2], c[3], a or 1) end end
  t._solid = { c[1], c[2], c[3], a or 1 }
  return t
end
P.Solid = Solid

-- Cadre bronze de 2 px tracé À L'INTÉRIEUR du rectangle de « target ».
-- sides : { top=, bottom=, left=, right= } (tous par défaut).
function P.BronzeBorder(owner, target, layer, sub, colors, sides)
  colors = colors or P.BRONZE
  local B = owner._bronze
  if not B then
    B = { outer = {}, inner = {} }
    for _, k in ipairs({ "top", "bottom", "left", "right" }) do
      B.outer[k] = owner:CreateTexture(nil, layer or "OVERLAY", nil, sub or 0)
      B.inner[k] = owner:CreateTexture(nil, layer or "OVERLAY", nil, sub or 0)
    end
    owner._bronze = B
  end
  B.target, B.colors = target, colors
  local px = colors.px or 1
  for ring, set in pairs({ outer = B.outer, inner = B.inner }) do
    local o = (ring == "outer") and 0 or px
    local c = colors[ring]
    for k, t in pairs(set) do
      Solid(t, c, 1)
      t:ClearAllPoints()
      if k == "top" then
        t:SetPoint("TOPLEFT", target, "TOPLEFT", o, -o) t:SetPoint("TOPRIGHT", target, "TOPRIGHT", -o, -o) t:SetHeight(px)
      elseif k == "bottom" then
        t:SetPoint("BOTTOMLEFT", target, "BOTTOMLEFT", o, o) t:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", -o, o) t:SetHeight(px)
      elseif k == "left" then
        t:SetPoint("TOPLEFT", target, "TOPLEFT", o, -o) t:SetPoint("BOTTOMLEFT", target, "BOTTOMLEFT", o, o) t:SetWidth(px)
      else
        t:SetPoint("TOPRIGHT", target, "TOPRIGHT", -o, -o) t:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", -o, o) t:SetWidth(px)
      end
      if sides and sides[k] == false then t:Hide() else t:Show() end
    end
  end
  return B
end

-- Cases : plus de cadre d'emplacement gris (UI-Quickslot2) ni de fond de sac
-- gris : fond sombre + cadre bronze 2 px autour de l'icône.
P.SLOT_BG = { 12 / 255, 9 / 255, 5 / 255 }
local baseResize = UI.ResizeTile
function UI:ResizeTile(t, tw, th)
  local r = { baseResize(self, t, tw, th) }
  if t and t._icon330 then
    if t.slotBorder then t.slotBorder:SetAlpha(0) t.slotBorder:Hide() end
    if t.slotBg then t.slotBg:SetAlpha(0) t.slotBg:Hide() end
    if not t.bg333 then t.bg333 = t:CreateTexture(nil, "BACKGROUND", nil, 1) end
    Solid(t.bg333, P.SLOT_BG, 1)
    t.bg333:ClearAllPoints()
    t.bg333:SetAllPoints(t.icon)
    t.bg333:Show()
    P.BronzeBorder(t, t.icon, "OVERLAY", 1)
  end
  return unpack(r)
end

-- Barre bleue du volet : filets du cadre en bronze (comme « Main droite »).
local baseSkin = V.SkinBar
function V.SkinBar(b, ...)
  local r = { baseSkin(b, ...) }
  if b and b.frame and b.edges then
    for _, e in pairs(b.edges) do if e.SetAlpha then e:SetAlpha(0) end end
    P.BronzeBorder(b.frame, b.frame, "OVERLAY", 2)
  end
  return unpack(r)
end

------------------------------------------------------------------------------
-- 2) Portrait du personnage sur la case Niveau (« mets l'image du personnage
--    comme image »), recadré carré ; repli : icône actuelle.
------------------------------------------------------------------------------
P.PORTRAIT_COORD = { 0.15, 0.85, 0.15, 0.85 }
function P.ApplyPortrait(t)
  if not (t and t.icon) then return false end
  if type(SetPortraitTexture) ~= "function" then t._portrait = nil return false end
  local ok = pcall(SetPortraitTexture, t.icon, "player")
  if not ok then t._portrait = nil return false end
  if t.icon.SetTexCoord then pcall(t.icon.SetTexCoord, t.icon, unpack(P.PORTRAIT_COORD)) end
  t._portrait = true
  return true
end
local baseUpdate = UI.UpdateTile
function UI:UpdateTile(t, d)
  local r = { baseUpdate(self, t, d) }
  if t and t._icon330 and d then
    if d.kind == "level" and not d.placeholder then
      if not P.ApplyPortrait(t) and t.icon.SetTexCoord then pcall(t.icon.SetTexCoord, t.icon, 0.07, 0.93, 0.07, 0.93) end
    elseif t._portrait then
      t._portrait = nil
      if t.icon.SetTexCoord then pcall(t.icon.SetTexCoord, t.icon, 0.07, 0.93, 0.07, 0.93) end
    end
    local ia = (DB().iconAlpha or 100) / 100
    if t.icon.SetAlpha then t.icon:SetAlpha(ia) end
  end
  return unpack(r)
end
function P.RefreshPortraits()
  for _, t in ipairs(UI.embed and UI.embed.tiles or {}) do
    if t.data and t.data.kind == "level" and t.IsShown and t:IsShown() then P.ApplyPortrait(t) end
  end
end
ns.On("UNIT_PORTRAIT_UPDATE", function(_, unit) if unit == nil or unit == "player" then P.RefreshPortraits() end end)
ns.On("PLAYER_ENTERING_WORLD", function() P.RefreshPortraits() end)

------------------------------------------------------------------------------
-- 4) Panneau compact permanent / déplié
------------------------------------------------------------------------------
-- Compact : la grille d'icônes seule (+ la petite ligne « Niveau total »),
-- sans titre ni texte, cadre brun foncé et bordure bronze, aucune capture de
-- souris hors des cases (le cadre ne prend pas la souris ; seule une fine
-- poignée en haut sert à le déplacer). Le chevron (ou un clic sur une case)
-- déplie le volet de détail ; Échap ne fait que le replier. Le panneau reste
-- ouvert d'une session à l'autre s'il l'était.
P.CPAD, P.CTOP = 8, 16
P.ESC_NAME = "DropamineEsc"
P.CHEVRON = { open = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up", openDown = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down",
  close = "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up", closeDown = "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down",
  hl = "Interface\\Buttons\\UI-Common-MouseHilight" }

-- 3.3.5 : plus de volet de détail ni de chevron (« quand on passe la souris
-- sur une compétence, c'est un mouseover qui fournit toutes les informations »).
-- Le panneau reste TOUJOURS compact ; DB().expanded est ignoré (et effacé).
function P.IsExpanded() return false end

-- position : TOPLEFT par rapport au coin bas-gauche d'UIParent (le panneau
-- grandit vers la droite / le bas en se dépliant, sans sauter)
function P.SavePos(f)
  local l, _, t = RectOf(f)
  -- 3.5.16 : au pixel entier (plus de dérive d'un demi-pixel à chaque mise en page)
  local Px = ns.Layout and ns.Layout.Px
  if Px then l, t = Px(l, f), Px(t, f) end
  if l and t then DB().winPos = { point = "TOPLEFT", relativePoint = "BOTTOMLEFT", x = l, y = t } end
end

function P.CompactListHeight()
  local n = UI.snapshot and UI.snapshot.tiles and #UI.snapshot.tiles or 9
  local ins = UI:ListInsets()
  local inner = W.LIST_W - ins.left - ins.right
  local cols = math.max(1, math.floor((inner + I.HGAP) / (I.TILE + I.HGAP)))
  local rows = math.max(1, math.ceil(n / cols))
  return ins.top + rows * I.STEP + 40, cols, rows
end

local function setShown(o, v) if o then if v then o:Show() else o:Hide() end end end

function P.ApplyMode()
  local f = W.frame
  if not f then return end
  local exp = P.IsExpanded()
  local list, detail = W.list, W.detail
  list:ClearAllPoints()
  if exp then
    f:SetSize(W.SIZE.w, W.SIZE.h)
    list:SetPoint("TOPLEFT", f, "TOPLEFT", W.PAD, -W.TOP)
    list:SetSize(W.LIST_W, W.SIZE.h - W.TOP - W.PAD)
    pcall(f.SetFrameStrata, f, "HIGH")
  else
    local lh = P.CompactListHeight()
    f:SetSize(W.LIST_W + 2 * P.CPAD, P.CTOP + lh + P.CPAD)
    list:SetPoint("TOPLEFT", f, "TOPLEFT", P.CPAD, -P.CTOP)
    list:SetSize(W.LIST_W, lh)
    pcall(f.SetFrameStrata, f, "MEDIUM")
  end
  setShown(detail, exp)
  setShown(W.title, exp) setShown(W.subtitle, exp) setShown(W.titleBar, exp)
  setShown(W.close, exp)
  setShown(W.divV, exp) setShown(W.divV2, exp)
  setShown(W.opSlider, exp) setShown(W.opLabel, exp)
  -- 3.3.5 : ni fond brun, ni filets de liste : seul l'habillage des toasts
  setShown(W.bg, false) setShown(W.listBg, false) setShown(W.divTop, false) setShown(W.divBottom, false)
  if UI.ownDetail and not exp then UI.ownDetail:Hide() end
  -- souris : déplié = comme avant ; compact = rien hors des cases / poignée
  f:EnableMouse(exp)
  P.PlaceChevron()
  P.handle:ClearAllPoints()
  P.handle:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  P.handle:SetPoint("TOPRIGHT", f, "TOPRIGHT", exp and -60 or 0, 0)
  P.handle:SetHeight(exp and 28 or P.CTOP)
  P.SyncEsc()
  W.mode = exp and "déplié" or "compact"
end

function P.PlaceChevron()
  local c = P.chevron
  if not c then return end
  local exp = P.IsExpanded()
  c:ClearAllPoints()
  if exp then c:SetPoint("TOPRIGHT", W.frame, "TOPRIGHT", -30, -6) else c:SetPoint("TOPRIGHT", W.frame, "TOPRIGHT", -3, 0) end
  local C = P.CHEVRON
  c:SetNormalTexture(exp and C.close or C.open)
  c:SetPushedTexture(exp and C.closeDown or C.openDown)
end

function P.SetExpanded(v, why)
  DB().expanded = nil
  P.lastToggle = why
  if W.frame and W.frame:IsShown() then
    P.ApplyMode()
    W.Layout()
  end
end
function P.ToggleExpanded(why) P.SetExpanded(not P.IsExpanded(), why) end

-- Échap : un petit cadre (le nôtre) inscrit dans UISpecialFrames, montré
-- seulement quand le volet est déplié ; Échap le cache → on replie.
-- Le panneau lui-même N'EST PLUS dans UISpecialFrames (il reste ouvert).
function P.SyncEsc()
  local e = P.esc
  if not e then return end
  local want = P.IsExpanded() and W.frame and W.frame:IsShown()
  P._escQuiet = true
  if want then e:Show() else e:Hide() end
  P._escQuiet = nil
end

local baseBuild = W.Build
function W.Build()
  if W.frame then return W.frame end
  local f = baseBuild()
  -- Échap ne ferme plus le panneau
  if type(UISpecialFrames) == "table" then
    for i = #UISpecialFrames, 1, -1 do if UISpecialFrames[i] == W.NAME then table.remove(UISpecialFrames, i) end end
  end
  -- 3.3.5 : plus de cadre Échap (il n'y a plus de détail à replier) ;
  -- Échap ne touche jamais le panneau.
  P.esc = nil
  -- 3.3.5 : habillage IDENTIQUE aux notifications (toasts) : même fond noir
  -- translucide, même bord (celui du chat Forever, repli Flare doré), posés
  -- par la MÊME fonction que les toasts (UI:ApplyDropFinish). Plus de fond
  -- brun plein ni de bordure bronze autour du panneau (les cases gardent
  -- leur cadre bronze).
  if f.SetBackdrop then pcall(f.SetBackdrop, f, nil) end
  W.backdrop = nil
  f._bdEdge = nil
  P.ApplyToastLook(f)
  SafeStep("cadre d'infobulle", P.ApplyTooltipLook, f)   -- 3.3.7 : même cadre que l'infobulle
  for _, t in ipairs({ W.divTop, W.divBottom, W.divV, W.detailDiv, W.titleBar and W.titleBar.line }) do
    if t then W.Tint(t, P.BRONZE.outer, 1) end
  end
  if W.bg then W.bg:ClearAllPoints() W.bg:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2) W.bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2) end
  -- glisser : verrouillable
  f:SetScript("OnDragStart", function(fr) if not DB().locked then fr:StartMoving() end end)
  f:SetScript("OnDragStop", function(fr) fr:StopMovingOrSizing() P.SavePos(fr) end)
  -- poignée (seule zone qui prend la souris hors des cases en mode compact)
  local h = CreateFrame("Frame", W.NAME .. "Handle", f)
  h._osrsOwn = true
  h:EnableMouse(true)
  h:RegisterForDrag("LeftButton")
  h:SetScript("OnDragStart", function() if not DB().locked then f:StartMoving() end end)
  h:SetScript("OnDragStop", function() f:StopMovingOrSizing() P.SavePos(f) end)
  h:SetScript("OnEnter", function(self)
    P.SetHover(true)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(W.TotalLine(), 1, 0.82, 0)
    GameTooltip:AddLine(DB().locked and Tr["Position verrouillée (/drop verrou off)"] or Tr["Glisser : déplacer"], 1, 1, 1)
    GameTooltip:Show()
  end)
  h:SetScript("OnLeave", function() P.SetHover(false) if GameTooltip then GameTooltip:Hide() end end)
  P.handle = h
  P.chevron = nil     -- 3.3.5 : plus de chevron (détail = infobulle au survol)
  if W.close then W.close:SetScript("OnClick", function() W.Hide() end) end
  P.BuildSlider(f)
  P.ApplyOpacity()
  P.ApplyMode()
  return f
end

-- La mise en page applique d'abord le mode (tailles), puis la grille.
local baseLayout = W.Layout
function W.Layout()
  if W.frame and W.frame:IsShown() then P.ApplyMode() end
  P._inLayout = true
  local ok, err = pcall(baseLayout)
  P._inLayout = nil
  if not ok then error(err, 0) end
  if W.frame and W.frame:IsShown() and not P.IsExpanded() then
    if UI.embed and UI.embed.EnableMouse then UI.embed:EnableMouse(false) end
    if UI.ownDetail then UI.ownDetail:Hide() end
  end
  P.ApplyOpacity()
end

-- Clic sur une case en mode compact : déplie le détail.
local baseSelect = UI.SelectTile
function UI:SelectTile(d, ...)
  return baseSelect(self, d, ...)     -- 3.3.5 : un clic ne déplie plus rien
end

-- Ouvert / fermé : mémorisé (le panneau peut rester ouvert en permanence).
local baseShow, baseHide, baseToggle = W.Show, W.Hide, W.Toggle
function W.Show(...) DB().panelOpen = true local r = baseShow(...) P.SyncEsc() return r end
function W.Hide(...) DB().panelOpen = nil local r = baseHide(...) P.SyncEsc() return r end
function W.Toggle(...)
  local r = baseToggle(...)
  DB().panelOpen = r and true or nil
  P.SyncEsc()
  return r
end
local baseHook = UI.HookSkillFrame
function UI:HookSkillFrame(...)
  local r = baseHook(self, ...)
  if DB().panelOpen and not W.IsShown() then SafeStep("panneau permanent", W.Show) end
  return r
end
local basePlace = W.PlaceDefault
function W.PlaceDefault(f)
  local p = DB().winPos
  if p and p.point == "TOPLEFT" and p.relativePoint == "BOTTOMLEFT" and N(p.x) and N(p.y) then
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p.x, p.y)
    W.posSource = "position mémorisée"
    return
  end
  return basePlace(f)
end

------------------------------------------------------------------------------
-- 5) Opacité du fond et du cadre (0–100 %), icônes et textes toujours nets
------------------------------------------------------------------------------
function P.Clamp(v, lo, hi)
  v = tonumber(v)
  if not v or v ~= v then return nil end
  v = math.floor(v + 0.5)
  if v < lo then v = lo elseif v > hi then v = hi end
  return v
end
-- 3.3.6 : FONDU AUTOMATIQUE façon compteur de dégâts (DPS meter) :
--   * AU REPOS, tout le panneau descend à l'opacité minimale (/drop opacite,
--     0-100 %, défaut 60) avec l'habillage « repos » (fond très transparent,
--     filet doré pâle) ;
--   * à CHAQUE GAIN (toast de compétence / XP / niveau, arrivée de l'éclat) ou
--     au SURVOL (une case, la poignée) : opacité pleine + habillage « survol »
--     (fond plus sombre, bord doré plein), fondu d'entrée 0,2 s ;
--   * puis, sans survol, retour au repos après /drop fondu secondes (défaut 3),
--     fondu de sortie 0,6 s.
-- L'attente est une minuterie C_Timer (aucun OnUpdate) ; seul le fondu lui-même
-- (≤ 0,6 s) utilise un OnUpdate, retiré dès la fin. Les captures du compteur
-- n'étaient pas lisibles sur la machine de build : valeurs ci-dessous estimées,
-- réglables ici.
P.DEFAULT_OPACITY, P.DEFAULT_FADE = 60, 3
function P.Opacity() return P.Clamp(DB().opacity, 0, 100) or P.DEFAULT_OPACITY end
function P.FadeDelay() return P.Clamp(DB().fadeDelay, 0, 60) or P.DEFAULT_FADE end
-- 3.3.8 : FOND à l'état actif (survol / gain) = alpha ABSOLU du fond, réglable
-- (/drop fond <0-100>, mémorisé) : plus clair / translucide, comme les fenêtres
-- du compteur de dégâts. Le repos garde son aspect (jamais plus opaque que l'actif) ;
-- le bord doré reste plein.
P.DEFAULT_BG = 45
function P.BgAlpha() return P.Clamp(DB().bgAlpha, 0, 100) or P.DEFAULT_BG end
-- multiplicateurs (× alpha natif du fond) repos / actif pour un fond d'alpha a0
function P.BgMuls(a0, idleMul)
  a0 = (a0 and a0 > 0) and a0 or 1
  local hover = (P.BgAlpha() / 100) / a0
  return math.min(idleMul, hover), hover
end
P.LOOK = {
  idle = { bg = 0.40, border = 0.45 },    -- × alpha du fond des toasts / du bord
  hover = { bg = 2.20, border = 1.00 },   -- fond sombre, bord plein
  fadeIn = 0.20, fadeOut = 0.60,
}
function P.ApplyToastLook(f)
  f._osrsPanel = true   -- 3.3.9 : le panneau reçoit la bordure via P.ApplyTooltipLook (pas celle des toasts)
  local before = {}
  for _, r in ipairs({ f:GetRegions() }) do before[r] = true end
  if UI.ApplyDropFinish then UI:ApplyDropFinish(f) end
  local bg, border = {}, {}
  for _, r in ipairs({ f:GetRegions() }) do
    if not before[r] and r ~= f._toastBg then border[#border + 1] = r end
  end
  -- pièces réutilisées (2e appel) : les reprendre
  for _, t in pairs(f._chatPieces or {}) do local dup = false for _, x in ipairs(border) do if x == t then dup = true end end if not dup then border[#border + 1] = t end end
  if f._toastBg then bg[1] = f._toastBg end
  -- couleur de fond des toasts (noir, alpha du chat ou réglage des drops)
  local base = { 0, 0, 0, 0.35 }
  local cc = UI.LearnChatChrome and UI:LearnChatChrome()
  if cc and cc.bgColor then base = { cc.bgColor[1], cc.bgColor[2], cc.bgColor[3], cc.bgColor[4] } end
  local ua = UI.DropBgAlpha and UI:DropBgAlpha()
  if ua then base[4] = ua end
  P.toast = { bg = bg, border = border, source = f._osrsNativeBorder, bgColor = base }
  W.toastLook = f._osrsNativeBorder
  return P.toast
end
-- 3.3.7 : le cadre du panneau = EXACTEMENT celui de l'infobulle (GameTooltip)
-- de ce client (« le cadre de l'infobulle est parfait »). Lecture seule de
-- GameTooltip (jamais modifié) ; NOTRE cadre enfant reçoit le même dessin :
--   1) NineSlice : même disposition (NineSliceUtil.ApplyLayoutByName avec le
--      layoutType lu sur GameTooltip.NineSlice) ;
--   2) sinon copie pièce par pièce (atlas ou fichier + coordonnées, tailles,
--      décalages des coins) des 9 pièces de GameTooltip.NineSlice ;
--   3) sinon même backdrop (GameTooltip:GetBackdrop(), BackdropTemplate) ;
--   4) sinon constantes du client (TOOLTIP_BACKDROP_STYLE_DEFAULT) ;
--   5) sinon l'habillage des toasts (3.3.5) reste.
-- Couleurs : celles LUES sur l'infobulle (bord, fond). Survol = infobulle à
-- l'identique ; repos = fond et bord atténués (P.LOOK_TIP), fondu inchangé.
P.TIP_PIECES = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center" }
-- 3.3.11 : le BORD n'est jamais atténué (bord pâle / délavé au repos en 3.3.10) :
-- seul le fond suit /drop fond ; le panneau entier suit /drop opacite (alpha du cadre).
P.LOOK_TIP = { idle = { bg = 0.45, border = 1.00 }, hover = { bg = 1.00, border = 1.00 } }
local function Col(obj, getter)
  if not obj or type(obj[getter]) ~= "function" then return nil end
  local ok, r, g, b, a = pcall(obj[getter], obj)
  if ok and N(r) then return { r, g, b, N(a) or 1 } end
end
-- 3.3.10 : l'art est relu, jamais les couleurs (teinte live de GameTooltip)
local baseReadArt
function P.ReadTooltipArt()
  local art, why = baseReadArt()
  if type(art) == "table" then
    local Ch = ns.Chrome
    local bc, cc = { 1, 1, 1, 1 }, { 0.09, 0.09, 0.19, 1 }
    if Ch and Ch.TipColors then bc, cc = Ch.TipColors() end
    art.border, art.center = bc, cc
    for _, e in pairs(art.pieces or {}) do e.color = nil end
  end
  return art, why
end
function baseReadArt()
  local tt = _G.GameTooltip
  if type(tt) ~= "table" then return nil, "pas de GameTooltip" end
  local nsl = rawget(tt, "NineSlice")
  if type(nsl) == "table" then
    local art = { mode = "nineslice", layout = rawget(nsl, "layoutType") or rawget(tt, "layoutType"), pieces = {} }
    for _, k in ipairs(P.TIP_PIECES) do
      local pc = rawget(nsl, k)
      if type(pc) == "table" then
        local e = { name = k }
        e.atlas = pc.GetAtlas and select(2, pcall(pc.GetAtlas, pc)) or nil
        if type(e.atlas) ~= "string" or e.atlas == "" then e.atlas = nil end
        e.file = pc.GetTexture and select(2, pcall(pc.GetTexture, pc)) or nil
        if pc.GetTexCoord then local ok, a, b, c, d, e2, f2, g, h = pcall(pc.GetTexCoord, pc) if ok and N(a) then e.coord = { a, b, c, d, e2, f2, g, h } end end
        if pc.GetSize then local ok, w, h = pcall(pc.GetSize, pc) if ok then e.w, e.h = N(w), N(h) end end
        if pc.GetPoint then local ok, pt, _, rp, x, y = pcall(pc.GetPoint, pc, 1) if ok then e.point, e.rel, e.x, e.y = pt, rp, N(x) or 0, N(y) or 0 end end
        e.color = Col(pc, "GetVertexColor")
        art.pieces[k] = e
      end
    end
    art.border = Col(nsl, "GetBorderColor") or (art.pieces.TopEdge and art.pieces.TopEdge.color)
    art.center = Col(nsl, "GetCenterColor") or (art.pieces.Center and art.pieces.Center.color)
    if art.layout or next(art.pieces) then return art end
  end
  if tt.GetBackdrop then
    local ok, bd = pcall(tt.GetBackdrop, tt)
    if ok and type(bd) == "table" and (bd.edgeFile or bd.bgFile) then
      return { mode = "backdrop", backdrop = bd, border = Col(tt, "GetBackdropBorderColor"), center = Col(tt, "GetBackdropColor") }
    end
  end
  local cst = rawget(_G, "TOOLTIP_BACKDROP_STYLE_DEFAULT")
  if type(cst) == "table" then
    local bd = { bgFile = cst.bgFile or "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = cst.edgeFile or "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileEdge = cst.tileEdge, tileSize = cst.tileSize or 16, edgeSize = cst.edgeSize or 16, insets = cst.insets or { left = 5, right = 5, top = 5, bottom = 5 } }
    local bc, cc = cst.backdropBorderColor, cst.backdropColor
    local function C2(c, d) if type(c) == "table" then return { N(c.r) or c[1] or d[1], N(c.g) or c[2] or d[2], N(c.b) or c[3] or d[3], N(c.a) or c[4] or d[4] } end return d end
    return { mode = "constantes", backdrop = bd, border = C2(bc, { 1, 1, 1, 1 }), center = C2(cc, { 0.09, 0.09, 0.19, 1 }) }
  end
  return nil, "aucun dessin d'infobulle lisible"
end

local CORNER = { TopLeftCorner = "TOPLEFT", TopRightCorner = "TOPRIGHT", BottomLeftCorner = "BOTTOMLEFT", BottomRightCorner = "BOTTOMRIGHT" }
local function CopyPiece(host, e)
  local t = host:CreateTexture(nil, e.name == "Center" and "BACKGROUND" or "BORDER")
  if e.atlas and t.SetAtlas then pcall(t.SetAtlas, t, e.atlas, false)
  elseif e.file then pcall(t.SetTexture, t, e.file) if e.coord and t.SetTexCoord then pcall(t.SetTexCoord, t, unpack(e.coord)) end end
  return t
end
function P.BuildTipPieces(host, art)
  local P9 = art.pieces
  local made = {}
  for _, k in ipairs(P.TIP_PIECES) do if P9[k] then made[k] = CopyPiece(host, P9[k]) end end
  for k, pt in pairs(CORNER) do
    local t, e = made[k], P9[k]
    if t then
      if e.w and e.h then t:SetSize(e.w, e.h) end
      t:SetPoint(pt, host, pt, (e.point == pt and e.x) or 0, (e.point == pt and e.y) or 0)
    end
  end
  local function between(k, a1, c1, a2, c2, thick, horiz)
    local t = made[k]
    if not t then return end
    local A, B = made[c1], made[c2]
    if A then t:SetPoint(a1, A, (horiz and (a1:gsub("LEFT", "RIGHT"))) or (a1:gsub("TOP", "BOTTOM")), 0, 0) else t:SetPoint(a1, host, a1, 0, 0) end
    if B then t:SetPoint(a2, B, (horiz and (a2:gsub("RIGHT", "LEFT"))) or (a2:gsub("BOTTOM", "TOP")), 0, 0) else t:SetPoint(a2, host, a2, 0, 0) end
    if thick then if horiz then t:SetHeight(thick) else t:SetWidth(thick) end end
  end
  between("TopEdge", "TOPLEFT", "TopLeftCorner", "TOPRIGHT", "TopRightCorner", P9.TopEdge and P9.TopEdge.h, true)
  between("BottomEdge", "BOTTOMLEFT", "BottomLeftCorner", "BOTTOMRIGHT", "BottomRightCorner", P9.BottomEdge and P9.BottomEdge.h, true)
  between("LeftEdge", "TOPLEFT", "TopLeftCorner", "BOTTOMLEFT", "BottomLeftCorner", P9.LeftEdge and P9.LeftEdge.w, false)
  between("RightEdge", "TOPRIGHT", "TopRightCorner", "BOTTOMRIGHT", "BottomRightCorner", P9.RightEdge and P9.RightEdge.w, false)
  if made.Center then
    local e = P9.Center
    if made.TopLeftCorner and made.BottomRightCorner and e.point ~= "TOPLEFT" then
      made.Center:SetPoint("TOPLEFT", made.TopLeftCorner, "BOTTOMRIGHT", 0, 0)
      made.Center:SetPoint("BOTTOMRIGHT", made.BottomRightCorner, "TOPLEFT", 0, 0)
    else
      made.Center:SetPoint("TOPLEFT", host, "TOPLEFT", e.x or 0, e.y or 0)
      made.Center:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -(e.x or 0), -(e.y or 0))
    end
  end
  return made
end

function P.ApplyTooltipLook(f)
  W.tipLook = nil
  -- 3.3.9 : d'abord la mise en page NineSlice de l'infobulle elle-même
  -- (Chrome.lua : même art, coins à taille native, lissés) ; sinon l'ancien chemin.
  local Ch = ns.Chrome
  if Ch and Ch.Apply then
    local okC, c = pcall(Ch.Apply, f)
    if okC and c and c.center then
      P.tip = { mode = c.mode, bg = { c.center }, border = c.border, bgColor = c.centerColor, borderColor = c.borderColor, chrome = c }
      local T = P.toast
      if T then for _, t in ipairs(T.bg) do if t.Hide then t:Hide() end end for _, t in ipairs(T.border) do if t.Hide then t:Hide() end end end
      W.tipLook = P.tip.mode
      return P.tip
    end
  end
  local art, why = P.ReadTooltipArt()
  if not art then W.tipLookWhy = why return nil end
  local host = f._tipChrome
  if not host then
    host = CreateFrame("Frame", nil, f, (art.mode ~= "nineslice") and (_G.BackdropTemplateMixin and "BackdropTemplate" or nil) or nil)
    host._osrsOwn = true
    if host.EnableMouse then host:EnableMouse(false) end
    host:SetAllPoints(f)
    pcall(host.SetFrameLevel, host, math.max(0, (f.GetFrameLevel and f:GetFrameLevel() or 1)))
    f._tipChrome = host
  end
  local bgT, edT, mode = {}, {}, art.mode
  if art.mode == "nineslice" then
    local util = rawget(_G, "NineSliceUtil")
    local applied = false
    if art.layout and type(util) == "table" and type(util.ApplyLayoutByName) == "function" then
      applied = pcall(util.ApplyLayoutByName, host, art.layout)
      if applied then
        for _, k in ipairs(P.TIP_PIECES) do
          local pc = rawget(host, k)
          if pc then if k == "Center" then bgT[#bgT + 1] = pc else edT[#edT + 1] = pc end end
        end
        mode = "NineSlice « " .. tostring(art.layout) .. " »"
        if #edT == 0 then applied = false end
      end
    end
    if not applied then
      local made = P.BuildTipPieces(host, art)
      for k, t in pairs(made) do if k == "Center" then bgT[#bgT + 1] = t else edT[#edT + 1] = t end end
      mode = "pièces copiées de GameTooltip.NineSlice"
    end
    local bc, cc = art.border or { 1, 1, 1, 1 }, art.center or { 0, 0, 0, 0.8 }
    for _, t in ipairs(edT) do if t.SetVertexColor then pcall(t.SetVertexColor, t, bc[1], bc[2], bc[3], 1) end end
    for _, t in ipairs(bgT) do if t.SetVertexColor then pcall(t.SetVertexColor, t, cc[1], cc[2], cc[3], 1) end end
    P.tip = { mode = mode, bg = bgT, border = edT, bgColor = cc, borderColor = bc, art = art }
  else
    if not host.SetBackdrop and _G.BackdropTemplateMixin and _G.Mixin then pcall(_G.Mixin, host, _G.BackdropTemplateMixin) end
    if not (host.SetBackdrop and pcall(host.SetBackdrop, host, art.backdrop)) then W.tipLookWhy = "SetBackdrop indisponible" return nil end
    local bc, cc = art.border or { 1, 1, 1, 1 }, art.center or { 0, 0, 0, 0.8 }
    P.tip = { mode = (art.mode == "backdrop") and "backdrop de GameTooltip" or "constantes TOOLTIP_BACKDROP_STYLE_DEFAULT", host = host,
      bgColor = cc, borderColor = bc, art = art }
  end
  -- l'habillage des toasts (3.3.5) s'efface : un seul cadre
  local T = P.toast
  if T then for _, t in ipairs(T.bg) do if t.Hide then t:Hide() end end for _, t in ipairs(T.border) do if t.Hide then t:Hide() end end end
  W.tipLook = P.tip.mode
  return P.tip
end
-- Couleurs relues quand NOTRE infobulle vient de s'afficher (le client peut
-- poser le style de l'infobulle à l'affichage) ; rien n'est reconstruit.
function P.RefreshTipColors()
  local X = P.tip
  if not X or P._tipColorsRead then return false end
  local art = P.ReadTooltipArt()
  if not art then return false end
  P._tipColorsRead = true
  X.borderColor, X.bgColor = art.border or X.borderColor, art.center or X.bgColor
  if not X.host then
    local bc, cc = X.borderColor, X.bgColor
    for _, t in ipairs(X.border) do if t.SetVertexColor then pcall(t.SetVertexColor, t, bc[1], bc[2], bc[3], 1) end end
    for _, t in ipairs(X.bg) do if t.SetVertexColor then pcall(t.SetVertexColor, t, cc[1], cc[2], cc[3], 1) end end
  end
  P.ApplyOpacity()
  return true
end
function P.ApplyTipAlpha(kb, kr)
  kr = 1   -- 3.3.11 : bord plein, identique à l'infobulle (pas de multiplication par le fondu)
  local X = P.tip
  local cc, bc = X.bgColor, X.borderColor
  local ba = math.min(1, (cc[4] or 1) * kb)
  if X.host then
    pcall(X.host.SetBackdropColor, X.host, cc[1], cc[2], cc[3], ba)
    pcall(X.host.SetBackdropBorderColor, X.host, bc[1], bc[2], bc[3], math.min(1, (bc[4] or 1) * kr))
  else
    for _, t in ipairs(X.bg) do if t.SetAlpha then t:SetAlpha(ba) end t._bgAlpha = ba end
    for _, t in ipairs(X.border) do if t.SetAlpha then t:SetAlpha(math.min(1, (bc[4] or 1) * kr)) end end
  end
  X.bgAlpha, X.borderAlpha = ba, math.min(1, (bc[4] or 1) * kr)
end

function P.ChromeTextures()
  local out = {}
  local T = P.toast
  if T then for _, t in ipairs(T.bg) do out[#out + 1] = t end for _, t in ipairs(T.border) do out[#out + 1] = t end end
  return out
end
function P.StateMix()
  local k = P._mix or 0          -- 0 = repos, 1 = actif (gain / survol)
  local L = P.LOOK
  return L.idle.bg + (L.hover.bg - L.idle.bg) * k, L.idle.border + (L.hover.border - L.idle.border) * k
end
-- Opacité du PANNEAU entier : repos = /drop opacite, actif = 100 %.
function P.FrameAlpha()
  local a = P.Opacity() / 100
  local k = P._mix or 0
  return a + (1 - a) * k
end
function P.ApplyOpacity()
  local f = W.frame
  if not f then return end
  local kb, kr = P.StateMix()
  local T = P.toast
  if P.tip then
    local k = P._mix or 0
    local L = P.LOOK_TIP
    local bi, bh = P.BgMuls(P.tip.bgColor and P.tip.bgColor[4], L.idle.bg)
    P.ApplyTipAlpha(bi + (bh - bi) * k, L.idle.border + (L.hover.border - L.idle.border) * k)
    T = nil
  end
  if T then
    local c = T.bgColor
    local bi, bh = P.BgMuls(c[4], P.LOOK.idle.bg)
    kb = bi + (bh - bi) * (P._mix or 0)
    local ba = math.min(1, c[4] * kb)
    for _, t in ipairs(T.bg) do
      local done = t.SetColorTexture and pcall(t.SetColorTexture, t, c[1], c[2], c[3], ba)
      if not done then
        pcall(t.SetTexture, t, "Interface\\Buttons\\WHITE8X8")
        if t.SetVertexColor then pcall(t.SetVertexColor, t, c[1], c[2], c[3], ba) end
      end
      if t.SetAlpha then t:SetAlpha(1) end
      t._bgAlpha = ba
    end
    for _, t in ipairs(T.border) do if t.SetAlpha then t:SetAlpha(1) end end   -- 3.3.11 : bord jamais atténué
  end
  local fa = P.FrameAlpha()
  if f.SetAlpha then f:SetAlpha(fa) end
  W.frameAlpha = fa
  W.chromeAlpha = P.Opacity() / 100
  W.chromeState = (P._mix or 0) >= 0.999 and "survol" or ((P._mix or 0) <= 0.001 and "repos" or "fondu")
  if P.slider and not P._sliding then P._setSlider = true pcall(P.slider.SetValue, P.slider, P.Opacity()) P._setSlider = nil end
end
local function Now() return (type(GetTime) == "function" and GetTime()) or 0 end
local function After(sec, fn)
  if type(C_Timer) == "table" and type(C_Timer.After) == "function" then C_Timer.After(sec, fn) return true end
  return false
end
-- Retour au repos programmé (jeton : seule la DERNIÈRE demande compte).
function P.ScheduleSleep()
  P._sleepToken = (P._sleepToken or 0) + 1
  local tok = P._sleepToken
  P._sleepAt = Now() + P.FadeDelay()
  local function go()
    if tok ~= P._sleepToken or P._hoverWant then return end
    P._sleepAt = nil
    P._target = 0
    P.StartFade()
  end
  if not After(P.FadeDelay(), go) then go() end
end
function P.Wake(reason)
  P.lastWake = reason or "gain"
  P.wakes = (P.wakes or 0) + 1
  P._target = 1
  P.StartFade()
  if not P._hoverWant then P.ScheduleSleep() end
end
-- Survol : une case ou la poignée → état actif ; sortie → repos après le délai.
function P.SetHover(on)
  P._hoverWant = on and true or false
  if on then
    P._sleepToken = (P._sleepToken or 0) + 1   -- annule un retour au repos en attente
    P._sleepAt = nil
    -- 3.5.3 : déjà pleinement actif (case → case voisine) : rien à repeindre
    if (P._mix or 0) >= 1 and (P._target or 0) >= 1 then return end
    P._target = 1
    P.StartFade()
  else
    P.ScheduleSleep()
  end
end
function P.StepFade(elapsed)
  local target = P._target or 0
  local m = P._mix or 0
  local dur = (target > m) and P.LOOK.fadeIn or P.LOOK.fadeOut
  local step = (elapsed or 0.03) / math.max(0.01, dur)
  if m < target then m = math.min(target, m + step) elseif m > target then m = math.max(target, m - step) end
  P._mix = m
  P.ApplyOpacity()
  return m == target
end
function P.StartFade()
  local d = P.fader
  if not d then
    d = CreateFrame("Frame", nil, UIParent)
    d._osrsOwn = true
    if d.EnableMouse then d:EnableMouse(false) end
    P.fader = d
  end
  if (P._mix or 0) == (P._target or 0) then d:SetScript("OnUpdate", nil) P.ApplyOpacity() return end
  d:SetScript("OnUpdate", function(self, el) if P.StepFade(el) then self:SetScript("OnUpdate", nil) end end)
end
function P.SetOpacity(v)
  local c = P.Clamp(v, 0, 100)
  if not c then return nil end
  DB().opacity = c
  P.ApplyOpacity()
  return c
end
function P.SetBgAlpha(v)
  local c = P.Clamp(v, 0, 100)
  if not c then return nil end
  DB().bgAlpha = c
  P.ApplyOpacity()
  return c
end
function P.SetFadeDelay(v)
  local c = P.Clamp(v, 0, 60)
  if not c then return nil end
  DB().fadeDelay = c
  return c
end
function P.SetIconAlpha(v)
  local c = P.Clamp(v, 20, 100)
  if not c then return nil end
  DB().iconAlpha = c
  for _, t in ipairs(UI.embed and UI.embed.tiles or {}) do if t.icon and t.icon.SetAlpha then t.icon:SetAlpha(c / 100) end end
  return c
end

function P.BuildSlider(f)
  local ok, sl = pcall(CreateFrame, "Slider", W.NAME .. "Opacity", f, "OptionsSliderTemplate")
  if not (ok and sl) then ok, sl = pcall(CreateFrame, "Slider", W.NAME .. "Opacity", f) end
  if not (ok and sl) then return end
  sl._osrsOwn = true
  sl:SetSize(90, 14)
  sl:SetPoint("TOPRIGHT", f, "TOPRIGHT", -56, -10)
  pcall(sl.SetOrientation, sl, "HORIZONTAL")
  pcall(sl.SetMinMaxValues, sl, 0, 100)
  pcall(sl.SetValueStep, sl, 5)
  pcall(sl.SetObeyStepOnDrag, sl, true)
  for _, k in ipairs({ "Low", "High", "Text" }) do
    local fs = rawget(sl, k) or _G[W.NAME .. "Opacity" .. k]
    if type(fs) == "table" and fs.SetText then fs:SetText("") end
  end
  sl:SetScript("OnValueChanged", function(_, v)
    if P._setSlider then return end
    P._sliding = true
    P.SetOpacity(v)
    P._sliding = nil
  end)
  local lab = H.Text(f, "GameFontHighlightSmall", "RIGHT")
  lab:SetPoint("RIGHT", sl, "LEFT", -6, 0)
  lab:SetText(Tr["Opacité"])
  P.slider, W.opSlider, W.opLabel = sl, sl, lab
end

------------------------------------------------------------------------------
-- 6) Commandes
------------------------------------------------------------------------------
ns.SlashExt = ns.SlashExt or {}
local function say(m) print(Tr["|cffffd100Dropamine|r : "] .. m) end
ns.SlashExt.opacite = function(rest)
  rest = (rest or ""):lower()
  local which, val = rest:match("^(%a+)%s+(%S+)$")
  if which == "icones" or which == "icônes" then
    local c = P.SetIconAlpha(val)
    say(c and (Tr["opacité des icônes : "] .. c .. " %") or Tr["usage : /drop opacite icones <20-100>"])
    return
  end
  local c = P.SetOpacity(rest:match("^%s*(%-?[%d%.]+)"))
  if c then say(Tr["opacité au repos : "] .. c .. Tr[" % (100 % au survol et à chaque gain)"]) else say(Tr["opacité au repos : "] .. P.Opacity() .. Tr[" % (usage : /drop opacite <0-100>)"]) end
end
ns.SlashExt.fondu = function(rest)
  local c = P.SetFadeDelay((rest or ""):match("^%s*(%-?[%d%.]+)"))
  if c then say(Tr["retour au repos après "] .. c .. Tr[" s sans survol ni gain"]) else say(Tr["fondu : "] .. P.FadeDelay() .. Tr[" s (usage : /drop fondu <0-60>)"]) end
end
ns.SlashExt.fond = function(rest)
  local c = P.SetBgAlpha((rest or ""):match("^%s*(%-?[%d%.]+)"))
  if c then say(Tr["fond à l'état actif : "] .. c .. Tr[" % (bord doré inchangé)"]) else say(Tr["fond : "] .. P.BgAlpha() .. Tr[" % (usage : /drop fond <0-100>)"]) end
end
ns.SlashExt["opacité"] = ns.SlashExt.opacite
ns.SlashExt.verrou = function(rest)
  rest = (rest or ""):lower()
  if rest == "on" then DB().locked = true elseif rest == "off" then DB().locked = nil else DB().locked = (not DB().locked) or nil end
  say(DB().locked and Tr["panneau verrouillé"] or Tr["panneau déplaçable"])
end
-- 3.3.5 : commandes devenues sans objet, gardées pour ne pas surprendre
local function noDetail() say(Tr["plus de volet de détail : passe la souris sur une case pour tout voir (infobulle)"]) end
ns.SlashExt.deplier = function() if not W.IsShown() then W.Show() end noDetail() end
ns.SlashExt.replier = noDetail

local baseDebug = W.DebugLines
W.DebugLines = function()
  local out = baseDebug()
  out[#out + 1] = "  panneau : " .. tostring(W.mode) .. (DB().panelOpen and ", ouvert en permanence" or "") .. (DB().locked and ", verrouillé" or "")
    .. ", opacité " .. P.Opacity() .. " %, icônes " .. tostring(DB().iconAlpha or 100) .. " %"
  return out
end

------------------------------------------------------------------------------
-- 7) 3.3.4 : « le total devrait avoir une case à lui, comme ça on trie toutes
--    les cases en colonnes égales ». Niveau total = DERNIÈRE case de la grille
--    (comme la case Total level d'OSRS) ; plus de ligne du bas.
--    9 compétences + total = 10 cases → rectangle plein 5 colonnes × 2 rangées
--    (10 ne se divise qu'en 2 ou 5 colonnes ; 5×2 garde le panneau compact
--    large et bas, 278 × 126 px, au lieu d'une colonne haute de 5 rangées, et
--    la grille 5 colonnes existante ne change pas de largeur).
------------------------------------------------------------------------------
UI.NO_FOOT = true
P.TOTAL_ICON = "Interface\\AddOns\\Dropamine\\Media\\SkillsTab"   -- 3.5.20 : La Fiole (pas le portrait)
function P.TotalTile()
  local d = UI.TOTAL_DATA
  local snap = UI.snapshot
  d.kind, d.id, d.name, d.key = "total", "total", Tr["Niveau total"], "total"
  d.current = snap and snap.total or 0
  d.apiMax = (snap and snap.totalMax) or ns.TOTAL_MAX or 2460
  d.icon = P.TOTAL_ICON
  d.placeholder = nil
  return d
end
local baseGroup = UI.GroupTiles
function UI:GroupTiles(tiles)
  local groups = baseGroup(self, tiles)
  if #groups > 0 then
    local g = groups[#groups]
    local has = false
    for _, d in ipairs(g.tiles) do if d.kind == "total" then has = true end end
    if not has then
      local copy = {}
      for i, d in ipairs(g.tiles) do copy[i] = d end
      copy[#copy + 1] = P.TotalTile()
      groups[#groups] = { title = g.title, tiles = copy, flat = g.flat }
    end
  end
  return groups
end
local function hideFoot(wrap)
  if not wrap then return end
  if wrap.foot then wrap.foot:Hide() if wrap.foot.EnableMouse then wrap.foot:EnableMouse(false) end end
  if wrap.totalFS then wrap.totalFS:Hide() end
end
local baseFooter = UI.LayoutFooter
function UI:LayoutFooter(wrap, ...)
  local r = { baseFooter(self, wrap, ...) }
  hideFoot(wrap)
  return unpack(r)
end
local baseGrid = UI.LayoutGrid
function UI:LayoutGrid(wrap, snap)
  local r = { baseGrid(self, wrap, snap) }
  hideFoot(wrap)
  return unpack(r)
end
function P.CompactListHeight()
  local n = (UI.snapshot and UI.snapshot.tiles and #UI.snapshot.tiles or 9) + 1
  local ins = UI:ListInsets()
  local inner = W.LIST_W - ins.left - ins.right
  local cols = math.max(1, math.floor((inner + I.HGAP) / (I.TILE + I.HGAP)))
  local rows = math.max(1, math.ceil(n / cols))
  return ins.top + rows * I.STEP + 4, cols, rows
end
