-- fb_bounty.lua — Phase 4c: the bounty on a visible Jedi.
--
-- Stock visibility is the score: every Force power or saber swing in view of NPCs and players raises it, it
-- decays over three weeks (visibility_manager.lua), and at 1500 a Jedi shows on the bounty terminals. Here the
-- same threshold puts a price on the character: hunters come for them. The Phase 4 decisions: hunters open fire
-- and never talk; their number and strength scale with visibility and rank, up to a squad for a high-visibility
-- Master; visibility fades on its own, the bounty itself never shrinks; it can be paid off through a shady fixer in
-- a cantina for a markup. At deep alignment (|score| ≥ 60) one of the hunters is a Force user of the other side
-- (4c.4). Bounty hunter players can already hunt a visible Jedi through the stock terminals (4c.3 is stock).
--
-- Who comes: by the character's level — `thug` (to 40), `hunter` (to 80), `veteran` (above); how many: FRS rank
-- 0–3 one, 4–7 two, 8+ three; visibility ≥ 5000 adds one. They spawn 45–60 m out on a random bearing, are set on
-- the character and attack on sight. All down → a cooldown before the next hunt (30 min, 20 for a Master);
-- the character down → the hunters leave after a minute and the next hunt is 20 min off. Paying the fixer clears
-- the bounty and keeps the hunters away for a day; visibility still decays as stock.
--
-- State: FbAttunement flags `bounty` (credits owed), `bountyPaidUntil`, `nextHuntAt`; quest status
-- `FbBounty.hunters.<oid>` (live hunter oids). A per-player tick every five minutes while online, plus the attunement
-- trigger. Lab: FbLabTests bounty / bountySet / bountyTick / bountyPay / bountyClear, checkBounty; scenario `bounty`.

FbBounty = {
	threshold = 1500,          -- stock termThreshold (visibility_manager.lua)
	squadAt = 5000,            -- visibility that adds a hunter
	creditsPerVisibility = 10, -- the bounty: 1500 → 15 000 cr
	markup = 1.5,              -- what the fixer charges
	paidFor = 24 * 3600,       -- hunters stay away this long after a payment
	cooldown = 30 * 60, masterCooldown = 20 * 60, deathCooldown = 20 * 60,
	tickMs = 5 * 60 * 1000,
	tiers = {                  -- by the character's level
		{ upTo = 40, template = "fb_bounty_thug" },
		{ upTo = 80, template = "fb_bounty_hunter" },
		{ upTo = 999, template = "fb_bounty_veteran" },
	},
	forceHunters = { light = "fb_bounty_dark_hunter", dark = "fb_bounty_light_hunter" },   -- who hunts a deep light / deep dark Jedi
	deepAt = 60,
	fixer = {
		name = "Dax Ventrell", template = "fb_fixer",
		-- the Mos Eisley cantina (stock building 1082874), its main room `cantina` (cell 1082877), beside the bar's
		-- regulars: (12.8, 3.2) is 8/8 on the placement audit (lab, 2026-10-23; (8, 4) by the wall was 0/8), floor −0.9
		zone = "tatooine", buildingOid = 1082874, room = "cantina", x = 12.8, z = -0.9, y = 3.2, heading = 200,
	},
}

-- ---------------------------------------------------------------- state

local function flag(pPlayer, n) return FbAttunement ~= nil and FbAttunement:flag(pPlayer, n) or nil end
local function setFlag(pPlayer, n, v) if FbAttunement ~= nil then FbAttunement:setFlag(pPlayer, n, v) end end
local function num(pPlayer, n) return tonumber(flag(pPlayer, n) or 0) or 0 end
local function say(pPlayer, id) CreatureObject(pPlayer):sendSystemMessage("@fb_force:bounty_" .. id) end

function FbBounty:isJedi(pPlayer) return pPlayer ~= nil and CreatureObject(pPlayer):hasSkill("force_title_jedi_novice") end
function FbBounty:visibility(pPlayer)
	local pGhost = CreatureObject(pPlayer):getPlayerObject()
	return pGhost ~= nil and PlayerObject(pGhost):getVisibility() or 0
end
function FbBounty:amount(pPlayer) return num(pPlayer, "bounty") end
function FbBounty:isPaid(pPlayer) return num(pPlayer, "bountyPaidUntil") > os.time() end
function FbBounty:rank(pPlayer)
	local pGhost = CreatureObject(pPlayer):getPlayerObject()
	return pGhost ~= nil and PlayerObject(pGhost):getFrsRank() or 0
end

