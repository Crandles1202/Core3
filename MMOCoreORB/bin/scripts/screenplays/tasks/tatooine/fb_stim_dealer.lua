-- fb_stim_dealer.screenplay.lua
-- Screenplay for Vex Renn (FB Medical Supplier). Spawns the NPC, hosts the
-- static medical-consumables inventory, and provides the SUI buy callback.
--
-- Mirrors the FB-72 armory droid pattern verbatim — only the inventory
-- table, NPC template, customDialogText, and spawn coords are different.
-- That four-file pattern is now a proven recipe for any static-inventory
-- vendor.
--
-- Install path: MMOCoreORB/bin/scripts/screenplays/tasks/tatooine/fb_stim_dealer.lua
-- Register in:  screenplays/screenplays.lua as
--               includeFile("tasks/tatooine/fb_stim_dealer.lua")
--
-- Phase 2.1 MVP — Final Boss server.

FbStimDealer = ScreenPlay:new {
	screenplayName = "FbStimDealer",

	-- ==== Static medical-consumables inventory ====
	-- Starter-tier prices. Player-crafted equivalents are MUCH more powerful
	-- (doctor/chemist crafted stims heal vastly more) — Vex's stock is the
	-- "I'm out of stims and there's no doctor around" tier. Doesn't undercut
	-- the player chemistry economy at all.
	--
	-- To add an item: append {name=..., template=..., price=...}. The SUI
	-- list and purchase callback both read this table by index.
	stims = {
		{ name = "Basic Stim Pack",     template = "object/tangible/medicine/stimpack_sm_s1.iff",    price = 50  },
		{ name = "Basic Wound Pack",    template = "object/tangible/medicine/medpack_sm_s1.iff",     price = 100 },
		{ name = "Disease Cure Pack",   template = "object/tangible/medicine/medpack_cure_disease.iff", price = 150 },
		{ name = "Poison Cure Pack",    template = "object/tangible/medicine/medpack_cure_poison.iff",  price = 150 },
		{ name = "Revival Pack",        template = "object/tangible/medicine/medpack_revive.iff",    price = 500 },
	},

	-- ==== Spawn locations ====
	-- MVP: Mos Eisley starport, a few meters east of FB-72 so they cluster
	-- as a "newbie services" pair near where new chars exit the starport.
	spawns = {
		{ planet = "tatooine", label = "Mos Eisley Starport", x = 3520, z = 5, y = -4818, dir = 1 },
	},
}

registerScreenPlay("FbStimDealer", true)

function FbStimDealer:start()
	local spawned = 0
	local skipped = 0

	for _, spawn in ipairs(self.spawns) do
		if isZoneEnabled(spawn.planet) then
			spawnMobile(
				spawn.planet,
				"fb_stim_dealer",
				0,                                 -- respawn timer (0 = never despawn)
				spawn.x, spawn.z, spawn.y,
				spawn.dir,
				spawn.cellID or 0                  -- 0 = world; non-zero = inside that cell
			)
			spawned = spawned + 1
		else
			skipped = skipped + 1
		end
	end

	printf("FbStimDealer: spawned " .. spawned .. " dealer(s) (" .. skipped .. " skipped, zone disabled)\n")
end

-- ==== Open the buy listbox ====
function FbStimDealer:showStimList(pPlayer, pNpc)
	if pPlayer == nil then return end

	local pSui = SuiListBox.new("FbStimDealer", "purchaseStimCallback")
	pSui.setTitle("FB Medical Supply — Catalogue")
	pSui.setPrompt("Select an item. Player-crafted medical kits are much more potent — these are emergency supplies only.")

	for i = 1, #self.stims do
		local s = self.stims[i]
		pSui.add("[" .. s.price .. " cr] " .. s.name, "")
	end

	pSui.sendTo(pPlayer)
end

-- ==== Purchase callback ====
-- eventIndex == 0 -> OK, == 1 -> Cancel.
-- args is the zero-based stringified index of the selected row.
-- Same atomic order as FB-72: credit check, inventory check, give item,
-- only then deduct credits. Defensive — subtractCashCredits doesn't
-- guard against negative balances.
function FbStimDealer:purchaseStimCallback(pPlayer, pSui, eventIndex, args)
	if pPlayer == nil then return end
	if eventIndex == 1 then return end

	local idx = tonumber(args)
	if idx == nil then return end
	idx = idx + 1

	if idx < 1 or idx > #self.stims then return end

	local stim = self.stims[idx]
	local creature = CreatureObject(pPlayer)

	if creature:getCashCredits() < stim.price then
		creature:sendSystemMessage("Not enough credits for the " .. stim.name .. ". It costs " .. stim.price .. " credits.")
		return
	end

	local pInventory = creature:getSlottedObject("inventory")
	if pInventory == nil then
		creature:sendSystemMessage("Transaction failed: cannot access your inventory.")
		return
	end

	if SceneObject(pInventory):isContainerFullRecursive() then
		creature:sendSystemMessage("Your inventory is full. Free some space and try again.")
		return
	end

	local pItem = giveItem(pInventory, stim.template, -1)
	if pItem == nil then
		creature:sendSystemMessage("Transaction failed. Please try again.")
		return
	end

	creature:subtractCashCredits(stim.price)
	creature:sendSystemMessage("Purchased " .. stim.name .. " for " .. stim.price .. " credits. Stay safe out there.")
end
