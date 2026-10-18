-- fb_galaxy_chatter.lua — Phase 3.6: galaxy chatter.
--
-- One shared pool of "what people are talking about" lines that FbAmbientLife mixes into every
-- location's local chatter. Two sources:
--   * static galaxy news (roadmap: "static for now"), and
--   * live facts the server already knows: where the traveling merchant is this visit and which
--     phase the Bestine election is in. Phase 3.5 (story ticker) will push into addNews().
-- Public: FbGalaxyChatter.lines() -> array of strings; FbGalaxyChatter.addNews(key, line, ttlSeconds).

FbGalaxyChatter = {
	static = {
		"Did you hear about the Imperial garrison on Naboo? Doubled overnight.",
		"They say a Rebel cell got rolled up on Corellia. CorSec's not talking.",
		"Hutt freighters are running Kessel spice through Nal Hutta again. Prices are up.",
		"Bounty went out on some senator. Nobody knows which one. Everybody's guessing.",
		"Dantooine's quiet. Too quiet. Nobody goes to Dantooine for nothing.",
		"A whole Star Destroyer parked over Talus last week. Just sat there.",
		"Lok's getting worse. Nym's people shot at a supply ship, I heard.",
		"The Empire's hiring on Yavin. Don't ask what for.",
		"Shuttle fares are up again. Blame the blockade, blame the Hutts, blame anyone.",
		"My cousin on Rori swears she saw a Jedi. My cousin also drinks.",
	},
}

-- addNews(key, line, ttlSeconds): a dated line that expires; stored in quest status so every Lua
-- state and the next server start see it. Keys must not contain ':'.
-- The pool stays short: the same line posted again (a second convoy, another storm) refreshes the
-- existing entry instead of adding a twin, expired entries are dropped, and only the newest maxNews
-- survive — a cantina full of patrons repeating sixty old headlines is not news.
FbGalaxyChatter.maxNews = 8

function FbGalaxyChatter.addNews(key, line, ttlSeconds)
	local now = os.time()
	local expires = now + (tonumber(ttlSeconds) or 7 * 24 * 3600)
	local keys = getQuestStatus("FbGalaxyChatter.newsKeys") or ""
	local kept = {}
	for k in keys:gmatch("[^,]+") do
		local raw = getQuestStatus("FbGalaxyChatter.news." .. k)
		local exp, text = (raw or ""):match("^(%d+)|(.*)$")
		if k == key or exp == nil or tonumber(exp) <= now or text == line then
			if k ~= key then removeQuestStatus("FbGalaxyChatter.news." .. k) end   -- expired, or the twin we replace
		else
			kept[#kept + 1] = k
		end
	end
	kept[#kept + 1] = key
	while #kept > FbGalaxyChatter.maxNews do
		removeQuestStatus("FbGalaxyChatter.news." .. table.remove(kept, 1))
	end
	setQuestStatus("FbGalaxyChatter.news." .. key, tostring(expires) .. "|" .. line)
	setQuestStatus("FbGalaxyChatter.newsKeys", "," .. table.concat(kept, ",") .. ",")
end

function FbGalaxyChatter.newsLines()
	local out = {}
	local keys = getQuestStatus("FbGalaxyChatter.newsKeys") or ""
	for key in keys:gmatch("[^,]+") do
		local raw = getQuestStatus("FbGalaxyChatter.news." .. key)
		if raw ~= nil and raw ~= "" then
			local expires, line = raw:match("^(%d+)|(.*)$")
			if expires ~= nil and tonumber(expires) > os.time() then out[#out + 1] = line end
		end
	end
	return out
end

-- Live facts, each guarded: a missing screenplay or a Lua error just drops that line.
function FbGalaxyChatter.liveLines()
	local out = {}
	pcall(function()
		if FbTravelingMerchant ~= nil then
			local stop = FbTravelingMerchant.stops[FbTravelingMerchant:currentStop()]
			if stop ~= nil then
				out[#out + 1] = "That traveling merchant, Ozlo? Someone saw him setting up at " .. stop.label .. ". Won't be there long."
			end
		end
	end)
	pcall(function()
		if FbTerritory ~= nil then
			for _, region in ipairs(FbTerritory.order) do
				local f, label = FbTerritory.faction(region), FbTerritory.regions[region].label
				if f == "rebel" then out[#out + 1] = "The Rebels run " .. label .. " these days. Stormtroopers don't leave the garrison after dark."
				elseif f == "contested" then out[#out + 1] = label .. "'s anyone's. Saw Imperials and Rebels drinking at opposite ends of the same bar."
				end
			end
		end
	end)
	pcall(function()
		if BestineElection ~= nil and type(BestineElection.getCurrentPhase) == "function" then
			local phase = BestineElection:getCurrentPhase()
			if phase == 1 then
				out[#out + 1] = "Bestine's election is on. Both candidates are promising lower water taxes. Both are lying."
			elseif phase ~= nil then
				out[#out + 1] = "Election's over in Bestine. Half the town's sulking about it."
			end
		end
	end)
	return out
end

function FbGalaxyChatter.lines()
	local all = {}
	for _, l in ipairs(FbGalaxyChatter.static) do all[#all + 1] = l end
	for _, l in ipairs(FbGalaxyChatter.newsLines()) do all[#all + 1] = l end
	for _, l in ipairs(FbGalaxyChatter.liveLines()) do all[#all + 1] = l end
	return all
end

function FbGalaxyChatter.pick()
	local all = FbGalaxyChatter.lines()
	if #all == 0 then return nil end
	return all[getRandomNumber(1, #all)]
end
