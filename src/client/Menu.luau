-- Menú al entrar: elegir slot (3, dos bloqueados por nivel) y, dentro del slot,
-- ver tu personaje, hacer Spin para cambiar de raza y entrar a jugar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local RacePreview = require(script.Parent.RacePreview)
local UI = require(script.Parent.UI)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getMenuRemote = remotes:WaitForChild("GetMenu")
local selectSlotRemote = remotes:WaitForChild("SelectSlot")
local spinRemote = remotes:WaitForChild("Spin")
local playRemote = remotes:WaitForChild("Play")
local setRaceRemote = remotes:WaitForChild("SetRace")

local player = Players.LocalPlayer
local Colors = UI.Colors
local create = UI.create

local Menu = {}

local onPlay = nil -- función que se llama al entrar al juego
local currentSlot = nil -- resumen del slot abierto (viene del servidor)
local busy = false -- true mientras esperamos al servidor o gira el spin
local confirmSpin = false -- pedir confirmación antes de perder una raza rara

--------------------------------------------------------------------------------
-- Base
--------------------------------------------------------------------------------

local gui = create("ScreenGui", {
	Name = "Menu",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 10,
	Enabled = false,
}, player:WaitForChild("PlayerGui"))

local background = create("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Colors.White,
	BackgroundTransparency = 0.15,
}, gui)
create("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(20, 55, 110), Color3.fromRGB(4, 8, 22)),
	Rotation = 90,
}, background)

local toastLabel = UI.label(gui, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -96),
	Size = UDim2.new(0.8, 0, 0, 28),
	Font = Enum.Font.GothamBold,
	TextSize = 18,
	TextColor3 = Color3.fromRGB(255, 120, 120),
	TextStrokeTransparency = 0.4,
	TextTransparency = 1,
	ZIndex = 10,
	Text = "",
})

local toastToken = 0
local function toast(text, color)
	toastToken += 1
	local token = toastToken
	toastLabel.Text = text
	toastLabel.TextColor3 = color or Color3.fromRGB(255, 120, 120)
	toastLabel.TextTransparency = 0
	task.delay(2.5, function()
		if token == toastToken then
			TweenService:Create(toastLabel, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		end
	end)
end

--------------------------------------------------------------------------------
-- Pantalla 1: elegir slot
--------------------------------------------------------------------------------

local mainScreen = create("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
}, gui)

UI.label(mainScreen, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.07),
	Size = UDim2.new(0.9, 0, 0, 56),
	Font = UI.Fonts.Title,
	TextSize = 54,
	TextColor3 = Colors.Accent,
	TextStrokeColor3 = Color3.fromRGB(10, 60, 120),
	TextStrokeTransparency = 0,
	Text = Config.GameName,
})

UI.label(mainScreen, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.07, 60),
	Size = UDim2.new(0.9, 0, 0, 24),
	TextSize = 18,
	Font = UI.Fonts.Title,
	TextColor3 = Colors.Gold,
	Text = "◆ Elige un slot ◆",
})

local slotsRow = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.58),
	Size = UDim2.fromScale(0.95, 0.6),
	BackgroundTransparency = 1,
}, mainScreen)
create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 16),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, slotsRow)

local loadingLabel = UI.label(mainScreen, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.58),
	Size = UDim2.fromOffset(300, 40),
	TextSize = 20,
	TextColor3 = Colors.Muted,
	Text = "Cargando...",
})

--------------------------------------------------------------------------------
-- Pantalla 2: dentro del slot
--------------------------------------------------------------------------------

local slotScreen = create("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Visible = false,
}, gui)

local backButton = UI.button(slotScreen, "← Atrás", Colors.PanelLight, {
	Position = UDim2.fromOffset(16, 16),
	Size = UDim2.fromOffset(120, 40),
	TextSize = 16,
})

local slotTitle = UI.label(slotScreen, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 18),
	Size = UDim2.new(0.5, 0, 0, 36),
	Font = Enum.Font.GothamBlack,
	TextSize = 28,
	Text = "Slot 1",
})

