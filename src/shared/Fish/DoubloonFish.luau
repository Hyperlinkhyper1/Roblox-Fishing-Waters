return {
	Name = "Doubloon Fish",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 0.15,
	AverageKg = 0.6,
	MaxKg = 3,
	BaseValue = 52,
	Fight = 0.05,
	Pools = { "PirateCove" },
	Seasons = { "Spring", "Summer", "Autumn", "Winter" },
	Requires = { "Day" },
	Shapes = {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "##", "##" },
	},
	-- A round, coin-flat moonfish that only flashes gold in daylight. The cove's crew swear the
	-- ring on its flank is stamped by the sunken treasure it feeds around.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(170, 124, 28), side = rgb(234, 194, 70), belly = rgb(250, 232, 150) }
		local fin = rgb(222, 172, 56)
		local stamp = rgb(152, 106, 24)
		b:fishBody(0.52, 0.08, colors, 0.14)
		b:edgeFin(0.1, -0.2, { 0.14, 0.1, 0.06, 0.04 }, fin, false, 0.08)
		b:edgeFin(0.06, -0.2, { 0.12, 0.08, 0.05, 0.03 }, fin, true, 0.08)
		b:forkTail(0.16, 0.07, fin)
		b:pectoral(0.2, -0.02, 0.09, 0.03, fin, 0.2)
		-- The doubloon stamp: a ring with a cross in the middle.
		local ring = {}
		for step = 0, 16 do
			local angle = step / 16 * math.pi * 2
			table.insert(ring, v2(0.0 + math.cos(angle) * 0.11, 0.01 + math.sin(angle) * 0.11))
		end
		b:stroke(ring, 0.01, stamp)
		b:stroke({ v2(-0.05, 0.01), v2(0.05, 0.01) }, 0.01, stamp)
		b:stroke({ v2(0.0, -0.04), v2(0.0, 0.06) }, 0.01, stamp)
		b:face(0.37, 0.07, 0.05, rgb(244, 206, 84), rgb(160, 112, 30))
	end,
}
