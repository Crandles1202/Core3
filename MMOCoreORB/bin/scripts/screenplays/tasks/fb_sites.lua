-- fb_sites.lua — Final Boss sites: server-placed stock buildings with their tenants, from data (Phase 2.12b).
--
-- A site is a data file in screenplays/tasks/sites/<name>.lua calling FbSites:add { … } (the site builder on
-- the Lab Remote writes them; the Mos Eisley Trade Hall is the first). At every boot FbSites spawns each
-- site's building on its lot, the tenants into its rooms by cell *name*, and its outdoor NPCs — nothing is
-- persisted (stock prop pattern), so cell ids change per boot and are never stored.
--
--   FbSites:add {
--     name = "mos_eisley_trade_hall", label = "Mos Eisley Trade Hall", planet = "tatooine",
--     template = "object/building/tatooine/guild_commerce_tatooine_style_01.iff",
--     x = 3580, y = -4638, heading = 180,          -- building origin; heading 0 = entrance side north
--     door = { dx = 0, dy = 18 },                  -- entrance, building-local (for waypoints)
--     tenants = { { template = "fb_parts_dealer", label = "Tamsin Rook, crafting parts", room = "meetingc", x = 9, z = 1.13, y = -11, dir = 0 }, … },
--     outside = { { template = "fb_trade_hall_keeper", x = 3524, z = 5, y = -4815, dir = 90 } },
--   }
--
-- Public: FbSites:get(name), :building(name), :isOpen(name), :cellByName(name, room), :doorPosition(name),
--         :giveWaypoint(name, pPlayer), :tenantLine(name), :status(name), FbSites.names (in file order)
-- Preview (2.12d, the site planner's game loop): FbSites:preview(file) tears down the live site of the same
-- name, spawns the site described in sites/.preview/<file>.lua instead; :previewEnd() removes it and puts the
-- boot-time site back. Nothing here persists; a restart always rebuilds from the saved files.

FbSites = ScreenPlay:new {
	screenplayName = "FbSites",
	dir = "scripts/screenplays/tasks/sites",
	sites = {},
	names = {},
}

function FbSites:add(site)
	if site == nil or site.name == nil then printf("FbSites: a site without a name was ignored\n"); return end
	if self.sites[site.name] == nil then self.names[#self.names + 1] = site.name end
	site.tenants = site.tenants or {}
	site.outside = site.outside or {}
	self.sites[site.name] = site
end

-- the site files
do
	local p = io.popen and io.popen("ls " .. FbSites.dir .. "/*.lua 2>/dev/null")
	if p ~= nil then
		for line in p:lines() do
			local f = line:match("([^/]+%.lua)$")
			if f ~= nil then includeFile("tasks/sites/" .. f) end
		end
		p:close()
	end
end

registerScreenPlay("FbSites", true)

local function key(name, what) return "FbSites." .. name .. "." .. what end

function FbSites:start()
	for _, name in ipairs(self.names) do
		local ok, err = pcall(function() self:build(self.sites[name]) end)
		if not ok then printf("FbSites: %s failed: %s\n", name, tostring(err)) end
	end
end

-- Spawn one site: building, tenants, outdoor NPCs. Returns the building pointer or nil.
function FbSites:build(site)
	if not isZoneEnabled(site.planet) then return nil end
	local z = site.z or getTerrainHeightAt(site.planet, site.x, site.y)
	local rad = math.rad(site.heading or 0)
	local pBuilding = spawnSceneObject(site.planet, site.template, site.x, z, site.y, 0, math.cos(rad / 2), 0, math.sin(rad / 2), 0)
	if pBuilding == nil then
		printf("FbSites: %s — could not spawn %s\n", site.name, site.template)
		return nil
	end
	setQuestStatus(key(site.name, "building"), tostring(SceneObject(pBuilding):getObjectID()))

	local placed, npcs = 0, {}
	for _, t in ipairs(site.tenants) do
		local pCell = self:cellByName(site.name, t.room)
		if pCell == nil then
			printf("FbSites: %s — no room '%s' for %s\n", site.name, tostring(t.room), t.template)
		else
			local pNpc = spawnMobile(site.planet, t.template, 0, t.x, t.z, t.y, t.dir or 0, SceneObject(pCell):getObjectID())
			if pNpc ~= nil then placed = placed + 1; npcs[#npcs + 1] = tostring(SceneObject(pNpc):getObjectID()) end
		end
	end
	for _, o in ipairs(site.outside) do
		local pNpc = spawnMobile(site.planet, o.template, 0, o.x, o.z or getTerrainHeightAt(site.planet, o.x, o.y), o.y, o.dir or 0, 0)
		if pNpc ~= nil then npcs[#npcs + 1] = tostring(SceneObject(pNpc):getObjectID()) end
	end
	setQuestStatus(key(site.name, "npcs"), table.concat(npcs, ","))   -- so teardown (preview) can remove them
	printf("FbSites: %s open at %.1f,%.1f — %d of %d tenants, %d outside\n", site.name, site.x, site.y, placed, #site.tenants, #site.outside)
	return pBuilding
end

-- Remove a site's NPCs and building (a preview, or the live site a preview replaces). Returns how many objects went.
function FbSites:teardown(name)
	local gone = 0
	local function destroy(oid)
		oid = tonumber(oid)
		if oid == nil or oid == 0 then return end
		local p = getSceneObject(oid)
		if p ~= nil then
			SceneObject(p):destroyObjectFromWorld(true)
			SceneObject(p):destroyObjectFromDatabase()
			gone = gone + 1
		end
		if FbLabTests ~= nil and FbLabTests.registryRemove ~= nil then FbLabTests.registryRemove(oid) end
	end
	for oid in tostring(getQuestStatus(key(name, "npcs")) or ""):gmatch("[^,]+") do destroy(oid) end
	destroy(getQuestStatus(key(name, "building")))
	removeQuestStatus(key(name, "npcs"))
	removeQuestStatus(key(name, "building"))
	return gone
end

-- Read one site file without registering it: the FbSites:add call inside is captured.
function FbSites:loadFile(path)
	local captured
	local env = setmetatable({ FbSites = { add = function(_, site) captured = site end } }, { __index = _G })
	local chunk, err = loadfile(path, "t", env)
	if chunk == nil then return nil, err end
	local ok, rerr = pcall(chunk)
	if not ok then return nil, rerr end
	if captured == nil or captured.name == nil then return nil, "no FbSites:add { name = … } in " .. path end
	captured.tenants = captured.tenants or {}
	captured.outside = captured.outside or {}
	return captured
end

-- Spawn the site in sites/.preview/<file>.lua now, in place of the live site of the same name.
-- Returns the site table and the building pointer, or nil and an error.
function FbSites:preview(file)
	local site, err = self:loadFile(self.dir .. "/.preview/" .. tostring(file):gsub("[^%w_%-]", "") .. ".lua")
	if site == nil then return nil, err end
	local previous = getQuestStatus("FbSites.preview")
	if previous ~= nil and previous ~= "" and previous ~= site.name then self:previewEnd() end   -- one preview at a time
	self:teardown(site.name)                                                                  -- the live one, or the last preview
	setQuestStatus("FbSites.preview", site.name)
	local pBuilding = self:build(site)
	if pBuilding == nil then return nil, "could not spawn " .. tostring(site.template) end
	return site, pBuilding
end

-- Take the preview down; the site saved at boot (if one has that name) comes back on its own lot.
function FbSites:previewEnd()
	local name = getQuestStatus("FbSites.preview")
	if name == nil or name == "" then return nil end
	local gone = self:teardown(name)
	removeQuestStatus("FbSites.preview")
	local saved = self.sites[name]
	if saved ~= nil then self:build(saved) end
	return name, gone, saved ~= nil
end

function FbSites:get(name) return self.sites[name] end

function FbSites:building(name)
	local oid = tonumber(getQuestStatus(key(name, "building")))
	if oid == nil or oid == 0 then return nil end
	local p = getSceneObject(oid)
	if p == nil or not SceneObject(p):isBuildingObject() or SceneObject(p):getZoneName() == "" then return nil end
	return p
end

function FbSites:isOpen(name) return self:building(name) ~= nil end

function FbSites:cellByName(name, room)
	local pBuilding = self:building(name)
	if pBuilding == nil then return nil end
	local n = BuildingObject(pBuilding):getTotalCellNumber()
	for i = 1, n do
		if BuildingObject(pBuilding):getCellName(i) == room then return BuildingObject(pBuilding):getCell(i) end
	end
	return nil
end

-- world position of the entrance (site.door, building-local, rotated by the heading)
function FbSites:doorPosition(name)
	local site = self.sites[name]
	local door = site.door or { dx = 0, dy = 0 }
	local a = math.rad(site.heading or 0)
	return site.x + door.dx * math.cos(a) + door.dy * math.sin(a), site.y - door.dx * math.sin(a) + door.dy * math.cos(a)
end

function FbSites:giveWaypoint(name, pPlayer)
	local site = self.sites[name]
	if site == nil or pPlayer == nil then return end
	local pGhost = CreatureObject(pPlayer):getPlayerObject()
	if pGhost == nil then return end
	local x, y = self:doorPosition(name)
	local z = getTerrainHeightAt(site.planet, x, y)
	PlayerObject(pGhost):addWaypoint(site.planet, site.label or name, "", x, z, y, 1, true, true, 0)
	setQuestStatus(key(name, "lastWaypoint"), CreatureObject(pPlayer):getFirstName())   -- the lab reads this
end

function FbSites:tenantLine(name)
	local site = self.sites[name]
	local names = {}
	for _, t in ipairs(site.tenants) do names[#names + 1] = t.label or t.template end
	return table.concat(names, "; ")
end

function FbSites:status(name)
	local site = self.sites[name]
	if site == nil then return "unknown site " .. tostring(name) end
	local pBuilding = self:building(name)
	if pBuilding == nil then return "open=0" end
	return string.format("open=1 building=%d x=%.1f y=%.1f cells=%d tenants=%d", SceneObject(pBuilding):getObjectID(),
		SceneObject(pBuilding):getWorldPositionX(), SceneObject(pBuilding):getWorldPositionY(), BuildingObject(pBuilding):getTotalCellNumber(), #site.tenants)
end
