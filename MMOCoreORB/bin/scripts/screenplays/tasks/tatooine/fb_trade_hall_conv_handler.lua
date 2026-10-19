-- fb_trade_hall_conv_handler.lua — Hallkeeper Jyn Odaro (Phase 2.11)
local ObjectManager = require("managers.object.object_manager")

fbTradeHallKeeperConvoHandler = conv_handler:new {}

function fbTradeHallKeeperConvoHandler:runScreenHandlers(pConvTemplate, pPlayer, pNpc, selectedOption, pConvScreen)
	local screen = LuaConversationScreen(pConvScreen)
	local screenID = screen:getScreenID()

	if screenID == "do_waypoint" then
		FbTradeHall:giveWaypoint(pPlayer)
	elseif screenID == "do_tenants" then
		local clonedConversation = LuaConversationScreen(pConvScreen)
		clonedConversation:setDialogTextTT(FbTradeHall:tenantLine())
	end

	return pConvScreen
end
