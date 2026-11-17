return {
	Name = "Yellow Bullhead",
	Rarity = "Common",
	RarityDenominator = 5,
	MinKg = 0.1,
	AverageKg = 0.55,
	MaxKg = 3,
	BaseValue = 16,
	Fight = 0.04,
	Pools = { "MainLake", "SoddenMire" },
	Seasons = { "Summer", "Autumn" },
	Requires = { "Rain" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "###", "###" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(100, 90, 36), side = rgb(184, 162, 66), belly = rgb(240, 222, 150) }
		local fin, whisker = rgb(152, 128, 46), rgb(236, 226, 186)
		b:fishBody(0.24, 0.2, colors, 0.16)
		local dorsal = b:edgeFin(0.15, 0.025, { 0.11, 0.075, 0.045 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3] }, colors.back)
		b:ellipsoid("AdiposeFin", CFrame.new(-0.23, b:top(-0.23) + 0.006, 0), Vector3.new(0.1, 0.032, 0.015), fin)
		b:edgeFin(-0.02, -0.31, { 0.045, 0.055, 0.055, 0.055, 0.045 }, fin, true)
		b:edgeFin(0.06, -0.005, { 0.045 }, fin, true)
		b:roundTail(0.115, fin)
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
		b:stroke({ v2(0.27, -0.055), v2(0, -0.075), v2(-0.25, -0.03) }, 0.012, rgb(226, 202, 112))
		b:face(0.4, 0.018, 0.031, rgb(182, 146, 46), colors.back)
	end,
}
