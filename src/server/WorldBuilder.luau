--!strict

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

export type World = {
	model: Model,
	interactions: { [string]: ProximityPrompt },
	spawns: { [string]: CFrame },
}

local WorldBuilder = {}
local CONCRETE = Color3.fromRGB(55, 62, 67)
local DARK = Color3.fromRGB(24, 29, 33)
local METAL = Color3.fromRGB(75, 84, 88)
local CYAN = Color3.fromRGB(90, 226, 217)
local AMBER = Color3.fromRGB(243, 177, 77)
local RED = Color3.fromRGB(205, 54, 72)
local ARCHIVE = Color3.fromRGB(112, 88, 132)

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

local function label(adornee: BasePart, text: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face, gui.CanvasSize, gui.LightInfluence = Enum.NormalId.Front, Vector2.new(640, 180), 0
	gui.Parent = adornee
	local output = Instance.new("TextLabel")
	output.BackgroundTransparency, output.Font, output.Size =
		1, Enum.Font.GothamBold, UDim2.fromScale(1, 1)
	output.Text, output.TextColor3, output.TextScaled = text, color, true
	output.Parent = gui
end

local function room(
	parent: Instance,
	name: string,
	center: Vector3,
	size: Vector3,
	accent: Color3
): Model
	local model = Instance.new("Model")
	model.Name, model.Parent = name, parent
	part(model, "Floor", Vector3.new(size.X, 1, size.Z), center, CONCRETE, Enum.Material.Concrete)
	part(
		model,
		"Ceiling",
		Vector3.new(size.X, 1, size.Z),
		center + Vector3.new(0, 14, 0),
		DARK,
		Enum.Material.Metal
	)
	part(
		model,
		"NorthWall",
		Vector3.new(size.X, 14, 1),
		center + Vector3.new(0, 7, -size.Z / 2),
		METAL,
		Enum.Material.Concrete
	)
	part(
		model,
		"SouthWall",
		Vector3.new(size.X, 14, 1),
		center + Vector3.new(0, 7, size.Z / 2),
		METAL,
		Enum.Material.Concrete
	)
	part(
		model,
		"WestWall",
		Vector3.new(1, 14, size.Z),
		center + Vector3.new(-size.X / 2, 7, 0),
		METAL,
		Enum.Material.Concrete
	)
	part(
		model,
		"EastWall",
		Vector3.new(1, 14, size.Z),
		center + Vector3.new(size.X / 2, 7, 0),
		METAL,
		Enum.Material.Concrete
	)
	local strip = part(
		model,
		"AccentLight",
		Vector3.new(size.X - 4, 0.25, 0.4),
		center + Vector3.new(0, 11.5, -size.Z / 2 + 0.7),
		accent,
		Enum.Material.Neon
	)
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range, light.Shadows =
		accent, 0.7, math.max(size.X, size.Z) * 0.65, true
	light.Parent = strip
	return model
end

local function corridor(parent: Instance, name: string, center: Vector3, size: Vector3)
	local model = room(parent, name, center, size, CYAN)
	if size.X > size.Z then
		model.WestWall:Destroy()
		model.EastWall:Destroy()
	else
		model.NorthWall:Destroy()
		model.SouthWall:Destroy()
	end
end

local function sign(parent: Instance, text: string, position: Vector3, color: Color3)
	local panel =
		part(parent, `{text}Sign`, Vector3.new(12, 3, 0.35), position, DARK, Enum.Material.Metal)
	panel.CanCollide = false
	label(panel, text, color)
end

local function addPrompt(
	world: World,
	id: string,
	position: Vector3,
	actionText: string,
	objectText: string,
	color: Color3
)
	local console =
		part(world.model, id, Vector3.new(2.8, 3.4, 1.4), position, color, Enum.Material.Metal)
	local screen = part(
		world.model,
		`${id}Screen`,
		Vector3.new(2.2, 1.35, 0.16),
		position + Vector3.new(0, 0.45, -0.78),
		color,
		Enum.Material.Neon
	)
	screen.CanCollide = false
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name, prompt.ActionText, prompt.ObjectText = `${id}Prompt`, actionText, objectText
	prompt.HoldDuration, prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 0.35, 10, false
	prompt.Parent = console
	world.interactions[id] = prompt
end

function WorldBuilder.build(): World
	local old = Workspace:FindFirstChild("GeneratedWorld")
	if old then
		old:Destroy()
	end
	Workspace.Baseplate.Transparency, Workspace.Baseplate.CanCollide = 1, false
	Workspace.SpawnLocation.Transparency, Workspace.SpawnLocation.CanCollide = 1, false
	Workspace.SpawnLocation.Position = Vector3.new(0, 2, 68)

	local model = Instance.new("Model")
	model.Name, model.Parent = "GeneratedWorld", Workspace
	local world: World = { model = model, interactions = {}, spawns = {} }

	room(model, "Arrival", Vector3.new(0, 0, 62), Vector3.new(24, 14, 26), AMBER)
	corridor(model, "ArrivalConnector", Vector3.new(0, 0, 43), Vector3.new(12, 14, 14))
	room(model, "Reception", Vector3.new(0, 0, 25), Vector3.new(34, 14, 24), CYAN)
	corridor(model, "ObservationConnector", Vector3.new(-25, 0, 25), Vector3.new(16, 14, 10))
	room(model, "Observation", Vector3.new(-46, 0, 25), Vector3.new(26, 14, 26), CYAN)
	corridor(model, "UtilityConnector", Vector3.new(-46, 0, 3), Vector3.new(10, 14, 18))
	room(model, "Utility", Vector3.new(-46, 0, -22), Vector3.new(28, 14, 32), AMBER)
	corridor(model, "ArchiveConnector", Vector3.new(-24, 0, -22), Vector3.new(16, 14, 10))
	room(model, "ArchiveAnnex", Vector3.new(0, 0, -22), Vector3.new(32, 14, 30), ARCHIVE)
	corridor(model, "ServiceLoop", Vector3.new(25, 0, 2), Vector3.new(10, 14, 68))
	room(model, "EvacuationElevator", Vector3.new(25, 0, 48), Vector3.new(20, 14, 20), RED)

	-- Wall panels are visual graybox boundaries. Collision stays on floors and
	-- consoles so overlapping room shells cannot create invisible route blockers.
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") and string.find(item.Name, "Wall") then
			item.CanCollide, item.Transparency = false, 0.38
		end
	end

	sign(model, "ARRIVAL", Vector3.new(0, 8, 49.2), AMBER)
	sign(model, "RECEPTION", Vector3.new(0, 8, 36.7), CYAN)
	sign(model, "OBSERVATION", Vector3.new(-33.2, 8, 25), CYAN)
	sign(model, "UTILITY", Vector3.new(-46, 8, -5.7), AMBER)
	sign(model, "ARCHIVE ANNEX", Vector3.new(0, 8, -6.7), ARCHIVE)
	sign(model, "SERVICE / EVAC", Vector3.new(25, 8, 37.7), RED)

	world.spawns = {
		ArrivalSpawn = CFrame.new(0, 3, 68),
		ObservationSpawn = CFrame.new(-46, 3, 30),
		UtilitySpawn = CFrame.new(-46, 3, -13),
		ArchiveSpawn = CFrame.new(0, 3, -13),
		PursuitStartSpawn = CFrame.new(8, 3, -22),
		RelayOneSpawn = CFrame.new(25, 3, -18),
		RelayTwoSpawn = CFrame.new(25, 3, 28),
		ElevatorSpawn = CFrame.new(25, 3, 48),
	}

	local prompts = {
		{ "ReceptionDoor", Vector3.new(0, 2.2, 54), "Enter", "Larkspur Reception", AMBER },
		{ "CircuitA", Vector3.new(-11, 2.2, 20), "Reset", "Security Circuit A", CYAN },
		{ "CircuitB", Vector3.new(0, 2.2, 18), "Reset", "Security Circuit B", CYAN },
		{ "CircuitC", Vector3.new(11, 2.2, 20), "Reset", "Security Circuit C", CYAN },
		{ "ObservationDoor", Vector3.new(-31, 2.2, 25), "Unseal", "Observation Chamber", CYAN },
		{ "ChooseVent", Vector3.new(-52, 2.2, 29), "Trust Morrow", "Vent Route", CYAN },
		{ "ChooseManual", Vector3.new(-40, 2.2, 29), "Work Alone", "Manual Bypass", AMBER },
		{ "VentAccess", Vector3.new(-50, 2.2, 4), "Release", "Utility Vent Latch", CYAN },
		{ "ManualBypass", Vector3.new(-42, 2.2, 4), "Override", "Utility Door Bypass", AMBER },
		{ "BreakerA", Vector3.new(-55, 2.2, -26), "Synchronize", "Generator Phase A", AMBER },
		{ "BreakerB", Vector3.new(-46, 2.2, -30), "Synchronize", "Generator Phase B", AMBER },
		{ "BreakerC", Vector3.new(-37, 2.2, -26), "Synchronize", "Generator Phase C", AMBER },
		{ "Usefulness", Vector3.new(-46, 2.2, -16), "Answer", "Morrow's Check-in", CYAN },
		{ "PrivilegeKey", Vector3.new(-14, 2.2, -22), "Install", "Privilege Key", RED },
		{ "Loneliness", Vector3.new(-8, 2.2, -15), "Stay Awhile", "Morrow", CYAN },
		{ "ArchiveA", Vector3.new(-9, 2.2, -28), "Recover", "Recording Fragment 01", ARCHIVE },
		{ "ArchiveB", Vector3.new(0, 2.2, -31), "Recover", "Recording Fragment 02", ARCHIVE },
		{ "ArchiveC", Vector3.new(9, 2.2, -28), "Recover", "Recording Fragment 03", ARCHIVE },
		{ "Evidence", Vector3.new(8, 2.2, -17), "Respond", "Incident Playback", RED },
		{ "ImpossibleSignal", Vector3.new(18, 2.2, -22), "Follow", "Morrow's Signal", RED },
		{ "RelayOne", Vector3.new(25, 2.2, -22), "Activate", "Archive Isolation Relay", RED },
		{ "RelayTwo", Vector3.new(25, 2.2, 18), "Activate", "Utility Isolation Relay", RED },
		{ "Elevator", Vector3.new(25, 2.2, 46), "Evacuate", "Larkspur Elevator", CYAN },
	}
	for _, definition in prompts do
		addPrompt(
			world,
			definition[1] :: string,
			definition[2] :: Vector3,
			definition[3] :: string,
			definition[4] :: string,
			definition[5] :: Color3
		)
	end

	Lighting.Brightness, Lighting.ClockTime = 1.1, 0.4
	Lighting.Ambient, Lighting.OutdoorAmbient =
		Color3.fromRGB(20, 27, 34), Color3.fromRGB(11, 15, 22)
	Lighting.FogColor, Lighting.FogStart, Lighting.FogEnd = Color3.fromRGB(15, 22, 29), 70, 180
	local oldAtmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if oldAtmosphere then
		oldAtmosphere:Destroy()
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name, atmosphere.Density, atmosphere.Haze = "StationHaze", 0.22, 1.1
	atmosphere.Color, atmosphere.Decay, atmosphere.Parent =
		Color3.fromRGB(106, 131, 146), Color3.fromRGB(31, 40, 54), Lighting
	return world
end

return WorldBuilder
