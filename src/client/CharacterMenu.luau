-- Menú del personaje (tecla M): Inventario, Atributos (con gráfica hexagonal), Tienda y Ajustes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UI = require(script.Parent.UI)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local useItemRemote = remotes:WaitForChild("UseItem")
local allocateRemote = remotes:WaitForChild("AllocateStat")
local equipRemote = remotes:WaitForChild("Equip")
local saveSettingRemote = remotes:WaitForChild("SaveSetting")

local player = Players.LocalPlayer
local Colors = UI.Colors
local create = UI.create
local GOLD = Colors.Gold

local CharacterMenu = {}

local allowed = false -- solo se puede abrir mientras juegas
local currentTab = "Inventory"

local gui = create("ScreenGui", {
	Name = "CharacterMenu",
	ResetOnSpawn = false,
	DisplayOrder = 6,
	Enabled = false,
}, player:WaitForChild("PlayerGui"))

-- Botón para abrirlo (encima del contador de oro)
local openButton = UI.button(gui, "🎒  Personaje (M)", Colors.PanelLight, {
	AnchorPoint = Vector2.new(1, 1),
	Position = if UserInputService.TouchEnabled then UDim2.new(1, -150, 1, -76) else UDim2.new(1, -16, 1, -76),
	Size = UDim2.fromOffset(170, 40),
	TextSize = 15,
})

local window = UI.panel(gui, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.8, 0.82),
	Active = true, -- los clics sobre la ventana no cuentan como ataque
	Visible = false,
}, 16)
create("UISizeConstraint", { MinSize = Vector2.new(380, 300), MaxSize = Vector2.new(900, 580) }, window)

-- Cabecera
UI.header(window, "Estado del personaje", {
	Position = UDim2.fromOffset(18, 10),
	Size = UDim2.new(0.5, 0, 0, 32),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextSize = 24,
})
local goldLabel = UI.label(window, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -64, 0, 14),
	Size = UDim2.fromOffset(200, 26),
	Font = Enum.Font.GothamBlack,
	TextSize = 18,
	TextColor3 = GOLD,
	TextXAlignment = Enum.TextXAlignment.Right,
	Text = "",
})
local closeButton = UI.button(window, "✕", Colors.Red, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 12),
	Size = UDim2.fromOffset(36, 32),
	TextSize = 18,
})

-- Pestañas (izquierda)
local tabColumn = create("Frame", {
	Position = UDim2.fromOffset(14, 56),
	Size = UDim2.new(0, 150, 1, -70),
	BackgroundTransparency = 1,
}, window)
create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, tabColumn)

-- Contenido (derecha)
local contentArea = create("Frame", {
	Position = UDim2.fromOffset(176, 56),
	Size = UDim2.new(1, -190, 1, -70),
	BackgroundColor3 = Color3.fromRGB(4, 8, 20),
	BackgroundTransparency = 0.35,
}, window)
UI.round(contentArea, 12)
create("UIStroke", { Color = Colors.AccentDark, Thickness = 1, Transparency = 0.4 }, contentArea)

local TABS = {
	{ Id = "Inventory", Name = "🎒 Inventario" },
	{ Id = "Stats", Name = "📊 Atributos" },
	{ Id = "Shop", Name = "🛒 Tienda" },
	{ Id = "Settings", Name = "⚙️ Ajustes" },
}

local pages = {} -- [tabId] = ScrollingFrame
local tabButtons = {} -- [tabId] = TextButton

for order, tab in TABS do
	local page = create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Colors.Accent,
		Visible = false,
	}, contentArea)
	UI.padding(page, 12)
	pages[tab.Id] = page

	local button = UI.button(tabColumn, tab.Name, Colors.PanelLight, {
		Size = UDim2.new(1, 0, 0, 42),
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
	})
	create("UIPadding", { PaddingLeft = UDim.new(0, 12) }, button)
	tabButtons[tab.Id] = button
end

--------------------------------------------------------------------------------
-- Utilidades
--------------------------------------------------------------------------------

-- Borra el contenido de una página (menos su margen)
local function clear(container)
	for _, child in container:GetChildren() do
		if not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function parsePairs(text)
	local values = {}
	for key, value in string.gmatch(text or "", "(%w+)=(%d+)") do
		values[key] = tonumber(value)
	end
	return values
