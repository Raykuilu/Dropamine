-- Dropamine 3.3.7 — ancrage des notifications (toasts / drops).
--   /drop notif dessus   (défaut) : les toasts s'empilent JUSTE AU-DESSUS du panneau
--                       compact, ancrés à lui (ils le suivent quand on le déplace
--                       ou change sa disposition) ; même largeur que le panneau
--                       (au moins 180 px, sinon largeur normale des toasts) ;
--   /drop notif dessous : juste en dessous, empilés vers le bas ;
--   /drop notif detache : position libre d'avant (déplaçable : /drop drops move).
-- Bascule automatique : « dessus » trop près du haut de l'écran → dessous
-- (et « dessous » trop près du bas → dessus). Mémorisé (SavedVariables).
-- L'éclat vers la case (3.3.5) part du toast où qu'il soit.
-- Panneau jamais construit : position libre.
local ADDON, ns = ...
local UI, W, P = ns.UI, ns.Window, ns.Panel
local H = UI._H
local RectOf, SizeOf = H.RectOf, H.SizeOf
local N = ns.N
local Nf = {}
ns.Notif = Nf

Nf.MODES = { dessus = true, dessous = true, detache = true }
Nf.ALIASES = { ["détache"] = "detache", ["detacher"] = "detache", ["détacher"] = "detache", libre = "detache", haut = "dessus", bas = "dessous" }
Nf.GAP, Nf.MIN_W, Nf.STACK = 2, 180, 3
Nf.DEFAULT_W = 260
local function DB() ns.db.ui = ns.db.ui or {} return ns.db.ui end
local function say(m) print("|cffffd100Dropamine|r : " .. m) end

function Nf.Mode() local m = DB().notifMode return Nf.MODES[m] and m or "dessus" end
local function Scale(f)
  local s = 1
  if f.GetEffectiveScale and UIParent and UIParent.GetEffectiveScale then
    local ok1, es = pcall(f.GetEffectiveScale, f)
    local ok2, us = pcall(UIParent.GetEffectiveScale, UIParent)
    if ok1 and ok2 and N(es) and N(us) and us > 0 then s = es / us end
  end
  return s
end
-- place nécessaire pour la pile (3 toasts)
function Nf.Need() return ((UI.DropFirstHeight and UI:DropFirstHeight()) or 56) * Nf.STACK + Nf.GAP * (Nf.STACK + 1) end
function Nf.Effective()
  local m = Nf.Mode()
  local f = W.frame
  if m == "detache" or not f then return "detache", (m ~= "detache") and "panneau absent" or nil end
  local l, r, t, b = RectOf(f)
  local sh = UIParent and UIParent.GetHeight and N(UIParent:GetHeight())
  if t and b and sh and sh > 0 then
    local s = Scale(f)
    if m == "dessus" and t * s + Nf.Need() > sh then return "dessous", "bascule : panneau près du haut de l'écran" end
    if m == "dessous" and b * s - Nf.Need() < 0 then return "dessus", "bascule : panneau près du bas de l'écran" end
  end
  return m
end
function Nf.Attached() return Nf.state and Nf.state.eff ~= "detache" end

local function RestoreFree(f)
  f:ClearAllPoints()
  local p = DB().dropsPos
  if p and p.x and p.y and pcall(f.SetPoint, f, p.point or "BOTTOMLEFT", UIParent, p.relativePoint or "BOTTOMLEFT", p.x, p.y) then return end
  f:ClearAllPoints()
  f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -80)
end

function Nf.Attach(why)
  local f = UI.dropsFrame
  if not f or Nf._busy then return nil end
  Nf._busy = true
  local eff, note = Nf.Effective()
  local was = Nf.state and Nf.state.eff
  Nf.state = { mode = Nf.Mode(), eff = eff, why = note, by = why }
  if eff == "detache" then
    f._osrsAttachW = nil
    if was and was ~= "detache" then RestoreFree(f) end
    f:SetSize(UI:DropWidth(), UI:DropFirstHeight())
  else
    local pw = SizeOf(W.frame)
    pw = pw and pw * Scale(W.frame) or 0
    f._osrsAttachW = (pw >= Nf.MIN_W) and math.floor(pw + 0.5) or Nf.DEFAULT_W
    f:ClearAllPoints()
    if eff == "dessus" then f:SetPoint("BOTTOMLEFT", W.frame, "TOPLEFT", 0, Nf.GAP)
    else f:SetPoint("TOPLEFT", W.frame, "BOTTOMLEFT", 0, -Nf.GAP) end
    f:SetSize(f._osrsAttachW, UI:DropFirstHeight())
  end
  pcall(UI.PlaceDropsHandle, UI)
  pcall(UI.PackDrops, UI)
  Nf._busy = nil
  return eff
