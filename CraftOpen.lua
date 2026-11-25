-- Dropamine 3.3.13 : toasts « N × Recette possibles » CLIQUABLES.
-- Clic gauche : ouvre la fenêtre du métier et sélectionne la recette.
-- Sans souillure : ouvrir un métier = lancer son sort, fonction PROTÉGÉE pour
-- un addon (CastSpellByName). On passe donc par un bouton sécurisé à nous
-- (SecureActionButtonTemplate, type = spell), posé sur le toast au survol, HORS
-- combat seulement, à coordonnées absolues (jamais ancré au toast : le toast
-- reste un cadre ordinaire). La sélection de la recette se fait ensuite avec
-- les API publiques (GetTradeSkillInfo / SelectTradeSkill, GetCraftInfo /
-- SelectCraft) et les fonctions d'affichage de la fenêtre Blizzard.
-- En combat : la recette est mise en attente ; elle est sélectionnée dès que la
-- fenêtre du métier s'ouvre, et un rappel s'affiche à la fin du combat.
-- 3.5.5 : clic réellement actif (une seule phase de clic inscrite, celle qui
-- agit selon ActionButtonUseKeyDown), sort décidé au clic (jamais relancé sur
-- une fenêtre ouverte, anti double-lancer), sélection par un travail unique
-- et borné (déplie les catégories, puis remet les filtres, puis abandonne).
-- Cases de métier : clic-ouverture réactivé (option « Clic : ouvrir le métier »).
local _, ns = ...
local Tr = ns.L   -- 3.5.19 : textes traduits (Locales/)
local CO = {}
ns.CraftOpen = CO
local UI = ns.UI

-- sorts des métiers (identifiants Classic ; noms FR / EN en repli)
CO.SPELLS = {
  firstaid = { 3273, "Secourisme", "First Aid" }, cooking = { 2550, "Cuisine", "Cooking" },
  tailoring = { 3908, "Couture", "Tailoring" }, leatherworking = { 2108, "Travail du cuir", "Leatherworking" },
  blacksmithing = { 2018, "Forge", "Blacksmithing" }, alchemy = { 2259, "Alchimie", "Alchemy" },
  engineering = { 4036, "Ingénierie", "Engineering" }, enchanting = { 7411, "Enchantement", "Enchanting" },
  mining = { 2656, "Fondre", "Smelting" },
}
CO.CRAFT_UI = { enchanting = true }   -- fenêtre « Craft » (enchantement) au lieu de « TradeSkill »
CO.HINT = "Clic : ouvrir la recette"
CO.stats = { armed = 0, selected = 0, queued = 0 }

local function N(v) return ns.N and ns.N(v) or tonumber(v) end
local function InCombat() return ns.InCombat and ns.InCombat() or false end
local function Norm(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()) end
local function Now()
  if type(_G.GetTime) == "function" then
    local ok, t = pcall(_G.GetTime)
    if ok and type(t) == "number" then return t end
  end
  return 0
end

