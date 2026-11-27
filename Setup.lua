-- Dropamine — 3.8.1 : visite guidée du premier lancement (3.13.0 : cadre du jeu, icône par page, points de progression,
-- aperçus de thème, page Récompenses, récap final).
-- Huit pages courtes : chaque fonction est présentée, essayable et activable / désactivable
-- (mêmes options que la fenêtre Options). S'affiche une seule fois sur un compte sans réglages
-- enregistrés ; /drop setup la rouvre.
local ADDON, ns = ...
local Tr = ns.L or setmetatable({}, { __index = function(_, k) return k end })
local S = {}
ns.Setup = S

local function UIDB() return ns.EnsureDB and ns.EnsureDB().ui or {} end
local function TotalMax()
  local snap = ns.UI and ns.UI.snapshot
  return (snap and tonumber(snap.totalMax)) or tonumber(ns.TOTAL_MAX) or 2460
end

local function Opt(key, on)
  local ui = UIDB()
  if on then return ui[key] ~= false end
  return ui[key] == true and ui.sounds ~= false
end

-- actions de test (rejouent l'effet, même si la fonction est décochée)
local function TestGain()
  local P = ns.Progress
  if P and P.Toast then P.Toast(Tr["Compétence +1"], Tr["Exemple de gain"], { kind = "progress" }, "setup-gain") end
end
local function TestLevel()
  local ui = ns.UI
  if ui and ui.SpawnDrop then
    pcall(ui.SpawnDrop, ui, ns.LEVEL_ICON, Tr["Niveau atteint !"], Tr["Exemple"], nil, nil, nil, { kind = "levelup", variant = "gold", big = true })
  end
end
local function TestSound()
  local ui = ns.UI
  if type(_G.PlaySound) == "function" and ui and ui.LevelUpSoundKit then
    local kit = ui:LevelUpSoundKit()
    if kit then pcall(_G.PlaySound, kit) end
  end
end
local function TestTier() local P = ns.Progress if P and P.DingFx then P.DingFx(1500, TotalMax(), true) end end
local function TestMax() local P = ns.Progress if P and P.DingFx then P.DingFx(TotalMax(), TotalMax(), true) end end
local function TestHunt() if ns.SlashExt and ns.SlashExt.chasse then ns.SlashExt.chasse("test") end end
local function TestLoot() local O = ns.Options if O and O.PlayTestNow then pcall(O.PlayTestNow, "lootAlerts") end end
local function OpenLootSettings()
  local O = ns.Options
  if O and O.Open then pcall(O.Open) end
  if O and O.SelectTab then pcall(O.SelectTab, "hunt") end
end
local function OpenPanel() if ns.UI and ns.UI.Toggle then pcall(ns.UI.Toggle, ns.UI) end end
local function OpenProgress(tab) if ns.ProgressUI and ns.ProgressUI.Open then pcall(ns.ProgressUI.Open, tab) end end

-- Les pages : titre, icône, texte, cases (option, défaut actif ?, libellé), boutons
-- 3.13.0 : 8 pages (Gains, Montée de niveau et Paliers réunis dans « Récompenses »), une icône du jeu par page
local ICONS = "Interface\\Icons\\"
S.STEPS = {
  { title = "Bienvenue dans Dropamine", icon = "logo",
    text = "Dropamine rend ta progression visible : chaque compétence, chaque métier et ton niveau total, avec de petites récompenses à chaque pas. Cette visite dure une minute, tu peux tout essayer et couper ce qui ne te plaît pas." },
  { title = "Les cases", icon = ICONS .. "Trade_Mining",
    text = "Chaque case est une compétence ou un métier, avec son niveau et son maximum. Survole une case pour le détail, clic droit pour t'en faire un objectif. Le niveau total se lit en bas.",
    themes = true,
    -- 3.10.0 : barre du niveau total, cochable dès la visite
    checks = { { "showTotal", false, "Afficher le niveau total",
      get = function() return (ns.db and ns.db.ui and ns.db.ui.showTotal) == true end,
      set = function(v) if ns.Wide and ns.Wide.SetShown then ns.Wide.SetShown(v) elseif ns.SetOpt then ns.SetOpt("showTotal", v or nil) end end } },
    actions = { { "Afficher / masquer le panneau", OpenPanel } } },
  { title = "Récompenses", icon = "level",
    text = "Chaque pas se sent : un petit message à chaque gain d'XP ou de compétence, une animation à chaque niveau, un toast doré à chaque palier du total (500, 1000, 1500…) et un feu d'artifice au maximum.",
    checks = { { "dropsEnabled", true, "Notifications de gain" }, { "levelUpAnim", true, "Animation de niveau" }, { "levelUpSound", false, "Son de niveau" },
      { "totalDing", true, "Palier du total" }, { "fireworks", true, "Feu d'artifice au maximum" } },
    actions = { { "Tester un gain", TestGain }, { "Tester l'animation", TestLevel }, { "Tester un palier", TestTier } } },
  { title = "Fenêtre Progression", icon = ICONS .. "INV_Scroll_03",
    text = "Succès, graphiques, records, farm et tes autres personnages : tout se trouve dans la fenêtre Progression (/drop progression ou clic gauche sur la goutte).",
    actions = { { "Ouvrir la fenêtre", function() OpenProgress() end } } },
  -- 3.11.1 : Collection et Chasse BiS sont deux choses distinctes, présentées sur deux pages
  { title = "Collection", icon = ICONS .. "INV_Box_01",
    text = "Le carnet de tout ce que tu as obtenu : donjon par donjon, boss par boss, les objets que tu as en couleur, ceux qui manquent en gris. Il se remplit tout seul, sans rien suivre. C'est le cœur du jeu complétionniste.",
    actions = { { "Ouvrir la Collection", function() OpenProgress("collection") end } } },
  -- 3.11.1 : la chasse est un choix (les complétionnistes peuvent la couper, le carnet reste)
  { title = "Chasse BiS", icon = ICONS .. "INV_Sword_04",
    text = "Tu vises un objet précis (ou tes favoris du Journal des donjons) : Dropamine compte tes essais et te prévient quand il tombe. Tu préfères seulement le carnet ? Décoche la Chasse BiS (/drop chasse on|off).",
    checks = { { "huntOn", true, "Activer la Chasse BiS",
      set = function(v) if ns.SetOpt then ns.SetOpt("huntOn", v) end local PU = ns.ProgressUI if PU and PU.OnModeChanged then pcall(PU.OnModeChanged) end end },
      { "huntAlert", true, "Alerte quand un objet suivi tombe" } },
    actions = { { "Tester l'alerte", TestHunt }, { "Ouvrir la Chasse", function() OpenProgress("hunt") end } } },
  -- 3.8.2 : nouveauté présentée à tous (la visite est relancée une fois, voir S.TOUR_VERSION)
  { title = "Alertes de butin", icon = ICONS .. "INV_Misc_Gem_Sapphire_02",
    text = "Un toast dans la couleur de l'objet quand tu reçois un objet rare, épique ou légendaire. Choisis les qualités dans les réglages (onglet Chasse), ou « Aucun » pour couper. Clic sur le toast : fiche de l'objet.",
    actions = { { "Tester l'alerte de butin", TestLoot }, { "Choisir les qualités", OpenLootSettings } } },
  { title = "C'est prêt !", icon = ICONS .. "INV_Misc_Note_01", recap = true,
    -- 3.10.0 : les deux addons qui complètent Dropamine (facultatifs)
    text = "Tout se règle dans les Options. Commandes utiles : /drop (panneau), /drop progression, /drop chasse, /drop setup (rouvrir cette visite).\n\nPour aller plus loin (facultatif) : Dungeon Journal complète la Chasse et le collection log, SkillUp Forever ajoute son trajet de métier dans les cases. Bon jeu !",
    actions = { { "Ouvrir les réglages", function() if ns.Options and ns.Options.Open then pcall(ns.Options.Open) end end } } },
}

-- Choix du thème (page « Les cases ») : trois aperçus de cases, un par intention
S.THEMES = { { "dropamine", "Dropamine", "Bord bronze à losange" }, { "neutre", "Neutre", "Fond sombre, bord fin" }, { "leger", "Léger", "Discret, sans cadre" } }
local function ThemeMode() return (ns.Theme and ns.Theme.Choice and ns.Theme.Choice()) or "dropamine" end
local PREVIEW = { ICONS .. "INV_Sword_04", ICONS .. "Trade_Mining", ICONS .. "INV_Misc_Bag_08" }
local PREVIEW_NUM = { "37", "150", "225" }
local function PaintThemeCards(f)
  if not (f and f.themeCards) then return end
  local cur, PU = ThemeMode(), ns.ProgressUI
  for _, c in ipairs(f.themeCards) do
    local on = c.mode == cur
    if PU and PU.PaintCard then PU.PaintCard(c, on) end
    c.name:SetTextColor(on and 1 or 0.85, on and 0.82 or 0.77, on and 0 or 0.54)
    c.check:SetShown(on)
  end
end
-- 3.13.0 : aperçu fidèle : mini-panneau au vrai cadre du thème (Skin.PreviewHost) avec 3 cases
-- habillées comme les vraies (masque + biseau de Theme.lua) ; « léger » : les cases seules.
S.PREVIEW_TILE, S.PREVIEW_GAP, S.PREVIEW_H = 30, 10, 52
-- une case d'aperçu : l'icône habillée comme une vraie case (repli : filet bronze)
local function PreviewTile(parent, mode, k, x, y)
  local t = CreateFrame("Frame", nil, parent)
  t:SetSize(S.PREVIEW_TILE, S.PREVIEW_TILE)
  t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
  local icon = t:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints(t)
  icon:SetTexture(PREVIEW[k])
  t.icon = icon
  local Th = ns.Theme
  if Th and Th.IconSkin and Th.Round then
    pcall(Th.Round, t, icon)
    local c = (ns.STYLE and ns.STYLE.ICON_CROP) or { 0.08, 0.92, 0.08, 0.92 }
    icon:SetTexCoord(c[1], c[2], c[3], c[4])
    t._skinned = pcall(Th.IconSkin, t)
  end
  if not t._skinned then
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local B = (ns.STYLE and ns.STYLE.BORDER) or { 0.65, 0.49, 0.27, 1 }
    local a, w = (mode == "leger") and 0.55 or 1, (mode == "dropamine") and 2 or 1
    local e = {}
    for i = 1, 4 do e[i] = t:CreateTexture(nil, "OVERLAY") e[i]:SetColorTexture(B[1], B[2], B[3], a) end
    e[1]:SetPoint("BOTTOMLEFT", t, "TOPLEFT", 1, 0) e[1]:SetPoint("BOTTOMRIGHT", t, "TOPRIGHT", -1, 0) e[1]:SetHeight(w)
    e[2]:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 1, 0) e[2]:SetPoint("TOPRIGHT", t, "BOTTOMRIGHT", -1, 0) e[2]:SetHeight(w)
    e[3]:SetPoint("TOPRIGHT", t, "TOPLEFT", 0, -1) e[3]:SetPoint("BOTTOMRIGHT", t, "BOTTOMLEFT", 0, 1) e[3]:SetWidth(w)
    e[4]:SetPoint("TOPLEFT", t, "TOPRIGHT", 0, -1) e[4]:SetPoint("BOTTOMLEFT", t, "BOTTOMRIGHT", 0, 1) e[4]:SetWidth(w)
  end
  local n = t:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  if n.SetDrawLayer then n:SetDrawLayer("OVERLAY", 3) end   -- au-dessus du biseau
  n:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -1, 2)
  n:SetText(PREVIEW_NUM[k])
  return t
