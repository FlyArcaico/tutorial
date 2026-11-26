-- Monstruos: aparecen con un nivel según la zona, tienen su propio diseño, barra de vida
-- encima y números de daño. Persiguen y atacan a los jugadores. Al morir sueltan una
-- esencia (si los derrota un Slime). También gestiona efectos: quemadura, ralentización,
-- raíces y empujones.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local MeshRig = require(script.Parent.MeshRig)

local Monsters = {}

local rng = Random.new()
local monsterFolder
local essenceFolder
local effectsFolder
local active = {} -- [Model] = state
local essences = {} -- [Part] = { Expires = number, Bob = Tween }
local zoneCounts = {} -- [zone] = monstruos vivos
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

-- Busca un sitio libre dentro de la zona: fuera de la zona segura y sin árboles, rocas,
-- casas u otros monstruos encima. Si no encuentra ninguno, devuelve nil.
local GROUND_NAMES = { Ground = true, Path = true, StoneGround = true }
local function findSpawnPoint(zone)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { essenceFolder, effectsFolder }
	for _ = 1, 10 do
		local point = randomPointInZone(zone)
		if not Config.IsInSafeZone(point) then
			local blocked = false
			for _, part in
				Workspace:GetPartBoundsInBox(CFrame.new(point + Vector3.new(0, 3, 0)), Vector3.new(4, 5, 4), params)
			do
				if not GROUND_NAMES[part.Name] then
					blocked = true
					break
				end
			end
			if not blocked then
				return point
			end
		end
	end
	return nil
end

