-- fb_property_agent_conv.lua

fbPropertyAgentConvoTemplate = ConvoTemplate:new {
	initialScreen = "intro",
	templateType = "Lua",
	luaClassHandler = "fbPropertyAgentConvoHandler",
	screens = {}
}

intro = ConvoScreen:new {
	id = "intro",
	customDialogText = "Welcome to FB Real Estate. Garlen, your agent. I broker deeds for houses, harvesters, factories, generators, and turret platforms. Licensed Architects produce custom work; my stock is factory-standard prefabs. What can I show you?",
	stopConversation = "false",
	options = {
		{"Show me your catalogue.", "do_buy"},
		{"Just looking. Thanks.",   "do_decline"},
	}
}
fbPropertyAgentConvoTemplate:addScreen(intro)

do_buy = ConvoScreen:new { id = "do_buy", customDialogText = "Right this way. Plenty to choose from.", stopConversation = "true", options = {} }
fbPropertyAgentConvoTemplate:addScreen(do_buy)

do_decline = ConvoScreen:new { id = "do_decline", customDialogText = "Of course. When you're ready to build, you know where to find me.", stopConversation = "true", options = {} }
fbPropertyAgentConvoTemplate:addScreen(do_decline)

addConversationTemplate("fbPropertyAgentConvoTemplate", fbPropertyAgentConvoTemplate)