-- Panel izquierdo: personaje
local leftPanel = create("Frame", {
	Position = UDim2.new(0.03, 0, 0, 70),
	Size = UDim2.new(0.34, 0, 1, -160),
	BackgroundColor3 = Colors.Panel,
	BackgroundTransparency = 0.1,
}, slotScreen)
local leftStroke = UI.theme(leftPanel, 14)

local viewport = create("ViewportFrame", {
	Size = UDim2.new(1, 0, 1, -70),
	BackgroundTransparency = 1,
}, leftPanel)
local viewportCamera = Instance.new("Camera")
viewportCamera.FieldOfView = 35
viewportCamera.CFrame = RacePreview.CameraCFrame
viewportCamera.Parent = viewport
viewport.CurrentCamera = viewportCamera

local raceNameLabel = UI.label(leftPanel, {
	Position = UDim2.new(0, 0, 1, -68),
	Size = UDim2.new(1, 0, 0, 36),
	Font = Enum.Font.GothamBlack,
	TextSize = 30,
	Text = "",
})

local rarityLabel = UI.label(leftPanel, {
	Position = UDim2.new(0, 0, 1, -32),
	Size = UDim2.new(1, 0, 0, 22),
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	Text = "",
})

-- Panel derecho: información de la raza y tabla de probabilidades
local rightPanel = create("Frame", {
	Position = UDim2.new(0.39, 0, 0, 70),
	Size = UDim2.new(0.58, 0, 1, -160),
	BackgroundColor3 = Colors.Panel,
	BackgroundTransparency = 0.1,
}, slotScreen)
UI.theme(rightPanel, 14)
UI.padding(rightPanel, 14)

local infoScroll = create("ScrollingFrame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 6,
}, rightPanel)
create("UIListLayout", {
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, infoScroll)

local function infoText(order, props)
	local settings = {
		Size = UDim2.new(1, -10, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		RichText = true,
		LayoutOrder = order,
	}
	for key, value in props do
		settings[key] = value
	end
	return UI.label(infoScroll, settings)
end

infoText(1, { Text = "TU RAZA", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Colors.Muted })
local descriptionLabel = infoText(2, { Text = "", TextSize = 16 })
local traitsLabel = infoText(3, { Text = "", TextSize = 15, TextColor3 = Color3.fromRGB(200, 230, 255) })
infoText(4, {
	Text = "RAZAS POSIBLES (Spin)",
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	TextColor3 = Colors.Muted,
})
local testerHint = infoText(5, {
	Text = "<b>MODO PRUEBA (solo tú):</b> toca una raza para elegirla sin gastar spins",
	TextSize = 13,
	TextColor3 = Color3.fromRGB(255, 210, 90),
	Visible = false,
})

local chooseRace -- se define más abajo (modo prueba)
local raceRows = {} -- [raceId] = { Frame, Stroke, Button }
for index, raceId in Config.DisplayOrder do
	local race = Config.Races[raceId]
	local rarity = Config.Rarities[race.Rarity]
	local isSubtype = Config.ParentRace(raceId) ~= nil

	-- Los subtipos y tipos van metidos hacia la derecha, debajo de su raza
	local row = create("Frame", {
		Size = UDim2.new(1, -10, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = if isSubtype then rarity.Color:Lerp(Colors.Panel, 0.82) else Colors.PanelLight,
		LayoutOrder = 10 + index,
	}, infoScroll)
	UI.round(row, 8)
	local rowPadding = UI.padding(row, 8)
	if isSubtype then
		rowPadding.PaddingLeft = UDim.new(0, 28)
	end
	local stroke = create("UIStroke", { Thickness = 2, Color = rarity.Color, Enabled = false }, row)

	local header
	if race.VariantOf then
		header = string.format(
			'<font color="#%s"><b>↳ TIPO de %s</b></font>   <b>%s</b>  <font color="#%s">(%s total)</font>',
			rarity.Color:ToHex(),
			Config.Races[race.VariantOf].Name,
			race.Name,
			Colors.Muted:ToHex(),
			Config.ChanceText(raceId)
		)
	elseif isSubtype then
		header = string.format(
			'<font color="#%s"><b>↳ SUBTIPO de %s · %s de los %s</b></font>   <b>%s</b>  <font color="#%s">(%s total)</font>',
			rarity.Color:ToHex(),
			Config.Races[race.SubtypeOf].Name,
			Config.SubtypeChanceText(raceId),
			Config.Races[race.SubtypeOf].Name,
			race.Name,
			Colors.Muted:ToHex(),
			Config.ChanceText(raceId)
		)
	else
		header = string.format(
			'<font color="#%s"><b>%s · %s</b></font>   <b>%s</b>',
			rarity.Color:ToHex(),
			rarity.Name,
			Config.ChanceText(raceId),
			race.Name
		)
	end

	UI.label(row, {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Left,
		RichText = true,
		TextSize = 14,
		Text = header .. string.format('\n<font color="#%s">%s</font>', Colors.Muted:ToHex(), race.Description),
	})

	-- Botón invisible encima de la fila (solo en modo prueba)
	local rowButton = create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 3,
		Visible = false,
	}, row)
	rowButton.Activated:Connect(function()
		chooseRace(raceId)
	end)

	raceRows[raceId] = { Frame = row, Stroke = stroke, Button = rowButton }
end

local function updateTesterMode()
	local isTester = player:GetAttribute("IsTester") == true
	testerHint.Visible = isTester
	for _, row in raceRows do
		row.Button.Visible = isTester
	end
end
player:GetAttributeChangedSignal("IsTester"):Connect(updateTesterMode)
updateTesterMode()

-- Barra inferior: Spin y Jugar
local bottomBar = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -16),
	Size = UDim2.new(0.94, 0, 0, 64),
	BackgroundTransparency = 1,
}, slotScreen)
create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 16),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, bottomBar)

