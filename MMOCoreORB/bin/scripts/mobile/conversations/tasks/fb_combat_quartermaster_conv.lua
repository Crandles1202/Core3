-- fb_combat_quartermaster_conv.lua
-- Install:  mobile/conversations/tasks/fb_combat_quartermaster_conv.lua
-- Register: includeFile("conversations/tasks/fb_combat_quartermaster_conv.lua")

fbCombatQuartermasterConvoTemplate = ConvoTemplate:new {
	initialScreen = "intro",
	templateType = "Lua",
	luaClassHandler = "fbCombatQuartermasterConvoHandler",
	screens = {}
}

intro = ConvoScreen:new {
	id = "intro",
	customDialogText = "Sehrev, FB Combat Supply. I deal in grenades — healing, damage, poison, disease, area-effect. Standard issue stock. A trained Combat Medic will brew you better, but I keep you alive between brewings.",
	stopConversation = "false",
	options = {
		{"Show me what you have.",      "do_buy"},
		{"What's in stock?",            "do_price_list"},
		{"Just passing by.",            "do_decline"},
	}
}
fbCombatQuartermasterConvoTemplate:addScreen(intro)

do_buy = ConvoScreen:new {
	id = "do_buy",
	customDialogText = "Right, here's the inventory.",
	stopConversation = "true",
	options = {}
}
fbCombatQuartermasterConvoTemplate:addScreen(do_buy)

do_price_list = ConvoScreen:new {
	id = "do_price_list",
	customDialogText = "Stock: Damage Grenades — A (200cr), B (350cr), C (500cr). Area-Effect Grenades — A (400cr), B (600cr), C (800cr). Tier A is basic, C is the toughest I carry. Cash only.",
	stopConversation = "false",
	options = {
		{"Show me the inventory.",   "do_buy"},
		{"Just passing by.",         "do_decline"},
	}
}
fbCombatQuartermasterConvoTemplate:addScreen(do_price_list)

do_decline = ConvoScreen:new {
	id = "do_decline",
	customDialogText = "Stay alive out there.",
	stopConversation = "true",
	options = {}
}
fbCombatQuartermasterConvoTemplate:addScreen(do_decline)

addConversationTemplate("fbCombatQuartermasterConvoTemplate", fbCombatQuartermasterConvoTemplate)
