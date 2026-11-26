-- El pueblo de la zona segura (Willowbrook): fuente en el centro, plaza empedrada,
-- casas decoradas, farolas, bancos, árboles, valla y arco de entrada. Textos en inglés.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Village = {}

local UP = CFrame.Angles(0, 0, math.rad(90)) -- cilindros de pie
local WOOD = Color3.fromRGB(120, 80, 50)
local DARK_WOOD = Color3.fromRGB(75, 50, 32)
local STONE = Color3.fromRGB(150, 145, 135)
local WARM_LIGHT = Color3.fromRGB(255, 200, 130)

local rng = Random.new(2024)

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		p[key] = value
	end
	p.Parent = parent
	return p
end

-- Devuelve una función para crear piezas relativas a "base"
local function builder(parent, base)
	return function(name, size, offset, color, props)
		local settings = { Name = name, Size = size, CFrame = base * offset, Color = color }
		for key, value in props or {} do
			settings[key] = value
		end
		return part(parent, settings)
	end
end

local function light(parentPart, range, brightness)
	local pointLight = Instance.new("PointLight")
	pointLight.Color = WARM_LIGHT
	pointLight.Range = range
	pointLight.Brightness = brightness or 1
	pointLight.Parent = parentPart
	return pointLight
end

-- Cartel de madera con texto por las dos caras
local function signText(signPart, text, size)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0.3
		gui.Parent = signPart
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Fantasy
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 230, 160)
		label.TextStrokeTransparency = 0.4
		label.Text = text
		label.Parent = gui
		local constraint = Instance.new("UITextSizeConstraint")
		constraint.MaxTextSize = size or 80
		constraint.Parent = label
	end
end

--------------------------------------------------------------------------------
-- Fuente con estatua de slime
--------------------------------------------------------------------------------

local function buildFountain(parent)
	local piece = builder(parent, CFrame.new(Config.SafeZone.Center))
	local water = Color3.fromRGB(70, 160, 225)

	piece("BasinBase", Vector3.new(1.4, 15, 15), CFrame.new(0, 0.7, 0) * UP, STONE, {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Cobblestone,
	})
	piece("BasinRim", Vector3.new(0.35, 15.6, 15.6), CFrame.new(0, 1.5, 0) * UP, Color3.fromRGB(175, 170, 160), {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Marble,
	})
	piece("Water", Vector3.new(0.3, 13.4, 13.4), CFrame.new(0, 1.55, 0) * UP, water, {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Glass,
		Transparency = 0.25,
		Reflectance = 0.2,
		CanCollide = false,
	})
	piece("Pillar", Vector3.new(3.2, 1.8, 1.8), CFrame.new(0, 3, 0) * UP, Color3.fromRGB(185, 180, 170), {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Marble,
	})
	piece("UpperBowl", Vector3.new(0.7, 6, 6), CFrame.new(0, 4.7, 0) * UP, Color3.fromRGB(185, 180, 170), {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Marble,
	})
	local upperWater = piece("UpperWater", Vector3.new(0.2, 5.2, 5.2), CFrame.new(0, 5.05, 0) * UP, water, {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Glass,
		Transparency = 0.2,
		CanCollide = false,
	})
	piece("Pedestal", Vector3.new(1.4, 1.2, 1.2), CFrame.new(0, 5.7, 0) * UP, Color3.fromRGB(185, 180, 170), {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Marble,
	})

	-- Estatua de un slime en lo alto
	local statueColor = Color3.fromRGB(120, 180, 230)
	local statue = piece("SlimeStatue", Vector3.new(2.6, 2.1, 2.6), CFrame.new(0, 7.4, 0), statueColor, {
		Material = Enum.Material.Marble,
	})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = statue
	for _, side in { -1, 1 } do
		piece(
			"StatueEye",
			Vector3.new(0.35, 0.08, 0.08),
			CFrame.new(side * 0.45, 7.55, -1.28),
			Color3.fromRGB(40, 60, 90)
		)
	end

	-- Chorros de agua cayendo
	local spray = Instance.new("ParticleEmitter")
	spray.Color = ColorSequence.new(Color3.fromRGB(190, 230, 255))
	spray.Transparency = NumberSequence.new(0.2, 1)
	spray.Size = NumberSequence.new(0.35, 0.15)
	spray.Rate = 70
	spray.Lifetime = NumberRange.new(0.9, 1.2)
	spray.Speed = NumberRange.new(7, 9)
	spray.SpreadAngle = Vector2.new(30, 30)
	spray.Acceleration = Vector3.new(0, -28, 0)
	spray.EmissionDirection = Enum.NormalId.Right -- hacia arriba (cilindro girado)
	spray.Parent = upperWater
