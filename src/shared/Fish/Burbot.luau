-- Regional seasonal species; fishBody exposes a smooth loft to FishMeshes' EditableMesh renderer.
return {
	Name = "Burbot",
	ScientificName = "Lota lota",
	Rarity = "Rare",
	RarityDenominator = 18,
	MinKg = 0.4,
	AverageKg = 2.4,
	MaxKg = 18,
	BaseValue = 108,
	Fight = 0.065,
	Pools = { "FrostmereExpanse", "SoddenMire" },
	Seasons = { "Autumn", "Winter" },
	Shapes = {
		Normal = { "###" },
		Big = { "####" },
		Huge = { "#####", ".###." },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(69, 74, 44), side = rgb(129, 130, 79), belly = rgb(213, 204, 157) }
		local fin, dark = rgb(104, 110, 63), rgb(49, 56, 33)
		b:fishBody(0.19, 0.16, colors, 0.04)
		b:edgeFin(0.17, 0.02, { 0.045, 0.06, 0.05 }, fin)
		b:edgeFin(0.07, -0.01, { 0.045, 0.03 }, fin, true)
		b:roundTail(0.12, fin)
		b:pectoral(0.23, -0.035, 0.1, 0.05, fin, 0.05)
		b:edgeFin(-0.02, -0.32, { 0.04, 0.055, 0.055, 0.045, 0.03 }, fin)
		b:edgeFin(0.02, -0.3, { 0.04, 0.05, 0.05, 0.04 }, fin, true)
		b:limb(Vector3.new(0.43, -0.06, 0), Vector3.new(0.39, -0.16, 0), 0.009, rgb(193, 181, 124), "ChinBarbel")
		b:speckle(15, v2(-0.28, 0.3), v2(-0.045, 0.065), v2(0.025, 0.052), dark)
		b:face(0.37, 0.025, 0.04, rgb(181, 168, 92), dark)
	end,
}

