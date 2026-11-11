return {
	Name = "Cutlass Fish",
	Rarity = "Rare",
	RarityDenominator = 12,
	MinKg = 0.3,
	AverageKg = 1.5,
	MaxKg = 6,
	LengthScale = 1.4,
	BaseValue = 165,
	Fight = 0.06,
	Pools = { "PirateCove" },
	Seasons = { "Summer", "Autumn", "Winter" },
	Requires = { "Night" },
	Shapes = {
		Normal = { "###" },
		Big = { "####" },
		Huge = { "#####" },
	},
	-- A blade-thin silver ribbonfish that rises to the cove's lanterns after dark: one long
	-- see-through dorsal, no tail fin, just a whip, and a mouth full of fangs.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(150, 164, 178), side = rgb(214, 222, 230), belly = rgb(244, 246, 248) }
		local fin = rgb(196, 210, 222)
		b:fishBody(0.1, 0.05, colors, 0)
		local heights = {}
		for index = 1, 12 do
			heights[index] = 0.025 + 0.006 * math.sin(index * 0.9)
		end
		b:edgeFin(0.3, -0.42, heights, fin, false, 0.35)
		b:limb(Vector3.new(-0.42, 0, 0), Vector3.new(-0.64, -0.01, 0), 0.008, colors.side, "Whip")
		b:pectoral(0.28, -0.01, 0.05, 0.02, fin, 0.3)
		b:stroke({ v2(0.34, 0.012), v2(-0.36, 0.006) }, 0.005, rgb(124, 140, 156))
		for _, x in { 0.47, 0.455, 0.44 } do
			b:marks(x, b:bottom(x) * 0.2, 0.006, 0.014, rgb(250, 250, 250))
		end
		b:face(0.4, 0.016, 0.034, rgb(232, 222, 150), rgb(150, 160, 172))
	end,
}
