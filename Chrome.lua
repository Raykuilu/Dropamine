-- Dropamine — Chrome.lua (3.3.9)
-- Bordure IDENTIQUE à l'infobulle native, pour le panneau ET les toasts.
-- Pas d'approximation par un bord de backdrop : on applique la MÊME mise en
-- page NineSlice que GameTooltip (nom lu dans GameTooltip.NineSlice.layoutType,
-- sinon « TooltipDefaultLayout » de NineSliceLayouts), avec les fonctions de
-- Blizzard (NineSliceUtil.ApplyLayout). Les coins gardent leur taille native :
--  * l'habillage est un cadre enfant dont l'échelle compense celle du panneau
--    (/drop taille) → coins au même nombre de pixels que l'infobulle ;
--  * pas d'accrochage à la grille de pixels / de biais de texel sur les pièces
--    (SetSnapToPixelGrid(false), SetTexelSnappingBias(0)) → arrondis lisses.
-- Replis : pièces copiées de GameTooltip.NineSlice (atlas / fichier + coords,
-- tailles natives), sinon rien (l'ancien habillage reste).
local ADDON, ns = ...
local Ch = {}
ns.Chrome = Ch
Ch.PIECES = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center" }
Ch.DEFAULT_LAYOUT = "TooltipDefaultLayout"
Ch.stats = { applied = 0, rescaled = 0 }

local function Call(fn, ...) if type(fn) ~= "function" then return nil end local ok, a, b, c, d = pcall(fn, ...) if ok then return a, b, c, d end end
local function N(v) return tonumber(v) end

-- Nom de mise en page exposé par le client (et d'où il vient).
function Ch.LayoutName()
  local tt = rawget(_G, "GameTooltip")
  local nsl = type(tt) == "table" and rawget(tt, "NineSlice") or nil
  local name, src
  if type(nsl) == "table" then
    name = rawget(nsl, "layoutType")
    if name then src = "GameTooltip.NineSlice.layoutType" end
    if not name and nsl.GetLayoutType then name = Call(nsl.GetLayoutType, nsl) if name then src = "GameTooltip.NineSlice:GetLayoutType()" end end
  end
  if not name and type(tt) == "table" and rawget(tt, "layoutType") then name, src = rawget(tt, "layoutType"), "GameTooltip.layoutType" end
  if not name then
    local layouts = rawget(_G, "NineSliceLayouts")
    if type(layouts) == "table" and layouts[Ch.DEFAULT_LAYOUT] then name, src = Ch.DEFAULT_LAYOUT, "NineSliceLayouts (défaut de l'infobulle)" end
  end
  return name, src
end
function Ch.Layout(name)
  if not name then return nil end
  local util = rawget(_G, "NineSliceUtil")
  local L = type(util) == "table" and Call(util.GetLayout, name) or nil
  if type(L) ~= "table" then local t = rawget(_G, "NineSliceLayouts") L = type(t) == "table" and t[name] or nil end
  return type(L) == "table" and L or nil
end

-- Couleurs de l'infobulle (bord, fond). 3.3.10 : jamais relues sur GameTooltip
-- (teinte live : bord rouge après le survol d'un ennemi). 3.3.11 (« utilise la
-- bordure des infobulles ») : les COULEURS PAR DÉFAUT de l'infobulle, celles
-- que le client lui applique lui-même : TOOLTIP_DEFAULT_COLOR (bord, non
-- teinté) et TOOLTIP_DEFAULT_BACKGROUND_COLOR (fond). Ce sont des constantes
-- globales du client, pas l'état de GameTooltip. Repli : blanc / bleu nuit.
Ch.BORDER = { 1, 1, 1, 1 }
Ch.CENTER = { 0.09, 0.09, 0.19, 1 }
local function ColOf(c)
  if type(c) ~= "table" then return nil end
  local r, g, b, a
  if type(c.GetRGBA) == "function" then local ok, r1, g1, b1, a1 = pcall(c.GetRGBA, c) if ok then r, g, b, a = r1, g1, b1, a1 end end
  r = N(r) or N(c.r) or N(c[1]); g = N(g) or N(c.g) or N(c[2]); b = N(b) or N(c.b) or N(c[3])
  a = N(a) or N(c.a) or N(c[4]) or 1
  if r and g and b then return { r, g, b, a } end
end
function Ch.DefaultColors()
  local style = rawget(_G, "GAME_TOOLTIP_BACKDROP_STYLE_DEFAULT") or rawget(_G, "TOOLTIP_BACKDROP_STYLE_DEFAULT")
  local bc, bsrc = ColOf(rawget(_G, "TOOLTIP_DEFAULT_COLOR")), "TOOLTIP_DEFAULT_COLOR"
  if not bc and type(style) == "table" then bc, bsrc = ColOf(style.backdropBorderColor), "style par défaut (backdropBorderColor)" end
  if not bc then bc, bsrc = { Ch.BORDER[1], Ch.BORDER[2], Ch.BORDER[3], 1 }, "repli blanc (art non teinté)" end
  local cc, csrc = ColOf(rawget(_G, "TOOLTIP_DEFAULT_BACKGROUND_COLOR")), "TOOLTIP_DEFAULT_BACKGROUND_COLOR"
  if not cc and type(style) == "table" then cc, csrc = ColOf(style.backdropColor), "style par défaut (backdropColor)" end
  if not cc then cc, csrc = { Ch.CENTER[1], Ch.CENTER[2], Ch.CENTER[3], 1 }, "repli bleu nuit" end
  bc[4] = 1   -- bord : toujours plein (seule l'opacité du cadre entier s'applique)
  Ch.colorSource = { border = bsrc, center = csrc }
  return bc, cc
end
function Ch.TipColors() return Ch.DefaultColors() end

-- Lissage : pas d'accrochage aux pixels / texels sur une pièce.
function Ch.Smooth(t)
  if type(t) ~= "table" then return 0 end
  local n = 0
  if t.SetSnapToPixelGrid then pcall(t.SetSnapToPixelGrid, t, false) n = n + 1 end
  if t.SetTexelSnappingBias then pcall(t.SetTexelSnappingBias, t, 0) n = n + 1 end
  t._osrsSmooth = true
  return n
end

-- Échelle : coins à la taille native de l'infobulle quel que soit /drop taille.
function Ch.EffScale(f) if type(f) == "table" and f.GetEffectiveScale then return N(Call(f.GetEffectiveScale, f)) end end
function Ch.FixScale(host)
  local f = host and host._osrsFor
  if not f then return nil end
  local fs = Ch.EffScale(f) or 1
  local ref = Ch.EffScale(rawget(_G, "GameTooltip")) or Ch.EffScale(rawget(_G, "UIParent")) or fs
  if fs <= 0 then return nil end
  local s = ref / fs
  if host.SetScale then pcall(host.SetScale, host, s) end
  host:ClearAllPoints()
  host:SetAllPoints(f)
  host._osrsScale = s
  Ch.stats.rescaled = Ch.stats.rescaled + 1
  return s
end

local function Host(f)
  local host = f._tipChrome
  if host then return host, false end
  host = CreateFrame("Frame", nil, f)
  host._osrsOwn, host._osrsFor = true, f
  if host.EnableMouse then host:EnableMouse(false) end
  host:SetAllPoints(f)
  pcall(host.SetFrameLevel, host, math.max(0, (f.GetFrameLevel and f:GetFrameLevel() or 1)))
  f._tipChrome = host
  return host, true
end

-- Applique la bordure de l'infobulle sur f. Renvoie { host, center, border = {...}, mode }.
function Ch.Apply(f, opts)
  if type(f) ~= "table" or not f.CreateTexture then return nil end
  opts = opts or {}
  local host = Host(f)
  local mode, pieces = nil, {}
  local name, src = Ch.LayoutName()
  local layout = Ch.Layout(name)
  local util = rawget(_G, "NineSliceUtil")
  local canTable = layout and type(util) == "table" and type(util.ApplyLayout) == "function"
  local canName = name and type(util) == "table" and type(util.ApplyLayoutByName) == "function"
  if canTable or canName then
    local ok
    if canTable then ok = pcall(util.ApplyLayout, host, layout)
    else ok = pcall(util.ApplyLayoutByName, host, name) end
    if ok then
      for _, k in ipairs(Ch.PIECES) do local pc = rawget(host, k) if type(pc) == "table" then pieces[k] = pc end end
      if pieces.TopLeftCorner and pieces.TopEdge then mode = "NineSlice « " .. tostring(name) .. " » (" .. tostring(src) .. ")" end
    end
  end
  if not mode then
    local P = ns.Panel
    local art = P and P.ReadTooltipArt and P.ReadTooltipArt()
    if art and art.mode == "nineslice" and art.pieces and next(art.pieces) and P.BuildTipPieces then
      host._osrsCopied = host._osrsCopied or P.BuildTipPieces(host, art)
      pieces = host._osrsCopied
      -- coins : taille native de l'atlas si le client la donne
      for _, k in ipairs({ "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner" }) do
        local e, t = art.pieces[k], pieces[k]
        if e and t and e.atlas and t.SetAtlas then pcall(t.SetAtlas, t, e.atlas, true) end
      end
      mode = "pièces copiées de GameTooltip.NineSlice"
    end
  end
  if not mode then f._tipChromeMode = nil return nil end
  local bc, cc = Ch.TipColors()
  local tint = bc   -- 3.3.11 : bord par défaut de l'infobulle, aucune teinte à nous
  local border = {}
  for k, t in pairs(pieces) do
    Ch.Smooth(t)
    if k ~= "Center" then
      border[#border + 1] = t
      if t.SetVertexColor then pcall(t.SetVertexColor, t, tint[1], tint[2], tint[3], tint[4] or 1) end
      if t.Show then t:Show() end
    end
  end
  local center = pieces.Center
  if center and center.SetVertexColor then pcall(center.SetVertexColor, center, cc[1], cc[2], cc[3], 1) end
  Ch.FixScale(host)
  f._tipChromeMode = mode
  Ch.stats.applied = Ch.stats.applied + 1
  Ch.lastMode, Ch.lastLayout, Ch.lastSource = mode, name, src
  return { host = host, center = center, border = border, pieces = pieces, mode = mode, borderColor = bc, centerColor = cc }
end

-- Toast : bord de l'infobulle ; le fond du toast (sa couleur, /drop drops opacite)
-- est recalé dans la zone intérieure (pièce centrale) → rien ne dépasse des arrondis.
function Ch.Toast(f, tint)
  if type(f) ~= "table" or f._osrsPanel then return nil end
  local c = Ch.Apply(f, { tint = tint })
  if not c then return nil end
  for _, t in pairs(f._chatPieces or {}) do if t.Hide then t:Hide() end end
  if f.SetBackdropBorderColor then pcall(f.SetBackdropBorderColor, f, 0, 0, 0, 0) end
  local fl = f._flare and f._flare.border
  if fl then for _, t in pairs(fl) do if type(t) == "table" and t.Hide then t:Hide() end end end
  local bg, center = f._toastBg, c.center
  if center then
    if center.Hide then center:Hide() end
    if bg then
      bg:ClearAllPoints()
      -- même rectangle que la pièce centrale (mêmes décalages que l'infobulle)
      bg:SetPoint("TOPLEFT", center, "TOPLEFT", 0, 0)
      bg:SetPoint("BOTTOMRIGHT", center, "BOTTOMRIGHT", 0, 0)
    end
  end
  f._osrsNativeBorder = "infobulle : " .. c.mode
  return c
end

-- Recalage d'échelle (taille du panneau, échelle de l'interface).
function Ch.RescaleAll()
  local n = 0
  local W = ns.Window
  local f = W and W.frame
  if f and f._tipChrome then Ch.FixScale(f._tipChrome) n = n + 1 end
  local UI = ns.UI
  for _, d in ipairs(UI and UI.dropsActive or {}) do if d._tipChrome then Ch.FixScale(d._tipChrome) n = n + 1 end end
  return n
end
if ns.On then
  ns.On("UI_SCALE_CHANGED", function() pcall(Ch.RescaleAll) end)
  ns.On("DISPLAY_SIZE_CHANGED", function() pcall(Ch.RescaleAll) end)
end

ns.DebugExt = ns.DebugExt or {}
ns.DebugExt[#ns.DebugExt + 1] = function()
  local out = { "— Bordure (3.3.9) —" }
  local name, src = Ch.LayoutName()
  out[#out + 1] = "  mise en page de l'infobulle : " .. tostring(name or "aucune") .. " (" .. tostring(src or "—") .. ") ; NineSliceUtil " .. tostring(type(rawget(_G, "NineSliceUtil")) == "table")
  local tt = rawget(_G, "GameTooltip")
  local nsl = type(tt) == "table" and rawget(tt, "NineSlice") or nil
  if type(nsl) == "table" then
    local tl = rawget(nsl, "TopLeftCorner")
    if tl then
      local atlas = tl.GetAtlas and Call(tl.GetAtlas, tl)
      local w, h = Call(tl.GetSize, tl)
      out[#out + 1] = "  coin de l'infobulle : " .. tostring(atlas or (tl.GetTexture and Call(tl.GetTexture, tl)) or "?") .. " " .. tostring(w) .. "×" .. tostring(h)
    end
  end
  out[#out + 1] = "  appliqué : " .. tostring(Ch.lastMode or "pas encore") .. " ; " .. Ch.stats.applied .. " cadres, " .. Ch.stats.rescaled .. " recalages d'échelle"
  return out
end
