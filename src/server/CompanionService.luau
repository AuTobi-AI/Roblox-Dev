--!strict

local RunService = game:GetService("RunService")

export type Controller = {
	model: Model,
	root: Part,
	prompt: ProximityPrompt,
	setTarget: (position: Vector3) -> (),
	setPosition: (position: Vector3) -> (),
	setHunting: (value: boolean) -> (),
	setThinking: (value: boolean) -> (),
	destroy: () -> (),
}

local FRIENDLY_COLOR = Color3.fromRGB(118, 217, 202)
local HUNT_COLOR = Color3.fromRGB(194, 32, 69)
local FACE_COLOR = Color3.fromRGB(20, 18, 26)
local CompanionService = {}

local function makeFacePart(parent: Model, name: string, size: Vector3): Part
	local item = Instance.new("Part")
	item.Name = name
	item.Anchored = true
	item.CanCollide = false
	item.CanQuery = false
	item.CastShadow = false
	item.Color = FACE_COLOR
	item.Material = Enum.Material.SmoothPlastic
	item.Size = size
	item.Parent = parent
	return item
end

function CompanionService.create(startPosition: Vector3?): Controller
	local model = Instance.new("Model")
	model.Name = "Morrow"
	model.Parent = workspace

	local root = Instance.new("Part")
	root.Name = "Core"
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.Size = Vector3.new(5, 1.8, 1.8)
	root.Color = FRIENDLY_COLOR
	root.Material = Enum.Material.Neon
	root.CFrame = CFrame.new(startPosition or Vector3.new(0, 5, -11))
	root.Parent = model
	model.PrimaryPart = root

	local leftBell = Instance.new("Part")
	leftBell.Name = "LeftBell"
	leftBell.Anchored = true
	leftBell.CanCollide = false
	leftBell.CanQuery = false
	leftBell.Shape = Enum.PartType.Ball
	leftBell.Size = Vector3.new(1.8, 2.7, 2.4)
	leftBell.Color = FRIENDLY_COLOR
	leftBell.Material = Enum.Material.SmoothPlastic
	leftBell.Parent = model

	local rightBell = leftBell:Clone()
	rightBell.Name = "RightBell"
	rightBell.Parent = model

	local glow = Instance.new("PointLight")
	glow.Name = "Glow"
	glow.Brightness = 1.4
	glow.Color = FRIENDLY_COLOR
	glow.Range = 18
	glow.Shadows = true
	glow.Parent = root

	local leftEye = makeFacePart(model, "LeftEye", Vector3.new(0.5, 0.85, 0.25))
	local rightEye = makeFacePart(model, "RightEye", Vector3.new(0.5, 0.85, 0.25))
	local smile = makeFacePart(model, "Smile", Vector3.new(1.65, 0.24, 0.25))

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TalkPrompt"
	prompt.ActionText = "Talk"
	prompt.ObjectText = "Morrow"
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = root

	local thinkingGui = Instance.new("BillboardGui")
	thinkingGui.Name = "ThinkingIndicator"
	thinkingGui.AlwaysOnTop = true
	thinkingGui.Enabled = false
	thinkingGui.LightInfluence = 0
	thinkingGui.Size = UDim2.fromOffset(90, 34)
	thinkingGui.StudsOffset = Vector3.new(0, 3.5, 0)
	thinkingGui.Parent = root

	local thinkingLabel = Instance.new("TextLabel")
	thinkingLabel.BackgroundColor3 = Color3.fromRGB(9, 15, 18)
	thinkingLabel.BackgroundTransparency = 0.2
	thinkingLabel.Font = Enum.Font.GothamMedium
	thinkingLabel.Size = UDim2.fromScale(1, 1)
	thinkingLabel.Text = "thinking…"
	thinkingLabel.TextColor3 = Color3.fromRGB(202, 247, 239)
	thinkingLabel.TextScaled = true
	thinkingLabel.Parent = thinkingGui
	local thinkingCorner = Instance.new("UICorner")
	thinkingCorner.CornerRadius = UDim.new(0, 10)
	thinkingCorner.Parent = thinkingLabel

	local targetPosition: Vector3? = nil
	local logicalPosition = root.Position
	local isHunting = false
	local elapsed = 0
	local destroyed = false
	local heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		if destroyed then
			return
		end
		elapsed += deltaTime
		if targetPosition then
			local delta = targetPosition - logicalPosition
			if delta.Magnitude > 0.05 then
				local speed = if isHunting then 14 else 5
				logicalPosition += delta.Unit * math.min(delta.Magnitude, speed * deltaTime)
			end
		end
		root.CFrame =
			CFrame.new(logicalPosition + Vector3.new(0, math.sin(elapsed * 2.2) * 0.08, 0))

		local forward, right = root.CFrame.LookVector, root.CFrame.RightVector
		leftBell.CFrame = root.CFrame * CFrame.new(-2.35, 0, 0)
		rightBell.CFrame = root.CFrame * CFrame.new(2.35, 0, 0)
		local faceCenter = root.Position + forward * 0.95
		leftEye.CFrame =
			CFrame.lookAt(faceCenter - right * 0.75 + Vector3.new(0, 0.55, 0), faceCenter + forward)
		rightEye.CFrame =
			CFrame.lookAt(faceCenter + right * 0.75 + Vector3.new(0, 0.55, 0), faceCenter + forward)
		smile.CFrame = CFrame.lookAt(faceCenter - Vector3.new(0, 0.65, 0), faceCenter + forward)
	end)

	return {
		model = model,
		root = root,
		prompt = prompt,
		setTarget = function(position: Vector3)
			targetPosition = position
		end,
		setPosition = function(position: Vector3)
			logicalPosition = position
			targetPosition = position
		end,
		setHunting = function(value: boolean)
			isHunting = value
			prompt.Enabled = not value
			root.Color = if value then HUNT_COLOR else FRIENDLY_COLOR
			leftBell.Color = root.Color
			rightBell.Color = root.Color
			glow.Color = root.Color
			glow.Brightness = if value then 3 else 1.4
			smile.Size = if value
				then Vector3.new(2.8, 0.38, 0.3)
				else Vector3.new(1.65, 0.24, 0.25)
		end,
		setThinking = function(value: boolean)
			thinkingGui.Enabled = value
		end,
		destroy = function()
			if destroyed then
				return
			end
			destroyed = true
			heartbeatConnection:Disconnect()
			model:Destroy()
		end,
	}
end

return CompanionService
