--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdapterTypes = require(script.Parent.DialogueAdapterTypes)
local DialogueConfig = require(ReplicatedStorage.Shared.DialogueConfig)
local DialogueProtocol = require(ReplicatedStorage.Shared.DialogueProtocol)
local DialogueRateLimiter = require(script.Parent.DialogueRateLimiter)
local DialogueSessionStore = require(script.Parent.DialogueSessionStore)
local FakeTextGeneratorAdapter = require(script.Parent.FakeTextGeneratorAdapter)
local FallbackDialogue = require(script.Parent.FallbackDialogue)
local OutputValidator = require(script.Parent.OutputValidator)
local PromptCompiler = require(script.Parent.PromptCompiler)
local SafetyRouter = require(script.Parent.SafetyRouter)
local TextGeneratorAdapter = require(script.Parent.TextGeneratorAdapter)

type Adapter = AdapterTypes.Adapter
type GenerationRequest = AdapterTypes.GenerationRequest
type RequestTicket = DialogueSessionStore.RequestTicket
type SessionSnapshot = DialogueSessionStore.SessionSnapshot
type SafeFacts = DialogueSessionStore.SafeFacts
type DialogueRequest = DialogueProtocol.DialogueRequest
type DialogueReject = DialogueProtocol.DialogueReject
type DialogueReply = DialogueProtocol.DialogueReply
type DialogueWindowGrant = DialogueProtocol.DialogueWindowGrant
type RejectCode = DialogueProtocol.RejectCode
type ReplySource = DialogueProtocol.ReplySource
type ValidatedOutput = OutputValidator.ValidatedOutput

export type RuntimeContext = {
	aiEnabled: boolean,
	phaseRevision: number,
	storyPhase: string,
	intent: string,
	interactionPart: BasePart?,
	interactionPosition: Vector3?,
	maxDistance: number?,
	relationshipBands: { [string]: string }?,
	recentEvents: { string }?,
	explicitUnknowns: { string }?,
}

export type ResolveContext = (player: Player, windowId: string) -> RuntimeContext?
export type ReplyCallback = (reply: DialogueReply) -> ()

export type Options = {
	resolveContext: ResolveContext,
	preferNative: boolean?,
	adapter: Adapter?,
	clock: (() -> number)?,
}

export type DialogueService = {
	_resolveContext: ResolveContext,
	_adapter: Adapter,
	_sessions: DialogueSessionStore.DialogueSessionStore,
	_rateLimiter: DialogueRateLimiter.DialogueRateLimiter,
	_destroyed: boolean,
	_playerRemovingConnection: RBXScriptConnection?,
	_resolveRuntime: (
		self: DialogueService,
		player: Player,
		windowId: string,
		expectedPhaseRevision: number
	) -> (RuntimeContext?, RejectCode?),
	_isTicketDeliverable: (self: DialogueService, ticket: RequestTicket) -> boolean,
	openWindow: (
		self: DialogueService,
		player: Player,
		windowId: string,
		phaseRevision: number,
		safeFacts: SafeFacts?
	) -> (DialogueWindowGrant?, DialogueReject?),
	submit: (
		self: DialogueService,
		player: Player,
		request: any,
		callback: ReplyCallback
	) -> (boolean, DialogueReject?),
	updateSafeFacts: (
		self: DialogueService,
		player: Player,
		safeFacts: SafeFacts
	) -> (boolean, DialogueReject?),
	closeWindow: (self: DialogueService, player: Player) -> (),
	resetRun: (self: DialogueService, player: Player) -> (),
	removePlayer: (self: DialogueService, player: Player) -> (),
	destroy: (self: DialogueService) -> (),
}

type StringMapLimits = {
	maximumEntries: number,
	maximumKeyCharacters: number,
	maximumValueCharacters: number,
	requireIdentifierKeys: boolean,
}

local expectedRequestFields = table.freeze({
	protocolVersion = true,
	windowId = true,
	nonce = true,
	message = true,
	phaseRevision = true,
})

local DialogueService = {}
DialogueService.__index = DialogueService

local function reject(code: RejectCode, retryAfter: number?): DialogueReject
	return {
		kind = "reject",
		protocolVersion = DialogueConfig.ProtocolVersion,
		code = code,
		retryAfter = retryAfter,
	}
