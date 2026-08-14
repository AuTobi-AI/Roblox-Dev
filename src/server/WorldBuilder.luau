--!strict

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

export type World = {
	model: Model,
	spawn: CFrame,
	receptionDock: Vector3,
	recordsDock: Vector3,
	pickupPrompt: ProximityPrompt,
	dockPrompt: ProximityPrompt,
	evidencePrompt: ProximityPrompt,
	exitTrigger: BasePart,
	setStage: (stage: number) -> (),
	openExit: () -> (),
}

local WorldBuilder = {}

local WALL = Color3.fromRGB(47, 54, 60)
local FLOOR = Color3.fromRGB(31, 37, 42)
local DARK = Color3.fromRGB(12, 16, 20)
local SAFE = Color3.fromRGB(102, 224, 210)
local WARNING = Color3.fromRGB(235, 158, 69)
local DANGER = Color3.fromRGB(204, 38, 66)

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
	item.Color, item.Material = color, material
	item.TopSurface, item.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	item.Parent = parent
	return item
end

local function surfaceText(adornee: BasePart, text: string, color: Color3, face: Enum.NormalId?)
	local gui = Instance.new("SurfaceGui")
	gui.Face, gui.CanvasSize, gui.LightInfluence =
		face or Enum.NormalId.Front, Vector2.new(720, 240), 0
	gui.Parent = adornee
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency, label.Font, label.Size =
		1, Enum.Font.GothamBold, UDim2.fromScale(1, 1)
	label.Text, label.TextColor3, label.TextScaled, label.TextWrapped = text, color, true, true
	label.Parent = gui
end

local function makePrompt(
	parent: BasePart,
	name: string,
	action: string,
	object: string
): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name, prompt.ActionText, prompt.ObjectText = name, action, object
	prompt.HoldDuration, prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 0.6, 10, false
	prompt.Parent = parent
	return prompt
end

local function shell(parent: Instance, name: string, centerZ: number, length: number)
	local model = Instance.new("Model")
	model.Name, model.Parent = name, parent
	part(
		model,
		"Floor",
		Vector3.new(34, 1, length),
		Vector3.new(0, 0, centerZ),
		FLOOR,
		Enum.Material.Metal
	)
	part(
		model,
		"Ceiling",
		Vector3.new(34, 1, length),
		Vector3.new(0, 14, centerZ),
		DARK,
		Enum.Material.Metal
	)
	part(
		model,
		"LeftWall",
		Vector3.new(1, 14, length),
		Vector3.new(-17, 7, centerZ),
		WALL,
		Enum.Material.Concrete
	)
	part(
		model,
		"RightWall",
		Vector3.new(1, 14, length),
		Vector3.new(17, 7, centerZ),
		WALL,
		Enum.Material.Concrete
	)
	part(
		model,
		"FrontWall",
		Vector3.new(34, 14, 1),
		Vector3.new(0, 7, centerZ - length / 2),
		WALL,
		Enum.Material.Concrete
	)
	part(
		model,
		"BackWall",
		Vector3.new(34, 14, 1),
		Vector3.new(0, 7, centerZ + length / 2),
		WALL,
		Enum.Material.Concrete
	)
end

local function lightBar(parent: Instance, name: string, position: Vector3): (Part, PointLight)
	local fixture = part(parent, name, Vector3.new(9, 0.3, 1.4), position, SAFE, Enum.Material.Neon)
	fixture.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range, light.Shadows = SAFE, 1.2, 22, true
	light.Parent = fixture
	return fixture, light
end

