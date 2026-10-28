-- tasks/scenes/narmle_swamp_rumour.lua — Phase 3.14 street scene, played by FbScenes (tasks/fb_scenes.lua) when a player is near.
FbScenes:add {
	key = "narmle_swamp_rumour", city = "narmle", at = "starport", offset = { -6, -3 },
	every = { 900, 1800 },
	cast = {
		{ name = "old", template = "commoner_old", dx = 0, dy = 0, mood = "npc_worried" },
		{ name = "young", template = "commoner_naboo", dx = 2, dy = 0, mood = "npc_bored" },
	},
	beats = {
		{ say = "old", text = "Three speeders went into the swamp road this week. Two came out." },
		{ say = "young", text = "Garyn's lot?" },
		{ say = "old", text = "Garyn's lot don't leave the speeders. Something else is out there." },
		{ emote = "young", anim = "rub_chin_thoughtful", pause = 2 },
		{ say = "young", text = "You say that every week, grandfather." },
		{ say = "old", text = "And every week I'm right." },
		{ emote = "old", anim = "nod_head_once", pause = 2 },
	},
}
