-- tasks/scenes/bestine_dressing_down.lua — Phase 3.14 street scene, played by FbScenes (tasks/fb_scenes.lua) when a player is near.
FbScenes:add {
	key = "bestine_dressing_down", city = "bestine", at = "plaza", offset = { 6, 4 },
	every = { 900, 1500 },
	cast = {
		{ name = "officer", template = "crackdown_imperial_first_lieutenant", dx = 0, dy = 0, mood = "npc_angry" },
		{ name = "trooper1", template = "stormtrooper", dx = -2, dy = 2 },
		{ name = "trooper2", template = "stormtrooper", dx = 2, dy = 2 },
	},
	beats = {
		{ say = "officer", text = "Which of you left the east checkpoint unmanned for forty minutes?" },
		{ say = "trooper1", text = "Sir, the relief never arrived, sir." },
		{ say = "officer", text = "The relief is standing next to you, trooper." },
		{ emote = "trooper2", anim = "nod_head_once", pause = 2 },
		{ say = "officer", text = "Double shifts for both of you. And the Governor hears nothing of this. Dismissed." },
		{ emote = "officer", anim = "wave_finger_warning", pause = 2 },
		{ leave = "trooper1", pause = 1 },
		{ leave = "trooper2", pause = 1 },
	},
}
