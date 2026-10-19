-- fb_stim_dealer.screenplay.lua  — Vex Renn (FB Medical Supplier).
-- Full Doctor-profession medical inventory in two-level submenu UX.
-- Phase 2.8 — comprehensive medical expansion.
--
-- Categories (Doctor profession side):
--   1. Stimpacks       — heal damage
--   2. Wound Packs     — heal wounds per stat
--   3. Cure: Disease   — single + area
--   4. Cure: Poison    — single + area + antidote
--   5. Enhance Packs   — Doctor buffs per stat
--   6. State Cures     — blinded / dizzy / stunned / intimidated
--   7. Tools & Misc    — medikits, revival, newbie items
--
-- Combat Medic items (damage packs, disease/poison apply, grenades) live on
-- Quartermaster Sehrev — Vex is Doctor-only. Pet meds live on Yan'lara.
--
-- Install:  screenplays/tasks/tatooine/fb_stim_dealer.lua

FbStimDealer = ScreenPlay:new {
	screenplayName = "FbStimDealer",
	spawns = {
		-- moved into the Mos Eisley Trade Hall (fb_trade_hall.lua), Phase 2.11: { planet = "tatooine", label = "Mos Eisley Starport", x = 3520, z = 5, y = -4818, dir = 1 },
	},
}

