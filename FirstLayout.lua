-- Dropamine — 3.3.15 : première ouverture sans ascenseur.
-- Au tout premier affichage (nouveau personnage, SavedVariables vides), la
-- grille était posée avant que le panneau ait sa taille finale / avant le
-- chargement des métiers : elle « débordait » et un ascenseur apparaissait
-- jusqu'au premier redimensionnement. Désormais :
--   1. passe de mise en page complète à PLAYER_LOGIN, PLAYER_ENTERING_WORLD,
--      SKILL_LINES_CHANGED et à l'affichage, puis À NOUVEAU à la frame suivante
--      (C_Timer.After(0)) quand les tailles sont posées ;
--   2. l'ascenseur du panneau principal n'est JAMAIS montré : un débordement
--      déclenche une nouvelle passe (bornée), la molette reste un secours.
-- Événementiel uniquement, aucun OnUpdate. Hors combat (reporté sinon).
local ADDON, ns = ...
local UI = ns.UI
if not UI then return end
local FL = {}
ns.FirstLayout = FL
FL.stats = { passes = 0, queued = 0, overflowRetries = 0, barsHidden = 0, lastReason = nil }
FL.MAX_RETRIES = 3

local function After0(fn)
  if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(0, fn) else fn() end
end

function FL.Pass(reason)
  if ns.InCombat and ns.InCombat() then
    if ns.AfterCombat then ns.AfterCombat("osrs-firstlayout", function() FL.Pass(reason) end) end
    return false
  end
  FL.stats.passes = FL.stats.passes + 1
  FL.stats.lastReason = reason
  local wrap = UI.embed
  local snap = (wrap and wrap._snap) or UI.snapshot
  if not snap and UI.Refresh then
    pcall(UI.Refresh, UI, true)
    snap = (wrap and wrap._snap) or UI.snapshot
  end
  if wrap and snap and wrap.IsShown and wrap:IsShown() and UI.LayoutGrid then
    pcall(UI.LayoutGrid, UI, wrap, snap)
  end
  if UI.soloGrid and UI.frame and UI.frame.IsShown and UI.frame:IsShown() and snap and UI.LayoutGrid then
    pcall(UI.LayoutGrid, UI, UI.soloGrid, snap)
  end
  return true
end

function FL.Queue(reason)
  FL.stats.queued = FL.stats.queued + 1
  local now = (type(GetTime) == "function" and GetTime()) or 0
  if FL._pending and (now - FL._pending) < 1 then return end   -- déjà en file (garde-fou : 1 s)
  FL._pending = now
  After0(function()
    FL._pending = nil
    FL.Pass(reason .. " (frame suivante)")
  end)
end

function FL.Full(reason)
  FL.Pass(reason)
  FL.Queue(reason)
end

-- (2) Jamais d'ascenseur sur le panneau principal.
local baseBar = UI.UpdateGridScrollBar
function UI:UpdateGridScrollBar(wrap)
  local L = wrap and wrap._layout
  if not L then return end
  local sb = self.EnsureGridScrollBar and self:EnsureGridScrollBar(wrap)
  if sb and sb.Hide then sb:Hide() end
  if L.overflow then
    FL.stats.barsHidden = FL.stats.barsHidden + 1
    if (FL._retries or 0) < FL.MAX_RETRIES then
      FL._retries = (FL._retries or 0) + 1
      FL.stats.overflowRetries = FL.stats.overflowRetries + 1
      FL.Queue("débordement")
    end
    if wrap.EnableMouseWheel then pcall(wrap.EnableMouseWheel, wrap, true) end   -- secours discret
    self.gridScroll = string.format("débordement %.0f : nouvelle mise en page, pas de barre", wrap._maxScroll or 0)
  else
    FL._retries = 0
    if wrap.EnableMouseWheel then pcall(wrap.EnableMouseWheel, wrap, false) end
    self.gridScroll = "contenu tient : pas de barre"
  end
end
FL._baseBar = baseBar

-- (1) Passes complètes aux bons moments.
if ns.On then
  ns.On("PLAYER_LOGIN", function() FL.Full("PLAYER_LOGIN") end)
  ns.On("PLAYER_ENTERING_WORLD", function() FL.Full("PLAYER_ENTERING_WORLD") end)
  ns.On("SKILL_LINES_CHANGED", function() FL.Queue("SKILL_LINES_CHANGED") end)
end
-- à l'affichage de la grille (première ouverture du panneau)
function FL.HookShow(wrap)
  if not wrap or wrap._flShowHooked or not wrap.HookScript then return end
  wrap._flShowHooked = true
  pcall(wrap.HookScript, wrap, "OnShow", function() FL.Full("affichage") end)
end
local baseLayout = UI.LayoutGrid
function UI:LayoutGrid(wrap, ...)
  if wrap and wrap == self.embed and not wrap._flShowHooked then FL.HookShow(wrap) end
  return baseLayout(self, wrap, ...)
end

function FL.DebugLine()
  local s = FL.stats
  return string.format("— Première mise en page (3.3.15) — passes %d, en file %d, débordements repris %d, barre cachée %d (dernière : %s)",
    s.passes, s.queued, s.overflowRetries, s.barsHidden, tostring(s.lastReason))
end
ns.DebugExt = ns.DebugExt or {}
ns.DebugExt[#ns.DebugExt + 1] = function() return { FL.DebugLine() } end
