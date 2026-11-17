-- Regional seasonal species; fishBody exposes a smooth loft to FishMeshes' EditableMesh renderer.
return {
	Name = "Dolly Varden",
	ScientificName = "Salvelinus malma",
	Rarity = "Uncommon",
	RarityDenominator = 13,
	MinKg = 0.15,
	AverageKg = 0.95,
	MaxKg = 9,
	BaseValue = 74,
	Fight = 0.055,
	Pools = { "FrostmereExpanse" },
	Seasons = { "Summer", "Autumn", "Winter" },
	Shapes = {
		Normal = { "###" },
		Big = { "####" },
		Huge = { "#####", ".###." },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(43, 78, 73), side = rgb(96, 150, 139), belly = rgb(227, 203, 159) }
		local fin, dark = rgb(177, 102, 77), rgb(28, 64, 61)
		b:fishBody(0.21, 0.115, colors, 0.025)
		b:edgeFin(0.09, -0.1, { 0.075, 0.075, 0.05, 0.03 }, fin)
		b:ellipsoid("AdiposeFin", CFrame.new(-0.25, b:top(-0.25) + 0.009, 0), Vector3.new(0.045, 0.026, 0.012), fin)
		b:edgeFin(-0.09, -0.23, { 0.055, 0.06, 0.035 }, fin, true)
		b:edgeFin(0.07, -0.01, { 0.045, 0.03 }, fin, true)
		b:forkTail(0.105, 0.035, fin)
		b:pectoral(0.23, -0.035, 0.1, 0.035, fin, 0.05)
		b:speckle(18, v2(-0.28, 0.29), v2(-0.03, 0.065), v2(0.017, 0.028), rgb(232, 141, 135))
		b:marks(0.28, -0.035, 0.065, 0.03, rgb(218, 161, 116))
		b:face(0.37, 0.025, 0.04, rgb(231, 183, 103), dark)
	end,
}

