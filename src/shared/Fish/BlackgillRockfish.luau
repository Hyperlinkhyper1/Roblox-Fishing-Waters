return {
	Name = "Blackgill Rockfish",
	Rarity = "Rare",
	RarityDenominator = 20,
	MinKg = 0.5,
	AverageKg = 2.2,
	MaxKg = 6,
	BaseValue = 156,
	Fight = 0.05,
	Pools = { "CinderIsles", "PirateCove" },
	Seasons = { "Autumn", "Winter" },
	Requires = { "Night" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", ".##." },
		Huge = { "#####", "#####" },
	},
	-- Brick-red body with a conspicuous coal-dark gill cover.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(124, 54, 48), side = rgb(192, 98, 86), belly = rgb(232, 178, 154) }
		local fin = rgb(156, 62, 58)
		b:fishBody(0.3, 0.16, colors, 0.08)
		b:layered("LowerJaw", Vector3.new(0.405, -0.052, 0), Vector3.new(0.17, 0.075, 0.10400000000000001), colors)
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
		b:marks(0.25, 0.015, 0.075, 0.105, rgb(54, 37, 38))
		-- A raised brow and short cheek spines distinguish the rockfish head.
		for _, side in { 1, -1 } do
			b:limb(Vector3.new(0.34, 0.07, side * 0.048), Vector3.new(0.30, 0.092, side * 0.055999999999999994), 0.013, colors.back, "Brow")
			b:limb(Vector3.new(0.26, -0.005, side * 0.0768), Vector3.new(0.20, -0.015, side * 0.10400000000000001), 0.012, fin, "CheekSpine")
		end
		b:face(0.37, 0.045, 0.058, rgb(232, 176, 88), colors.back)
	end,
}

