-- fb_smuggler_goods.screenplay.lua  — Greelo's full smuggler inventory.
-- Slicing kits + every spice. Two-level submenu UX.
-- Phase 2.10 — final Wave 1 expansion.

FbSmugglerGoods = ScreenPlay:new {
	screenplayName = "FbSmugglerGoods",
	spawns = {
		{ planet = "tatooine", label = "Mos Eisley Starport", x = 3532, z = 5, y = -4818, dir = 1 },
	},
}

FbSmugglerGoods.smugglerCategories = {
	{ name = "Slicing Kits", items = {
		{ name="Slicing Laser Knife",      template="object/tangible/slicing/slicing_laser_knife.iff",         price=300  },
		{ name="Slicing Flow Analyzer",    template="object/tangible/slicing/slicing_flow_analyzer.iff",       price=400  },
		{ name="Slicing Molecular Clamp",  template="object/tangible/slicing/slicing_molecular_clamp.iff",     price=500  },
		{ name="Armor Upgrade Kit",        template="object/tangible/slicing/slicing_armor_upgrade_kit.iff",   price=1000 },
		{ name="Weapon Upgrade Kit",       template="object/tangible/slicing/slicing_weapon_upgrade_kit.iff",  price=1000 },
	}},
	{ name = "Spice", items = {
		{ name="Booster Blue",     template="object/tangible/food/spice/spice_booster_blue.iff",     price=200 },
		{ name="Crash 'n Burn",    template="object/tangible/food/spice/spice_crash_n_burn.iff",     price=200 },
		{ name="Droid Lube",       template="object/tangible/food/spice/spice_droid_lube.iff",       price=200 },
		{ name="Giggledust",       template="object/tangible/food/spice/spice_giggledust.iff",       price=250 },
		{ name="Grey Gabaki",      template="object/tangible/food/spice/spice_grey_gabaki.iff",      price=250 },
		{ name="Gunjack",          template="object/tangible/food/spice/spice_gunjack.iff",          price=200 },
		{ name="Kliknik Boost",    template="object/tangible/food/spice/spice_kliknik_boost.iff",    price=250 },
		{ name="Kwi Boost",        template="object/tangible/food/spice/spice_kwi_boost.iff",        price=250 },
		{ name="Muon Gold",        template="object/tangible/food/spice/spice_muon_gold.iff",        price=400 },
		{ name="Neutron Pixey",    template="object/tangible/food/spice/spice_neutron_pixey.iff",    price=300 },
		{ name="Pyrepenol",        template="object/tangible/food/spice/spice_pyrepenol.iff",        price=300 },
		{ name="Scramjet",         template="object/tangible/food/spice/spice_scramjet.iff",         price=350 },
		{ name="Sedative H4-B",    template="object/tangible/food/spice/spice_sedative_h4b.iff",     price=350 },
		{ name="Shadowpaw",        template="object/tangible/food/spice/spice_shadowpaw.iff",        price=300 },
		{ name="Sweetblossom",     template="object/tangible/food/spice/spice_sweetblossom.iff",     price=250 },
		{ name="Thruster Head",    template="object/tangible/food/spice/spice_thruster_head.iff",    price=300 },
		{ name="Yarrock",          template="object/tangible/food/spice/spice_yarrock.iff",          price=400 },
	}},
}

registerScreenPlay("FbSmugglerGoods", true)

function FbSmugglerGoods:start()
	for _, spawn in ipairs(self.spawns) do
		if isZoneEnabled(spawn.planet) then
			spawnMobile(spawn.planet, "fb_smuggler_goods", 0,
				spawn.x, spawn.z, spawn.y, spawn.dir, spawn.cellID or 0)
		end
	end
	printf("FbSmugglerGoods: spawned\n")
end

function FbSmugglerGoods:_purchaseFromCategory(pPlayer, eventIndex, args, catIdx)
	if pPlayer == nil then return end
	if eventIndex == 1 then return end
	local creature = CreatureObject(pPlayer)
	if catIdx < 1 or catIdx > #FbSmugglerGoods.smugglerCategories then return end

	local idx = tonumber(args)
	if idx == nil then return end

	if idx == 0 then
		FbSmugglerGoods:_purchaseOneOfEach(pPlayer, catIdx)
		return
	end

	local cat = FbSmugglerGoods.smugglerCategories[catIdx]
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
	creature:sendSystemMessage("Purchased " .. item.name .. " for " .. item.price .. " credits. No refunds.")
end

function FbSmugglerGoods:_purchaseOneOfEach(pPlayer, catIdx)
	if pPlayer == nil then return end
	local creature = CreatureObject(pPlayer)
	local cat = FbSmugglerGoods.smugglerCategories[catIdx]
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
				givenCount = givenCount + 1
				totalSpent = totalSpent + item.price
			else
				table.insert(failed, item.name)
			end
		end
	end

	if totalSpent > 0 then creature:subtractCashCredits(totalSpent) end

	if givenCount == #cat.items then
		creature:sendSystemMessage("Got one of each: " .. givenCount .. " items for " .. totalSpent .. " credits.")
	elseif givenCount > 0 then
		creature:sendSystemMessage("Partial: " .. givenCount .. " of " .. #cat.items .. " for " .. totalSpent .. " cr. Failed: " .. table.concat(failed, ", "))
	else
		creature:sendSystemMessage("No items delivered.")
	end
end

for i = 1, #FbSmugglerGoods.smugglerCategories do
	local catIdx = i
	FbSmugglerGoods["onSmugglerPickedCat" .. catIdx] = function(self, pPlayer, pSui, eventIndex, args)
		FbSmugglerGoods:_purchaseFromCategory(pPlayer, eventIndex, args, catIdx)
	end
end

function FbSmugglerGoods:showSmugglerList(pPlayer, pNpc)
	if pPlayer == nil then return end
	local pSui = SuiListBox.new("FbSmugglerGoods", "onCategoryPicked")
	pSui.setTitle("Greelo's Goods")
	pSui.setPrompt("Slicing kits or spice. No refunds.")
	for i = 1, #FbSmugglerGoods.smugglerCategories do
		local cat = FbSmugglerGoods.smugglerCategories[i]
		pSui.add(cat.name .. "  (" .. #cat.items .. " items)", "")
	end
	pSui.sendTo(pPlayer)
end

function FbSmugglerGoods:onCategoryPicked(pPlayer, pSui, eventIndex, args)
	if pPlayer == nil then return end
	if eventIndex == 1 then return end
	local catIdx = tonumber(args)
	if catIdx == nil then return end
	catIdx = catIdx + 1
	if catIdx < 1 or catIdx > #FbSmugglerGoods.smugglerCategories then return end

	local cat = FbSmugglerGoods.smugglerCategories[catIdx]
	local pInner = SuiListBox.new("FbSmugglerGoods", "onSmugglerPickedCat" .. catIdx)
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
