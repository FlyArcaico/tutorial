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
			-- Bloquear
			Guard = Config.Guard.Max,
			WantGuard = false, -- el jugador mantiene F
			Guarding = false,
			GuardBrokenUntil = 0,
			GuardLocked = false, -- tras romperse, no se puede bloquear hasta recuperar un poco
			LastGuard = 0,
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

-- Onda plana que se expande por el suelo
local function playShockwave(center, radius, color)
	local ring = effectPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 2, 2),
		Color = color,
		Transparency = 0.2,
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
	})
	tweenAndDestroy(ring, 0.4, { Size = Vector3.new(0.4, radius * 2, radius * 2), Transparency = 1 })
end

-- Slime (robada al murciélago): onda alrededor que daña y aturde
function abilityHandlers.SonicScreech(player, root, ability, damage)
	local center = root.Position
	for _, target in Monsters.InRadius(center, ability.Radius) do
		Monsters.Damage(target, player, damage, ability.Color)
		Monsters.Root(target, ability.StunDuration) -- aturdido: no se mueve ni ataca
	end
	playShockwave(center - Vector3.new(0, 1.5, 0), ability.Radius, ability.Color)
	playShockwave(center, ability.Radius * 0.7, ability.Color)
end

-- Slime (robada al gólem): golpe al suelo delante que daña y empuja
function abilityHandlers.RockFist(player, root, ability, damage)
	local flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	local center = Vector3.new(root.Position.X, 0.5, root.Position.Z) + flat * ability.Distance
	for _, target in Monsters.InRadius(center, ability.Radius) do
		Monsters.Damage(target, player, damage, ability.Color)
		local away = target.Root.Position - center
		Monsters.Knockback(target, if away.Magnitude > 0.1 then away else flat, ability.Knockback)
	end
	playExplosion(center, ability.Radius * 0.6, ability.Color)
	playShockwave(center, ability.Radius, ability.Color)

	-- Rocas que saltan del suelo
	for index = 1, 6 do
		local angle = index / 6 * math.pi * 2
		local rock = effectPart({
			Material = Enum.Material.Slate,
			Size = Vector3.one * 1.4,
			Color = Color3.fromRGB(120, 110, 100),
			CFrame = CFrame.new(center + Vector3.new(math.cos(angle) * 3, 0, math.sin(angle) * 3))
				* CFrame.Angles(angle, angle, 0),
		})
		tweenAndDestroy(rock, 0.6, {
			CFrame = rock.CFrame * CFrame.new(0, 4, 0) * CFrame.Angles(1, 1, 0),
			Transparency = 1,
		})
	end
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
	local race = Config.Races[slot.Race]
	local weaponId = if race.CanAbsorb then nil else slot.Equipped
	local weapon = weaponId and Config.Weapons[weaponId]
	local now = os.clock()
	-- Un poco de margen por el retraso de red
	if now - state.LastAttack < Config.AttackCooldown(weaponId) * 0.85 then
		return
	end
	if state.Guarding or state.GuardBrokenUntil > now then
		return -- no se puede pegar mientras bloqueas o estás aturdido
	end
	state.LastAttack = now
	state.LastCombat = now
	state.Hits = (state.Hits or 0) + 1

	local body = Config.GetBody(slot.Race, slot.Level)
	local range = Config.AttackRange(slot.Level, slot.Race) + (if weapon then 1.5 else 0)
	local stats = PlayerData.GetStats(player)
	local damage = Config.AttackDamage(stats, slot.Race, slot.Level, slot.Skills, weaponId)
		* stateDamageMult(state, race)
	local root = character.HumanoidRootPart

	-- Color del golpe: según la raza, el elemento o la rareza del arma
	local style = Config.GetAttackStyle(slot.Race, weaponId)
	local color = Config.AttackStyles[style].Color
	if weapon then
		color = Config.Rarities[weapon.Rarity].Color
	elseif race.Element then
		color = Config.Abilities[race.Abilities[1]].Color
	elseif race.CanAbsorb then
		color = body.Color
	end
	if state.Berserk then
		color = Color3.fromRGB(255, 50, 40)
	end

	local passive = weapon and weapon.Passive and Config.WeaponPassives[weapon.Passive]
	for _, target in Monsters.InFront(root.CFrame, range) do
		Monsters.Damage(target, player, damage, color)
		if weapon and weapon.Passive == "DoubleHit" and math.random() < passive.Chance then
			task.delay(0.12, function()
				Monsters.Damage(target, player, damage, color)
			end)
		elseif weapon and weapon.Passive == "Burn" then
			Monsters.Burn(target, player, damage * passive.TickDamageMult, passive.Duration)
		end
	end

	-- Hoja estelar: cada X golpes lanza una onda de energía
	if weapon and weapon.Passive == "StarWave" and state.Hits % passive.EveryHits == 0 then
		local direction = root.CFrame.LookVector
		for _, target in Monsters.InLine(root.Position, direction, passive.Range, passive.Width) do
			Monsters.Damage(target, player, damage * passive.DamageMult, passive.Color)
		end
		playLineEffect(
			root.Position,
			direction,
			{ Color = passive.Color, Range = passive.Range },
			passive.Width,
			0.3,
			3
		)
	end

	-- Solo el Invocado lanza energía con el clic; los demás golpean con el puño o el arma
	if race.Element then
		playAttackEffect(root, color, body.Size, range)
	end
	-- Todos los jugadores ven la animación de ataque de este personaje
	Remotes.AttackFx:FireAllClients(character, style, color)
