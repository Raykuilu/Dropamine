-- Dropamine 3.3.5 — alertes de récolte (Dépeçage, Minage, Herboristerie).
--   1) Infobulle de bête / cadavre : signal FIABLE = la ligne native
--      « Dépeçable » / « Skinnable » du jeu (lecture seule), sinon une API
--      UnitIsSkinnable si le client en a une, sinon un nom déjà vu dépeçable
--      (mémorisé dans les SavedVariables) ou une créature dépeçable de la base
--      Forever. On AJOUTE une ligne « Dépeçage : … » sous la ligne native (rien
--      n'est réécrit), seulement si tu as Dépeçage.
--   2) Repère de proximité : petite icône de peau (notre cadre, ancré à la
--      barre de nom, jamais modifiée) sur les bêtes dépeçables qui peuvent
--      encore rapporter un point. /drop alertes on|off.
--   3) Nœuds de Minage / Herboristerie : la ligne existante (« Requiert … »)
--      et, si le jeu ne l'affiche pas, le rang requis déjà relevé pour ce nœud.
-- Rang requis pour dépecer : règle publiée pour Forever (Warcraft Wiki,
-- « Forever skinning techniques ») — niveau 1-10 : 1 ; 11-20 : (niveau-10)×10 ;
-- 21+ : niveau×5 ; calculée par le serveur (non lisible dans le client).
-- Les seuils de couleur (orange / jaune / vert / gris) ne sont PAS publiés pour
-- Forever : la couleur vient de ce qu'on OBSERVE (point gagné à ton rang = vert ;
-- 3 dépeçages sans point à ton rang = gris ; rang insuffisant = rouge ; sinon
-- bronze « possible »). Rien d'inventé.
-- Performance : uniquement des événements ; barres de nom traitées par lots
-- (4 par 0,25 s, minuterie C_Timer, aucun OnUpdate), évaluations en cache par
-- nom, repères recyclés (pool).
local ADDON, ns = ...
local Tr = ns.L   -- 3.5.19 : textes traduits (Locales/)
local S = ns.Scanner
S.UnifiedMarkers = true
local G = {}
ns.Gather = G

local function N(v) return ns.N(v) end
local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local r = { pcall(fn, ...) }
  if not r[1] then return nil end
  return unpack(r, 2)
end
local function Str(v) if type(v) ~= "string" or (ns.IsSecret and ns.IsSecret(v)) or v == "" then return nil end return v end
local function InCombat() return S and S.InCombat and S.InCombat() end
local function Now() return N(Call(_G.GetTime)) or 0 end
local function After(sec, fn)
  if type(_G.C_Timer) == "table" and type(_G.C_Timer.After) == "function" then _G.C_Timer.After(sec, fn) return true end
  return false
end

G.stats = { events = 0, evals = 0, evalCached = 0, markersCreated = 0, tooltips = 0, batches = 0 }
G.SKIN_SOURCE = "règle Forever publiée (Warcraft Wiki « Forever skinning techniques ») ; calcul serveur"
G.NATIVE = { ["dépeçable"] = true, ["skinnable"] = true }
G.COLORS = { locked = { 1, 0.3, 0.3 }, trivial = { 0.5, 0.5, 0.5 }, capped = { 0.5, 0.5, 0.5 }, easy = { 0.25, 0.75, 0.25 }, possible = { 0.72, 0.56, 0.32 } }
G.NO_GAIN_GREY = 3

function G.Enabled() return not (ns.db and ns.db.ui and ns.db.ui.gatherAlerts == false) end

function G.SkinReq(level)
  level = N(level)
  if not level or level <= 0 then return nil end
  if level <= 10 then return 1 end
  if level <= 20 then return (level - 10) * 10 end
  return level * 5
end

-- Rang de Dépeçage : mis en cache (lecture des compétences coûteuse) ; vidé à
-- chaque montée de compétence.
function G.Rank()
  local t = Now()
  if G._rank ~= nil and G._rankAt and (t - G._rankAt) < 5 then return G._rank end
  G._rank = (S.RankOf and S.RankOf("skinning")) or nil
  G._rankAt = t
  return G._rank