FbStimDealer.medCategories = {
	{ name = "Stimpacks (heal damage)", items = {
		{ name="Newbie Stim Pack",       template="object/tangible/medicine/stimpack_sm_s1.iff",                          price=50  },
		{ name="Stimpack A",             template="object/tangible/medicine/crafted/crafted_stimpack_sm_s1_a.iff",         price=100 },
		{ name="Stimpack B",             template="object/tangible/medicine/crafted/crafted_stimpack_sm_s1_b.iff",         price=200 },
		{ name="Stimpack C",             template="object/tangible/medicine/crafted/crafted_stimpack_sm_s1_c.iff",         price=400 },
		{ name="Stimpack D",             template="object/tangible/medicine/crafted/crafted_stimpack_sm_s1_d.iff",         price=800 },
		{ name="Stimpack E",             template="object/tangible/medicine/crafted/crafted_stimpack_sm_s1_e.iff",         price=1600 },
	}},
	{ name = "Wound Packs (heal wounds)", items = {
		{ name="Newbie Med Pack",        template="object/tangible/medicine/medpack_sm_s1.iff",                              price=100 },
		-- Health
		{ name="Wound Pack: Health A",   template="object/tangible/medicine/crafted/medpack_wound_health_a.iff",            price=150 },
		{ name="Wound Pack: Health B",   template="object/tangible/medicine/crafted/medpack_wound_health_b.iff",            price=300 },
		{ name="Wound Pack: Health C",   template="object/tangible/medicine/crafted/medpack_wound_health_c.iff",            price=600 },
		{ name="Wound Pack: Health D",   template="object/tangible/medicine/crafted/medpack_wound_health_d.iff",            price=1200 },
		{ name="Wound Pack: Health E",   template="object/tangible/medicine/crafted/medpack_wound_health_e.iff",            price=2400 },
		-- Action
		{ name="Wound Pack: Action A",   template="object/tangible/medicine/crafted/medpack_wound_action_a.iff",            price=150 },
		{ name="Wound Pack: Action B",   template="object/tangible/medicine/crafted/medpack_wound_action_b.iff",            price=300 },
		{ name="Wound Pack: Action C",   template="object/tangible/medicine/crafted/medpack_wound_action_c.iff",            price=600 },
		{ name="Wound Pack: Action D",   template="object/tangible/medicine/crafted/medpack_wound_action_d.iff",            price=1200 },
		{ name="Wound Pack: Action E",   template="object/tangible/medicine/crafted/medpack_wound_action_e.iff",            price=2400 },
		-- Strength
		{ name="Wound Pack: Strength A", template="object/tangible/medicine/crafted/medpack_wound_strength_a.iff",          price=150 },
		{ name="Wound Pack: Strength B", template="object/tangible/medicine/crafted/medpack_wound_strength_b.iff",          price=300 },
		{ name="Wound Pack: Strength C", template="object/tangible/medicine/crafted/medpack_wound_strength_c.iff",          price=600 },
		{ name="Wound Pack: Strength D", template="object/tangible/medicine/crafted/medpack_wound_strength_d.iff",          price=1200 },
		{ name="Wound Pack: Strength E", template="object/tangible/medicine/crafted/medpack_wound_strength_e.iff",          price=2400 },
		-- Stamina
		{ name="Wound Pack: Stamina A",  template="object/tangible/medicine/crafted/medpack_wound_stamina_a.iff",           price=150 },
		{ name="Wound Pack: Stamina B",  template="object/tangible/medicine/crafted/medpack_wound_stamina_b.iff",           price=300 },
		{ name="Wound Pack: Stamina C",  template="object/tangible/medicine/crafted/medpack_wound_stamina_c.iff",           price=600 },
		{ name="Wound Pack: Stamina D",  template="object/tangible/medicine/crafted/medpack_wound_stamina_d.iff",           price=1200 },
		{ name="Wound Pack: Stamina E",  template="object/tangible/medicine/crafted/medpack_wound_stamina_e.iff",           price=2400 },
		-- Constitution
		{ name="Wound Pack: Constitution A", template="object/tangible/medicine/crafted/medpack_wound_constitution_a.iff",   price=150 },
		{ name="Wound Pack: Constitution B", template="object/tangible/medicine/crafted/medpack_wound_constitution_b.iff",   price=300 },
		{ name="Wound Pack: Constitution C", template="object/tangible/medicine/crafted/medpack_wound_constitution_c.iff",   price=600 },
		{ name="Wound Pack: Constitution D", template="object/tangible/medicine/crafted/medpack_wound_constitution_d.iff",   price=1200 },
		{ name="Wound Pack: Constitution E", template="object/tangible/medicine/crafted/medpack_wound_constitution_e.iff",   price=2400 },
		-- Quickness
		{ name="Wound Pack: Quickness A", template="object/tangible/medicine/crafted/medpack_wound_quickness_a.iff",        price=150 },
		{ name="Wound Pack: Quickness B", template="object/tangible/medicine/crafted/medpack_wound_quickness_b.iff",        price=300 },
		{ name="Wound Pack: Quickness C", template="object/tangible/medicine/crafted/medpack_wound_quickness_c.iff",        price=600 },
		{ name="Wound Pack: Quickness D", template="object/tangible/medicine/crafted/medpack_wound_quickness_d.iff",        price=1200 },
		{ name="Wound Pack: Quickness E", template="object/tangible/medicine/crafted/medpack_wound_quickness_e.iff",        price=2400 },
	}},
	{ name = "Cure: Disease", items = {
		{ name="Cure Disease A",         template="object/tangible/medicine/crafted/medpack_cure_disease_a.iff",            price=150 },
		{ name="Cure Disease B",         template="object/tangible/medicine/crafted/medpack_cure_disease_b.iff",            price=300 },
		{ name="Cure Disease C",         template="object/tangible/medicine/crafted/medpack_cure_disease_c.iff",            price=600 },
		{ name="Area Cure Disease A",    template="object/tangible/medicine/crafted/medpack_cure_disease_area_a.iff",       price=300 },
		{ name="Area Cure Disease B",    template="object/tangible/medicine/crafted/medpack_cure_disease_area_b.iff",       price=600 },
		{ name="Area Cure Disease C",    template="object/tangible/medicine/crafted/medpack_cure_disease_area_c.iff",       price=1200 },
	}},
	{ name = "Cure: Poison", items = {
		{ name="Antidote (newbie)",      template="object/tangible/medicine/antidote_sm_s1.iff",                              price=100 },
		{ name="Cure Poison A",          template="object/tangible/medicine/crafted/medpack_cure_poison_a.iff",              price=150 },
		{ name="Cure Poison B",          template="object/tangible/medicine/crafted/medpack_cure_poison_b.iff",              price=300 },
		{ name="Cure Poison C",          template="object/tangible/medicine/crafted/medpack_cure_poison_c.iff",              price=600 },
		{ name="Area Cure Poison A",     template="object/tangible/medicine/crafted/medpack_cure_poison_area_a.iff",         price=300 },
		{ name="Area Cure Poison B",     template="object/tangible/medicine/crafted/medpack_cure_poison_area_b.iff",         price=600 },
		{ name="Area Cure Poison C",     template="object/tangible/medicine/crafted/medpack_cure_poison_area_c.iff",         price=1200 },
	}},
	{ name = "Enhance Packs (Doctor buffs)", items = {
		-- Health enhance
		{ name="Enhance: Health A",      template="object/tangible/medicine/crafted/medpack_enhance_health_a.iff",          price=200 },
		{ name="Enhance: Health B",      template="object/tangible/medicine/crafted/medpack_enhance_health_b.iff",          price=400 },
		{ name="Enhance: Health C",      template="object/tangible/medicine/crafted/medpack_enhance_health_c.iff",          price=800 },
		{ name="Enhance: Health D",      template="object/tangible/medicine/crafted/medpack_enhance_health_d.iff",          price=1600 },
		-- Action enhance
		{ name="Enhance: Action A",      template="object/tangible/medicine/crafted/medpack_enhance_action_a.iff",          price=200 },
		{ name="Enhance: Action B",      template="object/tangible/medicine/crafted/medpack_enhance_action_b.iff",          price=400 },
		{ name="Enhance: Action C",      template="object/tangible/medicine/crafted/medpack_enhance_action_c.iff",          price=800 },
		{ name="Enhance: Action D",      template="object/tangible/medicine/crafted/medpack_enhance_action_d.iff",          price=1600 },
		-- Strength enhance
		{ name="Enhance: Strength A",    template="object/tangible/medicine/crafted/medpack_enhance_strength_a.iff",        price=200 },
		{ name="Enhance: Strength B",    template="object/tangible/medicine/crafted/medpack_enhance_strength_b.iff",        price=400 },
		{ name="Enhance: Strength C",    template="object/tangible/medicine/crafted/medpack_enhance_strength_c.iff",        price=800 },
		{ name="Enhance: Strength D",    template="object/tangible/medicine/crafted/medpack_enhance_strength_d.iff",        price=1600 },
		-- Stamina enhance
		{ name="Enhance: Stamina A",     template="object/tangible/medicine/crafted/medpack_enhance_stamina_a.iff",         price=200 },
		{ name="Enhance: Stamina B",     template="object/tangible/medicine/crafted/medpack_enhance_stamina_b.iff",         price=400 },
		{ name="Enhance: Stamina C",     template="object/tangible/medicine/crafted/medpack_enhance_stamina_c.iff",         price=800 },
		{ name="Enhance: Stamina D",     template="object/tangible/medicine/crafted/medpack_enhance_stamina_d.iff",         price=1600 },
		-- Constitution enhance
		{ name="Enhance: Constitution A", template="object/tangible/medicine/crafted/medpack_enhance_constitution_a.iff",   price=200 },
		{ name="Enhance: Constitution B", template="object/tangible/medicine/crafted/medpack_enhance_constitution_b.iff",   price=400 },
		{ name="Enhance: Constitution C", template="object/tangible/medicine/crafted/medpack_enhance_constitution_c.iff",   price=800 },
		{ name="Enhance: Constitution D", template="object/tangible/medicine/crafted/medpack_enhance_constitution_d.iff",   price=1600 },
		-- Quickness enhance
		{ name="Enhance: Quickness A",   template="object/tangible/medicine/crafted/medpack_enhance_quickness_a.iff",       price=200 },
		{ name="Enhance: Quickness B",   template="object/tangible/medicine/crafted/medpack_enhance_quickness_b.iff",       price=400 },
		{ name="Enhance: Quickness C",   template="object/tangible/medicine/crafted/medpack_enhance_quickness_c.iff",       price=800 },
		{ name="Enhance: Quickness D",   template="object/tangible/medicine/crafted/medpack_enhance_quickness_d.iff",       price=1600 },
		-- Disease resistance enhance
		{ name="Enhance: Disease Res A", template="object/tangible/medicine/crafted/medpack_enhance_disease_a.iff",         price=200 },
		{ name="Enhance: Disease Res B", template="object/tangible/medicine/crafted/medpack_enhance_disease_b.iff",         price=400 },
		{ name="Enhance: Disease Res C", template="object/tangible/medicine/crafted/medpack_enhance_disease_c.iff",         price=800 },
		-- Poison resistance enhance
		{ name="Enhance: Poison Res A",  template="object/tangible/medicine/crafted/medpack_enhance_poison_a.iff",          price=200 },
		{ name="Enhance: Poison Res B",  template="object/tangible/medicine/crafted/medpack_enhance_poison_b.iff",          price=400 },
		{ name="Enhance: Poison Res C",  template="object/tangible/medicine/crafted/medpack_enhance_poison_c.iff",          price=800 },
	}},
	{ name = "State Cures", items = {
		{ name="Cure Blinded A",         template="object/tangible/medicine/crafted/medpack_blinded_a.iff",                  price=200 },
		{ name="Cure Blinded B",         template="object/tangible/medicine/crafted/medpack_blinded_b.iff",                  price=400 },
		{ name="Cure Dizzy A",           template="object/tangible/medicine/crafted/medpack_dizzy_a.iff",                    price=200 },
		{ name="Cure Dizzy B",           template="object/tangible/medicine/crafted/medpack_dizzy_b.iff",                    price=400 },
		{ name="Cure Stunned A",         template="object/tangible/medicine/crafted/medpack_stunned_a.iff",                  price=200 },
		{ name="Cure Stunned B",         template="object/tangible/medicine/crafted/medpack_stunned_b.iff",                  price=400 },
		{ name="Cure Intimidated A",     template="object/tangible/medicine/crafted/medpack_intimidated_a.iff",              price=200 },
		{ name="Cure Intimidated B",     template="object/tangible/medicine/crafted/medpack_intimidated_b.iff",              price=400 },
	}},
	{ name = "Tools & Misc", items = {
		{ name="Revival Pack",           template="object/tangible/medicine/crafted/medpack_revive.iff",                     price=500 },
		{ name="Basic Medikit",          template="object/tangible/medicine/medikit_tool_basic.iff",                          price=300 },
		{ name="Advanced Medikit",       template="object/tangible/medicine/medikit_tool_advanced.iff",                       price=1500 },
		{ name="Newbie Heal Medicine",   template="object/tangible/medicine/newbie_heal_mission_medicine.iff",                price=50  },
	}},
}