end

local function trim(value: string): string
	return (string.gsub(value, "^%s*(.-)%s*$", "%1"))
end

local function isBoundedText(value: any, maximumCharacters: number, allowEmpty: boolean): boolean
	if typeof(value) ~= "string" or #value > maximumCharacters * 4 then
		return false
	end
	local length = utf8.len(value)
	return length ~= nil
		and length <= maximumCharacters
		and (allowEmpty or length > 0)
		and string.find(value, "[%z\1-\31\127]") == nil
end

local function isFiniteNumber(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function isFiniteVector3(value: Vector3): boolean
	return isFiniteNumber(value.X) and isFiniteNumber(value.Y) and isFiniteNumber(value.Z)
end

local function validateStringMap(
	value: any,
	limits: StringMapLimits
): ({ [string]: string }?, boolean)
	if value == nil then
		return {}, true
	end
	if typeof(value) ~= "table" then
		return nil, false
	end

	local result: { [string]: string } = {}
	local count = 0
	for key, entry in value do
		count += 1
		if
			count > limits.maximumEntries
			or not isBoundedText(key, limits.maximumKeyCharacters, false)
			or not isBoundedText(entry, limits.maximumValueCharacters, true)
		then
			return nil, false
		end
		if limits.requireIdentifierKeys and not string.match(key, "^[%a][%w_]*$") then
			return nil, false
		end
		result[key] = entry
	end
	return result, true
end

local function validateStringList(
	value: any,
	maximumEntries: number,
	maximumCharacters: number
): ({ string }?, boolean)
	if value == nil then
		return {}, true
	end
	if typeof(value) ~= "table" or #value > maximumEntries then
		return nil, false
	end

	local result: { string } = {}
	local count = 0
	for key, entry in value do
		count += 1
		if
			typeof(key) ~= "number"
			or key % 1 ~= 0
			or key < 1
			or key > #value
			or count > maximumEntries
			or not isBoundedText(entry, maximumCharacters, false)
		then
			return nil, false
		end
		result[key] = entry
	end
	if count ~= #value then
		return nil, false
	end
	return result, true
end

local function validateSafeFacts(value: any): (SafeFacts?, boolean)
	local validated, valid = validateStringMap(value, {
		maximumEntries = DialogueConfig.MaxSafeFacts,
		maximumKeyCharacters = DialogueConfig.MaxSafeFactKeyCharacters,
		maximumValueCharacters = DialogueConfig.MaxSafeFactValueCharacters,
		requireIdentifierKeys = true,
	})
	return validated, valid
end

local function validateRequest(value: any): (DialogueRequest?, RejectCode?)
	if typeof(value) ~= "table" then
		return nil, "malformed_request"
	end

	local fieldCount = 0
	for key in value do
		if typeof(key) ~= "string" or not expectedRequestFields[key] then
			return nil, "malformed_request"
		end
		fieldCount += 1
	end
	if fieldCount ~= 5 then
		return nil, "malformed_request"
	end

	if value.protocolVersion ~= DialogueConfig.ProtocolVersion then
		return nil, "protocol_mismatch"
	end
	if
		not DialogueProtocol.isKnownWindow(value.windowId)
		or not isBoundedText(value.windowId, 40, false)
		or not isBoundedText(value.nonce, DialogueConfig.MaxNonceCharacters, false)
	then
		return nil, "malformed_request"
	end
	if
		typeof(value.phaseRevision) ~= "number"
		or value.phaseRevision % 1 ~= 0
		or value.phaseRevision < 0
	then
		return nil, "malformed_request"
	end
	if not isBoundedText(value.message, DialogueConfig.MaxInputCharacters, false) then
		return nil, "invalid_message"
	end

	local message = trim(value.message)
	if not isBoundedText(message, DialogueConfig.MaxInputCharacters, false) then
		return nil, "invalid_message"
	end

	return {
		protocolVersion = value.protocolVersion,
		windowId = value.windowId,
		nonce = value.nonce,
		message = message,
		phaseRevision = value.phaseRevision,
	},
		nil
end

local function getPlayerRoot(player: Player): BasePart?
	if player.Parent ~= Players then
		return nil
	end
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil
	end
	return root
end

local function makeAdapter(options: Options): Adapter
	if options.adapter then
		return options.adapter
	end
	if options.preferNative == true then
		return TextGeneratorAdapter.new() :: any
	end
	return FakeTextGeneratorAdapter.new() :: any
end

function DialogueService.new(options: Options): DialogueService
	assert(typeof(options) == "table", "DialogueService options are required")
	assert(typeof(options.resolveContext) == "function", "resolveContext callback is required")

	local service = setmetatable({
		_resolveContext = options.resolveContext,
		_adapter = makeAdapter(options),
		_sessions = DialogueSessionStore.new(options.clock),
		_rateLimiter = DialogueRateLimiter.new(options.clock),
		_destroyed = false,
		_playerRemovingConnection = nil,
	}, DialogueService) :: any

	service._playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		service:removePlayer(player)
	end)
	return service
