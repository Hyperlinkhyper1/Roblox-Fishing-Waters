return {
	Name = "Trout",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 0.3,
	AverageKg = 1.2,
	MaxKg = 9,
	BaseValue = 10,
	Fight = 0.04,
	Pools = { "MainLake" },
	Seasons = { "Summer" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "###", "###" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(78, 90, 54), side = rgb(184, 188, 160), belly = rgb(240, 236, 224) }
		local fin = rgb(150, 142, 108)
		b:fishBody(0.21, 0.12, colors)
		b:edgeFin(0.07, -0.08, { 0.08, 0.075, 0.06, 0.04 }, fin)
		b:ellipsoid("AdiposeFin", CFrame.new(-0.25, b:top(-0.25) + 0.004, 0), Vector3.new(0.045, 0.028, 0.012), fin)
		b:edgeFin(-0.12, -0.23, { 0.06, 0.05, 0.035 }, fin, true)
		b:edgeFin(0.02, -0.07, { 0.05, 0.045 }, fin, true)
		b:forkTail(0.11, 0.045, fin)
		b:pectoral(0.2, -0.05, 0.1, 0.035, fin)
		for x = 0.26, -0.3, -0.028 do
			b:marks(x, -0.004, 0.055, 0.04 * (1 - math.abs(x) * 0.9), rgb(222, 128, 132))
		end
		b:marks(0.29, -0.01, 0.08, 0.045, rgb(216, 132, 128))
		b:speckle(46, v2(-0.33, 0.33), v2(-0.01, 0.11), v2(0.011, 0.018), rgb(32, 32, 26))
		for _ = 1, 9 do
			b:finSpot(b.random(-0.47, -0.37), b.random(-0.09, 0.09), 0.012, rgb(40, 40, 32))
		end
		for _ = 1, 4 do
			b:finSpot(b.random(-0.06, 0.04), b:top(0) + b.random(0.01, 0.05), 0.011, rgb(40, 40, 32))
		end
		b:face(0.37, 0.02, 0.045, rgb(204, 172, 96), rgb(120, 112, 96))
	end,
}
