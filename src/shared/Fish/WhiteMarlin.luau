return {
	Name = "White Marlin",
	Rarity = "Epic",
	RarityDenominator = 32,
	MinKg = 8,
	AverageKg = 25,
	MaxKg = 90,
	LengthScale = 1.5,
	BaseValue = 310,
	Fight = 0.09,
	Pools = { "PirateCove" },
	Seasons = { "Spring", "Summer" },
	Requires = { "Day" },
	Shapes = {
		Normal = { "####", ".##." },
		Big = { "#####", ".###." },
		Huge = { "######", ".####." },
	},
	-- Pale silver flanks and a rounded, dark-spotted first dorsal.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(36, 62, 104), side = rgb(168, 190, 210), belly = rgb(240, 244, 244) }
		local fin = rgb(74, 102, 146)
		b:fishBody(0.17, 0.095, colors, 0.02)
		local dorsal = b:edgeFin(0.26, -0.23, { 0.12, 0.17, 0.18, 0.15, 0.10, 0.055, 0.025 }, fin, false, 0.05)
		for index = 3, 6 do
			local tip = dorsal[index]
			b:finSpot(tip.X, b:top(tip.X) + (tip.Y - b:top(tip.X)) * 0.6, 0.017, rgb(28, 46, 82))
		end
		b:edgeFin(-0.25, -0.3, { 0.025 }, fin)
		b:edgeFin(0.0, -0.16, { 0.075, 0.055, 0.03 }, fin, true)
		b:edgeFin(-0.25, -0.3, { 0.025 }, fin, true)
		b:lunateTail(0.20, fin)
		b:pectoral(0.23, -0.025, 0.17, 0.042, fin)
		for _, side in { 1, -1 } do
			b:limb(Vector3.new(0.17, b:bottom(0.17), side * 0.012), Vector3.new(-0.03, -0.15, side * 0.024), 0.006, fin, "PelvicFin")
		end
		for x = 0.2, -0.26, -0.06 do
			b:stroke({ v2(x, b:top(x) * 0.65), v2(x - 0.012, b:bottom(x) * 0.3) }, 0.007, rgb(132, 162, 204))
		end
		b:limb(Vector3.new(0.44, 0.006, 0), Vector3.new(0.78, 0.002, 0), 0.018, colors.back, "Bill")
		b:face(0.37, 0.024, 0.04, rgb(180, 192, 198), rgb(84, 108, 144))
	end,
}
