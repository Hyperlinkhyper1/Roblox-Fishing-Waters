-- Regional seasonal species; fishBody exposes a smooth loft to FishMeshes' EditableMesh renderer.
return {
	Name = "Tench",
	ScientificName = "Tinca tinca",
	Rarity = "Uncommon",
	RarityDenominator = 13,
	MinKg = 0.3,
	AverageKg = 1.8,
	MaxKg = 7.5,
	BaseValue = 48,
	Fight = 0.045,
	Pools = { "SoddenMire" },
	Seasons = { "Spring", "Summer", "Autumn" },
	Shapes = {
		Normal = { "##", "##" },
		Big = { "###", "###" },
		Huge = { "####", "####" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(53, 73, 37), side = rgb(115, 132, 65), belly = rgb(201, 196, 119) }
		local fin, dark = rgb(94, 105, 53), rgb(47, 66, 32)
		b:fishBody(0.325, 0.185, colors, 0.1)
		b:edgeFin(0.18, -0.24, { 0.065, 0.07, 0.055, 0.04 }, fin)
		b:edgeFin(-0.09, -0.23, { 0.055, 0.06, 0.035 }, fin, true)
		b:edgeFin(0.07, -0.01, { 0.045, 0.03 }, fin, true)
		b:roundTail(0.125, fin)
		b:pectoral(0.23, -0.065, 0.12, 0.05, fin, 0.05)
		for _, side in { 1, -1 } do
			b:limb(Vector3.new(0.43, -0.035, side * 0.032), Vector3.new(0.39, -0.095, side * 0.05), 0.007, rgb(164, 156, 91), "ShortBarbel")
		end
		b:marks(0.08, -0.01, 0.22, 0.08, rgb(137, 149, 78))
		b:face(0.37, 0.04, 0.04, rgb(221, 100, 55), dark)
	end,
}

