-- Dropamine 3.10.0 : onglet Hardcore (mode Hardcore à venir sur Forever, ou Hardcore manuel par personnage).
--   Liseré « danger » sur la cible. Rien ne s'active hors d'un personnage Hardcore (ns.IsHardcore ; /drop hc simu pour tester).
local ADDON, ns = ...
local Tr = ns.L

local H = {}
ns.Hardcore = H

local function N(v) return ns.N(v) end
local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c, d, e, f, g, h, i, j, k = pcall(fn, ...)
  if not ok then return nil end
  return ns.Unsecret(a, b, c, d, e, f, g, h, i, j, k)
end
local function After(sec, fn) if _G.C_Timer and _G.C_Timer.After then _G.C_Timer.After(sec, fn) return true end fn() return false end

-- Réglages ---------------------------------------------------------------------
local function CharDB() local ok, c = pcall(ns.CharDB) return ok and type(c) == "table" and c or nil end
local function Hello(force)
  local db = CharDB()
  if db and (force or not db.hcHello) then
    db.hcHello = true
    ns.Print(Tr["Hardcore détecté : l'alerte danger sur la cible est active (Réglages > Avancé > Hardcore)."])
  end
end
-- Hardcore volontaire : par personnage
function H.SetManual(on)
  local db = CharDB()
  if not db then return end
  local was = db.hcManual == true
  db.hcManual = on and true or nil
  if on and not was then Hello(true) end
  local T = ns.Target
  if T and T.Refresh then pcall(T.Refresh, "hc") end
  if H.Update then pcall(H.Update, false) end
