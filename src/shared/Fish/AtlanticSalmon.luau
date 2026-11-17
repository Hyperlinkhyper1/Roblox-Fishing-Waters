return {
	Name = "Atlantic Salmon",
	Rarity = "Rare",
	RarityDenominator = 14,
	MinKg = 1,
	AverageKg = 4.5,
	MaxKg = 25,
	BaseValue = 144,
	Fight = 0.07,
	Pools = { "MainLake", "FrostmereExpanse" },
	Seasons = { "Spring", "Autumn", "Winter" },
	Requires = { "Rain" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", ".##." },
		Huge = { "#####", "#####" },
	},
	-- Silver flanks, dark cross-shaped spots and a narrow tail wrist.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(50, 76, 86), side = rgb(176, 192, 196), belly = rgb(236, 240, 234) }
		local fin, spot = rgb(92, 112, 116), rgb(36, 46, 44)
		b:fishBody(0.22, 0.12, colors, 0.05)
		b:edgeFin(0.08, -0.08, { 0.085, 0.08, 0.055, 0.035 }, fin)
		b:ellipsoid("AdiposeFin", CFrame.new(-0.25, b:top(-0.25) + 0.008, 0), Vector3.new(0.055, 0.035, 0.014), fin)
		b:edgeFin(-0.12, -0.25, { 0.06, 0.055, 0.035 }, fin, true)
		b:edgeFin(0.02, -0.06, { 0.05, 0.04 }, fin, true)
		b:forkTail(0.12, 0.04, fin)
		b:pectoral(0.22, -0.045, 0.11, 0.04, fin)
		for _ = 1, 18 do
			local x, y = b.random(-0.28, 0.3), b.random(0.005, 0.075)
			b:stroke({ v2(x - 0.007, y - 0.007), v2(x + 0.007, y + 0.007) }, 0.005, spot)
			b:stroke({ v2(x - 0.007, y + 0.007), v2(x + 0.007, y - 0.007) }, 0.005, spot)
		end
		b:stroke({ v2(0.28, -0.012), v2(0, -0.016), v2(-0.28, -0.008) }, 0.005, fin)
		b:face(0.38, 0.025, 0.04, rgb(208, 194, 132), fin)
	end,
}

