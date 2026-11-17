-- Region and season rules are gameplay choices; the body joins the shared EditableMesh loft pipeline.
return {
	Name = "Emperor Angelfish",
	ScientificName = "Pomacanthus imperator",
	Rarity = "Epic",
	RarityDenominator = 55,
	MinKg = 0.2,
	AverageKg = 1.2,
	MaxKg = 4.5,
	BaseValue = 195,
	Fight = 0.07,
	Pools = { "CoralShallows", "CinderIsles" },
	Seasons = { "Summer", "Autumn" },
	Shapes = {
		Normal = { "##" },
		Big = { "###", ".#." },
		Huge = { "####", "####" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(20, 49, 111), side = rgb(37, 101, 175), belly = rgb(96, 159, 210) }
		local fin = rgb(236, 203, 56)
		local dark, pale = rgb(25, 29, 35), rgb(249, 246, 222)
		b:fishBody(0.45, 0.13, colors, 0.10)
		b:edgeFin(0.19, -0.27, { 0.06, 0.09, 0.12, 0.12, 0.07 }, colors.back)
		b:edgeFin(0.02, -0.25, { 0.08, 0.12, 0.07 }, fin, true)
		b:roundTail(0.13, fin)
		b:pectoral(0.21, -0.04, 0.13, 0.04, rgb(32, 92, 155))
		-- Long yellow flank stripes and a navy eye mask distinguish the adult emperor.
		for index = -2, 2 do
		    b:marks(-0.015, index * 0.045, 0.55 - math.abs(index) * 0.06, 0.014, fin)
		end
		b:marks(0.32, 0.04, 0.12, 0.15, dark, v2(-0.25, 1))
		b:marks(0.24, 0.0, 0.035, 0.22, rgb(130, 200, 226))
		b:face(0.37, 0.05, 0.047, rgb(240, 203, 91), dark)
	end,
}
