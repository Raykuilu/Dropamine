-- Dropamine 3.3.7 — mise en page redimensionnable du panneau compact.
--   * /drop colonnes <2|3|5|10> : 10 cases (9 compétences + Niveau total) en
--     2 × 5, 3 × 4, 5 × 2 (défaut) ou 10 × 1 ; ordre des cases inchangé,
--     Niveau total toujours la DERNIÈRE ;
--   * poignée de redimensionnement (coin bas-droit, NOTRE cadre) : en la
--     glissant, le panneau saute à la disposition valide la plus proche ;
--     inactive et cachée quand le panneau est verrouillé (/drop verrou on) ;
--   * /drop taille <50-200> : échelle du panneau (%, au pour cent près) ;
--   * mémorisé (SavedVariables) ; le coin HAUT-GAUCHE du panneau reste en place.
-- Coût : rien au repos ; l'OnUpdate de la poignée n'existe que pendant le
-- glissement (retiré au relâchement).
local ADDON, ns = ...
local Tr = ns.L   -- 3.5.19 : textes traduits (Locales/)
local UI, W, P, I = ns.UI, ns.Window, ns.Panel, ns.Icons
local H = UI._H
local RectOf, SizeOf = H.RectOf, H.SizeOf
local N = ns.N
local L = {}
ns.Layout = L

L.stats = { checks = 0, restored = 0, pinned = 0 }
L.VALID = { 2, 3, 5, 10 }   -- 3.6.3 : plus de mode 1 colonne
L.BASE_COLS, L.BASE_W = 5, 262          -- largeur de liste historique (5 colonnes)
L.SCALE_MIN, L.SCALE_MAX = 50, 200   -- 3.3.12 : plage élargie, pas de 1 %
local function DB() ns.db.ui = ns.db.ui or {} return ns.db.ui end
local function say(m) print(Tr["|cffffd100Dropamine|r : "] .. m) end
local function IsValid(n) for _, v in ipairs(L.VALID) do if v == n then return true end end return false end

function L.NearestCols(n)
  n = N(n)
  if not n then return L.BASE_COLS end
  if IsValid(n) then return n end
  local best, bd = L.BASE_COLS, 1e9
  for _, v in ipairs(L.VALID) do
    local d = math.abs(v - n)
    if d < bd or (d == bd and v < best) then best, bd = v, d end
  end
  return best
end

function L.Cols()
  local c = N(DB().cols)
  -- Seule l'ancienne valeur 1 est migrée (option retirée) et réécrite.
  if c == 1 then
    local n = (L.NearestCols and L.NearestCols(1)) or 2
    DB().cols = (n ~= L.BASE_COLS) and n or nil
    if ns.SaveActiveProfile then pcall(ns.SaveActiveProfile) end
    return n
  end
  if c and IsValid(c) then return c end
  return L.BASE_COLS
