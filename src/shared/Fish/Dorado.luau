return {
	Name = "Dorado",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 1,
	AverageKg = 4,
	MaxKg = 30,
	BaseValue = 27,
	Fight = 0.06,
	Pools = { "MainLake" },
	Seasons = { "Summer" },
	Requires = { "Clear" },
	Shapes = {
		Normal = { "###" },
		Big = { "###", "###" },
		Huge = { "####", "####" },
	},
	-- Golden dorado: a river predator in gold with rows of dark dashes and a red tail.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(176, 128, 30), side = rgb(232, 182, 54), belly = rgb(246, 226, 160) }
		local fin = rgb(224, 150, 50)
		b:fishBody(0.24, 0.14, colors, 0.05)
		b:edgeFin(0.08, -0.1, { 0.07, 0.07, 0.06, 0.045 }, fin)
		b:ellipsoid("AdiposeFin", CFrame.new(-0.24, b:top(-0.24) + 0.004, 0), Vector3.new(0.05, 0.03, 0.012), fin)
		b:edgeFin(-0.12, -0.23, { 0.06, 0.05, 0.035 }, fin, true)
		b:edgeFin(0.03, -0.06, { 0.05, 0.04 }, fin, true)
		b:forkTail(0.14, 0.06, rgb(214, 72, 44))
		b:stroke({ v2(-0.36, 0), v2(-0.48, 0) }, 0.014, rgb(40, 30, 20))
		b:pectoral(0.2, -0.05, 0.1, 0.035, fin)
		for row = 0, 5 do
			local y = -0.07 + row * 0.03
			for x = 0.22 - (row % 2) * 0.02, -0.3, -0.04 do
				if y < b:top(x) - 0.012 and y > b:bottom(x) + 0.012 then
					b:marks(x, y, 0.018, 0.008, rgb(96, 64, 20))
				end
			end
		end
		b:face(0.37, 0.025, 0.044, rgb(220, 150, 50), rgb(150, 100, 30))
	end,
}
