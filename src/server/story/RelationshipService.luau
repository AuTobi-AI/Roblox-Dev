--!strict

-- RelationshipService turns a small whitelist of verified gameplay actions into
-- narrative dimensions. Callers cannot provide arbitrary deltas, so client text
-- or AI classifications can never become authoritative relationship state.

local RelationshipService = {}
RelationshipService.__index = RelationshipService

export type RelationshipStyle = "Confidant" | "Caretaker" | "Investigator" | "Avoidant" | "Enabler"
export type RelationshipBand = "Low" | "Moderate" | "High"

export type ActionId =
	"OptionalMessageSent"
	| "ThankedMorrow"
	| "ComfortedMorrow"
	| "AnsweredHonestly"
	| "SetBoundary"
	| "AskedMorrowToWait"
	| "CalledMorrow"
	| "VentRouteChosen"
	| "ManualBypassChosen"
	| "FollowedVerifiedHint"
	| "PrivilegeKeyInstalledInMorrow"
	| "PrivilegeKeyInstalledInTerminal"
	| "WarmUsefulnessAnswer"
	| "DirectUsefulnessAnswer"
	| "AvoidedUsefulnessAnswer"
	| "ConfrontedArchiveEvidence"
	| "ReassuredAfterEvidence"
	| "AvoidedArchiveEvidence"
	| "ExplainedDeparture"
	| "LiedAboutDeparture"
	| "AttemptedExit"

export type DimensionScores = {
	warmth: number,
	candor: number,
	compliance: number,
	autonomy: number,
}

export type DimensionBands = {
	warmth: RelationshipBand,
	candor: RelationshipBand,
	compliance: RelationshipBand,
	autonomy: RelationshipBand,
}

export type RelationshipSnapshot = {
	scores: DimensionScores,
	bands: DimensionBands,
	style: RelationshipStyle,
	totalActions: number,
	engagement: number,
	lastAction: ActionId?,
	actionCounts: { [ActionId]: number },
	revision: number,
}

type ActionDefinition = {
	warmth: number,
	candor: number,
	compliance: number,
	autonomy: number,
	engagement: number,
	maxCount: number,
}

type RelationshipState = {
	scores: DimensionScores,
	totalActions: number,
	engagement: number,
	lastAction: ActionId?,
	actionCounts: { [ActionId]: number },
	revision: number,
}

export type Service = typeof(setmetatable(
	{} :: {
		_states: { [Player]: RelationshipState },
	},
	RelationshipService
))

local MIN_SCORE = -12
local MAX_SCORE = 12
local MIN_ENGAGEMENT_FOR_STYLE = 3

local ACTIONS = table.freeze({
	OptionalMessageSent = "OptionalMessageSent" :: ActionId,
	ThankedMorrow = "ThankedMorrow" :: ActionId,
	ComfortedMorrow = "ComfortedMorrow" :: ActionId,
	AnsweredHonestly = "AnsweredHonestly" :: ActionId,
	SetBoundary = "SetBoundary" :: ActionId,
	AskedMorrowToWait = "AskedMorrowToWait" :: ActionId,
	CalledMorrow = "CalledMorrow" :: ActionId,
	VentRouteChosen = "VentRouteChosen" :: ActionId,
	ManualBypassChosen = "ManualBypassChosen" :: ActionId,
	FollowedVerifiedHint = "FollowedVerifiedHint" :: ActionId,
	PrivilegeKeyInstalledInMorrow = "PrivilegeKeyInstalledInMorrow" :: ActionId,
	PrivilegeKeyInstalledInTerminal = "PrivilegeKeyInstalledInTerminal" :: ActionId,
	WarmUsefulnessAnswer = "WarmUsefulnessAnswer" :: ActionId,
	DirectUsefulnessAnswer = "DirectUsefulnessAnswer" :: ActionId,
	AvoidedUsefulnessAnswer = "AvoidedUsefulnessAnswer" :: ActionId,
	ConfrontedArchiveEvidence = "ConfrontedArchiveEvidence" :: ActionId,
	ReassuredAfterEvidence = "ReassuredAfterEvidence" :: ActionId,
	AvoidedArchiveEvidence = "AvoidedArchiveEvidence" :: ActionId,
	ExplainedDeparture = "ExplainedDeparture" :: ActionId,
	LiedAboutDeparture = "LiedAboutDeparture" :: ActionId,
	AttemptedExit = "AttemptedExit" :: ActionId,
})

