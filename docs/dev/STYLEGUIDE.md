# Guide de style — OSRS Total Level (3.3.1)

## Règle 3.3.1

- Icône : 3 colonnes verticales R (0.82,0.12,0.10) / V (0.16,0.66,0.16) / B (0.16,0.38,0.88) sur fond (30,19,8), marges 14 %, écarts 7 %, en `SetColorTexture` (aucune texture de fichier). `Media/SkillsTab.tga` = même dessin.
- Onglet latéral : cadre `SpellBook-SkillLineTab` codé en dur ; jamais de texture lue sur un autre cadre ; écart = écart mesuré entre onglets + débord du cadre (11/32 de la taille), sous le bas VISIBLE de l’onglet du dessus.
- Volet de droite : texte courant à 22 px des bords gauche et droit du volet ; bandeaux d’en-tête à 6 px.


## Règle 3.3.0 : icônes seules, couleurs natives, jamais de gris

- Case 40×40, icône 36 (cadre d’emplacement natif), écart 8 / 6, pas 46. Rang en bas à droite de l’icône (`NumberFontNormal`, contour), blanc ; emplacement libre : « 0 » brun clair.
- Survol : `ButtonHilight-Square` (ADD) + info-bulle. Sélection : `CheckButtonHilight` (ADD) + surbrillance de la case.
- Fenêtre 640×470, liste 262 px. Couleurs mesurées sur refs/native-284.png : fond (34,23,15), liste (19,11,2), titre (49,28,13), bordure `UI-Tooltip-Border` teintée (135,100,57), séparation (24,17,9).
- Aucun aplat gris (test `test_v330` : canaux égaux entre 0,12 et 0,85 interdits ; textures « rock / marble / tooltip-background / dialogbox-background » interdites).
- Barre du volet de droite : la barre 3.2.0 (dégradé (0,50,97)→(31,92,159) sur (25,14,0), 24 px, texte blanc « rang / max »).


## Règle 3.2.0 : une fenêtre à nous, l’onglet Comp. intact

- Fenêtre `OSRS_TotalLevelWindow` 790×540 (gabarit `PortraitFrameTemplate`, repli bordure `UI-DialogBox-Border`), zone liste 440 px, volet de droite le reste ; filets fins couleur filet natif mesuré.
- Bouton du micro menu (3.3.2, remplace l’onglet latéral) : textures d’état du bouton Personnage (chemins Blizzard uniquement, jamais AddOns), repli `UI-MicroButtonCharacter-Up/-Down` + `UI-MicroButton-Hilight` ; 3 piliers à la place du portrait ; ancré au dernier bouton visible de la rangée avec l’écart mesuré ; aucun bouton natif déplacé.
- Rang des cases (3.3.3) : « actuel » sur « /max », Arial Narrow contouré, aligné à droite, 8 à 13 px, jamais plus large ni plus haut que la case.
- Bronze (3.3.3, mesuré sur refs/native-bronze-333.png) : filet 1 px (115,91,56) + ombre intérieure 1 px (66,52,34) ; cadres des cases, du panneau et de la barre du détail. Plus de UI-Quickslot2 ni de bordure d’infobulle.
- Lanceur en colonne verticale : TOP sur le BOTTOM du dernier bouton, écart vertical mesuré, même centre ; segment de fond/bordure à nous sous lui (couleurs du cadre natif lues, sinon mesurées : fond noir 70 %, bordure (140,112,86)/(62,42,30)).
- Barre unique pour toutes les tuiles (`V.BAR_STYLE = "osrs-3.2.0"`), aucune lecture de barre native.


## Règle 3.0.0 : valeurs mesurées sur la capture native (refs/native-284.png)

