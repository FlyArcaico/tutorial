-- Punto de entrada del cliente: abre el menú al entrar y muestra el HUD al jugar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Animator = require(script.Animator)
local CharacterMenu = require(script.CharacterMenu)
local Dialog = require(script.Dialog)
local Hud = require(script.Hud)
local Menu = require(script.Menu)
local MonsterAnimator = require(script.MonsterAnimator)
local ShopWindow = require(script.ShopWindow)
local SlimeAnimator = require(script.SlimeAnimator)
local TargetLock = require(script.TargetLock)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local returnToMenuRemote = remotes:WaitForChild("ReturnToMenu")
local attackFxRemote = remotes:WaitForChild("AttackFx")
local player = Players.LocalPlayer

-- Animaciones de andar/atacar de todos los personajes y del Slime
Animator.Start()
SlimeAnimator.Start()
MonsterAnimator.Start()
-- Fijar objetivo con la rueda del ratón (retrato, nombre y vida del enemigo)
TargetLock.Start()

attackFxRemote.OnClientEvent:Connect(function(character, style)
	if not character then
		return
	end
	if style == "SlimeLunge" then
		SlimeAnimator.PlayAttack(character)
	elseif style == "SlimeCast" then
		SlimeAnimator.PlayCast(character, "Ability")
	elseif style == "SlimeAbsorb" then
		SlimeAnimator.PlayCast(character, "Absorb")
	else
		Animator.PlayAttack(character, style)
	end
end)

-- Absorber (Slime): todos ven la animación; si eres tú, el slime se gira y se acerca
-- solo a la esencia durante la preparación (sin que tus teclas lo muevan)
local absorbSequenceRemote = remotes:WaitForChild("AbsorbSequence")
absorbSequenceRemote.OnClientEvent:Connect(function(character, orb, success, timing)
	if not character then
		return
	end
	SlimeAnimator.PlayAbsorb(character, success, timing)
	if character ~= player.Character or not orb then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	local body = character:FindFirstChild("SlimeBody")
	if not humanoid or not root then
		return
	end
	local ok, controls = pcall(function()
		-- PlayerModule es un script interno de Roblox (el editor no lo conoce, por eso :: any)
		local playerModule = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: any
		return require(playerModule):GetControls()
	end)
	if ok and controls then
		controls:Disable()
	end

	-- Mirar a la esencia y acercarse hasta casi tocarla
	local target = Vector3.new(orb.Position.X, root.Position.Y, orb.Position.Z)
	local toTarget = target - root.Position
	if toTarget.Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, target)
		local size = if body then body:GetAttribute("Size") or 3 else 3
		local stopDistance = size * 0.5 + timing.ApproachDistance + 0.6
		if toTarget.Magnitude > stopDistance then
			humanoid:MoveTo(target - toTarget.Unit * stopDistance)
		end
	end

	local total = if success
		then timing.Approach + timing.Engulf + timing.Close + timing.Digest
		else timing.Approach + timing.Struggle + timing.Recoil
	task.delay(timing.Approach, function()
		humanoid:Move(Vector3.zero)
	end)
	task.delay(total, function()
		if ok and controls then
			controls:Enable()
		end
	end)
end)

Menu.Init(function()
	Hud.Show()
	CharacterMenu.SetAllowed(true)
end)

Hud.Init(function()
	returnToMenuRemote:FireServer()
	Dialog.Close()
	ShopWindow.Close()
	CharacterMenu.SetAllowed(false)
	Hud.Hide()
	Menu.Open()
end)

-- La cámara sigue al personaje cuando aparece
player.CharacterAdded:Connect(function(character)
	local humanoid = character:WaitForChild("Humanoid")
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = humanoid
end)

Menu.Open()

-- En Studio: autocomprobación de las animaciones (el resultado sale en Output)
if game:GetService("RunService"):IsStudio() then
	task.defer(function()
		local ok, problem = pcall(require(script.Tests).Run)
		if not ok then
			warn("[Autocomprobación] Error al ejecutar las pruebas del cliente:", problem)
		end
	end)
end
