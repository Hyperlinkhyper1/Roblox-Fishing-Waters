return {
	Name = "Chinook Salmon",
	Rarity = "Epic",
	RarityDenominator = 30,
	MinKg = 3,
	AverageKg = 12,
	MaxKg = 60,
	LengthScale = 1.15,
	BaseValue = 378,
	Fight = 0.1,
	Pools = { "FrostmereExpanse" },
	Seasons = { "Spring", "Summer", "Autumn" },
	Requires = { "Day" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", ".##." },
		Huge = { "#####", "#####" },
	},
	-- Heavy king-salmon shoulders, a dark mouth and spots on both tail lobes.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(38, 66, 72), side = rgb(144, 168, 168), belly = rgb(228, 234, 222) }
		local fin, spot = rgb(64, 86, 88), rgb(36, 46, 44)
		b:fishBody(0.28, 0.16, colors, 0.05)
		b:layered("Shoulder", Vector3.new(0.16, 0.02, 0), Vector3.new(0.46, 0.29, 0.17), colors)
		b:edgeFin(0.08, -0.08, { 0.085, 0.08, 0.055, 0.035 }, fin)
		b:ellipsoid("AdiposeFin", CFrame.new(-0.25, b:top(-0.25) + 0.008, 0), Vector3.new(0.055, 0.035, 0.014), fin)
		b:edgeFin(-0.12, -0.25, { 0.06, 0.055, 0.035 }, fin, true)
		b:edgeFin(0.02, -0.06, { 0.05, 0.04 }, fin, true)
		b:forkTail(0.14, 0.04, fin)
		b:pectoral(0.22, -0.045, 0.11, 0.04, fin)
		b:speckle(30, v2(-0.30, 0.30), v2(0, 0.11), v2(0.009, 0.017), spot)
		for _, y in { -0.085, -0.05, 0.045, 0.08 } do
			b:finSpot(-0.46, y, 0.011, spot)
			b:finSpot(-0.425, y * 0.55, 0.008, spot)
		end
		b:marks(0.448, -0.027, 0.05, 0.025, rgb(28, 34, 30))
		b:stroke({ v2(0.28, -0.012), v2(0, -0.016), v2(-0.28, -0.008) }, 0.005, fin)
		b:face(0.38, 0.025, 0.047, rgb(204, 180, 114), fin)
	end,
}

