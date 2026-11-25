-- Dropamine 3.10.0 : aiguille GPS dans la goutte.
-- Tant qu'un point posé par Dropamine (Alt+clic SkillUp) est le point natif du jeu, la goutte
-- devient une aiguille qui pointe vers lui (vert devant, jaune sur le côté, rouge derrière).
-- Pas d'aiguille si TomTom ou Shortest Path est chargé (ils ont la leur), ni sans orientation
-- (donjon). À l'arrivée (~10 m) : toast « Arrivé » et le point est retiré. Alt+clic sur la goutte : retirer.
local ADDON, ns = ...
local Tr = ns.L
local Nd = {}
ns.Needle = Nd

Nd.ARRIVE = 10                 -- mètres (yards)
Nd.MAX_AGE = 30 * 60           -- garde-fou : 30 min
Nd.TEXTURE = "Interface\\Minimap\\MinimapArrow"
Nd.COLORS = { ahead = { 0.35, 1, 0.35 }, side = { 1, 0.85, 0.2 }, behind = { 1, 0.3, 0.25 } }

local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c = pcall(fn, ...)
  if ok then return a, b, c end
end
local function Num(v) if type(v) == "number" and v == v and not (ns.IsSecret and ns.IsSecret(v)) then return v end end
local function Now() return Call(_G.GetTime) or 0 end

-- Réglage (dans la liste des états de la goutte)
Nd.OPTION = { type = "check", key = "needle", label = "Aiguille GPS dans la goutte", default = true, cmd = "Réglage de ce panneau",
  help = "Quand un point posé par Dropamine (Alt+clic SkillUp) est actif : la goutte pointe vers lui. Pas d'aiguille avec TomTom ou Shortest Path." }
