-- Creates the RemoteEvents the client and server use to talk to each other.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local function makeEvent(name)
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = folder
	return event
end

local Remotes = {
	Attack = makeEvent("Attack"), -- client -> server: player attacked
	Absorb = makeEvent("Absorb"), -- client -> server: player pressed absorb
	Notify = makeEvent("Notify"), -- server -> client: show a message
}

folder.Parent = ReplicatedStorage

return Remotes
