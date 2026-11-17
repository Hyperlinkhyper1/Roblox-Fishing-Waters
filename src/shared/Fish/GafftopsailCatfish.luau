return {
	Name = "Gafftopsail Catfish",
	Rarity = "Rare",
	RarityDenominator = 17,
	MinKg = 0.4,
	AverageKg = 2.8,
	MaxKg = 8,
	BaseValue = 156,
	Fight = 0.09,
	Pools = { "CoralShallows", "PirateCove" },
	Seasons = { "Spring", "Summer" },
	Requires = { "Night" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", "####" },
		Huge = { "#####", "#####" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(56, 80, 102), side = rgb(166, 184, 198), belly = rgb(236, 236, 226) }
		local fin, whisker = rgb(110, 138, 160), rgb(190, 202, 200)
		b:fishBody(0.21, 0.18, colors, 0.1)
		local dorsal = b:edgeFin(0.15, 0.025, { 0.22, 0.15, 0.065 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3] }, colors.back)
		b:ellipsoid("AdiposeFin", CFrame.new(-0.23, b:top(-0.23) + 0.006, 0), Vector3.new(0.1, 0.032, 0.015), fin)
		b:edgeFin(-0.02, -0.31, { 0.045, 0.055, 0.055, 0.055, 0.045 }, fin, true)
		b:edgeFin(0.06, -0.005, { 0.045 }, fin, true)
		b:forkTail(0.13, 0.075, fin)
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
		-- Sail-like dorsal spine and long trailing pectoral filaments.
		local tip = Vector3.new(0.1, b:top(0.1) + 0.28, 0)
		b:limb(Vector3.new(0.17, b:top(0.17), 0), tip, 0.007, fin, "DorsalFilament")
		b:limb(tip, Vector3.new(-0.09, b:top(0.1) + 0.23, 0), 0.004, fin, "DorsalFilament")
		for _, side in { 1, -1 } do
			b:limb(Vector3.new(0.21, -0.045, side * 0.065), Vector3.new(-0.03, -0.14, side * 0.13), 0.006, fin, "PectoralFilament")
			b:limb(Vector3.new(-0.03, -0.14, side * 0.13), Vector3.new(-0.22, -0.15, side * 0.1), 0.004, fin, "PectoralFilament")
		end
		b:face(0.4, 0.018, 0.031, rgb(180, 188, 166), colors.back)
	end,
}
