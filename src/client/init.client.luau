-- Punto de entrada del cliente: abre el menú al entrar y muestra el HUD al jugar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Dialog = require(script.Dialog)
local Hud = require(script.Hud)
local Menu = require(script.Menu)

local returnToMenuRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ReturnToMenu")
local player = Players.LocalPlayer

Menu.Init(function()
	Hud.Show()
end)

Hud.Init(function()
	returnToMenuRemote:FireServer()
	Dialog.Close()
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
