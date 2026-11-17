-- Region and season rules are gameplay choices; the body joins the shared EditableMesh loft pipeline.
return {
	Name = "Mandarinfish",
	ScientificName = "Synchiropus splendidus",
	Rarity = "Epic",
	RarityDenominator = 42,
	MinKg = 0.01,
	AverageKg = 0.05,
	MaxKg = 0.2,
	BaseValue = 176,
	Fight = 0.03,
	Pools = { "CoralShallows" },
	Seasons = { "Spring", "Summer" },
	Requires = { "Night" },
	Shapes = {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "##", "##" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(20, 63, 93), side = rgb(32, 128, 151), belly = rgb(127, 197, 183) }
		local fin = rgb(225, 109, 38)
		local dark, pale = rgb(25, 29, 35), rgb(249, 246, 222)
		b:fishBody(0.27, 0.15, colors, 0.07)
		b:edgeFin(0.14, -0.03, { 0.12, 0.10 }, fin)
		b:edgeFin(-0.09, -0.26, { 0.08, 0.075, 0.04 }, fin)
		b:edgeFin(-0.06, -0.24, { 0.07, 0.07, 0.045 }, fin, true)
		b:roundTail(0.12, fin)
		b:pectoral(0.24, -0.04, 0.15, 0.08, rgb(46, 173, 170), 0.1)
		-- Broad orange maze lines, with dark rims supplied by the teal body.
		b:stroke({ v2(0.25, 0.06), v2(0.10, 0.04), v2(0.04, -0.04), v2(-0.10, -0.05) }, 0.025, fin)
		b:stroke({ v2(0.10, 0.10), v2(-0.08, 0.08), v2(-0.22, 0.015) }, 0.024, fin)
		b:marks(-0.16, 0, 0.085, 0.045, rgb(22, 68, 121))
		b:marks(-0.16, 0, 0.045, 0.024, fin)
		b:eye(0.37, 0.065, 0.055, rgb(226, 155, 54))
	end,
}
