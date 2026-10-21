-- Final Boss hooks into the Jedi manager. Run by JediManager::loadConfiguration (C++) right after the stock
-- jedi_manager.lua / village_jedi_manager.lua, in every Lua state that loads the manager. The screenplays are
-- already loaded in that state, so FbAttunement is in reach; anything that must survive the manager's own
-- definitions goes here, not into a screenplay (a screenplay-time wrapper is overwritten by the load).

-- 4a.1: /checkForceStatus reports the attunement tier, never the Village's progress line
if FbAttunement ~= nil and FbAttunement.showStatus ~= nil then
	if VillageJediManager ~= nil then
		VillageJediManager.checkForceStatusCommand = function(self, pPlayer) FbAttunement:showStatus(pPlayer) end
	elseif JediManager ~= nil then
		JediManager.checkForceStatusCommand = function(self, pPlayer) FbAttunement:showStatus(pPlayer) end
	end
end
