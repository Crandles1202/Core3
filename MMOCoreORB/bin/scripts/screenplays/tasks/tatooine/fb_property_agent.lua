-- fb_property_agent.screenplay.lua  — Property Agent Garlen (structure deeds).
-- Houses by planet + harvesters + factories + generators + turrets.

FbPropertyAgent = ScreenPlay:new {
	screenplayName = "FbPropertyAgent",
	spawns = {
		{ planet = "tatooine", label = "Mos Eisley Starport", x = 3519, z = 5, y = -4813, dir = 1 },
	},
}

FbPropertyAgent.propertyCategories = {
	{ name = "Houses: Generic", items = {
		{ name="Generic House Small",                    template="object/tangible/deed/player_house_deed/generic_house_small_deed.iff",                       price=5000  },
		{ name="Generic House Small (Floor 2)",          template="object/tangible/deed/player_house_deed/generic_house_small_floor_02_deed.iff",              price=6000  },
		{ name="Generic House Small (Style 2)",          template="object/tangible/deed/player_house_deed/generic_house_small_style_02_deed.iff",              price=5500  },
		{ name="Generic House Small (Style 2 Floor 2)",  template="object/tangible/deed/player_house_deed/generic_house_small_style_02_floor_02_deed.iff",     price=6500  },
		{ name="Generic House Medium",                   template="object/tangible/deed/player_house_deed/generic_house_medium_deed.iff",                      price=15000 },
		{ name="Generic House Medium (Style 2)",         template="object/tangible/deed/player_house_deed/generic_house_medium_style_02_deed.iff",             price=16000 },
		{ name="Generic House Large",                    template="object/tangible/deed/player_house_deed/generic_house_large_deed.iff",                       price=30000 },
		{ name="Generic House Large (Style 2)",          template="object/tangible/deed/player_house_deed/generic_house_large_style_02_deed.iff",              price=32000 },
	}},
	{ name = "Houses: Corellia", items = {
		{ name="Corellia House Small",                   template="object/tangible/deed/player_house_deed/corellia_house_small_deed.iff",                      price=5500  },
		{ name="Corellia House Small (Floor 2)",         template="object/tangible/deed/player_house_deed/corellia_house_small_floor_02_deed.iff",             price=6500  },
		{ name="Corellia House Small (Style 2)",         template="object/tangible/deed/player_house_deed/corellia_house_small_style_02_deed.iff",             price=6000  },
		{ name="Corellia House Small (Style 2 Floor 2)", template="object/tangible/deed/player_house_deed/corellia_house_small_style_02_floor_02_deed.iff",    price=7000  },
		{ name="Corellia House Medium",                  template="object/tangible/deed/player_house_deed/corellia_house_medium_deed.iff",                     price=16000 },
		{ name="Corellia House Medium (Style 2)",        template="object/tangible/deed/player_house_deed/corellia_house_medium_style_02_deed.iff",            price=17000 },
		{ name="Corellia House Large",                   template="object/tangible/deed/player_house_deed/corellia_house_large_deed.iff",                      price=32000 },
		{ name="Corellia House Large (Style 2)",         template="object/tangible/deed/player_house_deed/corellia_house_large_style_02_deed.iff",             price=34000 },
	}},
	{ name = "Houses: Naboo", items = {
		{ name="Naboo House Small",            template="object/tangible/deed/player_house_deed/naboo_house_small_deed.iff",             price=6000  },
		{ name="Naboo House Small (Style 2)",  template="object/tangible/deed/player_house_deed/naboo_house_small_style_02_deed.iff",    price=6500  },
		{ name="Naboo House Medium",           template="object/tangible/deed/player_house_deed/naboo_house_medium_deed.iff",            price=17000 },
		{ name="Naboo House Medium (Style 2)", template="object/tangible/deed/player_house_deed/naboo_house_medium_style_02_deed.iff",   price=18000 },
		{ name="Naboo House Large",            template="object/tangible/deed/player_house_deed/naboo_house_large_deed.iff",             price=35000 },
	}},
	{ name = "Houses: Tatooine", items = {
		{ name="Tatooine House Small",            template="object/tangible/deed/player_house_deed/tatooine_house_small_deed.iff",          price=5000  },
		{ name="Tatooine House Small (Style 2)",  template="object/tangible/deed/player_house_deed/tatooine_house_small_style_02_deed.iff", price=5500  },
		{ name="Tatooine House Medium",           template="object/tangible/deed/player_house_deed/tatooine_house_medium_deed.iff",         price=15000 },
		{ name="Tatooine House Large",            template="object/tangible/deed/player_house_deed/tatooine_house_large_deed.iff",          price=30000 },
	}},
	{ name = "Merchant Tents", items = {
		{ name="Merchant Tent Style 1", template="object/tangible/deed/player_house_deed/merchant_tent_style_01_deed.iff", price=1500 },
		{ name="Merchant Tent Style 2", template="object/tangible/deed/player_house_deed/merchant_tent_style_02_deed.iff", price=1500 },
		{ name="Merchant Tent Style 3", template="object/tangible/deed/player_house_deed/merchant_tent_style_03_deed.iff", price=1500 },
	}},
	{ name = "Harvesters", items = {
		{ name="Flora Harvester",            template="object/tangible/deed/harvester_deed/harvester_flora_deed.iff",          price=3000  },
		{ name="Flora Harvester (Medium)",   template="object/tangible/deed/harvester_deed/harvester_flora_deed_medium.iff",   price=6000  },
		{ name="Flora Harvester (Heavy)",    template="object/tangible/deed/harvester_deed/harvester_flora_deed_heavy.iff",    price=12000 },
		{ name="Gas Harvester",              template="object/tangible/deed/harvester_deed/harvester_gas_deed.iff",            price=3500  },
		{ name="Gas Harvester (Medium)",     template="object/tangible/deed/harvester_deed/harvester_gas_deed_medium.iff",     price=7000  },
		{ name="Gas Harvester (Heavy)",      template="object/tangible/deed/harvester_deed/harvester_gas_deed_heavy.iff",      price=14000 },
		{ name="Liquid Harvester",           template="object/tangible/deed/harvester_deed/harvester_liquid_deed.iff",         price=3000  },
		{ name="Liquid Harvester (Medium)",  template="object/tangible/deed/harvester_deed/harvester_liquid_deed_medium.iff",  price=6000  },
		{ name="Liquid Harvester (Heavy)",   template="object/tangible/deed/harvester_deed/harvester_liquid_deed_heavy.iff",   price=12000 },
		{ name="Moisture Vaporator",         template="object/tangible/deed/harvester_deed/harvester_moisture_deed.iff",       price=2500  },
		{ name="Moisture Vaporator (Medium)", template="object/tangible/deed/harvester_deed/harvester_moisture_deed_medium.iff", price=5000  },
		{ name="Moisture Vaporator (Heavy)",  template="object/tangible/deed/harvester_deed/harvester_moisture_deed_heavy.iff",  price=10000 },
		{ name="Ore Mining Drill S1",        template="object/tangible/deed/harvester_deed/harvester_ore_s1_deed.iff",         price=4000  },
		{ name="Ore Mining Drill S2",        template="object/tangible/deed/harvester_deed/harvester_ore_s2_deed.iff",         price=8000  },
		{ name="Heavy Ore Mining Drill",     template="object/tangible/deed/harvester_deed/harvester_ore_heavy_deed.iff",      price=15000 },
		{ name="Creature Harvester",         template="object/tangible/deed/harvester_deed/harvester_creature_deed.iff",       price=3500  },
	}},
	{ name = "Factories", items = {
		{ name="Clothing Factory",  template="object/tangible/deed/factory_deed/factory_clothing_deed.iff",  price=30000 },
		{ name="Food Factory",      template="object/tangible/deed/factory_deed/factory_food_deed.iff",      price=30000 },
		{ name="Item Factory",      template="object/tangible/deed/factory_deed/factory_item_deed.iff",      price=35000 },
		{ name="Structure Factory", template="object/tangible/deed/factory_deed/factory_structure_deed.iff", price=40000 },
	}},
	{ name = "Generators", items = {
		{ name="Solar Generator",       template="object/tangible/deed/generator_deed/generator_solar_deed.iff",        price=5000  },
		{ name="Wind Generator",        template="object/tangible/deed/generator_deed/generator_wind_deed.iff",         price=6000  },
		{ name="Photo-Bio Generator",   template="object/tangible/deed/generator_deed/generator_photo_bio_deed.iff",    price=8000  },
		{ name="Fusion Generator",      template="object/tangible/deed/generator_deed/generator_fusion_deed.iff",       price=15000 },
	}},
	{ name = "Turrets", items = {
		{ name="Small Block Turret",  template="object/tangible/deed/turret_deed/turret_block_small_deed.iff",  price=25000  },
		{ name="Medium Block Turret", template="object/tangible/deed/turret_deed/turret_block_medium_deed.iff", price=75000  },
		{ name="Large Block Turret",  template="object/tangible/deed/turret_deed/turret_block_large_deed.iff",  price=200000 },
	}},
}

