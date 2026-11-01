return {
	Name = "Crimsonfish",
	Rarity = "Rare",
	RarityDenominator = 15,
	MinKg = 0.3,
	AverageKg = 1.2,
	MaxKg = 8,
	BaseValue = 100,
	Fight = 0.05,
	Pools = { "MainLake", "OpenSea" },
	Seasons = { "Summer" },
	Requires = { "Beach" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "###", "###" },
	},
	-- Crimson beach fish with gold-edged, flowing fins.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(120, 16, 30), side = rgb(196, 30, 46), belly = rgb(236, 120, 110) }
		local fin, gold = rgb(176, 26, 40), rgb(240, 190, 70)
		b:fishBody(0.24, 0.12, colors, 0.05)
		local dorsal = b:edgeFin(0.14, -0.2, { 0.09, 0.11, 0.12, 0.12, 0.11, 0.09, 0.06 }, fin, false, 0.1)
		b:stroke({ dorsal[3], dorsal[4], dorsal[5], dorsal[6], dorsal[7], dorsal[8] }, 0.01, gold)
		local anal = b:edgeFin(-0.06, -0.22, { 0.07, 0.09, 0.08, 0.05 }, fin, true, 0.1)
		b:stroke({ anal[3], anal[4], anal[5], anal[6] }, 0.01, gold)
		b:edgeFin(0.06, -0.01, { 0.06, 0.05 }, fin, true, 0.1)
		b:forkTail(0.17, 0.08, fin, 0.08)
		b:stroke({ v2(-0.5, 0.17), v2(-0.42, 0.08) }, 0.01, gold)
		b:stroke({ v2(-0.5, -0.17), v2(-0.42, -0.08) }, 0.01, gold)
		b:pectoral(0.2, -0.04, 0.13, 0.04, rgb(226, 90, 80), 0.2)
		b:speckle(26, v2(-0.28, 0.3), v2(-0.04, 0.08), v2(0.01, 0.018), rgb(250, 170, 150))
		b:face(0.37, 0.03, 0.05, gold, rgb(140, 20, 34))
	end,
}
