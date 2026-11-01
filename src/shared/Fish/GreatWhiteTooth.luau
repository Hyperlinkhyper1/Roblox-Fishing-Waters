return {
	Name = "Great White Tooth",
	Rarity = "Legendary",
	RarityDenominator = 1 / 0.03,
	MinKg = 1,
	AverageKg = 1,
	MaxKg = 1,
	BaseValue = 800,
	Fight = 0,
	DropOnly = true,
	Shapes = {
		Normal = { "#" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		b:fin({ v2(-0.26, -0.25), v2(0.26, -0.25), v2(0.04, 0.40) }, rgb(239, 235, 211))
		b:ellipsoid("Root", CFrame.new(0, -0.24, 0), Vector3.new(0.53, 0.11, 0.10), rgb(203, 190, 161))
	end,
}
