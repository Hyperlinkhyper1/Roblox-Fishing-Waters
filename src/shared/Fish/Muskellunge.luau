-- Regional seasonal species; fishBody exposes a smooth loft to FishMeshes' EditableMesh renderer.
return {
	Name = "Muskellunge",
	ScientificName = "Esox masquinongy",
	Rarity = "Epic",
	RarityDenominator = 55,
	MinKg = 2,
	AverageKg = 12,
	MaxKg = 38,
	LengthScale = 1.5,
	BaseValue = 245,
	Fight = 0.13,
	Pools = { "MainLake" },
	Seasons = { "Autumn", "Winter" },
	Shapes = {
		Normal = { "#####", ".###." },
		Big = { "######", ".####." },
		Huge = { "#######", "#######" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(78, 89, 66), side = rgb(161, 166, 119), belly = rgb(225, 222, 180) }
		local fin, dark = rgb(132, 119, 76), rgb(71, 84, 54)
		b:fishBody(0.17, 0.14, colors, 0.02)
		b:layered("Duckbill", Vector3.new(0.46, -0.006, 0), Vector3.new(0.22, 0.055, 0.11200000000000002), colors)
		b:edgeFin(-0.12, -0.28, { 0.08, 0.105, 0.075, 0.045 }, fin)
		b:edgeFin(-0.14, -0.29, { 0.055, 0.06, 0.035 }, fin, true)
		b:edgeFin(0.07, -0.01, { 0.045, 0.03 }, fin, true)
		b:forkTail(0.155, 0.07, fin)
		b:pectoral(0.23, -0.035, 0.075, 0.035, fin, 0.05)
		for x = 0.20, -0.27, -0.075 do b:marks(x, 0.005, 0.026, 0.085 * (1 - math.abs(x)), dark, v2(-0.12, 1)) end
		b:stroke({ v2(0.55, -0.008), v2(0.40, -0.03) }, 0.01, dark)
		b:face(0.35, 0.025, 0.04, rgb(221, 173, 67), dark)
	end,
}

