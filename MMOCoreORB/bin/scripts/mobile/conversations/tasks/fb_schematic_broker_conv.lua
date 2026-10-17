-- fb_schematic_broker_conv.lua — Phase 2.2 schematic broker conversation.
fbSchematicBrokerConvoTemplate = ConvoTemplate:new {
	initialScreen = "intro",
	templateType = "Lua",
	luaClassHandler = "fbSchematicBrokerConvoHandler",
	screens = {}
}

intro = ConvoScreen:new {
	id = "intro",
	customDialogText = "Schematics, friend. Single-use, fully legal, mostly. Furniture, kitchen gear, recyclers, a few workshop pieces. The rare stuff you still have to earn out there - I only deal in what a working crafter can use today.",
	stopConversation = "false",
	options = {
		{"Show me the catalogue.",        "do_catalogue"},
		{"How does a bought schematic work?", "do_explain"},
		{"Not today.",                    "do_decline"},
	}
}
fbSchematicBrokerConvoTemplate:addScreen(intro)

do_catalogue = ConvoScreen:new {
	id = "do_catalogue",
	customDialogText = "Take your time. Cash only, no refunds.",
	stopConversation = "true",
	options = {}
}
fbSchematicBrokerConvoTemplate:addScreen(do_catalogue)

do_explain = ConvoScreen:new {
	id = "do_explain",
	customDialogText = "You buy the datapad, use it from your inventory, and the schematic appears in your crafting tool for one build. Each datapad is labelled with the profession box you need to read it - some take anyone, most want the matching crafter - and you still need resources and a crafting tool. A real crafter will beat my prices; I'm here for when there isn't one around.",
	stopConversation = "false",
	options = {
		{"Show me the catalogue.",  "do_catalogue"},
		{"Not today.",              "do_decline"},
	}
}
fbSchematicBrokerConvoTemplate:addScreen(do_explain)

do_decline = ConvoScreen:new {
	id = "do_decline",
	customDialogText = "Suit yourself. The datapads keep.",
	stopConversation = "true",
	options = {}
}
fbSchematicBrokerConvoTemplate:addScreen(do_decline)

addConversationTemplate("fbSchematicBrokerConvoTemplate", fbSchematicBrokerConvoTemplate)
