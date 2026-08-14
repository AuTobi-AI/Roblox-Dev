--!strict

-- StoryDirector is the only owner of vertical-slice progression. It intentionally
-- has no knowledge of remotes or dialogue generation: trusted server systems
-- complete an objective, then request the one legal next phase.

local StoryDirector = {}
StoryDirector.__index = StoryDirector

export type Phase =
	"Arrival"
	| "SecurityCircuit"
	| "FirstAwakening"
	| "UtilityChoice"
	| "VentAccess"
	| "ManualBypass"
	| "GeneratorRepair"
	| "UsefulnessCheckIn"
	| "PrivilegeKey"
	| "LonelinessConversation"
	| "ArchiveReconstruction"
	| "ArchiveConfrontation"
	| "ImpossibleAppearance"
	| "PursuitRelayOne"
	| "PursuitRelayTwo"
	| "ElevatorEnding"
	| "Complete"

export type ObjectiveId =
	"ReachReception"
	| "CompleteSecurityCircuit"
	| "MeetMorrow"
	| "ChooseUtilityRoute"
	| "CompleteVentAccess"
	| "CompleteManualBypass"
	| "RestoreGenerator"
	| "AnswerMorrow"
	| "InstallPrivilegeKey"
	| "TalkAboutLoneliness"
	| "ReconstructIncident"
	| "RespondToEvidence"
	| "FollowImpossibleMorrow"
	| "ActivateFirstRelay"
	| "ActivateSecondRelay"
	| "ReachElevator"

export type CheckpointId =
	"Arrival"
	| "Observation"
	| "Utility"
	| "Archive"
	| "PursuitStart"
	| "RelayOne"
	| "RelayTwo"
	| "Elevator"

export type ObjectiveSnapshot = {
	id: ObjectiveId,
	text: string,
	progress: number,
	target: number,
	completed: boolean,
	revision: number,
}

export type CheckpointSnapshot = {
	id: CheckpointId,
	spawnTag: string,
	phase: Phase,
	phaseRevision: number,
	reachedAt: number,
}

export type TransitionSnapshot = {
	from: Phase,
	to: Phase,
	revision: number,
	transitionedAt: number,
}

export type StorySnapshot = {
	phase: Phase,
	phaseRevision: number,
	objective: ObjectiveSnapshot?,
	checkpoint: CheckpointSnapshot,
	startedAt: number,
}

type ObjectiveDefinition = {
	id: ObjectiveId,
	text: string,
	target: number,
}

type ObjectiveState = ObjectiveSnapshot
type CheckpointState = CheckpointSnapshot

type Session = {
	phase: Phase,
	phaseRevision: number,
	objective: ObjectiveState?,
	checkpoint: CheckpointState,
	startedAt: number,
	transitions: { TransitionSnapshot },
}

export type Director = typeof(setmetatable(
	{} :: {
		_sessions: { [Player]: Session },
	},
	StoryDirector
))

local INITIAL_PHASE: Phase = "Arrival"
local MAX_TRANSITION_HISTORY = 24

local PHASES = table.freeze({
	Arrival = "Arrival" :: Phase,
	SecurityCircuit = "SecurityCircuit" :: Phase,
	FirstAwakening = "FirstAwakening" :: Phase,
	UtilityChoice = "UtilityChoice" :: Phase,
	VentAccess = "VentAccess" :: Phase,
	ManualBypass = "ManualBypass" :: Phase,
	GeneratorRepair = "GeneratorRepair" :: Phase,
	UsefulnessCheckIn = "UsefulnessCheckIn" :: Phase,
	PrivilegeKey = "PrivilegeKey" :: Phase,
	LonelinessConversation = "LonelinessConversation" :: Phase,
	ArchiveReconstruction = "ArchiveReconstruction" :: Phase,
	ArchiveConfrontation = "ArchiveConfrontation" :: Phase,
	ImpossibleAppearance = "ImpossibleAppearance" :: Phase,
	PursuitRelayOne = "PursuitRelayOne" :: Phase,
	PursuitRelayTwo = "PursuitRelayTwo" :: Phase,
	ElevatorEnding = "ElevatorEnding" :: Phase,
	Complete = "Complete" :: Phase,
})

