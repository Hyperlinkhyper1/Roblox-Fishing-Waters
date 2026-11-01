return {
	Name = "Rainbow Trout",
	Rarity = "Rare",
	RarityDenominator = 20,
	MinKg = 0.3,
	AverageKg = 1.5,
	MaxKg = 12,
	BaseValue = 62,
	Fight = 0.05,
	Pools = { "MainLake" },
	Seasons = { "Summer" },
	Requires = { "Rain" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "###", "###" },
	},
	Build = function(b, kit)
		local rgb, trout = kit.rgb, kit.trout
		trout(b, {
			colors = { back = rgb(70, 96, 70), side = rgb(196, 200, 176), belly = rgb(244, 240, 230) },
			fin = rgb(156, 150, 120),
			band = rgb(226, 112, 140),
			spots = 70,
			spot = rgb(28, 30, 24),
			iris = rgb(210, 180, 100),
			line = rgb(110, 116, 96),
		})
	end,
}
