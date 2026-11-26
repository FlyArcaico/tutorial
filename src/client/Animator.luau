-- Animaciones procedurales para personajes R6 (cada jugador las calcula para todos):
-- andar y correr fluidos (piernas, brazos y torso), respiración en reposo, salto/caída,
-- bloqueo (Guard) y golpes: puñetazos alternando derecha/izquierda, tajo con espada, etc.
-- Se hacen moviendo las articulaciones (Motor6D.Transform) cada frame.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Animator = {}

local tracked = {} -- [character] = estado

-- Duración de cada animación de ataque (segundos)
local ATTACK_DURATION = {
	Punch = 0.32,
	Swift = 0.24, -- Elf: puñetazos más rápidos
	Smash = 0.5,
	Cast = 0.42,
	Slash = 0.38,
}

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function smooth(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function approach(current, target, rate, dt)
	return current + (target - current) * math.min(1, rate * dt)
end

local function setup(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	local torso = character:WaitForChild("Torso", 10)
	if not humanoid or not root or not torso then
		return -- no es R6
	end
	local joints = {
		Root = root:WaitForChild("RootJoint", 5),
		Neck = torso:WaitForChild("Neck", 5),
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
	tracked[character] = {
		Player = Players:GetPlayerFromCharacter(character),
		Humanoid = humanoid,
		Root = root,
		Joints = joints,
		Phase = 0,
		Amplitude = 0,
		Lean = 0,
		Guard = 0,
		Air = 0,
		NextHand = 1, -- 1 = derecha, -1 = izquierda
		AttackStyle = nil,
		AttackStart = 0,
		AttackHand = 1,
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

function Animator.PlayAttack(character, style)
	local state = tracked[character]
	if not state or not ATTACK_DURATION[style] then
		return
	end
	state.AttackStyle = style
	state.AttackStart = os.clock()
	-- Los puñetazos alternan: primero derecha, luego izquierda
	if style == "Punch" or style == "Swift" then
		state.AttackHand = state.NextHand
		state.NextHand = -state.NextHand
	else
		state.AttackHand = 1
	end
end

-- Ángulo del brazo para un puñetazo: atrás (preparar) -> delante rápido -> volver
local function punchCurve(t, base)
	if t < 0.25 then
		return lerp(base, -0.45, smooth(t / 0.25)), 0
	elseif t < 0.5 then
		local k = smooth((t - 0.25) / 0.25)
		return lerp(-0.45, 1.75, k), k
	end
	local k = smooth((t - 0.5) / 0.5)
	return lerp(1.75, base, k), 1 - k
end

local function animate(state, dt, now)
	local humanoid, root, joints = state.Humanoid, state.Root, state.Joints
	local player = state.Player
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local running = player ~= nil and player:GetAttribute("Sprinting") == true
	local guarding = player ~= nil and player:GetAttribute("Guarding") == true
	local inAir = humanoid.FloorMaterial == Enum.Material.Air

	-- Suavizar cambios (empezar/parar de andar, inclinarse al correr, guardia, aire)
	local moving = speed > 0.6 and not inAir
	local targetAmplitude = if moving then (if running then 1.1 else math.clamp(speed / 16, 0.35, 1) * 0.72) else 0
	state.Amplitude = approach(state.Amplitude, targetAmplitude, 9, dt)
	state.Lean = approach(state.Lean, if running and moving then 0.3 else (if moving then 0.06 else 0), 7, dt)
	state.Guard = approach(state.Guard, if guarding then 1 else 0, 14, dt)
	state.Air = approach(state.Air, if inAir then 1 else 0, 10, dt)

	-- La zancada va con la distancia recorrida: así los pies no "patinan"
	if moving then
		state.Phase += dt * math.max(speed * 0.55, 4)
	else
		-- Al pararse, las piernas vuelven poco a poco al centro
		state.Phase = approach(state.Phase, math.floor(state.Phase / math.pi + 0.5) * math.pi, 6, dt)
	end

	local amplitude = state.Amplitude
	local cycle = math.sin(state.Phase)
	local legSwing = cycle * amplitude
	local armSwing = cycle * amplitude * (if running then 1.15 else 0.85)

	-- Base: andar/correr (brazos al revés que las piernas)
	local rightArm, leftArm = armSwing, armSwing
	local rightLeg, leftLeg = -legSwing, -legSwing
	-- El torso sube y baja dos veces por zancada, gira un poco con los hombros y se balancea
	local bob = -math.abs(cycle) * 0.12 * amplitude + 0.06 * amplitude
	local twist = cycle * 0.13 * amplitude
	local roll = math.cos(state.Phase) * 0.04 * amplitude
	local lean = state.Lean

	-- Respirar en reposo
	local idle = 1 - math.min(1, amplitude * 2)
	local breathe = math.sin(now * 1.8) * 0.035 * idle
	rightArm += breathe
	leftArm -= breathe
	bob += math.sin(now * 1.8) * 0.02 * idle

	-- En el aire: brazos arriba y piernas separadas
	local air = state.Air
	local rising = velocity.Y > 2
	rightArm = lerp(rightArm, if rising then 2.1 else 2.6, air)
	leftArm = lerp(leftArm, if rising then -2.1 else -2.6, air)
	rightLeg = lerp(rightLeg, 0.35, air)
	leftLeg = lerp(leftLeg, 0.35, air)

	-- Bloqueo: brazos en guardia delante y un poco agachado
	local guard = state.Guard
	rightArm = lerp(rightArm, 1.5, guard)
	leftArm = lerp(leftArm, -1.5, guard)
	bob = lerp(bob, -0.2, guard)
	twist = lerp(twist, 0, guard)

	-- Ataques
	local style = state.AttackStyle
	if style then
		local t = (now - state.AttackStart) / ATTACK_DURATION[style]
		if t >= 1 then
			state.AttackStyle = nil
		elseif style == "Punch" or style == "Swift" then
			-- Puñetazo con un brazo (alterna en cada golpe) y el torso gira hacia ese lado
			local hand = state.AttackHand
			local angle, strike = punchCurve(t, if hand == 1 then rightArm else -leftArm)
			if hand == 1 then
				rightArm = angle
			else
				leftArm = -angle
			end
			twist += hand * 0.4 * strike
			lean += 0.1 * strike
		elseif style == "Slash" then
			-- Espada: levantar, tajo rápido de arriba abajo, volver
			local raised, strike
			if t < 0.3 then
				raised, strike = lerp(rightArm, 2.9, smooth(t / 0.3)), 0
			elseif t < 0.55 then
				local k = smooth((t - 0.3) / 0.25)
				raised, strike = lerp(2.9, 0.35, k), k
			else
				local k = smooth((t - 0.55) / 0.45)
				raised, strike = lerp(0.35, rightArm, k), 1 - k
			end
			rightArm = raised
			twist += -0.3 + 0.75 * strike
			lean += 0.15 * strike
		elseif style == "Smash" then
			-- Ogre: sube los dos brazos y machaca hacia abajo
			local up = if t < 0.55 then smooth(t / 0.55) else 1 - smooth((t - 0.55) / 0.45)
			local arms = if t < 0.55 then 3 * up else 1.2 + 1.8 * up
			rightArm, leftArm = arms, -arms
			if t > 0.55 then
				bob -= 0.25 * (1 - up)
				lean += 0.2 * (1 - up)
			end
		elseif style == "Cast" then
			-- Invocado: mano derecha hacia delante como lanzando magia
			local k = math.sin(t * math.pi)
			rightArm = lerp(rightArm, 1.6, math.min(1, k * 1.6))
			leftArm = lerp(leftArm, -0.5, k)
			lean += 0.08 * k
		end
	end

	-- Aplicar. En RootJoint y Neck: X = inclinar adelante/atrás, Y = ladear, Z = girar (eje vertical)
	joints.RightShoulder.Transform = CFrame.Angles(0, 0, rightArm)
	joints.LeftShoulder.Transform = CFrame.Angles(0, 0, leftArm)
	joints.RightHip.Transform = CFrame.Angles(0, 0, rightLeg)
	joints.LeftHip.Transform = CFrame.Angles(0, 0, leftLeg)
	joints.Root.Transform = CFrame.new(0, 0, bob) * CFrame.Angles(lean, roll, twist)
	-- La cabeza compensa para seguir mirando al frente
	joints.Neck.Transform = CFrame.Angles(-lean * 0.7, -roll, -twist * 0.7)
end

function Animator.Start()
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)

	-- PreSimulation va después de las animaciones de Roblox: así las nuestras mandan
	RunService.PreSimulation:Connect(function(dt)
		local now = os.clock()
		for character, state in tracked do
			if not character.Parent or state.Humanoid.Health <= 0 then
				tracked[character] = nil
				continue
			end
			animate(state, dt, now)
		end
	end)
end

return Animator
