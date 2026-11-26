-- Diálogo con el NPC de misiones: elegir misión, ver el progreso, recoger la recompensa.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UI = require(script.Parent.UI)

local questRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Quest")

local player = Players.LocalPlayer
local Colors = UI.Colors
local create = UI.create
local GOLD = Color3.fromRGB(255, 205, 70)

local Dialog = {}

local gui = create("ScreenGui", {
	Name = "Dialog",
	ResetOnSpawn = false,
	DisplayOrder = 5,
	Enabled = false,
}, player:WaitForChild("PlayerGui"))

local window = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.fromScale(0.6, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = Colors.White,
}, gui)
create("UISizeConstraint", { MinSize = Vector2.new(320, 0), MaxSize = Vector2.new(620, 2000) }, window)
UI.round(window, 14)
create("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(45, 40, 75), Color3.fromRGB(18, 18, 32)),
	Rotation = 90,
}, window)
create("UIStroke", { Color = GOLD, Thickness = 2 }, window)
UI.padding(window, 16)
create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, window)

UI.label(window, {
	Size = UDim2.new(1, 0, 0, 24),
	Font = Enum.Font.GothamBlack,
	TextSize = 20,
	TextColor3 = GOLD,
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 1,
	Text = "🧙 " .. Config.QuestGiver.Name,
})

local speechLabel = UI.label(window, {
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	TextSize = 16,
	RichText = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 2,
	Text = "",
})

local content = create("Frame", {
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	LayoutOrder = 3,
}, window)
create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, content)

local buttonRow = create("Frame", {
	Size = UDim2.new(1, 0, 0, 44),
	BackgroundTransparency = 1,
	LayoutOrder = 4,
}, window)
create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, buttonRow)

local errorLabel = UI.label(window, {
	Size = UDim2.new(1, 0, 0, 18),
	TextSize = 14,
	TextColor3 = Color3.fromRGB(255, 120, 120),
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 5,
	Visible = false,
	Text = "",
})

local busy = false
local render -- se define más abajo

local function clear(container)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function close()
	gui.Enabled = false
end

-- Llama al servidor y vuelve a dibujar el diálogo con la respuesta
local function act(action, questId)
	if busy then
		return
	end
	busy = true
	local ok, result = pcall(questRemote.InvokeServer, questRemote, action, questId)
	busy = false
	if ok and result and result.Ok then
		errorLabel.Visible = false
		if action == "Claim" or action == "Abandon" then
			render(result.Quest)
		else
			close()
		end
	else
		errorLabel.Text = if ok and result then result.Message else "Error al hablar con el NPC"
		errorLabel.Visible = true
	end
end

local function addButton(text, color, order, callback)
	local button = UI.button(buttonRow, text, color, {
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 16,
		LayoutOrder = order,
	})
	create("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, button)
	button.Activated:Connect(callback)
	return button
end

local function rewardText(quest)
	return "Recompensa: <b>"
		.. quest.BaseXP
		.. "+ XP</b> y <b>"
		.. quest.BaseGold
		.. "+ oro</b> (más según el nivel de los monstruos)"
end

-- Tarjeta de una misión en la lista
local function questCard(quest, level, order, canAccept)
	local locked = level < quest.MinLevel
	local card = create("Frame", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = if locked then Color3.fromRGB(28, 28, 40) else Color3.fromRGB(50, 50, 80),
		LayoutOrder = order,
	}, content)
	UI.round(card, 10)
	local padding = UI.padding(card, 10)
	padding.PaddingRight = UDim.new(0, 130)
	create(
		"UIStroke",
		{ Color = if locked then Colors.PanelLight else GOLD, Thickness = 1.5, Transparency = 0.3 },
		card
	)

	local monsterName = Config.Monsters[quest.Monster].DisplayName
	UI.label(card, {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 14,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = if locked then Colors.Muted else Colors.White,
		Text = string.format(
			'<font color="#%s"><b>%s</b></font>  <font color="#%s">Nivel %d+</font>\nDerrota a <b>%d × %s</b>\n%s',
			(if locked then Colors.Muted else GOLD):ToHex(),
			quest.Title,
			Colors.Muted:ToHex(),
			quest.MinLevel,
			quest.Count,
			monsterName,
			rewardText(quest)
		),
	})

	local button = UI.button(
		card,
		if locked then "🔒 Nivel " .. quest.MinLevel else "Aceptar",
		if locked then Colors.PanelLight else Colors.Green,
		{
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(1, 10, 0.5, 0),
			Size = UDim2.fromOffset(110, 40),
			TextSize = 15,
		}
	)
	button.AutoButtonColor = canAccept and not locked
	button.Activated:Connect(function()
		if canAccept and not locked then
			act("Accept", quest.Id)
		end
	end)
end

function render(state)
	clear(content)
	clear(buttonRow)
	errorLabel.Visible = false

	if state.State == "None" then
		speechLabel.Text =
			"¡Hola, viajero! Los monstruos no paran de molestar al pueblo. ¿Me ayudas? Elige una misión:"
		for index, quest in Config.Quests do
			questCard(quest, state.Level, index, true)
		end
		addButton("Ahora no", Colors.PanelLight, 1, close)
	else
		local quest = Config.GetQuest(state.QuestId)
		local monsterName = Config.Monsters[quest.Monster].DisplayName
		if state.State == "Done" then
			speechLabel.Text = string.format(
				"¡Excelente trabajo! Has derrotado a los %d %s. Aquí tienes tu recompensa:\n<b>+%d XP</b> y <b>+%d oro</b>",
				quest.Count,
				monsterName,
				state.RewardXP,
				state.RewardGold
			)
			addButton("Recoger recompensa", GOLD:Lerp(Color3.new(), 0.25), 1, function()
				act("Claim")
			end)
		else
			speechLabel.Text = string.format(
				"<b>%s</b>\n%s\nLlevas <b>%d / %d</b>. ¡Vuelve cuando termines!\nRecompensa por ahora: <b>%d XP</b> y <b>%d oro</b>",
				quest.Title,
				quest.Description,
				state.Kills,
				quest.Count,
				state.RewardXP,
				state.RewardGold
			)
			addButton("Abandonar misión", Colors.Red, 1, function()
				act("Abandon")
			end)
			addButton("Cerrar", Colors.PanelLight, 2, close)
		end
	end
end

local function open()
	if busy then
		return
	end
	busy = true
	local ok, result = pcall(questRemote.InvokeServer, questRemote, "Get")
	busy = false
	if ok and result and result.Ok then
		render(result.Quest)
		gui.Enabled = true
	end
end

-- Abrir al pulsar T junto al NPC
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "QuestPrompt" then
		open()
	end
end)

-- Cerrar si te alejas
RunService.Heartbeat:Connect(function()
	if not gui.Enabled then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - Config.QuestGiver.Position).Magnitude > Config.QuestGiver.TalkDistance + 6 then
		close()
	end
end)

function Dialog.Close()
	close()
end

return Dialog
