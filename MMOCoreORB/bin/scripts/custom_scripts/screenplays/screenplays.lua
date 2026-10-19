-- Final Boss test-lab checks (tools/swg test lua). Must load before the fb_* screenplays start.
includeFile("../custom_scripts/screenplays/fb_lab_tests.lua")
includeFile("../custom_scripts/screenplays/fb_lab_remote.lua")   -- Phase 2.12: admin lab console item (replaces the field probe)
includeFile("../custom_scripts/screenplays/fb_player_login.lua")   -- wraps PlayerTriggers:playerLoggedIn
