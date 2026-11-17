return {
	Name = "Treefish",
	Rarity = "Rare",
	RarityDenominator = 18,
	MinKg = 0.2,
	AverageKg = 0.7,
	MaxKg = 2,
	BaseValue = 146,
	Fight = 0.04,
	Pools = { "CoralShallows", "PirateCove" },
	Seasons = { "Spring", "Summer", "Autumn" },
	Requires = { "Night" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", ".##." },
		Huge = { "#####", "#####" },
	},
	-- Yellow-green body with broad black vertical bars and reddish lips.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(98, 98, 38), side = rgb(198, 184, 70), belly = rgb(234, 218, 146) }
		local fin = rgb(166, 150, 54)
		b:fishBody(0.32, 0.16, colors, 0.08)
		b:layered("LowerJaw", Vector3.new(0.405, -0.052, 0), Vector3.new(0.17, 0.075, 0.10400000000000001), colors)
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
		for _, x in { 0.25, 0.12, -0.03, -0.18, -0.29 } do
			b:stroke({ v2(x, b:top(x) * 0.84), v2(x - 0.02, b:bottom(x) * 0.65) }, 0.045, rgb(42, 46, 32))
		end
		-- A raised brow and short cheek spines distinguish the rockfish head.
		for _, side in { 1, -1 } do
			b:limb(Vector3.new(0.34, 0.07, side * 0.048), Vector3.new(0.30, 0.092, side * 0.055999999999999994), 0.013, colors.back, "Brow")
			b:limb(Vector3.new(0.26, -0.005, side * 0.0768), Vector3.new(0.20, -0.015, side * 0.10400000000000001), 0.012, fin, "CheekSpine")
		end
		b:marks(0.455, -0.028, 0.035, 0.024, rgb(178, 72, 54))
		b:face(0.37, 0.045, 0.05, rgb(230, 178, 72), colors.back)
	end,
}

