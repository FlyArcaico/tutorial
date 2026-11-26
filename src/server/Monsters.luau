-- Monstruos: aparecen con un nivel según la zona, tienen su propio diseño, barra de vida
-- encima y números de daño. Persiguen y atacan a los jugadores. Al morir sueltan una
-- esencia (si los derrota un Slime). También gestiona efectos: quemadura, ralentización,
-- raíces y empujones.
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local MeshRig = require(script.Parent.MeshRig)
local Physics = require(script.Parent.Physics)

local Monsters = {}

local rng = Random.new()
local monsterFolder
local essenceFolder
local effectsFolder
local active = {} -- [Model] = state
local essences = {} -- [Part] = { Expires = number, Bob = Tween }
local killHandler = nil -- function(player, monsterId, level): boolean (true = soltar esencia)

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new()

function Monsters.SetKillHandler(handler)
	killHandler = handler
end

-- function(character, damage, isMagic): la usa Combat para resistencias y bloqueo
local playerDamageHandler = nil
function Monsters.SetPlayerDamageHandler(handler)
	playerDamageHandler = handler
end

local function randomPointInZone(zone)
	local angle = rng:NextNumber(0, math.pi * 2)
	local distance = math.sqrt(rng:NextNumber()) * zone.Radius
	return zone.Center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
end

--------------------------------------------------------------------------------
-- Diseño de cada monstruo
--------------------------------------------------------------------------------

-- Cada builder recibe add(name, size, offset, color, props, options) para pegar piezas al cuerpo.
-- options.Joint = nombre de la articulación (Motor6D) y options.Pivot = punto de giro
-- (relativo al cuerpo). Así el cliente puede animar patas, alas, brazos, cabeza y cola.
-- options.Attach = pegar la pieza a otra (por ejemplo, los ojos a la cabeza).
local builders = {}

function builders.Bat(root, add, s, color, eyeColor)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = root

	local wingColor = color:Lerp(BLACK, 0.35)
	for _, side in { -1, 1 } do
		local tag = if side > 0 then "R" else "L"
		-- Ala: gira desde el lado del cuerpo
		local wing = add(
			"Wing",
			Vector3.new(2.4, 0.15, 1.4) * s,
			CFrame.new(side * 2 * s, 0.3 * s, 0.1 * s) * CFrame.Angles(0, 0, side * math.rad(20)),
			wingColor,
			nil,
			{ Joint = "Wing" .. tag, Pivot = CFrame.new(side * 0.85 * s, 0.1 * s, 0.1 * s) }
		)
		-- Punta del ala: gira desde el final del ala (para que el aleteo se doble)
		add(
			"WingTip",
			Vector3.new(1.2, 0.12, 0.9) * s,
			CFrame.new(side * 3.6 * s, 0.85 * s, 0.3 * s) * CFrame.Angles(0, 0, side * math.rad(35)),
			wingColor:Lerp(BLACK, 0.2),
			nil,
			{ Joint = "Tip" .. tag, Pivot = CFrame.new(side * 3.1 * s, 0.7 * s, 0.2 * s), Attach = wing }
		)
		add(
			"Ear",
			Vector3.new(0.3, 0.6, 0.2) * s,
			CFrame.new(side * 0.45 * s, 1 * s, -0.2 * s) * CFrame.Angles(0, 0, -side * 0.3),
			color
		)
		add(
			"Eye",
			Vector3.one * 0.32 * s,
			CFrame.new(side * 0.35 * s, 0.25 * s, -0.8 * s),
			eyeColor,
			{ Shape = Enum.PartType.Ball, Material = Enum.Material.Neon }
		)
		add("Fang", Vector3.new(0.1, 0.25, 0.1) * s, CFrame.new(side * 0.15 * s, -0.3 * s, -0.82 * s), WHITE)
	end
end

function builders.Wolf(_root, add, s, color, eyeColor)
	local light = color:Lerp(WHITE, 0.35)
	local dark = color:Lerp(BLACK, 0.3)

	add("Belly", Vector3.new(2.2, 0.6, 4) * s, CFrame.new(0, -0.9 * s, 0), light)
	-- Cabeza: gira desde el cuello; hocico, nariz, orejas y ojos van pegados a ella
	local head = add(
		"Head",
		Vector3.new(1.8, 1.7, 1.8) * s,
		CFrame.new(0, 0.7 * s, -2.6 * s),
		color,
		nil,
		{ Joint = "Neck", Pivot = CFrame.new(0, 0.6 * s, -1.9 * s) }
	)
	add("Snout", Vector3.new(0.9, 0.7, 1.1) * s, CFrame.new(0, 0.35 * s, -3.9 * s), light, nil, { Attach = head })
	add("Nose", Vector3.new(0.4, 0.3, 0.2) * s, CFrame.new(0, 0.6 * s, -4.5 * s), BLACK, nil, { Attach = head })
	-- Cola: gira desde la base
	add(
		"Tail",
		Vector3.new(0.45, 0.45, 2) * s,
		CFrame.new(0, 0.8 * s, 2.9 * s) * CFrame.Angles(math.rad(35), 0, 0),
		dark,
		nil,
		{ Joint = "Tail", Pivot = CFrame.new(0, 0.55 * s, 2.1 * s) }
	)
	for _, side in { -1, 1 } do
		add(
			"Ear",
			Vector3.new(0.45, 0.75, 0.3) * s,
			CFrame.new(side * 0.55 * s, 1.85 * s, -2.4 * s) * CFrame.Angles(0, 0, -side * 0.2),
			dark,
			nil,
			{ Attach = head }
		)
		add(
			"Eye",
			Vector3.one * 0.3 * s,
			CFrame.new(side * 0.45 * s, 0.95 * s, -3.5 * s),
			eyeColor,
			{ Shape = Enum.PartType.Ball, Material = Enum.Material.Neon },
			{ Attach = head }
		)
		-- Patas: giran desde arriba (la cadera / el hombro)
		for _, z in { -1.5, 1.5 } do
			local tag = (if side > 0 then "R" else "L") .. (if z < 0 then "F" else "B")
			add(
				"Leg",
				Vector3.new(0.6, 1.6, 0.6) * s,
				CFrame.new(side * 0.8 * s, -1.9 * s, z * s),
				dark,
				nil,
				{ Joint = "Leg" .. tag, Pivot = CFrame.new(side * 0.8 * s, -1.1 * s, z * s) }
			)
		end
	end
end

