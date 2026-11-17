-- Region and season rules are gameplay choices; the body joins the shared EditableMesh loft pipeline.
return {
	Name = "Yellow Tang",
	ScientificName = "Zebrasoma flavescens",
	Rarity = "Common",
	RarityDenominator = 7,
	MinKg = 0.05,
	AverageKg = 0.25,
	MaxKg = 1.1,
	BaseValue = 38,
	Fight = 0.02,
	Pools = { "CoralShallows" },
	Seasons = { "Summer", "Autumn" },
	Shapes = {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "##", "##" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(200, 159, 23), side = rgb(247, 216, 45), belly = rgb(255, 239, 123) }
		local fin = rgb(239, 190, 34)
		local dark, pale = rgb(25, 29, 35), rgb(249, 246, 222)
		b:fishBody(0.48, 0.09, colors, 0.12)
		b:layered("PointedSnout", Vector3.new(0.435, -0.045, 0), Vector3.new(0.16, 0.075, 0.065), colors)
		b:edgeFin(0.18, -0.25, { 0.09, 0.12, 0.11, 0.09, 0.05 }, fin)
		b:edgeFin(0.05, -0.22, { 0.11, 0.12, 0.07 }, fin, true)
		b:forkTail(0.14, 0.018, fin)
		b:pectoral(0.18, -0.04, 0.1, 0.035, rgb(255, 235, 116), 0.12)
		b:marks(-0.3, 0, 0.055, 0.018, pale)
		b:marks(0.07, 0.11, 0.16, 0.023, rgb(255, 231, 92))
		b:face(0.37, 0.045, 0.042, rgb(109, 91, 36), rgb(147, 111, 26))
	end,
}
