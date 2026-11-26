-- Autocomprobación del servidor (solo en Roblox Studio). Revisa que la configuración sea
-- coherente y que los modelos se construyan bien, y escribe el resultado en Output.
-- Si algo falla, sale en amarillo con "[Autocomprobación]".
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local SlimeModel = require(ReplicatedStorage.Shared.SlimeModel)

local MeshRig = require(script.Parent.MeshRig)

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

	-- Absorción: duraciones de la secuencia y probabilidades de conseguir habilidades
	check(
		Config.AbsorbDuration(true) > Config.AbsorbSequence.Approach,
		"Absorber: la secuencia de éxito es demasiado corta"
	)
	check(
		Config.AbsorbDuration(false) > Config.AbsorbSequence.Approach,
		"Absorber: la secuencia de fallo es demasiado corta"
	)
	for _, tier in Config.AbsorbTiers do
		check(type(tier.SkillBonus) == "number", tier.Name .. ": falta SkillBonus")
	end
	for skillId, skill in Config.Skills do
		check(type(skill.AcquireChance) == "number", skillId .. ": falta AcquireChance")
		for _, levels in { { 1, 9 }, { 1, 1 }, { 40, 1 } } do
			local chance = Config.SkillAcquireChance(skillId, levels[1], levels[2], 0)
			check(chance >= 0.05 and chance <= 1, skillId .. ": probabilidad fuera de rango")
		end
		check(
			Config.SkillAcquireChance(skillId, 1, 1, 3) > Config.SkillAcquireChance(skillId, 1, 1, 0),
			skillId .. ": los intentos fallidos deberían subir la probabilidad"
		)
	end

	-- Monstruos
	for monsterId in Config.Monsters do
		check(modules.Monsters.HasBuilder(monsterId), monsterId .. ": no tiene diseño")
	end
	for _, zone in Config.Zones do
		check(#zone.Spawns > 0, zone.Name .. ": la tabla de aparición está vacía")
		for _, entry in zone.Spawns do
			check(
				Config.Monsters[entry.Monster] ~= nil,
				zone.Name .. ": monstruo desconocido " .. tostring(entry.Monster)
			)
			check(entry.Levels and entry.Levels[1] <= entry.Levels[2], zone.Name .. ": rango de niveles inválido")
			check(not Config.IsInSafeZone(zone.Center), zone.Name .. ": la zona está dentro de la zona segura")
		end
	end

	-- Goblin: rig R15 con su diseño y sus animaciones; murciélagos y lobos retirados
	local goblin = Config.Monsters.Goblin
	check(
		goblin ~= nil and goblin.Rig == "R15" and goblin.AnimSet ~= nil and goblin.FallbackAnimSet ~= nil,
		"Goblin: falta configurar su rig"
	)

	-- Monstruos de Blender: medidas completas y, si el modelo está importado, montarlo
	local R15 = {
		"LowerTorso",
		"UpperTorso",
		"Head",
		"LeftUpperArm",
		"LeftLowerArm",
		"LeftHand",
		"RightUpperArm",
		"RightLowerArm",
		"RightHand",
		"LeftUpperLeg",
		"LeftLowerLeg",
		"LeftFoot",
		"RightUpperLeg",
		"RightLowerLeg",
		"RightFoot",
	}
	for monsterId, def in Config.Monsters do
		if def.MeshModel then
			local dataModule = script.Parent.MonsterRigs:FindFirstChild(def.MeshModel)
			check(dataModule ~= nil, monsterId .. ": faltan las medidas de su modelo 3D")
			if dataModule then
				local data = require(dataModule)
				for _, partName in R15 do
					check(data.Parts[partName] ~= nil, monsterId .. ": a su modelo le falta " .. partName)
				end
				check(#data.Joints == 15, monsterId .. ": su modelo debería tener 15 articulaciones")
			end
			if MeshRig.IsReady(def.MeshModel) then
				local model = Instance.new("Model")
				local root = Instance.new("Part")
				root.Name = "HumanoidRootPart"
				root.Anchored = true
				root.CFrame = CFrame.new(0, 500, 0)
				root.Parent = model
				local ok, parts = pcall(MeshRig.Build, def.MeshModel, root, 1, model)
				check(ok, monsterId .. ": no se pudo montar su modelo 3D: " .. tostring(parts))
				if ok then
					local motors = 0
					for _, descendant in model:GetDescendants() do
						if descendant:IsA("Motor6D") then
							motors += 1
						end
					end
					check(motors == 15, monsterId .. ": su modelo 3D debería tener 15 articulaciones")
					local function rel(name)
						return root.CFrame:PointToObjectSpace(parts[name].Position)
					end
					check(rel("Head").Y > rel("LowerTorso").Y + 1, monsterId .. ": la cabeza no queda arriba")
					check(rel("Head").Z < rel("LowerTorso").Z, monsterId .. ": no mira hacia delante")
					check(rel("RightHand").X > 0, monsterId .. ": la mano derecha queda a la izquierda")
					check(rel("LeftFoot").Y < rel("LowerTorso").Y - 0.6, monsterId .. ": los pies no quedan abajo")
				end
				model:Destroy()
				print("[Autocomprobación] · " .. monsterId .. ": se usa su modelo 3D de Blender")
			else
				print(
					"[Autocomprobación] · "
						.. monsterId
						.. ": modelo 3D no importado ("
						.. tostring(MeshRig.Problem(def.MeshModel))
						.. "); se usa el diseño de piezas"
				)
			end
		end
	end
	check(Config.IsMonsterActive("Goblin"), "Goblin: no aparece en ninguna zona")
	check(
		not Config.IsMonsterActive("Bat") and not Config.IsMonsterActive("Wolf"),
		"Murciélagos y lobos deberían estar retirados"
	)
	check(
		Config.Monsters.Bat ~= nil and Config.Monsters.Wolf ~= nil,
		"Los datos de murciélagos y lobos deben conservarse"
	)
	-- Física: jugadores y monstruos no chocan entre sí, pero sí con el mundo
	check(modules.Physics.IsConfigured(), "Los grupos de colisión no están bien configurados")

	-- Comportamiento de los monstruos que aparecen: valores coherentes
	for monsterId in Config.Monsters do
		if Config.IsMonsterActive(monsterId) then
			local def = Config.Monsters[monsterId]
			local function get(key)
				return Config.MonsterSetting(def, key)
			end
			local reach = Config.MonsterReach(def, def.Size)
			check(reach > 0 and reach < get("DetectionRange"), monsterId .. ": alcance de golpe raro")
			check(get("ChaseRange") >= get("DetectionRange"), monsterId .. ": deja de perseguir antes de lo que ve")
			check(get("TurnSpeed") > 0 and get("AttackWidth") > 0, monsterId .. ": giro o ancho de golpe inválidos")
			local window = def.AttackHitWindow or { get("AttackWindup"), get("AttackWindup") }
			check(window[1] <= window[2], monsterId .. ": la ventana del golpe está al revés")
			check(get("AttackCooldown") > window[2] + 0.15, monsterId .. ": ataca más rápido de lo que golpea")
			check(get("LeashRange") > get("WanderRadius") + 5, monsterId .. ": LeashRange demasiado pequeño")
			check(get("RespawnTime") >= get("CorpseTime"), monsterId .. ": reaparece antes de desaparecer su cuerpo")
			check(get("ChaseSpeed") > 0 and get("ReturnSpeed") > 0, monsterId .. ": velocidades inválidas")
		end
	end
	for _, zone in Config.Zones do
		local safe = Config.SafeZone
		local gap = (Vector3.new(zone.Center.X, 0, zone.Center.Z) - Vector3.new(safe.Center.X, 0, safe.Center.Z)).Magnitude
		check(gap + zone.Radius > safe.Radius + 20, zone.Name .. ": no hay sitio para aparecer fuera de la zona segura")
	end

	-- Recompensa: para el que más daño hizo (y sigue en el juego); empate, el último golpe
	local a, b, gone = { Parent = true }, { Parent = true }, { Parent = nil }
	local choose = modules.Monsters.ChooseRewardPlayer
	check(choose({ [a] = 20, [b] = 10 }, b) == a, "Recompensa: debería ser para quien más daño hizo")
	check(choose({ [a] = 10, [b] = 10 }, b) == b, "Recompensa: en empate, para el último golpe")
	check(choose({ [gone] = 50, [b] = 5 }, gone) == b, "Recompensa: no para alguien que se fue")
	check(choose({}, nil) == nil, "Recompensa: sin daño de jugadores no hay recompensa")

	local availableQuests = 0
	for _, quest in Config.Quests do
		if Config.IsQuestAvailable(quest) then
			availableQuests += 1
		end
	end
	check(availableQuests > 0, "No hay ninguna misión disponible")

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

-- Prueba en vivo (unos segundos después de empezar): los monstruos que han aparecido
-- están bien colocados, y uno muere y reaparece correctamente.
function Tests.RunLive(modules)
	local passed, failed = 0, 0
	local function check(condition, message)
		if condition then
			passed += 1
		else
			failed += 1
			warn("[Autocomprobación en vivo] ✗ " .. message)
		end
	end
	local Monsters = modules.Monsters
	local safe = Config.SafeZone

	local slots = Monsters.GetSlots()
	local living = 0
	for _, slot in slots do
		if slot.Model then
			living += 1
		end
	end
	check(living > 0, "No ha aparecido ningún monstruo")

	-- Cada monstruo vivo: en su grupo de colisión, controlado por el servidor, en el suelo,
	-- fuera de la zona segura y con un solo modelo por sitio
	local seen = {}
	for model, state in Monsters.GetActive() do
		local root = state.Root
		check(not seen[state.Slot], model.Name .. ": dos monstruos en el mismo sitio")
		seen[state.Slot] = true
		check(model.Parent ~= nil, model.Name .. ": está activo pero no en el mundo")
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part.CollisionGroup ~= modules.Physics.MONSTERS then
				check(false, model.Name .. ": la pieza " .. part.Name .. " no está en el grupo Monsters")
				break
			end
		end
		check(root:GetNetworkOwner() == nil, model.Name .. ": su física no la controla el servidor")
		check(root.Position.Y > -5 and root.Position.Y < 12, model.Name .. ": no está en el suelo")
		local gap = Vector3.new(root.Position.X - safe.Center.X, 0, root.Position.Z - safe.Center.Z).Magnitude
		check(gap > safe.Radius, model.Name .. ": está dentro de la zona segura")
		check(state.Humanoid:GetStateEnabled(Enum.HumanoidStateType.Seated) == false, model.Name .. ": puede sentarse")
	end
	for _, player in game:GetService("Players"):GetPlayers() do
		local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			check(rootPart.CollisionGroup == modules.Physics.PLAYERS, player.Name .. ": no está en el grupo Players")
		end
	end

	-- Muerte y reaparición: matar a uno (sin jugador, así no da recompensa a nadie)
	local victim, victimSlot
	for _, state in Monsters.GetActive() do
		if state.Mode == "Idle" then
			victim, victimSlot = state, state.Slot
			break
		end
	end
	if not victim then
		print("[Autocomprobación en vivo] · No había ningún monstruo tranquilo para probar la reaparición")
	else
		local def = victim.Def
		local diedCount = 0
		victim.Humanoid.Died:Connect(function()
			diedCount += 1
		end)
		local oldModel = victim.Model
		Monsters.Damage(victim, nil, victim.Humanoid.MaxHealth * 10)
		Monsters.Damage(victim, nil, 50) -- un golpe de más no debe hacer nada
		task.wait(0.2)
		check(victim.Dead and diedCount == 1, "Muerte: debería procesarse exactamente una vez")
		check(victimSlot.Model == nil, "Muerte: el sitio debería quedar libre")
		check(oldModel:GetAttribute("AIState") == "Dead", "Muerte: el monstruo sigue activo")
		check(oldModel:FindFirstChild("HealthBar", true) == nil, "Muerte: la barra de vida no se quitó")
		check(#oldModel:GetDescendants() > 5, "Muerte: el cuerpo se rompió (explosión de Roblox)")

		task.wait(Config.MonsterSetting(def, "CorpseTime") + 0.3)
		check(oldModel.Parent == nil, "Muerte: el cuerpo no se ha borrado")

		local deadline = os.clock() + Config.MonsterSetting(def, "RespawnTime") + 6
		while os.clock() < deadline and not victimSlot.Model do
			task.wait(0.5)
		end
		check(victimSlot.Model ~= nil and victimSlot.Model ~= oldModel, "Reaparecer: no volvió a aparecer")
		if victimSlot.Model then
			local state = Monsters.GetActive()[victimSlot.Model]
			check(state ~= nil and state.Humanoid.Health == state.Humanoid.MaxHealth, "Reaparecer: sin la vida llena")
			check(state ~= nil and state.Target == nil and state.Mode == "Idle", "Reaparecer: no empezó tranquilo")
			check(victimSlot.Model:FindFirstChild("HealthBar", true) ~= nil, "Reaparecer: sin barra de vida")
			local home = victimSlot.Home
			local position = victimSlot.Model:GetPivot().Position
			check(
				Vector3.new(position.X - home.X, 0, position.Z - home.Z).Magnitude < 4,
				"Reaparecer: no salió en su sitio"
			)
		end
	end

	local total = passed + failed
	if failed == 0 then
		print(string.format("[Autocomprobación en vivo] ✓ Monstruos: %d/%d comprobaciones correctas", passed, total))
	else
		warn(string.format("[Autocomprobación en vivo] Monstruos: %d de %d comprobaciones fallaron", failed, total))
	end
end

return Tests