end

function DialogueService:_resolveRuntime(
	player: Player,
	windowId: string,
	expectedPhaseRevision: number
): (RuntimeContext?, RejectCode?)
	local resolvedSuccessfully, rawContext = pcall(self._resolveContext, player, windowId)
	if not resolvedSuccessfully or typeof(rawContext) ~= "table" then
		return nil, "not_authorized"
	end

	local context = rawContext :: RuntimeContext
	if context.aiEnabled ~= true then
		return nil, "ai_disabled"
	end
	if
		typeof(context.phaseRevision) ~= "number"
		or context.phaseRevision % 1 ~= 0
		or context.phaseRevision ~= expectedPhaseRevision
	then
		return nil, "phase_mismatch"
	end
	if
		not isBoundedText(context.storyPhase, 64, false)
		or not isBoundedText(context.intent, 64, false)
	then
		return nil, "not_authorized"
	end

	local relationshipBands, relationshipsValid = validateStringMap(context.relationshipBands, {
		maximumEntries = DialogueConfig.MaxRelationshipBands,
		maximumKeyCharacters = DialogueConfig.MaxSafeFactKeyCharacters,
		maximumValueCharacters = DialogueConfig.MaxRelationshipBandCharacters,
		requireIdentifierKeys = true,
	})
	local recentEvents, eventsValid = validateStringList(
		context.recentEvents,
		DialogueConfig.MaxRecentEvents,
		DialogueConfig.MaxRecentEventCharacters
	)
	local explicitUnknowns, unknownsValid = validateStringList(
		context.explicitUnknowns,
		DialogueConfig.MaxExplicitUnknowns,
		DialogueConfig.MaxExplicitUnknownCharacters
	)
	if not relationshipsValid or not eventsValid or not unknownsValid then
		return nil, "not_authorized"
	end

	local root = getPlayerRoot(player)
	if not root then
		return nil, "player_unavailable"
	end

	local interactionPosition = context.interactionPosition
	local interactionPart = context.interactionPart
	if interactionPart then
		if
			typeof(interactionPart) ~= "Instance"
			or not interactionPart:IsA("BasePart")
			or not interactionPart.Parent
		then
			return nil, "not_authorized"
		end
		interactionPosition = (interactionPart :: BasePart).Position
	end
	if typeof(interactionPosition) ~= "Vector3" or not isFiniteVector3(interactionPosition) then
		return nil, "not_authorized"
	end

	local maxDistance = context.maxDistance or DialogueConfig.InteractionRange
	if typeof(maxDistance) ~= "number" or not isFiniteNumber(maxDistance) or maxDistance <= 0 then
		return nil, "not_authorized"
	end
	maxDistance = math.min(maxDistance, DialogueConfig.MaxInteractionRange)
	if (root.Position - interactionPosition).Magnitude > maxDistance then
		return nil, "too_far"
	end

	return {
		aiEnabled = true,
		phaseRevision = context.phaseRevision,
		storyPhase = context.storyPhase,
		intent = context.intent,
		interactionPart = interactionPart,
		interactionPosition = interactionPosition,
		maxDistance = maxDistance,
		relationshipBands = relationshipBands,
		recentEvents = recentEvents,
		explicitUnknowns = explicitUnknowns,
	},
		nil
end

function DialogueService:_isTicketDeliverable(ticket: RequestTicket): boolean
	if self._destroyed or not self._sessions:isCurrent(ticket) then
		return false
	end
	local runtimeContext =
		self:_resolveRuntime(ticket.player, ticket.windowId, ticket.phaseRevision)
	return runtimeContext ~= nil
