-- fb_weather_events.lua — Phase 3.9: weather as world events, per planet since 3.13.
--
-- Core3 already rolls planet weather (WeatherManager, 0 clear .. 4 extreme storm) and, with hasDamagingSandstorms
-- on, blinds and hurts the unsheltered in an extreme storm. This screenplay makes a storm an *event*: every minute
-- it reads each listed planet's weather and, when a heavy or extreme storm rolls in, warns everyone, posts news and
-- sends raiding parties walking in on a city's outskirts (Tatooine: three Tusken parties on Mos Eisley's east,
-- north-east and south-east). When the sky clears the survivors withdraw. A planet with no parties gets the
-- broadcasts only (cosmetic rain). Also the weather half of 3.3 (spawn density tied to weather).
--
-- Public for the lab: FbWeatherEvents:tick(planet) evaluates now, :status(planet) one line, :storm(planet)/:clear(planet)
-- force the two transitions; a nil planet is the first one (Tatooine). Quest status: FbWeatherEvents.<planet>.<k>.

FbWeatherEvents = ScreenPlay:new {
	screenplayName = "FbWeatherEvents",
	tickSeconds = 60,
}

FbWeatherEvents.planets = {
	tatooine = {
		stormAt = 3,     -- HEAVYSTORM and up starts the event
		clearAt = 1,     -- LIGHTSTORM and below ends it
		raidLeader = "tusken_raid_leader",
		raiders = { "tusken_raider", "tusken_raider", "tusken_raider" },
		-- spawn point -> rally point (walk toward the city, stop short of the walls)
		parties = {
			{ key = "east",      spawn = { 3950, -4780 }, rally = { 3800, -4790 } },
			{ key = "northeast", spawn = { 3900, -4500 }, rally = { 3780, -4650 } },
			{ key = "southeast", spawn = { 3850, -5050 }, rally = { 3750, -4950 } },
		},
		stormBroadcast = "Tatooine: a sandstorm is sweeping in from the Dune Sea. Tusken raiding parties are moving on Mos Eisley's outskirts. Seek shelter.",
		clearBroadcast = "Tatooine: the sandstorm has passed. The Tuskens are pulling back into the wastes.",
		stormNews = "A sandstorm hit Mos Eisley and the Tuskens came in with it. Farms on the east side took losses.",
	},
}
FbWeatherEvents.order = { "tatooine" }
for planet, _ in pairs(FbWeatherEvents.planets) do
	local listed = false
	for _, p in ipairs(FbWeatherEvents.order) do if p == planet then listed = true end end
	if not listed then FbWeatherEvents.order[#FbWeatherEvents.order + 1] = planet end
end

registerScreenPlay("FbWeatherEvents", true)

local function planetOf(planet)
	planet = planet or FbWeatherEvents.order[1]
	return FbWeatherEvents.planets[planet] ~= nil and planet or nil
end
local function key(planet, k) return "FbWeatherEvents." .. planet .. "." .. k end
local function get(planet, k) return getQuestStatus(key(planet, k)) or "" end
local function set(planet, k, v) setQuestStatus(key(planet, k), tostring(v)) end

local function alive(oid)
	oid = tonumber(oid)
	if oid == nil or oid == 0 then return nil end
	local p = getSceneObject(oid)
	if p == nil or SceneObject(p):getZoneName() == "" then return nil end
	if SceneObject(p):isCreatureObject() and CreatureObject(p):isDead() then return nil end
	return p
end

local function oids(planet)
	local out = {}
	for oid in get(planet, "raiders"):gmatch("%d+") do out[#out + 1] = tonumber(oid) end
	return out
end

-- ---- lifecycle --------------------------------------------------------------------------------

function FbWeatherEvents:start()
	for _, planet in ipairs(self.order) do
		if get(planet, "active") == "1" then set(planet, "active", "0"); set(planet, "raiders", "") end   -- spawns do not survive a restart
		if isZoneEnabled(planet) then
			createEvent(self.tickSeconds * 1000, "FbWeatherEvents", "onTick", nil, planet)
			printf("FbWeatherEvents: watching %s weather (now %d)\n", planet, self:weather(planet))
		end
	end
end

function FbWeatherEvents:onTick(pNil, planet)
	planet = planetOf(planet)
	if planet == nil then return end
	pcall(function() self:tick(planet) end)
	createEvent(self.tickSeconds * 1000, "FbWeatherEvents", "onTick", nil, planet)
end

function FbWeatherEvents:weather(planet)
	return getZoneWeather(planetOf(planet) or "tatooine")
end

function FbWeatherEvents:status(planet)
	planet = planetOf(planet)
	if planet == nil then return "no such planet" end
	local living = 0
	for _, oid in ipairs(oids(planet)) do if alive(oid) then living = living + 1 end end
	return string.format("planet=%s weather=%d active=%s raiders=%d/%d storms=%s", planet, self:weather(planet),
		get(planet, "active") == "1" and "1" or "0", living, #oids(planet), get(planet, "storms") ~= "" and get(planet, "storms") or "0")
end

-- tick(planet): compare the weather with the event state and transition if needed. Returns what it did.
function FbWeatherEvents:tick(planet)
	planet = planetOf(planet)
	if planet == nil then return "no such planet" end
	local cfg = self.planets[planet]
	local w = self:weather(planet)
	if w >= (cfg.stormAt or 3) and get(planet, "active") ~= "1" then return self:storm(planet) end
	if w <= (cfg.clearAt or 1) and get(planet, "active") == "1" then return self:clear(planet) end
	return "steady"
end

-- storm(planet): the event begins — raiders, warning, news.
function FbWeatherEvents:storm(planet)
	planet = planetOf(planet)
	if planet == nil then return "no such planet" end
	local cfg = self.planets[planet]
	if not isZoneEnabled(planet) then return "zone disabled" end
	local all = {}
	local pFirst = nil
	for _, party in ipairs(cfg.parties or {}) do
		local sx, sy = party.spawn[1], party.spawn[2]
		local pLeader = spawnMobile(planet, party.leader or cfg.raidLeader, 0, sx, getTerrainHeightAt(planet, sx, sy), sy, getRandomNumber(0, 6), 0)
		if pLeader ~= nil then
			pFirst = pFirst or pLeader
			all[#all + 1] = tostring(SceneObject(pLeader):getObjectID())
			AiAgent(pLeader):setNextPosition(party.rally[1], getTerrainHeightAt(planet, party.rally[1], party.rally[2]), party.rally[2], 0)
			for i, template in ipairs(party.raiders or cfg.raiders or {}) do
				local p = spawnMobile(planet, template, 0, sx + i * 2, getTerrainHeightAt(planet, sx + i * 2, sy - i), sy - i, getRandomNumber(0, 6), 0)
				if p ~= nil then
					AiAgent(p):setFollowObject(pLeader)
					all[#all + 1] = tostring(SceneObject(p):getObjectID())
				end
			end
		end
	end
	set(planet, "raiders", table.concat(all, ","))
	set(planet, "active", "1")
	set(planet, "storms", (tonumber(get(planet, "storms")) or 0) + 1)
	if cfg.stormBroadcast ~= nil then
		local pSpeaker = pFirst
		if pSpeaker == nil and FbHoloNet ~= nil then   -- a cosmetic planet has no raiders: borrow a relay as the sender
			for li, loc in ipairs(FbHoloNet.locations) do
				local p = FbHoloNet:relay(li)
				if p ~= nil then pSpeaker = p; break end
			end
		end
		if pSpeaker ~= nil then broadcastToGalaxy(pSpeaker, cfg.stormBroadcast) end
	end
	if FbGalaxyChatter ~= nil and cfg.stormNews ~= nil then FbGalaxyChatter.addNews("storm_" .. planet .. "_" .. tostring(os.time()), cfg.stormNews, 2 * 24 * 3600) end
	printf("FbWeatherEvents: %s storm event, %d raiders\n", planet, #all)
	return "storm"
end

-- clear(planet): the event ends — survivors withdraw.
function FbWeatherEvents:clear(planet)
	planet = planetOf(planet)
	if planet == nil then return "no such planet" end
	local cfg = self.planets[planet]
	local pAny = nil
	for _, oid in ipairs(oids(planet)) do
		local p = alive(oid)
		if p ~= nil then pAny = pAny or p end
	end
	if pAny == nil and FbHoloNet ~= nil then
		for li, loc in ipairs(FbHoloNet.locations) do
			local p = FbHoloNet:relay(li)
			if p ~= nil then pAny = p; break end
		end
	end
	if pAny ~= nil and cfg.clearBroadcast ~= nil then broadcastToGalaxy(pAny, cfg.clearBroadcast) end
	for _, oid in ipairs(oids(planet)) do
		local p = getSceneObject(oid)
		if p ~= nil then SceneObject(p):destroyObjectFromWorld(true) end
	end
	set(planet, "raiders", "")
	set(planet, "active", "0")
	printf("FbWeatherEvents: %s storm over\n", planet)
	return "clear"
end
