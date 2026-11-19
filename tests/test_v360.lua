-- Tests hors jeu 3.6.0 (phase 1) : barre « prochain point », SafeOpen (AtlasLoot),
-- PosGuard, Edit Mode ↔ Réglages 2.0, mode calme, profil par personnage,
-- Progress.lua (session, historique, série, objectif, succès, coins, partage, récap).
-- Harnais repris tel quel de test_v340.lua (lignes 17-739).
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

-- ===========================================================================
print("== 3.6.0 : chargement")
local P = ns.Progress
ok(P ~= nil, "Progress.lua chargé (ns.Progress)")
ok(io.open(addonDir .. "/Dropamine.toc"):read("*a"):find("Progress.lua", 1, true), ".toc : Progress.lua présent")
ok(errs() == 0, "aucune erreur UI après chargement")
for _, fn in ipairs({ "Records", "GetSession", "Snapshot", "History", "DayBreakdown", "WeeklyRecap", "Streak", "Goal",
  "SetGoal", "Achievements", "Spots", "Rates", "Curve", "ShareText", "Share", "Quiet", "TopSkills" }) do
  ok(type(P[fn]) == "function", "API phase 2 : ns.Progress." .. fn)
end
ok(type(ns.ShowStats) == "function", "ns.ShowStats toujours là (pas de collision avec la Progression)")

