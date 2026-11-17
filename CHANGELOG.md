# Changelog

All notable changes to Dropamine (formerly OSRS Total Level) are documented here. The 3.3.x notes are taken from the addon's in-tree README and test headers. Command names below use `/drop` (also `/dropamine`).

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [3.5.0] — 2026-11-17

### Fixed
- **Profession windows no longer hitch when switching tabs.** `TRADE_SKILL_*`, `CRAFT_*` and frame `OnShow` hooks share one deferred job (`C_Timer.After` ~0.25 s, a single pending flag). Recipes are scanned only when the key (profession, recipe count, skill rank) changes, in batches of about 25 per frame. Tiles are repainted only when their highlight level actually changes. Nothing is scanned in combat, and the batch `OnUpdate` is cleared when the job ends. `/drop perf` reports scan count and milliseconds per scan.
- **Enemy players light up.** An honorable target (`UnitIsPlayer` or a `Player` GUID, `UnitIsEnemy` / `UnitCanAttack`, `UnitIsPVP` when that function exists, not a trivial level) turns the PvP tile green — subtle on target, strong while you are in combat with them. Equipped weapons and Defence follow the same rules as for creatures. Players are not treated as creatures (no skinning, loot or XP highlight; `UnitCreatureType` is nil). The nameplate marker is green when the player is worth honor, grey when the level is trivial.
- **Toast progress bar no longer runs under the round icon.** On every toast and in all three themes, the thin bar starts at the title’s left edge and ends at the same right inset as the text.

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
