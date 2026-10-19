-- Site: the Mos Eisley Trade Hall (Phase 2.11) — the Final Boss vendors under one roof, 150 m north of
-- the starport square (the nearest lot that clears every stock footprint; the starport apron is 170 m
-- across). Room coordinates checked with `tools/lotsurvey check <template> --lua <this file>`.
FbSites:add {
	name = "mos_eisley_trade_hall",
	label = "Mos Eisley Trade Hall",
	planet = "tatooine",
	template = "object/building/tatooine/guild_commerce_tatooine_style_01.iff",
	x = 3580, y = -4638, heading = 180,
	door = { dx = 0, dy = 18 },
	tenants = {
		{ template = "fb_armory_droid",         label = "FB-72, weapons",                     room = "mainroom", x = -3.7,  z = 1.13, y = -6.0,  dir = 11 },
		{ template = "fb_armor_droid",          label = "FB-44, armour",                      room = "mainroom", x = 3.7,   z = 1.13, y = -6.0,  dir = 349 },
		-- meetinga/b are dining rooms: a long table runs x≈±12, y 1..6; stand in front of it
		{ template = "fb_stim_dealer",          label = "Vex Renn, medical supplies",         room = "meetinga", x = 12.0,  z = 1.13, y = -1.5,  dir = 0 },
		{ template = "fb_pet_vet",              label = "Doctor Yan'lara, pet medicine",      room = "meetingb", x = -12.0, z = 1.13, y = -1.5,  dir = 0 },
		{ template = "fb_parts_dealer",         label = "Tamsin Rook, crafting parts",        room = "meetingc", x = 9.0,   z = 1.13, y = -11.0, dir = 0 },
		{ template = "fb_schematic_broker",     label = "Dannik Vosa, schematics",            room = "meetingc", x = 13.0,  z = 1.13, y = -11.0, dir = 0 },
		{ template = "fb_smuggler_goods",       label = "Greelo, odds and ends",              room = "meetingd", x = 2.0,   z = 1.13, y = -13.0, dir = 0 },   -- the stock bar spot (3.3, -9.6) is inside the counter
		{ template = "fb_combat_quartermaster", label = "Quartermaster Sehrev, combat supply", room = "meetingd", x = -1.5,  z = 1.13, y = -10.5, dir = 111 },
		{ template = "fb_pet_dealer",           label = "Handler Toobu, pets",                room = "meetinge", x = -11.0, z = 1.13, y = -11.0, dir = 0 },
		{ template = "fb_property_agent",       label = "Property Agent Garlen, housing",     room = "meetinge", x = -8.0,  z = 1.13, y = -11.5, dir = 90 },
		{ template = "fb_droid_dispenser",      label = "FB-3D, droids",                      room = "halla",    x = 10.6,  z = 2.5,  y = 9.5,   dir = 180 },
	},
	outside = {
		-- the doorman on the starport square, where the vendor row used to stand
		{ template = "fb_trade_hall_keeper", x = 3524, z = 5, y = -4815, dir = 90 },
	},
}
