return {
	Name = "Tiger Grouper",
	Rarity = "Epic",
	RarityDenominator = 32,
	MinKg = 2,
	AverageKg = 9,
	MaxKg = 35,
	BaseValue = 340,
	Fight = 0.08,
	Pools = { "CoralShallows", "CinderIsles" },
	Seasons = { "Summer", "Autumn" },
	Requires = { "Night" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", ".##." },
		Huge = { "#####", "#####" },
	},
	-- Amber grouper with bold diagonal tiger bars rather than rows of round spots.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(116, 72, 48), side = rgb(210, 148, 82), belly = rgb(240, 210, 158) }
		local fin = rgb(142, 84, 48)
		b:fishBody(0.33, 0.17, colors, 0.075)
		local dorsal = b:edgeFin(0.17, -0.22, { 0.055, 0.075, 0.07, 0.06, 0.055, 0.065, 0.08, 0.075, 0.055 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3], dorsal[4], dorsal[5] }, colors.back)
		b:edgeFin(-0.08, -0.24, { 0.065, 0.075, 0.055 }, fin, true)
		b:edgeFin(0.1, 0.015, { 0.06, 0.045 }, fin, true)
		b:roundTail(0.135, fin)
		b:pectoral(0.2, -0.04, 0.13, 0.05, fin)
		for _, x in { 0.21, 0.09, -0.03, -0.15, -0.26 } do
			b:stroke({ v2(x + 0.045, b:top(x) * 0.83), v2(x - 0.045, b:bottom(x) * 0.62) }, 0.034, rgb(82, 46, 30))
		end
		b:speckle(14, v2(0.28, 0.42), v2(-0.06, 0.08), v2(0.006, 0.012), rgb(168, 78, 42))
		b:face(0.37, 0.04, 0.043, rgb(212, 148, 54), colors.back)
	end,
}
