-- Dropamine — 3.8.1 : visite guidée du premier lancement.
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

-- Les pages : titre, texte, cases (option, défaut actif ?, libellé), boutons
S.STEPS = {
  { title = "Bienvenue dans Dropamine",
    text = "Dropamine rend ta progression visible : chaque compétence, chaque métier et ton niveau total, avec de petites récompenses à chaque pas. Cette visite dure une minute, tu peux tout essayer et couper ce qui ne te plaît pas." },
  { title = "Les cases",
    text = "Chaque case est une compétence ou un métier, avec son niveau et son maximum. Survole une case pour le détail, clic droit pour t'en faire un objectif. Le niveau total se lit en bas.",
    themes = true,
    -- 3.10.0 : barre du niveau total, cochable dès la visite
    checks = { { "showTotal", false, "Afficher le niveau total",
      get = function() return (ns.db and ns.db.ui and ns.db.ui.showTotal) == true end,
      set = function(v) if ns.Wide and ns.Wide.SetShown then ns.Wide.SetShown(v) elseif ns.SetOpt then ns.SetOpt("showTotal", v or nil) end end } },
    actions = { { "Afficher / masquer le panneau", OpenPanel } } },
  { title = "Notifications de gain",
    text = "Un petit message apparaît quand tu gagnes de l'XP ou un point de compétence, pour sentir chaque pas sans ouvrir de fenêtre.",
    checks = { { "dropsEnabled", true, "Afficher les notifications de gain" } },
    actions = { { "Tester", TestGain } } },
  { title = "Montée de niveau",
    text = "Une animation marque chaque niveau gagné. Le son est facultatif.",
    checks = { { "levelUpAnim", true, "Animation de niveau" }, { "levelUpSound", false, "Son de niveau" } },
    actions = { { "Tester l'animation", TestLevel }, { "Tester le son", TestSound } } },
  { title = "Paliers du total",
    text = "Ton niveau total franchit des paliers (500, 1000, 1500…) : un toast doré et une émote te le disent. Au maximum, un feu d'artifice.",
    checks = { { "totalDing", true, "Palier du total" }, { "fireworks", true, "Feu d'artifice au maximum" } },
    actions = { { "Tester un palier", TestTier }, { "Tester le maximum", TestMax } } },
  { title = "Fenêtre Progression",
    text = "Succès, graphiques, records, farm et tes autres personnages : tout se trouve dans la fenêtre Progression (/drop progression ou clic gauche sur la goutte).",
    actions = { { "Ouvrir la fenêtre", function() OpenProgress() end } } },
  { title = "Chasse et collection",
    text = "Suis un objet précis (ou importe tes favoris du Journal des donjons) : Dropamine compte tes tentatives et te prévient quand il tombe. Le collection log montre ce que tu as déjà obtenu.",
    checks = { { "huntAlert", true, "Alerte quand un objet suivi tombe" } },
    actions = { { "Tester l'alerte", TestHunt }, { "Ouvrir la Chasse", function() OpenProgress("hunt") end } } },
  -- 3.8.2 : nouveauté présentée à tous (la visite est relancée une fois, voir S.TOUR_VERSION)
  { title = "Nouveau : alertes de butin",
    text = "Un toast dans la couleur de l'objet quand tu reçois un objet rare, épique ou légendaire. Choisis les qualités dans les réglages (onglet Chasse), ou « Aucun » pour couper. Clic sur le toast : fiche de l'objet.",
    actions = { { "Tester l'alerte de butin", TestLoot }, { "Choisir les qualités", OpenLootSettings } } },
  { title = "C'est prêt !",
    text = "Tout se règle dans les Options. Commandes utiles : /drop (panneau), /drop progression, /drop chasse, /drop setup (rouvrir cette visite). Bon jeu !",
    actions = { { "Ouvrir les réglages", function() if ns.Options and ns.Options.Open then pcall(ns.Options.Open) end end } } },
}

-- Choix du thème (page « Les cases ») : Léger par défaut sur une nouvelle installation
S.THEMES = { { "leger", "Léger" }, { "flare2", "FlareUI" }, { "flare", "Moderne" }, { "classic", "Classique" } }
local function ThemeMode() return (ns.Theme and ns.Theme.Choice and ns.Theme.Choice()) or "flare" end
local function PaintThemeButtons(f)
  if not (f and f.themeBtns) then return end
  local cur = ThemeMode()
  for _, b in ipairs(f.themeBtns) do
    local on = (b.mode == cur)
    if b.fs then
      if on then b.fs:SetTextColor(1, 0.82, 0) else b.fs:SetTextColor(0.8, 0.76, 0.66) end
    end
    if b.SetAlpha then b.SetAlpha(b, on and 1 or 0.85) end
  end
