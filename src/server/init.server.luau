-- Server entry point: builds the world, starts monsters and player data, handles combat.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Monsters = require(script.Monsters)
local PlayerData = require(script.PlayerData)
local Remotes = require(script.Remotes)
local World = require(script.World)

World.Build()
Monsters.Start()
PlayerData.Start()

local lastAttack = {} -- [Player] = time

local function getAliveCharacter(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 and character:FindFirstChild("HumanoidRootPart") then
		return character
	end
	return nil
end

-- A quick splash in front of the slime so everyone sees the attack
local function playAttackEffect(character, form, range)
	local root = character.HumanoidRootPart
	local splash = Instance.new("Part")
	splash.Shape = Enum.PartType.Ball
	splash.Size = Vector3.one * form.Size
	splash.Color = form.Color
	splash.Material = Enum.Material.Neon
	splash.Transparency = 0.4
	splash.Anchored = true
	splash.CanCollide = false
	splash.CanQuery = false
	splash.CanTouch = false
	splash.Position = (root.CFrame * CFrame.new(0, -1, -range / 2)).Position
	splash.Parent = Workspace

	local tween = TweenService:Create(splash, TweenInfo.new(0.25), {
		Size = Vector3.one * range,
		Transparency = 1,
	})
	tween.Completed:Connect(function()
		splash:Destroy()
	end)
	tween:Play()
end

Remotes.Attack.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if now - (lastAttack[player] or 0) < Config.Attack.Cooldown then
		return
	end

	local data = PlayerData.Get(player)
	local character = getAliveCharacter(player)
	if not data or not character then
		return
	end
	lastAttack[player] = now

	local form = Config.GetForm(data.Level)
	local range = Config.Attack.Range + form.Size / 2
	Monsters.DamageInFront(character, Config.AttackDamage(data.Level), range)
	playAttackEffect(character, form, range)
end)

Remotes.Absorb.OnServerEvent:Connect(function(player)
	local character = getAliveCharacter(player)
	if not character or not PlayerData.Get(player) then
		return
	end

	local monsterId = Monsters.TryAbsorb(character)
	if monsterId then
		PlayerData.Absorb(player, monsterId)
	else
		Remotes.Notify:FireClient(player, "Nothing to absorb nearby", Color3.fromRGB(180, 180, 180))
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastAttack[player] = nil
end)
