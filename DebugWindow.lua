-- Dropamine 3.4.3 — /drop debug dans une FENÊTRE COPIABLE (au lieu du chat seul).
-- Cadre à nous (enfant d'UIParent) habillé comme le panneau, zone de texte
-- multiligne défilante, texte présélectionné (HighlightText + focus) : Ctrl+C
-- suffit. Fermeture : bouton ✕ ou Échap. Diagnostic « métier en cours » en tête ;
-- « /drop debug metier » n'affiche que lui. Rien n'est créé avant le 1er appel.
local ADDON, ns = ...
local Tr = ns.L   -- 3.5.19 : textes traduits (Locales/)
local DW = {}
ns.DebugWindow = DW
DW.NAME = "DropamineDebugWindow"
DW.W, DW.H = 620, 420

local function P(o, m, ...) if type(o) == "table" and type(o[m]) == "function" then return pcall(o[m], o, ...) end end

-- 3.10.0 : fenêtre du jeu (cadre à portrait + encart), comme les rapports des addons Forever.
-- Repli sur l'ancien habillage si le client n'a pas ces modèles.
DW.ICON = "Interface\\AddOns\\Dropamine\\Media\\Dropamine-Icon"
local function NativeFrame()
  local ok, f = pcall(CreateFrame, "Frame", DW.NAME, UIParent, "PortraitFrameTemplate")
  if not (ok and f) then return nil end
  f:SetSize(DW.W, DW.H)
  if type(f.SetTitle) == "function" then pcall(f.SetTitle, f, "Dropamine") end
  DW.portraitIcon = DW.DecoratePortrait(f)
  local hint = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  hint:SetPoint("TOPLEFT", f, "TOPLEFT", 70, -32)
  hint:SetPoint("RIGHT", f, "RIGHT", -16, 0)
  if hint.SetJustifyH then hint:SetJustifyH("LEFT") end
  DW.title = hint
  local okI, inset = pcall(CreateFrame, "Frame", nil, f, "InsetFrameTemplate")
  DW.inset = okI and inset or nil
  DW.native = true
  return f
end
-- 3.13.0 : portrait d'un cadre du jeu (PortraitFrameTemplate) : disque noir, goutte Dropamine au centre.
-- Partagé avec la fenêtre Progression (style « jeu »).
function DW.DecoratePortrait(f)
  local portrait = (type(f.GetPortrait) == "function" and select(2, pcall(f.GetPortrait, f))) or f.portrait
    or (f.PortraitContainer and f.PortraitContainer.portrait)
  if portrait and portrait.SetTexture then
    -- disque noir dans le portrait, goutte plus petite posée au centre
    pcall(portrait.SetTexture, portrait, "Interface\\CharacterFrame\\TempPortraitAlphaMask")
    if portrait.SetVertexColor then pcall(portrait.SetVertexColor, portrait, 0, 0, 0, 1) end
    local holder = (portrait.GetParent and portrait:GetParent()) or f
    local layer, sub = "ARTWORK", 0
    if portrait.GetDrawLayer then
      local okL, l, s = pcall(portrait.GetDrawLayer, portrait)
      if okL and l then layer, sub = l, (tonumber(s) or 0) end
    end
    local icon = holder:CreateTexture(nil, layer, nil, math.min(7, sub + 1))
    local pw = (portrait.GetWidth and portrait:GetWidth()) or 60
    if not pw or pw < 10 then pw = 60 end
    icon:SetSize(pw * 0.62, pw * 0.62)
    icon:SetPoint("CENTER", portrait, "CENTER", 0, 0)
    pcall(icon.SetTexture, icon, DW.ICON)
    return icon
  end
  return nil
end
function DW.Build()
  if DW.frame then return DW.frame end
  DW.W, DW.H = 540, 420
  local f = NativeFrame()
  if not f then
    DW.W, DW.H = 620, 420
    f = CreateFrame("Frame", DW.NAME, UIParent)
    f:SetSize(DW.W, DW.H)
  end
  f._osrsOwn = true
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  P(f, "SetFrameStrata", "DIALOG")
  P(f, "SetToplevel", true)
  P(f, "SetClampedToScreen", true)
  P(f, "SetMovable", true)
  P(f, "EnableMouse", true)
  P(f, "RegisterForDrag", "LeftButton")
  f:SetScript("OnDragStart", function(self) P(self, "StartMoving") end)
  f:SetScript("OnDragStop", function(self) P(self, "StopMovingOrSizing") end)
  if not DW.native then
    -- habillage : la recette du panneau (FlareUI / classique selon le thème), fond opaque
    local Sk = ns.Skin
    if Sk and Sk.Host then
      local host = Sk.Host(f)
      if host and Sk.Paint then Sk.Paint(host, 0.96) end
      DW.host = host
    end
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -12)
    DW.title = title
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() f:Hide() end)
    DW.close = close
  end
  DW.title:SetText(Tr["Dropamine — debug (Ctrl+C pour copier)"])
  local sf = CreateFrame("ScrollFrame", DW.NAME .. "Scroll", DW.inset or f, "UIPanelScrollFrameTemplate")
  DW.scroll = sf
  local eb = CreateFrame("EditBox", DW.NAME .. "Edit", sf)
  P(eb, "SetMultiLine", true)
  P(eb, "SetAutoFocus", false)
  P(eb, "SetFontObject", _G.ChatFontNormal or _G.GameFontHighlightSmall)
  eb:SetWidth(DW.W - 66)
  P(eb, "SetMaxLetters", 0)
  eb:SetScript("OnEscapePressed", function() f:Hide() end)
  -- lecture seule : toute frappe remet le texte et le resélectionne (sauf en mode saisie, 3.9.0)
  eb:SetScript("OnTextChanged", function(self, user)
    if user and DW.text and not DW.editable then self:SetText(DW.text) P(self, "HighlightText") end
  end)
  -- 3.9.0 : bouton de validation du mode saisie (import d'un profil)
  local ok = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  ok:SetSize(110, 22)
  ok:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 10)
  ok:SetScript("OnClick", function()
    local fn = DW.onAccept
    if fn and fn(eb:GetText() or "") ~= false then f:Hide() end
  end)
  ok:Hide()
  DW.accept = ok
  eb:SetScript("OnEditFocusGained", function(self) P(self, "HighlightText") end)
  P(sf, "SetScrollChild", eb)
  DW.edit = eb
  -- Échap ferme NOTRE fenêtre de debug (pas le panneau)
  if type(_G.UISpecialFrames) == "table" then
    local seen = false
    for _, n in ipairs(_G.UISpecialFrames) do if n == DW.NAME then seen = true end end
    if not seen then table.insert(_G.UISpecialFrames, DW.NAME) end
  end
  f:Hide()
  DW.frame = f
  return f
