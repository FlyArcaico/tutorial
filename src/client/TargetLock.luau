-- Fijar objetivo (estilo MMORPG):
--   * Rueda del ratón: selecciona el enemigo más cercano y, al seguir girándola, pasa al
--     siguiente (hacia abajo = siguiente más lejano, hacia arriba = anterior).
--   * Clic con la rueda (botón central): deja de fijar.
--   * Con un objetivo fijado, la cámara lo mantiene encuadrado (suave, sin meterse en
--     paredes) y arriba a la izquierda sale su retrato, su nombre y su vida (sin números).
--   * Si el objetivo muere, se aleja demasiado o mueres tú, se suelta solo.
-- Todo es solo visual y local: no cambia nada en el servidor.
-- El zoom de la cámara sigue funcionando con las teclas I y O.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local UI = require(script.Parent.UI)

local TargetLock = {}

local player = Players.LocalPlayer
local create = UI.create

local SELECT_RANGE = 60 -- distancia máxima para seleccionar
local KEEP_RANGE = 90 -- si se aleja más, se suelta
local CAMERA_DISTANCE = 13
local CAMERA_HEIGHT = 5
local CAMERA_SHOULDER = 2 -- un poco a la derecha, para ver al personaje y al enemigo

local GOLD = Color3.fromRGB(232, 196, 120)
local SILVER = Color3.fromRGB(200, 205, 220)
local HEALTH_GOOD = Color3.fromRGB(96, 214, 118)
local HEALTH_MID = Color3.fromRGB(236, 196, 64)
local HEALTH_LOW = Color3.fromRGB(226, 66, 58)

local current = nil -- { Model, Humanoid, Root, Highlight, Connections }
local cameraPosition, cameraFocus = nil, nil
local lastDirection = Vector3.new(0, 0, -1)

--------------------------------------------------------------------------------
-- Interfaz
--------------------------------------------------------------------------------

local gui = create("ScreenGui", {
	Name = "TargetLock",
	ResetOnSpawn = false,
	DisplayOrder = 2,
	IgnoreGuiInset = false,
}, player:WaitForChild("PlayerGui"))

-- Al lado de la tarjeta del personaje (que ocupa de 16 a 316 px)
local REST_POSITION = UDim2.fromOffset(332, 18)
local panel = create("CanvasGroup", {
	Name = "Target",
	Position = REST_POSITION,
	Size = UDim2.fromOffset(276, 74),
	BackgroundColor3 = Color3.fromRGB(10, 12, 22),
	BackgroundTransparency = 0.22,
	GroupTransparency = 1,
	Visible = false,
}, gui)
UI.round(panel, 10)
create("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(46, 52, 78), Color3.fromRGB(12, 14, 24)),
	Rotation = 90,
}, panel)
local panelStroke = create("UIStroke", {
	Color = Color3.new(1, 1, 1),
	Thickness = 1.2,
	Transparency = 0.25,
	ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
}, panel)
create("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, GOLD),
		ColorSequenceKeypoint.new(0.45, SILVER),
		ColorSequenceKeypoint.new(1, GOLD),
	}),
	Rotation = 20,
}, panelStroke)

-- Retrato con marco dorado
local portraitFrame = create("Frame", {
	Position = UDim2.fromOffset(7, 7),
	Size = UDim2.fromOffset(60, 60),
	BackgroundColor3 = Color3.fromRGB(26, 30, 46),
}, panel)
UI.round(portraitFrame, 9)
create("UIStroke", { Color = GOLD, Thickness = 1.6, Transparency = 0.1 }, portraitFrame)
create("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(70, 78, 110), Color3.fromRGB(18, 20, 32)),
	Rotation = 90,
}, portraitFrame)
local viewport = create("ViewportFrame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Ambient = Color3.fromRGB(120, 122, 135),
	LightColor = Color3.fromRGB(255, 240, 215),
	LightDirection = Vector3.new(-0.6, -0.8, -0.9),
}, portraitFrame)
UI.round(viewport, 9)
local portraitFlash = create("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 1,
	ZIndex = 3,
}, portraitFrame)
UI.round(portraitFlash, 9)
-- Rombo decorativo en la esquina del marco
local gem = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(1, -2, 1, -2),
	Size = UDim2.fromOffset(9, 9),
	Rotation = 45,
	BackgroundColor3 = GOLD,
	ZIndex = 4,
}, portraitFrame)
create("UIStroke", { Color = Color3.fromRGB(60, 45, 20), Thickness = 1 }, gem)

