--!strict

local RunService = game:GetService("RunService")

local CompanionService = {}

function CompanionService.create()
	local model = Instance.new("Model")
	model.Name, model.Parent = "Morrow", workspace
	local root = Instance.new("Part")
	root.Name, root.Anchored, root.CanCollide = "Core", true, false
	root.Shape, root.Size, root.Color, root.Material =
		Enum.PartType.Ball, Vector3.new(5, 5, 5), Color3.fromRGB(118, 217, 202), Enum.Material.Neon
	root.CFrame, root.Parent, model.PrimaryPart = CFrame.new(0, 5, -15), model, root
	local glow = Instance.new("PointLight")
	glow.Brightness, glow.Color, glow.Range, glow.Shadows, glow.Parent =
		1.4, root.Color, 18, true, root

	local face = {}
	for _, data in
		{
			{ "LeftEye", Vector3.new(0.5, 0.85, 0.25) },
			{ "RightEye", Vector3.new(0.5, 0.85, 0.25) },
			{ "Smile", Vector3.new(1.65, 0.24, 0.25) },
		}
	do
		local item = Instance.new("Part")
		item.Name, item.Anchored, item.CanCollide, item.CastShadow =
			data[1] :: string, true, false, false
		item.Color, item.Material, item.Size, item.Parent =
			Color3.fromRGB(20, 18, 26), Enum.Material.SmoothPlastic, data[2] :: Vector3, model
		face[item.Name] = item
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText, prompt.ObjectText, prompt.HoldDuration, prompt.MaxActivationDistance =
		"Talk", "Morrow", 0.25, 12
	prompt.RequiresLineOfSight, prompt.Parent = false, root

	local target: Vector3? = nil
	local hunting, elapsed = false, 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if target then
			local delta = target - root.Position
			if delta.Magnitude > 0.05 then
				root.Position += delta.Unit * math.min(
					delta.Magnitude,
					(if hunting then 14 else 5) * dt
				)
			end
		end
		root.Position += Vector3.new(0, math.sin(elapsed * 2.2) * 0.004, 0)
		local forward, right = root.CFrame.LookVector, root.CFrame.RightVector
		local center = root.Position + forward * 2.35
		face.LeftEye.CFrame =
			CFrame.lookAt(center - right * 0.75 + Vector3.new(0, 0.55, 0), center + forward)
		face.RightEye.CFrame =
			CFrame.lookAt(center + right * 0.75 + Vector3.new(0, 0.55, 0), center + forward)
		face.Smile.CFrame = CFrame.lookAt(center - Vector3.new(0, 0.65, 0), center + forward)
	end)
	return {
		model = model,
		root = root,
		prompt = prompt,
		setTarget = function(position: Vector3)
			target = position
		end,
		setHunting = function(value: boolean)
			hunting, prompt.Enabled = value, not value
			root.Color = if value
				then Color3.fromRGB(194, 32, 69)
				else Color3.fromRGB(118, 217, 202)
			glow.Color, glow.Brightness = root.Color, if value then 3 else 1.4
			face.Smile.Size = if value
				then Vector3.new(2.8, 0.38, 0.3)
				else Vector3.new(1.65, 0.24, 0.25)
		end,
	}
end

return CompanionService
