-- GENERADO por art/goblin/build_goblin.py: no editar a mano (se sobrescribe).
-- Medidas del Goblin de Blender (1 unidad = 1 stud; mira hacia -Y, arriba es +Z).
-- server/MeshRig.luau las usa para montar el modelo importado en Roblox.
return {
	Template = "GoblinTier1",
	Root = Vector3.new(0.0000, 0.0200, 1.4100),
	Parts = {
		LowerTorso = {
			Center = Vector3.new(0.0038, -0.0616, 1.2407),
			Size = Vector3.new(0.9586, 0.6353, 0.7521),
			Triangles = 3544,
		},
		UpperTorso = {
			Center = Vector3.new(0.0468, -0.1029, 1.9277),
			Size = Vector3.new(0.9285, 0.5827, 0.8400),
			Triangles = 2040,
		},
		Head = {
			Center = Vector3.new(0.0000, -0.4321, 2.9306),
			Size = Vector3.new(2.5595, 1.7263, 1.4154),
			Triangles = 11985,
		},
		LeftUpperArm = {
			Center = Vector3.new(0.3640, -0.1795, 1.9192),
			Size = Vector3.new(0.2567, 0.2366, 0.3766),
			Triangles = 640,
		},
		LeftLowerArm = {
			Center = Vector3.new(0.4477, -0.2869, 1.5534),
			Size = Vector3.new(0.2290, 0.2771, 0.3970),
			Triangles = 1600,
		},
		LeftHand = {
			Center = Vector3.new(0.4824, -0.4056, 1.2106),
			Size = Vector3.new(0.1936, 0.2608, 0.3742),
			Triangles = 1104,
		},
		RightUpperArm = {
			Center = Vector3.new(-0.3640, -0.1795, 1.9192),
			Size = Vector3.new(0.2567, 0.2366, 0.3766),
			Triangles = 640,
		},
		RightLowerArm = {
			Center = Vector3.new(-0.4453, -0.2862, 1.5523),
			Size = Vector3.new(0.2336, 0.2757, 0.3992),
			Triangles = 1600,
		},
		RightHand = {
			Center = Vector3.new(-0.5541, -0.7269, 0.7438),
			Size = Vector3.new(0.3317, 0.9342, 1.3079),
			Triangles = 2700,
		},
		LeftUpperLeg = {
			Center = Vector3.new(0.1986, -0.0882, 1.0047),
			Size = Vector3.new(0.3013, 0.3757, 0.4988),
			Triangles = 800,
		},
		LeftLowerLeg = {
			Center = Vector3.new(0.2363, -0.0878, 0.4963),
			Size = Vector3.new(0.2170, 0.3592, 0.5984),
			Triangles = 800,
		},
		LeftFoot = {
			Center = Vector3.new(0.2300, -0.1306, 0.1088),
			Size = Vector3.new(0.2593, 0.5741, 0.2263),
			Triangles = 1308,
		},
		RightUpperLeg = {
			Center = Vector3.new(-0.1986, -0.0882, 1.0047),
			Size = Vector3.new(0.3013, 0.3757, 0.4988),
			Triangles = 800,
		},
		RightLowerLeg = {
			Center = Vector3.new(-0.2360, -0.0878, 0.4963),
			Size = Vector3.new(0.2553, 0.3592, 0.5984),
			Triangles = 1568,
		},
		RightFoot = {
			Center = Vector3.new(-0.2300, -0.1306, 0.1085),
			Size = Vector3.new(0.2593, 0.5741, 0.2258),
			Triangles = 1308,
		},
	},
	Joints = {
		{
			Name = "Root",
			Part0 = "HumanoidRootPart",
			Part1 = "LowerTorso",
			Position = Vector3.new(0.0000, 0.0200, 1.3600),
		},
		{ Name = "Waist", Part0 = "LowerTorso", Part1 = "UpperTorso", Position = Vector3.new(0.0000, -0.0100, 1.5500) },
		{ Name = "Neck", Part0 = "UpperTorso", Part1 = "Head", Position = Vector3.new(0.0000, -0.3200, 2.3400) },
		{
			Name = "LeftShoulder",
			Part0 = "UpperTorso",
			Part1 = "LeftUpperArm",
			Position = Vector3.new(0.3200, -0.1600, 2.1000),
		},
		{
			Name = "LeftElbow",
			Part0 = "LeftUpperArm",
			Part1 = "LeftLowerArm",
			Position = Vector3.new(0.4200, -0.2100, 1.7400),
		},
		{
			Name = "LeftWrist",
			Part0 = "LeftLowerArm",
			Part1 = "LeftHand",
			Position = Vector3.new(0.4700, -0.3300, 1.3800),
		},
		{
			Name = "LeftHip",
			Part0 = "LowerTorso",
			Part1 = "LeftUpperLeg",
			Position = Vector3.new(0.1600, 0.0200, 1.2400),
		},
		{
			Name = "LeftKnee",
			Part0 = "LeftUpperLeg",
			Part1 = "LeftLowerLeg",
			Position = Vector3.new(0.2400, -0.2000, 0.7800),
		},
		{
			Name = "LeftAnkle",
			Part0 = "LeftLowerLeg",
			Part1 = "LeftFoot",
			Position = Vector3.new(0.2250, 0.0400, 0.2100),
		},
		{
			Name = "RightShoulder",
			Part0 = "UpperTorso",
			Part1 = "RightUpperArm",
			Position = Vector3.new(-0.3200, -0.1600, 2.1000),
		},
		{
			Name = "RightElbow",
			Part0 = "RightUpperArm",
			Part1 = "RightLowerArm",
			Position = Vector3.new(-0.4200, -0.2100, 1.7400),
		},
		{
			Name = "RightWrist",
			Part0 = "RightLowerArm",
			Part1 = "RightHand",
			Position = Vector3.new(-0.4700, -0.3300, 1.3800),
		},
		{
			Name = "RightHip",
			Part0 = "LowerTorso",
			Part1 = "RightUpperLeg",
			Position = Vector3.new(-0.1600, 0.0200, 1.2400),
		},
		{
			Name = "RightKnee",
			Part0 = "RightUpperLeg",
			Part1 = "RightLowerLeg",
			Position = Vector3.new(-0.2400, -0.2000, 0.7800),
		},
		{
			Name = "RightAnkle",
			Part0 = "RightLowerLeg",
			Part1 = "RightFoot",
			Position = Vector3.new(-0.2250, 0.0400, 0.2100),
		},
	},
}
