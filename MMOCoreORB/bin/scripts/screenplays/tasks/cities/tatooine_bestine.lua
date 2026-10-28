-- tasks/cities/tatooine_bestine.lua — Bestine: Phase 3.13 city data, read by the living-world screenplays through FbCities (tasks/fb_cities.lua).
FbCities:add {
	key = "bestine", planet = "tatooine", label = "Bestine", order = 2,
	lean = 80,   -- 3.4: the Imperial capital of the planet
	centre = { -1218, -3688 }, radius = 336,
	starport = { -1361, -3600 },   -- travel point "Bestine Starport"
	plaza = { -1230, -3600 },   -- trainer row at the city centre (the invasion plaza)
	relays = {   -- 3.10
		{ key = "cantina", label = "Bestine Cantina", x = 9.0, z = 0.4, y = -8.5, dir = 3, cell = 1528397 },
	},
	ambient = {   -- 3.7/3.8
	{
		-- 3.8 flavour: Imperial-leaning, tenser and quieter than Mos Eisley (stock cell 1528397, floor z 0.4)
		key = "cantina", label = "Bestine Cantina",
		anchor = { x = 0.5, z = 0.4, y = -5.0, cell = 1528397 },
		seats = {
			{ x = 8.0,  z = 0.4, y = -7.5, dir = 300, cell = 1528397 },
			{ x = -2.5, z = 0.4, y = -6.5, dir = 60,  cell = 1528397 },
			{ x = 5.5,  z = 0.4, y = -4.2, dir = 200, cell = 1528397 },
			{ x = -7.5, z = 0.4, y = -5.0, dir = 120, cell = 1528397 },
		},
		templates = { "patron", "commoner_tatooine", "businessman", "patron_devaronian", "patron_nikto", "commoner_old" },
		moods = { "npc_sitting_chair", "npc_sitting_table", "npc_standing_drinking", "worried", "bored", "calm" },
		chatter = {
			"Keep it down. The garrison drinks here.",
			"Governor's office doubled the patrols again. Good for business, they say.",
			"Saw a shuttle full of stormtroopers land this morning. Routine, apparently.",
			"You don't ask about the Rebellion in Bestine. You just don't.",
			"The water tax went up. Of course it did.",
			"Nice and orderly, this town. Too orderly, if you ask me. I didn't say that.",
			"Somebody tell the bartender the Imperial blend is awful.",
			"They say the Empire keeps the Tuskens away. They say a lot of things.",
		},
		newcomer = {
			"New in town? Papers in order, I hope.",
			"Another traveller. Don't make a scene, they don't like scenes here.",
			"Sit down before a trooper decides you're loitering.",
		},
		emotes = { "nod_head_once", "shake_head_no", "sigh_deeply", "rub_chin_thoughtful", "wave_finger_warning" },
	},
	},
	-- 3.1: the GCW invasion (one contested city per planet; the city key is its territory region)
	invasion = {
			defender = "imperial", attacker = "rebel",
	staging = { -850, -3690 },          -- desert east of the walls
	plaza = { -1230, -3600 },           -- trainer row at the city centre
	muster = { -1225, -3618 },          -- where the garrison forms up
	attackers = { leader = "rebel_commando", troops = { "rebel_commando", "rebel_commando", "rebel_commando", "rebel_commando", "rebel_engineer", "rebel_medic" } },   -- commandos are level 25 like stormtroopers; troopers (15) were wiped in 30 s
	defenders = { leader = "stormtrooper_squad_leader", troops = { "stormtrooper", "stormtrooper", "stormtrooper", "stormtrooper", "stormtrooper_medic" } },
	warn = "Bestine: Rebel forces are massing in the desert east of the city. The Imperial garrison is on alert. Assault expected within ten minutes.",
	assault = "Bestine: the Rebel assault has begun. Fighting in the streets near the plaza.",
	held = "Bestine: the Imperial garrison has repelled the Rebel assault.",
	fell = "Bestine: the garrison is overrun. Rebel forces hold the plaza.",
	withdrew = "Bestine: the Rebel attackers have withdrawn into the desert. The city stands.",
	news = {
		held = "The Rebels hit Bestine and bounced off the garrison. Lot of bodies in the plaza.",
		fell = "Bestine fell to a Rebel assault. The Empire will want it back by morning.",
		withdrew = "A Rebel column probed Bestine and pulled back before it was decided.",
	},
	},
}