-- the price keeps up with the visibility and never comes down on its own
function FbBounty:updateAmount(pPlayer)
	if self:visibility(pPlayer) < self.threshold then return self:amount(pPlayer) end   -- no price until the terminals would list you
	if self:isPaid(pPlayer) then return self:amount(pPlayer) end   -- the fixer's arrangement holds for its day
	local want = math.floor(self:visibility(pPlayer) * self.creditsPerVisibility)
	if want > self:amount(pPlayer) then
		local had = self:amount(pPlayer)
		setFlag(pPlayer, "bounty", want)
		if had == 0 and want >= self.threshold * self.creditsPerVisibility then say(pPlayer, "placed") end
	end
	return self:amount(pPlayer)
end

function FbBounty:isActive(pPlayer)
	return self:isJedi(pPlayer) and self:visibility(pPlayer) >= self.threshold and not self:isPaid(pPlayer)
end

function FbBounty:reset(pPlayer)
	self:despawnHunters(pPlayer)
	for _, k in ipairs({ "bounty", "bountyPaidUntil", "nextHuntAt" }) do
		if FbAttunement ~= nil then deleteScreenPlayData(pPlayer, FbAttunement.DATA, "flag:" .. k) end
	end
end

-- ---------------------------------------------------------------- the hunters

function FbBounty:hunterKey(pPlayer) return "FbBounty.hunters." .. SceneObject(pPlayer):getObjectID() end
function FbBounty:hunters(pPlayer)
	local list = {}
	for oid in tostring(getQuestStatus(self:hunterKey(pPlayer)) or ""):gmatch("%d+") do
		local p = getSceneObject(tonumber(oid))
		if p ~= nil and SceneObject(p):getZoneName() ~= "" and not CreatureObject(p):isDead() then list[#list + 1] = p end
	end
	return list
end
function FbBounty:liveCount(pPlayer) return #self:hunters(pPlayer) end

function FbBounty:tierFor(pPlayer)
	local level = CreatureObject(pPlayer):getLevel()
	for _, t in ipairs(self.tiers) do if level <= t.upTo then return t.template end end
	return self.tiers[#self.tiers].template
end

function FbBounty:squadSize(pPlayer)
	local rank = self:rank(pPlayer)
	local n = rank >= 8 and 3 or (rank >= 4 and 2 or 1)
	if self:visibility(pPlayer) >= self.squadAt then n = n + 1 end
	return n
end

-- the composition: the level tier, with a Force user of the other side in the squad at deep alignment (4c.4)
function FbBounty:composition(pPlayer)
	local list = {}
	local base = self:tierFor(pPlayer)
	for i = 1, self:squadSize(pPlayer) do list[i] = base end
	if FbAlignment ~= nil then
		local score = FbAlignment:score(pPlayer)
		if score >= self.deepAt then list[1] = self.forceHunters.light elseif score <= -self.deepAt then list[1] = self.forceHunters.dark end
	end
	return list
end

-- the hunt: the squad spawns out of sight and comes for the character
function FbBounty:hunt(pPlayer)
	if pPlayer == nil then return false end
	-- plain numbers first: SceneObject(pMob) below re-points the one shared wrapper (the gotcha; the first run wrote
	-- each hunter's own id as its owner and the cooldown went to an NPC called Lerlo)
	local zone, parent = SceneObject(pPlayer):getZoneName(), SceneObject(pPlayer):getParentID()
	if zone == "" or parent ~= 0 then return false end
	local playerOid = SceneObject(pPlayer):getObjectID()
	local px, py, pz = SceneObject(pPlayer):getWorldPositionX(), SceneObject(pPlayer):getWorldPositionY(), SceneObject(pPlayer):getWorldPositionZ()
	local bearing = math.rad(getRandomNumber(360))
	local dist = 45 + getRandomNumber(15)
	local oids = {}
	for i, template in ipairs(self:composition(pPlayer)) do
		local a = bearing + (i - 1) * 0.15
		local x, y = px + dist * math.cos(a), py + dist * math.sin(a)
		local pMob = spawnMobile(zone, template, 0, x, getTerrainHeightAt(zone, x, y), y, 0, 0)
		if pMob ~= nil then
			local oid = SceneObject(pMob):getObjectID()
			oids[#oids + 1] = oid
			writeData(oid .. ":fbBountyFor", playerOid)
			AiAgent(pMob):setHomeLocation(px, pz, py, nil)   -- no leashing back while they close in
			AiAgent(pMob):setDefender(pPlayer)   -- on the character from the first step; aggressive and ENEMY besides
			createObserver(OBJECTDESTRUCTION, "FbBounty", "onHunterDown", pMob)
			createEvent(45 * 60 * 1000, "FbBounty", "sweepHunter", pPlayer, tostring(oid))
			if FbLabTests ~= nil and FbLabTests.registryAdd ~= nil then
				FbLabTests.registryAdd({ oid = oid, zone = zone, cell = 0, x = x, y = y, z = getTerrainHeightAt(zone, x, y), template = template, src = "fb_bounty", name = SceneObject(pMob):getObjectName() })
			end
		end
	end
	if #oids == 0 then return false end
	setQuestStatus(self:hunterKey(pPlayer), table.concat(oids, ","))
	say(pPlayer, "hunted")
	printf("FbBounty: %d hunter(s) sent after %s (visibility %d, bounty %d)\n", #oids, CreatureObject(pPlayer):getFirstName(), self:visibility(pPlayer), self:amount(pPlayer))
	return true
end

function FbBounty:ownerOf(pMob)
	local oid = tonumber(readData(SceneObject(pMob):getObjectID() .. ":fbBountyFor") or 0) or 0
	return oid ~= 0 and getSceneObject(oid) or nil
end

-- a hunter down: the last one sets the cooldown
function FbBounty:onHunterDown(pMob, pKiller)
	if pMob == nil then return 1 end
	local pPlayer = self:ownerOf(pMob)
	local mine = SceneObject(pMob):getObjectID()
	deleteData(mine .. ":fbBountyFor")
	printf("FbBounty: hunter %d down (owner %s)\n", mine, pPlayer ~= nil and CreatureObject(pPlayer):getFirstName() or "-")
	if pPlayer == nil then return 1 end
	-- the dying hunter still reads as alive at observer time: count the others
	local others = 0
	for _, p in ipairs(self:hunters(pPlayer)) do if SceneObject(p):getObjectID() ~= mine then others = others + 1 end end
	if others == 0 then
		removeQuestStatus(self:hunterKey(pPlayer))
		local cd = self:rank(pPlayer) >= 8 and self.masterCooldown or self.cooldown
		setFlag(pPlayer, "nextHuntAt", os.time() + cd)
		say(pPlayer, "squad_down")
		printf("FbBounty: %s's hunters are down; the next hunt in %d min\n", CreatureObject(pPlayer):getFirstName(), cd / 60)
	end
	return 1
end

function FbBounty:sweepHunter(pPlayer, args)
	local oid = tonumber(args)
	if oid == nil or oid == 0 then return end
	local p = getSceneObject(oid)
	if p == nil then return end
	deleteData(oid .. ":fbBountyFor")
	if SceneObject(p):getZoneName() ~= "" then
		SceneObject(p):destroyObjectFromWorld(true)
		SceneObject(p):destroyObjectFromDatabase()
	end
	if FbLabTests ~= nil and FbLabTests.registryRemove ~= nil then FbLabTests.registryRemove(oid) end
end

function FbBounty:despawnHunters(pPlayer)
	for oid in tostring(getQuestStatus(self:hunterKey(pPlayer)) or ""):gmatch("%d+") do self:sweepHunter(pPlayer, oid) end
	removeQuestStatus(self:hunterKey(pPlayer))
end

-- the character went down (FbAttunement's incapacitation / death observer): the hunters leave, the next hunt waits
function FbBounty:onPlayerDown(pPlayer)
	if pPlayer == nil or self:liveCount(pPlayer) == 0 then return end
	createEvent(60000, "FbBounty", "leave", pPlayer, "")
	setFlag(pPlayer, "nextHuntAt", os.time() + self.deathCooldown)
end
function FbBounty:leave(pPlayer) if pPlayer ~= nil then self:despawnHunters(pPlayer) end end

-- ---------------------------------------------------------------- the trigger

-- would a hunt start now? (the lab asks without starting one)
function FbBounty:due(pPlayer)
	if pPlayer == nil or not self:isActive(pPlayer) then return false, "no bounty" end
	if self:liveCount(pPlayer) > 0 then return false, "hunters out" end
	if num(pPlayer, "nextHuntAt") > os.time() then return false, "cooldown" end
	local c = CreatureObject(pPlayer)
	if c:isDead() or c:isIncapacitated() or c:isInCombat() then return false, "down or fighting" end
	if SceneObject(pPlayer):getParentID() ~= 0 then return false, "indoors" end
	return true, "due"
end

function FbBounty:maybe(pPlayer)
	if pPlayer == nil or not self:isJedi(pPlayer) then return false end
	self:updateAmount(pPlayer)
	local ok = self:due(pPlayer)
	if not ok then return false end
	return self:hunt(pPlayer)
end

-- the five-minute tick while the character is online (armed at login)
function FbBounty:tick(pPlayer)
	if pPlayer == nil or SceneObject(pPlayer):getZoneName() == "" then return end
	self:maybe(pPlayer)
	createEvent(self.tickMs, "FbBounty", "tick", pPlayer, "")
end

function FbBounty:onLogin(pPlayer)
	if pPlayer == nil or not self:isJedi(pPlayer) then return end
	createEvent(self.tickMs, "FbBounty", "tick", pPlayer, "")
end

-- ---------------------------------------------------------------- the fixer

function FbBounty:price(pPlayer) return math.floor(self:amount(pPlayer) * self.markup) end

-- the fixer's opening: no price on you / a price, and what it costs
function FbBounty:fixerScreen(pPlayer)
	if not self:isJedi(pPlayer) then return "nothing" end
	if self:isPaid(pPlayer) then return "paid" end          -- the price is 0 while the arrangement holds: he remembers
	if self:amount(pPlayer) == 0 then return "nothing" end
	return "offer"
end

function FbBounty:pay(pPlayer)
	local price = self:price(pPlayer)
	if price <= 0 then return false end
	if CreatureObject(pPlayer):getCashCredits() < price then say(pPlayer, "short"); return false end
	CreatureObject(pPlayer):subtractCashCredits(price)
	setFlag(pPlayer, "bounty", 0)
	setFlag(pPlayer, "bountyPaidUntil", os.time() + self.paidFor)
	self:despawnHunters(pPlayer)
	local msg = LuaStringIdChatParameter("@fb_force:bounty_paid"); msg:setDI(price)
	CreatureObject(pPlayer):sendSystemMessage(msg:_getObject())
	printf("FbBounty: %s pays %d to the fixer\n", CreatureObject(pPlayer):getFirstName(), price)
	return true
end

function FbBounty:spawnFixer()
	local f = self.fixer
	if not isZoneEnabled(f.zone) or f.buildingOid == 0 then return nil end
	local pBuilding = getSceneObject(f.buildingOid)
	if pBuilding == nil then printf("FbBounty: the fixer's cantina (%d) is missing\n", f.buildingOid); return nil end
	local pCell = BuildingObject(pBuilding):getNamedCell(f.room)
	if pCell == nil then printf("FbBounty: no room %s in %d\n", f.room, f.buildingOid); return nil end
	local pNpc = spawnMobile(f.zone, f.template, 0, f.x, f.z, f.y, math.rad(f.heading), SceneObject(pCell):getObjectID())
	if pNpc == nil then printf("FbBounty: spawnMobile %s failed\n", f.template); return nil end
	AiAgent(pNpc):addObjectFlag(AI_STATIC)
	CreatureObject(pNpc):clearOptionBit(AIENABLED)
	setQuestStatus("FbBounty.fixer", tostring(SceneObject(pNpc):getObjectID()))
	return pNpc
end

function FbBounty:fixerNpc()
	local oid = tonumber(getQuestStatus("FbBounty.fixer") or 0) or 0
	return oid ~= 0 and getSceneObject(oid) or nil
end

-- the status report's line
function FbBounty:statusLine(pPlayer)
	if not self:isJedi(pPlayer) then return nil end
	if self:isPaid(pPlayer) then return "@fb_force:bounty_status_paid" end
	if self:amount(pPlayer) == 0 then return nil end
	return "@fb_force:bounty_status_active"
end

function FbBounty:status(pPlayer)
	local ok, why = self:due(pPlayer)
	return string.format("jedi=%s visibility=%d bounty=%d price=%d paid=%s hunters=%d squad=%d tier=%s nextHuntIn=%d due=%s(%s) statusLine=%s",
		tostring(self:isJedi(pPlayer)), math.floor(self:visibility(pPlayer)), math.floor(self:amount(pPlayer)), math.floor(self:price(pPlayer)), tostring(self:isPaid(pPlayer)),
		self:liveCount(pPlayer), self:squadSize(pPlayer), self:tierFor(pPlayer), math.floor(math.max(0, num(pPlayer, "nextHuntAt") - os.time())), tostring(ok), why, tostring(self:statusLine(pPlayer) or "-"))
end

-- ---------------------------------------------------------------- boot

FbBountyScreenPlay = ScreenPlay:new { screenplayName = "FbBountyScreenPlay" }
registerScreenPlay("FbBountyScreenPlay", true)
function FbBountyScreenPlay:start() FbBounty:spawnFixer() end
