-- Grupos de colisión.
--
-- Por qué: los monstruos los mueve el servidor y a los jugadores su propio ordenador. Cuando
-- dos personajes con Humanoid chocan, cada uno empuja al otro con toda la fuerza de su
-- Humanoid, y como cada lado calcula la física por su cuenta, el choque se corrige de golpe:
-- el jugador sale despedido o el monstruo sale volando (sobre todo con el Dash, que empuja
-- con una fuerza enorme, o cuando el monstruo caminaba hacia el centro del jugador).
--
-- Solución: jugadores y monstruos no chocan entre sí (ni los monstruos entre ellos), pero
-- todos siguen chocando con el mundo (suelo, casas, árboles, rocas). Los golpes no dependen
-- de la física: se calculan en el servidor por distancia y dirección (Monsters.InFront...),
-- así que ningún arma ni ataque empuja a nadie sin querer.
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local Physics = {}

Physics.PLAYERS = "Players"
Physics.MONSTERS = "Monsters"

local function setPart(part, group)
	if part:IsA("BasePart") then
		part.CollisionGroup = group
	end
end

-- Pone todas las piezas de un modelo (y las que se le añadan después) en un grupo
function Physics.SetGroup(model, group)
	for _, descendant in model:GetDescendants() do
		setPart(descendant, group)
	end
	model.DescendantAdded:Connect(function(descendant)
		setPart(descendant, group)
	end)
end

function Physics.Setup()
	for _, group in { Physics.PLAYERS, Physics.MONSTERS } do
		if not PhysicsService:IsCollisionGroupRegistered(group) then
			PhysicsService:RegisterCollisionGroup(group)
		end
	end
	PhysicsService:CollisionGroupSetCollidable(Physics.PLAYERS, Physics.MONSTERS, false)
	PhysicsService:CollisionGroupSetCollidable(Physics.MONSTERS, Physics.MONSTERS, false)

	local function watch(player)
		player.CharacterAdded:Connect(function(character)
			Physics.SetGroup(character, Physics.PLAYERS)
		end)
		if player.Character then
			Physics.SetGroup(player.Character, Physics.PLAYERS)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

-- Para la autocomprobación
function Physics.IsConfigured()
	return PhysicsService:IsCollisionGroupRegistered(Physics.PLAYERS)
		and PhysicsService:IsCollisionGroupRegistered(Physics.MONSTERS)
		and not PhysicsService:CollisionGroupsAreCollidable(Physics.PLAYERS, Physics.MONSTERS)
		and not PhysicsService:CollisionGroupsAreCollidable(Physics.MONSTERS, Physics.MONSTERS)
		and PhysicsService:CollisionGroupsAreCollidable(Physics.MONSTERS, "Default")
		and PhysicsService:CollisionGroupsAreCollidable(Physics.PLAYERS, "Default")
end

return Physics