end
-- l'aperçu complet d'une carte : panneau du thème (ou rien pour « léger ») + 3 cases centrées
local function ThemePreview(card, mode, x, y, w)
  local Sk = ns.Skin
  local host = Sk and Sk.PreviewHost and Sk.PreviewHost(card, mode, w)
  local parent, px, py = card, x, y
  if host then
    host:SetPoint("TOPLEFT", card, "TOPLEFT", x, -y)
    host:SetSize(w, S.PREVIEW_H)
    parent, px, py = host, 0, 0
  end
  local n, T, G = #PREVIEW, S.PREVIEW_TILE, S.PREVIEW_GAP
  local x0 = px + math.floor((w - (n * T + (n - 1) * G)) / 2)
  local y0 = py + math.floor((S.PREVIEW_H - T) / 2)
  local tiles = {}
  for i = 1, n do tiles[i] = PreviewTile(parent, mode, i, x0 + (i - 1) * (T + G), y0) end
  card.preview, card.previewTiles = host, tiles
  return host, tiles
end

local frame
local step = 1
S.MAX_CHECKS, S.MAX_ACTIONS = 5, 3

-- récap de la dernière page : ce qui est activé ou coupé, et le thème
local RECAP = { { "dropsEnabled", true, "Notifications de gain" }, { "levelUpAnim", true, "Animation de niveau" }, { "levelUpSound", false, "Son de niveau" },
  { "totalDing", true, "Palier du total" }, { "huntOn", true, "Chasse BiS" }, { "huntAlert", true, "Alerte quand un objet suivi tombe" } }
