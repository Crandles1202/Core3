-- tasks/cities/corellia_coronet.lua — Coronet: Phase 3.13 city data, read by the living-world screenplays through FbCities (tasks/fb_cities.lua).
FbCities:add {
	key = "coronet", planet = "corellia", label = "Coronet", order = 1,
	lean = 55,   -- 3.4: contested (the capital has both an Imperial and a CorSec presence)
	ambient = {   -- 3.7/3.8
	{
		-- 3.8 flavour: working-class and pilot-heavy, louder, gambling talk (stock cell 8105496, floor z -0.9)
		key = "cantina", label = "Coronet Cantina",
		anchor = { x = 0.0, z = -0.9, y = -2.0, cell = 8105496 },
		seats = {
			{ x = -5.5, z = -0.9, y = -7.5, dir = 30,  cell = 8105496 },
			{ x = 5.0,  z = -0.9, y = -6.5, dir = 220, cell = 8105496 },
			{ x = 1.0,  z = -0.9, y = 8.5,  dir = 180, cell = 8105496 },
			{ x = -6.5, z = -0.9, y = 2.0,  dir = 90,  cell = 8105496 },
		},
		templates = { "pilot", "businessman", "patron", "patron_quarren", "patron_ithorian", "commoner" },
		moods = { "npc_standing_drinking", "npc_sitting_table", "conversation", "happy", "npc_sitting_chair", "bored" },
		chatter = {
			"Three hands in a row. Three! Deal again.",
			"Hyperdrive's been whining since Talus. Anybody know a mechanic who takes credit?",
			"CorSec were sniffing around the docks again.",
			"Loudest cantina on the planet and I still can't hear myself drink.",
			"Who's buying? Not me. I just lost my landing fees.",
			"If you fly for the Diktat you can afford the good stuff. Rest of us drink this.",
			"Heard a freighter came in from Tatooine loaded with... spice? Sand? Something.",
			"Double or nothing. Come on. One more.",
		},
		newcomer = {
			"Fresh off a transport? You look it.",
			"Grab a seat, the game's about to turn ugly.",
			"Pilot? No? Then you're buying.",
		},
		emotes = { "shrug_shoulders", "explain", "slow_down", "point_to_self", "nod_head_multiple" },
	},
	},
}