local SPIN_COLOR = Color3.fromRGB(150, 80, 230)
local spinButton = UI.button(bottomBar, "Spin", SPIN_COLOR, {
	Size = UDim2.fromOffset(280, 56),
	TextSize = 20,
	LayoutOrder = 1,
})
local playButton = UI.button(bottomBar, "Jugar", Colors.Green, {
	Size = UDim2.fromOffset(200, 56),
	TextSize = 22,
	LayoutOrder = 2,
})

-- Cartel grande al terminar el spin
local banner = UI.label(gui, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.45),
	Size = UDim2.new(0.9, 0, 0, 80),
	Font = Enum.Font.GothamBlack,
	TextSize = 56,
	TextStrokeTransparency = 1,
	TextTransparency = 1,
	ZIndex = 10,
	Text = "",
})

--------------------------------------------------------------------------------
-- Mostrar una raza (modelo, nombre, rareza, descripción)
--------------------------------------------------------------------------------

local previewModel = nil

local function showRace(raceId)
	local race = Config.Races[raceId]
	local rarity = Config.Rarities[race.Rarity]

	if previewModel then
		previewModel:Destroy()
	end
	previewModel = RacePreview.Build(raceId)
	previewModel.Parent = viewport

	raceNameLabel.Text = race.Name
	raceNameLabel.TextColor3 = rarity.Color
	if race.SubtypeOf then
		rarityLabel.Text = rarity.Name .. "  ·  Subtipo de " .. Config.Races[race.SubtypeOf].Name
	elseif race.VariantOf then
		rarityLabel.Text = rarity.Name .. "  ·  Tipo de " .. Config.Races[race.VariantOf].Name
	else
		rarityLabel.Text = rarity.Name .. "  ·  " .. Config.ChanceText(raceId)
	end
	rarityLabel.TextColor3 = rarity.Color
	leftStroke.Color = rarity.Color

	descriptionLabel.Text = race.Description
	local traits = {}
	for _, trait in race.Traits do
		table.insert(traits, "• " .. trait)
	end
	traitsLabel.Text = table.concat(traits, "\n")

	for id, row in raceRows do
		row.Stroke.Enabled = id == raceId
	end
end

-- Balanceo suave del personaje
RunService.RenderStepped:Connect(function()
	if previewModel and gui.Enabled and slotScreen.Visible then
		previewModel:PivotTo(CFrame.Angles(0, math.sin(os.clock() * 1.2) * 0.5, 0))
	end
end)

