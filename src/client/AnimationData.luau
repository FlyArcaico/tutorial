-- Animaciones de los personajes (R15), hechas con fotogramas clave como en el Animation Editor.
--
-- Articulaciones (nombres cortos):
--   Root (cadera/cuerpo entero), Waist (cintura), Neck (cuello)
--   RS/LS hombros, RE/LE codos, RW/LW muñecas
--   RH/LH caderas, RK/LK rodillas, RA/LA tobillos
-- Valores en grados:
--   Hombros y caderas: { pitch = adelante, out = abrir hacia fuera, twist = girar }
--   Codos: { doblar }   Rodillas: { doblar }   Tobillos: { punta arriba }
--   Muñecas: { arriba/abajo, ladear }
--   Root / Waist: { lean = inclinar adelante, yaw = girar a la derecha, roll = ladear a la
--                   derecha, up = subir/bajar en studs, forward = adelantar en studs }
--   Neck: { pitch = mirar abajo, yaw = mirar a la derecha, roll }
-- Una articulación que no aparece en una animación "de encima" (golpe, guardia...) no se
-- toca: así se puede golpear mientras se anda o se corre.
local AnimationData = {}

local rad = math.rad

AnimationData.Joints =
	{ "Root", "Waist", "Neck", "RS", "RE", "RW", "LS", "LE", "LW", "RH", "RK", "RA", "LH", "LK", "LA" }

--------------------------------------------------------------------------------
-- Conversión de poses "fáciles" a los Motor6D de R15
-- (en R15 todos los Motor6D tienen los ejes alineados con el cuerpo)
--------------------------------------------------------------------------------

local function limb(isLeft)
	return function(v)
		local pitch, out, twist = v[1] or 0, v[2] or 0, v[3] or 0
		if isLeft then
			return CFrame.Angles(rad(pitch), rad(-twist), rad(-out))
		end
		return CFrame.Angles(rad(pitch), rad(twist), rad(out))
	end
end

local function hinge(sign)
	return function(v)
		return CFrame.Angles(rad((v[1] or 0) * sign), 0, 0)
	end
end

local function wrist(isLeft)
	return function(v)
		return CFrame.Angles(rad(v[1] or 0), 0, rad((v[2] or 0) * (if isLeft then -1 else 1)))
	end
end

local function bodyJoint(v)
	return CFrame.new(v.side or 0, v.up or 0, -(v.forward or 0))
		* CFrame.Angles(rad(-(v.lean or 0)), rad(-(v.yaw or 0)), rad(-(v.roll or 0)))
end

local function neckJoint(v)
	return CFrame.Angles(rad(-(v.pitch or 0)), rad(-(v.yaw or 0)), rad(-(v.roll or 0)))
end

local CONVERT = {
	Root = bodyJoint,
	Waist = bodyJoint,
	Neck = neckJoint,
	RS = limb(false),
	LS = limb(true),
	RH = limb(false),
	LH = limb(true),
	RE = hinge(1), -- el antebrazo se dobla hacia delante
	LE = hinge(1),
	RK = hinge(-1), -- la pierna se dobla hacia atrás
	LK = hinge(-1),
	RA = hinge(1),
	LA = hinge(1),
	RW = wrist(false),
	LW = wrist(true),
}

-- Lado derecho <-> izquierdo (para hacer el segundo paso de un ciclo, el puñetazo izquierdo...)
local SWAP = {
	RS = "LS",
	LS = "RS",
	RE = "LE",
	LE = "RE",
	RW = "LW",
	LW = "RW",
	RH = "LH",
	LH = "RH",
	RK = "LK",
	LK = "RK",
	RA = "LA",
	LA = "RA",
}

local function mirror(pose)
	local result = {}
	for key, values in pose do
		if SWAP[key] then
			result[SWAP[key]] = values
		else
			local copy = table.clone(values)
			copy.yaw = -(values.yaw or 0)
			copy.roll = -(values.roll or 0)
			copy.side = -(values.side or 0)
			result[key] = copy
		end
	end
	return result
end
AnimationData.Mirror = mirror

-- Convierte una animación escrita a mano en fotogramas con CFrames listos para mezclar.
-- Si un fotograma no menciona una articulación, usa la del fotograma anterior (o el siguiente).
local function compile(definition)
	local joints = {}
	for _, frame in definition.Frames do
		for joint in frame.Pose do
			assert(CONVERT[joint], "Articulación desconocida en una animación: " .. tostring(joint))
			joints[joint] = true
		end
	end

	local frames = {}
	for index, frame in definition.Frames do
		local compiled = { Time = frame.Time, Ease = frame.Ease or "Sine", CFrames = {} }
		for joint in joints do
			local values = frame.Pose[joint]
			if not values then
				-- Buscar el fotograma anterior que la tenga; si no, el siguiente
				for back = index - 1, 1, -1 do
					values = definition.Frames[back].Pose[joint]
					if values then
						break
					end
				end
				if not values then
					for ahead = index + 1, #definition.Frames do
						values = definition.Frames[ahead].Pose[joint]
						if values then
							break
						end
					end
				end
			end
			compiled.CFrames[joint] = CONVERT[joint](values or {})
		end
		table.insert(frames, compiled)
	end

	return {
		Length = definition.Length,
		Loop = definition.Loop == true,
		Frames = frames,
		Joints = joints,
	}
