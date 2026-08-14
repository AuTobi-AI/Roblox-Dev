--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AdapterTypes = require(script.Parent.DialogueAdapterTypes)
local DialogueConfig = require(ReplicatedStorage.Shared.DialogueConfig)
local FakeTextGeneratorAdapter = require(script.Parent.FakeTextGeneratorAdapter)

type Adapter = AdapterTypes.Adapter
type GenerationRequest = AdapterTypes.GenerationRequest
type GenerationResult = AdapterTypes.GenerationResult

export type TextGeneratorAdapter = {
	_generators: { [Player]: TextGenerator },
	_busy: { [Player]: string },
	_epochs: { [number]: number },
	_parent: Instance,
	_fallback: Adapter,
	_destroyed: boolean,
	_getGenerator: (self: TextGeneratorAdapter, player: Player) -> (TextGenerator?, string?),
	_generateFallback: (
		self: TextGeneratorAdapter,
		player: Player,
		request: GenerationRequest,
		failureCode: string
	) -> (GenerationResult?, string?),
	generate: (
		self: TextGeneratorAdapter,
		player: Player,
		request: GenerationRequest
	) -> (GenerationResult?, string?),
	destroySession: (self: TextGeneratorAdapter, player: Player) -> (),
	destroy: (self: TextGeneratorAdapter) -> (),
}

export type Options = {
	parent: Instance?,
	fallbackAdapter: Adapter?,
}

local TextGeneratorAdapter = {}
TextGeneratorAdapter.__index = TextGeneratorAdapter

function TextGeneratorAdapter.new(options: Options?): TextGeneratorAdapter
	local resolvedOptions = options or {}
	return setmetatable({
		_generators = {},
		_busy = {},
		_epochs = {},
		_parent = resolvedOptions.parent or ServerStorage,
		_fallback = resolvedOptions.fallbackAdapter or FakeTextGeneratorAdapter.new(),
		_destroyed = false,
	}, TextGeneratorAdapter) :: any
end

function TextGeneratorAdapter:_getGenerator(player: Player): (TextGenerator?, string?)
	local existing = self._generators[player]
	if existing and existing.Parent then
		return existing, nil
	end

	local created, generatorOrError = pcall(function()
		local generator = Instance.new("TextGenerator")
		generator.Name = `MorrowTextGenerator_{player.UserId}`
		generator.Temperature = DialogueConfig.Temperature
		generator.TopP = DialogueConfig.TopP
		generator.Seed = DialogueConfig.Seed
		generator.Parent = self._parent
		return generator
	end)
	if not created then
		return nil, "native_unavailable"
	end

	local generator = generatorOrError :: TextGenerator
	self._generators[player] = generator
	return generator, nil
end

function TextGeneratorAdapter:_generateFallback(
	player: Player,
	request: GenerationRequest,
	failureCode: string
): (GenerationResult?, string?)
	local fallbackRequest: GenerationRequest = {
		systemPrompt = request.systemPrompt,
		userPrompt = request.userPrompt,
		jsonSchema = request.jsonSchema,
		contextToken = nil,
		maxTokens = request.maxTokens,
		simulation = request.simulation,
	}
	local fallbackResult, fallbackError = self._fallback:generate(player, fallbackRequest)
	if not fallbackResult then
		return nil, fallbackError or failureCode
	end

	-- A simulated token must never be sent back to the native model on a later request.
	fallbackResult.contextToken = nil
	fallbackResult.nativeFailure = failureCode
	return fallbackResult, nil
end

function TextGeneratorAdapter:generate(
	player: Player,
	request: GenerationRequest
): (GenerationResult?, string?)
	if self._destroyed then
		return nil, "adapter_destroyed"
	end
	local sessionEpoch = self._epochs[player.UserId] or 0
	if self._busy[player] then
		return self:_generateFallback(player, request, "native_busy")
	end

	local generator, generatorError = self:_getGenerator(player)
	if not generator then
		return self:_generateFallback(player, request, generatorError or "native_unavailable")
	end

	local requestToken = HttpService:GenerateGUID(false)
	self._busy[player] = requestToken
	local succeeded, response = pcall(function()
		generator.SystemPrompt = request.systemPrompt
		generator.Temperature = DialogueConfig.Temperature
		generator.TopP = DialogueConfig.TopP

		local nativeRequest: { [string]: any } = {
			UserPrompt = request.userPrompt,
			MaxTokens = request.maxTokens,
			JsonSchema = request.jsonSchema,
		}
		if request.contextToken then
			nativeRequest.ContextToken = request.contextToken
		end
		return generator:GenerateTextAsync(nativeRequest)
	end)
	if self._busy[player] == requestToken then
		self._busy[player] = nil
	end
	if self._destroyed or (self._epochs[player.UserId] or 0) ~= sessionEpoch then
		return nil, "session_ended"
	end

	if not succeeded or typeof(response) ~= "table" then
		return self:_generateFallback(player, request, "native_call_failed")
	end

	local generatedText = response.GeneratedText
	local contextToken = response.ContextToken
	local model = response.Model
	if typeof(generatedText) ~= "string" or generatedText == "" then
		return self:_generateFallback(player, request, "native_invalid_response")
	end
	if contextToken ~= nil and typeof(contextToken) ~= "string" then
		return self:_generateFallback(player, request, "native_invalid_response")
	end
	if typeof(model) ~= "string" then
		model = "roblox-text-generator"
	end

	return {
		generatedText = generatedText,
		contextToken = contextToken,
		model = model,
		source = "native",
		nativeFailure = nil,
	},
		nil
end

function TextGeneratorAdapter:destroySession(player: Player)
	local userId = player.UserId
	self._epochs[userId] = (self._epochs[userId] or 0) + 1
	self._busy[player] = nil
	local generator = self._generators[player]
	if generator then
		generator:Destroy()
		self._generators[player] = nil
	end
	self._fallback:destroySession(player)
end

function TextGeneratorAdapter:destroy()
	self._destroyed = true
	for player, generator in self._generators do
		generator:Destroy()
		self._generators[player] = nil
	end
	table.clear(self._busy)
	table.clear(self._epochs)
	self._fallback:destroy()
end

return TextGeneratorAdapter
