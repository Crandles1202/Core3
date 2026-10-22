-- fb_sith_master_conv.lua — Darth Ysanne Vhal (Phase 4b.2). Handler: fbSithMasterConvoHandler
-- (screenplays/tasks/tatooine/fb_sith_master_conv_handler.lua) picks the opening screen from the student's state.

fbSithMasterConvoTemplate = ConvoTemplate:new {
	initialScreen = "stranger",
	templateType = "Lua",
	luaClassHandler = "fbSithMasterConvoHandler",
	screens = {}
}

local function screen(id, text, options, stop)
	local s = ConvoScreen:new { id = id, leftDialog = "@fb_force:" .. text, stopConversation = stop and "true" or "false", options = options or {} }
	fbSithMasterConvoTemplate:addScreen(s)
end

-- not on the path / the other door
screen("stranger", "sith_stranger", {}, true)
screen("otherdoor", "sith_otherdoor", {}, true)

-- the offer
screen("offer", "sith_offer", {
	{"I am ready to learn.", "take"},
	{"Not yet.", "later"},
})
screen("take", "sith_take", {}, true)
screen("later", "sith_later", {}, true)

-- the tasks: given, waited for, reported
screen("train_patience", "sith_train_patience", { {"I will.", "told_patience"} })
screen("told_patience", "sith_told", {}, true)
screen("wait_patience", "sith_wait_patience", {}, true)
screen("done_patience", "sith_done_patience", { {"I waited.", "reward_patience"} })
screen("reward_patience", "sith_reward_patience", {}, true)

screen("train_prey", "sith_train_prey", { {"I will.", "told_prey"} })
screen("told_prey", "sith_told", {}, true)
screen("wait_prey", "sith_wait_prey", {}, true)
screen("done_prey", "sith_done_prey", { {"It is done.", "reward_prey"} })
screen("reward_prey", "sith_reward_prey", {}, true)

-- the ladder (4b.3): a rank is a task, given when the experience is there, reported for the promotion
screen("rank_wait_xp", "sith_rank_wait_xp", {}, true)
screen("train_rank1", "sith_train_rank1", { {"I will.", "told_rank1"} })
screen("told_rank1", "sith_told", {}, true)
screen("wait_rank1", "sith_wait_rank1", {}, true)
screen("done_rank1", "sith_done_rank1", { {"It is done.", "reward_rank1"} })
screen("reward_rank1", "sith_reward_rank1", {}, true)
screen("train_rank2", "sith_train_rank2", { {"I will.", "told_rank2"} })
screen("told_rank2", "sith_told", {}, true)
screen("wait_rank2", "sith_wait_rank2", {}, true)
screen("done_rank2", "sith_done_rank2", { {"It is done.", "reward_rank2"} })
screen("reward_rank2", "sith_reward_rank2", {}, true)

-- the turn (4b.3): the other Master's student whose heart leans this way
screen("turn", "sith_turn", {
	{"I am done with them.", "turned"},
	{"No.", "later"},
})
screen("turned", "sith_turned", {}, true)

-- the ladder's end for now
screen("trained", "sith_trained", {}, true)

addConversationTemplate("fb_sith_master_conv", fbSithMasterConvoTemplate)
