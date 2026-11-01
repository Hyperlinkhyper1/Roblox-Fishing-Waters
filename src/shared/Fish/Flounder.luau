return {
	Name = "Flounder",
	Rarity = "Rare",
	RarityDenominator = 12,
	MinKg = 0.4,
	AverageKg = 1.5,
	MaxKg = 9,
	BaseValue = 145,
	Fight = 0.03,
	Pools = { "OpenSea" },
	Seasons = { "Spring", "Summer", "Autumn", "Winter" },
	Shapes = {
		Normal = { "##", "##" },
		Big = { "###", "##." },
		Huge = { "###", "###" },
	},
	Build = function(b, kit)
		local rgb, flatfish = kit.rgb, kit.flatfish
		flatfish(b, {
			top = rgb(118, 108, 84),
			under = rgb(240, 238, 230),
			fin = rgb(132, 120, 94),
			ray = rgb(90, 82, 62),
			light = rgb(214, 120, 54),
			dark = rgb(80, 72, 54),
			iris = rgb(200, 180, 110),
			mouth = rgb(60, 50, 36),
		})
	end,
}
