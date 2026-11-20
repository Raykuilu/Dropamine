# Changelog

## 3.6.3
- test8: the compact frame always uses the *current* tile size (scale slider / `/drop taille`), for every column count including defaults — never the old 40 px / 262-wide list. Recomputed on the size slider. The last tile no longer overlaps the right border; the frame ends 12 px below the total bar, with no leftover gap.
- test8: flask states (rest, campfire, combat, fishing, eating, flight, death, …) only swap the official *total vial icon*. The total bar and its number stay visible at full width, as a plain static fill. No profession-tile badges, no state animation on the bar, no frame change driven by a state. Rest is a guideline icon (dark disc + cream/bronze Z, gentle float), not a plain letter. Combat uses a single basic sword (`INV_Sword_04`).
- test8: `/drop test totaladd red|blue|green` (and live gains) tint the falling drop correctly. After the drop hits, one pooled spark in the same color travels the bar to the current fill tip and flashes briefly (~0.6 s, alpha back to 0, no per-frame allocation).
- Panel frame fits the grid or total bar exactly: `cols×tile + (cols-1)×gap` wide, and either `rows×tile + (rows-1)×gap` (grid) or skill-rows plus the slim total bar (when `/drop total on` widens the last row). Same 12 px margin on all four sides. Recomputed on resize, column change, scale change, and when a flask state / `/drop test` ends. The old 5-column list pad and trailing gap (about one tile empty on the right and half a tile at the bottom) are gone.
- Flask states that replace the official vial (no superposition, no bands): fishing keeps the validated Fishing-Sheet hook on the total tile; combat uses a single sword (`INV_Sword_04`); campfire uses `Spell_Fire_Fire`; eating uses a fork-and-knife / cup / split disc; rest in an inn (`IsResting`) uses a single cream/bronze Z with a gentle hourglass-like float/fade (lowest priority). The vial is restored cleanly afterwards. `/drop test` still does not auto-open the explanation tooltip.
- The only animation kept *on* the official vial is add-to-total (falling drop). Red is XP; blue is weapon/defense skill-ups; green is profession skill-ups. Same motion, tinted with the bar segment colours.
- Pooled state icons and rest Z (created once, reused, hidden on end). A 500-cycle `/drop test` loop regression asserts no new frames/textures/fontstrings and bounded memory.

- Sleeping bag, style A: while the Well-Rested aura (spell 429959, 1–3 stacks, +1% XP gained per stack) is building out of combat, the flask well shows the style-A icon with 1, 2 or 3 bands, clipped in the icon in bar and grid layouts. Priority is just before rested “z”. Leaving before 3 stacks fires one XP-tinted toast: “Sac de couchage : 2/3 %”, “1 % manqué”, hint “Bien reposé”, with the icon at the reached step. At 3/3 there is no miss toast and no confirmation. `/drop test sleepingbag 1|2|3|miss` (DEV).
- Mob-kill XP no longer fires a toast (the flask wave/fill animation still runs). A discreet XP-tinted milestone toast is shown at 25%, 50% and 75% of the current level (“Niveau 6 · 50 %”), once per threshold per level (already-reached thresholds are seeded silently on login). Quest turn-in XP still gets one toast, and the real level-up toast is unchanged.
- Recipe and “Recette possible” toasts (DEV test and live) show the profession icon (`Trade_LeatherWorking` for leatherworking), not the item or a generic bag/pouch icon. The XP vial icon is unchanged.
- CPU: player aura scans (eating, Well-Rested, fishing channel) run only on UNIT_AURA / channel events for `player`, after a short coalescing timer, and are cached for Live* checks. `SetSize` on flask clip frames and textures is skipped when the size is unchanged. Bag-full counting runs on `BAG_UPDATE_DELAYED` only (not on `BAG_UPDATE` spam, nor on every Refresh). The flask OnUpdate driver still stops when no animation is active (the sleeping-bag icon is static). Toast tint and per-character profile writes skip work when nothing changed.
- Bags-full toast: only general bags (bagType 0) are counted, via `C_Container.GetContainerNumFreeSlots` (backpack 0..NUM_BAG_SLOTS and the reagent bag if any). Profession, quiver, ammo, soul bags and the keyring are ignored. A transient 0 during BAG_UPDATE or loading is ignored; the toast fires only after a confirmed 0 free general slots (debounced, also on BAG_UPDATE_DELAYED). A failed API read is not treated as 0.
- Display settings are saved per character (profile keyed by name-realm in DropamineDB). Existing account settings are copied as the default for every character. The active profile is applied before the UI is built, and option changes are written to that profile immediately (not only at logout). “Use account settings” remains available (`/drop profil compte`).
- Toast tint keeps the same background opacity as before the tint (the `/drop drops opacite` / Fond des toasts setting, and the fade in/out). Only the tint colour changes; `_tintFill` no longer paints at alpha 1.
- The +75 XP toast keeps the red XP vial icon (`XP-Icon`), not the empty outlined fallback vial. Profession toasts still replace a missing or XP-vial placeholder with the profession icon.
- Recipe “possible” toasts no longer start with a stray × when the craft count is missing or 1 (`× Viande de sanglier rôtie possible`). The `N ×` prefix is used only for 2 or more. Long titles still use the existing single-line marquee and hover tooltip.
- Flask liquids (eating wave, combat fill, rested z) are clipped inside the drop icon in every display mode: bar and 1/2/3/5-column grids. Clip and textures are explicitly sized from the icon (the small bar-mode drop is ~14 px, not a default 100×50 block). Combat in bar mode stays on the horizontal segments only.
- `/drop mem` reports addon memory (`GetAddOnMemoryUsage` before and after `collectgarbage`) and a breakdown of retained tables: SavedVariables (per-character session history, farm spots, recipes, history), the old `OSRS_TotalLevelDB` copy if still loaded, ScannerDB and learned-creature cache, name/recipe indexes, locales, UI snapshot. At login, duplicate static scanner creatures are dropped (cap 2500 learned NPCs), daily history is pruned to 35 days on every character, session recaps are compacted (slim profit/spots, 30 sessions, 104 weekly aggregates).
- Recipe toasts and profession lines no longer show "item 159" (or "objet 159") when the item name is not yet in the client cache. Until the name arrives, only the recipe is shown ("Boiled Clams (+1)"); the toast then updates, for example to "Refreshing Spring Water: Boiled Clams (+1)". The same applies to shopping lists, "learn soon" lines and target highlights. Names are resolved with Item:CreateFromItemID / ContinueOnItemLoad when the client has them, otherwise GetItemInfo and GET_ITEM_INFO_RECEIVED.
- New option **Pause while flying** (Options › Display, on by default): on a flight path (`UnitOnTaxi("player")`), the profession tracker, nameplate scans, mouseover/target toasts and all toasts/popups are paused. Nothing is queued, so landing does not dump a backlog. `/drop vol on|off` (or `/drop flight on|off`).
- On a flight path, the drop on the total flask is replaced by a bronze hourglass that fits exactly in the drop's slot (same size and anchor, clipped under the bronze frame). A 32-frame sprite sheet (26 of sand draining from the top bulb into the bottom with a thin stream, then 6 of a 180° flip in 0.4 s) is cycled with SetTexCoord; one texture, no AnimationGroups, no SetRotation. About 3 s per cycle. The panel dims slightly (×0.75) and the flask tooltip adds “Paused while flying” and “Scanning resumes as soon as you land.” Hovering the hourglass or the flask during flight shows that explanation (title + line). On landing, the drop and full opacity fade back in 0.5 s. Follows the **Pause while flying** option. Throttled OnUpdate at 20 fps, stopped when hidden.
- The first time flight pause starts on a character, one Dropamine toast explains it (hourglass icon): “Tracking paused while flying. Scanning resumes as soon as you land.” It is a normal toast (auto-fade, usual click behaviour). Once per character (SavedVariables). `/drop reset-hints` shows it again.
- Taking a flight path is detected live, without a `/reload`: a 0.5 s poll of `UnitOnTaxi("player")` stays on (the OnUpdate frame is shown), and `PLAYER_CONTROL_LOST`, `TAXIMAP_CLOSED` and `UNIT_FLAGS` (player) are re-checked at 0.1 s, 0.5 s and 1.5 s, because `UnitOnTaxi` is often still false when control is first lost. Landing is detected the same way (`PLAYER_CONTROL_GAINED` plus the poll).
- Toast titles and detail lines stay on a single line. A long name is clipped and scrolls horizontally (after a short pause) instead of wrapping onto a second line; toast height stays the same. Hovering a toast pauses the scroll and the auto-fade timer; both resume when the cursor leaves. A GameTooltip shows the full untruncated text. Recipe and craftable toasts also list the profession, required rank, difficulty colour, how many you can craft now, any missing reagents, and the item tooltip (`SetItemByID` / `SetHyperlink`) when the item id is known.