function S.RecapText()
  local on, off = {}, {}
  for _, r in ipairs(RECAP) do
    local v = Opt(r[1], r[2])
    if v then on[#on + 1] = Tr[r[3]] else off[#off + 1] = Tr[r[3]] end
  end
  local name = ThemeMode()
  for _, t in ipairs(S.THEMES) do if t[1] == name then name = Tr[t[2]] end end
  local lines = { string.format(Tr["Thème : %s"], "|cffffd100" .. name .. "|r") }
  if #on > 0 then lines[#lines + 1] = "|cff4fdc4f" .. Tr["Activé :"] .. "|r " .. table.concat(on, ", ") end
  if #off > 0 then lines[#lines + 1] = "|cff9d9d9d" .. Tr["Coupé :"] .. "|r " .. table.concat(off, ", ") end
  return table.concat(lines, "\n")
end

local function Pos(o, x, y) o:ClearAllPoints() o:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y) end

function S.Show(i)
  if not frame then return end
  local n = #S.STEPS
  step = math.max(1, math.min(n, i))
  local st = S.STEPS[step]
  local PU = ns.ProgressUI
  frame.title:SetText(Tr[st.title])
  frame.count:SetText(string.format("%d / %d", step, n))
  -- pas d'icône à côté du titre (la goutte du portrait suffit) : le titre est seul en tête de page
  frame.iconFrame:Hide()
  frame.title:ClearAllPoints()
  frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -66)
  -- texte, puis tout s'empile dessous selon sa hauteur
  frame.text:SetText(Tr[st.text])
  local y = 108 + math.floor((frame.text.GetStringHeight and tonumber(frame.text:GetStringHeight()) or 40) + 0.5) + 14
  if st.recap then
    frame.recap:SetText(S.RecapText())
    Pos(frame.recap, 22, y) frame.recap:Show()
    y = y + math.floor((frame.recap.GetStringHeight and tonumber(frame.recap:GetStringHeight()) or 40) + 0.5) + 14
  else frame.recap:Hide() end
  -- aperçus de thème
  local th = st.themes and true or false
  frame.themeLabel:SetShown(th)
  for _, c in ipairs(frame.themeCards) do c:SetShown(th) end
  if th then
    Pos(frame.themeLabel, 22, y)
    for k, c in ipairs(frame.themeCards) do Pos(c, 18 + (k - 1) * (frame.cardW + 8), y + 16) end
    PaintThemeCards(frame)
    y = y + 16 + frame.cardH + 10
  end
  -- cases à cocher : sur deux colonnes au-delà de deux
  local nc = st.checks and #st.checks or 0
  for k, row in ipairs(frame.checks) do
    local c = st.checks and st.checks[k]
    if c then
      row.cfg = c
      local col, line = 0, k - 1
      if nc > 2 then col, line = (k - 1) % 2, math.floor((k - 1) / 2) end
      Pos(row.cb, 16 + col * 250, y + line * 26)
      if c.get then row.cb:SetChecked(c.get() and true or false) else row.cb:SetChecked(Opt(c[1], c[2])) end
      row.label:SetText(Tr[c[3]])
      row.cb:Show() row.label:Show()
    else
      row.cb:Hide() row.label:Hide()
    end
  end
  if nc > 0 then y = y + (nc > 2 and math.ceil(nc / 2) or nc) * 26 + 8 end
  -- boutons d'essai, sur une ligne
  local x = 20
  for k, b in ipairs(frame.actions) do
    local a = st.actions and st.actions[k]
    if a then
      b.fn = a[2]
      if b.SetText then b:SetText(Tr[a[1]]) elseif b.fs then b.fs:SetText(Tr[a[1]]) end
      local fs = b.fs or (b.GetFontString and b:GetFontString())
      local w = math.max(90, math.floor(((fs and fs.GetStringWidth and tonumber(fs:GetStringWidth())) or 70) + 28))
      b:SetWidth(w)
      Pos(b, x, y)
      x = x + w + 6
      b:Show()
      if PU and PU.PaintButton then PU.PaintButton(b) end
    else
      b:Hide()
    end
  end
  -- points de progression : fait, en cours, à venir
  for k, d in ipairs(frame.dots) do
    if k == step then d.tex:SetVertexColor(1, 0.82, 0, 1) d:SetSize(12, 12)
    elseif k < step then d.tex:SetVertexColor(0.65, 0.49, 0.27, 1) d:SetSize(9, 9)
    else d.tex:SetVertexColor(0.35, 0.35, 0.35, 1) d:SetSize(9, 9) end
  end
  frame.prev:SetShown(step > 1)
  frame.skip:SetShown(step < n)
  local nt = step < n and Tr["Suivant ›"] or Tr["C'est parti !"]
  if frame.nextBtn.SetText then frame.nextBtn:SetText(nt) elseif frame.nextBtn.fs then frame.nextBtn.fs:SetText(nt) end
  if PU and PU.PaintButton then PU.PaintButton(frame.nextBtn) PU.PaintButton(frame.prev) PU.PaintButton(frame.skip) end
