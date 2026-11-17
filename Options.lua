-- Dropamine : panneau d'options (catégorie AddOns des Options natives).
-- Chaque réglage reflète une commande /drop et la même clé de SavedVariables.
local ADDON, ns = ...
local Options = {}
ns.Options = Options

-- v2.7.2 : registre rangé par sections (ordre fixé dans STYLEGUIDE.md).
-- Chaque réglage : type, clé SV, libellé, défaut, commande /drop, aide facultative.
-- 3.3.8 : panneau réordonné en groupes clairs (Affichage, Notifications,
-- Cibles & récolte, Métiers, Infobulle des cases & rappels). Curseurs et menus
-- pour les valeurs, cases seulement pour un vrai on/off. Chaque réglage =
-- une commande /drop (même effet, même mémoire). Retirés : « Afficher les
-- caractéristiques » (volet de détail supprimé en 3.3.5), « Sens d'empilement »
-- et « Coller au chat » (remplacés par la position des notifications).
local function DBui() return ns.EnsureDB().ui end
local function PanelM() return ns.Panel end
local function LayoutM() return ns.Layout end
-- 3.4.0 (pré-version) : 5 groupes courts, libellés simples, une phrase d'aide
-- par réglage. Les clés de sauvegarde et les commandes /drop ne changent pas
-- (aucune valeur enregistrée perdue). Rare / technique → « Avancé ».
Options.SECTIONS = {
  { id = "display", title = "Affichage & thème", desc = "L'apparence du panneau : thème, disposition, taille.", items = {
    { type = "radio", key = "theme", label = "Thème", default = "flare", cmd = "/drop theme flare|leger|classic",
      choices = { { "flare", "FlareUI (sombre, bord arrondi)" }, { "leger", "Léger (cases seules, sans cadre)" }, { "classic", "Classique (look Blizzard)" } },
      help = "Change l'habillage du panneau, des cases et des toasts.",
      get = function() return ns.Theme and ns.Theme.Mode() or "flare" end,
      set = function(v) if ns.Theme then ns.Theme.Set(v) end end },
    { type = "radio", key = "cols", label = "Colonnes", default = 5, cmd = "/drop colonnes 1|2|3|5|10",
      choices = { { 1, "1 colonne" }, { 2, "2 colonnes" }, { 3, "3 colonnes" }, { 5, "5 colonnes" }, { 10, "10 colonnes (1 rangée)" } },
      help = "Nombre de cases par rangée (aussi : poignée du coin, Alt+glisser).",
      get = function() return LayoutM() and LayoutM().Cols() or 5 end,
      set = function(v) if LayoutM() then LayoutM().SetCols(v) end end },
    { type = "slider", key = "scale", label = "Taille", default = 100, min = 50, max = 200, step = 1, unit = "pct", cmd = "/drop taille <50-200>",
      help = "Taille du panneau ; les cases restent nettes.",
      get = function() return LayoutM() and LayoutM().Scale() or 100 end,
      set = function(v) if LayoutM() then LayoutM().SetScale(v) end end },
    { type = "slider", key = "opacity", label = "Transparence au repos", default = 60, min = 0, max = 100, step = 5, unit = "pct", cmd = "/drop opacite <0-100>",
      help = "Visibilité du panneau quand rien ne se passe.",
      get = function() return PanelM() and PanelM().Opacity() or 60 end,
      set = function(v) if PanelM() then PanelM().SetOpacity(v) if PanelM().ApplyOpacity then PanelM().ApplyOpacity() end end end },
    { type = "radio", key = "colorMode", label = "Couleur des chiffres", default = "palier",
      choices = { { "palier", "Selon le palier" }, { "vert", "Vert" }, { "jaune", "Jaune" } }, cmd = "/drop couleurs palier|vert|jaune",
      help = "Selon le palier : rouge, puis jaune, puis vert près du maximum." },
    { type = "check", key = "showTotal", label = "Barre Niveau total", default = false, cmd = "/drop total on|off",
      help = "Ajoute une barre fine « total / 2460 » sous les cases.",
      get = function() return (ns.db and ns.db.ui and ns.db.ui.showTotal) == true end,
      set = function(v) if ns.Wide then ns.Wide.SetShown(v and true or false) else DBui().showTotal = v and true or nil end end },
    { type = "check", key = "locked", label = "Verrouiller", default = false, cmd = "/drop verrou on|off",
      help = "Empêche de déplacer le panneau et le bouton par erreur.",
      get = function() return DBui().locked and true or false end,
      set = function(v) DBui().locked = v and true or nil if LayoutM() and LayoutM().PlaceGrip then pcall(LayoutM().PlaceGrip) end end },
  } },
  { id = "prof", title = "Métiers & surlignage", desc = "Les cases qui s'allument en vert, et les liens entre métiers.", items = {
    { type = "check", key = "gatherAlerts", label = "Surligner selon la cible", default = true, cmd = "/drop alertes on|off",
      help = "Vert sur les cases que ta cible peut faire monter.",
      get = function() return not (DBui().gatherAlerts == false) end,
      set = function(v)
        if v then DBui().gatherAlerts = nil else DBui().gatherAlerts = false end   -- 3.3.13 : « (not v) and false or nil » valait toujours nil
        if ns.Gather then if v then pcall(ns.Gather.Rescan) else pcall(ns.Gather.HideAll) end end
        if ns.Target and ns.Target.Refresh then pcall(ns.Target.Refresh, "option") end
      end },
    { type = "check", key = "activity", label = "Surligner le métier en cours", default = true, cmd = "/drop activite on|off",
      help = "Vert en pêchant / fabriquant ; liens discrets quand une fenêtre de métier est ouverte.",
      get = function() return not (DBui().activity == false) end,
      set = function(v)
        if v then DBui().activity = nil else DBui().activity = false end
        if ns.Target and ns.Target.Paint then pcall(ns.Target.Paint) end
      end },
    { type = "check", key = "craftNotify", label = "Pastille « N prêts »", default = true, cmd = "/drop recettes on|off",
      help = "Nombre de recettes que tes sacs permettent de faire pour un +1." },
    { type = "check", key = "links", label = "Liens entre métiers", default = true, cmd = "/drop liens on|off",
      help = "« Utilisé par » dans l'infobulle des objets et des créatures." },
    { type = "check", key = "unlearned", label = "Recettes à apprendre", default = true, cmd = "/drop nonapprises on|off",
      help = "Montre aussi les recettes pas encore apprises (rang requis)." },
    { type = "check", key = "scannerIcons", label = "Icônes sur les créatures", default = true, cmd = "/drop scanner icones on|off",
      help = "Petite icône de métier au-dessus du nom : vert = +1 possible." },
    { type = "check", key = "tipCompact", label = "Infobulle courte", default = true, cmd = "/drop infobulle compacte|detail",
      help = "Une ligne par métier ; maintiens Maj pour le détail.",
      set = function(v) ns.SetOpt("tipCompact", v and true or false) if ns.Tip then ns.Tip.Sync() end end },
    { type = "check", key = "styleMetiers", label = "Habiller la fenêtre Métiers", default = true, cmd = "/drop style on|off",
      help = "Barres et encadrés au style de Dropamine dans la fenêtre du jeu." },
    { type = "check", key = "openProf", label = "Clic : ouvrir le métier", default = true, cmd = "/drop ouvrir on|off",
      help = "Clic gauche sur une case de métier ouvre sa fenêtre, hors combat.",
      get = function() return not (DBui().openProf == false) end,
      set = function(v) if v then DBui().openProf = nil else DBui().openProf = false end end },
  } },
  { id = "pvp", title = "JcJ", desc = "Honneur, victoires honorables et repères sur les ennemis.", items = {
    { type = "check", key = "pvp", label = "Case JcJ", default = true, cmd = "/drop pvp on|off",
      help = "Rang, honneur et série de victoires dans la grille.",
      get = function() return not (ns.db and ns.db.ui and ns.db.ui.pvp == false) end,
      set = function(v) if ns.PvP then ns.PvP.SetEnabled(v and true or false) else if v then DBui().pvp = nil else DBui().pvp = false end end end },
    { type = "check", key = "pvpMarks", label = "Repères sur les ennemis", default = true, cmd = "/drop pvp marques on|off",
      help = "Vert : rapporte de l'honneur ; gris : ne rapporte rien." },
  } },
  { id = "notif", title = "Notifications", desc = "Les petits messages quand tu gagnes quelque chose.", items = {
    { type = "check", key = "dropsEnabled", label = "Afficher les notifications", default = true, cmd = "/drop drops on|off",
      help = "Interrupteur général des toasts de gain." },
    { type = "radio", key = "notifMode", label = "Position", default = "dessus", cmd = "/drop notif dessus|dessous|detache",
      choices = { { "dessus", "Au-dessus du panneau" }, { "dessous", "En dessous du panneau" }, { "detache", "Libre (déplaçable)" } },
      help = "Où apparaissent les toasts.",
      get = function() return ns.Notif and ns.Notif.Mode() or "dessus" end,
      set = function(v) if ns.Notif then ns.Notif.Set(v) end end },
    { type = "radio", key = "dropStyle", label = "Format", default = "complet",
      choices = { { "complet", "Complet" }, { "leger", "Une ligne" } }, cmd = "/drop drops style complet|leger",
      help = "Toast complet ou une seule ligne discrète." },
    { type = "check", key = "xpDrops", label = "Gains d'XP", default = true, cmd = "/drop drops xp on|off", help = "Toast à chaque gain d'expérience." },
    { type = "check", key = "skillDrops", label = "Gains de compétence", default = true, cmd = "/drop drops comp on|off", help = "Toast à chaque +1 de compétence." },
    { type = "check", key = "flyAnim", label = "Animation vers la case", default = true, cmd = "/drop animation on|off",
      help = "Un éclat vole du toast jusqu'à la case, puis « +N »." },
    { type = "check", key = "paliers", label = "Palier atteint", default = true, cmd = "/drop paliers on|off", help = "Prévient quand il faut aller voir ton maître." },
    { type = "check", key = "objectifs", label = "Objectif atteint", default = true, cmd = "/drop objectif on|off", help = "Prévient quand un objectif (clic droit sur une case) est atteint." },
    { type = "check", key = "levelUpAnim", label = "Animation de niveau", default = true, cmd = "/drop anim on|off", help = "Grande animation à chaque niveau." },
    { type = "check", key = "levelUpSound", label = "Son de niveau", default = false, cmd = "/drop anim son on|off", help = "Joue un son avec l'animation de niveau." },
    { type = "slider", key = "dropDuration", label = "Durée d'affichage", default = 2.6, min = 1, max = 10, step = 0.5, cmd = "/drop drops duree <1-10>", unit = "s",
      help = "Temps pendant lequel un toast reste visible." },
  } },
  { id = "advanced", title = "Avancé", extra = true, desc = "Réglages fins et rappels secondaires. Les valeurs par défaut conviennent à tous.", items = {
    { type = "slider", key = "bgAlpha", label = "Fond au survol", default = 45, min = 0, max = 100, step = 5, unit = "pct", cmd = "/drop fond <0-100>",
      help = "Opacité du fond quand le panneau est actif.",
      get = function() return PanelM() and PanelM().BgAlpha() or 45 end,
      set = function(v) if PanelM() then PanelM().SetBgAlpha(v) end end },
    { type = "slider", key = "fadeDelay", label = "Délai avant repos", default = 3, min = 0, max = 60, step = 1, unit = "s", cmd = "/drop fondu <0-60>",
      help = "Secondes avant que le panneau redevienne discret.",
      get = function() return PanelM() and PanelM().FadeDelay() or 3 end,
      set = function(v) if PanelM() then PanelM().SetFadeDelay(v) end end },
    { type = "slider", key = "dropBgAlpha", label = "Fond des toasts", default = 0.68, min = 0, max = 1, step = 0.05, cmd = "/drop drops opacite <0-100>", unit = "%",
      help = "Opacité du fond des toasts (Classique / repli)." },
    { type = "check", key = "scanner", label = "Apprendre le butin", default = true, cmd = "/drop scanner on|off",
      help = "Mémorise ce que lâchent les créatures (à laisser activé)." },
    { type = "check", key = "scannerToast", label = "Toast « recette possible »", default = false, cmd = "/drop scanner toast on|off",
      help = "Toast quand une créature proche donne un ingrédient utile." },
    { type = "check", key = "scannerSound", label = "Son du toast recette", default = false, cmd = "/drop scanner son on|off",
      help = "Petit son avec le toast « recette possible »." },
    { type = "check", key = "session", label = "Gains du jour", default = true, cmd = "/drop session on|off", help = "« +N aujourd'hui » dans l'infobulle des cases." },
    { type = "check", key = "rappel", label = "Rappel arme en retard", default = true, cmd = "/drop rappel on|off", help = "Signale discrètement une arme en main sous-montée." },
  } },
}
-- Lignes ajoutées par d'autres modules (QoL) : rangées dans le bon groupe,
-- libellés courts, une phrase d'aide chacune.
Options.EXTRA = Options.EXTRA or {}
Options.EXTRA_HOME = { eta = "advanced", prepalier = "notif", historique = "advanced", alts = "advanced", partage = "advanced", defense = "advanced",
  maitreArmes = "advanced", armePrincipale = "advanced", jalons = "notif", recapLogout = "notif", peche = "prof", courses = "prof" }
