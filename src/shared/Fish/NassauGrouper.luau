return {
	Name = "Nassau Grouper",
	Rarity = "Rare",
	RarityDenominator = 16,
	MinKg = 1,
	AverageKg = 5,
	MaxKg = 25,
	BaseValue = 180,
	Fight = 0.065,
	Pools = { "CoralShallows" },
	Seasons = { "Spring", "Winter" },
	Requires = { "Day" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", ".##." },
		Huge = { "#####", "#####" },
	},
	-- Sand-coloured Nassau grouper with five broad dark bars and a black tail saddle.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(134, 116, 76), side = rgb(212, 192, 140), belly = rgb(242, 228, 184) }
		local fin = rgb(144, 122, 76)
		b:fishBody(0.34, 0.18, colors, 0.075)
		local dorsal = b:edgeFin(0.17, -0.22, { 0.055, 0.075, 0.07, 0.06, 0.055, 0.065, 0.08, 0.075, 0.055 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3], dorsal[4], dorsal[5] }, colors.back)
		b:edgeFin(-0.08, -0.24, { 0.065, 0.075, 0.055 }, fin, true)
		b:edgeFin(0.1, 0.015, { 0.06, 0.045 }, fin, true)
		b:roundTail(0.135, fin)
		b:pectoral(0.2, -0.04, 0.13, 0.05, fin)
		for _, x in { 0.26, 0.13, 0, -0.13, -0.26 } do
			b:stroke({ v2(x + 0.01, b:top(x) * 0.86), v2(x - 0.018, b:bottom(x) * 0.65) }, 0.047, rgb(90, 76, 46))
		end
		b:marks(-0.3, 0.005, 0.06, 0.055, rgb(34, 32, 24))
		b:stroke({ v2(0.43, 0.04), v2(0.28, -0.065) }, 0.018, rgb(92, 78, 48))
		b:face(0.37, 0.04, 0.043, rgb(194, 166, 80), colors.back)
	end,
}
