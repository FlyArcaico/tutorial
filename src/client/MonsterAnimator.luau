-- Animaciones de los monstruos (cada jugador las calcula en su pantalla):
--   Lobo: galope con las patas en diagonal, cabeza que sube y baja, cola que se mueve; mordisco.
--   Murciélago: aleteo con las puntas de las alas doblándose; ataque en picado.
--   Gólem: pasos pesados con los brazos balanceándose; golpe con los dos puños.
--   Goblin (rig R15): fotogramas clave de AnimationData.Monster (reposo, andar, correr,
--   garrotazo, recibir daño y caer muerto).
-- Mueve las articulaciones (Motor6D) que crea el servidor en Monsters.luau.
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AnimationData = require(script.Parent.AnimationData)

local MonsterAnimator = {}

local tracked = {} -- [model] = estado

local rad = math.rad

local function approach(current, target, rate, dt)
	return current + (target - current) * math.min(1, rate * dt)
end

-- En estas articulaciones X = adelante/atrás, Y = girar, Z = subir/bajar de lado
local function rotation(pitch, yaw, roll)
	return CFrame.Angles(rad(pitch or 0), rad(yaw or 0), rad(roll or 0))
end

local trackR15 -- (se define más abajo)

-- Golpe recibido: destello blanco muy breve y unas chispas (solo en pantalla, sin física)
local function hitFlash(model, root)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.35
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	TweenService:Create(highlight, TweenInfo.new(0.18), { FillTransparency = 1 }):Play()
	Debris:AddItem(highlight, 0.25)

	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, root.Size.Y * 0.4, 0)
	attachment.Parent = root
	local sparks = Instance.new("ParticleEmitter") -- textura de partículas que trae Roblox
	sparks.Rate = 0
	sparks.Lifetime = NumberRange.new(0.15, 0.3)
	sparks.Speed = NumberRange.new(8, 14)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Size = NumberSequence.new(0.35, 0)
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 245, 210))
	sparks.LightEmission = 1
	sparks.Drag = 6
	sparks.Parent = attachment
	sparks:Emit(8)
	Debris:AddItem(attachment, 0.5)
end

local function track(model)
	local root = model:WaitForChild("HumanoidRootPart", 5)
	local humanoid = model:WaitForChild("Humanoid", 5)
	if not root or not humanoid then
		return
	end
	local lastHealth = humanoid.Health
	humanoid.HealthChanged:Connect(function(health)
		if health < lastHealth - 0.5 then
			hitFlash(model, root)
		end
		lastHealth = health
	end)
	task.wait() -- que lleguen todas las piezas
	if model:GetAttribute("Rig") == "R15" then
		trackR15(model, root, humanoid)
		return
	end
	local joints = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") then
			joints[descendant.Name] = descendant
		end
	end
	local state = {
		Id = model:GetAttribute("MonsterId"),
		Root = root,
		Humanoid = humanoid,
		Joints = joints,
		Phase = math.random() * 6,
		Move = 0,
		AttackStart = -10,
		Seed = math.random() * 10,
	}
	model:GetAttributeChangedSignal("AttackTick"):Connect(function()
		state.AttackStart = os.clock()
	end)
	tracked[model] = state
end

local function set(state, name, cframe)
	local joint = state.Joints[name]
	if joint then
		joint.Transform = cframe
	end
end

--------------------------------------------------------------------------------
-- Lobo
--------------------------------------------------------------------------------