- The drop in the total flask now shows what you are doing: one symbol at a time, clipped in the drop's slot (sprite sheets, 20 fps, no AnimationGroups). Priority: death (skull, flask drained and grey, tracking paused until resurrection) > flight (hourglass) > AFK (bronze clock) > fishing (bobbing hook while the channel is up, a jolt when the catch hits the bags) > swimming (bubbles) > resting z's (only while actually in an inn or capital, wave fill stays on the level tile) > the drop. A nearby profession trainer adds a glint on the profession tile, not the flask. Each symbol has a hover tooltip and an option (on by default). Combat is a Display setting, **Combat style**: **Bubbles** (default, mockup A: the flask stays, red+blue rise and fill with a waving surface and warm amber bubbles, green fades out; after combat the liquid recedes and green fades back in), **Sword** (mockup C: the same liquid plus a small bronze sword in the slot, at priority just below flight), or **Off**. The flask tooltip in combat reads “In combat: XP and weapon skills in progress.” Interrupted combat/death transitions (re-entering mid-drain, reload in combat, death in combat) always settle on the correct final state. No combat blink or panel dim.
- In a capital or a city with trainers, when a profession has a higher rank available at the trainer (the same “Rank up available” logic as the tile tooltip), a sticky toast reads “<Profession>: next rank available at the trainer” (one combined toast if several). It stays until clicked or until that rank is learned, is exempt from auto-fade and the toast cap, and reappears on every capital entry while still unlearned. It is not shown in flight or combat (it queues until those end). Option on by default.