function builders.Golem(root, add, s, color, eyeColor)
	root.Material = Enum.Material.Slate
	local dark = color:Lerp(BLACK, 0.25)
	local moss = Color3.fromRGB(80, 130, 60)
	local slate = { Material = Enum.Material.Slate }

	local head = add(
		"Head",
		Vector3.new(2.2, 1.8, 2.2) * s,
		CFrame.new(0, 3.1 * s, -0.2 * s),
		color,
		slate,
		{ Joint = "Neck", Pivot = CFrame.new(0, 2.2 * s, -0.2 * s) }
	)
	add("Core", Vector3.new(1, 1, 0.3) * s, CFrame.new(0, 0.6 * s, -1.75 * s), eyeColor, {
		Material = Enum.Material.Neon,
	})
	for _, side in { -1, 1 } do
		local tag = if side > 0 then "R" else "L"
		-- Brazo con su puño: gira desde el hombro
		local arm = add(
			"Arm",
			Vector3.new(1.6, 4.2, 1.6) * s,
			CFrame.new(side * 3.1 * s, -0.4 * s, 0),
			dark,
			slate,
			{ Joint = "Arm" .. tag, Pivot = CFrame.new(side * 3.1 * s, 1.6 * s, 0) }
		)
		add("Fist", Vector3.new(2, 1.6, 2) * s, CFrame.new(side * 3.1 * s, -3 * s, 0), color, slate, { Attach = arm })
		add(
			"Moss",
			Vector3.new(1.8, 0.4, 1.8) * s,
			CFrame.new(side * 3.1 * s, 1.85 * s, 0),
			moss,
			{ Material = Enum.Material.Grass },
			{ Attach = arm }
		)
		-- Pierna: gira desde la cadera
		add(
			"Leg",
			Vector3.new(1.8, 2.8, 1.8) * s,
			CFrame.new(side * 1.2 * s, -3.6 * s, 0),
			dark,
			slate,
			{ Joint = "Leg" .. tag, Pivot = CFrame.new(side * 1.2 * s, -2.2 * s, 0) }
		)
		add(
			"Eye",
			Vector3.new(0.45, 0.3, 0.1) * s,
			CFrame.new(side * 0.5 * s, 3.2 * s, -1.32 * s),
			eyeColor,
			{ Material = Enum.Material.Neon },
			{ Attach = head }
		)
	end
end

--------------------------------------------------------------------------------
-- Goblin de nivel 1 (rig R15 completo)
--
-- Pequeño y delgado, con la cabeza grande, orejas puntiagudas hacia los lados, nariz
-- ancha, ojos grandes con cejas preocupadas, colmillos pequeños, pelo despeinado,
-- vendas en las muñecas, taparrabos, cinturón de cuero y un garrote de madera.
-- Las piezas del cuerpo son elipsoides suaves para que parezca una criatura y no bloques.
-- Las articulaciones se llaman igual que en R15 (Root, Waist, Neck, RightShoulder...),
-- así lo anima el mismo sistema de fotogramas clave que a los jugadores.
--------------------------------------------------------------------------------

-- Altura del centro del HumanoidRootPart sobre el suelo (HipHeight + mitad del root)
local GOBLIN_ROOT_Y = 1.41

local function sphereMesh(part, scale)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	if scale then
		mesh.Scale = scale
	end
	mesh.Parent = part
	return part
end

