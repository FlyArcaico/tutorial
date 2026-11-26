-- Reproductor de animaciones de los personajes R6 (cada jugador lo ejecuta para todos):
-- mezcla reposo / andar / correr según la velocidad, salto y caída, y encima por capas
-- la espada al hombro, la guardia y los golpes (puñetazos alternos, combos de espada...).
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

-- Ataque normal según el estilo que manda el servidor
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
	local torso = character:WaitForChild("Torso", 10)
	if not humanoid or not root or not torso then
		warn("[Slime Rebirth] Animaciones: el personaje no es R6", character:GetFullName())
		return
	end
	local joints = {
		Torso = root:WaitForChild("RootJoint", 5),
		Head = torso:WaitForChild("Neck", 5),
		RightShoulder = torso:WaitForChild("Right Shoulder", 5),
		LeftShoulder = torso:WaitForChild("Left Shoulder", 5),
		RightHip = torso:WaitForChild("Right Hip", 5),
		LeftHip = torso:WaitForChild("Left Hip", 5),
	}
	for _, joint in joints do
		if not joint then
			return
		end
	end
	removeDefaultAnimations(character, humanoid)
	character.ChildAdded:Connect(function(child)
		if child.Name == "Animate" then
			task.defer(child.Destroy, child)
		end
	end)

	tracked[character] = {
		Player = Players:GetPlayerFromCharacter(character),
		Humanoid = humanoid,
		Root = root,
		Joints = joints,
		-- Tiempos de cada animación de fondo
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
		ActionWeight = 0,
		NextHand = 1,
		Combo = 0,
		LastAttack = 0,
	}
end

local function watchPlayer(player)
	if player.Character then
		task.spawn(setup, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		setup(character)
	end)
end

local function getWeapon(state)
	local player = state.Player
	if not player then
		return nil
	end
	local raceId = player:GetAttribute("Race")
	local race = raceId and Config.Races[raceId]
	if race and race.CanAbsorb then
		return nil -- el Slime no lleva armas
	end
	local weaponId = player:GetAttribute("Equipped")
	return weaponId and Config.Weapons[weaponId]
end

-- Lo llama el cliente cuando el servidor avisa de un ataque (AttackFx)
function Animator.PlayAttack(character, style)
	local state = tracked[character]
	if not state then
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

local function animate(state, dt)
	local humanoid, root = state.Humanoid, state.Root
	local player = state.Player
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local inAir = humanoid.FloorMaterial == Enum.Material.Air
	local sprinting = player ~= nil and player:GetAttribute("Sprinting") == true
	local guarding = player ~= nil and player:GetAttribute("Guarding") == true
	local weapon = getWeapon(state)

	-- Pesos suavizados
	state.Move = approach(state.Move, if speed > 0.8 and not inAir then 1 else 0, 10, dt)
	state.Running = approach(state.Running, if sprinting and speed > 4 then 1 else 0, 8, dt)
	state.Air = approach(state.Air, if inAir then 1 else 0, 12, dt)
	state.Guard = approach(state.Guard, if guarding then 1 else 0, 14, dt)
	state.Carry = approach(state.Carry, if weapon and not guarding then 1 else 0, 10, dt)

	-- Tiempos: andar y correr avanzan según la velocidad real (así los pies no patinan)
	state.IdleTime += dt
	state.WalkTime += dt * math.clamp(speed / WALK_SPEED_REFERENCE, 0.5, 1.6)
	state.RunTime += dt * math.clamp(speed / RUN_SPEED_REFERENCE, 0.6, 1.5)
	if inAir then
		state.AirTime += dt
		state.FallTime += dt
	else
		state.AirTime = 0
	end

	-- Capa base: reposo -> andar -> correr
	local pose = AnimationData.Sample(Anim.Idle, state.IdleTime)
	layer(pose, AnimationData.Sample(Anim.Walk, state.WalkTime), state.Move)
	layer(pose, AnimationData.Sample(Anim.Run, state.RunTime), state.Move * state.Running)

	-- En el aire: subiendo = salto, bajando = caída
	if state.Air > 0.01 then
		local airPose = if velocity.Y > 1
			then AnimationData.Sample(Anim.Jump, state.AirTime)
			else AnimationData.Sample(Anim.Fall, state.FallTime)
		layer(pose, airPose, state.Air)
	end

	-- Espada al hombro y guardia (solo la parte de arriba)
	layer(pose, AnimationData.Sample(Anim.SwordCarry, 0), state.Carry)
	layer(pose, AnimationData.Sample(if weapon then Anim.GuardSword else Anim.Guard, state.IdleTime), state.Guard)

	-- Golpe en curso: entra rápido y sale suave al final
	local action = state.Action
	if action then
		state.ActionTime += dt * state.ActionSpeed
		local t = state.ActionTime
		if t >= action.Length then
			state.Action = nil
		else
			local fadeIn = math.min(1, t / 0.04)
			local fadeOut = math.min(1, (action.Length - t) / 0.1)
			layer(pose, AnimationData.Sample(action, t), math.min(fadeIn, fadeOut))
		end
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
			if not character.Parent or state.Humanoid.Health <= 0 then
				tracked[character] = nil
				continue
			end
			animate(state, dt)
		end
	end)
end

return Animator
