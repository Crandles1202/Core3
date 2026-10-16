-- fb_imperial_armorer.screenplay.lua — Major Tarkus, Imperial-themed faction vendor.
-- Wave 5: faction-themed split. Stormtrooper armor + Imperial blasters.

FbImperialArmorer = ScreenPlay:new {
	screenplayName = "FbImperialArmorer",
	spawns = {
		-- Mos Eisley Imperial building (probe parentID 1280132)
		{ planet = "tatooine", label = "Mos Eisley Imperial Bldg", x = -3.65, z = 1.00, y = 8.08, dir = 1, cellID = 1280132 },
	},
}

FbImperialArmorer.imperialCategories = {
	{ name = "Stormtrooper Armor", items = {
		{ name="Helmet",         template="object/tangible/wearables/armor/stormtrooper/armor_stormtrooper_helmet.iff",        price=500 },
		{ name="Chest Plate",    template="object/tangible/wearables/armor/stormtrooper/armor_stormtrooper_chest_plate.iff",   price=750 },
		{ name="Leggings",       template="object/tangible/wearables/armor/stormtrooper/armor_stormtrooper_leggings.iff",      price=600 },
		{ name="Boots",          template="object/tangible/wearables/armor/stormtrooper/armor_stormtrooper_boots.iff",         price=400 },
		{ name="Bicep L",        template="object/tangible/wearables/armor/stormtrooper/armor_stormtrooper_bicep_l.iff",       price=350 },
		{ name="Bicep R",        template="object/tangible/wearables/armor/stormtrooper/armor_stormtrooper_bicep_r.iff",       price=350 },
		{ name="Bracer L",       template="object/tangible/wearables/armor/stormtrooper/armor_stormtrooper_bracer_l.iff",      price=350 },
		{ name="Bracer R",       template="object/tangible/wearables/armor/stormtrooper/armor_stormtrooper_bracer_r.iff",      price=350 },
		{ name="Gloves",         template="object/tangible/wearables/armor/stormtrooper/armor_stormtrooper_gloves.iff",        price=300 },
		{ name="Utility Belt",   template="object/tangible/wearables/armor/stormtrooper/armor_stormtrooper_utility_belt.iff",  price=400 },
	}},
	{ name = "Imperial Pistols", items = {
		{ name="DH-17 Pistol",            template="object/weapon/ranged/pistol/pistol_dh17.iff",            price=1500 },
		{ name="Scout Blaster",           template="object/weapon/ranged/pistol/pistol_scout_blaster.iff",   price=1200 },
		{ name="DE-10 Pistol",            template="object/weapon/ranged/pistol/pistol_de_10.iff",           price=1800 },
	}},
	{ name = "Imperial Carbines", items = {
		{ name="E-11 Carbine",            template="object/weapon/ranged/carbine/carbine_e11.iff",           price=2500 },
		{ name="DH-17 Carbine",           template="object/weapon/ranged/carbine/carbine_dh17.iff",          price=2200 },
		{ name="DH-17 Carbine (Black)",   template="object/weapon/ranged/carbine/carbine_dh17_black.iff",    price=2400 },
		{ name="DH-17 Snubnose",          template="object/weapon/ranged/carbine/carbine_dh17_snubnose.iff", price=2000 },
		{ name="EE-3 Carbine",            template="object/weapon/ranged/carbine/carbine_ee3.iff",           price=3500 },
		{ name="Elite Carbine",           template="object/weapon/ranged/carbine/carbine_elite.iff",         price=4000 },
	}},
	{ name = "Imperial Rifles", items = {
		{ name="E-11 Rifle",              template="object/weapon/ranged/rifle/rifle_e11.iff",               price=3000 },
		{ name="DLT-20 Rifle",            template="object/weapon/ranged/rifle/rifle_dlt20.iff",             price=3200 },
		{ name="DLT-20a Sniper Rifle",    template="object/weapon/ranged/rifle/rifle_dlt20a.iff",            price=4500 },
		{ name="T-21 Heavy Rifle",        template="object/weapon/ranged/rifle/rifle_t21.iff",               price=5000 },
		{ name="SG-82 Rifle",             template="object/weapon/ranged/rifle/rifle_sg82.iff",              price=3800 },
	}},
	{ name = "Imperial Ordnance", items = {
		{ name="Imperial Detonator",      template="object/weapon/ranged/grenade/grenade_imperial_detonator.iff", price=2500 },
	}},
}

