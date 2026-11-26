-- Combate de los jugadores: ataque normal, habilidades especiales (gastan maná),
-- absorber, maná y su regeneración, Sobrecarga de Energía (Invocados),
-- Berserker (Ogre) y Regeneración (Slime).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Monsters = require(script.Parent.Monsters)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)

local Combat = {}

local GREY = Color3.fromRGB(180, 180, 180)
local states = {} -- [Player] = estado de combate

local function getState(player)
	local state = states[player]
	if not state then
		state = {
			Mana = 0,
			Heat = 0, -- sobrecarga acumulada
			OverloadUntil = 0,
			Berserk = false,
			LastCombat = 0,
			LastAttack = 0,
			Cooldowns = {},
			-- Correr
			Stamina = 0,
			WantSprint = false, -- el jugador mantiene Control
			Sprinting = false, -- está corriendo de verdad (se mueve y tiene stamina)
			Exhausted = false, -- se quedó sin stamina: no puede correr hasta recuperarse
			LastSprint = 0,
			PoseBase = nil, -- posición original de las articulaciones (para la postura de carrera)
			PoseCharacter = nil,
		}
		states[player] = state
	end
	return state
end

local function notify(player, text, color)
	Remotes.Notify:FireClient(player, text, color)
end

local function getAliveCharacter(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 and character:FindFirstChild("HumanoidRootPart") then
		return character, humanoid
	end
	return nil, nil
end

-- Multiplicador de daño por estados (Berserker, Sobrecarga)
local function stateDamageMult(state, race)
	local mult = 1
	if state.Berserk and race.Berserk then
		mult *= race.Berserk.DamageMult
	end
	if state.OverloadUntil > os.clock() then
		mult *= Config.Overload.DamageMult
	end
	return mult
end

--------------------------------------------------------------------------------
-- Efectos visuales
--------------------------------------------------------------------------------

local function effectPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		part[key] = value
	end
	part.Parent = Monsters.EffectsFolder
	return part
end

local function tweenAndDestroy(part, duration, goal)
	local tween = TweenService:Create(part, TweenInfo.new(duration), goal)
	tween.Completed:Connect(function()
		part:Destroy()
	end)
	tween:Play()
end

local function sphereMesh(part)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
end

-- Ataque normal: una explosión rápida delante del personaje
local function playAttackEffect(root, color, size, range)
	local splash = effectPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * size,
		Color = color,
		Transparency = 0.4,
		Position = (root.CFrame * CFrame.new(0, -1, -range / 2)).Position,
	})
	tweenAndDestroy(splash, 0.25, { Size = Vector3.one * range, Transparency = 1 })
end

-- Corte de viento / torrente: piezas que vuelan hacia delante
local function playLineEffect(origin, direction, ability, width, thickness, pieces)
	local flat = Vector3.new(direction.X, 0, direction.Z).Unit
	local start = CFrame.lookAt(origin, origin + flat)
	for index = 1, pieces do
		local back = -(index - 1) * 1.4
		local piece = effectPart({
			Size = Vector3.new(width, thickness, 1.4),
			Color = ability.Color:Lerp(Color3.new(1, 1, 1), if index == 1 then 0.4 else 0),
			Transparency = if index == 1 then 0.1 else 0.45,
			CFrame = start * CFrame.new(0, 0, back),
		})
		sphereMesh(piece)
		tweenAndDestroy(piece, 0.35, {
			CFrame = start * CFrame.new(0, 0, back - ability.Range),
			Transparency = 1,
		})
	end
end

local function playExplosion(position, radius, color)
	local blast = effectPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2,
		Color = color,
		Transparency = 0.2,
		Position = position,
	})
	tweenAndDestroy(blast, 0.35, { Size = Vector3.one * radius * 2, Transparency = 1 })
end

