return {
	Name = "Cowcod",
	Rarity = "Epic",
	RarityDenominator = 36,
	MinKg = 1.5,
	AverageKg = 7,
	MaxKg = 18,
	BaseValue = 395,
	Fight = 0.08,
	Pools = { "CinderIsles" },
	Seasons = { "Autumn", "Winter" },
	Requires = { "Night" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", ".##." },
		Huge = { "#####", "#####" },
	},
	-- Deep orange body, broad head, dark saddles and tall dorsal spines.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(156, 64, 40), side = rgb(224, 114, 64), belly = rgb(248, 202, 150) }
		local fin = rgb(186, 76, 44)
		b:fishBody(0.36, 0.19, colors, 0.08)
		b:layered("LowerJaw", Vector3.new(0.405, -0.052, 0), Vector3.new(0.17, 0.075, 0.12350000000000001), colors)
		local spines = b:edgeFin(0.2, -0.08, { 0.045, 0.09, 0.14, 0.10, 0.085, 0.07, 0.04 }, fin)
		for index = 3, #spines - 1 do
			local tip = spines[index]
			b:rays(v2(tip.X, b:top(tip.X)), { tip }, colors.back)
		end
		b:edgeFin(-0.08, -0.27, { 0.075, 0.085, 0.07, 0.04 }, fin, false, 0.05)
		b:edgeFin(-0.08, -0.25, { 0.065, 0.07, 0.045 }, fin, true)
		b:edgeFin(0.1, 0.015, { 0.055, 0.04 }, fin, true)
		b:roundTail(0.13, fin)
		b:pectoral(0.24, -0.045, 0.18, 0.065, fin)
		for _, x in { 0.25, 0.12, -0.03, -0.18, -0.29 } do
			b:stroke({ v2(x, b:top(x) * 0.84), v2(x - 0.02, b:bottom(x) * 0.65) }, 0.028, rgb(130, 50, 34))
		end
		-- A raised brow and short cheek spines distinguish the rockfish head.
		for _, side in { 1, -1 } do
			b:limb(Vector3.new(0.34, 0.07, side * 0.056999999999999995), Vector3.new(0.30, 0.092, side * 0.06649999999999999), 0.013, colors.back, "Brow")
			b:limb(Vector3.new(0.26, -0.005, side * 0.0912), Vector3.new(0.20, -0.015, side * 0.12350000000000001), 0.012, fin, "CheekSpine")
		end
		b:face(0.37, 0.045, 0.063, rgb(236, 186, 100), colors.back)
	end,
}