local LEGAL_TRANSITIONS: { [Phase]: { [Phase]: boolean } } = {
	Arrival = { SecurityCircuit = true },
	SecurityCircuit = { FirstAwakening = true },
	FirstAwakening = { UtilityChoice = true },
	UtilityChoice = { VentAccess = true, ManualBypass = true },
	VentAccess = { GeneratorRepair = true },
	ManualBypass = { GeneratorRepair = true },
	GeneratorRepair = { UsefulnessCheckIn = true },
	UsefulnessCheckIn = { PrivilegeKey = true },
	PrivilegeKey = { LonelinessConversation = true },
	LonelinessConversation = { ArchiveReconstruction = true },
	ArchiveReconstruction = { ArchiveConfrontation = true },
	ArchiveConfrontation = { ImpossibleAppearance = true },
	ImpossibleAppearance = { PursuitRelayOne = true },
	PursuitRelayOne = { PursuitRelayTwo = true },
	PursuitRelayTwo = { ElevatorEnding = true },
	ElevatorEnding = { Complete = true },
	Complete = {},
}

local OBJECTIVES: { [Phase]: ObjectiveDefinition? } = {
	Arrival = {
		id = "ReachReception",
		text = "Follow the distress signal to Larkspur reception",
		target = 1,
	},
	SecurityCircuit = {
		id = "CompleteSecurityCircuit",
		text = "Restore the reception security circuit",
		target = 3,
	},
	FirstAwakening = {
		id = "MeetMorrow",
		text = "Enter Observation and speak with Morrow",
		target = 1,
	},
	UtilityChoice = {
		id = "ChooseUtilityRoute",
		text = "Choose how to open Utility",
		target = 1,
	},
	VentAccess = {
		id = "CompleteVentAccess",
		text = "Help Morrow open the Utility vent route",
		target = 1,
	},
	ManualBypass = {
		id = "CompleteManualBypass",
		text = "Complete the exterior Utility bypass",
		target = 1,
	},
	GeneratorRepair = {
		id = "RestoreGenerator",
		text = "Synchronize the three generator breakers",
		target = 3,
	},
	UsefulnessCheckIn = {
		id = "AnswerMorrow",
		text = "Answer Morrow's question",
		target = 1,
	},
	PrivilegeKey = {
		id = "InstallPrivilegeKey",
		text = "Choose where to install the privilege key",
		target = 1,
	},
	LonelinessConversation = {
		id = "TalkAboutLoneliness",
		text = "Talk with Morrow before entering the Archive",
		target = 1,
	},
	ArchiveReconstruction = {
		id = "ReconstructIncident",
		text = "Reconstruct the damaged incident recording",
		target = 3,
	},
	ArchiveConfrontation = {
		id = "RespondToEvidence",
		text = "Decide how to respond to Morrow",
		target = 1,
	},
	ImpossibleAppearance = {
		id = "FollowImpossibleMorrow",
		text = "Find the source of Morrow's signal",
		target = 1,
	},
	PursuitRelayOne = {
		id = "ActivateFirstRelay",
		text = "Activate the Archive isolation relay",
		target = 1,
	},
	PursuitRelayTwo = {
		id = "ActivateSecondRelay",
		text = "Activate the Utility isolation relay",
		target = 1,
	},
	ElevatorEnding = {
		id = "ReachElevator",
		text = "Reach the evacuation elevator",
		target = 1,
	},
	Complete = nil,
}

