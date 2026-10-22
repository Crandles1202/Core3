-- fb_knight_boss_conv_handler.lua — the Knight trial's beaten enemy (Phase 4b.4): spare or finish it.

fbKnightBossConvoHandler = conv_handler:new {}

function fbKnightBossConvoHandler:getInitialScreen(pPlayer, pNpc, pConvTemplate)
	local convoTemplate = LuaConversationTemplate(pConvTemplate)
	if FbKnight ~= nil and FbKnight:belongsTo(pPlayer, pNpc) and FbKnight:yielded(pNpc) and FbKnight:state(pPlayer) == "given" then
		return convoTemplate:getScreen("yield")
	end
	return convoTemplate:getScreen("nothing")
end

function fbKnightBossConvoHandler:runScreenHandlers(pConvTemplate, pPlayer, pNpc, selectedOption, pConvScreen)
	local screen = LuaConversationScreen(pConvScreen)
	local screenID = screen:getScreenID()
	if FbKnight == nil then return pConvScreen end
	if screenID == "spare" then FbKnight:spare(pPlayer, pNpc)
	elseif screenID == "kill" then FbKnight:execute(pPlayer, pNpc) end
	return pConvScreen
end
