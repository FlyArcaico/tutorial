-- Animaciones del Slime (cada jugador las calcula para todos los slimes).
-- El cuerpo se deforma entero (escala en X/Y/Z, desplazamiento e inclinación) y todas las
-- piezas (cara, brillos, luz interior) siguen esa deformación:
--   Reposo: respira despacio.            Andar: pequeños saltitos.
--   Correr: saltos más largos e inclinado. Saltar: se estira. Caer: se alarga un poco.
--   Aterrizar: se aplasta y rebota.       Atacar: se estira hacia delante como un muelle.
--   Recibir daño: tiembla y se pone rojo. Magia/absorber: la luz interior brilla.
--   Morir: se derrite en un charco.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SlimeFace = require(script.Parent.SlimeFace)

local SlimeAnimator = {}

local tracked = {} -- [SlimeBody] = estado
local HURT_COLOR = Color3.fromRGB(255, 90, 110)

local function approach(current, target, rate, dt)
	return current + (target - current) * math.min(1, rate * dt)
end

local function decay(value, rate, dt)
	return value * math.exp(-rate * dt)
end

local function track(body)
	local character = body.Parent
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local center = body:GetAttribute("Center")
	if not humanoid or not center then
		return
	end

	local state = {
		Body = body,
		Humanoid = humanoid,
		Root = nil,
		Size = body:GetAttribute("Size") or 3,
		Height = body:GetAttribute("Height") or 2.3,
		Center = center,
		Pieces = {},
		Core = nil,
		CoreLight = nil,
		Sparkles = nil,
		-- Estado de la animación
		HopPhase = math.random() * 3,
		Move = 0,
		Run = 0,
		Rise = 0,
		Fall = 0,
		Land = 0,
		Hurt = 0,
		Cast = 0,
		AttackStart = -10,
		DeathStart = nil,
		WasInAir = false,
		LastHealth = humanoid.Health,
		Phase = math.random() * 6,
	}

	for _, part in body:GetChildren() do
		local joint = part:IsA("BasePart") and part:FindFirstChildOfClass("Weld")
		local base = joint and joint:GetAttribute("BaseC0")
		if base then
			state.Root = state.Root or joint.Part0
			local piece = {
				Part = part,
				Joint = joint,
				-- Posición de la pieza respecto al centro del cuerpo
				Relative = center:Inverse() * base,
				Mesh = part:FindFirstChildOfClass("SpecialMesh"),
				Role = part:GetAttribute("SlimeRole"),
				BaseColor = part.Color,
				BaseTransparency = part.Transparency,
			}
			table.insert(state.Pieces, piece)
			if piece.Role == "Core" then
				state.Core = piece
				state.CoreLight = part:FindFirstChild("CoreLight")
				-- Partículas para cuando lanza magia (solo en este cliente)
				local sparkles = Instance.new("ParticleEmitter")
				sparkles.Color = ColorSequence.new(Color3.fromRGB(170, 240, 255), Color3.fromRGB(80, 170, 255))
				sparkles.LightEmission = 1
				sparkles.Size = NumberSequence.new(0.25, 0)
				sparkles.Transparency = NumberSequence.new(0, 1)
				sparkles.Lifetime = NumberRange.new(0.4, 0.8)
				sparkles.Speed = NumberRange.new(3, 6)
				sparkles.SpreadAngle = Vector2.new(180, 180)
				sparkles.Rate = 0
				sparkles.Parent = part
				state.Sparkles = sparkles
			end
		end
	end
	if not state.Root then
		return
	end

	-- Cara con expresiones (si el cuerpo tiene placas de cara)
	state.Face = SlimeFace.Attach(body)
	state.LastHurt = -10

	humanoid.HealthChanged:Connect(function(health)
		if health < state.LastHealth - 0.5 then
			state.Hurt = 1
			state.LastHurt = os.clock()
		end
		state.LastHealth = health
	end)
	humanoid.Died:Connect(function()
		state.DeathStart = os.clock()
	end)

	tracked[body] = state
