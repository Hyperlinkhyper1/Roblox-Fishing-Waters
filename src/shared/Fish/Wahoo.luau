-- Region and season rules are gameplay choices; the body joins the shared EditableMesh loft pipeline.
return {
	Name = "Wahoo",
	ScientificName = "Acanthocybium solandri",
	Rarity = "Epic",
	RarityDenominator = 62,
	MinKg = 3,
	AverageKg = 18,
	MaxKg = 85,
	LengthScale = 1.4,
	BaseValue = 425,
	Fight = 0.13,
	Pools = { "CinderIsles" },
	Seasons = { "Autumn", "Winter" },
	Shapes = {
		Normal = { "####", ".##." },
		Big = { "#####", ".###." },
		Huge = { "######", "######" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(26, 68, 104), side = rgb(128, 177, 192), belly = rgb(229, 239, 234) }
		local fin = rgb(35, 85, 112)
		local dark, pale = rgb(25, 29, 35), rgb(249, 246, 222)
		b:loftBody({ {0.49, 0.021, -0.029, 0.018}, {0.32, 0.068, -0.058, 0.045}, {0.08, 0.095, -0.075, 0.066}, {-0.15, 0.058, -0.046, 0.045}, {-0.35, 0.015, -0.015, 0.014} }, colors, 0.19, 0.13, 0.02)
		b:edgeFin(0.21, -0.13, { 0.09, 0.065, 0.04, 0.03, 0.025 }, fin)
		b:edgeFin(-0.15, -0.23, { 0.065, 0.04 }, fin)
		b:edgeFin(-0.14, -0.23, { 0.055, 0.035 }, fin, true)
		b:lunateTail(0.19, fin)
		b:pectoral(0.24, -0.025, 0.11, 0.03, fin)
		for index = 0, 8 do
		    local x = 0.25 - index * 0.064
		    b:marks(x, 0, 0.018, (b:top(x) - b:bottom(x)) * 0.9, rgb(41, 107, 149))
		end
		for index = 0, 3 do
		    local x = -0.24 - index * 0.027
		    for _, below in { false, true } do
		        b:edgeFin(x + 0.01, x - 0.012, { 0.022 }, fin, below)
		    end
		end
		b:eye(0.37, 0.025, 0.043, rgb(182, 191, 159))
	end,
}
