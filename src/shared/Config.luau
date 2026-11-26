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

Config.BaseSpeed = 12 -- velocidad andando del Human y de los monstruos (correr es bastante más rápido)

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

-- Bloquear (mantener F; el Slime usa F para absorber y no puede bloquear).
-- Mientras bloqueas no recibes daño: el golpe gasta tu barra de bloqueo.
Config.Guard = {
	Max = 100, -- barra de bloqueo sin arma
	SwordBonus = 50, -- con espada la barra es más grande
	RegenPerSecond = 20,
	RegenDelay = 1.5, -- segundos sin bloquear antes de que se recupere
	BreakStun = 1.5, -- si se rompe la barra, te quedas aturdido (lento) este tiempo
	RecoverFraction = 0.4, -- tras romperse, no puedes bloquear hasta recuperar este %
	SpeedMult = 0.5, -- vas más lento mientras bloqueas
}

-- Zona segura alrededor del spawn: los monstruos no entran ni atacan dentro, y te curas.
Config.SafeZone = {
	Center = Vector3.new(0, 0, 0),
	Radius = 62, -- todo el pueblo
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
		Stamina = { Max = 110, Drain = 18, Regen = 20, SpeedMult = 1.65 },
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
		Stamina = { Max = 80, Drain = 24, Regen = 16, SpeedMult = 1.5 }, -- pesado: corre menos tiempo
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
		Stamina = { Max = 130, Drain = 17, Regen = 20, SpeedMult = 1.75 }, -- ágil: corre más y más rápido
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
		Stamina = { Max = 140, Drain = 16, Regen = 22, SpeedMult = 1.75 },
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
	race.Stamina = race.Stamina or { Max = 100, Drain = 20, Regen = 18, SpeedMult = 1.65 }
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

	-- Habilidades que el Slime roba (ver Config.Skills)
	SonicScreech = {
		DisplayName = "Chillido Sónico",
		Description = "Onda que daña y aturde a tu alrededor",
		Icon = "🔊",
		Key = "E",
		Kind = "Area",
		Cooldown = 4,
		ManaCost = 25,
		Radius = 14,
		DamageMult = 1.4,
		Magic = true,
		StunDuration = 1.5,
		Color = Color3.fromRGB(200, 150, 255),
	},
	RockFist = {
		DisplayName = "Puño de roca",
		Description = "Golpe al suelo que daña y empuja en área",
		Icon = "👊",
		Key = "R",
		Kind = "Area",
		Cooldown = 5,
		ManaCost = 30,
		Distance = 6,
		Radius = 11,
		DamageMult = 2.4,
		Scaling = "Strength", -- escala con Fuerza, no con Magia
		Magic = false,
		Knockback = 45,
		Color = Color3.fromRGB(170, 140, 110),
	},
}

Config.EssenceLifetime = 20 -- segundos antes de que una esencia desaparezca

