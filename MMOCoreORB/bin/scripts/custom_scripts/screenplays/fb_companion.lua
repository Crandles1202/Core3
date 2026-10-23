-- fb_companion.lua — Phase 4b.5: the companion Padawan / Apprentice.
--
-- A Knight (4b.4) is offered a student of their own by their Master: Mirren Solas on the light side, Ryka Dathe on
-- the dark. The companion is a stock hireling pet — a control device in the datapad (giveControlDevice, the GCW
-- recruiters' machinery), called and stored like any pet, following, surviving logout, crossing zones — with a
-- named NPC of ours in it. What makes it a character lives here: a voice (idle lines, a word when a fight starts,
-- when something dies, when you go down, at a shrine), it defends you (a DAMAGERECEIVED observer on the player sets
-- it on the attacker), and it grows: three stages, each a stronger template, reached by kills made with it out.
--
-- Light capstone: at the third stage Master Venn offers the Padawan's trials — three shrines of any world with
-- the Padawan beside you and alive at each (the attunement shrine hook). The report is the knighting: the Padawan
-- leaves for good, you keep a robe with their name on it and Master Venn calls you Master from then on.
--
-- Dark path: at any time Darth Vhal lets you betray the apprentice — it dies, you gain a permanent 100 to each
-- base pool and lean 20 darker. Train them fully instead and from the third stage each day carries a growing
-- chance (5 % per day, capped at 50) of their turn: the apprentice walks out of the datapad as an enemy and hunts
-- you. Beat them: slain, 5 darker. Lose: they take a quarter of the cash you carry and you are "the former master"
-- in Darth Vhal's mouth and in /checkForceStatus from then on (Chuck's call 2026-10-23: cash and a title, not
-- the inventory). Run: they vanish and come again at a later tick.
--
-- State is per-player screenplay data (FbCompanion:<key>): side, state (active / trial / knighted / betrayed /
-- turned / hunted / former / slain), stage, kills, device (oid), fullAt, turnedOid, lastRoll, trialShrines.
-- Lab: FbLabTests companion*, checkCompanion; scenario `companion`.

FbCompanion = {
	DATA = "FbCompanion",
	device = "object/intangible/pet/pet_control.iff",
	stageKills = { 0, 20, 50 },          -- kills with the companion out: stage 2 at 20, stage 3 at 50
	nearRange = 80,                      -- m: a kill counts when the companion stands this close
	idleMs = 4 * 60 * 1000,              -- the idle tick while online
	idleChance = 40,                     -- % of ticks the companion says something, when out and not fighting
	fightCooldown = 60,                  -- s between fight lines
	turnBase = 5, turnCap = 50,          -- % per day since the third stage, capped
	turnWindow = 10 * 60,                -- s a turned apprentice hunts before vanishing
	cashCut = 0.25,                      -- the lost fight's price
	betrayBonus = 100,                   -- permanent base pool bonus for the betrayal
	trialShrinesNeeded = 3,
	sides = {
		light = { name = "Mirren Solas", prefix = "light", master = "master", stages = { "fb_companion_light_1", "fb_companion_light_2", "fb_companion_light_3" },
			robe = "object/tangible/wearables/robe/robe_jedi_light_s01.iff", music = "sound/music_become_light_jedi.snd", idle = 4, fight = 3, kill = 3 },
		dark = { name = "Ryka Dathe", prefix = "dark", master = "sith", stages = { "fb_companion_dark_1", "fb_companion_dark_2", "fb_companion_dark_3" },
			turned = "fb_companion_dark_turned", idle = 4, fight = 3, kill = 3 },
	},
}

-- ---------------------------------------------------------------- data

