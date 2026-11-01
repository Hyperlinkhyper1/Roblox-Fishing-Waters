return {
	Name = "Shore Crab",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 0.05,
	AverageKg = 0.2,
	MaxKg = 0.9,
	BaseValue = 12,
	Fight = 0,
	Shapes = {
		Normal = { "##" },
		Big = { "##", "##" },
		Huge = { "###", "###" },
	},
	Build = function(b, kit)
		local rgb, crab = kit.rgb, kit.crab
		crab(b, {
			shell = rgb(92, 112, 58),
			dark = rgb(70, 86, 44),
			belly = rgb(214, 170, 86),
			clawColor = rgb(104, 118, 62),
			legColor = rgb(112, 124, 66),
			carapace = Vector3.new(0.42, 0.14, 0.52),
			teeth = 5,
			claw = 1,
			legs = {
				lean = { 0.55, 0.15, -0.25, -0.7 },
				thigh = 0.17,
				shin = 0.16,
				lift = 0.06,
				drop = 0.17,
				width = 0.034,
			},
			spots = { count = 30, size = Vector2.new(0.012, 0.03), color = rgb(150, 138, 72) },
		})
	end,
}
