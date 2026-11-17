-- Regional seasonal species; fishBody exposes a smooth loft to FishMeshes' EditableMesh renderer.
return {
	Name = "Chain Pickerel",
	ScientificName = "Esox niger",
	Rarity = "Rare",
	RarityDenominator = 17,
	MinKg = 0.2,
	AverageKg = 1.3,
	MaxKg = 5.5,
	LengthScale = 1.25,
	BaseValue = 64,
	Fight = 0.08,
	Pools = { "SoddenMire" },
	Seasons = { "Spring", "Autumn", "Winter" },
	Shapes = {
		Normal = { "###" },
		Big = { "####" },
		Huge = { "#####", ".###." },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(62, 86, 45), side = rgb(142, 165, 77), belly = rgb(222, 223, 156) }
		local fin, dark = rgb(136, 124, 54), rgb(51, 77, 34)
		b:fishBody(0.145, 0.095, colors, 0.015)
		b:layered("Duckbill", Vector3.new(0.46, -0.006, 0), Vector3.new(0.22, 0.055, 0.07600000000000001), colors)
		b:edgeFin(-0.12, -0.28, { 0.065, 0.08, 0.065, 0.035 }, fin)
		b:edgeFin(-0.14, -0.29, { 0.055, 0.06, 0.035 }, fin, true)
		b:edgeFin(0.07, -0.01, { 0.045, 0.03 }, fin, true)
		b:forkTail(0.115, 0.05, fin)
		b:pectoral(0.23, -0.035, 0.075, 0.035, fin, 0.05)
		for x = 0.20, -0.26, -0.075 do
			b:marks(x, 0.015, 0.065, 0.042, dark, v2(1, 0.65))
			b:marks(x, 0.015, 0.045, 0.023, rgb(174, 188, 97), v2(1, 0.65))
		end
		b:marks(0.34, -0.025, 0.015, 0.045, dark)
		b:face(0.35, 0.025, 0.04, rgb(225, 186, 74), dark)
	end,
}

