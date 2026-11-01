return {
	Name = "Sailfish",
	Rarity = "Epic",
	RarityDenominator = 30,
	MinKg = 12,
	AverageKg = 40,
	MaxKg = 150,
	BaseValue = 372,
	Fight = 0.07,
	Pools = { "OpenSea" },
	Seasons = { "Summer" },
	Shapes = {
		Normal = { ".##.", "####" },
		Big = { ".###.", "#####" },
		Huge = { ".####.", "######" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(28, 50, 96), side = rgb(110, 140, 176), belly = rgb(226, 230, 234) }
		local fin, sail = rgb(34, 56, 104), rgb(40, 72, 150)
		b:fishBody(0.16, 0.1, colors, 0.02)
		local base = b:edgeFin(0.24, -0.16, { 0.2, 0.3, 0.33, 0.32, 0.28, 0.24, 0.18, 0.1 }, sail, false, 0.12)
		for index = 3, #base - 1 do
			local tip = base[index]
			local root = v2(tip.X, b:top(tip.X))
			b:rays(root, { tip }, rgb(24, 40, 90))
			b:finSpot(tip.X + 0.02, root.Y + (tip.Y - root.Y) * b.random(0.3, 0.7), 0.024, rgb(18, 26, 56))
		end
		b:edgeFin(-0.18, -0.25, { 0.04, 0.03 }, fin)
		b:edgeFin(-0.06, -0.2, { 0.08, 0.05, 0.03 }, fin, true)
		for _, side in { 1, -1 } do
			local belly = b:bottom(0.18)
			b:limb(
				Vector3.new(0.18, belly + 0.005, side * 0.01),
				Vector3.new(-0.06, belly - 0.12, side * 0.02),
				0.007,
				fin,
				"Filament"
			)
		end
		b:lunateTail(0.2, fin)
		b:pectoral(0.22, -0.03, 0.12, 0.04, fin)
		for x = 0.16, -0.26, -0.05 do
			b:stroke({ v2(x, b:top(x) * 0.8), v2(x - 0.01, 0) }, 0.008, rgb(150, 190, 226))
		end
		b:limb(Vector3.new(0.44, 0.005, 0), Vector3.new(0.82, 0, 0), 0.022, colors.back, "Bill")
		b:face(0.36, 0.02, 0.045, rgb(170, 180, 190), rgb(60, 80, 120))
	end,
}