| Élément | Valeur native mesurée |
|---|---|
| Barre (boîte extérieure) | 24 px de haut ; remplissage 17 px ; retraits 3 (côtés) / 4 (haut) / 3 (bas) |
| Remplissage | dégradé horizontal (0,50,97) → (31,92,159) ; haut/bas assombris ~55 % |
| Fond de barre | (25,14,0) |
| Filets | haut (184,161,136), bas (121,98,72), côtés (105,89,67), liseré intérieur (8,5,0) |
| Texte de barre | blanc |
| En-tête | 28 px, fond (47,28,13), filet haut (78,67,57), bas (53,45,38) |
| « − » d'en-tête | jaune (255,223,0), 15×3 px, à 6 px du bord droit — seul indicateur |
| Surbrillance | additive ≈ 0,22 (85,78,71 sur 29,19,10), toute la tuile, sous le contenu |

`tests/measure_refs.py` re-mesure la capture et vérifie ces valeurs dans `View.lua`.


## Règle 2.8.2 : la vue OSRS fait partie de la vue classique

- **Aucun fond à nous** (grille, tuiles, bandeau, panneau de droite) : seul le fond de la fenêtre native se voit.
- **En-têtes de groupe** : « Combat », « Métiers », « Métiers secondaires », barre relevée sur une ligne d'en-tête
  de la liste native (lecture seule, mémorisée) ; repli : bandeau or translucide dégradé vers la droite. Texte
  `GameFontNormal` or. Hauteur 18 px, 2 px avant les tuiles.
- **Ordre** : Niveau, Mêlée, 2e tuile de combat (selon la classe), Défense | Métier 1, Métier 2 | Cuisine, Pêche,
  Secourisme. 2 colonnes, ligne par ligne, tassé en haut dans chaque groupe.
- **Tuile** : icône dans un emplacement d'objet natif carré (fond d'emplacement vide, icône rognée 0,07–0,93,
  cadre carré relevé sur `CharacterHeadSlot`, repli `UI-Quickslot2`), pas d'anneau ni de masque rond. Nom en
  **blanc** à gauche, rang **coloré par palier** à droite sur la même ligne, barre fine de 4 px en bleu natif
  avec filet 1 px gris-acier. Emplacement libre : texte gris, icône désaturée ; « Métier à choisir » = emplacement vide.
- **Survol / sélection** : rectangle blanc arrondi (coins 6 px, `Media/Skin/Highlight.tga` en 9 morceaux ;
  repli : blanc uni), sans bordure, sous l'icône et le texte. Survol 10 %, sélection 16 %.
- **Clic** : un bouton plein cadre par tuile = la cellule + la moitié des espaces voisins (cellules jointives),
  au-dessus de tous nos cadres ; tout le reste sans souris.
- **Bandeau du total** : bouton d'en-tête natif (relevé sur « Adversaire de niveau égal » / « Récompenses au
  rang N »), texte blanc centré ; cliquable.
- **Panneau de droite** : natif tel quel pour une arme / la Défense que le natif affiche ; sinon nos sections à
  en-tête natif (texte blanc centré) et lignes deux tons (libellé or `#FFD100`, valeur blanche).
- Les **drops** gardent leur aspect (composant figé ci-dessous).



## Composant de référence (2.8.1) : le drop

Le drop validé par l'utilisateur (« +40 XP / Niveau 2 · 5 % / Niveau 3 dans ~7 min »,
« Défense +1 / Rang 6/10 / ~1 min par rang (mesuré) ») est LA référence visuelle. Son
aspect est figé (test « Aspect figé du drop » dans tests/test_v281.lua) :

