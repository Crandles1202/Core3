-- fb_old_man_conv_handler.lua — the Old Man's first visit (Phase 4a.1). The Old Man is spawned per player by
-- FbOldManVisit (custom_scripts/screenplays/fb_attunement.lua); he only talks to the character he came for.

fbOldManConvoHandler = conv_handler:new {}

function fbOldManConvoHandler:getInitialScreen(pPlayer, pNpc, pConvTemplate)
	local convoTemplate = LuaConversationTemplate(pConvTemplate)
	if FbOldManVisit ~= nil and FbOldManVisit:belongsTo(pPlayer, pNpc) then
		return convoTemplate:getScreen("intro")
	end
	return convoTemplate:getScreen("nothing")
end

function fbOldManConvoHandler:runScreenHandlers(pConvTemplate, pPlayer, pNpc, selectedOption, pConvScreen)
	local screen = LuaConversationScreen(pConvScreen)
	local screenID = screen:getScreenID()
	if screenID == "warning" then
		-- the call is accepted: the shrine task begins (4a.2 reads FbAttunement called/task)
		FbAttunement:accept(pPlayer)
		CreatureObject(pNpc):clearOptionBit(CONVERSABLE)
		FbOldManVisit:scheduleDespawn(pPlayer)
	elseif screenID == "refuse" then
		CreatureObject(pNpc):clearOptionBit(CONVERSABLE)
		FbOldManVisit:scheduleDespawn(pPlayer)
	end
	return pConvScreen
end
