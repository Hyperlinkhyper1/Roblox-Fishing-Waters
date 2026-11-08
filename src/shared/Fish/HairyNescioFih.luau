return {
	Name = "Hairy Nescio Fih",
	Rarity = "Admin",
	RarityDenominator = 5000000,
	MinKg = 20,
	AverageKg = 48,
	MaxKg = 180,
	BaseValue = 150000,
	Fight = 0.35,
	Pools = { "MainLake", "OpenSea" },
	Seasons = { "Spring", "Summer", "Autumn", "Winter" },
	Shapes = {
		Normal = { "#####", "#####" },
		Big = { "######", "######", "######" },
		Huge = { "########", "########", "########", "########" },
	},
	-- The Nescio Fih, but worse: the same pale creature under a shaggy coat
	-- of brown hair, with a long mane down its back.
	Build = function(b, kit)
		kit.nescio(b, { hairy = true })
	end,
}
