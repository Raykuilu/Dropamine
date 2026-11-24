-- Dropamine : panneau d'options (catégorie AddOns des Options natives).
-- Chaque réglage reflète une commande /drop et la même clé de SavedVariables.
local ADDON, ns = ...
local Tr = ns.L   -- 3.5.19 : textes traduits (Locales/)
local Options = {}
ns.Options = Options

-- 3.5.22 : réglages 2.0 — look natif Classic (façon LayerSwap) : titres d'or
-- sans encadrés, tout aligné à gauche, une famille = une section, aperçu en
-- direct, boutons Tester et Réinitialiser par section. Les clés de sauvegarde
-- et les commandes /drop ne changent pas (aucune valeur enregistrée perdue).
local function DBui() return ns.EnsureDB().ui end
local function PanelM() return ns.Panel end
local function LayoutM() return ns.Layout end

Options.SECTIONS = {
  { id = "display", title = "Affichage", desc = "Apparence, disposition, transparence et icônes d'état.", items = {
    { type = "radio", key = "theme", label = "Thème", default = "flare", cmd = "/drop theme flare|flare2|leger|classic",
      choices = { { "flare2", "FlareUI" }, { "flare", "Moderne" }, { "leger", "Léger (cases seules, sans cadre)" }, { "classic", "Classique (look Blizzard)" } },
      help = "Change l'habillage du panneau, des cases et des toasts.",
      get = function() return ns.Theme and ns.Theme.Choice() or "flare" end,
      set = function(v) if ns.Theme then ns.Theme.Set(v) end end },
    -- 3.5.19 : langue des textes (enregistrée dans DropamineDB.ui.lang, « auto » par défaut)
    { type = "radio", key = "lang", label = "Langue", default = "auto", noReset = true, cmd = "/drop lang auto|en|fr",
      choices = { { "auto", "Auto (langue du jeu)" }, { "en", "English" }, { "fr", "Français" } },
      help = "Langue des textes de l'addon. Auto : français sur un client français, anglais sinon.",
      get = function() return ns.LangSetting and ns.LangSetting() or "auto" end,
      set = function(v) if ns.SetLang then ns.SetLang(v) end end },
    { type = "radio", key = "cols", label = "Colonnes", default = 5, cmd = "/drop colonnes 2|3|5|10",
      choices = { { 2, "2 colonnes" }, { 3, "3 colonnes" }, { 5, "5 colonnes" }, { 10, "10 colonnes (1 rangée)" } },
      help = "Nombre de cases par rangée (aussi : poignée du coin, Alt+glisser).",
      get = function() return LayoutM() and LayoutM().Cols() or 5 end,
      set = function(v) if LayoutM() then LayoutM().SetCols(v) end end },
    { type = "slider", key = "scale", label = "Taille", default = 100, min = 90, max = 200, step = 1, unit = "pct", cmd = "/drop taille <90-200>",
      help = "Taille du panneau ; les cases restent nettes.",
      get = function() return LayoutM() and LayoutM().Scale() or 100 end,
      set = function(v) if LayoutM() then LayoutM().SetScale(v) end end },
    { type = "slider", key = "opacity", label = "Transparence au repos", default = 60, min = 0, max = 100, step = 5, unit = "pct", cmd = "/drop opacite <0-100>",
      help = "Visibilité du panneau quand rien ne se passe.",
      get = function() return PanelM() and PanelM().Opacity() or 60 end,
      set = function(v) if PanelM() then PanelM().SetOpacity(v) if PanelM().ApplyOpacity then PanelM().ApplyOpacity() end end end },
    { type = "slider", key = "bgAlpha", label = "Fond au survol", default = 45, min = 0, max = 100, step = 5, unit = "pct", cmd = "/drop fond <0-100>",
      help = "Opacité du fond quand le panneau est actif.",
      get = function() return PanelM() and PanelM().BgAlpha() or 45 end,
      set = function(v) if PanelM() then PanelM().SetBgAlpha(v) end end },
    { type = "slider", key = "fadeDelay", label = "Délai avant repos", default = 3, min = 0, max = 60, step = 1, unit = "s", cmd = "/drop fondu <0-60>",
      help = "Secondes avant que le panneau redevienne discret. 0 = jamais (le repos n'est pas déclenché).",
      get = function()
        local Pnl = PanelM()
        if Pnl then return Pnl.FadeDelay() end
        return 3
      end,
      set = function(v) if PanelM() then PanelM().SetFadeDelay(v) end end },
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
    { type = "check", key = "pauseFlying", label = "Pause pendant le vol", default = true, cmd = "/drop vol on|off",
      help = "Met le suivi et les toasts en pause sur un trajet aérien, un bateau, un zeppelin ou le tram. Rien n'est mis en file : à l'arrivée, pas de rattrapage.",
      get = function() return not (DBui().pauseFlying == false) end,
      set = function(v)
        ns.SetOpt("pauseFlying", v and true or false)
        if ns.Flight and ns.Flight.Sync then pcall(ns.Flight.Sync, "option") end
      end },
  } },
  { id = "notif", title = "Notifications et toasts", tab = "Toasts", desc = "Toasts, célébrations, alertes et mode calme.", items = {
    { type = "check", key = "dropsEnabled", label = "Afficher les notifications", default = true, cmd = "/drop drops on|off",
      help = "Interrupteur général des toasts de gain." },
    { type = "radio", key = "notifMode", label = "Position", default = "dessus", cmd = "/drop notif dessus|dessous|detache",
      choices = { { "dessus", "Au-dessus du panneau" }, { "dessous", "En dessous du panneau" }, { "detache", "Libre (déplaçable)" } },
      help = "Où apparaissent les toasts.",
      get = function() return ns.Notif and ns.Notif.Mode() or "dessus" end,
      set = function(v) if ns.Notif then ns.Notif.Set(v) end end },
    { type = "radio", key = "dropDir", label = "Sens des notifs", default = "haut", cmd = "/drop drops sens haut|bas|place",
      choices = { { "haut", "Vers le haut" }, { "bas", "Vers le bas" }, { "place", "Sur place" } },
      help = "En position libre : le plus récent reste à l'emplacement choisi. Vers le haut : les anciens montent. Vers le bas : ils descendent. Sur place : pile de cartes (3 visibles). Sans effet au-dessus ou en dessous du panneau." },
    { type = "radio", key = "dropStyle", label = "Format", default = "complet",
      choices = { { "complet", "Complet" }, { "leger", "Une ligne" } }, cmd = "/drop drops style complet|leger",
      help = "Toast complet ou une seule ligne discrète." },
    { type = "check", key = "xpDrops", label = "Gains d'XP", default = true, cmd = "/drop drops xp on|off",
      help = "Toasts d'XP : remise de quête, jalons discrets à 25, 50 et 75 % du niveau en cours, une fois par palier. Pas de toast à chaque monstre tué. La montée de niveau se règle à part." },
    { type = "check", key = "skillDrops", label = "Gains de compétence", default = true, cmd = "/drop drops comp on|off", help = "Toast à chaque +1 de compétence." },
    { type = "test", key = "weaponTest", label = "Tester armes / Défense",
      help = "Joue un gain bleu (toast, +1, voile et étincelle) sur une case d'arme ou de Défense." },
    { type = "check", key = "flyAnim", label = "Animation vers la case", default = true, cmd = "/drop animation on|off",
      help = "Un éclat vole du toast jusqu'à la case, puis « +N »." },
    { type = "check", key = "paliers", label = "Palier atteint", default = true, cmd = "/drop paliers on|off", help = "Prévient quand il faut aller voir ton maître." },
    { type = "check", key = "objectifs", label = "Objectif atteint", default = true, cmd = "/drop objectif on|off", help = "Prévient quand un objectif (clic droit sur une case) est atteint." },
    { type = "check", key = "levelUpAnim", label = "Animation de niveau", default = true, cmd = "/drop anim on|off", help = "Grande animation à chaque niveau." },
    { type = "check", key = "totalDing", label = "Palier du total", default = true, cmd = "Réglage de ce panneau et de la visite guidée (/drop setup)", help = "Toast doré et émote quand le niveau total franchit un palier." },
    { type = "check", key = "fireworks", label = "Feu d'artifice (maximum)", default = true, cmd = "Réglage de ce panneau et de la visite guidée (/drop setup)", help = "Gerbes dorées quand le niveau total maximum est atteint." },
    -- 3.8.2 : une liste à cases remplace « Alerte de butin rare » + « à partir de »
    { type = "radio", multi = true, qualityColors = true, key = "lootAlerts", label = "Alertes de butin", default = "45", cmd = "Réglage de ce panneau",
      choices = { { 3, "Rare" }, { 4, "Épique" }, { 5, "Légendaire" } },
      help = "Toast quand tu reçois un objet d'une qualité cochée, dans la couleur de l'objet.",
      get = function() return ns.Hunt and ns.Hunt.LootQualString and ns.Hunt.LootQualString() or "45" end,
      set = function(v) if ns.Hunt and ns.Hunt.SetLootQualString then ns.Hunt.SetLootQualString(v) end end },
    { type = "check", key = "huntAlert", label = "Alerte de chasse", default = true, cmd = "Réglage de ce panneau et de la visite guidée (/drop setup)", help = "Toast quand un objet de ta liste de chasse tombe." },
    -- 3.9.0 : objet recherché repéré dans les fenêtres de butin et de jet de groupe
    { type = "check", key = "huntRoll", label = "Repérer l'objet au butin", default = true, cmd = "Réglage de ce panneau",
      help = "Cadre doré sur l'objet de ta chasse dans la fenêtre de butin et au jet de groupe, avec un toast pour le jet." },
    { type = "slider", key = "dropWidth", label = "Largeur des notifs", default = 0, min = 0, max = 480, step = 10, unit = "pxauto",
      help = "Auto : suit la largeur du panneau, avec un minimum lisible (260 px à l'échelle). Une valeur fixe impose la largeur. Si le toast est plus large que le panneau, il s'aligne sur le bord du panneau du côté de l'écran, sans dépasser." },
    { type = "slider", key = "dropDuration", label = "Durée d'affichage", default = 2.6, min = 1, max = 10, step = 0.5, cmd = "/drop drops duree <1-10>", unit = "s",
      help = "Temps pendant lequel un toast reste visible." },
    { type = "slider", key = "dropBgAlpha", label = "Fond des toasts", default = 0.68, min = 0, max = 1, step = 0.05, cmd = "/drop drops opacite <0-100>", unit = "%",
      help = "Opacité du fond des toasts (Classique / repli)." },
    -- 3.8.3 : créatures qui donnent un ingrédient : une case par métier (liste à cases, « Aucun » en tête).
    -- Avant : une seule case « recette possible » (viande et étoffes : très répétitif en balade).
    { type = "radio", multi = true, key = "scannerToasts", label = "Créatures à ingrédients", default = "", cmd = "/drop scanner toast on|off",
      choices = { { 1, "Cuisine" }, { 2, "Secourisme" } },
      help = "Toast quand une créature proche donne un ingrédient d'une recette que tu connais, une fois par type de créature.",
      get = function() return ns.Scanner and ns.Scanner.ToastSkillsString and ns.Scanner.ToastSkillsString() or "" end,
      set = function(v) if ns.Scanner and ns.Scanner.SetToastSkills then ns.Scanner.SetToastSkills(v) end end },
  } },
  { id = "sounds", title = "Sons", desc = "Un interrupteur général, puis chaque son à part.", items = {
    { type = "check", key = "levelUpSound", label = "Son de niveau", default = false, cmd = "/drop anim son on|off", help = "Joue un son avec l'animation de niveau." },
    { type = "check", key = "scannerSound", label = "Son du toast recette", default = false, cmd = "/drop scanner son on|off",
      help = "Petit son avec le toast « recette possible »." },
  } },
  { id = "prof", title = "Métiers & surlignage", tab = "Métiers", desc = "Surlignage vert, infobulles, fenêtre des métiers et suivi.", items = {
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
    { type = "check", key = "craftNotify", label = "Pastille « N prêts »", default = true, cmd = "/drop recettes on|off", refresh = true,
      help = "Nombre de recettes que tes sacs permettent de faire pour un +1." },
    { type = "check", key = "links", label = "Liens entre métiers", default = true, cmd = "/drop liens on|off",
      help = "« Utilisé par » dans l'infobulle des objets et des créatures." },
    -- 3.9.0 : prochain meilleur +1 dans l'infobulle des cases de métier (liste « Infobulles »)
    { type = "check", key = "nextBest", label = "Prochain +1 conseillé", default = true, cmd = "Réglage de ce panneau",
      help = "Quand rien ne fait progresser avec tes sacs : la recette la plus proche, ce qui manque et où le trouver." },
    { type = "check", key = "unlearned", label = "Recettes à apprendre", default = true, cmd = "/drop nonapprises on|off",
      help = "Montre aussi les recettes pas encore apprises (rang requis)." },
    -- 3.8.2 : icônes au-dessus des barres de nom des créatures : un interrupteur général + les recettes à part
    -- 3.8.3 : icône de Dépeçage au-dessus du nom des créatures (liste « Icônes sur les créatures »)
    { type = "check", key = "plateSkin", label = "Dépeçage sur les créatures", default = true, cmd = "Réglage de ce panneau",
      help = "Icône de Dépeçage au-dessus du nom des créatures que tu peux dépecer.",
      set = function(v) ns.SetOpt("plateSkin", v and true or false) Options.RefreshPlates() end },
    { type = "check", key = "scannerIcons", label = "Recettes sur les créatures", default = true, cmd = "/drop scanner icones on|off",
      help = "Icônes Cuisine, Secourisme et autres métiers quand la créature donne un ingrédient de recette : vert = +1 possible.",
      set = function(v) ns.SetOpt("scannerIcons", v and true or false) Options.RefreshPlates() end },
    { type = "check", key = "tipCompact", label = "Infobulle courte", default = true, cmd = "/drop infobulle compacte|detail",
      help = "Une ligne par métier ; maintiens Maj pour le détail.",
      set = function(v) ns.SetOpt("tipCompact", v and true or false) if ns.Tip then ns.Tip.Sync() end end },
    { type = "check", key = "styleMetiers", label = "Habiller la fenêtre Métiers", default = true, cmd = "/drop style on|off",
      help = "Barres et encadrés au style de Dropamine dans la fenêtre du jeu." },
    { type = "check", key = "openProf", label = "Clic : ouvrir / fermer le métier", default = true, cmd = "/drop ouvrir on|off",
      help = "Clic gauche sur une case de métier : ouvre sa fenêtre, un 2e clic la ferme. Hors combat.",
      get = function() return not (DBui().openProf == false) end,
      set = function(v) if v then DBui().openProf = nil else DBui().openProf = false end end },
  } },
  -- 3.6.0 : progression (objectif de session, série, récap hebdo, succès) ;
  -- les réglages viennent de Progress.lua (Options.EXTRA).
  { id = "progress", title = "Progression", desc = "Objectifs, succès, récaps et suivi dans les infobulles.", items = {} },
  -- 3.8.1 : Chasse et Collection, fonctions à part entière (onglets de la fenêtre Progression visibles à tout niveau)
  { id = "hunt", title = "Chasse et collection", tab = "Chasse", desc = "Objets recherchés, alertes de butin rare et collection.", items = {} },
  { id = "advanced", title = "Avancé", extra = true, desc = "JcJ, rappels d'armes et collecte de données. Les défauts conviennent à tous.", items = {
    { type = "check", key = "pvp", label = "Case JcJ", default = true, cmd = "/drop pvp on|off",
      help = "Rang, honneur et série de victoires dans la grille.",
      get = function() return not (ns.db and ns.db.ui and ns.db.ui.pvp == false) end,
      set = function(v) if ns.PvP then ns.PvP.SetEnabled(v and true or false) else if v then DBui().pvp = nil else DBui().pvp = false end end end },
    { type = "check", key = "pvpMarks", label = "Repères sur les ennemis", default = true, cmd = "/drop pvp marques on|off",
      help = "Vert : rapporte de l'honneur ; gris : ne rapporte rien." },
    { type = "check", key = "scanner", label = "Apprendre le butin", default = true, cmd = "/drop scanner on|off",
      help = "Mémorise ce que lâchent les créatures (à laisser activé)." },
    { type = "check", key = "session", label = "Gains du jour", default = true, cmd = "/drop session on|off", help = "« +N aujourd'hui » dans l'infobulle des cases." },
    { type = "check", key = "rappel", label = "Rappel arme en retard", default = true, cmd = "/drop rappel on|off", help = "Signale discrètement une arme en main sous-montée." },
    -- 3.9.0 : niveaux de monstres conseillés sur les cases d'arme / Défense (liste « Rappels d'armes »)
    { type = "check", key = "weaponLevels", label = "Niveaux de monstres conseillés", default = true, cmd = "/drop armes",
      help = "Sur les cases d'arme et de Défense pas au maximum : la plage de niveaux qui fait monter, et un avertissement si ta cible est grise." },
  } },
}
-- Lignes ajoutées par d'autres modules (QoL, Dopamine) : rangées dans le bon groupe,
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

