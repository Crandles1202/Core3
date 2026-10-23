-- fb_sith_master_conv_handler.lua — Darth Ysanne Vhal's conversation (Phase 4b.2). The opening screen comes from FbSithMaster:screenFor
-- (custom_scripts/screenplays/fb_masters.lua); the screens' effects are here. Both Masters share the screen ids.

fbSithMasterConvoHandler = conv_handler:new {}

function fbSithMasterConvoHandler:getInitialScreen(pPlayer, pNpc, pConvTemplate)
	local convoTemplate = LuaConversationTemplate(pConvTemplate)
	if FbSithMaster == nil then return convoTemplate:getScreen("stranger") end
	local id = FbSithMaster:screenFor(pPlayer)
	if id == "otherdoor" then FbSithMaster:turnAway(pPlayer) end
	return convoTemplate:getScreen(id)
end

function fbSithMasterConvoHandler:runScreenHandlers(pConvTemplate, pPlayer, pNpc, selectedOption, pConvScreen)
	local screen = LuaConversationScreen(pConvScreen)
	local screenID = screen:getScreenID()
	if FbSithMaster == nil then return pConvScreen end
	if screenID == "take" then
		FbSithMaster:take(pPlayer)
	elseif screenID == "turned" then
		FbSithMaster:turn(pPlayer)
	elseif screenID == "knight_go" and FbKnight ~= nil then
		FbKnight:give(pPlayer)
	elseif screenID == "knight_done" and FbKnight ~= nil then
		FbKnight:graduate(pPlayer)
	elseif screenID == "comp_take" and FbCompanion ~= nil then
		FbCompanion:give(pPlayer)
	elseif screenID == "comp_betray_do" and FbCompanion ~= nil then
		FbCompanion:betray(pPlayer)
	elseif screenID:sub(1, 5) == "told_" then
		FbSithMaster:told(pPlayer, screenID:sub(6))
	elseif screenID:sub(1, 7) == "reward_" then
		FbSithMaster:reward(pPlayer, screenID:sub(8))
	end
	return pConvScreen
end