end

-- 3.8.2 : version de la visite. Si elle est plus récente que celle validée sur le compte, la visite
-- s'ouvre une fois au prochain chargement, y compris pour les joueurs existants ; validée (« C'est parti ! »
-- ou « Passer »), elle ne revient plus jusqu'à la prochaine version.
S.TOUR_VERSION = 2
function S.Close(done)
  if done then
    local ui = UIDB()
    ui.setupDone = true
    ui.tourVersion = S.TOUR_VERSION
  end
  if frame then frame:Hide() end
end

-- 3.13.0 : cadre du jeu à portrait (comme la fenêtre Progression), repli sur notre carte
local function Shell(W, H)
  local PU = ns.ProgressUI
  local ok, f = pcall(CreateFrame, "Frame", "DropamineSetupFrame", _G.UIParent, "PortraitFrameTemplate")
  if ok and f then
    f.native = true
    f:SetSize(W, H)
    if type(f.SetTitle) == "function" then pcall(f.SetTitle, f, "Dropamine · " .. Tr["Visite"]) end
    local DW = ns.DebugWindow
    if DW and DW.DecoratePortrait then pcall(DW.DecoratePortrait, f) end
    local close = rawget(f, "CloseButton")
    if type(close) == "table" and close.SetScript then close:SetScript("OnClick", function() S.Close(true) end) end
    return f
  end
  f = PU.Card(_G.UIParent, 0, 0, W, H, "")
  S.SolidBack(f)
  if PU.PaintCard then PU.PaintCard(f) end
  return f
