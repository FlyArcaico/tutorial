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
Config.DefaultRace = "Human"

-- Modo prueba: estos jugadores pueden elegir raza sin hacer Spin.
-- En Roblox Studio y para el dueño del juego se activa solo.
-- Para añadir a alguien más, pon su UserId, por ejemplo: { 12345678 }
Config.Testers = {}

--------------------------------------------------------------------------------
-- Velocidad, combate y maná
--------------------------------------------------------------------------------

Config.BaseSpeed = 16 -- velocidad del Human y de los monstruos

Config.Attack = {
	Range = 8, -- studs delante del personaje (más la mitad de su tamaño)
	Cooldown = 0.5, -- segundos entre ataques
}

Config.OutOfCombatDelay = 4 -- segundos sin pegar ni recibir daño para estar "fuera de combate"
Config.ManaRegenInCombat = 0.01 -- fracción del maná máximo por segundo en combate

-- Sobrecarga de energía (Invocados): cada habilidad suma "calor"; si se acumula demasiado,
-- baja el daño y la velocidad durante unos segundos.
Config.Overload = {
	HeatPerCast = 1,
	DecayPerSecond = 0.25,
	Threshold = 3.5,
	Duration = 5,
	DamageMult = 0.7,
	SpeedMult = 0.75,
}

-- Correr (mantener Control izquierdo). Cada raza tiene su propia stamina (ver Config.Races).
Config.Sprint = {
	RegenDelay = 0.8, -- segundos sin correr antes de recuperar stamina
	ExhaustedRecover = 0.3, -- si te quedas sin stamina, no puedes correr hasta recuperar este %
}

-- Zona segura alrededor del spawn: los monstruos no entran ni atacan dentro, y te curas.
Config.SafeZone = {
	Center = Vector3.new(0, 0, 0),
	Radius = 40,
	HealPerSecond = 0.05, -- fracción de vida por segundo
}

function Config.IsInSafeZone(position)
	local offset = position - Config.SafeZone.Center
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= Config.SafeZone.Radius
end

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

-- Razas principales que salen en el Spin, de la más rara a la más común
Config.RaceOrder = { "Slime", "Summoned", "Ogre", "Elf", "Human" }

-- Orden en que se muestran en el menú (subtipos y tipos debajo de su raza)
Config.DisplayOrder = {
	"Slime",
	"Summoned",
	"SummonedFire",
	"SummonedWater",
	"SummonedPlant",
	"Ogre",
	"Elf",
	"MajorElf",
	"Human",
}

-- Pasivas comunes de todos los Invocados
local SUMMONED_TRAITS = {
	"Cuerpo Impregnado de Maná: +30% de maná máximo (500) y regeneración fuera de combate",
	"Barrera Multidimensional: -12% daño mágico recibido",
	"Sobrecarga de Energía: si abusas de las habilidades, -30% daño y -25% velocidad",
}

local function summonedTraits(abilityLine)
	local traits = { abilityLine }
	for _, trait in SUMMONED_TRAITS do
		table.insert(traits, trait)
	end
	return traits
end