local CHECKPOINTS: { [Phase]: { id: CheckpointId, spawnTag: string }? } = {
	Arrival = { id = "Arrival", spawnTag = "ArrivalSpawn" },
	FirstAwakening = { id = "Observation", spawnTag = "ObservationSpawn" },
	GeneratorRepair = { id = "Utility", spawnTag = "UtilitySpawn" },
	ArchiveConfrontation = { id = "Archive", spawnTag = "ArchiveSpawn" },
	PursuitRelayOne = { id = "PursuitStart", spawnTag = "PursuitStartSpawn" },
	PursuitRelayTwo = { id = "RelayOne", spawnTag = "RelayOneSpawn" },
	ElevatorEnding = { id = "RelayTwo", spawnTag = "RelayTwoSpawn" },
	Complete = { id = "Elevator", spawnTag = "ElevatorSpawn" },
}

StoryDirector.Phases = PHASES

local function cloneObjective(objective: ObjectiveState?): ObjectiveSnapshot?
	if objective == nil then
		return nil
	end

	return {
		id = objective.id,
		text = objective.text,
		progress = objective.progress,
		target = objective.target,
		completed = objective.completed,
		revision = objective.revision,
	}
end

local function cloneCheckpoint(checkpoint: CheckpointState): CheckpointSnapshot
	return {
		id = checkpoint.id,
		spawnTag = checkpoint.spawnTag,
		phase = checkpoint.phase,
		phaseRevision = checkpoint.phaseRevision,
		reachedAt = checkpoint.reachedAt,
	}
end

local function makeObjective(phase: Phase): ObjectiveState?
	local definition = OBJECTIVES[phase]
	if definition == nil then
		return nil
	end

	return {
		id = definition.id,
		text = definition.text,
		progress = 0,
		target = definition.target,
		completed = false,
		revision = 0,
	}
end

local function makeCheckpoint(phase: Phase, phaseRevision: number): CheckpointState?
	local definition = CHECKPOINTS[phase]
	if definition == nil then
		return nil
	end

	return {
		id = definition.id,
		spawnTag = definition.spawnTag,
		phase = phase,
		phaseRevision = phaseRevision,
		reachedAt = os.clock(),
	}
end

function StoryDirector.new(): Director
	return setmetatable({
		_sessions = {},
	}, StoryDirector)
end

function StoryDirector.createPlayer(self: Director, player: Player): (StorySnapshot?, string?)
	if self._sessions[player] ~= nil then
		return nil, "player already has a story session"
	end

	local checkpoint = makeCheckpoint(INITIAL_PHASE, 0)
	assert(checkpoint ~= nil, "initial story phase must define a checkpoint")

	local startedAt = os.clock()
	local session: Session = {
		phase = INITIAL_PHASE,
		phaseRevision = 0,
		objective = makeObjective(INITIAL_PHASE),
		checkpoint = checkpoint,
		startedAt = startedAt,
		transitions = {},
	}
	self._sessions[player] = session

	return self:getSnapshot(player), nil
end

function StoryDirector.hasPlayer(self: Director, player: Player): boolean
	return self._sessions[player] ~= nil
end

function StoryDirector.getPhase(self: Director, player: Player): Phase?
	local session = self._sessions[player]
	return if session == nil then nil else session.phase
end

function StoryDirector.getPhaseRevision(self: Director, player: Player): number?
	local session = self._sessions[player]
	return if session == nil then nil else session.phaseRevision
end

function StoryDirector.getSnapshot(self: Director, player: Player): StorySnapshot?
	local session = self._sessions[player]
	if session == nil then
		return nil
	end

	return {
		phase = session.phase,
		phaseRevision = session.phaseRevision,
		objective = cloneObjective(session.objective),
		checkpoint = cloneCheckpoint(session.checkpoint),
		startedAt = session.startedAt,
	}
end

function StoryDirector.getObjective(self: Director, player: Player): ObjectiveSnapshot?
	local session = self._sessions[player]
	return if session == nil then nil else cloneObjective(session.objective)
end

function StoryDirector.getCheckpoint(self: Director, player: Player): CheckpointSnapshot?
	local session = self._sessions[player]
	return if session == nil then nil else cloneCheckpoint(session.checkpoint)