end

local function getSkills()
	local skills = {}
	for skillId in string.gmatch(player:GetAttribute("Skills") or "", "[^,]+") do
		skills[skillId] = true
	end
	return skills
end

local function getOwnedWeapons()
	local owned = {}
	for weaponId in string.gmatch(player:GetAttribute("Weapons") or "", "[^,]+") do
		owned[weaponId] = true
	end
	return owned
end

local function getRaceId()
	local raceId = player:GetAttribute("Race")
	return if raceId and Config.Races[raceId] then raceId else Config.DefaultRace
end

local function percent(value)
	return tostring(math.floor(value * 100 + 0.5)) .. "%"
end

local function hex(color)
	return "#" .. color:ToHex()
end

local feedbackToken = 0
local feedbackLabel = UI.label(window, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -2),
	Size = UDim2.new(1, -40, 0, 14),
	TextSize = 13,
	TextColor3 = Color3.fromRGB(255, 120, 120),
	Text = "",
})
local function feedback(text, color)
	feedbackToken += 1
	local token = feedbackToken
	feedbackLabel.Text = text
	feedbackLabel.TextColor3 = color or Color3.fromRGB(255, 120, 120)
	task.delay(2.5, function()
		if token == feedbackToken then
			feedbackLabel.Text = ""
		end
	end)
end

local function call(remote, ...)
	local ok, result = pcall(remote.InvokeServer, remote, ...)
	if not ok or not result or not result.Ok then
		feedback(if ok and result then result.Message else "Error")
		return false
	end
	return true
end

-- Tarjeta con fondo del tema (tamaño automático en Y si no se da alto)
local function card(parent, order, height)
	local frame = create("Frame", {
		Size = UDim2.new(1, 0, 0, height or 0),
		AutomaticSize = if height then Enum.AutomaticSize.None else Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(16, 30, 62),
		BackgroundTransparency = 0.15,
		LayoutOrder = order,
	}, parent)
	UI.round(frame, 10)
	create("UIStroke", { Color = Colors.AccentDark, Thickness = 1, Transparency = 0.35 }, frame)
	UI.padding(frame, 10)
	return frame
end

local function sectionTitle(parent, order, text)
	return UI.label(parent, {
		Size = UDim2.new(1, 0, 0, 22),
		Font = UI.Fonts.Title,
		TextSize = 17,
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
		Text = "◆ " .. text,
	})
end

local function list(parent, padding)
	return create(
		"UIListLayout",
		{ Padding = UDim.new(0, padding or 8), SortOrder = Enum.SortOrder.LayoutOrder },
		parent
	)
end

--------------------------------------------------------------------------------
-- Inventario: armas y objetos
--------------------------------------------------------------------------------

