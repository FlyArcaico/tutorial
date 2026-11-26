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
		Inventory = {}, -- [itemId] = cantidad
		StatPoints = {}, -- [statId] = puntos libres repartidos
		Weapons = {}, -- [weaponId] = true (armas compradas)
		-- Equipped = weaponId (arma equipada, o nil)
	}
end

local function defaultSettings()
	local settings = {}
	for _, setting in Config.Settings do
		settings[setting.Id] = true
	end
	return settings
end

local TEMPLATE = {
	Slots = { newSlot(), newSlot(), newSlot() },
	Settings = defaultSettings(),
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

local function spentPoints(slot)
	local spent = 0
	for _, points in slot.StatPoints do
		spent += points
	end
	return spent
end

local function computeStats(slot)
	return Config.ComputeStats(slot.Level, slot.Race, slot.StatPoints, slot.Absorbed)
end

-- Atributos actuales del jugador (Fuerza, Vitalidad...) mientras juega
function PlayerData.GetStats(player)
	local slot = PlayerData.Get(player)
	return slot and computeStats(slot)
end

-- El HUD del cliente lee estos atributos
local function updateAttributes(player, slot)
	local race = Config.Races[slot.Race]

	-- Atributos y puntos libres
	player:SetAttribute("Stats", Config.EncodeStats(computeStats(slot)))
	player:SetAttribute("StatPoints", Config.TotalStatPoints(slot.Level) - spentPoints(slot))
	player:SetAttribute("AbsorbTier", if race.CanAbsorb then Config.GetAbsorbTier(slot.Level).Name else "")
	local absorbed = {}
	for monsterId, count in slot.Absorbed do
		table.insert(absorbed, monsterId .. "=" .. count)
	end
	player:SetAttribute("Absorbed", table.concat(absorbed, ","))

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

	-- Inventario como texto: "HealthPotion=2,ManaPotion=1" (los atributos no admiten tablas)
	local items = {}
	for _, itemId in Config.ItemOrder do
		local count = slot.Inventory[itemId] or 0
		if count > 0 then
			table.insert(items, itemId .. "=" .. count)
		end
	end
	player:SetAttribute("Inventory", table.concat(items, ","))
	player:SetAttribute("Spins", slot.Spins)

	-- Armas
	local weapons = {}
	for _, weaponId in Config.WeaponOrder do
		if slot.Weapons[weaponId] then
			table.insert(weapons, weaponId)
		end
	end
	player:SetAttribute("Weapons", table.concat(weapons, ","))
	player:SetAttribute("Equipped", slot.Equipped or "")
	player:SetAttribute("AttackCooldown", Config.AttackCooldown(slot.Equipped))

	-- Misión activa (el HUD muestra el progreso arriba a la izquierda)
	local quest = slot.Quest and Config.GetQuest(slot.Quest.Id)
	player:SetAttribute("QuestId", if quest then quest.Id else "")
	player:SetAttribute("QuestKills", if quest then slot.Quest.Kills else 0)

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
	local stats = computeStats(slot)
	local maxHealth = Config.MaxHealth(stats, slot.Race, slot.Skills)
	local ratio = humanoid.Health / math.max(humanoid.MaxHealth, 1)
	humanoid.MaxHealth = maxHealth
	humanoid.Health = if heal then maxHealth else math.min(maxHealth, maxHealth * ratio)
	humanoid.WalkSpeed = Config.WalkSpeed(stats, slot.Race)
	humanoid.UseJumpPower = true
	humanoid.JumpPower = if race.CanAbsorb and slot.Skills.HighJump then Config.Skills.HighJump.JumpPower else 50

	-- Monsters lee esto para reducir el daño recibido
	character:SetAttribute("MagicResist", Config.MagicResist(stats, slot.Race))
	character:SetAttribute("PhysicalResist", Config.PhysicalResist(stats, slot.Race))
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
	body:SetAttribute("Size", d)
	-- En R6 el HumanoidRootPart está a 3 studs del suelo
	local base = root.CFrame * CFrame.new(0, height / 2 - 3, 0)

	-- Se usan Weld (no WeldConstraint) para que el cliente pueda animar las piezas.
	-- BaseC0 guarda la posición original de cada pieza.
	local function attach(part)
		local joint = Instance.new("Weld")
		joint.Part0 = root
		joint.Part1 = part
		joint.C0 = root.CFrame:ToObjectSpace(part.CFrame)
		joint:SetAttribute("BaseC0", joint.C0)
		joint.Parent = part
		part.Parent = body
	end

	local function sphere(name, size, cframe, color, transparency)
		local part = makeExtraPart(name, size, cframe, color)
		part.Transparency = transparency
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
		attach(part)
		return part
	end

	-- Interior azul intenso
	local blob = sphere("Blob", Vector3.new(d, height, d), base, form.Color, 0.05)

	-- Contorno azul clarito alrededor de la silueta (no tapa los ojos)
	local outline = Instance.new("Highlight")
	outline.Name = "SlimeOutline"
	outline.Adornee = blob
	outline.FillTransparency = 1
	outline.OutlineColor = Color3.fromRGB(175, 230, 255)
	outline.OutlineTransparency = 0
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = body

	-- Ojos de "dormido": cada ojo es una curva ◡ de 3 trocitos, pegada POR FUERA del cuerpo
	local rx, ry = d / 2, height / 2
	local function surfaceZ(x, y)
		local inside = 1 - (x / rx) ^ 2 - (y / ry) ^ 2
		return -rx * math.sqrt(math.max(inside, 0)) - d * 0.015
	end
	local eyeColor = Color3.fromRGB(20, 30, 60)
	local segment = Vector3.new(d * 0.075, d * 0.032, d * 0.03)
	for _, side in { -1, 1 } do
		local ex, ey = side * d * 0.17, height * 0.1
		-- { desplazamiento x, desplazamiento y, inclinación }: centro abajo, puntas arriba
		for _, piece in { { 0, -d * 0.012, 0 }, { -d * 0.06, 0, -0.45 }, { d * 0.06, 0, 0.45 } } do
			local x, y = ex + piece[1], ey + piece[2]
			local eye = makeExtraPart(
				"Eye",
				segment,
				base * CFrame.new(x, y, surfaceZ(x, y)) * CFrame.Angles(0, -x / rx * 0.9, piece[3]),
				eyeColor
			)
			eye:SetAttribute("SlimeEye", true)
			attach(eye)
		end
	end

	sphere(
		"Shine",
		Vector3.one * d * 0.13,
		base * CFrame.new(d * 0.22, height * 0.32, -d * 0.3),
		Color3.new(1, 1, 1),
		0.25
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

-- Espada en la mano derecha. Cuanto mejor es el arma, más detalles tiene.
local function attachWeapon(character, weaponId)
	local old = character:FindFirstChild("EquippedWeapon")
	if old then
		old:Destroy()
	end
	local weapon = weaponId and Config.Weapons[weaponId]
	local arm = character:FindFirstChild("Right Arm")
	if not weapon or not arm then
		return
	end

	local look = weapon.Look
	local s = character:GetScale()
	local model = Instance.new("Model")
	model.Name = "EquippedWeapon"

	-- La espada sale de la mano hacia delante, un poco inclinada hacia arriba
	local hand = arm.CFrame * CFrame.new(0, -arm.Size.Y / 2 + 0.15 * s, 0) * CFrame.Angles(math.rad(10), 0, 0)
	local function piece(name, size, offset, color, props)
		local part = makeExtraPart(name, size * s, hand * CFrame.new(offset * s), color)
		for key, value in props or {} do
			part[key] = value
		end
		weld(part, arm)
		part.Parent = model
		return part
	end

	local length = look.Length
	piece("Grip", Vector3.new(0.28, 0.28, 1), Vector3.new(0, 0, 0), look.Handle, { Material = Enum.Material.Fabric })
	piece("Pommel", Vector3.one * 0.38, Vector3.new(0, 0, 0.62), look.Guard, { Shape = Enum.PartType.Ball })
	piece(
		"Guard",
		Vector3.new(1.3, 0.22, 0.25),
		Vector3.new(0, 0, -0.6),
		look.Guard,
		{ Material = Enum.Material.Metal }
	)
	local blade = piece(
		"Blade",
		Vector3.new(0.1, 0.42, length),
		Vector3.new(0, 0, -0.72 - length / 2),
		look.Blade,
		{ Material = Enum.Material.Metal, Reflectance = 0.15 }
	)
	piece(
		"Tip",
		Vector3.new(0.1, 0.24, 0.4),
		Vector3.new(0, 0, -0.92 - length),
		look.Blade,
		{ Material = Enum.Material.Metal }
	)

	-- Raro en adelante: gema en la guarda
	if look.Gem then
		piece("Gem", Vector3.one * 0.26, Vector3.new(0, 0, -0.6), look.Gem, {
			Shape = Enum.PartType.Ball,
			Material = Enum.Material.Neon,
		})
	end
	-- Épico en adelante: guarda con "alas" y filo brillante
	if look.Wings then
		for _, side in { -1, 1 } do
			piece(
				"Wing",
				Vector3.new(0.5, 0.15, 0.2),
				Vector3.new(side * 0.78, 0, -0.5),
				look.Guard,
				{ Material = Enum.Material.Metal }
			)
		end
	end
	if look.Glow then
		piece(
			"Edge",
			Vector3.new(0.12, 0.08, length * 0.9),
			Vector3.new(0, 0.18, -0.72 - length / 2),
			look.Gem or look.Blade,
			{
				Material = Enum.Material.Neon,
			}
		)
		local light = Instance.new("PointLight")
		light.Color = look.Gem or look.Blade
		light.Range = 8
		light.Brightness = 1.5
		light.Parent = blade
	end
	-- Legendario: hoja en llamas. Mítico: destellos.
	if look.Fire then
		local fire = Instance.new("Fire")
		fire.Size = 2.5
		fire.Heat = 3
		fire.Color = Color3.fromRGB(255, 120, 30)
		fire.SecondaryColor = Color3.fromRGB(255, 220, 80)
		fire.Parent = blade
	end
	if look.Sparkles then
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Color = ColorSequence.new(look.Gem, look.Blade)
		sparkles.LightEmission = 1
		sparkles.Size = NumberSequence.new(0.25, 0)
		sparkles.Rate = 20
		sparkles.Lifetime = NumberRange.new(0.4, 0.8)
		sparkles.Speed = NumberRange.new(0.5, 1.5)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Parent = blade
	end

	model.Parent = character
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
		if slot.Equipped then
			attachWeapon(character, slot.Equipped)
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
	local oldTier = Config.GetAbsorbTier(slot.Level)
	local oldAwakening = Config.GetAwakening(slot.Level)
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
			notify(
				player,
				"¡Subiste de nivel! Nivel "
					.. slot.Level
					.. "  (+"
					.. Config.PointsPerLevel
					.. " puntos de atributo, pulsa M)",
				GOLD
			)
		end

		-- La habilidad de absorber mejora (Absorber -> Devorador -> Habilidad Única)
		local newTier = Config.GetAbsorbTier(slot.Level)
		if Config.Races[slot.Race].CanAbsorb and newTier ~= oldTier then
			local prefix = if newTier.Unique then "¡HABILIDAD ÚNICA despertada: " else "¡Tu habilidad evolucionó a "
			notify(player, prefix .. newTier.Name .. "!", Color3.fromRGB(255, 90, 160))
		end

		local newAwakening = Config.GetAwakening(slot.Level)
		if newAwakening and newAwakening ~= oldAwakening then
			notify(
				player,
				"¡" .. newAwakening.Name .. "! Todos tus atributos +" .. math.floor(newAwakening.Bonus * 100) .. "%",
				PURPLE
			)
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

	-- Progreso de la misión
	local quest = slot.Quest and Config.GetQuest(slot.Quest.Id)
	if quest and quest.Monster == monsterId and slot.Quest.Kills < quest.Count then
		slot.Quest.Kills += 1
		slot.Quest.BonusXP += Config.MonsterStats(monsterId, level).XP * Config.QuestKillBonus.XPMult
		slot.Quest.BonusGold += level * Config.QuestKillBonus.GoldPerLevel
		if slot.Quest.Kills >= quest.Count then
			notify(
				player,
				"¡Misión completada! Vuelve con " .. Config.QuestGiver.Name .. " para tu recompensa",
				Color3.fromRGB(255, 215, 90)
			)
		end
	end

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

	local count = (slot.Absorbed[monsterId] or 0) + 1
	slot.Absorbed[monsterId] = count
	local tier = Config.GetAbsorbTier(slot.Level)
	local xp = math.floor(Config.MonsterStats(monsterId, level).XP * tier.XPMult)

	-- Habilidades de este monstruo que se desbloquean al llegar a X absorbidos
	local learned = false
	for _, skillId in Config.SkillOrder do
		local skill = Config.Skills[skillId]
		if skill.From == monsterId and count >= skill.Required and not slot.Skills[skillId] then
			slot.Skills[skillId] = true
			learned = true
			notify(player, "¡Habilidad robada: " .. skill.DisplayName .. "! " .. skill.Description, CYAN)
		end
	end
	if not learned then
		notify(
			player,
			"Absorbiste " .. def.DisplayName .. " Nv. " .. level .. " (" .. count .. ")  +" .. xp .. " XP",
			WHITE
		)
	end

	PlayerData.AddXP(player, xp)
	updateAttributes(player, slot)
	applyStats(player, slot, false) -- los atributos ganados al absorber cuentan al momento
end

-- Repartir un punto libre en un atributo
function PlayerData.AllocateStat(player, statId)
	local slot = PlayerData.Get(player)
	if not slot then
		return fail("Entra al juego primero")
	end
	local valid = false
	for _, stat in Config.Stats do
		if stat.Id == statId then
			valid = true
		end
	end
	if not valid then
		return fail("Atributo no válido")
	end
	if Config.TotalStatPoints(slot.Level) - spentPoints(slot) <= 0 then
		return fail("No te quedan puntos libres")
	end

	slot.StatPoints[statId] = (slot.StatPoints[statId] or 0) + 1
	updateAttributes(player, slot)
	applyStats(player, slot, false)
	return { Ok = true }
end

-- Devuelve todos los puntos libres repartidos (objeto de la tienda o al bajar de nivel)
function PlayerData.ResetStatPoints(player)
	local slot = PlayerData.Get(player)
	if not slot then
		return
	end
	slot.StatPoints = {}
	updateAttributes(player, slot)
	applyStats(player, slot, false)
end

--------------------------------------------------------------------------------
-- Misiones del NPC
--------------------------------------------------------------------------------

local function questReward(slot)
	local quest = Config.GetQuest(slot.Quest.Id)
	return math.floor(quest.BaseXP + slot.Quest.BonusXP), math.floor(quest.BaseGold + slot.Quest.BonusGold)
end

local function isNearQuestGiver(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	return (root.Position - Config.QuestGiver.Position).Magnitude <= Config.QuestGiver.TalkDistance + 4
end

-- Estado de misiones para el diálogo del cliente
local function questState(slot)
	if not slot.Quest or not Config.GetQuest(slot.Quest.Id) then
		return { State = "None", Level = slot.Level }
	end
	local quest = Config.GetQuest(slot.Quest.Id)
	local xp, gold = questReward(slot)
	return {
		State = if slot.Quest.Kills >= quest.Count then "Done" else "Active",
		Level = slot.Level,
		QuestId = quest.Id,
		Kills = slot.Quest.Kills,
		RewardXP = xp,
		RewardGold = gold,
	}
end

-- action: "Get", "Accept" (questId), "Claim", "Abandon"
function PlayerData.QuestAction(player, action, questId)
	local slot = PlayerData.Get(player)
	if not slot then
		return fail("Entra al juego primero")
	end
	if action == "Get" then
		return { Ok = true, Quest = questState(slot) }
	end
	if not isNearQuestGiver(player) then
		return fail("Estás demasiado lejos de " .. Config.QuestGiver.Name)
	end

	if action == "Accept" then
		local quest = type(questId) == "string" and Config.GetQuest(questId)
		if not quest then
			return fail("Misión no válida")
		end
		if slot.Quest then
			return fail("Ya tienes una misión activa")
		end
		if slot.Level < quest.MinLevel then
			return fail("Necesitas nivel " .. quest.MinLevel)
		end
		slot.Quest = { Id = quest.Id, Kills = 0, BonusXP = 0, BonusGold = 0 }
		notify(player, "Misión aceptada: " .. quest.Title, Color3.fromRGB(255, 215, 90))
	elseif action == "Claim" then
		local quest = slot.Quest and Config.GetQuest(slot.Quest.Id)
		if not quest or slot.Quest.Kills < quest.Count then
			return fail("Todavía no has terminado la misión")
		end
		local xp, gold = questReward(slot)
		slot.Quest = nil
		slot.Gold += gold
		notify(player, "¡Recompensa: +" .. xp .. " XP y +" .. gold .. " oro!", Color3.fromRGB(255, 215, 90))
		PlayerData.AddXP(player, xp)
	elseif action == "Abandon" then
		slot.Quest = nil
		notify(player, "Misión abandonada", Color3.fromRGB(180, 180, 180))
	else
		return fail("Acción no válida")
	end

	updateAttributes(player, slot)
	return { Ok = true, Quest = questState(slot) }
end

--------------------------------------------------------------------------------
-- Tienda, inventario y ajustes
--------------------------------------------------------------------------------

local function isNearShop(player, shopId)
	local shop = Config.Shops[shopId]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return shop ~= nil and root ~= nil and (root.Position - shop.Position).Magnitude <= Config.ShopTalkDistance + 6
end

-- Comprar en la tienda de Medicina (hay que estar cerca del NPC)
function PlayerData.Buy(player, itemId, amount)
	local slot = PlayerData.Get(player)
	local item = type(itemId) == "string" and Config.Items[itemId]
	if not slot or not item or not table.find(Config.Shops.Medicine.Items, itemId) then
		return fail("Objeto no válido")
	end
	if not isNearShop(player, "Medicine") then
		return fail("Acércate a la tienda de Medicina")
	end
	amount = if amount == 5 then 5 else 1
	local owned = slot.Inventory[itemId] or 0
	if owned + amount > Config.MaxItemStack then
		return fail("No puedes llevar más de " .. Config.MaxItemStack)
	end
	local cost = item.Price * amount
	if slot.Gold < cost then
		return fail("No tienes suficiente oro (" .. cost .. ")")
	end

	slot.Gold -= cost
	slot.Inventory[itemId] = owned + amount
	updateAttributes(player, slot)
	notify(
		player,
		"Compraste " .. amount .. "× " .. item.Name .. "  -" .. cost .. " oro",
		Color3.fromRGB(255, 215, 90)
	)
	return { Ok = true }
end

-- Comprar un arma en la Herrería (se equipa al momento)
function PlayerData.BuyWeapon(player, weaponId)
	local slot = PlayerData.Get(player)
	local weapon = type(weaponId) == "string" and Config.Weapons[weaponId]
	if not slot or not weapon then
		return fail("Arma no válida")
	end
	if not isNearShop(player, "Blacksmith") then
		return fail("Acércate a la Herrería")
	end
	if Config.Races[slot.Race].CanAbsorb then
		return fail("El Slime aún no tiene forma humana para usar espadas")
	end
	if slot.Weapons[weaponId] then
		return fail("Ya tienes esta arma")
	end
	if slot.Gold < weapon.Price then
		return fail("No tienes suficiente oro (" .. weapon.Price .. ")")
	end

	slot.Gold -= weapon.Price
	slot.Weapons[weaponId] = true
	slot.Equipped = weaponId
	if player.Character then
		attachWeapon(player.Character, weaponId)
	end
	updateAttributes(player, slot)
	notify(player, "¡Compraste y equipaste " .. weapon.Name .. "!", Config.Rarities[weapon.Rarity].Color)
	return { Ok = true }
end

-- Equipar un arma que ya tienes ("" para quitártela)
function PlayerData.Equip(player, weaponId)
	local slot = PlayerData.Get(player)
	if not slot then
		return fail("Entra al juego primero")
	end
	if weaponId == "" then
		slot.Equipped = nil
	else
		if type(weaponId) ~= "string" or not slot.Weapons[weaponId] then
			return fail("No tienes esa arma")
		end
		if Config.Races[slot.Race].CanAbsorb then
			return fail("El Slime aún no tiene forma humana para usar espadas")
		end
		slot.Equipped = weaponId
	end
	if player.Character then
		attachWeapon(player.Character, slot.Equipped)
	end
	updateAttributes(player, slot)
	return { Ok = true }
end

-- Quita un objeto del inventario. Devuelve true si lo tenía.
function PlayerData.TakeItem(player, itemId)
	local slot = PlayerData.Get(player)
	if not slot or (slot.Inventory[itemId] or 0) <= 0 then
		return false
	end
	slot.Inventory[itemId] -= 1
	if slot.Inventory[itemId] <= 0 then
		slot.Inventory[itemId] = nil
	end
	updateAttributes(player, slot)
	return true
end

function PlayerData.AddSpins(player, amount)
	local slot = PlayerData.Get(player)
	if slot then
		slot.Spins += amount
		updateAttributes(player, slot)
	end
end

function PlayerData.SaveSetting(player, settingId, enabled)
	local session = sessions[player]
	if not session or type(settingId) ~= "string" or type(enabled) ~= "boolean" then
		return
	end
	for _, setting in Config.Settings do
		if setting.Id == settingId then
			session.Profile.Data.Settings[settingId] = enabled
			player:SetAttribute("Setting" .. settingId, enabled)
			return
		end
	end
end

--------------------------------------------------------------------------------
-- Modo prueba: subir o bajar niveles
--------------------------------------------------------------------------------

function PlayerData.DevChangeLevel(player, delta)
	local slot = PlayerData.Get(player)
	if not slot or not isTester(player) or (delta ~= 5 and delta ~= -5) then
		return
	end

	local oldBody = Config.GetBody(slot.Race, slot.Level)
	slot.Level = math.max(1, slot.Level + delta)
	slot.XP = 0
	-- Si bajas de nivel y tenías más puntos repartidos de los que te tocan, se devuelven
	if spentPoints(slot) > Config.TotalStatPoints(slot.Level) then
		slot.StatPoints = {}
	end
	updateAttributes(player, slot)

	local newBody = Config.GetBody(slot.Race, slot.Level)
	if Config.Races[slot.Race].CanAbsorb and newBody.Name ~= oldBody.Name and player.Character then
		applySlimeBody(player.Character, newBody)
		notify(player, "Modo prueba: nivel " .. slot.Level .. " (" .. newBody.Name .. ")", PURPLE)
	else
		notify(player, "Modo prueba: nivel " .. slot.Level, PURPLE)
	end
	applyStats(player, slot, true)
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
	for _, setting in Config.Settings do
		player:SetAttribute("Setting" .. setting.Id, profile.Data.Settings[setting.Id] ~= false)
	end
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
