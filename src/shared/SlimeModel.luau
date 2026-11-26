-- Diseño del Slime (lo usan el servidor para el personaje y el menú para la vista previa,
-- así los dos se ven exactamente igual).
--
-- Un slime azul translúcido y brillante, con forma de "mochi": cuerpo redondo y una base
-- un poco más ancha, luz interior, reflejos suaves, ojos de raya curvada y mejillas.
local SlimeModel = {}

local WHITE = Color3.new(1, 1, 1)

SlimeModel.HeightRatio = 0.82 -- alto del cuerpo respecto al ancho (un poco ovalado)
SlimeModel.BottomRatio = 0.5 -- distancia del centro al suelo (en altos de cuerpo)
SlimeModel.DepthRatio = 0.94 -- un poco más estrecho de delante a atrás: silueta más orgánica

-- Alto del cuerpo para un tamaño de forma
function SlimeModel.Height(size)
	return size * SlimeModel.HeightRatio
end

-- Distancia del centro del cuerpo al suelo
function SlimeModel.CenterHeight(size)
	return SlimeModel.Height(size) * SlimeModel.BottomRatio
end

-- Devuelve la lista de piezas. Cada pieza:
--   Name, Role ("Body", "Core", "Shine", "Eye", "Face", "Cheek"), Size, Offset (CFrame desde
--   el centro del cuerpo), Color, Transparency, Material, Sphere (usa malla esférica)
-- options.Face:
--   "Plates" (en el juego): placas invisibles para ojos y boca donde el cliente dibuja
--            las expresiones (ver client/SlimeFace.luau).
--   "Parts"  (por defecto, vista previa del menú): ojos de raya hechos con piezas.
function SlimeModel.Pieces(form, options)
	local faceStyle = options and options.Face or "Parts"
	local d = form.Size
	local h = SlimeModel.Height(d)
	local rx, ry, rz = d / 2, h / 2, d * SlimeModel.DepthRatio / 2
	local color = form.Color
	local pieces = {}

	-- Punto de la superficie del cuerpo (para pegar cara y brillos por fuera)
	local function surfaceZ(x, y, push)
		local inside = 1 - (x / rx) ^ 2 - (y / ry) ^ 2
		return -rz * math.sqrt(math.max(inside, 0)) - d * (push or 0.012)
	end

	local function add(piece)
		piece.Material = piece.Material or Enum.Material.SmoothPlastic
		piece.Transparency = piece.Transparency or 0
		table.insert(pieces, piece)
	end

	-- Cuerpo translúcido. La base queda casi entera dentro del cuerpo: solo ensancha un
	-- poco la parte de abajo, sin formar un anillo.
	add({
		Name = "Body",
		Role = "Body",
		Size = Vector3.new(d, h, d * SlimeModel.DepthRatio),
		Offset = CFrame.new(),
		Color = color,
		Transparency = 0.2,
		Material = Enum.Material.Glass,
		Sphere = true,
	})
	add({
		Name = "Base",
		Role = "Body",
		Size = Vector3.new(d * 0.99, h * 0.5, d * SlimeModel.DepthRatio * 0.97),
		Offset = CFrame.new(0, -h * 0.22, 0),
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

	-- Orientación de la superficie en un punto: gira hacia los lados y hacia arriba/abajo
	-- siguiendo la curva del cuerpo, para que la cara parezca pegada y no flotando
	local function onSurface(x, y, push)
		local tiltUp = math.asin(math.clamp(y / ry, -1, 1)) * 0.8
		return CFrame.new(x, y, surfaceZ(x, y, push)) * CFrame.Angles(0, -x / rx * 0.9, 0) * CFrame.Angles(tiltUp, 0, 0)
	end

	-- Placa de la cara: invisible, casi tocando la superficie
	local function facePlate(name, x, y, width, height)
		add({
			Name = name,
			Role = "Face",
			Size = Vector3.new(width, height, d * 0.01),
			Offset = onSurface(x, y, 0.004),
			Color = WHITE,
			Transparency = 1,
		})
	end

	-- Ojos alargados (2:1) en la parte media-alta de la cara (sin boca)
	local eyeX, eyeY = d * 0.19, h * 0.08
	if faceStyle == "Plates" then
		facePlate("FaceRightEye", eyeX, eyeY, d * 0.3, d * 0.15)
		facePlate("FaceLeftEye", -eyeX, eyeY, d * 0.3, d * 0.15)
	end

	local eyeColor = Color3.fromRGB(18, 22, 40)
	local segment = Vector3.new(d * 0.09, d * 0.026, d * 0.025)
	for _, side in { -1, 1 } do
		-- Ojos de piezas (solo vista previa del menú): una línea alargada y curvada ∩,
		-- hecha con 3 trocitos por fuera del cuerpo
		local ex, ey = side * eyeX, eyeY
		for _, bit in { { 0, d * 0.012, 0 }, { -d * 0.075, 0, 0.32 }, { d * 0.075, 0, -0.32 } } do
			if faceStyle == "Plates" then
				break
			end
			local x, y = ex + bit[1], ey + bit[2]
			add({
				Name = "Eye",
				Role = "Eye",
				Size = segment,
				Offset = onSurface(x, y, 0.012) * CFrame.Angles(0, 0, bit[3]),
				Color = eyeColor,
			})
		end

		-- Mejillas sonrosadas: pequeñas y suaves, debajo y por fuera de los ojos
		local cx, cy = side * d * 0.26, -h * 0.04
		add({
			Name = "Cheek",
			Role = "Cheek",
			Size = Vector3.new(d * 0.1, d * 0.045, d * 0.02),
			Offset = onSurface(cx, cy, 0.003),
			Color = Color3.fromRGB(255, 150, 195),
			Transparency = 0.62,
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
