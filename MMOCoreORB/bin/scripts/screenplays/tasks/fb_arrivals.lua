-- fb_arrivals.lua — Phase 3.16: shuttle arrivals.
--
-- Every few minutes, while a player is near a starport, a landing party of three to six travellers steps off the pad
-- and walks into town along the city's navmesh route (the one the convoys use), vanishing at the far end as if through a
-- door; one or two walk the other way and "board". Species follow the city's cantina voice (its patron templates).
-- Starports feel used. Only cities with a convoy route take part (FbConvoys:routeFor). Walkers that never arrive are
-- swept every few minutes.
--
-- Public for the lab: FbArrivals:land(city) -> a party now (no player needed), :sweep(city) -> clear its walkers,
-- :status(city); FbArrivals.order the cities.

FbArrivals = ScreenPlay:new {
	screenplayName = "FbArrivals",
	cycleSeconds = { 150, 300 },   -- between landings at one starport
	nearRange = 100,               -- a player this close to the pad sees the party; nobody, no party
	party = { 3, 6 },
	boarders = { 1, 2 },
	sweepSeconds = 420,
	fallback = { "commoner", "commoner_old", "businessman", "patron" },
}

FbArrivals.cities, FbArrivals.order = {}, {}
if FbCities ~= nil and FbConvoys ~= nil then
	for _, city in ipairs(FbConvoys.order) do
		local c = FbCities:get(city)
		if c ~= nil then
			local templates = (c.ambient[1] and c.ambient[1].templates) or FbArrivals.fallback
			FbArrivals.cities[city] = { label = c.label, planet = c.planet, templates = templates }
			FbArrivals.order[#FbArrivals.order + 1] = city
		end
	end
end

registerScreenPlay("FbArrivals", true)

local PLAYER_TYPE = 0x409
local function key(city, k) return "FbArrivals." .. city .. "." .. k end
local function get(city, k) return getQuestStatus(key(city, k)) or "" end
local function set(city, k, v) setQuestStatus(key(city, k), tostring(v)) end
local function between(r) return getRandomNumber(r[1], r[2]) end
local function pick(list) return list[getRandomNumber(1, #list)] end

local function alive(oid)
	oid = tonumber(oid)
	if oid == nil or oid == 0 then return nil end
	local p = getSceneObject(oid)
	if p == nil or SceneObject(p):getZoneName() == "" then return nil end
	if SceneObject(p):isCreatureObject() and CreatureObject(p):isDead() then return nil end
	return p
end

local function walkers(city)
	local out = {}
	for oid in get(city, "walkers"):gmatch("%d+") do out[#out + 1] = tonumber(oid) end
	return out
end

local function pointZ(planet, pt) return getTerrainHeightAt(planet, pt[1], pt[3]) end

-- ---- lifecycle --------------------------------------------------------------------------------

function FbArrivals:start()
	local n = 0
	for _, city in ipairs(self.order) do
		local cfg = self.cities[city]
		if isZoneEnabled(cfg.planet) then
			set(city, "walkers", "")   -- spawns do not survive a restart
			createEvent(between(self.cycleSeconds) * 1000, "FbArrivals", "onCycle", nil, city)
			createEvent(self.sweepSeconds * 1000, "FbArrivals", "onSweep", nil, city)
			n = n + 1
		end
	end
	printf("FbArrivals: %d starports\n", n)
end

function FbArrivals:onCycle(pNil, city)
	local cfg = self.cities[city]
	if cfg == nil then return end
	pcall(function()
		local route = FbConvoys:routeFor(city)
		if route ~= nil then
			local pad = route[1]
			local near = getObjectsInRange(cfg.planet, pad[1], pad[3], self.nearRange, PLAYER_TYPE)
			if near ~= nil and #near > 0 then self:land(city) end
		end
	end)
	createEvent(between(self.cycleSeconds) * 1000, "FbArrivals", "onCycle", nil, city)
end

function FbArrivals:onSweep(pNil, city)
	pcall(function() self:sweep(city) end)
	createEvent(self.sweepSeconds * 1000, "FbArrivals", "onSweep", nil, city)
end

function FbArrivals:status(city)
	local cfg = self.cities[city]
	if cfg == nil then return "no such city" end
	local living = 0
	for _, oid in ipairs(walkers(city)) do if alive(oid) then living = living + 1 end end
	local route = FbConvoys:routeFor(city)
	return string.format("city=%s planet=%s route=%d walkers=%d/%d landings=%s", city, cfg.planet, route and #route or 0, living, #walkers(city),
		get(city, "landings") ~= "" and get(city, "landings") or "0")
end

-- ---- the party --------------------------------------------------------------------------------

-- a walker's record: city|leg index|direction (1 = into town, -1 = to the pad)
local function remember(p, city, idx, dir) setQuestStatus("FbArrivals.w." .. tostring(SceneObject(p):getObjectID()), city .. "|" .. idx .. "|" .. dir) end
local function recall(p)
	local v = getQuestStatus("FbArrivals.w." .. tostring(SceneObject(p):getObjectID())) or ""
	local city, idx, dir = v:match("^([%w_]+)|(%-?%d+)|(%-?%d+)$")
	return city, tonumber(idx), tonumber(dir)
end
local function forget(p) removeQuestStatus("FbArrivals.w." .. tostring(SceneObject(p):getObjectID())) end

function FbArrivals:sendLeg(p, city, idx)
	local cfg = self.cities[city]
	local route = FbConvoys:routeFor(city)
	local pt = route and route[idx]
	if pt == nil then return false end
	AiAgent(p):setNextPosition(pt[1], pointZ(cfg.planet, pt), pt[3], 0)
	return true
end

-- land(city): a party steps off the pad and a boarder or two walk to it. Returns the status line.
function FbArrivals:land(city)
	local cfg = self.cities[city]
	if cfg == nil then return "no such city" end
	if not isZoneEnabled(cfg.planet) then return "zone disabled" end
	local route = FbConvoys:routeFor(city)
	if route == nil or #route < 2 then return "no route" end
	local list = get(city, "walkers")
	local pad, far = route[1], route[#route]
	local function spawnAt(pt, idx, dir, spread)
		local x, y = pt[1] + getRandomNumber(-spread, spread), pt[3] + getRandomNumber(-spread, spread)
		local p = spawnMobile(cfg.planet, pick(cfg.templates), 0, x, getTerrainHeightAt(cfg.planet, x, y), y, getRandomNumber(0, 6), 0)
		if p == nil then return end
		CreatureObject(p):setPvpStatusBitmask(0)
		remember(p, city, idx, dir)
		createObserver(DESTINATIONREACHED, "FbArrivals", "onArrived", p)
		list = list == "" and tostring(SceneObject(p):getObjectID()) or (list .. "," .. tostring(SceneObject(p):getObjectID()))
		createEvent(getRandomNumber(500, 4000), "FbArrivals", "onFirstLeg", p, city)
	end
	for i = 1, between(self.party) do spawnAt(pad, 2, 1, 3) end
	for i = 1, between(self.boarders) do spawnAt(far, #route - 1, -1, 2) end
	set(city, "walkers", list)
	set(city, "landings", (tonumber(get(city, "landings")) or 0) + 1)
	return self:status(city)
end

function FbArrivals:onFirstLeg(p, city)
	if p == nil or SceneObject(p):getZoneName() == "" then return end
	local c, idx, dir = recall(p)
	if c ~= nil then pcall(function() self:sendLeg(p, c, idx) end) end
end

function FbArrivals:onArrived(p)
	if p == nil then return 1 end
	local city, idx, dir = recall(p)
	if city == nil then return 1 end
	local route = FbConvoys:routeFor(city)
	local nextIdx = idx + dir
	if route == nil or nextIdx < 1 or nextIdx > #route then
		forget(p)
		SceneObject(p):destroyObjectFromWorld(true)   -- through the door, or aboard
		return 1
	end
	remember(p, city, nextIdx, dir)
	pcall(function() self:sendLeg(p, city, nextIdx) end)
	return 0
end

function FbArrivals:sweep(city)
	local n = 0
	for _, oid in ipairs(walkers(city)) do
		local p = getSceneObject(oid)
		if p ~= nil then forget(p); SceneObject(p):destroyObjectFromWorld(true); n = n + 1 end
		removeQuestStatus("FbArrivals.w." .. tostring(oid))
	end
	set(city, "walkers", "")
	return n
end
