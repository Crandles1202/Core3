-- fb_armory_droid_conv_handler.lua
-- Conversation handler for FB-72 armory droid.
-- When the player picks "I'd like to buy a weapon" the screenID becomes
-- "do_buy"; we delegate to the screenplay's showWeaponList(), which sends
-- a SUI listbox. Selection is handled by the screenplay's
-- purchaseWeaponCallback().
--
-- Install path: MMOCoreORB/bin/scripts/screenplays/tasks/tatooine/fb_armory_droid_conv_handler.lua
-- (Keeping the "tatooine" subdir matches FB-21 for consistency; the droid
--  itself is location-agnostic.)

local ObjectManager = require("managers.object.object_manager")

fbArmoryDroidConvoHandler = conv_handler:new {}

function fbArmoryDroidConvoHandler:runScreenHandlers(pConvTemplate, pPlayer, pNpc, selectedOption, pConvScreen)
	local screen = LuaConversationScreen(pConvScreen)
	local screenID = screen:getScreenID()

	-- "Buy" branch: hand off to the screenplay's SUI builder.
	if screenID == "do_buy" then
		FbArmoryDroid:showWeaponList(pPlayer, pNpc)
		return pConvScreen
	end

	-- All other screens (do_price_list, do_decline) are pure dialog — no side effects.
	return pConvScreen
end