builders.GoblinTier1 = function(root, add, s, color, eyeColor)
	root.Transparency = 1

	-- Posición en "coordenadas del suelo" (y = 0 es el suelo) -> relativa al root
	local function g(x, y, z)
		return CFrame.new(x * s, (y - GOBLIN_ROOT_Y) * s, z * s)
	end
	local function v(x, y, z)
		return Vector3.new(x, y, z) * s
	end

	-- Cada goblin tiene un tono de piel un poco distinto
	local skin = color:Lerp(Color3.fromRGB(135, 165, 65), rng:NextNumber(0, 0.45))
	local skinDark = skin:Lerp(Color3.fromRGB(40, 60, 25), 0.25)
	local skinShade = skin:Lerp(Color3.fromRGB(40, 60, 25), 0.12)
	local cloth = Color3.fromRGB(150, 120, 80):Lerp(Color3.fromRGB(110, 95, 75), rng:NextNumber(0, 1))
	local leather = Color3.fromRGB(75, 48, 30)
	local bandage = Color3.fromRGB(222, 212, 190)
	local wood = Color3.fromRGB(110, 72, 42)
	local hair = ({
		Color3.fromRGB(70, 55, 45),
		Color3.fromRGB(120, 115, 110),
		Color3.fromRGB(95, 70, 50),
	})[rng:NextInteger(1, 3)]
	local fabric = { Material = Enum.Material.Fabric }

	local function bodyPart(name, size, at, partColor, joint, pivot, parent)
		local part = add(name, size, at, partColor, nil, { Joint = joint, Pivot = pivot, Attach = parent })
		return sphereMesh(part)
	end

	-- Cuerpo (articulaciones R15)
	local lowerTorso = bodyPart("LowerTorso", v(0.9, 0.42, 0.55), g(0, 1.41, 0), skinShade, "Root", g(0, 1.41, 0), root)
	local upperTorso =
		bodyPart("UpperTorso", v(0.95, 0.9, 0.6), g(0, 2.02, 0.02), skin, "Waist", g(0, 1.6, 0), lowerTorso)
	local head = bodyPart("Head", v(1.3, 1.2, 1.2), g(0, 3.04, -0.05), skin, "Neck", g(0, 2.44, 0), upperTorso)

	local hands = {}
	for _, side in { 1, -1 } do
		local prefix = if side > 0 then "Right" else "Left"
		local x = side * 0.64
		local upperArm = bodyPart(
			prefix .. "UpperArm",
			v(0.3, 0.6, 0.3),
			g(x, 2.03, 0),
			skin,
			prefix .. "Shoulder",
			g(x, 2.3, 0),
			upperTorso
		)
		local lowerArm = bodyPart(
			prefix .. "LowerArm",
			v(0.27, 0.56, 0.27),
			g(x, 1.51, 0),
			skin,
			prefix .. "Elbow",
			g(x, 1.76, 0),
			upperArm
		)
		hands[side] = bodyPart(
			prefix .. "Hand",
			v(0.32, 0.3, 0.32),
			g(x, 1.12, 0),
			skinDark,
			prefix .. "Wrist",
			g(x, 1.26, 0),
			lowerArm
		)

		local legX = side * 0.24
		local upperLeg = bodyPart(
			prefix .. "UpperLeg",
			v(0.4, 0.58, 0.4),
			g(legX, 0.97, 0),
			skinShade,
			prefix .. "Hip",
			g(legX, 1.22, 0),
			lowerTorso
		)
		local lowerLeg = bodyPart(
			prefix .. "LowerLeg",
			v(0.33, 0.56, 0.33),
			g(legX, 0.47, 0),
			skin,
			prefix .. "Knee",
			g(legX, 0.72, 0),
			upperLeg
		)
		bodyPart(
			prefix .. "Foot",
			v(0.42, 0.24, 0.66),
			g(legX, 0.11, -0.09),
			skinDark,
			prefix .. "Ankle",
			g(legX, 0.22, 0),
			lowerLeg
		)

		-- Vendas en la muñeca (como en la referencia) y una en la espinilla derecha
		sphereMesh(add("WristWrap", v(0.33, 0.16, 0.33), g(x, 1.32, 0), bandage, fabric, { Attach = lowerArm }))
		sphereMesh(add("WristWrap", v(0.31, 0.12, 0.31), g(x, 1.48, 0), bandage, fabric, { Attach = lowerArm }))
		if side > 0 then
			sphereMesh(add("ShinWrap", v(0.37, 0.15, 0.37), g(legX, 0.55, 0), bandage, fabric, { Attach = lowerLeg }))
		end

		-- Ojo: blanco grande, pupila pequeña mirando un poco hacia dentro y un brillo
		sphereMesh(
			add("EyeWhite", v(0.34, 0.38, 0.12), g(side * 0.26, 3.08, -0.6), Color3.fromRGB(245, 245, 235), nil, {
				Attach = head,
			})
		)
		sphereMesh(add("Pupil", v(0.12, 0.14, 0.05), g(side * 0.23, 3.06, -0.665), eyeColor, nil, { Attach = head }))
		sphereMesh(add("EyeShine", v(0.05, 0.05, 0.03), g(side * 0.25, 3.11, -0.69), Color3.new(1, 1, 1), nil, {
			Attach = head,
		}))
		-- Cejas inclinadas hacia arriba por dentro: cara de goblin novato y algo asustado
		sphereMesh(
			add(
				"Brow",
				v(0.42, 0.12, 0.2),
				g(side * 0.27, 3.3, -0.55) * CFrame.Angles(0, 0, side * math.rad(-14)),
				skinDark,
				nil,
				{ Attach = head }
			)
		)
		-- Colmillos pequeños que asoman hacia arriba
		add(
			"Fang",
			v(0.07, 0.13, 0.05),
			g(side * 0.13, 2.68, -0.62),
			Color3.fromRGB(245, 240, 225),
			nil,
			{ Attach = head }
		)

		-- Oreja grande y puntiaguda hacia el lado (cuña: la punta hacia fuera, un poco hacia arriba)
		local earAngle = CFrame.Angles(0, 0, side * math.rad(16)) * CFrame.Angles(0, -side * math.rad(90), 0)
		add(
			"Ear",
			v(0.1, 0.44, 0.98),
			g(side * 1.0, 3.12, 0.05) * earAngle,
			skin,
			nil,
			{ Class = "WedgePart", Attach = head }
		)
		add(
			"InnerEar",
			v(0.05, 0.28, 0.66),
			g(side * 0.94, 3.1, 0.01) * earAngle,
			Color3.fromRGB(150, 115, 90),
			nil,
			{ Class = "WedgePart", Attach = head }
		)
	end

	-- Cara: mandíbula ancha, nariz grande y ancha, boca fina
	sphereMesh(add("Jaw", v(1.2, 0.75, 1.05), g(0, 2.74, -0.1), skin, nil, { Attach = head }))
	sphereMesh(add("Nose", v(0.46, 0.32, 0.36), g(0, 2.9, -0.66), skinDark, nil, { Attach = head }))
	add("Mouth", v(0.44, 0.05, 0.04), g(0, 2.62, -0.62), Color3.fromRGB(40, 25, 20), nil, { Attach = head })

	-- Pelo despeinado: unos mechones encima y detrás de la cabeza
	for index, tuft in
		{
			{ -0.3, 3.62, 0.05, -20, 15 },
			{ 0.05, 3.7, -0.05, 10, -10 },
			{ 0.35, 3.6, 0.1, 25, 20 },
			{ -0.15, 3.52, 0.4, -10, 160 },
			{ 0.25, 3.48, 0.42, 15, 200 },
		}
	do
		add(
			"Hair" .. index,
			v(0.32, 0.36, 0.48),
			g(tuft[1], tuft[2], tuft[3]) * CFrame.Angles(0, math.rad(tuft[5]), math.rad(tuft[4])),
			hair,
			nil,
			{ Class = "WedgePart", Attach = head }
		)
	end

	-- Ropa: cinturón de cuero con hebilla, taparrabos y una tira de tela rota en el pecho
	add(
		"Belt",
		v(0.98, 0.14, 0.62),
		g(0, 1.56, 0),
		leather,
		{ Material = Enum.Material.Leather },
		{ Attach = lowerTorso }
	)
	add("Buckle", v(0.16, 0.12, 0.05), g(0, 1.56, -0.32), Color3.fromRGB(120, 115, 105), {
		Material = Enum.Material.Metal,
	}, { Attach = lowerTorso })
	add("LoinFront", v(0.52, 0.58, 0.06), g(0, 1.22, -0.29), cloth, fabric, { Attach = lowerTorso })
	add("LoinBack", v(0.56, 0.52, 0.06), g(0, 1.24, 0.29), cloth, fabric, { Attach = lowerTorso })
	add("ChestCloth", v(1.05, 0.2, 0.66), g(0, 2.12, 0.02) * CFrame.Angles(0, 0, math.rad(35)), cloth, fabric, {
		Attach = upperTorso,
	})
	add(
		"Patch",
		v(0.18, 0.16, 0.05),
		g(0.22, 2.26, -0.33),
		cloth:Lerp(Color3.new(), 0.3),
		fabric,
		{ Attach = upperTorso }
	)

	-- Garrote de madera tosco en la mano derecha (apunta hacia delante con el brazo caído)
	local hand = hands[1]
	local along = CFrame.Angles(0, math.rad(90), 0) -- los cilindros van en X: así quedan hacia delante
	add("ClubGrip", v(0.32, 0.19, 0.19), g(0.64, 1.12, -0.3) * along, leather, { Shape = Enum.PartType.Cylinder }, {
		Attach = hand,
	})
	add("ClubHandle", v(1.25, 0.16, 0.16), g(0.64, 1.12, -0.62) * along, wood, {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Wood,
	}, { Attach = hand })
	add("ClubHead", v(0.6, 0.38, 0.38), g(0.64, 1.14, -1.38) * along, wood:Lerp(Color3.new(), 0.15), {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Wood,
	}, { Attach = hand })
	for _, knot in { { 0.16, 1.26, -1.3 }, { -0.12, 1.02, -1.48 }, { 0.05, 1.3, -1.55 } } do
		add("ClubKnot", v(0.16, 0.16, 0.16), g(0.64 + knot[1], knot[2], knot[3]), wood:Lerp(Color3.new(), 0.25), {
			Shape = Enum.PartType.Ball,
			Material = Enum.Material.Wood,
		}, { Attach = hand })
	end
end

-- Monstruos hechos en Blender: el modelo importado se monta con sus articulaciones R15
builders.Mesh = function(root, _add, s, _color, _eyeColor, model, def)
	root.Transparency = 1
	MeshRig.Build(def.MeshModel, root, s, model)
end

--------------------------------------------------------------------------------
-- Barra de vida, números de daño y esencias
--------------------------------------------------------------------------------

