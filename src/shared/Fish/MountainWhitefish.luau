-- Regional seasonal species; fishBody exposes a smooth loft to FishMeshes' EditableMesh renderer.
return {
	Name = "Mountain Whitefish",
	ScientificName = "Prosopium williamsoni",
	Rarity = "Common",
	RarityDenominator = 6,
	MinKg = 0.12,
	AverageKg = 0.65,
	MaxKg = 3.5,
	BaseValue = 32,
	Fight = 0.025,
	Pools = { "MainLake", "FrostmereExpanse" },
	Seasons = { "Spring", "Autumn", "Winter" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "####", ".##." },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(90, 109, 111), side = rgb(188, 199, 190), belly = rgb(236, 233, 209) }
		local fin, dark = rgb(135, 149, 133), rgb(80, 99, 97)
		b:fishBody(0.22, 0.115, colors, 0.12)
		b:edgeFin(0.09, -0.1, { 0.105, 0.08, 0.045 }, fin)
		b:ellipsoid("AdiposeFin", CFrame.new(-0.25, b:top(-0.25) + 0.009, 0), Vector3.new(0.045, 0.032, 0.012), fin)
		b:edgeFin(-0.09, -0.23, { 0.055, 0.06, 0.035 }, fin, true)
		b:edgeFin(0.07, -0.01, { 0.045, 0.03 }, fin, true)
		b:forkTail(0.135, 0.06, fin)
		b:pectoral(0.23, -0.035, 0.1, 0.035, fin, 0.05)
		-- Small underslung mouth and a short, blunt snout.
		b:ellipsoid("SubterminalLip", CFrame.new(0.432, -0.048, 0), Vector3.new(0.052, 0.021, 0.045), rgb(209, 211, 190))
		for x = 0.18, -0.24, -0.07 do b:marks(x, 0.005, 0.034, 0.019, rgb(215, 221, 201)) end
		b:face(0.37, 0.025, 0.04, rgb(225, 198, 114), dark)
	end,
}