end

local function watchCharacter(character)
	local function check(child)
		if child.Name == "SlimeBody" and child:IsA("Model") then
			task.defer(track, child) -- esperar a que lleguen todas las piezas
		end
	end
	for _, child in character:GetChildren() do
		check(child)
	end
	character.ChildAdded:Connect(check)
end

local function watchPlayer(player)
	if player.Character then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
end

local function find(character)
	local body = character:FindFirstChild("SlimeBody")
	return body and tracked[body]
end

-- Ataque normal: estirarse hacia delante
function SlimeAnimator.PlayAttack(character)
	local state = find(character)
	if state then
		state.AttackStart = os.clock()
	end
end

-- Magia o absorber: la luz interior brilla y salen chispas.
-- kind = "Absorb" (cara contenta ^^) o "Ability" (cara concentrada)
function SlimeAnimator.PlayCast(character, kind)
	local state = find(character)
	if state then
		state.Cast = 1
		if kind == "Absorb" then
			state.AbsorbStart = os.clock()
		else
			state.CastStart = os.clock()
		end
		if state.Sparkles then
			state.Sparkles:Emit(16)
		end
	end
end

local function animate(state, dt, now)
	local humanoid = state.Humanoid
	local velocity = state.Root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local inAir = humanoid.FloorMaterial == Enum.Material.Air
	local player = Players:GetPlayerFromCharacter(state.Body.Parent)
	local sprinting = player ~= nil and player:GetAttribute("Sprinting") == true
	local d, h = state.Size, state.Height

	-- Pesos suavizados
	state.Move = approach(state.Move, if speed > 0.8 and not inAir then 1 else 0, 9, dt)
	state.Run = approach(state.Run, if sprinting and speed > 4 then 1 else 0, 7, dt)
	state.Rise = approach(state.Rise, if inAir and velocity.Y > 1 then 1 else 0, 14, dt)
	state.Fall = approach(state.Fall, if inAir and velocity.Y <= 1 then 1 else 0, 10, dt)
	if state.WasInAir and not inAir then
		state.Land = 1 -- acaba de aterrizar
	end
	state.WasInAir = inAir
	state.Land = decay(state.Land, 7, dt)
	state.Hurt = decay(state.Hurt, 5, dt)
	state.Cast = decay(state.Cast, 2.5, dt)

	-- Base: escala 1, sin desplazamiento ni inclinación
	local sx, sy, sz = 1, 1, 1
	local dy, dz, lean = 0, 0, 0

	-- Reposo: respirar
	local idle = 1 - state.Move
	local breathe = math.sin(now * 2.1 + state.Phase)
	sy += 0.035 * breathe * idle
	sx -= 0.018 * breathe * idle
	sz -= 0.018 * breathe * idle

	-- Andar y correr: saltitos. Al tocar el suelo se aplasta; arriba se estira.
	if state.Move > 0.01 then
		state.HopPhase += dt * (6.5 + 3.5 * state.Run)
		local hop = math.abs(math.sin(state.HopPhase))
		local contact = (1 - hop) ^ 3 * state.Move
		local stretch = hop * state.Move
		dy += hop * d * (0.18 + 0.14 * state.Run) * state.Move
		sy += -0.17 * contact + 0.07 * stretch
		sx += 0.13 * contact - 0.035 * stretch
		sz += 0.13 * contact - 0.035 * stretch
		lean += math.rad(4 + 9 * state.Run) * state.Move
	end

	-- En el aire: se estira al subir y un poco al caer
	sy += 0.2 * state.Rise + 0.08 * state.Fall
	sx -= 0.1 * state.Rise + 0.04 * state.Fall
	sz -= 0.1 * state.Rise + 0.04 * state.Fall

	-- Aterrizar: se aplasta y vuelve con un pequeño rebote
	local land = state.Land * math.cos((1 - state.Land) * 9)
	sy -= 0.32 * land
	sx += 0.22 * land
	sz += 0.22 * land

	-- Ataque: se estira hacia delante como un muelle
	local attackTime = now - state.AttackStart
	if attackTime < 0.32 then
		local k = math.sin(attackTime / 0.32 * math.pi)
		sz += 0.42 * k
		sy -= 0.15 * k
		sx -= 0.08 * k
		dz -= d * 0.35 * k
		lean += math.rad(10) * k
	end

	-- Recibir daño: tiembla
	local wobble = math.sin(now * 38) * 0.12 * state.Hurt
	sx += wobble
	sz += wobble
	sy -= wobble

	-- Magia: se hincha un poco
	sy += 0.08 * state.Cast
	dy += d * 0.05 * state.Cast

	-- Morir: se derrite en un charco
	local melt = 0
	if state.DeathStart then
		melt = math.clamp((now - state.DeathStart) / 1.2, 0, 1)
		sy = math.max(0.15, sy * (1 - 0.85 * melt))
		sx *= 1 + 0.7 * melt
		sz *= 1 + 0.7 * melt
		dy = 0
		lean = 0
	end

	-- Aplicar: el fondo del slime se queda pegado al suelo (o al punto del salto)
	local bottom = h * 0.5 -- igual que SlimeModel.BottomRatio
	local pivot = state.Center
		* CFrame.new(0, -bottom + dy, dz)
		* CFrame.Angles(-lean, 0, 0)
		* CFrame.new(0, bottom * sy, 0)
	local scale = Vector3.new(sx, sy, sz)
	local hurtTint = state.Hurt * 0.55
	for _, piece in state.Pieces do
		local position = piece.Relative.Position * scale
		piece.Joint.C0 = pivot * CFrame.new(position) * piece.Relative.Rotation
		if piece.Mesh then
			piece.Mesh.Scale = scale
		end
		if piece.Role == "Body" then
			piece.Part.Color = piece.BaseColor:Lerp(HURT_COLOR, hurtTint)
		end
		if melt > 0 then
			piece.Part.Transparency = piece.BaseTransparency + (1 - piece.BaseTransparency) * melt * 0.8
		end
	end

	-- Expresión de la cara según lo que esté haciendo
	if state.Face then
		local dead = state.DeathStart ~= nil
		local hurt = now - state.LastHurt < 0.6 -- acaba de recibir un golpe
		local absorbing = now - (state.AbsorbStart or -10) < 1.2 -- absorbe contento
		local attacking = attackTime < 0.5
		local casting = now - (state.CastStart or -10) < 0.8 -- usa una habilidad
		local running = state.Run > 0.5 and state.Move > 0.5
		local lowHealth = humanoid.Health < humanoid.MaxHealth * 0.35
		local busy = hurt or absorbing or attacking or casting or running
		local idleSmile = state.Move < 0.2 and (now + state.Phase) % 9 < 1.4 -- de vez en cuando sonríe

		local expression = "Normal"
		if dead or (lowHealth and not busy) then
			expression = "Sad"
		elseif hurt then
			expression = "Hurt"
		elseif absorbing or idleSmile then
			expression = "Happy"
		elseif attacking then
			expression = "Angry"
		elseif casting then
			expression = "Focused"
		elseif running then
			expression = "Energetic"
		end
		state.Face:Set(expression)
	end

	-- Luz interior: más fuerte al lanzar magia
	if state.Core then
		state.Core.Part.Transparency = 0.78 - 0.55 * state.Cast
		if state.CoreLight then
			state.CoreLight.Brightness = 0.6 + 3 * state.Cast
		end
	end
end

function SlimeAnimator.Start()
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)

	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		for body, state in tracked do
			if not body.Parent then
				tracked[body] = nil
				continue
			end
			animate(state, dt, now)
		end
	end)
end

return SlimeAnimator