local nameLabel = UI.label(panel, {
	Position = UDim2.fromOffset(78, 10),
	Size = UDim2.new(1, -90, 0, 20),
	Font = UI.Fonts.Title,
	TextSize = 19,
	TextColor3 = Color3.fromRGB(240, 232, 214),
	TextStrokeTransparency = 0.55,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextWrapped = false,
	TextTruncate = Enum.TextTruncate.AtEnd,
	Text = "",
})
-- Línea fina bajo el nombre
create("Frame", {
	Position = UDim2.fromOffset(78, 33),
	Size = UDim2.new(1, -92, 0, 1),
	BackgroundColor3 = GOLD,
	BackgroundTransparency = 0.55,
	BorderSizePixel = 0,
}, panel)

-- Barra de vida: fondo oscuro, rastro claro que baja con retraso y relleno de color
local barBack = create("Frame", {
	Position = UDim2.fromOffset(78, 42),
	Size = UDim2.new(1, -92, 0, 13),
	BackgroundColor3 = Color3.fromRGB(8, 9, 14),
	ClipsDescendants = true,
}, panel)
UI.round(barBack, 4)
create("UIStroke", { Color = Color3.fromRGB(150, 140, 115), Thickness = 1, Transparency = 0.35 }, barBack)
local trail = create("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(255, 236, 200),
	BackgroundTransparency = 0.15,
	BorderSizePixel = 0,
}, barBack)
UI.round(trail, 4)
local fill = create("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = HEALTH_GOOD,
	BorderSizePixel = 0,
	ZIndex = 2,
}, barBack)
UI.round(fill, 4)
create("UIGradient", {
	Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150)),
	Rotation = 90,
}, fill)
-- Brillo en la mitad de arriba
create("Frame", {
	Size = UDim2.fromScale(1, 0.45),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0.82,
	BorderSizePixel = 0,
	ZIndex = 3,
}, barBack)

--------------------------------------------------------------------------------
-- Retrato: copia de la cabeza del monstruo en un ViewportFrame (el original no se toca)
--------------------------------------------------------------------------------

local portraitCamera = create("Camera", { FieldOfView = 28 }, viewport)
viewport.CurrentCamera = portraitCamera
local portraitFocus, portraitFront, portraitDistance = Vector3.zero, Vector3.new(0, 0, -1), 6
local portraitStart = 0

local function buildPortrait(model)
	for _, child in viewport:GetChildren() do
		if child ~= portraitCamera and not child:IsA("UICorner") then
			child:Destroy()
		end
	end
	local archivable = model.Archivable
	model.Archivable = true
	local ok, copy = pcall(model.Clone, model)
	model.Archivable = archivable
	if not ok or not copy then
		return
	end
	-- Solo la parte visible: fuera Humanoid, articulaciones, efectos y textos
	for _, descendant in copy:GetDescendants() do
		if
			descendant:IsA("Humanoid")
			or descendant:IsA("JointInstance")
			or descendant:IsA("Constraint")
			or descendant:IsA("BillboardGui")
			or descendant:IsA("Highlight")
			or descendant:IsA("ParticleEmitter")
			or descendant:IsA("Fire")
		then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
	local root = copy:FindFirstChild("HumanoidRootPart")
	local head = copy:FindFirstChild("Head") or root
	if not head then
		copy:Destroy()
		return
	end
	copy.Parent = viewport

	-- Encuadrar la cara: de frente y un poco de lado
	local front = if root then root.CFrame.LookVector else head.CFrame.LookVector
	front = Vector3.new(front.X, 0, front.Z)
	portraitFront = if front.Magnitude > 0.1 then front.Unit else Vector3.new(0, 0, -1)
	portraitFocus = head.Position + Vector3.new(0, head.Size.Y * 0.05, 0)
	local size = math.max(head.Size.Y, math.min(head.Size.X, head.Size.Y * 1.6))
	portraitDistance = size / (2 * math.tan(math.rad(portraitCamera.FieldOfView / 2))) * 1.05
	portraitStart = os.clock()
end

-- Movimiento suave del retrato: la cámara oscila un poco, como si respirara
local function updatePortrait(now)
	local t = now - portraitStart
	local angle = math.rad(22 + math.sin(t * 0.7) * 5)
	local direction = CFrame.Angles(0, angle, 0):VectorToWorldSpace(portraitFront)
	local bob = Vector3.new(0, math.sin(t * 1.6) * 0.03, 0)
	local eye = portraitFocus + direction * portraitDistance + Vector3.new(0, portraitDistance * 0.08, 0)
	portraitCamera.CFrame = CFrame.lookAt(eye + bob, portraitFocus + bob)
end

--------------------------------------------------------------------------------
-- Vida
--------------------------------------------------------------------------------