function FbCompanion:get(pPlayer, k) local v = readScreenPlayData(pPlayer, self.DATA, k); if v == nil or v == "" then return nil end; return v end
function FbCompanion:set(pPlayer, k, v) writeScreenPlayData(pPlayer, self.DATA, k, tostring(v)) end
function FbCompanion:clear(pPlayer, k) deleteScreenPlayData(pPlayer, self.DATA, k) end
function FbCompanion:num(pPlayer, k) return tonumber(self:get(pPlayer, k) or 0) or 0 end
function FbCompanion:state(pPlayer) return self:get(pPlayer, "state") end
function FbCompanion:sideOf(pPlayer) local s = self:get(pPlayer, "side"); return s, s and self.sides[s] or nil end

local function say(pPlayer, id) CreatureObject(pPlayer):sendSystemMessage("@fb_force:comp_" .. id) end
local function sayN(pPlayer, id, n)
	local msg = LuaStringIdChatParameter("@fb_force:comp_" .. id); msg:setDI(n)
	CreatureObject(pPlayer):sendSystemMessage(msg:_getObject())
end
local function dist(pA, pB)
	local a, b = SceneObject(pA), nil
	local ax, ay = a:getWorldPositionX(), a:getWorldPositionY()
	b = SceneObject(pB)
	local dx, dy = ax - b:getWorldPositionX(), ay - b:getWorldPositionY()
	return math.sqrt(dx * dx + dy * dy)
end

-- the Knight of a side whose Master this is
function FbCompanion:eligible(pPlayer, m)
	if pPlayer == nil or FbAttunement == nil or m == nil then return false end
	if FbAttunement:flag(pPlayer, "knight") == nil then return false end
	return FbAttunement:flag(pPlayer, "master") == m.side
end

-- ---------------------------------------------------------------- the device and the pet

function FbCompanion:deviceOf(pPlayer)
	local oid = self:num(pPlayer, "device")
	if oid == 0 then return nil end
	return getSceneObject(oid)
end
function FbCompanion:petOf(pPlayer)
	local pDevice = self:deviceOf(pPlayer)
	if pDevice == nil then return nil end
	return getControlledObject(pDevice)
end
-- out: in a zone (a stored pet has none), alive
function FbCompanion:isOut(pPlayer)
	local pPet = self:petOf(pPlayer)
	if pPet == nil then return false, nil end
	if SceneObject(pPet):getZoneName() == "" then return false, pPet end
	if CreatureObject(pPet):isDead() then return false, pPet end
	return true, pPet
end
function FbCompanion:petNear(pPlayer)
	local out, pPet = self:isOut(pPlayer)
	if not out then return false, pPet end
	return dist(pPlayer, pPet) <= self.nearRange, pPet
end

function FbCompanion:call(pPlayer)
	local pDevice = self:deviceOf(pPlayer)
	if pDevice == nil then return false end
	return callControlDevice(pDevice, pPlayer)
end
function FbCompanion:store(pPlayer)
	local pDevice = self:deviceOf(pPlayer)
	if pDevice == nil then return false end
	return storeControlDevice(pDevice, pPlayer)
end

-- the device and its creature gone for good
function FbCompanion:removeDevice(pPlayer)
	local pDevice = self:deviceOf(pPlayer)
	if pDevice == nil then self:clear(pPlayer, "device"); return end
	local pPet = getControlledObject(pDevice)
	if pPet ~= nil and SceneObject(pPet):getZoneName() ~= "" then storeControlDevice(pDevice, pPlayer) end
	pPet = getControlledObject(pDevice)
	-- a pet the store did not take out of the world goes first; the device's database destroy takes its creature with it
	if pPet ~= nil and SceneObject(pPet):getZoneName() ~= "" then SceneObject(pPet):destroyObjectFromWorld(true) end
	SceneObject(pDevice):destroyObjectFromWorld(true)
	SceneObject(pDevice):destroyObjectFromDatabase()
	self:clear(pPlayer, "device")
end

-- a device of the stage's template in the datapad, named, called out
function FbCompanion:makeDevice(pPlayer, side, stage)
	local d = self.sides[side]
	local pDatapad = SceneObject(pPlayer):getSlottedObject("datapad")
	if pDatapad == nil then return nil end
	local pDevice = giveControlDevice(pDatapad, self.device, d.stages[stage], -1, true)
	if pDevice == nil then return nil end
	SceneObject(pDevice):setCustomObjectName(d.name)
	self:set(pPlayer, "device", SceneObject(pDevice):getObjectID())
	self:set(pPlayer, "stage", stage)
	callControlDevice(pDevice, pPlayer)
	return pDevice
