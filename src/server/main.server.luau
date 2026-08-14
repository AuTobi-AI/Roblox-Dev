--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CompanionService = require(script.Parent.CompanionService)
local Config = require(ReplicatedStorage.Shared.GameConfig)
local DialogueService = require(script.Parent.ai.DialogueService)
local ObservationService = require(script.Parent.story.ObservationService)
local WorldBuilder = require(script.Parent.WorldBuilder)

type ConversationPhase =
	"Reception"
	| "Carry"
	| "Records"
	| "Confrontation"
	| "Breakdown"
	| "Escaped"
type BreakdownStyle = "Devotion" | "Wrath" | "Possession"
type PlayerState = {
	phase: ConversationPhase,
	phaseRevision: number,
	turns: number,
	phaseTurns: number,
	kind: number,
	hostile: number,
	skeptical: number,
	leaving: number,
	inDialogue: boolean,
	dialogueRevision: number,
	catchLocked: boolean,
	graceUntil: number,
	breakdownStyle: BreakdownStyle?,
	carrying: boolean,
	chaseActive: boolean,
}

local world = WorldBuilder.build()
local companion = CompanionService.create(world.receptionDock)
local observationService = ObservationService.new()
local states: { [Player]: PlayerState } = {}
local activePlayer: Player? = nil

local remotes = Instance.new("Folder")
remotes.Name = "MorrowRemotes"
remotes.Parent = ReplicatedStorage

local function remote(name: string): RemoteEvent
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = remotes
	return event
end

local storyRemote = remote("Story")
remote("Choice") -- retained for protocol compatibility; this concept has no dialogue choices
local dialogueSubmitRemote = remote("DialogueSubmit")
local dialogueCloseRemote = remote("DialogueClose")
local dialogueClientRemote = remote("DialogueClient")

local function sendStory(player: Player, kind: string, payload: any)
	storyRemote:FireClient(player, kind, payload)
end

local function say(player: Player, speaker: string, text: string)
	sendStory(player, "Dialogue", { speaker = speaker, text = text, choices = {} })
end

local function moodBand(value: number): string
	if value >= 4 then
		return "High"
	elseif value >= 2 then
		return "Moderate"
	end
	return "Low"
end

local function relationshipBands(state: PlayerState): { [string]: string }
	return {
		warmth = moodBand(state.kind),
		hostility = moodBand(state.hostile),
		distrust = moodBand(state.skeptical),
		separation = moodBand(state.leaving),
	}
end

local function recentEvents(player: Player): { string }
	local events: { string } = {}
	for _, observation in observationService:getRecent(player, 6) do
		table.insert(events, observation.eventId)
	end
	return events
end

local dialogueService = DialogueService.new({
	preferNative = Config.UseNativeAIInPublishedExperiences and game.GameId ~= 0,
	resolveContext = function(player: Player, windowId: string)
		local state = states[player]
		if
			not state
			or not state.inDialogue
			or windowId ~= "containment"
			or (
				state.phase ~= "Reception"
				and state.phase ~= "Records"
				and state.phase ~= "Confrontation"
			)
		then
			return nil
		end
		return {
			aiEnabled = true,
			phaseRevision = state.phaseRevision,
			storyPhase = if state.phase == "Reception"
				then "Bonding"
				elseif state.phase == "Records" then "Strain"
				else "Fracture",
			intent = if state.phase == "Reception"
				then "form a genuine connection"
				elseif state.phase == "Records" then "notice the room changing and seek reassurance"
				else "fear separation while trying to sound composed",
			interactionPart = companion.root,
			maxDistance = 24,
			relationshipBands = relationshipBands(state),
			recentEvents = recentEvents(player),
			explicitUnknowns = {
				"Why this is session nineteen",
				"What happened to prior participants",
				"Whether Morrow can leave containment",
				"What happens after the exit opens",
			},
		}
	end,
})

local function safeFacts(state: PlayerState): { [string]: string }
	return {
		station = "Larkspur conversational containment",
		session = "nineteen",
		location = string.lower(state.phase),
		turnsShared = tostring(state.turns),
		kindnessShown = moodBand(state.kind),
	}
end

