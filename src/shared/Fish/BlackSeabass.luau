return {
	Name = "Black Seabass",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 0.3,
	AverageKg = 1.2,
	MaxKg = 4.5,
	BaseValue = 46,
	Fight = 0.04,
	Pools = { "MainLake", "CoralShallows" },
	Seasons = { "Spring", "Summer" },
	Requires = { "Day" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "####", "####" },
	},
	-- Charcoal sea bass with a tall spiny dorsal, turquoise flecks and blue fin margins.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(30, 40, 42), side = rgb(62, 78, 82), belly = rgb(170, 182, 176) }
		local fin = rgb(32, 52, 58)
		b:fishBody(0.29, 0.13, colors, 0.075)
		local dorsal = b:edgeFin(0.17, -0.22, { 0.055, 0.075, 0.07, 0.06, 0.055, 0.065, 0.08, 0.075, 0.055 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3], dorsal[4], dorsal[5] }, colors.back)
		b:edgeFin(-0.08, -0.24, { 0.065, 0.075, 0.055 }, fin, true)
		b:edgeFin(0.1, 0.015, { 0.06, 0.045 }, fin, true)
		b:roundTail(0.115, fin)
		b:pectoral(0.2, -0.04, 0.13, 0.05, fin)
		b:speckle(44, v2(-0.3, 0.28), v2(-0.09, 0.11), v2(0.006, 0.012), rgb(104, 172, 180))
		b:edgeFin(0.16, -0.18, { 0.09, 0.12, 0.1, 0.07, 0.09, 0.1 }, rgb(74, 128, 148), false, 0.15)
		b:stroke({ v2(0.24, -0.025), v2(0.02, -0.035), v2(-0.27, -0.02) }, 0.006, rgb(124, 150, 156))
		b:face(0.37, 0.04, 0.043, rgb(166, 180, 162), colors.back)
	end,
}
