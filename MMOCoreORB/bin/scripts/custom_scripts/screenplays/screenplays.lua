-- Final Boss test-lab checks (tools/swg test lua). Must load before the fb_* screenplays start.
includeFile("../custom_scripts/screenplays/fb_lab_tests.lua")
includeFile("../custom_scripts/screenplays/fb_field_probe_menu_component.lua")
includeFile("../custom_scripts/screenplays/fb_player_login.lua")   -- wraps PlayerTriggers:playerLoggedIn
