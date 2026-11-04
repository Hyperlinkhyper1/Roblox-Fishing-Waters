return {
	Name = "Carp",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 0.8,
	AverageKg = 3.5,
	MaxKg = 30,
	BaseValue = 9,
	Fight = 0.02,
	Pools = { "MainLake" },
	Seasons = { "Summer" },
	Shapes = {
		Normal = { "##", "##" },
		Big = { "###", "###" },
		Huge = { "####", "####" },
	},
	Build = function(b, kit)
		local rgb, carp = kit.rgb, kit.carp
		carp(b, {
			mesh = true,
			colors = { back = rgb(86, 68, 36), side = rgb(192, 146, 64), belly = rgb(234, 208, 148) },
			fin = rgb(176, 104, 60),
			scale = rgb(164, 118, 48),
			scaleAlt = rgb(176, 130, 54),
			barbel = rgb(170, 120, 70),
			lips = rgb(198, 150, 92),
			iris = rgb(214, 172, 64),
			line = rgb(130, 96, 44),
		})
	end,
}
