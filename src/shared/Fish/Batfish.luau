return {
	Name = "Batfish",
	Rarity = "Uncommon",
	RarityDenominator = 12,
	MinKg = 0.2,
	AverageKg = 0.8,
	MaxKg = 4,
	BaseValue = 34,
	Fight = 0.04,
	Pools = { "MainLake" },
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
		local pale = rgb(206, 206, 200)
		-- Wider, strongly compressed disc body with a small head; the extra
		-- Z depth keeps it looking chunky from the side and full head-on.
		b:fishBody(0.52, 0.14, colors, 0.12)
		-- Tall leading dorsal lobe and long-based anal fin, both dark like a
		-- spadefish, with ray rods fanning through the membranes.
		b:edgeFin(0.16, -0.18, { 0.13, 0.17, 0.15, 0.1, 0.07, 0.05 }, fin, false, 0.05)
		b:edgeFin(0.02, -0.16, { 0.11, 0.1, 0.07, 0.05 }, fin, true, 0.05)
		b:rays(v2(0.08, b:top(0.08) + 0.01), { v2(-0.02, b:top(-0.02) + 0.16), v2(-0.09, b:top(-0.09) + 0.12), v2(-0.16, b:top(-0.16) + 0.06) }, rgb(78, 76, 82))
		b:rays(v2(0.06, b:bottom(0.06) - 0.01), { v2(-0.04, b:bottom(-0.04) - 0.11), v2(-0.12, b:bottom(-0.12) - 0.06) }, rgb(78, 76, 82))
		-- Short pelvic filaments dangling below the chest.
		for _, side in { 1, -1 } do
			b:limb(
				Vector3.new(0.16, b:bottom(0.16) + 0.02, side * 0.02),
				Vector3.new(0.1, b:bottom(0.16) - 0.17, side * 0.04),
				0.008,
				fin,
				"Filament"
			)
			b:limb(
				Vector3.new(0.12, b:bottom(0.12) + 0.015, side * 0.018),
				Vector3.new(0.06, b:bottom(0.12) - 0.12, side * 0.03),
				0.006,
				fin,
				"Filament"
			)
		end
		b:forkTail(0.14, 0.04, fin)
		b:pectoral(0.2, -0.02, 0.1, 0.04, fin, 0.2)
		-- Pale margin along the trailing edges of the dark fins.
		b:stroke({ v2(-0.17, b:top(-0.17) + 0.13), v2(-0.2, b:top(-0.2) + 0.035) }, 0.014, pale)
		b:stroke({ v2(-0.15, b:bottom(-0.15) - 0.1), v2(-0.18, b:bottom(-0.18) - 0.03) }, 0.014, pale)
		-- Two to three broad dark vertical bands across the silvery flank,
		-- each one slightly wavy with a paler inner core like juvenile spades.
		b:stroke({ v2(0.2, b:top(0.2) - 0.012), v2(0.19, b:bottom(0.19) + 0.012) }, 0.06, dark)
		b:stroke({ v2(0.205, b:top(0.205) - 0.03), v2(0.19, 0.0) }, 0.022, rgb(120, 118, 120))
		b:stroke({ v2(-0.02, b:top(-0.02) - 0.012), v2(-0.03, b:bottom(-0.03) + 0.012) }, 0.075, dark)
		b:stroke({ v2(-0.015, b:top(-0.015) - 0.03), v2(-0.03, 0.0) }, 0.026, rgb(120, 118, 120))
		b:stroke({ v2(-0.22, b:top(-0.22) - 0.012), v2(-0.23, b:bottom(-0.23) + 0.012) }, 0.055, dark)
		b:stroke({ v2(-0.215, b:top(-0.215) - 0.025), v2(-0.228, 0.0) }, 0.018, rgb(120, 118, 120))
		-- Soft speckling over the back between the bands, plus a silver
		-- shimmer of tiny bright flecks along the upper flank.
		b:speckle(28, v2(-0.3, 0.3), v2(0.02, 0.2), v2(0.008, 0.016), rgb(120, 120, 126))
		b:speckle(18, v2(-0.28, 0.32), v2(0.0, 0.14), v2(0.005, 0.009), rgb(240, 242, 240))
		-- Faint darker edging above each eye for the classic spadefish brow.
		b:marks(0.37, 0.09, 0.05, 0.014, rgb(96, 94, 98))
		-- Small protruding mouth and a bright silvery iris.
		b:face(0.37, 0.05, 0.045, rgb(214, 210, 190), rgb(140, 138, 130))
		b:marks(0.45, -0.045, 0.032, 0.02, rgb(52, 48, 50))
		-- Chin barbel bump and a pale pelvic patch between the filaments.
		b:marks(0.42, b:bottom(0.42) * 0.6, 0.02, 0.016, rgb(148, 146, 148))
	end,
}
