-- fb_loot_kits.lua — Phase 2.4: loot kits, the drops.
--
-- The quality ladder is in docs/Loot-Kits-Design.md (signed off 2026-10-26): kit gear tops out around two thirds of the
-- best crafted gear and every kit tier beats every shop. The kits and parts themselves are generated data
-- (custom_scripts/object/tangible/fb_kits/fb_kits.lua, custom_scripts/loot/items/fb_kits.lua): a kit is the stock Pre-CU
-- loot-kit object with the tier's parts as its components and a loot item as its reward (the engine addition
-- collectibleLootReward makes the finished piece through the loot manager, so it carries the tier's stats). Assembly is
-- the stock drag-and-drop into the kit; nothing here touches that.
--
-- This file is the drop roll: after every kill a player makes (FbAttunement:onKill → FbLootKits:onKill, 0.8 s later so
-- the corpse's own loot is there first), the victim's level picks the tier, parts fall from anything in the band, kits
-- only from humanoids, and a kit matches its source where the source has a look of its own (Tuskens bone and padded,
-- the Empire composite, the Nightsisters chitin). Lab: FbLabTests kits / kitGive / kitParts / kitAssemble / itemStats /
-- kitRoll, checkKits; scenario `loot-kits`.

FbLootKits = {
	-- level bands and chances in percent per kill (Loot-Kits-Design.md, Drops)
	tiers = {
		{ tier = 1, lo = 5,  hi = 25,  parts = 7, kits = 3   },
		{ tier = 2, lo = 26, hi = 55,  parts = 6, kits = 2.5 },
		{ tier = 3, lo = 56, hi = 999, parts = 5, kits = 2   },
	},
	weaponShare = 25,   -- % of kit drops (and of part drops) that are weapon rather than armor
	-- the armor sets a tier has (the generated groups fb_kits_<set>_<tier>)
	sets = { [1] = { "padded", "bone" }, [2] = { "composite", "ubese", "chitin" }, [3] = { "composite_adv" } },
	-- a source's own look: social group → the sets its kits come from (where the tier has them); anything else is the tier's pool
	sources = {
		tusken_raider = { "bone", "padded" }, janta = { "bone" }, kun = { "bone" }, mokk = { "bone" },
		imperial = { "composite", "composite_adv" }, stormtrooper = { "composite", "composite_adv" },
		rebel = { "composite", "padded", "composite_adv" },
		nightsister = { "chitin" }, singing_mountain_clan = { "chitin" },
		spice_collective = { "ubese" }, ubese = { "ubese" }, bh = { "ubese" }, blacksun = { "ubese", "composite_adv" },
	},
	delayMs = 800,
}

function FbLootKits:tierFor(level)
	for _, t in ipairs(self.tiers) do
		if level >= t.lo and level <= t.hi then return t end
	end
	return nil
end

-- the kit group for a tier and a source: one of the source's sets the tier has, else the tier's whole pool
function FbLootKits:kitGroup(t, social)
	if getRandomNumber(100) <= self.weaponShare then return "fb_kits_weapon_" .. t.tier end
	local wanted = self.sources[tostring(social or ""):lower()]
	if wanted ~= nil then
		local have = {}
		for _, s in ipairs(wanted) do
			for _, ts in ipairs(self.sets[t.tier]) do if ts == s then have[#have + 1] = s end end
		end
		if #have > 0 then return "fb_kits_" .. have[getRandomNumber(#have)] .. "_" .. t.tier end
	end
	return "fb_kits_" .. t.tier
end

function FbLootKits:partsGroup(t)
	return "fb_kit_parts_" .. (getRandomNumber(100) <= self.weaponShare and "weapon" or "armor") .. "_" .. t.tier
end

-- the roll into a container: returns "parts=<group or ->,kit=<group or ->"
function FbLootKits:roll(pContainer, level, humanoid, social, force)
	local t = self:tierFor(tonumber(level) or 0)
	if t == nil or pContainer == nil then return "parts=-,kit=- (no tier for level " .. tostring(level) .. ")" end
	local parts, kit = "-", "-"
	if force or getRandomNumber(1000) <= t.parts * 10 then
		parts = self:partsGroup(t)
		createLoot(pContainer, parts, tonumber(level) or 10, false)
	end
	if humanoid and (force or getRandomNumber(1000) <= t.kits * 10) then
		kit = self:kitGroup(t, social)
		createLoot(pContainer, kit, tonumber(level) or 10, false)
	end
	return "parts=" .. parts .. ",kit=" .. kit
end

-- from FbAttunement:onKill: a moment later, so the corpse's own loot is already there
function FbLootKits:onKill(pPlayer, pVictim)
	if pPlayer == nil or pVictim == nil or not SceneObject(pVictim):isCreatureObject() then return end
	if SceneObject(pVictim):isPlayerCreature() then return end
	local level = CreatureObject(pVictim):getLevel()
	local humanoid = not AiAgent(pVictim):isCreature()
	local social = AiAgent(pVictim):getSocialGroup() or ""
	createEvent(self.delayMs, "FbLootKits", "drop", pVictim, string.format("%d:%d:%s", level, humanoid and 1 or 0, social))
end

function FbLootKits:drop(pVictim, args)
	if pVictim == nil then return end
	local level, humanoid, social = tostring(args):match("^(%d+):(%d):(.*)$")
	if level == nil then return end
	local pInventory = SceneObject(pVictim):getSlottedObject("inventory")
	if pInventory == nil then return end
	local what = self:roll(pInventory, tonumber(level), humanoid == "1", social, false)
	if what ~= "parts=-,kit=-" then printf("FbLootKits: level %s %s (%s) drops %s\n", level, humanoid == "1" and "humanoid" or "creature", social, what) end
end