local function healthColor(ratio)
	if ratio > 0.5 then
		return HEALTH_MID:Lerp(HEALTH_GOOD, (ratio - 0.5) / 0.5)
	elseif ratio > 0.25 then
		return HEALTH_LOW:Lerp(HEALTH_MID, (ratio - 0.25) / 0.25)
	end
	return HEALTH_LOW
end

local trailTween = nil
local function setHealth(ratio, animate)
	ratio = math.clamp(ratio, 0, 1)
	if not animate then
		fill.Size = UDim2.fromScale(ratio, 1)
		trail.Size = UDim2.fromScale(ratio, 1)
		fill.BackgroundColor3 = healthColor(ratio)
		return
	end
	local quick = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(fill, quick, { Size = UDim2.fromScale(ratio, 1), BackgroundColor3 = healthColor(ratio) }):Play()
	-- El rastro claro se queda un momento y luego baja (se ve cuánto daño hiciste)
	if trailTween then
		trailTween:Cancel()
	end
	if trail.Size.X.Scale < ratio then
		trail.Size = UDim2.fromScale(ratio, 1)
	else
		trailTween = TweenService:Create(
			trail,
			TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.35),
			{ Size = UDim2.fromScale(ratio, 1) }
		)
		trailTween:Play()
	end
end

