-- Guarda el progreso (ProfileService): 3 slots por jugador, cada uno con su raza,
-- nivel y habilidades. También controla el menú, los spins y el aspecto del personaje.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local ProfileService = require(ServerScriptService.ServerPackages.ProfileService)
local Remotes = require(script.Parent.Remotes)

local PlayerData = {}

local function newSlot()
	return {
		Level = 1,
		XP = 0,
		Race = Config.DefaultRace,
		Spins = Config.StartingSpins,
		Skills = {}, -- [skillId] = true (solo Slime)
		Absorbed = {}, -- [monsterId] = cantidad (solo Slime)
	}
end

local TEMPLATE = {
	Slots = { newSlot(), newSlot(), newSlot() },
}

local store = ProfileService.GetProfileStore("SlimeRebirth_v2", TEMPLATE)
local sessions = {} -- [Player] = { Profile = profile, SlotIndex = number?, Playing = boolean }
local rng = Random.new()

local GOLD = Color3.fromRGB(255, 215, 90)
local CYAN = Color3.fromRGB(120, 220, 255)
local PURPLE = Color3.fromRGB(200, 150, 255)
local WHITE = Color3.new(1, 1, 1)

local function notify(player, text, color)
	Remotes.Notify:FireClient(player, text, color)
end

local function fail(message)
	return { Ok = false, Message = message }
end

--------------------------------------------------------------------------------
-- Consultas
--------------------------------------------------------------------------------

-- Datos del slot con el que se está jugando ahora mismo (nil si está en el menú)
function PlayerData.Get(player)
	local session = sessions[player]
	if session and session.Playing then
		return session.Profile.Data.Slots[session.SlotIndex]
	end
	return nil
end

function PlayerData.GetRace(player)
	local slot = PlayerData.Get(player)
	return slot and Config.Races[slot.Race]
end

local function highestLevel(profile)
	local highest = 0
	for _, slot in profile.Data.Slots do
		highest = math.max(highest, slot.Level)
	end
	return highest
end

local function isUnlocked(profile, index)
	return highestLevel(profile) >= Config.Slots[index].RequiredLevel
end

local function isValidIndex(index)
	return type(index) == "number" and Config.Slots[index] ~= nil
end

local function summarize(profile, index)
	local slot = profile.Data.Slots[index]
	return {
		Index = index,
		Level = slot.Level,
		Race = slot.Race,
		Spins = slot.Spins,
		Locked = not isUnlocked(profile, index),
		RequiredLevel = Config.Slots[index].RequiredLevel,
	}
end

local function waitForSession(player)
	local deadline = os.clock() + 15
	while not sessions[player] and player.Parent and os.clock() < deadline do
		task.wait(0.1)
	end
	return sessions[player]
end

--------------------------------------------------------------------------------
-- Atributos y estadísticas
--------------------------------------------------------------------------------

-- El HUD del cliente lee estos atributos
local function updateAttributes(player, slot)
	local race = Config.Races[slot.Race]

	local skills = {}
	if race.CanAbsorb then
		for skillId in slot.Skills do
			table.insert(skills, skillId)
		end
		table.sort(skills)
	end

	player:SetAttribute("Level", slot.Level)
	player:SetAttribute("XP", slot.XP)
	player:SetAttribute("XPNeeded", Config.XPToNextLevel(slot.Level))
	player:SetAttribute("Race", slot.Race)
	player:SetAttribute("Form", Config.GetBody(slot.Race, slot.Level).Name)
	player:SetAttribute("Skills", table.concat(skills, ","))

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Level.Value = slot.Level
	end
end

local function applyStats(player, slot, heal)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local race = Config.Races[slot.Race]
	local maxHealth = Config.MaxHealth(slot.Level, slot.Race, slot.Skills)
	humanoid.MaxHealth = maxHealth
	if heal then
		humanoid.Health = maxHealth
	end
	humanoid.WalkSpeed = Config.WalkSpeed(slot.Level, slot.Race)
	humanoid.UseJumpPower = true
	humanoid.JumpPower = if race.CanAbsorb and slot.Skills.HighJump then Config.Skills.HighJump.JumpPower else 50
end

--------------------------------------------------------------------------------
-- Aspecto del personaje según la raza
--------------------------------------------------------------------------------

local function weld(part, target)
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = target
	constraint.Part1 = part
	constraint.Parent = part
end

local function makeExtraPart(name, size, cframe, color)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part:SetAttribute("RacePart", true)
	return part
end

