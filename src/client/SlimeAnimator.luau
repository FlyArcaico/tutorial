-- Animación de reposo de los Slimes (la ve cada jugador para todos los slimes):
-- el cuerpo "respira" (se estira y se aplasta) y los ojos de raya suben y bajan.
-- Al moverse, rebota un poco más.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SlimeAnimator = {}

local tracked = {} -- [Model SlimeBody] = { Meshes = {...}, Eyes = {...}, Size = number, Root = Part }

local function track(body)
	local info = { Meshes = {}, Eyes = {}, Size = body:GetAttribute("Size") or 3, Phase = math.random() * 6 }
	for _, part in body:GetChildren() do
		if part:IsA("BasePart") then
			local joint = part:FindFirstChildOfClass("Weld")
			if part.Name == "Blob" or part.Name == "Rim" then
				local mesh = part:FindFirstChildOfClass("SpecialMesh")
				if mesh then
					table.insert(info.Meshes, mesh)
				end
			end
			if joint and joint:GetAttribute("BaseC0") then
				table.insert(
					info.Eyes,
					{ Joint = joint, Base = joint:GetAttribute("BaseC0"), IsEye = part.Name == "Eye" }
				)
				info.Root = info.Root or joint.Part0
			end
		end
	end
	tracked[body] = info
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

function SlimeAnimator.Start()
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for body, info in tracked do
			if not body.Parent then
				tracked[body] = nil
				continue
			end

			-- Si se mueve, rebota más rápido y más fuerte
			local moving = false
			if info.Root then
				local velocity = info.Root.AssemblyLinearVelocity
				moving = Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 2
			end
			local speed = if moving then 7 else 2.2
			local strength = if moving then 1.8 else 1
			local wave = math.sin(now * speed + info.Phase)

			-- Respirar: más ancho cuando está más bajo
			local squash = 0.05 * strength * wave
			local scale = Vector3.new(1 + squash * 0.7, 1 - squash, 1 + squash * 0.7)
			for _, mesh in info.Meshes do
				mesh.Scale = scale
			end

			-- El resto de piezas baja y sube con el cuerpo; los ojos un poco más
			local d = info.Size
			for _, piece in info.Eyes do
				local offset = -squash * d * 0.4
				if piece.IsEye then
					offset += d * 0.025 * math.sin(now * speed * 0.5 + info.Phase)
				end
				piece.Joint.C0 = piece.Base * CFrame.new(0, offset, 0)
			end
		end
	end)
end

return SlimeAnimator
