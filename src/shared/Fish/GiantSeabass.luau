return {
	Name = "Giant Seabass",
	Rarity = "Legendary",
	RarityDenominator = 90,
	MinKg = 12,
	AverageKg = 70,
	MaxKg = 250,
	LengthScale = 1.3,
	BaseValue = 890,
	Fight = 0.12,
	Pools = { "CinderIsles", "PirateCove" },
	Seasons = { "Spring", "Summer" },
	Requires = { "Rain", "Storm", "Night" },
	Shapes = {
		Normal = { "###", "###" },
		Big = { "####", "####" },
		Huge = { "#####", "#####" },
	},
	-- Massive, high-shouldered dark sea bass with a blunt jaw and scattered slate blotches.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(38, 44, 46), side = rgb(86, 98, 98), belly = rgb(172, 180, 174) }
		local fin = rgb(48, 58, 58)
		b:fishBody(0.43, 0.25, colors, 0.075)
		b:layered("Shoulder", Vector3.new(0.12, 0.035, 0), Vector3.new(0.51, 0.43, 0.255), colors)
		b:layered("Jaw", Vector3.new(0.38, -0.09, 0), Vector3.new(0.25, 0.15, 0.21), colors)
		local dorsal = b:edgeFin(0.17, -0.22, { 0.055, 0.075, 0.07, 0.06, 0.055, 0.065, 0.08, 0.075, 0.055 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3], dorsal[4], dorsal[5] }, colors.back)
		b:edgeFin(-0.08, -0.24, { 0.065, 0.075, 0.055 }, fin, true)
		b:edgeFin(0.1, 0.015, { 0.06, 0.045 }, fin, true)
		b:roundTail(0.135, fin)
		b:pectoral(0.2, -0.04, 0.13, 0.05, fin)
		b:speckle(24, v2(-0.28, 0.29), v2(-0.13, 0.16), v2(0.025, 0.046), rgb(46, 58, 60))
		b:stroke({ v2(0.48, -0.055), v2(0.34, -0.12) }, 0.018, rgb(30, 36, 36))
		b:face(0.37, 0.04, 0.055, rgb(152, 164, 144), colors.back)
	end,
}
