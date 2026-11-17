return {
	Name = "Longbill Spearfish",
	Rarity = "Rare",
	RarityDenominator = 20,
	MinKg = 3,
	AverageKg = 12,
	MaxKg = 55,
	LengthScale = 1.5,
	BaseValue = 185,
	Fight = 0.08,
	Pools = { "CoralShallows" },
	Seasons = { "Spring", "Summer" },
	Requires = { "Clear", "Day" },
	Shapes = {
		Normal = { "####" },
		Big = { "#####", ".###." },
		Huge = { "######", ".####." },
	},
	-- A narrow body, long needle bill and a low continuous dorsal.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(30, 52, 100), side = rgb(128, 164, 188), belly = rgb(226, 234, 238) }
		local fin = rgb(36, 62, 114)
		b:fishBody(0.14, 0.085, colors, 0.015)
		b:edgeFin(0.26, -0.23, { 0.10, 0.12, 0.11, 0.09, 0.07, 0.05, 0.025 }, fin)
		b:edgeFin(-0.25, -0.3, { 0.025 }, fin)
		b:edgeFin(0.0, -0.16, { 0.065, 0.045, 0.025 }, fin, true)
		b:edgeFin(-0.25, -0.3, { 0.025 }, fin, true)
		b:lunateTail(0.18, fin)
		b:pectoral(0.22, -0.02, 0.16, 0.026, fin)
		for _, side in { 1, -1 } do
			b:limb(Vector3.new(0.17, b:bottom(0.17), side * 0.009), Vector3.new(-0.08, -0.14, side * 0.018), 0.005, fin, "PelvicFin")
		end
		b:stroke({ v2(0.28, 0.012), v2(0.0, 0.008), v2(-0.3, 0.001) }, 0.006, rgb(74, 126, 178))
		b:limb(Vector3.new(0.44, 0.004, 0), Vector3.new(0.90, 0, 0), 0.015, colors.back, "Spear")
		b:face(0.375, 0.016, 0.035, rgb(190, 198, 196), rgb(70, 92, 120))
	end,
}
