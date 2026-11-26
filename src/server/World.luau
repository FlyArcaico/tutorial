-- Builds the map with code, so you don't need to build anything in Studio.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Shops = require(script.Parent.Shops)
local Village = require(script.Parent.Village)

local World = {}

local function makePart(parent, props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		part[key] = value
	end
	part.Parent = parent
	return part
end

local function makeSign(parent, position, text)
	local post = makePart(parent, {
		Name = "Sign",
		Size = Vector3.new(1, 8, 1),
		Position = position + Vector3.new(0, 4, 0),
		Color = Color3.fromRGB(110, 75, 45),
		Material = Enum.Material.Wood,
	})

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(220, 60)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.MaxDistance = 150
	billboard.Parent = post

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Parent = billboard
end

local function makeTree(parent, position, rng)
	local height = rng:NextNumber(8, 14)
	makePart(parent, {
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 2, 2),
		CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(110, 75, 45),
		Material = Enum.Material.Wood,
	})
	makePart(parent, {
		Name = "Leaves",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * rng:NextNumber(8, 12),
		Position = position + Vector3.new(0, height + 2, 0),
		Color = Color3.fromRGB(60, rng:NextInteger(125, 155), 60),
		Material = Enum.Material.Grass,
	})
end

local function makeRock(parent, position, rng)
	local size = rng:NextNumber(4, 10)
	makePart(parent, {
		Name = "Rock",
		Size = Vector3.new(size, size * rng:NextNumber(0.5, 1), size * rng:NextNumber(0.7, 1.2)),
		CFrame = CFrame.new(position + Vector3.new(0, size * 0.3, 0))
			* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.3, 0.3)),
		Color = Color3.fromRGB(120, 118, 112),
		Material = Enum.Material.Slate,
	})
end

local function isInsideAnyZone(position, margin)
	for _, zone in Config.Zones do
		if (position - zone.Center).Magnitude < zone.Radius - margin then
			return true
		end
	end
	return false
end

-- NPC de misiones: un sabio con túnica, barba y bastón
function World.BuildQuestGiver(parent)
	local giver = Config.QuestGiver
	local model = Instance.new("Model")
	model.Name = giver.Name

	-- Mirando hacia el spawn
	local base = CFrame.lookAt(giver.Position, Vector3.new(0, giver.Position.Y, 0))
	local function piece(name, size, offset, color, props)
		local part = makePart(model, {
			Name = name,
			Size = size,
			CFrame = base * offset,
			Color = color,
			Material = Enum.Material.SmoothPlastic,
		})
		for key, value in props or {} do
			part[key] = value
		end
		return part
	end

	local skin = Color3.fromRGB(230, 185, 150)
	local robe = Color3.fromRGB(70, 50, 120)
	local trim = Color3.fromRGB(255, 200, 70)
	local beard = Color3.fromRGB(235, 235, 235)

	piece("Robe", Vector3.new(2.4, 3.6, 1.4), CFrame.new(0, 1.8, 0), robe, { Material = Enum.Material.Fabric })
	piece("RobeTrim", Vector3.new(2.45, 0.3, 1.45), CFrame.new(0, 0.2, 0), trim)
	local torso = piece("Torso", Vector3.new(2, 2, 1), CFrame.new(0, 4, 0), robe, { Material = Enum.Material.Fabric })
	piece("Belt", Vector3.new(2.05, 0.3, 1.05), CFrame.new(0, 3.2, 0), trim)
	for _, side in { -1, 1 } do
		piece("Arm", Vector3.new(1, 2, 1), CFrame.new(side * 1.5, 4, 0), robe, { Material = Enum.Material.Fabric })
		piece("Hand", Vector3.new(0.9, 0.5, 0.9), CFrame.new(side * 1.5, 2.8, 0), skin)
		piece("Eye", Vector3.new(0.15, 0.22, 0.05), CFrame.new(side * 0.25, 5.75, -0.62), Color3.new())
	end
	piece("Head", Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 5.6, 0), skin)
	piece("Beard", Vector3.new(1, 1.1, 0.3), CFrame.new(0, 5, -0.6), beard)
	piece("Hat", Vector3.new(1.5, 0.3, 1.5), CFrame.new(0, 6.3, 0), robe)
	piece("HatTop", Vector3.new(1, 1, 1), CFrame.new(0, 6.9, 0.1) * CFrame.Angles(math.rad(-10), 0, 0), robe)
	piece("HatTip", Vector3.new(0.5, 0.6, 0.5), CFrame.new(0, 7.6, 0.25) * CFrame.Angles(math.rad(-20), 0, 0), robe)

	-- Bastón con orbe brillante
	piece(
		"Staff",
		Vector3.new(6.5, 0.35, 0.35),
		CFrame.new(2.2, 3.2, -0.3) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(110, 75, 45),
		{ Shape = Enum.PartType.Cylinder, Material = Enum.Material.Wood }
	)
	local orb = piece(
		"Orb",
		Vector3.one * 0.9,
		CFrame.new(2.2, 6.6, -0.3),
		Color3.fromRGB(120, 220, 255),
		{ Shape = Enum.PartType.Ball, Material = Enum.Material.Neon }
	)
	local light = Instance.new("PointLight")
	light.Color = orb.Color
	light.Range = 12
	light.Parent = orb

	-- Nombre y "!" encima
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 60)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.MaxDistance = 80
	billboard.Parent = torso

	local mark = Instance.new("TextLabel")
	mark.Size = UDim2.new(1, 0, 0, 34)
	mark.BackgroundTransparency = 1
	mark.Font = Enum.Font.GothamBlack
	mark.TextSize = 34
	mark.TextColor3 = Color3.fromRGB(255, 210, 60)
	mark.TextStrokeTransparency = 0.2
	mark.Text = "!"
	mark.Parent = billboard

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Position = UDim2.fromOffset(0, 34)
	nameLabel.Size = UDim2.new(1, 0, 0, 22)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 18
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextStrokeTransparency = 0.2
	nameLabel.Text = giver.Name .. " · Quests"
	nameLabel.Parent = billboard

	-- Pulsa T para hablar (la E ya se usa para las habilidades)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "QuestPrompt"
	prompt.ActionText = "Talk"
	prompt.ObjectText = giver.Name
	prompt.KeyboardKeyCode = Enum.KeyCode.T
	prompt.MaxActivationDistance = giver.TalkDistance
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = torso

	model.PrimaryPart = torso
	model.Parent = parent
