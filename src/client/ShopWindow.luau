-- Ventana de las tiendas de la zona segura (Medicina y Herrería). Se abre pulsando T junto al NPC.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UI = require(script.Parent.UI)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local buyRemote = remotes:WaitForChild("Buy")
local buyWeaponRemote = remotes:WaitForChild("BuyWeapon")
local equipRemote = remotes:WaitForChild("Equip")

local player = Players.LocalPlayer
local Colors = UI.Colors
local create = UI.create

local ShopWindow = {}

local currentShop = nil -- id de la tienda abierta

local gui = create("ScreenGui", {
	Name = "ShopWindow",
	ResetOnSpawn = false,
	DisplayOrder = 7,
	Enabled = false,
}, player:WaitForChild("PlayerGui"))

local window, windowStroke = UI.panel(gui, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.7, 0.78),
	Active = true,
}, 16)
create("UISizeConstraint", { MinSize = Vector2.new(360, 300), MaxSize = Vector2.new(760, 560) }, window)

local titleLabel = UI.header(window, "", {
	Position = UDim2.fromOffset(18, 10),
	Size = UDim2.new(1, -80, 0, 32),
	TextSize = 26,
	TextXAlignment = Enum.TextXAlignment.Left,
})
local greetingLabel = UI.label(window, {
	Position = UDim2.fromOffset(18, 44),
	Size = UDim2.new(1, -36, 0, 36),
	TextSize = 14,
	RichText = true,
	TextColor3 = Colors.Muted,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "",
})
local goldLabel = UI.label(window, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -60, 0, 14),
	Size = UDim2.fromOffset(160, 26),
	Font = Enum.Font.GothamBlack,
	TextSize = 18,
	TextColor3 = Colors.Gold,
	TextXAlignment = Enum.TextXAlignment.Right,
	Text = "",
})
local closeButton = UI.button(window, "✕", Colors.Red, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 12),
	Size = UDim2.fromOffset(36, 32),
	TextSize = 18,
})

local listFrame = create("ScrollingFrame", {
	Position = UDim2.fromOffset(14, 86),
	Size = UDim2.new(1, -28, 1, -112),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = Colors.Accent,
}, window)

local feedbackLabel = UI.label(window, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -6),
	Size = UDim2.new(1, -40, 0, 16),
	TextSize = 14,
	TextColor3 = Color3.fromRGB(255, 120, 120),
	Text = "",
})

local feedbackToken = 0
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
	feedback("¡Gracias por tu compra!", Color3.fromRGB(130, 230, 150))
	return true
end

local function hex(color)
	return "#" .. color:ToHex()
end

local function clear()
	for _, child in listFrame:GetChildren() do
		child:Destroy()
	end
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, listFrame)
end

local function row(order, height, accent)
	local frame = create("Frame", {
		Size = UDim2.new(1, -8, 0, height),
		BackgroundColor3 = Color3.fromRGB(14, 26, 54),
		BackgroundTransparency = 0.1,
		LayoutOrder = order,
	}, listFrame)
	UI.round(frame, 10)
	create("UIStroke", { Color = accent, Thickness = 1.3, Transparency = 0.35 }, frame)
	return frame
end

-- Dibujito de la espada con frames (cuanto más rara, más detalles)
local function swordIcon(parent, look)
	local icon = create("Frame", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(80, 80),
		BackgroundColor3 = Color3.fromRGB(6, 12, 28),
	}, parent)
	UI.round(icon, 10)
	local holder = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(16, 76),
		BackgroundTransparency = 1,
		Rotation = 45,
	}, icon)
	local bladeLength = math.floor(look.Length * 11)
	local function bar(name, size, y, color)
		local frame = create("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, y),
			Size = size,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
		}, holder)
		return frame
	end
	bar("Blade", UDim2.fromOffset(8, bladeLength), 0, look.Blade)
	if look.Glow then
		bar("Edge", UDim2.fromOffset(2, bladeLength - 4), 2, look.Gem or Color3.new(1, 1, 1))
	end
	bar("Guard", UDim2.fromOffset(if look.Wings then 26 else 20, 4), bladeLength, look.Guard)
	bar("Grip", UDim2.fromOffset(5, 14), bladeLength + 4, look.Handle)
	local pommel = bar("Pommel", UDim2.fromOffset(7, 7), bladeLength + 18, look.Guard)
	UI.round(pommel, 4)
	if look.Gem then
		local gem = bar("Gem", UDim2.fromOffset(6, 6), bladeLength - 1, look.Gem)
		UI.round(gem, 3)
	end
	return icon
end

--------------------------------------------------------------------------------
-- Dibujar cada tienda
--------------------------------------------------------------------------------

