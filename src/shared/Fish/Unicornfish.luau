-- Region and season rules are gameplay choices; the body joins the shared EditableMesh loft pipeline.
return {
	Name = "Bluespine Unicornfish",
	ScientificName = "Naso unicornis",
	Rarity = "Rare",
	RarityDenominator = 21,
	MinKg = 0.3,
	AverageKg = 1.6,
	MaxKg = 6,
	BaseValue = 145,
	Fight = 0.06,
	Pools = { "CoralShallows" },
	Seasons = { "Spring", "Winter" },
	Shapes = {
		Normal = { "##" },
		Big = { "###", ".#." },
		Huge = { "####", "####" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(66, 109, 112), side = rgb(142, 183, 167), belly = rgb(221, 226, 191) }
		local fin = rgb(83, 150, 158)
		local dark, pale = rgb(25, 29, 35), rgb(249, 246, 222)
		b:fishBody(0.39, 0.13, colors, 0.05)
		b:edgeFin(0.19, -0.26, { 0.07, 0.085, 0.08, 0.065 }, fin)
		b:edgeFin(0.01, -0.24, { 0.065, 0.08, 0.05 }, fin, true)
		b:lunateTail(0.17, fin)
		b:pectoral(0.21, -0.025, 0.13, 0.045, fin)
		-- The forward forehead horn and paired blue tail scalpels give the silhouette its identity.
		b:limb(Vector3.new(0.32, 0.13, 0), Vector3.new(0.59, 0.18, 0), 0.032, colors.back, "ForeheadHorn")
		b:marks(-0.29, 0.01, 0.065, 0.022, rgb(71, 153, 195))
		b:marks(-0.24, 0.0, 0.034, 0.018, rgb(71, 153, 195))
		b:marks(0.06, -0.035, 0.26, 0.026, rgb(204, 217, 173))
		b:face(0.37, 0.045, 0.045, rgb(191, 188, 104), rgb(72, 115, 113))
	end,
}