registerScreenPlay("FbPropertyAgent", true)

function FbPropertyAgent:start()
	for _, spawn in ipairs(self.spawns) do
		if isZoneEnabled(spawn.planet) then
			spawnMobile(spawn.planet, "fb_property_agent", 0, spawn.x, spawn.z, spawn.y, spawn.dir, spawn.cellID or 0)
		end
	end
	printf("FbPropertyAgent: spawned\n")
end

function FbPropertyAgent:_purchaseFromCategory(pPlayer, eventIndex, args, catIdx)
	if pPlayer == nil then return end
	if eventIndex == 1 then return end
	local creature = CreatureObject(pPlayer)
	if catIdx < 1 or catIdx > #FbPropertyAgent.propertyCategories then return end
	local idx = tonumber(args); if idx == nil then return end
	if idx == 0 then FbPropertyAgent:_purchaseOneOfEach(pPlayer, catIdx); return end
	local cat = FbPropertyAgent.propertyCategories[catIdx]
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
		creature:sendSystemMessage("Transaction failed: " .. item.template)
		return
	end
	creature:subtractCashCredits(item.price)
	creature:sendSystemMessage("Purchased " .. item.name .. " for " .. item.price .. " credits.")
end

function FbPropertyAgent:_purchaseOneOfEach(pPlayer, catIdx)
	local creature = CreatureObject(pPlayer)
	local cat = FbPropertyAgent.propertyCategories[catIdx]
	local total = 0
	for i = 1, #cat.items do total = total + cat.items[i].price end
	if creature:getCashCredits() < total then
		creature:sendSystemMessage("Not enough credits. Need " .. total .. " cr.")
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
				givenCount = givenCount + 1; totalSpent = totalSpent + item.price
			else
				table.insert(failed, item.name)
			end
		end
	end
	if totalSpent > 0 then creature:subtractCashCredits(totalSpent) end
	if givenCount == #cat.items then
		creature:sendSystemMessage("Got one of each: " .. givenCount .. " deeds for " .. totalSpent .. " credits.")
	elseif givenCount > 0 then
		creature:sendSystemMessage("Partial: " .. givenCount .. " of " .. #cat.items .. " for " .. totalSpent .. " cr. Failed: " .. table.concat(failed, ", "))
	else
		creature:sendSystemMessage("No deeds delivered.")
	end
end

for i = 1, #FbPropertyAgent.propertyCategories do
	local catIdx = i
	FbPropertyAgent["onPropertyPickedCat" .. catIdx] = function(self, pPlayer, pSui, eventIndex, args)
		FbPropertyAgent:_purchaseFromCategory(pPlayer, eventIndex, args, catIdx)
	end
end

function FbPropertyAgent:showCategoryList(pPlayer, pNpc)
	if pPlayer == nil then return end
	local pSui = SuiListBox.new("FbPropertyAgent", "onCategoryPicked")
	pSui.setTitle("FB Real Estate — Catalogue")
	pSui.setPrompt("Select a category:")
	for i = 1, #FbPropertyAgent.propertyCategories do
		local cat = FbPropertyAgent.propertyCategories[i]
		pSui.add(cat.name .. "  (" .. #cat.items .. " items)", "")
	end
	pSui.sendTo(pPlayer)
end

function FbPropertyAgent:onCategoryPicked(pPlayer, pSui, eventIndex, args)
	if pPlayer == nil then return end
	if eventIndex == 1 then return end
	local catIdx = tonumber(args); if catIdx == nil then return end
	catIdx = catIdx + 1
	if catIdx < 1 or catIdx > #FbPropertyAgent.propertyCategories then return end
	local cat = FbPropertyAgent.propertyCategories[catIdx]
	local pInner = SuiListBox.new("FbPropertyAgent", "onPropertyPickedCat" .. catIdx)
	pInner.setTitle(cat.name)
	pInner.setPrompt("Pick a deed, or buy one of each:")
	local total = 0
	for i = 1, #cat.items do total = total + cat.items[i].price end
	pInner.add("[" .. total .. " cr]  *** Buy one of each (" .. #cat.items .. ", testing) ***", "")
	for i = 1, #cat.items do
		local it = cat.items[i]
		pInner.add("[" .. it.price .. " cr] " .. it.name, "")
	end
	pInner.sendTo(pPlayer)
end