registerScreenPlay("FbStimDealer", true)

function FbStimDealer:start()
	for _, spawn in ipairs(self.spawns) do
		if isZoneEnabled(spawn.planet) then
			spawnMobile(spawn.planet, "fb_stim_dealer", 0,
				spawn.x, spawn.z, spawn.y, spawn.dir, spawn.cellID or 0)
		end
	end
	printf("FbStimDealer: spawned\n")
end

-- ============================================================================
-- Per-category callbacks (stateless pattern from FB-44/FB-72)
-- ============================================================================
function FbStimDealer:_purchaseFromCategory(pPlayer, eventIndex, args, catIdx)
	if pPlayer == nil then return end
	if eventIndex == 1 then return end

	local creature = CreatureObject(pPlayer)
	if catIdx < 1 or catIdx > #FbStimDealer.medCategories then return end

	local idx = tonumber(args)
	if idx == nil then return end

	if idx == 0 then
		FbStimDealer:_purchaseOneOfEach(pPlayer, catIdx)
		return
	end

	local cat = FbStimDealer.medCategories[catIdx]
	if idx < 1 or idx > #cat.items then return end

	local item = cat.items[idx]

	if creature:getCashCredits() < item.price then
		creature:sendSystemMessage("Not enough credits for " .. item.name .. ". Need " .. item.price .. " cr.")
		return
	end

	local pInventory = creature:getSlottedObject("inventory")
	if pInventory == nil then
		creature:sendSystemMessage("Cannot access inventory.")
		return
	end
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

