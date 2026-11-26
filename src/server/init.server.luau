-- Punto de entrada del servidor: construye el mundo, inicia monstruos, datos, combate y el menú.
local Players = game:GetService("Players")

-- El personaje no aparece hasta que el jugador pulsa "Jugar" en el menú
Players.CharacterAutoLoads = false

local Combat = require(script.Combat)
local Monsters = require(script.Monsters)
local PlayerData = require(script.PlayerData)
local Remotes = require(script.Remotes)
local World = require(script.World)

World.Build()
Monsters.SetKillHandler(PlayerData.OnMonsterKilled)
Monsters.Start()
PlayerData.Start()
Combat.Start()

-- Menú
Remotes.GetMenu.OnServerInvoke = function(player)
	return PlayerData.GetMenu(player)
end

Remotes.SelectSlot.OnServerInvoke = function(player, index)
	return PlayerData.SelectSlot(player, index)
end

Remotes.Spin.OnServerInvoke = function(player)
	return PlayerData.Spin(player)
end

Remotes.SetRace.OnServerInvoke = function(player, raceId)
	return PlayerData.SetRace(player, raceId)
end

Remotes.Play.OnServerInvoke = function(player)
	return PlayerData.Play(player)
end

Remotes.ReturnToMenu.OnServerEvent:Connect(function(player)
	PlayerData.ReturnToMenu(player)
end)

-- Misiones del NPC
Remotes.Quest.OnServerInvoke = function(player, action, questId)
	return PlayerData.QuestAction(player, action, questId)
end

-- Tienda y ajustes (usar objetos está en Combat, porque toca vida/maná/stamina)
Remotes.Buy.OnServerInvoke = function(player, itemId, amount)
	return PlayerData.Buy(player, itemId, amount)
end

Remotes.AllocateStat.OnServerInvoke = function(player, statId)
	return PlayerData.AllocateStat(player, statId)
end

Remotes.SaveSetting.OnServerEvent:Connect(function(player, settingId, enabled)
	PlayerData.SaveSetting(player, settingId, enabled)
end)

-- Modo prueba: +5 / -5 niveles
Remotes.DevLevel.OnServerEvent:Connect(function(player, delta)
	PlayerData.DevChangeLevel(player, delta)
end)
