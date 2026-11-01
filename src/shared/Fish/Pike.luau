return {
	Name = "Pike",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 0.5,
	AverageKg = 2.5,
	MaxKg = 25,
	BaseValue = 26,
	Fight = 0.07,
	Pools = { "MainLake" },
	Seasons = { "Summer", "Autumn" },
	Shapes = {
		Normal = { "###" },
		Big = { "####" },
		Huge = { "#####", ".###." },
	},
	-- Long ambush predator: dorsal and anal fins set far back, flat duck-bill snout.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(58, 78, 44), side = rgb(118, 140, 82), belly = rgb(226, 228, 196) }
		local fin = rgb(132, 110, 62)
		b:fishBody(0.15, 0.1, colors, 0.02)
		b:layered("Snout", Vector3.new(0.45, -0.006, 0), Vector3.new(0.2, 0.065, 0.08), colors)
		b:edgeFin(-0.12, -0.25, { 0.06, 0.07, 0.06, 0.04 }, fin)
		b:edgeFin(-0.14, -0.26, { 0.05, 0.06, 0.04 }, fin, true)
		b:edgeFin(0.02, -0.04, { 0.04 }, fin, true)
		b:forkTail(0.11, 0.04, fin)
		b:pectoral(0.25, -0.03, 0.08, 0.025, fin)
		b:speckle(44, v2(-0.3, 0.3), v2(-0.04, 0.06), v2(0.014, 0.026), rgb(206, 214, 150))
		for _ = 1, 10 do
			b:finSpot(b.random(-0.47, -0.37), b.random(-0.09, 0.09), 0.014, rgb(60, 50, 30))
		end
		b:stroke({ v2(0.54, -0.014), v2(0.4, -0.03) }, 0.007, rgb(36, 34, 26))
		b:face(0.35, 0.02, 0.04, rgb(214, 186, 80), rgb(80, 96, 56))
	end,
}