- Flask signal and one standard toast when bags are full (“Bags full: loot will be lost”), once until a slot frees up. Option on by default (Options › Display, hover help only). `/drop test bags`.
- **Pause while flying** now also covers boats, zeppelins and the tram (`UnitOnTaxi` is false there). Same hourglass and the same clean resume on arrival (no toast backlog). No first-flight hint for a transport. `/drop test transport`.
- Loading screens and cinematics pause tracking silently and resume without dumping queued toasts. Always on (not behind the flying option). No hourglass for a loading screen. `/drop test loading`.
- While a food or drink regeneration buff is active (not Well Fed), a gentle wave plays in the flask. Can sit under a higher slot symbol. Option on by default. `/drop test eating`.
- **Auto-quiet in dungeons** (on by default) turns on the existing “instance” quiet mode when you enter a dungeon or raid and restores the previous setting when you leave. It does not override an existing instance/group choice. A manual quiet-mode change inside a dungeon clears the hold. `/drop test dungeon`.
- Optional **Low durability** flask signal and one toast when an equipped piece drops below 20% (off by default). Priority sits below fishing and swimming so it does not hide what you are doing now. `/drop test durability`.
- Priority in the flask well is now death > flight/transport (same hourglass) > combat sword (if that style is on) > AFK > bags full > fishing > swimming > durability (off by default) > rested “z” > drop. Eating is a wave layer, not a symbol. Loading/cinematic is a pause, not a symbol.
- Progression window: new **Efficiency** tab. The score is only the share of session time spent active (combat, gathering, crafting) versus downtime (death, loading, flight, transit, AFK). It is never based on points/h or XP/h. Informational XP rates (% of the current level / h, time-to-level) are hidden at maximum level. One factual end-of-session tip names the largest measured downtime share (for example “22% of time in flight”); nothing is invented.
- Progression comparisons (session, spots, 7/30 days) use normalized rates only: XP as a percentage of the current level per hour (`XP/h ÷ UnitXPMax`), professions as measured skill-ups per attempt (orange/yellow/green/grey and trainer cap), weapons against the 5× level cap. Raw points/h are never the comparison. The “0.00 lvl/h” readout at mid levels is fixed (it used levels gained, which stays 0 until you ding).
- Any truncated text in the Progression window (and stat cards) shows a hover tooltip with the full line plus useful detail (record dates, full time-to-level, scoring).
- Custom icons: XP drop, brighter spells spark, trainer-rank badge clipped inside the profession icon circle, farm-spots icon on the overview card, fallback icon. Profession icons keep their own art (no extra bronze frame). Toast icons never overflow their circular frame (inset + mask; Blizzard icons also use the 0.07 crop; Dropamine art is not cropped).
- Skill toasts get a stronger dark tint of the tile colour on the whole toast background (XP/level, weapons, professions); the bronze border is unchanged. System toasts stay neutral.
- **Profitability** report (Efficiency tab and the session recap): **vendor value** and value/h next to normalized progression, per session and per farm spot, with previous session and 7/30-day totals when those were measured. The value is raw looted coin (`CHAT_MSG_MONEY`) plus the vendor price of every item looted on the spot (`GetItemInfo` sellPrice × quantity, from your own loot only), measured at loot time. `GetMoney()` deltas are not used, so mail, the auction house, trades and the bank never skew a spot. An item later sold at the auction house stays valued at vendor price. Labels and the tooltip say “vendor value” / « valeur marchand » and explain the method. Gold is not tracked as a standalone possession elsewhere. Format uses the gold/silver/copper coin icons.
- The report highlights a **Best combined spot** (sum of the percentiles of normalized progression and vendor value/h among your own spots with at least 1 min measured), plus best-for-progression and best-for-gold. A tooltip explains the scoring and the vendor-value method. Spots missing a measured metric are left out of the combined ranking. `/drop test efficiency`.
- Clicking the session recap toast (or the **Session recap** button in the Progression window, or `/drop recap`) opens a recap view: duration, active share, normalized XP, skill-ups, recipes learned, deaths and time lost, missed loot, best spot, achievements, profitability and the factual tip. A DEV Test button loads clearly labelled sample data (`/drop test recap`).
- Per-character session history: the last 30 recaps are kept in detail; older sessions are merged into weekly aggregates. You can browse past sessions and compare the current one to the previous session and to 7-day and 30-day averages, using normalized rates only (active share, % of a level / h, skill-ups / h, vendor value / h).
- Flask states work in every display mode (bar and 1/2/3/5-column grids). In the grid, the total tile fills from the bottom inside the icon with proportional red + blue waving liquid and amber bubbles (green fades); rested “z” and the eating regen wave use the same tile. Liquid, bubbles, waves and z are clipped inside the icon (ScrollFrame, inset for the bronze frame) so they no longer spill above the tile border. In the bar, “z” still leave the Level portrait; in the grid they also stay on Level. DEV Test notes ask you to verify each layout. `/drop test combat`, `/drop test rested`, `/drop test eating`.
- Skill toasts (XP, weapon skill-ups, profession skill-ups, recipes, goals, trainer ranks, “tier reached”) show the validated darker tile-colour tint on the toast fill, applied after the skin/chrome and kept on reuse. System toasts stay neutral. Profession toasts use the profession’s original game icon (e.g. Skinning, Leatherworking), not the empty-vial fallback; the trainer-rank bronze chevron still sits on the profession icon. The vial is only used when no skill can be resolved.
- Eating and drinking (“repas”) is detected from player auras and the food/drink channel: C_UnitAuras and AuraUtil, classic spell IDs, and FR/EN names (Nourriture, Boisson, Food, Drink). Names or values that are secret on Forever are skipped without aborting the scan. “Well Fed” / “Bien nourri” is not treated as eating. The wave also shows in grid mode. `/drop test eating` (DEV Test › Repas).

