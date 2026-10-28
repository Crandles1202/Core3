-- tasks/scenes/bestine_arrest.lua — Phase 3.14 street scene, played by FbScenes (tasks/fb_scenes.lua) when a player is near.
FbScenes:add {
	key = "bestine_arrest", city = "bestine", at = "starport", offset = { -7, 2 },
	every = { 1200, 2400 },
	cast = {
		{ name = "trooper1", template = "stormtrooper", dx = 0, dy = 0, walks = true },
		{ name = "trooper2", template = "stormtrooper", dx = 2, dy = 0 },
		{ name = "suspect", template = "commoner_tatooine_female", dx = 1, dy = 2, mood = "npc_scared", walks = true },
	},
	beats = {
		{ say = "trooper1", text = "Identification. Now." },
		{ say = "suspect", text = "I'm just a farmer. I sell water. Ask anyone." },
		{ say = "trooper2", text = "Her name's on the list, corporal." },
		{ say = "suspect", text = "What list? There's no list!" },
		{ say = "trooper1", text = "Walk. Quietly, or not quietly, your choice." },
		{ walk = "trooper1", dx = 10, dy = -8, pause = 5 },
		{ walk = "suspect", dx = 10, dy = -8, pause = 5 },
		{ leave = "suspect", pause = 1 },
		{ leave = "trooper1", pause = 1 },
	},
}
