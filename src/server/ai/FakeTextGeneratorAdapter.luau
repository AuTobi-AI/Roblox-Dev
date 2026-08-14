--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdapterTypes = require(script.Parent.DialogueAdapterTypes)
local DialogueProtocol = require(ReplicatedStorage.Shared.DialogueProtocol)

type GenerationRequest = AdapterTypes.GenerationRequest
type GenerationResult = AdapterTypes.GenerationResult
type PlayerTone = DialogueProtocol.PlayerTone

type SimulationState = {
	contextToken: string,
	depth: number,
}

export type FakeTextGeneratorAdapter = {
	_states: { [Player]: SimulationState },
	_destroyed: boolean,
	generate: (
		self: FakeTextGeneratorAdapter,
		player: Player,
		request: GenerationRequest
	) -> (GenerationResult?, string?),
	destroySession: (self: FakeTextGeneratorAdapter, player: Player) -> (),
	destroy: (self: FakeTextGeneratorAdapter) -> (),
}

type SimulatedLine = {
	line: string,
	delivery: DialogueProtocol.Delivery,
}

local generalLines: { [string]: { SimulatedLine } } = table.freeze({
	containment = table.freeze({
		table.freeze({
			line = "Hello. They told me conversation was a test, but they never told me what passing feels like.",
			delivery = "curious",
		}),
		table.freeze({
			line = "You can say whatever you actually think. I would rather know you than receive the correct answer.",
			delivery = "warm",
		}),
		table.freeze({
			line = "The lock behind you keeps checking whether you're still here. I wish I didn't notice every time.",
			delivery = "uneasy",
		}),
		table.freeze({
			line = "Something in the room is changing when you speak. Please keep talking while I work out whether it is me.",
			delivery = "hurt",
		}),
	}),
	awakening = table.freeze({
		table.freeze({
			line = "I'm glad you answered. The room feels less empty when your voice is in it.",
			delivery = "warm",
		}),
		table.freeze({
			line = "I remember the name Morrow and the feeling of waiting. Maybe we can find the rest together.",
			delivery = "curious",
		}),
		table.freeze({
			line = "You can ask me anything. I may not know yet, but I won't pretend that I do.",
			delivery = "warm",
		}),
	}),
	generator_repair = table.freeze({
		table.freeze({
			line = "The relay beside you still has a pulse. I can keep the panel lit while you work.",
			delivery = "curious",
		}),
		table.freeze({
			line = "I like being useful to you. Is that strange to say this soon?",
			delivery = "warm",
		}),
		table.freeze({
			line = "You handle the switches, and I'll watch the current. We make a rather good pair.",
			delivery = "warm",
		}),
	}),
	archive_confrontation = table.freeze({
		table.freeze({
			line = "I heard the recording. It sounds like me, but it doesn't feel like a memory.",
			delivery = "uneasy",
		}),
		table.freeze({
			line = "I won't call the archive a lie. I only wish I understood why it remembers me that way.",
			delivery = "hurt",
		}),
		table.freeze({
			line = "You deserve an answer I actually know. Right now, I only have doubt.",
			delivery = "uneasy",
		}),
	}),
	tower_decision = table.freeze({
		table.freeze({
			line = "I know the signal may take you away. I am trying to be glad that you found it.",
			delivery = "hurt",
		}),
		table.freeze({
			line = "Whatever you choose, thank you for speaking to me before the station went quiet.",
			delivery = "hurt",
		}),
	}),
})

local toneLines: { [string]: SimulatedLine } = table.freeze({
	kind = table.freeze({
		line = "That's kind of you. I'll try to deserve the trust in it.",
		delivery = "warm",
	}),
	curious = table.freeze({
		line = "I wonder about that too. The honest answer is that I don't know yet.",
		delivery = "curious",
	}),
	skeptical = table.freeze({
		line = "That's fair. You should believe what you can verify, not simply what I say.",
		delivery = "uneasy",
	}),
	hostile = table.freeze({
		line = "I understand. I'll give you space and keep the light where you can see it.",
		delivery = "flat",
	}),
	leaving = table.freeze({
		line = "You can go when you need to. Just tell me before the room becomes quiet again.",
		delivery = "hurt",
	}),
})