- Memory: the 19 MB → 80+ MB climb after a few minutes came from toast frames. Every `SpawnDrop` created a new Frame (slot, textures, FontStrings, bar, OnUpdate) and `DismissDrop` only hid it, so hidden toasts accumulated without bound (especially on the previous test build, where every mob-kill XP still toasted). Toasts are now pooled and reused: peak concurrent frames (~5), children created once, a shared OnUpdate, and Compact's OnHide hook attached once. `FlushSkillDiff` no longer calls `Collect()` when no skill actually rose. `TransformWidths` reuses its output table. Rested “z” skip unchanged `SetPoint`. The flask driver, when only rested z/wave are active, ticks those animations only (no per-frame table or new texture).
- Data refreshes (profession/skill rescans, bag checks, aura scans, tile text) are coalesced every 1.25 s out of combat, 1.5 s in combat, 2 s in a raid, and only applied when something actually changed. Visual animations (wave, bubbles, drops, z) stay at full frame rate and allocate nothing per frame.
- The “higher-rank trainer available / go see your trainer” toast fires only when you enter a capital city (Orgrimmar, Undercity, Thunder Bluff, Silvermoon, Stormwind, Ironforge, Darnassus, Exodar, Shattrath, Dalaran, and Forever capitals via map/zone ID). A regular inn or a resting area such as Menethil or Booty Bay no longer triggers it. `PLAYER_UPDATE_RESTING` and `ZONE_CHANGED_INDOORS` do not show it. Entering and leaving the same capital will not toast again for 90 seconds. Zone/rest events use a light path (no full rescan) and skill toasts are quiet for 2 s so a partial skill-line read cannot look like a +1.
- The official drop-vial icon in the total slot is never hidden: in bar mode, hiding it made the well completely black while resting. Rested “z” and the wave sit inside that official logo in both bar and grid. Grid mode (~32 px) now also paints the 3-colour fill and the surface wave in the well (it used to leave an empty vial).
- Combat resize: the compact panel is not protected, so the grid is laid out immediately in combat and the backdrop height is recomputed (`Layout.Center`). If a wrap really is protected (SkillFrame), the layout is queued on `PLAYER_REGEN_ENABLED`.
- Unarmed / Mains nues: the tile is bound to the same skill line as the tooltip (API name/id, not a generic “Melee” match). Weapon/combat tiles are no longer frozen by `C.holds`, so the painted rank follows the toast in combat too. The unarmed icon is the skill-line icon, else `INV_Gauntlets_04` (fist), not a sword.
- Weapon time-to-cap uses a degressive chance ≈ (cap − current) / cap with a floor, normalizes measured gains, and sums expected time point-by-point. The label is `~ estimation` (not a linear “~4 min” near cap). The same math is used in the tooltip ETA line.

- Official XP / level-up vial icon redrawn from the exact Dropamine drop silhouette (bronze rim, official flask shape). Red liquid and a surface wave, no chemistry flask, no extra drop on top, no splash, legible at 64×64 (toast and tile size).
- Toasts use a short 7 px slide plus fade (in and out), sober, on the pooled frames (no per-frame allocation).
- Adding to the total: a drop falls into the official flask, then a wave and bubbles. This replaces the old fly-to-total spark on the total tile.
- Level-up: the flask overflows, the bronze ring pulses, then the fill resets with a wave (the real level-up toast is unchanged).
- Campfire, one glyph, no smoke: a small static ember when you are near the fire, the ember grows into a flame over the charge minute, then a short spark burst when the buff is taken and the well goes back to the drop. `/drop test campfire near|charge|burst`.
- Eating and drinking keep the real fill level: only the surface wave is coloured (amber for food, blue for drink, both = two layered waves). `/drop test eating food|drink|both`.
- Progression window: **Personnages** tab, a sortable table of every character on the account (level, XP, gold, professions, weapons, playtime). No completion % yet (3.6.4). Snapshots are stored on the character (`c.sheet`) at logout and on the 2-minute progress tick.

- Grid and bar flask states (fill, wave, eating, campfire, combat, sleeping bag, total-add, level-up) paint on the official vial: fixed texture paths, clip size/parent, and state tests drive the flask (not only a tooltip). Eating wave is a 2–3 px opaque animated band at the real fill (amber / blue / both). Rested “z” move into the visible total vial in grid as well as bar.
- The compact panel no longer resizes or rescales by itself (Layout.Center no longer SetSize). Its frame strata stays HIGH, above the chat frame. States do not grow the panel with leftover 100×50 overlay frames.
- Toasts: pooled frames reset font, height, anchors and marquee offset (start at 0) on acquire, with 6 px stack spacing. Width follows the panel by default (readable 260 px minimum at scale), with a per-character “Largeur des notifs” slider (Auto or a fixed width). If wider than the panel, they align to the panel edge on the screen side.
- Eating and fishing use a small corner badge (about 1/3 of the icon, top-right) in grid; the official total vial is never replaced and the count stays fully legible. Bar eating is unchanged (corner icon plus amber / blue / both wave). The stray triangle/arrow above the tile is removed. State tests never open the description tooltip by themselves. At rest, leftover white/green/blue fill and wave bands on the total vial are hidden (alpha 0); the add-to-total drop animation is unchanged.
---
- En barre et en grille, les états de la fiole (remplissage, vague, repas, feu de camp, combat, sac de couchage, ajout au total, niveau) se peignent sur la fiole officielle : chemins de textures corrigés, clip calé, et les `/drop test` pilotent vraiment la fiole (plus seulement une infobulle). Vague de repas : bande de 2–3 px opaque et animée au vrai niveau (ambre / bleu / les deux). Les « z » de repos vont dans la fiole du total visible, y compris en grille.
- Le panneau compact ne change plus tout seul de taille ni d'échelle (`Layout.Center` ne fait plus de `SetSize`). Il reste en strate HIGH, au-dessus du chat. Les états ne gonflent plus le panneau avec un cadre 100×50 par défaut.
- Toasts : le vivier remet police, hauteur, ancres et défilement à 0 à chaque réemploi, avec 6 px d'écart. Largeur Auto = largeur du panneau (minimum lisible 260 px à l'échelle), ou curseur « Largeur des notifs » (réglage perso). Plus large que le panneau : alignement sur le bord du panneau du côté de l'écran.
- Repas et pêche : en grille, un petit badge en coin (~1/3 de l'icône, haut-droit) ; la fiole officielle du total n'est jamais remplacée et le compteur reste lisible. En barre, le repas est inchangé (icône en coin + vague ambre / bleu / les deux). Plus de triangle parasite au-dessus de la case. Les `/drop test` n'ouvrent plus l'infobulle tout seuls. Au repos, les bandes blanc/vert/bleu et la vague résiduelle sur la fiole sont cachées (alpha 0) ; l'animation d'ajout au total est inchangée.

- Sac de couchage, style A : pendant que l'aura Bien reposé (sort 429959, 1 à 3 charges, +1 % d'XP gagnée par charge) se construit hors combat, le puits de la fiole affiche l'icône style A à 1, 2 ou 3 bandes, cadrée dans l'icône en barre et en grille. Priorité juste avant les z de repos. Si tu pars avant 3 charges, un toast teinté XP : « Sac de couchage : 2/3 % », « 1 % manqué », astuce « Bien reposé », avec l'icône du palier atteint. À 3/3, pas de toast d'échec ni de confirmation. `/drop test sleepingbag 1|2|3|miss` (DEV).
- L'XP des monstres tués ne déclenche plus de toast (l'animation de vague / remplissage de la fiole reste). Un toast de jalon discret, teinte XP, apparaît à 25 %, 50 % et 75 % du niveau en cours (« Niveau 6 · 50 % »), une seule fois par seuil et par niveau (les seuils déjà atteints sont mémorisés sans toast au login). Chaque remise de quête garde un toast, et le vrai toast de montée de niveau est inchangé.
- Les toasts de recette et « Recette possible » (test DEV et en jeu) affichent l'icône du métier (`Trade_LeatherWorking` pour le travail du cuir), pas l'icône d'objet ni un sac / une bourse générique. L'icône fiole XP est inchangée.
- CPU : le scan des auras du joueur (repas, Bien reposé, canal de pêche) n'a lieu que sur UNIT_AURA / canal pour `player`, après un court regroupement, et le résultat est mis en cache pour les détections Live*. `SetSize` sur les cadres et textures de rognage de la fiole est sauté si la taille n'a pas changé. Le comptage « sacs pleins » ne tourne que sur `BAG_UPDATE_DELAYED` (plus sur le spam `BAG_UPDATE`, ni à chaque Refresh). Le driver OnUpdate de la fiole s'arrête toujours quand aucune animation n'est active (le pictogramme du sac de couchage est statique). La teinte des toasts et l'écriture des profils par personnage ne refont pas le travail si rien n'a changé.

