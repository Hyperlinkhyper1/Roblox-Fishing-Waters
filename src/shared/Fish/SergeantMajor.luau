-- Region and season rules are gameplay choices; the body joins the shared EditableMesh loft pipeline.
return {
	Name = "Sergeant Major",
	ScientificName = "Abudefduf saxatilis",
	Rarity = "Common",
	RarityDenominator = 6,
	MinKg = 0.03,
	AverageKg = 0.18,
	MaxKg = 0.8,
	BaseValue = 35,
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
		local colors = { back = rgb(185, 167, 43), side = rgb(218, 215, 158), belly = rgb(242, 241, 221) }
		local fin = rgb(94, 107, 80)
		local dark, pale = rgb(25, 29, 35), rgb(249, 246, 222)
		b:fishBody(0.36, 0.12, colors, 0.07)
		b:edgeFin(0.15, -0.26, { 0.055, 0.065, 0.08, 0.075, 0.04 }, fin)
		b:edgeFin(-0.04, -0.23, { 0.08, 0.07, 0.04 }, fin, true)
		b:forkTail(0.14, 0.04, fin)
		b:pectoral(0.21, -0.03, 0.105, 0.04, rgb(222, 223, 181))
		for _, x in { 0.27, 0.14, 0.01, -0.12, -0.25 } do
		    b:marks(x, 0, 0.045, (b:top(x) - b:bottom(x)) * 0.96, dark)
		end
		b:marks(0.02, 0.115, 0.29, 0.05, rgb(239, 215, 63))
		b:face(0.37, 0.035, 0.044, rgb(188, 177, 90), rgb(80, 87, 69))
	end,
}