function WorldBuilder.build(): World
	local old = Workspace:FindFirstChild("GeneratedWorld")
	if old then
		old:Destroy()
	end
	Workspace.Baseplate.Transparency, Workspace.Baseplate.CanCollide = 1, false
	Workspace.SpawnLocation.Transparency, Workspace.SpawnLocation.CanCollide = 1, false
	Workspace.SpawnLocation.Position = Vector3.new(0, 2, 12)

	local model = Instance.new("Model")
	model.Name, model.Parent = "GeneratedWorld", Workspace

	-- Two rooms, one cord. The receiver is the only recurring interaction.
	shell(model, "DeadReception", 0, 34)
	local receptionBack = model.DeadReception.BackWall :: BasePart
	receptionBack.CanCollide, receptionBack.Transparency = false, 0.35
	shell(model, "TransferHall", 25, 18)
	local hallFront = model.TransferHall.FrontWall :: BasePart
	local hallBack = model.TransferHall.BackWall :: BasePart
	hallFront.CanCollide, hallFront.Transparency = false, 0.35
	hallBack.CanCollide, hallBack.Transparency = false, 0.35
	shell(model, "Records", 52, 36)
	local recordsFront = model.Records.FrontWall :: BasePart
	recordsFront.CanCollide, recordsFront.Transparency = false, 0.35
	local recordsBack = model.Records.BackWall :: BasePart
	recordsBack.CanCollide, recordsBack.Transparency = false, 0.35

	local receptionSign = part(
		model,
		"ReceptionSign",
		Vector3.new(12, 3, 0.3),
		Vector3.new(0, 9, -16.3),
		DARK,
		Enum.Material.Metal
	)
	receptionSign.CanCollide = false
	surfaceText(receptionSign, "LARKSPUR // RECEPTION", SAFE)
	local instruction = part(
		model,
		"Instruction",
		Vector3.new(9, 5, 0.3),
		Vector3.new(-11, 5, -16.2),
		DARK,
		Enum.Material.Metal
	)
	instruction.CanCollide = false
	surfaceText(instruction, "WHEN IT RINGS\nANSWER NATURALLY", WARNING)

	local receptionDock = Vector3.new(0, 5, -9)
	local cradle = part(
		model,
		"ReceptionCradle",
		Vector3.new(9, 4, 2),
		Vector3.new(0, 3, -9),
		WALL,
		Enum.Material.Metal
	)
	local cradlePlate = part(
		model,
		"ReceptionJack",
		Vector3.new(4, 2, 0.3),
		Vector3.new(0, 4, -7.85),
		SAFE,
		Enum.Material.Neon
	)
	cradlePlate.CanCollide = false
	surfaceText(cradlePlate, "LINE 19", DARK)
	local pickupPrompt = makePrompt(cradle, "PickupMorrow", "Unplug and carry", "Morrow Receiver")
	pickupPrompt.Enabled = false

	local recordsDock = Vector3.new(0, 5, 44)
	local recordsJack = part(
		model,
		"RecordsJack",
		Vector3.new(8, 5, 2),
		Vector3.new(0, 3, 44),
		WALL,
		Enum.Material.Metal
	)
	local jackGlow = part(
		model,
		"RecordsJackGlow",
		Vector3.new(4, 2, 0.3),
		Vector3.new(0, 4, 42.85),
		WARNING,
		Enum.Material.Neon
	)
	jackGlow.CanCollide = false
	surfaceText(jackGlow, "VOICE ARCHIVE", DARK)
	local dockPrompt =
		makePrompt(recordsJack, "DockMorrow", "Plug in receiver", "Records Wall Jack")
	dockPrompt.Enabled = false

	local projector = part(
		model,
		"IncidentProjector",
		Vector3.new(10, 4, 5),
		Vector3.new(0, 2.5, 58),
		WALL,
		Enum.Material.Metal
	)
	local reel = part(
		model,
		"IncidentReel",
		Vector3.new(3, 3, 0.5),
		Vector3.new(0, 5, 55.3),
		WARNING,
		Enum.Material.Metal
	)
	reel.Shape, reel.CanCollide = Enum.PartType.Cylinder, false
	reel.CFrame *= CFrame.Angles(0, math.rad(90), 0)
	local evidencePrompt =
		makePrompt(projector, "ThreadEvidence", "Thread the tape", "Incident Recording 18")
	evidencePrompt.Enabled = false
	local warningPanel = part(
		model,
		"WarningPanel",
		Vector3.new(11, 5, 0.3),
		Vector3.new(-10, 5, 69.2),
		DARK,
		Enum.Material.Metal
	)
	warningPanel.CanCollide = false
	surfaceText(warningPanel, "DO NOT PROMISE\nYOU WILL RETURN", WARNING, Enum.NormalId.Back)

	local exitDoor = part(
		model,
		"ExitDoor",
		Vector3.new(12, 14, 1),
		Vector3.new(0, 7, 70),
		WALL,
		Enum.Material.DiamondPlate
	)
	surfaceText(exitDoor, "SURFACE // LOCKED", WARNING, Enum.NormalId.Back)
	part(
		model,
		"ExitFrameLeft",
		Vector3.new(11, 14, 1),
		Vector3.new(-11.5, 7, 70),
		WALL,
		Enum.Material.Concrete
	)
	part(
		model,
		"ExitFrameRight",
		Vector3.new(11, 14, 1),
		Vector3.new(11.5, 7, 70),
		WALL,
		Enum.Material.Concrete
	)
	part(
		model,
		"ExitFloor",
		Vector3.new(12, 1, 26),
		Vector3.new(0, 0, 82),
		FLOOR,
		Enum.Material.Metal
	)
	part(
		model,
		"ExitLeft",
		Vector3.new(1, 14, 26),
		Vector3.new(-6, 7, 82),
		WALL,
		Enum.Material.Concrete
	)
	part(
		model,
		"ExitRight",
		Vector3.new(1, 14, 26),
		Vector3.new(6, 7, 82),
		WALL,
		Enum.Material.Concrete
	)
	part(
		model,
		"ExitCeiling",
		Vector3.new(12, 1, 26),
		Vector3.new(0, 14, 82),
		DARK,
		Enum.Material.Metal
	)
	local exitTrigger = part(
		model,
		"ExitTrigger",
		Vector3.new(10, 10, 2),
		Vector3.new(0, 5, 91),
		SAFE,
		Enum.Material.ForceField
	)
	exitTrigger.Transparency, exitTrigger.CanCollide, exitTrigger.CanQuery = 1, false, false

	local fixtures: { Part } = {}
	local lights: { PointLight } = {}
	for index, position in
		{
			Vector3.new(-9, 13.3, 4),
			Vector3.new(9, 13.3, 4),
			Vector3.new(-9, 13.3, -9),
			Vector3.new(9, 13.3, -9),
			Vector3.new(-9, 13.3, 48),
			Vector3.new(9, 13.3, 48),
			Vector3.new(-9, 13.3, 61),
			Vector3.new(9, 13.3, 61),
		}
	do
		local fixture, light = lightBar(model, `LineLight{index}`, position)
		table.insert(fixtures, fixture)
		table.insert(lights, light)
	end

	local emergency = part(
		model,
		"EmergencyLight",
		Vector3.one,
		Vector3.new(0, 11, 67),
		DANGER,
		Enum.Material.Neon
	)
	emergency.Shape, emergency.CanCollide = Enum.PartType.Ball, false
	local emergencyLight = Instance.new("PointLight")
	emergencyLight.Color, emergencyLight.Brightness, emergencyLight.Range, emergencyLight.Shadows =
		DANGER, 0, 40, true
	emergencyLight.Parent = emergency

	local cracks: { BasePart } = {}
	for index = 1, 6 do
		local crack = part(
			model,
			`CableBurn{index}`,
			Vector3.new(0.13, 2.5, 0.13),
			Vector3.new(-7 + index * 2, 4 + index % 2, 69.3),
			DANGER,
			Enum.Material.Neon
		)
		crack.CanCollide, crack.Transparency = false, 1
		crack.CFrame *= CFrame.Angles(0, 0, math.rad(if index % 2 == 0 then 32 else -32))
		table.insert(cracks, crack)
	end

	local exitOpen = false
	local function setStage(stage: number)
		local level = math.clamp(math.floor(stage), 0, 4)
		for index, fixture in fixtures do
			local isReception = index <= 4
			local enabled = if level == 0
				then isReception
				else if level == 1 then not isReception else index % 2 == 0
			fixture.Color = if level >= 3 then WARNING else SAFE
			lights[index].Enabled, lights[index].Color = enabled, fixture.Color
			lights[index].Brightness = if level >= 3 then 0.55 else 1.2
		end
		for index, crack in cracks do
			crack.Transparency = if level >= 3 and index <= level + 2 then 0.1 else 1
		end
		emergencyLight.Brightness = if level >= 4 then 3 else 0
		Lighting.Ambient = if level >= 4
			then Color3.fromRGB(55, 8, 18)
			else Color3.fromRGB(17, 26, 31)
	end

	local function openExit()
		if exitOpen then
			return
		end
		exitOpen = true
		exitDoor.CanCollide, exitDoor.Transparency, exitDoor.Color = false, 0.72, DANGER
	end

	Lighting.Brightness, Lighting.ClockTime = 0.9, 0
	Lighting.Ambient, Lighting.OutdoorAmbient =
		Color3.fromRGB(17, 26, 31), Color3.fromRGB(7, 10, 14)
	Lighting.FogColor, Lighting.FogStart, Lighting.FogEnd = Color3.fromRGB(10, 15, 19), 50, 120
	local oldAtmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if oldAtmosphere then
		oldAtmosphere:Destroy()
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name, atmosphere.Density, atmosphere.Haze = "LineHaze", 0.18, 0.8
	atmosphere.Color, atmosphere.Decay, atmosphere.Parent =
		Color3.fromRGB(104, 131, 137), Color3.fromRGB(26, 34, 42), Lighting
	setStage(0)

	return {
		model = model,
		spawn = CFrame.new(0, 3, 12),
		receptionDock = receptionDock,
		recordsDock = recordsDock,
		pickupPrompt = pickupPrompt,
		dockPrompt = dockPrompt,
		evidencePrompt = evidencePrompt,
		exitTrigger = exitTrigger,
		setStage = setStage,
		openExit = openExit,
	}
end

return WorldBuilder
