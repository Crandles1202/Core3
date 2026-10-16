-- fb_cantina_dancer_conv.lua

fbCantinaDancerConvoTemplate = ConvoTemplate:new {
	initialScreen = "intro",
	templateType = "Lua",
	luaClassHandler = "fbCantinaDancerConvoHandler",
	screens = {}
}

intro = ConvoScreen:new {
	id = "intro",
	customDialogText = "Hey there, traveler. Looking to unwind? Watch me dance for a bit and I'll clear that battle fatigue right out of you. The full enhancement package is on the house — Klee's tipping me fine.",
	stopConversation = "false",
	options = {
		{"Watch the show. (Get Entertainer + Doctor buffs, clear Battle Fatigue)",  "do_watch"},
		{"Just clear my Battle Fatigue.",                                            "do_clear_bf"},
		{"Maybe later.",                                                             "do_decline"},
	}
}
fbCantinaDancerConvoTemplate:addScreen(intro)

do_watch = ConvoScreen:new {
	id = "do_watch",
	customDialogText = "Eyes on me, then. *spins gracefully* Mind soothed, battle fatigue gone, body feeling fresh. Come back any time.",
	stopConversation = "true",
	options = {}
}
fbCantinaDancerConvoTemplate:addScreen(do_watch)

do_clear_bf = ConvoScreen:new {
	id = "do_clear_bf",
	customDialogText = "Done. Your mind is clear. Stay a while if you can — the drinks are good.",
	stopConversation = "true",
	options = {}
}
fbCantinaDancerConvoTemplate:addScreen(do_clear_bf)

do_decline = ConvoScreen:new {
	id = "do_decline",
	customDialogText = "Suit yourself. I'll be on stage if you change your mind.",
	stopConversation = "true",
	options = {}
}
fbCantinaDancerConvoTemplate:addScreen(do_decline)

do_in_combat = ConvoScreen:new {
	id = "do_in_combat",
	customDialogText = "Whoa — finish your fight first. I can't dance for someone swinging a blaster around.",
	stopConversation = "true",
	options = {}
}
fbCantinaDancerConvoTemplate:addScreen(do_in_combat)

addConversationTemplate("fbCantinaDancerConvoTemplate", fbCantinaDancerConvoTemplate)
