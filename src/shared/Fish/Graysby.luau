return {
	Name = "Graysby",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 0.1,
	AverageKg = 0.65,
	MaxKg = 2.5,
	BaseValue = 53,
	Fight = 0.035,
	Pools = { "CoralShallows", "PirateCove" },
	Seasons = { "Summer", "Autumn" },
	Requires = { "Night" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "####", "####" },
	},
	-- Small russet grouper with reddish spots and three dark spots along the dorsal base.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(136, 84, 70), side = rgb(194, 140, 114), belly = rgb(226, 196, 164) }
		local fin = rgb(150, 90, 74)
		b:fishBody(0.28, 0.15, colors, 0.075)
		local dorsal = b:edgeFin(0.17, -0.22, { 0.055, 0.075, 0.07, 0.06, 0.055, 0.065, 0.08, 0.075, 0.055 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3], dorsal[4], dorsal[5] }, colors.back)
		b:edgeFin(-0.08, -0.24, { 0.065, 0.075, 0.055 }, fin, true)
		b:edgeFin(0.1, 0.015, { 0.06, 0.045 }, fin, true)
		b:roundTail(0.135, fin)
		b:pectoral(0.2, -0.04, 0.13, 0.05, fin)
		b:speckle(42, v2(-0.3, 0.31), v2(-0.09, 0.11), v2(0.008, 0.014), rgb(132, 64, 56))
		for _, x in { 0.12, -0.035, -0.18 } do
			b:marks(x, b:top(x) * 0.74, 0.042, 0.032, rgb(58, 46, 40))
		end
		b:face(0.37, 0.04, 0.043, rgb(184, 142, 70), colors.back)
	end,
}
