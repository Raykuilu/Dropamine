-- Dropamine 3.6.2 — XP de repos sur la case Niveau.
--  * « z z Z » dorés (comme au-dessus du portrait du jeu) dans le coin haut
--    droit de l'icône EN ZONE DE REPOS (IsResting), s'il reste du repos : 1 z (< 25 % d'un
--    niveau), 2 z (< 75 %), 3 z (≥ 75 % ; le repos va jusqu'à 150 %).
--  * Fiole qui se remplit : pendant le repos (IsResting) et sous le plafond
--    (150 % d'un niveau), un liquide bleu « repos » translucide monte du bas
--    de l'icône jusqu'à repos / plafond, avec une vague à sa surface ; hors
--    repos, s'il reste du repos : le liquide reste à son niveau, sans vague.
--  * Caché au niveau maximum, sans XP de repos, en combat (animations
--    arrêtées), en mode calme actif, ou option décochée.
--  * Tout est NOTRE dessin, enfant de la case (hérite de son alpha : fondu au
--    repos, opacité) ; AnimationGroups en boucle, aucun OnUpdate ; rien n'est
--    créé en combat ; aucun cadre de Blizzard touché.
local _, ns = ...
local Tr = ns.L
local UI = ns.UI
local V = ns.View

local R = { stats = { builds = 0, liquids = 0, applies = 0 } }
ns.Rested = R

local MEDIA = "Interface\\AddOns\\Dropamine\\Media\\"
R.WAVE_TEX = MEDIA .. "Dropamine-Wave"
R.Z_COLOR = { 0.85, 0.93, 1.0 }     -- 3.6.2 (retour Arnaud) : blanc bleuté, plus lisible que l'or
R.Z_FONT = "Fonts\\FRIZQT__.TTF"
R.Z_SIZES = { 8, 10, 12 }
R.Z_TEXT = { "z", "z", "Z" }
R.Z_RISE = { 1, 2 }   -- montée courte : le grand Z reste dans le portrait
R.Z_PEAK = 1.0
R.Z_SHADOW = { 0, 0, 0, 1 }
R.Z_SHADOW_OFF = { 1, -1 }
R.Z_BOX = 12                          -- cadre de chaque z (≥ plus grande police)
R.Z_STEP = { 5, 3 }                   -- décalage d'un z au suivant
R.Z_HOLDER = { 22, 20 }               -- 2×5+12 = 22 de large, 2×3+12+2 = 20 de haut
R.Z_INSET = { 2, 1 }                  -- retrait du coin haut-droit (montée 1 px + ombre 1 px à droite)
R.Z_TIME = 2.4
R.Z_STAGGER = 0.8
R.LIQ_COLOR = { 0.35, 0.55, 1.0 }   -- bleu de l'XP de repos
R.LIQ_ALPHA = 0.3                    -- (historique ; voir R.LIQ ci-dessous)
-- 3.6.2 (retours Arnaud) : deux allures pour la fiole.
--  charge : en zone de repos, repos < plafond → vague bien visible qui défile
--           (crêtes de 3,75 px, une période en 2,4 s, surface plus claire).
--  calme  : hors repos (ou plafond atteint) → liquide léger, crêtes de 1,5 px
--           qui défilent très lentement (10 s).
-- Le CORPS du liquide ne bouge jamais : ancré au bas du portrait, hauteur =
-- repos / (1,5 × niveau) × hauteur du portrait. Seule la bande de vague défile,
-- horizontalement, centrée sur cette ligne de surface (aucun balancement).
-- La texture de vague fait 37,5 % de sa hauteur en creux-crête (lignes 14→26
-- sur 32, en partant du bas) : ligne moyenne à 62,5 % de la bande.
R.LIQ = {
  charge = { body = 0.36, wave = 0.80, color = { 0.60, 0.80, 1.00 }, h = 10, period = 2.4, step = 1 / 30 },
  calme  = { body = 0.16, wave = 0.28, color = { 0.35, 0.55, 1.00 }, h = 4,  period = 10,  step = 0.1 },
}
R.WAVE_MID = 0.625                   -- ligne moyenne de la vague (fraction de la bande, depuis le bas)
R.WAVE_U = 0.5                       -- une période de vague = la moitié de la texture (2 périodes / 128 px)
R.WAVE_H = R.LIQ.charge.h
R.WAVE_TIME = R.LIQ.charge.period
R.FADE_TIME = 0.8                    -- fondu entre les deux allures
R.CAP_K = 1.5                       -- plafond du repos : 150 % d'un niveau

local function N(v) return ns.N and ns.N(v) or (type(v) == "number" and v or nil) end
local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local r = { pcall(fn, ...) }
  if not r[1] then return nil end
  return unpack(r, 2)
end
local function InCombat()
  if type(_G.InCombatLockdown) == "function" then
    local ok, v = pcall(_G.InCombatLockdown)
    if ok and v then return true end
  end
  return ns.InCombat and ns.InCombat() or false
end

------------------------------------------------------------------------------
-- État (pur : testable)
------------------------------------------------------------------------------
function R.ZCount(rested, max)
  rested, max = N(rested), N(max)
  if not rested or rested <= 0 or not max or max <= 0 then return 0 end
  local k = rested / max
  if k < 0.25 then return 1 elseif k < 0.75 then return 2 end
  return 3
end

-- { z = 0..3, liquid = nil | "wave" | "static", frac = 0..1, rested, max, why }
function R.State()
  local st = { z = 0, frac = 0 }
  if ns.Opt and not ns.Opt("restedAnim") then st.why = "option" return st end
  if InCombat() then st.why = "combat" return st end
  if ns.Progress and ns.Progress.QuietActive and ns.Progress.QuietActive() then st.why = "calme" return st end
  local level = N(Call(_G.UnitLevel, "player")) or 0
  local cap = (ns.GetLevelCap and ns.GetLevelCap()) or 60
  if level >= cap then st.why = "max" return st end
  local max = N(Call(_G.UnitXPMax, "player"))
  if not max or max <= 0 then st.why = "xp" return st end
  local rested = N(Call(_G.GetXPExhaustion))
  st.rested, st.max = rested, max
  local capR = R.CAP_K * max
  local resting = Call(_G.IsResting) and true or false
  st.resting = resting
  -- 3.6.2 (retour en jeu) : les z SEULEMENT en zone de repos ; dehors, il ne
  -- reste que le liquide immobile.
  st.z = resting and R.ZCount(rested, max) or 0
  if resting and (rested or 0) < capR then
    st.liquid, st.frac = "wave", math.max(0, (rested or 0) / capR)
  elseif rested and rested > 0 then
    st.liquid, st.frac = "static", math.min(1, rested / capR)
  end
  if st.z == 0 and not st.liquid then st.why = "aucun repos" end
  return st
end

------------------------------------------------------------------------------
-- Dessin
------------------------------------------------------------------------------
local function NewAnim(ag, kind)
  local ok, a = pcall(ag.CreateAnimation, ag, kind)
  return ok and a or nil
end
local function Loop(ag, mode) if ag and ag.SetLooping then pcall(ag.SetLooping, ag, mode or "REPEAT") end end
local function Alpha(a, from, to, dur, delay)
  if not a then return end
  if a.SetFromAlpha then pcall(a.SetFromAlpha, a, from) pcall(a.SetToAlpha, a, to)
  elseif a.SetChange then pcall(a.SetChange, a, to - from) end
  pcall(a.SetDuration, a, dur)
  if delay and a.SetStartDelay then pcall(a.SetStartDelay, a, delay) end
end
local function Play(ag) if ag and not (ag.IsPlaying and ag:IsPlaying()) then pcall(ag.Play, ag) end end
local function Stop(ag) if ag and ag.Stop then pcall(ag.Stop, ag) end end
local function Anchor(t) return (t.icon and t.icon.GetWidth) and t.icon or t end
local function Solid(tex, c, a)
  local ok = tex.SetColorTexture and pcall(tex.SetColorTexture, tex, c[1], c[2], c[3], a)
  if not ok then pcall(tex.SetTexture, tex, "Interface\\Buttons\\WHITE8X8") if tex.SetVertexColor then pcall(tex.SetVertexColor, tex, c[1], c[2], c[3], a) end end
end

function R.BuildZ(t)
  if t._rzz then return t._rzz end
  local h = CreateFrame("Frame", nil, t)
  h._osrsOwn = true
  if h.EnableMouse then h:EnableMouse(false) end
  h:SetSize(R.Z_HOLDER[1], R.Z_HOLDER[2])
  h.z = {}
  for i = 1, 3 do
    local f = CreateFrame("Frame", nil, h)
    if f.EnableMouse then f:EnableMouse(false) end
    f:SetSize(R.Z_BOX, R.Z_BOX)
    f:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", (i - 1) * R.Z_STEP[1], (i - 1) * R.Z_STEP[2])
    local fs = f:CreateFontString(nil, "OVERLAY")
    if not (fs.SetFont and pcall(fs.SetFont, fs, R.Z_FONT, R.Z_SIZES[i], "OUTLINE")) and fs.SetFontObject then
      pcall(fs.SetFontObject, fs, "GameFontNormalSmall")
    end
    fs:SetPoint("CENTER", f, "CENTER", 0, 0)
    fs:SetText(R.Z_TEXT[i])
    fs:SetTextColor(R.Z_COLOR[1], R.Z_COLOR[2], R.Z_COLOR[3], 1)
    if fs.SetShadowColor then pcall(fs.SetShadowColor, fs, R.Z_SHADOW[1], R.Z_SHADOW[2], R.Z_SHADOW[3], R.Z_SHADOW[4]) end
    if fs.SetShadowOffset then pcall(fs.SetShadowOffset, fs, R.Z_SHADOW_OFF[1], R.Z_SHADOW_OFF[2]) end
    f.fs = fs
    f:SetAlpha(0)       -- invisible entre deux montées (pendant le décalage)
    if f.CreateAnimationGroup then
      local ok, ag = pcall(f.CreateAnimationGroup, f)
      if ok and ag then
        local delay = (i - 1) * R.Z_STAGGER
        local tr = NewAnim(ag, "Translation")
        if tr then pcall(tr.SetOffset, tr, R.Z_RISE[1], R.Z_RISE[2]) pcall(tr.SetDuration, tr, R.Z_TIME) if tr.SetStartDelay then pcall(tr.SetStartDelay, tr, delay) end end
        Alpha(NewAnim(ag, "Alpha"), 0, R.Z_PEAK, R.Z_TIME * 0.3, delay)
        local out = NewAnim(ag, "Alpha")
        Alpha(out, R.Z_PEAK, 0, R.Z_TIME * 0.7, delay + R.Z_TIME * 0.3)
        Loop(ag, "REPEAT")
        f.ag = ag
      end
    end
    f:Hide()
    h.z[i] = f
  end
  t._rzz = h
  R.stats.builds = R.stats.builds + 1
  return h
end

-- 3.6.2 (retour en jeu) : la fiole n'est PLUS un cadre enfant (il passait
-- au-dessus du biseau, du chiffre et débordait du cadre de l'icône) : ce sont
-- deux textures de la case elle-même, couche ARTWORK juste au-dessus de
-- l'icône (sous le biseau et le texte, en OVERLAY), ancrées sur l'icône par
-- ses deux bords et masquées par LE masque de l'icône (même cadre) : elles ne
-- peuvent jamais dépasser du portrait. L'icône n'est jamais touchée.
local LIQ = {}
LIQ.__index = LIQ
function LIQ:Show() self.shown = true end
function LIQ:Hide()
  self.shown = false
  self.mode = nil
  for _, w in ipairs({ self.wave, self.calm }) do Stop(w.fadeAg) w:Hide() end
  Stop(self.body.fadeAg)
  self.body:Hide()
  if R.SyncDriver then R.SyncDriver() end
end
function LIQ:IsShown() return self.shown and true or false end

-- Défilement horizontal de la vague. TextureCoordTranslation n'existe pas /
-- ne fait rien sur le client Forever, et une Translation déplacerait la
-- texture hors du portrait (pas de découpe fiable) : on décale nous-mêmes les
-- coordonnées de texture (SetTexCoord) depuis UN cadre pilote, limité à
-- 30 images/s en charge et 10/s au calme, et CACHÉ (donc sans aucun
-- OnUpdate) dès qu'aucune vague n'est visible.
local function SetUV(w)
  if w.SetTexCoord then pcall(w.SetTexCoord, w, w.u or 0, (w.u or 0) + R.WAVE_U, w.vt or 0, w.vb or 1) end
end
function R.Advance(w, dt)
  local P = w.prof
  w.u = ((w.u or 0) + dt * R.WAVE_U / P.period) % R.WAVE_U
  SetUV(w)
  return w.u
end
local function ActiveWaves()
  local list = {}
  for _, t in ipairs(R.Tiles()) do
    local lf = t._rliq
    if lf and lf.shown and t.IsVisible and t:IsVisible() then
      for _, w in ipairs({ lf.wave, lf.calm }) do if w:IsShown() then list[#list + 1] = w end end
    end
  end
  return list
end
R.drive = { frames = 0, steps = 0 }
function R.DriverTick(self, elapsed)
  R.drive.frames = R.drive.frames + 1
  R._acc = (R._acc or 0) + (N(elapsed) or 0)
  local list = ActiveWaves()
  if #list == 0 then R._acc = 0 if self and self.Hide then self:Hide() end return end
  local step = R.LIQ.calme.step
  for _, w in ipairs(list) do if w.prof.step < step then step = w.prof.step end end
  if R._acc < step then return end
  local dt = math.min(R._acc, 0.25)   -- après un gel d'écran, pas de saut géant
  R._acc = 0
  R.drive.steps = R.drive.steps + 1
  for _, w in ipairs(list) do R.Advance(w, dt) end
end
function R.SyncDriver()
  local need = #ActiveWaves() > 0
  if need and not R.driver then
    local okF, f = pcall(CreateFrame, "Frame", "DropamineRestedWave")
    if not (okF and f) then return end
    f:Hide()
    f:SetScript("OnUpdate", R.DriverTick)
    R.driver = f
  end
  local f = R.driver
  if not f then return end
  if need and not f:IsShown() then R._acc = 0 f:Show()
  elseif not need and f:IsShown() then f:Hide() end
end

local function NewWave(t, sub, prof)
  local w = t:CreateTexture(nil, "ARTWORK", nil, sub)
  pcall(w.SetTexture, w, R.WAVE_TEX)
  local c = prof.color
  if w.SetVertexColor then pcall(w.SetVertexColor, w, c[1], c[2], c[3], 1) end
  if w.SetAlpha then pcall(w.SetAlpha, w, 0) end
  w.prof, w.u, w.vt, w.vb = prof, 0, 0, 1
  SetUV(w)
  w:Hide()
  return w
end

-- fondu d'alpha (AnimationGroup « Alpha ») ; l'alpha final est posé tout de
-- suite (si l'animation manque, on saute directement au but)
local function Fade(x, from, to, instant)
  x.alphaTo = to
  if x.SetAlpha then pcall(x.SetAlpha, x, to) end
  if instant or from == to or not x.CreateAnimationGroup then
    Stop(x.fadeAg)
    if to <= 0 then x:Hide() end
    return
  end
  if not x.fadeAg then
    local ok, ag = pcall(x.CreateAnimationGroup, x)
    if not (ok and ag) then if to <= 0 then x:Hide() end return end
    x.fadeAnim = NewAnim(ag, "Alpha")
    if x.fadeAnim and x.fadeAnim.SetToFinalAlpha then pcall(x.fadeAnim.SetToFinalAlpha, x.fadeAnim, true) end
    if ag.SetScript then
      pcall(ag.SetScript, ag, "OnFinished", function()
        if (x.alphaTo or 0) <= 0 then x:Hide() R.SyncDriver() end
      end)
    end
    x.fadeAg = ag
  end
  local a = x.fadeAnim
  if a then
    pcall(a.SetFromAlpha, a, from) pcall(a.SetToAlpha, a, to) pcall(a.SetDuration, a, R.FADE_TIME)
    if a.SetSmoothing then pcall(a.SetSmoothing, a, "IN_OUT") end
  end
  Stop(x.fadeAg)
  pcall(x.fadeAg.Play, x.fadeAg)
end
R.Fade = Fade

function R.BuildLiquid(t)
  if t._rliq then return t._rliq end
  local lf = setmetatable({ owner = t, shown = false }, LIQ)
  lf.body = t:CreateTexture(nil, "ARTWORK", nil, 4)
  Solid(lf.body, R.LIQ_COLOR, 1)
  if lf.body.SetAlpha then pcall(lf.body.SetAlpha, lf.body, 0) end
  lf.wave = NewWave(t, 5, R.LIQ.charge)   -- allure « charge »
  lf.calm = NewWave(t, 5, R.LIQ.calme)    -- allure « calme »
  lf.body:Hide()
  t._rliq = lf
  R.stats.liquids = R.stats.liquids + 1
  return lf
end

-- masque de l'icône (thème FlareUI : coins biseautés ; Classique : neutre)
local function SyncMask(t, lf)
  local im = t.icon and t.icon._thMask
  if im == lf._mask then return end
  for _, x in ipairs({ lf.body, lf.wave, lf.calm }) do
    if lf._mask and x.RemoveMaskTexture then pcall(x.RemoveMaskTexture, x, lf._mask) end
    if im and x.AddMaskTexture then pcall(x.AddMaskTexture, x, im) end
  end
  lf._mask = im
end

-- bande de vague centrée sur la surface L, rognée (hauteur ET coordonnées de
-- texture) aux bords haut et bas du portrait : elle n'en sort jamais.
function R.PlaceWave(w, a, L, H)
  local h = w.prof.h
  local bot = L - R.WAVE_MID * h
  local top = bot + h
  local b0, t0 = math.max(0, bot), math.min(H, top)
  w.surfaceY = bot + R.WAVE_MID * h
  if t0 - b0 < 0.5 then w.cut = true return false end
  w.cut = false
  w.vt, w.vb = (top - t0) / h, 1 - (b0 - bot) / h
  w:ClearAllPoints()
  w:SetPoint("BOTTOMLEFT", a, "BOTTOMLEFT", 0, b0)
  w:SetPoint("BOTTOMRIGHT", a, "BOTTOMRIGHT", 0, b0)
  w:SetHeight(t0 - b0)
  SetUV(w)
  return true
end

function R.HideTile(t)
  local h, lf = t and t._rzz, t and t._rliq
  if h then for _, f in ipairs(h.z) do Stop(f.ag) f:Hide() end h:Hide() end
  if lf then lf:Hide() end
  if t then t._restState = nil end
end

function R.Apply(t)
  if type(t) ~= "table" then return end
  local d = t.data
  if not (d and d.kind == "level" and not d.placeholder) then
    if t._rzz or t._rliq then R.HideTile(t) end
    return
  end
  local st = R.State()
  t._restState = st
  if st.resting ~= nil then R._lastResting = st.resting end
  -- un peinturage peut afficher les z : démarrer le filet si besoin (jamais l'arrêter ici)
  if (st.z > 0 or st.liquid == "wave") and not R.ticker then R.SyncTicker(true) end
  R.stats.applies = R.stats.applies + 1
  if st.z == 0 and not st.liquid then R.HideTile(t) t._restState = st return end
  local a = Anchor(t)
  local base = (t.GetFrameLevel and N(t:GetFrameLevel())) or 1
  -- z
  local stealZ = false  -- z uniquement sur la case Niveau ; plus sur la fiole
  if st.z > 0 and stealZ then
    if t._rzz then
      for _, f in ipairs(t._rzz.z) do Stop(f.ag) f:Hide() end
      t._rzz:Hide()
    end
  elseif st.z > 0 then
    local h = R.BuildZ(t)
    h:ClearAllPoints()
    h:SetPoint("TOPRIGHT", a, "TOPRIGHT", -R.Z_INSET[1], -R.Z_INSET[2])   -- dans le coin de l'icône
    if h.SetFrameLevel then pcall(h.SetFrameLevel, h, base + 7) end
    h:Show()
    for i, f in ipairs(h.z) do
      if i <= st.z then f:Show() Play(f.ag) else Stop(f.ag) f:Hide() end
    end
  elseif t._rzz then
    for _, f in ipairs(t._rzz.z) do Stop(f.ag) f:Hide() end
    t._rzz:Hide()
  end
  -- fiole : corps ancré au bas de l'icône, surface à L = frac × H (exact)
  if st.liquid then
    local lf = R.BuildLiquid(t)
    SyncMask(t, lf)
    local H = (a.GetHeight and N(a:GetHeight())) or 36
    local mode = (st.liquid == "wave") and "charge" or "calme"
    local P = R.LIQ[mode]
    local frac = math.max(0, math.min(1, st.frac or 0))
    local L = math.floor(H * frac + 0.5)
    if st.liquid == "static" and L < 1 then L = 1 end   -- un peu de repos : au moins 1 px
    lf.bodyH, lf.surface, lf.H = L, L, H
    if L > 0 then
      lf.body:ClearAllPoints()
      lf.body:SetPoint("BOTTOMLEFT", a, "BOTTOMLEFT", 0, 0)
      lf.body:SetPoint("BOTTOMRIGHT", a, "BOTTOMRIGHT", 0, 0)
      lf.body:SetHeight(L)
      lf.body:Show()
    else
      lf.body:Hide()
    end
    local fits = {}
    for _, w in ipairs({ lf.wave, lf.calm }) do fits[w] = R.PlaceWave(w, a, L, H) end
    local prev = lf.mode
    local instant = (prev == nil) or not lf.shown
    local inW, outW = (mode == "charge") and lf.wave or lf.calm, (mode == "charge") and lf.calm or lf.wave
    if prev ~= mode or instant then
      Fade(lf.body, instant and P.body or ((prev and R.LIQ[prev].body) or 0), P.body, instant)
      if fits[inW] then inW:Show() Fade(inW, instant and P.wave or 0, P.wave, instant) else Fade(inW, 0, 0, true) end
      if outW:IsShown() and fits[outW] then Fade(outW, (prev and R.LIQ[prev].wave) or 0, 0, instant) else Fade(outW, 0, 0, true) end
      if prev and prev ~= mode then R.stats.switches = (R.stats.switches or 0) + 1 end
      lf.mode = mode
    else
      if fits[inW] then
        if not inW:IsShown() then inW:Show() Fade(inW, P.wave, P.wave, true) end
      else
        Fade(inW, 0, 0, true)
      end
      if outW:IsShown() and not fits[outW] then Fade(outW, 0, 0, true) end
    end
    lf:Show()
    R.SyncDriver()
  elseif t._rliq then
    t._rliq:Hide()
  end
end

-- Filet de sécurité : PLAYER_UPDATE_RESTING ne part pas toujours en sortant
-- d'une auberge / d'une ville ; tant que les z ou la vague sont affichés
-- (donc en zone de repos), on relit IsResting() toutes les 2 s. Arrêté dès
-- qu'il n'y a plus rien qui dépend du repos.
R.TICK = 2
R.tick = { runs = 0, refreshes = 0 }
function R.Check()
  R.tick.runs = R.tick.runs + 1
  -- panneau fermé / case cachée : plus rien à surveiller, le filet s'arrête
  local any = false
  for _, t in ipairs(R.Tiles()) do
    local st = t._restState
    if st and t.IsVisible and t:IsVisible() and (st.z > 0 or st.liquid == "wave") then any = true break end
  end
  if not any then R.SyncTicker(false) return end
  local now = Call(_G.IsResting) and true or false
  if now ~= R._lastResting then R.tick.refreshes = R.tick.refreshes + 1 R.RefreshAll() end
end
function R.SyncTicker(need)
  if need and not R.ticker then
    local CT = rawget(_G, "C_Timer")
    if type(CT) == "table" and type(CT.NewTicker) == "function" then
      local ok, tk = pcall(CT.NewTicker, R.TICK, R.Check)
      if ok and tk then R.ticker = tk end
    end
  elseif not need and R.ticker then
    if R.ticker.Cancel then pcall(R.ticker.Cancel, R.ticker) end
    R.ticker = nil
  end
end

function R.Tiles()
  return (UI and UI.embed and UI.embed.tiles) or {}
end
function R.RefreshAll()
  local need = false
  for _, t in ipairs(R.Tiles()) do
    if t._rzz or t._rliq or (t.data and t.data.kind == "level") then
      pcall(R.Apply, t)
      local st = t._restState
      if st and t.IsShown and t:IsShown() and (st.z > 0 or st.liquid == "wave") then need = true end
    end
  end
  R.SyncTicker(need)
end

-- Ne relance Apply que si le repos ou l'XP de repos a vraiment changé
-- (un ZONE_CHANGED d'auberge ne doit pas tout reconstruire).
function R.RequestRefresh(reason)
  reason = reason or ""
  local nowR = Call(_G.IsResting) and true or false
  local exh = N(Call(_G.GetXPExhaustion)) or 0
  local force = reason == "option" or reason == "PLAYER_ENTERING_WORLD"
    or reason == "PLAYER_LEVEL_UP" or reason == "test"
    or reason == "PLAYER_REGEN_ENABLED" or reason == "PLAYER_REGEN_DISABLED"
  if not force and R._lastResting == nowR and R._lastExh == exh then
    return
  end
  R._lastResting, R._lastExh = nowR, exh
  R.RefreshAll()
end

-- Info-bulle de la case Niveau : « XP de repos : 12 345 (45 % d'un niveau) »
function R.Num(n)
  local s = tostring(math.floor((N(n) or 0) + 0.5))
  local sep = (ns.IsFrench and ns.IsFrench()) and " " or ","
  local out = s:reverse():gsub("(%d%d%d)", "%1" .. sep):reverse()
  return (out:gsub("^" .. (sep == "," and "," or " "), ""))
end
function R.TooltipLine()
  local rested = N(Call(_G.GetXPExhaustion))
  local max = N(Call(_G.UnitXPMax, "player"))
  if not rested or rested <= 0 or not max or max <= 0 then return nil end
  local pct = math.floor(rested / max * 100 + 0.5)
  local line = Tr["XP de repos"] .. " : " .. R.Num(rested) .. " (" .. pct .. Tr[" % d'un niveau"] .. ")"
  local NL = ns.NativeLook
  return (NL and NL.TwoTone) and NL.TwoTone(line) or line
end

------------------------------------------------------------------------------
-- Branchements
------------------------------------------------------------------------------
if V and V.PaintTile then
  local base = V.PaintTile
  function V.PaintTile(t, ...)
    local r = { base(t, ...) }
    if t and (t._rzz or t._rliq or (t.data and t.data.kind == "level")) then pcall(R.Apply, t) end
    return unpack(r)
  end
end
if ns.Compact and ns.Compact.TooltipModel then
  local baseModel = ns.Compact.TooltipModel
  function ns.Compact.TooltipModel(d)
    local m = baseModel(d)
    if type(d) == "table" and d.kind == "level" and not d.placeholder and m and m.lines then
      local l = R.TooltipLine()
      if l then
        -- remplace la ligne « XP reposée : N (x % du niveau) » de la section
        -- Progression (Core.RankStatus) : une seule ligne de repos, au format court
        local fmt = Tr["\nXP reposée : %d (%d %% du niveau)"]
        local label = type(fmt) == "string" and fmt:match("^\n(.-)%s*:") or nil
        local done = false
        for _, e in ipairs(m.lines) do
          local plain = type(e[1]) == "string" and e[1]:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") or ""
          if label and plain:sub(1, #label) == label then e[1] = l done = true break end
        end
        if not done then table.insert(m.lines, math.min(#m.lines + 1, 3), { l, 1, 1, 1, false }) end
      end
    end
    return m
  end
end
if ns.On then
  for _, ev in ipairs({ "PLAYER_UPDATE_RESTING", "UPDATE_EXHAUSTION", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP",
    "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA",
    "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD" }) do
    ns.On(ev, function() R.RequestRefresh(ev) end)
  end
end

R.OPTIONS = {
  { type = "check", key = "restedAnim", label = "Animation XP de repos", default = true,
    help = "Petits « z » dorés sur la case Niveau quand tu as de l'XP de repos, et une fiole qui se remplit pendant que tu te reposes.",
    set = function(v) ns.SetOpt("restedAnim", v and true or false) R.RefreshAll() end },
}
if ns.Options then
  ns.Options.EXTRA_HOME.restedAnim = "display"
  local order = ns.Options.ITEM_ORDER and ns.Options.ITEM_ORDER.display
  if order then
    local at = #order + 1
    for i, k in ipairs(order) do if k == "seasonal" then at = i + 1 break end end
    table.insert(order, at, "restedAnim")
  end
  for _, it in ipairs(R.OPTIONS) do ns.Options.EXTRA[#ns.Options.EXTRA + 1] = it end
  ns.Options.ITEMS = ns.Options.All()
end