Options.EXTRA_LABEL = { historique = "Historique 7 jours", alts = "Autres personnages", eta = "Temps estimé jusqu'au rang",
  partage = "Maj+clic : partager dans le chat", defense = "Rappel Défense (ennemis gris)", jalons = "Jalons personnels",
  recapLogout = "Récap à la déconnexion", peche = "Prises de pêche par zone", courses = "Liste de courses (objectifs)",
  prepalier = "Rappel avant le palier", maitreArmes = "Rappel maître d'armes", armePrincipale = "Rappel arme principale" }
Options.EXTRA_HELP = { historique = "Gains des 7 derniers jours dans l'infobulle des cases.", alts = "Compare tes rangs avec tes autres personnages.",
  eta = "« 125 dans ~40 min » d'après ton rythme mesuré.", partage = "Maj+clic sur une case : « Dépeçage 161/225 » dans le chat.",
  defense = "Rappelle que la Défense ne monte pas sur les ennemis gris.", jalons = "Fête tes caps : premier 150, total 1000…",
  recapLogout = "Résumé de la session au moment de te déconnecter.", peche = "Retient ce que tu pêches dans chaque zone.",
  courses = "Composants à réunir pour tes objectifs de métier.", prepalier = "Prévient 5 points avant le maximum du palier.",
  maitreArmes = "Signale une arme équipée que tu n'as pas apprise.", armePrincipale = "Rappelle de remettre ton arme principale (hors combat)." }

