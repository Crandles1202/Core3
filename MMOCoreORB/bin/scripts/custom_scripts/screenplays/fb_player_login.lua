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

-- Phase 7.5: PlayerManager::calculatePlayerLevel (the held weapon line's combat difficulty / 100 + 1, cap 25) only runs
-- when a skill box is awarded, so a character that picked up its weapon afterwards -- every veteran start, made unarmed --
-- read level 1 to every con, mission terminal and aggro check for ever. CreatureObject:recomputeLevel() runs it again.
function FBLogin.recomputeLevel(pPlayer)
	if not SceneObject(pPlayer):isPlayerCreature() then return end
	local before = CreatureObject(pPlayer):getLevel()
	local after = CreatureObject(pPlayer):recomputeLevel()
	if after > 0 and after ~= before then
		printf("FBLogin: level of %s recomputed %d -> %d\n", CreatureObject(pPlayer):getFirstName(), before, after)
	end
end

function FBLogin.onLogin(pPlayer)
	if pPlayer == nil then return end
	local ok, err = pcall(FBLogin.raiseInventoryLimit, pPlayer)
	if not ok then printf("FBLogin.raiseInventoryLimit failed: %s\n", tostring(err)) end
	-- Phase 7.5: the stored level follows the weapon in hand (stock recomputes it only on a skill award)
	local okL, errL = pcall(FBLogin.recomputeLevel, pPlayer)
	if not okL then printf("FBLogin.recomputeLevel failed: %s\n", tostring(errL)) end
	-- Phase 2.12: every privileged character carries a Lab Remote (no-op for players and for admins who have one)
	if FbLabRemote ~= nil then
		local ok2, err2 = pcall(function() FbLabRemote:give(pPlayer) end)
		if not ok2 then printf("FBLogin: lab remote hand-out failed: %s\n", tostring(err2)) end
	end
	-- Phase 4a.1: attunement observers + silent credit for what the character already has
	if FbAttunement ~= nil then
		local ok3, err3 = pcall(function() FbAttunement:onLogin(pPlayer) end)
		if not ok3 then printf("FBLogin: attunement hook failed: %s\n", tostring(err3)) end
	end
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
