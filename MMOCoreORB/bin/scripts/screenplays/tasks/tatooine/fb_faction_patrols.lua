-- fb_faction_patrols.lua — Phase 3.2: faction patrols.
--
-- Small Imperial and Rebel squads that walk fixed routes between points of interest, so the GCW is
-- visible on the roads even with one player online. A squad is a leader who walks the route (the
-- same setNextPosition / DESTINATIONREACHED loop the stock city screenplays use) plus members who
-- follow the leader. Stock faction templates keep their own rules: patrols fight players declared
-- for the opposing faction and ignore neutrals. Dead squads are replaced on the next step.
--
-- Public for the lab: FbFactionPatrols:step(route) moves the squad to its next point now;
-- :status(route) one line; :respawn(route).

FbFactionPatrols = ScreenPlay:new {
	screenplayName = "FbFactionPatrols",
	dwellSeconds = { 20, 45 },     -- pause at each point
	retrySeconds = 30,             -- when the leader is fighting or missing
}

-- 3.13: one route per city and faction from the city files (patrols.<faction>.points; leader/members from the city's
-- factions or the defaults). Route keys stay "<city>_<faction>", the region is the city.
FbFactionPatrols.routes = {}
if FbCities ~= nil then
	for _, c in ipairs(FbCities.list) do
		for _, faction in ipairs({ "imperial", "rebel" }) do
			local pr = c.patrols[faction]
			if pr ~= nil and pr.points ~= nil and #pr.points > 0 then
				local f = FbCities:faction(c, faction)
				FbFactionPatrols.routes[#FbFactionPatrols.routes + 1] = {
					key = c.key .. "_" .. faction, planet = c.planet, faction = faction, region = c.key,
					leader = pr.leader or f.leader, members = pr.members or f.troops, points = pr.points,
				}
			end
		end
	end
end

registerScreenPlay("FbFactionPatrols", true)

local function key(route, what) return "FbFactionPatrols." .. route.key .. "." .. what end
local function between(range) return getRandomNumber(range[1], range[2]) end

local function alive(oid)
	if oid == nil or oid == 0 then return nil end
	local p = getSceneObject(oid)
	if p == nil or SceneObject(p):getZoneName() == "" or CreatureObject(p):isDead() then return nil end
	return p
end

function FbFactionPatrols:pointZ(route, pt)
	if pt[2] ~= nil then return pt[2] end
	return getTerrainHeightAt(route.planet, pt[1], pt[3])
end

-- ---- lifecycle --------------------------------------------------------------------------------

function FbFactionPatrols:start()
	for ri, route in ipairs(self.routes) do
		if isZoneEnabled(route.planet) then
			self:respawn(ri)
			createEvent(between(self.dwellSeconds) * 1000, "FbFactionPatrols", "onStep", nil, tostring(ri))
			printf("FbFactionPatrols: %s\n", self:status(ri))
		end
	end
end