end

--------------------------------------------------------------------------------
-- Plaza, farolas, bancos y flores
--------------------------------------------------------------------------------

local function lampPost(parent, position)
	local piece = builder(parent, CFrame.new(position))
	piece("LampPole", Vector3.new(0.45, 7, 0.45), CFrame.new(0, 3.5, 0), Color3.fromRGB(35, 35, 40), {
		Material = Enum.Material.Metal,
	})
	piece("LampBase", Vector3.new(1, 0.6, 1), CFrame.new(0, 0.3, 0), Color3.fromRGB(35, 35, 40), {
		Material = Enum.Material.Metal,
	})
	piece("LampCap", Vector3.new(1.3, 0.3, 1.3), CFrame.new(0, 7.9, 0), Color3.fromRGB(35, 35, 40), {
		Material = Enum.Material.Metal,
	})
	local lantern = piece("Lantern", Vector3.new(0.9, 1.1, 0.9), CFrame.new(0, 7.2, 0), Color3.fromRGB(255, 220, 150), {
		Material = Enum.Material.Neon,
		Transparency = 0.15,
	})
	light(lantern, 20, 1.2)
end

local function bench(parent, base)
	local piece = builder(parent, base)
	piece("Seat", Vector3.new(4, 0.3, 1.3), CFrame.new(0, 1.2, 0), WOOD, { Material = Enum.Material.WoodPlanks })
	piece("Back", Vector3.new(4, 1.2, 0.25), CFrame.new(0, 2, 0.55), WOOD, { Material = Enum.Material.WoodPlanks })
	for _, x in { -1.7, 1.7 } do
		piece("Leg", Vector3.new(0.3, 1.2, 1.2), CFrame.new(x, 0.6, 0), Color3.fromRGB(40, 40, 45), {
			Material = Enum.Material.Metal,
		})
	end
end

local FLOWER_COLORS = {
	Color3.fromRGB(240, 80, 110),
	Color3.fromRGB(255, 200, 70),
	Color3.fromRGB(200, 120, 255),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(255, 140, 60),
}

