return {
	Name = "Halibut",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 1,
	AverageKg = 6,
	MaxKg = 180,
	BaseValue = 18,
	Fight = 0.04,
	Pools = { "OpenSea" },
	Seasons = { "Spring", "Summer", "Autumn" },
	Shapes = {
		Normal = { "##", "##" },
		Big = { "###", "###" },
		Huge = { "#####", "#####", "#####" },
	},
	Build = function(b, kit)
		local rgb, flatfish = kit.rgb, kit.flatfish
		flatfish(b, {
			top = rgb(70, 66, 50),
			under = rgb(244, 244, 238),
			fin = rgb(80, 76, 58),
			ray = rgb(52, 50, 38),
			light = rgb(100, 96, 74),
			dark = rgb(46, 44, 34),
			iris = rgb(170, 160, 120),
			mouth = rgb(36, 34, 26),
		})
	end,
}
