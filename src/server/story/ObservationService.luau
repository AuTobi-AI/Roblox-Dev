--!strict

-- ObservationService stores only server-verified, low-cardinality event IDs.
-- It deliberately accepts no free-form payload, player text, generated text, or
-- context token, keeping this ledger safe to summarize for Morrow's prompt.

local ObservationService = {}
ObservationService.__index = ObservationService

export type EventId =
	"ArrivedAtReception"
	| "SecurityTileAligned"
	| "SecurityCircuitCompleted"
	| "AiDisclosureAcknowledged"
	| "MorrowMet"
	| "ConversationWindowCompleted"
	| "OptionalMessageSent"
	| "VentRouteChosen"
	| "ManualBypassChosen"
	| "GeneratorBreakerSynchronized"
	| "GeneratorRestored"
	| "UsefulnessQuestionAnswered"
	| "PrivilegeKeyInstalledInMorrow"
	| "PrivilegeKeyInstalledInTerminal"
	| "LonelinessConversationCompleted"
	| "ArchiveClipPlaced"
	| "ArchiveRecordingReconstructed"
	| "ArchiveEvidencePlayed"
	| "ArchiveEvidenceConfronted"
	| "ArchiveEvidenceReassured"
	| "ArchiveEvidenceAvoided"
	| "ImpossibleAppearanceWitnessed"
	| "PursuitStarted"
	| "RelayOneActivated"
	| "RelayTwoActivated"
	| "PlayerCaught"
	| "ElevatorReached"
	| "SliceCompleted"
	| "MorrowAskedToWait"
	| "MorrowCalled"
	| "MorrowHintUsed"

export type Observation = {
	sequence: number,
	eventId: EventId,
	observedAt: number,
}

export type ObservationSnapshot = {
	events: { Observation },
	counts: { [EventId]: number },
	sequence: number,
	startedAt: number,
}

type EventDefinition = {
	maxCount: number,
}

type ObservationState = {
	events: { Observation },
	counts: { [EventId]: number },
	sequence: number,
	startedAt: number,
}

export type Service = typeof(setmetatable(
	{} :: {
		_states: { [Player]: ObservationState },
	},
	ObservationService
))

local MAX_LEDGER_ENTRIES = 64
local MAX_RECENT_QUERY = 10

local EVENTS = table.freeze({
	ArrivedAtReception = "ArrivedAtReception" :: EventId,
	SecurityTileAligned = "SecurityTileAligned" :: EventId,
	SecurityCircuitCompleted = "SecurityCircuitCompleted" :: EventId,
	AiDisclosureAcknowledged = "AiDisclosureAcknowledged" :: EventId,
	MorrowMet = "MorrowMet" :: EventId,
	ConversationWindowCompleted = "ConversationWindowCompleted" :: EventId,
	OptionalMessageSent = "OptionalMessageSent" :: EventId,
	VentRouteChosen = "VentRouteChosen" :: EventId,
	ManualBypassChosen = "ManualBypassChosen" :: EventId,
	GeneratorBreakerSynchronized = "GeneratorBreakerSynchronized" :: EventId,
	GeneratorRestored = "GeneratorRestored" :: EventId,
	UsefulnessQuestionAnswered = "UsefulnessQuestionAnswered" :: EventId,
	PrivilegeKeyInstalledInMorrow = "PrivilegeKeyInstalledInMorrow" :: EventId,
	PrivilegeKeyInstalledInTerminal = "PrivilegeKeyInstalledInTerminal" :: EventId,
	LonelinessConversationCompleted = "LonelinessConversationCompleted" :: EventId,
	ArchiveClipPlaced = "ArchiveClipPlaced" :: EventId,
	ArchiveRecordingReconstructed = "ArchiveRecordingReconstructed" :: EventId,
	ArchiveEvidencePlayed = "ArchiveEvidencePlayed" :: EventId,
	ArchiveEvidenceConfronted = "ArchiveEvidenceConfronted" :: EventId,
	ArchiveEvidenceReassured = "ArchiveEvidenceReassured" :: EventId,
	ArchiveEvidenceAvoided = "ArchiveEvidenceAvoided" :: EventId,
	ImpossibleAppearanceWitnessed = "ImpossibleAppearanceWitnessed" :: EventId,
	PursuitStarted = "PursuitStarted" :: EventId,
	RelayOneActivated = "RelayOneActivated" :: EventId,
	RelayTwoActivated = "RelayTwoActivated" :: EventId,
	PlayerCaught = "PlayerCaught" :: EventId,
	ElevatorReached = "ElevatorReached" :: EventId,
	SliceCompleted = "SliceCompleted" :: EventId,
	MorrowAskedToWait = "MorrowAskedToWait" :: EventId,
	MorrowCalled = "MorrowCalled" :: EventId,
	MorrowHintUsed = "MorrowHintUsed" :: EventId,
})

