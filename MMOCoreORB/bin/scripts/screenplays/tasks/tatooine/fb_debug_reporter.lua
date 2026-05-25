-- fb_debug_reporter.screenplay.lua
-- Tiny utility screenplay: receives a scheduled createEvent callback and
-- reports a player's current position + parentID via system message.
--
-- Triggered by:
--   createEvent(15 * 1000, "FbDebugReporter", "reportCellInfo", pPlayer, "")
--
-- Used by FB-21 medical droid's "[DEBUG] Report my cell info" option so we
-- can harvest the cellID of static world buildings (medcenters, shops, etc.)
-- without having to grep the world snapshot manually.
--
-- Install path: MMOCoreORB/bin/scripts/screenplays/tasks/tatooine/fb_debug_reporter.lua
--
-- Phase 2.6 dev tool — Final Boss server.
-- Once we've harvested all the cellIDs we need, this can stay in place as
-- a permanent debug aid (or get removed; it's harmless either way).

FbDebugReporter = ScreenPlay:new {
	screenplayName = "FbDebugReporter",
}

registerScreenPlay("FbDebugReporter", true)

function FbDebugReporter:start()
	-- No spawns, no init. This screenplay only exists as a registered
	-- callback target so createEvent has something to invoke.
end

-- Called via:  createEvent(ms, "FbDebugReporter", "reportCellInfo", pPlayer, "")
--
-- Reports:
--   * planet (zone name)
--   * world position (x, z, y)
--   * parentID  --> this is the cellID if the player is inside a building,
--                   or 0 if they're outdoors
--
-- After running this, hardcode the printed parentID into the medical droid
-- screenplay's spawn entry, set the spawn's parentCellID arg accordingly,
-- and the droid will appear inside the building.
function FbDebugReporter:reportCellInfo(pPlayer)
	if pPlayer == nil then return end

	local sceneObj = SceneObject(pPlayer)
	local creature = CreatureObject(pPlayer)

	local zoneName = sceneObj:getZoneName()
	-- Cell-LOCAL coords (use these for spawn x/z/y when parentID != 0)
	local px = sceneObj:getPositionX()
	local pz = sceneObj:getPositionZ()
	local py = sceneObj:getPositionY()
	-- WORLD coords (for sanity-checking against the map)
	local wx = sceneObj:getWorldPositionX()
	local wy = sceneObj:getWorldPositionY()
	local parentID = sceneObj:getParentID()

	local locationTag = (parentID == 0) and "[OUTDOORS]" or "[INSIDE CELL]"

	-- Send two compact lines so each fits in the chat window without wrap.
	local line1 = string.format(
		"FB-21 Debug -> planet=%s  parentID=%s  %s",
		tostring(zoneName), tostring(parentID), locationTag
	)
	local line2 = string.format(
		"FB-21 Debug -> cellPos=(%.2f, %.2f, %.2f)  worldPos=(%.1f, %.1f)",
		px, pz, py, wx, wy
	)

	creature:sendSystemMessage(line1)
	creature:sendSystemMessage(line2)

	-- Also print to the server log so we have a recoverable record even if
	-- the player scrolls past the chat message.
	printf("FbDebugReporter: " .. line1 .. "\n")
	printf("FbDebugReporter: " .. line2 .. "\n")

	-- Hint when player forgot to walk inside:
	if parentID == 0 then
		creature:sendSystemMessage("[FB-21 Debug] parentID=0 means you are outdoors. Try again and walk further into the building.")
	end
end