-- 3.5.22 : ordre d'affichage dans chaque famille (les extras s'y insèrent).
Options.ITEM_ORDER = {
  display = { "theme", "lang", "charProfile", "cols", "scale", "opacity", "bgAlpha", "fadeDelay", "colorMode", "showTotal", "nextBar", "smartSort", "locked", "pauseFlying" },
  notif = { "dropsEnabled", "notifMode", "dropDir", "dropStyle", "dropWidth", "xpDrops", "skillDrops", "weaponTest", "flyAnim", "paliers", "objectifs", "levelUpAnim", "dropDuration", "dropBgAlpha", "scannerToasts", "combo", "maxFx", "records", "prepalier", "jalons", "recapLogout", "quietMode", "quietToasts" },
  sounds = { "sounds", "quietSounds", "soundSkill", "soundPalier", "soundMax", "soundDaily", "soundRecord", "levelUpSound", "scannerSound" },
  progress = { "goalToast", "achievements", "weeklyRecap" },
  prof = { "gatherAlerts", "activity", "craftNotify", "links", "unlearned", "plateSkin", "scannerIcons", "tipCompact", "styleMetiers", "openProf", "collection", "daily", "peche", "courses" },
  advanced = { "pvp", "pvpMarks", "scanner", "session", "rappel", "eta", "historique", "alts", "partage", "defense", "maitreArmes", "armePrincipale" },
}