-- 3.5.5 : réglages du clic « ouvrir la recette / le métier »
CO.WANT_TTL = 4       -- s : délai laissé à la fenêtre pour s'ouvrir après le clic
CO.QUEUE_TTL = 120    -- s : recette retenue pendant un combat (ouverture manuelle ensuite)
CO.SETTLE = 0.12      -- s : la fenêtre doit être affichée depuis ce délai (sa sélection native passe d'abord)
CO.DEBOUNCE = 0.6     -- s : jamais deux lancers du sort de métier aussi rapprochés (ouvrir puis refermer)
CO.FILTER_WAIT = 0.5  -- s : après remise à zéro des filtres, dernier délai avant d'abandonner

-- Clics sécurisés : le gabarit des clients Classic récents (moteur 10.x)
-- n'agit qu'à l'ENFONCEMENT quand ActionButtonUseKeyDown = 1 (réglage par
-- défaut), et qu'au relâchement sinon. Inscrire seulement « LeftButtonUp »
-- rendait le clic muet (cause probable de « Clic : ouvrir la recette » sans
-- effet). On inscrit les deux phases (correctif habituel), on aligne
-- l'attribut useOnKeyDown sur ce réglage, et le sort n'est posé QUE pour la
-- phase qui agit (vidé pour l'autre) : une seule action par clic, jamais deux
-- (deux lancers = la fenêtre s'ouvre puis se referme aussitôt), quel que soit
-- le gabarit du client. Les actions non sécurisées (fermer le toast, objectif,
-- partage, sélection de case) ne se font qu'au relâchement.
function CO.KeyDownMode()
  if type(_G.GetCVarBool) == "function" then
    local ok, v = pcall(_G.GetCVarBool, "ActionButtonUseKeyDown")
    if ok then return v and true or false end
  end
  if type(_G.GetCVar) == "function" then
    local ok, v = pcall(_G.GetCVar, "ActionButtonUseKeyDown")
    if ok then return v == "1" end
  end
  return false
end
function CO.RegisterClicks(b)
  if not (b and b.RegisterForClicks) or InCombat() then return end
  local down = CO.KeyDownMode()
  if b._coDown == down then return end
  if pcall(b.RegisterForClicks, b, "LeftButtonDown", "LeftButtonUp", "RightButtonUp") then
    b._coDown = down
    if type(b.SetAttribute) == "function" then pcall(b.SetAttribute, b, "useOnKeyDown", down) end
  end
end
-- cette phase du clic (enfoncement / relâchement) est-elle celle qui agit ?
function CO.ActingPhase(down)
  return (down and true or false) == CO.KeyDownMode()
end
-- attribut de sort du bouton (hors combat seulement : interdit sinon)
function CO.SetSpell(b, name)
  if not (b and type(b.SetAttribute) == "function") or InCombat() then return false end
  b:SetAttribute("type1", name and "spell" or nil)
  b:SetAttribute("spell1", name or nil)
  return true
end
-- au moment du clic : lancer le sort seulement si la fenêtre n'est pas déjà
-- ouverte (le relancer la fermerait) et pas deux fois de suite
function CO.PrepareCast(b, skill)
  if InCombat() then return false end
  local name = skill and CO.SpellName(skill)
  local t = Now()
  if not name or CO.WindowOpenFor(skill) or (t - (CO._lastCast or -100)) < CO.DEBOUNCE then
    CO.SetSpell(b, nil)
    return false
  end
  CO.SetSpell(b, name)
  CO._lastCast = t
  CO._opened = skill   -- 3.8.2 : métier ouvert par la case (le nom affiché n'est pas toujours lisible)
  CO._pending = { skill = skill, t = t }
  CO.stats.casts = (CO.stats.casts or 0) + 1
  return true
end
-- une fenêtre de métier (n'importe laquelle) est-elle affichée ?
function CO.AnyWindowShown(skill)
  local function on(f) return type(f) == "table" and f.IsShown and f:IsShown() and true or false end
  if CO.CRAFT_UI[skill] then return on(_G.CraftFrame) end
  return on(rawget(_G, "ProfessionsFrame")) or on(_G.TradeSkillFrame)
end
-- 2e clic sur la case : fermer si la fenêtre montre ce métier, ou si c'est ce métier que la case a ouvert
-- (Pêche, Cuisine : le nom lu dans la fenêtre ne correspond pas toujours, la fenêtre restait ouverte)
function CO.ShouldClose(skill)
  if not skill then return false end
  if CO.WindowOpenFor(skill) then return CO.AnyWindowShown(skill) end
  return CO._opened == skill and CO.AnyWindowShown(skill)
end

function CO.SpellName(skill)
  local e = CO.SPELLS[skill]
  if not e then return nil end
  if type(_G.GetSpellInfo) == "function" then
    local ok, name = pcall(_G.GetSpellInfo, e[1])
    if ok and type(name) == "string" and name ~= "" then return name end
  end
  local loc = type(_G.GetLocale) == "function" and _G.GetLocale() or "frFR"
  return (loc == "frFR") and e[2] or e[3]
end

-- fenêtre ouverte pour ce métier ?
function CO.WindowOpenFor(skill)
  local name = CO.SpellName(skill)
  if CO.CRAFT_UI[skill] then
    local f = _G.CraftFrame
    if not (f and f.IsShown and f:IsShown()) then return false end
    local line = type(_G.GetCraftDisplaySkillLine) == "function" and _G.GetCraftDisplaySkillLine() or (type(_G.GetCraftName) == "function" and _G.GetCraftName())
    return line == nil or Norm(line) == Norm(name)
  end
  -- 3.5.8 : fenêtre Métiers des clients récents (ProfessionsFrame + C_TradeSkillUI)
  local pf = rawget(_G, "ProfessionsFrame")
  local okP, pShown = false, false
  if type(pf) == "table" and pf.IsShown then okP, pShown = pcall(pf.IsShown, pf) end
  if okP and pShown and not (_G.TradeSkillFrame and _G.TradeSkillFrame.IsShown and _G.TradeSkillFrame:IsShown()) then
    local Sc = ns.Scanner
    local okI, id = false, nil
    if Sc and Sc.ModernIdentity then okI, id = pcall(Sc.ModernIdentity) end
    if okI and id then return id == skill or (skill == "mining" and id == "smelting") end
    return true   -- métier non nommé : on ne relance pas le sort (il fermerait la fenêtre)
  end
  local f = _G.TradeSkillFrame
  if not (f and f.IsShown and f:IsShown()) then return false end
  local line = type(_G.GetTradeSkillLine) == "function" and _G.GetTradeSkillLine()
  return line == nil or Norm(line) == Norm(name) or (skill == "mining" and Norm(line) == Norm(CO.SPELLS.mining[2]))
end

-- 3.8.2 : 2e clic sur la case = fermer la fenêtre du métier (fermer n'est pas protégé)
function CO.CloseWindow(skill)
  local function hide(f)
    if f and f.IsShown and f:IsShown() then
      if type(_G.HideUIPanel) == "function" then pcall(_G.HideUIPanel, f) end
      if f:IsShown() and f.Hide then pcall(f.Hide, f) end
    end
  end
  if CO.CRAFT_UI[skill] then
    if type(_G.CloseCraft) == "function" then pcall(_G.CloseCraft) end
    hide(_G.CraftFrame)
    return
  end
  local pf = rawget(_G, "ProfessionsFrame")
  if type(pf) == "table" and pf.IsShown and pf:IsShown() then
    local T = _G.C_TradeSkillUI
    if T and type(T.CloseTradeSkill) == "function" then pcall(T.CloseTradeSkill) end
    hide(pf)
  end
  if type(_G.CloseTradeSkill) == "function" and _G.TradeSkillFrame and _G.TradeSkillFrame:IsShown() then pcall(_G.CloseTradeSkill) end
  hide(_G.TradeSkillFrame)
end

-- index de la recette dans la fenêtre ouverte (en-têtes ignorés)
function CO.FindIndex(skill, recipe)
  local want = Norm(recipe)
  if CO.CRAFT_UI[skill] then
    local n = type(_G.GetNumCrafts) == "function" and N(_G.GetNumCrafts()) or 0
    for i = 1, n do
      local name, _, kind = _G.GetCraftInfo(i)
      if kind ~= "header" and Norm(name) == want then return i end
    end
    return nil
  end
  local n = type(_G.GetNumTradeSkills) == "function" and N(_G.GetNumTradeSkills()) or 0
  for i = 1, n do
    local name, kind = _G.GetTradeSkillInfo(i)
    if kind ~= "header" and Norm(name) == want then return i end
  end
  return nil
end

-- sélectionne et fait défiler jusqu'à la recette ; true si fait
function CO.Select(skill, recipe)
  -- 3.5.17 : jamais sur la fenêtre Métiers récente (sélection non sécurisée)
  if CO.IsModern(skill) then return false end
  local i = CO.FindIndex(skill, recipe)
  if not i then return false end
  if CO.CRAFT_UI[skill] then
    if type(_G.CraftFrame_SetSelection) == "function" then pcall(_G.CraftFrame_SetSelection, i)
    elseif type(_G.SelectCraft) == "function" then pcall(_G.SelectCraft, i) end
    local sf, h = _G.CraftListScrollFrame, _G.CRAFT_SKILL_HEIGHT or 16
    if sf and type(_G.FauxScrollFrame_SetOffset) == "function" then
      local n = type(_G.GetNumCrafts) == "function" and N(_G.GetNumCrafts()) or 0
      local off = math.max(0, math.min(i - 4, n - (N(_G.CRAFTS_DISPLAYED) or 8)))
      pcall(_G.FauxScrollFrame_SetOffset, sf, off)
      if sf.ScrollBar or _G.CraftListScrollFrameScrollBar then pcall((_G.CraftListScrollFrameScrollBar or sf.ScrollBar).SetValue, _G.CraftListScrollFrameScrollBar or sf.ScrollBar, off * h) end
    end
    if type(_G.CraftFrame_Update) == "function" then pcall(_G.CraftFrame_Update) end
  else
    if type(_G.TradeSkillFrame_SetSelection) == "function" then pcall(_G.TradeSkillFrame_SetSelection, i)
    elseif type(_G.SelectTradeSkill) == "function" then pcall(_G.SelectTradeSkill, i) end
    local sf, h = _G.TradeSkillListScrollFrame, _G.TRADE_SKILL_HEIGHT or 16
    if sf and type(_G.FauxScrollFrame_SetOffset) == "function" then
      local n = type(_G.GetNumTradeSkills) == "function" and N(_G.GetNumTradeSkills()) or 0
      local off = math.max(0, math.min(i - 4, n - (N(_G.TRADE_SKILLS_DISPLAYED) or 8)))
      pcall(_G.FauxScrollFrame_SetOffset, sf, off)
      local bar = _G.TradeSkillListScrollFrameScrollBar or sf.ScrollBar
      if bar and bar.SetValue then pcall(bar.SetValue, bar, off * h) end
    end
    if type(_G.TradeSkillFrame_Update) == "function" then pcall(_G.TradeSkillFrame_Update) end
  end
  CO.stats.selected = CO.stats.selected + 1
  CO.lastSelected = { skill = skill, recipe = recipe, index = i }
  return true
end

-- Catégories repliées : tout déplier (index 0 = toutes, comme le bouton natif)
function CO.ExpandAll(skill)
  if CO.CRAFT_UI[skill] then
    if type(_G.ExpandCraftSkillLine) == "function" then pcall(_G.ExpandCraftSkillLine, 0) end
  elseif type(_G.ExpandTradeSkillSubClass) == "function" then
    pcall(_G.ExpandTradeSkillSubClass, 0)
  end
end
local function ClearBox(names)
  for _, nm in ipairs(names) do
    local eb = _G[nm]
    if type(eb) == "table" and eb.GetText and eb.SetText then
      local ok, txt = pcall(eb.GetText, eb)
      if ok and type(txt) == "string" and txt ~= "" then pcall(eb.SetText, eb, "") end
    end
  end
end
local function Uncheck(name, fn)
  local cb = _G[name]
  if type(cb) == "table" and cb.GetChecked and cb.SetChecked then
    local ok, on = pcall(cb.GetChecked, cb)
    if ok and on then pcall(cb.SetChecked, cb, false) end
  end
  if type(_G[fn]) == "function" then pcall(_G[fn], false) end
end
-- Filtres (sous-classe, emplacement, « composants disponibles », recherche) :
-- remis à « Tout », en dernier recours seulement (la recette restait cachée)
function CO.ResetFilters(skill)
  if CO.CRAFT_UI[skill] then
    Uncheck("CraftFrameAvailableFilterCheckButton", "CraftOnlyShowMakeable")
    if type(_G.SetCraftItemNameFilter) == "function" then pcall(_G.SetCraftItemNameFilter, "") end
    ClearBox({ "CraftFrameSearchBox", "CraftFrameEditBox" })
    if type(_G.CraftFrame_Update) == "function" then pcall(_G.CraftFrame_Update) end
    return
  end
  if type(_G.SetTradeSkillSubClassFilter) == "function" then pcall(_G.SetTradeSkillSubClassFilter, 0, 1, 1) end
  if type(_G.SetTradeSkillInvSlotFilter) == "function" then pcall(_G.SetTradeSkillInvSlotFilter, 0, 1, 1) end
  if type(_G.UIDropDownMenu_SetSelectedID) == "function" then
    for _, nm in ipairs({ "TradeSkillSubClassDropDown", "TradeSkillInvSlotDropDown" }) do
      if type(_G[nm]) == "table" then pcall(_G.UIDropDownMenu_SetSelectedID, _G[nm], 1) end
    end
  end
  Uncheck("TradeSkillFrameAvailableFilterCheckButton", "TradeSkillOnlyShowMakeable")
  if type(_G.SetTradeSkillItemNameFilter) == "function" then pcall(_G.SetTradeSkillItemNameFilter, "") end
  ClearBox({ "TradeSkillFrameSearchBox", "TradeSkillFrameEditBox" })
  if type(_G.TradeSkillFrame_Update) == "function" then pcall(_G.TradeSkillFrame_Update) end
end

-- demande d'ouverture (clic sur le toast) ; renvoie l'état
function CO.Request(c)
  if not (c and c.skill and c.recipe) then return "rien" end
  local t = Now()
  CO.want = { skill = c.skill, recipe = c.recipe, rid = c.rid, item = c.item, t = t, expires = t + CO.WANT_TTL, stage = 0 }
  if CO.IsModern(c.skill) then
    -- 3.5.17 : fenêtre Métiers récente : AUCUNE sélection depuis notre code
    -- (OpenRecipe non sécurisé → « Échec d'une action d'interface »). La
    -- sélection passe par le bouton sécurisé du toast (macro, CO.ToastMacro).
    CO.want = nil
    if InCombat() then CO.lastToast = { name = c.recipe, state = Tr["en combat : rien (toast gardé)"] } return "combat" end
    return "opened"
  end
  if InCombat() then
    CO.want.expires = t + CO.QUEUE_TTL
    CO.stats.queued = CO.stats.queued + 1
    if ns.AfterCombat then
      ns.AfterCombat("craftopen", function()
        if CO.want and not CO.WindowOpenFor(CO.want.skill) and ns.Print then
          ns.Print(Tr["recette en attente : ouvre "] .. tostring(CO.SpellName(CO.want.skill)) .. Tr[" (clic sur le toast ou livre de sorts), « "] .. tostring(CO.want.recipe) .. Tr[" » sera sélectionnée."])
        end
      end)
    end
    return "queued"
  end
  if CO.want.modern then
    CO.StartJob()
    return "pending"
  end
  if CO.WindowOpenFor(c.skill) and CO.Select(c.skill, c.recipe) then
    CO.want = nil
    return "selected"
  end
  CO.StartJob()        -- la fenêtre s'ouvre (bouton sécurisé) ou se met à jour : sélection différée
  return "pending"
end

-- Travail de sélection : UN seul OnUpdate, retiré dès que la recette est
-- sélectionnée, introuvable, ou que le délai est passé. Il ne fait QUE lire
-- et sélectionner : jamais d'ouverture ni de fermeture de fenêtre, donc
-- aucune boucle ouvre / ferme possible. Les événements de la fenêtre ne font
-- que (re)lancer ce travail s'il reste une demande ; garde de réentrance
-- (déplier / filtrer relance TRADE_SKILL_UPDATE pendant la sélection).
function CO.StopJob()
  local f = CO._job
  if not f then return end
  f._running, f._since = false, nil
  if f.SetScript then pcall(f.SetScript, f, "OnUpdate", nil) end
end
function CO.Finish(found)
  local w = CO.want
  CO.want = nil
  CO.StopJob()
  if not found and w and ns.Print then
    ns.Print(Tr["« "] .. tostring(w.recipe) .. Tr[" » introuvable dans la fenêtre "] .. tostring(CO.SpellName(w.skill)) .. ".")
  end
end
-- un pas : trouver ; sinon déplier les catégories ; sinon remettre les filtres ; sinon abandon
function CO.Attempt(w)
  if CO.Select(w.skill, w.recipe) then return true end
  if w.stage == 0 then
    w.stage = 1
    CO.ExpandAll(w.skill)
    return nil
  elseif w.stage == 1 then
    w.stage, w.filterT = 2, Now()
    CO.ResetFilters(w.skill)
    return nil
  end
  if Now() - (w.filterT or 0) >= CO.FILTER_WAIT then return false end
  return nil
end
function CO.Step(f)
  local w = CO.want
  if not w then CO.StopJob() return end
  local t = Now()
  if t > (w.expires or 0) then
    if w.modern and CO.mstat then CO.MLog("délai dépassé") CO.mstat.result = CO.mstat.result or "abandon (délai)" end
    CO.want = nil CO.StopJob() return
  end
  if InCombat() or CO._busy then return end
  if w.modern then
    CO._busy = true
    local ok, err = pcall(CO.StepModern, f, w, t)
    CO._busy = false
    if not ok then
      if CO.mstat then CO.mstat.result = "erreur : " .. tostring(err) end
      CO.want = nil CO.StopJob()
    end
    return
  end
  if not CO.WindowOpenFor(w.skill) then f._since = nil return end
  if not f._since then f._since = t return end
  if t - f._since < CO.SETTLE then return end
  CO._busy = true
  local ok, r = pcall(CO.Attempt, w)
  CO._busy = false
  if not ok then CO.want = nil CO.StopJob() return end
  if r ~= nil then CO.Finish(r) end
end
function CO.StartJob()
  if not CO.want then return false end
  local f = CO._job
  if not f then
    if type(_G.CreateFrame) ~= "function" then return false end
    local ok, fr = pcall(_G.CreateFrame, "Frame")
    if not (ok and fr) then return false end
    f = fr
    CO._job = f
  end
  if f._running then return true end
  f._running, f._since = true, nil
  f:SetScript("OnUpdate", function(self) CO.Step(self) end)
  return true
end
-- compatibilité (anciens appels) : sélection immédiate si possible, sinon le travail
function CO.OnWindow()
  local w = CO.want
  if not w or CO._busy then return false end
  if CO.WindowOpenFor(w.skill) and CO.Select(w.skill, w.recipe) then CO.want = nil CO.StopJob() return true end
  CO.StartJob()
  return false
end
if ns.On then
  local function kick() if CO.want and not CO._busy then CO.StartJob() end end
  ns.On("TRADE_SKILL_SHOW", kick)
  ns.On("TRADE_SKILL_UPDATE", kick)
  ns.On("CRAFT_SHOW", kick)
  ns.On("CRAFT_UPDATE", kick)
  -- 3.8.2 : fenêtre fermée (Échap, croix…) : la case n'a plus rien d'ouvert
  ns.On("TRADE_SKILL_CLOSE", function() CO._opened = nil end)
  ns.On("CRAFT_CLOSE", function() CO._opened = nil end)
  -- changement de métier : l'ancienne fenêtre se ferme après le clic ; la nouvelle reprend le métier cliqué
  local function shown() local pd = CO._pending if pd and (Now() - (pd.t or 0)) < 3 then CO._opened = pd.skill end end
  ns.On("TRADE_SKILL_SHOW", shown)
  ns.On("CRAFT_SHOW", shown)
  -- 3.5.14 : fenêtre Métiers récente
  -- 3.5.16 : la liste des recettes a été (re)remplie : moment de référence du
  -- premier appel (avant, il partait avant la liste et restait sur la 1re recette)
  ns.On("TRADE_SKILL_LIST_UPDATE", function()
    if CO.want and CO.want.modern then CO.want.listT = Now() end
    kick()
  end)
  ns.On("TRADE_SKILL_DATA_SOURCE_CHANGED", kick)
  ns.On("OPEN_RECIPE_RESPONSE", function(_, rid)
    if CO.mstat then CO.mstat.response = N(rid) or tostring(rid) end
    kick()
  end)
end

------------------------------------------------------------------------------
-- 3.5.14 : sélection de la recette dans la fenêtre Métiers récente (Forever)
--   * attendre : fenêtre affichée, bon métier, C_TradeSkillUI.IsTradeSkillReady
--     (si présent), source de données stable, puis un court délai (la fenêtre
--     sélectionne d'abord SA recette par défaut : avant 3.5.14 notre appel
--     passait avant et était aussitôt écrasé) ;
--   * sélectionner : C_TradeSkillUI.OpenRecipe(recipeID) seulement (API
--     publique ; c'est le code du jeu qui sélectionne, via OPEN_RECIPE_RESPONSE) ;
--   * vérifier en LECTURE (formulaire de la recette affichée) ; sinon relancer,
--     au plus CO.MODERN_TRIES fois ;
--   * aucune écriture dans les cadres du jeu, aucun filtre, aucune recherche :
--     le bouton « Créer » reste sûr.
------------------------------------------------------------------------------
CO.MODERN_TTL = 10      -- s : ouverture + chargement de la fenêtre (premier chargement de Blizzard_Professions)
CO.MODERN_SETTLE = 0.35 -- s : fenêtre prête depuis ce délai avant le premier appel
CO.MODERN_GAP = 0.35    -- s : entre deux essais
CO.MODERN_TRIES = 2     -- 3.5.16 : deux essais au plus, vérifiés par le nom
function CO.MLog(m)
  local st = CO.mstat
  if not st then return end
  st.log[#st.log + 1] = m
  if #st.log > 8 then table.remove(st.log, 1) end
end
function CO.IsModern(skill)
  if CO.CRAFT_UI[skill] then return false end
  local T = rawget(_G, "C_TradeSkillUI")
  if type(T) ~= "table" or type(T.OpenRecipe) ~= "function" or type(T.GetAllRecipeIDs) ~= "function" then return false end
  local Sc = ns.Scanner
  if Sc and type(Sc.ModernTrade) == "function" then
    local ok, r = pcall(Sc.ModernTrade)
    if ok then return r and true or false end
  end
  return type(_G.GetNumTradeSkills) ~= "function"
end
-- nom normalisé (couleurs, espaces et rang « [1] » retirés)
function CO.NormName(nm)
  if type(nm) ~= "string" then return "" end
  local clean = ns.Scanner and ns.Scanner.CleanRecipeName
  if clean then
    local ok, c = pcall(clean, nm)
    if ok and type(c) == "string" then nm = c end
  end
  return (Norm(nm):gsub("%s*%[%d+%]$", ""))
end
function CO.NameOf(info)
  if type(info) ~= "table" or type(info.name) ~= "string" then return nil end
  return CO.NormName(info.name)
end
function CO.StepModern(f, w, t)
  -- 3.5.17 : plus de sélection non sécurisée (voir CO.ToastMacro)
  CO.want = nil
  CO.StopJob()
end

------------------------------------------------------------------------------
-- 3.5.17 : clic toast sécurisé. Le bouton sécurisé du toast exécute une macro
-- qui appelle la même fonction que l'alerte « nouvelle recette » du jeu :
--   /run ProfessionsUtil.OpenProfessionFrameToRecipe(<id>)
-- La macro est exécutée par le jeu au clic (chemin sécurisé) ; nos attributs
-- ne sont posés que hors combat. Identifiant : celui de la fenêtre Forever,
-- trouvé par le NOM (GetAllRecipeIDs / GetRecipeInfo), sinon celui du toast.
------------------------------------------------------------------------------
CO.ridByName = CO.ridByName or {}
function CO.ResolveToastID(c)
  if type(c) ~= "table" then return nil, "rien" end
  local key = tostring(c.skill) .. ":" .. CO.NormName(c.recipe)
  local T = rawget(_G, "C_TradeSkillUI")
  local function Valid(id)
    if type(T) ~= "table" or type(T.GetTradeSkillLineForRecipe) ~= "function" then return true end
    local ok, line = pcall(T.GetTradeSkillLineForRecipe, id)
    return ok and line ~= nil
  end
  -- seulement quand la fenêtre de CE métier est ouverte (liste du bon métier)
  if type(T) == "table" and type(T.GetAllRecipeIDs) == "function" and CO.WindowOpenFor(c.skill) then
    local ok, ids = pcall(T.GetAllRecipeIDs)
    local want, cands = CO.NormName(c.recipe), {}
    if ok and type(ids) == "table" and want ~= "" then
      for _, rid in ipairs(ids) do
        local okI, info = pcall(T.GetRecipeInfo, rid)
        if okI and type(info) == "table" and info.learned ~= false and not info.isRecipeHeader and CO.NameOf(info) == want then
          cands[#cands + 1] = rid
          local alt = N(info.recipeID)
          if alt and alt ~= rid then cands[#cands + 1] = alt end
        end
      end
    end
    -- plusieurs identifiants pour le même nom : un identifiant reconnu par le
    -- jeu (GetTradeSkillLineForRecipe), le plus récent (le plus grand) d'abord
    table.sort(cands, function(a, b) return a > b end)
    for _, id in ipairs(cands) do
      if Valid(id) then
        CO.ridByName[key] = { id = id, all = table.concat(cands, ",") }
        return id, "nom (" .. table.concat(cands, ",") .. ")"
      end
    end
  end
  local mem = CO.ridByName[key]
  if mem then return mem.id, "nom (mémorisé)" end
  if N(c.rid) then return N(c.rid), "id du toast (sort)" end
  return nil, "introuvable"
end
function CO.SecureToastOn()
  if not (ns.db and ns.db.ui) then return true end
  return ns.db.ui.toastSecure ~= false   -- 3.5.17 : actif par défaut (version de test)
end
function CO.ToastMacro(c)
  if not (CO.SecureToastOn() and c and CO.IsModern(c.skill)) then return nil end
  local PU = rawget(_G, "ProfessionsUtil")
  if not (type(PU) == "table" and type(PU.OpenProfessionFrameToRecipe) == "function") then return nil, "ProfessionsUtil absent" end
  local id, src = CO.ResolveToastID(c)
  if not id then return nil, src end
  local m = string.format("/run local u=ProfessionsUtil if u and u.OpenProfessionFrameToRecipe then u.OpenProfessionFrameToRecipe(%d) end", id)
  if #m > 255 then return nil, "macro trop longue" end
  return m, src, id
end
-- attributs du bouton pour ce toast (hors combat seulement)
function CO.ApplyToastAction(b, c)
  if not b or InCombat() or type(b.SetAttribute) ~= "function" then return false end
  local m, src, id = CO.ToastMacro(c)
  CO.lastToast = { name = c and c.recipe, id = id, src = src, macro = m, state = m and "macro posée" or ("sort du métier (" .. tostring(src or "désactivé") .. ")") }
  if m then
    pcall(b.SetAttribute, b, "spell1", nil)
    pcall(b.SetAttribute, b, "type1", "macro")
    pcall(b.SetAttribute, b, "macrotext1", m)
    return true
  end
  pcall(b.SetAttribute, b, "macrotext1", nil)
  if c and CO.WindowOpenFor(c.skill) then CO.SetSpell(b, nil) else CO.SetSpell(b, c and CO.SpellName(c.skill)) end
  return false
end
ns.SlashExt = ns.SlashExt or {}
ns.SlashExt.toast = function(rest)
  local a = (rest or ""):match("^%s*(%S*)") or ""
  if not (ns.db and ns.db.ui) then return end
  if a == "on" then ns.db.ui.toastSecure = true elseif a == "off" then ns.db.ui.toastSecure = false end
  if ns.Print then ns.Print(Tr["clic toast sécurisé (ouvre la recette) : "] .. (CO.SecureToastOn() and Tr["activé"] or Tr["désactivé (ouvre seulement le métier)"]) .. Tr[" — /drop toast on|off"]) end
end
ns.HelpExt = ns.HelpExt or {}
ns.HelpExt[#ns.HelpExt + 1] = "/drop toast on|off : clic sur un toast de recette = ouvrir le métier sur la recette (macro sécurisée) ou seulement le métier"

------------------------------------------------------------------------------
-- Bouton sécurisé (un seul, enfant d'UIParent), armé au survol hors combat
------------------------------------------------------------------------------
function CO.Button()
  if CO.btn then return CO.btn end
  if InCombat() then return nil end
  local ok, b = pcall(CreateFrame, "Button", "DropamineCraftOpen", UIParent, "SecureActionButtonTemplate")
  if not (ok and b) then return nil end
  b._osrsOwn = true
  CO.RegisterClicks(b)
  if b.SetFrameStrata then pcall(b.SetFrameStrata, b, "DIALOG") end
  b:Hide()
  b:SetScript("OnEnter", function(self)
    if GameTooltip and self._toast then
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(Tr[CO.HINT], 1, 1, 1)
      GameTooltip:Show()
    end
    local t = self._toast
    if t then t._hover = true if t.SetAlpha then pcall(t.SetAlpha, t, 1) end end
  end)
  b:SetScript("OnLeave", function(self)
    if GameTooltip then GameTooltip:Hide() end
    local t = self._toast
    if t then t._hover = false if t._restart then pcall(t._restart) end end
    CO.Disarm()
  end)
  -- avant l'action sécurisée : sort décidé AU CLIC (fenêtre déjà ouverte ou
  -- clic trop rapproché → pas de sort), recette retenue ; clic droit = fermer le toast
  b:HookScript("PreClick", function(self, button, down)
    local t = self._toast
    if button == "RightButton" then
      CO.SetSpell(self, nil)
      if not down and t and UI.DismissDrop then pcall(UI.DismissDrop, UI, t) end
      return
    end
    if not (t and t._craft) or not CO.ActingPhase(down) then
      if not InCombat() then pcall(self.SetAttribute, self, "macrotext1", nil) end
      CO.SetSpell(self, nil)
      return
    end
    if InCombat() then return end
    -- 3.5.17 : macro sécurisée (même fonction que l'alerte du jeu), sinon le sort du métier
    if CO.ApplyToastAction(self, t._craft) then
      CO.stats.macros = (CO.stats.macros or 0) + 1
      CO.lastToast.state = "macro exécutée par le jeu"
      return
    end
    CO.PrepareCast(self, t._craft.skill)
    CO.Request(t._craft)
  end)
  b:HookScript("PostClick", function(self, button, down)
    if down then return end
    local t = self._toast
    if button ~= "RightButton" and t and UI.DismissDrop then pcall(UI.DismissDrop, UI, t) end
    CO.Disarm()
    if CO.want then CO.StartJob() end
  end)
  CO.btn = b
  return b
end

-- pose le bouton sur le toast (coordonnées absolues), hors combat seulement
function CO.Arm(t)
  if InCombat() or not (t and t._craft) then return false end
  if UI and (UI._inEditMode or t._editPreview) then return false end
  local b = CO.Button()
  if not b then return false end
  local l, bt, w, h = t.GetLeft and t:GetLeft(), t.GetBottom and t:GetBottom(), t.GetWidth and t:GetWidth(), t.GetHeight and t:GetHeight()
  local s = (t.GetEffectiveScale and t:GetEffectiveScale()) or 1
  local us = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
  if not (N(l) and N(bt) and N(w) and N(h)) then return false end
  local k = s / us
  CO.RegisterClicks(b)
  b:ClearAllPoints()
  b:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l * k, bt * k)
  b:SetSize(w * k, h * k)
  -- au-dessus du toast, quelle que soit sa strate
  local okS, st = pcall(t.GetFrameStrata, t)
  local STR = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
  pcall(b.SetFrameStrata, b, (okS and STR[st] and STR[st] > 5) and st or "DIALOG")
  local okL, lv = pcall(t.GetFrameLevel, t)
  if okL and N(lv) then pcall(b.SetFrameLevel, b, math.min(9000, lv + 10)) end
  -- fenêtre déjà ouverte pour ce métier : pas de sort (il la fermerait), sélection directe
  -- (réévalué au clic par CO.PrepareCast)
  pcall(CO.ApplyToastAction, b, t._craft)   -- 3.5.17 : macro sécurisée ou sort du métier
  b._toast = t
  b:Show()
  CO.stats.armed = CO.stats.armed + 1
  return true
end
function CO.Disarm()
  local b = CO.btn
  if not b or InCombat() then return false end
  b:Hide()
  b._toast = nil
  return true
end

-- Cases du panneau : métiers qui ont une fenêtre (CO.SPELLS). Pas Dépeçage,
-- Herboristerie, Pêche, ni les autres cases. Hors combat seulement.
CO.TILE_HINT = "Clic : ouvrir / fermer le métier"
function CO.Openable(d)
  if not (d and d.id and not d.placeholder and CO.SPELLS[d.id]) then return nil end
  -- 3.5.5 : réactivé (désactivé en 3.5.0 pour un clignotement). Option /drop ouvrir on|off.
  if ns.db and ns.db.ui and ns.db.ui.openProf == false then return nil end
  return d.id
end
function CO.TileButton()
  if CO.tileBtn then return CO.tileBtn end
  if InCombat() then return nil end
  local ok, b = pcall(CreateFrame, "Button", "DropamineTileOpen", UIParent, "SecureActionButtonTemplate")
  if not (ok and b) then return nil end
  b._osrsOwn = true
  CO.RegisterClicks(b)
  if b.SetFrameStrata then pcall(b.SetFrameStrata, b, "DIALOG") end
  if b.SetFrameLevel then pcall(b.SetFrameLevel, b, 80) end
  b:Hide()
  b:HookScript("PreClick", function(self, button, down)
    if InCombat() or type(self.SetAttribute) ~= "function" then return end
    local shift = type(_G.IsShiftKeyDown) == "function" and _G.IsShiftKeyDown()
    -- 3.10.0 : Alt+clic = point SkillUp, pas d'ouverture du métier
    local alt = type(_G.IsAltKeyDown) == "function" and _G.IsAltKeyDown()
    if button ~= "LeftButton" or shift or alt or not self._tileSkill or not CO.ActingPhase(down) then
      CO.SetSpell(self, nil)
    else
      -- 3.8.2 : fenêtre déjà ouverte sur ce métier → ce clic la fermera (PostClick)
      self._closeAfter = CO.ShouldClose(self._tileSkill) and self._tileSkill or nil
      if self._closeAfter then CO.SetSpell(self, nil)
      else CO.PrepareCast(self, self._tileSkill) end   -- déjà ouverte / clic trop rapproché → pas de sort
    end
  end)
  b:HookScript("PostClick", function(self, button, down)
    if down then return end
    if self._closeAfter then
      local sk = self._closeAfter
      self._closeAfter = nil
      CO.CloseWindow(sk)
      CO._opened = nil
      CO.stats.tileClosed = (CO.stats.tileClosed or 0) + 1
      if not InCombat() then CO.SetSpell(self, CO.SpellName(sk)) end
      return
    end
    local tile = self._tile
    local data = tile and tile.data
    local shift = type(_G.IsShiftKeyDown) == "function" and _G.IsShiftKeyDown()
    local alt = type(_G.IsAltKeyDown) == "function" and _G.IsAltKeyDown()
    local altDone = false
    if data and button ~= "RightButton" and alt and ns.SkillUp and ns.SkillUp.OnAltClick then
      local okA, done = pcall(ns.SkillUp.OnAltClick, data)
      altDone = okA and done
    end
    if altDone then
      -- 3.10.0 : point SkillUp posé, rien d'autre
    elseif data and button ~= "RightButton" and shift and ns.QoL and ns.QoL.ShareTile and ns.Opt("partage") then
      pcall(ns.QoL.ShareTile, data)
    elseif data and button == "RightButton" then
      if shift and UI and UI.CycleGoal then pcall(UI.CycleGoal, UI, data)
      elseif UI and UI.PromptGoal then pcall(UI.PromptGoal, UI, data) end
    elseif data and UI and UI.SelectTile then
      pcall(UI.SelectTile, UI, data)
    end
    if self._tileSkill and not CO.WindowOpenFor(self._tileSkill) then CO.SetSpell(self, CO.SpellName(self._tileSkill)) end
  end)
  -- le bouton recouvre la case : on garde l'infobulle de la case tant que la
  -- souris reste dessus, et on ne fait le « départ » de la case qu'en le quittant
  b:SetScript("OnLeave", function(self)
    local tile = self._tile
    CO.DisarmTile()
    if tile and CO.baseLeave then pcall(CO.baseLeave, tile) end
  end)
  CO.tileBtn = b
  return b
end
function CO.OverTileButton()
  local b = CO.tileBtn
  if not (b and b.IsShown and b:IsShown()) then return false end
  if b.IsMouseOver then
    local ok, over = pcall(b.IsMouseOver, b)
    if ok and over then return true end
  end
  if type(_G.GetMouseFocus) ~= "function" then return false end
  local ok, f = pcall(_G.GetMouseFocus)
  return ok and f == b
end
function CO.ArmTile(tile)
  if InCombat() or not tile then return false end
  if UI and UI._inEditMode then return false end
  local skill = CO.Openable(tile.data)
  if not skill then return false end
  local b = CO.TileButton()
  if not b or type(b.SetAttribute) ~= "function" then return false end
  -- déjà armé sur cette case : on ne repose rien (pas de va-et-vient)
  if b._tile == tile and b._tileSkill == skill and b.IsShown and b:IsShown() then return true end
  CO.RegisterClicks(b)
  local l = tile.GetLeft and tile:GetLeft()
  local bt = tile.GetBottom and tile:GetBottom()
  local w = tile.GetWidth and tile:GetWidth()
  local h = tile.GetHeight and tile:GetHeight()
  if not (N(l) and N(bt) and N(w) and N(h) and w > 0 and h > 0) then return false end
  local s = (tile.GetEffectiveScale and tile:GetEffectiveScale()) or 1
  local us = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
  local k = (N(s) and N(us) and us > 0) and (s / us) or 1
  b:ClearAllPoints()
  b:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l * k, bt * k)
  b:SetSize(w * k, h * k)
  if CO.WindowOpenFor(skill) then CO.SetSpell(b, nil) else CO.SetSpell(b, CO.SpellName(skill)) end
  b:SetAttribute("type2", nil)
  b._tile, b._tileSkill = tile, skill
  b:Show()
  CO.stats.tileArmed = (CO.stats.tileArmed or 0) + 1
  return true
end
function CO.DisarmTile()
  local b = CO.tileBtn
  if not b or InCombat() then return false end
  b:Hide()
  b._tile, b._tileSkill = nil, nil
  return true
end
if ns.On then
  -- juste avant le verrou de combat : boutons sécurisés rangés
  ns.On("PLAYER_REGEN_DISABLED", function()
    local b = CO.tileBtn
    if b then
      b._tile, b._tileSkill = nil, nil
      pcall(b.Hide, b)
    end
    local tb = CO.btn
    if tb then
      tb._toast = nil
      pcall(tb.Hide, tb)
    end
  end)
end
if ns.Icons and ns.Icons.OnEnter then
  local baseEnter = ns.Icons.OnEnter
  function ns.Icons.OnEnter(self, ...)
    local b = CO.tileBtn
    if b and b._tile == self and b.IsShown and b:IsShown() then return end
    baseEnter(self, ...)
    pcall(CO.ArmTile, self)
  end
end
if ns.Icons and ns.Icons.OnLeave then
  local baseLeave = ns.Icons.OnLeave
  CO.baseLeave = baseLeave
  function ns.Icons.OnLeave(self, ...)
    local b = CO.tileBtn
    if b and b._tile == self and CO.OverTileButton() then return end
    baseLeave(self, ...)
    if b and b._tile == self then CO.DisarmTile() end
  end
end
if ns.Compact and ns.Compact.FillTooltip then
  local baseTip = ns.Compact.FillTooltip
  function ns.Compact.FillTooltip(tt, d, tile)
    local m = baseTip(tt, d, tile)
    if tt and d and CO.Openable(d) and tt.AddLine then
      pcall(tt.AddLine, tt, Tr[CO.TILE_HINT], 0.6, 0.6, 0.6)
    end
    return m
  end
end
ns.SlashExt = ns.SlashExt or {}
ns.SlashExt.ouvrir = function(rest)
  local on = ns.ParseOnOff(rest, ns.Opt("openProf"))
  if not ns.db then return end
  ns.db.ui = ns.db.ui or {}
  if on then ns.db.ui.openProf = nil else ns.db.ui.openProf = false end
  if not on then CO.DisarmTile() end
  if ns.Print then ns.Print(Tr["clic pour ouvrir le métier "] .. (on and Tr["activé."] or Tr["désactivé."])) end
end
ns.HelpExt = ns.HelpExt or {}
ns.HelpExt[#ns.HelpExt + 1] = "/drop ouvrir on|off : clic gauche sur une case de métier ouvre sa fenêtre (hors combat)"

------------------------------------------------------------------------------
-- Branchements : toasts de recettes
------------------------------------------------------------------------------
local Craft = ns.Craft
if Craft and Craft.Notify then
  local baseNotify = Craft.Notify
  function Craft.Notify(gains)
    local f = baseNotify(gains)
    local e = gains and gains[1]
    if f and e and e.recipe then
      -- 3.5.14 : identifiant de RECETTE (sort) retenu, pas l'objet fabriqué
      f._craft = { skill = e.skill, recipe = e.recipe.name, name = e.recipe.name, rid = N(e.recipe.recipeID), item = N(e.recipe.itemID or e.recipe.item) }
      -- 3.5.17 : identifiant Forever résolu dès la création (fenêtre ouverte)
      local okR, mid = pcall(CO.ResolveToastID, f._craft)
      if okR then f._craft.mid = mid end
      CO.Wire(f)
    end
    return f
  end
end
function CO.FromToastData(td)
  if type(td) ~= "table" then return nil end
  local skill = td.skill
  local name, rid, item
  local rec = td.recipe
  if type(rec) == "table" then
    name = rec.name
    rid = N(rec.recipeID)
    item = N(rec.itemID or rec.item)
  elseif type(rec) == "string" and rec ~= "" then
    name = rec
  end
  if not item then item = N(td.item) end
  if not name then
    local m = td.matches and td.matches[1]
    if not m then
      local e = td.entries and td.entries[1]
      m = e and (e.recipe and e or e)
    end
    if m then
      local r = (type(m.recipe) == "table" and m.recipe) or m
      name = name or r.name or m.name
      rid = rid or N(r.recipeID or m.recipeID)
      item = item or N(m.item or r.itemID or r.item)
      skill = skill or m.skill
    end
  end
  if skill and name then
    return { skill = skill, recipe = name, name = name, rid = rid, item = item }
  end
  return nil
end
if UI and UI.SpawnDrop then
  local baseSpawn = UI.SpawnDrop
  function UI:SpawnDrop(...)
    local f = baseSpawn(self, ...)
    if f then
      f._craft = nil            -- toast recyclé : plus de recette résiduelle
      local td = f._toastData
      if not td then
        local opts = select(7, ...)
        if type(opts) == "table" then td = opts.toastData end
      end
      local c = CO.FromToastData and CO.FromToastData(td)
      if c then
        f._craft = c
        local okR, mid = pcall(CO.ResolveToastID, f._craft)
        if okR then f._craft.mid = mid end
        if CO.Wire then CO.Wire(f) end
      end
    end
    return f
  end
end
-- survol du toast : bouton armé + infobulle ; repli : clic ordinaire (fenêtre déjà ouverte)
function CO.Wire(f)
  if not f or not f.GetScript then return end
  local cur = f:GetScript("OnEnter")
  if cur ~= f._coEnter then
    local orig = cur
    f._coEnter = function(self, ...)
      if orig then orig(self, ...) end
      if self._craft and not CO.Arm(self) and GameTooltip then
        -- 3.6.3 : ne pas écraser l'infobulle déjà remplie (texte intégral + recette).
        if GameTooltip.IsOwned and GameTooltip:IsOwned(self) then
          if GameTooltip.AddLine then GameTooltip:AddLine(Tr[CO.HINT], 0.25, 1, 0.25, true) end
          if GameTooltip.Show then GameTooltip:Show() end
        else
          GameTooltip:SetOwner(self, "ANCHOR_TOP")
          GameTooltip:SetText(Tr[CO.HINT], 1, 1, 1)
          GameTooltip:Show()
        end
      end
    end
    f:SetScript("OnEnter", f._coEnter)
  end
  local curL = f:GetScript("OnLeave")
  if curL ~= f._coLeave then
    local origL = curL
    f._coLeave = function(self, ...)
      if origL then origL(self, ...) end
      if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end
    f:SetScript("OnLeave", f._coLeave)
  end
end
-- clic sur le toast (sans bouton armé : en combat, ou fenêtre ouverte) → recette
if UI and UI.OpenFromDrop then
  local baseOpen = UI.OpenFromDrop
  function UI:OpenFromDrop(target, drop)
    if drop and drop._craft then
      local st = CO.Request(drop._craft)
      -- clic ordinaire sans bouton sécurisé et fenêtre fermée : on ne peut pas
      -- lancer le sort d'ici ; la recette reste retenue jusqu'à l'ouverture
      if st == "pending" and CO.want and not CO.WindowOpenFor(drop._craft.skill) then
        CO.want.expires = Now() + CO.QUEUE_TTL
        if ns.Print then ns.Print(Tr["ouvre "] .. tostring(CO.SpellName(drop._craft.skill)) .. Tr[" : « "] .. tostring(drop._craft.recipe) .. Tr[" » sera sélectionnée."]) end
      end
      if st ~= "queued" and st ~= "combat" and self.DismissDrop then pcall(self.DismissDrop, self, drop) end
      return "recette:" .. st
    end
    return baseOpen(self, target, drop)
  end
end

ns.DebugExt = ns.DebugExt or {}
ns.DebugExt[#ns.DebugExt + 1] = function()
  return { string.format("— Toasts de recettes / cases de métier (3.5.17) — armés %d, sorts %d, sélectionnées %d, en attente %d, clic à l'%s%s", CO.stats.armed, CO.stats.casts or 0, CO.stats.selected, CO.stats.queued,
    CO.KeyDownMode() and "enfoncement" or "relâchement", CO.want and (" ; attente : " .. tostring(CO.want.recipe)) or ""),
    (function()
      local lt = CO.lastToast
      local PU = rawget(_G, "ProfessionsUtil")
      return string.format("  clic toast sécurisé (3.5.17) : %s ; ProfessionsUtil %s ; recette « %s » ; id résolu %s (%s) ; macro %s ; état %s ; combat %s ; macros lancées %d",
        CO.SecureToastOn() and "activé" or "désactivé", (type(PU) == "table" and type(PU.OpenProfessionFrameToRecipe) == "function") and "oui" or "non",
        tostring(lt and lt.name or "—"), tostring(lt and lt.id or "—"), tostring(lt and lt.src or "—"), tostring(lt and lt.macro or "—"),
        tostring(lt and lt.state or "—"), InCombat() and "oui" or "non", CO.stats.macros or 0)
    end)() }
end