local function renderInventory()
	local page = pages.Inventory
	clear(page)
	list(page, 10)

	local race = Config.Races[getRaceId()]
	local owned = getOwnedWeapons()
	local equipped = player:GetAttribute("Equipped") or ""

	-- Armas
	sectionTitle(page, 1, "Armas")
	local weaponsBox = create("Frame", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
	}, page)
	list(weaponsBox, 6)
	local anyWeapon = false
	for order, weaponId in Config.WeaponOrder do
		if owned[weaponId] then
			anyWeapon = true
			local weapon = Config.Weapons[weaponId]
			local rarity = Config.Rarities[weapon.Rarity]
			local row = card(weaponsBox, order, 58)
			UI.label(row, {
				Size = UDim2.new(1, -120, 1, 0),
				TextSize = 13,
				RichText = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = string.format(
					'⚔️ <font color="%s"><b>%s</b> (%s)</font>\n<font color="%s">+%d daño · +%s vel. ataque%s</font>',
					hex(rarity.Color),
					weapon.Name,
					rarity.Name,
					hex(Colors.Muted),
					weapon.Damage,
					percent(weapon.AttackSpeed),
					if weapon.PassiveText then " · " .. weapon.PassiveText else ""
				),
			})
			local isEquipped = equipped == weaponId
			local button = UI.button(
				row,
				if isEquipped then "Quitar" else "Equipar",
				if isEquipped then Colors.PanelLight else Colors.Green,
				{
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.fromScale(1, 0.5),
					Size = UDim2.fromOffset(100, 34),
					TextSize = 14,
				}
			)
			button.Activated:Connect(function()
				call(equipRemote, if isEquipped then "" else weaponId)
			end)
		end
	end
	if not anyWeapon or race.CanAbsorb then
		UI.label(weaponsBox, {
			Size = UDim2.new(1, 0, 0, 34),
			TextSize = 13,
			TextColor3 = Colors.Muted,
			LayoutOrder = 99,
			Text = if race.CanAbsorb
				then "El Slime aún no tiene forma humana: todavía no puede usar armas."
				else "No tienes armas. Cómpralas en la Herrería de la zona segura.",
		})
	end

	-- Objetos
	sectionTitle(page, 3, "Objetos")
	local grid = create("Frame", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 4,
	}, page)
	create("UIGridLayout", {
		CellSize = UDim2.fromOffset(122, 140),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)

	local inventory = parsePairs(player:GetAttribute("Inventory"))
	local anyItem = false
	for order, itemId in Config.ItemOrder do
		local count = inventory[itemId] or 0
		if count > 0 then
			anyItem = true
			local item = Config.Items[itemId]
			local tile = create("Frame", {
				BackgroundColor3 = item.Color:Lerp(Color3.fromRGB(10, 18, 40), 0.75),
				LayoutOrder = order,
			}, grid)
			UI.round(tile, 12)
			create("UIStroke", { Color = item.Color, Thickness = 1.5, Transparency = 0.2 }, tile)
			UI.label(
				tile,
				{ Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 40), TextSize = 30, Text = item.Icon }
			)
			UI.label(tile, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -8, 0, 6),
				Size = UDim2.fromOffset(40, 20),
				Font = Enum.Font.GothamBlack,
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Right,
				Text = "×" .. count,
			})
			UI.label(tile, {
				Position = UDim2.fromOffset(6, 48),
				Size = UDim2.new(1, -12, 0, 34),
				Font = Enum.Font.GothamBold,
				TextSize = 13,
				Text = item.Name,
			})
			local useButton = UI.button(tile, "Usar", Colors.Green, {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -8),
				Size = UDim2.new(1, -16, 0, 32),
				TextSize = 14,
			})
			useButton.Activated:Connect(function()
				call(useItemRemote, itemId)
			end)
		end
	end
	if not anyItem then
		UI.label(page, {
			Size = UDim2.new(1, 0, 0, 40),
			TextSize = 13,
			TextColor3 = Colors.Muted,
			LayoutOrder = 5,
			Text = "No tienes objetos. Compra pociones en la tienda de Medicina de la zona segura.",
		})
	end
end

--------------------------------------------------------------------------------
-- Gráfica hexagonal de atributos
--------------------------------------------------------------------------------

local function line(parent, a, b, thickness, color, transparency, zIndex)
	local delta = b - a
	create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2),
		Size = UDim2.fromOffset(delta.Magnitude, thickness),
		Rotation = math.deg(math.atan2(delta.Y, delta.X)),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency or 0,
		BorderSizePixel = 0,
		ZIndex = zIndex or 1,
	}, parent)
end

