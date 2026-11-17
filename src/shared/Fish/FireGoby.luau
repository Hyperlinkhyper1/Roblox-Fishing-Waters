-- Region and season rules are gameplay choices; the body joins the shared EditableMesh loft pipeline.
return {
	Name = "Fire Goby",
	ScientificName = "Nemateleotris magnifica",
	Rarity = "Uncommon",
	RarityDenominator = 10,
	MinKg = 0.01,
	AverageKg = 0.045,
	MaxKg = 0.18,
	BaseValue = 54,
	Fight = 0.02,
	Pools = { "CinderIsles" },
	Seasons = { "Spring", "Summer" },
	Shapes = {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "##", "##" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(215, 207, 180), side = rgb(246, 240, 214), belly = rgb(255, 249, 232) }
		local fin = rgb(214, 57, 44)
		local dark, pale = rgb(25, 29, 35), rgb(249, 246, 222)
		b:fishBody(0.20, 0.095, colors, 0.02)
		b:edgeFin(0.20, 0.09, { 0.23, 0.19 }, pale)
		b:edgeFin(0.00, -0.27, { 0.09, 0.08, 0.055 }, fin)
		b:edgeFin(-0.05, -0.25, { 0.065, 0.07, 0.04 }, fin, true)
		b:forkTail(0.13, 0.022, fin)
		b:pectoral(0.23, -0.035, 0.105, 0.035, pale, 0.2)
		b:marks(-0.19, -0.005, 0.34, 0.16, rgb(228, 80, 56))
		b:marks(-0.08, -0.015, 0.16, 0.12, rgb(248, 150, 93))
		b:marks(0.27, 0.03, 0.07, 0.017, rgb(222, 117, 91))
		b:eye(0.37, 0.035, 0.048, rgb(133, 95, 54))
	end,
}
