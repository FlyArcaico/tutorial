-- Animaciones de los personajes R6, hechas con fotogramas clave (como en el Animation Editor).
--
-- Cada pose usa grados y nombres fáciles:
--   Brazos/piernas: { pitch, out, twist }
--     pitch > 0 = hacia delante, out > 0 = abrir hacia fuera, twist = girar sobre sí mismo
--   Torso: { lean = inclinar adelante, roll = ladear a la derecha, yaw = girar a la derecha,
--            up = subir/bajar (studs), forward = adelantar (studs) }
--   Head:  { pitch = mirar abajo, roll, yaw = girar a la derecha }
-- Una articulación que no aparece en una animación no se toca (así las de "solo brazos"
-- se pueden poner encima de andar o correr).
local AnimationData = {}

local rad = math.rad

--------------------------------------------------------------------------------
-- Conversión de poses "fáciles" a los Motor6D de R6
--------------------------------------------------------------------------------

-- En R6, el hombro/cadera derechos y los izquierdos están girados al revés
local function limb(values, isLeft)
	local pitch, out, twist = values[1] or 0, values[2] or 0, values[3] or 0
	if isLeft then
		return CFrame.Angles(rad(-out), rad(-twist), rad(-pitch))
	end
	return CFrame.Angles(rad(-out), rad(twist), rad(pitch))
end

-- RootJoint y Neck: X = inclinar adelante, Y = ladear (a la izquierda), Z = girar (a la izquierda)
local function torso(values)
	return CFrame.new(0, -(values.forward or 0), values.up or 0)
		* CFrame.Angles(rad(values.lean or 0), rad(-(values.roll or 0)), rad(-(values.yaw or 0)))
end

local function head(values)
	return CFrame.Angles(rad(values.pitch or 0), rad(-(values.roll or 0)), rad(-(values.yaw or 0)))
end

local CONVERT = {
	RightShoulder = function(v)
		return limb(v, false)
	end,
	LeftShoulder = function(v)
		return limb(v, true)
	end,
	RightHip = function(v)
		return limb(v, false)
	end,
	LeftHip = function(v)
		return limb(v, true)
	end,
	Torso = torso,
	Head = head,
}

-- Nombres cortos en las poses -> articulación
local SHORT =
	{ RS = "RightShoulder", LS = "LeftShoulder", RH = "RightHip", LH = "LeftHip", Torso = "Torso", Head = "Head" }

-- Convierte una animación escrita a mano en fotogramas con CFrames listos para mezclar
local function compile(definition)
	local joints = {}
	for _, frame in definition.Frames do
		for short in frame.Pose do
			joints[SHORT[short]] = true
		end
	end

	local frames = {}
	local previous = {}
	for _, frame in definition.Frames do
		local compiled = { Time = frame.Time, Ease = frame.Ease or "Sine", CFrames = {} }
		for short, values in frame.Pose do
			previous[SHORT[short]] = CONVERT[SHORT[short]](values)
		end
		for joint in joints do
			compiled.CFrames[joint] = previous[joint] or CFrame.identity
		end
		table.insert(frames, compiled)
	end
	-- Los primeros fotogramas que no tenían una articulación usan la del primero que sí
	for joint in joints do
		local first = nil
		for _, frame in definition.Frames do
			for short, values in frame.Pose do
				if SHORT[short] == joint and not first then
					first = CONVERT[joint](values)
				end
			end
		end
		for _, frame in frames do
			if frame.CFrames[joint] == CFrame.identity and first then
				frame.CFrames[joint] = first
			else
				break
			end
		end
	end

	return {
		Length = definition.Length,
		Loop = definition.Loop == true,
		Frames = frames,
		Joints = joints,
	}
end

--------------------------------------------------------------------------------
-- Leer una animación en un momento dado
--------------------------------------------------------------------------------

local function ease(alpha, style)
	if style == "Linear" then
		return alpha
	elseif style == "Out" then -- empieza rápido (golpes)
		return 1 - (1 - alpha) ^ 3
	elseif style == "In" then
		return alpha ^ 2
	end
	return alpha * alpha * (3 - 2 * alpha) -- "Sine": suave en los dos extremos
end

