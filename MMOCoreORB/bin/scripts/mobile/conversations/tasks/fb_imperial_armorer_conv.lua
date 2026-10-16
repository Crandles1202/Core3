-- fb_imperial_armorer_conv.lua

fbImperialArmorerConvoTemplate = ConvoTemplate:new {
	initialScreen = "intro",
	templateType = "Lua",
	luaClassHandler = "fbImperialArmorerConvoHandler",
	screens = {}
}

intro = ConvoScreen:new {
	id = "intro",
	customDialogText = "State your business, citizen. I supply standard-issue Stormtrooper armor and Imperial sidearms — E-11s, DH-17s, DLT-20s. Authorized personnel only. What do you need?",
	stopConversation = "false",
	options = {
		{"Show me the armory.",     "do_buy"},
		{"I'm just passing through.", "do_decline"},
	}
}
fbImperialArmorerConvoTemplate:addScreen(intro)

do_buy = ConvoScreen:new { id = "do_buy", customDialogText = "Very good. Step over to the requisition table.", stopConversation = "true", options = {} }
fbImperialArmorerConvoTemplate:addScreen(do_buy)

do_decline = ConvoScreen:new { id = "do_decline", customDialogText = "Move along, then. The Empire is watching.", stopConversation = "true", options = {} }
fbImperialArmorerConvoTemplate:addScreen(do_decline)

addConversationTemplate("fbImperialArmorerConvoTemplate", fbImperialArmorerConvoTemplate)