local function spawnMonster(monsterId, zone, levels)
	local def = Config.Monsters[monsterId]
	local position = findSpawnPoint(zone)
	if not position then
		return -- no hay sitio libre ahora; se intentará en el siguiente ciclo
	end
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
	root.CFrame = CFrame.new(position + Vector3.new(0, hipHeight + size.Y / 2 + 0.5, 0))
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
	humanoid.WalkSpeed = def.WalkSpeed or Config.BaseSpeed
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	humanoid.Parent = model

	local state = {
		Id = monsterId,
		Def = def,
		Level = level,
		Stats = stats,
		Size = size,
		Zone = zone,
		Model = model,
		Humanoid = humanoid,
		Root = root,
		TopOffset = topOffset,
		Home = position, -- pasea cerca de donde apareció
		LastAttack = 0,
		AttackingUntil = 0,
		NextWander = 0,
		LastHitBy = nil, -- el último jugador que le pegó se lleva la muerte
		SlowUntil = 0,
		SlowMult = 1,
		RootedUntil = 0,
		BurnUntil = 0,
		BurnDamage = 0,
		BurnBy = nil,
		NextBurnTick = 0,
	}
	createHealthBar(state, def.DisplayName, level)

	model.Parent = monsterFolder
	root:SetNetworkOwner(nil) -- el servidor mueve a los monstruos, así se ven bien para todos

	active[model] = state
	zoneCounts[zone] = (zoneCounts[zone] or 0) + 1

	humanoid.Died:Connect(function()
		active[model] = nil
		zoneCounts[zone] -= 1

		local killer = state.LastHitBy
		if killer and killer.Parent and killHandler and killHandler(killer, monsterId, level) then
			createEssence(monsterId, level, root.Position)
		end

		local bar = root:FindFirstChild("HealthBar")
		if bar then
			bar:Destroy()
		end
		-- Los monstruos con animación de muerte (Goblin) se quedan quietos mientras caen
		local corpseTime = def.CorpseTime or 1
		if def.CorpseTime then
			root.AssemblyLinearVelocity = Vector3.zero
			root.Anchored = true
		end
		task.delay(corpseTime - 0.9, function()
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

--------------------------------------------------------------------------------
-- Inteligencia
--------------------------------------------------------------------------------

local function findTarget(state)
	local bestCharacter, bestDistance = nil, state.Def.AggroRange
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		-- Los jugadores dentro de la zona segura no pueden ser atacados
		if humanoid and root and humanoid.Health > 0 and not Config.IsInSafeZone(root.Position) then
			local distance = (root.Position - state.Root.Position).Magnitude
			if distance < bestDistance then
				bestCharacter, bestDistance = character, distance
			end
		end
	end
	return bestCharacter, bestDistance
end

function Monsters.Damage(state, player, amount, color)
	if state.Humanoid.Health <= 0 then
		return
	end
	amount = math.max(1, math.floor(amount + 0.5))
	state.LastHitBy = player
	state.Humanoid:TakeDamage(amount)
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

-- Punto para pasear: cerca de su sitio (si lo tiene) y siempre dentro de la zona
local function wanderPoint(state)
	local radius = state.Def.WanderRadius
	if not radius or not state.Home then
		return randomPointInZone(state.Zone)
	end
	local angle = rng:NextNumber(0, math.pi * 2)
	local point = state.Home + Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(3, radius)
	local zone = state.Zone
	if (point - zone.Center).Magnitude > zone.Radius then
		point = zone.Center + (point - zone.Center).Unit * zone.Radius * 0.9
	end
	return point
end

local function updateMonster(state, now)
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
	if humanoid.Health <= 0 then
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

	-- Zona segura: si un monstruo se acerca demasiado, sale de ella
	local safe = Config.SafeZone
	local fromSafe = state.Root.Position - safe.Center
	fromSafe = Vector3.new(fromSafe.X, 0, fromSafe.Z)
	if fromSafe.Magnitude < safe.Radius + 4 then
		local away = if fromSafe.Magnitude > 0.1 then fromSafe.Unit else Vector3.new(0, 0, -1)
		humanoid:MoveTo(safe.Center + away * (safe.Radius + 15))
		return
	end

	local zone = state.Zone
	local awayFromHome = (state.Root.Position - zone.Center).Magnitude > zone.Radius + 30

	local target, distance = nil, math.huge
	if not awayFromHome then
		target, distance = findTarget(state)
	end

	-- Velocidad: paseando o persiguiendo (cada monstruo puede tener las suyas)
	local baseSpeed = if target then def.ChaseSpeed or Config.BaseSpeed else def.WalkSpeed or Config.BaseSpeed
	humanoid.WalkSpeed = baseSpeed * slowMult

	if target then
		local targetRoot = target.HumanoidRootPart
		humanoid:MoveTo(targetRoot.Position)

		local reach = def.AttackReach or (math.max(state.Size.X, state.Size.Z) / 2 + 3.5 + def.HipHeight)
		if distance <= reach and now - state.LastAttack >= (def.AttackCooldown or 1.2) then
			state.LastAttack = now
			-- Los clientes ven este cambio y reproducen la animación de ataque
			state.Model:SetAttribute("AttackTick", (state.Model:GetAttribute("AttackTick") or 0) + 1)

			local function hit()
				if playerDamageHandler then
					-- Combat aplica resistencias y el bloqueo (Guard)
					playerDamageHandler(target, state.Stats.Damage, def.Magic == true)
				else
					target.Humanoid:TakeDamage(state.Stats.Damage)
				end
			end

			local windup = def.AttackWindup or 0
			if windup <= 0 then
				hit()
			else
				-- El golpe llega cuando baja el arma: si el jugador se aleja a tiempo, falla
				state.AttackingUntil = now + windup + 0.15
				humanoid:Move(Vector3.zero)
				task.delay(windup, function()
					local targetHumanoid = target:FindFirstChildOfClass("Humanoid")
					local stillAlive = humanoid.Health > 0 and targetHumanoid and targetHumanoid.Health > 0
					if stillAlive and target.Parent and state.RootedUntil <= os.clock() then
						local gap = (target.HumanoidRootPart.Position - state.Root.Position).Magnitude
						if gap <= reach * 1.2 then
							hit()
						end
					end
				end)
			end
		end
	elseif awayFromHome then
		humanoid:MoveTo(zone.Center)
	elseif now >= state.NextWander then
		state.NextWander = now + rng:NextNumber(3, 7)
		humanoid:MoveTo(wanderPoint(state))
	end
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
			local flat = Vector3.new(offset.X, 0, offset.Z)
			if flat.Magnitude <= range + radiusOf(state) then
				if flat.Magnitude < 4 or cframe.LookVector:Dot(flat.Unit) > 0.2 then
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
			local flat = Vector3.new(offset.X, 0, offset.Z)
			if flat.Magnitude <= radius + radiusOf(state) then
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

function Monsters.Knockback(state, direction, power)
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.01 or state.RootedUntil > os.clock() then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Parent = state.Root
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.MaxForce = 1e6
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VectorVelocity = flat.Unit * power + Vector3.new(0, 8, 0)
	velocity.Parent = state.Root
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

	-- Rellenar cada zona poco a poco
	task.spawn(function()
		while true do
			for _, zone in Config.Zones do
				if (zoneCounts[zone] or 0) < zone.MaxMonsters and #zone.Spawns > 0 then
					local entry = pickSpawn(zone)
					spawnMonster(entry.Monster, zone, entry.Levels)
				end
			end
			task.wait(2)
		end
	end)

	-- Inteligencia y limpieza de esencias
	task.spawn(function()
		while true do
			local now = os.clock()
			for _, state in active do
				updateMonster(state, now)
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
