-- Regional seasonal species; fishBody exposes a smooth loft to FishMeshes' EditableMesh renderer.
return {
	Name = "Black Crappie",
	ScientificName = "Pomoxis nigromaculatus",
	Rarity = "Uncommon",
	RarityDenominator = 12,
	MinKg = 0.1,
	AverageKg = 0.7,
	MaxKg = 2.8,
	BaseValue = 44,
	Fight = 0.05,
	Pools = { "MainLake", "SoddenMire" },
	Seasons = { "Spring", "Autumn", "Winter" },
	Shapes = {
		Normal = { "##", "##" },
		Big = { "###", "###" },
		Huge = { "####", "####" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(50, 74, 64), side = rgb(151, 175, 146), belly = rgb(222, 224, 193) }
		local fin, dark = rgb(89, 118, 92), rgb(39, 65, 48)
		b:fishBody(0.42, 0.12, colors, 0.08)
		b:edgeFin(0.18, -0.24, { 0.09, 0.1, 0.11, 0.1, 0.08, 0.05 }, fin)
		b:edgeFin(0.04, -0.24, { 0.06, 0.09, 0.085, 0.055 }, fin, true)
		b:edgeFin(0.07, -0.01, { 0.045, 0.03 }, fin, true)
		b:roundTail(0.145, fin)
		b:pectoral(0.23, -0.065, 0.1, 0.035, fin, 0.05)
		b:speckle(8, v2(-0.26, 0.28), v2(-0.10, 0.12), v2(0.029, 0.045), dark)
		b:marks(0.27, 0.04, 0.06, 0.045, rgb(85, 114, 87))
		b:face(0.37, 0.04, 0.04, rgb(221, 184, 95), dark)
	end,
}

