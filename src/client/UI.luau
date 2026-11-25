-- Pequeñas utilidades para crear interfaz con código.
local UI = {}

UI.Colors = {
	Dark = Color3.fromRGB(20, 22, 35),
	Panel = Color3.fromRGB(32, 35, 55),
	PanelLight = Color3.fromRGB(45, 48, 72),
	White = Color3.new(1, 1, 1),
	Muted = Color3.fromRGB(170, 175, 195),
	Accent = Color3.fromRGB(90, 170, 255),
	Green = Color3.fromRGB(70, 190, 110),
	Red = Color3.fromRGB(220, 80, 80),
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

function UI.label(parent, props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 16,
		TextColor3 = UI.Colors.White,
		TextWrapped = true,
	}
	for key, value in props do
		defaults[key] = value
	end
	return UI.create("TextLabel", defaults, parent)
end

function UI.button(parent, text, color, props)
	local settings = {
		BackgroundColor3 = color,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = UI.Colors.White,
		Text = text,
		AutoButtonColor = true,
	}
	for key, value in props or {} do
		settings[key] = value
	end
	local button = UI.create("TextButton", settings, parent)
	UI.round(button, 10)
	return button
end

return UI
