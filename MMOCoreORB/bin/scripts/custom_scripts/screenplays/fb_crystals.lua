-- fb_crystals.lua — Phase 4a.0: lightsaber crystal hunting.
--
-- Four caves grow crystals: the crystal hunters' cave on Dantooine, the squill cave on Tatooine, the droid
-- engineer's cave on Lok and the rancor cave on Dathomir. In each, two formations stand in the deep rooms
-- (stock buildings; the rooms by name through getNamedCell, the floor heights from the floor meshes). A character
-- who works one (the radial: *Take a crystal*) gets a lightsaber colour crystal drawn by rarity — blue common,
-- green and yellow uncommon, orange and brown uncommon, purple rare — or, one time in twelve, a power crystal; red
-- grows only on Dathomir (the Phase 4 decision: colour stays cosmetic, the caves yield colour crystals by rarity
-- plus rare power crystals; 4b.6 is folded in here). A worked formation is bare for an hour.
--
-- The crystals are the stock lightsaber_module_force_crystal, one loot item per colour (custom_scripts/loot/items/
-- fb_crystals.lua: craftingValues pin the colour) so the roll decides the colour; a power crystal is the stock
-- `power_crystals` loot group at the character's level. A crystal in the bag also counts for attunement (4a.1 items).
--
-- Formations are `object/tangible/fb_crystal_node/fb_crystal_node.iff` (a server template with the stock force
-- crystal's look and our menu component), spawned at boot, recorded in quest status `FbCrystals.nodes` (oid list)
-- and `FbCrystals.ready.<oid>` (when it can be worked again). Lab: FbLabTests crystals / crystalHarvest /
-- crystalReset, checkCrystals; scenario `crystals`.

FbCrystals = {
	template = "object/tangible/fb_crystal_node/fb_crystal_node.iff",
	regrow = 60 * 60,        -- s
	powerChance = 8,         -- %
	-- colour codes are the client's @jedi_spam:saber_color_N: 0 Red, 1 Dark Red, 2 Light Green, 3 Dark Green,
	-- 4 Blue, 5 Dark Blue, 6 Yellow, 7 Dark Yellow, 8 Light Purple, 9 Dark Purple, 10 Orange, 11 Brown
	weights = {              -- rarity: colour → weight
		{ colors = { 4, 5 }, weight = 40, name = "blue" },
		{ colors = { 2, 3 }, weight = 22, name = "green" },
		{ colors = { 6, 7 }, weight = 16, name = "yellow" },
		{ colors = { 10, 11 }, weight = 12, name = "orange" },
		{ colors = { 8, 9 }, weight = 7, name = "purple" },
	},
	redWeight = 3,           -- added where red grows
	caves = {
		-- the crystal hunters' cave (cave layout s02): r8 and r7 are flat deep rooms; r9 is the Knight trial's room
		{ key = "dantooine", zone = "dantooine", buildingOid = 8535482, red = false, label = "the crystal hunters' cave",
		  nodes = { { room = "r8", x = 120.0, z = -66.0, y = -100.0 }, { room = "r7", x = 82.0, z = -66.5, y = -134.0 } } },
		-- the squill cave and the droid engineer's cave share one layout: r8 and r10 are flat
		{ key = "tatooine", zone = "tatooine", buildingOid = 7125559, red = false, label = "the squill cave",
		  nodes = { { room = "r8", x = -150.0, z = -50.0, y = -45.0 }, { room = "r10", x = -168.0, z = -49.5, y = -75.0 } } },
		{ key = "lok", zone = "lok", buildingOid = 568956, red = false, label = "the droid engineer's cave",
		  nodes = { { room = "r8", x = -150.0, z = -50.0, y = -45.0 }, { room = "r10", x = -168.0, z = -49.5, y = -75.0 } } },
		-- the rancor cave is the s02 layout mirrored: x negated
		{ key = "dathomir", zone = "dathomir", buildingOid = 4335462, red = true, label = "the rancor cave",
		  nodes = { { room = "r8", x = -120.0, z = -66.0, y = -100.0 }, { room = "r7", x = -82.0, z = -66.5, y = -134.0 } } },
	},
}

-- ---------------------------------------------------------------- boot

function FbCrystals:spawnAll()
	local oids = {}
	for _, cave in ipairs(self.caves) do
		if isZoneEnabled(cave.zone) then
			local pBuilding = getSceneObject(cave.buildingOid)
			if pBuilding == nil then printf("FbCrystals: %s (%d) is missing\n", cave.label, cave.buildingOid)
			else
				for i, n in ipairs(cave.nodes) do
					local pCell = BuildingObject(pBuilding):getNamedCell(n.room)
					if pCell == nil then printf("FbCrystals: no room %s in %s\n", n.room, cave.label)
					else
						local pNode = spawnSceneObject(cave.zone, self.template, n.x, n.z, n.y, SceneObject(pCell):getObjectID(), 1, 0, 0, 0)
						if pNode ~= nil then
							local oid = SceneObject(pNode):getObjectID()
							oids[#oids + 1] = oid
							setQuestStatus("FbCrystals.cave." .. oid, cave.key)
						end
					end
				end
			end
		end
	end
	setQuestStatus("FbCrystals.nodes", table.concat(oids, ","))
	printf("FbCrystals: %d formation(s) grown\n", #oids)
end

function FbCrystals:nodes()
	local list = {}
	for oid in tostring(getQuestStatus("FbCrystals.nodes") or ""):gmatch("%d+") do
		local p = getSceneObject(tonumber(oid))
		if p ~= nil then list[#list + 1] = p end
	end
	return list
end

function FbCrystals:caveOf(pNode)
	local key = getQuestStatus("FbCrystals.cave." .. SceneObject(pNode):getObjectID())
	for _, c in ipairs(self.caves) do if c.key == key then return c end end
	return nil
end

-- ---------------------------------------------------------------- working a formation

function FbCrystals:readyAt(pNode) return tonumber(getQuestStatus("FbCrystals.ready." .. SceneObject(pNode):getObjectID()) or 0) or 0 end
function FbCrystals:isReady(pNode) return self:readyAt(pNode) <= os.time() end
function FbCrystals:reset(pNode) removeQuestStatus("FbCrystals.ready." .. SceneObject(pNode):getObjectID()) end

-- the roll: a colour by rarity (red where it grows), or "power"
function FbCrystals:roll(cave, forced)
	if forced == "power" then return "power" end
	if forced ~= nil and forced ~= "" then return tonumber(forced) end
	if getRandomNumber(100) <= self.powerChance then return "power" end
	local total = 0
	for _, w in ipairs(self.weights) do total = total + w.weight end
	if cave.red then total = total + self.redWeight end
	local r = getRandomNumber(total)
	for _, w in ipairs(self.weights) do
		r = r - w.weight
		if r <= 0 then return w.colors[getRandomNumber(#w.colors)] end
	end
	return getRandomNumber(2) - 1   -- red or dark red
end

function FbCrystals:harvest(pPlayer, pNode, forced)
	if pPlayer == nil or pNode == nil then return false end
	local cave = self:caveOf(pNode)
	if cave == nil then return false end
	if not self:isReady(pNode) then
		CreatureObject(pPlayer):sendSystemMessage("@fb_force:crystal_bare")
		return false
	end
	local pInventory = SceneObject(pPlayer):getSlottedObject("inventory")
	if pInventory == nil or SceneObject(pInventory):isContainerFullRecursive() then
		CreatureObject(pPlayer):sendSystemMessage("@fb_force:crystal_bag_full")
		return false
	end
	local got = self:roll(cave, forced)
	local oid
	if got == "power" then
		oid = createLoot(pInventory, "power_crystals", math.max(1, CreatureObject(pPlayer):getLevel()), false)
		CreatureObject(pPlayer):sendSystemMessage("@fb_force:crystal_power")
	else
		oid = createLoot(pInventory, "fb_crystal_c" .. got, 0, false)
		local msg = LuaStringIdChatParameter("@fb_force:crystal_taken"); msg:setTO("@jedi_spam:saber_color_" .. got)
		CreatureObject(pPlayer):sendSystemMessage(msg:_getObject())
	end
	setQuestStatus("FbCrystals.ready." .. SceneObject(pNode):getObjectID(), tostring(os.time() + self.regrow))
	if FbAttunement ~= nil and FbAttunement.scanItems ~= nil then FbAttunement:scanItems(pPlayer) end
	printf("FbCrystals: %s takes %s from %s (item %s)\n", CreatureObject(pPlayer):getFirstName(), tostring(got), cave.label, tostring(oid))
	return true
end

function FbCrystals:status()
	local parts = {}
	for _, pNode in ipairs(self:nodes()) do
		local cave = self:caveOf(pNode)
		local so = SceneObject(pNode)
		parts[#parts + 1] = string.format("%s:%s:%s:%d", cave and cave.key or "?", tostring(so:getObjectID()), self:isReady(pNode) and "ready" or "bare", math.max(0, self:readyAt(pNode) - os.time()))
	end
	return "nodes=" .. #parts .. " " .. table.concat(parts, " ")
end

-- ---------------------------------------------------------------- the radial

FbCrystalNodeMenuComponent = {}

function FbCrystalNodeMenuComponent:fillObjectMenuResponse(pSceneObject, pMenuResponse, pPlayer)
	if pSceneObject == nil or pPlayer == nil then return end
	local menuResponse = LuaObjectMenuResponse(pMenuResponse)
	menuResponse:addRadialMenuItem(20, 3, "@fb_force:crystal_radial")
end

function FbCrystalNodeMenuComponent:handleObjectMenuSelect(pSceneObject, pPlayer, selectedID)
	if pSceneObject == nil or pPlayer == nil then return 0 end
	if selectedID == 20 and FbCrystals ~= nil then FbCrystals:harvest(pPlayer, pSceneObject) end
	return 0
end

-- ---------------------------------------------------------------- boot

FbCrystalsScreenPlay = ScreenPlay:new { screenplayName = "FbCrystalsScreenPlay" }
registerScreenPlay("FbCrystalsScreenPlay", true)
function FbCrystalsScreenPlay:start() FbCrystals:spawnAll() end