end

function StoryDirector.getTransitionHistory(self: Director, player: Player): { TransitionSnapshot }
	local session = self._sessions[player]
	if session == nil then
		return {}
	end

	local history: { TransitionSnapshot } = {}
	for _, transition in session.transitions do
		table.insert(history, {
			from = transition.from,
			to = transition.to,
			revision = transition.revision,
			transitionedAt = transition.transitionedAt,
		})
	end
	return history
end

function StoryDirector.canTransition(
	self: Director,
	player: Player,
	nextPhase: Phase
): (boolean, string?)
	local session = self._sessions[player]
	if session == nil then
		return false, "player has no story session"
	end
	if session.phase == nextPhase then
		return false, "story is already in that phase"
	end
	if LEGAL_TRANSITIONS[session.phase][nextPhase] ~= true then
		return false, `illegal story transition from {session.phase} to {nextPhase}`
	end
	if session.objective ~= nil and not session.objective.completed then
		return false, `objective {session.objective.id} is incomplete`
	end

	return true, nil
end

function StoryDirector.advanceObjective(
	self: Director,
	player: Player,
	expectedObjectiveId: ObjectiveId,
	amount: number?
): (ObjectiveSnapshot?, string?)
	local session = self._sessions[player]
	if session == nil then
		return nil, "player has no story session"
	end

	local objective = session.objective
	if objective == nil then
		return nil, "current phase has no objective"
	end
	if objective.id ~= expectedObjectiveId then
		return nil, `stale objective; expected {objective.id}`
	end
	if objective.completed then
		return cloneObjective(objective), nil
	end

	local increment = amount or 1
	if increment % 1 ~= 0 or increment <= 0 then
		return nil, "objective progress must be a positive integer"
	end

	objective.progress = math.min(objective.progress + increment, objective.target)
	objective.completed = objective.progress >= objective.target
	objective.revision += 1

	return cloneObjective(objective), nil
end

function StoryDirector.completeObjective(
	self: Director,
	player: Player,
	expectedObjectiveId: ObjectiveId
): (ObjectiveSnapshot?, string?)
	local session = self._sessions[player]
	if session == nil then
		return nil, "player has no story session"
	end

	local objective = session.objective
	if objective == nil then
		return nil, "current phase has no objective"
	end
	if objective.id ~= expectedObjectiveId then
		return nil, `stale objective; expected {objective.id}`
	end
	if not objective.completed then
		objective.progress = objective.target
		objective.completed = true
		objective.revision += 1
	end

	return cloneObjective(objective), nil
end

function StoryDirector.transition(
	self: Director,
	player: Player,
	nextPhase: Phase,
	expectedRevision: number?
): (StorySnapshot?, string?)
	local session = self._sessions[player]
	if session == nil then
		return nil, "player has no story session"
	end
	if expectedRevision ~= nil and expectedRevision ~= session.phaseRevision then
		return nil, "stale phase revision"
	end

	local allowed, reason = self:canTransition(player, nextPhase)
	if not allowed then
		return nil, reason
	end

	local previousPhase = session.phase
	session.phase = nextPhase
	session.phaseRevision += 1
	session.objective = makeObjective(nextPhase)

	local checkpoint = makeCheckpoint(nextPhase, session.phaseRevision)
	if checkpoint ~= nil then
		session.checkpoint = checkpoint
	end

	table.insert(session.transitions, {
		from = previousPhase,
		to = nextPhase,
		revision = session.phaseRevision,
		transitionedAt = os.clock(),
	})
	if #session.transitions > MAX_TRANSITION_HISTORY then
		table.remove(session.transitions, 1)
	end

	return self:getSnapshot(player), nil
end

function StoryDirector.teardownPlayer(self: Director, player: Player): boolean
	if self._sessions[player] == nil then
		return false
	end

	self._sessions[player] = nil
	return true
end

function StoryDirector.destroy(self: Director)
	table.clear(self._sessions)
end

return StoryDirector
