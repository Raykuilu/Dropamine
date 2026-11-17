-- Dropamine 3.3.17 : 3e thème « classic » (/drop theme classic). Uniquement des
-- textures DU JEU, appelées par leur chemin (aucune copie dans Media/) :
--   • panneau / toasts : bord d'infobulle Interface\Tooltips\UI-Tooltip-Border
--     (16 px, marges 4) sur fond Interface\Tooltips\UI-Tooltip-Background sombre,
--     teinte neutre (gris clair) comme les infobulles par défaut ;
--   • cases : cadre de bouton d'action Interface\Buttons\UI-Quickslot2 (66 px
--     pour une icône de 36, décalé de 1 px vers le bas comme ActionButtonTemplate),
--     icône carrée, chiffres « NumberFont » contournés (OUTLINE) ;
--     appui = UI-Quickslot-Depress, cible = cadre teinté vert, sélection = or ;
--   • barre du total : Interface\TargetingFrame\UI-StatusBar (piste sombre,
--     remplissage bleu « compétence »), bord d'infobulle fin autour.
-- Le thème FlareUI (défaut) n'est pas touché : tout est rétabli en repassant
-- à flare / leger. Aucun OnUpdate ; tout est posé au changement de thème et
-- aux mises à jour de case / de barre.
local _, ns = ...
local Th, Sk, I, Wd, UI, Po = ns.Theme, ns.Skin, ns.Icons, ns.Wide, ns.UI, ns.Polish
local Cl = {}
ns.Classic = Cl
Cl.EDGE_FILE = "Interface\\Tooltips\\UI-Tooltip-Border"
Cl.BG_FILE = "Interface\\Tooltips\\UI-Tooltip-Background"
Cl.EDGE_SIZE, Cl.INSET = 16, 4
Cl.TINT = { 0.80, 0.80, 0.80, 1 }          -- bord d'infobulle par défaut (gris clair)
Cl.BG = { 0.06, 0.06, 0.08, 1 }            -- fond d'infobulle sombre (alpha = /drop fond)
Cl.SLOT = "Interface\\Buttons\\UI-Quickslot2"
Cl.SLOT_DOWN = "Interface\\Buttons\\UI-Quickslot-Depress"
Cl.SLOT_K = 66 / 36                        -- ActionButtonTemplate : NormalTexture 66 × 66 pour 36
Cl.BAR_TEX = "Interface\\TargetingFrame\\UI-StatusBar"
Cl.BAR_FILL = { 0.25, 0.40, 0.90, 1 }      -- bleu des barres de compétence
Cl.BAR_TRACK = { 0.10, 0.10, 0.12, 0.85 }
Cl.BAR_EDGE = { 0.70, 0.70, 0.70, 1 }
Cl.GREEN = { 0.25, 1, 0.25 }
Cl.GOLD = { 1, 0.82, 0 }
local MASK_NONE = "Interface\\Buttons\\WHITE8X8"
local function On() return Th and Th.Mode and Th.Mode() == "classic" end
Cl.On = On
Cl.stats = { tiles = 0, applies = 0 }

------------------------------------------------------------------------------
-- Panneau et toasts : la recette d'habillage lit ces valeurs selon le thème
------------------------------------------------------------------------------
local FLARE = { edge = Sk and Sk.EDGE_FILE, bg = Sk and Sk.BG_FILE, size = Sk and Sk.EDGE_SIZE, inset = Sk and Sk.INSET, tint = Sk and Sk.TINT, bgc = Sk and Sk.BG }
function Cl.SkinValues()
  if not Sk then return end
  if On() then
    Sk.EDGE_FILE, Sk.BG_FILE, Sk.EDGE_SIZE, Sk.INSET = Cl.EDGE_FILE, Cl.BG_FILE, Cl.EDGE_SIZE, Cl.INSET
    Sk.TINT, Sk.BG = Cl.TINT, Cl.BG
  else
    Sk.EDGE_FILE, Sk.BG_FILE, Sk.EDGE_SIZE, Sk.INSET = FLARE.edge, FLARE.bg, FLARE.size, FLARE.inset
    Sk.TINT, Sk.BG = FLARE.tint, FLARE.bgc
  end
end
local function ReSkinHost(host)
  if host and host.SetBackdrop and Sk then
    pcall(host.SetBackdrop, host, Sk.Backdrop())
    local a = host._skinBgA
    if a ~= nil then Sk.Paint(host, a) end
  end
end
function Cl.Apply()
  Cl.stats.applies = Cl.stats.applies + 1
  Cl.SkinValues()
  -- chiffres : contour « NumberFont » en classique, ombre fine sinon
  if I then I.TEXT_FLAGS = On() and "OUTLINE" or "" end
  local W = ns.Window
  local f = W and W.frame
  if f and f._skinHost then ReSkinHost(f._skinHost) end
  if ns.Panel and ns.Panel.ApplyOpacity then pcall(ns.Panel.ApplyOpacity) end
  for _, d in ipairs(UI and UI.dropsActive or {}) do if d._skinHost then ReSkinHost(d._skinHost) end end
  if UI and UI.embed and UI.embed.tiles then
    for _, t in ipairs(UI.embed.tiles) do if t.icon then pcall(Th.StyleTile, t) end end
  end
  if UI and UI.Refresh then pcall(UI.Refresh, UI, true) end