end

local frame
local step = 1

local function Fmt(fs, txt) fs:SetText(txt or "") end

function S.Show(i)
  if not frame then return end
  local n = #S.STEPS
  step = math.max(1, math.min(n, i))
  local st = S.STEPS[step]
  frame.title:SetText(Tr[st.title])
  frame.text:SetText(Tr[st.text])
  frame.count:SetText(string.format("%d / %d", step, n))
  local PU = ns.ProgressUI
  if PU and PU.SetBar then PU.SetBar(frame.bar, step / n) end
  for k, row in ipairs(frame.checks) do
    local c = st.checks and st.checks[k]
    if c then
      row.cfg = c
      -- 3.10.0 : sur la page des thèmes, les cases passent sous les boutons
      row.cb:ClearAllPoints()
      row.cb:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -((st.themes and 180 or 148) + (k - 1) * 28))
      if c.get then row.cb:SetChecked(c.get() and true or false) else row.cb:SetChecked(Opt(c[1], c[2])) end
      row.label:SetText(Tr[c[3]])
      row.cb:Show() row.label:Show()
    else
      row.cb:Hide() row.label:Hide()
    end
  end
  for k, b in ipairs(frame.actions) do
    local a = st.actions and st.actions[k]
    if a then
      b.fn = a[2]
      b.fs:SetText(Tr[a[1]])
      b:SetWidth(math.max(80, math.floor((b.fs:GetStringWidth() or 60) + 24)))
      b:Show()
      if PU and PU.PaintButton then PU.PaintButton(b) end
    else
      b:Hide()
    end
  end
  if frame.themeLabel then
    local on = st.themes and true or false
    frame.themeLabel:SetShown(on)
    for _, b in ipairs(frame.themeBtns) do b:SetShown(on) end
    if on then PaintThemeButtons(frame) end
  end
  frame.prev:SetShown(step > 1)
  frame.skip:SetShown(step < n)
  frame.nextBtn.fs:SetText(step < n and Tr["Suivant ›"] or Tr["C'est parti !"])
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