-- Formas del Slime. Evoluciona automáticamente al llegar a MinLevel.
-- Mantenlas ordenadas de menor a mayor nivel.
Config.Forms = {
	{
		Name = "Slime pequeño",
		MinLevel = 1,
		Size = 3,
		Color = Color3.fromRGB(45, 125, 250), -- interior azul intenso (el contorno es azul clarito)
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

-- Habilidades que el Slime roba al absorber monstruos.
-- From = de qué monstruo, Required = cuántos de ese tipo hay que absorber.
-- Ability = si es una habilidad activa (está en Config.Abilities y se usa con su tecla).
Config.Skills = {
	-- Murciélago
	HighJump = {
		DisplayName = "Alas de murciélago",
		Description = "Pasiva: saltas mucho más alto",
		From = "Bat",
		Required = 1,
		AcquireChance = 0.5, -- probabilidad base de conseguirla al absorber
		JumpPower = 85,
	},
	SonicScreech = {
		DisplayName = "Chillido Sónico",
		Description = "Onda que daña y aturde a tu alrededor (E)",
		From = "Bat",
		Required = 5,
		AcquireChance = 0.35, -- probabilidad base de conseguirla al absorber
		Ability = "SonicScreech",
	},
	-- Lobo
	Dash = {
		DisplayName = "Embestida de lobo",
		Description = "Embiste hacia delante (Q)",
		From = "Wolf",
		Required = 1,
		AcquireChance = 0.5, -- probabilidad base de conseguirla al absorber
		Cooldown = 2,
		Speed = 90,
		Duration = 0.25,
	},
	WolfFang = {
		DisplayName = "Colmillo de lobo",
		Description = "Pasiva: +15% daño de tus golpes",
		From = "Wolf",
		Required = 5,
		AcquireChance = 0.35, -- probabilidad base de conseguirla al absorber
		DamageBonus = 0.15,
	},
	-- Gólem
	StoneSkin = {
		DisplayName = "Piel de piedra",
		Description = "Pasiva: +50 de vida máxima",
		From = "Golem",
		Required = 1,
		AcquireChance = 0.4, -- probabilidad base de conseguirla al absorber
		BonusHealth = 50,
	},
	RockFist = {
		DisplayName = "Puño de roca",
		Description = "Golpe al suelo que hace mucho daño en área (R)",
		From = "Golem",
		Required = 5,
		AcquireChance = 0.3, -- probabilidad base de conseguirla al absorber
		Ability = "RockFist",
	},
}

-- Orden en que se muestran las habilidades del Slime
Config.SkillOrder = { "HighJump", "SonicScreech", "Dash", "WolfFang", "StoneSkin", "RockFist" }

-- Niveles de la habilidad de absorber del Slime. Mejora sola al llegar a MinLevel.
-- (Puedes cambiar los nombres aquí si quieres.)
Config.AbsorbTiers = {
	{
		Name = "Absorber",
		MinLevel = 1,
		Description = "Absorbe esencias de monstruos derrotados.",
		ChanceBonus = 0,
		Range = 12,
		StatMult = 1, -- multiplica los atributos que ganas al absorber
		XPMult = 1,
		HealOnAbsorb = 0,
		SkillBonus = 0, -- extra de probabilidad de conseguir habilidades
		ManaOnAbsorb = 0,
		AreaAbsorb = false,
	},
	{
		Name = "Devorador",
		MinLevel = 15,
		Description = "+20% probabilidad, más alcance, x1,5 atributos y te cura al absorber.",
		ChanceBonus = 0.2,
		Range = 18,
		StatMult = 1.5,
		XPMult = 1.25,
		HealOnAbsorb = 0.1,
		SkillBonus = 0.15,
		ManaOnAbsorb = 0.1,
		AreaAbsorb = false,
	},
	{
		Name = "Vacío Insaciable",
		Unique = true, -- Habilidad Única
		MinLevel = 40,
		Description = "Habilidad Única: absorbe todas las esencias cercanas a la vez, siempre con éxito. x2 atributos, cura y maná.",
		ChanceBonus = 1,
		Range = 26,
		StatMult = 2,
		XPMult = 1.5,
		HealOnAbsorb = 0.2,
		SkillBonus = 0.4,
		ManaOnAbsorb = 0.2,
		AreaAbsorb = true,
	},
}

function Config.GetAbsorbTier(level)
	local current = Config.AbsorbTiers[1]
	for _, tier in Config.AbsorbTiers do
		if level >= tier.MinLevel then
			current = tier
		end
	end
	return current
end

-- Secuencia de absorción (segundos). Éxito: acercarse -> envolver -> cerrar -> digerir.
-- Fallo: acercarse -> forcejear -> rebotar hacia atrás.
Config.AbsorbSequence = {
	Approach = 0.5, -- el slime se acerca y se prepara (se ensancha y brilla un poco)
	Engulf = 0.8, -- el cuerpo se estira y envuelve la esencia
	Close = 0.4, -- se cierra a su alrededor y la lleva al centro
	Digest = 0.35, -- vuelve a su forma y la esencia se disuelve dentro
	Struggle = 0.7, -- (fallo) intenta envolverla pero la esencia se resiste
	Recoil = 0.55, -- (fallo) rebota hacia atrás, gracioso
	ApproachDistance = 0.9, -- distancia entre la superficie del slime y la esencia al empezar a envolver
}

function Config.AbsorbDuration(success)
	local s = Config.AbsorbSequence
	return if success then s.Approach + s.Engulf + s.Close + s.Digest else s.Approach + s.Struggle + s.Recoil
end

-- Conseguir la habilidad de un monstruo al absorberlo NO es automático:
--   probabilidad = base de la habilidad + 5% por cada nivel que superas al monstruo
--                  + bonus del nivel de absorción (Devorador / Habilidad Única)
--                  + 10% por cada intento fallido anterior (así no hay rachas eternas de mala suerte)
Config.SkillAcquire = {
	LevelBonus = 0.05,
	PityBonus = 0.1,
	Min = 0.05,
	Max = 1,
}

function Config.SkillAcquireChance(skillId, playerLevel, monsterLevel, failedTries)
	local skill = Config.Skills[skillId]
	local rules = Config.SkillAcquire
	local chance = (skill.AcquireChance or 0.4)
		+ (playerLevel - monsterLevel) * rules.LevelBonus
		+ Config.GetAbsorbTier(playerLevel).SkillBonus
		+ (failedTries or 0) * rules.PityBonus
	return math.clamp(chance, rules.Min, rules.Max)
end

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
		AbsorbStats = { Agility = 0.5, Spirit = 0.5 }, -- atributos que gana el Slime por cada uno absorbido
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
		AbsorbStats = { Strength = 0.5, Agility = 0.5 },
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
		AbsorbStats = { Defense = 1, Vitality = 0.5 },
		Color = Color3.fromRGB(135, 130, 120),
		EyeColor = Color3.fromRGB(255, 150, 40),
		Size = Vector3.new(4.4, 4.4, 3.4),
		HipHeight = 2.6,
		AggroRange = 30,
	},

	-- Goblin de nivel 1: pequeño, débil e inexperto, con un garrote de madera.
	-- Usa un rig R15 completo (mismas articulaciones que los jugadores) para tener
	-- animaciones de fotogramas clave: ver client/AnimationData.luau (Monster.Goblin).
	-- Para futuros goblins (guerrero, chamán, líder...) se añade otra entrada con la misma
	-- Species y su propio Builder/aspecto, sin tocar el resto del sistema.
	Goblin = {
		DisplayName = "Goblin",
		Species = "Goblin",
		-- Modelo 3D hecho en Blender (art/goblin). Si no está importado en
		-- ServerStorage.MonsterModels, se usa el diseño de piezas de antes.
		Builder = "Mesh",
		MeshModel = "GoblinTier1",
		AnimSet = "GoblinMesh", -- animaciones (AnimationData.Monster)
		FallbackBuilder = "GoblinTier1", -- diseño de piezas (Monsters.luau)
		FallbackAnimSet = "Goblin",
		Rig = "R15",
		Health = 30,
		Damage = 4,
		XP = 15,
		Gold = 1,
		AbsorbStats = { Strength = 0.5, Agility = 0.5 },
		Color = Color3.fromRGB(110, 150, 70), -- piel
		EyeColor = Color3.fromRGB(30, 30, 25),
		Size = Vector3.new(1, 1.2, 0.6), -- HumanoidRootPart (invisible)
		HipHeight = 0.81,
		AggroRange = 28, -- radio de detección
		LeashRange = 40, -- si se aleja más de esto de su sitio, deja de perseguir y vuelve
		WalkSpeed = 7, -- paseando
		ChaseSpeed = 11, -- persiguiendo (más lento que un jugador andando: se le puede escapar)
		ReturnSpeed = 15, -- volviendo a su sitio
		AttackReach = 3.6, -- distancia para golpear (desde su centro)
		AttackCooldown = 1.7, -- torpe: tarda en volver a atacar
		AttackWindup = 0.45, -- el golpe llega al bajar el garrote (no al empezar la animación)
		WanderRadius = 12, -- pasea cerca de donde apareció
		CorpseTime = 2.6, -- segundos que se queda el cuerpo para la animación de muerte
		RespawnTime = 12, -- segundos desde que muere hasta que vuelve a aparecer en su sitio
	},
}