end

function S.Open()
  local PU = ns.ProgressUI
  if not (PU and PU.Card and PU.Button and _G.UIParent) then return end
  if frame then frame:Show() S.Show(1) return end
  -- les registres de widgets n'existent qu'après la première ouverture de la fenêtre Progression
  PU.cards, PU.buttons, PU.texts, PU.pillGroups = PU.cards or {}, PU.buttons or {}, PU.texts or {}, PU.pillGroups or {}
  local W, H = 540, 420
  local f = Shell(W, H)
  frame = f
  f:ClearAllPoints()
  f:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 60)
  f:SetFrameStrata("DIALOG")
  -- 3.13.0 : au premier plan comme les autres fenêtres (Dungeon Journal…) : un clic la remet devant, l'ouverture aussi
  f:SetToplevel(true) f:Raise() f:HookScript("OnShow", function(self) self:Raise() end)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  -- en-tête de page : icône encadrée, titre, étape
  f.iconFrame = CreateFrame("Frame", nil, f)
  f.iconFrame:SetSize(40, 40)
  f.iconFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -62)
  f.icon = f.iconFrame:CreateTexture(nil, "ARTWORK")
  f.icon:SetAllPoints(f.iconFrame)
  local ring = f.iconFrame:CreateTexture(nil, "OVERLAY")
  ring:SetTexture("Interface\\Buttons\\UI-Quickslot2")
  ring:SetSize(72, 72)
  ring:SetPoint("CENTER", f.iconFrame, "CENTER", 0, -1)
  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  f.title:SetPoint("LEFT", f.iconFrame, "RIGHT", 12, 4)
  f.count = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.count:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)
  f.line = f:CreateTexture(nil, "ARTWORK")
  f.line:SetColorTexture(0.65, 0.49, 0.27, 0.6)
  f.line:SetHeight(1)
  f.line:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -100)
  f.line:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -100)
  f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.text:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -108)
  f.text:SetWidth(W - 40)
  f.text:SetJustifyH("LEFT")
  if f.text.SetWordWrap then f.text:SetWordWrap(true) end
  f.recap = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.recap:SetWidth(W - 44)
  f.recap:SetJustifyH("LEFT")
  if f.recap.SetWordWrap then f.recap:SetWordWrap(true) end
  f.recap:Hide()
  -- cases à cocher (5 maximum par page, sur deux colonnes au-delà de deux)
  f.checks = {}
  for k = 1, S.MAX_CHECKS do
    local row = {}
    row.cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    row.cb:SetSize(24, 24)
    row.label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.label:SetPoint("LEFT", row.cb, "RIGHT", 2, 0)
    row.cb:SetScript("OnClick", function(self)
      local c = row.cfg
      if not c then return end
      local on = self:GetChecked() and true or false
      if c.set then pcall(c.set, on) if ns.Options and ns.Options.Sync then pcall(ns.Options.Sync) end
      elseif ns.SetOpt then pcall(ns.SetOpt, c[1], on) end
      if c[1] == "levelUpSound" and on and ns.SetOpt then pcall(ns.SetOpt, "sounds", true) end
    end)
    row.cb:Hide() row.label:Hide()
    f.checks[k] = row
  end
  -- choix du thème : trois aperçus cliquables
  f.themeLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.themeLabel:SetText(Tr["Apparence du panneau"])
  f.cardW, f.cardH = math.floor((W - 36 - 16) / 3), 44 + S.PREVIEW_H + 8   -- nom, description, aperçu
  f.themeCards = {}
  for k, t in ipairs(S.THEMES) do
    local c = PU.Card(f, 0, 0, f.cardW, f.cardH)
    c.mode = t[1]
    c.name = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    c.name:SetPoint("TOPLEFT", c, "TOPLEFT", 10, -9)
    c.name:SetText(Tr[t[2]])
    c.desc = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    c.desc:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -2)
    c.desc:SetText(Tr[t[3]])
    c.check = c:CreateTexture(nil, "OVERLAY")
    c.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    c.check:SetSize(20, 20)
    c.check:SetPoint("TOPRIGHT", c, "TOPRIGHT", -4, -4)
    ThemePreview(c, t[1], 8, 44, f.cardW - 16)
    c:EnableMouse(true)
    c:SetScript("OnMouseUp", function()
      local before = ThemeMode()
      if ns.Theme and ns.Theme.Set then pcall(ns.Theme.Set, t[1]) end
      if ns.Options and ns.Options.Sync then pcall(ns.Options.Sync) end
      PaintThemeCards(f)
      if ThemeMode() ~= before and ns.AskReload then pcall(ns.AskReload) end
    end)
    c:Hide()
    f.themeCards[k] = c
  end
  -- boutons d'essai (3 maximum)
  f.actions = {}
  for k = 1, S.MAX_ACTIONS do
    f.actions[k] = PU.Button(f, 120, 22, "", "small", function(self) if self.fn then pcall(self.fn) end end)
    f.actions[k]:Hide()
  end
  -- navigation : Passer à gauche, points au centre, Précédent / Suivant à droite
  f.nextBtn = PU.Button(f, 110, 22, "", "share", function()
    if step >= #S.STEPS then S.Close(true) else S.Show(step + 1) end
  end)
  f.nextBtn:ClearAllPoints() f.nextBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 12)
  f.prev = PU.Button(f, 96, 22, Tr["‹ Précédent"], "small", function() S.Show(step - 1) end)
  f.prev:ClearAllPoints() f.prev:SetPoint("RIGHT", f.nextBtn, "LEFT", -6, 0)
  f.skip = PU.Button(f, 80, 22, Tr["Passer"], "small", function() S.Close(true) end)
  f.skip:ClearAllPoints() f.skip:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 12)
  f.dots = {}
  local n = #S.STEPS
  for k = 1, n do
    local d = CreateFrame("Button", nil, f)
    d:SetSize(9, 9)
    d:SetPoint("CENTER", f, "BOTTOM", (k - (n + 1) / 2) * 16, 46)   -- au-dessus des boutons (ils ne se chevauchent plus)
    d.tex = d:CreateTexture(nil, "ARTWORK")
    d.tex:SetAllPoints(d)
    d.tex:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")   -- disque blanc : la couleur vient de SetVertexColor
    d:SetScript("OnClick", function() S.Show(k) end)
    f.dots[k] = d
  end
  S.Show(1)
