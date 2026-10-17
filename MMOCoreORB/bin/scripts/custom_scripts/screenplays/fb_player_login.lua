-- fb_player_login.lua — Final Boss per-login fix-ups.
--
-- PlayerObjectImplementation::notifyOnline calls PlayerTriggers:playerLoggedIn(pPlayer) in the
-- DirectorManager Lua state on every login. Upstream's screenplays/playerTriggers.lua defines it;
-- this file wraps it (loaded later via custom_scripts/screenplays/screenplays.lua) instead of
-- editing the upstream file. The wrap is guarded so `reloadscreenplays` does not stack wrappers.
--
-- Add future "make sure every character has X" migrations to FBLogin.onLogin.

FBLogin = FBLogin or {}
FBLogin.INVENTORY_VOLUME = 100   -- Phase 1.5; keep equal to FB_INVENTORY_VOLUME in fb_inventory_100.lua

-- Phase 1.5: inventories created before the template change persisted containerVolumeLimit = 80.
function FBLogin.raiseInventoryLimit(pPlayer)
	local pInventory = CreatureObject(pPlayer):getSlottedObject("inventory")
	if pInventory == nil then return end
	if SceneObject(pInventory):getContainerVolumeLimit() < FBLogin.INVENTORY_VOLUME then
		SceneObject(pInventory):setContainerVolumeLimit(FBLogin.INVENTORY_VOLUME)
	end
end

function FBLogin.onLogin(pPlayer)
	if pPlayer == nil then return end
	local ok, err = pcall(FBLogin.raiseInventoryLimit, pPlayer)
	if not ok then printf("FBLogin.raiseInventoryLimit failed: %s\n", tostring(err)) end
	printf("FBLogin: fix-ups applied for %s\n", CreatureObject(pPlayer):getFirstName())
end

-- Guard by identity, not by a flag: `reloadscreenplays` re-runs upstream playerTriggers.lua, which
-- puts the plain upstream function back; a flag would then leave it unwrapped. Comparing against our
-- own wrapper re-wraps exactly once per (re)load and never stacks.
if PlayerTriggers.playerLoggedIn ~= FBLogin._wrapper then
	local upstreamPlayerLoggedIn = PlayerTriggers.playerLoggedIn
	FBLogin._wrapper = function(self, pPlayer)
		upstreamPlayerLoggedIn(self, pPlayer)
		FBLogin.onLogin(pPlayer)
	end
	PlayerTriggers.playerLoggedIn = FBLogin._wrapper
end
