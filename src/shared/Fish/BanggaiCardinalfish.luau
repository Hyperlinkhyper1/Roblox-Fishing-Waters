-- Region and season rules are gameplay choices; the body joins the shared EditableMesh loft pipeline.
return {
	Name = "Banggai Cardinalfish",
	ScientificName = "Pterapogon kauderni",
	Rarity = "Rare",
	RarityDenominator = 18,
	MinKg = 0.02,
	AverageKg = 0.09,
	MaxKg = 0.4,
	BaseValue = 96,
	Fight = 0.04,
	Pools = { "PirateCove" },
	Seasons = { "Spring", "Winter" },
	Shapes = {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "##", "##" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(139, 148, 144), side = rgb(215, 221, 204), belly = rgb(246, 246, 229) }
		local fin = rgb(59, 63, 60)
		local dark, pale = rgb(25, 29, 35), rgb(249, 246, 222)
		b:fishBody(0.34, 0.105, colors, 0.08)
		b:edgeFin(0.18, 0.02, { 0.20, 0.15 }, fin)
		b:edgeFin(-0.05, -0.26, { 0.18, 0.20, 0.10 }, fin)
		b:edgeFin(-0.03, -0.25, { 0.15, 0.17, 0.09 }, fin, true)
		b:forkTail(0.22, 0.09, fin)
		b:pectoral(0.21, -0.035, 0.10, 0.03, pale, 0.18)
		for _, x in { 0.29, 0.075, -0.18 } do
		    b:marks(x, 0, 0.055, (b:top(x) - b:bottom(x)) * 0.95, dark)
		end
		for _, point in { v2(0.0, 0.065), v2(-0.06, -0.02), v2(-0.27, 0.02), v2(0.16, -0.04) } do
		    b:marks(point.X, point.Y, 0.016, 0.016, pale)
		end
		b:eye(0.37, 0.045, 0.066, rgb(170, 172, 126))
	end,
}
