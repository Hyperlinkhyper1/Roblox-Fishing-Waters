return {
	Name = "Striped Marlin",
	Rarity = "Epic",
	RarityDenominator = 42,
	MinKg = 12,
	AverageKg = 55,
	MaxKg = 220,
	LengthScale = 1.55,
	BaseValue = 425,
	Fight = 0.10,
	Pools = { "OpenSea" },
	Seasons = { "Spring", "Summer", "Autumn" },
	Requires = { "Day" },
	Shapes = {
		Normal = { "####", ".##." },
		Big = { "#####", ".###." },
		Huge = { "######", ".####." },
	},
	-- High pointed dorsal and bright lavender-blue bars on a slim body.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(28, 42, 96), side = rgb(120, 146, 188), belly = rgb(228, 232, 240) }
		local fin = rgb(38, 48, 112)
		b:fishBody(0.18, 0.10, colors, 0.02)
		b:edgeFin(0.26, -0.24, { 0.17, 0.24, 0.19, 0.115, 0.055, 0.03, 0.02 }, fin)
		b:edgeFin(-0.25, -0.3, { 0.03 }, fin)
		b:edgeFin(0.0, -0.16, { 0.08, 0.05, 0.025 }, fin, true)
		b:edgeFin(-0.25, -0.3, { 0.025 }, fin, true)
		b:lunateTail(0.22, fin)
		b:pectoral(0.23, -0.025, 0.19, 0.036, fin)
		for _, side in { 1, -1 } do
			b:limb(Vector3.new(0.17, b:bottom(0.17), side * 0.012), Vector3.new(-0.06, -0.16, side * 0.025), 0.006, fin, "PelvicFin")
		end
		for x = 0.25, -0.29, -0.042 do
			b:stroke({ v2(x, b:top(x) * 0.82), v2(x - 0.013, b:bottom(x) * 0.62) }, 0.012, rgb(104, 122, 238))
		end
		b:limb(Vector3.new(0.44, 0.006, 0), Vector3.new(0.84, 0.002, 0), 0.021, colors.back, "Bill")
		b:face(0.37, 0.023, 0.04, rgb(166, 184, 204), rgb(62, 72, 128))
	end,
}