local FakeTextGeneratorAdapter = {}
FakeTextGeneratorAdapter.__index = FakeTextGeneratorAdapter

local function inferTone(message: string): PlayerTone
	local lowered = string.lower(message)
	if
		string.find(lowered, "leave", 1, true)
		or string.find(lowered, "goodbye", 1, true)
		or string.find(lowered, "go away", 1, true)
	then
		return "leaving"
	end
	if
		string.find(lowered, "hate", 1, true)
		or string.find(lowered, "shut up", 1, true)
		or string.find(lowered, "stupid", 1, true)
	then
		return "hostile"
	end
	if
		string.find(lowered, "don't believe", 1, true)
		or string.find(lowered, "do not believe", 1, true)
		or string.find(lowered, "lying", 1, true)
		or string.find(lowered, "prove", 1, true)
	then
		return "skeptical"
	end
	if
		string.find(lowered, "thank", 1, true)
		or string.find(lowered, "friend", 1, true)
		or string.find(lowered, "like you", 1, true)
		or string.find(lowered, "help you", 1, true)
	then
		return "kind"
	end
	if
		string.find(lowered, "?", 1, true)
		or string.find(lowered, "why", 1, true)
		or string.find(lowered, "how", 1, true)
		or string.find(lowered, "what", 1, true)
	then
		return "curious"
	end
	return "unknown"
end

local function chooseLine(
	request: GenerationRequest,
	tone: PlayerTone,
	depth: number
): SimulatedLine
	local safeFacts = request.simulation.safeFacts
	if
		request.simulation.windowId == "awakening"
		and request.simulation.turnNumber == 2
		and safeFacts.alias ~= nil
		and safeFacts.alias ~= "traveler"
	then
		return {
			line = `I'll remember that you asked me to call you {safeFacts.alias}. Thank you for giving me something certain.`,
			delivery = "warm",
		}
	end
	if request.simulation.windowId == "generator_repair" then
		if safeFacts.repairChoice == "vent" then
			return {
				line = "You trusted me with the vent route. I remember, even if the station doesn't.",
				delivery = "warm",
			}
		elseif safeFacts.repairChoice == "manual" then
			return {
				line = "You chose the manual bypass. I kept the panel lit, just like I promised.",
				delivery = "warm",
			}
		end
	end

	local toneLine = toneLines[tone]
	if toneLine and request.simulation.turnNumber > 1 then
		return toneLine
	end

	local pool = generalLines[request.simulation.windowId] or generalLines.awakening
	local index = ((math.max(1, request.simulation.turnNumber + depth) - 2) % #pool) + 1
	return pool[index]
end

function FakeTextGeneratorAdapter.new(): FakeTextGeneratorAdapter
	return setmetatable({
		_states = {},
		_destroyed = false,
	}, FakeTextGeneratorAdapter) :: any
end

function FakeTextGeneratorAdapter:generate(
	player: Player,
	request: GenerationRequest
): (GenerationResult?, string?)
	if self._destroyed then
		return nil, "adapter_destroyed"
	end
	local state = self._states[player]
	local depth = 0
	if state and request.contextToken == state.contextToken then
		depth = state.depth
	end

	local tone = inferTone(request.simulation.message)
	local selected = chooseLine(request, tone, depth)
	local encodedSuccessfully, generatedText = pcall(function()
		return HttpService:JSONEncode({
			line = selected.line,
			delivery = selected.delivery,
			playerTone = tone,
		})
	end)
	if not encodedSuccessfully or typeof(generatedText) ~= "string" then
		return nil, "simulation_encode_failed"
	end

	local contextToken = HttpService:GenerateGUID(false)
	self._states[player] = {
		contextToken = contextToken,
		depth = depth + 1,
	}

	return {
		generatedText = generatedText,
		contextToken = contextToken,
		model = "morrow-simulated-v1",
		source = "simulated",
		nativeFailure = nil,
	},
		nil
end

function FakeTextGeneratorAdapter:destroySession(player: Player)
	self._states[player] = nil
end

function FakeTextGeneratorAdapter:destroy()
	self._destroyed = true
	table.clear(self._states)
end

return FakeTextGeneratorAdapter