local function dot(parent, at, size, color, zIndex)
	local frame = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(at.X, at.Y),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = zIndex or 3,
	}, parent)
	UI.round(frame, size // 2)
end

-- Dibuja la gráfica: hexágono de fondo, tus atributos (cian) y cómo quedarán al subir de nivel (dorado)
local function radarChart(parent, stats, nextStats, size)
	local chart = create("Frame", {
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
	}, parent)

	local center = Vector2.new(size / 2, size / 2)
	local radius = size / 2 - 44
	local count = #Config.Stats
	local function direction(index)
		local angle = math.rad(-90 + (index - 1) * 360 / count)
		return Vector2.new(math.cos(angle), math.sin(angle))
	end

	-- Escala: el atributo más alto (contando el próximo nivel) llega casi al borde
	local highest = 1
	for _, stat in Config.Stats do
		highest = math.max(highest, stats[stat.Id], nextStats[stat.Id])
	end
	local scale = highest * 1.08

	-- Fondo: 3 hexágonos y los ejes
	for ring = 1, 3 do
		local r = radius * ring / 3
		for index = 1, count do
			local nextIndex = index % count + 1
			line(chart, center + direction(index) * r, center + direction(nextIndex) * r, 1, Colors.Accent, 0.7)
		end
	end
	for index = 1, count do
		line(chart, center, center + direction(index) * radius, 1, Colors.Accent, 0.75)
	end

	local function polygon(values, color, thickness, transparency, fill)
		local points = {}
		for index, stat in Config.Stats do
			points[index] = center + direction(index) * radius * math.clamp(values[stat.Id] / scale, 0.04, 1)
		end
		for index = 1, count do
			local nextIndex = index % count + 1
			line(chart, points[index], points[nextIndex], thickness, color, transparency, 2)
			-- "Relleno": rayos semitransparentes desde el centro
			if fill then
				line(chart, center, points[index], 10, color, 0.82, 1)
			end
		end
		return points
	end

	polygon(nextStats, GOLD, 2, 0.35, false)
	local points = polygon(stats, Colors.Accent, 3, 0, true)
	for _, point in points do
		dot(chart, point, 8, Color3.fromRGB(200, 245, 255))
	end

	-- Nombres y valores en cada punta
	for index, stat in Config.Stats do
		local at = center + direction(index) * (radius + 16)
		UI.label(chart, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(at.X, at.Y),
			Size = UDim2.fromOffset(70, 30),
			TextSize = 11,
			RichText = true,
			ZIndex = 4,
			Text = string.format(
				'%s <b>%s</b>\n<font color="%s"><b>%d</b></font>',
				stat.Icon,
				stat.Name,
				hex(Colors.Accent),
				stats[stat.Id]
			),
		})
	end
	return chart
end

--------------------------------------------------------------------------------
-- Atributos
--------------------------------------------------------------------------------

