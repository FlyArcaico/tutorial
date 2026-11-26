-- Menú del personaje (tecla M): Inventario, Stats, Tienda y Ajustes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UI = require(script.Parent.UI)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local buyRemote = remotes:WaitForChild("Buy")
local useItemRemote = remotes:WaitForChild("UseItem")
local allocateRemote = remotes:WaitForChild("AllocateStat")
local saveSettingRemote = remotes:WaitForChild("SaveSetting")

local player = Players.LocalPlayer
local Colors = UI.Colors
local create = UI.create
local GOLD = Color3.fromRGB(255, 205, 70)

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
local openButton = UI.button(gui, "🎒  Personaje (M)", Color3.fromRGB(45, 48, 75), {
	AnchorPoint = Vector2.new(1, 1),
	Position = if UserInputService.TouchEnabled then UDim2.new(1, -150, 1, -76) else UDim2.new(1, -16, 1, -76),
	Size = UDim2.fromOffset(170, 40),
	TextSize = 15,
})
create("UIStroke", { Color = Color3.fromRGB(85, 95, 140), Thickness = 1.5 }, openButton)

local window = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.72, 0.74),
	BackgroundColor3 = Colors.White,
	Active = true, -- los clics sobre la ventana no cuentan como ataque
	Visible = false,
}, gui)
create("UISizeConstraint", { MinSize = Vector2.new(360, 280), MaxSize = Vector2.new(780, 520) }, window)
UI.round(window, 16)
create("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(42, 45, 75), Color3.fromRGB(16, 18, 30)),
	Rotation = 90,
}, window)
create("UIStroke", { Color = Colors.Accent, Thickness = 2 }, window)

-- Cabecera
UI.label(window, {
	Position = UDim2.fromOffset(18, 12),
	Size = UDim2.new(0.5, 0, 0, 30),
	Font = Enum.Font.GothamBlack,
	TextSize = 22,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "🎒 Tu personaje",
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
	Size = UDim2.new(0, 140, 1, -70),
	BackgroundTransparency = 1,
}, window)
create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, tabColumn)

-- Contenido (derecha)
local contentArea = create("Frame", {
	Position = UDim2.fromOffset(166, 56),
	Size = UDim2.new(1, -180, 1, -70),
	BackgroundColor3 = Color3.fromRGB(14, 15, 26),
	BackgroundTransparency = 0.3,
}, window)
UI.round(contentArea, 12)

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

local function getInventory()
	local inventory = {}
	for itemId, count in string.gmatch(player:GetAttribute("Inventory") or "", "(%w+)=(%d+)") do
		inventory[itemId] = tonumber(count)
	end
	return inventory
end

local function getSkills()
	local skills = {}
	for skillId in string.gmatch(player:GetAttribute("Skills") or "", "[^,]+") do
		skills[skillId] = true
	end
	return skills
end

local function getRaceId()
	local raceId = player:GetAttribute("Race")
	return if raceId and Config.Races[raceId] then raceId else Config.DefaultRace
end

local feedbackToken = 0
local feedbackLabel = UI.label(window, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -4),
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

local function card(parent, order, height)
	local frame = create("Frame", {
		Size = UDim2.new(1, 0, 0, height or 0),
		AutomaticSize = if height then Enum.AutomaticSize.None else Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(38, 40, 66),
		LayoutOrder = order,
	}, parent)
	UI.round(frame, 10)
	UI.padding(frame, 10)
	return frame
end

--------------------------------------------------------------------------------
-- Inventario
--------------------------------------------------------------------------------

