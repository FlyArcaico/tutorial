-- Punto de entrada del servidor: construye el mundo, inicia monstruos y datos, y gestiona el menú y el combate.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

-- El personaje no aparece hasta que el jugador pulsa "Jugar" en el menú
Players.CharacterAutoLoads = false

local Config = require(ReplicatedStorage.Shared.Config)
local Monsters = require(script.Monsters)
local PlayerData = require(script.PlayerData)
local Remotes = require(script.Remotes)
local World = require(script.World)

World.Build()
Monsters.SetKillHandler(PlayerData.OnMonsterKilled)
Monsters.Start()
PlayerData.Start()

--------------------------------------------------------------------------------
-- Menú
--------------------------------------------------------------------------------

Remotes.GetMenu.OnServerInvoke = function(player)
	return PlayerData.GetMenu(player)
end

Remotes.SelectSlot.OnServerInvoke = function(player, index)
	return PlayerData.SelectSlot(player, index)
end

Remotes.Spin.OnServerInvoke = function(player)
	return PlayerData.Spin(player)
end

Remotes.SetRace.OnServerInvoke = function(player, raceId)
	return PlayerData.SetRace(player, raceId)
end

Remotes.Play.OnServerInvoke = function(player)
	return PlayerData.Play(player)
end

Remotes.ReturnToMenu.OnServerEvent:Connect(function(player)
	PlayerData.ReturnToMenu(player)
end)

--------------------------------------------------------------------------------
-- Combate
--------------------------------------------------------------------------------

local FIRE_COLOR = Color3.fromRGB(255, 120, 30)
local lastAttack = {} -- [Player] = tiempo

local function getAliveCharacter(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 and character:FindFirstChild("HumanoidRootPart") then
		return character
	end
	return nil
end

-- Una explosión rápida delante del personaje para que todos vean el ataque
local function playAttackEffect(character, color, size, range, withFire)
	local root = character.HumanoidRootPart
	local splash = Instance.new("Part")
	splash.Shape = Enum.PartType.Ball
	splash.Size = Vector3.one * size
	splash.Color = color
	splash.Material = Enum.Material.Neon
	splash.Transparency = 0.4
	splash.Anchored = true
	splash.CanCollide = false
	splash.CanQuery = false
	splash.CanTouch = false
	splash.Position = (root.CFrame * CFrame.new(0, -1, -range / 2)).Position
	splash.Parent = Workspace

	if withFire then
		local fire = Instance.new("Fire")
		fire.Size = size * 2
		fire.Color = FIRE_COLOR
		fire.SecondaryColor = Color3.fromRGB(255, 220, 80)
		fire.Parent = splash
	end

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

	local slot = PlayerData.Get(player)
	local character = getAliveCharacter(player)
	if not slot or not character then
		return
	end
	lastAttack[player] = now

	local race = Config.Races[slot.Race]
	local body = Config.GetBody(slot.Race, slot.Level)
	local range = Config.AttackRange(slot.Level, slot.Race)
	Monsters.DamageInFront(player, character, Config.AttackDamage(slot.Level, slot.Race), range)
	playAttackEffect(character, if race.Fire then FIRE_COLOR else body.Color, body.Size, range, race.Fire)
end)

Remotes.Absorb.OnServerEvent:Connect(function(player)
	local character = getAliveCharacter(player)
	local race = PlayerData.GetRace(player)
	if not character or not race then
		return
	end
	if not race.CanAbsorb then
		Remotes.Notify:FireClient(player, "Solo la raza Slime puede absorber", Color3.fromRGB(180, 180, 180))
		return
	end

	local monsterId = Monsters.TryAbsorb(character)
	if monsterId then
		PlayerData.Absorb(player, monsterId)
	else
		Remotes.Notify:FireClient(player, "No hay nada que absorber cerca", Color3.fromRGB(180, 180, 180))
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastAttack[player] = nil
end)
