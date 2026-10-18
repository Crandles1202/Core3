-- fb_holonet.lua — Phase 3.10: HoloNet news broadcasts.
--
-- Relay droids at public places read a short, produced news segment out loud (spatial chat, one
-- line every few seconds) whenever players are near: sting, headline (the live story ticker),
-- a galaxy item, a "wanted" segment built from the story's mobs, and an outro. Same pipeline as the
-- galaxy chatter, more produced. Nothing plays to an empty room.
--
-- Public for the lab: FbHoloNet:segment(loc) -> the lines the next broadcast would read;
-- FbHoloNet:broadcast(loc) reads one now; :status(loc) one line.

FbHoloNet = ScreenPlay:new {
	screenplayName = "FbHoloNet",
	mobile = "fb_holonet_relay",
	intervalSeconds = { 45, 75 },   -- between broadcasts while players are near
	lineGapSeconds = 3,             -- between the lines of one broadcast
	listenRange = 25,
}

FbHoloNet.locations = {
	{ key = "mos_eisley_starport", label = "Mos Eisley Starport", region = "mos_eisley", planet = "tatooine", x = 3540, y = -4816, dir = 1, cell = 0 },   -- end of the FB vendor row; (3512,-4790) had no line of sight for conversations
	{ key = "mos_eisley_cantina",  label = "Mos Eisley Cantina",  region = "mos_eisley", planet = "tatooine", x = 10.5, z = -0.9, y = 8.5, dir = 3, cell = 1082877 },
	{ key = "bestine_cantina",     label = "Bestine Cantina",     region = "bestine", planet = "tatooine", x = 9.0,  z = 0.4,  y = -8.5, dir = 3, cell = 1528397 },
}

FbHoloNet.stings = {
	"*static* ...this is HoloNet News. Galactic update.",
	"*tone* HoloNet News, bringing the galaxy to your sector.",
	"*static* HoloNet News. Stay informed. Stay loyal.",
}
FbHoloNet.propaganda = {
	"A message from the Imperial Governor's office: order is prosperity. Report unlawful gatherings.",
	"Travellers are reminded that unregistered weapons are subject to confiscation at starports.",
	"The Empire thanks the citizens of Tatooine for another month of record moisture output.",
}
-- Phase 3.4: when the Rebellion holds the relay's region, the relay has been "liberated"
FbHoloNet.rebelPropaganda = {
	"A message from the Alliance: this relay is free. The Empire's lies stop here.",
	"Citizens: the garrison answers to you now. Report Imperial sympathizers to the local cell.",
	"The Alliance thanks the farmers of Tatooine for their quiet support. Water flows both ways.",
}
FbHoloNet.outros = {
	"This has been HoloNet News. Next update in one standard hour.",
	"HoloNet News will return. The Empire reminds you: loyalty is its own reward.",
}

registerScreenPlay("FbHoloNet", true)

