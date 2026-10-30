-- Site mos_eisley_trade_hall: guild_commerce_tatooine_style_01 on tatooine, laid out with tools/siteplanner.
FbSites:add {
	name = "mos_eisley_trade_hall",
	label = "Mos Eisley Trade Hall",
	planet = "tatooine",
	template = "object/building/tatooine/guild_commerce_tatooine_style_01.iff",
	x = 3580.6, y = -4645.0, heading = 215,
	door = { dx = 0, dy = 18 },
	tenants = {
		{ template = "fb_armory_droid", label = "FB-72, weapons", room = "mainroom", x = -3.70, z = 1.13, y = -6.00, dir = 11 },
		{ template = "fb_armor_droid", label = "FB-44, armour", room = "mainroom", x = 3.70, z = 1.13, y = -6.00, dir = 349 },
		{ template = "fb_stim_dealer", label = "Vex Renn, medical supplies", room = "meetinga", x = 12.00, z = 1.13, y = -1.50, dir = 0 },
		{ template = "fb_pet_vet", label = "Doctor Yan'lara, pet medicine", room = "meetingb", x = -12.00, z = 1.13, y = -1.50, dir = 0 },
		{ template = "fb_parts_dealer", label = "Tamsin Rook, crafting parts", room = "meetingc", x = 9.00, z = 1.13, y = -11.00, dir = 0 },
		{ template = "fb_schematic_broker", label = "Dannik Vosa, schematics", room = "meetingc", x = 13.00, z = 1.13, y = -11.00, dir = 0 },
		{ template = "fb_smuggler_goods", label = "Greelo, odds and ends", room = "meetingd", x = 2.00, z = 1.13, y = -13.00, dir = 0 },
		{ template = "fb_combat_quartermaster", label = "Quartermaster Sehrev, combat supply", room = "meetingd", x = -1.50, z = 1.13, y = -10.50, dir = 111 },
		{ template = "fb_pet_dealer", label = "Handler Toobu, pets", room = "meetinge", x = -11.00, z = 1.13, y = -11.00, dir = 0 },
		{ template = "fb_property_agent", label = "Property Agent Garlen, housing", room = "meetinge", x = -8.00, z = 1.13, y = -11.50, dir = 90 },
		{ template = "fb_droid_dispenser", label = "FB-3D, droids", room = "halla", x = 10.60, z = 2.50, y = 9.50, dir = 180 },
		{ template = "fb_vehicle_dealer", label = "Rook Valdane, vehicles", room = "hallb", x = -10.60, z = 2.50, y = 9.50, dir = 180 },
		{ template = "fb_resource_dealer", label = "Mehra Tulk, raw resources", room = "foyer", x = 6.00, z = 2.50, y = 13.00, dir = 180 },
	},
	outside = {
		{ template = "fb_trade_hall_keeper", x = 3524.0, z = 5.00, y = -4815.0, dir = 90 },
	},
}
