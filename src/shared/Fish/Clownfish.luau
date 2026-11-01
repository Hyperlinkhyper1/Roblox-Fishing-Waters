return {
	Name = "Clownfish",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 0.03,
	AverageKg = 0.09,
	MaxKg = 0.45,
	BaseValue = 19,
	Fight = 0.03,
	Pools = { "OpenSea" },
	Seasons = { "Summer" },
	Requires = { "Clear" },
	Shapes = {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "##", "##" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(222, 92, 20), side = rgb(240, 122, 32), belly = rgb(246, 158, 72) }
		local fin = rgb(236, 112, 30)
		local white, edge = rgb(250, 250, 246), rgb(22, 18, 16)
		b:fishBody(0.36, 0.14, colors, 0.06)
		b:edgeFin(0.12, -0.26, { 0.06, 0.07, 0.06, 0.08, 0.09, 0.08 }, fin)
		b:edgeFin(-0.06, -0.24, { 0.06, 0.08, 0.06 }, fin, true)
		b:edgeFin(0.08, 0, { 0.07, 0.05 }, fin, true)
		b:roundTail(0.13, fin)
		b:pectoral(0.18, -0.04, 0.11, 0.05, fin)
		-- White bands with thin black borders.
		for _, x in { 0.2, -0.02, -0.3 } do
			local width = if x < -0.2 then 0.03 else 0.045
			b:stroke({ v2(x, b:top(x) - 0.008), v2(x - 0.01, b:bottom(x) + 0.008) }, width, white)
			for _, offset in { -1, 1 } do
				local bx = x + offset * (width / 2 + 0.008)
				b:stroke({ v2(bx, b:top(bx) - 0.008), v2(bx - 0.01, b:bottom(bx) + 0.008) }, 0.009, edge)
			end
		end
		b:face(0.38, 0.04, 0.05, rgb(232, 120, 40), edge)
	end,
}
