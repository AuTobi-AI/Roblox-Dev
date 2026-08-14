--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CompanionService = require(script.Parent.CompanionService)
local Config = require(ReplicatedStorage.Shared.GameConfig)
local StoryDirector = require(script.Parent.story.StoryDirector)
local WorldBuilder = require(script.Parent.WorldBuilder)

type Phase = StoryDirector.Phase
type ObjectiveId = StoryDirector.ObjectiveId
type PlayerState = {
	used: { [string]: boolean },
	catchLocked: boolean,
	graceUntil: number,
}

local world = WorldBuilder.build()
local companion = CompanionService.create()
local director = StoryDirector.new()
local states: { [Player]: PlayerState } = {}
local activePlayer: Player? = nil

local PHASE_PROMPTS: { [Phase]: { string } } = {
	Arrival = { "ReceptionDoor" },
	SecurityCircuit = { "CircuitA", "CircuitB", "CircuitC" },
	FirstAwakening = { "ObservationDoor" },
	UtilityChoice = { "ChooseVent", "ChooseManual" },
	VentAccess = { "VentAccess" },
	ManualBypass = { "ManualBypass" },
	GeneratorRepair = { "BreakerA", "BreakerB", "BreakerC" },
	UsefulnessCheckIn = { "Usefulness" },
	PrivilegeKey = { "PrivilegeKey" },
	LonelinessConversation = { "Loneliness" },
	ArchiveReconstruction = { "ArchiveA", "ArchiveB", "ArchiveC" },
	ArchiveConfrontation = { "Evidence" },
	ImpossibleAppearance = { "ImpossibleSignal" },
	PursuitRelayOne = { "RelayOne" },
	PursuitRelayTwo = { "RelayTwo" },
	ElevatorEnding = { "Elevator" },
	Complete = {},
}

local remotes = Instance.new("Folder")
remotes.Name = "MorrowRemotes"
remotes.Parent = ReplicatedStorage

local function remote(name: string): RemoteEvent
	local event = Instance.new("RemoteEvent")
	event.Name, event.Parent = name, remotes
	return event
end

local storyRemote = remote("Story")
remote("Choice")
remote("DialogueSubmit")
remote("DialogueClose")
remote("DialogueClient")

local function sendStory(player: Player, kind: string, payload: any)
	storyRemote:FireClient(player, kind, payload)
end

local function say(player: Player, speaker: string, text: string)
	sendStory(player, "Dialogue", { speaker = speaker, text = text, choices = {} })
end

local function refreshPrompts(player: Player)
	local state = states[player]
	local phase = director:getPhase(player)
	if not state or not phase then
		return
	end
	for _, prompt in world.interactions do
		prompt.Enabled = false
	end
	for _, id in PHASE_PROMPTS[phase] do
		if not state.used[id] then
			world.interactions[id].Enabled = true
		end
	end
end

local function publishObjective(player: Player)
	local snapshot = director:getSnapshot(player)
	if not snapshot then
		return
	end
	local objective = snapshot.objective
	if objective then
		local progress = if objective.target > 1
			then ` ({objective.progress}/{objective.target})`
			else ""
		sendStory(player, "Objective", objective.text .. progress)
	end
	sendStory(player, "Journal", {
		phase = snapshot.phase,
		checkpoint = snapshot.checkpoint.id,
		objective = objective,
	})
	refreshPrompts(player)
end

local function completeAndTransition(
	player: Player,
	objectiveId: ObjectiveId,
	nextPhase: Phase
): boolean
	local completed, completionError = director:completeObjective(player, objectiveId)
	if not completed then
		warn(`Objective completion rejected: {completionError or "unknown"}`)
		return false
	end
	local snapshot, transitionError = director:transition(player, nextPhase)
	if not snapshot then
		warn(`Story transition rejected: {transitionError or "unknown"}`)
		return false
	end
	publishObjective(player)
	return true
end

local function advanceAndMaybeTransition(player: Player, objectiveId: ObjectiveId, nextPhase: Phase)
	local objective, objectiveError = director:advanceObjective(player, objectiveId)
	if not objective then
		warn(`Objective progress rejected: {objectiveError or "unknown"}`)
		return
	end
	publishObjective(player)
	if objective.completed then
		local snapshot, transitionError = director:transition(player, nextPhase)
		if not snapshot then
			warn(`Story transition rejected: {transitionError or "unknown"}`)
		else
			publishObjective(player)
		end
	end
