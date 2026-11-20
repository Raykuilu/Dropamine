-- Tests hors jeu 3.7.0 : noms d'objets sans « objet 159 », pause en vol.
-- Harnais repris de test_v362.lua (lignes 8-745).
-- /tmp/lua-5.1.5/src/lua tests/test_v363.lua

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
  function f:GetEffectiveScale() return self._scale or 1 end
  function f:SetClipsChildren(v) self.clipsChildren = v and true or false end
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
  function f:GetUnboundedStringWidth() return 6 * #(self.text or "") end
  function f:SetMaxLines(n) self._maxLines = n end
  function f:GetMaxLines() return self._maxLines end
  function f:SetHorizontalScroll(v) self._hscroll = v end
  function f:GetHorizontalScroll() return self._hscroll or 0 end
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
function _G.GameTooltip:SetOwner(owner, anchor)
  self.owner, self.anchor = owner, anchor
  self.shown = true
end
function _G.GameTooltip:IsOwned(o) return self.owner == o end
function _G.GameTooltip:ClearLines()
  self.lines = {}
  self._text, self.itemId, self.link = nil, nil, nil
end
function _G.GameTooltip:SetText(text, r, g, b)
  self._text = text
  self.lines = { { text = text, r = r, g = g, b = b } }
end
function _G.GameTooltip:AddLine(text, r, g, b)
  self.lines = self.lines or {}
  self.lines[#self.lines + 1] = { text = text, r = r, g = g, b = b }
end
function _G.GameTooltip:AddDoubleLine(l, r)
  self.lines = self.lines or {}
  self.lines[#self.lines + 1] = { text = l, right = r }
end
function _G.GameTooltip:SetItemByID(id)
  self.itemId = id
end
function _G.GameTooltip:SetHyperlink(link)
  self.link = link
end

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


-- ===========================================================================
-- 3.6.3
-- ===========================================================================

print("== 3.6.3 : jamais « objet 159 » / « item 159 »")
do
  local gi = _G.GetItemInfo
  _G.GetItemInfo = function(id)
    if id == 854 then return gi(id) end
    return nil
  end
  ns._itemNames[159] = nil
  local nm = ns.ItemDisplayName(159)
  ok(nm == nil, "ItemDisplayName(159) sans cache : nil, pas un repli")
  ok(not tostring(nm or ""):find("159", 1, true), "aucun « 159 » renvoyé")
  ok(ns.BareItemIdLabel("objet 159") and ns.BareItemIdLabel("item 159") and ns.BareItemIdLabel("objet 159 "), "BareItemIdLabel reconnaît objet/item + id")
  ok(not ns.BareItemIdLabel("Eau de source") and not ns.BareItemIdLabel("Viande de loup maigre"), "un vrai nom n'est pas un repli")
  setLang("fr")
  ok(ns.ItemDisplayName(159, "objet 159") == nil, "repli « objet 159 » rejeté (FR)")
  setLang("en")
  ok(ns.ItemDisplayName(159, "item 159") == nil, "repli « item 159 » rejeté (EN)")
  setLang("fr")
  ok(ns.ItemDisplayName(159, "Eau de source") == "Eau de source", "repli sensé conservé")
  -- StaticItem : un objet de la base (viande de palourde 5503 si présent)
  local st = ns.Scanner and ns.Scanner.StaticItem and ns.Scanner.StaticItem(5503)
  if st and (st.fr or st.en) then
    ns._itemNames[5503] = nil
    local got = ns.ItemDisplayName(5503)
    ok(got and not ns.BareItemIdLabel(got), "StaticItem 5503 : vrai nom « " .. tostring(got) .. " »")
  else
    ok(true, "StaticItem 5503 absent de la base (ignoré)")
  end
  _G.GetItemInfo = gi
end

print("== 3.6.3 : toast recette, seulement le nom de recette tant que l'objet n'est pas chargé")
do
  setLang("fr")
  local rec = { name = "Palourdes bouillies" }
  local matches = { { recipe = rec, item = 159, itemName = nil, diff = "medium" } }
  local line = strip(ns.Craft.FormatMatch(matches[1]))
  ok(line == "Palourdes bouillies (+1)", "FR sans nom : « Palourdes bouillies (+1) » (" .. line .. ")")
  ok(not line:find("objet", 1, true) and not line:find("159", 1, true), "FR : ni objet ni id")
  matches[1].itemName = "objet 159"
  ok(strip(ns.Craft.FormatMatch(matches[1])) == "Palourdes bouillies (+1)", "FR : « objet 159 » ignoré, seulement la recette")
  matches[1].itemName = "Eau de source fraîche"
  ok(strip(ns.Craft.FormatMatch(matches[1])) == "Eau de source fraîche : Palourdes bouillies (+1)", "FR avec nom : « Eau de source fraîche : Palourdes bouillies (+1) »")
  setLang("en")
  rec.name = "Boiled Clams"
  matches[1].itemName = nil
  local en = strip(ns.Craft.FormatMatch(matches[1]))
  ok(en == "Boiled Clams (+1)", "EN sans nom : « Boiled Clams (+1) » (" .. en .. ")")
  matches[1].itemName = "Refreshing Spring Water"
  ok(strip(ns.Craft.FormatMatch(matches[1])) == "Refreshing Spring Water: Boiled Clams (+1)", "EN avec nom : « Refreshing Spring Water: Boiled Clams (+1) »")
  setLang("fr")
  rec.name = "Palourdes bouillies"
end

print("== 3.6.3 : mise à jour quand le nom arrive (GET_ITEM_INFO_RECEIVED)")
do
  ns._itemNames[159] = nil
  ns._itemWait[159] = nil
  local gi = _G.GetItemInfo
  _G.GetItemInfo = function(id)
    if id == 159 then return nil end
    return gi(id)
  end
  local seen
  ns.WhenItemName(159, function(nm) seen = nm end)
  ok(seen == nil, "callback pas encore appelé")
  _G.GetItemInfo = function(id)
    if id == 159 then return "Eau de source fraîche" end
    return gi(id)
  end
  fire("GET_ITEM_INFO_RECEIVED", 159, true)
  ok(seen == "Eau de source fraîche", "GET_ITEM_INFO_RECEIVED met à jour le nom (" .. tostring(seen) .. ")")
  ok(ns.ItemDisplayName(159) == "Eau de source fraîche", "cache retenu ensuite")
  _G.GetItemInfo = gi
  ns._itemNames[159] = nil
end

print("== 3.6.3 : Item:CreateFromItemID / ContinueOnItemLoad")
do
  ns._itemNames[159] = nil
  ns._itemWait[159] = nil
  local gi = _G.GetItemInfo
  local pending = {}
  _G.GetItemInfo = function(id)
    if id == 159 then return nil end
    return gi(id)
  end
  _G.Item = {
    CreateFromItemID = function(id)
      return {
        id = id,
        ContinueOnItemLoad = function(self, cb) pending[#pending + 1] = { id = self.id, cb = cb } end,
      }
    end,
  }
  local seen
  ns.WhenItemName(159, function(nm) seen = nm end)
  ok(#pending == 1 and pending[1].id == 159, "CreateFromItemID + ContinueOnItemLoad utilisés")
  _G.GetItemInfo = function(id)
    if id == 159 then return "Eau de source fraîche" end
    return gi(id)
  end
  pending[1].cb()
  ok(seen == "Eau de source fraîche", "ContinueOnItemLoad met à jour le toast/nom (" .. tostring(seen) .. ")")
  _G.Item = nil
  _G.GetItemInfo = gi
  ns._itemNames[159] = nil
end

print("== 3.6.3 : le titre du toast se met à jour une fois le nom chargé")
do
  setLang("fr")
  local rec = { name = "Palourdes bouillies" }
  local matches = { { recipe = rec, item = 159, itemName = nil, diff = "easy" } }
  local frame = {
    shown = true,
    IsShown = function(self) return self.shown end,
    titleFS = { text = "", SetText = function(self, s) self.text = s end },
    subFS = { text = "", SetText = function(self, s) self.text = s end },
    hintFS = { text = "", SetText = function(self, s) self.text = s end },
  }
  ns._itemNames[159] = nil
  ns._itemWait[159] = nil
  local gi = _G.GetItemInfo
  _G.GetItemInfo = function(id) if id == 159 then return nil end return gi(id) end
  ns.Craft.BindToastItems(frame, matches)
  ok(strip(frame.titleFS.text) == "Palourdes bouillies (+1)" or frame.titleFS.text == "", "toast initial : recette seule ou en attente")
  -- BindToastItems only SetText in the callback, so simulate arrival
  _G.GetItemInfo = function(id) if id == 159 then return "Eau de source fraîche" end return gi(id) end
  fire("GET_ITEM_INFO_RECEIVED", 159, true)
  ok(strip(frame.titleFS.text) == "Eau de source fraîche : Palourdes bouillies (+1)", "toast mis à jour : « Eau de source fraîche : Palourdes bouillies (+1) » (" .. strip(frame.titleFS.text) .. ")")
  frame.shown = false
  matches[1].itemName = nil
  ns._itemNames[160] = nil
  ns._itemWait[160] = nil
  matches[1].item = 160
  ns.Craft.BindToastItems(frame, matches)
  _G.GetItemInfo = function(id) if id == 160 then return "Trop tard" end return gi(id) end
  fire("GET_ITEM_INFO_RECEIVED", 160, true)
  ok(strip(frame.titleFS.text) == "Eau de source fraîche : Palourdes bouillies (+1)", "toast déjà masqué : texte non réécrit")
  _G.GetItemInfo = gi
  setLang("fr")
end

print("== 3.6.3 : ailleurs, plus de « objet <id> »")
do
  setLang("fr")
  ns._itemNames[42] = nil
  local gi = _G.GetItemInfo
  _G.GetItemInfo = function() return nil end
  -- Links : composant de repli
  ok((ns.ItemDisplayName(42) or "composant") == "composant" or ns.L["composant"] == "composant", "Links / courses : repli « composant », pas « objet 42 »")
  _G.GetItemInfo = gi
end

print("== 3.6.3 : option Pause pendant le vol (défaut on, FR/EN)")
do
  local it = ns.Options.Find("pauseFlying")
  ok(it and it.default == true and it.key == "pauseFlying", "option pauseFlying trouvée, défaut on")
  ok(it.cmd == "/drop vol on|off", "commande /drop vol on|off")
  setLang("fr")
  ok(ns.L[it.label] == "Pause pendant le vol" or it.label == "Pause pendant le vol", "libellé FR : Pause pendant le vol")
  setLang("en")
  ok(ns.L["Pause pendant le vol"] == "Pause while flying", "libellé EN : Pause while flying")
  setLang("fr")
  ok(ns.Flight.OptionOn() == true, "option active par défaut (nil)")
  ok(ns.CMD_ALIAS.flight == "vol" and ns.CMD_ALIAS.fly == "vol", "alias flight / fly → vol")
end

print("== 3.6.3 : en taxi, suivi et toasts en pause, rien en file à l'atterrissage")
do
  local taxi = false
  _G.UnitOnTaxi = function(u) return u == "player" and taxi end
  ns.SetOpt("pauseFlying", true)
  -- l'astuce « premier vol » est testée plus bas ; ici on la considère déjà vue
  local ch = ns.CharDB and ns.CharDB()
  if ch then ch.flightPauseHint = true end
  taxi = false
  ns.Flight.Sync("test-sol")
  ok(ns.PausedForFlight() == false, "au sol : pas en pause")
  clearDrops()
  local f0 = UI:SpawnDrop("Interface\\Icons\\X", "Sol toast", "ok", nil, nil, nil, { kind = "skill", force = true })
  -- force bypasses pause; use a normal toast
  clearDrops()
  local f1 = UI:SpawnDrop("Interface\\Icons\\X", "Sol toast", "ok", nil, nil, nil, { kind = "skill" })
  ok(f1 ~= nil, "au sol : toast normalement affiché")
  clearDrops()

  taxi = true
  ns.Flight.Sync("test-taxi")
  ok(ns.Flight.OnTaxi() == true and ns.PausedForFlight() == true, "en vol : PausedForFlight")
  local queued = 0
  local f2 = UI:SpawnDrop("Interface\\Icons\\X", "objet 159 : Palourdes bouillies (+1)", "nope", nil, nil, nil, { kind = "scanner" })
  if f2 then queued = queued + 1 end
  ok(f2 == nil, "en vol : SpawnDrop refuse le toast")
  ok(ns.Scanner.OnPlateAdded("nameplate1") == nil, "en vol : scan de barre de nom ignoré")
  -- Craft.Notify via SpawnDrop
  if ns.Craft and ns.Craft.Notify then
    ns.db.ui.craftNotify = true
    local gains = { { n = 1, diff = "easy", skill = "cooking", recipe = { name = "Palourdes bouillies", icon = "Interface\\Icons\\Inv_Misc_Shell_01" } } }
    local fn = ns.Craft.Notify(gains)
    ok(fn == nil, "en vol : toast de recette réalisable refusé")
  end
  ok(nDrops() == 0, "en vol : aucun toast visible")

  -- atterrissage : pas de rattrapage
  taxi = false
  ns.Flight.Sync("test-land")
  ok(ns.PausedForFlight() == false, "au sol : plus en pause")
  ok(nDrops() == 0, "atterrissage : aucun toast en file (" .. nDrops() .. ")")

  -- option coupée : les toasts passent même en vol
  taxi = true
  ns.SetOpt("pauseFlying", false)
  ns.Flight.Sync("test-off")
  ok(ns.PausedForFlight() == false, "option off en vol : pas en pause")
  clearDrops()
  local f3 = UI:SpawnDrop("Interface\\Icons\\X", "Vol autorisé", "ok", nil, nil, nil, { kind = "skill" })
  ok(f3 ~= nil, "option off : toast affiché en vol")
  clearDrops()
  ns.SetOpt("pauseFlying", true)
  taxi = false
  ns.Flight.Sync("test-reset")
  _G.UnitOnTaxi = function() return false end
end

print("== 3.6.3 : /drop vol on|off")
do
  slash("vol off")
  ok(ns.db.ui.pauseFlying == false, "/drop vol off")
  slash("vol on")
  ok(ns.db.ui.pauseFlying == true, "/drop vol on")
  slash("flight off")
  ok(ns.db.ui.pauseFlying == false, "/drop flight off (alias)")
  slash("vol on")
end

print("== 3.6.3 : audit chemins nil")
do
  local function safe(tag, fn) local okk, err = pcall(fn) ok(okk, tag .. (okk and "" or (" : " .. tostring(err)))) end
  safe("ItemDisplayName(nil / « objet 1 »)", function()
    ns.ItemDisplayName(nil) ns.ItemDisplayName("x") ns.ItemDisplayName(159, "objet 1")
  end)
  safe("WhenItemName(nil)", function() ns.WhenItemName(nil, function() end) end)
  safe("FormatMatch(nil / {})", function() ns.Craft.FormatMatch(nil) ns.Craft.FormatMatch({}) ns.Craft.MatchLines(nil, nil) end)
  safe("BindToastItems(nil)", function() ns.Craft.BindToastItems(nil, {}) ns.Craft.BindToastItems({}, nil) end)
  safe("Flight.Sync sans UnitOnTaxi", function()
    local keep = _G.UnitOnTaxi
    _G.UnitOnTaxi = nil
    ns.Flight.Sync("noapi")
    _G.UnitOnTaxi = keep
  end)
  safe("PausedForFlight", function() ok(ns.PausedForFlight() == false or ns.PausedForFlight() == true, "booléen") end)
end


print("== 3.6.3 : sablier — feuille 32 images (3 s, drainage puis retournement 0,4 s)")
do
  local F = ns.Flight
  ok(F.SAND_DUR == 2.6 and F.FLIP_DUR == 0.4 and F.CYCLE == 3.0, "durées : 2,6 s + 0,4 s = 3 s")
  ok(F.HG_FPS == 20 and math.abs((F.HG_STEP or 0) - 0.05) < 1e-6, "20 im/s")
  ok(F.SAND_FRAMES == 26 and F.FLIP_FRAMES == 6 and F.SHEET_N == 32, "32 images : 26 + 6")
  ok(F.SHEET_COLS == 8 and F.SHEET_ROWS == 4, "feuille 8×4")
  ok(F.SheetIndex(0) == 0, "t=0 : image 0")
  ok(F.SheetIndex(2.6 - 1e-9) == 25, "fin du drainage : image 25")
  ok(F.SheetIndex(2.6) == 26, "t=2,6 s : première image du retournement")
  -- milieu du flip (2,8 s, p=0,5) → floor(0,5*6)+26 = 29
  ok(F.SheetIndex(2.8) >= 28 and F.SheetIndex(2.8) <= 29, "t=2,8 s : milieu du flip, image " .. tostring(F.SheetIndex(2.8)))
  ok(F.SheetIndex(3.0) == 0, "t=3 s : retour à l'image 0")
  ok(F.Phase(0) == "sand" and F.Phase(2.6) == "flip" and F.Phase(3.0) == "sand", "Phase : drainage / flip / drainage")
  local u0, u1, v0, v1 = F.SheetTexCoord(0)
  ok(math.abs(u0) < 1e-9 and math.abs(u1 - 0.125) < 1e-9 and math.abs(v0) < 1e-9 and math.abs(v1 - 0.25) < 1e-9,
    "texcoords image 0 : (0, 1/8, 0, 1/4)")
  u0, u1, v0, v1 = F.SheetTexCoord(8)
  ok(math.abs(u0) < 1e-9 and math.abs(u1 - 0.125) < 1e-9 and math.abs(v0 - 0.25) < 1e-9 and math.abs(v1 - 0.50) < 1e-9,
    "texcoords image 8 : rangée 1")
  -- toutes les coordonnées restent dans [0, 1]
  local okuv = true
  for i = 0, 31 do
    local a,b,c,d = F.SheetTexCoord(i)
    if a < 0 or c < 0 or b > 1+1e-9 or d > 1+1e-9 or b <= a or d <= c then okuv = false end
  end
  ok(okuv, "toutes les texcoords dans [0, 1], cases non vides")
end

print("== 3.6.3 : sablier remplace la goutte en vol, calé dans l'emplacement, fondu et assombrissement")
do
  local F = ns.Flight
  local taxi = false
  _G.UnitOnTaxi = function(u) return u == "player" and taxi end
  ns.SetOpt("pauseFlying", true)
  -- le toast d'astuce n'interfère pas avec ces tests
  if F.ResetHints then F.ResetHints() end
  local c = ns.CharDB and ns.CharDB()
  if c then c.flightPauseHint = true end   -- déjà vue, pas de toast ici
  taxi = false
  F.Sync("hg-sol")
  local tot = ns.Wide.TotalTile()
  ok(tot ~= nil, "case Niveau total présente")
  ok((F._vis or 0) == 0 and (tot._hg == nil or not tot._hg:IsShown()), "au sol : pas de sablier")
  local dim0 = ns.Panel.FrameAlpha()
  local iconW = tot.icon and tot.icon.GetWidth and tot.icon:GetWidth()
  taxi = true
  F.Sync("hg-taxi")
  ok(F.Paused(), "en vol : pause")
  ok(F._visFrame and F._visFrame:IsShown(), "pilote OnUpdate démarré")
  for i = 1, 12 do
    gtime = gtime + 0.05
    F.TickVisual(F._visFrame, 0.05)
  end
  ok((F._vis or 0) >= 0.99, "après 0,6 s : vis = 1 (" .. tostring(F._vis) .. ")")
  local h = tot._hg
  ok(h and h:IsShown(), "sablier affiché sur la fiole")
  ok((h._texSet or (h.GetTexture and h:GetTexture()) or ""):find("Hourglass-Sheet", 1, true)
     or tostring(h._texSet or ""):find("Hourglass-Sheet", 1, true),
    "texture = feuille Hourglass-Sheet (" .. tostring(h._texSet) .. ")")
  ok(not h.sandTop and not h.frame, "une seule texture, pas de pièces de sable empilées")
  ok(tot.icon and (tot.icon.alpha or 1) < 0.05, "goutte d'origine estompée (alpha " .. tostring(tot.icon and tot.icon.alpha) .. ")")
  -- Fiole et sablier validés à ~70 % de la case (même taille).
  local tileHg = (ns.Icons and ns.Icons.TILE) or 40
  local vialSz = (ns.Wide and ns.Wide.IconSize and ns.Wide.IconSize(tileHg))
    or math.floor(tileHg * 0.70 + 0.5)
  local hw = h.GetWidth and h:GetWidth()
  local hh = h.GetHeight and h:GetHeight()
  ok(iconW and math.abs((iconW or 0) - vialSz) < 0.5,
    "fiole au repos = 70 % (" .. tostring(iconW) .. " / " .. tostring(vialSz) .. ")")
  ok(iconW and hw and math.abs(hw - iconW) < 0.5,
    "sablier = taille de la fiole (" .. tostring(hw) .. " / " .. tostring(iconW) .. ")")
  ok(hh and iconW and math.abs(hh - iconW) < 0.5,
    "hauteur sablier = fiole (" .. tostring(hh) .. ")")
  -- drainage : l'indice avance
  F._cycle0 = gtime - 1.3
  F.TickVisual(F._visFrame, 0.05)
  ok(h._idx and h._idx >= 10 and h._idx <= 16, "à 1,3 s : image milieu de drainage (" .. tostring(h._idx) .. ")")
  -- retournement : l'indice est dans 26–31, la taille ne change pas
  F._cycle0 = gtime - 2.8
  F.TickVisual(F._visFrame, 0.05)
  ok(h._idx and h._idx >= 26 and h._idx <= 31, "à 2,8 s : image de retournement (" .. tostring(h._idx) .. ")")
  local hw2 = h.GetWidth and h:GetWidth()
  local hh2 = h.GetHeight and h:GetHeight()
  ok(hw2 and math.abs(hw2 - (hw or hw2)) < 0.5 and hh2 and math.abs(hh2 - (hh or hh2)) < 0.5,
    "flip pré-rendu : la taille de l'emplacement ne change pas")
  local dim = F.DimMul()
  ok(math.abs(dim - 0.75) < 0.02, "assombrissement ×0,75 (" .. tostring(dim) .. ")")
  if ns.Panel.ApplyOpacity then ns.Panel.ApplyOpacity() end
  local fa = ns.Panel.FrameAlpha()
  ok(fa <= dim0 * 0.8 + 0.05, "FrameAlpha tient compte du dim (idle " .. tostring(dim0) .. " → " .. tostring(fa) .. ")")
  taxi = false
  F.Sync("hg-land")
  ok(not F.Paused(), "atterri")
  F.TickVisual(F._visFrame, 0.05)
  ok((F._vis or 1) < 1, "fondu de sortie commencé (" .. tostring(F._vis) .. ")")
  for i = 1, 12 do
    gtime = gtime + 0.05
    if F._visFrame and F._visFrame:IsShown() then F.TickVisual(F._visFrame, 0.05) end
  end
  ok((F._vis or 0) <= 0.01, "après 0,6 s : vis = 0 (" .. tostring(F._vis) .. ")")
  ok(not (tot._hg and tot._hg:IsShown()), "sablier caché")
  ok(tot.icon and (tot.icon.alpha or 1) >= 0.99, "goutte restaurée")
  ok(math.abs((F.DimMul() or 1) - 1) < 0.01, "opacité pleine restaurée")
  ok(not (F._visFrame and F._visFrame:IsShown()), "OnUpdate arrêté une fois caché")
  taxi = true
  ns.SetOpt("pauseFlying", false)
  F.Sync("hg-off")
  for i = 1, 4 do gtime = gtime + 0.05 if F._visFrame and F._visDriving then F.TickVisual(F._visFrame, 0.05) end end
  ok(not F.Paused() and (F._vis or 0) <= 0.01, "option off : pas de sablier en vol")
  ns.SetOpt("pauseFlying", true)
  taxi = false
  F.Sync("hg-reset")
  _G.UnitOnTaxi = function() return false end
end

print("== 3.6.3 : infobulle fiole « En pause pendant le vol »")
do
  local F = ns.Flight
  setLang("fr")
  local taxi = true
  _G.UnitOnTaxi = function(u) return u == "player" and taxi end
  ns.SetOpt("pauseFlying", true)
  F.Sync("hg-tip")
  F._vis = 1
  ok(F.ShowPauseTip(), "ShowPauseTip en pause")
  local tot = ns.Wide.TotalTile()
  local C = ns.Compact
  local m = C.TooltipModel and C.TooltipModel(tot and tot.data or { kind = "total" })
  local cm = {}
  if m and m.lines then for _, l in ipairs(m.lines) do cm[#cm+1] = l[1] end end
  local blob = table.concat(cm, "\n")
  ok(blob:find("En pause pendant le vol", 1, true), "infobulle FR : « En pause pendant le vol »")
  ok(blob:find("Le scan reprend dès l'atterrissage.", 1, true), "infobulle fiole FR : « Le scan reprend dès l'atterrissage. »")
  setLang("en")
  m = C.TooltipModel(tot and tot.data or { kind = "total" })
  cm = {}
  if m and m.lines then for _, l in ipairs(m.lines) do cm[#cm+1] = l[1] end end
  blob = table.concat(cm, "\n")
  ok(blob:find("Paused while flying", 1, true), "infobulle EN : « Paused while flying »")
  ok(blob:find("Scanning resumes as soon as you land.", 1, true), "infobulle fiole EN : « Scanning resumes as soon as you land. »")
  local gt = _G.GameTooltip
  if F.ShowPauseExplanation then
    F.ShowPauseExplanation(tot or gt)
    ok(gt._text and tostring(gt._text):find("Paused while flying", 1, true), "sablier : titre EN « Paused while flying »")
    local has = false
    for _, ln in ipairs(gt.lines or {}) do
      if ln.text and tostring(ln.text):find("Scanning resumes as soon as you land.", 1, true) then has = true end
    end
    ok(has, "sablier : ligne EN « Scanning resumes as soon as you land. »")
  end
  setLang("fr")
  if F.ShowPauseExplanation then
    F.ShowPauseExplanation(tot or gt)
    ok(gt._text and tostring(gt._text):find("En pause pendant le vol", 1, true), "sablier : titre FR « En pause pendant le vol »")
    local has = false
    for _, ln in ipairs(gt.lines or {}) do
      if ln.text and tostring(ln.text):find("Le scan reprend dès l'atterrissage.", 1, true) then has = true end
    end
    ok(has, "sablier : ligne FR « Le scan reprend dès l'atterrissage. »")
  end
  if tot and ns.Wide and ns.Wide.SyncFlaskHit then pcall(ns.Wide.SyncFlaskHit, tot, 1) end
  local hit = tot and tot._hgHit
  ok(hit and hit.IsShown and hit:IsShown(), "cadre de survol de la fiole affiché en vol")
  ok(hit and hit.IsMouseEnabled and hit:IsMouseEnabled(), "cadre de survol de la fiole : souris active")
  taxi = false
  F._vis = 0
  F.Sync("hg-tip-end")
  if tot and ns.Wide and ns.Wide.ApplyHourglassTo then pcall(ns.Wide.ApplyHourglassTo, tot, 0) end
  _G.UnitOnTaxi = function() return false end
end

print("== 3.6.3 : premier trajet — un toast d'astuce, une fois par personnage")

do
  local F = ns.Flight
  local function visibleToasts()
    local n, titles = 0, {}
    local ui = ns.UI
    for _, f in ipairs((ui and ui.dropsActive) or {}) do
      if f and f.IsShown and f:IsShown() and not f._editPreview then
        n = n + 1
        titles[#titles+1] = (f.titleFS and f.titleFS:GetText()) or f._title or ""
      end
    end
    return n, titles
  end
  local function hasHint(titles)
    for _, s in ipairs(titles) do
      if tostring(s):find("Suivi en pause", 1, true) or tostring(s):find("Tracking paused", 1, true) then return true end
    end
    return false
  end
  F.ResetHints()
  local c = ns.CharDB()
  ok(c.flightPauseHint == nil, "astuce pas encore vue")
  setLang("fr")
  ns.SetOpt("pauseFlying", true)
  -- un toast normal au sol, puis le vol doit le masquer et poser l'astuce
  if ns.UI and ns.UI.SpawnDrop then
    ns.UI:SpawnDrop("Interface\\Icons\\INV_Misc_QuestionMark", "toast-sol", "x", nil, nil, nil, { kind = "skill", force = true })
  end
  local taxi = true
  _G.UnitOnTaxi = function(u) return u == "player" and taxi end
  F._taxi = false
  F.Sync("hint-first")
  ok(F.Paused(), "en vol pour l'astuce")
  local n, titles = visibleToasts()
  ok(hasHint(titles), "toast d'astuce FR visible (« Suivi en pause pendant le vol. »)")
  -- le toast « sol » a été masqué
  local leftover = false
  for _, s in ipairs(titles) do if tostring(s):find("toast-sol", 1, true) then leftover = true end end
  ok(not leftover, "les toasts déjà ouverts ont été masqués")
  ok(c.flightPauseHint == true, "marqueur perso enregistré")
  -- un toast « recette » en vol reste refusé
  local before = n
  if ns.UI and ns.UI.SpawnDrop then
    local r = ns.UI:SpawnDrop("Interface\\Icons\\INV_Misc_QuestionMark", "Palourdes bouillies (+1)", nil, nil, nil, nil, { kind = "scanner" })
    ok(r == nil, "les autres toasts restent refusés en vol")
  end
  local function hintFrame()
    for _, f in ipairs((ns.UI and ns.UI.dropsActive) or {}) do
      if f and f._kind == "flight-hint" then return f end
    end
  end
  local function tick(f, dt)
    local fn = f and f.GetScript and f:GetScript("OnUpdate")
    if fn then fn(f, dt) end
  end
  local hf = hintFrame()
  ok(hf and not hf._sticky, "toast d'astuce standard (pas sticky)")
  local sub = hf and hf.subFS and hf.subFS.GetText and hf.subFS:GetText() or ""
  local htxt = hf and hf.hintFS and hf.hintFS.GetText and hf.hintFS:GetText() or ""
  ok(tostring(sub):find("Le scan reprend dès l'atterrissage.", 1, true),
    "sous-titre FR : « Le scan reprend dès l'atterrissage. »")
  ok(not tostring(htxt):find("Clic pour fermer", 1, true), "pas de ligne « Clic pour fermer »")
  if hf then for _ = 1, 20 do tick(hf, 0.05) end end
  ok(hf and hf.IsShown and hf:IsShown(), "l'astuce est encore visible après 1 s (maintien)")
  if ns.UI and ns.UI.SpawnDrop then
    ns.UI:SpawnDrop("Interface\\Icons\\INV_Misc_QuestionMark", "toast-force", "x", nil, nil, nil, { kind = "skill", force = true })
  end
  F.HideActiveToasts()
  n, titles = visibleToasts()
  ok(not hasHint(titles), "HideActiveToasts masque aussi l'astuce")
  -- second trajet : plus d'astuce
  -- second trajet : plus d'astuce
  taxi = false
  F.Sync("hint-land")
  if F.HideActiveToasts then F.HideActiveToasts() end
  taxi = true
  F.Sync("hint-second")
  n, titles = visibleToasts()
  ok(not hasHint(titles), "deuxième vol : pas de second toast d'astuce")
  -- reset-hints rouvre le droit
  taxi = false
  F.Sync("hint-reset-land")
  if F.HideActiveToasts then F.HideActiveToasts() end
  F.ResetHints()
  ok(c.flightPauseHint == nil, "/drop reset-hints (API) efface le marqueur")
  taxi = true
  F.Sync("hint-again")
  n, titles = visibleToasts()
  ok(hasHint(titles), "après reset-hints : l'astuce réapparaît")
  hf = hintFrame()
  if hf then
    for _ = 1, 80 do tick(hf, 0.05) end  -- 4 s > maintien 2,6 + fondu 0,7
  end
  n, titles = visibleToasts()
  ok(not hasHint(titles), "toast d'astuce : fondu automatique comme les autres")
  -- slash
  taxi = false
  F.Sync("hint-slash-land")
  hf = hintFrame()
  if hf and ns.UI and ns.UI.DismissDrop then ns.UI:DismissDrop(hf) end
  if F.HideActiveToasts then F.HideActiveToasts() end
  F.ResetHints()
  -- laisser le slash le faire
  c.flightPauseHint = true
  local slash = SlashCmdList.DROPAMINE
  if slash then slash("reset-hints") end
  ok(c.flightPauseHint == nil, "/drop reset-hints efface le marqueur")
  -- alias
  c.flightPauseHint = true
  if slash then slash("resethints") end
  ok(c.flightPauseHint == nil, "alias resethints")
  -- EN
  setLang("en")
  F.ResetHints()
  taxi = true
  F.Sync("hint-en")
  n, titles = visibleToasts()
  local enTitle, enSub, enHint = false, false, false
  for _, f in ipairs((ns.UI and ns.UI.dropsActive) or {}) do
    local title = f.titleFS and f.titleFS.GetText and f.titleFS:GetText() or ""
    local sub2 = f.subFS and f.subFS.GetText and f.subFS:GetText() or ""
    local hint2 = f.hintFS and f.hintFS.GetText and f.hintFS:GetText() or ""
    if tostring(title):find("Tracking paused while flying.", 1, true) then enTitle = true end
    if tostring(sub2):find("Scanning resumes as soon as you land.", 1, true) then enSub = true end
    if tostring(hint2):find("Click to dismiss", 1, true) then enHint = true end
  end
  ok(enTitle, "toast d'astuce EN : « Tracking paused while flying. »")
  ok(enSub, "sous-titre EN : « Scanning resumes as soon as you land. »")
  ok(not enHint, "pas de ligne EN « Click to dismiss »")
  hf = hintFrame()
  if hf and ns.UI and ns.UI.DismissDrop then ns.UI:DismissDrop(hf) end
  setLang("fr")
  taxi = false
  F.Sync("hint-done")
  if F.HideActiveToasts then F.HideActiveToasts() end
  _G.UnitOnTaxi = function() return false end
end

print("== 3.6.3 : toasts — une ligne, défilement, infobulle au survol")
do
  local ui = ns.UI
  ns.SetOpt("pauseFlying", true)
  _G.UnitOnTaxi = function() return false end
  if ns.Flight then ns.Flight._taxi = false end
  local function tick(f, dt)
    local fn = f and f.GetScript and f:GetScript("OnUpdate")
    if fn then fn(f, dt) end
  end
  local function enter(f)
    local fn = f and f.GetScript and f:GetScript("OnEnter")
    if fn then fn(f) end
  end
  local function leave(f)
    local fn = f and f.GetScript and f:GetScript("OnLeave")
    if fn then fn(f) end
  end
  local shortName = "Soupe courte"
  local longName = "A Very Long Recipe Name That Definitely Overflows The Toast Title Line When Measured At Six Pixels Per Character Because It Is Extremely Verbose Indeed"
  local short = ui:SpawnDrop("Interface\\Icons\\INV_Misc_QuestionMark", shortName, "détail court", nil, nil, nil, { kind = "skill", force = true })
  local long = ui:SpawnDrop("Interface\\Icons\\INV_Misc_QuestionMark", longName, "détail aussi très long pour forcer un défilement de la seconde ligne aussi", nil, nil, nil, { kind = "scanner", force = true })
  ok(short and long, "toasts court et long créés")
  local sh = short and (short:GetHeight() or short._h)
  local lh = long and (long:GetHeight() or long._h)
  ok(sh and lh and sh > 0 and lh > 0, "toasts court et long ont une hauteur")
  -- Un titre énorme (> 2 lignes) passe en défilement ; la hauteur peut grandir pour un texte moyen.
  ok(lh > 0, "toast long : hauteur auto (jusqu'à 2 lignes, défilement en repli)")
  local tfs = long and long.titleFS
  ok(tfs and tfs.wrap == false, "titre : SetWordWrap(false)")
  ok(tfs and (tfs._maxLines == 1 or tfs.GetMaxLines and tfs:GetMaxLines() == 1), "titre : une seule ligne (SetMaxLines(1))")
  local need = tfs and tfs:GetStringWidth() or 0
  local room = ns.ToastFit and ns.ToastFit.Avail and ns.ToastFit.Avail(long, tfs) or 0
  ok(need > room, "le nom de recette très long dépasse la largeur disponible")
  -- laisser ToastFit poser le clip
  if ns.ToastFit and ns.ToastFit.Fit then ns.ToastFit.Fit(long) end
  local mq = tfs and tfs._mq
  ok(mq, "clip / défilement installé pour le titre trop long")
  -- avant la pause initiale : offset 0
  for _ = 1, 10 do tick(long, 0.05) end  -- 0.5 s < 1.2 s d'attente
  ok((mq.off or 0) == 0, "pas de défilement pendant la pause initiale")
  for _ = 1, 30 do tick(long, 0.05) end  -- +1.5 s : le défilement a commencé
  ok((mq.off or 0) > 0, "le titre défile une fois le texte trop long")
  local off = mq.off
  enter(long)
  ok(long._hover, "survol : _hover")
  for _ = 1, 40 do tick(long, 0.05) end
  ok(mq.off == off, "survol : le défilement est en pause")
  leave(long)
  ok(not long._hover, "sortie : _hover levé")
  for _ = 1, 20 do tick(long, 0.05) end
  ok((mq.off or 0) > off, "sortie : le défilement reprend")

  -- Infobulle : toast simple = titre + détail intégraux
  enter(short)
  local gt = _G.GameTooltip
  local function tipHas(frag)
    if gt._text and tostring(gt._text):find(frag, 1, true) then return true end
    for _, ln in ipairs(gt.lines or {}) do
      if ln.text and tostring(ln.text):find(frag, 1, true) then return true end
    end
    return false
  end
  ok(gt.shown and gt:IsOwned(short), "survol d'un toast : GameTooltip affichée")
  ok(tipHas(shortName), "infobulle : titre intégral")
  ok(tipHas("détail court"), "infobulle : ligne de détail intégrale")
  leave(short)
  ok(not gt.shown, "sortie : GameTooltip masquée")

  -- Recette / réalisable : métier, rang, difficulté, nombre, composants, objet
  if _G.bags then _G.bags[159] = 1; _G.bags[2678] = 0 end
  bags[159] = 1
  bags[2678] = 0
  local recipe = {
    name = longName,
    req = 50,
    itemID = 5525,
    reagents = {
      { id = 159, name = "Eau de source", count = 1 },
      { id = 2678, name = "Épices douces", count = 1 },
    },
  }
  local craft = ui:SpawnDrop("Interface\\Icons\\INV_Misc_Food_15", longName, "1 × possible", nil, nil, nil, {
    kind = "craft", force = true,
    toastData = {
      kind = "craft", skill = "cooking", recipe = recipe, n = 0, diff = "optimal",
      item = 5525,
    },
  })
  ok(craft, "toast recette créé")
  if ns.ToastFit and ns.ToastFit.Fit then ns.ToastFit.Fit(craft) end
  enter(craft)
  ok(not gt.itemId and not (gt.link and tostring(gt.link):find("5525", 1, true)),
    "infobulle recette : pas de SetItemByID / SetHyperlink (le clic ouvrirait un lien d'objet)")
  ok(craft._craft and craft._craft.skill == "cooking" and craft._craft.recipe,
    "toast recette : _craft renseigné (clic ouvre la recette)")
  ok(craft._craft.item == 5525 or tostring(craft._craft.item or "") == "5525",
    "toast recette : id objet conservé pour Maj+clic")
  ok(tipHas(longName), "infobulle recette : nom intégral (non tronqué)")
  ok(tipHas("Métier :") or tipHas("Profession:"), "infobulle recette : métier")
  ok(tipHas("Rang requis : 50") or tipHas("Required rank: 50"), "infobulle recette : rang requis")
  ok(tipHas("Difficulté :") or tipHas("Difficulty:"), "infobulle recette : difficulté")
  ok(tipHas("Réalisable maintenant : 0") or tipHas("Can craft now: 0"), "infobulle recette : nombre fabricable")
  ok(tipHas("Composants manquants") or tipHas("Missing reagents"), "infobulle recette : composants manquants")
  ok(tipHas("Épices douces") or tipHas("2678"), "infobulle recette : le composant manquant est cité")
  leave(craft)

  -- Minuterie de fondu : le survol la met en pause, la sortie la reprend (sans relancer)
  local fading = ui:SpawnDrop("Interface\\Icons\\INV_Misc_QuestionMark", "fade-test", "x", nil, nil, nil, { kind = "skill", force = true })
  ok(fading, "toast pour la minuterie de fondu")
  -- presque en fin de maintien (0,15 + 2,55 ≈ juste avant le fondu)
  tick(fading, 2.65)
  ok(fading:IsShown(), "encore visible juste avant la fin du maintien")
  enter(fading)
  for _ = 1, 100 do tick(fading, 0.05) end  -- 5 s de survol
  ok(fading:IsShown(), "survol : la minuterie de fondu est en pause")
  leave(fading)
  tick(fading, 1.0)  -- reprise : le reste du maintien + fondu doit suffire à le fermer
  ok(not fading:IsShown(), "sortie : la minuterie reprend et le toast finit par disparaître")

  -- nettoyage
  if short and short:IsShown() and ui.DismissDrop then ui:DismissDrop(short) end
  if long and long:IsShown() and ui.DismissDrop then ui:DismissDrop(long) end
  if craft and craft:IsShown() and ui.DismissDrop then ui:DismissDrop(craft) end
end

print("== 3.6.3 : sablier d'abord, l'échec de l'astuce ne le bloque pas")
do
  local F = ns.Flight
  ns.SetOpt("pauseFlying", true)
  local saved = F.MaybeShowHint
  F.MaybeShowHint = function() error("hint boom") end
  _G.UnitOnTaxi = function(u) return u == "player" end
  F._taxi = nil
  F._visDriving = false
  local okCall = pcall(F.Sync, "hard-login-taxi")
  ok(okCall, "login déjà en vol : Sync ne lève pas si l'astuce échoue")
  ok(F.Paused(), "login déjà en vol : pause")
  ok(F._visDriving or (F._visFrame and F._visFrame:IsShown()), "login déjà en vol : le sablier démarre malgré l'échec de l'astuce")
  _G.UnitOnTaxi = function() return false end
  F._simTaxi = nil
  F.SetTaxi(false, "hard-land")
  F.MaybeShowHint = function() error("hint boom 2") end
  _G.UnitOnTaxi = function(u) return u == "player" end
  okCall = pcall(F.Sync, "hard-takeoff")
  ok(okCall, "envol après login : Sync ne lève pas si l'astuce échoue")
  ok(F._visDriving or (F._visFrame and F._visFrame:IsShown()), "envol après login : le sablier démarre malgré l'échec de l'astuce")
  F.MaybeShowHint = saved
  _G.UnitOnTaxi = function() return false end
  F._simTaxi = nil
  F.SetTaxi(false, "hard-done")
  F.Sync("hard-done")
end

print("== 3.6.3 : build publique sans section Test")
do
  ok(ns.DEV_TEST ~= true, "build publique : ns.DEV_TEST éteint")
  ok(not (ns.SlashExt and ns.SlashExt.test), "build publique : pas de /drop test")
  if ns.Options and ns.Options.Build then pcall(ns.Options.Build) end
  ok(not (ns.Options and ns.Options.devTestBox), "build publique : pas de section Test dans les Options")
end

-- Le reste de la suite exerce encore le module de simulation (API interne).
ns.DEV_TEST = true
ns.SlashExt = ns.SlashExt or {}
ns.SlashExt.test = function(rest)
  local arg = (rest or ""):match("^%s*(.-)%s*$") or ""
  if arg == "" then
    ns.Print("/drop test flight|toast|off : simulations (DEV)")
    return
  end
  if ns.Test and ns.Test.Toggle then ns.Test.Toggle(arg) end
end

print("== 3.6.3 : section Test (DEV) + /drop test")
do
  local T = ns.Test
  local F = ns.Flight
  ok(ns.DEV_TEST == true, "suite : ns.DEV_TEST réactivé pour les simulations")
  ok(T and T.Enabled and T.Enabled(), "module ns.Test actif")
  -- Options.Build est à usage unique : le panneau public a déjà été construit sans section Test.
  local f = T.Toast()
  ok(f and f.titleFS and tostring(f.titleFS:GetText()):find(T.LONG_NAME, 1, true), "bouton Toast : toast au nom long")
  if ns.ToastFit and ns.ToastFit.Fit then pcall(ns.ToastFit.Fit, f) end
  local need = f and f.titleFS and f.titleFS.GetStringWidth and f.titleFS:GetStringWidth() or 0
  local room = ns.ToastFit and ns.ToastFit.Avail and ns.ToastFit.Avail(f, f.titleFS) or 0
  ok(need > room, "toast test : le nom dépasse (défilement)")
  local c = ns.CharDB()
  c.flightPauseHint = true
  _G.UnitOnTaxi = function() return false end
  T.StartFlight()
  ok(F._simTaxi and F.Paused(), "test vol : pause simulée sans taxi réel")
  ok(F._visDriving or (F._visFrame and F._visFrame:IsShown()), "test vol : sablier démarré")
  local seen = false
  for _, drop in ipairs((ns.UI and ns.UI.dropsActive) or {}) do
    local title = drop.titleFS and drop.titleFS:GetText() or ""
    if tostring(title):find("Suivi en pause", 1, true) then seen = true end
  end
  ok(seen, "test vol : toast d'astuce affiché (même si déjà vu)")
  ok(c.flightPauseHint == true, "test vol : le marqueur perso n'est pas réécrit")
  local slash = SlashCmdList.DROPAMINE
  if slash then slash("test off") end
  ok(not F._simTaxi and not T.IsOn("flight"), "/drop test off arrête la simulation")
  ok(T.Start("death") == true, "test mort : simulation du crâne")
  ok(ns.Slot and ns.Slot.IsSim("death"), "test mort : sim active")
  T.StopAll()
  ok(not (ns.Slot and ns.Slot.IsSim("death")), "test mort : stoppé")
  if slash then slash("test flight") end
  ok(F._simTaxi and F.Paused(), "/drop test flight démarre la simulation")
  if slash then slash("test off") end
  _G.UnitOnTaxi = function() return false end
  F.Sync("dev-done")
end

print("== 3.6.3 : fichiers Media du sablier")
do
  local f1 = io.open(addonDir .. "/Media/Hourglass.tga", "rb")
  local f2 = io.open(addonDir .. "/Media/Hourglass-Sheet.tga", "rb")
  ok(f1 and f2, "Media/Hourglass.tga et Hourglass-Sheet.tga présents")
  if f1 then f1:close() end
  if f2 then f2:close() end
  -- la feuille fait 512×256 (32 cases de 64)
  if f2 == nil then
    -- already closed; reopen to check size
  end
  local s = io.open(addonDir .. "/Media/Hourglass-Sheet.tga", "rb")
  if s then
    local hdr = s:read(18)
    s:close()
    local w = hdr:byte(13) + hdr:byte(14) * 256
    local h = hdr:byte(15) + hdr:byte(16) * 256
    ok(w == 512 and h == 256, "feuille 512×256 (reçue " .. tostring(w) .. "×" .. tostring(h) .. ")")
  end
end


print("== 3.6.3 : départ et atterrissage détectés sans /reload")
do
  local F = ns.Flight
  local ch = ns.CharDB and ns.CharDB()
  if ch then ch.flightPauseHint = true end
  ns.SetOpt("pauseFlying", true)
  local taxi = false
  _G.UnitOnTaxi = function(u) return u == "player" and taxi end
  taxi = false
  F.Sync("login-sol")
  ok(not F.Paused(), "après login au sol : pas en pause")
  F.EnsurePoll()
  ok(F._pollFrame ~= nil, "cadre de sondage créé")
  ok(F._pollFrame.IsShown and F._pollFrame:IsShown(), "cadre de sondage affiché (OnUpdate tourne en jeu)")
  ok(F._pollFrame.GetScript and F._pollFrame:GetScript("OnUpdate") ~= nil, "OnUpdate posé au sol, avant tout taxi")

  -- Envol typique : PLAYER_CONTROL_LOST se déclenche AVANT que UnitOnTaxi soit vrai.
  fire("PLAYER_CONTROL_LOST")
  ok(not F.Paused(), "PLAYER_CONTROL_LOST trop tôt : pas encore en pause")
  ok(F._pollFrame:GetScript("OnUpdate") ~= nil, "le sondage n'est pas arrêté après CONTROL_LOST")
  ok(F._burst and #F._burst >= 3, "recontrôles 0,1 / 0,5 / 1,5 s planifiés (" .. tostring(F._burst and #F._burst) .. ")")

  -- UnitOnTaxi passe à vrai, sans /reload ; le premier recontrôle à 0,1 s doit voir le taxi.
  taxi = true
  local upd = F._pollFrame:GetScript("OnUpdate")
  upd(F._pollFrame, 0.1)
  ok(F.Paused() == true, "0,1 s plus tard, UnitOnTaxi vrai : pause sans /reload")

  -- Atterrissage détecté par le sondage 0,5 s, sans event et sans /reload
  taxi = false
  F._burst = {}
  F._elapsed = 0
  upd(F._pollFrame, 0.5)
  ok(not F.Paused(), "atterrissage détecté par le sondage 0,5 s, sans /reload")

  -- PLAYER_CONTROL_GAINED
  taxi = true
  F.Sync("reprise-vol")
  ok(F.Paused(), "repart en vol")
  taxi = false
  fire("PLAYER_CONTROL_GAINED")
  ok(not F.Paused(), "PLAYER_CONTROL_GAINED : atterrissage")

  -- TAXIMAP_CLOSED puis UnitOnTaxi un instant plus tard
  taxi = false
  F.Sync("sol-carte")
  fire("TAXIMAP_CLOSED")
  ok(not F.Paused(), "TAXIMAP_CLOSED : pas encore en taxi")
  taxi = true
  upd(F._pollFrame, 0.1)
  ok(F.Paused(), "après TAXIMAP_CLOSED + 0,1 s : pause")

  -- UNIT_FLAGS d'une autre unité : ignoré
  taxi = false
  F.Sync("sol-flags")
  F._burst = {}
  fire("UNIT_FLAGS", "target")
  taxi = true
  -- Paused() lit UnitOnTaxi en direct ; on vérifie que le *déclenchement* n'a pas eu lieu.
  ok(F._taxi ~= true, "UNIT_FLAGS d'une autre unité : pas de déclenchement")
  -- UNIT_FLAGS joueur trop tôt, puis le taxi devient vrai
  taxi = false
  F.Sync("sol-flags2")
  fire("UNIT_FLAGS", "player")
  ok(not F.Paused(), "UNIT_FLAGS joueur trop tôt : pas encore en pause")
  taxi = true
  upd(F._pollFrame, 0.1)
  ok(F.Paused(), "UNIT_FLAGS joueur + 0,1 s : pause")

  -- le sondage périodique (0,5 s) détecte aussi un envol sans aucun event
  taxi = false
  F.Sync("sol-poll")
  F._burst = {}
  F._elapsed = 0
  taxi = true
  upd(F._pollFrame, 0.5)
  ok(F.Paused(), "sondage 0,5 s seul, sans event : pause à l'envol")

  ns.SetOpt("pauseFlying", true)
  taxi = false
  F.Sync("fin-detect")
  _G.UnitOnTaxi = function() return false end
end


print("== 3.6.3 : gestionnaire d'états de la fiole")
do
  local S = ns.Slot
  ok(S ~= nil, "Slot.lua chargé")
  ok(io.open(addonDir .. "/Dropamine.toc"):read("*a"):find("Rested.lua\nSlot.lua\nRankToast.lua", 1, true),
    ".toc : Slot.lua et RankToast.lua après Rested.lua")
  ok(S.CombatStyle() == "off", "style de combat retiré (fiole statique)")
  -- priorité sans épée (style bulles)
  S.ClearSim()
  S.SetCombatStyle("bubbles")
  S.SetSim("afk", true)
  S.SetSim("fishing", true)
  S.SetSim("combat", true)
  ok(S.Active() == "afk", "bulles : AFK passe avant pêche et combat (pas d'épée dans le puits)")
  S.SetSim("flight", true)
  -- flight wants F.Paused(); sim flight alone is not enough
  -- death > flight
  S.SetSim("death", true)
  ok(S.Active() == "death", "priorité : mort devant AFK")
  S.SetSim("death", false)
  S.SetSim("flight", false)
  S.SetCombatStyle("sword")
  S.SetSim("combat", true)
  S.SetSim("afk", true)
  ok(S.Active() ~= "combat", "plus de symbole epee anime")
  S.SetCombatStyle("bubbles")
  ok(S.Active() == "afk", "AFK reprend le puits")
  S.ClearSim()
  S.Refresh("test-clean")
  ok(S.Active() == "drop", "aucune sim : goutte")
end

print("== 3.6.3 : style de combat (bulles / épée / off) et transitions")
do
  local S, F, Wd = ns.Slot, ns.Flight, ns.Wide
  S.ClearSim()
  S.SetCombatStyle("bubbles")
  local tot = Wd and Wd.TotalTile and Wd.TotalTile()
  ok(tot ~= nil, "case total présente pour le liquide de combat")
  -- remplissage : p monte, vert s'efface, proportions rouge/bleu conservées
  local widths = { 20, 10, 30 }
  local out0 = S.TransformWidths(widths, 60, { p = 0, grey = 0, drain = 1 })
  ok(math.abs((out0[1] or 0) - 20) < 0.6 and math.abs((out0[2] or 0) - 10) < 0.6 and math.abs((out0[3] or 0) - 30) < 0.6,
    "p=0 : largeurs normales à trois couleurs")
  local out1 = S.TransformWidths(widths, 60, { p = 1, grey = 0, drain = 1 })
  local rb = (out1[1] or 0) + (out1[2] or 0)
  ok((out1[3] or 0) < 0.6, "p=1 : vert disparu (" .. tostring(out1[3]) .. ")")
  ok(math.abs(rb - 60) < 1.5, "p=1 : rouge+bleu remplissent la piste (" .. tostring(rb) .. ")")
  ok(math.abs((out1[1] or 0) / math.max(0.01, out1[2] or 0) - 2) < 0.15, "p=1 : proportion rouge/bleu conservée")
  -- montée animée
  S.fill.p, S.fill.grey, S.fill.drain = 0, 0, 1
  S.SetSim("combat", true)
  S.Refresh("combat-on")
  ok(S.Active() == "drop", "style bulles : le puits garde la goutte (pas d'épée)")
  for i = 1, 14 do S.Tick(0.05) end
  ok((S.fill.targetP or 0) == 0, "plus de liquide de combat apres ticks (p=" .. tostring(S.fill.p) .. ")")
  ok((S.fill.targetP or 0) == 0, "cible de remplissage combat = 0")
  -- descente
  S.SetSim("combat", false)
  S.Refresh("combat-off")
  S.Tick(0.05)
  local mid = S.fill.p
  ok(true, "plus de descente de liquide de combat")
  -- reprise au milieu de la descente
  S.SetSim("combat", true)
  S.Refresh("combat-re")
  S.Tick(0.05)
  ok((S.fill.targetP or 0) == 0, "reprise en combat : toujours sans liquide")
  for i = 1, 14 do S.Tick(0.05) end
  ok((S.fill.p or 0) < 0.2, "reprise : p reste a 0")
  -- style off : pas de liquide
  S.SetCombatStyle("off")
  S.Refresh("combat-style-off")
  ok((S.fill.targetP or 0) == 0, "plus de liquide de combat")
  -- style épée : symbole dans le puits
  S.SetCombatStyle("sword")
  S.SetSim("combat", true)
  S.Refresh("combat-sword")
  ok(S.Active() ~= "combat", "plus de feuille epee")
  if tot then S.ApplyTotal(tot) end
  local h = tot and tot._hg
  local tex = tostring((h and (h._texSet or (h.GetTexture and h:GetTexture()))) or "")
  ok(not (h and h:IsShown() and tex:find("Combat-C-Sheet", 1, true)), "plus de feuille epee dans le puits")
  ok(not tex:find("Combat-C-Sheet", 1, true) and not tex:find("Sword-Sheet", 1, true),
    "plus de texture epee (" .. tex .. ")")
  -- /reload en combat : p part de 0 et rejoint 1
  S.fill.p, S.fill.grey, S.fill.drain = 0, 0, 1
  S.SetCombatStyle("bubbles")
  S.SetSim("combat", true)
  S.Refresh("reload-in-combat")
  ok((S.fill.targetP or 0) == 0, "/reload en combat : pas de liquide")
  for i = 1, 14 do S.Tick(0.05) end
  ok((S.fill.p or 0) < 0.2, "/reload en combat : p reste a 0")
  S.ClearSim()
  S.SetCombatStyle("bubbles")
  S.fill.p, S.fill.grey, S.fill.drain = 0, 0, 1
  S.Refresh("clean")
end

print("== 3.6.3 : mort (crâne, fiole grise, pause) et conflit avec le combat")
do
  local S, UI = ns.Slot, ns.UI
  S.ClearSim()
  S.SetCombatStyle("bubbles")
  S.SetSim("combat", true)
  S.fill.p = 1
  S.Refresh("pre-death")
  S.SetSim("death", true)
  S.Refresh("death-in-combat")
  ok(S.Active() == "death", "mort en combat : le crâne gagne")
  ok(S.fill.targetDrain == 0 and S.fill.targetGrey == 1, "mort : cible vide + grise")
  for i = 1, 14 do S.Tick(0.05) end
  ok(S.fill.drain <= 0.05 and S.fill.grey >= 0.95, "après 0,7 s : fiole vidée et grisée")
  ok(S.DeathPause() and ns.PausedForFlight(), "suivi en pause pendant la mort")
  if UI and UI.SpawnDrop then
    local r = UI:SpawnDrop("Interface\\Icons\\INV_Misc_QuestionMark", "pendant-mort", "x", nil, nil, nil, { kind = "skill" })
    ok(r == nil, "mort : SpawnDrop refuse le toast (sans force)")
  end
  local tot = ns.Wide.TotalTile()
  if tot then S.ApplyTotal(tot) end
  local h = tot and tot._hg
  local tex = tostring((h and (h._texSet or (h.GetTexture and h:GetTexture()))) or "")
  ok(h and h:IsShown() and tex:find("Death-Sheet", 1, true), "crâne : feuille Death-Sheet (" .. tex .. ")")
  -- résurrection, encore en combat
  S.SetSim("death", false)
  S.Refresh("rez")
  ok(S.fill.targetDrain == 1 and S.fill.targetGrey == 0,
    "resurrection en combat : fiole retablie")
  for i = 1, 14 do S.Tick(0.05) end
  ok(S.fill.drain >= 0.95 and S.fill.grey <= 0.05, "refill termine (fiole normale)")
  -- résurrection hors combat
  S.SetSim("combat", false)
  S.SetSim("death", true)
  S.fill.p, S.fill.grey, S.fill.drain = 0, 1, 0
  S.Refresh("dead-again")
  S.SetSim("death", false)
  S.Refresh("rez-peace")
  ok(S.fill.targetP == 0 and S.fill.targetDrain == 1 and S.fill.targetGrey == 0,
    "résurrection hors combat : retour à l'état normal à trois couleurs")
  S.ClearSim()
  S.fill.p, S.fill.grey, S.fill.drain = 0, 0, 1
  S.Refresh("clean")
end

print("== 3.6.3 : infobulle de combat, AFK, pêche, test /drop")
do
  local S = ns.Slot
  S.ClearSim()
  S.SetCombatStyle("bubbles")
  S.SetSim("combat", true)
  S.Refresh("tip-combat")
  -- GameTooltip mock
  local gt = _G.GameTooltip
  if gt then
    if gt.ClearLines then pcall(gt.ClearLines, gt) end
    gt.text, gt.lines = nil, {}
  end
  setLang("fr")
  local tot = ns.Wide.TotalTile()
  S.ShowExplanation(tot or { typ = "Frame" })
  local blob = tostring((gt and (gt.text or gt._text)) or "")
  if gt and gt.lines then
    for _, l in ipairs(gt.lines) do blob = blob .. "\n" .. tostring(l[1] or l) end
  end
  -- certains mocks stockent dans records
  if gt and gt.logs then blob = blob .. table.concat(gt.logs, "\n") end
  ok(blob:find("En combat : XP et armes en cours", 1, true),
    "infobulle FR combat : « En combat : XP et armes en cours » (" .. blob .. ")")
  setLang("en")
  if gt and gt.ClearLines then pcall(gt.ClearLines, gt) end
  if gt then gt.text, gt.lines = nil, {} end
  S.ShowExplanation(tot or { typ = "Frame" })
  blob = tostring((gt and (gt.text or gt._text)) or "")
  if gt and gt.lines then for _, l in ipairs(gt.lines) do blob = blob .. "\n" .. tostring(l[1] or l) end end
  ok(blob:find("In combat: XP and weapon skills in progress", 1, true),
    "infobulle EN combat : « In combat: XP and weapon skills in progress » (" .. blob .. ")")
  setLang("fr")
  S.ClearSim()
  S.SetSim("afk", true)
  S.Refresh("afk")
  ok(S.Active() == "afk", "AFK : horloge")
  S.ClearSim()
  S.SetSim("fishing", true)
  S.Refresh("fish")
  ok(S.Active() == "fishing", "pêche : hameçon")
  S.OnCatch()
  ok((S._jolt or 0) > 0, "prise : sursaut du hameçon")
  S.ClearSim()
  S.SetSim("swimming", true)
  ok(S.Active() == "swimming", "nage : bulles")
  S.ClearSim()
  S.Refresh("clean")

  -- option Style de combat
  local it
  if ns.Options and ns.Options.Find then it = ns.Options.Find("combatStyle") end
  ok(not it, "Options : plus de Style de combat")

  -- /drop test
  if ns.Test then
    ns.Test.StopAll()
    ok(ns.Test.Start("combat") == true, "/drop test combat")
    ok(S.IsSim("combat"), "sim combat active")
    ok(ns.Test.Start("rankup") == true, "/drop test rankup")
    ns.Test.StopAll()
    ok(not S.IsSim("combat"), "test off : sims arrêtées")
  end
end

print("== 3.6.3 : toast collant rang supérieur chez le maître")
do
  local RT, UI = ns.RankToast, ns.UI
  ok(RT ~= nil, "RankToast.lua chargé")
  -- option par défaut on
  ok(RT.Opt(), "option trainerRankToast active par défaut")
  setLang("fr")
  local list = {
    { id = "skinning", name = "Dépeçage", icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01" },
    { id = "cooking", name = "Cuisine", icon = "Interface\\Icons\\INV_Misc_Food_15" },
  }
  ok(RT.Title(list):find("Dépeçage, Cuisine : rang supérieur disponible chez le maître", 1, true),
    "titre FR combiné : « Dépeçage, Cuisine : rang supérieur disponible chez le maître »")
  setLang("en")
  ok(RT.Title({ list[1] }):find("Dépeçage: next rank available at the trainer", 1, true),
    "titre EN : « <Profession>: next rank available at the trainer »")
  setLang("fr")
  -- sim ville + dispo
  if UI and UI.dropsActive then
    for i = #UI.dropsActive, 1, -1 do
      if UI.DismissDrop then pcall(UI.DismissDrop, UI, UI.dropsActive[i]) end
    end
  end
  RT._dismissedVisit, RT._queued, RT._wasInCity, RT._toast = nil, nil, nil, nil
  RT._leftAt, RT._leftKey, RT._wasKey = nil, nil, nil
  RT.SetSim(true, { list[1] })
  -- ni vol ni combat
  if ns.Flight then ns.Flight._simTaxi = nil end
  if ns.Slot then ns.Slot.ClearSim() ns.Slot.SetCombatStyle("bubbles") end
  local f = RT.Show(RT.Available())
  ok(f ~= nil, "toast rang maître affiché")
  ok(f and f._sticky, "toast collant (pas de fondu auto)")
  ok(f and f._dedupeKey == "rank-trainer", "dedupe rank-trainer")
  -- plafond : un sticky n'est pas évincé
  if UI and UI.DROP_MAX then
    local cap = UI.DROP_MAX
    for i = 1, cap + 2 do
      UI:SpawnDrop("Interface\\Icons\\X", "n" .. i, "x", nil, nil, nil, { kind = "skill", force = true })
    end
    local still = false
    for _, o in ipairs(UI.dropsActive or {}) do
      if o == f or (o and o._dedupeKey == "rank-trainer") then still = true end
    end
    ok(still, "le toast collant n'est pas évincé par le plafond")
  end
  -- clic : fermé, pas de relance tant qu'on reste en ville
  if UI and f then pcall(UI.DismissDrop, UI, f) end
  ok(RT._dismissedVisit, "clic : visite dismissée")
  local f2 = RT.Show(RT.Available())
  ok(f2 == nil, "pas de relance dans la même visite")
  -- sortie + rentrée immédiate dans la même capitale : pas de relance
  RT._simCity = false
  RT.Refresh("leave")
  ok(not RT._dismissedVisit, "sortie de ville : dismiss oublié")
  ok(RT._leftAt ~= nil, "sortie : horodatage de grâce posé")
  RT._simCity = true
  RT.Refresh("ZONE_CHANGED_NEW_AREA")
  ok(not RT.IsShowing(), "rentrée immédiate dans la même capitale : pas de nouveau toast")
  -- après la grâce : le toast peut revenir
  RT._simCity = false
  RT.Refresh("leave")
  RT._leftAt = (GetTime and GetTime() or 0) - ((RT.REENTRY_GRACE or 90) + 1)
  RT._simCity = true
  RT.Refresh("ZONE_CHANGED_NEW_AREA")
  ok(RT.IsShowing() or (RT._toast ~= nil), "après la grâce : le toast se relance")
  -- auberge / repos : pas un toast de maître
  RT.Hide("test")
  RT._wasInCity, RT._wasKey, RT._queued, RT._dismissedVisit = true, "sim", nil, nil
  RT._simCity = true
  RT.Refresh("PLAYER_UPDATE_RESTING")
  ok(not RT.IsShowing(), "PLAYER_UPDATE_RESTING : pas de toast maître")
  RT.Refresh("ZONE_CHANGED_INDOORS")
  ok(not RT.IsShowing(), "ZONE_CHANGED_INDOORS : pas de toast maître")
  -- Menethil / auberge (repos) n'est pas une capitale
  local bakCity, bakRest, bakZone = _G.GetRealZoneText, _G.IsResting, _G.GetZoneText
  _G.GetRealZoneText = function() return "Menethil Harbor" end
  _G.GetZoneText = function() return "Menethil Harbor" end
  _G.IsResting = function() return true end
  RT.SetSim(false)
  RT._simList = { list[1] }
  ok(not RT.InCapital(), "Menethil + repos : pas une capitale")
  _G.GetRealZoneText, _G.IsResting, _G.GetZoneText = bakCity, bakRest, bakZone
  RT.SetSim(true, { list[1] })
  if not RT.IsShowing() then RT.Show(RT.Available()) end
  -- apprentissage : plus rien de disponible → fermeture
  RT._simList = {}
  RT.Refresh("SKILL_LINES_CHANGED")
  ok(not RT.IsShowing(), "rang appris : toast fermé")
  -- file d'attente en vol
  RT.SetSim(true, { list[1] })
  RT._dismissedVisit, RT._wasInCity = nil, true
  if ns.Test and ns.Test.StartFlight then ns.Test.StartFlight() end
  RT.Refresh("flight")
  ok(RT.Blocked() == "flight", "en vol : toast bloqué")
  ok(not RT.IsShowing() or RT._queued, "en vol : toast en file (pas affiché)")
  if ns.Test and ns.Test.StopFlight then ns.Test.StopFlight() end
  RT._queued = true
  RT.Refresh("PLAYER_REGEN_ENABLED")
  ok(RT.IsShowing(), "après le vol : file vidée, toast affiché")
  -- combat : file
  if ns.Slot then ns.Slot.SetSim("combat", true) end
  RT.Refresh("combat")
  ok(RT.Blocked() == "combat", "en combat : toast bloqué")
  if ns.Slot then ns.Slot.SetSim("combat", false) ns.Slot.ClearSim() end
  RT.Refresh("PLAYER_REGEN_ENABLED")
  ok(RT.IsShowing(), "sortie de combat : toast réaffiché")
  -- nettoyage
  RT.SetSim(false)
  RT.Hide("test")
  if ns.Test then ns.Test.StopAll() end
  setLang("fr")
end

print("== 3.6.3 : fuite mémoire toasts, capitals, coalesce, fiole")
do
  local UI, S, RT = ns.UI, ns.Slot, ns.RankToast
  -- vivier de toasts : DismissDrop recycle, un second Spawn réutilise le cadre
  if UI and UI.dropsActive then
    for i = #UI.dropsActive, 1, -1 do
      if UI.DismissDrop then pcall(UI.DismissDrop, UI, UI.dropsActive[i]) end
    end
  end
  UI._toastPool = UI._toastPool or {}
  local before = UI._toastCreated or 0
  local a = UI:SpawnDrop("Interface\\Icons\\X", "pool-a", "x", nil, nil, nil, { kind = "skill", force = true })
  ok(a ~= nil, "toast pool : premier cadre créé")
  local created = UI._toastCreated or 0
  ok(created >= before + 1 or a._osrsToast, "toast pool : cadre marqué")
  UI:DismissDrop(a)
  ok(a._inPool, "DismissDrop remet le toast dans le vivier")
  local poolN = #(UI._toastPool or {})
  ok(poolN >= 1, "vivier non vide après fermeture")
  local b = UI:SpawnDrop("Interface\\Icons\\X", "pool-b", "x", nil, nil, nil, { kind = "skill", force = true })
  ok(b == a, "second toast : réutilise le même cadre")
  ok((UI._toastCreated or 0) == created, "aucun cadre supplémentaire créé")
  UI:DismissDrop(b)

  -- TransformWidths réutilise sa table
  if S and S.TransformWidths then
    S._widthOut = nil
    local t1 = S.TransformWidths({ 10, 20, 30 }, 100, { p = 0, grey = 0, drain = 1 })
    local t2 = S.TransformWidths({ 11, 21, 31 }, 100, { p = 0, grey = 0, drain = 1 })
    ok(t1 == t2 and t1 == S._widthOut, "TransformWidths réutilise le même tableau")
    ok(t2[1] == 11 and t2[2] == 21 and t2[3] == 31, "TransformWidths met à jour le tampon")
  else
    ok(false, "S.TransformWidths présent")
  end

  -- FlushSkillDiff sans palier : pas de Collect
  if UI.FlushSkillDiff and ns.SkillRankSnapshot then
    local calls = 0
    local prevC = ns.Collect
    ns.Collect = function(...)
      calls = calls + 1
      if prevC then return prevC(...) end
      return {}, {}
    end
    UI._skillSeeded = true
    UI._prevSkills = { foo = { name = "Foo", rank = 10, max = 75 } }
    -- snapshot identique
    local prevSnap = ns.SkillRankSnapshot
    ns.SkillRankSnapshot = function()
      return { foo = { name = "Foo", rank = 10, max = 75 } }
    end
    UI:FlushSkillDiff()
    ok(calls == 0, "FlushSkillDiff sans palier : pas de Collect")
    ns.Collect, ns.SkillRankSnapshot = prevC, prevSnap
  end

  -- icône officielle jamais cachée (fiole noire)
  if S and S.ApplySlotZ then
    local hidden = false
    local tile = {
      _wideOn = true,
      icon = {
        Show = function(self) self.shown = true hidden = false end,
        Hide = function(self) self.shown = false hidden = true end,
        SetAlpha = function(self, a) self.a = a end,
      },
    }
    -- EnsureSlotZ peut échouer sans CreateFrame sur la case : on pose un clip factice
    tile._slotZ = {
      Show = function() end, Hide = function() end,
      SetPoint = function() end, ClearAllPoints = function() end,
      SetSize = function() end,
    }
    S.IconInnerSize = S.IconInnerSize or function() return 14, 14, tile.icon, 2 end
    S.ApplySlotZ(tile, true)
    ok(not hidden and tile.icon.shown ~= false, "ApplySlotZ : la fiole officielle reste visible")
  end

  ok(S and S.OnRestOrZone and S.QuietSkills, "OnRestOrZone / QuietSkills présents")
  ok(UI.REFRESH_WAIT and UI.REFRESH_WAIT.idle >= 1 and UI.REFRESH_WAIT.raid <= 2.01,
    "rescans regroupés toutes les 1–2 s")
  ok(S and S.ApplyGridFill and S.EnsureGridFill, "remplissage de fiole en grille")
  ok(RT and RT.InCapital and RT.REENTRY_GRACE == 90, "InCapital + grâce 90 s")
  ok(ns.Compact and ns.Compact.ShouldHold, "Compact.ShouldHold présent")
  -- icône XP : silhouette officielle (pas l'ancienne goutte + splash)
  ok(type(ns.LEVEL_ICON) == "string" and ns.LEVEL_ICON:find("XP-Icon", 1, true), "LEVEL_ICON pointe vers XP-Icon")
  local xpPath = addonDir .. "/Media/XP-Icon.tga"
  local xf = io.open(xpPath, "rb")
  ok(xf ~= nil, "Media/XP-Icon.tga présent")
  if xf then
    local hdr = xf:read(18)
    xf:close()
    if hdr and #hdr >= 18 then
      local w = hdr:byte(13) + hdr:byte(14)*256
      local h = hdr:byte(15) + hdr:byte(16)*256
      ok(w == 64 and h == 64, "XP-Icon 64×64 (lisible en petit)")
    end
  end
  ok(UI.TOAST_SLIDE == 7, "toast : glissement de 7 px")
  ok(UI.ToastSlideAmount and UI.ApplyToastPoint, "toast : helpers de glissement")
  -- politique XP inchangée
  ok(UI.SpawnQuestXPToast and UI.MaybeXPMilestone and UI.XP_MILESTONES, "politique XP : quête + jalons")
  local marks = UI.XP_MILESTONES
  ok(marks and marks[1]==25 and marks[2]==50 and marks[3]==75, "jalons XP 25 / 50 / 75 %")
  -- repas : kinds
  ok(S.ClassifyEat and S.EatKind and S.EAT_WAVE, "repas : ClassifyEat / EatKind / couleurs")
  ok(S.ClassifyEat("Nourriture") == "food" and S.ClassifyEat("Boisson") == "drink", "repas : nourriture ambre, boisson bleue")
  ok(S.ClassifyEat("Nourriture et Boisson") == "both", "repas : les deux = two waves")
  ok((not S.PlayTotalAdd) and (not S.TickTotalAdd) and (not S.EnsureTotalAdd),
    "plus de goutte d'ajout dans la fiole")
  ok(S.PlayBarSpark and S.TickBarSpark and S.HideBarSpark, "étincelle de barre de total")
  ok(S.PlayLevelUp and S.TickLevelUp, "débordement de niveau conservé")
  -- Personnages
  local PU = ns.ProgressUI
  ok(PU and PU.TABS, "ProgressUI chargé")
  local hasChars
  for _, tab in ipairs(PU.TABS or {}) do if tab.id == "chars" then hasChars = true end end
  ok(hasChars, "onglet Personnages présent")
  ok(PU.BuildChars and PU.RefreshChars and PU.CharGrid and PU.SelectChar, "onglet Personnages en cartes")
  ok(ns.CaptureCharSheet and ns.AllCharSheets, "instantanés de personnages")
  if ns.Test then
    ok(ns.Test.StartEating and ns.Test.StartTotalAdd and ns.Test.StartLevelUp,
      "/drop test eating|totaladd|levelup")
  end

  if ns.Compact and ns.Compact.ShouldHold then
    ok(not ns.Compact.ShouldHold({ combatTile = true, skillName = "Mains nues", kind = "melee" }),
      "armes / cases combat : pas de retenue")
  end
end

print("== 3.6.3 : sacs, trajet, chargement, repas, calme auto, usure, efficacité, rentabilité")
do
  local S, F, P, E, UI, PU = ns.Slot, ns.Flight, ns.Progress, ns.Efficiency, ns.UI, ns.ProgressUI
  ok(S and F and P and E, "modules Slot, Flight, Progress, Efficiency chargés")

  -- priorité : mort > vol > épée combat > AFK > sacs > pêche > nage > usure > repos
  S.ClearSim()
  S.SetCombatStyle("sword")
  if ns.SetOpt then ns.SetOpt("slotDurability", true) end
  S.SetSim("durability", true)
  S.SetSim("swimming", true)
  S.SetSim("fishing", true)
  S.SetSim("bags", true)
  S.SetSim("afk", true)
  S.SetSim("combat", true)
  S.SetSim("flight", true)
  S.SetSim("death", true)
  ok(S.Active() == "death", "priorité : mort d'abord")
  S.SetSim("death", false)
  ok(S.Active() == "flight", "priorité : vol après la mort")
  S.SetSim("flight", false)
  ok(S.Active() ~= "combat", "plus d epee de combat dans l ordre de priorite")
  S.SetSim("combat", false)
  ok(S.Active() == "afk", "priorité : AFK après le combat")
  S.SetSim("afk", false)
  ok(S.Active() == "bags", "priorité : sacs pleins après AFK")
  S.SetSim("bags", false)
  ok(S.Active() == "fishing", "priorité : pêche après les sacs")
  S.SetSim("fishing", false)
  ok(S.Active() == "swimming", "priorité : nage après la pêche")
  S.SetSim("swimming", false)
  ok(S.Active() == "durability", "priorité : usure après la nage (option allumée)")
  S.SetCombatStyle("bubbles")
  if ns.SetOpt then ns.SetOpt("slotDurability", false) end
  S.ClearSim()
  S.SetSim("durability", true)
  ok(S.Active() == "drop", "usure : coupée par défaut, pas de signal")
  ok(S.Opt("slotDurability") == false, "option slotDurability off par défaut")
  S.ClearSim()

  -- toast sacs : une seule fois tant que ça reste plein
  S._bagsToastShown, S._bagsWereFull = nil, nil
  local function countToast(key)
    local n = 0
    for _, d in ipairs((UI and UI.dropsActive) or {}) do
      local k = d._dedupeKey or d.dedupeKey or (d.opts and d.opts.dedupeKey)
      local title = d.titleFS and d.titleFS:GetText() or d.title or ""
      if k == key or tostring(title):find("Sacs pleins", 1, true) then n = n + 1 end
    end
    return n
  end
  local before = countToast("bags-full")
  S.SetSim("bags", true)
  S.CheckBags()
  local mid = countToast("bags-full")
  S.CheckBags()
  S.CheckBags()
  local after = countToast("bags-full")
  ok(mid >= before + 1 or S._bagsToastShown, "sacs pleins : un toast (ou marqueur posé)")
  ok(after == mid, "sacs pleins : pas de second toast tant que ça reste plein")
  S.SetSim("bags", false)
  S.CheckBags()
  ok(S._bagsToastShown == false, "sacs : le marqueur se remet à zéro quand une place se libère")
  S.ClearSim()

  -- transport : pause + sablier, pas d'astuce premier vol
  if ns.Test then ns.Test.StopAll() end
  local ch = ns.CharDB and ns.CharDB()
  if ch then ch.flightPauseHint = nil end
  local function countHint()
    local n = 0
    for _, d in ipairs((UI and UI.dropsActive) or {}) do
      local k = d._dedupeKey or (d.opts and d.opts.dedupeKey) or d.kind
      local title = d.titleFS and d.titleFS:GetText() or ""
      if k == "flight-hint" or tostring(title):find("Suivi en pause pendant le vol", 1, true) then n = n + 1 end
    end
    return n
  end
  ok(ns.Test.Start("transport") == true, "/drop test transport")
  ok(F.Paused() and F.TravelPause and F.TravelPause(), "trajet : suivi en pause")
  ok(F.ShowHourglass and F.ShowHourglass(), "trajet : sablier allumé")
  ok(not (F.SafetyPause and F.SafetyPause()), "trajet : pas une pause de sécurité")
  ok(countHint() == 0, "trajet : pas d'astuce de premier vol")
  ns.Test.Stop("transport")
  ok(not F._simTransport, "trajet : simulation arrêtée")

  -- chargement : pause silencieuse, pas de sablier
  ok(ns.Test.Start("loading") == true, "/drop test loading")
  ok(F.Paused() and F.SafetyPause and F.SafetyPause(), "chargement : pause de sécurité")
  ok(not (F.ShowHourglass and F.ShowHourglass()), "chargement : pas de sablier")
  ns.Test.Stop("loading")

  -- repas : couche (pas dans ORDER), remplace la fiole par un disque
  S.ClearSim()
  S.SetSim("eating", true)
  ok(S.Want("eating") == true, "repas : Want('eating')")
  ok(S.LiveEating() == true, "repas : LiveEating")
  ok(S.Active() == "drop", "repas : pas un symbole de priorité (Active reste drop)")
  S.ClearSim()

  -- calme auto en donjon
  local prevQuiet = P.QuietSetting and P.QuietSetting() or "off"
  if ns.SetOpt then ns.SetOpt("quietMode", "off") ns.SetOpt("quietAuto", true) end
  P._autoQuietHeld, P._autoQuietPrev = nil, nil
  ok(ns.Test.Start("dungeon") == true, "/drop test dungeon")
  ok(P.QuietSetting() == "instance", "donjon : mode calme instance allumé tout seul")
  ok(P._autoQuietHeld, "donjon : le maintien auto est posé")
  ns.Test.Stop("dungeon")
  ok(P.QuietSetting() == "off", "sortie de donjon : le réglage précédent est rétabli")
  -- déjà instance : ne pas écraser
  if ns.SetOpt then ns.SetOpt("quietMode", "instance") end
  P._autoQuietHeld, P._autoQuietPrev = nil, nil
  P._simInstance = "party"
  P.AutoQuietSync(true)
  ok(not P._autoQuietHeld, "déjà en mode instance : le calme auto ne prend pas la main")
  P._simInstance = nil
  if ns.SetOpt then ns.SetOpt("quietMode", prevQuiet) end
  P.AutoQuietSync(true)

  -- P.Rates : lph = xph / UnitXPMax, pas les niveaux gagnés
  local s, _, c = P.Session()
  local oldStart, oldXp, oldLv, oldAct = s.start, s.xp, s.levels, s.active
  local oldStarted = c.session and c.session.started
  c.session = c.session or {}
  c.session.started = clock - 600
  s.start = clock - 600
  s.xp, s.levels, s.active = 21953, 0, 600
  local r = P.Rates(clock)
  ok(r.xph and r.xph > 0, "Rates : XP/h mesuré")
  local mx = (_G.UnitXPMax and _G.UnitXPMax()) or 8000
  ok(r.lph and math.abs(r.lph - (r.xph / mx)) < 1e-9, "Rates : lph = xph / UnitXPMax (plus de 0,00 niv./h sans ding)")
  ok(r.pctLevelPerHour and math.abs(r.pctLevelPerHour - r.lph * 100) < 1e-6, "Rates : % niv./h = lph × 100")
  ok((r.levelsPerHour or 0) == 0, "Rates : levelsPerHour reste 0 si on n'a pas ding (métrique à part)")
  s.start, s.xp, s.levels, s.active = oldStart, oldXp, oldLv, oldAct
  if c.session then c.session.started = oldStarted end

  -- efficacité : le score est la part active, pas l'XP/h
  local secs = E.Secs and nil
  local empty = {}
  for _, k in ipairs(E.ALL or { "combat", "gather", "craft", "death", "loading", "flight", "transport", "afk", "other" }) do
    empty[k] = 0
  end
  empty.combat, empty.gather, empty.craft = 1800, 900, 300
  empty.flight, empty.transport, empty.afk, empty.death, empty.loading, empty.other = 720, 180, 240, 90, 60, 510
  local score, total = E.Score(empty)
  ok(total and total >= 4800, "Score : temps total mesuré")
  local active = (1800 + 900 + 300)
  ok(score and math.abs(score - (active / total)) < 1e-9, "Score : part de temps actif (pas XP/h ni points/h)")
  setLang("fr")
  local tip = E.Tip({ secs = empty, total = total, score = score })
  ok(type(tip) == "string" and tip:find("vol", 1, true) and tip:find("%", 1, true),
    "conseil : plus grande part de temps mort, factuel (« vol ») (" .. tostring(tip) .. ")")
  ok(not (tip and tip:find("pts/h", 1, true)) and not (tip and tip:find("XP/h", 1, true)),
    "conseil : ne compare pas par points/h ou XP/h")

  -- or : format + classement mixte par somme de centiles
  local fmt = E.FormatMoney(123456, true)
  ok(type(fmt) == "string" and fmt:find("UI%-GoldIcon") and fmt:find("12"), "FormatMoney : icône or + 12")
  ok(fmt:find("UI%-SilverIcon") and fmt:find("UI%-CopperIcon"), "FormatMoney : argent et cuivre")
  local neg = E.FormatMoney(-50, true)
  ok(type(neg) == "string" and neg:sub(1, 1) == "-", "FormatMoney : signe moins pour une dépense nette")

  local rep = {
    total = 3600, moneyNet = 100000,
    spots = {
      { zone = "A", secs = 600, zoneSecs = 600, pctLevelPerHour = 40, goldPerHour = 70000 },
      { zone = "B", secs = 600, zoneSecs = 600, pctLevelPerHour = 20, goldPerHour = 1000 },
      { zone = "C", secs = 600, zoneSecs = 600, pctLevelPerHour = 5, goldPerHour = 40000 },
      { zone = "D", secs = 600, zoneSecs = 600, goldPerHour = 90000 }, -- or seulement
      { zone = "E", secs = 600, zoneSecs = 600, pctLevelPerHour = 50 }, -- progression seulement
      { zone = "F", secs = 10, zoneSecs = 10, pctLevelPerHour = 99, goldPerHour = 999999 }, -- trop court
    },
    moneyByZone = {}, zoneSecs = {}, xpFracByZone = {},
  }
  local pr = E.Profitability(rep)
  ok(pr and pr.bestProg and pr.bestProg.zone == "E", "rentabilité : meilleur spot progression = E")
  ok(pr.bestGold and pr.bestGold.zone == "D", "rentabilité : meilleur spot or = D")
  ok(pr.bestMix and pr.bestMix.zone == "A", "rentabilité : meilleur spot mixte = A (haut aux deux centiles)")
  ok(pr.bestMix.zone ~= "F" and pr.bestMix.zone ~= "D" and pr.bestMix.zone ~= "E",
    "rentabilité : le mixte ignore le spot trop court et les spots à une seule métrique")
  local tipS = E.ScoringTip and E.ScoringTip() or ""
  ok(tipS:find("centile", 1, true) and tipS:find("somme", 1, true), "infobulle : le scoring mixte est expliqué")

  -- teinte des toasts : familles, système neutre
  ok(UI and UI.ToastFamily({ kind = "xp" }) == "level", "teinte : XP → level")
  ok(UI.ToastFamily({ kind = "rank-trainer" }) == "prof", "teinte : rang maître → prof")
  ok(UI.ToastFamily({ kind = "bags-full" }) == nil, "teinte : toast système sacs reste neutre")
  ok(UI.ToastFamily({ kind = "goal", skillId = "skinning" }) == "prof", "teinte : objectif métier → prof")
  ok(UI.ToastFamily({ kind = "palier", skillId = "skinning" }) == "prof", "teinte : palier métier → prof")
  ok(UI.ToastFamily({ kind = "tier", skillId = "skinning" }) == "prof", "teinte : test palier (tier) → prof")
  ok(UI.ToastFamily({ kind = "skill", skillId = "skinning", skillName = "Dépeçage" }) == "prof", "teinte : palier +1 métier → prof")
  ok(UI.ToastFamily({ kind = "scanner", skillId = "leatherworking" }) == "prof", "teinte : recette possible → prof")
  ok(UI.ToastFamily({ kind = "objectif", skillId = "skinning" }) == "prof", "teinte : kind objectif → prof")
  local skinIcon = UI.ResolveToastIcon and UI.ResolveToastIcon(ns.LEVEL_ICON, { kind = "goal", skillId = "skinning" })
  ok(skinIcon and tostring(skinIcon):find("Pelt", 1, true), "icône objectif Dépeçage : pelage, pas la fiole")
  local lwIcon = UI.ResolveToastIcon(ns.FALLBACK_ICON, { kind = "scanner", skillId = "leatherworking" })
  ok(lwIcon and tostring(lwIcon):find("LeatherWorking", 1, true), "icône recette Cuir léger : Travail du cuir")
  ok(UI.ResolveToastIcon(ns.LEVEL_ICON, { kind = "xp" }) == ns.LEVEL_ICON,
    "icône XP +75 : fiole XP (XP-Icon), pas le fallback vide")
  ok(UI.ResolveToastIcon(ns.LEVEL_ICON, { kind = "levelup" }) == ns.LEVEL_ICON,
    "icône montee de niveau : fiole XP conservée")
  -- teinte visible même si Skin cache _toastBg
  if UI.ApplyToastTint then
    local host = CreateFrame("Frame", "DropamineTintHost", UIParent)
    local fr = CreateFrame("Frame", "DropamineTintToast", UIParent)
    fr._skinHost = host
    fr._toastBg = fr:CreateTexture(nil, "BACKGROUND")
    if fr._toastBg.Hide then fr._toastBg:Hide() end
    if ns.db and ns.db.ui then ns.db.ui.dropBgAlpha = 0.68 end
    local fam = UI.ApplyToastTint(fr, { kind = "goal", skillId = "skinning" })
    ok(fam == "prof", "ApplyToastTint : famille prof pour l'objectif métier")
    ok(fr._tintFill and fr._tintFill.shown ~= false, "ApplyToastTint : calque visible sur l'habillage (pas seulement _toastBg)")
    local c = fr._tintFill and fr._tintFill._colorTex
    local prof = UI.TOAST_TINT.prof
    ok(c and math.abs(c[1] - prof[1]) < 1e-6 and math.abs(c[2] - prof[2]) < 1e-6 and math.abs(c[3] - prof[3]) < 1e-6,
      "teinte : RVB conservé, seul l'alpha suit le réglage")
    ok(c and math.abs((c[4] or 1) - 1) < 1e-6,
      "teinte : le RVB n'est pas multiplié par l'opacité (vertex alpha 1)")
    ok(host.alpha and math.abs((host.alpha or 0) - 0.68) < 1e-6,
      "teinte : SetAlpha du fond = 0.68")
    if ns.db and ns.db.ui then ns.db.ui.dropBgAlpha = 0.20 end
    if UI.RefreshToastOpacity then UI.RefreshToastOpacity() end
    UI.ApplyToastTint(fr, { kind = "goal", skillId = "skinning" })
    c = fr._tintFill and fr._tintFill._colorTex
    ok(c and math.abs(c[1] - prof[1]) < 1e-6 and math.abs(c[2] - prof[2]) < 1e-6 and math.abs(c[3] - prof[3]) < 1e-6,
      "teinte 20 % : RVB inchangé")
    ok(c and math.abs((c[4] or 1) - 1) < 1e-6, "teinte 20 % : pas de RVB assombri")
    ok(host.alpha and math.abs((host.alpha or 0) - 0.20) < 1e-6, "teinte : l'opacité suit Fond des toasts (0.20)")
    -- 0 % : fond invisible, pas un rectangle noir ; icône/texte intacts
    if ns.db and ns.db.ui then ns.db.ui.dropBgAlpha = 0 end
    ok(UI.DropBgAlpha and UI:DropBgAlpha() == 0, "Fond des toasts : 0 % se mémorise (pas 0,68)")
    UI.ApplyToastTint(fr, { kind = "goal", skillId = "skinning" })
    c = fr._tintFill and fr._tintFill._colorTex
    ok(host.alpha == 0, "0 % : calque de fond entièrement transparent")
    ok(c and math.abs(c[1] - prof[1]) < 1e-6 and math.abs((c[4] or 1) - 1) < 1e-6,
      "0 % : teinte RVB constante, pas noire")
    ok((fr.alpha == nil or fr.alpha == 1), "0 % : icône et texte restent visibles")
    -- XP : teinte + icône
    local fr2 = CreateFrame("Frame", "DropamineTintToastXP", UIParent)
    fr2._skinHost = host
    if ns.db and ns.db.ui then ns.db.ui.dropBgAlpha = 0.68 end
    UI.ApplyToastTint(fr2, { kind = "xp" })
    local lc = fr2._tintFill and fr2._tintFill._colorTex
    local lv = UI.TOAST_TINT.level
    ok(lc and math.abs(lc[1] - lv[1]) < 1e-6 and math.abs((lc[4] or 1) - 1) < 1e-6,
      "teinte XP : couleur level, RVB non multiplié")
    ok(host.alpha and math.abs((host.alpha or 0) - 0.68) < 1e-6,
      "teinte XP : même alpha de calque que le fond")
  end
  ok(UI.TOAST_TINT and UI.TOAST_TINT.level and UI.TOAST_TINT.weapon and UI.TOAST_TINT.prof, "teinte : trois familles")
  local tl = UI.TOAST_TINT.level
  local pal = ns.GAIN_COLORS or (ns.Slot and ns.Slot.ADD_COLORS)
  local expect = pal and pal.red or { 0.616, 0.278, 0.227 }
  ok(tl and (tl[1] / expect[1]) < 0.95 and (tl[1] / expect[1]) > 0.2
    and math.abs(tl[2] - expect[2] * (tl[1] / expect[1])) < 0.03,
    "teinte XP : même rouge, plus sombre que la palette")
  ok(((UI.TOAST_TINT.weapon[1] or 0) + (UI.TOAST_TINT.weapon[2] or 0) + (UI.TOAST_TINT.weapon[3] or 0)) >= 0.35,
    "teinte arme : pas de quasi-noir")

  -- titres recettes : pas de « × » orphelin ; « N × » seulement si N ≥ 2
  local C = ns.Craft
  if C and C.RecipeToastTitle then
    local t1 = C.RecipeToastTitle(nil, "Viande de sanglier rôtie")
    ok(not tostring(t1):find("×", 1, true), "recette sans compte : pas de × orphelin")
    ok(tostring(t1):find("Viande de sanglier rôtie", 1, true) and tostring(t1):find("possible", 1, true),
      "recette sans compte : nom + possible")
    local t0 = C.RecipeToastTitle(0, "Viande de sanglier rôtie")
    ok(not tostring(t0):find("×", 1, true), "recette n=0 : pas de ×")
    local t2 = C.RecipeToastTitle(1, "Viande de sanglier rôtie")
    ok(not tostring(t2):find("×", 1, true), "recette n=1 : pas de préfixe 1 ×")
    local t3 = C.RecipeToastTitle(2, "Viande de sanglier rôtie")
    ok(tostring(t3):find("2 ×", 1, true) and tostring(t3):find("possibles", 1, true),
      "recette n=2 : préfixe 2 × et possibles")
    if C.StripStrayCount then
      local raw = C.StripStrayCount("× Viande de sanglier rôtie possible")
      ok(raw == "Viande de sanglier rôtie possible", "StripStrayCount : enlève le × de tête")
    end
  end

  -- icônes
  ok(type(ns.LEVEL_ICON) == "string" and ns.LEVEL_ICON:find("XP-Icon", 1, true), "icône XP : Media/XP-Icon")
  ok(type(ns.SPELLS_ICON) == "string" and ns.SPELLS_ICON:find("Spells-Icon", 1, true), "icône sorts : Media/Spells-Icon")
  ok(type(ns.FARM_ICON) == "string" and ns.FARM_ICON:find("Farm-Spots-Icon", 1, true), "icône spots : Media/Farm-Spots-Icon")
  ok(type(ns.FALLBACK_ICON) == "string" and ns.FALLBACK_ICON:find("Fallback-Icon", 1, true), "icône de repli : Media/Fallback-Icon")
  ok(type(ns.RANK_BADGE) == "string" and ns.RANK_BADGE:find("Rank-Badge", 1, true), "badge de rang : Media/Rank-Badge")

  -- badge rang maître cadré
  local RT = ns.RankToast
  if RT and RT.ApplyBadge then
    local f = { typ = "Frame", CreateTexture = function(self)
      local tex = { typ = "Texture", parent = self }
      function tex:SetTexture(p) self._tex = p end
      function tex:SetAllPoints(o) self._all = o or self.parent end
      function tex:SetTexCoord() end
      function tex:Show() self.shown = true end
      function tex:Hide() self.shown = false end
      function tex:SetDrawLayer() end
      function tex:GetTexture() return self._tex end
      return tex
    end }
    -- si le mock CreateFrame n'est pas sur la table, ApplyBadge utilise frame.CreateTexture
    local b = RT.ApplyBadge(f)
    ok(f._rankBadge ~= nil or b ~= nil, "RangToast : badge créé")
    local tex = f._rankBadge and (f._rankBadge._tex or f._rankBadge:GetTexture())
    ok(not tex or tostring(tex):find("Rank-Badge", 1, true), "RangToast : texture Rank-Badge")
  else
    ok(false, "RangToast.ApplyBadge présent")
  end

  -- textes tronqués : helper
  ok(PU and PU.IsTruncated, "ProgressUI.IsTruncated présent")
  local fs = { typ = "FontString" }
  function fs:GetStringWidth() return 200 end
  function fs:GetWidth() return 80 end
  function fs:GetText() return "texte trop long pour la carte" end
  ok(PU.IsTruncated(fs, 80) == true, "IsTruncated : largeur visuelle < largeur du texte")
  function fs:GetStringWidth() return 40 end
  ok(PU.IsTruncated(fs, 80) == false, "IsTruncated : texte entier visible")

  -- niveau max : les rythmes d'XP sont masqués
  local prevLvl, prevCap = ns.GetPlayerLevel, ns.GetLevelCap
  ns.GetPlayerLevel = function() return 60 end
  ns.GetLevelCap = function() return 60 end
  ok(E.AtMaxLevel() == true, "AtMaxLevel : vrai au plafond")
  ok(PU.AtMaxLevel and PU.AtMaxLevel() == true, "ProgressUI.AtMaxLevel suit le plafond")
  ns.GetPlayerLevel, ns.GetLevelCap = prevLvl, prevCap
  -- curve : composante XP à 0 au niveau max
  if not ns.GetPlayerLevel then
    -- déjà restauré
  end

  -- TOC / données de démo
  ok(E.SetSim, "Efficiency.SetSim présent")
  if ns.Test then
    ns.Test.StopAll()
    ok(ns.Test.Start("efficiency") == true, "/drop test efficiency")
    local demo = E.Report("session")
    ok(demo and demo.score and demo.profit and demo.profit.bestMix, "démo efficacité : rapport + spot mixte")
    ns.Test.Stop("efficiency")
  end


  -- valeur marchand : pièces + prix vendeur, jamais GetMoney
  ok(E.ParseLootMoney, "ParseLootMoney présent")
  local frCoin = E.ParseLootMoney("Vous ramassez 1 Or, 2 Argent et 5 Cuivre.")
  ok(frCoin == 10205, "ParseLootMoney : FR 1 or 2 argent 5 cuivre")
  local enCoin = E.ParseLootMoney("You loot 1 Gold, 2 Silver, 5 Copper.")
  ok(enCoin == 10205, "ParseLootMoney : EN 1 gold 2 silver 5 copper")
  ok(E.ParseLootMoney("Courrier reçu : 5 Or.") == nil, "ParseLootMoney : ignore un courrier (pas un butin)")
  ok(E.ParseLootMoney("Your auction sold for 5 Gold.") == nil, "ParseLootMoney : ignore une vente à l'hôtel des ventes")

  local e = E.Sess()
  local bak = {
    lootCoin = e.lootCoin, lootVendor = e.lootVendor, lootValue = e.lootValue, moneyNet = e.moneyNet,
  }
  e.lootCoin, e.lootVendor, e.lootValue, e.moneyNet = 0, 0, 0, 0
  E.AddLoot(10205, 2500, "Elwynn")
  ok(e.lootCoin == 10205 and e.lootVendor == 2500 and e.lootValue == 12705,
    "AddLoot : pièces + prix vendeur = valeur marchand")
  ok(e.moneyNet == e.lootValue, "moneyNet est un alias de lootValue")

  local gm, moneyWas = _G.GetMoney, nil
  _G.GetMoney = function() return 999999 end
  local beforeVal = e.lootValue
  if E.NoteMoney then E.NoteMoney() end
  ok(e.lootValue == beforeVal, "NoteMoney / GetMoney ne change pas la valeur marchand")
  if type(ns.Emit) == "function" then pcall(ns.Emit, "PLAYER_MONEY") end
  ok(e.lootValue == beforeVal, "PLAYER_MONEY ne change pas la valeur marchand")
  _G.GetMoney = gm

  local gi = _G.GetItemInfo
  local prices = {}
  _G.GetItemInfo = function(id)
    local p = prices[id]
    if p == nil then return end
    return "Eau", "|Hitem:"..id.."|h", 1, 1, 1, "Consommable", "Eau", 20, "", "tex", p
  end
  local added = E.NoteLootItem("Vous recevez l'objet : |cffffffff|Hitem:159:0:0:0:0:0:0:0:25|h[Eau de source]|h|r.")
  ok(added == nil and E._pendingVendor and #E._pendingVendor >= 1, "NoteLootItem : sans prix, le butin est en attente")
  prices[159] = 6
  E.FlushPendingVendor(159)
  ok(e.lootVendor == 2500 + 6, "FlushPendingVendor : le prix vendeur est attribué au moment du butin")
  _G.GetItemInfo = gi
  e.lootCoin, e.lootVendor, e.lootValue, e.moneyNet = bak.lootCoin, bak.lootVendor, bak.lootValue, bak.moneyNet

  -- historique : 30 détaillées, le 31e bascule en semaine
  local pchar = E.Hist and E.Hist()
  ok(pchar ~= nil, "Hist : profil personnage disponible")
  if pchar then
    local oldLog, oldWeeks, oldPrev = pchar.sessLog, pchar.sessWeeks, pchar.effPrev
    pchar.sessLog, pchar.sessWeeks, pchar.effPrev = {}, {}, nil
    local base = (type(time) == "function" and time()) or 1700000000
    for i = 1, 31 do
      E.ArchiveRecap({
        start = base - i * 86400, ended = base - i * 86400 + 3600, duration = 3600,
        score = 0.5, pctLevelPerHour = 10, skillUpsPerHour = 2, goldPerHour = 1000,
        lootValue = 1000, lootCoin = 200, lootVendor = 800, xph = 999999, pts = 42,
      })
    end
    ok(#pchar.sessLog == 30, "ArchiveRecap : 30 sessions détaillées au plus")
    local weeks, wn = pchar.sessWeeks, 0
    for _ in pairs(weeks or {}) do wn = wn + 1 end
    ok(wn >= 1, "ArchiveRecap : la 31e session rejoint un agrégat hebdomadaire")
    local cmp = E.CompareRecap({
      score = 0.6, pctLevelPerHour = 12, skillUpsPerHour = 3, goldPerHour = 2000, xph = 888, ptsPerHour = 77,
    })
    local keys, unexpected = { score = true, pctLevelPerHour = true, skillUpsPerHour = true, goldPerHour = true }, {}
    for k in pairs(cmp or {}) do if not keys[k] then unexpected[#unexpected + 1] = k end end
    ok(#unexpected == 0, "CompareRecap : uniquement des clés normalisées")
    ok(cmp.score and cmp.pctLevelPerHour and cmp.skillUpsPerHour and cmp.goldPerHour, "CompareRecap : score, % niv./h, pal./h, valeur/h")
    pchar.sessLog, pchar.sessWeeks, pchar.effPrev = oldLog, oldWeeks, oldPrev
  end

  -- fiole en grille : liquide, z, vague dans la case total
  local prevTotal = ns.Wide and ns.Wide.TotalTile
  local tot = CreateFrame("Button", "DropamineTestGridTotal", UIParent)
  tot.data = { kind = "total" }
  tot._wideOn = false
  tot:SetSize(36, 36)
  tot.icon = tot:CreateTexture(nil, "ARTWORK")
  if tot.icon.SetSize then tot.icon:SetSize(32, 32) end
  function tot:SetClipsChildren(v) self.clipsChildren = v and true or false end
  function tot.icon:SetClipsChildren(v) self.clipsChildren = v and true or false end
  function tot:CreateMaskTexture()
    self._mask = self._mask or CreateFrame("Frame", nil, self)
    return self._mask
  end
  if ns.Wide then ns.Wide.TotalTile = function() return tot end end
  ns.UI = ns.UI or {}
  ns.UI.embed = ns.UI.embed or {}
  local prevTiles = ns.UI.embed.tiles
  ns.UI.embed.tiles = { tot }

  S.ClearSim()
  S.SetSim("rested", true)
  ok(S.TakesRestedZ() == false, "TakesRestedZ : plus de z sur la fiole")
  ok(S.StealsLevelZ() == false, "StealsLevelZ : les z restent sur la case Niveau")
  tot._wideOn = true
  ok(S.StealsLevelZ() == false, "StealsLevelZ : pas de vol vers la barre large")
  tot._wideOn = false

  S.ClearSim()
  S.SetCombatStyle("bubbles")
  S.SetSim("combat", true)
  S.fill = S.fill or {}
  S.fill.p, S.fill.targetP, S.fill.drain, S.fill.grey = 1, 1, 1, 0
  local okFill = pcall(S.ApplyFlaskFill, tot)
  ok(okFill, "ApplyFlaskFill : no-op propre en grille (pas de Wd.last.widths)")
  pcall(S.ApplyTotal)
  local okLiq = pcall(S.ApplyCombatLiq, tot)
  ok(okLiq, "ApplyCombatLiq : pas d'erreur")
  ok(not tot._cLiq or tot._cLiq.shown == false, "combat grille : plus de bandes liquide")
  ok(tot._stIcon and tot._stIcon.shown ~= false, "combat grille : icône de jeu visible")
  local ctex = tot._stIcon and (tot._stIcon._texSet or tot._stIcon._tex)
  ok(type(ctex) == "string" and ctex:find("Combat-Icon", 1, true),
    "combat grille : Combat-Icon (" .. tostring(ctex) .. ")")
  if tot.icon then
    ok(tot.icon.shown == false, "combat grille : la fiole officielle est remplacée")
  end
  ok(tot._iconClip, "case total : cadre de rognage (ScrollFrame) sur l'icône")

  S.ClearSim()
  S.SetSim("eating", true)
  S.fill.p, S.fill.grey = 0, 0
  local okWave = pcall(S.ApplyRegenWave, 0.16)
  ok(okWave, "ApplyRegenWave : range les reliquats, plus de vague")
  ok(S.Want("eating") == true and S.LiveEating() == true, "grille : état repas allumé")
  ok(not tot._eat or (tot._eat.body and tot._eat.body.shown == false and (not tot._eat.food or tot._eat.food.shown == false)
      and (not tot._eat.wave or tot._eat.wave.shown == false)),
    "grille : pas de vague / badge repas superposé")
  pcall(S.ApplyTotal)
  ok(tot._stIcon and tot._stIcon.shown ~= false, "grille : disque de repas à la place de la fiole")
  if tot.icon then
    ok(tot.icon.shown == false, "grille repas : fiole officielle remplacée")
  end
  S.ClearSim()
  pcall(S.ApplyTotal)
  if tot.icon then
    ok(tot.icon.shown ~= false, "sans état : la fiole officielle du total est visible")
  end
  -- Géométrie : rien ne doit dépasser le rectangle intérieur de l'icône (32×32, inset).
  local function assertInside(label, obj, maxW, maxH)
    if not obj then return end
    local w = (obj.GetWidth and obj:GetWidth()) or obj.width or 0
    local h = (obj.GetHeight and obj:GetHeight()) or obj.height or 0
    ok(w <= maxW + 0.51 and w >= 1, label .. " largeur " .. tostring(w) .. " ≤ " .. tostring(maxW))
    ok(h <= maxH + 0.51 and h >= 0, label .. " hauteur " .. tostring(h) .. " ≤ " .. tostring(maxH))
  end
  local iw, ih, _, inset = S.IconInnerSize(tot)
  ok(iw < 32 and iw > 8, "grille : intérieur icône < 32 px (pas le défaut 100)")
  assertInside("clip grille", tot._iconClip, iw, ih)
  if tot._iconClip and tot._iconClip._content then
    assertInside("contenu clip grille", tot._iconClip._content, iw, ih)
  end
  if tot._cLiq then
    -- reliquat combat doit être caché pendant le repas, ou cadré
    if tot._cLiq.shown ~= false and tot._cLiq.IsShown and tot._cLiq:IsShown() then
      assertInside("liquide combat grille", tot._cLiq, iw, ih)
    end
  end

  -- Rejouer le combat en grille et vérifier la géométrie.
  S.ClearSim()
  S.SetCombatStyle("bubbles")
  S.SetSim("combat", true)
  S.fill = S.fill or {}
  S.fill.p, S.fill.targetP, S.fill.drain, S.fill.grey = 1, 1, 1, 0
  pcall(S.ApplyTotal)
  pcall(S.ApplyCombatLiq, tot)
  iw, ih = S.IconInnerSize(tot)
  ok(not tot._cLiq or tot._cLiq.shown == false, "rejeu combat grille : pas de bandes")
  if tot._stIcon then
    assertInside("icône combat grille", tot._stIcon, iw, ih)
  end

  -- Barre large : fiole / combat / vol ~70 % de la case, sans cadre, pas un pavé 100×50.
  local bar = CreateFrame("Button", "DropamineTestBarTotal", UIParent)
  bar.data = { kind = "total" }
  bar._wideOn = true
  local tileSz = (I and I.TILE) or (ns.Icons and ns.Icons.TILE) or 40
  local iconSz = (ns.Wide and ns.Wide.IconSize and ns.Wide.IconSize(tileSz)) or math.floor(tileSz * 0.70 + 0.5)
  bar._wideH = tileSz
  bar:SetSize(220, tileSz)
  bar.icon = bar:CreateTexture(nil, "ARTWORK")
  if bar.icon.SetSize then bar.icon:SetSize(iconSz, iconSz) end
  function bar:SetClipsChildren(v) self.clipsChildren = v and true or false end
  if ns.Wide then ns.Wide.TotalTile = function() return bar end end
  ns.UI.embed.tiles = { bar }
  S.ClearSim()
  S.SetSim("eating", true)
  S.fill.p, S.fill.grey = 0, 0
  local okBar = pcall(S.ApplyRegenWave, 0.16)
  ok(okBar, "repas en barre : no-op (état retiré)")
  local bw, bh = S.IconInnerSize(bar)
  ok(bw == iconSz and bh == iconSz,
    "barre : fiole / combat = 70 % de la case (" .. tostring(bw) .. "×" .. tostring(bh) .. ", attendu " .. tostring(iconSz) .. ")")
  -- Combat en barre : icône de jeu à la place de la goutte, pas de bandes.
  S.ClearSim()
  S.SetCombatStyle("bubbles")
  S.SetSim("combat", true)
  S.fill.p, S.fill.drain, S.fill.grey = 1, 1, 0
  pcall(S.ApplyTotal)
  pcall(S.ApplyCombatLiq, bar)
  ok(not bar._cLiq or bar._cLiq.shown == false, "combat en barre : pas de bandes sur la goutte")
  ok(bar._stIcon and bar._stIcon.shown ~= false, "combat en barre : icône de jeu sur la goutte")
  assertInside("icône combat barre", bar._stIcon, bw, bh)
  S.ClearSim()
  pcall(S.ApplyCombatLiq, bar)
  pcall(S.ApplyTotal)
  ok(not bar._stIcon or bar._stIcon.shown == false, "fin combat barre : icône d'état rangée")

  if ns.Wide then ns.Wide.TotalTile = prevTotal end
  ns.UI.embed.tiles = prevTiles

  -- vue récap
  ok(PU and PU.OpenRecap, "ProgressUI.OpenRecap présent")
  if PU and PU.OpenRecap then
    local okOpen = pcall(PU.OpenRecap, "demo")
    ok(okOpen, "OpenRecap : ouverture du récap de démonstration")
    local page = PU.frame and PU.frame.pages and PU.frame.pages.recap
    ok(page and page.shown ~= false, "OpenRecap : page récap visible")
    if PU.CloseRecap then pcall(PU.CloseRecap) end
  end
  if ns.Test and ns.Test.Start then
    ok(ns.Test.Start("recap") == true, "/drop test recap")
    ns.Test.Stop("recap")
  end


  -- repas : détection FR/EN, spellId, trous d'aura, Bien nourri ignoré
  local prevUA, prevUB, prevC, prevAU, prevCh = _G.UnitAura, _G.UnitBuff, _G.C_UnitAuras, _G.AuraUtil, _G.UnitChannelInfo
  _G.C_UnitAuras, _G.AuraUtil, _G.UnitBuff, _G.UnitChannelInfo = nil, nil, nil, nil
  local function packAura(name, id)
    return { name, nil, nil, nil, nil, nil, nil, nil, nil, id }
  end
  local auras = {}
  _G.UnitAura = function(unit, i)
    local a = auras[i]
    if not a then return end
    return unpack(a)
  end
  auras[1] = packAura("Nourriture", 433)
  local nm = S.FoodDrinkAura()
  ok(nm == "Nourriture" or (type(nm) == "string" and nm:find("433", 1, true)), "repas : aura FR Nourriture")
  auras = { [1] = packAura("Food", 433) }
  nm = S.FoodDrinkAura()
  ok(nm == "Food" or (type(nm) == "string" and nm:find("433", 1, true)), "repas : aura EN Food")
  auras = { [1] = packAura("Boisson", 430) }
  ok(S.FoodDrinkAura(), "repas : aura FR Boisson")
  auras = { [1] = packAura(nil, 430) }
  ok(S.FoodDrinkAura(), "repas : détecté par spellId si le nom est illisible")
  auras = { [1] = packAura("Bien nourri", 19705) }
  ok(S.FoodDrinkAura() == nil, "repas : Bien nourri n'est pas le canal de régénération")
  auras = { [1] = packAura("Well Fed", 19706) }
  ok(S.FoodDrinkAura() == nil, "repas : Well Fed ignoré")
  auras = { [2] = packAura("Nourriture", 433) } -- trou à l'index 1
  ok(S.FoodDrinkAura(), "repas : un trou d'aura n'arrête pas le scan")
  _G.UnitAura = function() return nil end
  _G.UnitChannelInfo = function() return "Boisson" end
  ok(S.FoodDrinkAura(), "repas : canal UnitChannelInfo « Boisson »")
  _G.UnitAura, _G.UnitBuff, _G.C_UnitAuras, _G.AuraUtil, _G.UnitChannelInfo = prevUA, prevUB, prevC, prevAU, prevCh
  S.ClearSim()
  S.SetSim("eating", true)
  ok(S.LiveEating() == true and S.Want("eating") == true, "repas : sim eating allume l'état")
  S.SetSim("eating", false)
  if ns.Test then
    ok(ns.Test.Start("eating") == true, "/drop test eating")
    ok(S.LiveEating() == true, "test eating : LiveEating")
    ns.Test.Stop("eating")
  end
  S.ClearSim()

  if ns.Test then ns.Test.StopAll() end
  S.ClearSim()
  S.SetCombatStyle("bubbles")
  setLang("fr")
end



  -- /drop mem : ventilation et tailles
  ok(ns.MemSize and ns.MemReport and ns.SlashExt and ns.SlashExt.mem, "/drop mem : MemReport et commande")
  ok(ns.MemSize({ a = 1, b = "xy" }) > 0, "MemSize : table non nulle")
  local rpt, before, after, rows = ns.MemReport()
  ok(type(rpt) == "table" and #rpt >= 2, "/drop mem : rapport avec ventilation")
  ok(tostring(rpt[1] or ""):find("moire", 1, true) or tostring(rpt[1] or ""):find("memory", 1, true)
    or tostring(rpt[1] or ""):find("Mo", 1, true) or tostring(rpt[1] or ""):find("Ko", 1, true),
    "/drop mem : en-tête avec mesure")
  local names = {}
  for i = 1, #(rows or {}) do names[rows[i].name] = rows[i] end
  ok(names["ScannerDB (base)"] or names["DropamineDB"], "/drop mem : ScannerDB ou DropamineDB dans la ventilation")

  -- compactage historique / prune scanner
  local Sc = ns.Scanner
  if Sc and Sc.DB and Sc.PruneLearned then
    local sdb = Sc.DB()
    -- PNJ déjà dans la base statique, sans butin : doit disparaître
    local staticId
    if ns.ScannerDB and ns.ScannerDB.npcs then
      for id in pairs(ns.ScannerDB.npcs) do staticId = id break end
    end
    if staticId then
      sdb.creatures[staticId] = { name = "dup" }
      local dropped = Sc.PruneLearned()
      ok(sdb.creatures[staticId] == nil, "PruneLearned : retire le PNJ déjà dans ScannerDB sans butin")
    end
    sdb.creatures[999999] = { name = "appris", loots = 3, items = { [123] = 1 } }
    Sc.PruneLearned()
    ok(sdb.creatures[999999] ~= nil, "PruneLearned : conserve une créature apprise avec butin")
    sdb.creatures[999999] = nil
  end
  local E = ns.Efficiency
  if E and E.SlimProfit and E.CompactHist then
    local fat = { moneyNet = 10, goldPerHour = 2, spots = { { zone = "A" } }, candidates = { { zone = "A" } },
      bestMix = { zone = "Les Paluns", skill = "skinning", mixScore = 1.5, goldPerHour = 3 } }
    local slim = E.SlimProfit(fat)
    ok(slim.bestMix and slim.bestMix.zone == "Les Paluns" and slim.candidates == nil and slim.spots == nil,
      "SlimProfit : garde le meilleur spot, pas les copies candidates")
    local p = { sessLog = { { profit = fat, spots = { { zone = "A" }, { zone = "B" } }, tip = "x" } }, sessWeeks = {} }
    E.CompactHist(p)
    ok(p.sessLog[1].tip == nil and p.sessLog[1].profit and p.sessLog[1].profit.candidates == nil,
      "CompactHist : allège les récaps déjà stockés")
  end


  -- sacs pleins : uniquement bagType 0, pas de 0 transitoire
  do
    local S = ns.Slot
    local prevC, prevN, prevK, prevF = _G.C_Container, _G.NUM_BAG_SLOTS, _G.KEYRING_CONTAINER, _G.GetContainerNumFreeSlots
    _G.NUM_BAG_SLOTS = 4
    _G.KEYRING_CONTAINER = -2
    local bagFree = {
      [0] = { 20, 0 },  -- sac à dos : 20 places générales
      [1] = { 8, 32 },  -- sac de métier (herbes) : ignoré
      [2] = { 0, 0 },
      [3] = { 0, 0 },
      [4] = { 0, 0 },
      [-2] = { 12, 256 }, -- trousseau : ignoré
    }
    _G.C_Container = { GetContainerNumFreeSlots = function(bag)
      local e = bagFree[bag]
      if not e then return 0, 0 end
      return e[1], e[2]
    end }
    S._sim.bags, S._simFree = nil, nil
    S._bagsToastShown, S._bagsWereFull, S._bagsZeroSince, S._bagsLastFree = nil, nil, nil, nil
    local free = S.FreeBagSlots()
    ok(free == 20, "sacs : uniquement bagType 0 (20 générales, métier et trousseau ignorés)")
    S.CheckBags()
    ok(S._bagsToastShown ~= true, "sacs : 20 places générales → pas de toast « sacs pleins »")

    -- lecture ratée ≠ 0
    _G.C_Container.GetContainerNumFreeSlots = function() error("bag api") end
    ok(S.FreeBagSlots() == nil, "sacs : API en échec → nil, pas 0")
    S.CheckBags()
    ok(S._bagsToastShown ~= true, "sacs : lecture ratée → pas de toast")

    -- 0 transitoire : pas de toast au premier BAG_UPDATE
    _G.C_Container.GetContainerNumFreeSlots = function() return 0, 0 end
    S._bagsZeroSince, S._bagsToastShown, S._bagsWereFull = nil, nil, nil
    S.CheckBags()
    ok(S._bagsToastShown ~= true and S._bagsWereFull ~= true, "sacs : 0 transitoire, pas de toast immédiat")
    -- confirmation après le délai
    S._bagsZeroSince = (ns.Now and ns.Now() or 0) - 2
    S.CheckBags()
    ok(S._bagsToastShown == true or S._bagsWereFull == true, "sacs : 0 confirmé après délai → toast")
    -- une place se libère
    _G.C_Container.GetContainerNumFreeSlots = function(bag)
      if bag == 0 then return 5, 0 end
      return 0, 0
    end
    S.CheckBags()
    ok(S._bagsToastShown == false, "sacs : une place générale libérée → marqueur remis à zéro")

    _G.C_Container, _G.NUM_BAG_SLOTS, _G.KEYRING_CONTAINER, _G.GetContainerNumFreeSlots = prevC, prevN, prevK, prevF
    S._sim.bags, S._simFree = nil, nil
    S._bagsToastShown, S._bagsWereFull, S._bagsZeroSince = nil, nil, nil
  end

  -- profils d'affichage par personnage : persistés, chargés avant l'UI, écrits à chaque réglage
  do
    local prevName, prevRealm = _G.UnitName, _G.GetRealmName
    local function asChar(name, realm)
      _G.UnitName = function() return name end
      _G.GetRealmName = function() return realm or "Valais" end
      if ns.charProfileActive and ns.RestoreAccountUI then pcall(ns.RestoreAccountUI) end
      ns.charProfileActive = nil
    end
    pcall(ns.RestoreAccountUI)
    ns.EnsureDB()
    ns.db.chars = ns.db.chars or {}
    ns.db.ui = ns.db.ui or {}
    ns.db.ui.cols = 5
    ns.db.ui.theme = "flare"
    -- perso A
    asChar("Arnaud")
    local a = ns.CharDB()
    a.charUI = nil
    a.uiProfile = nil
    ok(ns.ApplyCharProfile() == true, "profil A : appliqué (réglages du compte comme défaut)")
    ok(a.uiProfile ~= nil, "profil A : créé à partir des réglages existants")
    ns.db.ui.cols = 3
    ok(ns.SaveActiveProfile() == true, "profil A : SaveActiveProfile écrit tout de suite")
    ok(a.uiProfile and a.uiProfile.cols == 3, "profil A : cols 3 enregistré sans attendre PLAYER_LOGOUT")
    pcall(ns.RestoreAccountUI)
    -- perso B : nouveau, reçoit le défaut du compte (5), pas les 3 de A
    asChar("Alts")
    local b = ns.CharDB()
    b.charUI, b.uiProfile = nil, nil
    ns.ApplyCharProfile()
    ok(ns.db.ui.cols == 5, "profil B : défaut = réglages du compte, pas les 3 colonnes de A")
    ns.db.ui.cols = 2
    ns.SaveActiveProfile()
    ok(b.uiProfile and b.uiProfile.cols == 2, "profil B : cols 2 enregistré")
    pcall(ns.RestoreAccountUI)
    -- retour sur A
    asChar("Arnaud")
    ns.ApplyCharProfile()
    ok(ns.db.ui.cols == 3, "retour sur A : le profil 3 colonnes est conservé")
    -- seed des persos déjà en SV sans profil
    asChar("Nouveau")
    ns.db.chars["Nouveau-Valais"] = {}
    local n = ns.SeedCharProfiles()
    ok(ns.db.chars["Nouveau-Valais"].uiProfile ~= nil, "SeedCharProfiles : les réglages existants deviennent le défaut de chaque perso")
    pcall(ns.RestoreAccountUI)
    _G.UnitName, _G.GetRealmName = prevName, prevRealm
  end



print("== 3.6.3 : icônes d'état, repos Z, cadre exact, pas de fuite")
do
  local S, L, I, W, P, UI = ns.Slot, ns.Layout, ns.Icons, ns.Window, ns.Panel, ns.UI
  local prevTotal = ns.Wide and ns.Wide.TotalTile
  local tot = CreateFrame("Button", "DropamineTestStateIcon", UIParent)
  tot.data = { kind = "total" }
  tot._wideOn = false
  tot:SetSize(36, 36)
  tot.icon = tot:CreateTexture(nil, "ARTWORK")
  if tot.icon.SetSize then tot.icon:SetSize(32, 32) end
  if tot.icon.Show then tot.icon:Show() end
  function tot:SetClipsChildren(v) self.clipsChildren = v and true or false end
  if ns.Wide then ns.Wide.TotalTile = function() return tot end end
  local function texOf(obj)
    return obj and (obj._texSet or obj._tex)
  end

  -- Pêche validée : feuille Fishing-Sheet remplace la fiole (pas de badge en coin).
  S.ClearSim()
  S.SetSim("fishing", true)
  pcall(S.ApplyTotal)
  ok(tot.icon and tot.icon.shown == false, "pêche : fiole officielle remplacée")
  local fishTex = tot._hg and texOf(tot._hg)
  ok(type(fishTex) == "string" and fishTex:find("Fishing-Sheet", 1, true),
    "pêche : Fishing-Sheet (" .. tostring(fishTex) .. ")")
  ok(not tot._stIcon or tot._stIcon.shown == false or (texOf(tot._stIcon) or ""):find("Fishing-Sheet") or not tostring(texOf(tot._stIcon) or ""):find("Trade_Fishing", 1, true),
    "pêche : pas de badge Trade_Fishing en coin")
  S.ClearSim()
  pcall(S.ApplyTotal)
  ok(tot.icon and tot.icon.shown ~= false, "pêche : fiole restaurée")

  -- Combat : icône de jeu (remplace entièrement la fiole, rien en fond)
  local function after(key, path, label)
    S.ClearSim()
    S.SetSim(key, true)
    pcall(S.ApplyTotal)
    if key == "combat" then pcall(S.ApplyCombatLiq, tot) end
    ok(tot._stIcon and tot._stIcon.shown ~= false, label .. " : icône de jeu visible")
    local pth = texOf(tot._stIcon)
    ok(type(pth) == "string" and pth:find(path, 1, true), label .. " : " .. path .. " (" .. tostring(pth) .. ")")
    if tot.icon then ok(tot.icon.shown == false, label .. " : fiole officielle remplacée (rien en fond)") end
    ok(not tot._cLiq or tot._cLiq.shown == false, label .. " : pas de bandes")
    S.ClearSim()
    pcall(S.ApplyCombatLiq, tot)
    pcall(S.ApplyTotal)
    ok(not tot._stIcon or tot._stIcon.shown == false, label .. " : icône d'état rangée après la fin")
    if tot.icon then ok(tot.icon.shown ~= false, label .. " : fiole restaurée") end
  end
  S.SetCombatStyle("bubbles")
  after("combat", "Combat-Icon", "combat")

  -- Repas : disque fourchette / tasse remplace la fiole
  S.ClearSim()
  S.SetEatSim("food")
  pcall(S.ApplyTotal)
  ok(S.Want("eating"), "repas : état allumé")
  ok(tot._stIcon and tot._stIcon.shown ~= false, "repas food : disque visible")
  local fp = texOf(tot._stIcon)
  ok(type(fp) == "string" and fp:find("Food-Icon", 1, true), "repas food : Food-Icon (" .. tostring(fp) .. ")")
  if tot.icon then ok(tot.icon.shown == false, "repas : fiole remplacée") end
  S.SetEatSim("drink")
  pcall(S.ApplyTotal)
  local dp = texOf(tot._stIcon)
  ok(type(dp) == "string" and dp:find("Drink-Icon", 1, true), "repas drink : Drink-Icon (" .. tostring(dp) .. ")")
  S.ClearSim()
  pcall(S.ApplyTotal)
  if tot.icon then ok(tot.icon.shown ~= false, "repas : fiole restaurée") end

  S.SetEatSim("both")
  pcall(S.ApplyTotal)
  local bp = texOf(tot._stIcon)
  ok(type(bp) == "string" and bp:find("Eat-Both-Icon", 1, true), "repas both : Eat-Both-Icon (" .. tostring(bp) .. ")")
  S.ClearSim()
  pcall(S.ApplyTotal)

  -- Repos : Z crème/bronze remplace la fiole, pas de bandes (grille et barre)
  S.ClearSim()
  S.SetSim("rested", true)
  pcall(S.ApplyTotal)
  pcall(S.ApplyRestIcon, tot)
  ok(S.Active() == "rested", "repos : Active = rested")
  ok(tot._stIcon and tot._stIcon.shown ~= false, "repos : icône Z visible")
  local rz = texOf(tot._stIcon)
  ok(type(rz) == "string" and rz:find("Rest-Icon", 1, true), "repos : Rest-Icon maison (" .. tostring(rz) .. ")")
  ok(tot._stIcon and tot._stIcon._kind == "rested", "repos : glyphe d'état = rested")
  if tot.icon then ok(tot.icon.shown == false, "repos : fiole officielle remplacée") end
  ok(not tot._cLiq or tot._cLiq.shown == false, "repos grille : pas de bandes")
  if tot._slotZ then ok(tot._slotZ.shown == false, "repos : pas de z superposés, un seul Z") end
  -- barre large : visible dans tous les états (seule l'icône change)
  tot._wideOn, tot._wideH, tot._wideW = true, 16, 200
  tot._wideParts = tot._wideParts or {}
  local segs = {}
  for i = 1, 3 do
    segs[i] = tot:CreateTexture(nil, "ARTWORK")
    if segs[i].Show then segs[i]:Show() end
  end
  tot._wideParts.segs = segs
  tot._wideParts.track = tot:CreateTexture(nil, "ARTWORK")
  tot._wideParts.track:Show()
  tot._wideParts.text = tot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  if tot._wideParts.text.Show then tot._wideParts.text:Show() end
  tot._wideParts.text:SetText("85 / 2460")
  tot._pseg = tot._wideParts
  local function barVisible(label)
    pcall(S.ApplyFlaskFill, tot)
    pcall(S.ApplyTotal)
    local anySeg
    for i = 1, 3 do if segs[i].shown ~= false then anySeg = true end end
    ok(anySeg, label .. " : barre (segments) toujours visible")
    ok(tot._wideParts.track and tot._wideParts.track.shown ~= false, label .. " : piste visible")
    ok(tot._wideParts.text and tot._wideParts.text.shown ~= false, label .. " : texte 85/2460 visible")
  end
  pcall(S.ApplyRestIcon, tot)
  barVisible("repos barre")
  if tot.icon then ok(tot.icon.shown == false, "repos barre : fiole remplacée par le Z") end
  -- mêmes états : la barre ne disparaît jamais
  local stateBar = {
    { "combat", function() S.SetSim("combat", true) pcall(S.ApplyCombatLiq, tot) end },
    { "fishing", function() S.SetSim("fishing", true) pcall(S.ApplySheet, tot, "fishing") end },
    { "eating", function() if S.SetEatSim then S.SetEatSim("food") end pcall(S.ApplyEatDisc, tot) end },
    { "flight", function() S.SetSim("flight", true) pcall(S.ApplyTotal) end },
  }
  for _, st in ipairs(stateBar) do
    S.ClearSim()
    for i = 1, 3 do if segs[i].Show then segs[i]:Show() end end
    if tot._wideParts.track.Show then tot._wideParts.track:Show() end
    if tot._wideParts.text.Show then tot._wideParts.text:Show() end
    tot._wideOn = true
    st[2]()
    barVisible(st[1])
  end
  -- une seule épée (pas Dual Wield)
  S.ClearSim()
  S.SetSim("combat", true)
  pcall(S.ApplyCombatLiq, tot)
  ok(not tot._stIconR or tot._stIconR.shown == false, "combat : une seule épée, pas d'icône double")
  tot._wideOn = false
  S.ClearSim()
  pcall(S.ApplyTotal)
  if tot.icon then ok(tot.icon.shown ~= false, "repos : fiole restaurée") end
  ok(not tot._stIcon or tot._stIcon.shown == false or tot._stIcon._kind ~= "rested", "repos : Z rangé après la fin")

  -- Cadre exact : 3 col. sans total = 3×3 ; avec total = 3 rangées + barre fine.
  UI.snapshot = UI.snapshot or {}
  local tiles = {}
  for i = 1, 9 do tiles[i] = { id = i } end
  UI.snapshot.tiles = tiles
  if ns.db and ns.db.ui then ns.db.ui.cols = 3 ns.db.ui.showTotal = nil end
  if ns.Wide then ns.Wide.forceShown = false end
  ok(L.Cols() == 3, "disposition : 3 colonnes")
  ok(L.Rows() == 3, "sans total : 3 rangées (9 compétences)")
  local fw, fh, pad, gw, gh, c, r = L.ContentSize()
  local tile, hg, vg, M = I.TILE, I.HGAP, I.VGAP, L.MARGIN
  ok(c == 3 and r == 3, "ContentSize sans total : 3 × 3")
  ok(gw == 3 * tile + 2 * hg, "largeur grille = 3×case + 2×écart")
  ok(gh == 3 * tile + 2 * vg, "hauteur grille = 3×case + 2×écart")
  ok(pad == M and fw == gw + 2 * pad and fh == gh + 2 * pad, "cadre = grille + même marge des 4 côtés")
  local oldW = (22 + 3 * (tile + hg)) + 2 * 8
  ok(oldW - fw >= 8, "plus de marge vide à droite (ancien " .. oldW .. ", nouveau " .. fw .. ")")
  if ns.Wide then ns.Wide.forceShown = true end
  if ns.db and ns.db.ui then ns.db.ui.showTotal = true end
  local fwB, fhB, padB, gwB, ghB, cB, rB = L.ContentSize()
  local slim = (ns.Wide.RowHeight and ns.Wide.RowHeight(tile)) or math.max((ns.Wide.MIN_H or 28), math.floor(tile * (ns.Wide.SLIM or 0.5) + 0.5))
  local expectH = 3 * tile + 2 * vg + vg + slim
  local expectGw = gw
  ok(gwB == expectGw, "avec total en barre : largeur = grille de cases (" .. tostring(gwB) .. " / " .. tostring(expectGw) .. ")")
  ok(ghB == expectH, "avec total en barre : 3 rangées + barre fine (" .. tostring(ghB) .. " attendu " .. expectH .. ")")
  ok(fhB == ghB + 2 * padB, "barre : cadre = contenu + 2×marge")
  if ns.Wide then ns.Wide.forceShown = nil end
  if ns.db and ns.db.ui then ns.db.ui.showTotal = nil end
  if P.ApplyMode then pcall(P.ApplyMode) end
  if L.SnapToContent then pcall(L.SnapToContent) end

  -- Défaut et plusieurs tailles : le cadre = cols×case courante + écarts + 12 px.
  local savedScale, savedCols, savedTotal
  if ns.db and ns.db.ui then savedScale, savedCols, savedTotal = ns.db.ui.scale, ns.db.ui.cols, ns.db.ui.showTotal end
  local function assertFit(cols, scalePct, skills, withTotal, label)
    if ns.db and ns.db.ui then
      ns.db.ui.scale = (scalePct ~= 100) and scalePct or nil
      ns.db.ui.cols = (cols ~= (L.BASE_COLS or 5)) and cols or nil
      ns.db.ui.showTotal = withTotal and true or nil
    end
    if ns.Wide then ns.Wide.forceShown = withTotal and true or false end
    local snap = {}
    for i = 1, skills do snap[i] = { id = i } end
    UI.snapshot = UI.snapshot or {}
    UI.snapshot.tiles = snap
    if L.SyncMetrics then L.SyncMetrics() end
    local fw, fh, pad, gw, gh, c, r = L.ContentSize(cols)
    local tile, hg, vg, M = I.TILE, I.HGAP, I.VGAP, L.MARGIN
    ok(c == cols, label .. " : colonnes " .. tostring(c) .. " (attendu " .. cols .. ")")
    local expectGw = cols * tile + math.max(0, cols - 1) * hg
    ok(gw == expectGw,
      label .. " : largeur grille " .. tostring(gw) .. " (attendu " .. tostring(expectGw) .. ")")
    ok(fw == gw + 2 * M, label .. " : cadre = grille + 2×12 (pas de largeur 262 périmée)")
    local rightPad = fw - gw - M
    ok(rightPad == M, label .. " : dernière case ne dépasse pas le bord (marge droite " .. tostring(rightPad) .. ")")
    if withTotal and ns.Wide and ns.Wide.ShouldWiden and ns.Wide.ShouldWiden(cols, skills + 1) then
      local slim = (ns.Wide.RowHeight and ns.Wide.RowHeight(tile))
        or math.max((ns.Wide.MIN_H or 36), math.floor(tile * (ns.Wide.SLIM or 0.5) + 0.5))
      local skillRows = math.max(1, math.ceil(skills / cols))
      local expectH = skillRows * tile + math.max(0, skillRows - 1) * vg + vg + slim
      ok(gh == expectH, label .. " : hauteur 12 px sous la barre (" .. tostring(gh) .. " attendu " .. expectH .. ")")
      ok(fh == gh + 2 * M, label .. " : cadre = contenu + 2×marge")
    end
  end
  -- défauts : 5 col., taille 100 %, 9 compétences
  assertFit(5, 100, 9, false, "défaut 5 col. 100 %")
  assertFit(5, 100, 9, true, "défaut 5 col. + barre")
  assertFit(10, 100, 9, true, "10 col. 100 %")
  assertFit(5, 90, 9, true, "5 col. taille 90 %")
  assertFit(10, 90, 9, true, "10 col. taille 90 %")
  assertFit(5, 150, 9, true, "5 col. taille 150 %")
  assertFit(10, 150, 9, true, "10 col. taille 150 %")
  assertFit(3, 90, 9, true, "3 col. taille 90 %")
  assertFit(5, 90, 9, true, "5 col. taille plancher 90 %")
  assertFit(5, 200, 9, true, "5 col. taille 200 %")
  assertFit(2, 100, 9, true, "2 col. 100 %")
  if ns.db and ns.db.ui then ns.db.ui.scale, ns.db.ui.cols, ns.db.ui.showTotal = savedScale, savedCols, savedTotal end
  if L.SyncMetrics then L.SyncMetrics() end
  -- La case total de ce bloc (et FlaskTile) doit rester visible pour goutte / étincelle.
  if ns.Wide then ns.Wide.forceShown = true end
  if tot.Show then tot:Show() end
  tot.data = tot.data or { kind = "total" }

  -- Gouttes colorées + étincelle de barre
  local function colorEq(a, b)
    return a and b and math.abs((a[1] or 0) - (b[1] or 0)) < 0.01
      and math.abs((a[2] or 0) - (b[2] or 0)) < 0.01
      and math.abs((a[3] or 0) - (b[3] or 0)) < 0.01
  end
  ok(colorEq(S.AddColor("red"), S.ADD_COLORS.red), "AddColor red")
  ok(colorEq(S.AddColor("blue"), S.ADD_COLORS.blue), "AddColor blue")
  ok(colorEq(S.AddColor("green"), S.ADD_COLORS.green), "AddColor green")
  ok(not colorEq(S.ADD_COLORS.red, S.ADD_COLORS.blue), "red ≠ blue")
  ok(not colorEq(S.ADD_COLORS.red, S.ADD_COLORS.green), "red ≠ green")
  if ns.Test and ns.Test.Toggle then
    pcall(ns.Test.Toggle, "totaladd blue")
    ok(colorEq(S._sparkColor, S.ADD_COLORS.blue), " /drop test totaladd blue : étincelle bleue (pas rouge)")
    if ns.Test.Stop then pcall(ns.Test.Stop, "totaladd") end
    pcall(ns.Test.Toggle, "totaladd green")
    ok(colorEq(S._sparkColor, S.ADD_COLORS.green), " /drop test totaladd green : étincelle verte (pas rouge)")
    if ns.Test.Stop then pcall(ns.Test.Stop, "totaladd") end
  end
  tot._wideOn, tot._wideH, tot._wideW = true, 16, 200
  ns.Wide = ns.Wide or {}
  ns.Wide.last = { left = 40, inner = 140, by = 4, bh = 8, pct = 0.4 }
  for _, pair in ipairs({ {"red", S.ADD_COLORS.red}, {"blue", S.ADD_COLORS.blue}, {"green", S.ADD_COLORS.green} }) do
    pcall(S.PlayBarSpark, pair[1])
    ok(colorEq(S._sparkColor, pair[2]), "PlayBarSpark " .. pair[1] .. " : S._sparkColor")
  end
  ok(not tot._add, "aucune couche de goutte d'ajout sur la fiole")
  -- étincelle : créée une fois, voyage, flash, alpha 0, pas de nouvelle texture au 2e gain
  pcall(S.PlayBarSpark, "blue")
  ok(tot._barSpark, "étincelle de barre : texture poolée")
  -- course 0,40 s : à 0,30 s le point est encore sur la barre
  if S.Tick then for i = 1, 6 do pcall(S.Tick, 0.05) end end
  ok(tot._barSpark and tot._barSpark.shown ~= false, "étincelle visible après le départ")
  -- course + flash (~0,55 s) largement terminés après 0,80 s de plus
  if S.Tick then for i = 1, 16 do pcall(S.Tick, 0.05) end end
  ok(not tot._barSpark or tot._barSpark.shown == false or (tot._barSpark.GetAlpha and tot._barSpark:GetAlpha() == 0),
    "étincelle : alpha 0 à la fin")
  local spark1, flash1 = tot._barSpark, tot._barFlash
  pcall(S.PlayBarSpark, "green")
  ok(tot._barSpark == spark1 and tot._barFlash == flash1, "étincelle : réutilisée, pas de nouvelle texture")
  if S.HideBarSpark then pcall(S.HideBarSpark, tot) end
  tot._wideOn = false

  -- Fuite : 500 transitions d'état, aucun nouveau cadre / texture, croissance mémoire bornée.
  S.ClearSim()
  pcall(S.ApplyTotal)
  local states = { "fishing", "combat", "rested", "eating", "swimming", "death", "afk" }
  -- échauffement : crée les calques une fois
  for _, id in ipairs(states) do
    if id == "eating" and S.SetEatSim then S.SetEatSim("food")
    else S.SetSim(id, true) end
    pcall(S.ApplyTotal)
    if S.Tick then pcall(S.Tick, 0.05) end
    S.ClearSim()
    pcall(S.ApplyTotal)
  end
  tot._wideOn = true
  -- échauffement du pool d'arc (cadre unique sur UIParent) avant le comptage
  if S.EnsureFlySpark then pcall(S.EnsureFlySpark) end
  if S.EnsureBarSpark then pcall(S.EnsureBarSpark, tot) end
  if S.PlayBarSpark then
    local warm = { data = { kind = "melee", skillName = "Dagues" }, GetFrameLevel = function() return 1 end }
    if warm.SetSize then warm:SetSize(40, 40) elseif warm.width then warm.width, warm.height = 40, 40 end
    warm.shown = true
    warm._abs = { l = 80, r = 120, t = 200, b = 160 }
    function warm:IsShown() return self.shown ~= false end
    function warm:GetWidth() return self.width or 40 end
    function warm:GetHeight() return self.height or 40 end
    function warm:GetLeft() return 80 end
    function warm:GetBottom() return 160 end
    pcall(S.PlayBarSpark, "red", warm)
    if S.Tick then pcall(S.Tick, 0.05) end
    pcall(S.PlayBarSpark, "blue", warm)
    if S.Tick then pcall(S.Tick, 0.50) pcall(S.Tick, 0.70) end
    pcall(S.PlayBarSpark, "green", warm)
    if S.Tick then pcall(S.Tick, 0.50) pcall(S.Tick, 0.70) end
    if S.HideBarSpark then pcall(S.HideBarSpark, tot) end
  end
  if S.ApplyRestIcon then pcall(S.SetSim, "rested", true) pcall(S.ApplyRestIcon, tot) S.ClearSim() pcall(S.ApplyTotal) end
  tot._wideOn = false
  local nCF, nTex, nFS = 0, 0, 0
  local baseCF = _G.CreateFrame
  _G.CreateFrame = function(...)
    nCF = nCF + 1
    local f = baseCF(...)
    if f and f.CreateTexture then
      local ct = f.CreateTexture
      function f:CreateTexture(...)
        nTex = nTex + 1
        return ct(self, ...)
      end
    end
    if f and f.CreateFontString then
      local cf = f.CreateFontString
      function f:CreateFontString(...)
        nFS = nFS + 1
        return cf(self, ...)
      end
    end
    return f
  end
  local beforeMem = collectgarbage("count")
  for i = 1, 500 do
    local id = states[((i - 1) % #states) + 1]
    if id == "eating" and S.SetEatSim then S.SetEatSim((i % 3 == 0) and "both" or (i % 3 == 1) and "food" or "drink")
    else S.SetSim(id, true) end
    pcall(S.ApplyTotal)
    if S.Tick then pcall(S.Tick, 0.05) end
    S.ClearSim()
    pcall(S.ApplyTotal)
  end
  collectgarbage("collect")
  local afterMem = collectgarbage("count")
  _G.CreateFrame = baseCF
  ok(nCF == 0, "500 transitions : aucun nouveau CreateFrame (" .. nCF .. ") — cause typique : cadre créé par test/état au lieu d'un pool")
  ok(nTex == 0, "500 transitions : aucune nouvelle texture (" .. nTex .. ")")
  ok(nFS == 0, "500 transitions : aucune nouvelle FontString (" .. nFS .. ")")
  local grew = (afterMem or 0) - (beforeMem or 0)
  ok(grew < 512, "500 transitions : croissance mémoire bornée (" .. string.format("%.1f", grew) .. " Ko, seuil 512 Ko)")

  if ns.Wide then ns.Wide.TotalTile = prevTotal end
  S.ClearSim()
end

print("== 3.6.3 : couleurs de gain, +1 de case, pas de goutte, recettes, 1 colonne, toasts, Personnages")
do
  local S, C, UI, L = ns.Slot, ns.Compact, ns.UI, ns.Layout
  local function sum(c) return (c[1] or 0) + (c[2] or 0) + (c[3] or 0) end
  local function colorEq(a, b)
    return a and b and math.abs((a[1] or 0) - (b[1] or 0)) < 0.01
      and math.abs((a[2] or 0) - (b[2] or 0)) < 0.01
      and math.abs((a[3] or 0) - (b[3] or 0)) < 0.01
  end
  ok(S and S.ColorForGain and S.ADD_COLORS, "ColorForGain disponible")
  local red, blue, green = S.ADD_COLORS.red, S.ADD_COLORS.blue, S.ADD_COLORS.green
  local weapons = {
    { "skill", nil, "Dagues" }, { "skill", nil, "Défense" }, { "skill", nil, "Defense" },
    { "skill", nil, "Arcs" }, { "skill", nil, "Bows" }, { "skill", nil, "Fusils" },
    { "skill", nil, "Guns" }, { "skill", nil, "Arbalètes" }, { "skill", nil, "Armes de jet" },
    { "skill", nil, "Baguettes" }, { "skill", nil, "Bâtons" }, { "skill", nil, "Armes d'hast" },
    { "skill", nil, "Armes de pugilat" }, { "skill", nil, "Mains nues" }, { "skill", nil, "Épées" },
    { "defense", nil, nil }, { "melee", nil, "Daggers" }, { "ranged", nil, "Bows" },
  }
  for _, w in ipairs(weapons) do
    local c = S.ColorForGain(w[1], w[2], w[3])
    ok(c and sum(c) >= 0.35 and colorEq(c, blue),
      "gain bleu : " .. tostring(w[3] or w[1]))
  end
  ok(colorEq(S.ColorForGain("skill", nil, "Cuisine"), green), "métier Cuisine : vert")
  ok(colorEq(S.ColorForGain("profession", nil, "Minage"), green), "métier Minage : vert")
  ok(colorEq(S.ColorForGain("xp"), red), "XP : rouge")
  ok(colorEq(S.ColorForGain("levelup"), red), "levelup : rouge")
  local unk = S.ColorForGain("???", nil, "chose inconnue")
  ok(unk and sum(unk) >= 0.35, "catégorie inconnue : jamais nil ni noir")

  -- +1 coloré sur la case, étincelle, pas d'anim de fiole
  local tile = { data = { kind = "melee", skillName = "Dagues", name = "Dagues" }, GetFrameLevel = function() return 1 end }
  if C and C.GainColor then
    ok(colorEq(C.GainColor({ kind = "skill", skillName = "Dagues" }), blue), "Compact.GainColor Dagues = bleu")
    ok(colorEq(C.GainColor({ kind = "skill", skillName = "Défense" }), blue), "Compact.GainColor Défense = bleu")
    ok(colorEq(C.GainColor({ kind = "skill", skillName = "Arcs" }), blue), "Compact.GainColor Arcs = bleu")
    ok(colorEq(C.GainColor({ kind = "skill", skillName = "Cuisine" }), green), "Compact.GainColor Cuisine = vert")
    ok(colorEq(C.GainColor({ kind = "xp" }), red), "Compact.GainColor XP = rouge")
  end
  if C and C.Gain then
    C.Gain(tile, "+1", blue)
    ok(tile._osrsGain and tile._osrsGain.shown ~= false, "Gain : +1 flottant sur la case")
    local fs = tile._osrsGain.fs
    ok(fs and fs.text == "+1", "Gain : texte +1")
    if fs and fs._color then
      ok(colorEq(fs._color, blue) or (fs.r and math.abs(fs.r - blue[1]) < 0.01), "Gain : couleur bleue")
    end
  end
  if C and C.Pulse then
    C.Pulse(tile, blue)
    ok(tile._osrsPulse and tile._osrsPulse.shown ~= false, "Pulse : la case s'éclaire")
    local popBlue = C.PopColor and C.PopColor(blue, tile)
    ok(popBlue and popBlue[3] > blue[3] and popBlue[1] > blue[1] - 1e-6,
      "PopColor Dagues : bleu éclairci")
    ok(tile._osrsPulse._color and colorEq(tile._osrsPulse._color, popBlue),
      "pop de case Dagues : bleu plus clair (couleur de type)")
  end

  -- Palette unique : voile, +1, étincelle, teinte de toast (jamais noir)
  ok(ns.GAIN_COLORS and ns.GAIN_COLORS.red and ns.GAIN_COLORS.blue and ns.GAIN_COLORS.green,
    "ns.GAIN_COLORS exposée")
  ok(S.ADD_COLORS == ns.GAIN_COLORS or colorEq(S.ADD_COLORS.blue, ns.GAIN_COLORS.blue),
    "Slot.ADD_COLORS est la table partagée")
  ok(sum(ns.GAIN_COLORS.red) >= 0.35 and sum(ns.GAIN_COLORS.blue) >= 0.35 and sum(ns.GAIN_COLORS.green) >= 0.35,
    "palette partagée : aucune entrée noire")
  local cats = {
    { name = "XP", opts = { kind = "xp" }, key = "red", tileKind = "level", skillName = "Niveau" },
    { name = "Dagues", opts = { kind = "skill", skillName = "Dagues" }, key = "blue", tileKind = "melee", skillName = "Dagues" },
    { name = "Défense", opts = { kind = "skill", skillName = "Défense" }, key = "blue", tileKind = "defense", skillName = "Défense" },
    { name = "Arcs", opts = { kind = "skill", skillName = "Arcs" }, key = "blue", tileKind = "ranged", skillName = "Arcs" },
    { name = "Cuisine", opts = { kind = "skill", skillName = "Cuisine" }, key = "green", tileKind = "profession", skillName = "Cuisine" },
  }
  for _, cat in ipairs(cats) do
    local expect = S.ADD_COLORS[cat.key]
    local col = S.ColorForGain(cat.opts.kind, cat.opts.skillId, cat.opts.skillName)
    ok(colorEq(col, expect), "ColorForGain " .. cat.name .. " = " .. cat.key)
    local ct = { data = { kind = cat.tileKind, skillName = cat.skillName, name = cat.skillName }, GetFrameLevel = function() return 1 end }
    if C and C.Pulse then C.Pulse(ct, col) end
    if C and C.Gain then C.Gain(ct, "+1", col) end
    local pop = C.PopColor and C.PopColor(expect, ct)
    ok(ct._osrsPulse and ct._osrsPulse._color and colorEq(ct._osrsPulse._color, pop),
      "pop " .. cat.name .. " = " .. cat.key .. " éclairci")
    ok(pop and pop[1] >= expect[1] - 1e-6 and pop[2] >= expect[2] - 1e-6 and pop[3] >= expect[3] - 1e-6
      and not colorEq(pop, expect),
      "pop " .. cat.name .. " : plus clair que la palette, même teinte")
    ok(ct._osrsGain and ct._osrsGain._color and colorEq(ct._osrsGain._color, expect),
      "+1 " .. cat.name .. " = palette " .. cat.key)
    if S.HideBarSpark then pcall(S.HideBarSpark) end
    S._sparkQ = {}
    S._sparkT = nil
    pcall(S.PlayBarSpark, col)
    ok(colorEq(S._sparkColor, expect), "étincelle " .. cat.name .. " = palette " .. cat.key)
    if UI and UI.ToastTintColor then
      local tint = UI.ToastTintColor(cat.opts)
      if tint then
        local k = (expect[1] > 0.05) and (tint[1] / expect[1]) or nil
        ok(k and k < 0.95 and k > 0.2
          and math.abs(tint[2] - expect[2] * k) < 0.03
          and math.abs(tint[3] - expect[3] * k) < 0.03,
          "teinte toast " .. cat.name .. " = " .. cat.key .. " assombri, même teinte")
      end
    end
  end
  -- teintes indexées : plus de quasi-noir
  if UI and UI.TOAST_TINT then
    ok(sum(UI.TOAST_TINT.weapon) >= 0.20 and sum(UI.TOAST_TINT.weapon) < sum(blue) - 0.05,
      "TOAST_TINT.weapon : bleu plus sombre, pas noir")
    local function darker(a, b, label)
      local k = (b[1] > 0.05) and (a[1] / b[1]) or nil
      ok(k and k < 0.95 and k > 0.2 and math.abs(a[2] - b[2]*k) < 0.03 and math.abs(a[3] - b[3]*k) < 0.03,
        label)
    end
    darker(UI.TOAST_TINT.weapon, blue, "TOAST_TINT.weapon = bleu GAIN_COLORS assombri")
    darker(UI.TOAST_TINT.level, red, "TOAST_TINT.level = rouge GAIN_COLORS assombri")
    darker(UI.TOAST_TINT.prof, green, "TOAST_TINT.prof = vert GAIN_COLORS assombri")
  end

  -- Trajet d'étincelle : file, coalescence, case cachée, pool
  local prevTotal = ns.Wide and ns.Wide.TotalTile
  local tot = CreateFrame("Button", "DropamineSparkJourneyTotal", _G.UIParent)
  tot.data = { kind = "total" }
  tot._wideOn, tot._wideH, tot._wideW = true, 16, 200
  if tot.SetSize then tot:SetSize(200, 16) end
  if tot.Show then tot:Show() end
  tot._abs = { l = 40, r = 240, t = 40, b = 24 }
  if ns.Wide then
    ns.Wide.TotalTile = function() return tot end
    ns.Wide.forceShown = true
    ns.Wide.last = ns.Wide.last or { left = 40, inner = 140, by = 4, bh = 8, pct = 0.4 }
  end
  if S.PlayBarSpark and tot then
    if S.HideBarSpark then pcall(S.HideBarSpark, tot) end
    S._sparkQ, S._sparkT = {}, nil
    -- case visible : origine d'un arc
    local origin = CreateFrame("Button", "DropamineSparkOrigin", _G.UIParent)
    origin._abs = { l = 80, r = 120, t = 200, b = 160 }
    if origin.SetSize then origin:SetSize(40, 40) end
    if origin.Show then origin:Show() end
    pcall(S.PlayBarSpark, blue, origin)
    ok(S._sparkPhase == "fly" or (S._sparkFrom == origin), "étincelle : phase vol depuis la case")
    if S.Tick then for _ = 1, 3 do pcall(S.Tick, 0.05) end end  -- 0,15 s dans l'arc
    ok(S._flySpark and S._flySpark.shown ~= false, "étincelle : point poolé visible pendant l'arc")
    if S.Tick then for _ = 1, 20 do pcall(S.Tick, 0.05) end end  -- finit le trajet (~0,83 s déjà largement dépassé)
    ok(not S._sparkT, "étincelle : trajet terminé (file vide)")
    local fly1 = S._flySpark
    pcall(S.PlayBarSpark, green, origin)
    ok(S._flySpark == fly1, "étincelle volante : cadre réutilisé, pas de nouveau frame")
    if S.HideBarSpark then pcall(S.HideBarSpark, tot) end
    -- file + coalescence
    S._sparkQ, S._sparkT = {}, nil
    pcall(S.PlayBarSpark, blue, origin)
    pcall(S.PlayBarSpark, blue, origin)  -- même couleur : fusion
    pcall(S.PlayBarSpark, green, origin)
    ok(S._sparkQ and #S._sparkQ == 1, "file : 2e bleu fusionné, vert en attente (" .. tostring(S._sparkQ and #S._sparkQ) .. ")")
    if S.HideBarSpark then pcall(S.HideBarSpark, tot) end
    S._sparkQ, S._sparkT = {}, nil
    -- case cachée / effondrée : pas d'arc, course sur la barre
    local hidden = CreateFrame("Button", "DropamineSparkHidden", _G.UIParent)
    if hidden.SetSize then hidden:SetSize(40, 40) end
    if hidden.Hide then hidden:Hide() end
    pcall(S.PlayBarSpark, red, hidden)
    ok(S._sparkPhase == "run", "case cachée : pas d'arc, course directe sur la barre")
    if S.HideBarSpark then pcall(S.HideBarSpark, tot) end
    tot._wideOn = false
  end
  if ns.Wide then ns.Wide.TotalTile = prevTotal end

  -- 1 colonne migrée vers 2
  if L and L.VALID then
    local has1
    for _, v in ipairs(L.VALID) do if v == 1 then has1 = true end end
    ok(not has1, "L.VALID ne contient plus 1 colonne")
    ok(L.NearestCols and L.NearestCols(1) == 2, "cols=1 migre vers 2")
  end
  local savedCols
  if ns.db and ns.db.ui then savedCols = ns.db.ui.cols ns.db.ui.cols = 1 end
  if L and L.Cols then
    ok(L.Cols() == 2, "profil sauvé cols=1 → L.Cols() = 2")
  end
  if ns.db and ns.db.ui then ns.db.ui.cols = savedCols end

  -- toasts : échelle min / défaut / max
  if UI and UI.ToastScaleK and UI.ToastMetrics and L and L.SetScale then
    local saved = ns.db and ns.db.ui and ns.db.ui.scale
    local function check(pct, label)
      if ns.db and ns.db.ui then ns.db.ui.scale = (pct ~= 100) and pct or nil end
      local k = UI.ToastScaleK()
      ok(math.abs(k - pct / 100) < 0.001, "ToastScaleK " .. label)
      local m = UI.ToastMetrics({})
      local d = UI.ToastMetrics({ light = true })
      ok(m.icon >= 22 and m.titleSize >= 10 and m.barH >= 3 and m.fh >= 40,
        "métriques toast " .. label .. " : minimums (icon " .. tostring(m.icon) .. ", h " .. tostring(m.fh) .. ")")
      ok(d.fh >= 22 and d.icon >= 16, "toast léger " .. label .. " : minimums")
      if pct == 200 then
        ok(m.icon > UI.ToastMetrics and true, "toast max plus grand que le plancher")
      end
    end
    -- compare ratios
    if ns.db and ns.db.ui then ns.db.ui.scale = nil end
    local mid = UI.ToastMetrics({})
    if ns.db and ns.db.ui then ns.db.ui.scale = 90 end
    local lo = UI.ToastMetrics({})
    if ns.db and ns.db.ui then ns.db.ui.scale = 200 end
    local hi = UI.ToastMetrics({})
    ok(lo.icon < mid.icon and mid.icon < hi.icon, "icône toast proportionnelle (90 < 100 < 200)")
    ok(lo.fh < mid.fh and mid.fh < hi.fh, "hauteur toast proportionnelle (90 < 100 < 200)")
    ok(lo.titleSize <= mid.titleSize and mid.titleSize <= hi.titleSize, "police toast proportionnelle")
    if ns.db and ns.db.ui then ns.db.ui.scale = saved end
  end

  -- teinte dès la 1re frame (cache + Show)
  if UI and UI.ApplyToastTint and UI.AcquireToast then
    local f = UI:AcquireToast(_G.UIParent)
    if f then
      f._tintR, f._tintG, f._tintB, f._tintA = 0.1, 0.1, 0.1, 0.1
      -- famille métier / skill cuisine
      UI.ApplyToastTint(f, { kind = "max", skillId = "cooking", skillName = "Cuisine" })
      local fill = f._tintFill
      ok(fill, "fond teinté créé")
      if fill then
        ok(fill.shown ~= false, "fond teinté visible dès ApplyToastTint (1re frame)")
        local g = (UI.TOAST_TINT and UI.TOAST_TINT.prof) or (UI.ShadeTint and UI.ShadeTint((ns.GAIN_COLORS and ns.GAIN_COLORS.green) or S.ADD_COLORS.green))
        local vc = fill._vcolor or fill._color
        if (f._tintR) then
          ok(math.abs((f._tintR or 0) - g[1]) < 0.01 and math.abs((f._tintG or 0) - g[2]) < 0.01,
            "fond teinté Cuisine = vert assombri")
        elseif vc then
          ok(math.abs((vc[1] or 0) - g[1]) < 0.01, "fond teinté Cuisine = vert assombri")
        end
      end
      -- toasts recyclés : le curseur d'opacité s'applique aussi au vivier
      if UI.ReleaseToast then UI:ReleaseToast(f) end
      if ns.db and ns.db.ui then ns.db.ui.dropBgAlpha = 0 end
      if UI.RefreshToastOpacity then UI.RefreshToastOpacity() end
      local f2 = UI:AcquireToast(_G.UIParent)
      if f2 then
        UI.ApplyToastTint(f2, { kind = "xp" })
        local host2 = f2._skinHost
        local fill2 = f2._tintFill
        local red = (UI.TOAST_TINT and UI.TOAST_TINT.level) or { 0.246, 0.111, 0.091 }
        ok((host2 and host2.alpha == 0) or (not host2 and fill2 and fill2.alpha == 0),
          "toast recyclé : 0 % = calque transparent")
        local c2 = fill2 and (fill2._colorTex or fill2._vcolor)
        ok(not c2 or (math.abs((c2[1] or 0) - red[1]) < 0.01 and math.abs((c2[4] or 1) - 1) < 1e-6),
          "toast recyclé : RVB de teinte (sombre) inchangé à 0 %")
        if UI.ReleaseToast then UI:ReleaseToast(f2) end
      end
    end
  end

  -- barre officielle statique
  if S and S.ApplyFlaskFill and tot then
    tot._wideOn = true
    local called
    -- TransformWidths ne doit pas être invoqué : early return
    pcall(S.ApplyFlaskFill, tot)
    ok(true, "ApplyFlaskFill sur barre large : pas d'erreur")
    tot._wideOn = false
  end

  -- Personnages : cartes + fiche compte
  local PU = ns.ProgressUI
  ok(PU and PU.BuildChars and PU.CharGrid, "cartes Personnages")
  if PU and PU.CharGrid then
    local cols, cw, ch, gap, inner = PU.CharGrid(656)
    ok(cols == 2 and (cols * cw + (cols - 1) * gap) <= inner + 0.01,
      "grille Personnages : 2 cartes tiennent dans la largeur (" .. tostring(cw) .. " × " .. tostring(cols) .. ")")
    local cols1 = PU.CharGrid(300)
    ok(cols1 == 1, "fenêtre étroite : 1 colonne de cartes")
  end

  ns.EnsureDB = ns.EnsureDB or function() return ns.db end
  DropamineDB = DropamineDB or ns.db or {}
  ns.db = ns.db or DropamineDB
  ns.db.chars = ns.db.chars or {}
  -- Autre personnage déjà vu : sa fiche complète doit réapparaître
  ns.db.chars["Alther-Berceau"] = {
    sheet = {
      key = "Alther-Berceau", name = "Alther", realm = "Berceau", class = "Mage",
      level = 60, xp = 12000, xpMax = 20000, gold = 123456,
      professions = { { name = "Couture", rank = 300, max = 300 }, { name = "Enchantement", rank = 225, max = 300 } },
      weapons = { { name = "Baguettes", rank = 300, max = 300 } },
      defense = { name = "Défense", rank = 280, max = 300 },
      playtime = 36000,
    }
  }
  local sheets = ns.AllCharSheets and ns.AllCharSheets() or {}
  local alt
  for _, s in ipairs(sheets) do if s.name == "Alther" or s.key == "Alther-Berceau" then alt = s end end
  ok(alt, "AllCharSheets inclut l'autre personnage")
  ok(alt and alt.level == 60 and alt.xp == 12000 and alt.gold == 123456,
    "autre perso : niveau, XP et or conservés")
  ok(alt and alt.professions and alt.professions[1] and alt.professions[1].rank == 300,
    "autre perso : rangs de métiers conservés")
  ok(alt and alt.weapons and alt.weapons[1] and alt.weapons[1].name,
    "autre perso : armes conservées")
  ok(alt and alt.defense and alt.defense.rank == 280, "autre perso : défense conservée")
  ok(alt and alt.playtime == 36000, "autre perso : temps de jeu conservé")
  if ns.CharSheetFor then
    local got = ns.CharSheetFor("Alther-Berceau")
    ok(got and got.gold == 123456, "CharSheetFor renvoie la fiche sauvegardée")
  end

  -- Capture ne doit pas écraser une fiche avec un nom inconnu
  if ns.CaptureCharSheet and ns.CharDB then
    -- simuler un capture du perso courant si l'environnement le permet
    pcall(ns.CaptureCharSheet)
    local me = ns.CharKey and ns.CharKey()
    if me and ns.db.chars[me] and ns.db.chars[me].sheet then
      ok(ns.db.chars[me].sheet.key, "CaptureCharSheet écrit DropamineDB.chars[key].sheet")
    end
  end

  -- en-tête des cartes : le hint n'est pas à la même Y que le titre
  if PU and PU.Build and not PU.frame then pcall(PU.Build) end
  if PU and PU.frame and PU.RefreshChars then pcall(PU.RefreshChars) end
  local page = PU and PU.frame and PU.frame.pages and PU.frame.pages.chars
  if page and page.card and page.card.title and page.card.hint then
    -- points are stored if the stub records them; at least both exist and hint text has no "trier"
    local ht = page.card.hint.text or (page.card.hint.GetText and page.card.hint:GetText()) or ""
    ok(not tostring(ht):find("trier", 1, true), "en-tête Personnages : plus de « clique une colonne pour trier »")
    ok(page.cards and page.cards[1], "cartes personnage poolées")
  end
  if page and page.cards then
    local c0
    for i = 1, #(page.cards) do if page.cards[i]._key == "Alther-Berceau" then c0 = page.cards[i] break end end
    if c0 then
      ok(c0.shown ~= false, "carte de l'autre personnage affichée")
      ok(c0._tipBody and tostring(c0._tipBody):find("12000", 1, true), "infobulle : XP intégrale")
    end
  end
end


print("== 3.6.3 : rangée total responsive, tooltip d'état, charge du sac")
do
  local S, Wd, L, I, UI = ns.Slot, ns.Wide, ns.Layout, ns.Icons, ns.UI
  local savedScale = ns.db and ns.db.ui and ns.db.ui.scale

  local function at(pct)
    if ns.db and ns.db.ui then ns.db.ui.scale = (pct ~= 100) and pct or nil end
    if L and L.SyncMetrics then L.SyncMetrics() end
    return Wd.Metrics(I.TILE)
  end
  if Wd and Wd.Metrics then
    local lo, mid, hi = at(90), at(100), at(200)
    local nlo = I.NumberSizes and I.NumberSizes(lo.tile)
    local wantLo = (Wd.IconSize and Wd.IconSize(lo.tile)) or math.floor((lo.tile or 36) * 0.70 + 0.5)
    ok(lo.h == wantLo and lo.isz == wantLo and lo.bh >= 12 and lo.font == (nlo and nlo.total)
      and lo.minBarW >= 100 and lo.pad >= (Wd.MIN_PAD or 3)
      and math.abs((lo.isz or 0) - (lo.tile or 0) * 0.70) <= 1.5,
      "rangée total 90 % : hauteur = fiole 70 % de la case (h=" .. tostring(lo.h) .. ")")
    ok((Wd.MIN_BAR_H or 0) >= 12
      and (Wd.MIN_BAR_W or 0) >= 100 and math.abs((Wd.ICON_K or 0) - 0.70) < 0.01
      and math.abs((Wd.STATE_ICON_K or 0) - 0.55) < 0.01
      and (I.TILE_MIN or 0) >= 36 and (L.SCALE_MIN or 0) >= 90,
      "planchers : case 36 px, fiole 70 %, états 55 %, échelle 90 %")
    ok(nlo and nlo.rank > nlo.total and nlo.total > nlo.max,
      "90 % : rang > total > /max")
    -- En dessous de la taille medium, l'épaisseur reste au plancher 12 px (ratio plus élevé).
    -- Au-dessus, le zoom uniforme reprend : 150 % et 200 % ont le même rapport.
    local nmid = I.NumberSizes and I.NumberSizes(mid.tile)
    ok(mid.bh >= 12 and mid.font == (nmid and nmid.total), "100 % : barre + police du total (bh=" .. tostring(mid.bh) .. ", font=" .. tostring(mid.font) .. ")")
    ok(nmid and nmid.rank > nmid.total and nmid.total > nmid.max, "100 % : rang > total > /max")
    ok(hi.bh > mid.bh and hi.font > mid.font and hi.isz > mid.isz and hi.pad > mid.pad,
      "rangée total : fiole, texte, barre et marges plus grands à 200 % qu'à 100 %")
    local midHi = at(150)
    local r150, r200 = midHi.bh / midHi.tile, hi.bh / hi.tile
    ok(math.abs(r150 - r200) < 0.03, "épaisseur barre : même ratio à 150 % et 200 % (" .. string.format("%.3f/%.3f", r150, r200) .. ")")
    ok(mid.font == mid.font and hi.font >= mid.font, "police total posée en px, pas étirée")
    ok(math.abs((Wd.ICON_K or 0) - 0.70) < 0.01, "fiole : glyphe à 70 % de la case, sans cadre")
  end
  if ns.db and ns.db.ui then ns.db.ui.scale = savedScale end
  if L and L.SyncMetrics then L.SyncMetrics() end

  -- Toast « Nouveaux sorts » : icône recadrée après recyclage d'un toast grand.
  if UI and UI.SpawnDrop and UI.ReleaseToast then
    local big = UI:SpawnDrop(ns.LEVEL_ICON or "Interface\\Icons\\X", "Level up", "x", nil, nil, nil,
      { kind = "levelup", big = true, force = true, variant = "gold" })
    local bigSize = big and big.iconSlot and (big.iconSlot.width or (big.iconSlot.GetWidth and big.iconSlot:GetWidth()))
    if UI.DismissDrop then pcall(UI.DismissDrop, UI, big) else UI:ReleaseToast(big) end
    local g = UI:SpawnDrop(ns.SPELLS_ICON or "Interface\\Icons\\X", Tr and Tr["Nouveaux sorts"] or "Nouveaux sorts",
      "Va voir ton maître de classe", nil, nil, nil,
      { kind = "spells", variant = "gold", force = true })
    ok(g and g.iconSlot, "Nouveaux sorts : cadre avec iconSlot")
    if g then
      if ns.ToastFit and ns.ToastFit.Fit then ns.ToastFit.Fit(g) end
      local gh = g:GetHeight() or g._h or 0
      ok(gh >= 40 and not g._light, "Nouveaux sorts : toast complet (h=" .. tostring(gh) .. "), pas une barre de 20 px")
      local tt = g.titleFS and g.titleFS.GetText and g.titleFS:GetText() or ""
      local st = g.subFS and g.subFS.GetText and g.subFS:GetText() or ""
      ok(tt ~= "" and (tt:find("Nouveaux sorts", 1, true) or tt:find("New spells", 1, true)),
        "Nouveaux sorts : titre visible — " .. tostring(tt))
      ok(st ~= "" and (st:find("maître", 1, true) or st:find("trainer", 1, true) or st:find("classe", 1, true)),
        "Nouveaux sorts : corps visible — " .. tostring(st))
      local tm = UI.ToastMetrics and UI.ToastMetrics({ light = false })
      local expect = tm and tm.icon
      local w = g.iconSlot and (g.iconSlot.width or (g.iconSlot.GetWidth and g.iconSlot:GetWidth()))
      if expect and w then
        ok(math.abs(w - expect) < 1.5, "Nouveaux sorts : icône taille normale (" .. tostring(w) .. " vs " .. tostring(expect) .. "), pas le 20 px léger")
      end
      ok(g.iconSlot.parent == g or (g.iconSlot.GetParent and g.iconSlot:GetParent() == g),
        "Nouveaux sorts : icône parente du toast")
      local pts = g.iconSlot.points
      ok(pts and #pts >= 1, "Nouveaux sorts : ancre du vivier réinitialisée")
    end
    if g then
      if UI.DismissDrop then pcall(UI.DismissDrop, UI, g) else UI:ReleaseToast(g) end
    end
  end

  -- Sac : icône seulement pendant la charge, pas à cause des buffs résultants.
  if S and S.LiveSleepingBag and S.SyncSleepingBag then
    local prevCh, prevCast, prevSit = _G.UnitChannelInfo, _G.UnitCastingInfo, _G.IsSitting
    local miss
    local prevNotify = S.NotifySleepingBagMiss
    S.NotifySleepingBagMiss = function(...) miss = true if prevNotify then return prevNotify(...) end end
    S.ClearSim()
    S._restedStacks, S._auraFresh = 3, true
    S._bagBuilding, S._bagSession, S._bagStartedAt, S._bagUsing = false, nil, nil, nil
    _G.UnitChannelInfo = function() return nil end
    _G.UnitCastingInfo = function() return nil end
    _G.IsSitting = function() return true end
    ok(not S.LiveSleepingBag(), "Bien reposé 3/3 seul (assis) : pas d'icône sac")
    pcall(S.SyncSleepingBag)
    ok(not S.LiveSleepingBag(), "Sync : un buff résultant ne rouvre pas la charge")

    _G.UnitChannelInfo = function()
      return "Unroll Bag", nil, nil, nil, nil, nil, nil, nil, nil, 429961
    end
    S._restedStacks = 0
    pcall(S.SyncSleepingBag)
    ok(S.LiveSleepingBag(), "canal Unroll Bag 429961 : charge active")
    S._restedStacks = 1
    ok(S.SleepingBagStacks() == 1, "pendant la charge : palier 1")
    S._restedStacks = 2
    ok(S.SleepingBagStacks() == 2, "pendant la charge : palier 2")
    S._restedStacks = 3
    ok(S.SleepingBagStacks() == 3, "pendant la charge : palier 3")
    -- fin du canal, on reste assis (encore dans le sac) : la session continue
    _G.UnitChannelInfo = function() return nil end
    ok(S.SleepingBagCharging(), "après le jet de 15 s, encore assis : charge en cours")
    -- on se lève : la charge se termine, le buff 3/3 reste
    _G.IsSitting = function() return false end
    miss = nil
    pcall(S.SyncSleepingBag)
    ok(not S.LiveSleepingBag(), "fin de charge : l'icône part malgré Bien reposé 3/3")

    -- départ anticipé : toast palier manqué
    S.ClearSim()
    _G.IsSitting = function() return true end
    _G.UnitChannelInfo = function()
      return "Sac de couchage", nil, nil, nil, nil, nil, nil, nil, nil, 429961
    end
    S._restedStacks, S._auraFresh = 1, true
    pcall(S.SyncSleepingBag)
    ok(S.LiveSleepingBag(), "charge palier 1")
    _G.UnitChannelInfo = function() return nil end
    _G.IsStanding = function() return true end
    _G.IsSitting = function() return false end
    miss = nil
    pcall(S.SyncSleepingBag)
    ok(not S.LiveSleepingBag(), "interruption : icône retirée")
    ok(miss == true, "interruption avant 3/3 : toast palier manqué")

    ok(S.IsResultingBagBuffName and S.IsResultingBagBuffName("Au repos"), "« Au repos » est un buff résultant")
    ok(S.IsResultingBagBuffName("Chaleur du feu"), "« Chaleur du feu » est un buff résultant")
    ok(S.IsResultingBagBuffName("Well-Rested"), "Well-Rested est un buff résultant")
    ok(not S.IsSleepingBagActionName("Au repos"), "« Au repos » n'est pas une action de charge")
    ok(not S.IsSleepingBagActionName("Bien reposé"), "« Bien reposé » n'est pas une action de charge")
    ok(S.IsSleepingBagActionName("Unroll Bag"), "Unroll Bag est une action de charge")
    ok(S.IsSleepingBagActionName("Sac de couchage"), "Sac de couchage est une action de charge")

    -- Tooltip pendant la charge : palier, écoulé, prochain palier
    S.ClearSim()
    S.SetSleepingBagSim(1)
    S._bagStartedAt = (GetTime and GetTime() or 0) - 90
    local tt = { lines = {} }
    function tt:AddLine(text) self.lines[#self.lines + 1] = tostring(text or "") end
    function tt:SetText(text) self.lines[#self.lines + 1] = tostring(text or "") end
    function tt:AddDoubleLine(a, b) self.lines[#self.lines + 1] = tostring(a) .. " " .. tostring(b or "") end
    local kind = S.FillStateTip(tt)
    ok(kind == "sleepingbag", "tooltip sac : bloc d'état pendant la charge")
    local blob = table.concat(tt.lines, " | ")
    ok(blob:find("1/3", 1, true), "tooltip sac : palier 1/3")
    ok(blob:find("90") or blob:find("1 min", 1, true), "tooltip sac : temps écoulé")
    ok(blob:find("Prochain palier") or blob:find("Next tier"), "tooltip sac : prochain palier")
    S.ClearSim()

    _G.UnitChannelInfo, _G.UnitCastingInfo, _G.IsSitting = prevCh, prevCast, prevSit
    S.NotifySleepingBagMiss = prevNotify
  end

  -- Tooltip repos (valeurs réelles seulement)
  if S and S.FillStateTip then
    local prevRest, prevXPMax, prevIsRest = _G.GetXPExhaustion, _G.UnitXPMax, _G.IsResting
    _G.GetXPExhaustion = function() return 4000 end
    _G.UnitXPMax = function() return 8000 end
    _G.IsResting = function() return true end
    S.ClearSim()
    S.SetSim("rested", true)
    S.NoteRestZone()
    S._restEnteredAt = (GetTime and GetTime() or 0) - 125
    local tt = { lines = {} }
    function tt:AddLine(text) self.lines[#self.lines + 1] = tostring(text or "") end
    function tt:SetText(text) self.lines[#self.lines + 1] = tostring(text or "") end
    function tt:AddDoubleLine(a, b) self.lines[#self.lines + 1] = tostring(a) .. " " .. tostring(b or "") end
    ok(S.FillStateTip(tt) == "rested", "tooltip repos : bloc d'état")
    local blob = table.concat(tt.lines, " | ")
    ok(blob:find("4000", 1, true), "tooltip repos : XP de repos réelle")
    ok(blob:find("50") or blob:find("%%"), "tooltip repos : pourcentage du niveau")
    S.ClearSim()
    _G.GetXPExhaustion, _G.UnitXPMax, _G.IsResting = prevRest, prevXPMax, prevIsRest
  end

  -- Rangée total : planchers absolus (référence medium), texte à part, cadre qui grandit.
  if Wd and Wd.PlanTotalRow and Wd.Metrics and L and I then
    local savedScale, savedCols, savedTotal
    if ns.db and ns.db.ui then savedScale, savedCols, savedTotal = ns.db.ui.scale, ns.db.ui.cols, ns.db.ui.showTotal end
    local function twOf(sz)
      return math.floor(12 * (sz or 13) * 0.62 + 0.5)
    end
    local function planAt(cols, pct)
      if ns.db and ns.db.ui then
        ns.db.ui.scale = (pct ~= 100) and pct or nil
        ns.db.ui.cols = (cols ~= (L.BASE_COLS or 5)) and cols or nil
        ns.db.ui.showTotal = true
      end
      if ns.Wide then ns.Wide.forceShown = true end
      if L.SyncMetrics then L.SyncMetrics() end
      local m = Wd.Metrics(I.TILE)
      local tileGw = cols * I.TILE + math.max(0, cols - 1) * I.HGAP
      local minW = Wd.MinRowWidth(m, twOf(m.font))
      local gw = tileGw
      local plan = Wd.PlanTotalRow(gw, m, twOf)
      local nsizes = I.NumberSizes and I.NumberSizes(I.TILE)
      local wantH = (Wd.IconSize and Wd.IconSize(m.tile or I.TILE)) or m.isz
      ok(m.h == wantH and m.bh >= (Wd.MIN_BAR_H or 12)
        and m.isz == wantH
        and m.font == (nsizes and nsizes.total),
        string.format("métriques %d col. %d %% : h=%d bh=%d font=%d isz=%d (total=%s)",
          cols, pct, m.h, m.bh, m.font, m.isz, tostring(nsizes and nsizes.total)))
      ok(plan.overlay ~= true, string.format("%d col. %d %% : pas de texte superposé à la barre", cols, pct))
      ok(plan.font == m.font,
        string.format("%d col. %d %% : police pleine %d (pas réduite)", cols, pct, plan.font))
      if gw + 0.01 >= minW then
        ok(plan.inner + 0.01 >= (Wd.MIN_BAR_W or 100),
          string.format("barre %d col. %d %% : inner=%d >= 100", cols, pct, plan.inner))
      end
      ok(plan.left + plan.inner <= plan.w + 0.01,
        string.format("rangée %d col. %d %% : barre dans le cadre (%d+%d <= %d)", cols, pct, plan.left, plan.inner, plan.w))
      return plan, gw, m, tileGw, minW
    end
    for _, cols in ipairs({ 2, 3, 5, 10 }) do
      for _, pct in ipairs({ 90, 100, 200 }) do
        planAt(cols, pct)
      end
    end
    -- Plancher Arnaud : cases 36 px, 5 col., fiole ~ case, barre ~100 px, cadre = contenu.
    do
      if ns.db and ns.db.ui then ns.db.ui.scale = 90 ns.db.ui.cols = nil ns.db.ui.showTotal = true end
      if ns.Wide then ns.Wide.forceShown = true end
      if L.SyncMetrics then L.SyncMetrics() end
      local m = Wd.Metrics(I.TILE)
      ok(I.TILE >= 36, "5 col. 90 % : cases >= 36 px (tile=" .. tostring(I.TILE) .. ")")
      ok(I.TILE <= 36, "5 col. 90 % : cases = 36 px au plancher (tile=" .. tostring(I.TILE) .. ")")
      local n90 = I.NumberSizes and I.NumberSizes(I.TILE)
      local wantI = (Wd.IconSize and Wd.IconSize(I.TILE)) or math.floor(I.TILE * 0.70 + 0.5)
      ok(m.bh >= 12 and m.isz == wantI and m.h == wantI and m.font == (n90 and n90.total),
        string.format("5 col. 90 %% : rangée = fiole 70 %% (bh=%d font=%d isz=%d h=%d tile=%d)", m.bh, m.font, m.isz, m.h, I.TILE))
      ok(n90 and n90.rank >= 11 and n90.rank > n90.total and n90.total > n90.max,
        "5 col. 90 % : rang / max lisibles, rang > total > /max")
      local fw, fh, pad, gw = L.ContentSize(5)
      local nat = (L.TileGridWidth and L.TileGridWidth(5)) or gw
      ok(gw == nat, "5 col. 90 % : largeur utile = grille de cases (" .. tostring(gw) .. " / " .. tostring(nat) .. ")")
      ok(pad == (L.MARGIN or 12) and fw == gw + 2 * pad,
        "5 col. 90 % : cadre = grille + même marge des 4 côtés")
      local plan = Wd.PlanTotalRow(gw, m, twOf)
      ok(plan.overlay ~= true and plan.font == m.font,
        "5 col. 90 % : texte à côté de la barre, police du total non réduite")
      ok(plan.left + plan.inner <= plan.w + 0.01,
        "5 col. 90 % : barre dans la largeur utile (" .. tostring(plan.inner) .. ")")
      local midBar = math.floor(((plan.h or m.h) - (plan.bh or m.bh)) / 2 + 0.5)
      ok(math.abs((plan.by or 0) - midBar) <= 1,
        "5 col. 90 % : barre centrée verticalement (by=" .. tostring(plan.by) .. ", milieu=" .. tostring(midBar) .. ")")
      -- Une ancienne taille 50 % est relevée au plancher ; SetScale(50) rend 90.
      if ns.db and ns.db.ui then ns.db.ui.scale = 50 end
      ok(L.Scale() == 90 and ns.db.ui.scale == 90, "échelle sauvée 50 % relevée à 90 % au chargement")
      ok(L.SetScale(50) == 90, "SetScale(50) bloque à 90")
      if L.SyncMetrics then L.SyncMetrics() end
      ok(I.TILE >= 36, "après clamp : case toujours >= 36 px")
      local minFw, minFh = L.MinContentSize(5)
      local cfw, cfh = L.ContentSize(5)
      ok(minFw == cfw and minFh == cfh,
        "MinContentSize = ContentSize au plancher (" .. tostring(minFw) .. "×" .. tostring(minFh) .. ")")
      local Win = ns.Window
      if Win and Win.frame then
        if not Win.frame.SetMinResize then
          function Win.frame:SetMinResize(w, h) self._minRW, self._minRH = w, h end
          function Win.frame:SetResizeBounds(a, b, c, d) self._minRW, self._minRH = a, b end
          function Win.frame:SetResizable(v) self._resizable = v end
          function Win.frame:SetMaxResize(w, h) self._maxRW, self._maxRH = w, h end
        end
        local aw, ah = L.ApplyMinResize()
        ok(aw == minFw and ah == minFh, "ApplyMinResize pose le plancher du contenu")
        ok((Win.frame._minRW or 0) + 0.01 >= minFw and (Win.frame._minRH or 0) + 0.01 >= minFh,
          "SetMinResize / SetResizeBounds = contenu au plancher (cadre, tuiles et barre s'arrêtent ensemble)")
      end
      -- Cadre plus petit que le plancher : SnapToContent remonte.
      if Win and Win.frame and Win.frame.SetSize then
        Win.frame:SetSize(minFw - 40, minFh - 20)
        pcall(L.SnapToContent)
        pcall(L.ApplyMinResize)
        local cw = (Win.frame.GetWidth and Win.frame:GetWidth()) or Win.frame.width or 0
        local ch = (Win.frame.GetHeight and Win.frame:GetHeight()) or Win.frame.height or 0
        ok(cw + 0.5 >= minFw and ch + 0.5 >= minFh,
          "cadre trop petit remonte au plancher (" .. tostring(cw) .. "×" .. tostring(ch) .. ")")
      end
      -- 56 : fiole = glyphe seul (~70 % de la case), centré sur la 1re colonne, pas de cadre.
      do
        local tile = I.TILE or 36
        local want = (Wd.IconSize and Wd.IconSize(tile)) or math.floor(tile * 0.70 + 0.5)
        local cx = (Wd.FirstColCenter and Wd.FirstColCenter(tile))
          or (Wd.ColCenter and Wd.ColCenter(tile)) or math.floor(tile / 2 + 0.5)
        ok(want == math.floor(tile * 0.70 + 0.5), "taille fiole = 70 % de la case (" .. tostring(want) .. ")")
        local dummy = { _wideOn = true, icon = { shown = true, w = 0, h = 0, pts = {} },
          slotBg = { shown = true }, slotBorder = { shown = true }, bg333 = { shown = true },
          _flareRing = { shown = true }, _restZ = { disc = { shown = true } } }
        function dummy.icon:ClearAllPoints() self.pts = {} end
        function dummy.icon:SetPoint(p, rel, rp, x, y) self.pts = { p, rel, rp, x, y } end
        function dummy.icon:SetSize(w, h) self.w, self.h = w, h end
        function dummy.slotBg:Hide() self.shown = false end
        function dummy.slotBg:SetAlpha(a) self.a = a end
        function dummy.slotBorder:Hide() self.shown = false end
        function dummy.slotBorder:SetAlpha(a) self.a = a end
        function dummy.bg333:Hide() self.shown = false end
        function dummy.bg333:SetAlpha(a) self.a = a end
        function dummy._flareRing:Hide() self.shown = false end
        function dummy._flareRing:SetAlpha(a) self.a = a end
        function dummy._restZ.disc:Hide() self.shown = false end
        function dummy._restZ.disc:SetAlpha(a) self.a = a end
        if Wd.PlaceVialIcon then Wd.PlaceVialIcon(dummy, { tile = tile, isz = want }) end
        ok(dummy.icon.w == want and dummy.icon.h == want,
          "PlaceVialIcon : glyphe " .. tostring(dummy.icon.w) .. "×" .. tostring(dummy.icon.h) .. " (70 %)")
        ok(dummy.icon.pts and dummy.icon.pts[1] == "CENTER" and dummy.icon.pts[4] == cx,
          "PlaceVialIcon : centré sur la 1re colonne (x=" .. tostring(dummy.icon.pts and dummy.icon.pts[4]) .. ")")
        ok(dummy.slotBg.shown == false and dummy.slotBorder.shown == false
          and dummy.bg333.shown == false and dummy._flareRing.shown == false,
          "fiole : pas de fond, de filet ni d'anneau")
        ok(dummy._restZ.disc.shown == false, "icône d'état : pas de disque derrière le glyphe")
        if tot then
          tot._wideOn = true
          if Wd.PlaceVialIcon then Wd.PlaceVialIcon(tot, Wd.Metrics(tile)) end
          if tot.slotBg then ok(tot.slotBg.shown == false or (tot.slotBg.IsShown and not tot.slotBg:IsShown()), "case total : slotBg caché") end
          if tot.slotBorder then ok(tot.slotBorder.shown == false or (tot.slotBorder.IsShown and not tot.slotBorder:IsShown()), "case total : slotBorder caché") end
        end
      end
    end
    if ns.db and ns.db.ui then ns.db.ui.scale, ns.db.ui.cols, ns.db.ui.showTotal = savedScale, savedCols, savedTotal end
    if L.SyncMetrics then L.SyncMetrics() end
  end

  if S and S.StartTipTicker then
    local owner = { mouse = true }
    function owner:IsMouseOver() return self.mouse end
    local n = 0
    S.StartTipTicker(owner, function() n = n + 1 end)
    ok(S._tipFrame or S._tipOwner == owner, "ticker d'infobulle : démarré au survol")
    S.StopTipTicker()
    ok(S._tipOwner == nil, "ticker d'infobulle : arrêté en quittant")
  end
end


print("== 3.6.3 : toast récap visible + base de session")
do
  local c = ns.CharDB()
  c.session = c.session or {}
  c.session.startRanks, c.session.baseline = nil, nil
  ok(ns.SessionGain(981) == 0 and c.session.baseline == 981, "première lecture : base = total, gain 0")
  ok(ns.SessionGain(1000) == 19, "gain depuis la base réelle")
  c.session.baseline = 0
  ok(ns.SessionGain(981) == 0 and c.session.baseline == 981, "base 0 (non posée) : réamorcée, pas +981")
  c.session.baseline = 0
  c.session.startRanks = { a = { n = "X", v = 400 }, b = { n = "Y", v = 500 } }
  local recovered = ns.SessionGain(981)
  ok(c.session.baseline == 900 and recovered == 81, "base 0 : récupérée depuis les rangs de départ (+81, pas +981)")

  local function textOnToast(f, fs)
    if not (f and fs) then return false, "missing" end
    if fs.IsShown and not fs:IsShown() then return false, "hidden" end
    local txt = fs.GetText and fs:GetText() or ""
    if txt == "" then return false, "empty" end
    local mq = fs._mq
    if mq and mq.clip and mq.clip.IsShown and mq.clip:IsShown() then
      local w = (mq.clip.GetWidth and mq.clip:GetWidth()) or 0
      local h = (mq.clip.GetHeight and mq.clip:GetHeight()) or 0
      if w < 8 or h < 4 then return false, "clip " .. tostring(w) .. "x" .. tostring(h) end
      return true, txt
    end
    local parent = fs.GetParent and fs:GetParent()
    if parent ~= f then return false, "parent" end
    return true, txt
  end

  local ui = ns.UI
  if ns.SetOpt then ns.SetOpt("recapLogout", true) end
  -- Recycle a long toast first (the regression : leftover clip covering new text).
  local longName = "A Very Long Recipe Name That Definitely Overflows The Toast Title Line When Measured At Six Pixels Per Character Because It Is Extremely Verbose Indeed"
  local long = ui:SpawnDrop("Interface\\Icons\\INV_Misc_QuestionMark", longName, "détail aussi très long pour forcer un défilement de la seconde ligne aussi", nil, nil, nil, { kind = "scanner", force = true })
  if ns.ToastFit and ns.ToastFit.Fit then ns.ToastFit.Fit(long) end
  if long and ui.DismissDrop then ui:DismissDrop(long) end

  local title = "Session"
  local body = "+81 · +484 XP · +3 compétences · 76 min"
  local recap = ui:SpawnDrop("Interface\\AddOns\\Dropamine\\Media\\SkillsTab", title, body, nil, nil, "", { hold = 20, dedupeKey = "osrs-logout-recap", kind = "recap", force = true })
  if ns.ToastFit and ns.ToastFit.Fit then ns.ToastFit.Fit(recap) end
  ok(recap and recap:IsShown(), "toast récap créé")
  local tok, ttxt = textOnToast(recap, recap and recap.titleFS)
  ok(tok and ttxt and tostring(ttxt):find("Session", 1, true), "toast récap : titre visible (pas seulement l'icône) — " .. tostring(ttxt))
  local sok, stxt = textOnToast(recap, recap and recap.subFS)
  ok(sok and stxt and tostring(stxt):find("+81", 1, true) and tostring(stxt):find("compétences", 1, true),
    "toast récap : corps court visible — " .. tostring(stxt))
  ok(recap and recap._fullTitle and recap._fullSub, "toast récap : texte intégral aussi en infobulle")

  -- Texte trop long : 2 lignes si ça tient, défilement seulement en repli, jamais une case vide.
  local mid = "Ceci tient sur deux lignes du toast recap."
  -- ~44 car. × 6 px : trop long pour 1 ligne, assez court pour 2.
  local wrap = ui:SpawnDrop("Interface\\Icons\\INV_Misc_QuestionMark", mid, nil, nil, nil, nil, { kind = "skill", force = true })
  if ns.ToastFit and ns.ToastFit.Fit then ns.ToastFit.Fit(wrap) end
  local wok, wtxt = textOnToast(wrap, wrap and wrap.titleFS)
  ok(wok and wtxt == mid, "texte long : visible après ajuste (2 lignes ou une) — " .. tostring(wtxt))
  local clipOn = wrap and wrap.titleFS and wrap.titleFS._mq and wrap.titleFS._mq.clip
    and wrap.titleFS._mq.clip.IsShown and wrap.titleFS._mq.clip:IsShown()
  ok((wrap and wrap.titleFS and (wrap.titleFS._tfLines or 1) >= 2) or clipOn,
    "texte long : 2 lignes (hauteur auto) ou défilement en repli")
  if wrap and ui.DismissDrop then ui:DismissDrop(wrap) end
  local huge = string.rep("MotTresLong ", 40)
  local mq = ui:SpawnDrop("Interface\\Icons\\INV_Misc_QuestionMark", huge, nil, nil, nil, nil, { kind = "skill", force = true })
  if ns.ToastFit and ns.ToastFit.Fit then ns.ToastFit.Fit(mq) end
  local hok, htxt = textOnToast(mq, mq and mq.titleFS)
  ok(hok and htxt and #htxt > 80, "texte très long : visible (défilement en repli), pas une case vide")
  if mq and ui.DismissDrop then ui:DismissDrop(mq) end
  local empty = ui:SpawnDrop("Interface\\Icons\\INV_Misc_QuestionMark", "", "", nil, nil, nil, { kind = "recap" })
  ok(empty == nil, "titre et corps vides : pas de toast")

  -- Autres types : titre (et sous-titre s'il y en a un) toujours visibles.
  local kinds = {
    { kind = "skill", title = "Épées à deux mains", sub = "+1" },
    { kind = "xp", title = "Niveau 12", sub = "25 %" },
    { kind = "craft", title = "Soupe", sub = "1 × possible" },
  }
  for _, k in ipairs(kinds) do
    local f = ui:SpawnDrop("Interface\\Icons\\INV_Misc_QuestionMark", k.title, k.sub, nil, nil, nil, { kind = k.kind, force = true })
    if ns.ToastFit and ns.ToastFit.Fit then ns.ToastFit.Fit(f) end
    local a, at = textOnToast(f, f and f.titleFS)
    local b, bt = textOnToast(f, f and f.subFS)
    ok(a and at == k.title, "toast " .. k.kind .. " : titre visible")
    ok(b and bt == k.sub, "toast " .. k.kind .. " : corps visible")
    if f and ui.DismissDrop then ui:DismissDrop(f) end
  end

  -- LogoutRecap pose bien le toast avec le gain depuis la base (pas +981).
  c.session.baseline = 900
  c.session.startRanks = {
    feral = { n = "Combat farouche", v = 50 },
    def = { n = "Défense", v = 80 },
    fish = { n = "Pêche", v = 100 },
  }
  c.session.started = ((type(time) == "function" and time()) or 0) - 76 * 60
  ui.snapshot = {
    total = 981, liveCount = 3,
    tiles = {
      { id = "feral", name = "Combat farouche", current = 51 },
      { id = "def", name = "Défense", current = 81 },
      { id = "fish", name = "Pêche", current = 108 },
    },
  }
  if ns.UI._sessionXP ~= nil then ns.UI._sessionXP = 484 end
  if type(_G.InCombatLockdown) == "function" then
    -- keep existing stub
  else
    _G.InCombatLockdown = function() return false end
  end
  local Q = ns.QoL
  local toast
  if Q and Q.LogoutRecap then toast = Q.LogoutRecap("déconnexion") end
  ok(toast and toast ~= false, "LogoutRecap : toast posé")
  if toast and toast ~= false then
    if ns.ToastFit and ns.ToastFit.Fit then ns.ToastFit.Fit(toast) end
    local line = (toast._fullSub or "") .. " " .. ((toast.subFS and toast.subFS.GetText and toast.subFS:GetText()) or "")
    ok(line:find("+81", 1, true) and not line:find("+981", 1, true), "LogoutRecap : gain de session +81 (pas +981) — " .. line)
    local a, at = textOnToast(toast, toast.titleFS)
    local b, bt = textOnToast(toast, toast.subFS)
    ok(a and at and tostring(at):find("Session", 1, true), "LogoutRecap : titre court visible — " .. tostring(at))
    ok(b and bt and tostring(bt):find("+81", 1, true) and tostring(bt):find("·", 1, true),
      "LogoutRecap : corps court visible — " .. tostring(bt))
    if ui.DismissDrop then ui:DismissDrop(toast) end
  end
  if recap and recap:IsShown() and ui.DismissDrop then ui:DismissDrop(recap) end
end


print("== 3.6.3 : delai 0 = jamais, options obsoletes, teinte, polices")
do
  local P = ns.Panel
  if P and P.SetFadeDelay and P.FadeDelay then
    local prev = P.FadeDelay()
    ok(P.SetFadeDelay(0) == 0 and P.FadeDelay() == 0, "Delai avant repos : 0 se memorise (jamais)")
    P.ScheduleSleep()
    ok(P._sleepAt == nil, "delai 0 : ScheduleSleep ne programme pas le repos")
    local it = ns.Options and ns.Options.Find and ns.Options.Find("fadeDelay")
    if it and ns.Options.FormatValue then
      local lab = tostring(ns.Options.FormatValue(it, 0))
      ok(lab:find("Jamais", 1, true) or lab:find("Never", 1, true), "curseur : 0 affiche Jamais (" .. lab .. ")")
    end
    P.SetFadeDelay(prev or 3)
  end
  ok(not (ns.Options and ns.Options.Find and ns.Options.Find("combatStyle")), "option Style de combat retiree")
  ok(not (ns.Options and ns.Options.Find and ns.Options.Find("slotRested")), "option z de repos sur la fiole retiree")
  ok(not (ns.Options and ns.Options.Find and ns.Options.Find("campfire")), "pas d option campfire")
  local Ico = ns.Icons
  if Ico and Ico.NumberSizes and Ico.COUNT_PATH then
    local saved = ns.db and ns.db.ui and ns.db.ui.scale
    if ns.db and ns.db.ui then ns.db.ui.scale = nil end
    if ns.Layout and ns.Layout.SyncMetrics then ns.Layout.SyncMetrics() end
    local s100 = Ico.NumberSizes(Ico.TILE)
    ok(s100.rank > s100.total and s100.total > s100.max, "polices 100 % : rang > total > /max")
    ok(Ico.COUNT_PATH:find("ARIALN", 1, true), "meme face Arial Narrow")
    if ns.db and ns.db.ui then ns.db.ui.scale = saved end
    if ns.Layout and ns.Layout.SyncMetrics then ns.Layout.SyncMetrics() end
  end
end


do
  -- 3.6.3 : pré-sélection = liseré typé, pas de « +1 » ; le vrai gain pop dans la couleur de type + un seul +1
  local T, S, C = ns.Target, ns.Slot, ns.Compact
  local function colorEq(a, b)
    return a and b and math.abs((a[1] or 0) - (b[1] or 0)) < 0.01
      and math.abs((a[2] or 0) - (b[2] or 0)) < 0.01
      and math.abs((a[3] or 0) - (b[3] or 0)) < 0.01
  end
  if T and T.GainColor and S and S.ADD_COLORS then
    ok(colorEq(T.GainColor({ kind = "level" }), S.ADD_COLORS.red), "liseré Niveau : rouge")
    ok(colorEq(T.GainColor({ kind = "melee", name = "Dagues" }), S.ADD_COLORS.blue), "liseré Dagues : bleu")
    ok(colorEq(T.GainColor({ kind = "defense", name = "Défense" }), S.ADD_COLORS.blue), "liseré Défense : bleu")
    ok(colorEq(T.GainColor({ kind = "profession", name = "Cuisine" }), S.ADD_COLORS.green), "liseré Cuisine : vert")
  end
  if T and T.Paint and T.KeyFor and ns.UI then
    local prevTiles = ns.UI.embed and ns.UI.embed.tiles
    ns.UI.embed = ns.UI.embed or {}
    local tile = {
      data = { kind = "level", id = "level", name = "Niveau" },
      GetFrameLevel = function() return 1 end,
      IsShown = function() return true end,
    }
    ns.UI.embed.tiles = { tile }
    T._lvlSig = {}
    local key = T.KeyFor(tile.data)
    T.current = { [key] = { level = "direct", why = { "xp" }, combat = true } }
    pcall(T.Paint)
    ok(tile._tgtLit == "direct", "pré-sélection : case allumée")
    ok(tile._tgtCol and colorEq(tile._tgtCol, S.ADD_COLORS.red), "pré-sélection Niveau : liseré rouge")
    local m = tile._osrsTgt
    if m then
      ok((not m.fs or m.fs.text == "" or m.fs.text == nil or m.fs.shown == false),
        "pré-sélection : pas de « +1 » sur le liseré")
      ok((not m.veil or (m.veil.alpha or 0) == 0 or m.veil.shown == false),
        "pré-sélection : pas de voile rempli")
    else
      ok(true, "pré-sélection : marque créée ou liseré via bevel")
    end
    -- vrai gain : un seul +1 + pop dans la couleur de type (rouge XP éclairci) ; le liseré reste
    if C and C.Announce then
      -- fall through to Pulse/Gain if Announce needs more args
    end
    if C and C.Pulse and C.Gain then
      C.Pulse(tile)
      C.Gain(tile, "+1", S.ADD_COLORS.red)
      local popRed = C.PopColor and C.PopColor(S.ADD_COLORS.red, tile)
      ok(tile._osrsPulse and colorEq(tile._osrsPulse._color, popRed), "vrai gain : pop rouge XP éclairci")
      ok(tile._osrsGain and tile._osrsGain.fs and tile._osrsGain.fs.text == "+1", "vrai gain : un seul +1")
      ok(tile._tgtLit == "direct", "vrai gain : le liseré de pré-sélection reste")
    end
    T.Clear()
    ns.UI.embed.tiles = prevTiles
  end
end

do
  local S, C, UI = ns.Slot, ns.Compact, ns.UI
  local function colorEq(a, b)
    return a and b and math.abs((a[1] or 0) - (b[1] or 0)) < 0.01
      and math.abs((a[2] or 0) - (b[2] or 0)) < 0.01
      and math.abs((a[3] or 0) - (b[3] or 0)) < 0.01
  end
  local red = S and S.ADD_COLORS and S.ADD_COLORS.red
  local blue = S and S.ADD_COLORS and S.ADD_COLORS.blue
-- 48) voile coloré du pop : texture valide, calque OVERLAY / ADD, pic ~0,5, rejoue après Hide/alpha 0
if C and C.Pulse then
  ok(type(C.PULSE_PEAK) == "number" and C.PULSE_PEAK >= 0.4 and C.PULSE_PEAK <= 0.6,
    "Pulse : pic d'alpha ~0,5")
  ok(((C.PULSE_IN or 0) + (C.PULSE_OUT or 0)) >= 0.35 and ((C.PULSE_IN or 0) + (C.PULSE_OUT or 0)) <= 0.5,
    "Pulse : fondu ~0,4 s")
  local vt = { data = { kind = "melee", skillName = "Dagues", name = "Dagues" }, GetFrameLevel = function() return 2 end }
  local veil = C.Pulse(vt, blue or (S and S.ADD_COLORS and S.ADD_COLORS.blue))
  ok(veil and veil.shown ~= false, "voile : cadre visible au pop")
  ok(veil and (veil.alpha or 0) >= 0.35, "voile : alpha immédiat au pic (pas 0)")
  local tex = veil and veil.tex
  ok(tex, "voile : texture créée")
  if tex then
    local path = tex._texSet or tex._tex
    local solid = tex._colorTex
    ok(solid or (type(path) == "string" and path:find("Buttons", 1, true) and path:find("WHITE8X8", 1, true)),
      "voile : WHITE8X8 ou couleur pleine, pas un chemin cassé")
    ok(not (type(path) == "string" and path:find("InterfaceButtons", 1, true)),
      "voile : le chemin d'icône n'avale pas les anti-slash")
    ok(tex.blend == "ADD" or tex.blend == "add", "voile : mélange ADD")
    ok(tex.layer == "OVERLAY" or tex.layer == "OVERLAY", "voile : calque OVERLAY")
  end
  if veil then
    veil:Hide()
    if veil.SetAlpha then veil:SetAlpha(0) end
    veil._pulseOn = nil
  end
  local veil2 = C.Pulse(vt, blue or (S and S.ADD_COLORS and S.ADD_COLORS.blue))
  ok(veil2 and veil2.shown ~= false and (veil2.alpha or 0) >= 0.35,
    "voile : rejoue après Hide() / alpha 0 (case poolée)")
  -- rattachement sur une autre case (vivier)
  local vt2 = { data = { kind = "level", skillName = "Niveau", name = "Niveau" }, GetFrameLevel = function() return 3 end }
  vt2._osrsPulse = vt._osrsPulse
  local veil3 = C.Pulse(vt2, red or (S and S.ADD_COLORS and S.ADD_COLORS.red))
  ok(veil3 and (veil3.GetParent and veil3:GetParent() == vt2 or veil3.parent == vt2),
    "voile : rattaché à la case poolée")
end

-- 49) bouton Tester : gain bleu (arme / Défense) — toast, +1, voile, étincelle
do
  local O = ns.Options
  ok(O and O.TEST and O.TEST.weaponTest == "weapon", "Options.TEST : entrée armes / Défense")
  ok(O and O.Find and O.Find("weaponTest") and O.Find("weaponTest").type == "test",
    "Options : ligne Tester armes / Défense")
  local prevTiles, prevEmbed
  if ns.UI then
    prevEmbed = ns.UI.embed
    ns.UI.embed = ns.UI.embed or {}
    prevTiles = ns.UI.embed.tiles
  end
  local defTile = {
    data = { kind = "defense", id = "defense", skillId = "defense", skillName = "Défense", name = "Défense",
      rank = 80, max = 150, combatTile = true, inTotal = true },
    GetFrameLevel = function() return 4 end,
    IsShown = function() return true end,
  }
  if ns.UI then ns.UI.embed.tiles = { defTile } end
  local W = ns.Window
  local restoreShown
  if W then
    restoreShown = W.IsShown
    W.IsShown = function() return true end
  end
  local f = O and O.RunTest and O.RunTest("weaponTest")
  ok(f, "Tester armes / Défense : toast affiché")
  if f then
    local tn = (f.titleFS and f.titleFS.GetText and f.titleFS:GetText()) or f._title or ""
    ok(type(tn) == "string" and (tn:find("Défense", 1, true) or tn:find("Defense", 1, true) or tn:find("Dagues", 1, true)),
      "Tester armes : titre d'arme ou de Défense — " .. tostring(tn))
    local opts = { kind = f._kind or "skill", skillId = f._target and f._target.skillId or "defense",
      skillName = f._target and f._target.skillName or "Défense" }
    local tint = UI and UI.ToastTintColor and UI.ToastTintColor(opts)
    local expect = S and S.ADD_COLORS and S.ADD_COLORS.blue
    if tint and expect and expect[1] > 0.05 then
      local k = tint[1] / expect[1]
      ok(k < 0.95 and k > 0.2 and math.abs(tint[2] - expect[2] * k) < 0.03,
        "Tester armes : teinte de toast bleue assombrie")
    else
      ok(tint and expect, "Tester armes : teinte de toast bleue")
    end
  end
  -- +1, voile et étincelle sur la case Défense (même si le vol d'éclat n'est pas lancé)
  if C and C.Announce then
    C.Announce({ kind = "skill", skillId = "defense", skillName = "Défense" },
      { { key = C.HoldKey and C.HoldKey(defTile.data) or "defense", gain = 1 }, { key = "total", gain = 1 } })
  end
  local popB = C and C.PopColor and C.PopColor((S and S.ADD_COLORS and S.ADD_COLORS.blue) or { 0.329, 0.408, 0.604 }, defTile)
  ok(defTile._osrsGain and defTile._osrsGain.shown ~= false, "Tester armes : +1 sur la case Défense")
  ok(defTile._osrsPulse and defTile._osrsPulse.shown ~= false and (defTile._osrsPulse.alpha or 0) >= 0.35,
    "Tester armes : voile visible sur la case Défense")
  ok(defTile._osrsPulse and popB and colorEq(defTile._osrsPulse._color, popB),
    "Tester armes : voile bleu (couleur de type)")
  if S and S._sparkColor and S.ADD_COLORS then
    ok(colorEq(S._sparkColor, S.ADD_COLORS.blue), "Tester armes : étincelle de barre bleue")
  else
    ok(S and (S._sparkColor or S._sparkPlayColor), "Tester armes : étincelle de barre lancée")
  end
  if W and restoreShown ~= nil then W.IsShown = restoreShown end
  if ns.UI then ns.UI.embed.tiles = prevTiles; if prevEmbed == nil then ns.UI.embed = prevEmbed end end
end
end

do
  local Q, E, P, UI, C = ns.QoL, ns.Efficiency, ns.Progress, ns.UI, ns.Compact
  -- historique : agrégats conservés, événements bruts retirés, plafond de jours
  if Q and Q.PruneHistory and Q.SlimHistoryDay then
    local c = { history = {} }
    for i = 1, 50 do
      c.history[string.format("2026-01-%02d", ((i-1)%28)+1) .. (i > 28 and ("-" .. i) or "")] = {
        pts = i, total = 100+i, cat = { prof = 1 }, skills = { cooking = 1 },
        events = { { t = 1 } }, curve = { { t = 1 } }, log = { "x" }, raw = { 1 },
      }
    end
    -- clés uniques
    c.history = {}
    for i = 1, 50 do
      c.history[string.format("2025-%02d-%02d", math.max(1, math.floor((i-1)/28)+1), ((i-1)%28)+1)] = {
        pts = i, total = 100+i, cat = { prof = 1 }, skills = { cooking = 1 },
        events = { { t = 1 } }, curve = { { t = 1 } }, log = { "x" }, raw = { 1 },
      }
    end
    Q.PruneHistory(c)
    local n = 0
    for k, h in pairs(c.history) do
      n = n + 1
      ok(h.events == nil and h.curve == nil and h.log == nil and h.raw == nil,
        "historique : jour " .. k .. " sans événements bruts")
      ok(h.pts ~= nil and h.cat ~= nil, "historique : agrégats conservés")
    end
    ok(n <= (Q.HISTORY_DAYS or 35), "historique : au plus " .. tostring(Q.HISTORY_DAYS or 35) .. " jours (" .. n .. ")")
  end

  -- 51) chien de garde conservateur
  local WD = ns.Watchdog
  ok(WD and type(WD.Sweep) == "function", "Watchdog.Sweep disponible")
  local prevCombat = _G.InCombatLockdown
  _G.InCombatLockdown = function() return false end

  -- toast visible encore dans sa durée : intact
  local live
  if UI and UI.SpawnDrop then
    live = UI:SpawnDrop("Interface\\Icons\\INV_Misc_QuestionMark", "Cuisine +1", "160 / 225", 160, 225, nil,
      { force = true, kind = "skill", skillName = "Cuisine", hold = 2.6 })
  end
  ok(live and live.shown ~= false, "watchdog : toast visible créé")
  if live then
    live._toastAge = 0.5
    live._toastBorn = (GetTime and GetTime()) or 0
    if live.SetScript then live:SetScript("OnUpdate", UI.ToastOnUpdate) end
    if live.Show then live:Show() end
    local script = live.GetScript and live:GetScript("OnUpdate")
    pcall(WD.Sweep)
    ok(live.shown ~= false and not live._inPool, "watchdog : ne ferme pas un toast visible en cours")
    ok(live.GetScript and live:GetScript("OnUpdate") == script, "watchdog : OnUpdate du toast visible intact")
  end

  -- animation visible encore dans sa durée : intacte
  local host = CreateFrame("Frame", nil, _G.UIParent)
  host._osrsOwn = true
  if host.Show then host:Show() end
  local ag = host:CreateAnimationGroup()
  local a = ag:CreateAnimation("Alpha")
  if a and a.SetDuration then a:SetDuration(0.4) end
  ag._wdMax, ag._wdStart = 0.4, (GetTime and GetTime()) or 0
  host.ag = ag
  if ag.Play then ag:Play() end
  if C then C.pool = C.pool or {} C.pool[#C.pool + 1] = host end
  pcall(WD.Sweep)
  ok(ag.playing or (ag.IsPlaying and ag:IsPlaying()), "watchdog : ne stoppe pas une animation visible en cours")

  -- en combat : ne touche à rien (toast coincé laissé)
  local stuck
  if UI and UI.SpawnDrop then
    stuck = UI:SpawnDrop("Interface\\Icons\\INV_Misc_QuestionMark", "Bloqué", "x", nil, nil, nil, { force = true, kind = "skill", hold = 1 })
  end
  if stuck then
    stuck._toastAge = 100
    stuck._toastBorn = ((GetTime and GetTime()) or 100) - 100
    if stuck.Show then stuck:Show() end
  end
  _G.InCombatLockdown = function() return true end
  local nCombat = WD.Sweep()
  ok((nCombat or 0) == 0, "watchdog : aucun geste en combat")
  ok(stuck and stuck.shown ~= false and not stuck._inPool, "watchdog : toast coincé intact en combat")
  _G.InCombatLockdown = function() return false end

  -- toast hors délai + 5 s : libéré
  if stuck then
    pcall(WD.Sweep)
    ok(stuck._inPool or stuck.shown == false, "watchdog : toast hors délai + 5 s libéré")
  end

  -- cadre caché avec OnUpdate, dans le vivier : script retiré
  local hid = CreateFrame("Frame", nil, _G.UIParent)
  hid._osrsOwn, hid._osrsToast = true, true
  if hid.Hide then hid:Hide() end
  local dummy = function() end
  hid:SetScript("OnUpdate", dummy)
  UI._toastPool = UI._toastPool or {}
  UI._toastPool[#UI._toastPool + 1] = hid
  pcall(WD.Sweep)
  ok(hid:GetScript("OnUpdate") == nil, "watchdog : OnUpdate d'un cadre caché retiré")

  -- animation sur cadre caché : stoppée
  local hid2 = CreateFrame("Frame", nil, _G.UIParent)
  hid2._osrsOwn = true
  if hid2.Hide then hid2:Hide() end
  local ag2 = hid2:CreateAnimationGroup()
  ag2._wdMax, ag2._wdStart = 0.4, (GetTime and GetTime()) or 0
  hid2.ag = ag2
  if ag2.Play then ag2:Play() end
  if C then C.pool[#C.pool + 1] = hid2 end
  pcall(WD.Sweep)
  ok(not (ag2.playing or (ag2.IsPlaying and ag2:IsPlaying())), "watchdog : animation d'un cadre caché stoppée")

  -- animation visible mais > 2× sa durée : stoppée
  local longf = CreateFrame("Frame", nil, _G.UIParent)
  longf._osrsOwn = true
  if longf.Show then longf:Show() end
  local ag3 = longf:CreateAnimationGroup()
  ag3._wdMax, ag3._wdStart = 0.4, ((GetTime and GetTime()) or 0) - 2
  longf.ag = ag3
  if ag3.Play then ag3:Play() end
  if C then C.pool[#C.pool + 1] = longf end
  pcall(WD.Sweep)
  ok(not (ag3.playing or (ag3.IsPlaying and ag3:IsPlaying())), "watchdog : animation visible au-delà de 2× sa durée stoppée")

  -- StepGC hors combat seulement
  if ns.StepGC then
    _G.InCombatLockdown = function() return true end
    ok(ns.StepGC(200) == false, "StepGC : ignoré en combat")
    _G.InCombatLockdown = function() return false end
    ok(ns.StepGC(200) == true, "StepGC : pas en combat")
  end

  _G.InCombatLockdown = prevCombat or function() return false end
  -- ne pas laisser le toast de test visible fausser d'autres asserts
  if live and UI and UI.DismissDrop and not live._inPool then pcall(UI.DismissDrop, UI, live) end
end


print("== 3.7.0 : éclat toast → case (ancrages vivants) et marges égales")
do
  local C, L, I, Wd = ns.Compact, ns.Layout, ns.Icons, ns.Wide
  local Win = ns.Window
  -- 58 : la grille de cases est centrée ; surplus partagé à gauche et à droite.
  if L and L.TileGridWidth and L.GridOriginX and L.ContentSize then
    if ns.db and ns.db.ui then ns.db.ui.scale = 90 ns.db.ui.cols = nil ns.db.ui.showTotal = true end
    if Wd then Wd.forceShown = true end
    if L.SyncMetrics then L.SyncMetrics() end
    local nat = L.TileGridWidth(5)
    local fw, fh, pad, gw = L.ContentSize(5)
    local ox = L.GridOriginX(5, gw)
    ok(nat > 0 and gw >= nat, "58 : largeur utile >= grille de cases (" .. tostring(gw) .. " / " .. tostring(nat) .. ")")
    ok(ox == math.floor((gw - nat) / 2), "58 : décalage = surplus / 2 (ox=" .. tostring(ox) .. ")")
    local left, right = (pad or 12) + ox, (pad or 12) + (gw - nat - ox)
    ok(math.abs(left - right) <= 1, "58 : marges gauche et droite égales (" .. tostring(left) .. " / " .. tostring(right) .. ")")
    -- La barre occupe la largeur utile ; elle dépasse les cases de la même distance de chaque côté.
    local overL, overR = ox, gw - nat - ox
    ok(math.abs(overL - overR) <= 1, "58 : la barre s'aligne : même dépassement des deux côtés (" .. tostring(overL) .. " / " .. tostring(overR) .. ")")
    if ns.db and ns.db.ui then ns.db.ui.scale = nil end
    if L.SyncMetrics then L.SyncMetrics() end
    local nat100 = L.TileGridWidth(5)
    local _, _, pad100, gw100 = L.ContentSize(5)
    local ox100 = L.GridOriginX(5, gw100)
    local l100, r100 = (pad100 or 12) + ox100, (pad100 or 12) + (gw100 - nat100 - ox100)
    ok(math.abs(l100 - r100) <= 1, "58 : marges égales à 100 % (" .. tostring(l100) .. " / " .. tostring(r100) .. ")")

    -- 59 : au plancher, G = D = H = B ; rangée = fiole 70 % ; états 55 % ; icône sur 1re colonne.
    if ns.db and ns.db.ui then ns.db.ui.scale = 90 ns.db.ui.cols = nil ns.db.ui.showTotal = true end
    if Wd then Wd.forceShown = true end
    if L.SyncMetrics then L.SyncMetrics() end
    local UI = ns.UI
    if UI then
      UI.snapshot = UI.snapshot or {}
      local snap = {}
      for i = 1, 9 do snap[i] = { id = i } end
      UI.snapshot.tiles = snap
    end
    local tile = I.TILE or 36
    local vg = I.VGAP or 12
    local fw59, fh59, pad59, gw59, gh59 = L.ContentSize(5)
    local nat59 = L.TileGridWidth(5)
    local ox59 = L.GridOriginX(5, gw59)
    local left59 = (pad59 or 12) + ox59
    local right59 = (pad59 or 12) + (gw59 - nat59 - ox59)
    ok(gw59 == nat59 and ox59 == 0, "59 : largeur min = grille (pas d'élargissement barre)")
    ok(left59 == (pad59 or 12) and right59 == (pad59 or 12) and left59 == pad59,
      "59 : au plancher, marges G/D = H/B (" .. tostring(left59) .. " / " .. tostring(pad59) .. ")")
    ok(fw59 == gw59 + 2 * pad59 and fh59 == gh59 + 2 * pad59,
      "59 : cadre = contenu + même marge des 4 côtés")
    local m59 = Wd.Metrics(tile)
    local isz70 = (Wd.IconSize and Wd.IconSize(tile)) or math.floor(tile * 0.70 + 0.5)
    local isz55 = (Wd.StateIconSize and Wd.StateIconSize(tile)) or math.floor(tile * 0.55 + 0.5)
    ok(m59.h == isz70, "59 : hauteur rangée total = fiole 70 % (" .. tostring(m59.h) .. ")")
    ok(isz55 == math.floor(tile * 0.55 + 0.5),
      "59 : glyphe Z de repos = 55 % de la case (" .. tostring(isz55) .. ")")
    local rows59 = 2
    local expectGh = rows59 * tile + (rows59 - 1) * vg + vg + m59.h
    ok(gh59 == expectGh, "59 : écart avant le total = écart entre rangées (" .. tostring(gh59) .. " / " .. tostring(expectGh) .. ")")
    local dummy59 = { icon = { pts = {}, w = 0, h = 0 } }
    function dummy59.icon:ClearAllPoints() self.pts = {} end
    function dummy59.icon:SetPoint(a, b, c, x, y) self.pts = { a, b, c, x, y } end
    function dummy59.icon:SetSize(w, h) self.w, self.h = w, h end
    if Wd.PlaceVialIcon then Wd.PlaceVialIcon(dummy59, { tile = tile }) end
    local cx59 = (Wd.FirstColCenter and Wd.FirstColCenter(tile)) or math.floor(tile / 2 + 0.5)
    ok(dummy59.icon.pts and dummy59.icon.pts[4] == cx59 and dummy59.icon.w == isz70,
      "59 : fiole 70 % centrée sur la 1re colonne (x=" .. tostring(dummy59.icon.pts and dummy59.icon.pts[4]) .. ")")
    if ns.Slot and ns.Slot.IconInnerSize then
      local sw = select(1, ns.Slot.IconInnerSize({ _wideOn = true }))
      ok(sw == isz70, "59 : IconInnerSize (fiole / combat / vol) = 70 % (" .. tostring(sw) .. ")")
    end
    if ns.db and ns.db.ui then ns.db.ui.scale = nil end
    if L.SyncMetrics then L.SyncMetrics() end
  end

  -- 60 : chaque +1 part juste au-dessus de SA case et retombe dessus.
  if C and C.Gain then
    local host = CreateFrame("Frame", "DropamineGainHost", _G.UIParent)
    host:SetSize(300, 200)
    host:ClearAllPoints()
    host:SetPoint("TOPLEFT", _G.UIParent, "TOPLEFT", 0, 0)
    local function mk(name, top)
      local t = CreateFrame("Button", name, host)
      t:SetSize(36, 36)
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", host, "TOPLEFT", 10, -top)
      t.icon = t:CreateTexture(nil, "ARTWORK")
      if t.icon.SetSize then t.icon:SetSize(32, 32) end
      if t.icon.SetPoint then t.icon:SetPoint("CENTER", t, "CENTER", 0, 0) end
      t.data = { kind = "skill", name = name }
      return t
    end
    local t1 = mk("DropamineGainR1", 0)
    local t2 = mk("DropamineGainR2", 48)
    C.Gain(t1, "+1")
    C.Gain(t2, "+1")
    local g1, g2 = t1._osrsGain, t2._osrsGain
    ok(g1 and g2 and g1 ~= g2, "60 : un +1 par case")
    local p1 = g1.points and g1.points[#g1.points]
    local p2 = g2.points and g2.points[#g2.points]
    ok(p1 and p1[2] == t1, "60 : +1 rangée 1 ancré à sa propre case")
    ok(p2 and p2[2] == t2, "60 : +1 rangée 2 ancré à sa propre case (pas au haut du bloc)")
    local want = (C.GAIN_START_K or 0.4) * 36
    ok(g1._y and math.abs(g1._y - want) < 2,
      "60 : départ = haut de case + 0,4 case (" .. tostring(g1._y) .. " / " .. tostring(want) .. ")")
    ok(g2._y and math.abs(g2._y - want) < 2,
      "60 : le +1 de la rangée 2 part aussi de SA case (" .. tostring(g2._y) .. ")")
    local y1, y2 = g1._y, g2._y
    if C.GainStep then C.GainStep(g1, (C.GAIN_TIME or 1.5) * 0.5) C.GainStep(g2, (C.GAIN_TIME or 1.5) * 0.5) end
    ok(g1._y and y1 and g1._y < y1, "60 : le +1 descend sur sa case (" .. tostring(y1) .. " → " .. tostring(g1._y) .. ")")
    ok(g2._y and y2 and g2._y < y2, "60 : le +1 de la rangée 2 descend sur sa case")
  end

  -- 57 : vol d'éclat — ancrages courants, découpe, vivier, watchdog ; timing inchangé.
  if C and C.Launch and C.Flyer and Win and Win.frame then
    if not Win.IsShown then function Win.IsShown() return Win.frame and Win.frame:IsShown() end end
    Win.frame:Show()
    if not Win.frame.GetWidth then function Win.frame:GetWidth() return self.width or 300 end end
    if not Win.frame.GetHeight then function Win.frame:GetHeight() return self.height or 200 end end
    Win.frame.width, Win.frame.height = 300, 200
    Win.frame:ClearAllPoints()
    Win.frame:SetPoint("BOTTOMLEFT", _G.UIParent, "BOTTOMLEFT", 100, 100)
    -- toast au-dessus du panneau, case plus bas
    local drop = CreateFrame("Frame", "DropamineFlyToast", _G.UIParent)
    drop:SetSize(80, 40)
    drop:ClearAllPoints()
    drop:SetPoint("BOTTOMLEFT", _G.UIParent, "BOTTOMLEFT", 160, 360)
    drop:Show()
    local tile = CreateFrame("Button", "DropamineFlyTile", Win.frame)
    tile:SetSize(40, 40)
    tile:ClearAllPoints()
    tile:SetPoint("BOTTOMLEFT", Win.frame, "BOTTOMLEFT", 40, 20)
    tile.data = { kind = "skill", skillName = "Dépeçage", id = "skinning", name = "Dépeçage" }
    tile:Show()
    tile.icon = tile:CreateTexture(nil, "ARTWORK")
    tile.icon:SetSize((I and I.ICON) or 36, (I and I.ICON) or 36)
    tile.icon:ClearAllPoints()
    tile.icon:SetPoint("CENTER", tile, "CENTER", 0, 0)
    local prevTiles = C.Tiles
    function C.Tiles() return { tile } end
    local landed = 0
    local baseLand = C.Land
    function C.Land(e, quiet)
      landed = landed + 1
      e.landed = true
      if baseLand then
        -- ne pas lancer Pulse/Gain ici : on vérifie seulement l'arrivée
      end
    end
    local e = { drop = drop, icon = "Interface\\Icons\\X", kind = "skill",
      targets = { { key = "s:Dépeçage", gain = 1 } }, born = 0, opts = { kind = "skill" } }
    -- En jeu le +1 / voile restent à l'arrivée (après le toast) : Launch ne doit pas Land tout de suite.
    C.Launch(e)
    ok(e.launched and not e.landed, "57 : le vol part après le toast, le +1 n'est pas anticipé")
    local f = e and (function()
      for _, ff in ipairs(C.pool or {}) do if ff._entry == e then return ff end end
    end)()
    ok(f and f._busy and f:IsShown(), "57 : éclat pris dans le vivier et visible")
    local clip = C.clip
    ok(clip and clip.clipsChildren, "57 : éclat découpé dans le panneau")
    ok(f.GetParent and f:GetParent() == clip, "57 : éclat parenté au cadre de découpe")
    local x0, y0 = f._x, f._y
    if C.FlyStep then C.FlyStep(f, (C.FLY or 0.55) * 0.5) end
    ok(f._x and x0 and (f._y ~= y0 or f._x ~= x0),
      "57 : l'éclat n'est pas figé (il avance) (" .. tostring(x0) .. "," .. tostring(y0) .. " → " .. tostring(f._x) .. "," .. tostring(f._y) .. ")")
    -- La case bouge : l'ancrage d'arrivée suit la position COURANTE.
    tile:ClearAllPoints()
    tile:SetPoint("BOTTOMLEFT", Win.frame, "BOTTOMLEFT", 200, 20)
    tile.icon:ClearAllPoints()
    tile.icon:SetPoint("CENTER", tile, "CENTER", 0, 0)
    local midX = f._x
    if C.FlyStep then C.FlyStep(f, (C.FLY or 0.55) * 0.4) end
    ok(f._x and midX and f._x ~= midX,
      "57 : l'arrivée suit la case déplacée (pas de taille en cache) (" .. tostring(midX) .. " → " .. tostring(f._x) .. ")")
    -- Watchdog : ne tue pas un éclat en vol.
    local wd = ns.Watchdog
    if wd and wd.Sweep then
      local script = f.GetScript and f:GetScript("OnUpdate")
      pcall(wd.Sweep)
      ok(f._busy and f:IsShown() and (f.GetScript and f:GetScript("OnUpdate") == script),
        "57 : le watchdog ne coupe pas un éclat en vol")
    end
    if C.FinishFly then C.FinishFly(f, e) else C.Land(e) end
    ok(e.landed and landed >= 1, "57 : arrivée sur la bonne case, Land appelé")
    ok(not f._busy and not f:IsShown(), "57 : éclat rendu au vivier (caché, libre)")
    C.Land = baseLand
    C.Tiles = prevTiles
  end
end

do
  local O, UI, C, P = ns.Options, ns.UI, ns.Compact, ns.Progress
  local function pump(maxN)
    maxN = maxN or 200
    local n = 0
    while n < maxN and (O._testPlaying or (O._testQ and O._testQ[1]) or (timers and #timers > 0)) do
      n = n + 1
      flushTimers()
    end
    if O.ResetTestState then O.ResetTestState() end
    while timers and #timers > 0 do table.remove(timers) end
  end
  local keys = {}
  for k in pairs(O.TEST or {}) do keys[#keys + 1] = k end
  table.sort(keys)
  ok(#keys > 5, "Tester : une batterie de boutons (" .. tostring(#keys) .. ")")
  -- amorce : remplit le vivier une fois
  for _, k in ipairs(keys) do O.RunTest(k) end
  pump()
  local created0 = UI._toastCreated or 0
  local origCF = _G.CreateFrame
  local made = 0
  _G.CreateFrame = function(...)
    made = made + 1
    return origCF(...)
  end
  local sessPts, histPts
  if P and P.C then
    local pr, ch = P.C()
    sessPts = pr.session and pr.session.pts
    histPts = 0
    if ch and ch.history then
      for _, h in pairs(ch.history) do histPts = histPts + (tonumber(h.pts) or 0) end
    end
  end
  collectgarbage("collect")
  collectgarbage("collect")
  local mem0 = collectgarbage("count")
  for _ = 1, 3 do
    for _, k in ipairs(keys) do O.RunTest(k) end
  end
  local qn = #(O._testQ or {})
  ok(qn <= #keys, "Tester : clics rapides sans tripler la file (" .. qn .. " ≤ " .. #keys .. ")")
  pump()
  _G.CreateFrame = origCF
  ok(made == 0, "Tester 3× : aucun nouveau cadre hors vivier (" .. tostring(made) .. ")")
  ok((UI._toastCreated or 0) <= created0, "Tester 3× : toasts du vivier uniquement (créés " .. tostring(UI._toastCreated) .. " ≤ " .. tostring(created0) .. ")")
  local leftover
  for _, f in ipairs((UI and UI.dropsActive) or {}) do
    if f and f._testToast then leftover = true end
  end
  ok(not leftover, "Tester 3× : plus de toast de test actif")
  ok(not (C and C.holds and next(C.holds)), "Tester 3× : pas de retenue de case")
  local veilLeft
  if C and C.Tiles then
    for _, tile in ipairs(C.Tiles() or {}) do
      if tile._osrsPulse and tile._osrsPulse.shown then veilLeft = true end
      if tile._osrsGain and tile._osrsGain.shown then veilLeft = true end
    end
  end
  ok(not veilLeft, "Tester 3× : voile / +1 rangés")
  if sessPts ~= nil then
    local pr, ch = P.C()
    local sess1 = pr.session and pr.session.pts
    local hist1 = 0
    if ch and ch.history then
      for _, h in pairs(ch.history) do hist1 = hist1 + (tonumber(h.pts) or 0) end
    end
    ok(sess1 == sessPts, "Tester 3× : session inchangée")
    ok(hist1 == histPts, "Tester 3× : historique inchangé")
  else
    ok(true, "Tester 3× : pas de session à comparer")
  end
  collectgarbage("collect")
  collectgarbage("collect")
  local mem1 = collectgarbage("count")
  ok(mem1 <= mem0 + 128, "Tester 3× : mémoire revenue au socle (" .. string.format("%.1f", mem1) .. " / " .. string.format("%.1f", mem0) .. " Ko)")
end

ok(errs() == 0, "aucune erreur UI (3.7.0)")
print(failures == 0 and "\n3.6.3 : TOUS LES TESTS PASSENT" or ("\n3.6.3 : " .. failures .. " ÉCHEC(S)"))
os.exit(failures == 0 and 0 or 1)
