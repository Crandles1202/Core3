-- fb_cantina_musician_conv.lua

fbCantinaMusicianConvoTemplate = ConvoTemplate:new {
	initialScreen = "intro",
	templateType = "Lua",
	luaClassHandler = "fbCantinaMusicianConvoHandler",
	screens = {}
}

intro = ConvoScreen:new {
	id = "intro",
	customDialogText = "*tuning a kloo horn* Got a request? Stick around for a set and I'll see what I can do for you — clear the battle fog, sharpen the focus, the works.",
	stopConversation = "false",
	options = {
		{"Listen to the set. (Get Entertainer + Doctor buffs, clear Battle Fatigue)", "do_listen"},
		{"Just clear my Battle Fatigue.",                                              "do_clear_bf"},
		{"Not right now.",                                                             "do_decline"},
	}
}
fbCantinaMusicianConvoTemplate:addScreen(intro)

do_listen = ConvoScreen:new {
	id = "do_listen",
	customDialogText = "*plays a slow, soothing tune* There. Mind clear, body humming. Drop a credit in the jar if you liked it.",
	stopConversation = "true",
	options = {}
}
fbCantinaMusicianConvoTemplate:addScreen(do_listen)

do_clear_bf = ConvoScreen:new {
	id = "do_clear_bf",
	customDialogText = "A quick lullaby, then. Better?",
	stopConversation = "true",
	options = {}
}
fbCantinaMusicianConvoTemplate:addScreen(do_clear_bf)

do_decline = ConvoScreen:new {
	id = "do_decline",
	customDialogText = "Suit yourself. I'll be here.",
	stopConversation = "true",
	options = {}
}
fbCantinaMusicianConvoTemplate:addScreen(do_decline)

do_in_combat = ConvoScreen:new {
	id = "do_in_combat",
	customDialogText = "Take your fight outside, friend. The band only plays for peaceful patrons.",
	stopConversation = "true",
	options = {}
}
fbCantinaMusicianConvoTemplate:addScreen(do_in_combat)

addConversationTemplate("fbCantinaMusicianConvoTemplate", fbCantinaMusicianConvoTemplate)
