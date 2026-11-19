-- Dropamine 3.3.13 : intégration au MODE ÉDITION du jeu (façon FlareUI).
-- Mode édition ouvert → le panneau montre un calque de sélection ; un clic
-- ouvre une fenêtre de réglages à côté du panneau : titre, sections repliables
-- (en-têtes jaunes), curseurs ◀ ▶ + case numérique, menus déroulants, boutons
-- rouges « Paramètres complets », « Réinitialiser », « Revenir à la position
-- par défaut ». Aperçu en direct : tout passe par Options.Set (mêmes effets que
-- les commandes /drop et le panneau d'options, synchronisés).
-- Sans souillure : HookScript / hooksecurefunc seulement, sur
-- EditModeManagerFrame ; jamais ClearSelectedSystem ni écriture dans ses
-- tables. Nos cadres sont enfants d'UIParent / du panneau.
-- Repli : /drop edit bascule le calque si l'API du mode édition est absente.
local _, ns = ...
local Tr = ns.L   -- 3.5.19 : textes traduits (Locales/)
local UI, W = ns.UI, ns.Window
local EM = {}
ns.EditMode = EM
local function N(v) return ns.N and ns.N(v) or tonumber(v) end
local function O() return ns.Options end
local function Say(m) print(Tr["|cffffd100Dropamine|r : "] .. m) end
local function After(dt, fn) if type(_G.C_Timer) == "table" and type(_G.C_Timer.After) == "function" then _G.C_Timer.After(dt, fn) else fn() end end

EM.W, EM.ROW_H, EM.HEAD_H, EM.PAD = 300, 26, 22, 12
EM.YELLOW = { 1, 0.82, 0 }
-- 3.6.0 : réglages rapides alignés sur les réglages 2.0 (Options.lua) : mêmes
-- familles (id), dans le même ordre, mêmes titres, mêmes libellés et aides
-- (Options.SectionItems), aucune clé qui n'existe pas dans le panneau complet.
EM.SECTIONS = {
  { id = "display", keys = { "theme", "cols", "scale", "opacity", "showTotal" } },
  { id = "notif", keys = { "dropsEnabled", "notifMode", "dropDir", "quietMode" } },
  { id = "prof", keys = { "gatherAlerts", "activity", "tipCompact", "scannerIcons" } },
  { id = "advanced", keys = { "pvp", "pvpMarks" } },
}
-- Titre de la famille = celui du panneau complet.
function EM.SectionTitle(sec)
  local o = ns.Options
  for _, s in ipairs(o and o.SECTIONS or {}) do if s.id == sec.id then return s.title end end
  return sec.title or sec.id
end
-- Familles résolues : titre, réglages existants (les clés périmées sont écartées
-- et notées dans EM.stale pour /drop debug et les tests), ordre du panneau complet.
function EM.Sections()
  local o = ns.Options
  local out, stale = {}, {}
  local rank = {}
  for i, s in ipairs(o and o.SECTIONS or {}) do rank[s.id] = i end
  for _, sec in ipairs(EM.SECTIONS) do
    local items = {}
    for _, key in ipairs(sec.keys) do
      local it = o and o.Find and o.Find(key)
      if it then items[#items + 1] = it else stale[#stale + 1] = key end
    end
    if #items > 0 then out[#out + 1] = { id = sec.id, title = EM.SectionTitle(sec), items = items, rank = rank[sec.id] or 99 } end
  end
  table.sort(out, function(a, b) return a.rank < b.rank end)
  EM.stale = stale
  return out
end
function EM.QuickKeys()
  local keys = {}
  for _, sec in ipairs(EM.Sections()) do for _, it in ipairs(sec.items) do keys[#keys + 1] = it.key end end
  return keys
end
EM.collapsed = {}
EM.stats = { enter = 0, exit = 0, sets = 0 }

local function Panel() return W and W.frame end
local function InCombat() return ns.InCombat and ns.InCombat() or false end

------------------------------------------------------------------------------
-- Calque de sélection sur le panneau
------------------------------------------------------------------------------
function EM.Overlay()
  local f = Panel()
  if not f then return nil end
  if EM.overlay then return EM.overlay end
  local ok, s = pcall(CreateFrame, "Frame", nil, f, "EditModeSystemSelectionTemplate")
  if not (ok and s) then s = CreateFrame("Frame", nil, f) EM.overlayKind = "repli" else EM.overlayKind = "EditModeSystemSelectionTemplate" end
  s._osrsOwn = true
  s:SetAllPoints(f)
  pcall(s.SetFrameLevel, s, (f.GetFrameLevel and f:GetFrameLevel() or 1) + 40)
  s.system = { GetSystemName = function() return "Dropamine" end }
  if EM.overlayKind == "repli" or not s.ShowHighlighted then
    s.fill = s:CreateTexture(nil, "OVERLAY")
    s.fill:SetAllPoints(s)
    pcall(s.fill.SetTexture, s.fill, "Interface\\Buttons\\WHITE8X8")
    function s:ShowHighlighted() self.fill:SetVertexColor(0.25, 0.55, 1, 0.25) self.isSelected = false self:Show() end
    function s:ShowSelected() self.fill:SetVertexColor(1, 0.82, 0, 0.25) self.isSelected = true self:Show() end
  end
  s.label = s:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  s.label:SetPoint("CENTER", s, "CENTER", 0, 0)
  s.label:SetText("Dropamine")
  if s.EnableMouse then s:EnableMouse(true) end
  if s.RegisterForDrag then pcall(s.RegisterForDrag, s, "LeftButton") end
  s:SetScript("OnMouseDown", function() EM.Select() end)
  s:SetScript("OnDragStart", function()
    local p = Panel()
    if p and p.StartMoving and not InCombat() then
      if p.SetMovable then pcall(p.SetMovable, p, true) end
      pcall(p.StartMoving, p) EM._moving = true
    end
  end)
  s:SetScript("OnDragStop", function()
    local p = Panel()
    if p and EM._moving then
      EM._moving = nil
      pcall(p.StopMovingOrSizing, p)
      if ns.Panel and ns.Panel.SavePos then pcall(ns.Panel.SavePos, p) end
      if EM.dialog and EM.dialog:IsShown() then EM.Place() end
    end
  end)
  s:Hide()
  EM.overlay = s
  return s
end

function EM.Select()
  local s = EM.Overlay()
  if not s then return end
  pcall(s.ShowSelected, s, true)
  EM.selected = true
  EM.OpenDialog()
end
function EM.Deselect()
  EM.selected = nil
  local s = EM.overlay
  if s and EM.active then pcall(s.ShowHighlighted, s) end
  if EM.dialog then EM.dialog:Hide() end
end

function EM.Enter(how)
  if EM.active then return false end
  EM.active, EM.how = true, how or "jeu"
  EM.stats.enter = EM.stats.enter + 1
  if W and W.IsShown and not W.IsShown() and W.Show then EM._shownByEdit = true pcall(W.Show) end
  local s = EM.Overlay()
  if s then pcall(s.ShowHighlighted, s) end
  return true
end
function EM.Exit()
  if not EM.active then return false end
  EM.active, EM.selected = nil, nil
  EM.stats.exit = EM.stats.exit + 1
  if EM.overlay then EM.overlay:Hide() end
  if EM.dialog then EM.dialog:Hide() end
  if EM.menu then EM.menu:Hide() end
  if EM._shownByEdit and W and W.Hide then EM._shownByEdit = nil pcall(W.Hide) end
  return true
end

-- branché sur l'existant (UI:EnterEditMode / ExitEditMode appelés par les crochets du jeu)
if UI.EnterEditMode then
  local baseEnter, baseExit = UI.EnterEditMode, UI.ExitEditMode
  function UI:EnterEditMode(...)
    local r = { baseEnter(self, ...) }
    pcall(EM.Enter, "jeu")
    return unpack(r)
  end
  function UI:ExitEditMode(...)
    local r = { baseExit(self, ...) }
    pcall(EM.Exit)
    return unpack(r)
  end
end
-- un autre système sélectionné dans le mode édition → on désélectionne le nôtre
function EM.HookSelect()
  local em = _G.EditModeManagerFrame
  if EM._selHooked or type(em) ~= "table" or type(_G.hooksecurefunc) ~= "function" then return false end
  if type(em.SelectSystem) ~= "function" then return false end
  EM._selHooked = true
  pcall(_G.hooksecurefunc, em, "SelectSystem", function() if EM.selected then EM.Deselect() end end)
  return true
end
pcall(EM.HookSelect)
if ns.On then ns.On("PLAYER_LOGIN", function() pcall(EM.HookSelect) end) end

------------------------------------------------------------------------------
-- Fenêtre de réglages
------------------------------------------------------------------------------
local function Btn(parent, text, w, h)
  local ok, b = pcall(CreateFrame, "Button", nil, parent, "UIPanelButtonTemplate")   -- bouton rouge Blizzard
  if not (ok and b) then b = CreateFrame("Button", nil, parent) end
  b._osrsOwn = true
  b:SetSize(w or 120, h or 22)
  if b.SetText then b:SetText(text) end
  if not b.GetFontString or not b:GetFontString() then
    b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.fs:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.fs:SetText(text)
  end
  return b
end
local function Arrow(parent, dir)
  local b = CreateFrame("Button", nil, parent)
  b._osrsOwn = true
  b:SetSize(18, 18)
  local base = dir < 0 and "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-" or "Interface\\Buttons\\UI-SpellbookIcon-NextPage-"
  if b.SetNormalTexture then pcall(b.SetNormalTexture, b, base .. "Up") pcall(b.SetPushedTexture, b, base .. "Down") pcall(b.SetDisabledTexture, b, base .. "Disabled") end
  if b.SetHighlightTexture then pcall(b.SetHighlightTexture, b, "Interface\\Buttons\\UI-Common-MouseHilight", "ADD") end
  return b
end

-- 3.6.0 : même infobulle que le panneau complet (libellé, aide, commande)
local function Tip(frame, it)
  if not (frame and frame.SetScript and it) then return end
  frame:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(Tr[it.label], 1, 0.82, 0)
    if it.help then GameTooltip:AddLine(Tr[it.help], 1, 1, 1, true) end
    if it.cmd then GameTooltip:AddLine(Tr[it.cmd], 0.7, 0.7, 0.7) end
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end
EM.Tip = Tip

function EM.Set(key, v)
  local o = O()
  if not o then return end
  EM.stats.sets = EM.stats.sets + 1
  pcall(o.Set, key, v)
  EM.Sync()
  if o.panel and o.Sync then pcall(o.Sync) end
  if EM.dialog and EM.dialog:IsShown() then After(0, EM.Place) end
end

local function SliderRow(d, it)
  local r = CreateFrame("Frame", nil, d)
  r._osrsOwn = true
  r:SetSize(EM.W - 2 * EM.PAD, EM.ROW_H)
  r.label = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")   -- libellé or (réglages 2.0)
  r.label:SetPoint("LEFT", r, "LEFT", 0, 0)
  r.label:SetWidth(96)
  if r.label.SetJustifyH then r.label:SetJustifyH("LEFT") end
  r.label:SetText(Tr[it.label])
  r.label.font = "GameFontNormalSmall"
  if r.EnableMouse then r:EnableMouse(true) end
  Tip(r, it)
  r.left = Arrow(r, -1)
  r.left:SetPoint("LEFT", r, "LEFT", 98, 0)
  local ok, s = pcall(CreateFrame, "Slider", nil, r, "OptionsSliderTemplate")
  if not (ok and s) then s = CreateFrame("Slider", nil, r) end
  s._osrsOwn = true
  if s.SetOrientation then s:SetOrientation("HORIZONTAL") end
  s:SetSize(96, 14)
  s:SetPoint("LEFT", r.left, "RIGHT", 2, 0)
  s:SetMinMaxValues(it.min, it.max)
  if s.SetValueStep then s:SetValueStep(it.step or 1) end
  if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
  for _, k in ipairs({ "Low", "High", "Text" }) do local fs = s.GetName and s:GetName() and _G[s:GetName() .. k] if fs and fs.Hide then fs:Hide() end end
  r.slider = s
  r.right = Arrow(r, 1)
  r.right:SetPoint("LEFT", s, "RIGHT", 2, 0)
  local okE, e = pcall(CreateFrame, "EditBox", nil, r, "InputBoxTemplate")
  if not (okE and e) then e = CreateFrame("EditBox", nil, r) end
  e._osrsOwn = true
  e:SetSize(38, 18)
  e:SetPoint("LEFT", r.right, "RIGHT", 6, 0)
  if e.SetAutoFocus then e:SetAutoFocus(false) end
  if e.SetMaxLetters then e:SetMaxLetters(5) end
  if e.SetJustifyH then e:SetJustifyH("CENTER") end
  if e.SetFontObject then pcall(e.SetFontObject, e, "GameFontHighlightSmall") end
  r.box = e
  r.it = it
  local function step(dir)
    local cur = N(O().Get(it.key)) or it.default
    EM.Set(it.key, cur + dir * (it.step or 1))
  end
  r.left:SetScript("OnClick", function() step(-1) end)
  r.right:SetScript("OnClick", function() step(1) end)
  s:SetScript("OnValueChanged", function(_, v)
    if EM._syncing then return end
    local st = it.step or 1
    v = math.floor((N(v) or 0) / st + 0.5) * st
    if v ~= N(O().Get(it.key)) then EM.Set(it.key, v) end
  end)
  local function commit(self)
    local v = N(self:GetText())
    if v then EM.Set(it.key, v) else EM.Sync() end
    if self.ClearFocus then self:ClearFocus() end
  end
  e:SetScript("OnEnterPressed", commit)
  e:SetScript("OnEscapePressed", function(self) EM.Sync() if self.ClearFocus then self:ClearFocus() end end)
  function r:Refresh()
    local v = N(O().Get(it.key)) or it.default
    EM._syncing = true
    self.slider:SetValue(v)
    EM._syncing = false
    local txt = (it.step and it.step < 1) and string.format("%.2f", v):gsub("%.?0+$", "") or tostring(math.floor(v + 0.5))
    self.box:SetText(txt)
    self.value = v
  end
  return r
end

local function Label(it, v)
  for _, c in ipairs(it.choices or {}) do if c[1] == v then return Tr[c[2]] end end
  return tostring(v)
end
function EM.Menu(row)
  local m = EM.menu
  if not m then
    m = CreateFrame("Frame", nil, UIParent)
    m._osrsOwn = true
    if m.SetFrameStrata then m:SetFrameStrata("DIALOG") end
    pcall(m.SetFrameLevel, m, 260)
    if ns.Skin and ns.Skin.Host then local h = ns.Skin.Host(m) ns.Skin.Paint(h, 0.95) end
    m.items = {}
    EM.menu = m
  end
  local it = row.it
  for i, c in ipairs(it.choices or {}) do
    local b = m.items[i]
    if not b then
      b = CreateFrame("Button", nil, m)
      b._osrsOwn = true
      b:SetSize(180, 18)
      b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      b.fs:SetPoint("LEFT", b, "LEFT", 8, 0)
      if b.SetHighlightTexture then pcall(b.SetHighlightTexture, b, "Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD") end
      m.items[i] = b
    end
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", m, "TOPLEFT", 4, -4 - (i - 1) * 18)
    b.fs:SetText(Tr[c[2]])
    b:SetScript("OnClick", function() m:Hide() EM.Set(it.key, c[1]) end)
    b:Show()
  end
  for i = #(it.choices or {}) + 1, #m.items do m.items[i]:Hide() end
  m:SetSize(188, 8 + 18 * #(it.choices or {}))
  m:ClearAllPoints()
  m:SetPoint("TOPLEFT", row.button, "BOTTOMLEFT", 0, -2)
  m._row = row
  m:Show()
  return m
end
local function DropRow(d, it)
  local r = CreateFrame("Frame", nil, d)
  r._osrsOwn = true
  r:SetSize(EM.W - 2 * EM.PAD, EM.ROW_H)
  r.label = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  r.label:SetPoint("LEFT", r, "LEFT", 0, 0)
  r.label:SetText(Tr[it.label])
  r.label.font = "GameFontNormalSmall"
  if r.EnableMouse then r:EnableMouse(true) end
  Tip(r, it)
  local b = CreateFrame("Button", nil, r)
  b._osrsOwn = true
  b:SetSize(170, 20)
  b:SetPoint("RIGHT", r, "RIGHT", 0, 0)
  if ns.Skin and ns.Skin.Host then local h = ns.Skin.Host(b) ns.Skin.Paint(h, 0.6) end
  b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.fs:SetPoint("LEFT", b, "LEFT", 8, 0)
  b.fs:SetPoint("RIGHT", b, "RIGHT", -18, 0)
  if b.fs.SetJustifyH then b.fs:SetJustifyH("LEFT") end
  b.arrow = b:CreateTexture(nil, "OVERLAY")
  b.arrow:SetSize(14, 14)
  b.arrow:SetPoint("RIGHT", b, "RIGHT", -4, 0)
  pcall(b.arrow.SetTexture, b.arrow, "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
  r.button, r.it = b, it
  b:SetScript("OnClick", function() if EM.menu and EM.menu:IsShown() and EM.menu._row == r then EM.menu:Hide() else EM.Menu(r) end end)
  function r:Refresh() self.value = O().Get(it.key) self.button.fs:SetText(Label(it, self.value)) end
  return r
end
local function CheckRow(d, it)
  local r = CreateFrame("Frame", nil, d)
  r._osrsOwn = true
  r:SetSize(EM.W - 2 * EM.PAD, EM.ROW_H)
  local ok, c = pcall(CreateFrame, "CheckButton", nil, r, "UICheckButtonTemplate")
  if not (ok and c) then c = CreateFrame("CheckButton", nil, r) end
  c._osrsOwn = true
  c:SetSize(22, 22)
  c:SetPoint("LEFT", r, "LEFT", -2, 0)
  r.label = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  r.label:SetPoint("LEFT", c, "RIGHT", 2, 0)
  r.label:SetText(Tr[it.label])
  r.label.font = "GameFontNormalSmall"
  Tip(c, it)
  r.check, r.it = c, it
  c:SetScript("OnClick", function(self) EM.Set(it.key, self:GetChecked() and true or false) end)
  function r:Refresh() self.value = O().Get(it.key) and true or false self.check:SetChecked(self.value) end
  return r
end

function EM.BuildDialog()
  if EM.dialog then return EM.dialog end
  local o = O()
  if not o then return nil end
  local d = CreateFrame("Frame", "DropamineEditDialog", UIParent)
  d._osrsOwn = true
  if d.SetFrameStrata then d:SetFrameStrata("DIALOG") end
  pcall(d.SetFrameLevel, d, 200)
  d:SetSize(EM.W, 200)
  if d.EnableMouse then d:EnableMouse(true) end
  if d.SetClampedToScreen then d:SetClampedToScreen(true) end
  if ns.Skin and ns.Skin.Host then d.host = ns.Skin.Host(d) ns.Skin.Paint(d.host, 0.92) end
  d.title = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  d.title:SetPoint("TOP", d, "TOP", 0, -12)
  d.title:SetText("Dropamine")
  local okC, close = pcall(CreateFrame, "Button", nil, d, "UIPanelCloseButton")
  if okC and close then close:SetPoint("TOPRIGHT", d, "TOPRIGHT", -2, -2) close:SetScript("OnClick", function() EM.Deselect() end) d.close = close end
  d.sections, d.rows = {}, {}
  for si, sec in ipairs(EM.Sections()) do
    local h = CreateFrame("Button", nil, d)
    h._osrsOwn = true
    h:SetSize(EM.W - 2 * EM.PAD, EM.HEAD_H)
    h.fs = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")      -- en-tête jaune
    h.fs:SetPoint("LEFT", h, "LEFT", 0, 0)
    h.fs:SetTextColor(EM.YELLOW[1], EM.YELLOW[2], EM.YELLOW[3])
    h.div = h:CreateTexture(nil, "ARTWORK")
    h.div:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 0, 0)
    h.div:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 0, 0)
    h.div:SetHeight(2)
    pcall(h.div.SetTexture, h.div, "Interface\\Common\\UI-TooltipDivider-Transparent")
    h.sec = sec
    h:SetScript("OnClick", function() EM.collapsed[sec.title] = not EM.collapsed[sec.title] or nil EM.Relayout() end)
    local rows = {}
    for _, it in ipairs(sec.items) do
      local r = (it.type == "slider" and SliderRow(d, it)) or (it.type == "radio" and DropRow(d, it)) or (it.type == "check" and CheckRow(d, it)) or nil
      if r then rows[#rows + 1] = r d.rows[it.key] = r end
    end
    d.sections[si] = { head = h, rows = rows, title = sec.title, id = sec.id }
  end
  d.full = Btn(d, Tr["Paramètres complets"], EM.W - 2 * EM.PAD, 22)
  d.full:SetScript("OnClick", function() EM.Deselect() if O().Open then pcall(O().Open) end end)
  d.reset = Btn(d, Tr[o.SECTION_RESET or "Réinitialiser"], EM.W - 2 * EM.PAD, 22)
  Tip(d.reset, { label = o.SECTION_RESET or "Réinitialiser", help = "Remet les réglages rapides ci-dessus à leur valeur d'origine" })
  d.reset:SetScript("OnClick", function(self) EM.ResetClick(self) end)
  d.home = Btn(d, Tr["Revenir à la position par défaut"], EM.W - 2 * EM.PAD, 22)
  d.home:SetScript("OnClick", function() if UI.ResetPositions then pcall(UI.ResetPositions, UI) end EM.Place() end)
  d:Hide()
  EM.dialog = d
  EM.Relayout()
  return d
end
local function BtnText(b, t) if b.SetText then b:SetText(t) end if b.fs then b.fs:SetText(t) end end
-- 3.6.0 : comme « Réinitialiser » d'une section des réglages 2.0 : deux clics,
-- et seulement les réglages montrés ici (avant : TOUT le panneau d'options).
function EM.ResetClick(b)
  local o = O()
  local txt, conf = Tr[o.SECTION_RESET or "Réinitialiser"], Tr[o.SECTION_RESET_CONFIRM or "Confirmer ?"]
  if not EM._resetArmed then
    EM._resetArmed = true
    BtnText(b, conf)
    After(4, function() if EM._resetArmed then EM._resetArmed = nil BtnText(b, txt) end end)
    return "armed"
  end
  EM._resetArmed = nil
  BtnText(b, txt)
  local n = 0
  o._syncing = true
  for _, sec in ipairs(EM.Sections()) do
    for _, it in ipairs(sec.items) do
      if it.default ~= nil and not it.noReset and pcall(o.Set, it.key, it.default) then n = n + 1 end
    end
  end
  o._syncing = false
  if o.panel and o.Sync then pcall(o.Sync) end
  if o.OnLiveChange then pcall(o.OnLiveChange, "theme") end
  EM.Sync()
  return n
end

function EM.Relayout()
  local d = EM.dialog
  if not d then return end
  local y = -40
  for _, s in ipairs(d.sections) do
    local c = EM.collapsed[s.title]
    s.head:ClearAllPoints()
    s.head:SetPoint("TOPLEFT", d, "TOPLEFT", EM.PAD, y)
    s.head.fs:SetText((c and "+ " or "– ") .. Tr[s.title])
    y = y - EM.HEAD_H - 2
    for _, r in ipairs(s.rows) do
      if c then r:Hide() else
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", d, "TOPLEFT", EM.PAD, y)
        r:Show()
        y = y - EM.ROW_H
      end
    end
    y = y - 4
  end
  y = y - 6
  for _, b in ipairs({ d.full, d.reset, d.home }) do
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", d, "TOPLEFT", EM.PAD, y)
    y = y - 26
  end
  d:SetHeight(-y + EM.PAD - 4)
  EM.height = -y + EM.PAD - 4
end

function EM.Sync()
  local d = EM.dialog
  if not d then return end
  for _, r in pairs(d.rows) do if r.Refresh then pcall(r.Refresh, r) end end
end

-- à côté du panneau : à droite s'il y a la place, sinon à gauche
function EM.Place()
  local d, f = EM.dialog, Panel()
  if not (d and f) then return end
  d:ClearAllPoints()
  local r = f.GetRight and N(f:GetRight())
  local sw = UIParent and UIParent.GetWidth and N(UIParent:GetWidth()) or 1920
  if r and r + 8 + EM.W > sw then
    d:SetPoint("TOPRIGHT", f, "TOPLEFT", -8, 0) EM.side = "gauche"
  else
    d:SetPoint("TOPLEFT", f, "TOPRIGHT", 8, 0) EM.side = "droite"
  end
end

function EM.OpenDialog()
  local d = EM.BuildDialog()
  if not d then return nil end
  EM.Sync()
  EM.Place()
  d:Show()
  return d
end

------------------------------------------------------------------------------
-- /drop edit (repli sans API du mode édition, ou à la demande)
------------------------------------------------------------------------------
ns.SlashExt = ns.SlashExt or {}
ns.SlashExt.edit = function()
  if InCombat() then Say(Tr["en combat : réessaie après le combat."]) return end
  if EM.active then EM.Exit() Say(Tr["mode édition du panneau : fermé"])
  else EM.Enter("/drop edit") EM.Select() Say(Tr["mode édition du panneau : clic sur le panneau = réglages, glisser = déplacer (/drop edit pour fermer)"]) end
end
ns.SlashExt["edition"] = ns.SlashExt.edit
ns.SlashExt["édition"] = ns.SlashExt.edit
ns.HelpExt = ns.HelpExt or {}
ns.HelpExt[#ns.HelpExt + 1] = "/drop edit : calque d'édition + fenêtre de réglages rapides (s'ouvre aussi avec le mode édition du jeu)"

ns.DebugExt = ns.DebugExt or {}
ns.DebugExt[#ns.DebugExt + 1] = function()
  EM.Sections()
  return { string.format("— Mode édition (3.3.13) — %s ; calque %s ; SelectSystem %s ; entrées %d, réglages %d ; clés périmées : %s",
    EM.active and ("actif (" .. tostring(EM.how) .. ")") or "inactif", tostring(EM.overlayKind or "pas encore créé"),
    EM._selHooked and "suivi" or "absent", EM.stats.enter, EM.stats.sets, (#(EM.stale or {}) > 0) and table.concat(EM.stale, ", ") or "aucune") }
end
