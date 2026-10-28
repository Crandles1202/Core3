-- tasks/scenes/theed_papers.lua — Phase 3.14 street scene, played by FbScenes (tasks/fb_scenes.lua) when a player is near.
FbScenes:add {
	key = "theed_papers", city = "theed", at = "starport", offset = { 6, 3 },
	every = { 900, 1500 },
	cast = {
		{ name = "police", template = "naboo_police_officer", dx = 0, dy = 0 },
		{ name = "traveller", template = "commoner_naboo", dx = 2, dy = 1, mood = "npc_bored" },
	},
	beats = {
		{ say = "police", text = "Travel permit, please. New arrivals are checked by order of the Governor." },
		{ say = "traveller", text = "Of course. It's... here somewhere." },
		{ emote = "police", anim = "rub_chin_thoughtful", pause = 2 },
		{ say = "traveller", text = "There. Stamped in Keren this morning." },
		{ say = "police", text = "Enjoy Theed. Stay off the palace steps after dark." },
		{ emote = "police", anim = "nod_head_once", pause = 2 },
		{ leave = "traveller", pause = 1 },
	},
}