end

local function onCast(player, abilityId)
	local slot = PlayerData.Get(player)
	local character = getAliveCharacter(player)
	if not slot or not character or type(abilityId) ~= "string" then
		return
	end
	local ability = Config.Abilities[abilityId]
	if not ability or not Config.CanUseAbility(slot.Race, slot.Skills, abilityId) then
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
	local damage = Config.AbilityDamage(PlayerData.GetStats(player), slot.Race, abilityId)
		* stateDamageMult(state, race)
	abilityHandlers[abilityId](player, character.HumanoidRootPart, ability, damage)
	-- Todos ven la animación de lanzar la habilidad (el Slime brilla por dentro)
	Remotes.AttackFx:FireAllClients(character, if race.CanAbsorb then "SlimeCast" else "Cast")

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

	-- Absorber -> Devorador -> Habilidad Única: más alcance, y la última absorbe todo lo cercano
	local tier = Config.GetAbsorbTier(slot.Level)
	local absorbed = Monsters.TryAbsorb(character, tier.Range, tier.AreaAbsorb)
	if #absorbed == 0 then
		notify(player, "No hay nada que absorber cerca", GREY)
		return
	end

	Remotes.AttackFx:FireAllClients(character, "SlimeCast")
	local successes = 0
	for _, essence in absorbed do
		local chance = Config.AbsorbChance(slot.Level, essence.Level)
		if math.random() <= chance then
			successes += 1
			PlayerData.Absorb(player, essence.Id, essence.Level)
		else
			PlayerData.AbsorbFailed(player, essence.Id, essence.Level, chance)
		end
	end

	-- Devorador y la Habilidad Única te curan y te dan maná al absorber
	if successes > 0 then
		local _, humanoid = getAliveCharacter(player)
		local state = getState(player)
		if humanoid and tier.HealOnAbsorb > 0 then
			humanoid.Health =
				math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * tier.HealOnAbsorb * successes)
		end
		if tier.ManaOnAbsorb > 0 then
			local maxMana = Config.MaxMana(PlayerData.GetStats(player), slot.Race)
			state.Mana = math.min(maxMana, state.Mana + maxMana * tier.ManaOnAbsorb * successes)
		end
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

-- (La postura de correr ahora la anima el cliente, en Animator.luau)

local function tick(player, dt, now)
	local slot = PlayerData.Get(player)
	local character, humanoid = getAliveCharacter(player)
	if not slot or not character then
		return
	end
	local state = getState(player)
	local race = Config.Races[slot.Race]
	local outOfCombat = now - state.LastCombat >= Config.OutOfCombatDelay

	-- Maná (Espíritu hace que se regenere más rápido)
	local stats = PlayerData.GetStats(player)
	local maxMana = Config.MaxMana(stats, slot.Race)
	local regen = if outOfCombat then race.ManaRegenOutOfCombat else Config.ManaRegenInCombat
	state.Mana = math.min(maxMana, state.Mana + maxMana * regen * Config.ManaRegenMult(stats) * dt)

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
	local maxStamina = Config.MaxStamina(stats, slot.Race) -- Agilidad da más stamina
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
		state.Stamina = math.min(maxStamina, state.Stamina + stamina.Regen * dt)
	end
	if state.Exhausted and state.Stamina >= maxStamina * Config.Sprint.ExhaustedRecover then
		state.Exhausted = false
	end
	if sprinting ~= state.Sprinting then
		state.Sprinting = sprinting
	end

	-- Bloquear: mantener F (no el Slime). La barra se gasta al recibir golpes.
	local hasSword = slot.Equipped ~= nil and not race.CanAbsorb
	local maxGuard = Config.Guard.Max + (if hasSword then Config.Guard.SwordBonus else 0)
	local stunned = state.GuardBrokenUntil > now
	local guarding = state.WantGuard and not race.CanAbsorb and not stunned and not state.GuardLocked
	if guarding then
		state.LastGuard = now
	elseif now - state.LastGuard >= Config.Guard.RegenDelay then
		state.Guard = math.min(maxGuard, state.Guard + Config.Guard.RegenPerSecond * dt)
	end
	state.Guard = math.min(state.Guard, maxGuard)
	if state.GuardLocked and state.Guard >= maxGuard * Config.Guard.RecoverFraction then
		state.GuardLocked = false
	end
	state.Guarding = guarding

	-- Velocidad
	local speed = Config.WalkSpeed(stats, slot.Race)
	if sprinting then
		speed *= stamina.SpeedMult
	end
	if state.Berserk and race.Berserk then
		speed *= race.Berserk.SpeedMult
	end
	if overloaded then
		speed *= Config.Overload.SpeedMult
	end
	if guarding then
		speed *= Config.Guard.SpeedMult
	end
	if stunned then
		speed *= 0.3
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
	player:SetAttribute("MaxStamina", maxStamina)
	player:SetAttribute("Sprinting", sprinting)
	player:SetAttribute("Exhausted", state.Exhausted)
	player:SetAttribute("InSafeZone", inSafeZone)
	player:SetAttribute("Guard", math.floor(state.Guard))
	player:SetAttribute("MaxGuard", maxGuard)
	player:SetAttribute("Guarding", guarding)
	player:SetAttribute("GuardBroken", stunned or state.GuardLocked)