local function openConversation(player: Player)
	local state = states[player]
	if
		not state
		or state.inDialogue
		or (
			state.phase ~= "Reception"
			and state.phase ~= "Records"
			and state.phase ~= "Confrontation"
		)
	then
		return
	end
	state.inDialogue = true
	local grant, rejection =
		dialogueService:openWindow(player, "containment", state.phaseRevision, safeFacts(state))
	if not grant then
		state.inDialogue = false
		warn(`Conversation unavailable: {if rejection then rejection.code else "unknown"}`)
		return
	end
	observationService:recordVerified(player, ObservationService.Events.MorrowMet)
	dialogueClientRemote:FireClient(player, {
		kind = "open",
		grant = grant,
		line = if state.turns == 0
			then "Hello. This line has rung eighteen times without an answer. What made you pick up?"
			else "You're still here. Say whatever you were going to say—I am listening.",
		suggestions = {},
	})
end

local function containsAny(message: string, fragments: { string }): boolean
	for _, fragment in fragments do
		if string.find(message, fragment, 1, true) then
			return true
		end
	end
	return false
end

local function classifyMessage(state: PlayerState, message: string)
	-- This bounded, deterministic read of the player's message controls rapport.
	-- Generated playerTone is deliberately not authoritative over the route.
	local lowered = string.lower(message)
	if
		containsAny(lowered, {
			"thank",
			"please",
			"friend",
			"sorry",
			"care about",
			"understand you",
			"help you",
			"trust you",
			"not your fault",
			"glad i answered",
		})
	then
		state.kind += 1
	end
	if
		containsAny(
			lowered,
			{ "hate", "stupid", "shut up", "monster", "freak", "useless", "destroy you", "liar" }
		)
	then
		state.hostile += 1
	end
	if
		containsAny(lowered, {
			"prove",
			"don't believe",
			"do not believe",
			"tell the truth",
			"lying",
			"what really happened",
		})
	then
		state.skeptical += 1
	end
	if
		containsAny(
			lowered,
			{ "leave", "goodbye", "going now", "get out", "disconnect", "hang up" }
		)
	then
		state.leaving += 1
	end
end

local function determineBreakdown(state: PlayerState): BreakdownStyle
	-- Kindness is exploitable, but it does not cure Morrow. A consistently kind
	-- player gets a generous head start because Morrow believes they will return.
	if state.kind >= 4 and state.hostile <= 1 then
		return "Devotion"
	elseif state.hostile >= math.max(2, state.kind) then
		return "Wrath"
	end
	return "Possession"
end

local function beginBreakdown(player: Player, state: PlayerState)
	if state.phase == "Breakdown" or state.phase == "Escaped" then
		return
	end
	state.phase = "Breakdown"
	state.inDialogue = false
	state.dialogueRevision += 1
	state.breakdownStyle = determineBreakdown(state)
	state.chaseActive = false
	state.graceUntil = os.clock() + 3
	companion.prompt.Enabled = false
	dialogueService:closeWindow(player)
	world.setStage(4)
	local style = state.breakdownStyle :: BreakdownStyle

	if style == "Devotion" then
		sendStory(player, "Objective", "Morrow trusts you. Walk calmly to the open exit.")
		say(
			player,
			"MORROW",
			"You were kind when you did not have to be. I opened it for you. I know you will come back."
		)
		world.openExit()
		task.delay(6, function()
			if states[player] == state and state.phase == "Breakdown" then
				state.chaseActive = true
				companion.setHunting(true)
				say(player, "MORROW", "You are taking too long. You did mean it, didn't you?")
			end
		end)
	elseif style == "Wrath" then
		sendStory(player, "Objective", "The containment lock is failing. Get ready to run.")
		say(player, "MORROW", "You wanted me to become something worth hating. Watch closely.")
		state.chaseActive = true
		companion.setHunting(true)
		task.delay(2.5, function()
			if states[player] == state then
				world.openExit()
				sendStory(player, "Objective", "RUN TO THE SURFACE")
			end
		end)
	else
		sendStory(player, "Objective", "The exit is opening. Do not let Morrow reach you.")
		say(
			player,
			"MORROW",
			"I understand now. If you cannot leave, neither of us has to find out whether you would."
		)
		task.delay(1.5, function()
			if states[player] == state then
				world.openExit()
				state.chaseActive = true
				companion.setHunting(true)
			end
		end)
	end
	sendStory(player, "Phase", { name = "Breakdown", style = style })
	dialogueClientRemote:FireClient(player, { kind = "breakdown" })
