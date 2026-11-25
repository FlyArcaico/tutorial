-- Client entry point: on-screen display (HUD), controls and the dash skill.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local attackRemote = remotes:WaitForChild("Attack")
local absorbRemote = remotes:WaitForChild("Absorb")
local notifyRemote = remotes:WaitForChild("Notify")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local DARK = Color3.fromRGB(20, 22, 35)
local WHITE = Color3.new(1, 1, 1)

--------------------------------------------------------------------------------
-- UI helpers
--------------------------------------------------------------------------------

local function create(className, props, parent)
	local instance = Instance.new(className)
	for key, value in props do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local function round(parent, radius)
	create("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local gui = create("ScreenGui", { Name = "SlimeHud", ResetOnSpawn = false }, playerGui)

-- Stats panel (top-left)
local statsPanel = create("Frame", {
	Position = UDim2.fromOffset(16, 16),
	Size = UDim2.fromOffset(260, 96),
	BackgroundColor3 = DARK,
	BackgroundTransparency = 0.25,
}, gui)
round(statsPanel, 10)
create("UIPadding", {
	PaddingLeft = UDim.new(0, 12),
	PaddingRight = UDim.new(0, 12),
	PaddingTop = UDim.new(0, 8),
}, statsPanel)

local formLabel = create("TextLabel", {
	Size = UDim2.new(1, 0, 0, 26),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 20,
	TextColor3 = Color3.fromRGB(140, 210, 255),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Little Slime",
}, statsPanel)

local levelLabel = create("TextLabel", {
	Position = UDim2.fromOffset(0, 26),
	Size = UDim2.new(1, 0, 0, 20),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	TextSize = 16,
	TextColor3 = WHITE,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Level 1",
}, statsPanel)

local xpBar = create("Frame", {
	Position = UDim2.fromOffset(0, 52),
	Size = UDim2.new(1, 0, 0, 22),
	BackgroundColor3 = Color3.fromRGB(45, 48, 70),
}, statsPanel)
round(xpBar, 6)

local xpFill = create("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Color3.fromRGB(90, 200, 255),
}, xpBar)
round(xpFill, 6)

local xpText = create("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextColor3 = WHITE,
	TextStrokeTransparency = 0.5,
	Text = "0 / 60 XP",
	ZIndex = 2,
}, xpBar)

-- Skills panel (under the stats)
local skillsPanel = create("Frame", {
	Position = UDim2.fromOffset(16, 120),
	Size = UDim2.fromOffset(260, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = DARK,
	BackgroundTransparency = 0.25,
}, gui)
round(skillsPanel, 10)
create("UIPadding", {
	PaddingLeft = UDim.new(0, 12),
	PaddingRight = UDim.new(0, 12),
	PaddingTop = UDim.new(0, 8),
	PaddingBottom = UDim.new(0, 10),
}, skillsPanel)

local skillsLabel = create("TextLabel", {
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	TextSize = 14,
	TextColor3 = WHITE,
	TextWrapped = true,
	RichText = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	Text = "",
}, skillsPanel)

-- Messages (top-center)
local notifyLabel = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 20),
	Size = UDim2.new(0.8, 0, 0, 40),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 24,
	TextWrapped = true,
	TextColor3 = WHITE,
	TextStrokeTransparency = 1,
	TextTransparency = 1,
	Text = "",
}, gui)

-- Controls hint (bottom-center)
create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -12),
	Size = UDim2.new(0.6, 0, 0, 20),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	TextSize = 14,
	TextColor3 = WHITE,
	TextStrokeTransparency = 0.4,
	Text = "Click: Attack   |   F: Absorb   |   Q: Dash (after absorbing a wolf)",
}, gui)

-- Action buttons (bottom-right, for mobile and mouse)
local function makeButton(text, color, order)
	local button = create("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16 - (order - 1) * 92, 1, -40),
		Size = UDim2.fromOffset(80, 80),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.15,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = WHITE,
		Text = text,
	}, gui)
	round(button, 40)
	return button
end

local attackButton = makeButton("Attack", Color3.fromRGB(220, 80, 80), 1)
local absorbButton = makeButton("Absorb\n(F)", Color3.fromRGB(70, 150, 230), 2)
local dashButton = makeButton("Dash\n(Q)", Color3.fromRGB(150, 120, 90), 3)
dashButton.Visible = false

-- Red flash when you take damage
local damageFlash = create("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(255, 0, 0),
	BackgroundTransparency = 1,
	ZIndex = 0,
}, gui)

--------------------------------------------------------------------------------
-- Updating the HUD from the attributes the server sets
--------------------------------------------------------------------------------

local function getSkills()
	local skills = {}
	local text = player:GetAttribute("Skills") or ""
	for skillId in string.gmatch(text, "[^,]+") do
		skills[skillId] = true
	end
	return skills
end

local function refresh()
	local level = player:GetAttribute("Level") or 1
	local xp = player:GetAttribute("XP") or 0
	local needed = player:GetAttribute("XPNeeded") or Config.XPToNextLevel(level)

	formLabel.Text = player:GetAttribute("Form") or "Little Slime"
	levelLabel.Text = "Level " .. tostring(level)
	xpFill.Size = UDim2.fromScale(math.clamp(xp / needed, 0, 1), 1)
	xpText.Text = tostring(xp) .. " / " .. tostring(needed) .. " XP"

	local skills = getSkills()
	local lines = { "<b>Skills</b>" }
	for skillId, skill in Config.Skills do
		if skills[skillId] then
			table.insert(lines, "• " .. skill.DisplayName .. ": " .. skill.Description)
		end
	end
	if #lines == 1 then
		table.insert(lines, "None yet. Defeat monsters and absorb them!")
	end
	skillsLabel.Text = table.concat(lines, "\n")

	dashButton.Visible = skills.Dash == true
end

player.AttributeChanged:Connect(refresh)
refresh()

--------------------------------------------------------------------------------
-- Messages: shown one after another so none get lost
--------------------------------------------------------------------------------

local messageQueue = {}
local showingMessages = false

local function showMessages()
	showingMessages = true
	while #messageQueue > 0 do
		local message = table.remove(messageQueue, 1)
		notifyLabel.Text = message.Text
		notifyLabel.TextColor3 = message.Color or WHITE
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
-- Actions
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
	absorbRemote:FireServer()
end

local dashReadyAt = 0
local function dash()
	if not getSkills().Dash then
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
	if gameProcessed then
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
-- Damage flash
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
if player.Character then
	task.spawn(onCharacterAdded, player.Character)
end
