-- tasks/scenes/mos_eisley_drunk.lua — Phase 3.14 street scene, played by FbScenes (tasks/fb_scenes.lua) when a player is near.
FbScenes:add {
	key = "mos_eisley_drunk", city = "mos_eisley", at = "plaza", offset = { 5, -4 },
	every = { 900, 1500 },
	cast = {
		{ name = "drunk", template = "patron", dx = 0, dy = 0, mood = "npc_drunk", walks = true },
		{ name = "bouncer", template = "businessman", dx = 2, dy = 0, mood = "npc_angry" },
	},
	beats = {
		{ say = "bouncer", text = "Out. And don't come back until you can pay for what you broke." },
		{ say = "drunk", text = "I didn't break nothin'. The chair was like that." },
		{ emote = "bouncer", anim = "wave_finger_warning", pause = 2 },
		{ say = "drunk", text = "Fine! Fine. There's better cantinas on this rock anyway. There aren't, but still." },
		{ walk = "drunk", dx = 12, dy = 6, pause = 5 },
		{ say = "drunk", text = "...wretched hive..." },
		{ emote = "bouncer", anim = "shake_head_no", pause = 2 },
		{ leave = "drunk", pause = 1 },
	},
}
