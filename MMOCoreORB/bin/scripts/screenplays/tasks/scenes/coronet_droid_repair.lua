-- tasks/scenes/coronet_droid_repair.lua — Phase 3.14 street scene, played by FbScenes (tasks/fb_scenes.lua) when a player is near.
FbScenes:add {
	key = "coronet_droid_repair", city = "coronet", at = "plaza", offset = { -5, 6 },
	every = { 900, 1800 },
	cast = {
		{ name = "tech", template = "businessman", dx = 0, dy = 0, mood = "npc_angry" },
		{ name = "owner", template = "commoner", dx = 3, dy = 0, mood = "npc_angry" },
		{ name = "droid", template = "r2", dx = 1, dy = 2 },
	},
	beats = {
		{ say = "owner", text = "Four hundred credits and it still can't find the hyperspace lane to Talus!" },
		{ say = "tech", text = "The motivator's fine. Your astromech has a personality problem." },
		{ say = "droid", text = "*an indignant trill*" },
		{ say = "owner", text = "See? It agrees with me." },
		{ say = "tech", text = "It said you fly like a drunk bantha. I only translate." },
		{ emote = "owner", anim = "shake_head_no", pause = 2 },
		{ say = "owner", text = "Fine. Half now, half when it stops insulting me." },
		{ leave = "owner", pause = 1 },
		{ leave = "droid", pause = 1 },
	},
}
