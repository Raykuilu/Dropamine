-- Dropamine 3.5.12 — clics des cases « fiche » et Pêche, SANS souillure.
-- Historique : 3.5.7-3.5.11 cherchaient et cliquaient l'onglet JcJ /
-- Compétences de la fiche ; sur WoW Forever ces onglets ne sont pas
-- cliquables de façon sécurisée et les ouvrir depuis l'addon souillait la
-- fiche (erreur « secret number value … tainted by 'Dropamine' »). Retiré.
-- Désormais :
--   * cases Niveau, JcJ, armes (mêlée, distance, farouche) et Défense : au
--     survol, hors combat, un bouton SÉCURISÉ recouvre la case ; c'est le jeu
--     qui exécute « /click CharacterMicroButton » (ouvre / ferme la fiche) ;
--   * cases Dépeçage, Herboristerie, Pêche : ouvrent la fenêtre de leur
--     métier (C_TradeSkillUI.OpenTradeSkill ; aucun lancer de sort) ;
--   * attributs posés hors combat seulement ; bouton rangé avant le combat ;
--   * aucun message dans le chat, aucun crochet sur les onglets de la fiche.
local _, ns = ...
local Tr = ns.L   -- 3.5.19 : textes traduits (Locales/)
local PV = ns.PvP
if not PV then return end

local PT = { stats = { clicks = 0, armed = 0, prof = 0 } }
ns.PvPTab = PT

-- 3.7.1 : sans table temporaire.
local function GetRet(ok, ...)
  if not ok then return nil end
  return ...
end
local function Get(o, m, ...)
  if type(o) ~= "table" or type(o[m]) ~= "function" then return nil end
  return GetRet(pcall(o[m], o, ...))
end
local function InCombat()
  if type(_G.InCombatLockdown) == "function" then
    local ok, r = pcall(_G.InCombatLockdown)
    if ok and r then return true end
  end
  return ns.InCombat and ns.InCombat() or false
end
local function After(dt, fn)
  if type(_G.C_Timer) == "table" and type(_G.C_Timer.After) == "function" then _G.C_Timer.After(dt, fn) else fn() end
end

-- cases dont le clic gauche a une action
function PT.ModeOf(d)
  if type(d) ~= "table" or d.placeholder then return nil end
  if d.id and PT.GATHER[d.id] then return "prof" end
  if d.kind == "level" or d.kind == "pvp" or d.kind == "melee" or d.kind == "ranged"
    or d.kind == "feral" or d.kind == "defense" or d.id == "defense" then
    if type(rawget(_G, "CharacterMicroButton")) == "table" then return "sheet" end
  end
  return nil
end
PT.HINTS = { sheet = "Clic : fiche du personnage", prof = "Clic : ouvrir / fermer le métier" }

-- Métiers sans sort d'ouverture (récolte) : fenêtre du métier par sa ligne de
-- compétence. Sur Forever, Dépeçage, Herboristerie et Pêche ont leur fenêtre
-- (recettes, onglets de métiers). Les métiers de fabrication et le Minage
-- (Fondre) gardent le bouton de sort sécurisé de CraftOpen.
-- Lignes : lues dans le jeu (GetAllProfessionTradeSkillLines + nom), sinon
-- identifiants standard (Dépeçage 393, Herboristerie 182, Pêche 356).
PT.GATHER = { skinning = 393, herbalism = 182, fishing = 356 }
PT._lines, PT._cands = nil, nil
-- 3.5.13 : lignes lues dans le jeu, le PARENT d'abord (avant : la première
-- ligne rencontrée, parfois une ligne d'extension « enfant » → fenêtre vide ou
-- mauvais métier) ; carte refaite tant qu'elle est vide (métiers pas encore
-- chargés à la connexion).
local function ProfKey(info)
  if type(info) ~= "table" or not (ns.Style and ns.Style.SkillIdForText) then return nil end
  for _, nm in ipairs({ info.parentProfessionName, info.professionName }) do
    if type(nm) == "string" and nm ~= "" then
      local ok, key = pcall(ns.Style.SkillIdForText, nm)
      if ok and key then return key end
    end
  end
  return nil