end

-- ---------------------------------------------------------------- the Master's screens

function FbCompanion:screenFor(pPlayer, m)
	if not self:eligible(pPlayer, m) then return nil end
	local s = self:state(pPlayer)
	local side = m.side
	if s == nil then return "comp_offer" end
	if self:get(pPlayer, "side") ~= side then return nil end
	if s == "active" then
		if side == "light" then
			if self:num(pPlayer, "stage") >= 3 then return "comp_trial_offer" end
			return "comp_has"
		end
		return "comp_dark_has"
	end
	if s == "trial" then
		if self:trialCount(pPlayer) >= self.trialShrinesNeeded then return "comp_trial_report" end
		return "comp_trial_wait"
	end
	if s == "knighted" then return "comp_knighted_after" end
	if s == "betrayed" then return "comp_betrayed_after" end
	if s == "turned" or s == "hunted" then return "comp_turned_wait" end
	if s == "former" then return "comp_former_after" end
	if s == "slain" then return "comp_slain_after" end
	return nil
end

-- "I will take them": the first stage, out at once
function FbCompanion:give(pPlayer)
	if pPlayer == nil or FbAttunement == nil then return false end
	local side = FbAttunement:flag(pPlayer, "master")
	local m = FbMasters ~= nil and FbMasters.of(pPlayer) or nil
	if side == nil or self.sides[side] == nil or not self:eligible(pPlayer, m) or self:state(pPlayer) ~= nil then return false end
	self:set(pPlayer, "side", side)
	self:set(pPlayer, "state", "active")
	self:set(pPlayer, "kills", 0)
	local pDevice = self:makeDevice(pPlayer, side, 1)
	if pDevice == nil then self:clear(pPlayer, "state"); self:clear(pPlayer, "side"); return false end
	say(pPlayer, side .. "_given")
	self:armDefence(pPlayer)
	self:armIdle(pPlayer)
	printf("FbCompanion: %s takes %s (%s)\n", CreatureObject(pPlayer):getFirstName(), self.sides[side].name, side)
	return true
end

-- ---------------------------------------------------------------- growing

function FbCompanion:credit(pPlayer, n)
	local kills = self:num(pPlayer, "kills") + (n or 1)
	self:set(pPlayer, "kills", kills)
	local stage = self:num(pPlayer, "stage")
	local _, d = self:sideOf(pPlayer)
	if d ~= nil and stage < 3 and kills >= self.stageKills[stage + 1] then self:advance(pPlayer, stage + 1) end
	return kills
end

function FbCompanion:advance(pPlayer, stage)
	local side, d = self:sideOf(pPlayer)
	if d == nil or stage > #d.stages then return false end
	self:removeDevice(pPlayer)
	if self:makeDevice(pPlayer, side, stage) == nil then return false end
	say(pPlayer, side .. "_stage" .. stage)
	if stage == 3 then self:set(pPlayer, "fullAt", os.time()); self:set(pPlayer, "lastRoll", os.date("%Y%m%d")) end
	printf("FbCompanion: %s's %s reaches stage %d\n", CreatureObject(pPlayer):getFirstName(), d.name, stage)
	return true
end

-- ---------------------------------------------------------------- the voice and the fights

function FbCompanion:speak(pPlayer, kind, count)
	local side, d = self:sideOf(pPlayer)
	local out, pPet = self:isOut(pPlayer)
	if not out or d == nil then return false end
	spatialChat(pPet, "@fb_force:comp_" .. side .. "_" .. kind .. "_" .. getRandomNumber(count or 1))
	return true
end