local function updateSpinButton()
	confirmSpin = false
	if currentSlot.Spins > 0 then
		spinButton.Text = "Spin (" .. currentSlot.Spins .. " restantes)"
		UI.setButtonColor(spinButton, SPIN_COLOR)
	else
		spinButton.Text = "Sin spins"
		UI.setButtonColor(spinButton, Colors.PanelLight)
	end
end

--------------------------------------------------------------------------------
-- Pantalla 1: tarjetas de slot
--------------------------------------------------------------------------------

local openSlot -- se define más abajo

local function buildSlotCard(summary)
	local card = create("Frame", {
		Size = UDim2.fromScale(0.3, 1),
		BackgroundColor3 = if summary.Locked then Color3.fromRGB(24, 25, 38) else Colors.Panel,
		LayoutOrder = summary.Index,
	}, slotsRow)
	create("UISizeConstraint", { MaxSize = Vector2.new(240, 300) }, card)
	local stroke = UI.theme(card, 14, Colors.PanelLight)
	if summary.Locked then
		card.BackgroundTransparency = 0.35
	end
	UI.padding(card, 14)

	UI.label(card, {
		Size = UDim2.new(1, 0, 0, 26),
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		Text = "Slot " .. summary.Index,
	})

	if summary.Locked then
		UI.label(card, {
			Position = UDim2.fromScale(0, 0.22),
			Size = UDim2.new(1, 0, 0, 60),
			TextSize = 46,
			Text = "🔒",
		})
		UI.label(card, {
			Position = UDim2.fromScale(0, 0.55),
			Size = UDim2.new(1, 0, 0, 24),
			Font = Enum.Font.GothamBold,
			TextSize = 18,
			TextColor3 = Colors.Muted,
			Text = "Bloqueado",
		})
		UI.label(card, {
			Position = UDim2.new(0, 0, 0.55, 28),
			Size = UDim2.new(1, 0, 0, 40),
			TextSize = 15,
			TextColor3 = Colors.Muted,
			Text = "Requiere nivel " .. summary.RequiredLevel,
		})
		return
	end

	local race = Config.Races[summary.Race]
	local rarity = Config.Rarities[race.Rarity]
	stroke.Color = rarity.Color

	UI.label(card, {
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 32),
		Font = Enum.Font.GothamBlack,
		TextSize = 26,
		TextColor3 = rarity.Color,
		Text = race.Name,
	})
	UI.label(card, {
		Position = UDim2.fromOffset(0, 72),
		Size = UDim2.new(1, 0, 0, 20),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = rarity.Color,
		Text = if race.SubtypeOf
			then rarity.Name .. " · Subtipo de " .. Config.Races[race.SubtypeOf].Name
			elseif race.VariantOf then rarity.Name .. " · Tipo de " .. Config.Races[race.VariantOf].Name
			else rarity.Name,
	})
	UI.label(card, {
		Position = UDim2.fromOffset(0, 100),
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 17,
		Text = "Nivel " .. summary.Level,
	})
	UI.label(card, {
		Position = UDim2.fromOffset(0, 124),
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 14,
		TextColor3 = Colors.Muted,
		Text = "Spins: " .. summary.Spins .. "   ·   Oro: " .. (summary.Gold or 0),
	})

	local enterButton = UI.button(card, "Entrar", Colors.Green, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 44),
	})
	enterButton.Activated:Connect(function()
		openSlot(summary.Index)
	end)
end

local function showMainScreen()
	slotScreen.Visible = false
	mainScreen.Visible = true
	loadingLabel.Visible = true

	for _, child in slotsRow:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	task.spawn(function()
		local ok, data = pcall(getMenuRemote.InvokeServer, getMenuRemote)
		loadingLabel.Visible = false
		if not ok or not data then
			loadingLabel.Visible = true
			loadingLabel.Text = "No se pudieron cargar tus datos. Vuelve a entrar."
			return
		end
		for _, summary in data.Slots do
			buildSlotCard(summary)
		end
	end)
end

--------------------------------------------------------------------------------
-- Pantalla 2: acciones
--------------------------------------------------------------------------------

