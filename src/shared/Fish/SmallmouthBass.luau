return {
	Name = "Smallmouth Bass",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 0.3,
	AverageKg = 1.2,
	MaxKg = 6,
	BaseValue = 25,
	Fight = 0.06,
	Pools = { "MainLake" },
	Seasons = { "Spring", "Autumn" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "###", "###" },
	},
	-- Bronze black bass with diffuse vertical bars, dark cheek stripes, a joined
	-- spiny-soft dorsal, a big mouth and a red eye.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(86, 72, 38), side = rgb(156, 128, 70), belly = rgb(224, 208, 168) }
		local fin = rgb(130, 106, 62)
		b:fishBody(0.28, 0.14, colors, 0.08)
		local dorsal =
			b:edgeFin(0.14, -0.22, { 0.06, 0.075, 0.07, 0.055, 0.04, 0.05, 0.07, 0.075, 0.06 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3], dorsal[4], dorsal[5] }, rgb(80, 64, 36))
		b:edgeFin(-0.08, -0.22, { 0.06, 0.065, 0.045 }, fin, true, 0.05)
		b:edgeFin(0.08, 0.0, { 0.06, 0.04 }, fin, true)
		b:forkTail(0.13, 0.035, fin)
		b:pectoral(0.2, -0.04, 0.1, 0.04, fin, 0.1)
		for x = 0.16, -0.3, -0.055 do
			b:stroke({ v2(x + 0.006, b:top(x) * 0.85), v2(x - 0.006, b:bottom(x) * 0.45) }, 0.024, rgb(96, 76, 38))
		end
		for _, y in { 0.02, -0.01, -0.04 } do
			b:stroke({ v2(0.34, y + 0.012), v2(0.25, y) }, 0.01, rgb(70, 56, 30))
		end
		-- Jaw hinge reaches to below the eye.
		b:stroke({ v2(0.47, -0.03), v2(0.37, -0.05) }, 0.008, rgb(40, 32, 22))
		b:face(0.37, 0.035, 0.048, rgb(204, 64, 40), rgb(100, 82, 46))
	end,
}
