--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ConversationPanel = require(script.Parent.ui.ConversationPanel)
local DialogueConfig = require(ReplicatedStorage.Shared.DialogueConfig)
local DialogueProtocol = require(ReplicatedStorage.Shared.DialogueProtocol)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("MorrowRemotes")
local storyRemote = remotes:WaitForChild("Story") :: RemoteEvent
local choiceRemote = remotes:WaitForChild("Choice") :: RemoteEvent
local dialogueSubmitRemote = remotes:WaitForChild("DialogueSubmit") :: RemoteEvent
local dialogueCloseRemote = remotes:WaitForChild("DialogueClose") :: RemoteEvent
local dialogueClientRemote = remotes:WaitForChild("DialogueClient") :: RemoteEvent

local gui = Instance.new("ScreenGui")
gui.Name = "MorrowInterface"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10
gui.Parent = player:WaitForChild("PlayerGui")

local huntTint = Instance.new("Frame")
huntTint.Name = "HuntTint"
huntTint.BackgroundColor3 = Color3.fromRGB(95, 0, 19)
huntTint.BackgroundTransparency = 1
huntTint.BorderSizePixel = 0
huntTint.Size = UDim2.fromScale(1, 1)
huntTint.ZIndex = 1
huntTint.Parent = gui

local objective = Instance.new("TextLabel")
objective.Name = "Objective"
objective.AnchorPoint = Vector2.new(0.5, 0)
objective.BackgroundColor3 = Color3.fromRGB(10, 14, 19)
objective.BackgroundTransparency = 0.2
objective.Position = UDim2.fromScale(0.5, 0.035)
objective.Size = UDim2.new(1, -32, 0, 46)
objective.Font = Enum.Font.GothamMedium
objective.Text = "..."
objective.TextColor3 = Color3.fromRGB(220, 237, 235)
objective.TextSize = 18
objective.TextWrapped = true
objective.ZIndex = 3
objective.Parent = gui

local objectiveSize = Instance.new("UISizeConstraint")
objectiveSize.MaxSize = Vector2.new(620, 46)
objectiveSize.MinSize = Vector2.new(280, 46)
objectiveSize.Parent = objective
local objectiveCorner = Instance.new("UICorner")
objectiveCorner.CornerRadius = UDim.new(0, 10)
objectiveCorner.Parent = objective

local authoredDialogue = Instance.new("Frame")
authoredDialogue.Name = "AuthoredDialogue"
authoredDialogue.AnchorPoint = Vector2.new(0.5, 1)
authoredDialogue.BackgroundColor3 = Color3.fromRGB(9, 12, 17)
authoredDialogue.BackgroundTransparency = 0.08
authoredDialogue.Position = UDim2.new(0.5, 0, 1, -24)
authoredDialogue.Size = UDim2.new(1, -24, 0, 185)
authoredDialogue.Visible = false
authoredDialogue.ZIndex = 4
authoredDialogue.Parent = gui

local authoredSize = Instance.new("UISizeConstraint")
authoredSize.MaxSize = Vector2.new(700, 185)
authoredSize.MinSize = Vector2.new(280, 185)
authoredSize.Parent = authoredDialogue
local dialogueCorner = Instance.new("UICorner")
dialogueCorner.CornerRadius = UDim.new(0, 14)
dialogueCorner.Parent = authoredDialogue

local speaker = Instance.new("TextLabel")
speaker.BackgroundTransparency = 1
speaker.Position = UDim2.fromOffset(22, 14)
speaker.Size = UDim2.new(1, -44, 0, 28)
speaker.Font = Enum.Font.GothamBold
speaker.Text = "MORROW"
speaker.TextColor3 = Color3.fromRGB(118, 217, 202)
speaker.TextSize = 20
speaker.TextXAlignment = Enum.TextXAlignment.Left
speaker.ZIndex = 5
speaker.Parent = authoredDialogue

local authoredText = Instance.new("TextLabel")
authoredText.BackgroundTransparency = 1
authoredText.Position = UDim2.fromOffset(22, 46)
authoredText.Size = UDim2.new(1, -44, 0, 62)
authoredText.Font = Enum.Font.Gotham
authoredText.TextColor3 = Color3.fromRGB(237, 241, 244)
authoredText.TextSize = 18
authoredText.TextWrapped = true
authoredText.TextXAlignment = Enum.TextXAlignment.Left
authoredText.TextYAlignment = Enum.TextYAlignment.Top
authoredText.ZIndex = 5
authoredText.Parent = authoredDialogue

local authoredButtons: { TextButton } = {}
local authoredDialogueRevision = 0
for index = 1, 2 do
	local button = Instance.new("TextButton")
	button.Name = `Choice{index}`
	button.BackgroundColor3 = Color3.fromRGB(31, 43, 49)
	button.Position = UDim2.new((index - 1) * 0.5, 22 + (index - 1) * 6, 1, -58)
	button.Size = UDim2.new(0.5, -31, 0, 38)
	button.Font = Enum.Font.GothamMedium
	button.TextColor3 = Color3.fromRGB(225, 242, 239)
	button.TextSize = 16
	button.Visible = false
	button.ZIndex = 5
	button.Parent = authoredDialogue
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	button.Activated:Connect(function()
		authoredDialogueRevision += 1
		authoredDialogue.Visible = false
		choiceRemote:FireServer(index)
	end)
	authoredButtons[index] = button
end

