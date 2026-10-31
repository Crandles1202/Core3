-- fb_sith_shadows.lua — Final Boss 4b.1: Sith Shadow camps (2026-10-31).
--
-- Stock Core3 has Sith Shadows only as Village quest mobiles on Dathomir; Master Venn's "shadows" task (five
-- sith_shadow kills) and the Jedi rank-1 task (ten) had nothing to hunt. Four camps now stand where she says they
-- do: a few hundred metres east of each Yavin 4 enclave, by the old temple on Dantooine, and outside the crystal
-- hunters' cave. Each camp is a handful of the stock sith_shadow_outlaw (17) / pirate (32) / thug (51), aggressive
-- on sight; the dead are replaced every ten minutes (the story ticker's pattern: records in quest status, no AiAgent
-- respawn timers). Lab: shadowCamps, shadowCampsRefill.
FbSithShadows = ScreenPlay:new {
	numberOfActs = 1,
	screenplayName = "FbSithShadows",
	refillMinutes = 10,
	camps = {
		{ key = "yavin_light", planet = "yavin4", x = -5150, y = 4900, radius = 12, label = "east of the Light Enclave",
			templates = { "sith_shadow_outlaw", "sith_shadow_outlaw", "sith_shadow_outlaw", "sith_shadow_pirate", "sith_shadow_pirate" } },
		{ key = "yavin_dark", planet = "yavin4", x = 5400, y = 500, radius = 12, label = "east of the Dark Enclave",
			templates = { "sith_shadow_outlaw", "sith_shadow_outlaw", "sith_shadow_outlaw", "sith_shadow_pirate", "sith_shadow_pirate" } },
		{ key = "dantooine_temple", planet = "dantooine", x = 4460, y = 5260, radius = 14, label = "by the old temple on Dantooine",
			templates = { "sith_shadow_outlaw", "sith_shadow_pirate", "sith_shadow_pirate", "sith_shadow_thug", "sith_shadow_thug" } },
		{ key = "dantooine_cave", planet = "dantooine", x = -5900, y = 7250, radius = 12, label = "outside the crystal hunters' cave",
			templates = { "sith_shadow_outlaw", "sith_shadow_outlaw", "sith_shadow_outlaw", "sith_shadow_pirate", "sith_shadow_pirate" } },
	},
}
registerScreenPlay("FbSithShadows", true)

function FbSithShadows:recordsKey(camp) return "FbSithShadows.camp." .. camp.key end

function FbSithShadows:records(camp)
	local out = {}
	for oid, template in (getQuestStatus(self:recordsKey(camp)) or ""):gmatch("(%d+)=([%w_]+)") do
		out[#out + 1] = { oid = tonumber(oid), template = template }
	end
	return out
end

function FbSithShadows:save(camp, records)
	local parts = {}
	for _, r in ipairs(records) do parts[#parts + 1] = tostring(r.oid) .. "=" .. r.template end
	setQuestStatus(self:recordsKey(camp), table.concat(parts, ","))
end

local function alive(oid)
	local p = getSceneObject(oid)
	return p ~= nil and SceneObject(p):isCreatureObject() and not CreatureObject(p):isDead()
end

function FbSithShadows:spawnOne(camp, template)
	local x = camp.x + getRandomNumber(-camp.radius, camp.radius)
	local y = camp.y + getRandomNumber(-camp.radius, camp.radius)
	local z = getTerrainHeightAt(camp.planet, x, y)
	return spawnMobile(camp.planet, template, 0, x, z, y, getRandomNumber(0, 6), 0)
end

-- spawnCamp(camp): every member fresh (a restart loses spawnMobile NPCs; old records are dropped)
function FbSithShadows:spawnCamp(camp)
	if not isZoneEnabled(camp.planet) then return 0 end
	local records = {}
	for _, template in ipairs(camp.templates) do
		local p = self:spawnOne(camp, template)
		if p ~= nil then records[#records + 1] = { oid = SceneObject(p):getObjectID(), template = template } end
	end
	self:save(camp, records)
	return #records
end

-- refill(): the dead are replaced, camp by camp; returns how many
function FbSithShadows:refill()
	local replaced = 0
	for _, camp in ipairs(self.camps) do
		if isZoneEnabled(camp.planet) then
			local records = self:records(camp)
			if #records == 0 then
				replaced = replaced + self:spawnCamp(camp)
			else
				for _, r in ipairs(records) do
					if not alive(r.oid) then
						local p = self:spawnOne(camp, r.template)
						if p ~= nil then r.oid = SceneObject(p):getObjectID(); replaced = replaced + 1 end
					end
				end
				self:save(camp, records)
			end
		end
	end
	return replaced
end

function FbSithShadows:onRefill()
	pcall(function() self:refill() end)
	createEvent(self.refillMinutes * 60 * 1000, "FbSithShadows", "onRefill", nil, "")
end

-- status(): one line per camp (lab)
function FbSithShadows:status()
	local lines = {}
	for _, camp in ipairs(self.camps) do
		local n, up = 0, 0
		for _, r in ipairs(self:records(camp)) do n = n + 1; if alive(r.oid) then up = up + 1 end end
		lines[#lines + 1] = string.format("camp=%s planet=%s x=%d y=%d alive=%d/%d of=%d", camp.key, camp.planet, camp.x, camp.y, up, n, #camp.templates)
	end
	return lines
end

-- nearest(planet, x, y) -> camp on that planet nearest a point, or nil
function FbSithShadows:nearest(planet, x, y)
	local best, bestD
	for _, camp in ipairs(self.camps) do
		if camp.planet == planet then
			local d = (camp.x - x) ^ 2 + (camp.y - y) ^ 2
			if bestD == nil or d < bestD then best, bestD = camp, d end
		end
	end
	return best
end

function FbSithShadows:start()
	local n = 0
	for _, camp in ipairs(self.camps) do n = n + self:spawnCamp(camp) end
	createEvent(self.refillMinutes * 60 * 1000, "FbSithShadows", "onRefill", nil, "")
	printf("FbSithShadows: %d shadows in %d camps\n", n, #self.camps)
end