-- DAMAGERECEIVED on the player: the companion goes for the attacker
function FbCompanion:onDamage(pPlayer, pAttacker, damage)
	if pPlayer == nil or pAttacker == nil or self:state(pPlayer) ~= "active" then return 0 end
	local near, pPet = self:petNear(pPlayer)
	if not near or pPet == nil then return 0 end
	if not SceneObject(pAttacker):isCreatureObject() or SceneObject(pAttacker):getObjectID() == SceneObject(pPet):getObjectID() then return 0 end
	if not CreatureObject(pPet):isInCombat() then
		AiAgent(pPet):setDefender(pAttacker)
		local last = self:num(pPlayer, "fightAt")
		if os.time() - last >= self.fightCooldown then
			self:set(pPlayer, "fightAt", os.time())
			local _, d = self:sideOf(pPlayer)
			self:speak(pPlayer, "fight", d.fight)
		end
	end
	return 0
end

-- from FbAttunement:onKill
function FbCompanion:onKill(pPlayer, pVictim)
	if pPlayer == nil then return end
	local s = self:state(pPlayer)
	if (s == "turned") and pVictim ~= nil and SceneObject(pVictim):getObjectID() == self:num(pPlayer, "turnedOid") then
		self:resolveTurn(pPlayer, "slain")
		return
	end
	if s ~= "active" then return end
	local near = self:petNear(pPlayer)
	if not near then return end
	local kills = self:credit(pPlayer, 1)
	if kills % 5 == 0 then local _, d = self:sideOf(pPlayer); self:speak(pPlayer, "kill", d.kill) end
end

-- from FbAttunement:onIncap (OBJECTDESTRUCTION on the player: incapacitated or dead)
function FbCompanion:onIncap(pPlayer, pAttacker)
	if pPlayer == nil then return end
	local s = self:state(pPlayer)
	if s == "turned" and pAttacker ~= nil and SceneObject(pAttacker):getObjectID() == self:num(pPlayer, "turnedOid") then
		self:resolveTurn(pPlayer, "lost")
		return
	end
	if s == "active" then self:speak(pPlayer, "down", 1) end
end

-- from FbAttunement:onEnterArea (a shrine): the Padawan's trials
function FbCompanion:onShrine(pPlayer, key)
	if pPlayer == nil or self:state(pPlayer) ~= "trial" then return end
	local near = self:petNear(pPlayer)
	if not near then return end
	local have = self:get(pPlayer, "trialShrines") or ""
	for k in have:gmatch("[^,]+") do if k == key then return end end
	have = have == "" and key or (have .. "," .. key)
	self:set(pPlayer, "trialShrines", have)
	local n = self:trialCount(pPlayer)
	self:speak(pPlayer, "shrine", 1)
	if n >= self.trialShrinesNeeded then say(pPlayer, "light_trial_ready") else sayN(pPlayer, "light_trial_shrine", n) end
end
function FbCompanion:trialCount(pPlayer)
	local n = 0
	for _ in (self:get(pPlayer, "trialShrines") or ""):gmatch("[^,]+") do n = n + 1 end
	return n
end

-- the idle tick: the voice, and the dark turn's daily roll
function FbCompanion:armIdle(pPlayer)
	local gen = self:num(pPlayer, "idleGen") + 1
	self:set(pPlayer, "idleGen", gen)
	createEvent(self.idleMs, "FbCompanion", "idleTick", pPlayer, tostring(gen))
end
function FbCompanion:idleTick(pPlayer, args)
	if pPlayer == nil or tonumber(args) ~= self:num(pPlayer, "idleGen") then return end
	if SceneObject(pPlayer):getZoneName() == "" then return end   -- logged out: onLogin re-arms
	self:maybeTurn(pPlayer)
	if self:state(pPlayer) == "active" then
		local out, pPet = self:isOut(pPlayer)
		if out and not CreatureObject(pPet):isInCombat() and not CreatureObject(pPlayer):isInCombat() and getRandomNumber(100) <= self.idleChance then
			local _, d = self:sideOf(pPlayer)
			self:speak(pPlayer, "idle", d.idle)
		end
	end
	createEvent(self.idleMs, "FbCompanion", "idleTick", pPlayer, args)
