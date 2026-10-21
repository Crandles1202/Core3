-- fb_jedi_master_conv.lua — Master Ilara Venn (Phase 4b.1). Handler: fbJediMasterConvoHandler
-- (screenplays/tasks/tatooine/fb_jedi_master_conv_handler.lua) picks the opening screen from the student's state.

fbJediMasterConvoTemplate = ConvoTemplate:new {
	initialScreen = "stranger",
	templateType = "Lua",
	luaClassHandler = "fbJediMasterConvoHandler",
	screens = {}
}

local function screen(id, text, options, stop)
	local s = ConvoScreen:new { id = id, leftDialog = "@fb_force:" .. text, stopConversation = stop and "true" or "false", options = options or {} }
	fbJediMasterConvoTemplate:addScreen(s)
end

-- not on the path / the other door
screen("stranger", "master_stranger", {}, true)
screen("otherdoor", "master_otherdoor", {}, true)

-- the offer
screen("offer", "master_offer", {
	{"I am ready to learn.", "take"},
	{"Not yet.", "later"},
})
screen("take", "master_take", {}, true)
screen("later", "master_later", {}, true)

-- the tasks: given, waited for, reported
screen("train_stillness", "master_train_stillness", { {"I will.", "told_stillness"} })
screen("told_stillness", "master_told", {}, true)
screen("wait_stillness", "master_wait_stillness", {}, true)
screen("done_stillness", "master_done_stillness", { {"I sat.", "reward_stillness"} })
screen("reward_stillness", "master_reward_stillness", {}, true)

screen("train_shadows", "master_train_shadows", { {"I will.", "told_shadows"} })
screen("told_shadows", "master_told", {}, true)
screen("wait_shadows", "master_wait_shadows", {}, true)
screen("done_shadows", "master_done_shadows", { {"It is done.", "reward_shadows"} })
screen("reward_shadows", "master_reward_shadows", {}, true)

-- nothing more to give yet (4b.3)
screen("trained", "master_trained", {}, true)

addConversationTemplate("fb_jedi_master_conv", fbJediMasterConvoTemplate)