local function createHealthBar(state, displayName, level)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HealthBar"
	billboard.Adornee = state.Root
	billboard.Size = UDim2.fromOffset(150, 34)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, state.TopOffset, 0)
	billboard.MaxDistance = 90
	billboard.LightInfluence = 0
	billboard.Parent = state.Root

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0, 16)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 13
	nameLabel.TextColor3 = WHITE
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.RichText = true
	nameLabel.Text = displayName .. '  <font color="#FFD25A">Nv. ' .. level .. "</font>"
	nameLabel.Parent = billboard

	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(0, 19)
	back.Size = UDim2.new(1, 0, 0, 11)
	back.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	back.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = back
	local stroke = Instance.new("UIStroke")
	stroke.Color = BLACK
	stroke.Thickness = 1.5
	stroke.Parent = back

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 220, 90)
	fill.BorderSizePixel = 0
	fill.Parent = back
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 5)
	fillCorner.Parent = fill

	local humanoid = state.Humanoid
	humanoid.HealthChanged:Connect(function(health)
		local ratio = math.clamp(health / humanoid.MaxHealth, 0, 1)
		TweenService:Create(fill, TweenInfo.new(0.15), { Size = UDim2.fromScale(ratio, 1) }):Play()
		fill.BackgroundColor3 = Color3.fromRGB(230, 60, 50):Lerp(Color3.fromRGB(90, 220, 90), ratio)
	end)
end

local function showDamageNumber(state, amount, color)
	local billboard = Instance.new("BillboardGui")
	billboard.Adornee = state.Root
	billboard.Size = UDim2.fromOffset(90, 30)
	billboard.StudsOffsetWorldSpace = Vector3.new(rng:NextNumber(-1.2, 1.2), state.TopOffset + 0.5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 80
	billboard.LightInfluence = 0

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 22
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = tostring(amount)
	label.Parent = billboard
	billboard.Parent = effectsFolder

	local info = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(billboard, info, {
		StudsOffsetWorldSpace = billboard.StudsOffsetWorldSpace + Vector3.new(0, 2.5, 0),
	}):Play()
	local fade = TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 })
	fade.Completed:Connect(function()
		billboard:Destroy()
	end)
	fade:Play()
end

local function createEssence(monsterId, level, position)
	local def = Config.Monsters[monsterId]

	local orb = Instance.new("Part")
	orb.Name = "Essence"
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.one * 2
	orb.Material = Enum.Material.Neon
	orb.Color = def.Color:Lerp(Color3.fromRGB(150, 230, 255), 0.6)
	orb.Anchored = true
	orb.CanCollide = false
	orb.Position = Vector3.new(position.X, 2, position.Z)
	orb:SetAttribute("MonsterId", monsterId)
	orb:SetAttribute("MonsterLevel", level)

	local light = Instance.new("PointLight")
	light.Color = orb.Color
	light.Range = 10
	light.Parent = orb

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(190, 44)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 40
	billboard.Parent = orb

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "Esencia: " .. def.DisplayName .. " Nv. " .. level .. "\nPulsa F para absorber"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = WHITE
	label.TextStrokeTransparency = 0.2
	label.Parent = billboard

	orb.Parent = essenceFolder

	local bob = TweenService:Create(
		orb,
		TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = orb.Position + Vector3.new(0, 1, 0) }
	)
	bob:Play()

	essences[orb] = { Expires = os.clock() + Config.EssenceLifetime, Bob = bob }
end

--------------------------------------------------------------------------------
-- Aparecer
--------------------------------------------------------------------------------

-- Elige qué monstruo aparece según la tabla de la zona (Weight = probabilidad relativa)
local function pickSpawn(zone)
	local total = 0
	for _, entry in zone.Spawns do
		total += entry.Weight or 1
	end
	local roll = rng:NextNumber(0, total)
	for _, entry in zone.Spawns do
		roll -= entry.Weight or 1
		if roll <= 0 then
			return entry
		end
	end
	return zone.Spawns[#zone.Spawns]
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- ¿Hay sitio? Sin árboles, rocas, casas, jugadores ni otros monstruos encima
local GROUND_NAMES = { Ground = true, Path = true, StoneGround = true }
local function isFree(point)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { essenceFolder, effectsFolder }
	for _, part in Workspace:GetPartBoundsInBox(CFrame.new(point + Vector3.new(0, 3, 0)), Vector3.new(4, 5, 4), params) do
		if not GROUND_NAMES[part.Name] then
			return false
		end
	end
	return true
end

local function playerNear(point, radius)
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - point).Magnitude < radius then
			return true
		end
	end
	return false
end

-- Un sitio de aparición nuevo dentro de la zona: libre, bien lejos de la zona segura y
-- separado de los demás sitios (para que no salgan todos amontonados)
local function findSpawnPoint(zone, taken)
	local safe = Config.SafeZone
	for _ = 1, 40 do
		local point = randomPointInZone(zone)
		local separated = true
		for _, other in taken do
			if (other - point).Magnitude < 10 then
				separated = false
				break
			end
		end
		if separated and flat(point - safe.Center).Magnitude > safe.Radius + 12 and isFree(point) then
			return point
		end
	end
	return nil
end

-- Puntos de aparición: cada zona tiene MaxMonsters sitios fijos. Cada sitio tiene como mucho
-- un monstruo vivo y, cuando muere, vuelve a aparecer en ese mismo sitio tras su
-- RespawnTime. Así no hay duplicados ni monstruos que aparecen encima de nadie.
local slots = {} -- { Zone, Entry, Home, Model, RespawnAt }
local homesTaken = {}

-- Quién se lleva la recompensa: el jugador que más daño le hizo y sigue en el juego (así
-- nadie "roba" un monstruo dando solo el último golpe). En caso de empate, el último que
-- golpeó. Se entrega una sola vez porque la muerte solo se procesa una vez.
function Monsters.ChooseRewardPlayer(damageBy, lastHitBy)
	local best, bestDamage = nil, 0
	for player, damage in damageBy do
		if player.Parent and (damage > bestDamage or (damage == bestDamage and player == lastHitBy)) then
			best, bestDamage = player, damage
		end
	end
	return best
end

