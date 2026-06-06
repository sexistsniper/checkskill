-- ServerScriptService/SkillCheckConfig.lua
-- Server-side config/tuning for CheckSkillService.
-- Keep reward/buff values here so the server owns the important numbers.

local SkillCheckConfig = {}

SkillCheckConfig.ActiveWindow = 8
SkillCheckConfig.BaseCooldown = 10
SkillCheckConfig.StartThrottle = 0.5
SkillCheckConfig.BuffDuration = 10
SkillCheckConfig.MaxStartDistance = 20
SkillCheckConfig.MaxStage = 3

SkillCheckConfig.StageNames = {
	[0] = "Miss",
	[1] = "Easy",
	[2] = "Medium",
	[3] = "Hard",
}

SkillCheckConfig.BoostByStage = {
	[0] = 1,
	[1] = 1.25,
	[2] = 1.5,
	[3] = 1.75,
}

local function getPrestigeNumber(player: Player, attrName: string): number
	return tonumber(player:GetAttribute(attrName)) or 0
end

function SkillCheckConfig.GetForPlayer(player: Player)
	local cooldownMult = 1 + getPrestigeNumber(player, "Prestige_SkillCheckCooldownMultiplier_Add")
	local speedMult = 1 + getPrestigeNumber(player, "Prestige_SkillCheckSpeedMultiplier_Add")
	local difficultyFlat = math.floor(getPrestigeNumber(player, "Prestige_SkillCheckDifficultyFlat_Add") + 0.5)

	return {
		cooldown = math.max(1, SkillCheckConfig.BaseCooldown * math.max(0.1, cooldownMult)),
		speedMultiplier = math.max(0.5, speedMult),
		difficultyFlat = math.max(0, difficultyFlat),
	}
end

function SkillCheckConfig.ClampStage(stage: any): number
	stage = tonumber(stage) or 0
	stage = math.floor(stage)

	if stage < 0 then
		return 0
	end

	if stage > SkillCheckConfig.MaxStage then
		return SkillCheckConfig.MaxStage
	end

	return stage
end

function SkillCheckConfig.GetBoost(stage: any): number
	stage = SkillCheckConfig.ClampStage(stage)
	return SkillCheckConfig.BoostByStage[stage] or 1
end

function SkillCheckConfig.GetStageName(stage: any): string
	stage = SkillCheckConfig.ClampStage(stage)
	return SkillCheckConfig.StageNames[stage] or "Unknown"
end

return SkillCheckConfig

