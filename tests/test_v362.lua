-- Tests hors jeu 3.6.2 : détail natif des armes (toucher / crit / coups déviés) en court.
-- PosGuard, Edit Mode ↔ Réglages 2.0, mode calme, profil par personnage,
-- Progress.lua (session, historique, série, objectif, succès, coins, partage, récap).
-- Harnais repris tel quel de test_v340.lua (lignes 17-739).
-- Harnais repris de test_v360.lua (lignes 5-734). /tmp/lua-5.1.5/src/lua tests/test_v362.lua
-- /tmp/lua-5.1.5/src/lua tests/test_v360.lua

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
  function f:GetButtonState() return self._bstate or "NORMAL" end
  function f:SetDrawLayer(layer, sub) self.layer, self.sublayer = layer, sub end
  function f:LockHighlight() self._hlLocked = true end
  function f:UnlockHighlight() self._hlLocked = nil end
  function f:SetVertexColor(r, g, b, a) self._vc = { r, g, b, a } end
  function f:GetVertexColor() local c = self._vc if c then return c[1], c[2], c[3], c[4] end return 1, 1, 1, 1 end
  function f:SetTexture(p) self._texSet = p if _G.__missingTex and type(p) == "string" and p:find(_G.__missingTex, 1, true) then return false end return true end
  function f:SetDesaturated(v) self.desat = v end
  function f:SetAtlas(a) self._atlasSet = a return true end
  function f:GetTexture() return self._tex end
  function f:GetAtlas() return self._atlas end
  function f:SetColorTexture(r, g, b, a) self._colorTex = { r, g, b, a } end
  function f:SetTexCoord(...) self._tcoord = { ... } end
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

-- 3.6.2 : client français (comme chez Arnaud)
_G.GetLocale = function() return "frFR" end
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

-- ===========================================================================

