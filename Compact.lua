-- Dropamine 3.3.5 — panneau compact « style notifications » :
--   1) infobulle au survol = TOUT le détail de l'ancien volet de droite ;
--   2) plus de surbrillance de sélection (il n'y a plus de volet à piloter) ;
--   3) toasts et grille unifiés : quand un toast s'efface, un petit éclat
--      (son icône) vole jusqu'à la case concernée ; à l'arrivée la case
--      pulse aux couleurs des toasts, son nombre passe à la vraie valeur et
--      un petit « +1 » coloré monte et s'efface, façon XP drop d'OSRS
--      (bleu : armes et défense, vert : métiers, rouge : XP).
--      Une étincelle de la même couleur parcourt la barre de total.
--      La goutte officielle reste un logo statique (jamais de goutte ni de vague).
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
local GAIN_GREEN = { 0.25, 1.00, 0.25 }     -- repli si ColorForGain absent
local WHITE8 = "Interface\\Buttons\\WHITE8X8"

function C.GainColor(opts, data)
  local S = ns.Slot
  opts, data = opts or {}, data or {}
  if S and S.ColorForGain then
    return S.ColorForGain(
      opts.kind or data.kind,
      opts.skillId or opts.id or data.id,
      opts.skillName or opts.name or data.skillName or data.name,
      opts.header or data.headerName or data.header)
  end
  local G = ns.GAIN_COLORS or (S and S.ADD_COLORS)
  return (G and G.green) or { 0.310, 0.498, 0.243 }
end

-- Couleur partagée (voile, +1, étincelle) : jamais jaune, lime, nil ou noir.
function C.SharedGainColor(color)
  local S = ns.Slot
  if S and S.UsableColor then
    local u = S.UsableColor(color)
    if u then return u end
  end
  if S and S.AddColor then
    local c = S.AddColor(color)
    if c then return c end
  end
  local G = ns.GAIN_COLORS or (S and S.ADD_COLORS)
  return (G and G.green) or { 0.310, 0.498, 0.243 }
end

-- Flash du +1 : même teinte de type (rouge XP, bleu armes/Défense, vert métiers),
-- éclaircie pour le pop. Jamais un vert unique pour toutes les cases.
function C.PopColor(color, tile)
  if (not color or type(color) ~= "table") and tile and tile.data and C.GainColor then
    color = C.GainColor(tile.data)
  end
  color = C.SharedGainColor and C.SharedGainColor(color) or color or { 0.310, 0.498, 0.243 }
  local k = C.POP_LIFT
  if type(k) ~= "number" then k = 0.42 end
  return {
    math.min(1, color[1] + (1 - color[1]) * k),
    math.min(1, color[2] + (1 - color[2]) * k),
    math.min(1, color[3] + (1 - color[3]) * k),
  }
end

-- +1 coloré sur la case, puis une étincelle de même couleur quitte la case,
-- rejoint la barre de total (arc court), la parcourt jusqu'au bout rempli et flash.
-- La goutte elle-même n'est pas animée.
function C.Announce(opts, targets, skipGain)
  opts = opts or {}
  local color = C.GainColor(opts)
  local origin, wantSpark
  for _, tg in ipairs(targets or {}) do
    if tg.key == "total" then
      wantSpark = true
    else
      local tile = C.TileByKey and C.TileByKey(tg.key)
      if tile then
        -- Un seul pop + un seul « +1 » (la pré-sélection reste un liseré, sans +1).
        local now = (type(GetTime) == "function" and GetTime()) or 0
        if not (tile._gainPopAt and now > 0 and (now - tile._gainPopAt) < 0.25) then
          tile._gainPopAt = now
          if C.Pulse then C.Pulse(tile, color) end
          if not skipGain and tg.gain and tg.gain > 0 and C.Gain then
            C.Gain(tile, "+" .. tostring(math.floor(tg.gain + 0.5)), color)
          end
        end
        if not origin then origin = tile end
      end
    end
  end
  local kind = opts.kind
  if kind == "xp" or kind == "skill" or kind == "levelup" or wantSpark then
    -- XP : la case Niveau est l'origine ; armes / métiers : la case de compétence.
    if ns.Slot and ns.Slot.PlayBarSpark then
      pcall(ns.Slot.PlayBarSpark, color, origin)
    end
  end
  return color
