-- fb_territory.lua — Phase 3.4: the faction territory map.
--
-- Each region carries an Imperial control percentage (quest status "FbTerritory.<region>", 0–100).
-- Events shift it: an invasion held/fell (±10, FbInvasions), a convoy destroyed (−10) or arrived (+5,
-- FbConvoys). The rest of the living galaxy reads it: patrol squads of the dominant faction are a man
-- stronger and the minority's a man weaker (FbFactionPatrols), HoloNet propaganda speaks for whoever
-- holds the relay's region (FbHoloNet), cantina patrons gossip about who is winning (FbGalaxyChatter).
-- Crossing a threshold (60 % Imperial-held, 40 % Rebel-held, contested between) posts a news line and
-- tells everyone online. Vendor faction and mission types are not wired yet.
--
-- Public: FbTerritory.control(region) -> %, .faction(region) -> "imperial"|"rebel"|"contested",
-- .shift(region, delta, reason) -> new %, .set(region, pct), .squadFor(route) -> members list, .status().

FbTerritory = {
	imperialAt = 60,   -- % and above: Imperial-held
	rebelAt = 40,      -- % and below: Rebel-held
}

-- 3.13: every city (tasks/cities/*.lua) is a region; its key is the region key, `lean` the default Imperial %
FbTerritory.regions, FbTerritory.order = {}, {}
if FbCities ~= nil then
	for _, c in ipairs(FbCities.list) do
		FbTerritory.regions[c.key] = { label = c.label, planet = c.planet, default = c.lean }
		FbTerritory.order[#FbTerritory.order + 1] = c.key
	end
end

-- onPlanet(planet): the region keys of one planet, in order (the HoloNet sector report and the gossip stay local)
function FbTerritory.onPlanet(planet)
	local out = {}
	for _, region in ipairs(FbTerritory.order) do
		if planet == nil or FbTerritory.regions[region].planet == planet then out[#out + 1] = region end
	end
	return out
end

local function key(region) return "FbTerritory." .. region end

function FbTerritory.control(region)
	local r = FbTerritory.regions[region]
	if r == nil then return -1 end
	local v = tonumber(getQuestStatus(key(region)))
	if v == nil then return r.default end
	return math.max(0, math.min(100, v))
end

function FbTerritory.factionAt(pct)
	if pct >= FbTerritory.imperialAt then return "imperial" end
	if pct <= FbTerritory.rebelAt then return "rebel" end
	return "contested"
end

function FbTerritory.faction(region)
	local pct = FbTerritory.control(region)
	if pct < 0 then return "unknown" end
	return FbTerritory.factionAt(pct)
end

function FbTerritory.set(region, pct)
	if FbTerritory.regions[region] == nil then return -1 end
	pct = math.max(0, math.min(100, math.floor(tonumber(pct) or 50)))
	setQuestStatus(key(region), tostring(pct))
	return pct
end

local function describe(region, faction)
	local label = FbTerritory.regions[region].label
	if faction == "imperial" then return label .. " is firmly in Imperial hands again. Patrols are everywhere." end
	if faction == "rebel" then return "The Rebellion holds " .. label .. " now. Stormtroopers are keeping to the garrison." end
	return label .. " is up for grabs. Both sides are recruiting in the cantina."
end

-- shift(region, delta, reason): move the needle; on a threshold crossing, news + broadcast.
function FbTerritory.shift(region, delta, reason)
	local r = FbTerritory.regions[region]
	if r == nil then return -1 end
	local before = FbTerritory.control(region)
	local after = FbTerritory.set(region, before + (tonumber(delta) or 0))
	local was, now = FbTerritory.factionAt(before), FbTerritory.factionAt(after)
	if was ~= now then
		local line = describe(region, now)
		if FbGalaxyChatter ~= nil then FbGalaxyChatter.addNews("territory_" .. region .. "_" .. tostring(os.time()), line, 3 * 24 * 3600) end
		pcall(function()
			-- broadcastToGalaxy needs a creature as the sender: borrow any HoloNet relay
			if FbHoloNet ~= nil then
				for li, _ in ipairs(FbHoloNet.locations) do
					local p = FbHoloNet:relay(li)
					if p ~= nil then broadcastToGalaxy(p, r.label .. ": " .. line); break end
				end
			end
		end)
	end
	printf("FbTerritory: %s %d -> %d (%s)%s\n", region, before, after, tostring(reason), was ~= now and (" now " .. now) or "")
	return after
end

-- squadFor(route): the patrol members a route gets right now — dominant faction +1, minority −1 (min 1).
function FbTerritory.squadFor(route)
	local members = {}
	for _, m in ipairs(route.members) do members[#members + 1] = m end
	local holder = route.region and FbTerritory.faction(route.region) or "contested"
	if holder == route.faction then
		members[#members + 1] = members[#members]
	elseif holder ~= "contested" and holder ~= "unknown" and #members > 1 then
		members[#members] = nil
	end
	return members
end

function FbTerritory.status()
	local parts = {}
	for _, region in ipairs(FbTerritory.order) do
		parts[#parts + 1] = string.format("%s=%d(%s)", region, FbTerritory.control(region), FbTerritory.faction(region))
	end
	return table.concat(parts, " ")
end
