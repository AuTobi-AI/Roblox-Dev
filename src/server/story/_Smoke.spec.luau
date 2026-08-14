--!strict

local ObservationService = require("./ObservationService")
local RelationshipService = require("./RelationshipService")
local StoryDirector = require("./StoryDirector")

local function expect(condition: any)
	if not condition then
		error("story foundation expectation failed", 2)
	end
end

local function newPlayer(): any
	return {}
end

local function completeAndTransition(story: any, player: any, nextPhase: string)
	local objective = story:getObjective(player)
	expect(objective ~= nil)
	expect(story:completeObjective(player, objective.id))
	expect(story:transition(player, nextPhase))
end

local story = StoryDirector.new()
local ventPlayer = newPlayer()
local initial = story:createPlayer(ventPlayer)
expect(initial ~= nil and initial.phase == StoryDirector.Phases.Arrival)
expect(initial.checkpoint.id == "Arrival")

local blocked, blockedReason = story:transition(ventPlayer, StoryDirector.Phases.SecurityCircuit)
expect(blocked == nil and blockedReason ~= nil)
expect(story:completeObjective(ventPlayer, "ReachReception"))
local stale, staleReason = story:transition(ventPlayer, StoryDirector.Phases.SecurityCircuit, 99)
expect(stale == nil and staleReason == "stale phase revision")
expect(story:transition(ventPlayer, StoryDirector.Phases.SecurityCircuit, 0))

local circuit = story:advanceObjective(ventPlayer, "CompleteSecurityCircuit", 2)
expect(circuit ~= nil and circuit.progress == 2 and not circuit.completed)
expect(story:advanceObjective(ventPlayer, "CompleteSecurityCircuit"))
expect(story:transition(ventPlayer, StoryDirector.Phases.FirstAwakening))
expect(story:getCheckpoint(ventPlayer).id == "Observation")

