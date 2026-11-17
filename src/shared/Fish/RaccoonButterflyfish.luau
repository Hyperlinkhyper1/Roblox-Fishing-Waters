-- Region and season rules are gameplay choices; the body joins the shared EditableMesh loft pipeline.
return {
	Name = "Raccoon Butterflyfish",
	ScientificName = "Chaetodon lunula",
	Rarity = "Uncommon",
	RarityDenominator = 12,
	MinKg = 0.05,
	AverageKg = 0.28,
	MaxKg = 1.2,
	BaseValue = 61,
	Fight = 0.03,
	Pools = { "PirateCove" },
	Seasons = { "Autumn", "Winter" },
	Shapes = {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "##", "##" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(164, 112, 39), side = rgb(239, 191, 71), belly = rgb(255, 229, 137) }
		local fin = rgb(211, 148, 37)
		local dark, pale = rgb(25, 29, 35), rgb(249, 246, 222)
		b:fishBody(0.42, 0.095, colors, 0.11)
		b:edgeFin(0.16, -0.27, { 0.07, 0.10, 0.11, 0.09, 0.04 }, fin)
		b:edgeFin(0.0, -0.23, { 0.09, 0.095, 0.06 }, fin, true)
		b:roundTail(0.115, fin)
		b:pectoral(0.19, -0.04, 0.095, 0.035, colors.belly)
		-- Pale eye band between a black mask and the broad dark shoulder saddle.
		b:marks(0.27, 0.035, 0.17, 0.24, pale)
		b:marks(0.32, 0.025, 0.075, 0.21, dark)
		b:marks(0.13, 0.11, 0.14, 0.18, dark, v2(0.5, -1))
		for _, x in { 0.01, -0.10, -0.21 } do
		    b:marks(x, -0.01, 0.008, 0.16, rgb(175, 119, 37), v2(0.7, 1))
		end
		b:face(0.37, 0.045, 0.044, rgb(224, 178, 66), dark)
	end,
}