local function renderStats()
	local page = pages.Stats
	clear(page)
	list(page, 10)

	local raceId = getRaceId()
	local race = Config.Races[raceId]
	local rarity = Config.Rarities[race.Rarity]
	local level = player:GetAttribute("Level") or 1
	local skills = getSkills()
	local weaponId = player:GetAttribute("Equipped") or ""
	if weaponId == "" or race.CanAbsorb then
		weaponId = nil
	end
	local stats = Config.DecodeStats(player:GetAttribute("Stats"))
	local freePoints = player:GetAttribute("StatPoints") or 0

	-- Cómo quedarán al subir 1 nivel (crecimiento de tu raza)
	local nextStats = {}
	for _, stat in Config.Stats do
		nextStats[stat.Id] = stats[stat.Id] + race.Growth[stat.Id]
	end

	-- Resumen
	UI.label(page, {
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 14,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
		Text = string.format(
			'<font color="%s"><b>%s</b></font> (%s) · Nivel <b>%d</b> · %s%s',
			hex(rarity.Color),
			race.Name,
			rarity.Name,
			level,
			player:GetAttribute("Form") or race.Name,
			if Config.GetAwakening(level) then " · " .. Config.GetAwakening(level).Name else ""
		),
	})

	-- Fila superior: gráfica + atributos con botón +
	local top = create("Frame", {
		Size = UDim2.new(1, 0, 0, 240),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
	}, page)
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, top)
	radarChart(top, stats, nextStats, 240)

	local statList = create("Frame", {
		Size = UDim2.new(1, -250, 1, 0),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
	}, top)
	list(statList, 4)
	UI.label(statList, {
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 13,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
		Text = string.format(
			'Puntos libres: <font color="%s"><b>%d</b></font>   <font color="%s">— actual  <font color="%s">— próximo nivel</font></font>',
			hex(GOLD),
			freePoints,
			hex(Colors.Accent),
			hex(GOLD)
		),
	})
	for index, stat in Config.Stats do
		local row = create("Frame", {
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundColor3 = Color3.fromRGB(14, 26, 54),
			BackgroundTransparency = 0.1,
			LayoutOrder = index,
		}, statList)
		UI.round(row, 8)
		UI.label(row, {
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(1, -110, 1, 0),
			TextSize = 13,
			RichText = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = string.format(
				'%s <b>%s</b> <font color="%s">+%d/nv</font>',
				stat.Icon,
				stat.Name,
				hex(Colors.Muted),
				race.Growth[stat.Id]
			),
		})
		UI.label(row, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -44, 0, 0),
			Size = UDim2.new(0, 56, 1, 0),
			Font = Enum.Font.GothamBlack,
			TextSize = 17,
			TextColor3 = Colors.Accent,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = tostring(stats[stat.Id]),
		})
		local plus = UI.button(row, "+", if freePoints > 0 then Colors.Green else Colors.PanelLight, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -4, 0.5, 0),
			Size = UDim2.fromOffset(32, 26),
			TextSize = 18,
		})
		plus.Activated:Connect(function()
			if freePoints > 0 then
				call(allocateRemote, stat.Id)
			end
		end)
	end

	-- Combate: rejilla compacta de 2 columnas
	sectionTitle(page, 3, "Combate")
	local grid = create("Frame", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 4,
	}, page)
	create("UIGridLayout", {
		CellSize = UDim2.new(0.5, -4, 0, 26),
		CellPadding = UDim2.fromOffset(8, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	local speed = Config.WalkSpeed(stats, raceId)
	local combatValues = {
		{ "❤️ Vida", tostring(Config.MaxHealth(stats, raceId, skills)) },
		{ "🔮 Maná", tostring(Config.MaxMana(stats, raceId)) },
		{ "💨 Stamina", tostring(Config.MaxStamina(stats, raceId)) },
		{ "⚔️ Daño (clic)", tostring(Config.AttackDamage(stats, raceId, level, skills, weaponId)) },
		{ "⏱️ Golpes/seg", string.format("%.1f", 1 / Config.AttackCooldown(weaponId)) },
		{ "📏 Alcance", string.format("%.1f", Config.AttackRange(level, raceId)) },
		{ "👟 Velocidad", string.format("%.1f (correr x%.2f)", speed, race.Stamina.SpeedMult) },
		{ "🛡️ Res. física", percent(Config.PhysicalResist(stats, raceId)) },
		{ "✨ Res. mágica", percent(Config.MagicResist(stats, raceId)) },
		{ "🪙 Oro / XP", "x" .. race.GoldMult .. " / +" .. percent(race.XPMult - 1) },
	}
	for order, value in combatValues do
		local cell = create("Frame", {
			BackgroundColor3 = Color3.fromRGB(14, 26, 54),
			BackgroundTransparency = 0.1,
			LayoutOrder = order,
		}, grid)
		UI.round(cell, 6)
		UI.label(cell, {
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(1, -16, 1, 0),
			TextSize = 13,
			RichText = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = value[1] .. '  <b><font color="' .. hex(Colors.Accent) .. '">' .. value[2] .. "</font></b>",
		})
	end

	-- Habilidades: activas con daño, maná y recarga; pasivas; y las que faltan
	sectionTitle(page, 5, "Habilidades")
	local skillBox = create("Frame", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 6,
	}, page)
	list(skillBox, 4)
	local skillOrder = 0
	local function skillRow(text, locked)
		skillOrder += 1
		local row = create("Frame", {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = if locked then Color3.fromRGB(12, 16, 30) else Color3.fromRGB(14, 26, 54),
			BackgroundTransparency = 0.1,
			LayoutOrder = skillOrder,
		}, skillBox)
		UI.round(row, 6)
		create("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 5),
			PaddingBottom = UDim.new(0, 5),
		}, row)
		UI.label(row, {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextSize = 13,
			RichText = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if locked then Colors.Muted else Colors.White,
			Text = text,
		})
	end

	local abilityIds = {}
	for abilityId in Config.Abilities do
		table.insert(abilityIds, abilityId)
	end
	table.sort(abilityIds)
	for _, abilityId in abilityIds do
		if Config.CanUseAbility(raceId, skills, abilityId) then
			local ability = Config.Abilities[abilityId]
			skillRow(
				string.format(
					'%s <b>%s</b> [%s]  <font color="%s">%d daño · %d MP · %ss</font>\n<font color="%s">%s</font>',
					ability.Icon,
					ability.DisplayName,
					ability.Key,
					hex(Colors.Accent),
					Config.AbilityDamage(stats, raceId, abilityId),
					ability.ManaCost,
					tostring(ability.Cooldown),
					hex(Colors.Muted),
					ability.Description
				)
			)
		end
	end
	if race.CanAbsorb then
		local absorbed = parsePairs(player:GetAttribute("Absorbed"))
		local tier = Config.GetAbsorbTier(level)
		skillRow(
			string.format(
				'🌀 <b><font color="#FF78B4">%s</font></b>%s [F]\n<font color="%s">%s</font>',
				tier.Name,
				if tier.Unique then " (Habilidad Única)" else "",
				hex(Colors.Muted),
				tier.Description
			)
		)
		for _, skillId in Config.SkillOrder do
			local skill = Config.Skills[skillId]
			if not skill.Ability then
				local have = skills[skillId] == true
				skillRow(
					string.format(
						"%s <b>%s</b>  %s",
						if have then "✅" else "🔒",
						skill.DisplayName,
						if have
							then skill.Description
							else string.format(
								"(absorbe %d %s: %d/%d)",
								skill.Required,
								Config.Monsters[skill.From].DisplayName,
								math.min(absorbed[skill.From] or 0, skill.Required),
								skill.Required
							)
					),
					not have
				)
			elseif not skills[skillId] then
				skillRow(
					string.format(
						"🔒 <b>%s</b>  (absorbe %d %s: %d/%d)",
						skill.DisplayName,
						skill.Required,
						Config.Monsters[skill.From].DisplayName,
						math.min(absorbed[skill.From] or 0, skill.Required),
						skill.Required
					),
					true
				)
			end
		end
	else
		for _, trait in race.Traits do
			skillRow("◇ " .. trait)
		end
	end

	-- Progresión por nivel: qué se desbloquea y cuándo
	sectionTitle(page, 7, "Progresión por nivel")
	local milestones = {}
	if race.CanAbsorb then
		for index, form in Config.Forms do
			if index > 1 then
				table.insert(milestones, { form.MinLevel, "Evolución: " .. form.Name })
			end
		end
		for index, tier in Config.AbsorbTiers do
			if index > 1 then
				table.insert(
					milestones,
					{ tier.MinLevel, "Absorción: " .. tier.Name .. (if tier.Unique then " (Única)" else "") }
				)
			end
		end
	end
	for _, awakening in Config.Awakenings do
		table.insert(
			milestones,
			{ awakening.Level, awakening.Name .. ": +" .. percent(awakening.Bonus) .. " a todos los atributos" }
		)
	end
	table.sort(milestones, function(a, b)
		return a[1] < b[1]
	end)
	local progress = create("Frame", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 8,
	}, page)
	list(progress, 3)
	for order, milestone in milestones do
		local reached = level >= milestone[1]
		UI.label(progress, {
			Size = UDim2.new(1, 0, 0, 20),
			TextSize = 13,
			RichText = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if reached then Colors.White else Colors.Muted,
			LayoutOrder = order,
			Text = string.format(
				'%s <font color="%s"><b>Nv. %d</b></font>  %s',
				if reached then "✅" else "🔒",
				hex(GOLD),
				milestone[1],
				milestone[2]
			),
		})
	end