Config.Races = {
	Slime = {
		Name = "Slime",
		Rarity = "Mythic",
		Color = Color3.fromRGB(90, 170, 255),
		Description = "Absorbe a los enemigos derrotados para volverse más fuerte y les roba sus habilidades.",
		Traits = {
			"Absorber (F): roba habilidades. La probabilidad sube con tu nivel",
			"Cuerpo de Slime: -25% daño físico recibido",
			"Regeneración: recupera vida fuera de combate",
			"Evoluciona al subir de nivel",
		},
		CanAbsorb = true,
		MaxMana = 120,
		Stamina = { Max = 110, Drain = 18, Regen = 20, SpeedMult = 1.5 },
		PhysicalResist = 0.25,
		HealthRegen = 0.03, -- fracción de vida por segundo fuera de combate
	},

	-- Invocado: al salir en el Spin se elige uno de sus 3 tipos al azar
	Summoned = {
		Name = "Invocado",
		Rarity = "Legendary",
		Color = Color3.fromRGB(255, 130, 40),
		Description = "Llegó de otro mundo con un poder elemental innato. Hay 3 tipos: Fuego, Agua y Planta.",
		Traits = SUMMONED_TRAITS,
		Variants = { "SummonedFire", "SummonedWater", "SummonedPlant" },
	},
	SummonedFire = {
		Name = "Invocado de Fuego",
		Rarity = "Legendary",
		VariantOf = "Summoned",
		Element = "Fire",
		Color = Color3.fromRGB(255, 110, 40),
		CapeColor = Color3.fromRGB(190, 30, 35),
		Description = "Domina el fuego: lanza bolas de fuego que explotan y queman a los enemigos.",
		Traits = summonedTraits("Bola de Fuego (E): explota en área y quema"),
		Abilities = { "Fireball" },
	},
	SummonedWater = {
		Name = "Invocado de Agua",
		Rarity = "Legendary",
		VariantOf = "Summoned",
		Element = "Water",
		Color = Color3.fromRGB(70, 170, 255),
		CapeColor = Color3.fromRGB(30, 80, 190),
		Description = "Domina el agua: lanza torrentes que empujan y ralentizan a los enemigos.",
		Traits = summonedTraits("Torrente de Agua (E): empuja y ralentiza en línea"),
		Abilities = { "WaterTorrent" },
	},
	SummonedPlant = {
		Name = "Invocado de Planta",
		Rarity = "Legendary",
		VariantOf = "Summoned",
		Element = "Plant",
		Color = Color3.fromRGB(90, 200, 80),
		CapeColor = Color3.fromRGB(35, 130, 50),
		Description = "Domina las plantas: atrapa a los enemigos con raíces y roba su vida.",
		Traits = summonedTraits("Raíces Atrapadoras (E): inmoviliza en área y te cura"),
		Abilities = { "PlantRoots" },
	},

	Ogre = {
		Name = "Ogre",
		Rarity = "Epic",
		Color = Color3.fromRGB(190, 110, 90),
		Description = "Un guerrero enorme con el cuerpo fortalecido de forma innata. Al estar herido entra en modo Berserker.",
		Traits = {
			"Fortalecimiento Corporal: +50% vida, +25% fuerza, +15% velocidad, -15% daño físico",
			"Berserker: con menos del 50% de vida, +30% daño y +10% velocidad",
			"Mucho más grande que un humano",
		},
		HealthMult = 1.5,
		DamageMult = 1.25,
		SpeedMult = 1.15,
		PhysicalResist = 0.15,
		BodyScale = 1.8,
		MaxMana = 60,
		Stamina = { Max = 80, Drain = 24, Regen = 16, SpeedMult = 1.35 }, -- pesado: corre menos tiempo
		Berserk = { Threshold = 0.5, DamageMult = 1.3, SpeedMult = 1.1 },
	},
	Elf = {
		Name = "Elf",
		Rarity = "Rare",
		Color = Color3.fromRGB(100, 200, 110),
		Description = "Inteligente y ágil: aprende más rápido y se mueve con rapidez.",
		Traits = { "+15% velocidad", "+25% XP", "+10% daño", "+50% maná" },
		XPMult = 1.25,
		SpeedMult = 1.15,
		DamageMult = 1.1,
		MaxMana = 150,
		Stamina = { Max = 130, Drain = 17, Regen = 20, SpeedMult = 1.55 }, -- ágil: corre más y más rápido
		ElfEars = true,
	},
	MajorElf = {
		Name = "Major Elf",
		Rarity = "Rare",
		SubtypeOf = "Elf", -- subtipo: sale dentro de Elf
		SubtypeChance = 5, -- % de que un Elf salga como Major Elf
		Color = Color3.fromRGB(60, 220, 120),
		Description = "Un elfo noble que domina la magia del viento: lanza cortes de aire y resiste la magia.",
		Traits = {
			"Air Manipulation (E): cortes de viento a distancia",
			"+50% daño mágico",
			"Resiste la magia: -50% daño mágico recibido",
			"+3 de oro por monstruo",
			"+15% velocidad, +25% XP",
		},
		XPMult = 1.25,
		SpeedMult = 1.15,
		DamageMult = 1.1,
		MagicDamageMult = 1.5,
		MagicResist = 0.5,
		GoldMult = 3,
		BodyScale = 1.15,
		MaxMana = 220,
		Stamina = { Max = 140, Drain = 16, Regen = 22, SpeedMult = 1.55 },
		ElfEars = true,
		ElfHat = true,
		Abilities = { "AirSlash" },
	},
	Human = {
		Name = "Human",
		Rarity = "Common",
		Color = Color3.fromRGB(230, 230, 230),
		Description = "Un humano común. Nada especial... por ahora.",
		Traits = { "Sin bonus (velocidad y maná base)" },
	},
}

