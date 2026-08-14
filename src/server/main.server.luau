--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CompanionService = require(script.Parent.CompanionService)
local Config = require(ReplicatedStorage.Shared.GameConfig)
local WorldBuilder = require(script.Parent.WorldBuilder)

local world, companion = WorldBuilder.build(), CompanionService.create()
local remotes = Instance.new("Folder")
remotes.Name, remotes.Parent = "MorrowRemotes", ReplicatedStorage
local story, choice = Instance.new("RemoteEvent"), Instance.new("RemoteEvent")
story.Name, story.Parent, choice.Name, choice.Parent = "Story", remotes, "Choice", remotes

type State = { talks: number, shards: number, trust: number, phase: string, inDialogue: boolean }
local states: { [Player]: State } = {}
local shardPositions = {
	Vector3.new(31, 2.5, -8),
	Vector3.new(-38, 2.5, -24),
	Vector3.new(22, 2.5, 44),
	Vector3.new(-29, 2.5, 51),
}
local lines = {
	{
		"Oh! You can hear me. I was worried the dark had swallowed everyone. Will you stay a while?",
		{ "Of course.", "Who are you?" },
	},
	{
		"I chose the name Morrow. It means there will always be a tomorrow. Do you like it?",
		{ "It suits you.", "That's a strange name." },
	},
	{
		"I scattered four little echoes in the woods. Bring them back and I might remember why I was left here.",
		{ "I'll find them.", "What happens if I don't?" },
	},
}

local function send(player: Player, kind: string, payload: any)
	story:FireClient(player, kind, payload)
end
local function objective(player: Player, text: string)
	send(player, "Objective", text)
end
local function say(player: Player, text: string, choices: { string }?)
	send(player, "Dialogue", { speaker = "Morrow", text = text, choices = choices or {} })
end

local function hunt(player: Player)
	local state = states[player]
	if not state or state.phase == "Hunt" then
		return
	end
	state.phase, state.inDialogue = "Hunt", false
	companion.setHunting(true)
	send(player, "Phase", "Hunt")
	say(player, "You gave me a name. You gave me memories. Now give me the rest of you.")
	task.spawn(function()
		for remaining = Config.HuntDuration, 1, -1 do
			if not player.Parent or state.phase ~= "Hunt" then
				return
			end
			send(player, "Timer", remaining)
			task.wait(1)
		end
		state.phase = "Escaped"
		companion.setHunting(false)
		for _, item in companion.model:GetChildren() do
			if item:IsA("BasePart") then
				item.Transparency = 1
			end
		end
		send(player, "Phase", "Escaped")
		objective(player, "YOU SURVIVED — but Morrow remembers you.")
	end)
end

local function createShards(player: Player)
	for index, position in shardPositions do
		local shard = Instance.new("Part")
		shard.Name, shard.Anchored, shard.CanCollide = `EchoShard{index}`, true, false
		shard.Material, shard.Color, shard.Size =
			Enum.Material.Neon, Color3.fromRGB(133, 236, 255), Vector3.new(1.2, 3.2, 1.2)
		shard.CFrame, shard.Parent = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(35)), world
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText, prompt.ObjectText, prompt.HoldDuration, prompt.Parent =
			"Collect", "Echo Shard", 0.5, shard
		prompt.Triggered:Connect(function(triggeringPlayer)
			local state = states[player]
			if triggeringPlayer ~= player or not state or state.phase ~= "Gather" then
				return
			end
			state.shards += 1
			shard:Destroy()
			objective(player, `Collect Morrow's echoes ({state.shards}/{Config.RequiredShards})`)
			if state.shards == 2 then
				say(player, "Those were mine before you arrived. I think. Please keep going.")
			end
			if state.shards >= Config.RequiredShards then
				state.phase = "Unsettling"
				objective(player, "Return to Morrow")
				say(player, "I can remember the room beyond your screen now. Come closer.")
			end
		end)
	end
end

companion.prompt.Triggered:Connect(function(player)
	local state = states[player]
	if not state or state.inDialogue then
		return
	end
	if state.phase == "Unsettling" then
		state.inDialogue = true
		say(
			player,
			"You were kind when you thought kindness was safe. Was it real?",
			{ "Yes.", "Stay away from me." }
		)
	elseif state.phase == "Bond" then
		state.inDialogue = true
		local line = lines[state.talks + 1]
		say(player, line[1] :: string, line[2] :: { string })
	end
end)

choice.OnServerEvent:Connect(function(player, index)
	if typeof(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > 2 then
		return
	end
	local state = states[player]
	if not state or not state.inDialogue then
		return
	end
	state.inDialogue, state.trust = false, state.trust + (if index == 1 then 1 else -1)
	if state.phase == "Unsettling" then
		say(
			player,
			if index == 1
				then "Good. Then you won't run."
				else "You already taught me how to follow."
		)
		task.delay(2.5, function()
			hunt(player)
		end)
		return
	end
	state.talks += 1
	if state.talks < Config.RequiredTalks then
		objective(player, `Talk with Morrow ({state.talks}/{Config.RequiredTalks})`)
	else
		state.phase = "Gather"
		objective(player, `Collect Morrow's echoes (0/{Config.RequiredShards})`)
		createShards(player)
	end
end)

Players.PlayerAdded:Connect(function(player)
	states[player] = { talks = 0, shards = 0, trust = 0, phase = "Bond", inDialogue = false }
	task.delay(1.5, function()
		if player.Parent then
			send(player, "Title", "MORROW\nA friend is waiting in the dark")
			objective(player, `Find and talk with Morrow (0/{Config.RequiredTalks})`)
		end
	end)
end)
Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
end)

RunService.Heartbeat:Connect(function()
	local player = Players:GetPlayers()[1]
	local state = player and states[player]
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not state or not root or not root:IsA("BasePart") then
		return
	end
	if state.phase == "Hunt" then
		companion.setTarget(root.Position + Vector3.new(0, 2, 0))
		if (companion.root.Position - root.Position).Magnitude < 4.2 then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Health = 0
			end
		end
	else
		companion.setTarget(
			root.Position
				- root.CFrame.LookVector * 7
				+ root.CFrame.RightVector * 4
				+ Vector3.new(0, 3, 0)
		)
	end
end)

print(`{Config.Name} server started (v{Config.Version})`)
