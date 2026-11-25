-- Builds the map with code, so you don't need to build anything in Studio.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

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

	-- Spawn area
	if not Workspace:FindFirstChildOfClass("SpawnLocation") then
		local spawnLocation = Instance.new("SpawnLocation")
		spawnLocation.Anchored = true
		spawnLocation.Size = Vector3.new(14, 1, 14)
		spawnLocation.Position = Vector3.new(0, 0, 0)
		spawnLocation.Color = Color3.fromRGB(90, 170, 255)
		spawnLocation.Material = Enum.Material.SmoothPlastic
		spawnLocation.Duration = 3
		spawnLocation.Parent = world
	end

	local crystal = makePart(world, {
		Name = "RebirthCrystal",
		Size = Vector3.new(3, 8, 3),
		CFrame = CFrame.new(16, 5, 6) * CFrame.Angles(0, math.rad(45), math.rad(10)),
		Color = Color3.fromRGB(120, 200, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local light = Instance.new("PointLight")
	light.Color = crystal.Color
	light.Range = 20
	light.Brightness = 2
	light.Parent = crystal

	makeSign(world, Vector3.new(-10, 0, 8), Config.GameName)

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
		local nearSpawn = position.Magnitude < 35
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

	Lighting.ClockTime = 14
	Lighting.Brightness = 2
end

return World