local STYLES = table.freeze({
	Confidant = "Confidant" :: RelationshipStyle,
	Caretaker = "Caretaker" :: RelationshipStyle,
	Investigator = "Investigator" :: RelationshipStyle,
	Avoidant = "Avoidant" :: RelationshipStyle,
	Enabler = "Enabler" :: RelationshipStyle,
})

local ACTION_DEFINITIONS: { [ActionId]: ActionDefinition } = {
	OptionalMessageSent = {
		warmth = 1,
		candor = 0,
		compliance = 0,
		autonomy = 0,
		engagement = 1,
		maxCount = 3,
	},
	ThankedMorrow = {
		warmth = 2,
		candor = 0,
		compliance = 0,
		autonomy = 0,
		engagement = 1,
		maxCount = 2,
	},
	ComfortedMorrow = {
		warmth = 2,
		candor = 0,
		compliance = 0,
		autonomy = 0,
		engagement = 1,
		maxCount = 2,
	},
	AnsweredHonestly = {
		warmth = 0,
		candor = 2,
		compliance = 0,
		autonomy = 0,
		engagement = 1,
		maxCount = 3,
	},
	SetBoundary = {
		warmth = 0,
		candor = 1,
		compliance = 0,
		autonomy = 2,
		engagement = 1,
		maxCount = 3,
	},
	AskedMorrowToWait = {
		warmth = 0,
		candor = 0,
		compliance = 0,
		autonomy = 1,
		engagement = 1,
		maxCount = 3,
	},
	CalledMorrow = {
		warmth = 1,
		candor = 0,
		compliance = 1,
		autonomy = 0,
		engagement = 1,
		maxCount = 3,
	},
	VentRouteChosen = {
		warmth = 1,
		candor = 0,
		compliance = 3,
		autonomy = 0,
		engagement = 2,
		maxCount = 1,
	},
	ManualBypassChosen = {
		warmth = 0,
		candor = 0,
		compliance = 0,
		autonomy = 3,
		engagement = 2,
		maxCount = 1,
	},
	FollowedVerifiedHint = {
		warmth = 0,
		candor = 0,
		compliance = 1,
		autonomy = 0,
		engagement = 1,
		maxCount = 3,
	},
	PrivilegeKeyInstalledInMorrow = {
		warmth = 1,
		candor = 0,
		compliance = 3,
		autonomy = 0,
		engagement = 2,
		maxCount = 1,
	},
	PrivilegeKeyInstalledInTerminal = {
		warmth = 0,
		candor = 1,
		compliance = 0,
		autonomy = 3,
		engagement = 2,
		maxCount = 1,
	},
	WarmUsefulnessAnswer = {
		warmth = 2,
		candor = 0,
		compliance = 1,
		autonomy = 0,
		engagement = 1,
		maxCount = 1,
	},
	DirectUsefulnessAnswer = {
		warmth = 0,
		candor = 2,
		compliance = 0,
		autonomy = 1,
		engagement = 1,
		maxCount = 1,
	},
	AvoidedUsefulnessAnswer = {
		warmth = 0,
		candor = 0,
		compliance = 0,
		autonomy = 0,
		engagement = 0,
		maxCount = 1,
	},
	ConfrontedArchiveEvidence = {
		warmth = 0,
		candor = 3,
		compliance = 0,
		autonomy = 1,
		engagement = 2,
		maxCount = 1,
	},
	ReassuredAfterEvidence = {
		warmth = 3,
		candor = 0,
		compliance = 1,
		autonomy = 0,
		engagement = 2,
		maxCount = 1,
	},
	AvoidedArchiveEvidence = {
		warmth = 0,
		candor = -1,
		compliance = 0,
		autonomy = 0,
		engagement = 0,
		maxCount = 1,
	},
	ExplainedDeparture = {
		warmth = 1,
		candor = 3,
		compliance = 0,
		autonomy = 1,
		engagement = 2,
		maxCount = 1,
	},
	LiedAboutDeparture = {
		warmth = 0,
		candor = -3,
		compliance = 0,
		autonomy = 0,
		engagement = 1,
		maxCount = 1,
	},
	AttemptedExit = {
		warmth = 0,
		candor = 0,
		compliance = 0,
		autonomy = 2,
		engagement = 1,
		maxCount = 2,
	},
}

RelationshipService.Actions = ACTIONS
RelationshipService.Styles = STYLES

local function cloneScores(scores: DimensionScores): DimensionScores
	return {
		warmth = scores.warmth,
		candor = scores.candor,
		compliance = scores.compliance,
		autonomy = scores.autonomy,
	}
