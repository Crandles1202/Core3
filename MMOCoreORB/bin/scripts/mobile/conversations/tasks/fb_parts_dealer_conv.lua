-- fb_parts_dealer_conv.lua — Phase 2.3 parts dealer conversation.
fbPartsDealerConvoTemplate = ConvoTemplate:new {
	initialScreen = "intro",
	templateType = "Lua",
	luaClassHandler = "fbPartsDealerConvoHandler",
	screens = {}
}

intro = ConvoScreen:new {
	id = "intro",
	customDialogText = "Parts, crafter. Barrels, power handlers, armor segments, chemistry bits - the pieces you'd normally beg off another profession. Standard stock rolls decent; the advanced crates roll better and cost you three times as much.",
	stopConversation = "false",
	options = {
		{"Show me the parts.",            "do_parts"},
		{"Why buy parts from you?",       "do_explain"},
		{"Not today.",                    "do_decline"},
	}
}
fbPartsDealerConvoTemplate:addScreen(intro)

do_parts = ConvoScreen:new {
	id = "do_parts",
	customDialogText = "Have a look. Cash only, no refunds.",
	stopConversation = "true",
	options = {}
}
fbPartsDealerConvoTemplate:addScreen(do_parts)

do_explain = ConvoScreen:new {
	id = "do_explain",
	customDialogText = "Because a weaponsmith who needs a power handler shouldn't have to find an engineer first. Every part I sell is rolled fresh with real stats and goes straight into your crafting tool like any looted component. A dedicated crafter will beat my numbers and my prices - I'm here for when there isn't one around.",
	stopConversation = "false",
	options = {
		{"Show me the parts.",  "do_parts"},
		{"Not today.",          "do_decline"},
	}
}
fbPartsDealerConvoTemplate:addScreen(do_explain)

do_decline = ConvoScreen:new {
	id = "do_decline",
	customDialogText = "Crates aren't going anywhere.",
	stopConversation = "true",
	options = {}
}
fbPartsDealerConvoTemplate:addScreen(do_decline)

addConversationTemplate("fbPartsDealerConvoTemplate", fbPartsDealerConvoTemplate)
