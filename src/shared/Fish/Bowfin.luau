-- Regional seasonal species; fishBody exposes a smooth loft to FishMeshes' EditableMesh renderer.
return {
	Name = "Bowfin",
	ScientificName = "Amia calva",
	Rarity = "Rare",
	RarityDenominator = 26,
	MinKg = 0.5,
	AverageKg = 3.2,
	MaxKg = 11,
	BaseValue = 118,
	Fight = 0.1,
	Pools = { "SoddenMire" },
	Seasons = { "Summer", "Autumn" },
	Shapes = {
		Normal = { "###" },
		Big = { "####" },
		Huge = { "#####", ".###." },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(49, 76, 43), side = rgb(110, 140, 72), belly = rgb(200, 208, 143) }
		local fin, dark = rgb(103, 137, 67), rgb(39, 65, 34)
		b:fishBody(0.235, 0.17, colors, 0.04)
		b:edgeFin(0.18, -0.3, { 0.055, 0.075, 0.085, 0.085, 0.075, 0.06, 0.035 }, fin)
		b:edgeFin(-0.09, -0.23, { 0.055, 0.06, 0.035 }, fin, true)
		b:edgeFin(0.07, -0.01, { 0.045, 0.03 }, fin, true)
		b:roundTail(0.14, fin)
		b:pectoral(0.23, -0.035, 0.1, 0.05, fin, 0.05)
		b:marks(-0.27, 0.035, 0.065, 0.058, rgb(218, 184, 80))
		b:marks(-0.27, 0.035, 0.043, 0.037, rgb(26, 47, 28))
		b:speckle(14, v2(-0.20, 0.28), v2(-0.04, 0.07), v2(0.023, 0.039), dark)
		b:face(0.37, 0.025, 0.04, rgb(205, 157, 66), dark)
	end,
}