local function spawnMonster(slot)
	local monsterId = slot.Entry.Monster
	local levels = slot.Entry.Levels
	local def = Config.Monsters[monsterId]
	local position = slot.Home
	local level = rng:NextInteger(levels[1], levels[2])
	local stats = Config.MonsterStats(monsterId, level)
	local s = stats.Scale
	-- Cuanto más nivel, un poco más oscuro
	local color = def.Color:Lerp(BLACK, (level - 1) * 0.035)

	local model = Instance.new("Model")
	model.Name = def.DisplayName
	model:SetAttribute("MonsterId", monsterId)
	model:SetAttribute("Level", level)

	local size = def.Size * s
	local hipHeight = def.HipHeight * s
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = size
	root.Color = color
	root.Material = Enum.Material.SmoothPlastic
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.CFrame = CFrame.new(position + Vector3.new(0, hipHeight + size.Y / 2 + 0.2, 0))
		* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	root.Parent = model
	model.PrimaryPart = root

	local function add(name, partSize, offset, partColor, props, options)
		local part = Instance.new(options and options.Class or "Part")
		part.Name = name
		part.Size = partSize
		part.CFrame = root.CFrame * offset
		part.Color = partColor
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		for key, value in props or {} do
			part[key] = value
		end

		local attachTo = options and options.Attach or root
		if options and options.Joint then
			-- Articulación animable: los ejes del punto de giro van alineados con el cuerpo
			local pivot = root.CFrame * options.Pivot
			local motor = Instance.new("Motor6D")
			motor.Name = options.Joint
			motor.Part0 = attachTo
			motor.Part1 = part
			motor.C0 = attachTo.CFrame:ToObjectSpace(pivot)
			motor.C1 = part.CFrame:ToObjectSpace(pivot)
			motor.Parent = part
		else
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = attachTo
			weld.Part1 = part
			weld.Parent = part
		end
		part.Parent = model
		return part
	end
	-- Modelo 3D de Blender si está importado; si no, el diseño de piezas de siempre
	local builderId, animSet = def.Builder or monsterId, def.AnimSet
	if def.MeshModel and not MeshRig.IsReady(def.MeshModel) then
		builderId, animSet = def.FallbackBuilder, def.FallbackAnimSet or animSet
	end
	builders[builderId](root, add, s, color, def.EyeColor, model, def)

	-- Altura de la barra de vida: justo encima de la pieza más alta
	local boxCFrame, boxSize = model:GetBoundingBox()
	local topOffset = boxCFrame.Position.Y + boxSize.Y / 2 - root.Position.Y + 1.2

	-- Rig R15 (Goblin): el cliente lo anima con fotogramas clave. AnimScale ajusta los
	-- desplazamientos de las animaciones (agacharse, caer muerto) a su tamaño.
	if def.Rig == "R15" then
		model:SetAttribute("Rig", "R15")
		model:SetAttribute("AnimSet", animSet)
		model:SetAttribute("AnimScale", (hipHeight + size.Y / 2) / 2.9)
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.AutomaticScalingEnabled = false
	humanoid.HipHeight = hipHeight
	humanoid.MaxHealth = stats.Health
	humanoid.Health = stats.Health
	humanoid.WalkSpeed = Config.MonsterSetting(def, "WalkSpeed")
	humanoid.BreakJointsOnDeath = false -- sin la "explosión" de Roblox al morir
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	-- Estados que no tienen sentido en un monstruo (y que lo podían tumbar o sentar)
	for _, humanoidState in
		{
			Enum.HumanoidStateType.FallingDown,
			Enum.HumanoidStateType.Ragdoll,
			Enum.HumanoidStateType.Seated,
			Enum.HumanoidStateType.Climbing,
		}
	do
		humanoid:SetStateEnabled(humanoidState, false)
	end
	humanoid.Parent = model

	local state = {
		Id = monsterId,
		Def = def,
		Level = level,
		Stats = stats,
		Size = size,
		Zone = slot.Zone,
		Slot = slot,
		Model = model,
		Humanoid = humanoid,
		Root = root,
		TopOffset = topOffset,
		Reach = Config.MonsterReach(def, size),
		Home = position, -- su sitio: pasea cerca y vuelve aquí
		Mode = "Idle", -- Idle (en su sitio) / Chase (persigue) / Return (vuelve a su sitio)
		Target = nil, -- personaje al que persigue
		DamageBy = {}, -- [Player] = daño hecho (para la recompensa)
		Dead = false,
		LastAttack = 0,
		AttackingUntil = 0,
		NextWander = os.clock() + rng:NextNumber(1, 4),
		WanderGoal = nil,
		SurroundAngle = rng:NextNumber(-55, 55), -- varios monstruos rodean en vez de amontonarse
		Path = nil,
		PathIndex = 0,
		PathGoal = nil,
		PathRefresh = 0,
		PathBusy = false,
		StuckPathUntil = 0,
		LastPos = root.Position,
		NextStuckCheck = 0,
		LastHitBy = nil,
		SlowUntil = 0,
		SlowMult = 1,
		RootedUntil = 0,
		BurnUntil = 0,
		BurnDamage = 0,
		BurnBy = nil,
		NextBurnTick = 0,
	}
	model:SetAttribute("AIState", "Idle")
	createHealthBar(state, def.DisplayName, level)

	-- No choca con jugadores ni con otros monstruos (sí con el mundo): ver Physics.luau
	Physics.SetGroup(model, Physics.MONSTERS)
	model.Parent = monsterFolder
	root:SetNetworkOwner(nil) -- el servidor mueve a los monstruos, así se ven bien para todos

	active[model] = state
	slot.Model = model

	humanoid.Died:Connect(function()
		if state.Dead then
			return -- la muerte solo se procesa una vez
		end
		state.Dead = true
		active[model] = nil
		model:SetAttribute("AIState", "Dead")
		slot.Model = nil
		slot.RespawnAt = os.clock() + Config.MonsterSetting(def, "RespawnTime")

		local killer = Monsters.ChooseRewardPlayer(state.DamageBy, state.LastHitBy)
		if killer and killHandler and killHandler(killer, monsterId, level) then
			createEssence(monsterId, level, root.Position)
		end

		local bar = root:FindFirstChild("HealthBar")
		if bar then
			bar:Destroy()
		end
		local fire = root:FindFirstChild("Burning")
		if fire then
			fire:Destroy()
		end
		-- Se queda quieto mientras cae (el cliente reproduce la animación de muerte)
		local corpseTime = Config.MonsterSetting(def, "CorpseTime")
		root.AssemblyLinearVelocity = Vector3.zero
		root.Anchored = true
		task.delay(math.max(0, corpseTime - 0.9), function()
			for _, descendant in model:GetDescendants() do
				if descendant:IsA("BasePart") and descendant.Transparency < 1 then
					TweenService:Create(descendant, TweenInfo.new(0.8), { Transparency = 1 }):Play()
				end
			end
		end)
		task.delay(corpseTime, function()
			model:Destroy()
		end)
	end)
end

-- Intenta (re)aparecer el monstruo de un sitio
local function trySpawn(slot, now)
	if not slot.Home then
		slot.Home = findSpawnPoint(slot.Zone, homesTaken)
		if not slot.Home then
			slot.RespawnAt = now + 3
			return
		end
		table.insert(homesTaken, slot.Home)
	end
	-- No aparecer encima de un jugador, de otro monstruo o de su propio cuerpo
	if playerNear(slot.Home, 12) or not isFree(slot.Home) then
		slot.RespawnAt = now + 3
		return
	end
	slot.Entry = pickSpawn(slot.Zone)
	spawnMonster(slot)
end

--------------------------------------------------------------------------------
-- Inteligencia
--
--   Idle:   en su sitio. A ratos pasea un poco cerca y a ratos se queda quieto.
--   Chase:  persigue al jugador más cercano dentro de su radio de detección (o al que le
--           pegó). Se para a distancia de golpe, lo rodea si hay más monstruos y esquiva
--           obstáculos con PathfindingService cuando no hay línea recta.
--   Return: si el jugador se escapa, entra en la zona segura o el monstruo se aleja
--           demasiado de su sitio, vuelve corriendo, no recibe daño ("Esquiva") y al llegar
--           recupera toda la vida.
--------------------------------------------------------------------------------

local function setMode(state, mode)
	if state.Mode ~= mode then
		state.Mode = mode
		state.Path = nil
		state.Model:SetAttribute("AIState", mode)
	end
end

local function aliveRoot(character)
	local humanoid = character and character.Parent and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return root
	end
	return nil
end

