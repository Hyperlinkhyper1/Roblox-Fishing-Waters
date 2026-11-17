return {
	Name = "White Catfish",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 0.2,
	AverageKg = 1.8,
	MaxKg = 9,
	BaseValue = 38,
	Fight = 0.06,
	Pools = { "MainLake" },
	Seasons = { "Spring", "Summer", "Autumn" },
	Requires = { "Night" },
	Shapes = {
		Normal = { "###" },
		Big = { "####" },
		Huge = { "#####", "#####" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(88, 104, 116), side = rgb(184, 196, 198), belly = rgb(246, 244, 228) }
		local fin, whisker = rgb(140, 154, 160), rgb(224, 224, 204)
		b:fishBody(0.22, 0.21, colors, 0.14)
		local dorsal = b:edgeFin(0.15, 0.025, { 0.11, 0.075, 0.045 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3] }, colors.back)
		b:ellipsoid("AdiposeFin", CFrame.new(-0.23, b:top(-0.23) + 0.006, 0), Vector3.new(0.1, 0.032, 0.015), fin)
		b:edgeFin(-0.02, -0.31, { 0.045, 0.055, 0.055, 0.055, 0.045 }, fin, true)
		b:edgeFin(0.06, -0.005, { 0.045 }, fin, true)
		b:forkTail(0.13, 0.025, fin)
		b:pectoral(0.24, -0.05, 0.12, 0.045, fin)
		-- Paired long maxillary barbels and four shorter chin barbels.
		for _, side in { 1, -1 } do
			local bend = Vector3.new(0.35, -0.055, side * 0.15)
			b:limb(Vector3.new(0.46, -0.01, side * 0.035), bend, 0.009, whisker, "Barbel")
			b:limb(bend, Vector3.new(0.2, -0.13, side * 0.18), 0.006, whisker, "Barbel")
			for _, z in { 0.015, 0.04 } do
				local chin = b:bottom(0.44)
				b:limb(Vector3.new(0.44, chin + 0.006, side * z), Vector3.new(0.4, chin - 0.055, side * z * 1.7), 0.006, whisker, "Barbel")
			end
		end
		-- Broad pale head and a lightly forked tail.
		b:marks(0.31, -0.035, 0.11, 0.05, rgb(226, 228, 210))
		b:face(0.4, 0.018, 0.031, rgb(178, 184, 142), colors.back)
	end,
}
