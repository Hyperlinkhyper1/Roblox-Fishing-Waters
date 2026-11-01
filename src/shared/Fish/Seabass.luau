return {
	Name = "Seabass",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 0.5,
	AverageKg = 2,
	MaxKg = 12,
	BaseValue = 19,
	Fight = 0.04,
	Pools = { "OpenSea" },
	Seasons = { "Spring", "Winter" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "###", "###" },
	},
	-- European sea bass: a sleek silver-grey predator with two separate dorsals
	-- (spiny then soft), a dark spot on the gill cover and a moderately forked tail.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(82, 94, 104), side = rgb(184, 190, 194), belly = rgb(238, 240, 238) }
		local fin = rgb(140, 148, 154)
		b:fishBody(0.24, 0.13, colors, 0.05)
		local spines = b:edgeFin(0.14, 0.02, { 0.06, 0.075, 0.07, 0.05 }, fin, false, 0.08)
		b:rays(spines[1], { spines[3], spines[4], spines[5] }, rgb(80, 88, 96))
		b:edgeFin(-0.02, -0.17, { 0.06, 0.055, 0.045, 0.03 }, fin, false, 0.08)
		b:edgeFin(-0.08, -0.2, { 0.05, 0.05, 0.035 }, fin, true, 0.08)
		b:edgeFin(0.07, -0.01, { 0.05, 0.035 }, fin, true, 0.1)
		b:forkTail(0.13, 0.045, fin)
		b:pectoral(0.21, -0.03, 0.09, 0.03, fin, 0.15)
		b:stroke({ v2(0.25, 0.045), v2(0, 0.04), v2(-0.3, 0.01) }, 0.006, rgb(70, 80, 88))
		b:marks(0.255, 0.035, 0.032, 0.026, rgb(40, 44, 50))
		b:face(0.37, 0.03, 0.05, rgb(190, 196, 196), rgb(100, 110, 118))
	end,
}