end
if Th then
  local prev = Th.OnModeChanged
  function Th.OnModeChanged(m)
    if prev then pcall(prev, m) end
    -- la valeur est enregistrée juste après : on la pose d'abord pour que On() la voie
    ns.EnsureDB().ui.theme = (m ~= "flare") and m or nil
    Cl.Apply()
  end
end

------------------------------------------------------------------------------
-- Cases : cadre de bouton d'action
------------------------------------------------------------------------------
local function Slot(t)
  local s = t._clsSlot
  if s then return s end
  s = t:CreateTexture(nil, "OVERLAY", nil, 1)
  pcall(s.SetTexture, s, Cl.SLOT)
  t._clsSlot = s
  Cl.stats.tiles = Cl.stats.tiles + 1
  return s
end
function Cl.SlotColor(t)
  local s = t and t._clsSlot
  if not s then return nil end
  local c, a = { 1, 1, 1 }, 1
  if t._tgtLit then c = Cl.GREEN a = (t._tgtLit == "indirect") and 0.65 or 1
  elseif t._flSelOn then c = Cl.GOLD end
  s:SetVertexColor(c[1], c[2], c[3], a)
  return c
end
function Cl.StyleTile(t)
  local icon = t and t.icon
  if not icon then return end
  if On() then
    local s = Slot(t)
    local w = (icon.GetWidth and ns.N(icon:GetWidth())) or I.ICON or 36
    if w <= 0 then w = I.ICON or 36 end
    s:ClearAllPoints()
    s:SetPoint("CENTER", icon, "CENTER", 0, -1)
    s:SetSize(math.floor(w * Cl.SLOT_K + 0.5), math.floor(w * Cl.SLOT_K + 0.5))
    s:Show()
    if Th.ShowBevel then Th.ShowBevel(t, false) end
    local m = icon._thMask
    if m then pcall(m.SetTexture, m, MASK_NONE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE") end
    if t._numShade then t._numShade:SetAlpha(0) end
    Cl.SlotColor(t)
    if not t._clsPress and t.HookScript then
      t._clsPress = true
      t:HookScript("OnMouseDown", function(self) Cl.Press(self, true) end)
      t:HookScript("OnMouseUp", function(self) Cl.Press(self, false) end)
    end
  else
    if t._clsSlot then t._clsSlot:Hide() end
    if t._numShade then t._numShade:SetAlpha(1) end
    -- biseau / masque FlareUI : reposés par Th.IconSkin (appelé juste avant)
  end
end
if Th and Th.StyleTile then
  local baseST = Th.StyleTile
  function Th.StyleTile(t, ...)
    local r = { baseST(t, ...) }
    pcall(Cl.StyleTile, t)
    return unpack(r)
  end
end
-- couleur cible / sélection : suit le même état que le biseau
if Th and Th.BevelColor then
  local baseBC = Th.BevelColor
  function Th.BevelColor(t, ...)
    local r = { baseBC(t, ...) }
    if On() and t and t._clsSlot then
      Cl.SlotColor(t)
      if Th.ShowBevel then Th.ShowBevel(t, false) end
    end
    return unpack(r)
  end
end
-- appui : cadre « enfoncé » de la barre d'action, le temps du clic
function Cl.Press(t, down)
  local s = t and t._clsSlot
  if not (s and On()) then return end
  pcall(s.SetTexture, s, down and Cl.SLOT_DOWN or Cl.SLOT)
end

------------------------------------------------------------------------------
-- Barre du total : barre d'état Blizzard
------------------------------------------------------------------------------
if Wd and Wd.Paint then
  local basePaint = Wd.Paint
  function Wd.Paint(t, ...)
    local r = { basePaint(t, ...) }
    local p = t and t._wideParts
    if not (p and t._wideOn) then return unpack(r) end
    local cls = On()
    pcall(p.track.SetTexture, p.track, cls and Cl.BAR_TEX or Wd.TEX)
    pcall(p.fill.SetTexture, p.fill, cls and Cl.BAR_TEX or Wd.FILL_TEX)
    local tc, fc = cls and Cl.BAR_TRACK or Wd.TRACK, cls and Cl.BAR_FILL or Wd.FILL
    p.track:SetVertexColor(tc[1], tc[2], tc[3], tc[4] or 1)
    p.fill:SetVertexColor(fc[1], fc[2], fc[3], fc[4] or 1)
    if p.sheen then if cls then p.sheen:Hide() end end
    local e = p.edge
    if e and e.SetBackdrop then
      local want = cls and Cl.EDGE_FILE or Wd.EDGE_TEX
      if e._clsEdge ~= want then
        e._clsEdge = want
        pcall(e.SetBackdrop, e, { edgeFile = want, edgeSize = cls and 10 or Wd.EDGE_SIZE })
      end
      local c = cls and Cl.BAR_EDGE or Wd.FILL
      if e.SetBackdropBorderColor then pcall(e.SetBackdropBorderColor, e, c[1], c[2], c[3], 1) end
    end
    if t._clsSlot then t._clsSlot:Hide() end
    return unpack(r)
  end
end

-- état au chargement (thème enregistré)
Cl.SkinValues()
if I and On() then I.TEXT_FLAGS = "OUTLINE" end

ns.DebugExt = ns.DebugExt or {}
ns.DebugExt[#ns.DebugExt + 1] = function()
  return { "— Thème classique (3.3.17) —", string.format("actif : %s · cases habillées %d · bord %s · barre %s",
    tostring(On()), Cl.stats.tiles, Cl.EDGE_FILE, Cl.BAR_TEX) }
end
