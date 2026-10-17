-- fb_speeder_dealer_conv.lua

fbSpeederDealerConvoTemplate = ConvoTemplate:new {
	initialScreen = "intro",
	templateType = "Lua",
	luaClassHandler = "fbSpeederDealerConvoHandler",
	screens = {}
}

intro = ConvoScreen:new {
	id = "intro",
	customDialogText = "Welcome, welcome! Drosa Vex, finest speeder dealer on Tatooine — perhaps third finest. I have jetpacks, landspeeders, swoops, the X-34 like Skywalker drove. All as deeds — pop them in an open spot and watch them assemble. What's your pleasure?",
	stopConversation = "false",
	options = {
		{"Show me what you have.", "do_buy"},
		{"Just looking. Thanks.",  "do_decline"},
	}
}
fbSpeederDealerConvoTemplate:addScreen(intro)

do_buy = ConvoScreen:new { id = "do_buy", customDialogText = "Of course, of course. Here's the lineup.", stopConversation = "true", options = {} }
fbSpeederDealerConvoTemplate:addScreen(do_buy)

do_decline = ConvoScreen:new { id = "do_decline", customDialogText = "Come back when you need to move faster.", stopConversation = "true", options = {} }
fbSpeederDealerConvoTemplate:addScreen(do_decline)

addConversationTemplate("fbSpeederDealerConvoTemplate", fbSpeederDealerConvoTemplate)
