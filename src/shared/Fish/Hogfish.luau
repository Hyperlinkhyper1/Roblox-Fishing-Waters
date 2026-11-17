-- Region and season rules are gameplay choices; the body joins the shared EditableMesh loft pipeline.
return {
	Name = "Hogfish",
	ScientificName = "Lachnolaimus maximus",
	Rarity = "Rare",
	RarityDenominator = 19,
	MinKg = 0.25,
	AverageKg = 2.4,
	MaxKg = 12,
	BaseValue = 142,
	Fight = 0.08,
	Pools = { "PirateCove" },
	Seasons = { "Spring", "Summer", "Autumn" },
	Shapes = {
		Normal = { "##" },
		Big = { "###", ".#." },
		Huge = { "####", "####" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(153, 66, 56), side = rgb(223, 137, 118), belly = rgb(249, 208, 179) }
		local fin = rgb(167, 75, 69)
		local dark, pale = rgb(25, 29, 35), rgb(249, 246, 222)
		b:fishBody(0.35, 0.15, colors, 0.17)
		b:layered("LongPigSnout", Vector3.new(0.445, -0.075, 0), Vector3.new(0.23, 0.10, 0.09), colors)
		b:edgeFin(0.17, -0.25, { 0.15, 0.13, 0.08, 0.065, 0.055 }, fin)
		for index = 0, 2 do
		    local x = 0.16 - index * 0.055
		    b:limb(Vector3.new(x, b:top(x), 0), Vector3.new(x - 0.07, 0.39 - index * 0.025, 0), 0.009, fin, "DorsalFilament")
		end
		b:edgeFin(-0.05, -0.24, { 0.075, 0.08, 0.045 }, fin, true)
		b:forkTail(0.15, 0.03, fin)
		b:pectoral(0.21, -0.04, 0.12, 0.05, rgb(226, 171, 124))
		b:marks(-0.25, 0.08, 0.065, 0.065, rgb(74, 47, 43))
		b:marks(0.25, 0.07, 0.17, 0.06, rgb(135, 64, 57), v2(1, -0.5))
		b:face(0.36, 0.045, 0.045, rgb(197, 151, 69), rgb(143, 69, 62))
	end,
}