function Options.LegacySectionItems(sec)
  local list, seen = {}, {}
  local function add(it)
    if not it or not it.key or seen[it.key] then return end
    if Options.EXTRA_LABEL[it.key] then it.label = Options.EXTRA_LABEL[it.key] end
    if Options.EXTRA_HELP[it.key] then it.help = Options.EXTRA_HELP[it.key] end
    seen[it.key] = true
    list[#list + 1] = it
  end
  local byKey = {}
  for _, it in ipairs(sec.items) do if it.key then byKey[it.key] = it end end
  for _, it in ipairs(Options.EXTRA) do
    if it.key and (Options.EXTRA_HOME[it.key] or "advanced") == sec.id then
      if not byKey[it.key] then byKey[it.key] = it end
    end
  end
  local order = Options.ITEM_ORDER and Options.ITEM_ORDER[sec.id]
  if order then
    for _, key in ipairs(order) do add(byKey[key]) end
  end
  for _, it in ipairs(sec.items) do add(it) end
  for _, it in ipairs(Options.EXTRA) do
    if it.key and (Options.EXTRA_HOME[it.key] or "advanced") == sec.id then add(byKey[it.key] or it) end
  end
  return list
end

-- 3.8.1 : plan unique des réglages. Chaque famille est découpée en sous-groupes titrés ; une ligne
-- n'apparaît qu'à un seul endroit, quel que soit le module qui l'a ajoutée. Une ligne absente du plan
-- (module futur) tombe en bas de sa famille d'origine, sous « Autres ».
Options.MAP = {
  -- 3.8.3 : réglages réorganisés. Une famille de cases = une liste à cases (Options.GROUPS, clés « grp… »).
  display = {
    { "Apparence", { "theme", "lang", "colorMode" } },
    { "Disposition", { "cols", "scale", "showTotal", "nextBar", "smartSort" } },
    { "Transparence", { "opacity", "bgAlpha", "fadeDelay" } },
    { "Comportement", { "locked", "charProfile", "pauseFlying", "grpSlots" } },
  },
  notif = {
    { "Affichage des toasts", { "dropsEnabled", "notifMode", "dropDir", "dropStyle", "dropWidth", "dropDuration", "dropBgAlpha", "flyAnim" } },
    { "Quoi annoncer", { "grpGains", "grpReminders", "grpCelebr" } },
    { "Mode calme", { "quietMode", "quietToasts", "quietAuto" } },
  },
  sounds = {
    { "Sons", { "sounds", "quietSounds", "grpSounds" } },
  },
  prof = {
    { "Cases et créatures", { "grpTiles", "grpPlates", "scannerToasts" } },
    { "Fenêtre et infobulles", { "styleMetiers", "openProf", "grpTips" } },
  },
  hunt = {
    { "Chasse", { "huntAlert", "huntRoll", "lootAlerts" } },
    { "Collection", { "collection" } },
  },
  progress = {
    { "Progression", { "grpAnnounce", "grpTileTip", "partage" } },
  },
  advanced = {
    { "JcJ", { "pvp", "pvpMarks" } },
    { "Armes", { "grpWeapons" } },
    { "Données", { "scanner", "peche", "courses" } },
  },
}

-- 3.8.3 : listes à cases. Chaque case reste un réglage à part (même clé, même commande /drop) ;
-- la liste n'est qu'une façon de les ranger. « Aucun » en tête décoche tout ; Tester joue un exemple
-- de chaque case cochée, l'une après l'autre.
Options.GROUPS = {
  grpSlots = { label = "Icônes d'état", help = "Petites icônes dans la goutte et sur les cases quand il se passe quelque chose.",
    items = { { "slotDeath", "Mort" }, { "slotFlight", "Vol" }, { "slotAfk", "Absence (AFK)" }, { "slotBags", "Sacs pleins" },
      { "slotFishing", "Pêche" }, { "slotSwimming", "Nage" }, { "slotDurability", "Équipement usé" },
      { "slotTrainer", "Maître à proximité" }, { "restedAnim", "XP de repos" } } },
  grpGains = { label = "Gains", help = "Un toast à chaque gain. La montée de niveau est dans Célébrations.",
    items = { { "xpDrops", "XP (quêtes, jalons du niveau)" }, { "skillDrops", "Compétences (+1)" } },
    extraTests = { skillDrops = { "weaponTest" } } },
  grpReminders = { label = "Rappels", help = "Pour ne rien rater chez le maître ou sur tes objectifs.",
    items = { { "paliers", "Palier atteint (va voir ton maître)" }, { "prepalier", "5 points avant le palier" },
      { "trainerRankToast", "Rang à apprendre (en capitale)" }, { "objectifs", "Objectif d'une case atteint" } } },
  grpCelebr = { label = "Célébrations", help = "Les grands moments, avec un toast doré.",
    items = { { "levelUpAnim", "Montée de niveau" }, { "maxFx", "Compétence au maximum" }, { "totalDing", "Palier du niveau total" },
      { "fireworks", "Feu d'artifice (total maximum)" }, { "combo", "Combo de session" }, { "records", "Records personnels" } } },
  grpSounds = { label = "Un son pour…", help = "Chaque son se coche à part ; ils sont coupés par défaut.",
    items = { { "soundSkill", "Chaque point" }, { "soundPalier", "Palier" }, { "soundMax", "Maximum" }, { "levelUpSound", "Montée de niveau" },
      { "soundDaily", "Défi du jour" }, { "soundRecord", "Record" }, { "scannerSound", "Créature à ingrédient" } } },
  grpTiles = { label = "Sur les cases", help = "Ce que les cases de métier montrent d'elles-mêmes.",
    items = { { "gatherAlerts", "Vert selon la cible" }, { "activity", "Vert pour le métier en cours" }, { "craftNotify", "Pastille « N prêts »" } } },
  grpPlates = { label = "Icônes sur les créatures", help = "Au-dessus du nom des créatures : vert = +1 possible.",
    items = { { "plateSkin", "Dépeçage" }, { "scannerIcons", "Recettes (Cuisine, Secourisme…)" } } },
  grpTips = { label = "Infobulles", help = "Ce que les infobulles ajoutent.",
    items = { { "nextBest", "Prochain +1 conseillé" }, { "links", "Liens entre métiers (« Utilisé par »)" }, { "unlearned", "Recettes pas encore apprises" },
      { "tipCompact", "Version courte (Maj : détail)" }, { "tipTotalFull", "Total toujours complet" } } },
  grpAnnounce = { label = "Annonces", help = "Les toasts de la fenêtre Progression.",
    items = { { "goalToast", "Objectif de session atteint" }, { "achievements", "Succès" }, { "daily", "Défi du jour" },
      { "jalons", "Jalons personnels" }, { "weeklyRecap", "Récap du lundi" }, { "recapLogout", "Récap à la déconnexion" } } },
  grpTileTip = { label = "Dans l'infobulle des cases", help = "Lignes en plus quand tu survoles une case.",
    items = { { "session", "Gains du jour" }, { "eta", "Temps estimé jusqu'au rang" }, { "historique", "Historique 7 jours" }, { "alts", "Autres personnages" } } },
  grpWeapons = { label = "Rappels d'armes", help = "Petits rappels discrets sur tes armes.",
    items = { { "rappel", "Arme en retard" }, { "weaponLevels", "Niveaux de monstres conseillés" }, { "defense", "Défense (ennemis gris)" }, { "maitreArmes", "Arme pas apprise" }, { "armePrincipale", "Remettre l'arme principale" } } },
}
-- lignes rangées ailleurs (bouton de test seul, joué par la liste « Gains »)
Options.HIDDEN = { weaponTest = true }
Options._groupItems = {}
function Options.GroupItem(k)
  local g = Options.GROUPS[k]
  if not g then return nil end
  local it = Options._groupItems[k]
  if not it then
    it = { type = "radio", multi = true, checklist = true, key = k, label = g.label, help = g.help, choices = g.items, noReset = true }
    Options._groupItems[k] = it
  end
  return it
end
function Options.InGroup()
  local m = {}
  for _, g in pairs(Options.GROUPS) do for _, ch in ipairs(g.items) do m[ch[1]] = true end end
  for k in pairs(Options.HIDDEN) do m[k] = true end
  return m
end
-- réglage brut (rangé dans une liste ou non), pour Find / Get / Set
function Options.RawItem(key)
  for _, s2 in ipairs(Options.SECTIONS) do for _, it in ipairs(s2.items) do if it.key == key then return it end end end
  for _, it in ipairs(Options.EXTRA) do if it.key == key then return it end end
end

function Options.SectionItems(sec)
  local map = Options.MAP and Options.MAP[sec.id]
  if not map then return Options.LegacySectionItems(sec) end
  local byKey, mapped = {}, Options.InGroup()
  for _, s2 in ipairs(Options.SECTIONS) do for _, it in ipairs(s2.items) do if it.key then byKey[it.key] = it end end end
  for _, it in ipairs(Options.EXTRA) do if it.key and not byKey[it.key] then byKey[it.key] = it end end
  for k in pairs(Options.GROUPS) do byKey[k] = Options.GroupItem(k) end
  for _, g in pairs(Options.MAP) do for _, grp in ipairs(g) do for _, k in ipairs(grp[2]) do mapped[k] = true end end end
  local list, seen = {}, {}
  local function add(it, group)
    if not it or not it.key or seen[it.key] then return end
    seen[it.key] = true
    if Options.EXTRA_LABEL[it.key] then it.label = Options.EXTRA_LABEL[it.key] end
    if Options.EXTRA_HELP[it.key] then it.help = Options.EXTRA_HELP[it.key] end
    it.group = group
    list[#list + 1] = it
  end
  for _, grp in ipairs(map) do for _, k in ipairs(grp[2]) do add(byKey[k], grp[1]) end end
  for _, it in ipairs(Options.LegacySectionItems(sec)) do if not mapped[it.key] then add(it, "Autres") end end
  return list
end

-- Liste à plat, dans l'ordre d'affichage (Find / Get / debug).
-- 3.9.0 : liste mise en cache (avant : reconstruite à chaque Find / Get, donc à chaque lecture d'un
-- réglage). Reconstruite seulement quand un module ajoute des lignes (Options.EXTRA grandit).
function Options.All()
  local n = #Options.EXTRA
  if Options._all and Options._allN == n then return Options._all end
  local out, seen, byKey = {}, {}, {}
  local function put(it)
    out[#out + 1] = it
    seen[it.key or ""] = true
    if it.key and byKey[it.key] == nil then byKey[it.key] = it end
  end
  for _, sec in ipairs(Options.SECTIONS) do
    for _, it in ipairs(Options.SectionItems(sec)) do put(it) end
  end
  -- 3.8.3 : les réglages rangés dans une liste restent trouvables (valeur, défaut, réinitialisation)
  for k in pairs(Options.InGroup()) do
    if not seen[k] then local it = Options.RawItem(k) if it then put(it) end end
  end
  Options._all, Options._allN, Options._byKey = out, n, byKey
  return out
end
Options.ITEMS = Options.All()

function Options.Find(key)
  Options.All()
  return Options._byKey and Options._byKey[key]
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
    if ns.SaveActiveProfile then pcall(ns.SaveActiveProfile) end
    if Options.panel and Options.panel:IsShown() and not Options._syncing then Options.Sync() end
    if Options.OnLiveChange then Options.OnLiveChange(key) end
    return Options.Get(key)
  end
  if key == "colorMode" then
    if ns.SetColorMode then ns.SetColorMode(value) else ns.EnsureDB().ui.colorMode = value end
    if ns.OnOptionChanged then pcall(ns.OnOptionChanged, key, value) end
  else
    ns.SetOpt(key, value)
  end
  if ns.SaveActiveProfile then pcall(ns.SaveActiveProfile) end
  if Options.OnLiveChange then Options.OnLiveChange(key) end
  return value
end

function ns.OnOptionChanged(key, value)
  local UI = ns.UI
  if key == "dropsEnabled" and UI and UI.ApplyDropsEnabled then pcall(UI.ApplyDropsEnabled, UI) end
  if (key == "dropDir" or key == "dropStyle" or key == "dropWidth") and UI and UI.ApplyDropsLayout then pcall(UI.ApplyDropsLayout, UI) end
  if key == "dropBgAlpha" and UI and UI.RefreshToastOpacity then pcall(UI.RefreshToastOpacity, UI) end
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
  if Options.OnLiveChange then Options.OnLiveChange(key) end
end

-- /drop drops xp|comp|style|duree|opacite ----------------------------------------
function ns.DropsSubcommand(full)
  local sub, arg = (full or ""):lower():match("^(%S*)%s*(%S*)")
  if sub == "xp" then
    local v = Options.Set("xpDrops", ns.ParseOnOff(arg, Options.Get("xpDrops")))
    ns.Print(Tr["drops d'XP "] .. (v and Tr["activés."] or Tr["désactivés."]))
    return true
  elseif sub == "comp" or sub == "competences" or sub == "compétences" then
    local v = Options.Set("skillDrops", ns.ParseOnOff(arg, Options.Get("skillDrops")))
    ns.Print(Tr["drops de compétence "] .. (v and Tr["activés."] or Tr["désactivés."]))
    return true
  elseif sub == "style" then
    if arg == "leger" or arg == "léger" then Options.Set("dropStyle", "leger")
    elseif arg == "complet" then Options.Set("dropStyle", "complet")
    else ns.Print(Tr["style actuel : "] .. tostring(Options.Get("dropStyle")) .. Tr[". Usage : /drop drops style complet|leger"]) return true end
    ns.Print(Tr["style des drops : "] .. Options.Get("dropStyle") .. ".")
    return true
  elseif sub == "chat" or sub == "coller" then
    local v = Options.Set("dropsSnapChat", ns.ParseOnOff(arg, Options.Get("dropsSnapChat")))
    ns.Print(v and Tr["drops collés au-dessus du chat (même largeur)."] or Tr["drops détachés du chat."])
    return true
  elseif sub == "sens" or sub == "direction" then
    if arg == "haut" or arg == "bas" or arg == "place" then Options.Set("dropDir", arg)
    elseif arg == "surplace" or arg == "pile" then Options.Set("dropDir", "place")
    else
      local d = Options.Get("dropDir") or "haut"
      local names = { haut = Tr["vers le haut"], bas = Tr["vers le bas"], place = Tr["sur place"] }
      ns.Print(Tr["sens actuel : "] .. (names[d] or tostring(d)) .. Tr[". Usage : /drop drops sens haut|bas|place"])
      return true
    end
    local d = Options.Get("dropDir")
    local names = { haut = Tr["vers le haut"], bas = Tr["vers le bas"], place = Tr["sur place"] }
    ns.Print(Tr["sens des notifs : "] .. (names[d] or tostring(d)) .. ".")
    return true
  elseif sub == "duree" or sub == "durée" then
    if not ns.N(arg) then ns.Print(Tr["durée actuelle : "] .. tostring(Options.Get("dropDuration")) .. Tr[" s. Usage : /drop drops duree <1-10>"]) return true end
    local v = Options.Set("dropDuration", ns.N(arg))
    ns.Print(Tr["durée des drops : "] .. tostring(v) .. Tr[" s."])
    return true
  elseif sub == "opacite" or sub == "opacité" then
    if not ns.N(arg) then ns.Print(Tr["opacité actuelle : "] .. tostring(math.floor((Options.Get("dropBgAlpha") or 0) * 100 + 0.5)) .. Tr[" %. Usage : /drop drops opacite <0-100>"]) return true end
    local a = ns.N(arg)
    if a > 1 then a = a / 100 end
    local v = Options.Set("dropBgAlpha", a)
    ns.Print(Tr["opacité du fond des drops : "] .. tostring(math.floor(v * 100 + 0.5)) .. " %.")
    return true
  end
  return false
end

ns.SlashExt.style = function(rest)
  local v = Options.Set("styleMetiers", ns.ParseOnOff(rest, Options.Get("styleMetiers")))
  ns.Print(Tr["style Métiers "] .. (v and Tr["activé."] or Tr["désactivé (style précédent)."]))
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
  if fs.SetJustifyV then fs:SetJustifyV("TOP") end
  return fs
end

Options.widgets = {}
-- 3.5.22 : look natif Classic, sans encadrés dorés. Titres GameFontNormal à
-- gauche, cases avec libellé or collé à la case, description blanche dessous,
-- curseurs « Libellé  valeur » puis description puis barre, menus avec
-- libellé or au-dessus, deux colonnes quand ça tient, boutons rouges natifs.
Options.CONTENT_W, Options.COL_W, Options.COL2_X = 600, 540, 300   -- 3.8.1 : une seule colonne (les aides longues se coupaient)
Options.LAYOUT = {
  MARGIN = 8,
  TITLE_H = 22,
  ROW = 26,
  DESC_H = 14,
  DROP_H = 64,
  SLIDER_H = 72,
  SECTION_GAP = 16,
  CHECK_TEXT_X = 30,
  TEST_W = 64,
  RESET_W = 110,
}
Options.WHEEL_STEP = 90   -- 3.8.2 : défilement plus rapide (40 avant)

-- Conservé pour les tests / le repli autonome, mais plus utilisé pour le chrome.
Options.BOX_EDGE = "Interface\\Tooltips\\UI-Tooltip-Border"
Options.BOX_GOLD = { 1.00, 0.82, 0.00, 0.80 }
Options.BOX_FILL = { 0, 0, 0, 0.25 }

function Options.FormatValue(it, v)
  v = ns.N(v) or 0
  if it.unit == "pxauto" then
    if v <= 0 then return Tr["Auto"] end
    return tostring(math.floor(v + 0.5)) .. " px"
  end
  if it.unit == "%" then return tostring(math.floor(v * 100 + 0.5)) .. " %" end
  if it.unit == "pct" then return tostring(math.floor(v + 0.5)) .. " %" end
  if it.unit == "s" then
    if it.key == "fadeDelay" and v <= 0 then return Tr["Jamais"] end
    return tostring(v) .. Tr[" s"]
  end
  return tostring(v)
end

-- Molette : défile le contenu, borné à la plage du ScrollFrame.
function Options.Scroll(delta)
  local sc = Options.scroll
  if not sc or not sc.SetVerticalScroll then return end
  local cur = (sc.GetVerticalScroll and sc:GetVerticalScroll()) or 0
  local max = (sc.GetVerticalScrollRange and sc:GetVerticalScrollRange()) or 0
  -- 3.8.2 : borne calculée sur la page affichée (la plage du ScrollFrame pouvait rester celle de
  -- toutes les pages empilées : on descendait alors dans le vide)
  local own = Options.MaxScroll and Options.MaxScroll()
  if own and own < max then max = own end
  local v = cur - (delta or 0) * Options.WHEEL_STEP
  if v < 0 then v = 0 end
  if v > max then v = max end
  sc:SetVerticalScroll(v)
  return v
end

-- Rectangles posés (x, y vers le bas, largeur, hauteur) : vérifiés par les tests.
local function Rect(owner, x, y, w, h, what)
  owner._rects = owner._rects or {}
  owner._rects[#owner._rects + 1] = { x = x, y = y, w = w, h = h, what = what }
end

local function TipOn(frame, title, line)
  frame:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if title then GameTooltip:AddLine(title, 1, 0.82, 0) end
    if line then GameTooltip:AddLine(line, 1, 1, 1, true) end
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

local function MakeDropdown(box, it, x, y)
  local name = "DropamineOpt_" .. it.key
  local dd = TryCreate("Frame", name, box, { "UIDropDownMenuTemplate" })
  dd:SetPoint("TOPLEFT", box, "TOPLEFT", x - 16, -y)   -- le modèle a 16 px de marge gauche
  local W = math.min(300, Options.COL_W - 24)
  if type(_G.UIDropDownMenu_SetWidth) == "function" then pcall(_G.UIDropDownMenu_SetWidth, dd, W) end
  dd.choices = it.choices
  dd.key = it.key
  -- 3.8.2 : menu à cases (it.multi) : valeur = chiffres des choix cochés (« 45 »), « Aucun » en tête
  -- 3.8.3 : liste à cases (it.checklist) : chaque choix est un réglage à part (sa clé), coché = actif
  local function has(v, c)
    if it.checklist then return Options.Get(c) and true or false end
    return type(v) == "string" and v:find(tostring(c), 1, true) ~= nil
  end
  local function toggle(c)
    if it.checklist then Options.Set(c, not has(nil, c)) return end
    local cur = tostring(Options.Get(it.key) or "")
    if has(cur, c) then cur = cur:gsub(tostring(c), "") else cur = cur .. tostring(c) end
    Options.Set(it.key, cur)
  end
  local function clearAll()
    if it.checklist then for _, ch in ipairs(it.choices) do Options.Set(ch[1], false) end return end
    Options.Set(it.key, "")
  end
  local function hexOf(c)
    local rgb = it.qualityColors and ns.Hunt and ns.Hunt.QualityRGB and ns.Hunt.QualityRGB(nil, c)
    if not rgb then return nil end
    return string.format("|cff%02x%02x%02x", math.floor(rgb[1] * 255 + 0.5), math.floor(rgb[2] * 255 + 0.5), math.floor(rgb[3] * 255 + 0.5))
  end
  local function label(v)
    if it.multi then
      local parts = {}
      for _, ch in ipairs(it.choices) do
        if has(v, ch[1]) then local hx = hexOf(ch[1]) parts[#parts + 1] = hx and (hx .. Tr[ch[2]] .. "|r") or Tr[ch[2]] end
      end
      if #parts == 0 then return Tr["Aucun"] end
      if #parts == #it.choices and #parts > 2 then return Tr["Tout"] end
      -- liste longue : « 5 sur 9 » (les noms ne tiendraient pas dans le bouton)
      if #parts > 2 then return string.format(Tr["%d sur %d"], #parts, #it.choices) end
      return table.concat(parts, ", ")
    end
    for _, ch in ipairs(it.choices) do if ch[1] == v then return Tr[ch[2]] end end
    return tostring(v)
  end
  dd.Refresh = function(self)
    local v = Options.Get(it.key)
    if type(_G.UIDropDownMenu_SetText) == "function" then pcall(_G.UIDropDownMenu_SetText, self, label(v)) end
    self.selected = v
  end
  local function initMulti(level)
    local none = _G.UIDropDownMenu_CreateInfo()
    none.text, none.notCheckable = Tr["Aucun"], true
    none.func = function()
      clearAll()
      dd:Refresh()
      if type(_G.CloseDropDownMenus) == "function" then pcall(_G.CloseDropDownMenus) end
    end
    _G.UIDropDownMenu_AddButton(none, level)
    for _, ch in ipairs(it.choices) do
      local info = _G.UIDropDownMenu_CreateInfo()
      info.text, info.value = Tr[ch[2]], ch[1]
      info.colorCode = hexOf(ch[1])
      info.isNotRadio, info.keepShownOnClick = true, true
      info.checked = has(Options.Get(it.key), ch[1])
      info.func = function()
        toggle(ch[1])
        dd:Refresh()
      end
      _G.UIDropDownMenu_AddButton(info, level)
    end
  end
  local function init(self, level)
    if ns.InCombat and ns.InCombat() then return end
    if type(_G.UIDropDownMenu_CreateInfo) ~= "function" then return end
    if it.multi then return initMulti(level) end
    for _, ch in ipairs(it.choices) do
      local info = _G.UIDropDownMenu_CreateInfo()
      info.text, info.value = Tr[ch[2]], ch[1]
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

-- Aperçu en direct : le panneau Dropamine s'affiche (hors combat) tant que les
-- options sont ouvertes, pour que thème / taille / transparence se voient tout de suite.
Options.PREVIEW_KEYS = {
  theme = true, scale = true, opacity = true, bgAlpha = true, fadeDelay = true,
  cols = true, colorMode = true, showTotal = true, nextBar = true, locked = true,
  smartSort = true, charProfile = true,
}

function Options.EnsurePreviewVisible()
  if ns.InCombat and ns.InCombat() then
    if ns.AfterCombat then
      ns.AfterCombat("options-preview", function()
        if Options.panel and Options.panel:IsShown() then Options.EnsurePreviewVisible() end
      end)
    end
    return
  end
  local W = ns.Window
  if not (W and W.Show) then return end
  if W.IsShown and W.IsShown() then return end
  local db = ns.db or (ns.EnsureDB and ns.EnsureDB())
  local ui = db and db.ui
  Options._previewOpened = true
  Options._previewPrevOpen = ui and ui.panelOpen
  pcall(W.Show)
  if ui then ui.panelOpen = Options._previewPrevOpen end
end

function Options.EndPreview()
  if not Options._previewOpened then return end
  Options._previewOpened = nil
  if Options._previewPrevOpen then return end
  if ns.InCombat and ns.InCombat() then return end
  local W = ns.Window
  if W and W.Hide and W.IsShown and W.IsShown() then pcall(W.Hide) end
end

function Options.OnLiveChange(key)
  if not (Options.panel and Options.panel:IsShown()) then return end
  if key and not Options.PREVIEW_KEYS[key] then return end
  Options.EnsurePreviewVisible()
end

-- Boutons « Tester » : joue le son / montre un toast d'exemple, même si la case est décochée.
Options.TEST = {
  dropsEnabled = "skill", xpDrops = "xp", skillDrops = "skill", weaponTest = "weapon", flyAnim = "skill",
  paliers = "tier", objectifs = "goal", levelUpAnim = "levelup",
  scannerToasts = "scanner", jalons = "milestone", recapLogout = "recap",
  maxFx = "max", records = "record", prepalier = "pretier", combo = "combo",
  soundSkill = "sound", soundPalier = "sound", soundMax = "sound",
  soundDaily = "sound", soundRecord = "sound", levelUpSound = "sound",
  scannerSound = "sound",
  -- 3.6.0 (Progress.lua) : les tests passent outre le mode calme (force)
  goalToast = "sessiongoal", achievements = "achievement", weeklyRecap = "weekly",
  -- 3.8.2 : chaque notification a son bouton « Tester »
  totalDing = "totalding", fireworks = "fireworks", lootAlerts = "rare", huntAlert = "hunt",
  trainerRankToast = "rankup", daily = "daily",
  -- 3.8.3 : listes à cases : un exemple par case cochée, à la suite
  grpGains = "group", grpReminders = "group", grpCelebr = "group", grpSounds = "group", grpAnnounce = "group",
}

local function WeaponTestSkill()
  local name, id, icon = Tr["Défense"] or "Défense", "defense", "Interface\\Icons\\Ability_Defend"
  local C = ns.Compact
  if C and C.Tiles then
    local fallback
    for _, tile in ipairs(C.Tiles() or {}) do
      local d = tile and tile.data
      if d and not d.placeholder then
        local def = d.kind == "defense" or d.id == "defense" or d.skillId == "defense"
          or d.skillName == name or d.name == name
        local wep = d.kind == "melee" or d.kind == "ranged" or d.kind == "feral"
          or d.combatTile or d.kind == "weapon"
        if def then
          local ic = icon
          if tile.icon and tile.icon.GetTexture then ic = tile.icon:GetTexture() or ic end
          return d.skillName or d.name or name, d.id or d.skillId or id, ic, tile
        elseif wep and not fallback then
          fallback = tile
        end
      end
    end
    if fallback and fallback.data then
      local d = fallback.data
      local ic = icon
      if fallback.icon and fallback.icon.GetTexture then ic = fallback.icon:GetTexture() or ic end
      return d.skillName or d.name or name, d.id or d.skillId or id, ic, fallback
    end
  end
  return name, id, icon, nil
end

Options.TEST_GAP = 1.5
Options.TEST_DEBOUNCE = 0.4

local function TestNow()
  if type(GetTime) == "function" then
    local ok, v = pcall(GetTime)
    if ok and type(v) == "number" then return v end
  end
  return 0
end

local function After(sec, fn)
  if type(_G.C_Timer) == "table" and type(_G.C_Timer.After) == "function" then
    _G.C_Timer.After(sec, fn)
    return
  end
  local f = Options._testTimer
  if not f and type(CreateFrame) == "function" then
    local ok, fr = pcall(CreateFrame, "Frame", "DropamineOptTestTimer", _G.UIParent)
    if ok and fr then
      f = fr
      f._osrsOwn = true
      if f.EnableMouse then pcall(f.EnableMouse, f, false) end
      if f.Show then pcall(f.Show, f) end
      Options._testTimer = f
    end
  end
  Options._testWait = Options._testWait or {}
  Options._testWait[#Options._testWait + 1] = { t = sec or 0, fn = fn }
  if not f or not f.SetScript then return end
  f:SetScript("OnUpdate", function(self, dt)
    local q = Options._testWait
    if not (q and q[1]) then
      pcall(self.SetScript, self, "OnUpdate", nil)
      return
    end
    local i = 1
    while i <= #q do
      q[i].t = (q[i].t or 0) - (dt or 0)
      if q[i].t <= 0 then
        local cb = table.remove(q, i).fn
        if cb then pcall(cb) end
      else
        i = i + 1
      end
    end
    if not q[1] then pcall(self.SetScript, self, "OnUpdate", nil) end
  end)
end

local function RememberTile(tile)
  if not tile then return end
  Options._testSnap = Options._testSnap or { tiles = {} }
  local snap = Options._testSnap.tiles
  if snap[tile] then return end
  local fs = tile.levelFS
  snap[tile] = {
    countTop = tile._countTop,
    levelText = fs and fs.GetText and fs:GetText() or nil,
  }
end

local function PreviewTileFx(opts, drop)
  -- Testers : le +1 / voile jouent à l'affichage du toast de test (en jeu,
  -- le vrai gain reste calé sur l'arrivée de l'éclat, après le toast).
  -- Le +1 voyageur part de l'icône du toast de test vers la bonne case.
  local C = ns.Compact
  if not (C and C.Announce and C.TargetsFor) then return end
  local targets = C.TargetsFor(opts)
  if not (targets and targets[1]) then return end
  for _, tg in ipairs(targets) do
    if tg.key and tg.key ~= "total" and C.TileByKey then
      RememberTile(C.TileByKey(tg.key))
    end
  end
  -- Le +1 part de l'icône du toast ; le voile joue à l'arrivée (pas de 2e +1 sur la case).
  if drop and C.PreviewFly then
    pcall(C.PreviewFly, drop, opts, targets)
  elseif C.Announce then
    pcall(C.Announce, opts, targets)
  end
end

function Options.ResetTestState()
  local UI, C, S = ns.UI, ns.Compact, ns.Slot
  if UI and UI.dropsActive then
    for i = #UI.dropsActive, 1, -1 do
      local f = UI.dropsActive[i]
      if f and (f._testToast or (f._tintOpts and f._tintOpts.test)) then
        if f._fx then
          if f._fx.glowAnim and f._fx.glowAnim.Stop then pcall(f._fx.glowAnim.Stop, f._fx.glowAnim) end
          if f._fx.burstAnim and f._fx.burstAnim.Stop then pcall(f._fx.burstAnim.Stop, f._fx.burstAnim) end
          if f._fx.fx and f._fx.fx.Hide then pcall(f._fx.fx.Hide, f._fx.fx) end
          if f._fx.burst and f._fx.burst.Hide then pcall(f._fx.burst.Hide, f._fx.burst) end
        end
        if UI.DismissDrop then pcall(UI.DismissDrop, UI, f) end
      end
    end
  end
  if C and C.pool then
    for _, f in ipairs(C.pool) do
      if f and not f._busy then
        if f.ag and f.ag.Stop then pcall(f.ag.Stop, f.ag) end
        if f.Hide then pcall(f.Hide, f) end
        f._busy = nil
      end
    end
  end
  local snap = Options._testSnap and Options._testSnap.tiles
  if snap then
    for tile, st in pairs(snap) do
      if tile then
        if st.countTop ~= nil then tile._countTop = st.countTop end
        if tile._osrsPulse then
          local pul = tile._osrsPulse
          pul._pulseOn = nil
          if pul.ag and pul.ag.Stop then pcall(pul.ag.Stop, pul.ag) end
          if pul.SetScript then pcall(pul.SetScript, pul, "OnUpdate", nil) end
          if pul.SetAlpha then pcall(pul.SetAlpha, pul, 0) end
          if pul.Hide then pcall(pul.Hide, pul) end
        end
        if tile._osrsGain then
          local g = tile._osrsGain
          if g.ag and g.ag.Stop then pcall(g.ag.Stop, g.ag) end
          if g.SetScript then pcall(g.SetScript, g, "OnUpdate", nil) end
          if g.Hide then pcall(g.Hide, g) end
        end
        if UI and UI.UpdateTile and tile.data then pcall(UI.UpdateTile, UI, tile, tile.data) end
      end
    end
  end
  if S and S.HideBarSpark then pcall(S.HideBarSpark) end
  if S and S.HideFlySpark then pcall(S.HideFlySpark) end
  if C then C.holds = {} end
  Options._testSnap, Options._testQ = nil, {}
  Options._testPlaying, Options._testCurrent = nil, nil
  Options._testLastKey, Options._testLastAt = nil, nil
  Options._testWait = {}
  if Options._testTimer and Options._testTimer.SetScript then
    pcall(Options._testTimer.SetScript, Options._testTimer, "OnUpdate", nil)
  end
end

local function TestToast(kind)
  local ui = ns.UI
  if not (ui and ui.SpawnDrop) then return end
  local function ProfIcon(id, fallback)
    local e = ns.CATALOG_BY_ID and ns.CATALOG_BY_ID[id]
    return (e and e.icon) or fallback
  end
  local icon = ns.LEVEL_ICON or "Interface\\Icons\\INV_Misc_QuestionMark"
  local title, sub, cur, maxv, opts = Tr["Toast d'exemple"], "", nil, nil, { force = true, kind = "test" }
  local sample  -- objet réel de l'exemple (clic = fiche de l'objet)
  if kind == "xp" then
    title, sub, cur, maxv = Tr["Expérience +250"], Tr["Niveau 32"], 250, 2500
    opts.kind = "xp"
    icon = "Interface\\Icons\\INV_Misc_QuestionMark"
  elseif kind == "skill" then
    title, sub, cur, maxv = Tr["Dépeçage"] .. " +1", "161 / 225", 161, 225
    opts.kind, opts.skillId, opts.skillName = "skill", "skinning", Tr["Dépeçage"]
  elseif kind == "weapon" then
    local wname, wid, wicon, wtile = WeaponTestSkill()
    local curV, maxV = 75, 150
    if wtile and wtile.data then
      curV = tonumber(wtile.data.rank or wtile.data.current) or curV
      maxV = tonumber(wtile.data.max or wtile.data.maxRank or wtile.data.cap) or maxV
    end
    title, sub, cur, maxv = wname .. " +1", tostring(curV) .. " / " .. tostring(maxV), curV, maxV
    opts.kind, opts.skillId, opts.skillName = "skill", wid, wname
    icon = wicon or "Interface\\Icons\\Ability_Defend"
  elseif kind == "tier" then
    title, sub = Tr["Palier atteint"], Tr["Va voir ton maître"]
    opts.kind, opts.variant, opts.skillId, opts.skillName = "palier", "gold", "skinning", Tr["Dépeçage"]
    icon = ProfIcon("skinning", "Interface\\Icons\\INV_Misc_Pelt_Wolf_01")
  elseif kind == "goal" then
    title, sub = Tr["Objectif atteint"], Tr["Dépeçage"] .. " 150"
    opts.kind, opts.variant, opts.skillId, opts.skillName = "goal", "gold", "skinning", Tr["Dépeçage"]
    icon = ProfIcon("skinning", "Interface\\Icons\\INV_Misc_Pelt_Wolf_01")
  elseif kind == "scanner" then
    -- 3.8.3 : exemple dans le premier métier coché (Cuisine ou Secourisme) ; aucun coché = pas de toast
    local S = ns.Scanner
    local on = S and S.ToastSkillsString and S.ToastSkillsString() or ""
    if on == "" then
      if ns.Print then ns.Print(Tr["Créatures à ingrédients : aucun métier coché, pas de toast."]) end
      return nil
    end
    local sk = on:find("1", 1, true) and "cooking" or "firstaid"
    title, sub = Tr["Recette possible"], (sk == "cooking") and Tr["Viande de loup"] or Tr["Étoffe de soie"]
    opts.kind, opts.hint = "scanner", Tr["Toast d'exemple"]
    opts.skillId = sk
    opts.toastData = { kind = "scanner", skill = sk }
    icon = ProfIcon(sk, (sk == "cooking") and "Interface\\Icons\\INV_Misc_Food_15" or "Interface\\Icons\\Spell_Holy_SealOfSacrifice")
  elseif kind == "milestone" then
    title, sub = Tr["Jalons personnels"], Tr["Premier 150"]
    opts.kind, opts.variant = "milestone", "gold"
  elseif kind == "recap" then
    title, sub = Tr["Récap de session"], Tr["+12 aujourd'hui"]
    opts.kind = "recap"
  elseif kind == "max" then
    title, sub = Tr["Dépeçage"] .. Tr[" au maximum !"], "300 / 300"
    opts.kind, opts.variant, opts.big = "max", "gold", true
  elseif kind == "record" then
    title, sub = Tr["Nouveau record !"], "25" .. Tr[" points cette session"]
    opts.kind, opts.variant = "record", "gold"
  elseif kind == "pretier" then
    title, sub = Tr["Rappel avant le palier"], Tr["Encore 5 points"]
    opts.kind, opts.skillId, opts.skillName = "pretier", "skinning", Tr["Dépeçage"]
    icon = ProfIcon("skinning", "Interface\\Icons\\INV_Misc_Pelt_Wolf_01")
  elseif kind == "combo" then
    title, sub = Tr["Combo x"] .. "3", ""
    opts.kind, opts.variant = "combo", "gold"
  elseif kind == "sessiongoal" then
    title, sub = Tr["Objectif de session atteint !"], "20 / 20"
    opts.kind, opts.variant = "goal", "gold"
  elseif kind == "achievement" then
    title, sub = Tr["Succès : "] .. Tr["Série de 5 jours"], Tr["Toast d'exemple"]
    opts.kind, opts.variant = "achievement", "gold"
    icon = "Interface\\AddOns\\Dropamine\\Media\\Dropamine-Icon"
  elseif kind == "weekly" then
    title, sub = Tr["Récap de la semaine"], Tr["Toast d'exemple"]
    opts.kind, opts.variant = "weekly", "gold"
  elseif kind == "levelup" then
    local level = (ns.GetPlayerLevel and ns.GetPlayerLevel()) or 32
    title = Tr["Niveau "] .. tostring(level) .. Tr[" atteint !"]
    sub = (ui.LevelTotalLine and ui:LevelTotalLine()) or ""
    opts.kind, opts.variant, opts.big = "levelup", "gold", true
  elseif kind == "totalding" or kind == "fireworks" then
    local tmax = tonumber(ns.TOTAL_MAX) or 2460
    local hit = kind == "fireworks" and tmax or 1500
    title = Tr["Niveau total "] .. tostring(hit) .. Tr[" atteint !"]
    sub = kind == "fireworks" and Tr["Maximum atteint !"] or Tr["Palier du total franchi"]
    opts.kind, opts.variant, opts.big = "levelup", "gold", true
  elseif kind == "rare" or kind == "hunt" then
    -- exemple : le premier objet de la liste de chasse s'il y en a un (nom localisé, vraie icône)
    local H = ns.Hunt
    local first = H and H.List and H.List()[1]
    local nm = first and first.name
    if first and first.id and H.Icon then icon = H.Icon(first.id) end
    if not (first and first.id) then icon = "Interface\\Icons\\INV_Sword_39" end
    -- titre : couleur de qualité de l'objet lié
    local q = first and first.id and H.QualityOf and H.QualityOf(first.id)
    local rgb = first and first.id and H.QualityRGB and H.QualityRGB(first.id, q)
    if kind == "rare" then
      -- alerte de butin : vrai objet d'exemple dans la plus haute qualité cochée ; aucune cochée = pas d'alerte
      q = H.LootQualityTop and H.LootQualityTop()
      if not q then
        if ns.Print then ns.Print(Tr["Alertes de butin : aucune qualité cochée, pas de toast."]) end
        return nil
      end
      local sid, snm = H.SampleItem and H.SampleItem(q)
      if sid and _G.C_Item and _G.C_Item.RequestLoadItemDataByID then pcall(_G.C_Item.RequestLoadItemDataByID, sid) end
      local RT = { [3] = "Butin rare : ", [4] = "Butin épique : ", [5] = "Butin légendaire : " }
      local lbl = RT[q] or RT[4]
      local shown = sid and H.DisplayName and H.DisplayName(sid, snm) or snm
      title, sub = Tr[lbl] .. (shown or Tr["Objet d'exemple"]), Tr[(lbl:gsub(" : $", ""))]
      opts.titleColor = (H.QualityRGB and H.QualityRGB(nil, q)) or { 0.64, 0.21, 0.93 }
      icon = (sid and H.Icon and H.Icon(sid)) or "Interface\\Icons\\INV_Sword_39"
      sample = sid and { id = sid, name = shown } or nil
    else
      title, sub = Tr["Objet recherché trouvé : "] .. (nm or Tr["Sifflet de chien"]), string.format(Tr["Après %d tentatives"], 12)
      opts.titleColor = rgb
    end
    opts.kind, opts.variant = "achievement", "gold"
  elseif kind == "rankup" then
    local RT = ns.RankToast
    local list = { { id = "skinning", name = Tr["Dépeçage"] } }
    title = (RT and RT.Title and RT.Title(list)) or string.format(Tr["%s : rang supérieur disponible chez le maître"], Tr["Dépeçage"])
    sub = nil
    opts.kind, opts.skillId = "rank-trainer", "skinning"
    icon = ProfIcon("skinning", "Interface\\Icons\\INV_Misc_Pelt_Wolf_01")
  elseif kind == "daily" then
    title, sub = Tr["Défi du jour réussi !"], "+5" .. Tr[" en "] .. Tr["Dépeçage"]
    opts.kind, opts.variant = "daily", "gold"
    icon = ProfIcon("skinning", "Interface\\Icons\\INV_Misc_Pelt_Wolf_01")
  end
  opts.force, opts.test = true, true
  local f = ui:SpawnDrop(icon, title, sub, cur, maxv, nil, opts)
  if f then
    f._testToast = true
    -- butin rare / chasse : clic = fiche de l'objet, comme les vraies notifications
    if kind == "hunt" and ns.Hunt and ns.Hunt.MakeClickable and ns.Hunt.List then
      local first = ns.Hunt.List()[1]
      if first and first.id then pcall(ns.Hunt.MakeClickable, f, first.id, first.name) end
    elseif kind == "rare" and sample and ns.Hunt and ns.Hunt.MakeClickable then
      pcall(ns.Hunt.MakeClickable, f, sample.id, sample.name)
    end
    if (kind == "levelup" or kind == "max" or kind == "totalding" or kind == "fireworks") and ui.AttachFlareFx then pcall(ui.AttachFlareFx, ui, f, true) end
    if kind == "fireworks" and ns.Progress and ns.Progress.Fireworks then pcall(ns.Progress.Fireworks) end
    PreviewTileFx(opts, f)
  end
  return f
end

-- 3.8.2 : icônes des barres de nom : on retire tout, puis on repose selon les réglages (hors combat)
function Options.RefreshPlates()
  local G, S = ns.Gather, ns.Scanner
  if G and G.HideAll then pcall(G.HideAll) end
  if S and S.HideAll then pcall(S.HideAll) end
  if G then G._plateCache = {} end
  if ns.InCombat and ns.InCombat() then return end
  if ns.Opt("plateSkin") or ns.Opt("scannerIcons") then
    if G and G.Rescan then pcall(G.Rescan) end
    if S and S.RescanPlates then pcall(S.RescanPlates) end
  end
end

function Options.PlayTestSound(key)
  if type(_G.PlaySound) ~= "function" then return nil end
  if key == "levelUpSound" then
    local kit
    if ns.UI and ns.UI.LevelUpSoundKit then kit = ns.UI:LevelUpSoundKit() end
    if kit and (pcall(_G.PlaySound, kit, "SFX") or pcall(_G.PlaySound, kit)) then return kit end
    if pcall(_G.PlaySound, "LevelUp") then return "LevelUp" end
    return nil
  end
  if key == "scannerSound" then
    local kit = _G.SOUNDKIT and _G.SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
    if kit and (pcall(_G.PlaySound, kit, "SFX") or pcall(_G.PlaySound, kit)) then return kit end
    if pcall(_G.PlaySound, "igMainMenuOptionCheckBoxOn") then return "igMainMenuOptionCheckBoxOn" end
    return nil
  end
  if ns.Dopamine and ns.Dopamine.Play then return ns.Dopamine.Play(key, true) end
  return nil
end

function Options.PlayTestNow(key)
  local kind = Options.TEST[key]
  if not kind then return end
  if kind == "sound" then return Options.PlayTestSound(key) end
  return TestToast(kind)
end

function Options.KickTests()
  if Options._testPlaying then return end
  Options._testQ = Options._testQ or {}
  local key = table.remove(Options._testQ, 1)
  if not key then
    Options.ResetTestState()
    return
  end
  Options._testPlaying, Options._testCurrent = true, key
  -- Un seul toast/effet à la fois : on range le précédent, on garde le cliché pour la remise à zéro.
  if ns.UI and ns.UI.dropsActive then
    for i = #ns.UI.dropsActive, 1, -1 do
      local f = ns.UI.dropsActive[i]
      if f and f._testToast and ns.UI.DismissDrop then pcall(ns.UI.DismissDrop, ns.UI, f) end
    end
  end
  local ok, result = pcall(Options.PlayTestNow, key)
  Options._testLastResult = (ok and result) or nil
  After(Options.TEST_GAP or 1.5, function()
    Options._testPlaying, Options._testCurrent = nil, nil
    Options.KickTests()
  end)
  return Options._testLastResult
end

function Options.RunTest(key)
  local kind = Options.TEST[key]
  if not kind then return end
  -- 3.8.3 : liste à cases : on met en file l'exemple de chaque case cochée (joués l'un après l'autre)
  if kind == "group" then
    local g = Options.GROUPS and Options.GROUPS[key]
    if not g then return end
    local n = 0
    for _, ch in ipairs(g.items) do
      local k = ch[1]
      if Options.Get(k) then
        if Options.TEST[k] and Options.TEST[k] ~= "group" then Options.RunTest(k) n = n + 1 end
        for _, x in ipairs((g.extraTests and g.extraTests[k]) or {}) do Options.RunTest(x) n = n + 1 end
      end
    end
    if n == 0 and ns.Print then ns.Print(Tr["Rien n'est coché dans cette liste."]) end
    return
  end
  local now = TestNow()
  if key == Options._testLastKey and now > 0 and Options._testLastAt
    and (now - Options._testLastAt) < (Options.TEST_DEBOUNCE or 0.4) then
    return Options._testLastResult
  end
  Options._testLastKey, Options._testLastAt = key, now
  Options._testQ = Options._testQ or {}
  if Options._testCurrent == key then return Options._testLastResult end
  for i = 1, #Options._testQ do
    if Options._testQ[i] == key then return Options._testLastResult end
  end
  if not Options._testPlaying then
    table.insert(Options._testQ, 1, key)
    return Options.KickTests()
  end
  Options._testQ[#Options._testQ + 1] = key
  return Options._testLastResult
end

function Options.ResetSection(secId)
  local sec
  for _, s in ipairs(Options.SECTIONS) do if s.id == secId then sec = s break end end
  if not sec then return 0 end
  local n = 0
  Options._syncing = true
  local function reset(it)
    if it and it.key and it.default ~= nil and not it.noReset then
      local ok = pcall(Options.Set, it.key, it.default)
      if ok then n = n + 1 end
    end
  end
  for _, it in ipairs(Options.SectionItems(sec)) do
    if it.checklist then
      for _, ch in ipairs(it.choices) do reset(Options.RawItem(ch[1])) end   -- 3.8.3 : cases d'une liste
    else
      reset(it)
    end
  end
  Options._syncing = false
  if Options.panel then Options.Sync() end
  if Options.OnLiveChange then Options.OnLiveChange("theme") end
  return n
end

Options.RESET_TEXT, Options.RESET_CONFIRM = "Valeurs par défaut", "Confirmer ?"
Options.SECTION_RESET, Options.SECTION_RESET_CONFIRM = "Réinitialiser", "Confirmer ?"
Options.TEST_TEXT = "Tester"

function Options.ResetDefaults()
  local n = 0
  Options._syncing = true
  for _, it in ipairs(Options.All()) do
    if it.key and it.default ~= nil and not it.noReset then   -- 3.5.19 : la langue n'est pas remise à zéro
      local ok = pcall(Options.Set, it.key, it.default)
      if ok then n = n + 1 end
    end
  end
  Options._syncing = false
  if Options.panel then Options.Sync() end
  if Options.OnLiveChange then Options.OnLiveChange("theme") end
  return n
end
function Options.ResetClick(btn)
  if not Options._armed then
    Options._armed = true
    if btn and btn.SetText then btn:SetText(Tr[Options.RESET_CONFIRM]) end
    if _G.C_Timer and _G.C_Timer.After then
      _G.C_Timer.After(4, function() Options._armed = nil if btn and btn.SetText then btn:SetText(Tr[Options.RESET_TEXT]) end end)
    end
    return false
  end
  Options._armed = nil
  if btn and btn.SetText then btn:SetText(Tr[Options.RESET_TEXT]) end
  local n = Options.ResetDefaults()
  ns.Print(Tr["options : "] .. n .. Tr[" réglages remis par défaut."])
  return n
end

local function MakeSectionReset(parent, sec, x, y)
  local b = TryCreate("Button", "DropamineOptReset_" .. sec.id, parent, { "UIPanelButtonTemplate" })
  b:SetSize(Options.LAYOUT.RESET_W, 20)
  b:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -x, -y)
  b:SetText(Tr[Options.SECTION_RESET])
  b:SetScript("OnClick", function(self)
    if Options._armedSection ~= sec.id then
      Options._armedSection = sec.id
      self:SetText(Tr[Options.SECTION_RESET_CONFIRM])
      if _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(4, function()
          if Options._armedSection == sec.id then
            Options._armedSection = nil
            if self.SetText then self:SetText(Tr[Options.SECTION_RESET]) end
          end
        end)
      end
      return
    end
    Options._armedSection = nil
    self:SetText(Tr[Options.SECTION_RESET])
    local n = Options.ResetSection(sec.id)
    ns.Print(Tr["options : "] .. n .. Tr[" réglages remis par défaut."])
  end)
  TipOn(b, Tr[Options.SECTION_RESET], Tr["Remet les réglages de cette section à leur valeur d'origine"])
  return b
end

local function MakeTestButton(parent, it, x, y)
  local b = TryCreate("Button", "DropamineOptTest_" .. it.key, parent, { "UIPanelButtonTemplate" })
  b:SetSize(Options.LAYOUT.TEST_W, 20)
  b:SetPoint("TOPRIGHT", parent, "TOPLEFT", x + Options.COL_W - 4, -y)
  b:SetText(Tr[Options.TEST_TEXT])
  b:SetScript("OnClick", function() Options.RunTest(it.key) end)
  local kind = Options.TEST[it.key]
  local tip
  if kind == "sound" then tip = Tr["Joue le son"]
  elseif kind == "weapon" then tip = Tr["Joue un gain bleu (toast, +1, voile et étincelle) sur une case d'arme ou de Défense."]
  elseif kind == "group" then tip = Tr["Joue un exemple de chaque case cochée, l'un après l'autre."]
  else tip = Tr["Affiche un toast d'exemple"] end
  TipOn(b, Tr[Options.TEST_TEXT], tip)
  return b
end

function Options.BuildDevTest(content, y, boxW)
  if ns.DEV_TEST ~= true then return y end
  local L = Options.LAYOUT
  local T = ns.Test
  local h = Label(content, Tr["Test (DEV)"], "GameFontNormal")
  h:SetPoint("TOPLEFT", content, "TOPLEFT", L.MARGIN, -y)
  if h.SetJustifyH then h:SetJustifyH("LEFT") end
  y = y + L.TITLE_H
  local box = CreateFrame("Frame", "DropamineOptSec_devtest", content)
  box:SetPoint("TOPLEFT", content, "TOPLEFT", L.MARGIN, -y)
  box:SetWidth(boxW)
  box.header = h
  local desc = Label(box, Tr["Simulations temporaires, retirées avant la version publique. /drop test <état>|off"], "GameFontHighlightSmall")
  desc:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
  if desc.SetWidth then desc:SetWidth(boxW) end
  if desc.SetJustifyH then desc:SetJustifyH("LEFT") end
  local by = L.DESC_H + 8
  local function MakeBtn(name, text, tip, click, w)
    local b = TryCreate("Button", name, box, { "UIPanelButtonTemplate" })
    b:SetSize(w or 130, 22)
    b:SetText(Tr[text] or text)
    b:SetScript("OnClick", click)
    TipOn(b, Tr[text] or text, Tr[tip] or tip)
    return b
  end
  local btns = {}
  if T and T.STATES then
    for _, s in ipairs(T.STATES) do
      local id, label, tip = s.id, s.label, s.tip
      tip = tip or (s.stub and "Pas encore simulable." or "")
      btns[#btns + 1] = { id = id, label = label, tip = tip }
    end
  end
  btns[#btns + 1] = { id = "toast", label = "Toast", tip = "Affiche un toast de recette au nom très long (défilement + infobulle)." }
  btns[#btns + 1] = { id = "off", label = "Tout arrêter", tip = "Arrête toutes les simulations en cours." }
  local col, rowH, x, bw, gap = 0, 0, 0, 130, 8
  local cols = 4
  for i, info in ipairs(btns) do
    if col == 0 then x = 0 end
    local b = MakeBtn("DropamineDevTest_" .. info.id, info.label, info.tip, function()
      if ns.Test and ns.Test.Toggle then pcall(ns.Test.Toggle, info.id) end
    end, (info.id == "off" or info.id == "trainer" or info.id == "rankup" or info.id == "rested") and 200 or bw)
    b:SetPoint("TOPLEFT", box, "TOPLEFT", x, -by)
    local w = b:GetWidth() or bw
    x = x + w + gap
    col = col + 1
    rowH = 26
    if col >= cols or info.id == "off" then
      by = by + rowH
      col, x = 0, 0
    end
  end
  if col > 0 then by = by + rowH end
  box:SetHeight(by)
  Options.boxes = Options.boxes or {}
  Options.boxes[#Options.boxes + 1] = box
  Options.devTestBox = box
  return y + by + L.SECTION_GAP
end

function Options.Build()
  if Options.panel then return Options.panel end
  local panel = CreateFrame("Frame", "DropamineOptionsPanel", UIParent)
  panel.name = "Dropamine"
  panel:Hide()
  local title = Label(panel, "Dropamine", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
  local subt = Label(panel, Tr["Survole un réglage pour voir sa commande /drop."], "GameFontHighlightSmall")
  subt:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  if subt.SetWidth then subt:SetWidth(Options.CONTENT_W - 340) end
  if subt.SetJustifyH then subt:SetJustifyH("LEFT") end
  -- 3.3.8 : « Valeurs par défaut » (deux clics : le 1er demande confirmation)
  local rb = TryCreate("Button", "DropamineOptionsReset", panel, { "UIPanelButtonTemplate" })
  rb:SetSize(150, 22)
  rb:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -36, -16)
  rb:SetText(Tr[Options.RESET_TEXT])
  rb:SetScript("OnClick", function(self) Options.ResetClick(self) end)
  rb:SetScript("OnEnter", function(self)
    if GameTooltip then GameTooltip:SetOwner(self, "ANCHOR_LEFT") GameTooltip:AddLine(Tr["Remet tous les réglages de ce panneau à leur valeur d'origine"], 1, 1, 1, true) GameTooltip:AddLine(Tr["/drop options defaut"], 0.7, 0.7, 0.7) GameTooltip:Show() end
  end)
  rb:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  panel.reset, Options.resetButton = rb, rb
  -- 3.8.1 : revoir la visite guidée sans taper de commande
  local tb = TryCreate("Button", "DropamineOptionsTour", panel, { "UIPanelButtonTemplate" })
  tb:SetSize(130, 22)
  tb:SetPoint("RIGHT", rb, "LEFT", -8, 0)
  tb:SetText(Tr["Revoir la visite"])
  tb:SetScript("OnClick", function()
    if ns.Setup and ns.Setup.Open then
      if _G.SettingsPanel and _G.SettingsPanel.Hide then pcall(_G.SettingsPanel.Hide, _G.SettingsPanel) end
      ns.Setup.Open()
    end
  end)
  tb:SetScript("OnEnter", function(self)
    if GameTooltip then GameTooltip:SetOwner(self, "ANCHOR_LEFT") GameTooltip:AddLine(Tr["Rouvre la visite guidée de Dropamine."], 1, 1, 1, true) GameTooltip:AddLine("/drop setup", 0.7, 0.7, 0.7) GameTooltip:Show() end
  end)
  tb:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  panel.tour = tb
  local scroll = TryCreate("ScrollFrame", "DropamineOptionsScroll", panel, { "UIPanelScrollFrameTemplate" })
  scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -84)
  scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 8)
  if scroll.SetClipsChildren then pcall(scroll.SetClipsChildren, scroll, true) end
  local content = CreateFrame("Frame", "DropamineOptionsContent", scroll)
  content:SetSize(Options.CONTENT_W, 400)
  if scroll.SetScrollChild then scroll:SetScrollChild(content) end
  if scroll.EnableMouseWheel then scroll:EnableMouseWheel(true) end
  scroll:SetScript("OnMouseWheel", function(self, delta) Options.Scroll(delta) end)
  -- 3.8.2 : barre de défilement et flèches aussi bornées à la page affichée
  if scroll.HookScript then scroll:HookScript("OnVerticalScroll", function() if Options.ClampScroll then Options.ClampScroll() end end) end
  panel.scroll, panel.content = scroll, content
  Options.scroll, Options.content = scroll, content
  Options.boxes = {}
  Options.testButtons = {}
  Options.sectionResets = {}
  Options.secUI = {}
  local L = Options.LAYOUT
  local boxW = Options.CONTENT_W - 2 * L.MARGIN
  local y = 0
  for _, sec in ipairs(Options.SECTIONS) do
    local items = Options.SectionItems(sec)
    if #items > 0 then
      local h = Label(content, Tr[sec.title], "GameFontNormal")
      h:SetPoint("TOPLEFT", content, "TOPLEFT", L.MARGIN, -y)
      if h.SetJustifyH then h:SetJustifyH("LEFT") end
      local rst = MakeSectionReset(content, sec, L.MARGIN, y)
      rst:ClearAllPoints()
      rst:SetPoint("TOPRIGHT", content, "TOPLEFT", L.MARGIN + boxW, -y)
      Options.sectionResets[sec.id] = rst
      y = y + L.TITLE_H
      -- Cadre invisible (plus d'encadré doré) : sert au placement et aux tests.
      local box = CreateFrame("Frame", "DropamineOptSec_" .. sec.id, content)
      box:SetPoint("TOPLEFT", content, "TOPLEFT", L.MARGIN, -y)
      box:SetWidth(boxW)
      box.header = h
      box._chrome = "aucun (look natif, sans encadré)"
      local by = 0
      if sec.desc then
        local d = Label(box, Tr[sec.desc], "GameFontHighlightSmall")
        d.font = "GameFontHighlightSmall"
        d:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -by)
        if d.SetWidth then d:SetWidth(boxW) end
        if d.SetJustifyH then d:SetJustifyH("LEFT") end
        Rect(box, 0, by, boxW, L.DESC_H, sec.id .. ":intro")
        box.descFS = d
        by = by + L.DESC_H + 8
      end
      local col, rowH, used, rowKind = 0, 0, false, nil
      local function endRow()
        if used then by = by + rowH end
        col, rowH, used, rowKind = 0, 0, false, nil
      end
      local function cell()
        return (col == 0) and 0 or Options.COL2_X
      end
      local function advance(hgt, full)
        used = true
        if hgt > rowH then rowH = hgt end
        endRow()   -- une ligne par réglage
      end
      local function sameKind(kind)
        if used and rowKind and rowKind ~= kind then endRow() end
        rowKind = kind
      end
      local curGroup
      for _, it in ipairs(items) do
        if it.group and it.group ~= curGroup then
          endRow()
          if curGroup then by = by + 12 end
          curGroup = it.group
          local gf = Label(box, Tr[it.group], "GameFontNormalSmall")
          if gf.SetTextColor then gf:SetTextColor(0.85, 0.77, 0.54) end
          gf:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -by)
          Rect(box, 0, by, boxW, 14, sec.id .. ":groupe:" .. it.group)
          by = by + 20
        end
        if it.type == "check" then
          sameKind("check")
          if it.row and col == 1 then endRow() end
          local cx = cell()
          local cb = TryCreate("CheckButton", "DropamineOpt_" .. it.key, box, { "InterfaceOptionsCheckButtonTemplate", "UICheckButtonTemplate" })
          cb:SetSize(26, 26)
          cb:SetPoint("TOPLEFT", box, "TOPLEFT", cx, -by)
          local txt = FS(cb.Text, cb.text, _G[(cb.GetName and cb:GetName() or "") .. "Text"])
          if not txt then txt = Label(cb, "") end
          txt:ClearAllPoints()
          txt:SetPoint("LEFT", cb, "RIGHT", 4, 1)
          txt:SetText(Tr[it.label])
          if txt.SetFontObject and _G.GameFontNormal then pcall(txt.SetFontObject, txt, _G.GameFontNormal) end
          txt.font = "GameFontNormal"
          if txt.SetJustifyH then txt:SetJustifyH("LEFT") end
          if txt.SetWordWrap then pcall(txt.SetWordWrap, txt, false) end
          -- Pas de largeur fixe : un libellé centré dans une case trop large
          -- laissait un trou entre la case et le texte.
          cb.labelFS = txt
          cb.tooltipText = Tr[it.cmd]
          cb.col, cb.x, cb.y, cb.section = col, cx, by, sec.id
          local hasTest = Options.TEST[it.key] and true or false
          local hgt = L.ROW
          local mainW = Options.COL_W - (hasTest and (L.TEST_W + 8) or 0)
          Rect(box, cx, by, mainW, it.help and (L.ROW - 4) or L.ROW, it.key)
          if hasTest then
            local tb = MakeTestButton(box, it, cx, by + 2)
            Options.testButtons[it.key] = tb
            cb.testBtn = tb
            Rect(box, cx + Options.COL_W - L.TEST_W, by + 2, L.TEST_W, 20, it.key .. ":test")
          end
          if it.help then
            local hf = Label(box, Tr[it.help], "GameFontHighlightSmall")
            hf.font = "GameFontHighlightSmall"
            -- Sous la ligne case + libellé (+ bouton Tester) : pas de chevauchement.
            local helpY = by + (hasTest and L.ROW or (L.ROW - 4))
            local helpW = Options.COL_W - L.CHECK_TEXT_X - 2
            hf:SetPoint("TOPLEFT", box, "TOPLEFT", cx + L.CHECK_TEXT_X, -helpY)
            if hf.SetWidth then hf:SetWidth(helpW) end
            if hf.SetJustifyH then hf:SetJustifyH("LEFT") end
            if hf.SetWordWrap then pcall(hf.SetWordWrap, hf, true) end
            local lines = math.max(1, math.ceil(#Tr[it.help] / 88))
            hgt = helpY - by + lines * L.DESC_H + 4
            Rect(box, cx + L.CHECK_TEXT_X, helpY, helpW, lines * L.DESC_H, it.key .. ":desc")
            cb.helpFS = hf
          end
          cb:SetScript("OnClick", function(self)
            local on = self:GetChecked() and true or false
            Options.Set(it.key, on)
          end)
          TipOn(cb, Tr[it.label], Tr[it.cmd])
          Options.widgets[it.key] = cb
          advance(hgt, it.row)
        elseif it.type == "test" then
          sameKind("test")
          if col == 1 then endRow() end
          local cx = cell()
          local l = Label(box, Tr[it.label], "GameFontNormal")
          l:SetPoint("TOPLEFT", box, "TOPLEFT", cx, -by - 4)
          if l.SetWidth then l:SetWidth(Options.COL_W - (L.TEST_W + 8)) end
          if l.SetJustifyH then l:SetJustifyH("LEFT") end
          local tb = MakeTestButton(box, it, cx, by + 2)
          Options.testButtons[it.key] = tb
          if it.help then TipOn(l, Tr[it.label], Tr[it.help]) end
          Rect(box, cx, by, Options.COL_W - (L.TEST_W + 8), L.ROW, it.key)
          Rect(box, cx + Options.COL_W - L.TEST_W, by + 2, L.TEST_W, 20, it.key .. ":test")
          advance(L.ROW, true)
        elseif it.type == "radio" then
          sameKind("radio")
          local cx = cell()
          local l = Label(box, Tr[it.label], "GameFontNormal")
          l.font = "GameFontNormal"
          l:SetPoint("TOPLEFT", box, "TOPLEFT", cx, -by)
          if l.SetJustifyH then l:SetJustifyH("LEFT") end
          -- 3.8.2 : bouton « Tester » aussi sur un menu (Alertes de butin)
          if Options.TEST[it.key] then
            local tb = MakeTestButton(box, it, cx, by - 2)
            Options.testButtons[it.key] = tb
            Rect(box, cx + Options.COL_W - L.TEST_W, by - 2, L.TEST_W, 20, it.key .. ":test")
          end
          local hy = by + 16
          if it.help then
            local hf = Label(box, Tr[it.help], "GameFontHighlightSmall")
            hf.font = "GameFontHighlightSmall"
            hf:SetPoint("TOPLEFT", box, "TOPLEFT", cx, -hy)
            if hf.SetWidth then hf:SetWidth(Options.COL_W - 8) end
            if hf.SetJustifyH then hf:SetJustifyH("LEFT") end
            local rl = math.max(1, math.ceil(#Tr[it.help] / 100))
            Rect(box, cx, hy, Options.COL_W - 8, rl * L.DESC_H, it.key .. ":desc")
            hy = hy + rl * L.DESC_H + 4
          end
          local dd = MakeDropdown(box, it, cx, hy)
          dd.labelFS, dd.col, dd.helpFS = l, col, it.help and true or nil
          local dropH = hy - by + 32
          Rect(box, cx, by, Options.COL_W, 16, it.key)
          Rect(box, cx, hy, Options.COL_W, 32, it.key .. ":menu")
          Options.widgets[it.key] = dd
          advance(math.max(L.DROP_H, dropH + 4))
        elseif it.type == "slider" then
          endRow()
          local sname = "DropamineOpt_" .. it.key
          local l = Label(box, Tr[it.label], "GameFontNormal")
          l.font = "GameFontNormal"
          l:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -by)
          if l.SetJustifyH then l:SetJustifyH("LEFT") end
          local sl = TryCreate("Slider", sname, box, { "OptionsSliderTemplate", "UISliderTemplateWithLabels", "UISliderTemplate" })
          local sw = boxW - 24
          sl.valueFS = Label(box, "", "GameFontHighlight")
          sl.valueFS:SetPoint("LEFT", l, "RIGHT", 8, 0)
          if sl.valueFS.SetJustifyH then sl.valueFS:SetJustifyH("LEFT") end
          local hy = by + 16
          if it.help then
            local hf = Label(box, Tr[it.help], "GameFontHighlightSmall")
            hf:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -hy)
            if hf.SetWidth then hf:SetWidth(boxW) end
            if hf.SetJustifyH then hf:SetJustifyH("LEFT") end
            Rect(box, 0, hy, boxW, L.DESC_H, it.key .. ":desc")
            sl.helpFS = hf
            hy = hy + L.DESC_H + 4
          end
          sl:SetPoint("TOPLEFT", box, "TOPLEFT", 12, -hy)
          sl:SetWidth(sw)
          if sl.SetHeight then sl:SetHeight(17) end
          if sl.SetOrientation then sl:SetOrientation("HORIZONTAL") end
          sl:SetMinMaxValues(it.min, it.max)
          if sl.SetValueStep then sl:SetValueStep(it.step) end
          if sl.SetObeyStepOnDrag then pcall(sl.SetObeyStepOnDrag, sl, true) end
          local low = FS(_G[sname .. "Low"], sl.Low) local high = FS(_G[sname .. "High"], sl.High) local tt = FS(_G[sname .. "Text"], sl.Text)
          if not low then low = Label(box, "", "GameFontHighlightSmall") end
          if not high then high = Label(box, "", "GameFontHighlightSmall") end
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
          sl.labelFS, sl.y = l, by
          local slH = hy - by + 17 + 16
          Rect(box, 0, by, boxW, 16, it.key)
          Rect(box, 12, hy, sw, 17 + 16, it.key .. ":bar")
          sl:SetScript("OnValueChanged", function(self, v)
            if Options._syncing then return end
            v = Options.Set(it.key, math.floor(v / it.step + 0.5) * it.step)
            self.valueFS:SetText(Options.FormatValue(it, v))
          end)
          Options.widgets[it.key] = sl
          by = by + math.max(L.SLIDER_H, slH + 4)
        end
      end
      endRow()
      box:SetHeight(by)
      box.section = sec.id
      Options.boxes[#Options.boxes + 1] = box
      Options.secUI[sec.id] = { h = h, rst = rst, box = box, hgt = by }
      y = y + by + L.SECTION_GAP
    end
  end
  if ns.DEV_TEST and Options.BuildDevTest then
    y = Options.BuildDevTest(content, y, boxW) or y
  end
  content:SetHeight(y + L.MARGIN)
  -- 3.8.1 : une famille à la fois (onglets) au lieu d'un seul long défilement
  Options.tabs = {}
  local order = {}
  for _, sec in ipairs(Options.SECTIONS) do if Options.secUI[sec.id] then order[#order + 1] = sec end end
  local tabW = math.floor((Options.CONTENT_W - 2 * L.MARGIN) / math.max(1, #order))
  function Options.SelectTab(id)
    local found
    for _, sec in ipairs(order) do if sec.id == id then found = sec end end
    if not found then found = order[1] id = found and found.id end
    if not found then return end
    Options._tab = id
    for _, sec in ipairs(order) do
      local u, on = Options.secUI[sec.id], (sec.id == id)
      for _, w in ipairs({ u.h, u.rst, u.box }) do if on then w:Show() else w:Hide() end end
      local t = Options.tabs[sec.id]
      if t and t.fs then
        if on then t.fs:SetTextColor(1, 0.82, 0) else t.fs:SetTextColor(0.75, 0.72, 0.65) end
        if t.line then if on then t.line:Show() else t.line:Hide() end end
      end
      if on then
        u.h:ClearAllPoints() u.h:SetPoint("TOPLEFT", content, "TOPLEFT", L.MARGIN, 0)
        u.rst:ClearAllPoints() u.rst:SetPoint("TOPRIGHT", content, "TOPLEFT", L.MARGIN + boxW, 0)
        u.box:ClearAllPoints() u.box:SetPoint("TOPLEFT", content, "TOPLEFT", L.MARGIN, -L.TITLE_H)
        content:SetHeight(L.TITLE_H + u.hgt + L.SECTION_GAP + L.MARGIN)
        if scroll.UpdateScrollChildRect then pcall(scroll.UpdateScrollChildRect, scroll) end
        -- 3.8.2 : hauteur réelle (plus de vide en bas) : mesurée une fois la page posée
        After(0, function() Options.FitContent(u.box) end)
      end
    end
    if scroll.SetVerticalScroll then scroll:SetVerticalScroll(0) end
  end
  -- Hauteur du défilement = bas du dernier élément visible de la page (l'estimation par lignes
  -- surestimait les aides et laissait un grand vide sous les réglages).
  -- défilement maximal de la page affichée = hauteur du contenu - hauteur visible
  function Options.MaxScroll()
    local sc = Options.scroll
    if not (sc and sc.GetHeight and content.GetHeight) then return nil end
    local ch, vh = content:GetHeight(), sc:GetHeight()
    if not (ch and vh and vh > 0) then return nil end
    return math.max(0, ch - vh)
  end
  function Options.ClampScroll()
    local sc = Options.scroll
    local mx = Options.MaxScroll()
    if sc and mx and sc.GetVerticalScroll and sc:GetVerticalScroll() > mx then sc:SetVerticalScroll(mx) end
  end
  function Options.FitContent(box)
    Options.ClampScroll()
    if not (box and box.GetTop and box:IsShown()) then return end
    local top = box:GetTop()
    if not top then return end
    local low = top
    local function scan(list)
      for _, r in ipairs(list) do
        if r and r.IsShown and r:IsShown() and r.GetBottom then
          local b = r:GetBottom()
          if b and b < low then low = b end
        end
      end
    end
    scan({ box:GetChildren() })
    scan({ box:GetRegions() })
    local real = top - low
    if real > 20 then
      content:SetHeight(L.TITLE_H + real + L.MARGIN * 2)
      local sc = Options.scroll
      if sc and sc.UpdateScrollChildRect then pcall(sc.UpdateScrollChildRect, sc) end
      Options.ClampScroll()
    end
  end
  for i, sec in ipairs(order) do
    local tb2 = CreateFrame("Button", "DropamineOptTab_" .. sec.id, panel)
    tb2:SetSize(tabW - 2, 24)
    tb2:SetPoint("TOPLEFT", panel, "TOPLEFT", L.MARGIN + (i - 1) * tabW, -54)
    tb2.fs = tb2:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tb2.fs:SetPoint("CENTER", tb2, "CENTER", 0, 1)
    tb2.fs:SetText(Tr[sec.tab or sec.title])
    tb2.line = tb2:CreateTexture(nil, "ARTWORK")
    tb2.line:SetColorTexture(1, 0.82, 0, 0.9)
    tb2.line:SetPoint("BOTTOMLEFT", tb2, "BOTTOMLEFT", 2, 0)
    tb2.line:SetPoint("BOTTOMRIGHT", tb2, "BOTTOMRIGHT", -2, 0)
    tb2.line:SetHeight(2)
    tb2:SetScript("OnClick", function() Options.SelectTab(sec.id) end)
    tb2:SetScript("OnEnter", function(self) if Options._tab ~= sec.id then self.fs:SetTextColor(1, 1, 1) end end)
    tb2:SetScript("OnLeave", function(self) if Options._tab ~= sec.id then self.fs:SetTextColor(0.75, 0.72, 0.65) end end)
    Options.tabs[sec.id] = tb2
  end
  local sep = panel:CreateTexture(nil, "ARTWORK")
  sep:SetColorTexture(1, 1, 1, 0.12)
  sep:SetPoint("TOPLEFT", panel, "TOPLEFT", L.MARGIN, -78)
  sep:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -L.MARGIN, -78)
  sep:SetHeight(1)
  Options.SelectTab(Options._tab or (order[1] and order[1].id))
  panel:SetScript("OnShow", function()
    Options.Sync()
    Options.EnsurePreviewVisible()
    -- la page n'a de position qu'une fois affichée : mesurer sa vraie hauteur à ce moment
    local u = Options.secUI[Options._tab or ""]
    if u then After(0, function() Options.FitContent(u.box) end) end
  end)
  panel:SetScript("OnHide", function()
    Options.EndPreview()
  end)
  Options.panel = panel
  Options.height = y + 52
  return panel
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
    ns.Print(Tr["animation : son "] .. (v and Tr["activé"] or Tr["désactivé"]) .. (kit and (" (" .. tostring(name) .. ")") or Tr[" (aucun son natif trouvé : rien ne sera joué)"]) .. ".")
  elseif sub == "test" then
    if ns.UI and ns.UI.PlayLevelUp then ns.UI:PlayLevelUp(ns.GetPlayerLevel()) end
  else
    local v = Options.Set("levelUpAnim", ns.ParseOnOff(sub, ns.Opt("levelUpAnim")))
    ns.Print(Tr["animation de montée de niveau "] .. (v and Tr["activée."] or Tr["désactivée."]))
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
        if t and rec then any = true ns.Print(ns.CatalogDisplayName(e) .. " — " .. t:gsub("\n", " · ")) end
      end
    end
    if not any then ns.Print(Tr["recettes : aucune fenêtre de métier lue pour l'instant (lecture automatique à l'ouverture du métier)."]) end
    return
  end
  local v = Options.Set("craftNotify", ns.ParseOnOff(sub, ns.Opt("craftNotify")))
  ns.Print(Tr["drop « recettes réalisables » "] .. (v and Tr["activé."] or Tr["désactivé."]))
end
ns.HelpExt[#ns.HelpExt + 1] = "/drop recettes [on|off] : recettes réalisables avec tes sacs (tous les métiers de fabrication)"
ns.SlashExt.options = function(rest)
  rest = (rest or ""):lower()
  if rest == "defaut" or rest == "défaut" or rest == "reset" then
    ns.Print(Tr["options : "] .. Options.ResetDefaults() .. Tr[" réglages remis par défaut."])
    return
  end
  Options.Open()
end
-- 3.3.8 : commandes des nouveaux réglages (miroir exact du panneau)
local function onoff(key, label)
  return function(rest)
    local v = Options.Set(key, ns.ParseOnOff((rest or ""):match("^%s*(%S*)"), Options.Get(key)))
    ns.Print(Tr[label] .. Tr[" : "] .. (v and Tr["activé."] or Tr["désactivé."]))
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
  ns.Print(Tr["infobulle de créature : "] .. (v and Tr["compacte (Maj = détail)."] or Tr["détaillée."]))
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
