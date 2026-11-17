-- Region and season rules are gameplay choices; the body joins the shared EditableMesh loft pipeline.
return {
	Name = "Flame Angelfish",
	ScientificName = "Centropyge loricula",
	Rarity = "Rare",
	RarityDenominator = 18,
	MinKg = 0.03,
	AverageKg = 0.12,
	MaxKg = 0.6,
	BaseValue = 89,
	Fight = 0.03,
	Pools = { "CinderIsles" },
	Seasons = { "Summer", "Autumn" },
	Shapes = {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "##", "##" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(177, 51, 20), side = rgb(247, 104, 25), belly = rgb(255, 173, 69) }
		local fin = rgb(38, 57, 139)
		local dark, pale = rgb(25, 29, 35), rgb(249, 246, 222)
		b:fishBody(0.37, 0.11, colors, 0.08)
		b:edgeFin(0.15, -0.24, { 0.06, 0.075, 0.075, 0.055 }, fin)
		b:edgeFin(-0.01, -0.24, { 0.06, 0.08, 0.055 }, fin, true)
		b:roundTail(0.11, rgb(241, 132, 44))
		b:pectoral(0.20, -0.035, 0.10, 0.035, rgb(248, 160, 52))
		for _, x in { 0.15, 0.035, -0.08, -0.19 } do
		    b:marks(x, 0.015, 0.032, (b:top(x) - b:bottom(x)) * 0.83, dark)
		end
		b:marks(0.29, 0.02, 0.06, 0.10, colors.side)
		b:face(0.37, 0.035, 0.044, rgb(126, 91, 49), rgb(127, 42, 30))
	end,
}
