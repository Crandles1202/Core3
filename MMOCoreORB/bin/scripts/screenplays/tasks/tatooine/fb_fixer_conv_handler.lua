-- fb_fixer_conv_handler.lua — Dax Ventrell (Phase 4c): the bounty paid off for a markup.

fbFixerConvoHandler = conv_handler:new {}

function fbFixerConvoHandler:getInitialScreen(pPlayer, pNpc, pConvTemplate)
	local convoTemplate = LuaConversationTemplate(pConvTemplate)
	if FbBounty == nil then return convoTemplate:getScreen("nothing") end
	local id = FbBounty:fixerScreen(pPlayer)
	if id == "offer" then
		local msg = LuaStringIdChatParameter("@fb_force:fixer_price"); msg:setDI(FbBounty:price(pPlayer))
		CreatureObject(pPlayer):sendSystemMessage(msg:_getObject())
	end
	return convoTemplate:getScreen(id)
end

function fbFixerConvoHandler:runScreenHandlers(pConvTemplate, pPlayer, pNpc, selectedOption, pConvScreen)
	local screen = LuaConversationScreen(pConvScreen)
	if screen:getScreenID() == "pay" and FbBounty ~= nil then FbBounty:pay(pPlayer) end
	return pConvScreen
end
