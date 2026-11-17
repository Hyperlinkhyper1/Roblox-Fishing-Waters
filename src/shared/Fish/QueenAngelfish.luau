-- Region and season rules are gameplay choices; the body joins the shared EditableMesh loft pipeline.
return {
	Name = "Queen Angelfish",
	ScientificName = "Holacanthus ciliaris",
	Rarity = "Rare",
	RarityDenominator = 24,
	MinKg = 0.15,
	AverageKg = 0.9,
	MaxKg = 3.8,
	BaseValue = 128,
	Fight = 0.06,
	Pools = { "PirateCove" },
	Seasons = { "Spring", "Winter" },
	Shapes = {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "##", "##" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(43, 86, 119), side = rgb(80, 169, 174), belly = rgb(183, 221, 180) }
		local fin = rgb(243, 211, 65)
		local dark, pale = rgb(25, 29, 35), rgb(249, 246, 222)
		b:fishBody(0.46, 0.12, colors, 0.11)
		b:edgeFin(0.19, -0.26, { 0.06, 0.08, 0.12, 0.17, 0.10 }, fin)
		b:edgeFin(0.03, -0.26, { 0.09, 0.16, 0.11 }, fin, true)
		b:limb(Vector3.new(-0.22, 0.20, 0), Vector3.new(-0.43, 0.33, 0), 0.009, fin, "DorsalStreamer")
		b:limb(Vector3.new(-0.22, -0.19, 0), Vector3.new(-0.42, -0.30, 0), 0.009, fin, "AnalStreamer")
		b:roundTail(0.12, fin)
		b:pectoral(0.21, -0.04, 0.12, 0.04, fin)
		b:marks(0.26, 0.15, 0.11, 0.07, rgb(56, 172, 211))
		b:marks(0.26, 0.15, 0.065, 0.035, dark)
		for x = 0.1, -0.25, -0.08 do
		    b:marks(x, 0, 0.015, 0.22, rgb(191, 206, 103), v2(0.3, 1))
		end
		b:face(0.37, 0.05, 0.047, rgb(246, 212, 79), rgb(48, 107, 125))
	end,
}
