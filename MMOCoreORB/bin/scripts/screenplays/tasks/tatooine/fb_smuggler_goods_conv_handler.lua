-- fb_smuggler_goods_conv_handler.lua
local ObjectManager = require("managers.object.object_manager")

fbSmugglerGoodsConvoHandler = conv_handler:new {}

function fbSmugglerGoodsConvoHandler:runScreenHandlers(pConvTemplate, pPlayer, pNpc, selectedOption, pConvScreen)
	local screen = LuaConversationScreen(pConvScreen)
	local screenID = screen:getScreenID()

	if screenID == "do_buy" then
		FbSmugglerGoods:showSmugglerList(pPlayer, pNpc)
		return pConvScreen
	end

	return pConvScreen
end
