return {
	Name = "Coho Salmon",
	Rarity = "Rare",
	RarityDenominator = 12,
	MinKg = 0.8,
	AverageKg = 3.5,
	MaxKg = 15,
	BaseValue = 136,
	Fight = 0.08,
	Pools = { "MainLake", "FrostmereExpanse" },
	Seasons = { "Autumn", "Winter" },
	Requires = { "Rain", "Day" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", ".##." },
		Huge = { "#####", "#####" },
	},
	-- Bright silver flanks, blue-green back and a lightly spotted upper tail.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(42, 82, 96), side = rgb(188, 204, 208), belly = rgb(238, 242, 236) }
		local fin, spot = rgb(76, 110, 122), rgb(36, 46, 44)
		b:fishBody(0.23, 0.125, colors, 0.05)
		b:edgeFin(0.08, -0.08, { 0.085, 0.08, 0.055, 0.035 }, fin)
		b:ellipsoid("AdiposeFin", CFrame.new(-0.25, b:top(-0.25) + 0.008, 0), Vector3.new(0.055, 0.035, 0.014), fin)
		b:edgeFin(-0.12, -0.25, { 0.06, 0.055, 0.035 }, fin, true)
		b:edgeFin(0.02, -0.06, { 0.05, 0.04 }, fin, true)
		b:forkTail(0.12, 0.04, fin)
		b:pectoral(0.22, -0.045, 0.11, 0.04, fin)
		b:speckle(18, v2(-0.30, 0.30), v2(0, 0.11), v2(0.009, 0.017), spot)
		for _, y in { 0.035, 0.065, 0.085 } do
			b:finSpot(-0.46, y, 0.011, spot)
			b:finSpot(-0.425, y * 0.55, 0.008, spot)
		end
		b:stroke({ v2(0.28, -0.012), v2(0, -0.016), v2(-0.28, -0.008) }, 0.005, fin)
		b:face(0.38, 0.025, 0.04, rgb(200, 196, 154), fin)
	end,
}