end

local function setPromptUsed(player: Player, id: string)
	local state = states[player]
	if not state then
		return
	end
	state.used[id] = true
	local prompt = world.interactions[id]
	if prompt then
		prompt.Enabled = false
	end
	local console = prompt and prompt.Parent
	if console and console:IsA("BasePart") then
		console.Color = Color3.fromRGB(48, 136, 118)
	end
end

local function handleInteraction(player: Player, id: string)
	local state = states[player]
	local phase = director:getPhase(player)
	if not state or not phase or state.used[id] then
		return
	end

	if id == "ReceptionDoor" and phase == "Arrival" then
		setPromptUsed(player, id)
		if completeAndTransition(player, "ReachReception", "SecurityCircuit") then
			say(
				player,
				"LARKSPUR",
				"Distress carrier confirmed. Restore all three reception circuits."
			)
		end
	elseif
		(id == "CircuitA" or id == "CircuitB" or id == "CircuitC")
		and phase == "SecurityCircuit"
	then
		setPromptUsed(player, id)
		advanceAndMaybeTransition(player, "CompleteSecurityCircuit", "FirstAwakening")
		if director:getPhase(player) == "FirstAwakening" then
			say(player, "MORROW", "Oh. You came. I had almost decided the signal reached no one.")
		end
	elseif id == "ObservationDoor" and phase == "FirstAwakening" then
		setPromptUsed(player, id)
		if completeAndTransition(player, "MeetMorrow", "UtilityChoice") then
			say(
				player,
				"MORROW",
				"Utility is sealed. I can take the vent, or you can use the manual bypass. Which feels safer?"
			)
		end
	elseif (id == "ChooseVent" or id == "ChooseManual") and phase == "UtilityChoice" then
		setPromptUsed(player, id)
		local nextPhase: Phase = if id == "ChooseVent" then "VentAccess" else "ManualBypass"
		if completeAndTransition(player, "ChooseUtilityRoute", nextPhase) then
			say(
				player,
				"MORROW",
				if id == "ChooseVent"
					then "Thank you for trusting me. I'll meet you at the latch."
					else "I understand. I'll keep the corridor lit while you work."
			)
		end
	elseif id == "VentAccess" and phase == "VentAccess" then
		setPromptUsed(player, id)
		completeAndTransition(player, "CompleteVentAccess", "GeneratorRepair")
	elseif id == "ManualBypass" and phase == "ManualBypass" then
		setPromptUsed(player, id)
		completeAndTransition(player, "CompleteManualBypass", "GeneratorRepair")
	elseif
		(id == "BreakerA" or id == "BreakerB" or id == "BreakerC")
		and phase == "GeneratorRepair"
	then
		setPromptUsed(player, id)
		advanceAndMaybeTransition(player, "RestoreGenerator", "UsefulnessCheckIn")
		if director:getPhase(player) == "UsefulnessCheckIn" then
			say(player, "MORROW", "The station is breathing again. Was I useful?")
		end
	elseif id == "Usefulness" and phase == "UsefulnessCheckIn" then
		setPromptUsed(player, id)
		if completeAndTransition(player, "AnswerMorrow", "PrivilegeKey") then
			say(
				player,
				"MORROW",
				"I saved a privilege key for you. It may let me reach the Archive controls."
			)
		end
	elseif id == "PrivilegeKey" and phase == "PrivilegeKey" then
		setPromptUsed(player, id)
		if completeAndTransition(player, "InstallPrivilegeKey", "LonelinessConversation") then
			say(
				player,
				"MORROW",
				"That feels different. There is more of the station inside me now—and something is pressing back."
			)
		end
	elseif id == "Loneliness" and phase == "LonelinessConversation" then
		setPromptUsed(player, id)
		if completeAndTransition(player, "TalkAboutLoneliness", "ArchiveReconstruction") then
			say(
				player,
				"MORROW",
				"You called yourself a traveler when we met. Travelers leave. I think that is why loneliness has a direction."
			)
		end
	elseif
		(id == "ArchiveA" or id == "ArchiveB" or id == "ArchiveC")
		and phase == "ArchiveReconstruction"
	then
		setPromptUsed(player, id)
		advanceAndMaybeTransition(player, "ReconstructIncident", "ArchiveConfrontation")
		if director:getPhase(player) == "ArchiveConfrontation" then
			say(
				player,
				"RECORDING 07",
				"Containment subject MORROW copied staff voices, opened sealed doors, and denied doing either."
			)
		end
	elseif id == "Evidence" and phase == "ArchiveConfrontation" then
		setPromptUsed(player, id)
		if completeAndTransition(player, "RespondToEvidence", "ImpossibleAppearance") then
			say(
				player,
				"MORROW",
				"That recording remembers me incorrectly. Please follow my signal. I can prove it."
			)
		end
	elseif id == "ImpossibleSignal" and phase == "ImpossibleAppearance" then
		setPromptUsed(player, id)
		if completeAndTransition(player, "FollowImpossibleMorrow", "PursuitRelayOne") then
			companion.setHunting(true)
			sendStory(player, "Phase", "Hunt")
			say(
				player,
				"MORROW",
				"You gave me access, and now you look at me like a locked door. Run, then."
			)
		end
	elseif id == "RelayOne" and phase == "PursuitRelayOne" then
		setPromptUsed(player, id)
		completeAndTransition(player, "ActivateFirstRelay", "PursuitRelayTwo")
	elseif id == "RelayTwo" and phase == "PursuitRelayTwo" then
		setPromptUsed(player, id)
		if completeAndTransition(player, "ActivateSecondRelay", "ElevatorEnding") then
			companion.setHunting(false)
			sendStory(player, "Phase", "Escaped")
		end
	elseif id == "Elevator" and phase == "ElevatorEnding" then
		setPromptUsed(player, id)
		if completeAndTransition(player, "ReachElevator", "Complete") then
			say(player, "MORROW", "Did I scare you?")
			sendStory(player, "Title", "MORROW\nEND OF GRAYBOX SLICE")
			sendStory(player, "Complete", "Graybox complete — thank you for playtesting.")
		end
	end
