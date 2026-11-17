return {
	Name = "Atlantic Sailfish",
	Rarity = "Epic",
	RarityDenominator = 35,
	MinKg = 8,
	AverageKg = 28,
	MaxKg = 100,
	LengthScale = 1.55,
	BaseValue = 340,
	Fight = 0.08,
	Pools = { "OpenSea" },
	Seasons = { "Summer", "Autumn" },
	Requires = { "Clear", "Day" },
	Shapes = {
		Normal = { ".##.", "####" },
		Big = { ".###.", "#####" },
		Huge = { ".####.", "######" },
	},
	-- A cobalt sail rises far above the slender striped silver body.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(22, 40, 82), side = rgb(106, 152, 190), belly = rgb(230, 238, 240) }
		local fin, sail = rgb(22, 50, 104), rgb(26, 82, 164)
		b:fishBody(0.155, 0.09, colors, 0.02)
		local dorsal = b:edgeFin(0.26, -0.24, { 0.21, 0.32, 0.35, 0.34, 0.31, 0.27, 0.22, 0.14 }, sail, false, 0.08)
		for index = 3, #dorsal - 1 do
			local tip = dorsal[index]
			local root = v2(tip.X, b:top(tip.X))
			b:rays(root, { tip }, rgb(18, 40, 92))
			b:finSpot(tip.X + 0.015, root.Y + (tip.Y - root.Y) * 0.55, 0.018, rgb(14, 28, 66))
		end
		b:edgeFin(-0.25, -0.3, { 0.025 }, fin)
		b:edgeFin(0.02, -0.18, { 0.075, 0.05, 0.025 }, fin, true)
		b:edgeFin(-0.25, -0.3, { 0.025 }, fin, true)
		b:lunateTail(0.21, fin)
		b:pectoral(0.23, -0.03, 0.16, 0.035, fin)
		for _, side in { 1, -1 } do
			local root = Vector3.new(0.17, b:bottom(0.17), side * 0.012)
			b:limb(root, Vector3.new(-0.12, -0.17, side * 0.024), 0.006, fin, "PelvicFilament")
		end
		for x = 0.23, -0.28, -0.045 do
			b:stroke({ v2(x, b:top(x) * 0.75), v2(x - 0.012, b:bottom(x) * 0.3) }, 0.007, rgb(62, 132, 210))
		end
		b:limb(Vector3.new(0.44, 0.006, 0), Vector3.new(0.84, 0.001, 0), 0.018, colors.back, "Bill")
		b:face(0.37, 0.02, 0.042, rgb(164, 184, 202), rgb(52, 78, 112))
	end,
}
