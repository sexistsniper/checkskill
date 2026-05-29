-- Connected Discord-GitHub
-- This script handles the client-side skill check minigame used when interacting with farms.
-- It replaces the default proximity prompt with a custom UI, starts the minigame,
-- scales difficulty by stage, and reports the result back to the server.

local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local ProxyPromptUI = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ProxyPromptUI"))
local SoundTable = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("SoundTable"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local guiFolder = playerGui:FindFirstChild("Gui")

local function getScreenGui(name)
	if guiFolder and guiFolder:FindFirstChild(name) then
		return guiFolder:WaitForChild(name)
	end

	return playerGui:WaitForChild(name)
end

local gui = getScreenGui("autofarmshop")
local canva = gui:WaitForChild("canva")
local check = canva:WaitForChild("check")
local frame = check:WaitForChild("Frame")
local circle = frame:WaitForChild("Circle")
local zoneFolder = circle:WaitForChild("ZoneFolder")
local left = zoneFolder:WaitForChild("LeftArcHolder")
local right = zoneFolder:WaitForChild("RightArcHolder")
local needle = circle:WaitForChild("Needle")
local difficultyLabel = frame:FindFirstChild("Difficulty")

local proxyPrompt = canva:WaitForChild("proxytest")
local proxyPromptController = ProxyPromptUI.new(proxyPrompt)

local BASE_LEFT_ROTATION = left.Rotation
local RANDOM_OFFSET_X = 110
local RANDOM_OFFSET_Y = 70

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:WaitForChild("RemoteEvent")
local SkillCheckResult = remotesFolder:WaitForChild("SkillCheckResult")
local SkillStart = remotesFolder:WaitForChild("StartSkillCheck")
local RequestSkillCheck = remotesFolder:WaitForChild("RequestSkillCheck")

local STAGE_NAMES = {
	[1] = "Easy",
	[2] = "Medium",
	[3] = "Hard",
}

local BOOST_BY_STAGE = {
	[1] = 1.25,
	[2] = 1.5,
	[3] = 1.75,
}

local BASE_STAGE_SIZES = { 126, 45, 12 }
local BASE_STAGE_SPEEDS = { 165, 245, 330 }

local active = false
local currentStage = 0
local maxStageReached = 0
local rotation = 0
local speed = 180
local currentConfig = {
	speedMultiplier = 1,
	difficultyFlat = 0,
}

local hiddenCanvaStates = {}
local hiddenScreenGuiStates = {}
local hiddenPromptStates = {}
local shownSkillPrompt = nil

check.Visible = false
frame.Visible = false
proxyPrompt.Visible = false

if difficultyLabel then
	difficultyLabel.Text = ""
end

-- This helper is used to prevent the skill check from starting while another combat-style state is active.
local function hasCombo()
	return player:GetAttribute("HasCombo") == true
end

-- Nuke prompts are only useful if the player is holding the correct tool,
-- so this helper lets the client hide or restore those prompts dynamically.
local function isHoldingTool()
	local character = player.Character
	if not character then
		return false
	end

	return character:FindFirstChildWhichIsA("Tool") ~= nil
end

local function isCustomProxyPrompt(prompt)
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return false
	end

	local customType = prompt:GetAttribute("CustomPromptType")
	if customType == "SkillCheck" or customType == "Nuke" then
		return true
	end

	local actionText = string.lower(tostring(prompt.ActionText or ""))
	return actionText == "start skillcheck" or actionText == "skill check" or actionText == "nuke!"
end

local function isNukePrompt(prompt)
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return false
	end

	if prompt:GetAttribute("CustomPromptType") == "Nuke" then
		return true
	end

	local actionText = string.lower(tostring(prompt.ActionText or ""))
	return actionText == "nuke!"
end

local function isSkillCheckPrompt(prompt)
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return false
	end

	if prompt:GetAttribute("CustomPromptType") == "SkillCheck" then
		return true
	end

	local actionText = string.lower(tostring(prompt.ActionText or ""))
	return actionText == "start skillcheck" or actionText == "skill check"
end

local function getPromptKeyText(prompt, inputType)
	if inputType == Enum.ProximityPromptInputType.Gamepad then
		local gamepadCode = prompt.GamepadKeyCode
		if gamepadCode and gamepadCode ~= Enum.KeyCode.Unknown then
			return gamepadCode.Name
		end
	end

	local keyCode = prompt.KeyboardKeyCode
	if keyCode and keyCode ~= Enum.KeyCode.Unknown then
		return keyCode.Name
	end

	return "E"
end

-- This function calculates where the custom prompt should appear in screen space.
-- It supports prompts parented to Attachments, BaseParts, or Models.
local function getPromptWorldPosition(prompt)
	local parent = prompt and prompt.Parent
	if not parent then
		return nil
	end

	if parent:IsA("Attachment") then
		return parent.WorldPosition
	end

	if parent:IsA("BasePart") then
		return parent.Position + Vector3.new(0, (parent.Size.Y * 0.75) + 0.75, 0)
	end

	local model = prompt:FindFirstAncestorOfClass("Model")
	if model then
		local ok, cf, size = pcall(function()
			return model:GetBoundingBox()
		end)

		if ok and cf and size then
			return cf.Position + Vector3.new(0, (size.Y * 0.55) + 0.75, 0)
		end
	end

	return nil
end

local function updateProxyPromptPosition()
	if not shownSkillPrompt then
		return
	end

	local worldPosition = getPromptWorldPosition(shownSkillPrompt)
	local camera = workspace.CurrentCamera
	if not worldPosition or not camera then
		return
	end

	local viewportPosition, onScreen = camera:WorldToViewportPoint(worldPosition)
	if onScreen and viewportPosition.Z > 0 then
		proxyPromptController:UpdatePosition(shownSkillPrompt, viewportPosition)
	else
		proxyPromptController:UpdatePosition(shownSkillPrompt, nil)
	end
end

local function hideProxyPrompt(prompt)
	if prompt and shownSkillPrompt ~= prompt then
		return
	end

	shownSkillPrompt = nil
	proxyPromptController:Hide(prompt)
	proxyPrompt.Visible = false
end

-- This replaces the default Roblox prompt with a custom prompt that fits the game's UI style.
local function showProxyPrompt(prompt, inputType)
	if active or not isCustomProxyPrompt(prompt) then
		return
	end

	if isNukePrompt(prompt) and not isHoldingTool() then
		hideProxyPrompt(prompt)
		return
	end

	shownSkillPrompt = prompt
	proxyPrompt.Visible = true

	proxyPromptController:Show({
		prompt = prompt,
		text = tostring(prompt.ActionText ~= "" and prompt.ActionText or "Start Skillcheck"),
		keyText = getPromptKeyText(prompt, inputType),
	})

	updateProxyPromptPosition()
end

local function playProxyHold(prompt)
	if prompt ~= shownSkillPrompt then
		return
	end

	proxyPromptController:BeginHold(prompt, prompt.HoldDuration)
end

-- The popup is randomly offset near the center so repeated use feels less static.
local function placeCheckPopup()
	local parentGuiObject = check.Parent
	if not parentGuiObject or not parentGuiObject:IsA("GuiObject") then
		check.Position = UDim2.fromScale(0.5, 0.5)
		return
	end

	local parentSize = parentGuiObject.AbsoluteSize
	if parentSize.X <= 0 or parentSize.Y <= 0 then
		check.Position = UDim2.fromScale(0.5, 0.5)
		return
	end

	check.AnchorPoint = Vector2.new(0.5, 0.5)

	local halfWidth = math.floor(check.AbsoluteSize.X * 0.5)
	local halfHeight = math.floor(check.AbsoluteSize.Y * 0.5)
	local maxX = math.max(0, math.min(RANDOM_OFFSET_X, math.floor(parentSize.X * 0.5) - halfWidth - 8))
	local maxY = math.max(0, math.min(RANDOM_OFFSET_Y, math.floor(parentSize.Y * 0.5) - halfHeight - 8))
	local centerX = math.floor(parentSize.X * 0.5)
	local centerY = math.floor(parentSize.Y * 0.5)
	local offsetX = math.random(-maxX, maxX)
	local offsetY = math.random(-maxY, maxY)

	check.Position = UDim2.fromOffset(centerX + offsetX, centerY + offsetY)
end

-- While the minigame is active, unrelated UI and prompts are hidden.
-- This reduces visual noise and prevents overlapping interactions.
local function setFocusMode(enabled)
	if enabled then
		table.clear(hiddenCanvaStates)
		table.clear(hiddenScreenGuiStates)
		table.clear(hiddenPromptStates)
		hideProxyPrompt(shownSkillPrompt)

		for _, child in ipairs(canva:GetChildren()) do
			if child ~= check and child:IsA("GuiObject") then
				hiddenCanvaStates[child] = child.Visible
				child.Visible = false
			end
		end

		for _, child in ipairs(playerGui:GetChildren()) do
			if child:IsA("ScreenGui") and child ~= gui then
				hiddenScreenGuiStates[child] = child.Enabled
				child.Enabled = false
			end
		end

		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj:IsA("ProximityPrompt") then
				hiddenPromptStates[obj] = obj.Enabled
				obj.Enabled = false
			end
		end
	else
		for obj, wasVisible in pairs(hiddenCanvaStates) do
			if obj and obj.Parent then
				obj.Visible = wasVisible
			end
		end
		table.clear(hiddenCanvaStates)

		for guiObject, wasEnabled in pairs(hiddenScreenGuiStates) do
			if guiObject and guiObject.Parent then
				guiObject.Enabled = wasEnabled
			end
		end
		table.clear(hiddenScreenGuiStates)

		for prompt, wasEnabled in pairs(hiddenPromptStates) do
			if prompt and prompt.Parent then
				prompt.Enabled = wasEnabled
			end
		end
		table.clear(hiddenPromptStates)
	end
end

local function normalizeAngle(angle)
	return ((angle % 360) + 360) % 360
end

-- The safe area is the open gap between two blocked arc segments.
-- Because the arc can wrap around 0/360, the angle comparison has to handle wrap-around correctly.
local function isAngleBetween(angle, startAngle, endAngle)
	angle = normalizeAngle(angle)
	startAngle = normalizeAngle(startAngle)
	endAngle = normalizeAngle(endAngle)

	if startAngle <= endAngle then
		return angle >= startAngle and angle <= endAngle
	end

	return angle >= startAngle or angle <= endAngle
end

local function getCoveredByLeft(angle)
	local start = zoneFolder.Rotation + left.Rotation
	return isAngleBetween(angle, start, start + 180)
end

local function getCoveredByRight(angle)
	local start = zoneFolder.Rotation + right.Rotation
	return isAngleBetween(angle, start, start + 180)
end

local function updateDifficultyLabel(stage)
	if difficultyLabel then
		difficultyLabel.Text = STAGE_NAMES[stage] or ""
	end
end

local function playSkillSuccessSound()
	local sound = Instance.new("Sound")
	sound.Name = "SkillCheckSuccessOneShot"
	sound.SoundId = SoundTable.Pop
	sound.Volume = 0.12
	sound.Parent = SoundService
	sound:Play()

	Debris:AddItem(sound, 3)
end

-- The zone is rotated randomly every stage so players cannot rely on a fixed timing pattern.
local function setupZone(visibleSize)
	visibleSize = math.clamp(visibleSize, 25, 180)

	local startGap = 180 - visibleSize
	left.Rotation = BASE_LEFT_ROTATION
	right.Rotation = BASE_LEFT_ROTATION + startGap
	zoneFolder.Rotation = math.random(0, 359)
end

-- The server can send modifiers into the client config, allowing the same minigame
-- to scale for progression without needing separate scripts for each difficulty.
local function setupStage(stage)
	local difficultyFlat = math.max(0, tonumber(currentConfig.difficultyFlat) or 0)
	local speedMultiplier = math.max(0.5, tonumber(currentConfig.speedMultiplier) or 1)

	local visibleSize = (BASE_STAGE_SIZES[stage] or 12) - (difficultyFlat * 4)
	speed = (BASE_STAGE_SPEEDS[stage] or 330) * speedMultiplier

	updateDifficultyLabel(stage)
	setupZone(visibleSize)
end

local function finishSkillCheck(stageCleared)
	active = false
	check.Visible = false
	frame.Visible = false
	setFocusMode(false)
	updateDifficultyLabel(nil)

	-- The client only reports the best cleared stage and its multiplier.
	-- The server remains responsible for validating and applying rewards.
	SkillCheckResult:FireServer({
		stage = stageCleared,
		boost = BOOST_BY_STAGE[stageCleared] or 1,
	})
end

local function startSkillCheck(data)
	if active or hasCombo() then
		return
	end

	currentConfig = data or currentConfig
	active = true
	currentStage = 1
	maxStageReached = 0
	rotation = math.random(0, 359)
	needle.Rotation = rotation

	hideProxyPrompt(shownSkillPrompt)
	placeCheckPopup()
	setFocusMode(true)
	check.Visible = true
	frame.Visible = true
	setupStage(currentStage)
end

RunService.RenderStepped:Connect(function(dt)
	if shownSkillPrompt and not active then
		updateProxyPromptPosition()
	end

	if not active then
		return
	end

	rotation += speed * dt
	needle.Rotation = normalizeAngle(rotation)
end)

-- This is the core success/failure check.
-- A successful press happens only if the needle is inside the open space between both blocked arcs.
local function checkSkill()
	if not active then
		return
	end

	local needleAngle = normalizeAngle(needle.Rotation)
	local inLeft = getCoveredByLeft(needleAngle)
	local inRight = getCoveredByRight(needleAngle)
	local success = not inLeft and not inRight

	if success then
		playSkillSuccessSound()
		maxStageReached = currentStage

		if currentStage < 3 then
			currentStage += 1
			setupStage(currentStage)
			return
		end
	end

	finishSkillCheck(maxStageReached)
end

UIS.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not active then
		return
	end

	if input.KeyCode == Enum.KeyCode.E or input.UserInputType == Enum.UserInputType.MouseButton1 then
		checkSkill()
	end
end)

