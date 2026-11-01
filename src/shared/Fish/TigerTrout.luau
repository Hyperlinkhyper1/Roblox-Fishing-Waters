return {
	Name = "Tiger Trout",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 0.3,
	AverageKg = 1.5,
	MaxKg = 10,
	BaseValue = 14,
	Fight = 0.05,
	Pools = { "MainLake", "OpenSea" },
	Seasons = { "Autumn", "Winter" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "###", "###" },
	},
	Build = function(b, kit)
		local rgb, trout = kit.rgb, kit.trout
		trout(b, {
			colors = { back = rgb(110, 92, 50), side = rgb(206, 176, 104), belly = rgb(240, 226, 186) },
			fin = rgb(196, 140, 72),
			vermiculate = true,
			spot = rgb(60, 46, 24),
			iris = rgb(220, 176, 80),
			line = rgb(130, 106, 60),
		})
	end,
}
