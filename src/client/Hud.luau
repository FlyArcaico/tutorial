-- HUD del juego: tarjeta del personaje (vida/XP), rasgos, botones de ataque a la izquierda,
-- contador de oro abajo a la derecha, mensajes y efectos.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UI = require(script.Parent.UI)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local attackRemote = remotes:WaitForChild("Attack")
local absorbRemote = remotes:WaitForChild("Absorb")
local castRemote = remotes:WaitForChild("Cast")
local notifyRemote = remotes:WaitForChild("Notify")
local sprintRemote = remotes:WaitForChild("Sprint")
local devLevelRemote = remotes:WaitForChild("DevLevel")

local player = Players.LocalPlayer
local Colors = UI.Colors
local create = UI.create

local GOLD = Color3.fromRGB(255, 205, 70)

local Hud = {}

-- Usamos nuestra propia barra de vida
pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Health, false)

local gui =
	create("ScreenGui", { Name = "Hud", ResetOnSpawn = false, Enabled = false }, player:WaitForChild("PlayerGui"))

--------------------------------------------------------------------------------
-- Piezas de interfaz
--------------------------------------------------------------------------------

-- Panel oscuro con degradado y borde
local function panel(parent, props)
	local frame = create("Frame", {
		BackgroundColor3 = Colors.White,
		BackgroundTransparency = 0.08,
	}, parent)
	for key, value in props do
		frame[key] = value
	end
	UI.round(frame, 12)
	create("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(40, 44, 72), Color3.fromRGB(16, 18, 30)),
		Rotation = 90,
	}, frame)
	local stroke = create("UIStroke", {
		Color = Color3.fromRGB(85, 95, 140),
		Thickness = 1.5,
		Transparency = 0.25,
	}, frame)
	return frame, stroke
end

-- Barra con relleno y texto encima
local function bar(parent, position, height, fillTop, fillBottom)
	local back = create("Frame", {
		Position = position,
		Size = UDim2.new(1, -24, 0, height),
		BackgroundColor3 = Color3.fromRGB(12, 13, 22),
	}, parent)
	UI.round(back, height // 2)

	local fill = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Colors.White,
	}, back)
	UI.round(fill, height // 2)
	create("UIGradient", { Color = ColorSequence.new(fillTop, fillBottom), Rotation = 90 }, fill)

	local text = UI.label(back, {
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = math.max(10, height - 4),
		TextStrokeTransparency = 0.4,
		ZIndex = 2,
		Text = "",
	})
	return fill, text
end

--------------------------------------------------------------------------------
-- Tarjeta del personaje (arriba a la izquierda)
--------------------------------------------------------------------------------

local card, cardStroke = panel(gui, {
	Position = UDim2.fromOffset(16, 16),
	Size = UDim2.fromOffset(300, 148),
})

local rarityPill = create("Frame", {
	Position = UDim2.fromOffset(12, 10),
	Size = UDim2.fromOffset(0, 20),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = Colors.Muted,
}, card)
UI.round(rarityPill, 10)
create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, rarityPill)
local rarityText = UI.label(rarityPill, {
	Size = UDim2.fromScale(0, 1),
	AutomaticSize = Enum.AutomaticSize.X,
	Font = Enum.Font.GothamBlack,
	TextSize = 12,
	TextColor3 = Colors.Dark,
	TextWrapped = false,
	Text = "",
})

local levelBadge = create("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 8),
	Size = UDim2.fromOffset(62, 24),
	BackgroundColor3 = Color3.fromRGB(12, 13, 22),
}, card)
UI.round(levelBadge, 8)
create("UIStroke", { Color = GOLD, Thickness = 1.5 }, levelBadge)
local levelText = UI.label(levelBadge, {
	Size = UDim2.fromScale(1, 1),
	Font = Enum.Font.GothamBlack,
	TextSize = 14,
	TextColor3 = GOLD,
	Text = "Nv. 1",
})

