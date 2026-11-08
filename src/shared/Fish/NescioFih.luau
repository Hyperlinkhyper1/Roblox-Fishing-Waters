return {
	Name = "Nescio Fih",
	Rarity = "Admin",
	RarityDenominator = 1000000,
	MinKg = 18,
	AverageKg = 42,
	MaxKg = 160,
	BaseValue = 50000,
	Fight = 0.3,
	Pools = { "MainLake", "OpenSea" },
	Seasons = { "Spring", "Summer", "Autumn", "Winter" },
	Shapes = {
		Normal = { "#####", "#####" },
		Big = { "######", "######", "######" },
		Huge = { "########", "########", "########", "########" },
	},
	-- Nobody knows what it is. A pale, blotchy thing with a pointed shark's
	-- head, two frog legs folded under its hunched body and a paddle tail.
	Build = function(b, kit)
		kit.nescio(b, {})
	end,
}
