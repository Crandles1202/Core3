-- fb_droid_dispenser_conv.lua

fbDroidDispenserConvoTemplate = ConvoTemplate:new {
	initialScreen = "intro",
	templateType = "Lua",
	luaClassHandler = "fbDroidDispenserConvoHandler",
	screens = {}
}

intro = ConvoScreen:new {
	id = "intro",
	customDialogText = "FB-3D, Droid Dispensary. I carry deeds for the standard service droid lines — protocol, astromech, repair, utility. Pop the deed in a calm spot and it'll instantiate. Higher-grade droids and customizations are available from licensed Droid Engineers.",
	stopConversation = "false",
	options = {
		{"Show me your droid catalogue.",  "do_buy"},
		{"Just looking. Thanks.",          "do_decline"},
	}
}
fbDroidDispenserConvoTemplate:addScreen(intro)

do_buy = ConvoScreen:new { id = "do_buy", customDialogText = "Accessing droid inventory.", stopConversation = "true", options = {} }
fbDroidDispenserConvoTemplate:addScreen(do_buy)

do_decline = ConvoScreen:new { id = "do_decline", customDialogText = "Acknowledged. Return when you need a droid.", stopConversation = "true", options = {} }
fbDroidDispenserConvoTemplate:addScreen(do_decline)

addConversationTemplate("fbDroidDispenserConvoTemplate", fbDroidDispenserConvoTemplate)