-- Raíces: pinchos verdes que salen del suelo
local function playRootsEffect(center, radius, color, duration)
	for index = 1, 14 do
		local angle = index / 14 * math.pi * 2
		local distance = if index % 2 == 0 then radius * 0.8 else radius * 0.4
		local position = center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		local spike = effectPart({
			Material = Enum.Material.Grass,
			Size = Vector3.new(0.8, 0.1, 0.8),
			Color = color,
			CFrame = CFrame.new(position) * CFrame.Angles(math.rad(10), angle, math.rad(10)),
		})
		TweenService:Create(spike, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
			Size = Vector3.new(0.8, 4, 0.8),
			CFrame = spike.CFrame * CFrame.new(0, 2, 0),
		}):Play()
		task.delay(duration, function()
			tweenAndDestroy(spike, 0.3, { Transparency = 1 })
		end)
	end
end

local function playVinesOn(target, duration)
	local root = target.Root
	local vine = effectPart({
		Material = Enum.Material.Grass,
		Shape = Enum.PartType.Cylinder,
		Color = Color3.fromRGB(60, 150, 50),
		Transparency = 0.15,
		Size = Vector3.new(1, root.Size.X + 1.2, root.Size.Z + 1.2),
		CFrame = CFrame.new(root.Position - Vector3.new(0, root.Size.Y / 2 - 0.3, 0))
			* CFrame.Angles(0, 0, math.rad(90)),
	})
	task.delay(duration, function()
		tweenAndDestroy(vine, 0.3, { Transparency = 1 })
	end)
end

--------------------------------------------------------------------------------
-- Habilidades
--------------------------------------------------------------------------------

local abilityHandlers = {}

function abilityHandlers.AirSlash(player, root, ability, damage)
	local origin, direction = root.Position, root.CFrame.LookVector
	for _, target in Monsters.InLine(origin, direction, ability.Range, ability.Width) do
		Monsters.Damage(target, player, damage, ability.Color)
	end
	playLineEffect(origin, direction, ability, ability.Width, 0.25, 2)
end

function abilityHandlers.WaterTorrent(player, root, ability, damage)
	local origin, direction = root.Position, root.CFrame.LookVector
	for _, target in Monsters.InLine(origin, direction, ability.Range, ability.Width) do
		Monsters.Damage(target, player, damage, ability.Color)
		Monsters.Slow(target, ability.Slow.Mult, ability.Slow.Duration)
		Monsters.Knockback(target, direction, ability.Knockback)
	end
	playLineEffect(origin, direction, ability, ability.Width, 2.5, 4)
end

function abilityHandlers.PlantRoots(player, root, ability, damage)
	local flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	local center = Vector3.new(root.Position.X, 0.2, root.Position.Z) + flat * ability.Distance

	local dealt = 0
	for _, target in Monsters.InRadius(center, ability.Radius) do
		Monsters.Damage(target, player, damage, ability.Color)
		Monsters.Root(target, ability.RootDuration)
		playVinesOn(target, ability.RootDuration)
		dealt += damage
	end
	playRootsEffect(center, ability.Radius, ability.Color, ability.RootDuration)

	-- Robo de vida
	local humanoid = root.Parent:FindFirstChildOfClass("Humanoid")
	if humanoid and dealt > 0 then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + dealt * ability.Lifesteal)
	end
end

function abilityHandlers.Fireball(player, root, ability, damage)
	local flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	local position = root.Position + flat * 3

	local ball = effectPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2.5,
		Color = ability.Color,
		Position = position,
	})
	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Color = ability.Color
	fire.SecondaryColor = Color3.fromRGB(255, 220, 80)
	fire.Parent = ball
	local light = Instance.new("PointLight")
	light.Color = ability.Color
	light.Range = 14
	light.Parent = ball

	local function explode(at)
		ball:Destroy()
		playExplosion(at, ability.Radius, ability.Color)
		for _, target in Monsters.InRadius(at, ability.Radius) do
			Monsters.Damage(target, player, damage, ability.Color)
			Monsters.Burn(target, player, damage * ability.Burn.TickDamageMult, ability.Burn.Duration)
		end
	end

	-- El proyectil avanza cada frame hasta chocar con un monstruo o llegar a su alcance
	local traveled = 0
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		local step = ability.Speed * dt
		position += flat * step
		traveled += step
		ball.Position = position

		if #Monsters.InRadius(position, 1.5) > 0 or traveled >= ability.Range then
			connection:Disconnect()
			explode(position)
		end
	end)
