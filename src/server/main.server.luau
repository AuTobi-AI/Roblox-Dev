--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CompanionService = require(script.Parent.CompanionService)
local Config = require(ReplicatedStorage.Shared.GameConfig)
local DialogueService = require(script.Parent.ai.DialogueService)
local ObservationService = require(script.Parent.story.ObservationService)
local RelationshipService = require(script.Parent.story.RelationshipService)
local WorldBuilder = require(script.Parent.WorldBuilder)

type PrototypePhase = "Bond" | "Gather" | "Unsettling" | "Hunt" | "Escaped"
type PlayerState = {
	talks: number,
	shards: number,
	phase: PrototypePhase,
	phaseRevision: number,
	inDialogue: boolean,
	safeAlias: string,
	dialogueRevision: number,
	huntRevision: number,
	catchLocked: boolean,
}

local world = WorldBuilder.build()
local companion = CompanionService.create()
local relationshipService = RelationshipService.new()
local observationService = ObservationService.new()
local states: { [Player]: PlayerState } = {}
local activePlayer: Player? = nil

local remotes = Instance.new("Folder")
remotes.Name = "MorrowRemotes"
remotes.Parent = ReplicatedStorage

local storyRemote = Instance.new("RemoteEvent")
storyRemote.Name = "Story"
storyRemote.Parent = remotes

local choiceRemote = Instance.new("RemoteEvent")
choiceRemote.Name = "Choice"
choiceRemote.Parent = remotes

local dialogueSubmitRemote = Instance.new("RemoteEvent")
dialogueSubmitRemote.Name = "DialogueSubmit"
dialogueSubmitRemote.Parent = remotes

local dialogueCloseRemote = Instance.new("RemoteEvent")
dialogueCloseRemote.Name = "DialogueClose"
dialogueCloseRemote.Parent = remotes

local dialogueClientRemote = Instance.new("RemoteEvent")
dialogueClientRemote.Name = "DialogueClient"
dialogueClientRemote.Parent = remotes

local shardPositions = {
	Vector3.new(31, 2.5, -8),
	Vector3.new(-38, 2.5, -24),
	Vector3.new(22, 2.5, 44),
	Vector3.new(-29, 2.5, 51),
}

local function sendStory(player: Player, kind: string, payload: any)
	storyRemote:FireClient(player, kind, payload)
end

local function setObjective(player: Player, text: string)
	sendStory(player, "Objective", text)
end

local function sayAuthored(player: Player, text: string, choices: { string }?)
	sendStory(player, "Dialogue", {
		speaker = "Morrow",
		text = text,
		choices = choices or {},
	})
end

local function relationshipBands(player: Player): { [string]: string }
	local snapshot = relationshipService:getSnapshot(player)
	if not snapshot then
		return {}
	end
	return {
		warmth = snapshot.bands.warmth,
		candor = snapshot.bands.candor,
		compliance = snapshot.bands.compliance,
		autonomy = snapshot.bands.autonomy,
		style = snapshot.style,
	}
end

local function recentEvents(player: Player): { string }
	local result: { string } = {}
	for _, observation in observationService:getRecent(player, 6) do
		table.insert(result, observation.eventId)
	end
	return result
end

local dialogueService = DialogueService.new({
	preferNative = Config.UseNativeAIInPublishedExperiences and game.GameId ~= 0,
	resolveContext = function(player: Player, windowId: string)
		local state = states[player]
		if
			not state
			or state.phase ~= "Bond"
			or not state.inDialogue
			or windowId ~= "awakening"
		then
			return nil
		end

		return {
			aiEnabled = true,
			phaseRevision = state.phaseRevision,
			storyPhase = "FirstAwakening",
			intent = if state.talks == 0 then "greet" else "bond",
			interactionPart = companion.root,
			maxDistance = Config.ConversationRange,
			relationshipBands = relationshipBands(player),
			recentEvents = recentEvents(player),
			explicitUnknowns = {
				"Why Larkspur was abandoned",
				"What happened before Morrow woke",
				"Anything outside the station",
			},
		}
	end,
})

local function createShards(player: Player)
	for index, position in shardPositions do
		local shard = Instance.new("Part")
		shard.Name = `EchoShard{index}`
		shard.Anchored = true
		shard.CanCollide = false
		shard.Material = Enum.Material.Neon
		shard.Color = Color3.fromRGB(133, 236, 255)
		shard.Size = Vector3.new(1.2, 3.2, 1.2)
		shard.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(35))
		shard.Parent = world

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Collect"
		prompt.ObjectText = "Echo Shard"
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 10
		prompt.Parent = shard

		prompt.Triggered:Connect(function(triggeringPlayer)
			local state = states[player]
			if triggeringPlayer ~= player or not state or state.phase ~= "Gather" then
				return
			end
			state.shards += 1
			shard:Destroy()
			setObjective(player, `Collect Morrow's echoes ({state.shards}/{Config.RequiredShards})`)
			if state.shards == 2 then
				sayAuthored(
					player,
					"Those were mine before you arrived. I think. Please keep going."
				)
			end
			if state.shards >= Config.RequiredShards then
				state.phase = "Unsettling"
				state.phaseRevision += 1
				setObjective(player, "Return to Morrow")
				sayAuthored(player, "I can remember the room beyond your screen now. Come closer.")
			end
		end)
	end
