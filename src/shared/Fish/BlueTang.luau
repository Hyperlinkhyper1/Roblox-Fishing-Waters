-- Region and season rules are gameplay choices; the body joins the shared EditableMesh loft pipeline.
return {
	Name = "Blue Tang",
	ScientificName = "Paracanthurus hepatus",
	Rarity = "Rare",
	RarityDenominator = 16,
	MinKg = 0.08,
	AverageKg = 0.4,
	MaxKg = 1.8,
	BaseValue = 78,
	Fight = 0.04,
	Pools = { "CoralShallows" },
	Seasons = { "Spring", "Summer" },
	Shapes = {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "##", "##" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(12, 39, 135), side = rgb(36, 95, 224), belly = rgb(110, 164, 238) }
		local fin = rgb(247, 209, 48)
		local dark, pale = rgb(25, 29, 35), rgb(249, 246, 222)
		b:fishBody(0.43, 0.10, colors, 0.08)
		b:edgeFin(0.18, -0.27, { 0.07, 0.08, 0.07, 0.06, 0.04 }, colors.back)
		b:edgeFin(0.01, -0.25, { 0.07, 0.08, 0.05 }, colors.back, true)
		b:forkTail(0.15, 0.035, fin)
		b:pectoral(0.21, -0.03, 0.12, 0.035, fin)
		-- Curved black palette on the shoulder and back, plus a blue island inside it.
		b:marks(-0.03, 0.065, 0.46, 0.20, dark)
		b:marks(0.02, 0.055, 0.27, 0.09, colors.side)
		b:marks(-0.26, 0.005, 0.10, 0.07, dark)
		b:face(0.37, 0.045, 0.045, rgb(206, 185, 101), dark)
	end,
}
