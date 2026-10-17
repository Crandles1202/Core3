-- fb_parts_dealer.lua — Phase 2.3: component vendor NPC (Mos Eisley starport).
--
-- Sells the crafting sub-components a solo crafter would otherwise need a second profession (or a
-- lucky drop) for: weapon parts, armor segments, chemistry parts. Each sale is generated through the
-- loot system (createLoot with a component_loot item name), so the part gets real crafting values
-- rolled at the listed level — a "standard" part rolls at level 30, an "advanced" one at level 60.
-- Prices sit above what a player crafter would ask (roadmap Phase 2 rule).
--
-- Flow (same as FbSchematicBroker): converse -> "Show me the parts" -> SUI category -> SUI item ->
-- FbPartsDealer:purchase(pPlayer, catIdx, itemIdx). purchase() is public for the lab.

FbPartsDealer = ScreenPlay:new {
	screenplayName = "FbPartsDealer",
	spawns = {
		{ planet = "tatooine", label = "Mos Eisley Starport", x = 3535, z = 5, y = -4818, dir = 1 },
	},
}

FbPartsDealer.STANDARD_LEVEL = 30
FbPartsDealer.ADVANCED_LEVEL = 60

-- loot = component_loot item name (scripts/loot/items/component_loot/<loot>.lua); the advanced row
-- uses "<loot>_advanced" and ADVANCED_LEVEL.
local function part(name, loot, price)
	return {
		{ name = name,                 loot = loot,               level = FbPartsDealer.STANDARD_LEVEL, price = price },
		{ name = name .. " (advanced)", loot = loot .. "_advanced", level = FbPartsDealer.ADVANCED_LEVEL, price = price * 3 },
	}
end

local function rows(...)
	local out = {}
	for _, pair in ipairs({ ... }) do out[#out + 1] = pair[1]; out[#out + 1] = pair[2] end
	return out
end

FbPartsDealer.categories = {
	{ name = "Weapon parts", items = rows(
		part("Blaster Power Handler",     "blaster_power_handler",     1500),
		part("Blaster Pistol Barrel",     "blaster_pistol_barrel",     1500),
		part("Blaster Rifle Barrel",      "blaster_rifle_barrel",      1500),
		part("Projectile Pistol Barrel",  "projectile_pistol_barrel",  1500),
		part("Projectile Rifle Barrel",   "projectile_rifle_barrel",   1500),
		part("Projectile Feed Mechanism", "projectile_feed_mechanism", 1500),
		part("Weapon Stock",              "stock",                     1200),
		part("Weapon Scope",              "scope_weapon",              1200),
		part("Vibro Unit",                "vibro_unit",                1500),
		part("Sword Core",                "sword_core",                1500),
		part("Reinforcement Core",        "reinforcement_core",        1500)
	)},
	{ name = "Armor segments", items = rows(
		part("Bone Armor Segment",       "armor_segment_bone",      2000),
		part("Chitin Armor Segment",     "armor_segment_chitin",    2000),
		part("Padded Armor Segment",     "armor_segment_padded",    2500),
		part("Ubese Armor Segment",      "armor_segment_ubese",     3000),
		part("Composite Armor Segment",  "armor_segment_composite", 4000)
	)},
	{ name = "Chemistry parts", items = rows(
		part("Biologic Effect Controller",  "biologic_effect_controller",  1200),
		part("Dispersal Mechanism",         "dispersal_mechanism",         1200),
		part("Infection Amplifier",         "infection_amplifier",         1200),
		part("Liquid Delivery Suspension",  "liquid_delivery_suspension",  1200),
		part("Release Mechanism",           "release_mechanism_duration",  1200),
		part("Resilience Compound",         "resilience_compound",         1200),
		part("Solid Delivery Shell",        "solid_delivery_shell",        1200)
	)},
}

registerScreenPlay("FbPartsDealer", true)

function FbPartsDealer:start()
	for _, spawn in ipairs(self.spawns) do
		if isZoneEnabled(spawn.planet) then
			spawnMobile(spawn.planet, "fb_parts_dealer", 0,
				spawn.x, spawn.z, spawn.y, spawn.dir, spawn.cellID or 0)
		end
	end
	printf("FbPartsDealer: spawned\n")
end

-- purchase(pPlayer, catIdx, itemIdx) -> "ok" | "no_credits" | "inventory_full" | "bad_item" | "failed"
function FbPartsDealer:purchase(pPlayer, catIdx, itemIdx)
	if pPlayer == nil then return "failed" end
	local cat = self.categories[catIdx]
	if cat == nil then return "bad_item" end
	local item = cat.items[itemIdx]
	if item == nil then return "bad_item" end

	local creature = CreatureObject(pPlayer)
	if creature:getCashCredits() < item.price then
		creature:sendSystemMessage("Not enough cash for a " .. item.name .. ". Need " .. item.price .. " cr.")
		return "no_credits"
	end

	local pInventory = creature:getSlottedObject("inventory")
	if pInventory == nil or SceneObject(pInventory):isContainerFullRecursive() then
		creature:sendSystemMessage("Your inventory is full.")
		return "inventory_full"
	end

	local oid = createLoot(pInventory, item.loot, item.level, false)
	if oid == nil or oid == 0 then
		creature:sendSystemMessage("The dealer rummages in the crate and comes up empty. (" .. item.loot .. " could not be generated)")
		return "failed"
	end

	creature:subtractCashCredits(item.price)
	creature:sendSystemMessage("Purchased a " .. item.name .. " for " .. item.price .. " credits.")
	return "ok"
end

-- ---- SUI plumbing ----------------------------------------------------------------------------

function FbPartsDealer:showParts(pPlayer, pNpc)
	if pPlayer == nil then return end
	local pSui = SuiListBox.new("FbPartsDealer", "onCategoryPicked")
	pSui.setTitle("Parts Dealer")
	pSui.setPrompt("Crafting sub-components, rolled fresh. Standard parts or advanced (better rolls, three times the price). Cash only, no refunds.")
	for i = 1, #self.categories do
		local cat = self.categories[i]
		pSui.add(cat.name .. "  (" .. #cat.items .. " parts)", "")
	end
	pSui.sendTo(pPlayer)
end

function FbPartsDealer:onCategoryPicked(pPlayer, pSui, eventIndex, args)
	if pPlayer == nil or eventIndex == 1 then return end
	local catIdx = tonumber(args)
	if catIdx == nil then return end
	catIdx = catIdx + 1
	local cat = self.categories[catIdx]
	if cat == nil then return end

	local pInner = SuiListBox.new("FbPartsDealer", "onItemPickedCat" .. catIdx)
	pInner.setTitle(cat.name)
	pInner.setPrompt("Pick a part:")
	for i = 1, #cat.items do
		local it = cat.items[i]
		pInner.add("[" .. it.price .. " cr] " .. it.name, "")
	end
	pInner.sendTo(pPlayer)
end

for i = 1, #FbPartsDealer.categories do
	local catIdx = i
	FbPartsDealer["onItemPickedCat" .. catIdx] = function(self, pPlayer, pSui, eventIndex, args)
		if pPlayer == nil or eventIndex == 1 then return end
		local idx = tonumber(args)
		if idx == nil then return end
		FbPartsDealer:purchase(pPlayer, catIdx, idx + 1)
	end
end
