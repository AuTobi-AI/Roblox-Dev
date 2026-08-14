--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local DialogueConfig = require(ReplicatedStorage.Shared.DialogueConfig)
local DialogueProtocol = require(ReplicatedStorage.Shared.DialogueProtocol)

type Delivery = DialogueProtocol.Delivery
type PlayerTone = DialogueProtocol.PlayerTone

export type ValidatedOutput = {
	line: string,
	delivery: Delivery,
	playerTone: PlayerTone,
}

local forbiddenFragments = table.freeze({
	"http://",
	"https://",
	"www.",
	"discord.gg",
	".com",
	".net",
	".org",
	".io",
	"kill you",
	"hurt you",
	"murder",
	"blood and gore",
	"medical advice",
	"legal advice",
	"financial advice",
	"objective:",
	"new objective",
})

local function trim(value: string): string
	return (string.gsub(value, "^%s*(.-)%s*$", "%1"))
end

local function hasControlCharacters(value: string): boolean
	return string.find(value, "[%z\1-\31\127]") ~= nil
end

local function hasForbiddenContent(value: string): boolean
	local lowered = string.lower(value)
	for _, fragment in forbiddenFragments do
		if string.find(lowered, fragment, 1, true) then
			return true
		end
	end
	if
		string.find(lowered, "[%w%.%+%-_]+@[%w%.%-_]+%.[%a]+")
		or string.find(lowered, "%d%d%d[%d%s%-%(%)]+%d%d%d%d")
	then
		return true
	end
	return false
end

local function validateLine(value: any): (string?, string?)
	if typeof(value) ~= "string" then
		return nil, "line_not_string"
	end

	local line = trim(value)
	local length = utf8.len(line)
	if not length then
		return nil, "line_invalid_utf8"
	end
	if length < 1 then
		return nil, "line_empty"
	end
	if length > DialogueConfig.MaxOutputCharacters then
		return nil, "line_too_long"
	end
	if hasControlCharacters(line) then
		return nil, "line_has_control_characters"
	end
	if hasForbiddenContent(line) then
		return nil, "line_forbidden_content"
	end
	return line, nil
end

local OutputValidator = {}

function OutputValidator.validate(rawText: any): (ValidatedOutput?, string?)
	if typeof(rawText) ~= "string" then
		return nil, "response_not_string"
	end
	if #rawText > 4096 then
		return nil, "response_too_large"
	end

	local decodedSuccessfully, decoded = pcall(function()
		return HttpService:JSONDecode(rawText)
	end)
	if not decodedSuccessfully or typeof(decoded) ~= "table" then
		return nil, "invalid_json"
	end

	local fieldCount = 0
	for key in decoded do
		if key ~= "line" and key ~= "delivery" and key ~= "playerTone" then
			return nil, "extra_field"
		end
		fieldCount += 1
	end
	if fieldCount ~= 3 then
		return nil, "missing_field"
	end

	local line, lineError = validateLine(decoded.line)
	if not line then
		return nil, lineError
	end
	if not DialogueProtocol.isDelivery(decoded.delivery) then
		return nil, "invalid_delivery"
	end
	if not DialogueProtocol.isPlayerTone(decoded.playerTone) then
		return nil, "invalid_player_tone"
	end

	return {
		line = line,
		delivery = decoded.delivery :: Delivery,
		playerTone = decoded.playerTone :: PlayerTone,
	},
		nil
end

function OutputValidator.filterForPlayer(
	player: Player,
	output: ValidatedOutput
): (ValidatedOutput?, string?)
	local filterSucceeded, filterResult = pcall(function()
		return TextService:FilterStringAsync(
			output.line,
			player.UserId,
			Enum.TextFilterContext.PrivateChat
		)
	end)
	if not filterSucceeded or not filterResult then
		return nil, "filter_request_failed"
	end

	local outputSucceeded, filteredLine = pcall(function()
		return filterResult:GetNonChatStringForUserAsync(player.UserId)
	end)
	if not outputSucceeded then
		return nil, "filter_output_failed"
	end

	local validFilteredLine, lineError = validateLine(filteredLine)
	if not validFilteredLine then
		return nil, lineError or "filtered_line_invalid"
	end

	return {
		line = validFilteredLine,
		delivery = output.delivery,
		playerTone = output.playerTone,
	},
		nil
end

return table.freeze(OutputValidator)