local nameLabel = UI.label(card, {
	Position = UDim2.fromOffset(12, 34),
	Size = UDim2.new(1, -24, 0, 28),
	Font = Enum.Font.GothamBlack,
	TextSize = 22,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextWrapped = false,
	TextTruncate = Enum.TextTruncate.AtEnd,
	Text = "",
})

local hpFill, hpText =
	bar(card, UDim2.fromOffset(12, 66), 18, Color3.fromRGB(110, 230, 120), Color3.fromRGB(40, 160, 70))
local manaFill, manaText =
	bar(card, UDim2.fromOffset(12, 88), 14, Color3.fromRGB(120, 140, 255), Color3.fromRGB(70, 60, 220))
local staminaFill, staminaText =
	bar(card, UDim2.fromOffset(12, 106), 14, Color3.fromRGB(240, 240, 120), Color3.fromRGB(200, 170, 40))
local xpFill, xpText =
	bar(card, UDim2.fromOffset(12, 124), 12, Color3.fromRGB(230, 150, 255), Color3.fromRGB(150, 70, 220))

-- Estados (debajo de la tarjeta): Berserker, Sobrecarga, Regenerando
local statusRow = create("Frame", {
	Position = UDim2.fromOffset(16, 170),
	Size = UDim2.fromOffset(300, 24),
	BackgroundTransparency = 1,
}, gui)
create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, statusRow)

local function statusChip(order, text, color)
	local chip = create("Frame", {
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = color:Lerp(Color3.new(), 0.55),
		LayoutOrder = order,
		Visible = false,
	}, statusRow)
	UI.round(chip, 12)
	create("UIStroke", { Color = color, Thickness = 1.5 }, chip)
	create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, chip)
	UI.label(chip, {
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Font = Enum.Font.GothamBlack,
		TextSize = 12,
		TextColor3 = color:Lerp(Colors.White, 0.4),
		TextWrapped = false,
		Text = text,
	})
	return chip
end

local berserkChip = statusChip(1, "💢 BERSERKER", Color3.fromRGB(255, 60, 50))
local overloadChip = statusChip(2, "⚡ SOBRECARGA", Color3.fromRGB(255, 150, 50))
local regenChip = statusChip(3, "✚ Regenerando", Color3.fromRGB(90, 220, 120))
local safeChip = statusChip(4, "🛡 Zona segura", Color3.fromRGB(120, 230, 170))
local exhaustedChip = statusChip(5, "💦 Agotado", Color3.fromRGB(200, 200, 120))

-- Progreso de la misión (debajo de los estados)
local questPanel = panel(gui, {
	Position = UDim2.fromOffset(16, 200),
	Size = UDim2.fromOffset(300, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Visible = false,
})
create("UIPadding", {
	PaddingLeft = UDim.new(0, 12),
	PaddingRight = UDim.new(0, 12),
	PaddingTop = UDim.new(0, 8),
	PaddingBottom = UDim.new(0, 10),
}, questPanel)
local questLabel = UI.label(questPanel, {
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	TextSize = 14,
	RichText = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "",
})
local questBarBack = create("Frame", {
	Size = UDim2.new(1, 0, 0, 8),
	BackgroundColor3 = Color3.fromRGB(12, 13, 22),
	LayoutOrder = 2,
}, questPanel)
UI.round(questBarBack, 4)
local questBarFill = create("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Color3.fromRGB(255, 205, 70),
}, questBarBack)
UI.round(questBarFill, 4)
create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, questPanel)

-- Barra de "calor" de la Sobrecarga de Energía (solo Invocados)
local heatBar = create("Frame", {
	Position = UDim2.fromOffset(16, 200),
	Size = UDim2.fromOffset(300, 8),
	BackgroundColor3 = Color3.fromRGB(12, 13, 22),
	Visible = false,
}, gui)
UI.round(heatBar, 4)
local heatFill = create("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Color3.fromRGB(255, 150, 50),
}, heatBar)
UI.round(heatFill, 4)
UI.label(heatBar, {
	Position = UDim2.fromOffset(0, 9),
	Size = UDim2.new(1, 0, 0, 14),
	Font = Enum.Font.GothamBold,
	TextSize = 11,
	TextColor3 = Colors.Muted,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Energía acumulada (no abuses de las habilidades)",
})