- cadre 260 × 56 px (ligne d'astuce comprise), fond sombre translucide repris du
  chat (opacité par défaut 68 %, réglable), bord bronze du chat (repli : Border.tga) ;
- icône ronde 32 px avec anneau (IconRing + IconMask, repli : cadre biseauté), à 7 px
  du bord haut-gauche ;
- hiérarchie du texte : titre or GameFontNormal, ligne blanche GameFontHighlightSmall,
  astuce verte (0,25 / 1 / 0,25) GameFontHighlightSmall ;
- fine barre native de 4 px en bas, à 7 px des côtés et 6 px du bas, sans texte.

Comportement 2.8.1 (sans changer l'aspect) : cumul tant que visible (« Dagues +1 » →
« +2 », « +125 XP (3 monstres) », « (quête) »), petite impulsion du titre, minuterie
relancée à chaque gain, survol = drop tenu, clic gauche = onglet Comp. sur la tuile,
clic droit = fermer, 5 drops visibles au plus.

Alignement des autres éléments sur cette finition :

- **Grille et panneau de détail** : dégradé brun clair Métiers (#211C18 → #3A2C24,
  toujours dessiné en WHITE8X8 + SetGradient, jamais dépendant d'une texture) + filet
  bronze #634D36, avec le bord du drop par-dessus.
- **Bandeau du total** : finition complète du drop (fond translucide + bord).
- **Tuiles** : icône ronde à anneau, nom or, rang coloré par état, fine barre 4 px.
- **Montée de niveau** : c'est un drop (variante or, grande).
- **Options** : exception voulue — couleurs de base façon Questie (voir plus bas).

## Panneau d'options (2.8.1, façon Questie)

Aucun fond à nous : le fond natif du panneau Options reste visible. Chaque groupe :
titre jaune GameFontNormal au-dessus ; encadré = bord d'info-bulle natif
(Interface\Tooltips\UI-Tooltip-Border, 16 px) teinté or (1 / 0,82 / 0, 80 %) sur un
voile noir à 25 % ; cases natives (InterfaceOptionsCheckButtonTemplate) avec libellé
jaune GameFontNormal juste à droite et description blanche GameFontHighlightSmall
dessous ; 2 colonnes alignées (x = 12 et 300) ; choix en menu déroulant natif
(UIDropDownMenuTemplate) ; curseurs natifs (OptionsSliderTemplate) pleine largeur,
libellé au-dessus, valeur à droite, bornes min / max aux deux extrémités. Rectangles
sans chevauchement vérifiés par les tests.

## Emplacements libres (grille fixe de 9)

Niveau, Métier 1, Métier 2, Cuisine, Pêche, Secourisme, Mêlée, Distance/Farouche,
Défense, tassés en haut. Un emplacement manquant est grisé (#808080) : métier
principal = case vide « Métier à choisir », secondaires = icône désaturée, « 0/75 »,
« non appris » ; barre vide ; hors total ; sélectionnable (détail : où apprendre).

---

# Historique : FlareUI (2.8.0)

Source unique des couleurs : `Style.PALETTE` (Style.lua). Source unique des textures :
`Style.FLARE` → `Media/Skin/*.tga`. Aucune autre couleur de bord ou d'encadré dans le code.

## Référence

Capture FlareUI pleine résolution `bf7d98bd….png` (2885 × 1404) : fenêtre d'options
FlareUI 6.9, page « Sacs et butin ». Chaque valeur est un pixel relevé (pas une moyenne) ;
coordonnées en pixels de la capture. Planche de comparaison : `refs/flare_v280_preview.png`
(à gauche la capture, à droite nos textures).

## Palette

| Clé | Hex | Rôle | Relevé (x, y) |
|---|---|---|---|
| borderOuter | #181513 | bord d'encadré : trait sombre extérieur | (1300, 333) |
| borderGold | #624F32 | bord d'encadré : filet or | (1300, 334) |
| borderInner | #463824 | bord d'encadré : filet bronze | (1300, 335) |
| borderDark | #161412 | bord d'encadré : trait sombre intérieur | (1300, 336) |
| divider | #796345 | filet 1 px sous l'en-tête de section | (1500, 371) |
| windowBg | #443F38 | fond de fenêtre (gouttière) | (1600, 150-200) |
| panelBg | #302C29 | panneau de contenu | (1240-1700, 250-270) |
| sidebarBg | #2C2924 | barre latérale, encadré d'info | (990-1200, 600-640) |
| sectionBg | #272320 | intérieur d'un encadré | (1300-1500, 420-430) |
| inputBg | #26231F | champ « Rechercher… » | (2100, 165) |
| titleYellow | #FFD800 | titre, en-têtes, « Réinitialiser », « Par défaut », « Astuce », onglet non choisi | (1255-1420, 345-370) |
| labelWhite | #FFFFFF | libellés d'options, onglet choisi | (1255-1335, 393-410) |
| bodyText | #DFDFDF | texte de l'encadré d'info | (2033-2330, 505-540) |
| sidebarText | #DFD4BE | libellés de la barre latérale | (1025-1100, 225-245) |
| subtitleGrey / helpGrey | #B0A699 | sous-titre, version, aide courte | (1300-1540, 253-268) |
| categoryText | #B49B6D | catégories de la barre latérale | (990-1060, 330-345) |
| checkEdge | #685948 | bord de case | (1572, 435) |
| checkBox | #190E00 | intérieur de case (haut, dégradé vers #241F19) | (1572, 437) |
| checkGold | #FDED23 | coche (dégradé vers #DAC401) | (1572, 444) |
| sliderEdge | #504131 | filets de la piste | (1650, 394) |
| sliderTrack | #1A1815 | intérieur de la piste | (1650, 398) |
| thumb | #A97B59 | losange cuivre (reflet #E2C7B0, ombre #76573C) | (1626, 401) |
| tabEdge | #927450 | liseré or des onglets (haut #98815E, bas #6B4F2D) | (1241, 303) |
| buttonTop → buttonBottom | #5F5F5F → #282727 | dégradé gris des onglets / boutons | (1250, 293-315) |
| selectedRow → selectedRowEnd | #A97B3D → #43321D | ligne sélectionnée (dégradé horizontal) | (1000-1200, 846) |
| selectedAccent | #FDD271 | accent or 2 px à gauche de la ligne sélectionnée | (981, 846) |
| iconRing | #756451 | anneau or des icônes rondes (puis #6E5941, #63503A) | (1019, 225-227) |
| scrollThumb | #603F21 | ascenseur (reflet #896036, ombre #714B2D) | (1988-1993, 500) |

## Textures (Media/Skin, TGA 32 bits, origine en bas à gauche)

| Fichier | Taille | Usage | Découpe |
|---|---|---|---|
| Border.tga | 32×32 | bord d'encadré or 4 px, coins biseautés 3 px, centre transparent | 9 tranches, coins 8 px |
| Button.tga | 64×32 | onglet / bouton gris liseré or | 9 tranches, coins 6 px |
| Dropdown.tga | 64×32 | liste déroulante (liseré #836947 / #6E5230) | 9 tranches, coins 6 px |
| CheckBox.tga | 32×32 | case vide | entière |
| CheckMark.tga | 32×32 | coche jaune ombrée | entière |
| SliderTrack.tga | 64×16 | piste du curseur | étirée en largeur |
| SliderThumb.tga | 32×32 | losange cuivre | entière (affichée 24 px) |
| RowSelected.tga | 128×32 | ligne / tuile sélectionnée | étirée |
| IconRing.tga | 64×64 | anneau or rond (icône masquée en rond) | entière |
| IconMask.tga | 64×64 | masque rond (si `CreateMaskTexture` existe) | entière |
| IconFrame.tga | 64×64 | cadre biseauté (repli sans masque) | entière |
| ScrollThumb.tga | 16×64 | ascenseur | étiré |
| Arrow.tga | 32×32 | flèche jaune (listes, flèches) | entière, SetTexCoord pour l'inverser |
| Divider.tga | 64×4 | filet 1 px #796345 | étiré |
| LightBurst.tga | 128×128 | éclat doré (montée de niveau), mode ADD | entière |
| Glow.tga | 64×64 | lueur or de bord (pulsation), mode ADD | 9 tranches, coins 12 px |

API : `SetTexture`, `SetTexCoord`, `SetVertexColor`, `SetBlendMode`, `CreateAnimationGroup`
(Alpha, Scale). Le masque rond n'est utilisé que si le client expose
`CreateMaskTexture` / `AddMaskTexture` ; sinon l'icône reste carrée, rognée (0,08-0,92),
sous `IconFrame.tga`.

## Bord or (un seul style)

- 4 px : #181513 / #624F32 / #463824 / #161412, coins biseautés.
- Encadrés (options, grille, détail, bandeau) et cadre de drop en repli.
- Drops : le vrai bord du chat est copié d'abord (NineSlice, backdrop, enfants) ;
  Border.tga n'est que le repli. `/drop debug` donne la source.
- Variantes de drop (objectif, palier, montée de niveau) : `SetVertexColor` sur Border.tga.

## Icônes

- Tuiles et drops : icône 3 px en retrait, anneau `IconRing.tga` (masque disponible)
  ou cadre `IconFrame.tga` par-dessus (couche OVERLAY). Rien de gris dessous.

## Polices

| Usage | Police / couleur |
|---|---|
| Titre du panneau | GameFontNormalLarge, #FFD800 |
| En-tête de section, nom de compétence, titre de détail | GameFontNormal, #FFD800 |
| Libellé de case / radio / curseur | GameFontHighlight, #FFFFFF |
| Valeur de curseur | GameFontNormal, #FFD800 |
| Onglet | GameFontNormalSmall, blanc si choisi, #FFD800 sinon |
| Rang d'une tuile | GameFontHighlightSmall, couleur d'état (voir ci-dessous) |
| Aide | GameFontDisableSmall, #B0A699 |
| Drop de montée de niveau | GameFontNormalLarge |

## Couleurs d'état des rangs (mode « Palier »)

| Tuile | Vert | Jaune | Rouge | Or neutre |
|---|---|---|---|---|
| Niveau | XP du niveau > 75 % | 50-75 % | < 50 % | niveau maximum |
| Métiers, Cuisine, Pêche, Secourisme | rang suivant apprenable | il manque des points ou un niveau | bloqué au maximum actuel (niveau manquant ou seuil non documenté) | 300/300 |
| Armes, Défense | au maximum actuel | moins de 25 points sous le maximum | 25 points ou plus sous le maximum | — |

## Espacements

| Mesure | Valeur |
|---|---|
| Largeur du contenu des options | 600 px |
| Marge du contenu | 8 px ; marge intérieure d'encadré 12 px |
| En-tête → filet | 18 px ; filet → premier élément 8 px |
| Ligne de case / onglets | 26 px (ligne d'onglets supplémentaire 22 px) |
| Onglet | 122 × 22 px, pas de 130 px |
| Bloc curseur | 46 px ; aide 16 px ; entre encadrés 10 px |
| Grille : écart entre tuiles | 8 px / 6 px |
| Drop : hauteur | 46 px (Complet), 64 px (montée de niveau) |

## Contrôles

- Case : CheckButton, `SetNormalTexture(CheckBox)`, `SetCheckedTexture(CheckMark)`,
  survol `Glow` en ADD ; deux colonnes (x = 12 et 300).
- Choix (radio) : onglets `Button.tga` alignés à x = 160 ; choisi : texte blanc, texture
  pleine ; non choisi : texte #FFD800, texture à 78 %.
- Curseur : `SliderTrack.tga` pleine largeur, `SliderThumb.tga` 24 px, libellé au-dessus,
  valeur à droite.
- Ascenseur : `ScrollThumb.tga` sur le ScrollFrame des options.
- Liste déroulante / flèches : `Dropdown.tga` + `Arrow.tga` (réservés, aucune liste
  dans le panneau pour l'instant).

## Anatomie d'un encadré

1. `Border.tga` 9 tranches. 2. Fond #272320 à 3 px. 3. En-tête #FFD800 à 12 px.
4. Filet 1 px #796345. 5. Éléments. 6. 12 px de marge basse.

## Animation de montée de niveau

- Ne remplace jamais la bannière officielle : drop dans la pile des drops.
- Drop 64 px « Niveau X atteint ! », sous-titre « Niveau total : N (+1) », bord or teinté.
- `Glow.tga` (ADD) : Alpha 0 → 1 → 0,25 → 1 → 0 (1,95 s).
- `LightBurst.tga` (ADD) 128 px sur l'icône : Scale 0,5 → 1,4 et Alpha 0,95 → 0 (1,2 s).
- Tuile Niveau : une pulsation `Glow.tga` à la prochaine ouverture de l'onglet.
- Variante légère (rang de métier) : drop « Léger » + lueur, sans éclat.

## Structure du panneau d'options (ordre final)

1. **Notifications** : Drops activés · Drops d'XP · Drops de compétence · Annonce de
   palier · Objectif atteint · Coller au chat (aide) · Animation de montée de niveau
   (aide) · Son · Style Complet / Léger (aide) · Sens d'empilement · Durée d'affichage ·
   Opacité du fond.
2. **Apparence** : Couleur des rangs Palier / Vert / Jaune · Afficher les
   caractéristiques · Style de la fenêtre Métiers.
3. **Scanner** : Scanner activé · Icônes sur les créatures · Toast · Son.
4. **Qualité de vie** : réglages du module QoL.
5. **Grille** : Gains de session dans le bandeau · Rappel d'arme sous-montée.


## 2.8.3 — relevé natif
- Tout ce qui ressemble au natif est **lu** sur la liste et le détail natifs (textures, atlas, coordonnées, couleurs `GetVertexColor`/`GetStatusBarColor`/`GetTextColor`, objets de police `GetFontObject`, tailles, marges), mémorisé dans `DropamineDB.nativeAssets` ; replis uniquement si rien n'a pu être relevé.
- Tuile : nom en haut (marge 3 px), barre native pleine hauteur dessous, rang dans la barre.
- Panneau droit : titre/barre centrés, texte à gauche sur la marge native.


## 2.8.4
- Vue classique : aucun cadre de l'addon visible ni sensible à la souris sur la fiche.
- En-têtes de section : Button plein cadre, icône +/− native, repliables.
- Surbrillance ancrée au bouton de tuile ; cadre de barre toujours dans la tuile.
- Détail : titre + valeur centrés, texte de barre blanc, lignes or/blanc, pied sous le contenu.
- Replis de couleur barre : remplissage (0 ; 0,40 ; 1), fond (0 ; 0 ; 0 ; 0,75).


## 3.0.1 : mesures complémentaires (normalisées : échelle = largeur barre native / 200 px)

- Pas de ligne natif 40 px, en-têtes 28 px ; pas OSRS = clamp((hauteur dispo − groupes × en-tête) / lignes tout déplié, minimum, 62).
- Filets de liste natifs : haut y≈108, bas y≈597 (native-284.png) — conservés.
- Volet de détail : bas du titre 13 px au-dessus du filet ; description 22 px à gauche du bord gauche de la barre, bord droit = bord droit de la barre, 18 px sous la barre, interligne 14.
- Barres des tuiles : hauteur et largeur natives fixes, jamais étirées avec la tuile ou la fenêtre.


## 3.1.0 : grille native

- Rien n'est redessiné pour une ligne qui existe en natif : on la déplace (SetPoint / SetSize hors combat), son rendu reste celui du jeu.
- Cellule : icône 32 à gauche (V.TEXT_X = 40), nom natif en haut, barre native dessous à sa taille native (largeur bornée par la colonne).
- Nos éléments (tuile Niveau, emplacements libres, bandeau Niveau total) copient le rendu natif relevé (barre, police, en-tête).
