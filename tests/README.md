# Tests

Small offline checks, no game needed. They use fake WoW APIs, so they verify the **logic**, not what is drawn on screen.

**Everything at once:** `sh tests/run_all.sh` (also run by GitHub on every push, and before every release).

Run them from the addon root (the folder with `Dropamine.toc`), with Lua 5.2+ (`lua`, or `texlua` from TeX Live). Only Lua is needed (no Python). Force a binary with `LUA=…` and `LUAC=…`.

    lua tests/check_syntax.lua          # every file in the .toc parses
    lua tests/load_modules.lua          # every file actually RUNS at load time (catches nil globals)
    lua tests/check_options.lua         # settings: each row shown once, list boxes wired, every label translated
    lua tests/check_globals.lua         # stray globals (a forgotten `local`, code pasted in the wrong place) — needs luac
    lua tests/missing_translations.lua  # Tr["..."] texts without an English translation
    lua tests/hunt_autotile.lua         # Hunt: items land on their equipment slot
    lua tests/hunt_loot_kc.lua          # loot message -> kill count + epic alert
    lua tests/hunt_rare_alert.lua       # rare/epic alert by quality
    lua tests/hunt_roll.lua             # hunted item spotted in a group roll (gold frame + one toast)
    lua tests/progress_run.lua          # active-time streak and new achievements
    lua tests/hunt_missing.lua          # missing recipes and creatures by level (real database)
    lua tests/recap_table.lua           # session recap comparison table
    lua tests/collection_home.lua       # Collection log home page figures

The `check_*` and `missing_translations` scripts exit with code 1 on a problem; the others print what they computed, with the expected value when there is one. Some print in `pairs()` order, so line order may change between runs.

Not covered: secret values (a protected value can only be produced by the game itself), frames, tooltips and sounds. Those need an in-game check.
