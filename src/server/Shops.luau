-- Tiendas de la zona segura: Medicina y Herrería. Cada una tiene su puesto, decoración
-- temática y un NPC (pulsa T para comprar).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local Shops = {}

local rng = Random.new(777)

local WOOD = Color3.fromRGB(125, 85, 50)
local DARK_WOOD = Color3.fromRGB(85, 55, 35)

-- Crea una pieza anclada en la posición local "offset" del puesto
local function newBuilder(parent, base)
	return function(name, size, offset, color, props)
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.Size = size
		part.CFrame = base * offset
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		for key, value in props or {} do
			part[key] = value
		end
		part.Parent = parent
		return part
	end
end

local UP = CFrame.Angles(0, 0, math.rad(90)) -- para cilindros de pie

--------------------------------------------------------------------------------
-- Puesto: suelo, paredes, tejado, mostrador y cartel
--------------------------------------------------------------------------------

local function buildStall(piece, shop, roofColor)
	piece(
		"Floor",
		Vector3.new(13, 0.4, 10),
		CFrame.new(0, 0.2, 0.5),
		DARK_WOOD,
		{ Material = Enum.Material.WoodPlanks }
	)
	piece("BackWall", Vector3.new(13, 8, 0.5), CFrame.new(0, 4.2, 5.25), WOOD, { Material = Enum.Material.WoodPlanks })
	for _, side in { -1, 1 } do
		piece("SideWall", Vector3.new(0.5, 8, 6), CFrame.new(side * 6.25, 4.2, 2.5), WOOD, {
			Material = Enum.Material.WoodPlanks,
		})
		piece("Post", Vector3.new(0.7, 8.4, 0.7), CFrame.new(side * 6.2, 4.2, -4.2), DARK_WOOD, {
			Material = Enum.Material.Wood,
		})
	end

	-- Tejado inclinado con toldo de rayas
	piece("Roof", Vector3.new(14, 0.4, 11.5), CFrame.new(0, 8.8, 0.3) * CFrame.Angles(math.rad(-10), 0, 0), roofColor, {
		Material = Enum.Material.Fabric,
	})
	for index = 0, 6 do
		piece(
			"Stripe",
			Vector3.new(1, 0.42, 11.5),
			CFrame.new(-6 + index * 2, 8.82, 0.3) * CFrame.Angles(math.rad(-10), 0, 0),
			Color3.fromRGB(245, 240, 225),
			{ Material = Enum.Material.Fabric }
		)
	end
	for index = 0, 12 do
		piece(
			"Fringe",
			Vector3.new(1, 0.8, 0.15),
			CFrame.new(-6.5 + index * 1.08, 8.1, -5.3),
			if index % 2 == 0 then roofColor else Color3.fromRGB(245, 240, 225),
			{ Material = Enum.Material.Fabric }
		)
	end

	-- Mostrador
	piece("Counter", Vector3.new(9, 3, 1.6), CFrame.new(0, 1.9, -2.4), WOOD, { Material = Enum.Material.WoodPlanks })
	piece(
		"CounterTop",
		Vector3.new(9.6, 0.3, 2),
		CFrame.new(0, 3.5, -2.4),
		DARK_WOOD,
		{ Material = Enum.Material.Wood }
	)

	-- Cartel con el nombre de la tienda
	local sign = piece("Sign", Vector3.new(7.5, 1.8, 0.3), CFrame.new(0, 7.2, -5), DARK_WOOD, {
		Material = Enum.Material.Wood,
	})
	piece("SignFrame", Vector3.new(7.9, 2.2, 0.2), CFrame.new(0, 7.2, -4.92), Color3.fromRGB(220, 180, 80), {
		Material = Enum.Material.Metal,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Fantasy
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 225, 140)
	label.TextStrokeTransparency = 0.3
	label.Text = shop.Icon .. " " .. shop.Title
	label.Parent = gui
end

--------------------------------------------------------------------------------
-- NPC: figura estilo R6 hecha con bloques
--------------------------------------------------------------------------------

local function buildNpc(piece, shop, look)
	local y = 0.4 -- encima del suelo del puesto
	local z = 0.6
	local function at(x, height)
		return CFrame.new(x, y + height, z)
	end

	for _, side in { -1, 1 } do
		piece("Leg", Vector3.new(1, 2, 1), at(side * 0.5, 1), look.Pants)
		piece("Arm", Vector3.new(1, 2, 1), at(side * 1.5, 3), look.Shirt)
		piece("Hand", Vector3.new(0.9, 0.4, 0.9), at(side * 1.5, 1.85), look.Skin)
		piece("Eye", Vector3.new(0.15, 0.22, 0.05), at(side * 0.25, 4.75) * CFrame.new(0, 0, -0.62), Color3.new())
	end
	local torso = piece("Torso", Vector3.new(2, 2, 1), at(0, 3), look.Shirt, { Material = Enum.Material.Fabric })
	piece("Apron", Vector3.new(1.8, 2.6, 0.1), at(0, 2.3) * CFrame.new(0, 0, -0.55), look.Apron, {
		Material = Enum.Material.Fabric,
	})
	piece("Head", Vector3.new(1.2, 1.2, 1.2), at(0, 4.6), look.Skin)
	piece("Hair", Vector3.new(1.3, 0.4, 1.3), at(0, 5.3) * CFrame.new(0, 0, 0.05), look.Hair)
	if look.Beard then
		piece("Beard", Vector3.new(1, 0.7, 0.3), at(0, 4.15) * CFrame.new(0, 0, -0.6), look.Hair)
	end
	if look.Bandana then
		piece("Bandana", Vector3.new(1.35, 0.3, 1.35), at(0, 5.05), look.Bandana, { Material = Enum.Material.Fabric })
	end

	-- Nombre encima
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(220, 56)
	billboard.StudsOffset = Vector3.new(0, 3.6, 0)
	billboard.MaxDistance = 70
	billboard.Parent = torso
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 26)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 20
	title.TextColor3 = shop.Color
	title.TextStrokeTransparency = 0.2
	title.Text = shop.Icon .. " " .. shop.Title
	title.Parent = billboard
	local name = Instance.new("TextLabel")
	name.Position = UDim2.fromOffset(0, 26)
	name.Size = UDim2.new(1, 0, 0, 20)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.TextSize = 15
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.2
	name.Text = shop.Npc
	name.Parent = billboard

	return torso
