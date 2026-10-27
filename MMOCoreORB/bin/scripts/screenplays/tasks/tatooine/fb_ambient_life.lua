-- fb_ambient_life.lua — Phase 3.7/3.8: ambient life in public spaces (Mos Eisley, Bestine and Coronet cantinas).
--
-- Stock Core3 already seats ~40 silent patrons in the Mos Eisley cantina (cities/tatooine_mos_eisley.lua).
-- This adds the *living* layer on top: a handful of extra patrons who mutter and gesture while someone
-- is in the room, notice a newcomer, and come and go over time (a seat is re-filled with a different
-- face every few minutes). Nothing happens while the room has no players in it.
--
-- Data-driven: add a location (cells, seats, lines) and it works. Public for the lab:
--   FbAmbientLife:tick(loc)          one ambience beat now -> "chat:<text>" | "emote:<anim>" | "newcomer:<text>" | "quiet"
--   FbAmbientLife:churn(loc, seat)   replace the patron in a seat now -> new oid
--   FbAmbientLife:status(loc)        one line per seat

FbAmbientLife = ScreenPlay:new {
	screenplayName = "FbAmbientLife",
	chatterSeconds = { 25, 45 },      -- beat interval while players are near
	churnSeconds = { 300, 600 },      -- how often one seat changes hands
	noticeRange = 20,                 -- metres: a player this close keeps the room "alive"
	galaxyShare = 35,                 -- % of spoken beats that are galaxy news (FbGalaxyChatter) instead of local lines
}

