return {
	Name = "Green Mussel",
	Rarity = "Uncommon",
	RarityDenominator = 6,
	MinKg = 0.04,
	AverageKg = 0.18,
	MaxKg = 0.9,
	BaseValue = 30,
	Fight = 0,
	Shapes = {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "##", "##" },
	},
	Build = function(b, kit)
		local rgb, mussel = kit.rgb, kit.mussel
		mussel(b, rgb(45, 100, 67), rgb(134, 175, 104))
	end,
}