-- Valores por defecto del comportamiento de los monstruos (cada monstruo puede cambiarlos
-- en su entrada de Config.Monsters). Así un monstruo nuevo solo necesita sus datos.
Config.MonsterDefaults = {
	AggroRange = 30, -- radio de detección
	LeashRange = 45, -- distancia máxima a su sitio antes de rendirse y volver
	LoseInterestRange = 1.6, -- deja de perseguir si te alejas AggroRange × esto
	WalkSpeed = 12,
	ChaseSpeed = 12,
	ReturnSpeed = 16,
	AttackCooldown = 1.2,
	AttackWindup = 0, -- 0 = el daño llega al empezar el ataque
	WanderRadius = 15,
	CorpseTime = 1,
	RespawnTime = 10,
}

-- Un valor del monstruo, o el de por defecto si no lo tiene
function Config.MonsterSetting(def, key)
	local value = def[key]
	if value == nil then
		return Config.MonsterDefaults[key]
	end
	return value
end

-- Distancia a la que un monstruo puede golpear (desde su centro)
function Config.MonsterReach(def, size)
	return def.AttackReach or (math.max(size.X, size.Z) / 2 + 3.5 + def.HipHeight)
end

-- Zonas donde aparecen monstruos. El spawn está en (0, 0, 0); las zonas van al norte (-Z).
-- Spawns: tabla de aparición { Monster, Weight (probabilidad relativa), Levels = { min, max } }.
-- Para sacar o volver a meter un monstruo basta con tocar esta tabla.
-- (Murciélagos y lobos están retirados temporalmente: sus datos y diseños se conservan.)
Config.Zones = {
	{
		Name = "Pradera Susurrante",
		Label = "Whispering Meadow\nLv. 1",
		Center = Vector3.new(0, 0, -140),
		Radius = 70,
		Spawns = {
			{ Monster = "Goblin", Weight = 1, Levels = { 1, 1 } },
			-- { Monster = "Bat", Weight = 2, Levels = { 1, 4 } },
			-- { Monster = "Wolf", Weight = 1, Levels = { 1, 4 } },
		},
		MaxMonsters = 8,
	},
	{
		Name = "Colinas de Piedra",
		Label = "Stone Hills\nLv. 5-9",
		Center = Vector3.new(0, 0, -340),
		Radius = 80,
		Spawns = {
			{ Monster = "Golem", Weight = 1, Levels = { 5, 9 } },
			-- { Monster = "Wolf", Weight = 1, Levels = { 5, 9 } },
		},
		MaxMonsters = 6,
	},
}