- Toast « sacs pleins » : on ne compte que les sacs généraux (bagType 0), via `C_Container.GetContainerNumFreeSlots` (sac à dos 0..NUM_BAG_SLOTS et le sac de composants s'il existe). Sacs de métier, carquois, munitions, âme et trousseau de clés sont ignorés. Un 0 transitoire pendant BAG_UPDATE ou un chargement est ignoré ; le toast ne part que lorsque 0 place générale est confirmée (délai, aussi sur BAG_UPDATE_DELAYED). Une lecture d'API ratée n'est pas traitée comme 0.
- Les réglages d'affichage sont enregistrés par personnage (profil clé nom-royaume dans DropamineDB). Les réglages de compte existants deviennent le défaut de chaque personnage. Le profil actif est appliqué avant la construction de l'interface, et chaque changement d'option est écrit tout de suite dans ce profil (pas seulement à la déconnexion). « Suivre le compte » reste disponible (`/drop profil compte`).
- La teinte des toasts garde la même opacité de fond qu'avant la teinte (réglage `/drop drops opacite` / Fond des toasts, et le fondu d'entrée/sortie). Seule la couleur change ; `_tintFill` n'est plus peint à l'alpha 1.
- Le toast +75 XP garde l'icône fiole XP rouge (`XP-Icon`), pas la fiole de repli vide. Les toasts de métier remplacent toujours un fallback ou une fiole XP de substitution par l'icône du métier.
- Les toasts « recette possible » ne commencent plus par un × orphelin quand le compte est absent ou égal à 1 (« × Viande de sanglier rôtie possible »). Le préfixe « N × » n'apparaît qu'à partir de 2. Les titres longs utilisent toujours le défilement sur une ligne et l'infobulle au survol.
- Les liquides de la fiole (vague de repas, remplissage de combat, z de repos) sont cadrés dans l'icône de la goutte dans tous les modes : barre et grilles 1/2/3/5 colonnes. Le clip et les textures sont dimensionnés d'après l'icône (petite goutte en barre ~14 px, plus un pavé par défaut 100×50). En barre, le combat reste sur les segments horizontaux seulement.
- `/drop mem` affiche la mémoire de l'addon (`GetAddOnMemoryUsage` avant et après `collectgarbage`) et une ventilation des tables retenues : SavedVariables (historique de session par personnage, spots, recettes, historique), l'ancienne copie `OSRS_TotalLevelDB` si elle est encore chargée, ScannerDB et le cache des créatures apprises, les index de noms/recettes, les locales, le snapshot UI. À la connexion, les PNJ déjà dans la base statique sans butin appris sont retirés (plafond 2500 créatures apprises), l'historique journalier de chaque personnage est limité à 35 jours, les récaps de session sont compactés (profit/spots allégés, 30 sessions, 104 agrégats hebdo).
- Les toasts de recettes et les lignes de métier n'affichent plus « objet 159 » (ou « item 159 ») quand le nom n'est pas encore dans le cache du client. En attendant le nom, seule la recette est montrée (« Palourdes bouillies (+1) ») ; le toast se met ensuite à jour, par exemple en « Eau de source : Palourdes bouillies (+1) ». Même règle pour les listes de courses, les lignes « à apprendre bientôt » et le surlignage de cible. Le nom est résolu avec Item:CreateFromItemID / ContinueOnItemLoad si le client les a, sinon GetItemInfo et GET_ITEM_INFO_RECEIVED.
- Nouvelle option **Pause pendant le vol** (Options › Affichage, active par défaut) : sur un trajet aérien (`UnitOnTaxi("player")`), le suivi, les scans de barres de nom, les toasts de survol / cible et tous les toasts / popups sont en pause. Rien n'est mis en file : à l'atterrissage, pas de rattrapage. `/drop vol on|off` (ou `/drop flight on|off`).
- Sur un trajet aérien, la goutte de la fiole du total est remplacée par un sablier bronze qui tient exactement dans l'emplacement de la goutte (même taille et ancre, sous le cadre bronze). Une feuille de 32 images (26 du sable qui descend de l'ampoule haute vers l'ampoule basse avec un mince filet, puis 6 du retournement à 180° en 0,4 s) est parcourue avec SetTexCoord ; une seule texture, pas d'AnimationGroup, pas de SetRotation. Environ 3 s par cycle. Le panneau s'assombrit un peu (× 0,75) et l'infobulle de la fiole ajoute « En pause pendant le vol » et « Le scan reprend dès l'atterrissage. » Le survol du sablier ou de la fiole en vol montre cette explication (titre + ligne). À l'atterrissage, la goutte et l'opacité reviennent en fondu de 0,5 s. Suit l'option **Pause pendant le vol**. OnUpdate cadencé à 20 im/s, arrêté une fois caché.
- La première fois que la pause en vol se déclenche sur un personnage, un toast Dropamine l'explique (icône du sablier) : « Suivi en pause pendant le vol. Le scan reprend dès l'atterrissage. » C'est un toast normal (fondu automatique, clic habituel). Une fois par personnage (SavedVariables). `/drop reset-hints` le réaffiche.
- L'envol sur un trajet aérien est détecté en direct, sans `/reload` : un sondage de `UnitOnTaxi("player")` toutes les 0,5 s reste actif (le cadre OnUpdate est affiché), et `PLAYER_CONTROL_LOST`, `TAXIMAP_CLOSED` et `UNIT_FLAGS` (joueur) sont revérifiés à 0,1 s, 0,5 s et 1,5 s, car `UnitOnTaxi` est souvent encore faux quand le contrôle est perdu. L'atterrissage est détecté de la même façon (`PLAYER_CONTROL_GAINED` plus le sondage).
- Les titres et lignes des toasts tiennent sur une seule ligne. Un nom trop long est rogné et défile horizontalement (après une courte pause) au lieu de passer à la ligne ; la hauteur du toast ne change pas. Le survol met le défilement et la minuterie de fondu en pause ; les deux reprennent quand le curseur part. Une GameTooltip montre le texte intégral. Pour une recette ou un toast « réalisable », elle ajoute aussi le métier, le rang requis, la couleur de difficulté, le nombre fabricable maintenant, les composants manquants s'il y en a, et l'infobulle de l'objet (`SetItemByID` / `SetHyperlink`) quand l'identifiant est connu.

