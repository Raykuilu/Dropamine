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
}
local O = ns.Options
if O then
  O.EXTRA_HOME = O.EXTRA_HOME or {}
  for _, it in ipairs(H.OPTIONS) do O.EXTRA[#O.EXTRA + 1] = it O.EXTRA_HOME[it.key] = it.home end
  if O.GROUPS then
    O.GROUPS.grpHardcore = { label = "Hardcore", help = "Actif seulement sur un personnage Hardcore (mode à venir sur Forever).",
      items = { { "hcManual", "Je joue en Hardcore (mode non officiel)" }, { "hcDanger", "Alerte danger sur la cible" }, { "hcSound", "Son d'alerte au ciblage" } } }
  end
  if O.MAP and O.MAP.advanced then table.insert(O.MAP.advanced, 1, { "Hardcore", { "grpHardcore" } }) end
  if O.TEST then
    O.TEST.hcDanger = "danger"
    O.TEST.hcSound = "hcsound"
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
-- cadre rouge (4 bords de 2 px, 2 px hors du panneau) + bandeau
function H.BuildPanelAlert(f)
  if not f then return nil end
  if H.glow and H.glow:GetParent() == f then return H.glow end
  local g = CreateFrame("Frame", nil, f)
  g:SetPoint("TOPLEFT", f, "TOPLEFT", -3, 3)
  g:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 3, -3)
  if g.SetFrameLevel and f.GetFrameLevel then pcall(g.SetFrameLevel, g, (N(f:GetFrameLevel()) or 1) + 20) end
  if g.EnableMouse then g:EnableMouse(false) end
  local function Edge(p1, p2, w, h)
    local t = g:CreateTexture(nil, "OVERLAY")
    pcall(t.SetTexture, t, WHITE)
    t:SetVertexColor(H.DANGER[1], H.DANGER[2], H.DANGER[3], 1)
    t:SetPoint(p1, g, p1) t:SetPoint(p2, g, p2)
    if w then t:SetWidth(w) else t:SetHeight(h) end
  end
  Edge("TOPLEFT", "TOPRIGHT", nil, 2) Edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 2)
  Edge("TOPLEFT", "BOTTOMLEFT", 2, nil) Edge("TOPRIGHT", "BOTTOMRIGHT", 2, nil)
  g.ag = Pulse(g, 1, 0.15, 0.6)
  -- bandeau sur le bord haut : tête de mort + raison
  local b = CreateFrame("Frame", nil, g)
  b:SetHeight(16)
  b:SetPoint("BOTTOM", g, "TOP", 0, -9)
  local bg = b:CreateTexture(nil, "BACKGROUND")
  pcall(bg.SetTexture, bg, WHITE)
  bg:SetVertexColor(0.30, 0.04, 0.02, 0.95)
  bg:SetAllPoints(b)
  local skull = b:CreateTexture(nil, "ARTWORK")
  pcall(skull.SetTexture, skull, "Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
  skull:SetSize(12, 12)
  skull:SetPoint("LEFT", b, "LEFT", 4, 0)
  local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetPoint("LEFT", skull, "RIGHT", 4, 0)
  fs:SetTextColor(1, 0.82, 0.78)
  b.fs = fs
  g.banner = b
  g:Hide()
  H.glow = g
  return g
end
-- goutte rouge qui bat, posée sur celle du total (même taille au repos)
function H.BuildDropAlert(t)
  local S = ns.Slot
  if not (t and S and S.PlaceIconClip) then return nil end
  local clip, content, w, h = S.PlaceIconClip(t)
  local parent = content or clip
  if not parent or type(parent.CreateTexture) ~= "function" then return nil end
  local tex = t._hcDrop
  if not tex then
    tex = parent:CreateTexture(nil, "OVERLAY", nil, 7)
    pcall(tex.SetTexture, tex, DROP_TEX)
    if tex.SetDesaturated then pcall(tex.SetDesaturated, tex, true) end
    tex:SetVertexColor(1, 0.15, 0.10, 1)
    local ag = tex:CreateAnimationGroup()
    if ag.SetLooping then ag:SetLooping("REPEAT") end
    local function Beat(order, s, d)
      local a = ag:CreateAnimation("Scale")
      if a.SetScaleFrom then a:SetScaleFrom(1, 1) a:SetScaleTo(s, s) elseif a.SetScale then a:SetScale(s, s) end
      a:SetDuration(d) a:SetOrder(order)
      if a.SetOrigin then a:SetOrigin("CENTER", 0, 0) end
    end
    Beat(1, 1.3, 0.12) Beat(2, 1, 0.12) Beat(3, 1.15, 0.10) Beat(4, 1, 0.5)
    tex.ag = ag
    t._hcDrop = tex
  end
  w, h = w or 16, h or 16
  local side = math.max(8, math.min(w, h))
  tex:ClearAllPoints()
  tex:SetSize(side, side)
  tex:SetPoint("CENTER", parent, "CENTER", 0, 0)
  return tex
end
local function TotalTiles()
  local out, tiles = {}, ns.UI and ns.UI.embed and ns.UI.embed.tiles
  for _, tt in ipairs(tiles or {}) do if tt and tt.data and tt.data.kind == "total" then out[#out + 1] = tt end end
  return out
end
local function Play(ag, on) if ag then if on then if not ag:IsPlaying() then ag:Play() end else ag:Stop() end end end
-- état de l'alerte : why = texte ou nil
function H.Show(why)
  H.why = why
  local Wn = ns.Window
  local f = Wn and Wn.frame
  local g = (why and f) and H.BuildPanelAlert(f) or H.glow
  if g then
    if why then
      g.banner.fs:SetText(why)
      g.banner:SetWidth((N(g.banner.fs:GetStringWidth()) or 60) + 26)
      g:Show() Play(g.ag, true)
    else
      Play(g.ag, false) g:Hide()
    end
  end
  for _, t in ipairs(TotalTiles()) do
    local busy = t._needle and t._needle.IsShown and t._needle:IsShown()
    local tex = (why and not busy) and H.BuildDropAlert(t) or t._hcDrop
    if tex then
      if why and not busy then tex:Show() Play(tex.ag, true) else Play(tex.ag, false) tex:Hide() end
    end
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
    if key == "hcDanger" or key == "hcManual" then pcall(H.Update, false) end
    return unpack(r)
  end
end
