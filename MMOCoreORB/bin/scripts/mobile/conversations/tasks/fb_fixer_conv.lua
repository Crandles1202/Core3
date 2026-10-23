-- fb_fixer_conv.lua — Dax Ventrell (Phase 4c). Handler: fbFixerConvoHandler picks the opening screen from the bounty.

fbFixerConvoTemplate = ConvoTemplate:new {
	initialScreen = "nothing",
	templateType = "Lua",
	luaClassHandler = "fbFixerConvoHandler",
	screens = {}
}

local function screen(id, text, options, stop)
	local s = ConvoScreen:new { id = id, leftDialog = "@fb_force:" .. text, stopConversation = stop and "true" or "false", options = options or {} }
	fbFixerConvoTemplate:addScreen(s)
end

screen("nothing", "fixer_nothing", {}, true)
screen("paid", "fixer_paid", {}, true)
screen("offer", "fixer_offer", {
	{"Make it go away.", "pay"},
	{"Not at that price.", "refuse"},
})
screen("pay", "fixer_pay", {}, true)
screen("refuse", "fixer_refuse", {}, true)

addConversationTemplate("fb_fixer_conv", fbFixerConvoTemplate)
