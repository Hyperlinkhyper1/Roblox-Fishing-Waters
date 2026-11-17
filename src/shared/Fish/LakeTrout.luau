-- Regional seasonal species; fishBody exposes a smooth loft to FishMeshes' EditableMesh renderer.
return {
	Name = "Lake Trout",
	ScientificName = "Salvelinus namaycush",
	Rarity = "Rare",
	RarityDenominator = 21,
	MinKg = 0.6,
	AverageKg = 4.5,
	MaxKg = 42,
	BaseValue = 136,
	Fight = 0.09,
	Pools = { "FrostmereExpanse" },
	Seasons = { "Autumn", "Winter" },
	Shapes = {
		Normal = { "###" },
		Big = { "####" },
		Huge = { "#####", ".###." },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(48, 64, 60), side = rgb(114, 133, 116), belly = rgb(212, 218, 192) }
		local fin, dark = rgb(89, 110, 99), rgb(45, 62, 55)
		b:fishBody(0.22, 0.145, colors, 0.025)
		b:edgeFin(0.09, -0.1, { 0.075, 0.08, 0.055, 0.03 }, fin)
		b:ellipsoid("AdiposeFin", CFrame.new(-0.25, b:top(-0.25) + 0.009, 0), Vector3.new(0.045, 0.026, 0.012), fin)
		b:edgeFin(-0.09, -0.23, { 0.055, 0.06, 0.035 }, fin, true)
		b:edgeFin(0.07, -0.01, { 0.045, 0.03 }, fin, true)
		b:forkTail(0.14, 0.065, fin)
		b:pectoral(0.23, -0.035, 0.1, 0.035, fin, 0.05)
		b:speckle(20, v2(-0.3, 0.3), v2(-0.05, 0.07), v2(0.018, 0.03), rgb(213, 220, 166))
		b:marks(0.33, -0.025, 0.07, 0.035, rgb(195, 205, 160))
		b:face(0.37, 0.025, 0.04, rgb(220, 194, 110), dark)
	end,
}

