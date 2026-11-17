-- Region and season rules are gameplay choices; the body joins the shared EditableMesh loft pipeline.
return {
	Name = "Clown Triggerfish",
	ScientificName = "Balistoides conspicillum",
	Rarity = "Epic",
	RarityDenominator = 48,
	MinKg = 0.25,
	AverageKg = 1.8,
	MaxKg = 7.5,
	BaseValue = 217,
	Fight = 0.1,
	Pools = { "CinderIsles" },
	Seasons = { "Autumn", "Winter" },
	Shapes = {
		Normal = { "##" },
		Big = { "###", ".#." },
		Huge = { "####", "####" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(35, 38, 43), side = rgb(51, 58, 63), belly = rgb(91, 96, 92) }
		local fin = rgb(238, 188, 38)
		local dark, pale = rgb(25, 29, 35), rgb(249, 246, 222)
		b:fishBody(0.42, 0.18, colors, 0.09)
		b:edgeFin(0.22, 0.11, { 0.13, 0.04 }, colors.back)
		b:edgeFin(-0.04, -0.28, { 0.10, 0.12, 0.07 }, fin)
		b:edgeFin(-0.04, -0.26, { 0.085, 0.11, 0.06 }, fin, true)
		b:roundTail(0.14, fin)
		b:pectoral(0.23, -0.03, 0.11, 0.045, fin)
		for _, point in { v2(0.16, -0.06), v2(0.02, -0.10), v2(-0.11, -0.07), v2(-0.23, -0.02), v2(0.05, 0.005), v2(-0.09, 0.025) } do
		    b:marks(point.X, point.Y, 0.071, 0.057, pale)
		end
		b:marks(-0.11, 0.13, 0.27, 0.075, fin)
		b:marks(0.40, -0.03, 0.13, 0.09, fin)
		b:marks(0.40, -0.03, 0.06, 0.03, colors.back)
		b:eye(0.35, 0.065, 0.049, rgb(186, 148, 68))
	end,
}
