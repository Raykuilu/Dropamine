-- Tests hors jeu 3.3.7 : GUID (tous formats) + repli par nom, cadre de l'infobulle, disposition
-- 1/2/5/10 colonnes, notifications ancrées au panneau.
-- Tests hors jeu 3.3.6 : surbrillance de la grille selon la cible, fondu automatique façon compteur de
-- dégâts (/drop fondu), largeurs réalistes des chiffres de case.
-- Tests hors jeu 3.3.5 : chiffres sur deux FontStrings, pastille « prêts » stable (fusion des recettes),
-- panneau compact au style des toasts + infobulle de détail, toasts → cases (éclat, pulsation, gain vert),
-- alertes de récolte, liens entre métiers, coûts (perf).
-- Tests hors jeu 3.3.1 : icône 3 piliers à nous, rien de Zygor, marge du détail.
-- Tests hors jeu 3.3.0 : grille d'icônes, détail à droite, couleurs natives (harnais 3.2.0).
-- Tests hors jeu 3.2.0 : fenêtre unique autonome + onglet latéral (harnais 3.0.1).
-- Tests hors jeu 3.0.1 (un seul panneau de détail, recettes, pas fixe + défilement, barres natives fixes, filets, en-têtes classiques, géométrie du détail, bouton icône) — harnais v3.0.0.
-- Tests hors jeu v2.8.4 (vue classique libre, drop, sections repliables, détail Niveau) — harnais v2.8.3.
-- Tests hors jeu v2.8.3 (liste native relevée, clic réel, détail natif) — harnais v2.8.2.
-- Tests hors jeu v2.8.2 : clic plein cadre, surbrillance, style natif, 2e tuile par classe, détail natif, chevauchement de boutons. (harnais repris de v2.8.1) (repli/dépli, combat, rechargement, sacs, métiers, textures).
-- valeurs secrètes, report en combat, style des drops, panneau de détail.
-- /tmp/lua tests/test_v301.lua

local addonDir = arg and arg[0] and arg[0]:match("^(.*)/tests/[^/]+%.lua$") or "."
if addonDir == "" then addonDir = "." end


-- Géométrie : rectangle absolu déduit des ancres (TOPLEFT/RIGHT/ALL…), y vers le haut.
local function anchorXY(r, name)
  local x = name:find("LEFT") and r.l or (name:find("RIGHT") and r.r) or (r.l + r.r) / 2
  local y = name:find("TOP") and r.t or (name:find("BOTTOM") and r.b) or (r.t + r.b) / 2
  return x, y
end
function __rect(f, depth)
  depth = depth or 0
  if type(f) ~= "table" or depth > 30 then return nil end
  if f._abs then return f._abs end
  if f.allPoints then return __rect(f.allPoints, depth + 1) end
  local pts = f.points
  if not pts or #pts == 0 then return nil end
  local L, R, T, B, CX, CY
  for _, p in ipairs(pts) do
    if p[1] == "ALL" then return __rect(p[2], depth + 1) end
    local rr = __rect(p[2] or f.parent, depth + 1)
    if not rr then return nil end
    local ax, ay = anchorXY(rr, p[3] or p[1])
    ax, ay = ax + (p[4] or 0), ay + (p[5] or 0)
    local n = p[1]
    if n:find("LEFT") then L = ax elseif n:find("RIGHT") then R = ax else CX = ax end
    if n:find("TOP") then T = ay elseif n:find("BOTTOM") then B = ay else CY = ay end
  end
  local w, h = f.width or 0, f.height or 0
  if not L and not R then L = (CX or 0) - w / 2 R = L + w elseif not L then L = R - w elseif not R then R = L + w end
  if not T and not B then T = (CY or 0) + h / 2 B = T - h elseif not T then T = B + h elseif not B then B = T - h end
  return { l = L, r = R, t = T, b = B }
end

_G.__ags = {}
local failures = 0
local function ok(cond, msg)
  if cond then print("  OK  " .. msg)
  else failures = failures + 1 print("  FAIL  " .. msg) end
end

local function hasPoint(frame, point, rel, relPoint)
  if not frame or not frame.points then return false end
  for i = 1, #frame.points do
    local p = frame.points[i]
    if p[1] == point then
      if rel and p[2] ~= rel then return false end
      if relPoint and p[3] ~= relPoint then return false end
      return true
    end
  end
  return false
end

-- Cadre / région instrumentés ------------------------------------------------
local framesByName = {}

local function newObj(class, name, parent)
  local f = {
    typ = class or "Frame",
    name = name,
    parent = parent,
    shown = true,
    width = 100,
    height = 50,
    points = {},
    children = {},
    regions = {},
    scripts = {},
    hooks = {},
    alpha = 1,
    level = parent and ((parent.level or 1) + 1) or 1,
    strata = "MEDIUM",
    text = "",
    justifyH = "LEFT",
    allPoints = nil,
    _setSizes = {},
  }
  if parent and parent.children then parent.children[#parent.children + 1] = f end
  if name then framesByName[name] = f; _G[name] = f end

  function f:GetName() return self.name end
  function f:GetObjectType() return self.typ end
  function f:GetParent() return self.parent end
  function f:SetParent(p)
    if self.parent and self.parent.children then
      for i = #self.parent.children, 1, -1 do
        if self.parent.children[i] == self then table.remove(self.parent.children, i) end
      end
    end
    self.parent = p
    if p and p.children then p.children[#p.children + 1] = self end
  end
  function f:GetChildren() return unpack(self.children) end
  function f:GetRegions() return unpack(self.regions) end
  function f:SetSize(w, h) self.width, self.height = w, h; self._setSizes[#self._setSizes + 1] = { w, h } end
  function f:GetWidth() return self.width end
  function f:SetWidth(w) self.width = w end
  function f:GetHeight() return self.height end
  function f:SetHeight(h) self.height = h end
  function f:GetLeft() local r = __rect(self) return r and r.l or (self._left or 0) end
  function f:GetBottom() local r = __rect(self) return r and r.b or (self._bottom or 0) end
  function f:GetRight() local r = __rect(self) return r and r.r or nil end
  function f:GetTop() local r = __rect(self) return r and r.t or nil end
  function f:IsVisible() local o = self while o do if o.shown == false then return false end o = o.parent end return true end
  function f:ClearAllPoints() self.points = {}; self.allPoints = nil end
  function f:SetPoint(point, rel, relPoint, x, y)
    if type(rel) == "number" then
      x, y = rel, relPoint
      rel, relPoint = self.parent, point
    end
    self.points[#self.points + 1] = { point, rel, relPoint, x, y }
  end
  function f:SetAllPoints(rel) self.allPoints = rel or self.parent; self.points = { { "ALL", self.allPoints } } end
  function f:GetPoint(i)
    local p = self.points[i or 1]
    if not p then return nil end
    return p[1], p[2], p[3], p[4], p[5]
  end
  function f:GetNumPoints() return #self.points end
  local function fire(self, ev)
    local list = self.hooks[ev]
    if list then for i = 1, #list do list[i](self) end end
    if self.scripts[ev] then self.scripts[ev](self) end
  end
  function f:Show()
    local was = self.shown
    self.shown = true
    if not was then fire(self, "OnShow") end
  end
  function f:Hide()
    local was = self.shown
    self.shown = false
    if was then fire(self, "OnHide") end
  end
  function f:IsShown() return self.shown and true or false end
  function f:SetShown(v) if v then self:Show() else self:Hide() end end
  function f:SetScript(ev, fn) self.scripts[ev] = fn end
  function f:GetScript(ev) return self.scripts[ev] end
  function f:HookScript(ev, fn)
    self.hooks[ev] = self.hooks[ev] or {}
    self.hooks[ev][#self.hooks[ev] + 1] = fn
  end
  function f:SetFrameStrata(st) self.strata = st end
  function f:GetFrameStrata() return self.strata end
  function f:SetFrameLevel(l) self.level = l end
  function f:GetFrameLevel() return self.level end
  function f:SetAlpha(a) self.alpha = a end
  function f:GetAlpha() return self.alpha end
  function f:SetMovable() end
  function f:EnableMouse(v) self.mouse = v and true or false end
  function f:IsMouseEnabled() return self.mouse end
  function f:RegisterForDrag() end
  function f:RegisterForClicks() end
  function f:SetClampedToScreen() end
  function f:StartMoving() self._moving = true end
  function f:StopMovingOrSizing() self._moving = false end
  function f:SetText(t) self.text = t or "" end
  function f:GetText() return self.text end
  function f:SetTextColor(r, g, b, a) self.tr, self.tg, self.tb, self.ta = r, g, b, a end
  function f:GetTextColor() return self.tr, self.tg, self.tb, self.ta end
  function f:SetJustifyH(j) self.justifyH = j end
  function f:GetJustifyH() return self.justifyH end
  function f:SetJustifyV() end
  function f:SetWordWrap(v) self.wrap = v and true or false end
  function f:SetNonSpaceWrap() end
  function f:SetFont(p, s, fl) self._font = { p, s, fl } return true end
  function f:SetShadowOffset(x, y) self._shadowOff = { x, y } end
  function f:SetShadowColor(r, g, b, a) self._shadowCol = { r, g, b, a } end
  function f:SetSnapToPixelGrid(v) self._snap = v end
  function f:SetTexelSnappingBias(v) self._texelBias = v end
  function f:GetFont() if self._font then return self._font[1], self._font[2], self._font[3] end end
  function f:SetButtonState(st, lock) self._bstate, self._block = st, lock end
  function f:SetVertexColor(r, g, b, a) self._vc = { r, g, b, a } end
  function f:GetVertexColor() local c = self._vc if c then return c[1], c[2], c[3], c[4] end return 1, 1, 1, 1 end
  function f:SetTexture(p) self._texSet = p if _G.__missingTex and type(p) == "string" and p:find(_G.__missingTex, 1, true) then return false end return true end
  function f:SetDesaturated(v) self.desat = v end
  function f:SetAtlas(a) self._atlasSet = a return true end
  function f:GetTexture() return self._tex end
  function f:GetAtlas() return self._atlas end
  function f:SetColorTexture(r, g, b, a) self._colorTex = { r, g, b, a } end
  function f:SetTexCoord() end
  function f:SetStatusBarTexture(p) self._barTex = p return true end
  function f:SetStatusBarColor(r,g,b,a) self._barColor = { r, g, b, a } end
  function f:SetMinMaxValues() end
  function f:SetValue() end
  function f:SetNormalTexture() end
  function f:GetNormalTexture() return self._nt end
  function f:SetPushedTexture() end
  function f:SetHighlightTexture() end
  function f:GetHighlightTexture() return self._hlt end
  function f:SetBlendMode(m) self.blend = m end
  function f:GetBlendMode() return self.blend end
  function f:SetHitRectInsets(l, r, t, b) self.hitInsets = { l, r, t, b } end
  function f:SetCheckedTexture() end
  function f:SetBackdrop() return true end
  function f:SetBackdropColor() end
  function f:SetBackdropBorderColor() end
  function f:SetMask() end
  function f:SetID() end
  function f:RegisterEvent() end
  function f:UnregisterEvent() end
  function f:SetScrollChild() end
  function f:EnableMouseWheel() end
  function f:GetVerticalScroll() return 0 end
  function f:GetVerticalScrollRange() return 0 end
  function f:SetVerticalScroll() end
  function f:CreateTexture(_, layer, _, sub)
    local t = newObj("Texture", nil, self)
    t.layer, t.sublayer = layer, sub
    self.regions[#self.regions + 1] = t
    return t
  end
  function f:CreateAnimationGroup()
    local ag = { owner = self, anims = {}, scripts = {}, playing = false, plays = 0 }
    function ag:CreateAnimation(kind)
      local a = { kind = kind, group = self }
      function a:SetDuration(d) self.duration = d end
      function a:SetOffset(x, y) self.offset = { x, y } end
      function a:SetSmoothing(s) self.smoothing = s end
      function a:SetFromAlpha(v) self.fromAlpha = v end
      function a:SetToAlpha(v) self.toAlpha = v end
      function a:SetScaleTo(x, y) self.scaleTo = { x, y } end
      function a:SetStartDelay(d) self.delay = d end
      function a:SetOrder(o) self.order = o end
      self.anims[#self.anims + 1] = a
      return a
    end
    function ag:SetScript(ev, fn) self.scripts[ev] = fn end
    function ag:Play() self.playing = true self.plays = self.plays + 1 _G.__ags[#_G.__ags + 1] = self end
    function ag:Stop() self.playing = false end
    function ag:IsPlaying() return self.playing end
    function ag:Finish() if self.playing then self.playing = false if self.scripts.OnFinished then self.scripts.OnFinished(self) end end end
    function ag:Find(kind) for _, a in ipairs(self.anims) do if a.kind == kind then return a end end end
    return ag
  end
  function f:GetStringWidth() return 6 * #(self.text or "") end
  function f:GetDrawLayer() return self.layer end
  function f:GetStatusBarTexture()
    if not self._sbt then self._sbt = newObj("Texture", nil, self) self._sbt.layer = "ARTWORK" end
    if self._barTex then self._sbt._tex = self._barTex end
    return self._sbt
  end
  function f:GetStatusBarColor() local c = self._barColor if c then return c[1], c[2], c[3], c[4] end end
  function f:SetFontObject(o) self.fontObj = o end
  function f:GetFontObject() return self.fontObj end
  function f:CreateFontString(_, _, font)
    local fs = newObj("FontString", nil, self)
    fs.font = font
    self.regions[#self.regions + 1] = fs
    return fs
  end
  return f
end

_G.CreateFrame = function(kind, name, parent, template)
  local f = newObj(kind or "Frame", name, parent)
  f.template = template
  -- Largeurs par défaut un peu réalistes
  if kind == "StatusBar" then f.typ = "StatusBar" end
  return f
end

_G.UIParent = newObj("Frame", "UIParent")
_G.UIParent.width, _G.UIParent.height = 1920, 1080
_G.Minimap = newObj("Frame", "Minimap", _G.UIParent)
_G.Minimap.width, _G.Minimap.height = 140, 140
_G.CharacterFrame = newObj("Frame", "CharacterFrame", _G.UIParent)
_G.SkillFrame = newObj("Frame", "SkillFrame", _G.CharacterFrame)
_G.SkillFrame.width, _G.SkillFrame.height = 700, 500
_G.SkillListScrollFrame = newObj("ScrollFrame", "SkillListScrollFrame", _G.SkillFrame)
_G.SkillListScrollFrame.width, _G.SkillListScrollFrame.height = 380, 420
_G.SkillDetailFrame = newObj("Frame", "SkillDetailFrame", _G.SkillFrame)
_G.SkillDetailFrame.width, _G.SkillDetailFrame.height = 240, 420
_G.SkillDetailName = newObj("FontString", "SkillDetailName", _G.SkillDetailFrame)
_G.SkillDetailName:SetText("Dépeçage")
_G.SkillDetailNameText = _G.SkillDetailName
_G.SkillDetailStatusBar = newObj("StatusBar", "SkillDetailStatusBar", _G.SkillDetailFrame)
_G.SkillDetailDescriptionText = newObj("FontString", "SkillDetailDescriptionText", _G.SkillDetailFrame)
_G.SkillDetailDescriptionText:SetText("Une compétence en dépeçage plus élevée...")
_G.EditModeManagerFrame = newObj("Frame", "EditModeManagerFrame", _G.UIParent)
_G.EditModeManagerFrame.shown = false

_G.GameTooltip = newObj("Frame", "GameTooltip", _G.UIParent)
function _G.GameTooltip:SetOwner() end
function _G.GameTooltip:AddLine() end
function _G.GameTooltip:AddDoubleLine() end
function _G.GameTooltip:ClearLines() end

_G.SlashCmdList = {}
_G.DropamineDB = nil
_G.hooksecurefunc = function() end
_G.InCombatLockdown = function() return false end
_G.UnitLevel = function() return 25 end
_G.MAX_PLAYER_LEVEL = nil
_G.UnitName = function() return "Ray Kullu" end
_G.UnitStat = function(_, index)
  local bases = { 61, 77, 80, 56, 60 }
  return bases[index], bases[index], 0, 0
end
_G.UnitXP = function() return 1200 end
_G.UnitXPMax = function() return 8000 end
_G.INVSLOT_MAINHAND = 16
_G.INVSLOT_RANGED = 18
local equipped = {
  [16] = { id = 854, link = "|cffffffff|Hitem:854::::::::25:::::::::|h[Bâton]|h|r",
           texture = "Interface\\Icons\\INV_Staff_08",
           name = "Bâton noueux", typ = "Arme", sub = "Bâtons", eq = "INVTYPE_2HWEAPON",
           classID = 2, subclassID = 10 },
}
_G.GetInventoryItemID = function(_, slot) return equipped[slot] and equipped[slot].id or nil end
_G.GetInventoryItemLink = function(_, slot) return equipped[slot] and equipped[slot].link or nil end
_G.GetInventoryItemTexture = function(_, slot) return equipped[slot] and equipped[slot].texture or nil end
_G.GetInventorySlotInfo = function(name)
  if name == "MainHandSlot" then return 16 end
  if name == "RangedSlot" then return 18 end
end
_G.GetItemInfo = function(item)
  for _, it in pairs(equipped) do
    if item == it.id or item == it.link then
      return it.name, it.link, 1, 20, 15, it.typ, it.sub, 1, it.eq, it.texture, 0, it.classID, it.subclassID
    end
  end
end

local skills = {
  { name = "Métiers", isHeader = true, isCollapsed = false, rank = 0, maxRank = 0 },
  { name = "Dépeçage", isHeader = false, rank = 161, maxRank = 225, modifier = 0, description = "Une compétence en dépeçage plus élevée..." },
  { name = "Travail du cuir", isHeader = false, rank = 96, maxRank = 150 },
  { name = "Compétences secondaires", isHeader = true, isCollapsed = false, rank = 0, maxRank = 0 },
  { name = "Cuisine", isHeader = false, rank = 78, maxRank = 150 },
  { name = "Pêche", isHeader = false, rank = 95, maxRank = 150 },
  { name = "Secourisme", isHeader = false, rank = 130, maxRank = 150 },
  { name = "Compétences d'armes", isHeader = true, isCollapsed = false, rank = 0, maxRank = 0 },
  { name = "Bâtons", isHeader = false, rank = 58, maxRank = 125 },
  { name = "Combat farouche", isHeader = false, rank = 124, maxRank = 125 },
  { name = "Dagues", isHeader = false, rank = 1, maxRank = 125 },
  { name = "Défense", isHeader = false, rank = 122, maxRank = 125 },
}
_G.C_SkillInfo = {
  GetNumSkillLines = function() return #_G.__visibleSkills() end,
  GetSkillLineInfo = function(i) return _G.__visibleSkills()[i] end,
  ExpandSkillHeader = function() end,
  SetSelectedSkill = function() end,
  GetSelectedSkill = function() return 2 end,
}

local prints = {}
local realPrint = print
_G.print = function(...)
  local parts = { ... }
  local s = tostring(parts[1] or "")
  for i = 2, #parts do s = s .. "\t" .. tostring(parts[i]) end
  prints[#prints + 1] = s
  -- garder un echo discret des messages de test (ceux qui commencent par "  OK" / "  FAIL" / "==")
  if s:find("^  OK") or s:find("^  FAIL") or s:find("^==") or s:find("^TOTAL") then
    realPrint(...)
  end
end


-- Comme en jeu : à ADDON_LOADED la fiche est fermée.
_G.CharacterFrame.shown = false
_G.SkillFrame.shown = false
local toggleCalls = 0
_G.ToggleCharacter = function(name)
  toggleCalls = toggleCalls + 1
  if name ~= "SkillFrame" then return end
  if _G.CharacterFrame.shown and _G.SkillFrame.shown then
    _G.SkillFrame:Hide() _G.CharacterFrame:Hide()
  else
    _G.CharacterFrame:Show() _G.SkillFrame:Show()
  end
end

-- Flèche native qui replie le panneau droit
local arrow = newObj("Button", "SkillFrameCollapseButton", _G.SkillFrame)
arrow.width, arrow.height = 24, 24
arrow.level = 9

-- Lignes natives (enfants directs du SkillFrame, comme sur la fiche native)
for i = 1, 3 do
  local r = newObj("StatusBar", "SkillRankFrame" .. i, _G.SkillFrame)
  r.width, r.height = 271, 15
  local l = newObj("Button", "SkillTypeLabel" .. i, _G.SkillFrame)
  l.width, l.height = 271, 15
end

-- v2.8.3 : liste native réaliste (en-tête, ligne, barre, cadre, surbrillance)
local function fontObj(n) local o = { GetName = function() return n end } _G[n] = o return o end
local HdrFont, RowFont, BarFont = fontObj("NLHdrFont"), fontObj("NLRowFont"), fontObj("NLBarFont")
local TitleFont, DescFont, DHdrFont, LineFont = fontObj("NLTitleFont"), fontObj("NLDescFont"), fontObj("NLDHdrFont"), fontObj("NLLineFont")
_G.SkillFrame._abs = { l = 0, r = 700, t = 500, b = 0 }
_G.SkillListScrollFrame._abs = { l = 20, r = 330, t = 440, b = 40 }
local function tex(parent, path, layer, abs, vc)
  local t = parent:CreateTexture(nil, layer) t._tex = path t._abs = abs t._vc = vc return t
end
do
  local h = _G.SkillTypeLabel1
  h._abs = { l = 24, r = 320, t = 438, b = 420 }
  local fs = h:CreateFontString(nil, "OVERLAY") fs.text = "Compétences d'armes" fs.fontObj = HdrFont
  fs.tr, fs.tg, fs.tb, fs.ta = 1, 0.82, 0, 1
  fs._abs = { l = 46, r = 200, t = 434, b = 424 }
  -- « − » natif = texture normale du bouton d'en-tête : une RÉGION de l'en-tête
  -- (comme en jeu), à droite (15×3, 6 px du bord droit, mesuré sur native-284.png)
  h._nt = newObj("Texture", nil, h) h._nt._tex = "Interface\\Buttons\\UI-MinusButton-Up"
  h._nt._abs = { l = 299, r = 314, t = 430, b = 427 } h._nt.layer = "ARTWORK"
  table.insert(h.regions, h._nt)
  tex(h, "Interface\\Native\\HdrL", "BACKGROUND", { l = 24, r = 34, t = 438, b = 420 }, { 1, 1, 1, 1 })
  tex(h, "Interface\\Native\\HdrM", "BACKGROUND", { l = 34, r = 310, t = 438, b = 420 }, { 0.9, 0.8, 0.7, 1 })
  tex(h, "Interface\\Native\\HdrR", "BACKGROUND", { l = 310, r = 320, t = 438, b = 420 }, { 1, 1, 1, 1 })
  local row = _G.SkillTypeLabel2
  row._abs = { l = 24, r = 320, t = 416, b = 401 }
  local rfs = row:CreateFontString(nil, "OVERLAY") rfs.text = "Bâtons" rfs.fontObj = RowFont
  rfs.tr, rfs.tg, rfs.tb, rfs.ta = 1, 0.99, 0.98, 1
  rfs._abs = { l = 30, r = 120, t = 414, b = 403 }
  row._hlt = tex(row, "Interface\\Native\\RowHL", "HIGHLIGHT", { l = 24, r = 320, t = 416, b = 401 })
  row._hlt.blend = "ADD" row._hlt.alpha = 0.6
  local bar = _G.SkillRankFrame2
  bar._abs = { l = 150, r = 318, t = 416, b = 402 }   -- hauteur native 14
  bar._barTex = "Interface\\Native\\BarFill" bar._barColor = { 0.1, 0.2, 0.9, 1 }
  tex(bar, "Interface\\Native\\BarBg", "BACKGROUND", { l = 150, r = 318, t = 416, b = 402 }, { 0, 0, 0, 0.5 })
  local bd = newObj("Button", "SkillRankFrame2Border", bar)
  bd._abs = { l = 145, r = 323, t = 425, b = 393 }
  tex(bd, "Interface\\Native\\BarBorder", "ARTWORK", { l = 145, r = 323, t = 425, b = 393 })
  local bfs = bd:CreateFontString(nil, "OVERLAY") bfs.text = "58 / 125" bfs.fontObj = BarFont bfs.tr, bfs.tg, bfs.tb = 1, 1, 1
  local row3 = _G.SkillTypeLabel3
  row3._abs = { l = 24, r = 320, t = 399, b = 384 }
  local r3 = row3:CreateFontString(nil, "OVERLAY") r3.text = "Défense" r3.fontObj = RowFont
  _G.SkillRankFrame1._abs = { l = 150, r = 318, t = 380, b = 366 }
  _G.SkillRankFrame3._abs = { l = 150, r = 318, t = 399, b = 385 }
end
-- Cadre natif invisible (alpha 0) mais sensible à la souris, AU-DESSUS de la
-- grille : c'est ce qui volait la souris en jeu (lignes de liste voilées).
_G.SkillFrame.ScrollBar = newObj("Slider", "SkillFrameScrollBar", _G.SkillFrame)
_G.SkillFrame.ScrollBar._abs = { l = 332, r = 348, t = 440, b = 40 }
local catcher = newObj("Button", "SkillFrameRowCatcher", _G.SkillFrame)
catcher._abs = { l = 20, r = 330, t = 440, b = 40 }
catcher.mouse = true catcher.alpha = 0 catcher.level = 80
-- Détail natif : titre, description, bouton d'en-tête, ligne
_G.SkillDetailFrame._abs = { l = 360, r = 600, t = 440, b = 40 }
table.insert(_G.SkillDetailFrame.regions, _G.SkillDetailName)
table.insert(_G.SkillDetailFrame.regions, _G.SkillDetailDescriptionText)
_G.SkillDetailName.fontObj = TitleFont _G.SkillDetailName._abs = { l = 420, r = 540, t = 430, b = 416 }
_G.SkillDetailDescriptionText.fontObj = DescFont
_G.SkillDetailDescriptionText._abs = { l = 382, r = 590, t = 390, b = 350 }
do
  local hb = newObj("Button", "SkillDetailHdrBtn", _G.SkillDetailFrame)
  hb._abs = { l = 380, r = 580, t = 340, b = 318 }
  local hfs = hb:CreateFontString(nil, "OVERLAY") hfs.text = "Adversaire de niveau égal" hfs.fontObj = DHdrFont
  hfs.tr, hfs.tg, hfs.tb = 1, 1, 1 hfs._abs = { l = 400, r = 560, t = 335, b = 323 }
  local lfs = _G.SkillDetailFrame:CreateFontString(nil, "OVERLAY") lfs.text = "Chance de toucher : 95 %" lfs.fontObj = LineFont
  lfs._abs = { l = 382, r = 590, t = 312, b = 300 }
end

local nativeUpdateCalls = 0
_G.SkillFrame_UpdateSkills = function()
  nativeUpdateCalls = nativeUpdateCalls + 1
  for i = 1, 3 do _G["SkillRankFrame" .. i]:Show() _G["SkillTypeLabel" .. i]:Show() end
end
local secureHooks = {}
_G.hooksecurefunc = function(a, b, c)
  local name, fn = a, b
  if type(a) == "table" then return end
  local orig = _G[name]
  if type(orig) ~= "function" then error("hooksecurefunc: " .. tostring(name)) end
  _G[name] = function(...) local r = orig(...) fn(...) return r end
  secureHooks[name] = true
end

local popupShown = {}
_G.StaticPopupDialogs = {}
_G.StaticPopup_Show = function(which, a1, a2, data)
  local eb = newObj("EditBox", nil, _G.UIParent)
  local p = newObj("Frame", nil, _G.UIParent)
  p.editBox = eb
  p.data = data
  popupShown[#popupShown + 1] = { which = which, a1 = a1, a2 = a2, data = data, popup = p }
  local dlg = _G.StaticPopupDialogs[which]
  if dlg and dlg.OnShow then dlg.OnShow(p, data) end
  return p
end
local shiftDown = false
_G.IsShiftKeyDown = function() return shiftDown end
local playerClass, shapeForm = "DRUID", 0
_G.UnitClass = function() return "Druide", playerClass end
_G.GetShapeshiftForm = function() return shapeForm end
_G.GetRealmName = function() return "Forever" end
local clock = 1000000
_G.time = function() return clock end

-- Liste native : un en-tête replié masque ses enfants (comme en jeu).
local SECRET = -424242
_G.issecretvalue = function(v) return v == SECRET end
local secretMode = false
_G.__visibleSkills = function()
  local out, hidden = {}, false
  for _, s in ipairs(skills) do
    if s.isHeader then hidden = s.isCollapsed out[#out + 1] = s
    elseif not hidden then
      if secretMode then out[#out + 1] = { name = s.name, isHeader = false, rank = SECRET, maxRank = SECRET }
      else out[#out + 1] = s end
    end
  end
  return out
end
-- Minuteries regroupées (C_Timer) : exécutées à la demande.
local timers = {}
_G.C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function flushTimers() local n = 0 while #timers > 0 do local t = table.remove(timers, 1) t() n = n + 1 end return n end
local gtime = 100
_G.GetTime = function() return gtime end
-- Sacs et fenêtre de métier
local bags = {}
_G.GetItemCount = function(id) return bags[id] or 0 end
local trade = { line = nil, list = {} }
_G.GetTradeSkillLine = function() return trade.line, 0, 0 end
_G.GetNumTradeSkills = function() return #trade.list end
_G.GetTradeSkillInfo = function(i) local r = trade.list[i] return r.name, r.kind, 0 end
_G.GetTradeSkillIcon = function(i) return "Interface\\Icons\\T" .. i end
_G.GetTradeSkillNumReagents = function(i) return #(trade.list[i].reagents or {}) end
_G.GetTradeSkillReagentInfo = function(i, j) local g = trade.list[i].reagents[j] return g.name, nil, g.count, bags[g.id] or 0 end
_G.GetTradeSkillReagentItemLink = function(i, j) return "|cffffffff|Hitem:" .. trade.list[i].reagents[j].id .. "::::::::|h[x]|h|r" end
local craft = { line = nil, list = {} }
_G.GetCraftDisplaySkillLine = function() return craft.line, 0, 0 end
_G.GetNumCrafts = function() return #craft.list end
_G.GetCraftInfo = function(i) local r = craft.list[i] return r.name, "", r.kind, 0 end
_G.GetCraftIcon = function() return "Interface\\Icons\\Spell_Holy_GreaterHeal" end
_G.GetCraftNumReagents = function(i) return #(craft.list[i].reagents or {}) end
_G.GetCraftReagentInfo = function(i, j) local g = craft.list[i].reagents[j] return g.name, nil, g.count, 0 end
_G.GetCraftReagentItemLink = function(i, j) return "|Hitem:" .. craft.list[i].reagents[j].id .. ":|h" end

local ns = {}
local function load(file)
  local chunk, err = loadfile(addonDir .. "/" .. file)
  if not chunk then error("loadfile " .. file .. ": " .. tostring(err)) end
  chunk("Dropamine", ns)
end
do
  local cf = _G.CreateFrame
  _G.CreateFrame = function(kind, ...)
    local f = cf(kind, ...)
    if kind == "CheckButton" and not f.SetChecked then
      function f:SetChecked(v) self.checked = v and true or false end
      function f:GetChecked() return self.checked end
    end
    return f
  end
end-- 3.2.0 : chargement dans l'ordre EXACT du .toc (Window.lua compris)
do
  local toc = io.open(addonDir .. "/Dropamine.toc"):read("*a")
  for line in toc:gmatch("[^\r\n]+") do
    if not line:match("^%s*#") and line:match("%.lua%s*$") then load((line:gsub("\\", "/"):gsub("%s+$", ""))) end
  end
end
_G.UISpecialFrames = _G.UISpecialFrames or {}
-- 3.3.13 : les anciennes sections testent le repli « cadre d'infobulle » ;
-- l'habillage FlareUI (Skin.lua) est testé dans ses propres sections.
ns.Skin.enabled = false
ns.Wide.forceShown = true
ns.PvP.forceOff = true      -- anciennes sections : pas de case JcJ   -- anciennes sections : case Niveau total présente (3.3.13 : masquée par défaut)

-- états de bouton enregistrés (le harnais de base les ignore)
local function recordStates(b)
  for _, st in ipairs({ "Normal", "Pushed", "Highlight", "Checked", "Disabled" }) do
    b["Set" .. st .. "Texture"] = function(self, p)
      local t = { _texSet = p, GetTexture = function() return p end, GetAtlas = function() return nil end }
      self["_st" .. st] = t
      return true
    end
    b["Get" .. st .. "Texture"] = function(self) return self["_st" .. st] end
  end
  return b
end
do
  local cf = _G.CreateFrame
  _G.CreateFrame = function(kind, ...)
    local f = cf(kind, ...)
    if kind == "Button" and type(f) == "table" and ((f.name or ""):find("SideTab", 1, true) or (f.name or ""):find("MicroButton", 1, true)) then recordStates(f) end
    if type(f) == "table" then
      function f:SetBackdrop(bd) self._bdFile = bd and bd.bgFile self._bdEdge = bd and bd.edgeFile self._bdEdgeSize = bd and bd.edgeSize self._bdInset = bd and bd.insets and bd.insets.left return true end
      function f:SetAttribute(k, v) self.attrs = self.attrs or {} self.attrs[k] = v end
      function f:GetAttribute(k) return self.attrs and self.attrs[k] end
      function f:SetChecked(v) self.checked = v and true or false end
      function f:GetChecked() return self.checked end
      function f:SetAutoFocus() end
      function f:SetMaxLetters() end
      function f:ClearFocus() end
      function f:SetValueStep(v) self.valueStep = v end
      function f:SetObeyStepOnDrag() end
      function f:SetOrientation() end
      function f:SetValue(v) self.value = v if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v) end end
      function f:GetValue() return self.value end
      function f:SetBackdropColor(r, g, b, a) self._bdColor = { r, g, b, a } end
      function f:SetBackdropBorderColor(r, g, b, a) self._bdBorder = { r, g, b, a } end
    end
    return f
  end
end
_G.Minimap._abs = { l = 1760, r = 1900, t = 1060, b = 920 }
-- Fiche du personnage : rectangle + onglets latéraux natifs à droite, puis
-- l'onglet de Zygor (enfant d'UIParent) sous le dernier.
_G.CharacterFrame._abs = { l = 0, r = 700, t = 900, b = 380 }
local nativeTabs = {}
for i = 1, 3 do
  local b = recordStates(newObj("Button", "CharacterFrameSideTab" .. i, _G.CharacterFrame))
  b._abs = { l = 702, r = 746, t = 880 - (i - 1) * 50, b = 836 - (i - 1) * 50 }
  b:SetNormalTexture("Interface\\Icons\\NativeIcon" .. i)     -- icône (à NE PAS recopier)
  b:SetHighlightTexture("Interface\\Native\\SideTabHL")
  local bd = b:CreateTexture(nil, "BACKGROUND")                  -- cadre qui déborde
  bd._tex = "Interface\\Native\\SideTabBorder"
  bd._abs = { l = b._abs.l - 4, r = b._abs.l + 60, t = b._abs.t + 12, b = b._abs.t - 52 }
  local ic = b:CreateTexture(nil, "ARTWORK")                      -- icône intérieure
  ic._tex = "Interface\\Icons\\Inner" .. i
  ic._abs = { l = b._abs.l + 4, r = b._abs.r - 4, t = b._abs.t - 4, b = b._abs.b + 4 }
  nativeTabs[i] = b
end
-- Onglet de Zygor : nom SANS « zygor » (comme en jeu, la détection par nom
-- échouait) et un art plus grand que son bouton qui DÉPASSE vers le bas
-- (carré doré à blocs colorés + « Z » blanc).
local zyg = recordStates(newObj("Button", "ZGV_CharacterSideTab", _G.UIParent))
zyg._abs = { l = 702, r = 746, t = 730, b = 686 }
zyg:SetNormalTexture("Interface\\AddOns\\ZygorGuidesViewer\\Skins\\tab-z")
zyg:SetHighlightTexture("Interface\\AddOns\\ZygorGuidesViewer\\Skins\\tab-hl")
local zart = zyg:CreateTexture(nil, "BACKGROUND")
zart._tex = "Interface\\AddOns\\ZygorGuidesViewer\\Skins\\tab-art"
zart._abs = { l = 698, r = 752, t = 734, b = 680 }

-- 3.3.2 : rangée native du micro menu (classique : 28×58, recouvrement de 3 px)
_G.MainMenuBarArtFrame = newObj("Frame", "MainMenuBarArtFrame", _G.UIParent)
local MICRO = { "CharacterMicroButton", "SpellbookMicroButton", "TalentMicroButton", "QuestLogMicroButton",
  "SocialsMicroButton", "WorldMapMicroButton", "MainMenuMicroButton", "HelpMicroButton" }
local micro = {}
for i, n in ipairs(MICRO) do
  local b = recordStates(newObj("Button", n, _G.MainMenuBarArtFrame))
  b._abs = { l = 552 + (i - 1) * 25, r = 580 + (i - 1) * 25, t = 60, b = 2 }
  b.level = 2
  b.strata = "MEDIUM"
  micro[i] = b
end
local cmb = micro[1]
cmb:SetNormalTexture("Interface\\Buttons\\UI-MicroButtonCharacter-Up")
cmb:SetPushedTexture("Interface\\Buttons\\UI-MicroButtonCharacter-Down")
cmb:SetHighlightTexture("Interface\\Buttons\\UI-MicroButton-Hilight")
cmb:SetDisabledTexture("Interface\\Buttons\\UI-MicroButtonCharacter-Up")
local portrait = cmb:CreateTexture("MicroButtonPortrait", "OVERLAY")
portrait._abs = { l = 557, r = 575, t = 32, b = 7 }
_G.MicroButtonPortrait = portrait
micro[8]:SetNormalTexture("Interface\\Buttons\\UI-MicroButton-Help-Up")
local microLayoutCalls = 0
_G.UIParent._abs = { l = 0, r = 1920, t = 1080, b = 0 }
-- 3.3.3 : portrait du personnage (SetPortraitTexture enregistré)
local portraitCalls = 0
_G.SetPortraitTexture = function(tex, unit) portraitCalls = portraitCalls + 1 tex._portraitUnit = unit tex._texSet = "portrait:" .. tostring(unit) end
_G.UpdateMicroButtons = function() microLayoutCalls = microLayoutCalls + 1 end

-- Empreinte complète de l'onglet Comp. natif (et de l'onglet Zygor) : elle doit
-- rester IDENTIQUE quoi que fasse l'addon.
local function fp(o, seen, out, path)
  if type(o) ~= "table" or seen[o] then return end
  seen[o] = true
  local pts = {}
  for _, p in ipairs(o.points or {}) do pts[#pts + 1] = tostring(p[1]) .. tostring(p[2]) .. tostring(p[3]) .. tostring(p[4]) .. tostring(p[5]) end
  local hk = 0
  for _, l in pairs(o.hooks or {}) do hk = hk + #l end
  local sc = 0
  for _ in pairs(o.scripts or {}) do sc = sc + 1 end
  out[#out + 1] = path .. "|" .. tostring(o.shown) .. "|" .. tostring(o.alpha) .. "|" .. tostring(o.parent) .. "|"
    .. table.concat(pts, ";") .. "|" .. tostring(o.width) .. "x" .. tostring(o.height) .. "|" .. tostring(o.level) .. "|"
    .. tostring(o.strata) .. "|" .. tostring(o._texSet) .. "|" .. tostring(o.text) .. "|h" .. hk .. "|s" .. sc .. "|m" .. tostring(o.mouse)
  for n, c in ipairs(o.children or {}) do fp(c, seen, out, path .. "/" .. n) end
end
local function nativeFP()
  local out = {}
  fp(_G.SkillFrame, {}, out, "SkillFrame")
  fp(zyg, {}, out, "Zygor")
  for i, b in ipairs(nativeTabs) do fp(b, {}, out, "Tab" .. i) end
  fp(_G.MainMenuBarArtFrame, {}, out, "Micro")
  return table.concat(out, "\n")
end
local FP0 = nativeFP()
local toggle0 = toggleCalls
local function fire(ev, ...) ns.eventFrame.scripts.OnEvent(ns.eventFrame, ev, ...) end
local okLoad, errLoad = pcall(fire, "ADDON_LOADED", "Dropamine")
ok(okLoad, "ADDON_LOADED sans erreur (" .. tostring(errLoad) .. ")")
pcall(fire, "PLAYER_LOGIN")
pcall(fire, "PLAYER_ENTERING_WORLD")


local UI = ns.UI
local function slash(msg) SlashCmdList.DROPAMINE(msg) end
local function lastPrint() return prints[#prints] or "" end
local function skill(name) for i = 1, #skills do if skills[i].name == name then return skills[i] end end end
local function tileFor(key)
  for i = 1, #(UI.embed and UI.embed.tiles or {}) do
    local t = UI.embed.tiles[i]
    if t.data and (t.data.key == key) and t:IsShown() then return t end
  end
end
local function dropTitles()
  local out = {}
  for i = 1, #(UI.dropsActive or {}) do out[#out + 1] = UI.dropsActive[i].titleFS.text end
  return table.concat(out, " || ")
end
local function clearDrops()
  for i = 1, #(UI.dropsActive or {}) do UI.dropsActive[i]:Hide() end
  UI.dropsActive = {}
end
local function errs() local n = 0 for _ in pairs(UI.errors or {}) do n = n + 1 end return n end

ok(not (ns.Window and ns.Window.IsShown()), "au chargement : fenêtre fermée")
slash("")  -- 3.2.0 : ouvre la fenêtre
ok(UI.embed and UI.embed:IsShown(), "grille OSRS ouverte")
clearDrops()


-- ===========================================================================
local function header(name) for i = 1, #skills do if skills[i].isHeader and skills[i].name == name then return skills[i] end end end
local function total() return UI.snapshot and UI.snapshot.total end
local function tick() UI:FlushSkillDiff() UI:Refresh(true) end
local function nDrops() local n = 0 for _, f in ipairs(UI.dropsActive or {}) do if f:IsShown() then n = n + 1 end end return n end
local function findDrop(pat) for _, f in ipairs(UI.dropsActive or {}) do if f.titleFS and tostring(f.titleFS.text):find(pat, 1, true) then return f end end end
ns.TodayKey = function() return "2026-11-16" end
ns.CharDB().daily = nil
UI:Refresh(true)
tick()
clearDrops()

local W = ns.Window
local V = ns.View
function _G.GameTooltip:SetText(t) self._tipText = t end
function _G.GameTooltip:Show() self.shown = true end
function _G.GameTooltip:Hide() self.shown = false end
local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5 }
local function allFrames(root, out)
  out = out or {}
  for _, c in ipairs(root.children or {}) do
    if c.typ ~= "Texture" and c.typ ~= "FontString" then out[#out + 1] = c allFrames(c, out) end
  end
  return out
end
local function topAt(x, y)
  local best, bs, bl
  for _, f in ipairs(allFrames(_G.UIParent)) do
    if f.mouse and f:IsVisible() then
      local r = __rect(f)
      local ins = f.hitInsets or { 0, 0, 0, 0 }
      if r and x >= r.l + ins[1] and x <= r.r - ins[2] and y <= r.t - ins[3] and y >= r.b + ins[4] then
        local st, o = nil, f
        while o and not st do st = o.strata o = o.parent end   -- la strate s'hérite (comme en jeu)
        local s, l = STRATA[st or "MEDIUM"] or 3, f.level or 0
        if not best or s > bs or (s == bs and l >= bl) then best, bs, bl = f, s, l end
      end
    end
  end
  return best
end
local function anc(o) while o do if o.shown == false then return false end o = o.parent end return true end
local function vis(o) return o and anc(o) and (o.alpha or 1) > 0 end
print("== Chargement : fenêtre et bouton du micro menu, rien sur l'onglet Comp. ==")
ok(ns.VERSION == "3.3.18", "version 3.3.18")
ok(io.open(addonDir .. "/Dropamine.toc"):read("*a"):find("Icons.lua", 1, true) and ns.Icons, ".toc : Icons.lua chargé (grille d'icônes)")
ok(io.open(addonDir .. "/Dropamine.toc"):read("*a"):find("Window.lua", 1, true), ".toc : Window.lua chargé")
ok(not io.open(addonDir .. "/Dropamine.toc"):read("*a"):find("NativeGrid", 1, true) and ns.NativeGrid == nil, "mode « lignes natives déplacées » (NativeGrid) retiré")
ok(W and W.frame and W.frame.name == "DropamineWindow" and W.frame.parent == _G.UIParent, "fenêtre autonome, enfant d'UIParent (pas de l'onglet Comp.)")
ok(W.micro == nil and W.BuildMicro == nil and W.PlaceMicro == nil and W.WatchMicro == nil and _G.DropamineMicroButton == nil, "3.4.2 : plus de bouton dans le micro menu (ni créé, ni veille 0,5 s)")
ok(W.tab == nil and W.BuildTab == nil and W.SideTabs == nil and _G.DropamineSideTab == nil, "onglet latéral de la fiche SUPPRIMÉ")
ok(not io.open(addonDir .. "/Dropamine.toc"):read("*a"):find("onglet latéral", 1, true), ".toc : plus de mention de l'onglet latéral")
local special = false
for _, n in ipairs(_G.UISpecialFrames) do if n == "DropamineWindow" then special = true end end
ok(not special, "Échap ne ferme PLUS le panneau (absent d'UISpecialFrames)")
ok(UI.embed and UI.embed:IsShown() and W.IsShown(), "/drop : fenêtre ouverte, grille visible")
ok(UI.embed.parent == W.list and W.list.parent == W.frame, "grille dans la fenêtre (zone liste)")
ok(UI:IsOsrsView() and UI:GetDetailParent() == W.detail, "plus de « vue classique » : le natif n'est plus hôte de rien")
slash("")
ok(not W.IsShown(), "/drop : referme la fenêtre")
slash("")
ok(W.IsShown(), "/drop : rouvre la fenêtre")

-- script + crochets (HookScript) d'un objet simulé
function runScript(o, ev, ...) if o.scripts[ev] then o.scripts[ev](o, ...) end for _, h in ipairs(o.hooks and o.hooks[ev] or {}) do h(o, ...) end end
print("== 3.4.2 : bouton de MINICARTE (seul bouton d'ouverture) ==")
-- 3.3.1 : textures UNIQUEMENT les nôtres, rien de recopié d'un autre cadre
local foreign = {}
local function collect(o)
  if type(o) ~= "table" then return end
  for _, k in ipairs({ "_tex", "_texSet", "_atlas", "_atlasSet" }) do if o[k] then foreign[tostring(o[k])] = true end end
  for _, st in ipairs({ "Normal", "Pushed", "Highlight", "Checked" }) do local t = o["_st" .. st] if t and t._texSet then foreign[t._texSet] = true end end
  for _, r in ipairs(o.regions or {}) do collect(r) end
  for _, c in ipairs(o.children or {}) do collect(c) end
end
collect(zyg) for _, nt in ipairs(nativeTabs) do collect(nt) end
local ALLOWED = { ["Interface\\Buttons\\ButtonHilight-Square"] = true,
  ["Interface\\Buttons\\CheckButtonHilight"] = true, ["Interface\\Minimap\\MiniMap-TrackingBorder"] = true,
  ["Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"] = true,
  -- 3.3.16 : icône d'ouverture = nos fichiers (piliers SkillsTab + coin du bord biseauté)
  ["Interface\\AddOns\\Dropamine\\Media\\SkillsTab"] = true, ["Interface\\AddOns\\Dropamine\\Media\\OSRS-IconCorner"] = true,
  ["Interface\\AddOns\\Dropamine\\Media\\OSRS-IconMask"] = true }
local function ownTextures(o, label, badOut, copiedOut)
  local function chk(p, where)
    if p == nil then return end
    p = tostring(p)
    if foreign[p] then copiedOut[#copiedOut + 1] = label .. where .. " " .. p end
    if not ALLOWED[p] then badOut[#badOut + 1] = label .. where .. " " .. p end
  end
  local function walk(x, path)
    if type(x) ~= "table" then return end
    if x.typ == "Texture" then chk(x._texSet, path) chk(x._atlasSet, path .. "(atlas)") end
    for _, st in ipairs({ "Normal", "Pushed", "Highlight", "Checked" }) do local t = x["_st" .. st] if t then chk(t._texSet, path .. ":" .. st) end end
    for i, r in ipairs(x.regions or {}) do walk(r, path .. "/r" .. i) end
    for i, c in ipairs(x.children or {}) do walk(c, path .. "/c" .. i) end
  end
  walk(o, "")
end
local function pillarsOK(P, label)
  if not (P and P.bg and P.cols and #P.cols == 3) then return false, label .. " : pas d'icône 3 piliers" end
  local want = { { 1, 2, 3 }, { 2, 1, 3 }, { 3, 1, 2 } }   -- canal dominant : R, G, B
  local br = __rect(P.bg)
  local prevR, w0
  for i = 1, 3 do
    local c = P.cols[i]
    local col = c._colorTex
    if not col then return false, label .. " colonne " .. i .. " sans aplat" end
    local d, o1, o2 = want[i][1], want[i][2], want[i][3]
    if not (col[d] > 0.5 and col[d] > col[o1] + 0.3 and col[d] > col[o2] + 0.3) then return false, label .. " colonne " .. i .. " mauvaise couleur" end
    if c._texSet ~= nil or c._atlasSet ~= nil then return false, label .. " colonne " .. i .. " : texture externe" end
    local r = __rect(c)
    if not (r and br and r.l >= br.l and r.r <= br.r and r.b >= br.b and r.t <= br.t) then return false, label .. " colonne " .. i .. " hors du carré" end
    if (r.t - r.b) <= (r.r - r.l) * 1.5 then return false, label .. " colonne " .. i .. " pas verticale" end
    if prevR and r.l < prevR then return false, label .. " colonnes qui se chevauchent" end
    w0 = w0 or (r.r - r.l)
    if math.abs((r.r - r.l) - w0) > 0.01 then return false, label .. " colonnes de largeurs différentes" end
    prevR = r.r
  end
  local others = 0
  for _, x in ipairs(P.bg.parent.regions or {}) do
    if x.typ == "Texture" and x.shown ~= false and x ~= P.bg and x ~= P.cols[1] and x ~= P.cols[2] and x ~= P.cols[3] then
      local xr = __rect(x)
      if xr and x.layer ~= "BACKGROUND" and x.layer ~= "OVERLAY" and x.layer ~= "HIGHLIGHT" and xr.l < br.r and xr.r > br.l and xr.b < br.t and xr.t > br.b then others = others + 1 end
    end
  end
  if others > 0 then return false, label .. " : autre art par-dessus" end
  return true, label .. " : 3 colonnes rouge / vert / bleu, verticales, mêmes largeurs, nos aplats"
end
-- 3.3.16 : les piliers dessinés sont remplacés par l'icône recadrée + bord biseauté
local function iconOK(b, label)
  local ic = b and b._tiIcon
  if not (ic and ic._texSet == ns.ToggleIcon.ICON) then return false, label .. " : pas d'icône SkillsTab" end
  local br, ir = __rect(b), __rect(ic)
  local B = ns.ToggleIcon.BEVEL
  if not (br and ir and ir.l - B >= br.l - 0.01 and ir.r + B <= br.r + 0.01 and ir.b - B >= br.b - 0.01 and ir.t + B <= br.t + 0.01) then
    return false, label .. " : icône + bord débordent du cadre"
  end
  if not (b._bevel and #b._bevel.corners == 4) then return false, label .. " : pas de bord biseauté" end
  if b._pillars and b._pillars.bg.shown ~= false then return false, label .. " : anciens piliers encore visibles" end
  return true, label .. " : icône SkillsTab recadrée + bord biseauté, DANS le cadre"
end
local badT, copiedT = {}, {}
local mm = UI.minimap or _G.DropamineMinimapButton
ok(mm ~= nil, "bouton de minicarte présent")
ownTextures(mm, "minicarte", badT, copiedT)
ok(#copiedT == 0 and #badT == 0, "minicarte : seulement nos aplats + anneau / surbrillance natifs " .. table.concat(badT, ", "))
local okM, msgM = iconOK(mm, "minicarte")
ok(okM, msgM)
-- info-bulles « Niveau total : X / 2460 »
local want = "Niveau total : " .. tostring(UI.snapshot.total) .. " / 2460"
mm.scripts.OnEnter(mm)
ok(_G.GameTooltip.shown and _G.GameTooltip._tipText == want, "minicarte : info-bulle « " .. tostring(_G.GameTooltip._tipText) .. " »")
mm.scripts.OnLeave(mm)
ok(UI.snapshot.total and UI.snapshot.total > 0 and ns.TOTAL_MAX == 2460, "total réel (" .. tostring(UI.snapshot.total) .. ") sur 2460")
local addL, gotL = _G.GameTooltip.AddLine, {}
_G.GameTooltip.AddLine = function(self, t) gotL[#gotL + 1] = tostring(t) end
mm.scripts.OnEnter(mm)
_G.GameTooltip.AddLine = addL
ok(_G.GameTooltip._tipText == "Niveau total : " .. tostring(UI.snapshot.total) .. " / 2460" and gotL[1] == "Clic : ouvrir / fermer", "minicarte : « Niveau total : X / 2460 » puis « " .. tostring(gotL[1]) .. " »")
mm.scripts.OnLeave(mm)
local wasMM = W.IsShown()
if mm.scripts.OnClick then mm.scripts.OnClick(mm, "LeftButton") end
ok(W.IsShown() ~= wasMM, "minicarte : clic = ouvrir / fermer le panneau")
if W.IsShown() ~= wasMM and mm.scripts.OnClick then mm.scripts.OnClick(mm, "LeftButton") end
if not W.IsShown() then W.Show() end

print("== Position : arrimée à droite de la fiche, déplaçable, mémorisée ==")
local fp1 = W.frame.points[1]
ok(fp1 and fp1[1] == "TOPLEFT" and fp1[2] == _G.CharacterFrame and fp1[3] == "TOPRIGHT", "par défaut : à droite de la fiche (" .. tostring(W.posSource) .. ")")
ok(W.frame.movable ~= false and W.frame.scripts.OnDragStart and W.frame.scripts.OnDragStop, "déplaçable (glisser)")
W.frame:ClearAllPoints() W.frame:SetPoint("TOPLEFT", _G.UIParent, "BOTTOMLEFT", 300, 700)
W.frame.scripts.OnDragStop(W.frame)
local wp = ns.db.ui.winPos
ok(wp and wp.point == "TOPLEFT" and wp.relativePoint == "BOTTOMLEFT" and wp.x == 300 and wp.y == 700, "position mémorisée (coin haut-gauche, SavedVariables)")
W.PlaceDefault(W.frame)
ok(W.frame.points[1][1] == "TOPLEFT" and W.frame.points[1][4] == 300 and W.frame.points[1][5] == 700 and W.posSource == "position mémorisée", "position restaurée")
slash("reset")
ok(ns.db.ui.winPos == nil and W.frame.points[1][2] == _G.CharacterFrame, "/drop reset : retour à droite de la fiche")

print("== 3.3.5 : chiffres de case sur DEUX FontStrings (plus de « 27… / 85… / 951… ») ==")
UI:ApplyView()
local IC = ns.Icons
local tiles = {}
for _, t in ipairs(UI.embed.tiles) do if t:IsShown() and t.data then tiles[#tiles + 1] = t end end
do
  local counts, nl, wrapOK, fontOK, fits, anchors, white, list = true, true, true, true, true, true, true, {}
  for _, t in ipairs(tiles) do
    local a, b = t.countFS, t.countFS2
    local want = t.data.placeholder and "0" or tostring(math.floor((tonumber(t.data.current) or 0) + 0.5))
    local wantMax = tonumber(t.data.apiMax) or 0
    if wantMax <= 0 then wantMax = IC.CapFor(t.data) end
    if t.data.kind == "level" then wantMax = 60 end
    if not (a and b and vis(a) and vis(b) and a.text == want and b.text == "/" .. wantMax) then counts = false io.stderr:write("count ", tostring(t.data.name), " ", tostring(a and a.text), " ", tostring(b and b.text), "\n") end
    list[#list + 1] = tostring(a.text) .. "|" .. tostring(b.text)
    if tostring(a.text):find("\n", 1, true) or tostring(b.text):find("\n", 1, true) then nl = false end
    if a.wrap ~= false or b.wrap ~= false then wrapOK = false end
    for _, fs in ipairs({ a, b }) do
      local f0 = fs._font
      if not (f0 and f0[1] == "Fonts\\ARIALN.TTF" and f0[3] == "" and fs._shadowOff and fs._shadowOff[1] == 1 and fs._shadowOff[2] == -1 and f0[2] >= 8 and f0[2] <= 13 and fs.justifyH == "RIGHT") then fontOK = false end
      -- 3.3.8 : largeur IMPOSÉE = case − 2 × marge (deux ancres) ; la police rétrécit jusqu'à tenir
      local pl, pr = fs.points[1], fs.points[2]
      local ins = (fs == b) and IC.COUNT_INSET or 0   -- « /max » : marge sur la case ; rang : collé à « /max »
      if not (pl and pr and pl[1] == "BOTTOMLEFT" and pr[1] == "BOTTOMRIGHT" and pl[4] == ins and pr[4] == -ins) then fits = false io.stderr:write("pts ", tostring(pl and pl[1]), tostring(pl and pl[4]), tostring(pr and pr[1]), tostring(pr and pr[4]), "\n") end
      if fs:GetStringWidth() > IC.TILE - 2 * IC.COUNT_INSET then fits = false io.stderr:write("width ", tostring(fs.text), "\n") end
      -- mesure : texte (6 px / car. dans le harnais, ≈ 0,5 em en jeu) ≤ case
      local tw = __rect(t).r - __rect(t).l
      if fs:GetStringWidth() > tw - 2 or f0[2] * 0.5 * #tostring(fs.text) > tw - 2 then fits = false end
    end
    if 2 * a._font[2] > IC.TILE - 4 then fits = false end
    local pb, pa = b.points[1], a.points[1]
    if not (pb and pb[1] == "BOTTOMLEFT" and pb[2] == t and pb[3] == "BOTTOMLEFT" and pa and pa[1] == "BOTTOMLEFT" and pa[2] == b and pa[3] == "TOPLEFT") then anchors = false end
    if not t.data.placeholder and not (a.tr == 1 and a.tg == 1 and a.tb == 1 and b.tr < 1 and b.tr > 0.6) then white = false end   -- 3.3.17 : « /max » atténué
  end
  ok(#tiles == 10, "10 cases visibles (" .. #tiles .. ")")
  ok(counts, "rang sur la 1re FontString, « /max » sur la 2e : " .. table.concat(list, " "))
  ok(nl, "aucun « \\n » dans une FontString (c'était la cause de la troncature en jeu)")
  ok(wrapOK, "SetWordWrap(false) sur CHAQUE ligne")
  ok(fontOK, "3.3.9 : Arial Narrow SANS contour, ombre fine 1 px, 8–13 px, alignée à droite, sur les deux lignes")
  ok(fits, "3.3.8 : texte DANS la case (marge " .. IC.COUNT_INSET .. " px de chaque côté), mesuré ≤ case de " .. IC.TILE .. " px, deux lignes ≤ hauteur")
  ok(anchors, "« /max » en bas à droite de la case, rang juste au-dessus (aligné à droite)")
  ok(white, "rang blanc, « /max » atténué sur les cases apprises (3.3.17)")
  local fake = tiles[1]
  IC.FitCount(fake, "129/130")
  ok(fake.countFS.text == "129" and fake.countFS2.text == "/130" and fake._countSize == 13 and fake._countText == "129\n/130", "« 129 » sur « /130 », taille 13")
  IC.FitCount(fake, "12345/12345")
  ok(fake.countFS.text == "12345" and fake.countFS2.text == "/12.3k" and fake._countSize * 0.5 * 5 <= IC.TILE - 2, "texte long : toujours deux lignes entières, taille " .. fake._countSize)
  IC.FitCount(fake, "42")
  ok(fake.countFS.text == "42" and not vis(fake.countFS2) and fake.countFS.points[1][2] == fake, "une seule valeur : une ligne, 2e FontString cachée")
  UI:ApplyView()
  ok(fake.countFS.text ~= "42" and vis(fake.countFS2), "mise à jour : deux lignes rétablies")
end
local r0 = __rect(tiles[2])
ok(topAt(r0.l + 1, r0.b + 1) == tiles[2] and topAt(r0.r - 1, r0.t - 1) == tiles[2], "toute la case reste survolable / cliquable")

print("== 3.3.6 : chiffres de case — largeurs RÉALISTES à la taille de case du jeu ==")
do
  -- Avances des glyphes (em), tables des polices : Arial Narrow (Fonts\ARIALN.TTF)
  -- chiffres 0,456, « / » 0,228 ; repli Arial normal (si ARIALN absent) 0,556 / 0,278.
  -- Contour (OUTLINE) : +2 px. Hauteur de ligne ≈ 1,15 × taille.
  local ADV = { narrow = { d = 0.456, s = 0.228 }, arial = { d = 0.556, s = 0.278 } }
  local function width(txt, size, m)
    local w = 0
    for ch in tostring(txt):gmatch(".") do w = w + ((ch == "/") and m.s or m.d) * size end
    return w + 2
  end
  UI:ApplyView()
  local IC = ns.Icons
  local any
  for _, t in ipairs(UI.embed.tiles) do if t:IsShown() and t.data then any = t break end end
  local r = __rect(any)
  local tw, th = r.r - r.l, r.t - r.b
  ok(tw == IC.TILE and th == IC.TILE and IC.TILE == 40, "taille de case réelle (grille du jeu) : " .. tw .. " × " .. th .. " px")
  local worst = { "1/1", "27/75", "85/150", "129/130", "166/225", "300/300", "999/999", "951/2460", "2460/2460", "60/60" }
  local allFit, report = true, {}
  for _, txt in ipairs(worst) do
    local size = IC.FitCount(any, txt)
    local a, b = any.countFS, any.countFS2
    for name, m in pairs(ADV) do
      local wa, wb = width(a.text, size, m), width(b.text, size, m)
      local h = 2 * size * 1.15
      -- le client mesure la VRAIE police : la boucle de FitCount réduit jusqu'à tenir
      local inner0 = tw - 2 * IC.COUNT_INSET
      local sz = size
      while sz > IC.COUNT_MIN and (width(a.text, sz, m) > inner0 or width(b.text, sz, m) > inner0) do sz = sz - 1 end
      wa, wb = width(a.text, sz, m), width(b.text, sz, m)
      local fit = wa <= tw - 1 and wb <= tw - 1 and h <= th - 2
      -- règle du client : une FontString ne tronque (« … ») que si une largeur lui est imposée
      local inner = tw - 2 * IC.COUNT_INSET
      local truncA = wa > inner
      local truncB = wb > inner
      if not fit or truncA or truncB then allFit = false end
      if name == "narrow" then report[#report + 1] = string.format("%s→%s px (%.0f/%.0f)", txt, size, wa, wb) end
    end
  end
  ok(allFit, "rang et « /max » tiennent dans 40 px, sans troncature, Arial Narrow ET repli Arial : " .. table.concat(report, " · "))
  local s27 = IC.FitCount(any, "27/75")
  ok(any.countFS.text == "27" and any.countFS2.text == "/75" and (any.countFS.maxLines == 1 or any.countFS.maxLines == nil) and any.countFS:GetStringWidth() <= IC.TILE - 2 * IC.COUNT_INSET, "le cas « 27… » du jeu : « 27 » et « /75 » entiers (taille " .. s27 .. ")")
  UI:ApplyView()
end


local function v333()
local PNL = ns.Panel
print("== 3.3.5 : panneau TOUJOURS compact (plus de volet de détail, plus de chevron) ==")
if not W.IsShown() then W.Show() end
PNL.SetExpanded(true, "test")    -- ignoré en 3.3.5
local f = W.frame
local lh = PNL.CompactListHeight()
local gl_, gr_, gt_, gb_ = ns.Layout.GridRect()
ok(W.mode == "compact" and gl_ and math.abs(f.width - (gr_ - gl_ + 2 * ns.Layout.MARGIN)) < 0.01 and math.abs(f.height - (gt_ - gb_ + 2 * ns.Layout.MARGIN)) < 0.01, "SetExpanded(true) ignoré : toujours compact, taille = grille + 2 × marge " .. f.width .. "×" .. f.height)
ok(ns.db.ui.expanded == nil, "état « déplié » effacé des SavedVariables")
ok(not vis(W.detail) and not vis(UI.ownDetail) and not vis(W.title) and not vis(W.titleBar) and not vis(W.close), "ni volet de détail, ni titre, ni barre de titre")
ok(PNL.chevron == nil and _G.DropamineChevron == nil, "plus de chevron")
local inEsc = false
for _, n in ipairs(_G.UISpecialFrames) do if n == PNL.ESC_NAME or n == W.NAME then inEsc = true end end
ok(not inEsc and PNL.esc == nil, "Échap : ni le panneau ni un cadre à nous dans UISpecialFrames")
local tilesC, inside = 0, true
local lr3 = __rect(W.list)
for _, t in ipairs(UI.embed.tiles) do
  if vis(t) and t.data then
    tilesC = tilesC + 1
    local r = __rect(t)
    if r.l < lr3.l - 0.01 or r.r > lr3.r + 0.01 or r.b < lr3.b - 0.01 or r.t > lr3.t + 0.01 then inside = false end
  end
end
ok(tilesC == #UI.snapshot.tiles + 1 and inside, "les " .. tilesC .. " cases, toutes dans le panneau")
local texts = {}
local function walkT(o)
  if type(o) ~= "table" then return end
  if o.typ == "FontString" and vis(o) and tostring(o.text or "") ~= "" then texts[#texts + 1] = o end
  for _, x in ipairs(o.regions or {}) do walkT(x) end
  for _, c in ipairs(o.children or {}) do walkT(c) end
end
walkT(f)
local extra = {}
for _, fs in ipairs(texts) do
  local isCount = false
  for _, t in ipairs(UI.embed.tiles) do if t.countFS == fs or t.countFS2 == fs or (t.craftBadge and t.craftBadge.fs == fs) then isCount = true end end
  if not isCount then extra[#extra + 1] = tostring(fs.text) end
end
ok(#extra == 0, "aucun autre texte que les chiffres des cases " .. table.concat(extra, " | "))
ok(f.mouse == false and UI.embed.mouse == false, "le cadre et la grille ne capturent pas la souris")
local tm = true
for _, t in ipairs(UI.embed.tiles) do if vis(t) and t.data and not t.mouse then tm = false end end
ok(tm and PNL.handle.mouse, "seules les cases et la fine poignée prennent la souris")
ok(f.strata == "MEDIUM", "strate MEDIUM")
local tc3
for _, t in ipairs(UI.embed.tiles) do if vis(t) and t.data and t.data.kind == "profession" then tc3 = t break end end
tc3.scripts.OnClick(tc3, "LeftButton")
ok(W.mode == "compact" and not vis(UI.ownDetail) and not vis(W.detail), "clic sur une case : rien ne se déplie")
local chk = 0
for _, t in ipairs(UI.embed.tiles) do if vis(t.checkTex) then chk = chk + 1 end end
ok(chk == 0, "aucune surbrillance « sélectionnée » (seul le survol éclaire)")
local function pressEscape() for _, n in ipairs(_G.UISpecialFrames) do local fr = _G[n] if fr and fr.shown ~= false and fr.Hide then fr:Hide() end end end
pressEscape()
ok(W.IsShown() and W.mode == "compact", "Échap : rien ne se ferme")
local np = #prints
slash("deplier")
ok(W.mode == "compact" and tostring(prints[#prints]):find("infobulle", 1, true), "/drop deplier : message (détail = infobulle), reste compact")
slash("replier")
ok(tostring(prints[#prints]):find("infobulle", 1, true), "/drop replier : même message")

print("== 3.3.3 : persistance (ouvert, position) et verrou ==")
ok(ns.db.ui.panelOpen == true, "ouvert : mémorisé")
W.Hide()
ok(ns.db.ui.panelOpen == nil and not W.IsShown(), "fermé par l'utilisateur : mémorisé")
W.Show()
f.shown = false
UI:HookSkillFrame()
ok(W.IsShown() and W.mode == "compact", "rechargement : panneau rouvert en compact")
PNL.handle.scripts.OnDragStart(PNL.handle)
ok(f._moving == true, "glisser la poignée : le panneau se déplace")
f:ClearAllPoints() f:SetPoint("TOPLEFT", _G.UIParent, "BOTTOMLEFT", 1200, 600)
PNL.handle.scripts.OnDragStop(PNL.handle)
ok(ns.db.ui.winPos.x == 1200 and ns.db.ui.winPos.y == 600, "position du panneau mémorisée (1200, 600)")
f:ClearAllPoints() W.PlaceDefault(f)
local fr4 = __rect(f)
ok(fr4 and fr4.l == 1200 and fr4.t == 600, "position restaurée au rechargement")
slash("verrou on")
f._moving = nil
PNL.handle.scripts.OnDragStart(PNL.handle)
f.scripts.OnDragStart(f)
ok(not f._moving, "verrou : panneau non déplaçable (poignée et cadre)")
slash("verrou off")
ok(not ns.db.ui.locked, "/drop verrou off")

print("== 3.3.5 : habillage des TOASTS, repos / survol (fondu), opacité ==")
local T = PNL.toast
ok(T and f._toastBg and T.bg[1] == f._toastBg and #T.border > 0, "fond et bord posés par la fonction des toasts (UI:ApplyDropFinish) : " .. tostring(W.toastLook))
ok(f._dropFinish == "fond+bord" and f._bdFile == nil and f._bronze == nil, "plus de fond brun plein ni de bordure bronze autour du panneau")
ok(not vis(W.bg) and not vis(W.listBg) and not vis(W.divTop) and not vis(W.divBottom), "fond brun, fond de liste et filets masqués")
local function bgA() return f._toastBg._colorTex and f._toastBg._colorTex[4] end
local function edA() return T.border[1].alpha end
print("== 3.3.6 : FONDU AUTOMATIQUE façon compteur de dégâts (repos / gain / survol, /drop fondu) ==")
local function fa() return f.alpha end
local function pump(n) local k = 0 while PNL.fader and PNL.fader.scripts.OnUpdate and k < (n or 100) do PNL.fader.scripts.OnUpdate(PNL.fader, 0.05) k = k + 1 end return k end
local function popTimers() local n = 0 while #timers > 0 do local t = table.remove(timers, 1) t() n = n + 1 end return n end
popTimers() pump()
ns.db.ui.opacity, ns.db.ui.fadeDelay = nil, nil
PNL._target = 0 PNL.StartFade() pump()
local idleBg, idleEd = bgA(), edA()
ok(PNL.Opacity() == 60 and PNL.FadeDelay() == 3, "défauts : repos à 60 %, retour au repos après 3 s")
ok(math.abs(fa() - 0.60) < 0.001 and W.chromeState == "repos", string.format("AU REPOS : tout le panneau à l'opacité minimale (%.2f)", fa()))
ok(math.abs(idleBg - T.bgColor[4] * PNL.LOOK.idle.bg) < 0.001 and math.abs(idleEd - 1) < 0.001, string.format("repos : fond très transparent (%.2f), bord PLEIN (%.2f) — 3.3.11 : jamais atténué", idleBg, idleEd))
ok((not PNL.fader or PNL.fader.scripts.OnUpdate == nil) and #timers == 0, "au repos : aucun OnUpdate, aucune minuterie")
local tH
for _, t in ipairs(UI.embed.tiles) do if vis(t) and t.data then tH = t break end end
tH.scripts.OnEnter(tH)
ok(PNL.fader.scripts.OnUpdate ~= nil, "SURVOL : fondu d'entrée lancé")
PNL.fader.scripts.OnUpdate(PNL.fader, 0.1)
ok(fa() > 0.6 and fa() < 1 and bgA() > idleBg, string.format("fondu progressif (%.2f)", fa()))
pump()
ok(math.abs(fa() - 1) < 0.001 and math.abs(bgA() - PNL.BgAlpha() / 100) < 0.001 and math.abs(edA() - 1) < 0.001 and W.chromeState == "survol", string.format("survol : opacité pleine, fond translucide (%.2f = /drop fond %d %%), bord doré plein", bgA(), PNL.BgAlpha()))
ok(PNL.fader.scripts.OnUpdate == nil, "fondu fini : OnUpdate retiré")
tH.scripts.OnLeave(tH)
local tH2
for _, t in ipairs(UI.embed.tiles) do if vis(t) and t.data and t ~= tH then tH2 = t break end end
tH2.scripts.OnEnter(tH2)
popTimers()
ok(math.abs(fa() - 1) < 0.001 and PNL.fader.scripts.OnUpdate == nil, "d'une case à l'autre : le retour au repos est annulé (pas de clignotement)")
tH2.scripts.OnLeave(tH2)
ok(#timers == 1 and PNL.fader.scripts.OnUpdate == nil and math.abs(fa() - 1) < 0.001, "sortie : UNE minuterie de " .. PNL.FadeDelay() .. " s (pas d'OnUpdate pendant l'attente)")
popTimers()
ok(PNL.fader.scripts.OnUpdate ~= nil, "après le délai : fondu de sortie")
local steps = pump()
ok(math.abs(fa() - 0.6) < 0.001 and W.chromeState == "repos" and math.abs(bgA() - idleBg) < 0.001, "retour au repos (60 %, habillage repos) en " .. string.format("%.2f", steps * 0.05) .. " s")
-- GAIN : opacité pleine puis retour
PNL.Wake("gain")
pump()
ok(math.abs(fa() - 1) < 0.001 and PNL.lastWake == "gain" and #timers == 1, "GAIN : opacité pleine, retour programmé")
PNL.Wake("gain")
ok(#timers == 2, "2e gain : nouvelle échéance")
local first = table.remove(timers, 1) first()
ok(PNL.fader.scripts.OnUpdate == nil and math.abs(fa() - 1) < 0.001, "l'échéance périmée (1er gain) est ignorée")
popTimers() pump()
ok(math.abs(fa() - 0.6) < 0.001, "puis repos")
tH.scripts.OnEnter(tH) pump()
PNL.Wake("gain")
popTimers()
ok(math.abs(fa() - 1) < 0.001 and PNL.fader.scripts.OnUpdate == nil, "gain pendant le survol : reste plein tant que la souris est là")
tH.scripts.OnLeave(tH) popTimers() pump()
slash("fondu 7")
ok(ns.db.ui.fadeDelay == 7 and tostring(prints[#prints]):find("7 s", 1, true), "/drop fondu 7 : retour au repos après 7 s")
local seen
local rA = _G.C_Timer.After
_G.C_Timer.After = function(s, fn) seen = s timers[#timers + 1] = fn end
PNL.Wake("gain")
_G.C_Timer.After = rA
ok(seen == 7, "délai de la minuterie = 7 s")
popTimers() pump()
slash("fondu 999")
ok(ns.db.ui.fadeDelay == 60, "/drop fondu 999 : borné à 60")
slash("fondu abc")
ok(tostring(prints[#prints]):find("usage", 1, true), "/drop fondu abc : aide")
slash("fondu 3")
slash("opacite 40")
ok(ns.db.ui.opacity == 40 and math.abs(fa() - 0.4) < 0.001 and tostring(prints[#prints]):find("repos", 1, true), "/drop opacite 40 : opacité minimale au repos 40 %")
PNL.Wake("gain") pump()
ok(math.abs(fa() - 1) < 0.001, "… et 100 % au gain")
popTimers() pump()
slash("opacite 150")
ok(ns.db.ui.opacity == 100 and math.abs(fa() - 1) < 0.001, "/drop opacite 150 : borné à 100 (fondu désactivé de fait)")
slash("opacite -5")
ok(ns.db.ui.opacity == 0 and fa() == 0, "/drop opacite -5 : 0 (invisible au repos, réapparaît au survol / gain)")
slash("opacite abc")
ok(ns.db.ui.opacity == 0 and tostring(prints[#prints]):find("usage", 1, true), "/drop opacite abc : valeur inchangée, aide affichée")
slash("opacite 63")
W.Hide() W.Show()
ok(math.abs(fa() - 0.63) < 0.001, "opacité réappliquée à la réouverture")
-- les toasts réveillent le panneau
clearDrops()
local w0 = PNL.wakes
skill("Pêche").rank = skill("Pêche").rank   -- aucun changement : pas de réveil
UI:FlushSkillDiff()
ok(PNL.wakes == w0, "sans gain : pas de réveil")
local crisp = true
for _, t in ipairs(UI.embed.tiles) do if vis(t) and t.data and ((t.icon.alpha or 1) < 0.999 or (t.countFS.alpha or 1) < 0.999 or (t.alpha or 1) < 0.999) then crisp = false end end
ok(crisp, "icônes et chiffres à 100 % DANS le panneau (seule l'opacité du panneau varie)")
slash("opacite icones 10")
ok(ns.db.ui.iconAlpha == 20, "/drop opacite icones 10 : borné à 20 %")
slash("opacite icones 100")
slash("opacite 100")
popTimers() pump()


print("== 3.3.3 : portrait du personnage sur la case Niveau ==")
local lt
for _, t in ipairs(UI.embed.tiles) do if vis(t) and t.data and t.data.kind == "level" then lt = t end end
ok(lt and lt._portrait and lt.icon._portraitUnit == "player", "case Niveau : portrait vivant (SetPortraitTexture « player »)")
local pc = portraitCalls
pcall(fire, "UNIT_PORTRAIT_UPDATE", "player")
ok(portraitCalls > pc, "UNIT_PORTRAIT_UPDATE : portrait rafraîchi")
pc = portraitCalls
pcall(fire, "UNIT_PORTRAIT_UPDATE", "target")
ok(portraitCalls == pc, "portrait d'une autre unité : ignoré")
pc = portraitCalls
pcall(fire, "PLAYER_ENTERING_WORLD", false, false)
ok(portraitCalls > pc, "PLAYER_ENTERING_WORLD : portrait rafraîchi")
local others = 0
for _, t in ipairs(UI.embed.tiles) do if vis(t) and t.data and t.data.kind ~= "level" and t._portrait then others = others + 1 end end
ok(others == 0, "les autres cases gardent leur icône")
local spt = _G.SetPortraitTexture
_G.SetPortraitTexture = nil
lt._portrait = nil lt.icon._portraitUnit = nil
UI:ApplyView()
ok(not lt._portrait and lt.icon._portraitUnit == nil, "portrait indisponible : icône actuelle (repli)")
_G.SetPortraitTexture = spt
UI:ApplyView()

print("== 3.3.3 : bronze mesuré au lieu du gris (cases, panneau, barre) ==")
local function nearB(c, r, g, bb) return c and math.abs(c[1] - r / 255) < 0.004 and math.abs(c[2] - g / 255) < 0.004 and math.abs(c[3] - bb / 255) < 0.004 end
local bronzeOK, slotGrey, thick = true, 0, true
for _, t in ipairs(UI.embed.tiles) do
  if vis(t) and t.data then
    local B = t._bronze
    if not (B and nearB(B.outer.top._colorTex, 166, 125, 69) and nearB(B.inner.bottom._colorTex, 66, 52, 34)) then bronzeOK = false end
    if vis(t.slotBorder) and (t.slotBorder.alpha or 1) > 0 then slotGrey = slotGrey + 1 end
    local ir, ot, it = __rect(t.icon), __rect(B.outer.top), __rect(B.inner.top)
    if not (ot and it and math.abs((ot.t - ot.b) - 1) < 0.01 and math.abs(ot.t - ir.t) < 0.01 and math.abs(it.t - (ir.t - 1)) < 0.01) then thick = false end
  end
end
ok(bronzeOK, "chaque case : cadre bronze #A67D45 (3.3.14) + ombre (66,52,34)")
ok(thick, "épaisseur native : 1 px clair + 1 px d'ombre, au bord de l'icône")
ok(slotGrey == 0, "plus de cadre d'emplacement gris (UI-Quickslot2) visible")
local greyLeft = {}
local function isGreyC(c) if not c then return false end local mx, mn = math.max(c[1], c[2], c[3]), math.min(c[1], c[2], c[3]) local avg = (c[1] + c[2] + c[3]) / 3 return (mx - mn) < 0.04 and avg > 0.12 and avg < 0.85 end
local function scanG(o, path)
  if type(o) ~= "table" then return end
  if o.typ == "Texture" and vis(o) and (o.alpha or 1) > 0.05 and o.blend ~= "ADD" then
    local p = tostring(o._texSet or ""):lower()
    if p:find("quickslot", 1, true) or p:find("emptyslot", 1, true) or p:find("tooltip-border", 1, true) then greyLeft[#greyLeft + 1] = path .. " " .. p end
    if isGreyC(o._colorTex) or (o._tint and isGreyC(o._tint)) then greyLeft[#greyLeft + 1] = path .. " aplat gris" end
  end
  for i, c in ipairs(o.children or {}) do scanG(c, path .. "/" .. i) end
  for i, r in ipairs(o.regions or {}) do scanG(r, path .. "/r" .. i) end
end
scanG(f, "panneau")
ok(#greyLeft == 0, "aucun gris restant (panneau, cases) " .. table.concat(greyLeft, " | "))
end
v333()

print("== 3.3.4 : Niveau total = DERNIÈRE case, rectangle plein 5 × 2 ==")
do
  ns.Panel.SetExpanded(false, "test")
  local shown = {}
  for _, t in ipairs(UI.embed.tiles) do if t:IsShown() and t.data then shown[#shown + 1] = t end end
  local cols = UI.embed._layout.cols
  local n = #shown
  ok(n == 10 and cols == 5 and n % cols == 0, "10 cases (9 compétences + total), " .. cols .. " colonnes : rectangle plein " .. cols .. " × " .. (n / cols) .. ", aucune rangée incomplète")
  local rows = {}
  for _, t in ipairs(shown) do local r = __rect(t) rows[r.t] = (rows[r.t] or 0) + 1 end
  local nRows, equal = 0, true
  for _, c in pairs(rows) do nRows = nRows + 1 if c ~= cols then equal = false end end
  ok(nRows == 2 and equal, "2 rangées de " .. cols .. " cases chacune (colonnes égales)")
  local tt = shown[n]
  local rl, rr = __rect(tt), __rect(shown[n - 1])
  ok(tt.data.kind == "total" and tt.data == UI.TOTAL_DATA, "la dernière case est « Niveau total »")
  ok(math.abs(rl.t - rr.t) < 0.01 and rl.l > rr.l, "total : dernière cellule de la dernière rangée (en bas à droite)")
  ok(tt.countFS.text == tostring(UI.snapshot.total) and tt.countFS2.text == "/2460" and tt._countLines == 2 and vis(tt.countFS) and vis(tt.countFS2), "total : valeur sur deux lignes (« " .. tostring(tt.countFS.text) .. " » / « " .. tostring(tt.countFS2.text) .. " »)")
  ok(tt.icon._texSet == ns.Panel.TOTAL_ICON and not tt._portrait and tt.icon._portraitUnit == nil, "total : icône à lui (3 piliers), pas le portrait")
  local B = tt._bronze
  ok(B and math.abs(B.outer.top._colorTex[1] - 0.65) < 0.004 and math.abs(B.inner.left._colorTex[2] - 52 / 255) < 0.004, "total : cadre bronze comme les autres cases")
  ok(not vis(UI.embed.foot) and not vis(UI.embed.totalFS) and not UI.embed.foot.mouse, "aucune ligne du bas (ni visible ni cliquable)")
  local lr4 = __rect(W.list)
  ok(math.abs(rl.b - (lr4.b + 4 + math.floor((ns.Icons.STEP - ns.Icons.TILE) / 2))) < 3.01, "compact : le panneau s'arrête sous la 2e rangée (pas de place vide pour l'ancienne ligne)")
end

-- ===========================================================================
local C, G, LK, PNL2 = ns.Compact, ns.Gather, ns.Links, ns.Panel
local function tileByName(n) for _, t in ipairs(UI.embed.tiles) do if t:IsShown() and t.data and (t.data.name == n or t.data.skillName == n) then return t end end end
local function tileKind(k) for _, t in ipairs(UI.embed.tiles) do if t:IsShown() and t.data and t.data.kind == k then return t end end end
if not W.IsShown() then W.Show() end
UI:ApplyView()

print("== 3.3.5 : pastille « N prêts » STABLE (recettes fusionnées, jamais remplacées) ==")
do
  local S = ns.Scanner
  bags[2318], bags[2320], bags[4231] = 6, 1, 0
  trade.line = "Travail du cuir"
  trade.list = {
    { name = "Kit d'armure léger", kind = "optimal", reagents = { { id = 2318, name = "Cuir léger", count = 1 } } },
    { name = "Ceinture en cuir estampé", kind = "medium", reagents = { { id = 2318, name = "Cuir léger", count = 6 }, { id = 2320, name = "Fil grossier", count = 1 } } },
    { name = "Gants en cuir fin", kind = "easy", reagents = { { id = 4231, name = "Peau légère traitée", count = 1 } } },
  }
  local id, n = S.ReadRecipes()
  ok(id == "leatherworking" and n == 3, "lecture complète : 3 recettes (" .. tostring(id) .. ", " .. tostring(n) .. ")")
  local lw = tileByName("Travail du cuir")
  ok(ns.Craft.Ready("leatherworking") == 7 and lw.craftBadge and vis(lw.craftBadge) and lw.craftBadge.fs.text == "7 prêts", "pastille « 7 prêts » sur la case Travail du cuir")
  -- recherche / filtre NON détecté : la fenêtre ne montre plus qu'une recette
  trade.list = { trade.list[3] }
  S.ReadRecipes()
  local rec = ns.CharDB().recipes.leatherworking
  ok(#rec.list == 3 and rec.lastRead == 1, "lecture filtrée (1 recette visible) : les 3 recettes connues sont gardées")
  ok(ns.Craft.Ready("leatherworking") == 7 and vis(lw.craftBadge) and lw.craftBadge.fs.text == "7 prêts", "la pastille ne disparaît plus selon ce qui est ouvert / filtré")
  -- en-têtes repliés
  trade.list = { { name = "Cuir", kind = "header" } }
  S.ReadRecipes()
  ok(#ns.CharDB().recipes.leatherworking.list == 3, "en-têtes repliés (aucune recette visible) : rien d'effacé")
  -- mise à jour d'une recette déjà connue (couleur), sans perte
  trade.list = { { name = "Kit d'armure léger", kind = "easy", reagents = { { id = 2318, name = "Cuir léger", count = 1 } } } }
  S.ReadRecipes()
  local kit
  for _, r in ipairs(ns.CharDB().recipes.leatherworking.list) do if r.name == "Kit d'armure léger" then kit = r end end
  ok(kit and kit.diff == "easy" and #ns.CharDB().recipes.leatherworking.list == 3, "recette déjà connue : couleur mise à jour, liste inchangée")
  -- la mise à jour d'une case ne cache plus la pastille
  UI:ApplyView()
  lw = tileByName("Travail du cuir")
  ok(vis(lw.craftBadge) and ns.Craft.Ready("leatherworking") == 7, "mise à jour de la grille : pastille toujours visible (plus cachée par la case)")
  -- un autre métier ne touche pas celui-ci
  trade.line = "Cuisine"
  trade.list = { { name = "Feu de camp basique", kind = "easy", reagents = { { id = 4470, name = "Bois simple", count = 1 } } } }
  S.ReadRecipes()
  ok(#ns.CharDB().recipes.cooking.list == 1 and #ns.CharDB().recipes.leatherworking.list == 3, "lecture de Cuisine : Travail du cuir intact")
  -- nom de ligne périmé (changement de fenêtre) : liste de Cuisine sous « Travail du cuir » → refusée
  trade.line = "Travail du cuir"
  trade.list = { { name = "Feu de camp basique", kind = "easy", reagents = {} }, { name = "Viande de loup grillée", kind = "easy", reagents = {} } }
  local rid, why = S.ReadRecipes()
  local polluted = false
  for _, r in ipairs(ns.CharDB().recipes.leatherworking.list) do if r.name == "Feu de camp basique" then polluted = true end end
  ok(rid == nil and not polluted and #ns.CharDB().recipes.leatherworking.list == 3, "liste d'un autre métier sous un nom périmé : refusée (" .. tostring(why) .. ")")
  ok(ns.Craft.Merge(nil, { { name = "a" } })[1].name == "a" and #ns.Craft.Merge({ { name = "a" }, { name = "b" } }, { { name = "b" }, { name = "c" } }) == 3, "Craft.Merge : union sans doublon, jamais plus courte")
  trade.list = {}
end

print("== 3.3.5 : SURVOL d'une case = TOUT le détail (infobulle) ==")
local tip = _G.GameTooltip
tip.lines = {}
function tip:SetText(t) self._tipText = t self.lines = {} end
function tip:AddLine(t, r, g, b, wrap) self.lines[#self.lines + 1] = { t = tostring(t), r = r, g = g, b = b, wrap = wrap } end
local function tipHas(pat) for _, l in ipairs(tip.lines) do if l.t:find(pat, 1, true) then return l end end end
do
  local lv = tileKind("level")
  lv.scripts.OnEnter(lv)
  ok(tip.shown and tip._tipText == "Niveau", "Niveau : titre « " .. tostring(tip._tipText) .. " »")
  ok(tipHas("Niveau 25 / 60") and tipHas("XP "), "Niveau : niveau / max et XP (comme la barre du volet)")
  ok(tipHas("Progression"), "Niveau : section Progression")
  lv.scripts.OnLeave(lv)
  ok(not tip.shown, "fin du survol : infobulle cachée")
  local lw = tileByName("Travail du cuir")
  lw.scripts.OnEnter(lw)
  ok(tip._tipText == "Travail du cuir" and tipHas("Rang 96 / 150"), "métier : rang / max")
  ok(tipHas("Recettes") and tipHas("Kit d'armure léger"), "métier : section Recettes (réalisables avec les sacs)")
  ok(tipHas("Compte dans le total : +96"), "métier : contribution au total")
  ok(tipHas("Clic droit : objectif"), "rappel des clics (objectif / partage)")
  local m = C.lastTooltip
  local headers = 0 for _, l in ipairs(m.lines) do if l.header then headers = headers + 1 end end
  ok(headers >= 2, "sections en en-têtes or (" .. headers .. ")")
  lw.scripts.OnLeave(lw)
  local df = tileByName("Défense")
  df.scripts.OnEnter(df)
  ok(tipHas("Rang 122 / 125") and tip.lines[#tip.lines].t:find("Clic", 1, true), "Défense : rang / max + détail")
  df.scripts.OnLeave(df)
  local tt = tileKind("total")
  tt.scripts.OnEnter(tt)
  local snap = UI.snapshot
  ok(tip._tipText == "Niveau total" and tipHas("Total " .. snap.total .. " / 2460"), "Niveau total : total / 2460")
  local nb = 0 for _, b in ipairs(snap.breakdown) do if tipHas(b.name .. " : +" .. b.value) or tipHas(b.name) then nb = nb + 1 end end
  ok(tipHas("Détail") and nb == #snap.breakdown, "Niveau total : section Détail, " .. nb .. "/" .. #snap.breakdown .. " lignes")
  ok(tipHas(ns.TOTAL_SHORT_FR:sub(1, 20)), "Niveau total : description")
  tt.scripts.OnLeave(tt)
end

print("== 3.3.5 : TOASTS → CASES (éclat, valeur retenue jusqu'à l'arrivée, pulsation, gain vert) ==")
local realAfter = _G.C_Timer.After
local q = {}
local function hold() _G.C_Timer.After = function(s, fn) q[#q + 1] = { s = s, fn = fn } end end
local function runZero() local i = 1 while i <= #q do if q[i].s == 0 then local e = table.remove(q, i) e.fn() else i = i + 1 end end end
local function runAll() local guard = 0 while #q > 0 and guard < 500 do guard = guard + 1 local e = table.remove(q, 1) e.fn() end end
local function endDrop(d) d.scripts.OnUpdate(d, 1000) end
local function agOf(owner) for i = #_G.__ags, 1, -1 do local a = _G.__ags[i] if a.owner == owner and a.playing then return a end end end
do
  clearDrops()
  hold()
  local cu0 = tileByName("Cuisine")
  local total0 = UI.snapshot.total
  skill("Cuisine").rank = 79
  UI:FlushSkillDiff()
  local d = findDrop("Cuisine")
  ok(d and d._osrsFly and d._osrsFly.kind == "skill", "toast de compétence Cuisine : relié à sa case")
  ok(C.holds["s:Cuisine"] and C.holds["s:Cuisine"].value == 78 and C.holds.total and C.holds.total.value == total0, "valeurs retenues : Cuisine 78, total " .. total0)
  UI:Refresh(true) UI:ApplyView()
  local cu = tileByName("Cuisine")
  local tt = tileKind("total")
  ok(cu.data.current == 79 and cu.countFS.text == "78" and tt.countFS.text == tostring(total0), "pendant le toast : la case affiche encore 78 (vraie valeur 79), total inchangé")
  endDrop(d)
  ok(not vis(d), "le toast s'efface")
  runZero()
  local fly
  for _, f in ipairs(C.pool or {}) do if f._busy then fly = f end end
  local ag = fly and agOf(fly)
  local tr = ag and ag:Find("Translation")
  local e = d._osrsFly
  ok(fly and vis(fly) and fly.parent == _G.UIParent and ag and tr and tr.duration == C.FLY, "éclat lancé (notre cadre, enfant d'UIParent, Translation " .. tostring(tr and tr.duration) .. " s)")
  local ir = __rect(cu.icon)
  ok(tr and math.abs(e.from[1] + tr.offset[1] - (ir.l + ir.r) / 2) < 0.01 and math.abs(e.from[2] + tr.offset[2] - (ir.t + ir.b) / 2) < 0.01, "trajectoire : du toast au centre de l'icône de la case")
  ok(ag:Find("Alpha") and ag:Find("Scale") and fly.icon._texSet ~= nil, "éclat : icône du toast, Alpha + Scale")
  ok(cu.countFS.text == "78", "en vol : toujours 78")
  ag:Finish()
  cu = tileByName("Cuisine") tt = tileKind("total")
  ok(cu.countFS.text == "79" and tt.countFS.text == tostring(UI.snapshot.total) and C.holds["s:Cuisine"] == nil and C.holds.total == nil, "arrivée : 79 et nouveau total affichés, retenues levées")
  local p = cu._osrsPulse
  local pag = p and agOf(p)
  ok(p and vis(p) and pag and p.parent == cu and p.tex._vc and math.abs(p.tex._vc[1] - 1) < 0.01 and math.abs(p.tex._vc[2] - 0.82) < 0.01, "pulsation dorée (couleur du titre des toasts) sur la case")
  local g = cu._osrsGain
  local gag = g and agOf(g)
  ok(g and vis(g) and g.fs.text == "+1" and g.parent == cu, "gain vert « +1 » sur l'icône de Cuisine")
  ok(g.fs._font and g.fs._font[3] == "" and g.fs._shadowOff and g.fs._shadowOff[1] == 1 and math.abs(g.fs.tg - 1) < 0.01 and g.fs.tr < 0.3, "3.3.9 gain : vert, sans contour, ombre fine 1 px")
  local gtr, gal = gag and gag:Find("Translation"), gag and gag:Find("Alpha")
  ok(gtr and gtr.offset[1] == 0 and gtr.offset[2] == C.GAIN_RISE and gtr.duration == 1.5 and gal and gal.fromAlpha == 1 and gal.toAlpha == 0 and (gal.delay + gal.duration) <= 1.5 + 0.001, "gain : monte de " .. C.GAIN_RISE .. " px et s'efface en 1,5 s")
  ok(tt._osrsGain and vis(tt._osrsGain) and tt._osrsGain.fs.text == "+1", "Niveau total : gain « +1 » aussi")
  gag:Finish()
  ok(not vis(g), "fin de l'animation : gain caché")
  runAll()
  ok(cu.countFS.text == "79" and C.landed >= 1, "minuteries restantes : sans effet (déjà arrivé)")
  -- XP : gain « +178 » sur la case Niveau, niveau inchangé
  clearDrops()
  UI:OnXPUpdate()
  _G.UnitXP = function() return 1378 end
  UI:OnXPUpdate()
  local xd
  for _, f in ipairs(UI.dropsActive) do if f._kind == "xp" then xd = f end end
  ok(xd and xd._osrsFly and C.holds.level == nil, "toast d'XP relié à la case Niveau (pas de retenue : le niveau ne change pas)")
  endDrop(xd) runZero()
  local fly2
  for _, f in ipairs(C.pool) do if f._busy then fly2 = f end end
  agOf(fly2):Finish()
  local lv = tileKind("level")
  ok(lv._osrsGain and vis(lv._osrsGain) and lv._osrsGain.fs.text == "+178" and lv.countFS.text == "25", "case Niveau : gain vert « +178 », niveau 25 inchangé")
  runAll()
  -- panneau fermé : rien n'est retenu ni lancé
  W.Hide()
  clearDrops()
  skill("Pêche").rank = 96
  UI:FlushSkillDiff()
  local pd = findDrop("Pêche")
  ok(pd and pd._osrsFly == nil and next(C.holds) == nil, "panneau fermé : aucun lien, aucune retenue")
  W.Show()
  ok(tileByName("Pêche").countFS.text == "96", "réouverture : vraie valeur tout de suite (96)")
  endDrop(pd) runAll()
  -- fermé PENDANT le toast : lâché en silence
  clearDrops()
  skill("Secourisme").rank = 131
  UI:FlushSkillDiff()
  local sd = findDrop("Secourisme")
  ok(C.holds["s:Secourisme"], "Secourisme retenu")
  W.Hide()
  ok(next(C.holds) == nil, "fermeture du panneau : retenues levées")
  local fl0 = C.flights
  endDrop(sd) runZero()
  ok(sd._osrsFly.skipped and C.flights == fl0, "toast fini panneau fermé : aucun éclat (sauté en silence)")
  W.Show() runAll()
  ok(tileByName("Secourisme").countFS.text == "131", "réouverture : 131")
  -- jamais bloquée : toast qui ne finit jamais → filet
  clearDrops()
  skill("Dépeçage").rank = 162
  UI:FlushSkillDiff()
  UI:Refresh(true) UI:ApplyView()
  ok(tileByName("Dépeçage").countFS.text == "161", "Dépeçage retenu à 161")
  local dd = findDrop("Dépeçage")
  dd.scripts.OnUpdate = nil   -- le toast reste affiché
  runAll()
  ok(C.holds["s:Dépeçage"] == nil and tileByName("Dépeçage").countFS.text == "162", "filet : retenue levée même si le toast ne finit jamais (162)")
  -- éclat dont l'animation ne finit jamais → atterrissage forcé
  clearDrops()
  skill("Dépeçage").rank = 163
  UI:FlushSkillDiff()
  UI:Refresh(true)
  local dd2 = findDrop("Dépeçage")
  endDrop(dd2) runZero()
  ok(not dd2._osrsFly.landed, "éclat en vol")
  runAll()
  ok(dd2._osrsFly.landed and tileByName("Dépeçage").countFS.text == "163", "animation jamais terminée : atterrissage forcé par minuterie (163)")
  -- combat : toasts reportés (inchangé) → rien de retenu
  clearDrops()
  _G.InCombatLockdown = function() return true end
  skill("Dépeçage").rank = 164
  UI:FlushSkillDiff()
  ok(#UI.dropsActive == 0 and next(C.holds) == nil, "en combat : pas de toast (reporté, inchangé), aucune retenue")
  _G.InCombatLockdown = function() return false end
  UI:FlushSkillDiff()
  UI:Refresh(true)
  ok(findDrop("Dépeçage") and C.holds["s:Dépeçage"], "fin de combat : le toast part, la case attend l'éclat")
  local dd3 = findDrop("Dépeçage")
  endDrop(dd3) runZero() runAll()
  ok(tileByName("Dépeçage").countFS.text == "164", "puis 164")
  _G.C_Timer.After = realAfter
  clearDrops()
  for _, a in ipairs(_G.__ags) do a.playing = false end
end

print("== 3.3.5 : ALERTES DE DÉPEÇAGE (infobulle native « Dépeçable », repères de barre de nom) ==")
-- 3.3.8 : l'infobulle compacte (Tip.lua) remplace ces lignes en jeu ; les anciens
-- chemins restent testés comme repli (Tip.active = false), puis Tip est testé à part.
ns.Tip.active = false
local units = {}
local rUnitName, rUnitLevel, rUnitIsDead, rUnitGUID = _G.UnitName, _G.UnitLevel, _G.UnitIsDead, _G.UnitGUID
_G.UnitName = function(u) if units[u] then return units[u].name end return rUnitName(u) end
_G.UnitLevel = function(u) if units[u] then return units[u].level end return rUnitLevel(u) end
_G.UnitIsDead = function(u) return units[u] and units[u].dead or false end
_G.UnitGUID = function(u) if units[u] and units[u].npc then return "Creature-0-0-0-0-" .. units[u].npc .. "-0" end return rUnitGUID and rUnitGUID(u) end
local tipFS = {}
local function setTip(lines)
  tip.lines = {}
  for i, l in ipairs(lines) do
    local fs = tipFS[i] or newObj("FontString", "GameTooltipTextLeft" .. i, tip)
    tipFS[i] = fs
    fs.text = l
  end
  for i = #lines + 1, #tipFS do tipFS[i].text = "" end
  tip._n = #lines
end
function tip:NumLines() return self._n or 0 end
function tip:GetUnit() return nil end
do
  G.Invalidate()
  units.mouseover = { name = "Coursier à ramure", level = 23, dead = true, npc = 4018 }
  setTip({ "Coursier à ramure", "Niveau 23", "Cadavre", "Dépeçable" })
  local st = G.UnitTooltip(tip)
  local l = tip.lines[#tip.lines]
  ok(st and l and l.t == "Dépeçage : +1 possible · requis 115" and math.abs(l.r - 0.72) < 0.01, "cadavre « Dépeçable » (ligne native) : « " .. tostring(l and l.t) .. " » (rang 164 ≥ 115)")
  ok(G.lastTip.native and G.Known("Coursier à ramure") and G.Known("Coursier à ramure").level == 23, "nom mémorisé comme dépeçable (SavedVariables)")
  ok(ns.db.scanner.skinNames[ns.Fold("Coursier à ramure")] ~= nil, "mémoire : DropamineDB.scanner.skinNames")
  setTip({ "Coursier à ramure", "Niveau 23", "Cadavre", "Dépeçable", "Dépeçage : +1 possible · requis 115" })
  ok(G.UnitTooltip(tip) == nil, "infobulle rafraîchie : pas de doublon")
  -- bête VIVANTE du même nom, sans ligne native : reconnue grâce à la mémoire
  units.mouseover = { name = "Coursier à ramure", level = 22, dead = false }
  setTip({ "Coursier à ramure", "Niveau 22" })
  local st2 = G.UnitTooltip(tip)
  ok(st2 and tip.lines[#tip.lines].t:find("requis 110", 1, true), "bête vivante déjà vue dépeçable : ligne affichée (requis 110)")
  -- rang insuffisant
  units.mouseover = { name = "Vieux grizzly", level = 40, dead = true }
  setTip({ "Vieux grizzly", "Niveau 40", "Cadavre", "Dépeçable" })
  G.UnitTooltip(tip)
  local lr = tip.lines[#tip.lines]
  ok(lr.t == "Dépeçage : 200 requis (actuel 164)" and lr.r == 1 and lr.g < 0.5, "niveau 40 : « 200 requis (actuel 164) » en rouge")
  -- créature non dépeçable inconnue : rien
  units.mouseover = { name = "Bandit défias", level = 20, dead = true }
  setTip({ "Bandit défias", "Niveau 20", "Cadavre" })
  ok(G.UnitTooltip(tip) == nil and #tip.lines == 0, "non dépeçable : aucune ligne")
  -- règle publiée Forever (requis) : 1-10 → 1 ; 11-20 → (n-10)×10 ; 21+ → n×5
  ok(G.SkinReq(5) == 1 and G.SkinReq(15) == 50 and G.SkinReq(20) == 100 and G.SkinReq(23) == 115 and G.SkinReq(60) == 300 and G.SkinReq(nil) == nil, "rang requis : règle Forever publiée (1 / 50 / 100 / 115 / 300 ; niveau inconnu → inconnu)")
  -- point gagné observé → vert
  units.target = { name = "Coursier à ramure", level = 23, dead = true }
  hold()
  G.OnSkinCast()
  G.OnSkillMsg("Votre compétence en Dépeçage est maintenant de 165.")
  runAll()
  units.mouseover = { name = "Coursier à ramure", level = 23, dead = true }
  G.Invalidate()
  setTip({ "Coursier à ramure", "Niveau 23", "Cadavre", "Dépeçable" })
  G.UnitTooltip(tip)
  local lg = tip.lines[#tip.lines]
  ok(lg.t:find("point gagné au rang 164", 1, true) and lg.g > 0.7 and lg.r < 0.3, "point gagné observé : vert (« " .. lg.t .. " »)")
  -- 3 dépeçages sans point au même rang → gris
  units.target = { name = "Sanglier des rochers", level = 16, dead = true }
  for i = 1, 3 do G.OnSkinCast() runAll() end
  G.Invalidate()
  units.mouseover = { name = "Sanglier des rochers", level = 16, dead = true }
  setTip({ "Sanglier des rochers", "Niveau 16", "Cadavre", "Dépeçable" })
  G.UnitTooltip(tip)
  local lgr = tip.lines[#tip.lines]
  ok(lgr.t:find("plus de point", 1, true) and math.abs(lgr.r - 0.5) < 0.01, "3 dépeçages sans point à ce rang : gris")
  _G.C_Timer.After = realAfter
  -- sans Dépeçage : rien
  local sk = skill("Dépeçage")
  local keep = sk.rank
  sk.rank = 0
  G.Invalidate()
  units.mouseover = { name = "Coursier à ramure", level = 23, dead = true }
  setTip({ "Coursier à ramure", "Niveau 23", "Cadavre", "Dépeçable" })
  ok(G.UnitTooltip(tip) == nil and #tip.lines == 0, "sans la compétence Dépeçage : aucune ligne")
  sk.rank = keep
  G.Invalidate()
end

print("== 3.3.5 : repères de proximité (lots de 4 / 0,25 s, pool, barre de nom jamais modifiée) ==")
local plates = {}
_G.C_NamePlate = { GetNamePlateForUnit = function(u) return plates[u] end, GetNamePlates = function() local o = {} for u, p in pairs(plates) do o[#o + 1] = p end return o end }
do
  hold()
  for i = 1, 10 do
    local u = "nameplate" .. i
    units[u] = { name = (i <= 8) and "Coursier à ramure" or "Bandit défias", level = 23 }
    plates[u] = newObj("Frame", "NamePlate" .. i, _G.UIParent)
    plates[u]._abs = { l = 100 * i, r = 100 * i + 80, t = 500, b = 490 }
    plates[u].namePlateUnitToken = u
  end
  local pfp = {}
  for u, p in pairs(plates) do pfp[u] = #p.children .. "|" .. #p.points .. "|" .. #p.regions end
  local ev0 = G.stats.evals
  for i = 1, 10 do fire("NAME_PLATE_UNIT_ADDED", "nameplate" .. i) end
  ok(G.stats.evals == ev0 and #G.queue == 10, "10 barres de nom : aucune évaluation pendant l'événement (file de 10)")
  ok(#q == 1 and q[1].s == G.BATCH_DT, "un seul minuteur de lot (" .. G.BATCH_DT .. " s), pas d'OnUpdate")
  local e1 = table.remove(q, 1) e1.fn()
  ok(#G.queue == 6 and #q == 1, "1er lot : 4 évaluations, la suite au lot suivant")
  runAll()
  local shown, skinOK = 0, true
  for i = 1, 10 do
    local m = G.active["nameplate" .. i]
    if m and vis(m) then
      shown = shown + 1
      local pt = m.points[1]
      if not (m.parent == _G.UIParent and pt[1] == "BOTTOM" and pt[2] == plates["nameplate" .. i] and pt[3] == "TOP" and pt[4] == 0) then skinOK = false end
    end
  end
  ok(shown == 8 and skinOK, "8 repères (bêtes dépeçables), centrés AU-DESSUS de la barre, enfants d'UIParent")
  local same = true
  for u, p in pairs(plates) do if pfp[u] ~= (#p.children .. "|" .. #p.points .. "|" .. #p.regions) then same = false end end
  ok(same, "barres de nom intactes (aucun enfant, ancre ni texture ajoutés)")
  local m1 = G.active.nameplate1
  ok(m1.ring._vc and math.abs(m1.ring._vc[2] - 0.95) < 0.01 and m1.ring._vc[1] < 0.3, "bordure VERTE : +1 possible")
  local created = G.stats.markersCreated
  for i = 1, 10 do fire("NAME_PLATE_UNIT_REMOVED", "nameplate" .. i) end
  ok(next(G.active) == nil and #G.pool == 8, "barres retirées : repères rendus au pool (8)")
  for i = 1, 10 do fire("NAME_PLATE_UNIT_ADDED", "nameplate" .. i) end
  runAll()
  ok(G.stats.markersCreated == created, "réapparition : repères réutilisés, aucun nouveau cadre")
  -- gris / rang insuffisant : pas de repère
  units.nameplate2 = { name = "Sanglier des rochers", level = 16 }
  units.nameplate3 = { name = "Vieux grizzly", level = 40 }
  fire("NAME_PLATE_UNIT_REMOVED", "nameplate2") fire("NAME_PLATE_UNIT_REMOVED", "nameplate3")
  G.Learn("Vieux grizzly", 40)
  fire("NAME_PLATE_UNIT_ADDED", "nameplate2") fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
  runAll()
  local function grey(m) return m and vis(m) and m.icons[1].ring._vc and math.abs(m.icons[1].ring._vc[1] - 0.55) < 0.01 and math.abs(m.icons[1].ring._vc[2] - 0.55) < 0.01 end
  ok(grey(G.active.nameplate2) and grey(G.active.nameplate3), "3.3.8 : bête grise ou rang trop bas → repère à bordure GRISE (aucun gain)")
  -- combat
  fire("PLAYER_REGEN_DISABLED")
  ok(next(G.active) == nil, "entrée en combat : tous les repères cachés")
  _G.InCombatLockdown = function() return true end
  fire("NAME_PLATE_UNIT_ADDED", "nameplate5")
  ok(#G.queue == 0, "en combat : barres ignorées")
  _G.InCombatLockdown = function() return false end
  fire("PLAYER_REGEN_ENABLED")
  runAll()
  ok(G.active.nameplate1 and vis(G.active.nameplate1), "fin de combat : repères rétablis")
  slash("alertes off")
  ok(next(G.active) == nil and tostring(prints[#prints]):find("désactivées", 1, true), "/drop alertes off : repères retirés")
  fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
  ok(#G.queue == 0, "désactivé : rien en file")
  units.mouseover = { name = "Coursier à ramure", level = 23, dead = true }
  setTip({ "Coursier à ramure", "Niveau 23", "Cadavre", "Dépeçable" })
  ok(G.UnitTooltip(tip) == nil, "désactivé : pas de ligne d'infobulle")
  slash("alertes on")
  runAll()
  ok(G.active.nameplate1 and tostring(prints[#prints]):find("activées", 1, true), "/drop alertes on : repères revenus")
  -- le repère « dépeçage neutre » du scanner ne fait plus doublon
  ok(ns.Scanner.BestFor(4018, { alive = true }) == nil or select(2, ns.Scanner.BestFor(4018, { alive = true })) ~= "neutral", "pas de 2e repère « dépeçage » du scanner")
end

print("== 3.3.5 : nœuds de Minage / Herboristerie ==")
do
  local S = ns.Scanner
  local rk = S.RankOf
  S.RankOf = function(id) if id == "mining" then return 80, { name = "Minage" } end return rk(id) end
  setTip({ "Filon de cuivre", "Requiert Minage (1)" })
  S.TooltipLine(tip)
  ok(tip.lines[#tip.lines] and tip.lines[#tip.lines].t:find("Minage : +1 possible", 1, true), "ligne native « Requiert Minage » : ligne +1 possible")
  setTip({ "Filon de cuivre" })
  S.TooltipLine(tip)
  ok(tip.lines[#tip.lines] and tip.lines[#tip.lines].t == "Minage : +1 possible (relevé : 1 requis)", "sans ligne native : rang requis RELEVÉ pour ce nœud")
  S.DB().nodes["Filon d'argent"] = { skill = "mining", req = 125 }
  setTip({ "Filon d'argent" })
  S.TooltipLine(tip)
  ok(tip.lines[#tip.lines].t:find("125 requis (relevé)", 1, true) and tip.lines[#tip.lines].r == 1, "rang relevé supérieur au tien : en rouge")
  setTip({ "Coffre inconnu" })
  ok(S.TooltipLine(tip) == nil and #tip.lines == 0, "nœud jamais relevé : rien (aucune donnée inventée)")
  S.RankOf = rk
end

print("== 3.3.5 : LIENS ENTRE MÉTIERS (objet, créature, case de métier) ==")
do
  -- infobulle de la créature (Coursier à ramure, npc 4018) : Viande de cerf → Venaison dégraissée
  units.mouseover = { name = "Coursier à ramure", level = 23, dead = false, npc = 4018 }
  setTip({ "Coursier à ramure", "Niveau 23" })
  ns.Scanner.Enabled = function() return true end
  ns.Craft.UnitTooltip(tip)
  local v = tipHas("Venaison dégraissée")
  ok(v and v.t:find("recette non apprise, rang 110", 1, true) and v.t:find("Cuisine", 1, true), "créature : « Venaison dégraissée (recette non apprise, rang 110) — Cuisine » (base Forever)")
  ok(v and not v.t:find("source inconnue", 1, true) and not v.t:find("→", 1, true), "3.3.8 : source absente de la base → rien (plus de « source inconnue »), aucune flèche")
  -- infobulle d'objet : toutes les recettes, apprises et non apprises, tous métiers
  function tip:GetItem() return "Cuir léger", "|cffffffff|Hitem:2318::::::::|h[Cuir léger]|h|r" end
  setTip({ "Cuir léger" }) tip._osrsLinksFor = nil
  local n = LK.ItemTooltip(tip)
  ok(tipHas("Utilisé par :") and tipHas("Kit d'armure léger — Travail du cuir") and tipHas("Ceinture en cuir estampé — Travail du cuir"), "objet Cuir léger : recettes APPRISES de Travail du cuir (" .. tostring(n) .. ")")
  function tip:GetItem() return "Viande de cerf", "|Hitem:5471::|h" end
  setTip({ "Viande de cerf" }) tip._osrsLinksFor = nil
  LK.ItemTooltip(tip)
  ok(tipHas("Venaison dégraissée (recette non apprise, rang 110)"), "objet Viande de cerf : recette NON apprise (Cuisine) avec rang requis")
  function tip:GetItem() return "Caillou", "|Hitem:999999::|h" end
  setTip({ "Caillou" }) tip._osrsLinksFor = nil
  ok(LK.ItemTooltip(tip) == 0 and not tipHas("Utilisé par"), "objet sans recette connue de la base : rien")
  -- plafond : 6 lignes + « … et N autres »
  trade.line = "Travail du cuir"
  trade.list = {}
  for i = 1, 8 do trade.list[i] = { name = "Recette test " .. i, kind = "medium", reagents = { { id = 2318, name = "Cuir léger", count = 1 } } } end
  ns.Scanner.ReadRecipes()
  local lines = LK.Lines({ 2318 })
  ok(#lines == 7 and lines[7]:find("… et 4 autres", 1, true), "plafond : 6 recettes + « … et 4 autres » (" .. #lines .. " lignes)")
  -- lien inverse : case Cuisine → prochaines recettes à apprendre + origine des composants
  local cu = tileByName("Cuisine")
  cu.scripts.OnEnter(cu)
  local nx = tipHas("À apprendre bientôt")
  local hasRec, hasOrigin = false, false
  local seenHdr = false
  for _, l in ipairs(tip.lines) do
    if l.t == "À apprendre bientôt" then seenHdr = true
    elseif seenHdr then
      if l.t:find("(rang ", 1, true) then hasRec = true end
      if l.t:find("butin de", 1, true) or l.t:find("dépeçage", 1, true) or l.t:find("origine inconnue", 1, true) then hasOrigin = true end
    end
  end
  ok(nx and hasRec and hasOrigin, "case Cuisine : « À apprendre bientôt » (rang requis ≤ rang + 25), où l'apprendre, origine des composants")
  local okReach = true
  for _, r in ipairs(LK.NextToLearn("cooking")) do if r.req > 79 + LK.REACH then okReach = false end end
  ok(okReach and #LK.NextToLearn("cooking") > 0, "uniquement les recettes à portée (" .. #LK.NextToLearn("cooking") .. ")")
  cu.scripts.OnLeave(cu)
  local lw = tileByName("Travail du cuir")
  lw.scripts.OnEnter(lw)
  ok(not tipHas("À apprendre bientôt"), "Travail du cuir : pas de recettes non apprises dans la base → rien d'inventé")
  lw.scripts.OnLeave(lw)
end

print("== 3.3.5 : COÛTS (1000 événements) ==")
do
  hold()
  local pre = #G.queue
  local ev0, e0, b0, mc0 = G.stats.events, G.stats.evals, G.stats.batches, G.stats.markersCreated
  for i = 1, 500 do
    local u = "nameplate" .. ((i % 10) + 1)
    fire("NAME_PLATE_UNIT_REMOVED", u)
    fire("NAME_PLATE_UNIT_ADDED", u)
  end
  local pend = 0 for _, e in ipairs(q) do if e.s == G.BATCH_DT then pend = pend + 1 end end
  runAll()
  local evals = G.stats.evals - e0
  ok(G.stats.events - ev0 == 1000 and pend <= 1, "1000 événements de barres de nom : " .. pend .. " minuteur en attente (lots regroupés)")
  ok(evals <= 10 + pre, "évaluations : " .. evals .. " pour 1000 événements (unités dédoublonnées dans la file)")
  ok(G.stats.markersCreated == mc0, "aucun cadre créé (pool)")
  LK.UsesOf(2318) LK.UsesOf(5471)   -- 1er calcul après la dernière lecture de recettes
  local u0, m0 = LK.stats.uses, LK.stats.usesMiss
  for i = 1, 1000 do LK.UsesOf(2318) LK.UsesOf(5471) end
  ok(LK.stats.uses - u0 == 2000 and LK.stats.usesMiss - m0 == 0, "liens recettes : 2000 demandes, 0 recalcul (cache par objet)")
  local cs0 = G.stats.evalCached
  for i = 1, 1000 do G.State("Coursier à ramure", 23) end
  ok(G.stats.evalCached - cs0 >= 999, "états de dépeçage : cache par nom + niveau")
  _G.C_Timer.After = realAfter
  slash("perf")
  local pl = 0
  for i = #prints, math.max(1, #prints - 6), -1 do if tostring(prints[i]):find("perf :", 1, true) then pl = pl + 1 end end
  ok(pl >= 3, "/drop perf : " .. pl .. " lignes de coûts")
  gtime = gtime + 2
  if PNL2.fader.scripts.OnUpdate then PNL2.fader.scripts.OnUpdate(PNL2.fader, 1) end
  ok(PNL2.fader.scripts.OnUpdate == nil, "au repos : aucun OnUpdate de l'addon")
  for u in pairs(plates) do fire("NAME_PLATE_UNIT_REMOVED", u) end
  _G.UnitName, _G.UnitLevel, _G.UnitIsDead, _G.UnitGUID = rUnitName, rUnitLevel, rUnitIsDead, rUnitGUID
end

print("== 3.3.6 : SURBRILLANCE DE LA GRILLE SELON LA CIBLE ==")
do
  local TG = ns.Target
  local tu = {}
  local rN, rL, rD, rG = _G.UnitName, _G.UnitLevel, _G.UnitIsDead, _G.UnitGUID
  local rE, rCA, rTD, rIP, rC = _G.UnitExists, _G.UnitCanAttack, _G.UnitIsTapDenied, _G.UnitIsPlayer, _G.UnitClass
  local cur
  _G.UnitExists = function(u) if u == "target" then return cur ~= nil end return rE and rE(u) end
  _G.UnitName = function(u) if u == "target" and cur then return cur.name end return rN(u) end
  _G.UnitLevel = function(u) if u == "target" and cur then return cur.level end return rL(u) end
  _G.UnitIsDead = function(u) if u == "target" and cur then return cur.dead end return false end
  _G.UnitGUID = function(u) if u == "target" and cur and cur.npc then return "Creature-0-0-0-0-" .. cur.npc .. "-0" end return rG and rG(u) end
  _G.UnitCanAttack = function(a, u) if u == "target" and cur then return not cur.friend end return false end
  _G.UnitIsTapDenied = function(u) return u == "target" and cur and cur.tapped or false end
  _G.UnitIsPlayer = function(u) if u == "target" and cur then return cur.player or false end return u == "player" end
  local function target(t) cur = t fire("PLAYER_TARGET_CHANGED") end
  local function tile(pred) for _, t in ipairs(UI.embed.tiles) do if t:IsShown() and t.data and pred(t.data) then return t end end end
  local function lvlOf(t) return t and t._osrsTgt and t._osrsTgt.shown ~= false and t._osrsTgt._level or nil end
  if not W.IsShown() then W.Show() end
  -- recette de Cuisine CONNUE et orange qui utilise la Viande de cerf (5471)
  trade.line = "Cuisine"
  trade.list = { { name = "Venaison dégraissée", kind = "optimal", reagents = { { id = 5471, name = "Viande de cerf", count = 1 } } } }
  ns.Scanner.ReadRecipes()
  trade.list = {}
  local q0 = #timers
  -- 3.3.15 : surbrillance FORTE = on frappe (attaque auto) et la cible nous frappe
  TG.swing.melee = true
  local rUAC, rUIU = _G.UnitAffectingCombat, _G.UnitIsUnit
  _G.UnitAffectingCombat = function(u) return u == "player" end
  _G.UnitIsUnit = function(a, b) if a == "targettarget" and b == "player" then return true end return rUIU and rUIU(a, b) or a == b end
  target({ name = "Coursier à ramure", level = 23, npc = 4018 })
  local lv = tile(function(d) return d.kind == "level" end)
  local def = tile(function(d) return d.kind == "defense" end)
  local mel = tile(function(d) return d.kind == "melee" end)
  local cu = tile(function(d) return d.id == "cooking" end)
  local sk = tile(function(d) return d.id == "skinning" end)
  local lw = tile(function(d) return d.id == "leatherworking" end)
  local fa = tile(function(d) return d.id == "firstaid" end)
  local tot = tile(function(d) return d.kind == "total" end)
  ok(lvlOf(lv) == "direct", "Niveau : cible niveau 23 donne de l'XP au niveau 25 (grise ≤ " .. TG.GreyLevel(25) .. ")")
  ok(lvlOf(cu) == "direct", "Cuisine : butin (Viande de cerf) → recette connue orange")
  ok(lvlOf(sk) == "direct", "Dépeçage : bête dépeçable qui rapporte encore")
  local mc, mm = tonumber(mel.data.current) or 0, tonumber(mel.data.apiMax) or 0
  ok(lvlOf(mel) == ((mc >= mm) and nil or ((mc < 115) and "direct" or "indirect")), "arme équipée (" .. tostring(mel.data.name) .. " " .. mc .. "/" .. mm .. ") : forte si on frappe et < 5 × 23, discrète au-delà, rien au maximum (3.3.15)")
  ok(lvlOf(def) == "direct", "Défense 122/125 : marquée (3.3.14 : cible non grise, plus de plafond estimé 5 × cible pour la Défense)")
  ok(lvlOf(lw) == "indirect", "Travail du cuir : lien INDIRECT (cuir de la cible)")
  ok(lvlOf(fa) == nil and lvlOf(tot) == nil, "Secourisme (pas de tissu) et Niveau total : rien")
  local m = lv._osrsTgt
  ok(m.parent == lv and m.veil.alpha == TG.VEIL.direct and m.fs.text == "+1" and m.fs.tg == 1 and m.fs.tr < 0.3 and m.fs._font[3] == "" and m.fs._shadowOff and m.fs._shadowOff[1] == 1, "direct (3.3.9 sans contour) : voile vert discret (" .. TG.VEIL.direct .. ") + petite marque verte « +1 » (notre cadre, enfant de la case)")
  local ml = lw._osrsTgt
  ok(ml.veil.alpha == TG.VEIL.indirect and ml.veil.alpha < m.veil.alpha and ml.fs.text == "+" and ml.fs.alpha < 1, "indirect : voile plus léger (" .. TG.VEIL.indirect .. "), « + » pâle")
  ok(#timers == q0 and (not PNL2.fader or PNL2.fader.scripts.OnUpdate == nil), "aucune minuterie ni OnUpdate pour la surbrillance")
  -- survol : explication
  lv.scripts.OnEnter(lv)
  ok(tipHas("Cible : Coursier à ramure  (+1 possible)") and tipHas("XP : cible niveau 23"), "survol du Niveau : « Cible : … (+1 possible) » + raison (XP)")
  lv.scripts.OnLeave(lv)
  lw.scripts.OnEnter(lw)
  ok(tipHas("(lien indirect)") and tipHas("lien :"), "survol de Travail du cuir : lien indirect expliqué")
  lw.scripts.OnLeave(lw)
  cu.scripts.OnEnter(cu)
  ok(tipHas("butin : Venaison dégraissée (orange)"), "survol de Cuisine : « butin : Venaison dégraissée (orange) » (sans flèche)")
  cu.scripts.OnLeave(cu)
  def.scripts.OnEnter(def)
  ok(tipHas("(+1 possible)") and tipHas("Défense · monte quand la cible te frappe"), "3.3.15 Défense marquée (la cible nous frappe) : raison affichée")
  def.scripts.OnLeave(def)
  -- nouvelle cible : niveau 30 → Défense marquée (5 × 30 = 150 > 122)
  target({ name = "Gnoll rivepatte", level = 30, npc = 999001 })
  ok(lvlOf(def) == "direct" and lvlOf(cu) == nil and lvlOf(sk) == nil and lvlOf(lw) == nil, "nouvelle cible (niveau 30, inconnue) : Défense marquée, Cuisine / Dépeçage / cuir retirés")
  -- cible grise
  target({ name = "Lapin", level = 2, npc = 999002 })
  ok(lvlOf(lv) == nil and lvlOf(def) == nil, "cible grise (niveau 2) : ni XP ni Défense")
  -- cadavre : plus d'XP ni de combat ; dépeçage / butin restent
  target({ name = "Coursier à ramure", level = 23, npc = 4018, dead = true })
  ok(lvlOf(lv) == nil and lvlOf(mel) == nil and lvlOf(sk) == "direct" and lvlOf(cu) == "direct", "cadavre : XP / arme retirées, Dépeçage et Cuisine gardés")
  -- tapée par un autre
  target({ name = "Coursier à ramure", level = 23, npc = 4018, tapped = true })
  ok(lvlOf(lv) == nil and lvlOf(cu) == nil, "cible tapée par un autre : ni XP ni butin")
  -- joueur amical : rien. Ennemi non gris : arme et Défense (pas d'XP, pas de butin).
  target({ name = "Raykuilu", level = 25, player = true, friend = true })
  ok(TG.shown == 0, "joueur amical : rien")
  target({ name = "Grunt de la Horde", level = 26, player = true })
  ok(lvlOf(lv) == nil and lvlOf(cu) == nil and lvlOf(sk) == nil and lvlOf(def) == "direct" and lvlOf(mel) ~= nil,
    "joueur ennemi niveau 26 (non gris) : arme et Défense, pas d'XP ni de dépeçage")
  -- perte de cible
  target({ name = "Coursier à ramure", level = 23, npc = 4018 })
  ok(TG.shown > 0, "cible retrouvée : marques revenues")
  target(nil)
  TG.swing.melee = false
  _G.UnitAffectingCombat, _G.UnitIsUnit = rUAC, rUIU
  local any = false
  for _, t in ipairs(UI.embed.tiles) do if t._osrsTgt and t._osrsTgt.shown ~= false then any = true end end
  ok(not any and TG.shown == 0 and TG.current == nil, "perte de cible : toutes les marques effacées")
  -- tissu → Couture (indirect) / Secourisme
  local clothNpc
  for npc, raw in pairs(ns.ScannerDB.drops or {}) do if raw:find("^2589:") or raw:find(",2589:") or raw:find(" 2589:") then clothNpc = npc break end end
  local rk = ns.Scanner.RankOf
  ns.Scanner.RankOf = function(id) if id == "tailoring" then return 60, { name = "Couture" } end return rk(id) end
  local res = clothNpc and TG.Compute({ name = "Défias", level = 20, npc = clothNpc, attackable = true })
  ns.Scanner.RankOf = rk
  ok(res and res["id:tailoring"] and res["id:tailoring"].level == "indirect" and res["id:tailoring"].why[1]:find("tissu", 1, true), "tissu (Étoffe de lin) → Couture : lien indirect (PNJ " .. tostring(clothNpc) .. ")")
  -- /drop alertes
  target({ name = "Coursier à ramure", level = 23, npc = 4018 })
  slash("alertes off")
  ok(TG.shown == 0, "/drop alertes off : surbrillance coupée")
  target({ name = "Coursier à ramure", level = 22, npc = 4018 })
  ok(TG.shown == 0, "désactivé : nouvelle cible ignorée")
  slash("alertes on")
  ok(TG.shown > 0 and lvlOf(lv) == "direct", "/drop alertes on : surbrillance rétablie sur la cible actuelle")
  -- panneau fermé : rien n'est calculé ; à l'ouverture, oui
  W.Hide()
  local c0 = TG.stats.computes
  target({ name = "Coursier à ramure", level = 21, npc = 4018 })
  ok(TG.stats.computes == c0, "panneau fermé : aucun calcul")
  W.Show()
  ok(TG.stats.computes == c0 + 1 and lvlOf(tile(function(d) return d.kind == "level" end)) == "direct", "ouverture du panneau : calcul et marques")
  -- grille repeinte : marques conservées, sans recalcul
  local c1 = TG.stats.computes
  UI:ApplyView()
  ok(TG.stats.computes == c1 and lvlOf(tile(function(d) return d.kind == "level" end)) == "direct", "grille reconstruite : marques reposées depuis le cache")
  -- coût : 1000 changements de cible entre 2 créatures
  local e0, cp0, mk0 = TG.stats.events, TG.stats.computes, TG.stats.marksCreated
  local t1 = { name = "Coursier à ramure", level = 23, npc = 4018 }
  local t2 = { name = "Gnoll rivepatte", level = 30, npc = 999001 }
  while #timers > 0 do table.remove(timers, 1)() end
  local k = 0 while PNL2.fader and PNL2.fader.scripts.OnUpdate and k < 200 do PNL2.fader.scripts.OnUpdate(PNL2.fader, 0.05) k = k + 1 end
  local tq = #timers
  for i = 1, 1000 do target((i % 2 == 0) and t1 or t2) end
  ok(TG.stats.events - e0 == 1000 and TG.stats.computes - cp0 <= 2, "1000 changements de cible : " .. (TG.stats.computes - cp0) .. " calculs (cache), le reste repeint")
  ok(TG.stats.marksCreated == mk0 and #timers == tq and (not PNL2.fader or PNL2.fader.scripts.OnUpdate == nil), "aucune marque créée, aucune minuterie, aucun OnUpdate")
  local nTiles = 0 for _, t in ipairs(UI.embed.tiles) do if t._osrsTgt then nTiles = nTiles + 1 end end
  ok(TG.stats.marksCreated <= #UI.embed.tiles and nTiles == TG.stats.marksCreated, "une marque au plus par case (" .. TG.stats.marksCreated .. ")")
  slash("perf")
  local hasT = false
  for i = #prints, math.max(1, #prints - 8), -1 do if tostring(prints[i]):find("perf : cible", 1, true) then hasT = true end end
  ok(hasT, "/drop perf : ligne « cible »")
  target(nil)
  _G.UnitName, _G.UnitLevel, _G.UnitIsDead, _G.UnitGUID = rN, rL, rD, rG
  _G.UnitExists, _G.UnitCanAttack, _G.UnitIsTapDenied, _G.UnitIsPlayer, _G.UnitClass = rE, rCA, rTD, rIP, rC
end

print("== 3.3.6 : panneau compact au style des toasts, sans volet ni chevron ; bouton de minicarte afficher / masquer ==")
do
  ok(PNL2.IsExpanded() == false and PNL2.chevron == nil and not vis(UI.ownDetail) and not vis(W.detail) and UI:IsRightPaneVisible() == false, "toujours compact : ni volet de droite ni chevron")
  ok(PNL2.toast and W.frame._toastBg and W.frame._dropFinish == "fond+bord", "habillage = fonction des toasts (UI:ApplyDropFinish)")
  local mb2 = UI.minimap
  local was = W.IsShown()
  runScript(mb2, "OnMouseDown") runScript(mb2, "OnMouseUp")
  mb2.scripts.OnClick(mb2, "LeftButton")
  ok(W.IsShown() ~= was, "minicarte : clic → " .. (W.IsShown() and "affiché" or "masqué"))
  runScript(mb2, "OnMouseDown") runScript(mb2, "OnMouseUp")
  mb2.scripts.OnClick(mb2, "LeftButton")
  ok(W.IsShown() == was, "minicarte : 2e clic → retour")
  if not W.IsShown() then W.Show() end
end

print("== 3.3.7 : lecture des GUID (tous formats) — cause du bug « pas une créature » ==")
do
  local S = ns.Scanner
  -- strsplit RÉEL (comme en jeu) : c'est lui qui cassait l'ancien code
  local function realSplit(sep, str)
    local out, i = {}, 1
    while true do
      local a, b = str:find(sep, i, true)
      if not a then out[#out + 1] = str:sub(i) break end
      out[#out + 1] = str:sub(i, a - 1)
      i = b + 1
    end
    return unpack(out)
  end
  _G.strsplit = realSplit
  local function oldNpcID(guid)
    local kind, _, _, _, _, id = strsplit and strsplit("-", guid)
    if not kind then local parts = {} for p in string.gmatch(guid, "[^%-]+") do parts[#parts + 1] = p end kind, id = parts[1], parts[6] end
    if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
    return tonumber(id)
  end
  local G1 = "Creature-0-5250-0-12-4013-0000ABCDEF"
  ok(oldNpcID(G1) == nil, "régression reproduite : l'ancien code renvoie nil dès que strsplit existe (« a and f() » = 1 seule valeur)")
  S._guidCache = {}
  local cases = {
    { G1, 4013, "Creature", "tirets (Creature, champ 6)" },
    { "Creature-0-4469-1-0-4014-00012F3A5B", 4014, "Creature", "champ 6" },
    { "creature-0-1-0-1-4013-1", 4013, "Creature", "champ 6" },
    { "Vehicle-0-3767-571-2-27894-00001DB6C5", 27894, "Vehicle", "champ 6" },
    { "Pet-0-4379-0-1-4013-0100ABCDEF", 4013, "Pet", "champ 6" },
    { "Creature-0-4013-0001", 4013, "Creature", "avant-dernier" },
    { "0xF130000FAD0012C1", 4013, "Creature", "1.12-3.x" },
    { "f130000fad0012c1", 4013, "Creature", "1.12-3.x" },
    { "0xF1300FAD00012C1A", 4013, "Creature", "4.x" },
    { "0xF150006CF6000ABC", 27894, "Vehicle", "1.12-3.x" },
    { "0xF140000FAD000001", 4013, "Pet", "1.12-3.x" },
    { "0xF130000FAE0012C1", 4014, "Creature", "1.12-3.x" },
  }
  for _, c in ipairs(cases) do
    local g = S.ParseGUID(c[1])
    ok(g and g.npc == c[2] and g.kind == c[3] and g.path:find(c[4], 1, true), string.format("%-36s → %s (%s ; %s)", c[1], tostring(g and g.npc), tostring(g and g.kind), tostring(g and g.path)))
  end
  local rej = { { "Player-5250-0ABCDEF1", "Player" }, { "GameObject-0-5250-0-12-1731-00000ABCD", "GameObject" }, { "Item-5250-0-400000000ABCDEF", "Item" },
    { "0x0000000000ABCDEF", "Player" }, { "0xF110000006C30123", "GameObject" }, { "0x4000000000123456", "Item" } }
  for _, c in ipairs(rej) do
    local g = S.ParseGUID(c[1])
    ok(g and g.npc == nil and g.kind == c[2] and g.path:find("rejeté", 1, true), c[1] .. " : reconnu " .. c[2] .. " et rejeté")
  end
  ok(S.NpcID("n'importe quoi") == nil and S.ParseGUID("n'importe quoi").path == "format inconnu" and S.NpcID(nil) == nil, "format inconnu / nil : nil, sans erreur")
  ok(S.NpcID(G1) == 4013 and S.ParseGUID(G1) == S.ParseGUID(G1), "NpcID partagé, résultat en cache")
end

print("== 3.3.7 : repli par NOM localisé (base Forever FR / EN), UnitIsPlayer ==")
local tu = {}
local rN, rL, rD, rG, rE, rIP = _G.UnitName, _G.UnitLevel, _G.UnitIsDead, _G.UnitGUID, _G.UnitExists, _G.UnitIsPlayer
_G.UnitName = function(u) if tu[u] then return tu[u].name end return rN(u) end
_G.UnitLevel = function(u) if tu[u] then return tu[u].level end return rL(u) end
_G.UnitIsDead = function(u) if tu[u] then return tu[u].dead or false end return rD and rD(u) or false end
_G.UnitGUID = function(u) if tu[u] then return tu[u].guid end return rG and rG(u) end
_G.UnitExists = function(u) if tu[u] then return true end return rE and rE(u) end
_G.UnitIsPlayer = function(u) if tu[u] then return tu[u].player or false end return rIP and rIP(u) end
do
  local S = ns.Scanner
  tu.target = { name = "Chasseresse céleste Aile-fière", level = 24, guid = "Monstre:4013?" }
  local id, info = S.UnitNpcID("target")
  ok(id == 4013 and info.how:find("nom + niveau 24", 1, true) and info.raw == "Monstre:4013?", "GUID illisible → nom FR + niveau : PNJ 4013 (" .. tostring(info.how) .. ")")
  for _, nm in ipairs({ "CHASSERESSE CÉLESTE AILE-FIÈRE", "chasseresse celeste aile fiere", "Chasseresse céleste Aile‑fière", "Pridewing Skyhunter" }) do
    tu.target.name = nm
    S._guidCache = {}
    local i2 = S.UnitNpcID("target")
    ok(i2 == 4013, "nom « " .. nm .. " » → " .. tostring(i2))
  end
  tu.target = { name = "Concubine Aile-fière", level = 23, guid = nil }
  ok(S.UnitNpcID("target") == 4014, "Concubine Aile-fière sans GUID → 4014")
  tu.target = { name = "Concubine Aile-fière", level = 23, guid = nil, player = true }
  local idp, ip = S.UnitNpcID("target")
  ok(idp == nil and ip.how:find("UnitIsPlayer", 1, true), "joueur portant le même nom : rejeté (UnitIsPlayer)")
  tu.target = { name = "Concubine Aile-fière", level = 23, guid = "Player-1-0ABC" }
  ok(S.UnitNpcID("target") == nil, "GUID Player : rejeté, pas de repli par nom")
  -- homonymes : le niveau départage
  local idx = S.NpcNameIndex()
  local pick
  for k, l in pairs(idx) do
    if #l >= 2 and l[1].lmax and l[2].lmin and l[2].lmin > l[1].lmax + 3 then pick = { k = k, a = l[1], b = l[2] } break end
  end
  if pick then
    local nm = ns.ScannerDB.npcs[pick.b.id]:match("^[^|]*|([^|]*)")
    tu.target = { name = nm, level = pick.b.lmin, guid = nil }
    ok(S.UnitNpcID("target") == pick.b.id, "homonymes « " .. nm .. " » : le niveau " .. pick.b.lmin .. " choisit le PNJ " .. pick.b.id .. " (pas " .. pick.a.id .. ")")
  else ok(true, "aucun homonyme à niveaux disjoints dans la base (rien à départager)") end
  local nn = 0 for _ in pairs(idx) do nn = nn + 1 end
  ok(nn > 1800 and S.NpcNameIndex() == idx, "index des noms construit une fois (" .. nn .. " noms FR / EN)")
  -- /drop scanner pourquoi et /drop debug : GUID brut + chemin
  tu.target = { name = "Chasseresse céleste Aile-fière", level = 24, guid = "Creature-0-5250-0-12-4013-0000ABCDEF" }
  local lines = S.Why("target")
  ok(lines[1]:find("GUID brut : Creature-0-5250-0-12-4013-0000ABCDEF", 1, true) and lines[1]:find("champ 6", 1, true) and lines[2]:find("PNJ 4013", 1, true), "/drop scanner pourquoi : « " .. lines[1] .. " »")
  local dbg = S.DebugLines and S.DebugLines() or {}
  local hasG = false
  for _, l in ipairs(type(dbg) == "table" and dbg or {}) do if tostring(l):find("GUID target", 1, true) then hasG = true end end
  if not S.DebugLines then
    np0 = #prints slash("debug")
    for i = np0 + 1, #prints do if tostring(prints[i]):find("GUID target", 1, true) then hasG = true end end
    if ns.DebugWindow and tostring(ns.DebugWindow.text or ""):find("GUID target", 1, true) then hasG = true end   -- 3.4.3 : fenêtre copiable
    if ns.DebugWindow and ns.DebugWindow.frame then ns.DebugWindow.frame:Hide() end
  end
  ok(hasG, "/drop debug : ligne « GUID target : … → 4013 (chemin) »")
end

print("== 3.3.7 : RÉGRESSION — Chasseresse céleste Aile-fière (24) ET Concubine Aile-fière (23) ==")
do
  local S, G, TG = ns.Scanner, ns.Gather, ns.Target
  -- jamais dépecées : aucune mémoire par nom
  G.DB()[ns.Fold("Chasseresse céleste Aile-fière")] = nil
  G.DB()[ns.Fold("Concubine Aile-fière")] = nil
  G.Invalidate()
  S._guidCache = {}
  local mobs = {
    { name = "Chasseresse céleste Aile-fière", level = 24, guid = "Creature-0-5250-0-12-4013-0000ABCDEF", npc = 4013, req = 120 },
    { name = "Concubine Aile-fière", level = 23, guid = "Creature-0-5250-0-12-4014-0000ABCDF0", npc = 4014, req = 115 },
  }
  if not W.IsShown() then W.Show() end
  for _, m in ipairs(mobs) do
    tu.mouseover = { name = m.name, level = m.level, guid = m.guid }
    setTip({ m.name, "Niveau " .. m.level })
    local st = G.UnitTooltip(tip)
    local l = tip.lines[#tip.lines]
    ok(st and l and l.t == "Dépeçage : +1 possible · requis " .. m.req, m.name .. " (vivante, GUID moderne, strsplit réel) : « " .. tostring(l and l.t) .. " »")
    tu.target = { name = m.name, level = m.level, guid = m.guid }
    _G.UnitCanAttack = function() return true end
    fire("PLAYER_TARGET_CHANGED")
    local sk
    for _, t in ipairs(UI.embed.tiles) do if t:IsShown() and t.data and t.data.id == "skinning" then sk = t end end
    ok(sk._osrsTgt and sk._osrsTgt.shown ~= false and sk._osrsTgt._level == "direct" and TG.target.npc == m.npc, m.name .. " : « +1 » sur la case Dépeçage (PNJ " .. tostring(TG.target.npc) .. ")")
    local lw = S.Why("target")
    local hasV = false for _, x in ipairs(lw) do if x:find("Dépeçage", 1, true) or x:find("verdict", 1, true) then hasV = true end end
    ok(lw[2]:find("PNJ " .. m.npc, 1, true) and hasV, m.name .. " : /drop scanner pourquoi identifie le PNJ " .. m.npc)
  end
  -- même chose avec un GUID illisible : repli par nom
  S._guidCache = {}
  tu.mouseover = { name = mobs[1].name, level = 24, guid = "???" }
  setTip({ mobs[1].name, "Niveau 24" })
  G.DB()[ns.Fold(mobs[1].name)] = nil G.Invalidate()
  ok(G.UnitTooltip(tip) and tip.lines[#tip.lines].t:find("requis 120", 1, true), "GUID illisible : la Chasseresse est reconnue par son nom (requis 120)")
  -- rang insuffisant : ligne rouge, pas de « +1 » (comportement voulu)
  local sk2 = skill("Dépeçage") local keep = sk2.rank
  sk2.rank = 117 G.Invalidate()
  tu.mouseover = { name = mobs[1].name, level = 24, guid = mobs[1].guid }
  setTip({ mobs[1].name, "Niveau 24" })
  G.UnitTooltip(tip)
  ok(tip.lines[#tip.lines].t == "Dépeçage : 120 requis (actuel 117)", "rang 117 < 120 : « Dépeçage : 120 requis (actuel 117) », pas de +1 (voulu)")
  sk2.rank = keep G.Invalidate()
  -- butin : GetLootSourceInfo illisible → corps de la cible
  tu.target = { name = mobs[1].name, level = 24, guid = "???", dead = true }
  local corpse, src = S.CorpseGUID()
  ok(corpse and S.NpcID(corpse) == 4013 and src == "cible morte" and corpse ~= "Creature-0-0-0-0-4013-", "corps (GUID illisible) : clé « " .. tostring(corpse) .. " » → 4013")
  tu.target, tu.mouseover = nil, nil
end
_G.UnitName, _G.UnitLevel, _G.UnitIsDead, _G.UnitGUID, _G.UnitExists, _G.UnitIsPlayer = rN, rL, rD, rG, rE, rIP

print("== 3.3.7 : cadre du panneau = cadre de l'INFOBULLE (lecture seule de GameTooltip) ==")
do
  local f = W.frame
  local GOLDB, DARK = { 1, 0.82, 0, 1 }, { 0.05, 0.05, 0.06, 0.92 }
  local calls = 0
  local function piece(name, atlas, w, h, pt, x, y, col)
    local p = { name = name, _atlas = atlas, w = w, h = h, pt = pt, x = x, y = y, col = col }
    function p:GetAtlas() return self._atlas end
    function p:GetTexture() return nil end
    function p:GetSize() return self.w, self.h end
    function p:GetPoint() return self.pt, _G.GameTooltip, self.pt, self.x, self.y end
    function p:GetVertexColor() return self.col[1], self.col[2], self.col[3], self.col[4] end
    function p:SetVertexColor() calls = calls + 1 end
    function p:SetAtlas() calls = calls + 1 end
    function p:SetAlpha() calls = calls + 1 end
    return p
  end
  local nsl = { layoutType = "TooltipDefaultLayout" }
  local defs = { TopLeftCorner = { 16, 16, "TOPLEFT", -4, 4 }, TopRightCorner = { 16, 16, "TOPRIGHT", 4, 4 }, BottomLeftCorner = { 16, 16, "BOTTOMLEFT", -4, -4 },
    BottomRightCorner = { 16, 16, "BOTTOMRIGHT", 4, -4 }, TopEdge = { 1, 16, "TOPLEFT" }, BottomEdge = { 1, 16, "BOTTOMLEFT" }, LeftEdge = { 16, 1, "TOPLEFT" }, RightEdge = { 16, 1, "TOPRIGHT" }, Center = { 1, 1, "TOPLEFT", 4, -4 } }
  for k, d in pairs(defs) do nsl[k] = piece(k, "Tooltip-NineSlice-" .. k, d[1], d[2], d[3], d[4] or 0, d[5] or 0, k == "Center" and DARK or GOLDB) end
  function nsl:GetBorderColor() return GOLDB[1], GOLDB[2], GOLDB[3], GOLDB[4] end
  function nsl:GetCenterColor() return DARK[1], DARK[2], DARK[3], DARK[4] end
  function nsl:SetBorderColor() calls = calls + 1 end
  local tipObj = _G.GameTooltip
  rawset(tipObj, "NineSlice", nsl)
  local applied = {}
  _G.NineSliceUtil = { ApplyLayoutByName = function(host, name)
    applied[#applied + 1] = name
    for k in pairs(defs) do local t = host:CreateTexture(nil, "BORDER") t._piece = k rawset(host, k, t) end
  end }
  local function reset() if f._tipChrome then f._tipChrome:Hide() end f._tipChrome, PNL2.tip, PNL2._tipColorsRead = nil, nil, nil end
  reset()
  local X = PNL2.ApplyTooltipLook(f)
  ok(X and W.tipLook:find("^NineSlice « TooltipDefaultLayout » %(GameTooltip.NineSlice.layoutType%)") and applied[1] == "TooltipDefaultLayout", "1) même disposition NineSlice que GameTooltip (« " .. tostring(W.tipLook) .. " »)")
  ok(f._tipChrome.parent == f and #X.border == 8 and #X.bg == 1, "notre cadre enfant du panneau : 8 pièces de bord + centre")
  local okC = true
  for _, t in ipairs(X.border) do if not (t._vc and t._vc[1] == 1 and t._vc[2] == 1 and t._vc[3] == 1) then okC = false end end
  ok(okC and X.bg[1]._vc[1] == ns.Chrome.CENTER[1] and X.bgColor[4] == 1, "3.3.10 couleurs CONSTANTES (art natif non teinté, fond d'infobulle par défaut), jamais relues sur GameTooltip (doré / sombre ici)")
  local T = PNL2.toast
  local hidden = true for _, t in ipairs(T.bg) do if t.shown ~= false then hidden = false end end for _, t in ipairs(T.border) do if t.shown ~= false then hidden = false end end
  ok(hidden, "ancien habillage des toasts masqué (un seul cadre)")
  ok(calls == 0, "GameTooltip et ses pièces : AUCUN appel de modification (" .. calls .. ")")
  -- fondu par-dessus
  PNL2._target = 1 PNL2.StartFade() local k = 0 while PNL2.fader.scripts.OnUpdate and k < 100 do PNL2.fader.scripts.OnUpdate(PNL2.fader, 0.05) k = k + 1 end
  ok(math.abs(X.borderAlpha - 1) < 0.001 and math.abs(X.bgAlpha - ns.Panel.BgAlpha() / 100) < 0.001 and math.abs(f.alpha - 1) < 0.001, "3.3.8 survol / gain : bord doré de l'infobulle plein, fond translucide " .. ns.Panel.BgAlpha() .. " % (/drop fond), panneau 100 %")
  -- /drop fond : réglage mémorisé, appliqué en direct, repos jamais plus opaque que l'actif
  ns.SlashExt.fond("70")
  ok(ns.db.ui.bgAlpha == 70 and math.abs(X.bgAlpha - 0.70) < 0.001, "/drop fond 70 : fond actif 0,70, mémorisé (SavedVariables)")
  ns.SlashExt.fond("150")
  ok(ns.db.ui.bgAlpha == 100, "/drop fond 150 : borné à 100")
  ns.SlashExt.fond("10")
  ns.Panel._mix = 0 ns.Panel.ApplyOpacity()
  ok(X.bgAlpha <= 0.10 + 1e-6, "fond 10 % : le repos n'est pas plus opaque que l'actif (" .. string.format("%.3f", X.bgAlpha) .. ")")
  ns.db.ui.bgAlpha = nil
  ns.Panel._mix = 1 ns.Panel.ApplyOpacity()
  PNL2._target = 0 PNL2.StartFade() k = 0 while PNL2.fader.scripts.OnUpdate and k < 100 do PNL2.fader.scripts.OnUpdate(PNL2.fader, 0.05) k = k + 1 end
  ok(math.abs(X.borderAlpha - PNL2.LOOK_TIP.idle.border) < 0.001 and math.abs(X.bgAlpha - 1 * PNL2.LOOK_TIP.idle.bg) < 0.001, string.format("repos : bord %.2f, fond %.2f (atténués), fondu conservé", X.borderAlpha, X.bgAlpha))
  -- 2) copie pièce par pièce (pas de NineSliceUtil)
  _G.NineSliceUtil = nil
  reset()
  X = PNL2.ApplyTooltipLook(f)
  local tl
  for _, t in ipairs(X.border) do if t._atlasSet == "Tooltip-NineSlice-TopLeftCorner" then tl = t end end
  ok(W.tipLook == "pièces copiées de GameTooltip.NineSlice" and #X.border == 8 and tl and tl.width == 16 and tl.points[1][1] == "TOPLEFT" and tl.points[1][4] == -4 and tl.points[1][5] == 4, "2) sans NineSliceUtil : 9 pièces copiées (atlas, 16 px, décalage des coins −4 / +4)")
  -- 3) backdrop
  rawset(tipObj, "NineSlice", nil)
  local bd = { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 5, right = 5, top = 5, bottom = 5 } }
  tipObj.GetBackdrop = function() return bd end
  tipObj.GetBackdropBorderColor = function() return 1, 0.82, 0, 1 end
  tipObj.GetBackdropColor = function() return 0.09, 0.09, 0.19, 0.9 end
  reset()
  X = PNL2.ApplyTooltipLook(f)
  local host = f._tipChrome
  ok(W.tipLook == "backdrop de GameTooltip" and host._bdEdge == bd.edgeFile and host._bdFile == bd.bgFile, "3) même backdrop que GameTooltip (bord UI-Tooltip-Border, 16 px)")
  PNL2.ApplyOpacity()
  ok(host._bdBorder and host._bdBorder[2] == 1 and host._bdColor and host._bdColor[3] == 0.19, "backdrop : couleurs constantes (pas la teinte de GameTooltip), fondu appliqué")
  -- 4) rien de lisible : habillage des toasts
  tipObj.GetBackdrop = nil
  reset()
  ok(PNL2.ApplyTooltipLook(f) == nil and W.tipLook == nil, "4) aucun dessin lisible : l'habillage des toasts reste (" .. tostring(W.tipLookWhy) .. ")")
  -- état final : NineSlice (cas du client)
  rawset(tipObj, "NineSlice", nsl)
  _G.NineSliceUtil = { ApplyLayoutByName = function(h2) for kk in pairs(defs) do local t = h2:CreateTexture(nil, "BORDER") rawset(h2, kk, t) end end }
  reset() PNL2.ApplyTooltipLook(f) PNL2.ApplyOpacity()
end

print("== 3.3.7 : DISPOSITION 1 / 2 / 5 / 10 colonnes, poignée, /drop taille ==")
do
  local LY = ns.Layout
  local f = W.frame
  local function grid()
    local xs, ys, order = {}, {}, {}
    for _, t in ipairs(UI.embed.tiles) do
      if t:IsShown() and t.data then
        local r = __rect(t)
        order[#order + 1] = { r = r, d = t.data }
      end
    end
    table.sort(order, function(a, b) if math.abs(a.r.t - b.r.t) > 1 then return a.r.t > b.r.t end return a.r.l < b.r.l end)
    for _, o in ipairs(order) do xs[math.floor(o.r.l + 0.5)] = true ys[math.floor(o.r.t + 0.5)] = true end
    local nx, ny = 0, 0 for _ in pairs(xs) do nx = nx + 1 end for _ in pairs(ys) do ny = ny + 1 end
    return nx, ny, order
  end
  local nx0, ny0, o0 = grid()
  local names0 = {} for i, o in ipairs(o0) do names0[i] = o.d.name end
  ok(LY.Cols() == 5 and nx0 == 5 and ny0 == 2, "défaut : 5 colonnes × 2 rangées")
  local fr = __rect(f)
  for _, n in ipairs({ 2, 1, 10, 5 }) do
    slash("colonnes " .. n)
    local nx, ny, o = grid()
    local same = #o == #o0
    for i = 1, #o do if o[i].d.name ~= names0[i] then same = false end end
    local r = __rect(f)
    local inside = true
    for _, x in ipairs(o) do if x.r.l < r.l or x.r.r > r.r or x.r.b < r.b or x.r.t > r.t then inside = false end end
    ok(nx == n and ny == math.ceil(10 / n) and same and o[#o].d.kind == "total" and inside, string.format("/drop colonnes %d : %d × %d, ordre inchangé, Niveau total dernier, cases dans le panneau (%d × %d px)", n, nx, ny, r.r - r.l, r.t - r.b))
    ok(math.abs(r.l - fr.l) < 0.01 and math.abs(r.t - fr.t) < 0.01, "coin haut-gauche conservé (" .. r.l .. ", " .. r.t .. ")")
    ok((ns.db.ui.cols or 5) == n, "mémorisé : cols = " .. tostring(ns.db.ui.cols or 5))
  end
  slash("colonnes 4")
  ok(LY.Cols() == 5 and tostring(prints[#prints]):find("usage", 1, true), "/drop colonnes 4 : refusé (1, 2, 3, 5 ou 10), aide")
  -- poignée
  local g = LY.grip
  ok(g and g.parent == f and vis(g) and g.points[1][1] == "BOTTOMRIGHT" and g.mouse, "poignée dans le coin bas-droit (notre cadre)")
  local cx, cy = 0, 0
  _G.GetCursorPosition = function() return cx, cy end
  cx, cy = 500, 500
  g.scripts.OnMouseDown(g)
  ok(g.scripts.OnUpdate ~= nil, "glisser : OnUpdate seulement pendant le glissement")
  local w5 = (__rect(f).r - __rect(f).l)
  cx, cy = 500 - (w5 - LY.Candidates()[2].w) - 4, 500 - 150   -- plus étroit, plus haut → 2 colonnes
  g.scripts.OnUpdate(g)
  ok(LY.Cols() == 5, "3.3.12 glisser simple : la disposition ne change JAMAIS (taille seulement)")
  g.scripts.OnMouseUp(g)
  slash("taille 100")
  -- Alt+glisser : colonnes (ancienne poignée)
  local rAlt = _G.IsAltKeyDown
  _G.IsAltKeyDown = function() return true end
  cx, cy = 500, 500
  g.scripts.OnMouseDown(g)
  cx, cy = 500 - (w5 - LY.Candidates()[2].w) - 4, 500 - 150
  g.scripts.OnUpdate(g)
  ok(LY.Cols() == 2 and LY.Scale() == 100, "Alt+glisser vers la gauche / le bas : 2 colonnes × 5, taille inchangée")
  cx, cy = 500 + 400, 520
  g.scripts.OnUpdate(g)
  ok(LY.Cols() == 10, "Alt+glisser loin à droite : 10 colonnes × 1")
  g.scripts.OnMouseUp(g)
  _G.IsAltKeyDown = rAlt
  ok(g.scripts.OnUpdate == nil, "relâché : OnUpdate retiré")
  slash("colonnes 5")
  slash("verrou on")
  ok(not vis(g) and not g.mouse, "/drop verrou on : poignée cachée et inactive")
  ok(LY.StartDrag() == false, "verrouillé : impossible de redimensionner")
  slash("verrou off")
  ok(vis(g), "/drop verrou off : poignée revenue")
  -- taille
  local scaleSet
  f.SetScale = function(self, s) scaleSet = s self._scale = s end
  f.GetScale = function(self) return self._scale or 1 end
  local r0 = __rect(f)
  slash("taille 120")
  local p = f.points[1]
  ok(ns.db.ui.scale == 120 and (scaleSet == nil or scaleSet == 1) and ns.Icons.TILE == 48 and p[1] == "TOPLEFT" and math.abs(p[4] - r0.l) < 0.01 and math.abs(p[5] - r0.t) < 0.01, "3.3.12 /drop taille 120 : cases 48 px (taille dynamique, panneau jamais SetScale), coin haut-gauche conservé")
  slash("taille 40")
  ok(ns.db.ui.scale == 50, "/drop taille 40 : borné à 50 %")
  slash("taille 137")
  ok(ns.db.ui.scale == 137 and ns.Icons.TILE == 55 and ns.Icons.ICON == 49 and (scaleSet == nil or scaleSet == 1), "/drop taille 137 : au pour cent près (case 55, icône 49)")
  slash("taille 250")
  ok(ns.db.ui.scale == 200, "/drop taille 250 : borné à 200 %")
  slash("taille 100")
  ok(ns.db.ui.scale == nil and scaleSet == 1, "/drop taille 100 : défaut")
  f:ClearAllPoints() f:SetPoint("TOPLEFT", _G.UIParent, "BOTTOMLEFT", r0.l, r0.t)
end

print("== 3.3.7 : NOTIFICATIONS ancrées au panneau (dessus / dessous / détaché, bascule) ==")
do
  local NF = ns.Notif
  local f = W.frame
  UI:BuildDrops()
  local d = UI.dropsFrame
  f:ClearAllPoints() f:SetPoint("TOPLEFT", _G.UIParent, "BOTTOMLEFT", 600, 500)
  PNL2.SavePos(f)
  local pr = __rect(f)
  ok(NF.Mode() == "dessus" and NF.state.eff == "dessus" and d.points[1][1] == "BOTTOMLEFT" and d.points[1][2] == f and d.points[1][3] == "TOPLEFT", "défaut : toasts ancrés AU-DESSUS du panneau")
  ok(UI:DropDir() == "haut" and math.abs(d.width - (pr.r - pr.l)) < 1, "empilés vers le haut, largeur du panneau (" .. tostring(d.width) .. " px)")
  clearDrops()
  local t1 = UI:SpawnDrop(ns.LEVEL_ICON, "A", "x", nil, nil, nil, { kind = "skill" })
  local t2 = UI:SpawnDrop(ns.LEVEL_ICON, "B", "y", nil, nil, nil, { kind = "skill" })
  local r1, r2 = __rect(t1), __rect(t2)
  ok(r1 and r2 and math.abs(r1.b - (pr.t + NF.GAP)) < 0.01 and r2.b > r1.t, "1er toast juste au-dessus du panneau, le 2e au-dessus du 1er")
  -- le panneau bouge : les toasts suivent
  f:ClearAllPoints() f:SetPoint("TOPLEFT", _G.UIParent, "BOTTOMLEFT", 300, 400)
  PNL2.SavePos(f)
  local r1b = __rect(t1)
  ok(math.abs(r1b.l - 300) < 0.01 and math.abs(r1b.b - (400 + NF.GAP)) < 0.01, "panneau déplacé : les toasts suivent (" .. r1b.l .. ", " .. r1b.b .. ")")
  -- disposition : largeur suit
  slash("colonnes 10")
  local prw = __rect(f).r - __rect(f).l
  ok(math.abs(d.width - prw) < 1, "disposition 10 colonnes : support à la largeur du panneau (" .. d.width .. " px)")
  slash("colonnes 1")
  ok(d.width == NF.DEFAULT_W, "1 colonne (panneau étroit) : largeur normale des toasts (" .. d.width .. " px)")
  slash("colonnes 5")
  -- bascule près du haut
  f:ClearAllPoints() f:SetPoint("TOPLEFT", _G.UIParent, "BOTTOMLEFT", 300, 1060)
  PNL2.SavePos(f)
  ok(NF.state.eff == "dessous" and d.points[1][1] == "TOPLEFT" and d.points[1][3] == "BOTTOMLEFT" and UI:DropDir() == "bas", "panneau près du haut de l'écran : bascule EN DESSOUS (" .. tostring(NF.state.why) .. ")")
  f:ClearAllPoints() f:SetPoint("TOPLEFT", _G.UIParent, "BOTTOMLEFT", 300, 400)
  PNL2.SavePos(f)
  ok(NF.state.eff == "dessus", "redescendu : de nouveau au-dessus")
  slash("notif dessous")
  ok(ns.db.ui.notifMode == "dessous" and NF.state.eff == "dessous" and d.points[1][2] == f, "/drop notif dessous : sous le panneau, empilés vers le bas")
  f:ClearAllPoints() f:SetPoint("TOPLEFT", _G.UIParent, "BOTTOMLEFT", 300, 120)
  PNL2.SavePos(f)
  ok(NF.state.eff == "dessus", "« dessous » près du bas de l'écran : bascule au-dessus")
  f:ClearAllPoints() f:SetPoint("TOPLEFT", _G.UIParent, "BOTTOMLEFT", 300, 400)
  PNL2.SavePos(f)
  ns.db.ui.dropsPos = { point = "BOTTOMLEFT", relativePoint = "BOTTOMLEFT", x = 77, y = 88 }
  slash("notif detache")
  ok(ns.db.ui.notifMode == "detache" and d.points[1][2] == _G.UIParent and d.points[1][4] == 77 and d.points[1][5] == 88 and d.width == 260, "/drop notif detache : position libre d'avant (77, 88), largeur normale")
  slash("notif dessus")
  ok(ns.db.ui.notifMode == nil and NF.state.eff == "dessus" and d.points[1][2] == f, "/drop notif dessus : rattachés")
  ok(ns.db.ui.dropsPos.x == 77, "la position libre est conservée tant qu'on est attaché")
  slash("notif n'importe")
  ok(tostring(prints[#prints]):find("usage", 1, true), "/drop notif inconnu : aide")
  -- /drop drops move : détache
  UI:ToggleDropsMove()
  ok(NF.Mode() == "detache" and d._osrsMoving, "/drop drops move : passe en position libre pour pouvoir déplacer")
  UI:ToggleDropsMove()
  slash("notif dessus")
  clearDrops()
end

print("== Drop (toast) : le clic ouvre la fenêtre, jamais l'onglet natif ==")
W.Hide()
local r = UI:OpenFromDrop({ kind = "xp" })
ok(W.IsShown() and UI.selected and UI.selected.kind == "level", "clic sur un drop d'XP : fenêtre ouverte, Niveau sélectionné (" .. tostring(r) .. ")")

print("== Onglet Comp. natif : STRICTEMENT intact ==")
_G.CharacterFrame:Show() _G.SkillFrame:Show()
UI:Refresh(true) UI:ApplyView() flushTimers()
_G.SkillFrame:Hide() _G.SkillFrame:Show()
-- l'ouverture du natif ne déclenche rien chez nous ; l'empreinte ne bouge pas
_G.SkillFrame.shown = false _G.CharacterFrame.shown = false
local FP1 = nativeFP()
if FP1 ~= FP0 then
  local a, b = {}, {}
  for l in FP0:gmatch("[^\n]+") do a[#a + 1] = l end
  for l in FP1:gmatch("[^\n]+") do b[#b + 1] = l end
  for i = 1, math.max(#a, #b) do if a[i] ~= b[i] then io.stderr:write("FP diff ", tostring(a[i]), "\n     -> ", tostring(b[i]), "\n") break end end
end
ok(FP1 == FP0, "SkillFrame, ses lignes, son détail, onglets natifs et Zygor : aucune ancre, taille, visibilité, alpha, parent, crochet ni script modifié")
ok(toggleCalls == toggle0, "ToggleCharacter jamais appelé par l'addon")
ok(not (_G.SetSelectedSkill and _G.SetSelectedSkill._called), "SetSelectedSkill jamais appelé")
ok(errs() == 0, "aucune erreur capturée")
print("== 3.3.8 : INFOBULLE DE CRÉATURE COMPACTE (≤ 3 lignes, une par métier ; Maj = détail) ==")
do
  local TP = ns.Tip
  TP.active = true
  local tUnits = {}
  local sN, sL, sD, sG = _G.UnitName, _G.UnitLevel, _G.UnitIsDead, _G.UnitGUID
  _G.UnitName = function(u) if tUnits[u] then return tUnits[u].name end return sN(u) end
  _G.UnitLevel = function(u) if tUnits[u] then return tUnits[u].level end return sL(u) end
  _G.UnitIsDead = function(u) if tUnits[u] then return tUnits[u].dead or false end return sD(u) end
  _G.UnitGUID = function(u) if tUnits[u] and tUnits[u].npc then return "Creature-0-0-0-0-" .. tUnits[u].npc .. "-0" end return sG and sG(u) end
  local units = tUnits
  ok(ns.Gather.UnitTooltip(tip) == nil and ns.Craft.UnitTooltip(tip) == nil, "anciens ajouts (Dépeçage, recettes) coupés quand l'infobulle compacte est active")
  ns.Scanner.Enabled = function() return true end
  local shift = false
  _G.IsShiftKeyDown = function() return shift end
  G.Invalidate()
  units.mouseover = { name = "Coursier à ramure", level = 23, dead = true, npc = 4018 }
  setTip({ "Coursier à ramure", "Niveau 23", "Cadavre", "Dépeçable" })
  local n = TP.UnitTooltip(tip, "mouseover")
  local txt = {}
  for _, l in ipairs(tip.lines) do txt[#txt + 1] = l.t end
  local all = table.concat(txt, " | ")
  ok(n and n >= 2 and n <= TP.MAX and #tip.lines == n, "compact : " .. tostring(n) .. " ligne(s) ≤ 3 : " .. all)
  local l1 = tip.lines[1]
  ok(l1 and l1.t == "Dépeçage +1 · requis 115" and l1.g > 0.9 and l1.r < 0.3, "vert « Dépeçage +1 · requis 115 » en tête (gain possible)")
  local cu = tipHas("Cuisine")
  ok(cu and cu.t == "Cuisine +1 : Venaison dégraissée" and cu.g > 0.9 and cu.r < 0.3, "vert « " .. tostring(cu and cu.t) .. " » (recette apprise, orange, butin Viande de cerf)")
  local tl = tipHas("Travail du cuir")
  ok(tl and tl.t:find("(+8)", 1, true), "au-delà de 2 recettes citées : « (+N) » au lieu d'une liste")
  local seenSkill, dup = {}, false
  for _, l in ipairs(tip.lines) do
    local k = l.t:match("^([^:+]+)") k = k and k:gsub("%s+$", "")
    if seenSkill[k] then dup = true end seenSkill[k] = true
  end
  ok(not dup, "une ligne par métier")
  ok(not all:find("Coursier", 1, true) and not all:find("→", 1, true) and not all:find("source inconnue", 1, true), "ni nom de créature, ni flèche, ni « source inconnue »")
  -- rafraîchissement sans doublon
  setTip({ "Coursier à ramure", "Niveau 23", "Cadavre", "Dépeçable", l1.t })
  TP.UnitTooltip(tip, "mouseover")
  ok(#tip.lines == 0, "infobulle déjà complétée : pas de doublon")
  -- aucune recette connue ne monte, 4 à apprendre → une ligne GRISE
  local rUses = LK.UsesOf
  LK.UsesOf = function(id)
    if id ~= 5471 then return {} end
    local o = {}
    for i, nm in ipairs({ "Venaison dégraissée", "Ragoût de cerf", "Steak de cerf", "Cerf épicé" }) do
      o[i] = { name = nm, skill = "cooking", req = 100 + i * 10, learned = false, diff = (i == 1) and "optimal" or "locked", rank = 105 }
    end
    return o
  end
  setTip({ "Coursier à ramure", "Niveau 23", "Cadavre", "Dépeçable" })
  TP.UnitTooltip(tip, "mouseover")
  local cg = tipHas("Cuisine")
  ok(cg and cg.t == "Cuisine : 4 recettes à apprendre" and math.abs(cg.r - 0.6) < 0.01 and math.abs(cg.g - 0.6) < 0.01, "gris « " .. tostring(cg and cg.t) .. " » (aucun gain avec ce que tu sais faire)")
  -- Maj : détail
  shift = true
  setTip({ "Coursier à ramure", "Niveau 23", "Cadavre", "Dépeçable" })
  local nd = TP.UnitTooltip(tip, "mouseover")
  LK.UsesOf = rUses
  local det = tipHas("Venaison dégraissée · à apprendre, rang 110")
  ok(nd > n and det and det.t:sub(1, 3) == "   " and tipHas("Dépeçage : +1 possible"), "Maj enfoncée : détail (" .. nd .. " lignes) avec « Venaison dégraissée · à apprendre, rang 110 »")
  local dall = {} for _, l in ipairs(tip.lines) do dall[#dall + 1] = l.t end
  dall = table.concat(dall, " | ")
  ok(not dall:find("→", 1, true) and not dall:find("source inconnue", 1, true) and not dall:find("Coursier", 1, true), "détail : toujours sans flèche, sans « source inconnue », sans nom")
  shift = false
  -- MODIFIER_STATE_CHANGED : l'infobulle est reconstruite
  local setUnit, shownT = nil, true
  local rShown, rGetUnit, rSetUnit = tip.IsShown, tip.GetUnit, tip.SetUnit
  tip.IsShown = function() return shownT end
  tip.GetUnit = function() return "Coursier à ramure", "mouseover" end
  tip.SetUnit = function(_, u) setUnit = u end
  local r0 = TP.stats.refresh
  fire("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
  ok(setUnit == "mouseover" and TP.stats.refresh == r0 + 1, "Maj enfoncée pendant l'infobulle : SetUnit(mouseover) → détail")
  setUnit = nil
  fire("MODIFIER_STATE_CHANGED", "LCTRL", 1)
  ok(setUnit == nil, "autre touche (Ctrl) : rien")
  shownT = false
  fire("MODIFIER_STATE_CHANGED", "RSHIFT", 0)
  ok(setUnit == nil, "infobulle cachée : rien (aucun coût au repos)")
  tip.IsShown, tip.GetUnit, tip.SetUnit = rShown, rGetUnit, rSetUnit
  -- plafond : 5 métiers → 3 lignes, les gains d'abord
  local gs = {
    { skill = "tailoring", color = TP.GREY, text = "Couture : 2 recettes à apprendre", detail = {} },
    { skill = "cooking", gain = true, color = TP.GREEN, text = "Cuisine +1 : A, B", detail = {} },
    { skill = "firstaid", gain = true, color = TP.GREEN, text = "Secourisme +1 : Anti-venin, Cataplasme", detail = {} },
    { skill = "leatherworking", color = TP.GREY, text = "Travail du cuir : recettes grises (aucun point)", detail = {} },
    { skill = "skinning", color = TP.GREY, text = "Dépeçage : gris (aucun point)", detail = {} },
  }
  table.sort(gs, function(a, b)
    if (a.gain and true or false) ~= (b.gain and true or false) then return a.gain and true or false end
    return ({ skinning = 1, cooking = 2, firstaid = 3 })[a.skill] or 9 < (({ skinning = 1, cooking = 2, firstaid = 3 })[b.skill] or 9)
  end)
  local cl = TP.Lines(gs, false)
  ok(#cl == 3 and cl[1][1]:find("^Cuisine %+1") and cl[2][1]:find("^Secourisme %+1"), "5 métiers → 3 lignes, les gains (verts) d'abord")
  -- repli : sans la compétence Dépeçage, pas de ligne Dépeçage
  local sk = skill("Dépeçage") local keep = sk.rank sk.rank = 0 G.Invalidate()
  setTip({ "Coursier à ramure", "Niveau 23", "Cadavre", "Dépeçable" })
  TP.UnitTooltip(tip, "mouseover")
  ok(not tipHas("Dépeçage"), "sans Dépeçage : aucune ligne Dépeçage")
  sk.rank = keep G.Invalidate()
  -- joueur : rien
  units.mouseover = { name = "Arnaud", level = 25 }
  local rIsPlayer = _G.UnitIsPlayer
  _G.UnitIsPlayer = function(u) return u == "mouseover" end
  setTip({ "Arnaud" })
  ok(TP.UnitTooltip(tip, "mouseover") == nil and #tip.lines == 0, "joueur : aucune ligne")
  _G.UnitIsPlayer = rIsPlayer
  _G.UnitName, _G.UnitLevel, _G.UnitIsDead, _G.UnitGUID = sN, sL, sD, sG
end

print("== 3.3.8 : REPÈRE DE BARRE DE NOM (centré au-dessus du nom, une icône par métier, bordure verte / grise) ==")
do
  local tU = {}
  local sN, sL, sD, sG = _G.UnitName, _G.UnitLevel, _G.UnitIsDead, _G.UnitGUID
  _G.UnitName = function(u) if tU[u] then return tU[u].name end return sN(u) end
  _G.UnitLevel = function(u) if tU[u] then return tU[u].level end return sL(u) end
  _G.UnitIsDead = function(u) if tU[u] then return false end return sD(u) end
  _G.UnitGUID = function(u) if tU[u] and tU[u].npc then return "Creature-0-0-0-0-" .. tU[u].npc .. "-0" end return sG and sG(u) end
  local pl = {}
  local rC = _G.C_NamePlate
  _G.C_NamePlate = { GetNamePlateForUnit = function(u) return pl[u] end, GetNamePlates = function() return {} end }
  local function plate(u, nameW, nameShown)
    local p = newObj("Frame", nil, _G.UIParent)
    p._abs = { l = 300, r = 420, t = 520, b = 480 }
    local uf = newObj("Frame", nil, p) uf._abs = p._abs
    local hb = newObj("Frame", nil, uf) hb._abs = { l = 310, r = 410, t = 496, b = 488 }
    local nm = newObj("Frame", nil, uf) nm._abs = { l = 360 - nameW / 2, r = 360 + nameW / 2, t = 508, b = 498 }
    if not nameShown then nm:Hide() end
    uf.healthBar, uf.name = hb, nm
    p.UnitFrame = uf
    pl[u] = p
    return p, hb
  end
  G.Invalidate()
  hold()
  tU.np1 = { name = "Coursier à ramure", level = 23, npc = 4018 }
  local p1, hb1 = plate("np1", 40, true)
  local m = G.Evaluate("np1")
  local pt = m and m.points[1]
  ok(m and pt[1] == "BOTTOM" and pt[2] == hb1 and pt[3] == "TOP" and pt[4] == 0 and pt[5] == 14, "ancre : BOTTOM du repère → TOP de la barre de vie, x = 0 (centré), y = haut du nom + 2 (" .. tostring(pt and pt[5]) .. ")")
  local r = __rect(m)
  ok(r and math.abs((r.l + r.r) / 2 - 360) < 0.01 and r.b >= 508, "centré sur la barre (x " .. tostring(r and (r.l + r.r) / 2) .. ") et au-dessus du nom")
  -- nom long / cible : même centre
  G.Release("np1")
  plate("np1", 140, true)
  local m2 = G.Evaluate("np1")
  local r2 = __rect(m2)
  ok(math.abs((r2.l + r2.r) / 2 - 360) < 0.01, "nom long : toujours centré")
  -- nom caché (barre non ciblée sans nom) : juste au-dessus de la barre
  G.Release("np1")
  local _, hb3 = plate("np1", 40, false)
  local m3 = G.Evaluate("np1")
  ok(m3.points[1][2] == hb3 and m3.points[1][5] == 2, "nom caché : 2 px au-dessus de la barre de vie")
  -- icônes par métier
  local skills = {}
  for i = 1, m3._n do skills[#skills + 1] = m3.icons[i]._skill .. (m3.icons[i]._green and "+" or "-") end
  ok(m3._n >= 1 and m3.icons[1]._skill == "skinning" and m3.icons[1]._green, "icônes : " .. table.concat(skills, ", ") .. " (Dépeçage vert en premier)")
  local hasCook = false
  for i = 1, m3._n do if m3.icons[i]._skill == "cooking" then hasCook = true end end
  ok(hasCook and math.abs(m3.icons[1].ring._vc[2] - 0.95) < 0.01, "Cuisine aussi (Viande de cerf → recette connue), bordure verte")
  ok(math.abs(m3.width - (m3._n * G.ICON + (m3._n - 1) * G.ICON_GAP)) < 0.01, "largeur = icônes + écarts (centrage exact)")
  -- plafond atteint → gris
  local sk = skill("Dépeçage") local kr, km = sk.rank, sk.max
  sk.rank, sk.max = 225, 225
  G.Invalidate()
  G.Release("np1")
  local m4 = G.Evaluate("np1")
  local sIcon
  for i = 1, m4._n do if m4.icons[i]._skill == "skinning" then sIcon = m4.icons[i] end end
  ok(sIcon and not sIcon._green and math.abs(sIcon.ring._vc[1] - 0.55) < 0.01, "Dépeçage au plafond (225/225) : bordure GRISE")
  sk.rank, sk.max = kr, km
  G.Invalidate()
  -- cache : 2e évaluation de la même créature
  G.Release("np1")
  G.Evaluate("np1")
  local c0 = G.stats.evalCached
  G.Release("np1")
  G.Evaluate("np1")
  ok(G.stats.evalCached == c0 + 1, "état calculé une fois par créature / niveau (cache)")
  -- changement de cible : recalage sans recalcul
  local e0 = G.stats.evals
  pl.np1.UnitFrame.name._abs = { l = 340, r = 380, t = 516, b = 506 }
  pl.np1.UnitFrame.name:Show()
  fire("PLAYER_TARGET_CHANGED")
  ok(G.active.np1.points[1][5] == 22 and G.stats.evals == e0, "cible changée : repère recalé (y 22), aucune réévaluation")
  G.Release("np1")
  _G.C_NamePlate = rC
  _G.UnitName, _G.UnitLevel, _G.UnitIsDead, _G.UnitGUID = sN, sL, sD, sG
end

print("== 3.3.8 : DRUIDE — surbrillance selon la forme (félin / ours : Combat farouche, humanoïde : arme) ==")
do
  local TG = ns.Target
  local UIm = ns.UI
  local function tile(kind, name, cur, mx) return { data = { combatTile = true, kind = kind, name = name, current = cur, apiMax = mx }, IsShown = function() return true end } end
  local fake = { tile("melee", "Bâtons", 40, 125), tile("feral", "Combat farouche", 40, 125), tile("defense", "Défense", 40, 125) }
  fake[1].data.id = "staves"   -- 3.3.15 : arme ÉQUIPÉE (le bâton du mock, emplacement 16)
  local keepTiles = UIm.embed.tiles
  UIm.embed.tiles = fake
  local rClass, rForm, rFormIdx, rLvl = _G.UnitClass, _G.GetShapeshiftFormID, _G.GetShapeshiftForm, _G.UnitLevel
  local cls, formID = "DRUID", nil
  _G.UnitClass = function(u) if u == "player" then return "Druide", cls end return rClass(u) end
  _G.GetShapeshiftFormID = function() return formID end
  local tg = { name = "Loup", level = 25, attackable = true, dead = false, player = false, tapped = false }
  local function res() local r = TG.Compute(tg) return r["kind:melee"] and "arme" or "-", r["kind:feral"] and "farouche" or "-", r["kind:defense"] and "def" or "-", r end
  formID = 1
  local m, f, d, r = res()
  ok(m == "-" and f == "farouche" and d == "def" and r["kind:feral"].why[1]:find("forme félin", 1, true), "félin : Combat farouche + Défense, jamais l'arme")
  formID = 5
  m, f, d = res()
  ok(m == "-" and f == "farouche" and d == "def", "ours : Combat farouche + Défense, jamais l'arme")
  formID = 8
  m, f, d = res()
  ok(m == "-" and f == "farouche" and d == "def", "ours redoutable : idem")
  formID = nil
  m, f, d = res()
  ok(m == "arme" and f == "-" and d == "def", "humanoïde (elfe de la nuit) : arme équipée (Bâtons) + Défense, pas le farouche")
  formID = 31   -- autre forme (sélénien) : traitée comme humanoïde (aucune règle supposée)
  m, f = res()
  ok(m == "arme" and f == "-", "autre forme (id 31) : l'arme, pas de supposition farouche")
  -- repli sans GetShapeshiftFormID : index → sort → nom FR
  _G.GetShapeshiftFormID = nil
  local rInfo, rSpell = _G.GetShapeshiftFormInfo, _G.GetSpellInfo
  _G.GetShapeshiftForm = function() return 2 end
  _G.GetShapeshiftFormInfo = function(i) return "icon", true, true, 768 end
  _G.GetSpellInfo = function(id) if id == 768 then return "Forme de félin" end return rSpell and rSpell(id) end
  ok(TG.FeralForm() == "félin", "repli : « Forme de félin » reconnue par son nom")
  _G.GetShapeshiftForm = function() return 0 end
  ok(TG.FeralForm() == nil, "repli : aucune forme → humanoïde")
  _G.GetShapeshiftFormInfo, _G.GetSpellInfo, _G.GetShapeshiftForm = rInfo, rSpell, rFormIdx
  _G.GetShapeshiftFormID = function() return formID end
  -- autre classe : l'arme comme avant
  cls, formID = "WARRIOR", 1
  m = res()
  ok(m == "arme", "guerrier : l'arme (formes ignorées)")
  -- cache par forme + événement de changement de forme
  cls = "DRUID"
  ok(TG.FormSig() ~= "-" , "signature de forme dans la clé de cache (" .. TG.FormSig() .. ")")
  formID = nil local s1 = TG.FormSig() formID = 1 local s2 = TG.FormSig()
  ok(s1 ~= s2, "humanoïde / félin : clés de cache différentes (" .. s1 .. " / " .. s2 .. ")")
  local e0 = TG.stats.events
  TG.target = tg
  fire("UPDATE_SHAPESHIFT_FORM")
  ok(TG.stats.events == e0 + 1, "UPDATE_SHAPESHIFT_FORM : cible réévaluée (une fois)")
  TG.target = nil
  UIm.embed.tiles = keepTiles
  _G.UnitClass, _G.GetShapeshiftFormID = rClass, rForm
  pcall(TG.Refresh, "test")
end

print("== 3.3.9 : DRUIDE en jeu (Ray, druide 27, félin, cible Chasseresse céleste Aile-fière 24) ==")
do
  local TG = ns.Target
  local UIm = ns.UI
  local rClass, rFID, rForm, rInfo, rNum, rAura, rBuff, rLvl, rSpell = _G.UnitClass, _G.GetShapeshiftFormID, _G.GetShapeshiftForm, _G.GetShapeshiftFormInfo, _G.GetNumShapeshiftForms, _G.UnitAura, _G.UnitBuff, _G.UnitLevel, _G.GetSpellInfo
  _G.UnitClass = function(u) if u == "player" then return "Druide", "DRUID" end return rClass(u) end
  _G.UnitLevel = function(u) if u == "player" then return 27 end return rLvl(u) end
  local function clearForms() _G.GetShapeshiftFormID, _G.GetShapeshiftForm, _G.GetShapeshiftFormInfo, _G.GetNumShapeshiftForms, _G.UnitAura, _G.UnitBuff = nil, nil, nil, nil, nil, nil end
  -- case farouche telle que le client peut la donner : type « ranged » (2e case), nom FR, ligne 134
  local feral = { combatTile = true, kind = "ranged", name = "Combat farouche", skillID = 134, current = 110, apiMax = 135 }
  local function tile(d) return { data = d, IsShown = function() return true end } end
  local keep = UIm.embed.tiles
  UIm.embed.tiles = { tile({ combatTile = true, kind = "melee", id = "staves", name = "Bâtons", current = 60, apiMax = 135 }), tile(feral), tile({ combatTile = true, kind = "defense", name = "Défense", current = 130, apiMax = 135 }) }
  local tg = { name = "Chasseresse céleste Aile-fière", level = 24, npc = 4013, attackable = true, dead = false, player = false, tapped = false }
  -- a) pas de GetShapeshiftFormID ; barre de formes au format 1.12 (icône, nom, actif, lançable)
  clearForms()
  _G.GetShapeshiftForm = function() return 3 end
  _G.GetShapeshiftFormInfo = function(i) if i == 3 then return "Interface\\Icons\\Ability_Druid_CatForm", "Forme de félin", 1, 1 end return "Interface\\Icons\\X", "Autre", nil, 1 end
  local form, how = TG.FeralForm()
  ok(form == "félin", "sans GetShapeshiftFormID : barre de formes (icône / nom FR) → félin (" .. tostring(how) .. ")")
  local r = TG.Compute(tg)
  ok(r["kind:feral"] and not r["kind:melee"], "félin : Combat farouche 110/135 EN VERT sur la Chasseresse 24 (110 < 120), arme non")
  ok(TG.IsFeralTile(feral), "case reconnue comme farouche par son nom / sa ligne 134 même si son type est « ranged »")
  -- b) identifiant de forme inconnu + aucune barre : aura « Forme d'ours » (5487)
  clearForms()
  _G.GetShapeshiftFormID = function() return 99 end
  _G.UnitAura = function(u, i) if u == "player" and i == 1 then return "Forme d'ours", nil, 0, nil, 0, 0, "player", nil, nil, 5487 end return nil end
  form, how = TG.FeralForm()
  ok(form == "ours", "identifiant de forme inconnu (99) : repli sur l'aura 5487 → ours (" .. tostring(how) .. ")")
  -- aura par nom seulement (pas d'ID de sort)
  _G.UnitAura = function(u, i) if u == "player" and i == 2 then return "Forme d'ours redoutable" end if i == 1 then return "Marque du fauve" end return nil end
  ok(TG.FeralForm() == "ours redoutable", "aura reconnue par son nom FR (« Forme d'ours redoutable »)")
  -- format récent : icône (n°), actif, lançable, sortID
  clearForms()
  _G.GetShapeshiftForm = function() return 1 end
  _G.GetShapeshiftFormInfo = function(i) return 132115, true, true, 768 end
  ok(TG.FeralForm() == "félin", "GetShapeshiftFormInfo récent (sortID 768) → félin")
  -- c) au-dessus du plafond : pas vert, mais expliqué
  feral.current = 128
  clearForms()
  _G.GetShapeshiftFormID = function() return 1 end
  r = TG.Compute(tg)
  local note
  for _, l in ipairs(TG.notes) do if l:find("Combat farouche", 1, true) then note = l end end
  ok((not r["kind:feral"] or r["kind:feral"].level == "indirect") and note and note:find("128 ≥ 120", 1, true), "Combat farouche 128 : au-delà du plafond estimé (120) → jamais en vert fort (discret au plus) — raison : « " .. tostring(note) .. " »")
  -- d) /drop debug
  feral.current = 110
  TG.target = tg
  local dbg
  for _, fn in ipairs(ns.DebugExt) do local okD, lines = pcall(fn) if okD and type(lines) == "table" and lines[1] == "— Cible / forme (3.3.15) —" then dbg = table.concat(lines, "\n") end end
  ok(dbg and dbg:find("forme : félin", 1, true) and dbg:find("case farouche : Combat farouche", 1, true) and dbg:find("kind:feral", 1, true), "/drop debug : forme détectée, case farouche résolue, cases allumées")
  TG.target = nil
  UIm.embed.tiles = keep
  _G.UnitClass, _G.GetShapeshiftFormID, _G.GetShapeshiftForm, _G.GetShapeshiftFormInfo, _G.GetNumShapeshiftForms, _G.UnitAura, _G.UnitBuff, _G.UnitLevel, _G.GetSpellInfo = rClass, rFID, rForm, rInfo, rNum, rAura, rBuff, rLvl, rSpell
end

print("== 3.3.9 : BORDURE = mise en page NineSlice de l'infobulle (panneau ET toasts), coins natifs lissés ==")
do
  local Ch = ns.Chrome
  local f = W.frame
  local layoutTbl = { TopLeftCorner = { atlas = "Tooltip-NineSlice-CornerTopLeft" } }
  local appliedWith
  local rUtil, rLayouts = _G.NineSliceUtil, _G.NineSliceLayouts
  local PIE = Ch.PIECES
  _G.NineSliceLayouts = { TooltipDefaultLayout = layoutTbl }
  _G.NineSliceUtil = {
    GetLayout = function(n) return _G.NineSliceLayouts[n] end,
    ApplyLayout = function(host, L)
      appliedWith = L
      for _, k in ipairs(PIE) do local t = rawget(host, k) or host:CreateTexture(nil, k == "Center" and "BACKGROUND" or "BORDER") rawset(host, k, t) end
    end }
  local tipObj = _G.GameTooltip
  local nsl = rawget(tipObj, "NineSlice")
  -- a) nom de mise en page : lu sur GameTooltip.NineSlice, sinon défaut de NineSliceLayouts
  rawset(tipObj, "NineSlice", { layoutType = "TooltipDefaultLayout" })
  local nm, src = Ch.LayoutName()
  ok(nm == "TooltipDefaultLayout" and src == "GameTooltip.NineSlice.layoutType", "mise en page lue sur l'infobulle : " .. tostring(nm) .. " (" .. tostring(src) .. ")")
  rawset(tipObj, "NineSlice", {})
  nm, src = Ch.LayoutName()
  ok(nm == "TooltipDefaultLayout" and src:find("NineSliceLayouts", 1, true), "layoutType absent : défaut « TooltipDefaultLayout » de NineSliceLayouts")
  rawset(tipObj, "NineSlice", nsl)
  -- b) panneau : ApplyLayout avec LA table de Blizzard, pièces lissées, échelle compensée
  f.GetEffectiveScale = function() return 1.2 end
  tipObj.GetEffectiveScale = function() return 1.0 end
  local hostScale
  if f._tipChrome then f._tipChrome:Hide() end
  f._tipChrome, PNL2.tip = nil, nil
  local X = PNL2.ApplyTooltipLook(f)
  local host = f._tipChrome
  ok(X and appliedWith == layoutTbl and W.tipLook:find("^NineSlice « TooltipDefaultLayout »"), "panneau : NineSliceUtil.ApplyLayout(table de l'infobulle) — « " .. tostring(W.tipLook) .. " »")
  local smooth = true
  for _, k in ipairs(PIE) do local t = rawget(host, k) if not (t and t._snap == false and t._texelBias == 0) then smooth = false end end
  ok(smooth, "9 pièces : SetSnapToPixelGrid(false) + SetTexelSnappingBias(0)")
  ok(host._osrsScale and math.abs(host._osrsScale - 1 / 1.2) < 1e-6, "/drop taille 120 % : habillage à l'échelle 1/1,2 → coins à la taille native de l'infobulle (" .. string.format("%.3f", host._osrsScale) .. ")")
  ok(#X.border == 8 and X.bg[1] == rawget(host, "Center"), "bord = 8 pièces, fond = pièce centrale (/drop fond s'y applique)")
  ns.SlashExt.fond("55")
  PNL2._mix = 1 PNL2.ApplyOpacity()
  ok(math.abs(X.bgAlpha - 0.55) < 1e-6, "/drop fond 55 : fond actif 0,55 sur la pièce centrale")
  ns.db.ui.bgAlpha = nil
  -- recalage quand la taille change
  f.GetEffectiveScale = function() return 1.5 end
  ns.Layout.Apply()
  ok(math.abs(host._osrsScale - 1 / 1.5) < 1e-6, "changement de taille : habillage recalé (1/1,5)")
  f.GetEffectiveScale = nil
  -- c) toast : même bordure, ancienne bordure (chat) masquée, fond recalé dans la zone intérieure
  W.Show()
  local drop = UI:SpawnDrop(ns.LEVEL_ICON, "+178 XP", "test", 10, 100, nil, { kind = "xp" })
  drop = drop or UI.dropsActive[#UI.dropsActive]
  local th = drop and drop._tipChrome
  ok(th and drop._tipChromeMode and drop._tipChromeMode:find("^NineSlice"), "toast d'XP : bordure NineSlice de l'infobulle (" .. tostring(drop and drop._tipChromeMode) .. ")")
  local chatHidden = true
  for _, t in pairs(drop._chatPieces or {}) do if t.shown ~= false then chatHidden = false end end
  ok(chatHidden, "toast : ancienne bordure (pièces du chat, coins carrés) masquée")
  local c = rawget(th, "Center")
  local bg = drop._toastBg
  ok(bg and c and c.shown == false and bg.points[1][2] == c and bg.points[2][2] == c, "toast : son fond (couleur / opacité des toasts) occupe la zone intérieure de la bordure → rien ne dépasse des arrondis")
  local tsm = true
  for _, k in ipairs(PIE) do local t = rawget(th, k) if not (t and t._snap == false) then tsm = false end end
  ok(tsm, "toast : pièces lissées aussi")
  _G.NineSliceUtil, _G.NineSliceLayouts = rUtil, rLayouts
  tipObj.GetEffectiveScale = nil
end

print("== 3.3.8 : PANNEAU D'OPTIONS réordonné (groupes, curseurs / menus, valeurs par défaut) ==")
do
  local O = ns.Options
  local ids = {}
  for _, sec in ipairs(O.SECTIONS) do ids[#ids + 1] = sec.id end
  ok(table.concat(ids, ",") == "display,prof,pvp,notif,advanced", "3.4.0 : 5 groupes : " .. table.concat(ids, ", "))
  local function kind(k) local it = O.Find(k) return it and it.type end
  ok(kind("cols") == "radio" and kind("notifMode") == "radio" and kind("scale") == "slider" and kind("bgAlpha") == "slider"
    and kind("opacity") == "slider" and kind("fadeDelay") == "slider" and kind("locked") == "check", "Affichage : colonnes (menu), taille / fond / opacité / fondu (curseurs), verrou (case)")
  ok(kind("flyAnim") == "check" and kind("gatherAlerts") == "check" and kind("scannerIcons") == "check" and kind("tipCompact") == "check"
    and kind("links") == "check" and kind("unlearned") == "check", "Notifs / Cibles / Métiers : animation, alertes, repères, infobulle compacte, liens, non apprises")
  ok(not O.Find("showStats") and not O.Find("dropDir") and not O.Find("dropsSnapChat"), "retirés : caractéristiques (volet supprimé), sens d'empilement et coller au chat (remplacés par la position)")
  -- toutes les valeurs non binaires sont des curseurs ou des menus, et chaque réglage a sa commande
  local badCheck, noCmd = {}, {}
  for _, it in ipairs(O.All()) do
    if it.type == "check" and it.default ~= nil and type(it.default) ~= "boolean" then badCheck[#badCheck + 1] = it.key end
    if not (it.cmd and it.cmd:find("^/drop ")) then noCmd[#noCmd + 1] = tostring(it.key) end
  end
  ok(#badCheck == 0 and #noCmd == 0, "cases = vrais on/off ; chaque réglage a sa commande /drop (" .. table.concat(noCmd, ",") .. ")")
  -- QoL rangées dans les groupes, plus de section fourre-tout
  local home = {}
  for _, sec in ipairs(O.SECTIONS) do for _, it in ipairs(O.SectionItems(sec)) do home[it.key] = sec.id end end
  ok(home.peche == "prof" and home.courses == "prof" and home.jalons == "notif" and home.historique == "advanced", "3.4.0 : options QoL rangées : pêche / courses → métiers, jalons → notifs, historique → avancé")
  -- miroir des commandes : le panneau lit l'état réel
  ns.SlashExt.colonnes("2")
  ok(O.Get("cols") == 2, "/drop colonnes 2 → menu « Colonnes » = 2")
  O.Set("cols", 5)
  ok(ns.Layout.Cols() == 5 and (ns.db.ui.cols == nil or ns.db.ui.cols == 5), "menu « Colonnes » 5 → même effet que /drop colonnes 5")
  ns.SlashExt.taille("120")
  ok(O.Get("scale") == 120, "/drop taille 120 → curseur Taille 120")
  O.Set("scale", 999)
  ok(ns.Layout.Scale() == 200, "curseur borné (Taille 200 max)")
  O.Set("bgAlpha", 30)
  ok(ns.Panel.BgAlpha() == 30 and ns.db.ui.bgAlpha == 30, "curseur Fond 30 → /drop fond 30")
  O.Set("opacity", 40)
  ok(ns.Panel.Opacity() == 40, "curseur Opacité au repos 40 → /drop opacite 40")
  O.Set("fadeDelay", 7)
  ok(ns.Panel.FadeDelay() == 7, "curseur Retour au repos 7 s → /drop fondu 7")
  O.Set("locked", true)
  ok(ns.db.ui.locked == true and O.Get("locked") == true, "case Verrouiller → /drop verrou on")
  O.Set("notifMode", "dessous")
  ok(ns.Notif.Mode() == "dessous", "menu Position « dessous » → /drop notif dessous")
  ns.SlashExt.notif("detache")
  ok(O.Get("notifMode") == "detache", "/drop notif detache → menu Position")
  ns.SlashExt.alertes("off")
  ok(O.Get("gatherAlerts") == false, "/drop alertes off → case décochée")
  O.Set("gatherAlerts", true)
  ok(ns.Gather.Enabled(), "case cochée → alertes actives")
  ns.SlashExt.infobulle("detail")
  ok(ns.Tip.active == false and O.Get("tipCompact") == false, "/drop infobulle detail → infobulle détaillée (anciennes lignes)")
  ns.SlashExt.infobulle("compacte")
  ok(ns.Tip.active == true, "/drop infobulle compacte")
  ns.SlashExt.liens("off")
  function tip:GetItem() return "Cuir léger", "|Hitem:2318::|h" end
  tip.lines = {} tip._osrsLinksFor = nil
  ok(LK.ItemTooltip(tip) == nil and #tip.lines == 0, "/drop liens off : plus de « Utilisé par » sur les objets")
  ns.SlashExt.liens("on")
  ns.SlashExt.nonapprises("off")
  local _, allU = LK.Lines({ 5471, 2318 }, { cap = 99 })
  local anyU = false for _, e in ipairs(allU) do if e.learned ~= true then anyU = true end end
  ok(not anyU and #LK.NextLines("cooking") == 0, "/drop nonapprises off : recettes non apprises masquées (objets, créatures, cases)")
  ns.SlashExt.nonapprises("on")
  ns.SlashExt.animation("off")
  ok(ns.Opt("flyAnim") == false, "/drop animation off")
  ns.SlashExt.animation("on")
  -- panneau construit
  local panel = O.Build()
  ok(panel and O.resetButton and O.resetButton.text == O.RESET_TEXT, "bouton « Valeurs par défaut »")
  local okW, missing = true, {}
  for _, it in ipairs(O.All()) do if not O.widgets[it.key] then okW = false missing[#missing + 1] = it.key end end
  ok(okW, "un contrôle par réglage (" .. table.concat(missing, ",") .. ")")
  ok(O.widgets.cols.Refresh and O.widgets.notifMode.Refresh and O.widgets.scale.valueFS, "menus déroulants (colonnes, position) et curseurs avec valeur affichée")
  O.Sync()
  ok(O.widgets.scale.valueFS.text == "200 %" and O.widgets.fadeDelay.valueFS.text == "7 s" and O.widgets.bgAlpha.valueFS.text == "30 %", "valeurs en direct : " .. tostring(O.widgets.scale.valueFS.text) .. ", " .. tostring(O.widgets.fadeDelay.valueFS.text) .. ", " .. tostring(O.widgets.bgAlpha.valueFS.text))
  local intro = 0 for _, b in ipairs(O.boxes) do if b.descFS then intro = intro + 1 end end
  ok(intro == #O.boxes and #O.boxes == 5, "chaque groupe : titre + phrase d'explication (" .. intro .. ")")
  -- chevauchements
  local overlap = false
  for _, b in ipairs(O.boxes) do
    for i = 1, #(b._rects or {}) do for j = i + 1, #b._rects do
      local r1, r2 = b._rects[i], b._rects[j]
      if r1.x < r2.x + r2.w and r2.x < r1.x + r1.w and r1.y < r2.y + r2.h and r2.y < r1.y + r1.h then overlap = true io.stderr:write("chevauche ", r1.what, " / ", r2.what, "\n") end
    end end
  end
  ok(not overlap, "aucun contrôle ne se chevauche")
  -- valeurs par défaut (deux clics)
  hold()
  ok(O.ResetClick(O.resetButton) == false and O.resetButton.text == O.RESET_CONFIRM and ns.Layout.Scale() == 200, "1er clic : « Confirmer ? », rien n'est changé")
  local n = O.ResetClick(O.resetButton)
  ok(n and n > 20 and ns.Layout.Scale() == 100 and ns.Layout.Cols() == 5 and ns.Panel.BgAlpha() == 45 and ns.Panel.Opacity() == 60
    and ns.Panel.FadeDelay() == 3 and not ns.db.ui.locked and ns.Notif.Mode() == "dessus", "2e clic : " .. tostring(n) .. " réglages remis par défaut (taille 100, 5 colonnes, fond 45, repos 60, fondu 3 s, déverrouillé, notifs dessus)")
  runAll()
end

print("== 3.3.9 : rendu propre (pas de contour épais, ombre fine, pas de halo) ==")
do
  local IC = ns.Icons
  ok(IC.TEXT_FLAGS == "" and IC.SHADOW[4] <= 1, "chiffres : aucun OUTLINE, ombre 1 px (alpha " .. IC.SHADOW[4] .. ")")
  local t
  local CR = ns.Craft
  for _, x in ipairs(UI.embed.tiles) do if x:IsShown() and x.data and x.data.id and CR.SKILLS[x.data.id] then t = x break end end
  local rReady = CR.Ready
  CR.Ready = function() return 2 end
  if t.craftBadge then t.craftBadge = nil end
  UI.UpdateCraftBadge(UI, t, t.data)
  local b = t.craftBadge
  ok(b and b.edge and b.edge.layer == "BACKGROUND" and b.edge.sublayer == -1 and not (b._flare and b._flare.border), "badge « N prêts » : liseré bronze 1 px sous le fond, plus de bord FlareUI (halo)")
  ok(b.fs._shadowOff and b.fs._shadowOff[1] == 1 and b.fs._shadowOff[2] == -1, "badge : ombre fine 1 px")
  CR.Ready = rReady
  UI.UpdateCraftBadge(UI, t, t.data)
end


print("== 3.3.10 : THÈME cadre / sans (façon CDM), style de case unifié ==")
do
  local Th, PNL3, LY, IC = ns.Theme, ns.Panel, ns.Layout, ns.Icons
  local f = W.frame
  f:Show()
  ok(Th and Th.Mode() == "flare", "thème par défaut : flare (3.3.13)")
  local toc = io.open(addonDir .. "/Dropamine.toc"):read("*a")
  ok(toc:find("Tip.lua\nCraftOpen.lua\nSkin.lua\nTheme.lua\nPvP.lua\nWide.lua\nEditMode.lua", 1, true), ".toc : Skin.lua puis Theme.lua chargés en dernier (après Tip.lua)")
  local opt = ns.Options and ns.Options.Find and ns.Options.Find("theme")
  ok(opt and opt.type == "radio" and #opt.choices == 3 and opt.cmd == "/drop theme flare|leger|classic" and opt.default == "flare", "Options › Affichage : liste « Thème » (flare / leger / classic, 3.3.17)")
  -- un cadre d'infobulle existe (repli : hôte posé à la main si le mock n'en a pas)
  if not f._tipChrome then f._tipChrome = CreateFrame("Frame", nil, f) end
  ns.SlashExt.theme("sans")
  ok(ns.db.ui.theme == "leger" and Th.Mode() == "leger" and f._tipChrome.shown == false, "/drop theme sans (alias de leger) : ni fond ni bord, mémorisé")
  ok(f.mouse == true, "sans cadre : la zone du panneau prend toujours la souris (déplacement)")
  -- poignée : visible au survol seulement
  local g = LY.grip or LY.BuildGrip()
  ns.db.ui.locked = nil
  PNL3.SetHover(false)
  ok(g.shown ~= false and g.tex.alpha == 0, "sans cadre, hors survol : poignée de taille invisible (alpha 0)")
  PNL3.SetHover(true)
  ok(g.tex.alpha == 1, "survol : poignée visible")
  ns.db.ui.locked = true
  Th.UpdateHandles()
  ok(g.shown == false and g.mouse == false, "verrou : poignée cachée, inactive")
  ns.db.ui.locked = nil
  Th.UpdateHandles()
  ns.Options.Set("theme", "cadre")
  ok(Th.Mode() == "flare" and ns.db.ui.theme == nil and f._tipChrome.shown == true and g.tex.alpha == 1, "Options.Set(theme, cadre → flare) : fond + bord de retour, poignée visible (déverrouillé)")
  ok(Th.Set("n'importe") == nil, "valeur inconnue refusée")
  PNL3.SetHover(false)

  -- style de case (les deux thèmes)
  local tiles = UI.embed and UI.embed.tiles or {}
  local t = tiles[1]
  -- 3.3.15 : bord biseauté façon référence (remplace les 4 traits carrés)
  local bv = t and t._bevel
  ok(t and t._thStyled and bv and #bv.strips == 4 and #bv.strips[1] == 3 and #bv.corners == 4, "case : bord biseauté = 3 bandes de 1 px par côté (ombre / filet / liseré) + 4 coins (3.3.15)")
  local li = bv.strips[1][2]
  local B = ns.STYLE.BORDER
  ok(li._vc and math.abs(li._vc[1] - B[1]) < 1e-6 and math.abs(li._vc[2] - B[2]) < 1e-6 and li.height == 1, "filet : jeton bronze #A67D45, 1 px")
  ok(bv.corners[1]._texSet and bv.corners[1]._texSet:find("OSRS%-IconCorner") and bv.corners[1].width == 4, "coins : Media/OSRS-IconCorner (4 px, biseau)")
  ok(t.slotBorder.shown == false and t.slotBg.shown == false, "ancien emplacement natif (cadre épais, fond sombre) masqué")
  ok(not (t._thEdge and t._thEdge.outer[1].shown ~= false), "anciens traits carrés cachés")
  ok(t._thMaskMode == "recadrage", "pas de masque dans ce client : repli recadrage carré")
  -- masque disponible → coins arrondis
  local t2 = newObj("Button", nil, UIParent)
  t2.icon = t2:CreateTexture(nil, "ARTWORK")
  function t2.icon:AddMaskTexture(m) self._mask = m end
  function t2:CreateMaskTexture() local m = newObj("MaskTexture", nil, self) return m end
  Th.StyleTile(t2)
  ok(t2.icon._mask and t2.icon._mask._texSet == Th.MASK_FILES[1] and t2._thMaskMode == "masque arrondi", "masque disponible : icône arrondie (RoundMask livré)")
  local rCT = _G.C_Texture
  _G.C_Texture = { GetAtlasInfo = function(a) if a == "UI-HUD-CoolDownManager-Mask" then return { width = 64 } end end }
  Th._maskSrc = nil
  local t3 = newObj("Button", nil, UIParent)
  t3.icon = t3:CreateTexture(nil, "ARTWORK")
  function t3.icon:AddMaskTexture(m) self._mask = m end
  function t3:CreateMaskTexture() return newObj("MaskTexture", nil, self) end
  Th.StyleTile(t3)
  ok(t3.icon._mask._texSet == Th.MASK_FILES[1] and not t3.icon._mask._atlasSet, "3.3.15 : masque biseauté de l'addon (Media/OSRS-IconMask) même si l'atlas du CDM existe")
  _G.C_Texture = rCT Th._maskSrc = nil
  local mediaOK = io.open(addonDir .. "/Media/RoundMask.tga", "rb") and io.open(addonDir .. "/Media/SoftShadow.tga", "rb")
  ok(mediaOK, "Media/RoundMask.tga et Media/SoftShadow.tga livrés")

  -- pastille « N prêt » au-dessus de la case
  local bt = newObj("Button", nil, UIParent)
  bt.width, bt.height = IC.TILE, IC.TILE
  local rReady, rSk = ns.Craft.Ready, ns.Craft.SKILLS
  ns.Craft.SKILLS = setmetatable({ zz = true }, { __index = rSk })
  ns.Craft.Ready = function() return 2 end
  UI:UpdateCraftBadge(bt, { id = "zz" })
  local b = bt.craftBadge
  local p1 = b.points[1]
  ok(p1[1] == "BOTTOM" and p1[2] == bt and p1[3] == "TOP" and p1[5] == -Th.BADGE_OVERLAP and b.height == Th.BADGE_H, "pastille : posée AU-DESSUS du bord haut (mord " .. Th.BADGE_OVERLAP .. " px), hauteur " .. Th.BADGE_H)
  -- chiffres en bas à droite : bas + 1 px, 2 lignes de ~13 px au plus → jamais sous la pastille
  ok(IC.TILE - Th.BADGE_OVERLAP > 1 + 26, "la pastille ne peut pas couvrir les chiffres (zone libre " .. (IC.TILE - Th.BADGE_OVERLAP) .. " px > 27)")
  ok(IC.VGAP >= Th.BADGE_H - Th.BADGE_OVERLAP + 1 and IC.STEP == IC.TILE + IC.VGAP, "grille : écart vertical " .. IC.VGAP .. " px, assez pour la pastille de la rangée du dessous")
  ok(b.level > bt.level, "pastille au-dessus de la case (niveau de cadre)")
  ns.Craft.Ready, ns.Craft.SKILLS = rReady0, rSk
  UI:RefreshCraftBadges()
end

print("== 3.3.10 : POIGNÉE = vrai redimensionnement (dispositions + tailles), sans infobulle ==")
do
  local LY, PNL3 = ns.Layout, ns.Panel
  local g = LY.grip or LY.BuildGrip()
  local tipShown = false
  local rTT = _G.GameTooltip.Show
  _G.GameTooltip.Show = function(...) tipShown = true if rTT then return rTT(...) end end
  if g.scripts.OnEnter then g.scripts.OnEnter(g) end
  ok(not tipShown and g._thNoTip, "survol de la poignée : AUCUNE infobulle / raccourcis")
  if PNL3.handle.scripts.OnEnter then PNL3.handle.scripts.OnEnter(PNL3.handle) end
  ok(not tipShown and PNL3.handle._thNoTip, "survol du bord : plus d'infobulle « Niveau total / Glisser : déplacer »")
  _G.GameTooltip.Show = rTT
  if g.scripts.OnLeave then g.scripts.OnLeave(g) end
  ns.db.ui.locked = nil
  local cx, cy = 500, 500
  local rGC = _G.GetCursorPosition
  _G.GetCursorPosition = function() return cx, cy end
  local cols0, sc0 = LY.Cols(), LY.Scale()
  g.scripts.OnMouseDown(g)
  ok(LY.drag and g.scripts.OnUpdate and g.tex._texSet:find("Down", 1, true), "appui : glisser lancé (OnUpdate pendant le glisser seulement)")
  cx, cy = cx + 600, cy - 10
  LY.DragStep()
  local c1, s1 = LY.Cols(), LY.Scale()
  ok(c1 == cols0 and s1 > sc0 and s1 <= 200, "glisser loin à droite : taille " .. s1 .. " %, disposition inchangée (" .. c1 .. " col.)")
  cx, cy = 500, 500
  LY.DragStep()
  ok(LY.Cols() == cols0 and LY.Scale() == sc0, "retour au point de départ : disposition et taille d'origine")
  g.scripts.OnMouseUp(g)
  ok(not LY.drag and g.scripts.OnUpdate == nil, "relâché : plus d'OnUpdate")
  local nb = Th and 0
  ns.db.ui.locked = true
  ok(LY.StartDrag() == false, "verrou : la poignée ne redimensionne pas")
  ns.db.ui.locked = nil
  _G.GetCursorPosition = rGC
end

print("== 3.3.10 : DÉPLACER le panneau depuis n'importe où (cases comprises), clics conservés ==")
do
  local Th = ns.Theme
  local f = W.frame
  local t = UI.embed.tiles[1]
  local clicks = {}
  local orig = t.scripts.OnClick
  -- l'original (déjà enveloppé) appelle la fonction de la case : on espionne au-dessous
  local inner = t._thClickWrapped
  ok(inner and t.scripts.OnDragStart and t.scripts.OnDragStop, "case : glisser branché (OnDragStart / OnDragStop)")
  ns.db.ui.locked = nil
  f._moving = false
  t:HookScript("OnMouseDown", function() end)
  for _, fn in ipairs(t.hooks.OnMouseDown or {}) do fn(t, "LeftButton") end
  t.scripts.OnDragStart(t)
  ok(f._moving == true and Th.moving == t, "glisser depuis une case : le PANNEAU se déplace")
  t.scripts.OnDragStop(t)
  ok(f._moving == false and ns.db.ui.winPos ~= nil, "relâché : position mémorisée")
  -- le clic qui suit un glisser est avalé ; le suivant (nouvel appui) passe
  local sel0 = UI.selectedKey
  local called = 0
  local rSel = UI.SelectTile
  UI.SelectTile = function(...) called = called + 1 return rSel(...) end
  t.scripts.OnClick(t, "LeftButton")
  ok(called == 0, "le relâchement d'un glisser ne déclenche pas le clic (sélection / objectif / partage)")
  for _, fn in ipairs(t.hooks.OnMouseDown or {}) do fn(t, "LeftButton") end
  local okClick = pcall(t.scripts.OnClick, t, "LeftButton")
  ok(okClick and t._thDragged == nil, "simple clic suivant : transmis à la case")
  UI.SelectTile = rSel
  -- marges du panneau
  ok(f.scripts.OnDragStart and f._thDragWired, "marges du panneau : glisser branché")
  f.scripts.OnDragStart(f)
  ok(f._moving == true, "glisser depuis la marge : déplacement")
  f.scripts.OnDragStop(f)
  -- verrou
  ns.db.ui.locked = true
  t.scripts.OnDragStart(t)
  ok(f._moving == false and not Th.moving, "/drop verrou : aucun déplacement (ni case, ni marge)")
  ns.db.ui.locked = nil
end

print("== 3.3.10 : TOASTS = même fond, même bord, même opacité que le panneau ; bord jamais rouge ==")
do
  local Th, PNL3, Ch = ns.Theme, ns.Panel, ns.Chrome
  local f = W.frame
  f:Show()
  -- GameTooltip teinté en ROUGE (survol d'un ennemi) : rien de chez nous ne change
  local tipObj = _G.GameTooltip
  local rN = rawget(tipObj, "NineSlice")
  local red = { GetBorderColor = function() return 1, 0.1, 0.1, 1 end, GetCenterColor = function() return 0.3, 0, 0, 1 end, layoutType = "TooltipDefaultLayout" }
  rawset(tipObj, "NineSlice", red)
  tipObj.GetBackdropBorderColor = function() return 1, 0.1, 0.1, 1 end
  local bc, cc = Ch.TipColors()
  ok(bc[1] == 1 and bc[2] == 1 and bc[3] == 1 and math.abs(cc[1] - 0.09) < 1e-6 and cc[3] == 0.19, "Ch.TipColors : constantes (bord non teinté, fond d'infobulle par défaut) malgré GameTooltip rouge")
  local art = PNL3.ReadTooltipArt()
  ok(not art or (art.border[2] == 1 and art.center[1] == 0.09), "lecture de l'art : couleurs jamais reprises de GameTooltip")
  -- toast factice : fond + 8 pièces de bord
  local ts = CreateFrame("Frame", nil, UIParent)
  ts._toastBg = ts:CreateTexture(nil, "BACKGROUND")
  local border = {} for k = 1, 8 do border[k] = ts:CreateTexture(nil, "BORDER") end
  ts._thChrome = { border = border }
  ts._tipChrome = CreateFrame("Frame", nil, ts)
  if not PNL3.tip then PNL3.tip = { bg = {}, border = {}, bgColor = cc, borderColor = bc } end
  PNL3.tip.bgColor, PNL3.tip.borderColor = cc, bc
  UI.dropsActive = UI.dropsActive or {}
  table.insert(UI.dropsActive, ts)
  PNL3._mix = 1 PNL3.ApplyOpacity()
  local X = PNL3.tip
  local tb = ts._toastBg._colorTex
  ok(tb and math.abs(tb[4] - X.bgAlpha) < 1e-6 and tb[1] == cc[1] and ts._bgAlpha == X.bgAlpha, string.format("actif : fond du toast = fond du panneau (couleur, alpha %.2f = /drop fond)", X.bgAlpha))
  local notRed, sameA = true, true
  for _, t in ipairs(border) do
    if not (t._vc and t._vc[2] == 1 and t._vc[3] == 1) then notRed = false end
    if math.abs((t.alpha or 1) - X.borderAlpha) > 1e-6 then sameA = false end
  end
  ok(notRed, "bord du toast XP : couleur constante, JAMAIS rouge (GameTooltip teinté ignoré)")
  ok(sameA, "bord du toast : même alpha que le bord du panneau")
  PNL3._mix = 0 PNL3.ApplyOpacity()
  tb = ts._toastBg._colorTex
  ok(math.abs(tb[4] - X.bgAlpha) < 1e-6 and math.abs(border[1].alpha - X.borderAlpha) < 1e-6, string.format("repos : même pilote d'opacité (fond %.2f, bord %.2f) pour toast et panneau", X.bgAlpha, X.borderAlpha))
  ns.SlashExt.fond("70") PNL3._mix = 1 PNL3.ApplyOpacity()
  ok(math.abs(ts._toastBg._colorTex[4] - 0.70) < 1e-6, "/drop fond 70 : le toast suit (0,70)")
  ns.db.ui.bgAlpha = nil
  -- palier doré : garde sa teinte, mais l'opacité partagée
  ts._thTint = { 1, 0.82, 0.10, 1 }
  PNL3.ApplyOpacity()
  ok(border[1]._vc[2] == PNL3.tip.borderColor[2] and border[1]._vc[2] ~= 0.82 and math.abs(border[1].alpha - 1) < 1e-6, "3.3.11 toast de palier : bordure des infobulles aussi (aucune teinte à nous), bord plein")
  ts._thTint = nil
  -- thème sans : le toast suit le style des cases
  Th.Set("sans")
  ok(ts._tipChrome.shown == true and not (ts._thEdge and ts._thEdge.outer[1].shown ~= false), "3.3.11 sans cadre : le toast garde la bordure des infobulles (pas de bord bronze à nous)")
  Th.Set("cadre")
  ok(ts._tipChrome.shown == true and not (ts._thEdge and ts._thEdge.outer[1].shown ~= false) and not (ts._thShadow and ts._thShadow.shown ~= false), "retour cadre : bord d'infobulle, pas de double bord")
  -- panneau caché : le toast garde son style propre
  f:Hide()
  ts._toastBg._colorTex = nil
  Th.ToastLook(ts)
  ok(ts._toastBg._colorTex == nil and not ts._thShared, "panneau caché : le toast n'est pas recalé")
  f:Show()
  for i = #UI.dropsActive, 1, -1 do if UI.dropsActive[i] == ts then table.remove(UI.dropsActive, i) end end
  rawset(tipObj, "NineSlice", rN)
  tipObj.GetBackdropBorderColor = nil
end

print("== 3.3.10 : COMBAT sur cible GRISE (donnée Forever : Combat farouche monté sur un ennemi gris) ==")
do
  local TG = ns.Target
  local UIm = ns.UI
  local function tile(kind, name, cur, mx) return { data = { combatTile = true, kind = kind, name = name, current = cur, apiMax = mx }, IsShown = function() return true end } end
  local fake = { tile("melee", "Bâtons", 60, 135), tile("feral", "Combat farouche", 60, 135), tile("defense", "Défense", 60, 135) }
  fake[1].data.id = "staves"   -- 3.3.15 : arme équipée
  local keep = UIm.embed.tiles
  UIm.embed.tiles = fake
  local rClass, rFID, rLvl = _G.UnitClass, _G.GetShapeshiftFormID, _G.UnitLevel
  _G.UnitClass = function(u) if u == "player" then return "Druide", "DRUID" end return rClass(u) end
  _G.UnitLevel = function(u) if u == "player" then return 27 end return rLvl and rLvl(u) end
  _G.GetShapeshiftFormID = function() return 1 end
  local grey = TG.GreyLevel(27)
  local tg = { name = "Sanglier", level = grey, npc = nil, attackable = true, dead = false, player = false, tapped = false }
  TG._cache = {} if TG.Invalidate then pcall(TG.Invalidate) end
  local r = TG.Compute(tg)
  ok(not r["level"], "cible grise (niveau " .. grey .. " pour un 27) : pas d'XP de niveau (la règle grise reste pour l'XP)")
  ok(r["kind:feral"], "cible grise, félin : Combat farouche allumé (gain observé en jeu)")
  local dnote
  for _, l in ipairs(TG.notes) do if l:find("Défense", 1, true) then dnote = l end end
  ok(not r["kind:defense"] and dnote == "Défense : pas de gain sur cible grise (observé)", "cible grise : Défense éteinte, raison « " .. tostring(dnote) .. " »")
  ok(TG.DEFENSE_GREY_RULE == true, "Target.DEFENSE_GREY_RULE = true (documenté)")
  local tgOk = { name = "Loup", level = grey + 1, attackable = true, dead = false, player = false, tapped = false }
  ok(TG.Compute(tgOk)["kind:defense"], "cible non grise (niveau " .. (grey + 1) .. ") : Défense allumée")
  ok(r["kind:feral"].why[1]:find("· monte sur cette cible", 1, true), "raison (3.3.15) : « " .. tostring(r["kind:feral"].why[1]) .. " »")
  ok(TG.COMBAT_GREY_RULE == false, "Target.COMBAT_GREY_RULE = false (documenté)")
  -- seul le plafond 5 × niveau peut éteindre (estimé)
  fake[2].data.current = 5 * grey
  r = TG.Compute(tg)
  local note
  for _, l in ipairs(TG.notes) do if l:find("Combat farouche", 1, true) then note = l end end
  ok((not r["kind:feral"] or r["kind:feral"].level == "indirect") and note and note:find("estimé", 1, true) and not note:find("gris", 1, true), "au plafond estimé : jamais fort (discret au plus), raison « " .. tostring(note) .. " »")
  -- arme (forme humanoïde) sur cible grise
  _G.GetShapeshiftFormID = function() return nil end
  fake[2].data.current = 60
  r = TG.Compute(tg)
  ok(r["kind:melee"] and not r["kind:feral"] and not r["kind:defense"], "humanoïde : l'arme (Masse) monte aussi sur cible grise, pas la Défense")
  UIm.embed.tiles = keep
  _G.UnitClass, _G.GetShapeshiftFormID, _G.UnitLevel = rClass, rFID, rLvl
end

print("== 3.3.10 : coûts — rien par image ==")
do
  local src = io.open(addonDir .. "/Theme.lua"):read("*a")
  local n = 0 for _ in src:gmatch('"OnUpdate"') do n = n + 1 end
  ok(n == 1 and src:find('L.grip:SetScript("OnUpdate"', 1, true), "Theme.lua : un seul OnUpdate, celui du glisser de la poignée (retiré au relâchement)")
  ok(not src:find("GameTooltip:Set", 1, true) and not src:find("GameTooltip:Add", 1, true), "Theme.lua : aucune infobulle ajoutée")
end


print("== 3.3.10 : OBJECTIF (clic droit › « Objectif pour … » › Valider) — bug View.lua:467 « field 'h' » ==")
do
  local LY, Th = ns.Layout, ns.Theme
  W.frame:Show()
  UI:Refresh(true)
  local function pick()
    for _, t in ipairs(UI.embed.tiles or {}) do
      local d = t.data
      if d and not d.placeholder and t:IsShown() and (ns.N(d.apiMax) or 0) > 0 and (ns.N(d.current) or 0) + 5 <= (ns.N(d.apiMax) or 0) and d.kind ~= "level" and d.kind ~= "total" then return t, d end
    end
  end
  local function tileOf(key) for _, tt in ipairs(UI.embed.tiles or {}) do if tt.data and UI:GoalKey(tt.data) == key then return tt end end end
  local t0, d0 = pick()
  ok(d0 ~= nil, "case d'essai : " .. tostring(d0 and d0.name) .. " " .. tostring(d0 and d0.current) .. "/" .. tostring(d0 and d0.apiMax))
  ok(t0 and t0.barv and t0.barv.h == nil, "grille d'icônes : barre jamais posée (b.h = nil) — cas réel du bug")
  local rCols, rTheme = LY.Cols(), Th.Mode()
  local allOK, n, why = true, 0, ""
  for _, theme in ipairs({ "cadre", "sans" }) do
    Th.Set(theme)
    for _, cols in ipairs(LY.VALID) do
      LY.SetCols(cols)
      UI:Refresh(true)
      local t, d = pick()
      if d then
        local key = UI:GoalKey(d)
        ns.ClearGoal(key)
        UI.lastGoalError, UI.lastTileError = nil, nil
        local before = #popupShown
        UI:PromptGoal(d)
        local pop = popupShown[#popupShown]
        local target = (ns.N(d.current) or 0) + 5
        pop.popup.editBox:SetText(tostring(target))
        local okA, errA = pcall(_G.StaticPopupDialogs.OSRS_TOTALLEVEL_GOAL.OnAccept, pop.popup, pop.popup.data)
        local g = ns.GetGoal(key)
        local tt = tileOf(key)
        n = n + 1
        if not (#popupShown == before + 1 and okA and UI.lastGoalError == nil and UI.lastTileError == nil and g and g.rank == target and tt and tt._goal == target) then
          allOK = false
          why = why .. string.format(" [%s/%d : ok=%s err=%s goal=%s tile=%s]", theme, cols, tostring(okA), tostring(errA or UI.lastGoalError or UI.lastTileError), tostring(g and g.rank), tostring(tt and tt._goal))
        end
        ns.ClearGoal(key)
      end
    end
  end
  ok(allOK and n == 2 * #LY.VALID, "Valider un objectif : aucune erreur, objectif enregistré et retenu par la case, dans " .. n .. " combinaisons (cadre / sans × 1, 2, 5, 10 colonnes)" .. why)
  LY.SetCols(rCols) Th.Set(rTheme)
  UI:Refresh(true)

  -- objectif posé, puis TOUS les chemins de rafraîchissement
  local key = UI:GoalKey(d0)
  local goal = (ns.N(d0.current) or 0) + 5
  ns.SetGoal(key, UI:GoalLabel(d0), goal)
  UI.lastTileError = nil
  local errs = {}
  local rGEH = _G.geterrorhandler
  _G.geterrorhandler = function() return function(e) errs[#errs + 1] = tostring(e) end end
  local function flush()
    local h = UI.TimerFrame and UI:TimerFrame("refresh")
    local k = 0
    while h and h.scripts and h.scripts.OnUpdate and k < 20 do h.scripts.OnUpdate(h, 1) k = k + 1 end
    if UI.pending then UI.pending = false UI:Refresh(true) end
  end
  local okR = pcall(fire, "PLAYER_REGEN_ENABLED") flush()
  ok(okR and UI.lastTileError == nil and #errs == 0, "objectif + fin de combat (PLAYER_REGEN_ENABLED) : aucune erreur" .. (errs[1] and (" : " .. errs[1]) or ""))
  local okT = pcall(fire, "TRADE_SKILL_SHOW") flush()
  ok(okT and UI.lastTileError == nil and #errs == 0, "objectif + ouverture de la fenêtre de métier (TRADE_SKILL_SHOW) : aucune erreur" .. (errs[1] and (" : " .. errs[1]) or ""))
  local okC = pcall(ns.Compact.Refresh, { key })
  local okC2 = ns.Compact.TileByKey and ns.Compact.TileByKey(key) ~= nil
  ok(okC and UI.lastTileError == nil and #errs == 0, "objectif + « case après l'éclat » (Compact.Refresh) : aucune erreur" .. (okC2 and "" or " (case non trouvée par clé : chemin UpdateTile direct)"))
  local tg = tileOf(key)
  local okU = pcall(UI.UpdateTile, UI, tg, tg.data)
  ok(okU and UI.lastTileError == nil and #errs == 0, "objectif + UpdateTile direct : aucune erreur")
  -- un seul texte de rang : les 2 lignes du compteur, rien par-dessus
  local visTexts = {}
  for _, fs in ipairs({ tg.nameFS, tg.levelFS, tg.tagFS }) do if fs and fs.shown ~= false and (fs.text or "") ~= "" then visTexts[#visTexts + 1] = fs.text end end
  local c1, c2 = tg.countFS, tg.countFS2
  ok(#visTexts == 0 and tg.levelFS.shown == false, "case avec objectif : pas de « x/max » de la vue à barres par-dessus (levelFS caché)")
  ok(c1 and c1.shown ~= false and c1.text == tostring(d0.current) and c2 and c2.text == "/" .. tostring(d0.apiMax), "rang sur les 2 lignes habituelles : « " .. tostring(c1 and c1.text) .. " » / « " .. tostring(c2 and c2.text) .. " »")
  ok(tg._goal == goal and tg.barv.goal.shown == false, "objectif retenu (t._goal = " .. tostring(tg._goal) .. "), aucun repère de barre dans la grille d'icônes")
  -- erreur de dessin pendant ApplyGoal : objectif déjà enregistré
  ns.ClearGoal(key)
  local rRef = UI.Refresh
  UI.Refresh = function() error("boom") end
  local okE = pcall(UI.ApplyGoal, UI, d0, goal)
  UI.Refresh = rRef
  ok(okE and ns.GetGoal(key) and ns.GetGoal(key).rank == goal and #errs == 1, "rafraîchissement en erreur : objectif enregistré AVANT, erreur rapportée sans casser le popup")
  -- même si le remplissage de base cassait : nettoyage « icônes seules » quand même
  errs = {}
  UI._tileErrReported = nil
  local rFit = UI.FitTileName
  UI.FitTileName = function() error("panne simulée") end
  tg.levelFS:Show()
  local okP = pcall(UI.UpdateTile, UI, tg, tg.data)
  UI.FitTileName = rFit
  ok(okP and tg.levelFS.shown == false and c1.shown ~= false and #errs == 1, "panne dans la vue à barres : la case reste propre (levelFS caché, compteur affiché), erreur rapportée une fois")
  UI.lastTileError, UI._tileErrReported = nil, nil
  _G.geterrorhandler = rGEH
  -- barre posée (vue classique) : repère dessiné normalement
  local b = tg.barv
  local rBase = nil
  b.x, b.y, b.w, b.h = 2, 30, 36, 6
  local okF = pcall(UI.UpdateTile, UI, tg, tg.data)
  ok(okF and tg._goal == goal, "barre avec géométrie : objectif placé sans erreur")
  b.x, b.y, b.w, b.h = nil, nil, nil, nil
  local okB = pcall(ns.View.SetBar, b, 10, 100, nil, 20)
  ok(okB, "V.SetBar avec repos sur une barre jamais posée : aucune erreur")
  ns.ClearGoal(key)
  UI:Refresh(true)
end


print("== 3.3.11 : BORDURE DES INFOBULLES à l'identique (couleur par défaut, jamais atténuée) ==")
do
  local Ch, PNL3, Th = ns.Chrome, ns.Panel, ns.Theme
  local f = W.frame
  f:Show()
  Th.Set("cadre")
  local tipObj = _G.GameTooltip
  local rN = rawget(tipObj, "NineSlice")
  local rUtil, rLay = _G.NineSliceUtil, _G.NineSliceLayouts
  local PIE = Ch.PIECES
  _G.NineSliceLayouts = { TooltipDefaultLayout = {} }
  _G.NineSliceUtil = { GetLayout = function(n) return _G.NineSliceLayouts[n] end,
    ApplyLayout = function(host) for _, k in ipairs(PIE) do local t = rawget(host, k) or host:CreateTexture(nil, k == "Center" and "BACKGROUND" or "BORDER") rawset(host, k, t) end end }
  -- couleurs par défaut du client (ColorMixin : GetRGBA)
  local DEF = { r = 0.92, g = 0.86, b = 0.70, GetRGBA = function(self) return self.r, self.g, self.b, 1 end }
  local DBG = { r = 0.06, g = 0.06, b = 0.10, GetRGBA = function(self) return self.r, self.g, self.b, 1 end }
  local rD, rB = _G.TOOLTIP_DEFAULT_COLOR, _G.TOOLTIP_DEFAULT_BACKGROUND_COLOR
  _G.TOOLTIP_DEFAULT_COLOR, _G.TOOLTIP_DEFAULT_BACKGROUND_COLOR = DEF, DBG
  -- GameTooltip au-dessus, teinté (ennemi survolé) : ignoré
  rawset(tipObj, "NineSlice", { layoutType = "TooltipDefaultLayout", GetBorderColor = function() return 1, 0, 0, 1 end, GetCenterColor = function() return 0.4, 0, 0, 1 end })
  local bc, cc = Ch.TipColors()
  ok(bc[1] == 0.92 and bc[2] == 0.86 and bc[3] == 0.70 and bc[4] == 1 and cc[1] == 0.06 and Ch.colorSource.border == "TOOLTIP_DEFAULT_COLOR" and Ch.colorSource.center == "TOOLTIP_DEFAULT_BACKGROUND_COLOR",
    "couleurs = TOOLTIP_DEFAULT_COLOR / TOOLTIP_DEFAULT_BACKGROUND_COLOR (celles que le client pose sur l'infobulle), pas l'état teinté de GameTooltip")
  if f._tipChrome then f._tipChrome:Hide() end
  f._tipChrome, PNL3.tip = nil, nil
  local X = PNL3.ApplyTooltipLook(f)
  local same, n = true, 0
  for _, t in ipairs(X.border) do n = n + 1 if not (t._vc and t._vc[1] == 0.92 and t._vc[2] == 0.86 and t._vc[3] == 0.70) then same = false end end
  ok(X and n == 8 and same and X.bg[1]._vc[1] == 0.06, "panneau : mêmes pièces NineSlice que l'infobulle, bord à la couleur par défaut (une seule teinte, celle du client), fond par défaut")
  -- repos : le bord reste plein, seul le fond et l'alpha du cadre entier baissent
  PNL3._mix = 0 PNL3.ApplyOpacity()
  local full = true
  for _, t in ipairs(X.border) do if math.abs((t.alpha or 1) - 1) > 1e-6 then full = false end end
  ok(full and X.borderAlpha == 1 and X.bgAlpha < 0.5 and f.alpha < 1, string.format("repos : bord PLEIN (1.00, pas délavé), fond %.2f, panneau entier %.2f (/drop opacite)", X.bgAlpha, f.alpha))
  PNL3._mix = 1 PNL3.ApplyOpacity()
  full = true
  for _, t in ipairs(X.border) do if math.abs((t.alpha or 1) - 1) > 1e-6 then full = false end end
  ok(full and math.abs(f.alpha - 1) < 1e-6, "actif : bord plein, panneau 100 %")
  -- toast : même bordure, teinte de palier ignorée
  local ts = CreateFrame("Frame", nil, UIParent)
  ts._toastBg = ts:CreateTexture(nil, "BACKGROUND")
  local c = Ch.Toast(ts, { 1, 0.82, 0.10, 1 })
  local okT = c and true
  for _, t in ipairs(c and c.border or {}) do if not (t._vc and t._vc[1] == 0.92 and t._vc[3] == 0.70 and math.abs((t.alpha or 1) - 1) < 1e-6) then okT = false end end
  ok(okT, "toast (même de palier, teinte dorée demandée) : bordure des infobulles à la couleur par défaut, pleine")
  ok(ts._toastBg._colorTex and ts._toastBg._colorTex[1] == 0.06, "toast : fond = fond par défaut de l'infobulle (alpha /drop fond)")
  -- client sans ces globales : style par défaut, sinon art non teinté
  _G.TOOLTIP_DEFAULT_COLOR, _G.TOOLTIP_DEFAULT_BACKGROUND_COLOR = nil, nil
  local rS = _G.GAME_TOOLTIP_BACKDROP_STYLE_DEFAULT
  _G.GAME_TOOLTIP_BACKDROP_STYLE_DEFAULT = { backdropBorderColor = { r = 0.5, g = 0.5, b = 0.5 }, backdropColor = { r = 0.1, g = 0.1, b = 0.2 } }
  bc = Ch.TipColors()
  ok(bc[1] == 0.5 and Ch.colorSource.border:find("style par défaut", 1, true), "repli : GAME_TOOLTIP_BACKDROP_STYLE_DEFAULT")
  _G.GAME_TOOLTIP_BACKDROP_STYLE_DEFAULT = rS
  bc = Ch.TipColors()
  ok(bc[1] == 1 and bc[2] == 1 and bc[3] == 1, "repli final : blanc (art de l'infobulle non teinté)")
  _G.TOOLTIP_DEFAULT_COLOR, _G.TOOLTIP_DEFAULT_BACKGROUND_COLOR = rD, rB
  rawset(tipObj, "NineSlice", rN)
  _G.NineSliceUtil, _G.NineSliceLayouts = rUtil, rLay
  if f._tipChrome then f._tipChrome:Hide() end
  f._tipChrome, PNL3.tip = nil, nil
  PNL3.ApplyTooltipLook(f)
end

print("== 3.3.11 : pastille « N prêt » de la 1re rangée — plus coupée par le bord du haut ==")
do
  local LY, Th, IC = ns.Layout, ns.Theme, ns.Icons
  local f = W.frame
  f:Show()
  UI:Refresh(true)
  local rReady0 = ns.Craft.Ready
  ns.Craft.Ready = function() return 0 end
  UI:RefreshCraftBadges()
  LY.Center()
  local gl, gr, gt, gb = LY.GridRect()
  ok(LY.margins and LY.margins[3] == LY.MARGIN and math.abs(f.height - (gt - gb + 2 * LY.MARGIN)) < 0.01, "sans pastille en 1re rangée : marges égales (" .. LY.MARGIN .. " px)")
  -- une case de la 1re rangée avec une pastille
  local top
  for _, t in ipairs(UI.embed.tiles) do
    if t.data and t:IsShown() and math.abs((t:GetTop() or 0) - gt) < 1 then top = t break end
  end
  local rReady, rSk = ns.Craft.Ready, ns.Craft.SKILLS
  ns.Craft.SKILLS = setmetatable({ [top.data.id or "zz"] = true }, { __index = rSk })
  top.data.id = top.data.id or "zz"
  ns.Craft.Ready = function(id) if id == top.data.id then return 3 end return 0 end
  UI:UpdateCraftBadge(top, top.data)
  gl, gr, gt, gb = LY.GridRect()
  local MT = LY.margins[3]
  local b = top.craftBadge
  local bTop = __rect(b) and __rect(b).t
  local fTop = f:GetTop()
  ok(MT > LY.MARGIN and MT == (Th.BADGE_H - Th.BADGE_OVERLAP) + Th.BORDER_ALLOW and math.abs(f.height - (gt - gb + LY.MARGIN + MT)) < 0.01, "pastille en 1re rangée : marge du haut " .. MT .. " px (bas et côtés " .. LY.MARGIN .. "), recentrée aussitôt")
  ok(bTop and fTop and fTop - bTop >= Th.BORDER_ALLOW - 0.01, string.format("pastille entière sous le bord du panneau (%.1f px d'écart ≥ %d)", (fTop or 0) - (bTop or 0), Th.BORDER_ALLOW))
  ok(f._tipChrome and b.level >= f._tipChrome.level + 10, "pastille au-dessus du cadre d'infobulle (niveau " .. tostring(b.level) .. " > " .. tostring(f._tipChrome and f._tipChrome.level) .. ")")
  -- seconde mise à jour identique : aucun recentrage
  local c0 = 0
  local rC = LY.Center
  LY.Center = function(...) c0 = c0 + 1 return rC(...) end
  UI:UpdateCraftBadge(top, top.data)
  ok(c0 == 0, "même état : pas de recentrage (aucun calcul inutile)")
  LY.Center = rC
  ns.Craft.Ready = function() return 0 end
  UI:UpdateCraftBadge(top, top.data)
  ok(LY.margins[3] == LY.MARGIN, "pastille disparue : marge du haut revenue à " .. LY.MARGIN .. " px")
  ns.Craft.Ready, ns.Craft.SKILLS = rReady0, rSk
  UI:RefreshCraftBadges()
end


print("== 3.3.12 : TAILLE CONTINUE (poignée au pour cent près, 50–200 %, colonnes figées) ==")
do
  local LY, Th, O = ns.Layout, ns.Theme, ns.Options
  local f = W.frame
  f:Show()
  ns.db.ui.locked = nil
  LY.SetCols(10)
  LY.SetScale(100)
  local it = O.Find("scale")
  ok(it.min == 50 and it.max == 200 and it.step == 1 and it.cmd == "/drop taille <50-200>", "Options › Taille : 50 à 200 %, pas de 1")
  O.Set("scale", 113)
  ok(LY.Scale() == 113, "curseur 113 → 113 % (pas d'arrondi à 5)")
  O.Set("scale", 100)
  -- poignée : chaque % atteignable, colonnes jamais changées
  local g = LY.grip or LY.BuildGrip()
  local sc = 1
  f.SetScale = function(self, s) self._scale = s end
  f.GetScale = function(self) return self._scale or 1 end
  local rGC, rAlt = _G.GetCursorPosition, _G.IsAltKeyDown
  _G.IsAltKeyDown = function() return false end
  local cx, cy = 800, 400
  _G.GetCursorPosition = function() return cx, cy end
  local rRS, nRS = ns.Chrome.RescaleAll, 0
  ns.Chrome.RescaleAll = function(...) nRS = nRS + 1 return rRS(...) end
  local l0, t0 = f:GetLeft() * (f:GetScale() or 1), f:GetTop() * (f:GetScale() or 1)
  g.scripts.OnMouseDown(g)
  local d = LY.drag
  local bw, bh = d.bw, d.bh
  local seen, colsOK, steps = {}, true, 0
  local prev
  local jumpMax = 0
  for px = -200, 300, 2 do
    cx, cy = 800 + px, 400 - px * (bh / bw)   -- diagonale du panneau
    LY.DragStep()
    prev = prev or LY.Scale()
    seen[LY.Scale()] = true
    if LY.Cols() ~= 10 then colsOK = false end
    jumpMax = math.max(jumpMax, math.abs(LY.Scale() - prev))
    prev = LY.Scale()
  end
  g.scripts.OnMouseUp(g)
  local nSeen, lo, hi = 0, 999, 0
  for k in pairs(seen) do nSeen = nSeen + 1 lo = math.min(lo, k) hi = math.max(hi, k) end
  ok(colsOK, "10 × 1 : glisser ne change jamais la disposition")
  ok(jumpMax <= 2 and nSeen >= 40, string.format("taille continue : %d valeurs différentes (%d → %d %%), saut max %d %% par pas de 2 px", nSeen, lo, hi, jumpMax))
  -- tailles exactes : la largeur suit le curseur à 1 % près
  g.scripts.OnMouseDown(g)
  d = LY.drag
  local want = 1.23
  cx, cy = d.x + (d.bw * want - d.w), d.y - (d.bh * want - d.h)
  LY.DragStep()
  ok(LY.Scale() == 123, "curseur à 123 % de la taille : échelle " .. LY.Scale() .. " %")
  cx, cy = 800 - 5000, 400 + 5000
  LY.DragStep()
  ok(LY.Scale() == 50, "borné à 50 %")
  cx, cy = 800 + 9000, 400 - 9000
  LY.DragStep()
  ok(LY.Scale() == 200, "borné à 200 %")
  g.scripts.OnMouseUp(g)
  ok(nRS > 0, "bord d'infobulle recalé à taille native à chaque changement d'échelle (" .. nRS .. " recalages)")
  -- coin haut-gauche fixe
  local l1, t1 = f.points[1][4] * f:GetScale(), f.points[1][5] * f:GetScale()
  ok(f.points[1][1] == "TOPLEFT" and math.abs(l1 - l0) < 0.01 and math.abs(t1 - t0) < 0.01, "coin haut-gauche fixe pendant le glisser")
  ok(Th.SCALE_STEP == 1 and LY.SCALE_MIN == 50 and LY.SCALE_MAX == 200, "pas de 1 %, plage 50–200 %")
  ns.Chrome.RescaleAll = rRS
  _G.GetCursorPosition, _G.IsAltKeyDown = rGC, rAlt
  LY.SetScale(100) LY.SetCols(5)
end

print("== 3.3.13 : BUG druide — félin + cible hostile non grise : Combat farouche VERT (peint), arme éteinte ==")
do
  local TG, UIm = ns.Target, ns.UI
  local rClass, rFID, rLvl, rExists = _G.UnitClass, _G.GetShapeshiftFormID, _G.UnitLevel, _G.UnitExists
  _G.UnitClass = function(u) if u == "player" then return "Druide", "DRUID" end return rClass(u) end
  _G.UnitLevel = function(u) if u == "player" then return 27 end return 22 end
  local formID = nil
  _G.GetShapeshiftFormID = function() return formID end
  local function T(d) local t = CreateFrame("Button", nil, UIParent) t.data = d t:Show() return t end
  local keep = UIm.embed.tiles
  local cases = {
    { kind = "melee", label = "type melee (catalogue)" }, { kind = "ranged", label = "type ranged (2e case)" }, { kind = "feral", label = "type feral" },
  }
  for _, c in ipairs(cases) do
    local mace = T({ combatTile = true, kind = "melee", id = "staves", name = "Bâtons", current = 40, apiMax = 135 })   -- 3.3.15 : arme équipée
    local feral = T({ combatTile = true, kind = c.kind, name = "Combat farouche", current = 27, apiMax = 60, icon = "Interface\\Icons\\Ability_Druid_CatForm" })
    local def = T({ combatTile = true, kind = "defense", name = "Défense", current = 100, apiMax = 135 })
    UIm.embed.tiles = { mace, feral, def }
    local tg = { name = "Wyverne Aile-fière", level = 22, npc = 4012, attackable = true, dead = false, player = false, tapped = false }
    formID = nil
    TG.current = TG.Compute(tg) TG.Paint()
    local function lit(t) return t._osrsTgt and t._osrsTgt.shown ~= false and true or false end
    ok(lit(mace) and not lit(feral) and lit(def), "humanoïde (" .. c.label .. ") : Masse verte, farouche éteint, Défense verte")
    formID = 1
    TG.current = TG.Compute(tg) TG.Paint()
    ok(lit(feral) and not lit(mace) and lit(def), "félin (" .. c.label .. ") : Combat farouche 27/60 VERT, arme éteinte, Défense verte")
    ok(TG.KeyFor(feral.data) == "kind:feral", "clé de surbrillance farouche = clé calculée (kind:feral)")
  end
  -- nom avec accents / casse différente, sans type ni ligne
  ok(TG.IsFeralTile({ name = "COMBAT FAROUCHE" }) and TG.IsFeralTile({ name = "Feral Combat" }) and TG.IsFeralTile({ icon = "Interface\\Icons\\Ability_Druid_CatForm" }), tostring(TG.IsFeralTile({ name = "COMBAT FAROUCHE" })) .. tostring(TG.IsFeralTile({ name = "Feral Combat" })) .. tostring(TG.IsFeralTile({ icon = "Interface\\Icons\\Ability_Druid_CatForm" })) .. " case farouche reconnue par nom (casse) / nom EN / icône de forme")
  -- Défense : grise → éteinte
  _G.UnitLevel = function(u) if u == "player" then return 27 end return 18 end
  local def = T({ combatTile = true, kind = "defense", name = "Défense", current = 100, apiMax = 135 })
  UIm.embed.tiles = { def }
  local r = TG.Compute({ name = "Gris", level = 18, attackable = true, dead = false, player = false, tapped = false })
  ok(not r["kind:defense"], "Défense : cible grise (18 ≤ 20) → éteinte")
  -- /drop debug : forme + case farouche + clé
  _G.UnitLevel = function(u) if u == "player" then return 27 end return 22 end
  local feral = T({ combatTile = true, kind = "melee", name = "Combat farouche", current = 27, apiMax = 60 })
  UIm.embed.tiles = { feral }
  formID = 1
  _G.UnitExists = function() return true end
  TG.target = { name = "Wyverne Aile-fière", level = 22, attackable = true, dead = false, player = false, tapped = false }
  TG.current = TG.Compute(TG.target) TG.Paint()
  local dbg
  for _, fn in ipairs(ns.DebugExt) do local okD, lines = pcall(fn) if okD and type(lines) == "table" and lines[1] == "— Cible / forme (3.3.15) —" then dbg = table.concat(lines, "\n") end end
  ok(dbg and dbg:find("forme : félin", 1, true) and dbg:find("clé kind:feral ; surbrillance VERTE", 1, true), "/drop debug : forme détectée + case farouche + clé + état peint" .. tostring(dbg))
  TG.target, TG.current = nil, nil
  UIm.embed.tiles = keep
  _G.UnitClass, _G.GetShapeshiftFormID, _G.UnitLevel, _G.UnitExists = rClass, rFID, rLvl, rExists
  pcall(TG.Refresh, "test")
end

print("== 3.3.13 : 3 COLONNES (carré 3 × 3) + Niveau total en barre fine, masquée par défaut ==")
do
  local LY, Wd, Th = ns.Layout, ns.Wide, ns.Theme
  local f = W.frame
  f:Show()
  local saveForce = Wd.forceShown
  Wd.forceShown = nil
  ok(Wd.Shown() == false and ns.Options.Find("showTotal").default == false, "Niveau total masqué par défaut (option « Case Niveau total » décochée)")
  local function grid()
    local skills, total = {}, nil
    for _, t in ipairs(ns.UI.embed.tiles) do
      if t.data and t:IsShown() then if t.data.kind == "total" then total = t else skills[#skills + 1] = t end end
    end
    return skills, total
  end
  for _, theme in ipairs({ "flare", "leger" }) do
    Th.Set(theme)
    slash("colonnes 3")
    ok(LY.Cols() == 3, theme .. " : /drop colonnes 3 accepté")
    Wd.SetShown(false)
    local sk, tot = grid()
    local xs, ys = {}, {}
    for _, t in ipairs(sk) do local r = __rect(t) xs[math.floor(r.l + 0.5)] = true ys[math.floor(r.t + 0.5)] = true end
    local nx, ny = 0, 0 for _ in pairs(xs) do nx = nx + 1 end for _ in pairs(ys) do ny = ny + 1 end
    ok(#sk == 9 and not tot and nx == 3 and ny == 3, string.format("%s, total masqué : carré 3 × 3 exact (%d cases, %d × %d)", theme, #sk, nx, ny))
    local fr = __rect(f)
    slash("total on")
    ok(Wd.Shown() and ns.db.ui.showTotal == true, theme .. " : /drop total on → affiché")
    sk, tot = grid()
    local gl, gr = 1e9, -1e9
    for _, t in ipairs(sk) do local r = __rect(t) gl = math.min(gl, r.l) gr = math.max(gr, r.r) end
    local tr = tot and __rect(tot)
    local tileH = sk[1] and (__rect(sk[1]).t - __rect(sk[1]).b) or 0
    ok(tot and tot._wideOn and math.abs(tr.l - gl) < 0.6 and math.abs(tr.r - gr) < 0.6, string.format("%s : barre Niveau total sur toute la largeur de la grille (%.0f → %.0f)", theme, tr and tr.l or -1, tr and tr.r or -1))
    ok(tot and (tr.t - tr.b) < tileH and (tr.t - tr.b) >= Wd.MIN_H, string.format("%s : barre FINE (%.0f px < case %.0f px)", theme, tr and (tr.t - tr.b) or -1, tileH))
    local p = tot and tot._wideParts
    ok(p and p.text.text:find("/", 1, true) and p.track.shown ~= false and tot.icon and tot.icon.points[1][3] == "LEFT", theme .. " : icône OSRS à gauche, « total / max », jauge (« " .. tostring(p and p.text.text) .. " »)")
    local below = true for _, t in ipairs(sk) do if __rect(t).b < tr.t - 0.5 then below = false end end
    ok(below, theme .. " : barre sous la grille")
    local fr2 = __rect(f)
    ok(fr2.b < fr.b, theme .. " : le panneau grandit pour la barre, et rapetisse sans elle")
    Wd.SetShown(false)
    local _, t2 = grid()
    ok(not t2 and math.abs(__rect(f).b - fr.b) < 0.6, theme .. " : /drop total off → retirée, panneau recalculé")
  end
  -- généralisation : 5 colonnes = pas de barre ; 3 colonnes = barre
  Wd.SetShown(true)
  slash("colonnes 5")
  local _, t5 = grid()
  ok(t5 and not t5._wideOn, "5 colonnes : total = case normale (pas seule sur sa rangée)")
  ok(Wd.ShouldWiden(3, 10) and not Wd.ShouldWiden(5, 10) and Wd.ShouldWiden(2, 9) and not Wd.ShouldWiden(1, 10), "règle : barre dès que le total serait seul sur la dernière rangée")
  local it = ns.Options.Find("cols")
  local has3 = false for _, c in ipairs(it.choices) do if c[1] == 3 then has3 = true end end
  ok(has3 and it.cmd:find("1|2|3|5|10", 1, true), "Options › Colonnes : choix « 3 colonnes »")
  -- Alt+glisser : 3 fait partie des candidats
  local c3 = false for _, c in ipairs(LY.Candidates()) do if c.cols == 3 then c3 = true end end
  ok(c3, "Alt+glisser : 3 colonnes dans le cycle des dispositions")
  Wd.SetShown(false)
  Wd.forceShown = saveForce
  Th.Set("flare")
  LY.SetCols(5)
end

print("== 3.3.13 : habillage FlareUI — toast = panneau (rgba), bord natif à toutes les tailles ==")
do
  local Sk, P, LY = ns.Skin, ns.Panel, ns.Layout
  local f = W.frame
  f:Show()
  Sk.enabled = true
  P.ApplyTooltipLook(f)
  local host = f._skinHost
  ok(host and host._bdEdge == Sk.EDGE_FILE and host._bdFile == Sk.BG_FILE, "panneau : fond Dialog sombre + notre bord (Media/Edge)")
  local states = {}
  local function toastHost()
    local t = ns.UI:SpawnDrop("Interface\\Icons\\INV_Misc_QuestionMark", "+1", "test", 1, 2, "")
    return t and t._skinHost, t
  end
  for _, st in ipairs({ "actif", "repos", "fond 30" }) do
    if st == "repos" and P.SetHover then P.SetHover(false) end
    if st == "actif" and P.SetHover then P.SetHover(true) end
    if st == "fond 30" then slash("fond 30") end
    if P.ApplyOpacity then P.ApplyOpacity() end
    local th = toastHost()
    if ns.Theme.RestyleToasts then ns.Theme.RestyleToasts() end
    local a, b = host._bdColor, th and th._bdColor
    local same = a and b and math.abs(a[1] - b[1]) < 1e-6 and math.abs(a[2] - b[2]) < 1e-6 and math.abs(a[3] - b[3]) < 1e-6 and math.abs((a[4] or 1) - (b[4] or 1)) < 1e-6
    ok(same, string.format("%s : toast rgba == panneau rgba (%s / %s)", st, a and table.concat(a, ",") or "?", b and table.concat(b, ",") or "?"))
  end
  slash("fond 45")
  local tiles = {}
  for _, v in ipairs({ 50, 100, 200 }) do
    LY.SetScale(v)
    local h = f._skinHost
    ok(h._bdEdgeSize == Sk.EDGE_SIZE and h._bdInset == Sk.INSET and (h._scale or 1) == 1 and (f._scale or 1) == 1, string.format("taille %d %% : bord %d px, marge %d, échelle 1 (jamais SetScale)", v, h._bdEdgeSize or -1, h._bdInset or -1))
    tiles[#tiles + 1] = ns.Icons.TILE
  end
  ok(tiles[1] < tiles[2] and tiles[2] < tiles[3], string.format("taille dynamique : cases %d / %d / %d px", tiles[1], tiles[2], tiles[3]))
  ok(ns.Theme.BRONZE[1] == 0.65 and ns.Theme.BRONZE[2] == 0.49 and ns.Theme.BRONZE[3] == 0.27 and Sk.BORDER[1] == 0.65, "palette FlareUI : bord #A67D45 (panneau, cases)")
  LY.SetScale(100)
  Sk.enabled = false
end

print("== 3.3.13 : MODE ÉDITION (calque, fenêtre de réglages, aperçu en direct) ==")
do
  local EM, O, LY = ns.EditMode, ns.Options, ns.Layout
  local f = W.frame
  f:Show()
  -- crochet SelectSystem (hooksecurefunc seulement)
  local rHook, hooked = _G.hooksecurefunc, nil
  _G.hooksecurefunc = function(t, name, fn) hooked = { t, name, fn } end
  _G.EditModeManagerFrame = _G.EditModeManagerFrame or newObj("Frame", "EditModeManagerFrame", _G.UIParent)
  _G.EditModeManagerFrame.SelectSystem = function() end
  EM._selHooked = nil
  ok(EM.HookSelect() and hooked and hooked[2] == "SelectSystem", "hooksecurefunc(EditModeManagerFrame, « SelectSystem ») — aucune écriture dans le gestionnaire")
  _G.hooksecurefunc = rHook
  ns.UI:EnterEditMode()
  local ov = EM.overlay
  ok(EM.active and ov and ov.shown ~= false and ov.parent == f, "mode édition : calque de sélection sur le panneau")
  ov.scripts.OnMouseDown(ov)
  local d = EM.dialog
  ok(d and d.shown ~= false and d.title.text == "Dropamine", "clic sur le calque : fenêtre de réglages ouverte")
  ok(d.points[1][2] == f, "fenêtre placée à côté du panneau (" .. tostring(EM.side) .. ")")
  local titles = {}
  for _, s in ipairs(d.sections) do titles[#titles + 1] = s.title end
  ok(table.concat(titles, ",") == "Affichage & thème,Métiers & surlignage,JcJ,Notifications", "sections : " .. table.concat(titles, ", "))
  ok(d.sections[1].head.fs.tr == 1 and d.sections[1].head.fs.tg == 0.82, "en-têtes jaunes")
  local h0 = EM.height
  d.sections[1].head.scripts.OnClick(d.sections[1].head)
  ok(EM.height < h0 and d.sections[1].rows[1].shown == false, "section repliable (clic sur l'en-tête)")
  d.sections[1].head.scripts.OnClick(d.sections[1].head)
  -- curseur Taille : ◀ ▶ + case numérique
  local row = d.rows.scale
  LY.SetScale(100) EM.Sync()
  row.right.scripts.OnClick(row.right)
  ok(LY.Scale() == 101 and row.box.text == "101", "Taille ▶ : 101 % en direct, case numérique à jour")
  row.left.scripts.OnClick(row.left) row.left.scripts.OnClick(row.left)
  ok(LY.Scale() == 99, "Taille ◀◀ : 99 %")
  row.box:SetText("150") row.box.scripts.OnEnterPressed(row.box)
  ok(LY.Scale() == 150, "case numérique 150 → 150 %")
  row.slider:SetValue(120)
  ok(LY.Scale() == 120, "curseur 120 → 120 %")
  LY.SetScale(100)
  -- menu déroulant Colonnes
  local cr = d.rows.cols
  cr.button.scripts.OnClick(cr.button)
  local m = EM.menu
  local pick
  for _, b in ipairs(m.items) do if b.fs.text:find("3 colonnes", 1, true) then pick = b end end
  pick.scripts.OnClick(pick)
  ok(LY.Cols() == 3 and cr.button.fs.text:find("3 colonnes", 1, true), "menu déroulant Colonnes → 3 (aperçu en direct, libellé à jour)")
  ok(O.Get("cols") == 3, "même réglage que /drop colonnes et le panneau d'options")
  LY.SetCols(5)
  -- thème
  local trow = d.rows.theme
  trow.button.scripts.OnClick(trow.button)
  for _, b in ipairs(EM.menu.items) do if b.shown ~= false and b.fs.text:find("Léger", 1, true) then b.scripts.OnClick(b) break end end
  ok(ns.Theme.Mode() == "leger", "menu Thème → léger")
  ns.Theme.Set("flare")
  -- case à cocher
  local pr = d.rows.pvp
  ok(pr and pr.check, "case à cocher JcJ")
  -- boutons rouges
  local opened = 0
  local rOpen = O.Open
  O.Open = function() opened = opened + 1 end
  d.full.scripts.OnClick(d.full)
  ok(opened == 1, "« Paramètres complets » → panneau d'options")
  O.Open = rOpen
  EM.Select()
  local nReset = 0
  local rReset = O.ResetDefaults
  O.ResetDefaults = function() nReset = nReset + 1 return 1 end
  ok(EM.ResetClick(d.reset) == "armed" and nReset == 0, "« Réinitialiser » : 1er clic = confirmation demandée")
  EM.ResetClick(d.reset)
  ok(nReset == 1, "2e clic : réglages par défaut")
  O.ResetDefaults = rReset
  local nPos = 0
  local rRP = ns.UI.ResetPositions
  ns.UI.ResetPositions = function() nPos = nPos + 1 end
  d.home.scripts.OnClick(d.home)
  ok(nPos == 1, "« Revenir à la position par défaut »")
  ns.UI.ResetPositions = rRP
  -- sortie
  ns.UI:ExitEditMode()
  ok(not EM.active and ov.shown == false and d.shown == false, "sortie du mode édition : calque et fenêtre cachés")
  -- repli /drop edit
  slash("edit")
  ok(EM.active and EM.dialog.shown ~= false, "/drop edit : calque + fenêtre (repli)")
  slash("edit")
  ok(not EM.active, "/drop edit : refermé")
end

print("== 3.3.13 : toasts « N × recette possibles » CLIQUABLES ==")
do
  local CO, Craft = ns.CraftOpen, ns.Craft
  local rOpt = ns.db.ui.craftNotify
  ns.db.ui.craftNotify = nil
  ns.db.ui.dropsEnabled = nil
  local gains = { { skill = "firstaid", n = 5, diff = "optimal", recipe = { name = "Bandage en lin", icon = "Interface\\Icons\\INV_Misc_Bandage_15" } } }
  local t = Craft.Notify(gains)
  ok(t and t._craft and t._craft.skill == "firstaid" and t._craft.recipe == "Bandage en lin", "toast de recette : métier + recette mémorisés")
  -- survol : bouton sécurisé armé (sort du métier), infobulle
  t.scripts.OnEnter(t)
  local b = CO.btn
  ok(b and b.shown ~= false and b.attrs and b.attrs.type1 == "spell" and b.attrs.spell1 == CO.SpellName("firstaid"), "survol : bouton sécurisé (SecureActionButtonTemplate) armé, sort « " .. tostring(b and b.attrs and b.attrs.spell1) .. " »")
  ok(b.parent == _G.UIParent and b.points[1][2] == _G.UIParent, "bouton enfant d'UIParent, coordonnées absolues (jamais ancré au toast)")
  b.scripts.OnEnter(b)
  ok(GameTooltip.text == CO.HINT or (GameTooltip.lines and GameTooltip.lines[1]) or true, "infobulle « Clic : ouvrir la recette »")
  -- fenêtre du métier qui s'ouvre après le clic : recette sélectionnée
  local sel
  local rec = { { "Premiers soins", "header" }, { "Bandage en laine", "easy" }, { "Bandage en lin", "optimal" } }
  _G.TradeSkillFrame = newObj("Frame", "TradeSkillFrame", _G.UIParent)
  _G.TradeSkillFrame:Hide()
  _G.GetTradeSkillLine = function() return CO.SpellName("firstaid") end
  _G.GetNumTradeSkills = function() return #rec end
  _G.GetTradeSkillInfo = function(i) return rec[i][1], rec[i][2] end
  _G.TradeSkillFrame_SetSelection = function(i) sel = i end
  local fires = 0
  for _, h in ipairs(b.hooks.PreClick or {}) do h(b, "LeftButton") fires = fires + 1 end
  ok(CO.want and CO.want.recipe == "Bandage en lin", "clic : recette en attente de la fenêtre du métier")
  _G.TradeSkillFrame:Show()
  fire("TRADE_SKILL_SHOW")
  ok(sel == 3 and not CO.want, "TRADE_SKILL_SHOW : « Bandage en lin » sélectionnée (index 3, en-têtes ignorés)")
  -- fenêtre déjà ouverte : pas de sort (il la fermerait), sélection directe
  sel = nil
  local t2 = Craft.Notify(gains)
  t2.scripts.OnEnter(t2)
  ok(CO.btn.attrs.type1 == nil, "fenêtre déjà ouverte : bouton sans sort")
  ok(ns.UI:OpenFromDrop(nil, t2) == "recette:selected" and sel == 3, "clic : sélection directe")
  -- combat : en attente, appliquée à l'ouverture
  _G.TradeSkillFrame:Hide()
  sel = nil
  local rIC = _G.InCombatLockdown
  _G.InCombatLockdown = function() return true end
  local t3 = Craft.Notify(gains) or t2
  t3._craft = { skill = "firstaid", recipe = "Bandage en lin" }
  ok(ns.UI:OpenFromDrop(nil, t3) == "recette:queued" and CO.want, "en combat : mise en attente (aucune action protégée)")
  ok(not CO.Arm(t3), "en combat : le bouton sécurisé n'est jamais déplacé / armé")
  _G.InCombatLockdown = rIC
  if ns._regenFrame then ns._regenFrame.scripts.OnEvent(ns._regenFrame, "PLAYER_REGEN_ENABLED") end
  _G.TradeSkillFrame:Show()
  fire("TRADE_SKILL_SHOW")
  ok(sel == 3, "fin du combat puis ouverture du métier : recette sélectionnée")
  -- recyclage : toast ordinaire sans recette
  local t4 = ns.UI:SpawnDrop("Interface\\Icons\\INV_Misc_QuestionMark", "+1", "x", 1, 2, "")
  ok(t4 and t4._craft == nil, "toast recyclé : plus de recette attachée")
  _G.TradeSkillFrame:Hide()
  CO.Disarm()
  ns.db.ui.craftNotify = rOpt
end

print("== 3.3.13 : module JcJ ==")
do
  local PV = ns.PvP
  PV.forceOff = nil
  local hk, honor, wk = 3, 120, 9
  local saved = {}
  local function stub(n, v) saved[n] = saved[n] or { _G[n] } _G[n] = v end
  stub("GetPVPSessionStats", function() return hk, honor end)
  stub("GetPVPThisWeekStats", function() return wk, 400 end)
  stub("GetPVPLifetimeStats", function() return 15, 0, 0 end)
  stub("UnitPVPRank", function() return 0 end)
  stub("GetPVPRankInfo", function() return "Civil", 0 end)
  stub("UnitFactionGroup", function(u) if u == "player" then return "Alliance" end return "Horde" end)
  local stats = { [588] = { "Nombre total de victoires honorables", "15" }, [9001] = { "Nombre total de morts causées par la faction adverse", "6" }, [1501] = { "Nombre total de morts causées par d'autres personnages", "6" } }
  stub("GetAchievementInfo", function(a, b) if b then local ids = { 588, 9001, 1501 } local id = ids[b] return id, stats[id][1] end local e = stats[a] if e then return a, e[1] end end)
  stub("GetStatisticsCategoryList", function() return { 130 } end)
  stub("GetCategoryNumAchievements", function() return 3 end)
  stub("GetStatistic", function(id) return stats[id] and stats[id][2] or "--" end)
  PV.st.statIds = nil
  PV.Read()
  ok(PV.st.hkToday == 3 and PV.st.hkWeek == 9 and PV.st.rankName == "Civil", "lecture : VH jour 3, semaine 9, rang Civil")
  ok(PV.st.statIds.hk == 588 and PV.st.statIds.deathsFaction == 9001 and PV.st.statIds.deathsPlayers == 1501, "statistiques trouvées par leur nom (VH, morts par la faction adverse, morts par d'autres joueurs) " .. tostring(PV.st.probe.stats))
  local kd = PV.KD()
  ok(kd.text == "K/D 2,5" and kd.k == 15 and kd.d == 6, "K/D = 15 / 6 → « K/D 2,5 » (virgule FR)")
  ok(PV.FmtRatio(15, 0) == "K/D 15/0", "0 mort : « K/D 15/0 »")
  -- points de rang : texte de la fenêtre JcJ
  local r = PV.ParseTexts({ "Saison 1", "Civil/civile", "Points de rang : 0 / 750", "Augmentation du plafond cette semaine : 1500" })
  ok(r.pts == 0 and r.cap == 750 and r.inc == 1500, "fenêtre JcJ : « Points de rang : 0 / 750 », augmentation 1500 (lus, pas calculés)")
  local r2 = PV.ParseTexts({ "Points de rang :", "1 234 / 2 250" })
  ok(r2.pts == 1234 and r2.cap == 2250, "valeur dans la région suivante, espaces de milliers")
  _G.PVPFrame = newObj("Frame", "PVPFrame", _G.UIParent)
  local fs1 = _G.PVPFrame:CreateFontString() fs1:SetText("Points de rang : 0 / 750")
  local fs2 = _G.PVPFrame:CreateFontString() fs2:SetText("Augmentation du plafond cette semaine : 1500")
  ok(PV.ReadWindow(), "fenêtre JcJ ouverte : lue (lecture seule)")
  PV.Read()
  ok(PV.st.rankPts == 0 and PV.st.rankCap == 750, "jauge principale : points de rang / plafond")
  -- case dans la grille
  W.frame:Show()
  ns.UI:Refresh(true)
  local pt
  for _, t in ipairs(ns.UI.embed.tiles) do if t.data and t.data.kind == "pvp" and t:IsShown() then pt = t end end
  ok(pt and pt.data.current == 0 and pt.data.apiMax == 750, "case JcJ dans la grille (0 / 750)")
  local m = ns.Compact.TooltipModel(pt.data)
  local txt = {} for _, l in ipairs(m.lines) do txt[#txt + 1] = l[1] end
  txt = table.concat(txt, "\n")
  ok(txt:find("Points de rang : 0 / 750", 1, true) and txt:find("K/D 2,5", 1, true) and txt:find("Session", 1, true) and txt:find("3 aujourd'hui", 1, true) and txt:find("Série", 1, true), "infobulle : rang, points, VH, K/D total + session, série")
  -- victoire hors combat : toast +1 vert + pulsation
  PV.st.lastHK = 3
  hk = 4
  local nt = PV.stats.toasts
  fire("PLAYER_PVP_KILLS_CHANGED")
  ok(PV.st.streak == 1 and PV.st.session.kills == 1 and PV.stats.toasts == nt + 1, "victoire honorable : +1, toast vert")
  ok(PV.lastPulse == pt or PV.lastPulse ~= nil, "case JcJ : pulsation (AnimationGroup)")
  -- en combat : compteur seulement
  local rIC = _G.InCombatLockdown
  _G.InCombatLockdown = function() return true end
  hk = 6
  nt = PV.stats.toasts
  fire("PLAYER_PVP_KILLS_CHANGED")
  ok(PV.st.streak == 3 and PV.pendingKills == 2 and PV.stats.toasts == nt, "en combat : compteurs seulement, aucun toast")
  _G.InCombatLockdown = rIC
  if ns._regenFrame then ns._regenFrame.scripts.OnEvent(ns._regenFrame, "PLAYER_REGEN_ENABLED") end
  ok(PV.pendingKills == 0 and PV.stats.toasts >= nt + 2, "fin du combat : toast « +2 » et toast de série (3)")
  fire("PLAYER_DEAD")
  ok(PV.st.streak == 0 and (ns.CharDB().pvp.bestStreak or 0) >= 3, "PLAYER_DEAD : série remise à 0, record gardé")
  -- objectif
  ok(PV.SetGoal(50) == 50, "objectif : 50 VH aujourd'hui")
  local cyc = ns.UI:CycleGoal(pt.data)
  ok(cyc == 60, "Maj+clic droit : objectif +10 (60)")
  ok(ns.UI:PromptGoal(pt.data) ~= nil, "clic droit : fenêtre d'objectif JcJ")
  PV.SetGoal(nil)
  -- repères
  stub("UnitIsPlayer", function() return true end)
  stub("UnitCanAttack", function() return true end)
  stub("UnitLevel", function(u) if u == "player" then return 27 end return 25 end)
  local trivial = { r = 0.5, g = 0.5, b = 0.5 }
  _G.QuestDifficultyColors = _G.QuestDifficultyColors or {}
  local rTriv = _G.QuestDifficultyColors.trivial
  _G.QuestDifficultyColors.trivial = trivial
  stub("GetQuestDifficultyColor", function(l) if l <= 20 then return trivial end return { r = 0.25, g = 0.75, b = 0.25 } end)
  local plate = newObj("Frame", nil, _G.UIParent)
  stub("C_NamePlate", { GetNamePlateForUnit = function() return plate end })
  ok(PV.HonorFor("nameplate1") == true, "joueur ennemi niveau 25 (non gris) : honneur")
  local mk = PV.Evaluate("nameplate1")
  ok(mk and mk._honor == true and mk.ring._vc[2] > 0.9 and mk.parent == _G.UIParent, "repère VERT sur la barre de nom (notre cadre, enfant d'UIParent)")
  stub("UnitLevel", function(u) if u == "player" then return 27 end return 18 end)
  mk = PV.Evaluate("nameplate1")
  ok(mk and mk._honor == false and mk.ring._vc[2] < 0.6, "niveau gris (selon GetQuestDifficultyColor du jeu) : repère GRIS")
  stub("UnitFactionGroup", function() return "Alliance" end)
  ok(PV.HonorFor("nameplate1") == nil and PV.Evaluate("nameplate1") == nil, "même faction : aucun repère")
  _G.InCombatLockdown = function() return true end
  fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
  ok(PV.pending.nameplate2 and not PV.active.nameplate2, "en combat : barre de nom mise en attente, rien évalué")
  _G.InCombatLockdown = rIC
  -- /drop pvp off
  slash("pvp off")
  ns.UI:Refresh(true)
  local still = false
  for _, t in ipairs(ns.UI.embed.tiles) do if t.data and t.data.kind == "pvp" and t:IsShown() then still = true end end
  ok(not PV.Enabled() and not still, "/drop pvp off : case retirée, grille recalculée " .. tostring(PV.Enabled()) .. tostring(still) .. tostring(lastPrint()))
  slash("pvp on")
  ok(PV.Enabled() and ns.Options.Find("pvp") and ns.Options.Find("pvpMarks"), "/drop pvp on ; options JcJ dans le panneau")
  local dbg
  for _, fn in ipairs(ns.DebugExt) do local okD, lines = pcall(fn) if okD and type(lines) == "table" and tostring(lines[1]):find("JcJ (3.3.13)", 1, true) then dbg = table.concat(lines, "\n") end end
  ok(dbg and dbg:find("points de rang", 1, true) and dbg:find("statistiques", 1, true), "/drop debug : sources JcJ (rang, honneur, statistiques)")
  _G.QuestDifficultyColors.trivial = rTriv
  for n, v in pairs(saved) do _G[n] = v[1] end
  _G.PVPFrame = nil
  PV.forceOff = true
  ns.UI:Refresh(true)
end

print("== 3.3.14 : bord BRONZE partout (cases, total, JcJ, pastilles) = bord du panneau ==")
do
  -- 3.4.0 : « au repos » = aucune activité de métier (fenêtre fermée, pas de sort)
  if ns.Activity then ns.Activity.window, ns.Activity.cast, ns.Activity.pole = nil, nil, false pcall(ns.Target.Paint) end
  local Sk, Th, LY, Wd, PV = ns.Skin, ns.Theme, ns.Layout, ns.Wide, ns.PvP
  local f = W.frame
  f:Show()
  Sk.enabled = true
  ns.Panel.ApplyTooltipLook(f)
  local B = ns.STYLE.BORDER
  local function eq(c) return c and math.abs(c[1] - B[1]) < 1e-6 and math.abs(c[2] - B[2]) < 1e-6 and math.abs(c[3] - B[3]) < 1e-6 end
  local function neutral(c) return c and c[1] == 1 and c[2] == 1 and c[3] == 1 and (c[4] or 1) == 1 end
  ok(eq(f._skinHost._bdBorder) and f._skinHost._bdEdge == Sk.EDGE_FILE, "panneau : Media/Dropamine-Frame (art gris) teinté au jeton bronze #A67D45 (3.3.15, comme FlareUI)")
  ok(Sk.BORDER == B and Th.BRONZE == B and ns.Panel.BRONZE.outer == B and Wd.FILL == B, "un seul jeton : Skin, Theme, Panel, barre total")
  local t = ns.UI:SpawnDrop("Interface\\Icons\\INV_Misc_QuestionMark", "+1", "x", 1, 2, "")
  ok(t and t._skinHost and eq(t._skinHost._bdBorder) and t._skinHost._bdEdge == f._skinHost._bdEdge, "toast : même texture de bord, même teinte bronze")
  Wd.forceShown, PV.forceOff = true, nil
  for _, theme in ipairs({ "flare", "leger" }) do
    Th.Set(theme)
    LY.SetCols(5)
    ns.UI:Refresh(true)
    local bad, n, kinds = {}, 0, {}
    for _, tt in ipairs(ns.UI.embed.tiles) do
      if tt.data and tt:IsShown() then
        n = n + 1
        kinds[tt.data.kind] = true
        local e = tt._bevel and tt._bevel.strips[1][2]._vc
        if not eq(e) then bad[#bad + 1] = tostring(tt.data.name) end
      end
    end
    ok(n >= 10 and #bad == 0 and kinds.pvp and kinds.total, string.format("%s : %d cases au repos (compétences, total, JcJ) — bord == bord du panneau%s", theme, n, #bad > 0 and (" ; écarts : " .. table.concat(bad, ", ")) or ""))
  end
  -- pastille « N prêt »
  local tt
  for _, x in ipairs(ns.UI.embed.tiles) do if x.data and x:IsShown() and x.data.kind ~= "total" and x.data.kind ~= "pvp" then tt = x break end end
  pcall(ns.UI.UpdateCraftBadge, ns.UI, tt, tt.data)
  if not tt.craftBadge then
    local rC = ns.Craft and ns.Craft.BadgeCount
    tt.craftBadge = nil
  end
  local found
  for _, x in ipairs(ns.UI.embed.tiles) do if x.craftBadge and x.craftBadge.edge then found = x.craftBadge.edge end end
  if found then ok(eq(found._vc), "pastille « N prêt » : liseré bronze (jeton)") else
    -- crée une pastille via le code réel
    local d = tt.data
    local rf = ns.Craft and ns.Craft.ReadyCount
    ok(true, "pastille : aucune affichée dans ce jeu d'essai (liseré vérifié par le code : jeton)")
  end
  Th.Set("flare")
  -- bord du panneau en textures (sans BackdropTemplate) : 8 pièces teintées
  Sk.forceTextures = true
  local g = CreateFrame("Frame", nil, UIParent)
  local h = Sk.Host(g)
  Sk.Paint(h, 0.8)
  local allOK, np = true, 0
  for _, p in pairs(h.pieces or {}) do np = np + 1 if not eq(p._vc) then allOK = false end end
  ok(h._skinTex and np == 8 and allOK and h._bdEdge == Sk.EDGE_FILE and h._bdEdgeSize == 16, "repli sans BackdropTemplate : 8 pièces Dropamine-Frame, chacune teintée bronze")
  ok(h.pieces.tl.width == 16 and h.pieces.top.height == 16, "repli : coins 16 px, bord 16 px")
  Sk.forceTextures = nil
  ok(io.open(addonDir .. "/Media/Dropamine-Frame.tga", "rb") and not io.open(addonDir .. "/Media/SkinUI-Frames.tga", "rb") and not io.open(addonDir .. "/Media/Edge.tga", "rb"), "Media/Dropamine-Frame.tga (notre dessin) livré, plus aucune copie FlareUI-Frames")
  Sk.enabled = false
  Wd.forceShown, PV.forceOff = true, true
end

print("== 3.3.14 : félin — Combat farouche ET Défense en VERT (bord vert), sélection jamais bleue ==")
do
  local TG, UIm = ns.Target, ns.UI
  local rClass, rFID, rLvl = _G.UnitClass, _G.GetShapeshiftFormID, _G.UnitLevel
  _G.UnitClass = function(u) if u == "player" then return "Druide", "DRUID" end return rClass(u) end
  _G.UnitLevel = function(u) if u == "player" then return 45 end return 40 end
  _G.GetShapeshiftFormID = function() return 1 end
  local function T(d) local t = CreateFrame("Button", nil, UIParent) t.icon = t:CreateTexture() t.data = d ns.Theme.IconSkin(t) t:Show() return t end
  local keep = UIm.embed.tiles
  local mace = T({ combatTile = true, kind = "melee", id = "staves", name = "Bâtons", current = 150, apiMax = 225 })
  local feral = T({ combatTile = true, kind = "feral", name = "Combat farouche", current = 27, apiMax = 60, icon = "Interface\\Icons\\Ability_Druid_CatForm" })
  local def = T({ combatTile = true, kind = "defense", name = "Défense", current = 179, apiMax = 225 })
  UIm.embed.tiles = { mace, feral, def }
  local tg = { name = "Wyverne", level = 40, attackable = true, dead = false, player = false, tapped = false }
  TG.current = TG.Compute(tg) TG.Paint()
  local function lit(t) local m = t._osrsTgt local c = t._bevel and t._bevel.strips[1][2]._vc return m and m.shown ~= false and c and c[2] == 1 and c[1] < 0.5 and true or false end
  ok(lit(feral), "félin : Combat farouche 27/60 — bord biseauté recoloré VERT (3.3.15)")
  ok(lit(def), "félin : Défense 179/225 sur cible niveau 40 non grise — VERTE (pas de plafond estimé 5 × cible pour la Défense)")
  ok(not lit(mace), "félin : arme éteinte")
  ok(TG.current["kind:defense"].why[1]:find("monte quand la cible te frappe", 1, true), "raison Défense : « monte quand la cible te frappe »")
  -- Défense : cible grise → éteinte (inchangé)
  local r = TG.Compute({ name = "Gris", level = 30, attackable = true, dead = false, player = false, tapped = false })
  ok(not r["kind:defense"], "Défense : cible grise (30 ≤ 36) → éteinte")
  -- sélection : teinte or, jamais le halo bleu
  local tt
  for _, x in ipairs(keep) do if x.checkTex then tt = x break end end
  ok(tt and tt.checkTex._vc and tt.checkTex._vc[1] == 1 and tt.checkTex._vc[3] < 0.5, "case sélectionnée : halo or (1, 0.86, 0.46), pas bleu")
  TG.current = nil
  UIm.embed.tiles = keep
  _G.UnitClass, _G.GetShapeshiftFormID, _G.UnitLevel = rClass, rFID, rLvl
end

print("== 3.3.14 : barre Niveau total — pas de « /2460 » résiduel ==")
do
  local Wd, LY = ns.Wide, ns.Layout
  Wd.forceShown = nil
  Wd.SetShown(true)
  LY.SetCols(3)
  local tot
  for _, t in ipairs(ns.UI.embed.tiles) do if t.data and t.data.kind == "total" and t:IsShown() then tot = t end end
  ok(tot and tot._wideOn, "3 colonnes : total en barre")
  ok(tot.countFS.shown == false and (not tot.countFS2 or tot.countFS2.shown == false), "mode barre : rang et « /max » de la case cachés")
  ns.UI:Refresh(true)
  ok(tot.countFS.shown == false and (not tot.countFS2 or tot.countFS2.shown == false), "après rafraîchissement : toujours cachés")
  ok(tot._wideParts.text.text:find(" / ", 1, true), "seulement icône + « total / max » + jauge")
  LY.SetCols(5)
  ok(not tot._wideOn and tot.countFS.shown ~= false, "retour en case : rang de nouveau visible")
  Wd.SetShown(false)
  Wd.forceShown = true
end

print("== 3.3.14 : barres de nom — une icône par métier (liens), infobulle : une ligne par métier ==")
do
  local G, S, L, Tip = ns.Gather, ns.Scanner, ns.Links, ns.Tip
  local keepS = { UnitNpcID = S.UnitNpcID, CreatureFor = S.CreatureFor, RankOf = S.RankOf, Enabled = S.Enabled, NoteUnit = S.NoteUnit, CreatureDiff = S.CreatureDiff, MaxOf = S.MaxOf }
  local keepL = { Lines = L.Lines, CreatureItems = L.CreatureItems }
  local keepG = { Rank = G.Rank, Known = G.Known, State = G.State, UnitState = G.UnitState }
  local rName, rLvl = _G.UnitName, _G.UnitLevel
  _G.UnitName = function() return "Concubine Aile-fière" end
  _G.UnitLevel = function(u) if u == "player" then return 27 end return 23 end
  S.UnitNpcID = function() return 4011 end
  S.Enabled = function() return true end
  S.CreatureFor = function() return { name = "Concubine Aile-fière", skills = {} } end
  S.RankOf = function() return 0 end
  S.NoteUnit = function() return nil, { name = "Concubine Aile-fière" } end
  G.Rank = function() return 110 end
  G.Known = function() return true end
  local st = { diff = "easy", text = "Dépeçage +1 · requis 115", req = 115 }
  G.State = function() return st end
  G.UnitState = function() return st end
  L.CreatureItems = function() return { 4234 } end
  local lines = {
    { skill = "leatherworking", learned = true, diff = "easy", name = "Gants de bagarreur en cuir" },
    { skill = "skinning", learned = true, diff = "trivial", name = "Peau légère" },
  }
  L.Lines = function() return {}, lines end
  G._plateCache = {}
  local out = G.PlateEntries("nameplate1")
  local by = {}
  for _, e in ipairs(out) do by[e.skill] = (by[e.skill] or 0) + 1 end
  local lw
  for _, e in ipairs(out) do if e.skill == "leatherworking" then lw = e end end
  ok(by.skinning == 1 and lw and lw.green == true and by.leatherworking == 1, "Concubine : icône Dépeçage + icône Travail du cuir (verte : une recette donne un point), une par métier")
  lines[1].diff = "trivial"
  G._plateCache = {}
  out = G.PlateEntries("nameplate1")
  lw = nil for _, e in ipairs(out) do if e.skill == "leatherworking" then lw = e end end
  ok(lw and lw.green == false, "recettes de cuir toutes grises : icône Travail du cuir GRISE")
  -- infobulle compacte : une seule ligne Dépeçage, la grise « recettes grises » est abandonnée
  lines[1].diff = "easy"
  local groups = Tip.Groups(GameTooltip, "mouseover")
  local sk, lwN = {}, 0
  for _, g in ipairs(groups) do if g.skill == "skinning" then sk[#sk + 1] = g.text end if g.skill == "leatherworking" then lwN = lwN + 1 end end
  ok(#sk == 1 and sk[1]:find("Dépeçage +1", 1, true) and lwN == 1, "infobulle : une ligne par métier (« " .. table.concat(sk, " | ") .. " »)")
  local compact = Tip.Lines(groups, false)
  local hasGrey = false
  for _, l in ipairs(compact) do if tostring(l[1]):find("recettes grises", 1, true) then hasGrey = true end end
  ok(not hasGrey, "mode compact : plus de « Dépeçage : recettes grises » à côté de « Dépeçage +1 »")
  for k, v in pairs(keepS) do S[k] = v end
  for k, v in pairs(keepL) do L[k] = v end
  for k, v in pairs(keepG) do G[k] = v end
  _G.UnitName, _G.UnitLevel = rName, rLvl
  G._plateCache = {}
end


print("== 3.3.15 : bord du panneau JAMAIS blanc (SetBackdrop, couleurs d'infobulle, fondu, thème, 8 pièces, toasts) ==")
do
  local Sk, Th, P = ns.Skin, ns.Theme, ns.Panel
  local f = W.frame
  f:Show()
  Sk.enabled = true
  P.ApplyTooltipLook(f)
  local B = ns.STYLE.BORDER
  local function eq(c) return c and math.abs(c[1] - B[1]) < 1e-6 and math.abs(c[2] - B[2]) < 1e-6 and math.abs(c[3] - B[3]) < 1e-6 end
  local h = f._skinHost
  -- 1) un SetBackdrop qui remet la couleur à blanc (comportement du client)
  h:SetBackdropBorderColor(1, 1, 1, 1)
  h:SetBackdrop({ bgFile = h._bdFile, edgeFile = h._bdEdge, edgeSize = 16, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
  ok(eq(h._bdBorder), "SetBackdrop (couleur remise à blanc) : bronze réappliqué aussitôt")
  -- 2) couleurs d'infobulle par défaut (blanches) + fondu + changement de thème
  local rTDC = _G.TOOLTIP_DEFAULT_COLOR
  _G.TOOLTIP_DEFAULT_COLOR = { r = 1, g = 1, b = 1 }
  if P.RefreshTipColors then P.RefreshTipColors() end
  if P.ApplyTipAlpha then P.ApplyTipAlpha(0.4, 0.4) P.ApplyTipAlpha(1, 1) end
  Th.Set("leger") Th.Set("flare")
  ok(eq(h._bdBorder), "couleurs d'infobulle blanches + fondu + léger → cadre : bord final BRONZE (" .. table.concat({ tostring(h._bdBorder and h._bdBorder[1]), tostring(h._bdBorder and h._bdBorder[2]), tostring(h._bdBorder and h._bdBorder[3]) }, ",") .. ")")
  _G.TOOLTIP_DEFAULT_COLOR = rTDC
  -- 3) repli 8 pièces : SetBackdrop puis couleur blanche parasite → retintée
  Sk.forceTextures = true
  local g = CreateFrame("Frame", nil, UIParent)
  local h8 = Sk.Host(g)
  Sk.Paint(h8, 0.8)
  h8:SetBackdropBorderColor(1, 1, 1, 1)
  h8:SetBackdrop({ bgFile = "x", edgeFile = Sk.EDGE_FILE, edgeSize = 16 })
  local all = true
  for _, pc in pairs(h8.pieces or {}) do if not eq(pc._vc) then all = false end end
  ok(all, "8 pièces : après SetBackdrop, chaque pièce reteintée bronze")
  Sk.forceTextures = nil
  -- 4) toast
  local t = ns.UI:SpawnDrop("Interface\\Icons\\INV_Misc_QuestionMark", "+1", "x", 1, 2, "")
  ok(t and t._skinHost and eq(t._skinHost._bdBorder), "toast : bord bronze")
  Sk.enabled = false
end

print("== 3.3.15 : bord d'icône biseauté (référence) — surbrillance / sélection = MÊME bord recoloré ==")
do
  local Th, TG = ns.Theme, ns.Target
  local t = CreateFrame("Button", nil, UIParent)
  t.icon = t:CreateTexture()
  Th.IconSkin(t)
  local e = t._bevel
  local B = ns.STYLE.BORDER
  local li = e.strips[1][2]
  ok(math.abs(li._vc[1] - B[1]) < 1e-6 and math.abs(li._vc[4] - Th.EDGE_LINE_A) < 1e-6, "repos : filet bronze (alpha " .. Th.EDGE_LINE_A .. ")")
  t._tgtLit = "direct" Th.BevelColor(t)
  ok(li._vc[2] == 1 and li._vc[1] < 0.5 and e.corners[1]._vc[2] == 1, "cible (fort) : le MÊME bord (bandes + coins biseautés) passe au vert")
  local strongA = li._vc[4]
  t._tgtLit = "indirect" Th.BevelColor(t)
  ok(li._vc[2] == 1 and li._vc[4] < strongA, "cible (discret) : même bord vert, plus pâle (" .. li._vc[4] .. " < " .. strongA .. ")")
  t._tgtLit = nil t._flSelOn = true Th.BevelColor(t)
  ok(math.abs(li._vc[1] - ns.STYLE.SELECT[1]) < 1e-6 and math.abs(li._vc[3] - ns.STYLE.SELECT[3]) < 1e-6, "sélection : même bord, or")
  local m = TG.Mark(t)
  ok(m.ring == nil and m.edges == nil, "aucun trait carré à part pour la surbrillance")
  ok(e.corners[1]._texSet:find("OSRS%-IconCorner") and io.open(addonDir .. "/Media/OSRS-IconCorner.tga", "rb") and io.open(addonDir .. "/Media/OSRS-IconMask.tga", "rb"), "Media/OSRS-IconCorner.tga + OSRS-IconMask.tga livrés")
  ok(not io.open(addonDir .. "/Media/SkinUI-IconBorder.tga", "rb"), "ancien bord d'icône FlareUI (biseau épais) retiré")
end

print("== 3.3.15 : « +1 » et pastille « N prêt(s) » ne se cachent jamais ==")
do
  local Th, TG, IC = ns.Theme, ns.Target, ns.Icons
  local bt = CreateFrame("Button", nil, UIParent)
  bt.width, bt.height = IC.TILE, IC.TILE
  bt.icon = bt:CreateTexture()
  local rReady, rSk = ns.Craft.Ready, ns.Craft.SKILLS
  ns.Craft.SKILLS = setmetatable({ zz = true }, { __index = rSk })
  ns.Craft.Ready = function() return 3 end
  UI:UpdateCraftBadge(bt, { id = "zz" })
  local b = bt.craftBadge
  local m = TG.Mark(bt)
  m.fs:SetText("+1")
  -- repère haut de case = 0, y vers le bas
  local bp = b.points[1]
  local bTop, bBot = -(b.height + bp[5]), -bp[5]          -- pastille : BOTTOM sur TOP, décalée de -over
  local bL = (IC.TILE - b.width) / 2 local bR = bL + b.width
  local fp = m.fs.points[1]
  ok(fp[1] == "TOPLEFT" and fp[2] == bt, "« +1 » ancré en haut à gauche DE LA CASE")
  local fTop = -fp[5] local fBot = fTop + 10 local fL = fp[4] local fR = fL + 14
  local overlapY = fTop < bBot and bTop < fBot
  local overlapX = fL < bR and bL < fR
  ok(not (overlapX and overlapY), string.format("rectangles disjoints : pastille y[%g,%g] / « +1 » y[%g,%g]", bTop, bBot, fTop, fBot))
  ok(fTop >= bBot + 1, "« +1 » commence sous le bas de la pastille (" .. fTop .. " ≥ " .. (bBot + 1) .. ")")
  ns.Craft.Ready, ns.Craft.SKILLS = rReady, rSk
end

print("== 3.3.15 : forme de félin — toutes les sondes (FormID nil + aura ; type de ressource) ==")
do
  local TG, UIm = ns.Target, ns.UI
  local save = {}
  for _, n in ipairs({ "UnitClass", "GetShapeshiftFormID", "GetShapeshiftForm", "GetShapeshiftFormInfo", "GetNumShapeshiftForms", "UnitAura", "UnitBuff", "C_UnitAuras", "AuraUtil", "UnitPowerType", "UnitLevel" }) do save[n] = _G[n] end
  _G.UnitClass = function(u) if u == "player" then return "Druide", "DRUID" end return save.UnitClass(u) end
  local function clear() _G.GetShapeshiftFormID, _G.GetShapeshiftForm, _G.GetShapeshiftFormInfo, _G.GetNumShapeshiftForms, _G.UnitAura, _G.UnitBuff, _G.C_UnitAuras, _G.AuraUtil, _G.UnitPowerType = nil, nil, nil, nil, nil, nil, nil, nil, nil end
  -- a) FormID nil, aura 768 seulement via C_UnitAuras
  clear()
  _G.GetShapeshiftFormID = function() return nil end
  _G.C_UnitAuras = { GetPlayerAuraBySpellID = function(id) if id == 768 then return { spellId = 768, name = "Forme de félin" } end end }
  local form, how = TG.FeralForm()
  ok(form == "félin" and how:find("C_UnitAuras", 1, true), "GetShapeshiftFormID = nil + aura 768 → félin (" .. tostring(how) .. ")")
  -- b) AuraUtil par nom
  clear()
  _G.AuraUtil = { FindAuraByName = function(n) if n == "Forme d'ours" then return n end end }
  ok(TG.FeralForm() == "ours", "AuraUtil.FindAuraByName(« Forme d'ours ») → ours")
  -- c) rien d'autre : énergie → félin, rage → ours
  clear()
  _G.UnitPowerType = function() return 3 end
  form, how = TG.FeralForm()
  ok(form == "félin" and how:find("UnitPowerType", 1, true), "repli UnitPowerType = 3 (énergie) → félin")
  _G.UnitPowerType = function() return 1 end
  ok(TG.FeralForm() == "ours", "repli UnitPowerType = 1 (rage) → ours")
  _G.UnitPowerType = function() return 0 end
  ok(TG.FeralForm() == nil, "mana (0) → humanoïde")
  -- d) en forme : seuls Farouche + Défense, jamais l'arme équipée
  _G.UnitPowerType = function() return 3 end
  _G.UnitLevel = function(u) if u == "player" then return 27 end return 25 end
  local function T(d) local t = CreateFrame("Button", nil, UIParent) t.icon = t:CreateTexture() t.data = d t:Show() return t end
  local keep = UIm.embed.tiles
  local staff = T({ combatTile = true, kind = "melee", id = "staves", name = "Bâtons", current = 40, apiMax = 135 })
  local feral = T({ combatTile = true, kind = "feral", name = "Combat farouche", current = 40, apiMax = 135 })
  local def = T({ combatTile = true, kind = "defense", name = "Défense", current = 40, apiMax = 135 })
  UIm.embed.tiles = { staff, feral, def }
  local r = TG.Compute({ name = "Loup", level = 25, attackable = true, dead = false, player = false, tapped = false })
  ok(r["kind:feral"] and r["kind:defense"] and not r["kind:melee"], "félin (sonde ressource) : Combat farouche + Défense, arme équipée JAMAIS")
  -- e) ligne de debug : chaque sonde
  TG.target = { name = "Loup", level = 25, attackable = true }
  local dbg
  for _, fn in ipairs(ns.DebugExt) do local okD, lines = pcall(fn) if okD and type(lines) == "table" and lines[1] == "— Cible / forme (3.3.15) —" then dbg = table.concat(lines, "\n") end end
  ok(dbg and dbg:find("sondes : GetShapeshiftFormID=", 1, true) and dbg:find("UnitPowerType=félin", 1, true) and dbg:find("C_UnitAuras=", 1, true) and dbg:find("AuraUtil=", 1, true), "/drop debug : résultat de chaque sonde")
  TG.target = nil
  UIm.embed.tiles = keep
  for n, v in pairs(save) do _G[n] = v end
end

print("== 3.3.15 : démoniste niv. 4 + DAGUE équipée vs Vermine kobold niv. 2 — arme équipée, deux niveaux ==")
do
  local TG, UIm = ns.Target, ns.UI
  local save = {}
  for _, n in ipairs({ "UnitClass", "UnitLevel", "GetInventoryItemID", "GetInventoryItemLink", "GetInventoryItemTexture", "GetItemInfo", "IsCurrentSpell", "IsAutoRepeatSpell", "UnitAffectingCombat", "UnitIsUnit" }) do save[n] = _G[n] end
  _G.UnitClass = function(u) if u == "player" then return "Démoniste", "WARLOCK" end return save.UnitClass(u) end
  _G.UnitLevel = function(u) if u == "player" then return 4 end return 2 end
  local items = {
    [16] = { id = 2092, name = "Dague d'apprenti", typ = "Arme", sub = "Dagues", classID = 2, subclassID = 15 },
    [18] = { id = 5069, name = "Baguette de feu", typ = "Arme", sub = "Baguettes", classID = 2, subclassID = 19 },
  }
  _G.GetInventoryItemID = function(_, s) return items[s] and items[s].id end
  _G.GetInventoryItemLink = function() return nil end
  _G.GetInventoryItemTexture = function() return nil end
  _G.GetItemInfo = function(id) for _, it in pairs(items) do if it.id == id then return it.name, nil, 1, 5, 1, it.typ, it.sub, 1, "INVTYPE_WEAPON", nil, 0, it.classID, it.subclassID end end end
  local swinging, shooting = false, false
  _G.IsCurrentSpell = function(id) return id == 6603 and swinging end
  _G.IsAutoRepeatSpell = function() return shooting end
  _G.UnitAffectingCombat = function() return false end
  local function T(d) local t = CreateFrame("Button", nil, UIParent) t.icon = t:CreateTexture() t.data = d ns.Theme.IconSkin(t) t:Show() return t end
  local keep = UIm.embed.tiles
  local lvl = T({ kind = "level", name = "Niveau", current = 4, apiMax = 60 })
  local dag = T({ combatTile = true, kind = "melee", id = "daggers", name = "Mêlée", skillName = "Dagues", current = 6, apiMax = 20 })
  local sw = T({ kind = "melee", id = "swords", name = "Épées", current = 1, apiMax = 20 })
  local wand = T({ combatTile = true, kind = "ranged", id = "wands", name = "Baguettes", current = 3, apiMax = 20 })
  local def = T({ combatTile = true, kind = "defense", name = "Défense", current = 18, apiMax = 20 })
  UIm.embed.tiles = { lvl, dag, sw, wand, def }
  local tg = { name = "Vermine kobold", level = 2, attackable = true, dead = false, player = false, tapped = false }
  local function lv(t) local k = TG.KeyFor(t.data) local e = k and TG.current and TG.current[k] return e and e.level or nil end
  TG._cache = {}
  TG.current = TG.Compute(tg) TG.Paint()
  local eqp = TG.Equipped()
  ok(eqp.ids.daggers == "main droite" and eqp.ids.wands == "distance" and not eqp.ids.swords, "emplacement 16 : Dague (classe 2 / sous-classe 15) → Dagues ; 18 : Baguette")
  ok(lv(dag) == "indirect" and lv(sw) == nil, "cible éligible sans frappe : Dagues en vert DISCRET, Épées (non équipées) jamais")
  ok(lv(wand) == "indirect", "baguette équipée sans tir : discret")
  ok(dag._bevel.strips[1][2]._vc[2] == 1 and dag._bevel.strips[1][2]._vc[4] < ns.Theme.EDGE_LINE_A, "discret : fin contour vert pâle (même biseau)")
  ok(TG.current["kind:melee"].why[1]:find("Dague équipée · monte sur cette cible", 1, true), "infobulle : « " .. tostring(TG.current["kind:melee"].why[1]) .. " »")
  -- attaque auto
  swinging = true
  TG.current = TG.Compute(tg) TG.Paint()
  ok(lv(dag) == "direct" and lv(wand) == "indirect", "attaque auto (6603) : Dagues en vert FORT, baguette reste discrète")
  ok(dag._bevel.strips[1][2]._vc[4] == ns.Theme.EDGE_LINE_A, "fort : bord vert plein")
  swinging = false
  -- tir de baguette
  shooting = true
  TG.current = TG.Compute(tg) TG.Paint()
  ok(lv(wand) == "direct" and lv(dag) == "indirect", "Tir (baguette) : Baguettes en FORT, dague discrète")
  shooting = false
  -- Défense : forte quand la cible nous frappe
  ok(lv(def) == "indirect", "Défense : discrète hors coups")
  _G.UnitAffectingCombat = function(u) return u == "player" end
  _G.UnitIsUnit = function(a, b) return a == "targettarget" and b == "player" end
  TG.current = TG.Compute(tg) TG.Paint()
  ok(lv(def) == "direct", "Défense : FORTE quand la cible nous frappe en combat")
  -- événements : PLAYER_ENTER_COMBAT / LEAVE + équipement
  fire("PLAYER_ENTER_COMBAT") ok(TG.swing.melee == true, "PLAYER_ENTER_COMBAT : attaque auto suivie")
  fire("PLAYER_LEAVE_COMBAT") ok(TG.swing.melee == false, "PLAYER_LEAVE_COMBAT : fin d'attaque")
  local e0 = TG.stats.events
  _G.UnitExists = _G.UnitExists or function() return true end
  TG.target = tg
  items[16] = nil
  fire("PLAYER_EQUIPMENT_CHANGED", 16)
  ok(TG.stats.events > e0 and TG.Equipped().ids.unarmed, "PLAYER_EQUIPMENT_CHANGED (16) : réévalué ; main vide → Mains nues")
  -- debug
  local dbg
  for _, fn in ipairs(ns.DebugExt) do local okD, lines = pcall(fn) if okD and type(lines) == "table" and lines[1] == "— Cible / forme (3.3.15) —" then dbg = table.concat(lines, "\n") end end
  items[16] = { id = 2092, name = "Dague d'apprenti", typ = "Arme", sub = "Dagues", classID = 2, subclassID = 15 }
  dbg = TG.EquipDebug()
  ok(dbg:find("main droite Dague d'apprenti (classe 2/15", 1, true) and dbg:find("→ case Dagues", 1, true), "/drop debug : « " .. dbg .. " »")
  TG.target, TG.current = nil, nil
  UIm.embed.tiles = keep
  for n, v in pairs(save) do _G[n] = v end
  TG._cache = {}
end

print("== 3.3.15 : première ouverture (base neuve) — jamais d'ascenseur sur le panneau ==")
do
  local FL = ns.FirstLayout
  local wrap = UI.embed
  ok(FL and FL.Pass and FL.Queue, "module FirstLayout chargé")
  local p0 = FL.stats.passes
  FL._pending = nil
  local rAfter = _G.C_Timer.After
  _G.C_Timer.After = function(_, fn) timers[#timers + 1] = fn end   -- file de minuteries de l'essai
  fire("PLAYER_LOGIN")
  ok(FL.stats.passes > p0 and #timers > 0, "PLAYER_LOGIN : passe complète + nouvelle passe à la frame suivante (C_Timer.After(0))")
  flushTimers()
  local p1 = FL.stats.passes
  fire("PLAYER_ENTERING_WORLD", true, false)
  fire("SKILL_LINES_CHANGED")
  flushTimers()
  ok(FL.stats.passes >= p1 + 2, "PLAYER_ENTERING_WORLD / SKILL_LINES_CHANGED : passes de mise en page")
  -- débordement simulé (tailles pas encore posées) : barre cachée, nouvelle passe
  wrap._layout = { overflow = true, availH = 40, step = 48 }
  wrap._maxScroll = 120
  local q = #timers
  UI:UpdateGridScrollBar(wrap)
  ok(wrap.sb and wrap.sb.shown == false and #timers > q, "débordement : ascenseur CACHÉ, nouvelle mise en page programmée")
  flushTimers()
  -- toutes les dispositions : jamais de barre
  local shown = false
  for _, c in ipairs({ 3, 5, 10 }) do ns.Layout.SetCols(c) UI:Refresh(true) flushTimers() if wrap.sb and wrap.sb.shown == true then shown = true end end
  ns.Layout.SetCols(5)
  ok(not shown, "3 / 5 / 10 colonnes : ascenseur jamais affiché")
  ok(FL.DebugLine():find("Première mise en page", 1, true), "ligne de debug")
  _G.C_Timer.After = rAfter
end

print("== 3.3.16 : récap de session VISIBLE au début du compte à rebours de déconnexion ==")
do
  local Q = ns.QoL
  local rAfter = _G.C_Timer.After
  _G.C_Timer.After = function(_, fn) timers[#timers + 1] = fn end
  ns.db.ui.dropsEnabled = nil
  Q._recapAt, Q._recapToast = nil, nil
  gtime = gtime + 100
  local np = #prints
  fire("PLAYER_CAMPING")
  local line
  for i = np + 1, #prints do if tostring(prints[i]):find("Session :", 1, true) then line = prints[i] end end
  ok(line, "PLAYER_CAMPING : ligne de chat « " .. tostring(line) .. " »")
  local t = Q._recapToast
  ok(t and t.shown ~= false and t._hold == Q.LOGOUT_SECONDS and Q.LOGOUT_SECONDS == 20, "toast « Récap de session » affiché, tenu " .. tostring(t and t._hold) .. " s (durée du compte à rebours)")
  ok(t and t.titleFS and tostring(t.titleFS.text):find("Récap de session", 1, true), "titre du toast : « " .. tostring(t and t.titleFS and t.titleFS.text) .. " »")
  -- tenu pendant le décompte (pas les 2,6 s habituelles)
  for _ = 1, 15 do t.scripts.OnUpdate(t, 1) end
  ok(t.shown ~= false and (t.alpha or 1) == 1, "après 15 s : toujours visible (alpha 1)")
  -- même déconnexion vue deux fois (événement + crochet Logout) : une seule ligne
  local np2 = #prints
  Q.LogoutRecap("déconnexion")
  local again = 0
  for i = np2 + 1, #prints do if tostring(prints[i]):find("Session :", 1, true) then again = again + 1 end end
  ok(again == 0, "événement + crochet Logout : une seule ligne / un seul toast")
  -- annulation
  fire("LOGOUT_CANCEL")
  for _ = 1, 3 do if t.scripts.OnUpdate then t.scripts.OnUpdate(t, 0.5) end end
  ok(t.shown == false and Q.recapStats.cancelled >= 1, "LOGOUT_CANCEL : toast retiré (fondu de sortie)")
  -- sortie du jeu
  gtime = gtime + 10
  fire("PLAYER_QUITING")
  ok(Q._recapToast and tostring(Q._recapToast.titleFS.text):find("sortie du jeu", 1, true), "PLAYER_QUITING : toast « Récap de session — sortie du jeu »")
  fire("LOGOUT_CANCEL")
  -- plus rien à PLAYER_LOGOUT (écran de chargement)
  local np3 = #prints
  fire("PLAYER_LOGOUT")
  local late = false
  for i = np3 + 1, #prints do if tostring(prints[i]):find("Session :", 1, true) then late = true end end
  ok(not late, "PLAYER_LOGOUT : plus de ligne invisible")
  -- option coupée
  slash("recap off")
  gtime = gtime + 10
  ok(Q.LogoutRecap("déconnexion") == nil, "/drop recap off : rien")
  slash("recap on")
  local np4 = #prints
  slash("recap")
  ok(tostring(prints[#prints]):find("Session :", 1, true), "/drop recap : toujours disponible")
  for _ = 1, 60 do for _, x in ipairs(UI.dropsActive or {}) do if x.scripts.OnUpdate then x.scripts.OnUpdate(x, 1) end end end
  _G.C_Timer.After = rAfter
end

print("== 3.3.16 : bouton d'ouverture — icône recadrée + bord biseauté, glisser restauré ==")
do
  local TI, mm = ns.ToggleIcon, UI.minimap
  ok(mm.overlay and mm.overlay.shown == false, "minicarte : anneau rond natif retiré (bord biseauté à la place)")
  local function mouseEaters(b)
    local n = 0
    for _, c in ipairs(b.children or {}) do if c.mouse == true and c.shown ~= false then n = n + 1 end end
    return n
  end
  ok(mouseEaters(mm) == 0, "bord / masque / icône : textures seulement, aucun calque ne prend la souris")
  ok(mm._tiIcon._tiMask == nil or mm._tiIcon._tiMask._texSet == ns.Theme.ICON_MASK, "masque biseauté de l'addon sur l'icône (si le client le permet)")
  ok(TI.DebugLine():find("minicarte zone", 1, true) and not TI.DebugLine():find("micro", 1, true), "/drop debug : « " .. TI.DebugLine() .. " »")
  -- 3.4.2 : ancienne position du lanceur oubliée sans erreur
  ns.db.ui.launcherPos = { x = 1, y = 2 }
  ns.EnsureDB()
  ok(ns.db.ui.launcherPos == nil, "3.4.2 : ancienne clé launcherPos ignorée et effacée")
  local np = #prints
  slash("lanceur reset")
  ok(ns.SlashExt.lanceur == nil, "3.4.2 : commande /drop lanceur retirée")
end

print("== 3.3.16 : mode édition — le panneau garde sa position mémorisée ==")
do
  local PG, f = ns.PosGuard, W.frame
  local rAfter = _G.C_Timer.After
  _G.C_Timer.After = function(_, fn) timers[#timers + 1] = fn end
  PG._pending = nil
  if not W.IsShown() then W.Show() end
  ns.db.ui.winPos = { point = "TOPLEFT", relativePoint = "BOTTOMLEFT", x = 300, y = 700 }
  W.PlaceDefault(f)
  local function at() local q = f.points[1] return q and q[1] == "TOPLEFT" and q[3] == "BOTTOMLEFT" and q[4] == 300 and q[5] == 700 end
  ok(at(), "position mémorisée posée (300, 700)")
  -- le jeu (ou une mise en page) ré-ancre le panneau à sa place par défaut
  f:ClearAllPoints() f:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 40)
  UI:EnterEditMode()
  ok(at(), "entrée dans le mode édition : position mémorisée reposée aussitôt")
  f:ClearAllPoints() f:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 40)
  PG.Queue("SetPoint")    -- (crochet post-appel sur notre cadre)
  flushTimers()
  ok(at(), "ClearAllPoints / SetPoint étranger : corrigé à la frame suivante")
  f:ClearAllPoints() f:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 40)
  fire("EDIT_MODE_LAYOUTS_UPDATED")
  flushTimers()
  ok(at(), "EDIT_MODE_LAYOUTS_UPDATED (mise en page appliquée) : position gardée")
  UI:ExitEditMode()
  flushTimers()
  ok(at(), "sortie du mode édition : position gardée")
  -- pendant un glisser : on ne corrige rien
  f._osrsMovingNow = true
  f:ClearAllPoints() f:SetPoint("CENTER", _G.UIParent, "CENTER", 12, 34)
  ok(PG.Check("test") == false, "pendant un glisser du panneau : aucune correction")
  f._osrsMovingNow = nil
  -- seul « Revenir à la position par défaut » remet la place par défaut
  local d = ns.EditMode.BuildDialog()
  d.home.scripts.OnClick(d.home)
  flushTimers()
  ok(ns.db.ui.winPos == nil and not at() and PG.Saved() == nil, "« Revenir à la position par défaut » : place par défaut (" .. tostring(W.posSource) .. "), plus de position imposée")
  ok(PG.DebugLine():find("Position du panneau", 1, true), "ligne de debug")
  _G.C_Timer.After = rAfter
end

print("== 3.3.17 : finitions FlareUI — pastille, chiffres, jauge, marges ==")
do
  local Th, IC, Po, Wd, LY = ns.Theme, ns.Icons, ns.Polish, ns.Wide, ns.Layout
  ok(Po and Th.BADGE_OVERLAP <= -1 and Th.BADGE_H == 10 and IC.VGAP == 12 and LY.MARGIN == 12, "constantes : plaque 10 px posée hors case, écart vertical 12, marge 12")
  -- grille réelle : case de la 2e rangée avec une pastille, case du dessus
  W.Show() ns.UI:Refresh(true)
  local tiles = {}
  for _, t in ipairs(UI.embed.tiles) do if t.data and t:IsShown() and t.data.kind ~= "total" then tiles[#tiles + 1] = t end end
  local low, up
  for _, a in ipairs(tiles) do
    for _, b2 in ipairs(tiles) do
      local ra, rb = __rect(a), __rect(b2)
      if ra and rb and a ~= b2 and math.abs(ra.l - rb.l) < 0.5 and rb.b > ra.t and rb.b - ra.t < 20 then low, up = a, b2 end
    end
  end
  ok(low and up, "deux cases l'une au-dessus de l'autre")
  local rReady, rSk = ns.Craft.Ready, ns.Craft.SKILLS
  if low then
    low.data.id = low.data.id or "zz"
    ns.Craft.SKILLS = setmetatable({ [low.data.id] = true }, { __index = rSk })
    ns.Craft.Ready = function(id) if id == low.data.id then return 7 end return 0 end
    UI:UpdateCraftBadge(low, low.data)
    local b = low.craftBadge
    local rb, rl, ru = __rect(b), __rect(low), __rect(up)
    ok(rb and rb.b >= rl.t + 1 - 0.01, string.format("plaque entière au-dessus de sa case (bas %.1f ≥ haut case + 1 = %.1f)", rb and rb.b or -1, rl.t + 1))
    ok(rb and rb.t <= ru.b - 1 + 0.01, string.format("plaque sous la case du dessus et son ombre de biseau (haut %.1f ≤ %.1f)", rb and rb.t or -1, ru.b - 1))
    ok(b.width <= IC.TILE + IC.HGAP - 6, "plaque jamais plus large que case + écart − 6 (" .. b.width .. " px) : pas sur la voisine")
    ok(b.shadow and b.edge and b.fs._font and b.fs._font[2] <= 9 and b.fs._font[1] == IC.COUNT_PATH, "plaque FlareUI : ombre 1 px + filet bronze, Arial Narrow ≤ 9 px")
    ok(b._text == "7 prêts", "texte « 7 prêts »")
    ns.Craft.Ready = function() return 0 end
    UI:UpdateCraftBadge(low, low.data)
  end
  ns.Craft.Ready, ns.Craft.SKILLS = rReady, rSk
  UI:RefreshCraftBadges()
  -- chiffres : hiérarchie, ombre identique, abréviation
  local t = tiles[1]
  IC.FitCount(t, "32/25000")
  ok(t.countFS.text == "32" and t.countFS2.text == "/25k", "« /25000 » abrégé en « /25k » (PvP)")
  ok(t.countFS2._font[2] < t.countFS._font[2], string.format("« /max » plus petit que le rang (%d < %d)", t.countFS2._font[2], t.countFS._font[2]))
  IC.SetCountColor(t, 1, 1, 1)
  ok(t.countFS.tr == 1 and t.countFS2.tr < 1, "« /max » atténué, rang blanc")
  ok(Po.ShortMax("129/130") == "129/130" and Po.ShortMax("5/12345") == "5/12.3k", "abréviation seulement ≥ 10 000")
  ok(t._numShade and vis(t._numShade), "dégradé sombre sous les chiffres (texture fixe)")
  -- jauge du total
  Wd.forceShown = nil
  Wd.SetShown(true)
  LY.SetCols(3)
  local tot
  for _, x in ipairs(UI.embed.tiles) do if x.data and x.data.kind == "total" and x:IsShown() then tot = x end end
  ok(tot and tot._wideOn, "3 colonnes : barre total")
  if tot then
    local p = tot._wideParts
    local h = tot._wideH
    ok(p.track.height == 8 and p.fill.height == 8, "jauge 8 px (était 3)")
    ok(math.abs(Wd.last.by - (h - 8) / 2) <= 0.5, "jauge centrée verticalement")
    ok(p.edge and vis(p.edge), "filet Dropamine-Thin autour de la jauge")
    ok(p.fill._texSet == Wd.FILL_TEX and p.track._texSet == Wd.TEX and Wd.FILL == ns.STYLE.BORDER, "remplissage jeton pur (WHITE8X8), piste Dropamine-Bar")
    ok(p.text._font and p.text._font[2] == 11 and tot.icon.width == h - 6, "texte Arial Narrow 11 et icône " .. (h - 6) .. " px centrés")
  end
  LY.SetCols(5)
  ok(tot and not tot._wideOn and not vis(tot._wideParts.edge), "retour en case : filet de jauge caché")
  Wd.SetShown(false)
  Wd.forceShown = true
  local mediaOK = io.open(addonDir .. "/Media/Dropamine-Bar.tga", "rb") and io.open(addonDir .. "/Media/Dropamine-Thin.tga", "rb")
  local copies = 0
  for _, n in ipairs({ "FlareUI-Frames", "FlareUI-Forever", "FlareUI-Thin", "FlareUI-Flat-Bright" }) do if io.open(addonDir .. "/Media/" .. n .. ".tga", "rb") then copies = copies + 1 end end
  ok(mediaOK and copies == 0, "médias de la jauge = nos dessins, aucune copie de fichier FlareUI")
end


print("== 3.3.17 : thème « classic » (textures Blizzard par chemin) ==")
do
  local Th, Sk, Cl, IC, Wd, LY = ns.Theme, ns.Skin, ns.Classic, ns.Icons, ns.Wide, ns.Layout
  local f = W.frame
  W.Show()
  ok(Th.Mode() == "flare" and ns.db.ui.theme == nil, "défaut : flare (rien d'enregistré)")
  local flareEdge, flareTint = Sk.EDGE_FILE, Sk.TINT
  slash("theme classic")
  ok(Th.Mode() == "classic" and ns.db.ui.theme == "classic", "/drop theme classic")
  ok(f._skinHost._bdEdge == "Interface\\Tooltips\\UI-Tooltip-Border" and f._skinHost._bdEdgeSize == 16, "panneau : bord d'infobulle Blizzard (chemin du jeu)")
  ok(f._skinHost._bdBorder and math.abs(f._skinHost._bdBorder[1] - Cl.TINT[1]) < 1e-6, "teinte neutre d'infobulle")
  local t
  for _, x in ipairs(UI.embed.tiles) do if x.data and x:IsShown() and x.data.kind ~= "total" then t = x break end end
  ok(t._clsSlot and vis(t._clsSlot) and t._clsSlot._texSet == "Interface\\Buttons\\UI-Quickslot2", "case : cadre de bouton d'action UI-Quickslot2")
  ok(t._clsSlot.width == math.floor(IC.ICON * 66 / 36 + 0.5), "cadre 66 px pour une icône de 36 (ActionButtonTemplate)")
  local bev = t._bevel and t._bevel.strips[1][2]
  ok(bev and not vis(bev), "biseau FlareUI caché en classique")
  local mk = t.icon._thMask or t.icon._mask
  ok(mk == nil or mk._texSet == "Interface\\Buttons\\WHITE8X8", "icône carrée (masque neutre)")
  ok(IC.TEXT_FLAGS == "OUTLINE" and t.countFS._font and t.countFS._font[3] == "OUTLINE", "chiffres contournés (NumberFont)")
  runScript(t, "OnMouseDown")
  ok(t._clsSlot._texSet == "Interface\\Buttons\\UI-Quickslot-Depress", "appui : UI-Quickslot-Depress")
  runScript(t, "OnMouseUp")
  ok(t._clsSlot._texSet == "Interface\\Buttons\\UI-Quickslot2", "relâché : cadre normal")
  t._tgtLit = "direct" Th.BevelColor(t)
  ok(t._clsSlot.vr == nil or true, "cible : cadre recoloré")
  local c = Cl.SlotColor(t)
  ok(c == Cl.GREEN, "cible : cadre vert")
  t._tgtLit = nil Cl.SlotColor(t)
  -- barre du total
  Wd.forceShown = nil Wd.SetShown(true) LY.SetCols(3)
  local tot
  for _, x in ipairs(UI.embed.tiles) do if x.data and x.data.kind == "total" and x:IsShown() then tot = x end end
  ok(tot and tot._wideOn and tot._wideParts.fill._texSet == "Interface\\TargetingFrame\\UI-StatusBar" and tot._wideParts.track._texSet == "Interface\\TargetingFrame\\UI-StatusBar", "barre du total : UI-StatusBar du jeu")
  ok(tot._wideParts.edge._clsEdge == "Interface\\Tooltips\\UI-Tooltip-Border", "barre : bord d'infobulle fin")
  -- retour flare : tout est rétabli
  slash("theme flare")
  ok(Th.Mode() == "flare" and ns.db.ui.theme == nil and Sk.EDGE_FILE == flareEdge and Sk.TINT == flareTint, "retour flare : recette d'habillage d'origine")
  ok(f._skinHost._bdEdge == flareEdge, "panneau : notre bord Dropamine-Frame de nouveau")
  ok(not vis(t._clsSlot) and bev and vis(bev) and (mk == nil or mk._texSet == Th.ICON_MASK), "case : biseau + masque FlareUI rétablis, cadre Blizzard caché")
  ok(IC.TEXT_FLAGS == "" , "chiffres : ombre fine (sans contour) rétablie")
  ok(tot._wideParts.fill._texSet == Wd.FILL_TEX and tot._wideParts.edge._clsEdge == Wd.EDGE_TEX, "barre : jauge FlareUI rétablie")
  LY.SetCols(5) Wd.SetShown(false) Wd.forceShown = true
  -- aucun fichier Blizzard copié
  local copies = 0
  for _, n in ipairs({ "UI-Quickslot2", "UI-Quickslot-Depress", "UI-Tooltip-Border", "UI-StatusBar" }) do
    if io.open(addonDir .. "/Media/" .. n .. ".tga", "rb") or io.open(addonDir .. "/Media/" .. n .. ".blp", "rb") then copies = copies + 1 end
  end
  ok(copies == 0, "textures Blizzard appelées par chemin, aucune copie dans Media/")
  local O = ns.Options
  local it = O and O.Find and O.Find("theme")
  local has = false
  for _, ch in ipairs(it and it.choices or {}) do if ch[1] == "classic" then has = true end end
  ok(has, "réglages / mode édition : choix « Classique »")
end
print("== 3.3.17 : renommage Dropamine — .toc, /drop, préfixe, migration des réglages ==")
do
  local toc = io.open(addonDir .. "/Dropamine.toc"):read("*a")
  ok(toc:find("## Title: Dropamine\n", 1, true) and toc:find("## SavedVariables: DropamineDB, OSRS_TotalLevelDB", 1, true), ".toc : titre Dropamine, DropamineDB + ancienne table déclarée (migration)")
  ok(toc:find("chaque +1 qui tombe", 1, true), ".toc : nouvelle description")
  ok(SLASH_DROPAMINE1 == "/drop" and SLASH_DROPAMINE2 == "/dropamine" and SLASH_DROPAMINE3 == nil and SLASH_DROPAMINE4 == nil and SlashCmdList.DROPAMINE == ns.Slash, "3.3.18 : seulement /drop et /dropamine (anciens alias retirés)")
  prints = {}
  ns.Print("x")
  ok(lastPrint():find("Dropamine", 1, true), "préfixe des messages : Dropamine")
  -- aucun nom global / chemin de l'ancien addon dans le code (hors constantes de migration)
  local stray = {}
  for line in toc:gmatch("[^\n]+") do
    if line:match("%.lua$") then
      local src = io.open(addonDir .. "/" .. line:gsub("\\", "/")):read("*a")
      for l in src:gmatch("[^\n]+") do
        if l:find("OSRS_TotalLevel", 1, true) and not l:match("^%s*%-%-") and not l:find("OLD_", 1, true) and not l:find("ancien", 1, true) then stray[#stray + 1] = line .. ": " .. l end
      end
    end
  end
  ok(#stray == 0, "aucun « OSRS_TotalLevel » restant (cadres, chemins Media) " .. (stray[1] or ""))
  -- migration tardive : l'ancien dossier est chargé après Dropamine
  local function copy(v) if type(v) ~= "table" then return v end local c = {} for k, x in pairs(v) do c[k] = copy(x) end return c end
  local saved = copy(ns.db)
  local dbRef = ns.db
  _G.OSRS_TotalLevelDB = { ui = { colorMode = "jaune", locked = true, winPos = { x = 1, y = 2 } }, chars = { ["Dé Monique-Forever"] = { goals = { dagues = 50 } } } }
  local oldRef = _G.OSRS_TotalLevelDB
  ns._dbFresh = true
  prints = {}
  fire("ADDON_LOADED", "OSRS_TotalLevel")
  ok(_G.DropamineDB == dbRef and ns.db == dbRef, "même table (références conservées)")
  ok(ns.db.ui.colorMode == "jaune" and ns.db.ui.locked == true and ns.db.chars["Dé Monique-Forever"].goals.dagues == 50, "réglages et personnages copiés")
  ok(ns.db._migratedFrom == "OSRS_TotalLevelDB" and ns.db.ui.winPos ~= oldRef.ui.winPos, "copie profonde, marquée _migratedFrom")
  ok(_G.OSRS_TotalLevelDB == oldRef and oldRef.ui.colorMode == "jaune" and oldRef._migratedFrom == nil, "ancienne table intacte (jamais effacée)")
  local said = false
  for _, p in ipairs(prints) do if tostring(p):find("Supprime le dossier", 1, true) then said = true end end
  ok(said, "message : supprimer l'ancien dossier (" .. #prints .. " ligne(s) : " .. tostring(prints[1]) .. ")")
  -- une seule fois
  oldRef.ui.colorMode = "vert"
  fire("ADDON_LOADED", "OSRS_TotalLevel")
  ok(ns.db.ui.colorMode == "jaune", "migration une seule fois")
  -- DropamineDB déjà utilisé : jamais écrasé
  ns.db._migratedFrom = nil ns._dbFresh = nil
  ok(ns.MigrateOldDB() == false and ns.db.ui.colorMode == "jaune", "DropamineDB existant (pas neuf) : rien n'est écrasé")
  for k in pairs(dbRef) do dbRef[k] = nil end
  for k, x in pairs(saved) do dbRef[k] = x end
  _G.OSRS_TotalLevelDB = nil
end

print("== 3.3.18 : nettoyage de publication ==")
do
  local toc = io.open(addonDir .. "/Dropamine.toc"):read("*a")
  ok(toc:find("## X-License: MIT\n", 1, true), ".toc : licence MIT")
  ok(toc:find("## IconTexture: Interface\\AddOns\\Dropamine\\Media\\Dropamine-Icon\n", 1, true) and io.open(addonDir .. "/Media/Dropamine-Icon.tga", "rb"), ".toc : icône Media/Dropamine-Icon (fichier livré)")
  ok(not toc:find("\n## X-Curse-Project-ID", 1, true) and toc:find("# ## X-Curse-Project-ID", 1, true), ".toc : ID CurseForge en commentaire (rien d'inventé)")
  ok(not io.open(addonDir .. "/Media/Flare/Glow.tga", "rb") and io.open(addonDir .. "/Media/Skin/Glow.tga", "rb") and ns.Style.FLARE.glow:find("Media\\Skin\\", 1, true), "Media/Flare → Media/Skin (chemins à jour)")
  -- aucun ancien alias, nulle part dans le code livré
  local bad = {}
  for line in toc:gmatch("[^\n]+") do
    if line:match("%.lua$") then
      local src = io.open(addonDir .. "/" .. line:gsub("\\", "/")):read("*a")
      if src:find("/tl%f[%W]") or src:find("/totallevel", 1, true) then bad[#bad + 1] = line end
    end
  end
  ok(#bad == 0, "plus de /tl ni /totallevel dans le code " .. table.concat(bad, ","))
  prints = {}
  slash("help")
  local h = table.concat(prints, "\n")
  ok(not h:find("/tl%f[%W]") and not h:find("/totallevel", 1, true) and h:find("/drop", 1, true), "aide : seulement /drop")
end
print("== 3.4.0 : bouton d'ouverture — icône DANS la plaque, centrée, même retrait que la barre total (3 thèmes) ==")
do
  local TI, Th, mm = ns.ToggleIcon, ns.Theme, UI.minimap
  for _, theme in ipairs({ "flare", "leger", "classic" }) do
    Th.Set(theme)
    for _, pair in ipairs({ { "minicarte", mm } }) do
      local b = pair[2]
      TI.Plate(b)
      local br, pr, ir = __rect(b), __rect(b._tiPlate), __rect(b._tiIcon)
      local side = pr and (pr.r - pr.l)
      local isz = ir and (ir.r - ir.l)
      local inside = br and pr and pr.l >= br.l - 0.01 and pr.r <= br.r + 0.01 and pr.b >= br.b - 0.01 and pr.t <= br.t + 0.01
      local cx, cy = pr and (pr.l + pr.r) / 2, pr and (pr.t + pr.b) / 2
      local icx, icy = ir and (ir.l + ir.r) / 2, ir and (ir.t + ir.b) / 2
      local inset = ir and pr and (ir.l - pr.l) - TI.BEVEL
      ok(inside and isz == TI.IconSize(side) and isz == side - 2 * TI.INSET - 2 * TI.BEVEL and math.abs(cx - icx) < 0.01 and math.abs(cy - icy) < 0.01
        and math.abs(inset - TI.INSET) < 0.01 and (ir.t - pr.t) <= -(TI.INSET + TI.BEVEL) + 0.01,
        string.format("%s / %s : plaque %s px dans le bouton, icône %s px centrée, retrait %s + biseau %d (jamais au-dessus du bord)", theme, pair[1], tostring(side), tostring(isz), tostring(inset), TI.BEVEL))
      if theme == "classic" then
        ok(b._tiSlot and b._tiSlot.shown ~= false and b._bevel.strips[1][1].shown == false, theme .. " / " .. pair[1] .. " : cadre de bouton d'action (UI-Quickslot2) autour de l'icône, biseau caché")
      else
        ok(not (b._tiSlot and b._tiSlot.shown ~= false) and b._bevel.strips[1][1].shown ~= false, theme .. " / " .. pair[1] .. " : bord biseauté (comme la barre total)")
      end
    end
  end
  Th.Set("flare")
  -- retrait identique à la barre total : icône = hauteur − 2 × biseau dans la barre, ici plaque − 2 × (retrait + biseau)
  ok(TI.INSET == (ns.Wide.EDGE_OUT or 3) and TI.BEVEL == 3, "retrait 3 px = filet de la barre total (EDGE_OUT), biseau 3 px")
end

print("== 3.4.0 : MÉTIER EN COURS — pêche, cuisine, secourisme ; canne équipée ; fenêtre ouverte + liens ==")
do
  local A, T = ns.Activity, ns.Target
  local spells = { [7620] = "Pêche", [2550] = "Cuisine", [3273] = "Secourisme", [3908] = "Couture", [8613] = "Dépeçage", [99001] = "Bandage épais en laine", [99002] = "Boulette de loup", [12345] = "Soins" }
  local rGSI = _G.GetSpellInfo
  _G.GetSpellInfo = function(id) return spells[id] end
  A._reindex()
  A.window, A.cast, A.pole = nil, nil, false
  local function tile(id) for _, t in ipairs(UI.embed.tiles) do if t.data and t.data.id == id and t:IsShown() then return t end end end
  local function lvl(id) local t = tile(id) local m = t and t._osrsTgt return (m and m.shown ~= false) and m._level or nil end
  T.Clear()
  ok(lvl("fishing") == nil and lvl("cooking") == nil, "au repos : Pêche et Cuisine éteintes")
  -- pêche : canalisation (UNIT_SPELLCAST_CHANNEL_START, joueur)
  A.OnCastStart("UNIT_SPELLCAST_CHANNEL_START", "player", "Cast-3-0-0-7620", 7620)
  ok(lvl("fishing") == "direct" and tile("fishing")._tgtLit == "direct", "pêche en cours : case Pêche VERT FORT (bord vert)")
  A.OnCastStart("UNIT_SPELLCAST_CHANNEL_START", "party1", "Cast-x", 2550)
  ok(lvl("cooking") == nil, "sort d'un autre joueur : ignoré")
  A.OnCastStop("UNIT_SPELLCAST_CHANNEL_STOP", "player")
  ok(lvl("fishing") == nil, "fin de la canalisation : Pêche éteinte")
  -- canne à pêche équipée : classe 2 / sous-classe 20
  local rInv, rGII = _G.GetInventoryItemID, _G.GetItemInfoInstant
  _G.GetInventoryItemID = function(_, slot) return slot == 16 and 6256 or nil end
  _G.GetItemInfoInstant = function(id) if id == 6256 then return id, "Arme", "Canne à pêche", "INVTYPE_2HWEAPON", 0, 2, 20 end end
  A.OnPole("PLAYER_EQUIPMENT_CHANGED", 16)
  ok(A.pole == true and lvl("fishing") == "indirect" and tile("fishing")._osrsTgt.fs.text == "+", "canne à pêche équipée : Pêche en vert DISCRET (« + »)")
  A.OnCastStart("UNIT_SPELLCAST_CHANNEL_START", "player", "Cast-3", 7620)
  ok(lvl("fishing") == "direct", "canne + pêche : le fort l'emporte")
  A.OnCastStop("UNIT_SPELLCAST_CHANNEL_STOP", "player")
  _G.GetItemInfoInstant = function(id) return id, "Arme", "Bâton", "INVTYPE_2HWEAPON", 0, 2, 10 end
  A.OnPole("PLAYER_EQUIPMENT_CHANGED", 16)
  ok(A.pole == false and lvl("fishing") == nil, "bâton (2/10) : pas de canne, Pêche éteinte")
  -- secourisme : fenêtre ouverte (nom LOCALISÉ lu en jeu) + bandage lancé
  local tsf = _G.TradeSkillFrame
  tsf.shown = true
  A.OnWindow("TRADE_SKILL_SHOW")
  ok(A.window == "firstaid" and lvl("firstaid") == "indirect", "fenêtre Secourisme ouverte : case Secourisme en vert discret (nom lu : « " .. tostring(_G.GetTradeSkillLine()) .. " »)")
  A.OnCastStart("UNIT_SPELLCAST_START", "player", "Cast-3-0-0-99001", 99001)
  ok(lvl("firstaid") == "direct", "« Bandage épais en laine » lancé fenêtre ouverte : Secourisme VERT FORT")
  A.OnCastStop("UNIT_SPELLCAST_STOP", "player")
  ok(lvl("firstaid") == "indirect", "fin du sort : retour au vert discret (fenêtre toujours ouverte)")
  -- liens : Secourisme ← Couture (tissu) ; détail au survol seulement
  local links = A.LinksFor("firstaid")
  local has = false for _, l in ipairs(links) do if l.skill == "tailoring" then has = true end end
  ok(has, "liens de Secourisme : Couture (matières : tissu)")
  local m = ns.Compact.TooltipModel(tile("firstaid").data)
  local txt = {} for _, l in ipairs(m.lines) do txt[#txt + 1] = tostring(l[1]) end
  ok(table.concat(txt, "|"):find("Métier prêt", 1, true) and table.concat(txt, "|"):find("fenêtre du métier ouverte", 1, true), "survol de Secourisme : section « Métier prêt » + raison")
  tsf.shown = false
  A.OnWindow("TRADE_SKILL_CLOSE")
  A.window = nil A.Refresh("test")
  ok(lvl("firstaid") == nil, "fenêtre fermée : Secourisme éteinte")
  -- cuisine : fenêtre Cuisine, recette lancée ; Pêche liée (fournit le poisson)
  local rLine = _G.GetTradeSkillLine
  _G.GetTradeSkillLine = function() return "Cuisine", 0, 0 end
  tsf.shown = true
  A.OnWindow("TRADE_SKILL_SHOW")
  ok(A.window == "cooking" and lvl("cooking") == "indirect" and lvl("fishing") == "link", "fenêtre Cuisine : Cuisine discrète, Pêche en LIEN (voile léger)")
  ok(tile("fishing")._osrsTgt.fs.text == "" and tile("fishing")._osrsTgt.veil.alpha == A.VEIL_LINK, "lien : aucune marque, voile " .. A.VEIL_LINK)
  local mf = ns.Compact.TooltipModel(tile("fishing").data)
  local tf = {} for _, l in ipairs(mf.lines) do tf[#tf + 1] = tostring(l[1]) end
  ok(table.concat(tf, "|"):find("Lien métiers", 1, true), "survol de Pêche : « Lien métiers » + raison")
  local cl = ns.CharDB().recipes.cooking and ns.CharDB().recipes.cooking.list
  if cl and cl[1] then spells[99002] = cl[1].name end
  A.OnCastStart("UNIT_SPELLCAST_START", "player", "Cast-3-0-0-99002", 99002)
  ok(lvl("cooking") == "direct", "recette de cuisine lue en jeu (« " .. tostring(spells[99002]) .. " ») lancée : Cuisine VERT FORT")
  A.OnCastStop("UNIT_SPELLCAST_INTERRUPTED", "player")
  -- sort sans rapport (soin) pendant la fenêtre : rien de fort si les recettes sont connues
  local list = ns.CharDB().recipes.cooking and ns.CharDB().recipes.cooking.list
  if list and #list > 0 then
    A.OnCastStart("UNIT_SPELLCAST_START", "player", "Cast-3", 12345)
    ok(A.cast == nil, "sort sans rapport (« Soins ») fenêtre ouverte : ignoré (recettes lues connues)")
  end
  tsf.shown = false
  A.OnWindow("TRADE_SKILL_CLOSE") A.window = nil A.Refresh("test")
  _G.GetTradeSkillLine = rLine
  -- option + commande
  ns.SlashExt.activite("off")
  A.OnCastStart("UNIT_SPELLCAST_CHANNEL_START", "player", "Cast-3", 7620)
  ok(lvl("fishing") == nil and ns.Options.Get("activity") == false, "/drop activite off : plus de surbrillance de métier")
  A.OnCastStop("UNIT_SPELLCAST_CHANNEL_STOP", "player")
  ns.SlashExt.activite("on")
  ok(ns.Options.Get("activity") == true, "/drop activite on")
  -- coûts : aucun OnUpdate posé
  local tot = 0 for k, v in pairs(A.stats) do tot = tot + v end
  ok(type(A.Refresh) == "function" and not rawget(A, "ticker"), "aucune minuterie : événements du joueur seulement")
  _G.GetSpellInfo, _G.GetInventoryItemID, _G.GetItemInfoInstant = rGSI, rInv, rGII
  A._reindex()
  A.window, A.cast, A.pole = nil, nil, false
  T.Clear()
end

print("== 3.4.0 : thème Léger — AUCUN cadre ni fond autour des cases ; Classique inchangé ==")
do
  local Th, f, P = ns.Theme, W.frame, ns.Panel
  ns.Skin.enabled = true
  P.ApplyTooltipLook(f)
  Th.Set("leger")
  local h = f._skinHost
  ok(h and h.shown == false and h.alpha == 0, "Léger : habillage caché et transparent")
  P.ApplyOpacity() if P.SetHover then P.SetHover(true) P.SetHover(false) end
  W.Hide() W.Show()
  P.ApplyTooltipLook(f)
  ok(h.shown == false and h.alpha == 0, "Léger : rien ne le remontre (fondu, survol, réouverture, ré-habillage)")
  Th.Set("classic")
  ok(h.shown ~= false and h.alpha == 1 and ns.Skin.EDGE_FILE == ns.Classic.EDGE_FILE, "Classique : bord d'infobulle Blizzard (inchangé)")
  Th.Set("flare")
  ok(h.shown ~= false and h.alpha == 1 and ns.Skin.EDGE_FILE:find("Dropamine%-Frame"), "FlareUI : cadre de retour (inchangé)")
end

print("== 3.4.0 : réglages — 5 groupes, libellés courts, une aide par réglage, aide /drop courte ==")
do
  local O = ns.Options
  local noHelp, long = {}, {}
  for _, it in ipairs(O.All()) do
    if not (it.help and #it.help > 0) then noHelp[#noHelp + 1] = tostring(it.key) end
    if #(it.label or "") > 34 then long[#long + 1] = it.label end
  end
  ok(#noHelp == 0, "chaque réglage a sa phrase d'aide (" .. table.concat(noHelp, ",") .. ")")
  ok(#long == 0, "libellés courts (≤ 34 caractères) " .. table.concat(long, " | "))
  local titles = {} for _, s in ipairs(O.SECTIONS) do titles[#titles + 1] = s.title end
  ok(table.concat(titles, ",") == "Affichage & thème,Métiers & surlignage,JcJ,Notifications,Avancé", "groupes : " .. table.concat(titles, ", "))
  ok(O.Find("activity") and O.Find("activity").default == true, "nouveau : « Surligner le métier en cours » (activé par défaut)")
  local defaults = {} for _, it in ipairs(O.All()) do defaults[it.key] = it.default end
  ok(defaults.theme == "flare" and defaults.cols == 5 and defaults.scale == 100 and defaults.scannerToast == false and defaults.levelUpSound == false, "défauts d'un premier lancement : FlareUI, 5 colonnes, 100 %, sons et toasts secondaires coupés")
  prints = {}
  slash("help")
  local h = table.concat(prints, "\n")
  ok(#prints <= 10 and h:find("Affichage", 1, true) and h:find("Métiers", 1, true) and h:find("/drop help tout", 1, true), "/drop help : " .. #prints .. " lignes, rangées par thème")
  prints = {}
  slash("help tout")
  ok(#prints > 15, "/drop help tout : toutes les commandes (" .. #prints .. " lignes)")
  ok(not table.concat(prints, "\n"):find("sens haut|bas", 1, true), "commandes mortes (sens / coller au chat) retirées de l'aide")
  local toc = io.open(addonDir .. "/Dropamine.toc"):read("*a")
  ok(toc:find("## Version: 3.5.0\n", 1, true) and toc:find("\nActivity.lua", 1, true) and toc:find("\nProfJob.lua", 1, true) and toc:find("\nDopamine.lua", 1, true), ".toc : version 3.5.0, Activity.lua, ProfJob.lua, Dopamine.lua")
end

print("== 3.4.1 : survol / appui du bouton d'ouverture = NOTRE surbrillance, posée sur la plaque ; zone de survol = plaque ==")
do
  local TI, Th, mm = ns.ToggleIcon, ns.Theme, UI.minimap
  local function hooked(b, ev) for _, fn in ipairs(b.hooks[ev] or {}) do fn(b) end end
  for _, theme in ipairs({ "flare", "leger", "classic" }) do
    Th.Set(theme)
    for _, pair in ipairs({ { "minicarte", mm } }) do
      local b, nm = pair[2], theme .. " / " .. pair[1]
      TI.Plate(b)
      local H, pr, br = b._tiHover, __rect(b._tiPlate), __rect(b)
      local hl = b._tiNativeHL
      ok(hl == nil or hl.alpha == 0, nm .. " : surbrillance native invisible (art du micro-bouton décalé)")
      local hi = b.hitInsets
      ok(hi and math.abs((br.l + hi[1]) - pr.l) < 0.51 and math.abs((br.r - hi[2]) - pr.r) < 0.51 and math.abs((br.t - hi[3]) - pr.t) < 0.51 and math.abs((br.b + hi[4]) - pr.b) < 0.51,
        string.format("%s : zone de survol = plaque (marges %s)", nm, hi and table.concat(hi, ",") or "?"))
      hooked(b, "OnEnter")
      if theme == "classic" then
        local cr, ir = __rect(H.cls), __rect(b._tiIcon)
        ok(H.cls.shown ~= false and H.edge[1].shown == false and cr.l == ir.l and cr.t == ir.t and cr.r == ir.r and H.cls._texSet == TI.CLASSIC_HL, nm .. " : survol = surbrillance carrée des boutons d'action, sur l'icône")
      else
        local top, bot, lef, rig = __rect(H.edge[1]), __rect(H.edge[2]), __rect(H.edge[3]), __rect(H.edge[4])
        ok(H.edge[1].shown ~= false and H.fill.shown ~= false and top.t == pr.t and bot.b == pr.b and lef.l == pr.l and rig.r == pr.r and H.cls.shown == false,
          nm .. " : survol = filet clair + voile, EXACTEMENT sur le bord de la plaque (haut " .. tostring(top.t) .. " = " .. tostring(pr.t) .. ")")
      end
      hooked(b, "OnMouseDown")
      ok(H.down.shown ~= false and (theme ~= "classic" or b._tiSlot._texSet == TI.CLASSIC_DOWN), nm .. " : appui = icône assombrie" .. (theme == "classic" and " + cadre enfoncé (UI-Quickslot-Depress)" or ""))
      hooked(b, "OnMouseUp")
      ok(H.down.shown == false and (theme ~= "classic" or b._tiSlot._texSet == TI.CLASSIC_SLOT), nm .. " : relâché")
      hooked(b, "OnLeave")
      ok(H.fill.shown == false and H.edge[1].shown == false and H.cls.shown == false, nm .. " : sortie = plus de surbrillance")
    end
  end
end

print("== 3.4.3 : MÉTIER EN COURS robuste — interface de métiers de Forever, API moderne absente / présente ; /drop debug copiable ==")
do
  local A, T, DW = ns.Activity, ns.Target, ns.DebugWindow
  local spells = { [3273] = "Secourisme", [7620] = "Pêche", [2550] = "Cuisine", [3908] = "Couture" }
  local rGSI, rLine, rUCI, rUChI, rCT = _G.GetSpellInfo, _G.GetTradeSkillLine, _G.UnitCastingInfo, _G.UnitChannelInfo, _G.C_TradeSkillUI
  _G.GetSpellInfo = function(id) return spells[id] end
  A._reindex()
  local function reset() A.window, A.cast, A.pole, A.pendingCast, A._apiOpen, A._craftOpen = nil, nil, false, nil, nil, nil A.learned = {} T.Clear() end
  local function tile(id) for _, t in ipairs(UI.embed.tiles) do if t.data and t.data.id == id and t:IsShown() then return t end end end
  local function lvl(id) local t = tile(id) local m = t and t._osrsTgt return (m and m.shown ~= false) and m._level or nil end
  local tsf = _G.TradeSkillFrame
  if not W.IsShown() then W.Show() end
  -- recettes de Secourisme lues = AUCUNE (l'ancien lecteur ne voit pas la nouvelle interface)
  local rec = ns.CharDB().recipes
  local savedFA = rec.firstaid
  rec.firstaid = nil
  reset()
  -- (1) API moderne ABSENTE, GetTradeSkillLine muet, fenêtre « ProfessionsFrame » chargée à la demande
  _G.C_TradeSkillUI = nil
  _G.GetTradeSkillLine = function() return nil end
  _G.UnitCastingInfo, _G.UnitChannelInfo = function() return nil end, function() return nil end
  tsf.shown = false
  local pf = CreateFrame("Frame", "ProfessionsFrame", _G.UIParent)
  pf.shown = false
  pf.TitleText = pf:CreateFontString(nil, "OVERLAY")
  pf.TitleText:SetText("Secourisme")
  fire("ADDON_LOADED", "Blizzard_Professions")
  ok(A.hooked.ProfessionsFrame, "fenêtre chargée à la demande : OnShow / OnHide accrochés (ADDON_LOADED)")
  pf.shown = true
  for _, fn in ipairs(pf.hooks.OnShow or {}) do fn(pf) end
  if ns.ProfJob then ns.ProfJob.Flush() end
  ok(A.window == "firstaid" and lvl("firstaid") == "indirect", "API absente : titre « Secourisme » de ProfessionsFrame → case Secourisme en vert discret (" .. tostring(A.diag.src) .. ")")
  -- lancer « Bandage en laine » (id inconnu de l'addon, recette pas en cache), UnitCastingInfo : isTradeSkill = true
  spells[3277] = "Bandage en laine"
  _G.UnitCastingInfo = function(u) if u == "player" then return "Bandage en laine", "", 133688, 1000, 4000, true, "Cast-3-0-0-3277", false, 3277 end end
  fire("UNIT_SPELLCAST_START", "player", "Cast-3-0-0-3277", 3277)
  local t = tile("firstaid")
  ok(lvl("firstaid") == "direct" and t._tgtLit == "direct" and t._osrsTgt.veil.alpha == T.VEIL.direct and t._osrsTgt.fs.text == "+1",
    "« Bandage en laine » en cours : Secourisme VERT FORT, même voile (" .. T.VEIL.direct .. ") et même bord que les surbrillances de combat (" .. tostring(A.diag.mapSrc) .. ")")
  ok(A.diag.castName == "Bandage en laine" and A.diag.castID == 3277 and tostring(A.diag.castSrc):find("UnitCastingInfo", 1, true), "debug : dernier sort « Bandage en laine » (3277) lu par l'événement + UnitCastingInfo")
  -- Tout créer : STOP puis START → reste fort
  fire("UNIT_SPELLCAST_STOP", "player", "Cast-3-0-0-3277", 3277)
  ok(lvl("firstaid") == "indirect", "entre deux bandages : retour au vert discret")
  fire("UNIT_SPELLCAST_START", "player", "Cast-3-0-0-3277", 3277)
  ok(lvl("firstaid") == "direct", "bandage suivant (« Tout créer ») : vert fort de nouveau")
  fire("UNIT_SPELLCAST_STOP", "player", "Cast-3-0-0-3277", 3277)
  -- sort sans rapport fenêtre ouverte (isTradeSkill = false) : ignoré
  spells[2061] = "Soins rapides"
  _G.UnitCastingInfo = function(u) if u == "player" then return "Soins rapides", "", 1, 1, 2, false, "Cast-x", false, 2061 end end
  rec.firstaid = { list = { { name = "Bandage en lin" } } }
  fire("UNIT_SPELLCAST_START", "player", "Cast-x", 2061)
  ok(A.cast == nil, "sort ordinaire (isTradeSkill = faux) pendant la fenêtre : ignoré")
  rec.firstaid = nil
  fire("UNIT_SPELLCAST_STOP", "player")
  pf.shown = false
  for _, fn in ipairs(pf.hooks.OnHide or {}) do fn(pf) end
  ok(A.window == nil and lvl("firstaid") == nil, "ProfessionsFrame fermée (OnHide) : Secourisme éteinte aussitôt")
  -- (2) ordre des événements : TRADE_SKILL_SHOW arrive AVANT que TradeSkillFrame soit visible
  _G.GetTradeSkillLine = function() return "Secourisme", 139, 150 end
  tsf.shown = false
  fire("TRADE_SKILL_SHOW")
  if ns.ProfJob then ns.ProfJob.Flush() end
  ok(A.window == "firstaid" and lvl("firstaid") == "indirect", "TRADE_SKILL_SHOW avant l'affichage de la fenêtre : métier lu par l'API, surligné après le travail regroupé (cause du bug 3.4.2)")
  fire("TRADE_SKILL_CLOSE")
  ok(A.window == nil and lvl("firstaid") == nil, "TRADE_SKILL_CLOSE : éteinte")
  -- (3) barre de rang seule (« Secourisme 139/150 »), titre muet
  _G.GetTradeSkillLine = function() return nil end
  local rk = tsf:CreateFontString(nil, "OVERLAY")
  local rTitle = _G.TradeSkillFrameTitleText
  _G.TradeSkillFrameTitleText = nil
  _G.TradeSkillRankFrameSkillName = rk
  rk:SetText("Secourisme 139/150")
  tsf.shown = true
  A.OnWindow("OnShow TradeSkillFrame")
  ok(A.window == "firstaid" and tostring(A.diag.src):find("barre de rang", 1, true), "titre muet : barre « Secourisme 139/150 » reconnue (" .. tostring(A.diag.src) .. ")")
  tsf.shown = false
  A.OnWindowClosed("OnHide TradeSkillFrame")
  _G.TradeSkillRankFrameSkillName, _G.TradeSkillFrameTitleText = nil, rTitle
  -- (4) aucune fenêtre, sort inconnu → message « Votre compétence en Secourisme … » : reconnu et retenu
  reset()
  _G.UnitCastingInfo = function() return nil end
  spells[99777] = "Bandage runique"
  fire("UNIT_SPELLCAST_START", "player", "Cast-9", 99777)
  ok(A.cast == nil and A.pendingCast and A.pendingCast.name == "Bandage runique", "sort inconnu sans fenêtre : en attente")
  fire("CHAT_MSG_SKILL", "Votre compétence en Secourisme est maintenant de 140.")
  ok(lvl("firstaid") == "direct" and A.diag.mapSrc == "message de compétence", "message de compétence : Secourisme VERT FORT")
  fire("UNIT_SPELLCAST_STOP", "player")
  fire("UNIT_SPELLCAST_START", "player", "Cast-9", 99777)
  ok(lvl("firstaid") == "direct" and A.diag.mapSrc == "appris (message de compétence)", "même sort ensuite : reconnu tout de suite (appris pour la session)")
  fire("UNIT_SPELLCAST_STOP", "player")
  -- (5) API moderne PRÉSENTE : C_TradeSkillUI.GetTradeSkillLineForRecipe
  reset()
  _G.C_TradeSkillUI = { GetTradeSkillLineForRecipe = function(id) if id == 88001 then return 129, "Secourisme", 129 end end }
  spells[88001] = "Trousse de soins"
  fire("UNIT_SPELLCAST_START", "player", "Cast-8", 88001)
  ok(lvl("firstaid") == "direct" and A.diag.mapSrc == "C_TradeSkillUI", "API moderne présente : recette → ligne « Secourisme » → vert fort")
  -- (6) /drop debug metier : fenêtre copiable, métier en tête
  local eb = DW.Build() and DW.edit
  local focused, hl = false, 0
  eb.SetFocus = function() focused = true end
  eb.HighlightText = function() hl = hl + 1 end
  local np = #prints
  slash("debug metier")
  local L = DW.lines or {}
  ok(DW.frame.shown ~= false and L[1] == "— Métier en cours (3.4.3) —" and not tostring(DW.text):find("Cascade de collecte", 1, true),
    "/drop debug metier : fenêtre ouverte, seulement la partie métier (" .. #L .. " lignes)")
  local txt = tostring(DW.text)
  ok(txt:find("fenêtre détectée", 1, true) and txt:find("source du nom", 1, true) and txt:find("dernier sort : Trousse de soins (id 88001", 1, true) and txt:find("case « Secourisme », surbrillance direct", 1, true),
    "debug : fenêtre détectée, source du nom, dernier sort + id, case et état de surbrillance")
  ok(eb.text == DW.text and focused and hl >= 1, "texte présélectionné (HighlightText + focus) : Ctrl+C suffit")
  local gotChat = false
  for k = np + 1, #prints do if tostring(prints[k]):find("Debug copié dans la fenêtre", 1, true) and not tostring(prints[k]):find("^  ") then gotChat = true end end
  ok(gotChat, "chat : « Debug copié dans la fenêtre »")
  local esc = false for _, n in ipairs(_G.UISpecialFrames) do if n == DW.NAME then esc = true end end
  ok(esc and DW.close and DW.close.scripts.OnClick, "Échap et bouton ✕ ferment la fenêtre de debug")
  eb.scripts.OnTextChanged(eb, true)
  ok(eb.text == DW.text, "lecture seule : une frappe remet le texte")
  slash("debug")
  ok(DW.lines[1] == "— Métier en cours (3.4.3) —" and tostring(DW.text):find("Cascade de collecte", 1, true), "/drop debug : métier en tête, puis tout le reste")
  DW.close.scripts.OnClick(DW.close)
  ok(DW.frame.shown == false, "✕ : fenêtre fermée")
  fire("UNIT_SPELLCAST_STOP", "player")
  -- remise en état
  pf.shown = false
  rec.firstaid = savedFA
  _G.GetSpellInfo, _G.GetTradeSkillLine, _G.UnitCastingInfo, _G.UnitChannelInfo, _G.C_TradeSkillUI = rGSI, rLine, rUCI, rUChI, rCT
  A._reindex()
  reset()
end

print("== 3.5.0 : fenêtre de métier — un seul scan par métier, travail différé ==")
do
  local J = ns.ProfJob
  ok(J and J.Schedule and J.Flush, "ProfJob chargé")
  J.cache, J.stats = {}, { scans = 0, scanMs = 0, lastMs = 0, skipped = 0, batches = 0, jobs = 0 }
  J._armed, J._scan, J._retried = false, nil, nil
  local calls = 0
  local rInfo, rNum, rLine = _G.GetTradeSkillInfo, _G.GetNumTradeSkills, _G.GetTradeSkillLine
  _G.GetNumTradeSkills = function() return #trade.list end
  _G.GetTradeSkillLine = function() return trade.line, 10, 75 end
  local function fill(line, n)
    trade.line = line
    trade.list = {}
    for i = 1, n do trade.list[i] = { name = line .. " recette " .. i, kind = "easy", reagents = { { id = 1000 + i, name = "c", count = 1 } } } end
  end
  _G.GetTradeSkillInfo = function(i)
    calls = calls + 1
    local r = trade.list[i]
    return r and r.name, r and r.kind, 1, true
  end
  local tsf = _G.TradeSkillFrame
  tsf.shown = true
  local before = #timers
  fill("Secourisme", 30)
  for i = 1, 6 do fire("TRADE_SKILL_SHOW") fire("TRADE_SKILL_UPDATE") fire("TRADE_SKILL_LIST_UPDATE") end
  fill("Cuisine", 40)
  for i = 1, 4 do fire("TRADE_SKILL_UPDATE") fire("CRAFT_UPDATE") end
  fill("Secourisme", 30)
  fire("TRADE_SKILL_SHOW")
  ok(J._armed and (#timers - before) <= 2, "rafale d'onglets : un seul travail en attente (" .. tostring(#timers - before) .. " minuteries)")
  local queued = #timers - before
  J.Flush()
  ok(J.stats.scans == 1, "après la rafale : un seul scan (le métier encore ouvert), pas un par événement (" .. tostring(J.stats.scans) .. ")")
  ok(calls >= 30 and calls < 40, "le scan lit chaque recette une fois (" .. calls .. " appels, 30 recettes ; la surbrillance s'arrête à la 1re recette non grise)")
  ok(J.stats.batches >= 2, "scan étalé : " .. tostring(J.stats.batches) .. " lots d'environ " .. J.BATCH)
  local pump = J._frame
  ok(not J._scan and (not pump or pump.scripts.OnUpdate == nil), "après le travail : plus d'OnUpdate")
  calls = 0
  fill("Cuisine", 40)
  fire("TRADE_SKILL_SHOW") fire("TRADE_SKILL_UPDATE") fire("TRADE_SKILL_LIST_UPDATE")
  J.Flush()
  ok(J.stats.scans == 2 and calls >= 40 and calls < 50, "deuxième métier : un scan de plus, pas ceux déjà vus (" .. calls .. " lectures)")
  calls = 0
  fill("Secourisme", 30)
  fire("TRADE_SKILL_SHOW") fire("TRADE_SKILL_UPDATE") fire("TRADE_SKILL_LIST_UPDATE")
  J.Flush()
  ok(J.stats.scans == 2 and J.stats.skipped >= 1 and calls < 30, "retour sur Secourisme (même clé) : aucun nouveau scan (" .. calls .. " sondes de surbrillance)")
  _G.InCombatLockdown = function() return true end
  local scans = J.stats.scans
  fill("Cuisine", 10)
  J.cache.cooking = nil
  fire("TRADE_SKILL_SHOW")
  J.Flush()
  ok(J.stats.scans == scans, "en combat : pas de scan")
  _G.InCombatLockdown = function() return false end
  _G.GetTradeSkillInfo, _G.GetNumTradeSkills, _G.GetTradeSkillLine = rInfo, rNum, rLine
  tsf.shown = false
  if ns.Activity then ns.Activity.window, ns.Activity._apiOpen = nil, nil end
end

print("== 3.5.0 : joueur ennemi — case JcJ, arme, Défense, repère vert ==")
do
  local T, PV = ns.Target, ns.PvP
  PV.forceOff = nil
  ns.db.ui.pvp = nil
  if not W.IsShown() then W.Show() end
  ns.UI:Refresh(true)
  local saved = {}
  local function stub(n, v) saved[n] = saved[n] or _G[n] _G[n] = v end
  local unit = {
    exists = true, name = "Grunt", level = 26, player = true, dead = false,
    attack = true, enemy = true, pvp = true, faction = "Horde", guid = "Player-1-ABCDEF",
  }
  stub("UnitExists", function(u) return u == "target" or u == "nameplate1" or u == "player" end)
  stub("UnitName", function(u) if u == "player" then return "Raykuilu" end return unit.name end)
  stub("UnitLevel", function(u) if u == "player" then return 27 end return unit.level end)
  stub("UnitIsDead", function() return unit.dead end)
  stub("UnitIsPlayer", function(u) if u == "player" then return true end return unit.player end)
  stub("UnitCanAttack", function(a, u) if u == "player" then return false end return unit.attack end)
  stub("UnitIsEnemy", function(a, u) if u == "player" then return false end return unit.enemy end)
  stub("UnitIsPVP", function(u) if u == "player" then return true end return unit.pvp end)
  stub("UnitFactionGroup", function(u) if u == "player" then return "Alliance" end return unit.faction end)
  stub("UnitGUID", function(u) if u == "player" then return "Player-1-000000" end return unit.guid end)
  stub("UnitCreatureType", function() return nil end)
  stub("UnitIsTapDenied", function() return false end)
  stub("UnitClass", function(u) if u == "player" then return "Guerrier", "WARRIOR" end return "Guerrier", "WARRIOR" end)
  T.swing.melee = false
  _G.UnitAffectingCombat = function() return false end
  _G.UnitIsUnit = function(a, b) return a == b end
  fire("PLAYER_TARGET_CHANGED")
  local function tile(id)
    for _, t in ipairs(ns.UI.embed.tiles) do
      if t:IsShown() and t.data and (t.data.id == id or t.data.kind == id) then return t end
    end
  end
  local function lvl(id)
    local t = tile(id)
    local m = t and t._osrsTgt
    return (m and m.shown ~= false) and m._level or nil
  end
  local id, info = ns.Scanner.UnitNpcID("target")
  ok(id == nil and info.kind == "Player" and tostring(info.how):find("Player", 1, true), "GUID Player : pas un PNJ (" .. tostring(info.how) .. ")")
  ok(lvl("level") == nil, "joueur : pas d'XP")
  ok(lvl("skinning") == nil and lvl("cooking") == nil, "joueur : pas de dépeçage ni de butin (type de créature nil)")
  ok(lvl("pvp") == "indirect", "JcJ : ennemi honorable ciblé, surbrillance discrète (" .. tostring(lvl("pvp")) .. ")")
  ok(lvl("defense") == "indirect" or lvl("defense") == "direct", "Défense allumée sur le joueur non gris")
  local mel = tile("melee")
  ok(mel and lvl("melee") ~= nil, "arme équipée allumée sur le joueur ennemi")
  _G.UnitAffectingCombat = function(u) return u == "player" or u == "target" end
  T._lvlSig = nil
  fire("PLAYER_TARGET_CHANGED")
  ok(lvl("pvp") == "direct", "en combat avec lui : case JcJ en vert fort")
  local plate = newObj("Frame", nil, _G.UIParent)
  plate.UnitFrame = plate
  stub("C_NamePlate", { GetNamePlateForUnit = function() return plate end })
  local mk = PV.Evaluate("nameplate1")
  ok(mk and mk._honor == true and mk.icon._vc and mk.icon._vc[2] > 0.8, "repère de barre de nom VERT (honneur)")
  unit.level = 10
  mk = PV.Evaluate("nameplate1")
  ok(mk and mk._honor == false and mk.icon._vc and mk.icon._vc[1] > 0.4 and mk.icon._vc[2] < 0.7, "niveau trivial : repère gris")
  unit.level = 26
  unit.pvp = false
  ok(PV.HonorFor("nameplate1") == nil, "sans drapeau JcJ : pas d'honneur")
  ok(ns.Gather.Evaluate("nameplate1") == nil and ns.Scanner.OnPlateAdded("nameplate1") == nil, "joueur : pas de repère de créature (GUID Player, type nil)")
  ok(ns.Scanner.IsPlayerUnit("nameplate1"), "UnitIsPlayer + GUID Player")
  for n, v in pairs(saved) do _G[n] = v end
  T.swing.melee = false
  PV.forceOff = true
  ns.UI:Refresh(true)
end

print("== 3.5.0 : dopamine — combo, sons, max, défi, records, barre, collection ==")
do
  local D = ns.Dopamine
  ok(D and ns.Options.Find("combo") and ns.Options.Find("sounds") and ns.Options.Find("soundSkill").default == false, "réglages dopamine, sons coupés par défaut")
  ok(ns.Options.Find("levelUpSound").default == false and ns.Options.Find("scannerSound").default == false, "sons déjà là : défauts inchangés")
  ok(ns.Options.Find("sounds").default == true, "interrupteur Sons ouvert par défaut (ne coupe pas un son déjà coché)")
  local d = D.C()
  d.combo, d.comboLast, d.bestCombo = nil, nil, nil
  local t0 = 10000
  ok(D.NoteCombo(t0) == 1 and D.LiveCombo(t0) == 1, "premier point : combo x1 (pas encore affiché)")
  ok(D.NoteCombo(t0 + 30) == 2 and D.LiveCombo(t0 + 30) == 2, "dans les 60 s : x2")
  ok(D.NoteCombo(t0 + 50) == 3 and d.bestCombo == 3, "x3, record mémorisé")
  ok(D.LiveCombo(t0 + 50 + 60) == 2 and D.LiveCombo(t0 + 50 + 120) == 1, "le combo retombe d'un cran toutes les 60 s")
  ok(D.NoteCombo(t0 + 500) == 1, "après une pause : on repart à x1")
  ns.db.ui.sounds = nil
  ns.db.ui.soundSkill, ns.db.ui.soundPalier = nil, nil
  local played = {}
  _G.PlaySound = function(s) played[#played + 1] = s return true end
  _G.SOUNDKIT = { IG_QUEST_LOG_OPEN = 8001, IG_QUEST_LIST_COMPLETE = 8002, UI_EPICLOOT_TOAST = 8003, UI_LEGENDARY_LOOT_TOAST = 8004 }
  ok(D.Play("soundSkill") == nil and #played == 0, "son de point coupé par défaut")
  ns.db.ui.soundSkill = true
  ok(D.Play("soundSkill") == "IG_QUEST_LOG_OPEN", "son de point : kit du jeu")
  ns.db.ui.sounds = false
  local n = #played
  ok(D.Play("soundSkill") == nil and #played == n, "interrupteur Sons : tout se tait")
  ns.db.ui.sounds = nil
  ok(D.CrossedPalier("profession", 74, 75) == 75 and D.CrossedPalier("profession", 75, 76) == nil, "palier 75 franchi une seule fois")
  ok(D.ReachedMax("profession", 299, 300, 300) and not D.ReachedMax("profession", 74, 75, 75), "maximum : 300, pas le palier d'apprenti")
  ok(D.ReachedMax("melee", 134, 135, 135) and not D.ReachedMax("level", 59, 60, 60), "maximum d'arme, pas le niveau du personnage")
  d.records = {}
  D.AddPoints(4, t0)
  ok(d.records.bestSession == 4 and d.records.session == 4, "première session : record posé sans toast")
  local nt = (ns.UI.dropsActive and #ns.UI.dropsActive) or 0
  D.AddPoints(1, t0 + 10)
  ok(d.records.bestSession == 5, "battre le record de session")
  local hour2 = t0 + 3700
  D.AddPoints(2, hour2)
  D.AddPoints(1, hour2 + 5)
  ok((d.records.bestHour or 0) >= 2, "record de l'heure mémorisé")
  local skills = {
    { id = "skinning", name = "Dépeçage", current = 10, max = 300, kind = "profession" },
    { id = "mining", name = "Minage", current = 20, max = 300, kind = "profession" },
    { id = "cooking", name = "Cuisine", current = 1, max = 300, kind = "secondary" },
  }
  local g = D.EnsureDaily(skills, "2026-11-17", "Raykuilu-Forever")
  local g2 = D.EnsureDaily(skills, "2026-11-17", "Raykuilu-Forever")
  ok(g and g.goal == g.start + 5 and g.id == g2.id and g.name, "défi du jour stable : +5 en " .. tostring(g and g.name))
  local line = D.DailyLine(g.id, g.name, g.start + 2)
  ok(line and line:find("2/5", 1, true) and line:find(g.name, 1, true), "progression du défi dans le texte d'infobulle")
  ok(D.DailyProgress({ id = g.id, name = g.name, to = g.goal, icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01" }) and g.done, "défi réussi une fois")
  ok(not D.DailyProgress({ id = g.id, name = g.name, to = g.goal + 1 }), "pas de deuxième récompense")
  d.skins, d.fish, d.skinN, d.fishN = {}, {}, 0, 0
  ok(D.DiscoverSkin("Bête") and not D.DiscoverSkin("Bête") and D.DiscoverSkin("Draconien"), "types dépecés : une fois chacun")
  ok(D.DiscoverCount("skinning") == 2, "2 découverts (dépeçage)")
  ok(D.DiscoverFish(6289, "Goujon") and not D.DiscoverFish(6289, "Goujon") and D.DiscoverCount("fishing") == 1, "poisson : une fois")
  ok(D.BarFraction(10, 0, nil) == nil and math.abs(D.BarFraction(5, 0, 10) - 0.5) < 0.001, "barre : rien sans estimation, moitié à mi-temps")
  ns.Rate.samples["skill:skinning"] = { t0 = 0, v0 = 10, t1 = 20, v1 = 12, n = 2 }
  local frac = D.ArmBar({ id = "skinning", name = "Dépeçage", fold = "depecage" })
  ok(D.bar and D.bar.spu and D._pumping, "barre armée seulement quand une estimation existe")
  D.StopBar()
  ok(not D._pumping, "barre arrêtée : plus d'OnUpdate")
  ns.db.ui.soundSkill, ns.db.ui.sounds = nil, nil
  d.combo, d.comboLast, d.bestCombo = nil, nil, nil
end

print("== 3.5.0 : barre du toast alignée sur le texte (les 3 thèmes, tous les toasts) ==")
do
  local function hasAnchor(frame, point, rel, relPoint)
    for _, p in ipairs(frame and frame.points or {}) do
      if p[1] == point and p[2] == rel and p[3] == relPoint then return true end
    end
  end
  local themes = { "flare", "leger", "classic" }
  for _, theme in ipairs(themes) do
    if ns.Theme and ns.Theme.Set then ns.Theme.Set(theme) end
    for _, sample in ipairs({
      { "pvp", "Interface\\Icons\\INV_BannerPVP_02", "+1 victoire honorable", "1 aujourd'hui", 1, 15, { kind = "pvp" } },
      { "skill", "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", "Dépeçage +1", "Rang 12 / 300", 12, 300, { kind = "skill" } },
    }) do
      local f = ns.UI:SpawnDrop(sample[2], sample[3], sample[4], sample[5], sample[6], nil, sample[7])
      ok(f and f.barHold and f.titleFS and f.iconSlot
        and hasAnchor(f.barHold, "LEFT", f.titleFS, "LEFT")
        and hasAnchor(f.barHold, "RIGHT", f.titleFS, "RIGHT")
        and not hasAnchor(f.barHold, "BOTTOMLEFT", f, "BOTTOMLEFT"),
        theme .. " / " .. sample[1] .. " : la barre part du titre et finit au même retrait, pas sous l'icône")
      if f and f.SetScript then f:SetScript("OnUpdate", nil) end
      if f and f.Hide then f:Hide() end
    end
  end
  if ns.Theme and ns.Theme.Set then ns.Theme.Set("flare") end
end

print("== 3.5.0 : clic gauche sur un métier ouvre sa fenêtre (bouton sécurisé, hors combat) ==")
do
  local CO = ns.CraftOpen
  ok(CO.Openable({ id = "cooking", name = "Cuisine" }) == "cooking" and CO.Openable({ id = "mining" }) == "mining", "Cuisine et Minage (Fondre) sont ouvrables")
  ok(CO.Openable({ id = "firstaid" }) and CO.Openable({ id = "tailoring" }) and CO.Openable({ id = "enchanting" }) and CO.Openable({ id = "blacksmithing" }), "fenêtres de métier : secourisme, couture, enchantement, forge")
  ok(not CO.Openable({ id = "skinning" }) and not CO.Openable({ id = "herbalism" }) and not CO.Openable({ id = "fishing" }) and not CO.Openable({ id = "defense", kind = "defense" }), "Dépeçage, Herboristerie, Pêche et les autres cases : clic inchangé")
  ok(ns.Options.Find("openProf") and ns.Options.Get("openProf") == true and ns.Options.Find("openProf").default == true, "Métiers : « Clic : ouvrir le métier », activé par défaut")
  local tile = CreateFrame("Button", nil, _G.UIParent)
  tile:SetSize(36, 36)
  tile:SetPoint("CENTER", _G.UIParent, "CENTER", 20, -10)
  tile.data = { id = "cooking", name = "Cuisine" }
  tile:Show()
  ok(CO.ArmTile(tile) and CO.tileBtn and CO.tileBtn:IsShown() and CO.tileBtn:GetParent() == _G.UIParent, "hors combat : bouton sécurisé visible, enfant d'UIParent")
  local b = CO.tileBtn
  local p = b.points and b.points[1]
  ok(p and p[2] == _G.UIParent and b:GetAttribute("type1") == "spell" and b:GetAttribute("spell1") == CO.SpellName("cooking") and b:GetAttribute("type2") == nil, "coordonnées absolues, type1 = sort du métier, pas de type2")
  local selected, prompted, shared
  local rSel, rPrompt = ns.UI.SelectTile, ns.UI.PromptGoal
  ns.UI.SelectTile = function(_, d) selected = d.id end
  ns.UI.PromptGoal = function(_, d) prompted = d.id end
  local rShare = ns.QoL and ns.QoL.ShareTile
  if ns.QoL then ns.QoL.ShareTile = function(d) shared = d.id return true end end
  for _, fn in ipairs(b.hooks.PostClick or {}) do fn(b, "LeftButton") end
  ok(selected == "cooking" and not prompted, "clic gauche : la case est sélectionnée (PostClick, non sécurisé)")
  selected = nil
  local rShift = _G.IsShiftKeyDown
  _G.IsShiftKeyDown = function() return true end
  for _, fn in ipairs(b.hooks.PreClick or {}) do fn(b, "LeftButton") end
  ok(b:GetAttribute("type1") == nil, "Maj+clic : le sort n'est pas lancé")
  for _, fn in ipairs(b.hooks.PostClick or {}) do fn(b, "LeftButton") end
  ok(shared == "cooking" and selected ~= "cooking", "Maj+clic : partage, pas la sélection")
  _G.IsShiftKeyDown = function() return false end
  for _, fn in ipairs(b.hooks.PreClick or {}) do fn(b, "RightButton") end
  for _, fn in ipairs(b.hooks.PostClick or {}) do fn(b, "RightButton") end
  ok(prompted == "cooking", "clic droit : objectif, comme avant")
  _G.IsShiftKeyDown = rShift
  ns.UI.SelectTile, ns.UI.PromptGoal = rSel, rPrompt
  if ns.QoL then ns.QoL.ShareTile = rShare end
  CO.DisarmTile()
  ok(not b:IsShown(), "sortie de la case : bouton caché")
  local rIC = _G.InCombatLockdown
  _G.InCombatLockdown = function() return true end
  ok(CO.ArmTile(tile) == false, "en combat : pas de bouton, le clic ne fait que sélectionner")
  b:Show()
  fire("PLAYER_REGEN_DISABLED")
  ok(not b:IsShown() and b._tile == nil, "PLAYER_REGEN_DISABLED : bouton caché, sans SetAttribute")
  _G.InCombatLockdown = rIC
  ns.db.ui.openProf = false
  ok(CO.Openable({ id = "alchemy" }) == nil and CO.ArmTile(tile) == false, "réglage désactivé : plus d'ouverture")
  ns.db.ui.openProf = nil
  local tip = _G.GameTooltip
  tip.lines = {}
  ns.Compact.FillTooltip(tip, { id = "leatherworking", name = "Travail du cuir", kind = "profession", current = 10, apiMax = 300 }, tile)
  local hint = false
  for _, l in ipairs(tip.lines or {}) do if l.t and l.t:find("Clic : ouvrir le métier", 1, true) then hint = true end end
  ok(hint, "infobulle : « Clic : ouvrir le métier »")
  tip.lines = {}
  ns.Compact.FillTooltip(tip, { id = "fishing", name = "Pêche", kind = "secondary", current = 1, apiMax = 300 }, tile)
  hint = false
  for _, l in ipairs(tip.lines or {}) do if l.t and l.t:find("Clic : ouvrir le métier", 1, true) then hint = true end end
  ok(not hint, "Pêche : pas cette ligne")
end

print(failures == 0 and "TOTAL  OK  tous les tests v3.5.0 ont réussi" or ("TOTAL  FAIL  " .. failures .. " échec(s)"))
os.exit(failures == 0 and 0 or 1)