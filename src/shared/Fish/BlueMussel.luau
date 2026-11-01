return {
	Name = "Blue Mussel",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 0.03,
	AverageKg = 0.12,
	MaxKg = 0.6,
	BaseValue = 18,
	Fight = 0,
	Shapes = {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "##", "##" },
	},
	Build = function(b, kit)
		local rgb, mussel = kit.rgb, kit.mussel
		mussel(b, rgb(34, 52, 76), rgb(95, 122, 151))
	end,
}
