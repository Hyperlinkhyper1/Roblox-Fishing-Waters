return {
	Name = "Yellowshark",
	Rarity = "Legendary",
	RarityDenominator = 90,
	MinKg = 40,
	AverageKg = 180,
	MaxKg = 1100,
	BaseValue = 1260,
	Fight = 0.08,
	Pools = { "OpenSea" },
	Seasons = { "Summer" },
	Requires = { "Storm" },
	Shapes = {
		Normal = { "..#..", "#####", "#####" },
		Big = { "...#..", "######", "######", ".####." },
		Huge = { "...#...", "#######", "#######", "#######", ".#####." },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(196, 150, 32), side = rgb(232, 196, 70), belly = rgb(246, 238, 210) }
		local fin = rgb(204, 160, 40)
		b:fishBody(0.2, 0.19, colors, 0)
		b:layered("Snout", Vector3.new(0.43, 0.01, 0), Vector3.new(0.16, 0.1, 0.13), colors)
		b:fin({
			v2(0.12, b:top(0.12) - 0.008),
			v2(0, b:top(0) + 0.17),
			v2(-0.03, b:top(0) + 0.15),
			v2(-0.04, b:top(-0.04) - 0.008),
		}, fin)
		b:edgeFin(-0.22, -0.28, { 0.04, 0.025 }, fin)
		b:edgeFin(-0.2, -0.26, { 0.035, 0.02 }, fin, true)
		b:edgeFin(-0.04, -0.1, { 0.04, 0.03 }, fin, true)
		b:pectoral(0.18, -0.06, 0.2, 0.06, fin)
		-- Shark tail: the upper lobe reaches much further than the lower one.
		local stalk = b:top(-0.36)
		local upper, lower = v2(-0.34, stalk * 0.9), v2(-0.34, -stalk * 0.9)
		b:fin({ upper, v2(-0.6, 0.26), v2(-0.56, 0.2), v2(-0.42, 0), lower }, fin)
		b:fin({ lower, v2(-0.44, 0), v2(-0.52, -0.15) }, fin)
		b:speckle(24, v2(-0.3, 0.3), v2(0.02, 0.09), v2(0.015, 0.03), rgb(176, 128, 24))
		for index = 0, 4 do
			local x = 0.27 - index * 0.028
			b:stroke({ v2(x, 0.035), v2(x - 0.008, -0.04) }, 0.007, rgb(150, 110, 24))
		end
		b:stroke({ v2(0.43, -0.035), v2(0.38, -0.055), v2(0.32, -0.06) }, 0.008, rgb(60, 40, 20))
		b:eye(0.4, 0.03, 0.03, rgb(20, 20, 20))
	end,
}