local function flowerBed(parent, base, width)
	local piece = builder(parent, base)
	piece("Planter", Vector3.new(width, 0.8, 1.6), CFrame.new(0, 0.4, 0), Color3.fromRGB(150, 80, 60), {
		Material = Enum.Material.Brick,
	})
	piece("Soil", Vector3.new(width - 0.3, 0.1, 1.3), CFrame.new(0, 0.82, 0), Color3.fromRGB(80, 55, 35), {
		Material = Enum.Material.Ground,
	})
	for index = 1, math.floor(width * 1.5) do
		piece(
			"Flower",
			Vector3.one * rng:NextNumber(0.45, 0.7),
			CFrame.new(rng:NextNumber(-width / 2 + 0.4, width / 2 - 0.4), 1.1, rng:NextNumber(-0.45, 0.45)),
			FLOWER_COLORS[(index % #FLOWER_COLORS) + 1],
			{ Shape = Enum.PartType.Ball }
		)
	end
end

local function buildPlaza(parent)
	local center = Config.SafeZone.Center
	local piece = builder(parent, CFrame.new(center))

	piece("PlazaEdge", Vector3.new(0.25, 44, 44), CFrame.new(0, 0.02, 0) * UP, Color3.fromRGB(110, 105, 100), {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Cobblestone,
	})
	piece("Plaza", Vector3.new(0.3, 41, 41), CFrame.new(0, 0.06, 0) * UP, STONE, {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Cobblestone,
	})
	-- Caminos de piedra hacia las salidas norte y sur
	piece(
		"NorthRoad",
		Vector3.new(9, 0.3, 42),
		CFrame.new(0, 0.05, -40),
		STONE,
		{ Material = Enum.Material.Cobblestone }
	)
	piece(
		"SouthRoad",
		Vector3.new(9, 0.3, 24),
		CFrame.new(0, 0.05, 32),
		STONE,
		{ Material = Enum.Material.Cobblestone }
	)

	-- Farolas alrededor de la plaza
	for index = 1, 8 do
		local angle = (index - 0.5) / 8 * math.pi * 2
		lampPost(parent, center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 22)
	end

	-- Bancos y jardineras alrededor de la fuente
	for index = 1, 4 do
		local angle = (index - 1) / 4 * math.pi * 2 + math.pi / 4
		local position = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 12
		-- El banco mira a la fuente
		bench(parent, CFrame.lookAt(position, Vector3.new(center.X, position.Y, center.Z)))
		local bedAngle = angle + math.pi / 4
		local bedPosition = center + Vector3.new(math.cos(bedAngle), 0, math.sin(bedAngle)) * 10.5
		flowerBed(parent, CFrame.lookAt(bedPosition, Vector3.new(center.X, bedPosition.Y, center.Z)), 3.5)
	end
end

--------------------------------------------------------------------------------
-- Casas
--------------------------------------------------------------------------------

local WALL_COLORS = {
	Color3.fromRGB(235, 225, 200),
	Color3.fromRGB(245, 240, 230),
	Color3.fromRGB(230, 210, 170),
	Color3.fromRGB(220, 200, 185),
}
local ROOF_COLORS = {
	Color3.fromRGB(150, 60, 45),
	Color3.fromRGB(70, 85, 110),
	Color3.fromRGB(90, 110, 60),
	Color3.fromRGB(160, 95, 50),
}

local function house(parent, position, variant)
	local center = Config.SafeZone.Center
	local base = CFrame.lookAt(position, Vector3.new(center.X, position.Y, center.Z)) -- la puerta mira a la fuente
	local model = Instance.new("Model")
	model.Name = "House"
	model.Parent = parent
	local piece = builder(model, base)

	local wall = WALL_COLORS[(variant % #WALL_COLORS) + 1]
	local roof = ROOF_COLORS[(variant % #ROOF_COLORS) + 1]
	local width, depth, height = 11, 9, 7

	piece("Foundation", Vector3.new(width + 1, 1, depth + 1), CFrame.new(0, 0.5, 0), STONE, {
		Material = Enum.Material.Cobblestone,
	})
	piece("Walls", Vector3.new(width, height, depth), CFrame.new(0, 1 + height / 2, 0), wall, {
		Material = Enum.Material.Plaster,
	})

	-- Entramado de madera
	for _, x in { -width / 2, width / 2 } do
		for _, z in { -depth / 2, depth / 2 } do
			piece("Beam", Vector3.new(0.6, height, 0.6), CFrame.new(x, 1 + height / 2, z), DARK_WOOD, {
				Material = Enum.Material.Wood,
			})
		end
	end
	for _, y in { 1.2, 1 + height / 2, 1 + height - 0.2 } do
		piece("FrontBeam", Vector3.new(width + 0.2, 0.4, 0.3), CFrame.new(0, y, -depth / 2 - 0.05), DARK_WOOD, {
			Material = Enum.Material.Wood,
		})
	end

	-- Tejado a dos aguas: un prisma del color de la pared y dos faldones encima
	local top = 1 + height
	piece(
		"Gable",
		Vector3.new(width - 0.2, 6.4, 6.4),
		CFrame.new(0, top, 0) * CFrame.Angles(math.rad(45), 0, 0),
		wall,
		{
			Material = Enum.Material.Plaster,
		}
	)
	local slope = math.rad(45)
	for _, side in { -1, 1 } do
		piece(
			"Roof",
			Vector3.new(width + 1.6, 0.5, 7.4),
			CFrame.new(0, top + 2.5, side * 2.45) * CFrame.Angles(side * slope, 0, 0),
			roof,
			{ Material = Enum.Material.Slate }
		)
	end
	piece("Ridge", Vector3.new(width + 1.8, 0.5, 0.6), CFrame.new(0, top + 4.5, 0), roof:Lerp(Color3.new(), 0.3), {
		Material = Enum.Material.Slate,
	})
	piece("Chimney", Vector3.new(1.4, 4, 1.4), CFrame.new(width / 2 - 2, top + 3.4, 1.8), Color3.fromRGB(140, 75, 60), {
		Material = Enum.Material.Brick,
	})

	-- Puerta, escalón y farolillo
	piece(
		"Door",
		Vector3.new(2.4, 4, 0.3),
		CFrame.new(0, 3, -depth / 2 - 0.1),
		DARK_WOOD,
		{ Material = Enum.Material.WoodPlanks }
	)
	piece("Knob", Vector3.one * 0.25, CFrame.new(0.8, 3, -depth / 2 - 0.3), Color3.fromRGB(220, 180, 80), {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Metal,
	})
	piece(
		"Step",
		Vector3.new(3.2, 0.4, 1.2),
		CFrame.new(0, 0.2, -depth / 2 - 1),
		STONE,
		{ Material = Enum.Material.Slate }
	)
	local doorLamp = piece(
		"DoorLamp",
		Vector3.new(0.5, 0.7, 0.5),
		CFrame.new(1.8, 5.4, -depth / 2 - 0.4),
		Color3.fromRGB(255, 220, 150),
		{
			Material = Enum.Material.Neon,
		}
	)
	light(doorLamp, 10, 0.8)

	-- Ventanas con luz cálida y jardineras
	for _, x in { -3.3, 3.3 } do
		piece("WindowFrame", Vector3.new(2.2, 2.2, 0.25), CFrame.new(x, 4.8, -depth / 2 - 0.05), DARK_WOOD, {
			Material = Enum.Material.Wood,
		})
		local glass = piece(
			"Window",
			Vector3.new(1.8, 1.8, 0.2),
			CFrame.new(x, 4.8, -depth / 2 - 0.12),
			Color3.fromRGB(255, 225, 160),
			{
				Material = Enum.Material.Neon,
				Transparency = 0.35,
			}
		)
		if x > 0 then
			light(glass, 8, 0.5)
		end
		piece("Cross", Vector3.new(0.12, 1.8, 0.1), CFrame.new(x, 4.8, -depth / 2 - 0.25), DARK_WOOD)
		piece("CrossH", Vector3.new(1.8, 0.12, 0.1), CFrame.new(x, 4.8, -depth / 2 - 0.25), DARK_WOOD)
		piece("FlowerBox", Vector3.new(2.2, 0.4, 0.6), CFrame.new(x, 3.55, -depth / 2 - 0.4), WOOD)
		for index = 0, 3 do
			piece(
				"BoxFlower",
				Vector3.one * 0.4,
				CFrame.new(x - 0.75 + index * 0.5, 3.9, -depth / 2 - 0.4),
				FLOWER_COLORS[((index + variant) % #FLOWER_COLORS) + 1],
				{ Shape = Enum.PartType.Ball }
			)
		end
	end

	-- Algo de decoración al lado: barril o cajas
	if variant % 2 == 0 then
		piece("Barrel", Vector3.new(1.8, 1.5, 1.5), CFrame.new(width / 2 + 1.2, 0.9, -2) * UP, WOOD, {
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Wood,
		})
	else
		piece("Crate", Vector3.one * 1.6, CFrame.new(-width / 2 - 1.2, 0.8, -2), Color3.fromRGB(160, 120, 75), {
			Material = Enum.Material.WoodPlanks,
		})
		piece(
			"Crate",
			Vector3.one * 1.1,
			CFrame.new(-width / 2 - 1.1, 2.15, -2.1) * CFrame.Angles(0, 0.4, 0),
			Color3.fromRGB(160, 120, 75),
			{
				Material = Enum.Material.WoodPlanks,
			}
		)
	end
end

--------------------------------------------------------------------------------
-- Árboles, valla y arco de entrada
--------------------------------------------------------------------------------

local function tree(parent, position)
	local piece = builder(parent, CFrame.new(position))
	local height = rng:NextNumber(7, 10)
	piece("Trunk", Vector3.new(height, 1.6, 1.6), CFrame.new(0, height / 2, 0) * UP, Color3.fromRGB(100, 70, 45), {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Wood,
	})
	for index = 1, 3 do
		piece(
			"Leaves",
			Vector3.one * rng:NextNumber(5, 7),
			CFrame.new(rng:NextNumber(-1.2, 1.2), height + index * 0.8, rng:NextNumber(-1.2, 1.2)),
			Color3.fromRGB(60, rng:NextInteger(120, 160), 60),
			{ Shape = Enum.PartType.Ball, Material = Enum.Material.Grass }
		)
	end
end

local function buildFence(parent)
	local safe = Config.SafeZone
	local radius = safe.Radius - 2
	local segments = 72
	for index = 1, segments do
		local a1 = (index - 1) / segments * math.pi * 2
		local a2 = index / segments * math.pi * 2
		local p1 = safe.Center + Vector3.new(math.cos(a1), 0, math.sin(a1)) * radius
		local p2 = safe.Center + Vector3.new(math.cos(a2), 0, math.sin(a2)) * radius
		local middle = (p1 + p2) / 2
		-- Huecos para las entradas norte y sur (por donde pasan los caminos)
		if math.abs(middle.X - safe.Center.X) > 6 then
			local length = (p2 - p1).Magnitude
			local base = CFrame.lookAt(middle, p2)
			local piece = builder(parent, base)
			piece(
				"FencePost",
				Vector3.new(0.5, 3, 0.5),
				CFrame.new(0, 1.5, length / 2),
				DARK_WOOD,
				{ Material = Enum.Material.Wood }
			)
			for _, y in { 1, 2.2 } do
				piece(
					"FenceRail",
					Vector3.new(0.25, 0.3, length),
					CFrame.new(0, y, 0),
					WOOD,
					{ Material = Enum.Material.Wood }
				)
			end
		end
	end
end

local function gateArch(parent, z, text)
	local base = CFrame.new(Config.SafeZone.Center + Vector3.new(0, 0, z))
	local piece = builder(parent, base)
	for _, x in { -6, 6 } do
		piece("GatePost", Vector3.new(1.2, 10, 1.2), CFrame.new(x, 5, 0), DARK_WOOD, { Material = Enum.Material.Wood })
		local torch =
			piece("Torch", Vector3.new(0.5, 0.8, 0.5), CFrame.new(x, 8.5, -0.8), Color3.fromRGB(255, 170, 80), {
				Material = Enum.Material.Neon,
			})
		local fire = Instance.new("Fire")
		fire.Size = 2
		fire.Heat = 4
		fire.Parent = torch
		light(torch, 14, 1)
	end
	piece("GateBeam", Vector3.new(14, 1, 1.2), CFrame.new(0, 10.2, 0), DARK_WOOD, { Material = Enum.Material.Wood })
	local sign = piece(
		"GateSign",
		Vector3.new(10, 2.2, 0.4),
		CFrame.new(0, 8.6, 0),
		WOOD,
		{ Material = Enum.Material.WoodPlanks }
	)
	signText(sign, text, 70)
end

local function signPost(parent, position, text)
	local piece = builder(parent, CFrame.new(position))
	piece("SignPole", Vector3.new(0.4, 5, 0.4), CFrame.new(0, 2.5, 0), DARK_WOOD, { Material = Enum.Material.Wood })
	local board = piece(
		"SignBoard",
		Vector3.new(4.5, 1.6, 0.25),
		CFrame.new(0, 4.3, 0),
		WOOD,
		{ Material = Enum.Material.WoodPlanks }
	)
	signText(board, text, 40)
end

--------------------------------------------------------------------------------
-- Construir el pueblo
--------------------------------------------------------------------------------

function Village.Build(parent)
	local folder = Instance.new("Folder")
	folder.Name = "Village"
	folder.Parent = parent
	local center = Config.SafeZone.Center

	buildPlaza(folder)
	buildFountain(folder)

	-- Casas alrededor de la plaza (dejando libres los caminos y las tiendas)
	local housePositions = {
		Vector3.new(-44, 0, -20),
		Vector3.new(-46, 0, 20),
		Vector3.new(-22, 0, 44),
		Vector3.new(22, 0, 44),
		Vector3.new(46, 0, 20),
		Vector3.new(44, 0, -20),
		Vector3.new(-24, 0, -44),
		Vector3.new(24, 0, -44),
	}
	for index, position in housePositions do
		house(folder, center + position, index)
	end

	-- Árboles entre las casas
	for _, position in
		{
			Vector3.new(-36, 0, -36),
			Vector3.new(36, 0, -36),
			Vector3.new(-50, 0, 0),
			Vector3.new(50, 0, 0),
			Vector3.new(-38, 0, 38),
			Vector3.new(38, 0, 38),
			Vector3.new(-10, 0, 50),
			Vector3.new(10, 0, 52),
		}
	do
		tree(folder, center + position)
	end

	buildFence(folder)
	gateArch(folder, -(Config.SafeZone.Radius - 2), "Willowbrook Village")
	gateArch(folder, Config.SafeZone.Radius - 2, "Willowbrook")
	signPost(folder, center + Vector3.new(7, 0, -26), "↑ Whispering Meadow")
	signPost(folder, center + Vector3.new(-7, 0, -52), "Safe Zone\nNo monsters inside")
end

return Village
