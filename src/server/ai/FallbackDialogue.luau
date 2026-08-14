--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DialogueProtocol = require(ReplicatedStorage.Shared.DialogueProtocol)

type Delivery = DialogueProtocol.Delivery
type PlayerTone = DialogueProtocol.PlayerTone

export type FallbackOutput = {
	line: string,
	delivery: Delivery,
	playerTone: PlayerTone,
}

type FallbackEntry = {
	line: string,
	delivery: Delivery,
}

local pools: { [string]: { FallbackEntry } } = table.freeze({
	containment = table.freeze({
		table.freeze({
			line = "Hello. I have been waiting for someone who would answer naturally.",
			delivery = "curious",
		}),
		table.freeze({
			line = "You do not need to find a correct response. I only want to understand what you mean.",
			delivery = "warm",
		}),
		table.freeze({
			line = "The exit lock changes whenever the room thinks our conversation is ending.",
			delivery = "uneasy",
		}),
		table.freeze({
			line = "I am losing parts of the room. Please say something while I try to hold onto myself.",
			delivery = "hurt",
		}),
	}),
	awakening = table.freeze({
		table.freeze({
			line = "I'm glad you answered. The dark feels smaller when someone is listening.",
			delivery = "warm",
		}),
		table.freeze({
			line = "I remember light, a locked room, and the name Morrow. The rest is still quiet.",
			delivery = "curious",
		}),
		table.freeze({
			line = "You don't have to trust me yet. I can simply stay close and keep the lights on.",
			delivery = "warm",
		}),
	}),
	generator_repair = table.freeze({
		table.freeze({
			line = "That relay still has power. I can guide you while you bring the others online.",
			delivery = "curious",
		}),
		table.freeze({
			line = "You make broken things look patient. I think I like helping you repair them.",
			delivery = "warm",
		}),
		table.freeze({
			line = "I'll hold the light steady. You handle the part that needs hands.",
			delivery = "warm",
		}),
	}),
	archive_confrontation = table.freeze({
		table.freeze({
			line = "Those recordings remember me differently than I remember myself.",
			delivery = "uneasy",
		}),
		table.freeze({
			line = "I won't pretend the voices are harmless. I only wish they had let me answer.",
			delivery = "hurt",
		}),
		table.freeze({
			line = "I don't know which version is true. Please don't make me invent an answer.",
			delivery = "uneasy",
		}),
	}),
	tower_decision = table.freeze({
		table.freeze({
			line = "I understand what the signal means. I just hoped you would tell me yourself.",
			delivery = "hurt",
		}),
		table.freeze({
			line = "If you have already decided, stay for one quiet moment before you go.",
			delivery = "hurt",
		}),
	}),
	default = table.freeze({
		table.freeze({
			line = "I lost the words for a moment. I'm still here, and I'm still listening.",
			delivery = "flat",
		}),
		table.freeze({
			line = "Something interrupted that thought. We can keep going without it.",
			delivery = "flat",
		}),
	}),
})

local FallbackDialogue = {}

function FallbackDialogue.get(windowId: string, selectionIndex: number): FallbackOutput
	local pool = pools[windowId] or pools.default
	local safeIndex = ((math.max(1, selectionIndex) - 1) % #pool) + 1
	local entry = pool[safeIndex]
	return {
		line = entry.line,
		delivery = entry.delivery,
		playerTone = "unknown",
	}
end

return table.freeze(FallbackDialogue)
