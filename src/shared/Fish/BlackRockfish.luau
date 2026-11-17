return {
	Name = "Black Rockfish",
	Rarity = "Uncommon",
	RarityDenominator = 8,
	MinKg = 0.4,
	AverageKg = 1.5,
	MaxKg = 5,
	BaseValue = 54,
	Fight = 0.04,
	Pools = { "MainLake", "FrostmereExpanse" },
	Seasons = { "Spring", "Summer", "Autumn", "Winter" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", ".##." },
		Huge = { "#####", "#####" },
	},
	-- Charcoal back, slate flanks and irregular pale flecks.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(42, 49, 52), side = rgb(90, 100, 106), belly = rgb(190, 196, 196) }
		local fin = rgb(58, 66, 72)
		b:fishBody(0.29, 0.15, colors, 0.08)
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
		b:speckle(24, v2(-0.3, 0.3), v2(-0.09, 0.12), v2(0.014, 0.032), rgb(154, 162, 164))
		-- A raised brow and short cheek spines distinguish the rockfish head.
		for _, side in { 1, -1 } do
			b:limb(Vector3.new(0.34, 0.07, side * 0.045), Vector3.new(0.30, 0.092, side * 0.0525), 0.013, colors.back, "Brow")
			b:limb(Vector3.new(0.26, -0.005, side * 0.072), Vector3.new(0.20, -0.015, side * 0.0975), 0.012, fin, "CheekSpine")
		end
		b:face(0.37, 0.045, 0.044, rgb(186, 176, 136), colors.back)
	end,
}

