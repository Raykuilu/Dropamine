-- Dropamine 3.3.5 — panneau compact « style notifications » :
--   1) infobulle au survol = TOUT le détail de l'ancien volet de droite ;
--   2) plus de surbrillance de sélection (il n'y a plus de volet à piloter) ;
--   3) toasts et grille unifiés : quand un toast s'efface, un petit éclat
--      (son icône) vole jusqu'à la case concernée ; à l'arrivée la case
--      pulse aux couleurs des toasts, son nombre passe à la vraie valeur et
--      un petit gain vert (« +178 », « +1 ») monte et s'efface, façon XP drop
--      d'OSRS.
-- Uniquement NOS cadres, textures, FontStrings et AnimationGroups
-- (Translation / Alpha / Scale). Aucun cadre natif touché. Le report des
-- toasts en fin de combat est inchangé (on n'agit qu'à leur disparition).
local ADDON, ns = ...
local Tr = ns.L   -- 3.5.19 : textes traduits (Locales/)
local UI = ns.UI
local H = UI._H
local V = ns.View
local W = ns.Window
local I = ns.Icons
local P = ns.Panel
local SafeStep, RectOf = H.SafeStep, H.RectOf
local N = ns.N

local C = {}
ns.Compact = C

local GOLD = { 1, 0.82, 0 }
local TOAST_YELLOW = { 1.00, 0.82, 0.20 }   -- titre des toasts (UI.lua)
local GAIN_GREEN = { 0.25, 1.00, 0.25 }     -- ligne verte des toasts (UI.lua)
local WHITE8 = "Interface\\Buttons\\WHITE8X8"

