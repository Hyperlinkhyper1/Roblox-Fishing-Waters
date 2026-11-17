-- Region and season rules are gameplay choices; the body joins the shared EditableMesh loft pipeline.
return {
	Name = "Queen Triggerfish",
	ScientificName = "Balistes vetula",
	Rarity = "Rare",
	RarityDenominator = 28,
	MinKg = 0.3,
	AverageKg = 2,
	MaxKg = 8,
	BaseValue = 166,
	Fight = 0.09,
	Pools = { "PirateCove" },
	Seasons = { "Autumn", "Winter" },
	Shapes = {
		Normal = { "##" },
		Big = { "###", ".#." },
		Huge = { "####", "####" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(107, 76, 109), side = rgb(177, 153, 141), belly = rgb(225, 207, 173) }
		local fin = rgb(58, 129, 165)
		local dark, pale = rgb(25, 29, 35), rgb(249, 246, 222)
		b:fishBody(0.42, 0.16, colors, 0.10)
		b:edgeFin(0.21, 0.10, { 0.17, 0.035 }, fin)
		b:edgeFin(-0.03, -0.27, { 0.13, 0.18, 0.095 }, fin)
		b:edgeFin(-0.03, -0.27, { 0.12, 0.16, 0.085 }, fin, true)
		b:forkTail(0.20, 0.07, fin)
		b:pectoral(0.22, -0.035, 0.115, 0.04, rgb(227, 180, 108))
		-- Blue facial arcs and long tail lobes separate this queen from the other triggers.
		b:marks(0.29, 0.03, 0.035, 0.20, rgb(77, 169, 210), v2(-0.4, 1))
		b:marks(0.17, -0.015, 0.024, 0.23, rgb(77, 169, 210), v2(-0.4, 1))
		b:marks(0.40, -0.03, 0.11, 0.06, rgb(68, 123, 164))
		b:marks(-0.10, 0.01, 0.30, 0.06, rgb(209, 183, 116), v2(1, 0.25))
		b:eye(0.35, 0.06, 0.05, rgb(195, 164, 91))
	end,
}