end

function DialogueService:openWindow(
	player: Player,
	windowId: string,
	phaseRevision: number,
	safeFacts: SafeFacts?
): (DialogueWindowGrant?, DialogueReject?)
	if self._destroyed then
		return nil, reject("service_destroyed")
	end
	if
		not DialogueProtocol.isKnownWindow(windowId)
		or typeof(phaseRevision) ~= "number"
		or phaseRevision % 1 ~= 0
		or phaseRevision < 0
	then
		return nil, reject("invalid_window")
	end

	local validatedFacts, factsValid = validateSafeFacts(safeFacts)
	if not factsValid or not validatedFacts then
		return nil, reject("not_authorized")
	end
	local runtimeContext, runtimeError = self:_resolveRuntime(player, windowId, phaseRevision)
	if not runtimeContext then
		return nil, reject(runtimeError or "not_authorized")
	end

	local snapshot, sessionError =
		self._sessions:openWindow(player, windowId, phaseRevision, validatedFacts)
	if not snapshot then
		return nil, reject((sessionError or "not_authorized") :: RejectCode)
	end

	return {
		kind = "window",
		protocolVersion = DialogueConfig.ProtocolVersion,
		windowId = snapshot.windowId,
		nonce = snapshot.nonce,
		phaseRevision = snapshot.phaseRevision,
		expiresIn = DialogueConfig.WindowLifetimeSeconds,
		turnsRemaining = snapshot.turnsRemaining,
		runTurnsRemaining = snapshot.runTurnsRemaining,
		disclosure = DialogueConfig.Disclosure,
		aiBadge = DialogueConfig.AIBadge,
	},
		nil
end

function DialogueService:updateSafeFacts(
	player: Player,
	safeFacts: SafeFacts
): (boolean, DialogueReject?)
	if self._destroyed then
		return false, reject("service_destroyed")
	end
	local validatedFacts, factsValid = validateSafeFacts(safeFacts)
	if not factsValid or not validatedFacts then
		return false, reject("not_authorized")
	end
	if not self._sessions:updateSafeFacts(player, validatedFacts) then
		return false, reject("no_active_window")
	end
	return true, nil
end

