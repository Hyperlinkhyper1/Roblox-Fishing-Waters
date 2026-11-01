return {
	Name = "Red Snapper",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 0.5,
	AverageKg = 2.5,
	MaxKg = 20,
	BaseValue = 19,
	Fight = 0.04,
	Pools = { "OpenSea" },
	Seasons = { "Summer", "Autumn", "Winter" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "###", "###" },
	},
	-- Deep red reef snapper with a sloped head, spiny dorsal and red eye.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(176, 46, 46), side = rgb(222, 88, 80), belly = rgb(244, 184, 176) }
		local fin = rgb(206, 70, 66)
		b:fishBody(0.34, 0.13, colors, 0.1)
		local dorsal = b:edgeFin(0.16, -0.22, { 0.06, 0.08, 0.08, 0.075, 0.07, 0.065, 0.07, 0.08, 0.07 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3], dorsal[5], dorsal[7] }, rgb(140, 36, 36))
		b:edgeFin(-0.08, -0.22, { 0.07, 0.08, 0.06 }, fin, true)
		b:edgeFin(0.06, -0.02, { 0.06, 0.05 }, fin, true)
		b:forkTail(0.15, 0.06, fin)
		b:pectoral(0.2, -0.03, 0.14, 0.035, fin)
		for y = -0.06, 0.08, 0.035 do
			b:stroke({ v2(0.28, y + 0.01), v2(-0.3, y) }, 0.005, rgb(234, 120, 110))
		end
		b:face(0.37, 0.05, 0.048, rgb(206, 40, 40), rgb(150, 40, 40))
	end,
}
