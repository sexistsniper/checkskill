-- ServerScriptService/CheckSkillService.server.lua
-- Cleaned server-side companion for the CheckSkill client script.
-- Extracted from the live MegaLogic SkillCheckSystem and separated for review.
-- The client only shows UI/input. This server validates the request, starts the check,
-- receives the result, clamps the stage, applies cooldowns, and applies the buff safely.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillCheckConfig = require(script.Parent:WaitForChild("SkillCheckConfig"))

local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "Remotes"
	Remotes.Parent = ReplicatedStorage
end

local function getOrCreateRemoteEvent(name: string): RemoteEvent
	local existing = Remotes:FindFirstChild(name)

	if existing and existing:IsA("RemoteEvent") then
		return existing
	end

	if existing then
		existing:Destroy()
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = Remotes
	return remote
end

local NotifyRE = getOrCreateRemoteEvent("Notify")
local SkillStartRE = getOrCreateRemoteEvent("StartSkillCheck")
local SkillResultRE = getOrCreateRemoteEvent("SkillCheckResult")
local RequestStartRE = getOrCreateRemoteEvent("RequestSkillCheck")

local AllFunctions = require(game.ServerScriptService:WaitForChild("modules"):WaitForChild("AllFunctions"))

local activeChecks = {} :: {
	[Player]: {
		farm: Model,
		expires: number,
		config: {},
		bypassCooldown: boolean,
	}
}

local playerLastCheck = {} :: { [Player]: number }
local playerStartThrottle = {} :: { [Player]: number }

local function notify(player: Player, text: string, kind: string?, duration: number?)
	if not player or not player.Parent then
		return
	end

	NotifyRE:FireClient(player, {
		text = text,
		type = kind or "info",
		time = duration or 1.6,
	})
end

local function getPlayerPlot(player: Player): Instance?
	local plotFinder = AllFunctions.PlotFinder
	if not plotFinder then
		return nil
	end

	if plotFinder.GetPlayerPlot then
		return plotFinder.GetPlayerPlot(player)
	end

	if plotFinder.GetPlotForPlayer then
		return plotFinder.GetPlotForPlayer(player)
	end

	return nil
end

local function canStartSkillCheck(player: Player): boolean
	local gameplayMode = AllFunctions.GameplayMode

	if gameplayMode and gameplayMode.CanStartSkillCheck then
		return gameplayMode.CanStartSkillCheck(player) == true
	end

	return true
end

local function applySkillBuff(player: Player, farm: Model, boost: number, duration: number): boolean
	local gameplayMode = AllFunctions.GameplayMode

	if gameplayMode and gameplayMode.ApplySkillBuff then
		return gameplayMode.ApplySkillBuff(player, farm, boost, duration) == true
	end

	-- Fallback for showcase/testing if the full gameplay module is not present.
	player:SetAttribute("HasSkillBuff", true)
	player:SetAttribute("SkillBuffBoost", boost)
	player:SetAttribute("SkillBuffExpiresAt", os.clock() + duration)

	task.delay(duration, function()
		if player.Parent and (tonumber(player:GetAttribute("SkillBuffExpiresAt")) or 0) <= os.clock() then
			player:SetAttribute("HasSkillBuff", false)
			player:SetAttribute("SkillBuffBoost", 1)
		end
	end)

	return true
end

local function isStackWindowActive(player: Player): boolean
	local activeStacks = tonumber(player:GetAttribute("SkillBuffStacksActive")) or 0
	local maxStacks = tonumber(player:GetAttribute("SkillBuffMaxStacks")) or 1

	return activeStacks > 0 and activeStacks < maxStacks
end

local function resolveRequestedFarm(plot: Instance, farmName: any): Model?
	if typeof(farmName) ~= "string" or farmName == "" then
		return nil
	end

	local direct = plot:FindFirstChild(farmName)
	if direct and direct:IsA("Model") then
		return direct
	end

	local farmFolder = plot:FindFirstChild("farm")
	if farmFolder then
		local nested = farmFolder:FindFirstChild(farmName)
		if nested and nested:IsA("Model") then
			return nested
		end
	end

	for _, descendant in ipairs(plot:GetDescendants()) do
		if descendant:IsA("Model") and descendant.Name == farmName and descendant:FindFirstChild("SpawnRocket", true) then
			return descendant
		end
	end

	return nil
end

local function getSkillCheckAnchorPosition(farm: Model): Vector3?
	local prompt = farm:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		local promptParent = prompt.Parent

		if promptParent and promptParent:IsA("Attachment") then
			return promptParent.WorldPosition
		end

		if promptParent and promptParent:IsA("BasePart") then
			return promptParent.Position
		end
	end

	for _, targetName in ipairs({ "Head", "PromptPart", "HumanoidRootPart", "SpawnRocket" }) do
		local target = farm:FindFirstChild(targetName, true)
		if target and target:IsA("BasePart") then
			return target.Position
		end
	end

	local fallback = farm:FindFirstChildWhichIsA("BasePart", true)
	return fallback and fallback.Position or nil