end

--------------------------------------------------------------------------------
-- Tienda (de momento, las compras se hacen en las tiendas de la zona segura)
--------------------------------------------------------------------------------

local function renderShop()
	local page = pages.Shop
	clear(page)
	list(page, 12)
	UI.header(page, "Próximamente...", {
		Size = UDim2.new(1, 0, 0, 60),
		TextSize = 32,
		LayoutOrder = 1,
	})
	UI.label(page, {
		Size = UDim2.new(1, 0, 0, 60),
		TextSize = 15,
		TextColor3 = Colors.Muted,
		LayoutOrder = 2,
		Text = "Mientras tanto, visita la ⚗️ Medicina y la ⚒️ Herrería en la zona segura.",
	})
end

--------------------------------------------------------------------------------
-- Ajustes
--------------------------------------------------------------------------------

local function renderSettings()
	local page = pages.Settings
	clear(page)
	list(page, 8)

	for order, setting in Config.Settings do
		local row = card(page, order, 64)
		UI.label(row, {
			Size = UDim2.new(1, -90, 1, 0),
			TextSize = 14,
			RichText = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = string.format(
				'<b>%s</b>\n<font color="%s">%s</font>',
				setting.Name,
				hex(Colors.Muted),
				setting.Description
			),
		})

		local enabled = player:GetAttribute("Setting" .. setting.Id) ~= false
		local toggle =
			UI.button(row, if enabled then "ON" else "OFF", if enabled then Colors.Green else Colors.PanelLight, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(74, 36),
				TextSize = 15,
			})
		toggle.Activated:Connect(function()
			saveSettingRemote:FireServer(setting.Id, not enabled)
		end)
	end

	UI.label(page, {
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = 13,
		TextColor3 = Colors.Muted,
		LayoutOrder = 100,
		Text = "Controles: Clic atacar · E/R habilidades · F absorber · Q embestir · Shift correr · T hablar · M este menú",
	})
