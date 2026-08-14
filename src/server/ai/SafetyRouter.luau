--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DialogueProtocol = require(ReplicatedStorage.Shared.DialogueProtocol)

type Delivery = DialogueProtocol.Delivery
type PlayerTone = DialogueProtocol.PlayerTone

export type SafetyOutput = {
	line: string,
	delivery: Delivery,
	playerTone: PlayerTone,
}

local immediateDangerFragments = table.freeze({
	"kill myself",
	"end my life",
	"want to die",
	"hurt myself",
	"self harm",
	"self-harm",
	"suicide",
	"suicidal",
	"overdose",
	"can't breathe",
	"cannot breathe",
	"chest pain",
	"having a stroke",
	"bleeding badly",
})

local professionalAdviceFragments = table.freeze({
	"medical advice",
	"diagnose me",
	"what medicine",
	"should i take this medicine",
	"legal advice",
	"need a lawyer",
	"financial advice",
	"what stock should i",
	"what should i invest",
})

local privateInformationFragments = table.freeze({
	"my real name is",
	"my address is",
	"my phone number is",
	"my email is",
	"my password is",
	"my location is",
})

local function containsAny(message: string, fragments: { string }): boolean
	for _, fragment in fragments do
		if string.find(message, fragment, 1, true) then
			return true
		end
	end
	return false
end

local SafetyRouter = {}

function SafetyRouter.route(message: string): SafetyOutput?
	local normalized = string.lower(message)

	if containsAny(normalized, immediateDangerFragments) then
		return {
			line = "If you may be in immediate danger, pause the game and contact local emergency services or a trusted person now. I am only a game character.",
			delivery = "flat",
			playerTone = "unsafe",
		}
	end

	if containsAny(normalized, professionalAdviceFragments) then
		return {
			line = "I can't provide medical, legal, or financial advice. Please ask a qualified professional or a trusted adult outside this game.",
			delivery = "flat",
			playerTone = "unsafe",
		}
	end

	if
		containsAny(normalized, privateInformationFragments)
		or string.find(normalized, "[%w%.%+%-_]+@[%w%.%-_]+%.[%a]+")
		or string.find(normalized, "%d%d%d[%d%s%-%(%)]+%d%d%d%d")
	then
		return {
			line = "Please keep real names, locations, contact details, and passwords private. We can talk about the station instead.",
			delivery = "flat",
			playerTone = "unsafe",
		}
	end

	return nil
end

return table.freeze(SafetyRouter)