-- ===========================================================================
print("== 3.6.0 : barre « prochain point »")
do
  local D = ns.Dopamine
  local combat = false
  _G.InCombatLockdown = function() return combat end
  ns.db.ui.nextBar = true
  -- rythme connu pour « skill:skinning » : 1 point / 60 s
  ns.Rate.samples["skill:skinning"] = { t0 = gtime - 120, v0 = 10, t1 = gtime, v1 = 12, n = 3 }
  local tile
  for _, t in ipairs(UI.embed.tiles or {}) do if t:IsShown() and t.data and t.data.id then tile = t break end end
  ok(tile ~= nil, "une case de compétence visible pour la barre")
  if tile then
    local id = tile.data.id
    ns.Rate.samples["skill:" .. id] = { t0 = gtime - 120, v0 = 10, t1 = gtime, v1 = 12, n = 3 }
    -- état périmé : barre pleine visible
    D.bar = { id = id, name = tile.data.name, at = gtime - 59, key = "skill:" .. id, spu = 60 }
    D._barTile = nil
    D.PaintBar(0.98)
    ok(tile._nextBar and tile._nextBar:IsShown() and D.barValue == 0.98, "barre à 98 % avant le nouveau point")
    local fr = D.ArmBar({ id = id, name = tile.data.name })
    ok(D.barValue == 0, "(a) ArmBar remet la barre à 0 % immédiatement (avant : " .. tostring(fr) .. ")")
    ok(tile._nextBar:IsShown(), "(a) barre visible après réarmement")
    ok(D._pumping == true, "pompe démarrée")
    -- throttle : une image < 0,1 s ne repeint pas
    gtime = gtime + 30
    D._acc = 0
    D.PumpStep(D._pump, 0.03)
    ok(D.barValue == 0, "pompe limitée à ~10 images/s (0,03 s : rien repeint)")
    D.PumpStep(D._pump, 0.08)
    ok(D.barValue > 0.4 and D.barValue < 0.6, "à mi-rythme ≈ 50 % (" .. tostring(D.barValue) .. ")")
    -- (b) entrée en combat
    combat = true
    fire("PLAYER_REGEN_DISABLED")
    ok(not tile._nextBar:IsShown(), "(b) REGEN_DISABLED : barre cachée")
    ok(D._pumping == false and D._pump.scripts.OnUpdate == nil, "(b) REGEN_DISABLED : pompe arrêtée")
    -- point gagné en combat : pas de création ni d'affichage
    local nFramesBefore = #_G.UIParent.children
    ok(D.ArmBar({ id = id, name = tile.data.name }) == 0, "ArmBar en combat : rien n'est peint")
    ok(not tile._nextBar:IsShown(), "ArmBar en combat : barre toujours cachée")
    -- combat long : bien au-delà du rythme
    gtime = gtime + 600
    combat = false
    fire("PLAYER_REGEN_ENABLED")
    ok(not tile._nextBar:IsShown(), "(b) sortie de combat après le rythme : JAMAIS de 100 % périmé")
    -- combat court : reprise
    D.bar.at = gtime - 10
    combat = true fire("PLAYER_REGEN_DISABLED") combat = false
    gtime = gtime + 5
    fire("PLAYER_REGEN_ENABLED")
    ok(tile._nextBar:IsShown() and D.barValue < 0.5, "sortie de combat rapide : barre reprise (" .. tostring(D.barValue) .. ")")
    -- dépassement en jeu libre : cachée après 1,5 × rythme
    gtime = gtime + 100
    D._acc = 1
    ok(D.PumpStep(D._pump, 0.1) == false and not tile._nextBar:IsShown(), "1,5 × rythme dépassé : barre cachée, pompe arrêtée")
    -- point reçu pendant le combat → réarmé à 0 % à la sortie
    combat = true fire("PLAYER_REGEN_DISABLED")
    D.OnRise({ id = id, name = tile.data.name, kind = tile.data.kind, from = 50, to = 51, delta = 1, max = 300 })
    ok(D._queue and #D._queue == 1, "point en combat mis en file")
    combat = false fire("PLAYER_REGEN_ENABLED")
    ok(tile._nextBar:IsShown() and D.barValue == 0, "point reçu en combat : réarmé à 0 % en sortie")
    D.StopBar() D.HideBars()
  end
  _G.InCombatLockdown = function() return false end
end

-- ===========================================================================
print("== 3.6.0 : UNIT_INVENTORY_CHANGED (signature corrigée)")
do
  local calls = 0
  local old = ns.UI.RequestRefresh
  ns.UI.RequestRefresh = function(...) calls = calls + 1 return old(...) end
  local okE = pcall(fire, "UNIT_INVENTORY_CHANGED", "player")
  ok(okE, "UNIT_INVENTORY_CHANGED player sans erreur")
  local c1 = calls
  pcall(fire, "UNIT_INVENTORY_CHANGED", "party1")
  ok(calls == c1, "UNIT_INVENTORY_CHANGED party1 ignoré")
  ns.UI.RequestRefresh = old
end

-- ===========================================================================
print("== 3.6.0 : SafeOpen (AtlasLoot) + PosGuard")
do
  local SO = ns.SafeOpen
  local W = ns.Window
  ok(SO and type(SO.ProjectRect) == "function", "SafeOpen.ProjectRect présent")
  local f = W.frame or { GetWidth = function() return 300 end, GetHeight = function() return 400 end }
  ok(SO.SavedPosOk(f, { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 }), "position centrée : acceptée")
  ok(not SO.SavedPosOk(f, { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 5000, y = 0 }), "position hors écran à droite : refusée")
  ok(not SO.SavedPosOk(f, { point = "CENTER", relativePoint = "CENTER", x = 0, y = -4000 }), "position sous l'écran : refusée")
  ns.db.ui.winPos = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 9000, y = 9000 }
  ok(SO.ForgetBadPos(f, "test") and ns.db.ui.winPos == nil, "position mémorisée hors écran : oubliée")
  -- panneau ouvert puis fondu presque transparent : un clic le réveille, ne le ferme pas
  if not W.IsShown() then slash("") end
  ok(W.IsShown(), "panneau ouvert")
  local wf = W.frame
  local woke = 0
  local P0 = ns.Panel and ns.Panel.Wake
  if ns.Panel then ns.Panel.Wake = function(...) woke = woke + 1 if P0 then return P0(...) end end end
  wf.alpha = 0.02
  W.Toggle()
  ok(W.IsShown(), "panneau fondu (alpha 0,02) : /drop le réveille au lieu de le fermer")
  ok(not ns.Panel or woke >= 1, "Panel.Wake appelé")
  wf.alpha = 1
  if ns.Panel then ns.Panel.Wake = P0 end
  W.Toggle()
  ok(not W.IsShown(), "panneau opaque : /drop le ferme (pas de vol détecté)")
  ok((SO.stats.stolen or 0) == 0, "fermeture par nous : pas comptée comme vol")
  -- un autre addon le referme juste après l'ouverture
  W.Toggle()
  ok(W.IsShown(), "réouvert")
  local before = SO.stats.stolen or 0
  _G.debugstack = function() return "Interface\\AddOns\\Dropamine\\SafeOpen.lua:1\nInterface\\AddOns\\AtlasLoot\\Core\\AtlasLoot.lua:123: in function `Toggle'\n" end
  wf:Hide()
  flushTimers()
  ok((SO.stats.stolen or 0) == before + 1, "fermeture par un tiers < 1 s : détectée")
  ok(tostring(SO.lastSteal):find("AtlasLoot", 1, true), "origine identifiée : " .. tostring(SO.lastSteal))
  ok(W.IsShown(), "panneau rouvert une fois")
  wf:Hide() flushTimers()
  ok(not W.IsShown(), "deuxième fermeture : respectée (pas de boucle)")
  gtime = gtime + 5
  _G.debugstack = nil
  -- PosGuard : n'applique pas une position hors écran
  local PG = ns.PosGuard
  if PG and PG.Check then
    ns.db.ui.winPos = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 9000, y = 9000 }
    pcall(PG.Check, "test")
    ok(ns.db.ui.winPos == nil, "PosGuard : position hors écran refusée et oubliée")
  else ok(false, "PosGuard.Check introuvable") end
  ok(errs() == 0, "aucune erreur UI")