--------------------------------------------------------------------------------
-- Panel de rasgos / habilidades (arriba a la derecha)
--------------------------------------------------------------------------------

local menuButton = UI.button(gui, "☰  Menú", Color3.fromRGB(45, 48, 75), {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 16),
	Size = UDim2.fromOffset(120, 38),
	TextSize = 16,
})
create("UIStroke", { Color = Color3.fromRGB(85, 95, 140), Thickness = 1.5 }, menuButton)

-- Modo prueba: botones para bajar/subir 5 niveles (solo tú)
local devPanel = create("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -144, 0, 16),
	Size = UDim2.fromOffset(0, 38),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
	Visible = false,
}, gui)
create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, devPanel)
for order, delta in { -5, 5 } do
	local devButton =
		UI.button(devPanel, (if delta > 0 then "+" else "") .. delta .. " Nv", Color3.fromRGB(150, 90, 30), {
			Size = UDim2.fromOffset(72, 38),
			TextSize = 15,
			LayoutOrder = order,
		})
	create("UIStroke", { Color = Color3.fromRGB(255, 200, 90), Thickness = 1.5 }, devButton)
	devButton.Activated:Connect(function()
		devLevelRemote:FireServer(delta)
	end)
end
local function updateDevPanel()
	devPanel.Visible = player:GetAttribute("IsTester") == true
end
player:GetAttributeChangedSignal("IsTester"):Connect(updateDevPanel)
updateDevPanel()

local infoPanel = panel(gui, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 64),
	Size = UDim2.fromOffset(270, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
})
create("UIPadding", {
	PaddingLeft = UDim.new(0, 12),
	PaddingRight = UDim.new(0, 12),
	PaddingTop = UDim.new(0, 10),
	PaddingBottom = UDim.new(0, 12),
}, infoPanel)

local infoLabel = UI.label(infoPanel, {
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	TextSize = 14,
	RichText = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	Text = "",
})

--------------------------------------------------------------------------------
-- Botones de acción (lado izquierdo)
--------------------------------------------------------------------------------

local actionColumn = create("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 16, 0.6, 0),
	Size = UDim2.fromOffset(84, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
}, gui)
create("UIListLayout", {
	Padding = UDim.new(0, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, actionColumn)

local actions = {} -- [id] = action
local orderedActions = {}

local function makeAction(id, order, icon, name, key, color, cooldown, use)
	local button = create("TextButton", {
		Size = UDim2.fromOffset(84, 84),
		BackgroundColor3 = Colors.White,
		AutoButtonColor = true,
		Text = "",
		LayoutOrder = order,
	}, actionColumn)
	UI.round(button, 18)
	create("UIGradient", {
		Color = ColorSequence.new(color, color:Lerp(Color3.new(), 0.55)),
		Rotation = 90,
	}, button)
	create("UIStroke", {
		Color = color:Lerp(Colors.White, 0.4),
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, button)
	local scale = create("UIScale", { Scale = 1 }, button)

	UI.label(button, {
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 44),
		TextSize = 32,
		Text = icon,
	})
	UI.label(button, {
		Position = UDim2.new(0, 2, 1, -28),
		Size = UDim2.new(1, -4, 0, 24),
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextStrokeTransparency = 0.5,
		Text = name,
	})

	local keyBadge = create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -5, 0, 5),
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0.35,
		ZIndex = 2,
	}, button)
	UI.round(keyBadge, 5)
	create("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }, keyBadge)
	UI.label(keyBadge, {
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Font = Enum.Font.GothamBlack,
		TextSize = 11,
		TextWrapped = false,
		ZIndex = 2,
		Text = key,
	})

	-- Capa de recarga que baja mientras el ataque no está listo
	local overlay = create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0.4,
		Visible = false,
		ZIndex = 3,
	}, button)
	UI.round(overlay, 18)
	local cooldownText = UI.label(button, {
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBlack,
		TextSize = 22,
		TextStrokeTransparency = 0.3,
		Visible = false,
		ZIndex = 4,
		Text = "",
	})

	-- Coste de maná (solo habilidades que gastan maná)
	local costLabel = UI.label(button, {
		Position = UDim2.fromOffset(5, 5),
		Size = UDim2.fromOffset(40, 16),
		Font = Enum.Font.GothamBlack,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(160, 175, 255),
		TextStrokeTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
		Visible = false,
		Text = "",
	})

	local action = {
		Button = button,
		Scale = scale,
		Overlay = overlay,
		CooldownText = cooldownText,
		CostLabel = costLabel,
		ManaCost = 0,
		Key = key,
		Cooldown = cooldown,
		ReadyAt = 0,
		Use = use,
	}
	actions[id] = action
	table.insert(orderedActions, action)
	return action
