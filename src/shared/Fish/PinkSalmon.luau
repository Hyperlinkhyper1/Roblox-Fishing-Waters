return {
	Name = "Pink Salmon",
	Rarity = "Uncommon",
	RarityDenominator = 8,
	MinKg = 0.5,
	AverageKg = 1.8,
	MaxKg = 6.5,
	BaseValue = 52,
	Fight = 0.05,
	Pools = { "MainLake", "FrostmereExpanse" },
	Seasons = { "Summer", "Autumn" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", ".##." },
		Huge = { "#####", "#####" },
	},
	-- Spawning pink salmon with a high shoulder hump and bold oval tail spots.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(106, 110, 80), side = rgb(186, 168, 142), belly = rgb(230, 214, 190) }
		local fin, spot = rgb(112, 118, 88), rgb(36, 46, 44)
		b:fishBody(0.24, 0.13, colors, 0.05)
		b:layered("Hump", Vector3.new(0.03, 0.055, 0), Vector3.new(0.40, 0.27, 0.12), colors)
		b:layered("Kype", Vector3.new(0.445, -0.035, 0), Vector3.new(0.15, 0.085, 0.08), colors)
		b:edgeFin(0.08, -0.08, { 0.085, 0.08, 0.055, 0.035 }, fin)
		b:ellipsoid("AdiposeFin", CFrame.new(-0.25, b:top(-0.25) + 0.008, 0), Vector3.new(0.055, 0.035, 0.014), fin)
		b:edgeFin(-0.12, -0.25, { 0.06, 0.055, 0.035 }, fin, true)
		b:edgeFin(0.02, -0.06, { 0.05, 0.04 }, fin, true)
		b:forkTail(0.12, 0.04, fin)
		b:pectoral(0.22, -0.045, 0.11, 0.04, fin)
		b:speckle(24, v2(-0.30, 0.30), v2(0, 0.11), v2(0.015, 0.027), spot)
		for _, y in { -0.085, -0.05, 0.045, 0.08 } do
			b:finSpot(-0.46, y, 0.018, spot)
			b:finSpot(-0.425, y * 0.55, 0.014, spot)
		end
		b:stroke({ v2(0.28, -0.012), v2(0, -0.016), v2(-0.28, -0.008) }, 0.005, fin)
		b:face(0.38, 0.025, 0.04, rgb(212, 192, 118), fin)
	end,
}

