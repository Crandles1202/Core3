-- fb_pet_vet.screenplay.lua — Doctor Yan'lara, full Bio-Engineer/CH inventory.
-- Pet medical + droid medical, two-level submenu UX.
-- Phase 2.10 — expansion.

FbPetVet = ScreenPlay:new {
	screenplayName = "FbPetVet",
	spawns = {
		{ planet = "tatooine", label = "Mos Eisley Starport", x = 3529, z = 5, y = -4818, dir = 1 },
	},
}

FbPetVet.petCategories = {
	{ name = "Pet Medical (stims + vita)", items = {
		{ name="Pet Stimpack A",  template="object/tangible/medicine/pet/pet_stimpack_a.iff",  price=75   },
		{ name="Pet Stimpack B",  template="object/tangible/medicine/pet/pet_stimpack_b.iff",  price=150  },
		{ name="Pet Stimpack C",  template="object/tangible/medicine/pet/pet_stimpack_c.iff",  price=300  },
		{ name="Pet Stimpack D",  template="object/tangible/medicine/pet/pet_stimpack_d.iff",  price=600  },
		{ name="Pet Vitapack A",  template="object/tangible/medicine/pet/pet_vitapack_a.iff",  price=75   },
		{ name="Pet Vitapack B",  template="object/tangible/medicine/pet/pet_vitapack_b.iff",  price=150  },
		{ name="Pet Vitapack C",  template="object/tangible/medicine/pet/pet_vitapack_c.iff",  price=300  },
	}},
	{ name = "Droid Medical (stims, vita, damage/wound kits)", items = {
		{ name="Droid Stimpack A",     template="object/tangible/medicine/pet/droid_stimpack_a.iff",     price=150  },
		{ name="Droid Stimpack B",     template="object/tangible/medicine/pet/droid_stimpack_b.iff",     price=300  },
		{ name="Droid Stimpack C",     template="object/tangible/medicine/pet/droid_stimpack_c.iff",     price=600  },
		{ name="Droid Stimpack D",     template="object/tangible/medicine/pet/droid_stimpack_d.iff",     price=1200 },
		{ name="Droid Vitapack A",     template="object/tangible/medicine/pet/droid_vitapack_a.iff",     price=150  },
		{ name="Droid Vitapack B",     template="object/tangible/medicine/pet/droid_vitapack_b.iff",     price=300  },
		{ name="Droid Vitapack C",     template="object/tangible/medicine/pet/droid_vitapack_c.iff",     price=600  },
		{ name="Droid Damage Kit A",   template="object/tangible/medicine/pet/droid_damage_kit_a.iff",   price=200  },
		{ name="Droid Damage Kit B",   template="object/tangible/medicine/pet/droid_damage_kit_b.iff",   price=400  },
		{ name="Droid Damage Kit C",   template="object/tangible/medicine/pet/droid_damage_kit_c.iff",   price=800  },
		{ name="Droid Damage Kit D",   template="object/tangible/medicine/pet/droid_damage_kit_d.iff",   price=1600 },
		{ name="Droid Wound Kit A",    template="object/tangible/medicine/pet/droid_wound_kit_a.iff",    price=200  },
		{ name="Droid Wound Kit B",    template="object/tangible/medicine/pet/droid_wound_kit_b.iff",    price=400  },
		{ name="Droid Wound Kit C",    template="object/tangible/medicine/pet/droid_wound_kit_c.iff",    price=800  },
		{ name="Droid Wound Kit D",    template="object/tangible/medicine/pet/droid_wound_kit_d.iff",    price=1600 },
	}},
}

registerScreenPlay("FbPetVet", true)

function FbPetVet:start()
	for _, spawn in ipairs(self.spawns) do
		if isZoneEnabled(spawn.planet) then
			spawnMobile(spawn.planet, "fb_pet_vet", 0,
				spawn.x, spawn.z, spawn.y, spawn.dir, spawn.cellID or 0)
		end
	end
	printf("FbPetVet: spawned\n")
end

function FbPetVet:_purchaseFromCategory(pPlayer, eventIndex, args, catIdx)
	if pPlayer == nil then return end
	if eventIndex == 1 then return end
	local creature = CreatureObject(pPlayer)
	if catIdx < 1 or catIdx > #FbPetVet.petCategories then return end

	local idx = tonumber(args)
	if idx == nil then return end

	if idx == 0 then
		FbPetVet:_purchaseOneOfEach(pPlayer, catIdx)
		return
	end

	local cat = FbPetVet.petCategories[catIdx]
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
	creature:sendSystemMessage("Purchased " .. item.name .. " for " .. item.price .. " credits.")
end

function FbPetVet:_purchaseOneOfEach(pPlayer, catIdx)
	if pPlayer == nil then return end
	local creature = CreatureObject(pPlayer)
	local cat = FbPetVet.petCategories[catIdx]
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

for i = 1, #FbPetVet.petCategories do
	local catIdx = i
	FbPetVet["onPetPickedCat" .. catIdx] = function(self, pPlayer, pSui, eventIndex, args)
		FbPetVet:_purchaseFromCategory(pPlayer, eventIndex, args, catIdx)
	end
end

function FbPetVet:showPetMedList(pPlayer, pNpc)
	if pPlayer == nil then return end
	local pSui = SuiListBox.new("FbPetVet", "onCategoryPicked")
	pSui.setTitle("FB Veterinary Supply — Catalogue")
	pSui.setPrompt("Pet or droid medical supplies. Bio-Engineer crafted gear is more potent.")
	for i = 1, #FbPetVet.petCategories do
		local cat = FbPetVet.petCategories[i]
		pSui.add(cat.name .. "  (" .. #cat.items .. " items)", "")
	end
	pSui.sendTo(pPlayer)
end

function FbPetVet:onCategoryPicked(pPlayer, pSui, eventIndex, args)
	if pPlayer == nil then return end
	if eventIndex == 1 then return end
	local catIdx = tonumber(args)
	if catIdx == nil then return end
	catIdx = catIdx + 1
	if catIdx < 1 or catIdx > #FbPetVet.petCategories then return end

	local cat = FbPetVet.petCategories[catIdx]
	local pInner = SuiListBox.new("FbPetVet", "onPetPickedCat" .. catIdx)
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
