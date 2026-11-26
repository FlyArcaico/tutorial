-- Monta monstruos hechos en Blender (MeshParts importadas con "Importar 3D").
--
-- Cada monstruo tiene:
--   * Su modelo importado en ServerStorage.MonsterModels.<Nombre> (assets/models/<Nombre>.rbxm),
--     con una MeshPart por pieza R15 (LowerTorso, Head, RightHand...).
--   * Sus medidas en server/MonsterRigs/<Nombre>.luau (las genera el script de Blender):
--     centro y tamaño de cada pieza y dónde va cada articulación.
--
-- El importador de Roblox puede cambiar la escala y girar los ejes según sus ajustes, así que
-- aquí se averigua solo: se comparan las posiciones de las piezas importadas con las de
-- Blender y se busca el giro y la escala que mejor encajan. Si el modelo no encaja (falta
-- una pieza, se importó mal...), no se usa y el juego vuelve al diseño de piezas de siempre.
local ServerStorage = game:GetService("ServerStorage")

local RigData = script.Parent.MonsterRigs

local MeshRig = {}

-- Blender: mira hacia -Y, arriba +Z, su derecha es -X.
-- Juego: mira hacia -Z, arriba +Y, su derecha es +X.
-- (columnas = adónde va cada eje de Blender)
local BLENDER_TO_GAME =
	CFrame.fromMatrix(Vector3.zero, Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 1, 0))

local cache = {} -- [nombre] = calibración (o false si no se puede usar)

-- Los 24 giros de 90° posibles (cómo pudo girar los ejes el importador)
local ROTATIONS = {}
do
	local axes = { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis }
	for i, a in axes do
		for j, b in axes do
			if i ~= j then
				for _, sa in { 1, -1 } do
					for _, sb in { 1, -1 } do
						local x, y = a * sa, b * sb
						table.insert(ROTATIONS, CFrame.fromMatrix(Vector3.zero, x, y, x:Cross(y)))
					end
				end
			end
		end
	end
end

local function findPart(template, name)
	for _, descendant in template:GetDescendants() do
		if descendant.Name == name and descendant:IsA("BasePart") then
			return descendant
		end
	end
	-- A veces el importador mete cada malla en un Model con su nombre
	local holder = template:FindFirstChild(name, true)
	return holder and holder:FindFirstChildWhichIsA("BasePart", true)
end

local function absVector(v)
	return Vector3.new(math.abs(v.X), math.abs(v.Y), math.abs(v.Z))
end