end
AnimationData.Compile = compile

--------------------------------------------------------------------------------
-- Leer una animación en un momento dado
--------------------------------------------------------------------------------

local function ease(alpha, style)
	if style == "Linear" then
		return alpha
	elseif style == "Out" then -- empieza rápido (golpes)
		return 1 - (1 - alpha) ^ 3
	elseif style == "In" then -- empieza lento (caer)
		return alpha ^ 2
	end
	return alpha * alpha * (3 - 2 * alpha) -- "Sine": suave en los dos extremos
end

-- Devuelve una tabla nueva { [articulación] = CFrame } para el tiempo t
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
	return table.clone(frames[#frames].CFrames)
end

--------------------------------------------------------------------------------
-- Generadores: reposo, andar y correr a partir de unos pocos parámetros
-- (así cada raza tiene su forma de moverse sin repetir todo)
--------------------------------------------------------------------------------

-- Ciclo: apoyo derecho -> paso -> apoyo izquierdo -> paso
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

-- p: parámetros del movimiento (ver HUMAN_WALK para la lista)
local function locomotion(p)
	-- Pie derecho delante (talón apoyado) y pie izquierdo detrás (empujando)
	local contact = {
		Root = { lean = p.Lean, yaw = -p.HipTwist, up = -p.Bob, roll = 0 },
		Waist = { lean = p.ChestLean, yaw = p.ChestTwist },
		Neck = { pitch = p.HeadPitch, yaw = p.HipTwist - p.ChestTwist },
		RH = { p.Stride, p.LegOut },
		RK = { p.FrontKnee },
		RA = { p.HeelUp },
		LH = { -p.StrideBack, p.LegOut },
		LK = { p.BackKnee },
		LA = { -p.ToeOff },
		-- Brazos al revés que las piernas, separados del cuerpo y con el codo doblado
		RS = { -p.ArmBack, p.ArmOut },
		RE = { p.ElbowBack },
		RW = { 0 },
		LS = { p.ArmFront, p.ArmOut },
		LE = { p.ElbowFront },
		LW = { 0 },
	}
	-- Paso: la pierna izquierda pasa por delante con la rodilla alta; el cuerpo sube
	local passing = {
		Root = { lean = p.Lean, yaw = 0, up = p.Rise, roll = p.Roll },
		Waist = { lean = p.ChestLean, yaw = 0 },
		Neck = { pitch = p.HeadPitch, yaw = 0 },
		RH = { -4, p.LegOut },
		RK = { p.StanceKnee },
		RA = { 2 },
		LH = { p.SwingHip, p.LegOut },
		LK = { p.SwingKnee },
		LA = { p.SwingFoot },
		RS = { -p.ArmBack * 0.15, p.ArmOut },
		RE = { p.ElbowMid },
		RW = { 0 },
		LS = { p.ArmFront * 0.15, p.ArmOut },
		LE = { p.ElbowMid },
		LW = { 0 },
	}
	return cycle(p.Length, contact, passing)
end

-- Reposo vivo: respira, pasa el peso de una pierna a otra (la otra rodilla se relaja),
-- mira un poco alrededor y corrige la postura con pequeños ajustes de hombros y brazos.
-- Movimientos suaves y pequeños para que no parezca exagerado.
local function idle(p)
	-- breath: 0..1   shift: -1 (peso en la izquierda) .. 1 (derecha)
	-- look: giro de la cabeza (grados)   lookUp: mirar arriba/abajo   adjust: ajuste de brazos
	local function pose(breath, shift, look, lookUp, adjust)
		local rightRelax = math.max(0, -shift) -- si el peso está a la izquierda, se relaja la derecha
		local leftRelax = math.max(0, shift)
		return {
			Root = { up = p.Crouch + 0.03 * breath, roll = p.Shift * shift, side = 0.06 * shift },
			Waist = { lean = p.ChestLean - 2 * breath, yaw = p.ChestYaw + look * 0.2, roll = -p.Shift * 0.6 * shift },
			Neck = { pitch = p.HeadPitch - 2 * breath + lookUp, yaw = -p.ChestYaw + look * 0.8, roll = look * 0.08 },
			RS = { 3 + p.ArmForward + adjust, p.ArmOut + 2 * breath + shift * 1.5 },
			RE = { p.Elbow + adjust * 2 },
			RW = { p.Wrist },
			LS = { 3 + p.ArmForward - adjust * 0.5, p.ArmOut + 2 * breath - shift * 1.5 },
			LE = { p.Elbow - adjust },
			LW = { p.Wrist },
			RH = { 3 * rightRelax, p.LegOut },
			RK = { p.Knee + 9 * rightRelax },
			RA = { -3 * rightRelax },
			LH = { 3 * leftRelax, p.LegOut },
			LK = { p.Knee + 9 * leftRelax },
			LA = { -3 * leftRelax },
		}
	end
	local length = p.Length * 2.2
	return compile({
		Length = length,
		Loop = true,
		Frames = {
			{ Time = 0, Pose = pose(0, 0, 0, 0, 0) },
			{ Time = length * 0.2, Pose = pose(1, 0.6, 6, -2, 2) },
			{ Time = length * 0.4, Pose = pose(0, 1, 10, 1, 0) },
			{ Time = length * 0.6, Pose = pose(1, 0, -4, -3, -2) },
			{ Time = length * 0.8, Pose = pose(0, -0.8, -9, 2, 1) },
			{ Time = length, Pose = pose(0, 0, 0, 0, 0) },
		},
	})
end

local function with(base, changes)
	local result = table.clone(base)
	for key, value in changes do
		result[key] = value
	end
	return result
end

-- Human: equilibrado y natural
local HUMAN_WALK = {
	Length = 1.1,
	Stride = 26,
	StrideBack = 20,
	LegOut = 2,
	FrontKnee = 4,
	BackKnee = 16,
	HeelUp = 8,
	ToeOff = 14,
	StanceKnee = 6,
	SwingHip = 14,
	SwingKnee = 48,
	SwingFoot = 5,
	ArmBack = 22,
	ArmFront = 26,
	ArmOut = 9,
	ElbowBack = 12,
	ElbowFront = 28,
	ElbowMid = 18,
	Lean = 3,
	ChestLean = 1,
	Bob = 0.06,
	Rise = 0.06,
	Roll = 1.5,
	HipTwist = 6,
	ChestTwist = 9,
	HeadPitch = -1,
}
local HUMAN_RUN = with(HUMAN_WALK, {
	Length = 0.66,
	Stride = 52,
	StrideBack = 38,
	FrontKnee = 18,
	BackKnee = 55,
	HeelUp = 10,
	ToeOff = 25,
	StanceKnee = 25,
	SwingHip = 35,
	SwingKnee = 100,
	SwingFoot = 15,
	ArmBack = 50,
	ArmFront = 62,
	ArmOut = 12,
	ElbowBack = 70,
	ElbowFront = 95,
	ElbowMid = 85,
	Lean = 15,
	ChestLean = 4,
	Bob = 0.12,
	Rise = 0.16,
	Roll = 2,
	HipTwist = 9,
	ChestTwist = 14,
	HeadPitch = -12,
})
local HUMAN_IDLE = {
	Length = 3.4,
	Crouch = 0,
	Shift = 1.2,
	ChestLean = 0,
	ChestYaw = 0,
	HeadPitch = 0,
	ArmForward = 0,
	ArmOut = 7,
	Elbow = 12,
	Wrist = 0,
	LegOut = 3,
	Knee = 3,
}

-- Elf: ligero, ágil y elegante (pasos más altos y "saltarines")
local ELF_WALK = with(HUMAN_WALK, {
	Length = 0.95,
	Stride = 24,
	SwingKnee = 58,
	ArmFront = 18,
	ArmBack = 16,
	ArmOut = 12,
	ElbowFront = 32,
	ElbowBack = 20,
	ElbowMid = 26,
	Lean = 1,
	Bob = 0.08,
	Rise = 0.09,
	ChestTwist = 6,
	HeadPitch = -3,
})
local ELF_RUN = with(HUMAN_RUN, {
	Length = 0.6,
	Stride = 55,
	SwingKnee = 110,
	ArmFront = 50,
	ArmBack = 42,
	ArmOut = 14,
	ElbowFront = 85,
	ElbowBack = 65,
	Lean = 12,
	Rise = 0.2,
})
local ELF_IDLE = with(HUMAN_IDLE, { Shift = 3, ArmOut = 6, Elbow = 14, HeadPitch = -3, Length = 3.8 })

-- Ogre: pesado y poderoso (piernas abiertas, se balancea, brazos separados)
local OGRE_WALK = with(HUMAN_WALK, {
	Length = 1.3,
	Stride = 22,
	StrideBack = 18,
	LegOut = 8,
	StanceKnee = 12,
	SwingKnee = 40,
	ArmOut = 22,
	ArmFront = 20,
	ArmBack = 18,
	ElbowFront = 32,
	ElbowBack = 26,
	ElbowMid = 28,
	Lean = 7,
	ChestLean = 4,
	Bob = 0.12,
	Rise = 0.1,
	Roll = 4,
	HipTwist = 8,
	ChestTwist = 12,
	HeadPitch = 4,
})
local OGRE_RUN = with(HUMAN_RUN, {
	Length = 0.78,
	Stride = 44,
	LegOut = 8,
	StanceKnee = 28,
	SwingKnee = 85,
	ArmOut = 24,
	ArmFront = 55,
	ArmBack = 48,
	ElbowFront = 80,
	ElbowBack = 70,
	Lean = 18,
	Bob = 0.16,
	Rise = 0.14,
	Roll = 4,
	HeadPitch = -6,
})
local OGRE_IDLE = with(HUMAN_IDLE, {
	Length = 2.8,
	Crouch = -0.08,
	Shift = 2,
	ChestLean = 4,
	HeadPitch = 3,
	ArmOut = 18,
	Elbow = 22,
	LegOut = 9,
	Knee = 10,
})

-- Invocados: elegantes, con las manos un poco levantadas, listas para la magia
local SUMMONED_WALK = with(HUMAN_WALK, {
	Stride = 24,
	ArmFront = 14,
	ArmBack = 12,
	ArmOut = 14,
	ElbowFront = 34,
	ElbowBack = 26,
	ElbowMid = 30,
	Lean = 1,
	Bob = 0.05,
	Roll = 2,
	ChestTwist = 5,
})
local SUMMONED_RUN = with(HUMAN_RUN, { ArmOut = 14, ArmFront = 55, ArmBack = 45 })
local SUMMONED_IDLE = with(HUMAN_IDLE, { ArmForward = 8, ArmOut = 12, Elbow = 35, Wrist = -15, Shift = 1.5 })

-- Fuego: agresivo e inclinado hacia delante. Agua: fluido y ondulante.
local FIRE_WALK = with(SUMMONED_WALK, { Lean = 5, ArmFront = 22, ArmBack = 18, ChestTwist = 10, HeadPitch = 2 })
local FIRE_RUN = with(SUMMONED_RUN, { Lean = 18 })
local FIRE_IDLE = with(SUMMONED_IDLE, { ChestLean = 3, HeadPitch = 3, Elbow = 45 })
local WATER_WALK = with(SUMMONED_WALK, { Roll = 3.5, Bob = 0.04, Rise = 0.05, Length = 1.2, ChestTwist = 7 })
local WATER_RUN = with(SUMMONED_RUN, { Roll = 3 })
local WATER_IDLE = with(SUMMONED_IDLE, { Shift = 2.5, Length = 4 })

--------------------------------------------------------------------------------
-- Animaciones comunes
--------------------------------------------------------------------------------

local Anim = {}
AnimationData.Animations = Anim

-- Saltar (subiendo) y caer
Anim.Jump = compile({
	Length = 0.3,
	Frames = {
		{
			Time = 0,
			Pose = {
				Root = { lean = 0 },
				Waist = { lean = 0 },
				RS = { 10, 10 },
				RE = { 20 },
				LS = { 10, 10 },
				LE = { 20 },
				RH = { 10, 3 },
				RK = { 10 },
				LH = { 0, 3 },
				LK = { 10 },
			},
		},
		{
			Time = 0.18,
			Pose = {
				Root = { lean = -4 },
				Waist = { lean = -3 },
				RS = { 35, 28 },
				RE = { 40 },
				LS = { 35, 28 },
				LE = { 40 },
				RH = { 45, 3 },
				RK = { 70 },
				RA = { 10 },
				LH = { -8, 3 },
				LK = { 25 },
			},
		},
		{
			Time = 0.3,
			Pose = {
				Root = { lean = -3 },
				Waist = { lean = -2 },
				RS = { 30, 32 },
				RE = { 35 },
				LS = { 30, 32 },
				LE = { 35 },
				RH = { 38, 3 },
				RK = { 60 },
				LH = { -6, 3 },
				LK = { 22 },
			},
		},
	},
})

Anim.Fall = compile({
	Length = 0.9,
	Loop = true,
	Frames = {
		{
			Time = 0,
			Pose = {
				Waist = { lean = 4 },
				RS = { 20, 60 },
				RE = { 25 },
				LS = { 20, 60 },
				LE = { 25 },
				RH = { 20, 5 },
				RK = { 35 },
				LH = { -10, 5 },
				LK = { 45 },
			},
		},
		{
			Time = 0.45,
			Pose = {
				Waist = { lean = 2 },
				RS = { 15, 70 },
				RE = { 30 },
				LS = { 15, 70 },
				LE = { 30 },
				RH = { 25, 5 },
				RK = { 30 },
				LH = { -5, 5 },
				LK = { 40 },
			},
		},
		{
			Time = 0.9,
			Pose = {
				Waist = { lean = 4 },
				RS = { 20, 60 },
				RE = { 25 },
				LS = { 20, 60 },
				LE = { 25 },
				RH = { 20, 5 },
				RK = { 35 },
				LH = { -10, 5 },
				LK = { 45 },
			},
		},
	},
})

-- Aterrizar: flexiona las rodillas para amortiguar y vuelve a ponerse recto
local STAND = {
	Root = { up = 0, lean = 0 },
	Waist = { lean = 0 },
	RS = { 5, 8 },
	RE = { 15 },
	LS = { 5, 8 },
	LE = { 15 },
	RH = { 0, 3 },
	RK = { 4 },
	RA = { 0 },
	LH = { 0, 3 },
	LK = { 4 },
	LA = { 0 },
}
Anim.Land = compile({
	Length = 0.34,
	Frames = {
		{ Time = 0, Pose = STAND },
		{
			Time = 0.08,
			Ease = "Out",
			Pose = {
				Root = { up = -0.5, lean = 12 },
				Waist = { lean = 8 },
				RS = { 25, 25 },
				RE = { 40 },
				LS = { 25, 25 },
				LE = { 40 },
				RH = { 35, 6 },
				RK = { 70 },
				RA = { -20 },
				LH = { 35, 6 },
				LK = { 70 },
				LA = { -20 },
			},
		},
		{ Time = 0.34, Pose = STAND },
	},
})

-- Recibir daño: el cuerpo se va un poco hacia atrás y vuelve
Anim.Hurt = compile({
	Length = 0.36,
	Frames = {
		{ Time = 0, Pose = { Waist = { lean = 0, yaw = 0 }, Neck = { pitch = 0 }, Root = { forward = 0 } } },
		{
			Time = 0.07,
			Ease = "Out",
			Pose = {
				Waist = { lean = -14, yaw = 8 },
				Neck = { pitch = -18, yaw = -6 },
				Root = { forward = -0.18 },
				RS = { -12, 30 },
				RE = { 35 },
				LS = { -12, 30 },
				LE = { 35 },
			},
		},
		{
			Time = 0.36,
			Pose = {
				Waist = { lean = 0, yaw = 0 },
				Neck = { pitch = 0, yaw = 0 },
				Root = { forward = 0 },
				RS = { 5, 8 },
				RE = { 15 },
				LS = { 5, 8 },
				LE = { 15 },
			},
		},
	},
})

-- Morir: las rodillas ceden y cae de espaldas al suelo, donde se queda.
-- ("up" está pensado para un personaje de tamaño normal; el Animator lo escala.)
local LYING = {
	Root = { lean = -88, up = -2.35, forward = -0.6 },
	Waist = { lean = -4 },
	Neck = { pitch = -10, yaw = 15 },
	RS = { 10, 70 },
	RE = { 20 },
	LS = { -5, 75 },
	LE = { 35 },
	RH = { 8, 10 },
	RK = { 15 },
	RA = { 30 },
	LH = { -5, 12 },
	LK = { 25 },
	LA = { 30 },
}
Anim.Death = compile({
	Length = 1.3,
	Frames = {
		{ Time = 0, Pose = with(STAND, { Neck = { pitch = 0 } }) },
		{
			Time = 0.3,
			Pose = {
				Root = { up = -0.9, lean = 15 },
				Waist = { lean = 18 },
				Neck = { pitch = 25 },
				RS = { 10, 15 },
				RE = { 30 },
				LS = { 10, 15 },
				LE = { 30 },
				RH = { 40, 4 },
				RK = { 80 },
				RA = { -10 },
				LH = { 40, 4 },
				LK = { 80 },
				LA = { -10 },
			},
		},
		{ Time = 0.75, Ease = "In", Pose = LYING },
		{ Time = 0.9, Pose = with(LYING, { Root = { lean = -84, up = -2.2, forward = -0.6 } }) },
		{ Time = 1.05, Pose = LYING },
		{ Time = 1.3, Pose = LYING },
	},
})

--------------------------------------------------------------------------------
-- Espada al hombro, guardias y golpes
--------------------------------------------------------------------------------

-- Espada al hombro: el antebrazo hacia arriba y la hoja descansando sobre el hombro
local CARRY = { RS = { 60, 15 }, RE = { 100 }, RW = { -10 } }
Anim.SwordCarry = compile({
	Length = 1,
	Loop = true,
	Frames = { { Time = 0, Pose = CARRY }, { Time = 1, Pose = CARRY } },
})

-- Guardia de combate: pies separados (izquierdo delante), rodillas dobladas, cuerpo girado
-- de lado hacia el enemigo y la cabeza mirando al frente. Se mueve un poco (respira).
local function stance(p)
	local function pose(breath)
		return {
			Root = { yaw = -p.Turn, up = p.Crouch + 0.04 * breath, lean = p.Lean },
			Waist = { yaw = p.Turn * 0.45, lean = p.ChestLean },
			Neck = { yaw = p.Turn * 0.55, pitch = p.HeadPitch },
			RH = { -14, p.LegOut },
			RK = { p.Knee + 4 * breath },
			RA = { 8 },
			LH = { 26, p.LegOut * 0.8 },
			LK = { p.Knee - 2 + 4 * breath },
			LA = { -6 },
			RS = p.RS,
			RE = p.RE,
			RW = p.RW,
			LS = p.LS,
			LE = p.LE,
			LW = p.LW,
		}
	end
	return compile({
		Length = 1.6,
		Loop = true,
		Frames = {
			{ Time = 0, Pose = pose(0) },
			{ Time = 0.8, Pose = pose(1) },
			{ Time = 1.6, Pose = pose(0) },
		},
	})
end

-- Sin arma: guardia de boxeo (puño izquierdo delante, derecho protegiendo la barbilla)
-- Brazos cerca del cuerpo, codos muy doblados y los puños a la altura de la barbilla
local FIST_STANCE = {
	Turn = 22,
	Crouch = -0.3,
	Lean = 7,
	ChestLean = 5,
	HeadPitch = 9,
	LegOut = 8,
	Knee = 26,
	RS = { 28, 3 },
	RE = { 128 },
	RW = { -8 },
	LS = { 42, 1 },
	LE = { 120 },
	LW = { -8 },
}
-- Con espada: la empuñadura delante de la cintura y la hoja en diagonal, con la punta
-- hacia el enemigo; la mano izquierda ayuda a sujetarla. Los brazos no tocan el cuerpo.
-- (el agarre y la diagonal de la hoja se mantienen: brazo + codo + muñeca ≈ 54°)
local SWORD_STANCE = {
	Turn = 28,
	Crouch = -0.34,
	Lean = 7,
	ChestLean = 4,
	HeadPitch = 5,
	LegOut = 9,
	Knee = 28,
	RS = { 18, 5 },
	RE = { 66 },
	RW = { -30 },
	LS = { 28, -3 },
	LE = { 78 },
	LW = { 0 },
}
Anim.Guard = stance(FIST_STANCE)
Anim.GuardSword = stance(SWORD_STANCE)
-- Ogre: postura más ancha y baja, y la espada más alta (es más pesada)
Anim.GuardOgre = stance(with(FIST_STANCE, { LegOut = 13, Crouch = -0.4, RS = { 32, 8 }, LS = { 46, 6 } }))
Anim.GuardSwordOgre = stance(with(SWORD_STANCE, {
	LegOut = 13,
	Crouch = -0.42,
	RS = { 26, 9 },
	RE = { 72 },
	RW = { -24 },
	LS = { 34, 2 },
	LE = { 82 },
}))

-- Bloquear un golpe: el impacto empuja la guardia hacia atrás y vuelve (se pone encima de la guardia)
local function blockHit(base)
	local pushed = {
		Root = { yaw = -base.Turn, up = base.Crouch - 0.08, lean = base.Lean - 6, forward = -0.3 },
		Waist = { yaw = base.Turn * 0.45, lean = base.ChestLean - 10 },
		Neck = { yaw = base.Turn * 0.55, pitch = base.HeadPitch - 6 },
		RS = { base.RS[1] - 10, base.RS[2] + 3 },
		RE = { base.RE[1] + 8 },
		LS = { base.LS[1] - 12, base.LS[2] + 3 },
		LE = { base.LE[1] + 8 },
	}
	local settled = {
		Root = { yaw = -base.Turn, up = base.Crouch, lean = base.Lean, forward = 0 },
		Waist = { yaw = base.Turn * 0.45, lean = base.ChestLean },
		Neck = { yaw = base.Turn * 0.55, pitch = base.HeadPitch },
		RS = base.RS,
		RE = base.RE,
		LS = base.LS,
		LE = base.LE,
	}
	return compile({
		Length = 0.32,
		Frames = {
			{ Time = 0, Pose = settled },
			{ Time = 0.06, Pose = pushed, Ease = "Out" },
			{ Time = 0.32, Pose = settled },
		},
	})
end
Anim.BlockHit = blockHit(FIST_STANCE)
Anim.BlockHitSword = blockHit(SWORD_STANCE)

-- Puñetazo: cargar -> golpe rápido con el brazo estirado -> volver. La otra mano en guardia.
local function punch(isLeft)
	local start = {
		Root = { yaw = 0, lean = 0, forward = 0 },
		Waist = { yaw = 0, lean = 0 },
		Neck = { yaw = 0 },
		RS = { 10, 8 },
		RE = { 20 },
		LS = { 10, 8 },
		LE = { 20 },
	}
	local windup = {
		Root = { yaw = -6, lean = 2, forward = 0 },
		Waist = { yaw = -18, lean = 2 },
		Neck = { yaw = 12 },
		RS = { 25, 10 },
		RE = { 125 },
		LS = { 55, 8 },
		LE = { 100 },
	}
	local hit = {
		Root = { yaw = 8, lean = 4, forward = 0.15 },
		Waist = { yaw = 24, lean = 5 },
		Neck = { yaw = -20 },
		RS = { 88, 2 },
		RE = { 6 },
		LS = { 50, 8 },
		LE = { 105 },
	}
	local rest = {
		Root = { yaw = 0, lean = 0, forward = 0 },
		Waist = { yaw = 0, lean = 0 },
		Neck = { yaw = 0 },
		RS = { 30, 9 },
		RE = { 60 },
		LS = { 35, 8 },
		LE = { 70 },
	}
	if isLeft then
		start, windup, hit, rest = mirror(start), mirror(windup), mirror(hit), mirror(rest)
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

-- Tajos de espada cortos. Empiezan y acaban con la espada al hombro.
local CARRY_SLASH =
	{ RS = { 60, 15 }, RE = { 100 }, RW = { -10 }, LS = { 10, 10 }, LE = { 20 }, Waist = { yaw = 0, lean = 2 } }
Anim.SlashA = compile({ -- diagonal, de arriba a la derecha hacia abajo a la izquierda
	Length = 0.42,
	Frames = {
		{ Time = 0, Pose = CARRY_SLASH },
		{
			Time = 0.13,
			Pose = {
				RS = { 150, 40 },
				RE = { 40 },
				RW = { -20 },
				LS = { 20, 15 },
				LE = { 30 },
				Waist = { yaw = -26, lean = -3 },
			},
		},
		{
			Time = 0.24,
			Ease = "Out",
			Pose = {
				RS = { 55, -25 },
				RE = { 10 },
				RW = { 10 },
				LS = { 15, 12 },
				LE = { 25 },
				Waist = { yaw = 32, lean = 12 },
			},
		},
		{ Time = 0.42, Pose = with(CARRY_SLASH, { Waist = { yaw = 5, lean = 3 } }) },
	},
})
Anim.SlashB = compile({ -- horizontal, de izquierda a derecha
	Length = 0.42,
	Frames = {
		{ Time = 0, Pose = CARRY_SLASH },
		{
			Time = 0.12,
			Pose = {
				RS = { 90, -55 },
				RE = { 30 },
				RW = { 0 },
				LS = { 30, 15 },
				LE = { 35 },
				Waist = { yaw = 34, lean = 4 },
			},
		},
		{
			Time = 0.24,
			Ease = "Out",
			Pose = {
				RS = { 95, 60 },
				RE = { 8 },
				RW = { 0 },
				LS = { 20, 15 },
				LE = { 30 },
				Waist = { yaw = -34, lean = 8 },
			},
		},
		{ Time = 0.42, Pose = with(CARRY_SLASH, { Waist = { yaw = -4, lean = 3 } }) },
	},
})
Anim.SlashC = compile({ -- de arriba abajo con las dos manos
	Length = 0.5,
	Frames = {
		{ Time = 0, Pose = with(CARRY_SLASH, { Root = { up = 0, lean = 0 } }) },
		{
			Time = 0.17,
			Pose = {
				RS = { 170, 0 },
				RE = { 30 },
				RW = { -10 },
				LS = { 165, -10 },
				LE = { 35 },
				Waist = { lean = -8, yaw = 0 },
				Root = { up = 0.05, lean = 0 },
			},
		},
		{
			Time = 0.3,
			Ease = "Out",
			Pose = {
				RS = { 40, -8 },
				RE = { 10 },
				RW = { 10 },
				LS = { 35, -15 },
				LE = { 15 },
				Waist = { lean = 20, yaw = 0 },
				Root = { up = -0.3, lean = 6 },
			},
		},
		{ Time = 0.5, Pose = with(CARRY_SLASH, { Root = { up = 0, lean = 0 } }) },
	},
})
Anim.SlashSpin = compile({ -- giro completo con la espada extendida (espadas míticas)
	Length = 0.55,
	Frames = {
		{
			Time = 0,
			Pose = { RS = { 90, 75 }, RE = { 5 }, LS = { 25, 40 }, LE = { 30 }, Root = { yaw = 0, lean = 6 } },
		},
		{ Time = 0.12, Ease = "Linear", Pose = { Root = { yaw = 90, lean = 8 } } },
		{ Time = 0.24, Ease = "Linear", Pose = { Root = { yaw = 180, lean = 8 } } },
		{ Time = 0.36, Ease = "Linear", Pose = { Root = { yaw = 270, lean = 8 } } },
		{ Time = 0.46, Ease = "Linear", Pose = { Root = { yaw = 360, lean = 6 } } },
		{
			Time = 0.55,
			Pose = { RS = { 60, 15 }, RE = { 100 }, LS = { 10, 10 }, LE = { 20 }, Root = { yaw = 360, lean = 0 } },
		},
	},
})

-- Ogre: levanta los dos brazos y machaca (la animación que ya funcionaba bien, pasada a R15)
Anim.Smash = compile({
	Length = 0.62,
	Frames = {
		{
			Time = 0,
			Pose = {
				RS = { 10, 8 },
				RE = { 20 },
				LS = { 10, 8 },
				LE = { 20 },
				Waist = { lean = 2 },
				Root = { up = 0, lean = 0 },
			},
		},
		{
			Time = 0.26,
			Pose = {
				RS = { 172, 12 },
				RE = { 25 },
				LS = { 172, 12 },
				LE = { 25 },
				Waist = { lean = -10 },
				Root = { up = 0.06, lean = 0 },
			},
		},
		{
			Time = 0.37,
			Ease = "Out",
			Pose = {
				RS = { 55, -10 },
				RE = { 10 },
				LS = { 55, -10 },
				LE = { 10 },
				Waist = { lean = 22 },
				Root = { up = -0.35, lean = 6 },
			},
		},
		{
			Time = 0.62,
			Pose = {
				RS = { 10, 8 },
				RE = { 20 },
				LS = { 10, 8 },
				LE = { 20 },
				Waist = { lean = 3 },
				Root = { up = 0, lean = 0 },
			},
		},
	},
})

-- Lanzar magia: la mano derecha empuja hacia delante con la palma abierta
Anim.Cast = compile({
	Length = 0.46,
	Frames = {
		{
			Time = 0,
			Pose = {
				RS = { 10, 8 },
				RE = { 20 },
				RW = { 0 },
				LS = { 10, 8 },
				LE = { 20 },
				Waist = { yaw = 0, lean = 2 },
			},
		},
		{
			Time = 0.1,
			Pose = {
				RS = { 40, 20, -20 },
				RE = { 60 },
				RW = { 10 },
				LS = { 25, 15 },
				LE = { 40 },
				Waist = { yaw = -10, lean = 0 },
			},
		},
		{
			Time = 0.2,
			Ease = "Out",
			Pose = {
				RS = { 88, 6, -30 },
				RE = { 5 },
				RW = { -25 },
				LS = { 30, 18 },
				LE = { 45 },
				Waist = { yaw = 16, lean = 6 },
			},
		},
		{
			Time = 0.32,
			Pose = {
				RS = { 86, 6, -30 },
				RE = { 5 },
				RW = { -25 },
				LS = { 30, 18 },
				LE = { 45 },
				Waist = { yaw = 14, lean = 5 },
			},
		},
		{
			Time = 0.46,
			Pose = {
				RS = { 10, 8 },
				RE = { 20 },
				RW = { 0 },
				LS = { 10, 8 },
				LE = { 20 },
				Waist = { yaw = 0, lean = 2 },
			},
		},
	},
})

--------------------------------------------------------------------------------
-- Juegos de animaciones por raza
--------------------------------------------------------------------------------

local SETS = {
	Human = { Idle = idle(HUMAN_IDLE), Walk = locomotion(HUMAN_WALK), Run = locomotion(HUMAN_RUN) },
	Elf = { Idle = idle(ELF_IDLE), Walk = locomotion(ELF_WALK), Run = locomotion(ELF_RUN) },
	Ogre = {
		Idle = idle(OGRE_IDLE),
		Walk = locomotion(OGRE_WALK),
		Run = locomotion(OGRE_RUN),
		Guard = Anim.GuardOgre,
		GuardSword = Anim.GuardSwordOgre,
	},
	SummonedFire = { Idle = idle(FIRE_IDLE), Walk = locomotion(FIRE_WALK), Run = locomotion(FIRE_RUN) },
	SummonedWater = { Idle = idle(WATER_IDLE), Walk = locomotion(WATER_WALK), Run = locomotion(WATER_RUN) },
	SummonedPlant = { Idle = idle(SUMMONED_IDLE), Walk = locomotion(SUMMONED_WALK), Run = locomotion(SUMMONED_RUN) },
}
SETS.MajorElf = SETS.Elf
SETS.Summoned = SETS.SummonedPlant

for _, set in SETS do
	set.Guard = set.Guard or Anim.Guard
	set.GuardSword = set.GuardSword or Anim.GuardSword
end
AnimationData.Sets = SETS

-- Animaciones de una raza (las que no tenga propias, las del Human)
function AnimationData.GetSet(raceId)
	return SETS[raceId] or SETS.Human
end

-- Combos de espada según la rareza: las mejores espadas tienen más golpes
AnimationData.SwordCombos = {
	Common = { "SlashA", "SlashB" },
	Rare = { "SlashA", "SlashB" },
	Epic = { "SlashA", "SlashB", "SlashC" },
	Legendary = { "SlashA", "SlashB", "SlashC" },
	Mythic = { "SlashA", "SlashB", "SlashC", "SlashSpin" },
}

return AnimationData
