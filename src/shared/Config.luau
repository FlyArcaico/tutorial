-- Balance y contenido del juego. Cambia los números aquí para ajustar el juego.
local Config = {}

Config.GameName = "Slime Rebirth"

--------------------------------------------------------------------------------
-- Slots y spins
--------------------------------------------------------------------------------

-- Nivel necesario para desbloquear cada slot (cuenta el nivel más alto de tus slots)
Config.Slots = {
	{ RequiredLevel = 0 },
	{ RequiredLevel = 50 },
	{ RequiredLevel = 100 },
}

Config.StartingSpins = 5 -- spins gratis que tiene cada slot nuevo

-- Modo prueba: estos jugadores pueden elegir raza sin hacer Spin.
-- En Roblox Studio y para el dueño del juego se activa solo.
-- Para añadir a alguien más, pon su UserId, por ejemplo: { 12345678 }
Config.Testers = {}
Config.DefaultRace = "Human"

--------------------------------------------------------------------------------
-- Rarezas y razas
--------------------------------------------------------------------------------

-- Weight sobre 1000: Mítico 0,1% / Legendario 3% / Épico 10% / Raro 30% / Común 56,9%
Config.Rarities = {
	Mythic = { Name = "Mítico", Weight = 1, Color = Color3.fromRGB(255, 70, 120) },
	Legendary = { Name = "Legendario", Weight = 30, Color = Color3.fromRGB(255, 190, 40) },
	Epic = { Name = "Épico", Weight = 100, Color = Color3.fromRGB(180, 100, 255) },
	Rare = { Name = "Raro", Weight = 300, Color = Color3.fromRGB(70, 160, 255) },
	Common = { Name = "Común", Weight = 569, Color = Color3.fromRGB(200, 200, 200) },
}

-- Orden de la más rara a la más común
Config.RaceOrder = { "Slime", "Summoned", "Ogre", "Elf", "Human" }

Config.Races = {
	Slime = {
		Name = "Slime",
		Rarity = "Mythic",
		Color = Color3.fromRGB(90, 170, 255),
		Description = "Absorbe a los enemigos derrotados para volverse más fuerte y les roba sus habilidades.",
		Traits = { "Absorber (F): roba habilidades", "Evoluciona al subir de nivel" },
		CanAbsorb = true,
	},
	Summoned = {
		Name = "Invocado",
		Rarity = "Legendary",
		Color = Color3.fromRGB(255, 130, 40),
		Description = "Llegó de otro mundo con poderes innatos: controla el fuego y ataca con llamas.",
		Traits = { "Ataques de fuego: +30% daño", "+4 de alcance de ataque" },
		DamageMult = 1.3,
		RangeBonus = 4,
		Fire = true,
	},
	Ogre = {
		Name = "Ogre",
		Rarity = "Epic",
		Color = Color3.fromRGB(190, 110, 90),
		Description = "Un guerrero enorme con más fuerza, defensa y velocidad.",
		Traits = { "+50% vida", "+25% daño", "+15% velocidad" },
		HealthMult = 1.5,
		DamageMult = 1.25,
		SpeedMult = 1.15,
		BodyScale = 1.3,
	},
	Elf = {
		Name = "Elf",
		Rarity = "Rare",
		Color = Color3.fromRGB(100, 200, 110),
		Description = "Inteligente y ágil: aprende más rápido y se mueve con rapidez.",
		Traits = { "+25% XP", "+20% velocidad", "+10% daño" },
		XPMult = 1.25,
		SpeedMult = 1.2,
		DamageMult = 1.1,
	},
	Human = {
		Name = "Human",
		Rarity = "Common",
		Color = Color3.fromRGB(230, 230, 230),
		Description = "Un humano común. Nada especial... por ahora.",
		Traits = { "Sin bonus" },
	},
}

-- Valores por defecto para lo que una raza no indique
for _, race in Config.Races do
	race.HealthMult = race.HealthMult or 1
	race.DamageMult = race.DamageMult or 1
	race.SpeedMult = race.SpeedMult or 1
	race.XPMult = race.XPMult or 1
	race.RangeBonus = race.RangeBonus or 0
	race.CanAbsorb = race.CanAbsorb == true
end

-- Devuelve una raza al azar según las probabilidades de su rareza
function Config.RollRace(rng)
	local roll = rng:NextInteger(1, 1000)
	local total = 0
	for _, raceId in Config.RaceOrder do
		total += Config.Rarities[Config.Races[raceId].Rarity].Weight
		if roll <= total then
			return raceId
		end
	end
	return Config.DefaultRace
end

-- "0,1%", "56,9%"...
function Config.ChanceText(rarityId)
	local percent = Config.Rarities[rarityId].Weight / 10
	return (string.gsub(string.format("%g%%", percent), "%.", ","))
end

--------------------------------------------------------------------------------
-- Combate
--------------------------------------------------------------------------------

