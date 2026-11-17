return {
	Name = "Gulf Coney",
	Rarity = "Common",
	RarityDenominator = 5,
	MinKg = 0.08,
	AverageKg = 0.35,
	MaxKg = 1.3,
	BaseValue = 24,
	Fight = 0.02,
	Pools = { "CoralShallows" },
	Seasons = { "Spring", "Summer", "Autumn" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "####", "####" },
	},
	-- A compact golden coney with bright blue spots and a charcoal saddle at the tail base.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(164, 116, 36), side = rgb(222, 176, 60), belly = rgb(248, 228, 156) }
		local fin = rgb(194, 132, 42)
		b:fishBody(0.26, 0.14, colors, 0.075)
		local dorsal = b:edgeFin(0.17, -0.22, { 0.055, 0.075, 0.07, 0.06, 0.055, 0.065, 0.08, 0.075, 0.055 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3], dorsal[4], dorsal[5] }, colors.back)
		b:edgeFin(-0.08, -0.24, { 0.065, 0.075, 0.055 }, fin, true)
		b:edgeFin(0.1, 0.015, { 0.06, 0.045 }, fin, true)
		b:roundTail(0.135, fin)
		b:pectoral(0.2, -0.04, 0.13, 0.05, fin)
		b:speckle(36, v2(-0.28, 0.3), v2(-0.085, 0.1), v2(0.007, 0.014), rgb(76, 152, 218))
		b:marks(-0.27, 0.025, 0.072, 0.065, rgb(70, 56, 32))
		b:marks(0.3, 0.045, 0.028, 0.025, rgb(82, 160, 220))
		b:face(0.37, 0.04, 0.043, rgb(198, 104, 48), colors.back)
	end,
}
