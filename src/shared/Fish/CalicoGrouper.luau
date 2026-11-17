return {
	Name = "Calico Grouper",
	Rarity = "Rare",
	RarityDenominator = 14,
	MinKg = 1.5,
	AverageKg = 7,
	MaxKg = 25,
	BaseValue = 170,
	Fight = 0.06,
	Pools = { "CoralShallows", "CinderIsles" },
	Seasons = { "Summer", "Autumn" },
	Requires = { "Clear" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", ".##." },
		Huge = { "#####", "#####" },
	},
	-- A warm ochre grouper patterned with large dark calico patches and pale seams.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(106, 74, 50), side = rgb(180, 144, 96), belly = rgb(226, 206, 166) }
		local fin = rgb(112, 82, 54)
		b:fishBody(0.33, 0.18, colors, 0.075)
		local dorsal = b:edgeFin(0.17, -0.22, { 0.055, 0.075, 0.07, 0.06, 0.055, 0.065, 0.08, 0.075, 0.055 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3], dorsal[4], dorsal[5] }, colors.back)
		b:edgeFin(-0.08, -0.24, { 0.065, 0.075, 0.055 }, fin, true)
		b:edgeFin(0.1, 0.015, { 0.06, 0.045 }, fin, true)
		b:roundTail(0.135, fin)
		b:pectoral(0.2, -0.04, 0.13, 0.05, fin)
		for _, spot in { { 0.23, 0.06, 0.1, 0.09 }, { 0.11, -0.04, 0.11, 0.08 }, { -0.02, 0.08, 0.12, 0.1 }, { -0.15, -0.02, 0.1, 0.1 }, { -0.26, 0.035, 0.065, 0.065 } } do
			b:marks(spot[1], spot[2], spot[3], spot[4], rgb(76, 50, 32))
		end
		b:speckle(24, v2(-0.28, 0.3), v2(-0.11, 0.12), v2(0.009, 0.017), rgb(238, 214, 168))
		b:face(0.37, 0.04, 0.043, rgb(206, 166, 78), colors.back)
	end,
}