-- Slime: esconde el avatar para que solo se vea el slime
local function hideHumanBody(instance)
	if instance:GetAttribute("RacePart") then
		return
	end
	if instance:IsA("Accessory") then
		task.defer(instance.Destroy, instance)
	elseif instance:IsA("BasePart") or instance:IsA("Decal") then
		instance.Transparency = 1
	end
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
	body:SetAttribute("RacePart", true)

	local d = form.Size
	local height = d * 0.8
	-- El HumanoidRootPart está a unos 3 studs del suelo
	local base = root.CFrame * CFrame.new(0, height / 2 - 3, 0)

	local function sphere(name, size, cframe, color, transparency)
		local part = makeExtraPart(name, size, cframe, color)
		part.Transparency = transparency
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
		weld(part, root)
		part.Parent = body
	end

	sphere("Blob", Vector3.new(d, height, d), base, form.Color, 0.15)
	for _, side in { -1, 1 } do
		sphere(
			"Eye",
			Vector3.new(d * 0.12, d * 0.2, d * 0.12),
			base * CFrame.new(side * d * 0.18, height * 0.12, -d * 0.44),
			Color3.fromRGB(20, 20, 30),
			0
		)
	end
	sphere(
		"Shine",
		Vector3.one * d * 0.14,
		base * CFrame.new(d * 0.22, height * 0.3, -d * 0.3),
		Color3.new(1, 1, 1),
		0.3
	)

	body.Parent = character
end

-- Elf: orejas puntiagudas
local function addElfEars(character)
	local head = character:WaitForChild("Head", 10)
	if not head then
		return
	end
	for _, side in { -1, 1 } do
		local ear = makeExtraPart(
			"ElfEar",
			Vector3.new(0.15, 0.7, 0.3),
			head.CFrame * CFrame.new(side * (head.Size.X / 2 + 0.05), 0.15, 0) * CFrame.Angles(0, 0, -side * 0.6),
			head.Color
		)
		weld(ear, head)
		ear.Parent = character
	end
end

-- Ogre: cuernos
local function addOgreHorns(character)
	local head = character:WaitForChild("Head", 10)
	if not head then
		return
	end
	for _, side in { -1, 1 } do
		local horn = makeExtraPart(
			"OgreHorn",
			Vector3.new(0.9, 0.3, 0.3),
			head.CFrame
				* CFrame.new(side * head.Size.X * 0.28, head.Size.Y / 2 + 0.3, 0)
				* CFrame.Angles(0, 0, math.rad(90 - side * 25)),
			Color3.fromRGB(240, 230, 200)
		)
		horn.Shape = Enum.PartType.Cylinder
		weld(horn, head)
		horn.Parent = character
	end
end

-- Invocado: fuego en las manos
local function addFireHands(character)
	for _, handName in { "RightHand", "LeftHand", "Right Arm", "Left Arm" } do
		local hand = character:FindFirstChild(handName)
		if hand then
			local fire = Instance.new("Fire")
			fire.Size = 2
			fire.Heat = 4
			fire.Color = Color3.fromRGB(255, 120, 30)
			fire.SecondaryColor = Color3.fromRGB(255, 220, 80)
			fire.Parent = hand

			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 140, 50)
			light.Range = 8
			light.Parent = hand
		end
	end
end

local function loadCharacter(player)
	local slot = PlayerData.Get(player)
	if not slot then
		return
	end
	local race = Config.Races[slot.Race]

	local description
	if player.UserId > 0 then
		local ok, result = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(player.UserId)
		end)
		if ok then
			description = result
		end
	end

	if not PlayerData.Get(player) then
		return -- volvió al menú mientras cargaba
	end

	if description then
		if race.BodyScale then
			description.HeightScale *= race.BodyScale
			description.WidthScale *= race.BodyScale
			description.DepthScale *= race.BodyScale
			description.HeadScale *= race.BodyScale
		end
		player:LoadCharacterWithHumanoidDescription(description)
	else
		player:LoadCharacter()
	end
end

local function onCharacterAdded(player, character)
	local slot = PlayerData.Get(player)
	if not slot then
		return
	end
	local race = Config.Races[slot.Race]

	if race.CanAbsorb then
		for _, descendant in character:GetDescendants() do
			hideHumanBody(descendant)
		end
		character.DescendantAdded:Connect(hideHumanBody)
		applySlimeBody(character, Config.GetForm(slot.Level))
	elseif slot.Race == "Elf" then
		addElfEars(character)
	elseif slot.Race == "Ogre" then
		addOgreHorns(character)
	elseif race.Fire then
		character:WaitForChild("Head", 10)
		addFireHands(character)
	end

	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	applyStats(player, slot, true)

	-- Reaparecer al morir (CharacterAutoLoads está desactivado por el menú)
	humanoid.Died:Connect(function()
		task.delay(4, function()
			if player.Parent and player.Character == character and PlayerData.Get(player) then
				loadCharacter(player)
			end
		end)
	end)
end

--------------------------------------------------------------------------------
-- Menú: slots, spins y jugar
--------------------------------------------------------------------------------

function PlayerData.GetMenu(player)
	local session = waitForSession(player)
	if not session then
		return nil
	end
	local slots = {}
	for index = 1, #Config.Slots do
		table.insert(slots, summarize(session.Profile, index))
	end
	return { Slots = slots }
end

function PlayerData.SelectSlot(player, index)
	local session = sessions[player]
	if not session or session.Playing or not isValidIndex(index) then
		return fail("No se puede seleccionar ese slot")
	end
	if not isUnlocked(session.Profile, index) then
		return fail("Slot bloqueado: requiere nivel " .. Config.Slots[index].RequiredLevel)
	end
	session.SlotIndex = index
	return { Ok = true, Slot = summarize(session.Profile, index) }