end

-- Daño de los monstruos a un jugador: resistencias y bloqueo
function Combat.DamagePlayer(character, damage, isMagic)
	local player = Players:GetPlayerFromCharacter(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local slot = player and PlayerData.Get(player)
	if not slot then
		humanoid:TakeDamage(damage)
		return
	end

	local stats = PlayerData.GetStats(player)
	local resist = if isMagic then Config.MagicResist(stats, slot.Race) else Config.PhysicalResist(stats, slot.Race)
	damage *= 1 - resist

	local state = getState(player)
	state.LastCombat = os.clock()
	if state.Guarding then
		-- Bloqueado: no hace daño, pero gasta la barra de bloqueo
		state.Guard -= damage
		state.LastGuard = os.clock()
		if state.Guard <= 0 then
			state.Guard = 0
			state.Guarding = false
			state.GuardLocked = true
			state.GuardBrokenUntil = os.clock() + Config.Guard.BreakStun
			notify(player, "¡Bloqueo roto! Estás aturdido", Color3.fromRGB(255, 120, 90))
		end
		return
	end
	humanoid:TakeDamage(damage)
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
	state.WantGuard = false
	state.Guarding = false
	state.GuardLocked = false
	state.GuardBrokenUntil = 0
	state.Guard = Config.Guard.Max

	-- Empezar con el maná y la stamina llenos
	local slot = PlayerData.Get(player)
	if slot then
		local stats = PlayerData.GetStats(player)
		state.Mana = Config.MaxMana(stats, slot.Race)
		state.Stamina = Config.MaxStamina(stats, slot.Race)
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

--------------------------------------------------------------------------------
-- Usar objetos del inventario
--------------------------------------------------------------------------------

local lastPotion = {} -- [Player] = tiempo

function Combat.UseItem(player, itemId)
	local slot = PlayerData.Get(player)
	local item = type(itemId) == "string" and Config.Items[itemId]
	local character, humanoid = getAliveCharacter(player)
	if not slot or not item or not character then
		return { Ok = false, Message = "No puedes usar eso ahora" }
	end

	local isPotion = item.Effect ~= "Spin" and item.Effect ~= "StatReset"
	local now = os.clock()
	if isPotion and now - (lastPotion[player] or 0) < Config.PotionCooldown then
		return { Ok = false, Message = "Espera un poco antes de otra poción" }
	end
	if not PlayerData.TakeItem(player, itemId) then
		return { Ok = false, Message = "No te quedan" }
	end

	local state = getState(player)
	if item.Effect == "Heal" then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * item.Amount)
	elseif item.Effect == "Mana" then
		local maxMana = Config.MaxMana(PlayerData.GetStats(player), slot.Race)
		state.Mana = math.min(maxMana, state.Mana + maxMana * item.Amount)
	elseif item.Effect == "Stamina" then
		local maxStamina = Config.MaxStamina(PlayerData.GetStats(player), slot.Race)
		state.Stamina = math.min(maxStamina, state.Stamina + maxStamina * item.Amount)
		state.Exhausted = false
	elseif item.Effect == "StatReset" then
		PlayerData.ResetStatPoints(player)
	elseif item.Effect == "Spin" then
		PlayerData.AddSpins(player, item.Amount)
	end

	if isPotion then
		lastPotion[player] = now
	end
	notify(player, "Usaste " .. item.Name, item.Color)
	return { Ok = true }
end

-- Para la autocomprobación: ¿tiene código esta habilidad?
function Combat.HasAbilityHandler(abilityId)
	return abilityHandlers[abilityId] ~= nil
end

function Combat.Start()
	Remotes.Attack.OnServerEvent:Connect(onAttack)
	Remotes.Cast.OnServerEvent:Connect(onCast)
	Remotes.Absorb.OnServerEvent:Connect(onAbsorb)
	Remotes.UseItem.OnServerInvoke = function(player, itemId)
		return Combat.UseItem(player, itemId)
	end
	Remotes.Sprint.OnServerEvent:Connect(function(player, wantsToSprint)
		getState(player).WantSprint = wantsToSprint == true
	end)
	Remotes.Guard.OnServerEvent:Connect(function(player, wantsToGuard)
		getState(player).WantGuard = wantsToGuard == true
	end)
	Monsters.SetPlayerDamageHandler(Combat.DamagePlayer)

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
		lastPotion[player] = nil
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
