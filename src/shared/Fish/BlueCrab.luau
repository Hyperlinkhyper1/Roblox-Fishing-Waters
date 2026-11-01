return {
	Name = "Blue Crab",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 0.15,
	AverageKg = 0.45,
	MaxKg = 1.8,
	BaseValue = 26,
	Fight = 0,
	Shapes = {
		Normal = { "##" },
		Big = { "###", "###" },
		Huge = { "####", "####" },
	},
	Build = function(b, kit)
		local rgb, crab = kit.rgb, kit.crab
		crab(b, {
			shell = rgb(96, 122, 112),
			dark = rgb(70, 96, 92),
			belly = rgb(236, 230, 214),
			clawColor = rgb(66, 128, 196),
			legColor = rgb(84, 142, 196),
			tipColor = rgb(206, 70, 50),
			carapace = Vector3.new(0.34, 0.12, 0.6),
			teeth = 7,
			lateral = 0.1,
			claw = 1.05,
			legs = {
				lean = { 0.6, 0.2, -0.2, -0.95 },
				thigh = 0.16,
				shin = 0.16,
				lift = 0.06,
				drop = 0.15,
				width = 0.032,
				paddle = true,
			},
			spots = { count = 14, size = Vector2.new(0.01, 0.022), color = rgb(122, 146, 128) },
		})
	end,
}