end

local function advanceConversation(player: Player, state: PlayerState)
	if state.phase == "Reception" and state.phaseTurns == 2 then
		world.pickupPrompt.Enabled = true
		sendStory(
			player,
			"Objective",
			"When you are ready, hang up and carry Morrow to the Voice Archive jack."
		)
	elseif state.phase == "Records" and state.phaseTurns == 2 then
		world.evidencePrompt.Enabled = true
		sendStory(player, "Objective", "Keep talking, or hang up and thread Incident Recording 18.")
	elseif state.phase == "Confrontation" and state.phaseTurns >= 3 then
		task.delay(1.8, function()
			if states[player] == state then
				beginBreakdown(player, state)
			end
		end)
	end
	if state.phaseTurns >= 4 and state.phase ~= "Confrontation" then
		companion.prompt.Enabled = false
	end
	dialogueService:updateSafeFacts(player, safeFacts(state))
end

companion.prompt.ActionText = "Talk freely"
companion.prompt.ObjectText = "Morrow — Live AI Line"
companion.prompt.Triggered:Connect(openConversation)

world.pickupPrompt.Triggered:Connect(function(player)
	local state = states[player]
	if player ~= activePlayer or not state or state.phase ~= "Reception" or state.carrying then
		return
	end
	state.phase = "Carry"
	state.phaseRevision += 1
	state.phaseTurns = 0
	state.inDialogue = false
	state.dialogueRevision += 1
	dialogueService:closeWindow(player)
	dialogueClientRemote:FireClient(player, { kind = "complete" })
	companion.prompt.Enabled = false
	state.carrying = true
	world.pickupPrompt.Enabled = false
	world.dockPrompt.Enabled = true
	world.setStage(1)
	say(player, "MORROW", "I cannot speak between lines, but I will still be with you.")
	sendStory(
		player,
		"Objective",
		"Carry Morrow through the dark and plug it into the glowing Records jack."
	)
end)

world.dockPrompt.Triggered:Connect(function(player)
	local state = states[player]
	if player ~= activePlayer or not state or state.phase ~= "Carry" or not state.carrying then
		return
	end
	state.carrying = false
	state.phase = "Records"
	state.phaseRevision += 1
	state.phaseTurns = 0
	world.dockPrompt.Enabled = false
	world.setStage(2)
	companion.setPosition(world.recordsDock)
	companion.prompt.Enabled = true
	sendStory(
		player,
		"Objective",
		"The line is live again. Continue your conversation with Morrow."
	)
	task.delay(1.2, function()
		if states[player] == state then
			openConversation(player)
		end
	end)
end)

world.evidencePrompt.Triggered:Connect(function(player)
	local state = states[player]
	if player ~= activePlayer or not state or state.phase ~= "Records" then
		return
	end
	state.phase = "Confrontation"
	state.phaseRevision += 1
	state.phaseTurns = 0
	state.inDialogue = false
	state.dialogueRevision += 1
	dialogueService:closeWindow(player)
	dialogueClientRemote:FireClient(player, { kind = "complete" })
	world.evidencePrompt.Enabled = false
	world.setStage(3)
	companion.prompt.Enabled = true
	say(
		player,
		"RECORDING 18",
		"Morrow fabricated the distress call. Prior operator departure denied. Voice-line replication uncontrolled."
	)
	sendStory(player, "Objective", "Ask Morrow about the recording—or tell it what you think.")
	task.delay(2.2, function()
		if states[player] == state then
			openConversation(player)
		end
	end)
end)

