--!strict

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local DEFAULT_DISCLOSURE =
	"Morrow uses AI-generated replies. It is not human, may make mistakes, and remembers only this play session. Please don't share personal information."
local DEFAULT_STATUS = "Choose a reply or type your own."
local THINKING_STATUS = "Morrow is thinking…"
local DEFAULT_INPUT_LIMIT = 240

local COLORS = {
	panel = Color3.fromRGB(8, 15, 19),
	panelStroke = Color3.fromRGB(70, 102, 104),
	field = Color3.fromRGB(17, 28, 32),
	fieldStroke = Color3.fromRGB(71, 100, 103),
	accent = Color3.fromRGB(116, 224, 205),
	accentDark = Color3.fromRGB(25, 71, 67),
	text = Color3.fromRGB(239, 247, 246),
	muted = Color3.fromRGB(165, 188, 188),
	error = Color3.fromRGB(255, 157, 164),
	disabled = Color3.fromRGB(72, 84, 86),
	button = Color3.fromRGB(31, 52, 56),
}

export type SubmitKind = "typed" | "suggested"
export type ResponseSource = "NATIVE AI" | "SIMULATED AI" | "FALLBACK"
export type Delivery = "warm" | "curious" | "uneasy" | "hurt" | "flat"
export type StatusTone = "neutral" | "success" | "error"

export type Options = {
	InternalBuild: boolean?,
	MaxInputCharacters: number?,
	DisclosureText: string?,
	OnSubmit: ((message: string, kind: SubmitKind, suggestionIndex: number?) -> ())?,
	OnClose: (() -> ())?,
}

type PrivatePanel = {
	Root: Frame,
	Submitted: RBXScriptSignal,
	Closed: RBXScriptSignal,
	_lineLabel: TextLabel,
	_disclosureLabel: TextLabel,
	_sourceBadge: TextLabel,
	_statusLabel: TextLabel,
	_input: TextBox,
	_sendButton: TextButton,
	_closeButton: TextButton,
	_suggestionButtons: { TextButton },
	_counterLabel: TextLabel,
	_submitEvent: BindableEvent,
	_closeEvent: BindableEvent,
	_connections: { RBXScriptConnection },
	_suggestions: { string },
	_maxInputCharacters: number,
	_inputEnabled: boolean,
	_isThinking: boolean,
	_isUpdatingInput: boolean,
	_statusText: string,
	_statusTone: StatusTone,
	_onSubmit: ((message: string, kind: SubmitKind, suggestionIndex: number?) -> ())?,
	_onClose: (() -> ())?,
}

local ConversationPanel = {}
ConversationPanel.__index = ConversationPanel

export type ConversationPanel = typeof(setmetatable({} :: PrivatePanel, ConversationPanel))

