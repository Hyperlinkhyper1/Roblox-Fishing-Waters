return {
	Name = "Aurora Rockfish",
	Rarity = "Rare",
	RarityDenominator = 16,
	MinKg = 0.3,
	AverageKg = 0.8,
	MaxKg = 2.5,
	BaseValue = 142,
	Fight = 0.04,
	Pools = { "FrostmereExpanse" },
	Seasons = { "Autumn", "Winter" },
	Requires = { "Night" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", ".##." },
		Huge = { "#####", "#####" },
	},
	-- Rose-red body, dusky mottling and large golden eyes.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(134, 58, 60), side = rgb(216, 116, 102), belly = rgb(246, 206, 182) }
		local fin = rgb(176, 76, 68)
		b:fishBody(0.28, 0.14, colors, 0.08)
		b:layered("LowerJaw", Vector3.new(0.405, -0.052, 0), Vector3.new(0.17, 0.075, 0.09100000000000001), colors)
		local spines = b:edgeFin(0.2, -0.08, { 0.045, 0.09, 0.105, 0.10, 0.085, 0.07, 0.04 }, fin)
		for index = 3, #spines - 1 do
			local tip = spines[index]
			b:rays(v2(tip.X, b:top(tip.X)), { tip }, colors.back)
		end
		b:edgeFin(-0.08, -0.27, { 0.075, 0.085, 0.07, 0.04 }, fin, false, 0.05)
		b:edgeFin(-0.08, -0.25, { 0.065, 0.07, 0.045 }, fin, true)
		b:edgeFin(0.1, 0.015, { 0.055, 0.04 }, fin, true)
		b:roundTail(0.13, fin)
		b:pectoral(0.24, -0.045, 0.15, 0.065, fin)
		b:speckle(24, v2(-0.3, 0.3), v2(-0.09, 0.12), v2(0.014, 0.032), rgb(112, 48, 54))
		-- A raised brow and short cheek spines distinguish the rockfish head.
		for _, side in { 1, -1 } do
			b:limb(Vector3.new(0.34, 0.07, side * 0.042), Vector3.new(0.30, 0.092, side * 0.049), 0.013, colors.back, "Brow")
			b:limb(Vector3.new(0.26, -0.005, side * 0.06720000000000001), Vector3.new(0.20, -0.015, side * 0.09100000000000001), 0.012, fin, "CheekSpine")
		end
		b:face(0.37, 0.045, 0.061, rgb(234, 198, 114), colors.back)
	end,
}