function DialogueService:submit(
	player: Player,
	rawRequest: any,
	callback: ReplyCallback
): (boolean, DialogueReject?)
	if self._destroyed then
		return false, reject("service_destroyed")
	end
	if typeof(callback) ~= "function" then
		return false, reject("malformed_request")
	end

	local request, requestError = validateRequest(rawRequest)
	if not request then
		return false, reject(requestError or "malformed_request")
	end

	local runtimeContext, runtimeError =
		self:_resolveRuntime(player, request.windowId, request.phaseRevision)
	if not runtimeContext then
		return false, reject(runtimeError or "not_authorized")
	end

	local sessionValid, sessionError = self._sessions:validateRequest(
		player,
		request.windowId,
		request.nonce,
		request.phaseRevision
	)
	if not sessionValid then
		return false, reject((sessionError or "not_authorized") :: RejectCode)
	end

	local rateAllowed, rateError, retryAfter, ratePermit = self._rateLimiter:tryBegin(player)
	if not rateAllowed then
		return false, reject((rateError or "cooldown") :: RejectCode, retryAfter)
	end
	local permit = ratePermit :: number

	local ticket, beginError =
		self._sessions:beginRequest(player, request.windowId, request.nonce, request.phaseRevision)
	if not ticket then
		self._rateLimiter:finish(player, permit)
		return false, reject((beginError or "not_authorized") :: RejectCode)
	end

	local settled = false

	local function emit(
		output: ValidatedOutput,
		source: ReplySource,
		contextToken: string?,
		modelFailed: boolean
	)
		if settled then
			return
		end
		settled = true

		local ticketWasCurrent = self._sessions:isCurrent(ticket)
		if not self:_isTicketDeliverable(ticket) then
			self._sessions:abandonRequest(ticket)
			self._rateLimiter:finish(player, permit)
			if ticketWasCurrent then
				self._sessions:closeWindow(player)
			end
			return
		end

		if modelFailed then
			self._sessions:recordFailure(ticket)
		elseif source ~= "safety" and source ~= "fallback" then
			self._sessions:recordSuccess(ticket)
		end

		local snapshot = self._sessions:completeRequest(ticket, contextToken)
		self._rateLimiter:finish(player, permit)
		if not snapshot then
			return
		end

		local reply: DialogueReply = {
			kind = "reply",
			protocolVersion = DialogueConfig.ProtocolVersion,
			windowId = snapshot.windowId,
			requestRevision = ticket.requestRevision,
			line = output.line,
			delivery = output.delivery,
			source = source,
			nextNonce = snapshot.nonce,
			turnsRemaining = snapshot.turnsRemaining,
			runTurnsRemaining = snapshot.runTurnsRemaining,
			fallbackOnly = snapshot.fallbackOnly,
		}
		task.spawn(function()
			pcall(callback, reply)
		end)
	end

	local function emitFallback()
		local fallback = FallbackDialogue.get(ticket.windowId, ticket.sessionTurnNumber)
		emit(fallback, "fallback", nil, true)
	end

	task.delay(DialogueConfig.SoftWatchdogSeconds, emitFallback)

	local safetyOutput = SafetyRouter.route(request.message)
	if safetyOutput then
		task.defer(function()
			emit(safetyOutput, "safety", nil, false)
		end)
		return true, nil
	end

	if self._sessions:isFallbackOnly(player) then
		task.defer(emitFallback)
		return true, nil
	end

	local compiledPrompt = PromptCompiler.compile({
		windowId = ticket.windowId,
		storyPhase = runtimeContext.storyPhase,
		intent = runtimeContext.intent,
		playerMessage = request.message,
		safeFacts = ticket.safeFacts,
		relationshipBands = runtimeContext.relationshipBands,
		recentEvents = runtimeContext.recentEvents,
		explicitUnknowns = runtimeContext.explicitUnknowns,
	})
	if not compiledPrompt then
		task.defer(emitFallback)
		return true, nil
	end

	local generationRequest: GenerationRequest = {
		systemPrompt = compiledPrompt.systemPrompt,
		userPrompt = compiledPrompt.userPrompt,
		jsonSchema = compiledPrompt.jsonSchema,
		contextToken = ticket.contextToken,
		maxTokens = DialogueConfig.MaxTokens,
		simulation = {
			windowId = ticket.windowId,
			message = request.message,
			turnNumber = ticket.turnNumber,
			safeFacts = ticket.safeFacts,
		},
	}

	task.spawn(function()
		local generationResult = self._adapter:generate(player, generationRequest)
		if settled then
			return
		end
		if
			not generationResult
			or (generationResult.source ~= "native" and generationResult.source ~= "simulated")
		then
			emitFallback()
			return
		end

		local output = OutputValidator.validate(generationResult.generatedText)
		if not output then
			emitFallback()
			return
		end

		if generationResult.source == "native" then
			local filteredOutput = OutputValidator.filterForPlayer(player, output)
			if settled then
				return
			end
			if not filteredOutput then
				emitFallback()
				return
			end
			output = filteredOutput
		end

		local contextToken = generationResult.contextToken
		if contextToken ~= nil and typeof(contextToken) ~= "string" then
			emitFallback()
			return
		end
		if contextToken and #contextToken > DialogueConfig.MaxContextTokenBytes then
			emitFallback()
			return
		end
		emit(output, generationResult.source, contextToken, generationResult.nativeFailure ~= nil)
	end)

	return true, nil
end

function DialogueService:closeWindow(player: Player)
	if self._destroyed then
		return
	end
	self._sessions:closeWindow(player)
end

function DialogueService:resetRun(player: Player)
	if self._destroyed then
		return
	end
	self._sessions:resetRun(player)
	self._rateLimiter:reset(player)
	self._adapter:destroySession(player)
end

function DialogueService:removePlayer(player: Player)
	self._sessions:resetRun(player)
	self._rateLimiter:reset(player)
	self._adapter:destroySession(player)
end

function DialogueService:destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	if self._playerRemovingConnection then
		self._playerRemovingConnection:Disconnect()
		self._playerRemovingConnection = nil
	end
	self._sessions:destroy()
	self._rateLimiter:destroy()
	self._adapter:destroy()
end

return DialogueService
