-- fb_combat_quartermaster.screenplay.lua  — Quartermaster Sehrev screenplay.
-- Full Combat Medic-profession inventory in two-level submenu UX.
-- Phase 2.9 — comprehensive combat goods expansion.
--
-- Categories (Combat Medic side):
--   1. Damage Packs               — single-target HAM damage
--   2. Disease Apply (single)     — apply disease to enemy by stat
--   3. Disease Apply (area)       — area-effect disease apply
--   4. Poison Apply (single)      — apply poison by stat (action, health, mind)
--   5. Poison Apply (area)        — area-effect poison apply
--   6. Damage Grenades            — single-target combat grenades
--   7. Area Grenades              — area-effect combat grenades

FbCombatQuartermaster = ScreenPlay:new {
	screenplayName = "FbCombatQuartermaster",
	spawns = {
		{ planet = "tatooine", label = "Mos Eisley Starport", x = 3526, z = 5, y = -4818, dir = 1 },
	},
}

FbCombatQuartermaster.combatCategories = {
	{ name = "Damage Packs (HAM damage)", items = {
		{ name="Damage Pack A", template="object/tangible/medicine/crafted/medpack_damage_a.iff", price=200 },
		{ name="Damage Pack B", template="object/tangible/medicine/crafted/medpack_damage_b.iff", price=400 },
		{ name="Damage Pack C", template="object/tangible/medicine/crafted/medpack_damage_c.iff", price=800 },
		{ name="Damage Pack D", template="object/tangible/medicine/crafted/medpack_damage_d.iff", price=1600 },
		{ name="Damage Pack E", template="object/tangible/medicine/crafted/medpack_damage_e.iff", price=3200 },
	}},
	{ name = "Disease Apply (single-target)", items = {
		{ name="Disease: Action A",       template="object/tangible/medicine/crafted/medpack_disease_action_a.iff",       price=250 },
		{ name="Disease: Action B",       template="object/tangible/medicine/crafted/medpack_disease_action_b.iff",       price=500 },
		{ name="Disease: Action C",       template="object/tangible/medicine/crafted/medpack_disease_action_c.iff",       price=1000 },
		{ name="Disease: Constitution A", template="object/tangible/medicine/crafted/medpack_disease_constitution_a.iff", price=250 },
		{ name="Disease: Constitution B", template="object/tangible/medicine/crafted/medpack_disease_constitution_b.iff", price=500 },
		{ name="Disease: Constitution C", template="object/tangible/medicine/crafted/medpack_disease_constitution_c.iff", price=1000 },
		{ name="Disease: Focus A",        template="object/tangible/medicine/crafted/medpack_disease_focus_a.iff",        price=250 },
		{ name="Disease: Focus B",        template="object/tangible/medicine/crafted/medpack_disease_focus_b.iff",        price=500 },
		{ name="Disease: Focus C",        template="object/tangible/medicine/crafted/medpack_disease_focus_c.iff",        price=1000 },
		{ name="Disease: Health A",       template="object/tangible/medicine/crafted/medpack_disease_health_a.iff",       price=250 },
		{ name="Disease: Health B",       template="object/tangible/medicine/crafted/medpack_disease_health_b.iff",       price=500 },
		{ name="Disease: Health C",       template="object/tangible/medicine/crafted/medpack_disease_health_c.iff",       price=1000 },
		{ name="Disease: Mind A",         template="object/tangible/medicine/crafted/medpack_disease_mind_a.iff",         price=250 },
		{ name="Disease: Mind B",         template="object/tangible/medicine/crafted/medpack_disease_mind_b.iff",         price=500 },
		{ name="Disease: Mind C",         template="object/tangible/medicine/crafted/medpack_disease_mind_c.iff",         price=1000 },
		{ name="Disease: Quickness A",    template="object/tangible/medicine/crafted/medpack_disease_quickness_a.iff",    price=250 },
		{ name="Disease: Quickness B",    template="object/tangible/medicine/crafted/medpack_disease_quickness_b.iff",    price=500 },
		{ name="Disease: Quickness C",    template="object/tangible/medicine/crafted/medpack_disease_quickness_c.iff",    price=1000 },
		{ name="Disease: Stamina A",      template="object/tangible/medicine/crafted/medpack_disease_stamina_a.iff",      price=250 },
		{ name="Disease: Stamina B",      template="object/tangible/medicine/crafted/medpack_disease_stamina_b.iff",      price=500 },
		{ name="Disease: Stamina C",      template="object/tangible/medicine/crafted/medpack_disease_stamina_c.iff",      price=1000 },
		{ name="Disease: Strength A",     template="object/tangible/medicine/crafted/medpack_disease_strength_a.iff",     price=250 },
		{ name="Disease: Strength B",     template="object/tangible/medicine/crafted/medpack_disease_strength_b.iff",     price=500 },
		{ name="Disease: Strength C",     template="object/tangible/medicine/crafted/medpack_disease_strength_c.iff",     price=1000 },
		{ name="Disease: Willpower A",    template="object/tangible/medicine/crafted/medpack_disease_willpower_a.iff",    price=250 },
		{ name="Disease: Willpower B",    template="object/tangible/medicine/crafted/medpack_disease_willpower_b.iff",    price=500 },
		{ name="Disease: Willpower C",    template="object/tangible/medicine/crafted/medpack_disease_willpower_c.iff",    price=1000 },
	}},
	{ name = "Disease Apply (area)", items = {
		{ name="Area Disease: Action A",       template="object/tangible/medicine/crafted/medpack_disease_area_action_a.iff",       price=500 },
		{ name="Area Disease: Action B",       template="object/tangible/medicine/crafted/medpack_disease_area_action_b.iff",       price=1000 },
		{ name="Area Disease: Action C",       template="object/tangible/medicine/crafted/medpack_disease_area_action_c.iff",       price=2000 },
		{ name="Area Disease: Constitution A", template="object/tangible/medicine/crafted/medpack_disease_area_constitution_a.iff", price=500 },
		{ name="Area Disease: Constitution B", template="object/tangible/medicine/crafted/medpack_disease_area_constitution_b.iff", price=1000 },
		{ name="Area Disease: Constitution C", template="object/tangible/medicine/crafted/medpack_disease_area_constitution_c.iff", price=2000 },
		{ name="Area Disease: Focus A",        template="object/tangible/medicine/crafted/medpack_disease_area_focus_a.iff",        price=500 },
		{ name="Area Disease: Focus B",        template="object/tangible/medicine/crafted/medpack_disease_area_focus_b.iff",        price=1000 },
		{ name="Area Disease: Focus C",        template="object/tangible/medicine/crafted/medpack_disease_area_focus_c.iff",        price=2000 },
		{ name="Area Disease: Health A",       template="object/tangible/medicine/crafted/medpack_disease_area_health_a.iff",       price=500 },
		{ name="Area Disease: Health B",       template="object/tangible/medicine/crafted/medpack_disease_area_health_b.iff",       price=1000 },
		{ name="Area Disease: Health C",       template="object/tangible/medicine/crafted/medpack_disease_area_health_c.iff",       price=2000 },
		{ name="Area Disease: Mind A",         template="object/tangible/medicine/crafted/medpack_disease_area_mind_a.iff",         price=500 },
		{ name="Area Disease: Mind B",         template="object/tangible/medicine/crafted/medpack_disease_area_mind_b.iff",         price=1000 },
		{ name="Area Disease: Mind C",         template="object/tangible/medicine/crafted/medpack_disease_area_mind_c.iff",         price=2000 },
		{ name="Area Disease: Quickness A",    template="object/tangible/medicine/crafted/medpack_disease_area_quickness_a.iff",    price=500 },
		{ name="Area Disease: Quickness B",    template="object/tangible/medicine/crafted/medpack_disease_area_quickness_b.iff",    price=1000 },
		{ name="Area Disease: Quickness C",    template="object/tangible/medicine/crafted/medpack_disease_area_quickness_c.iff",    price=2000 },
		{ name="Area Disease: Stamina A",      template="object/tangible/medicine/crafted/medpack_disease_area_stamina_a.iff",      price=500 },
		{ name="Area Disease: Stamina B",      template="object/tangible/medicine/crafted/medpack_disease_area_stamina_b.iff",      price=1000 },
		{ name="Area Disease: Stamina C",      template="object/tangible/medicine/crafted/medpack_disease_area_stamina_c.iff",      price=2000 },
		{ name="Area Disease: Strength A",     template="object/tangible/medicine/crafted/medpack_disease_area_strength_a.iff",     price=500 },
		{ name="Area Disease: Strength B",     template="object/tangible/medicine/crafted/medpack_disease_area_strength_b.iff",     price=1000 },
		{ name="Area Disease: Strength C",     template="object/tangible/medicine/crafted/medpack_disease_area_strength_c.iff",     price=2000 },
		{ name="Area Disease: Willpower A",    template="object/tangible/medicine/crafted/medpack_disease_area_willpower_a.iff",    price=500 },
		{ name="Area Disease: Willpower B",    template="object/tangible/medicine/crafted/medpack_disease_area_willpower_b.iff",    price=1000 },
		{ name="Area Disease: Willpower C",    template="object/tangible/medicine/crafted/medpack_disease_area_willpower_c.iff",    price=2000 },
	}},
	{ name = "Poison Apply (single-target)", items = {
		{ name="Poison: Action A", template="object/tangible/medicine/crafted/medpack_poison_action_a.iff", price=250 },
		{ name="Poison: Action B", template="object/tangible/medicine/crafted/medpack_poison_action_b.iff", price=500 },
		{ name="Poison: Action C", template="object/tangible/medicine/crafted/medpack_poison_action_c.iff", price=1000 },
		{ name="Poison: Health A", template="object/tangible/medicine/crafted/medpack_poison_health_a.iff", price=250 },
		{ name="Poison: Health B", template="object/tangible/medicine/crafted/medpack_poison_health_b.iff", price=500 },
		{ name="Poison: Health C", template="object/tangible/medicine/crafted/medpack_poison_health_c.iff", price=1000 },
		{ name="Poison: Mind A",   template="object/tangible/medicine/crafted/medpack_poison_mind_a.iff",   price=250 },
		{ name="Poison: Mind B",   template="object/tangible/medicine/crafted/medpack_poison_mind_b.iff",   price=500 },
		{ name="Poison: Mind C",   template="object/tangible/medicine/crafted/medpack_poison_mind_c.iff",   price=1000 },
	}},
	{ name = "Poison Apply (area)", items = {
		{ name="Area Poison: Action A", template="object/tangible/medicine/crafted/medpack_poison_area_action_a.iff", price=500 },
		{ name="Area Poison: Action B", template="object/tangible/medicine/crafted/medpack_poison_area_action_b.iff", price=1000 },
		{ name="Area Poison: Action C", template="object/tangible/medicine/crafted/medpack_poison_area_action_c.iff", price=2000 },
		{ name="Area Poison: Health A", template="object/tangible/medicine/crafted/medpack_poison_area_health_a.iff", price=500 },
		{ name="Area Poison: Health B", template="object/tangible/medicine/crafted/medpack_poison_area_health_b.iff", price=1000 },
		{ name="Area Poison: Health C", template="object/tangible/medicine/crafted/medpack_poison_area_health_c.iff", price=2000 },
		{ name="Area Poison: Mind A",   template="object/tangible/medicine/crafted/medpack_poison_area_mind_a.iff",   price=500 },
		{ name="Area Poison: Mind B",   template="object/tangible/medicine/crafted/medpack_poison_area_mind_b.iff",   price=1000 },
		{ name="Area Poison: Mind C",   template="object/tangible/medicine/crafted/medpack_poison_area_mind_c.iff",   price=2000 },
	}},
	{ name = "Damage Grenades", items = {
		{ name="Damage Grenade A", template="object/tangible/medicine/crafted/medpack_grenade_damage_a.iff", price=200 },
		{ name="Damage Grenade B", template="object/tangible/medicine/crafted/medpack_grenade_damage_b.iff", price=350 },
		{ name="Damage Grenade C", template="object/tangible/medicine/crafted/medpack_grenade_damage_c.iff", price=500 },
		{ name="Damage Grenade D", template="object/tangible/medicine/crafted/medpack_grenade_damage_d.iff", price=800 },
		{ name="Damage Grenade E", template="object/tangible/medicine/crafted/medpack_grenade_damage_e.iff", price=1200 },
	}},
	{ name = "Area-Effect Grenades", items = {
		{ name="Area Grenade A", template="object/tangible/medicine/crafted/medpack_grenade_area_a.iff", price=400 },
		{ name="Area Grenade B", template="object/tangible/medicine/crafted/medpack_grenade_area_b.iff", price=600 },
		{ name="Area Grenade C", template="object/tangible/medicine/crafted/medpack_grenade_area_c.iff", price=800 },
	}},
}

