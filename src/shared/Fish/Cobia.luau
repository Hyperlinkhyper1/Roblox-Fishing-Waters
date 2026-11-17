-- Region and season rules are gameplay choices; the body joins the shared EditableMesh loft pipeline.
return {
	Name = "Cobia",
	ScientificName = "Rachycentron canadum",
	Rarity = "Rare",
	RarityDenominator = 28,
	MinKg = 1.5,
	AverageKg = 14,
	MaxKg = 65,
	LengthScale = 1.4,
	BaseValue = 285,
	Fight = 0.11,
	Pools = { "CinderIsles" },
	Seasons = { "Spring", "Summer" },
	Shapes = {
		Normal = { "####", ".##." },
		Big = { "#####", ".###." },
		Huge = { "######", "######" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(55, 53, 40), side = rgb(135, 136, 103), belly = rgb(228, 224, 190) }
		local fin = rgb(64, 70, 51)
		local dark, pale = rgb(25, 29, 35), rgb(249, 246, 222)
		b:loftBody({ {0.49, 0.031, -0.043, 0.034}, {0.30, 0.085, -0.075, 0.074}, {0.06, 0.11, -0.09, 0.086}, {-0.16, 0.067, -0.055, 0.054}, {-0.35, 0.019, -0.018, 0.018} }, colors, 0.22, 0.17, 0.02)
		b:edgeFin(0.01, -0.26, { 0.12, 0.12, 0.09, 0.06 }, fin)
		b:edgeFin(-0.06, -0.24, { 0.085, 0.095, 0.065 }, fin, true)
		for index = 0, 4 do
		    local x = 0.22 - index * 0.035
		    b:limb(Vector3.new(x, b:top(x), 0), Vector3.new(x - 0.015, b:top(x) + 0.035, 0), 0.008, fin, "FreeDorsalSpine")
		end
		b:lunateTail(0.17, fin)
		b:pectoral(0.25, -0.025, 0.18, 0.04, fin)
		b:marks(-0.015, -0.002, 0.64, 0.04, colors.back)
		b:marks(-0.02, -0.035, 0.62, 0.013, pale)
		b:eye(0.37, 0.03, 0.047, rgb(175, 170, 107))
	end,
}
