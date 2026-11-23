-- Dropamine 3.5.5 — ouverture du panneau PROTÉGÉE (bouton de minicarte, /drop,
-- clic sur un drop).
-- Contexte : chez un joueur avec AtlasLoot, le bouton de minicarte et /drop
-- restaient sans effet (alors que /drop reset répondait). Dropamine n'écrit
-- que 4 globales (DropamineDB, SLASH_DROPAMINE1/2, SlashCmdList.DROPAMINE),
-- n'embarque aucune librairie (ni LibStub, ni LibDBIcon, ni CallbackHandler)
-- et ne nomme que des cadres « Dropamine… » : pas de collision directe.
-- Le symptôme correspond à une erreur Lua dans la chaîne Toggle → Build → Show
-- (les erreurs sont masquées par défaut : rien ne s'affiche), ou à un panneau
-- ouvert mais invisible (opacité, échelle, position hors écran, strate).
-- Ici : chaque ouverture passe par xpcall ; une erreur est écrite UNE fois dans
-- le chat (avec l'endroit) au lieu d'être muette, puis le panneau est affiché
-- et remis en vue quand même. Rien d'autre n'est modifié.
-- 3.5.6 : cause trouvée. Le panneau était ancré par défaut sur CharacterFrame ;
-- tant que la fiche n'a jamais été ouverte (ou si un autre addon la déplace),
-- elle n'a pas de rectangle : le panneau était « affiché » (IsShown vrai) mais
-- sans position, donc invisible, et le clic suivant le « fermait ». Ici :
-- * tout ancrage qui ne vit pas sur UIParent est converti en coordonnées
--   d'UIParent (ou recentré si la position est introuvable / hors écran) ;
-- * un panneau « affiché » mais pas réellement visible compte comme fermé :
--   le clic l'OUVRE (et le remet en vue) au lieu de le fermer.
-- 3.6.0 : nouvelle enquête « AtlasLoot » (/drop et minicarte sans effet,
-- /drop reset répond). Chemins tracés :
--   /drop        → SlashCmdList.DROPAMINE → ns.UI:Toggle (Window.lua) →
--                  W.Toggle (SafeOpen ⊃ Panel ⊃ Window) → W.Build → f:Show →
--                  OnShow → UI:Refresh(true) + UI:ApplyView → W.Layout ;
--   minicarte    → OnClick → UI:Toggle → même chemin ;
--   /drop reset  → UI:ResetPositions → winPos = nil + W.PlaceDefault : NE
--                  montre rien, ne construit rien, ne touche ni l'opacité ni
--                  la strate. Qu'il « marche » prouve seulement que
--                  SlashCmdList.DROPAMINE est bien le nôtre (aucun vol de /drop).
-- Vérifié dans le code : aucune globale écrite hors DropamineDB /
-- SLASH_DROPAMINE1-2 / SlashCmdList.DROPAMINE (luac -l), aucune globale lue
-- qui ne soit pas une API du jeu, aucune librairie embarquée (LibStub,
-- LibDBIcon…), des noms de cadres tous « Dropamine… », le panneau hors de
-- UISpecialFrames et de UIPanelWindows (Échap / CloseAllWindows ne le
-- ferment pas), aucun ancrage vivant sur CharacterFrame depuis 3.5.6.
-- Points fragiles trouvés et corrigés ici :
--   1. PosGuard reposait à l'image suivante une position MÉMORISÉE hors écran
--      que SafeOpen venait d'abandonner (recentrage annulé aussitôt) : la
--      position mémorisée n'était effacée que si le rectangle était lisible,
--      et une ancre autre que TOPLEFT/BOTTOMLEFT n'était jamais vérifiée.
--      → SO.SavedPosOk projette la position (toute ancre, échelle comprise)
--        et une position hors écran est oubliée partout (PosGuard compris).
--   2. Panneau « affiché » mais presque transparent (fondu au repos, opacité
--      choisie très basse) : le clic le FERMAIT. → il est réveillé (100 %).
--   3. Fermeture par un tiers juste après l'ouverture (crochet d'un autre
--      addon sur CloseSpecialWindows / OnShow d'un de ses cadres…) : rien ne
--      le disait. → OnHide surveillé : rouvert une fois, et l'auteur (pile
--      d'appel) est écrit une seule fois dans le chat et dans /drop debug.
--   4. Toute ouverture réveille le panneau (fondu plein), même déjà construit.
local ADDON, ns = ...
local Tr = ns.L   -- 3.5.19 : textes traduits (Locales/)
local UI, W = ns.UI, ns.Window
if not (UI and W and W.Toggle and W.Show and W.Build) then return end

local SO = { stats = { opens = 0, errors = 0, healed = 0 }, said = {} }
ns.SafeOpen = SO

local function Say(msg)
  if ns.Print and pcall(ns.Print, msg) then return end
  local cf = _G.DEFAULT_CHAT_FRAME
  if cf and cf.AddMessage then pcall(cf.AddMessage, cf, "Dropamine: " .. tostring(msg)) end
end
local function Trace(err)
  local s = tostring(err)
  if type(_G.debugstack) == "function" then
    local ok, st = pcall(_G.debugstack, 2, 4, 0)
    if ok and type(st) == "string" and st ~= "" then s = s .. "\n" .. st end
  end
  return s
end
function SO.Report(where, err)
  SO.stats.errors = SO.stats.errors + 1
  local txt = tostring(err)
  local first = txt:match("^[^\n]*") or "?"
  SO.lastError = where .. " : " .. txt
  if SO.said[first] then return end
  SO.said[first] = true
  Say(Tr["|cffff4040erreur à l'ouverture du panneau|r ("] .. where .. ") : " .. first)
  Say(Tr["le panneau est affiché malgré tout si possible ; /drop debug donne le détail à transmettre."])
end
local function Guard(where, fn)
  local ok, r = xpcall(fn, Trace)
  if not ok then SO.Report(where, r) return nil, false end
  return r, true
end
local function Num(v) if type(v) == "number" and v == v then return v end return nil end
local function Get(f, m)
  if type(f) ~= "table" or type(f[m]) ~= "function" then return nil end
  local ok, a, b = pcall(f[m], f)
  if ok then return a, b end
  return nil
end

-- 3.6.0 : rectangle (unités d'UIParent) qu'aurait le panneau posé à « p ».
local function Frac(point)
  point = tostring(point or "CENTER")
  local fx = point:find("LEFT") and 0 or (point:find("RIGHT") and 1 or 0.5)
  local fy = point:find("BOTTOM") and 0 or (point:find("TOP") and 1 or 0.5)
  return fx, fy
end
SO._frac = Frac
function SO.ProjectRect(f, p)
  local up = _G.UIParent
  local uw, uh = Num(Get(up, "GetWidth")), Num(Get(up, "GetHeight"))
  local w, h = Num(Get(f, "GetWidth")), Num(Get(f, "GetHeight"))
  local x, y = p and Num(p.x), p and Num(p.y)
  if not (uw and uh and w and h and x and y) then return nil end
  local fes, ues = Num(Get(f, "GetEffectiveScale")) or 1, Num(Get(up, "GetEffectiveScale")) or 1
  local k = (ues > 0) and (fes / ues) or 1
  local rfx, rfy = Frac(p.relativePoint or p.point)
  local pfx, pfy = Frac(p.point)
  local px, py = uw * rfx + x * k, uh * rfy + y * k
  local l, b = px - pfx * w * k, py - pfy * h * k
  return l, l + w * k, b + h * k, b, uw, uh
end
-- Position mémorisée utilisable ? (au moins 24 px du panneau à l'écran)
function SO.SavedPosOk(f, p)
  if type(p) ~= "table" then return false end
  local l, r, t, b, uw, uh = SO.ProjectRect(f, p)
  if not l then return true end   -- pas mesurable (tests, cadre en construction) : pas de verdict
  return not ((r < 24) or (l > uw - 24) or (t < 24) or (b > uh - 24))
end
function SO.ForgetBadPos(f, why)
  local p = ns.db and ns.db.ui and ns.db.ui.winPos
  if p and not SO.SavedPosOk(f, p) then
    ns.db.ui.winPos = nil
    SO.stats.badPos = (SO.stats.badPos or 0) + 1
    SO.lastBadPos = why
    return true
  end
  return false
end

-- Panneau affiché mais invisible ? opacité, échelle, parent, strate, écran.
function SO.EnsureVisible(f)
  if type(f) ~= "table" or not f.IsShown then return false end
  local fixed = {}
  local up = _G.UIParent
  if up and Get(f, "GetParent") ~= up then
    if pcall(f.SetParent, f, up) then fixed[#fixed + 1] = "parent" end
  end
  local a = Num(Get(f, "GetAlpha"))
  -- (sauf si le joueur a choisi lui-même une opacité au repos quasi nulle)
  local P = ns.Panel
  local userOp = P and type(P.Opacity) == "function" and Num(select(2, pcall(P.Opacity)))
  if a and a < 0.05 and not (userOp and userOp < 5) then pcall(f.SetAlpha, f, 1) fixed[#fixed + 1] = "opacité" end
  local sc = Num(Get(f, "GetScale"))
  if sc and sc < 0.3 then pcall(f.SetScale, f, 1) fixed[#fixed + 1] = "échelle" end
  local st = Get(f, "GetFrameStrata")
  -- (MEDIUM = mode compact, voulu : on n'y touche pas)
  if st == "BACKGROUND" or st == "LOW" then pcall(f.SetFrameStrata, f, "HIGH") fixed[#fixed + 1] = "strate" end
  if f.Raise then pcall(f.Raise, f) end
  -- à l'écran (unités d'UIParent) ?
  local l, r, t, b = Num(Get(f, "GetLeft")), Num(Get(f, "GetRight")), Num(Get(f, "GetTop")), Num(Get(f, "GetBottom"))
  local uw, uh = Num(Get(up, "GetWidth")), Num(Get(up, "GetHeight"))
  local fes, ues = Num(Get(f, "GetEffectiveScale")) or 1, Num(Get(up, "GetEffectiveScale")) or 1
  local k = (ues > 0) and (fes / ues) or 1
  local off = false
  if l and r and t and b and uw and uh then
    off = (r * k < 24) or (l * k > uw - 24) or (t * k < 24) or (b * k > uh - 24)
  else
    -- 3.5.6 : ancré (GetNumPoints > 0) mais SANS rectangle = invisible
    off = true
  end
  -- 3.5.6 : ancre posée sur un autre cadre que UIParent (ex. CharacterFrame
  -- jamais ouverte, déplacée ou cachée par un autre addon) → coordonnées fixes
  if not off then
    local foreign = false
    local n = Num(Get(f, "GetNumPoints")) or 0
    for i = 1, n do
      local ok, _, rel = pcall(f.GetPoint, f, i)
      if ok and rel ~= nil and rel ~= up then foreign = true end
    end
    if foreign then
      pcall(f.ClearAllPoints, f)
      pcall(f.SetPoint, f, "TOPLEFT", up, "BOTTOMLEFT", l, t)
      fixed[#fixed + 1] = "ancrage"
    end
  end
  if off then
    -- 3.5.13 : d'abord la position MÉMORISÉE (un rectangle pas encore calculé
    -- juste après Show n'est pas une raison de l'oublier) ; le centre de
    -- l'écran seulement si elle est elle-même hors écran.
    local p = ns.db and ns.db.ui and ns.db.ui.winPos
    local px, py = p and Num(p.x), p and Num(p.y)
    local savedOk = false
    -- 3.6.0 : toute ancre est projetée (avant : seule TOPLEFT/BOTTOMLEFT
    -- était vérifiée, les autres étaient reposées même hors écran)
    if px and py and uw and uh and SO.SavedPosOk(f, p) then
      pcall(f.ClearAllPoints, f)
      savedOk = pcall(f.SetPoint, f, p.point or "CENTER", up, p.relativePoint or "CENTER", px, py) and true or false
    end
    if savedOk then
      fixed[#fixed + 1] = "position mémorisée reposée"
    else
      -- 3.6.0 : position mémorisée TOUJOURS oubliée ici, sinon PosGuard la
      -- reposait à l'image suivante (le recentrage était aussitôt annulé)
      if ns.db and ns.db.ui then ns.db.ui.winPos = nil end
      pcall(f.ClearAllPoints, f)
      pcall(f.SetPoint, f, "CENTER", up, "CENTER", 0, 0)
      fixed[#fixed + 1] = "position"
    end
  end
  -- 3.5.6 : toujours retenu à l'écran
  if f.SetClampedToScreen then pcall(f.SetClampedToScreen, f, true) end
  if #fixed > 0 then
    SO.stats.healed = SO.stats.healed + 1
    SO.lastHeal = table.concat(fixed, ", ")
    Say(Tr["panneau remis en vue ("] .. SO.lastHeal .. ").")
    -- 3.5.6 : la mise en page (taille compacte, grille) avait été calculée sans
    -- rectangle : on la refait maintenant que le panneau a une vraie place
    Guard("mise en page", function() return W.Layout() end)
    -- 3.5.13 : la mise en page refaite garde la taille mémorisée
    local Lm = ns.Layout
    if Lm and type(Lm.EnsureSaved) == "function" then pcall(Lm.EnsureSaved, "remise en vue") end
    local FL = ns.FirstLayout
    if FL and type(FL.Queue) == "function" then pcall(FL.Queue, "remise en vue") end
  end
  return true
end

-- après une ouverture (réussie ou non) : construit, affiché, rempli, visible
function SO.Ensure()
  local f = W.frame
  if not f then Guard("construction", function() return W.Build() end) f = W.frame end
  if not f then
    Say(Tr["|cffff4040le panneau n'a pas pu être construit|r : /drop debug donne le détail à transmettre."])
    return false
  end
  if not Get(f, "IsShown") then
    pcall(f.Show, f)
    if ns.db and ns.db.ui then ns.db.ui.panelOpen = true end
  end
  if not Get(f, "IsShown") then
    Say(Tr["|cffff4040le panneau refuse de s'afficher|r : /drop debug donne le détail à transmettre."])
    return false
  end
  -- contenu absent (l'OnShow a échoué en silence) : mise en page relancée, erreur montrée
  local e = UI.embed
  if not (e and Get(e, "IsShown")) then
    Guard("rafraîchissement", function() return UI:Refresh(true) end)
    Guard("mise en page", function() return W.Layout() end)
    -- 3.5.13 : la mise en page refaite garde la taille mémorisée
    local Lm = ns.Layout
    if Lm and type(Lm.EnsureSaved) == "function" then pcall(Lm.EnsureSaved, "remise en vue") end
  end
  SO.EnsureVisible(f)
  return true
end

-- 3.5.6 : réellement visible à l'écran ? (affiché, parents affichés, rectangle)
function SO.OnScreen(f)
  if type(f) ~= "table" then return false end
  if not Get(f, "IsShown") or not Get(f, "IsVisible") then return false end
  local l, t = Num(Get(f, "GetLeft")), Num(Get(f, "GetTop"))
  local w, h = Num(Get(f, "GetWidth")), Num(Get(f, "GetHeight"))
  return (l and t and w and h and w > 1 and h > 1) and true or false
end

-- 3.6.0 : opacité réellement vue (fondu au repos compris)
function SO.SeenAlpha(f)
  local a = Num(Get(f, "GetEffectiveAlpha")) or Num(Get(f, "GetAlpha")) or 1
  return a
end
SO.GHOST_ALPHA = 0.10
function SO.Wake(why)
  local P = ns.Panel
  if P and type(P.Wake) == "function" then pcall(P.Wake, why or "ouverture") end
end
-- Fermeture par un tiers juste après une ouverture : rouverte une fois.
SO.STEAL_WINDOW = 1.0
local function NowT() return (type(_G.GetTime) == "function" and _G.GetTime()) or 0 end
function SO.MarkOpen() SO._openAt, SO._reopened = NowT(), nil end
function SO.OnHide(f)
  if SO._selfHide then return end
  if not SO._openAt or NowT() - SO._openAt > SO.STEAL_WINDOW then return end
  if not (ns.db and ns.db.ui and ns.db.ui.panelOpen) then return end
  SO.stats.stolen = (SO.stats.stolen or 0) + 1
  local who = "?"
  if type(_G.debugstack) == "function" then
    local ok, st = pcall(_G.debugstack, 2, 6, 0)
    if ok and type(st) == "string" then
      -- première ligne qui ne vient pas de Dropamine = l'auteur probable
      for line in st:gmatch("[^\n]+") do
        if not line:find("Dropamine", 1, true) and not line:find("%[C%]") then who = line break end
      end
      SO.lastStealStack = st
    end
  end
  SO.lastSteal = who
  if not SO.said["steal:" .. who] then
    SO.said["steal:" .. who] = true
    Say(Tr["le panneau a été refermé par un autre addon juste après l'ouverture ; il est rouvert. Origine : "] .. who)
  end
  if SO._reopened then return end
  SO._reopened = true
  local function again() if not W.IsShown() then pcall(f.Show, f) SO.Ensure() end end
  if type(_G.C_Timer) == "table" and type(_G.C_Timer.After) == "function" then _G.C_Timer.After(0, again) else again() end
end
function SO.HookFrame(f)
  if type(f) ~= "table" or f._soHooked or not f.HookScript then return end
  f._soHooked = true
  pcall(f.HookScript, f, "OnHide", function(fr) SO.OnHide(fr) end)
end

local baseToggle, baseShow, baseHide = W.Toggle, W.Show, W.Hide
function W.Toggle(...)
  SO.stats.opens = SO.stats.opens + 1
  local f = W.frame
  -- affiché mais invisible (sans position) : on l'ouvre, on ne le ferme pas
  if f and W.IsShown() and not SO.OnScreen(f) then
    SO.stats.ghost = (SO.stats.ghost or 0) + 1
    if ns.db and ns.db.ui then ns.db.ui.panelOpen = true end
    SO.Ensure()
    SO.Wake("ouverture")
    return W.IsShown()
  end
  -- 3.6.0 : affiché, à l'écran, mais presque transparent → réveillé, pas fermé
  if f and W.IsShown() and SO.SeenAlpha(f) < SO.GHOST_ALPHA then
    SO.stats.faded = (SO.stats.faded or 0) + 1
    SO.Wake("ouverture")
    return W.IsShown()
  end
  local wasShown = W.IsShown()
  if wasShown then
    SO._selfHide = true
    Guard("fermeture", function() return baseToggle() end)
    SO._selfHide = nil
    return W.IsShown()
  end
  SO.MarkOpen()
  Guard("ouverture", function() return baseToggle() end)
  SO.HookFrame(W.frame)
  SO.Ensure()
  SO.Wake("ouverture")
  return W.IsShown()
end
function W.Show(...)
  SO.stats.opens = SO.stats.opens + 1
  SO.MarkOpen()
  Guard("ouverture", function() return baseShow() end)
  SO.HookFrame(W.frame)
  SO.Ensure()
  SO.Wake("ouverture")
  return true
end
function W.Hide(...)
  SO._selfHide = true
  local ok, r = pcall(baseHide, ...)
  SO._selfHide = nil
  SO._openAt = nil
  if not ok then SO.Report("fermeture", r) end
  return r
end

ns.DebugExt = ns.DebugExt or {}
ns.DebugExt[#ns.DebugExt + 1] = function()
  local f = W.frame
  local where = "—"
  if f then
    local ok, p, rel, rp, x, y = pcall(f.GetPoint, f, 1)
    local rn = rel and rel.GetName and select(2, pcall(rel.GetName, rel)) or (rel and "?" or "nil")
    if ok and p then where = string.format("%s→%s:%s %.0f,%.0f", tostring(p), tostring(rn), tostring(rp), Num(x) or 0, Num(y) or 0) end
  end
  local L = { string.format("— Ouverture protégée (3.5.6) — ouvertures %d, erreurs %d, remises en vue %d%s ; invisibles rouverts %d ; à l'écran %s ; ancre %s",
    SO.stats.opens, SO.stats.errors, SO.stats.healed, SO.lastHeal and (" (dernière : " .. SO.lastHeal .. ")") or "",
    SO.stats.ghost or 0, f and (SO.OnScreen(f) and "oui" or "non") or "—", where) }
  if SO.lastError then L[#L + 1] = "  dernière erreur : " .. SO.lastError end
  L[#L + 1] = string.format("  3.6.0 : réveillé au lieu de fermé %d, position hors écran oubliée %d%s, refermé par un tiers %d%s",
    SO.stats.faded or 0, SO.stats.badPos or 0, SO.lastBadPos and (" (" .. SO.lastBadPos .. ")") or "",
    SO.stats.stolen or 0, SO.lastSteal and (" — origine : " .. SO.lastSteal) or "")
  return L
end
