-- fb_cantina_manager.screenplay.lua — Cantina Manager Klee food/drink vendor.

FbCantinaManager = ScreenPlay:new {
	screenplayName = "FbCantinaManager",
	spawns = {
		{ planet = "tatooine", label = "Mos Eisley Food & Drink", x = -13.59, z = 1.13, y = -10.83, dir = 1, cellID = 1279965 },
	},
}

FbCantinaManager.foodCategories = {
	{ name = "Desserts", items = {
		{ name="Air Cake",                       template="object/tangible/food/crafted/dessert_air_cake.iff",                       price=100 },
		{ name="Almond Kwevvu Crisp Munchies",   template="object/tangible/food/crafted/dessert_almond_kwevvu_crisp_munchies.iff",   price=100 },
		{ name="Bantha Butter",                  template="object/tangible/food/crafted/dessert_bantha_butter.iff",                  price=100 },
		{ name="Blap Biscuit",                   template="object/tangible/food/crafted/dessert_blap_biscuit.iff",                   price=100 },
		{ name="Blob Candy",                     template="object/tangible/food/crafted/dessert_blob_candy.iff",                     price=100 },
		{ name="Bofa Treat",                     template="object/tangible/food/crafted/dessert_bofa_treat.iff",                     price=100 },
		{ name="Cavaellin Creams",               template="object/tangible/food/crafted/dessert_cavaellin_creams.iff",               price=100 },
		{ name="Chandad",                        template="object/tangible/food/crafted/dessert_chandad.iff",                        price=100 },
		{ name="Citros Snow Cake",               template="object/tangible/food/crafted/dessert_citros_snow_cake.iff",               price=100 },
		{ name="Corellian Fried Icecream",       template="object/tangible/food/crafted/dessert_corellian_fried_icecream.iff",       price=100 },
		{ name="Deneelian Fizz Pudding",         template="object/tangible/food/crafted/dessert_deneelian_fizz_pudding.iff",         price=100 },
		{ name="Dweezel",                        template="object/tangible/food/crafted/dessert_dweezel.iff",                        price=100 },
		{ name="Felbar",                         template="object/tangible/food/crafted/dessert_felbar.iff",                         price=100 },
		{ name="Glazed Glucose Pate",            template="object/tangible/food/crafted/dessert_glazed_glucose_pate.iff",            price=100 },
		{ name="Gorrnar",                        template="object/tangible/food/crafted/dessert_gorrnar.iff",                        price=100 },
		{ name="Kiwik Clusjo Swirl",             template="object/tangible/food/crafted/dessert_kiwik_clusjo_swirl.iff",             price=100 },
		{ name="Nanana Twist",                   template="object/tangible/food/crafted/dessert_nanana_twist.iff",                   price=100 },
		{ name="Para Roll",                      template="object/tangible/food/crafted/dessert_para_roll.iff",                      price=100 },
		{ name="Parwan Nutricake",               template="object/tangible/food/crafted/dessert_parwan_nutricake.iff",               price=100 },
		{ name="Pastebread",                     template="object/tangible/food/crafted/dessert_pastebread.iff",                     price=100 },
		{ name="Pikatta Pie",                    template="object/tangible/food/crafted/dessert_pikatta_pie.iff",                    price=100 },
		{ name="Pkneb",                          template="object/tangible/food/crafted/dessert_pkneb.iff",                          price=100 },
		{ name="Puffcake",                       template="object/tangible/food/crafted/dessert_puffcake.iff",                       price=100 },
		{ name="Pyollian Cake",                  template="object/tangible/food/crafted/dessert_pyollian_cake.iff",                  price=100 },
		{ name="Ryshcate",                       template="object/tangible/food/crafted/dessert_ryshcate.iff",                       price=100 },
		{ name="Smugglers Delight",              template="object/tangible/food/crafted/dessert_smugglers_delight.iff",              price=100 },
		{ name="Sweesonberry Rolls",             template="object/tangible/food/crafted/dessert_sweesonberry_rolls.iff",             price=100 },
		{ name="Sweet Cake Mix",                 template="object/tangible/food/crafted/dessert_sweet_cake_mix.iff",                 price=100 },
		{ name="Tranna Nougat Cream",            template="object/tangible/food/crafted/dessert_tranna_nougat_cream.iff",            price=100 },
		{ name="Vagnerian Canape",               template="object/tangible/food/crafted/dessert_vagnerian_canape.iff",               price=100 },
		{ name="Wedding Cake",                   template="object/tangible/food/crafted/dessert_wedding_cake.iff",                   price=100 },
		{ name="Won Won",                        template="object/tangible/food/crafted/dessert_won_won.iff",                        price=100 },
	}},
	{ name = "Dishes", items = {
		{ name="Ahrisa",                         template="object/tangible/food/crafted/dish_ahrisa.iff",                            price=100 },
		{ name="Bivoli Tempari",                 template="object/tangible/food/crafted/dish_bivoli_tempari.iff",                    price=100 },
		{ name="Blood Chowder",                  template="object/tangible/food/crafted/dish_blood_chowder.iff",                     price=100 },
		{ name="Braised Canron",                 template="object/tangible/food/crafted/dish_braised_canron.iff",                    price=100 },
		{ name="Cho Nor Hoola",                  template="object/tangible/food/crafted/dish_cho_nor_hoola.iff",                     price=100 },
		{ name="Crispic",                        template="object/tangible/food/crafted/dish_crispic.iff",                           price=100 },
		{ name="Dustcrepe",                      template="object/tangible/food/crafted/dish_dustcrepe.iff",                         price=100 },
		{ name="Exo Protein Wafers",             template="object/tangible/food/crafted/dish_exo_protein_wafers.iff",                price=100 },
		{ name="Fire Stew",                      template="object/tangible/food/crafted/dish_fire_stew.iff",                         price=100 },
		{ name="Fried Endwa",                    template="object/tangible/food/crafted/dish_fried_endwa.iff",                       price=100 },
		{ name="Gruuvan Shaal",                  template="object/tangible/food/crafted/dish_gruuvan_shaal.iff",                     price=100 },
		{ name="Havla",                          template="object/tangible/food/crafted/dish_havla.iff",                             price=100 },
		{ name="Kanali Wafers",                  template="object/tangible/food/crafted/dish_kanali_wafers.iff",                     price=100 },
		{ name="Karkan Ribenes",                 template="object/tangible/food/crafted/dish_karkan_ribenes.iff",                    price=100 },
		{ name="Meatlump",                       template="object/tangible/food/crafted/dish_meatlump.iff",                          price=100 },
		{ name="Ormachek",                       template="object/tangible/food/crafted/dish_ormachek.iff",                          price=100 },
		{ name="Patot Panak",                    template="object/tangible/food/crafted/dish_patot_panak.iff",                       price=100 },
		{ name="Protato",                        template="object/tangible/food/crafted/dish_protato.iff",                           price=100 },
		{ name="Puk",                            template="object/tangible/food/crafted/dish_puk.iff",                               price=100 },
		{ name="Rakririan Burnout Sauce",        template="object/tangible/food/crafted/dish_rakririan_burnout_sauce.iff",           price=100 },
		{ name="Ramorrean Capanata",             template="object/tangible/food/crafted/dish_ramorrean_capanata.iff",                price=100 },
		{ name="Rations",                        template="object/tangible/food/crafted/dish_rations.iff",                           price=100 },
		{ name="Scrimpi",                        template="object/tangible/food/crafted/dish_scrimpi.iff",                           price=100 },
		{ name="Soypro",                         template="object/tangible/food/crafted/dish_soypro.iff",                            price=100 },
		{ name="Stewed Gwouch",                  template="object/tangible/food/crafted/dish_stewed_gwouch.iff",                     price=100 },
		{ name="Synthsteak",                     template="object/tangible/food/crafted/dish_synthsteak.iff",                        price=100 },
		{ name="Teltier Noodles",                template="object/tangible/food/crafted/dish_teltier_noodles.iff",                   price=100 },
		{ name="Terratta",                       template="object/tangible/food/crafted/dish_terratta.iff",                          price=100 },
		{ name="Thakitillo",                     template="object/tangible/food/crafted/dish_thakitillo.iff",                        price=100 },
		{ name="Travel Biscuits",                template="object/tangible/food/crafted/dish_travel_biscuits.iff",                   price=100 },
		{ name="Trimpian",                       template="object/tangible/food/crafted/dish_trimpian.iff",                          price=100 },
		{ name="Vegeparsine",                    template="object/tangible/food/crafted/dish_vegeparsine.iff",                       price=100 },
		{ name="Veghash",                        template="object/tangible/food/crafted/dish_veghash.iff",                           price=100 },
		{ name="Vercupti Of Agazza Boleruuee",   template="object/tangible/food/crafted/dish_vercupti_of_agazza_boleruuee.iff",      price=100 },
		{ name="Wastril Bread",                  template="object/tangible/food/crafted/dish_wastril_bread.iff",                     price=100 },
		{ name="Xermaauc",                       template="object/tangible/food/crafted/dish_xermaauc.iff",                          price=100 },
	}},
	{ name = "Drinks", items = {
		{ name="Accarragm",                      template="object/tangible/food/crafted/drink_accarragm.iff",                        price=100 },
		{ name="Aitha",                          template="object/tangible/food/crafted/drink_aitha.iff",                            price=100 },
		{ name="Alcohol",                        template="object/tangible/food/crafted/drink_alcohol.iff",                          price=100 },
		{ name="Aludium Pu36",                   template="object/tangible/food/crafted/drink_aludium_pu36.iff",                     price=100 },
		{ name="Angerian Fishak Surprise",       template="object/tangible/food/crafted/drink_angerian_fishak_surprise.iff",         price=100 },
		{ name="Antakarian Fire Dancer",         template="object/tangible/food/crafted/drink_antakarian_fire_dancer.iff",           price=100 },
		{ name="Bantha Blaster",                 template="object/tangible/food/crafted/drink_bantha_blaster.iff",                   price=100 },
		{ name="Bespin Port",                    template="object/tangible/food/crafted/drink_bespin_port.iff",                      price=100 },
		{ name="Blue Milk",                      template="object/tangible/food/crafted/drink_blue_milk.iff",                        price=100 },
		{ name="Breath Of Heaven",               template="object/tangible/food/crafted/drink_breath_of_heaven.iff",                 price=100 },
		{ name="Caf",                            template="object/tangible/food/crafted/drink_caf.iff",                              price=100 },
		{ name="Charde",                         template="object/tangible/food/crafted/drink_charde.iff",                           price=100 },
		{ name="Corellian Ale",                  template="object/tangible/food/crafted/drink_corellian_ale.iff",                    price=100 },
		{ name="Corellian Brandy",               template="object/tangible/food/crafted/drink_corellian_brandy.iff",                 price=100 },
		{ name="Cortyg",                         template="object/tangible/food/crafted/drink_cortyg.iff",                           price=100 },
		{ name="Deuterium Pyro",                 template="object/tangible/food/crafted/drink_deuterium_pyro.iff",                   price=100 },
		{ name="Double Dip Outer Rim Rumdrop",   template="object/tangible/food/crafted/drink_double_dip_outer_rim_rumdrop.iff",     price=100 },
		{ name="Durindfire",                     template="object/tangible/food/crafted/drink_durindfire.iff",                       price=100 },
		{ name="Elshandruu Pica Thundercloud",   template="object/tangible/food/crafted/drink_elshandruu_pica_thundercloud.iff",     price=100 },
		{ name="Flameout",                       template="object/tangible/food/crafted/drink_flameout.iff",                         price=100 },
		{ name="Garrmorl",                       template="object/tangible/food/crafted/drink_garrmorl.iff",                         price=100 },
		{ name="Gralinyn Juice",                 template="object/tangible/food/crafted/drink_gralinyn_juice.iff",                   price=100 },
		{ name="Ice Blaster",                    template="object/tangible/food/crafted/drink_ice_blaster.iff",                      price=100 },
		{ name="Ithorian Mist",                  template="object/tangible/food/crafted/drink_ithorian_mist.iff",                    price=100 },
		{ name="Jaar",                           template="object/tangible/food/crafted/drink_jaar.iff",                             price=100 },
		{ name="Jawa Beer",                      template="object/tangible/food/crafted/drink_jawa_beer.iff",                        price=100 },
		{ name="Kylessian Fruit Distillate",     template="object/tangible/food/crafted/drink_kylessian_fruit_distillate.iff",       price=100 },
		{ name="Mandalorian Wine",               template="object/tangible/food/crafted/drink_mandalorian_wine.iff",                 price=100 },
		{ name="Ruby Bliel",                     template="object/tangible/food/crafted/drink_ruby_bliel.iff",                       price=100 },
		{ name="Skannbult Likker",               template="object/tangible/food/crafted/drink_skannbult_likker.iff",                 price=100 },
		{ name="Spiced Tea",                     template="object/tangible/food/crafted/drink_spiced_tea.iff",                       price=100 },
		{ name="Starshine Surprise",             template="object/tangible/food/crafted/drink_starshine_surprise.iff",               price=100 },
		{ name="Sullustan Gin",                  template="object/tangible/food/crafted/drink_sullustan_gin.iff",                    price=100 },
		{ name="Tatooine Sunburn",               template="object/tangible/food/crafted/drink_tatooine_sunburn.iff",                 price=100 },
		{ name="Tilla Tiil",                     template="object/tangible/food/crafted/drink_tilla_tiil.iff",                       price=100 },
		{ name="Tssolok",                        template="object/tangible/food/crafted/drink_tssolok.iff",                          price=100 },
		{ name="Vasarian Brandy",                template="object/tangible/food/crafted/drink_vasarian_brandy.iff",                  price=100 },
		{ name="Vayerbok",                       template="object/tangible/food/crafted/drink_vayerbok.iff",                         price=100 },
		{ name="Veronian Berry Wine",            template="object/tangible/food/crafted/drink_veronian_berry_wine.iff",              price=100 },
	}},
}

