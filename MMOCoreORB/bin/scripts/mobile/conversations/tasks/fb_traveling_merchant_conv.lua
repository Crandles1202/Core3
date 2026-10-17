-- fb_traveling_merchant_conv.lua — Phase 2.9 traveling merchant conversation.
fbTravelingMerchantConvoTemplate = ConvoTemplate:new {
	initialScreen = "intro",
	templateType = "Lua",
	luaClassHandler = "fbTravelingMerchantConvoHandler",
	screens = {}
}

intro = ConvoScreen:new {
	id = "intro",
	customDialogText = "Ozlo Vantrek, purveyor of the odd and the ornamental, passing through. Paintings nobody else carries, trinkets from three systems over, hats that will start conversations. I don't stay anywhere long - see something you like, buy it now.",
	stopConversation = "false",
	options = {
		{"Let's see what you've got.",      "do_stock"},
		{"Where are you headed next?",      "do_travel"},
		{"Safe travels.",                   "do_decline"},
	}
}
fbTravelingMerchantConvoTemplate:addScreen(intro)

do_stock = ConvoScreen:new {
	id = "do_stock",
	customDialogText = "Have a look. Everything here is one of a kind, at least on this planet.",
	stopConversation = "true",
	options = {}
}
fbTravelingMerchantConvoTemplate:addScreen(do_stock)

do_travel = ConvoScreen:new {
	id = "do_travel",
	customDialogText = "Wherever the shuttles are cheap and the customers are bored. A few hours here, then another city. My stock changes with every stop, so if you miss something, find me again and see what's new.",
	stopConversation = "false",
	options = {
		{"Let's see what you've got.",  "do_stock"},
		{"Safe travels.",               "do_decline"},
	}
}
fbTravelingMerchantConvoTemplate:addScreen(do_travel)

do_decline = ConvoScreen:new {
	id = "do_decline",
	customDialogText = "And to you. Don't wait too long.",
	stopConversation = "true",
	options = {}
}
fbTravelingMerchantConvoTemplate:addScreen(do_decline)

addConversationTemplate("fbTravelingMerchantConvoTemplate", fbTravelingMerchantConvoTemplate)
