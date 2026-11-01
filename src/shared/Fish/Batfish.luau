return {
	Name = "Batfish",
	Rarity = "Uncommon",
	RarityDenominator = 12,
	MinKg = 0.2,
	AverageKg = 0.8,
	MaxKg = 4,
	BaseValue = 34,
	Fight = 0.04,
	Pools = { "MainLake", "GullhavenSound" },
	Seasons = { "Summer" },
	Requires = { "Rain" },
	Shapes = {
		Normal = { "#" },
		Big = { "#", "#" },
		Huge = { "#.", "##", "#." },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(96, 96, 100), side = rgb(196, 198, 196), belly = rgb(232, 232, 226) }
		local fin = rgb(58, 56, 62)
		local dark = rgb(34, 32, 38)
		-- Very deep, strongly compressed disc body with a small head.
		b:fishBody(0.5, 0.09, colors, 0.12)
		-- Tall leading dorsal lobe and long-based anal fin, both dark like a spadefish.
		b:edgeFin(0.16, -0.18, { 0.13, 0.17, 0.15, 0.1, 0.07, 0.05 }, fin, false, 0.05)
		b:edgeFin(0.02, -0.16, { 0.11, 0.1, 0.07, 0.05 }, fin, true, 0.05)
		-- Short pelvic filaments dangling below the chest.
		for _, side in { 1, -1 } do
			b:limb(
				Vector3.new(0.16, b:bottom(0.16) + 0.02, side * 0.015),
				Vector3.new(0.1, b:bottom(0.16) - 0.16, side * 0.03),
				0.007,
				fin,
				"Filament"
			)
		end
		b:forkTail(0.13, 0.04, fin)
		b:pectoral(0.2, -0.02, 0.09, 0.035, fin, 0.2)
		-- Pale margin along the trailing edges of the dark fins.
		b:stroke({ v2(-0.17, b:top(-0.17) + 0.13), v2(-0.2, b:top(-0.2) + 0.035) }, 0.012, rgb(206, 206, 200))
		b:stroke({ v2(-0.15, b:bottom(-0.15) - 0.1), v2(-0.18, b:bottom(-0.18) - 0.03) }, 0.012, rgb(206, 206, 200))
		-- Two to three broad dark vertical bands across the silvery flank.
		b:stroke({ v2(0.2, b:top(0.2) - 0.012), v2(0.19, b:bottom(0.19) + 0.012) }, 0.06, dark)
		b:stroke({ v2(-0.02, b:top(-0.02) - 0.012), v2(-0.03, b:bottom(-0.03) + 0.012) }, 0.075, dark)
		b:stroke({ v2(-0.22, b:top(-0.22) - 0.012), v2(-0.23, b:bottom(-0.23) + 0.012) }, 0.055, dark)
		-- Soft speckling over the back between the bands.
		b:speckle(22, v2(-0.3, 0.3), v2(0.02, 0.2), v2(0.008, 0.014), rgb(120, 120, 126))
		-- Small protruding mouth and a bright silvery iris.
		b:face(0.37, 0.05, 0.045, rgb(214, 210, 190), rgb(140, 138, 130))
		b:marks(0.45, -0.045, 0.03, 0.018, rgb(52, 48, 50))
	end,
}
