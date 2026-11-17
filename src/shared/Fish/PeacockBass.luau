return {
	Name = "Peacock Bass",
	Rarity = "Rare",
	RarityDenominator = 18,
	MinKg = 0.4,
	AverageKg = 2.2,
	MaxKg = 10,
	BaseValue = 76,
	Fight = 0.12,
	Pools = { "MainLake", "SoddenMire" },
	Seasons = { "Summer" },
	Requires = { "Clear", "Day" },
	Shapes = {
		Normal = { "###" },
		Big = { "####" },
		Huge = { "#####", "#####" },
	},
	-- Species-specific body proportions, fins and flank markings share the smooth mesh pipeline.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(70, 108, 38), side = rgb(208, 184, 58), belly = rgb(242, 196, 82) }
		local fin = rgb(186, 110, 42)
		b:fishBody(0.3, 0.15, colors, 0.07)
		local dorsal = b:edgeFin(0.15, -0.23, { 0.06, 0.075, 0.07, 0.055, 0.04, 0.055, 0.08, 0.075, 0.055 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3], dorsal[4], dorsal[5] }, rgb(42, 66, 32))
		b:edgeFin(-0.08, -0.23, { 0.06, 0.07, 0.045 }, fin, true)
		b:edgeFin(0.08, 0, { 0.055, 0.04 }, fin, true)
		b:forkTail(0.13, 0.028, fin)
		b:pectoral(0.21, -0.04, 0.105, 0.04, fin, 0.1)
		-- Three broad bars and the orange-rimmed tail eyespot.
		for _, x in { 0.18, -0.015, -0.21 } do
			b:stroke({ v2(x, b:top(x) * 0.9), v2(x - 0.025, b:bottom(x) * 0.75) }, 0.048, rgb(44, 60, 30))
		end
		b:marks(-0.3, 0, 0.076, 0.07, rgb(240, 172, 46))
		b:marks(-0.3, 0, 0.045, 0.043, rgb(24, 34, 24))
		b:edgeFin(-0.07, -0.2, { 0.015, 0.018, 0.012 }, rgb(234, 130, 40), true)
		b:face(0.37, 0.033, 0.046, rgb(208, 78, 38), rgb(42, 66, 32))
	end,
}
