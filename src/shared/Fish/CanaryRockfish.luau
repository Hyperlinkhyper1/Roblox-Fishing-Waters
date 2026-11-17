return {
	Name = "Canary Rockfish",
	Rarity = "Rare",
	RarityDenominator = 14,
	MinKg = 0.4,
	AverageKg = 1.8,
	MaxKg = 5.5,
	BaseValue = 138,
	Fight = 0.04,
	Pools = { "FrostmereExpanse", "CinderIsles" },
	Seasons = { "Spring", "Summer" },
	Requires = { "Day" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", ".##." },
		Huge = { "#####", "#####" },
	},
	-- Golden-orange flanks and three pale diagonal head stripes.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(192, 100, 28), side = rgb(242, 166, 58), belly = rgb(250, 228, 174) }
		local fin = rgb(224, 132, 34)
		b:fishBody(0.31, 0.15, colors, 0.08)
		b:layered("LowerJaw", Vector3.new(0.405, -0.052, 0), Vector3.new(0.17, 0.075, 0.0975), colors)
		local spines = b:edgeFin(0.2, -0.08, { 0.045, 0.09, 0.105, 0.10, 0.085, 0.07, 0.04 }, fin)
		for index = 3, #spines - 1 do
			local tip = spines[index]
			b:rays(v2(tip.X, b:top(tip.X)), { tip }, colors.back)
		end
		b:edgeFin(-0.08, -0.27, { 0.075, 0.085, 0.07, 0.04 }, fin, false, 0.05)
		b:edgeFin(-0.08, -0.25, { 0.065, 0.07, 0.045 }, fin, true)
		b:edgeFin(0.1, 0.015, { 0.055, 0.04 }, fin, true)
		b:forkTail(0.14, 0.025, fin)
		b:pectoral(0.24, -0.045, 0.15, 0.065, fin)
		for _, y in { 0.065, 0.015, -0.04 } do
			b:stroke({ v2(0.41, y + 0.025), v2(0.26, y - 0.025) }, 0.017, rgb(246, 214, 148))
		end
		-- A raised brow and short cheek spines distinguish the rockfish head.
		for _, side in { 1, -1 } do
			b:limb(Vector3.new(0.34, 0.07, side * 0.045), Vector3.new(0.30, 0.092, side * 0.0525), 0.013, colors.back, "Brow")
			b:limb(Vector3.new(0.26, -0.005, side * 0.072), Vector3.new(0.20, -0.015, side * 0.0975), 0.012, fin, "CheekSpine")
		end
		b:face(0.37, 0.045, 0.049, rgb(244, 204, 86), colors.back)
	end,
}

