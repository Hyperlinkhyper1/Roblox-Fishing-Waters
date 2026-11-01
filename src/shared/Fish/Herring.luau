return {
	Name = "Herring",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 0.1,
	AverageKg = 0.25,
	MaxKg = 0.9,
	BaseValue = 48,
	Fight = 0.04,
	Pools = { "OpenSea" },
	Seasons = { "Spring", "Winter" },
	Shapes = {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "###" },
	},
	-- Slim silver schooling fish with a blue-green back.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(46, 84, 110), side = rgb(186, 198, 206), belly = rgb(244, 246, 248) }
		local fin = rgb(160, 172, 180)
		b:fishBody(0.19, 0.1, colors, 0.03)
		b:edgeFin(0.05, -0.06, { 0.065, 0.055, 0.03 }, fin, false, 0.15)
		b:edgeFin(-0.12, -0.22, { 0.03, 0.025 }, fin, true, 0.15)
		b:edgeFin(0.0, -0.05, { 0.03 }, fin, true, 0.15)
		b:forkTail(0.13, 0.09, fin, 0.1)
		b:pectoral(0.21, -0.04, 0.07, 0.025, fin, 0.15)
		b:stroke({ v2(0.26, 0.03), v2(-0.3, 0.015) }, 0.01, rgb(140, 176, 196))
		for x = 0.2, -0.24, -0.04 do
			b:stroke({ v2(x, b:bottom(x) * 0.3), v2(x - 0.01, b:bottom(x) * 0.8) }, 0.004, rgb(220, 226, 232))
		end
		b:face(0.37, 0.018, 0.054, rgb(220, 224, 220), rgb(120, 140, 150))
	end,
}