-- Prompts are bound once per client to avoid duplicate connections and unnecessary repeated logic.
local function bindPrompt(prompt)
	if not prompt:IsA("ProximityPrompt") then
		return
	end

	if isCustomProxyPrompt(prompt) then
		prompt.Style = Enum.ProximityPromptStyle.Custom
	end

	if prompt:GetAttribute("__BoundClient") then
		return
	end

	prompt:SetAttribute("__BoundClient", true)

	if not isSkillCheckPrompt(prompt) then
		return
	end

	prompt.Triggered:Connect(function(triggeringPlayer)
		if triggeringPlayer ~= player then
			return
		end

		if hasCombo() then
			return
		end

		local farmModel = prompt:FindFirstAncestorOfClass("Model")
		if farmModel then
			RequestSkillCheck:FireServer(farmModel.Name)
		end
	end)
end

for _, obj in ipairs(workspace:GetDescendants()) do
	if obj:IsA("ProximityPrompt") then
		bindPrompt(obj)
	end
end

workspace.DescendantAdded:Connect(function(obj)
	if obj:IsA("ProximityPrompt") then
		bindPrompt(obj)

		if active then
			hiddenPromptStates[obj] = obj.Enabled
			obj.Enabled = false
		end
	end
end)

ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
	if isCustomProxyPrompt(prompt) then
		showProxyPrompt(prompt, inputType)
	end