local function renderMedicine(shop)
	local inventory = {}
	for itemId, count in string.gmatch(player:GetAttribute("Inventory") or "", "(%w+)=(%d+)") do
		inventory[itemId] = tonumber(count)
	end
	local gold = player:GetAttribute("Gold") or 0

	for order, itemId in shop.Items do
		local item = Config.Items[itemId]
		local frame = row(order, 72, item.Color)
		UI.label(
			frame,
			{ Position = UDim2.fromOffset(6, 0), Size = UDim2.fromOffset(56, 72), TextSize = 34, Text = item.Icon }
		)
		UI.label(frame, {
			Position = UDim2.fromOffset(66, 0),
			Size = UDim2.new(1, -250, 1, 0),
			TextSize = 13,
			RichText = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = string.format(
				'<font color="%s"><b>%s</b></font>  <font color="%s">(tienes %d)</font>\n<font color="%s">%s</font>',
				hex(item.Color:Lerp(Color3.new(1, 1, 1), 0.3)),
				item.Name,
				hex(Colors.Muted),
				inventory[itemId] or 0,
				hex(Colors.Muted),
				item.Description
			),
		})
		local buyOne = UI.button(
			frame,
			"💰 " .. item.Price,
			if gold >= item.Price then Colors.Gold:Lerp(Color3.new(), 0.35) else Colors.PanelLight,
			{
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -78, 0.5, 0),
				Size = UDim2.fromOffset(100, 40),
				TextSize = 15,
			}
		)
		buyOne.Activated:Connect(function()
			call(buyRemote, itemId, 1)
		end)
		local buyFive = UI.button(
			frame,
			"×5",
			if gold >= item.Price * 5 then Colors.Gold:Lerp(Color3.new(), 0.5) else Colors.PanelLight,
			{
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.fromOffset(60, 40),
				TextSize = 15,
			}
		)
		buyFive.Activated:Connect(function()
			call(buyRemote, itemId, 5)
		end)
	end
end

local function renderBlacksmith(shop)
	local owned = {}
	for weaponId in string.gmatch(player:GetAttribute("Weapons") or "", "[^,]+") do
		owned[weaponId] = true
	end
	local equipped = player:GetAttribute("Equipped") or ""
	local gold = player:GetAttribute("Gold") or 0
	local raceId = player:GetAttribute("Race") or Config.DefaultRace
	local isSlime = Config.Races[raceId] and Config.Races[raceId].CanAbsorb

	if isSlime then
		UI.label(listFrame, {
			Size = UDim2.new(1, -8, 0, 30),
			TextSize = 14,
			TextColor3 = Color3.fromRGB(255, 190, 120),
			LayoutOrder = 0,
			Text = "⚠️ Un Slime todavía no tiene forma humana para empuñar una espada.",
		})
	end

	for order, weaponId in shop.Weapons do
		local weapon = Config.Weapons[weaponId]
		local rarity = Config.Rarities[weapon.Rarity]
		local frame = row(order, 96, rarity.Color)
		swordIcon(frame, weapon.Look)

		UI.label(frame, {
			Position = UDim2.fromOffset(98, 6),
			Size = UDim2.new(1, -250, 1, -12),
			TextSize = 13,
			RichText = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = string.format(
				'<font color="%s"><b>%s</b>  ·  %s</font>\n<font color="%s">⚔️ +%d daño   ⏱️ +%d%% vel. ataque</font>%s\n<font color="%s"><i>%s</i></font>',
				hex(rarity.Color),
				weapon.Name,
				rarity.Name,
				hex(Colors.Accent),
				weapon.Damage,
				math.floor(weapon.AttackSpeed * 100),
				if weapon.PassiveText
					then '\n<font color="' .. hex(Colors.Gold) .. '">✦ ' .. weapon.PassiveText .. "</font>"
					else "",
				hex(Colors.Muted),
				weapon.Description
			),
		})

		local text, color, action
		if owned[weaponId] then
			if equipped == weaponId then
				text, color = "Equipada ✔", Colors.PanelLight
			else
				text, color = "Equipar", Colors.Green
				action = function()
					call(equipRemote, weaponId)
				end
			end
		else
			text = "💰 " .. weapon.Price
			color = if gold >= weapon.Price and not isSlime
				then Colors.Gold:Lerp(Color3.new(), 0.35)
				else Colors.PanelLight
			action = function()
				call(buyWeaponRemote, weaponId)
			end
		end
		local button = UI.button(frame, text, color, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(130, 42),
			TextSize = 15,
		})
		if action then
			button.Activated:Connect(action)
		end
	end
end

local function render()
	if not currentShop then
		return
	end
	local shop = Config.Shops[currentShop]
	titleLabel.Text = "◆ " .. shop.Icon .. " " .. shop.Title .. " ◆"
	greetingLabel.Text = '<b><font color="'
		.. hex(shop.Color)
		.. '">'
		.. shop.Npc
		.. ":</font></b> «"
		.. shop.Greeting
		.. "»"
	goldLabel.Text = "💰 " .. tostring(player:GetAttribute("Gold") or 0) .. " oro"
	windowStroke.Color = shop.Color

	clear()
	if currentShop == "Medicine" then
		renderMedicine(shop)
	else
		renderBlacksmith(shop)
	end
end

local function close()
	gui.Enabled = false
	currentShop = nil
end

local function open(shopId)
	if not Config.Shops[shopId] then
		return
	end
	currentShop = shopId
	render()
	gui.Enabled = true
end

closeButton.Activated:Connect(close)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "ShopPrompt" then
		open(prompt:GetAttribute("ShopId"))
	end
end)

-- Redibujar al cambiar el oro, el inventario o las armas
for _, name in { "Gold", "Inventory", "Weapons", "Equipped" } do
	player:GetAttributeChangedSignal(name):Connect(function()
		if gui.Enabled then
			render()
		end
	end)
end

-- Cerrar si te alejas
RunService.Heartbeat:Connect(function()
	if not gui.Enabled or not currentShop then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local shop = Config.Shops[currentShop]
	if not root or (root.Position - shop.Position).Magnitude > Config.ShopTalkDistance + 8 then
		close()
	end
end)

function ShopWindow.Close()
	close()
end

return ShopWindow
