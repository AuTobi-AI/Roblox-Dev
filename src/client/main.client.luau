--!strict

local Players, ReplicatedStorage, TweenService =
	game:GetService("Players"),
	game:GetService("ReplicatedStorage"),
	game:GetService("TweenService")
local remotes = ReplicatedStorage:WaitForChild("MorrowRemotes")
local story, choice =
	remotes:WaitForChild("Story") :: RemoteEvent, remotes:WaitForChild("Choice") :: RemoteEvent
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset, gui.Parent =
	"MorrowInterface", false, true, Players.LocalPlayer:WaitForChild("PlayerGui")

local tint = Instance.new("Frame")
tint.BackgroundColor3, tint.BackgroundTransparency, tint.BorderSizePixel, tint.Size, tint.ZIndex, tint.Parent =
	Color3.fromRGB(95, 0, 19), 1, 0, UDim2.fromScale(1, 1), 1, gui
local objective = Instance.new("TextLabel")
objective.AnchorPoint, objective.Position, objective.Size =
	Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.035), UDim2.fromOffset(540, 46)
objective.BackgroundColor3, objective.BackgroundTransparency = Color3.fromRGB(10, 14, 19), 0.2
objective.Font, objective.Text, objective.TextColor3, objective.TextSize =
	Enum.Font.GothamMedium, "...", Color3.fromRGB(220, 237, 235), 18
objective.ZIndex, objective.Parent = 3, gui
local objectiveCorner = Instance.new("UICorner")
objectiveCorner.CornerRadius, objectiveCorner.Parent = UDim.new(0, 10), objective

local dialogue = Instance.new("Frame")
dialogue.AnchorPoint, dialogue.Position, dialogue.Size =
	Vector2.new(0.5, 1), UDim2.fromScale(0.5, 0.94), UDim2.fromOffset(700, 185)
dialogue.BackgroundColor3, dialogue.BackgroundTransparency, dialogue.Visible, dialogue.ZIndex, dialogue.Parent =
	Color3.fromRGB(9, 12, 17), 0.08, false, 4, gui
local dialogueCorner = Instance.new("UICorner")
dialogueCorner.CornerRadius, dialogueCorner.Parent = UDim.new(0, 14), dialogue
local speaker = Instance.new("TextLabel")
speaker.BackgroundTransparency, speaker.Position, speaker.Size =
	1, UDim2.fromOffset(22, 14), UDim2.new(1, -44, 0, 28)
speaker.Font, speaker.Text, speaker.TextColor3, speaker.TextSize, speaker.TextXAlignment =
	Enum.Font.GothamBold, "MORROW", Color3.fromRGB(118, 217, 202), 20, Enum.TextXAlignment.Left
speaker.ZIndex, speaker.Parent = 5, dialogue
local text = Instance.new("TextLabel")
text.BackgroundTransparency, text.Position, text.Size =
	1, UDim2.fromOffset(22, 46), UDim2.new(1, -44, 0, 62)
text.Font, text.TextColor3, text.TextSize, text.TextWrapped =
	Enum.Font.Gotham, Color3.fromRGB(237, 241, 244), 18, true
text.TextXAlignment, text.TextYAlignment, text.ZIndex, text.Parent =
	Enum.TextXAlignment.Left, Enum.TextYAlignment.Top, 5, dialogue

local buttons = {}
for index = 1, 2 do
	local button = Instance.new("TextButton")
	button.BackgroundColor3, button.Position, button.Size =
		Color3.fromRGB(31, 43, 49),
		UDim2.new((index - 1) * 0.5, 22 + (index - 1) * 6, 1, -58),
		UDim2.new(0.5, -31, 0, 38)
	button.Font, button.TextColor3, button.TextSize, button.Visible, button.ZIndex, button.Parent =
		Enum.Font.GothamMedium, Color3.fromRGB(225, 242, 239), 16, false, 5, dialogue
	local corner = Instance.new("UICorner")
	corner.CornerRadius, corner.Parent = UDim.new(0, 8), button
	button.Activated:Connect(function()
		dialogue.Visible = false
		choice:FireServer(index)
	end)
	buttons[index] = button
end

local function title(message: string)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency, label.Size, label.Font =
		1, UDim2.fromScale(1, 1), Enum.Font.GothamBold
	label.Text, label.TextColor3, label.TextSize, label.TextTransparency, label.ZIndex, label.Parent =
		message, Color3.fromRGB(224, 245, 242), 34, 1, 10, gui
	TweenService:Create(label, TweenInfo.new(1), { TextTransparency = 0 }):Play()
	task.delay(3, function()
		local tween = TweenService:Create(label, TweenInfo.new(1), { TextTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		label:Destroy()
	end)
end

story.OnClientEvent:Connect(function(kind: string, payload: any)
	if kind == "Title" and typeof(payload) == "string" then
		title(payload)
	elseif kind == "Objective" and typeof(payload) == "string" then
		objective.Text = payload
	elseif kind == "Dialogue" and typeof(payload) == "table" then
		speaker.Text, text.Text = tostring(payload.speaker), tostring(payload.text)
		for index, button in buttons do
			local option = payload.choices[index]
			button.Visible, button.Text = option ~= nil, if option then tostring(option) else ""
		end
		dialogue.Visible = true
		if #payload.choices == 0 then
			task.delay(3.5, function()
				dialogue.Visible = false
			end)
		end
	elseif kind == "Phase" and payload == "Hunt" then
		tint.BackgroundTransparency, objective.TextColor3 = 0.82, Color3.fromRGB(255, 196, 205)
	elseif kind == "Phase" and payload == "Escaped" then
		tint.BackgroundTransparency, objective.TextColor3 = 1, Color3.fromRGB(190, 255, 226)
	elseif kind == "Timer" and typeof(payload) == "number" then
		objective.Text = `SURVIVE — {payload}`
	end
end)
