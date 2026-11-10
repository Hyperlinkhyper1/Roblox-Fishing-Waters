return {
	Name = "Yellowfin Tuna",
	Rarity = "Rare",
	RarityDenominator = 12,
	MinKg = 6,
	AverageKg = 35,
	MaxKg = 200,
	LengthScale = 1.3,
	BaseValue = 150,
	Fight = 0.08,
	Pools = { "OpenSea" },
	Seasons = { "Summer" },
	Shapes = {
		Normal = { "###", "###" },
		Big = { "####", "####" },
		Huge = { ".####.", "######", ".####." },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(24, 40, 82), side = rgb(150, 160, 176), belly = rgb(232, 234, 236) }
		local fin, yellow = rgb(40, 52, 84), rgb(242, 196, 40)
		b:fishBody(0.27, 0.2, colors, 0.03)
		b:edgeFin(0.14, 0.02, { 0.08, 0.06, 0.03 }, fin, false, 0.05)
		-- Long yellow sickle fins, the species' trademark.
		b:fin({ v2(0, b:top(0) - 0.008), v2(-0.14, b:top(0) + 0.22), v2(-0.09, b:top(-0.09) - 0.008) }, yellow)
		b:fin(
			{ v2(-0.02, b:bottom(-0.02) + 0.008), v2(-0.16, b:bottom(-0.02) - 0.2), v2(-0.1, b:bottom(-0.1) + 0.008) },
			yellow
		)
		for index = 0, 5 do
			local x = -0.15 - index * 0.03
			for _, below in { false, true } do
				local edge = if below then b:bottom(x) else b:top(x)
				local sign = if below then -1 else 1
				b:fin({
					v2(x + 0.008, edge - sign * 0.004),
					v2(x - 0.012, edge + sign * 0.022),
					v2(x - 0.014, edge - sign * 0.004),
				}, yellow)
			end
		end
		b:lunateTail(0.24, fin)
		b:pectoral(0.21, 0.01, 0.19, 0.065, fin)
		b:stroke({ v2(0.28, 0.035), v2(0, 0.04), v2(-0.28, 0.012) }, 0.018, yellow)
		for x = 0.1, -0.24, -0.05 do
			b:stroke({ v2(x, -0.03), v2(x - 0.01, b:bottom(x) * 0.7) }, 0.006, rgb(200, 206, 214))
		end
		b:face(0.37, 0.03, 0.05, rgb(180, 170, 120), rgb(70, 80, 100))
	end,
}
