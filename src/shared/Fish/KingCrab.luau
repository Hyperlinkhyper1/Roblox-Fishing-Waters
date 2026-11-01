return {
	Name = "King Crab",
	Rarity = "Rare",
	RarityDenominator = 20,
	MinKg = 0.8,
	AverageKg = 2.6,
	MaxKg = 11,
	BaseValue = 60,
	Fight = 0,
	Shapes = {
		Normal = { "###", "###" },
		Big = { "####", "####" },
		Huge = { "#####", "#####", "#####" },
	},
	Build = function(b, kit)
		local rgb, crab = kit.rgb, kit.crab
		local spine = rgb(226, 132, 104)
		crab(b, {
			shell = rgb(176, 52, 40),
			dark = rgb(144, 38, 32),
			belly = rgb(238, 214, 190),
			clawColor = rgb(188, 64, 46),
			legColor = rgb(186, 62, 46),
			tipColor = rgb(84, 34, 28),
			carapace = Vector3.new(0.38, 0.17, 0.42),
			teeth = 3,
			claw = 1.15,
			offhand = 0.78,
			armSpines = true,
			spineColor = spine,
			legs = { lean = { 0.45, -0.05, -0.55 }, thigh = 0.25, shin = 0.25, lift = 0.1, drop = 0.24, width = 0.044 },
			knobs = { count = 46, size = Vector2.new(0.014, 0.024), color = spine },
		})
	end,
}