local activeGrant: any = nil
local conversation = ConversationPanel.new(gui, {
	InternalBuild = GameConfig.InternalBuild,
	MaxInputCharacters = DialogueConfig.MaxInputCharacters,
	DisclosureText = DialogueConfig.Disclosure,
	OnSubmit = function(message: string)
		local grant = activeGrant
		if typeof(grant) ~= "table" then
			return
		end
		dialogueSubmitRemote:FireServer({
			protocolVersion = DialogueProtocol.Version,
			windowId = grant.windowId,
			nonce = grant.nonce,
			message = message,
			phaseRevision = grant.phaseRevision,
		})
	end,
	OnClose = function()
		activeGrant = nil
		dialogueCloseRemote:FireServer()
	end,
})

local function showTitle(message: string)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = message
	label.TextColor3 = Color3.fromRGB(224, 245, 242)
	label.TextSize = 34
	label.TextTransparency = 1
	label.ZIndex = 30
	label.Parent = gui
	TweenService:Create(label, TweenInfo.new(1), { TextTransparency = 0 }):Play()
	task.delay(3, function()
		local tween = TweenService:Create(label, TweenInfo.new(1), { TextTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		label:Destroy()
	end)
end

local function sourceLabel(source: string): ConversationPanel.ResponseSource
	if source == "native" then
		return "NATIVE AI"
	elseif source == "fallback" or source == "safety" then
		return "FALLBACK"
	end
	return "SIMULATED AI"
end

local function nextSuggestions(turnsRemaining: number): { string }
	if turnsRemaining >= 2 then
		return { "What do you remember?", "Are you lonely?" }
	elseif turnsRemaining == 1 then
		return { "Do you want to come with me?", "Can I trust you?" }
	end
	return {}
end

dialogueClientRemote.OnClientEvent:Connect(function(packet: any)
	if typeof(packet) ~= "table" or typeof(packet.kind) ~= "string" then
		return
	end

	if packet.kind == "open" and typeof(packet.grant) == "table" then
		activeGrant = packet.grant
		conversation:SetLine(tostring(packet.line), "curious")
		conversation:SetSuggestions(
			if typeof(packet.suggestions) == "table" then packet.suggestions else {}
		)
		conversation:SetResponseSource(if game.GameId == 0 then "SIMULATED AI" else "NATIVE AI")
		conversation:SetInputEnabled(true)
		conversation:SetThinking(false, "Choose a reply or type your own.")
		conversation:Show()
		conversation:FocusInput()
	elseif packet.kind == "reply" and activeGrant then
		activeGrant.nonce = packet.nextNonce
		conversation:SetThinking(false)
		conversation:ClearInput()
		conversation:SetLine(
			tostring(packet.line),
			if DialogueProtocol.isDelivery(packet.delivery) then packet.delivery else nil
		)
		conversation:SetResponseSource(sourceLabel(tostring(packet.source)))
		local turnsRemaining = if typeof(packet.turnsRemaining) == "number"
			then packet.turnsRemaining
			else 0
		conversation:SetSuggestions(nextSuggestions(turnsRemaining))
		conversation:SetInputEnabled(turnsRemaining > 0)
		conversation:SetStatus(
			if turnsRemaining > 0
				then `{turnsRemaining} conversation replies remain.`
				else "Morrow is quiet.",
			"success"
		)
	elseif packet.kind == "reject" then
		conversation:SetThinking(false)
		local retryAfter = if typeof(packet.retryAfter) == "number"
			then math.ceil(packet.retryAfter)
			else nil
		conversation:SetError(
			if retryAfter
				then `Morrow needs {retryAfter} more seconds to gather its thoughts.`
				else "Morrow's signal scattered. Try again."
		)
		conversation:SetInputEnabled(true)
	elseif packet.kind == "abandoned" then
		activeGrant = nil
		conversation:SetThinking(false)
		conversation:SetInputEnabled(false)
		conversation:SetError("Morrow lost track of the conversation. Move closer and try again.")
	elseif packet.kind == "complete" then
		activeGrant = nil
		conversation:Hide()
	end
end)

storyRemote.OnClientEvent:Connect(function(kind: string, payload: any)
	if kind == "Title" and typeof(payload) == "string" then
		showTitle(payload)
	elseif kind == "Objective" and typeof(payload) == "string" then
		objective.Text = payload
	elseif kind == "Dialogue" and typeof(payload) == "table" then
		authoredDialogueRevision += 1
		local thisDialogueRevision = authoredDialogueRevision
		speaker.Text = tostring(payload.speaker)
		authoredText.Text = tostring(payload.text)
		for index, button in authoredButtons do
			local option = payload.choices[index]
			button.Visible = option ~= nil
			button.Text = if option then tostring(option) else ""
		end
		authoredDialogue.Visible = true
		if #payload.choices == 0 then
			task.delay(3.5, function()
				if authoredDialogueRevision == thisDialogueRevision then
					authoredDialogue.Visible = false
				end
			end)
		end
	elseif kind == "Phase" and payload == "Hunt" then
		huntTint.BackgroundTransparency = 0.82
		objective.TextColor3 = Color3.fromRGB(255, 196, 205)
	elseif kind == "Phase" and payload == "Escaped" then
		huntTint.BackgroundTransparency = 1
		objective.TextColor3 = Color3.fromRGB(190, 255, 226)
	elseif kind == "Timer" and typeof(payload) == "number" then
		objective.Text = `SURVIVE — {payload}`
	end
end)
