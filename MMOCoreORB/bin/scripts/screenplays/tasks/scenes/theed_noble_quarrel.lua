-- tasks/scenes/theed_noble_quarrel.lua — Phase 3.14 street scene, played by FbScenes (tasks/fb_scenes.lua) when a player is near.
FbScenes:add {
	key = "theed_noble_quarrel", city = "theed", at = "plaza", offset = { 4, 6 },
	every = { 900, 1800 },
	cast = {
		{ name = "noble", template = "noble", dx = 0, dy = 0, mood = "npc_angry" },
		{ name = "official", template = "commoner_naboo", dx = 2, dy = 0, mood = "npc_worried" },
	},
	beats = {
		{ say = "noble", text = "My family has held that estate since before the Trade Federation, and the Governor's office wants it for a garrison?" },
		{ say = "official", text = "It is a temporary requisition, my lady. The compensation is generous." },
		{ emote = "noble", anim = "shake_head_no", pause = 2 },
		{ say = "noble", text = "Compensation. For a garrison in my mother's garden." },
		{ say = "official", text = "I will convey your displeasure. Carefully." },
		{ emote = "official", anim = "bow", pause = 2 },
		{ leave = "official", pause = 1 },
	},
}
