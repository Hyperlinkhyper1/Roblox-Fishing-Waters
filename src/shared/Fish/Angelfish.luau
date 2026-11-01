return {
	Name = "Angelfish",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 0.08,
	AverageKg = 0.25,
	MaxKg = 1.2,
	BaseValue = 28,
	Fight = 0.03,
	Pools = { "MainLake" },
	Seasons = { "Summer" },
	Shapes = {
		Normal = { "#" },
		Big = { "#", "#" },
		Huge = { "#.", "##", "#." },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(184, 186, 180), side = rgb(216, 218, 216), belly = rgb(238, 240, 240) }
		local fin = rgb(206, 208, 206)
		b:fishBody(0.5, 0.07, colors, 0.12)
		b:fin({ v2(0.16, 0.2), v2(-0.02, 0.42), v2(-0.36, 0.66), v2(-0.26, 0.26), v2(-0.24, 0.1) }, fin, 0.2)
		b:fin({ v2(0.1, -0.2), v2(-0.04, -0.42), v2(-0.36, -0.66), v2(-0.26, -0.26), v2(-0.24, -0.1) }, fin, 0.2)
		b:roundTail(0.13, fin, 0.2)
		for _, side in { 1, -1 } do
			b:limb(
				Vector3.new(0.14, -0.2, side * 0.02),
				Vector3.new(0.0, -0.66, side * 0.03),
				0.008,
				rgb(226, 224, 214),
				"Filament"
			)
		end
		for _, tip in { v2(-0.6, 0.22), v2(-0.6, -0.22) } do
			b:limb(Vector3.new(-0.46, tip.Y * 0.5, 0), Vector3.new(tip.X, tip.Y, 0), 0.006, fin, "Filament")
		end
		local dark = rgb(26, 26, 30)
		b:stroke({ v2(0.33, b:top(0.33) - 0.01), v2(0.33, b:bottom(0.33) + 0.01) }, 0.045, dark)
		b:stroke({ v2(0.1, b:top(0.1) - 0.01), v2(0.08, b:bottom(0.08) + 0.01) }, 0.055, dark)
		b:stroke({ v2(-0.15, b:top(-0.15) - 0.01), v2(-0.17, b:bottom(-0.17) + 0.01) }, 0.045, dark)
		b:rays(v2(0.09, 0.22), { v2(-0.12, 0.5) }, dark)
		b:rays(v2(0.07, -0.22), { v2(-0.12, -0.5) }, dark)
		b:rays(v2(-0.15, 0.17), { v2(-0.3, 0.55) }, dark)
		b:rays(v2(-0.17, -0.17), { v2(-0.3, -0.55) }, dark)
		b:pectoral(0.2, -0.02, 0.09, 0.03, fin, 0.3)
		b:face(0.37, 0.06, 0.05, rgb(196, 70, 54), rgb(170, 170, 160))
	end,
}