registerScreenPlay("FbImperialArmorer", true)

function FbImperialArmorer:start()
	for _, spawn in ipairs(self.spawns) do
		if isZoneEnabled(spawn.planet) then
			spawnMobile(spawn.planet, "fb_imperial_armorer", 0, spawn.x, spawn.z, spawn.y, spawn.dir, spawn.cellID or 0)
		end
	end
	printf("FbImperialArmorer: spawned\n")
end

function FbImperialArmorer:_purchaseFromCategory(pPlayer, eventIndex, args, catIdx)
	if pPlayer == nil then return end
	if eventIndex == 1 then return end
	local creature = CreatureObject(pPlayer)
	if catIdx < 1 or catIdx > #FbImperialArmorer.imperialCategories then return end
	local idx = tonumber(args); if idx == nil then return end
	if idx == 0 then FbImperialArmorer:_purchaseOneOfEach(pPlayer, catIdx); return end
	local cat = FbImperialArmorer.imperialCategories[catIdx]
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
	creature:sendSystemMessage("Requisitioned " .. item.name .. " for " .. item.price .. " credits.")
end

function FbImperialArmorer:_purchaseOneOfEach(pPlayer, catIdx)
	local creature = CreatureObject(pPlayer)
	local cat = FbImperialArmorer.imperialCategories[catIdx]
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
		creature:sendSystemMessage("Requisitioned " .. givenCount .. " items for " .. totalSpent .. " credits.")
	elseif givenCount > 0 then
		creature:sendSystemMessage("Partial: " .. givenCount .. " of " .. #cat.items .. " for " .. totalSpent .. " cr. Failed: " .. table.concat(failed, ", "))
	else
		creature:sendSystemMessage("No items delivered.")
	end
end

for i = 1, #FbImperialArmorer.imperialCategories do
	local catIdx = i
	FbImperialArmorer["onItemPickedCat" .. catIdx] = function(self, pPlayer, pSui, eventIndex, args)
		FbImperialArmorer:_purchaseFromCategory(pPlayer, eventIndex, args, catIdx)
	end
end

function FbImperialArmorer:showCategoryList(pPlayer, pNpc)
	if pPlayer == nil then return end
	local pSui = SuiListBox.new("FbImperialArmorer", "onCategoryPicked")
	pSui.setTitle("Imperial Requisition")
	pSui.setPrompt("Select a category:")
	for i = 1, #FbImperialArmorer.imperialCategories do
		local cat = FbImperialArmorer.imperialCategories[i]
		pSui.add(cat.name .. "  (" .. #cat.items .. " items)", "")
	end
	pSui.sendTo(pPlayer)
end

function FbImperialArmorer:onCategoryPicked(pPlayer, pSui, eventIndex, args)
	if pPlayer == nil then return end
	if eventIndex == 1 then return end
	local catIdx = tonumber(args); if catIdx == nil then return end
	catIdx = catIdx + 1
	if catIdx < 1 or catIdx > #FbImperialArmorer.imperialCategories then return end
	local cat = FbImperialArmorer.imperialCategories[catIdx]
	local pInner = SuiListBox.new("FbImperialArmorer", "onItemPickedCat" .. catIdx)
	pInner.setTitle(cat.name)
	pInner.setPrompt("Pick an item, or requisition the entire kit:")
	local total = 0
	for i = 1, #cat.items do total = total + cat.items[i].price end
	pInner.add("[" .. total .. " cr]  *** Full kit (" .. #cat.items .. " items, testing) ***", "")
	for i = 1, #cat.items do
		local it = cat.items[i]
		pInner.add("[" .. it.price .. " cr] " .. it.name, "")
	end
	pInner.sendTo(pPlayer)
end
