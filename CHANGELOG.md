# Changelog

## 3.6.2
- Weapon skill tooltips (tile and native skill list row): hit, crit and glancing values are back, in a short two-tone block ("Hit & crit (same lvl): 4.04% · 5.00%", boss line, "Glancing: 40% · -35% dmg"). The values are read from the game's skill detail pane, never computed; lines that cannot be read are left out. Root cause: the pane reader had been stubbed since 3.2.0, and cached values were looked up under the wrong key (and EN headers were not recognised). The parser now works by position, so colour-split text (Polearms, Feral Combat) reads correctly. The native description is no longer shown twice.
- New **Rested XP animation** on the Level tile (Options › Display, on by default): white-blue z's with a dark shadow (1, 2 or 3 depending on rested XP) only while you are resting, and a translucent blue liquid that fills the portrait up to rested / 1.5 levels, with a clearly visible wave while it is recharging at an inn or in a city; as soon as you leave the rest area it fades (0.8 s) to a light, almost still liquid. Hidden at max level, in combat, in quiet mode or when the option is off. The z's go away when you leave the rest area (events plus a 2 s check that stops on its own when the panel is hidden).
- Level tooltip: "Rested XP: 12,345 (45% of a level)", replacing the old rested line (no duplicate).
- Level tile: the liquid is drawn inside the portrait, under its frame, and clipped by the theme mask, so it no longer spills over the top or bottom of the tile, in all themes and layouts. The z's stay in the portrait's corner.
- Progress window: gridlines and axis labels no longer appear below the window. The scale comes from the actual maximum (for example +98 / +31 / +3) and no longer overwrites the chart's top margin after the first redraw. The chart is clipped to its frame.
- Progress window: the empty-chart and empty-curve messages wrap on 2 lines inside their card instead of overflowing on the right.

---

- Infobulles des armes (case et ligne de la liste native des compétences) : les valeurs de toucher, crit et coups déviés sont de retour, en un bloc court bicolore (« Toucher & crit (même niv.) : 4,04 % · 5,00 % », ligne boss, « Coups déviés : 40 % · -35 % dégâts »). Les valeurs sont lues dans le volet de détail du jeu, jamais calculées ; une ligne illisible est omise. Cause : la lecture du volet était neutralisée depuis la 3.2.0, et les valeurs étaient cherchées sous la mauvaise clé (en-têtes anglais non reconnus). Le parseur travaille désormais par position : le texte découpé par couleurs (Armes d'hast, Combat farouche) est bien lu. La description native n'apparaît plus en double.
- Nouvelle **animation XP de repos** sur la case Niveau (Options › Affichage, active par défaut) : des z blanc bleuté ombrés (1, 2 ou 3 selon l'XP de repos) seulement quand tu te reposes, et un liquide bleu translucide qui remplit le portrait jusqu'à repos / 1,5 niveau, avec une vague bien visible pendant qu'il se recharge à l'auberge ou en ville ; dès que tu sors de la zone de repos, il passe en fondu (0,8 s) à un liquide léger, presque immobile. Caché au niveau maximum, en combat, en mode calme ou si l'option est décochée. Les z disparaissent en quittant la zone de repos (événements + contrôle toutes les 2 s, qui s'arrête de lui-même quand le panneau est caché).
- Infobulle du Niveau : « XP de repos : 12 345 (45 % d'un niveau) », à la place de l'ancienne ligne (pas de doublon).
- Case Niveau : le liquide est dessiné dans le portrait, sous son cadre, et découpé par le masque du thème : il ne déborde plus en haut ni en bas de la case, dans tous les thèmes et dispositions. Les z restent dans le coin du portrait.
- Fenêtre Progression : les lignes de graduation et leurs libellés ne s'affichent plus sous la fenêtre. L'échelle vient du vrai maximum (ex. +98 / +31 / +3) et n'écrase plus la marge haute du graphe après le premier rendu. Le graphe est découpé à son cadre.
- Fenêtre Progression : les messages « aucune donnée » du graphe et de la courbe passent sur 2 lignes dans leur carte au lieu de déborder à droite.

## 3.6.1
- Wide (bar) layout: the total row (flask, "total / max" text and bar) no longer turns white on hover or click. The square tile keeps its usual hover highlight.
- Progress window: the chart title ("7-day progress" / "30-day progress") is fitted to the space and no longer clipped; the records line ("Best session +X · Best hour +X") no longer gets cut off and switches to a short form ("Sess. +X · Hour +X") when space is tight.
- Progress window: chart labels stay inside the frame (right margin, first and last day labels aligned with the edges).

---

- Format allongé (barre) : la rangée du total (fiole, texte « total / max » et barre) ne blanchit plus au survol ni au clic. La case carrée garde sa surbrillance habituelle au survol.
- Fenêtre Progression : le titre du graphe (« Progression sur 7 jours » / « sur 30 jours ») s'ajuste à la place et n'est plus coupé ; la ligne des records (« Max session +X · Max heure +X ») n'est plus rognée et passe en version courte (« Sess. +X · Heure +X ») quand la place manque.
- Fenêtre Progression : les libellés du graphe restent dans le cadre (marge à droite, premier et dernier jour alignés sur les bords).

## 3.6.0
- New **Progress window** (ProgressUI.lua): left-click the flask / total tile (Compact and UI views), the total-level bar (Wide view) or the total banner, or type /drop progress (also /drop progression). The window can be dragged, stays on screen, and closes with the X or Escape. It follows the Flare, Light and Classic themes.
- Header with the flask, your name, class and level, and a **Share** button. Share puts your session recap in the chat input box; nothing is sent until you press Enter. Under it, a total banner (total / max) with the same 3-segment bar as the Wide view (level, weapons & defense, professions, with the same minimum widths) and one badge per category.
- **Overview** tab: 4 cards (XP pace and time to next level, points pace, streak and records, session goal with +5 / +10 / Edit). A 7-day / 30-day / session bar chart with Total / XP/h / Categories views, a session curve (XP/h and pts/h) with the session top 4, your latest achievement and your current best farm spot.
- **Charts** tab: a larger chart. Click a bar for that day's skill-by-skill details, or click a skill to chart it alone.
- **Achievements (N/18)** tab: unlocked achievements in gold with their date; locked ones are muted, with a progress bar.
- **Farm spots** tab: zone / profession / points / pace (min per point), fastest first, with an empty-state message.
- **Weekly recap** tab: Monday–Sunday total, comparison with last week, split by category, best day, streak, day-by-day chart and top skills of the week.
- Total tooltip (Compact, Wide, UI banner): a 7-day mini chart under the tooltip, with day initials and daily points. It hides with the tooltip, never takes the mouse and never stays on screen.
- Options › Progress: new **Open window** button. /drop stats is unchanged; /drop progress text still prints the summary in chat; /drop progress achievements | spots | week opens that tab.
- Also in 3.6.0: the next-point bar resets to 0% on each point and hides in combat; AtlasLoot compatibility safeguards keep the panel from closing or opening off-screen; Edit Mode follows the Settings 2.0 sections; quiet mode in dungeons and groups; per-character display profiles; session goal, daily streak, 18 achievements, gathering spots by zone, weekly recap and /drop share.
- Safe in combat: the Progress window is never built in combat (it opens once combat ends), refreshes are throttled (0.5 s / 2 s in combat for Progress; 0.1 s / 0.5 s combat / 1 s raid for the main panel), and only textures and font strings are used (no CreateLine). All new texts are localized (FR/EN).

---

- Nouvelle **fenêtre Progression** (ProgressUI.lua) : clic gauche sur la fiole / case du total (vues Compacte et UI), sur la barre de niveau total (vue Wide) ou sur le bandeau du total, ou /drop progression (aussi /drop progress). La fenêtre se déplace, reste dans l'écran et se ferme avec le X ou Échap. Elle suit les thèmes Flare, Léger et Classique.
- En-tête avec la fiole, ton nom, ta classe et ton niveau, et un bouton **Partager**. Partager pose le récap de ta session dans la zone de saisie du chat ; rien n'est envoyé tant que tu n'appuies pas sur Entrée. Dessous, un bandeau du total (total / max) avec la même barre 3 segments que la vue Wide (niveau, armes & défense, métiers, mêmes largeurs minimales) et un badge par catégorie.
- Onglet **Vue d'ensemble** : 4 cartes (rythme XP et temps jusqu'au niveau suivant, rythme de points, série et records, objectif de session avec +5 / +10 / Éditer). Un histogramme 7 jours / 30 jours / session en vues Total / XP/h / Catégories, une courbe de session (XP/h et pts/h) avec le top 4 de la session, ton dernier succès et ton meilleur spot de farm actuel.
- Onglet **Graphiques** : un graphique plus grand. Clic sur une barre pour le détail compétence par compétence de ce jour, ou clic sur une compétence pour la tracer seule.
- Onglet **Succès (N/18)** : succès débloqués en or avec leur date ; les verrouillés sont atténués, avec une barre de progression.
- Onglet **Spots de farm** : zone / métier / points / rythme (min par point), du plus rapide au plus lent, avec un message quand c'est vide.
- Onglet **Récap hebdo** : total du lundi au dimanche, comparaison avec la semaine passée, répartition par catégorie, meilleur jour, série, histogramme jour par jour et top des compétences de la semaine.
- Infobulle du total (Compacte, Wide, bandeau UI) : un mini-graphe 7 jours sous l'infobulle, avec les initiales des jours et les points du jour. Il se cache avec l'infobulle, ne prend jamais la souris et ne reste jamais à l'écran.
- Réglages › Progression : nouveau bouton **Ouvrir la fenêtre**. /drop stats ne change pas ; /drop progression texte affiche toujours le résumé dans le chat ; /drop progression succes | spots | semaine ouvre l'onglet voulu.
- Aussi en 3.6.0 : la barre du prochain point repart à 0 % à chaque point et se cache en combat ; garde-fous de compatibilité AtlasLoot (position hors écran ignorée, réouverture propre) ; le mode Édition suit les sections des Réglages 2.0 ; mode discret en donjon et en groupe ; profils d'affichage par personnage ; objectif de session, série quotidienne, 18 succès, spots de récolte par zone, récap hebdomadaire et /drop share.
- Sûr en combat : la fenêtre Progression n'est jamais construite en combat (elle s'ouvre dès la sortie de combat), les rafraîchissements sont regroupés (0,5 s / 2 s en combat pour Progression ; 0,1 s / 0,5 s combat / 1 s raid pour le panneau principal), et seules des textures et des textes sont utilisés (pas de CreateLine). Tous les nouveaux textes sont traduits (FR/EN).


