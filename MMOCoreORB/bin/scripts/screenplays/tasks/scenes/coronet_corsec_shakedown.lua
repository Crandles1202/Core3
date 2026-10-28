-- tasks/scenes/coronet_corsec_shakedown.lua — Phase 3.14 street scene, played by FbScenes (tasks/fb_scenes.lua) when a player is near.
FbScenes:add {
	key = "coronet_corsec_shakedown", city = "coronet", at = "starport", offset = { 7, -4 },
	every = { 900, 1500 },
	cast = {
		{ name = "corsec1", template = "corsec_trooper", dx = 0, dy = 0 },
		{ name = "corsec2", template = "corsec_trooper", dx = 2, dy = 0 },
		{ name = "spacer", template = "patron", dx = 1, dy = 2, mood = "npc_scared" },
	},
	beats = {
		{ say = "corsec1", text = "Open the bag. Slowly." },
		{ say = "spacer", text = "It's spice. Medical spice. I have a... I had a permit." },
		{ say = "corsec2", text = "Everybody had a permit." },
		{ emote = "corsec1", anim = "wave_finger_warning", pause = 2 },
		{ say = "corsec1", text = "Confiscated. Be glad it's us and not the Imperials." },
		{ say = "spacer", text = "That was my whole run..." },
		{ leave = "corsec1", pause = 1 },
		{ leave = "corsec2", pause = 1 },
	},
}
