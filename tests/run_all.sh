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
run "$LUA" tests/collection_sort_share.lua
run "$LUA" tests/quiet_pvp.lua
run "$LUA" tests/profile_search.lua
run "$LUA" tests/bug_report.lua
run "$LUA" tests/hardcore.lua
run "$LUA" tests/skillup_bridge.lua
run "$LUA" tests/recipe_toast.lua
run "$LUA" tests/hunt_link_format.lua
run "$LUA" tests/locales.lua
run "$LUA" tests/lang_clients.lua
run "$LUA" tests/recipe_locale.lua
run "$LUA" tests/pvp_week.lua
run "$LUA" tests/group_hunt.lua
run "$LUA" tests/needle.lua
run "$LUA" tests/hiscores.lua
run "$LUA" tests/collection_not_mine.lua
run "$LUA" tests/hunt_attempts_here.lua
run "$LUA" tests/hunt_import.lua
run "$LUA" tests/hunt_outing.lua
run "$LUA" tests/hunt_off.lua
run "$LUA" tests/progress_native.lua
run "$LUA" tests/farm_data.lua
run "$LUA" tests/app_bridge.lua
run "$LUA" tests/setup_tour.lua
for t in hunt_autotile hunt_loot_kc hunt_rare_alert hunt_missing progress_run collection_home recap_table; do
  run "$LUA" tests/$t.lua >/dev/null
done
[ $fail -eq 0 ] && echo "TOUT EST OK" || echo "ÉCHEC : voir au-dessus"
exit $fail