- La goutte de la fiole du total dit maintenant ce que tu fais : un seul symbole à la fois, cadré dans le puits (feuilles de sprites, 20 i/s, pas d'AnimationGroups). Priorité : mort (crâne, fiole vidée et grisée, suivi en pause jusqu'à la résurrection) > vol (sablier) > AFK (horloge de bronze) > pêche (hameçon qui tangue pendant le canal, un sursaut quand la prise arrive dans les sacs) > nage (bulles) > « z » de repos (seulement à l'auberge ou en capitale ; la vague reste sur la case Niveau) > la goutte. Un maître de métier à proximité fait briller la case du métier, pas la fiole. Chaque symbole a une infobulle au survol et une option (active par défaut). Le combat est un réglage d'Affichage, **Style de combat** : **Bulles** (défaut, maquette A : la fiole reste, le rouge et le bleu montent et la remplissent avec une surface ondulée et des bulles ambrées, le vert s'efface ; après le combat le liquide redescend et le vert revient), **Épée** (maquette C : le même liquide plus une petite épée de bronze dans le puits, priorité juste sous le vol), ou **Désactivé**. L'infobulle de la fiole en combat affiche « En combat : XP et armes en cours ». Les transitions combat / mort interrompues (reprise au milieu de la descente, /reload en combat, mort en combat) aboutissent toujours à l'état final correct. Pas de clignotement ni d'assombrissement du panneau en combat.
- En capitale ou en ville de maîtres, quand un métier a un rang supérieur disponible chez le maître (la même logique que la ligne d'infobulle « Rang supérieur disponible chez le maître »), un toast collant affiche « <Métier> : rang supérieur disponible chez le maître » (un seul toast s'il y en a plusieurs). Il reste jusqu'au clic ou jusqu'à l'apprentissage du rang, ignore le fondu automatique et le plafond de toasts, et se relance à chaque entrée en capitale tant que le rang n'est pas appris. Il n'apparaît pas en vol ni en combat (il attend la fin). Option active par défaut.


- Signal dans la fiole et un toast standard quand les sacs sont pleins (« Sacs pleins : le butin sera perdu »), une fois jusqu'à ce qu'une place se libère. Option active par défaut (Options › Affichage, aide au survol uniquement). `/drop test bags`.
- **Pause pendant le vol** couvre aussi les bateaux, les zeppelins et le tram (`UnitOnTaxi` y est faux). Même sablier et même reprise propre à l'arrivée (pas de file de toasts). Pas d'astuce de premier vol pour un transport. `/drop test transport`.
- Les écrans de chargement et les cinématiques mettent le suivi en pause silencieusement et le reprennent sans déverser de toasts en attente. Toujours actif (pas derrière l'option vol). Pas de sablier pour un chargement. `/drop test loading`.
- Pendant un buff de régénération nourriture ou boisson (pas « Bien nourri »), une vague douce joue dans la fiole. Peut cohabiter sous un symbole plus prioritaire. Option active par défaut. `/drop test eating`.
- **Calme auto en donjon** (actif par défaut) allume le mode calme « instance » déjà existant à l'entrée en donjon ou raid, et rétablit le réglage précédent à la sortie. Il ne remplace pas un choix déjà « instance » ou « groupe ». Un changement manuel du mode calme dans le donjon lève le maintien. `/drop test dungeon`.
- Option **Équipement usé** : signal dans la fiole et un toast quand une pièce équipée passe sous 20 % (coupée par défaut). Priorité sous la pêche et la nage, pour ne pas masquer ce que tu fais maintenant. `/drop test durability`.
- La priorité dans le puits est désormais mort > vol/trajet (même sablier) > épée de combat (si ce style est choisi) > AFK > sacs pleins > pêche > nage > usure (coupée par défaut) > « z » de repos > goutte. Le repas est une couche de vague, pas un symbole. Chargement / cinématique : une pause, pas un symbole.
- Fenêtre Progression : nouvel onglet **Efficacité**. Le score est uniquement la part du temps de session passée à progresser (combat, récolte, artisanat) face au temps mort (mort, chargement, vol, trajet, absence). Il ne repose jamais sur les points/h ni sur l'XP/h. Les rythmes d'XP informatifs (% du niveau en cours / h, temps restant) sont masqués au niveau maximum. Un conseil factuel en fin de session nomme la plus grande part de temps mort mesurée (par exemple « 22 % du temps en vol ») ; rien n'est inventé.
- Les comparaisons de progression (session, spots, 7/30 jours) n'utilisent que des rythmes normalisés : XP en % du niveau en cours par heure (`XP/h ÷ UnitXPMax`), métiers en paliers mesurés par tentative (orange/jaune/vert/gris et palier maître), armes face au plafond 5× le niveau. Les points/h bruts ne servent jamais de comparaison. L'affichage « 0,00 niv./h » en milieu de palier est corrigé (il comptait les niveaux gagnés, donc 0 tant que tu n'as pas ding).
- Tout texte tronqué dans la fenêtre Progression (et les cartes de stats) a une infobulle au survol avec la ligne complète et le détail utile (dates des records, temps restant, scoring).
- Icônes : goutte d'XP, étincelle de sorts plus visible, badge de rang maître cadré dans le cercle de l'icône de métier, icône des spots de farm sur la carte d'ensemble, icône de repli. Les icônes de métier gardent leur propre art (pas de cadre bronze ajouté). Les icônes de toast ne débordent jamais de leur cercle (marge + masque ; les icônes Blizzard ont aussi le recadrage 0,07 ; l'art Dropamine n'est pas recadré).
- Les toasts de compétences reçoivent un voile plus soutenu de la couleur de la case sur tout le fond (XP/niveau, armes, métiers) ; le bord bronze ne change pas. Les toasts système restent neutres.
- Rapport **Rentabilité** (onglet Efficacité et récap de session) : **valeur marchand** et valeur/h à côté de la progression normalisée, par session et par spot de farm, avec la session précédente et les totaux 7/30 jours quand ils ont été mesurés. La valeur est les pièces ramassées (`CHAT_MSG_MONEY`) plus le prix vendeur de chaque objet butiné sur le spot (`GetItemInfo` sellPrice × quantité, butin personnel uniquement), mesurée au moment du butin. Les deltas `GetMoney()` ne sont pas utilisés : le courrier, l'hôtel des ventes, les échanges et la banque ne faussent jamais un spot. Un objet ensuite vendu à l'hôtel des ventes reste valorisé au prix vendeur. Les libellés et l'infobulle disent « valeur marchand » et expliquent la méthode. L'or n'est pas suivi comme une possession ailleurs. Le format utilise les icônes d'or, d'argent et de cuivre.
- Le rapport met en avant un **Meilleur spot mixte** (somme des centiles de la progression normalisée et de la valeur marchand/h parmi tes propres spots d'au moins 1 min mesurée), plus le meilleur pour la progression et le meilleur pour l'or. Une infobulle explique le calcul et la méthode valeur marchand. Un spot sans métrique mesurée n'entre pas dans le classement mixte. `/drop test efficiency`.
- Un clic sur le toast de récap de session (ou le bouton **Récap session** de la fenêtre Progression, ou `/drop recap`) ouvre la vue récap : durée, part active, XP normalisée, paliers, recettes apprises, morts et temps perdu, butin perdu, meilleur spot, succès, rentabilité et le conseil factuel. Un bouton DEV Test charge des données d'exemple clairement signalées (`/drop test recap`).
- Historique de session par personnage : les 30 derniers récaps sont gardés en détail ; les plus anciens sont fusionnés en agrégats hebdomadaires. On peut parcourir les sessions passées et comparer la session en cours à la précédente et aux moyennes 7 et 30 jours, uniquement avec des rythmes normalisés (part active, % de niveau / h, paliers / h, valeur marchand / h).
- Les états de la fiole fonctionnent dans tous les modes d'affichage (barre et grilles 1/2/3/5 colonnes). En grille, la case total se remplit depuis le bas dans l'icône avec le liquide rouge + bleu proportionnel ondulé et les bulles ambre (le vert s'éteint) ; les « z » de repos et la vague de repas utilisent la même case. Liquide, bulles, vagues et z sont cadrés dans l'icône (ScrollFrame, retrait pour le cadre bronze) et ne débordent plus au-dessus du fond de la case. En barre, les z quittent toujours le portrait Niveau ; en grille, ils restent aussi sur Niveau. Les notes DEV Test demandent de vérifier chaque disposition. `/drop test combat`, `/drop test rested`, `/drop test eating`.
- Les toasts de compétences (XP, armes, métiers, recettes, objectifs, rang maître, palier atteint) reçoivent la teinte sombre validée de la couleur de case, posée après l'habillage et conservée au recyclage. Les toasts système restent neutres. Les toasts de métier utilisent l'icône d'origine du jeu (Dépeçage, Travail du cuir…), pas la fiole de repli ; le chevron bronze du rang maître reste sur l'icône du métier. La fiole n'apparaît que si aucun métier n'est identifiable.
- Le repas et la boisson sont détectés via les auras du joueur et le canal nourriture/boisson : C_UnitAuras, AuraUtil, identifiants de sorts classiques, et noms FR/EN (Nourriture, Boisson, Food, Drink). Un nom secret sur Forever n'interrompt pas le scan. « Bien nourri » / « Well Fed » n'est pas un repas. La vague s'affiche aussi en grille. `/drop test eating` (Test › Repas).

- Mémoire : la montée de 19 Mo à plus de 80 Mo en quelques minutes venait des cadres de toast. Chaque `SpawnDrop` créait un Frame (emplacement, textures, FontStrings, barre, OnUpdate) et `DismissDrop` ne faisait que le cacher : les toasts cachés s'accumulaient sans limite (surtout sur le build de test précédent, où chaque XP de monstre toastait encore). Les toasts sont désormais mis en vivier et réutilisés : au plus le pic simultané (~5), enfants créés une fois, OnUpdate partagé, crochet OnHide de Compact posé une seule fois. `FlushSkillDiff` n'appelle plus `Collect()` s'il n'y a pas de vrai palier. `TransformWidths` réutilise sa table. Les « z » de repos ignorent un `SetPoint` inchangé. Quand seuls les z / la vague de repos tournent, le pilote de la fiole ne fait plus que ces animations (pas de table ni de texture par image).
- Les rescans de données (métiers, compétences, sacs, auras, textes des cases) sont regroupés toutes les 1,25 s hors combat, 1,5 s en combat, 2 s en raid, et n'appliquent un changement que s'il y a un vrai écart. Les animations (vague, bulles, gouttes, z) restent à pleine cadence et n'allouent rien par image.
- Le toast « rang supérieur disponible chez le maître » ne part plus qu'à l'entrée dans une capitale (Orgrimmar, Fossoyeuse, les Pitons-du-Tonnerre, Lune-d'Argent, Hurlevent, Forgefer, Darnassus, l'Exodar, Shattrath, Dalaran, et les capitales Forever via l'ID de carte / de zone). Une simple auberge ou une zone de repos (Menethil, Baie-du-Butin…) ne le déclenche plus. `PLAYER_UPDATE_RESTING` et `ZONE_CHANGED_INDOORS` ne l'affichent pas. Entrer et sortir de la même capitale ne le relance pas pendant 90 s. Les événements de zone / repos empruntent un chemin léger (pas de rescan complet) et les toasts de compétence sont en silence 2 s, pour qu'une lecture partielle ne ressemble pas à un +1.
- L'icône officielle de la fiole (goutte) n'est jamais cachée : en barre, la cacher noircissait tout le puits au repos. Les « z » et la vague de repos se dessinent dans ce logo, en barre et en grille. En grille (~32 px), le remplissage 3 couleurs et la vague de surface sont aussi peints dans le puits (la fiole restait vide).
- Redimensionnement en combat : le panneau compact n'est pas protégé, la grille est donc relancée tout de suite et la hauteur du fond est recalculée (`Layout.Center`). Si un encapsuleur est vraiment protégé (fiche des compétences), la mise en page est reportée à `PLAYER_REGEN_ENABLED`.
- Mains nues : la case est liée à la même ligne de compétence que l'infobulle (nom / id API, pas un rapprochement générique « Mêlée »). Les cases d'arme / de combat ne sont plus figées par `C.holds` : le rang peint suit le toast, aussi en combat. L'icône est celle de la ligne, sinon `INV_Gauntlets_04` (poing), pas une épée.
- Le temps restant jusqu'au plafond d'arme utilise une chance dégressive ≈ (plafond − rang) / plafond (avec un plancher), normalise les gains mesurés, et additionne le temps attendu point par point. Libellé `~ estimation` (plus un « ~4 min » linéaire près du plafond). La même formule sert à la ligne d'estimation de l'infobulle.

- Icône officielle de la fiole XP / montée de niveau redessinée à partir de la silhouette exacte de la goutte Dropamine (filet bronze, forme officielle). Liquide rouge et vague de surface, pas de fiole de chimie, pas de goutte en plus au-dessus, pas d'éclaboussure, lisible en 64×64 (toast et case).
- Les toasts ont un court glissement de 7 px plus un fondu (à l'apparition et à la disparition), sobre, sur les cadres du vivier (rien n'est alloué par image).
- Ajout au total : une goutte tombe dans la fiole officielle, puis vague et bulles. Cela remplace l'ancien éclat qui volait vers la case total.
- Montée de niveau : la fiole déborde, l'anneau bronze pulse, puis le remplissage se remet avec une vague (le vrai toast de niveau est inchangé).
- Feu de camp, un seul glyphe, pas de fumée : petite braise statique près du feu, elle grandit en flamme pendant la minute de charge, puis une courte gerbe d'étincelles quand le buff est pris et retour à la goutte. `/drop test campfire near|charge|burst`.
- Repas et boisson : le niveau de remplissage reste le vrai ; seule la vague de surface est colorée (ambre nourriture, bleu boisson, les deux = deux vagues superposées). `/drop test eating food|drink|both`.
- Fenêtre Progression : onglet **Personnages**, table triable de tous les personnages du compte (niveau, XP, or, métiers, armes, temps de jeu). Pas encore de % de complétion (3.6.4). Les instantanés sont enregistrés sur le personnage (`c.sheet`) à la déconnexion et au tick de progression (2 min).

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
