-- fb_component_depot_conv.lua — Final Boss 2.15: BX-4, the component depot. intro -> "Show me the parts" -> do_list.
fbComponentDepotConvoTemplate = ConvoTemplate:new {
	initialScreen = "intro",
	templateType = "Lua",
	luaClassHandler = "fbComponentDepotConvoHandler",
	screens = {}
}
intro = ConvoScreen:new {
	id = "intro",
	customDialogText = "BX-4, component depot. Every crafting component in the galaxy, catalogued. Parts with real stats are rolled fresh when you buy them; the raw ones come straight off the shelf.",
	stopConversation = "false",
	options = {
		{"Show me the parts.", "do_list"},
		{"What is the difference between rolled and raw?", "do_explain"},
		{"Just looking, thanks.", "do_decline"},
	}
}
fbComponentDepotConvoTemplate:addScreen(intro)
do_list = ConvoScreen:new {
	id = "do_list",
	customDialogText = "Pick a shelf. Cash only, no refunds, no returns on a part you experimented into the floor.",
	stopConversation = "true",
	options = {}
}
fbComponentDepotConvoTemplate:addScreen(do_list)
do_explain = ConvoScreen:new {
	id = "do_explain",
	customDialogText = "A rolled part comes out of the same machinery that drops it in the field: weapon, armor, chemistry and lightsaber parts with real values you can experiment on. A raw part is the bare component: every schematic accepts it, but it brings no values of its own, so the piece you make from it will be plain. Droid, structure, vehicle and food parts are raw; nobody has ever looted a better one.",
	stopConversation = "false",
	options = {
		{"Show me the parts.", "do_list"},
		{"Just looking, thanks.", "do_decline"},
	}
}
fbComponentDepotConvoTemplate:addScreen(do_explain)
do_decline = ConvoScreen:new {
	id = "do_decline",
	customDialogText = "The shelves will still be here.",
	stopConversation = "true",
	options = {}
}
fbComponentDepotConvoTemplate:addScreen(do_decline)
addConversationTemplate("fbComponentDepotConvoTemplate", fbComponentDepotConvoTemplate)
