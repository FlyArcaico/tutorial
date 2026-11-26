-- Construye un modelo sencillo de cada raza para mostrarlo en el menú (ViewportFrame).
-- Estilo R6. Los modelos miran hacia -Z y todos tienen los pies en y = -2.5,
-- así se nota la diferencia de tamaño entre razas.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local RacePreview = {}

local FLOOR = -2.5

local function part(model, size, cframe, color, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props or {} do
		p[key] = value
	end
	p.Parent = model
	return p
end

-- Convierte una posición de una figura de tamaño normal a una figura escalada
local function scaler(s)
	return function(x, y, z)
		return CFrame.new(x * s, FLOOR + (y - FLOOR) * s, z * s)
	end
end

-- Figura R6 con bloques. Devuelve la función de posición y la escala.
local function figure(model, look)
	local s = look.Scale or 1
	local at = scaler(s)

	part(model, Vector3.new(1, 2, 1) * s, at(-0.5, -1.5, 0), look.Pants)
	part(model, Vector3.new(1, 2, 1) * s, at(0.5, -1.5, 0), look.Pants)
	part(model, Vector3.new(2, 2, 1) * s, at(0, 0.5, 0), look.Shirt)
	part(model, Vector3.new(1, 2, 1) * s, at(-1.5, 0.5, 0), look.Sleeves or look.Skin)
	part(model, Vector3.new(1, 2, 1) * s, at(1.5, 0.5, 0), look.Sleeves or look.Skin)
	part(model, Vector3.new(1.2, 1.2, 1.2) * s, at(0, 2.1, 0), look.Skin)

	for _, side in { -1, 1 } do
		part(model, Vector3.new(0.15, 0.25, 0.05) * s, at(side * 0.25, 2.2, -0.62), Color3.new())
	end
	part(model, Vector3.new(0.4, 0.08, 0.05) * s, at(0, 1.85, -0.62), Color3.fromRGB(120, 60, 50))

	if look.Hair then
		part(model, Vector3.new(1.3, 0.35, 1.3) * s, at(0, 2.8, 0.05), look.Hair)
	end
	return at, s
end

local function elfEars(model, at, s, skin)
	for _, side in { -1, 1 } do
		part(model, Vector3.new(0.15, 0.8, 0.3) * s, at(side * 0.68, 2.3, 0) * CFrame.Angles(0, 0, -side * 0.6), skin)
	end
end

local builders = {}

function builders.Human(model)
	figure(model, {
		Skin = Color3.fromRGB(234, 184, 146),
		Shirt = Color3.fromRGB(70, 120, 200),
		Pants = Color3.fromRGB(50, 50, 70),
		Hair = Color3.fromRGB(90, 60, 40),
	})
end

function builders.Elf(model)
	local skin = Color3.fromRGB(245, 218, 190)
	local at, s = figure(model, {
		Skin = skin,
		Shirt = Color3.fromRGB(60, 150, 80),
		Pants = Color3.fromRGB(95, 75, 50),
		Hair = Color3.fromRGB(240, 220, 130),
	})
	elfEars(model, at, s, skin)
end

function builders.MajorElf(model)
	local skin = Color3.fromRGB(250, 225, 200)
	local green = Color3.fromRGB(40, 150, 70)
	local gold = Color3.fromRGB(255, 200, 60)
	local at, s = figure(model, {
		Scale = Config.Races.MajorElf.BodyScale,
		Skin = skin,
		Shirt = Color3.fromRGB(35, 120, 60),
		Sleeves = Color3.fromRGB(35, 120, 60),
		Pants = Color3.fromRGB(230, 230, 215),
		Hair = Color3.fromRGB(250, 235, 160),
	})
	elfEars(model, at, s, skin)

	-- Capa dorada en el pecho
	part(model, Vector3.new(2.05, 0.3, 1.05) * s, at(0, -0.35, 0), gold)
	part(model, Vector3.new(0.35, 0.35, 0.05) * s, at(0, 1.1, -0.53), gold, { Material = Enum.Material.Neon })

	-- Gorro verde puntiagudo con banda dorada y pluma
	local up = CFrame.Angles(0, 0, math.rad(90))
	part(model, Vector3.new(0.12, 1.9, 1.9) * s, at(0, 2.75, 0) * up, green, { Shape = Enum.PartType.Cylinder })
	part(model, Vector3.new(0.18, 1.32, 1.32) * s, at(0, 2.88, 0) * up, gold, { Shape = Enum.PartType.Cylinder })
	for index, diameter in { 1.25, 1.0, 0.75, 0.5, 0.28 } do
		part(
			model,
			Vector3.new(0.34, diameter, diameter) * s,
			at(0, 2.95 + index * 0.3, index * 0.09) * up,
			green,
			{ Shape = Enum.PartType.Cylinder }
		)
	end
	part(
		model,
		Vector3.new(0.1, 1.1, 0.3) * s,
		at(0.6, 3.3, 0.1) * CFrame.Angles(0, 0, -0.5),
		Color3.fromRGB(240, 240, 220)
	)

	-- Corte de viento girando alrededor de la mano
	part(
		model,
		Vector3.new(1.6, 0.15, 0.6) * s,
		at(1.9, -0.5, -0.6) * CFrame.Angles(0, 0.4, 0.3),
		Color3.fromRGB(170, 255, 200),
		{ Material = Enum.Material.Neon, Transparency = 0.3 }
	)
end

function builders.Ogre(model)
	local at, s = figure(model, {
		Scale = Config.Races.Ogre.BodyScale,
		Skin = Color3.fromRGB(175, 110, 90),
		Shirt = Color3.fromRGB(110, 75, 50),
		Pants = Color3.fromRGB(70, 50, 35),
		Hair = Color3.fromRGB(40, 30, 30),
	})
	-- Cuernos pequeños y negros
	for _, side in { -1, 1 } do
		part(
			model,
			Vector3.new(0.5, 0.2, 0.2) * s,
			at(side * 0.32, 2.85, -0.1) * CFrame.Angles(0, 0, math.rad(90 - side * 20)),
			Color3.fromRGB(25, 22, 25),
			{ Shape = Enum.PartType.Cylinder }
		)
		part(
			model,
			Vector3.new(0.22, 0.12, 0.12) * s,
			at(side * 0.4, 3.1, -0.1) * CFrame.Angles(0, 0, math.rad(90 - side * 35)),
			Color3.fromRGB(10, 10, 12),
			{ Shape = Enum.PartType.Cylinder }
		)
	end
	part(model, Vector3.new(2.05, 0.3, 1.05) * s, at(0, -0.35, 0), Color3.fromRGB(40, 30, 25))
end

-- Invocados: capa del color de su elemento y magia en las manos (neón, porque los
-- ViewportFrame no muestran fuego ni partículas)
local function summonedBuilder(raceId)
	return function(model)
		local race = Config.Races[raceId]
		local gold = Color3.fromRGB(255, 200, 70)
		local at, s = figure(model, {
			Skin = Color3.fromRGB(234, 184, 146),
			Shirt = race.CapeColor:Lerp(Color3.new(), 0.35),
			Pants = Color3.fromRGB(35, 30, 35),
			Hair = Color3.fromRGB(25, 25, 30),
		})
		local fabric = { Material = Enum.Material.Fabric }
		part(
			model,
			Vector3.new(2.1, 3, 0.15) * s,
			at(0, 0.1, 0.62) * CFrame.Angles(math.rad(8), 0, 0),
			race.CapeColor,
			fabric
		)
		part(model, Vector3.new(2.2, 0.35, 1.2) * s, at(0, 1.45, 0.05), race.CapeColor:Lerp(Color3.new(), 0.25), fabric)
		part(model, Vector3.new(0.35, 0.35, 0.1) * s, at(0, 1.35, -0.55), gold, { Material = Enum.Material.Neon })
		part(model, Vector3.new(2.05, 0.25, 1.05) * s, at(0, -0.4, 0), gold)

		for _, side in { -1, 1 } do
			part(
				model,
				Vector3.one * 0.9 * s,
				at(side * 1.5, -0.8, -0.2),
				race.Color,
				{ Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Transparency = 0.15 }
			)
			part(
				model,
				Vector3.one * 0.5 * s,
				at(side * 1.5, -0.25, -0.2),
				race.Color:Lerp(Color3.new(1, 1, 1), 0.5),
				{ Shape = Enum.PartType.Ball, Material = Enum.Material.Neon }
			)
		end
	end
end

builders.SummonedFire = summonedBuilder("SummonedFire")
builders.SummonedWater = summonedBuilder("SummonedWater")
builders.SummonedPlant = summonedBuilder("SummonedPlant")
builders.Summoned = builders.SummonedFire

function builders.Slime(model)
	local d = 4
	local height = d * 0.8
	local base = CFrame.new(0, FLOOR + height / 2, 0)

	local function sphere(size, cframe, color, transparency)
		local p = part(model, size, cframe, color, { Transparency = transparency })
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end

	-- Bola azul con reborde azul clarito
	sphere(Vector3.new(d, height, d), base, Color3.fromRGB(90, 170, 255), 0.05)
	sphere(Vector3.new(d, height, d) * 1.08, base, Color3.fromRGB(175, 230, 255), 0.6)
	-- Ojos achinados: dos rayas
	for _, side in { -1, 1 } do
		part(
			model,
			Vector3.new(d * 0.17, d * 0.035, d * 0.04),
			base * CFrame.new(side * d * 0.18, height * 0.15, -d * 0.445) * CFrame.Angles(0, side * 0.38, side * 0.12),
			Color3.fromRGB(25, 35, 60)
		)
	end
	sphere(Vector3.one * d * 0.13, base * CFrame.new(d * 0.22, height * 0.32, -d * 0.3), Color3.new(1, 1, 1), 0.25)
end

function RacePreview.Build(raceId)
	local model = Instance.new("Model")
	model.Name = raceId
	local builder = builders[raceId] or builders.Human
	builder(model)
	model.WorldPivot = CFrame.new()
	return model
end

-- Cámara que encuadra hasta el más grande (Ogre)
RacePreview.CameraCFrame = CFrame.lookAt(Vector3.new(0, 3.4, -18.5), Vector3.new(0, 2.7, 0))

return RacePreview
