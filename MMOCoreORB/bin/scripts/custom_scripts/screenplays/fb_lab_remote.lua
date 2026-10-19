-- fb_lab_remote.lua — the Final Boss Lab Remote: the lab, in game (Phase 2.12).
--
-- An admin right-clicks the remote (object/tangible/fb_lab_remote/fb_lab_remote.iff) and gets server UI
-- windows for what the terminal lab does: find any Final Boss NPC and teleport to it, mark it or audit
-- it; read out exactly where you stand (world and room coordinates, ready to paste into a screenplay);
-- audit the NPCs around you; fire the lab's event triggers. Everything calls the same FbLabTests
-- oracles the scenarios use, so what the remote shows is what the tests check.
--
-- Lua-state note: radial and window callbacks run on whichever thread handles the packet, so nothing
-- is kept in Lua tables between windows — per-player state goes through quest status
-- (FbLabRemote.<playerOid>.*), and the spawn registry the finder reads is the quest-status one.

FbLabRemoteMenuComponent = {}

function FbLabRemoteMenuComponent:fillObjectMenuResponse(pSceneObject, pMenuResponse, pPlayer)
	if pSceneObject == nil or pPlayer == nil then return end
	local menuResponse = LuaObjectMenuResponse(pMenuResponse)
	menuResponse:addRadialMenuItem(20, 3, "Lab console")
	menuResponse:addRadialMenuItem(21, 3, "Where am I")
end

function FbLabRemoteMenuComponent:handleObjectMenuSelect(pSceneObject, pPlayer, selectedID)
	if pSceneObject == nil or pPlayer == nil then return 0 end
	if not SceneObject(pSceneObject):isASubChildOf(pPlayer) then return 0 end
	if not FbLabRemote:allowed(pPlayer) then
		CreatureObject(pPlayer):sendSystemMessage("Final Boss Lab Remote: admin accounts only.")
		return 0
	end
	if selectedID == 20 then
		FbLabRemote:showMain(pPlayer)
	elseif selectedID == 21 then
		FbLabRemote:showWhereAmI(pPlayer)
	end
	return 0
end

FbLabRemote = ScreenPlay:new {
	screenplayName = "FbLabRemote",
	template = "object/tangible/fb_lab_remote/fb_lab_remote.iff",
	itemName = "Final Boss Lab Remote",
	maxLines = 60,   -- message boxes stay readable
}

registerScreenPlay("FbLabRemote", true)

function FbLabRemote:start() end

function FbLabRemote:allowed(pPlayer)
	if pPlayer == nil or not SceneObject(pPlayer):isPlayerCreature() then return false end
	local pGhost = CreatureObject(pPlayer):getPlayerObject()
	return pGhost ~= nil and PlayerObject(pGhost):isPrivileged()
end

-- ---------------------------------------------------------------- helpers

local function pkey(pPlayer, what) return "FbLabRemote." .. SceneObject(pPlayer):getObjectID() .. "." .. what end

local function say(pPlayer, text) CreatureObject(pPlayer):sendSystemMessage(text) end

-- Run a lab oracle and hand back what it printed (the oracles report through print).
local function captured(fn, ...)
	local lines = FbLabTests.capture(fn, ...)
	return lines
end

