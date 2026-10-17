-- fb_parts_dealer_conv_handler.lua — Phase 2.3 parts dealer conversation handler.
local ObjectManager = require("managers.object.object_manager")

fbPartsDealerConvoHandler = conv_handler:new {}

function fbPartsDealerConvoHandler:runScreenHandlers(pConvTemplate, pPlayer, pNpc, selectedOption, pConvScreen)
	local screen = LuaConversationScreen(pConvScreen)
	local screenID = screen:getScreenID()

	if screenID == "do_parts" then
		FbPartsDealer:showParts(pPlayer, pNpc)
	end

	return pConvScreen
end