-- ¿Aparece este monstruo en alguna zona ahora mismo?
function Config.IsMonsterActive(monsterId)
	for _, zone in Config.Zones do
		for _, spawn in zone.Spawns do
			if spawn.Monster == monsterId then
				return true
			end
		end
	end
	return false
end

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
-- Devorador suma +20% y la Habilidad Única siempre acierta.
function Config.AbsorbChance(playerLevel, monsterLevel)
	local chance = 0.4 + (playerLevel - monsterLevel) * 0.1 + playerLevel * 0.02
	chance += Config.GetAbsorbTier(playerLevel).ChanceBonus
	return math.clamp(chance, 0.05, 1)
end

--------------------------------------------------------------------------------
-- Atributos (sistema híbrido)
-- 1) Cada raza sube sola sus atributos al subir de nivel (Growth).
-- 2) Cada nivel da puntos libres para repartir donde quieras.
-- 3) Saltos de poder: el Slime gana atributos al absorber, y todos tienen Despertares.
--------------------------------------------------------------------------------

Config.Stats = {
	{ Id = "Strength", Name = "Fuerza", Icon = "💪", Description = "Daño de tus golpes y del Puño de roca" },
	{ Id = "Vitality", Name = "Vitalidad", Icon = "❤️", Description = "Vida máxima" },
	{ Id = "Defense", Name = "Defensa", Icon = "🛡️", Description = "Reduce el daño físico recibido" },
	{ Id = "Agility", Name = "Agilidad", Icon = "💨", Description = "Velocidad y stamina" },
	{ Id = "Magic", Name = "Magia", Icon = "🔮", Description = "Daño de habilidades mágicas y maná máximo" },
	{ Id = "Spirit", Name = "Espíritu", Icon = "✨", Description = "Resistencia mágica y regeneración de maná" },
}

Config.BaseStat = 5 -- todos los atributos empiezan en 5 a nivel 1
Config.PointsPerLevel = 2 -- puntos libres por cada nivel
Config.AbsorbStatCap = 40 -- el Slime gana atributos de los primeros 40 de cada tipo absorbidos