-- ===========================================================================
local NL = ns.NativeLook
local C = ns.Compact
local function setLang(l) ns.db.ui = ns.db.ui or {} ns.db.ui.lang = l DropamineDB.ui.lang = l end
local function joined(list) local t = {} for i, l in ipairs(list) do t[i] = (type(l) == "table") and l[1] or l end return table.concat(t, "\n") end
local function strip(s) return (tostring(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

print("== 3.6.2 : lecture des chiffres (FR)")
local FR = {
  sections = {
    { title = "Adversaire de niveau égal", lines = {
      "Chances de toucher et d'éviter que vos attaques soient esquivées ou parées : -0.96%",
      "Chances de coup critique : -0.96%" } },
    { title = "Contre les boss de raid", lines = {
      "Chances de toucher et d'éviter que vos attaques soient esquivées ou parées : -7.16%",
      "Chances de coup critique : -7.16%",
      "Les coups déviés surviennent 100% du temps et leurs dégâts sont réduits de 89%." } },
  } }
local p = NL.ParseCombat(FR)
ok(p and p.same and p.same.hit == "-0.96%" and p.same.crit == "-0.96%", "FR : même niveau toucher / crit -0.96%")
ok(p and p.boss and p.boss.hit == "-7.16%" and p.boss.crit == "-7.16%", "FR : boss toucher / crit -7.16%")
ok(p and p.glance and p.glance.freq == "100%" and p.glance.red == "-89%", "FR : coups déviés 100% · -89%")

print("== 3.6.2 : lecture des chiffres (EN)")
local EN = {
  sections = {
    { title = "Against Equal Level Opponent", lines = {
      "Chance to hit and to avoid your attacks being dodged or parried: -0.96%",
      "Critical strike chance: -1.20%" } },
    { title = "Against Raid Bosses", lines = {
      "Chance to hit and to avoid your attacks being dodged or parried: -7.16%",
      "Critical strike chance: -7.16%",
      "Glancing blows occur 100% of the time and their damage is reduced by 89%." } },
  } }
local pe = NL.ParseCombat(EN)
ok(pe and pe.same and pe.same.hit == "-0.96%" and pe.same.crit == "-1.20%", "EN : equal level hit -0.96% / crit -1.20%")
ok(pe and pe.boss and pe.boss.hit == "-7.16%" and pe.boss.crit == "-7.16%", "EN : raid boss -7.16%")
ok(pe and pe.glance and pe.glance.freq == "100%" and pe.glance.red == "-89%", "EN : glancing 100% · -89%")
ok(NL.IsHeaderText("Against Equal Level Opponent") and NL.IsHeaderText("Against Raid Bosses"), "EN : en-têtes reconnus")

print("== 3.6.2 : texte natif coloré, coupé, signes typographiques ; lignes illisibles abandonnées")
local odd = { sections = {
  { title = "|cffffffffAdversaire de niveau égal|r", lines = {
    "|cffffd100Chances de toucher|r et d'éviter que vos attaques soient esquivées ou |cffffd100parées|r : \226\136\1460,96\194\160%",
    "Chances de coup critique : bientôt" } },
  { title = "Contre les boss de raid", lines = {
    "Les coups déviés surviennent 100% du temps",
    "et leurs dégâts sont réduits de 89%." } } } }
local po = NL.ParseCombat(odd)
ok(po and po.same and po.same.hit == "-0,96%", "couleurs ôtées, moins typographique et virgule lus tels quels (" .. tostring(po and po.same and po.same.hit) .. ")")
ok(po and po.same and po.same.crit == nil, "ligne sans chiffre : abandonnée")
ok(po and po.glance and po.glance.freq == "100%" and po.glance.red == "-89%", "phrase coupée en deux lignes : recollée")
ok(NL.ParseCombat({ sections = { { title = "Récompenses au rang 1", lines = { "Rien ici" } } } }) == nil, "rien à lire : nil")

print("== 3.6.2 : sortie courte")
setLang("fr")
local fr = strip(joined(NL.CompactCombatLines(p)))
ok(fr == "Toucher & crit (même niv.) : -0.96%\nToucher & crit (boss) : -7.16%\nCoups déviés : 100% · -89% dégâts", "FR compact :\n" .. fr)
local tw = NL.CompactCombatLines(p)[1]
ok(tw:find("^|cffffd100Toucher & crit") and tw:find("|cffffffff%-0.96%%|r$"), "deux tons : libellé or, valeur blanche")
local fr2 = strip(joined(NL.CompactCombatLines(pe)))
ok(fr2:find("Toucher / crit (même niv.) : -0.96% / -1.20%", 1, true), "valeurs différentes : « toucher / crit » avec les deux")
local only = strip(joined(NL.CompactCombatLines(po)))
ok(only == "Toucher (même niv.) : -0,96%\nCoups déviés : 100% · -89% dégâts", "une seule valeur lue : une seule affichée")
setLang("en")
local en = strip(joined(NL.CompactCombatLines(p)))
ok(en == "Hit & crit (same lvl): -0.96%\nHit & crit (boss): -7.16%\nGlancing: 100% · -89% dmg", "EN compact :\n" .. en)
ok(strip(joined(NL.CompactCombatLines(pe))):find("Hit / crit (same lvl): -0.96% / -1.20%", 1, true), "EN : hit / crit with both values")
setLang("fr")

print("== 3.6.2 : lecture du volet natif ouvert (lecture seule)")
-- Volet « Comp. » natif de Forever : liste à gauche, détail à droite.
local pane = newObj("Frame", "ForeverSkillsPane", _G.CharacterFrame)
pane._abs = { l = 100, r = 700, t = 880, b = 400 }
local function fs(parent, text, l, t, w)
  local f = newObj("FontString", nil, parent)
  parent.regions[#parent.regions + 1] = f
  f.text = text
  f._abs = { l = l, r = l + (w or 180), t = t, b = t - 14 }
  return f
end
local list = newObj("Frame", nil, pane) list._abs = { l = 110, r = 450, t = 860, b = 420 }
fs(list, "Compétences d'armes", 120, 700)
fs(list, "Bâtons", 118, 680, 120)
fs(list, "58 / 125", 330, 680, 60)
fs(list, "Dagues", 118, 650, 120)
local det = newObj("Frame", nil, pane) det._abs = { l = 480, r = 690, t = 860, b = 420 }
fs(det, "Bâtons", 545, 840, 100)
fs(det, "58 / 125", 560, 815, 60)
local descFS = fs(det, "Une compétence d'arme plus élevée augmente vos chances de toucher.", 492, 790)
local b1 = newObj("Button", nil, det) b1._abs = { l = 495, r = 675, t = 760, b = 736 }
fs(b1, "Adversaire de niveau égal", 515, 754)
fs(det, FR.sections[1].lines[1], 490, 725)
fs(det, FR.sections[1].lines[2], 490, 690)
local b2 = newObj("Button", nil, det) b2._abs = { l = 495, r = 675, t = 670, b = 646 }
fs(b2, "Contre les boss de raid", 515, 664)
fs(det, FR.sections[2].lines[1], 490, 635)
fs(det, FR.sections[2].lines[2], 490, 600)
fs(det, FR.sections[2].lines[3], 490, 575)
local function snap(o, seen, out)
  seen = seen or {} out = out or {}
  if seen[o] then return out end
  seen[o] = true
  local hk = 0 for _, l in pairs(o.hooks or {}) do hk = hk + #l end
  local sc = 0 for _ in pairs(o.scripts or {}) do sc = sc + 1 end
  out[#out + 1] = tostring(o.text) .. "|" .. tostring(o.shown) .. "|" .. tostring(o.alpha) .. "|" .. #(o.points or {}) .. "|" .. hk .. "|" .. sc .. "|" .. tostring(o.parent)
  for _, c in ipairs(o.children or {}) do snap(c, seen, out) end
  for _, r in ipairs(o.regions or {}) do snap(r, seen, out) end
  return out
end
local before = table.concat(snap(pane), "\n")
local cdb = ns.CharDB()
cdb.nativeDetail, cdb.nativeDetailIds = nil, nil
_G.CharacterFrame.shown = false
ok(NL.ReadIfShown(true) == nil, "fiche fermée : rien n'est lu")
_G.CharacterFrame.shown = true
_G.InCombatLockdown = function() return true end
ok(NL.ReadIfShown(true) == nil, "en combat : rien n'est lu")
_G.InCombatLockdown = function() return false end
local r = NL.ReadIfShown(true)
ok(r and r.skill == "Bâtons", "titre du détail natif lu : " .. tostring(r and r.skill))
ok(r and r.id == "staves", "identifiant du catalogue mémorisé : " .. tostring(r and r.id))
ok(r and #r.desc == 1 and r.desc[1]:find("^Une compétence d'arme"), "description native : une ligne (la liste de gauche est ignorée)")
ok(r and r.combat and r.combat.boss and r.combat.boss.crit == "-7.16%" and r.combat.glance.red == "-89%", "chiffres lus dans le volet natif")
ok(cdb.nativeDetail and cdb.nativeDetail["batons"] == r and cdb.nativeDetailIds.staves == "batons", "mémorisé par nom replié + index par identifiant")
ok(table.concat(snap(pane), "\n") == before, "volet natif intact : aucun texte, ancre, crochet ni script modifié")
ok(NL.ReadIfShown() == nil, "deuxième lecture dans la seconde : ignorée (cadence)")

print("== 3.6.2 : retrouvé depuis la case, quelle que soit la langue de l'addon")
local tileFR = { kind = "melee", id = "staves", name = "Mêlée", skillName = "Bâtons", catName = "Bâtons", current = 58, apiMax = 125, combatTile = true, inTotal = true }
local tileEN = { kind = "melee", id = "staves", name = "Melee", skillName = "Staves", catName = "Bâtons", current = 58, apiMax = 125, combatTile = true, inTotal = true }
ok(NL.CachedFor(tileFR) == r, "case FR → détail lu")
ok(NL.CachedFor(tileEN) == r, "case EN sur client FR (nom « Staves ») → détail lu par identifiant")
cdb.nativeDetail = { ["batons"] = { skill = "Bâtons", desc = {}, sections = FR.sections } }
cdb.nativeDetailIds = nil
ok(NL.CachedFor({ kind = "melee", id = "staves", skillName = "Staves", name = "Melee" }) ~= nil, "ancienne capture (sans index) retrouvée par identifiant")
ok(#NL.CombatLinesFor({ id = "staves", skillName = "Staves" }) == 3, "ancienne capture : chiffres relus à l'affichage (3 lignes)")
cdb.nativeDetail, cdb.nativeDetailIds = nil, nil
NL.ReadIfShown(true)

print("== 3.6.2 : infobulle de la case")
local function tip(d)
  local m = C.TooltipModel(d)
  local t = {}
  for _, l in ipairs(m.lines) do t[#t + 1] = strip(l[1]) end
  return table.concat(t, "\n"), m
end
setLang("fr")
local tf = tip(tileFR)
ok(tf:find("\nCombat\nToucher & crit (même niv.) : -0.96%\nToucher & crit (boss) : -7.16%\nCoups déviés : 100% · -89% dégâts", 1, true), "FR : section Combat courte")
ok(not tf:find("esquivées", 1, true) and not tf:find("surviennent", 1, true), "FR : aucune phrase native à rallonge")
ok(not tf:find("Adversaire de niveau", 1, true) and not tf:find("Contre les boss", 1, true), "FR : plus d'en-têtes natifs bruts")
local _, nDesc = tf:gsub("plus élevée augmente", "")
ok(nDesc <= 1, "description pas en double")
io.write("--- infobulle FR ---\n" .. tf .. "\n")
setLang("en")
local te = tip(tileEN)
ok(te:find("\nCombat\nHit & crit (same lvl): -0.96%\nHit & crit (boss): -7.16%\nGlancing: 100% · -89% dmg", 1, true), "EN : compact Combat section")
ok(not te:find("Une compétence d'arme", 1, true), "EN sur client FR : pas de description native française")
io.write("--- infobulle EN ---\n" .. te .. "\n")
setLang("fr")
_G.CharacterFrame.shown = false
pane.shown = false
local tn = tip(tileFR)
ok(tn:find("Toucher & crit (boss) : -7.16%", 1, true), "fiche fermée : valeurs mémorisées toujours affichées")
local tb = tip({ kind = "melee", id = "daggers", name = "Mêlée", skillName = "Dagues", current = 1, apiMax = 125 })
ok(not tb:find("\nCombat\n", 1, true), "compétence jamais vue dans le volet natif : pas de section vide")
ok(errs() == 0, "aucune erreur UI")


print("== 3.6.2 (retour en jeu) : segments colorés en plusieurs FontStrings, comme le volet de Forever")
skills[#skills + 1] = { name = "Armes d'hast", isHeader = false, rank = 136, maxRank = 160 }
local G, Wt = "|cffffd100", "|cffffffff"
-- variant "bloc" : un FontString or sur plusieurs lignes (« Chances de … parées : x% »)
-- et un FontString blanc à droite, qui commence à la même hauteur ; idem
-- pour les coups déviés (« surviennent » en or, à droite).
-- variant "segments" : chaque fragment coloré est un FontString, rangées
-- décalées de ±1 px.
local function nativePane(name, title, rank, same, boss, variant)
  local root = newObj("Frame", name, _G.CharacterFrame)
  root._abs = { l = 100, r = 760, t = 880, b = 380 }
  local det = newObj("Frame", nil, root) det._abs = { l = 515, r = 735, t = 860, b = 400 }
  local lst = newObj("Frame", nil, root) lst._abs = { l = 140, r = 480, t = 860, b = 400 }
  fs(lst, title, 160, 520, 120) fs(lst, rank, 330, 520, 60)
  fs(det, title, 580, 845, 100)
  fs(det, rank, 590, 820, 60)
  fs(det, Wt .. "Une compétence d'arme plus élevée augmente vos chances de toucher.|r", 525, 795)
  local y = 770
  local function header(text)
    local b = newObj("Button", nil, det) b._abs = { l = 530, r = 710, t = y, b = y - 24 }
    fs(b, text, 555, y - 6)
    y = y - 34
  end
  local function hitcrit(v)
    if variant == "bloc" then
      fs(det, G .. "Chances de|r\n\n" .. G .. "parées|r" .. G .. " : " .. v .. "|r", 525, y)
      fs(det, Wt .. "toucher|r " .. Wt .. "et d'éviter que\nvos attaques soient esquivées ou|r", 590, y)
      y = y - 45
      fs(det, G .. "Chances de|r", 525, y)
      fs(det, Wt .. "coup critique : " .. v .. "|r", 585, y)
      y = y - 25
    else
      fs(det, G .. "Chances de|r", 525, y) fs(det, Wt .. "toucher|r", 590, y + 1) fs(det, Wt .. "et d'éviter que|r", 640, y)
      y = y - 12
      fs(det, Wt .. "vos attaques soient|r", 525, y) fs(det, G .. "esquivées|r", 620, y - 1) fs(det, Wt .. "ou|r", 680, y)
      y = y - 12
      fs(det, G .. "parées|r", 525, y + 1) fs(det, Wt .. " : " .. v .. "|r", 565, y)
      y = y - 20
      fs(det, G .. "Chances de|r", 525, y) fs(det, Wt .. "coup critique|r", 590, y - 1) fs(det, Wt .. " : " .. v .. "|r", 660, y)
      y = y - 25
    end
  end
  header("Adversaire de niveau égal") hitcrit(same)
  header("Contre les boss de raid") hitcrit(boss)
  if variant == "bloc" then
    fs(det, Wt .. "Les coups déviés|r\n" .. Wt .. "100% du temps et leurs dégâts\nsont réduits de 89%.|r", 525, y)
    fs(det, G .. "surviennent|r", 640, y)
  else
    fs(det, Wt .. "Les coups déviés|r", 525, y) fs(det, G .. "surviennent|r", 610, y + 1)
    fs(det, Wt .. "100% du temps et leurs dégâts|r", 525, y - 12)
    fs(det, Wt .. "sont réduits de 89%.|r", 525, y - 24)
  end
  return root
end
setLang("fr")
_G.CharacterFrame.shown = true
pane.shown = false
local cases = {
  { "Armes d'hast", "136 / 160", "-0.96%", "-7.16%", { kind = "melee", id = "polearms", name = "Mêlée", skillName = "Armes d'hast", current = 136, apiMax = 160 } },
  { "Combat farouche", "158 / 160", "-0.08%", "-6.28%", { kind = "feral", id = "feral", name = "Combat farouche", skillName = "Combat farouche", current = 158, apiMax = 160 } },
}
for _, variant in ipairs({ "bloc", "segments" }) do
  for _, c in ipairs(cases) do
    local root = nativePane("NativeTest_" .. variant .. "_" .. c[1]:gsub("%W", ""), c[1], c[2], c[3], c[4], variant)
    local rr = NL.ReadIfShown(true)
    local cb = rr and rr.combat
    local tag = c[1] .. " (" .. variant .. ")"
    ok(rr and rr.skill == c[1], tag .. " : titre lu (" .. tostring(rr and rr.skill) .. ")")
    ok(cb and cb.same and cb.same.hit == c[3] and cb.same.crit == c[3], tag .. " : même niveau " .. c[3] .. " / " .. c[3] .. " (lu " .. tostring(cb and cb.same and cb.same.hit) .. " / " .. tostring(cb and cb.same and cb.same.crit) .. ")")
    ok(cb and cb.boss and cb.boss.hit == c[4] and cb.boss.crit == c[4], tag .. " : boss " .. c[4] .. " / " .. c[4] .. " (lu " .. tostring(cb and cb.boss and cb.boss.hit) .. " / " .. tostring(cb and cb.boss and cb.boss.crit) .. ")")
    ok(cb and cb.glance and cb.glance.freq == "100%" and cb.glance.red == "-89%", tag .. " : coups déviés 100% · -89% (lu " .. tostring(cb and cb.glance and cb.glance.freq) .. " · " .. tostring(cb and cb.glance and cb.glance.red) .. ")")
    local d = c[5]
    local want = "Toucher & crit (même niv.) : " .. c[3] .. "\nToucher & crit (boss) : " .. c[4] .. "\nCoups déviés : 100% · -89% dégâts"
    local got = strip(joined(NL.CombatLinesFor(d)))
    ok(got == want, tag .. " : infobulle\n" .. got)
    root.shown = false
  end
end
-- Retour en jeu tel quel : l'ancien analyseur donnait « Crit (même niv.) » seul
-- et « Coups déviés : -7.16% · -89% » ; on vérifie les deux défauts.
do
  local tf2 = tip({ kind = "melee", id = "polearms", name = "Mêlée", skillName = "Armes d'hast", current = 136, apiMax = 160, combatTile = true, inTotal = true })
  ok(not tf2:find("Coups déviés : -7.16%", 1, true) and tf2:find("Coups déviés : 100% · -89% dégâts", 1, true), "plus de « Coups déviés : -7.16% »")
  ok(tf2:find("Toucher & crit (même niv.) : -0.96%", 1, true) and not tf2:find("\nCrit (même niv.)", 1, true), "toucher présent, plus de « Crit » seul")
  io.write("--- infobulle Armes d'hast (segments) ---\n" .. tf2 .. "\n")
end


print("== 3.6.2 : XP de repos (z dorés + fiole) sur la case Niveau")
local R = ns.Rested
ok(R ~= nil, "Rested.lua chargé")
ok(io.open(addonDir .. "/Dropamine.toc"):read("*a"):find("ProgressUI.lua\nRested.lua", 1, true), ".toc : Rested.lua après ProgressUI.lua")
-- correspondance repos → nombre de z
ok(R.ZCount(nil, 8000) == 0 and R.ZCount(0, 8000) == 0, "pas de repos : 0 z")
ok(R.ZCount(1, 8000) == 1 and R.ZCount(1999, 8000) == 1, "< 25 % d'un niveau : 1 z")
ok(R.ZCount(2000, 8000) == 2 and R.ZCount(5999, 8000) == 2, "25-75 % : 2 z")
ok(R.ZCount(6000, 8000) == 3 and R.ZCount(12000, 8000) == 3, "≥ 75 % (jusqu'à 150 %) : 3 z")
local tickers = {}
_G.C_Timer.NewTicker = function(d, fn)
  local tk = { d = d, fn = fn, cancelled = false }
  function tk:Cancel() self.cancelled = true end
  tickers[#tickers + 1] = tk
  return tk
end
local restXP, resting, lvl = 4000, true, 25
_G.GetXPExhaustion = function() return restXP end
_G.IsResting = function() return resting end
_G.UnitLevel = function() return lvl end
_G.UnitXPMax = function() return 8000 end
setLang("fr")
ns.db.ui.restedAnim = nil
local function lvlTile()
  for _, t in ipairs(UI.embed and UI.embed.tiles or {}) do if t.data and t.data.kind == "level" then return t end end
end
UI:Refresh(true)
local lt = lvlTile()
ok(lt ~= nil, "case Niveau présente")
local function apply() R.Apply(lt) return lt._restState end
local st = apply()
ok(st.z == 2 and st.liquid == "wave" and math.abs(st.frac - 4000 / 12000) < 1e-9, "repos 4000/8000 en zone de repos : 2 z, fiole qui se remplit (1/3)")
local zs = lt._rzz and lt._rzz.z or {}
ok(lt._rzz and lt._rzz:IsShown() and zs[1]:IsShown() and zs[2]:IsShown() and not zs[3]:IsShown(), "2 z visibles, le 3e caché")
ok(zs[1].ag and zs[1].ag.playing and zs[2].ag.playing and not zs[3].ag.playing, "z animés (AnimationGroup) ; le caché arrêté")
local tr = zs[2].ag and zs[2].ag:Find("Translation")
ok(tr and tr.offset and tr.offset[2] > 0 and tr.delay == R.Z_STAGGER, "z : montée en translation, décalée (" .. tostring(tr and tr.delay) .. " s)")
ok(zs[1].fs.text == "z" and zs[1]._alphaSet ~= false, "z : texte « z »")
local lf = lt._rliq
local H = lt.icon:GetHeight()
local CH, CA = R.LIQ.charge, R.LIQ.calme
local function settle(l)
  l = l or lt._rliq
  for _, x in ipairs({ l.body, l.wave, l.calm }) do if x.fadeAg and x.fadeAg.playing then x.fadeAg:Finish() end end
end
-- 3.6.2 (retour Arnaud n° 2) : surface EXACTEMENT proportionnelle, corps fixe
ok(lf and lf:IsShown() and lf.body:IsShown() and lf.bodyH == math.floor(H * (4000 / 12000) + 0.5), "fiole : hauteur = repos / (1,5 × niveau) × portrait (" .. tostring(lf and lf.bodyH) .. " px sur " .. tostring(H) .. ")")
ok(lf.wave:IsShown() and R.driver and R.driver:IsShown() and R.driver.scripts.OnUpdate == R.DriverTick, "vague : pilote de défilement actif (vague visible)")
ok(lf.waveAg == nil and lf.bobAg == nil and lf.wave.bobAg == nil, "plus de balancement vertical (le liquide ne monte/descend plus)")
ok(lf.body.parent == lt and lf.wave.parent == lt and lt._rzz.parent == lt, "dessin sur la case (hérite de son alpha : fondu, opacité)")
ok(lf.body.layer == "ARTWORK" and lf.body.sublayer > (lt.icon.sublayer or 0) and lf.wave.layer == "ARTWORK", "liquide : textures de la case au-dessus de l'icône, sous le biseau et le chiffre (OVERLAY)")
ok(lt._rzz.scripts.OnUpdate == nil and (lf.wave.scripts == nil or lf.wave.scripts.OnUpdate == nil), "z et textures : aucun OnUpdate (seul le pilote limité en a un)")
ok(lf.mode == "charge" and lf.body.alpha == CH.body and lf.wave.alpha == CH.wave and not lf.calm:IsShown(), "charge : liquide " .. CH.body .. ", vague " .. CH.wave .. " (allure calme cachée)")
do
  local c = lf.wave._vc
  ok(c and c[1] > R.LIQ_COLOR[1] and c[2] > R.LIQ_COLOR[2], "charge : surface de la vague plus claire")
  -- défilement horizontal réel + aucun trou au fond, à chaque phase
  local ir = __rect(lt.icon)
  local us, gaps, outs, moved, surf = {}, 0, 0, 0, 0
  local u0 = lf.wave.u
  local frames0 = R.drive.steps
  for k = 1, 60 do
    R.DriverTick(R.driver, 0.04)
    local br, wr = __rect(lf.body), __rect(lf.wave)
    if math.abs(br.b - ir.b) > 0.01 or math.abs((br.t - br.b) - lf.bodyH) > 0.01 then gaps = gaps + 1 end
    if wr.b < ir.b - 0.01 or wr.t > ir.t + 0.01 or wr.l < ir.l or wr.r > ir.r then outs = outs + 1 end
    if wr.b > br.t + 0.01 then gaps = gaps + 1 end                     -- la vague recouvre le haut du corps
    if math.abs(lf.wave.surfaceY - lf.bodyH) > 0.01 then surf = surf + 1 end
    local tc = lf.wave._tcoord
    if tc and tc[1] ~= us[#us] then moved = moved + 1 end
    us[#us + 1] = tc and tc[1]
  end
  ok(gaps == 0, "aucun trou au fond : corps ancré au bas du portrait à toutes les phases (60 pas)")
  ok(outs == 0 and surf == 0, "vague dans le portrait, ligne moyenne = surface du liquide, à toutes les phases")
  ok(moved >= 50 and R.drive.steps - frames0 >= 50, "vague : les coordonnées de texture défilent horizontalement (" .. moved .. " pas sur 60)")
  local tc = lf.wave._tcoord
  ok(tc and math.abs((tc[2] - tc[1]) - R.WAVE_U) < 1e-9 and tc[1] >= 0 and tc[2] <= 1, "vague : fenêtre d'une période, sans dépasser la texture")
  local per = 2.4 * 0.5 / CH.period   -- 2,4 s à 0,04 s/pas, en fraction de texture
  ok(math.abs(((u0 + per) % R.WAVE_U) - lf.wave.u) < 1e-6, "charge : une période de vague en " .. CH.period .. " s")
  -- limité : 30 images/s en charge (un pas < 1/30 s ne fait rien)
  local st0 = R.drive.steps
  R.DriverTick(R.driver, 0.01) R.DriverTick(R.driver, 0.01)
  ok(R.drive.steps == st0, "pilote limité à 30 images/s")
  R.DriverTick(R.driver, 0.02)
end
-- hors repos, il reste du repos : liquide LÉGER, presque immobile (fondu)
resting = false
st = apply()
ok(st.liquid == "static" and lf.mode == "calme" and lf.calm:IsShown(), "hors repos : allure calme (petite vague lente)")
ok(lf.wave.fadeAg and lf.wave.fadeAg.playing and lf.wave.fadeAnim.fromAlpha == CH.wave and lf.wave.fadeAnim.toAlpha == 0 and lf.wave.fadeAnim.duration == R.FADE_TIME, "transition douce : la vague « charge » s'efface en " .. R.FADE_TIME .. " s")
ok(lf.calm.fadeAnim and lf.calm.fadeAnim.fromAlpha == 0 and lf.calm.fadeAnim.toAlpha == CA.wave and lf.body.fadeAnim.fromAlpha == CH.body and lf.body.fadeAnim.toAlpha == CA.body, "transition douce : calme 0 → " .. CA.wave .. ", liquide " .. CH.body .. " → " .. CA.body)
settle()
ok(not lf.wave:IsShown() and lf.body.alpha == CA.body and lf.calm.alpha == CA.wave, "hors repos (fondu fini) : vague « charge » cachée, liquide léger " .. CA.body)
do
  ok(lf.calm.height <= CA.h and CA.h < CH.h and CA.period >= 8 and CA.step >= 0.1 and CA.body < CH.body and CA.wave < CH.wave,
    "calme : vague " .. CA.h .. " px, " .. CA.period .. " s, 10 images/s, alpha plus bas")
  ok(lf.bodyH == math.floor(H * (4000 / 12000) + 0.5), "même hauteur de liquide dans les deux allures (pas de saut)")
  local u0 = lf.calm.u
  local ir = __rect(lt.icon)
  local gaps = 0
  for k = 1, 20 do R.DriverTick(R.driver, 0.1) local br = __rect(lf.body) if math.abs(br.b - ir.b) > 0.01 then gaps = gaps + 1 end end
  ok(gaps == 0 and lf.calm.u ~= u0 and math.abs(((u0 + 2 * 0.5 / CA.period) % R.WAVE_U) - lf.calm.u) < 1e-6, "calme : défilement lent (une période en " .. CA.period .. " s), corps toujours au fond")
end
ok(st.z == 0 and not zs[1]:IsShown() and not zs[2]:IsShown() and not zs[1].ag.playing, "hors repos : plus de z (seulement le liquide léger)")
-- hauteurs exactes : plein portrait = 150 % d'un niveau (bord bas → bord haut)
do
  local ir = __rect(lt.icon)
  local rows = {}
  for _, case in ipairs({ { 0, 0 }, { 0.15, 0.10 }, { 0.75, 0.50 }, { 1.50, 1.00 }, { 2.00, 1.00 } }) do
    for _, rs in ipairs({ true, false }) do
      resting, restXP = rs, case[1] * 8000
      st = apply() settle()
      local want = math.floor(H * case[2] + 0.5)
      local got
      if st.liquid then
        got = lf.body:IsShown() and (__rect(lf.body).t - ir.b) or 0
        local w = (lf.mode == "charge") and lf.wave or lf.calm
        ok(math.abs(got - want) < 0.01 and math.abs(w.surfaceY - want) < 0.01 and (not lf.body:IsShown() or math.abs(__rect(lf.body).b - ir.b) < 0.01),
          string.format("repos %d %% d'un niveau (%s) : surface à %s px sur %s (attendu %s = %d %% du portrait)", case[1] * 100, rs and "en repos" or "dehors", tostring(got), tostring(H), tostring(want), case[2] * 100))
      else
        ok(case[1] == 0 and not rs, "repos 0 % dehors : pas de liquide")
        got = 0
      end
      if rs then rows[#rows + 1] = string.format("%d%%→%spx", case[1] * 100, tostring(got)) end
    end
  end
  io.write("--- hauteurs mesurées (portrait " .. tostring(H) .. " px) : " .. table.concat(rows, ", ") .. "\n")
end
-- plafond atteint en zone de repos : plus de remplissage, fiole pleine, allure calme
resting, restXP = true, 12000
st = apply()
settle()
ok(st.liquid == "static" and st.frac == 1 and st.z == 3 and lf.mode == "calme" and lf.bodyH == H, "plafond (150 %) : fiole pleine, allure calme ; 3 z")
-- repos à 0 en zone de repos : le liquide commence à monter, aucun z
restXP = nil
st = apply()
ok(st.z == 0 and st.liquid == "wave" and st.frac == 0 and not zs[1]:IsShown() and lf.wave:IsShown() and not lf.body:IsShown(), "GetXPExhaustion nil en zone de repos : pas de z, vague au fond (crêtes seulement)")
resting = false
st = apply()
ok(st.z == 0 and not st.liquid and not lf:IsShown() and not lt._rzz:IsShown(), "GetXPExhaustion nil hors repos : rien")
R.DriverTick(R.driver, 0.2)
ok(not R.driver:IsShown(), "plus de vague visible : le pilote se cache (aucun OnUpdate)")
-- niveau maximum
restXP, resting, lvl = 4000, true, 60
st = apply()
ok(st.why == "max" and not lf:IsShown() and not lt._rzz:IsShown() and not R.driver:IsShown(), "niveau maximum : caché, pilote arrêté")
lvl = 25
-- combat : arrêté, caché ; reprise à la fin du combat
apply()
_G.InCombatLockdown = function() return true end
local nCF0 = R.stats.builds + R.stats.liquids
fire("PLAYER_REGEN_DISABLED")
ok(lt._restState and lt._restState.why == "combat" and not lf:IsShown() and not lt._rzz:IsShown(), "combat : caché")
ok(not R.driver:IsShown() and not zs[1].ag.playing, "combat : animations en pause (pilote caché)")
ok(R.stats.builds + R.stats.liquids == nCF0, "combat : rien n'est créé")
_G.InCombatLockdown = function() return false end
fire("PLAYER_REGEN_ENABLED")
ok(lf:IsShown() and R.driver:IsShown() and zs[1].ag.playing, "fin du combat : reprise")
-- retour en jeu : le portrait dépassait du cadre. L'icône (ancres, taille,
-- recadrage, masque) doit rester IDENTIQUE avec et sans la fiole, et le
-- liquide rester DANS l'icône, vague et balancement compris.
do
  local function iconSig()
    local ic = lt.icon
    local pts = {}
    for _, p in ipairs(ic.points or {}) do pts[#pts + 1] = table.concat({ tostring(p[1]), tostring(p[2]), tostring(p[3]), tostring(p[4]), tostring(p[5]) }, ",") end
    local r = __rect(ic) or {}
    return table.concat(pts, ";") .. "|" .. tostring(ic.width) .. "x" .. tostring(ic.height) .. "|" .. tostring(r.l) .. "," .. tostring(r.r) .. "," .. tostring(r.t) .. "," .. tostring(r.b)
      .. "|" .. tostring(ic.parent) .. "|" .. tostring(ic.layer) .. tostring(ic.sublayer) .. "|" .. tostring(ic._tcoord and table.concat(ic._tcoord, ",")) .. "|" .. tostring(ic.shown)
  end
  ns.db.ui.restedAnim = false
  R.HideTile(lt)
  UI:Refresh(true)
  local without = iconSig()
  ns.db.ui.restedAnim = nil
  for _, case in ipairs({ { true, 4000 }, { false, 4000 }, { true, 12000 }, { true, 11999 }, { false, 12000 } }) do
    resting, restXP = case[1], case[2]
    UI:Refresh(true)
    st = apply()
    ok(iconSig() == without, "icône du Niveau inchangée (repos " .. tostring(case[1]) .. ", " .. case[2] .. ")")
    local ir = __rect(lt.icon)
    local br = lf.body:IsShown() and __rect(lf.body)
    ok(not br or (br.l >= ir.l and br.r <= ir.r and br.b >= ir.b and br.t <= ir.t), "liquide dans l'icône (" .. (br and (br.b .. "→" .. br.t) or "caché") .. " ; icône " .. ir.b .. "→" .. ir.t .. ")")
    if lf.wave:IsShown() then
      local wr = __rect(lf.wave)
      ok(wr.l >= ir.l and wr.r <= ir.r and wr.b >= ir.b and wr.t <= ir.t, "vague dans l'icône (" .. wr.b .. "→" .. wr.t .. " ; icône " .. ir.b .. "→" .. ir.t .. ")")
    end
  end
  ok(lt.icon._thMask == nil or lf._mask == lt.icon._thMask, "liquide découpé par le masque de l'icône (thème)")
  resting, restXP = true, 4000
  apply()
end
-- sortie d'une zone de repos : événements et filet de 2 s
resting, restXP = true, 4000
R.RefreshAll()
ok(zs[1]:IsShown() and R.ticker and not R.ticker.cancelled and R.ticker.d == 2, "z affichés : filet de 2 s actif (C_Timer.NewTicker)")
resting = false
fire("PLAYER_UPDATE_RESTING")
ok(lf.mode == "calme" and lf.wave.fadeAg.playing, "PLAYER_UPDATE_RESTING : fondu vers l'allure calme")
settle()
ok(not zs[1]:IsShown() and lf:IsShown() and not lf.wave:IsShown() and lf.calm:IsShown(), "PLAYER_UPDATE_RESTING : z retirés, liquide léger")
ok(R.ticker == nil and tickers[#tickers].cancelled, "plus de z ni de vague : filet arrêté")
resting = true
fire("ZONE_CHANGED")
ok(zs[1]:IsShown() and lf.wave:IsShown() and lf.mode == "charge" and lf.wave.fadeAnim.toAlpha == CH.wave and lf.calm.fadeAnim.toAlpha == 0, "ZONE_CHANGED (retour en ville) : z et vague « charge » de retour, en fondu")
settle()
ok(not lf.calm:IsShown() and lf.wave.alpha == CH.wave, "fondu fini : allure calme cachée (le pilote ne la fait plus défiler)")
resting = false
fire("ZONE_CHANGED_INDOORS")
ok(not zs[1]:IsShown(), "ZONE_CHANGED_INDOORS : z retirés")
resting = true
fire("ZONE_CHANGED_NEW_AREA")
ok(zs[1]:IsShown(), "ZONE_CHANGED_NEW_AREA : z de retour")
-- aucun événement en sortant de l'auberge : le filet s'en charge
local tk = R.ticker
resting = false
tk.fn()
settle()
ok(not zs[1]:IsShown() and not lf.wave:IsShown() and lf:IsShown(), "sans événement : le filet de 2 s retire les z au plus tard 2 s après")
ok(tk.cancelled and R.ticker == nil, "filet arrêté ensuite")
local n0 = R.tick.refreshes
resting = true
R.RefreshAll()
local tk2 = R.ticker
tk2.fn()
ok(R.tick.refreshes == n0, "filet : rien n'est repeint tant que l'état du repos ne change pas")
-- 3.6.2 (audit) : panneau fermé → le filet s'arrête de lui-même (pas de fuite)
do
  local wasShown = lt.shown
  lt.shown = false
  local tk3 = R.ticker
  tk3.fn()
  ok(tk3.cancelled and R.ticker == nil, "case cachée : le filet de 2 s s'arrête (aucune fuite)")
  R.DriverTick(R.driver, 0.05)
  ok(not R.driver:IsShown(), "case cachée : le pilote de vague se cache (plus d'OnUpdate)")
  lt.shown = wasShown
  R.RefreshAll()
  ok(R.driver:IsShown(), "case de nouveau visible : vague relancée")
  ok(R.ticker and not R.ticker.cancelled, "case de nouveau visible : filet relancé")
  local nt = #tickers
  for _ = 1, 5 do R.RefreshAll() end
  ok(#tickers == nt, "RefreshAll répété : un seul filet (pas de doublon)")
  -- les z restent dans le coin de l'icône : départ dans l'icône, montée ≤ 4 px
  local ir, hr = __rect(lt.icon), __rect(lt._rzz)
  ok(hr.t <= ir.t + 0.5 and hr.r <= ir.r + 0.5 and hr.l >= ir.l and hr.b >= ir.b, "z ancrés DANS le coin de l'icône (ne débordent plus du cadre)")
  -- 3.6.2 (retour Arnaud) : z plus visibles, toujours dans le portrait
  local zz = lt._rzz.z
  local outs = 0
  for i, f in ipairs(zz) do
    local fr = __rect(f)
    local tr = f.ag and f.ag:Find("Translation")
    local dx, dy = tr and tr.offset[1] or 0, tr and tr.offset[2] or 0
    local sz = f.fs._font and f.fs._font[2] or 99
    -- cadre du z (≥ police) + montée + ombre (1 px à droite / en bas) dans l'icône
    if fr.l < ir.l or fr.b - 1 < ir.b or fr.r + dx + 1 > ir.r + 0.01 or fr.t + dy > ir.t + 0.01 or sz > (fr.t - fr.b) then outs = outs + 1 end
  end
  ok(outs == 0, "les 3 z (avec montée et ombre) restent dans le portrait")
  local f3 = zz[3].fs
  ok(zz[1].fs._font[2] == 8 and zz[2].fs._font[2] == 10 and f3._font[2] == 12 and f3._font[3] == "OUTLINE", "z : tailles 8 / 10 / 12, contour OUTLINE")
  ok(f3.tr == 0.85 and f3.tg == 0.93 and f3.tb == 1.0, "z : blanc bleuté (0.85, 0.93, 1.0)")
  ok(f3._shadowCol and f3._shadowCol[1] == 0 and f3._shadowCol[4] == 1 and f3._shadowOff[1] == 1 and f3._shadowOff[2] == -1, "z : ombre noire, décalage 1, -1")
  local peak = 0
  for _, a in ipairs(zz[3].ag.anims) do if a.kind == "Alpha" and (a.toAlpha or 0) > peak then peak = a.toAlpha end end
  ok(peak == 1.0, "z : opacité maximale 1.0")
end
apply()
-- mode calme actif
ns.Progress._quiet = true
st = apply()
ok(st.why == "calme" and not lf:IsShown(), "mode calme actif : caché")
ns.Progress._quiet = false
-- option
local O = ns.Options
local it = O.Find("restedAnim")
ok(it and it.default == true and (O.EXTRA_HOME.restedAnim == "display"), "réglage « Animation XP de repos » dans Affichage, activé par défaut")
local idx
for i, k in ipairs(O.ITEM_ORDER.display) do if k == "restedAnim" then idx = i end end
ok(idx and O.ITEM_ORDER.display[idx - 1] == "seasonal", "rangé après « Teinte saisonnière »")
O.Set("restedAnim", false)
ok(lt._restState.why == "option" and not lf:IsShown() and not lt._rzz:IsShown(), "option décochée : tout caché aussitôt")
O.Set("restedAnim", true)
ok(lf:IsShown() and lt._rzz:IsShown(), "option recochée : de retour")
setLang("en")
ok(ns.L[it.label] == "Rested XP animation", "EN : « Rested XP animation »")
setLang("fr")
-- autre case : aucun dessin
local other
for _, t in ipairs(UI.embed.tiles) do if t.data and t.data.kind ~= "level" and t:IsShown() then other = t break end end
if other then R.Apply(other) ok(other._rzz == nil and other._rliq == nil, "autre case : rien de dessiné") end
-- infobulle
restXP = 3600
local function lvlTip()
  local m = C.TooltipModel(lt.data)
  local t = {}
  for _, l in ipairs(m.lines) do t[#t + 1] = l[1] end
  return table.concat(t, "\n")
end
local ttf = lvlTip()
ok(strip(ttf):find("XP de repos : 3 600 (45 % d'un niveau)", 1, true) and ttf:find("|cffffd100XP de repos", 1, true), "infobulle FR, deux tons : « XP de repos : 3 600 (45 % d'un niveau) »")
io.write("--- infobulle Niveau FR ---\n" .. strip(ttf) .. "\n")
ok(not strip(ttf):find("reposé", 1, true), "plus de « · reposé N » en double")
setLang("en")
restXP = 12345
ok(strip(lvlTip()):find("Rested XP: 12,345 (154% of a level)", 1, true), "infobulle EN : « Rested XP: 12,345 (154% of a level) »")
setLang("fr")
restXP = nil
ok(not strip(lvlTip()):find("XP de repos", 1, true), "sans repos : pas de ligne")
ok(errs() == 0, "aucune erreur UI (repos)")




print("== 3.6.2 : audit de débordement, cases (3 thèmes × colonnes × FR/EN)")
do
  local R = ns.Rested
  local function frect(r)
    if r.typ ~= "FontString" or r.wrap == true or r.width ~= 100 then return __rect(r) end
    local w0, h0 = r.width, r.height
    r.width, r.height = r:GetStringWidth(), 12
    local rr = __rect(r) r.width, r.height = w0, h0 return rr
  end
  local function inside(a, o, tol) tol = tol or 1 return a and o and a.l >= o.l - tol and a.r <= o.r + tol and a.b >= o.b - tol and a.t <= o.t + tol end
  local cols0, theme0 = ns.db.ui.cols, ns.Theme.Mode()
  resting, restXP = true, 4000
  for _, th in ipairs({ "flare", "leger", "classic" }) do
    for _, cols in ipairs({ 1, 5, 10 }) do
      for _, lang in ipairs({ "fr", "en" }) do
        setLang(lang) ns.Theme.Set(th) ns.db.ui.cols = cols
        UI:Refresh(true)
        local nbad, worst, nt = 0, "", 0
        for _, t in ipairs(UI.embed and UI.embed.tiles or {}) do
          if t:IsVisible() and t.data then
            nt = nt + 1
            local tr = __rect(t)
            if t.icon and not inside(__rect(t.icon), tr) then nbad = nbad + 1 worst = "icône " .. tostring(t.data.kind) end
            local lf = t._rliq
            if lf and lf:IsShown() then
              local ir = __rect(t.icon)
              for _, x in ipairs({ lf.body, lf.wave, lf.calm }) do if x:IsShown() and not inside(__rect(x), ir) then nbad = nbad + 1 worst = "liquide" end end
            end
            for _, r in ipairs(t.regions or {}) do
              if r.typ == "FontString" and r:IsVisible() and (r.text or "") ~= "" and not inside(frect(r), tr, 2) then
                nbad = nbad + 1 worst = "texte « " .. tostring(r.text):sub(1, 24) .. " » (" .. tostring(t.data.kind) .. ")"
              end
            end
          end
        end
        ok(nt > 0 and nbad == 0, th .. " / " .. cols .. " col. / " .. lang .. " : " .. nt .. " cases, rien ne déborde (" .. nbad .. " " .. worst .. ")")
      end
    end
  end
  setLang("fr") ns.Theme.Set(theme0) ns.db.ui.cols = cols0 UI:Refresh(true)
end
print("== 3.6.2 : audit des chemins nil / erreur (NativeLook, Rested)")
do
  local NL, R = ns.NativeLook, ns.Rested
  local function safe(tag, fn) local okk, err = pcall(fn) ok(okk, tag .. (okk and "" or (" : " .. tostring(err)))) end
  safe("NL.CachedFor(nil / {} / sans id)", function() NL.CachedFor(nil) NL.CachedFor({}) NL.CachedFor({ name = 42 }) end)
  safe("NL.ParseCombat(nil / {} / lignes vides)", function() NL.ParseCombat(nil) NL.ParseCombat({}) NL.ParseCombat({ sections = { { lines = {} } } }) end)
  safe("NL.CompactCombatLines(nil / {})", function() NL.CompactCombatLines(nil) NL.CompactCombatLines({}) end)
  safe("NL.NativeDesc(nil / {})", function() NL.NativeDesc(nil) NL.NativeDesc({}) end)
  safe("NL.CombatLinesFor(nil / {})", function() NL.CombatLinesFor(nil) NL.CombatLinesFor({}) end)
  local saved = {}
  for _, n in ipairs(NL.ROOT_NAMES) do saved[n] = _G[n] _G[n] = nil end
  safe("NL.ReadNativeDetail sans aucune fenêtre du jeu", function() ok(NL.ReadNativeDetail() == nil, "rien lu, rien cassé") end)
  safe("NL.ReadIfShown(true) sans fenêtre", function() NL.ReadIfShown(true) end)
  for n, v in pairs(saved) do _G[n] = v end
  -- Rested : API absentes ou folles
  local keep = { UnitXPMax = _G.UnitXPMax, GetXPExhaustion = _G.GetXPExhaustion, IsResting = _G.IsResting }
  _G.UnitXPMax = function() return nil end
  safe("R.State : UnitXPMax nil", function() local st = R.State() ok(st.z == 0 and not st.liquid, "UnitXPMax nil : rien d'affiché") end)
  _G.UnitXPMax = function() return 0 end
  safe("R.State : UnitXPMax 0 (pas de division par 0)", function() local st = R.State() ok(st.z == 0 and not st.liquid, "UnitXPMax 0 : rien d'affiché") end)
  _G.UnitXPMax = keep.UnitXPMax
  _G.GetXPExhaustion = nil _G.IsResting = nil
  safe("R.State / TooltipLine : API absentes", function() R.State() R.TooltipLine() end)
  _G.GetXPExhaustion = function() error("boom") end
  safe("R.State : GetXPExhaustion qui lève une erreur", function() R.State() end)
  _G.GetXPExhaustion, _G.IsResting = keep.GetXPExhaustion, keep.IsResting
  safe("R.Apply : case sans icône / nil", function()
    R.Apply(nil)
    local t = CreateFrame("Frame") t.data = { kind = "level" } R.Apply(t) R.HideTile(t)
  end)
  safe("R.Num : nil / négatif / grand", function() ok(R.Num(nil) ~= nil and R.Num(-1234) and R.Num(1234567), "R.Num tolérant : " .. tostring(R.Num(1234567))) end)
  R.RefreshAll()
end
print("== 3.6.2 : audit de débordement, fenêtre Progression (tous onglets, FR/EN, 2 rendus)")
do
  local PU, P = ns.ProgressUI, ns.Progress
  local today = "2026-11-20"
  _G.date = function(fmt, t) if fmt == "%Y-%m-%d" and not t then return today end return os.date(fmt, t) end
  local _, c = P.C()
  c.history = c.history or {}
  c.history["2026-11-18"] = { pts = 98, cat = { prof = 90, combat = 8 }, skills = {} }
  c.history["2026-11-19"] = { pts = 31, cat = { prof = 31 }, skills = {} }
  c.history["2026-11-20"] = { pts = 3, cat = { level = 1, prof = 2 }, skills = {} }
  _G.CharacterFrame.shown = true
  PU.Open()
  local f = PU.frame
  ok(f and f:IsShown(), "fenêtre Progression ouverte")
  -- en jeu, un FontString sans largeur imposée prend la largeur de son texte
  -- (le harnais lui donne 100 × 50 par défaut) : rectangle « réel » estimé.
  local function frect(r)
    if r.typ ~= "FontString" or r.wrap == true or r.width ~= 100 then return __rect(r) end
    local w0, h0, abs = r.width, r.height, r._abs
    r.width, r.height = r:GetStringWidth(), 12
    local rr = __rect(r)
    r.width, r.height = w0, h0
    return rr
  end
  local function inside(r, o, tol)
    tol = tol or 1
    return r.l >= o.l - tol and r.r <= o.r + tol and r.b >= o.b - tol and r.t <= o.t + tol
  end
  local function audit(tag)
    local fr = __rect(f)
    local bad = {}
    local function walk(o, depth)
      if depth > 12 or not o:IsVisible() then return end
      for _, r in ipairs(o.regions or {}) do
        if r.shown ~= false and r:IsVisible() then
          local rr = frect(r)
          if rr and (rr.r - rr.l) > 0 and not inside(rr, fr) then
            bad[#bad + 1] = (r.typ or "?") .. " « " .. tostring(r.text or r._texSet or ""):sub(1, 30) .. " » " .. string.format("%.0f,%.0f→%.0f,%.0f", rr.l, rr.b, rr.r, rr.t)
          end
        end
      end
      for _, k in ipairs(o.children or {}) do walk(k, depth + 1) end
    end
    walk(f, 0)
    ok(#bad == 0, tag .. " : tout dans la fenêtre (" .. #bad .. ") " .. table.concat(bad, " | "):sub(1, 300))
    -- graphiques : graduations DANS le tracé
    local gbad = 0
    for _, ch in ipairs(PU.charts or {}) do
      if ch:IsVisible() then
        local cr = __rect(ch)
        for k = 1, 4 do
          local g = ch.grid[k]
          if g:IsVisible() then local gr = __rect(g) if not (gr and inside(gr, cr)) then gbad = gbad + 1 end end
          local l = ch.ylab[k]
          if l:IsVisible() then local lr = frect(l) if lr and (lr.b < cr.b - 1 or lr.t > cr.t + 8) then gbad = gbad + 1 end end
        end
      end
    end
    ok(gbad == 0, tag .. " : graduations et libellés dans le graphique (" .. gbad .. ")")
  end
  for _, lang in ipairs({ "fr", "en" }) do
    setLang(lang)
    for _, t in ipairs(PU.TABS) do
      PU.SetTab(t.id)
      if t.id == "overview" or t.id == "charts" then
        for _, per in ipairs(PU.PERIODS) do
          for _, met in ipairs(PU.METRICS) do
            PU.SetPeriod(per.id) PU.SetMetric(met.id)
            PU.Refresh() PU.Refresh()
            audit(lang .. " / " .. t.id .. " / " .. per.id .. " / " .. met.id)
          end
        end
      else
        PU.Refresh() PU.Refresh()
        audit(lang .. " / " .. t.id)
      end
    end
  end
  setLang("fr")
  -- le défaut d'origine : 2e rendu, échelle mémorisée dans la marge haute
  PU.SetTab("overview") PU.SetPeriod("d7") PU.SetMetric("cat")
  PU.Refresh() PU.Refresh() PU.Refresh()
  local ch
  for _, x in ipairs(PU.charts) do if x:IsVisible() then ch = x break end end
  ok(ch and ch.padTop == 12 and ch.scaleTop and ch.scaleTop >= 98, "graphique : marge haute intacte, échelle à part (" .. tostring(ch and ch.scaleTop) .. ")")
  local ok98 = false
  for _, b in ipairs(ch and ch.bars or {}) do if b:IsShown() and b.val:IsShown() and b.val.text == "+98" then
    local hsum = 0 for k = 1, 3 do if b.seg[k]:IsShown() then hsum = hsum + (b.seg[k].height or 0) end end
    ok98 = (__rect(b).t <= __rect(ch).t) and hsum >= 20
  end end
  ok(ok98, "barre +98 dessinée dans le graphique après 3 rendus")
  -- courbe de session vide : texte borné à la carte, sur 2 lignes
  local cv
  for _, x in ipairs(PU.curves or {}) do if x:IsVisible() then cv = x break end end
  if cv then
    ok(cv.empty.width and cv.empty.width <= cv.w - 16 and cv.empty.wordWrap ~= false, "courbe vide : texte limité à la largeur de la carte, avec retour à la ligne")
  end
  PU.Close()
end
print(failures == 0 and "\n3.6.2 : TOUS LES TESTS PASSENT" or ("\n3.6.2 : " .. failures .. " ÉCHEC(S)"))
os.exit(failures == 0 and 0 or 1)
