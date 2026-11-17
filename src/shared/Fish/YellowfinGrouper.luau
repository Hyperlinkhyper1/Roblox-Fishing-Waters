return {
	Name = "Yellowfin Grouper",
	Rarity = "Rare",
	RarityDenominator = 18,
	MinKg = 1,
	AverageKg = 5,
	MaxKg = 25,
	BaseValue = 190,
	Fight = 0.065,
	Pools = { "CoralShallows" },
	Seasons = { "Spring", "Summer" },
	Requires = { "Clear", "Day" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", ".##." },
		Huge = { "#####", "#####" },
	},
	-- Olive grouper with pale oval spots, yellow paired fins and a yellow-edged rounded tail.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(100, 98, 62), side = rgb(174, 168, 104), belly = rgb(228, 220, 168) }
		local fin = rgb(216, 176, 48)
		b:fishBody(0.31, 0.17, colors, 0.075)
		local dorsal = b:edgeFin(0.17, -0.22, { 0.055, 0.075, 0.07, 0.06, 0.055, 0.065, 0.08, 0.075, 0.055 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3], dorsal[4], dorsal[5] }, colors.back)
		b:edgeFin(-0.08, -0.24, { 0.065, 0.075, 0.055 }, fin, true)
		b:edgeFin(0.1, 0.015, { 0.06, 0.045 }, fin, true)
		b:roundTail(0.135, fin)
		b:pectoral(0.2, -0.04, 0.13, 0.05, fin)
		b:speckle(42, v2(-0.3, 0.3), v2(-0.105, 0.12), v2(0.012, 0.024), rgb(232, 220, 156))
		b:pectoral(0.22, -0.035, 0.16, 0.055, rgb(242, 198, 44))
		b:marks(0.3, 0.055, 0.026, 0.025, rgb(230, 216, 150))
		b:face(0.37, 0.04, 0.043, rgb(218, 178, 70), colors.back)
	end,
}
