--!strict

local DialogueConfig = require(script.Parent.DialogueConfig)

export type Delivery = "warm" | "curious" | "uneasy" | "hurt" | "flat"
export type PlayerTone =
	"kind"
	| "curious"
	| "skeptical"
	| "hostile"
	| "leaving"
	| "unsafe"
	| "unknown"
export type ReplySource = "native" | "simulated" | "fallback" | "safety"

export type DialogueRequest = {
	protocolVersion: number,
	windowId: string,
	nonce: string,
	message: string,
	phaseRevision: number,
}

export type DialogueWindowGrant = {
	kind: "window",
	protocolVersion: number,
	windowId: string,
	nonce: string,
	phaseRevision: number,
	expiresIn: number,
	turnsRemaining: number,
	runTurnsRemaining: number,
	disclosure: string,
	aiBadge: string,
}

export type DialogueReply = {
	kind: "reply",
	protocolVersion: number,
	windowId: string,
	requestRevision: number,
	line: string,
	delivery: Delivery,
	source: ReplySource,
	nextNonce: string,
	turnsRemaining: number,
	runTurnsRemaining: number,
	fallbackOnly: boolean,
}

export type RejectCode =
	"service_destroyed"
	| "malformed_request"
	| "protocol_mismatch"
	| "invalid_message"
	| "invalid_window"
	| "not_authorized"
	| "ai_disabled"
	| "player_unavailable"
	| "too_far"
	| "no_active_window"
	| "window_mismatch"
	| "invalid_nonce"
	| "phase_mismatch"
	| "window_expired"
	| "window_budget"
	| "run_budget"
	| "in_flight"
	| "cooldown"

export type DialogueReject = {
	kind: "reject",
	protocolVersion: number,
	code: RejectCode,
	retryAfter: number?,
}

local deliveries: { [string]: boolean } = table.freeze({
	warm = true,
	curious = true,
	uneasy = true,
	hurt = true,
	flat = true,
})

local playerTones: { [string]: boolean } = table.freeze({
	kind = true,
	curious = true,
	skeptical = true,
	hostile = true,
	leaving = true,
	unsafe = true,
	unknown = true,
})

local replySources: { [string]: boolean } = table.freeze({
	native = true,
	simulated = true,
	fallback = true,
	safety = true,
})

local DialogueProtocol = {}

DialogueProtocol.Version = DialogueConfig.ProtocolVersion

function DialogueProtocol.isDelivery(value: any): boolean
	return typeof(value) == "string" and deliveries[value] == true
end

function DialogueProtocol.isPlayerTone(value: any): boolean
	return typeof(value) == "string" and playerTones[value] == true
end

function DialogueProtocol.isReplySource(value: any): boolean
	return typeof(value) == "string" and replySources[value] == true
end

function DialogueProtocol.isKnownWindow(value: any): boolean
	return typeof(value) == "string" and DialogueConfig.Windows[value] ~= nil
end

return table.freeze(DialogueProtocol)
