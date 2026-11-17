# Dropamine 3.3.18 (WoW Forever)

*Le Skills tab façon OSRS : tes compétences d'un coup d'œil, chaque +1 qui tombe, et ce qui monte sur ta cible.* (Anciennement « OSRS Total Level ».)

Grille de compétences inspirée du **Total level** d’Old School RuneScape, dans **une fenêtre unique, entièrement dessinée par l’addon**. L’onglet **Comp.** natif n’est plus jamais touché (ni caché, ni déplacé, ni relu).

## Installation

1. Dézippe `Dropamine-3.3.18.zip` dans `World of Warcraft\_forever_\Interface\AddOns\`, ce qui donne `...\AddOns\Dropamine\Dropamine.toc`.
   **Venant d'OSRS_TotalLevel** : garde l'ancien dossier activé pour la PREMIÈRE connexion (Dropamine importe ses réglages, message dans le chat), puis supprime `AddOns\OSRS_TotalLevel` et fais `/reload`. Autre voie : copie `WTF\Account\<compte>\SavedVariables\OSRS_TotalLevel.lua` en `Dropamine.lua` avant de lancer le jeu.
2. Le TOC déclare `## Interface: 16001` (Forever 1.60.1). Si le jeu le marque « périmé » après un patch, coche « Charger les addons périmés ».

## Nouveautés 3.3.18
- Commandes : seulement **`/drop`** et **`/dropamine`** (les anciens alias sont retirés).
- `Media/Flare/` renommé `Media/Skin/` (nos propres textures de réglages, chemins mis à jour).
- `.toc` : `X-License: MIT`, icône `Media/Dropamine-Icon`, ligne commentée pour l'ID CurseForge (à remplir à la création du projet).

## Nouveautés 3.3.17
- **Nouveau nom : Dropamine.** Dossier `Dropamine/`, `Dropamine.toc`, commande principale **`/drop`** (et `/dropamine`). Réglages dans `DropamineDB`, importés UNE fois depuis `DropamineDB` (l'ancienne table n'est jamais modifiée). Messages préfixés « Dropamine ».
- **Bord du panneau redessiné par nous** (`Media/Dropamine-Frame.tga`, généré par `tools/make_frame_border.py`) : même tracé, même pan coupé, même profil d'opacité et même éclairage que le bord FlareUI qu'il remplace. Écart mesuré sur le panneau rendu : moyen 0,04/255, max 9/255 (invisible). Plus aucun fichier FlareUI dans `Media/` : le filet de la jauge (`Dropamine-Thin`) et sa piste (`Dropamine-Bar`) sont aussi les nôtres.
- **Pastille « N prêt(s) »** : petite plaque façon FlareUI (fond sombre, filet bronze 1 px, ombre noire 1 px, Arial Narrow 9 or), posée entièrement dans l'écart au-dessus de la case : elle ne mord plus la case, ni celle du dessus, ni le bord du panneau. Écart vertical 12 px, marges 12 px.
- **Chiffres** : rang grand et blanc, « /max » plus petit (≈ 78 %) et atténué, même ombre nette partout, retrait de 4 px dans le biseau ; les maxima ≥ 10 000 s'abrègent (« /25k »). Léger dégradé sombre sous les chiffres pour la lisibilité.
- **Barre Niveau total** : jauge de 8 px (au lieu de 3) avec piste sombre, remplissage bronze, reflet de 1 px et filet fin bronze ; icône et texte centrés verticalement.
- **3e thème « classic »** (`/drop theme classic`, aussi dans les réglages et le mode édition) : textures du jeu appelées par leur chemin, rien de copié — bord d'infobulle `Interface\Tooltips\UI-Tooltip-Border`, cadres de bouton d'action `Interface\Buttons\UI-Quickslot2` (appui `UI-Quickslot-Depress`), chiffres contournés, barre `Interface\TargetingFrame\UI-StatusBar`. Le thème par défaut reste **flare**.
- Aperçu QC : `preview_3.3.17.png` (outil `tools/preview_panel.py` : capture 3.3.16, maquette 3.3.16, 3.3.17 dans les 3 thèmes, écart du bord redessiné).

## Nouveautés 3.3.16
- **Récap de session visible** : il s'affiche au DÉBUT du compte à rebours de déconnexion ou de sortie (événements PLAYER_CAMPING / PLAYER_QUITING, plus des crochets sûrs sur Logout / Quit pour la déconnexion instantanée), en toast tenu 20 s et en ligne de chat. Il disparaît si tu annules (LOGOUT_CANCEL). Plus rien à PLAYER_LOGOUT (caché par l'écran de chargement). `/drop recap` et `/drop recap on|off` restent.
- **Bouton d'ouverture** (lanceur près du chat / micro-menu, et bouton de minicarte) : même icône que la barre total — `Media/SkillsTab` recadrée, masquée, avec le bord biseauté bronze, le tout dans le cadre du bouton (plus de débordement ; l'anneau rond de la minicarte est retiré).
- **Lanceur déplaçable** de nouveau : glisser pour le déplacer (le verrou du panneau ne le bloque plus), un simple clic bascule toujours, le clic de fin de glisser est ignoré. Position mémorisée pour le compte.
- **Mode édition** : le panneau ne revient plus à sa place par défaut. Sa position mémorisée est reposée à l'entrée / la sortie et après chaque mise en page ; seul « Revenir à la position par défaut » la remet par défaut.

## Nouveautés 3.3.15
- **Bord du panneau jamais blanc** : la teinte bronze est reposée après chaque `SetBackdrop` (y compris le repli en 8 textures), chaque fondu, changement de thème et redimensionnement. Les couleurs d'infobulle par défaut (blanches) ne touchent plus l'habillage. Toasts : idem.
- **Textures** : addon autonome, sans dépendance ni code FlareUI. Fond `Interface\DialogFrame\UI-DialogBox-Background-Dark` (Blizzard, comme FlareUI). Bord : `Media/Dropamine-Frame.tga` (3.3.17 : notre dessin, voir `tools/make_frame_border.py`). Même réglage que FlareUI : bord 16, marges 3, teinte `#A67D45`.
- **Bord d'icône** façon capture de référence : filet bronze de 1 px, coins biseautés, ombre noire dehors, liseré sombre dedans, icône recadrée. La surbrillance de cible (verte) et la sélection (or) recolorent ce même bord, sans trait carré. Aperçu QC : `preview_3.3.15.png` (outil `tools/preview.py`).
- **Arme équipée** : seules les compétences des armes portées (main droite, main gauche, distance) s'allument, d'après l'objet (classe 2, sous-classe, par ex. 15 = Dague → Dagues). Deux niveaux : vert FORT quand tu frappes (attaque auto, Tir ou baguette), vert DISCRET si la cible convient mais que tu ne frappes pas. Même logique pour Combat farouche (en forme) et la Défense (forte quand la cible te frappe). Infobulle : « Dague équipée · monte sur cette cible ».
- **Forme de félin / ours** : détection par toutes les sondes (identifiant de forme, barre de formes, auras UnitAura / C_UnitAuras / AuraUtil, type de ressource : énergie → félin, rage → ours). `/drop debug` montre le résultat de chacune. En forme : seulement Combat farouche et Défense.
- **« +1 » et pastille « N prêt(s) »** : le « +1 » est en haut à gauche dans la case, la pastille au-dessus ; ils ne se cachent plus.
- **Première ouverture** (nouveau personnage) : plus d'ascenseur. La mise en page est refaite à la connexion, à l'entrée dans le monde, au chargement des compétences et à la frame suivante. Le panneau principal n'affiche jamais d'ascenseur.

