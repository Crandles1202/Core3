-- tasks/scenes/mos_eisley_bounty_hunter.lua — Phase 3.14 street scene, played by FbScenes (tasks/fb_scenes.lua) when a player is near.
FbScenes:add {
	key = "mos_eisley_bounty_hunter", city = "mos_eisley", at = "plaza", offset = { -5, 5 },
	every = { 1200, 2400 }, radius = 40,
	cast = {
		{ name = "hunter", template = "fb_bounty_hunter", dx = 0, dy = 0, mood = "npc_angry" },
		{ name = "local", template = "commoner_tatooine", dx = 2, dy = 0, mood = "npc_worried" },
	},
	beats = {
		{ say = "hunter", text = "I'm looking for someone. Goes by {player}. Seen them?" },
		{ say = "local", text = "Never heard the name. We get a lot of names through here." },
		{ emote = "hunter", anim = "rub_chin_thoughtful", pause = 2 },
		{ say = "hunter", text = "Funny. Someone matching the description walked past a minute ago." },
		{ say = "local", text = "I mind my own business, friend. You should try it." },
		{ say = "hunter", text = "Tell {player} the galaxy's smaller than it looks." },
		{ leave = "hunter", pause = 1 },
	},
}
