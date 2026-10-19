-- fb_trade_hall.lua — the Mos Eisley Trade Hall (Phase 2.11).
--
-- Proof of concept for server-placed buildings: a stock Commerce Guild hall spawned on an empty lot
-- east of the starport square, with the Final Boss vendors inside it and a doorman on the square who
-- points people at it. Nothing is persisted: like every stock screenplay prop, the building and its
-- tenants are spawned again at each boot (the cell ids therefore change per boot; never store them).
--
-- Room coordinates come from the hall's floor meshes (appearance/collision/mun_tato_guild_commerce_s01_r*_floor.flr,
-- read with the lab's tools): cell-local x is x, cell-local y is the mesh z, cell-local z is the floor
-- height (2.50 in the foyer and side halls, 1.13 in the main room's lower half and the meeting rooms).
--   foyer     x -14..14  y 10..15.6        (entrance side; the porch runs on to y = 34)
--   halla     x 7.2..14  y 7.5..11.5       hallb mirrored at x -14..-7.2
--   mainroom  x -16..16  y -6.8..10.5      (floor 1.13 near the back, 2.50 near the foyer)
--   meetinga  x 7.8..16  y -2.8..7         meetingb mirrored
--   meetingc  x 6..16    y -15.5..-6.8     meetingd x -5..5     meetinge x -16..-6
-- Stock spawns in the same hall type sit at (-3.69, 1.13, -6) mainroom and (3.29, 1.13, -9.58) /
-- (-0.05, 1.13, -13.9) meetingd — those are proven floor points.
--
-- Public for the lab: FbTradeHall:status(), :isOpen(), :building(), :cellByName(name), :tenantLine()

FbTradeHall = ScreenPlay:new {
	screenplayName = "FbTradeHall",
	planet = "tatooine",
	template = "object/building/tatooine/guild_commerce_tatooine_style_01.iff",
	-- the lot: building origin and heading (0 = porch faces north, 90 = east, 180 = south, 270 = west)
	-- nearest lot that clears every stock footprint (the starport apron alone is 170 m across): 150 m
	-- north of the square, porch facing south toward it (lab survey of snapshot/tatooine.ws, 2026-10-18)
	lot = { x = 3580, y = -4638, heading = 180 },
	-- where the doorman stands: the square where the vendor row used to be
	keeper = { x = 3524, z = 5, y = -4815, dir = 90 },

	tenants = {
		{ template = "fb_armory_droid",        label = "FB-72, weapons",            room = "mainroom", x = -3.7, z = 1.13, y = -6.0,  dir = 11  },
		{ template = "fb_armor_droid",         label = "FB-44, armour",             room = "mainroom", x = 3.7,  z = 1.13, y = -6.0,  dir = 349 },
		{ template = "fb_stim_dealer",         label = "Vex Renn, medical supplies", room = "meetinga", x = 12.0, z = 1.13, y = 2.0,   dir = 270 },
		{ template = "fb_pet_vet",             label = "Doctor Yan'lara, pet medicine", room = "meetingb", x = -12.0, z = 1.13, y = 2.0, dir = 90 },
		{ template = "fb_parts_dealer",        label = "Tamsin Rook, crafting parts", room = "meetingc", x = 9.0,  z = 1.13, y = -11.0, dir = 0 },
		{ template = "fb_schematic_broker",    label = "Dannik Vosa, schematics",   room = "meetingc", x = 13.0, z = 1.13, y = -11.0, dir = 0   },
		{ template = "fb_smuggler_goods",      label = "Greelo, odds and ends",     room = "meetingd", x = 3.3,  z = 1.13, y = -9.6,  dir = 249 },
		{ template = "fb_combat_quartermaster", label = "Quartermaster Sehrev, combat supply", room = "meetingd", x = -3.0, z = 1.13, y = -10.0, dir = 111 },
		{ template = "fb_pet_dealer",          label = "Handler Toobu, pets",       room = "meetinge", x = -11.0, z = 1.13, y = -11.0, dir = 0  },
		{ template = "fb_property_agent",      label = "Property Agent Garlen, housing", room = "meetinge", x = -8.0, z = 1.13, y = -11.5, dir = 90 },
		{ template = "fb_droid_dispenser",     label = "FB-3D, droids",             room = "halla",    x = 10.6, z = 2.5,  y = 9.5,   dir = 180 },
	},
}

registerScreenPlay("FbTradeHall", true)

local function key(what) return "FbTradeHall." .. what end

function FbTradeHall:start()
	if not isZoneEnabled(self.planet) then return end
	local lot = self.lot
	local z = getTerrainHeightAt(self.planet, lot.x, lot.y)
	local rad = math.rad(lot.heading)
	local pBuilding = spawnSceneObject(self.planet, self.template, lot.x, z, lot.y, 0, math.cos(rad / 2), 0, math.sin(rad / 2), 0)
	if pBuilding == nil then
		printf("FbTradeHall: could not spawn %s\n", self.template)
		return
	end
	setQuestStatus(key("building"), tostring(SceneObject(pBuilding):getObjectID()))

	local placed = 0
	for _, t in ipairs(self.tenants) do
		local pCell = self:cellByName(t.room)
		if pCell == nil then
			printf("FbTradeHall: no cell '%s' for %s\n", t.room, t.template)
		else
			local pNpc = spawnMobile(self.planet, t.template, 0, t.x, t.z, t.y, t.dir, SceneObject(pCell):getObjectID())
			if pNpc ~= nil then placed = placed + 1 end
		end
	end

	local k = self.keeper
	spawnMobile(self.planet, "fb_trade_hall_keeper", 0, k.x, k.z, k.y, k.dir, 0)
	printf("FbTradeHall: open at %d,%d — %d of %d tenants placed\n", lot.x, lot.y, placed, #self.tenants)
end

function FbTradeHall:building()
	local oid = tonumber(getQuestStatus(key("building")))
	if oid == nil or oid == 0 then return nil end
	local p = getSceneObject(oid)
	if p == nil or not SceneObject(p):isBuildingObject() or SceneObject(p):getZoneName() == "" then return nil end
	return p
end

function FbTradeHall:isOpen() return self:building() ~= nil end

function FbTradeHall:cellByName(name)
	local pBuilding = self:building()
	if pBuilding == nil then return nil end
	local n = BuildingObject(pBuilding):getTotalCellNumber()
	for i = 1, n do
		if BuildingObject(pBuilding):getCellName(i) == name then return BuildingObject(pBuilding):getCell(i) end
	end
	return nil
end

-- world position of the porch end (local (0, 34)) and of the doors (local (0, 16)), for waypoints
function FbTradeHall:doorPosition()
	local lot = self.lot
	local a = math.rad(lot.heading)
	return lot.x + 18 * math.sin(a), lot.y + 18 * math.cos(a)
end

function FbTradeHall:giveWaypoint(pPlayer)
	if pPlayer == nil then return end
	local pGhost = CreatureObject(pPlayer):getPlayerObject()
	if pGhost == nil then return end
	local x, y = self:doorPosition()
	local z = getTerrainHeightAt(self.planet, x, y)
	PlayerObject(pGhost):addWaypoint(self.planet, "Mos Eisley Trade Hall", "The Final Boss traders, under one roof.", x, z, y, 1, true, true, 0)
	setQuestStatus(key("lastWaypoint"), CreatureObject(pPlayer):getFirstName())   -- the lab reads this
end

function FbTradeHall:tenantLine()
	local names = {}
	for _, t in ipairs(self.tenants) do names[#names + 1] = t.label end
	return "Inside you'll find " .. table.concat(names, "; ") .. ". Ask the keepers, they don't bite. Mostly."
end

function FbTradeHall:status()
	local pBuilding = self:building()
	if pBuilding == nil then return "open=0" end
	return string.format("open=1 building=%d x=%.1f y=%.1f cells=%d tenants=%d", SceneObject(pBuilding):getObjectID(),
		SceneObject(pBuilding):getWorldPositionX(), SceneObject(pBuilding):getWorldPositionY(), BuildingObject(pBuilding):getTotalCellNumber(), #self.tenants)
end
