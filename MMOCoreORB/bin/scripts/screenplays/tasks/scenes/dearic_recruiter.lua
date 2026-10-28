-- tasks/scenes/dearic_recruiter.lua — Phase 3.14 street scene, played by FbScenes (tasks/fb_scenes.lua) when a player is near.
FbScenes:add {
	key = "dearic_recruiter", city = "dearic", at = "plaza", offset = { 5, -5 },
	every = { 1200, 2400 },
	cast = {
		{ name = "pirate", template = "binayre_pirate", dx = 0, dy = 0, mood = "npc_bored" },
		{ name = "youth", template = "commoner", dx = 2, dy = 1, mood = "npc_worried" },
	},
	beats = {
		{ say = "pirate", text = "Good money on the river barges, kid. Nobody asks where the cargo's from." },
		{ say = "youth", text = "My mother says Binayre crews don't come back." },
		{ say = "pirate", text = "Some don't. The ones who do come back rich." },
		{ emote = "youth", anim = "shake_head_no", pause = 2 },
		{ say = "youth", text = "I'll think about it." },
		{ say = "pirate", text = "Think fast. We sail at dusk." },
		{ leave = "pirate", pause = 1 },
	},
}
