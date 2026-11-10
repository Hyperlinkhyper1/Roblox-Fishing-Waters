return {
	Name = "Shovelnose Sturgeon",
	Rarity = "Epic",
	RarityDenominator = 50,
	MinKg = 0.8,
	AverageKg = 2.5,
	MaxKg = 8,
	LengthScale = 1.6,
	BaseValue = 165,
	Fight = 0.05,
	Pools = { "MainLake" },
	Seasons = { "Spring", "Summer" },
	Shapes = {
		Normal = { "####" },
		Big = { "#####" },
		Huge = { "#####", ".###." },
	},
	Build = function(b, kit)
		local rgb, sturgeon = kit.rgb, kit.sturgeon
		sturgeon(b, {
			colors = { back = rgb(128, 106, 72), side = rgb(178, 158, 120), belly = rgb(236, 230, 212) },
			fin = rgb(140, 118, 84),
			scute = rgb(212, 200, 170),
			-- The flat, wide shovel snout gives the species its name.
			snout = Vector3.new(0.34, 0.032, 0.17),
			snoutAt = Vector3.new(0.5, -0.03, 0),
			barbelX = 0.5,
			filament = true,
			iris = rgb(160, 140, 96),
		})
	end,
}