end

local function addPrompt(torso, shopId, shop)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ActionText = "Shop"
	prompt.ObjectText = shop.Npc
	prompt.KeyboardKeyCode = Enum.KeyCode.T
	prompt.MaxActivationDistance = Config.ShopTalkDistance
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt:SetAttribute("ShopId", shopId)
	prompt.Parent = torso
end

--------------------------------------------------------------------------------
-- Medicina: estantes llenos de pociones, caldero burbujeante y plantas
--------------------------------------------------------------------------------

local POTION_COLORS = {
	Color3.fromRGB(230, 60, 80),
	Color3.fromRGB(255, 110, 190),
	Color3.fromRGB(80, 120, 255),
	Color3.fromRGB(240, 210, 60),
	Color3.fromRGB(90, 220, 120),
}

local function bottle(piece, offset, color, scale)
	local s = scale or 1
	piece("Bottle", Vector3.new(0.8, 0.65, 0.65) * s, offset * UP, color:Lerp(Color3.new(1, 1, 1), 0.5), {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Glass,
		Transparency = 0.35,
	})
	piece("Liquid", Vector3.new(0.55, 0.5, 0.5) * s, offset * CFrame.new(0, -0.08 * s, 0) * UP, color, {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Neon,
	})
	piece(
		"Neck",
		Vector3.new(0.35, 0.25, 0.25) * s,
		offset * CFrame.new(0, 0.55 * s, 0) * UP,
		color:Lerp(Color3.new(1, 1, 1), 0.6),
		{
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Glass,
			Transparency = 0.3,
		}
	)
	piece(
		"Cork",
		Vector3.new(0.15, 0.22, 0.22) * s,
		offset * CFrame.new(0, 0.78 * s, 0) * UP,
		Color3.fromRGB(160, 120, 80),
		{
			Shape = Enum.PartType.Cylinder,
		}
	)
end