function S.Open()
  local PU = ns.ProgressUI
  if not (PU and PU.Card and PU.Button and _G.UIParent) then return end
  if frame then frame:Show() S.Show(1) return end
  -- les registres de widgets n'existent qu'après la première ouverture de la fenêtre Progression
  PU.cards, PU.buttons, PU.texts, PU.pillGroups = PU.cards or {}, PU.buttons or {}, PU.texts or {}, PU.pillGroups or {}
  local W, H = 480, 300
  local f = PU.Card(_G.UIParent, 0, 0, W, H, "")
  f:ClearAllPoints()
  f:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 80)
  f:SetFrameStrata("DIALOG")
  local solid = f:CreateTexture(nil, "BACKGROUND", nil, -1)
  solid:SetAllPoints(f)
  solid:SetColorTexture(0.07, 0.065, 0.055, 0.97)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  if f.title then f.title:SetText("") end
  local logo = f:CreateTexture(nil, "ARTWORK")
  logo:SetSize(34, 34)
  logo:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -10)
  logo:SetTexture((ns.Progress and ns.Progress.ICON) or "Interface\\AddOns\\Dropamine\\Media\\Dropamine-Icon")
  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 56, -16)
  f.title:SetTextColor(1, 0.82, 0)
  f.count = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.count:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -16)
  f.bar = PU.NewBar(f, W - 16 - 110, 34, 110, 5)
  f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.text:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -60)
  f.text:SetWidth(W - 32)
  f.text:SetJustifyH("LEFT")
  if f.text.SetWordWrap then f.text:SetWordWrap(true) end
  f.text:SetTextColor(0.9, 0.86, 0.75)
  -- cases à cocher (2 maximum par page)
  f.checks = {}
  for k = 1, 2 do
    local row = {}
    row.cb = _G.CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    row.cb:SetSize(24, 24)
    row.cb:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -(148 + (k - 1) * 28))
    row.label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.label:SetPoint("LEFT", row.cb, "RIGHT", 4, 0)
    row.cb:SetScript("OnClick", function(self)
      local c = row.cfg
      if not c then return end
      local on = self:GetChecked() and true or false
      if c.set then pcall(c.set, on) if ns.Options and ns.Options.Sync then pcall(ns.Options.Sync) end
      elseif ns.SetOpt then pcall(ns.SetOpt, c[1], on) end
      if c[1] == "levelUpSound" and on and ns.SetOpt then pcall(ns.SetOpt, "sounds", true) end
    end)
    f.checks[k] = row
  end
  -- choix du thème
  f.themeLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.themeLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -128)
  f.themeLabel:SetText(Tr["Apparence du panneau"])
  f.themeLabel:SetTextColor(0.85, 0.77, 0.54)
  f.themeBtns = {}
  for k, t in ipairs(S.THEMES) do
    local b = PU.Button(f, 86, 22, Tr[t[2]], "small", function(self)
      if ns.Theme and ns.Theme.Set then pcall(ns.Theme.Set, t[1]) end
      if ns.Options and ns.Options.Sync then pcall(ns.Options.Sync) end
      PaintThemeButtons(f)
    end)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", f, "TOPLEFT", 16 + (k - 1) * 92, -148)
    b.mode = t[1]
    f.themeBtns[k] = b
  end
  -- boutons d'essai (2 maximum)
  f.actions = {}
  local x = 16
  for k = 1, 2 do
    local b = PU.Button(f, 120, 20, "", "small", function(self) if self.fn then pcall(self.fn) end end)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", f, "TOPLEFT", 16 + (k - 1) * 170, -(210))
    f.actions[k] = b
  end
  -- navigation
  f.nextBtn = PU.Button(f, 100, 22, "", "share", function()
    if step >= #S.STEPS then S.Close(true) else S.Show(step + 1) end
  end)
  f.nextBtn:ClearAllPoints() f.nextBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 12)
  f.prev = PU.Button(f, 80, 22, Tr["‹ Précédent"], "small", function() S.Show(step - 1) end)
  f.prev:ClearAllPoints() f.prev:SetPoint("RIGHT", f.nextBtn, "LEFT", -6, 0)
  f.skip = PU.Button(f, 70, 22, Tr["Passer"], "small", function() S.Close(true) end)
  f.skip:ClearAllPoints() f.skip:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 12)
  frame = f
  if PU.PaintCard then PU.PaintCard(f) end
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
  { id = "bug", label = "Signaler un bug (/drop bug prépare le rapport)", url = "https://github.com/Raykuilu/Dropamine/issues/new?template=bug_report.yml" },
  { id = "curseforge", label = "CurseForge", url = "https://www.curseforge.com/wow/addons/dropamine" },
  { id = "twitter", label = "Twitter / X", url = "https://x.com/raykuilu" },
}
local about
local function Version()
  local f = (_G.C_AddOns and _G.C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
  if f then local ok, v = pcall(f, ADDON, "Version") if ok and v then return v end end
  return "?"
end
function S.OpenAbout()
  local PU = ns.ProgressUI
  if not (PU and PU.Card and PU.Button and _G.UIParent) then return end
  if about then about:SetShown(not about:IsShown()) return end
  PU.cards, PU.buttons, PU.texts, PU.pillGroups = PU.cards or {}, PU.buttons or {}, PU.texts or {}, PU.pillGroups or {}
  local links = {}
  for _, l in ipairs(S.LINKS) do if l.url then links[#links + 1] = l end end
  local W, H = 520, 262 + #links * 30
  local f = PU.Card(_G.UIParent, 0, 0, W, H, "")
  f:ClearAllPoints()
  f:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 60)
  f:SetFrameStrata("DIALOG")
  local solid = f:CreateTexture(nil, "BACKGROUND", nil, -1)
  solid:SetAllPoints(f)
  solid:SetColorTexture(0.07, 0.065, 0.055, 0.97)
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
    y = y + 30
  end
  local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 96)
  hint:SetText(Tr["Clique une adresse, Ctrl+C pour la copier."])
  local th0 = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  th0:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 74)
  th0:SetText(Tr["Suivi des compétences et collection log inspirés d'Old School RuneScape (projet non affilié)."])
  local th = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  th:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 60)
  th:SetText(Tr["Merci à Flare UI pour l'inspiration visuelle."])
  local th2 = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  th2:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 46)
  th2:SetText(Tr["Merci à Exehn (Dungeon Journal) pour sa base et l'accès aux favoris."])
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