-- ¿Puede (seguir) persiguiendo a este personaje?
local function canChase(state, character)
	local root = aliveRoot(character)
	if not root or Config.IsInSafeZone(root.Position) then
		return false -- los jugadores en la zona segura están protegidos
	end
	local def = state.Def
	local aggro = Config.MonsterSetting(def, "AggroRange")
	-- El jugador está demasiado lejos del sitio del monstruo
	if flat(root.Position - state.Home).Magnitude > Config.MonsterSetting(def, "LeashRange") + aggro * 0.5 then
		return false
	end
	return (root.Position - state.Root.Position).Magnitude <= aggro * Config.MonsterSetting(def, "LoseInterestRange")
end

local function findTarget(state)
	local best, bestDistance = nil, Config.MonsterSetting(state.Def, "AggroRange")
	for _, player in Players:GetPlayers() do
		local root = aliveRoot(player.Character)
		if root then
			local distance = (root.Position - state.Root.Position).Magnitude
			if distance < bestDistance and canChase(state, player.Character) then
				best, bestDistance = player.Character, distance
			end
		end
	end
	return best
end

function Monsters.Damage(state, player, amount, color)
	local humanoid = state.Humanoid
	if state.Dead or humanoid.Health <= 0 then
		return
	end
	-- Desde la zona segura no se puede pelear (si no, sería pegar sin riesgo)
	local character = player and player.Character
	local attackerRoot = character and character:FindFirstChild("HumanoidRootPart")
	if attackerRoot and Config.IsInSafeZone(attackerRoot.Position) then
		showDamageNumber(state, "Zona segura", Color3.fromRGB(150, 200, 255))
		return
	end
	-- Volviendo a su sitio: no recibe daño (evita "arrastrarlo" lejos para pegarle gratis)
	if state.Mode == "Return" then
		showDamageNumber(state, "Esquiva", Color3.fromRGB(190, 190, 190))
		return
	end
	amount = math.max(1, math.floor(amount + 0.5))
	if player then
		state.LastHitBy = player
		state.DamageBy[player] = (state.DamageBy[player] or 0) + math.min(amount, humanoid.Health)
		-- Si le pegan, va a por quien le pegó aunque estuviera fuera de su radio de detección
		if character and (state.Target == nil or not canChase(state, state.Target)) and canChase(state, character) then
			state.Target = character
		end
	end
	humanoid:TakeDamage(amount)
	showDamageNumber(state, amount, color or WHITE)
end

local function setBurning(state, burning)
	local fire = state.Root:FindFirstChild("Burning")
	if burning and not fire then
		fire = Instance.new("Fire")
		fire.Name = "Burning"
		fire.Size = math.max(state.Size.X, state.Size.Z)
		fire.Color = Color3.fromRGB(255, 120, 30)
		fire.SecondaryColor = Color3.fromRGB(255, 220, 80)
		fire.Parent = state.Root
	elseif not burning and fire then
		fire:Destroy()
	end
end

-- Punto para pasear: cerca de su sitio y siempre dentro de la zona
local function wanderPoint(state)
	local radius = Config.MonsterSetting(state.Def, "WanderRadius")
	local angle = rng:NextNumber(0, math.pi * 2)
	local point = state.Home + Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(3, radius)
	local zone = state.Zone
	if flat(point - zone.Center).Magnitude > zone.Radius then
		point = zone.Center + flat(point - zone.Center).Unit * zone.Radius * 0.9
	end
	return point
end

-- Lo que bloquea el paso (para decidir si hace falta buscar un camino): todo menos personajes,
-- monstruos y efectos. Se calcula una vez por ciclo de la IA.
local function sightParams()
	local ignore = { monsterFolder, essenceFolder, effectsFolder }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	return params
end

-- Caminar hacia un punto: en línea recta si se puede; si hay algo en medio (o se quedó
-- atascado), con un camino de PathfindingService que se calcula sin parar la IA.
local function moveTo(state, destination, params, now)
	local humanoid = state.Humanoid
	local origin = state.Root.Position
	local offset = flat(destination - origin)
	if offset.Magnitude < 0.5 then
		return
	end
	local blocked = state.StuckPathUntil > now or Workspace:Raycast(origin, offset, params) ~= nil
	if not blocked then
		state.Path = nil
		humanoid:MoveTo(destination)
		return
	end

	local needPath = not state.Path or now >= state.PathRefresh or (state.PathGoal - destination).Magnitude > 6
	if needPath and not state.PathBusy then
		state.PathBusy = true
		local radius = math.max(1.5, math.max(state.Size.X, state.Size.Z) / 2 + 0.5)
		task.spawn(function()
			local path = PathfindingService:CreatePath({
				AgentRadius = radius,
				AgentHeight = state.Size.Y + state.Def.HipHeight + 1,
				AgentCanJump = false,
			})
			local ok = pcall(function()
				path:ComputeAsync(origin, destination)
			end)
			state.PathBusy = false
			if ok and path.Status == Enum.PathStatus.Success then
				state.Path = path:GetWaypoints()
				state.PathIndex = 2
			else
				state.Path = nil
			end
			state.PathGoal = destination
			state.PathRefresh = os.clock() + 1.5
		end)
	end

	local path = state.Path
	if path then
		local waypoint = path[state.PathIndex]
		while waypoint and flat(waypoint.Position - origin).Magnitude < 2 do
			state.PathIndex += 1
			waypoint = path[state.PathIndex]
		end
		if waypoint then
			humanoid:MoveTo(waypoint.Position)
			return
		end
		state.Path = nil
	end
	humanoid:MoveTo(destination)
end

-- Si quería moverse y apenas se ha movido, está atascado: usa caminos un rato
local function checkStuck(state, now, wantsToMove)
	if now < state.NextStuckCheck then
		return
	end
	local position = state.Root.Position
	if wantsToMove and flat(position - state.LastPos).Magnitude < 0.6 then
		state.StuckPathUntil = now + 3
		state.PathRefresh = 0
	end
	state.LastPos = position
	state.NextStuckCheck = now + 1.25
end

-- Separarse de otros monstruos muy cercanos (no chocan entre ellos)
local function separation(state)
	local push = Vector3.zero
	for _, other in active do
		if other ~= state then
			local offset = flat(state.Root.Position - other.Root.Position)
			local distance = offset.Magnitude
			if distance > 0.01 and distance < 3 then
				push += offset.Unit * (3 - distance)
			end
		end
	end
	return push
end

-- Girar hacia un punto poco a poco (como mucho maxStep radianes por ciclo)
local function faceTowards(state, point, maxStep)
	local root = state.Root
	local wanted = flat(point - root.Position)
	local current = flat(root.CFrame.LookVector)
	if wanted.Magnitude < 0.1 or current.Magnitude < 0.1 then
		return
	end
	wanted, current = wanted.Unit, current.Unit
	local angle = math.acos(math.clamp(current:Dot(wanted), -1, 1))
	if angle < math.rad(8) then
		return
	end
	local sign = if current:Cross(wanted).Y >= 0 then 1 else -1
	root.CFrame = CFrame.new(root.Position)
		* CFrame.Angles(0, sign * math.min(angle, maxStep), 0)
		* root.CFrame.Rotation
