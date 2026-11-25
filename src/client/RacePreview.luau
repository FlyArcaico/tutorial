-- Construye un modelo sencillo de cada raza para mostrarlo en el menú (ViewportFrame).
-- Los modelos miran hacia -Z y están centrados en el origen.
local RacePreview = {}

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

-- Figura humanoide con bloques. Devuelve la escala para añadir extras.
local function figure(model, look)
	local s = look.Scale or 1
	local w = look.Width or 1

	part(model, Vector3.new(1 * w, 2, 1) * s, CFrame.new(-0.5 * w * s, -1.5 * s, 0), look.Pants)
	part(model, Vector3.new(1 * w, 2, 1) * s, CFrame.new(0.5 * w * s, -1.5 * s, 0), look.Pants)
	part(model, Vector3.new(2 * w, 2, 1) * s, CFrame.new(0, 0.5 * s, 0), look.Shirt)
	part(model, Vector3.new(1, 2, 1) * s, CFrame.new(-1.5 * w * s, 0.5 * s, 0), look.Skin)
	part(model, Vector3.new(1, 2, 1) * s, CFrame.new(1.5 * w * s, 0.5 * s, 0), look.Skin)
	part(model, Vector3.new(1.2, 1.2, 1.2) * s, CFrame.new(0, 2.1 * s, 0), look.Skin)

	for _, side in { -1, 1 } do
		part(model, Vector3.new(0.15, 0.25, 0.05) * s, CFrame.new(side * 0.25 * s, 2.2 * s, -0.62 * s), Color3.new())
	end

	if look.Hair then
		part(model, Vector3.new(1.3, 0.35, 1.3) * s, CFrame.new(0, 2.8 * s, 0.05 * s), look.Hair)
	end
	return s, w
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
	local s = figure(model, {
		Skin = skin,
		Shirt = Color3.fromRGB(60, 150, 80),
		Pants = Color3.fromRGB(95, 75, 50),
		Hair = Color3.fromRGB(240, 220, 130),
	})
	-- Orejas puntiagudas
	for _, side in { -1, 1 } do
		part(
			model,
			Vector3.new(0.15, 0.8, 0.3) * s,
			CFrame.new(side * 0.68 * s, 2.3 * s, 0) * CFrame.Angles(0, 0, -side * 0.6),
			skin
		)
	end
end

function builders.Ogre(model)
	local s, w = figure(model, {
		Scale = 1.15,
		Width = 1.25,
		Skin = Color3.fromRGB(175, 110, 90),
		Shirt = Color3.fromRGB(110, 75, 50),
		Pants = Color3.fromRGB(70, 50, 35),
		Hair = Color3.fromRGB(40, 30, 30),
	})
	-- Cuernos
	for _, side in { -1, 1 } do
		part(
			model,
			Vector3.new(0.9, 0.3, 0.3) * s,
			CFrame.new(side * 0.35 * s, 3.1 * s, 0) * CFrame.Angles(0, 0, math.rad(90 - side * 25)),
			Color3.fromRGB(240, 230, 200),
			{ Shape = Enum.PartType.Cylinder }
		)
	end
	-- Cinturón
	part(model, Vector3.new(2.05 * w, 0.3, 1.05) * s, CFrame.new(0, -0.35 * s, 0), Color3.fromRGB(40, 30, 25))
end

function builders.Summoned(model)
	local s = figure(model, {
		Skin = Color3.fromRGB(234, 184, 146),
		Shirt = Color3.fromRGB(130, 30, 35),
		Pants = Color3.fromRGB(35, 30, 35),
		Hair = Color3.fromRGB(25, 25, 30),
	})
	-- Llamas en las manos (los ViewportFrame no muestran Fire, así que usamos neón)
	for _, side in { -1, 1 } do
		part(
			model,
			Vector3.one * 0.9 * s,
			CFrame.new(side * 1.5 * s, -0.8 * s, -0.2 * s),
			Color3.fromRGB(255, 130, 30),
			{ Shape = Enum.PartType.Ball, Material = Enum.Material.Neon }
		)
		part(
			model,
			Vector3.one * 0.5 * s,
			CFrame.new(side * 1.5 * s, -0.3 * s, -0.2 * s),
			Color3.fromRGB(255, 220, 80),
			{ Shape = Enum.PartType.Ball, Material = Enum.Material.Neon }
		)
	end
end

function builders.Slime(model)
	local d = 4
	local height = d * 0.8
	local base = CFrame.new(0, -2.5 + height / 2, 0)

	local function sphere(size, cframe, color, transparency)
		local p = part(model, size, cframe, color, { Transparency = transparency })
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end

	sphere(Vector3.new(d, height, d), base, Color3.fromRGB(90, 170, 255), 0.1)
	for _, side in { -1, 1 } do
		sphere(
			Vector3.new(d * 0.12, d * 0.2, d * 0.12),
			base * CFrame.new(side * d * 0.18, height * 0.12, -d * 0.44),
			Color3.fromRGB(20, 20, 30),
			0
		)
	end
	sphere(Vector3.one * d * 0.14, base * CFrame.new(d * 0.22, height * 0.3, -d * 0.3), Color3.new(1, 1, 1), 0.3)
end

function RacePreview.Build(raceId)
	local model = Instance.new("Model")
	model.Name = raceId
	local builder = builders[raceId] or builders.Human
	builder(model)
	model.WorldPivot = CFrame.new()
	return model
end

return RacePreview
