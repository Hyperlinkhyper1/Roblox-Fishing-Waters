return {
	Name = "Glacierfish",
	Rarity = "Legendary",
	RarityDenominator = 120,
	MinKg = 5,
	AverageKg = 22,
	MaxKg = 140,
	BaseValue = 900,
	Fight = 0.08,
	Pools = { "MainLake", "OpenSea" },
	Seasons = { "Winter" },
	Shapes = {
		Normal = { "###", "###" },
		Big = { "####", "####" },
		Huge = { "#####", "#####", "#####" },
	},
	-- Pale ice-blue legend with frost crystals along its back.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(120, 176, 214), side = rgb(196, 226, 244), belly = rgb(244, 250, 255) }
		local fin, frost = rgb(160, 210, 236), rgb(236, 248, 255)
		b:fishBody(0.26, 0.15, colors, 0.04)
		b:edgeFin(0.14, -0.18, { 0.08, 0.1, 0.1, 0.09, 0.07, 0.05 }, fin, false, 0.25)
		b:edgeFin(-0.06, -0.22, { 0.06, 0.07, 0.05 }, fin, true, 0.25)
		b:edgeFin(0.06, -0.02, { 0.05, 0.04 }, fin, true, 0.25)
		b:forkTail(0.17, 0.07, fin, 0.25)
		b:pectoral(0.2, -0.04, 0.13, 0.04, fin, 0.3)
		for x = 0.26, -0.28, -0.045 do
			local top = b:top(x)
			local height = 0.03 + 0.03 * math.cos(x * 4)
			b:limb(Vector3.new(x, top - 0.004, 0), Vector3.new(x - 0.012, top + height, 0), 0.016, frost, "Spine")
		end
		for _ = 1, 30 do
			local x, y = b.random(-0.3, 0.32), b.random(-0.08, 0.1)
			local size = b.random(0.015, 0.03)
			if y < b:top(x) - size and y > b:bottom(x) + size then
				b:marks(x, y, size, size * 0.5, frost, v2(1, b.random(-1, 1)))
			end
		end
		b:stroke({ v2(0.28, 0.02), v2(0, 0.025), v2(-0.3, 0.005) }, 0.01, rgb(90, 150, 200))
		b:face(0.37, 0.03, 0.05, rgb(140, 220, 255), rgb(120, 170, 210))
	end,
}
