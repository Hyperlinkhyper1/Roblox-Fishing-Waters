return {
	Name = "Broomtail Grouper",
	Rarity = "Epic",
	RarityDenominator = 36,
	MinKg = 4,
	AverageKg = 20,
	MaxKg = 100,
	LengthScale = 1.15,
	BaseValue = 390,
	Fight = 0.08,
	Pools = { "CoralShallows" },
	Seasons = { "Autumn", "Winter" },
	Requires = { "Night" },
	Shapes = {
		Normal = { "###", "###" },
		Big = { "####", "####" },
		Huge = { "#####", "#####" },
	},
	-- Heavy mottled grouper with the ragged, broom-like caudal fin that gives it its name.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(74, 68, 52), side = rgb(138, 122, 86), belly = rgb(210, 196, 156) }
		local fin = rgb(90, 78, 54)
		b:fishBody(0.36, 0.2, colors, 0.075)
		local dorsal = b:edgeFin(0.17, -0.22, { 0.055, 0.075, 0.07, 0.06, 0.055, 0.065, 0.08, 0.075, 0.055 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3], dorsal[4], dorsal[5] }, colors.back)
		b:edgeFin(-0.08, -0.24, { 0.065, 0.075, 0.055 }, fin, true)
		b:edgeFin(0.1, 0.015, { 0.06, 0.045 }, fin, true)
		local tail = { v2(-0.345, 0.025) }
		for index = 0, 12 do
			local y = 0.155 - index * 0.31 / 12
			table.insert(tail, v2(if index % 2 == 0 then -0.54 else -0.505, y))
		end
		table.insert(tail, v2(-0.345, -0.025))
		b:fin(tail, fin)
		for y = -0.12, 0.12, 0.04 do
			b:rays(v2(-0.35, 0), { v2(-0.53, y) }, rgb(62, 56, 40))
		end
		b:pectoral(0.2, -0.04, 0.13, 0.05, fin)
		for _, spot in { { 0.22, 0.06 }, { 0.1, -0.055 }, { -0.02, 0.05 }, { -0.14, -0.04 }, { -0.25, 0.02 } } do
			b:marks(spot[1], spot[2], 0.115, 0.085, rgb(76, 62, 40))
		end
		b:speckle(22, v2(-0.3, 0.3), v2(-0.12, 0.13), v2(0.008, 0.014), rgb(190, 170, 126))
		b:face(0.37, 0.04, 0.043, rgb(186, 166, 86), colors.back)
	end,
}