end

local function trigger(action)
	if not gui.Enabled or not action.Button.Visible then
		return
	end
	local now = os.clock()
	if now < action.ReadyAt then
		return
	end
	if action.ManaCost > (player:GetAttribute("Mana") or 0) then
		action.Use() -- el servidor avisa de que no hay maná suficiente
		return
	end
	action.ReadyAt = now + action.Cooldown
	action.Use()

	action.Scale.Scale = 0.88
	TweenService:Create(action.Scale, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

--------------------------------------------------------------------------------
-- Contador de oro (abajo a la derecha)
--------------------------------------------------------------------------------

local goldPanel = panel(gui, {
	AnchorPoint = Vector2.new(1, 1),
	Position = if UserInputService.TouchEnabled then UDim2.new(1, -150, 1, -16) else UDim2.new(1, -16, 1, -16),
	Size = UDim2.fromOffset(0, 50),
	AutomaticSize = Enum.AutomaticSize.X,
})
create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 16) }, goldPanel)
create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, goldPanel)

local coin = create("Frame", {
	Size = UDim2.fromOffset(30, 30),
	BackgroundColor3 = Colors.White,
	LayoutOrder = 1,
}, goldPanel)
UI.round(coin, 15)
create("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(255, 230, 120), Color3.fromRGB(215, 150, 30)),
	Rotation = 90,
}, coin)
create("UIStroke", { Color = Color3.fromRGB(150, 100, 20), Thickness = 2 }, coin)
UI.label(coin, {
	Size = UDim2.fromScale(1, 1),
	Font = Enum.Font.GothamBlack,
	TextSize = 16,
	TextColor3 = Color3.fromRGB(130, 85, 10),
	Text = "$",
})

local goldText = UI.label(goldPanel, {
	Size = UDim2.fromOffset(0, 30),
	AutomaticSize = Enum.AutomaticSize.X,
	Font = Enum.Font.GothamBlack,
	TextSize = 26,
	TextColor3 = GOLD,
	TextWrapped = false,
	LayoutOrder = 2,
	Text = "0",
})
UI.label(goldPanel, {
	Size = UDim2.fromOffset(0, 30),
	AutomaticSize = Enum.AutomaticSize.X,
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextColor3 = Colors.Muted,
	TextWrapped = false,
	LayoutOrder = 3,
	Text = "oro",
})
local goldScale = create("UIScale", { Scale = 1 }, goldPanel)

