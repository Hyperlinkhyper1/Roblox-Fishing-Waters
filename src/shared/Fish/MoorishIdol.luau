-- Region and season rules are gameplay choices; the body joins the shared EditableMesh loft pipeline.
return {
	Name = "Moorish Idol",
	ScientificName = "Zanclus cornutus",
	Rarity = "Rare",
	RarityDenominator = 20,
	MinKg = 0.06,
	AverageKg = 0.3,
	MaxKg = 1.4,
	BaseValue = 102,
	Fight = 0.06,
	Pools = { "CoralShallows", "PirateCove" },
	Seasons = { "Spring", "Summer", "Autumn" },
	Shapes = {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "##", "##" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(229, 224, 188), side = rgb(248, 241, 207), belly = rgb(255, 249, 221) }
		local fin = rgb(235, 211, 76)
		local dark, pale = rgb(25, 29, 35), rgb(249, 246, 222)
		b:fishBody(0.47, 0.09, colors, 0.1)
		b:layered("TubeSnout", Vector3.new(0.45, -0.045, 0), Vector3.new(0.15, 0.07, 0.055), colors)
		b:fin({ v2(0.18, 0.19), v2(0.08, 0.43), v2(-0.16, 0.64), v2(-0.1, 0.35), v2(-0.26, 0.14) }, pale)
		b:limb(Vector3.new(-0.1, 0.42, 0), Vector3.new(-0.28, 0.69, 0), 0.008, pale, "DorsalStreamer")
		b:edgeFin(0.04, -0.22, { 0.12, 0.16, 0.10 }, fin, true)
		b:forkTail(0.13, 0.03, dark)
		b:pectoral(0.20, -0.03, 0.105, 0.035, fin)
		for _, x in { 0.24, -0.08, -0.29 } do
		    b:marks(x, 0, 0.075, math.max(0.07, b:top(x) - b:bottom(x)) * 0.94, dark)
		end
		b:marks(0.09, -0.07, 0.12, 0.14, fin)
		b:face(0.37, 0.045, 0.045, rgb(187, 153, 59), dark)
	end,
}
