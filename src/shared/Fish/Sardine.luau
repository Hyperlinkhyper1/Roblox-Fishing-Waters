return {
	Name = "Sardine",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 0.04,
	AverageKg = 0.12,
	MaxKg = 0.5,
	BaseValue = 18,
	Fight = 0.04,
	Pools = { "OpenSea" },
	Seasons = { "Summer" },
	Shapes = {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "###" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(40, 96, 112), side = rgb(176, 192, 196), belly = rgb(240, 242, 242) }
		local fin = rgb(150, 164, 166)
		b:fishBody(0.18, 0.1, colors, 0.04)
		b:edgeFin(0.06, -0.05, { 0.06, 0.05, 0.03 }, fin, false, 0.15)
		b:edgeFin(-0.14, -0.22, { 0.03, 0.02 }, fin, true, 0.15)
		b:edgeFin(0, -0.05, { 0.03 }, fin, true, 0.15)
		b:forkTail(0.12, 0.08, fin, 0.1)
		b:pectoral(0.21, -0.04, 0.07, 0.025, fin, 0.15)
		b:stroke({ v2(0.26, 0.02), v2(-0.3, 0.01) }, 0.008, rgb(120, 150, 160))
		for x = 0.18, -0.2, -0.065 do
			b:marks(x, 0.035, 0.016, 0.016, rgb(26, 40, 48))
		end
		b:face(0.37, 0.015, 0.05, rgb(210, 214, 210), rgb(110, 130, 136))
	end,
}
