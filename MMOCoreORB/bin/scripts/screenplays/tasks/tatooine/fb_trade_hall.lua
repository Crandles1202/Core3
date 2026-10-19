-- fb_trade_hall.lua — the Mos Eisley Trade Hall (Phase 2.11), now a site: the data lives in
-- screenplays/tasks/sites/mos_eisley_trade_hall.lua and FbSites builds it at boot. This file keeps the
-- names the doorman's conversation handler and the lab use.

FbTradeHall = ScreenPlay:new {
	screenplayName = "FbTradeHall",
	site = "mos_eisley_trade_hall",
}

registerScreenPlay("FbTradeHall", true)

function FbTradeHall:start() end   -- FbSites spawns the hall

function FbTradeHall:building() return FbSites:building(self.site) end
function FbTradeHall:isOpen() return FbSites:isOpen(self.site) end
function FbTradeHall:cellByName(name) return FbSites:cellByName(self.site, name) end
function FbTradeHall:doorPosition() return FbSites:doorPosition(self.site) end
function FbTradeHall:status() return FbSites:status(self.site) end

function FbTradeHall:giveWaypoint(pPlayer)
	FbSites:giveWaypoint(self.site, pPlayer)
	setQuestStatus("FbTradeHall.lastWaypoint", CreatureObject(pPlayer):getFirstName())   -- the trade-hall scenario reads this
end

function FbTradeHall:tenantLine()
	return "Inside you'll find " .. FbSites:tenantLine(self.site) .. ". Ask the keepers, they don't bite. Mostly."
end
