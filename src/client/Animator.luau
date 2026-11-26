-- Reproductor de animaciones de los personajes R15 (cada jugador lo ejecuta para todos).
-- Capas, de abajo arriba:
--   1. Base: reposo / andar / correr de la raza, mezclados según la velocidad.
--   2. Aire: salto y caída.     3. Aterrizar (tras caer fuerte).
--   4. Espada al hombro.        5. Guardia (F).
--   6. Golpe (puñetazos alternos, combos de espada, machaque, magia).
--   7. Recibir daño.            8. Morir (cae y se queda tumbado).
-- Las animaciones están en AnimationData.luau.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local AnimationData = require(script.Parent.AnimationData)

local Anim = AnimationData.Animations
local Animator = {}

local tracked = {} -- [character] = estado

local WALK_SPEED_REFERENCE = Config.BaseSpeed -- a esta velocidad el ciclo de andar va a velocidad normal
local RUN_SPEED_REFERENCE = Config.BaseSpeed * 1.65
local COMBO_RESET = 1.2 -- segundos sin pegar para volver al primer golpe del combo
local HARD_LANDING = -20 -- velocidad de caída para que se note el aterrizaje

-- Dónde está cada articulación de R15: { pieza, nombre del Motor6D }
local JOINT_PATHS = {
	Root = { "LowerTorso", "Root" },
	Waist = { "UpperTorso", "Waist" },
	Neck = { "Head", "Neck" },
	RS = { "RightUpperArm", "RightShoulder" },
	RE = { "RightLowerArm", "RightElbow" },
	RW = { "RightHand", "RightWrist" },
	LS = { "LeftUpperArm", "LeftShoulder" },
	LE = { "LeftLowerArm", "LeftElbow" },
	LW = { "LeftHand", "LeftWrist" },
	RH = { "RightUpperLeg", "RightHip" },
	RK = { "RightLowerLeg", "RightKnee" },
	RA = { "RightFoot", "RightAnkle" },
	LH = { "LeftUpperLeg", "LeftHip" },
	LK = { "LeftLowerLeg", "LeftKnee" },
	LA = { "LeftFoot", "LeftAnkle" },
}

-- Golpe normal según el estilo que manda el servidor
local ATTACK_ANIMATION = {
	Smash = "Smash",
	Cast = "Cast",
}

local function approach(current, target, rate, dt)
	return current + (target - current) * math.min(1, rate * dt)
end

-- Quitar el script de animación de Roblox y parar sus animaciones (si las hubiera)
local function removeDefaultAnimations(character, humanoid)
	local animate = character:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in animator:GetPlayingAnimationTracks() do
			track:Stop(0)
		end
	end
end

