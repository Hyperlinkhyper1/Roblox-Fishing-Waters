return {
	Name = "Blue Mackerel",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 0.2,
	AverageKg = 0.6,
	MaxKg = 2.5,
	BaseValue = 11,
	Fight = 0.05,
	Pools = { "MainLake" },
	Seasons = { "Summer" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "####" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(32, 92, 118), side = rgb(158, 182, 192), belly = rgb(238, 240, 240) }
		local fin = rgb(72, 94, 104)
		b:fishBody(0.17, 0.11, colors, 0.03)
		local spines = b:edgeFin(0.11, -0.01, { 0.07, 0.065, 0.05, 0.035 }, fin, false, 0.1)
		b:rays(spines[1], { spines[4], spines[5], spines[6] }, rgb(40, 56, 64))
		b:edgeFin(-0.08, -0.14, { 0.04, 0.03 }, fin)
		b:edgeFin(-0.08, -0.14, { 0.04, 0.03 }, fin, true)
		for index = 0, 4 do
			local x = -0.17 - index * 0.028
			for _, below in { false, true } do
				local edge = if below then b:bottom(x) else b:top(x)
				local sign = if below then -1 else 1
				b:fin({
					v2(x + 0.008, edge - sign * 0.004),
					v2(x - 0.012, edge + sign * 0.02),
					v2(x - 0.014, edge - sign * 0.004),
				}, rgb(196, 184, 96))
			end
		end
		b:forkTail(0.13, 0.085, fin)
		b:pectoral(0.21, -0.02, 0.09, 0.03, fin)
		for x = 0.21, -0.3, -0.04 do
			local top = b:top(x)
			b:stroke({ v2(x, top * 0.88), v2(x - 0.022, top * 0.52), v2(x + 0.004, top * 0.18) }, 0.007, rgb(16, 36, 50))
		end
		for x = 0.16, -0.26, -0.05 do
			b:marks(x, -0.03 + math.sin(x * 40) * 0.006, 0.012, 0.012, rgb(112, 126, 136))
		end
		b:face(0.375, 0.015, 0.052, rgb(196, 204, 196), rgb(90, 108, 118))
	end,
}