-- Valores por defecto para lo que una raza no indique
for _, race in Config.Races do
	race.HealthMult = race.HealthMult or 1
	race.DamageMult = race.DamageMult or 1
	race.SpeedMult = race.SpeedMult or 1
	race.XPMult = race.XPMult or 1
	race.RangeBonus = race.RangeBonus or 0
	race.MagicDamageMult = race.MagicDamageMult or 1
	race.MagicResist = race.MagicResist or 0
	race.PhysicalResist = race.PhysicalResist or 0
	race.HealthRegen = race.HealthRegen or 0
	race.GoldMult = race.GoldMult or 1
	race.BodyScale = race.BodyScale or 1
	race.MaxMana = race.MaxMana or 100
	race.ManaRegenOutOfCombat = race.ManaRegenOutOfCombat or 0.03
	race.Abilities = race.Abilities or {}
	-- Stamina base (Human, Invocados): 100 de stamina, corre a x1,45 unos 5 segundos
	race.Stamina = race.Stamina or { Max = 100, Drain = 20, Regen = 18, SpeedMult = 1.45 }
	race.CanAbsorb = race.CanAbsorb == true
end

-- Ajustes comunes de los tipos de Invocado
for _, race in Config.Races do
	if race.VariantOf == "Summoned" then
		race.MaxMana = 500 -- "mucho más que un humano"
		race.ManaRegenOutOfCombat = 0.08
		race.MagicResist = 0.12
		race.DamageMult = 1.1
		race.Overload = true
	end
end

