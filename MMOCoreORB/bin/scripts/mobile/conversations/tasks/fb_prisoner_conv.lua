-- fb_prisoner_conv.lua — the fourth Padawan trial (Phase 4a.3). Handler: fbPrisonerConvoHandler.

fbPrisonerConvoTemplate = ConvoTemplate:new {
	initialScreen = "plea",
	templateType = "Lua",
	luaClassHandler = "fbPrisonerConvoHandler",
	screens = {}
}

plea = ConvoScreen:new {
	id = "plea",
	leftDialog = "@fb_force:prisoner_plea",
	stopConversation = "false",
	options = {
		{"What did you do?",        "truth"},
		{"You're free. Go.",        "free"},
		{"No witnesses.",           "kill"},
	}
}
fbPrisonerConvoTemplate:addScreen(plea)

truth = ConvoScreen:new {
	id = "truth",
	leftDialog = "@fb_force:prisoner_truth",
	stopConversation = "false",
	options = {
		{"You're free. Go.",        "free"},
		{"No witnesses.",           "kill"},
	}
}
fbPrisonerConvoTemplate:addScreen(truth)

free = ConvoScreen:new { id = "free", leftDialog = "@fb_force:prisoner_freed", stopConversation = "true", options = {} }
fbPrisonerConvoTemplate:addScreen(free)

kill = ConvoScreen:new { id = "kill", leftDialog = "@fb_force:prisoner_killed", stopConversation = "true", options = {} }
fbPrisonerConvoTemplate:addScreen(kill)

nothing = ConvoScreen:new { id = "nothing", leftDialog = "@fb_force:oldman_nothing", stopConversation = "true", options = {} }
fbPrisonerConvoTemplate:addScreen(nothing)

addConversationTemplate("fbPrisonerConvoTemplate", fbPrisonerConvoTemplate)
