-- Diseño del Slime (lo usan el servidor para el personaje y el menú para la vista previa,
-- así los dos se ven exactamente igual).
--
-- Un slime azul translúcido y brillante, con forma de "mochi": cuerpo redondo y una base
-- un poco más ancha, luz interior, reflejos suaves, ojos de raya curvada y mejillas.
local SlimeModel = {}

local WHITE = Color3.new(1, 1, 1)

SlimeModel.HeightRatio = 0.78 -- alto del cuerpo respecto al ancho
SlimeModel.BottomRatio = 0.52 -- distancia del centro al suelo (en altos de cuerpo)

-- Alto del cuerpo para un tamaño de forma
function SlimeModel.Height(size)
	return size * SlimeModel.HeightRatio
end

-- Distancia del centro del cuerpo al suelo
function SlimeModel.CenterHeight(size)
	return SlimeModel.Height(size) * SlimeModel.BottomRatio
end

-- Devuelve la lista de piezas. Cada pieza:
--   Name, Role ("Body", "Core", "Shine", "Eye", "Cheek"), Size, Offset (CFrame desde el
--   centro del cuerpo), Color, Transparency, Material, Sphere (usa malla esférica)
function SlimeModel.Pieces(form)
	local d = form.Size
	local h = SlimeModel.Height(d)
	local rx, ry = d / 2, h / 2
	local color = form.Color
	local pieces = {}

	-- Punto de la superficie del cuerpo (para pegar cara y brillos por fuera)
	local function surfaceZ(x, y, push)
		local inside = 1 - (x / rx) ^ 2 - (y / ry) ^ 2
		return -rx * math.sqrt(math.max(inside, 0)) - d * (push or 0.012)
	end

	local function add(piece)
		piece.Material = piece.Material or Enum.Material.SmoothPlastic
		piece.Transparency = piece.Transparency or 0
		table.insert(pieces, piece)
	end

	-- Cuerpo translúcido y la base blandita
	add({
		Name = "Body",
		Role = "Body",
		Size = Vector3.new(d, h, d),
		Offset = CFrame.new(),
		Color = color,
		Transparency = 0.2,
		Material = Enum.Material.Glass,
		Sphere = true,
	})
	add({
		Name = "Base",
		Role = "Body",
		Size = Vector3.new(d * 1.08, h * 0.42, d * 1.08),
		Offset = CFrame.new(0, -h * 0.31, 0),
		Color = color,
		Transparency = 0.2,
		Material = Enum.Material.Glass,
		Sphere = true,
	})

	-- Luz interior (brilla más al usar magia)
	add({
		Name = "Core",
		Role = "Core",
		Size = Vector3.new(d * 0.55, h * 0.5, d * 0.55),
		Offset = CFrame.new(0, -h * 0.05, d * 0.04),
		Color = color:Lerp(Color3.fromRGB(190, 245, 255), 0.6),
		Transparency = 0.78,
		Material = Enum.Material.Neon,
		Sphere = true,
	})

	-- Reflejos: uno grande y suave arriba a la izquierda y un puntito más brillante
	local shineX, shineY = -d * 0.2, h * 0.3
	add({
		Name = "Shine",
		Role = "Shine",
		Size = Vector3.new(d * 0.3, h * 0.15, d * 0.12),
		Offset = CFrame.new(shineX, shineY, surfaceZ(shineX, shineY, 0.0))
			* CFrame.Angles(math.rad(-25), 0, math.rad(18)),
		Color = WHITE,
		Transparency = 0.45,
		Sphere = true,
	})
	local dotX, dotY = -d * 0.31, h * 0.14
	add({
		Name = "ShineDot",
		Role = "Shine",
		Size = Vector3.one * d * 0.075,
		Offset = CFrame.new(dotX, dotY, surfaceZ(dotX, dotY, 0.0)),
		Color = WHITE,
		Transparency = 0.15,
		Sphere = true,
	})

	-- Ojos: cada uno es una curva ◡ suave hecha con 3 trocitos, por fuera del cuerpo
	local eyeColor = Color3.fromRGB(18, 28, 60)
	local segment = Vector3.new(d * 0.075, d * 0.034, d * 0.03)
	for _, side in { -1, 1 } do
		local ex, ey = side * d * 0.17, h * 0.08
		for _, bit in { { 0, -d * 0.013, 0 }, { -d * 0.058, 0, -0.5 }, { d * 0.058, 0, 0.5 } } do
			local x, y = ex + bit[1], ey + bit[2]
			add({
				Name = "Eye",
				Role = "Eye",
				Size = segment,
				Offset = CFrame.new(x, y, surfaceZ(x, y)) * CFrame.Angles(0, -x / rx * 0.9, bit[3]),
				Color = eyeColor,
			})
		end

		-- Mejillas sonrosadas
		local cx, cy = side * d * 0.27, -h * 0.06
		add({
			Name = "Cheek",
			Role = "Cheek",
			Size = Vector3.new(d * 0.12, d * 0.06, d * 0.03),
			Offset = CFrame.new(cx, cy, surfaceZ(cx, cy, 0.006)) * CFrame.Angles(0, -cx / rx * 0.9, 0),
			Color = Color3.fromRGB(255, 150, 195),
			Transparency = 0.55,
			Sphere = true,
		})
	end

	return pieces
end

-- Crea una pieza de verdad a partir de su descripción (anclada o no)
function SlimeModel.MakePart(piece, cframe)
	local part = Instance.new("Part")
	part.Name = piece.Name
	part.Size = piece.Size
	part.CFrame = cframe
	part.Color = piece.Color
	part.Transparency = piece.Transparency
	part.Material = piece.Material
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = piece.Role == "Body"
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("SlimeRole", piece.Role)
	if piece.Sphere then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	return part
end

return SlimeModel
