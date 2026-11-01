return {
	Name = "Bluegill",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 0.1,
	AverageKg = 0.35,
	MaxKg = 2,
	BaseValue = 20,
	Fight = 0,
	Pools = { "MainLake" },
	Seasons = { "Summer" },
	Shapes = {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "##", "##" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(58, 76, 58), side = rgb(112, 124, 86), belly = rgb(224, 150, 60) }
		local fin = rgb(82, 92, 70)
		b:fishBody(0.42, 0.13, colors, 0.1)
		local dorsal =
			b:edgeFin(0.13, -0.24, { 0.07, 0.05, 0.075, 0.05, 0.075, 0.055, 0.08, 0.1, 0.11, 0.09 }, fin, false, 0.08)
		b:rays(dorsal[1], { dorsal[4], dorsal[6], dorsal[8], dorsal[10] }, rgb(46, 52, 42))
		b:edgeFin(-0.05, -0.24, { 0.06, 0.08, 0.09, 0.07 }, fin, true, 0.08)
		b:edgeFin(0.08, -0.02, { 0.07, 0.06 }, fin, true)
		b:forkTail(0.15, 0.03, fin, 0.05)
		b:pectoral(0.2, -0.04, 0.15, 0.04, rgb(150, 140, 96), 0.15)
		for _, x in { 0.15, 0.07, -0.01, -0.09, -0.17, -0.24 } do
			b:stroke({ v2(x + 0.01, b:top(x) - 0.02), v2(x - 0.01, -0.06) }, 0.03, rgb(40, 50, 36))
		end
		b:stroke({ v2(0.43, -0.02), v2(0.33, -0.05) }, 0.012, rgb(88, 110, 156))
		b:stroke({ v2(0.43, -0.05), v2(0.34, -0.09) }, 0.012, rgb(88, 110, 156))
		b:marks(0.235, 0.035, 0.065, 0.055, rgb(18, 18, 22))
		b:face(0.38, 0.05, 0.05, rgb(46, 40, 36), rgb(70, 80, 56))
	end,
}
