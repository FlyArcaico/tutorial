-- Saves player progress (ProfileService), handles leveling, skills and the slime body.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local ProfileService = require(ServerScriptService.ServerPackages.ProfileService)
local Remotes = require(script.Parent.Remotes)

local PlayerData = {}

local TEMPLATE = {
	Level = 1,
	XP = 0,
	Skills = {}, -- [skillId] = true
	Absorbed = {}, -- [monsterId] = count
}

local store = ProfileService.GetProfileStore("SlimeRebirth_v1", TEMPLATE)
local profiles = {} -- [Player] = profile

local GOLD = Color3.fromRGB(255, 215, 90)
local CYAN = Color3.fromRGB(120, 220, 255)
local PURPLE = Color3.fromRGB(200, 150, 255)

local function notify(player, text, color)
	Remotes.Notify:FireClient(player, text, color)
end

function PlayerData.Get(player)
	local profile = profiles[player]
	return profile and profile.Data
end

-- The client UI reads these attributes
local function updateAttributes(player, data)
	local skills = {}
	for skillId in data.Skills do
		table.insert(skills, skillId)
	end
	table.sort(skills)

	player:SetAttribute("Level", data.Level)
	player:SetAttribute("XP", data.XP)
	player:SetAttribute("XPNeeded", Config.XPToNextLevel(data.Level))
	player:SetAttribute("Form", Config.GetForm(data.Level).Name)
	player:SetAttribute("Skills", table.concat(skills, ","))

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Level.Value = data.Level
	end
end

local function applyStats(player, data, heal)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local maxHealth = Config.MaxHealth(data.Level, data.Skills)
	humanoid.MaxHealth = maxHealth
	if heal then
		humanoid.Health = maxHealth
	end
	humanoid.WalkSpeed = Config.WalkSpeed(data.Level)
	humanoid.UseJumpPower = true
	humanoid.JumpPower = if data.Skills.HighJump then Config.Skills.HighJump.JumpPower else 50
end

-- Hide the normal avatar so only the slime is visible
local function hideHumanBody(instance)
	if instance:GetAttribute("SlimePart") then
		return
	end
	if instance:IsA("Accessory") then
		task.defer(instance.Destroy, instance)
	elseif instance:IsA("BasePart") or instance:IsA("Decal") then
		instance.Transparency = 1
	end
end

local function makeSlimePart(name, size, cframe, color, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Transparency = transparency
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part:SetAttribute("SlimePart", true)

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

local function applySlimeBody(character, form)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end

	local old = character:FindFirstChild("SlimeBody")
	if old then
		old:Destroy()
	end

	local body = Instance.new("Model")
	body.Name = "SlimeBody"
	body:SetAttribute("SlimePart", true)

	local d = form.Size
	local height = d * 0.8
	-- The character's root sits about 3 studs above the ground
	local base = root.CFrame * CFrame.new(0, height / 2 - 3, 0)

	local blob = makeSlimePart("Blob", Vector3.new(d, height, d), base, form.Color, 0.15)
	local parts = { blob }
	for _, side in { -1, 1 } do
		table.insert(
			parts,
			makeSlimePart(
				"Eye",
				Vector3.new(d * 0.12, d * 0.2, d * 0.12),
				base * CFrame.new(side * d * 0.18, height * 0.12, -d * 0.44),
				Color3.fromRGB(20, 20, 30),
				0
			)
		)
	end
	table.insert(
		parts,
		makeSlimePart(
			"Shine",
			Vector3.one * d * 0.14,
			base * CFrame.new(d * 0.22, height * 0.3, -d * 0.3),
			Color3.new(1, 1, 1),
			0.3
		)
	)

	for _, part in parts do
		local constraint = Instance.new("WeldConstraint")
		constraint.Part0 = root
		constraint.Part1 = part
		constraint.Parent = part
		part.Parent = body
	end
	body.Parent = character
end

local function onCharacterAdded(player, character)
	local data = PlayerData.Get(player)
	if not data then
		return
	end

	for _, descendant in character:GetDescendants() do
		hideHumanBody(descendant)
	end
	character.DescendantAdded:Connect(hideHumanBody)

	applySlimeBody(character, Config.GetForm(data.Level))
	character:WaitForChild("Humanoid", 10)
	applyStats(player, data, true)
end

function PlayerData.AddXP(player, amount)
	local data = PlayerData.Get(player)
	if not data then
		return
	end

	local oldForm = Config.GetForm(data.Level)
	data.XP += amount

	local leveledUp = false
	while data.XP >= Config.XPToNextLevel(data.Level) do
		data.XP -= Config.XPToNextLevel(data.Level)
		data.Level += 1
		leveledUp = true
	end

	updateAttributes(player, data)

	if leveledUp then
		local newForm = Config.GetForm(data.Level)
		if newForm ~= oldForm then
			notify(player, "You evolved into a " .. newForm.Name .. "!", PURPLE)
			if player.Character then
				applySlimeBody(player.Character, newForm)
			end
		else
			notify(player, "Level up! You are now level " .. data.Level, GOLD)
		end
		applyStats(player, data, true)
	end
end

function PlayerData.Absorb(player, monsterId)
	local data = PlayerData.Get(player)
	local def = Config.Monsters[monsterId]
	if not data or not def then
		return
	end

	data.Absorbed[monsterId] = (data.Absorbed[monsterId] or 0) + 1

	local skillId = def.Skill
	if skillId and not data.Skills[skillId] then
		data.Skills[skillId] = true
		local skill = Config.Skills[skillId]
		notify(player, "New skill stolen: " .. skill.DisplayName .. "! " .. skill.Description, CYAN)
		applyStats(player, data, false)
	else
		notify(player, "Absorbed " .. def.DisplayName .. "  +" .. def.XP .. " XP", Color3.new(1, 1, 1))
	end

	PlayerData.AddXP(player, def.XP)
	updateAttributes(player, data)
end

local function onPlayerAdded(player)
	local profile = store:LoadProfileAsync("Player_" .. player.UserId, "ForceLoad")
	if not profile then
		player:Kick("Could not load your data. Please rejoin.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile:ListenToRelease(function()
		profiles[player] = nil
		player:Kick("Your data was loaded on another server. Please rejoin.")
	end)

	if player.Parent ~= Players then
		profile:Release() -- player left while loading
		return
	end
	profiles[player] = profile

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Parent = leaderstats
	leaderstats.Parent = player

	updateAttributes(player, profile.Data)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end

	notify(player, "You have been reborn as a slime! Defeat monsters, then press F to absorb them.", CYAN)
end

function PlayerData.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			profile:Release()
		end
	end)
end

return PlayerData
