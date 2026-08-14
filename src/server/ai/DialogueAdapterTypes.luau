--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DialogueProtocol = require(ReplicatedStorage.Shared.DialogueProtocol)

export type SimulationContext = {
	windowId: string,
	message: string,
	turnNumber: number,
	safeFacts: { [string]: string },
}

export type GenerationRequest = {
	systemPrompt: string,
	userPrompt: string,
	jsonSchema: string,
	contextToken: string?,
	maxTokens: number,
	simulation: SimulationContext,
}

export type GenerationResult = {
	generatedText: string,
	contextToken: string?,
	model: string,
	source: DialogueProtocol.ReplySource,
	nativeFailure: string?,
}

export type Adapter = {
	generate: (
		self: Adapter,
		player: Player,
		request: GenerationRequest
	) -> (GenerationResult?, string?),
	destroySession: (self: Adapter, player: Player) -> (),
	destroy: (self: Adapter) -> (),
}

return table.freeze({})