-- "+3" que sube y desaparece al ganar oro
local function popGold(amount)
	local pop = UI.label(gui, {
		AnchorPoint = Vector2.new(1, 1),
		Position = goldPanel.Position - UDim2.fromOffset(20, 54),
		Size = UDim2.fromOffset(100, 30),
		Font = Enum.Font.GothamBlack,
		TextSize = 24,
		TextColor3 = GOLD,
		TextStrokeTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "+" .. amount,
	})
	local rise = TweenService:Create(pop, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = pop.Position - UDim2.fromOffset(0, 40),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	rise.Completed:Connect(function()
		pop:Destroy()
	end)
	rise:Play()

	goldScale.Scale = 1.15
	TweenService:Create(goldScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

--------------------------------------------------------------------------------
-- Mensajes (arriba en el centro)
--------------------------------------------------------------------------------

local notifyGroup = create("CanvasGroup", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 16),
	Size = UDim2.fromOffset(0, 46),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = Color3.fromRGB(18, 20, 34),
	BackgroundTransparency = 0.15,
	GroupTransparency = 1,
}, gui)
UI.round(notifyGroup, 23)
local notifyStroke = create("UIStroke", { Color = Colors.Accent, Thickness = 2 }, notifyGroup)
create("UIPadding", { PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20) }, notifyGroup)
local notifyLabel = UI.label(notifyGroup, {
	Size = UDim2.fromScale(0, 1),
	AutomaticSize = Enum.AutomaticSize.X,
	Font = Enum.Font.GothamBold,
	TextSize = 18,
	TextWrapped = false,
	Text = "",
})

-- Destello rojo al recibir daño y aviso al morir
local damageFlash = create("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(255, 0, 0),
	BackgroundTransparency = 1,
	ZIndex = 0,
}, gui)

local deathLabel = UI.label(gui, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.4),
	Size = UDim2.new(0.8, 0, 0, 60),
	Font = Enum.Font.GothamBlack,
	TextSize = 36,
	TextColor3 = Color3.fromRGB(255, 110, 110),
	TextStrokeTransparency = 0.2,
	Visible = false,
	Text = "Has caído... reapareciendo",
})

--------------------------------------------------------------------------------
-- Estado y acciones
--------------------------------------------------------------------------------

local function getSkills()
	local skills = {}
	for skillId in string.gmatch(player:GetAttribute("Skills") or "", "[^,]+") do
		skills[skillId] = true
	end
	return skills
end

local function getRaceId()
	local raceId = player:GetAttribute("Race")
	return if raceId and Config.Races[raceId] then raceId else Config.DefaultRace
end

local function getAlive()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return humanoid, root
	end
	return nil, nil
end

local function dash()
	local humanoid, root = getAlive()
	if not humanoid then
		return
	end
	local skill = Config.Skills.Dash
	local direction = if humanoid.MoveDirection.Magnitude > 0.1 then humanoid.MoveDirection else root.CFrame.LookVector
	direction = Vector3.new(direction.X, 0, direction.Z)
	if direction.Magnitude < 0.01 then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.MaxForce = 1e7
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VectorVelocity = direction.Unit * skill.Speed
	velocity.Parent = root

	task.delay(skill.Duration, function()
		velocity:Destroy()
		attachment:Destroy()
	end)
end

makeAction("Attack", 1, "⚔️", "Atacar", "Clic", Color3.fromRGB(220, 75, 75), Config.Attack.Cooldown, function()
	attackRemote:FireServer()
end)

-- Un botón por cada habilidad especial (solo se ve el de tu raza)
local abilityIds = {}
for abilityId in Config.Abilities do
	table.insert(abilityIds, abilityId)
end
table.sort(abilityIds)
for _, abilityId in abilityIds do
	local ability = Config.Abilities[abilityId]
	local action = makeAction(
		abilityId,
		2,
		ability.Icon,
		ability.DisplayName,
		ability.Key,
		ability.Color:Lerp(Color3.new(), 0.25),
		ability.Cooldown,
		function()
			castRemote:FireServer(abilityId)
		end
	)
	action.ManaCost = ability.ManaCost
	action.CostLabel.Text = ability.ManaCost .. " MP"
	action.CostLabel.Visible = true
	action.Button.Visible = false
end

