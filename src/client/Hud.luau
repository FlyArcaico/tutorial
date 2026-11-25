-- HUD del juego: nivel, XP, habilidades, mensajes, botones y controles.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UI = require(script.Parent.UI)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local attackRemote = remotes:WaitForChild("Attack")
local absorbRemote = remotes:WaitForChild("Absorb")
local notifyRemote = remotes:WaitForChild("Notify")

local player = Players.LocalPlayer
local Colors = UI.Colors
local create = UI.create

local Hud = {}

local gui =
	create("ScreenGui", { Name = "Hud", ResetOnSpawn = false, Enabled = false }, player:WaitForChild("PlayerGui"))

--------------------------------------------------------------------------------
-- Elementos
--------------------------------------------------------------------------------

-- Panel de estadísticas (arriba a la izquierda)
local statsPanel = create("Frame", {
	Position = UDim2.fromOffset(16, 16),
	Size = UDim2.fromOffset(260, 96),
	BackgroundColor3 = Colors.Dark,
	BackgroundTransparency = 0.25,
}, gui)
UI.round(statsPanel, 10)
create("UIPadding", {
	PaddingLeft = UDim.new(0, 12),
	PaddingRight = UDim.new(0, 12),
	PaddingTop = UDim.new(0, 8),
}, statsPanel)

local formLabel = UI.label(statsPanel, {
	Size = UDim2.new(1, 0, 0, 26),
	Font = Enum.Font.GothamBold,
	TextSize = 20,
	TextColor3 = Color3.fromRGB(140, 210, 255),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "",
})

local levelLabel = UI.label(statsPanel, {
	Position = UDim2.fromOffset(0, 26),
	Size = UDim2.new(1, 0, 0, 20),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Nivel 1",
})

local xpBar = create("Frame", {
	Position = UDim2.fromOffset(0, 52),
	Size = UDim2.new(1, 0, 0, 22),
	BackgroundColor3 = Colors.PanelLight,
}, statsPanel)
UI.round(xpBar, 6)

local xpFill = create("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Colors.Accent,
}, xpBar)
UI.round(xpFill, 6)

local xpText = UI.label(xpBar, {
	Size = UDim2.fromScale(1, 1),
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextStrokeTransparency = 0.5,
	Text = "",
	ZIndex = 2,
})

-- Panel de habilidades (debajo)
local skillsPanel = create("Frame", {
	Position = UDim2.fromOffset(16, 120),
	Size = UDim2.fromOffset(260, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = Colors.Dark,
	BackgroundTransparency = 0.25,
}, gui)
UI.round(skillsPanel, 10)
create("UIPadding", {
	PaddingLeft = UDim.new(0, 12),
	PaddingRight = UDim.new(0, 12),
	PaddingTop = UDim.new(0, 8),
	PaddingBottom = UDim.new(0, 10),
}, skillsPanel)

local skillsLabel = UI.label(skillsPanel, {
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	TextSize = 14,
	RichText = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	Text = "",
})

-- Botón para volver al menú (abajo a la izquierda)
local menuButton = UI.button(gui, "Menú", Colors.PanelLight, {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 16, 1, -16),
	Size = UDim2.fromOffset(100, 40),
	TextSize = 16,
})

-- Mensajes (arriba en el centro)
local notifyLabel = UI.label(gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 20),
	Size = UDim2.new(0.6, 0, 0, 60),
	Font = Enum.Font.GothamBold,
	TextSize = 22,
	TextStrokeTransparency = 1,
	TextTransparency = 1,
	Text = "",
})

-- Controles (abajo en el centro)
local hintLabel = UI.label(gui, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -12),
	Size = UDim2.new(0.5, 0, 0, 20),
	TextSize = 14,
	TextStrokeTransparency = 0.4,
	Text = "",
})

-- Botones de acción (abajo a la derecha, para móvil y ratón)
local function makeActionButton(text, color, order)
	local button = create("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16 - (order - 1) * 92, 1, -40),
		Size = UDim2.fromOffset(80, 80),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.15,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = Colors.White,
		Text = text,
	}, gui)
	UI.round(button, 40)
	return button
end

local attackButton = makeActionButton("Atacar", Colors.Red, 1)
local absorbButton = makeActionButton("Absorber\n(F)", Color3.fromRGB(70, 150, 230), 2)
local dashButton = makeActionButton("Embestir\n(Q)", Color3.fromRGB(150, 120, 90), 3)

-- Destello rojo al recibir daño
local damageFlash = create("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(255, 0, 0),
	BackgroundTransparency = 1,
	ZIndex = 0,
}, gui)

--------------------------------------------------------------------------------
-- Actualizar con los atributos que pone el servidor
--------------------------------------------------------------------------------

