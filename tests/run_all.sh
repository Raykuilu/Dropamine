#!/bin/sh
# Lance toutes les vérifications. Usage, depuis la racine de l'addon : sh tests/run_all.sh
# Lua : texlua (TeX Live) ou lua 5.x ; on peut forcer avec LUA=... (la CI GitHub utilise lua 5.4).
LUA=${LUA:-$(command -v texlua || command -v lua || command -v lua5.4 || command -v lua5.1)}
fail=0
run() { echo "== $*"; "$@" || fail=1; }
run "$LUA" tests/check_syntax.lua
run "$LUA" tests/load_modules.lua
run "$LUA" tests/check_options.lua
run "$LUA" tests/check_globals.lua
run "$LUA" tests/missing_translations.lua
run "$LUA" tests/hunt_roll.lua
run "$LUA" tests/craft_nextbest.lua
run "$LUA" tests/weapons_level.lua
for t in hunt_autotile hunt_loot_kc hunt_rare_alert hunt_missing progress_run collection_home recap_table; do
  run "$LUA" tests/$t.lua >/dev/null
done
[ $fail -eq 0 ] && echo "TOUT EST OK" || echo "ÉCHEC : voir au-dessus"
exit $fail
