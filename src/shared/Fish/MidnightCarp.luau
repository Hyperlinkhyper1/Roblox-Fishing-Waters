return {
	Name = "Midnight Carp",
	Rarity = "Epic",
	RarityDenominator = 50,
	MinKg = 1,
	AverageKg = 5,
	MaxKg = 35,
	BaseValue = 170,
	Fight = 0.05,
	Pools = { "MainLake" },
	Seasons = { "Spring", "Autumn", "Winter" },
	Requires = { "Night" },
	Shapes = {
		Normal = { "##", "##" },
		Big = { "###", "###" },
		Huge = { "####", "####" },
	},
	Build = function(b, kit)
		local rgb, carp = kit.rgb, kit.carp
		carp(b, {
			colors = { back = rgb(18, 20, 40), side = rgb(40, 46, 86), belly = rgb(96, 104, 150) },
			fin = rgb(30, 36, 76),
			scale = rgb(70, 92, 170),
			scaleAlt = rgb(48, 58, 112),
			barbel = rgb(60, 66, 110),
			lips = rgb(70, 76, 120),
			iris = rgb(190, 220, 255),
			line = rgb(60, 70, 120),
		})
	end,
}