end
function G.Max()
  local t = Now()
  if G._max ~= nil and G._maxAt and (t - G._maxAt) < 5 then return G._max end
  G._max = (S.MaxOf and S.MaxOf("skinning")) or false
  G._maxAt = t
  return G._max or nil
end
function G.Invalidate() G._rank, G._rankAt, G._max, G._maxAt, G._states, G._plateCache = nil, nil, nil, nil, {}, {} end
G._plateCache = {}
G._states = {}

function G.DB()
  local db = S.DB()
  db.skinNames = db.skinNames or {}
  return db.skinNames
end
function G.Learn(name, level, how)
  name = Str(name)
  if not name then return nil end
  local k = ns.Fold(name)
  local db = G.DB()
  local e = db[k]
  local fresh = not e
  e = e or { name = name }
  e.level = N(level) and N(level) > 0 and N(level) or e.level
  e.how = e.how or how
  db[k] = e
  if fresh then G._states[k] = nil G._plateCache = {} end
  return e, fresh
end
function G.Known(name) local n = Str(name) return n and G.DB()[ns.Fold(n)] or nil end

-- Créature dépeçable de la base Forever (npcID).
function G.StaticSkinnable(npcID)
  local c = npcID and S.StaticCreature and S.StaticCreature(npcID)
  return c and c.skills and (c.skills.skinning or 0) > 0 or false
end

-- État pour un nom / niveau : { diff, text, req } (cache par nom + niveau).
function G.State(name, level)
  local rank = G.Rank()
  if not rank or rank <= 0 then return nil end
  local k = ns.Fold(name or "?") .. "#" .. tostring(level or "?")
  local c = G._states[k]
  G.stats.evals = G.stats.evals + 1
  if c then G.stats.evalCached = G.stats.evalCached + 1 return c end
  local req = G.SkinReq(level)
  local e = G.Known(name) or {}
  local st
  local mx = G.Max()
  if mx and mx > 0 and rank >= mx then
    st = { diff = "capped", text = Tr["Dépeçage : plafond atteint ("] .. rank .. "/" .. mx .. Tr[") — va voir ton maître"], req = req }
  elseif req and rank < req then
    st = { diff = "locked", text = Tr["Dépeçage : "] .. req .. Tr[" requis (actuel "] .. rank .. ")", req = req }
  else
    local greyAt = e.greyAt
    if greyAt and rank >= greyAt and not ((e.gainMax or -1) >= rank) then
      st = { diff = "trivial", text = Tr["Dépeçage : plus de point ("] .. G.NO_GAIN_GREY .. Tr[" dépeçages sans gain au rang "] .. greyAt .. ")", req = req }
    elseif e.gainMax and e.gainMax >= rank - 1 then
      st = { diff = "easy", text = Tr["Dépeçage : +1 possible · point gagné au rang "] .. e.gainMax, req = req }
    else
      st = { diff = "possible", text = Tr["Dépeçage : +1 possible"] .. (req and (Tr[" · requis "] .. req) or Tr[" · rang requis inconnu"]), req = req }
    end
  end
  st.color = G.COLORS[st.diff]
  G._states[k] = st
  return st
end
function G.GivesPoints(st) return st and st.diff ~= "locked" and st.diff ~= "trivial" and st.diff ~= "capped" end

------------------------------------------------------------------------------
-- 1) Infobulle d'unité
------------------------------------------------------------------------------
G.MAX_SCAN = 10
function G.ScanNative(tt)
  local tname = (tt.GetName and Call(tt.GetName, tt)) or "GameTooltip"
  local n = math.min(N(Call(tt.NumLines, tt)) or 0, G.MAX_SCAN)
  local native, ours
  for i = 2, n do
    local fs = _G[tname .. "TextLeft" .. i]
    local txt = fs and Str(Call(fs.GetText, fs))
    if txt then
      local f = txt:lower()
      if G.NATIVE[f] then native = i end
      if txt:find(Tr["^Dépeçage : "]) then ours = i end
    end
  end
  return native, ours