end

function PlayerData.Spin(player)
	local session = sessions[player]
	if not session or session.Playing or not session.SlotIndex then
		return fail("Primero elige un slot")
	end
	local slot = session.Profile.Data.Slots[session.SlotIndex]
	if slot.Spins <= 0 then
		return fail("No te quedan spins")
	end

	slot.Spins -= 1
	slot.Race = Config.RollRace(rng)
	return { Ok = true, Race = slot.Race, Spins = slot.Spins }
end

function PlayerData.Play(player)
	local session = sessions[player]
	if not session or session.Playing or not session.SlotIndex then
		return fail("Primero elige un slot")
	end
	session.Playing = true

	local slot = PlayerData.Get(player)
	local race = Config.Races[slot.Race]
	updateAttributes(player, slot)
	task.spawn(loadCharacter, player)

	-- Pequeña espera para que el HUD ya esté visible cuando llegue el mensaje
	task.delay(1, function()
		if not PlayerData.Get(player) then
			return
		end
		if race.CanAbsorb then
			notify(player, "¡Renaciste como Slime! Derrota monstruos y pulsa F para absorberlos.", CYAN)
		else
			notify(player, "¡Has entrado como " .. race.Name .. "! Derrota monstruos para subir de nivel.", CYAN)
		end
	end)
	return { Ok = true }
end

function PlayerData.ReturnToMenu(player)
	local session = sessions[player]
	if not session or not session.Playing then
		return
	end
	session.Playing = false
	if player.Character then
		player.Character:Destroy()
		player.Character = nil
	end
end

--------------------------------------------------------------------------------
-- Progreso
--------------------------------------------------------------------------------

function PlayerData.AddXP(player, amount)
	local slot = PlayerData.Get(player)
	if not slot then
		return
	end

	local oldBody = Config.GetBody(slot.Race, slot.Level)
	slot.XP += amount

	local leveledUp = false
	while slot.XP >= Config.XPToNextLevel(slot.Level) do
		slot.XP -= Config.XPToNextLevel(slot.Level)
		slot.Level += 1
		leveledUp = true
	end

	updateAttributes(player, slot)

	if leveledUp then
		local newBody = Config.GetBody(slot.Race, slot.Level)
		if Config.Races[slot.Race].CanAbsorb and newBody.Name ~= oldBody.Name then
			notify(player, "¡Has evolucionado a " .. newBody.Name .. "!", PURPLE)
			if player.Character then
				applySlimeBody(player.Character, newBody)
			end
		else
			notify(player, "¡Subiste de nivel! Ahora eres nivel " .. slot.Level, GOLD)
		end
		applyStats(player, slot, true)
	end
end

-- Lo llama Monsters cuando un jugador derrota a un monstruo.
-- Devuelve true si debe aparecer una esencia (solo para Slime).
function PlayerData.OnMonsterKilled(player, monsterId)
	local slot = PlayerData.Get(player)
	local def = Config.Monsters[monsterId]
	if not slot or not def then
		return false
	end

	local race = Config.Races[slot.Race]
	if race.CanAbsorb then
		return true -- el Slime gana la XP al absorber
	end

	local xp = math.floor(def.XP * race.XPMult + 0.5)
	notify(player, "Derrotaste a " .. def.DisplayName .. "  +" .. xp .. " XP", WHITE)
	PlayerData.AddXP(player, xp)
	return false
end

function PlayerData.Absorb(player, monsterId)
	local slot = PlayerData.Get(player)
	local def = Config.Monsters[monsterId]
	if not slot or not def then
		return
	end

	slot.Absorbed[monsterId] = (slot.Absorbed[monsterId] or 0) + 1

	local skillId = def.Skill
	if skillId and not slot.Skills[skillId] then
		slot.Skills[skillId] = true
		local skill = Config.Skills[skillId]
		notify(player, "¡Habilidad robada: " .. skill.DisplayName .. "! " .. skill.Description, CYAN)
		applyStats(player, slot, false)
	else
		notify(player, "Absorbiste " .. def.DisplayName .. "  +" .. def.XP .. " XP", WHITE)
	end

	PlayerData.AddXP(player, def.XP)
	updateAttributes(player, slot)
end

--------------------------------------------------------------------------------
-- Cargar y guardar
--------------------------------------------------------------------------------

local function onPlayerAdded(player)
	local profile = store:LoadProfileAsync("Player_" .. player.UserId, "ForceLoad")
	if not profile then
		player:Kick("No se pudieron cargar tus datos. Vuelve a entrar.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile:ListenToRelease(function()
		sessions[player] = nil
		player:Kick("Tus datos se cargaron en otro servidor. Vuelve a entrar.")
	end)

	if player.Parent ~= Players then
		profile:Release() -- salió mientras cargaba
		return
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Parent = leaderstats
	leaderstats.Parent = player

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	sessions[player] = { Profile = profile, SlotIndex = nil, Playing = false }
end

function PlayerData.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local session = sessions[player]
		if session then
			session.Profile:Release()
		end
	end)
end

return PlayerData