-- 3.13: the locations come from the city files (ambient = { { key, label, anchor, seats, templates, moods, chatter,
-- newcomer, emotes } }); a location's key is "<city>_<key>" ("mos_eisley_cantina"), its planet the city's
FbAmbientLife.locations = {}
if FbCities ~= nil then
	for _, c in ipairs(FbCities.list) do
		for _, a in ipairs(c.ambient) do
			local loc = { key = c.key .. "_" .. a.key, label = a.label or (c.label .. " " .. a.key), planet = c.planet, city = c.key }
			for k, v in pairs(a) do if loc[k] == nil then loc[k] = v end end
			FbAmbientLife.locations[#FbAmbientLife.locations + 1] = loc
		end
	end
end

registerScreenPlay("FbAmbientLife", true)

local function pick(list) return list[getRandomNumber(1, #list)] end
local function between(range) return getRandomNumber(range[1], range[2]) end

local function seatKey(loc, seat) return "FbAmbientLife." .. loc.key .. ".seat" .. seat end

-- ---- lifecycle --------------------------------------------------------------------------------

function FbAmbientLife:start()
	for li, loc in ipairs(self.locations) do
		if isZoneEnabled(loc.planet) then
			for si = 1, #loc.seats do
				self:spawnSeat(li, si)
			end
			createEvent(between(self.chatterSeconds) * 1000, "FbAmbientLife", "onBeat", nil, tostring(li))
			createEvent(between(self.churnSeconds) * 1000, "FbAmbientLife", "onChurn", nil, tostring(li))
			printf("FbAmbientLife: %s - %d ambient patrons\n", loc.label, #loc.seats)
		end
	end
end

function FbAmbientLife:spawnSeat(li, si)
	local loc = self.locations[li]
	local seat = loc.seats[si]
	local template = pick(loc.templates)
	local z = seat.z
	if z == nil then z = getTerrainHeightAt(loc.planet, seat.x, seat.y) end   -- outdoor seat
	local pMobile = spawnMobile(loc.planet, template, 0, seat.x, z, seat.y, seat.dir, seat.cell or 0)
	if pMobile == nil then
		printf("FbAmbientLife: could not spawn %s at %s seat %d\n", template, loc.label, si)
		return nil
	end
	-- patrons stay on their seat: AI_STATIC + no AI (same pattern as the cantina entertainers);
	-- without it the stock commoner AI wandered the outdoor travellers 20–30 m from the starport
	AiAgent(pMobile):addObjectFlag(AI_STATIC)
	if CreatureObject(pMobile):getPvpStatusBitmask() == 0 then
		CreatureObject(pMobile):clearOptionBit(AIENABLED)
	end
	CreatureObject(pMobile):setMoodString(pick(loc.moods))
	setQuestStatus(seatKey(loc, si), tostring(SceneObject(pMobile):getObjectID()))
	return pMobile
end

function FbAmbientLife:seatMobile(li, si)
	local oid = tonumber(getQuestStatus(seatKey(self.locations[li], si)))
	if oid == nil or oid == 0 then return nil end
	local pMobile = getSceneObject(oid)
	if pMobile == nil or SceneObject(pMobile):getZoneName() == "" then return nil end
	return pMobile
end

function FbAmbientLife:status(li)
	li = tonumber(li) or 1
	local loc = self.locations[li]
	if loc == nil then return "no such location" end
	local lines = {}
	for si = 1, #loc.seats do
		local pMobile = self:seatMobile(li, si)
		if pMobile ~= nil then
			lines[#lines + 1] = string.format("seat=%d oid=%d cell=%d mood=%s", si, SceneObject(pMobile):getObjectID(),
				SceneObject(pMobile):getParentID(), CreatureObject(pMobile):getMoodString())
		else
			lines[#lines + 1] = string.format("seat=%d oid=0", si)
		end
	end
	return table.concat(lines, "\n")
end

-- ---- behaviour --------------------------------------------------------------------------------

-- Players within noticeRange of any seat; also tracks who is new since the last beat.
function FbAmbientLife:playersNear(li)
	local loc = self.locations[li]
	local seen, newcomers = {}, {}
	local lastKey = "FbAmbientLife." .. loc.key .. ".seen"
	local last = getQuestStatus(lastKey) or ""
	for si = 1, #loc.seats do
		local pMobile = self:seatMobile(li, si)
		if pMobile ~= nil then
			local players = SceneObject(pMobile):getPlayersInRange(self.noticeRange)
			if players ~= nil then
				for _, pPlayer in pairs(players) do
					local oid = tostring(SceneObject(pPlayer):getObjectID())
					if not seen[oid] then
						seen[oid] = true
						if not last:find(oid, 1, true) then newcomers[#newcomers + 1] = oid end
					end
				end
			end
		end
	end
	local ids = {}
	for oid in pairs(seen) do ids[#ids + 1] = oid end
	setQuestStatus(lastKey, table.concat(ids, ","))
	return #ids, newcomers
end

-- tick(li): one ambience beat. Quiet when nobody is near.
function FbAmbientLife:tick(li)
	li = tonumber(li) or 1
	local loc = self.locations[li]
	if loc == nil then return "no such location" end

	local nearby, newcomers = self:playersNear(li)
	if nearby == 0 then return "quiet" end

	local candidates = {}
	for si = 1, #loc.seats do
		local pMobile = self:seatMobile(li, si)
		if pMobile ~= nil then candidates[#candidates + 1] = pMobile end
	end
	if #candidates == 0 then return "quiet" end
	local pSpeaker = pick(candidates)

	if #newcomers > 0 and getRandomNumber(1, 100) <= 60 then
		local line = pick(loc.newcomer)
		spatialChat(pSpeaker, line)
		return "newcomer:" .. line
	end
	if getRandomNumber(1, 100) <= 65 then
		-- Phase 3.6: a share of the talk is galaxy news rather than local colour
		if FbGalaxyChatter ~= nil and getRandomNumber(1, 100) <= self.galaxyShare then
			local news = FbGalaxyChatter.pick(loc.planet)
			if news ~= nil then
				spatialChat(pSpeaker, news)
				return "galaxy:" .. news
			end
		end
		local line = pick(loc.chatter)
		spatialChat(pSpeaker, line)
		return "chat:" .. line
	end
	local anim = pick(loc.emotes)
	CreatureObject(pSpeaker):doAnimation(anim)
	return "emote:" .. anim
end

-- churn(li, si): the patron in a seat leaves and a different one sits down.
function FbAmbientLife:churn(li, si)
	li = tonumber(li) or 1
	local loc = self.locations[li]
	if loc == nil then return "no such location" end
	si = tonumber(si) or getRandomNumber(1, #loc.seats)
	local pOld = self:seatMobile(li, si)
	if pOld ~= nil then
		SceneObject(pOld):destroyObjectFromWorld(true)
	end
	local pNew = self:spawnSeat(li, si)
	return pNew ~= nil and tostring(SceneObject(pNew):getObjectID()) or "0"
end

function FbAmbientLife:onBeat(pNil, liStr)
	local li = tonumber(liStr) or 1
	pcall(function() self:tick(li) end)
	createEvent(between(self.chatterSeconds) * 1000, "FbAmbientLife", "onBeat", nil, tostring(li))
end

function FbAmbientLife:onChurn(pNil, liStr)
	local li = tonumber(liStr) or 1
	pcall(function() self:churn(li, nil) end)
	createEvent(between(self.churnSeconds) * 1000, "FbAmbientLife", "onChurn", nil, tostring(li))
end