end
function PT.BuildLines()
  local T = rawget(_G, "C_TradeSkillUI")
  if type(T) ~= "table" or type(T.GetAllProfessionTradeSkillLines) ~= "function"
    or type(T.GetProfessionInfoBySkillLineID) ~= "function" then return nil end
  local cands, n = {}, 0
  local ok, lines = pcall(T.GetAllProfessionTradeSkillLines)
  for _, line in ipairs((ok and type(lines) == "table") and lines or {}) do
    local okI, info = pcall(T.GetProfessionInfoBySkillLineID, line)
    local key = okI and ProfKey(info)
    if key and PT.GATHER[key] then
      cands[key] = cands[key] or {}
      local parent = tonumber(info.parentProfessionID)
      local function add(v, front)
        v = tonumber(v)
        if not v or v <= 0 then return end
        for _, x in ipairs(cands[key]) do if x == v then return end end
        if front then table.insert(cands[key], 1, v) else cands[key][#cands[key] + 1] = v end
        n = n + 1
      end
      if parent and parent > 0 then add(parent, true) add(line) else add(line, true) end
    end
  end
  if n == 0 then return nil end
  PT._cands = cands
  PT._lines = {}
  for k, v in pairs(cands) do PT._lines[k] = v[1] end
  return cands
end
function PT.Candidates(id)
  if not PT._cands then pcall(PT.BuildLines) end
  local out, seen = {}, {}
  for _, v in ipairs((PT._cands and PT._cands[id]) or {}) do if not seen[v] then seen[v] = true out[#out + 1] = v end end
  local d = PT.GATHER[id]
  if d and not seen[d] then out[#out + 1] = d end
  return out
end
local function ProfFrameShown()
  local pf = rawget(_G, "ProfessionsFrame")
  return (pf and Get(pf, "IsShown")) and true or false
end
-- métier affiché dans la fenêtre des métiers (clé du catalogue), ou nil
function PT.ShownProf()
  if not ProfFrameShown() then return nil end
  local T = rawget(_G, "C_TradeSkillUI")
  if type(T) ~= "table" then return nil end
  for _, fn in ipairs({ "GetBaseProfessionInfo", "GetChildProfessionInfo" }) do
    if type(T[fn]) == "function" then
      local ok, info = pcall(T[fn])
      local key = ok and ProfKey(info)
      if key then return key, info end
    end
  end
  return nil
end
PT.lastProf = {}
PT._profBusy = 0
local function Now() return (type(_G.GetTime) == "function" and select(2, pcall(_G.GetTime))) or 0 end
function PT.OpenProf(id)
  if InCombat() then PT.lastProf[id] = "en combat (rien)" return false end
  local T = rawget(_G, "C_TradeSkillUI")
  if type(T) ~= "table" then PT.lastProf[id] = "C_TradeSkillUI absent" return false end
  -- anti double clic : un essai en cours (vérification différée) → on ne
  -- relance rien (avant : ouverture puis fermeture immédiate possibles)
  local now = tonumber(Now()) or 0
  if now > 0 and now < PT._profBusy then PT.lastProf[id] = tostring(PT.lastProf[id]) .. " ; clic ignoré (essai en cours)" return false end
  -- déjà ouverte sur CE métier (comparaison par nom, parent ou enfant) : on la referme
  local shown = PT.ShownProf()
  -- 3.8.2 : aussi quand la fenêtre est celle que cette case a ouverte (Pêche : nom illisible ou différent)
  if ProfFrameShown() and (shown == id or (PT._opened == id and (shown == nil or shown == id))) then
    if type(T.CloseTradeSkill) == "function" then pcall(T.CloseTradeSkill) end
    local pf = rawget(_G, "ProfessionsFrame")
    if ProfFrameShown() and type(_G.HideUIPanel) == "function" then pcall(_G.HideUIPanel, pf) end
    if ProfFrameShown() and pf.Hide then pcall(pf.Hide, pf) end
    PT._opened = nil
    PT.lastProf[id] = "fermée (déjà ouverte sur ce métier)"
    return true
  end
  PT._opened = id
  if type(T.OpenTradeSkill) ~= "function" then PT.lastProf[id] = "OpenTradeSkill absent" return false end
  local cands = PT.Candidates(id)
  local log = { "avant : " .. tostring(shown or (ProfFrameShown() and "autre fenêtre" or "fermée")) }
  PT.stats.prof = (PT.stats.prof or 0) + 1
  local i = 0
  local function Try()
    i = i + 1
    local line = cands[i]
    if not line then
      log[#log + 1] = "ÉCHEC : aucune ligne n'ouvre " .. id
      PT.lastProf[id] = table.concat(log, " ; ")
      PT._profBusy = 0
      return
    end
    local ok, r = pcall(T.OpenTradeSkill, line)
    log[#log + 1] = "OpenTradeSkill(" .. tostring(line) .. ") → " .. (ok and tostring(r) or ("erreur " .. tostring(r)))
    PT._profBusy = (tonumber(Now()) or 0) + 0.6
    After(0.35, function()
      local got = PT.ShownProf()
      if got == id then
        log[#log + 1] = "fenêtre ouverte sur " .. id
        PT.lastProf[id] = table.concat(log, " ; ")
        PT._profBusy = 0
      elseif InCombat() then
        log[#log + 1] = "combat : arrêt"
        PT.lastProf[id] = table.concat(log, " ; ")
        PT._profBusy = 0
      else
        log[#log + 1] = "vu : " .. tostring(got or (ProfFrameShown() and "fenêtre sans métier lisible" or "rien"))
        -- fenêtre ouverte mais nom illisible : on n'empile pas d'autres essais
        if ProfFrameShown() and not got then
          PT.lastProf[id] = table.concat(log, " ; ")
          PT._profBusy = 0
          return
        end
        Try()
      end
    end)
  end
  Try()
  PT.lastProf[id] = table.concat(log, " ; ")
  return true
end

-- bouton sécurisé posé sur la case
function PT.Button()
  if PT.btn then return PT.btn end
  if InCombat() or type(_G.CreateFrame) ~= "function" then return nil end
  local ok, b = pcall(_G.CreateFrame, "Button", "DropaminePvPOpen", _G.UIParent, "SecureActionButtonTemplate")
  if not (ok and b) then return nil end
  b._osrsOwn = true
  local CO = ns.CraftOpen
  if CO and CO.RegisterClicks then pcall(CO.RegisterClicks, b)
  elseif b.RegisterForClicks then pcall(b.RegisterForClicks, b, "LeftButtonUp", "RightButtonUp") end
  pcall(b.SetFrameStrata, b, "DIALOG")
  pcall(b.SetFrameLevel, b, 80)
  b:Hide()
  b:HookScript("PreClick", function(self, button, down)
    if InCombat() then return end
    local shift = type(_G.IsShiftKeyDown) == "function" and _G.IsShiftKeyDown()
    local acting = not (CO and CO.ActingPhase) or CO.ActingPhase(down)
    pcall(self.SetAttribute, self, "spell1", nil)
    if button ~= "LeftButton" or shift or not acting or self._mode ~= "sheet" then
      pcall(self.SetAttribute, self, "type1", nil)
      pcall(self.SetAttribute, self, "macrotext1", nil)
      return
    end
    pcall(self.SetAttribute, self, "type1", "macro")
    pcall(self.SetAttribute, self, "macrotext1", "/click CharacterMicroButton")
  end)
  b:HookScript("PostClick", function(self, button, down)
    if down then return end
    PT.stats.clicks = PT.stats.clicks + 1
    local tile = self._tile
    local data = tile and tile.data
    local shift = type(_G.IsShiftKeyDown) == "function" and _G.IsShiftKeyDown()
    if data and button ~= "RightButton" and shift and ns.QoL and ns.QoL.ShareTile and ns.Opt("partage") then
      pcall(ns.QoL.ShareTile, data)
    elseif data and button == "RightButton" then
      if shift and ns.UI and ns.UI.CycleGoal then pcall(ns.UI.CycleGoal, ns.UI, data)
      elseif ns.UI and ns.UI.PromptGoal then pcall(ns.UI.PromptGoal, ns.UI, data) end
    else
      if self._mode == "prof" and data then pcall(PT.OpenProf, data.id) end
      PT.lastClick = tostring(self._mode) .. ((self._mode == "prof" and data) and (" " .. tostring(data.id)) or "")
      if data and ns.UI and ns.UI.SelectTile and data.kind ~= "pvp" then pcall(ns.UI.SelectTile, ns.UI, data) end
    end
  end)
  b:SetScript("OnLeave", function(self)
    local tile = self._tile
    PT.Disarm()
    if tile and PT.baseLeave then pcall(PT.baseLeave, tile) end
  end)
  PT.btn = b
  return b
end
function PT.Arm(tile)
  if InCombat() or type(tile) ~= "table" then return false end
  local mode = PT.ModeOf(tile.data)
  if not mode then return false end
  if ns.UI and ns.UI._inEditMode then return false end
  local b = PT.Button()
  if not b then return false end
  if b._tile == tile and Get(b, "IsShown") then return true end
  local l, bt, w, h = Get(tile, "GetLeft"), Get(tile, "GetBottom"), Get(tile, "GetWidth"), Get(tile, "GetHeight")
  local function num(v) return type(v) == "number" and v == v end
  if not (num(l) and num(bt) and num(w) and num(h) and w > 0 and h > 0) then return false end
  local s = Get(tile, "GetEffectiveScale") or 1
  local us = Get(_G.UIParent, "GetEffectiveScale") or 1
  local k = (num(s) and num(us) and us > 0) and (s / us) or 1
  b:ClearAllPoints()
  b:SetPoint("BOTTOMLEFT", _G.UIParent, "BOTTOMLEFT", l * k, bt * k)
  b:SetSize(w * k, h * k)
  pcall(b.SetAttribute, b, "type2", nil)
  b._tile, b._mode = tile, mode
  -- 3.5.13 : jamais deux boutons sécurisés en même temps : le bouton de sort
  -- des métiers (Fondre, etc.) resté posé sur une autre case est rangé
  local CO = ns.CraftOpen
  if CO and CO.tileBtn and CO.tileBtn._tile ~= tile and Get(CO.tileBtn, "IsShown") and CO.DisarmTile then
    pcall(CO.DisarmTile)
    PT.stats.coDisarmed = (PT.stats.coDisarmed or 0) + 1
  end
  b:Show()
  PT.stats.armed = PT.stats.armed + 1
  return true
end
function PT.Disarm()
  local b = PT.btn
  if not b or InCombat() then return false end
  b:Hide()
  b._tile = nil
  return true
end
local function OverButton()
  local b = PT.btn
  return (b and Get(b, "IsShown") and Get(b, "IsMouseOver")) and true or false
end
if ns.On then
  ns.On("PLAYER_REGEN_DISABLED", function()
    local b = PT.btn
    if b then b._tile = nil pcall(b.Hide, b) end
  end)
  -- 3.8.2 : fenêtre fermée par le joueur : la case n'a plus rien d'ouvert
  ns.On("TRADE_SKILL_CLOSE", function() PT._opened = nil end)
  -- anciens réglages des versions 3.5.10 / 3.5.11 (onglets appris) : effacés
  ns.On("PLAYER_LOGIN", function()
    if ns.db and ns.db.ui then ns.db.ui.pvpTab, ns.db.ui.skillsTab = nil, nil end
  end)
end
if ns.Icons and ns.Icons.OnEnter then
  local baseEnter = ns.Icons.OnEnter
  function ns.Icons.OnEnter(self, ...)
    local b = PT.btn
    if b and b._tile == self and Get(b, "IsShown") then return end
    baseEnter(self, ...)
    pcall(PT.Arm, self)
  end
end
if ns.Icons and ns.Icons.OnLeave then
  local baseLeave = ns.Icons.OnLeave
  PT.baseLeave = baseLeave
  function ns.Icons.OnLeave(self, ...)
    local b = PT.btn
    if b and b._tile == self and OverButton() then return end
    baseLeave(self, ...)
    if b and b._tile == self then PT.Disarm() end
  end
end
if ns.Compact and ns.Compact.FillTooltip then
  local baseTip = ns.Compact.FillTooltip
  function ns.Compact.FillTooltip(tt, d, tile)
    local m = baseTip(tt, d, tile)
    local mode = PT.ModeOf(d)
    local h = mode and PT.HINTS[mode]
    -- (la case JcJ a sa propre infobulle, ligne « Clic : » comprise)
    if h and not (d and d.kind == "pvp") and tt and tt.AddLine then pcall(tt.AddLine, tt, Tr[h] .. Tr[" (hors combat)"], 0.6, 0.6, 0.6) end
    return m
  end
end

-- clic direct sur la case JcJ (sans bouton sécurisé, ex. en combat) : rien,
-- et surtout jamais d'ouverture de la fiche par notre code
function PV.OpenWindow()
  PT.lastClick = InCombat() and "case JcJ en combat (rien)" or "case JcJ sans bouton sécurisé (rien)"
  return nil
end

ns.DebugExt = ns.DebugExt or {}
ns.DebugExt[#ns.DebugExt + 1] = function()
  local s = PT.stats
  local parts = {}
  for id in pairs(PT.GATHER) do
    local okC, c = pcall(PT.Candidates, id)
    parts[#parts + 1] = id .. " [" .. ((okC and type(c) == "table") and table.concat(c, ",") or "?") .. "]" .. (PT.lastProf[id] and (" : " .. PT.lastProf[id]) or "")
  end
  table.sort(parts)
  local co = ns.CraftOpen and ns.CraftOpen.tileBtn
  local coTile = co and co._tile and co._tile.data and co._tile.data.id
  local b = PT.btn
  local bTile = b and b._tile and b._tile.data and b._tile.data.id
  local okS, sp = pcall(PT.ShownProf)
  local out = { string.format("— Clics des cases (3.5.13) — bouton sécurisé %s (case %s, mode %s), armé %d, clics %d, dernier : %s ; bouton de sort des métiers sur %s ; fenêtre des métiers : %s",
    b and "oui" or "pas encore", tostring(bTile or "—"), tostring(b and b._mode or "—"), s.armed, s.clicks, tostring(PT.lastClick or "—"),
    tostring(coTile or "aucune case"), tostring((okS and sp) or (ProfFrameShown() and "ouverte (métier illisible)" or "fermée"))) }
  out[#out + 1] = "  métiers de récolte (lignes essayées dans l'ordre) : " .. table.concat(parts, " · ")
  return out
end