function FbFactionPatrols:respawn(ri)
	ri = tonumber(ri)
	local route = self.routes[ri]
	if route == nil then return "no such route" end
	-- clear whatever is left of the previous squad
	for _, oid in ipairs(self:memberOids(route)) do
		local p = getSceneObject(oid)
		if p ~= nil then SceneObject(p):destroyObjectFromWorld(true) end
	end
	local pOld = getSceneObject(tonumber(getQuestStatus(key(route, "leader"))) or 0)
	if pOld ~= nil then SceneObject(pOld):destroyObjectFromWorld(true) end

	local idx = 1
	local pt = route.points[idx]
	local z = self:pointZ(route, pt)
	local pLeader = spawnMobile(route.planet, route.leader, 0, pt[1], z, pt[3], getRandomNumber(0, 6), 0)
	if pLeader == nil then
		printf("FbFactionPatrols: could not spawn %s for %s\n", route.leader, route.key)
		return "spawn failed"
	end
	setQuestStatus(key(route, "leader"), tostring(SceneObject(pLeader):getObjectID()))
	setQuestStatus(key(route, "point"), tostring(idx))
	createObserver(DESTINATIONREACHED, "FbFactionPatrols", "onLeaderArrived", pLeader)

	local oids = {}
	-- Phase 3.4: the faction holding the region fields a bigger squad, the other a smaller one
	local members = (FbTerritory ~= nil) and FbTerritory.squadFor(route) or route.members
	for i, template in ipairs(members) do
		local pMember = spawnMobile(route.planet, template, 0, pt[1] + i * 2, z, pt[3] - i, getRandomNumber(0, 6), 0)
		if pMember ~= nil then
			AiAgent(pMember):setFollowObject(pLeader)
			oids[#oids + 1] = tostring(SceneObject(pMember):getObjectID())
		end
	end
	setQuestStatus(key(route, "members"), table.concat(oids, ","))
	return self:status(ri)
end

function FbFactionPatrols:memberOids(route)
	local out = {}
	for oid in (getQuestStatus(key(route, "members")) or ""):gmatch("%d+") do out[#out + 1] = tonumber(oid) end
	return out
end

function FbFactionPatrols:leader(route)
	return alive(tonumber(getQuestStatus(key(route, "leader"))))
end

function FbFactionPatrols:status(ri)
	ri = tonumber(ri) or 1
	local route = self.routes[ri]
	if route == nil then return "no such route" end
	local pLeader = self:leader(route)
	local members = 0
	for _, oid in ipairs(self:memberOids(route)) do if alive(oid) ~= nil then members = members + 1 end end
	local pos = "x=0 y=0"
	if pLeader ~= nil then
		pos = string.format("x=%.1f y=%.1f", SceneObject(pLeader):getWorldPositionX(), SceneObject(pLeader):getWorldPositionY())
	end
	return string.format("route=%d key=%s faction=%s leader=%s %s members=%d/%d point=%s combat=%s", ri, route.key, route.faction,
		pLeader ~= nil and tostring(SceneObject(pLeader):getObjectID()) or "0", pos, members, #self:memberOids(route),   -- squad size varies with territory (3.4)
		getQuestStatus(key(route, "point")) or "0", pLeader ~= nil and tostring(CreatureObject(pLeader):isInCombat()) or "n/a")
end

-- ---- movement ---------------------------------------------------------------------------------

-- step(ri): send the leader to the next point (members follow). Returns the new point index.
function FbFactionPatrols:step(ri)
	ri = tonumber(ri) or 1
	local route = self.routes[ri]
	if route == nil then return "no such route" end
	local pLeader = self:leader(route)
	if pLeader == nil then
		self:respawn(ri)
		return "respawned"
	end
	if CreatureObject(pLeader):isInCombat() then return "in_combat" end

	local idx = tonumber(getQuestStatus(key(route, "point"))) or 1
	idx = idx % #route.points + 1
	local pt = route.points[idx]
	AiAgent(pLeader):setNextPosition(pt[1], self:pointZ(route, pt), pt[3], 0)
	setQuestStatus(key(route, "point"), tostring(idx))
	return tostring(idx)
end

function FbFactionPatrols:onLeaderArrived(pLeader)
	-- find the route this leader belongs to, then rest a while before the next leg
	for ri, route in ipairs(self.routes) do
		local oid = tonumber(getQuestStatus(key(route, "leader")))
		if pLeader ~= nil and oid == SceneObject(pLeader):getObjectID() then
			createEvent(between(self.dwellSeconds) * 1000, "FbFactionPatrols", "onStep", nil, tostring(ri))
			return 0
		end
	end
	return 0
end

function FbFactionPatrols:onStep(pNil, riStr)
	local ri = tonumber(riStr) or 1
	local ok, result = pcall(function() return self:step(ri) end)
	-- arriving schedules the next leg; anything else (combat, respawn, error) retries later
	if not ok or result == "in_combat" or result == "respawned" then
		createEvent(self.retrySeconds * 1000, "FbFactionPatrols", "onStep", nil, tostring(ri))
	else
		-- safety net in case DESTINATIONREACHED never fires (stuck leader): take another step later
		createEvent(180 * 1000, "FbFactionPatrols", "onStep", nil, tostring(ri))
	end
end