local function renderInventory()
	local page = pages.Inventory
	clear(page)
	create("UIGridLayout", {
		CellSize = UDim2.fromOffset(130, 150),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, page)

	local inventory = getInventory()
	local any = false
	for order, itemId in Config.ItemOrder do
		local count = inventory[itemId] or 0
		if count > 0 then
			any = true
			local item = Config.Items[itemId]
			local tile = create("Frame", {
				BackgroundColor3 = item.Color:Lerp(Color3.fromRGB(20, 20, 35), 0.7),
				LayoutOrder = order,
			}, page)
			UI.round(tile, 12)
			create("UIStroke", { Color = item.Color, Thickness = 1.5 }, tile)

			UI.label(
				tile,
				{ Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 44), TextSize = 34, Text = item.Icon }
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
				Position = UDim2.fromOffset(6, 52),
				Size = UDim2.new(1, -12, 0, 36),
				Font = Enum.Font.GothamBold,
				TextSize = 13,
				Text = item.Name,
			})
			local useButton = UI.button(tile, "Usar", Colors.Green, {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -8),
				Size = UDim2.new(1, -16, 0, 34),
				TextSize = 15,
			})
			useButton.Activated:Connect(function()
				call(useItemRemote, itemId)
			end)
		end
	end

	if not any then
		page:FindFirstChildOfClass("UIGridLayout"):Destroy()
		UI.label(page, {
			Size = UDim2.new(1, 0, 0, 60),
			TextSize = 16,
			TextColor3 = Colors.Muted,
			Text = "Tu inventario está vacío.\nCompra objetos en la Tienda con el oro que ganas.",
		})
	end
end

--------------------------------------------------------------------------------
-- Stats
--------------------------------------------------------------------------------

local function percent(value)
	return tostring(math.floor(value * 100 + 0.5)) .. "%"
end