-- Crecimiento automático por nivel de cada raza
local RACE_GROWTH = {
	Ogre = { Strength = 3, Vitality = 3, Defense = 2, Agility = 1, Magic = 0, Spirit = 1 },
	Elf = { Strength = 1, Vitality = 1, Defense = 1, Agility = 3, Magic = 2, Spirit = 2 },
	MajorElf = { Strength = 1, Vitality = 1, Defense = 1, Agility = 3, Magic = 3, Spirit = 2 },
	Summoned = { Strength = 1, Vitality = 1, Defense = 1, Agility = 1, Magic = 4, Spirit = 2 },
	-- El Slime crece poco por nivel: su fuerza viene de lo que absorbe
	Slime = { Strength = 1, Vitality = 2, Defense = 2, Agility = 1, Magic = 2, Spirit = 2 },
	Human = { Strength = 2, Vitality = 2, Defense = 2, Agility = 2, Magic = 1, Spirit = 1 },
}
for raceId, race in Config.Races do
	race.Growth = RACE_GROWTH[raceId] or RACE_GROWTH[race.VariantOf or ""] or RACE_GROWTH.Human
end

-- Despertares: a ciertos niveles todos tus atributos suben un % (se queda el más alto)
Config.Awakenings = {
	{ Level = 20, Name = "Despertar I", Bonus = 0.1 },
	{ Level = 50, Name = "Despertar II", Bonus = 0.2 },
	{ Level = 100, Name = "Despertar III", Bonus = 0.35 },
}

function Config.GetAwakening(level)
	local current = nil
	for _, awakening in Config.Awakenings do
		if level >= awakening.Level then
			current = awakening
		end
	end
	return current
end

function Config.TotalStatPoints(level)
	return (level - 1) * Config.PointsPerLevel
end

-- Calcula los atributos finales de un slot
function Config.ComputeStats(level, raceId, allocated, absorbed)
	local race = Config.Races[raceId]
	local awakening = Config.GetAwakening(level)
	local tier = Config.GetAbsorbTier(level)
	local stats = {}
	for _, stat in Config.Stats do
		local id = stat.Id
		local value = Config.BaseStat + race.Growth[id] * (level - 1) + (allocated[id] or 0)
		if race.CanAbsorb then
			for monsterId, count in absorbed do
				local def = Config.Monsters[monsterId]
				local bonus = def and def.AbsorbStats and def.AbsorbStats[id]
				if bonus then
					value += bonus * math.min(count, Config.AbsorbStatCap) * tier.StatMult
				end
			end
		end
		if awakening then
			value *= 1 + awakening.Bonus
		end
		stats[id] = math.floor(value)
	end
	return stats
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

-- Vitalidad 5 = 100 de vida; cada punto +8
function Config.MaxHealth(stats, raceId, skills)
	local race = Config.Races[raceId]
	local health = (60 + stats.Vitality * 8) * race.HealthMult
	if race.CanAbsorb and skills.StoneSkin then
		health += Config.Skills.StoneSkin.BonusHealth
	end
	return math.floor(health)
end

-- Cada punto de Magia por encima de 5: +2% de maná
function Config.MaxMana(stats, raceId)
	return math.floor(Config.Races[raceId].MaxMana * (1 + (stats.Magic - Config.BaseStat) * 0.02))
end

-- Cada punto de Agilidad por encima de 5: +1 de stamina
function Config.MaxStamina(stats, raceId)
	return math.floor(Config.Races[raceId].Stamina.Max + (stats.Agility - Config.BaseStat))
end

-- Fuerza 5 = 10 de daño; cada punto +2
function Config.AttackDamage(stats, raceId, level, skills, weaponId)
	local race = Config.Races[raceId]
	local weapon = weaponId and not race.CanAbsorb and Config.Weapons[weaponId]
	local weaponDamage = if weapon then weapon.Damage else 0
	local damage = (stats.Strength * 2 + Config.GetBody(raceId, level).DamageBonus + weaponDamage) * race.DamageMult
	if race.CanAbsorb and skills and skills.WolfFang then
		damage *= 1 + Config.Skills.WolfFang.DamageBonus
	end
	return math.floor(damage)
end

-- Las habilidades escalan con Magia (o con Fuerza si su Scaling es "Strength")
function Config.AbilityDamage(stats, raceId, abilityId)
	local race = Config.Races[raceId]
	local ability = Config.Abilities[abilityId]
	local damage = stats[ability.Scaling or "Magic"] * 2 * ability.DamageMult
	if ability.Magic then
		damage *= race.MagicDamageMult
	end
	return math.floor(damage)
end

function Config.AttackRange(level, raceId)
	local race = Config.Races[raceId]
	return Config.Attack.Range + Config.GetBody(raceId, level).Size / 2 + race.RangeBonus
