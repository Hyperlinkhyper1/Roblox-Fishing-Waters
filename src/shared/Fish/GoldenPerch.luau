-- Regional seasonal species; fishBody exposes a smooth loft to FishMeshes' EditableMesh renderer.
return {
	Name = "Golden Perch",
	ScientificName = "Macquaria ambigua",
	Rarity = "Rare",
	RarityDenominator = 19,
	MinKg = 0.3,
	AverageKg = 2.1,
	MaxKg = 13,
	BaseValue = 78,
	Fight = 0.09,
	Pools = { "MainLake" },
	Seasons = { "Spring", "Summer", "Autumn" },
	Shapes = {
		Normal = { "##", "##" },
		Big = { "###", "###" },
		Huge = { "####", "####" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(92, 84, 37), side = rgb(192, 167, 69), belly = rgb(237, 219, 151) }
		local fin, dark = rgb(153, 117, 45), rgb(80, 73, 34)
		b:fishBody(0.34, 0.19, colors, 0.09)
		b:layered("Forehead", Vector3.new(0.28, 0.062, 0), Vector3.new(0.22, 0.18, 0.155), colors)
		for x = 0.13, -0.22, -0.09 do b:marks(x, 0, 0.046, 0.09, rgb(142, 125, 48), v2(0.2, 1)) end
		b:edgeFin(0.18, -0.24, { 0.065, 0.09, 0.07, 0.025, 0.035, 0.09, 0.08, 0.04 }, fin)
		b:edgeFin(-0.09, -0.23, { 0.055, 0.06, 0.035 }, fin, true)
		b:edgeFin(0.07, -0.01, { 0.045, 0.03 }, fin, true)
		b:roundTail(0.135, fin)
		b:pectoral(0.23, -0.065, 0.1, 0.05, fin, 0.05)
		b:face(0.37, 0.04, 0.04, rgb(230, 176, 56), dark)
	end,
}

