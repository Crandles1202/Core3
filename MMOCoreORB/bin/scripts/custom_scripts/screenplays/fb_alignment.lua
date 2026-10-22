-- fb_alignment.lua — Phase 4b.3: the alignment score.
--
-- The mercy trial chooses a side (FbAttunement flag `alignment`, light or dark); from then on what the character
-- does moves a hidden score between −100 (deep dark) and +100 (deep light), kept as FbAttunement flag `align`.
-- The side itself never flips on its own: when the score leans far enough the *other* Master offers the turn
-- (redemption or temptation, FbMasterBase:turn), and that is a choice made in conversation. /checkForceStatus
-- shows the score as one of five vague lines (`@fb_force:align_tier_1..5`) once a side has been chosen.
--
-- Shifts (data, all through FbAlignment:shift): the mercy choice ±30; kills by template fragment (Sith Shadows and
-- Dark Jedi toward the light, the enclave's Light Jedi toward the dark); killing a humanoid NPC that was neither
-- hostile nor a killer is murder (−3); the Masters' tasks carry their own shift (`align` in the task data).
--
-- Lab: FbLabTests alignment / alignmentShift / alignmentSet, checkAlignment; scenario `ranks-alignment`.

FbAlignment = {
	FLAG = "align",
	min = -100, max = 100,
	leanAt = 30,          -- |score| from which the other Master offers the turn
	killShifts = {        -- template fragment → shift (light positive)
		{ "sith_shadow", 3 },
		{ "dark_jedi", 5 },
		{ "mauler", 3 },
		{ "nightsister", 2 },
		{ "light_jedi", -5 },
	},
	murder = -3,
	tiers = {             -- lower bound → tier id (checked from the top)
		{ 60, 5 }, { 20, 4 }, { -19, 3 }, { -59, 2 }, { -100, 1 },
	},
}

function FbAlignment:score(pPlayer)
	if pPlayer == nil or FbAttunement == nil then return 0 end
	return tonumber(FbAttunement:flag(pPlayer, self.FLAG) or 0) or 0
end

function FbAlignment:tier(score)
	for _, t in ipairs(self.tiers) do if score >= t[1] then return t[2] end end
	return 1
end

-- "light" / "dark" when the score leans past leanAt, else nil
function FbAlignment:leans(pPlayer)
	local s = self:score(pPlayer)
	if s >= self.leanAt then return "light" elseif s <= -self.leanAt then return "dark" end
	return nil
end

function FbAlignment:set(pPlayer, value)
	if pPlayer == nil or FbAttunement == nil then return end
	value = math.max(self.min, math.min(self.max, math.floor(tonumber(value) or 0)))
	FbAttunement:setFlag(pPlayer, self.FLAG, value)
	return value
end

-- shift by delta (light positive); a tier crossing tells the character in the vague words
function FbAlignment:shift(pPlayer, delta, why)
	if pPlayer == nil or FbAttunement == nil or delta == nil or delta == 0 then return end
	if FbAttunement:flag(pPlayer, "alignment") == nil then return end   -- nothing moves before the choice
	local before = self:score(pPlayer)
	local after = self:set(pPlayer, before + delta)
	if self:tier(after) ~= self:tier(before) then
		CreatureObject(pPlayer):sendSystemMessage("@fb_force:align_tier_" .. self:tier(after))
	end
	printf("FbAlignment: %s %+d (%s) → %d\n", CreatureObject(pPlayer):getFirstName(), delta, tostring(why), after)
	return after
end

-- the mercy trial's choice sets the side and the first lean
function FbAlignment:onChoice(pPlayer, side)
	if pPlayer == nil then return end
	self:set(pPlayer, side == "dark" and -30 or 30)
end

-- a kill: by template, or murder
function FbAlignment:onKill(pPlayer, pVictim)
	if pPlayer == nil or pVictim == nil or FbAttunement == nil or FbAttunement:flag(pPlayer, "alignment") == nil then return end
	local path = (SceneObject(pVictim):getTemplateObjectPath() .. " " .. tostring(SceneObject(pVictim):getObjectName())):lower()
	for _, k in ipairs(self.killShifts) do
		if path:find(k[1], 1, true) then self:shift(pPlayer, k[2], "kill:" .. k[1]); return end
	end
	-- murder: a humanoid NPC (not a creature) that was neither hostile to the character nor a killer
	if SceneObject(pVictim):isAiAgent() and not SceneObject(pVictim):isCreature() then
		if not AiAgent(pVictim):isKiller() and not AiAgent(pVictim):isAggressiveTo(pPlayer) then
			self:shift(pPlayer, self.murder, "murder")
		end
	end
end

-- the status report's line (only once a side is chosen)
function FbAlignment:statusLine(pPlayer)
	if pPlayer == nil or FbAttunement == nil or FbAttunement:flag(pPlayer, "alignment") == nil then return nil end
	return "@fb_force:align_tier_" .. self:tier(self:score(pPlayer))
end

function FbAlignment:status(pPlayer)
	return string.format("align=%d tier=%d leans=%s side=%s", self:score(pPlayer), self:tier(self:score(pPlayer)), tostring(self:leans(pPlayer) or "-"), tostring(FbAttunement ~= nil and FbAttunement:flag(pPlayer, "alignment") or "-"))
end
