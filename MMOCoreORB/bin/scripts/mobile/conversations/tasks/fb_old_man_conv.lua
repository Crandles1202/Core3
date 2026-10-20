-- fb_old_man_conv.lua — the Old Man's first visit (Phase 4a.1). Handler: fbOldManConvoHandler (screenplays/tasks/tatooine/fb_old_man_conv_handler.lua).

fbOldManConvoTemplate = ConvoTemplate:new {
	initialScreen = "intro",
	templateType = "Lua",
	luaClassHandler = "fbOldManConvoHandler",
	screens = {}
}

intro = ConvoScreen:new {
	id = "intro",
	leftDialog = "@fb_force:oldman_intro",
	stopConversation = "false",
	options = {
		{"Who are you?",             "who"},
		{"What do you want with me?", "task"},
		{"I want no part of this.",   "refuse"},
	}
}
fbOldManConvoTemplate:addScreen(intro)

who = ConvoScreen:new {
	id = "who",
	leftDialog = "@fb_force:oldman_who",
	stopConversation = "false",
	options = {
		{"What do you want with me?", "task"},
		{"I want no part of this.",   "refuse"},
	}
}
fbOldManConvoTemplate:addScreen(who)

task = ConvoScreen:new {
	id = "task",
	leftDialog = "@fb_force:oldman_task",
	stopConversation = "false",
	options = {
		{"And then?", "warning"},
	}
}
fbOldManConvoTemplate:addScreen(task)

warning = ConvoScreen:new {
	id = "warning",
	leftDialog = "@fb_force:oldman_warning",
	stopConversation = "true",
	options = {}
}
fbOldManConvoTemplate:addScreen(warning)

refuse = ConvoScreen:new {
	id = "refuse",
	leftDialog = "@fb_force:oldman_refuse",
	stopConversation = "true",
	options = {}
}
fbOldManConvoTemplate:addScreen(refuse)

return_intro = ConvoScreen:new {
	id = "return_intro",
	leftDialog = "@fb_force:oldman_return_intro",
	stopConversation = "false",
	options = {
		{"What comes next?", "return_trials"},
		{"I need more time.",  "return_wait"},
	}
}
fbOldManConvoTemplate:addScreen(return_intro)

return_trials = ConvoScreen:new {
	id = "return_trials",
	leftDialog = "@fb_force:oldman_return_trials",
	stopConversation = "true",
	options = {}
}
fbOldManConvoTemplate:addScreen(return_trials)

return_wait = ConvoScreen:new {
	id = "return_wait",
	leftDialog = "@fb_force:oldman_return_wait",
	stopConversation = "true",
	options = {}
}
fbOldManConvoTemplate:addScreen(return_wait)

nothing = ConvoScreen:new {
	id = "nothing",
	leftDialog = "@fb_force:oldman_nothing",
	stopConversation = "true",
	options = {}
}
fbOldManConvoTemplate:addScreen(nothing)

addConversationTemplate("fbOldManConvoTemplate", fbOldManConvoTemplate)
