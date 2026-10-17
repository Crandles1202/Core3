-- fb_field_probe_menu_component.lua  — radial menu component for FB Field Probe.
--
-- Pattern mirrors bin/scripts/screenplays/tools/MagicEightBallMenuComponent.lua.
-- The Core3 engine looks up `objectMenuComponent = "FBFieldProbeMenuComponent"`
-- on the item template, finds this global table, and calls these methods
-- when the player right-clicks the item.
--
-- Install path: bin/scripts/custom_scripts/screenplays/fb_field_probe_menu_component.lua
-- Register in:  bin/scripts/custom_scripts/screenplays/screenplays.lua
--   includeFile("fb_field_probe_menu_component.lua")

local ObjectManager = require("managers.object.object_manager")

FBFieldProbeMenuComponent = { }

-- Called by the engine to build the radial menu that pops up when the player
-- right-clicks the probe in inventory. Radial id 20 = ITEM_USE (the standard
-- "Use" entry the client expects). Callback type 3 means "send the selection
-- back to the server so handleObjectMenuSelect runs."
function FBFieldProbeMenuComponent:fillObjectMenuResponse(pSceneObject, pMenuResponse, pPlayer)
	local menuResponse = LuaObjectMenuResponse(pMenuResponse)
	menuResponse:addRadialMenuItem(20, 3, "@ui_radial:item_use") -- "Use"
end

-- Called by the engine when the player picks an option from the radial menu.
-- pSceneObject = the probe item itself.
-- pPlayer      = the player who right-clicked it.
function FBFieldProbeMenuComponent:handleObjectMenuSelect(pSceneObject, pPlayer, selectedID)
	if (pPlayer == nil or pSceneObject == nil) then
		return 0
	end

	-- Defensive: only allow the probe to be used by its owner. isASubChildOf
	-- checks that the item is somewhere inside the player's inventory tree.
	if (SceneObject(pSceneObject):isASubChildOf(pPlayer) == false) then
		return 0
	end

	if (selectedID == 20) then
		local creature = CreatureObject(pPlayer)
		local sceneObj = SceneObject(pPlayer)

		local zoneName = sceneObj:getZoneName()
		local px       = sceneObj:getPositionX()
		local pz       = sceneObj:getPositionZ()  -- note: in Core3 Lua "Z" is the height axis (mind the swap)
		local py       = sceneObj:getPositionY()
		local wx       = sceneObj:getWorldPositionX()
		local wy       = sceneObj:getWorldPositionY()
		local parentID = sceneObj:getParentID()

		local locationTag = (parentID == 0) and "[OUTDOORS]" or "[INSIDE CELL]"

		-- Two compact lines so the chat doesn't wrap.
		local line1 = string.format(
			"FB Probe -> planet=%s  parentID=%s  %s",
			tostring(zoneName), tostring(parentID), locationTag
		)
		local line2 = string.format(
			"FB Probe -> cellPos=(%.2f, %.2f, %.2f)  worldPos=(%.1f, %.1f)",
			px, pz, py, wx, wy
		)

		creature:sendSystemMessage(line1)
		creature:sendSystemMessage(line2)

		if parentID == 0 then
			creature:sendSystemMessage("[FB Probe] parentID=0 means you are outdoors. Walk further into a building for a cellID.")
		end
	end

	return 0
end