end
-- 3.3.8 : état de Dépeçage d'une unité (sans rien écrire) ; l'infobulle
-- compacte (Tip.lua) l'affiche sur UNE ligne.
function G.UnitState(tt, unit)
  if not G.Enabled() or InCombat() then return nil end
  unit = unit or "mouseover"
  local name = Str(Call(_G.UnitName, unit))
  if not name then return nil end
  local native = type(tt) == "table" and G.ScanNative(tt) or nil
  local level = N(Call(_G.UnitLevel, unit))
  local api = type(_G.UnitIsSkinnable) == "function" and Call(_G.UnitIsSkinnable, unit) or nil
  if native or api then G.Learn(name, level, native and "ligne native" or "UnitIsSkinnable") end
  local npc = S.UnitNpcID(unit)
  local dead = Call(_G.UnitIsDead, unit)
  local skinnable = native or api or (G.Known(name) and true) or (not dead and G.StaticSkinnable(npc))
  if not skinnable then return nil end
  local st = G.State(name, level)
  if st then G.lastTip = { name = name, text = st.text, diff = st.diff, native = native and true or false } end
  return st
end
function G.UnitTooltip(tt, unit)
  if ns.Tip and ns.Tip.active then return nil end   -- 3.3.8 : infobulle compacte
  if not G.Enabled() or InCombat() or type(tt) ~= "table" then return nil end
  unit = unit or "mouseover"
  G.stats.tooltips = G.stats.tooltips + 1
  local name = Str(Call(_G.UnitName, unit))
  if not name then return nil end
  local native, ours = G.ScanNative(tt)
  if ours then return nil end
  local level = N(Call(_G.UnitLevel, unit))
  local api = type(_G.UnitIsSkinnable) == "function" and Call(_G.UnitIsSkinnable, unit) or nil
  if native or api then G.Learn(name, level, native and "ligne native" or "UnitIsSkinnable") end
  local npc = S.UnitNpcID(unit)
  local dead = Call(_G.UnitIsDead, unit)
  local skinnable = native or api or (G.Known(name) and true) or (not dead and G.StaticSkinnable(npc))
  if not skinnable then return nil end
  local st = G.State(name, level)
  if not st then return nil end   -- pas de Dépeçage
  local c = st.color
  pcall(tt.AddLine, tt, st.text, c[1], c[2], c[3])
  if tt.Show then pcall(tt.Show, tt) end
  G.lastTip = { name = name, text = st.text, diff = st.diff, native = native and true or false }
  return st
end
function G.HookTooltip()
  if G._hooked then return end
  local tt = _G.GameTooltip
  if type(tt) ~= "table" then return end
  G._hooked = true
  if type(_G.TooltipDataProcessor) == "table" and type(_G.TooltipDataProcessor.AddTooltipPostCall) == "function"
    and _G.Enum and _G.Enum.TooltipDataType and _G.Enum.TooltipDataType.Unit then
    pcall(_G.TooltipDataProcessor.AddTooltipPostCall, _G.Enum.TooltipDataType.Unit, function(t) if t == tt then pcall(G.UnitTooltip, t) end end)
    G.ttMode = "TooltipDataProcessor"
  elseif tt.HookScript then
    pcall(tt.HookScript, tt, "OnTooltipSetUnit", function(t) pcall(G.UnitTooltip, t) end)
    G.ttMode = "OnTooltipSetUnit"
  end
end

------------------------------------------------------------------------------
-- 2) Repères sur les barres de nom (lots de 4 / 0,25 s, pool)
------------------------------------------------------------------------------
G.BATCH, G.BATCH_DT = 4, 0.25
G.queue, G.queued, G.active, G.pool = {}, {}, {}, {}
local function PeltIcon()
  local e = ns.CATALOG_BY_ID and ns.CATALOG_BY_ID.skinning
  return e and e.icon or "Interface\\Icons\\INV_Misc_Pelt_Wolf_01"
