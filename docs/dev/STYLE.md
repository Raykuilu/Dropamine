# Dropamine : jetons de style (3.3.17)

Guide visuel : **FlareUI** (Malkkav). Addon autonome (aucune dépendance, aucun code
FlareUI) ; aucun fichier image de FlareUI (3.3.17 : bord redessiné par nous, voir
« Licence » plus bas). Thèmes : `flare` (défaut), `leger`, `classic` (textures
Blizzard par chemin, `ClassicTheme.lua`). Toutes les surfaces (panneau,
toasts, cases, pastilles, infobulles, fenêtre du mode édition) utilisent le même
pipeline, `Skin.lua` (`Sk.Host` / `Sk.Paint`).

## Fond et bord (thème « flare », par défaut)
| Jeton | Valeur |
|---|---|
| Fond | `Interface\DialogFrame\UI-DialogBox-Background-Dark` (Blizzard), `tile = false` |
| Couleur du fond | blanc `1,1,1`, alpha = opacité partagée panneau/toasts (`/drop fond`, `/drop opacite`) |
| Bord | `Media\Dropamine-Frame.tga` (notre dessin procédural, `tools/make_frame_border.py`, même rendu que le bord FlareUI ; art gris), `edgeSize 16`, marges `3`, teinté au jeton ; repli en 8 textures sans BackdropTemplate (mêmes cellules, chacune teintée) |
| Couleur du bord | `#A67D45` `{0.65, 0.49, 0.27, 1}` = `ns.STYLE.BORDER`, jeton unique (panneau, toasts, cases, pastilles, total, JcJ), alpha toujours 1 |
| Bord au survol | `{0.98, 0.74, 0.36}` |
| Bord actif | `{1, 0.86, 0.46}` |
| Bord de séparation (réglages) | `{0.55, 0.42, 0.24}` |
| Infobulle (référence FlareUI) | bord `#CC9957` `{0.80, 0.60, 0.34}`, fond `{0.05, 0.05, 0.06, 0.9}` |
| Échelle | toujours 1 ; la taille (`/drop taille`) change les cases, pas le bord |

## Thème « leger »
Pas de fond ni de bord de panneau ; les cases flottent (bord fin bronze, même jeton),
les poignées n'apparaissent qu'au survol.

## Bord d'icône (3.3.15, d'après la capture de référence)
Net à toute taille : par côté 3 bandes de 1 px (ombre noire 0.70 dehors, filet au
jeton à alpha 0.72, liseré intérieur = jeton × 0.35 opaque) + 4 coins biseautés
`Media\OSRS-IconCorner.tga` (4 × 4, pivotés par coordonnées) ; masque d'icône
`Media\OSRS-IconMask.tga` (coins coupés) ; icône recadrée 0.08–0.92. QC : 
`tools/preview.py` (rendu PIL à côté de la référence, écart ≤ 8/255 sur le filet).

## États (sens, pas décor)
- Le MÊME bord d'icône change de couleur, jamais de trait carré à part :
  repos bronze, cible verte `{0.25, 1, 0.25}`, sélection or `{1, 0.86, 0.46}`.
- Cible FORTE (« +1 », vert plein + voile 0.16) : on frappe vraiment (attaque auto,
  tir / baguette, en forme pour Farouche ; Défense : la cible nous frappe).
- Cible DISCRÈTE (« + », vert à 45 %, voile 0.07) : cible éligible, pas de frappe.
- Armes : seules les armes équipées (16 / 17 / 18) sont éligibles.
- « +1 » en haut à gauche dans la case, pastille « N prêt(s) » centrée au-dessus :
  jamais l'un sur l'autre.
- Barres de nom : anneau vert (point possible) / gris (aucun point).
- Au repos : toujours bronze.

## Cases
- Bord de case : `#A67D45` (`ns.STYLE.BORDER`), liseré intérieur `{66,52,34}/255`.
- Masque arrondi : `Media\RoundMask` (repli : masque d'icône Blizzard / recadrage 0.08–0.92).
- Ombre douce : `Media\SoftShadow`, alpha 0.30, décalage −1.
- Pastille « N prêt » : hauteur 11, mord 4 px sur le haut de la case.
- Barre Niveau total (si affichée) : 45 % de la hauteur d'une case (min 14 px), jauge
  de 3 px `#A67D45` sur fond noir à 0.55.

## Espacements
- Marge du panneau : 10 px sur les 4 côtés (plus la place d'une pastille en haut).
- Marges du bord : 3 (épais) / 4 (fin, 8 px).
- Pas des cases : case + 8 px (taille 100 %), recalculé de 50 à 200 %.

## Textes
Polices du jeu (FlareUI utilise Roboto Condensed / Marcellus, sous licence OFL /
Apache, non embarquées) :
- titre de fenêtre : `GameFontHighlightLarge` ;
- en-tête de section : `GameFontNormal`, jaune `{1, 0.82, 0}`, séparateur
  `Interface\Common\UI-TooltipDivider-Transparent` ;
- libellés : `GameFontHighlightSmall`.

## Contrôles (fenêtre du mode édition)
- Curseur : ◀ ▶ (`UI-SpellbookIcon-Prev/NextPage`), curseur `OptionsSliderTemplate`,
  case numérique `InputBoxTemplate` (38 px).
- Menu déroulant : bouton habillé (fond à 0.6), flèche `UI-ChatIcon-ScrollDown-Up`,
  liste habillée (0.95), surbrillance `UI-QuestTitleHighlight`.
- Boutons : rouges Blizzard (`UIPanelButtonTemplate`).

## Licence
FlareUI : licence MIT pour le **code** seulement ; `Media/Art`, les barres et les
icônes sont explicitement « non licenciés pour réutilisation » ; les bordures,
panneaux et masques sont ambigus. 3.3.17 : plus AUCUN fichier FlareUI dans
`Media/`. Le bord (`Dropamine-Frame.tga`), le filet fin (`Dropamine-Thin.tga`) et
la piste de jauge (`Dropamine-Bar.tga`) sont générés par notre script
`tools/make_frame_border.py`. Tout le reste est Blizzard (par chemin) ou dessiné
pour l'addon (`OSRS-IconCorner.tga`, `OSRS-IconMask.tga`, `RoundMask.tga`,
`SoftShadow.tga`, `Media/Skin/*`).
