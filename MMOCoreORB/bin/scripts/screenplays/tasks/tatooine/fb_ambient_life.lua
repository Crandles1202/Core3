-- fb_ambient_life.lua — Phase 3.7: ambient life in public spaces (first location: Mos Eisley cantina).
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
}

FbAmbientLife.locations = {
	{
		key = "mos_eisley_cantina", label = "Mos Eisley Cantina", planet = "tatooine",
		-- the lab teleports here to be "in the room" (main room cell, next to the stage)
		anchor = { x = 12.0, z = -0.9, y = 1.5, cell = 1082877 },
		seats = {   -- extra patrons; positions sit beside stock tables without overlapping stock seats
			{ x = 12.6, z = -0.9, y = -5.6, dir = 20,  cell = 1082877 },
			{ x = 25.2, z = -0.9, y = -6.9, dir = 200, cell = 1082877 },
			{ x = -1.0, z = -0.9, y = 12.6, dir = 180, cell = 1082877 },
			{ x = -4.9, z = -0.9, y = -9.9, dir = 40,  cell = 1082877 },
			{ x = 21.6, z = -0.9, y = 7.5,  dir = 250, cell = 1082877 },
		},
		templates = { "patron", "patron_chiss", "patron_devaronian", "patron_ishitib", "patron_ithorian", "patron_klaatu", "patron_nikto", "patron_quarren" },
		moods = { "npc_sitting_chair", "npc_sitting_table", "npc_standing_drinking", "conversation", "bored", "happy", "npc_sitting_table_eating" },
		chatter = {
			"Koochoo. Another round.",
			"Bo shuda, bo shuda... everybody wants something.",
			"The band's loud tonight. Good. Hard to eavesdrop.",
			"Keep your voice down. Imperials at the far table.",
			"Jabba's people were in here yesterday asking about a pilot.",
			"Ten thousand credits? For that rust bucket? Ha.",
			"Mind the Wookiee. He bites.",
			"If the dealer had schematics like that in my day... hmph.",
			"Sandstorm coming. You can smell it.",
			"I don't drink with Rodians. Nothing personal.",
			"Chuba! Watch where you put those feet.",
			"That armory droid by the starport? Overpriced. Reliable, though.",
		},
		newcomer = {
			"Hm. New face.",
			"Don't know you. Sit anywhere, just not here.",
			"Eyes front, friend. Nobody likes a gawker.",
			"Another one off the shuttle. Welcome to Mos Eisley.",
		},
		emotes = { "shrug_shoulders", "nod_head_once", "shake_head_disgust", "sigh_deeply", "rub_chin_thoughtful", "slow_down", "explain" },
	},
}

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
	local pMobile = spawnMobile(loc.planet, template, 0, seat.x, seat.z, seat.y, seat.dir, seat.cell)
	if pMobile == nil then
		printf("FbAmbientLife: could not spawn %s at %s seat %d\n", template, loc.label, si)
		return nil
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
