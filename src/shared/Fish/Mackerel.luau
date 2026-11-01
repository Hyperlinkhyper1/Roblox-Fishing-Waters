return {
	Name = "Mackerel",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 0.2,
	AverageKg = 0.5,
	MaxKg = 2,
	BaseValue = 18,
	Fight = 0.05,
	Pools = { "OpenSea" },
	Seasons = { "Spring", "Summer", "Autumn", "Winter" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "####" },
	},
	-- Atlantic mackerel: green-blue back with bold, wavy black bars above an
	-- unspotted silver belly, widely spaced dorsals and dark finlets.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(30, 100, 92), side = rgb(170, 192, 188), belly = rgb(244, 246, 244) }
		local fin, finlet = rgb(70, 92, 92), rgb(52, 70, 72)
		b:fishBody(0.16, 0.1, colors, 0.03)
		local spines = b:edgeFin(0.12, 0.02, { 0.065, 0.06, 0.045, 0.03 }, fin, false, 0.1)
		b:rays(spines[1], { spines[4], spines[5] }, rgb(36, 50, 52))
		b:edgeFin(-0.09, -0.15, { 0.04, 0.03 }, fin)
		b:edgeFin(-0.09, -0.15, { 0.035, 0.025 }, fin, true)
		for index = 0, 4 do
			local x = -0.18 - index * 0.028
			for _, below in { false, true } do
				local edge = if below then b:bottom(x) else b:top(x)
				local sign = if below then -1 else 1
				b:fin({
					v2(x + 0.008, edge - sign * 0.004),
					v2(x - 0.012, edge + sign * 0.02),
					v2(x - 0.014, edge - sign * 0.004),
				}, finlet)
			end
		end
		b:forkTail(0.13, 0.085, fin)
		b:pectoral(0.21, -0.02, 0.08, 0.028, fin)
		for x = 0.2, -0.3, -0.035 do
			local top = b:top(x)
			b:stroke({
				v2(x, top * 0.9),
				v2(x - 0.018, top * 0.62),
				v2(x + 0.006, top * 0.38),
				v2(x - 0.01, top * 0.12),
			}, 0.008, rgb(10, 24, 26))
		end
		b:face(0.375, 0.015, 0.05, rgb(196, 204, 196), rgb(90, 108, 112))
	end,
}
