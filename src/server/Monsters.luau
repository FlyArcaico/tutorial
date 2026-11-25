-- Spawns monsters, runs their AI, and drops an essence when one is defeated.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local Monsters = {}

local rng = Random.new()
local monsterFolder
local essenceFolder
local active = {} -- [Model] = state
local essences = {} -- [Part] = { Expires = number, Bob = Tween }
local zoneCounts = {} -- [zone] = number of living monsters

local function randomPointInZone(zone)
	local angle = rng:NextNumber(0, math.pi * 2)
	local distance = math.sqrt(rng:NextNumber()) * zone.Radius
	return zone.Center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
end

local function weld(part, root)
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = root
	constraint.Part1 = part
	constraint.Parent = part
end

local function createEssence(monsterId, position)
	local def = Config.Monsters[monsterId]

	local orb = Instance.new("Part")
	orb.Name = "Essence"
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.one * 2
	orb.Material = Enum.Material.Neon
	orb.Color = def.Color:Lerp(Color3.fromRGB(150, 230, 255), 0.6)
	orb.Anchored = true
	orb.CanCollide = false
	orb.Position = Vector3.new(position.X, 2, position.Z)
	orb:SetAttribute("MonsterId", monsterId)

	local light = Instance.new("PointLight")
	light.Color = orb.Color
	light.Range = 10
	light.Parent = orb

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(180, 44)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 40
	billboard.Parent = orb

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = def.DisplayName .. " essence\nPress F to absorb"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Parent = billboard

	orb.Parent = essenceFolder

	local bob = TweenService:Create(
		orb,
		TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = orb.Position + Vector3.new(0, 1, 0) }
	)
	bob:Play()

	essences[orb] = { Expires = os.clock() + Config.EssenceLifetime, Bob = bob }
end

local function spawnMonster(monsterId, zone)
	local def = Config.Monsters[monsterId]

	local model = Instance.new("Model")
	model.Name = def.DisplayName
	model:SetAttribute("MonsterId", monsterId)

	local position = randomPointInZone(zone)
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = def.Size
	root.Color = def.Color
	root.Material = Enum.Material.SmoothPlastic
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.CFrame = CFrame.new(position + Vector3.new(0, def.Size.Y / 2 + 1, 0))
		* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	root.Parent = model
	model.PrimaryPart = root

	-- Glowing eyes on the front (-Z) face
	local eyeSize = math.max(0.4, math.min(def.Size.X, def.Size.Y) * 0.18)
	for _, side in { -1, 1 } do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.one * eyeSize
		eye.Material = Enum.Material.Neon
		eye.Color = Color3.fromRGB(255, 80, 60)
		eye.CanCollide = false
		eye.Massless = true
		eye.CFrame = root.CFrame * CFrame.new(side * def.Size.X * 0.25, def.Size.Y * 0.2, -def.Size.Z / 2)
		eye.Parent = model
		weld(eye, root)
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = 0.2
	humanoid.MaxHealth = def.Health
	humanoid.Health = def.Health
	humanoid.WalkSpeed = def.Speed
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	humanoid.NameDisplayDistance = 80
	humanoid.HealthDisplayDistance = 80
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	humanoid.Parent = model

	model.Parent = monsterFolder
	root:SetNetworkOwner(nil) -- server controls monsters, so they move smoothly for everyone

	active[model] = {
		Def = def,
		Zone = zone,
		Humanoid = humanoid,
		Root = root,
		LastAttack = 0,
		NextWander = 0,
	}
	zoneCounts[zone] = (zoneCounts[zone] or 0) + 1

	humanoid.Died:Connect(function()
		active[model] = nil
		zoneCounts[zone] -= 1
		createEssence(monsterId, root.Position)
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Transparency = 0.6
			end
		end
		task.delay(1, function()
			model:Destroy()
		end)
	end)
end

local function findTarget(state)
	local bestCharacter, bestDistance = nil, state.Def.AggroRange
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and humanoid.Health > 0 then
			local distance = (root.Position - state.Root.Position).Magnitude
			if distance < bestDistance then
				bestCharacter, bestDistance = character, distance
			end
		end
	end
	return bestCharacter, bestDistance
end

local function updateMonster(state, now)
	local zone = state.Zone
	local awayFromHome = (state.Root.Position - zone.Center).Magnitude > zone.Radius + 30

	local target, distance = nil, math.huge
	if not awayFromHome then
		target, distance = findTarget(state)
	end

	if target then
		local targetRoot = target.HumanoidRootPart
		state.Humanoid:MoveTo(targetRoot.Position)

		local reach = math.max(state.Def.Size.X, state.Def.Size.Z) / 2 + 3.5
		if distance <= reach and now - state.LastAttack >= 1.2 then
			state.LastAttack = now
			target.Humanoid:TakeDamage(state.Def.Damage)
		end
	elseif awayFromHome then
		state.Humanoid:MoveTo(zone.Center)
	elseif now >= state.NextWander then
		state.NextWander = now + rng:NextNumber(3, 7)
		state.Humanoid:MoveTo(randomPointInZone(zone))
	end
end

-- Damages every monster in front of the character. Returns how many were hit.
function Monsters.DamageInFront(character, damage, range)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return 0
	end

	local hits = 0
	for _, state in active do
		if state.Humanoid.Health > 0 then
			local offset = state.Root.Position - root.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local reach = range + math.max(state.Def.Size.X, state.Def.Size.Z) / 2
			if flat.Magnitude <= reach then
				local inFront = flat.Magnitude < 4 or root.CFrame.LookVector:Dot(flat.Unit) > 0.2
				if inFront then
					state.Humanoid:TakeDamage(damage)
					hits += 1
				end
			end
		end
	end
	return hits
end

-- Absorbs the closest essence near the character. Returns the monster id, or nil.
function Monsters.TryAbsorb(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end

	local closest, closestDistance = nil, Config.AbsorbRange
	for orb in essences do
		local distance = (orb.Position - root.Position).Magnitude
		if distance <= closestDistance then
			closest, closestDistance = orb, distance
		end
	end
	if not closest then
		return nil
	end

	local monsterId = closest:GetAttribute("MonsterId")
	essences[closest].Bob:Cancel()
	essences[closest] = nil

	-- Fly into the slime, then vanish
	local suck = TweenService:Create(
		closest,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = root.Position, Size = Vector3.one * 0.2 }
	)
	suck.Completed:Connect(function()
		closest:Destroy()
	end)
	suck:Play()

	return monsterId
end

function Monsters.Start()
	monsterFolder = Instance.new("Folder")
	monsterFolder.Name = "Monsters"
	monsterFolder.Parent = Workspace

	essenceFolder = Instance.new("Folder")
	essenceFolder.Name = "Essences"
	essenceFolder.Parent = Workspace

	-- Spawner: refill each zone over time
	task.spawn(function()
		while true do
			for _, zone in Config.Zones do
				if (zoneCounts[zone] or 0) < zone.MaxMonsters then
					local monsterId = zone.Monsters[rng:NextInteger(1, #zone.Monsters)]
					spawnMonster(monsterId, zone)
				end
			end
			task.wait(2)
		end
	end)

	-- AI and essence cleanup
	task.spawn(function()
		while true do
			local now = os.clock()
			for _, state in active do
				updateMonster(state, now)
			end
			for orb, info in essences do
				if now >= info.Expires then
					info.Bob:Cancel()
					essences[orb] = nil
					orb:Destroy()
				end
			end
			task.wait(0.25)
		end
	end)
end

return Monsters