end
H.OPTIONS = {
  { type = "check", key = "hcManual", label = "Je joue en Hardcore (mode non officiel)", default = false, cmd = "/drop hc on|off",
    help = "Pour ce personnage seulement : active les aides Hardcore sans le mode officiel du jeu.", home = "advanced",
    get = function() return ns.HardcoreManual() end, set = function(v) H.SetManual(v) end },
  { type = "check", key = "hcDanger", label = "Alerte danger sur la cible", default = true, cmd = "Réglage de ce panneau",
    help = "Personnage Hardcore : si la cible est élite, de niveau ?? ou a 3 niveaux de plus que toi, le cadre du panneau pulse en rouge, un bandeau dit pourquoi et la goutte bat en rouge. Les cases gardent leurs couleurs.", home = "advanced" },
  { type = "check", key = "hcSound", label = "Son d'alerte au ciblage", default = true, cmd = "Réglage de ce panneau",
    help = "Personnage Hardcore : un son d'alerte, une fois par cible dangereuse. Joué même si les sons de l'addon sont coupés.", home = "advanced" },
  { type = "slider", key = "hcGlowFrameInt", label = "Lueur rouge du panneau", default = 50, min = 0, max = 100, step = 5, unit = "pct", cmd = "Réglage de ce panneau",
    help = "Alerte danger : taille et force de la lueur rouge autour du panneau. 0 % = pas de lueur. Bouger le curseur montre l'alerte 4 s.", home = "advanced" },
  { type = "slider", key = "hcGlowDropInt", label = "Halo rouge de la goutte", default = 35, min = 0, max = 100, step = 5, unit = "pct", cmd = "Réglage de ce panneau",
    help = "Alerte danger : taille et force du halo rouge derrière la goutte, qui bat. 0 % = goutte normale. Bouger le curseur montre l'alerte 4 s.", home = "advanced" },
}
local O = ns.Options
if O then
  O.EXTRA_HOME = O.EXTRA_HOME or {}
  for _, it in ipairs(H.OPTIONS) do O.EXTRA[#O.EXTRA + 1] = it O.EXTRA_HOME[it.key] = it.home end
  if O.GROUPS then
    O.GROUPS.grpHardcore = { label = "Hardcore", help = "Actif seulement sur un personnage Hardcore (mode à venir sur Forever).",
      items = { { "hcManual", "Je joue en Hardcore (mode non officiel)" }, { "hcDanger", "Alerte danger sur la cible" }, { "hcSound", "Son d'alerte au ciblage" },
        { "hcGlowFrameInt", "Lueur rouge du panneau" }, { "hcGlowDropInt", "Halo rouge de la goutte" } } }
  end
  if O.MAP and O.MAP.advanced then table.insert(O.MAP.advanced, 1, { "Hardcore", { "grpHardcore" } }) end
  if O.TEST then
    O.TEST.hcDanger = "danger"
    O.TEST.hcSound = "hcsound"
    O.TEST.hcGlowFrameInt = "danger" O.TEST.hcGlowDropInt = "danger"
    O.TEST.grpHardcore = "group"
  end
  O.TEST_FN = O.TEST_FN or {}
end

-- Liseré danger ----------------------------------------------------------
H.DANGER = { 1, 0.12, 0.08 }
local ELITE = { elite = true, rareelite = true, worldboss = true }
-- raison du danger (texte) ou nil
function H.DangerOf(tg)
  if not (tg and (ns.IsHardcore() or H._simDanger) and ns.Opt("hcDanger")) then return nil end
  if tg.dead or not (tg.attackable or tg.enemy) then return nil end
  local pl = N(tg.playerLevel) or N(Call(_G.UnitLevel, "player")) or 1
  local tl = N(tg.level)
  if not tl or tl <= 0 then return Tr["niveau ??"] end
  if tg.classif and ELITE[tg.classif] then return Tr["élite"] end
  if tl >= pl + 3 then return string.format(Tr["+%d niveaux"], tl - pl) end
  return nil
end
-- 3.10.0 : alerte HORS des cases (leurs 3 couleurs restent celles de l'addon) :
-- cadre du panneau qui pulse en rouge, bandeau « pourquoi » sur le bord haut,
-- goutte rouge qui bat, son d'alerte une fois par cible. Tout est à nous.
local DROP_TEX = "Interface\\AddOns\\Dropamine\\Media\\Dropamine-Icon"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local function ReadTarget()
  local T = ns.Target
  if not (T and T.ReadTarget) then return nil end
  local ok, tg = pcall(T.ReadTarget)
  return ok and tg or nil
end
local function Pulse(region, from, to, dur)
  if not (region and region.CreateAnimationGroup) then return nil end
  local ag = region:CreateAnimationGroup()
  if ag.SetLooping then ag:SetLooping("BOUNCE") end
  local a = ag:CreateAnimation("Alpha")
  if a.SetFromAlpha then a:SetFromAlpha(from) a:SetToAlpha(to) end
  a:SetDuration(dur)
  return ag
end
-- lueur rouge douce AUTOUR du panneau (ombre douce de l'addon, en 8 morceaux,
-- seulement à l'extérieur), teintée en rouge
H.GLOW = 16
-- textures BLANCHES (Media/Glow-*.tga) : l'ombre de l'addon (SoftShadow) est noire,
-- donc impossible à teinter en rouge
local GLOW_SOFT = "Interface\\AddOns\\Dropamine\\Media\\Glow-Soft"
local GLOW_ROUND = "Interface\\AddOns\\Dropamine\\Media\\Glow-Round"
local function ShadowTex() return GLOW_SOFT end
function H.BuildPanelAlert(f)
  if not f then return nil end
  if H.glow and H.glow:GetParent() == f then return H.glow end
  local tex = ShadowTex()
  local g = CreateFrame("Frame", nil, f)
  g:SetAllPoints(f)
  if g.SetFrameLevel and f.GetFrameLevel then pcall(g.SetFrameLevel, g, (N(f:GetFrameLevel()) or 1) + 20) end
  if g.EnableMouse then g:EnableMouse(false) end
  local P, E = H.GLOW, 20 / 64   -- largeur de la lueur ; bord flou du fichier + un peu de zone pleine
  g.pieces = {}
  local function Piece(l, r, t, b)
    local s = g:CreateTexture(nil, "BACKGROUND")
    pcall(s.SetTexture, s, tex)
    s:SetTexCoord(l, r, t, b)
    s:SetVertexColor(H.DANGER[1], H.DANGER[2], H.DANGER[3], 1)
    if s.SetBlendMode then pcall(s.SetBlendMode, s, "ADD") end
    g.pieces[#g.pieces + 1] = s
    return s
  end
  -- coins
  local tl = Piece(0, E, 0, E) tl:SetPoint("BOTTOMRIGHT", f, "TOPLEFT", 0, 0) tl:SetSize(P, P)
  local tr = Piece(1 - E, 1, 0, E) tr:SetPoint("BOTTOMLEFT", f, "TOPRIGHT", 0, 0) tr:SetSize(P, P)
  local bl = Piece(0, E, 1 - E, 1) bl:SetPoint("TOPRIGHT", f, "BOTTOMLEFT", 0, 0) bl:SetSize(P, P)
  local br = Piece(1 - E, 1, 1 - E, 1) br:SetPoint("TOPLEFT", f, "BOTTOMRIGHT", 0, 0) br:SetSize(P, P)
  tl._dim, tr._dim, bl._dim, br._dim = "both", "both", "both", "both"
  -- bords
  local top = Piece(E, 1 - E, 0, E)
  top:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 0) top:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, 0) top:SetHeight(P)
  local bot = Piece(E, 1 - E, 1 - E, 1)
  bot:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, 0) bot:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 0, 0) bot:SetHeight(P)
  local lef = Piece(0, E, E, 1 - E)
  lef:SetPoint("TOPRIGHT", f, "TOPLEFT", 0, 0) lef:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", 0, 0) lef:SetWidth(P)
  local rig = Piece(1 - E, 1, E, 1 - E)
  rig:SetPoint("TOPLEFT", f, "TOPRIGHT", 0, 0) rig:SetPoint("BOTTOMLEFT", f, "BOTTOMRIGHT", 0, 0) rig:SetWidth(P)
  top._dim, bot._dim, lef._dim, rig._dim = "h", "h", "w", "w"
  g.ag = Pulse(g, 0.8, 0.3, 0.7)
  -- bandeau : même plaque que la pastille « N prêts », en rouge (tête de mort + raison)
  local Po = ns.Polish
  local I = ns.Icons
  local b = CreateFrame("Frame", nil, f)
  if b.SetFrameLevel and f.GetFrameLevel then pcall(b.SetFrameLevel, b, (N(f:GetFrameLevel()) or 1) + 22) end
  if b.EnableMouse then b:EnableMouse(false) end
  b:SetHeight(18)
  b:SetPoint("CENTER", f, "TOP", 0, 0)
  local sh = b:CreateTexture(nil, "BACKGROUND", nil, -2)
  pcall(sh.SetTexture, sh, WHITE)
  sh:SetVertexColor(0, 0, 0, 0.70)
  sh:SetPoint("TOPLEFT", -2, 2) sh:SetPoint("BOTTOMRIGHT", 2, -2)
  local edge = b:CreateTexture(nil, "BACKGROUND", nil, -1)
  pcall(edge.SetTexture, edge, WHITE)
  edge:SetVertexColor(H.DANGER[1], H.DANGER[2], H.DANGER[3], 1)
  edge:SetPoint("TOPLEFT", -1, 1) edge:SetPoint("BOTTOMRIGHT", 1, -1)
  local bg = b:CreateTexture(nil, "BACKGROUND", nil, 0)
  pcall(bg.SetTexture, bg, WHITE)
  local BG = (Po and Po.BADGE_BG) or { 0.06, 0.05, 0.04, 0.94 }
  bg:SetVertexColor(BG[1], BG[2], BG[3], BG[4] or 0.94)
  bg:SetAllPoints(b)
  local skull = b:CreateTexture(nil, "ARTWORK")
  pcall(skull.SetTexture, skull, "Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
  skull:SetSize(14, 14)
  skull:SetPoint("LEFT", b, "LEFT", 5, 0)
  local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  pcall(fs.SetFont, fs, (I and I.COUNT_PATH) or "Fonts\\ARIALN.TTF", 12, "")
  if I and I.CleanText then pcall(I.CleanText, fs) end
  fs:SetPoint("LEFT", skull, "RIGHT", 4, 0)
  fs:SetTextColor(1, 0.45, 0.30)
  b.fs = fs
  b:Hide()
  g.banner = b
  g:Hide()
  H.glow = g
  return g
end
-- goutte : la VRAIE goutte (en couleurs), dans un cadre à nous NON rogné,
-- halo rouge rond qui pulse derrière et petit battement (+12 %)
function H.BuildDropAlert(t, k)
  local S = ns.Slot
  if not (t and S and S.IconInnerSize) then return nil end
  local w, h, anchor = S.IconInnerSize(t)
  anchor = anchor or t.icon or t
  local fx = t._hcFx
  if not fx then
    fx = CreateFrame("Frame", nil, t)
    if fx.EnableMouse then fx:EnableMouse(false) end
    local halo = fx:CreateTexture(nil, "BACKGROUND")
    pcall(halo.SetTexture, halo, GLOW_ROUND)
    halo:SetVertexColor(H.DANGER[1], H.DANGER[2], H.DANGER[3], 1)
    if halo.SetBlendMode then pcall(halo.SetBlendMode, halo, "ADD") end
    fx.halo = halo
    fx.haloAG = Pulse(halo, 1, 0.5, 0.6)
    local drop = fx:CreateTexture(nil, "ARTWORK")
    pcall(drop.SetTexture, drop, DROP_TEX)
    fx.drop = drop
    local ag = drop:CreateAnimationGroup()
    if ag.SetLooping then ag:SetLooping("REPEAT") end
    local function Beat(order, s, d)
      local a = ag:CreateAnimation("Scale")
      if a.SetScaleFrom then a:SetScaleFrom(1, 1) a:SetScaleTo(s, s) elseif a.SetScale then a:SetScale(s, s) end
      a:SetDuration(d) a:SetOrder(order)
      if a.SetOrigin then a:SetOrigin("CENTER", 0, 0) end
    end
    Beat(1, 1.12, 0.12) Beat(2, 1 / 1.12, 0.12) Beat(3, 1.06, 0.10) Beat(4, 1 / 1.06, 0.5)
    fx.ag = ag
    t._hcFx = fx
  end
  if fx.SetFrameLevel and t.GetFrameLevel then pcall(fx.SetFrameLevel, fx, (N(t:GetFrameLevel()) or 1) + 12) end
  local side = math.max(8, math.min(N(w) or 16, N(h) or 16))
  fx:ClearAllPoints()
  fx:SetSize(side, side)
  fx:SetPoint("CENTER", anchor, "CENTER", 0, 0)
  fx.drop:ClearAllPoints() fx.drop:SetAllPoints(fx)
  fx.halo:ClearAllPoints()
  local pad = math.floor(side * 0.9 * (k or 1) + 0.5)
  fx.halo:SetPoint("TOPLEFT", fx, "TOPLEFT", -pad, pad) fx.halo:SetPoint("BOTTOMRIGHT", fx, "BOTTOMRIGHT", pad, -pad)
  return fx
end
local function TotalTiles()
  local out, tiles = {}, ns.UI and ns.UI.embed and ns.UI.embed.tiles
  for _, tt in ipairs(tiles or {}) do if tt and tt.data and tt.data.kind == "total" then out[#out + 1] = tt end end
  return out
end
local function Play(ag, on) if ag then if on then if not ag:IsPlaying() then ag:Play() end else ag:Stop() end end end
-- la goutte d'origine (rognée) s'efface le temps de l'alerte, puis revient
local function OrigAlpha(t, a)
  local S = ns.Slot
  local clip = S and S.EnsureIconClip and (S.EnsureIconClip(t))
  for _, o in ipairs({ t.icon or false, clip or false }) do if o and o.SetAlpha then pcall(o.SetAlpha, o, a) end end
end
-- état de l'alerte : why = texte ou nil
-- niveau réglé (curseurs de l'onglet Hardcore), 0..1 : taille ET force.
-- Reprise des anciennes cases (zip de test) : décochée = 0 %.
local OLD_CHECK = { hcGlowFrameInt = "hcGlowFrame", hcGlowDropInt = "hcGlowDrop" }
function H.Intensity(key, def)
  local ui = ns.db and ns.db.ui
  local old = OLD_CHECK[key]
  if ui and old and ui[old] ~= nil then
    if ui[old] == false then ui[key] = 0 end
    ui[old] = nil
  end
  local v = ui and N(ui[key])
  return math.max(0, math.min(100, v or def)) / 100
end
-- lueur : épaisseur et force selon le niveau (alpha jamais trop pâle tant qu'elle existe)
local function SizeGlow(g, k)
  local P = math.max(2, math.floor(H.GLOW * k + 0.5))
  local a = 0.3 + 0.7 * k
  for _, s in ipairs(g.pieces or {}) do
    if s._dim == "both" then s:SetSize(P, P) elseif s._dim == "h" then s:SetHeight(P) elseif s._dim == "w" then s:SetWidth(P) end
    s:SetVertexColor(H.DANGER[1], H.DANGER[2], H.DANGER[3], a)
  end
end
function H.Show(why)
  H.why = why
  local Wn = ns.Window
  local f = Wn and Wn.frame
  local g = (why and f) and H.BuildPanelAlert(f) or H.glow
  if g then
    if why then
      g.banner.fs:SetText(why)
      g.banner:SetWidth((N(g.banner.fs:GetStringWidth()) or 60) + 30)
      g.banner:Show()
      local k = H.Intensity("hcGlowFrameInt", 50)
      if k > 0 then
        SizeGlow(g, k)
        g:Show() Play(g.ag, true)
      else
        Play(g.ag, false) g:Hide()
      end
    else
      Play(g.ag, false) g:Hide() g.banner:Hide()
    end
  end
  for _, t in ipairs(TotalTiles()) do
    local busy = t._needle and t._needle.IsShown and t._needle:IsShown()
    local k = H.Intensity("hcGlowDropInt", 35)
    local on = why and not busy and k > 0
    local fx = on and H.BuildDropAlert(t, k) or t._hcFx
    if fx then
      if on then
        fx.halo:SetVertexColor(H.DANGER[1], H.DANGER[2], H.DANGER[3], 0.3 + 0.7 * k)
        fx:Show() Play(fx.ag, true) Play(fx.haloAG, true)
        OrigAlpha(t, 0) t._hcHid = true
      else
        Play(fx.ag, false) Play(fx.haloAG, false) fx:Hide()
      end
    end
    if not on and t._hcHid then OrigAlpha(t, 1) t._hcHid = nil end
  end
end
-- raison complète pour le bandeau et l'infobulle : « Élite · niveau ?? »
function H.Reason(tg)
  if not (tg and (ns.IsHardcore() or H._simDanger) and ns.Opt("hcDanger")) then return nil end
  if tg.dead or not (tg.attackable or tg.enemy) then return nil end
  local parts = {}
  if tg.classif and ELITE[tg.classif] then parts[#parts + 1] = Tr["Élite"] end
  local pl = N(tg.playerLevel) or 1
  local tl = N(tg.level)
  if not tl or tl <= 0 then parts[#parts + 1] = Tr["niveau ??"]
  elseif tl >= pl + 3 then parts[#parts + 1] = string.format(Tr["+%d niveaux"], tl - pl) end
  if #parts == 0 then return nil end
  return table.concat(parts, " · ")
end
-- son : une fois par cible (GUID), même si les sons de l'addon sont coupés
function H.Sound(force)
  if not (force or ns.Opt("hcSound")) then return end
  local kit = _G.SOUNDKIT and _G.SOUNDKIT.RAID_WARNING or 8959
  if type(_G.PlaySound) == "function" then pcall(_G.PlaySound, kit, "Master") end
end
function H.Update(fromTarget)
  local tg = ReadTarget()
  local why = H.Reason(tg)
  if why and fromTarget then
    local guid = Call(_G.UnitGUID, "target")
    if guid ~= H._soundGuid then H._soundGuid = guid H.Sound() end
  elseif not why and fromTarget then
    H._soundGuid = nil
  end
  if why ~= H.why then H.Show(why) end
  -- cible dangereuse : on revérifie 2 fois par seconde (morte, plus attaquable…)
  if why and not H._ticking then
    H._ticking = true
    local function Tick()
      if not H.why then H._ticking = false return end
      H.Update(false)
      if H.why then After(0.5, Tick) else H._ticking = false end
    end
    After(0.5, Tick)
  end
  return why
end
-- infobulle de la goutte : une ligne d'alerte en tête des autres
if ns.Compact and ns.Compact.ShowTotalTip then
  local baseTip = ns.Compact.ShowTotalTip
  function ns.Compact.ShowTotalTip(owner, tile, ...)
    local r = { baseTip(owner, tile, ...) }
    local tt = _G.GameTooltip
    if H.why and tt and tt.AddLine then
      tt:AddLine(" ")
      tt:AddLine(Tr["Danger (Hardcore) : "] .. H.why, H.DANGER[1], H.DANGER[2], H.DANGER[3], true)
      tt:Show()
    end
    return unpack(r)
  end
end
-- Test : 6 s d'alerte (sur la cible si elle compte, sinon une démo « Élite · niveau ?? »)
function H.TestDanger()
  H._simDanger = true
  local why = H.Update(false) or (Tr["Élite"] .. " · " .. Tr["niveau ??"])
  H.Show(why)
  H.Sound(true)
  ns.Print(Tr["Test : alerte danger pendant 6 s."])
  After(6, function() H._simDanger = nil H.Show(nil) H.Update(false) end)
  return true
end
function H.TestSound() H.Sound(true) return true end
-- aperçu muet pendant qu'on bouge un curseur : 4 s d'alerte, relancées à chaque cran
function H.Preview()
  if H.why and not H._preview then H.Show(H.why) return end
  H._preview = (H._preview or 0) + 1
  local mine = H._preview
  H.Show(Tr["Élite"] .. " · " .. Tr["niveau ??"])
  After(4, function()
    if H._preview ~= mine then return end
    H._preview = nil
    H.Show(nil)
    pcall(H.Update, false)
  end)
end

-- Tests (boutons « Tester » des réglages) --------------------------------------------------------
if O and O.TEST_FN then
  O.TEST_FN.danger = H.TestDanger
  O.TEST_FN.hcsound = H.TestSound
end

-- /drop hc : état ; /drop hc simu : simule un personnage Hardcore (tests sur un royaume normal)
ns.SlashExt = ns.SlashExt or {}
ns.SlashExt.hc = function(rest)
  local low = tostring(rest or ""):lower()
  if low:find("simu") then
    ns._forceHC = not ns._forceHC
    ns.Print(ns._forceHC and Tr["Hardcore simulé : actif jusqu'au /reload."] or Tr["Hardcore simulé : coupé."])
    pcall(H.Update, false)
    return
  end
  local word = low:match("^%s*(%a+)")
  if word == "on" or word == "off" then
    H.SetManual(word == "on")
    if O and O.Sync then pcall(O.Sync) end
    pcall(H.Update, false)
    ns.Print(word == "on" and Tr["Hardcore manuel : activé pour ce personnage."] or Tr["Hardcore manuel : coupé pour ce personnage."])
    return
  end
  local state = ns.HardcoreOfficial() and Tr["officiel"] or (ns.HardcoreManual() and Tr["manuel"])
    or (ns._forceHC and Tr["simulé"]) or Tr["non"]
  ns.Print(Tr["Hardcore : "] .. state .. Tr[" (/drop hc on|off, simu pour tester)"])
end
ns.HelpExt = ns.HelpExt or {}
ns.HelpExt[#ns.HelpExt + 1] = "/drop hc : mode Hardcore (on|off : Hardcore manuel, simu : simuler)"

if ns.On then
  ns.On("PLAYER_LOGIN", function()
    if ns.IsHardcore() then Hello(false) end
  end)
  ns.On("PLAYER_TARGET_CHANGED", function() pcall(H.Update, true) end)
  ns.On("UNIT_CLASSIFICATION_CHANGED", function(_, u) if u == "target" then pcall(H.Update, false) end end)
end
-- option « Alerte danger » décochée / recochée : l'alerte suit tout de suite
if ns.OnOptionChanged then
  local baseOpt = ns.OnOptionChanged
  function ns.OnOptionChanged(key, value, ...)
    local r = { baseOpt(key, value, ...) }
    if key == "hcDanger" or key == "hcManual" then pcall(H.Update, false)
    elseif key == "hcGlowFrameInt" or key == "hcGlowDropInt" then pcall(H.Preview) end
    return unpack(r)
  end
end
