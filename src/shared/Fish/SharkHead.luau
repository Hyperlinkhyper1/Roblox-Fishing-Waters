return {
	Name = "Shark Head",
	Rarity = "Epic",
	RarityDenominator = 20,
	MinKg = 1,
	AverageKg = 1,
	MaxKg = 1,
	BaseValue = 400,
	Fight = 0,
	DropOnly = true,
	Shapes = {
		Normal = { "#" },
	},
	Build = function(b, kit)
		local rgb = kit.rgb
		b:ellipsoid("Head", CFrame.new(), Vector3.new(0.65, 0.28, 0.25), rgb(136, 151, 156))
		b:ellipsoid("Belly", CFrame.new(0, -0.07, 0), Vector3.new(0.59, 0.13, 0.23), rgb(214, 216, 210))
		for _, side in { -1, 1 } do
			b:ellipsoid("Eye", CFrame.new(0.18, 0.04, side * 0.116), Vector3.new(0.035, 0.035, 0.015), rgb(20, 24, 26))
		end
	end,
}