end

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
  local sk = d.skillName and ns.LocSkillName and ns.LocSkillName(d.skillName) or d.skillName
  local nm = d.name and ns.LocSkillName and ns.LocSkillName(d.name) or d.name
  if d.combatTile and sk and sk ~= nm then
    return Tr["Compte dans le total : +"] .. tostring(d.current or 0) .. "  (" .. sk .. ")"
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
-- 3.8.1 : infobulle du total en résumé ; complète avec Maj maintenu, ou en permanence si l'option est cochée
function C.TotalTipFull()
  if ns.OptOff and ns.OptOff("tipTotalFull") then return true end
  return (_G.IsShiftKeyDown and _G.IsShiftKeyDown()) and true or false
end
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
    local full = C.TotalTipFull()
    m.full = full
    if not full then
      -- 3.8.1 : résumé par défaut ; Maj (ou l'option) déplie tout
      local gain0 = ns.DailyGains and ns.DailyGains(snap)
      if gain0 and gain0 > 0 then add(Tr["Aujourd'hui : +"] .. tostring(gain0), GAIN_GREEN[1], GAIN_GREEN[2], GAIN_GREEN[3]) end
      if ns.Flight and ns.Flight.ShowPauseTip and ns.Flight.ShowPauseTip() then add(Tr["En pause pendant le vol"], 1, 0.82, 0) end
      return m
    end
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
      add(Tr["Le scan reprend dès l'atterrissage."], 1, 1, 1)
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
  local full = (d.kind == "total") and C.TotalTipFull() or false
  if e and e.snap == UI.snapshot and e.full == full and (now - e.t) < C.TIP_TTL then return e.m end
  local m = C.TooltipModel(d)
  C._tipMemo[d] = { snap = UI.snapshot, t = now, m = m, full = full }
  return m
end
function C.FillTooltip(tt, d, tile)
  local m = C.ModelFor(d)
  tt:SetText(m.title, GOLD[1], GOLD[2], GOLD[3])
  for _, l in ipairs(m.lines) do tt:AddLine(l[1], l[2], l[3], l[4], l[5]) end
  if d and d.kind == "total" and m.full and ns.QoL and ns.QoL.AltTooltip then pcall(ns.QoL.AltTooltip, tt) end
  -- 3.6.0 : clic sur le total = fenêtre Progression
  if d and d.kind == "total" and ns.ProgressUI then
    tt:AddLine(" ", 1, 1, 1)
    tt:AddLine(Tr["Clic : fenêtre Progression"], 0.6, 0.8, 1)
    if ns.Opt and ns.Opt("partage") then tt:AddLine(Tr["Maj + clic : partager"], 0.6, 0.6, 0.6) end
    if not m.full then tt:AddLine(Tr["Maj : tout afficher"], 0.6, 0.6, 0.6) end
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
    if d.kind == "total" then C._totalTile = self else C._totalTile = nil end
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
C.GAIN_TIME = 1.5     -- chute + fondu
C.GAIN_RISE = 14      -- (ancien, conservé)
C.GAIN_START_K = 0.40 -- départ : juste au-dessus de CETTE case (~0,4 × hauteur)
C.PULSE_IN, C.PULSE_OUT = 0.08, 0.32   -- voile : pic puis fondu, 0,4 s au total
C.PULSE_PEAK = 0.5
C.POP_LIFT = 0.42  -- mélange vers le blanc : version plus claire de GAIN_COLORS
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
function C.ShouldHold(d)
  if not d or d.placeholder then return false end
  if d.combatTile then return false end
  if ns.IsWeaponSkill and ns.IsWeaponSkill(d.id or d.skillID, d.kind, d.skillName or d.name) then
    return false
  end
  return true
end

function I.HeldValue(d)
  if not C.ShouldHold(d) then return nil end
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
  if not opts then return nil end
  if opts.kind == "xp" or opts.kind == "levelup" then
    return C.TileByKey and C.TileByKey("level")
  end
  local wantName = opts.skillName or opts.name
  local wantId = opts.skillId or opts.skillID or opts.id
  for _, t in ipairs(C.Tiles()) do
    local d = t.data
    if d and d.kind ~= "total" and not d.placeholder then
      if d.kind == "level" and (opts.kind == "xp" or opts.kind == "levelup") then return t end
      local id = d.id or d.skillId or d.skillID
      if wantId and id and tostring(id) == tostring(wantId) then return t end
      if wantName and (d.skillName == wantName or d.name == wantName) then return t end
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
      local hold = C.ShouldHold(t.data)
      out[#out + 1] = { key = C.HoldKey(t.data), gain = d, hold = hold }
      if t.data.inTotal or t.data.combatTile then out[#out + 1] = { key = "total", gain = d, hold = hold } end
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
  -- 3.7.3 : mode calme (donjon / raid) : ni « +1 », ni voile, ni étincelle.
  local Q = ns.Progress
  if Q and Q.QuietBlocks and Q.QuietBlocks(opts) then return nil end
  local e = drop._osrsFly
  local targets = C.TargetsFor(opts, drop)
  if #targets == 0 then return nil end
  if P.Wake then P.Wake("gain") end   -- 3.3.6 : opacité pleine à chaque gain
  if not ns.Opt("flyAnim") then
    -- pas de vol d'éclat, mais le +1 coloré et l'étincelle restent
    if C.Announce then C.Announce(opts, targets) end
    return nil
  end
  if not e then
    e = { drop = drop, icon = iconPath, kind = opts.kind, targets = targets, born = Now(), opts = opts }
    drop._osrsFly = e
    if drop.HookScript and not drop._osrsFlyHooked then
      drop._osrsFlyHooked = true
      drop:HookScript("OnHide", function(self)
        local en = self._osrsFly
        if not en or en.launched then return end
        -- Avant que le toast disparaisse : mémoriser le centre de SON icône.
        if C.SnapToast then C.SnapToast(en) end
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
  if C.SnapToast then C.SnapToast(e) end
  return e
end

local baseSpawn = UI.SpawnDrop
function UI:SpawnDrop(iconPath, title, subtitle, barCur, barMax, rightValue, opts)
  local f = baseSpawn(self, iconPath, title, subtitle, barCur, barMax, rightValue, opts)
  if f and type(opts) == "table" and C.KINDS[opts.kind] and not f._editPreview and not opts.test then
    SafeStep("toast → case", C.Register, f, iconPath, opts)
  end
  return f
end

-- Centre actuel d'un objet, en coordonnées UIParent (échelle effective).
-- Jamais de taille ou de position mémorisée : on relit GetLeft/GetRight.
local function AbsCenter(o)
  if not o then return nil end
  local l, r, t, b = RectOf(o)
  if not l then return nil end
  local s = 1
  local parent = _G.UIParent
  if o.GetEffectiveScale and parent and parent.GetEffectiveScale then
    local ok1, es = pcall(o.GetEffectiveScale, o)
    local ok2, us = pcall(parent.GetEffectiveScale, parent)
    if ok1 and ok2 and N(es) and N(us) and us > 0 then s = es / us end
  end
  return (l + r) / 2 * s, (t + b) / 2 * s
end
local function HostCenter(o, host)
  local ux, uy = AbsCenter(o)
  if not ux then return nil end
  if not host or host == _G.UIParent then return ux, uy end
  local hl, _, _, hb = RectOf(host)
  if not hl then return ux, uy end
  local s = 1
  local parent = _G.UIParent
  if host.GetEffectiveScale and parent and parent.GetEffectiveScale then
    local ok1, es = pcall(host.GetEffectiveScale, host)
    local ok2, us = pcall(parent.GetEffectiveScale, parent)
    if ok1 and ok2 and N(es) and N(us) and us > 0 then s = es / us end
  end
  return (ux - hl * s) / s, (uy - hb * s) / s
end
local function Center(o) return AbsCenter(o) end

-- Icône à l'intérieur du toast (slot ou texture).
function C.ToastIcon(drop)
  if not drop then return nil end
  return drop.icon or drop.iconTex or (drop.iconSlot and (drop.iconSlot.iconTex or drop.iconSlot.icon)) or drop.iconSlot or drop.Icon or drop.IconTexture
end

-- Centre en espace UIParent : GetCenter × échelle effective.
function C.ScreenCenter(o)
  if not o then return nil end
  local cx, cy
  if o.GetCenter then
    local ok, x, y = pcall(o.GetCenter, o)
    if ok and N(x) and N(y) then cx, cy = x, y end
  end
  if not (cx and cy) then
    return AbsCenter(o)
  end
  local es, us = 1, 1
  if o.GetEffectiveScale then
    local ok, s = pcall(o.GetEffectiveScale, o)
    if ok and N(s) and s > 0 then es = s end
  end
  local parent = _G.UIParent
  if parent and parent.GetEffectiveScale then
    local ok, s = pcall(parent.GetEffectiveScale, parent)
    if ok and N(s) and s > 0 then us = s end
  end
  if not us or us <= 0 then us = 1 end
  return cx * es / us, cy * es / us
end

-- Juste au-dessus de la case (repli si le toast / son icône est absent).
function C.AboveTile(tile)
  if not tile then return nil end
  local ex, ey = C.ScreenCenter(tile.icon or tile)
  if not ex then return nil end
  local h = C.TileHeight and C.TileHeight(tile) or (tile.GetHeight and N(tile:GetHeight())) or 40
  if not h or h < 1 then h = 40 end
  local o = tile.icon or tile
  if o.GetEffectiveScale and _G.UIParent and _G.UIParent.GetEffectiveScale then
    local es = N(o:GetEffectiveScale()) or 1
    local us = N(_G.UIParent:GetEffectiveScale()) or 1
    if us > 0 then h = h * es / us end
  end
  return ex, ey + h / 2 + (C.GAIN_START_K or 0.4) * h
end

function C.SnapToast(e)
  if not e then return end
  local icon = C.ToastIcon and C.ToastIcon(e.drop)
  local x, y
  if icon and C.ScreenCenter then x, y = C.ScreenCenter(icon) end
  if x and y then e._iconX, e._iconY = x, y end
end

-- Vol du +1 : cadre d'incrustation sur UIParent, SANS découpe (le toast est hors du panneau).
function C.FlyHost()
  local parent = _G.UIParent
  local h = C.overlay
  if not h then
    h = CreateFrame("Frame", "DropamineFlyOverlay", parent)
    h._osrsOwn, h._osrsOverlay = true, true
    if h.EnableMouse then pcall(h.EnableMouse, h, false) end
    if h.SetFrameStrata then pcall(h.SetFrameStrata, h, "TOOLTIP") end
    C.overlay = h
  elseif h.SetParent and h.GetParent and parent and h:GetParent() ~= parent then
    pcall(h.SetParent, h, parent)
  end
  if h.ClearAllPoints then h:ClearAllPoints() end
  if h.SetAllPoints then h:SetAllPoints(parent) end
  local pw = (parent and parent.GetWidth and N(parent:GetWidth())) or 0
  local ph = (parent and parent.GetHeight and N(parent:GetHeight())) or 0
  if h.SetSize and pw > 0 and ph > 0 then h:SetSize(pw, ph) end
  if h.Show then h:Show() end
  return h
end

function C.FlyerSize(tile)
  local sz
  if tile and tile.icon and tile.icon.GetWidth then
    sz = N(tile.icon:GetWidth())
  end
  if not sz or sz < 4 then
    sz = (I and I.ICON) or (ns.Icons and ns.Icons.ICON) or C.FLY_SIZE or 22
  end
  return math.max(10, math.floor(sz + 0.5))
end

function C.FinishFly(f, e)
  if f then
    if f.SetScript then pcall(f.SetScript, f, "OnUpdate", nil) end
    if f.ag and f.ag.Stop then pcall(f.ag.Stop, f.ag) end
    if C.StripFlyerArt then C.StripFlyerArt(f) end
    if f.Hide then f:Hide() end
    f._busy, f._entry, f._t = nil, nil, nil
  end
  if e and not e.landed then C.Land(e) end
end

function C.FlyStep(f, elapsed)
  if not (f and f._busy and f._entry) then return end
  local e = f._entry
  local host = (f.GetParent and f:GetParent()) or (C.FlyHost and C.FlyHost()) or _G.UIParent
  local tile = (e._flyKey and C.TileByKey and C.TileByKey(e._flyKey)) or e._flyTile
  local sx, sy = e._sx, e._sy
  -- Départ vivant = icône du toast tant qu'il est visible ; sinon le cliché.
  if e.drop and e.drop.IsShown and e.drop:IsShown() then
    local icon = C.ToastIcon and C.ToastIcon(e.drop)
    local x, y
    if C.ScreenCenter then x, y = C.ScreenCenter(icon or e.drop) end
    if x then sx, sy, e._sx, e._sy, e._iconX, e._iconY = x, y, x, y, x, y end
  elseif e._iconX then
    sx, sy = e._iconX, e._iconY
  end
  local ex, ey
  if tile and C.ScreenCenter then ex, ey = C.ScreenCenter(tile.icon or tile) end
  if not (ex and ey) and tile then
    ex, ey = HostCenter(tile.icon or tile, host)
  end
  if not (sx and sy) and tile and C.AboveTile then
    sx, sy = C.AboveTile(tile)
  end
  if not (sx and ex and ey) then C.FinishFly(f, e) return end
  local sz = C.FlyerSize(tile)
  if f.SetSize then f:SetSize(sz, sz) end
  f._t = (f._t or 0) + (elapsed or 0)
  local dur = C.FLY or 0.55
  local k = (dur > 0) and (f._t / dur) or 1
  if k > 1 then k = 1 end
  local u = k * k
  local x = sx + (ex - sx) * u
  local y = sy + (ey - sy) * u
  -- Pas de clamp dans le panneau : le toast est hors cadre, le +1 doit pouvoir en partir.
  if f.ClearAllPoints then f:ClearAllPoints() end
  if f.SetPoint then f:SetPoint("CENTER", host, "BOTTOMLEFT", x, y) end
  f._x, f._y = x, y
  if f.SetAlpha then
    if k < 0.6 then f:SetAlpha(1) else f:SetAlpha(1 - (k - 0.6) / 0.4 * 0.8) end
  end
  if k >= 1 then C.FinishFly(f, e) end
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
-- Range icône / lueur héritées : le voyageur n'est plus qu'un « +1 » coloré.
function C.StripFlyerArt(f)
  if not f then return end
  for _, k in ipairs({ "icon", "glow" }) do
    local r = f[k]
    if r then
      if r.Hide then r:Hide() end
      if r.SetAlpha then pcall(r.SetAlpha, r, 0) end
      if r.SetTexture then pcall(r.SetTexture, r, "") end
    end
  end
  if f.ag and f.ag.Stop then pcall(f.ag.Stop, f.ag) end
end

function C.Flyer()
  C.pool = C.pool or {}
  for _, f in ipairs(C.pool) do
    if not f._busy and f._osrsFlyer then
      if C.StripFlyerArt then C.StripFlyerArt(f) end
      return f
    end
  end
  local f = CreateFrame("Frame", nil, UIParent)
  f._osrsOwn, f._osrsFlyer = true, true
  if f.EnableMouse then f:EnableMouse(false) end
  pcall(f.SetFrameStrata, f, "TOOLTIP")
  f:SetSize(C.FLY_SIZE, C.FLY_SIZE)
  -- Pas de texture d'icône ni de lueur : seulement le « +1 » coloré.
  local okFs, fs = pcall(f.CreateFontString, f, nil, "OVERLAY", "NumberFontNormal")
  if not (okFs and fs) and f.CreateFontString then fs = f:CreateFontString(nil, "OVERLAY") end
  if fs then
    pcall(fs.SetFont, fs, I.COUNT_PATH or "Fonts\\ARIALN.TTF", 16, I.TEXT_FLAGS or "OUTLINE")
    if I.CleanText then I.CleanText(fs) end
    fs:SetPoint("CENTER", f, "CENTER", 0, 0)
    if fs.SetWordWrap then pcall(fs.SetWordWrap, fs, false) end
    f.fs = fs
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
  -- Ajout au total : le point tombe dans la goutte officielle (vague + bulles),
  -- plus d'éclat qui vole vers la case total. Le level-up a son propre débordement.
  local main, mainTg
  for _, tg in ipairs(e.targets or {}) do
    if tg.key == "total" then
      -- la goutte reste statique ; étincelle + +1 à l'arrivée (C.Land)
    elseif not main then
      main, mainTg = C.TileByKey(tg.key), tg
    end
  end
  if not main then
    -- seulement le total : pas de vol, on libère à l'arrivée de la goutte.
    if not After(0.45, function() C.Land(e) end) then C.Land(e) end
    return
  end
  if not (W.IsShown() and main) then C.Release(e) e.skipped = true return end
  -- Départ = centre de l'icône du toast (GetCenter × échelle), en espace UIParent.
  -- Jamais découpé dans le panneau (le toast est à l'extérieur).
  if C.SnapToast then C.SnapToast(e) end
  local host = (C.FlyHost and C.FlyHost()) or _G.UIParent
  local icon = C.ToastIcon and C.ToastIcon(e.drop)
  local sx, sy
  if icon and C.ScreenCenter then sx, sy = C.ScreenCenter(icon) end
  if not (sx and sy) then sx, sy = e._iconX, e._iconY end
  local ex, ey
  if C.ScreenCenter then ex, ey = C.ScreenCenter(main.icon or main) end
  if not (ex and ey) then ex, ey = HostCenter(main.icon or main, host) end
  if not (sx and sy) and C.AboveTile then sx, sy = C.AboveTile(main) end
  if not (ex and ey) then C.Land(e) return end
  if not (sx and sy) then sx, sy = ex, ey end
  local f = C.Flyer()
  if f.SetParent then pcall(f.SetParent, f, host) end
  if f.SetFrameStrata then pcall(f.SetFrameStrata, f, "TOOLTIP") end
  local sz = C.FlyerSize(main)
  if f.SetSize then f:SetSize(sz, sz) end
  f._busy, f._entry, f._t = true, e, 0
  local gain = (mainTg and mainTg.gain and mainTg.gain > 0) and math.floor(mainTg.gain + 0.5) or 1
  if C.StripFlyerArt then C.StripFlyerArt(f) end
  if f.fs and f.fs.SetText then
    f.fs:SetText("+" .. tostring(gain))
    local col = (C.GainColor and C.GainColor(e.opts or { kind = e.kind })) or (C.SharedGainColor and C.SharedGainColor())
    if col and f.fs.SetTextColor then pcall(f.fs.SetTextColor, f.fs, col[1], col[2], col[3]) end
    if f.fs.Show then f.fs:Show() end
  end
  f:ClearAllPoints()
  f:SetPoint("CENTER", host, "BOTTOMLEFT", sx, sy)
  f:SetAlpha(1)
  f:Show()
  e.from, e.to = { sx, sy }, { ex, ey }
  e._sx, e._sy = sx, sy
  e._flyTile, e._flyKey = main, (main.data and C.HoldKey and C.HoldKey(main.data)) or nil
  C.flights = C.flights + 1
  if f.ag and f.ag.Stop then pcall(f.ag.Stop, f.ag) end
  if f.SetScript then f:SetScript("OnUpdate", C.FlyStep) end
  -- Même durée qu'avant (C.FLY) : le +1 / voile reste à l'arrivée, après le toast.
  After(C.FLY + 0.5, function() if not e.landed then C.FinishFly(f, e) end end)
  -- Premier pas immédiat (le harnais de tests n'a pas de boucle OnUpdate).
  if C.FlyStep then C.FlyStep(f, 0) end
end

-- Vol d'aperçu (Options Tester) : part de l'icône du toast de test, sans retenue ni 2e Announce.
function C.PreviewFly(drop, opts, targets)
  if not (drop and opts) then return nil end
  targets = targets or (C.TargetsFor and C.TargetsFor(opts, drop))
  if not (targets and targets[1]) then return nil end
  local e = {
    drop = drop, icon = opts.icon, kind = opts.kind, targets = targets,
    born = Now(), opts = opts, preview = true,
  }
  if C.SnapToast then C.SnapToast(e) end
  C.Launch(e)
  return e
end

-- Arrivée : vraie valeur, pulsation dorée, gain vert.
function C.Land(e, quiet)
  if e.landed then return end
  e.landed = true
  if not e.preview then C.Release(e) end
  if quiet or not W.IsShown() then return end
  C.landed = C.landed + 1
  if P.Wake then P.Wake("éclat") end
  -- Le « +1 » coloré a déjà voyagé depuis l'icône du toast ; à l'arrivée, seulement le voile.
  if C.Announce then
    C.Announce(e.opts or { kind = e.kind }, e.targets, true)
  else
    for _, tg in ipairs(e.targets) do
      if tg.key ~= "total" then
        local tile = C.TileByKey(tg.key)
        if tile then
          local now = (type(GetTime) == "function" and GetTime()) or 0
          if not (tile._gainPopAt and now > 0 and (now - tile._gainPopAt) < 0.25) then
            tile._gainPopAt = now
            C.Pulse(tile)
          end
        end
      end
    end
  end
end

function C.Pulse(t, color)
  if not t then return end
  local peak = C.PULSE_PEAK
  if type(peak) ~= "number" then peak = 0.5 end
  local tin, tout = C.PULSE_IN or 0.08, C.PULSE_OUT or 0.32
  local p = t._osrsPulse
  C._pulseByKey = C._pulseByKey or {}
  local pkey = (t.data and C.HoldKey and C.HoldKey(t.data)) or tostring(t)
  p = p or C._pulseByKey[pkey]
  if not p then
    p = CreateFrame("Frame", nil, t)
    p._osrsOwn = true
    if p.EnableMouse then p:EnableMouse(false) end
    p.tex = p:CreateTexture(nil, "OVERLAY", nil, 7)
    if p.tex then
      p.tex:SetAllPoints(p)
      local okTex = p.tex.SetColorTexture and pcall(p.tex.SetColorTexture, p.tex, 1, 1, 1, 1)
      if not okTex and p.tex.SetTexture then pcall(p.tex.SetTexture, p.tex, WHITE8) end
      if p.tex.SetBlendMode then pcall(p.tex.SetBlendMode, p.tex, "ADD") end
    end
    t._osrsPulse = p
  end
  t._osrsPulse = p
  if pkey then C._pulseByKey[pkey] = p end
  -- case poolée : rattacher le voile, au-dessus de l'icône, sans masque ni alpha 0.
  if p.SetParent then pcall(p.SetParent, p, t) end
  if p.ClearAllPoints then pcall(p.ClearAllPoints, p) end
  if p.SetAllPoints then p:SetAllPoints(t.icon or t) end
  local tex = p.tex
  if tex then
    if tex.ClearAllPoints then pcall(tex.ClearAllPoints, tex) end
    if tex.SetAllPoints then tex:SetAllPoints(p) end
    local okTex = tex.SetColorTexture and pcall(tex.SetColorTexture, tex, 1, 1, 1, 1)
    if not okTex and tex.SetTexture then pcall(tex.SetTexture, tex, WHITE8) end
    if tex.SetBlendMode then pcall(tex.SetBlendMode, tex, "ADD") end
    if tex.SetDrawLayer then pcall(tex.SetDrawLayer, tex, "OVERLAY", 7) end
    if tex.RemoveMaskTexture and tex._thMask then pcall(tex.RemoveMaskTexture, tex, tex._thMask) end
    if tex.SetAlpha then pcall(tex.SetAlpha, tex, 1) end
    if tex.Show then tex:Show() end
  end
  local base = t.GetFrameLevel and t:GetFrameLevel() or 1
  pcall(p.SetFrameLevel, p, base + 8)
  color = C.PopColor(color, t)
  if tex and tex.SetVertexColor then
    pcall(tex.SetVertexColor, tex, color[1], color[2], color[3], 1)
  end
  p._color = color
  p._peak = peak
  p._pulseT, p._pulseOn = 0, true
  -- Pic visible tout de suite (pas un AnimationGroup qui part d'alpha 0, ni un Hide restant).
  if p.SetAlpha then p:SetAlpha(peak) end
  if p.ag and p.ag.Stop then pcall(p.ag.Stop, p.ag) end
  if p.SetScript then
    p:SetScript("OnUpdate", function(self, elapsed)
      if not self._pulseOn then return end
      local e = (self._pulseT or 0) + (elapsed or 0)
      self._pulseT = e
      local a
      if e < tin then
        a = peak * (tin > 0 and (e / tin) or 1)
        if a < peak * 0.35 then a = peak end  -- première image jamais invisible
      elseif e < tin + tout then
        a = peak * (1 - (e - tin) / (tout > 0 and tout or 1))
      else
        self._pulseOn = nil
        if self.SetAlpha then self:SetAlpha(0) end
        if self.Hide then self:Hide() end
        return
      end
      if self.SetAlpha then self:SetAlpha(a) end
    end)
  end
  p:Show()
  p._plays = (p._plays or 0) + 1
  After(tin + tout + 0.05, function()
    if not p._pulseOn then return end
    if (p._pulseT or 0) >= (tin + tout - 0.02) then
      p._pulseOn = nil
      if p.SetAlpha then p:SetAlpha(0) end
      if p.Hide then p:Hide() end
    end
  end)
  return p
end


-- +1 coloré : part juste au-dessus de SA case (~0,4 × hauteur) et retombe
-- sur elle en ~1,5 s, puis s'efface. Chaque case a son propre départ.
function C.TileHeight(t)
  local h = t and t.GetHeight and t:GetHeight()
  h = N(h)
  if not h or h < 1 then h = (I and I.TILE) or 40 end
  return h
end
function C.GainEnds(t)
  local h = C.TileHeight(t)
  local y0 = (C.GAIN_START_K or 0.4) * h
  local y1 = -(h * 0.5) + 4
  return y0, y1, h
end
function C.GainStep(g, elapsed)
  if not (g and g._gainOn and g._gainTile) then return end
  local tile = g._gainTile
  local y0, y1 = C.GainEnds(tile)
  g._t = (g._t or 0) + (elapsed or 0)
  local dur = C.GAIN_TIME or 1.5
  local k = (dur > 0) and (g._t / dur) or 1
  if k > 1 then k = 1 end
  local u = k * k
  local y = y0 + (y1 - y0) * u
  if g.ClearAllPoints then g:ClearAllPoints() end
  if g.SetPoint then g:SetPoint("CENTER", tile, "TOP", 0, y) end
  g._y, g._k = y, k
  if g.SetAlpha then
    if k < 0.4 then g:SetAlpha(1) else g:SetAlpha(math.max(0, 1 - (k - 0.4) / 0.6)) end
  end
  if k >= 1 then
    g._gainOn = nil
    if g.SetScript then pcall(g.SetScript, g, "OnUpdate", nil) end
    if g.Hide then g:Hide() end
  end
end
function C.Gain(t, text, color)
  color = C.SharedGainColor and C.SharedGainColor(color) or color
  local g = t._osrsGain
  C._gainByKey = C._gainByKey or {}
  local gkey = (t.data and C.HoldKey and C.HoldKey(t.data)) or tostring(t)
  g = g or C._gainByKey[gkey]
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
    local gc = color or (C.SharedGainColor and C.SharedGainColor()) or { 0.310, 0.498, 0.243 }
    fs:SetTextColor(gc[1], gc[2], gc[3])
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
  t._osrsGain = g
  if gkey then C._gainByKey[gkey] = g end
  -- Parenté au bloc de cases (pas à la case) pour ne pas être rogné, mais
  -- toujours ancré à CETTE case : le +1 d'une rangée 2 ne part pas du haut du bloc.
  local host = (t.GetParent and t:GetParent()) or t
  if g.SetParent then pcall(g.SetParent, g, host) end
  if g.ag and g.ag.Stop then pcall(g.ag.Stop, g.ag) end
  local base = t.GetFrameLevel and t:GetFrameLevel() or 1
  pcall(g.SetFrameLevel, g, base + 8)
  g.fs:SetText(text)
  if color and g.fs and g.fs.SetTextColor then
    g.fs:SetTextColor(color[1], color[2], color[3])
    g.fs._color = color
  end
  g._color = color
  g._gainTile, g._gainOn, g._t = t, true, 0
  g:SetAlpha(1)
  g:Show()
  g._plays = (g._plays or 0) + 1
  if g.SetScript then g:SetScript("OnUpdate", C.GainStep) end
  C.GainStep(g, 0)
  After((C.GAIN_TIME or 1.5) + 0.05, function()
    if not g._gainOn then return end
    g._gainOn = nil
    if g.SetScript then pcall(g.SetScript, g, "OnUpdate", nil) end
    if g.Hide then g:Hide() end
  end)
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

-- 3.8.1 : appuyer / relâcher Maj pendant le survol du total redessine l'infobulle (résumé <-> complète)
do
  local f = _G.CreateFrame and _G.CreateFrame("Frame")
  if f and f.RegisterEvent then
    f:RegisterEvent("MODIFIER_STATE_CHANGED")
    f:SetScript("OnEvent", function()
      local tile, tt = C._totalTile, _G.GameTooltip
      if not (tile and tile._hover and tile.data and tt and tt.IsShown and tt:IsShown()) then return end
      local ok = pcall(function()
        tt:SetOwner(tile, "ANCHOR_RIGHT")
        C.FillTooltip(tt, tile.data, tile)
        tt:Show()
        if ns.ProgressUI and ns.ProgressUI.ShowMini then ns.ProgressUI.ShowMini(tt, tile) end
      end)
      return ok
    end)
  end
end
-- 3.8.1 : réglage « toujours complète » (défaut : résumé, Maj pour tout voir)
if ns.Options and ns.Options.EXTRA then
  ns.Options.EXTRA[#ns.Options.EXTRA + 1] = { type = "check", key = "tipTotalFull", label = "Infobulle du total complète", default = false,
    cmd = "Maj : déplier l'infobulle du total", help = "Décoché : résumé, et Maj maintenu affiche tout. Coché : toujours complète." }
  ns.Options.EXTRA_HOME = ns.Options.EXTRA_HOME or {}
  ns.Options.EXTRA_HOME.tipTotalFull = "prof"
  if ns.Options.All then ns.Options.ITEMS = ns.Options.All() end
end