end
-- 3.3.8 : UN repère par barre de nom, centré JUSTE AU-DESSUS du nom / de la
-- barre de vie (quelle que soit la longueur du nom ou l'état ciblé), avec une
-- icône par métier concerné (Dépeçage, Cuisine, Secourisme). Bordure de chaque
-- icône : VERTE si un point de compétence est possible (rang requis atteint,
-- pas gris, pas au plafond), GRISE sinon. Le « pourquoi » est dans l'infobulle
-- de la créature (lignes « Dépeçage : … » et recettes). Cadres recyclés ; état
-- calculé une fois par créature / niveau (cache), repositionné à l'apparition
-- de la barre et au changement de cible.
G.ICON, G.ICON_GAP = 16, 2
G.GAIN_DIFF = { optimal = true, medium = true, easy = true }
G.RING_GREEN, G.RING_GREY = { 0.25, 0.95, 0.25 }, { 0.55, 0.55, 0.55 }
local function SkillIcon(id)
  local e = ns.CATALOG_BY_ID and ns.CATALOG_BY_ID[id]
  return e and e.icon or (id == "skinning" and "Interface\\Icons\\INV_Misc_Pelt_Wolf_01") or ns.FALLBACK_ICON
end
local function NewIcon(m)
  local c = CreateFrame("Frame", nil, m)
  c:SetSize(G.ICON, G.ICON)
  c.ring = c:CreateTexture(nil, "BACKGROUND")
  c.ring:SetAllPoints(c)
  pcall(c.ring.SetTexture, c.ring, "Interface\\Buttons\\WHITE8X8")
  c.icon = c:CreateTexture(nil, "ARTWORK")
  c.icon:SetPoint("TOPLEFT", c, "TOPLEFT", 1, -1)
  c.icon:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -1, 1)
  if c.icon.SetTexCoord then pcall(c.icon.SetTexCoord, c.icon, 0.07, 0.93, 0.07, 0.93) end
  return c
end
function G.AcquireMarker()
  local m = table.remove(G.pool)
  if m then return m end
  m = CreateFrame("Frame", nil, UIParent)
  m._osrsOwn = true
  if m.EnableMouse then m:EnableMouse(false) end
  m:SetSize(G.ICON, G.ICON)
  m.icons = {}
  G.stats.markersCreated = G.stats.markersCreated + 1
  return m
