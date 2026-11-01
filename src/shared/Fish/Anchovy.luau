return {
	Name = "Anchovy",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 0.01,
	AverageKg = 0.04,
	MaxKg = 0.18,
	BaseValue = 17,
	Fight = 0.05,
	Pools = { "OpenSea" },
	Seasons = { "Summer" },
	Shapes = {
		Normal = { "#" },
		Big = { "#" },
		Huge = { "##" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(70, 112, 104), side = rgb(196, 204, 196), belly = rgb(236, 238, 232) }
		local fin = rgb(176, 184, 176)
		b:fishBody(0.15, 0.09, colors, 0.02)
		b:edgeFin(0.04, -0.06, { 0.05, 0.04, 0.025 }, fin, false, 0.25)
		b:edgeFin(-0.06, -0.2, { 0.025, 0.025, 0.02 }, fin, true, 0.25)
		b:forkTail(0.11, 0.08, fin, 0.2)
		b:pectoral(0.22, -0.035, 0.06, 0.02, fin, 0.25)
		b:stroke({ v2(0.24, 0), v2(-0.32, 0) }, 0.016, rgb(214, 224, 228))
		-- Rounded snout overhanging a long jaw.
		b:ellipsoid("Snout", CFrame.new(0.47, 0.012, 0), Vector3.new(0.07, 0.05, 0.05), colors.back)
		b:face(0.39, 0.015, 0.058, rgb(200, 206, 200), rgb(130, 140, 134))
		b:stroke({ v2(0.46, -0.012), v2(0.34, -0.028) }, 0.006, rgb(40, 40, 36))
	end,
}
