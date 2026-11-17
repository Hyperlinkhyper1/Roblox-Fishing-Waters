-- Regional seasonal species; fishBody exposes a smooth loft to FishMeshes' EditableMesh renderer.
return {
	Name = "Brown Trout",
	ScientificName = "Salmo trutta",
	Rarity = "Rare",
	RarityDenominator = 18,
	MinKg = 0.3,
	AverageKg = 1.8,
	MaxKg = 16,
	BaseValue = 72,
	Fight = 0.07,
	Pools = { "MainLake", "FrostmereExpanse" },
	Seasons = { "Spring", "Autumn", "Winter" },
	Shapes = {
		Normal = { "###" },
		Big = { "####" },
		Huge = { "#####", ".###." },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(87, 75, 47), side = rgb(184, 155, 88), belly = rgb(236, 219, 171) }
		local fin, dark = rgb(137, 109, 61), rgb(43, 39, 30)
		b:fishBody(0.25, 0.14, colors, 0.07)
		b:edgeFin(0.09, -0.1, { 0.08, 0.09, 0.06, 0.045 }, fin)
		b:ellipsoid("AdiposeFin", CFrame.new(-0.25, b:top(-0.25) + 0.009, 0), Vector3.new(0.045, 0.026, 0.012), fin)
		b:edgeFin(-0.09, -0.23, { 0.055, 0.06, 0.035 }, fin, true)
		b:edgeFin(0.07, -0.01, { 0.045, 0.03 }, fin, true)
		b:forkTail(0.12, 0.025, fin)
		b:pectoral(0.23, -0.035, 0.1, 0.035, fin, 0.05)
		b:speckle(14, v2(-0.27, 0.3), v2(-0.025, 0.09), v2(0.015, 0.025), dark)
		for _, x in { -0.21, -0.08, 0.08, 0.21 } do
			b:marks(x, -0.014, 0.028, 0.025, rgb(231, 205, 152))
			b:marks(x, -0.014, 0.014, 0.013, rgb(172, 57, 42))
		end
		b:face(0.37, 0.025, 0.04, rgb(218, 176, 79), dark)
	end,
}

