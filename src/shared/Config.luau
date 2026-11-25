-- Game balance and content. Change numbers here to tune the game.
local Config = {}

Config.GameName = "Slime Rebirth"

Config.Attack = {
	Range = 8, -- studs in front of the slime (plus half the slime's size)
	Cooldown = 0.5, -- seconds between attacks
}

Config.AbsorbRange = 12 -- how close you must be to an essence to absorb it
Config.EssenceLifetime = 20 -- seconds before an essence disappears

-- Slime forms. You evolve automatically when you reach MinLevel.
-- Keep them sorted from lowest to highest level.
Config.Forms = {
	{
		Name = "Little Slime",
		MinLevel = 1,
		Size = 3,
		Color = Color3.fromRGB(90, 170, 255),
		DamageBonus = 0,
	},
	{
		Name = "Greater Slime",
		MinLevel = 5,
		Size = 4.5,
		Color = Color3.fromRGB(70, 215, 190),
		DamageBonus = 5,
	},
	{
		Name = "Slime Monarch",
		MinLevel = 10,
		Size = 6,
		Color = Color3.fromRGB(170, 110, 255),
		DamageBonus = 15,
	},
}

-- Skills you steal by absorbing a monster type for the first time.
Config.Skills = {
	Dash = {
		DisplayName = "Wolf Dash",
		Description = "Dash forward (Q)",
		Cooldown = 2,
		Speed = 90,
		Duration = 0.25,
	},
	HighJump = {
		DisplayName = "Bat Wings",
		Description = "Passive: jump much higher",
		JumpPower = 85,
	},
	StoneSkin = {
		DisplayName = "Stone Skin",
		Description = "Passive: +50 max health",
		BonusHealth = 50,
	},
}

Config.Monsters = {
	Bat = {
		DisplayName = "Cave Bat",
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
		DisplayName = "Forest Wolf",
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
		DisplayName = "Rock Golem",
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

-- Areas where monsters spawn. Spawn point is at (0, 0, 0); zones go north (-Z).
Config.Zones = {
	{
		Name = "Whispering Meadow",
		Label = "Whispering Meadow\nLevel 1+",
		Center = Vector3.new(0, 0, -140),
		Radius = 70,
		Monsters = { "Bat", "Bat", "Wolf" },
		MaxMonsters = 10,
	},
	{
		Name = "Stone Hills",
		Label = "Stone Hills\nLevel 5+",
		Center = Vector3.new(0, 0, -340),
		Radius = 80,
		Monsters = { "Wolf", "Golem", "Golem" },
		MaxMonsters = 6,
	},
}

function Config.GetForm(level)
	local current = Config.Forms[1]
	for _, form in Config.Forms do
		if level >= form.MinLevel then
			current = form
		end
	end
	return current
end

function Config.XPToNextLevel(level)
	return 40 + level * 20
end

function Config.MaxHealth(level, skills)
	local health = 100 + (level - 1) * 15
	if skills.StoneSkin then
		health += Config.Skills.StoneSkin.BonusHealth
	end
	return health
end

function Config.AttackDamage(level)
	return 10 + (level - 1) * 4 + Config.GetForm(level).DamageBonus
end

function Config.WalkSpeed(level)
	return 16 + math.min(level, 20) * 0.4
end

return Config