end
function G.Release(unit)
  local m = G.active[unit]
  if not m then return end
  m:Hide()
  m:ClearAllPoints()
  G.active[unit] = nil
  G.pool[#G.pool + 1] = m
end

-- Ancre : centre horizontal de la barre de vie, juste au-dessus du nom.
local function Rect(o)
  if type(o) ~= "table" or not o.GetTop then return nil end
  local ok, t = pcall(o.GetTop, o)
  return ok and N(t) or nil
end
local function Shown(o) if type(o) ~= "table" then return false end if o.IsShown then local ok, v = pcall(o.IsShown, o) return ok and v end return true end
function G.PlateParts(plate)
  local uf = rawget(plate, "UnitFrame") or plate
  local hb = rawget(uf, "healthBar") or rawget(uf, "HealthBar") or rawget(uf, "healthbar")
  local nm = rawget(uf, "name") or rawget(uf, "Name")
  return (type(hb) == "table" and hb.GetTop) and hb or nil, (type(nm) == "table" and nm.GetTop) and nm or nil
end
function G.Anchor(m, plate)
  local hb, nm = G.PlateParts(plate)
  local ref = hb or plate
  local y = 2
  local rt = Rect(ref)
  local nt = Shown(nm) and Rect(nm) or nil
  if rt and nt and nt > rt then y = (nt - rt) + 2 end
  m:ClearAllPoints()
  local ok = pcall(m.SetPoint, m, "BOTTOM", ref, "TOP", 0, y)
  m._ref, m._y = ref, y
  return ok
end

-- Icônes d'une créature : { { skill, green, why } } (cache par créature / niveau).
function G.PlateEntries(unit)
  local name = Str(Call(_G.UnitName, unit))
  local level = N(Call(_G.UnitLevel, unit))
  local npc = S.UnitNpcID(unit)
  local key = tostring(npc or name) .. "#" .. tostring(level) .. "#" .. tostring(ns.Craft and ns.Craft._ver) .. "#" .. tostring(S._learnVer)
  local hit = G._plateCache[key]
  if hit then G.stats.evalCached = G.stats.evalCached + 1 return hit end
  local out = {}
  if name and G.Enabled() and (G.Rank() or 0) > 0 and (G.Known(name) or G.StaticSkinnable(npc)) then
    local st = G.State(name, level)
    if st then out[#out + 1] = { skill = "skinning", green = G.GivesPoints(st), why = st.text } end
  end
  local scan = S.Enabled and S.Enabled() and ns.Opt("scannerIcons") ~= false
  local c = scan and npc and S.CreatureFor and S.CreatureFor(npc, { name = name }) or nil
  if c then
    for _, sk in ipairs({ "cooking", "firstaid" }) do
      local rank = S.RankOf(sk)
      if rank and rank > 0 then
        local diff, recipe = S.CreatureDiff(c, sk)
        local mx = S.MaxOf and S.MaxOf(sk)
        if diff and diff ~= "trivial" and not (mx and mx > 0 and rank >= mx) then
          out[#out + 1] = { skill = sk, green = true, why = Tr["butin : "] .. tostring(recipe and recipe.name or Tr["recette"]) }
        elseif (c.skills and (c.skills[sk] or 0) > 0) and ns.CharDB().recipes and ns.CharDB().recipes[sk] then
          out[#out + 1] = { skill = sk, green = false, why = (mx and mx > 0 and rank >= mx) and Tr["plafond atteint"] or Tr["recettes connues grises"] }
        end
      end
    end
  end
  -- 3.3.14 : liens entre métiers (même source que l'infobulle) : une icône par
  -- métier, verte si une recette apprise donne un point, grise sinon.
  local L = ns.Links
  if c and L and L.Lines and L.CreatureItems and ns.Opt("links") then
    local have = {}
    for _, e in ipairs(out) do have[e.skill] = e end
    local okL, _, all = pcall(L.Lines, L.CreatureItems(c), { cap = 999 })
    local by, order = {}, {}
    for _, e in ipairs(okL and all or {}) do
      if e.skill and e.learned == true then
        local b = by[e.skill]
        if not b then b = { green = false } by[e.skill] = b order[#order + 1] = e.skill end
        if G.GAIN_DIFF[e.diff] and not b.green then b.green, b.name = true, e.name end
        b.any = b.any or e.name
      end
    end
    for _, sk in ipairs(order) do
      local b = by[sk]
      local ex = have[sk]
      if ex then
        if b.green and not ex.green then ex.green, ex.why = true, Tr["lien : "] .. tostring(b.name) end
      else
        local e = { skill = sk, green = b.green, why = b.green and (Tr["lien : "] .. tostring(b.name)) or Tr["recettes grises"] }
        out[#out + 1] = e
        have[sk] = e
      end
    end
  end
  G._plateCache[key] = out
  return out
end

function G.Evaluate(unit)
  if InCombat() then return nil end
  if Call(_G.UnitIsDead, unit) or (S.IsPlayerUnit and S.IsPlayerUnit(unit)) or Call(_G.UnitIsPlayer, unit) then G.Release(unit) return nil end
  local list = G.PlateEntries(unit)
  if #list == 0 then G.Release(unit) return nil end
  local plate = type(_G.C_NamePlate) == "table" and Call(_G.C_NamePlate.GetNamePlateForUnit, unit)
  if type(plate) ~= "table" then return nil end
  local m = G.active[unit] or G.AcquireMarker()
  G.active[unit] = m
  local n = #list
  local w = n * G.ICON + (n - 1) * G.ICON_GAP
  m:SetSize(w, G.ICON)
  for i = 1, math.max(n, #m.icons) do
    local c = m.icons[i]
    if i <= n then
      c = c or NewIcon(m)
      m.icons[i] = c
      local e = list[i]
      c:ClearAllPoints()
      c:SetPoint("LEFT", m, "LEFT", (i - 1) * (G.ICON + G.ICON_GAP), 0)
      pcall(c.icon.SetTexture, c.icon, SkillIcon(e.skill))
      local col = e.green and G.RING_GREEN or G.RING_GREY
      if c.ring.SetVertexColor then pcall(c.ring.SetVertexColor, c.ring, col[1], col[2], col[3], 1) end
      c._skill, c._green, c._why = e.skill, e.green, e.why
      c:Show()
    elseif c then c:Hide() end
  end
  m._n, m._list = n, list
  m._diff = list[1].green and "easy" or "trivial"
  m.ring = m.icons[1].ring        -- compatibilité (tests / debug)
  if not G.Anchor(m, plate) then G.Release(unit) return nil end
  m:Show()
  return m
end
-- cible changée : les barres changent de taille / de place du nom → on recale
function G.Reanchor()
  local n = 0
  for unit, m in pairs(G.active) do
    local plate = type(_G.C_NamePlate) == "table" and Call(_G.C_NamePlate.GetNamePlateForUnit, unit)
    if type(plate) == "table" then G.Anchor(m, plate) n = n + 1 end
  end
  return n
end
function G.RunBatch()
  G._batchPending = nil
  G.stats.batches = G.stats.batches + 1
  local n = 0
  while #G.queue > 0 and n < G.BATCH do
    local unit = table.remove(G.queue, 1)
    G.queued[unit] = nil
    n = n + 1
    pcall(G.Evaluate, unit)
  end
  if #G.queue > 0 then G.Schedule() end
end
function G.Schedule()
  if G._batchPending then return end
  G._batchPending = true
  if not After(G.BATCH_DT, G.RunBatch) then G.RunBatch() end
end
function G.OnPlateAdded(unit)
  G.stats.events = G.stats.events + 1
  if not G.Enabled() or InCombat() or not unit or G.queued[unit] then return end
  G.queued[unit] = true
  G.queue[#G.queue + 1] = unit
  G.Schedule()
end
function G.OnPlateRemoved(unit)
  G.stats.events = G.stats.events + 1
  if G.queued[unit] then
    G.queued[unit] = nil
    for i = #G.queue, 1, -1 do if G.queue[i] == unit then table.remove(G.queue, i) end end
  end
  G.Release(unit)
end
function G.HideAll() for unit in pairs(G.active) do G.Release(unit) end end
function G.Rescan()
  if InCombat() or not G.Enabled() then return end
  local plates = type(_G.C_NamePlate) == "table" and Call(_G.C_NamePlate.GetNamePlates) or {}
  for _, p in ipairs(plates or {}) do
    local unit = p.namePlateUnitToken or (p.UnitFrame and p.UnitFrame.unit)
    if unit then G.OnPlateAdded(unit) end
  end
end

------------------------------------------------------------------------------
-- Apprentissage : sort de Dépeçage → point gagné ou non (5 s)
------------------------------------------------------------------------------
G.GAIN_WINDOW = 5
function G.OnSkinCast()
  local name, lvl
  for _, u in ipairs({ "target", "mouseover" }) do
    if not name and Call(_G.UnitIsDead, u) then name, lvl = Str(Call(_G.UnitName, u)), N(Call(_G.UnitLevel, u)) end
  end
  if not name then return nil end
  local e = G.Learn(name, lvl, "dépeçage réussi")
  local pend = { name = name, key = ns.Fold(name), rank = G.Rank(), t = Now() }
  G.pending = pend
  After(G.GAIN_WINDOW, function()
    if pend.gained or not pend.rank then return end
    local en = G.DB()[pend.key]
    if not en then return end
    en.noGain = en.noGain or {}
    en.noGain[pend.rank] = (en.noGain[pend.rank] or 0) + 1
    if en.noGain[pend.rank] >= G.NO_GAIN_GREY and not en.greyAt then en.greyAt = pend.rank end
    G._states, G._plateCache = {}, {}
  end)
  return e
end
function G.OnSkillMsg(msg)
  G.Invalidate()
  local name, rank
  if ns.UI and ns.UI.ParseSkillMessage then name, rank = ns.UI:ParseSkillMessage(msg) end
  if not name or (ns.Style and ns.Style.SkillIdForText(name)) ~= "skinning" then return end
  local p = G.pending
  if p and (Now() - p.t) <= G.GAIN_WINDOW then
    p.gained = true
    local e = G.DB()[p.key]
    if e then
      local at = N(rank) and (N(rank) - 1) or p.rank
      e.gainMax = math.max(e.gainMax or 0, at or 0)
      if e.greyAt and at and at >= e.greyAt then e.greyAt = nil end
    end
  end
end

------------------------------------------------------------------------------
-- 3) Nœuds : rang requis déjà relevé quand le jeu n'affiche pas « Requiert »
------------------------------------------------------------------------------
local baseTooltipLine = S.TooltipLine
function S.TooltipLine(tooltip)
  local r = baseTooltipLine(tooltip)
  if r or not G.Enabled() or InCombat() or type(tooltip) ~= "table" then return r end
  if tooltip.GetUnit then local _, u = Call(tooltip.GetUnit, tooltip) if u then return nil end end
  local tname = (tooltip.GetName and tooltip:GetName()) or "GameTooltip"
  local title = Str(Call(function() local fs = _G[tname .. "TextLeft1"] return fs and fs:GetText() end))
  local node = title and S.DB().nodes[title]
  if not (node and node.skill and node.req) then return nil end
  local nLines = math.min(N(Call(tooltip.NumLines, tooltip)) or 0, G.MAX_SCAN)
  for i = 2, nLines do
    local fs = _G[tname .. "TextLeft" .. i]
    local txt = fs and Str(Call(fs.GetText, fs))
    if txt and (txt:find(Tr[" : +1 possible"], 1, true) or txt:find(Tr[" requis (actuel "], 1, true) or txt:find(Tr["(relevé)"], 1, true)) then return nil end
  end
  local rank, e = S.RankOf(node.skill)
  if not rank or rank <= 0 then return nil end
  local nm = e and ns.CatalogDisplayName(e) or node.skill
  local line, cr, cg, cb
  if rank >= node.req then
    line, cr, cg, cb = nm .. Tr[" : +1 possible (relevé : "] .. node.req .. Tr[" requis)"], 0.85, 0.85, 0.85
    if node.gainRank then line = line .. Tr[" · gain vu au rang "] .. node.gainRank end
  else
    line, cr, cg, cb = nm .. Tr[" : "] .. node.req .. Tr[" requis (relevé) — actuel "] .. rank, 1, 0.3, 0.3
  end
  S.lastNode = { name = title, skill = node.skill, t = Call(_G.GetTime) or 0 }
  pcall(tooltip.AddLine, tooltip, line, cr, cg, cb)
  pcall(tooltip.Show, tooltip)
  return line
end

-- Le repère « Dépeçage neutre » du scanner (au-dessus de la barre) ferait
-- doublon avec le nôtre : retiré quand les alertes sont actives.
local baseBestFor = S.BestFor
function S.BestFor(npcID, info)
  local skill, diff, r, m = baseBestFor(npcID, info)
  if skill == "skinning" and diff == "neutral" and G.Enabled() then return nil end
  return skill, diff, r, m
end

------------------------------------------------------------------------------
if ns.On then
  ns.On("PLAYER_LOGIN", function() G.HookTooltip() end)
  ns.On("NAME_PLATE_UNIT_ADDED", function(_, unit) G.OnPlateAdded(unit) end)
  ns.On("NAME_PLATE_UNIT_REMOVED", function(_, unit) G.OnPlateRemoved(unit) end)
  ns.On("PLAYER_TARGET_CHANGED", function() if next(G.active) then pcall(G.Reanchor) end end)
  ns.On("UNIT_NAME_UPDATE", function(_, unit) if unit and G.active[unit] then pcall(G.Evaluate, unit) end end)
  ns.On("PLAYER_REGEN_DISABLED", function() G.HideAll() end)
  ns.On("PLAYER_REGEN_ENABLED", function() G.Rescan() end)
  ns.On("CHAT_MSG_SKILL", function(_, msg) G.OnSkillMsg(msg) end)
  ns.On("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID)
    if unit ~= "player" then return end
    local nm = Str(Call(_G.GetSpellInfo, spellID))
    if nm and ns.Style and ns.Style.SkillIdForText(nm) == "skinning" then pcall(G.OnSkinCast) end
  end)
end

ns.SlashExt = ns.SlashExt or {}
ns.SlashExt.alertes = function(rest)
  ns.db.ui = ns.db.ui or {}
  rest = (rest or ""):lower()
  if rest == "on" then ns.db.ui.gatherAlerts = nil elseif rest == "off" then ns.db.ui.gatherAlerts = false
  elseif G.Enabled() then ns.db.ui.gatherAlerts = false else ns.db.ui.gatherAlerts = nil end   -- 3.3.13 : bascule (« x and false or nil » valait toujours nil)
  if not G.Enabled() then G.HideAll() else G.Rescan() end
  print(Tr["|cffffd100Dropamine|r : alertes de récolte "] .. (G.Enabled() and Tr["activées"] or Tr["désactivées"]))
end
ns.HelpExt = ns.HelpExt or {}
ns.HelpExt[#ns.HelpExt + 1] = "/drop alertes on|off : « Dépeçage : … » sur les bêtes / cadavres, repère de peau sur les barres de nom · /drop perf : coûts"

ns.DebugExt = ns.DebugExt or {}
ns.DebugExt[#ns.DebugExt + 1] = function()
  local n = 0 for _ in pairs(G.DB()) do n = n + 1 end
  return { "— Alertes de récolte (3.3.5) —",
    "  noms dépeçables mémorisés : " .. n .. " ; infobulle : " .. tostring(G.ttMode or "non accrochée") .. " ; rang requis : " .. G.SKIN_SOURCE,
    "  couleurs : seuils orange/jaune/vert non publiés pour Forever → couleur observée (vert = point vu, gris = " .. G.NO_GAIN_GREY .. " sans gain, rouge = rang insuffisant, bronze = possible)" }
end

-- /drop perf : coûts mesurés depuis la connexion.
function G.PerfLines()
  local C, L, P = ns.Compact, ns.Links, ns.Panel
  local out = {}
  local st = G.stats
  out[#out + 1] = string.format("perf : barres de nom %d événements → %d lots, %d évaluations (%d en cache), %d repères créés (pool %d, actifs %d)",
    st.events, st.batches, st.evals, st.evalCached, st.markersCreated, #G.pool, (function() local n = 0 for _ in pairs(G.active) do n = n + 1 end return n end)())
  if L then out[#out + 1] = string.format("perf : liens recettes %d demandes / %d calculs ; origines %d / %d", L.stats.uses, L.stats.usesMiss, L.stats.origin, L.stats.originMiss) end
  if C then out[#out + 1] = string.format("perf : éclats %d lancés, %d arrivés, cadres d'éclat %d (pool)", C.flights or 0, C.landed or 0, #(C.pool or {})) end
  local onu = 0
  if P and P.fader and P.fader.GetScript and P.fader:GetScript("OnUpdate") then onu = onu + 1 end
  out[#out + 1] = "perf : OnUpdate actifs de l'addon (hors toasts en cours) : " .. onu .. " (0 au repos)"
  return out
end
ns.SlashExt.perf = function() for _, l in ipairs(G.PerfLines()) do print("|cffffd100Dropamine|r " .. l) end end
