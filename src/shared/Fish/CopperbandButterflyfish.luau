-- Region and season rules are gameplay choices; the body joins the shared EditableMesh loft pipeline.
return {
	Name = "Copperband Butterflyfish",
	ScientificName = "Chelmon rostratus",
	Rarity = "Uncommon",
	RarityDenominator = 13,
	MinKg = 0.04,
	AverageKg = 0.22,
	MaxKg = 0.9,
	BaseValue = 58,
	Fight = 0.02,
	Pools = { "CoralShallows" },
	Seasons = { "Spring", "Summer" },
	Shapes = {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "##", "##" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(208, 208, 185), side = rgb(245, 241, 218), belly = rgb(255, 250, 236) }
		local fin = rgb(219, 151, 50)
		local dark, pale = rgb(25, 29, 35), rgb(249, 246, 222)
		b:fishBody(0.43, 0.08, colors, 0.12)
		b:layered("LongSnout", Vector3.new(0.45, -0.06, 0), Vector3.new(0.23, 0.065, 0.05), colors)
		b:edgeFin(0.18, -0.25, { 0.07, 0.1, 0.11, 0.10, 0.05 }, fin)
		b:edgeFin(0.01, -0.25, { 0.08, 0.1, 0.06 }, fin, true)
		b:roundTail(0.10, colors.side)
		b:pectoral(0.2, -0.04, 0.09, 0.03, pale, 0.18)
		for _, x in { 0.31, 0.12, -0.09, -0.26 } do
		    b:marks(x, 0, 0.045, (b:top(x) - b:bottom(x)) * 0.92, fin)
		end
		b:marks(-0.20, 0.14, 0.06, 0.06, pale)
		b:marks(-0.20, 0.14, 0.04, 0.04, dark)
		b:face(0.37, 0.04, 0.043, rgb(212, 164, 55), rgb(173, 117, 50))
	end,
}