registerScreenPlay("FbCombatQuartermaster", true)

function FbCombatQuartermaster:start()
	for _, spawn in ipairs(self.spawns) do
		if isZoneEnabled(spawn.planet) then
			spawnMobile(spawn.planet, "fb_combat_quartermaster", 0,
				spawn.x, spawn.z, spawn.y, spawn.dir, spawn.cellID or 0)
		end
	end
	printf("FbCombatQuartermaster: spawned\n")
end

-- ============================================================================
-- Stateless per-category callbacks (same pattern as FB-44/72, Vex)
-- ============================================================================
function FbCombatQuartermaster:_purchaseFromCategory(pPlayer, eventIndex, args, catIdx)
	if pPlayer == nil then return end
	if eventIndex == 1 then return end
	local creature = CreatureObject(pPlayer)
	if catIdx < 1 or catIdx > #FbCombatQuartermaster.combatCategories then return end

	local idx = tonumber(args)
	if idx == nil then return end

	if idx == 0 then
		FbCombatQuartermaster:_purchaseOneOfEach(pPlayer, catIdx)
		return
	end

	local cat = FbCombatQuartermaster.combatCategories[catIdx]
	if idx < 1 or idx > #cat.items then return end

	local item = cat.items[idx]
	if creature:getCashCredits() < item.price then
		creature:sendSystemMessage("Not enough credits for " .. item.name .. ". Need " .. item.price .. " cr.")
		return
	end

	local pInventory = creature:getSlottedObject("inventory")
	if pInventory == nil then return end
	if SceneObject(pInventory):isContainerFullRecursive() then
		creature:sendSystemMessage("Inventory full.")
		return
	end

	local pItem = giveItem(pInventory, item.template, -1)
	if pItem == nil then
		creature:sendSystemMessage("Transaction failed (template may not be spawnable): " .. item.template)
		return
	end

	creature:subtractCashCredits(item.price)
	creature:sendSystemMessage("Purchased " .. item.name .. " (" .. cat.name .. ") for " .. item.price .. " credits.")
