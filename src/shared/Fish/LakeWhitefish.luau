-- Regional seasonal species; fishBody exposes a smooth loft to FishMeshes' EditableMesh renderer.
return {
	Name = "Lake Whitefish",
	ScientificName = "Coregonus clupeaformis",
	Rarity = "Uncommon",
	RarityDenominator = 12,
	MinKg = 0.3,
	AverageKg = 1.6,
	MaxKg = 9,
	BaseValue = 82,
	Fight = 0.04,
	Pools = { "FrostmereExpanse", "MainLake" },
	Seasons = { "Autumn", "Winter" },
	Shapes = {
		Normal = { "###" },
		Big = { "####" },
		Huge = { "#####", ".###." },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(92, 106, 110), side = rgb(180, 189, 178), belly = rgb(235, 230, 204) }
		local fin, dark = rgb(130, 142, 128), rgb(76, 91, 89)
		b:fishBody(0.265, 0.15, colors, 0.13)
		b:edgeFin(0.09, -0.1, { 0.11, 0.09, 0.055, 0.025 }, fin)
		b:ellipsoid("AdiposeFin", CFrame.new(-0.25, b:top(-0.25) + 0.009, 0), Vector3.new(0.045, 0.032, 0.012), fin)
		b:edgeFin(-0.09, -0.23, { 0.055, 0.06, 0.035 }, fin, true)
		b:edgeFin(0.07, -0.01, { 0.045, 0.03 }, fin, true)
		b:forkTail(0.14, 0.06, fin)
		b:pectoral(0.23, -0.035, 0.1, 0.035, fin, 0.05)
		b:ellipsoid("DownturnedMouth", CFrame.new(0.427, -0.066, 0), Vector3.new(0.052, 0.028, 0.053), rgb(203, 202, 172))
		b:marks(0.12, 0.05, 0.18, 0.04, rgb(207, 213, 195))
		b:face(0.37, 0.025, 0.04, rgb(224, 198, 111), dark)
	end,
}