end

-- sens d'empilement et largeur suivent l'ancrage
local baseDir = UI.DropDir
function UI:DropDir()
  local st = Nf.state
  if st and st.eff == "dessus" then return "haut" end
  if st and st.eff == "dessous" then return "bas" end
  return baseDir(self)
end
local baseWidth = UI.DropWidth
function UI:DropWidth()
  local f = self.dropsFrame
  if f and f._osrsAttachW and Nf.Attached() then return f._osrsAttachW end
  return baseWidth(self)
end

local baseBuildDrops = UI.BuildDrops
function UI:BuildDrops(...)
  local r = { baseBuildDrops(self, ...) }
  if self.dropsFrame and not Nf.state then Nf.Attach("construction") end
  return unpack(r)
end
-- recalcul de taille du support : ne touche ni l'ancrage ni la position libre
local baseLayout = UI.ApplyDropsLayout
function UI:ApplyDropsLayout(...)
  local saved = DB().dropsPos
  local r = { baseLayout(self, ...) }
  if Nf.Attached() then DB().dropsPos = saved Nf.Attach("taille") end
  return unpack(r)
end
-- /drop drops move : passe en position libre (sinon rien ne bougerait)
local baseMove = UI.ToggleDropsMove
function UI:ToggleDropsMove(...)
  if Nf.Mode() ~= "detache" and not (self.dropsFrame and self.dropsFrame._osrsMoving) then
    DB().notifMode = "detache"
    Nf.Attach("déplacement")
    say("notifications détachées du panneau (/drop notif dessus pour les rattacher).")
  end
  return baseMove(self, ...)
end
-- le panneau bouge / change de taille : on suit (et on bascule si besoin)
local baseSavePos = P.SavePos
function P.SavePos(...)
  local r = { baseSavePos(...) }
  Nf.Attach("panneau déplacé")
  return unpack(r)
end
local baseApplyMode = P.ApplyMode
function P.ApplyMode(...)
  local r = { baseApplyMode(...) }
  Nf.Attach("disposition")
  return unpack(r)
end
if ns.Layout and ns.Layout.Apply then
  local baseLA = ns.Layout.Apply
  function ns.Layout.Apply(...)
    local r = { baseLA(...) }
    Nf.Attach("disposition")
    return unpack(r)
  end
end
if ns.On then ns.On("PLAYER_ENTERING_WORLD", function() if UI.dropsFrame then Nf.Attach("connexion") end end) end

function Nf.Set(m)
  m = (m or ""):lower()
  m = Nf.ALIASES[m] or m
  if not Nf.MODES[m] then return nil end
  DB().notifMode = (m ~= "dessus") and m or nil
  if UI.BuildDrops then pcall(UI.BuildDrops, UI) end
  Nf.Attach("commande")
  return m
end
ns.SlashExt = ns.SlashExt or {}
ns.SlashExt.notif = function(rest)
  local m = Nf.Set((rest or ""):match("^%s*(%S*)"))
  local st = Nf.state or {}
  if m then
    say("notifications : " .. m .. ((st.eff and st.eff ~= m) and (" (" .. tostring(st.why) .. " → " .. st.eff .. ")") or ""))
  else
    say("notifications : " .. Nf.Mode() .. " (usage : /drop notif dessus|dessous|detache)")
  end
end
ns.HelpExt = ns.HelpExt or {}
ns.HelpExt[#ns.HelpExt + 1] = "/drop notif dessus|dessous|detache : toasts au-dessus du panneau (défaut), en dessous, ou position libre"
local baseDebug = W.DebugLines
W.DebugLines = function()
  local out = baseDebug()
  local st = Nf.state or {}
  out[#out + 1] = "  notifications : " .. Nf.Mode() .. " → " .. tostring(st.eff) .. (st.why and (" (" .. st.why .. ")") or "") .. ", largeur " .. tostring(UI.dropsFrame and UI:DropWidth())
  return out
end