------------------------------------------------------------------------------
-- 1) Infobulle : tout le contenu de l'ancien volet de détail
------------------------------------------------------------------------------
local function split(txt)
  local out = {}
  for l in string.gmatch((txt or "") .. "\n", "(.-)\n") do if l ~= "" then out[#out + 1] = l end end
  return out
end
local function TwoTone(l) local NL = ns.NativeLook return (NL and NL.TwoTone and NL.TwoTone(l)) or l end

-- même texte que la ligne « Compte dans le total » du volet (UI.lua)
function C.ContributionLine(d)
  if not d then return "" end
  if d.kind == "stat" then return Tr["Non inclus dans le total (caractéristique)."] end
  if d.excludedMonte then return Tr["Affichée mais non incluse : aucun plafond de Monte n'est documenté."] end
  if d.combatTile and d.skillName and d.skillName ~= d.name then
    return Tr["Compte dans le total : +"] .. tostring(d.current or 0) .. "  (" .. d.skillName .. ")"
  end
  if d.inTotal then return Tr["Compte dans le total : +"] .. tostring(d.current or 0) end
  return ""
end

local function HistoryLine(id)
  local Q = ns.QoL
  if not (Q and Q.Series and ns.Opt("historique")) then return nil end
  local ok, series = pcall(Q.Series, id)
  if not ok or type(series) ~= "table" or #series < 2 then return nil end
  local delta = series[#series].value - series[1].value
  return #series .. Tr[" derniers jours : "] .. ((delta >= 0) and "+" or "") .. delta
end

-- Modèle : { title = , lines = { { text, r, g, b, wrap, header = bool } } }
function C.TooltipModel(d)
  local m = { lines = {} }
  local L = m.lines
  local function add(text, r, g, b, wrap) if text and text ~= "" then L[#L + 1] = { text, r or 1, g or 1, b or 1, wrap and true or false } end end
  local function header(text) L[#L + 1] = { " ", 1, 1, 1, false, spacer = true } L[#L + 1] = { text, GOLD[1], GOLD[2], GOLD[3], false, header = true } end
  if not d then m.title = "?" return m end
  local NL = ns.NativeLook
  if d.kind == "total" then
    local snap = UI.snapshot
    m.title = Tr["Niveau total"]
    local total = snap and (snap.total or snap.ficTotal) or 0
    local tmax = snap and (snap.totalMax or snap.ficMax) or ns.TOTAL_MAX or 2460
    add(Tr["Total "] .. tostring(total) .. " / " .. tostring(tmax), 1, 1, 1)
    add(Tr[ns.TOTAL_SHORT_FR], 1, 1, 1, true)
    local det = {}
    for _, b in ipairs(snap and snap.breakdown or {}) do det[#det + 1] = TwoTone(b.name .. " : +" .. tostring(b.value)) end
    if #det > 0 then header(Tr["Détail"]) for _, l in ipairs(det) do add(l, 1, 1, 1) end end
    local gain, glist = ns.DailyGains and ns.DailyGains(snap)
    if gain and gain > 0 then
      header(Tr["Aujourd'hui"])
      add(TwoTone(Tr["Total : +"] .. tostring(gain)), 1, 1, 1)
      for _, e in ipairs(glist or {}) do add(e.name .. " +" .. tostring(e.gain), GAIN_GREEN[1], GAIN_GREEN[2], GAIN_GREEN[3]) end
    end
    local hl = HistoryLine(nil)
    if hl then add(hl, 0.8, 0.8, 0.8) end
    if ns.Flight and ns.Flight.ShowPauseTip and ns.Flight.ShowPauseTip() then
      add(Tr["En pause pendant le vol"], 1, 0.82, 0)
    end
    return m
  end
  m.title = UI:DetailLabelFor(d) or d.name or "?"
  local cap = N(d.apiMax) or 0
  local cur = N(d.current) or 0
  -- barre du volet → ligne « rang / max » (XP pour le Niveau)
  if d.placeholder then
    add(d.notLearnedTag or Tr["Pas encore appris"], 0.62, 0.55, 0.45)
  elseif d.kind == "level" then
    if cap <= 0 then cap = ns.GetLevelCap and ns.GetLevelCap() or 60 end
    add(Tr["Niveau "] .. cur .. " / " .. cap, 1, 1, 1)
    local xp = UI.LevelBarXP and UI:LevelBarXP(cur, cap) or nil
    if xp and N(xp.max) and xp.max > 0 then
      local pct = math.floor((xp.cur or 0) / xp.max * 100 + 0.5)
      -- 3.6.2 : le repos a sa propre ligne (Rested.lua) ; plus de « · reposé N » ici
      add("XP " .. tostring(xp.cur) .. " / " .. tostring(xp.max) .. " (" .. pct .. " %)" .. ((N(xp.rested) and xp.rested > 0 and not ns.Rested) and (Tr["  ·  reposé "] .. tostring(xp.rested)) or ""), 0.8, 0.8, 0.8)
    end
  elseif d.kind == "stat" then
    add((d.name or "") .. "  " .. tostring(cur), 1, 1, 1)
  elseif cap > 0 then
    add(Tr["Rang "] .. cur .. " / " .. cap, 1, 1, 1)
  else
    add(tostring(cur), 1, 1, 1)
  end
  -- description
  local desc
  if d.placeholder then desc = "|cff808080" .. tostring(d.placeholderNote or Tr["Emplacement libre."]) .. "|r"
  else desc = UI.DetailDescriptionFor and UI:DetailDescriptionFor(d, nil) or "" end
  local isCombat = (d.kind == "melee" or d.kind == "ranged" or d.kind == "feral" or d.kind == "defense")
  local sections = {}
  local function sec(title, lines)
    local keep = {}
    for _, l in ipairs(lines or {}) do if l and l ~= "" then keep[#keep + 1] = l end end
    if #keep > 0 then sections[#sections + 1] = { title = title, lines = keep } end
  end
  if not d.placeholder then
    local prog = {}
    local st = ns.RankStatus and ns.RankStatus(d, cur, cap)
    if st and st.note and d.kind == "level" then
      for _, l in ipairs(split(st.note)) do prog[#prog + 1] = TwoTone(l) end
    elseif st and st.note then
      local c = st.col or { 1, 1, 1 }
      prog[#prog + 1] = string.format("|cff%02x%02x%02x%s|r", math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255), st.note)
    end
    local extra = UI.DetailExtraLines and UI:DetailExtraLines(d) or ""
    for _, l in ipairs(split(extra)) do prog[#prog + 1] = TwoTone(l) end
    sec(Tr["Progression"], prog)
    if isCombat then
      -- 3.6.2 : détail natif (toucher / critique / coups déviés) en version
      -- COURTE, valeurs lues dans le volet natif ; lu au survol si la fiche
      -- native est ouverte (hors combat), sinon la dernière lecture mémorisée.
      if NL and NL.ReadIfShown then NL.ReadIfShown() end
      local cached = NL and NL.CachedFor and NL.CachedFor(d)
      if cached then
        -- description native : seulement si nous n'en avons pas (pas de doublon)
        if not desc or desc == "" then desc = NL.NativeDesc(d) or "" end
        sec(Tr["Combat"], NL.CompactCombatLines(cached.combat or NL.ParseCombat(cached)))
      end
      if ns.CombatStatsText then
        local okS, stx = pcall(ns.CombatStatsText, d.kind)
        if okS and stx and stx ~= "" then
          local ls = split(stx)
          table.remove(ls, 1)
          for i = 1, #ls do ls[i] = TwoTone(ls[i]) end
          sec(Tr["Statistiques"], ls)
        end
      end
    end
    if ns.Craft and ns.Craft.DetailText and d.id then
      local okC, ct = pcall(ns.Craft.DetailText, d.id)
      if okC and ct and ct ~= "" then sec(Tr["Recettes"], split(ct)) end
    end
  end
  for _, l in ipairs(split(desc)) do add(l, 1, 1, 1, true) end
  for _, s2 in ipairs(sections) do
    header(s2.title)
    for _, l in ipairs(s2.lines) do add(l, 1, 1, 1, true) end
  end
  local contrib = C.ContributionLine(d)
  local hl = (not d.placeholder) and HistoryLine(d.id) or nil
  if contrib ~= "" or hl then L[#L + 1] = { " ", 1, 1, 1, false, spacer = true } end
  if contrib ~= "" then add(contrib, GOLD[1], GOLD[2], GOLD[3], true) end
  if hl then add(hl, 0.8, 0.8, 0.8) end
  return m
end

C.HINT = "Clic droit : objectif  ·  Maj + clic : partager"
C.HINT_NOSHARE = "Clic droit : objectif"
-- 3.5.3 : modèle d'infobulle mémorisé par case (au plus un calcul par seconde,
-- recalculé aussitôt si la grille a été relue) : plus de reconstruction
-- complète à chaque passage de la souris.
C.TIP_TTL = 1
C._tipMemo = setmetatable({}, { __mode = "k" })
function C.ModelFor(d)
  if type(d) ~= "table" then return C.TooltipModel(d) end
  local now = ns.NowSec and ns.NowSec() or 0
  local e = C._tipMemo[d]
  if e and e.snap == UI.snapshot and (now - e.t) < C.TIP_TTL then return e.m end
  local m = C.TooltipModel(d)
  C._tipMemo[d] = { snap = UI.snapshot, t = now, m = m }
  return m
end
function C.FillTooltip(tt, d, tile)
  local m = C.ModelFor(d)
  tt:SetText(m.title, GOLD[1], GOLD[2], GOLD[3])
  for _, l in ipairs(m.lines) do tt:AddLine(l[1], l[2], l[3], l[4], l[5]) end
  if d and d.kind == "total" and ns.QoL and ns.QoL.AltTooltip then pcall(ns.QoL.AltTooltip, tt) end
  -- 3.6.0 : clic sur le total = fenêtre Progression
  if d and d.kind == "total" and ns.ProgressUI then
    tt:AddLine(" ", 1, 1, 1)
    tt:AddLine(Tr["Clic : fenêtre Progression"], 0.6, 0.8, 1)
    if ns.Opt and ns.Opt("partage") then tt:AddLine(Tr["Maj + clic : partager"], 0.6, 0.6, 0.6) end
  end
  if d and d.kind ~= "total" and not d.placeholder then
    tt:AddLine(" ", 1, 1, 1)
    -- 3.5.5 : « Maj + clic : partager » seulement si l'option est active
    tt:AddLine(Tr[(ns.Opt and not ns.Opt("partage")) and C.HINT_NOSHARE or C.HINT], 0.6, 0.6, 0.6)
  end
  C.lastTooltip = m
  return m
end

function I.OnEnter(self)
  UI._hoverTile = self
  self._hover = true
  V.PaintTile(self)
  if P.SetHover then P.SetHover(true) end
  local d = self.data
  if d and GameTooltip then
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    SafeStep("infobulle de case", C.FillTooltip, GameTooltip, d, self)
    GameTooltip:Show()
    self._tipShown = true
    if P.RefreshTipColors then SafeStep("couleurs de l'infobulle", P.RefreshTipColors) end
    -- 3.6.0 : mini-graphe 7 jours sous l'infobulle du total
    if d.kind == "total" and ns.ProgressUI and ns.ProgressUI.ShowMini then
      SafeStep("mini-graphe 7 jours", ns.ProgressUI.ShowMini, GameTooltip, self)
    end
  end
end
function I.OnLeave(self)
  if ns.ProgressUI and ns.ProgressUI.HideMini then pcall(ns.ProgressUI.HideMini) end
  if GameTooltip and self._tipShown then GameTooltip:Hide() end
  self._tipShown = nil
  self._hover = false
  V.PaintTile(self)
  UI._hoverTile = nil
  if P.SetHover then P.SetHover(false) end
end

-- 2) plus de surbrillance « sélectionnée » (seul le survol éclaire la case)
local basePaint = V.PaintTile
function V.PaintTile(t)
  basePaint(t)
  if t and t.checkTex then t.checkTex:Hide() end
  if t and t._icon330 and t.hoverTex then if t._hover then t.hoverTex:Show() else t.hoverTex:Hide() end end
end
-- plus de volet : rien n'est rempli ni montré à droite
function UI:IsRightPaneVisible() return false end

------------------------------------------------------------------------------
-- 3) Toasts → grille
------------------------------------------------------------------------------
C.FLY = 0.55          -- vol de l'éclat (s)
C.GAIN_TIME = 1.5     -- gain vert : montée + fondu
C.GAIN_RISE = 14      -- px
C.PULSE_IN, C.PULSE_OUT = 0.12, 0.35
C.FLY_SIZE = 22
C.holds = {}          -- clé de case → valeur affichée tant que l'éclat vole
C.flights = 0
C.landed = 0

function C.HoldKey(d)
  if not d then return nil end
  if d.kind == "total" then return "total" end
  if d.kind == "level" then return "level" end
  return "s:" .. tostring(d.skillName or d.name or d.id)
end
-- Valeur RETENUE (affichée) pour une case, seulement si plus basse que la vraie.
function I.HeldValue(d)
  local h = C.holds[C.HoldKey(d) or ""]
  if not h then return nil end
  local real = N(d.current) or 0
  if h.value < real then return h.value end
  return nil
end

function C.Tiles()
  local out = {}
  for _, t in ipairs(UI.embed and UI.embed.tiles or {}) do
    if t.data and t.IsShown and t:IsShown() then out[#out + 1] = t end
  end
  return out
end
function C.TileByKey(key)
  for _, t in ipairs(C.Tiles()) do if C.HoldKey(t.data) == key then return t end end
end
function C.SkillTile(opts)
  for _, t in ipairs(C.Tiles()) do
    local d = t.data
    if d.kind ~= "total" and d.kind ~= "level" and not d.placeholder then
      if (opts.skillName and (d.skillName == opts.skillName or d.name == opts.skillName))
        or (opts.skillId and d.id == opts.skillId) then return t end
    end
  end
end
local function Shown(t) local v = t and t._countTop and tonumber(t._countTop) return v end

C.KINDS = { skill = true, xp = true, levelup = true, rankup = true }
-- Cibles d'un toast : { key, gain (nombre ou nil), hold (bool) }
function C.TargetsFor(opts, drop)
  local out = {}
  local kind = opts.kind
  local acc = drop and N(drop._acc) or (opts.accumulate and N(opts.accumulate.delta)) or nil
  if kind == "skill" then
    local t = C.SkillTile(opts)
    if t then
      local d = acc or 1
      out[#out + 1] = { key = C.HoldKey(t.data), gain = d, hold = true }
      if t.data.inTotal or t.data.combatTile then out[#out + 1] = { key = "total", gain = d, hold = true } end
    end
  elseif kind == "rankup" then
    local t = C.SkillTile(opts)
    if t then out[#out + 1] = { key = C.HoldKey(t.data) } end
  elseif kind == "xp" then
    out[#out + 1] = { key = "level", gain = acc, suffix = "" }
  elseif kind == "levelup" then
    out[#out + 1] = { key = "level", gain = 1, hold = true }
    out[#out + 1] = { key = "total", gain = 1, hold = true }
  end
  return out
end

local function After(sec, fn)
  if type(C_Timer) == "table" and type(C_Timer.After) == "function" then C_Timer.After(sec, fn) return true end
  return false
end
local function Now() return (type(GetTime) == "function" and N(GetTime())) or 0 end
local function DropAlive(drop)
  for _, o in ipairs(UI.dropsActive or {}) do if o == drop then return true end end
  return false
end

function C.Refresh(keys)
  for _, k in ipairs(keys) do
    local t = C.TileByKey(k)
    if t then SafeStep("case après l'éclat", UI.UpdateTile, UI, t, t.data) end
  end
end
function C.Release(entry)
  if entry.released then return end
  entry.released = true
  local keys = {}
  for _, tg in ipairs(entry.targets) do
    local h = C.holds[tg.key]
    if h and h.entry == entry then C.holds[tg.key] = nil end
    keys[#keys + 1] = tg.key
  end
  C.Refresh(keys)
end

-- Retenue posée à l'apparition du toast : la case garde le nombre qu'elle
-- affiche déjà jusqu'à l'arrivée de l'éclat. Filet : jamais bloquée (minuterie
-- relancée tant que le toast vit, puis libération forcée).
C.FALLBACK_STEP, C.FALLBACK_MAX = 1.0, 30
function C.Register(drop, iconPath, opts)
  if not (W.IsShown() and UI.embed) then return nil end
  local e = drop._osrsFly
  local targets = C.TargetsFor(opts, drop)
  if #targets == 0 then return nil end
  if P.Wake then P.Wake("gain") end   -- 3.3.6 : opacité pleine à chaque gain
  if not ns.Opt("flyAnim") then return nil end   -- 3.3.8 : /drop animation off (case mise à jour tout de suite)
  if not e then
    e = { drop = drop, icon = iconPath, kind = opts.kind, targets = targets, born = Now() }
    drop._osrsFly = e
    if drop.HookScript then
      drop:HookScript("OnHide", function(self)
        local en = self._osrsFly
        if not en or en.launched then return end
        local function check() if not DropAlive(self) then C.Launch(en) end end
        if not After(0, check) then check() end
      end)
    end
    local tries = 0
    local function fallback()
      if e.released then return end
      tries = tries + 1
      if DropAlive(drop) and tries < C.FALLBACK_MAX then After(C.FALLBACK_STEP, fallback) return end
      if e.launched then After(C.FLY + 0.5, function() C.Land(e, true) end) return end
      C.Release(e)
    end
    After((UI.DropHold and UI:DropHold() or 2.6) + 1.0, fallback)
  else
    -- toast cumulé (« +1 » → « +2 ») : mêmes cibles, gains à jour, retenue d'origine
    for _, tg in ipairs(targets) do
      local found = false
      for _, old in ipairs(e.targets) do if old.key == tg.key then old.gain = tg.gain found = true end end
      if not found then e.targets[#e.targets + 1] = tg end
    end
  end
  for _, tg in ipairs(e.targets) do
    if tg.hold and not C.holds[tg.key] then
      local t = C.TileByKey(tg.key)
      local v = Shown(t)
      if v then C.holds[tg.key] = { value = v, entry = e } end
    end
  end
  return e
end

local baseSpawn = UI.SpawnDrop
function UI:SpawnDrop(iconPath, title, subtitle, barCur, barMax, rightValue, opts)
  local f = baseSpawn(self, iconPath, title, subtitle, barCur, barMax, rightValue, opts)
  if f and type(opts) == "table" and C.KINDS[opts.kind] and not f._editPreview then
    SafeStep("toast → case", C.Register, f, iconPath, opts)
  end
  return f
end

local function Center(o)
  local l, r, t, b = RectOf(o)
  if not l then return nil end
  local s = 1
  if o.GetEffectiveScale and UIParent and UIParent.GetEffectiveScale then
    local ok1, es = pcall(o.GetEffectiveScale, o)
    local ok2, us = pcall(UIParent.GetEffectiveScale, UIParent)
    if ok1 and ok2 and N(es) and N(us) and us > 0 then s = es / us end
  end
  return (l + r) / 2 * s, (t + b) / 2 * s
end

local function NewAnim(ag, kind)
  local ok, a = pcall(ag.CreateAnimation, ag, kind)
  return ok and a or nil
end
local function AlphaAnim(a, from, to)
  if not a then return end
  if a.SetFromAlpha then pcall(a.SetFromAlpha, a, from) pcall(a.SetToAlpha, a, to)
  elseif a.SetChange then pcall(a.SetChange, a, to - from) end
end
local function ScaleAnim(a, sx)
  if not a then return end
  if a.SetScaleTo then pcall(a.SetScaleTo, a, sx, sx)
  elseif a.SetScale then pcall(a.SetScale, a, sx, sx) end
end

function C.Flyer()
  C.pool = C.pool or {}
  for _, f in ipairs(C.pool) do if not f._busy then return f end end
  local f = CreateFrame("Frame", nil, UIParent)
  f._osrsOwn = true
  if f.EnableMouse then f:EnableMouse(false) end
  pcall(f.SetFrameStrata, f, "DIALOG")
  f:SetSize(C.FLY_SIZE, C.FLY_SIZE)
  f.glow = f:CreateTexture(nil, "BACKGROUND")
  f.glow:SetPoint("TOPLEFT", f, "TOPLEFT", -4, 4)
  f.glow:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 4, -4)
  pcall(f.glow.SetTexture, f.glow, WHITE8)
  if f.glow.SetBlendMode then pcall(f.glow.SetBlendMode, f.glow, "ADD") end
  if f.glow.SetVertexColor then pcall(f.glow.SetVertexColor, f.glow, TOAST_YELLOW[1], TOAST_YELLOW[2], TOAST_YELLOW[3], 0.45) end
  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetAllPoints(f)
  if f.icon.SetTexCoord then pcall(f.icon.SetTexCoord, f.icon, 0.07, 0.93, 0.07, 0.93) end
  if f.CreateAnimationGroup then
    local ok, ag = pcall(f.CreateAnimationGroup, f)
    if ok and ag then
      f.ag = ag
      f.tr = NewAnim(ag, "Translation")
      if f.tr then pcall(f.tr.SetDuration, f.tr, C.FLY) if f.tr.SetSmoothing then pcall(f.tr.SetSmoothing, f.tr, "IN") end end
      f.sc = NewAnim(ag, "Scale")
      if f.sc then pcall(f.sc.SetDuration, f.sc, C.FLY) ScaleAnim(f.sc, 0.6) end
      f.al = NewAnim(ag, "Alpha")
      if f.al then pcall(f.al.SetDuration, f.al, C.FLY * 0.4) if f.al.SetStartDelay then pcall(f.al.SetStartDelay, f.al, C.FLY * 0.6) end AlphaAnim(f.al, 1, 0.2) end
      ag:SetScript("OnFinished", function() f:Hide() f._busy = nil if f._entry then C.Land(f._entry) end end)
    end
  end
  f:Hide()
  C.pool[#C.pool + 1] = f
  return f
end

-- Lancement : seulement si le panneau est ouvert et la case visible ; sinon
-- on libère en silence (la case affiche la vraie valeur, sans animation).
function C.Launch(e)
  if e.launched or e.released then return end
  e.launched = true
  local main = e.targets[1] and C.TileByKey(e.targets[1].key)
  if not (W.IsShown() and main) then C.Release(e) e.skipped = true return end
  local sx, sy = Center(e.drop)
  local ex, ey = Center(main.icon or main)
  if not (sx and ex) then C.Land(e) return end
  local f = C.Flyer()
  f._busy, f._entry = true, e
  pcall(f.icon.SetTexture, f.icon, e.icon or ns.LEVEL_ICON or WHITE8)
  f:ClearAllPoints()
  f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", sx, sy)
  f:SetAlpha(1)
  f:Show()
  e.from, e.to = { sx, sy }, { ex, ey }
  C.flights = C.flights + 1
  if f.ag and f.tr then
    pcall(f.tr.SetOffset, f.tr, ex - sx, ey - sy)
    if f.ag.Stop then pcall(f.ag.Stop, f.ag) end
    f.ag:Play()
    After(C.FLY + 0.5, function() if not e.landed then f:Hide() f._busy = nil C.Land(e) end end)
  else
    f:Hide() f._busy = nil
    C.Land(e)
  end
end

-- Arrivée : vraie valeur, pulsation dorée, gain vert.
function C.Land(e, quiet)
  if e.landed then return end
  e.landed = true
  C.Release(e)
  if quiet or not W.IsShown() then return end
  C.landed = C.landed + 1
  if P.Wake then P.Wake("éclat") end
  for _, tg in ipairs(e.targets) do
    local t = C.TileByKey(tg.key)
    if t then
      C.Pulse(t)
      if tg.gain and tg.gain > 0 then C.Gain(t, "+" .. tostring(math.floor(tg.gain + 0.5))) end
    end
  end
end

function C.Pulse(t)
  local p = t._osrsPulse
  if not p then
    p = CreateFrame("Frame", nil, t)
    p._osrsOwn = true
    if p.EnableMouse then p:EnableMouse(false) end
    p:SetAllPoints(t.icon or t)
    p.tex = p:CreateTexture(nil, "OVERLAY")
    p.tex:SetAllPoints(p)
    pcall(p.tex.SetTexture, p.tex, WHITE8)
    if p.tex.SetBlendMode then pcall(p.tex.SetBlendMode, p.tex, "ADD") end
    if p.tex.SetVertexColor then pcall(p.tex.SetVertexColor, p.tex, TOAST_YELLOW[1], TOAST_YELLOW[2], TOAST_YELLOW[3], 0.55) end
    if p.CreateAnimationGroup then
      local ok, ag = pcall(p.CreateAnimationGroup, p)
      if ok and ag then
        p.ag = ag
        local a1 = NewAnim(ag, "Alpha") if a1 then pcall(a1.SetDuration, a1, C.PULSE_IN) AlphaAnim(a1, 0, 1) if a1.SetOrder then pcall(a1.SetOrder, a1, 1) end end
        local s1 = NewAnim(ag, "Scale") if s1 then pcall(s1.SetDuration, s1, C.PULSE_IN) ScaleAnim(s1, 1.25) if s1.SetOrder then pcall(s1.SetOrder, s1, 1) end end
        local a2 = NewAnim(ag, "Alpha") if a2 then pcall(a2.SetDuration, a2, C.PULSE_OUT) AlphaAnim(a2, 1, 0) if a2.SetOrder then pcall(a2.SetOrder, a2, 2) end end
        ag:SetScript("OnFinished", function() p:Hide() end)
      end
    end
    t._osrsPulse = p
  end
  local base = t.GetFrameLevel and t:GetFrameLevel() or 1
  pcall(p.SetFrameLevel, p, base + 6)
  p:Show()
  p._plays = (p._plays or 0) + 1
  if p.ag then if p.ag.Stop then pcall(p.ag.Stop, p.ag) end p.ag:Play()
  elseif not After(C.PULSE_IN + C.PULSE_OUT, function() p:Hide() end) then p:Hide() end
  return p
end

-- Gain vert façon XP drop d'OSRS : au-dessus de l'icône, monte de quelques
-- pixels et s'efface en ~1,5 s ; police contournée.
function C.Gain(t, text)
  local g = t._osrsGain
  if not g then
    g = CreateFrame("Frame", nil, t)
    g._osrsOwn = true
    if g.EnableMouse then g:EnableMouse(false) end
    g:SetSize(60, 16)
    g:SetPoint("CENTER", t.icon or t, "CENTER", 0, 4)
    local ok, fs = pcall(g.CreateFontString, g, nil, "OVERLAY", "NumberFontNormal")
    if not (ok and fs) then fs = g:CreateFontString(nil, "OVERLAY") end
    pcall(fs.SetFont, fs, I.COUNT_PATH or "Fonts\\ARIALN.TTF", 14, I.TEXT_FLAGS or "")   -- 3.3.9 : ombre fine seulement
    if I.CleanText then I.CleanText(fs) elseif fs.SetShadowOffset then pcall(fs.SetShadowOffset, fs, 1, -1) end
    fs:SetPoint("CENTER", g, "CENTER", 0, 0)
    if fs.SetWordWrap then pcall(fs.SetWordWrap, fs, false) end
    fs:SetTextColor(GAIN_GREEN[1], GAIN_GREEN[2], GAIN_GREEN[3])
    g.fs = fs
    if g.CreateAnimationGroup then
      local ok2, ag = pcall(g.CreateAnimationGroup, g)
      if ok2 and ag then
        g.ag = ag
        local tr = NewAnim(ag, "Translation") if tr then pcall(tr.SetOffset, tr, 0, C.GAIN_RISE) pcall(tr.SetDuration, tr, C.GAIN_TIME) end
        local al = NewAnim(ag, "Alpha")
        if al then pcall(al.SetDuration, al, C.GAIN_TIME * 0.6) if al.SetStartDelay then pcall(al.SetStartDelay, al, C.GAIN_TIME * 0.4) end AlphaAnim(al, 1, 0) end
        ag:SetScript("OnFinished", function() g:Hide() end)
      end
    end
    t._osrsGain = g
  end
  local base = t.GetFrameLevel and t:GetFrameLevel() or 1
  pcall(g.SetFrameLevel, g, base + 8)
  g.fs:SetText(text)
  g:SetAlpha(1)
  g:Show()
  g._plays = (g._plays or 0) + 1
  if g.ag then if g.ag.Stop then pcall(g.ag.Stop, g.ag) end g.ag:Play()
  elseif not After(C.GAIN_TIME, function() g:Hide() end) then g:Hide() end
  C.lastGain = { tile = t, text = text }
  return g
end

-- Panneau fermé : aucune retenue ne survit (rien ne doit rester figé).
local baseHide = W.Hide
function W.Hide(...)
  local r = baseHide(...)
  for k, h in pairs(C.holds) do C.holds[k] = nil end
  return r
end

------------------------------------------------------------------------------
ns.HelpExt = ns.HelpExt or {}
ns.HelpExt[#ns.HelpExt + 1] = "/drop : panneau compact (survol d'une case = tout son détail) · /drop verrou on|off · /drop opacite <0-100> (opacité au repos) · /drop fondu <secondes> · /drop opacite icones <20-100> · /drop categories on|off"

local baseDebug = W.DebugLines
W.DebugLines = function()
  local out = baseDebug()
  local nh = 0 for _ in pairs(C.holds) do nh = nh + 1 end
  out[#out + 1] = "  3.3.5 : habillage des toasts (" .. tostring(W.toastLook) .. "), état " .. tostring(W.chromeState)
    .. " ; éclats lancés " .. C.flights .. ", arrivés " .. C.landed .. ", retenues en cours " .. nh
  return out
end
