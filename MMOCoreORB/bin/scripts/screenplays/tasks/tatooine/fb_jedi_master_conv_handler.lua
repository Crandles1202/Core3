-- fb_jedi_master_conv_handler.lua — Master Ilara Venn's conversation (Phase 4b.1). The opening screen comes from FbJediMaster:screenFor
-- (custom_scripts/screenplays/fb_masters.lua); the screens' effects are here. Both Masters share the screen ids.

fbJediMasterConvoHandler = conv_handler:new {}

function fbJediMasterConvoHandler:getInitialScreen(pPlayer, pNpc, pConvTemplate)
	local convoTemplate = LuaConversationTemplate(pConvTemplate)
	if FbJediMaster == nil then return convoTemplate:getScreen("stranger") end
	local id = FbJediMaster:screenFor(pPlayer)
	if id == "otherdoor" then FbJediMaster:turnAway(pPlayer) end
	return convoTemplate:getScreen(id)
end

function fbJediMasterConvoHandler:runScreenHandlers(pConvTemplate, pPlayer, pNpc, selectedOption, pConvScreen)
	local screen = LuaConversationScreen(pConvScreen)
	local screenID = screen:getScreenID()
	if FbJediMaster == nil then return pConvScreen end
	if screenID == "take" then
		FbJediMaster:take(pPlayer)
	elseif screenID == "turned" then
		FbJediMaster:turn(pPlayer)
	elseif screenID:sub(1, 5) == "told_" then
		FbJediMaster:told(pPlayer, screenID:sub(6))
	elseif screenID:sub(1, 7) == "reward_" then
		FbJediMaster:reward(pPlayer, screenID:sub(8))
	end
	return pConvScreen
end