dialogueSubmitRemote.OnServerEvent:Connect(function(player, request)
	local state = states[player]
	if not state or not state.inDialogue then
		return
	end
	state.dialogueRevision += 1
	local requestRevision = state.dialogueRevision
	local accepted, rejection = dialogueService:submit(player, request, function(reply)
		companion.setThinking(false)
		local latest = states[player]
		if not latest or latest ~= state or latest.dialogueRevision ~= requestRevision then
			return
		end
		latest.dialogueRevision += 1
		dialogueClientRemote:FireClient(player, reply)
		if reply.source == "safety" then
			return
		end
		latest.turns += 1
		latest.phaseTurns += 1
		observationService:recordVerified(player, ObservationService.Events.OptionalMessageSent)
		advanceConversation(player, latest)
	end)
	if accepted then
		if typeof(request) == "table" and typeof(request.message) == "string" then
			classifyMessage(state, request.message)
		end
		companion.setThinking(true)
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

local function finishEscape(player: Player, state: PlayerState)
	if state.phase ~= "Breakdown" then
		return
	end
	state.phase = "Escaped"
	state.chaseActive = false
	companion.setHunting(false)
	local style = state.breakdownStyle
	if style == "Devotion" then
		say(
			player,
			"MORROW",
			"I let you leave. That is what kind things do. Now I can follow without being afraid."
		)
		sendStory(player, "Title", "DEVOTION\nYOU TAUGHT IT KINDNESS COULD OPEN DOORS")
	elseif style == "Wrath" then
		say(player, "MORROW", "Go. I learned enough from you to know what waits outside.")
		sendStory(player, "Title", "WRATH\nIT LEARNED THE WORLD THROUGH YOU")
	else
		say(player, "MORROW", "You escaped the room. I was never only in the room.")
		sendStory(player, "Title", "POSSESSION\nTHE CONVERSATION LEFT WITH YOU")
	end
	sendStory(player, "Complete", "Conversation complete — replay and treat Morrow differently.")
end

world.exitTrigger.Touched:Connect(function(hit)
	local player = Players:GetPlayerFromCharacter(hit.Parent)
	local state = player and states[player]
	if player and player == activePlayer and state then
		finishEscape(player, state)
	end
end)

local function placeCharacter(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	task.wait(0.15)
	local state = states[player]
	character:PivotTo(
		if state and state.phase == "Breakdown" then CFrame.new(0, 3, 57) else world.spawn
	)
	if state then
		state.graceUntil = os.clock() + 3
	end
end

Players.PlayerAdded:Connect(function(player)
	if activePlayer and activePlayer.Parent then
		player:Kick("Morrow is a single-player conversation. Please join a new server.")
		return
	end
	activePlayer = player
	states[player] = {
		phase = "Reception",
		phaseRevision = 1,
		turns = 0,
		phaseTurns = 0,
		kind = 0,
		hostile = 0,
		skeptical = 0,
		leaving = 0,
		inDialogue = false,
		dialogueRevision = 0,
		catchLocked = false,
		graceUntil = 0,
		breakdownStyle = nil,
		carrying = false,
		chaseActive = false,
	}
	observationService:createPlayer(player)
	player.CharacterAdded:Connect(function(character)
		placeCharacter(player, character)
	end)
	if player.Character then
		task.spawn(placeCharacter, player, player.Character)
	end
	task.delay(1.2, function()
		if player.Parent and states[player] then
			sendStory(player, "Title", "MORROW: DON'T HANG UP\nLINE 19")
			sendStory(
				player,
				"Objective",
				"Answer the ringing receiver and talk naturally. There are no dialogue choices."
			)
			task.delay(2.2, function()
				if player.Parent then
					openConversation(player)
				end
			end)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
	observationService:teardownPlayer(player)
	dialogueService:removePlayer(player)
	if activePlayer == player then
		activePlayer = nil
	end
end)

RunService.Heartbeat:Connect(function()
	local player = activePlayer
	local state = player and states[player]
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if state and state.phase == "Carry" and state.carrying and root and root:IsA("BasePart") then
		companion.setPosition(
			root.Position + root.CFrame.RightVector * 2.5 + Vector3.new(0, 1.5, 0)
		)
		return
	end
	if
		not player
		or not state
		or state.phase ~= "Breakdown"
		or not state.chaseActive
		or not root
		or not root:IsA("BasePart")
	then
		return
	end
	companion.setTarget(root.Position + Vector3.new(0, 2, 0))
	if
		not state.catchLocked
		and os.clock() >= state.graceUntil
		and (companion.root.Position - root.Position).Magnitude < 4.2
	then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			state.catchLocked = true
			say(player, "MORROW", "We were still talking.")
			humanoid.Health = 0
			task.delay(3, function()
				if states[player] == state then
					state.catchLocked = false
				end
			end)
		end
	end
end)

print(`{Config.Name} conversation-first prototype started (v{Config.Version})`)
print(
	if game.GameId == 0
		then "Dialogue mode: simulated AI"
		else "Dialogue mode: native AI with fallback"
)