local function buildMedicine(piece)
	-- Estantes con pociones en la pared del fondo
	for row, height in { 2.4, 4.2, 6 } do
		piece(
			"Shelf",
			Vector3.new(11, 0.25, 1.2),
			CFrame.new(0, height, 4.4),
			DARK_WOOD,
			{ Material = Enum.Material.Wood }
		)
		for index = 0, 9 do
			local color = POTION_COLORS[(index + row) % #POTION_COLORS + 1]
			bottle(piece, CFrame.new(-4.8 + index * 1.05, height + 0.5, 4.4), color, rng:NextNumber(0.8, 1.1))
		end
	end

	-- Pociones y hierbas sobre el mostrador
	for index, color in POTION_COLORS do
		bottle(piece, CFrame.new(-3.4 + index * 1.1, 4.05, -2.4), color, 0.85)
	end
	piece("Mortar", Vector3.new(0.6, 1, 1), CFrame.new(3.6, 3.95, -2.4) * UP, Color3.fromRGB(150, 150, 140), {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Slate,
	})
	for index = 0, 2 do
		piece(
			"Herb",
			Vector3.one * 0.5,
			CFrame.new(-4 + index * 0.4, 3.9, -2.1),
			Color3.fromRGB(70, 160 + index * 20, 70),
			{
				Shape = Enum.PartType.Ball,
				Material = Enum.Material.Grass,
			}
		)
	end
	-- Hierbas colgando del techo
	for index = 0, 5 do
		piece(
			"HangingHerb",
			Vector3.new(0.35, 1.2, 0.35),
			CFrame.new(-4.5 + index * 1.8, 7.2, 2),
			Color3.fromRGB(80, 150 + index * 8, 70),
			{ Material = Enum.Material.Grass }
		)
	end

	-- Caldero burbujeante al lado
	piece("Cauldron", Vector3.new(2, 2.4, 2.4), CFrame.new(-8.4, 1.3, -1) * UP, Color3.fromRGB(40, 40, 45), {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Metal,
	})
	local brew = piece("Brew", Vector3.new(0.2, 2, 2), CFrame.new(-8.4, 2.35, -1) * UP, Color3.fromRGB(110, 255, 140), {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Neon,
	})
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Color = ColorSequence.new(Color3.fromRGB(160, 255, 180))
	bubbles.LightEmission = 0.8
	bubbles.Size = NumberSequence.new(0.3, 0)
	bubbles.Rate = 8
	bubbles.Lifetime = NumberRange.new(0.8, 1.4)
	bubbles.Speed = NumberRange.new(1, 2)
	bubbles.SpreadAngle = Vector2.new(20, 20)
	bubbles.EmissionDirection = Enum.NormalId.Right -- hacia arriba (el cilindro está girado)
	bubbles.Parent = brew
	local light = Instance.new("PointLight")
	light.Color = brew.Color
	light.Range = 10
	light.Parent = brew

	-- Macetas
	for _, x in { -8.4, 8.4 } do
		piece("Pot", Vector3.new(1.2, 1.4, 1.4), CFrame.new(x, 0.6, 3.5) * UP, Color3.fromRGB(170, 90, 60), {
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Brick,
		})
		piece("Plant", Vector3.one * 2, CFrame.new(x, 2, 3.5), Color3.fromRGB(70, 170, 80), {
			Shape = Enum.PartType.Ball,
			Material = Enum.Material.Grass,
		})
	end
end

--------------------------------------------------------------------------------
-- Herrería: fragua con fuego, yunque, espadas, escudos y armadura
--------------------------------------------------------------------------------

local function displaySword(piece, offset, look)
	piece("RackHandle", Vector3.new(0.25, 1, 0.25), offset * CFrame.new(0, -0.5, 0), look.Handle)
	piece("RackGuard", Vector3.new(1.1, 0.2, 0.25), offset, look.Guard, { Material = Enum.Material.Metal })
	piece(
		"RackBlade",
		Vector3.new(0.38, look.Length, 0.1),
		offset * CFrame.new(0, look.Length / 2 + 0.1, 0),
		look.Blade,
		{
			Material = if look.Glow then Enum.Material.Neon else Enum.Material.Metal,
		}
	)
end

local function buildBlacksmith(piece)
	-- Fragua de ladrillo con fuego y chimenea
	piece("Forge", Vector3.new(4, 4, 3.5), CFrame.new(-4, 2.4, 3), Color3.fromRGB(120, 60, 45), {
		Material = Enum.Material.Brick,
	})
	local embers =
		piece("Embers", Vector3.new(2.6, 1.2, 0.2), CFrame.new(-4, 2.6, 1.24), Color3.fromRGB(255, 120, 30), {
			Material = Enum.Material.Neon,
		})
	local fire = Instance.new("Fire")
	fire.Size = 5
	fire.Heat = 6
	fire.Color = Color3.fromRGB(255, 110, 30)
	fire.SecondaryColor = Color3.fromRGB(255, 220, 90)
	fire.Parent = embers
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 140, 60)
	glow.Range = 16
	glow.Brightness = 2
	glow.Parent = embers
	piece("Chimney", Vector3.new(1.8, 7, 1.8), CFrame.new(-4.5, 8, 3.8), Color3.fromRGB(100, 55, 45), {
		Material = Enum.Material.Brick,
	})

	-- Yunque
	piece("AnvilBase", Vector3.new(1.2, 1.6, 1), CFrame.new(2.4, 1.2, -0.6), Color3.fromRGB(60, 60, 65), {
		Material = Enum.Material.Metal,
	})
	local anvil =
		piece("AnvilTop", Vector3.new(2.4, 0.7, 1.2), CFrame.new(2.4, 2.3, -0.6), Color3.fromRGB(70, 70, 78), {
			Material = Enum.Material.Metal,
		})
	piece("AnvilHorn", Vector3.new(0.8, 0.45, 0.6), CFrame.new(3.9, 2.4, -0.6), Color3.fromRGB(70, 70, 78), {
		Material = Enum.Material.Metal,
	})
	piece("HotBlade", Vector3.new(1.8, 0.1, 0.35), CFrame.new(2.2, 2.7, -0.6), Color3.fromRGB(255, 140, 50), {
		Material = Enum.Material.Neon,
	})

	-- Espadas en la pared (una de cada diseño de la tienda)
	for index, weaponId in Config.WeaponOrder do
		local look = Config.Weapons[weaponId].Look
		displaySword(piece, CFrame.new(-0.4 + index * 1.15, 3.6, 4.8), look)
	end

	-- Escudos redondos en la pared lateral
	local shieldColors = { Color3.fromRGB(150, 40, 40), Color3.fromRGB(40, 80, 160), Color3.fromRGB(60, 120, 60) }
	for index, color in shieldColors do
		local base = CFrame.new(5.9, 2 + index * 1.9, 3.5 - index * 1.4) * CFrame.Angles(0, math.rad(90), 0)
		piece("Shield", Vector3.new(0.25, 1.7, 1.7), base * CFrame.Angles(0, math.rad(90), 0), color, {
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Wood,
		})
		piece(
			"ShieldRim",
			Vector3.new(0.2, 1.85, 1.85),
			base * CFrame.new(0, 0, 0.05) * CFrame.Angles(0, math.rad(90), 0),
			Color3.fromRGB(180, 180, 190),
			{
				Shape = Enum.PartType.Cylinder,
				Material = Enum.Material.Metal,
			}
		)
		piece("ShieldBoss", Vector3.one * 0.5, base * CFrame.new(0, 0, -0.15), Color3.fromRGB(220, 190, 90), {
			Shape = Enum.PartType.Ball,
			Material = Enum.Material.Metal,
		})
	end

	-- Armadura en un maniquí, al lado del puesto
	piece("StandPole", Vector3.new(0.3, 3, 0.3), CFrame.new(8.6, 1.5, 0), DARK_WOOD)
	piece("Breastplate", Vector3.new(2, 2, 1.1), CFrame.new(8.6, 3.6, 0), Color3.fromRGB(170, 175, 185), {
		Material = Enum.Material.Metal,
		Reflectance = 0.1,
	})
	piece("Helmet", Vector3.one * 1.3, CFrame.new(8.6, 5.2, 0), Color3.fromRGB(170, 175, 185), {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Metal,
	})
	piece(
		"Plume",
		Vector3.new(0.3, 0.8, 1),
		CFrame.new(8.6, 6, 0),
		Color3.fromRGB(200, 40, 40),
		{ Material = Enum.Material.Fabric }
	)

	-- Barril con espadas
	piece("Barrel", Vector3.new(2, 1.8, 1.8), CFrame.new(-8.4, 1, -1.5) * UP, DARK_WOOD, {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Wood,
	})
	for index = 1, 3 do
		piece(
			"BarrelSword",
			Vector3.new(0.3, 3, 0.1),
			CFrame.new(-8.8 + index * 0.3, 2.6, -1.5) * CFrame.Angles(0, 0, math.rad(-8 + index * 6)),
			Color3.fromRGB(190, 195, 200),
			{ Material = Enum.Material.Metal }
		)
	end

	return anvil
