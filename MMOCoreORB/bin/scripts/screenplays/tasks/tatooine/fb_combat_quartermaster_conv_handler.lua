-- fb_combat_quartermaster_conv_handler.lua
local ObjectManager = require("managers.object.object_manager")

fbCombatQuartermasterConvoHandler = conv_handler:new {}

function fbCombatQuartermasterConvoHandler:runScreenHandlers(pConvTemplate, pPlayer, pNpc, selectedOption, pConvScreen)
	local screen = LuaConversationScreen(pConvScreen)
	local screenID = screen:getScreenID()

	if screenID == "do_buy" then
		FbCombatQuartermaster:showGrenadeList(pPlayer, pNpc)
		return pConvScreen
	end

	return pConvScreen
end
