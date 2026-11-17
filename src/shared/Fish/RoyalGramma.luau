-- Region and season rules are gameplay choices; the body joins the shared EditableMesh loft pipeline.
return {
	Name = "Royal Gramma",
	ScientificName = "Gramma loreto",
	Rarity = "Uncommon",
	RarityDenominator = 11,
	MinKg = 0.015,
	AverageKg = 0.07,
	MaxKg = 0.3,
	BaseValue = 62,
	Fight = 0.02,
	Pools = { "PirateCove" },
	Seasons = { "Autumn", "Winter" },
	Shapes = {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "##", "##" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(91, 34, 127), side = rgb(158, 59, 186), belly = rgb(209, 117, 216) }
		local fin = rgb(232, 190, 35)
		local dark, pale = rgb(25, 29, 35), rgb(249, 246, 222)
		b:fishBody(0.27, 0.10, colors, 0.04)
		b:edgeFin(0.13, -0.25, { 0.06, 0.07, 0.08, 0.06 }, colors.side)
		b:edgeFin(-0.04, -0.23, { 0.07, 0.075, 0.04 }, fin, true)
		b:forkTail(0.12, 0.035, fin)
		b:pectoral(0.21, -0.025, 0.095, 0.04, colors.side)
		-- Violet forebody and the golden rear half meet behind the gill cover.
		b:marks(-0.16, 0, 0.37, 0.235, fin)
		b:marks(0.15, 0.01, 0.08, 0.04, rgb(217, 122, 215))
		b:finSpot(0.06, b:top(0.06) + 0.04, 0.035, dark)
		b:marks(0.33, 0.035, 0.12, 0.014, dark, v2(1, -0.5))
		b:face(0.37, 0.035, 0.043, rgb(240, 189, 63), rgb(87, 38, 109))
	end,
}