end

-- Golpe: anima, se queda quieto preparando el golpe y el daño llega en el momento de la
-- animación en que baja el arma. Solo acierta si el objetivo sigue cerca, delante y fuera
-- de la zona segura. Un ataque = como mucho un golpe.
local function startAttack(state, target, now)
	local def, humanoid = state.Def, state.Humanoid
	state.LastAttack = now
	faceTowards(state, target.HumanoidRootPart.Position, math.pi)
	humanoid:MoveTo(state.Root.Position)
	-- Los clientes ven este cambio y reproducen la animación de ataque
	state.Model:SetAttribute("AttackTick", (state.Model:GetAttribute("AttackTick") or 0) + 1)

	local windup = Config.MonsterSetting(def, "AttackWindup")
	state.AttackingUntil = now + windup + 0.15

	local function resolve()
		if state.Dead or humanoid.Health <= 0 or state.RootedUntil > os.clock() then
			return
		end
		local targetRoot = aliveRoot(target)
		if not targetRoot or Config.IsInSafeZone(targetRoot.Position) then
			return
		end
		local offset = targetRoot.Position - state.Root.Position
		if offset.Magnitude > state.Reach * 1.2 then
			return -- se apartó a tiempo: falla
		end
		local flatOffset = flat(offset)
		local look = flat(state.Root.CFrame.LookVector)
		if flatOffset.Magnitude > 2 and look.Magnitude > 0.1 and look.Unit:Dot(flatOffset.Unit) < 0.1 then
			return -- se puso detrás
		end
		if playerDamageHandler then
			-- Combat aplica resistencias y el bloqueo (Guard)
			playerDamageHandler(target, state.Stats.Damage, def.Magic == true)
		else
			target.Humanoid:TakeDamage(state.Stats.Damage)
		end
	end
	if windup <= 0 then
		resolve()
	else
		task.delay(windup, resolve)
	end
end

local function chase(state, target, now, params, slowMult)
	local def, humanoid, root = state.Def, state.Humanoid, state.Root
	local targetRoot = target.HumanoidRootPart
	local offset = flat(targetRoot.Position - root.Position)
	local distance = offset.Magnitude
	local stopAt = math.max(1.5, state.Reach * 0.7)
	humanoid.WalkSpeed = Config.MonsterSetting(def, "ChaseSpeed") * slowMult

	local moving = false
	if distance > stopAt then
		-- Se acerca a un punto a su alrededor (no al centro del jugador): no lo empuja, y
		-- si hay varios monstruos, cada uno llega por un lado
		local around = CFrame.Angles(0, math.rad(state.SurroundAngle), 0):VectorToWorldSpace(offset.Unit)
		local destination = targetRoot.Position - around * stopAt * 0.9 + separation(state) * 1.5
		moveTo(state, Vector3.new(destination.X, root.Position.Y, destination.Z), params, now)
		moving = true
	else
		humanoid:MoveTo(root.Position) -- se para a distancia de golpe y lo mira
		faceTowards(state, targetRoot.Position, math.rad(50))
	end

	if distance <= state.Reach and now - state.LastAttack >= Config.MonsterSetting(def, "AttackCooldown") then
		startAttack(state, target, now)
		moving = false
	end
	return moving
end

-- Vuelve a su sitio y se recupera del todo
local function resetMonster(state, now)
	setMode(state, "Idle")
	state.Target = nil
	state.DamageBy = {}
	state.LastHitBy = nil
	state.SlowUntil = 0
	state.BurnUntil = 0
	state.Humanoid.Health = state.Humanoid.MaxHealth
	state.NextWander = now + rng:NextNumber(2, 5)
	state.WanderGoal = nil
	state.Humanoid:MoveTo(state.Root.Position)
end

local function updateMonster(state, now, params)
	local humanoid = state.Humanoid

	-- Quemadura
	if state.BurnUntil > now then
		if now >= state.NextBurnTick then
			state.NextBurnTick = now + 0.5
			Monsters.Damage(state, state.BurnBy, state.BurnDamage, Color3.fromRGB(255, 150, 50))
		end
	elseif state.BurnDamage > 0 then
		state.BurnDamage = 0
		setBurning(state, false)
	end
	if state.Dead or humanoid.Health <= 0 then
		return
	end

	-- Atrapado por raíces: no se mueve ni ataca
	if state.RootedUntil > now then
		humanoid.WalkSpeed = 0
		humanoid:Move(Vector3.zero)
		return
	end
	-- Mientras prepara un golpe se queda quieto (así se ve el ataque y se puede esquivar)
	if state.AttackingUntil > now then
		humanoid.WalkSpeed = 0
		return
	end
	local def = state.Def
	local slowMult = if state.SlowUntil > now then state.SlowMult else 1
	local position = state.Root.Position

	-- Zona segura: si se acerca demasiado, deja lo que esté haciendo y vuelve a su sitio
	local safe = Config.SafeZone
	if state.Mode ~= "Return" and flat(position - safe.Center).Magnitude < safe.Radius + 4 then
		state.Target = nil
		setMode(state, "Return")
	end

	local fromHome = flat(position - state.Home).Magnitude
	local wantsToMove = false

	if state.Mode == "Return" then
		humanoid.WalkSpeed = Config.MonsterSetting(def, "ReturnSpeed") * slowMult
		if fromHome < 3 then
			resetMonster(state, now)
		else
			moveTo(state, state.Home, params, now)
			wantsToMove = true
		end
		checkStuck(state, now, wantsToMove)
		return
	end

	-- Elegir objetivo: sigue con el que tiene mientras pueda; si no, el más cercano
	local target = state.Target
	if target and not canChase(state, target) then
		target = nil
	end
	if not target then
		target = findTarget(state)
	end
	state.Target = target

	if target and fromHome > Config.MonsterSetting(def, "LeashRange") then
		-- Demasiado lejos de casa: se rinde
		state.Target = nil
		setMode(state, "Return")
		return
	end

	if target then
		setMode(state, "Chase")
		wantsToMove = chase(state, target, now, params, slowMult)
	elseif state.Mode == "Chase" then
		-- Perdió al objetivo (se escapó, murió, entró en la zona segura): vuelve a su sitio
		setMode(state, "Return")
		return
	else
		humanoid.WalkSpeed = Config.MonsterSetting(def, "WalkSpeed") * slowMult
		if now >= state.NextWander then
			state.NextWander = now + rng:NextNumber(4, 9)
			-- A veces pasea un poco y a veces se queda quieto mirando alrededor
			state.WanderGoal = if rng:NextNumber() < 0.6 then wanderPoint(state) else nil
		end
		if state.WanderGoal then
			if flat(state.WanderGoal - position).Magnitude < 1.5 then
				state.WanderGoal = nil
			else
				moveTo(state, state.WanderGoal, params, now)
				wantsToMove = true
			end
		end
	end
	checkStuck(state, now, wantsToMove)
end

--------------------------------------------------------------------------------
-- Buscar monstruos (los usa Combat para los ataques)
--------------------------------------------------------------------------------