end
function FbCompanion:armDefence(pPlayer)
	dropObserver(DAMAGERECEIVED, "FbCompanion", "onDamage", pPlayer)
	createObserver(DAMAGERECEIVED, "FbCompanion", "onDamage", pPlayer)
end

-- ---------------------------------------------------------------- the light capstone

function FbCompanion:trialGive(pPlayer)
	if self:state(pPlayer) ~= "active" or self:get(pPlayer, "side") ~= "light" or self:num(pPlayer, "stage") < 3 then return false end
	self:set(pPlayer, "state", "trial")
	self:set(pPlayer, "trialShrines", "")
	say(pPlayer, "light_trial_given")
	return true
end

function FbCompanion:knight(pPlayer)
	if self:state(pPlayer) ~= "trial" or self:trialCount(pPlayer) < self.trialShrinesNeeded then return false end
	local side, d = self:sideOf(pPlayer)
	local out = self:isOut(pPlayer)
	if out then self:speak(pPlayer, "farewell", 1) end
	self:removeDevice(pPlayer)
	local pInventory = SceneObject(pPlayer):getSlottedObject("inventory")
	if pInventory ~= nil then
		local pRobe = giveItem(pInventory, d.robe, -1)
		if pRobe ~= nil then SceneObject(pRobe):setCustomObjectName(d.name .. "'s robe") end
	end
	CreatureObject(pPlayer):playMusicMessage(d.music)
	self:set(pPlayer, "state", "knighted")
	if FbAlignment ~= nil then FbAlignment:shift(pPlayer, 10, "padawan knighted") end
	say(pPlayer, "light_knighted")
	printf("FbCompanion: %s's Padawan %s is knighted\n", CreatureObject(pPlayer):getFirstName(), d.name)
	return true
end

-- ---------------------------------------------------------------- the dark paths

function FbCompanion:betray(pPlayer)
	if self:state(pPlayer) ~= "active" or self:get(pPlayer, "side") ~= "dark" then return false end
	local _, d = self:sideOf(pPlayer)
	if not self:isOut(pPlayer) then self:call(pPlayer) end
	self:speak(pPlayer, "betray_last", 1)
	self:removeDevice(pPlayer)
	for _, pool in ipairs({ 0, 3, 6 }) do
		CreatureObject(pPlayer):setBaseHAM(pool, CreatureObject(pPlayer):getBaseHAM(pool) + self.betrayBonus)
		CreatureObject(pPlayer):setMaxHAM(pool, CreatureObject(pPlayer):getMaxHAM(pool) + self.betrayBonus)
	end
	self:set(pPlayer, "state", "betrayed")
	if FbAlignment ~= nil then FbAlignment:shift(pPlayer, -20, "betrayed the apprentice") end
	say(pPlayer, "dark_betrayed")
	printf("FbCompanion: %s betrays %s\n", CreatureObject(pPlayer):getFirstName(), d.name)
	return true
end

-- the daily roll from the third stage on; a hunted character gets the apprentice again at the next tick outdoors
function FbCompanion:maybeTurn(pPlayer)
	local s = self:state(pPlayer)
	if s == "hunted" then self:turn(pPlayer); return end
	if s ~= "active" or self:get(pPlayer, "side") ~= "dark" or self:num(pPlayer, "stage") < 3 then return end
	local day = os.date("%Y%m%d")
	if self:get(pPlayer, "lastRoll") == day then return end
	self:set(pPlayer, "lastRoll", day)
	local days = math.floor((os.time() - self:num(pPlayer, "fullAt")) / 86400)
	local chance = math.min(self.turnCap, self.turnBase * days)
	if chance > 0 and getRandomNumber(100) <= chance then self:turn(pPlayer) end
end

