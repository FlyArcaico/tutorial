-- Cara del Slime con expresiones. Dibuja ojos y boca con líneas y óvalos de interfaz
-- (SurfaceGui) sobre las placas que crea el servidor (FaceRightEye, FaceLeftEye, FaceMouth).
-- Así se ven nítidas, se pueden cambiar al instante y no hacen falta imágenes subidas.
--
-- Expresiones: Normal (relajado), Happy (contento), Angry (enfadado), Focused (concentrado),
--              Sad (triste), Surprised (sorprendido)
local SlimeFace = {}

local INK = Color3.fromRGB(18, 28, 60)
local WHITE = Color3.new(1, 1, 1)
local TEAR = Color3.fromRGB(150, 220, 255)
local TONGUE = Color3.fromRGB(255, 120, 150)

SlimeFace.Expressions = { "Normal", "Happy", "Angry", "Focused", "Sad", "Surprised" }

local EYE_CANVAS = Vector2.new(120, 100)
local MOUTH_CANVAS = Vector2.new(120, 70)

--------------------------------------------------------------------------------
-- Dibujo: líneas con puntas redondas, arcos y óvalos (en píxeles del lienzo)
--------------------------------------------------------------------------------

local function line(parent, x1, y1, x2, y2, thickness, color)
	local dx, dy = x2 - x1, y2 - y1
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2)
	frame.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + thickness, thickness)
	frame.Rotation = math.deg(math.atan2(dy, dx))
	frame.BackgroundColor3 = color or INK
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	frame.Parent = parent
	return frame
end

-- Arco de elipse; los ángulos en grados (0 = derecha, 90 = abajo)
local function arc(parent, cx, cy, rx, ry, fromAngle, toAngle, thickness, color)
	local segments = 7
	local previous = nil
	for index = 0, segments do
		local angle = math.rad(fromAngle + (toAngle - fromAngle) * index / segments)
		local point = Vector2.new(cx + math.cos(angle) * rx, cy + math.sin(angle) * ry)
		if previous then
			line(parent, previous.X, previous.Y, point.X, point.Y, thickness, color)
		end
		previous = point
	end
end

local function oval(parent, cx, cy, width, height, color, transparency)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromOffset(cx, cy)
	frame.Size = UDim2.fromOffset(width, height)
	frame.BackgroundColor3 = color or INK
	frame.BackgroundTransparency = transparency or 0
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	frame.Parent = parent
	return frame
end

--------------------------------------------------------------------------------
-- Diseños (para el ojo derecho del slime; el izquierdo es el espejo).
-- En el lienzo, la nariz queda a la derecha (x grande) para el ojo derecho.
--------------------------------------------------------------------------------

local EYES = {
	-- Relajado: ojos cerrados en curva suave ◡
	Normal = function(canvas, mx)
		arc(canvas, mx(60), 46, 30, 16, 0, 180, 9)
	end,
	-- Contento: ojos cerrados hacia arriba ^
	Happy = function(canvas, mx)
		arc(canvas, mx(60), 64, 30, 22, 180, 360, 10)
	end,
	-- Enfadado: ceja inclinada hacia la nariz y ojo entornado
	Angry = function(canvas, mx)
		line(canvas, mx(18), 24, mx(102), 48, 9)
		arc(canvas, mx(62), 76, 24, 13, 180, 360, 9)
	end,
	-- Concentrado: ceja casi recta y ojo como una línea
	Focused = function(canvas, mx)
		line(canvas, mx(20), 30, mx(100), 40, 8)
		line(canvas, mx(30), 66, mx(94), 66, 10)
	end,
	-- Triste: ceja levantada por el lado de la nariz, ojo caído y una lágrima
	Sad = function(canvas, mx)
		line(canvas, mx(18), 42, mx(100), 22, 8)
		arc(canvas, mx(60), 76, 26, 12, 180, 360, 9)
		oval(canvas, mx(32), 92, 13, 18, TEAR, 0.15)
	end,
	-- Sorprendido: ojo abierto y redondo con brillo
	Surprised = function(canvas, mx)
		oval(canvas, mx(60), 56, 46, 64, INK)
		oval(canvas, mx(71), 41, 14, 17, WHITE)
		oval(canvas, mx(52), 70, 7, 8, WHITE, 0.3)
	end,
}

local MOUTHS = {
	Normal = function(canvas)
		arc(canvas, 60, 22, 13, 9, 0, 180, 6)
	end,
	Happy = function(canvas)
		-- Boca abierta en forma de D, con la lengua
		local clip = Instance.new("Frame")
		clip.AnchorPoint = Vector2.new(0.5, 0)
		clip.Position = UDim2.fromOffset(60, 16)
		clip.Size = UDim2.fromOffset(46, 34)
		clip.BackgroundTransparency = 1
		clip.ClipsDescendants = true
		clip.Parent = canvas
		oval(clip, 23, 0, 46, 64, INK)
		oval(clip, 23, 28, 26, 16, TONGUE)
	end,
	Angry = function(canvas)
		arc(canvas, 60, 42, 15, 9, 180, 360, 6)
	end,
	Focused = function(canvas)
		line(canvas, 50, 34, 70, 34, 6)
	end,
	Sad = function(canvas)
		arc(canvas, 60, 46, 17, 11, 180, 360, 6)
	end,
	Surprised = function(canvas)
		local ring = oval(canvas, 60, 34, 20, 26, INK, 1)
		local stroke = Instance.new("UIStroke")
		stroke.Color = INK
		stroke.Thickness = 5
		stroke.Parent = ring
	end,
}

--------------------------------------------------------------------------------
-- Montar la cara sobre las placas y cambiar de expresión
--------------------------------------------------------------------------------

local function surface(plate, canvasSize)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SlimeFaceGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = canvasSize
	gui.LightInfluence = 0.25
	gui.Parent = plate
	return gui
end

-- Crea la cara sobre un SlimeBody. Devuelve un controlador con :Set(expresión).
function SlimeFace.Attach(body)
	local plates = {
		Right = body:FindFirstChild("FaceRightEye"),
		Left = body:FindFirstChild("FaceLeftEye"),
		Mouth = body:FindFirstChild("FaceMouth"),
	}
	if not plates.Right or not plates.Left or not plates.Mouth then
		return nil
	end

	local layers = {} -- [expresión] = { frames }
	for _, expression in SlimeFace.Expressions do
		layers[expression] = {}
	end

	local function build(plate, canvasSize, draw, mirrored)
		local gui = surface(plate, canvasSize)
		for _, expression in SlimeFace.Expressions do
			local canvas = Instance.new("Frame")
			canvas.Name = expression
			canvas.Size = UDim2.fromScale(1, 1)
			canvas.BackgroundTransparency = 1
			canvas.Visible = false
			canvas.Parent = gui
			-- El ojo izquierdo es el espejo del derecho
			local function mx(x)
				return if mirrored then canvasSize.X - x else x
			end
			draw[expression](canvas, mx)
			table.insert(layers[expression], canvas)
		end
	end

	build(plates.Right, EYE_CANVAS, EYES, false)
	build(plates.Left, EYE_CANVAS, EYES, true)
	build(plates.Mouth, MOUTH_CANVAS, MOUTHS, false)

	local controller = { Current = nil }
	function controller.Set(_, expression)
		if controller.Current == expression or not layers[expression] then
			return
		end
		if controller.Current then
			for _, canvas in layers[controller.Current] do
				canvas.Visible = false
			end
		end
		for _, canvas in layers[expression] do
			canvas.Visible = true
		end
		controller.Current = expression
	end
	controller:Set("Normal")
	return controller
end

return SlimeFace
