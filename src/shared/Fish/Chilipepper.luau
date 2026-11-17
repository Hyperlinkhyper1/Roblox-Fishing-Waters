return {
	Name = "Chilipepper",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 0.2,
	AverageKg = 0.9,
	MaxKg = 3,
	BaseValue = 56,
	Fight = 0.04,
	Pools = { "CinderIsles" },
	Seasons = { "Summer", "Autumn" },
	Requires = { "Day" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", ".##." },
		Huge = { "#####", "#####" },
	},
	-- Slender red body with a fine copper lateral line.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(174, 48, 48), side = rgb(224, 100, 90), belly = rgb(246, 202, 186) }
		local fin = rgb(198, 70, 60)
		b:fishBody(0.23, 0.12, colors, 0.08)
		b:layered("LowerJaw", Vector3.new(0.405, -0.052, 0), Vector3.new(0.17, 0.075, 0.078), colors)
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
		b:stroke({ v2(0.29, 0.018), v2(0, 0.012), v2(-0.3, 0) }, 0.009, rgb(242, 168, 132))
		-- A raised brow and short cheek spines distinguish the rockfish head.
		for _, side in { 1, -1 } do
			b:limb(Vector3.new(0.34, 0.07, side * 0.036), Vector3.new(0.30, 0.092, side * 0.041999999999999996), 0.013, colors.back, "Brow")
			b:limb(Vector3.new(0.26, -0.005, side * 0.0576), Vector3.new(0.20, -0.015, side * 0.078), 0.012, fin, "CheekSpine")
		end
		b:face(0.37, 0.045, 0.046, rgb(230, 180, 90), colors.back)
	end,
}

