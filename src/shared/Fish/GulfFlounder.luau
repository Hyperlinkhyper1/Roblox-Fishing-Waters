return {
	Name = "Gulf Flounder",
	Rarity = "Epic",
	RarityDenominator = 50,
	MinKg = 0.4,
	AverageKg = 1.5,
	MaxKg = 10,
	BaseValue = 160,
	Fight = 0.03,
	Pools = { "MainLake" },
	Seasons = { "Summer" },
	Shapes = {
		Normal = { "##", "##" },
		Big = { "###", "##." },
		Huge = { "###", "###" },
	},
	Build = function(b, kit)
		local rgb, v2, flatfish = kit.rgb, kit.v2, kit.flatfish
		flatfish(b, {
			top = rgb(124, 98, 66),
			under = rgb(238, 236, 228),
			fin = rgb(142, 114, 80),
			ray = rgb(100, 80, 56),
			light = rgb(156, 128, 90),
			dark = rgb(92, 70, 46),
			ocelli = { v2(-0.02, 0.11), v2(-0.02, -0.11), v2(-0.2, 0) },
			ring = rgb(204, 182, 142),
			center = rgb(36, 28, 22),
			iris = rgb(206, 176, 90),
			mouth = rgb(60, 44, 30),
		})
	end,
}
