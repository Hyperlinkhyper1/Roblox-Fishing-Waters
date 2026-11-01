return {
	Name = "Shark Meat",
	Rarity = "Common",
	RarityDenominator = 1 / 0.60,
	MinKg = 1,
	AverageKg = 1,
	MaxKg = 1,
	BaseValue = 35,
	Fight = 0,
	DropOnly = true,
	Shapes = {
		Normal = { "#" },
	},
	-- Shark rewards are individual parts, built locally like the other catch models.
	Build = function(b, kit)
		local rgb = kit.rgb
		b:ellipsoid("Meat", CFrame.new(), Vector3.new(0.55, 0.27, 0.18), rgb(198, 112, 112))
		b:ellipsoid("Cut", CFrame.new(0.01, 0.01, 0.088), Vector3.new(0.43, 0.19, 0.012), rgb(236, 164, 154))
	end,
}