local function addCorner(parent: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function addStroke(parent: GuiObject, color: Color3, transparency: number)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color
	stroke.Transparency = transparency
	stroke.Thickness = 1
	stroke.Parent = parent
end

local function configureTextLabel(label: TextLabel)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.RichText = false
	label.TextColor3 = COLORS.text
	label.TextSize = 16
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
end

local function configureButton(button: TextButton)
	button.AutoButtonColor = false
	button.BackgroundColor3 = COLORS.button
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamMedium
	button.RichText = false
	button.Selectable = true
	button.TextColor3 = COLORS.text
	button.TextSize = 15
	button.TextWrapped = true
	addCorner(button, 9)
	addStroke(button, COLORS.fieldStroke, 0.2)
end

local function trim(text: string): string
	return string.match(text, "^%s*(.-)%s*$") or ""
end

local function capUtf8(text: string, limit: number): (string, number)
	local length = utf8.len(text)
	if length == nil then
		local byteCapped = string.sub(text, 1, limit)
		return byteCapped, #byteCapped
	end
	if length <= limit then
		return text, length
	end

	local nextCharacter = utf8.offset(text, limit + 1)
	if nextCharacter == nil then
		return text, length
	end
	return string.sub(text, 1, nextCharacter - 1), limit
end

local function toneColor(tone: StatusTone): Color3
	if tone == "error" then
		return COLORS.error
	elseif tone == "success" then
		return COLORS.accent
	end
	return COLORS.muted
end

local function deliveryColor(delivery: Delivery?): Color3
	if delivery == "hurt" then
		return Color3.fromRGB(189, 216, 225)
	elseif delivery == "uneasy" then
		return Color3.fromRGB(213, 222, 196)
	elseif delivery == "flat" then
		return Color3.fromRGB(202, 211, 211)
	end
	return COLORS.text
end

function ConversationPanel:_setControlsEnabled()
	local controlsEnabled = self._inputEnabled and not self._isThinking
	local hasMessage = trim(self._input.Text) ~= ""

	self._input.TextEditable = controlsEnabled
	self._input.PlaceholderColor3 = if controlsEnabled then COLORS.muted else COLORS.disabled
	self._sendButton.Active = controlsEnabled and hasMessage
	self._sendButton.Selectable = controlsEnabled and hasMessage
	self._sendButton.BackgroundColor3 = if controlsEnabled and hasMessage
		then COLORS.accentDark
		else COLORS.disabled
	self._sendButton.TextColor3 = if controlsEnabled and hasMessage
		then COLORS.text
		else Color3.fromRGB(183, 190, 190)

	for index, button in self._suggestionButtons do
		local enabled = controlsEnabled and self._suggestions[index] ~= nil
		button.Active = enabled
		button.Selectable = enabled
		button.BackgroundColor3 = if enabled then COLORS.button else COLORS.disabled
		button.TextTransparency = if enabled then 0 else 0.25
	end
end

function ConversationPanel:_updateInput()
	if self._isUpdatingInput then
		return
	end

	local normalized = string.gsub(self._input.Text, "[\r\n]", " ")
	local capped, length = capUtf8(normalized, self._maxInputCharacters)
	if capped ~= self._input.Text then
		self._isUpdatingInput = true
		self._input.Text = capped
		self._input.CursorPosition = #capped + 1
		self._isUpdatingInput = false
	end

	self._counterLabel.Text = `{length}/{self._maxInputCharacters}`
	self._counterLabel.TextColor3 = if length >= self._maxInputCharacters
		then COLORS.error
		else COLORS.muted
	self:_setControlsEnabled()
end

function ConversationPanel:_submit(message: string, kind: SubmitKind, suggestionIndex: number?)
	if self._isThinking or not self._inputEnabled then
		return
	end

	local cleaned = trim(message)
	if cleaned == "" then
		self:SetStatus("Type a message first.", "error")
		return
	end

	local capped = capUtf8(cleaned, self._maxInputCharacters)
	self:SetThinking(true)
	self._submitEvent:Fire(capped, kind, suggestionIndex)
	if self._onSubmit ~= nil then
		self._onSubmit(capped, kind, suggestionIndex)
	end
end

function ConversationPanel:_requestClose()
	if not self.Root.Visible then
		return
	end

	self:Hide()
	self._closeEvent:Fire()
	if self._onClose ~= nil then
		self._onClose()
	end
end

function ConversationPanel.new(parent: Instance, options: Options?): ConversationPanel
	local panelOptions: Options = options or {}
	local requestedLimit = math.floor(panelOptions.MaxInputCharacters or DEFAULT_INPUT_LIMIT)
	local maxInputCharacters = math.clamp(requestedLimit, 1, DEFAULT_INPUT_LIMIT)

	local root = Instance.new("Frame")
	root.Name = "ConversationPanel"
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.BackgroundColor3 = COLORS.panel
	root.BackgroundTransparency = 0.04
	root.BorderSizePixel = 0
	root.ClipsDescendants = true
	root.Position = UDim2.new(0.5, 0, 1, -18)
	root.Size = UDim2.new(1, -24, 0, 360)
	root.Visible = false
	root.ZIndex = 20
	root.Parent = parent
	addCorner(root, 15)
	addStroke(root, COLORS.panelStroke, 0.1)

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(280, 360)
	sizeConstraint.MaxSize = Vector2.new(760, 360)
	sizeConstraint.Parent = root

	local speaker = Instance.new("TextLabel")
	configureTextLabel(speaker)
	speaker.Name = "Speaker"
	speaker.Position = UDim2.fromOffset(18, 13)
	speaker.Size = UDim2.fromOffset(90, 30)
	speaker.Font = Enum.Font.GothamBold
	speaker.Text = "MORROW"
	speaker.TextColor3 = COLORS.accent
	speaker.TextSize = 18
	speaker.TextWrapped = false
	speaker.ZIndex = 21
	speaker.Parent = root

	local aiBadge = Instance.new("TextLabel")
	configureTextLabel(aiBadge)
	aiBadge.Name = "AICharacterBadge"
	aiBadge.BackgroundColor3 = Color3.fromRGB(20, 59, 57)
	aiBadge.BackgroundTransparency = 0
	aiBadge.Position = UDim2.fromOffset(108, 16)
	aiBadge.Size = UDim2.fromOffset(96, 24)
	aiBadge.Font = Enum.Font.GothamBold
	aiBadge.Text = "AI CHARACTER"
	aiBadge.TextColor3 = COLORS.accent
	aiBadge.TextSize = 11
	aiBadge.TextWrapped = false
	aiBadge.ZIndex = 21
	aiBadge.Parent = root
	addCorner(aiBadge, 7)
	addStroke(aiBadge, COLORS.accent, 0.5)

	local sourceBadge = Instance.new("TextLabel")
	configureTextLabel(sourceBadge)
	sourceBadge.Name = "ResponseSourceBadge"
	sourceBadge.BackgroundColor3 = Color3.fromRGB(34, 40, 43)
	sourceBadge.BackgroundTransparency = 0
	sourceBadge.Position = UDim2.fromOffset(212, 16)
	sourceBadge.Size = UDim2.fromOffset(100, 24)
	sourceBadge.Font = Enum.Font.GothamBold
	sourceBadge.Text = "SIMULATED AI"
	sourceBadge.TextColor3 = COLORS.muted
	sourceBadge.TextSize = 10
	sourceBadge.TextWrapped = false
	sourceBadge.Visible = panelOptions.InternalBuild == true
	sourceBadge.ZIndex = 21
	sourceBadge.Parent = root
	addCorner(sourceBadge, 7)

	local closeButton = Instance.new("TextButton")
	configureButton(closeButton)
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.BackgroundTransparency = 1
	closeButton.Position = UDim2.new(1, -8, 0, 6)
	closeButton.Size = UDim2.fromOffset(44, 44)
	closeButton.Text = "×"
	closeButton.TextColor3 = COLORS.muted
	closeButton.TextSize = 28
	closeButton.ZIndex = 22
	closeButton.Parent = root

	local lineLabel = Instance.new("TextLabel")
	configureTextLabel(lineLabel)
	lineLabel.Name = "MorrowLine"
	lineLabel.Position = UDim2.fromOffset(18, 52)
	lineLabel.Size = UDim2.new(1, -36, 0, 58)
	lineLabel.Text = "…"
	lineLabel.TextSize = 17
	lineLabel.TextYAlignment = Enum.TextYAlignment.Top
	lineLabel.ZIndex = 21
	lineLabel.Parent = root

	local disclosureLabel = Instance.new("TextLabel")
	configureTextLabel(disclosureLabel)
	disclosureLabel.Name = "AIDisclosure"
	disclosureLabel.Position = UDim2.fromOffset(18, 111)
	disclosureLabel.Size = UDim2.new(1, -36, 0, 43)
	disclosureLabel.Text = panelOptions.DisclosureText or DEFAULT_DISCLOSURE
	disclosureLabel.TextColor3 = COLORS.muted
	disclosureLabel.TextSize = 12
	disclosureLabel.TextYAlignment = Enum.TextYAlignment.Top
	disclosureLabel.ZIndex = 21
	disclosureLabel.Parent = root

	local statusLabel = Instance.new("TextLabel")
	configureTextLabel(statusLabel)
	statusLabel.Name = "Status"
	statusLabel.Position = UDim2.fromOffset(18, 157)
	statusLabel.Size = UDim2.new(1, -36, 0, 22)
	statusLabel.Text = DEFAULT_STATUS
	statusLabel.TextColor3 = COLORS.muted
	statusLabel.TextSize = 12
	statusLabel.TextWrapped = false
	statusLabel.ZIndex = 21
	statusLabel.Parent = root

	local suggestionsFrame = Instance.new("Frame")
	suggestionsFrame.Name = "Suggestions"
	suggestionsFrame.BackgroundTransparency = 1
	suggestionsFrame.Position = UDim2.fromOffset(18, 184)
	suggestionsFrame.Size = UDim2.new(1, -36, 0, 48)
	suggestionsFrame.ZIndex = 21
	suggestionsFrame.Parent = root

	local suggestionButtons = {}
	for index = 1, 2 do
		local button = Instance.new("TextButton")
		configureButton(button)
		button.Name = `Suggestion{index}`
		button.Position = UDim2.new((index - 1) * 0.5, if index == 1 then 0 else 4, 0, 0)
		button.Size = UDim2.new(0.5, -4, 1, 0)
		button.Text = ""
		button.Visible = false
		button.ZIndex = 22
		button.Parent = suggestionsFrame
		suggestionButtons[index] = button
	end

	local input = Instance.new("TextBox")
	input.Name = "PlayerMessage"
	input.BackgroundColor3 = COLORS.field
	input.BorderSizePixel = 0
	input.ClearTextOnFocus = false
	input.Font = Enum.Font.Gotham
	input.MultiLine = false
	input.PlaceholderColor3 = COLORS.muted
	input.PlaceholderText = "Say something to Morrow…"
	input.Position = UDim2.fromOffset(18, 240)
	input.RichText = false
	input.Selectable = true
	input.Size = UDim2.new(1, -134, 0, 54)
	input.Text = ""
	input.TextColor3 = COLORS.text
	input.TextSize = 16
	input.TextTruncate = Enum.TextTruncate.AtEnd
	input.TextXAlignment = Enum.TextXAlignment.Left
	input.ZIndex = 22
	input.Parent = root
	addCorner(input, 9)
	addStroke(input, COLORS.fieldStroke, 0.1)

	local inputPadding = Instance.new("UIPadding")
	inputPadding.PaddingLeft = UDim.new(0, 14)
	inputPadding.PaddingRight = UDim.new(0, 14)
	inputPadding.Parent = input

	local sendButton = Instance.new("TextButton")
	configureButton(sendButton)
	sendButton.Name = "Send"
	sendButton.AnchorPoint = Vector2.new(1, 0)
	sendButton.BackgroundColor3 = COLORS.disabled
	sendButton.Position = UDim2.new(1, -18, 0, 240)
	sendButton.Size = UDim2.fromOffset(92, 54)
	sendButton.Text = "SEND"
	sendButton.TextSize = 14
	sendButton.ZIndex = 22
	sendButton.Parent = root

	local counterLabel = Instance.new("TextLabel")
	configureTextLabel(counterLabel)
	counterLabel.Name = "CharacterCounter"
	counterLabel.AnchorPoint = Vector2.new(1, 0)
	counterLabel.Position = UDim2.new(1, -18, 0, 301)
	counterLabel.Size = UDim2.fromOffset(72, 20)
	counterLabel.Text = `0/{maxInputCharacters}`
	counterLabel.TextColor3 = COLORS.muted
	counterLabel.TextSize = 11
	counterLabel.TextWrapped = false
	counterLabel.TextXAlignment = Enum.TextXAlignment.Right
	counterLabel.ZIndex = 21
	counterLabel.Parent = root

	local controlHint = Instance.new("TextLabel")
	configureTextLabel(controlHint)
	controlHint.Name = "ControlHint"
	controlHint.Position = UDim2.fromOffset(18, 301)
	controlHint.Size = UDim2.new(1, -112, 0, 39)
	controlHint.Text = "Enter to send  •  Esc / controller B to close"
	controlHint.TextColor3 = COLORS.muted
	controlHint.TextSize = 11
	controlHint.TextWrapped = false
	controlHint.ZIndex = 21
	controlHint.Parent = root

	local submitEvent = Instance.new("BindableEvent")
	submitEvent.Name = "Submitted"
	local closeEvent = Instance.new("BindableEvent")
	closeEvent.Name = "Closed"

	local self = setmetatable(
		{
			Root = root,
			Submitted = submitEvent.Event,
			Closed = closeEvent.Event,
			_lineLabel = lineLabel,
			_disclosureLabel = disclosureLabel,
			_sourceBadge = sourceBadge,
			_statusLabel = statusLabel,
			_input = input,
			_sendButton = sendButton,
			_closeButton = closeButton,
			_suggestionButtons = suggestionButtons,
			_counterLabel = counterLabel,
			_submitEvent = submitEvent,
			_closeEvent = closeEvent,
			_connections = {},
			_suggestions = {},
			_maxInputCharacters = maxInputCharacters,
			_inputEnabled = true,
			_isThinking = false,
			_isUpdatingInput = false,
			_statusText = DEFAULT_STATUS,
			_statusTone = "neutral",
			_onSubmit = panelOptions.OnSubmit,
			_onClose = panelOptions.OnClose,
		} :: PrivatePanel,
		ConversationPanel
	)

	table.insert(
		self._connections,
		input:GetPropertyChangedSignal("Text"):Connect(function()
			self:_updateInput()
		end)
	)
	table.insert(
		self._connections,
		input.FocusLost:Connect(function(enterPressed)
			if enterPressed then
				self:_submit(input.Text, "typed", nil)
			end
		end)
	)
	table.insert(
		self._connections,
		sendButton.Activated:Connect(function()
			self:_submit(input.Text, "typed", nil)
		end)
	)
	table.insert(
		self._connections,
		closeButton.Activated:Connect(function()
			self:_requestClose()
		end)
	)

	for index, button in suggestionButtons do
		table.insert(
			self._connections,
			button.Activated:Connect(function()
				local suggestion = self._suggestions[index]
				if suggestion ~= nil then
					self:_submit(suggestion, "suggested", index)
				end
			end)
		)
	end

	table.insert(
		self._connections,
		UserInputService.InputBegan:Connect(function(userInput, gameProcessed)
			if gameProcessed or not self.Root.Visible then
				return
			end

			if userInput.KeyCode == Enum.KeyCode.Escape then
				self:_requestClose()
			elseif userInput.KeyCode == Enum.KeyCode.ButtonB then
				local selectedObject = GuiService.SelectedObject
				if selectedObject ~= nil and selectedObject:IsDescendantOf(self.Root) then
					self:_requestClose()
				end
			end
		end)
	)

	input.NextSelectionRight = sendButton
	sendButton.NextSelectionLeft = input
	closeButton.NextSelectionDown = input
	suggestionButtons[1].NextSelectionRight = suggestionButtons[2]
	suggestionButtons[2].NextSelectionLeft = suggestionButtons[1]
	suggestionButtons[1].NextSelectionDown = input
	suggestionButtons[2].NextSelectionDown = sendButton
	input.NextSelectionUp = suggestionButtons[1]
	sendButton.NextSelectionUp = suggestionButtons[2]

	self:_updateInput()
	return self
end

function ConversationPanel:Show()
	self.Root.Visible = true
	if UserInputService.GamepadEnabled then
		local firstSuggestion = self._suggestionButtons[1]
		GuiService.SelectedObject = if firstSuggestion.Visible and firstSuggestion.Selectable
			then firstSuggestion
			else self._input
	end
end

function ConversationPanel:Hide()
	self._input:ReleaseFocus()
	local selectedObject = GuiService.SelectedObject
	if selectedObject ~= nil and selectedObject:IsDescendantOf(self.Root) then
		GuiService.SelectedObject = nil
	end
	self.Root.Visible = false
end

function ConversationPanel:SetLine(line: string, delivery: Delivery?)
	local capped = capUtf8(line, 180)
	self._lineLabel.Text = capped
	self._lineLabel.TextColor3 = deliveryColor(delivery)
end

function ConversationPanel:SetResponseSource(source: ResponseSource)
	self._sourceBadge.Text = source
	if source == "NATIVE AI" then
		self._sourceBadge.TextColor3 = COLORS.accent
	elseif source == "FALLBACK" then
		self._sourceBadge.TextColor3 = Color3.fromRGB(226, 197, 145)
	else
		self._sourceBadge.TextColor3 = COLORS.muted
	end
end

function ConversationPanel:SetSuggestions(suggestions: { string })
	table.clear(self._suggestions)
	for index, button in self._suggestionButtons do
		local suggestion = suggestions[index]
		if suggestion ~= nil and trim(suggestion) ~= "" then
			local capped = capUtf8(trim(suggestion), 72)
			self._suggestions[index] = capped
			button.Text = capped
			button.Visible = true
		else
			button.Text = ""
			button.Visible = false
		end
	end
	self:_setControlsEnabled()
end

function ConversationPanel:SetThinking(isThinking: boolean, status: string?)
	self._isThinking = isThinking
	if isThinking then
		self._statusLabel.Text = status or THINKING_STATUS
		self._statusLabel.TextColor3 = COLORS.accent
	else
		self._statusLabel.Text = status or self._statusText
		self._statusLabel.TextColor3 = if status ~= nil
			then COLORS.muted
			else toneColor(self._statusTone)
	end
	self:_setControlsEnabled()
end

function ConversationPanel:SetStatus(status: string, tone: StatusTone?)
	self._statusText = status
	self._statusTone = tone or "neutral"
	if not self._isThinking then
		self._statusLabel.Text = status
		self._statusLabel.TextColor3 = toneColor(self._statusTone)
	end
end

function ConversationPanel:SetError(message: string)
	self:SetThinking(false)
	self:SetStatus(message, "error")
end

function ConversationPanel:SetInputEnabled(enabled: boolean)
	self._inputEnabled = enabled
	if not enabled then
		self._input:ReleaseFocus()
	end
	self:_setControlsEnabled()
end

function ConversationPanel:FocusInput()
	if self.Root.Visible and self._inputEnabled and not self._isThinking then
		self._input:CaptureFocus()
	end
end

function ConversationPanel:ClearInput()
	self._input.Text = ""
	self:_updateInput()
end

function ConversationPanel:Destroy()
	local selectedObject = GuiService.SelectedObject
	if selectedObject ~= nil and selectedObject:IsDescendantOf(self.Root) then
		GuiService.SelectedObject = nil
	end
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	self._submitEvent:Destroy()
	self._closeEvent:Destroy()
	self.Root:Destroy()
end

return ConversationPanel