-- the apprentice out of the datapad as an enemy, beside the character, on them
function FbCompanion:turn(pPlayer)
	local s = self:state(pPlayer)
	if (s ~= "active" and s ~= "hunted") or self:get(pPlayer, "side") ~= "dark" then return false end
	local so = SceneObject(pPlayer)
	local zone = so:getZoneName()
	if zone == "" or so:getParentID() ~= 0 then self:set(pPlayer, "state", "hunted"); return false end   -- indoors: later
	local _, d = self:sideOf(pPlayer)
	if s == "active" then self:removeDevice(pPlayer) end
	local px, py, pz = so:getWorldPositionX(), so:getWorldPositionY(), so:getWorldPositionZ()
	local a = math.rad(getRandomNumber(360))
	local x, y = px + 8 * math.cos(a), py + 8 * math.sin(a)
	local pMob = spawnMobile(zone, d.turned, 0, x, getTerrainHeightAt(zone, x, y), y, 0, 0)
	if pMob == nil then self:set(pPlayer, "state", "hunted"); return false end
	local oid = SceneObject(pMob):getObjectID()
	AiAgent(pMob):setHomeLocation(px, pz, py, nil)
	AiAgent(pMob):setDefender(pPlayer)
	writeData(oid .. ":fbCompanionOf", so:getObjectID())
	createObserver(OBJECTDESTRUCTION, "FbCompanion", "onTurnedDown", pMob)
	self:set(pPlayer, "state", "turned")
	self:set(pPlayer, "turnedOid", oid)
	self:set(pPlayer, "turnedAt", os.time())
	spatialChat(pMob, "@fb_force:comp_dark_turn_1")
	say(pPlayer, "dark_turned")
	createEvent(self.turnWindow * 1000, "FbCompanion", "sweepTurned", pPlayer, tostring(oid))
	printf("FbCompanion: %s turns on %s\n", d.name, CreatureObject(pPlayer):getFirstName())
	return true
end

-- OBJECTDESTRUCTION on the turned apprentice: whoever finished her, the master is rid of her
function FbCompanion:onTurnedDown(pMob, pKiller)
	if pMob == nil then return 1 end
	local pPlayer = getSceneObject(readData(SceneObject(pMob):getObjectID() .. ":fbCompanionOf"))
	deleteData(SceneObject(pMob):getObjectID() .. ":fbCompanionOf")
	if pPlayer ~= nil and self:state(pPlayer) == "turned" and SceneObject(pMob):getObjectID() == self:num(pPlayer, "turnedOid") then
		self:resolveTurn(pPlayer, "slain")
		createEvent(8000, "FbCompanion", "sweepCorpse", pPlayer, tostring(SceneObject(pMob):getObjectID()))
	end
	return 1
end
function FbCompanion:sweepCorpse(pPlayer, args)
	local pMob = getSceneObject(tonumber(args) or 0)
	if pMob ~= nil then SceneObject(pMob):destroyObjectFromWorld(true); SceneObject(pMob):destroyObjectFromDatabase() end
end

function FbCompanion:turnedOf(pPlayer)
	local oid = self:num(pPlayer, "turnedOid")
	if oid == 0 then return nil end
	return getSceneObject(oid)
end

function FbCompanion:despawnTurned(pPlayer)
	local pMob = self:turnedOf(pPlayer)
	if pMob ~= nil then SceneObject(pMob):destroyObjectFromWorld(true); SceneObject(pMob):destroyObjectFromDatabase() end
	self:clear(pPlayer, "turnedOid")
end

