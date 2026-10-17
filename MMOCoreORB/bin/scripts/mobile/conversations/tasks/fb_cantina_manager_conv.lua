-- fb_cantina_manager_conv.lua

fbCantinaManagerConvoTemplate = ConvoTemplate:new {
	initialScreen = "intro",
	templateType = "Lua",
	luaClassHandler = "fbCantinaManagerConvoHandler",
	screens = {}
}

intro = ConvoScreen:new {
	id = "intro",
	customDialogText = "Hahh, hello friend. Klee, manager of this fine establishment. Hungry? Thirsty? Want something sweet? My larder has everything — dishes, desserts, drinks. Licensed Chefs do better preparation, but my stuff'll fill you up. What sounds good?",
	stopConversation = "false",
	options = {
		{"Show me the menu.",       "do_buy"},
		{"Just looking. Thanks.",   "do_decline"},
	}
}
fbCantinaManagerConvoTemplate:addScreen(intro)

do_buy = ConvoScreen:new { id = "do_buy", customDialogText = "Excellent! Step right up.", stopConversation = "true", options = {} }
fbCantinaManagerConvoTemplate:addScreen(do_buy)

do_decline = ConvoScreen:new { id = "do_decline", customDialogText = "Hahh, come back hungry.", stopConversation = "true", options = {} }
fbCantinaManagerConvoTemplate:addScreen(do_decline)

addConversationTemplate("fbCantinaManagerConvoTemplate", fbCantinaManagerConvoTemplate)