local function renderStats()
	local page = pages.Stats
	clear(page)
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, page)

	local raceId = getRaceId()
	local race = Config.Races[raceId]
	local rarity = Config.Rarities[race.Rarity]
	local level = player:GetAttribute("Level") or 1
	local skills = getSkills()
	local order = 0

	local function section(title, rows)
		order += 1
		local box = card(page, order)
		local lines = { '<font color="#' .. Colors.Accent:ToHex() .. '"><b>' .. title .. "</b></font>" }
		for _, row in rows do
			table.insert(lines, row[1] .. ":  <b>" .. row[2] .. "</b>")
		end
		UI.label(box, {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextSize = 15,
			RichText = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LineHeight = 1.15,
			Text = table.concat(lines, "\n"),
		})
	end

	local stats = Config.DecodeStats(player:GetAttribute("Stats"))
	local freePoints = player:GetAttribute("StatPoints") or 0

	section("PERSONAJE", {
		{ "Raza", '<font color="#' .. rarity.Color:ToHex() .. '">' .. race.Name .. " (" .. rarity.Name .. ")</font>" },
		{ "Nivel", tostring(level) },
		{ "Forma", player:GetAttribute("Form") or race.Name },
		{ "Despertar", if Config.GetAwakening(level) then Config.GetAwakening(level).Name else "Ninguno (nivel 20)" },
	})

	-- Atributos con botón + para repartir puntos libres
	order += 1
	local statsBox = card(page, order)
	create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, statsBox)
	UI.label(statsBox, {
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 15,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
		Text = string.format(
			'<font color="#%s"><b>ATRIBUTOS</b></font>   Puntos libres: <font color="#%s"><b>%d</b></font>',
			Colors.Accent:ToHex(),
			GOLD:ToHex(),
			freePoints
		),
	})
	for index, stat in Config.Stats do
		local growth = race.Growth[stat.Id]
		local row = create("Frame", {
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundColor3 = Color3.fromRGB(28, 30, 50),
			LayoutOrder = index,
		}, statsBox)
		UI.round(row, 8)
		UI.label(row, {
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, -120, 1, 0),
			TextSize = 14,
			RichText = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = string.format(
				'%s <b>%s</b>  <font color="#%s">%s · +%d por nivel</font>',
				stat.Icon,
				stat.Name,
				Colors.Muted:ToHex(),
				stat.Description,
				growth
			),
		})
		UI.label(row, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -50, 0, 0),
			Size = UDim2.new(0, 60, 1, 0),
			Font = Enum.Font.GothamBlack,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = tostring(stats[stat.Id]),
		})
		local plus = UI.button(row, "+", if freePoints > 0 then Colors.Green else Colors.PanelLight, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -4, 0.5, 0),
			Size = UDim2.fromOffset(36, 28),
			TextSize = 20,
		})
		plus.Activated:Connect(function()
			if freePoints > 0 then
				call(allocateRemote, stat.Id)
			end
		end)
	end

	local combat = {
		{ "Vida máxima", tostring(Config.MaxHealth(stats, raceId, skills)) },
		{ "Maná máximo", tostring(Config.MaxMana(stats, raceId)) },
		{ "Stamina", tostring(Config.MaxStamina(stats, raceId)) },
		{ "Daño (clic)", tostring(Config.AttackDamage(stats, raceId, level, skills)) },
		{ "Alcance (clic)", string.format("%.1f studs", Config.AttackRange(level, raceId)) },
	}
	for abilityId, ability in Config.Abilities do
		if Config.CanUseAbility(raceId, skills, abilityId) then
			table.insert(combat, {
				ability.Icon .. " " .. ability.DisplayName,
				Config.AbilityDamage(stats, raceId, abilityId) .. " daño · " .. ability.ManaCost .. " MP",
			})
		end
	end
	section("COMBATE", combat)

	local speed = Config.WalkSpeed(stats, raceId)
	section("MOVIMIENTO", {
		{ "Velocidad", string.format("%.1f", speed) },
		{ "Corriendo", string.format("%.1f (x%.2f)", speed * race.Stamina.SpeedMult, race.Stamina.SpeedMult) },
		{
			"Stamina por segundo",
			string.format("-%d al correr / +%d al descansar", race.Stamina.Drain, race.Stamina.Regen),
		},
	})

	section("DEFENSA", {
		{ "Resistencia física", percent(Config.PhysicalResist(stats, raceId)) },
		{ "Resistencia mágica", percent(Config.MagicResist(stats, raceId)) },
	})

	-- Slime: nivel de absorción y habilidades robadas
	if race.CanAbsorb then
		local tier = Config.GetAbsorbTier(level)
		local absorbed = {}
		for monsterId, count in string.gmatch(player:GetAttribute("Absorbed") or "", "(%w+)=(%d+)") do
			absorbed[monsterId] = tonumber(count)
		end
		local rows = {
			{
				"Habilidad",
				'<font color="#FF78B4">' .. tier.Name .. (if tier.Unique then " (Única)" else "") .. "</font>",
			},
			{ "Efecto", tier.Description },
		}
		for _, nextTier in Config.AbsorbTiers do
			if nextTier.MinLevel > level then
				table.insert(rows, { "Siguiente", nextTier.Name .. " a nivel " .. nextTier.MinLevel })
				break
			end
		end
		for monsterId, def in Config.Monsters do
			local bonus = {}
			for statId, amount in def.AbsorbStats do
				for _, stat in Config.Stats do
					if stat.Id == statId then
						table.insert(bonus, "+" .. amount * tier.StatMult .. " " .. stat.Name)
					end
				end
			end
			table.insert(rows, {
				def.DisplayName .. " absorbidos",
				(absorbed[monsterId] or 0) .. "  (" .. table.concat(bonus, ", ") .. " cada uno)",
			})
		end
		section("ABSORCIÓN", rows)

		local skillRows = {}
		for _, skillId in Config.SkillOrder do
			local skill = Config.Skills[skillId]
			local have = skills[skillId] == true
			table.insert(skillRows, {
				(if have then "✅ " else "🔒 ") .. skill.DisplayName,
				if have
					then skill.Description
					else string.format(
						"Absorbe %d %s (%d/%d)",
						skill.Required,
						Config.Monsters[skill.From].DisplayName,
						math.min(absorbed[skill.From] or 0, skill.Required),
						skill.Required
					),
			})
		end
		section("HABILIDADES ROBADAS", skillRows)
	end

	local extras = {
		{ "Daño mágico", "+" .. percent(race.MagicDamageMult - 1) },
		{ "XP extra", "+" .. percent(race.XPMult - 1) },
		{ "Oro por monstruo", "x" .. race.GoldMult },
	}
	if race.CanAbsorb then
		table.insert(extras, { "Prob. absorber (monstruo de tu nivel)", percent(Config.AbsorbChance(level, level)) })
		table.insert(extras, { "Regeneración fuera de combate", percent(race.HealthRegen) .. " vida/s" })
	end
	if race.Berserk then
		table.insert(extras, {
			"Berserker (vida < " .. percent(race.Berserk.Threshold) .. ")",
			"+"
				.. percent(race.Berserk.DamageMult - 1)
				.. " daño, +"
				.. percent(race.Berserk.SpeedMult - 1)
				.. " velocidad",
		})
	end
	section("EXTRA", extras)
