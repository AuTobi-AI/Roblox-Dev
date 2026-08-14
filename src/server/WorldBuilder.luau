--!strict

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local WorldBuilder = {}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local item = Instance.new("Part")
	item.Name, item.Anchored, item.Size, item.Position = name, true, size, position
	item.Color, item.Material, item.Parent = color, material, parent
	return item
end

function WorldBuilder.build(): Folder
	local old = Workspace:FindFirstChild("GeneratedWorld")
	if old then
		old:Destroy()
	end
	local world = Instance.new("Folder")
	world.Name, world.Parent = "GeneratedWorld", Workspace

	Workspace.Baseplate.Color, Workspace.Baseplate.Material =
		Color3.fromRGB(18, 24, 25), Enum.Material.Ground
	local cabin = Instance.new("Model")
	cabin.Name, cabin.Parent = "AbandonedCabin", world
	local wood = Color3.fromRGB(55, 40, 34)
	part(
		cabin,
		"Floor",
		Vector3.new(24, 1, 20),
		Vector3.new(0, 0.5, -34),
		wood,
		Enum.Material.WoodPlanks
	)
	part(
		cabin,
		"BackWall",
		Vector3.new(24, 12, 1),
		Vector3.new(0, 6, -44),
		wood,
		Enum.Material.WoodPlanks
	)
	part(
		cabin,
		"LeftWall",
		Vector3.new(1, 12, 20),
		Vector3.new(-12, 6, -34),
		wood,
		Enum.Material.WoodPlanks
	)
	part(
		cabin,
		"RightWall",
		Vector3.new(1, 12, 20),
		Vector3.new(12, 6, -34),
		wood,
		Enum.Material.WoodPlanks
	)
	part(
		cabin,
		"FrontLeft",
		Vector3.new(8, 12, 1),
		Vector3.new(-8, 6, -24),
		wood,
		Enum.Material.WoodPlanks
	)
	part(
		cabin,
		"FrontRight",
		Vector3.new(8, 12, 1),
		Vector3.new(8, 6, -24),
		wood,
		Enum.Material.WoodPlanks
	)
	part(
		cabin,
		"Roof",
		Vector3.new(28, 1, 24),
		Vector3.new(0, 12.5, -34),
		Color3.fromRGB(25, 24, 27),
		Enum.Material.Slate
	)
	local lamp = part(
		cabin,
		"Lamp",
		Vector3.one,
		Vector3.new(0, 7, -35),
		Color3.fromRGB(255, 192, 99),
		Enum.Material.Neon
	)
	lamp.Shape = Enum.PartType.Ball
	local light = Instance.new("PointLight")
	light.Brightness, light.Range, light.Shadows, light.Parent = 1.6, 22, true, lamp

	local random = Random.new(73021)
	for index = 1, 72 do
		local angle, distance = random:NextNumber(0, math.pi * 2), random:NextNumber(30, 112)
		local x, z = math.cos(angle) * distance, math.sin(angle) * distance
		if math.abs(x) > 18 or z > -18 or z < -52 then
			local height = random:NextNumber(15, 27)
			local tree = Instance.new("Model")
			tree.Name, tree.Parent = `Tree{index}`, world
			part(
				tree,
				"Trunk",
				Vector3.new(2.3, height, 2.3),
				Vector3.new(x, height / 2, z),
				Color3.fromRGB(38, 29, 28),
				Enum.Material.Wood
			)
			local crown = part(
				tree,
				"Crown",
				Vector3.new(9, 13, 9),
				Vector3.new(x, height + 3, z),
				Color3.fromRGB(16, 35, 31),
				Enum.Material.Grass
			)
			crown.Shape = Enum.PartType.Ball
		end
	end

	Lighting.Brightness, Lighting.ClockTime = 1.1, 1.2
	Lighting.Ambient, Lighting.OutdoorAmbient =
		Color3.fromRGB(29, 35, 52), Color3.fromRGB(38, 43, 58)
	Lighting.FogColor, Lighting.FogStart, Lighting.FogEnd = Color3.fromRGB(17, 24, 31), 35, 150
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name, atmosphere.Density, atmosphere.Haze = "NightMist", 0.38, 2.2
	atmosphere.Color, atmosphere.Decay, atmosphere.Parent =
		Color3.fromRGB(128, 146, 164), Color3.fromRGB(33, 39, 52), Lighting
	return world
end

return WorldBuilder
