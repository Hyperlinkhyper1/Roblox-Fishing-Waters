-- Regional seasonal species; fishBody exposes a smooth loft to FishMeshes' EditableMesh renderer.
return {
	Name = "Roach",
	ScientificName = "Rutilus rutilus",
	Rarity = "Common",
	RarityDenominator = 5,
	MinKg = 0.06,
	AverageKg = 0.35,
	MaxKg = 2,
	BaseValue = 17,
	Fight = 0.02,
	Pools = { "MainLake" },
	Seasons = { "Spring", "Autumn", "Winter" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "####", ".##." },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(80, 108, 107), side = rgb(183, 197, 183), belly = rgb(232, 234, 209) }
		local fin, dark = rgb(172, 88, 60), rgb(74, 99, 95)
		b:fishBody(0.28, 0.115, colors, 0.045)
		b:edgeFin(0.09, -0.1, { 0.1, 0.08, 0.04 }, fin)
		b:edgeFin(-0.09, -0.23, { 0.055, 0.06, 0.035 }, fin, true)
		b:edgeFin(0.07, -0.01, { 0.045, 0.03 }, fin, true)
		b:forkTail(0.13, 0.06, fin)
		b:pectoral(0.23, -0.035, 0.1, 0.035, fin, 0.05)
		for x = 0.16, -0.22, -0.075 do b:marks(x, 0.005, 0.041, 0.022, rgb(215, 222, 203)) end
		b:edgeFin(0.045, -0.015, { 0.065, 0.045 }, rgb(193, 96, 63), true)
		b:face(0.37, 0.025, 0.04, rgb(213, 84, 52), dark)
	end,
}