end

local function ownsFarm(player: Player, farm: Model): boolean
	local ownerId = farm:GetAttribute("OwnerUserId")
	if ownerId ~= nil and ownerId ~= player.UserId then
		return false
	end

	local ownerName = farm:GetAttribute("OwnerName")
	if ownerName ~= nil and ownerName ~= player.Name then
		return false
	end

	local ownerValue = farm:FindFirstChild("Owner")
	if ownerValue and ownerValue:IsA("ObjectValue") and ownerValue.Value ~= player then
		return false
	end

	local ownerNameValue = farm:FindFirstChild("Ownername")
	if ownerNameValue and ownerNameValue:IsA("StringValue") and ownerNameValue.Value ~= player.Name then
		return false
	end

	return true
end

local function isPlayerNearFarm(player: Player, farm: Model): boolean
	local character = player.Character
	if not character then
		return false
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end

	local anchorPosition = getSkillCheckAnchorPosition(farm)
	if not anchorPosition then
		return false
	end

	return (root.Position - anchorPosition).Magnitude <= SkillCheckConfig.MaxStartDistance
end

local function validateStartRequest(player: Player, farmName: any): (boolean, Model?)
	local plot = getPlayerPlot(player)
	if not plot then
		return false, nil
	end

	local farm = resolveRequestedFarm(plot, farmName)
	if not farm then
		return false, nil
	end

	if not ownsFarm(player, farm) then
		return false, nil
	end

	if not isPlayerNearFarm(player, farm) then
		return false, nil
	end

	if not farm:FindFirstChild("SpawnRocket", true) then
		return false, nil
	end

	if not canStartSkillCheck(player) then
		notify(player, "Skill check blocked right now.", "warn", 1.4)
		return false, nil
	end

	return true, farm
end

local function canPassStartThrottle(player: Player, now: number): boolean
	local lastStart = playerStartThrottle[player] or 0

	if (now - lastStart) < SkillCheckConfig.StartThrottle then
		return false
	end

	playerStartThrottle[player] = now
	return true
end

local function canPassCooldown(player: Player, now: number, cooldown: number, bypassCooldown: boolean): boolean
	if bypassCooldown then
		return true
	end

	local lastClear = playerLastCheck[player] or 0
	if (now - lastClear) >= cooldown then
		return true
	end

	local waitLeft = math.ceil(cooldown - (now - lastClear))
	notify(player, "Skill Check cooldown (" .. waitLeft .. "s)", "warn", 1.4)
	return false
end

RequestStartRE.OnServerEvent:Connect(function(player: Player, farmName: any)
	local now = os.clock()

	if activeChecks[player] then
		return
	end

	if not canPassStartThrottle(player, now) then
		return
	end

	local ok, farm = validateStartRequest(player, farmName)
	if not ok or not farm then
		return
	end

	local config = SkillCheckConfig.GetForPlayer(player)
	local bypassCooldown = isStackWindowActive(player)

	if not canPassCooldown(player, now, config.cooldown, bypassCooldown) then
		return
	end

	activeChecks[player] = {
		farm = farm,
		expires = now + SkillCheckConfig.ActiveWindow,
		config = config,
		bypassCooldown = bypassCooldown,
	}

	SkillStartRE:FireClient(player, {
		farmName = farm.Name,
		speedMultiplier = config.speedMultiplier,
		difficultyFlat = config.difficultyFlat,
	})
end)

SkillResultRE.OnServerEvent:Connect(function(player: Player, data: any)
	if typeof(data) ~= "table" then
		return
	end

	local state = activeChecks[player]
	if not state then
		return
	end

	activeChecks[player] = nil

	if os.clock() > state.expires then
		return
	end

	local farm = state.farm
	if not farm or not farm.Parent then
		return
	end

	if not ownsFarm(player, farm) or not isPlayerNearFarm(player, farm) then
		return
	end

	local now = os.clock()
	local config = state.config or SkillCheckConfig.GetForPlayer(player)
	local bypassCooldown = state.bypassCooldown == true

	if not canPassCooldown(player, now, config.cooldown, bypassCooldown) then
		return
	end

	if not bypassCooldown then
		playerLastCheck[player] = now
	end

	local stage = SkillCheckConfig.ClampStage(data.stage)
	if stage <= 0 then
		notify(player, "Miss...", "warn", 1.0)
		return
	end

	local boost = SkillCheckConfig.GetBoost(stage)
	local applied = applySkillBuff(player, farm, boost, SkillCheckConfig.BuffDuration)

	if not applied then
		notify(player, "No more buff stacks available.", "warn", 1.4)
		return
	end

	notify(player, string.format("Skill Check: %s clear! Boost x%s", SkillCheckConfig.GetStageName(stage), tostring(boost)), "success", 1.4)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	activeChecks[player] = nil
	playerLastCheck[player] = nil
	playerStartThrottle[player] = nil
end)