## Nouveautés 3.3.14
- **Un seul bronze** `#A67D45` (jeton `ns.STYLE.BORDER`, voir `STYLE.md`) pour le bord du panneau, les toasts, toutes les cases (compétences, total, JcJ), les pastilles et la barre total, dans les deux thèmes. Les cases avaient encore l'ancien bronze 115/91/56, qui paraissait gris.
- **Bord du panneau** : le filet de `Media/Edge.tga` est maintenant blanc pur, donc la teinte donne exactement le bronze (avant, il était gris et assombrissait la couleur). Si le jeu n'a pas `BackdropTemplate`, le bord est reconstruit en textures au lieu de retomber sur le bord gris des infobulles.
- **Surbrillance de cible** : bord vert de 2 px en plus du voile. Sur l'icône violette de Forme de félin, le voile seul ne se voyait pas. Une case sélectionnée a un halo or au lieu de bleu. Le vert et le gris ne servent plus qu'à la cible et aux barres de nom.
- **Défense** : verte sur toute cible non grise, jusqu'au plafond du personnage. Le plafond estimé (5 × niveau de la cible) ne s'applique plus qu'à l'arme et au Combat farouche.
- **Barre Niveau total** : le libellé « /2460 » de la case ne s'affiche plus en mode barre.
- **Barres de nom** : une icône par métier, y compris ceux liés par une recette (ex. Travail du cuir sur une bête dépeçable). Verte si une recette donne un point, grise sinon.
- **Infobulle** : une seule ligne par métier. La ligne grise « recettes grises » disparaît s'il y a déjà une ligne de gain pour ce métier.

## Nouveautés 3.3.13
- **Style FlareUI** partout (panneau, toasts, cases, pastilles, fenêtre de réglages) : fond Dialog sombre de Blizzard, bord arrondi `#A67D45` (notre fichier `Media/Edge.tga`), même opacité pour le panneau et les toasts. Les jetons sont dans `STYLE.md`. Technique inspirée de FlareUI (Malkkav, code sous licence MIT) ; aucun fichier FlareUI n'est copié (ses images ne sont pas sous licence de réutilisation).
- **Deux thèmes** : `flare` (par défaut) et `leger` (sans cadre, cases flottantes). `/drop theme flare|leger` (les anciens noms `cadre` et `sans` marchent toujours).
- **Taille dynamique** : la poignée, `/drop taille 50-200` et le curseur changent la taille des cases, les espacements et les textes. Le bord garde son épaisseur normale à toutes les tailles (plus de SetScale).
- **3 colonnes** : `/drop colonnes 3` (aussi dans le menu, et avec Alt+glisser) donne un carré de 3 × 3.
- **Niveau total masqué par défaut** : `/drop total on` l'affiche, ou l'option « Case Niveau total ». S'il se retrouve seul sur la dernière rangée, il prend la forme d'une barre fine sur toute la largeur : icône OSRS, « total / max » et une jauge.
- **Mode édition** : quand le mode édition du jeu est ouvert, cliquer sur le panneau ouvre une fenêtre de réglages rapides (Disposition, Taille, Apparence, Notifications, Fondu, Cibles & récolte, JcJ). Elle a des curseurs ◀ ▶ avec une case numérique, des menus déroulants et les boutons « Paramètres complets », « Réinitialiser » et « Revenir à la position par défaut ». `/drop edit` fait la même chose si le mode édition du jeu n'est pas disponible.
- **Toasts de recettes cliquables** : un clic ouvre le métier et sélectionne la recette (en combat, la recette est retenue jusqu'à l'ouverture du métier). Infobulle « Clic : ouvrir la recette ».
- **JcJ** (`/drop pvp on|off`) :
  - une case avec ton rang et la jauge « points de rang / plafond », lue dans la fenêtre JcJ ;
  - l'infobulle donne l'honneur, les victoires honorables du jour et de la semaine, le K/D (total et session) et ta série ;
  - un toast « +1 victoire honorable » ;
  - un repère vert ou gris sur la barre de nom des joueurs ennemis ;
  - un objectif de victoires du jour (clic droit sur la case).
- **Correctif druide** : en forme de félin ou d'ours, la case Combat farouche passe bien au vert. Le calcul et l'affichage utilisaient deux clés différentes.
- **Correctif** : `/drop alertes` (sans argument) et la case « Alertes de cible » désactivent vraiment les alertes.

## Nouveautés 3.3.12

- **Taille au pour cent près** : la poignée du coin bas-droit change seulement la taille, en continu (pas de 1 %, de 50 à 200 %), coin haut-gauche fixe, bord d'infobulle toujours net. Elle ne change plus le nombre de colonnes (plus de saut « trop petit / trop grand »).
- **Colonnes** : `/drop colonnes 1|2|5|10`, la liste des options, ou **Alt+glisser** la poignée.
- `/drop taille` accepte tout entier de 50 à 200 ; le curseur Options › Taille va de 50 à 200 % par pas de 1.

## Nouveautés 3.3.11