function openSlot(index)
	if busy then
		return
	end
	busy = true
	local ok, result = pcall(selectSlotRemote.InvokeServer, selectSlotRemote, index)
	busy = false

	if not ok or not result or not result.Ok then
		toast(if ok and result then result.Message else "Error al abrir el slot")
		return
	end

	currentSlot = result.Slot
	slotTitle.Text = "Slot " .. currentSlot.Index .. "  ·  Nivel " .. currentSlot.Level
	showRace(currentSlot.Race)
	updateSpinButton()
	mainScreen.Visible = false
	slotScreen.Visible = true
end

local function showBanner(raceId)
	local race = Config.Races[raceId]
	local rarity = Config.Rarities[race.Rarity]
	banner.Text = "¡" .. race.Name .. "!  (" .. rarity.Name .. ")"
	banner.TextColor3 = rarity.Color
	banner.TextTransparency = 0
	banner.TextStrokeTransparency = 0.2
	banner.Size = UDim2.new(0.9, 0, 0, 40)
	TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0.9, 0, 0, 80),
	}):Play()
	task.delay(2, function()
		TweenService:Create(banner, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end

-- Animación tipo ruleta: pasa por varias razas y se frena en la que tocó
local function playSpinAnimation(finalRaceId)
	local steps = 24
	local previous = nil
	for step = 1, steps do
		local raceId = finalRaceId
		if step < steps then
			repeat
				raceId = Config.DisplayOrder[math.random(1, #Config.DisplayOrder)]
			until raceId ~= previous
		end
		previous = raceId
		showRace(raceId)
		task.wait(0.04 + (step / steps) ^ 2 * 0.3)
	end
end

spinButton.Activated:Connect(function()
	if busy or not currentSlot then
		return
	end
	if currentSlot.Spins <= 0 then
		toast("No te quedan spins")
		return
	end

	-- Si tienes una raza Mítica o Legendaria, pide confirmación
	local rarityId = Config.Races[currentSlot.Race].Rarity
	if (rarityId == "Mythic" or rarityId == "Legendary") and not confirmSpin then
		confirmSpin = true
		spinButton.Text = "¿Seguro? Perderás tu raza"
		UI.setButtonColor(spinButton, Colors.Red)
		task.delay(3, function()
			if confirmSpin and not busy then
				updateSpinButton()
			end
		end)
		return
	end

	busy = true
	confirmSpin = false
	spinButton.Text = "Girando..."
	local ok, result = pcall(spinRemote.InvokeServer, spinRemote)
	if ok and result and result.Ok then
		playSpinAnimation(result.Race)
		currentSlot.Race = result.Race
		currentSlot.Spins = result.Spins
		showBanner(result.Race)
	else
		toast(if ok and result then result.Message else "Error al hacer spin")
	end
	updateSpinButton()
	busy = false
end)

playButton.Activated:Connect(function()
	if busy or not currentSlot then
		return
	end
	busy = true
	local ok, result = pcall(playRemote.InvokeServer, playRemote)
	busy = false

	if ok and result and result.Ok then
		Menu.Close()
		if onPlay then
			onPlay()
		end
	else
		toast(if ok and result then result.Message else "Error al entrar")
	end
end)

backButton.Activated:Connect(function()
	if not busy then
		showMainScreen()
	end
end)

-- Modo prueba: elegir raza directamente
function chooseRace(raceId)
	if busy or not currentSlot or raceId == currentSlot.Race then
		return
	end
	busy = true
	local ok, result = pcall(setRaceRemote.InvokeServer, setRaceRemote, raceId)
	busy = false

	if ok and result and result.Ok then
		currentSlot.Race = result.Race
		showRace(result.Race)
		updateSpinButton()
		toast("Modo prueba: ahora eres " .. Config.Races[result.Race].Name, Color3.fromRGB(255, 210, 90))
	else
		toast(if ok and result then result.Message else "Error al cambiar de raza")
	end
end

--------------------------------------------------------------------------------
-- API
--------------------------------------------------------------------------------

function Menu.Init(onPlayCallback)
	onPlay = onPlayCallback
end

function Menu.Open()
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(Vector3.new(60, 35, 40), Vector3.new(0, 0, -120))

	gui.Enabled = true
	showMainScreen()
end

function Menu.Close()
	gui.Enabled = false
	Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
end

return Menu
