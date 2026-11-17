-- Regional seasonal species; fishBody exposes a smooth loft to FishMeshes' EditableMesh renderer.
return {
	Name = "Brook Trout",
	ScientificName = "Salvelinus fontinalis",
	Rarity = "Uncommon",
	RarityDenominator = 10,
	MinKg = 0.15,
	AverageKg = 0.8,
	MaxKg = 5,
	BaseValue = 38,
	Fight = 0.05,
	Pools = { "FrostmereExpanse" },
	Seasons = { "Spring", "Autumn", "Winter" },
	Shapes = {
		Normal = { "###" },
		Big = { "####" },
		Huge = { "#####", ".###." },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(44, 72, 57), side = rgb(101, 137, 106), belly = rgb(225, 183, 128) }
		local fin, dark = rgb(173, 99, 70), rgb(25, 52, 46)
		b:fishBody(0.23, 0.12, colors, 0.04)
		b:edgeFin(0.09, -0.1, { 0.09, 0.08, 0.06, 0.035 }, fin)
		b:ellipsoid("AdiposeFin", CFrame.new(-0.25, b:top(-0.25) + 0.009, 0), Vector3.new(0.045, 0.026, 0.012), fin)
		b:edgeFin(-0.09, -0.23, { 0.055, 0.06, 0.035 }, fin, true)
		b:edgeFin(0.07, -0.01, { 0.045, 0.03 }, fin, true)
		b:forkTail(0.11, 0.025, fin)
		b:pectoral(0.23, -0.035, 0.1, 0.035, fin, 0.05)
		-- Pale vermiculations, red flank jewels and white fin leading edges.
		for x = 0.2, -0.26, -0.065 do
			b:marks(x, 0.012, 0.035, 0.024, rgb(204, 86, 77))
			b:marks(x - 0.018, 0.065, 0.025, 0.011, rgb(210, 211, 153), v2(1, 0.6))
		end
		b:limb(Vector3.new(0.02, -0.10, 0), Vector3.new(-0.04, -0.155, 0), 0.008, rgb(240, 235, 218), "WhiteFinEdge")
		b:face(0.37, 0.025, 0.04, rgb(222, 184, 99), dark)
	end,
}

