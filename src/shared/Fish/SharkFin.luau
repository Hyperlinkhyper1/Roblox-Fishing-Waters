return {
	Name = "Shark Fin",
	Rarity = "Uncommon",
	RarityDenominator = 5,
	MinKg = 1,
	AverageKg = 1,
	MaxKg = 1,
	BaseValue = 90,
	Fight = 0,
	DropOnly = true,
	Shapes = {
		Normal = { "#" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		b:fin({ v2(-0.36, -0.16), v2(0.30, -0.16), v2(0.05, 0.38), v2(-0.08, 0.16) }, rgb(103, 121, 128))
	end,
}