local function radiusOf(state)
	return math.max(state.Size.X, state.Size.Z) / 2
end
Monsters.RadiusOf = radiusOf

-- Monstruos delante de un CFrame (ataque normal)
function Monsters.InFront(cframe, range)
	local found = {}
	for _, state in active do
		if state.Humanoid.Health > 0 then
			local offset = state.Root.Position - cframe.Position
			local horizontal = flat(offset)
			if horizontal.Magnitude <= range + radiusOf(state) then
				if horizontal.Magnitude < 4 or cframe.LookVector:Dot(horizontal.Unit) > 0.2 then
					table.insert(found, state)
				end
			end
		end
	end
	return found
end

-- Monstruos en una línea recta (cortes, torrentes)
function Monsters.InLine(origin, direction, length, width)
	local found = {}
	local flatDirection = Vector3.new(direction.X, 0, direction.Z)
	if flatDirection.Magnitude < 0.01 then
		return found
	end
	flatDirection = flatDirection.Unit

	for _, state in active do
		if state.Humanoid.Health > 0 then
			local offset = state.Root.Position - origin
			offset = Vector3.new(offset.X, 0, offset.Z)
			local along = offset:Dot(flatDirection)
			local sideways = (offset - flatDirection * along).Magnitude
			local radius = radiusOf(state)
			if along >= -2 and along <= length + radius and sideways <= width / 2 + radius then
				table.insert(found, state)
			end
		end
	end
	return found
end

-- Monstruos dentro de un círculo (explosiones, raíces)
function Monsters.InRadius(center, radius)
	local found = {}
	for _, state in active do
		if state.Humanoid.Health > 0 then
			local offset = state.Root.Position - center
			local horizontal = flat(offset)
			if horizontal.Magnitude <= radius + radiusOf(state) then
				table.insert(found, state)
			end
		end
	end
	return found
end

--------------------------------------------------------------------------------
-- Efectos
--------------------------------------------------------------------------------

function Monsters.Slow(state, mult, duration)
	state.SlowMult = mult
	state.SlowUntil = math.max(state.SlowUntil, os.clock() + duration)
end

function Monsters.Root(state, duration)
	state.RootedUntil = math.max(state.RootedUntil, os.clock() + duration)
end

function Monsters.Burn(state, player, tickDamage, duration)
	state.BurnBy = player
	state.BurnDamage = math.max(state.BurnDamage, tickDamage)
	state.BurnUntil = math.max(state.BurnUntil, os.clock() + duration)
	state.NextBurnTick = math.max(state.NextBurnTick, os.clock() + 0.5)
	setBurning(state, true)
end

-- Empujón de algunas habilidades: solo en horizontal (antes también lo lanzaba hacia arriba
-- con una fuerza enorme y los monstruos ligeros salían volando). La gravedad sigue actuando
-- y la fuerza va según el peso del monstruo.
function Monsters.Knockback(state, direction, power)
	local horizontal = flat(direction)
	local root = state.Root
	if horizontal.Magnitude < 0.01 or state.RootedUntil > os.clock() or state.Dead or root.Anchored then
		return
	end
	if state.Mode == "Return" then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.PrimaryTangentAxis = Vector3.xAxis
	velocity.SecondaryTangentAxis = Vector3.zAxis
	local push = horizontal.Unit * power
	velocity.PlaneVelocity = Vector2.new(push.X, push.Z)
	velocity.MaxForce = root.AssemblyMass * 800
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.Parent = root
	task.delay(0.2, function()
		velocity:Destroy()
		attachment:Destroy()
	end)
end

--------------------------------------------------------------------------------
-- Absorber
--------------------------------------------------------------------------------

-- Reserva esencias cerca del personaje para la secuencia de absorción (Combat las mueve
-- y las destruye al terminar). Con all = false, solo la más cercana; con all = true
-- (Habilidad Única), todas las que estén dentro del alcance.
-- Devuelve una lista de { Orb = pieza, Id = monsterId, Level = nivel } (vacía si no hay nada).
function Monsters.ReserveEssences(character, range, all)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return {}
	end

	local picked = {}
	local closest, closestDistance = nil, range
	for orb in essences do
		local distance = (orb.Position - root.Position).Magnitude
		if distance <= range then
			if all then
				table.insert(picked, orb)
			elseif distance <= closestDistance then
				closest, closestDistance = orb, distance
			end
		end
	end
	if closest then
		table.insert(picked, closest)
	end

	local results = {}
	for _, orb in picked do
		table.insert(results, {
			Orb = orb,
			Id = orb:GetAttribute("MonsterId"),
			Level = orb:GetAttribute("MonsterLevel") or 1,
		})
		-- Ya no flota, no caduca y nadie más puede absorberla
		essences[orb].Bob:Cancel()
		essences[orb] = nil
		local label = orb:FindFirstChildOfClass("BillboardGui")
		if label then
			label:Destroy()
		end
	end
	return results
end

--------------------------------------------------------------------------------
-- Inicio
--------------------------------------------------------------------------------

-- Para la autocomprobación: ¿tiene diseño este monstruo?
function Monsters.HasBuilder(monsterId)
	local def = Config.Monsters[monsterId]
	if def == nil or builders[def.Builder or monsterId] == nil then
		return false
	end
	-- Los modelos de Blender necesitan un diseño de piezas por si no están importados
	return def.MeshModel == nil or builders[def.FallbackBuilder] ~= nil
end

-- Para la autocomprobación
function Monsters.GetSlots()
	return slots
end
function Monsters.GetActive()
	return active
end

function Monsters.Start()
	monsterFolder = Instance.new("Folder")
	monsterFolder.Name = "Monsters"
	monsterFolder.Parent = Workspace

	essenceFolder = Instance.new("Folder")
	essenceFolder.Name = "Essences"
	essenceFolder.Parent = Workspace

	effectsFolder = Instance.new("Folder")
	effectsFolder.Name = "Effects"
	effectsFolder.Parent = Workspace
	Monsters.EffectsFolder = effectsFolder

	-- Sitios de aparición: MaxMonsters por zona (aparecen poco a poco al empezar)
	for _, zone in Config.Zones do
		if #zone.Spawns > 0 then
			for _ = 1, zone.MaxMonsters do
				table.insert(slots, { Zone = zone, Entry = nil, Home = nil, Model = nil, RespawnAt = #slots * 0.4 })
			end
		end
	end
	local startTime = os.clock()
	for _, slot in slots do
		slot.RespawnAt += startTime
	end
	task.spawn(function()
		while true do
			local now = os.clock()
			for _, slot in slots do
				if not slot.Model and now >= slot.RespawnAt then
					trySpawn(slot, now)
				end
			end
			task.wait(0.5)
		end
	end)

	-- Inteligencia y limpieza de esencias
	task.spawn(function()
		while true do
			local now = os.clock()
			local params = sightParams()
			for _, state in active do
				updateMonster(state, now, params)
			end
			for orb, info in essences do
				if now >= info.Expires then
					info.Bob:Cancel()
					essences[orb] = nil
					orb:Destroy()
				end
			end
			task.wait(0.25)
		end
	end)
end

return Monsters