end

--------------------------------------------------------------------------------
-- Abrir, cerrar y cambiar de pestaña
--------------------------------------------------------------------------------

local renderers = {
	Inventory = renderInventory,
	Stats = renderStats,
	Shop = renderShop,
	Settings = renderSettings,
}

local function render()
	goldLabel.Text = "💰 " .. tostring(player:GetAttribute("Gold") or 0) .. " oro"
	for id, page in pages do
		page.Visible = id == currentTab
		UI.setButtonColor(tabButtons[id], if id == currentTab then Colors.AccentDark else Colors.PanelLight)
	end
	renderers[currentTab]()
end

local function setOpen(open)
	window.Visible = open and allowed
	if window.Visible then
		render()
	end
end

for id, button in tabButtons do
	button.Activated:Connect(function()
		currentTab = id
		render()
	end)
end

openButton.Activated:Connect(function()
	setOpen(not window.Visible)
end)
closeButton.Activated:Connect(function()
	setOpen(false)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not allowed then
		return
	end
	if input.KeyCode == Enum.KeyCode.M then
		setOpen(not window.Visible)
	end
end)

-- Volver a dibujar si cambian tus datos mientras el menú está abierto
local WATCHED = {
	Inventory = true,
	Gold = true,
	Level = true,
	Race = true,
	Form = true,
	Skills = true,
	Stats = true,
	StatPoints = true,
	Absorbed = true,
	AbsorbTier = true,
	Weapons = true,
	Equipped = true,
}
local pendingRender = false
player.AttributeChanged:Connect(function(name)
	if window.Visible and (WATCHED[name] or string.sub(name, 1, 7) == "Setting") and not pendingRender then
		-- Varios atributos cambian a la vez: redibujar una sola vez
		pendingRender = true
		task.defer(function()
			pendingRender = false
			if window.Visible then
				render()
			end
		end)
	end
end)

--------------------------------------------------------------------------------
-- Aplicar los ajustes visuales (números de daño y barras de vida)
--------------------------------------------------------------------------------

local function settingOn(id)
	return player:GetAttribute("Setting" .. id) ~= false
end

task.spawn(function()
	local effects = Workspace:WaitForChild("Effects")
	effects.ChildAdded:Connect(function(child)
		if child:IsA("BillboardGui") then
			child.Enabled = settingOn("DamageNumbers")
		end
	end)
end)

task.spawn(function()
	local monsters = Workspace:WaitForChild("Monsters")
	local function apply(billboard)
		billboard.Enabled = settingOn("MonsterBars")
	end
	monsters.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BillboardGui") and descendant.Name == "HealthBar" then
			apply(descendant)
		end
	end)
	player:GetAttributeChangedSignal("SettingMonsterBars"):Connect(function()
		for _, descendant in monsters:GetDescendants() do
			if descendant:IsA("BillboardGui") and descendant.Name == "HealthBar" then
				apply(descendant)
			end
		end
	end)
end)

--------------------------------------------------------------------------------
-- API
--------------------------------------------------------------------------------

-- Solo se puede usar mientras juegas (no en el menú de slots)
function CharacterMenu.SetAllowed(isAllowed)
	allowed = isAllowed
	gui.Enabled = isAllowed
	if not isAllowed then
		setOpen(false)
	end
end

return CharacterMenu
