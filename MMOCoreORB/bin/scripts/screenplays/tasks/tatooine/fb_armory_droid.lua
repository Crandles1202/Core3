-- fb_armory_droid.screenplay.lua
-- Screenplay for FB-72 armory droid. Spawns the NPC, hosts the static weapon
-- inventory, and provides the SUI buy callback.
--
-- Architecture mirrors the cantina bartender pattern: NPC conversation option
-- triggers a SuiListBox of items; selection callback validates credits,
-- gives the item, deducts credits.
--
-- Install path: MMOCoreORB/bin/scripts/screenplays/tasks/tatooine/fb_armory_droid.lua
-- Register in: screenplays/screenplays.lua
--
-- Phase 2.0 MVP — Final Boss server custom content.

FbArmoryDroid = ScreenPlay:new {
	screenplayName = "FbArmoryDroid",

	-- ==== Static weapon inventory ====
	-- Prices are deliberately cheap (factory-standard pre-30 weapons) so they
	-- DON'T undercut player-crafted weapons. A skilled weaponsmith's gear is
	-- strictly better at every quality tier; FB-72 only supplies the basics
	-- for new chars / solo players without crafter access.
	--
	-- To add a weapon: append {name=..., template=..., price=...}. The SUI
	-- list and purchase callback both read this table by index.
	weapons = {
		{ name = "Vibroblade",   template = "object/weapon/melee/knife/knife_vibroblade.iff",       price = 500  },
		{ name = "Vibroaxe",     template = "object/weapon/melee/axe/axe_vibroaxe.iff",             price = 800  },
		{ name = "Vibrolance",   template = "object/weapon/melee/polearm/lance_vibrolance.iff",     price = 1000 },
		{ name = "CDEF Pistol",  template = "object/weapon/ranged/pistol/pistol_cdef.iff",          price = 600  },
		{ name = "CDEF Carbine", template = "object/weapon/ranged/carbine/carbine_cdef.iff",        price = 1200 },
		{ name = "CDEF Rifle",   template = "object/weapon/ranged/rifle/rifle_cdef.iff",            price = 1500 },
	},

	-- ==== Spawn locations ====
	-- MVP: just one spot — outside Mos Eisley starport where new chars land.
	-- Once the buy flow is proven, scale to other starports + cities.
	--
	-- Coordinate semantics same as FB-21 medical droid screenplay:
	--   cellID nil/absent -> x/z/y are WORLD coords (outdoors)
	--   cellID set        -> x/z/y are CELL-LOCAL coords (inside that cell)
	spawns = {
		-- Mos Eisley: outdoor placement (Chuck-chosen spot near starport)
		{ planet = "tatooine", label = "Mos Eisley Starport", x = 3517, z = 5, y = -4818, dir = 1 },
	},
}

registerScreenPlay("FbArmoryDroid", true)

function FbArmoryDroid:start()
	local spawned = 0
	local skipped = 0

	for _, spawn in ipairs(self.spawns) do
		if isZoneEnabled(spawn.planet) then
			spawnMobile(
				spawn.planet,
				"fb_armory_droid",
				0,                                 -- respawn timer (0 = never despawn)
				spawn.x, spawn.z, spawn.y,
				spawn.dir,
				spawn.cellID or 0                  -- parent cellID (0 = world, no interior)
			)
			spawned = spawned + 1
		else
			skipped = skipped + 1
		end
	end

	printf("FbArmoryDroid: spawned " .. spawned .. " droid(s) (" .. skipped .. " skipped, zone disabled)\n")
end

-- ==== SUI builder: open the buy listbox ====
-- Called from the conv handler when the player picks "I'd like to buy a weapon."
function FbArmoryDroid:showWeaponList(pPlayer, pNpc)
	if pPlayer == nil then return end

	local pSui = SuiListBox.new("FbArmoryDroid", "purchaseWeaponCallback")
	pSui.setTitle("FB Armory — Weapon Catalogue")
	pSui.setPrompt("Select a weapon to purchase. Higher-grade equipment is available from licensed weaponsmiths.")

	for i = 1, #self.weapons do
		local w = self.weapons[i]
		pSui.add("[" .. w.price .. " cr] " .. w.name, "")
	end

	pSui.sendTo(pPlayer)
end

-- ==== Purchase callback ====
-- Triggered when the player clicks "OK" on the SUI listbox.
--   eventIndex == 0  -> OK clicked (proceed with purchase)
--   eventIndex == 1  -> Cancel clicked (no-op)
--   args             -> stringified zero-based index of selected row
--
-- Atomic flow: validate cash, validate inventory space, give item, then deduct.
-- If the giveItem fails (returns nil), we abort without charging — defensive
-- guard since subtractCashCredits is void (no insufficient-funds protection).
function FbArmoryDroid:purchaseWeaponCallback(pPlayer, pSui, eventIndex, args)
	if pPlayer == nil then return end
	if eventIndex == 1 then return end  -- Cancel

	local idx = tonumber(args)
	if idx == nil then return end
	idx = idx + 1  -- Lua tables are 1-indexed

	if idx < 1 or idx > #self.weapons then return end

	local weapon = self.weapons[idx]
	local creature = CreatureObject(pPlayer)

	-- Credit check (subtractCashCredits is void — must guard up front)
	if creature:getCashCredits() < weapon.price then
		creature:sendSystemMessage("You don't have enough credits for the " .. weapon.name .. ". It costs " .. weapon.price .. " credits.")
		return
	end

	-- Inventory space check
	local pInventory = creature:getSlottedObject("inventory")
	if pInventory == nil then
		creature:sendSystemMessage("Transaction failed: cannot access your inventory.")
		return
	end

	if SceneObject(pInventory):isContainerFullRecursive() then
		creature:sendSystemMessage("Your inventory is full. Free some space and try again.")
		return
	end

	-- Create the weapon and place it in the player's inventory.
	-- giveItem returns nil on failure (e.g. invalid template, container blocked).
	local pItem = giveItem(pInventory, weapon.template, -1)
	if pItem == nil then
		creature:sendSystemMessage("Transaction failed. Please try again.")
		return
	end

	-- Deduct credits ONLY after the item has successfully landed in inventory.
	creature:subtractCashCredits(weapon.price)
	creature:sendSystemMessage("Purchased " .. weapon.name .. " for " .. weapon.price .. " credits. Enjoy your new equipment.")
end