registerScreenPlay("FbCantinaManager", true)

function FbCantinaManager:start()
	for _, spawn in ipairs(self.spawns) do
		if isZoneEnabled(spawn.planet) then
			spawnMobile(spawn.planet, "fb_cantina_manager", 0, spawn.x, spawn.z, spawn.y, spawn.dir, spawn.cellID or 0)
		end
	end
	printf("FbCantinaManager: spawned\n")
end

function FbCantinaManager:_purchaseFromCategory(pPlayer, eventIndex, args, catIdx)
	if pPlayer == nil then return end
	if eventIndex == 1 then return end
	local creature = CreatureObject(pPlayer)
	if catIdx < 1 or catIdx > #FbCantinaManager.foodCategories then return end
	local idx = tonumber(args); if idx == nil then return end
	if idx == 0 then FbCantinaManager:_purchaseOneOfEach(pPlayer, catIdx); return end
	local cat = FbCantinaManager.foodCategories[catIdx]
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

function FbCantinaManager:_purchaseOneOfEach(pPlayer, catIdx)
	local creature = CreatureObject(pPlayer)
	local cat = FbCantinaManager.foodCategories[catIdx]
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
		creature:sendSystemMessage("Got one of each: " .. givenCount .. " items for " .. totalSpent .. " credits.")
	elseif givenCount > 0 then
		creature:sendSystemMessage("Partial: " .. givenCount .. " of " .. #cat.items .. " for " .. totalSpent .. " cr. Failed: " .. table.concat(failed, ", "))
	else
		creature:sendSystemMessage("No items delivered.")
	end
end

for i = 1, #FbCantinaManager.foodCategories do
	local catIdx = i
	FbCantinaManager["onFoodPickedCat" .. catIdx] = function(self, pPlayer, pSui, eventIndex, args)
		FbCantinaManager:_purchaseFromCategory(pPlayer, eventIndex, args, catIdx)
	end
end

function FbCantinaManager:showCategoryList(pPlayer, pNpc)
	if pPlayer == nil then return end
	local pSui = SuiListBox.new("FbCantinaManager", "onCategoryPicked")
	pSui.setTitle("Klee's Larder")
	pSui.setPrompt("Hahh, what sounds good? Pick a category:")
	for i = 1, #FbCantinaManager.foodCategories do
		local cat = FbCantinaManager.foodCategories[i]
		pSui.add(cat.name .. "  (" .. #cat.items .. " items)", "")
	end
	pSui.sendTo(pPlayer)
end

function FbCantinaManager:onCategoryPicked(pPlayer, pSui, eventIndex, args)
	if pPlayer == nil then return end
	if eventIndex == 1 then return end
	local catIdx = tonumber(args); if catIdx == nil then return end
	catIdx = catIdx + 1
	if catIdx < 1 or catIdx > #FbCantinaManager.foodCategories then return end
	local cat = FbCantinaManager.foodCategories[catIdx]
	local pInner = SuiListBox.new("FbCantinaManager", "onFoodPickedCat" .. catIdx)
	pInner.setTitle(cat.name)
	pInner.setPrompt("Pick an item, or buy one of each:")
	local total = 0
	for i = 1, #cat.items do total = total + cat.items[i].price end
	pInner.add("[" .. total .. " cr]  *** Buy one of each (" .. #cat.items .. ", testing) ***", "")
	for i = 1, #cat.items do
		local it = cat.items[i]
		pInner.add("[" .. it.price .. " cr] " .. it.name, "")
	end
	pInner.sendTo(pPlayer)
end