end

function World.Build()
	-- Remove the default baseplate if the place has one, we make our own ground.
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end

	local world = Instance.new("Folder")
	world.Name = "World"

	makePart(world, {
		Name = "Ground",
		Size = Vector3.new(800, 4, 800),
		Position = Vector3.new(0, -2, -200),
		Color = Color3.fromRGB(95, 160, 75),
		Material = Enum.Material.Grass,
	})

	makePart(world, {
		Name = "Path",
		Size = Vector3.new(12, 1, 460),
		Position = Vector3.new(0, -0.45, -210),
		Color = Color3.fromRGB(150, 120, 85),
		Material = Enum.Material.Ground,
	})

	local hills = Config.Zones[2]
	makePart(world, {
		Name = "StoneGround",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, (hills.Radius + 30) * 2, (hills.Radius + 30) * 2),
		CFrame = CFrame.new(hills.Center + Vector3.new(0, -0.4, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(140, 135, 125),
		Material = Enum.Material.Slate,
	})

	-- Punto de aparición: en el camino sur del pueblo, mirando a la fuente (invisible)
	for _, old in Workspace:GetDescendants() do
		if old:IsA("SpawnLocation") then
			old:Destroy()
		end
	end
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(8, 0.2, 8)
	spawnLocation.CFrame = CFrame.lookAt(Vector3.new(0, 0.2, 30), Vector3.new(0, 0.2, 0))
	spawnLocation.Transparency = 1
	spawnLocation.CanCollide = false
	spawnLocation.Duration = 0
	spawnLocation.Parent = world
	local decal = spawnLocation:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end

	-- Pueblo (zona segura), NPC de misiones y tiendas
	Village.Build(world)
	World.BuildQuestGiver(world)
	Shops.Build(world)

	-- Zone signs at the edge of each zone, facing the path
	for _, zone in Config.Zones do
		makeSign(world, zone.Center + Vector3.new(10, 0, zone.Radius + 5), zone.Label)
	end

	-- Decoration: same seed every time so the map always looks the same.
	local rng = Random.new(12345)
	local decor = Instance.new("Folder")
	decor.Name = "Decoration"
	decor.Parent = world

	local placed = 0
	while placed < 80 do
		local position = Vector3.new(rng:NextNumber(-250, 250), 0, rng:NextNumber(-500, 80))
		local nearSpawn = position.Magnitude < Config.SafeZone.Radius + 6
		local onPath = math.abs(position.X) < 12
		if not nearSpawn and not onPath and not isInsideAnyZone(position, 10) then
			if position.Z < hills.Center.Z + hills.Radius + 30 then
				makeRock(decor, position, rng)
			else
				makeTree(decor, position, rng)
			end
			placed += 1
		end
	end

	world.Parent = Workspace

	-- Luz de tarde cálida con un poco de neblina para dar ambiente
	Lighting.ClockTime = 15.5
	Lighting.Brightness = 2
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 135, 150)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.28
		atmosphere.Offset = 0.2
		atmosphere.Color = Color3.fromRGB(200, 215, 235)
		atmosphere.Decay = Color3.fromRGB(110, 120, 150)
		atmosphere.Haze = 1.2
		atmosphere.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("ColorCorrectionEffect") then
		local correction = Instance.new("ColorCorrectionEffect")
		correction.Saturation = 0.12
		correction.Contrast = 0.05
		correction.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("BloomEffect") then
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.4
		bloom.Size = 20
		bloom.Threshold = 1.6
		bloom.Parent = Lighting
	end
end

return World