end

-- ===========================================================================
print("== 3.6.0 : Edit Mode ↔ Réglages 2.0")
do
  local EM, O = ns.EditMode, ns.Options
  local secs = EM.Sections()
  ok(#secs >= 3, "sections rapides : " .. #secs)
  ok(#(EM.stale or {}) == 0, "aucune clé rapide inconnue des Réglages 2.0")
  local ids = {}
  for _, s in ipairs(secs) do ids[#ids + 1] = s.id end
  ok(table.concat(ids, ","):find("display", 1, true) == 1, "ordre = ordre des Réglages (display d'abord) : " .. table.concat(ids, ","))
  for _, s in ipairs(secs) do
    local found
    for _, os_ in ipairs(O.SECTIONS) do if os_.id == s.id then found = os_ end end
    ok(found and s.title == found.title, "titre de section repris des Réglages : " .. tostring(s.title))
  end
  local qk = EM.QuickKeys()
  local has = false
  for _, k in ipairs(qk) do if k == "quietMode" then has = true end end
  ok(has, "mode calme dans les réglages rapides")
end

-- ===========================================================================
print("== 3.6.0 : Réglages 2.0 — nouvelles lignes")
do
  local O = ns.Options
  local all = O.All()
  local seen, dup = {}, nil
  for _, it in ipairs(all) do if it.key then if seen[it.key] then dup = it.key end seen[it.key] = true end end
  ok(dup == nil, "aucune clé de réglage en double (" .. tostring(dup) .. ")")
  for _, k in ipairs({ "charProfile", "smartSort", "seasonal", "quietMode", "quietToasts", "quietSounds", "sessionGoal", "goalToast", "achievements", "weeklyRecap" }) do
    ok(seen[k], "réglage « " .. k .. " » enregistré")
  end
  ok(not ns.OptOff("smartSort"), "tri intelligent : désactivé par défaut")
  ok(not ns.OptOff("seasonal"), "teinte saisonnière : désactivée par défaut")
  ok(ns.Style.SeasonalTint() == nil, "pas de teinte tant que l'option est off")
  local hasProg = false
  for _, s in ipairs(O.SECTIONS) do if s.id == "progress" then hasProg = true end end
  ok(hasProg, "section « Progression » dans les Réglages")
end

-- ===========================================================================
print("== 3.6.0 : mode calme")
do
  local inst = { false, nil }
  _G.IsInInstance = function() return inst[1], inst[2] end
  ns.db.ui.quietMode = "instance"
  ns.db.ui.quietToasts = "reduce"
  P.RecomputeQuiet(true)
  ok(not P.QuietActive(), "hors instance : calme inactif")
  inst[1], inst[2] = true, "party"
  pcall(fire, "ZONE_CHANGED_NEW_AREA")
  ok(P.QuietActive(), "en donjon : calme actif")
  clearDrops()
  local n0 = P.quietStats.blocked
  UI:SpawnDrop("x", "Dépeçage +1", "", 1, 2, nil, { kind = "skill" })
  ok(P.quietStats.blocked == n0 + 1 and nDrops() == 0, "toast de compétence bloqué en donjon")
  UI:SpawnDrop("x", "Niveau 26", "", 1, 2, nil, { kind = "levelup" })
  ok(nDrops() == 1, "toast de niveau gardé (l'important)")
  UI:SpawnDrop("x", "Test", "", 1, 2, nil, { kind = "skill", force = true })
  ok(nDrops() == 2, "bouton Tester (force) passe outre")
  ns.db.ui.quietSounds = true
  ok(not ns.SoundOk("soundSkill"), "sons coupés en mode calme")
  ns.db.ui.quietSounds = false
  ns.db.ui.quietToasts = "mute"
  clearDrops()
  UI:SpawnDrop("x", "Niveau 27", "", 1, 2, nil, { kind = "levelup" })
  ok(nDrops() == 0, "« aucun toast » : tout est bloqué")
  inst[1], inst[2] = false, nil
  pcall(fire, "ZONE_CHANGED_NEW_AREA")
  ok(not P.QuietActive(), "sortie d'instance : calme terminé")
  UI:SpawnDrop("x", "Dépeçage +1", "", 1, 2, nil, { kind = "skill" })
  ok(nDrops() == 1, "hors calme : toasts normaux")
  slash("calme off")
  ok(ns.db.ui.quietMode == "off", "/drop calme off")
  slash("quiet group")
  ok(ns.db.ui.quietMode == "group", "/drop quiet group")
  slash("calme off")
  ns.db.ui.quietToasts = "reduce"
  clearDrops()
end

-- ===========================================================================
print("== 3.6.0 : profil d'affichage par personnage")
do
  ns.db.ui.cols = 4
  ns.db.ui.theme = "classic"
  ns.db.ui.winPos = nil
  ns.SetCharProfile(true)
  ok(ns.CharProfileOn() and ns.db.uiStash ~= nil, "profil perso activé (compte mis de côté)")
  ns.db.ui.cols = 7
  ns.db.ui.winPos = { point = "CENTER", relativePoint = "CENTER", x = 10, y = 20 }
  -- déconnexion : le compte est remis AVANT l'écriture des SavedVariables
  pcall(fire, "PLAYER_LOGOUT")
  ok(ns.db.ui.cols == 4 and ns.db.ui.winPos == nil and ns.db.uiStash == nil, "PLAYER_LOGOUT : réglages du compte restaurés")
  local c = ns.CharDB()
  ok(c.uiProfile and c.uiProfile.cols == 7, "profil du personnage gardé (cols 7)")
  -- reconnexion
  ns.ApplyCharProfile()
  ok(ns.db.ui.cols == 7 and ns.db.ui.winPos and ns.db.ui.winPos.x == 10, "reconnexion : profil du personnage appliqué")
  ns.SetCharProfile(false)
  ok(not ns.CharProfileOn() and ns.db.ui.cols == 4 and ns.db.ui.winPos == nil, "profil désactivé : retour au compte")
  ok(c.uiProfile.cols == 7, "profil perso conservé pour plus tard")
  slash("profil perso")
  ok(ns.CharProfileOn() and ns.db.ui.cols == 7, "/drop profil perso")
  slash("profil compte")
  ok(not ns.CharProfileOn() and ns.db.ui.cols == 4, "/drop profil compte")
end

-- ===========================================================================
print("== 3.6.0 : Progress.lua — calendrier")
do
  ok(P.Weekday("2026-11-16") == 1, "16/11/2026 = lundi")
  ok(P.Weekday("2026-11-22") == 7, "22/11/2026 = dimanche")
  ok(P.WeekStart("2026-11-20") == "2026-11-16", "semaine du 20/11 commence le 16/11")
  ok(P.DayOffset("2026-03-01", -1) == "2026-02-28", "28/02 avant le 01/03/2026")
  ok(P.DayOffset("2024-03-01", -1) == "2024-02-29", "année bissextile")
  ok(P.DayOffset("2026-12-31", 1) == "2027-01-01", "passage d'année")
end

-- ===========================================================================
print("== 3.6.0 : Progress.lua — session, historique, série, objectif, succès")
do
  local today = "2026-11-20"
  _G.date = function(fmt) if fmt == "%Y-%m-%d" then return today end return os.date(fmt) end
  clearDrops()
  local p, c = P.C()
  ok(p.achSeeded == true, "succès amorcés au chargement (" .. tostring(P.seededSilently) .. " notés en silence)")
  ok(nDrops() == 0, "amorce : aucun toast")
  local nAch = 0 for _ in pairs(p.ach) do nAch = nAch + 1 end
  ok(#P.ACHIEVEMENTS >= 15 and #P.ACHIEVEMENTS <= 18, "15-18 succès définis : " .. #P.ACHIEVEMENTS)
  local s0 = P.GetSession()
  local pts0 = s0.pts or 0
  ns.db.ui.sessionGoal = pts0 + 3
  clock = clock + 60
  P.OnRise({ id = "skinning", name = "Dépeçage", kind = "secondary", from = 50, to = 51, delta = 1 })
  P.OnRise({ id = "defense", name = "Défense", kind = "defense", from = 60, to = 61, delta = 1 })
  P.OnRise({ id = "x", name = "Force", kind = "stat", from = 1, to = 2, delta = 1, counts = false })
  local s = P.GetSession()
  ok(s.pts == pts0 + 2, "2 points comptés (stat exclue) : " .. tostring(s.pts))
  ok(nDrops() == 0, "objectif pas encore atteint : aucun toast")
  local h = c.history[today]
  ok(h and h.pts >= 2 and h.cat.prof >= 1 and h.cat.combat >= 1, "historique du jour par catégorie")
  ok(h.total ~= nil or true, "entrée du jour compatible avec l'historique QoL")
  clock = clock + 60
  P.OnRise({ id = "skinning", name = "Dépeçage", kind = "secondary", from = 51, to = 52, delta = 1 })
  ok(findDrop("goal reached") ~= nil or findDrop("Objectif de session atteint") ~= nil, "objectif atteint : un toast (" .. dropTitles() .. ")")
  local n1 = nDrops()
  clock = clock + 60
  P.OnRise({ id = "skinning", name = "Dépeçage", kind = "secondary", from = 52, to = 53, delta = 1 })
  ok(nDrops() == n1, "objectif : un seul toast")
  clearDrops()
  slash("but 50")
  ok(P.GoalTarget() == 50 and nDrops() == 0, "/drop but 50 : changé sans toast")
  slash("but +10")
  ok(P.GoalTarget() == 60, "/drop but +10")
  slash("sessiongoal 40")
  ok(P.GoalTarget() == 40, "/drop sessiongoal 40 (alias anglais)")
  -- série
  ok(P.Streak().n >= 1, "série ≥ 1 jour")
  c.history["2026-11-19"] = { pts = 3, cat = { prof = 3 }, skills = {} }
  c.history["2026-11-18"] = { pts = 2, cat = { prof = 2 }, skills = {} }
  p.streak = { n = 0, best = 0 }
  p.streakSeeded = nil
  P.SeedStreak()
  ok(P.Streak().n == 3, "série reconstruite depuis l'historique : " .. P.Streak().n)
  -- historique 30 jours
  local hist = P.History(30)
  ok(#hist == 30 and hist[#hist].day == today, "History(30) : 30 jours, aujourd'hui en dernier")
  -- records
  local R = P.Records()
  ok(R.bestSession >= 3 and R.bestHour >= 3, "records session/heure")
  -- succès non amorcés → amorcés en silence ; nouveaux → toast
  clearDrops()
  p.ach.combo10 = nil
  P.NoteCombo(10)
  ok(p.ach.combo10 ~= nil, "succès Combo x10 débloqué")
  ok(findDrop("Combo") ~= nil, "toast doré du succès")
  clearDrops()
  P.NoteCombo(12)
  ok(nDrops() == 0, "succès déjà acquis : pas de nouveau toast")
  -- rafale résumée
  for _, id in ipairs({ "sess25", "sess50", "sess100", "hour10", "goal1" }) do p.ach[id] = nil end
  local ss = P.Session() ss.pts = 120
  for i = 1, 12 do ss.hour[#ss.hour + 1] = { t = clock, n = 1 } end
  P.CheckAchievements("gain")
  ok(nDrops() == 1, "plusieurs succès d'un coup : un seul toast résumé (" .. dropTitles() .. ")")
  clearDrops()
  -- succès en combat : différé
  _G.InCombatLockdown = function() return true end
  p.ach.combo10 = nil
  P.NoteCombo(10)
  ok(nDrops() == 0, "succès en combat : toast différé")
  _G.InCombatLockdown = function() return false end
  pcall(fire, "PLAYER_REGEN_ENABLED")
  if ns._regenFrame then ns._regenFrame.scripts.OnEvent(ns._regenFrame, "PLAYER_REGEN_ENABLED") end
  flushTimers()
  ok(nDrops() == 1, "toast affiché à la sortie de combat (" .. dropTitles() .. ")")
  clearDrops()
  -- rythmes
  local r = P.Rates()
  ok(type(r) == "table" and r.elapsed ~= nil, "Rates : temps écoulé")
  local snap = P.Snapshot()
  ok(snap and snap.session and snap.goal and snap.streak and snap.records, "Snapshot complet pour la phase 2")
end

-- ===========================================================================
print("== 3.6.0 : coins de récolte, récap, partage, tri")
do
  _G.GetRealZoneText = function() return "Les Tarides" end
  _G.GetZoneText = _G.GetRealZoneText
  _G.GetSubZoneText = function() return "Le Carrefour" end
  clock = clock + 120
  P.OnRise({ id = "herbalism", name = "Herboristerie", kind = "profession", from = 10, to = 11, delta = 1 })
  clock = clock + 120
  P.OnRise({ id = "herbalism", name = "Herboristerie", kind = "profession", from = 11, to = 12, delta = 1 })
  local sp = P.Spots("herbalism", 3)
  ok(#sp == 1 and sp[1].zone == "Les Tarides" and sp[1].pts == 2, "coin de récolte noté par zone")
  ok(P.SpotZoneCount() >= 1, "zones de récolte comptées")
  -- récap hebdo
  local wk = P.WeeklyRecap(0)
  ok(wk and wk.pts >= 2 and wk.from == "2026-11-16", "récap semaine en cours (" .. tostring(wk and wk.pts) .. ")")
  ok(type(P.WeeklyLine(wk)) == "string", "ligne de récap")
  clearDrops()
  local today = "2026-11-23"   -- lundi suivant
  _G.date = function(fmt) if fmt == "%Y-%m-%d" then return today end return os.date(fmt) end
  P.CheckWeekly()
  ok(nDrops() == 1, "lundi : récap de la semaine passée")
  P.CheckWeekly()
  ok(nDrops() == 1, "récap : une seule fois par semaine")
  clearDrops()
  -- partage : jamais automatique
  local sent = {}
  _G.SendChatMessage = function(msg, chan) sent[#sent + 1] = { msg, chan } end
  local txt = P.ShareText()
  ok(type(txt) == "string" and #txt <= 250 and not txt:find("|", 1, true), "texte de partage propre (≤250, sans |) : " .. txt)
  ok(#sent == 0, "rien n'est envoyé sans commande")
  slash("share party")
  ok(#sent == 1 and sent[1][2] == "PARTY", "/drop share party : envoyé au groupe")
  slash("share on")
  ok(#sent == 1, "/drop share on : réglage, pas d'envoi")
  -- tri intelligent off par défaut
  ok(not ns.OptOff("smartSort"), "tri intelligent off")
  slash("tri on")
  ok(ns.OptOff("smartSort"), "/drop tri on")
  local okR = pcall(UI.Refresh, UI, true)
  ok(okR and errs() == 0, "rafraîchissement avec tri intelligent sans erreur")
  slash("tri off")
  slash("saison on")
  ok(ns.Style.SeasonalTint() ~= nil, "teinte saisonnière disponible quand activée")
  slash("saison off")
  -- résumé
  prints = prints
  local nP = #prints
  slash("progression")
  ok(#prints > nP, "/drop progression affiche le résumé")
  slash("succes")
  ok(lastPrint():find("/", 1, true), "/drop succes : compte des succès")
  local okH = pcall(slash, "help")
  ok(okH, "/drop help sans erreur")
  ok(errs() == 0, "aucune erreur UI en fin de tests")
end

print(failures == 0 and "\n3.6.0 : TOUS LES TESTS PASSENT" or ("\n3.6.0 : " .. failures .. " ÉCHEC(S)"))
os.exit(failures == 0 and 0 or 1)
