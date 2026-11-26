-- Monstruos: aparecen con un nivel según la zona, tienen su propio diseño, barra de vida
-- encima y números de daño. Persiguen y atacan a los jugadores. Al morir sueltan una
-- esencia (si los derrota un Slime). También gestiona efectos: quemadura, ralentización,
-- raíces y empujones.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

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

local function randomPointInZone(zone)
	local angle = rng:NextNumber(0, math.pi * 2)
	local distance = math.sqrt(rng:NextNumber()) * zone.Radius
	return zone.Center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
end

--------------------------------------------------------------------------------
-- Diseño de cada monstruo
--------------------------------------------------------------------------------

-- Cada builder recibe add(name, size, offset, color, props) para pegar piezas al cuerpo
local builders = {}

function builders.Bat(root, add, s, color, eyeColor)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = root

	local wing = color:Lerp(BLACK, 0.35)
	for _, side in { -1, 1 } do
		add(
			"Wing",
			Vector3.new(2.4, 0.15, 1.4) * s,
			CFrame.new(side * 2 * s, 0.3 * s, 0.1 * s) * CFrame.Angles(0, 0, side * math.rad(20)),
			wing
		)
		add(
			"WingTip",
			Vector3.new(1.2, 0.12, 0.9) * s,
			CFrame.new(side * 3.6 * s, 0.85 * s, 0.3 * s) * CFrame.Angles(0, 0, side * math.rad(35)),
			wing:Lerp(BLACK, 0.2)
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
	add("Head", Vector3.new(1.8, 1.7, 1.8) * s, CFrame.new(0, 0.7 * s, -2.6 * s), color)
	add("Snout", Vector3.new(0.9, 0.7, 1.1) * s, CFrame.new(0, 0.35 * s, -3.9 * s), light)
	add("Nose", Vector3.new(0.4, 0.3, 0.2) * s, CFrame.new(0, 0.6 * s, -4.5 * s), BLACK)
	add(
		"Tail",
		Vector3.new(0.45, 0.45, 2) * s,
		CFrame.new(0, 0.8 * s, 2.9 * s) * CFrame.Angles(math.rad(35), 0, 0),
		dark
	)
	for _, side in { -1, 1 } do
		add(
			"Ear",
			Vector3.new(0.45, 0.75, 0.3) * s,
			CFrame.new(side * 0.55 * s, 1.85 * s, -2.4 * s) * CFrame.Angles(0, 0, -side * 0.2),
			dark
		)
		add(
			"Eye",
			Vector3.one * 0.3 * s,
			CFrame.new(side * 0.45 * s, 0.95 * s, -3.5 * s),
			eyeColor,
			{ Shape = Enum.PartType.Ball, Material = Enum.Material.Neon }
		)
		for _, z in { -1.5, 1.5 } do
			add("Leg", Vector3.new(0.6, 1.6, 0.6) * s, CFrame.new(side * 0.8 * s, -1.9 * s, z * s), dark)
		end
	end
end

function builders.Golem(root, add, s, color, eyeColor)
	root.Material = Enum.Material.Slate
	local dark = color:Lerp(BLACK, 0.25)
	local moss = Color3.fromRGB(80, 130, 60)
	local slate = { Material = Enum.Material.Slate }

	add("Head", Vector3.new(2.2, 1.8, 2.2) * s, CFrame.new(0, 3.1 * s, -0.2 * s), color, slate)
	add("Core", Vector3.new(1, 1, 0.3) * s, CFrame.new(0, 0.6 * s, -1.75 * s), eyeColor, {
		Material = Enum.Material.Neon,
	})
	for _, side in { -1, 1 } do
		add("Arm", Vector3.new(1.6, 4.2, 1.6) * s, CFrame.new(side * 3.1 * s, -0.4 * s, 0), dark, slate)
		add("Fist", Vector3.new(2, 1.6, 2) * s, CFrame.new(side * 3.1 * s, -3 * s, 0), color, slate)
		add("Leg", Vector3.new(1.8, 2.8, 1.8) * s, CFrame.new(side * 1.2 * s, -3.6 * s, 0), dark, slate)
		add(
			"Moss",
			Vector3.new(1.8, 0.4, 1.8) * s,
			CFrame.new(side * 3.1 * s, 1.85 * s, 0),
			moss,
			{ Material = Enum.Material.Grass }
		)
		add(
			"Eye",
			Vector3.new(0.45, 0.3, 0.1) * s,
			CFrame.new(side * 0.5 * s, 3.2 * s, -1.32 * s),
			eyeColor,
			{ Material = Enum.Material.Neon }
		)
	end
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

local function spawnMonster(monsterId, zone)
	local def = Config.Monsters[monsterId]
	local level = rng:NextInteger(zone.Levels[1], zone.Levels[2])
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
	local position = randomPointInZone(zone)
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

	local function add(name, partSize, offset, partColor, props)
		local part = Instance.new("Part")
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
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
		return part
	end
	builders[monsterId](root, add, s, color, def.EyeColor)

	-- Altura de la barra de vida: justo encima de la pieza más alta
	local boxCFrame, boxSize = model:GetBoundingBox()
	local topOffset = boxCFrame.Position.Y + boxSize.Y / 2 - root.Position.Y + 1.2

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = hipHeight
	humanoid.MaxHealth = stats.Health
	humanoid.Health = stats.Health
	humanoid.WalkSpeed = Config.BaseSpeed
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
		LastAttack = 0,
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
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				TweenService:Create(descendant, TweenInfo.new(0.8), { Transparency = 1 }):Play()
			end
		end
		task.delay(1, function()
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
	humanoid.WalkSpeed = Config.BaseSpeed * (if state.SlowUntil > now then state.SlowMult else 1)

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

	if target then
		local targetRoot = target.HumanoidRootPart
		humanoid:MoveTo(targetRoot.Position)

		local reach = math.max(state.Size.X, state.Size.Z) / 2 + 3.5
		if distance <= reach + state.Def.HipHeight and now - state.LastAttack >= 1.2 then
			state.LastAttack = now
			-- PlayerData pone las resistencias en el personaje según su raza
			local resist = if state.Def.Magic
				then target:GetAttribute("MagicResist")
				else target:GetAttribute("PhysicalResist")
			target.Humanoid:TakeDamage(state.Stats.Damage * (1 - (resist or 0)))
		end
	elseif awayFromHome then
		humanoid:MoveTo(zone.Center)
	elseif now >= state.NextWander then
		state.NextWander = now + rng:NextNumber(3, 7)
		humanoid:MoveTo(randomPointInZone(zone))
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

-- Absorbe la esencia más cercana al personaje. Devuelve el id y el nivel del monstruo, o nil.
function Monsters.TryAbsorb(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil, nil
	end

	local closest, closestDistance = nil, Config.AbsorbRange
	for orb in essences do
		local distance = (orb.Position - root.Position).Magnitude
		if distance <= closestDistance then
			closest, closestDistance = orb, distance
		end
	end
	if not closest then
		return nil, nil
	end

	local monsterId = closest:GetAttribute("MonsterId")
	local level = closest:GetAttribute("MonsterLevel") or 1
	essences[closest].Bob:Cancel()
	essences[closest] = nil

	-- Vuela hacia el slime y desaparece
	local suck = TweenService:Create(
		closest,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = root.Position, Size = Vector3.one * 0.2 }
	)
	suck.Completed:Connect(function()
		closest:Destroy()
	end)
	suck:Play()

	return monsterId, level
end

--------------------------------------------------------------------------------
-- Inicio
--------------------------------------------------------------------------------

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
				if (zoneCounts[zone] or 0) < zone.MaxMonsters then
					local monsterId = zone.Monsters[rng:NextInteger(1, #zone.Monsters)]
					spawnMonster(monsterId, zone)
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
