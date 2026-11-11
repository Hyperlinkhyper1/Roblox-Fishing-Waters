return {
	Name = "Blackflag Grouper",
	Rarity = "Epic",
	RarityDenominator = 30,
	MinKg = 6,
	AverageKg = 25,
	MaxKg = 120,
	BaseValue = 400,
	Fight = 0.07,
	Pools = { "PirateCove" },
	Seasons = { "Spring", "Summer", "Autumn", "Winter" },
	Shapes = {
		Normal = { "###", "###" },
		Big = { "####", "####" },
		Huge = { "#####", "#####" },
	},
	-- A huge coal-black grouper that lurks under the cove's pier. Every one carries a pale skull
	-- and crossbones on its flank, which is how the cove got its flag.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(28, 28, 32), side = rgb(62, 60, 66), belly = rgb(146, 142, 136) }
		local fin = rgb(40, 38, 44)
		local bone, socket = rgb(236, 230, 214), rgb(18, 16, 18)
		b:fishBody(0.32, 0.17, colors, 0.06)
		local spines = b:edgeFin(0.16, -0.04, { 0.05, 0.065, 0.06, 0.055, 0.05 }, fin, false, 0.05)
		b:rays(spines[1], { spines[3], spines[4], spines[5] }, rgb(20, 20, 24))
		b:edgeFin(-0.04, -0.24, { 0.06, 0.07, 0.06, 0.04 }, fin, false, 0.05)
		b:edgeFin(-0.08, -0.24, { 0.06, 0.06, 0.04 }, fin, true, 0.05)
		b:edgeFin(0.12, 0.02, { 0.06, 0.04 }, fin, true, 0.1)
		b:roundTail(0.12, fin)
		b:pectoral(0.2, -0.04, 0.13, 0.05, fin)
		-- Crossbones first, the skull over them, then its eye sockets on top.
		b:stroke({ v2(-0.09, -0.06), v2(0.07, 0.05) }, 0.014, bone)
		b:stroke({ v2(-0.09, 0.05), v2(0.07, -0.06) }, 0.014, bone)
		for _, side in { 1, -1 } do
			b:mark(-0.01, 0.015, side, 0.075, 0.065, bone, nil, 0.001)
			b:mark(-0.01, -0.025, side, 0.045, 0.03, bone, nil, 0.001)
			b:mark(-0.025, 0.02, side, 0.018, 0.02, socket, nil, 0.002)
			b:mark(0.005, 0.02, side, 0.018, 0.02, socket, nil, 0.002)
		end
		b:speckle(18, v2(0.3, -0.3), v2(-0.08, 0.1), v2(0.008, 0.016), rgb(86, 84, 90))
		b:face(0.37, 0.04, 0.05, rgb(200, 44, 32), rgb(20, 20, 24))
	end,
}
