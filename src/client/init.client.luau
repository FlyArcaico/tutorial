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

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local returnToMenuRemote = remotes:WaitForChild("ReturnToMenu")
local attackFxRemote = remotes:WaitForChild("AttackFx")
local player = Players.LocalPlayer

-- Animaciones de andar/atacar de todos los personajes y del Slime
Animator.Start()
SlimeAnimator.Start()
MonsterAnimator.Start()

attackFxRemote.OnClientEvent:Connect(function(character, style)
	if not character then
		return
	end
	if style == "SlimeLunge" then
		SlimeAnimator.PlayAttack(character)
	elseif style == "SlimeCast" then
		SlimeAnimator.PlayCast(character)
	else
		Animator.PlayAttack(character, style)
	end
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