end

--------------------------------------------------------------------------------
-- Tienda
--------------------------------------------------------------------------------

local function renderShop()
	local page = pages.Shop
	clear(page)
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, page)

	local gold = player:GetAttribute("Gold") or 0
	local inventory = getInventory()
	for order, itemId in Config.ItemOrder do
		local item = Config.Items[itemId]
		local row = card(page, order, 78)
		create("UIStroke", { Color = item.Color, Thickness = 1, Transparency = 0.5 }, row)

		UI.label(row, { Size = UDim2.fromOffset(50, 58), TextSize = 32, Text = item.Icon })
		UI.label(row, {
			Position = UDim2.fromOffset(58, 0),
			Size = UDim2.new(1, -250, 1, 0),
			TextSize = 13,
			RichText = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = string.format(
				'<b>%s</b>  <font color="#%s">(tienes %d)</font>\n<font color="#%s">%s</font>',
				item.Name,
				Colors.Muted:ToHex(),
				inventory[itemId] or 0,
				Colors.Muted:ToHex(),
				item.Description
			),
		})

		local canBuy = gold >= item.Price
		local buyOne =
			UI.button(row, "💰 " .. item.Price, if canBuy then GOLD:Lerp(Color3.new(), 0.3) else Colors.PanelLight, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -68, 0.5, 0),
				Size = UDim2.fromOffset(100, 40),
				TextSize = 15,
			})
		buyOne.Activated:Connect(function()
			call(buyRemote, itemId, 1)
		end)

		local canBuyFive = gold >= item.Price * 5
		local buyFive = UI.button(row, "×5", if canBuyFive then GOLD:Lerp(Color3.new(), 0.45) else Colors.PanelLight, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(60, 40),
			TextSize = 15,
		})
		buyFive.Activated:Connect(function()
			call(buyRemote, itemId, 5)
		end)
	end
end

--------------------------------------------------------------------------------
-- Ajustes
--------------------------------------------------------------------------------

local function renderSettings()
	local page = pages.Settings
	clear(page)
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, page)

	for order, setting in Config.Settings do
		local row = card(page, order, 64)
		UI.label(row, {
			Size = UDim2.new(1, -90, 1, 0),
			TextSize = 14,
			RichText = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = string.format(
				'<b>%s</b>\n<font color="#%s">%s</font>',
				setting.Name,
				Colors.Muted:ToHex(),
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
		Text = "Controles: Clic atacar · E habilidad · F absorber · Q embestir · Shift correr · T hablar · M este menú",
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
		tabButtons[id].BackgroundColor3 = if id == currentTab
			then Colors.Accent:Lerp(Color3.new(), 0.3)
			else Colors.PanelLight
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
}
player.AttributeChanged:Connect(function(name)
	if window.Visible and (WATCHED[name] or string.sub(name, 1, 7) == "Setting") then
		render()
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