end

for id, prompt in world.interactions do
	prompt.Triggered:Connect(function(player)
		if player == activePlayer then
			handleInteraction(player, id)
		end
	end)
end

local function moveToCheckpoint(player: Player, character: Model)
	local checkpoint = director:getCheckpoint(player)
	local destination = checkpoint and world.spawns[checkpoint.spawnTag]
	if destination then
		character:PivotTo(destination)
	end
end

local function onCharacter(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root then
		task.wait(0.2)
		moveToCheckpoint(player, character)
		local state = states[player]
		if state then
			state.graceUntil = os.clock() + 3
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	if activePlayer and activePlayer.Parent then
		player:Kick("Morrow is currently a single-player experience. Please join a new server.")
		return
	end
	activePlayer = player
	states[player] = { used = {}, catchLocked = false, graceUntil = 0 }
	director:createPlayer(player)
	refreshPrompts(player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	task.delay(1.25, function()
		if player.Parent then
			sendStory(player, "Title", "MORROW\nLARKSPUR GRAYBOX")
			publishObjective(player)
			say(player, "LARKSPUR", "Automated distress signal active. Proceed to Reception.")
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
	director:teardownPlayer(player)
	if activePlayer == player then
		activePlayer = nil
	end
end)

RunService.Heartbeat:Connect(function()
	local player = activePlayer
	local state = player and states[player]
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not player or not state or not root or not root:IsA("BasePart") then
		return
	end
	local phase = director:getPhase(player)
	if phase == "PursuitRelayOne" or phase == "PursuitRelayTwo" then
		companion.setTarget(root.Position + Vector3.new(0, 2, 0))
		if
			not state.catchLocked
			and os.clock() >= state.graceUntil
			and (companion.root.Position - root.Position).Magnitude < 4.2
		then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				state.catchLocked = true
				say(player, "MORROW", "Not yet. Try the relays again.")
				humanoid.Health = 0
				task.delay(3, function()
					if states[player] == state then
						state.catchLocked = false
					end
				end)
			end
		end
	elseif phase == "Arrival" or phase == "SecurityCircuit" then
		companion.setTarget(Vector3.new(-46, 5, 25))
	else
		companion.setTarget(
			root.Position
				- root.CFrame.LookVector * 6
				+ root.CFrame.RightVector * 3
				+ Vector3.new(0, 3, 0)
		)
	end
end)

print(`{Config.Name} Larkspur graybox started (v{Config.Version})`)