local function hitFeedback()
	portraitFlash.BackgroundTransparency = 0.45
	TweenService:Create(portraitFlash, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
	-- Pequeña sacudida del panel
	task.spawn(function()
		for _, dx in { 3, -3, 2, -1, 0 } do
			panel.Position = REST_POSITION + UDim2.fromOffset(dx, 0)
			task.wait(0.03)
		end
	end)
end

--------------------------------------------------------------------------------
-- Seleccionar y soltar
--------------------------------------------------------------------------------

local function myRoot()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return root
	end
	return nil
end

local function isValid(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	return humanoid ~= nil and root ~= nil and humanoid.Health > 0 and model:GetAttribute("AIState") ~= "Dead"
end

-- Monstruos vivos cerca, del más cercano al más lejano
local function candidates(origin)
	local list = {}
	local folder = Workspace:FindFirstChild("Monsters")
	if not folder then
		return list
	end
	for _, model in folder:GetChildren() do
		if model:IsA("Model") and isValid(model) then
			local distance = (model.HumanoidRootPart.Position - origin).Magnitude
			if distance <= SELECT_RANGE then
				table.insert(list, { Model = model, Distance = distance })
			end
		end
	end
	table.sort(list, function(a, b)
		return a.Distance < b.Distance
	end)
	return list
end

local function release(instant)
	local old = current
	if not old then
		return
	end
	current = nil
	for _, connection in old.Connections do
		connection:Disconnect()
	end
	if old.Highlight then
		old.Highlight:Destroy()
	end
	if instant then
		panel.Visible = false
		panel.GroupTransparency = 1
	else
		local fade = TweenService:Create(panel, TweenInfo.new(0.25), { GroupTransparency = 1 })
		fade.Completed:Connect(function()
			if not current then
				panel.Visible = false
			end
		end)
		fade:Play()
	end
end

local function lockOn(model)
	if current and current.Model == model then
		return
	end
	release(true)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")

	-- Indicador sobre el enemigo: contorno dorado suave (solo lo ves tú)
	local highlight = create("Highlight", {
		Name = "TargetLockOutline",
		FillTransparency = 1,
		OutlineColor = GOLD,
		OutlineTransparency = 0.3,
		DepthMode = Enum.HighlightDepthMode.Occluded,
	}, model)

	current = { Model = model, Humanoid = humanoid, Root = root, Highlight = highlight, Connections = {} }
	local state = current
	nameLabel.Text = model.Name
	setHealth(humanoid.Health / math.max(humanoid.MaxHealth, 1), false)
	buildPortrait(model)

	local lastHealth = humanoid.Health
	table.insert(
		state.Connections,
		humanoid.HealthChanged:Connect(function(health)
			setHealth(health / math.max(humanoid.MaxHealth, 1), true)
			if health < lastHealth - 0.5 then
				hitFeedback()
			end
			lastHealth = health
		end)
	)
	-- Al morir: la barra baja a cero y el objetivo se suelta poco después
	table.insert(
		state.Connections,
		humanoid.Died:Connect(function()
			setHealth(0, true)
			task.delay(0.6, function()
				if current == state then
					release(false)
				end
			end)
		end)
	)

	-- Aparecer: se desliza un poco hacia abajo y aparece
	panel.Visible = true
	panel.GroupTransparency = 1
	panel.Position = REST_POSITION - UDim2.fromOffset(0, 8)
	local info = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(panel, info, { GroupTransparency = 0, Position = REST_POSITION }):Play()
end

-- step = 1: siguiente (más lejos), -1: anterior
local function cycle(step)
	local root = myRoot()
	if not root then
		return
	end
	local list = candidates(root.Position)
	if #list == 0 then
		release(false)
		return
	end
	local index = nil
	if current then
		for i, entry in list do
			if entry.Model == current.Model then
				index = i
				break
			end
		end
	end
	if not index then
		lockOn(list[1].Model) -- el primero siempre es el más cercano
	else
		lockOn(list[(index - 1 + step) % #list + 1].Model)
	end
end

--------------------------------------------------------------------------------
-- Cámara: después de la cámara normal de Roblox, la gira para encuadrar al objetivo
--------------------------------------------------------------------------------

local function cameraIgnoreList()
	local ignore = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	for _, name in { "Monsters", "Essences", "Effects" } do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			table.insert(ignore, folder)
		end
	end
	return ignore
end

local function updateCamera(dt)
	local camera = Workspace.CurrentCamera
	local root = myRoot()
	if not current or not root or camera.CameraType ~= Enum.CameraType.Custom then
		cameraPosition, cameraFocus = nil, nil
		return
	end
	local targetPosition = current.Root.Position
	local toTarget = Vector3.new(targetPosition.X - root.Position.X, 0, targetPosition.Z - root.Position.Z)
	if toTarget.Magnitude > 2 then
		lastDirection = toTarget.Unit
	end
	local direction = lastDirection
	local right = direction:Cross(Vector3.yAxis)

	local pivot = root.Position + Vector3.new(0, 2, 0)
	local desired = root.Position
		- direction * CAMERA_DISTANCE
		+ Vector3.new(0, CAMERA_HEIGHT, 0)
		+ right * CAMERA_SHOULDER
	-- No meter la cámara dentro de paredes
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = cameraIgnoreList()
	local hit = Workspace:Raycast(pivot, desired - pivot, params)
	if hit then
		desired = hit.Position + (pivot - hit.Position).Unit * 0.6
	end
	-- Mirar entre el personaje y el enemigo (más hacia el enemigo)
	local focus = root.Position:Lerp(targetPosition, 0.6) + Vector3.new(0, 1.2, 0)

	-- Suavizado: arranca desde donde estaba la cámara (sin saltos al fijar o cambiar)
	if not cameraPosition then
		cameraPosition = camera.CFrame.Position
		cameraFocus = camera.CFrame.Position + camera.CFrame.LookVector * (focus - camera.CFrame.Position).Magnitude
	end
	cameraPosition = cameraPosition:Lerp(desired, 1 - math.exp(-dt * 7))
	cameraFocus = cameraFocus:Lerp(focus, 1 - math.exp(-dt * 9))
	camera.CFrame = CFrame.lookAt(cameraPosition, cameraFocus)
end

--------------------------------------------------------------------------------
-- Controles
--------------------------------------------------------------------------------

-- No usar la rueda si el ratón está sobre una lista con scroll, o si no estás jugando
local function wheelAllowed()
	local hud = player.PlayerGui:FindFirstChild("Hud")
	if not hud or not hud.Enabled or not myRoot() or UserInputService:GetFocusedTextBox() then
		return false
	end
	local mouse = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
	for _, object in player.PlayerGui:GetGuiObjectsAtPosition(mouse.X, mouse.Y) do
		if object:IsA("ScrollingFrame") then
			return false
		end
	end
	return true
end

function TargetLock.Start()
	ContextActionService:BindActionAtPriority("TargetLockWheel", function(_, inputState, input)
		if inputState ~= Enum.UserInputState.Change or not wheelAllowed() then
			return Enum.ContextActionResult.Pass
		end
		cycle(if input.Position.Z < 0 then 1 else -1)
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.UserInputType.MouseWheel)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.MouseButton3 then
			release(false)
		end
	end)

	RunService:BindToRenderStep("TargetLockCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		-- Soltar si ya no sirve: muerto, borrado, demasiado lejos o tú muerto
		if current then
			local root = myRoot()
			local model = current.Model
			local gone = not root or not model.Parent or not current.Root.Parent
			if
				gone or (current.Humanoid.Health > 0 and (current.Root.Position - root.Position).Magnitude > KEEP_RANGE)
			then
				release(false)
			end
		end
		updateCamera(dt)
		if current then
			updatePortrait(os.clock())
		end
	end)

	player.CharacterRemoving:Connect(function()
		release(true)
	end)
end

-- Para la autocomprobación del cliente
TargetLock.HealthColor = healthColor
function TargetLock.Current()
	return current and current.Model
end

return TargetLock
