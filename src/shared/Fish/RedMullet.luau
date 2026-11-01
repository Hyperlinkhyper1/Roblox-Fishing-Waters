return {
	Name = "Red Mullet",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 0.1,
	AverageKg = 0.4,
	MaxKg = 2,
	BaseValue = 50,
	Fight = 0.03,
	Pools = { "OpenSea" },
	Seasons = { "Summer", "Autumn" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "###", "###" },
	},
	-- Rosy goatfish with a steep head, a yellow stripe and two long chin barbels.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(176, 70, 66), side = rgb(222, 120, 110), belly = rgb(246, 214, 200) }
		local fin = rgb(220, 150, 130)
		b:fishBody(0.22, 0.12, colors, 0.12)
		b:edgeFin(0.13, 0.01, { 0.07, 0.065, 0.045 }, fin, false, 0.1)
		b:edgeFin(-0.08, -0.18, { 0.05, 0.04 }, fin, false, 0.1)
		b:edgeFin(-0.08, -0.18, { 0.045, 0.035 }, fin, true, 0.1)
		b:forkTail(0.12, 0.07, fin, 0.05)
		b:pectoral(0.21, -0.04, 0.09, 0.03, fin, 0.1)
		b:stroke({ v2(0.3, 0.0), v2(0, -0.004), v2(-0.3, -0.004) }, 0.02, rgb(236, 196, 80))
		local chin = b:bottom(0.42)
		for _, side in { 1, -1 } do
			b:limb(
				Vector3.new(0.43, chin + 0.006, side * 0.012),
				Vector3.new(0.27, chin - 0.05, side * 0.022),
				0.008,
				rgb(246, 220, 190),
				"Barbel"
			)
		end
		b:face(0.36, 0.04, 0.05, rgb(220, 150, 90), rgb(176, 90, 80))
	end,
}
