return {
	Name = "Largemouth Bass",
	Rarity = "Rare",
	RarityDenominator = 14,
	MinKg = 0.3,
	AverageKg = 2.3,
	MaxKg = 11,
	BaseValue = 62,
	Fight = 0.1,
	Pools = { "MainLake", "SoddenMire" },
	Seasons = { "Spring", "Summer", "Autumn" },
	Shapes = {
		Normal = { "###" },
		Big = { "####" },
		Huge = { "#####", "#####" },
	},
	-- Species-specific body proportions, fins and flank markings share the smooth mesh pipeline.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(46, 72, 36), side = rgb(130, 152, 78), belly = rgb(232, 232, 196) }
		local fin = rgb(96, 118, 60)
		b:fishBody(0.31, 0.16, colors, 0.1)
		local dorsal = b:edgeFin(0.15, -0.23, { 0.05, 0.065, 0.06, 0.045, 0.015, 0.02, 0.075, 0.085, 0.065 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3], dorsal[4], dorsal[5] }, rgb(42, 62, 32))
		b:edgeFin(-0.08, -0.23, { 0.06, 0.07, 0.045 }, fin, true)
		b:edgeFin(0.08, 0, { 0.055, 0.04 }, fin, true)
		b:forkTail(0.13, 0.028, fin)
		b:pectoral(0.21, -0.04, 0.105, 0.04, fin, 0.1)
		-- Broad broken lateral stripe and a jaw hinge extending behind the eye.
		for x = 0.25, -0.29, -0.055 do
			b:marks(x, 0, 0.073, 0.042, rgb(42, 64, 30))
		end
		b:stroke({ v2(0.47, -0.025), v2(0.34, -0.075), v2(0.28, -0.045) }, 0.012, rgb(42, 54, 28))
		b:ellipsoid("LowerJaw", CFrame.new(0.425, -0.065, 0), Vector3.new(0.15, 0.035, 0.095), colors.belly)
		b:face(0.37, 0.033, 0.046, rgb(188, 152, 68), rgb(42, 62, 32))
	end,
}