end

-- Agilidad: +0,3% de velocidad por punto (máximo +30%)
function Config.WalkSpeed(stats, raceId)
	local bonus = math.min(0.3, (stats.Agility - Config.BaseStat) * 0.003)
	return Config.BaseSpeed * Config.Races[raceId].SpeedMult * (1 + bonus)
end

-- Defensa / Espíritu: +0,4% de resistencia por punto (máximo +40%, total máximo 75%)
function Config.PhysicalResist(stats, raceId)
	local bonus = math.min(0.4, (stats.Defense - Config.BaseStat) * 0.004)
	return math.min(0.75, Config.Races[raceId].PhysicalResist + bonus)
end

function Config.MagicResist(stats, raceId)
	local bonus = math.min(0.4, (stats.Spirit - Config.BaseStat) * 0.004)
	return math.min(0.75, Config.Races[raceId].MagicResist + bonus)
end

-- Espíritu: +1% de regeneración de maná por punto
function Config.ManaRegenMult(stats)
	return 1 + (stats.Spirit - Config.BaseStat) * 0.01
end

-- Oro por derrotar un monstruo: +1 normal; el Major Elf gana x3 (+3)
function Config.GoldForKill(raceId, monsterId)
	return Config.Monsters[monsterId].Gold * Config.Races[raceId].GoldMult
end

function Config.HasAbility(raceId, abilityId)
	return table.find(Config.Races[raceId].Abilities, abilityId) ~= nil
end

-- ¿Puede usar esta habilidad? (la de su raza, o una robada por el Slime)
function Config.CanUseAbility(raceId, skills, abilityId)
	if Config.HasAbility(raceId, abilityId) then
		return true
	end
	if Config.Races[raceId].CanAbsorb then
		for skillId, skill in Config.Skills do
			if skill.Ability == abilityId and skills[skillId] then
				return true
			end
		end
	end
	return false
end

-- Texto "Strength=10,Vitality=12,..." para mandar los atributos al cliente
function Config.EncodeStats(stats)
	local parts = {}
	for _, stat in Config.Stats do
		table.insert(parts, stat.Id .. "=" .. (stats[stat.Id] or 0))
	end
	return table.concat(parts, ",")
end

function Config.DecodeStats(text)
	local stats = {}
	for _, stat in Config.Stats do
		stats[stat.Id] = Config.BaseStat
	end
	for id, value in string.gmatch(text or "", "(%w+)=(%d+)") do
		stats[id] = tonumber(value)
	end
	return stats
end

--------------------------------------------------------------------------------
-- Misiones (NPC en la zona segura)
--------------------------------------------------------------------------------

Config.QuestGiver = {
	Name = "Elder Bram",
	Position = Vector3.new(12, 0, -16), -- en la plaza, junto a la fuente
	TalkDistance = 14,
}

