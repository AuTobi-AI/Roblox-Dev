--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DialogueConfig = require(ReplicatedStorage.Shared.DialogueConfig)

type Clock = () -> number

type Entry = {
	nextAllowedAt: number,
	inFlight: boolean,
	permit: number,
}

export type DialogueRateLimiter = {
	_entries: { [Player]: Entry },
	_clock: Clock,
	_cooldownSeconds: number,
	_nextPermit: number,
	tryBegin: (self: DialogueRateLimiter, player: Player) -> (boolean, string?, number?, number?),
	finish: (self: DialogueRateLimiter, player: Player, permit: number) -> (),
	reset: (self: DialogueRateLimiter, player: Player) -> (),
	destroy: (self: DialogueRateLimiter) -> (),
}

local DialogueRateLimiter = {}
DialogueRateLimiter.__index = DialogueRateLimiter

function DialogueRateLimiter.new(clock: Clock?): DialogueRateLimiter
	return setmetatable({
		_entries = {},
		_clock = clock or os.clock,
		_cooldownSeconds = DialogueConfig.CooldownSeconds,
		_nextPermit = 0,
	}, DialogueRateLimiter) :: any
end

function DialogueRateLimiter:tryBegin(player: Player): (boolean, string?, number?, number?)
	local now = self._clock()
	local entry = self._entries[player]
	if not entry then
		entry = {
			nextAllowedAt = 0,
			inFlight = false,
			permit = 0,
		}
		self._entries[player] = entry
	end

	if entry.inFlight then
		return false, "in_flight", nil, nil
	end

	if now < entry.nextAllowedAt then
		return false, "cooldown", entry.nextAllowedAt - now, nil
	end

	self._nextPermit += 1
	entry.inFlight = true
	entry.nextAllowedAt = now + self._cooldownSeconds
	entry.permit = self._nextPermit
	return true, nil, nil, entry.permit
end

function DialogueRateLimiter:finish(player: Player, permit: number)
	local entry = self._entries[player]
	if entry and entry.permit == permit then
		entry.inFlight = false
	end
end

function DialogueRateLimiter:reset(player: Player)
	self._entries[player] = nil
end

function DialogueRateLimiter:destroy()
	table.clear(self._entries)
end

return DialogueRateLimiter