function FbStimDealer:_purchaseOneOfEach(pPlayer, catIdx)
	if pPlayer == nil then return end
	local creature = CreatureObject(pPlayer)
	local cat = FbStimDealer.medCategories[catIdx]

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
			table.insert(failed, item.name .. " (inventory full)")
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
		creature:sendSystemMessage("No items delivered from " .. cat.name .. ".")
	end
end

for i = 1, #FbStimDealer.medCategories do
	local catIdx = i
	FbStimDealer["onMedPickedCat" .. catIdx] = function(self, pPlayer, pSui, eventIndex, args)
		FbStimDealer:_purchaseFromCategory(pPlayer, eventIndex, args, catIdx)
	end
end

function FbStimDealer:showStimList(pPlayer, pNpc)
	if pPlayer == nil then return end
	local pSui = SuiListBox.new("FbStimDealer", "onCategoryPicked")
	pSui.setTitle("FB Medical Supply — Catalogue")
	pSui.setPrompt("Select a category. A licensed Doctor's crafted gear will still be more potent — this is field-tier issue stock.")
	for i = 1, #FbStimDealer.medCategories do
		local cat = FbStimDealer.medCategories[i]
		pSui.add(cat.name .. "  (" .. #cat.items .. " items)", "")
	end
	pSui.sendTo(pPlayer)
end

function FbStimDealer:onCategoryPicked(pPlayer, pSui, eventIndex, args)
	if pPlayer == nil then return end
	if eventIndex == 1 then return end
	local catIdx = tonumber(args)
	if catIdx == nil then return end
	catIdx = catIdx + 1
	if catIdx < 1 or catIdx > #FbStimDealer.medCategories then return end

	local cat = FbStimDealer.medCategories[catIdx]
	local pInner = SuiListBox.new("FbStimDealer", "onMedPickedCat" .. catIdx)
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