-- the hunt's end: lost (a quarter of the cash, the former master), slain (5 darker)
function FbCompanion:resolveTurn(pPlayer, how)
	if self:state(pPlayer) ~= "turned" then return false end
	local _, d = self:sideOf(pPlayer)
	if how == "lost" then
		local cash = CreatureObject(pPlayer):getCashCredits()
		local cut = math.floor(cash * self.cashCut)
		if cut > 0 then CreatureObject(pPlayer):subtractCashCredits(cut) end
		local pMob = self:turnedOf(pPlayer)
		if pMob ~= nil then spatialChat(pMob, "@fb_force:comp_dark_win_1") end
		self:set(pPlayer, "state", "former")
		if FbAttunement ~= nil then FbAttunement:setFlag(pPlayer, "formerMaster", os.time()) end
		sayN(pPlayer, "dark_lost", cut)
		createEvent(8000, "FbCompanion", "sweepTurned", pPlayer, tostring(self:num(pPlayer, "turnedOid")))
		printf("FbCompanion: %s loses to %s: %d credits\n", CreatureObject(pPlayer):getFirstName(), d.name, cut)
	else
		self:set(pPlayer, "state", "slain")
		self:clear(pPlayer, "turnedOid")
		if FbAlignment ~= nil then FbAlignment:shift(pPlayer, -5, "slew the apprentice") end
		say(pPlayer, "dark_slain")
		printf("FbCompanion: %s slays the turned %s\n", CreatureObject(pPlayer):getFirstName(), d.name)
	end
	return true
end

-- the window closed: a hunting apprentice vanishes and comes again later; a beaten one is cleared away
function FbCompanion:sweepTurned(pPlayer, args)
	if pPlayer == nil or tonumber(args) ~= self:num(pPlayer, "turnedOid") then return end
	local s = self:state(pPlayer)
	self:despawnTurned(pPlayer)
	if s == "turned" then self:set(pPlayer, "state", "hunted"); say(pPlayer, "dark_escaped") end
end

-- ---------------------------------------------------------------- status, login, reset

function FbCompanion:statusLine(pPlayer)
	local s = self:state(pPlayer)
	if s == nil then return nil end
	local side = self:get(pPlayer, "side") or "light"
	if s == "active" or s == "trial" then return "@fb_force:comp_status_" .. side end
	if s == "turned" or s == "hunted" then return "@fb_force:comp_status_hunted" end
	return "@fb_force:comp_status_" .. s
end

function FbCompanion:onLogin(pPlayer)
	if pPlayer == nil or self:state(pPlayer) == nil then return end
	self:armDefence(pPlayer)
	self:armIdle(pPlayer)
end

function FbCompanion:reset(pPlayer)
	if pPlayer == nil then return end
	if self:get(pPlayer, "device") ~= nil then self:removeDevice(pPlayer) end
	self:despawnTurned(pPlayer)
	dropObserver(DAMAGERECEIVED, "FbCompanion", "onDamage", pPlayer)
	for _, k in ipairs({ "side", "state", "stage", "kills", "device", "fullAt", "turnedOid", "turnedAt", "lastRoll", "trialShrines", "fightAt", "idleGen" }) do self:clear(pPlayer, k) end
	if FbAttunement ~= nil then deleteScreenPlayData(pPlayer, FbAttunement.DATA, "flag:formerMaster") end
end

function FbCompanion:status(pPlayer)
	local out, pPet = self:isOut(pPlayer)
	local near = out and (dist(pPlayer, pPet) <= self.nearRange) or false
	local pDevice = self:deviceOf(pPlayer)
	local pTurned = self:turnedOf(pPlayer)
	return string.format("side=%s state=%s stage=%d kills=%d device=%s pet=%s out=%s near=%s petLevel=%s trial=%d turned=%s turnedAlive=%s former=%s",
		tostring(self:get(pPlayer, "side") or "-"), tostring(self:state(pPlayer) or "-"), self:num(pPlayer, "stage"), self:num(pPlayer, "kills"),
		pDevice and tostring(SceneObject(pDevice):getObjectID()) or "-", pPet and tostring(SceneObject(pPet):getObjectID()) or "-", tostring(out), tostring(near),
		pPet and tostring(CreatureObject(pPet):getLevel()) or "-", self:trialCount(pPlayer), pTurned and tostring(SceneObject(pTurned):getObjectID()) or "-",
		pTurned and tostring(not CreatureObject(pTurned):isDead()) or "-", tostring(FbAttunement ~= nil and FbAttunement:flag(pPlayer, "formerMaster") ~= nil))
end
