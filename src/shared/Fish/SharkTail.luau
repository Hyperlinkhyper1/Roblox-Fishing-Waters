return {
	Name = "Shark Tail",
	Rarity = "Rare",
	RarityDenominator = 1 / 0.12,
	MinKg = 1,
	AverageKg = 1,
	MaxKg = 1,
	BaseValue = 180,
	Fight = 0,
	DropOnly = true,
	Shapes = {
		Normal = { "#" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		b:ellipsoid("TailBase", CFrame.new(0.19, 0, 0), Vector3.new(0.35, 0.13, 0.13), rgb(130, 145, 151))
		b:fin({ v2(0.12, 0), v2(-0.40, 0.40), v2(-0.23, 0.06), v2(-0.38, -0.27) }, rgb(103, 121, 128))
	end,
}
