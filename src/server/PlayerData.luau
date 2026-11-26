-- Guarda el progreso (ProfileService): 3 slots por jugador, cada uno con su raza,
-- nivel, oro y habilidades. También controla el menú, los spins y el aspecto del personaje.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local ProfileService = require(ServerScriptService.ServerPackages.ProfileService)
local Remotes = require(script.Parent.Remotes)

local PlayerData = {}

local function newSlot()
	return {
		Level = 1,
		XP = 0,
		Gold = 0,
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
		Gold = slot.Gold,
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

-- Modo prueba: en Studio, el dueño del juego o los UserId de Config.Testers
local function isTester(player)
	if RunService:IsStudio() then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end
	return table.find(Config.Testers, player.UserId) ~= nil
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
	player:SetAttribute("Gold", slot.Gold)
	player:SetAttribute("Race", slot.Race)
	player:SetAttribute("Form", Config.GetBody(slot.Race, slot.Level).Name)
	player:SetAttribute("Skills", table.concat(skills, ","))

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Level.Value = slot.Level
		leaderstats.Oro.Value = slot.Gold
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
	humanoid.WalkSpeed = Config.WalkSpeed(slot.Race)
	humanoid.UseJumpPower = true
	humanoid.JumpPower = if race.CanAbsorb and slot.Skills.HighJump then Config.Skills.HighJump.JumpPower else 50

	-- Monsters lee esto para reducir el daño mágico
	character:SetAttribute("MagicResist", race.MagicResist)
	character:SetAttribute("PhysicalResist", race.PhysicalResist)
end

--------------------------------------------------------------------------------
-- Aspecto del personaje según la raza (avatares R6)
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

-- Pega una pieza decorativa a la cabeza
local function addToHead(character, head, name, size, offset, color, shape)
	local part = makeExtraPart(name, size, head.CFrame * offset, color)
	if shape then
		part.Shape = shape
	end
	weld(part, head)
	part.Parent = character
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
	-- En R6 el HumanoidRootPart está a 3 studs del suelo
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

-- Elf y Major Elf: orejas puntiagudas
local function addElfEars(character, head, s)
	for _, side in { -1, 1 } do
		addToHead(
			character,
			head,
			"ElfEar",
			Vector3.new(0.15, 0.7, 0.3) * s,
			CFrame.new(side * 0.68 * s, 0.1 * s, 0) * CFrame.Angles(0, 0, -side * 0.6),
			head.Color
		)
	end
end

-- Major Elf: gorro verde puntiagudo con banda dorada y pluma
local function addElfHat(character, head, s)
	-- Quitar sombreros del avatar para que se vea el gorro
	for _, child in character:GetChildren() do
		if child:IsA("Accessory") and child.AccessoryType == Enum.AccessoryType.Hat then
			child:Destroy()
		end
	end

	local green = Color3.fromRGB(40, 150, 70)
	local gold = Color3.fromRGB(255, 200, 60)
	local up = CFrame.Angles(0, 0, math.rad(90)) -- los cilindros apuntan hacia arriba

	addToHead(
		character,
		head,
		"HatBrim",
		Vector3.new(0.12, 1.9, 1.9) * s,
		CFrame.new(0, 0.55 * s, 0) * up,
		green,
		Enum.PartType.Cylinder
	)
	addToHead(
		character,
		head,
		"HatBand",
		Vector3.new(0.18, 1.32, 1.32) * s,
		CFrame.new(0, 0.68 * s, 0) * up,
		gold,
		Enum.PartType.Cylinder
	)

	-- Cono hecho con cilindros cada vez más pequeños, inclinado hacia atrás
	local diameters = { 1.25, 1.0, 0.75, 0.5, 0.28 }
	for index, diameter in diameters do
		addToHead(
			character,
			head,
			"HatCone",
			Vector3.new(0.34, diameter, diameter) * s,
			CFrame.new(0, (0.75 + index * 0.3) * s, index * 0.09 * s) * up,
			green,
			Enum.PartType.Cylinder
		)
	end

	addToHead(
		character,
		head,
		"HatFeather",
		Vector3.new(0.1, 1.1, 0.3) * s,
		CFrame.new(0.6 * s, 1.1 * s, 0.1 * s) * CFrame.Angles(0, 0, -0.5),
		Color3.fromRGB(240, 240, 220)
	)
end

-- Ogre: cuernos pequeños y negros
local function addOgreHorns(character, head, s)
	for _, side in { -1, 1 } do
		addToHead(
			character,
			head,
			"OgreHorn",
			Vector3.new(0.5, 0.2, 0.2) * s,
			CFrame.new(side * 0.32 * s, 0.68 * s, -0.1 * s) * CFrame.Angles(0, 0, math.rad(90 - side * 20)),
			Color3.fromRGB(25, 22, 25),
			Enum.PartType.Cylinder
		)
		addToHead(
			character,
			head,
			"OgreHornTip",
			Vector3.new(0.22, 0.12, 0.12) * s,
			CFrame.new(side * 0.4 * s, 0.95 * s, -0.1 * s) * CFrame.Angles(0, 0, math.rad(90 - side * 35)),
			Color3.fromRGB(10, 10, 12),
			Enum.PartType.Cylinder
		)
	end
end

-- Invocado: capa del color de su elemento y magia en las manos
local function addSummonedLook(character, race)
	local torso = character:FindFirstChild("Torso")
	if torso then
		local function piece(name, size, offset, color, material)
			local part = makeExtraPart(name, size, torso.CFrame * offset, color)
			part.Material = material or Enum.Material.Fabric
			weld(part, torso)
			part.Parent = character
		end
		local gold = Color3.fromRGB(255, 200, 70)
		piece(
			"Cape",
			Vector3.new(2.1, 3, 0.15),
			CFrame.new(0, -0.4, 0.62) * CFrame.Angles(math.rad(8), 0, 0),
			race.CapeColor
		)
		piece(
			"CapeLining",
			Vector3.new(1.9, 2.8, 0.05),
			CFrame.new(0, -0.4, 0.53) * CFrame.Angles(math.rad(8), 0, 0),
			race.Color
		)
		piece("Collar", Vector3.new(2.2, 0.35, 1.2), CFrame.new(0, 0.95, 0.05), race.CapeColor:Lerp(Color3.new(), 0.25))
		piece("Clasp", Vector3.new(0.35, 0.35, 0.1), CFrame.new(0, 0.85, -0.55), gold, Enum.Material.Neon)
	end

	for _, armName in { "Right Arm", "Left Arm" } do
		local arm = character:FindFirstChild(armName)
		if arm then
			if race.Element == "Fire" then
				local fire = Instance.new("Fire")
				fire.Size = 2
				fire.Heat = 4
				fire.Color = Color3.fromRGB(255, 120, 30)
				fire.SecondaryColor = Color3.fromRGB(255, 220, 80)
				fire.Parent = arm
			else
				local attachment = Instance.new("Attachment")
				attachment.Position = Vector3.new(0, -arm.Size.Y / 2, 0)
				attachment.Parent = arm
				local particles = Instance.new("ParticleEmitter")
				particles.Color = ColorSequence.new(race.Color)
				particles.LightEmission = 0.6
				particles.Size = NumberSequence.new(0.35, 0)
				particles.Rate = 18
				particles.Lifetime = NumberRange.new(0.5, 0.9)
				particles.Speed = NumberRange.new(1, 2.5)
				particles.SpreadAngle = Vector2.new(180, 180)
				particles.Acceleration = if race.Element == "Water" then Vector3.new(0, -5, 0) else Vector3.new(0, 2, 0)
				particles.Parent = attachment
			end

			local light = Instance.new("PointLight")
			light.Color = race.Color
			light.Range = 8
			light.Parent = arm
		end
	end
end

local function waitForAppearance(player)
	local deadline = os.clock() + 5
	while not player:HasAppearanceLoaded() and player.Parent and os.clock() < deadline do
		task.wait(0.1)
	end
end

local function loadCharacter(player)
	if PlayerData.Get(player) then
		-- El juego está configurado como R6 (StarterPlayer.GameSettingsAvatar en default.project.json)
		player:LoadCharacter()
	end
end

local function onCharacterAdded(player, character)
	local slot = PlayerData.Get(player)
	if not slot then
		return
	end
	local race = Config.Races[slot.Race]

	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	if humanoid.RigType ~= Enum.HumanoidRigType.R6 then
		warn("[Slime Rebirth] El personaje no es R6. Revisa Game Settings > Avatar > Avatar Type = R6")
	end

	if race.CanAbsorb then
		for _, descendant in character:GetDescendants() do
			hideHumanBody(descendant)
		end
		character.DescendantAdded:Connect(hideHumanBody)
		applySlimeBody(character, Config.GetForm(slot.Level))
	else
		waitForAppearance(player)
		if character.Parent == nil then
			return
		end

		if race.BodyScale ~= 1 then
			character:ScaleTo(race.BodyScale)
		end

		local head = character:FindFirstChild("Head")
		local s = character:GetScale()
		if head then
			if race.ElfEars then
				addElfEars(character, head, s)
			end
			if race.ElfHat then
				addElfHat(character, head, s)
			end
			if slot.Race == "Ogre" then
				addOgreHorns(character, head, s)
			end
		end
		if race.Element then
			addSummonedLook(character, race)
		end
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

-- Modo prueba: elegir raza sin gastar spins
function PlayerData.SetRace(player, raceId)
	if not isTester(player) then
		return fail("Solo disponible en modo prueba")
	end
	local session = sessions[player]
	if not session or session.Playing or not session.SlotIndex then
		return fail("Primero elige un slot")
	end
	if type(raceId) ~= "string" or not Config.Races[raceId] then
		return fail("Raza no válida")
	end

	local slot = session.Profile.Data.Slots[session.SlotIndex]
	slot.Race = Config.ResolveRace(raceId, rng) -- "Invocado" -> uno de sus tipos al azar
	return { Ok = true, Race = slot.Race, Spins = slot.Spins }
end

function PlayerData.Play(player)
	local session = sessions[player]
	if not session or session.Playing or not session.SlotIndex then
		return fail("Primero elige un slot")
	end
	session.Playing = true

	local slot = PlayerData.Get(player)
	-- Datos antiguos: un "Invocado" sin tipo recibe uno al azar
	slot.Race = Config.ResolveRace(slot.Race, rng)
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
		elseif #race.Abilities > 0 then
			notify(player, "¡Has entrado como " .. race.Name .. "! Usa tus ataques especiales (E).", CYAN)
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
-- Da el oro (todas las razas) y la XP (todas menos Slime, que la gana al absorber).
-- Devuelve true si debe aparecer una esencia (solo para Slime).
function PlayerData.OnMonsterKilled(player, monsterId, level)
	local slot = PlayerData.Get(player)
	local def = Config.Monsters[monsterId]
	if not slot or not def then
		return false
	end

	local race = Config.Races[slot.Race]
	local gold = Config.GoldForKill(slot.Race, monsterId)
	slot.Gold += gold
	updateAttributes(player, slot)

	if race.CanAbsorb then
		return true
	end

	local xp = math.floor(Config.MonsterStats(monsterId, level).XP * race.XPMult + 0.5)
	notify(
		player,
		"Derrotaste a " .. def.DisplayName .. " Nv. " .. level .. "  +" .. xp .. " XP  +" .. gold .. " oro",
		WHITE
	)
	PlayerData.AddXP(player, xp)
	return false
end

function PlayerData.Absorb(player, monsterId, level)
	local slot = PlayerData.Get(player)
	local def = Config.Monsters[monsterId]
	if not slot or not def then
		return
	end

	slot.Absorbed[monsterId] = (slot.Absorbed[monsterId] or 0) + 1
	local xp = Config.MonsterStats(monsterId, level).XP

	local skillId = def.Skill
	if skillId and not slot.Skills[skillId] then
		slot.Skills[skillId] = true
		local skill = Config.Skills[skillId]
		notify(player, "¡Habilidad robada: " .. skill.DisplayName .. "! " .. skill.Description, CYAN)
		applyStats(player, slot, false)
	else
		notify(player, "Absorbiste " .. def.DisplayName .. " Nv. " .. level .. "  +" .. xp .. " XP", WHITE)
	end

	PlayerData.AddXP(player, xp)
	updateAttributes(player, slot)
end

-- La absorción falló: la esencia se pierde, pero da un poco de XP
function PlayerData.AbsorbFailed(player, monsterId, level, chance)
	local slot = PlayerData.Get(player)
	local def = Config.Monsters[monsterId]
	if not slot or not def then
		return
	end
	local xp = math.floor(Config.MonsterStats(monsterId, level).XP * 0.3)
	notify(
		player,
		"La absorción falló (" .. math.floor(chance * 100) .. "% de probabilidad)  +" .. xp .. " XP",
		Color3.fromRGB(255, 140, 140)
	)
	PlayerData.AddXP(player, xp)
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
	for _, statName in { "Level", "Oro" } do
		local value = Instance.new("IntValue")
		value.Name = statName
		value.Parent = leaderstats
	end
	leaderstats.Parent = player

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	player:SetAttribute("IsTester", isTester(player))
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
