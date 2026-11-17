return {
	Name = "Blue Marlin",
	Rarity = "Legendary",
	RarityDenominator = 140,
	MinKg = 30,
	AverageKg = 140,
	MaxKg = 650,
	LengthScale = 1.65,
	BaseValue = 1050,
	Fight = 0.11,
	Pools = { "OpenSea" },
	Seasons = { "Summer", "Autumn" },
	Requires = { "Clear", "Day" },
	Shapes = {
		Normal = { "#####", ".###." },
		Big = { "######", ".####." },
		Huge = { "#######", "#######" },
	},
	-- Cobalt shoulders, faint blue bars and a tall pointed first dorsal.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(16, 42, 92), side = rgb(86, 148, 190), belly = rgb(226, 236, 240) }
		local fin = rgb(22, 48, 100)
		b:fishBody(0.225, 0.145, colors, 0.02)
		b:edgeFin(0.25, -0.24, { 0.17, 0.22, 0.13, 0.06, 0.03, 0.025, 0.02 }, fin)
		b:edgeFin(-0.25, -0.3, { 0.035 }, fin)
		b:edgeFin(0.0, -0.15, { 0.085, 0.05, 0.025 }, fin, true)
		b:edgeFin(-0.25, -0.3, { 0.03 }, fin, true)
		b:lunateTail(0.23, fin)
		b:pectoral(0.23, -0.035, 0.22, 0.05, fin)
		for _, side in { 1, -1 } do
			b:limb(Vector3.new(0.16, b:bottom(0.16), side * 0.012), Vector3.new(-0.08, -0.18, side * 0.025), 0.007, fin, "PelvicFin")
			b:ellipsoid("TailKeel", CFrame.new(-0.32, 0, side * 0.023), Vector3.new(0.10, 0.018, 0.028), colors.back)
		end
		for x = 0.2, -0.27, -0.055 do
			b:stroke({ v2(x, b:top(x) * 0.7), v2(x - 0.015, b:bottom(x) * 0.4) }, 0.009, rgb(62, 128, 184))
		end
		b:limb(Vector3.new(0.44, 0.008, 0), Vector3.new(0.83, 0.002, 0), 0.025, colors.back, "Bill")
		b:face(0.37, 0.032, 0.045, rgb(148, 180, 202), rgb(46, 78, 122))
	end,
}
