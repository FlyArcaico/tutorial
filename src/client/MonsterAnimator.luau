-- Animaciones de los monstruos (cada jugador las calcula en su pantalla):
--   Lobo: galope con las patas en diagonal, cabeza que sube y baja, cola que se mueve; mordisco.
--   Murciélago: aleteo con las puntas de las alas doblándose; ataque en picado.
--   Gólem: pasos pesados con los brazos balanceándose; golpe con los dos puños.
-- Mueve las articulaciones (Motor6D) que crea el servidor en Monsters.luau.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

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

local function track(model)
	local root = model:WaitForChild("HumanoidRootPart", 5)
	local humanoid = model:WaitForChild("Humanoid", 5)
	if not root or not humanoid then
		return
	end
	task.wait() -- que lleguen todas las piezas
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
			if not model.Parent or state.Humanoid.Health <= 0 then
				tracked[model] = nil
				continue
			end
			local velocity = state.Root.AssemblyLinearVelocity
			local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			state.Move = approach(state.Move, if speed > 0.8 then 1 else 0, 6, dt)
			local animate = ANIMATE[state.Id]
			if animate then
				animate(state, now, dt, speed)
			end
		end
	end)
end

return MonsterAnimator