end

--------------------------------------------------------------------------------
-- Acciones del jugador
--------------------------------------------------------------------------------

local function onAttack(player)
	local slot = PlayerData.Get(player)
	local character = getAliveCharacter(player)
	if not slot or not character then
		return
	end
	local state = getState(player)
	local now = os.clock()
	if now - state.LastAttack < Config.Attack.Cooldown then
		return
	end
	state.LastAttack = now
	state.LastCombat = now

	local race = Config.Races[slot.Race]
	local body = Config.GetBody(slot.Race, slot.Level)
	local range = Config.AttackRange(slot.Level, slot.Race)
	local damage = Config.AttackDamage(slot.Level, slot.Race) * stateDamageMult(state, race)
	local root = character.HumanoidRootPart

	for _, target in Monsters.InFront(root.CFrame, range) do
		Monsters.Damage(target, player, damage)
	end
	local color = if race.Element then Config.Abilities[race.Abilities[1]].Color else body.Color
	if state.Berserk then
		color = Color3.fromRGB(255, 50, 40)
	end
	playAttackEffect(root, color, body.Size, range)
end

local function onCast(player, abilityId)
	local slot = PlayerData.Get(player)
	local character = getAliveCharacter(player)
	if not slot or not character or type(abilityId) ~= "string" then
		return
	end
	local ability = Config.Abilities[abilityId]
	if not ability or not Config.HasAbility(slot.Race, abilityId) then
		return
	end

	local state = getState(player)
	local now = os.clock()
	if now - (state.Cooldowns[abilityId] or 0) < ability.Cooldown then
		return
	end
	if state.Mana < ability.ManaCost then
		notify(player, "No tienes suficiente maná (" .. ability.ManaCost .. ")", Color3.fromRGB(120, 160, 255))
		return
	end

	state.Cooldowns[abilityId] = now
	state.LastCombat = now
	state.Mana -= ability.ManaCost

	local race = Config.Races[slot.Race]
	local damage = Config.AbilityDamage(slot.Level, slot.Race, abilityId) * stateDamageMult(state, race)
	abilityHandlers[abilityId](player, character.HumanoidRootPart, ability, damage)

	-- Sobrecarga de Energía: usar habilidades muy seguido acumula calor
	if race.Overload then
		state.Heat += Config.Overload.HeatPerCast
		if state.Heat >= Config.Overload.Threshold and state.OverloadUntil <= now then
			state.Heat = 0
			state.OverloadUntil = now + Config.Overload.Duration
			notify(player, "¡Sobrecarga de Energía! Menos daño y velocidad un momento", Color3.fromRGB(255, 150, 60))
		end
	end
end

local function onAbsorb(player)
	local slot = PlayerData.Get(player)
	local character = getAliveCharacter(player)
	if not slot or not character then
		return
	end
	if not Config.Races[slot.Race].CanAbsorb then
		notify(player, "Solo la raza Slime puede absorber", GREY)
		return
	end

	local monsterId, monsterLevel = Monsters.TryAbsorb(character)
	if not monsterId then
		notify(player, "No hay nada que absorber cerca", GREY)
		return
	end

	local chance = Config.AbsorbChance(slot.Level, monsterLevel)
	if math.random() <= chance then
		PlayerData.Absorb(player, monsterId, monsterLevel)
	else
		PlayerData.AbsorbFailed(player, monsterId, monsterLevel, chance)
	end
