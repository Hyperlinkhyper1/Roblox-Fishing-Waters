return {
	Name = "Broadbill Swordfish",
	Rarity = "Epic",
	RarityDenominator = 50,
	MinKg = 15,
	AverageKg = 85,
	MaxKg = 600,
	LengthScale = 1.6,
	BaseValue = 480,
	Fight = 0.10,
	Pools = { "OpenSea" },
	Seasons = { "Spring", "Summer", "Autumn" },
	Requires = { "Night" },
	Shapes = {
		Normal = { "#####" },
		Big = { "######", ".####." },
		Huge = { "#######", ".#####." },
	},
	-- Broad flattened sword, large eyes and a short sickle dorsal; no pelvic fins.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(40, 42, 60), side = rgb(116, 122, 140), belly = rgb(216, 222, 228) }
		local fin = rgb(40, 46, 66)
		b:fishBody(0.21, 0.16, colors, 0.02)
		b:layered("Shoulder", Vector3.new(0.2, 0.015, 0), Vector3.new(0.34, 0.23, 0.18), colors)
		local crest = b:top(0.12)
		b:fin({
			v2(0.25, b:top(0.25) - 0.008), v2(0.15, crest + 0.12),
			v2(0.07, crest + 0.18), v2(0.1, crest + 0.07), v2(0.12, crest - 0.008),
		}, fin)
		b:edgeFin(-0.23, -0.29, { 0.035 }, fin)
		b:edgeFin(0.0, -0.13, { 0.11, 0.065, 0.03 }, fin, true)
		b:edgeFin(-0.23, -0.29, { 0.03 }, fin, true)
		b:lunateTail(0.24, fin)
		b:pectoral(0.22, -0.04, 0.19, 0.04, fin)
		for _, side in { 1, -1 } do
			b:ellipsoid("TailKeel", CFrame.new(-0.33, 0, side * 0.024), Vector3.new(0.105, 0.025, 0.038), colors.back)
		end
		b:ellipsoid("SwordBase", CFrame.new(0.57, 0.005, 0), Vector3.new(0.28, 0.025, 0.085), colors.back)
		b:fin({
			Vector3.new(0.45, 0.006, -0.044), Vector3.new(1.04, 0.006, -0.006),
			Vector3.new(1.07, 0.006, 0), Vector3.new(1.04, 0.006, 0.006),
			Vector3.new(0.45, 0.006, 0.044),
		}, rgb(66, 72, 90))
		b:face(0.365, 0.025, 0.07, rgb(112, 136, 156), rgb(62, 72, 94))
	end,
}