local function messageBox(pPlayer, title, lines)
	local out = {}
	for i = 1, math.min(#lines, FbLabRemote.maxLines) do out[#out + 1] = lines[i] end
	if #lines > FbLabRemote.maxLines then out[#out + 1] = string.format("… %d more lines in the server console", #lines - FbLabRemote.maxLines) end
	if #out == 0 then out[1] = "(nothing to report)" end
	local sui = SuiMessageBox.new("FbLabRemote", "noop")
	sui.setTitle(title)
	sui.setPrompt(table.concat(out, "\n"))
	sui.hideCancelButton()
	sui.sendTo(pPlayer)
end

function FbLabRemote:noop(pPlayer, pSui, eventIndex, args) end

-- Does this character already hold a remote? Returns the item or nil.
function FbLabRemote:findRemote(pPlayer)
	local pInventory = CreatureObject(pPlayer):getSlottedObject("inventory")
	if pInventory == nil then return nil end
	for i = 0, SceneObject(pInventory):getContainerObjectsSize() - 1 do
		local pItem = SceneObject(pInventory):getContainerObject(i)
		if pItem ~= nil then
			local path = SceneObject(pItem):getTemplateObjectPath()
			if path == self.template or path == "object/tangible/fb_field_probe/fb_field_probe.iff" then return pItem end
		end
	end
	return nil
end

-- Hand a remote to a privileged character (idempotent). Returns the item's oid or 0.
function FbLabRemote:give(pPlayer)
	if not self:allowed(pPlayer) then return 0 end
	local pItem = self:findRemote(pPlayer)
	if pItem == nil then
		local pInventory = CreatureObject(pPlayer):getSlottedObject("inventory")
		if pInventory == nil then return 0 end
		pItem = giveItem(pInventory, self.template, -1, true)
		if pItem == nil then return 0 end
		say(pPlayer, "A Final Boss Lab Remote has been placed in your inventory. Right-click it for the lab console.")
	end
	SceneObject(pItem):setCustomObjectName(self.itemName)
	return SceneObject(pItem):getObjectID()
end

-- ---------------------------------------------------------------- main menu

FbLabRemote.mainItems = {
	{ "Where am I (world + room coordinates)", "whereami" },
	{ "Find NPC…", "find" },
	{ "Audit NPCs within 50 m", "auditnear" },
	{ "Lab actions…", "actions" },
	{ "Trade Hall status", "tradehall" },
	{ "Territory", "territory" },
	{ "Galaxy news pool", "news" },
}

function FbLabRemote:showMain(pPlayer)
	local sui = SuiListBox.new("FbLabRemote", "onMain")
	sui.setTitle("Final Boss Lab Remote")
	sui.setPrompt("The lab, in game. Everything here runs the same checks the scenarios run.")
	for _, item in ipairs(self.mainItems) do sui.add(item[1], item[2]) end
	sui.sendTo(pPlayer)
end

function FbLabRemote:onMain(pPlayer, pSui, eventIndex, args)
	if pPlayer == nil or eventIndex == 1 then return end
	local idx = tonumber(args)
	local item = idx ~= nil and self.mainItems[idx + 1] or nil
	if item == nil then return end
	local what = item[2]
	if what == "whereami" then self:showWhereAmI(pPlayer)
	elseif what == "find" then self:askFind(pPlayer)
	elseif what == "auditnear" then self:auditNear(pPlayer, 50)
	elseif what == "actions" then self:showActions(pPlayer)
	elseif what == "tradehall" then messageBox(pPlayer, "Trade Hall", captured("tradeHall"))
	elseif what == "territory" then messageBox(pPlayer, "Territory", captured("territory"))
	elseif what == "news" then messageBox(pPlayer, "Galaxy news pool", captured("galaxyNews"))
	end
end

-- ---------------------------------------------------------------- where am I

-- The read-out a screenplay needs: world position and heading, and when indoors the building, the
-- room name and the room coordinates in the order spawnMobile takes them (x, z = height, y).
function FbLabRemote:whereLines(pPlayer)
	local so = SceneObject(pPlayer)
	local heading = math.deg(so:getDirectionAngle()) % 360
	local lines = {}
	lines[#lines + 1] = string.format("planet %s   world x=%.1f y=%.1f z=%.2f   heading %.0f", so:getZoneName(), so:getWorldPositionX(), so:getWorldPositionY(), so:getWorldPositionZ(), heading)
	local cell = so:getParentID()
	if cell == 0 then
		lines[#lines + 1] = "outdoors (cell 0)"
		lines[#lines + 1] = string.format("spawn: x = %.1f, z = %.2f, y = %.1f, dir = %.0f", so:getWorldPositionX(), so:getWorldPositionZ(), so:getWorldPositionY(), heading)
	else
		local pCell = getSceneObject(cell)
		local pBuilding = pCell ~= nil and SceneObject(pCell):getParent() or nil
		local room, building, tmpl = "?", 0, "?"
		if pBuilding ~= nil and SceneObject(pBuilding):isBuildingObject() then
			building = SceneObject(pBuilding):getObjectID()
			tmpl = SceneObject(pBuilding):getTemplateObjectPath()
			local n = BuildingObject(pBuilding):getTotalCellNumber()
			for i = 1, n do
				local pC = BuildingObject(pBuilding):getCell(i)
				if pC ~= nil and SceneObject(pC):getObjectID() == cell then room = BuildingObject(pBuilding):getCellName(i) end
			end
		end
		lines[#lines + 1] = string.format("inside cell %d (room '%s') of building %d", cell, room, building)
		lines[#lines + 1] = tmpl
		lines[#lines + 1] = string.format("room coordinates: x = %.2f, z = %.2f, y = %.2f, dir = %.0f", so:getPositionX(), so:getPositionZ(), so:getPositionY(), heading)
		lines[#lines + 1] = string.format("tenant line: { template = \"fb_…\", room = \"%s\", x = %.1f, z = %.2f, y = %.1f, dir = %.0f },", room, so:getPositionX(), so:getPositionZ(), so:getPositionY(), heading)
	end
	return lines
end

function FbLabRemote:showWhereAmI(pPlayer)
	local lines = self:whereLines(pPlayer)
	for _, l in ipairs(lines) do say(pPlayer, "[lab] " .. l) end   -- in the chat too, so it can be copied
	messageBox(pPlayer, "Where am I", lines)
end

-- ---------------------------------------------------------------- find an NPC

function FbLabRemote:askFind(pPlayer)
	local sui = SuiInputBox.new("FbLabRemote", "onFindText")
	sui.setTitle("Find NPC")
	sui.setPrompt("Part of a name, a template (fb_parts_dealer), a source file (fb_trade_hall) or an object id:")
	sui.sendTo(pPlayer)
end

function FbLabRemote:onFindText(pPlayer, pSui, eventIndex, args)
	if pPlayer == nil or eventIndex == 1 then return end
	local text = tostring(args or "")
	if text == "" then return end
	local list = FbLabTests.liveSpawns(text)
	if #list == 0 then
		messageBox(pPlayer, "Find NPC", { "No live Final Boss spawn matches '" .. text .. "'." })
		return
	end
	local myZone = SceneObject(pPlayer):getZoneName()
	local sui = SuiListBox.new("FbLabRemote", "onFindPick")
	sui.setTitle("Find NPC: " .. text)
	sui.setPrompt(#list .. " match(es). Pick one.")
	local oids = {}
	for i = 1, math.min(#list, 40) do
		local e = list[i]
		local so = SceneObject(e.pObj)
		local where = so:getParentID() == 0 and "outdoors" or ("cell " .. so:getParentID())
		local dist = so:getZoneName() == myZone and string.format("%.0f m", so:getDistanceTo(pPlayer)) or "other planet"
		sui.add(string.format("%s  [%s, %s, %s]", e.name, so:getZoneName(), where, dist), "")
		oids[#oids + 1] = tostring(e.oid)
	end
	setQuestStatus(pkey(pPlayer, "found"), table.concat(oids, ","))
	sui.sendTo(pPlayer)
end

FbLabRemote.npcActions = {
	{ "Teleport me to it", "goto" },
	{ "Waypoint it", "waypoint" },
	{ "Audit its placement", "audit" },
	{ "Move it to where I stand (facing my way)", "movehere" },
	{ "Make it face me", "faceme" },
}

function FbLabRemote:onFindPick(pPlayer, pSui, eventIndex, args)
	if pPlayer == nil or eventIndex == 1 then return end
	local idx = tonumber(args)
	local oids = {}
	for o in (getQuestStatus(pkey(pPlayer, "found")) or ""):gmatch("[^,]+") do oids[#oids + 1] = o end
	local oid = idx ~= nil and oids[idx + 1] or nil
	if oid == nil then return end
	setQuestStatus(pkey(pPlayer, "npc"), oid)
	local e = FbLabTests.liveSpawns(oid)[1]
	local sui = SuiListBox.new("FbLabRemote", "onNpcAction")
	sui.setTitle(e and e.name or ("NPC " .. oid))
	sui.setPrompt("What now?")
	for _, a in ipairs(self.npcActions) do sui.add(a[1], a[2]) end
	sui.sendTo(pPlayer)
end

function FbLabRemote:onNpcAction(pPlayer, pSui, eventIndex, args)
	if pPlayer == nil or eventIndex == 1 then return end
	local idx = tonumber(args)
	local action = idx ~= nil and self.npcActions[idx + 1] or nil
	local oid = getQuestStatus(pkey(pPlayer, "npc"))
	if action == nil or oid == nil or oid == "" then return end
	local me = CreatureObject(pPlayer):getFirstName()
	local what = action[2]
	if what == "goto" then
		local lines = captured("gotoNpc", me, oid)
		say(pPlayer, "[lab] " .. (lines[1] or "?"))
	elseif what == "waypoint" then
		local lines = captured("waypointTo", me, oid)
		say(pPlayer, "[lab] " .. (lines[1] or "?"))
	elseif what == "audit" then
		messageBox(pPlayer, "Placement audit", captured("placement", oid))
	elseif what == "movehere" then
		local so = SceneObject(pPlayer)
		local e = FbLabTests.liveSpawns(oid)[1]
		if e == nil then return end
		local heading = math.deg(so:getDirectionAngle()) % 360
		-- same cell as me, my local coordinates, my facing
		SceneObject(e.pObj):switchZone(so:getZoneName(), so:getPositionX(), so:getPositionZ(), so:getPositionY(), so:getParentID())
		SceneObject(e.pObj):setDirectionalHeading(heading)
		if SceneObject(e.pObj):isAiAgent() then
			local pCell = so:getParentID() ~= 0 and getSceneObject(so:getParentID()) or nil
			AiAgent(e.pObj):setHomeLocation(so:getPositionX(), so:getPositionZ(), so:getPositionY(), pCell)
		end
		local lines = self:whereLines(pPlayer)
		say(pPlayer, "[lab] moved " .. e.name .. " here: " .. (lines[#lines] or ""))
		for _, l in ipairs(lines) do say(pPlayer, "[lab] " .. l) end
	elseif what == "faceme" then
		local e = FbLabTests.liveSpawns(oid)[1]
		if e == nil then return end
		SceneObject(e.pObj):faceObject(pPlayer, true)
		say(pPlayer, "[lab] " .. e.name .. " now faces you (dir " .. string.format("%.0f", math.deg(SceneObject(e.pObj):getDirectionAngle()) % 360) .. ")")
	end
end

-- ---------------------------------------------------------------- audit around me

function FbLabRemote:auditNear(pPlayer, radius)
	local myZone = SceneObject(pPlayer):getZoneName()
	local lines, n = {}, 0
	for _, e in ipairs(FbLabTests.liveSpawns(nil)) do
		local so = SceneObject(e.pObj)
		if so:getZoneName() == myZone and so:getDistanceTo(pPlayer) <= radius then
			local f = FbLabTests.placementOf(e)
			n = n + 1
			lines[#lines + 1] = string.format("%s %s  los %s/8 %s%s", f.verdict == "ok" and "ok  " or string.upper(f.verdict), e.name, tostring(f.los), tostring(f.pattern),
				#f.reasons > 0 and ("  " .. table.concat(f.reasons, "; ")) or "")
		end
	end
	if n == 0 then lines[1] = "No Final Boss NPC within " .. radius .. " m. (Furniture is client-only: see tools/lotsurvey check for indoor spots.)" end
	messageBox(pPlayer, "Placement audit, " .. radius .. " m around you", lines)
end

-- ---------------------------------------------------------------- lab actions

FbLabRemote.actionItems = {
	{ "Convoy: spawn one now (Mos Eisley)", "convoySpawn" },
	{ "Invasion: begin (Bestine muster)", "invasionBegin" },
	{ "Invasion: assault now", "invasionAssault" },
	{ "Weather here: extreme storm", "stormOn" },
	{ "Weather here: clear", "stormOff" },
	{ "Story ticker: fire the next story", "storyFire" },
	{ "Traveling merchant: move to the next stop", "merchantMove" },
	{ "Traveling merchant: where is Ozlo", "merchant" },
	{ "HoloNet: broadcast a segment here", "holonetBroadcast" },
	{ "Ambient: one cantina beat (location 1)", "ambientTick" },
}

function FbLabRemote:showActions(pPlayer)
	local sui = SuiListBox.new("FbLabRemote", "onAction")
	sui.setTitle("Lab actions")
	sui.setPrompt("Each one does what the scenario oracle of the same name does.")
	for _, a in ipairs(self.actionItems) do sui.add(a[1], a[2]) end
	sui.sendTo(pPlayer)
end

function FbLabRemote:onAction(pPlayer, pSui, eventIndex, args)
	if pPlayer == nil or eventIndex == 1 then return end
	local idx = tonumber(args)
	local a = idx ~= nil and self.actionItems[idx + 1] or nil
	if a == nil then return end
	local zone = SceneObject(pPlayer):getZoneName()
	local lines
	if a[2] == "stormOn" then lines = captured("weatherSet", zone, 4)
	elseif a[2] == "stormOff" then lines = captured("weatherSet", zone, 0)
	else lines = captured(a[2]) end
	messageBox(pPlayer, a[1], lines)
end
