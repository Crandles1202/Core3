-- fb_holonet_relay_conv_handler.lua — Phase 3.10 HoloNet relay conversation handler.
local ObjectManager = require("managers.object.object_manager")

fbHolonetRelayConvoHandler = conv_handler:new {}

function fbHolonetRelayConvoHandler:runScreenHandlers(pConvTemplate, pPlayer, pNpc, selectedOption, pConvScreen)
	local screen = LuaConversationScreen(pConvScreen)
	local screenID = screen:getScreenID()

	if screenID == "do_replay" and pNpc ~= nil then
		-- find which relay this is and read a segment
		for li, loc in ipairs(FbHoloNet.locations) do
			local oid = tonumber(getQuestStatus("FbHoloNet." .. loc.key .. ".relay"))
			if oid == SceneObject(pNpc):getObjectID() then
				FbHoloNet:broadcast(li)
				break
			end
		end
	end

	return pConvScreen
end
