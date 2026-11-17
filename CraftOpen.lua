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
local _, ns = ...
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
  local f = _G.TradeSkillFrame
  if not (f and f.IsShown and f:IsShown()) then return false end
  local line = type(_G.GetTradeSkillLine) == "function" and _G.GetTradeSkillLine()
  return line == nil or Norm(line) == Norm(name) or (skill == "mining" and Norm(line) == Norm(CO.SPELLS.mining[2]))
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
  local i = CO.FindIndex(skill, recipe)
  if not i then return false end
  if CO.CRAFT_UI[skill] then
    if type(_G.CraftFrame_SetSelection) == "function" then pcall(_G.CraftFrame_SetSelection, i)
    elseif type(_G.SelectCraft) == "function" then pcall(_G.SelectCraft, i) end
    local sf, h = _G.CraftListScrollFrame, _G.CRAFT_SKILL_HEIGHT or 16
    if sf and type(_G.FauxScrollFrame_SetOffset) == "function" then
      local off = math.max(0, i - 4)
      pcall(_G.FauxScrollFrame_SetOffset, sf, off)
      if sf.ScrollBar or _G.CraftListScrollFrameScrollBar then pcall((_G.CraftListScrollFrameScrollBar or sf.ScrollBar).SetValue, _G.CraftListScrollFrameScrollBar or sf.ScrollBar, off * h) end
    end
    if type(_G.CraftFrame_Update) == "function" then pcall(_G.CraftFrame_Update) end
  else
    if type(_G.TradeSkillFrame_SetSelection) == "function" then pcall(_G.TradeSkillFrame_SetSelection, i)
    elseif type(_G.SelectTradeSkill) == "function" then pcall(_G.SelectTradeSkill, i) end
    local sf, h = _G.TradeSkillListScrollFrame, _G.TRADE_SKILL_HEIGHT or 16
    if sf and type(_G.FauxScrollFrame_SetOffset) == "function" then
      local off = math.max(0, i - 4)
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

-- demande d'ouverture (clic sur le toast) ; renvoie l'état
function CO.Request(c)
  if not (c and c.skill and c.recipe) then return "rien" end
  CO.want = { skill = c.skill, recipe = c.recipe }
  if InCombat() then
    CO.stats.queued = CO.stats.queued + 1
    if ns.AfterCombat then
      ns.AfterCombat("craftopen", function()
        if CO.want and not CO.WindowOpenFor(CO.want.skill) and ns.Print then
          ns.Print("recette en attente : ouvre " .. tostring(CO.SpellName(CO.want.skill)) .. " (clic sur le toast ou livre de sorts), « " .. tostring(CO.want.recipe) .. " » sera sélectionnée.")
        end
      end)
    end
    return "queued"
  end
  if CO.WindowOpenFor(c.skill) then
    if CO.Select(c.skill, c.recipe) then CO.want = nil return "selected" end
    return "pending"
  end
  return "pending"   -- le bouton sécurisé lance le sort ; la sélection suit à l'ouverture
end

-- fenêtre ouverte / mise à jour : recette en attente sélectionnée
function CO.OnWindow()
  local w = CO.want
  if not w then return false end
  if not CO.WindowOpenFor(w.skill) then return false end
  if CO.Select(w.skill, w.recipe) then CO.want = nil return true end
  return false
end
if ns.On then
  ns.On("TRADE_SKILL_SHOW", function() pcall(CO.OnWindow) end)
  ns.On("TRADE_SKILL_UPDATE", function() pcall(CO.OnWindow) end)
  ns.On("CRAFT_SHOW", function() pcall(CO.OnWindow) end)
  ns.On("CRAFT_UPDATE", function() pcall(CO.OnWindow) end)
end

------------------------------------------------------------------------------
-- Bouton sécurisé (un seul, enfant d'UIParent), armé au survol hors combat
------------------------------------------------------------------------------
function CO.Button()
  if CO.btn then return CO.btn end
  if InCombat() then return nil end
  local ok, b = pcall(CreateFrame, "Button", "DropamineCraftOpen", UIParent, "SecureActionButtonTemplate")
  if not (ok and b) then return nil end
  b._osrsOwn = true
  if b.RegisterForClicks then pcall(b.RegisterForClicks, b, "LeftButtonUp", "RightButtonUp") end
  if b.SetFrameStrata then pcall(b.SetFrameStrata, b, "DIALOG") end
  b:Hide()
  b:SetScript("OnEnter", function(self)
    if GameTooltip and self._toast then
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(CO.HINT, 1, 1, 1)
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
  -- avant l'action sécurisée : on retient la recette ; clic droit = fermer le toast
  b:HookScript("PreClick", function(self, button)
    local t = self._toast
    if button == "RightButton" then
      if t and UI.DismissDrop then pcall(UI.DismissDrop, UI, t) end
      return
    end
    if t and t._craft then CO.Request(t._craft) end
  end)
  b:HookScript("PostClick", function(self, button)
    local t = self._toast
    if button ~= "RightButton" and t and UI.DismissDrop then pcall(UI.DismissDrop, UI, t) end
    CO.Disarm()
    if CO.want then pcall(CO.OnWindow) end
  end)
  CO.btn = b
  return b
end

-- pose le bouton sur le toast (coordonnées absolues), hors combat seulement
function CO.Arm(t)
  if InCombat() or not (t and t._craft) then return false end
  local b = CO.Button()
  if not b then return false end
  local l, bt, w, h = t.GetLeft and t:GetLeft(), t.GetBottom and t:GetBottom(), t.GetWidth and t:GetWidth(), t.GetHeight and t:GetHeight()
  local s = (t.GetEffectiveScale and t:GetEffectiveScale()) or 1
  local us = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
  if not (N(l) and N(bt) and N(w) and N(h)) then return false end
  local k = s / us
  b:ClearAllPoints()
  b:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l * k, bt * k)
  b:SetSize(w * k, h * k)
  -- fenêtre déjà ouverte pour ce métier : pas de sort (il la fermerait), sélection directe
  local open = CO.WindowOpenFor(t._craft.skill)
  if open then
    b:SetAttribute("type1", nil)
    b:SetAttribute("spell1", nil)
  else
    b:SetAttribute("type1", "spell")
    b:SetAttribute("spell1", CO.SpellName(t._craft.skill))
  end
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
      f._craft = { skill = e.skill, recipe = e.recipe.name }
      CO.Wire(f)
    end
    return f
  end
end
if UI and UI.SpawnDrop then
  local baseSpawn = UI.SpawnDrop
  function UI:SpawnDrop(...)
    local f = baseSpawn(self, ...)
    if f then f._craft = nil end            -- toast recyclé : plus de recette
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
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(CO.HINT, 1, 1, 1)
        GameTooltip:Show()
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
      if st ~= "queued" and self.DismissDrop then pcall(self.DismissDrop, self, drop) end
      return "recette:" .. st
    end
    return baseOpen(self, target, drop)
  end
end

ns.DebugExt = ns.DebugExt or {}
ns.DebugExt[#ns.DebugExt + 1] = function()
  return { string.format("— Toasts de recettes (3.3.13) — armés %d, sélectionnées %d, en attente %d%s", CO.stats.armed, CO.stats.selected, CO.stats.queued,
    CO.want and (" ; attente : " .. tostring(CO.want.recipe)) or "") }
end
