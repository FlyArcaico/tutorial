-- Utilidades para crear interfaz con código, con el tema del juego:
-- "ventana de estado" de fantasía en azul noche con bordes cian brillantes y detalles dorados.
local UI = {}

UI.Colors = {
	Dark = Color3.fromRGB(8, 14, 32),
	Panel = Color3.fromRGB(16, 28, 58),
	PanelLight = Color3.fromRGB(30, 50, 92),
	White = Color3.new(1, 1, 1),
	Muted = Color3.fromRGB(150, 175, 210),
	Accent = Color3.fromRGB(90, 210, 255), -- cian
	AccentDark = Color3.fromRGB(30, 110, 170),
	Gold = Color3.fromRGB(255, 210, 110),
	Green = Color3.fromRGB(60, 190, 120),
	Red = Color3.fromRGB(215, 70, 80),
}

UI.Fonts = {
	Title = Enum.Font.Fantasy, -- títulos con estilo de fantasía
	Bold = Enum.Font.GothamBold,
	Black = Enum.Font.GothamBlack,
	Body = Enum.Font.Gotham,
}

-- Crea una instancia con propiedades y la mete en parent
function UI.create(className, props, parent)
	local instance = Instance.new(className)
	for key, value in props do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

function UI.round(parent, radius)
	return UI.create("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

function UI.padding(parent, pixels)
	return UI.create("UIPadding", {
		PaddingLeft = UDim.new(0, pixels),
		PaddingRight = UDim.new(0, pixels),
		PaddingTop = UDim.new(0, pixels),
		PaddingBottom = UDim.new(0, pixels),
	}, parent)
end

-- Convierte un frame en un panel del tema: degradado azul, borde cian que brilla
-- y una línea dorada arriba. Devuelve el borde para poder cambiarle el color.
function UI.theme(frame, radius, accent)
	accent = accent or UI.Colors.Accent
	frame.BackgroundColor3 = UI.Colors.White
	frame.BackgroundTransparency = 0.06
	UI.round(frame, radius or 12)
	UI.create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 44, 88)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(12, 24, 54)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 14, 34)),
		}),
		Rotation = 90,
	}, frame)
	local stroke = UI.create("UIStroke", {
		Color = accent,
		Thickness = 1.6,
		Transparency = 0.15,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, frame)
	-- El borde pasa de cian a dorado en las esquinas
	UI.create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, UI.Colors.Gold),
			ColorSequenceKeypoint.new(0.3, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.7, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, UI.Colors.Gold),
		}),
		Rotation = 30,
	}, stroke)
	return stroke
end

-- Panel nuevo ya con el tema
function UI.panel(parent, props, radius, accent)
	local frame = UI.create("Frame", {}, parent)
	local stroke = UI.theme(frame, radius, accent)
	for key, value in props do
		frame[key] = value
	end
	return frame, stroke
end

-- Título con decoración ◆ a los lados, estilo "ventana de estado"
function UI.header(parent, text, props)
	local settings = {
		BackgroundTransparency = 1,
		Font = UI.Fonts.Title,
		TextSize = 22,
		TextColor3 = UI.Colors.Gold,
		TextStrokeTransparency = 0.5,
		Text = "◆ " .. text .. " ◆",
	}
	for key, value in props or {} do
		settings[key] = value
	end
	return UI.create("TextLabel", settings, parent)
end

function UI.label(parent, props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = UI.Fonts.Body,
		TextSize = 16,
		TextColor3 = UI.Colors.White,
		TextWrapped = true,
	}
	for key, value in props do
		defaults[key] = value
	end
	return UI.create("TextLabel", defaults, parent)
end

-- Botón con degradado y borde
function UI.button(parent, text, color, props)
	local settings = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Font = UI.Fonts.Bold,
		TextSize = 18,
		TextColor3 = UI.Colors.White,
		TextStrokeTransparency = 0.6,
		Text = text,
		AutoButtonColor = true,
	}
	for key, value in props or {} do
		settings[key] = value
	end
	local button = UI.create("TextButton", settings, parent)
	UI.round(button, 10)
	local gradient = UI.create("UIGradient", {
		Name = "ButtonGradient",
		Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.15), color:Lerp(Color3.new(), 0.35)),
		Rotation = 90,
	}, button)
	UI.create("UIStroke", {
		Color = color:Lerp(Color3.new(1, 1, 1), 0.45),
		Thickness = 1.2,
		Transparency = 0.3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, button)
	-- Cambiar el color de un botón después de crearlo
	button:SetAttribute("ThemeColor", color)
	button:GetAttributeChangedSignal("ThemeColor"):Connect(function()
		local newColor = button:GetAttribute("ThemeColor")
		gradient.Color = ColorSequence.new(newColor:Lerp(Color3.new(1, 1, 1), 0.15), newColor:Lerp(Color3.new(), 0.35))
	end)
	return button
end

-- Cambia el color de un botón creado con UI.button
function UI.setButtonColor(button, color)
	button:SetAttribute("ThemeColor", color)
end

return UI
