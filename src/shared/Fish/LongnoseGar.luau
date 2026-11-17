-- Regional seasonal species; fishBody exposes a smooth loft to FishMeshes' EditableMesh renderer.
return {
	Name = "Longnose Gar",
	ScientificName = "Lepisosteus osseus",
	Rarity = "Epic",
	RarityDenominator = 45,
	MinKg = 0.7,
	AverageKg = 5.5,
	MaxKg = 23,
	LengthScale = 1.25,
	BaseValue = 198,
	Fight = 0.11,
	Pools = { "SoddenMire" },
	Seasons = { "Spring", "Summer" },
	Shapes = {
		Normal = { "###" },
		Big = { "####" },
		Huge = { "#####", ".###." },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(76, 89, 47), side = rgb(154, 165, 98), belly = rgb(223, 222, 166) }
		local fin, dark = rgb(132, 134, 75), rgb(45, 65, 32)
		b:fishBody(0.14, 0.095, colors, 0.02)
		b:layered("LongBill", Vector3.new(0.52, -0.008, 0), Vector3.new(0.38, 0.035, 0.035), colors)
		b:edgeFin(-0.12, -0.28, { 0.045, 0.065, 0.055, 0.03 }, fin)
		b:edgeFin(-0.14, -0.29, { 0.055, 0.06, 0.035 }, fin, true)
		b:edgeFin(0.07, -0.01, { 0.045, 0.03 }, fin, true)
		b:roundTail(0.11, fin)
		b:pectoral(0.23, -0.035, 0.075, 0.035, fin, 0.05)
		-- Thin long bill and dark ganoid scale pattern.
		for _, y in { -0.02, 0.035 } do
			for x = 0.20, -0.27, -0.078 do b:marks(x, y, 0.033, 0.018, dark, v2(1, 0.6)) end
		end
		b:stroke({ v2(0.70, -0.014), v2(0.42, -0.025) }, 0.016, dark)
		b:face(0.35, 0.025, 0.04, rgb(220, 176, 74), dark)
	end,
}