local EVENT_DEFINITIONS: { [EventId]: EventDefinition } = {
	ArrivedAtReception = { maxCount = 1 },
	SecurityTileAligned = { maxCount = 3 },
	SecurityCircuitCompleted = { maxCount = 1 },
	AiDisclosureAcknowledged = { maxCount = 1 },
	MorrowMet = { maxCount = 1 },
	ConversationWindowCompleted = { maxCount = 3 },
	OptionalMessageSent = { maxCount = 12 },
	VentRouteChosen = { maxCount = 1 },
	ManualBypassChosen = { maxCount = 1 },
	GeneratorBreakerSynchronized = { maxCount = 3 },
	GeneratorRestored = { maxCount = 1 },
	UsefulnessQuestionAnswered = { maxCount = 1 },
	PrivilegeKeyInstalledInMorrow = { maxCount = 1 },
	PrivilegeKeyInstalledInTerminal = { maxCount = 1 },
	LonelinessConversationCompleted = { maxCount = 1 },
	ArchiveClipPlaced = { maxCount = 3 },
	ArchiveRecordingReconstructed = { maxCount = 1 },
	ArchiveEvidencePlayed = { maxCount = 1 },
	ArchiveEvidenceConfronted = { maxCount = 1 },
	ArchiveEvidenceReassured = { maxCount = 1 },
	ArchiveEvidenceAvoided = { maxCount = 1 },
	ImpossibleAppearanceWitnessed = { maxCount = 1 },
	PursuitStarted = { maxCount = 1 },
	RelayOneActivated = { maxCount = 1 },
	RelayTwoActivated = { maxCount = 1 },
	PlayerCaught = { maxCount = 8 },
	ElevatorReached = { maxCount = 1 },
	SliceCompleted = { maxCount = 1 },
	MorrowAskedToWait = { maxCount = 4 },
	MorrowCalled = { maxCount = 6 },
	MorrowHintUsed = { maxCount = 6 },
}

ObservationService.Events = EVENTS

local function cloneObservation(observation: Observation): Observation
	return {
		sequence = observation.sequence,
		eventId = observation.eventId,
		observedAt = observation.observedAt,
	}
end

local function cloneEvents(events: { Observation }): { Observation }
	local result: { Observation } = {}
	for _, observation in events do
		table.insert(result, cloneObservation(observation))
	end
	return result
end

local function cloneCounts(counts: { [EventId]: number }): { [EventId]: number }
	return table.clone(counts)
end

local function makeSnapshot(state: ObservationState): ObservationSnapshot
	return {
		events = cloneEvents(state.events),
		counts = cloneCounts(state.counts),
		sequence = state.sequence,
		startedAt = state.startedAt,
	}
end

function ObservationService.new(): Service
	return setmetatable({
		_states = {},
	}, ObservationService)
end

function ObservationService.createPlayer(
	self: Service,
	player: Player
): (ObservationSnapshot?, string?)
	if self._states[player] ~= nil then
		return nil, "player already has an observation ledger"
	end

	local state: ObservationState = {
		events = {},
		counts = {},
		sequence = 0,
		startedAt = os.clock(),
	}
	self._states[player] = state

	return makeSnapshot(state), nil
end

function ObservationService.hasPlayer(self: Service, player: Player): boolean
	return self._states[player] ~= nil
end

function ObservationService.recordVerified(
	self: Service,
	player: Player,
	eventId: EventId
): (Observation?, string?)
	local state = self._states[player]
	if state == nil then
		return nil, "player has no observation ledger"
	end

	local definition = EVENT_DEFINITIONS[eventId]
	if definition == nil then
		return nil, "unknown observation event"
	end

	local count = state.counts[eventId] or 0
	if count >= definition.maxCount then
		return nil, `observation event {eventId} reached its per-run limit`
	end

	state.sequence += 1
	state.counts[eventId] = count + 1
	local observation: Observation = {
		sequence = state.sequence,
		eventId = eventId,
		observedAt = os.clock(),
	}
	table.insert(state.events, observation)
	if #state.events > MAX_LEDGER_ENTRIES then
		table.remove(state.events, 1)
	end

	return cloneObservation(observation), nil
end

function ObservationService.getSnapshot(self: Service, player: Player): ObservationSnapshot?
	local state = self._states[player]
	return if state == nil then nil else makeSnapshot(state)
end

function ObservationService.getRecent(
	self: Service,
	player: Player,
	requestedLimit: number?
): { Observation }
	local state = self._states[player]
	if state == nil then
		return {}
	end

	local limit = requestedLimit or 6
	if limit ~= limit then
		limit = 6
	end
	limit = math.clamp(math.floor(limit), 0, MAX_RECENT_QUERY)

	local firstIndex = math.max(1, #state.events - limit + 1)
	local recent: { Observation } = {}
	for index = firstIndex, #state.events do
		table.insert(recent, cloneObservation(state.events[index]))
	end
	return recent
end

function ObservationService.hasObserved(self: Service, player: Player, eventId: EventId): boolean
	local state = self._states[player]
	return state ~= nil and (state.counts[eventId] or 0) > 0
end

function ObservationService.getCount(self: Service, player: Player, eventId: EventId): number
	local state = self._states[player]
	return if state == nil then 0 else state.counts[eventId] or 0
end

function ObservationService.teardownPlayer(self: Service, player: Player): boolean
	if self._states[player] == nil then
		return false
	end

	self._states[player] = nil
	return true
end

function ObservationService.destroy(self: Service)
	table.clear(self._states)
end

return ObservationService
