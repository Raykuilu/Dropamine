-- Dropamine — 3.3.16 : la position du panneau ne saute plus.
-- Bug : à l'entrée dans le mode édition du jeu, le panneau revenait à sa place
-- par défaut. Désormais :
--   * le mode édition (entrée / sortie / mise en page appliquée) ne ré-ancre
--     JAMAIS par défaut : la position mémorisée est reposée aussitôt puis à la
--     frame suivante ;
--   * tout ClearAllPoints / SetPoint venu d'ailleurs sur NOTRE panneau est
--     corrigé à la frame suivante (hooksecurefunc post-appel, notre cadre) ;
--   * seul « Revenir à la position par défaut » (UI:ResetPositions) remet la
--     place par défaut.
-- Pendant un glisser du panneau, rien n'est corrigé. Aucun OnUpdate.
local ADDON, ns = ...
local UI, W = ns.UI, ns.Window
if not (UI and W) then return end
local PG = {}
ns.PosGuard = PG
PG.stats = { checks = 0, reapplied = 0, queued = 0 }
local function N(v) return (ns.N and ns.N(v)) or tonumber(v) end
local function DB() return ns.db and ns.db.ui or nil end
local function After0(fn) if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(0, fn) else fn() end end

-- position voulue = celle mémorisée (aucune → on ne touche à rien)
function PG.Saved()
  local d = DB()
  local p = d and d.winPos
  if p and N(p.x) and N(p.y) then return p end
  return nil
end
local function close(a, b) return math.abs((N(a) or 0) - (N(b) or 0)) < 1 end
function PG.Matches(f, p)
  local ok, point, rel, relPoint, x, y = pcall(f.GetPoint, f, 1)
  if not ok or not point then return false end
  if rel ~= nil and rel ~= UIParent then return false end
  return point == (p.point or "CENTER") and relPoint == (p.relativePoint or p.point or "CENTER") and close(x, p.x) and close(y, p.y)
end
function PG.Check(why)
  PG.stats.checks = PG.stats.checks + 1
  local f = W.frame
  local p = PG.Saved()
  if not (f and p) or PG._busy then return false end
  if f._osrsMovingNow or (ns.EditMode and ns.EditMode._moving) or (ns.Theme and ns.Theme.moving) then return false end
  if PG.Matches(f, p) then return false end
  -- 3.6.0 : jamais reposer une position mémorisée hors écran (elle est oubliée)
  local SO = ns.SafeOpen
  if SO and SO.SavedPosOk and not SO.SavedPosOk(f, p) then
    if SO.ForgetBadPos then SO.ForgetBadPos(f, "PosGuard " .. tostring(why)) end
    PG.stats.refused = (PG.stats.refused or 0) + 1
    return false
  end
  PG._busy = true
  pcall(f.ClearAllPoints, f)
  pcall(f.SetPoint, f, p.point or "CENTER", UIParent, p.relativePoint or p.point or "CENTER", p.x, p.y)
  PG._busy = nil
  PG.stats.reapplied = PG.stats.reapplied + 1
  PG.lastWhy = why
  return true
end
function PG.Queue(why)
  PG.stats.queued = PG.stats.queued + 1
  if PG._pending then return end
  PG._pending = true
  After0(function() PG._pending = nil PG.Check(why) end)
end
function PG.Now(why) PG.Check(why) PG.Queue(why) end

-- crochets sur NOTRE panneau (post-appel, sans souillure)
function PG.HookFrame(f)
  if not f or f._pgHooked or type(hooksecurefunc) ~= "function" then return end
  f._pgHooked = true
  for _, m in ipairs({ "ClearAllPoints", "SetPoint", "SetAllPoints" }) do
    if type(f[m]) == "function" then pcall(hooksecurefunc, f, m, function() if not PG._busy then PG.Queue(m) end end) end
  end
  -- marqueur de glisser (le panneau a ses propres OnDragStart / OnDragStop)
  if f.HookScript then
    f:HookScript("OnDragStart", function(fr) fr._osrsMovingNow = true end)
    f:HookScript("OnDragStop", function(fr) fr._osrsMovingNow = nil end)
  end
  pcall(f.SetDontSavePosition, f, true)   -- pas de position « client » concurrente
end

-- mode édition : entrée / sortie / mise en page
for _, m in ipairs({ "EnterEditMode", "ExitEditMode" }) do
  local base = UI[m]
  if base then
    UI[m] = function(self, ...)
      local r = { base(self, ...) }
      PG.Now(m)
      if ns.FirstLayout and ns.FirstLayout.Queue then ns.FirstLayout.Queue("mode édition") end
      return unpack(r)
    end
  end
end
if ns.EditMode then
  for _, m in ipairs({ "Enter", "Exit" }) do
    local base = ns.EditMode[m]
    if base then ns.EditMode[m] = function(...) local r = { base(...) } PG.Now("calque " .. m) return unpack(r) end end
  end
end
if ns.On then
  ns.On("EDIT_MODE_LAYOUTS_UPDATED", function() PG.Now("EDIT_MODE_LAYOUTS_UPDATED") end)
  ns.On("PLAYER_ENTERING_WORLD", function() PG.HookFrame(W.frame) PG.Queue("entrée dans le monde") end)
end
-- le panneau est créé à la demande : crochets dès sa création
if W.Build then
  local baseBuild = W.Build
  function W.Build(...)
    local f = baseBuild(...)
    PG.HookFrame(f or W.frame)
    return f
  end
end
if W.frame then PG.HookFrame(W.frame) end

function PG.DebugLine()
  local s = PG.stats
  return string.format("— Position du panneau (3.3.16) — vérifs %d, reposée %d fois (dernière : %s), mémorisée %s",
    s.checks, s.reapplied, tostring(PG.lastWhy), PG.Saved() and "oui" or "non (place par défaut)")
end
ns.DebugExt = ns.DebugExt or {}
ns.DebugExt[#ns.DebugExt + 1] = function() return { PG.DebugLine() } end
