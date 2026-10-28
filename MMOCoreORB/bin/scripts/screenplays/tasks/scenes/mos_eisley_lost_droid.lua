-- tasks/scenes/mos_eisley_lost_droid.lua — Phase 3.14 street scene, played by FbScenes (tasks/fb_scenes.lua) when a player is near.
FbScenes:add {
	key = "mos_eisley_lost_droid", city = "mos_eisley", at = "starport", offset = { 8, -3 },
	every = { 900, 1800 },
	cast = {
		{ name = "droid", template = "r2", dx = 0, dy = 0, walks = true },
		{ name = "spacer", template = "commoner_tatooine_female", dx = 3, dy = 2, mood = "npc_bored" },
	},
	beats = {
		{ say = "droid", text = "*a worried series of beeps and whistles*" },
		{ say = "spacer", text = "No, I haven't seen your master. What does he look like?" },
		{ say = "droid", text = "*a long descriptive warble*" },
		{ say = "spacer", text = "Tall, Corellian, owes you credits. That's half the port, little one." },
		{ walk = "droid", dx = -6, dy = 8, pause = 5 },
		{ say = "droid", text = "*a dejected tone*" },
		{ leave = "droid", pause = 1 },
	},
}
