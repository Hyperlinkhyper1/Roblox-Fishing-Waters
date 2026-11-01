return {
	Name = "Catfish",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 0.6,
	AverageKg = 3,
	MaxKg = 28,
	BaseValue = 48,
	Fight = 0.04,
	Pools = { "OpenSea" },
	Seasons = { "Summer" },
	Requires = { "Rain" },
	Shapes = {
		Normal = { "###" },
		Big = { "###", "###" },
		Huge = { "####", "####" },
	},
	Build = function(b, kit)
		local rgb = kit.rgb
		local colors = { back = rgb(70, 74, 78), side = rgb(130, 132, 128), belly = rgb(226, 222, 210) }
		local fin, whisker = rgb(96, 98, 98), rgb(60, 60, 62)
		b:fishBody(0.2, 0.18, colors, 0.12)
		local dorsal = b:edgeFin(0.14, 0.03, { 0.1, 0.07, 0.04 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3] }, rgb(52, 54, 56))
		b:ellipsoid("AdiposeFin", CFrame.new(-0.22, b:top(-0.22) + 0.006, 0), Vector3.new(0.09, 0.03, 0.012), fin)
		b:edgeFin(-0.04, -0.3, { 0.04, 0.05, 0.05, 0.045, 0.04 }, fin, true)
		b:edgeFin(0.06, 0, { 0.04 }, fin, true)
		b:forkTail(0.11, 0.05, fin)
		b:pectoral(0.24, -0.06, 0.11, 0.035, fin)
		for _, side in { 1, -1 } do
			local bend = Vector3.new(0.36, -0.06, side * 0.14)
			b:limb(Vector3.new(0.46, -0.01, side * 0.035), bend, 0.009, whisker, "Barbel")
			b:limb(bend, Vector3.new(0.22, -0.12, side * 0.17), 0.006, whisker, "Barbel")
			for _, z in { 0.015, 0.04 } do
				local chin = b:bottom(0.44)
				b:limb(
					Vector3.new(0.44, chin + 0.006, side * z),
					Vector3.new(0.41, chin - 0.05, side * z * 1.6),
					0.006,
					rgb(200, 196, 186),
					"Barbel"
				)
			end
		end
		b:face(0.4, 0.02, 0.03, rgb(150, 140, 100), rgb(90, 92, 92))
	end,
}