local function getSkills()
	local skills = {}
	for skillId in string.gmatch(player:GetAttribute("Skills") or "", "[^,]+") do
		skills[skillId] = true
	end
	return skills
end

local function getRace()
	return Config.Races[player:GetAttribute("Race") or Config.DefaultRace] or Config.Races[Config.DefaultRace]
end

local function refresh()
	local race = getRace()
	local rarity = Config.Rarities[race.Rarity]
	local level = player:GetAttribute("Level") or 1
	local xp = player:GetAttribute("XP") or 0
	local needed = player:GetAttribute("XPNeeded") or Config.XPToNextLevel(level)

	formLabel.Text = player:GetAttribute("Form") or race.Name
	formLabel.TextColor3 = rarity.Color
	levelLabel.Text = race.Name .. " (" .. rarity.Name .. ")  ·  Nivel " .. tostring(level)
	xpFill.Size = UDim2.fromScale(math.clamp(xp / needed, 0, 1), 1)
	xpText.Text = tostring(xp) .. " / " .. tostring(needed) .. " XP"

	local lines = {}
	local skills = getSkills()
	if race.CanAbsorb then
		table.insert(lines, "<b>Habilidades robadas</b>")
		for skillId, skill in Config.Skills do
			if skills[skillId] then
				table.insert(lines, "• " .. skill.DisplayName .. ": " .. skill.Description)
			end
		end
		if #lines == 1 then
			table.insert(lines, "Ninguna todavía. ¡Derrota monstruos y absórbelos!")
		end
	else
		table.insert(lines, "<b>Rasgos de " .. race.Name .. "</b>")
		for _, trait in race.Traits do
			table.insert(lines, "• " .. trait)
		end
	end
	skillsLabel.Text = table.concat(lines, "\n")

	absorbButton.Visible = race.CanAbsorb
	dashButton.Visible = race.CanAbsorb and skills.Dash == true

	local hint = "Clic: Atacar"
	if race.CanAbsorb then
		hint ..= "   |   F: Absorber"
		if skills.Dash then
			hint ..= "   |   Q: Embestir"
		end
	end
	hintLabel.Text = hint
end

player.AttributeChanged:Connect(refresh)

--------------------------------------------------------------------------------
-- Mensajes: se muestran uno tras otro para que no se pierda ninguno
--------------------------------------------------------------------------------

local messageQueue = {}
local showingMessages = false

local function showMessages()
	showingMessages = true
	while #messageQueue > 0 do
		local message = table.remove(messageQueue, 1)
		notifyLabel.Text = message.Text
		notifyLabel.TextColor3 = message.Color or Colors.White
		notifyLabel.TextTransparency = 0
		notifyLabel.TextStrokeTransparency = 0.3
		task.wait(if #messageQueue > 0 then 1.5 else 3)
		local fade = TweenService:Create(notifyLabel, TweenInfo.new(0.4), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})
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
-- Acciones
--------------------------------------------------------------------------------

local function getAlive()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return humanoid, root
	end
	return nil, nil
end

local function attack()
	attackRemote:FireServer()
end

local function absorb()
	if getRace().CanAbsorb then
		absorbRemote:FireServer()
	end
end

local dashReadyAt = 0
local function dash()
	if not getRace().CanAbsorb or not getSkills().Dash then
		return
	end
	local humanoid, root = getAlive()
	local now = os.clock()
	if not humanoid or now < dashReadyAt then
		return
	end

	local skill = Config.Skills.Dash
	dashReadyAt = now + skill.Cooldown

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

attackButton.Activated:Connect(attack)
absorbButton.Activated:Connect(absorb)
dashButton.Activated:Connect(dash)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not gui.Enabled then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		attack()
	elseif input.KeyCode == Enum.KeyCode.F then
		absorb()
	elseif input.KeyCode == Enum.KeyCode.Q then
		dash()
	end
end)

--------------------------------------------------------------------------------
-- Destello de daño
--------------------------------------------------------------------------------

local function onCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid")
	local lastHealth = humanoid.Health
	humanoid.HealthChanged:Connect(function(health)
		if health < lastHealth - 0.5 then
			damageFlash.BackgroundTransparency = 0.6
			TweenService:Create(damageFlash, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		end
		lastHealth = health
	end)
end

player.CharacterAdded:Connect(onCharacterAdded)

--------------------------------------------------------------------------------
-- API
--------------------------------------------------------------------------------

function Hud.Init(onMenuPressed)
	menuButton.Activated:Connect(onMenuPressed)
end

function Hud.Show()
	refresh()
	gui.Enabled = true
end

function Hud.Hide()
	gui.Enabled = false
end

return Hud
