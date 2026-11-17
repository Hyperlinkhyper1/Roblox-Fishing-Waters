return {
	Name = "Blue Catfish",
	Rarity = "Rare",
	RarityDenominator = 16,
	MinKg = 1,
	AverageKg = 12,
	MaxKg = 65,
	BaseValue = 88,
	Fight = 0.11,
	Pools = { "MainLake", "SoddenMire" },
	Seasons = { "Spring", "Summer", "Autumn" },
	Requires = { "Night" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", "####" },
		Huge = { "######", "######" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(42, 66, 90), side = rgb(132, 166, 188), belly = rgb(232, 236, 230) }
		local fin, whisker = rgb(86, 124, 154), rgb(146, 174, 184)
		b:fishBody(0.235, 0.2, colors, 0.1)
		local dorsal = b:edgeFin(0.15, 0.025, { 0.11, 0.075, 0.045 }, fin, false, 0.05)
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
		-- Long, straight-edged anal fin and deeply forked blue tail.
		b:stroke({ v2(0.25, 0.025), v2(-0.05, 0.02), v2(-0.29, 0.005) }, 0.006, rgb(102, 140, 166))
		b:face(0.4, 0.018, 0.031, rgb(158, 176, 154), colors.back)
	end,
}
