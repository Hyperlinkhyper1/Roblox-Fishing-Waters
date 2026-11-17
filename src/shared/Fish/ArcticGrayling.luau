-- Regional seasonal species; fishBody exposes a smooth loft to FishMeshes' EditableMesh renderer.
return {
	Name = "Arctic Grayling",
	ScientificName = "Thymallus arcticus",
	Rarity = "Rare",
	RarityDenominator = 24,
	MinKg = 0.15,
	AverageKg = 0.8,
	MaxKg = 3.8,
	BaseValue = 128,
	Fight = 0.065,
	Pools = { "FrostmereExpanse" },
	Seasons = { "Spring", "Summer" },
	Shapes = {
		Normal = { "###" },
		Big = { "####" },
		Huge = { "#####", ".###." },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(70, 76, 106), side = rgb(151, 164, 179), belly = rgb(220, 224, 218) }
		local fin, dark = rgb(116, 87, 142), rgb(66, 67, 99)
		b:fishBody(0.195, 0.1, colors, 0.06)
		b:edgeFin(0.14, -0.2, { 0.16, 0.23, 0.25, 0.23, 0.2, 0.13 }, fin)
		b:ellipsoid("AdiposeFin", CFrame.new(-0.25, b:top(-0.25) + 0.009, 0), Vector3.new(0.045, 0.026, 0.012), fin)
		b:edgeFin(-0.09, -0.23, { 0.055, 0.06, 0.035 }, fin, true)
		b:edgeFin(0.07, -0.01, { 0.045, 0.03 }, fin, true)
		b:forkTail(0.12, 0.055, fin)
		b:pectoral(0.23, -0.035, 0.1, 0.035, fin, 0.05)
		-- Tall flag dorsal with jeweled spots and strongly forked tail.
		for _, point in { v2(0.06, 0.19), v2(-0.01, 0.26), v2(-0.08, 0.24), v2(-0.15, 0.18) } do
			b:finSpot(point.X, point.Y, 0.022, rgb(73, 128, 164))
		end
		for x = 0.24, -0.22, -0.07 do b:marks(x, 0.025, 0.013, 0.014, dark) end
		b:face(0.37, 0.025, 0.04, rgb(223, 182, 100), dark)
	end,
}

