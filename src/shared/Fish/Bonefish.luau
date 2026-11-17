-- Region and season rules are gameplay choices; the body joins the shared EditableMesh loft pipeline.
return {
	Name = "Bonefish",
	ScientificName = "Albula vulpes",
	Rarity = "Uncommon",
	RarityDenominator = 12,
	MinKg = 0.2,
	AverageKg = 1.4,
	MaxKg = 9,
	BaseValue = 84,
	Fight = 0.08,
	Pools = { "CoralShallows" },
	Seasons = { "Spring", "Summer", "Autumn" },
	Shapes = {
		Normal = { "##" },
		Big = { "###", ".#." },
		Huge = { "####", "####" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(83, 118, 120), side = rgb(193, 215, 207), belly = rgb(247, 248, 229) }
		local fin = rgb(127, 166, 158)
		local dark, pale = rgb(25, 29, 35), rgb(249, 246, 222)
		b:fishBody(0.21, 0.13, colors, 0.055)
		b:edgeFin(0.12, -0.04, { 0.11, 0.08, 0.045 }, fin, false, 0.10)
		b:edgeFin(-0.14, -0.26, { 0.05, 0.06, 0.035 }, fin, true, 0.10)
		b:edgeFin(0.05, -0.015, { 0.04, 0.035 }, fin, true, 0.10)
		b:forkTail(0.18, 0.065, fin, 0.08)
		b:pectoral(0.24, -0.035, 0.14, 0.03, fin, 0.1)
		-- Silver lateral flashes and fine back stripes retain the long torpedo shape.
		for _, y in { 0.015, 0.045, 0.070 } do
		    b:marks(-0.01, y, 0.54 - y * 2, 0.007, rgb(102, 149, 144))
		end
		b:marks(0.01, -0.025, 0.57, 0.014, pale)
		b:marks(0.43, -0.035, 0.07, 0.02, rgb(137, 163, 146))
		b:face(0.37, 0.026, 0.045, rgb(189, 191, 144), rgb(104, 139, 132))
	end,
}
