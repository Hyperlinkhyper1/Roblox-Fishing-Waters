return {
	Name = "Yellow Bass",
	Rarity = "Common",
	RarityDenominator = 5,
	MinKg = 0.08,
	AverageKg = 0.35,
	MaxKg = 1.6,
	BaseValue = 14,
	Fight = 0.03,
	Pools = { "MainLake" },
	Seasons = { "Spring", "Summer" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "###", "###" },
	},
	-- Species-specific body proportions, fins and flank markings share the smooth mesh pipeline.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(112, 114, 40), side = rgb(220, 202, 92), belly = rgb(246, 234, 176) }
		local fin = rgb(176, 158, 60)
		b:fishBody(0.27, 0.12, colors, 0.07)
		local dorsal = b:edgeFin(0.15, -0.23, { 0.06, 0.075, 0.07, 0.055, 0.04, 0.055, 0.08, 0.075, 0.055 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3], dorsal[4], dorsal[5] }, rgb(72, 74, 36))
		b:edgeFin(-0.08, -0.23, { 0.06, 0.07, 0.045 }, fin, true)
		b:edgeFin(0.08, 0, { 0.055, 0.04 }, fin, true)
		b:forkTail(0.13, 0.055, fin)
		b:pectoral(0.21, -0.04, 0.105, 0.04, fin, 0.1)
		-- Several long dark stripes across the golden flank.
		for _, y in { -0.075, -0.04, -0.005, 0.03, 0.065 } do
			b:stroke({ v2(0.23, y), v2(-0.08, y * 0.78), v2(-0.3, y * 0.4) }, 0.008, rgb(78, 82, 38))
		end
		b:face(0.37, 0.033, 0.046, rgb(214, 176, 48), rgb(72, 74, 36))
	end,
}
