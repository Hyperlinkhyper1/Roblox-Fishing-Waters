return {
	Name = "Tripletail",
	Rarity = "Rare",
	RarityDenominator = 14,
	MinKg = 0.5,
	AverageKg = 4,
	MaxKg = 20,
	BaseValue = 150,
	Fight = 0.065,
	Pools = { "MainLake", "CoralShallows" },
	Seasons = { "Summer", "Autumn" },
	Requires = { "Clear", "Day" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", ".##." },
		Huge = { "#####", "#####" },
	},
	-- Deep, compressed tripletail: tall rear dorsal and anal fins flank a third rounded tail lobe.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(72, 66, 46), side = rgb(128, 116, 78), belly = rgb(192, 176, 128) }
		local fin = rgb(88, 78, 48)
		b:fishBody(0.4, 0.12, colors, 0.075)
		b:edgeFin(0.15, -0.08, { 0.055, 0.065, 0.055, 0.045 }, fin)
		b:edgeFin(-0.06, -0.35, { 0.07, 0.13, 0.15, 0.15, 0.13, 0.08 }, fin)
		b:edgeFin(-0.06, -0.35, { 0.07, 0.13, 0.15, 0.15, 0.13, 0.08 }, fin, true)
		b:edgeFin(0.08, 0, { 0.06, 0.045 }, fin, true)
		b:roundTail(0.17, fin)
		b:pectoral(0.2, -0.04, 0.13, 0.05, fin)
		b:speckle(30, v2(-0.29, 0.28), v2(-0.15, 0.16), v2(0.02, 0.045), rgb(82, 72, 44))
		b:marks(0.25, 0.07, 0.07, 0.065, rgb(164, 146, 96))
		b:face(0.37, 0.04, 0.043, rgb(176, 148, 74), colors.back)
	end,
}
