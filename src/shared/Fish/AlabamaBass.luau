return {
	Name = "Alabama Bass",
	Rarity = "Uncommon",
	RarityDenominator = 10,
	MinKg = 0.2,
	AverageKg = 1.4,
	MaxKg = 5.5,
	BaseValue = 29,
	Fight = 0.07,
	Pools = { "MainLake" },
	Seasons = { "Spring", "Summer", "Autumn" },
	Requires = { "Day" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "####", "####" },
	},
	-- Species-specific body proportions, fins and flank markings share the smooth mesh pipeline.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(52, 76, 42), side = rgb(142, 158, 88), belly = rgb(224, 226, 192) }
		local fin = rgb(100, 122, 66)
		b:fishBody(0.26, 0.14, colors, 0.07)
		local dorsal = b:edgeFin(0.15, -0.23, { 0.06, 0.075, 0.07, 0.055, 0.04, 0.055, 0.08, 0.075, 0.055 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3], dorsal[4], dorsal[5] }, rgb(54, 72, 40))
		b:edgeFin(-0.08, -0.23, { 0.06, 0.07, 0.045 }, fin, true)
		b:edgeFin(0.08, 0, { 0.055, 0.04 }, fin, true)
		b:forkTail(0.13, 0.028, fin)
		b:pectoral(0.21, -0.04, 0.105, 0.04, fin, 0.1)
		-- Broken dark lateral band and rows of small belly spots.
		for x = 0.25, -0.29, -0.06 do
			b:marks(x, 0, 0.065, 0.028, rgb(52, 76, 38))
		end
		for _, y in { -0.035, -0.065, -0.09 } do
			for x = 0.18, -0.23, -0.055 do
				b:marks(x, y, 0.012, 0.008, rgb(84, 100, 50))
			end
		end
		b:face(0.37, 0.033, 0.046, rgb(174, 132, 58), rgb(54, 72, 40))
	end,
}
