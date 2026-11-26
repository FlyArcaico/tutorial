-- Animaciones procedurales para personajes R6 (todos los jugadores las ven en su pantalla):
-- andar/correr con más balanceo, respiración en reposo, pose en el aire y una animación
-- de ataque distinta según la raza o el arma. Se calculan moviendo las articulaciones
-- (Motor6D.Transform) en cada frame, así no hace falta subir animaciones a Roblox.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Animator = {}

local tracked = {} -- [character] = estado

-- Duración de cada animación de ataque (segundos)
local ATTACK_DURATION = {
	Punch = 0.3,
	Swift = 0.36,
	Smash = 0.5,
	Cast = 0.42,
	Slash = 0.34,
}

local function bump(t, from, to)
	-- 0 -> 1 -> 0 entre "from" y "to"
	if t < from or t > to then
		return 0
	end
	return math.sin((t - from) / (to - from) * math.pi)
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
		Humanoid = humanoid,
		Root = root,
		Joints = joints,
		Phase = 0,
		Amplitude = 0,
		AttackStyle = nil,
		AttackStart = 0,
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
	if state and ATTACK_DURATION[style] then
		state.AttackStyle = style
		state.AttackStart = os.clock()
	end
end

local function animate(state, dt, now)
	local humanoid, root, joints = state.Humanoid, state.Root, state.Joints
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local inAir = humanoid.FloorMaterial == Enum.Material.Air

	-- Balanceo: más rápido y más amplio cuanto más rápido vas (al correr se nota mucho)
	local targetAmplitude = if speed > 1 then math.clamp(speed / 16, 0.4, 1.7) * 0.65 else 0
	state.Amplitude += (targetAmplitude - state.Amplitude) * math.min(1, dt * 10)
	state.Phase += dt * (3 + speed * 0.42)
	local swing = math.sin(state.Phase) * state.Amplitude
	local bob = math.abs(math.cos(state.Phase)) * state.Amplitude * 0.18
	local breathe = math.sin(now * 2) * 0.04

	local rightArm = swing + breathe
	local leftArm = swing - breathe
	local rightLeg = -swing
	local leftLeg = -swing
	local twist = math.sin(state.Phase) * state.Amplitude * 0.15
	local rootOffset = bob

	if inAir then
		-- En el aire: brazos arriba y piernas un poco dobladas
		rightArm, leftArm = 2.4, -2.4
		rightLeg, leftLeg = 0.4, -0.4
		twist, rootOffset = 0, 0
	end

	-- Animación de ataque (se suma encima)
	local style = state.AttackStyle
	if style then
		local t = (now - state.AttackStart) / ATTACK_DURATION[style]
		if t >= 1 then
			state.AttackStyle = nil
		elseif style == "Punch" then
			-- Puñetazo directo con la derecha
			local k = bump(t, 0, 1)
			rightArm = 1.65 * k + rightArm * (1 - k)
			twist += 0.35 * k
		elseif style == "Swift" then
			-- Elf: dos golpes rápidos, derecha y luego izquierda
			local first, second = bump(t, 0, 0.5), bump(t, 0.5, 1)
			rightArm = 1.6 * first + rightArm * (1 - first)
			leftArm = -1.6 * second + leftArm * (1 - second)
			twist += 0.3 * first - 0.3 * second
		elseif style == "Smash" then
			-- Ogre: sube los dos brazos y machaca hacia abajo
			local raise = if t < 0.55 then math.sin(t / 0.55 * math.pi / 2) else 1 - (t - 0.55) / 0.45
			local arms = if t < 0.55 then 3 * raise else 1.2 + 1.8 * raise
			rightArm, leftArm = arms, -arms
			rootOffset -= if t > 0.55 then 0.25 * (1 - raise) else 0
		elseif style == "Cast" then
			-- Invocado: mano derecha hacia delante, como lanzando magia
			local k = bump(t, 0, 1)
			rightArm = 1.55 * math.min(1, k * 1.6) + rightArm * (1 - k)
			leftArm = -0.5 * k + leftArm * (1 - k)
		elseif style == "Slash" then
			-- Espada: tajo de arriba hacia abajo y delante
			local eased = 1 - (1 - t) ^ 3
			rightArm = 2.7 - 2.2 * eased
			twist += -0.35 + 0.8 * eased
		end
	end

	joints.RightShoulder.Transform = CFrame.Angles(0, 0, rightArm)
	joints.LeftShoulder.Transform = CFrame.Angles(0, 0, leftArm)
	joints.RightHip.Transform = CFrame.Angles(0, 0, rightLeg)
	joints.LeftHip.Transform = CFrame.Angles(0, 0, leftLeg)
	-- En RootJoint y Neck el eje Z apunta hacia arriba
	joints.Root.Transform = CFrame.new(0, 0, rootOffset) * CFrame.Angles(0, 0, twist)
	joints.Neck.Transform = CFrame.Angles(0, 0, -twist * 0.6)
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
