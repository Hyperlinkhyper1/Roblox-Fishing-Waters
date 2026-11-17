-- Regional seasonal species; fishBody exposes a smooth loft to FishMeshes' EditableMesh renderer.
return {
	Name = "Crucian Carp",
	ScientificName = "Carassius carassius",
	Rarity = "Uncommon",
	RarityDenominator = 12,
	MinKg = 0.12,
	AverageKg = 0.8,
	MaxKg = 3.8,
	BaseValue = 38,
	Fight = 0.035,
	Pools = { "SoddenMire" },
	Seasons = { "Spring", "Summer" },
	Shapes = {
		Normal = { "##", "##" },
		Big = { "###", "###" },
		Huge = { "####", "####" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(101, 83, 40), side = rgb(190, 161, 77), belly = rgb(237, 216, 151) }
		local fin, dark = rgb(164, 118, 56), rgb(112, 89, 40)
		b:fishBody(0.45, 0.175, colors, 0.08)
		b:edgeFin(0.18, -0.24, { 0.07, 0.08, 0.075, 0.065, 0.055, 0.04 }, fin)
		b:edgeFin(-0.09, -0.23, { 0.055, 0.06, 0.035 }, fin, true)
		b:edgeFin(0.07, -0.01, { 0.045, 0.03 }, fin, true)
		b:forkTail(0.135, 0.025, fin)
		b:pectoral(0.23, -0.065, 0.1, 0.05, fin, 0.05)
		-- Tall rounded body and convex dorsal edge with a dark caudal spot.
		b:marks(-0.29, 0.008, 0.044, 0.06, dark)
		for x = 0.18, -0.20, -0.09 do b:marks(x, 0.06, 0.032, 0.04, rgb(220, 190, 103)) end
		b:face(0.37, 0.04, 0.04, rgb(226, 173, 63), dark)
	end,
}

