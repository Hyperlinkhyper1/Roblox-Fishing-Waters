return {
	Name = "Red Hind Grouper",
	Rarity = "Uncommon",
	RarityDenominator = 10,
	MinKg = 0.2,
	AverageKg = 1.4,
	MaxKg = 5.5,
	BaseValue = 64,
	Fight = 0.045,
	Pools = { "CoralShallows", "PirateCove" },
	Seasons = { "Spring", "Summer" },
	Requires = { "Day" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "####", "####" },
	},
	-- Cream-coloured hind densely covered in red spots, including its rounded tail.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(174, 126, 90), side = rgb(232, 202, 156), belly = rgb(248, 232, 194) }
		local fin = rgb(174, 104, 78)
		b:fishBody(0.29, 0.15, colors, 0.075)
		local dorsal = b:edgeFin(0.17, -0.22, { 0.055, 0.075, 0.07, 0.06, 0.055, 0.065, 0.08, 0.075, 0.055 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3], dorsal[4], dorsal[5] }, colors.back)
		b:edgeFin(-0.08, -0.24, { 0.065, 0.075, 0.055 }, fin, true)
		b:edgeFin(0.1, 0.015, { 0.06, 0.045 }, fin, true)
		b:roundTail(0.135, fin)
		b:pectoral(0.2, -0.04, 0.13, 0.05, fin)
		b:speckle(72, v2(-0.31, 0.34), v2(-0.105, 0.115), v2(0.007, 0.014), rgb(176, 66, 52))
		for _, x in { -0.43, -0.47 } do
			for y = -0.075, 0.075, 0.0375 do
				b:finSpot(x, y, 0.013, rgb(120, 48, 40))
			end
		end
		b:face(0.37, 0.04, 0.043, rgb(190, 124, 62), colors.back)
	end,
}