end
function L.Scale() local s = N(DB().scale) if not s then return 100 end return math.max(L.SCALE_MIN, math.min(L.SCALE_MAX, math.floor(s + 0.5))) end
-- Largeur / hauteur de la GRILLE seule : colonnes×case + (n-1)×écarts.
-- Pas de marge historique (22 px issus de la grille 5 col.) ni d'écart fantôme
-- à droite / en bas (cols×HGAP et rows×STEP en ajoutaient un).
function L.TileCount()
  local skills = (UI.snapshot and UI.snapshot.tiles and #UI.snapshot.tiles) or 9
  local totalOn = ns.Wide and ns.Wide.Shown and ns.Wide.Shown() and true or false
  return skills + (totalOn and 1 or 0), skills, totalOn
end
function L.Rows(cols)
  local n = L.TileCount()
  return math.max(1, math.ceil(n / (cols or L.Cols())))
end
-- Mesures courantes (curseur « Taille » / /drop taille) : jamais les 40×8 par défaut.
function L.SyncMetrics()
  if I.SetMetrics then I.SetMetrics(L.Scale() / 100) end
end
function L.GridSize(cols, rows)
  L.SyncMetrics()
  cols = cols or L.Cols()
  local tile = I.TILE or 40
  local hg = I.HGAP or 8
  local vg = I.VGAP or 12
  local gw = cols * tile + math.max(0, cols - 1) * hg
  local n, skills, totalOn = L.TileCount()
  local Wd = ns.Wide
  local barOn = totalOn and Wd and Wd.ShouldWiden and Wd.ShouldWiden(cols, n)
  if barOn then
    local skillRows = math.max(1, math.ceil((n - 1) / cols))
    local slim = (Wd.RowHeight and Wd.RowHeight(tile)) or math.max((Wd.MIN_H or 14), math.floor(tile * (Wd.SLIM or 0.45) + 0.5))
    local gh = skillRows * tile + math.max(0, skillRows - 1) * vg + vg + slim
    return gw, gh, cols, skillRows
  end
  rows = rows or L.Rows(cols)
  local gh = rows * tile + math.max(0, rows - 1) * vg
  return gw, gh, cols, rows
end
function L.ListW(cols)
  local gw = L.GridSize(cols, L.Rows(cols))
  return gw
end
-- Cadre = grille + la même marge sur les 4 côtés.
function L.ContentSize(cols, rows)
  local pad = L.MARGIN or 12
  local gw, gh, c, r = L.GridSize(cols, rows)
  return gw + 2 * pad, gh + 2 * pad, pad, gw, gh, c, r
end
function L.SnapToContent()
  local f, list = W.frame, W.list
  if not (f and list and P.IsExpanded and not P.IsExpanded()) then return nil end
  local fw, fh, pad, gw, gh = L.ContentSize()
  if not (fw and fh and fw > 0 and fh > 0) then return nil end
  fw, fh, pad, gw, gh = L.Px(fw, f), L.Px(fh, f), L.Px(pad, f), L.Px(gw, f), L.Px(gh, f)
  local cw = N(f.GetWidth and f:GetWidth()) or 0
  local ch = N(f.GetHeight and f:GetHeight()) or 0
  if math.abs(cw - fw) > 0.51 or math.abs(ch - fh) > 0.51 then
    if f.SetSize then f:SetSize(fw, fh) end
  end
  local lw = N(list.GetWidth and list:GetWidth()) or 0
  local lh = N(list.GetHeight and list:GetHeight()) or 0
  if math.abs(lw - gw) > 0.51 or math.abs(lh - gh) > 0.51 then
    if list.SetSize then list:SetSize(gw, gh) end
  end
  local okP, lp, lrel, lrp, lx, ly = pcall(list.GetPoint, list, 1)
  if not (okP and lp == "TOPLEFT" and lrel == f and lrp == "TOPLEFT"
      and math.abs((N(lx) or -1e9) - pad) < 0.01 and math.abs((N(ly) or -1e9) - (-pad)) < 0.01) then
    if list.ClearAllPoints then list:ClearAllPoints() end
    if list.SetPoint then list:SetPoint("TOPLEFT", f, "TOPLEFT", pad, -pad) end
  end
  L._listX, L._listY = pad, -pad
  L.margins = { pad, pad, pad, pad }
  return fw, fh
end

-- W.LIST_W suit la disposition avant chaque mise en forme du panneau
local baseApplyMode = P.ApplyMode
function P.ApplyMode(...)
  W.LIST_W = L.ListW()
  return baseApplyMode(...)
end

-- 3.5.16 : positions et tailles au pixel entier (à l'échelle effective)
function L.Px(v, f)
  v = N(v)
  if not v then return v end
  local PU = rawget(_G, "PixelUtil")
  local s = f and f.GetEffectiveScale and N(select(2, pcall(f.GetEffectiveScale, f)))
  if type(PU) == "table" and type(PU.GetNearestPixelSize) == "function" and s and s > 0 then
    local ok, r = pcall(PU.GetNearestPixelSize, v, s)
    if ok and N(r) then return N(r) end
  end
  return math.floor(v + 0.5)
end
local function TopLeft(f)
  local l, _, t = RectOf(f)
  return L.Px(l, f), L.Px(t, f)
end
local function Anchor(f, l, t)
  if not (l and t) then return end
  -- 3.5.16 : déjà ancré là (au pixel près) : on ne ré-ancre pas
  local ok, pt, rel, rp, x, y = pcall(f.GetPoint, f, 1)
  if ok and pt == "TOPLEFT" and rel == UIParent and rp == "BOTTOMLEFT" and math.abs((N(x) or -1e9) - l) < 0.01 and math.abs((N(y) or -1e9) - t) < 0.01 and (N(f:GetNumPoints()) or 1) == 1 then
    return
  end
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t)
  if P.SavePos then P.SavePos(f) end
end

function L.Apply(keep)
  local f = W.frame
  if not f then return end
  local l, t = TopLeft(f)
  -- 3.3.12 : jamais de SetScale (le bord grossissait) ; la taille agit sur la grille
  if f.SetScale then pcall(f.SetScale, f, 1) end
  if I.SetMetrics then I.SetMetrics(L.Scale() / 100) end
  P.ApplyMode()
  if W.IsShown() then pcall(W.Layout) if UI.ApplyView then pcall(UI.ApplyView, UI) end end
  if keep ~= false then Anchor(f, l, t) end
  if L.grip then L.PlaceGrip() end
  if ns.Chrome and ns.Chrome.RescaleAll then pcall(ns.Chrome.RescaleAll) end   -- 3.3.9 : coins à taille native
  L.applied = { cols = L.Cols(), rows = L.Rows(), w = SizeOf(f), scale = L.Scale() }
  return L.applied
end

function L.SetCols(n)
  n = N(n)
  if not n then return nil end
  n = L.NearestCols and L.NearestCols(n) or n
  if not IsValid(n) then return nil end
  if n == L.Cols() and L.applied and L.applied.cols == n then return n end
  DB().cols = (n ~= L.BASE_COLS) and n or nil
  if ns.SaveActiveProfile then pcall(ns.SaveActiveProfile) end
  L.Apply()
  return n
end
function L.SetScale(v)
  v = N(v)
  if not v then return nil end
  v = math.max(L.SCALE_MIN, math.min(L.SCALE_MAX, math.floor(v + 0.5)))
  local same = (v == L.Scale()) and L.applied and L.applied.scale == v
  local k = v / 100
  if same and I.metricsK and math.abs((I.metricsK or 1) - k) < 0.001 then return v end
  DB().scale = (v ~= 100) and v or nil
  if ns.SaveActiveProfile then pcall(ns.SaveActiveProfile) end
  -- taille dynamique : mesures de la grille recalculées, panneau remis en page,
  -- coin haut-gauche conservé (L.Apply), bord / coins à épaisseur native
  if I.SetMetrics then I.SetMetrics(v / 100) end
  if W.frame then
    L.Apply()
    if UI.Refresh then pcall(UI.Refresh, UI, true) end
    pcall(L.Center)
    if L.SnapToContent then pcall(L.SnapToContent) end
  end
  return v
end

------------------------------------------------------------------------------
-- Poignée de redimensionnement
------------------------------------------------------------------------------
L.GRIP = 10
function L.Candidates()
  local out = {}
  for _, c in ipairs(L.VALID) do
    local rows = L.Rows(c)
    local fw, fh = L.ContentSize(c, rows)
    out[#out + 1] = { cols = c, w = fw, h = fh, rows = rows }
  end
  return out
end
-- disposition valide la plus proche d'une taille voulue (w, h) en pixels du panneau
function L.Nearest(w, h)
  local best, bd
  for _, c in ipairs(L.Candidates()) do
    local d = (c.w - w) ^ 2 + (c.h - h) ^ 2
    if not bd or d < bd then best, bd = c, d end
  end
  return best
end
local function Cursor()
  local x, y = 0, 0
  if type(_G.GetCursorPosition) == "function" then x, y = _G.GetCursorPosition() end
  local s = (W.frame and W.frame.GetEffectiveScale and N(W.frame:GetEffectiveScale())) or 1
  if s <= 0 then s = 1 end
  return (N(x) or 0) / s, (N(y) or 0) / s
end
function L.DragStep()
  local d = L.drag
  if not d then return end
  local x, y = Cursor()
  local c = L.Nearest(d.w + (x - d.x), d.h + (d.y - y))
  if c and c.cols ~= L.Cols() then L.SetCols(c.cols) end
end
function L.StartDrag()
  if DB().locked then return false end
  local f = W.frame
  local w, h = SizeOf(f)
  local x, y = Cursor()
  L.drag = { x = x, y = y, w = w or 0, h = h or 0 }
  L.grip:SetScript("OnUpdate", function() L.DragStep() end)
  return true
end
function L.StopDrag()
  if L.drag then L.DragStep() end
  L.drag = nil
  if L.grip then L.grip:SetScript("OnUpdate", nil) end
end
function L.PlaceGrip()
  local g = L.grip
  g:ClearAllPoints()
  g:SetPoint("BOTTOMRIGHT", W.frame, "BOTTOMRIGHT", 0, 0)
  if DB().locked then g:Hide() g:EnableMouse(false) else g:Show() g:EnableMouse(true) end
end
function L.BuildGrip()
  local f = W.frame
  if not f or L.grip then return L.grip end
  local g = CreateFrame("Frame", nil, f)
  g._osrsOwn = true
  g:SetSize(L.GRIP, L.GRIP)
  pcall(g.SetFrameLevel, g, (f.GetFrameLevel and f:GetFrameLevel() or 1) + 20)
  g.tex = g:CreateTexture(nil, "OVERLAY")
  g.tex:SetAllPoints(g)
  pcall(g.tex.SetTexture, g.tex, "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  g:SetScript("OnMouseDown", function() L.StartDrag() end)
  g:SetScript("OnMouseUp", function() L.StopDrag() end)
  g:SetScript("OnHide", function() L.StopDrag() end)
  g:SetScript("OnEnter", function(self)
    if P.SetHover then P.SetHover(true) end
    if GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(Tr["Disposition : "] .. L.Cols() .. " × " .. L.Rows(), 1, 0.82, 0)
      GameTooltip:AddLine(Tr["Glisser : 1, 2, 3, 5 ou 10 colonnes · /drop colonnes · /drop taille"], 0.8, 0.8, 0.8)
      GameTooltip:Show()
    end
  end)
  g:SetScript("OnLeave", function() if P.SetHover then P.SetHover(false) end if GameTooltip then GameTooltip:Hide() end end)
  L.grip = g
  L.PlaceGrip()
  return g
end

------------------------------------------------------------------------------
-- 3.3.8 : CENTRAGE EXACT. La taille du panneau est calculée depuis la grille
-- réellement posée : même marge L.MARGIN sur les 4 côtés (le bord de
-- l'infobulle est symétrique, il ne déséquilibre rien), pour toute
-- disposition et toute /drop taille (l'échelle s'applique au tout). La poignée
-- de déplacement (bande du haut) et celle de redimensionnement (coin) se posent
-- PAR-DESSUS la marge sans réserver de place.
------------------------------------------------------------------------------
L.MARGIN = 12   -- 3.3.17 : = écart vertical de la grille (marges homogènes)
function L.GridRect()
  local Lx, Rx, Tx, Bx
  for _, t in ipairs(UI.embed and UI.embed.tiles or {}) do
    if t.data and t.IsShown and t:IsShown() then
      local l, r, tp, b = RectOf(t)
      if l then
        Lx = Lx and math.min(Lx, l) or l
        Rx = Rx and math.max(Rx, r) or r
        Tx = Tx and math.max(Tx, tp) or tp
        Bx = Bx and math.min(Bx, b) or b
      end
    end
  end
  return Lx, Rx, Tx, Bx
end
function L.Center()
  local f, list = W.frame, W.list
  if not (f and list and P.IsExpanded and not P.IsExpanded()) then return nil end
  local gl, gr, gt, gb = L.GridRect()
  local fl, _, ft = RectOf(f)
  if not (gl and fl) then return nil end
  local M = L.MARGIN
  -- 3.3.11 : marge du haut agrandie quand une pastille « N prêt » dépasse
  -- au-dessus d'une case de la 1re rangée (elle n'empiète plus sur le bord)
  local MT = M + ((L.TopExtra and L.TopExtra(gt)) or 0)
  local ox, oy = L._listX or P.CPAD, L._listY or -P.CTOP
  ox = L.Px(ox + (M - (gl - fl)), f)
  oy = L.Px(oy - (MT - (ft - gt)), f)
  -- 3.5.16 : rien ne bouge si rien n'a changé (pas de ré-ancrage à chaque
  -- toast / pastille) ; tout au pixel entier ; le coin haut-gauche du panneau
  -- reste fixe quel que soit son point d'ancrage
  local w, h = L.Px((gr - gl) + 2 * M, f), L.Px((gt - gb) + M + MT, f)
  local okP, lp, lrel, lrp, lx, ly = pcall(list.GetPoint, list, 1)
  if not (okP and lp == "TOPLEFT" and lrel == f and lrp == "TOPLEFT" and math.abs((N(lx) or -1e9) - ox) < 0.01 and math.abs((N(ly) or -1e9) - oy) < 0.01) then
    list:ClearAllPoints()
    list:SetPoint("TOPLEFT", f, "TOPLEFT", ox, oy)
  end
  L._listX, L._listY = ox, oy
  -- 3.6.3 : le cadre épouse la grille (case×colonnes + écarts + même marge
  -- des 4 côtés), recalculé ici, sur changement de colonnes / taille, et
  -- à la fin d'un état. On ne reprend plus GridRect (calques d'état, fiole
  -- amincie) qui faisait dériver la taille.
  L.SnapToContent()
  local pad = L.MARGIN or M
  if P.handle then
    P.handle:ClearAllPoints()
    P.handle:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    P.handle:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    P.handle:SetHeight(pad)
  end
  if L.grip then L.PlaceGrip() end
  L.margins = { pad, pad, pad, pad }
  return true
end
-- ApplyMode repose la liste à (CPAD, -CTOP) : on repart de là à chaque fois
local baseAM2 = P.ApplyMode
function P.ApplyMode(...)
  L._listX, L._listY = nil, nil
  local r = { baseAM2(...) }
  pcall(L.Center)
  return unpack(r)
end
local baseWLayout = W.Layout
function W.Layout(...)
  local r = { baseWLayout(...) }
  pcall(L.Center)
  return unpack(r)
end
local baseAV = UI.ApplyView
function UI:ApplyView(...)
  local r = { baseAV(self, ...) }
  if W.frame and W.IsShown() then pcall(L.Center) end
  return unpack(r)
end

-- construction / verrou
local baseBuild = W.Build
function W.Build(...)
  W.LIST_W = L.ListW()
  local r = { baseBuild(...) }
  if W.frame then
    -- 3.5.13 : même règle que L.Apply (échelle du cadre 1, taille portée par
    -- la grille). Avant : SetScale(taille) ici, puis SetScale(1) au premier
    -- L.Apply → la taille « revenait à 100 % » après masquer / afficher.
    if W.frame.SetScale then pcall(W.frame.SetScale, W.frame, 1) end
    if I.SetMetrics then I.SetMetrics(L.Scale() / 100) end
    L.BuildGrip()
  end
  return unpack(r)
end

-- 3.5.13 : à chaque affichage, la taille et la disposition MÉMORISÉES sont
-- reposées si quelque chose les a changées (échelle du cadre, mesures des
-- cases, colonnes), coin haut-gauche conservé.
L.stats = L.stats or { checks = 0, restored = 0, pinned = 0 }
function L.Drift()
  local f = W.frame
  if not f then return nil end
  local why = {}
  local fs = f.GetScale and N(f:GetScale())
  if fs and math.abs(fs - 1) > 0.001 then why[#why + 1] = "échelle du cadre " .. string.format("%.2f", fs) end
  local want = L.Scale() / 100
  if math.abs((I.metricsK or 1) - want) > 0.001 then why[#why + 1] = string.format("cases %.2f au lieu de %.2f", I.metricsK or 1, want) end
  if L.applied and L.applied.cols ~= L.Cols() then why[#why + 1] = "colonnes " .. tostring(L.applied.cols) .. " au lieu de " .. tostring(L.Cols()) end
  if W.LIST_W ~= L.ListW() then why[#why + 1] = "largeur de liste" end
  return (#why > 0) and table.concat(why, ", ") or nil
end
function L.EnsureSaved(reason)
  if ns.InCombat and ns.InCombat() then return false end
  L.stats.checks = L.stats.checks + 1
  local d = L.Drift()
  if not d then return false end
  L.stats.restored = L.stats.restored + 1
  L.lastRestore = tostring(reason) .. " : " .. d
  pcall(L.Apply, true)
  return true
end
for _, m in ipairs({ "Show", "Toggle" }) do
  local base = W[m]
  if base then
    W[m] = function(...)
      local r = { base(...) }
      if W.IsShown() then pcall(L.EnsureSaved, m) end
      return unpack(r)
    end
  end
end
if ns.On then ns.On("PLAYER_ENTERING_WORLD", function() pcall(L.EnsureSaved, "entrée dans le monde") end) end
if W.frame then L.BuildGrip() end
local baseVerrou = ns.SlashExt.verrou
ns.SlashExt.verrou = function(...)
  baseVerrou(...)
  if L.grip then L.StopDrag() L.PlaceGrip() end
end

ns.SlashExt.colonnes = function(rest)
  local n = L.SetCols((rest or ""):match("^%s*(%d+)"))
  if n then say(Tr["disposition : "] .. n .. Tr[" colonne"] .. (n > 1 and "s" or "") .. " × " .. L.Rows(n) .. Tr[" rangée"] .. (L.Rows(n) > 1 and "s" or ""))
  else say(Tr["colonnes : "] .. L.Cols() .. Tr[" (usage : /drop colonnes 2|3|5|10)"]) end
end
ns.SlashExt.taille = function(rest)
  local v = L.SetScale((rest or ""):match("^%s*(%d+)"))
  if v then say(Tr["taille du panneau : "] .. v .. " %") else say(Tr["taille : "] .. L.Scale() .. Tr[" % (usage : /drop taille 50-200)"]) end
end
ns.HelpExt = ns.HelpExt or {}
ns.HelpExt[#ns.HelpExt + 1] = "/drop colonnes 2|3|5|10 : disposition (poignée du coin bas-droit) · /drop taille 50-200 : échelle (%) ; poignée = taille (Alt+glisser = colonnes)"
local baseDebug = W.DebugLines
W.DebugLines = function()
  local out = baseDebug()
  out[#out + 1] = "  disposition : " .. L.Cols() .. " × " .. L.Rows() .. ", taille " .. L.Scale() .. " %, poignée " .. tostring(L.grip and L.grip:IsShown() and "active" or "cachée (verrou)")
  out[#out + 1] = string.format("  taille mémorisée (3.5.13) : %s %%, colonnes %s, position %s ; vérifs %d, reposée %d fois, coin haut-gauche re-fixé %d fois (3.5.16)%s", tostring(DB().scale or 100), tostring(DB().cols or L.BASE_COLS),
    DB().winPos and "mémorisée" or "par défaut", (L.stats and L.stats.checks) or 0, (L.stats and L.stats.restored) or 0, (L.stats and L.stats.pinned) or 0, L.lastRestore and (" (dernière : " .. L.lastRestore .. ")") or "")
    .. " ; cadre : " .. tostring(W.tipLook or ("toasts (" .. tostring(W.tipLookWhy) .. ")"))
  return out
end
