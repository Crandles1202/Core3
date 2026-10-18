-- fb_story_ticker.lua — Phase 3.5: the story event ticker.
--
-- Once a week (persistent server event "FbStoryTick") a galaxy-wide story fires: the galaxy chatter
-- gets its news lines (FbGalaxyChatter.addNews, one week TTL), everyone online gets a one-line
-- broadcast, and the story's mobs appear somewhere for the week - killable content anyone can grab
-- (they respawn until the next story replaces them). Static story table for now; Phase 3.5's
-- "limited-time quests" can hang off the same table later.
--
-- Public for the lab: FbStoryTicker:fire(idx) runs a story now; :status() one line; :current() index.

FbStoryTicker = ScreenPlay:new {
	screenplayName = "FbStoryTicker",
	periodDays = 7,
	eventName = "FbStoryTick",
	currentKey = "FbStoryTicker.current",
	sinceKey = "FbStoryTicker.since",
	spawnsKey = "FbStoryTicker.spawns",    -- comma-separated "oid=template" pairs of the current story's mobs
	refillMinutes = 60,                    -- dead story mobs are replaced this often, for the whole week
}

FbStoryTicker.stories = {
	{
		key = "tusken_raid", title = "Tusken raiding party sighted east of Mos Eisley",
		broadcast = "Mos Eisley militia: a Tusken raiding party has been sighted east of the city. Travellers are advised to go armed.",
		news = {
			"Tuskens hit a moisture farm east of Mos Eisley. The militia's offering a bounty on the raiders.",
			"Stay off the eastern flats unless you can shoot. Tuskens out there this week.",
		},
		planet = "tatooine", x = 3985, y = -4770, radius = 18,
		mobs = { { template = "tusken_raider", count = 4 }, { template = "tusken_raid_leader", count = 1 } },
	},
	{
		key = "pirates_anchorhead", title = "Pirates camped outside Anchorhead",
		broadcast = "Anchorhead constable: pirates have set up camp north-east of town. Keep clear or clear them out.",
		news = {
			"Pirates off a grounded freighter are squatting outside Anchorhead. The constable wants them gone.",
			"Heard the Anchorhead pirates are paying in stolen parts. Heard they shoot first, too.",
		},
		planet = "tatooine", x = 660, y = -5300, radius = 18,
		mobs = { { template = "pirate_crewman", count = 3 }, { template = "pirate_lieutenant", count = 1 } },
	},
	{
		key = "bestine_crackdown", title = "Imperial crackdown around Bestine",
		broadcast = "Imperial Governor's office: additional patrols are operating around Bestine this week. Carry identification.",
		news = {
			"Stormtroopers are stopping speeders on the Bestine road. Papers, cargo, the lot.",
			"The Bestine garrison doubled its patrols. Somebody important must be visiting.",
		},
		planet = "tatooine", x = -740, y = -3690, radius = 14,
		mobs = { { template = "stormtrooper", count = 3 }, { template = "stormtrooper_squad_leader", count = 1 } },
	},
}

registerScreenPlay("FbStoryTicker", true)

function FbStoryTicker:current()
	return tonumber(getQuestStatus(self.currentKey)) or 0
end

function FbStoryTicker:status()
	local idx = self:current()
	local story = self.stories[idx]
	local alive, total = self:aliveSpawns()
	return string.format("story=%d key=%s since=%s alive=%d/%d event=%s", idx,
		story and story.key or "none", getQuestStatus(self.sinceKey) or "0", alive, total,
		tostring(hasServerEvent(self.eventName)))
end

