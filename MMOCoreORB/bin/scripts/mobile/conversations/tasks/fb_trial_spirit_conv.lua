-- fb_trial_spirit_conv.lua — the spirit of the sixth and seventh Padawan trials (Phase 4a.3). Handler: fbTrialSpiritConvoHandler.
-- The handler picks the first screen: one of three riddles (the right option differs per riddle), or the sacrifice.

fbTrialSpiritConvoTemplate = ConvoTemplate:new {
	initialScreen = "riddle_1",
	templateType = "Lua",
	luaClassHandler = "fbTrialSpiritConvoHandler",
	screens = {}
}

riddle_1 = ConvoScreen:new {
	id = "riddle_1", leftDialog = "@fb_force:spirit_riddle_1", stopConversation = "false",
	options = { {"@fb_force:spirit_riddle_1_a", "right"}, {"@fb_force:spirit_riddle_1_b", "wrong"}, {"@fb_force:spirit_riddle_1_c", "wrong"} }
}
fbTrialSpiritConvoTemplate:addScreen(riddle_1)

riddle_2 = ConvoScreen:new {
	id = "riddle_2", leftDialog = "@fb_force:spirit_riddle_2", stopConversation = "false",
	options = { {"@fb_force:spirit_riddle_2_a", "wrong"}, {"@fb_force:spirit_riddle_2_b", "right"}, {"@fb_force:spirit_riddle_2_c", "wrong"} }
}
fbTrialSpiritConvoTemplate:addScreen(riddle_2)

riddle_3 = ConvoScreen:new {
	id = "riddle_3", leftDialog = "@fb_force:spirit_riddle_3", stopConversation = "false",
	options = { {"@fb_force:spirit_riddle_3_a", "wrong"}, {"@fb_force:spirit_riddle_3_b", "wrong"}, {"@fb_force:spirit_riddle_3_c", "right"} }
}
fbTrialSpiritConvoTemplate:addScreen(riddle_3)

right = ConvoScreen:new { id = "right", leftDialog = "@fb_force:spirit_right", stopConversation = "true", options = {} }
fbTrialSpiritConvoTemplate:addScreen(right)

wrong = ConvoScreen:new { id = "wrong", leftDialog = "@fb_force:spirit_wrong", stopConversation = "true", options = {} }
fbTrialSpiritConvoTemplate:addScreen(wrong)

sacrifice = ConvoScreen:new {
	id = "sacrifice", leftDialog = "@fb_force:spirit_sacrifice", stopConversation = "false",
	options = { {"Take them.", "give"}, {"Not today.", "keep"} }
}
fbTrialSpiritConvoTemplate:addScreen(sacrifice)

give = ConvoScreen:new { id = "give", leftDialog = "@fb_force:spirit_taken", stopConversation = "true", options = {} }
fbTrialSpiritConvoTemplate:addScreen(give)

keep = ConvoScreen:new { id = "keep", leftDialog = "@fb_force:spirit_leaves", stopConversation = "true", options = {} }
fbTrialSpiritConvoTemplate:addScreen(keep)

nothing = ConvoScreen:new { id = "nothing", leftDialog = "@fb_force:oldman_nothing", stopConversation = "true", options = {} }
fbTrialSpiritConvoTemplate:addScreen(nothing)

addConversationTemplate("fbTrialSpiritConvoTemplate", fbTrialSpiritConvoTemplate)
