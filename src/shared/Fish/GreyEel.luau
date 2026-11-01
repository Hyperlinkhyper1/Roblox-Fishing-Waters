return {
	Name = "Grey Eel",
	Rarity = "Rare",
	RarityDenominator = 20,
	MinKg = 0.5,
	AverageKg = 2,
	MaxKg = 12,
	BaseValue = 65,
	Fight = 0.06,
	Pools = { "MainLake" },
	Seasons = { "Summer" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", "#..." },
		Huge = { "#####", "#...#" },
	},
	Build = function(b, kit)
		local rgb, eel = kit.rgb, kit.eel
		eel(b, {
			back = rgb(84, 88, 92),
			side = rgb(128, 132, 134),
			belly = rgb(208, 206, 192),
			fin = rgb(110, 112, 108),
			iris = rgb(150, 150, 120),
		})
	end,
}
