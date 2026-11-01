return {
	Name = "Walleye",
	Rarity = "Rare",
	RarityDenominator = 20,
	MinKg = 0.5,
	AverageKg = 2,
	MaxKg = 11,
	BaseValue = 63,
	Fight = 0.04,
	Pools = { "MainLake" },
	Seasons = { "Spring", "Winter" },
	Shapes = {
		Normal = { "###" },
		Big = { "####" },
		Huge = { "####", "####" },
	},
	-- Olive-gold perch with dark saddles, a spiny then soft dorsal and big glassy eyes.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(96, 92, 46), side = rgb(186, 170, 92), belly = rgb(236, 230, 200) }
		local fin = rgb(150, 136, 80)
		b:fishBody(0.2, 0.12, colors, 0.04)
		local spines = b:edgeFin(0.15, 0.0, { 0.07, 0.08, 0.075, 0.06, 0.04 }, fin, false, 0.08)
		b:rays(spines[1], { spines[3], spines[4], spines[5], spines[6] }, rgb(70, 64, 36))
		b:finSpot(0.02, b:top(0.02) + 0.02, 0.022, rgb(30, 28, 20))
		b:edgeFin(-0.04, -0.2, { 0.06, 0.06, 0.05, 0.035 }, fin)
		b:edgeFin(-0.1, -0.22, { 0.05, 0.045, 0.03 }, fin, true)
		b:edgeFin(0.04, -0.04, { 0.04 }, fin, true)
		b:forkTail(0.12, 0.05, fin)
		-- The white tip on the lower tail lobe is the walleye's field mark.
		b:fin({ v2(-0.46, -0.07), v2(-0.5, -0.12), v2(-0.44, -0.1) }, rgb(240, 240, 232))
		b:pectoral(0.2, -0.04, 0.09, 0.03, fin)
		for _, x in { 0.18, 0.06, -0.06, -0.18 } do
			b:stroke({ v2(x, b:top(x) - 0.01), v2(x - 0.02, 0.0) }, 0.04, rgb(80, 74, 36))
		end
		b:face(0.36, 0.025, 0.06, rgb(214, 214, 196), rgb(110, 104, 56))
	end,
}