local function calibrate(name)
	local folder = ServerStorage:FindFirstChild("MonsterModels")
	local template = folder and folder:FindFirstChild(name)
	if not template then
		return nil, "no está el modelo importado ServerStorage.MonsterModels." .. name
	end
	local dataModule = RigData:FindFirstChild(name)
	if not dataModule then
		return nil, "faltan sus medidas (server/MonsterRigs/" .. name .. ".luau)"
	end
	local data = require(dataModule)

	-- Posiciones importadas (P) y de Blender (B) de cada pieza
	local names, imported, blender = {}, {}, {}
	for partName, info in data.Parts do
		local part = findPart(template, partName)
		if not part then
			return nil, "al modelo importado le falta la pieza " .. partName
		end
		table.insert(names, partName)
		imported[partName] = part
		blender[partName] = info.Center
	end

	local meanP, meanB = Vector3.zero, Vector3.zero
	for _, partName in names do
		meanP += imported[partName].Position
		meanB += blender[partName]
	end
	meanP /= #names
	meanB /= #names

	-- Probar los 24 giros: el bueno es el que deja las piezas en su sitio con una escala
	local best, bestError, bestScale = nil, math.huge, 0
	for _, rotation in ROTATIONS do
		local dot, norm = 0, 0
		for _, partName in names do
			local q = rotation * (blender[partName] - meanB)
			dot += (imported[partName].Position - meanP):Dot(q)
			norm += q:Dot(q)
		end
		local scale = dot / norm
		if scale > 0 then
			local err = 0
			for _, partName in names do
				local q = rotation * (blender[partName] - meanB)
				err += ((imported[partName].Position - meanP) - q * scale).Magnitude ^ 2
			end
			if err < bestError then
				best, bestError, bestScale = rotation, err, scale
			end
		end
	end
	if not best then
		return nil, "no se pudo averiguar cómo se importó"
	end
	-- Error medio por pieza, comparado con el tamaño del modelo
	local spread = 0
	for _, partName in names do
		spread += (imported[partName].Position - meanP).Magnitude ^ 2
	end
	if spread < 1e-6 then
		return nil, "todas las piezas importadas están en el mismo sitio"
	end
	if bestError / spread > 0.01 then
		return nil, string.format("las piezas importadas no están donde deberían (error %.3f)", bestError / spread)
	end

	-- Comprobar también los tamaños de cada pieza
	local parts = {}
	for _, partName in names do
		local part = imported[partName]
		local expected = absVector(best * (data.Parts[partName].Size * bestScale))
		local actual = absVector(part.CFrame.Rotation * part.Size)
		if (expected - actual).Magnitude > 0.2 * expected.Magnitude + 0.05 * bestScale then
			return nil, "el tamaño de la pieza " .. partName .. " no coincide con el de Blender"
		end
		parts[partName] = {
			Template = part,
			-- Giro de la pieza en el juego (relativo al monstruo)
			Rotation = BLENDER_TO_GAME * best:Inverse() * part.CFrame.Rotation,
		}
	end

	return {
		Data = data,
		Scale = bestScale, -- studs importados por cada unidad de Blender
		Parts = parts,
	}
end

local function getCalibration(name)
	if cache[name] == nil then
		local calibration, reason = calibrate(name)
		cache[name] = calibration or false
		if not calibration then
			warn(
				"[Slime Rebirth] Modelo 3D " .. name .. " no disponible: " .. reason .. ". Se usa el diseño de piezas."
			)
		end
	end
	return cache[name] or nil
end

-- ¿Está el modelo importado y encaja con sus medidas?
function MeshRig.IsReady(name)
	return getCalibration(name) ~= nil
end

-- Por qué no se puede usar (para la autocomprobación)
function MeshRig.Problem(name)
	local _, reason = calibrate(name)
	return reason
end

-- Monta el monstruo alrededor de su HumanoidRootPart. `scale` = 1 a tamaño normal.
-- Crea las articulaciones (Motor6D) con los nombres de R15, con los ejes alineados con
-- el cuerpo, igual que los demás monstruos: así las animaciones funcionan sin cambios.
function MeshRig.Build(name, root, scale, model)
	local calibration = getCalibration(name)
	assert(calibration, "MeshRig.Build sin modelo disponible: " .. name)
	local data = calibration.Data

	local function offset(blenderPoint)
		return CFrame.new(BLENDER_TO_GAME * (blenderPoint - data.Root) * scale)
	end

	local byName = { HumanoidRootPart = root }
	for partName, info in data.Parts do
		local source = calibration.Parts[partName]
		local part = source.Template:Clone()
		for _, child in part:GetChildren() do
			if child:IsA("JointInstance") or child:IsA("WeldConstraint") then
				child:Destroy()
			end
		end
		part.Name = partName
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = true
		part.Size = source.Template.Size * (scale / calibration.Scale)
		part.CFrame = root.CFrame * offset(info.Center) * source.Rotation
		part.Parent = model
		byName[partName] = part
	end

	for _, joint in data.Joints do
		local part0, part1 = byName[joint.Part0], byName[joint.Part1]
		local pivot = root.CFrame * offset(joint.Position)
		local motor = Instance.new("Motor6D")
		motor.Name = joint.Name
		motor.Part0 = part0
		motor.Part1 = part1
		motor.C0 = part0.CFrame:ToObjectSpace(pivot)
		motor.C1 = part1.CFrame:ToObjectSpace(pivot)
		motor.Parent = part1
	end
	return byName
end

return MeshRig