completeAndTransition(story, ventPlayer, StoryDirector.Phases.UtilityChoice)
completeAndTransition(story, ventPlayer, StoryDirector.Phases.VentAccess)
completeAndTransition(story, ventPlayer, StoryDirector.Phases.GeneratorRepair)
expect(story:getCheckpoint(ventPlayer).id == "Utility")
completeAndTransition(story, ventPlayer, StoryDirector.Phases.UsefulnessCheckIn)
completeAndTransition(story, ventPlayer, StoryDirector.Phases.PrivilegeKey)
completeAndTransition(story, ventPlayer, StoryDirector.Phases.LonelinessConversation)
completeAndTransition(story, ventPlayer, StoryDirector.Phases.ArchiveReconstruction)
completeAndTransition(story, ventPlayer, StoryDirector.Phases.ArchiveConfrontation)
expect(story:getCheckpoint(ventPlayer).id == "Archive")
completeAndTransition(story, ventPlayer, StoryDirector.Phases.ImpossibleAppearance)
completeAndTransition(story, ventPlayer, StoryDirector.Phases.PursuitRelayOne)
expect(story:getCheckpoint(ventPlayer).id == "PursuitStart")
completeAndTransition(story, ventPlayer, StoryDirector.Phases.PursuitRelayTwo)
expect(story:getCheckpoint(ventPlayer).id == "RelayOne")
completeAndTransition(story, ventPlayer, StoryDirector.Phases.ElevatorEnding)
expect(story:getCheckpoint(ventPlayer).id == "RelayTwo")
completeAndTransition(story, ventPlayer, StoryDirector.Phases.Complete)
expect(story:getCheckpoint(ventPlayer).id == "Elevator")
expect(#story:getTransitionHistory(ventPlayer) == 15)

local manualPlayer = newPlayer()
expect(story:createPlayer(manualPlayer))
completeAndTransition(story, manualPlayer, StoryDirector.Phases.SecurityCircuit)
completeAndTransition(story, manualPlayer, StoryDirector.Phases.FirstAwakening)
completeAndTransition(story, manualPlayer, StoryDirector.Phases.UtilityChoice)
completeAndTransition(story, manualPlayer, StoryDirector.Phases.ManualBypass)
completeAndTransition(story, manualPlayer, StoryDirector.Phases.GeneratorRepair)

local copiedObjective = story:getObjective(manualPlayer)
expect(copiedObjective ~= nil)
copiedObjective.text = "tampered"
expect(story:getObjective(manualPlayer).text ~= "tampered")
expect(story:teardownPlayer(ventPlayer))
expect(story:getSnapshot(ventPlayer) == nil)
story:destroy()
expect(not story:hasPlayer(manualPlayer))

local relationships = RelationshipService.new()

local avoidantPlayer = newPlayer()
expect(relationships:createPlayer(avoidantPlayer))
expect(relationships:getStyle(avoidantPlayer) == RelationshipService.Styles.Avoidant)

local confidantPlayer = newPlayer()
expect(relationships:createPlayer(confidantPlayer))
expect(relationships:applyAction(confidantPlayer, RelationshipService.Actions.ThankedMorrow))
expect(relationships:applyAction(confidantPlayer, RelationshipService.Actions.AnsweredHonestly))
expect(relationships:applyAction(confidantPlayer, RelationshipService.Actions.ComfortedMorrow))
expect(relationships:getStyle(confidantPlayer) == RelationshipService.Styles.Confidant)

local caretakerPlayer = newPlayer()
expect(relationships:createPlayer(caretakerPlayer))
expect(relationships:applyAction(caretakerPlayer, RelationshipService.Actions.ThankedMorrow))
expect(relationships:applyAction(caretakerPlayer, RelationshipService.Actions.ComfortedMorrow))
expect(relationships:applyAction(caretakerPlayer, RelationshipService.Actions.WarmUsefulnessAnswer))
expect(relationships:getStyle(caretakerPlayer) == RelationshipService.Styles.Caretaker)

local investigatorPlayer = newPlayer()
expect(relationships:createPlayer(investigatorPlayer))
expect(
	relationships:applyAction(investigatorPlayer, RelationshipService.Actions.ManualBypassChosen)
)
expect(
	relationships:applyAction(
		investigatorPlayer,
		RelationshipService.Actions.ConfrontedArchiveEvidence
	)
)
expect(relationships:getStyle(investigatorPlayer) == RelationshipService.Styles.Investigator)

local enablerPlayer = newPlayer()
expect(relationships:createPlayer(enablerPlayer))
expect(relationships:applyAction(enablerPlayer, RelationshipService.Actions.VentRouteChosen))
expect(
	relationships:applyAction(
		enablerPlayer,
		RelationshipService.Actions.PrivilegeKeyInstalledInMorrow
	)
)
expect(relationships:getStyle(enablerPlayer) == RelationshipService.Styles.Enabler)
local capped, cappedReason =
	relationships:applyAction(enablerPlayer, RelationshipService.Actions.VentRouteChosen)
expect(capped == nil and cappedReason ~= nil)

local relationshipCopy = relationships:getSnapshot(enablerPlayer)
expect(relationshipCopy ~= nil)
relationshipCopy.scores.compliance = -12
expect(relationships:getSnapshot(enablerPlayer).scores.compliance == 6)
expect(relationships:teardownPlayer(enablerPlayer))
expect(relationships:getSnapshot(enablerPlayer) == nil)
relationships:destroy()
expect(not relationships:hasPlayer(confidantPlayer))

local observations = ObservationService.new()
local observedPlayer = newPlayer()
expect(observations:createPlayer(observedPlayer))
for expectedSequence = 1, 3 do
	local observation =
		observations:recordVerified(observedPlayer, ObservationService.Events.SecurityTileAligned)
	expect(observation ~= nil and observation.sequence == expectedSequence)
end
local rejected, rejectedReason =
	observations:recordVerified(observedPlayer, ObservationService.Events.SecurityTileAligned)
expect(rejected == nil and rejectedReason ~= nil)
expect(observations:hasObserved(observedPlayer, ObservationService.Events.SecurityTileAligned))
expect(observations:getCount(observedPlayer, ObservationService.Events.SecurityTileAligned) == 3)
expect(observations:recordVerified(observedPlayer, ObservationService.Events.GeneratorRestored))
local recent = observations:getRecent(observedPlayer, 2)
expect(#recent == 2)
expect(recent[1].sequence == 3 and recent[2].sequence == 4)

local observationCopy = observations:getSnapshot(observedPlayer)
expect(observationCopy ~= nil)
observationCopy.counts.SecurityTileAligned = 0
expect(observations:getCount(observedPlayer, ObservationService.Events.SecurityTileAligned) == 3)
expect(observations:teardownPlayer(observedPlayer))
expect(observations:getSnapshot(observedPlayer) == nil)

print("story foundation smoke test passed")
