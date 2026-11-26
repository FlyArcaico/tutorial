-- Autocomprobación del cliente (solo en Roblox Studio): reproduce todas las animaciones en
-- varios momentos para ver que no dan errores ni posiciones imposibles, y monta la cara
-- del Slime con todas sus expresiones.
local AnimationData = require(script.Parent.AnimationData)
local SlimeFace = require(script.Parent.SlimeFace)

local Tests = {}

local function valid(cframe, maxOffset)
	local position = cframe.Position
	local look = cframe.LookVector
	return position == position and look == look and position.Magnitude < maxOffset
end

function Tests.Run()
	local passed, failed = 0, 0
	local function check(condition, message)
		if condition then
			passed += 1
		else
			failed += 1
			warn("[Autocomprobación] ✗ " .. message)
		end
	end

	local function checkAnimation(name, animation)
		check(animation.Length > 0 and #animation.Frames >= 2, name .. ": necesita al menos 2 fotogramas")
		for step = 0, 10 do
			local pose = AnimationData.Sample(animation, animation.Length * step / 10)
			for joint, cframe in pose do
				-- Solo la cadera (Root) se desplaza mucho (por ejemplo, al caer muerto)
				check(valid(cframe, if joint == "Root" then 4 else 0.5), name .. ": pose inválida en " .. joint)
			end
		end
	end

	for name, animation in AnimationData.Animations do
		checkAnimation(name, animation)
	end

	-- Cada raza: reposo, andar y correr mueven todo el cuerpo; guardias existen
	for raceId, set in AnimationData.Sets do
		for _, kind in { "Idle", "Walk", "Run" } do
			local animation = set[kind]
			check(animation ~= nil, raceId .. ": falta " .. kind)
			if animation then
				checkAnimation(raceId .. "." .. kind, animation)
				local pose = AnimationData.Sample(animation, 0)
				for _, joint in AnimationData.Joints do
					check(pose[joint] ~= nil, raceId .. "." .. kind .. ": falta la articulación " .. joint)
				end
			end
		end
		check(set.Guard ~= nil and set.GuardSword ~= nil, raceId .. ": faltan las guardias")
	end

	-- Monstruos R15 (Goblin): reposo, andar y correr mueven todo el cuerpo; ataque válido
	for monsterId, set in AnimationData.Monster do
		for _, kind in { "Idle", "Walk", "Run", "Attack" } do
			local animation = set[kind]
			check(animation ~= nil, monsterId .. ": falta " .. kind)
			if animation then
				checkAnimation(monsterId .. "." .. kind, animation)
			end
		end
		for _, kind in { "Idle", "Walk", "Run" } do
			local pose = AnimationData.Sample(set[kind], 0)
			for _, joint in AnimationData.Joints do
				check(pose[joint] ~= nil, monsterId .. "." .. kind .. ": falta la articulación " .. joint)
			end
		end
	end

	-- Morir debe acabar con el cuerpo tumbado y bajado al suelo
	local lying = AnimationData.Sample(AnimationData.Animations.Death, AnimationData.Animations.Death.Length)
	check(lying.Root.Position.Y < -1.5, "Morir: el cuerpo no baja hasta el suelo")

	-- Los combos de espada usan animaciones que existen
	for rarity, combo in AnimationData.SwordCombos do
		for _, name in combo do
			check(AnimationData.Animations[name] ~= nil, "Combo " .. rarity .. ": falta " .. name)
		end
	end

	-- La cara del Slime: montar todas las expresiones sobre placas de prueba
	local body = Instance.new("Model")
	for _, name in { "FaceRightEye", "FaceLeftEye" } do
		local plate = Instance.new("Part")
		plate.Name = name
		plate.Parent = body
	end
	local face = SlimeFace.Attach(body)
	check(face ~= nil, "La cara del Slime no se pudo montar")
	if face then
		for _, expression in SlimeFace.Expressions do
			local ok = pcall(face.Set, face, expression)
			check(ok and face.Current == expression, "Expresión del Slime: " .. expression)
		end
	end
	body:Destroy()

	local total = passed + failed
	if failed == 0 then
		print(string.format("[Autocomprobación] ✓ Cliente: %d/%d comprobaciones correctas", passed, total))
	else
		warn(string.format("[Autocomprobación] Cliente: %d de %d comprobaciones fallaron", failed, total))
	end
end

return Tests