end

-- mise en page : place libre en bas pour le bouton en mode saisie, ou pour les cases à cocher (3.11.1)
local CHECK_PER_ROW, CHECK_ROW_H = 3, 24
local function Layout(editable, checks)
  local sf = DW.scroll
  local n = checks and #checks or 0
  local rows = math.ceil(n / CHECK_PER_ROW)
  local low = editable and 40 or (rows > 0 and (14 + rows * CHECK_ROW_H)) or nil
  sf:ClearAllPoints()
  local inset = DW.inset
  if inset then
    -- 3.10.0 : encart sous la ligne d'aide, le bouton de validation dessous en mode saisie
    inset:ClearAllPoints()
    inset:SetPoint("TOPLEFT", DW.frame, "TOPLEFT", 10, -64)
    inset:SetPoint("BOTTOMRIGHT", DW.frame, "BOTTOMRIGHT", -10, low or 10)
    sf:SetPoint("TOPLEFT", inset, "TOPLEFT", 8, -8)
    sf:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -28, 8)
  else
    sf:SetPoint("TOPLEFT", DW.frame, "TOPLEFT", 14, -34)
    sf:SetPoint("BOTTOMRIGHT", DW.frame, "BOTTOMRIGHT", -32, low or 14)
  end
  if editable then DW.accept:Show() else DW.accept:Hide() end
  -- 3.11.1 : cases à cocher en bas (ex. les groupes de données de l'export Hiscores), 3 par ligne
  DW.checks = DW.checks or {}
  local colW = (DW.W - 24) / CHECK_PER_ROW
  for i = 1, math.max(n, #DW.checks) do
    local spec, cb = checks and checks[i], DW.checks[i]
    if spec and not cb and _G.CreateFrame then
      local ok, c = pcall(CreateFrame, "CheckButton", nil, DW.frame, "UICheckButtonTemplate")
      if not (ok and c) then c = CreateFrame("CheckButton", nil, DW.frame) end
      c._osrsOwn = true
      c:SetSize(24, 24)
      c.label = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      c.label:SetPoint("LEFT", c, "RIGHT", 2, 0)
      c:SetScript("OnClick", function(self)
        local fn = self.onToggle
        if fn then fn(self:GetChecked() and true or false) end
      end)
      DW.checks[i], cb = c, c
    end
    if cb then
      if spec then
        local row, col = math.floor((i - 1) / CHECK_PER_ROW), (i - 1) % CHECK_PER_ROW
        cb:ClearAllPoints()
        cb:SetPoint("BOTTOMLEFT", DW.frame, "BOTTOMLEFT", 12 + col * colW, 9 + (rows - 1 - row) * CHECK_ROW_H)
        cb.label:SetText(spec.label or "")
        P(cb, "SetChecked", spec.value and true or false)
        cb.onToggle = spec.onToggle
        cb:Show()
      else
        cb.onToggle = nil
        cb:Hide()
      end
    end
  end
end

-- opts.title (3.9.0) : titre de la fenêtre (sinon celui du debug)
-- opts.checks (3.11.1) : { { label, value, onToggle(coché) }, … } : cases à cocher sous le texte (opts.check : une seule)
function DW.Show(lines, opts)
  local f = DW.Build()
  DW.editable, DW.onAccept = nil, nil
  Layout(false, opts and (opts.checks or (opts.check and { opts.check })))
  DW.title:SetText((opts and opts.title) or Tr["Dropamine — debug (Ctrl+C pour copier)"])
  DW.lines = lines
  DW.text = table.concat(lines, "\n")
  local eb = DW.edit
  eb:SetText(DW.text)
  P(eb, "SetCursorPosition", 0)
  f:Show()
  P(eb, "SetFocus")
  P(eb, "HighlightText")
  return f
end

-- 3.9.0 : même fenêtre, en saisie : texte vide à remplir, bouton de validation (onAccept(texte) ;
-- renvoyer false garde la fenêtre ouverte)
function DW.ShowEdit(title, button, onAccept)
  local f = DW.Build()
  DW.editable, DW.onAccept, DW.text = true, onAccept, nil
  Layout(true)
  DW.title:SetText(title or "")
  DW.accept:SetText(button or "OK")
  DW.edit:SetText("")
  f:Show()
  P(DW.edit, "SetFocus")
  return f
end

-- rapport : métier en cours d'abord, puis tout le reste
function DW.Lines(part)
  local out = {}
  local A = ns.Activity
  if A and A.DebugLines then
    local ok, l = pcall(A.DebugLines)
    if ok and type(l) == "table" then for _, x in ipairs(l) do out[#out + 1] = tostring(x) end end
  end
  part = tostring(part or ""):lower()
  if part == "metier" or part == "métier" or part == "metiers" or part == "métiers" then return out end
  out[#out + 1] = " "
  if ns.DebugReport then
    local ok, l = pcall(ns.DebugReport)
    if ok and type(l) == "table" then for _, x in ipairs(l) do out[#out + 1] = tostring(x) end end
  end
  local W = ns.Window
  if W and W.DebugLines then
    local ok, l = pcall(W.DebugLines)
    if ok and type(l) == "table" then for _, x in ipairs(l) do out[#out + 1] = tostring(x) end end
  end
  return out
end

function ns.PrintDebug(part)
  local lines = DW.Lines(part)
  DW.Show(lines)
  if ns.Print then ns.Print(Tr["Debug copié dans la fenêtre (Ctrl+C pour copier, Échap pour fermer)."]) end
  return lines
end