local O = ns.Options
if O then
  O.EXTRA_HOME = O.EXTRA_HOME or {}
  O.EXTRA[#O.EXTRA + 1] = Nd.OPTION
  O.EXTRA_HOME.needle = "prof"
  if O.GROUPS and O.GROUPS.grpSkillUp then
    local items = O.GROUPS.grpSkillUp.items
    items[#items + 1] = { "needle", "Aiguille GPS dans la goutte" }
  end
end

-- Une autre flèche est déjà là : on s'efface
function Nd.OtherArrow()
  if type(rawget(_G, "TomTom")) == "table" then return true end
  local sp = rawget(_G, "ShortestPathForever")
  if type(sp) == "table" then return true end
  return false
end

-- Cap relatif (radians, sens anti-horaire, 0 = devant) et distance, en coordonnées du monde :
-- X vers le nord, Y vers l'ouest ; l'orientation du joueur vaut 0 au nord, croît vers l'ouest.
function Nd.Bearing(px, py, tx, ty, facing)
  local dx, dy = tx - px, ty - py
  local dist = math.sqrt(dx * dx + dy * dy)
  local bearing = math.atan2 and math.atan2(dy, dx) or math.atan(dy, dx)
  local rel = bearing - facing
  rel = (rel + math.pi) % (2 * math.pi) - math.pi
  return rel, dist
end
function Nd.ColorFor(rel)
  local a = math.abs(rel)
  if a <= math.rad(30) then return Nd.COLORS.ahead, "ahead" end
  if a <= math.rad(100) then return Nd.COLORS.side, "side" end
  return Nd.COLORS.behind, "behind"
end

-- Point suivi ----------------------------------------------------------------------
Nd.target = nil   -- { map, x, y, label, at }
local function UserWaypoint()
  local M = _G.C_Map
  if not (M and Call(M.HasUserWaypoint)) then return nil end
  local p = Call(M.GetUserWaypoint)
  if type(p) ~= "table" or not p.uiMapID or not p.position then return nil end
  local x, y = Num(p.position.x), Num(p.position.y)
  if not (x and y) then return nil end
  return p.uiMapID, x, y, p
end
-- À appeler juste après que Dropamine a fait poser un point (Alt+clic SkillUp)
function Nd.Track(label)
  local map, x, y = UserWaypoint()
  if not map then Nd.target = nil return false end
  Nd.target = { map = map, x = x, y = y, label = label, at = Now() }
  local S = ns.Slot
  if S and S.NeedsDriver and S.StartDriver and S.NeedsDriver() then pcall(S.StartDriver) end
  if S and S.ApplyTotal then pcall(S.ApplyTotal) end
  return true
end
function Nd.Clear(silent)
  local tg = Nd.target
  Nd.target = nil
  local M = _G.C_Map
  if tg and M and M.ClearUserWaypoint then
    local map, x, y = UserWaypoint()
    if map == tg.map and x and math.abs(x - tg.x) < 0.001 and math.abs(y - tg.y) < 0.001 then Call(M.ClearUserWaypoint) end
  end
  if tg and not silent then ns.Print(Tr["Point retiré."]) end
  local S = ns.Slot
  if S and S.ApplyTotal then pcall(S.ApplyTotal) end
  return tg ~= nil
end

-- État courant : nil (pas d'aiguille) ou { rel, dist, color, label }
function Nd.State()
  local tg = Nd.target
  if not tg or not ns.Opt("needle") or Nd.OtherArrow() then return nil end
  -- le point a été retiré ou remplacé par le joueur : on arrête de le suivre
  local map, x, y, point = UserWaypoint()
  if map ~= tg.map or not x or math.abs(x - tg.x) > 0.001 or math.abs(y - tg.y) > 0.001 then Nd.target = nil return nil end
  if Now() - (tg.at or 0) > Nd.MAX_AGE then Nd.target = nil return nil end
  local M = _G.C_Map
  local facing = Num(Call(_G.GetPlayerFacing))
  if not facing then return nil end                       -- donjon / orientation cachée
  local pmap = Call(M.GetBestMapForUnit, "player")
  local ppos = pmap and Call(M.GetPlayerMapPosition, pmap, "player")
  if not ppos then return nil end
  local pc, pw = Call(M.GetWorldPosFromMapPos, pmap, ppos)
  local tc, tw = Call(M.GetWorldPosFromMapPos, tg.map, point.position)
  if not (pc and tc and pw and tw) then return nil end
  if pc ~= tc then return { other = true, label = tg.label } end
  local px, py, tx, ty = Num(pw.x), Num(pw.y), Num(tw.x), Num(tw.y)
  if not (px and py and tx and ty) then return nil end
  local rel, dist = Nd.Bearing(px, py, tx, ty, facing)
  local color, side = Nd.ColorFor(rel)
  return { rel = rel, dist = dist, color = color, side = side, label = tg.label }
end
function Nd.Active()
  local st = Nd.State()
  return st ~= nil and not st.other
end

-- Arrivée : toast puis point retiré
function Nd.CheckArrival(st)
  if not (st and st.dist and st.dist <= Nd.ARRIVE) then return false end
  local label = st.label
  Nd.Clear(true)
  local ui = ns.UI
  if ui and ui.SpawnDrop then
    pcall(ui.SpawnDrop, ui, "Interface\\Icons\\INV_Misc_Map_01", Tr["Arrivé"], label or Tr["Point atteint"], nil, nil, nil, { kind = "qol" })
  end
  return true
end

-- Dessin dans la goutte -------------------------------------------------------------
function Nd.Hide(t)
  local tex = t and t._needle
  if tex and tex.Hide then tex:Hide() end
end
function Nd.Apply(t)
  local S = ns.Slot
  if not (t and S and S.PlaceIconClip) then return nil end
  local st = Nd.State()
  if not st or st.other then Nd.Hide(t) return nil end
  if Nd.CheckArrival(st) then Nd.Hide(t) return nil end
  local clip, content, w, h = S.PlaceIconClip(t)
  local parent = content or clip
  if not parent or type(parent.CreateTexture) ~= "function" then return nil end
  local tex = t._needle
  if not tex then
    tex = parent:CreateTexture(nil, "OVERLAY", nil, 6)
    if not tex then return nil end
    pcall(tex.SetTexture, tex, Nd.TEXTURE)
    t._needle = tex
  elseif tex.GetParent and tex:GetParent() ~= parent and tex.SetParent then
    pcall(tex.SetParent, tex, parent)
  end
  w, h = w or 16, h or 16
  local side = math.max(8, math.min(w, h) - 2)
  if tex.ClearAllPoints then tex:ClearAllPoints() end
  if tex.SetSize then tex:SetSize(side, side) end
  if tex.SetPoint then tex:SetPoint("CENTER", parent, "CENTER", 0, 0) end
  if tex.SetRotation then pcall(tex.SetRotation, tex, st.rel) end
  local c = st.color
  if tex.SetVertexColor then pcall(tex.SetVertexColor, tex, c[1], c[2], c[3], 1) end
  if tex.Show then tex:Show() end
  if t.icon and t.icon.Hide then t.icon:Hide() end
  return tex
end

-- Infobulle de la goutte en mode aiguille
function Nd.FillTip(tt)
  local st = Nd.State()
  if not (tt and st) then return false end
  pcall(tt.SetText, tt, Tr["Point en cours"], 1, 0.82, 0)
  if st.label then pcall(tt.AddLine, tt, tostring(st.label), 1, 1, 1, true) end
  if st.other then
    pcall(tt.AddLine, tt, Tr["Sur un autre continent."], 0.8, 0.8, 0.8, true)
  elseif st.dist then
    pcall(tt.AddLine, tt, string.format(Tr["Distance : %d m"], math.floor(st.dist + 0.5)), 0.9, 0.9, 0.9, true)
  end
  pcall(tt.AddLine, tt, Tr["Alt+clic : retirer le point"], 0.6, 0.6, 0.6, true)
  return true
end
