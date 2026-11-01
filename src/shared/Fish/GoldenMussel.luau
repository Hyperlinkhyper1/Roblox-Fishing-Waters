return {
	Name = "Golden Mussel",
	Rarity = "Rare",
	RarityDenominator = 12,
	MinKg = 0.05,
	AverageKg = 0.22,
	MaxKg = 1.1,
	BaseValue = 56,
	Fight = 0,
	Shapes = {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "##", "##" },
	},
	Build = function(b, kit)
		local rgb, mussel = kit.rgb, kit.mussel
		mussel(b, rgb(204, 158, 54), rgb(240, 212, 128))
	end,
}