end)

ProximityPromptService.PromptHidden:Connect(function(prompt)
	if isCustomProxyPrompt(prompt) then
		hideProxyPrompt(prompt)
	end
end)

ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
	if isCustomProxyPrompt(prompt) then
		playProxyHold(prompt)
	end
end)

ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
	if isCustomProxyPrompt(prompt) then
		proxyPromptController:ResetProgress()
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if isCustomProxyPrompt(prompt) then
		hideProxyPrompt(prompt)
	end
end)

local function refreshShownNukePrompt()
	if shownSkillPrompt and isNukePrompt(shownSkillPrompt) and not isHoldingTool() then
		hideProxyPrompt(shownSkillPrompt)
	end
end

local function tryShowNearbyNukePrompt()
	if not isHoldingTool() or active or shownSkillPrompt then
		return
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("ProximityPrompt") and isNukePrompt(obj) and obj.Enabled then
			local worldPosition = getPromptWorldPosition(obj)
			local maxDistance = obj.MaxActivationDistance > 0 and obj.MaxActivationDistance or 10

			if worldPosition and (worldPosition - rootPart.Position).Magnitude <= (maxDistance + 1.5) then
				showProxyPrompt(obj, Enum.ProximityPromptInputType.Keyboard)
				return
			end
		end
	end
end

player.CharacterAdded:Connect(function(character)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			updateProxyPromptPosition()
			tryShowNearbyNukePrompt()
		end
	end)

	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			refreshShownNukePrompt()
		end
	end)
end)

if player.Character then
	player.Character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			refreshShownNukePrompt()
		end
	end)

	player.Character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			tryShowNearbyNukePrompt()
		end
	end)

	tryShowNearbyNukePrompt()
end

SkillStart.OnClientEvent:Connect(function(data)
	startSkillCheck(data)
end)
