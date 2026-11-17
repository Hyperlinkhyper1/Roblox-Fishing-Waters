-- Regional seasonal species; fishBody exposes a smooth loft to FishMeshes' EditableMesh renderer.
-- Mirror carp are a real scale-pattern variety of common carp, not a separate species.
return {
	Name = "Mirror Carp",
	ScientificName = "Cyprinus carpio",
	Rarity = "Rare",
	RarityDenominator = 22,
	MinKg = 1,
	AverageKg = 6,
	MaxKg = 32,
	BaseValue = 104,
	Fight = 0.08,
	Pools = { "MainLake" },
	Seasons = { "Autumn", "Winter" },
	Shapes = {
		Normal = { "##", "##" },
		Big = { "###", "###" },
		Huge = { "####", "####" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(94, 72, 40), side = rgb(178, 137, 66), belly = rgb(229, 204, 139) }
		local fin, dark = rgb(158, 95, 46), rgb(99, 74, 34)
		b:fishBody(0.39, 0.22, colors, 0.11)
		b:layered("ShoulderHump", Vector3.new(0.16, 0.055, 0), Vector3.new(0.34, 0.29, 0.195), colors)
		b:edgeFin(0.18, -0.24, { 0.055, 0.075, 0.07, 0.06, 0.045, 0.035 }, fin)
		b:edgeFin(-0.09, -0.23, { 0.055, 0.06, 0.035 }, fin, true)
		b:edgeFin(0.07, -0.01, { 0.045, 0.03 }, fin, true)
		b:forkTail(0.15, 0.045, fin)
		b:pectoral(0.23, -0.065, 0.1, 0.05, fin, 0.05)
		-- Sparse oversized reflective scales distinguish this carp variant.
		for _, point in { v2(0.18, 0.07), v2(0.03, 0.08), v2(-0.13, 0.06), v2(-0.25, 0.015), v2(0.10, -0.065) } do
			b:marks(point.X, point.Y, 0.086, 0.07, rgb(215, 187, 119))
			b:marks(point.X + 0.018, point.Y + 0.004, 0.035, 0.048, rgb(238, 211, 147))
		end
		for _, side in { 1, -1 } do
			b:limb(Vector3.new(0.43, -0.055, side * 0.036), Vector3.new(0.38, -0.13, side * 0.06), 0.008, fin, "Barbel")
		end
		b:face(0.37, 0.04, 0.04, rgb(217, 167, 68), dark)
	end,
}