local function wolf(state, now, dt, speed)
	state.Phase += dt * math.max(speed, 0) * 0.85
	local move = state.Move
	local stride = math.sin(state.Phase) * 38 * move
	local bounce = math.sin(state.Phase * 2)

	-- Ataque: se agacha, lanza la cabeza y muerde
	local attack = 0
	local t = (now - state.AttackStart) / 0.45
	if t >= 0 and t < 1 then
		attack = math.sin(t * math.pi)
	end

	-- Patas en diagonal (delantera derecha con trasera izquierda), como un trote
	set(state, "LegRF", rotation(stride + attack * 30))
	set(state, "LegLB", rotation(stride - attack * 10))
	set(state, "LegLF", rotation(-stride + attack * 30))
	set(state, "LegRB", rotation(-stride - attack * 10))

	local breathe = math.sin(now * 2 + state.Seed) * 3 * (1 - move)
	set(
		state,
		"Neck",
		rotation(bounce * 5 * move + breathe - attack * 28, math.sin(now * 0.7 + state.Seed) * 8 * (1 - move))
	)
	-- La cola se mueve más rápido al correr
	local wag = math.sin(now * (if move > 0.3 then 12 else 4) + state.Seed) * (if move > 0.3 then 18 else 10)
	set(state, "Tail", rotation(10 * move - attack * 15, wag))
end

--------------------------------------------------------------------------------
-- Murciélago
--------------------------------------------------------------------------------

local function bat(state, now)
	local attack = 0
	local t = (now - state.AttackStart) / 0.4
	if t >= 0 and t < 1 then
		attack = math.sin(t * math.pi)
	end

	-- Aleteo: más rápido y fuerte al atacar; la punta va un poco por detrás (se dobla)
	local speed = 11 + attack * 8 + state.Move * 3
	local flap = math.sin(now * speed + state.Seed)
	local tipFlap = math.sin(now * speed + state.Seed - 0.7)
	local amplitude = 38 + attack * 15
	set(state, "WingR", rotation(attack * 25, 0, flap * amplitude))
	set(state, "WingL", rotation(attack * 25, 0, -flap * amplitude))
	set(state, "TipR", rotation(0, 0, tipFlap * 30))
	set(state, "TipL", rotation(0, 0, -tipFlap * 30))
end

--------------------------------------------------------------------------------
-- Gólem
--------------------------------------------------------------------------------

local function golem(state, now, dt, speed)
	state.Phase += dt * math.max(speed, 0) * 0.55
	local move = state.Move
	local step = math.sin(state.Phase) * 24 * move

	-- Ataque: levanta los dos brazos y los baja de golpe
	local t = (now - state.AttackStart) / 0.7
	local armsUp = 0
	if t >= 0 and t < 1 then
		if t < 0.5 then
			armsUp = 150 * math.sin(t / 0.5 * math.pi / 2)
		elseif t < 0.62 then
			armsUp = 150 - 130 * ((t - 0.5) / 0.12)
		else
			armsUp = 20 * (1 - (t - 0.62) / 0.38)
		end
	end
	local swing = step * 0.8 * (1 - math.min(1, armsUp / 40))

	set(state, "LegR", rotation(step))
	set(state, "LegL", rotation(-step))
	set(state, "ArmR", rotation(-swing + armsUp, 0, -4))
	set(state, "ArmL", rotation(swing + armsUp, 0, 4))
	local breathe = math.sin(now * 1.2 + state.Seed) * 3
	set(state, "Neck", rotation(breathe - armsUp * 0.08, math.sin(now * 0.5 + state.Seed) * 10 * (1 - move)))
end

local ANIMATE = {
	Wolf = wolf,
	Bat = bat,
	Golem = golem,
}

--------------------------------------------------------------------------------
-- Monstruos con rig R15 (Goblin...): fotogramas clave de AnimationData.Monster
--------------------------------------------------------------------------------

