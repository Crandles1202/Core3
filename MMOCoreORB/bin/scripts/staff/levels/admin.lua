admin = {
	level = 15,
	name = "admin",
	-- flag is the priviledgeFlag byte the server sends to the client in
	-- PlayerObjectMessage6. The client's command_table.iff uses it to gate
	-- which slash commands (e.g. /teleport, /planetwarp, /jediState) are
	-- typeable. Upstream ships admin with flag=0 which means the most
	-- powerful server-side level paradoxically gets ZERO client-side command
	-- access — admins have all the skills but can't even type /teleport.
	-- Bumping to 2 (Developer tier, matches dev.lua) unlocks the full set
	-- of admin slash commands client-side without changing anything else.
	-- See PermissionLevelList.h:117 (where flag is read) and
	-- PlayerObjectMessage6.h:18 (where it's sent).
	flag = 2,
	tag = "SWGEmu-Admin",
	skills = {
		"admin_base",
		"admin_debug_01",
		"admin_debug_02",
		"admin_debug_03",
		"admin_general_admin_01",
		"admin_general_admin_02",
		"admin_general_admin_03",
		"admin_jedi_management_01",
		"admin_player_management_01",
		"admin_player_management_02",
		"admin_player_management_03",
		"admin_player_management_04",
		"admin_quest_management_01",
		"admin_quest_management_02",
		"admin_server_admin_01",
		"admin_server_admin_02",
		"admin_spawn_management_01",
		"admin_spawn_management_02",
	}
}

addLevel(admin)