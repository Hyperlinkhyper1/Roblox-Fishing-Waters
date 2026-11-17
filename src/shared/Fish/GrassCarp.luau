-- Regional seasonal species; fishBody exposes a smooth loft to FishMeshes' EditableMesh renderer.
return {
	Name = "Grass Carp",
	ScientificName = "Ctenopharyngodon idella",
	Rarity = "Rare",
	RarityDenominator = 20,
	MinKg = 1.2,
	AverageKg = 8,
	MaxKg = 40,
	BaseValue = 96,
	Fight = 0.09,
	Pools = { "MainLake", "SoddenMire" },
	Seasons = { "Summer", "Autumn" },
	Shapes = {
		Normal = { "###" },
		Big = { "####" },
		Huge = { "#####", ".###." },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(77, 96, 52), side = rgb(153, 166, 110), belly = rgb(222, 221, 176) }
		local fin, dark = rgb(116, 135, 78), rgb(69, 92, 52)
		b:fishBody(0.24, 0.165, colors, 0.03)
		b:edgeFin(0.09, -0.1, { 0.09, 0.07, 0.035 }, fin)
		b:edgeFin(-0.09, -0.23, { 0.055, 0.06, 0.035 }, fin, true)
		b:edgeFin(0.07, -0.01, { 0.045, 0.03 }, fin, true)
		b:forkTail(0.15, 0.075, fin)
		b:pectoral(0.23, -0.035, 0.1, 0.05, fin, 0.05)
		-- Long torpedo body with large dark-edged scales, without mouth barbels.
		for _, y in { -0.025, 0.035 } do
			for x = 0.24, -0.25, -0.082 do b:marks(x, y, 0.052, 0.035, dark, v2(1, 0.4)) end
		end
		b:face(0.37, 0.025, 0.04, rgb(223, 189, 101), dark)
	end,
}

