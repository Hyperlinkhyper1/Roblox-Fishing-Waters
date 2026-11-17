return {
	Name = "Redeye Bass",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 0.1,
	AverageKg = 0.45,
	MaxKg = 2,
	BaseValue = 27,
	Fight = 0.08,
	Pools = { "MainLake" },
	Seasons = { "Spring", "Summer" },
	Requires = { "Clear" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "###", "###" },
	},
	-- Species-specific body proportions, fins and flank markings share the smooth mesh pipeline.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(72, 86, 54), side = rgb(146, 152, 106), belly = rgb(220, 218, 186) }
		local fin = rgb(144, 104, 64)
		b:fishBody(0.24, 0.12, colors, 0.07)
		local dorsal = b:edgeFin(0.15, -0.23, { 0.06, 0.075, 0.07, 0.055, 0.04, 0.055, 0.08, 0.075, 0.055 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3], dorsal[4], dorsal[5] }, rgb(64, 76, 42))
		b:edgeFin(-0.08, -0.23, { 0.06, 0.07, 0.045 }, fin, true)
		b:edgeFin(0.08, 0, { 0.055, 0.04 }, fin, true)
		b:forkTail(0.13, 0.028, fin)
		b:pectoral(0.21, -0.04, 0.105, 0.04, fin, 0.1)
		-- Narrow vertical mottling and pale edging on its reddish tail.
		for x = 0.18, -0.25, -0.085 do
			b:stroke({ v2(x, b:top(x) * 0.8), v2(x - 0.02, b:bottom(x) * 0.5) }, 0.022, rgb(82, 98, 58))
		end
		b:fin({ v2(-0.495, 0.125), v2(-0.472, 0.113), v2(-0.472, 0.075) }, rgb(224, 210, 160))
		b:fin({ v2(-0.495, -0.125), v2(-0.472, -0.113), v2(-0.472, -0.075) }, rgb(224, 210, 160))
		b:face(0.37, 0.033, 0.046, rgb(232, 54, 34), rgb(64, 76, 42))
	end,
}
