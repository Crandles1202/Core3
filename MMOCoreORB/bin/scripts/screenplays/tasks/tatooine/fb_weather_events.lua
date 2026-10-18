-- fb_weather_events.lua — Phase 3.9: weather as world events (Tatooine sandstorms).
--
-- Core3 already rolls planet weather (WeatherManager, 0 clear .. 4 extreme storm) and, with
-- hasDamagingSandstorms on, blinds and hurts the unsheltered in an extreme storm. This screenplay makes
-- the storm an *event*: every minute it reads Tatooine's weather and, when a heavy or extreme storm
-- rolls in, warns everyone, posts news and sends three Tusken raiding parties walking in on
-- Mos Eisley's outskirts (east, north-east, south-east). When the sky clears the survivors withdraw.
-- Also the weather half of 3.3 (spawn density tied to weather).
--
-- Public for the lab: FbWeatherEvents:tick() evaluates now, :status() one line, :storm()/:clear()
-- force the two transitions.

FbWeatherEvents = ScreenPlay:new {
	screenplayName = "FbWeatherEvents",
	planet = "tatooine",
	tickSeconds = 60,
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
}

registerScreenPlay("FbWeatherEvents", true)

local K = "FbWeatherEvents."
local function get(k) return getQuestStatus(K .. k) or "" end
local function set(k, v) setQuestStatus(K .. k, tostring(v)) end

local function alive(oid)
	oid = tonumber(oid)
	if oid == nil or oid == 0 then return nil end
	local p = getSceneObject(oid)
	if p == nil or SceneObject(p):getZoneName() == "" then return nil end
	if SceneObject(p):isCreatureObject() and CreatureObject(p):isDead() then return nil end
	return p
end

local function oids()
	local out = {}
	for oid in get("raiders"):gmatch("%d+") do out[#out + 1] = tonumber(oid) end
	return out
end

-- ---- lifecycle --------------------------------------------------------------------------------

function FbWeatherEvents:start()
	if get("active") == "1" then set("active", "0"); set("raiders", "") end   -- spawns do not survive a restart
	createEvent(self.tickSeconds * 1000, "FbWeatherEvents", "onTick", nil, "")
	printf("FbWeatherEvents: watching %s weather (now %d)\n", self.planet, self:weather())
end

function FbWeatherEvents:onTick()
	pcall(function() self:tick() end)
	createEvent(self.tickSeconds * 1000, "FbWeatherEvents", "onTick", nil, "")
end

function FbWeatherEvents:weather()
	return getZoneWeather(self.planet)
end

function FbWeatherEvents:status()
	local living = 0
	for _, oid in ipairs(oids()) do if alive(oid) then living = living + 1 end end
	return string.format("planet=%s weather=%d active=%s raiders=%d/%d storms=%s", self.planet, self:weather(),
		get("active") == "1" and "1" or "0", living, #oids(), get("storms") ~= "" and get("storms") or "0")
end

-- tick(): compare the weather with the event state and transition if needed. Returns what it did.
function FbWeatherEvents:tick()
	local w = self:weather()
	if w >= self.stormAt and get("active") ~= "1" then return self:storm() end
	if w <= self.clearAt and get("active") == "1" then return self:clear() end
	return "steady"
end

-- storm(): the event begins — raiders, warning, news.
function FbWeatherEvents:storm()
	if not isZoneEnabled(self.planet) then return "zone disabled" end
	local all = {}
	local pFirst = nil
	for _, party in ipairs(self.parties) do
		local sx, sy = party.spawn[1], party.spawn[2]
		local pLeader = spawnMobile(self.planet, self.raidLeader, 0, sx, getTerrainHeightAt(self.planet, sx, sy), sy, getRandomNumber(0, 6), 0)
		if pLeader ~= nil then
			pFirst = pFirst or pLeader
			all[#all + 1] = tostring(SceneObject(pLeader):getObjectID())
			AiAgent(pLeader):setNextPosition(party.rally[1], getTerrainHeightAt(self.planet, party.rally[1], party.rally[2]), party.rally[2], 0)
			for i, template in ipairs(self.raiders) do
				local p = spawnMobile(self.planet, template, 0, sx + i * 2, getTerrainHeightAt(self.planet, sx + i * 2, sy - i), sy - i, getRandomNumber(0, 6), 0)
				if p ~= nil then
					AiAgent(p):setFollowObject(pLeader)
					all[#all + 1] = tostring(SceneObject(p):getObjectID())
				end
			end
		end
	end
	set("raiders", table.concat(all, ","))
	set("active", "1")
	set("storms", (tonumber(get("storms")) or 0) + 1)
	if pFirst ~= nil then broadcastToGalaxy(pFirst, self.stormBroadcast) end
	if FbGalaxyChatter ~= nil then FbGalaxyChatter.addNews("sandstorm_" .. tostring(os.time()), self.stormNews, 2 * 24 * 3600) end
	printf("FbWeatherEvents: sandstorm event, %d raiders\n", #all)
	return "storm"
end

-- clear(): the event ends — survivors withdraw.
function FbWeatherEvents:clear()
	local pAny = nil
	for _, oid in ipairs(oids()) do
		local p = alive(oid)
		if p ~= nil then pAny = pAny or p end
	end
	if pAny ~= nil then broadcastToGalaxy(pAny, self.clearBroadcast) end
	for _, oid in ipairs(oids()) do
		local p = getSceneObject(oid)
		if p ~= nil then SceneObject(p):destroyObjectFromWorld(true) end
	end
	set("raiders", "")
	set("active", "0")
	printf("FbWeatherEvents: sandstorm over\n")
	return "clear"
end