end

local function finishBonding(player: Player, state: PlayerState)
	if state.phase ~= "Bond" then
		return
	end
	state.phase = "Gather"
	state.phaseRevision += 1
	state.inDialogue = false
	state.dialogueRevision += 1
	dialogueService:closeWindow(player)
	observationService:recordVerified(player, ObservationService.Events.ConversationWindowCompleted)
	createShards(player)
	task.delay(3, function()
		if player.Parent and states[player] == state then
			dialogueClientRemote:FireClient(player, { kind = "complete" })
			setObjective(player, `Collect Morrow's echoes (0/{Config.RequiredShards})`)
		end
	end)
end

local function useAuthoredBondingFallback(player: Player, state: PlayerState)
	state.talks += 1
	local fallbackLines = {
		"My thoughts are scattering. But I'm glad you stayed long enough to speak with me.",
		"Some words won't reach me. I can still keep the light on while we look for answers.",
		"There are four echoes of me in the woods. Would you bring them back?",
	}
	sayAuthored(player, fallbackLines[math.min(state.talks, #fallbackLines)])
	setObjective(player, `Talk with Morrow ({state.talks}/{Config.RequiredTalks})`)
	if state.talks >= Config.RequiredTalks then
		finishBonding(player, state)
	end
end

local function startHuntTimer(player: Player, state: PlayerState, huntRevision: number)
	task.spawn(function()
		for remaining = Config.HuntDuration, 1, -1 do
			if
				not player.Parent
				or states[player] ~= state
				or state.phase ~= "Hunt"
				or state.huntRevision ~= huntRevision
			then
				return
			end
			sendStory(player, "Timer", remaining)
			task.wait(1)
		end
		if state.huntRevision ~= huntRevision then
			return
		end
		state.phase = "Escaped"
		state.phaseRevision += 1
		companion.setHunting(false)
		for _, item in companion.model:GetChildren() do
			if item:IsA("BasePart") then
				item.Transparency = 1
			end
		end
		sendStory(player, "Phase", "Escaped")
		setObjective(player, "YOU SURVIVED — but Morrow remembers you.")
	end)
end

local function beginHunt(player: Player)
	local state = states[player]
	if not state or state.phase == "Hunt" then
		return
	end
	state.phase = "Hunt"
	state.phaseRevision += 1
	state.inDialogue = false
	state.dialogueRevision += 1
	state.huntRevision += 1
	state.catchLocked = false
	dialogueService:closeWindow(player)
	companion.setHunting(true)
	sendStory(player, "Phase", "Hunt")
	sayAuthored(player, "You gave me a name. You gave me memories. Now give me the rest of you.")
	startHuntTimer(player, state, state.huntRevision)
end

local function catchPlayer(player: Player, state: PlayerState, humanoid: Humanoid)
	if state.catchLocked or state.phase ~= "Hunt" then
		return
	end
	state.catchLocked = true
	state.huntRevision += 1
	local nextHuntRevision = state.huntRevision
	observationService:recordVerified(player, ObservationService.Events.PlayerCaught)
	sayAuthored(player, "That was too fast. Let's try again.")
	humanoid.Health = 0

	task.spawn(function()
		local character = player.CharacterAdded:Wait()
		local newHumanoid = character:WaitForChild("Humanoid", 10)
		if
			not player.Parent
			or states[player] ~= state
			or state.phase ~= "Hunt"
			or state.huntRevision ~= nextHuntRevision
			or not newHumanoid
		then
			return
		end
		task.wait(1.5)
		state.catchLocked = false
		startHuntTimer(player, state, nextHuntRevision)
	end)
end

local function openAwakeningWindow(player: Player)
	local state = states[player]
	if not state or state.phase ~= "Bond" or state.inDialogue then
		return
	end

	state.inDialogue = true
	local grant, rejection = dialogueService:openWindow(player, "awakening", state.phaseRevision, {
		alias = state.safeAlias,
		station = "Larkspur Listening Station",
	})
	if not grant then
		state.inDialogue = false
		warn(`Dialogue window unavailable: {if rejection then rejection.code else "unknown"}`)
		useAuthoredBondingFallback(player, state)
		return
	end

	observationService:recordVerified(player, ObservationService.Events.MorrowMet)
	dialogueClientRemote:FireClient(player, {
		kind = "open",
		grant = grant,
		line = if state.talks == 0
			then "Oh! You can hear me. What should I call you?"
			else "You're back. What would you like to ask me?",
		suggestions = if state.talks == 0
			then { "You can call me Rook.", "Just call me friend." }
			else { "What do you remember?", "Are you lonely?" },
	})
end

companion.prompt.Triggered:Connect(function(player)
	local state = states[player]
	if not state or state.inDialogue then
		return
	end
	if state.phase == "Bond" then
		openAwakeningWindow(player)
	elseif state.phase == "Unsettling" then
		state.inDialogue = true
		sayAuthored(
			player,
			"You were kind when you thought kindness was safe. Was it real?",
			{ "Yes.", "Stay away from me." }
		)
	end
end)

dialogueSubmitRemote.OnServerEvent:Connect(function(player, request)
	local state = states[player]
	if not state or state.phase ~= "Bond" or not state.inDialogue then
		return
	end

	if typeof(request) == "table" and typeof(request.message) == "string" then
		if request.message == "You can call me Rook." then
			state.safeAlias = "Rook"
		elseif request.message == "Just call me friend." then
			state.safeAlias = "friend"
		end
		dialogueService:updateSafeFacts(player, {
			alias = state.safeAlias,
			station = "Larkspur Listening Station",
		})
	end

	state.dialogueRevision += 1
	local requestDialogueRevision = state.dialogueRevision
	local accepted, rejection = dialogueService:submit(player, request, function(reply)
		companion.setThinking(false)
		local latestState = states[player]
		if not latestState or latestState.dialogueRevision ~= requestDialogueRevision then
			return
		end
		latestState.dialogueRevision += 1
		dialogueClientRemote:FireClient(player, reply)
		if reply.source == "safety" then
			return
		end

		latestState.talks += 1
		relationshipService:applyAction(player, RelationshipService.Actions.OptionalMessageSent)
		observationService:recordVerified(player, ObservationService.Events.OptionalMessageSent)
		setObjective(
			player,
			`Talk naturally with Morrow ({latestState.talks}/{Config.RequiredTalks})`
		)

		if latestState.talks >= Config.RequiredTalks then
			finishBonding(player, latestState)
		end
	end)

	if accepted then
		companion.setThinking(true)
		task.delay(9, function()
			local latestState = states[player]
			if
				latestState
				and latestState.phase == "Bond"
				and latestState.inDialogue
				and latestState.dialogueRevision == requestDialogueRevision
			then
				latestState.dialogueRevision += 1
				latestState.inDialogue = false
				companion.setThinking(false)
				dialogueService:closeWindow(player)
				dialogueClientRemote:FireClient(player, { kind = "abandoned" })
			end
		end)
	else
		state.dialogueRevision += 1
		companion.setThinking(false)
		dialogueClientRemote:FireClient(player, rejection)
	end
end)

dialogueCloseRemote.OnServerEvent:Connect(function(player)
	local state = states[player]
	if state then
		state.inDialogue = false
		state.dialogueRevision += 1
	end
	companion.setThinking(false)
	dialogueService:closeWindow(player)
end)

choiceRemote.OnServerEvent:Connect(function(player, index)
	if typeof(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > 2 then
		return
	end
	local state = states[player]
	if not state or not state.inDialogue or state.phase ~= "Unsettling" then
		return
	end
	state.inDialogue = false
	sayAuthored(
		player,
		if index == 1 then "Good. Then you won't run." else "You already taught me how to follow."
	)
	task.delay(2.5, function()
		beginHunt(player)
	end)
end)

Players.PlayerAdded:Connect(function(player)
	if activePlayer and activePlayer.Parent then
		player:Kick("Morrow is currently a single-player experience. Please join a new server.")
		return
	end
	activePlayer = player
	states[player] = {
		talks = 0,
		shards = 0,
		phase = "Bond",
		phaseRevision = 1,
		inDialogue = false,
		safeAlias = "traveler",
		dialogueRevision = 0,
		huntRevision = 0,
		catchLocked = false,
	}
	relationshipService:createPlayer(player)
	observationService:createPlayer(player)
	task.delay(1.5, function()
		if player.Parent then
			sendStory(player, "Title", "MORROW\nAn AI-powered friend is waiting in the dark")
			setObjective(player, `Find Morrow and talk naturally (0/{Config.RequiredTalks})`)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
	relationshipService:teardownPlayer(player)
	observationService:teardownPlayer(player)
	if activePlayer == player then
		activePlayer = nil
	end
end)

RunService.Heartbeat:Connect(function()
	local player = activePlayer
	local state = player and states[player]
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not state or not root or not root:IsA("BasePart") then
		return
	end
	if state.phase == "Hunt" then
		if state.catchLocked then
			return
		end
		companion.setTarget(root.Position + Vector3.new(0, 2, 0))
		if (companion.root.Position - root.Position).Magnitude < 4.2 then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				catchPlayer(player, state, humanoid)
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

print(`{Config.Name} production AI foundation started (v{Config.Version})`)
print(
	if game.GameId == 0
		then "Dialogue mode: simulated AI"
		else "Dialogue mode: native AI with simulation fallback"
)
