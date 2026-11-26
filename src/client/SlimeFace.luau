-- Cara del Slime con expresiones, dibujada con líneas de interfaz (SurfaceGui) sobre las
-- placas que crea el servidor (FaceRightEye, FaceLeftEye).
--
-- Estilo: cara de anime simple y limpia. Cada ojo es UNA sola línea negra, alargada y
-- curvada, más gruesa en el centro y fina en las puntas (sin cejas). Sin boca.
--
-- Expresiones:
--   Normal     ojos alargados y suavemente curvados (relajado)
--   Energetic  como Normal pero un poco más curvados (al correr)
--   Happy      ^^ cerrados hacia arriba (al absorber, de vez en cuando quieto)
--   Angry      ojos inclinados hacia el centro (al atacar)
--   Focused    ojos más finos y rectos (al usar una habilidad)
--   Hurt       > < apretados (al recibir un golpe)
--   Sad        ojos caídos hacia fuera (poca vida o muerto)
local TweenService = game:GetService("TweenService")

local SlimeFace = {}

local INK = Color3.fromRGB(18, 22, 40)
local FADE = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

SlimeFace.Expressions = { "Normal", "Energetic", "Happy", "Angry", "Focused", "Hurt", "Sad" }

-- El lienzo de cada ojo es 2:1, igual que su placa (alargado)
local EYE_CANVAS = Vector2.new(160, 80)

--------------------------------------------------------------------------------
-- Dibujo
--------------------------------------------------------------------------------

-- Trazo recto con las puntas redondas
local function stroke(parent, a, b, thickness)
	local delta = b - a
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
	frame.Size = UDim2.fromOffset(delta.Magnitude + thickness, thickness)
	frame.Rotation = math.deg(math.atan2(delta.Y, delta.X))
	frame.BackgroundColor3 = INK
	frame.BackgroundTransparency = 1 -- empieza oculto; se muestra con un fundido
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	frame.Parent = parent
	return frame
end

-- Curva suave (bézier de 3 puntos) más gruesa en el centro y fina en las puntas,
-- como una pincelada de anime
local function curve(parent, p0, p1, p2, thickness)
	local segments = 10
	local previous = p0
	for index = 1, segments do
		local t = index / segments
		local point = p0 * (1 - t) ^ 2 + p1 * 2 * (1 - t) * t + p2 * t ^ 2
		local middle = (index - 0.5) / segments
		local width = thickness * (0.45 + 0.55 * math.sin(middle * math.pi))
		stroke(parent, previous, point, width)
		previous = point
	end
end

local V = Vector2.new

--------------------------------------------------------------------------------
-- Diseños. Los ojos están dibujados para el ojo derecho del slime: en su lienzo,
-- la nariz queda a la derecha (x grande). El ojo izquierdo es el espejo.
--------------------------------------------------------------------------------

local EYES = {
	Normal = function(canvas, m)
		curve(canvas, m(16, 50), m(80, 30), m(144, 50), 7)
	end,
	Energetic = function(canvas, m)
		curve(canvas, m(18, 54), m(80, 24), m(142, 54), 8)
	end,
	Happy = function(canvas, m) -- ^
		curve(canvas, m(32, 64), m(80, 4), m(128, 64), 8)
	end,
	Angry = function(canvas, m) -- inclinado hacia abajo por el lado de la nariz
		curve(canvas, m(14, 26), m(84, 38), m(146, 60), 8)
	end,
	Focused = function(canvas, m)
		curve(canvas, m(18, 44), m(80, 40), m(142, 50), 6)
	end,
	Hurt = function(canvas, m) -- > (apunta a la nariz)
		stroke(canvas, m(50, 20), m(104, 40), 7)
		stroke(canvas, m(104, 40), m(50, 60), 7)
	end,
	Sad = function(canvas, m) -- caído por el lado de fuera
		curve(canvas, m(16, 60), m(82, 40), m(144, 34), 7)
	end,
}

--------------------------------------------------------------------------------
-- Montar la cara sobre las placas y cambiar de expresión (con fundido suave)
--------------------------------------------------------------------------------

local function surface(plate, canvasSize)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SlimeFaceGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = canvasSize
	gui.LightInfluence = 0.2
	gui.Parent = plate
	return gui
end

-- Crea la cara sobre un SlimeBody. Devuelve un controlador con :Set(expresión).
function SlimeFace.Attach(body)
	local plates = {
		Right = body:FindFirstChild("FaceRightEye"),
		Left = body:FindFirstChild("FaceLeftEye"),
	}
	if not plates.Right or not plates.Left then
		return nil
	end

	local strokes = {} -- [expresión] = { frames }
	for _, expression in SlimeFace.Expressions do
		strokes[expression] = {}
	end

	local function build(plate, canvasSize, designs, mirrored)
		local gui = surface(plate, canvasSize)
		for _, expression in SlimeFace.Expressions do
			local canvas = Instance.new("Frame")
			canvas.Name = expression
			canvas.Size = UDim2.fromScale(1, 1)
			canvas.BackgroundTransparency = 1
			canvas.Parent = gui
			-- El ojo izquierdo es el espejo del derecho
			local function m(x, y)
				return V(if mirrored then canvasSize.X - x else x, y)
			end
			designs[expression](canvas, m)
			for _, child in canvas:GetChildren() do
				table.insert(strokes[expression], child)
			end
		end
	end

	build(plates.Right, EYE_CANVAS, EYES, false)
	build(plates.Left, EYE_CANVAS, EYES, true)

	local controller = { Current = nil }

	local function show(expression, visible, instant)
		for _, frame in strokes[expression] do
			local goal = if visible then 0 else 1
			if instant then
				frame.BackgroundTransparency = goal
			else
				TweenService:Create(frame, FADE, { BackgroundTransparency = goal }):Play()
			end
		end
	end

	-- Cambia de expresión con un fundido rápido (sin saltos bruscos)
	function controller.Set(_, expression, instant)
		if controller.Current == expression or not strokes[expression] then
			return
		end
		if controller.Current then
			show(controller.Current, false, instant)
		end
		show(expression, true, instant)
		controller.Current = expression
	end

	controller:Set("Normal", true)
	return controller
end

return SlimeFace