local function setup(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not root then
		return
	end
	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		warn("[Slime Rebirth] Animaciones: el personaje no es R15", character:GetFullName())
		return
	end

	local joints = {}
	for short, path in JOINT_PATHS do
		local part = character:WaitForChild(path[1], 5)
		local motor = part and part:WaitForChild(path[2], 5)
		if not motor then
			warn("[Slime Rebirth] Animaciones: falta la articulación", path[2])
			return
		end
		joints[short] = motor
	end

	removeDefaultAnimations(character, humanoid)
	character.ChildAdded:Connect(function(child)
		if child.Name == "Animate" then
			task.defer(child.Destroy, child)
		end
	end)

	-- Silenciar SOLO el sonido de muerte de Roblox (lo crea su script de sonidos en el
	-- HumanoidRootPart). Los pasos, el salto y demás sonidos se mantienen.
	local function muteDeathSound(child)
		if child:IsA("Sound") and child.Name == "Died" then
			child.Volume = 0
		end
	end
	for _, child in root:GetChildren() do
		muteDeathSound(child)
	end
	root.ChildAdded:Connect(muteDeathSound)

	local state = {
		Character = character,
		Player = Players:GetPlayerFromCharacter(character),
		Humanoid = humanoid,
		Root = root,
		Joints = joints,
		-- Tiempos de las animaciones de fondo
		IdleTime = 0,
		WalkTime = 0,
		RunTime = 0,
		FallTime = 0,
		AirTime = 0,
		-- Pesos (se suavizan para que las transiciones no den saltos)
		Move = 0,
		Running = 0,
		Air = 0,
		Carry = 0,
		Guard = 0,
		-- Acción (golpe) en curso
		Action = nil,
		ActionTime = 0,
		ActionSpeed = 1,
		NextHand = 1,
		Combo = 0,
		LastAttack = 0,
		-- Reacciones
		LandTime = nil,
		HurtTime = nil,
		DeathTime = nil,
		WasInAir = false,
		LowestFallSpeed = 0,
		LastHealth = humanoid.Health,
	}

	humanoid.HealthChanged:Connect(function(health)
		if health < state.LastHealth - 0.5 and health > 0 then
			state.HurtTime = 0
		end
		state.LastHealth = health
	end)
	humanoid.Died:Connect(function()
		state.DeathTime = 0
		state.Action = nil
	end)

	tracked[character] = state
end

local function watchPlayer(player)
	if player.Character then
		task.spawn(setup, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		setup(character)
	end)
end

local function getRaceId(state)
	local player = state.Player
	local raceId = player and player:GetAttribute("Race")
	return if raceId and Config.Races[raceId] then raceId else Config.DefaultRace
end

local function getWeapon(state)
	local raceId = getRaceId(state)
	if Config.Races[raceId].CanAbsorb then
		return nil -- el Slime no lleva armas
	end
	local weaponId = state.Player and state.Player:GetAttribute("Equipped")
	return weaponId and Config.Weapons[weaponId]
end

-- Lo llama el cliente cuando el servidor avisa de un ataque (AttackFx)
function Animator.PlayAttack(character, style)
	local state = tracked[character]
	if not state or state.DeathTime then
		return
	end
	-- Ha bloqueado un golpe: la guardia retrocede un momento
	if style == "Block" then
		state.BlockTime = 0
		return
	end
	local now = os.clock()
	local name, speed

	if style == "Slash" then
		-- Combo de tajos: cada espada tiene su combo y su velocidad
		local weapon = getWeapon(state)
		local combo = AnimationData.SwordCombos[if weapon then weapon.Rarity else "Common"]
		if now - state.LastAttack > COMBO_RESET then
			state.Combo = 0
		end
		state.Combo = state.Combo % #combo + 1
		name = combo[state.Combo]
		speed = 1 + (if weapon then weapon.AttackSpeed else 0)
	elseif style == "Punch" or style == "Swift" then
		-- Puñetazos alternos: derecha, izquierda, derecha...
		name = if state.NextHand == 1 then "PunchRight" else "PunchLeft"
		state.NextHand = -state.NextHand
		speed = if style == "Swift" then 1.35 else 1
	else
		name = ATTACK_ANIMATION[style]
		speed = 1
	end
	if not name or not Anim[name] then
		return
	end

	state.LastAttack = now
	state.Action = Anim[name]
	state.ActionTime = 0
	state.ActionSpeed = speed
end

-- Mezcla "overlay" encima de "pose" con un peso (solo en las articulaciones del overlay)
local function layer(pose, overlay, weight)
	if weight <= 0.001 then
		return
	end
	for joint, cframe in overlay do
		pose[joint] = pose[joint]:Lerp(cframe, weight)
	end
end

-- Animación que se reproduce una vez y se desvanece al final
local function oneShot(pose, animation, time, fadeOut)
	if time >= animation.Length then
		return false
	end
	local weight = math.min(1, time / 0.04, (animation.Length - time) / fadeOut)
	layer(pose, AnimationData.Sample(animation, time), weight)
	return true
end

local function animate(state, dt)
	local humanoid, root = state.Humanoid, state.Root
	local player = state.Player
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local inAir = humanoid.FloorMaterial == Enum.Material.Air and not state.DeathTime
	local sprinting = player ~= nil and player:GetAttribute("Sprinting") == true
	local guarding = player ~= nil and player:GetAttribute("Guarding") == true
	local weapon = getWeapon(state)
	local set = AnimationData.GetSet(getRaceId(state))

	-- Pesos suavizados
	state.Move = approach(state.Move, if speed > 0.8 and not inAir then 1 else 0, 9, dt)
	state.Running = approach(state.Running, if sprinting and speed > 4 then 1 else 0, 7, dt)
	state.Air = approach(state.Air, if inAir then 1 else 0, 12, dt)
	state.Guard = approach(state.Guard, if guarding then 1 else 0, 12, dt)
	state.Carry = approach(state.Carry, if weapon and not guarding then 1 else 0, 10, dt)

	-- Andar y correr avanzan según la velocidad real (así los pies no patinan)
	state.IdleTime += dt
	state.WalkTime += dt * math.clamp(speed / WALK_SPEED_REFERENCE, 0.5, 1.6)
	state.RunTime += dt * math.clamp(speed / RUN_SPEED_REFERENCE, 0.6, 1.5)

	-- Aire y aterrizaje
	if inAir then
		state.AirTime += dt
		state.FallTime += dt
		state.LowestFallSpeed = math.min(state.LowestFallSpeed, velocity.Y)
	else
		if state.WasInAir and state.LowestFallSpeed < HARD_LANDING then
			state.LandTime = 0
		end
		state.AirTime = 0
		state.LowestFallSpeed = 0
	end
	state.WasInAir = inAir

	-- 1. Base: reposo -> andar -> correr (mezcla suave)
	local pose = AnimationData.Sample(set.Idle, state.IdleTime)
	layer(pose, AnimationData.Sample(set.Walk, state.WalkTime), state.Move)
	layer(pose, AnimationData.Sample(set.Run, state.RunTime), state.Move * state.Running)

	-- 2. En el aire: subiendo = salto, bajando = caída
	if state.Air > 0.01 then
		local airPose = if velocity.Y > 1
			then AnimationData.Sample(Anim.Jump, state.AirTime)
			else AnimationData.Sample(Anim.Fall, state.FallTime)
		layer(pose, airPose, state.Air)
	end

	-- 3. Aterrizar
	if state.LandTime then
		state.LandTime += dt
		if not oneShot(pose, Anim.Land, state.LandTime, 0.15) then
			state.LandTime = nil
		end
	end

	-- 4 y 5. Espada al hombro y guardia
	layer(pose, AnimationData.Sample(Anim.SwordCarry, 0), state.Carry)
	layer(pose, AnimationData.Sample(if weapon then set.GuardSword else set.Guard, state.IdleTime), state.Guard)
	if state.BlockTime then
		state.BlockTime += dt
		local blockAnimation = if weapon then Anim.BlockHitSword else Anim.BlockHit
		if not oneShot(pose, blockAnimation, state.BlockTime, 0.12) then
			state.BlockTime = nil
		end
	end

	-- 6. Golpe en curso
	if state.Action then
		state.ActionTime += dt * state.ActionSpeed
		if not oneShot(pose, state.Action, state.ActionTime, 0.1) then
			state.Action = nil
		end
	end

	-- 7. Recibir daño
	if state.HurtTime then
		state.HurtTime += dt
		if not oneShot(pose, Anim.Hurt, state.HurtTime, 0.15) then
			state.HurtTime = nil
		end
	end

	-- 8. Morir: cae y se queda tumbado
	if state.DeathTime then
		state.DeathTime += dt
		layer(pose, AnimationData.Sample(Anim.Death, state.DeathTime), 1)
	end

	-- Los desplazamientos (agacharse, caer al suelo...) se ajustan al tamaño del personaje
	local scale = state.Character:GetScale()
	if scale ~= 1 then
		local rootPose = pose.Root
		pose.Root = CFrame.new(rootPose.Position * scale) * rootPose.Rotation
	end

	for joint, motor in state.Joints do
		motor.Transform = pose[joint] or CFrame.identity
	end
end

function Animator.Start()
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)

	-- PreSimulation va justo después del paso de animación de Roblox: lo nuestro manda
	RunService.PreSimulation:Connect(function(dt)
		for character, state in tracked do
			if not character.Parent then
				tracked[character] = nil
				continue
			end
			animate(state, dt)
		end
	end)
end

return Animator
