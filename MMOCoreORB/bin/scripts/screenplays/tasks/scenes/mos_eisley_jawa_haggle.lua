-- tasks/scenes/mos_eisley_jawa_haggle.lua — Phase 3.14 street scene, played by FbScenes (tasks/fb_scenes.lua) when a player is near.
FbScenes:add {
	key = "mos_eisley_jawa_haggle", city = "mos_eisley", at = "starport", offset = { -6, 5 },
	every = { 600, 1200 },
	cast = {
		{ name = "jawa", template = "jawa", dx = 0, dy = 0, mood = "npc_angry" },
		{ name = "farmer", template = "commoner_tatooine_male", dx = 2, dy = 1, mood = "npc_consoling" },
	},
	beats = {
		{ say = "jawa", text = "Utinni! Utinni!" },
		{ say = "farmer", text = "Two hundred for a vaporator coil? It was three hundred last week." },
		{ emote = "jawa", anim = "shake_head_no", pause = 2 },
		{ say = "jawa", text = "Mo bagwa jawa! Utinni..." },
		{ say = "farmer", text = "Fine. Two-fifty, and you throw in the restraining bolt." },
		{ emote = "jawa", anim = "nod_head_once", pause = 2 },
		{ say = "farmer", text = "Robbery. Absolute robbery." },
		{ leave = "jawa", pause = 1 },
	},
}