-- Si la raza tiene tipos (Invocado), elige uno al azar. Si no, la deja igual.
function Config.ResolveRace(raceId, rng)
	local race = Config.Races[raceId]
	if race and race.Variants then
		return race.Variants[rng:NextInteger(1, #race.Variants)]
	end
	return raceId
end

-- Devuelve una raza al azar según las probabilidades de su rareza (y sus subtipos/tipos)
function Config.RollRace(rng)
	local roll = rng:NextInteger(1, 1000)
	local total = 0
	local picked = Config.DefaultRace
	for _, raceId in Config.RaceOrder do
		total += Config.Rarities[Config.Races[raceId].Rarity].Weight
		if roll <= total then
			picked = raceId
			break
		end
	end

	for subtypeId, race in Config.Races do
		if race.SubtypeOf == picked and rng:NextNumber(0, 100) < race.SubtypeChance then
			return subtypeId
		end
	end
	return Config.ResolveRace(picked, rng)
end

-- Raza "padre" para mostrar en el menú (Major Elf -> Elf, Invocado de Fuego -> Invocado)
function Config.ParentRace(raceId)
	local race = Config.Races[raceId]
	return race.SubtypeOf or race.VariantOf
end

local function percentText(percent)
	return (string.gsub(string.format("%g%%", percent), "%.", ","))
end

-- Probabilidad total de una raza como texto: "0,1%", "56,9%", "1,5%"...
function Config.ChanceText(raceId)
	local race = Config.Races[raceId]
	local percent = Config.Rarities[race.Rarity].Weight / 10
	if race.SubtypeOf then
		percent = percent * race.SubtypeChance / 100
	elseif race.VariantOf then
		percent = percent / #Config.Races[race.VariantOf].Variants
	else
		-- quitar la parte que se convierte en subtipos
		for _, other in Config.Races do
			if other.SubtypeOf == raceId then
				percent = percent * (1 - other.SubtypeChance / 100)
			end
		end
	end
	return percentText(math.floor(percent * 100 + 0.5) / 100)
end

function Config.SubtypeChanceText(raceId)
	return percentText(Config.Races[raceId].SubtypeChance)
end

--------------------------------------------------------------------------------
-- Habilidades especiales (tecla E). Todas gastan maná.
--------------------------------------------------------------------------------

Config.Abilities = {
	AirSlash = {
		DisplayName = "Air Manipulation",
		Description = "Corte de viento que atraviesa a los enemigos",
		Icon = "🌪️",
		Key = "E",
		Kind = "Line",
		Cooldown = 1.5,
		ManaCost = 15,
		Range = 45,
		Width = 6,
		DamageMult = 1.2,
		Magic = true,
		Color = Color3.fromRGB(150, 245, 190),
	},
	Fireball = {
		DisplayName = "Bola de Fuego",
		Description = "Explota en área y quema a los enemigos",
		Icon = "🔥",
		Key = "E",
		Kind = "Projectile",
		Cooldown = 2,
		ManaCost = 60,
		Range = 60,
		Speed = 90,
		Radius = 10,
		DamageMult = 1.8,
		Magic = true,
		Burn = { Duration = 3, TickDamageMult = 0.12 }, -- daño por tick (cada 0,5 s) respecto al golpe
		Color = Color3.fromRGB(255, 120, 30),
	},
	WaterTorrent = {
		DisplayName = "Torrente de Agua",
		Description = "Chorro que empuja y ralentiza",
		Icon = "🌊",
		Key = "E",
		Kind = "Line",
		Cooldown = 2,
		ManaCost = 50,
		Range = 40,
		Width = 8,
		DamageMult = 1.5,
		Magic = true,
		Knockback = 55,
		Slow = { Mult = 0.5, Duration = 3 },
		Color = Color3.fromRGB(80, 170, 255),
	},
	PlantRoots = {
		DisplayName = "Raíces Atrapadoras",
		Description = "Inmoviliza en área y te cura",
		Icon = "🌿",
		Key = "E",
		Kind = "Area",
		Cooldown = 2.5,
		ManaCost = 55,
		Distance = 16, -- el centro del área está delante de ti
		Radius = 12,
		DamageMult = 1.4,
		Magic = true,
		RootDuration = 2.5,
		Lifesteal = 0.3, -- te cura el 30% del daño hecho
		Color = Color3.fromRGB(90, 200, 70),
	},
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

--------------------------------------------------------------------------------
-- Monstruos
--------------------------------------------------------------------------------

-- Valores a nivel 1. Cada nivel los hace más fuertes (ver Config.MonsterStats).
-- Gold = oro base por derrotarlo (+1); el Major Elf gana x3.
Config.Monsters = {
	Bat = {
		DisplayName = "Murciélago de cueva",
		Health = 25,
		Damage = 5,
		Magic = true, -- su chillido es daño mágico (lo reducen las resistencias mágicas)
		XP = 15,
		Gold = 1,
		Skill = "HighJump",
		Color = Color3.fromRGB(80, 60, 110),
		EyeColor = Color3.fromRGB(255, 60, 90),
		Size = Vector3.new(1.8, 1.6, 1.8), -- cuerpo
		HipHeight = 3.2, -- vuela
		AggroRange = 35,
	},
	Wolf = {
		DisplayName = "Lobo del bosque",
		Health = 45,
		Damage = 8,
		XP = 25,
		Gold = 1,
		Skill = "Dash",
		Color = Color3.fromRGB(125, 115, 105),
		EyeColor = Color3.fromRGB(255, 210, 60),
		Size = Vector3.new(2.4, 2.2, 4.4),
		HipHeight = 1.4,
		AggroRange = 40,
	},
	Golem = {
		DisplayName = "Gólem de roca",
		Health = 160,
		Damage = 18,
		XP = 90,
		Gold = 1,
		Skill = "StoneSkin",
		Color = Color3.fromRGB(135, 130, 120),
		EyeColor = Color3.fromRGB(255, 150, 40),
		Size = Vector3.new(4.4, 4.4, 3.4),
		HipHeight = 2.6,
		AggroRange = 30,
	},
}

-- Zonas donde aparecen monstruos. El spawn está en (0, 0, 0); las zonas van al norte (-Z).
Config.Zones = {
	{
		Name = "Pradera Susurrante",
		Label = "Pradera Susurrante\nNivel 1-4",
		Center = Vector3.new(0, 0, -140),
		Radius = 70,
		Levels = { 1, 4 },
		Monsters = { "Bat", "Bat", "Wolf" },
		MaxMonsters = 10,
	},
	{
		Name = "Colinas de Piedra",
		Label = "Colinas de Piedra\nNivel 5-9",
		Center = Vector3.new(0, 0, -340),
		Radius = 80,
		Levels = { 5, 9 },
		Monsters = { "Wolf", "Golem", "Golem" },
		MaxMonsters = 6,
	},
}

-- Estadísticas de un monstruo según su nivel
function Config.MonsterStats(monsterId, level)
	local def = Config.Monsters[monsterId]
	local steps = level - 1
	return {
		Health = math.floor(def.Health * (1 + 0.3 * steps)),
		Damage = math.floor(def.Damage * (1 + 0.15 * steps) + 0.5),
		XP = math.floor(def.XP * (1 + 0.25 * steps)),
		Scale = 1 + 0.04 * steps, -- un poco más grandes
	}
end

-- Probabilidad (0-1) de que un Slime absorba a un monstruo.
-- Empieza en ~42% a nivel 1 y llega al 100% cuando superas bastante al monstruo.
function Config.AbsorbChance(playerLevel, monsterLevel)
	local chance = 0.4 + (playerLevel - monsterLevel) * 0.1 + playerLevel * 0.02
	return math.clamp(chance, 0.05, 1)
end

--------------------------------------------------------------------------------
-- Fórmulas de jugador
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
	return { Name = race.Name, Size = 3 * race.BodyScale, Color = race.Color, DamageBonus = 0 }
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

function Config.MaxMana(level, raceId)
	return math.floor(Config.Races[raceId].MaxMana * (1 + 0.05 * (level - 1)))
end

function Config.AttackDamage(level, raceId)
	local race = Config.Races[raceId]
	local base = 10 + (level - 1) * 4 + Config.GetBody(raceId, level).DamageBonus
	return math.floor(base * race.DamageMult)
end

function Config.AbilityDamage(level, raceId, abilityId)
	local race = Config.Races[raceId]
	local ability = Config.Abilities[abilityId]
	local damage = Config.AttackDamage(level, raceId) * ability.DamageMult
	if ability.Magic then
		damage *= race.MagicDamageMult
	end
	return math.floor(damage)
end

function Config.AttackRange(level, raceId)
	local race = Config.Races[raceId]
	return Config.Attack.Range + Config.GetBody(raceId, level).Size / 2 + race.RangeBonus
end

function Config.WalkSpeed(raceId)
	return Config.BaseSpeed * Config.Races[raceId].SpeedMult
end

-- Oro por derrotar un monstruo: +1 normal; el Major Elf gana x3 (+3)
function Config.GoldForKill(raceId, monsterId)
	return Config.Monsters[monsterId].Gold * Config.Races[raceId].GoldMult
end

function Config.HasAbility(raceId, abilityId)
	return table.find(Config.Races[raceId].Abilities, abilityId) ~= nil
end

--------------------------------------------------------------------------------
-- Misiones (NPC en la zona segura)
--------------------------------------------------------------------------------

Config.QuestGiver = {
	Name = "Maestro Bram",
	Position = Vector3.new(-16, 0, -14), -- dentro de la zona segura
	TalkDistance = 14,
}

-- Cada misión se desbloquea a un nivel. Se pueden repetir.
-- Recompensa = Base + un extra por cada monstruo según su nivel (más nivel, más premio).
Config.Quests = {
	{
		Id = "Bats",
		Title = "Plaga de murciélagos",
		Description = "Los murciélagos de la pradera asustan a los viajeros. ¡Derrota a 5!",
		Monster = "Bat",
		Count = 5,
		MinLevel = 1,
		BaseXP = 60,
		BaseGold = 10,
	},
	{
		Id = "Wolves",
		Title = "Lobos hambrientos",
		Description = "Una manada de lobos ataca a los animales del pueblo. Derrota a 5 lobos.",
		Monster = "Wolf",
		Count = 5,
		MinLevel = 5,
		BaseXP = 250,
		BaseGold = 35,
	},
	{
		Id = "Golems",
		Title = "Gigantes de piedra",
		Description = "Los gólems bloquean el camino de las colinas. Derrota a 5 gólems.",
		Monster = "Golem",
		Count = 5,
		MinLevel = 10,
		BaseXP = 800,
		BaseGold = 90,
	},
	{
		Id = "GolemHunt",
		Title = "Cazador de gólems",
		Description = "Solo un verdadero héroe puede limpiar las colinas. Derrota a 10 gólems.",
		Monster = "Golem",
		Count = 10,
		MinLevel = 15,
		BaseXP = 2000,
		BaseGold = 220,
	},
}

-- Extra de recompensa por cada monstruo de la misión
Config.QuestKillBonus = {
	XPMult = 0.5, -- 50% de la XP del monstruo (según su nivel)
	GoldPerLevel = 1, -- +1 de oro por cada nivel del monstruo
}

function Config.GetQuest(questId)
	for _, quest in Config.Quests do
		if quest.Id == questId then
			return quest
		end
	end
	return nil
end

return Config