-- Dónde está cada articulación de R15: { pieza, nombre del Motor6D }
local R15_JOINTS = {
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

local function layer(pose, overlay, weight)
	if weight <= 0.001 then
		return
	end
	for joint, cframe in overlay do
		if pose[joint] then
			pose[joint] = pose[joint]:Lerp(cframe, weight)
		end
	end
end

local function oneShot(pose, animation, time, fadeOut)
	if time >= animation.Length then
		return false
	end
	layer(pose, AnimationData.Sample(animation, time), math.min(1, time / 0.05, (animation.Length - time) / fadeOut))
	return true
end

function trackR15(model, root, humanoid)
	local animSet = AnimationData.Monster[model:GetAttribute("AnimSet") or ""]
	if not animSet then
		return
	end
	local joints = {}
	for short, path in R15_JOINTS do
		local part = model:FindFirstChild(path[1])
		local motor = part and part:FindFirstChild(path[2])
		if not motor then
			warn("[Slime Rebirth] Monstruo R15 sin la articulación", path[2], model.Name)
			return
		end
		joints[short] = motor
	end

	local state = {
		R15 = true,
		Set = animSet,
		Root = root,
		Humanoid = humanoid,
		Joints = joints,
		Scale = model:GetAttribute("AnimScale") or 1,
		IdleTime = math.random() * 6, -- que no se muevan todos a la vez
		WalkTime = 0,
		RunTime = 0,
		Move = 0,
		Running = 0,
		AttackTime = nil,
		HurtTime = nil,
		DeathTime = nil,
		LastHealth = humanoid.Health,
	}
	model:GetAttributeChangedSignal("AttackTick"):Connect(function()
		state.AttackTime = 0
	end)
	humanoid.HealthChanged:Connect(function(health)
		if health < state.LastHealth - 0.5 and health > 0 then
			state.HurtTime = 0
		end
		state.LastHealth = health
	end)
	humanoid.Died:Connect(function()
		state.DeathTime = 0
		state.AttackTime = nil
	end)
	tracked[model] = state
end

local function animateR15(state, dt, speed)
	local animSet = state.Set
	-- Andar despacio cuando pasea, correr cuando persigue
	state.Move = approach(state.Move, if speed > 0.6 and not state.DeathTime then 1 else 0, 8, dt)
	state.Running = approach(state.Running, if speed > 9 then 1 else 0, 6, dt)
	state.IdleTime += dt
	state.WalkTime += dt * math.clamp(speed / 7, 0.5, 1.6)
	state.RunTime += dt * math.clamp(speed / 11, 0.6, 1.5)

	local pose = AnimationData.Sample(animSet.Idle, state.IdleTime)
	layer(pose, AnimationData.Sample(animSet.Walk, state.WalkTime), state.Move)
	layer(pose, AnimationData.Sample(animSet.Run, state.RunTime), state.Move * state.Running)

	if state.AttackTime then
		state.AttackTime += dt
		if not oneShot(pose, animSet.Attack, state.AttackTime, 0.15) then
			state.AttackTime = nil
		end
	end
	if state.HurtTime then
		state.HurtTime += dt
		if not oneShot(pose, AnimationData.Animations.Hurt, state.HurtTime, 0.15) then
			state.HurtTime = nil
		end
	end
	if state.DeathTime then
		state.DeathTime += dt
		layer(pose, AnimationData.Sample(AnimationData.Animations.Death, state.DeathTime), 1)
	end

	-- Los desplazamientos (agacharse, caer al suelo) se ajustan a su tamaño
	local rootPose = pose.Root
	pose.Root = CFrame.new(rootPose.Position * state.Scale) * rootPose.Rotation

	for joint, motor in state.Joints do
		motor.Transform = pose[joint]
	end
end

function MonsterAnimator.Start()
	task.spawn(function()
		local folder = Workspace:WaitForChild("Monsters")
		for _, model in folder:GetChildren() do
			task.spawn(track, model)
		end
		folder.ChildAdded:Connect(function(model)
			task.spawn(track, model)
		end)
	end)

	RunService.PreSimulation:Connect(function(dt)
		local now = os.clock()
		for model, state in tracked do
			-- Los R15 siguen animándose al morir (caen al suelo); los demás se paran
			if not model.Parent or (state.Humanoid.Health <= 0 and not state.R15) then
				tracked[model] = nil
				continue
			end
			local velocity = state.Root.AssemblyLinearVelocity
			local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			if state.R15 then
				animateR15(state, dt, speed)
				continue
			end
			state.Move = approach(state.Move, if speed > 0.8 then 1 else 0, 6, dt)
			local animate = ANIMATE[state.Id]
			if animate then
				animate(state, now, dt, speed)
			end
		end
	end)
end

return MonsterAnimator
