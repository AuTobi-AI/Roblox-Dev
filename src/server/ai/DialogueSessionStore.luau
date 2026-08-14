--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DialogueConfig = require(ReplicatedStorage.Shared.DialogueConfig)

type Clock = () -> number

export type SafeFacts = { [string]: string }

export type DialogueSession = {
	contextToken: string?,
	activeWindow: string?,
	windowNonce: string?,
	turnsUsed: number,
	sessionTurnsUsed: number,
	expiresAt: number,
	inFlight: boolean,
	activeRequestToken: string?,
	requestRevision: number,
	phaseRevision: number,
	safeFacts: SafeFacts,
	failureCount: number,
	fallbackOnly: boolean,
}

export type RequestTicket = {
	player: Player,
	windowId: string,
	requestToken: string,
	requestRevision: number,
	phaseRevision: number,
	turnNumber: number,
	sessionTurnNumber: number,
	contextToken: string?,
	safeFacts: SafeFacts,
}

export type SessionSnapshot = {
	windowId: string,
	nonce: string,
	phaseRevision: number,
	turnsRemaining: number,
	runTurnsRemaining: number,
	fallbackOnly: boolean,
}

export type DialogueSessionStore = {
	_sessions: { [Player]: DialogueSession },
	_clock: Clock,
	_getOrCreate: (self: DialogueSessionStore, player: Player) -> DialogueSession,
	_snapshot: (self: DialogueSessionStore, session: DialogueSession) -> SessionSnapshot?,
	openWindow: (
		self: DialogueSessionStore,
		player: Player,
		windowId: string,
		phaseRevision: number,
		safeFacts: SafeFacts?
	) -> (SessionSnapshot?, string?),
	validateRequest: (
		self: DialogueSessionStore,
		player: Player,
		windowId: string,
		nonce: string,
		phaseRevision: number
	) -> (boolean, string?),
	beginRequest: (
		self: DialogueSessionStore,
		player: Player,
		windowId: string,
		nonce: string,
		phaseRevision: number
	) -> (RequestTicket?, string?),
	isCurrent: (self: DialogueSessionStore, ticket: RequestTicket) -> boolean,
	completeRequest: (
		self: DialogueSessionStore,
		ticket: RequestTicket,
		contextToken: string?
	) -> SessionSnapshot?,
	abandonRequest: (self: DialogueSessionStore, ticket: RequestTicket) -> (),
	recordFailure: (self: DialogueSessionStore, ticket: RequestTicket) -> (),
	recordSuccess: (self: DialogueSessionStore, ticket: RequestTicket) -> (),
	updateSafeFacts: (self: DialogueSessionStore, player: Player, safeFacts: SafeFacts) -> boolean,
	isFallbackOnly: (self: DialogueSessionStore, player: Player) -> boolean,
	closeWindow: (self: DialogueSessionStore, player: Player) -> (),
	resetRun: (self: DialogueSessionStore, player: Player) -> (),
	destroy: (self: DialogueSessionStore) -> (),
}

local DialogueSessionStore = {}
DialogueSessionStore.__index = DialogueSessionStore

local function cloneSafeFacts(safeFacts: SafeFacts): SafeFacts
	return table.clone(safeFacts)
end

local function newNonce(): string
	return HttpService:GenerateGUID(false)
end

local function windowTurnLimit(windowId: string): number?
	local window = DialogueConfig.Windows[windowId]
	if not window then
		return nil
	end
	return math.min(window.maxTurns, DialogueConfig.MaxTurnsPerWindow)
end

function DialogueSessionStore.new(clock: Clock?): DialogueSessionStore
	return setmetatable({
		_sessions = {},
		_clock = clock or os.clock,
	}, DialogueSessionStore) :: any
end

function DialogueSessionStore:_getOrCreate(player: Player): DialogueSession
	local session = self._sessions[player]
	if session then
		return session
	end

	session = {
		contextToken = nil,
		activeWindow = nil,
		windowNonce = nil,
		turnsUsed = 0,
		sessionTurnsUsed = 0,
		expiresAt = 0,
		inFlight = false,
		activeRequestToken = nil,
		requestRevision = 0,
		phaseRevision = 0,
		safeFacts = {},
		failureCount = 0,
		fallbackOnly = false,
	}
	self._sessions[player] = session
	return session
end

function DialogueSessionStore:_snapshot(session: DialogueSession): SessionSnapshot?
	local activeWindow = session.activeWindow
	local nonce = session.windowNonce
	if not activeWindow or not nonce then
		return nil
	end

	local turnLimit = windowTurnLimit(activeWindow)
	if not turnLimit then
		return nil
	end

	return {
		windowId = activeWindow,
		nonce = nonce,
		phaseRevision = session.phaseRevision,
		turnsRemaining = math.max(0, turnLimit - session.turnsUsed),
		runTurnsRemaining = math.max(0, DialogueConfig.MaxTurnsPerRun - session.sessionTurnsUsed),
		fallbackOnly = session.fallbackOnly,
	}
end

