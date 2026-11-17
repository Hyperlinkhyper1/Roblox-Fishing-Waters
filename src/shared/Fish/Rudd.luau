-- Regional seasonal species; fishBody exposes a smooth loft to FishMeshes' EditableMesh renderer.
return {
	Name = "Rudd",
	ScientificName = "Scardinius erythrophthalmus",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 0.06,
	AverageKg = 0.45,
	MaxKg = 2.2,
	BaseValue = 28,
	Fight = 0.025,
	Pools = { "MainLake", "SoddenMire" },
	Seasons = { "Spring", "Summer", "Autumn" },
	Shapes = {
		Normal = { "##", "##" },
		Big = { "###", "###" },
		Huge = { "####", "####" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(89, 100, 49), side = rgb(183, 173, 97), belly = rgb(234, 223, 172) }
		local fin, dark = rgb(201, 67, 44), rgb(87, 94, 47)
		b:fishBody(0.31, 0.115, colors, 0)
		b:edgeFin(-0.02, -0.24, { 0.09, 0.085, 0.045 }, fin)
		b:edgeFin(-0.09, -0.23, { 0.055, 0.06, 0.035 }, fin, true)
		b:edgeFin(0.07, -0.01, { 0.045, 0.03 }, fin, true)
		b:forkTail(0.14, 0.06, fin)
		b:pectoral(0.23, -0.065, 0.1, 0.035, fin, 0.05)
		-- Upswept mouth, bronze flanks and scarlet fins.
		b:ellipsoid("UpturnedLip", CFrame.new(0.453, 0.012, 0), Vector3.new(0.064, 0.03, 0.046), rgb(208, 192, 124))
		for x = 0.14, -0.23, -0.085 do b:marks(x, 0.02, 0.03, 0.036, rgb(215, 199, 123)) end
		b:face(0.37, 0.04, 0.04, rgb(216, 177, 61), dark)
	end,
}

