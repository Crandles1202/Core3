-- fb_food_vendor_conv.lua — Final Boss 2.16: Oola Prenn, the chef. intro -> "What is cooking?" -> do_list.
fbFoodVendorConvoTemplate = ConvoTemplate:new {
	initialScreen = "intro",
	templateType = "Lua",
	luaClassHandler = "fbFoodVendorConvoHandler",
	screens = {}
}
intro = ConvoScreen:new {
	id = "intro",
	customDialogText = "Oola Prenn, and yes, I cooked all of it. Every dish, dessert and drink a chef can make, done the way a master does it, and the cantina's own drinks besides. Nothing from the back room: I do not sell spice.",
	stopConversation = "false",
	options = {
		{"What is cooking?", "do_list"},
		{"How good is it?", "do_explain"},
		{"Just the smell, thanks.", "do_decline"},
	}
}
fbFoodVendorConvoTemplate:addScreen(intro)
do_list = ConvoScreen:new {
	id = "do_list",
	customDialogText = "Pick a shelf. Cash only, and no, you cannot have the recipes.",
	stopConversation = "true",
	options = {}
}
fbFoodVendorConvoTemplate:addScreen(do_list)
do_explain = ConvoScreen:new {
	id = "do_explain",
	customDialogText = "As good as the recipe allows: the full effect, the longest duration, the most helpings, and as light on the stomach as the dish can be made. A master chef with the best ingredients would match it, and nobody beats it. The cantina drinks are what the bartender pours, no more.",
	stopConversation = "false",
	options = {
		{"What is cooking?", "do_list"},
		{"Just the smell, thanks.", "do_decline"},
	}
}
fbFoodVendorConvoTemplate:addScreen(do_explain)
do_decline = ConvoScreen:new {
	id = "do_decline",
	customDialogText = "The smell is free. The rest is not.",
	stopConversation = "true",
	options = {}
}
fbFoodVendorConvoTemplate:addScreen(do_decline)
addConversationTemplate("fbFoodVendorConvoTemplate", fbFoodVendorConvoTemplate)