function Options.SectionItems(sec)
  local out = {}
  for _, it in ipairs(sec.items) do out[#out + 1] = it end
  for _, it in ipairs(Options.EXTRA) do
    if it.key and (Options.EXTRA_HOME[it.key] or "advanced") == sec.id then
      if Options.EXTRA_LABEL[it.key] then it.label = Options.EXTRA_LABEL[it.key] end
      if Options.EXTRA_HELP[it.key] then it.help = Options.EXTRA_HELP[it.key] end
      out[#out + 1] = it
    end
  end
  -- cases groupées après les menus / curseurs ? non : ordre du registre, mais
  -- les cases se rangent par paires (2 colonnes) entre deux curseurs.
  return out
end

-- Liste à plat, dans l'ordre d'affichage (Find / Get / debug).
function Options.All()
  local out = {}
  for _, sec in ipairs(Options.SECTIONS) do
    for _, it in ipairs(Options.SectionItems(sec)) do out[#out + 1] = it end
  end
  return out
end
Options.ITEMS = Options.All()

function Options.Find(key)
  for _, it in ipairs(Options.All()) do if it.key == key then return it end end
end

function Options.Get(key)
  local it = Options.Find(key)
  if it and it.get then local ok, v = pcall(it.get) if ok and v ~= nil then return v end return it.default end
  local ui = ns.EnsureDB().ui
  if key == "colorMode" then return ns.GetColorMode and ns.GetColorMode() or ui.colorMode or "palier" end
  local v = ui[key]
  if v == nil and it then return it.default end
  return v
end

-- Applique un réglage (même effet que la commande /drop correspondante).
function Options.Set(key, value)
  local it = Options.Find(key)
  if it and it.type == "slider" then
    value = ns.N(value) or it.default
    if value < it.min then value = it.min end
    if value > it.max then value = it.max end
  end
  if it and it.set then
    pcall(it.set, value)
    if Options.panel and Options.panel:IsShown() and not Options._syncing then Options.Sync() end
    return Options.Get(key)
  end
  if key == "colorMode" then
    if ns.SetColorMode then ns.SetColorMode(value) else ns.EnsureDB().ui.colorMode = value end
    if ns.OnOptionChanged then pcall(ns.OnOptionChanged, key, value) end
  else
    ns.SetOpt(key, value)
  end
  return value
end

function ns.OnOptionChanged(key, value)
  local UI = ns.UI
  if key == "dropsEnabled" and UI and UI.ApplyDropsEnabled then pcall(UI.ApplyDropsEnabled, UI) end
  if (key == "dropDir" or key == "dropStyle") and UI and UI.ApplyDropsLayout then pcall(UI.ApplyDropsLayout, UI) end
  if key == "dropsSnapChat" and UI and UI.SetDropsSnapChat and not Options._snapping then
    Options._snapping = true
    pcall(UI.SetDropsSnapChat, UI, value and true or false)
    Options._snapping = false
  end
  if (key == "scanner" or key == "scannerIcons") and ns.Scanner then
    if value then pcall(ns.Scanner.RescanPlates) else ns.Scanner.HideAll() end
  end
  if UI and UI.Refresh and (key == "showStats" or key == "session" or key == "rappel" or key == "paliers"
      or key == "styleMetiers" or key == "colorMode" or key == "barLabel" or (Options.Find(key) and Options.Find(key).refresh)) then
    pcall(UI.Refresh, UI, true)
  end
  if Options.panel and Options.panel:IsShown() then Options.Sync() end
end

-- /drop drops xp|comp|style|duree|opacite ----------------------------------------
function ns.DropsSubcommand(full)
  local sub, arg = (full or ""):lower():match("^(%S*)%s*(%S*)")
  if sub == "xp" then
    local v = Options.Set("xpDrops", ns.ParseOnOff(arg, Options.Get("xpDrops")))
    ns.Print("drops d'XP " .. (v and "activés." or "désactivés."))
    return true
  elseif sub == "comp" or sub == "competences" or sub == "compétences" then
    local v = Options.Set("skillDrops", ns.ParseOnOff(arg, Options.Get("skillDrops")))
    ns.Print("drops de compétence " .. (v and "activés." or "désactivés."))
    return true
  elseif sub == "style" then
    if arg == "leger" or arg == "léger" then Options.Set("dropStyle", "leger")
    elseif arg == "complet" then Options.Set("dropStyle", "complet")
    else ns.Print("style actuel : " .. tostring(Options.Get("dropStyle")) .. ". Usage : /drop drops style complet|leger") return true end
    ns.Print("style des drops : " .. Options.Get("dropStyle") .. ".")
    return true
  elseif sub == "chat" or sub == "coller" then
    local v = Options.Set("dropsSnapChat", ns.ParseOnOff(arg, Options.Get("dropsSnapChat")))
    ns.Print(v and "drops collés au-dessus du chat (même largeur)." or "drops détachés du chat.")
    return true
  elseif sub == "sens" or sub == "direction" then
    if arg == "haut" then Options.Set("dropDir", "haut")
    elseif arg == "bas" then Options.Set("dropDir", "bas")
    else ns.Print("sens actuel : vers le " .. tostring(Options.Get("dropDir")) .. ". Usage : /drop drops sens haut|bas") return true end
    ns.Print("drops empilés vers le " .. Options.Get("dropDir") .. ".")
    return true
  elseif sub == "duree" or sub == "durée" then
    if not ns.N(arg) then ns.Print("durée actuelle : " .. tostring(Options.Get("dropDuration")) .. " s. Usage : /drop drops duree <1-10>") return true end
    local v = Options.Set("dropDuration", ns.N(arg))
    ns.Print("durée des drops : " .. tostring(v) .. " s.")
    return true
  elseif sub == "opacite" or sub == "opacité" then
    if not ns.N(arg) then ns.Print("opacité actuelle : " .. tostring(math.floor((Options.Get("dropBgAlpha") or 0) * 100 + 0.5)) .. " %. Usage : /drop drops opacite <0-100>") return true end
    local a = ns.N(arg)
    if a > 1 then a = a / 100 end
    local v = Options.Set("dropBgAlpha", a)
    ns.Print("opacité du fond des drops : " .. tostring(math.floor(v * 100 + 0.5)) .. " %.")
    return true
  end
  return false
end

ns.SlashExt.style = function(rest)
  local v = Options.Set("styleMetiers", ns.ParseOnOff(rest, Options.Get("styleMetiers")))
  ns.Print("style Métiers " .. (v and "activé." or "désactivé (style précédent)."))
end

-- Panneau ------------------------------------------------------------------------
local function TryCreate(kind, name, parent, templates)
  for _, t in ipairs(templates or {}) do
    local ok, f = pcall(CreateFrame, kind, name, parent, t)
    if ok and f then f._template = t return f end
  end
  local ok, f = pcall(CreateFrame, kind, name, parent)
  return ok and f or nil
end

local function FS(...)
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    if type(v) == "table" and v.SetText then return v end
  end
  return nil
end

local function Label(parent, text, font)
  local fs = parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlight")
  fs:SetText(text)
  if fs.SetJustifyH then fs:SetJustifyH("LEFT") end
  return fs
end

Options.widgets = {}
-- v2.8.1 : panneau d'options aux couleurs de base, façon Questie : fond natif
-- du panneau Options visible (aucun fond à nous), titre de groupe jaune
-- GameFontNormal AU-DESSUS de chaque encadré, encadré = bord d'info-bulle natif
-- teinté or sur un voile sombre transparent, cases natives avec libellé jaune
-- à droite et description blanche dessous, 2 colonnes alignées, choix en menu
-- déroulant natif (UIDropDownMenu), curseurs natifs (OptionsSliderTemplate).
Options.CONTENT_W, Options.COL_W, Options.COL2_X = 600, 280, 300
Options.LAYOUT = {
  MARGIN = 8,          -- marge du contenu
  PAD = 12,            -- marge intérieure d'un encadré
  TITLE_H = 18,        -- titre de groupe (au-dessus de l'encadré)
  ROW = 26,            -- case à cocher
  DESC_H = 14,         -- une ligne de description blanche
  DROP_H = 50,         -- libellé + menu déroulant
  SLIDER_H = 58,       -- libellé + curseur + bornes min/max (sans chevauchement)
  SECTION_GAP = 12,    -- entre deux groupes
  CHECK_TEXT_X = 26,   -- texte à droite de la case
}
Options.BOX_EDGE = "Interface\\Tooltips\\UI-Tooltip-Border"
Options.BOX_GOLD = { 1.00, 0.82, 0.00, 0.80 }
Options.BOX_FILL = { 0, 0, 0, 0.25 }

function Options.FormatValue(it, v)
  v = ns.N(v) or 0
  if it.unit == "%" then return tostring(math.floor(v * 100 + 0.5)) .. " %" end
  if it.unit == "pct" then return tostring(math.floor(v + 0.5)) .. " %" end
  if it.unit == "s" then return tostring(v) .. " s" end
  return tostring(v)
end
Options.WHEEL_STEP = 40

-- Molette : défile le contenu, borné à la plage du ScrollFrame.
function Options.Scroll(delta)
  local sc = Options.scroll
  if not sc or not sc.SetVerticalScroll then return end
  local cur = (sc.GetVerticalScroll and sc:GetVerticalScroll()) or 0
  local max = (sc.GetVerticalScrollRange and sc:GetVerticalScrollRange()) or 0
  local v = cur - (delta or 0) * Options.WHEEL_STEP
  if v < 0 then v = 0 end
  if v > max then v = max end
  sc:SetVerticalScroll(v)
  return v
end

local function BoxChrome(box)
  local bd = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = Options.BOX_EDGE, edgeSize = 16, tile = true, tileSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 } }
  if box.SetBackdrop then
    local ok = pcall(box.SetBackdrop, box, bd)
    if ok then
      local f, g = Options.BOX_FILL, Options.BOX_GOLD
      if box.SetBackdropColor then pcall(box.SetBackdropColor, box, f[1], f[2], f[3], f[4]) end
      if box.SetBackdropBorderColor then pcall(box.SetBackdropBorderColor, box, g[1], g[2], g[3], g[4]) end
      box._chrome = "backdrop " .. Options.BOX_EDGE
      return box._chrome
    end
  end
  box._chrome = "aucun (pas de SetBackdrop)"
  return box._chrome
end

-- Rectangles posés (x, y vers le bas, largeur, hauteur) : vérifiés par les tests.
local function Rect(owner, x, y, w, h, what)
  owner._rects = owner._rects or {}
  owner._rects[#owner._rects + 1] = { x = x, y = y, w = w, h = h, what = what }
end

local function MakeDropdown(box, it, x, y)
  local name = "DropamineOpt_" .. it.key
  local dd = TryCreate("Frame", name, box, { "UIDropDownMenuTemplate" })
  dd:SetPoint("TOPLEFT", box, "TOPLEFT", x - 16, -y)   -- le modèle a 16 px de marge gauche
  local W = Options.COL_W - 40
  if type(_G.UIDropDownMenu_SetWidth) == "function" then pcall(_G.UIDropDownMenu_SetWidth, dd, W) end
  dd.choices = it.choices
  dd.key = it.key
  local function label(v)
    for _, ch in ipairs(it.choices) do if ch[1] == v then return ch[2] end end
    return tostring(v)
  end
  dd.Refresh = function(self)
    local v = Options.Get(it.key)
    if type(_G.UIDropDownMenu_SetText) == "function" then pcall(_G.UIDropDownMenu_SetText, self, label(v)) end
    self.selected = v
  end
  local function init(self, level)
    if ns.InCombat and ns.InCombat() then return end
    if type(_G.UIDropDownMenu_CreateInfo) ~= "function" then return end
    for _, ch in ipairs(it.choices) do
      local info = _G.UIDropDownMenu_CreateInfo()
      info.text, info.value = ch[2], ch[1]
      info.checked = (Options.Get(it.key) == ch[1])
      info.func = function()
        Options.Set(it.key, ch[1])
        dd:Refresh()
      end
      _G.UIDropDownMenu_AddButton(info, level)
    end
  end
  -- Pas d'UIDropDownMenu_Initialize au chargement (limite la souillure des
  -- globales du menu) : le bouton du modèle lit dd.initialize à l'ouverture.
  dd.initialize = init
  dd.Choose = function(self, v) Options.Set(it.key, v) self:Refresh() end
  dd.x, dd.y, dd.w = x, y, W + 32
  return dd
end

function Options.Build()
  if Options.panel then return Options.panel end
  local panel = CreateFrame("Frame", "DropamineOptionsPanel", UIParent)
  panel.name = "Dropamine"
  panel:Hide()
  local title = Label(panel, "Dropamine", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
  local subt = Label(panel, "Chaque réglage correspond à une commande /drop (survole-le pour la voir).", "GameFontHighlightSmall")
  subt:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  -- 3.3.8 : « Valeurs par défaut » (deux clics : le 1er demande confirmation)
  local rb = TryCreate("Button", "DropamineOptionsReset", panel, { "UIPanelButtonTemplate" })
  rb:SetSize(150, 22)
  rb:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -36, -16)
  rb:SetText(Options.RESET_TEXT)
  rb:SetScript("OnClick", function(self) Options.ResetClick(self) end)
  rb:SetScript("OnEnter", function(self)
    if GameTooltip then GameTooltip:SetOwner(self, "ANCHOR_LEFT") GameTooltip:AddLine("Remet tous les réglages de ce panneau à leur valeur d'origine", 1, 1, 1, true) GameTooltip:AddLine("/drop options defaut", 0.7, 0.7, 0.7) GameTooltip:Show() end
  end)
  rb:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  panel.reset, Options.resetButton = rb, rb
  local scroll = TryCreate("ScrollFrame", "DropamineOptionsScroll", panel, { "UIPanelScrollFrameTemplate" })
  scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -52)
  scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 8)
  if scroll.SetClipsChildren then pcall(scroll.SetClipsChildren, scroll, true) end
  local content = CreateFrame("Frame", "DropamineOptionsContent", scroll)
  content:SetSize(Options.CONTENT_W, 400)
  if scroll.SetScrollChild then scroll:SetScrollChild(content) end
  if scroll.EnableMouseWheel then scroll:EnableMouseWheel(true) end
  scroll:SetScript("OnMouseWheel", function(self, delta) Options.Scroll(delta) end)
  panel.scroll, panel.content = scroll, content
  Options.scroll, Options.content = scroll, content
  Options.boxes = {}
  local L = Options.LAYOUT
  local boxW = Options.CONTENT_W - 2 * L.MARGIN
  local y = 0
  for _, sec in ipairs(Options.SECTIONS) do
    local items = Options.SectionItems(sec)
    if #items > 0 then
      -- Titre jaune au-dessus du groupe.
      local h = Label(content, sec.title, "GameFontNormal")
      h:SetPoint("TOPLEFT", content, "TOPLEFT", L.MARGIN + 4, -y)
      y = y + L.TITLE_H
      local box = TryCreate("Frame", nil, content, { "BackdropTemplate" })
      box:SetPoint("TOPLEFT", content, "TOPLEFT", L.MARGIN, -y)
      box:SetWidth(boxW)
      BoxChrome(box)
      box.header = h
      local by = L.PAD
      if sec.desc then   -- 3.3.8 : une phrase qui dit à quoi sert le groupe
        local d = Label(box, sec.desc, "GameFontHighlightSmall")
        d.font = "GameFontHighlightSmall"
        d:SetPoint("TOPLEFT", box, "TOPLEFT", L.PAD + 4, -by)
        if d.SetWidth then d:SetWidth(boxW - 2 * L.PAD - 8) end
        Rect(box, L.PAD, by, boxW - 2 * L.PAD, L.DESC_H, sec.id .. ":intro")
        box.descFS = d
        by = by + L.DESC_H + 8
      end
      -- 2 colonnes : chaque cellule a sa hauteur ; la rangée prend la plus haute.
      local col, rowH, used = 0, 0, false
      local function endRow()
        if used then by = by + rowH end
        col, rowH, used = 0, 0, false
      end
      local function cell(width2, hgt)
        if width2 then endRow() end
        local x = (col == 0) and L.PAD or Options.COL2_X
        return x
      end
      local function advance(hgt, full)
        used = true
        if hgt > rowH then rowH = hgt end
        if full or col == 1 then endRow() else col = 1 end
      end
      for _, it in ipairs(items) do
        if it.type == "check" then
          if it.row and col == 1 then endRow() end
          local cx = cell(false)
          local cb = TryCreate("CheckButton", "DropamineOpt_" .. it.key, box, { "InterfaceOptionsCheckButtonTemplate", "UICheckButtonTemplate" })
          cb:SetSize(26, 26)
          cb:SetPoint("TOPLEFT", box, "TOPLEFT", cx, -by)
          local txt = FS(cb.Text, cb.text, _G[(cb.GetName and cb:GetName() or "") .. "Text"])
          if not txt then txt = Label(cb, "") end
          txt:ClearAllPoints()
          txt:SetPoint("LEFT", cb, "RIGHT", 2, 1)
          txt:SetText(it.label)
          if txt.SetFontObject and _G.GameFontNormal then pcall(txt.SetFontObject, txt, _G.GameFontNormal) end
          txt.font = "GameFontNormal"
          if txt.SetWidth then txt:SetWidth(Options.COL_W - L.CHECK_TEXT_X - 4) end
          if txt.SetWordWrap then pcall(txt.SetWordWrap, txt, false) end
          cb.labelFS = txt
          cb.tooltipText = it.cmd
          cb.col, cb.x, cb.y, cb.section = col, cx, by, sec.id
          local hgt = L.ROW
          Rect(box, cx, by, Options.COL_W, it.help and (L.ROW - 4) or L.ROW, it.key)
          if it.help then
            local hf = Label(box, it.help, "GameFontHighlightSmall")
            hf.font = "GameFontHighlightSmall"
            hf:SetPoint("TOPLEFT", box, "TOPLEFT", cx + L.CHECK_TEXT_X, -(by + L.ROW - 4))
            if hf.SetWidth then hf:SetWidth(Options.COL_W - L.CHECK_TEXT_X - 4) end
            local lines = math.max(1, math.ceil(#it.help / 46))
            hgt = L.ROW - 4 + lines * L.DESC_H + 4
            Rect(box, cx + L.CHECK_TEXT_X, by + L.ROW - 4, Options.COL_W - L.CHECK_TEXT_X, lines * L.DESC_H, it.key .. ":desc")
            cb.helpFS = hf
          end
          cb:SetScript("OnClick", function(self)
            local on = self:GetChecked() and true or false
            Options.Set(it.key, on)
          end)
          cb:SetScript("OnEnter", function(self)
            if GameTooltip then GameTooltip:SetOwner(self, "ANCHOR_RIGHT") GameTooltip:AddLine(it.label, 1, 0.82, 0) GameTooltip:AddLine(it.cmd, 1, 1, 1) GameTooltip:Show() end
          end)
          cb:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
          Options.widgets[it.key] = cb
          advance(hgt, it.row)
        elseif it.type == "radio" then
          local cx = cell(false)
          local l = Label(box, it.label, "GameFontNormal")
          l.font = "GameFontNormal"
          l:SetPoint("TOPLEFT", box, "TOPLEFT", cx + 4, -by)
          local dd = MakeDropdown(box, it, cx, by + 16)
          dd.labelFS, dd.col = l, col
          Rect(box, cx, by, Options.COL_W, L.DROP_H, it.key)
          Options.widgets[it.key] = dd
          advance(L.DROP_H)
        elseif it.type == "slider" then
          endRow()
          local sname = "DropamineOpt_" .. it.key
          local l = Label(box, it.label, "GameFontNormal")
          l.font = "GameFontNormal"
          l:SetPoint("TOPLEFT", box, "TOPLEFT", L.PAD + 4, -by)
          local sl = TryCreate("Slider", sname, box, { "OptionsSliderTemplate", "UISliderTemplateWithLabels", "UISliderTemplate" })
          local sw = boxW - 2 * L.PAD - 24
          sl:SetPoint("TOPLEFT", box, "TOPLEFT", L.PAD + 12, -(by + 20))
          sl:SetWidth(sw)
          if sl.SetHeight then sl:SetHeight(17) end
          if sl.SetOrientation then sl:SetOrientation("HORIZONTAL") end
          sl:SetMinMaxValues(it.min, it.max)
          if sl.SetValueStep then sl:SetValueStep(it.step) end
          if sl.SetObeyStepOnDrag then pcall(sl.SetObeyStepOnDrag, sl, true) end
          local low = FS(_G[sname .. "Low"], sl.Low) local high = FS(_G[sname .. "High"], sl.High) local tt = FS(_G[sname .. "Text"], sl.Text)
          if not low then low = Label(box, "", "GameFontHighlightSmall") end
          if not high then high = Label(box, "", "GameFontHighlightSmall") end
          -- Bornes sous les extrémités, alignées gauche / droite : jamais l'une sur l'autre.
          if low and low.SetText then
            low:SetText(Options.FormatValue(it, it.min))
            if low.ClearAllPoints then low:ClearAllPoints() low:SetPoint("TOPLEFT", sl, "BOTTOMLEFT", 0, -2) end
            if low.SetJustifyH then low:SetJustifyH("LEFT") end
          end
          if high and high.SetText then
            high:SetText(Options.FormatValue(it, it.max))
            if high.ClearAllPoints then high:ClearAllPoints() high:SetPoint("TOPRIGHT", sl, "BOTTOMRIGHT", 0, -2) end
            if high.SetJustifyH then high:SetJustifyH("RIGHT") end
          end
          if tt and tt.SetText then tt:SetText("") end
          sl.lowFS, sl.highFS = low, high
          sl.valueFS = Label(box, "", "GameFontHighlight")
          sl.valueFS:SetPoint("TOPRIGHT", box, "TOPRIGHT", -(L.PAD + 12), -by)
          if sl.valueFS.SetJustifyH then sl.valueFS:SetJustifyH("RIGHT") end
          sl.labelFS, sl.y = l, by
          Rect(box, L.PAD, by, boxW - 2 * L.PAD, L.SLIDER_H, it.key)
          sl:SetScript("OnValueChanged", function(self, v)
            if Options._syncing then return end
            v = Options.Set(it.key, math.floor(v / it.step + 0.5) * it.step)
            self.valueFS:SetText(Options.FormatValue(it, v))
          end)
          Options.widgets[it.key] = sl
          by = by + L.SLIDER_H
          if it.help then
            local hf = Label(box, it.help, "GameFontHighlightSmall")
            hf:SetPoint("TOPLEFT", box, "TOPLEFT", L.PAD + 4, -by)
            Rect(box, L.PAD, by, boxW - 2 * L.PAD, L.DESC_H, it.key .. ":desc")
            sl.helpFS = hf
            by = by + L.DESC_H + 4
          end
        end
      end
      endRow()
      by = by + L.PAD
      box:SetHeight(by)
      box.section = sec.id
      Options.boxes[#Options.boxes + 1] = box
      y = y + by + L.SECTION_GAP
    end
  end
  content:SetHeight(y + L.MARGIN)
  panel:SetScript("OnShow", function() Options.Sync() end)
  Options.panel = panel
  Options.height = y + 52
  return panel
end

-- Valeurs par défaut ----------------------------------------------------------------
Options.RESET_TEXT, Options.RESET_CONFIRM = "Valeurs par défaut", "Confirmer ?"
function Options.ResetDefaults()
  local n = 0
  Options._syncing = true
  for _, it in ipairs(Options.All()) do
    if it.key and it.default ~= nil then
      local ok = pcall(Options.Set, it.key, it.default)
      if ok then n = n + 1 end
    end
  end
  Options._syncing = false
  if Options.panel then Options.Sync() end
  return n
end
function Options.ResetClick(btn)
  if not Options._armed then
    Options._armed = true
    if btn and btn.SetText then btn:SetText(Options.RESET_CONFIRM) end
    if _G.C_Timer and _G.C_Timer.After then
      _G.C_Timer.After(4, function() Options._armed = nil if btn and btn.SetText then btn:SetText(Options.RESET_TEXT) end end)
    end
    return false
  end
  Options._armed = nil
  if btn and btn.SetText then btn:SetText(Options.RESET_TEXT) end
  local n = Options.ResetDefaults()
  ns.Print("options : " .. n .. " réglages remis par défaut.")
  return n
end

function Options.Sync()
  Options._syncing = true
  for key, w in pairs(Options.widgets) do
    local v = Options.Get(key)
    local it = Options.Find(key)
    local kind = it and it.type
    if kind == "check" then
      w:SetChecked(v and true or false)
    elseif kind == "slider" then
      w:SetValue(v)
      if w.valueFS then w.valueFS:SetText(Options.FormatValue(it, v)) end
    elseif kind == "radio" and w.Refresh then
      pcall(w.Refresh, w)
    end
  end
  Options._syncing = false
end

-- Enregistrement dans les Options natives (catégorie AddOns).
function Options.Register()
  if Options.registered then return Options.registered end
  local panel = Options.Build()
  local S = _G.Settings
  if type(S) == "table" and type(S.RegisterCanvasLayoutCategory) == "function" then
    local ok, cat = pcall(S.RegisterCanvasLayoutCategory, panel, panel.name)
    if ok and cat then
      if type(S.RegisterAddOnCategory) == "function" then pcall(S.RegisterAddOnCategory, cat) end
      Options.category = cat
      Options.registered = "Settings.RegisterCanvasLayoutCategory"
      return Options.registered
    end
  end
  if type(_G.InterfaceOptions_AddCategory) == "function" then
    if pcall(_G.InterfaceOptions_AddCategory, panel) then
      Options.registered = "InterfaceOptions_AddCategory"
      return Options.registered
    end
  end
  Options.registered = "fenêtre autonome"
  return Options.registered
end

function Options.Open()
  Options.Register()
  local S = _G.Settings
  if Options.category and type(S) == "table" and type(S.OpenToCategory) == "function" then
    local id = (Options.category.GetID and Options.category:GetID()) or Options.category.ID or Options.category
    if pcall(S.OpenToCategory, id) then Options.opened = "Settings" return "Settings" end
  end
  if type(_G.InterfaceOptionsFrame_OpenToCategory) == "function" then
    pcall(_G.InterfaceOptionsFrame_OpenToCategory, Options.panel)
    pcall(_G.InterfaceOptionsFrame_OpenToCategory, Options.panel)
    Options.opened = "InterfaceOptions"
    return "InterfaceOptions"
  end
  -- Repli : panneau seul, au centre, cadre natif.
  local p = Options.panel
  if not p._standalone then
    p._standalone = true
    p:SetParent(UIParent)
    p:SetSize(640, math.max(420, (Options.height or 400) + 20))
    p:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    p:SetFrameStrata("DIALOG")
    if p.SetBackdrop then
      pcall(p.SetBackdrop, p, { bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } })
    end
    local close = TryCreate("Button", nil, p, { "UIPanelCloseButton" })
    if close then close:SetPoint("TOPRIGHT", p, "TOPRIGHT", -4, -4) end
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "DropamineOptionsPanel") end
  end
  p:Show()
  Options.Sync()
  Options.opened = "autonome"
  return "autonome"
end

-- /drop anim on|off · /drop anim son on|off · /drop anim test (v2.8.0)
ns.SlashExt.anim = function(rest)
  local sub, arg = (rest or ""):lower():match("^(%S*)%s*(%S*)")
  if sub == "son" or sub == "sound" then
    local v = Options.Set("levelUpSound", ns.ParseOnOff(arg, ns.OptOff("levelUpSound")))
    local kit, name = ns.UI and ns.UI.LevelUpSoundKit and ns.UI:LevelUpSoundKit()
    ns.Print("animation : son " .. (v and "activé" or "désactivé") .. (kit and (" (" .. tostring(name) .. ")") or " (aucun son natif trouvé : rien ne sera joué)") .. ".")
  elseif sub == "test" then
    if ns.UI and ns.UI.PlayLevelUp then ns.UI:PlayLevelUp(ns.GetPlayerLevel()) end
  else
    local v = Options.Set("levelUpAnim", ns.ParseOnOff(sub, ns.Opt("levelUpAnim")))
    ns.Print("animation de montée de niveau " .. (v and "activée." or "désactivée."))
  end
end
ns.HelpExt[#ns.HelpExt + 1] = "/drop anim on|off · son on|off · test : animation de montée de niveau"
ns.SlashExt.recettes = function(rest)
  local sub = (rest or ""):lower():match("^(%S*)")
  if sub == "" or sub == "liste" then
    local C = ns.Craft
    if not C then return end
    if not ns.Scanner.InCombat() then C.Update(true) end
    local any = false
    for _, e in ipairs(ns.CATALOG or {}) do
      if C.SKILLS[e.id] then
        local t = C.DetailText(e.id)
        local rec = ns.CharDB().recipes and ns.CharDB().recipes[e.id]
        if t and rec then any = true ns.Print(e.name .. " — " .. t:gsub("\n", " · ")) end
      end
    end
    if not any then ns.Print("recettes : aucune fenêtre de métier lue pour l'instant (lecture automatique à l'ouverture du métier).") end
    return
  end
  local v = Options.Set("craftNotify", ns.ParseOnOff(sub, ns.Opt("craftNotify")))
  ns.Print("drop « recettes réalisables » " .. (v and "activé." or "désactivé."))
end
ns.HelpExt[#ns.HelpExt + 1] = "/drop recettes [on|off] : recettes réalisables avec tes sacs (tous les métiers de fabrication)"
ns.SlashExt.options = function(rest)
  rest = (rest or ""):lower()
  if rest == "defaut" or rest == "défaut" or rest == "reset" then
    ns.Print("options : " .. Options.ResetDefaults() .. " réglages remis par défaut.")
    return
  end
  Options.Open()
end
-- 3.3.8 : commandes des nouveaux réglages (miroir exact du panneau)
local function onoff(key, label)
  return function(rest)
    local v = Options.Set(key, ns.ParseOnOff((rest or ""):match("^%s*(%S*)"), Options.Get(key)))
    ns.Print(label .. " : " .. (v and "activé." or "désactivé."))
  end
end
ns.SlashExt.animation = onoff("flyAnim", "animation toast → case")
ns.SlashExt.liens = onoff("links", "liens entre métiers")
ns.SlashExt.nonapprises = onoff("unlearned", "recettes non apprises")
ns.SlashExt.infobulle = function(rest)
  rest = (rest or ""):lower():match("^%s*(%S*)") or ""
  local v
  if rest == "compacte" or rest == "on" then v = true
  elseif rest == "detail" or rest == "détail" or rest == "off" then v = false
  else v = not Options.Get("tipCompact") end
  Options.Set("tipCompact", v)
  ns.Print("infobulle de créature : " .. (v and "compacte (Maj = détail)." or "détaillée."))
end
ns.HelpExt[#ns.HelpExt + 1] = "/drop animation on|off · /drop infobulle compacte|detail · /drop liens on|off · /drop nonapprises on|off · /drop options defaut"
ns.SlashExt.config = ns.SlashExt.options
ns.HelpExt[#ns.HelpExt + 1] = "/drop options : panneau d'options (Options > AddOns)"
ns.HelpExt[#ns.HelpExt + 1] = "/drop drops xp|comp on|off · style complet|leger · duree <1-10> · opacite <0-100>"
ns.HelpExt[#ns.HelpExt + 1] = "/drop style on|off : style de la fenêtre Métiers (barres et encadrés)"

ns.DebugExt[#ns.DebugExt + 1] = function()
  local out = { "— Options —" }
  out[#out + 1] = "  enregistrement : " .. tostring(Options.registered or "pas encore") .. " ; Settings " .. tostring(type(_G.Settings) == "table") .. ", InterfaceOptions_AddCategory " .. tostring(type(_G.InterfaceOptions_AddCategory) == "function")
  local parts = {}
  for _, it in ipairs(Options.All()) do
    if it.key then parts[#parts + 1] = it.key .. "=" .. tostring(Options.Get(it.key)) end
  end
  out[#out + 1] = "  " .. table.concat(parts, ", ")
  return out
end

if ns.On then
  ns.On("PLAYER_LOGIN", function() pcall(Options.Register) end)
end