makeAction("Absorb", 3, "🌀", "Absorber", "F", Color3.fromRGB(70, 140, 235), 0.3, function()
	absorbRemote:FireServer()
end)
makeAction("Dash", 4, "💨", "Embestir", "Q", Color3.fromRGB(170, 130, 90), Config.Skills.Dash.Cooldown, dash)

-- Correr: mantener Shift izquierdo o Control izquierdo (en móvil, el botón activa/desactiva).
-- En Roblox Studio es mejor Shift: Studio usa Ctrl+A, Ctrl+D... como atajos.
local SPRINT_KEYS = {
	[Enum.KeyCode.LeftShift] = true,
	[Enum.KeyCode.LeftControl] = true,
}
local wantsSprint = false
local function setSprint(enabled)
	if wantsSprint ~= enabled then
		wantsSprint = enabled
		sprintRemote:FireServer(enabled)
	end
end
local sprintAction = makeAction("Sprint", 5, "🏃", "Correr", "Shift", Color3.fromRGB(200, 170, 50), 0, function()
	setSprint(not wantsSprint)
end)
sprintAction.Button.Visible = UserInputService.TouchEnabled

UserInputService.InputEnded:Connect(function(input)
	if SPRINT_KEYS[input.KeyCode] then
		setSprint(false)
	end
end)

-- Si la ventana pierde el foco (por ejemplo al hacer clic en Studio), dejar de correr
UserInputService.WindowFocusReleased:Connect(function()
	setSprint(false)
end)

for _, action in orderedActions do
	action.Button.Activated:Connect(function()
		trigger(action)
	end)
end

local keyNames = {
	[Enum.KeyCode.E] = "E",
	[Enum.KeyCode.F] = "F",
	[Enum.KeyCode.Q] = "Q",
}

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not gui.Enabled then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		trigger(actions.Attack)
		return
	end
	if SPRINT_KEYS[input.KeyCode] then
		setSprint(true)
		return
	end
	-- Usar el botón visible que tenga esa tecla
	local key = keyNames[input.KeyCode]
	if key then
		for _, action in orderedActions do
			if action.Key == key and action.Button.Visible then
				trigger(action)
				break
			end
		end
	end
end)

-- Maná, calor y estados: cambian muy seguido, así que van aparte del refresh general
local FAST_ATTRIBUTES = {
	Mana = true,
	MaxMana = true,
	Heat = true,
	Overloaded = true,
	Berserk = true,
	InCombat = true,
	Stamina = true,
	MaxStamina = true,
	Sprinting = true,
	Exhausted = true,
	InSafeZone = true,
}

local camera = workspace.CurrentCamera
local lastSprinting = false

local function refreshFast()
	local mana = player:GetAttribute("Mana") or 0
	local maxMana = math.max(player:GetAttribute("MaxMana") or 1, 1)
	manaFill.Size = UDim2.fromScale(math.clamp(mana / maxMana, 0, 1), 1)
	manaText.Text = tostring(mana) .. " / " .. tostring(maxMana) .. " MP"

	local race = Config.Races[player:GetAttribute("Race") or Config.DefaultRace] or Config.Races[Config.DefaultRace]
	berserkChip.Visible = player:GetAttribute("Berserk") == true
	overloadChip.Visible = player:GetAttribute("Overloaded") == true
	regenChip.Visible = race.HealthRegen > 0 and player:GetAttribute("InCombat") == false
	safeChip.Visible = player:GetAttribute("InSafeZone") == true
	exhaustedChip.Visible = player:GetAttribute("Exhausted") == true

	heatBar.Visible = race.Overload == true
	heatFill.Size = UDim2.fromScale(math.clamp(player:GetAttribute("Heat") or 0, 0, 1), 1)
	questPanel.Position = UDim2.fromOffset(16, if heatBar.Visible then 230 else 200)

	-- Stamina
	local stamina = player:GetAttribute("Stamina") or 0
	local maxStamina = math.max(player:GetAttribute("MaxStamina") or 1, 1)
	staminaFill.Size = UDim2.fromScale(math.clamp(stamina / maxStamina, 0, 1), 1)
	staminaText.Text = (if player:GetAttribute("Exhausted") then "Agotado  " else "Stamina  ")
		.. tostring(stamina)
		.. " / "
		.. tostring(maxStamina)

	-- Al correr, la cámara se abre un poco para dar sensación de velocidad
	local sprinting = player:GetAttribute("Sprinting") == true
	if sprinting ~= lastSprinting then
		lastSprinting = sprinting
		camera = workspace.CurrentCamera
		TweenService:Create(camera, TweenInfo.new(0.25), { FieldOfView = if sprinting then 80 else 70 }):Play()
		sprintAction.Button.BackgroundTransparency = if sprinting then 0.4 else 0
	end

	-- Habilidades sin maná suficiente: coste en rojo
	for _, action in orderedActions do
		if action.ManaCost > 0 then
			action.CostLabel.TextColor3 = if mana >= action.ManaCost
				then Color3.fromRGB(160, 175, 255)
				else Color3.fromRGB(255, 90, 90)
		end
	end
