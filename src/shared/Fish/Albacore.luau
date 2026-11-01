return {
	Name = "Albacore",
	Rarity = "Epic",
	RarityDenominator = 30,
	MinKg = 4,
	AverageKg = 15,
	MaxKg = 45,
	BaseValue = 380,
	Fight = 0.07,
	Pools = { "OpenSea" },
	Seasons = { "Autumn", "Winter" },
	Shapes = {
		Normal = { "###", "###" },
		Big = { "####", "####" },
		Huge = { ".####.", "######", ".####." },
	},
	-- Long-finned tuna: dark blue back and pectorals that reach past the second dorsal.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(20, 32, 66), side = rgb(140, 152, 172), belly = rgb(236, 238, 240) }
		local fin = rgb(32, 44, 76)
		b:fishBody(0.245, 0.18, colors, 0.03)
		b:edgeFin(0.14, 0.02, { 0.08, 0.06, 0.03 }, fin, false, 0.05)
		b:fin({ v2(-0.01, b:top(-0.01) - 0.008), v2(-0.1, b:top(-0.01) + 0.1), v2(-0.08, b:top(-0.08) - 0.008) }, fin)
		b:fin({
			v2(-0.03, b:bottom(-0.03) + 0.008),
			v2(-0.12, b:bottom(-0.03) - 0.09),
			v2(-0.09, b:bottom(-0.09) + 0.008),
		}, fin)
		for index = 0, 5 do
			local x = -0.15 - index * 0.03
			for _, below in { false, true } do
				local edge = if below then b:bottom(x) else b:top(x)
				local sign = if below then -1 else 1
				b:fin({
					v2(x + 0.008, edge - sign * 0.004),
					v2(x - 0.012, edge + sign * 0.02),
					v2(x - 0.014, edge - sign * 0.004),
				}, rgb(120, 116, 80))
			end
		end
		b:lunateTail(0.23, fin)
		-- Very long pectoral fins are the albacore's trademark.
		b:pectoral(0.21, 0.01, 0.34, 0.06, fin)
		b:stroke({ v2(0.28, 0.03), v2(0, 0.035), v2(-0.28, 0.01) }, 0.012, rgb(100, 130, 180))
		b:face(0.37, 0.03, 0.05, rgb(170, 170, 150), rgb(60, 70, 100))
	end,
}
