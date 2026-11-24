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

function DW.Build()
  if DW.frame then return DW.frame end
  local f = CreateFrame("Frame", DW.NAME, UIParent)
  f._osrsOwn = true
  f:SetSize(DW.W, DW.H)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  P(f, "SetFrameStrata", "DIALOG")
  P(f, "SetClampedToScreen", true)
  P(f, "SetMovable", true)
  P(f, "EnableMouse", true)
  P(f, "RegisterForDrag", "LeftButton")
  f:SetScript("OnDragStart", function(self) P(self, "StartMoving") end)
  f:SetScript("OnDragStop", function(self) P(self, "StopMovingOrSizing") end)
  -- habillage : la recette du panneau (FlareUI / classique selon le thème), fond opaque
  local Sk = ns.Skin
  if Sk and Sk.Host then
    local host = Sk.Host(f)
    if host and Sk.Paint then Sk.Paint(host, 0.96) end
    DW.host = host
  end
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -12)
  title:SetText(Tr["Dropamine — debug (Ctrl+C pour copier)"])
  DW.title = title
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
  close:SetScript("OnClick", function() f:Hide() end)
  DW.close = close
  local sf = CreateFrame("ScrollFrame", DW.NAME .. "Scroll", f, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -34)
  sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -32, 14)
  DW.scroll = sf
  local eb = CreateFrame("EditBox", DW.NAME .. "Edit", sf)
  P(eb, "SetMultiLine", true)
  P(eb, "SetAutoFocus", false)
  P(eb, "SetFontObject", _G.ChatFontNormal or _G.GameFontHighlightSmall)
  eb:SetWidth(DW.W - 50)
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

-- mise en page : place libre en bas pour le bouton en mode saisie
local function Layout(editable)
  local sf = DW.scroll
  sf:ClearAllPoints()
  sf:SetPoint("TOPLEFT", DW.frame, "TOPLEFT", 14, -34)
  sf:SetPoint("BOTTOMRIGHT", DW.frame, "BOTTOMRIGHT", -32, editable and 40 or 14)
  if editable then DW.accept:Show() else DW.accept:Hide() end
end

-- opts.title (3.9.0) : titre de la fenêtre (sinon celui du debug)
function DW.Show(lines, opts)
  local f = DW.Build()
  DW.editable, DW.onAccept = nil, nil
  Layout(false)
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
