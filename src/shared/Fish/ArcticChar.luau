-- Regional seasonal species; fishBody exposes a smooth loft to FishMeshes' EditableMesh renderer.
return {
	Name = "Arctic Char",
	ScientificName = "Salvelinus alpinus",
	Rarity = "Rare",
	RarityDenominator = 20,
	MinKg = 0.2,
	AverageKg = 1.4,
	MaxKg = 12,
	BaseValue = 112,
	Fight = 0.08,
	Pools = { "FrostmereExpanse" },
	Seasons = { "Spring", "Winter" },
	Shapes = {
		Normal = { "###" },
		Big = { "####" },
		Huge = { "#####", ".###." },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(39, 66, 75), side = rgb(111, 153, 157), belly = rgb(236, 135, 87) }
		local fin, dark = rgb(189, 99, 68), rgb(33, 61, 66)
		b:fishBody(0.245, 0.135, colors, 0.03)
		b:edgeFin(0.09, -0.1, { 0.09, 0.085, 0.055, 0.03 }, fin)
		b:ellipsoid("AdiposeFin", CFrame.new(-0.25, b:top(-0.25) + 0.009, 0), Vector3.new(0.045, 0.026, 0.012), fin)
		b:edgeFin(-0.09, -0.23, { 0.055, 0.06, 0.035 }, fin, true)
		b:edgeFin(0.07, -0.01, { 0.045, 0.03 }, fin, true)
		b:forkTail(0.125, 0.05, fin)
		b:pectoral(0.23, -0.035, 0.1, 0.035, fin, 0.05)
		for x = 0.22, -0.27, -0.055 do
			b:marks(x, 0.015, 0.026, 0.021, rgb(240, 194, 150))
		end
		b:limb(Vector3.new(0.02, -0.105, 0), Vector3.new(-0.05, -0.168, 0), 0.009, rgb(245, 243, 228), "WhiteFinEdge")
		b:face(0.37, 0.025, 0.04, rgb(225, 177, 86), dark)
	end,
}