Config.Attack = {
	Range = 8, -- studs delante del personaje (más la mitad de su tamaño)
	Cooldown = 0.5, -- segundos entre ataques
}

Config.AbsorbRange = 12 -- distancia máxima para absorber una esencia
Config.EssenceLifetime = 20 -- segundos antes de que una esencia desaparezca

-- Formas del Slime. Evoluciona automáticamente al llegar a MinLevel.
-- Mantenlas ordenadas de menor a mayor nivel.
Config.Forms = {
	{
		Name = "Slime pequeño",
		MinLevel = 1,
		Size = 3,
		Color = Color3.fromRGB(90, 170, 255),
		DamageBonus = 0,
	},
	{
		Name = "Slime mayor",
		MinLevel = 5,
		Size = 4.5,
		Color = Color3.fromRGB(70, 215, 190),
		DamageBonus = 5,
	},
	{
		Name = "Slime monarca",
		MinLevel = 10,
		Size = 6,
		Color = Color3.fromRGB(170, 110, 255),
		DamageBonus = 15,
	},
}

-- Habilidades que el Slime roba al absorber un tipo de monstruo por primera vez
Config.Skills = {
	Dash = {
		DisplayName = "Embestida de lobo",
		Description = "Embiste hacia delante (Q)",
		Cooldown = 2,
		Speed = 90,
		Duration = 0.25,
	},
	HighJump = {
		DisplayName = "Alas de murciélago",
		Description = "Pasiva: saltas mucho más alto",
		JumpPower = 85,
	},
	StoneSkin = {
		DisplayName = "Piel de piedra",
		Description = "Pasiva: +50 de vida máxima",
		BonusHealth = 50,
	},
}

Config.Monsters = {
	Bat = {
		DisplayName = "Murciélago de cueva",
		Health = 25,
		Damage = 5,
		Speed = 17,
		XP = 15,
		Skill = "HighJump",
		Color = Color3.fromRGB(70, 55, 95),
		Size = Vector3.new(2.5, 2, 2.5),
		AggroRange = 35,
	},
	Wolf = {
		DisplayName = "Lobo del bosque",
		Health = 45,
		Damage = 8,
		Speed = 15,
		XP = 25,
		Skill = "Dash",
		Color = Color3.fromRGB(125, 115, 105),
		Size = Vector3.new(3, 3, 5),
		AggroRange = 40,
	},
	Golem = {
		DisplayName = "Gólem de roca",
		Health = 160,
		Damage = 18,
		Speed = 9,
		XP = 90,
		Skill = "StoneSkin",
		Color = Color3.fromRGB(135, 130, 120),
		Size = Vector3.new(6, 7, 5),
		AggroRange = 30,
	},
}

-- Zonas donde aparecen monstruos. El spawn está en (0, 0, 0); las zonas van al norte (-Z).
Config.Zones = {
	{
		Name = "Pradera Susurrante",
		Label = "Pradera Susurrante\nNivel 1+",
		Center = Vector3.new(0, 0, -140),
		Radius = 70,
		Monsters = { "Bat", "Bat", "Wolf" },
		MaxMonsters = 10,
	},
	{
		Name = "Colinas de Piedra",
		Label = "Colinas de Piedra\nNivel 5+",
		Center = Vector3.new(0, 0, -340),
		Radius = 80,
		Monsters = { "Wolf", "Golem", "Golem" },
		MaxMonsters = 6,
	},
}

--------------------------------------------------------------------------------
-- Fórmulas
--------------------------------------------------------------------------------

function Config.GetForm(level)
	local current = Config.Forms[1]
	for _, form in Config.Forms do
		if level >= form.MinLevel then
			current = form
		end
	end
	return current
end

-- El "cuerpo" del personaje: formas para el Slime, tamaño normal para las demás razas
function Config.GetBody(raceId, level)
	local race = Config.Races[raceId]
	if race.CanAbsorb then
		return Config.GetForm(level)
	end
	return { Name = race.Name, Size = 3, Color = race.Color, DamageBonus = 0 }
end

function Config.XPToNextLevel(level)
	return 40 + level * 20
end

function Config.MaxHealth(level, raceId, skills)
	local race = Config.Races[raceId]
	local health = (100 + (level - 1) * 15) * race.HealthMult
	if race.CanAbsorb and skills.StoneSkin then
		health += Config.Skills.StoneSkin.BonusHealth
	end
	return math.floor(health)
end

function Config.AttackDamage(level, raceId)
	local race = Config.Races[raceId]
	local base = 10 + (level - 1) * 4 + Config.GetBody(raceId, level).DamageBonus
	return math.floor(base * race.DamageMult)
end

function Config.AttackRange(level, raceId)
	local race = Config.Races[raceId]
	return Config.Attack.Range + Config.GetBody(raceId, level).Size / 2 + race.RangeBonus
end

function Config.WalkSpeed(level, raceId)
	return (16 + math.min(level, 20) * 0.4) * Config.Races[raceId].SpeedMult
end

return Config
