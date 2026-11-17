-- Regional seasonal species; fishBody exposes a smooth loft to FishMeshes' EditableMesh renderer.
return {
	Name = "White Crappie",
	ScientificName = "Pomoxis annularis",
	Rarity = "Uncommon",
	RarityDenominator = 11,
	MinKg = 0.1,
	AverageKg = 0.6,
	MaxKg = 2.7,
	BaseValue = 39,
	Fight = 0.045,
	Pools = { "MainLake", "SoddenMire" },
	Seasons = { "Spring", "Summer" },
	Shapes = {
		Normal = { "##", "##" },
		Big = { "###", "###" },
		Huge = { "####", "####" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(83, 105, 91), side = rgb(178, 195, 170), belly = rgb(230, 231, 205) }
		local fin, dark = rgb(131, 157, 128), rgb(72, 99, 78)
		b:fishBody(0.4, 0.105, colors, 0.1)
		b:edgeFin(0.18, -0.24, { 0.06, 0.09, 0.1, 0.085, 0.07, 0.04 }, fin)
		b:edgeFin(0.04, -0.24, { 0.06, 0.09, 0.085, 0.055 }, fin, true)
		b:edgeFin(0.07, -0.01, { 0.045, 0.03 }, fin, true)
		b:roundTail(0.14, fin)
		b:pectoral(0.23, -0.065, 0.1, 0.035, fin, 0.05)
		for x = 0.15, -0.26, -0.075 do b:marks(x, -0.005, 0.034, 0.15 * (1 - math.abs(x)), dark) end
		b:marks(0.28, 0, 0.05, 0.045, rgb(132, 160, 126))
		b:face(0.37, 0.04, 0.04, rgb(221, 190, 97), dark)
	end,
}

