return {
	Name = "Tilapia",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 0.2,
	AverageKg = 0.8,
	MaxKg = 4,
	BaseValue = 10,
	Fight = 0.02,
	Pools = { "MainLake" },
	Seasons = { "Summer", "Autumn" },
	Requires = { "Rain" },
	Shapes = {
		Normal = { "##" },
		Big = { "##", "##" },
		Huge = { "###", "###" },
	},
	-- Deep-bodied cichlid with faint bars and a red-edged tail.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(70, 84, 76), side = rgb(140, 152, 140), belly = rgb(222, 222, 210) }
		local fin = rgb(104, 112, 104)
		b:fishBody(0.36, 0.13, colors, 0.08)
		local dorsal = b:edgeFin(0.14, -0.24, { 0.05, 0.06, 0.06, 0.06, 0.06, 0.07, 0.09, 0.1, 0.08 }, fin, false, 0.08)
		b:rays(dorsal[1], { dorsal[3], dorsal[5], dorsal[7], dorsal[9] }, rgb(60, 66, 60))
		b:edgeFin(-0.06, -0.24, { 0.06, 0.08, 0.07 }, fin, true, 0.08)
		b:edgeFin(0.08, -0.02, { 0.06, 0.05 }, fin, true)
		b:roundTail(0.13, fin, 0.05)
		b:stroke({ v2(-0.47, 0.12), v2(-0.5, 0), v2(-0.47, -0.12) }, 0.012, rgb(196, 70, 60))
		b:pectoral(0.2, -0.04, 0.12, 0.04, fin, 0.15)
		for _, x in { 0.14, 0.05, -0.04, -0.13, -0.22 } do
			b:stroke({ v2(x + 0.01, b:top(x) - 0.02), v2(x - 0.01, -0.07) }, 0.026, rgb(104, 116, 106))
		end
		for _ = 1, 12 do
			b:finSpot(b.random(-0.2, 0.1), b:top(-0.05) + b.random(0.01, 0.06), 0.01, rgb(220, 220, 214))
		end
		b:face(0.38, 0.05, 0.048, rgb(196, 132, 70), rgb(84, 96, 88))
	end,
}
