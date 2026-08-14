--!strict

local windows = table.freeze({
	awakening = table.freeze({
		maxTurns = 3,
		posture = "curious and cautiously charming",
		fallbackIntent = "bond",
	}),
	generator_repair = table.freeze({
		maxTurns = 4,
		posture = "helpful and lightly playful",
		fallbackIntent = "help",
	}),
	archive_confrontation = table.freeze({
		maxTurns = 3,
		posture = "defensive, evasive, and restrained",
		fallbackIntent = "deflect",
	}),
	tower_decision = table.freeze({
		maxTurns = 2,
		posture = "hurt, quiet, and restrained",
		fallbackIntent = "separation",
	}),
})

return table.freeze({
	ProtocolVersion = 1,
	PromptVersion = "morrow-dialogue-v1",

	-- Downloaded places use deterministic simulated replies until a private universe is configured.
	DefaultPreferNative = false,
	ExposeSourceLabels = true,

	Disclosure = "Morrow uses AI-generated replies. It is not human, may make mistakes, and remembers only this play session. Please don't share personal information.",
	AIBadge = "AI CHARACTER",

	MaxInputCharacters = 240,
	MaxOutputCharacters = 180,
	MaxNonceCharacters = 64,
	MaxContextTokenBytes = 16384,
	CooldownSeconds = 6,
	WindowLifetimeSeconds = 90,
	SoftWatchdogSeconds = 8,
	MaxTurnsPerWindow = 4,
	MaxTurnsPerRun = 12,
	CircuitFailureThreshold = 3,

	InteractionRange = 18,
	MaxInteractionRange = 24,

	MaxSafeFacts = 8,
	MaxSafeFactKeyCharacters = 32,
	MaxSafeFactValueCharacters = 80,
	MaxRelationshipBands = 8,
	MaxRelationshipBandCharacters = 24,
	MaxRecentEvents = 6,
	MaxRecentEventCharacters = 100,
	MaxExplicitUnknowns = 6,
	MaxExplicitUnknownCharacters = 80,

	Temperature = 0.65,
	TopP = 0.85,
	MaxTokens = 96,
	Seed = 0,

	Windows = windows,
})