end

-- Recargas
RunService.RenderStepped:Connect(function()
	if not gui.Enabled then
		return
	end
	local now = os.clock()
	for _, action in orderedActions do
		local remaining = action.ReadyAt - now
		local cooling = remaining > 0 and action.Cooldown >= 1
		action.Overlay.Visible = cooling
		action.CooldownText.Visible = cooling
		if cooling then
			action.Overlay.Size = UDim2.fromScale(1, remaining / action.Cooldown)
			action.CooldownText.Text = string.format("%.1f", remaining)
		end
	end
end)

--------------------------------------------------------------------------------
-- Actualizar con los atributos que pone el servidor
--------------------------------------------------------------------------------

local lastGold = nil

local function refresh()
	local raceId = getRaceId()
	local race = Config.Races[raceId]
	local rarity = Config.Rarities[race.Rarity]
	local level = player:GetAttribute("Level") or 1
	local xp = player:GetAttribute("XP") or 0
	local needed = player:GetAttribute("XPNeeded") or Config.XPToNextLevel(level)
	local skills = getSkills()

	-- Tarjeta
	rarityPill.BackgroundColor3 = rarity.Color
	rarityText.Text = string.upper(race.Name) .. "  ·  " .. rarity.Name
	cardStroke.Color = rarity.Color
	levelText.Text = "Nv. " .. tostring(level)
	nameLabel.Text = player:GetAttribute("Form") or race.Name
	nameLabel.TextColor3 = rarity.Color:Lerp(Colors.White, 0.35)
	xpFill.Size = UDim2.fromScale(math.clamp(xp / needed, 0, 1), 1)
	xpText.Text = tostring(xp) .. " / " .. tostring(needed) .. " XP"

	-- Rasgos y habilidades
	local lines = {}
	if race.CanAbsorb then
		table.insert(lines, "<b>HABILIDADES ROBADAS</b>")
		for skillId, skill in Config.Skills do
			if skills[skillId] then
				table.insert(lines, "• " .. skill.DisplayName .. ": " .. skill.Description)
			end
		end
		if #lines == 1 then
			table.insert(lines, "Ninguna todavía. ¡Derrota monstruos y absórbelos!")
		end
	else
		table.insert(lines, "<b>RASGOS DE " .. string.upper(race.Name) .. "</b>")
		for _, trait in race.Traits do
			table.insert(lines, "• " .. trait)
		end
	end
	infoLabel.Text = table.concat(lines, "\n")

	-- Botones disponibles
	for abilityId in Config.Abilities do
		actions[abilityId].Button.Visible = Config.HasAbility(raceId, abilityId)
	end
	actions.Absorb.Button.Visible = race.CanAbsorb
	actions.Dash.Button.Visible = race.CanAbsorb and skills.Dash == true

	-- Misión
	local questId = player:GetAttribute("QuestId") or ""
	local quest = if questId ~= "" then Config.GetQuest(questId) else nil
	questPanel.Visible = quest ~= nil
	if quest then
		local kills = math.min(player:GetAttribute("QuestKills") or 0, quest.Count)
		local monsterName = Config.Monsters[quest.Monster].DisplayName
		questBarFill.Size = UDim2.fromScale(kills / quest.Count, 1)
		if kills >= quest.Count then
			questBarFill.BackgroundColor3 = Color3.fromRGB(110, 230, 120)
			questLabel.Text = '<font color="#FFD25A"><b>📜 '
				.. quest.Title
				.. "</b></font>\n"
				.. '<font color="#6EE678"><b>✔ ¡Completada!</b></font> Vuelve con '
				.. Config.QuestGiver.Name
				.. " para tu recompensa"
		else
			questBarFill.BackgroundColor3 = Color3.fromRGB(255, 205, 70)
			questLabel.Text = '<font color="#FFD25A"><b>📜 '
				.. quest.Title
				.. "</b></font>\n"
				.. monsterName
				.. ": <b>"
				.. kills
				.. " / "
				.. quest.Count
				.. "</b>"
		end
	end

	-- Oro
	local gold = player:GetAttribute("Gold") or 0
	goldText.Text = tostring(gold)
	if lastGold and gold > lastGold and gui.Enabled then
		popGold(gold - lastGold)
	end
	lastGold = gold
