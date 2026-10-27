-- fb_cities.lua — Phase 3.13: the city registry.
--
-- A city is a data file in screenplays/tasks/cities/<planet>_<city>.lua calling FbCities:add { … }. The living-world
-- screenplays build their own tables from it when they load (so this file is included before them in screenplays.lua):
--   key, planet, label, order        the territory region (3.4) is the city key; `order` sorts cities within a planet
--   lean                             default Imperial % (3.4)
--   factions.imperial/rebel          { leader, troops } — the squads patrols draw on (3.2)
--   patrols.imperial/rebel           { points = { {x, z|nil, y}, … } [, leader, members] } — a walking squad (3.2)
--   convoy                           true, or { route = {{x, 0, y}, …} } or { from = {x, y}, to = {x, y} } (navmesh route) (3.11)
--   relays                           { { key, label, x, y[, z], dir, cell }, … } — HoloNet relay droids (3.10)
--   ambient                          { { key, label, anchor, seats, templates, moods, chatter, newcomer, emotes }, … } (3.7/3.8)
--   invasion                         { defender, attacker, staging, plaza, muster, attackers, defenders, texts… } (3.1)
--   starport, plaza                  { x, y } — the points the generated routes hang off
-- Keys are city-relative ("cantina", "starport"); the screenplays prefix them with the city key, so the Mos Eisley
-- relay is still "mos_eisley_starport" everywhere (lab, scenarios, quest status).
--
-- Public: FbCities.list (sorted: planet order below, then `order`, then key), FbCities:get(key), FbCities:onPlanet(planet),
-- FbCities.planetLabel(planet).

FbCities = {
	dir = "scripts/screenplays/tasks/cities",
	list = {},
	byKey = {},
	planetOrder = { "tatooine", "naboo", "corellia", "talus", "rori", "lok", "dantooine", "dathomir", "endor", "yavin4" },
	planetLabels = { tatooine = "Tatooine", naboo = "Naboo", corellia = "Corellia", talus = "Talus", rori = "Rori", lok = "Lok",
		dantooine = "Dantooine", dathomir = "Dathomir", endor = "Endor", yavin4 = "Yavin 4" },
	defaultFactions = {
		imperial = { leader = "stormtrooper_squad_leader", troops = { "stormtrooper", "stormtrooper" } },
		rebel    = { leader = "rebel_commando", troops = { "rebel_trooper", "rebel_trooper" } },
	},
}

function FbCities.planetLabel(planet) return FbCities.planetLabels[planet] or tostring(planet) end

function FbCities:add(c)
	if c == nil or c.key == nil or c.planet == nil then printf("FbCities: a city without key/planet was ignored\n"); return end
	c.label = c.label or c.key
	c.lean = tonumber(c.lean) or 50
	c.order = tonumber(c.order) or 99
	c.factions = c.factions or {}
	c.patrols = c.patrols or {}
	c.relays = c.relays or {}
	c.ambient = c.ambient or {}
	if self.byKey[c.key] ~= nil then
		for i, old in ipairs(self.list) do if old.key == c.key then self.list[i] = c end end   -- a reload replaces in place
	else
		self.list[#self.list + 1] = c
	end
	self.byKey[c.key] = c
end

function FbCities:get(key) return self.byKey[key] end

function FbCities:onPlanet(planet)
	local out = {}
	for _, c in ipairs(self.list) do if c.planet == planet then out[#out + 1] = c end end
	return out
end

function FbCities:faction(c, faction)
	return (c.factions and c.factions[faction]) or self.defaultFactions[faction]
end

function FbCities:sort()
	local rank = {}
	for i, p in ipairs(self.planetOrder) do rank[p] = i end
	table.sort(self.list, function(a, b)
		local ra, rb = rank[a.planet] or 99, rank[b.planet] or 99
		if ra ~= rb then return ra < rb end
		if a.order ~= b.order then return a.order < b.order end
		return a.key < b.key
	end)
end

-- the city files
do
	local p = io.popen and io.popen("ls " .. FbCities.dir .. "/*.lua 2>/dev/null")
	if p ~= nil then
		for line in p:lines() do
			local f = line:match("([^/]+%.lua)$")
			if f ~= nil then includeFile("tasks/cities/" .. f) end
		end
		p:close()
	end
	FbCities:sort()
	local planets = {}
	for _, c in ipairs(FbCities.list) do planets[c.planet] = true end
	local n = 0
	for _ in pairs(planets) do n = n + 1 end
	printf("FbCities: %d cities on %d planets\n", #FbCities.list, n)
end
