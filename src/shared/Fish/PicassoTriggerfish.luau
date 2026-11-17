-- Region and season rules are gameplay choices; the body joins the shared EditableMesh loft pipeline.
return {
	Name = "Picasso Triggerfish",
	ScientificName = "Rhinecanthus aculeatus",
	Rarity = "Rare",
	RarityDenominator = 24,
	MinKg = 0.12,
	AverageKg = 0.6,
	MaxKg = 2.8,
	BaseValue = 122,
	Fight = 0.07,
	Pools = { "CinderIsles" },
	Seasons = { "Spring", "Summer" },
	Shapes = {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "##", "##" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(114, 110, 79), side = rgb(209, 198, 149), belly = rgb(243, 237, 201) }
		local fin = rgb(69, 114, 126)
		local dark, pale = rgb(25, 29, 35), rgb(249, 246, 222)
		b:fishBody(0.38, 0.15, colors, 0.08)
		b:edgeFin(0.21, 0.10, { 0.15, 0.035 }, dark)
		b:edgeFin(-0.04, -0.27, { 0.09, 0.11, 0.06 }, fin)
		b:edgeFin(-0.04, -0.26, { 0.09, 0.1, 0.055 }, fin, true)
		b:forkTail(0.13, 0.012, colors.back)
		b:pectoral(0.22, -0.025, 0.11, 0.04, fin)
		-- Angular eye bars and bold diagonal belly wedges resemble a painted mask.
		b:marks(0.24, 0.045, 0.05, 0.23, dark, v2(-0.45, 1))
		b:marks(0.27, 0.055, 0.016, 0.22, rgb(60, 164, 208), v2(-0.45, 1))
		b:marks(-0.03, -0.06, 0.24, 0.065, dark, v2(1, 0.6))
		b:marks(-0.17, -0.025, 0.18, 0.035, pale, v2(1, 0.7))
		b:marks(0.36, -0.035, 0.12, 0.045, rgb(230, 180, 38))
		b:eye(0.35, 0.055, 0.05, rgb(174, 155, 85))
	end,
}
