-- Crea los RemoteEvents/RemoteFunctions que usan el cliente y el servidor para hablar.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local function make(className, name)
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = folder
	return remote
end

local Remotes = {
	-- Menú (el cliente pregunta, el servidor responde)
	GetMenu = make("RemoteFunction", "GetMenu"), -- datos de los 3 slots
	SelectSlot = make("RemoteFunction", "SelectSlot"), -- entrar en un slot
	Spin = make("RemoteFunction", "Spin"), -- tirar por una raza
	Play = make("RemoteFunction", "Play"), -- entrar al mundo
	SetRace = make("RemoteFunction", "SetRace"), -- modo prueba: elegir raza sin Spin
	ReturnToMenu = make("RemoteEvent", "ReturnToMenu"), -- volver al menú

	-- Juego
	Attack = make("RemoteEvent", "Attack"), -- cliente -> servidor: atacar
	Absorb = make("RemoteEvent", "Absorb"), -- cliente -> servidor: absorber
	Cast = make("RemoteEvent", "Cast"), -- cliente -> servidor: usar un ataque especial (Air Manipulation...)
	Notify = make("RemoteEvent", "Notify"), -- servidor -> cliente: mostrar un mensaje
	Sprint = make("RemoteEvent", "Sprint"), -- cliente -> servidor: empezar/dejar de correr
	Quest = make("RemoteFunction", "Quest"), -- hablar con el NPC: ver, aceptar, recoger, abandonar
	DevLevel = make("RemoteEvent", "DevLevel"), -- modo prueba: subir/bajar 5 niveles
	Buy = make("RemoteFunction", "Buy"), -- comprar en la tienda
	UseItem = make("RemoteFunction", "UseItem"), -- usar un objeto del inventario
	SaveSetting = make("RemoteEvent", "SaveSetting"), -- guardar un ajuste
	AllocateStat = make("RemoteFunction", "AllocateStat"), -- repartir un punto de atributo
	BuyWeapon = make("RemoteFunction", "BuyWeapon"), -- comprar un arma en la Herrería
	Equip = make("RemoteFunction", "Equip"), -- equipar / quitar un arma
	AttackFx = make("RemoteEvent", "AttackFx"), -- servidor -> todos: animación de ataque de un personaje
	Guard = make("RemoteEvent", "Guard"), -- cliente -> servidor: empezar/dejar de bloquear (F)
	DevGold = make("RemoteEvent", "DevGold"), -- modo prueba: +500 / -500 de oro
}

folder.Parent = ReplicatedStorage

return Remotes