end

--------------------------------------------------------------------------------
-- Bucle: maná, calor, Berserker, regeneración y velocidad
--------------------------------------------------------------------------------

local function setBerserkVisual(character, enabled)
	local highlight = character:FindFirstChild("BerserkGlow")
	if enabled and not highlight then
		highlight = Instance.new("Highlight")
		highlight.Name = "BerserkGlow"
		highlight.FillColor = Color3.fromRGB(255, 40, 30)
		highlight.FillTransparency = 0.75
		highlight.OutlineColor = Color3.fromRGB(255, 90, 60)
		highlight.Parent = character
	elseif not enabled and highlight then
		highlight:Destroy()
	end
end

-- Postura de carrera (R6): se inclina hacia delante y echa los brazos atrás.
-- Se hace en el servidor para que todos los jugadores la vean.
local POSE_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad)
local RUN_POSE = {
	RootJoint = CFrame.Angles(math.rad(-18), 0, 0), -- inclinarse
	Neck = CFrame.Angles(math.rad(12), 0, 0), -- mirar al frente
	RightShoulder = CFrame.Angles(math.rad(-45), 0, 0), -- brazos atrás
	LeftShoulder = CFrame.Angles(math.rad(-45), 0, 0),
}

local function setRunPose(state, character, running)
	local torso = character:FindFirstChild("Torso")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not torso or not root then
		return
	end
	local joints = {
		RootJoint = root:FindFirstChild("RootJoint"),
		Neck = torso:FindFirstChild("Neck"),
		RightShoulder = torso:FindFirstChild("Right Shoulder"),
		LeftShoulder = torso:FindFirstChild("Left Shoulder"),
	}
	-- Guardar la postura original la primera vez (después de escalar al Ogre)
	if state.PoseCharacter ~= character then
		state.PoseCharacter = character
		state.PoseBase = {}
		for name, joint in joints do
			state.PoseBase[name] = joint.C0
		end
	end

	for name, joint in joints do
		local base = state.PoseBase[name]
		if base then
			local goal = if running then CFrame.new(base.Position) * RUN_POSE[name] * base.Rotation else base
			TweenService:Create(joint, POSE_TWEEN, { C0 = goal }):Play()
		end
	end
end

