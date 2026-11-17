-- Region and season rules are gameplay choices; the body joins the shared EditableMesh loft pipeline.
return {
	Name = "Powder Blue Tang",
	ScientificName = "Acanthurus leucosternon",
	Rarity = "Uncommon",
	RarityDenominator = 12,
	MinKg = 0.1,
	AverageKg = 0.5,
	MaxKg = 2.3,
	BaseValue = 64,
	Fight = 0.03,
	Pools = { "CoralShallows" },
	Seasons = { "Spring", "Winter" },
	Shapes = {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "##", "##" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(52, 105, 160), side = rgb(112, 190, 222), belly = rgb(221, 238, 227) }
		local fin = rgb(246, 211, 68)
		local dark, pale = rgb(25, 29, 35), rgb(249, 246, 222)
		b:fishBody(0.40, 0.105, colors, 0.08)
		b:edgeFin(0.2, -0.25, { 0.08, 0.09, 0.08, 0.065, 0.04 }, fin)
		b:edgeFin(0.01, -0.23, { 0.055, 0.075, 0.04 }, pale, true)
		b:lunateTail(0.15, pale)
		b:pectoral(0.2, -0.025, 0.11, 0.04, fin)
		-- Black face mask, a white throat and a yellow surgeon's scalpel near the tail.
		b:marks(0.30, 0.0, 0.20, 0.25, dark)
		b:marks(0.27, -0.08, 0.14, 0.09, pale)
		b:marks(-0.31, 0, 0.048, 0.018, fin)
		b:face(0.37, 0.045, 0.046, rgb(212, 179, 75), dark)
	end,
}