end

local function scoreBand(score: number): RelationshipBand
	if score <= 1 then
		return "Low"
	elseif score <= 5 then
		return "Moderate"
	else
		return "High"
	end
end

local function deriveBands(scores: DimensionScores): DimensionBands
	return {
		warmth = scoreBand(scores.warmth),
		candor = scoreBand(scores.candor),
		compliance = scoreBand(scores.compliance),
		autonomy = scoreBand(scores.autonomy),
	}
end

local function deriveStyle(state: RelationshipState): RelationshipStyle
	if state.engagement < MIN_ENGAGEMENT_FOR_STYLE then
		return "Avoidant"
	end

	local scores = state.scores
	if scores.compliance >= 6 and scores.autonomy <= 2 then
		return "Enabler"
	end

	-- Ties favor candor-bearing styles. This keeps warmth plus honesty distinct
	-- from warmth plus obedience, which is central to Morrow's story.
	local bestStyle: RelationshipStyle = "Confidant"
	local bestScore = scores.warmth + scores.candor
	local investigatorScore = scores.candor + scores.autonomy - scores.compliance * 0.25
	if investigatorScore > bestScore then
		bestStyle = "Investigator"
		bestScore = investigatorScore
	end

	local caretakerScore = scores.warmth + scores.compliance - scores.autonomy * 0.25
	if caretakerScore > bestScore then
		bestStyle = "Caretaker"
	end

	return bestStyle
end

local function makeSnapshot(state: RelationshipState): RelationshipSnapshot
	local actionCounts: { [ActionId]: number } = table.clone(state.actionCounts)

	return {
		scores = cloneScores(state.scores),
		bands = deriveBands(state.scores),
		style = deriveStyle(state),
		totalActions = state.totalActions,
		engagement = state.engagement,
		lastAction = state.lastAction,
		actionCounts = actionCounts,
		revision = state.revision,
	}
end

function RelationshipService.new(): Service
	return setmetatable({
		_states = {},
	}, RelationshipService)
end

function RelationshipService.createPlayer(
	self: Service,
	player: Player
): (RelationshipSnapshot?, string?)
	if self._states[player] ~= nil then
		return nil, "player already has relationship state"
	end

	local state: RelationshipState = {
		scores = {
			warmth = 0,
			candor = 0,
			compliance = 0,
			autonomy = 0,
		},
		totalActions = 0,
		engagement = 0,
		lastAction = nil,
		actionCounts = {},
		revision = 0,
	}
	self._states[player] = state

	return makeSnapshot(state), nil
end

function RelationshipService.hasPlayer(self: Service, player: Player): boolean
	return self._states[player] ~= nil
end

function RelationshipService.getSnapshot(self: Service, player: Player): RelationshipSnapshot?
	local state = self._states[player]
	return if state == nil then nil else makeSnapshot(state)
end

function RelationshipService.getStyle(self: Service, player: Player): RelationshipStyle?
	local state = self._states[player]
	return if state == nil then nil else deriveStyle(state)
end

function RelationshipService.applyAction(
	self: Service,
	player: Player,
	actionId: ActionId
): (RelationshipSnapshot?, string?)
	local state = self._states[player]
	if state == nil then
		return nil, "player has no relationship state"
	end

	local definition = ACTION_DEFINITIONS[actionId]
	if definition == nil then
		return nil, "unknown relationship action"
	end

	local count = state.actionCounts[actionId] or 0
	if count >= definition.maxCount then
		return nil, `relationship action {actionId} reached its per-run limit`
	end

	local scores = state.scores
	scores.warmth = math.clamp(scores.warmth + definition.warmth, MIN_SCORE, MAX_SCORE)
	scores.candor = math.clamp(scores.candor + definition.candor, MIN_SCORE, MAX_SCORE)
	scores.compliance = math.clamp(scores.compliance + definition.compliance, MIN_SCORE, MAX_SCORE)
	scores.autonomy = math.clamp(scores.autonomy + definition.autonomy, MIN_SCORE, MAX_SCORE)

	state.actionCounts[actionId] = count + 1
	state.totalActions += 1
	state.engagement += definition.engagement
	state.lastAction = actionId
	state.revision += 1

	return makeSnapshot(state), nil
end

function RelationshipService.teardownPlayer(self: Service, player: Player): boolean
	if self._states[player] == nil then
		return false
	end

	self._states[player] = nil
	return true
end

function RelationshipService.destroy(self: Service)
	table.clear(self._states)
end

return RelationshipService