local function pick(list) return list[getRandomNumber(1, #list)] end
local function between(range) return getRandomNumber(range[1], range[2]) end
local function relayKey(loc) return "FbHoloNet." .. loc.key .. ".relay" end

-- ---- lifecycle --------------------------------------------------------------------------------

function FbHoloNet:start()
	for li, loc in ipairs(self.locations) do
		if isZoneEnabled(loc.planet) then
			self:spawnRelay(li)
			createEvent(between(self.intervalSeconds) * 1000, "FbHoloNet", "onTick", nil, tostring(li))
		end
	end
	printf("FbHoloNet: %d relays\n", #self.locations)
end

function FbHoloNet:spawnRelay(li)
	local loc = self.locations[li]
	local z = loc.z
	if z == nil then z = getTerrainHeightAt(loc.planet, loc.x, loc.y) end
	local pRelay = spawnMobile(loc.planet, self.mobile, 0, loc.x, z, loc.y, loc.dir or 0, loc.cell or 0)
	if pRelay == nil then
		printf("FbHoloNet: could not spawn relay at %s\n", loc.label)
		return nil
	end
	setQuestStatus(relayKey(loc), tostring(SceneObject(pRelay):getObjectID()))
	return pRelay
end

function FbHoloNet:relay(li)
	local loc = self.locations[li]
	if loc == nil then return nil end
	local oid = tonumber(getQuestStatus(relayKey(loc)))
	if oid == nil or oid == 0 then return nil end
	local p = getSceneObject(oid)
	if p == nil or SceneObject(p):getZoneName() == "" then return nil end
	return p
end

function FbHoloNet:status(li)
	li = tonumber(li) or 1
	local loc = self.locations[li]
	if loc == nil then return "no such location" end
	local p = self:relay(li)
	local near = 0
	if p ~= nil then
		local players = SceneObject(p):getPlayersInRange(self.listenRange)
		if players ~= nil then for _ in pairs(players) do near = near + 1 end end
	end
	return string.format("loc=%d key=%s relay=%s cell=%d players_near=%d", li, loc.key,
		p ~= nil and tostring(SceneObject(p):getObjectID()) or "0", p ~= nil and SceneObject(p):getParentID() or -1, near)
end

-- ---- the programme ----------------------------------------------------------------------------

-- segment(li): the lines of one broadcast, assembled from what the server knows right now.
function FbHoloNet:segment(li)
	local loc = self.locations[tonumber(li) or 1] or self.locations[1]
	local lines = { pick(self.stings) }

	if FbStoryTicker ~= nil then
		local story = FbStoryTicker.stories[FbStoryTicker:current()]
		if story ~= nil then
			lines[#lines + 1] = "Top story: " .. story.title .. "."
			local wanted = {}
			for _, g in ipairs(story.mobs) do wanted[#wanted + 1] = g.count .. " " .. g.template:gsub("_", " ") end
			lines[#lines + 1] = "This week's wanted: " .. table.concat(wanted, " and ") .. ". Authorities request assistance."
		end
	end

	if FbGalaxyChatter ~= nil then
		local news = FbGalaxyChatter.pick()
		if news ~= nil then lines[#lines + 1] = "In other news: " .. news end
	end

	if FbTravelingMerchant ~= nil then
		local stop = FbTravelingMerchant.stops[FbTravelingMerchant:currentStop()]
		if stop ~= nil then lines[#lines + 1] = "Commerce: the licensed traveling merchant is trading at " .. stop.label .. " this week." end
	end

	if FbTerritory ~= nil then
		local parts = {}
		for _, region in ipairs(FbTerritory.order) do
			local f = FbTerritory.faction(region)
			parts[#parts + 1] = FbTerritory.regions[region].label .. " " .. (f == "imperial" and "Imperial-held" or f == "rebel" and "Rebel-held" or "contested")
		end
		lines[#lines + 1] = "Sector report: " .. table.concat(parts, ", ") .. "."
	end
	local holder = (FbTerritory ~= nil and loc.region) and FbTerritory.faction(loc.region) or "imperial"
	lines[#lines + 1] = pick(holder == "rebel" and self.rebelPropaganda or self.propaganda)
	lines[#lines + 1] = pick(self.outros)
	return lines
end

-- broadcast(li): read a segment at location li, one line every lineGapSeconds. Returns line count.
function FbHoloNet:broadcast(li)
	li = tonumber(li) or 1
	local p = self:relay(li)
	if p == nil then return 0 end
	local lines = self:segment(li)
	for i, line in ipairs(lines) do
		if i == 1 then
			spatialChat(p, line)
		else
			createEvent((i - 1) * self.lineGapSeconds * 1000, "FbHoloNet", "onLine", p, line)
		end
	end
	return #lines
end

function FbHoloNet:onLine(pRelay, line)
	if pRelay ~= nil and SceneObject(pRelay):getZoneName() ~= "" then spatialChat(pRelay, line) end
end

function FbHoloNet:onTick(pNil, liStr)
	local li = tonumber(liStr) or 1
	local p = self:relay(li)
	if p ~= nil then
		local players = SceneObject(p):getPlayersInRange(self.listenRange)
		local near = false
		if players ~= nil then for _ in pairs(players) do near = true break end end
		if near then pcall(function() self:broadcast(li) end) end
	else
		pcall(function() self:spawnRelay(li) end)
	end
	createEvent(between(self.intervalSeconds) * 1000, "FbHoloNet", "onTick", nil, tostring(li))
end