-- Cada misión se desbloquea a un nivel. Se pueden repetir.
-- Recompensa = Base + un extra por cada monstruo según su nivel (más nivel, más premio).
Config.Quests = {
	{
		Id = "Goblins",
		Title = "Goblins traviesos",
		Description = "Unos goblins rondan la pradera y roban comida del pueblo. ¡Derrota a 5!",
		Monster = "Goblin",
		Count = 5,
		MinLevel = 1,
		BaseXP = 60,
		BaseGold = 10,
	},
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

-- Las misiones de monstruos que ahora no aparecen (murciélagos, lobos) se ocultan
-- en el NPC sin borrarlas, para poder recuperarlas cuando vuelvan esos monstruos
function Config.IsQuestAvailable(quest)
	return Config.IsMonsterActive(quest.Monster)
end

--------------------------------------------------------------------------------
-- Objetos (tienda e inventario)
--------------------------------------------------------------------------------

-- Effect: Heal / Mana / Stamina (fracción del máximo) o Spin (+1 spin al slot)
Config.Items = {
	HealthPotion = {
		Name = "Poción",
		Icon = "❤️",
		Description = "Recupera el 30% de tu vida.",
		Price = 20,
		Effect = "Heal",
		Amount = 0.3,
		Color = Color3.fromRGB(230, 70, 80),
	},
	FullPotion = {
		Name = "Poción completa",
		Icon = "💖",
		Description = "Recupera TODA tu vida.",
		Price = 100,
		Effect = "Heal",
		Amount = 1,
		Color = Color3.fromRGB(255, 110, 180),
	},
	ManaPotion = {
		Name = "Poción de maná",
		Icon = "💧",
		Description = "Recupera el 50% de tu maná.",
		Price = 25,
		Effect = "Mana",
		Amount = 0.5,
		Color = Color3.fromRGB(90, 120, 255),
	},
	StaminaPotion = {
		Name = "Poción de stamina",
		Icon = "⚡",
		Description = "Recupera toda tu stamina.",
		Price = 15,
		Effect = "Stamina",
		Amount = 1,
		Color = Color3.fromRGB(230, 200, 60),
	},
	SpinToken = {
		Name = "Ficha de Spin",
		Icon = "🎰",
		Description = "Da +1 Spin a este slot para volver a tirar tu raza en el menú.",
		Price = 150,
		Effect = "Spin",
		Amount = 1,
		Color = Color3.fromRGB(180, 100, 255),
	},
}

Config.Items.StatReset = {
	Name = "Elixir del olvido",
	Icon = "🧪",
	Description = "Devuelve todos tus puntos de atributo para repartirlos de nuevo.",
	Price = 300,
	Effect = "StatReset",
	Amount = 1,
	Color = Color3.fromRGB(240, 220, 160),
}

Config.ItemOrder = { "HealthPotion", "FullPotion", "ManaPotion", "StaminaPotion", "StatReset", "SpinToken" }
Config.PotionCooldown = 3 -- segundos entre pociones
Config.MaxItemStack = 99

--------------------------------------------------------------------------------
-- Armas (Herrería). El Slime todavía no puede usarlas: no tiene forma humana.
--------------------------------------------------------------------------------

-- Damage = daño extra por golpe. AttackSpeed = golpes más rápidos (0,2 = +20%).
-- Look = diseño de la espada (cuanto más cara, más detalles).
Config.Weapons = {
	IronSword = {
		Name = "Espada de hierro",
		Rarity = "Common",
		Price = 80,
		Damage = 4,
		AttackSpeed = 0,
		Description = "Sencilla pero fiable.",
		Look = {
			Blade = Color3.fromRGB(185, 190, 195),
			Guard = Color3.fromRGB(110, 90, 70),
			Handle = Color3.fromRGB(80, 55, 35),
			Length = 3.2,
		},
	},
	SteelSword = {
		Name = "Espada de acero",
		Rarity = "Rare",
		Price = 250,
		Damage = 8,
		AttackSpeed = 0.1,
		Description = "Acero templado: más daño y golpes más rápidos.",
		Look = {
			Blade = Color3.fromRGB(215, 225, 235),
			Guard = Color3.fromRGB(70, 120, 200),
			Handle = Color3.fromRGB(40, 40, 60),
			Gem = Color3.fromRGB(80, 160, 255),
			Length = 3.6,
		},
	},
	WindBlade = {
		Name = "Hoja del viento",
		Rarity = "Epic",
		Price = 700,
		Damage = 14,
		AttackSpeed = 0.2,
		Passive = "DoubleHit",
		PassiveText = "15% de probabilidad de dar un segundo golpe",
		Description = "Forjada con piedras de viento. Muy ligera.",
		Look = {
			Blade = Color3.fromRGB(170, 255, 210),
			Guard = Color3.fromRGB(60, 200, 140),
			Handle = Color3.fromRGB(30, 70, 60),
			Gem = Color3.fromRGB(120, 255, 190),
			Length = 3.9,
			Glow = true,
			Wings = true,
		},
	},
	FlameSword = {
		Name = "Espada de llamas",
		Rarity = "Legendary",
		Price = 1800,
		Damage = 22,
		AttackSpeed = 0.15,
		Passive = "Burn",
		PassiveText = "Tus golpes queman durante 3 s",
		Description = "Su hoja arde sin consumirse nunca.",
		Look = {
			Blade = Color3.fromRGB(255, 120, 40),
			Guard = Color3.fromRGB(60, 30, 30),
			Handle = Color3.fromRGB(40, 20, 20),
			Gem = Color3.fromRGB(255, 200, 60),
			Length = 4.2,
			Glow = true,
			Fire = true,
			Wings = true,
		},
	},
	StarBlade = {
		Name = "Hoja estelar",
		Rarity = "Mythic",
		Price = 5000,
		Damage = 35,
		AttackSpeed = 0.25,
		Passive = "StarWave",
		PassiveText = "Cada 4º golpe lanza una onda de energía",
		Description = "Dicen que cayó del cielo una noche de tormenta.",
		Look = {
			Blade = Color3.fromRGB(215, 195, 255),
			Guard = Color3.fromRGB(255, 210, 90),
			Handle = Color3.fromRGB(50, 30, 90),
			Gem = Color3.fromRGB(255, 80, 200),
			Length = 4.6,
			Glow = true,
			Sparkles = true,
			Wings = true,
		},
	},
}
Config.WeaponOrder = { "IronSword", "SteelSword", "WindBlade", "FlameSword", "StarBlade" }

-- Pasivas de las armas
Config.WeaponPassives = {
	DoubleHit = { Chance = 0.15 },
	Burn = { Duration = 3, TickDamageMult = 0.1 },
	StarWave = { EveryHits = 4, Range = 28, Width = 5, DamageMult = 0.8, Color = Color3.fromRGB(220, 170, 255) },
}

--------------------------------------------------------------------------------
-- Tiendas de la zona segura (NPC + decoración)
--------------------------------------------------------------------------------

Config.ShopTalkDistance = 14

Config.Shops = {
	Medicine = {
		Title = "Medicine",
		Icon = "⚗️",
		Npc = "Herbalist Liora",
		Greeting = "Welcome, traveler! My potions can heal any wound.",
		Position = Vector3.new(-25, 0, 2), -- al oeste de la fuente
		Color = Color3.fromRGB(110, 210, 140),
		Items = { "HealthPotion", "FullPotion", "ManaPotion", "StaminaPotion", "StatReset" },
	},
	Blacksmith = {
		Title = "Blacksmith",
		Icon = "⚒️",
		Npc = "Blacksmith Brakk",
		Greeting = "Finest steel in the land! The more you pay, the better the blade.",
		Position = Vector3.new(25, 0, 2), -- al este de la fuente
		Color = Color3.fromRGB(255, 150, 70),
		Weapons = Config.WeaponOrder,
	},
}

--------------------------------------------------------------------------------
-- Estilos de ataque (animación y color del golpe según raza o arma)
--------------------------------------------------------------------------------

Config.AttackStyles = {
	Punch = { Color = Color3.fromRGB(235, 235, 245) }, -- Human: puñetazo
	Swift = { Color = Color3.fromRGB(120, 240, 150) }, -- Elf: dos golpes rápidos
	Smash = { Color = Color3.fromRGB(255, 90, 60) }, -- Ogre: golpe con los dos brazos desde arriba
	Cast = { Color = Color3.fromRGB(255, 170, 80) }, -- Invocado: empuje mágico con la mano (color del elemento)
	SlimeLunge = { Color = Color3.fromRGB(90, 170, 255) }, -- Slime: se estira y salta hacia delante
	Slash = { Color = Color3.fromRGB(230, 230, 255) }, -- con espada: tajo (color de la rareza)
}

function Config.GetAttackStyle(raceId, weaponId)
	local race = Config.Races[raceId]
	if weaponId and Config.Weapons[weaponId] and not race.CanAbsorb then
		return "Slash"
	end
	if race.CanAbsorb then
		return "SlimeLunge"
	elseif race.Element then
		return "Cast"
	elseif raceId == "Ogre" then
		return "Smash"
	elseif race.ElfEars then
		return "Swift"
	end
	return "Punch"
end

-- Segundos entre golpes, según la velocidad de ataque del arma
function Config.AttackCooldown(weaponId)
	local weapon = weaponId and Config.Weapons[weaponId]
	return Config.Attack.Cooldown / (1 + (if weapon then weapon.AttackSpeed else 0))
end

-- Ajustes del jugador (se guardan en su cuenta, no en el slot)
Config.Settings = {
	{
		Id = "DamageNumbers",
		Name = "Números de daño",
		Description = "Ver el daño que haces encima de los monstruos",
	},
	{
		Id = "MonsterBars",
		Name = "Barras de vida de monstruos",
		Description = "Ver la vida y el nivel de los monstruos",
	},
	{ Id = "SprintFov", Name = "Efecto de cámara al correr", Description = "La cámara se abre un poco al correr" },
	{ Id = "Messages", Name = "Mensajes en pantalla", Description = "Avisos de XP, oro, misiones..." },
}

return Config