- **Bordure des infobulles, à l'identique** : panneau et toasts utilisent la bordure par défaut de l'infobulle (mêmes pièces NineSlice, couleur `TOOLTIP_DEFAULT_COLOR`, fond `TOOLTIP_DEFAULT_BACKGROUND_COLOR`), sans aucune teinte à nous (ni bronze, ni doré de palier, ni teinte live de l'infobulle).
- **Bord jamais délavé** : au repos, seul le fond (`/drop fond`) et l'opacité du panneau entier (`/drop opacite`) baissent ; le bord n'est plus atténué à part (c'était le gris / beige pâle).
- **Pastille « N prêt » en 1re rangée** : la marge du haut s'agrandit (13 px au lieu de 10) quand une pastille dépasse au-dessus d'une case du haut ; elle n'empiète plus sur le bord et passe au-dessus du cadre.
- Thème « sans » : les toasts gardent aussi la bordure des infobulles.

## Nouveautés 3.3.10

- **Thème** : `/drop theme cadre|sans` (ou Options › Affichage › Thème). « Sans cadre » : ni fond ni bord, les cases flottent comme les icônes du CDM ; poignées visibles au survol seulement (et jamais avec `/drop verrou`).
- **Cases unifiées** (les deux thèmes) : bord bronze 1 px aux coins adoucis, icône arrondie (masque), petite ombre douce discrète.
- **Pastille « N prêt »** : petite pastille au-dessus du bord haut de la case ; elle ne couvre plus les chiffres (la grille laisse 8 px entre les rangées).
- **Poignée en bas à droite** : vrai redimensionnement — glisser change la disposition (1/2/5/10 colonnes) et la taille (pas de 5 %), sans infobulle.
- **Déplacement** depuis n'importe où (cases comprises) ; un simple clic reste un clic (sélection, clic droit objectif, Maj+clic partage). Plus d'infobulle « Glisser : déplacer » sur le bord.
- **Toasts** : même fond (couleur + `/drop fond`), même bord et même fondu que le panneau ; en « sans cadre », même style que les cases. Bord jamais rouge : les couleurs ne sont plus relues sur l'infobulle du jeu (teintée après le survol d'un ennemi).
- **Cible grise** (observé sur Forever) : l'arme et le Combat farouche montent quand même (seul le plafond 5 × niveau, « estimé », reste) ; la Défense non (confirmé en jeu) (« pas de gain sur cible grise (observé) ») ; l'XP de niveau non plus.
- **Objectif (bug 3.3.9)** : « Valider » un objectif (clic droit sur une case) ne provoque plus l'erreur `View.lua:467 … field 'h'` (ni en fin de combat, ni à l'ouverture d'une fenêtre de métier, ni après l'éclat d'un gain). L'objectif est enregistré avant le rafraîchissement ; la case garde son rang sur deux lignes, sans « x/max » par-dessus.

## Nouveautés 3.3.9
- Bordure du panneau ET des toasts = la mise en page NineSlice de l'infobulle du jeu (lue sur GameTooltip, « TooltipDefaultLayout » par défaut), appliquée par les fonctions de Blizzard ; coins à leur taille native quelle que soit `/drop taille`, sans accrochage aux pixels → arrondis lisses. Le fond reste réglable (`/drop fond`).
- Rendu plus propre : chiffres et badge sans contour épais, une ombre fine de 1 px ; badge « N prêts » avec un simple liseré bronze (plus de halo).
- Druide : détection de forme renforcée (identifiant de forme, barre de formes ancienne / récente, aura Félin / Ours / Ours redoutable) ; case Combat farouche reconnue par nom FR / EN et ligne 134. Une case de combat non allumée explique pourquoi au survol (ex. « 128 ≥ 120, plafond 5 × niveau 24 »). `/drop debug` affiche la forme détectée et la case farouche.

## Nouveautés 3.3.8
- Panneau centré : marges égales des 4 côtés (toutes dispositions, toutes tailles) ; rangs DANS les cases ; badge « N prêts » centré.
- Fond actif plus clair / translucide (bord doré inchangé) : `/drop fond <0-100>` (45 % par défaut).
- Repère de barre de nom unique, centré au-dessus du nom : une icône par métier (Dépeçage, Cuisine, Secourisme), bordure verte = +1 possible, grise = rien (gris, rang trop bas ou plafond).
- Infobulle de créature compacte : 3 lignes max, une par métier (« Secourisme +1 : Anti-venin, Cataplasme », « Cuisine : 4 recettes à apprendre ») ; détail avec Maj. Plus de flèches ni de « source inconnue ». `/drop infobulle compacte|detail`.
- Druide : en félin / ours, seule la case Combat farouche (et Défense) s'allume, jamais l'arme ; en forme humanoïde, l'arme.
- Options réordonnées : Affichage, Notifications, Cibles & récolte, Métiers, Infobulle des cases & rappels ; menus et curseurs avec valeur en direct ; bouton « Valeurs par défaut » (`/drop options defaut`). Nouvelles commandes : `/drop animation`, `/drop liens`, `/drop nonapprises`.

## Nouveautés 3.3.4

- **Niveau total a sa propre case**, la dernière de la grille (comme la case Total level d’OSRS) : valeur sur deux lignes (« 940 » / « /2460 »), icône 3 piliers, cadre bronze ; un clic ouvre le volet « Niveau total ». La ligne du bas disparaît.
- Grille en rectangle plein : 9 compétences + total = 10 cases en **5 colonnes × 2 rangées**, colonnes égales, aucune rangée incomplète ; le panneau compact fait 278 × 126 px.

## Nouveautés 3.3.3

- **Panneau compact permanent** façon OSRS : la grille d’icônes seule , sans titre ni texte, brun foncé et bordure bronze. Déplaçable par sa fine poignée du haut, position mémorisée, reste ouvert d’une session à l’autre. Ne prend pas la souris hors des cases.
- **Chevron** (ou clic sur une case) : déplie / replie le volet de détail. Échap ne fait que replier, jamais fermer.
- **Opacité** du fond et du cadre : `/drop opacite 0-100` ou le curseur du panneau déplié (icônes et textes restent nets) ; `/drop opacite icones 20-100` en option.
- **Verrou** : `/drop verrou on|off` (panneau et lanceur).
- **Lanceur** : rangé dans la colonne verticale du micro menu de Forever (sous le « ? », même taille, même centre, cadre de la colonne prolongé sous lui). Déplaçable en le glissant ; relâché près de la colonne il s’y range ; `/drop lanceur reset`.
- **Cases** : rang sur deux lignes (« 129 » / « /130 »), police plus grosse, alignée à droite ; portrait du personnage sur la case Niveau.
- **Bronze mesuré** (1 px (115,91,56) + 1 px d’ombre (66,52,34)) à la place des cadres gris : cases, panneau, barre du détail.

## Nouveautés 3.3.2

- **Micro menu** : l’onglet latéral de la fiche est supprimé. Un bouton « 3 piliers » (rouge / vert / bleu sur fond sombre) s’ajoute au bout de la rangée native (Personnage, Grimoire, Talents…), même taille, même cadre, même surbrillance et même état enfoncé que ses voisins (textures Blizzard du bouton Personnage). Info-bulle « Niveau total : X / 2460 », clic : ouvre / ferme la fenêtre. Aucun bouton natif déplacé.
- **Minicarte** : mêmes piliers, info-bulle « Niveau total : X / 2460 ».
- **Cases** : rang affiché « actuel/max » (« 129/130 », Niveau « 27/60 »), police étroite contourée qui tient dans la case.
- **Plus de catégories** : une seule grille compacte, à la OSRS (Niveau, Mêlée, combat de la classe, Défense, métiers, Cuisine, Pêche, Secourisme), « Niveau total » en bas. Option cachée `/drop categories on` pour revenir aux sections.
- **Volet « Niveau total »** : titre « Niveau total » et description de nouveau visibles, au même endroit que les autres volets.

## Correctifs 3.3.1

- Icône « 3 piliers » (trois colonnes rouge / verte / bleue) dessinée par l’addon avec ses propres aplats, sur le bouton (micro menu depuis 3.3.2) et le bouton de minicarte. Plus l’ancienne image à 9 blocs.
- Plus aucune image de Zygor : des onglets voisins, on ne lit que la position ; cadre d’onglet du grimoire codé en dur. L’onglet se place sous l’art visible de l’onglet du dessus, sans chevauchement.
- Volet de droite : tout le texte (description, Progression, lignes de combat, Statistiques…) a la marge native de 22 px à gauche et à droite.

## Nouveautés 3.3.0 : grille d’icônes, couleurs natives

- La grille n’affiche plus que des **icônes** (notre petit cadre carré), comme une barre d’action : le **rang** est écrit en bas à droite de chaque icône (police des compteurs de boutons, blanc contouré). Plus de nom ni de barre sur les cases.
- Survol : info-bulle (nom, rang / max, XP pour Niveau, palier, rappel d’arme). Clic n’importe où sur la case : sélection (surbrillance native de case cochée), et **tout le détail** s’affiche à droite : nom au-dessus du filet, barre bleue native « rang / max », progression, description, recettes.
- Sections repliables avec le « − / + » jaune, « Niveau total » en ligne du bas : inchangés.
- Fini le gris : fenêtre aux couleurs mesurées sur la fiche native (fond (34,23,15), liste (19,11,2), barre de titre (49,28,13), bordure native teintée bronze (135,100,57)). Si la fiche du personnage a une texture de fond lisible, elle est reprise.
- Toasts, onglet latéral sous Zygor, `/drop`, Échap, position mémorisée, onglet Comp. intact : inchangés.

## Utilisation (3.2.0)

- **Ouvrir / fermer** : le bouton 3 piliers du micro menu ou de la minicarte, `/drop` (ou `/dropamine`), ou un clic sur un drop. Échap replie le détail (3.3.3).
- **Fenêtre** : bordure de dialogue native, déplaçable (glisser), position mémorisée ; par défaut arrimée à droite de la fiche. `/drop reset` la remet à sa place.
- **Grille** (3.3.2 : icônes seules, 5 colonnes, sans catégories), pas de rangée fixe 46 px, défilement si ça déborde, « Niveau total » ancré en bas.
- **Tuiles** : un seul style pour toutes (Niveau, armes, Défense, métiers, emplacements libres) : barre 24 px, dégradé mesuré (0,50,97) → (31,92,159) sur fond (25,14,0), texte blanc, taille fixe.
- **Volet de droite** : notre volet pour toutes les tuiles (titre au-dessus du filet, description, barre, sections, recettes lues automatiquement et mises en cache).
- `/drop debug` : état de la fenêtre et du bouton du micro menu (ancrage, textures).
- `/drop couleurs palier|vert|jaune`, `/drop drops on|off|move`, `/drop minimap`, `/drop objectif …`, `/drop stats on|off` : inchangés.

## Nouveautés 3.2.0 : fenêtre unique (plan B)

- Fini le mode 3.1.0 qui déplaçait les lignes natives (`NativeGrid.lua` retiré, archivé hors du zip).
- Fini la bascule Vue OSRS / Vue classique dans l’onglet Comp. : l’onglet natif reste 100 % d’origine.
- Nouvel onglet latéral sur la fiche (sous Zygor) ; le bouton icône près de la petite flèche carrée est supprimé.
- Toutes les tuiles partagent la même barre ; repli de section fiable ; pas fixe 40 px.

## Correctifs 3.0.1 (minimes ; clics et toast inchangés)

- Pas de ligne fixe calculé sur la liste entièrement dépliée ; « Niveau total » en bas de la zone de liste ; contenu ancré en haut ; débordement → défilement (molette, flèches, curseur au look natif, visible seulement si nécessaire). Barre de défilement native cachée.
- Filets de séparation natifs de la liste conservés en vue OSRS.
- Un en-tête replié en vue classique n'est plus jamais redéplié (l'addon ne touche jamais l'état des en-têtes natifs).
- Volet de détail : un seul à la fois (natif seul pour armes/Défense), titre au-dessus du filet natif, marges mesurées.
- Barres des tuiles construites depuis la StatusBar native (texture, couleur, fond, bordure relevés en jeu, sinon gabarit natif), taille native fixe, police du texte de barre native.
- Bouton de bascule carré, clone du bouton flèche natif, placé juste à sa gauche.
- Recettes lues automatiquement (lecture seule, mise en cache par personnage/métier) à l'ouverture d'un métier ; l'addon n'ouvre jamais la fenêtre de métier.

## Nouveautés 3.0.0 (vue OSRS réécrite)

La vue OSRS repart sur une base propre (nouveau fichier `View.lua`) ; la couche
de données (lecture des compétences, totaux, paliers, SavedVariables) est inchangée.

- **Un seul cadre** autonome, parent = `SkillFrame`, affiché uniquement en vue OSRS.
  Il n'est jamais placé dans la liste native.
- **Liste native cachée (`Hide`)** en vue OSRS hors combat, **réaffichée (`Show`)** en
  vue classique. En combat rien de natif n'est touché : la demande attend la fin du combat.
  Tout cadre natif posé sur la zone de la liste qui prend la souris ou porte du texte
  est caché lui aussi (c'est ce qui pouvait voler les clics) ; le décor pur reste.
- **Supprimés** : écran anti-clic, couche de boutons de clic, opacité 0, disjoncteur
  « ApplyView en rafale ». Niveaux de cadre fixes : encadré = fiche + 10, tuiles + 2.
- **Tuile = un Button** avec ses propres régions (icône, nom, barre, surbrillance) ;
  la zone de clic couvre la cellule entière (`SetHitRectInsets` négatifs).
- **En-têtes repliables** = un Button avec les textures de l'en-tête natif et
  **seulement** le « − / + » jaune natif à droite (l'ancien bouton rond rouge à gauche
  est supprimé). État enregistré par section.
- **Barres** : géométrie et couleurs mesurées sur la capture native (24 px, remplissage
  17 px, dégradé (0,50,97) → (31,92,159), fond (25,14,0), filets), **texte blanc**.
- **Surbrillance** sur toute la tuile, barre comprise, sous le contenu.
- **Drop d'XP** : code 2.8.3 conservé ; clic = ouvre Comp. en vue OSRS (hors mode
  édition, différé en combat). En mode édition, glisser le drop déplace le support et
  enregistre sa position ; le clic n'ouvre rien.
- `/drop hitdebug` : liste chaque tuile (taille, niveau, souris) et les éventuels cadres
  natifs au-dessus d'elle (« VOLÉ PAR … »).

## Nouveautés 2.8.4

- **Vue classique libre** : en vue classique, la grille, la couche des boutons de tuile, les en-têtes, l'écran anti-clic et notre détail sont cachés (Hide) **et** sans souris ; l'opacité native est entièrement rendue (filet de sécurité sur tout ce que l'addon a voilé). En combat : nos cadres se cachent tout de suite, le natif est rendu à la fin du combat. L'écran anti-clic ne peut plus réapparaître hors vue OSRS. `/drop hitdebug` fonctionne aussi en vue classique.
- **Clic sur un drop** (XP, compétence) : ouvre l'onglet Comp. en vue OSRS sur la bonne tuile ; le drop cliqué se ferme ; si l'onglet n'existe pas encore, la fiche est ouverte puis attendue au plus 1 s (minuterie toujours arrêtée) ; en combat : différé + message. Garde-fous anti-boucle : un OnSizeChanged sans vrai changement de taille est ignoré, et plus de 25 mises en page en 2 s sont coupées.
- **Sections repliables** : Combat / Métiers / Métiers secondaires = un bouton plein cadre avec l'icône +/− native ; état mémorisé par section (`DropamineDB.ui.collapsedGroups`), les sections suivantes remontent.
- **Origine de la liste native** : la grille démarre à l'origine de l'en-tête natif et s'arrête avant la barre de défilement ; la barre de défilement native (piste + flèches) et le décor du cadre restent visibles (seules les lignes sont voilées).
- **Barres** : couleurs de repli corrigées (bleu natif 0 ; 0,40 ; 1 et fond quasi noir au lieu du violet / gris) ; le cadre de barre finit dans la tuile ; la surbrillance est ancrée au bouton de la tuile et couvre icône + texte + barre.
- **Détail « Niveau »** : titre « Niveau » + valeur « Niveau N » au-dessus de la barre, texte de barre blanc, lignes XP en deux tons natifs, contenu empilé depuis le haut, « Compte dans le total » juste sous le contenu ; repli de police GameFontNormal / or natif.

## Nouveautés 2.8.3

- **Clic / survol sur toute la tuile (corrigé)** : en jeu, les lignes de la liste native restaient sensibles à la souris malgré leur opacité 0 et passaient au-dessus de nos boutons ; seule une bande étroite répondait. Les boutons de tuile vivent maintenant dans une couche dédiée, à taille explicite (= cellule), au-dessus de **tout** cadre natif sensible à la souris relevé sur la grille. `/drop hitdebug` : voile rouge sur la zone de clic réelle de chaque tuile + nom du cadre sous la souris (`/drop hitdebug off` pour retirer).
- **Style relevé sur la vraie liste native** (lecture seule) : en-têtes Combat / Métiers / Métiers secondaires = copie complète de l'en-tête « Compétences d'armes » (toutes les pièces, hauteur, police, couleur) ; barre des tuiles = barre native (hauteur, remplissage, couleur, fond et cadre clonés) avec « rang / max » dedans (couleur de palier conservée) ; nom des tuiles = police et couleur des lignes natives ; surbrillance = texture native des lignes, sous le texte et la barre.
- **Marges natives** : marge gauche/droite de la liste et écart en-tête → première ligne relevés et appliqués.
- **Texte des tuiles** : calé en haut ; nom entier sur la ligne 1 (« non appris » à droite seulement s'il tient, sinon masqué) ; rang dans la barre.
- **Cadre de fond** : en vue OSRS, le fond / l'encart du volet gauche restent visibles ; seul le contenu natif est voilé.
- **Panneau droit** : titre et barre centrés ; description et lignes alignées à gauche sur la marge native, pleine largeur ; polices du titre, de la description, des en-têtes et des lignes relevées sur le détail natif ; boutons d'en-tête à la taille native. Détail du Niveau total en sections ancrées (plus de chevauchement).
- **Bouton « Vue classique »** : la recherche de la flèche couvre aussi le cadre du personnage ; `/drop debug` liste les petits boutons détectés et signale un chevauchement.

## Nouveautés 2.8.2

- **Clic et survol sur toute la tuile** : chaque tuile a un bouton plein cadre (icône, nom, rang, barre et vide
  autour), posé au-dessus de tous nos cadres ; les cellules se touchent (aucun trou entre deux tuiles, plus de
  clignotement). L'écran anti-clic reste sous la grille et bloque toute la liste native.
- **Surbrillance façon onglet Statistiques** : rectangle blanc translucide aux coins arrondis, sans bordure
  (survol 10 %, sélection 16 %). Fini le cadre brun et le bord or.
- **Style natif** : plus aucun fond, dégradé ni bord à nous sur la grille, les tuiles, le bandeau du total ni le
  panneau de droite. En-têtes de groupe natifs « Combat », « Métiers », « Métiers secondaires » ; noms en
  blanc, rang coloré par palier ; barre fine en bleu natif ; icônes dans un emplacement d'objet natif carré ;
  bandeau du total dessiné avec le bouton d'en-tête natif (lu sur le panneau de droite), toujours cliquable.
  Les drops ne changent pas.
- **Ordre fixe** : Niveau, Mêlée, 2e tuile de combat, Défense, puis Métier 1, Métier 2, Cuisine, Pêche, Secourisme.
- **2e tuile de combat selon la classe**, libellée du vrai nom de la compétence : Baguettes (Démoniste, Mage,
  Prêtre), Combat farouche (Druide), arme à distance équipée sinon meilleure compétence à distance connue
  (Chasseur, Guerrier, Voleur). Paladin et Chaman : pas de 2e tuile. Compétence introuvable : la tuile
  n'apparaît pas (rien n'est deviné) et ne compte pas dans le total.
- **Panneau de droite** : pour une arme ou la Défense que le panneau natif affiche déjà, il reste **tel quel**.
  Sinon (métiers, Niveau, total, ou arme que le natif n'affiche pas) : notre panneau en style natif (sections
  à en-tête natif, lignes or / blanc). Les lignes natives « Adversaire de niveau égal », « Contre les boss de
  raid », chances de toucher / critique / coups déviés sont **lues** sur le panneau natif quand il les affiche,
  puis mémorisées par compétence ; jamais calculées. Pas encore lues : ligne masquée + indication grise.
  Statistiques Dégâts / Vitesse / DPS / Armure / Esquive / Parade / Blocage lues hors combat (dernières valeurs en combat).
- **« Crochets » au bord du panneau de droite** : c'étaient les barres d'en-tête natives de la compétence
  précédente, restées visibles derrière notre panneau. Tout le contenu natif du panneau est maintenant voilé
  (opacité seulement, hors combat) dès que notre panneau s'affiche, et restauré quand le natif reprend la main.
- **Boutons** : « Vue classique » / « Vue OSRS » ne chevauche plus la flèche native (rectangles vérifiés, recalage
  automatique, dans les deux vues).
- `/drop debug` liste les ressources natives utilisées (en-têtes, emplacement d'icône, détails lus, ornements voilés).

## Nouveautés 2.8.1

- **Correctifs** : un clic sur le titre d'une tuile ne traverse plus vers la liste
  native invisible (écran anti-clic à nous au-dessus de la liste, tuiles au-dessus) ;
  cache de rangs persistant : un en-tête natif replié ne fait plus disparaître de
  tuiles ni baisser le total / « aujourd'hui » ; plus de déluge de drops (« +rang
  complet » impossible, amorçage silencieux, relecture > 3 compétences = silence,
  1 drop par compétence, 5 au plus) ; fond des encadrés toujours en dégradé brun clair
  (même si une texture Media/Skin manque — `/drop debug` liste celles chargées) ;
  bouton « Vue classique » entier, à 4 px à gauche de la flèche (replié / déplié).
- **Recettes réalisables** (tous les métiers de fabrication + Cuisine, Secourisme) :
  recettes, composants et couleurs lus à l'ouverture de la fenêtre du métier
  (Enchantement : fenêtre Craft ; Minage : Fonte) ; pastille « N prêts » sur la
  tuile ; liste dans le détail ; drop « N × recette possible(s) (+1) » ;
  `/drop recettes`.
- **Scanner** : icône seulement si l'objet sert à une recette connue qui fait encore
  progresser ; « créature → ingrédient → recette (+1) » (infobulle, toast).
- **Drops** : cumul tant que visible, survol = tenu, clic = onglet Comp. sur la
  bonne tuile, clic droit = fermer ; fond 68 % par défaut (l'ancien 35 % migre).
- **Aujourd'hui** : base quotidienne (minuit), détail par compétence dans le panneau
  du total et l'infobulle du bandeau.
- **Grille fixe de 9 emplacements**, emplacements libres grisés.
- **Options** aux couleurs de base, façon Questie.

## Nouveautés 2.8.0

- **Base du scanner précalculée** (`Data/ScannerDB.lua`, 84 Ko) : 91 objets (viandes et
  autres réactifs de Cuisine, étoffes et réactifs de Secourisme, cuirs / peaux / écailles),
  1635 PNJ avec butin utile (chance ≥ 2 %), 620 PNJ dépeçables, 160 recettes de Cuisine et
  Secourisme avec leurs réactifs ; noms EN / FR des objets et des recettes. Le scanner
  consulte la base d'abord (par npcID, à l'apparition d'une barre de nom), puis ce que tu
  as appris en jeu. Tant que la fenêtre d'un métier n'a pas été ouverte, les recettes
  du maître et de base de la base servent à choisir la couleur.
- **Couleur des rangs** (mode « Palier ») :
  - Niveau : XP du niveau en cours (rouge < 50 %, jaune 50-75 %, vert > 75 %), or au
    niveau maximum ; barre = XP du niveau + calque bleu clair d'XP reposée ;
    détail « XP reposée : X (Y % du niveau) ».
  - Métiers, Cuisine, Pêche, Secourisme : vert = rang suivant apprenable
    (« Rang supérieur disponible chez le maître ») ; jaune = « encore X points de métier »
    / « niveau Y requis » ; rouge = bloqué au maximum actuel ; or = 300 / 300.
  - Armes et Défense : vert au maximum actuel, jaune en dessous, rouge à 25 points ou plus
    sous le maximum (« encore X points avant ton maximum actuel »).
- **Style FlareUI** : palette relevée sur la capture FlareUI, textures redessinées
  (`Media/Skin/*.tga`) pour les encadrés, cases, onglets, curseurs, ascenseur, ligne
  sélectionnée, icônes rondes (ou biseautées si le client n'a pas de masque) et drops.
- **Animation de montée de niveau** : grand drop « Niveau X atteint ! » près des drops
  (jamais à la place de la bannière officielle), lueur dorée qui pulse, éclat doré,
  « Niveau total : N (+1) », pulsation de la tuile Niveau à la prochaine ouverture.
  Variante légère pour un nouveau rang de métier. Options : « Animation de montée de
  niveau » et « Son » (`/drop anim on|off`, `/drop anim son on|off`, `/drop anim test`).

### Sources de la base (relevé du 16/11/2026)

Données **WoW Forever uniquement** :
- pages objets `https://www.wowhead.com/forever/item=<id>` (listes « dropped-by » et
  « skinned-from ») ; les lignes que Wowhead marque « Classic Era » (complétées depuis
  Classic faute de relevés Forever) sont exclues ;
- listes de sorts `https://www.wowhead.com/forever/spells/secondary-skills/cooking`,
  `…/first-aid`, `…/fishing` et `…/professions/<métier>` (recettes, rangs de métier) ;
- infobulles `https://nether.wowhead.com/forever/tooltip/{item|spell|npc|quest}/<id>?locale=2`
  (noms français, exigences des livres) ; pages `spell=` et `quest=` des rangs.
Filtres : au moins 10 butins observés et 2 obtentions, chance ≥ 2 %, PNJ de niveau 1 à 60.

## Nouveautés 2.7.2 (correctifs)

- **Erreur au chargement corrigée** (`UI.lua:143: table index is nil`) : la table des
  drapeaux recevait un cadre natif encore inexistant (nil) ; elle l'ignore désormais.
- **Sélection des tuiles** : la grille passe au-dessus de la liste native masquée (qui
  captait survols et clics) ; un clic sélectionne et la sélection reste.
- **Bandeau « Niveau total »** cliquable et survolable sur toute sa hauteur ; un clic
  sélectionne le détail « Niveau total ».
- **Tuiles** : nom entier sur la 1re ligne, rang « 96/150 » (couleur de palier) dessous,
  puis la barre ; un peu plus d'espace entre les tuiles ; icône encadrée d'un bord or
  3 px par-dessus, coins arrondis, plus de cadre gris dessous (même style sur l'icône
  des drops).
- **Bord des drops** : le vrai bord du chat est copié à l'exécution (NineSlice, puis
  backdrop, puis enfants du chat) ; repli : bord or 3 px. `/drop debug` donne la source.
  Option **Coller au chat** (`/drop drops chat on|off`) : drops posés au ras du chat, à sa
  largeur ; aimant automatique quand on lâche le support sur le chat.
- **Options** rangées en encadrés : Notifications, Apparence, Scanner, Qualité de vie,
  Grille ; en-têtes jaunes, filet fin, cases sur deux colonnes alignées, curseurs pleine
  largeur avec valeur affichée, courte aide grise là où c'est utile.
- **Palette unique** (`Style.PALETTE`) : bord or #433010 / #A68863 / #685335 relevé sur la
  fenêtre Options de Forever, utilisé partout.

## Nouveautés 2.7.1 (correctifs)

- **Erreur de souillure corrigée** (`SkillsFrame.lua:442 … secret number value … tainted by 'OSRS_TotalLevel'`) :
  l'addon n'appelle plus jamais `C_SkillInfo.SetSelectedSkill`, `C_SkillInfo.ExpandSkillHeader` ni les
  fonctions de mise à jour de la fenêtre native ; la liste native (lignes, ScrollBox, barre de défilement,
  détail) est masquée par opacité seulement, jamais par `Hide()` ; aucun champ n'est écrit sur un cadre
  natif (drapeaux en table faible) ; ouvrir l'onglet Comp. depuis `/drop` attend la fin du combat.
  Les en-têtes repliés de la liste native ne sont plus dépliés : ils sont signalés dans `/drop debug`.
- **Survol fluide** : le survol d'une tuile ne fait plus que peindre la tuile et afficher un détail mis en
  cache (aucune relecture des compétences, aucune reconstruction, aucun OnUpdate permanent).
- **Style Métiers** : grille, détail et bandeau dans un encadré au dégradé brun relevé sur la fenêtre Métiers
  (#211C18 en haut → #3A2C24 en bas) avec un filet bronze #634D36 et un trait extérieur #321F11.
  Noms et titres en jaune `GameFontNormal`, rang coloré par palier, écrit une seule fois ; barres sans texte
  dans les tuiles, lignes réparties sur toute la hauteur du volet, bandeau en bas, « (+0 aujourd'hui) » masqué.
- **Bouton « Vue classique »** à la taille de son texte, même hauteur que la flèche, 4 px à sa gauche.
- **Options** : contenu dans un cadre défilant natif (molette), cases à cocher sur deux colonnes.
- **Drops** : bord bronze du cadre de chat (#655131, relevé au pixel), fond un peu plus translucide (35 %).
  Nouveau réglage **Sens d'empilement** : « Vers le bas » (par défaut) ou « Vers le haut » (le premier drop
  se pose au ras du bord bas du support, les suivants montent — pratique posé juste au-dessus du chat).
  Le support (mode édition) a exactement la taille d'un drop complet. `/drop drops sens haut|bas`.
- **Scanner** : messages de butin en français (« Vous recevez le butin : [Cuir léger] x2 ») associés au
  dernier corps looté ; correspondance par npcID, sinon même nom et même famille ; le cuir obtenu en
  rouvrant un corps compte comme un dépeçage ; icône Dépeçage (anneau bronze) au-dessus des bêtes vivantes
  déjà dépecées ; `/drop scanner pourquoi` explique pourquoi la cible a (ou n'a pas) d'icône.

## Nouveautés 2.7.0 (qualité de vie)

Tout se coupe dans `/drop options` (section « Qualité de vie ») ou par commande. Rien n’est inventé : les estimations demandent au moins deux mesures, les maîtres d’armes doivent avoir été vus en jeu.

- **Estimation du temps** : dans le détail d’une tuile, « 225 dans ~62 min (rythme mesuré) » vers l’objectif ou le max, d’après le rythme réel de la session ; pour le niveau, « Niveau 26 dans ~40 min ». `/drop eta on|off`.
- **Rappel avant le palier** : à max − 5 pour un métier ou une compétence secondaire, drop « Bientôt le palier : Secourisme 145/150 — prévois le passage chez le maître », une fois par palier. `/drop prepalier on|off`.
- **Historique 7 jours** : un instantané par jour (SV, 30 jours gardés) ; mini-graphe des 7 derniers jours en bas du détail (total ou compétence choisie) avec « 7 derniers jours : +N ». `/drop historique on|off`.
- **Autres personnages** : au survol du bandeau, liste des autres personnages (total, niveau, écart). `/drop alts on|off`.
- **Jalons personnels** : drops dorés « Jalon : premier 150 / 225 / 300 ! » (premier métier à ce rang sur le perso) et « Jalon : niveau total 500 / 1000 / 1500 / 2000 ! ». Les jalons déjà atteints sont mémorisés sans annonce au premier lancement. `/drop jalons on|off`.
- **Pêche** : prises comptées par zone (`IsFishingLoot`) ; le détail de Pêche montre « Prises ici (zone) : N » et les meilleures autres zones. `/drop peche on|off`.
- **Défense** : si tu cibles un adversaire gris alors que ta Défense n’est pas au max, petit drop léger « Défense 122/125 · Adversaire gris (niveau 10) », une fois par session. `/drop defense on|off`.
- **Récap de session** : `/drop recap` → « Session : niveau total +12, +4 300 XP, Dépeçage +5, Cuisine +7 (1 h 12) » ; la même ligne s’écrit à la déconnexion (`/drop recap on|off`).
- **Liste de courses** : avec un objectif de Cuisine / Secourisme et les recettes lues, le détail et `/drop courses` listent les recettes utiles (orange d’abord, puis jaune, vert), leurs composants par fabrication, ce que tu as en sac et ce qui manque.
- **Partage** : Maj + clic sur une tuile insère « Dépeçage 161/225 » dans la zone de saisie du chat (ouverte si besoin). **Jamais d’envoi automatique.** `/drop partage on|off`.
- **Maître d’armes** : quand tu ouvres un entraîneur qui propose une compétence d’arme, l’addon note son nom et la zone. Si tu équipes ensuite une arme dont la compétence n’est pas apprise, drop « Haches : compétence non apprise — Maître d’armes vu : Woo Ping (zone) ». Sans maître vu en jeu : aucun rappel. `/drop maitre on|off`.
- **Arme principale** : `/drop arme principale` mémorise l’arme en main ; l’info-bulle du rappel d’arme rappelle de la remettre ; `/drop arme` la rééquipe **hors combat uniquement** (en combat : simple rappel). `/drop arme on|off`.

## Nouveautés 2.6.0

### Scanner discret
- **Butin appris, jamais inventé** : à l’ouverture d’un butin (`LOOT_OPENED`, source lue par `GetLootSourceInfo`, sinon la cible morte via `CHAT_MSG_LOOT`), l’addon note quelle créature (n° de PNJ tiré du GUID, type `UnitCreatureType`) a donné quel objet. Viande → Cuisine, tissu → Secourisme (classe d’objet du client, sinon le sous-type « Viande » / « Tissu »). Une bête n’est marquée **dépeçable** qu’après un dépeçage réussi suivi d’un butin de cuir. Tout est gardé dans les SV.
- **Recettes connues** : à l’ouverture de Cuisine / Secourisme (hors combat), lecture des recettes, de leur couleur de difficulté et de leurs composants (`GetTradeSkillInfo`, sinon `C_TradeSkillUI`). Seules les recettes orange, jaunes ou vertes déclenchent une alerte.
- **Barres de nom** : quand une créature utile apparaît (`NAME_PLATE_UNIT_ADDED`), petite icône de 14 px au-dessus de la barre de nom, cadre coloré selon la difficulté (orange / jaune / vert, couleurs natives `TradeSkillTypeColor`). Jamais en combat (cachées à l’entrée, rescannées à la sortie). Toast facultatif (désactivé par défaut), une fois par type de créature et par session ; pas de son par défaut.
- **Nœuds de récolte** : l’info-bulle « Requiert Minage 75 » reçoit une ligne discrète « Minage : +1 possible » ou « Minage : 75 requis (actuel 70) ». Si un gain a été observé juste après avoir récolté ce nœud, « · gain vu au rang 71 » s’ajoute. Pas de couleur jaune / verte pour la récolte : les seuils ne sont pas publiés pour Forever, l’addon ne les invente pas.
- Dépeçage : les créatures dépeçables sont apprises, mais pas d’alerte colorée (aucune couleur de difficulté lisible côté jeu).
- `/drop scanner on|off`, `/drop scanner toast on|off`, `/drop scanner son on|off`, `/drop scanner icones on|off`, `/drop scanner reset`. `/drop debug` → section « Scanner discret ».

### Panneau d’options
- `/drop options` ouvre **Options > AddOns > OSRS Total Level** (`Settings.RegisterCanvasLayoutCategory`, sinon `InterfaceOptions_AddCategory`, sinon une fenêtre autonome). Cases et curseurs natifs.
- Notifications : drops activés, drops d’XP (`/drop drops xp on|off`), drops de compétence (`/drop drops comp on|off`), paliers, objectifs atteints (`/drop objectif on|off`), icônes / toast / son du scanner.
- Style des drops : **Complet** (icône, 3 lignes, fine barre) ou **Léger** (une ligne compacte icône + texte, sans barre) — `/drop drops style complet|leger` ; durée d’affichage 1–10 s (`/drop drops duree 5`) ; opacité du fond (`/drop drops opacite 45`).
- Grille : couleur des rangs (palier / vert / jaune), caractéristiques, gains de session, rappel d’arme, style Métiers (`/drop style on|off`). Scanner on / off.
- Chaque option écrit la même clé de SV que la commande ; panneau et commandes restent synchronisés.

### Drops façon toast compact
- Boîte compacte : fond noir translucide, fin bord doré légèrement arrondi (pièces du chat copiées, sinon bord fin doré), icône nette de 32 px dans un cadre fin, puis **trois lignes** : titre or (« Dépeçage +1 », « +226 XP »), ligne blanche (« Rang 162 / 225 », « Niveau 25 · 64 % »), petite ligne verte d’astuce, et une **fine barre** native en bas (texture / couleur Métiers de la compétence).
- Ligne verte : objectif en cours (« Objectif 175 : encore 13 »), sinon rythme **mesuré** dans la session (« ~2 min par rang (mesuré) », « Niveau 26 dans ~40 min »), sinon palier suivant (« Palier 225 : encore 63 ») ou XP restante (« Encore 2880 XP avant le niveau 26 »). Aucune estimation sans au moins deux mesures.
- Voile bleu-gris et déplacement **uniquement** en mode édition ; empilés en haut à droite ; fondu.

## Nouveautés 2.5.0

- **Objectifs** : clic droit sur une tuile → petite fenêtre native « Objectif pour Cuisine (actuel 78) » (Valider / Annuler / Effacer), pré-remplie avec le palier suivant. **Maj + clic droit** passe directement au palier suivant (75 / 150 / 225 / 300 pour les métiers ; dizaine suivante pour le niveau ; +25 pour les armes, borné au max) puis efface après le dernier. Un petit repère discret marque la cible sur la barre de la tuile. Objectif atteint → drop doré « Objectif atteint : Cuisine 150 » avec l’icône. `/drop objectif <compétence> <rang>` (ex. `/drop objectif Cuisine 150`, `/drop objectif niveau 30`, `/drop objectif Bâtons 75`), `/drop objectif` pour la liste, `/drop objectif clear [compétence]`. Sauvegardé **par personnage**.
- **Annonce de palier** : quand un métier ou une compétence secondaire atteint son max (rang = max), drop orangé « Palier atteint — va voir ton maître » avec l’icône, **une fois par valeur max** (mémorisé). La tuile plafonnée porte une petite icône de maître (14 px). Au premier lancement sur un personnage, les plafonds actuels sont mémorisés **sans annonce**. `/drop paliers on|off`.
- **Gains de session** : le bandeau devient « Niveau total : 914 / 2460 (+N aujourd’hui) ». Remis à zéro à la **connexion**, conservé après un `/reload`. Une ligne ; si la place manque, « aujourd’hui » est retiré. `/drop session on|off`.
- **Rappel d’arme** : si la compétence de l’arme en main est sous 50 % de son max (max lu, sinon 5 × niveau), petite icône d’alerte native sur la tuile Mêlée, info-bulle « Compétence d’arme sous-montée : Dagues 1/125 ». Druide en forme : pas d’icône, l’info reste dans le détail. Rien dans le chat. `/drop rappel on|off`.
- **Détail « Niveau total »** : titre, barre « 914 / 2460 » en blanc, liste à deux colonnes « Compétence … +N », puis une phrase : « Niveau + 2 métiers + Cuisine, Pêche, Secourisme + Mêlée, Distance/Farouche, Défense. » Les règles complètes sont dans l’info-bulle (survol du titre ou du bandeau). Les restes du détail natif (barres vides, flèches d’ascenseur) sont masqués en vue OSRS. « Compte dans le total : +82 » n’est jamais tronqué.
- **Style « Métiers »** : les barres et les encadrés reprennent la fenêtre Métiers de Forever. À la connexion (hors combat) l’addon charge, si elles existent, les interfaces `Blizzard_ProfessionsBook` / `Blizzard_TradeSkillUI` / `Blizzard_Professions`, puis relève à l’exécution les barres de rang (texture, couleur, fond) **par métier** et l’encadré (fond dégradé brun clair + filet doré). Nouvelle capture à chaque ouverture de la fenêtre ; la dernière est gardée dans les SV. Tuiles de métier, détail et drops utilisent la barre du métier correspondant, avec « Cuisine 78/150 » centré dans la barre quand ça tient (le nom au-dessus est alors retiré). Niveau et armes gardent la barre bleue native. La grille, le détail et le bandeau prennent l’encadré Métiers. Si rien n’est trouvé : barres natives teintées (cuir, gris-vert, bleu clair, vert) et dégradé brun clair + filet doré. `/drop debug` → section « Style métiers ».
- **Drops de compétence corrigés** : plus d’anneau doré sur l’icône ; l’icône est **exactement celle de la tuile** (même recherche par compétence, ex. « Dépeçage » → peau de loup ; arme → icône de l’arme équipée) ; plus de « 162 » à droite ni de sous-ligne « 162 / 225 » : le rang n’est que dans la barre.
- **Combat et valeurs secrètes** : plus d’erreur « attempt to compare a secret number value ». Toutes les lectures (caractéristiques, XP, niveau, rangs) passent par un filtre (`issecretvalue` + test de comparaison protégé) ; les caractéristiques ne sont plus lues du tout sans `/drop stats on` ; en combat, les rafraîchissements non essentiels attendent `PLAYER_REGEN_ENABLED`.

## Grille (ordre fixe, une page)

Pas de catégories. Tout tient sur une page ; les tuiles/colonnes se compactent si besoin.

1. **Niveau**
2. Les **métiers principaux appris**, au plus **2** (les non appris sont masqués)
3. Les **secondaires** de rang > 0 (Cuisine, Pêche, Secourisme ; Monte si apprise, affichée mais exclue du total)
4. **Mêlée** — compétence de l’arme en main principale (emplacement 16 → type d’objet → compétence). Si rien n’est équipé : Mains nues. Si le type est inconnu : meilleure mêlée (hors Combat farouche). L’icône est celle de **l’arme équipée**.
5. **Distance** — arme à distance équipée (emplacement 18) ; **ou Farouche** si Combat farouche > 0 (à la place de Distance).
6. **Défense** (si rang > 0)

Les 5 caractéristiques (Force, Agilité, Endurance, Intelligence, Esprit) ne sont **pas** dans la grille par défaut : elles sont déjà sur la fiche et ne comptent pas dans le total. `/drop stats on` les réaffiche, `/drop stats off` les recache.

Tout rang 0 est masqué. **Aucune autre tuile d’arme**, plus de « hors total ». Survol / clic sur une tuile de combat : le panneau de droite montre la **compétence précise** (Épées, Masses, Bâtons, Arcs, Combat farouche…) via `SetSelectedSkill` sur le bon index, avec la description native. La grille se met à jour à `PLAYER_EQUIPMENT_CHANGED`.

## Formule du niveau total

**X** = niveau + rangs des 2 métiers principaux + Cuisine + Pêche + Secourisme + les **3 tuiles de combat** (Mêlée, Distance ou Farouche, Défense).

**Y** = `60 + 2×300 + 3×300 + 3×300` = **2460**

(Niveau 60 documenté ; palier 300 attesté par les objets de camp. Le racial Culture mentionne des plantes **> 300** : le plafond réel peut être plus élevé, aucun chiffre n’est publié. L’addon n’invente pas ce chiffre.)

Les caractéristiques ne comptent pas. La Monte, si elle est apprise, est affichée mais exclue (plafond non documenté).

## Drops (style notifications Forever)

Cadre en haut à droite, position sauvegardée. Au repos, le chrome est celui du **chat** : fond noir translucide (0,45), fin bord doré arrondi **copié à l’exécution** sur `ChatFrame1` (pièces `NineSlice`, sinon textures `ChatFrame1…Texture`), repli : bord d’info-bulle fin teinté or. L’icône est dans le cadre carré natif des tuiles, le titre en `GameFontNormal` or, une seule sous-ligne gris clair, la barre bleue native des compétences avec « rang / max » blanc contouré centré. `/drop debug` (section Drops) dit d’où vient le chrome et liste les pièces. Empilés, avec fondu (apparition, maintien, disparition). **Jamais le portrait.**

Le voile bleu-gris (grille du mode édition Forever) n’apparaît **que** lorsque le mode édition est ouvert : le cadre devient alors un élément déplaçable, la position est enregistrée à la fermeture. L’addon sonde `EditModeManagerFrame` (hook `OnShow`/`OnHide`), `EventRegistry` (`EditMode.Enter`/`Exit`), `C_EditMode` et `LibEditMode` s’il est chargé par un autre addon. Si rien de tout ça n’est là, `/drop drops move` reste le repli. `/drop debug` indique ce qui a été trouvé. `/drop drops off` les désactive.

- `PLAYER_XP_UPDATE` : delta de `UnitXP`. En cas de passage de niveau, le reste de l’ancienne barre (`UnitXPMax`) est ajouté à l’XP déjà gagnée au nouveau niveau. Affiche **+N XP** avec l’icône livre de la tuile Niveau (`INV_Misc_Book_11`), la sous-ligne « Niveau 25 · 64 % » (un seul %) et la barre de progression. Si l’XP est une valeur secrète (combat), la lecture est reportée.
- Compétences : différence des rangs sur `SKILL_LINES_CHANGED` / `CHAT_MSG_SKILL` → **Dépeçage +1** avec **l’icône de la compétence**, la sous-ligne « 72 % du palier » (le rang / max est déjà dans la barre) et la barre bleue.

## Lecture des compétences

Sur Forever, `GetNumSkillLines` / `GetSkillLineInfo` n’existent pas (confirmé en jeu). L’addon interroge, avec `pcall` :

1. `C_SkillInfo` (API Forever 1.60.1)
2. `GetNumSkillLines` / `GetSkillLineInfo` (repli)
3. `GetProfessions` + `GetProfessionInfo`
4. `C_TradeSkillUI`
5. `UnitDefense*` / `UnitAttackBothHands` / `UnitRangedAttack`
6. Textes du SkillFrame natif

L’arme équipée est lue via `GetInventoryItemID` / `GetInventoryItemLink` / `GetInventoryItemTexture` et `GetItemInfo` (sous-type et `classID`/`subclassID`), emplacements 16 et 18 (`INVSLOT_MAINHAND` / `INVSLOT_RANGED` ou `GetInventorySlotInfo`).

## Limites (à vérifier en jeu)

- Le hook de l’onglet Comp. suppose `SkillFrame`. `/drop debug` dump les enfants ; **Vue classique** et `/drop` restent disponibles.
- Le bouton latéral de l’onglet Comp. n’a pas un nom documenté : `/drop debug` liste les candidats. `/drop icon off` force l’icône native.
- Un sous-type d’arme non reconnu tombe sur la meilleure mêlée. Vérifier en jeu que les noms français du client (Épées, Bâtons, etc.) matchent bien.
- Plafond de métier éventuellement **> 300** : non chiffré ; Y reste 2460.
- Plafond de la Monte : non documenté ; exclue du total.
- `UnitStat` peut être « secret » en combat.
- Le mode édition Forever (`EditModeManagerFrame`) n’est pas documenté pour 1.60.1 : s’il est absent, utilise `/drop drops move`. `/drop debug` dit ce qui a été sondé.
- Les toasts se calquent sur le chat et les notifications natives ; les textures exactes (anneau d’or, barre de loot) dépendent de ce que le client expose.

## Historique 2.8.0
- Base du scanner WoW Forever, couleurs d'état des rangs (Niveau / métiers / armes),
  XP reposée, style FlareUI (textures Media/Skin), animation de montée de niveau.

## Historique 2.7.2
- Erreur au chargement, sélection des tuiles, bandeau cliquable, tuiles sur 3 lignes,
  bord or unique, bord des drops copié du chat, options rangées en encadrés.

## Historique 2.7.1
- Souillure de la liste native corrigée, survol fluide, style Métiers, options défilantes, sens d'empilement
  des drops, scanner plus robuste (`/drop scanner pourquoi`).

## Historique 2.7.0

- Qualité de vie : estimation mesurée, pré-palier, historique 7 jours, comparaison des personnages, jalons, pêche par zone, rappel de Défense, récap de session, liste de courses, partage Maj+clic, maître d’armes, arme principale.

## Historique 2.6.0

- Scanner discret (butin appris, recettes, barres de nom, info-bulle des nœuds), panneau d’options natif, drops façon toast compact (3 lignes + fine barre), style Léger.

## Historique 2.5.0

- Bouton de vue ancré à la flèche native, style doré, au-dessus de tout ; grille de taille fixe (volet gauche natif), 2 colonnes, identique dans les deux états ; mise en page de tuile unique ; cadre d’icône par-dessus l’icône ; détail du total nettoyé ; filtre des valeurs secrètes ; drops au look du chat ; objectifs, paliers, gains de session, rappel d’arme.

## Historique 2.4.4

- Intégration Comp. réparée : la grille est construite et **ancrée dès le hook** (avant, elle n’avait aucune ancre tant que la vue n’était pas appliquée, donc le bouton « Vue classique » ancré dessus n’était pas dessiné), chaque étape (bouton, grille, filet, détail, icône d’onglet, drops) est isolée : une erreur cosmétique n’empêche plus la grille de remplacer la liste. Les erreurs éventuelles sont écrites une fois dans le chat et listées dans `/drop debug` (section « Intégration onglet Comp. »).
- Nos propres cadres (bouton, grille, détail) ne sont plus jamais pris pour la liste ou le panneau natifs.
- Les lignes natives de la liste (`SkillRankFrameN`, `SkillTypeLabelN`, bouton « Tout »), enfants directs du `SkillFrame`, sont cachées en vue OSRS et réaffichées en vue classique ; re-cachées après chaque mise à jour native (survol / clic gardent le lien avec la sélection native).
- `/drop`, le bouton de minicarte et `UI:Show()` ouvrent l’onglet Comp. ; plus de fenêtre de secours quand le `SkillFrame` existe.
- Barres des tuiles et du panneau droit copiées sur les barres de rang natives : texture de remplissage, fond, cadre `UI-Character-Skills-BarBorder` et géométrie relevés en jeu sur `SkillRankFrame1` / `SkillDetailStatusBar` (repli : valeurs du template natif, barre 15 px, cadre +10 px ancré à -5 px). « rang / max » centré **dans** la barre, compacté (« 96/150 », puis « 96 ») si la place manque, jamais hors cadre.
- Tuiles empilées sur la hauteur de la tuile (chiffre en haut, nom, barre en bas) : plus de chevauchement chiffre / barre ; police du chiffre réduite plutôt que tronquée.
- Cadre d’icône (case à cocher native) **derrière** l’icône, à la taille de l’emplacement, marge transparente rognée : il entoure l’icône sans jamais la couper.

## Historique 2.4.2

- Un seul filet partout (pied, barres, drops, et icônes si la case à cocher native n’est pas trouvée) : la texture du cadre intérieur / séparateur de la fiche Forever (`Inset`, `NineSlice`, `Border`). `/drop debug` en dump le `GetTexture` / `GetAtlas`. Plus l’or maison 1 px autour du pied.
- Pied sans fond plat séparé (le bois du panneau transparaît), largeur strictement celle de la grille, à gauche du séparateur.
- Barres type Comp. (~18 px, fond sombre, remplissage bleu natif, « rang / max » blanc centré). Le **chiffre** de la tuile suit le palier (rouge < 50 %, jaune 50–75 %, vert > 75 %). `/drop couleurs palier|vert|jaune` (défaut palier, enregistré).
- Cadres d’icônes calqués sur les cases à cocher de réputation Forever ; repli sur le filet intérieur unique.
- Bouton Vue classique en haut de la grille, à gauche de la flèche native (plus en bas, plus sur le titre).
- Description native du panneau droit masquée récursivement et re-cachée après les mises à jour natives ; notre détail garde titre, barre remplie (« 96 / 150 »), description dans un `ScrollFrame` à molette, « Compte dans le total » sur une seule ligne centrée.
- Clic : la sélection reste verrouillée (clé persistante, pas l’identité de table). Le survol prévisualise ; en quittant, retour à la tuile cliquée, jamais « Travail du cuir ».
- Drops restylés (chat au repos, voile bleu uniquement en mode édition), déplaçables via le mode édition ou `/drop drops move`. Template `BackdropTemplate` uniquement (plus d’`AlertFrameTemplate`).

## Historique 2.4.0

- Filet d’emplacement de la même taille que l’icône (plus de Quickslot2 64/36 décalé).
- Détail parenté à la colonne droite : caché si on la replie, réaffiché à l’expansion ; plus de textes en double sur la grille.
- « Compte dans le total » uniquement dans le détail, centré ; le pied ne montre que « Niveau total », centré.
- Bouton Vue classique déplacé hors du titre / de la flèche. Plus de spam dans le chat au clic ; `/drop vue` continue d’écrire un message.
- Grille élargie à toute la largeur quand la colonne est repliée. Barres des tuiles à largeur explicite.
- Drops restylés (chat au repos, voile bleu uniquement en mode édition), déplaçables via le mode édition ou `/drop drops move`.