end

function FbCombatQuartermaster:_purchaseOneOfEach(pPlayer, catIdx)
	if pPlayer == nil then return end
	local creature = CreatureObject(pPlayer)
	local cat = FbCombatQuartermaster.combatCategories[catIdx]
	local total = 0
	for i = 1, #cat.items do total = total + cat.items[i].price end

	if creature:getCashCredits() < total then
		creature:sendSystemMessage("Not enough credits for one of each. Need " .. total .. " cr.")
		return
	end

	local pInventory = creature:getSlottedObject("inventory")
	if pInventory == nil then return end
	if SceneObject(pInventory):isContainerFullRecursive() then
		creature:sendSystemMessage("Inventory full.")
		return
	end

	local givenCount, totalSpent = 0, 0
	local failed = {}
	for i = 1, #cat.items do
		local item = cat.items[i]
		if SceneObject(pInventory):isContainerFullRecursive() then
			table.insert(failed, item.name .. " (full)")
		else
			local pItem = giveItem(pInventory, item.template, -1)
			if pItem ~= nil then
				givenCount = givenCount + 1
				totalSpent = totalSpent + item.price
			else
				table.insert(failed, item.name)
			end
		end
	end

	if totalSpent > 0 then creature:subtractCashCredits(totalSpent) end

	if givenCount == #cat.items then
		creature:sendSystemMessage("Got one of each " .. cat.name .. ": " .. givenCount .. " items for " .. totalSpent .. " credits.")
	elseif givenCount > 0 then
		creature:sendSystemMessage("Partial " .. cat.name .. ": " .. givenCount .. " of " .. #cat.items .. " for " .. totalSpent .. " cr. Failed: " .. table.concat(failed, ", "))
	else
		creature:sendSystemMessage("No items delivered.")
	end
end

for i = 1, #FbCombatQuartermaster.combatCategories do
	local catIdx = i
	FbCombatQuartermaster["onCombatPickedCat" .. catIdx] = function(self, pPlayer, pSui, eventIndex, args)
		FbCombatQuartermaster:_purchaseFromCategory(pPlayer, eventIndex, args, catIdx)
	end
end

function FbCombatQuartermaster:showGrenadeList(pPlayer, pNpc)
	if pPlayer == nil then return end
	local pSui = SuiListBox.new("FbCombatQuartermaster", "onCategoryPicked")
	pSui.setTitle("FB Combat Supply — Catalogue")
	pSui.setPrompt("A licensed Combat Medic will craft you better — this is field-issue stock.")
	for i = 1, #FbCombatQuartermaster.combatCategories do
		local cat = FbCombatQuartermaster.combatCategories[i]
		pSui.add(cat.name .. "  (" .. #cat.items .. " items)", "")
	end
	pSui.sendTo(pPlayer)
end

function FbCombatQuartermaster:onCategoryPicked(pPlayer, pSui, eventIndex, args)
	if pPlayer == nil then return end
	if eventIndex == 1 then return end
	local catIdx = tonumber(args)
	if catIdx == nil then return end
	catIdx = catIdx + 1
	if catIdx < 1 or catIdx > #FbCombatQuartermaster.combatCategories then return end

	local cat = FbCombatQuartermaster.combatCategories[catIdx]
	local pInner = SuiListBox.new("FbCombatQuartermaster", "onCombatPickedCat" .. catIdx)
	pInner.setTitle(cat.name)
	pInner.setPrompt("Pick an item, or buy one of each for testing:")

	local total = 0
	for i = 1, #cat.items do total = total + cat.items[i].price end
	pInner.add("[" .. total .. " cr]  *** Buy one of each (" .. #cat.items .. " items, testing) ***", "")

	for i = 1, #cat.items do
		local it = cat.items[i]
		pInner.add("[" .. it.price .. " cr] " .. it.name, "")
	end
	pInner.sendTo(pPlayer)
end
