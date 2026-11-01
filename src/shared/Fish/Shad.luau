return {
	Name = "Shad",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 0.3,
	AverageKg = 1,
	MaxKg = 3.5,
	BaseValue = 10,
	Fight = 0.04,
	Pools = { "MainLake" },
	Seasons = { "Spring" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "####" },
	},
	-- American shad: a deep, silvery herring with a blue-green back and a dark
	-- shoulder spot followed by a row of smaller spots.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(44, 92, 108), side = rgb(192, 200, 204), belly = rgb(244, 244, 240) }
		local fin = rgb(160, 170, 174)
		b:fishBody(0.26, 0.1, colors, 0.06)
		b:edgeFin(0.06, -0.06, { 0.07, 0.06, 0.035 }, fin, false, 0.15)
		b:edgeFin(-0.12, -0.24, { 0.03, 0.025, 0.02 }, fin, true, 0.15)
		b:edgeFin(0.0, -0.05, { 0.03 }, fin, true, 0.15)
		b:forkTail(0.14, 0.1, fin, 0.1)
		b:pectoral(0.21, -0.05, 0.08, 0.025, fin, 0.15)
		b:stroke({ v2(0.26, 0.05), v2(-0.3, 0.02) }, 0.01, rgb(130, 170, 186))
		b:marks(0.22, 0.04, 0.036, 0.032, rgb(30, 40, 46))
		for x = 0.16, -0.06, -0.045 do
			b:marks(x, 0.04, 0.018, 0.018, rgb(44, 56, 62))
		end
		-- Sharp belly scutes along the keel.
		for x = 0.22, -0.22, -0.04 do
			b:stroke({ v2(x, b:bottom(x) * 0.6), v2(x - 0.01, b:bottom(x) * 0.88) }, 0.004, rgb(220, 226, 230))
		end
		b:face(0.37, 0.02, 0.05, rgb(216, 220, 214), rgb(120, 140, 150))
	end,
}