## 3.5.22
- Settings 2.0: the options panel now follows the native Classic look (like LayerSwap). Gold-bordered boxed sections are gone. Section titles are plain gold. Every label is left-aligned, tight against its control — no centered text and no wide fixed widths that left holes in the row.
- One family, one section, most-used first. **Display** gathers every look and transparency setting (theme, language, columns, size, idle transparency, hover background, fade delay, number color, total-level bar, next-point bar, lock). Then **Notifications & toasts**, **Sounds**, **Professions & highlighting**, and **Advanced** (including PvP). Existing settings, /drop commands and SavedVariables keys are unchanged.
- Live preview: while the options panel is open, changing the theme, size or transparency shows and updates the Dropamine panel immediately. In combat the preview waits until you leave combat, and never touches protected frames.
- A **Test** button next to sound and notification settings plays the sound or shows a sample toast, even if that option is still off.
- Each section has its own **Reset**, in addition to the global Defaults button (two-click confirm, language is never reset).

---

- Réglages 2.0 : le panneau d'options reprend le look natif Classic (façon LayerSwap). Plus d'encadrés à bord doré. Les titres de section sont simplement en or. Tous les libellés sont alignés à gauche, collés à leur contrôle — plus de texte centré ni de largeurs fixes qui laissaient des trous.
- Une famille, une section, les plus utilisés en premier. **Affichage** rassemble tous les réglages d'apparence et de transparence (thème, langue, colonnes, taille, transparence au repos, fond au survol, délai avant repos, couleur des chiffres, barre de niveau total, barre du prochain point, verrou). Puis **Notifications et toasts**, **Sons**, **Métiers & surlignage**, et **Avancé** (y compris le JcJ). Les réglages, les commandes /drop et les clés de sauvegarde restent les mêmes.
- Aperçu en direct : tant que les options sont ouvertes, changer le thème, la taille ou la transparence affiche et met à jour le panneau Dropamine tout de suite. En combat, l'aperçu attend la sortie de combat et ne touche jamais un cadre protégé.
- Un bouton **Tester** à côté des sons et des notifications joue le son ou montre un toast d'exemple, même si l'option est encore décochée.
- Chaque section a son propre **Réinitialiser**, en plus du bouton général Valeurs par défaut (confirmation en deux clics, la langue n'est jamais remise à zéro).


## 3.5.21
- Total-level bar: the fill now sits cleanly flush inside the frame on every theme, with per-theme insets, so the Flare rounded corners no longer hide the red (character level) segment or leave a dark gap before it. Flare / Light: 1 px inset all around. Classic: 3 px left and right, 1 px top and bottom.
- The red character-level segment scales its minimum visible width by level (1 px at levels 1–15, 2 px at 16–30, 3 px at 31–45, 4 px at 46–59, 5 px at 60), while weapons/defense (blue) and professions (green) keep a 5 px minimum when non-zero.
- The skills panel (tiles and total-level bar) now updates live in combat. Only protected-frame operations (SetPoint / Show / Hide / SetFrameLevel, opening the native SkillFrame) are deferred until combat ends. FontString text, bar fills and textures on already-laid-out tiles refresh immediately. Unreadable secret values keep the last known rank / level / XP so the grid does not drop to 0.

---

- Barre de niveau total : le remplissage démarre collé au bord intérieur du cadre sur les trois thèmes (marge de 1 px tout autour sur Flare / Léger ; 3 px gauche/droite et 1 px haut/bas sur Classique) pour garder le segment rouge du niveau bien visible sans trou noir avant lui.
- Le segment rouge adapte sa largeur minimale au niveau (1 px du 1 au 15, 2 px du 16 au 30, 3 px du 31 au 45, 4 px du 46 au 59, 5 px au niveau 60), tandis que les armes/défense (bleu) et les métiers (vert) gardent 5 px minimum.
- Le panneau des compétences (cases et barre de niveau total) se met maintenant à jour en combat. Seules les opérations sur les cadres protégés (SetPoint / Show / Hide / SetFrameLevel, ouverture de la fenêtre native) attendent la fin du combat. Les textes, le remplissage des jauges et les textures des cases déjà posées sont rafraîchis tout de suite. Une valeur secrète illisible garde le dernier rang / niveau / XP connu, pour que la grille ne retombe pas à 0.

## 3.5.20
- In-game logo updated to "La Fiole": the minimap button, the addon-list icon (IconTexture), the character skills tab, the total-level tile, the session recap toast and the classic view toggle now use the new flask instead of the old drop / three pillars.
- Textures: Media/Dropamine-Icon.tga is now 128×128 (detailed master, addon list); Media/SkillsTab.tga and SkillsTab.png are 64×64 (simplified master, in-game uses); new Media/Dropamine-Icon-32.tga (32×32, minimap fallback); Media/Dropamine-Logo.png is the 512×512 detailed flask. All TGA files are 32-bit uncompressed, power-of-two, with alpha.
- The flask is drawn with its own transparency: no 8% crop and no round mask on the minimap / total-bar icon, so the tip of the vial is not cut off.

---

- Logo en jeu mis à jour : « La Fiole ». Le bouton de minicarte, l'icône de la liste d'addons (IconTexture), l'onglet Compétences, la case de niveau total, le toast de récap de session et le basculeur de vue classique utilisent maintenant la nouvelle fiole, à la place de l'ancienne goutte / des trois piliers.
- Textures : Media/Dropamine-Icon.tga passe en 128×128 (master détaillé, liste d'addons) ; Media/SkillsTab.tga et SkillsTab.png font 64×64 (master simplifié, usages en jeu) ; nouveau Media/Dropamine-Icon-32.tga (32×32, repli de la minicarte) ; Media/Dropamine-Logo.png est la fiole détaillée en 512×512. Tous les TGA sont 32 bits non compressés, en puissance de 2, avec alpha.
- La fiole est dessinée avec sa propre transparence : plus de recadrage de 8 % ni de masque rond sur l'icône de minicarte / barre total, pour ne pas couper la pointe de la fiole.

## 3.5.19
- All of the addon's own texts now follow the game language: toasts, tooltips, panel and tile labels, session recap, chat messages, /drop help and the options panel. French client → French (word for word as before); English client (enUS / enGB) → English; any other client language → English.
- New setting "Language" (Options › Display & theme) and command /drop lang auto|en|fr (also /drop langue). Saved per account (DropamineDB.ui.lang), "auto" by default; "Defaults" does not reset it. After a change, a popup offers /reload so texts already on screen are translated too.
- Locale tables: Locales/enUS.lua and Locales/frFR.lua (key = original French text, missing keys fall back to French text). 868 texts translated + 39 skill names of the catalog (tiles such as "Skinning", "Two-Handed Swords", "Total level").
- Names given by the game (professions, skills, items, recipes, creatures read from the client) stay exactly as the client returns them. Recipe and item names from the addon's own Forever database follow the client language (English names on non-French clients).
- English aliases for commands, French ones still work: /drop columns, size, opacity, lock, alerts, activity, recipes, links, unlearned, tooltip, open, tiers, reminder, bar, challenge, sounds, sound, fade, bg, pretier, history, milestones, fishing, shopping, share, master, weapon; arguments light, green, yellow, tier, above, below, detach, up, down, full, skill, duration, icons, compact, default, main…
- Parsing of game messages uses the client's own templates first (ERR_SKILL_UP_SI for skill-ups, LOOT_ITEM_SELF / LOOT_ITEM_PUSHED_SELF for loot, ITEM_MIN_SKILL for "Requires Mining (75)"), then the built-in French / English patterns as before.
- Decimal comma only in French (K/D 2,5 / K/D 2.5; character stats).
- /drop debug reports and /drop perf stay in French (developer diagnostics).

---

- Tous les textes propres à l'addon suivent maintenant la langue du jeu : toasts, infobulles, libellés du panneau et des cases, récap de session, messages dans le chat, aide /drop et panneau d'options. Client français → français (mot pour mot comme avant) ; client anglais (enUS / enGB) → anglais ; toute autre langue du client → anglais.
- Nouveau réglage « Langue » (Options › Affichage & thème) et commande /drop lang auto|en|fr (aussi /drop langue). Enregistré par compte (DropamineDB.ui.lang), « auto » par défaut ; « Valeurs par défaut » ne le change pas. Après un changement, une fenêtre propose /reload pour traduire aussi les textes déjà affichés.
- Tables de langue : Locales/enUS.lua et Locales/frFR.lua (clé = texte français d'origine, clé absente → texte français). 868 textes traduits + 39 noms de compétences du catalogue (cases « Skinning », « Two-Handed Swords », « Total level »…).
- Les noms donnés par le jeu (métiers, compétences, objets, recettes, créatures lus dans le client) restent exactement tels que le client les renvoie. Les noms de recettes et d'objets de la base Forever de l'addon suivent la langue du client (noms anglais hors client français).
- Alias anglais des commandes, les commandes françaises restent valables : /drop columns, size, opacity, lock, alerts, activity, recipes, links, unlearned, tooltip, open, tiers, reminder, bar, challenge, sounds, sound, fade, bg, pretier, history, milestones, fishing, shopping, share, master, weapon ; arguments light, green, yellow, tier, above, below, detach, up, down, full, skill, duration, icons, compact, default, main…
- La lecture des messages du jeu utilise d'abord les modèles du client (ERR_SKILL_UP_SI pour les montées de compétence, LOOT_ITEM_SELF / LOOT_ITEM_PUSHED_SELF pour le butin, ITEM_MIN_SKILL pour « Requiert Minage (75) »), puis les motifs français / anglais intégrés comme avant.
- Virgule décimale seulement en français (K/D 2,5 / K/D 2.5 ; caractéristiques).
- Les rapports /drop debug et /drop perf restent en français (diagnostic développeur).

## 3.5.18
- Fix: weapon skill toasts and tiles no longer show the red "?" icon. On Forever weapon skills have singular names ("Masse", "Hache", "Épée", "Dague", "Arc"…), which the catalog did not know (it only had "Masses", "Maces"…), so "Masse +5" fell back to the question mark. Every weapon skill now resolves by exact name (French and English, singular and plural, "à une main" / "one-handed", ’ or ' apostrophes, accents), then by skill line ID (Axes 44, Maces 54, Swords 43, Daggers 173, Bows 45…), then a generic weapon icon: never a "?" and never a blank weapon tile. Dual Wield ("Ambidextrie") has its own icon. All icons checked against the game's file list.
- Weapon skills matched by these names now also feed the melee / ranged tiles (rank of the right weapon).
- /drop debug: "Icônes des armes (3.5.18)" line, each weapon skill read with its skill line, resolved icon and how it was found.

---

- Correctif : les toasts et cases de compétences d'armes n'affichent plus l'icône « ? » rouge. Sur Forever, les compétences d'armes ont des noms au singulier (« Masse », « Hache », « Épée », « Dague », « Arc »…) que le catalogue ne connaissait pas (il n'avait que « Masses », « Maces »…) : « Masse +5 » retombait sur le point d'interrogation. Chaque compétence d'arme est maintenant trouvée par son nom exact (français et anglais, singulier et pluriel, « à une main » / « one-handed », apostrophes ’ ou ', accents), puis par l'identifiant de sa ligne de compétence (Haches 44, Masses 54, Épées 43, Dagues 173, Arcs 45…), puis une icône d'arme générique : jamais de « ? » ni de case d'arme vide. L'Ambidextrie a sa propre icône. Toutes les icônes vérifiées dans la liste des fichiers du jeu.
- Les compétences d'armes reconnues par ces noms alimentent aussi les cases Mêlée / Distance (rang de la bonne arme).
- /drop debug : ligne « Icônes des armes (3.5.18) », chaque compétence d'arme lue avec sa ligne de compétence, l'icône résolue et la façon dont elle a été trouvée.

## 3.5.17 (test build)
- Recipe toast click goes through a secure button: the game runs a macro calling the same function as its own "new recipe" alert, "/run ProfessionsUtil.OpenProfessionFrameToRecipe(<id>)". The ID is Forever's recipe ID, found by NAME in C_TradeSkillUI.GetAllRecipeIDs / GetRecipeInfo when the toast is created (profession window open) or when the toast is hovered, otherwise the toast's spell ID. The button's attributes are set out of combat only, on hover and again at the click. In combat: nothing happens and the toast stays.
- Removed: every insecure selection from the click path (C_TradeSkillUI.OpenRecipe, the verification loop, reading the Professions window). That loop was the likely cause of "Échec d'une action d'interface liée à un programme d'interface personnalisée".
- If ProfessionsUtil is missing, or with /drop toast off: the toast only opens the profession (secure spell), with no selection.
- On by default in this test build. /drop toast on|off.
- /drop debug: "clic toast sécurisé (3.5.17)" line (state, recipe name, resolved ID and its source, macro text, combat).
- 3.5.16 pixel-snap fixes kept.

---

- Le clic sur le toast de recette passe par un bouton sécurisé : le jeu exécute une macro qui appelle la même fonction que sa propre alerte « nouvelle recette », « /run ProfessionsUtil.OpenProfessionFrameToRecipe(<id>) ». L'identifiant est celui de la recette sur Forever, trouvé par le NOM dans C_TradeSkillUI.GetAllRecipeIDs / GetRecipeInfo à la création du toast (fenêtre du métier ouverte) ou au survol, sinon l'identifiant de sort du toast. Les attributs du bouton ne sont posés que hors combat, au survol puis au clic. En combat : rien, et le toast reste.
- Retiré : toute sélection non sécurisée du chemin du clic (C_TradeSkillUI.OpenRecipe, la boucle de vérification, la lecture de la fenêtre Métiers). Cette boucle était la cause probable de « Échec d'une action d'interface liée à un programme d'interface personnalisée ».
- Si ProfessionsUtil est absent, ou avec /drop toast off : le toast ouvre seulement le métier (sort sécurisé), sans sélection.
- Actif par défaut dans cette version de test. /drop toast on|off.
- /drop debug : ligne « clic toast sécurisé (3.5.17) » (état, nom de la recette, id résolu et sa provenance, texte de la macro, combat).
- Corrections au pixel de 3.5.16 conservées.

## 3.5.16
- Recipe toast click: the recipe is now found and checked by NAME. On Forever the Professions window uses a recipe ID different from the spell ID kept by the toast (e.g. 3763 vs 1229432 for "Ceinture élégante en cuir"): the recipe was selected on screen, but our ID check failed and OpenRecipe was called 5 times. Now: when the window is ready, C_TradeSkillUI.GetAllRecipeIDs / GetRecipeInfo find the recipe whose name matches the toast (then the toast's ID, then the crafted item); the recipe shown is read by name (rank "[1]" ignored); we stop as soon as it matches. The first call now waits until the recipe list has been filled (TRADE_SKILL_LIST_UPDATE + 0.25 s, or 1.2 s after the window is ready): before, it could leave before the list and the window stayed on the first recipe ("Tente du camp"). At most 2 tries, 0.35 s apart; far fewer protected calls, to avoid the "interface action failed" message. The toast keeps the recipe name. Every call protected, no writes to the game's frames.
- Main window no longer shifts by a pixel when a recipe toast appears: positions, list offset and size are rounded to whole pixels (PixelUtil at the effective scale); nothing is re-anchored or resized when nothing changed; if the window is anchored by another point than its top-left corner, that corner is put back after a size change; the saved position is stored in whole pixels. The room for the "N prêts" badge above the first row stays reserved once seen (remembered), so its appearance with a recipe toast no longer pushes the grid down.
- /drop debug: "sélection de recette (3.5.16)" line (name searched, toast ID, resolved ID, name shown, tries, result) and a count of top-left re-pins on the Layout line.

---

- Clic sur le toast de recette : la recette est maintenant trouvée et vérifiée par son NOM. Sur Forever, la fenêtre Métiers utilise un identifiant de recette différent de l'identifiant du sort retenu par le toast (ex. 3763 contre 1229432 pour « Ceinture élégante en cuir ») : la recette était bien sélectionnée à l'écran, mais notre vérification par identifiant échouait et OpenRecipe était appelé 5 fois. Désormais : fenêtre prête, C_TradeSkillUI.GetAllRecipeIDs / GetRecipeInfo trouvent la recette dont le nom correspond au toast (puis l'identifiant du toast, puis l'objet fabriqué) ; la recette affichée est lue par son nom (rang « [1] » ignoré) ; arrêt dès qu'elle correspond. Le premier appel attend maintenant que la liste des recettes soit remplie (TRADE_SKILL_LIST_UPDATE + 0,25 s, ou 1,2 s après que la fenêtre est prête) : avant, il pouvait partir avant la liste et la fenêtre restait sur la 1re recette (« Tente du camp »). 2 essais au plus, à 0,35 s d'écart ; beaucoup moins d'appels, pour éviter le message « Échec d'une action d'interface ». Le toast retient le nom de la recette. Chaque appel protégé, aucune écriture dans les cadres du jeu.
- La fenêtre principale ne se décale plus d'un pixel à l'apparition d'un toast de recette : positions, décalage de la liste et taille arrondis au pixel entier (PixelUtil à l'échelle effective) ; rien n'est ré-ancré ni redimensionné quand rien n'a changé ; si la fenêtre est ancrée par un autre point que son coin haut-gauche, ce coin est reposé après un changement de taille ; la position mémorisée est enregistrée en pixels entiers. La place de la pastille « N prêts » au-dessus de la 1re rangée reste réservée une fois vue (mémorisée) : son apparition avec un toast de recette ne pousse plus la grille vers le bas.
- /drop debug : ligne « sélection de recette (3.5.16) » (nom cherché, id du toast, id résolu, nom affiché, tentatives, résultat) et compteur de coin haut-gauche re-fixé sur la ligne Disposition.

## 3.5.15
- Toasts: text always fully readable. After a toast is created (and when its text is updated), every line is measured (GetUnboundedStringWidth, otherwise GetStringWidth). If a line is wider than the space available, it wraps onto 2 lines at most and the toast grows taller; the stack is laid out again. Width, style and fonts unchanged. Applies to every toast (skills, level, recipes, notifications). New file ToastFit.lua.
- "New spells" toast (even levels): shorter title, "Nouveaux sorts", body "Va voir ton maître de classe" (before: "Nouveaux sorts à apprendre  Va voir ton…", cut off).
- /drop debug: "Textes des toasts (3.5.15)" line (toasts measured, lines wrapped, lines still too long, last fit).

---

- Toasts : texte toujours lisible en entier. À la création d'un toast (et quand son texte change), chaque ligne est mesurée (GetUnboundedStringWidth, sinon GetStringWidth). Si elle dépasse la place disponible, elle passe à la ligne (2 lignes au plus) et le toast grandit en hauteur ; la pile est remise en place. Largeur, style et polices inchangés. Vaut pour tous les toasts (compétences, niveau, recettes, notifications). Nouveau fichier ToastFit.lua.
- Toast « nouveaux sorts » (niveaux pairs) : titre raccourci, « Nouveaux sorts », texte « Va voir ton maître de classe » (avant : « Nouveaux sorts à apprendre  Va voir ton… », coupé).
- /drop debug : ligne « Textes des toasts (3.5.15) » (toasts mesurés, lignes passées à la ligne, lignes encore trop longues, dernier ajustement).

## 3.5.14
- Recipe toast ("new recipe" / "N ready"): clicking it opens the profession window AND now selects the recipe on Forever's modern Professions window. Before, the selection was sent as soon as the window appeared, before the window had finished loading and picked its own default recipe, so ours was immediately overwritten.
- Now: wait until the window is shown on the right profession, C_TradeSkillUI.IsTradeSkillReady (when available) and the data source is stable, then a short delay; select with C_TradeSkillUI.OpenRecipe(recipeID) only (public API: the game's own code does the selection); check by reading the recipe shown, and retry a few times if needed.
- The toast now keeps the recipe ID (spell), not the crafted item. If the ID is not in the window's list: lookup by name, then by crafted item (GetRecipeSchematic outputItemID).
- No writes to the game's frames, no filters, no search box: the "Create" button stays safe (no taint).
- /drop debug: "sélection de recette (3.5.14)" line (recipe, recipeID and its source, OpenRecipe calls, game response, recipe shown, result, steps).

---

- Toast de recette (« nouvelle recette » / « N prêts ») : le clic ouvre la fenêtre du métier ET sélectionne maintenant la recette dans la fenêtre Métiers récente de Forever. Avant, la sélection partait dès l'apparition de la fenêtre, avant qu'elle ait fini de charger et choisi sa propre recette par défaut : la nôtre était aussitôt écrasée.
- Désormais : attente que la fenêtre soit affichée sur le bon métier, que C_TradeSkillUI.IsTradeSkillReady (s'il existe) le confirme et que les données soient stables, puis un court délai ; sélection par C_TradeSkillUI.OpenRecipe(recipeID) seulement (API publique : c'est le code du jeu qui sélectionne) ; vérification en lisant la recette affichée, quelques nouveaux essais si besoin.
- Le toast retient maintenant l'identifiant de la recette (sort), pas l'objet fabriqué. Si cet identifiant n'est pas dans la liste de la fenêtre : recherche par le nom, puis par l'objet fabriqué (GetRecipeSchematic outputItemID).
- Aucune écriture dans les cadres du jeu, aucun filtre, aucune zone de recherche : le bouton « Créer » reste sûr (aucune souillure).
- /drop debug : ligne « sélection de recette (3.5.14) » (recette, recipeID et sa provenance, appels à OpenRecipe, réponse du jeu, recette affichée, résultat, étapes).

## 3.5.13
- Window size kept when hiding / showing: the window was built with a frame scale equal to the saved size, while the size is carried by the tiles since 3.3.12: the two mechanisms could disagree and the window could come back to the default size after hiding and showing. Now the window is always built at frame scale 1 with the tiles at the saved size, and every show checks the saved size, columns and list width and restores them if anything changed them (top-left corner kept). The size is still saved as soon as you resize.
- Position kept: the "window back in view" repair no longer forgets the saved position when the window has no rectangle yet right after being shown; it first puts it back at the saved position, and only falls back to the screen centre if that position is itself off-screen.
- Skinning tile (and Herbalism, Fishing): skill lines read from the game, parent line first (before, the first line found could be a child line); the line list is rebuilt while it is empty; if a line does not open the right profession, the next one is tried (then 393 / 182 / 356). "Already open on this profession → close" now compares the profession name (parent or child). A quick double click no longer opens and then closes the window. The profession spell button (Smelting, etc.) left on another tile is put away when the tile's own secure button is placed: never two secure buttons at once.
- /drop debug: "Clics des cases (3.5.13)" line with the tile under the secure button, the profession spell button, the profession shown in the window and, for each gathering profession, the lines tried and the result; Layout line "taille mémorisée (3.5.13)".

---

- Taille de la fenêtre conservée en la masquant / affichant : la fenêtre était construite avec une échelle de cadre égale à la taille mémorisée, alors que la taille passe par les cases depuis 3.3.12 : les deux mécanismes pouvaient se contredire et la fenêtre revenir à la taille par défaut après masquer / afficher. Désormais la fenêtre est toujours construite à l'échelle 1 avec les cases à la taille mémorisée, et chaque affichage vérifie la taille, les colonnes et la largeur de liste mémorisées et les repose si quelque chose les a changées (coin haut-gauche conservé). La taille reste enregistrée dès le redimensionnement.
- Position conservée : la réparation « panneau remis en vue » n'oublie plus la position mémorisée quand la fenêtre n'a pas encore de rectangle juste après l'affichage ; elle la repose d'abord à la position mémorisée, et ne passe au centre de l'écran que si cette position est elle-même hors écran.
- Case Dépeçage (et Herboristerie, Pêche) : lignes de compétence lues dans le jeu, la ligne parente d'abord (avant : la première trouvée, parfois une ligne « enfant ») ; liste refaite tant qu'elle est vide ; si une ligne n'ouvre pas le bon métier, la suivante est essayée (puis 393 / 182 / 356). « Déjà ouverte sur ce métier → fermer » compare maintenant le nom du métier (parent ou enfant). Un double clic rapide n'ouvre plus puis ne referme plus la fenêtre. Le bouton de sort des métiers (Fondre, etc.) resté sur une autre case est rangé quand le bouton sécurisé de la case est posé : jamais deux boutons sécurisés à la fois.
- /drop debug : ligne « Clics des cases (3.5.13) » avec la case sous le bouton sécurisé, le bouton de sort des métiers, le métier affiché dans la fenêtre et, pour chaque métier de récolte, les lignes essayées et le résultat ; ligne Disposition « taille mémorisée (3.5.13) ».

## 3.5.12
- PvP, weapon (melee, ranged, feral) and Defense tiles: a click simply opens the Character frame. The game runs "/click CharacterMicroButton" through the secure button placed over the tile, out of combat. The search for and switching of the PvP / Skills tabs is removed (it did not work on Forever), along with its chat messages, the hooks on the sheet's tabs and the related debug lines. Tooltip: "Clic : fiche du personnage".
- Level tile: unchanged (opens or closes the Character frame).
- Gathering tiles (Skinning, Herbalism, Fishing): on Forever they have their own profession window. A click opens it (C_TradeSkillUI.OpenTradeSkill; skill line read from the game, otherwise 393 / 182 / 356) and closes it if it is already open. Fishing no longer casts. Tooltip: "Clic : ouvrir le métier". Crafting professions and Mining (Smelting) keep their secure spell button.
- "N prêts" badge: Skinning, Herbalism and Fishing are now included when their window has recipes (for example Skinning's "Chaise du camp").
- Still no taint: no ToggleCharacter, ShowUIPanel or spell cast from the addon's code; the secure button's settings are only changed out of combat.
- /drop debug: a single "Clics des cases (3.5.12)" line.

---

- Cases JcJ, armes (mêlée, distance, farouche) et Défense : un clic ouvre simplement la fiche du personnage. Le jeu exécute « /click CharacterMicroButton » par le bouton sécurisé posé sur la case, hors combat. La recherche et le changement des onglets JcJ / Compétences sont retirés (ils ne marchaient pas sur Forever), avec leurs messages dans le chat, les crochets sur les onglets de la fiche et les lignes de debug associées. Infobulle : « Clic : fiche du personnage ».
- Case Niveau : inchangée (ouvre ou ferme la fiche).
- Cases des métiers de récolte (Dépeçage, Herboristerie, Pêche) : sur Forever, elles ont leur propre fenêtre de métier. Un clic l'ouvre (C_TradeSkillUI.OpenTradeSkill ; ligne de compétence lue dans le jeu, sinon 393 / 182 / 356) et la referme si elle est déjà ouverte. La Pêche ne se lance plus. Infobulle : « Clic : ouvrir le métier ». Les métiers de fabrication et le Minage (Fondre) gardent leur bouton de sort sécurisé.
- Pastille « N prêts » : Dépeçage, Herboristerie et Pêche sont pris en compte quand leur fenêtre a des recettes (par exemple « Chaise du camp » au Dépeçage).
- Toujours aucune souillure : ni ToggleCharacter, ni ShowUIPanel, ni lancer de sort depuis le code de l'addon ; les réglages du bouton sécurisé ne changent que hors combat.
- /drop debug : une seule ligne « Clics des cases (3.5.12) ».

## 3.5.11
- Level tile: a click opens or closes the Character frame. The game itself runs "/click CharacterMicroButton" through a secure button placed over the tile on hover, out of combat.
- Fishing tile: a click casts Fishing (secure spell button; the localized spell name is read from its ID, otherwise "Pêche" / "Fishing").
- Weapon skill tiles (melee, ranged, feral) and Defense: a click opens the Character frame on its Skills tab, with the same secure macro as the PvP tab.
- PvP and Skills tabs are now recognised automatically, read-only and without running any game script: from their icon (honor icon = PvP; "jack of all trades" icon, otherwise the stats icon = Skills), their fields, the tooltip seen on hover or your own click (remembered). The macro can only click a tab that is, or contains, a named button. Otherwise the sheet opens and you click the tab yourself.
- Hint messages ("clique sur l'onglet…") are shown only once per session, no longer on every click.
- Tooltips only advertise clicks that work: "Clic : fiche du personnage", "Clic : pêcher", "Clic : onglet Compétences", and "Clic : ouvrir le métier" for professions with a window (Mining = Smelting). Skinning and Herbalism have no click action and show no click line.
- /drop debug: for each side tab, its icon, what it was recognised as and whether /click is possible, plus every named button under the Character frame.
- Still no taint: no ToggleCharacter, ShowUIPanel or spell cast from the addon's code; the secure buttons' settings are only changed out of combat.

---

- Case Niveau : un clic ouvre ou ferme la fiche du personnage. C'est le jeu qui exécute « /click CharacterMicroButton », par un bouton sécurisé posé sur la case au survol, hors combat.
- Case Pêche : un clic lance Pêche (bouton de sort sécurisé ; nom du sort lu par son identifiant, sinon « Pêche » / « Fishing »).
- Cases d'armes (mêlée, distance, farouche) et Défense : un clic ouvre la fiche sur l'onglet Compétences, avec la même macro sécurisée que l'onglet JcJ.
- Les onglets JcJ et Compétences sont maintenant reconnus automatiquement, en lecture seule et sans exécuter de script du jeu : par leur icône (icône honneur = JcJ ; icône « touche-à-tout », sinon l'icône statistiques = Compétences), leurs champs, l'infobulle vue au survol ou ton propre clic (retenu). La macro ne peut cliquer qu'un onglet qui est, ou contient, un bouton nommé. Sinon, la fiche s'ouvre et tu cliques toi-même sur l'onglet.
- Les messages d'aide (« clique sur l'onglet… ») ne s'affichent qu'une fois par session, plus à chaque clic.
- Les infobulles n'annoncent que les clics qui marchent : « Clic : fiche du personnage », « Clic : pêcher », « Clic : onglet Compétences », et « Clic : ouvrir le métier » pour les métiers qui ont une fenêtre (Minage = Fondre). Dépeçage et Herboristerie n'ont pas d'action au clic et n'affichent aucune ligne de clic.
- /drop debug : pour chaque onglet latéral, son icône, ce qu'il a été reconnu comme et si /click est possible, plus tous les boutons nommés sous la fiche.
- Toujours aucune souillure : ni ToggleCharacter, ni ShowUIPanel, ni lancer de sort depuis le code de l'addon ; les réglages des boutons sécurisés ne changent que hors combat.

## 3.5.10
- Fix (taint): the errors "attempt to compare a secret number value (execution tainted by 'Dropamine')" when pressing C or when the mouse leaves the player health bar came from 3.5.8, which opened the Character frame from the addon's own code. Fields written then (lockShow of the health bar) stayed tainted for the whole session. A /reload clears them, and since 3.5.9 the addon never opens the sheet itself.
- Audit: Dropamine no longer runs any script of the Character frame tabs. The PvP tab is no longer clicked by the addon, and its tooltip is no longer forced open. The tooltip is read passively when you hover a tab, and the tab is learned when you click it yourself; both are read-only hooks. That tab is remembered and then clicked by the secure macro when it is a named button. Otherwise the sheet opens and a short message asks you to click the PvP tab once.
- Audit result: no global or Blizzard function is replaced (only post-hooks), no SetScript on game frames, no SetCVar, no UIPanelWindows change, and the panel is never anchored to the Character frame (its position is only read).

---

- Correctif (souillure) : les erreurs « attempt to compare a secret number value (execution tainted by 'Dropamine') » en appuyant sur C ou en quittant la barre de vie du joueur venaient de la 3.5.8, qui ouvrait la fiche depuis le code de l'addon. Les champs écrits à ce moment-là (lockShow de la barre de vie) restaient souillés toute la session. Un /reload les efface, et depuis la 3.5.9 l'addon n'ouvre plus jamais la fiche lui-même.
- Audit : Dropamine n'exécute plus aucun script des onglets de la fiche. L'onglet JcJ n'est plus cliqué par l'addon et son infobulle n'est plus ouverte de force. L'infobulle est lue passivement au survol, et l'onglet est appris quand tu cliques toi-même dessus ; ce sont deux crochets en lecture seule. L'onglet est retenu, puis cliqué par la macro sécurisée s'il s'agit d'un bouton nommé. Sinon, la fiche s'ouvre et un court message te demande de cliquer une fois sur l'onglet JcJ.
- Résultat de l'audit : aucune globale ni fonction du jeu remplacée (seulement des post-crochets), aucun SetScript sur les cadres du jeu, aucun SetCVar, UIPanelWindows jamais modifié, et le panneau n'est jamais ancré à la fiche (sa position est seulement lue).

## 3.5.9
- Fix: clicking the PvP tile no longer triggers the Lua error "attempt to compare a secret number value (execution tainted by 'Dropamine')". The addon itself opened the Character frame (ToggleCharacter), which tainted the game's own opening code. The Character frame is now opened by the game: out of combat, hovering the PvP tile places a secure button over it that runs "/click CharacterMicroButton", then clicks the PvP tab when that tab is a named button. If the sheet is already open, only the tab is switched. With no secure way to open it, a short hint is shown: "ouvre la fiche (C), puis clique à nouveau sur la case JcJ".
- In combat: nothing is opened, just a short message.
- Review of every open path: no more ToggleCharacter, ShowUIPanel or spell cast from the addon's own code. Profession tiles and recipe toasts already use secure buttons, and the direct call into the Professions recipe list is removed (C_TradeSkillUI.OpenRecipe is kept).
- /drop debug: the "Onglet JcJ de la fiche" line shows the secure button, the tab used by /click and the last path taken.

---

- Correctif : un clic sur la case JcJ ne déclenche plus l'erreur Lua « attempt to compare a secret number value (execution tainted by 'Dropamine') ». L'addon ouvrait lui-même la fiche du personnage (ToggleCharacter), ce qui souillait l'ouverture du jeu. La fiche est maintenant ouverte par le jeu : hors combat, au survol de la case JcJ, un bouton sécurisé la recouvre et lance « /click CharacterMicroButton », puis clique sur l'onglet JcJ quand cet onglet est un bouton nommé. Si la fiche est déjà ouverte, seul l'onglet change. Sans moyen sécurisé de l'ouvrir, un court message s'affiche : « ouvre la fiche (C), puis clique à nouveau sur la case JcJ ».
- En combat : rien n'est ouvert, juste un court message.
- Revue de toutes les ouvertures : plus aucun ToggleCharacter, ShowUIPanel ni lancer de sort depuis le code de l'addon. Les cases de métier et les toasts de recette passent déjà par des boutons sécurisés, et l'appel direct à la liste des recettes de la fenêtre Métiers est retiré (C_TradeSkillUI.OpenRecipe est conservé).
- /drop debug : la ligne « Onglet JcJ de la fiche » indique le bouton sécurisé, l'onglet utilisé par /click et le dernier chemin suivi.

## 3.5.8
- Fix: the "N prêts" badge and the craftable recipes in profession tooltips are back on WoW Forever. Since 3.5.0 the profession window was only read through the old API (GetTradeSkillInfo), which this client does not have: nothing was read, so no badge, and the tooltip kept asking to open the profession window. Recipes are now read from the modern Professions window (C_TradeSkillUI): learned recipes, skill-up colour (grey when the game says it no longer gives points), required reagents and the craftable count. Windows of other players, guild or NPC crafting are ignored.
- Profession tiles ("Clic : ouvrir le métier") and recipe toasts: the modern Professions window is now recognised (no second cast that would close it), and the recipe is selected with the game's own C_TradeSkillUI.OpenRecipe.
- /drop debug: new "Lecture des métiers (3.5.8)" line (API used, last window read, result).

---

- Correctif : la pastille « N prêts » et les recettes réalisables dans les infobulles des métiers reviennent sur WoW Forever. Depuis la 3.5.0, la fenêtre du métier n'était lue que par l'ancienne API (GetTradeSkillInfo), absente de ce client : rien n'était lu, donc pas de pastille, et l'infobulle demandait sans fin d'ouvrir la fenêtre du métier. Les recettes sont maintenant lues dans la fenêtre Métiers moderne (C_TradeSkillUI) : recettes apprises, couleur de progression (gris quand le jeu dit qu'elle ne donne plus de points), composants obligatoires et nombre réalisable. Les fenêtres d'un autre joueur, de guilde ou d'un PNJ sont ignorées.
- Cases de métier (« Clic : ouvrir le métier ») et toasts de recette : la fenêtre Métiers moderne est reconnue (pas de second lancer qui la refermerait), et la recette est sélectionnée par la fonction du jeu C_TradeSkillUI.OpenRecipe.
- /drop debug : nouvelle ligne « Lecture des métiers (3.5.8) » (API utilisée, dernière fenêtre lue, résultat).

## 3.5.7
- Fix: clicking the PvP tile no longer says "fenêtre JcJ introuvable". On WoW Forever the PvP window (season, rank, rank points, rewards) is a tab of the Character frame. The click now opens the Character frame (it never closes it if it is already open) and selects its PvP tab. The tab is recognised by its text, its tooltip or, as a last resort, by trying each tab until the sheet's title shows "JcJ" or "points de rang" appears. The tab it finds is remembered for the session.
- In combat nothing is touched: a short message, and the tab opens when combat ends.
- /drop debug: new "Onglet JcJ de la fiche" section (tabs found, the tab chosen and how it was checked).

---

- Correctif : un clic sur la case JcJ ne répond plus « fenêtre JcJ introuvable ». Sur WoW Forever, la fenêtre JcJ (saison, rang, points de rang, récompenses) est un onglet de la fiche du personnage. Le clic ouvre maintenant la fiche (sans la refermer si elle est déjà ouverte) et choisit son onglet JcJ. L'onglet est reconnu par son texte, son infobulle ou, en dernier recours, en essayant chaque onglet jusqu'à ce que le titre de la fiche affiche « JcJ » ou que « points de rang » apparaisse. L'onglet trouvé est retenu pour la session.
- En combat, rien n'est touché : message court, l'onglet s'ouvre à la fin du combat.
- /drop debug : nouvelle section « Onglet JcJ de la fiche » (onglets trouvés, onglet retenu et comment il a été vérifié).

## 3.5.6
- Fix: the panel could stay invisible with /drop and the minimap button (no Lua error). Its default position was anchored to the Character frame, which has no position on screen until it has been opened once (or when another addon such as FlareUI or AtlasLoot moves or hides it). The panel is now always placed on the screen itself: next to the Character frame only when that frame is open, otherwise centred, and always kept on screen.
- Fix: a panel that was "open" but not actually visible is now opened again (and brought back into view) by the next click, instead of being closed.
- /drop debug: the "Ouverture protégée" line now shows whether the panel is on screen and what it is anchored to.

---

- Correctif : le panneau pouvait rester invisible avec /drop et le bouton de minicarte (sans erreur Lua). Sa place par défaut était ancrée sur la fiche du personnage, qui n'a aucune position à l'écran tant qu'elle n'a pas été ouverte une fois (ou quand un autre addon, FlareUI ou AtlasLoot, la déplace ou la cache). Le panneau est désormais toujours placé sur l'écran lui-même : à côté de la fiche seulement si elle est ouverte, sinon au centre, et toujours retenu à l'écran.
- Correctif : un panneau « ouvert » mais pas réellement visible est rouvert (et remis en vue) au clic suivant, au lieu d'être fermé.
- /drop debug : la ligne « Ouverture protégée » indique si le panneau est à l'écran et sur quoi il est ancré.

## 3.5.5
- Toasts de recette : « Clic : ouvrir la recette » fonctionne. Le clic ouvre la fenêtre du métier et sélectionne la recette (catégories repliées dépliées, filtres remis à « Tout » seulement si la recette restait cachée). Sélection en un seul passage borné : aucune boucle ouvre / ferme, jamais deux lancers du sort, rien sur une fenêtre déjà ouverte.
- Cases de métier : « Clic : ouvrir le métier » réactivé (désactivé en 3.5.0), mêmes garde-fous ; option /drop ouvrir on|off.
- Clics sécurisés compatibles avec le réglage « Action à l'appui de la touche » (ActionButtonUseKeyDown) des clients récents : c'est probablement ce qui rendait ces clics muets.
- Case JcJ : « Clic : fenêtre JcJ » essaie l'onglet Honneur puis les autres fenêtres JcJ, vérifie que l'une s'est ouverte, sinon le dit dans le chat ; en combat, ouverture à la fin du combat.
- Infobulles : retrait de « Clic : détail à droite » (plus de volet de détail) ; « Maj + clic : partager » n'apparaît que si l'option est active.
- Ouverture du panneau protégée (bouton de minicarte, /drop) : une erreur n'est plus muette (message dans le chat, détail dans /drop debug) et le panneau s'affiche quand même, remis en vue s'il était invisible ou hors écran. Vise le cas « le panneau ne s'ouvre pas avec AtlasLoot ».
- Bouton de minicarte : un glisser relâché hors du bouton n'avale plus le clic suivant.
- Correctif : /drop hit lisait une variable globale indéfinie.

## 3.5.4
- Records : plus d'enchaînement de « Nouveau record ! » à chaque point. Le record de session ne s'annonce qu'à des paliers croissants (25, 50, 100, 200…) et jamais sous 25 points ; le record horaire une seule fois par heure.
- Niveaux pairs : notif « Nouveaux sorts à apprendre » sous celle du level-up, avec un son.

## 3.5.3
- Performance : plus de micro-gels au survol (cases, barre, infobulles d'unité et d'objet).
- Rangs de compétence lus au plus une fois par seconde pour les infobulles (relus aussitôt après un gain, un niveau ou un changement d'équipement), au lieu d'une relecture complète à chaque ligne.
- Infobulle de case mémorisée (au plus un calcul par seconde, recalculée dès que la grille change).
- Infobulle de créature : mêmes lignes réutilisées pendant 1 s quand le jeu la rafraîchit.
- « À apprendre bientôt » et recettes apprises : résultats mémorisés au lieu d'être recalculés à chaque survol.
- Normalisation des noms mémorisée (des milliers de remplacements de texte en moins par infobulle).
- Passer d'une case à l'autre ne relance plus le repeint du panneau.
- Correctif : la lueur dorée du passage de niveau (toast et case Niveau) fait maintenant tout le tour, sur les 4 côtés, dans les 3 thèmes.

## 3.5.2
- Correctif : la barre Niveau total disparaissait au login alors que l'option était cochée.
- Correctif : erreur Lua « secret string » à l'ouverture de la fenêtre JcJ (textes protégés ignorés).


All notable changes to Dropamine (formerly OSRS Total Level) are documented here. The 3.3.x notes are taken from the addon's in-tree README and test headers. Command names below use `/drop` (also `/dropamine`).

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [3.5.1] — 2026-11-17

### Added
- **Segmented total-level bar.** The thin “Niveau total” gauge (all themes and layouts) is split into three sources, in native order: character level (muted red `#9D473A`), weapon skills + Defence including Feral Combat (muted blue `#54689A`), and professions, primary and secondary (muted green `#4F7F3E`). Colors are sampled from the three pillars of the total-level icon (`Media/SkillsTab`), desaturated ~40 %, slightly darkened, and warmed with a parchment-gold tint. Hovering the bar shows each source as points / max. No click action.
- **Toast direction in free position.** Edit mode → Notifications now adds “Sens des notifs”: Vers le haut (default when the toasts are freely placed — the newest stays at the anchor, older ones move up), Vers le bas (previous downward stack), and Sur place (a card pile at the anchor, 4 px up and right, at most 3 visible, slightly faded and darkened by depth). Saved in the profile (`dropDir`). Anchored above or below the panel is unchanged. `/drop drops sens haut|bas|place`.

## [3.5.0] — 2026-11-17

### Fixed
- **Profession windows no longer hitch when switching tabs.** `TRADE_SKILL_*`, `CRAFT_*` and frame `OnShow` hooks share one deferred job (`C_Timer.After` ~0.25 s, a single pending flag). Recipes are scanned only when the key (profession, recipe count, skill rank) changes, in batches of about 25 per frame. Tiles are repainted only when their highlight level actually changes. Nothing is scanned in combat, and the batch `OnUpdate` is cleared when the job ends. `/drop perf` reports scan count and milliseconds per scan.
- **Enemy players light up.** An honorable target (`UnitIsPlayer` or a `Player` GUID, `UnitIsEnemy` / `UnitCanAttack`, `UnitIsPVP` when that function exists, not a trivial level) turns the PvP tile green — subtle on target, strong while you are in combat with them. Equipped weapons and Defence follow the same rules as for creatures. Players are not treated as creatures (no skinning, loot or XP highlight; `UnitCreatureType` is nil). The nameplate marker is green when the player is worth honor, grey when the level is trivial.
- **Toast progress bar no longer runs under the round icon.** On every toast and in all three themes, the thin bar starts at the title’s left edge and ends at the same right inset as the text.
- **An open profession window highlights its tile only when a recipe can still gain a point.** If every visible recipe is grey, the green “window open” highlight stays off. Linked professions are unchanged. If the recipe list cannot be read, the previous behaviour is kept. The result is cached for one second.
- **The profession-tile spell button no longer flickers the tooltip.** Moving onto the secure button does not re-fire the tile’s `OnEnter`, and the tile’s `OnLeave` runs only when the pointer actually leaves the button.

### Added
- **Session combo.** Each skill point within 60 s of the previous raises a shown multiplier (x2, x3…). It steps down after you stop. The best combo is saved. `/drop combo`.
- **OSRS-style dings.** A short built-in sound on a skill point, another on a profession tier (75 / 150 / 225 / 300). No audio files are shipped. `/drop son point`, `/drop son palier`.
- **Max celebration.** A large golden animation when a profession or weapon skill reaches its maximum. `/drop max`, `/drop son max`.
- **Daily challenge.** One stable goal per day among the character’s skills (for example “+5 en Dépeçage”), progress in the tooltip, a visual reward once on completion. `/drop defi`.
- **Personal records.** Most points in a session and best hour, with a “Nouveau record !” toast. `/drop records`.
- **Next-point bar.** A thin bar under the active tile when a measured estimate exists. The `OnUpdate` runs only while that bar is showing, and not in combat. `/drop barre`.
- **Collection.** First-time skinned creature types and fished items, per character, with an “N découverts” line in the tooltip. `/drop collection`.
- **Master sound switch.** `/drop sons` gates every sound. Each sound has its own toggle, default off. Existing sound defaults (level-up, scanner) are unchanged.
- **Click a profession tile to open it** (out of combat). A secure spell button (`SecureActionButtonTemplate`, `type1` only) is placed at absolute coordinates over the hovered tile — First Aid, Cooking, Tailoring, Leatherworking, Blacksmithing, Engineering, Alchemy, Enchanting, and Mining (Smelting). The same click still selects the tile. Right-click and Shift-click are unchanged. In combat the click only selects. Tooltip: « Clic : ouvrir le métier ». Setting « Clic : ouvrir le métier » in Métiers (default on), `/drop ouvrir`.

## [3.4.3] — 2026-11-17

### Fixed
- **No profession highlight while crafting (First Aid window open, bandage being cast).** Most likely cause: on `TRADE_SKILL_SHOW` our handler ran before the game showed the window, and detection required `TradeSkillFrame:IsShown()`. Forever's profession UI may also be a different frame, and the recipe being cast was not in the recipe cache, so neither the window nor the cast was ever mapped. Detection now uses several independent sources. **Window:** `TRADE_SKILL_*` / `CRAFT_*` events (the open state is trusted from the event), `OnShow` / `OnHide` hooks on `TradeSkillFrame`, `CraftFrame` and `ProfessionsFrame` (also when loaded on demand), and a re-read one frame later. **Name:** `GetTradeSkillLine` / `C_TradeSkillUI`, then the window title, then the skill bar ("Secourisme 139/150"), matched to tile names. **Cast:** event args plus `UnitCastingInfo` / `UnitChannelInfo` (position-agnostic), recipe cache, `C_TradeSkillUI.GetTradeSkillLineForRecipe`, a trade-skill cast while the window is open, and finally the "Votre compétence en …" chat message (remembered for the session). Rendering goes through the same highlight path as combat. No text lookups in combat.

### Added
- `/drop debug` opens a copyable window (themed, scrollable, text pre-selected, Ctrl+C, Esc / ✕). Profession diagnostics come first (frames found / hooked, detected window, name source, last cast name + spellID, mapping source, tile and highlight state). `/drop debug metier` shows only that part. The chat now just says "Debug copié dans la fenêtre".

## [3.4.2] — 2026-11-17

### Removed
- **Micro-menu / floating launcher button** (`DropamineMicroButton`), by request: the minimap button is now the only button (it also works docked in a minimap button tray). Removed with it: its drag / snap code, the background segment drawn under it, the `/drop lanceur reset` command and help entries, and the 0.5 s micro-menu visibility check (no OnUpdate left while idle). The old saved `launcherPos` key is ignored and cleared on load; no other setting is touched. There were no launcher entries in the settings panel or Edit Mode.

### Changed
- Minimap button tooltip: “Niveau total : X / 2460”, then “Clic : ouvrir / fermer”. Look unchanged from 3.4.1.
- `/drop help` mentions the minimap button and `/drop minimap`; the panel lock message only mentions the panel.

## [3.4.1] — 2026-11-17

### Fixed
- **Launcher hover glow was offset upward.** Cause: the button still used the native micro-button highlight texture (`UI-MicroButton-Hilight`), whose glow is drawn for the tall native art, and the hit rect still covered the whole 28 × 58 button. The native highlight is now hidden (alpha 0, re-applied on every re-skin) and Dropamine draws its own hover/pressed states exactly on the square plate: Flare / Léger get a 1 px light edge + a faint additive veil; Classic uses the action-button hover (`ButtonHilight-Square`) on the icon and `UI-Quickslot-Depress` when pressed. Pressed darkens the icon in every theme. Same for the minimap button. `SetHitRectInsets` now limits hover/click to the plate.

## [3.4.0] — 2026-11-17 (pre-release)

### Fixed
- **Launcher icon poked out above its frame.** Cause: the icon was placed in the native Character micro-button *portrait* area (tall, high up) while the dark frame you see is the plate at the bottom of the native art. The launcher (and minimap button) now draws its own square plate (bottom-aligned, side = button width) and centres the icon in it with the same inset as the total-bar icon (3 px + 3 px bevel), in all three themes (Classic uses the action-button frame).
- **Fishing / Cooking tiles never turned green while fishing or cooking.** Cause: highlights only reacted to the target (`PLAYER_TARGET_CHANGED`); nothing listened to the player's own casts or to open profession windows.

### Added
- **Profession in progress** (`Activity.lua`): strong green on the profession tile while you cast or channel a profession action (`UNIT_SPELLCAST_START` / `CHANNEL_START`, player only) — fishing, any recipe (Cooking, First Aid, Tailoring…), herbing, mining, skinning. Mapping is locale-independent (spell IDs, then names read from the client via `GetSpellInfo` / `GetTradeSkillLine` / recipes read in game). Soft green when a fishing pole is equipped (`GetItemInfoInstant` class 2 / subclass 20) or the profession window is open. Option “Surligner le métier en cours”, `/drop activite on|off`.
- **Profession links**: while a profession window is open, supplier professions get a very light link highlight (First Aid ← Tailoring, Cooking ← Fishing, Leatherworking ← Skinning, Blacksmithing / Engineering ← Mining, Alchemy ← Herbalism, …) plus professions whose recipes read in game share a reagent (existing Links data). Details on tile hover only. Computed once per window, cached; no OnUpdate.

### Changed
- **Léger theme**: no outer frame or background at all (also re-hidden on fade, hover, reopen and re-skin). Flare and Classic unchanged.
- **Settings overhaul**: five groups — *Affichage & thème*, *Métiers & surlignage*, *JcJ*, *Notifications*, *Avancé* — with short labels and one help line per setting; rarely used options moved to *Avancé*; Edit Mode quick settings use the same groups. Saved-variable keys and slash commands are unchanged, so no setting is lost.
- **`/drop help`** is now short and grouped; `/drop help tout` prints every command. The dead `/drop drops sens|chat` entries are no longer advertised (the commands are still accepted).
- **Performance**: the launcher's 0.5 s visibility check is removed entirely when the launcher is free-floating.
- Edit Mode overlay / dialog title: “Dropamine”.

## [3.3.18] — 2026-11-17

### Changed
- Commands are now only `/drop` and `/dropamine`; the legacy aliases were removed.
- `Media/Flare/` renamed to `Media/Skin/` (the addon's own settings-window textures); paths updated.
- `.toc`: `## X-License: MIT`, `## IconTexture` pointing at `Media/Dropamine-Icon`, and a commented placeholder for `## X-Curse-Project-ID` (fill in once the CurseForge project exists).

## [3.3.17] — 2026-11-17

### Added
- Renamed the addon to **Dropamine**: folder `Dropamine/`, `Dropamine.toc`, saved variables `DropamineDB`. Settings are copied **once** from `OSRS_TotalLevelDB`; the old table is never modified. Chat prefix is now “Dropamine”. Commands: `/drop` and `/dropamine`.
- Third theme, **Classic** (`/drop theme classic`, also in options and Edit Mode): in-game Blizzard textures only, referenced by path — tooltip border, action-button frames (`UI-Quickslot2` / `UI-Quickslot-Depress`), outlined numbers, and a `UI-StatusBar` total. Default theme remains Flare.
- Original border art: `Media/Dropamine-Frame.tga` (and `Dropamine-Thin`, `Dropamine-Bar`) generated by `tools/make_frame_border.py`, matching the previous FlareUI-style edge (measured mean difference 0.04/255 on the rendered panel). No FlareUI image file remains in `Media/`.

### Changed
- “N ready” badge: small Flare-style plate (dark fill, 1 px bronze rule, 1 px shadow) placed fully in the 12 px gap above the tile — it no longer overlaps the tile, the tile above, or the panel edge. Panel margins 12 px.
- Tile numbers: large white rank, smaller dimmed “/max” (~78 %), shared crisp shadow, 4 px inset into the bevel; maxima ≥ 10 000 are abbreviated (`/25k`). A light dark gradient sits under the digits.
- Total-level bar: 8 px gauge (was 3 px) with a dark track, bronze fill, 1 px highlight and a thin bronze rule; icon and text vertically centred.

## [3.3.16] — 2026-11-17

### Changed
- Session recap now appears at the **start** of the logout / quit countdown (`PLAYER_CAMPING` / `PLAYER_QUITING`, plus safe hooks on Logout / Quit for an instant disconnect): a 20-second toast and a chat line. It is cleared on `LOGOUT_CANCEL`. Nothing is printed on `PLAYER_LOGOUT` (hidden by the loading screen). `/drop recap` and `/drop recap on|off` remain.
- Launcher and minimap button use the same cropped, masked SkillsTab art as the total bar, with a bevelled bronze edge that stays inside the button frame.
- The launcher is draggable again (the panel lock no longer freezes it). A click still toggles; the click at the end of a drag is ignored. Position is saved per account.
- Edit Mode no longer resets the panel to the default position. The saved position is reapplied on enter / leave and after each layout pass. Only “Reset to default position” moves it back.

## [3.3.15] — 2026-11-17

### Fixed
- Panel (and toast) borders no longer flash white: the bronze tint is reapplied after every `SetBackdrop` (including the 8-texture fallback), fade, theme change and resize. Default tooltip colours no longer touch the skin.
- On a new character, the first open no longer shows a scrollbar. Layout is rebuilt on login, entering the world, skill load, and the next frame.

### Changed
- Icon edge: 1 px bronze hairline, bevelled corners, outer black shadow, inner dark line, cropped icon. Target highlight (green) and selection (gold) recolour that same edge — no separate square stroke.
- Only skills of **equipped** weapons (main hand, off hand, ranged) light up, from the item subclass. Strong green while you are actually swinging / shooting; a quieter green when the target only qualifies. Same rules for Feral Combat (in form) and Defence (strong when the target hits you).
- Cat / bear form is detected from every available probe (shapeshift id, shapeshift bar, auras, resource type). In form, only Feral Combat and Defence light up.
- The “+1” sits in the top-left of the tile; the “N ready” badge sits above it — they no longer cover each other.

## [3.3.14] — 2026-11-16

### Changed
- One bronze token `#A67D45` for the panel, toasts, every tile (skills, total, PvP), badges and the total bar, in both themes of the time. Older 115/91/56 edges had looked grey.
- Target highlight: a 2 px green edge on top of the veil (visible on dark icons such as Cat Form). A selected tile gets a gold halo instead of blue.
- Defence lights up on any non-grey target, up to the character cap. The estimated 5 × target-level cap applies only to weapons and Feral Combat.
- The “/2460” label is no longer drawn on the total tile in bar mode.
- Nameplates: one icon per profession, including those linked by a recipe (e.g. Leatherworking on a skinnable beast). Green if a recipe would give a point, grey otherwise.
- Creature tooltip: one line per profession; a grey “grey recipes” line is omitted when a gain line already exists for that profession.

## [3.3.13] — 2026-11-16

### Added
- Two panel themes: **Flare** (default, Blizzard dark dialog fill + rounded `#A67D45` border, same opacity for panel and toasts) and **Léger** (no frame, floating tiles). `/drop theme flare|leger` (aliases `cadre` / `sans` still work). Classic arrives in 3.3.17.
- 3-column layout (`/drop colonnes 3`, also in the menu and with Alt-drag).
- Total-level tile hidden by default (`/drop total on` to show it). Alone on the last row, it becomes a full-width thin bar.
- Edit Mode: clicking the panel (or `/drop edit`) opens a quick-settings window (layout, size, look, notifications, fade, targets & gathering, PvP).
- Clickable recipe toasts: a click opens the profession and selects the recipe (queued if you are in combat).
- PvP module (`/drop pvp on|off`): a rank tile with the rank-point gauge, tooltip (honour, honourable kills today and this week, K/D, streak), a “+1 honourable victory” toast, green/grey markers on enemy player nameplates, and a daily-kills goal (right-click the tile).

### Changed
- Dynamic size: the handle, `/drop taille 50-200` and the slider resize tiles, gaps and text. The border keeps its native thickness (no `SetScale`).

### Fixed
- Feral Combat correctly turns green in cat or bear form (lookup key mismatch).
- `/drop alertes` with no argument, and the “Target alerts” checkbox, actually turn alerts off.

## [3.3.12] — 2026-11-16

### Changed
- The bottom-right handle now changes size only, continuously (1 % steps, 50–200 %), top-left corner fixed. It no longer changes the column count.
- Columns are set with `/drop colonnes 1|2|5|10`, the options list, or **Alt-drag** on the handle. `/drop taille` accepts any integer 50–200.

## [3.3.11] — 2026-11-16

### Changed
- Panel and toasts used the default game tooltip border (later replaced by the Flare / Dropamine border). At rest, only the fill and whole-panel opacity dim; the edge is no longer faded on its own.
- Top margin grows when a “N ready” badge sits on the first row, so the badge no longer covers the frame.

## [3.3.10] — 2026-11-16

### Added
- `/drop theme cadre|sans` (later renamed flare / leger): frameless mode with floating tiles and handles only on hover.

### Changed
- Unified tiles in both themes: 1 px bronze edge, rounded icon, light shadow. “N ready” badge sits above the top edge (8 px row gap) so it no longer covers the numbers.
- The handle resized and changed columns; the panel can be dragged from anywhere, including tiles, without eating a click.
- Toasts share the panel fill, border and fade. Border tint is no longer read back from the game tooltip (which turned red after hovering an enemy).
- Grey targets (observed on Forever): weapons and Feral Combat still go up (only the 5 × level cap remains); Defence and character XP do not.

### Fixed
- Confirming an objective (right-click) no longer errors `View.lua:467 … field 'h'`.

## [3.3.9] — 2026-11-16

### Changed
- Panel and toast borders used the game tooltip NineSlice (later replaced). Cleaner digits and badges (thin 1 px shadow, bronze hairline, no heavy outline).
- Stronger druid-form detection; a combat tile that stays dark explains why on hover.

## [3.3.8] — 2026-11-16

### Added
- Profession links (`/drop liens`), unlearned-recipe display (`/drop nonapprises`), and `/drop animation`.
- Creature tooltip: up to three profession lines; hold Shift for detail (`/drop infobulle compacte|detail`).
- A single nameplate marker, centred above the name: one icon per profession, green if a +1 is possible, grey otherwise.
- `/drop fond <0-100>` (default 45 %) and `/drop options defaut`.

### Changed
- Equal margins on all four sides; ranks drawn inside the tiles; “N ready” badge centred.
- In cat / bear form only Feral Combat and Defence light up, never the weapon skill; in caster form, the weapon does.
- Options reordered: Display, Notifications, Targets & gathering, Professions, Tile tooltip & reminders.

## [3.3.4] — 2026-11-16

### Changed
- Mid-3.3.x compact-panel iteration (3.3.5–3.3.7 test headers cover GUID matching, tooltip frame, 1/2/5/10-column layouts, toasts anchored to the panel, target highlight, damage-meter-style fade, split rank font strings, and gather alerts).

## [3.3.3] — 2026-11-16

### Added
- Escape collapses the detail view.
- Opacity of the background and frame (`/drop opacite 0-100`); optional icon opacity.
- Panel lock (`/drop verrou`).
- Launcher docks in Forever’s vertical micro-menu column (under “?”); drag to move, `/drop lanceur reset` to snap back.
- Rank on two lines inside the tile; character portrait on the Level tile.

## [3.3.2] — 2026-11-16

### Added
- Micro-menu button (three RGB pillars) and a matching minimap button. No native button is moved.
- Single compact OSRS-style grid (Level, melee, class combat, Defence, professions, Cooking, Fishing, First Aid) with Total Level at the bottom. Hidden `/drop categories on` restores section headers.
- Rank shown as current/max on each tile.

## [3.3.1] — 2026-11-16

### Changed
- Three-pillar icon drawn by the addon itself (no third-party art).

## [3.3.0] — 2026-11-16

### Added
- Icon-only skill grid in a window drawn entirely by the addon. Hover for the tooltip; click a tile for the full detail. The native Skills tab is left untouched.

### Notes
Versions 3.2.0 and earlier shipped under the name OSRS Total Level (standalone window, then an earlier attempt to restyle the native Skills tab). See older zips and the historical in-tree README if you need that era.
