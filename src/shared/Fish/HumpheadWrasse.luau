-- Region and season rules are gameplay choices; the body joins the shared EditableMesh loft pipeline.
return {
	Name = "Humphead Wrasse",
	ScientificName = "Cheilinus undulatus",
	Rarity = "Legendary",
	RarityDenominator = 140,
	MinKg = 3,
	AverageKg = 35,
	MaxKg = 180,
	BaseValue = 870,
	Fight = 0.13,
	Pools = { "CoralShallows", "CinderIsles" },
	Seasons = { "Summer", "Autumn" },
	Shapes = {
		Normal = { "####", ".##." },
		Big = { "#####", ".###." },
		Huge = { "######", "######" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(32, 99, 100), side = rgb(73, 164, 143), belly = rgb(162, 210, 171) }
		local fin = rgb(36, 119, 121)
		local dark, pale = rgb(25, 29, 35), rgb(249, 246, 222)
		b:fishBody(0.42, 0.23, colors, 0.09)
		b:layered("ForeheadHump", Vector3.new(0.25, 0.12, 0), Vector3.new(0.28, 0.26, 0.20), colors)
		b:layered("HeavyLips", Vector3.new(0.46, -0.07, 0), Vector3.new(0.13, 0.085, 0.13), colors)
		b:edgeFin(0.19, -0.26, { 0.045, 0.055, 0.065, 0.07, 0.05 }, fin)
		b:edgeFin(-0.04, -0.24, { 0.065, 0.075, 0.05 }, fin, true)
		b:roundTail(0.16, fin)
		b:pectoral(0.20, -0.05, 0.17, 0.075, rgb(69, 131, 123))
		for row = -1, 1 do
		    for column = 0, 3 do
		        b:marks(0.10 - column * 0.105, row * 0.065, 0.065, 0.013, rgb(30, 109, 115), v2(1, 0.5))
		    end
		end
		b:marks(0.33, -0.06, 0.13, 0.012, rgb(213, 185, 124), v2(1, -0.7))
		b:eye(0.36, 0.08, 0.051, rgb(212, 171, 103))
	end,
}
