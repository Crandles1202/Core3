-- tasks/cities/tatooine_mos_eisley.lua — Mos Eisley: Phase 3.13 city data, read by the living-world screenplays through FbCities (tasks/fb_cities.lua).
FbCities:add {
	key = "mos_eisley", planet = "tatooine", label = "Mos Eisley", order = 1,
	lean = 65,   -- 3.4: default Imperial %
	factions = {   -- the squads the patrols (3.2) draw on
		imperial = { leader = "stormtrooper_squad_leader", troops = { "stormtrooper", "stormtrooper" } },
		rebel    = { leader = "rebel_commando", troops = { "rebel_trooper", "rebel_trooper" } },
	},
	patrols = {   -- 3.2: the leader walks the points, the squad follows; a nil z is the terrain height
		-- the stock city patrol loop through Mos Eisley (cities/tatooine_mos_eisley.lua cll8_1): known walkable
		imperial = { points = { { 3318, 5, -4811 }, { 3359, 5, -4755 }, { 3403, 5, -4775 }, { 3430, 5, -4772 }, { 3470, 5, -4795 }, { 3377, 5, -4745 } } },
		-- open desert west of the city walls
		rebel = { points = { { 3150, nil, -4750 }, { 3200, nil, -4650 }, { 3280, nil, -4680 }, { 3240, nil, -4790 } } },
	},
	-- 3.11: starport vendor row -> through town -> the garrison end of the patrol loop (known walkable points; z from the terrain)
	convoy = { route = { { 3540, 0, -4816 }, { 3470, 0, -4795 }, { 3430, 0, -4772 }, { 3403, 0, -4775 }, { 3359, 0, -4755 }, { 3318, 0, -4811 } } },
	relays = {   -- 3.10: HoloNet relay droids
		{ key = "starport", label = "Mos Eisley Starport", x = 3530, y = -4809, dir = 3, cell = 0 },   -- open plaza in front of the FB vendor
		{ key = "cantina",  label = "Mos Eisley Cantina",  x = 10.5, z = -0.9, y = 8.5, dir = 3, cell = 1082877 },
	},
	ambient = {   -- 3.7/3.8: the living layer in the cantina and outside the starport
	{
		key = "cantina", label = "Mos Eisley Cantina",
		-- the lab teleports here to be "in the room" (main room cell, next to the stage)
		anchor = { x = 12.0, z = -0.9, y = 1.5, cell = 1082877 },
		seats = {   -- extra patrons; positions sit beside stock tables without overlapping stock seats
			{ x = 12.6, z = -0.9, y = -5.6, dir = 20,  cell = 1082877 },
			{ x = 25.2, z = -0.9, y = -6.9, dir = 200, cell = 1082877 },
			{ x = 16.0, z = -0.9, y = 10.0, dir = 180, cell = 1082877 },   -- (-1.0, 12.6) sat inside the wall: 0/8 line of sight (placement audit, 2026-10-18)
			{ x = -4.9, z = -0.9, y = -9.9, dir = 40,  cell = 1082877 },
			{ x = 21.6, z = -0.9, y = 7.5,  dir = 250, cell = 1082877 },
		},
		templates = { "patron", "patron_chiss", "patron_devaronian", "patron_ishitib", "patron_ithorian", "patron_klaatu", "patron_nikto", "patron_quarren" },
		moods = { "npc_sitting_chair", "npc_sitting_table", "npc_standing_drinking", "conversation", "bored", "happy", "npc_sitting_table_eating" },
		chatter = {
			"Koochoo. Another round.",
			"Bo shuda, bo shuda... everybody wants something.",
			"The band's loud tonight. Good. Hard to eavesdrop.",
			"Keep your voice down. Imperials at the far table.",
			"Jabba's people were in here yesterday asking about a pilot.",
			"Ten thousand credits? For that rust bucket? Ha.",
			"Mind the Wookiee. He bites.",
			"If the dealer had schematics like that in my day... hmph.",
			"Sandstorm coming. You can smell it.",
			"I don't drink with Rodians. Nothing personal.",
			"Chuba! Watch where you put those feet.",
			"That armory droid by the starport? Overpriced. Reliable, though.",
		},
		newcomer = {
			"Hm. New face.",
			"Don't know you. Sit anywhere, just not here.",
			"Eyes front, friend. Nobody likes a gawker.",
			"Another one off the shuttle. Welcome to Mos Eisley.",
		},
		emotes = { "shrug_shoulders", "nod_head_once", "shake_head_disgust", "sigh_deeply", "rub_chin_thoughtful", "slow_down", "explain" },
	},
	{
		-- outdoors: travellers waiting outside the Mos Eisley starport (cell 0, height from the terrain)
		key = "starport", label = "Mos Eisley Starport (outside)",
		-- the open plaza in front of the FB vendor row (the first spots, north-west of the entrance,
		-- were out of sight of a player on the plaza)
		anchor = { x = 3516, z = 5, y = -4806, cell = 0 },
		seats = {
			{ x = 3516, y = -4804, dir = 140, cell = 0 },
			{ x = 3519, y = -4807, dir = 220, cell = 0 },
			{ x = 3514, y = -4809, dir = 60,  cell = 0 },
		},
		templates = { "commoner_tatooine", "commoner", "businessman", "patron_ithorian", "commoner_old" },
		moods = { "bored", "worried", "conversation", "calm", "npc_standing_drinking" },
		chatter = {
			"Shuttle's late. Shuttle's always late.",
			"Two hundred credits to Bestine? I could walk it. I won't, but I could.",
			"Customs went through my bags twice. Twice!",
			"If that droid asks me one more time whether I'd like to see the medical centre...",
			"Anybody know a decent cantina? Not that one. The other one.",
			"I'm not standing near the Wookiee. You stand near the Wookiee.",
			"Three days on a freighter and the first thing I smell is bantha. Welcome home.",
			"They searched the Rodian for an hour. Me? Waved straight through. I'm not sure that's a compliment.",
		},
		newcomer = {
			"You waiting for the shuttle too? Get comfortable.",
			"Just arrived? Mind your purse past the starport gate.",
			"Another passenger. Line forms behind me, friend.",
		},
		emotes = { "shrug_shoulders", "sigh_deeply", "slow_down", "rub_chin_thoughtful", "nod_head_once" },
	},
	},
}