function DialogueSessionStore:openWindow(
	player: Player,
	windowId: string,
	phaseRevision: number,
	safeFacts: SafeFacts?
): (SessionSnapshot?, string?)
	if not windowTurnLimit(windowId) then
		return nil, "invalid_window"
	end

	local session = self:_getOrCreate(player)
	if session.sessionTurnsUsed >= DialogueConfig.MaxTurnsPerRun then
		return nil, "run_budget"
	end

	session.activeWindow = windowId
	session.windowNonce = newNonce()
	session.turnsUsed = 0
	session.expiresAt = self._clock() + DialogueConfig.WindowLifetimeSeconds
	session.inFlight = false
	session.activeRequestToken = nil
	session.requestRevision += 1
	session.phaseRevision = phaseRevision
	session.failureCount = 0
	session.fallbackOnly = false

	if safeFacts then
		session.safeFacts = cloneSafeFacts(safeFacts)
	end

	return self:_snapshot(session), nil
end

function DialogueSessionStore:validateRequest(
	player: Player,
	windowId: string,
	nonce: string,
	phaseRevision: number
): (boolean, string?)
	local session = self._sessions[player]
	if not session or not session.activeWindow then
		return false, "no_active_window"
	end
	if session.activeWindow ~= windowId then
		return false, "window_mismatch"
	end
	if session.windowNonce ~= nonce then
		return false, "invalid_nonce"
	end
	if session.phaseRevision ~= phaseRevision then
		return false, "phase_mismatch"
	end
	if self._clock() >= session.expiresAt then
		return false, "window_expired"
	end
	if session.inFlight then
		return false, "in_flight"
	end

	local turnLimit = windowTurnLimit(windowId)
	if not turnLimit or session.turnsUsed >= turnLimit then
		return false, "window_budget"
	end
	if session.sessionTurnsUsed >= DialogueConfig.MaxTurnsPerRun then
		return false, "run_budget"
	end
	return true, nil
end

function DialogueSessionStore:beginRequest(
	player: Player,
	windowId: string,
	nonce: string,
	phaseRevision: number
): (RequestTicket?, string?)
	local valid, reason = self:validateRequest(player, windowId, nonce, phaseRevision)
	if not valid then
		return nil, reason
	end

	local session = self._sessions[player] :: DialogueSession
	session.inFlight = true
	session.activeRequestToken = newNonce()
	session.turnsUsed += 1
	session.sessionTurnsUsed += 1
	session.requestRevision += 1
	session.windowNonce = newNonce()

	return {
		player = player,
		windowId = windowId,
		requestToken = session.activeRequestToken :: string,
		requestRevision = session.requestRevision,
		phaseRevision = phaseRevision,
		turnNumber = session.turnsUsed,
		sessionTurnNumber = session.sessionTurnsUsed,
		contextToken = session.contextToken,
		safeFacts = cloneSafeFacts(session.safeFacts),
	},
		nil
end

function DialogueSessionStore:isCurrent(ticket: RequestTicket): boolean
	local session = self._sessions[ticket.player]
	return session ~= nil
		and session.activeWindow == ticket.windowId
		and session.activeRequestToken == ticket.requestToken
		and session.requestRevision == ticket.requestRevision
		and session.phaseRevision == ticket.phaseRevision
		and session.inFlight
		and self._clock() < session.expiresAt
end

function DialogueSessionStore:completeRequest(
	ticket: RequestTicket,
	contextToken: string?
): SessionSnapshot?
	if not self:isCurrent(ticket) then
		return nil
	end

	local session = self._sessions[ticket.player] :: DialogueSession
	if contextToken and contextToken ~= "" then
		session.contextToken = contextToken
	end
	session.inFlight = false
	session.activeRequestToken = nil
	return self:_snapshot(session)
end

function DialogueSessionStore:abandonRequest(ticket: RequestTicket)
	local session = self._sessions[ticket.player]
	if session and session.activeRequestToken == ticket.requestToken then
		session.inFlight = false
		session.activeRequestToken = nil
	end
end

function DialogueSessionStore:recordFailure(ticket: RequestTicket)
	local session = self._sessions[ticket.player]
	if not session or session.activeRequestToken ~= ticket.requestToken then
		return
	end

	session.failureCount += 1
	if session.failureCount >= DialogueConfig.CircuitFailureThreshold then
		session.fallbackOnly = true
	end
end

function DialogueSessionStore:recordSuccess(ticket: RequestTicket)
	local session = self._sessions[ticket.player]
	if
		session
		and session.activeRequestToken == ticket.requestToken
		and not session.fallbackOnly
	then
		session.failureCount = 0
	end
end

function DialogueSessionStore:updateSafeFacts(player: Player, safeFacts: SafeFacts): boolean
	local session = self._sessions[player]
	if not session then
		return false
	end
	session.safeFacts = cloneSafeFacts(safeFacts)
	return true
end

function DialogueSessionStore:isFallbackOnly(player: Player): boolean
	local session = self._sessions[player]
	return session ~= nil and session.fallbackOnly
end

function DialogueSessionStore:closeWindow(player: Player)
	local session = self._sessions[player]
	if not session then
		return
	end

	session.activeWindow = nil
	session.windowNonce = nil
	session.turnsUsed = 0
	session.expiresAt = 0
	session.inFlight = false
	session.activeRequestToken = nil
	session.requestRevision += 1
	session.failureCount = 0
	session.fallbackOnly = false
end

function DialogueSessionStore:resetRun(player: Player)
	self._sessions[player] = nil
end

function DialogueSessionStore:destroy()
	table.clear(self._sessions)
end

return DialogueSessionStore
