-- fb_knight_boss_conv.lua — the Knight trial's beaten enemy (Phase 4b.4). Handler: fbKnightBossConvoHandler.
-- Only its own student gets the yield screen, and only once it has yielded.

fbKnightBossConvoTemplate = ConvoTemplate:new {
	initialScreen = "nothing",
	templateType = "Lua",
	luaClassHandler = "fbKnightBossConvoHandler",
	screens = {}
}

local function screen(id, text, options, stop)
	local s = ConvoScreen:new { id = id, leftDialog = "@fb_force:" .. text, stopConversation = stop and "true" or "false", options = options or {} }
	fbKnightBossConvoTemplate:addScreen(s)
end

screen("nothing", "knight_boss_nothing", {}, true)
screen("yield", "knight_boss_yield", {
	{"Go. Do not come back.", "spare"},
	{"No.", "kill"},
})
screen("spare", "knight_boss_spared", {}, true)
screen("kill", "knight_boss_killed", {}, true)

addConversationTemplate("fb_knight_boss_conv", fbKnightBossConvoTemplate)
