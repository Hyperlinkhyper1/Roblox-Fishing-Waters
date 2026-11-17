-- Regional seasonal species; fishBody exposes a smooth loft to FishMeshes' EditableMesh renderer.
return {
	Name = "Alligator Gar",
	ScientificName = "Atractosteus spatula",
	Rarity = "Legendary",
	RarityDenominator = 120,
	MinKg = 5,
	AverageKg = 38,
	MaxKg = 135,
	LengthScale = 1.7,
	BaseValue = 710,
	Fight = 0.15,
	Pools = { "SoddenMire" },
	Seasons = { "Summer", "Autumn" },
	Shapes = {
		Normal = { "#####", ".###." },
		Big = { "######", ".####." },
		Huge = { "#######", "#######" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(67, 78, 40), side = rgb(135, 146, 83), belly = rgb(219, 215, 151) }
		local fin, dark = rgb(111, 122, 58), rgb(41, 59, 29)
		b:fishBody(0.215, 0.21, colors, 0.025)
		b:layered("BroadBill", Vector3.new(0.52, -0.015, 0), Vector3.new(0.34, 0.055, 0.115), colors)
		b:edgeFin(-0.12, -0.28, { 0.055, 0.075, 0.065, 0.035 }, fin)
		b:edgeFin(-0.14, -0.29, { 0.055, 0.06, 0.035 }, fin, true)
		b:edgeFin(0.07, -0.01, { 0.045, 0.03 }, fin, true)
		b:roundTail(0.15, fin)
		b:pectoral(0.23, -0.035, 0.075, 0.05, fin, 0.05)
		-- Broad armored shoulders, wide toothy bill and blunt caudal fin.
		for x = 0.18, -0.26, -0.085 do
			b:marks(x, 0.055, 0.05, 0.024, dark, v2(1, 0.65))
			b:marks(x + 0.035, -0.005, 0.05, 0.024, dark, v2(1, 0.65))
		end
		for _, side in { 1, -1 } do
			for x = 0.48, 0.65, 0.045 do
				b:limb(Vector3.new(x, -0.023, side * 0.047), Vector3.new(x, -0.009, side * 0.047), 0.006, rgb(230, 225, 178), "Tooth")
			end
		end
		b:face(0.35, 0.025, 0.042, rgb(222, 168, 66), dark)
	end,
}

