-- fb_pet_dealer.screenplay.lua  — Handler Toobu creature pet vendor.
-- All 72 creature pet deeds in 3 alphabetical sub-categories.

FbPetDealer = ScreenPlay:new {
	screenplayName = "FbPetDealer",
	spawns = {
		{ planet = "tatooine", label = "Mos Eisley Starport", x = 3516, z = 5, y = -4813, dir = 1 },
	},
}

-- Helper to construct a deed item entry — pricing is rough/heuristic.
-- All creature deeds priced flat 1500 cr for testing; tune later.
local function deed(name, stem)
	return { name = name, template = "object/tangible/deed/pet_deed/" .. stem .. "_deed.iff", price = 1500 }
end

FbPetDealer.petCategories = {
	{ name = "Tameable Creatures A-F", items = {
		deed("Acklay",        "acklay"),
		deed("Angler",        "angler"),
		deed("Bageraset",     "bageraset"),
		deed("Bantha",        "bantha"),
		deed("Bearded Jax",   "bearded_jax"),
		deed("Blurrg",        "blurrg"),
		deed("Boar Wolf",     "boar_wolf"),
		deed("Bocatt",        "bocatt"),
		deed("Bol",           "bol"),
		deed("Bolle Bol",     "bolle_bol"),
		deed("Bolma",         "bolma"),
		deed("Bordok",        "bordok"),
		deed("Brackaset",     "brackaset"),
		deed("Carrion Spat",  "carrion_spat"),
		deed("Choku",         "choku"),
		deed("Cu Pa",         "cu_pa"),
		deed("Dalyrake",      "dalyrake"),
		deed("Dewback",       "dewback"),
		deed("Dune Lizard",   "dune_lizard"),
		deed("Durni",         "durni"),
		deed("Eopie",         "eopie"),
		deed("Falumpaset",    "falumpaset"),
		deed("Fambaa",        "fambaa"),
	}},
	{ name = "Tameable Creatures G-M", items = {
		deed("Gnort",         "gnort"),
		deed("Graul",         "graul"),
		deed("Gronda",        "gronda"),
		deed("Gualama",       "gualama"),
		deed("Guf Drolg",     "guf_drolg"),
		deed("Gurnaset",      "gurnaset"),
		deed("Gurrcat",       "gurrcat"),
		deed("Gurreck",       "gurreck"),
		deed("Hermit Spider", "hermit_spider"),
		deed("Huf Dun",       "huf_dun"),
		deed("Huurton",       "huurton"),
		deed("Ikopi",         "ikopi"),
		deed("Kaadu",         "kaadu"),
		deed("Kahmurra",      "kahmurra"),
		deed("Kima",          "kima"),
		deed("Kimogila",      "kimogila"),
		deed("Kliknik",       "kliknik"),
		deed("Krahbu",        "krahbu"),
		deed("Kusak",         "kusak"),
		deed("Kwi",           "kwi"),
		deed("Langlatch",     "langlatch"),
		deed("Malkloc",       "malkloc"),
		deed("Mawgax",        "mawgax"),
		deed("Merek",         "merek"),
		deed("Mott",          "mott"),
	}},
	{ name = "Tameable Creatures N-Z", items = {
		deed("Narglatch",     "narglatch"),
		deed("Piket",         "piket"),
		deed("Pugoriss",      "pugoriss"),
		deed("Rancor",        "rancor"),
		deed("Roba",          "roba"),
		deed("Ronto",         "ronto"),
		deed("Sand Panther",  "sand_panther"),
		deed("Sharnaff",      "sharnaff"),
		deed("Shear Mite",    "shear_mite"),
		deed("Slice Hound",   "slice_hound"),
		deed("Snorbal",       "snorbal"),
		deed("Squall",        "squall"),
		deed("Swirl Prong",   "swirl_prong"),
		deed("Thune",         "thune"),
		deed("Torton",        "torton"),
		deed("Tybis",         "tybis"),
		deed("Veermok",       "veermok"),
		deed("Verne",         "verne"),
		deed("Vesp",          "vesp"),
		deed("Vir Vur",       "vir_vur"),
		deed("Woolamander",   "woolamander"),
		deed("Zucca Boar",    "zucca_boar"),
	}},
}

registerScreenPlay("FbPetDealer", true)

function FbPetDealer:start()
	for _, spawn in ipairs(self.spawns) do
		if isZoneEnabled(spawn.planet) then
			spawnMobile(spawn.planet, "fb_pet_dealer", 0, spawn.x, spawn.z, spawn.y, spawn.dir, spawn.cellID or 0)
		end
	end
	printf("FbPetDealer: spawned\n")
end

function FbPetDealer:_purchaseFromCategory(pPlayer, eventIndex, args, catIdx)
	if pPlayer == nil then return end
	if eventIndex == 1 then return end
	local creature = CreatureObject(pPlayer)
	if catIdx < 1 or catIdx > #FbPetDealer.petCategories then return end
	local idx = tonumber(args); if idx == nil then return end
	if idx == 0 then FbPetDealer:_purchaseOneOfEach(pPlayer, catIdx); return end
	local cat = FbPetDealer.petCategories[catIdx]
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
	creature:sendSystemMessage("Purchased " .. item.name .. " deed for " .. item.price .. " credits.")
end

function FbPetDealer:_purchaseOneOfEach(pPlayer, catIdx)
	local creature = CreatureObject(pPlayer)
	local cat = FbPetDealer.petCategories[catIdx]
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

for i = 1, #FbPetDealer.petCategories do
	local catIdx = i
	FbPetDealer["onPetDeedPickedCat" .. catIdx] = function(self, pPlayer, pSui, eventIndex, args)
		FbPetDealer:_purchaseFromCategory(pPlayer, eventIndex, args, catIdx)
	end
end

function FbPetDealer:showCategoryList(pPlayer, pNpc)
	if pPlayer == nil then return end
	local pSui = SuiListBox.new("FbPetDealer", "onCategoryPicked")
	pSui.setTitle("Handler Toobu — Beast Registry")
	pSui.setPrompt("Select a creature group:")
	for i = 1, #FbPetDealer.petCategories do
		local cat = FbPetDealer.petCategories[i]
		pSui.add(cat.name .. "  (" .. #cat.items .. " species)", "")
	end
	pSui.sendTo(pPlayer)
end

function FbPetDealer:onCategoryPicked(pPlayer, pSui, eventIndex, args)
	if pPlayer == nil then return end
	if eventIndex == 1 then return end
	local catIdx = tonumber(args); if catIdx == nil then return end
	catIdx = catIdx + 1
	if catIdx < 1 or catIdx > #FbPetDealer.petCategories then return end
	local cat = FbPetDealer.petCategories[catIdx]
	local pInner = SuiListBox.new("FbPetDealer", "onPetDeedPickedCat" .. catIdx)
	pInner.setTitle(cat.name)
	pInner.setPrompt("Pick a species, or buy one of each:")
	local total = 0
	for i = 1, #cat.items do total = total + cat.items[i].price end
	pInner.add("[" .. total .. " cr]  *** Buy one of each (" .. #cat.items .. ", testing) ***", "")
	for i = 1, #cat.items do
		local it = cat.items[i]
		pInner.add("[" .. it.price .. " cr] " .. it.name, "")
	end
	pInner.sendTo(pPlayer)
end