end

-- premier lancement : seulement si aucun réglage n'a jamais été enregistré
ns.On("ADDON_LOADED", function(_, name)
  if name ~= ADDON then return end
  local ui = UIDB()
  if ui.setupDone == nil and next(ui) ~= nil then ui.setupDone = true end   -- compte existant : pas la 1re visite…
  -- …mais une visite d'une version plus récente s'affiche une fois à tout le monde
  S.pending = ui.setupDone == nil or (tonumber(ui.tourVersion) or 1) < S.TOUR_VERSION
end)
ns.On("PLAYER_ENTERING_WORLD", function()
  if not S.pending then return end
  S.pending = false
  if _G.C_Timer and _G.C_Timer.After then
    _G.C_Timer.After(6, function()
      if ns.InCombat and ns.InCombat() then return end
      -- nouvelle installation : thème Léger par défaut (les comptes existants gardent le leur)
      local ui = UIDB()
      if ui.theme == nil and ns.Theme and ns.Theme.Set then pcall(ns.Theme.Set, "leger") end
      pcall(S.Open)
    end)
  end
end)

ns.SlashExt = ns.SlashExt or {}
ns.SlashExt.setup = function() S.Open() end
ns.HelpExt = ns.HelpExt or {}
ns.HelpExt[#ns.HelpExt + 1] = "/drop setup : assistant de configuration et de test"

-- Page « À propos » (bouton « ? » de la fenêtre Progression, /drop about) --------------------
-- Les adresses s'affichent dans des zones copiables (le jeu n'ouvre pas de lien). Une entrée
-- sans adresse n'est pas montrée : renseigne S.LINKS.twitter / S.LINKS.curseforge pour l'afficher.
S.LINKS = {
  { id = "github", label = "GitHub", url = "https://github.com/Raykuilu/Dropamine" },
  { id = "bug", label = "Signaler un bug", url = "https://github.com/Raykuilu/Dropamine/issues/new?template=bug_report.yml" },
  { id = "curseforge", label = "CurseForge", url = "https://www.curseforge.com/wow/addons/dropamine" },
  { id = "twitter", label = "Twitter / X", url = "https://x.com/raykuilu" },
}
local about
local function Version()
  local f = (_G.C_AddOns and _G.C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
  if f then local ok, v = pcall(f, ADDON, "Version") if ok and v then return v end end
  return "?"
end
-- 3.13.0 : fond opaque d'une fenêtre : celui de sa bordure (coins arrondis du cadre jeu), sinon une texture en retrait
function S.SolidBack(f)
  if f._bd and f.SetBackdropColor then
    if f.bg then f.bg:Hide() end
    f._solid = true
    pcall(f.SetBackdropColor, f, 0.07, 0.065, 0.055, 0.97)
    return
  end
  local solid = f:CreateTexture(nil, "BACKGROUND", nil, -1)
  solid:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -3)
  solid:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 3)
  solid:SetColorTexture(0.07, 0.065, 0.055, 0.97)
