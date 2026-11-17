return {
	Name = "Black Grouper",
	Rarity = "Epic",
	RarityDenominator = 30,
	MinKg = 3,
	AverageKg = 14,
	MaxKg = 90,
	LengthScale = 1.1,
	BaseValue = 350,
	Fight = 0.08,
	Pools = { "CoralShallows", "PirateCove" },
	Seasons = { "Spring", "Summer", "Autumn" },
	Requires = { "Night" },
	Shapes = {
		Normal = { "###", "###" },
		Big = { "####", "####" },
		Huge = { "#####", "#####" },
	},
	-- Broad olive-grey grouper with rectangular charcoal blotches and a dark rounded tail.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(50, 52, 44), side = rgb(104, 108, 88), belly = rgb(194, 192, 160) }
		local fin = rgb(46, 50, 42)
		b:fishBody(0.34, 0.19, colors, 0.075)
		local dorsal = b:edgeFin(0.17, -0.22, { 0.055, 0.075, 0.07, 0.06, 0.055, 0.065, 0.08, 0.075, 0.055 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3], dorsal[4], dorsal[5] }, colors.back)
		b:edgeFin(-0.08, -0.24, { 0.065, 0.075, 0.055 }, fin, true)
		b:edgeFin(0.1, 0.015, { 0.06, 0.045 }, fin, true)
		b:roundTail(0.135, fin)
		b:pectoral(0.2, -0.04, 0.13, 0.05, fin)
		for _, x in { 0.19, 0.07, -0.05, -0.18, -0.28 } do
			for _, y in { -0.06, 0.025, 0.09 } do
				b:marks(x, y, 0.068, 0.046, rgb(46, 48, 40))
			end
		end
		b:stroke({ v2(0.47, -0.035), v2(0.34, -0.07) }, 0.014, rgb(36, 38, 32))
		b:face(0.37, 0.04, 0.043, rgb(188, 174, 94), colors.back)
	end,
}
