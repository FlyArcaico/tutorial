-- Autocomprobación del cliente (solo en Roblox Studio): reproduce todas las animaciones en
-- varios momentos para ver que no dan errores ni posiciones imposibles.
local AnimationData = require(script.Parent.AnimationData)

local Tests = {}

local BASE_JOINTS = { "Torso", "Head", "RightShoulder", "LeftShoulder", "RightHip", "LeftHip" }

local function valid(cframe)
	local position = cframe.Position
	local look = cframe.LookVector
	return position == position and look == look and position.Magnitude < 5
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

	for name, animation in AnimationData.Animations do
		check(animation.Length > 0 and #animation.Frames >= 2, name .. ": necesita al menos 2 fotogramas")
		for step = 0, 10 do
			local pose = AnimationData.Sample(animation, animation.Length * step / 10)
			for joint, cframe in pose do
				check(valid(cframe), name .. ": pose inválida en " .. joint)
			end
		end
	end

	-- Las animaciones de base tienen que mover todo el cuerpo
	for _, name in { "Idle", "Walk", "Run" } do
		local pose = AnimationData.Sample(AnimationData.Animations[name], 0)
		for _, joint in BASE_JOINTS do
			check(pose[joint] ~= nil, name .. ": falta la articulación " .. joint)
		end
	end

	-- Los combos de espada usan animaciones que existen
	for rarity, combo in AnimationData.SwordCombos do
		for _, name in combo do
			check(AnimationData.Animations[name] ~= nil, "Combo " .. rarity .. ": falta " .. name)
		end
	end

	local total = passed + failed
	if failed == 0 then
		print(string.format("[Autocomprobación] ✓ Cliente: %d/%d comprobaciones correctas", passed, total))
	else
		warn(string.format("[Autocomprobación] Cliente: %d de %d comprobaciones fallaron", failed, total))
	end
end

return Tests
