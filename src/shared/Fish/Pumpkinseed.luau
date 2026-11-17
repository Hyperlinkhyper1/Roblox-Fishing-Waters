-- Regional seasonal species; fishBody exposes a smooth loft to FishMeshes' EditableMesh renderer.
return {
	Name = "Pumpkinseed",
	ScientificName = "Lepomis gibbosus",
	Rarity = "Common",
	RarityDenominator = 6,
	MinKg = 0.04,
	AverageKg = 0.18,
	MaxKg = 0.8,
	BaseValue = 20,
	Fight = 0.02,
	Pools = { "MainLake" },
	Seasons = { "Spring", "Summer" },
	Shapes = {
		Normal = { "##", "##" },
		Big = { "###", "###" },
		Huge = { "####", "####" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(65, 108, 86), side = rgb(158, 174, 95), belly = rgb(235, 169, 64) }
		local fin, dark = rgb(157, 133, 63), rgb(44, 94, 78)
		b:fishBody(0.44, 0.105, colors, 0.1)
		b:edgeFin(0.18, -0.24, { 0.06, 0.08, 0.09, 0.07, 0.07, 0.045 }, fin)
		b:edgeFin(0.04, -0.24, { 0.06, 0.09, 0.085, 0.055 }, fin, true)
		b:edgeFin(0.07, -0.01, { 0.045, 0.03 }, fin, true)
		b:forkTail(0.13, 0.035, fin)
		b:pectoral(0.23, -0.065, 0.1, 0.035, fin, 0.05)
		-- Red ear flap, turquoise cheek slashes and orange belly.
		b:marks(0.23, 0.015, 0.065, 0.06, dark)
		b:marks(0.205, 0.015, 0.025, 0.039, rgb(215, 74, 45))
		for _, y in { -0.045, 0.015, 0.065 } do b:marks(0.31, y, 0.076, 0.016, rgb(76, 173, 172), v2(1, 0.5)) end
		for x = 0.10, -0.25, -0.09 do b:marks(x, 0.025, 0.025, 0.09, rgb(211, 154, 66)) end
		b:face(0.37, 0.04, 0.04, rgb(222, 157, 67), dark)
	end,
}

