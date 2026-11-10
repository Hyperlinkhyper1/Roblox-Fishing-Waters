return {
	Name = "Green Sturgeon",
	Rarity = "Epic",
	RarityDenominator = 30,
	MinKg = 10,
	AverageKg = 45,
	MaxKg = 160,
	LengthScale = 1.7,
	BaseValue = 395,
	Fight = 0.07,
	Pools = { "OpenSea" },
	Seasons = { "Spring", "Summer" },
	Shapes = {
		Normal = { "#####" },
		Big = { "######", ".####." },
		Huge = { "#######", "#######" },
	},
	Build = function(b, kit)
		local rgb, sturgeon = kit.rgb, kit.sturgeon
		sturgeon(b, {
			colors = { back = rgb(62, 82, 52), side = rgb(124, 140, 100), belly = rgb(222, 224, 200) },
			fin = rgb(84, 98, 70),
			scute = rgb(196, 200, 172),
			snout = Vector3.new(0.27, 0.07, 0.085),
			snoutAt = Vector3.new(0.47, -0.016, 0),
			stripe = rgb(96, 132, 72),
			iris = rgb(150, 150, 110),
		})
	end,
}
