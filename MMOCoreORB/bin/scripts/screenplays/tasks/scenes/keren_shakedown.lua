-- tasks/scenes/keren_shakedown.lua — Phase 3.14 street scene, played by FbScenes (tasks/fb_scenes.lua) when a player is near.
FbScenes:add {
	key = "keren_shakedown", city = "keren", at = "plaza", offset = { -4, 5 },
	every = { 900, 1800 },
	cast = {
		{ name = "thug", template = "borvos_thug", dx = 0, dy = 0, mood = "npc_angry" },
		{ name = "shopkeeper", template = "commoner_naboo", dx = 2, dy = 0, mood = "npc_scared" },
	},
	beats = {
		{ say = "thug", text = "Borvo sends his regards. And his invoice." },
		{ say = "shopkeeper", text = "I paid last month. I paid twice last month!" },
		{ say = "thug", text = "Prices went up. Protection's expensive in a war." },
		{ emote = "shopkeeper", anim = "sigh_deeply", pause = 2 },
		{ say = "shopkeeper", text = "Take it. Take it and go before the police come." },
		{ say = "thug", text = "The police? They're on the invoice too." },
		{ emote = "thug", anim = "laugh", pause = 2 },
		{ leave = "thug", pause = 1 },
	},
}