end
function S.OpenAbout()
  local PU = ns.ProgressUI
  if not (PU and PU.Card and PU.Button and _G.UIParent) then return end
  if about then about:SetShown(not about:IsShown()) return end
  PU.cards, PU.buttons, PU.texts, PU.pillGroups = PU.cards or {}, PU.buttons or {}, PU.texts or {}, PU.pillGroups or {}
  local links = {}
  for _, l in ipairs(S.LINKS) do if l.url then links[#links + 1] = l end end
  local W, H = 520, 276 + #links * 30
  local f = PU.Card(_G.UIParent, 0, 0, W, H, "")
  f:ClearAllPoints()
  f:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 60)
  f:SetFrameStrata("DIALOG")
  -- 3.13.0 : au premier plan comme les autres fenêtres (Dungeon Journal…) : un clic la remet devant, l'ouverture aussi
  f:SetToplevel(true) f:Raise() f:HookScript("OnShow", function(self) self:Raise() end)
  S.SolidBack(f)
  f:EnableMouse(true) f:SetMovable(true) f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  f:SetScript("OnKeyDown", nil)
  if f.title then f.title:SetText("") end
  local logo = f:CreateTexture(nil, "ARTWORK")
  logo:SetSize(44, 44)
  logo:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -12)
  logo:SetTexture((ns.Progress and ns.Progress.ICON) or "Interface\\AddOns\\Dropamine\\Media\\Dropamine-Icon")
  local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  t:SetPoint("TOPLEFT", f, "TOPLEFT", 66, -16)
  t:SetText("Dropamine")
  t:SetTextColor(1, 0.82, 0)
  local v = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  v:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -3)
  v:SetText(Tr["Version "] .. Version() .. "  ·  " .. Tr["par Raykuilu"])
  v:SetTextColor(0.7, 0.66, 0.55)
  local d = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  d:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -72)
  d:SetWidth(W - 32) d:SetJustifyH("LEFT")
  if d.SetWordWrap then d:SetWordWrap(true) end
  d:SetText(Tr["Dropamine rend ta progression visible et gratifiante : compétences, métiers, niveau total, succès, chasse aux objets et collection."])
  d:SetTextColor(0.9, 0.86, 0.75)
  local y = 118
  local rows = {}
  for _, l in ipairs(links) do
    local lb = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lb:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -(y + 5))
    lb:SetText(Tr[l.label])
    lb:SetTextColor(0.85, 0.77, 0.54)
    local eb = _G.CreateFrame("EditBox", nil, f)
    eb:SetSize(W - 32 - 110, 20)
    eb:SetPoint("TOPLEFT", f, "TOPLEFT", 126, -y)
    eb:SetFontObject(_G.GameFontHighlightSmall)
    eb:SetAutoFocus(false)
    eb:SetTextInsets(5, 5, 0, 0)
    eb:SetText(l.url)
    eb:SetCursorPosition(0)
    local bg = eb:CreateTexture(nil, "BACKGROUND") bg:SetAllPoints(eb) bg:SetColorTexture(0.03, 0.03, 0.03, 0.9)
    eb:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    eb:SetScript("OnTextChanged", function(self, user) if user then self:SetText(l.url) self:HighlightText() end end)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    rows[#rows + 1] = { lb = lb, eb = eb, y = y }
    y = y + 30
  end
  -- 3.13.0 : la colonne des adresses commence après le plus long libellé (« Signaler un bug (/drop bug) » était coupé)
  local lw = 0
  for _, r in ipairs(rows) do lw = math.max(lw, (r.lb.GetStringWidth and r.lb:GetStringWidth()) or 0) end
  lw = math.max(100, math.min(200, math.floor(lw + 0.5)))
  for _, r in ipairs(rows) do
    r.eb:ClearAllPoints()
    r.eb:SetPoint("TOPLEFT", f, "TOPLEFT", 16 + lw + 12, -r.y)
    r.eb:SetWidth(W - 32 - lw - 12)
  end
  local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 110)
  hint:SetWidth(W - 32) hint:SetJustifyH("LEFT")
  if hint.SetWordWrap then hint:SetWordWrap(true) end
  hint:SetText(Tr["Clique une adresse, Ctrl+C pour la copier."] .. " " .. Tr["Pour un bug : /drop bug prépare le rapport."])
  local th0 = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  th0:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 88)
  th0:SetText(Tr["Suivi des compétences et collection log inspirés d'Old School RuneScape (projet non affilié)."])
  local th = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  th:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 74)
  th:SetText(Tr["Merci à Flare UI pour l'inspiration visuelle."])
  local th2 = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  th2:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 60)
  th2:SetText(Tr["Merci à Exehn (Dungeon Journal) pour sa base et l'accès aux favoris."])
  -- 3.10.0 : lien optionnel avec SkillUp Forever (API publique, aucun code repris)
  local th3 = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  th3:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 46)
  th3:SetText(Tr["Merci à cjber (SkillUp Forever) pour son API publique, utilisée par le lien optionnel."])
  local close = PU.Button(f, 70, 22, Tr["Fermer"], "share", function() f:Hide() end)
  close:ClearAllPoints() close:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 12)
  local optb = PU.Button(f, 90, 22, Tr["Réglages"], "share", function() f:Hide() if ns.Options and ns.Options.Open then pcall(ns.Options.Open) end end)
  optb:ClearAllPoints() optb:SetPoint("RIGHT", close, "LEFT", -6, 0)
  local tourb = PU.Button(f, 120, 22, Tr["Revoir la visite"], "share", function() f:Hide() if S.Open then S.Open() end end)
  tourb:ClearAllPoints() tourb:SetPoint("RIGHT", optb, "LEFT", -6, 0)
  if PU.PaintCard then PU.PaintCard(f) end
  if PU.PaintButton then PU.PaintButton(close) PU.PaintButton(optb) PU.PaintButton(tourb) end
  about = f
end
ns.SlashExt.about = function() S.OpenAbout() end
ns.HelpExt[#ns.HelpExt + 1] = "/drop about : à propos, liens et signalement de bug"
