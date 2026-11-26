-- Autocomprobación del servidor (solo en Roblox Studio). Revisa que la configuración sea
-- coherente y que los modelos se construyan bien, y escribe el resultado en Output.
-- Si algo falla, sale en amarillo con "[Autocomprobación]".
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local SlimeModel = require(ReplicatedStorage.Shared.SlimeModel)

local Tests = {}

local function finite(number)
	return number == number and number ~= math.huge and number ~= -math.huge
end

function Tests.Run(modules)
	local passed, failed = 0, 0
	local function check(condition, message)
		if condition then
			passed += 1
		else
			failed += 1
			warn("[Autocomprobación] ✗ " .. message)
		end
	end

	-- Razas
	for raceId, race in Config.Races do
		check(Config.Rarities[race.Rarity] ~= nil, raceId .. ": rareza desconocida " .. tostring(race.Rarity))
		check(type(race.Name) == "string" and race.Name ~= "", raceId .. ": sin nombre")
		check(race.Stamina and race.Stamina.Max > 0 and race.Stamina.SpeedMult > 1, raceId .. ": stamina inválida")
		for _, stat in Config.Stats do
			check(type(race.Growth[stat.Id]) == "number", raceId .. ": falta crecimiento de " .. stat.Id)
		end
		for _, abilityId in race.Abilities do
			check(Config.Abilities[abilityId] ~= nil, raceId .. ": habilidad desconocida " .. abilityId)
		end
		if race.Variants then
			for _, variantId in race.Variants do
				check(Config.Races[variantId] ~= nil, raceId .. ": tipo desconocido " .. variantId)
			end
		end
	end
	for _, raceId in Config.DisplayOrder do
		check(Config.Races[raceId] ~= nil, "DisplayOrder: raza desconocida " .. raceId)
	end

	-- Habilidades: cada una tiene su código en Combat
	for abilityId, ability in Config.Abilities do
		check(modules.Combat.HasAbilityHandler(abilityId), abilityId .. ": no tiene código en Combat")
		check(ability.ManaCost >= 0 and ability.Cooldown > 0, abilityId .. ": coste o recarga inválidos")
	end
	for skillId, skill in Config.Skills do
		check(Config.Monsters[skill.From] ~= nil, skillId .. ": monstruo desconocido " .. tostring(skill.From))
		check(skill.Ability == nil or Config.Abilities[skill.Ability] ~= nil, skillId .. ": habilidad desconocida")
	end

	-- Monstruos
	for monsterId in Config.Monsters do
		check(modules.Monsters.HasBuilder(monsterId), monsterId .. ": no tiene diseño")
	end
	for _, zone in Config.Zones do
		for _, monsterId in zone.Monsters do
			check(Config.Monsters[monsterId] ~= nil, zone.Name .. ": monstruo desconocido " .. monsterId)
		end
	end

	-- Tiendas, armas y misiones
	for _, itemId in Config.Shops.Medicine.Items do
		check(Config.Items[itemId] ~= nil, "Medicina: objeto desconocido " .. itemId)
	end
	for _, weaponId in Config.Shops.Blacksmith.Weapons do
		local weapon = Config.Weapons[weaponId]
		check(weapon ~= nil, "Herrería: arma desconocida " .. weaponId)
		check(weapon == nil or Config.Rarities[weapon.Rarity] ~= nil, weaponId .. ": rareza desconocida")
	end
	for _, quest in Config.Quests do
		check(Config.Monsters[quest.Monster] ~= nil, quest.Id .. ": monstruo desconocido")
	end

	-- Slime: el diseño tiene todas sus partes y la cara queda por fuera del cuerpo
	for _, form in Config.Forms do
		local pieces = SlimeModel.Pieces(form)
		local roles = {}
		for _, piece in pieces do
			roles[piece.Role] = (roles[piece.Role] or 0) + 1
			local position = piece.Offset.Position
			check(
				finite(position.X) and finite(position.Y) and finite(position.Z),
				form.Name .. ": posición inválida"
			)
			if piece.Role == "Eye" then
				check(position.Z < -form.Size * 0.3, form.Name .. ": un ojo queda dentro del cuerpo")
			end
		end
		check((roles.Body or 0) >= 1 and roles.Core == 1, form.Name .. ": faltan el cuerpo o la luz interior")
		check(roles.Eye == 6, form.Name .. ": los ojos deberían tener 6 trocitos")

		-- En el juego, la cara va en 3 placas (ojo derecho, izquierdo y boca) por fuera del cuerpo
		local faces = 0
		for _, piece in SlimeModel.Pieces(form, { Face = "Plates" }) do
			if piece.Role == "Face" then
				faces += 1
				check(piece.Offset.Position.Z < -form.Size * 0.3, form.Name .. ": la cara queda dentro del cuerpo")
			end
			check(piece.Role ~= "Eye", form.Name .. ": con placas no debería haber ojos de piezas")
		end
		check(faces == 2, form.Name .. ": deberían ser 2 placas de cara (los ojos, sin boca)")
	end

	-- Slime: construirlo de verdad sobre un personaje de prueba
	local dummy = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Anchored = true
	root.Parent = dummy
	modules.PlayerData.BuildSlimeBodyForTest(dummy, Config.Forms[1])
	local body = dummy:FindFirstChild("SlimeBody")
	check(body ~= nil, "El Slime no se construyó")
	if body then
		local welds = 0
		for _, part in body:GetChildren() do
			local joint = part:IsA("BasePart") and part:FindFirstChildOfClass("Weld")
			if joint and joint:GetAttribute("BaseC0") then
				welds += 1
			end
		end
		check(welds == #SlimeModel.Pieces(Config.Forms[1], { Face = "Plates" }), "Al Slime le faltan uniones animables")
		check(body:FindFirstChild("FaceRightEye") ~= nil, "Al Slime le falta la placa de los ojos")
		check(body:FindFirstChild("FaceMouth") == nil, "El Slime no debería tener boca")
		check(body:GetAttribute("Center") ~= nil, "El Slime no tiene centro para animarlo")
	end
	dummy:Destroy()

	local total = passed + failed
	if failed == 0 then
		print(string.format("[Autocomprobación] ✓ Servidor: %d/%d comprobaciones correctas", passed, total))
	else
		warn(string.format("[Autocomprobación] Servidor: %d de %d comprobaciones fallaron", failed, total))
	end
end

return Tests