local function tick(player, dt, now)
	local slot = PlayerData.Get(player)
	local character, humanoid = getAliveCharacter(player)
	if not slot or not character then
		return
	end
	local state = getState(player)
	local race = Config.Races[slot.Race]
	local outOfCombat = now - state.LastCombat >= Config.OutOfCombatDelay

	-- Maná
	local maxMana = Config.MaxMana(slot.Level, slot.Race)
	local regen = if outOfCombat then race.ManaRegenOutOfCombat else Config.ManaRegenInCombat
	state.Mana = math.min(maxMana, state.Mana + maxMana * regen * dt)

	-- Sobrecarga: el calor baja con el tiempo
	state.Heat = math.max(0, state.Heat - Config.Overload.DecayPerSecond * dt)
	local overloaded = state.OverloadUntil > now

	-- Berserker (Ogre)
	if race.Berserk then
		local berserk = humanoid.Health / humanoid.MaxHealth < race.Berserk.Threshold
		if berserk ~= state.Berserk then
			state.Berserk = berserk
			setBerserkVisual(character, berserk)
			if berserk then
				notify(player, "¡MODO BERSERKER! Más daño y velocidad", Color3.fromRGB(255, 70, 50))
			end
		end
	end

	-- Regeneración de vida (Slime) fuera de combate
	if race.HealthRegen > 0 and outOfCombat and humanoid.Health < humanoid.MaxHealth then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * race.HealthRegen * dt)
	end

	-- Zona segura: te curas
	local root = character.HumanoidRootPart
	local inSafeZone = Config.IsInSafeZone(root.Position)
	if inSafeZone and humanoid.Health < humanoid.MaxHealth then
		humanoid.Health =
			math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * Config.SafeZone.HealPerSecond * dt)
	end

	-- Correr y stamina
	local stamina = race.Stamina
	local velocity = root.AssemblyLinearVelocity
	local moving = Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 2
	local sprinting = state.WantSprint and moving and not state.Exhausted and state.Stamina > 0
	if sprinting then
		state.Stamina = math.max(0, state.Stamina - stamina.Drain * dt)
		state.LastSprint = now
		if state.Stamina <= 0 then
			state.Exhausted = true
			sprinting = false
		end
	elseif now - state.LastSprint >= Config.Sprint.RegenDelay then
		state.Stamina = math.min(stamina.Max, state.Stamina + stamina.Regen * dt)
	end
	if state.Exhausted and state.Stamina >= stamina.Max * Config.Sprint.ExhaustedRecover then
		state.Exhausted = false
	end
	if sprinting ~= state.Sprinting then
		state.Sprinting = sprinting
		if not race.CanAbsorb then
			setRunPose(state, character, sprinting)
		end
	end

	-- Velocidad
	local speed = Config.WalkSpeed(slot.Race)
	if sprinting then
		speed *= stamina.SpeedMult
	end
	if state.Berserk and race.Berserk then
		speed *= race.Berserk.SpeedMult
	end
	if overloaded then
		speed *= Config.Overload.SpeedMult
	end
	if math.abs(humanoid.WalkSpeed - speed) > 0.01 then
		humanoid.WalkSpeed = speed
	end

	-- El HUD lee estos atributos
	player:SetAttribute("Mana", math.floor(state.Mana))
	player:SetAttribute("MaxMana", maxMana)
	player:SetAttribute("Heat", if race.Overload then state.Heat / Config.Overload.Threshold else 0)
	player:SetAttribute("Overloaded", overloaded)
	player:SetAttribute("Berserk", state.Berserk)
	player:SetAttribute("InCombat", not outOfCombat)
	player:SetAttribute("Stamina", math.floor(state.Stamina))
	player:SetAttribute("MaxStamina", stamina.Max)
	player:SetAttribute("Sprinting", sprinting)
	player:SetAttribute("Exhausted", state.Exhausted)
	player:SetAttribute("InSafeZone", inSafeZone)
end

local function onCharacterAdded(player, character)
	local state = getState(player)
	state.Berserk = false
	state.Heat = 0
	state.OverloadUntil = 0
	state.LastCombat = 0
	state.Sprinting = false
	state.WantSprint = false
	state.Exhausted = false
	state.PoseCharacter = nil

	-- Empezar con el maná y la stamina llenos
	local slot = PlayerData.Get(player)
	if slot then
		state.Mana = Config.MaxMana(slot.Level, slot.Race)
		state.Stamina = Config.Races[slot.Race].Stamina.Max
	end

	-- Recibir daño cuenta como estar en combate
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		local lastHealth = humanoid.Health
		humanoid.HealthChanged:Connect(function(health)
			if health < lastHealth then
				state.LastCombat = os.clock()
			end
			lastHealth = health
		end)
	end
end

function Combat.Start()
	Remotes.Attack.OnServerEvent:Connect(onAttack)
	Remotes.Cast.OnServerEvent:Connect(onCast)
	Remotes.Absorb.OnServerEvent:Connect(onAbsorb)
	Remotes.Sprint.OnServerEvent:Connect(function(player, wantsToSprint)
		getState(player).WantSprint = wantsToSprint == true
	end)

	local function onPlayerAdded(player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

	local last = os.clock()
	task.spawn(function()
		while true do
			task.wait(0.1)
			local now = os.clock()
			local dt = now - last
			last = now
			for _, player in Players:GetPlayers() do
				tick(player, dt, now)
			end
		end
	end)
end

return Combat
