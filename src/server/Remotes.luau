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
	ReturnToMenu = make("RemoteEvent", "ReturnToMenu"), -- volver al menú

	-- Juego
	Attack = make("RemoteEvent", "Attack"), -- cliente -> servidor: atacar
	Absorb = make("RemoteEvent", "Absorb"), -- cliente -> servidor: absorber
	Notify = make("RemoteEvent", "Notify"), -- servidor -> cliente: mostrar un mensaje
}

folder.Parent = ReplicatedStorage

return Remotes