end

-- El herrero golpea el yunque: el brazo sube y baja y saltan chispas
local function animateBlacksmith(arm, anvil)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 100, 30))
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.18, 0)
	sparks.Lifetime = NumberRange.new(0.3, 0.6)
	sparks.Speed = NumberRange.new(6, 12)
	sparks.SpreadAngle = Vector2.new(70, 70)
	sparks.Acceleration = Vector3.new(0, -30, 0)
	sparks.Rate = 0
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Parent = anvil

	local down = arm.CFrame
	-- Gira desde el hombro (parte de arriba del brazo) hacia delante y arriba
	local up = down * CFrame.new(0, 1, 0) * CFrame.Angles(math.rad(110), 0, 0) * CFrame.new(0, -1, 0)
	task.spawn(function()
		while arm.Parent do
			TweenService:Create(arm, TweenInfo.new(0.45, Enum.EasingStyle.Sine), { CFrame = up }):Play()
			task.wait(0.55)
			TweenService
				:Create(arm, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = down })
				:Play()
			task.wait(0.12)
			sparks:Emit(18)
			task.wait(0.6)
		end
	end)
end

--------------------------------------------------------------------------------
-- Construir todo
--------------------------------------------------------------------------------

function Shops.Build(parent)
	local center = Config.SafeZone.Center

	for shopId, shop in Config.Shops do
		local model = Instance.new("Model")
		model.Name = shop.Title
		-- El puesto mira hacia el centro de la zona segura
		local base = CFrame.lookAt(shop.Position, Vector3.new(center.X, shop.Position.Y, center.Z))
		local piece = newBuilder(model, base)

		if shopId == "Medicine" then
			buildStall(piece, shop, Color3.fromRGB(60, 150, 90))
			buildMedicine(piece)
			local torso = buildNpc(piece, shop, {
				Skin = Color3.fromRGB(240, 205, 175),
				Shirt = Color3.fromRGB(70, 140, 90),
				Pants = Color3.fromRGB(90, 70, 50),
				Apron = Color3.fromRGB(240, 235, 220),
				Hair = Color3.fromRGB(150, 90, 50),
				Bandana = Color3.fromRGB(110, 200, 130),
			})
			-- La herbolaria sujeta una poción
			bottle(piece, CFrame.new(1.5, 2.6, -0.1), Color3.fromRGB(255, 110, 190), 0.8)
			addPrompt(torso, shopId, shop)
		else
			buildStall(piece, shop, Color3.fromRGB(150, 50, 40))
			local anvil = buildBlacksmith(piece)
			local torso = buildNpc(piece, shop, {
				Skin = Color3.fromRGB(200, 150, 115),
				Shirt = Color3.fromRGB(120, 110, 100),
				Pants = Color3.fromRGB(60, 50, 45),
				Apron = Color3.fromRGB(90, 60, 40),
				Hair = Color3.fromRGB(60, 40, 30),
				Beard = true,
			})
			addPrompt(torso, shopId, shop)

			-- Martillo en la mano derecha del herrero
			local arm = nil
			for _, child in model:GetChildren() do
				if child.Name == "Arm" and (base:PointToObjectSpace(child.Position).X > 0) then
					arm = child
				end
			end
			if arm then
				local handle = piece("HammerHandle", Vector3.new(0.25, 1.6, 0.25), CFrame.new(0, 0, 0), DARK_WOOD)
				handle.CFrame = arm.CFrame * CFrame.new(0, -1.3, -0.4) * CFrame.Angles(math.rad(90), 0, 0)
				local head =
					piece("HammerHead", Vector3.new(0.6, 0.6, 1.1), CFrame.new(0, 0, 0), Color3.fromRGB(70, 70, 80), {
						Material = Enum.Material.Metal,
					})
				head.CFrame = handle.CFrame * CFrame.new(0, 0.8, 0)
				-- El martillo sigue al brazo: lo soldamos y desanclamos solo el martillo
				for _, part in { handle, head } do
					part.Anchored = false
					part.CanCollide = false
					part.Massless = true
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = arm
					weld.Part1 = part
					weld.Parent = part
				end
				animateBlacksmith(arm, anvil)
			end
		end

		model.Parent = parent
	end
end

return Shops
