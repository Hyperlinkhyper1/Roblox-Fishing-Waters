-- Regional seasonal species; fishBody exposes a smooth loft to FishMeshes' EditableMesh renderer.
return {
	Name = "Arctic Cisco",
	ScientificName = "Coregonus autumnalis",
	Rarity = "Uncommon",
	RarityDenominator = 11,
	MinKg = 0.12,
	AverageKg = 0.6,
	MaxKg = 2.8,
	BaseValue = 68,
	Fight = 0.035,
	Pools = { "FrostmereExpanse" },
	Seasons = { "Spring", "Winter" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "####", ".##." },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(66, 95, 112), side = rgb(169, 193, 201), belly = rgb(231, 236, 230) }
		local fin, dark = rgb(106, 142, 156), rgb(58, 88, 101)
		b:fishBody(0.17, 0.095, colors, 0.03)
		b:edgeFin(0.09, -0.1, { 0.1, 0.065, 0.035 }, fin)
		b:ellipsoid("AdiposeFin", CFrame.new(-0.25, b:top(-0.25) + 0.009, 0), Vector3.new(0.045, 0.032, 0.012), fin)
		b:edgeFin(-0.09, -0.23, { 0.055, 0.06, 0.035 }, fin, true)
		b:edgeFin(0.07, -0.01, { 0.045, 0.03 }, fin, true)
		b:forkTail(0.145, 0.07, fin)
		b:pectoral(0.23, -0.035, 0.1, 0.035, fin, 0.05)
		-- Slender silvery profile and long deeply forked caudal fin.
		b:stroke({ v2(0.27, 0.017), v2(0, 0.008), v2(-0.29, 0.006) }, 0.012, rgb(203, 220, 221))
		b:face(0.37, 0.025, 0.04, rgb(218, 205, 144), dark)
	end,
}

