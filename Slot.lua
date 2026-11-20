-- Dropamine 3.6.3 : le puits de la fiole dit ce que tu fais maintenant.
-- Un seul gestionnaire possède la texture de la goutte. Un symbole à la fois,
-- selon la priorité mort > vol > (épée de combat, si ce style est choisi) >
-- AFK > pêche > nage > z de repos > goutte. Le liquide de combat (rouge + bleu,
-- vert qui s'efface) est une couche derrière le symbole. Style réglable :
-- Bulles (défaut, maquette A), Épée (maquette C) ou Désactivé.
-- Feuilles 8×4 de 64 px, OnUpdate cadencé, pas d'AnimationGroups.
local ADDON, ns = ...
local Tr = ns.L
local S = {}
ns.Slot = S

S.ORDER_SWORD   = { "death", "flight", "combat", "afk", "fishing", "swimming", "rested" }
S.ORDER_DEFAULT = { "death", "flight", "afk", "fishing", "swimming", "rested" }

local MEDIA = "Interface\\AddOns\\Dropamine\\Media\\"
S.SHEETS = {
  death     = { tex = MEDIA .. "Death-Sheet",    frames = 32, step = 0.10 },
  combat    = { tex = MEDIA .. "Combat-C-Sheet", frames = 32, step = 0.10 },
  afk       = { tex = MEDIA .. "Afk-Sheet",      frames = 32, step = 0.10 },
  fishing   = { tex = MEDIA .. "Fishing-Sheet",  frames = 32, step = 0.10 },
  swimming  = { tex = MEDIA .. "Swimming-Sheet", frames = 32, step = 0.10 },
}
S.TRAINER_SHEET = MEDIA .. "Trainer-Sheet"
S.COMBAT_A_SHEET = MEDIA .. "Combat-A-Sheet"
S.OPT_KEYS = {
  death = "slotDeath", flight = "slotFlight",
  afk = "slotAfk", fishing = "slotFishing", swimming = "slotSwimming",
  rested = "slotRested", trainer = "slotTrainer",
}

function S.CombatStyle()
  local ui = ns.db and ns.db.ui
  local v = ui and ui.combatStyle
  if type(v) == "string" then
    v = v:lower()
    if v == "sword" or v == "epee" or v == "épée" or v == "c" then return "sword" end
    if v == "off" or v == "none" or v == "desactive" or v == "désactivé" then return "off" end
    if v == "bubbles" or v == "bulles" or v == "a" then return "bubbles" end
  end
  return "bubbles"
end

function S.SetCombatStyle(v)
  local n = S.CombatStyle()
  if type(v) == "string" then
    local k = v:lower()
    if k == "sword" or k == "epee" or k == "épée" or k == "c" then n = "sword"
    elseif k == "off" or k == "none" or k == "desactive" or k == "désactivé" then n = "off"
    elseif k == "bubbles" or k == "bulles" or k == "a" then n = "bubbles"
    end
  elseif v == false then
    n = "off"
  end
  if ns.SetOpt then ns.SetOpt("combatStyle", n) end
  return n
end

function S.CombatLiquidOn()
  return S.CombatStyle() ~= "off"
end

function S.Priority()
  if S.CombatStyle() == "sword" then return S.ORDER_SWORD end
  return S.ORDER_DEFAULT
end

S._sim = {}
S.fill = { p = 0, grey = 0, drain = 1, targetP = 0, targetGrey = 0, targetDrain = 1 }
S._phase = 0
S._jolt = 0
S._fishUntil = 0
S._frame = { death = 1, combat = 1, afk = 1, fishing = 1, swimming = 1, trainer = 1 }
S._acc = { death = 0, combat = 0, afk = 0, fishing = 0, swimming = 0, trainer = 0 }
S._zBits = {}

local function N(v)
  v = tonumber(v)
  return v
end

local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c, d, e, f = pcall(fn, ...)
  if not ok then return nil end
  return a, b, c, d, e, f
end

local function Now()
  if type(GetTime) == "function" then
    local ok, t = pcall(GetTime)
    if ok and N(t) then return N(t) end
  end
  return 0
end

local function Approach(cur, target, rate, dt)
  cur, target = N(cur) or 0, N(target) or 0
  if cur < target then
    cur = cur + rate * dt
    if cur > target then cur = target end
  elseif cur > target then
    cur = cur - rate * dt
    if cur < target then cur = target end
  end
  return cur
end

function S.Opt(key)
  if ns.Opt then return ns.Opt(key) ~= false end
  return true
end

function S.SetSim(id, on)
  if on then S._sim[id] = true else S._sim[id] = nil end
end

function S.ClearSim()
  S._sim = {}
  S._jolt = 0
  S._fishUntil = 0
end

function S.IsSim(id)
  return S._sim[id] and true or false
end

------------------------------------------------------------------------------
-- Détection
------------------------------------------------------------------------------
function S.LiveDeath()
  if S._sim.death then return true end
  if type(UnitIsDeadOrGhost) == "function" then
    local v = Call(UnitIsDeadOrGhost, "player")
    if v then return true end
  end
  if Call(UnitIsDead, "player") or Call(UnitIsGhost, "player") then return true end
  return false
end

function S.LiveFlight()
  local F = ns.Flight
  return (F and F.Paused and F.Paused()) and true or false
end

function S.LiveCombat()
  if S._sim.combat then return true end
  if type(UnitAffectingCombat) == "function" then
    return Call(UnitAffectingCombat, "player") and true or false
  end
  if type(InCombatLockdown) == "function" then
    return Call(InCombatLockdown) and true or false
  end
  return false
end

function S.LiveAfk()
  if S._sim.afk then return true end
  if type(UnitIsAFK) == "function" then
    return Call(UnitIsAFK, "player") and true or false
  end
  return false
end

local function LooksLikeFishing(name, icon)
  local n = type(name) == "string" and name:lower() or ""
  if n:find("fish", 1, true) or n:find("pêche", 1, true) or n:find("peche", 1, true) then return true end
  if type(icon) == "string" and icon:lower():find("fishing", 1, true) then return true end
  return false
end

function S.LiveFishing()
  if S._sim.fishing then return true end
  if type(UnitChannelInfo) == "function" then
    local name, rank, display, icon = Call(UnitChannelInfo, "player")
    if LooksLikeFishing(name, icon) or LooksLikeFishing(display, icon) then return true end
  end
  return false
end

function S.LiveSwimming()
  if S._sim.swimming then return true end
  if type(IsSwimming) == "function" then
    return Call(IsSwimming) and true or false
  end
  return false
end

function S.LiveRested()
  if S._sim.rested then return true end
  local resting = Call(IsResting) and true or false
  if not resting then return false end
  if ns.Rested and ns.Rested.State then
    local st = ns.Rested.State()
    if st and N(st.z) and st.z > 0 then return true end
    -- pas de « z » sans XP de repos
    return false
  end
  return resting
end

function S.LiveTrainer()
  if S._sim.trainer then return true end
  local tf = _G.TrainerFrame
  if tf and type(tf.IsShown) == "function" and Call(tf.IsShown, tf) then return true end
  local names = { Call(UnitName, "npc"), Call(UnitName, "target"), Call(UnitName, "mouseover") }
  for i = 1, #names do
    local n = names[i]
    if type(n) == "string" and n ~= "" then
      local f = (ns.Fold and ns.Fold(n) or n:lower())
      if f:find("maitre", 1, true) or f:find("trainer", 1, true) then return true end
    end
  end
  return false
end

function S.Want(id)
  local key = S.OPT_KEYS[id]
  if key and not S.Opt(key) then return false end
  if id == "death" then return S.LiveDeath() end
  if id == "flight" then return S.LiveFlight() end
  if id == "combat" then return S.CombatStyle() == "sword" and S.LiveCombat() end
  if id == "afk" then return S.LiveAfk() end
  if id == "fishing" then return S.LiveFishing() end
  if id == "swimming" then return S.LiveSwimming() end
  if id == "rested" then return S.LiveRested() end
  if id == "trainer" then return S.LiveTrainer() end
  return false
end

function S.Active()
  local order = S.Priority and S.Priority() or S.ORDER_DEFAULT
  for i = 1, #order do
    local id = order[i]
    if S.Want(id) then return id end
  end
  return "drop"
end

function S.DeathPause()
  return S.Opt("slotDeath") and S.LiveDeath()
end

function S.TakesRestedZ()
  if S.Active() ~= "rested" then return false end
  local Wd = ns.Wide
  local t = Wd and Wd.TotalTile and Wd.TotalTile()
  -- le puits de la goutte est celui de la barre Niveau total (disposition large)
  return t and t.data and t.data.kind == "total" and t._wideOn and true or false
end

------------------------------------------------------------------------------
-- Remplissage de la fiole (barre 3 couleurs)
-- p = 0 état normal (3 couleurs), 1 = combat (rouge+bleu remplissent, vert éteint)
-- grey 0..1, drain 1 = plein / 0 = vide (mort)
------------------------------------------------------------------------------
S.FILL_RATE = 1 / 0.6
S.GREY = { 0.42, 0.42, 0.40 }

function S.SyncFillTargets()
  local f = S.fill
  if S.Opt("slotDeath") and S.LiveDeath() then
    f.targetP, f.targetGrey, f.targetDrain = 0, 1, 0
  elseif S.CombatLiquidOn() and S.LiveCombat() then
    f.targetP, f.targetGrey, f.targetDrain = 1, 0, 1
  else
    f.targetP, f.targetGrey, f.targetDrain = 0, 0, 1
  end
end

function S.FillBusy()
  local f = S.fill
  if math.abs((f.p or 0) - (f.targetP or 0)) > 0.001 then return true end
  if math.abs((f.grey or 0) - (f.targetGrey or 0)) > 0.001 then return true end
  if math.abs((f.drain or 1) - (f.targetDrain or 1)) > 0.001 then return true end
  if (f.p or 0) > 0.02 and (f.drain or 1) > 0.02 and (f.grey or 0) < 0.5 then return true end -- ondulation
  return false
end

function S.TransformWidths(widths, track, fill)
  widths = widths or { 0, 0, 0 }
  track = math.max(0, N(track) or 0)
  fill = fill or S.fill
  local p = math.max(0, math.min(1, N(fill.p) or 0))
  local grey = math.max(0, math.min(1, N(fill.grey) or 0))
  local drain = math.max(0, math.min(1, N(fill.drain) or 1))
  local wR, wB, wG = N(widths[1]) or 0, N(widths[2]) or 0, N(widths[3]) or 0
  local rb = wR + wB
  local srcR, srcB = wR, wB
  if rb <= 0 and p > 0 and track > 0 then
    srcR, srcB, rb = 1, 1, 2
  end
  local dstR = (rb > 0) and (track * (srcR / rb)) or 0
  local dstB = (rb > 0) and (track * (srcB / rb)) or 0
  local outR = wR + (dstR - wR) * p
  local outB = wB + (dstB - wB) * p
  local outG = wG * (1 - p)
  outR, outB, outG = outR * drain, outB * drain, outG * drain
  if p > 0.15 and drain > 0.2 and grey < 0.5 and track > 0 then
    local wave = 0.035 * math.sin((S._phase or 0) * 2 * math.pi)
    local extra = wave * track
    local sum = outR + outB
    if sum > 0 then
      outR = math.max(0, outR + extra * (outR / sum))
      outB = math.max(0, outB + extra * (outB / sum))
      if outR + outB + outG > track then
        local scale = track / (outR + outB + outG)
        outR, outB, outG = outR * scale, outB * scale, outG * scale
      end
    end
  end
  return { outR, outB, outG }, p, grey, drain
end

function S.ApplyFlaskFill(t)
  local Wd = ns.Wide
  if not (Wd and Wd.EnsureSegs) then return end
  t = t or (Wd.TotalTile and Wd.TotalTile())
  if not t then return end
  local last = Wd.last
  if not last or not last.widths or not last.track then return end
  local pseg = Wd.EnsureSegs(t)
  if not (pseg and pseg.segs) then return end
  local out, p, grey, drain = S.TransformWidths(last.widths, last.track, S.fill)
  local il, ir, ib = last.il or 0, last.ir or 0, last.ib or 0
  local left, by, fh = last.left or 0, last.by or 0, last.fh or 0
  local x = left + il
  local GREY = S.GREY
  for i = 1, 3 do
    local tex, w = pseg.segs[i], out[i] or 0
    if not tex then break end
    local c = Wd.SEG_COLORS and Wd.SEG_COLORS[i] or { 1, 1, 1, 1 }
    local r = (c[1] or 1) + (GREY[1] - (c[1] or 1)) * grey
    local g = (c[2] or 1) + (GREY[2] - (c[2] or 1)) * grey
    local b = (c[3] or 1) + (GREY[3] - (c[3] or 1)) * grey
    local a = c[4] or 1
    if i == 3 then a = a * (1 - p) end
    if tex.ClearAllPoints then tex:ClearAllPoints() end
    if w > 0.5 and fh > 0 and a > 0.02 then
      tex:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", x, by + ib)
      if tex.SetSize then tex:SetSize(math.max(0.01, w), fh) end
      if tex.SetVertexColor then tex:SetVertexColor(r, g, b, a) end
      if tex.Show then tex:Show() end
      x = x + w
    else
      if tex.Hide then tex:Hide() end
    end
  end
end

------------------------------------------------------------------------------
-- Symbole dans le puits (même texture que le sablier)
------------------------------------------------------------------------------
local function TexCoord(i, frames, cols, rows)
  frames = frames or 32
  cols, rows = cols or 8, rows or 4
  i = ((i - 1) % frames) + 1
  local col = (i - 1) % cols
  local row = math.floor((i - 1) / cols)
  local u0, v0 = col / cols, row / rows
  return u0, u0 + 1 / cols, v0, v0 + 1 / rows
end
S.TexCoord = TexCoord

local function HideSymbol(t)
  if t and t._hg then
    if t._hg.ClearAllPoints and t.icon then pcall(t._hg.ClearAllPoints, t._hg) pcall(t._hg.SetAllPoints, t._hg, t.icon) end
    if t._hg.Hide then t._hg:Hide() end
  end
  if t and t.icon and (not ns.Flight or (ns.Flight._vis or 0) <= 0) then
    if t.icon.Show then t.icon:Show() end
    if t.icon.SetAlpha then t.icon:SetAlpha(1) end
  end
end

function S.ApplySheet(t, id)
  local Wd = ns.Wide
  if not (t and id and S.SHEETS[id] and Wd and Wd.EnsureHourglass) then return nil end
  local h = Wd.EnsureHourglass(t)
  if not h then return nil end
  local sh = S.SHEETS[id]
  if h.SetTexture then pcall(h.SetTexture, h, sh.tex) end
  local fi = S._frame[id] or 1
  if h.SetTexCoord then pcall(h.SetTexCoord, h, TexCoord(fi, sh.frames)) end
  if h.SetAllPoints and t.icon then pcall(h.SetAllPoints, h, t.icon) end
  if h.SetSize and t.icon and t.icon.GetWidth then
    local w = N(t.icon:GetWidth()) or 16
    local ht = N(t.icon:GetHeight()) or w
    pcall(h.SetSize, h, w, ht)
  end
  if id == "fishing" and (S._jolt or 0) > 0 and t.icon and h.ClearAllPoints and h.SetPoint then
    local j = S._jolt
    local ox = math.sin(j * 42) * 2.2 * j
    local oy = math.cos(j * 31) * 2.2 * j
    pcall(h.ClearAllPoints, h)
    pcall(h.SetPoint, h, "TOPLEFT", t.icon, "TOPLEFT", ox, oy)
    pcall(h.SetPoint, h, "BOTTOMRIGHT", t.icon, "BOTTOMRIGHT", ox, oy)
  end
  if h.SetAlpha then pcall(h.SetAlpha, h, 1) end
  if h.Show then h:Show() end
  if t.icon and t.icon.Hide then t.icon:Hide() end
  return h
end

function S.EnsureSlotZ(t)
  if t._slotZ then return t._slotZ end
  local parent = t.icon or t.slotBorder or t
  local ok, clip = pcall(CreateFrame, "ScrollFrame", nil, t)
  if not (ok and clip) then return nil end
  if clip.SetAllPoints and parent then pcall(clip.SetAllPoints, clip, parent) end
  if clip.EnableMouse then pcall(clip.EnableMouse, clip, false) end
  local okC, content = pcall(CreateFrame, "Frame", nil, clip)
  if not (okC and content) then return nil end
  if clip.SetScrollChild then pcall(clip.SetScrollChild, clip, content) end
  if content.SetAllPoints then pcall(content.SetAllPoints, content, clip) end
  local zs = {}
  for i = 1, 3 do
    local fs = content.CreateFontString and content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    if not fs and type(CreateFrame) == "function" then
      -- harnais de tests : certains CreateFontString sont sur le cadre
    end
    if fs then
      if fs.SetText then fs:SetText("z") end
      if fs.SetTextColor then fs:SetTextColor(0.925, 0.788, 0.412) end
      if fs.SetAlpha then fs:SetAlpha(0) end
      if fs.Hide then fs:Hide() end
      zs[i] = { fs = fs, y = 0, age = -i * 0.55, born = false }
    end
  end
  clip._content, clip.z = content, zs
  t._slotZ = clip
  return clip
end

function S.ApplySlotZ(t, on)
  if not t then return end
  if not on then
    if t._slotZ and t._slotZ.Hide then t._slotZ:Hide() end
    return
  end
  local clip = S.EnsureSlotZ(t)
  if not clip then return end
  local anchor = t.icon or t.slotBorder or t
  if clip.ClearAllPoints then pcall(clip.ClearAllPoints, clip) end
  if clip.SetAllPoints and anchor then pcall(clip.SetAllPoints, clip, anchor) end
  local w, h = 16, 16
  if anchor.GetWidth then w = N(anchor:GetWidth()) or w h = N(anchor:GetHeight()) or h end
  if clip.SetSize then pcall(clip.SetSize, clip, w, h) end
  if clip._content and clip._content.SetSize then pcall(clip._content.SetSize, clip._content, w, h) end
  if clip.Show then clip:Show() end
  if t.icon and t.icon.Hide then t.icon:Hide() end
  if t._hg and t._hg.Hide then t._hg:Hide() end
end

function S.TickSlotZ(dt)
  local Wd = ns.Wide
  local t = Wd and Wd.TotalTile and Wd.TotalTile()
  if not (t and t._slotZ and S.TakesRestedZ()) then return end
  local clip = t._slotZ
  local h = 16
  if clip.GetHeight then h = N(clip:GetHeight()) or h end
  local w = 16
  if clip.GetWidth then w = N(clip:GetWidth()) or w end
  for i, z in ipairs(clip.z or {}) do
    z.age = (z.age or 0) + dt
    if z.age >= 0 then
      local life = 1.55
      local u = z.age % life
      local y = (u / life) * (h - 2)
      local a = 1
      if u < 0.15 then a = u / 0.15
      elseif u > life - 0.35 then a = math.max(0, (life - u) / 0.35) end
      local fs = z.fs
      if fs then
        if fs.ClearAllPoints then pcall(fs.ClearAllPoints, fs) end
        local x = 2 + ((i - 1) % 3) * math.max(3, (w - 8) / 3)
        if fs.SetPoint then pcall(fs.SetPoint, fs, "BOTTOMLEFT", clip._content or clip, "BOTTOMLEFT", x, y) end
        if fs.SetAlpha then pcall(fs.SetAlpha, fs, a) end
        if fs.Show then fs:Show() end
      end
    end
  end
end

function S.EnsureCombatLiq(t)
  if not t then return nil end
  if t._cLiq then return t._cLiq end
  local parent = t.icon or t
  local ok, f = pcall(CreateFrame, "Frame", nil, t)
  if not (ok and f) then return nil end
  if f.EnableMouse then pcall(f.EnableMouse, f, false) end
  local function tex(layer)
    if type(f.CreateTexture) ~= "function" then return nil end
    local tx = f:CreateTexture(nil, layer or "ARTWORK")
    return tx
  end
  f.blue = tex("ARTWORK")
  f.red = tex("ARTWORK")
  f.wave = tex("ARTWORK")
  f.bubbles = tex("OVERLAY")
  if f.bubbles and f.bubbles.SetTexture then pcall(f.bubbles.SetTexture, f.bubbles, S.COMBAT_A_SHEET) end
  t._cLiq = f
  return f
end

function S.ApplyCombatLiq(t)
  local Wd = ns.Wide
  t = t or (Wd and Wd.TotalTile and Wd.TotalTile())
  if not t then return end
  local style = S.CombatStyle()
  local fill = S.fill or {}
  local p = math.max(0, math.min(1, (N(fill.p) or 0) * (N(fill.drain) or 1)))
  local grey = N(fill.grey) or 0
  local show = style ~= "off" and p > 0.01 and grey < 0.85
  local liq = t._cLiq
  if not show then
    if liq and liq.Hide then liq:Hide() end
    return
  end
  liq = S.EnsureCombatLiq(t)
  if not liq then return end
  local anchor = t.icon or t.slotBorder or t
  if liq.ClearAllPoints then pcall(liq.ClearAllPoints, liq) end
  if liq.SetAllPoints and anchor then pcall(liq.SetAllPoints, liq, anchor) end
  local w, h = 16, 16
  if anchor.GetWidth then w = N(anchor:GetWidth()) or w end
  if anchor.GetHeight then h = N(anchor:GetHeight()) or h end
  if liq.SetSize then pcall(liq.SetSize, liq, w, h) end
  -- Remplissage depuis le bas : le liquide monte avec p, surface ondulée.
  local inset = math.max(1, w * 0.18)
  local bodyH = math.max(1, (h * 0.72) * p)
  local wave = 0.04 * h * math.sin((S._phase or 0) * 2 * math.pi)
  bodyH = math.max(1, math.min(h * 0.82, bodyH + wave))
  local redH = bodyH * 0.38
  local blueH = bodyH - redH
  local function place(tex, height, y, r, g, b, a)
    if not tex or height < 0.5 then
      if tex and tex.Hide then tex:Hide() end
      return
    end
    if tex.ClearAllPoints then pcall(tex.ClearAllPoints, tex) end
    if tex.SetPoint then pcall(tex.SetPoint, tex, "BOTTOMLEFT", liq, "BOTTOMLEFT", inset, y) end
    if tex.SetSize then pcall(tex.SetSize, tex, math.max(1, w - inset * 2), height) end
    if tex.SetTexture then pcall(tex.SetTexture, tex, "Interface\\Buttons\\WHITE8X8") end
    if tex.SetVertexColor then pcall(tex.SetVertexColor, tex, r, g, b, a) end
    if tex.Show then tex:Show() end
  end
  local cr = (grey > 0) and (0.42 + (0.71 - 0.42) * (1 - grey)) or 0.71
  -- Wd.SEG_COLORS approx: red 0.616,0.278,0.227  blue 0.329,0.408,0.604
  place(liq.blue, blueH, math.max(0, h * 0.10), 0.329, 0.408, 0.604, 0.72)
  place(liq.red, redH, math.max(0, h * 0.10) + blueH, 0.616, 0.278, 0.227, 0.78)
  if liq.wave then
    local wy = math.max(0, h * 0.10) + bodyH - 1
    place(liq.wave, math.max(1, h * 0.08), wy, 0.82, 0.47, 0.37, 0.55)
  end
  -- Bulles (style A) : feuille par-dessus le liquide, seulement si assez rempli.
  if liq.bubbles then
    if style == "bubbles" and p > 0.15 and grey < 0.5 then
      if liq.bubbles.SetTexture then pcall(liq.bubbles.SetTexture, liq.bubbles, S.COMBAT_A_SHEET) end
      if liq.bubbles.SetAllPoints then pcall(liq.bubbles.SetAllPoints, liq.bubbles, liq) end
      local fi = S._frame.combatA or 1
      if liq.bubbles.SetTexCoord then pcall(liq.bubbles.SetTexCoord, liq.bubbles, S.TexCoord(fi, 32)) end
      if liq.bubbles.SetAlpha then pcall(liq.bubbles.SetAlpha, liq.bubbles, math.min(1, (p - 0.15) / 0.25)) end
      if liq.bubbles.Show then liq.bubbles:Show() end
    else
      if liq.bubbles.Hide then liq.bubbles:Hide() end
    end
  end
  if liq.SetFrameLevel and t.GetFrameLevel then
    pcall(liq.SetFrameLevel, liq, (t:GetFrameLevel() or 1) + 2)
  end
  if liq.Show then liq:Show() end
end

function S.ApplyTotal(t)
  local Wd = ns.Wide
  t = t or (Wd and Wd.TotalTile and Wd.TotalTile())
  if not (t and t.data and t.data.kind == "total") then
    -- tenter toutes les cases total
    local ui = ns.UI
    local tiles = ui and ui.embed and ui.embed.tiles
    if tiles then
      for i = 1, #tiles do
        local tt = tiles[i]
        if tt and tt.data and tt.data.kind == "total" then S.ApplyTotal(tt) end
      end
    end
    return
  end
  local act = S.Active()
  local F = ns.Flight
  if act == "flight" or (act == "drop" and F and (F._vis or 0) > 0) then
    S.ApplySlotZ(t, false)
    if Wd and Wd.ApplyHourglassTo then Wd.ApplyHourglassTo(t, F._vis or 0) end
    if Wd and Wd.SyncFlaskHit then Wd.SyncFlaskHit(t, F and F._vis or 0) end
    return
  end
  if act == "rested" then
    HideSymbol(t)
    S.ApplySlotZ(t, true)
  elseif act ~= "drop" and S.SHEETS[act] then
    S.ApplySlotZ(t, false)
    S.ApplySheet(t, act)
  else
    S.ApplySlotZ(t, false)
    HideSymbol(t)
  end
  if Wd and Wd.SyncFlaskHit then Wd.SyncFlaskHit(t) end
end

------------------------------------------------------------------------------
-- Éclat sur la case métier (maître à proximité)
------------------------------------------------------------------------------
function S.ProfessionTiles()
  local out = {}
  local ui = ns.UI
  local tiles = (ui and ui.embed and ui.embed.tiles) or {}
  for i = 1, #tiles do
    local t = tiles[i]
    local d = t and t.data
    if d and not d.placeholder and (d.kind == "profession" or d.kind == "secondary") and d.id ~= "riding" then
      out[#out + 1] = t
    end
  end
  return out
end

function S.EnsureGlint(t)
  if t._trGlint then return t._trGlint end
  local parent = t.icon or t
  if not parent or type(parent.CreateTexture) ~= "function" then
    if type(t.CreateTexture) ~= "function" then return nil end
    parent = t
  end
  local tex = parent:CreateTexture(nil, "OVERLAY")
  if not tex then return nil end
  if tex.SetTexture then pcall(tex.SetTexture, tex, S.TRAINER_SHEET) end
  if tex.SetSize then pcall(tex.SetSize, tex, 14, 14) end
  t._trGlint = tex
  return tex
end

function S.ApplyTrainerGlints()
  local on = S.Want("trainer")
  local tiles = S.ProfessionTiles()
  for i = 1, #tiles do
    local t = tiles[i]
    if on then
      local g = S.EnsureGlint(t)
      if g then
        local a = t.icon or t
        if g.ClearAllPoints then pcall(g.ClearAllPoints, g) end
        if g.SetPoint then pcall(g.SetPoint, g, "TOPRIGHT", a, "TOPRIGHT", 1, 1) end
        if g.SetTexCoord then pcall(g.SetTexCoord, g, TexCoord(S._frame.trainer or 1, 32)) end
        if g.Show then g:Show() end
      end
    elseif t._trGlint and t._trGlint.Hide then
      t._trGlint:Hide()
    end
  end
end

------------------------------------------------------------------------------
-- Infobulle du puits
------------------------------------------------------------------------------
S.TIPS = {
  death     = { "Mort ou fantôme", "Le suivi est en pause jusqu'à la résurrection." },
  flight    = { "En pause pendant le vol", "Le scan reprend dès l'atterrissage." },
  afk       = { "Absent", "Tu es absent." },
  fishing   = { "En train de pêcher", "La ligne est lancée." },
  swimming  = { "À la nage", "Tu nages." },
  rested    = { "Au repos", "Tu te reposes à l'auberge ou en capitale." },
}
S.COMBAT_TIP = "En combat : XP et armes en cours"

function S.ShowExplanation(owner)
  local act = S.Active()
  if act == "drop" and S.LiveFlight() then act = "flight" end
  if act == "drop" and S.CombatLiquidOn() and (S.LiveCombat() or ((S.fill and S.fill.p) or 0) > 0.05) then
    act = "combat"
  end
  if act == "drop" then return end
  local tt = _G.GameTooltip
  if not (tt and owner) then return end
  if type(tt.SetOwner) == "function" then pcall(tt.SetOwner, tt, owner, "ANCHOR_RIGHT") end
  if type(tt.ClearLines) == "function" then pcall(tt.ClearLines, tt) end
  if act == "combat" then
    local title = Tr[S.COMBAT_TIP] or S.COMBAT_TIP
    if type(tt.SetText) == "function" then
      pcall(tt.SetText, tt, title, 1, 0.82, 0)
    elseif type(tt.AddLine) == "function" then
      pcall(tt.AddLine, tt, title, 1, 0.82, 0, true)
    end
  else
    local tip = S.TIPS[act]
    if not tip then return end
    local title, line = Tr[tip[1]] or tip[1], Tr[tip[2]] or tip[2]
    if type(tt.SetText) == "function" then
      pcall(tt.SetText, tt, title, 1, 0.82, 0)
    elseif type(tt.AddLine) == "function" then
      pcall(tt.AddLine, tt, title, 1, 0.82, 0, true)
    end
    if type(tt.AddLine) == "function" then
      pcall(tt.AddLine, tt, line, 1, 1, 1, true)
    end
  end
  if type(tt.Show) == "function" then pcall(tt.Show, tt) end
end

------------------------------------------------------------------------------
-- Cadence
------------------------------------------------------------------------------
function S.NeedsDriver()
  local act = S.Active()
  if act ~= "drop" then return true end
  if S.Want("trainer") then return true end
  if S.FillBusy() then return true end
  if (S._jolt or 0) > 0 then return true end
  local F = ns.Flight
  if F and (F.Paused and F.Paused() or (F._vis or 0) > 0) then return true end
  return false
end

function S.StartDriver()
  local F = ns.Flight
  if F and F.StartVisualDriver then return F.StartVisualDriver() end
  return nil
end

function S.TickSheets(dt)
  for id, sh in pairs(S.SHEETS) do
    S._acc[id] = (S._acc[id] or 0) + dt
    if S._acc[id] >= (sh.step or 0.1) then
      local steps = math.floor(S._acc[id] / sh.step)
      S._acc[id] = S._acc[id] - steps * sh.step
      S._frame[id] = ((S._frame[id] or 1) - 1 + steps) % sh.frames + 1
    end
  end
  S._acc.combatA = (S._acc.combatA or 0) + dt
  if S._acc.combatA >= 0.08 then
    -- bulles plus rapides que la nage (~12,5 i/s)
    local steps = math.floor(S._acc.combatA / 0.08)
    S._acc.combatA = S._acc.combatA - steps * 0.08
    S._frame.combatA = ((S._frame.combatA or 1) - 1 + steps) % 32 + 1
  end
  S._acc.trainer = (S._acc.trainer or 0) + dt
  if S._acc.trainer >= 0.1 then
    local steps = math.floor(S._acc.trainer / 0.1)
    S._acc.trainer = S._acc.trainer - steps * 0.1
    S._frame.trainer = ((S._frame.trainer or 1) - 1 + steps) % 32 + 1
  end
end

function S.Tick(dt)
  dt = N(dt) or 0
  if dt <= 0 then return end
  if dt > 0.25 then dt = 0.25 end
  -- pêche récente (pour le sursaut à la prise)
  if S.LiveFishing() then S._fishUntil = Now() + 2 end
  S._jolt = math.max(0, (S._jolt or 0) - dt * 4)
  S._phase = (S._phase or 0) + dt * 0.7
  if S._phase > 1 then S._phase = S._phase - math.floor(S._phase) end
  S.SyncFillTargets()
  local rate = S.FILL_RATE
  local f = S.fill
  f.p = Approach(f.p, f.targetP, rate, dt)
  f.grey = Approach(f.grey, f.targetGrey, rate, dt)
  f.drain = Approach(f.drain, f.targetDrain, rate, dt)
  S.TickSheets(dt)
  S.ApplyTotal()
  S.ApplyFlaskFill()
  S.ApplyCombatLiq()
  S.ApplyTrainerGlints()
  S.TickSlotZ(dt)
end

function S.Refresh(reason)
  S.SyncFillTargets()
  if S.LiveFishing() then S._fishUntil = Now() + 2 end
  if S.NeedsDriver() then S.StartDriver() end
  S.ApplyTotal()
  S.ApplyFlaskFill()
  S.ApplyCombatLiq()
  S.ApplyTrainerGlints()
  local RT = ns.RankToast
  if RT and RT.Refresh then pcall(RT.Refresh, reason) end
end

function S.OnCatch()
  if S._sim.fishing or S.LiveFishing() or Now() <= (S._fishUntil or 0) then
    S._jolt = 1
    S.StartDriver()
  end
end

------------------------------------------------------------------------------
-- Options
------------------------------------------------------------------------------
S.OPTIONS = {
  { type = "check", key = "slotDeath", label = "Crâne à la mort", default = true,
    help = "Dans le puits de la fiole : un crâne, fiole vidée et grisée, suivi en pause jusqu'à la résurrection." },
  { type = "check", key = "slotFlight", label = "Sablier pendant le vol", default = true,
    help = "Remplace la goutte par le sablier pendant un trajet aérien. La pause du suivi reste réglée à part." },
  { type = "radio", key = "combatStyle", label = "Style de combat", default = "bubbles",
    choices = { { "bubbles", "Bulles" }, { "sword", "Épée" }, { "off", "Désactivé" } },
    cmd = "/drop combat bulles|epee|off",
    help = "Bulles (défaut) : la fiole se remplit en rouge et bleu, avec des bulles ambrées. Épée : le même liquide, plus une petite épée de bronze dans le puits. Désactivé : pas d'effet de combat.",
    get = function() return S.CombatStyle() end,
    set = function(v) S.SetCombatStyle(v) S.Refresh("option") end },
  { type = "check", key = "slotAfk", label = "Horloge AFK", default = true,
    help = "Une horloge de bronze à aiguille tournante quand tu es absent." },
  { type = "check", key = "slotFishing", label = "Hameçon à la pêche", default = true,
    help = "Un hameçon qui tangue tant que la ligne est lancée, et un petit sursaut quand la prise arrive dans les sacs." },
  { type = "check", key = "slotSwimming", label = "Bulles à la nage", default = true,
    help = "Des bulles montent dans le puits tant que tu nages." },
  { type = "check", key = "slotRested", label = "« z » de repos sur la fiole", default = true,
    help = "Les « z » de repos montent dans le puits de la fiole à l'auberge ou en capitale, s'il n'y a pas d'autre symbole." },
  { type = "check", key = "slotTrainer", label = "Éclat maître à proximité", default = true,
    help = "Un petit éclat sur la case du métier quand un maître est à proximité (pas dans la fiole)." },
}

------------------------------------------------------------------------------
-- Branchements
------------------------------------------------------------------------------
local function Hook(obj, name, wrap)
  if not (obj and obj[name]) then return end
  local base = obj[name]
  obj[name] = function(...)
    return wrap(base, ...)
  end
end

-- Pause du suivi pendant la mort (même porte que le vol).
do
  local prev = ns.PausedForFlight
  function ns.PausedForFlight()
    if S.DeathPause and S.DeathPause() then return true end
    if prev then return prev() end
    return false
  end
end

if ns.Wide and ns.Wide.LayoutSegments then
  local base = ns.Wide.LayoutSegments
  function ns.Wide.LayoutSegments(...)
    local a, b = base(...)
    pcall(S.ApplyFlaskFill)
    return a, b
  end
end

if ns.OnOptionChanged then
  -- déjà une fonction ; on s'y greffe plus bas si besoin
end
local prevOpt = ns.OnOptionChanged
function ns.OnOptionChanged(key, value)
  if prevOpt then pcall(prevOpt, key, value) end
  if type(key) == "string" and (key:find("^slot", 1) or key == "trainerRankToast" or key == "combatStyle") then
    pcall(S.Refresh, "option")
  end
  -- slotFlight off : cacher le sablier même en vol
  if key == "slotFlight" and value == false then
    local F = ns.Flight
    if F and not F.Paused() then return end
    pcall(S.Refresh, "option")
  end
end

if ns.On then
  local evs = {
    "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_FLAGS_CHANGED",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "BAG_UPDATE", "CHAT_MSG_LOOT", "LOOT_CLOSED",
    "PLAYER_ENTERING_WORLD", "PLAYER_UPDATE_RESTING",
    "TRAINER_SHOW", "TRAINER_CLOSED", "GOSSIP_SHOW", "GOSSIP_CLOSED",
    "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT",
    "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA",
    "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL",
  }
  for i = 1, #evs do
    local ev = evs[i]
    ns.On(ev, function(...)
      if ev == "BAG_UPDATE" or ev == "CHAT_MSG_LOOT" or ev == "LOOT_CLOSED" then
        pcall(S.OnCatch)
      end
      pcall(S.Refresh, ev)
    end)
  end
end

if ns.Options then
  ns.Options.EXTRA = ns.Options.EXTRA or {}
  ns.Options.EXTRA_HOME = ns.Options.EXTRA_HOME or {}
  local order = ns.Options.ITEM_ORDER and ns.Options.ITEM_ORDER.display
  local at = order and (#order + 1) or 1
  if order then
    for i, k in ipairs(order) do
      if k == "pauseFlying" or k == "restedAnim" then at = i + 1 end
    end
  end
  for _, it in ipairs(S.OPTIONS) do
    ns.Options.EXTRA[#ns.Options.EXTRA + 1] = it
    ns.Options.EXTRA_HOME[it.key] = "display"
    if order then
      table.insert(order, at, it.key)
      at = at + 1
    end
  end
  if ns.Options.All then ns.Options.ITEMS = ns.Options.All() end
end

ns.SlashExt = ns.SlashExt or {}
ns.SlashExt.combat = function(rest)
  local arg = (rest or ""):match("^%s*(%S*)") or ""
  if arg == "" then
    local cur = S.CombatStyle()
    local label = (cur == "sword" and Tr["Épée"]) or (cur == "off" and Tr["Désactivé"]) or Tr["Bulles"]
    ns.Print((Tr["style de combat"] or "style de combat") .. " : " .. (label or cur) .. ". /drop combat bulles|epee|off")
    return
  end
  local n = S.SetCombatStyle(arg)
  S.Refresh("slash")
  ns.Print((Tr["style de combat"] or "style de combat") .. " : " .. n)
end
ns.HelpExt = ns.HelpExt or {}
ns.HelpExt[#ns.HelpExt + 1] = "/drop combat bulles|epee|off : style de combat"
