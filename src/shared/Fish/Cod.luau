return {
	Name = "Cod",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 1,
	AverageKg = 4,
	MaxKg = 40,
	BaseValue = 24,
	Fight = 0.02,
	Pools = { "MainLake" },
	Seasons = { "Summer" },
	Shapes = {
		Normal = { "###" },
		Big = { "###", "###" },
		Huge = { "####", "####" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(102, 94, 60), side = rgb(158, 148, 104), belly = rgb(232, 226, 202) }
		local fin = rgb(122, 112, 78)
		b:fishBody(0.22, 0.15, colors, 0.08)
		b:edgeFin(0.15, 0.04, { 0.05, 0.065, 0.05 }, fin)
		b:edgeFin(0.0, -0.12, { 0.045, 0.055, 0.045 }, fin)
		b:edgeFin(-0.16, -0.27, { 0.04, 0.045, 0.03 }, fin)
		b:edgeFin(-0.03, -0.14, { 0.04, 0.05, 0.04 }, fin, true)
		b:edgeFin(-0.17, -0.27, { 0.04, 0.04, 0.03 }, fin, true)
		b:forkTail(0.09, 0.012, fin)
		b:pectoral(0.21, -0.03, 0.09, 0.04, fin)
		b:speckle(60, v2(-0.33, 0.36), v2(-0.04, 0.12), v2(0.014, 0.03), rgb(92, 80, 50))
		b:stroke({ v2(0.26, 0.04), v2(0.12, 0.05), v2(-0.06, 0.03), v2(-0.32, 0.005) }, 0.009, rgb(226, 220, 196))
		b:limb(
			Vector3.new(0.43, b:bottom(0.43) + 0.005, 0),
			Vector3.new(0.4, b:bottom(0.43) - 0.075, 0),
			0.012,
			rgb(150, 136, 96),
			"Barbel"
		)
		b:face(0.36, 0.02, 0.042, rgb(190, 176, 120), rgb(110, 100, 70))
	end,
}