end

player.AttributeChanged:Connect(function(name)
	if FAST_ATTRIBUTES[name] then
		refreshFast()
	else
		refresh()
	end
end)

--------------------------------------------------------------------------------
-- Mensajes: se muestran uno tras otro para que no se pierda ninguno
--------------------------------------------------------------------------------

local messageQueue = {}
local showingMessages = false

local function showMessages()
	showingMessages = true
	while #messageQueue > 0 do
		local message = table.remove(messageQueue, 1)
		local color = message.Color or Colors.White
		notifyLabel.Text = message.Text
		notifyLabel.TextColor3 = color
		notifyStroke.Color = color
		TweenService:Create(notifyGroup, TweenInfo.new(0.15), { GroupTransparency = 0 }):Play()
		task.wait(if #messageQueue > 0 then 1.5 else 3)
		local fade = TweenService:Create(notifyGroup, TweenInfo.new(0.3), { GroupTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
	end
	showingMessages = false
end

notifyRemote.OnClientEvent:Connect(function(text, color)
	table.insert(messageQueue, { Text = text, Color = color })
	if not showingMessages then
		task.spawn(showMessages)
	end
end)

--------------------------------------------------------------------------------
-- Vida
--------------------------------------------------------------------------------

local function onCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid")
	deathLabel.Visible = false

	local function updateHealth()
		local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
		hpFill.Size = UDim2.fromScale(ratio, 1)
		hpText.Text = tostring(math.ceil(humanoid.Health)) .. " / " .. tostring(math.floor(humanoid.MaxHealth))
	end

	local lastHealth = humanoid.Health
	humanoid.HealthChanged:Connect(function(health)
		if health < lastHealth - 0.5 then
			damageFlash.BackgroundTransparency = 0.65
			TweenService:Create(damageFlash, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		end
		lastHealth = health
		updateHealth()
	end)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(updateHealth)
	humanoid.Died:Connect(function()
		deathLabel.Visible = true
	end)
	updateHealth()
end

player.CharacterAdded:Connect(onCharacterAdded)

--------------------------------------------------------------------------------
-- API
--------------------------------------------------------------------------------

function Hud.Init(onMenuPressed)
	menuButton.Activated:Connect(onMenuPressed)
end

function Hud.Show()
	lastGold = nil
	refresh()
	refreshFast()
	gui.Enabled = true
end

function Hud.Hide()
	setSprint(false)
	gui.Enabled = false
	deathLabel.Visible = false
end

return Hud