-- spawn records: { {oid=, template=}, ... }
function FbStoryTicker:spawnRecords()
	local out = {}
	for oid, template in (getQuestStatus(self.spawnsKey) or ""):gmatch("(%d+)=([%w_]+)") do
		out[#out + 1] = { oid = tonumber(oid), template = template }
	end
	return out
end

function FbStoryTicker:saveRecords(records)
	local parts = {}
	for _, r in ipairs(records) do parts[#parts + 1] = tostring(r.oid) .. "=" .. r.template end
	setQuestStatus(self.spawnsKey, table.concat(parts, ","))
end

function FbStoryTicker:spawnOids()
	local out = {}
	for _, r in ipairs(self:spawnRecords()) do out[#out + 1] = r.oid end
	return out
end

local function isAlive(oid)
	local p = getSceneObject(oid)
	return p ~= nil and SceneObject(p):getZoneName() ~= ""
end

function FbStoryTicker:aliveSpawns()
	local records = self:spawnRecords()
	local alive = 0
	for _, r in ipairs(records) do if isAlive(r.oid) then alive = alive + 1 end end
	return alive, #records
end

function FbStoryTicker:spawnOne(story, template)
	local x = story.x + getRandomNumber(-story.radius, story.radius)
	local y = story.y + getRandomNumber(-story.radius, story.radius)
	local z = getTerrainHeightAt(story.planet, x, y)
	local p = spawnMobile(story.planet, template, 0, x, z, y, getRandomNumber(0, 6), 0)
	return p
end

-- refill(): replace story mobs that have been killed (the week-long "they keep coming" effect
-- without AiAgent respawn timers, which would resurrect a story we have already moved on from)
function FbStoryTicker:refill()
	local story = self.stories[self:current()]
	if story == nil then return 0 end
	local records = self:spawnRecords()
	local replaced = 0
	for _, r in ipairs(records) do
		if not isAlive(r.oid) then
			local p = self:spawnOne(story, r.template)
			if p ~= nil then r.oid = SceneObject(p):getObjectID(); replaced = replaced + 1 end
		end
	end
	self:saveRecords(records)
	return replaced
end

function FbStoryTicker:onRefill()
	pcall(function() self:refill() end)
	createEvent(self.refillMinutes * 60 * 1000, "FbStoryTicker", "onRefill", nil, "")
end

-- ---- lifecycle --------------------------------------------------------------------------------

function FbStoryTicker:start()
	if self:current() == 0 then
		self:fire(getRandomNumber(1, #self.stories))
	else
		self:spawnStory(self.stories[self:current()])   -- spawnMobile NPCs do not survive a restart
	end
	if not hasServerEvent(self.eventName) then
		createServerEvent(self.periodDays * 24 * 3600 * 1000, "FbStoryTicker", "onTick", self.eventName)
	end
	createEvent(self.refillMinutes * 60 * 1000, "FbStoryTicker", "onRefill", nil, "")
	printf("FbStoryTicker: %s\n", self:status())
end

function FbStoryTicker:onTick()
	local nextIdx = self:current() % #self.stories + 1
	self:fire(nextIdx)
	if hasServerEvent(self.eventName) then
		rescheduleServerEvent(self.eventName, self.periodDays * 24 * 3600 * 1000)
	else
		createServerEvent(self.periodDays * 24 * 3600 * 1000, "FbStoryTicker", "onTick", self.eventName)
	end
end

function FbStoryTicker:despawnStory()
	for _, oid in ipairs(self:spawnOids()) do
		local p = getSceneObject(oid)
		if p ~= nil then SceneObject(p):destroyObjectFromWorld(true) end
	end
	setQuestStatus(self.spawnsKey, "")
end

function FbStoryTicker:spawnStory(story)
	if story == nil or not isZoneEnabled(story.planet) then return end
	self:despawnStory()
	local records = {}
	for _, group in ipairs(story.mobs) do
		for i = 1, group.count do
			local p = self:spawnOne(story, group.template)
			if p ~= nil then records[#records + 1] = { oid = SceneObject(p):getObjectID(), template = group.template } end
		end
	end
	self:saveRecords(records)
	return #records
end

-- fire(idx): make story idx the current one - news, broadcast, mobs.
function FbStoryTicker:fire(idx)
	idx = tonumber(idx)
	local story = self.stories[idx]
	if story == nil then return "no such story" end

	setQuestStatus(self.currentKey, tostring(idx))
	setQuestStatus(self.sinceKey, tostring(os.time()))

	if FbGalaxyChatter ~= nil then
		for i, line in ipairs(story.news) do
			FbGalaxyChatter.addNews("story_" .. story.key .. "_" .. i, line, self.periodDays * 24 * 3600)
		end
	end

	local spawned = self:spawnStory(story) or 0

	-- broadcastToGalaxy wants a creature as the sender; use the first story mob when there is one
	local oids = self:spawnOids()
	local pSender = (#oids > 0) and getSceneObject(oids[1]) or nil
	if pSender ~= nil then
		broadcastToGalaxy(pSender, story.broadcast)
	end

	printf("FbStoryTicker: fired %s (%d mobs)\n", story.key, spawned)
	return self:status()
end