-- Devuelve { [articulación] = CFrame } para el tiempo t
function AnimationData.Sample(animation, t)
	local frames = animation.Frames
	if animation.Loop then
		t %= animation.Length
	else
		t = math.clamp(t, 0, animation.Length)
	end
	for index = 1, #frames - 1 do
		local a, b = frames[index], frames[index + 1]
		if t <= b.Time then
			local span = b.Time - a.Time
			local alpha = if span > 0 then ease((t - a.Time) / span, b.Ease) else 1
			local pose = {}
			for joint, cframe in a.CFrames do
				pose[joint] = cframe:Lerp(b.CFrames[joint], alpha)
			end
			return pose
		end
	end
	return frames[#frames].CFrames
end

--------------------------------------------------------------------------------
-- Animaciones
--------------------------------------------------------------------------------

local function mirrorLimb(values)
	return { values[1], values[2], -(values[3] or 0) }
end

-- Crea el fotograma "espejo" (lado derecho <-> izquierdo) para ciclos de andar/correr
local function mirror(pose)
	local result = {}
	for key, values in pose do
		if key == "RS" then
			result.LS = mirrorLimb(values)
		elseif key == "LS" then
			result.RS = mirrorLimb(values)
		elseif key == "RH" then
			result.LH = mirrorLimb(values)
		elseif key == "LH" then
			result.RH = mirrorLimb(values)
		else
			local copy = table.clone(values)
			copy.yaw = -(values.yaw or 0)
			copy.roll = -(values.roll or 0)
			result[key] = copy
		end
	end
	return result
end

local function cycle(length, contact, passing)
	return compile({
		Length = length,
		Loop = true,
		Frames = {
			{ Time = 0, Pose = contact },
			{ Time = length * 0.25, Pose = passing },
			{ Time = length * 0.5, Pose = mirror(contact) },
			{ Time = length * 0.75, Pose = mirror(passing) },
			{ Time = length, Pose = contact },
		},
	})
end

local Anim = {}
AnimationData.Animations = Anim

-- Reposo: respira despacio
Anim.Idle = compile({
	Length = 3.2,
	Loop = true,
	Frames = {
		{
			Time = 0,
			Pose = {
				RS = { 2, 4 },
				LS = { 2, 4 },
				RH = { 0, 2 },
				LH = { 0, 2 },
				Torso = { up = 0 },
				Head = { pitch = 0 },
			},
		},
		{
			Time = 1.6,
			Pose = {
				RS = { 4, 7, 4 },
				LS = { 4, 7, 4 },
				RH = { 0, 2 },
				LH = { 0, 2 },
				Torso = { up = 0.05, lean = -1 },
				Head = { pitch = -3 },
			},
		},
		{
			Time = 3.2,
			Pose = {
				RS = { 2, 4 },
				LS = { 2, 4 },
				RH = { 0, 2 },
				LH = { 0, 2 },
				Torso = { up = 0 },
				Head = { pitch = 0 },
			},
		},
	},
})

-- Andar: pie derecho delante -> paso -> pie izquierdo delante -> paso
-- (el torso sube en el paso, baja al apoyar, y gira un poco con los hombros)
Anim.Walk = cycle(1.05, {
	RS = { -24, 5 },
	LS = { 24, 5 },
	RH = { 28, 1 },
	LH = { -24, 1 },
	Torso = { lean = 3, yaw = -5, up = -0.07, roll = 0 },
	Head = { yaw = 4, pitch = -2 },
}, {
	RS = { 0, 5 },
	LS = { 0, 5 },
	RH = { -8, 1 },
	LH = { 12, 1 },
	Torso = { lean = 3, yaw = 0, up = 0.07, roll = 2 },
	Head = { yaw = 0, pitch = -2 },
})

-- Correr: zancadas largas, cuerpo inclinado, brazos fuertes y una fase "en el aire"
Anim.Run = cycle(0.68, {
	RS = { -62, -6, 10 },
	LS = { 68, -6, -10 },
	RH = { 58, 2 },
	LH = { -50, 2 },
	Torso = { lean = 16, yaw = -9, up = -0.14, roll = 0 },
	Head = { pitch = -12, yaw = 7 },
}, {
	RS = { -8, -6 },
	LS = { 12, -6 },
	RH = { 12, 2 },
	LH = { 28, 2 },
	Torso = { lean = 16, yaw = 0, up = 0.2, roll = 3 },
	Head = { pitch = -12, yaw = 0 },
})

-- Saltar (subiendo) y caer
Anim.Jump = compile({
	Length = 0.3,
	Frames = {
		{ Time = 0, Pose = { RS = { 10, 10 }, LS = { 10, 10 }, RH = { 0 }, LH = { 0 }, Torso = { lean = 0 } } },
		{ Time = 0.18, Pose = { RS = { 35, 40 }, LS = { 35, 40 }, RH = { 40 }, LH = { -15 }, Torso = { lean = -5 } } },
		{ Time = 0.3, Pose = { RS = { 30, 45 }, LS = { 30, 45 }, RH = { 32 }, LH = { -10 }, Torso = { lean = -4 } } },
	},
})

Anim.Fall = compile({
	Length = 0.8,
	Loop = true,
	Frames = {
		{
			Time = 0,
			Pose = { RS = { 25, 70 }, LS = { 25, 70 }, RH = { 12, 6 }, LH = { -18, 6 }, Torso = { lean = 5 } },
		},
		{
			Time = 0.4,
			Pose = { RS = { 20, 80 }, LS = { 20, 80 }, RH = { 20, 6 }, LH = { -8, 6 }, Torso = { lean = 3 } },
		},
		{
			Time = 0.8,
			Pose = { RS = { 25, 70 }, LS = { 25, 70 }, RH = { 12, 6 }, LH = { -18, 6 }, Torso = { lean = 5 } },
		},
	},
})

-- Espada al hombro (solo brazo derecho, encima de andar/correr)
Anim.SwordCarry = compile({
	Length = 1,
	Loop = true,
	Frames = {
		{ Time = 0, Pose = { RS = { 118, -22, 25 } } },
		{ Time = 1, Pose = { RS = { 118, -22, 25 } } },
	},
})

-- Guardia con los puños: brazos cruzados delante de la cara, un poco agachado
Anim.Guard = compile({
	Length = 1.6,
	Loop = true,
	Frames = {
		{
			Time = 0,
			Pose = {
				RS = { 112, -40, 15 },
				LS = { 112, -40, 15 },
				Torso = { lean = 9, up = -0.25 },
				Head = { pitch = -8 },
			},
		},
		{
			Time = 0.8,
			Pose = {
				RS = { 108, -38, 15 },
				LS = { 108, -38, 15 },
				Torso = { lean = 8, up = -0.22 },
				Head = { pitch = -7 },
			},
		},
		{
			Time = 1.6,
			Pose = {
				RS = { 112, -40, 15 },
				LS = { 112, -40, 15 },
				Torso = { lean = 9, up = -0.25 },
				Head = { pitch = -8 },
			},
		},
	},
})

-- Guardia con espada: la espada en medio, de pie delante del cuerpo
Anim.GuardSword = compile({
	Length = 1,
	Loop = true,
	Frames = {
		{
			Time = 0,
			Pose = {
				RS = { 82, -48, 0 },
				LS = { 72, -55, 0 },
				Torso = { lean = 6, up = -0.2, yaw = 10 },
				Head = { pitch = -5, yaw = -8 },
			},
		},
		{
			Time = 1,
			Pose = {
				RS = { 82, -48, 0 },
				LS = { 72, -55, 0 },
				Torso = { lean = 6, up = -0.2, yaw = 10 },
				Head = { pitch = -5, yaw = -8 },
			},
		},
	},
})

-- Puñetazo: cargar hacia atrás -> golpe rápido -> volver. Con la otra mano en guardia.
local function punch(isLeft)
	local hit = {
		RS = { 92, -6, 0 },
		LS = { 55, -22, 0 },
		Torso = { yaw = 24, lean = 9 },
		Head = { yaw = -12, pitch = -4 },
	}
	local windup = {
		RS = { -22, 8, 0 },
		LS = { 62, -22, 0 },
		Torso = { yaw = -18, lean = 3 },
		Head = { yaw = 8 },
	}
	local rest = {
		RS = { 20, 6, 0 },
		LS = { 30, -10, 0 },
		Torso = { yaw = 0, lean = 3 },
		Head = { yaw = 0 },
	}
	local start = { RS = { 5, 5 }, LS = { 5, 5 }, Torso = { yaw = 0 }, Head = { yaw = 0 } }
	if isLeft then
		hit, windup, rest, start = mirror(hit), mirror(windup), mirror(rest), mirror(start)
	end
	return compile({
		Length = 0.36,
		Frames = {
			{ Time = 0, Pose = start },
			{ Time = 0.1, Pose = windup },
			{ Time = 0.19, Pose = hit, Ease = "Out" },
			{ Time = 0.36, Pose = rest },
		},
	})
end
Anim.PunchRight = punch(false)
Anim.PunchLeft = punch(true)

-- Tajos de espada (cortos). Empiezan y acaban con la espada al hombro.
local CARRY = { 118, -22, 25 }
Anim.SlashA = compile({ -- diagonal, de arriba a la derecha hacia abajo a la izquierda
	Length = 0.42,
	Frames = {
		{ Time = 0, Pose = { RS = CARRY, LS = { 10, 8 }, Torso = { yaw = 0, lean = 2 } } },
		{ Time = 0.13, Pose = { RS = { 160, 35, 0 }, LS = { 25, 12 }, Torso = { yaw = -26, lean = -2 } } },
		{ Time = 0.24, Pose = { RS = { 48, -48, 0 }, LS = { 15, 12 }, Torso = { yaw = 30, lean = 12 } }, Ease = "Out" },
		{ Time = 0.42, Pose = { RS = { 100, -22, 15 }, LS = { 8, 6 }, Torso = { yaw = 6, lean = 4 } } },
	},
})
Anim.SlashB = compile({ -- horizontal, de izquierda a derecha
	Length = 0.42,
	Frames = {
		{ Time = 0, Pose = { RS = CARRY, LS = { 10, 8 }, Torso = { yaw = 0, lean = 2 } } },
		{ Time = 0.12, Pose = { RS = { 92, -68, -20 }, LS = { 30, 15 }, Torso = { yaw = 34, lean = 4 } } },
		{
			Time = 0.24,
			Pose = { RS = { 98, 55, -20 }, LS = { 20, 15 }, Torso = { yaw = -34, lean = 9 } },
			Ease = "Out",
		},
		{ Time = 0.42, Pose = { RS = { 105, -15, 15 }, LS = { 8, 6 }, Torso = { yaw = -4, lean = 4 } } },
	},
})
Anim.SlashC = compile({ -- de arriba abajo con las dos manos
	Length = 0.5,
	Frames = {
		{ Time = 0, Pose = { RS = CARRY, LS = { 10, 8 }, Torso = { lean = 2, up = 0 } } },
		{ Time = 0.17, Pose = { RS = { 172, -5 }, LS = { 165, -12 }, Torso = { lean = -8, up = 0.05 } } },
		{ Time = 0.3, Pose = { RS = { 42, -12 }, LS = { 38, -18 }, Torso = { lean = 20, up = -0.22 } }, Ease = "Out" },
		{ Time = 0.5, Pose = { RS = { 100, -20, 15 }, LS = { 10, 8 }, Torso = { lean = 4, up = 0 } } },
	},
})
Anim.SlashSpin = compile({ -- giro completo con la espada extendida (espadas míticas)
	Length = 0.55,
	Frames = {
		{ Time = 0, Pose = { RS = { 90, 70 }, LS = { 20, 40 }, Torso = { yaw = 0, lean = 6 } } },
		{ Time = 0.12, Pose = { RS = { 90, 72 }, LS = { 20, 40 }, Torso = { yaw = 90, lean = 8 } }, Ease = "Linear" },
		{ Time = 0.24, Pose = { RS = { 90, 72 }, LS = { 20, 40 }, Torso = { yaw = 180, lean = 8 } }, Ease = "Linear" },
		{ Time = 0.36, Pose = { RS = { 90, 72 }, LS = { 20, 40 }, Torso = { yaw = 270, lean = 8 } }, Ease = "Linear" },
		{ Time = 0.46, Pose = { RS = { 90, 70 }, LS = { 20, 40 }, Torso = { yaw = 360, lean = 6 } }, Ease = "Linear" },
		{ Time = 0.55, Pose = { RS = { 105, -15, 15 }, LS = { 10, 8 }, Torso = { yaw = 360, lean = 3 } } },
	},
})

-- Ogre: levanta los dos brazos y machaca
Anim.Smash = compile({
	Length = 0.62,
	Frames = {
		{ Time = 0, Pose = { RS = { 5, 5 }, LS = { 5, 5 }, Torso = { lean = 2, up = 0 } } },
		{ Time = 0.26, Pose = { RS = { 172, 12 }, LS = { 172, 12 }, Torso = { lean = -10, up = 0.06 } } },
		{ Time = 0.37, Pose = { RS = { 55, -15 }, LS = { 55, -15 }, Torso = { lean = 22, up = -0.35 } }, Ease = "Out" },
		{ Time = 0.62, Pose = { RS = { 8, 6 }, LS = { 8, 6 }, Torso = { lean = 3, up = 0 } } },
	},
})

-- Invocado: mano derecha hacia delante como lanzando magia
Anim.Cast = compile({
	Length = 0.46,
	Frames = {
		{ Time = 0, Pose = { RS = { 5, 5 }, LS = { 5, 5 }, Torso = { yaw = 0, lean = 2 } } },
		{ Time = 0.1, Pose = { RS = { 40, 20, -20 }, LS = { 25, 15 }, Torso = { yaw = -10, lean = 0 } } },
		{ Time = 0.2, Pose = { RS = { 90, 6, -30 }, LS = { 30, 18 }, Torso = { yaw = 16, lean = 6 } }, Ease = "Out" },
		{ Time = 0.32, Pose = { RS = { 88, 6, -30 }, LS = { 30, 18 }, Torso = { yaw = 14, lean = 5 } } },
		{ Time = 0.46, Pose = { RS = { 8, 5 }, LS = { 8, 5 }, Torso = { yaw = 0, lean = 2 } } },
	},
})

-- Combos de espada según la rareza: las mejores espadas tienen más golpes
AnimationData.SwordCombos = {
	Common = { "SlashA", "SlashB" },
	Rare = { "SlashA", "SlashB" },
	Epic = { "SlashA", "SlashB", "SlashC" },
	Legendary = { "SlashA", "SlashB", "SlashC" },
	Mythic = { "SlashA", "SlashB", "SlashC", "SlashSpin" },
}

return AnimationData
