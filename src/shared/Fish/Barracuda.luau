-- Region and season rules are gameplay choices; the body joins the shared EditableMesh loft pipeline.
return {
	Name = "Great Barracuda",
	ScientificName = "Sphyraena barracuda",
	Rarity = "Epic",
	RarityDenominator = 55,
	MinKg = 1.5,
	AverageKg = 12,
	MaxKg = 55,
	LengthScale = 1.4,
	BaseValue = 345,
	Fight = 0.12,
	Pools = { "PirateCove" },
	Seasons = { "Summer", "Autumn" },
	Shapes = {
		Normal = { "####", ".##." },
		Big = { "#####", ".###." },
		Huge = { "######", "######" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(47, 75, 77), side = rgb(162, 186, 181), belly = rgb(235, 239, 220) }
		local fin = rgb(62, 89, 89)
		local dark, pale = rgb(25, 29, 35), rgb(249, 246, 222)
		b:loftBody({ {0.50, 0.025, -0.045, 0.022}, {0.35, 0.065, -0.072, 0.050}, {0.10, 0.085, -0.082, 0.062}, {-0.14, 0.063, -0.056, 0.048}, {-0.35, 0.022, -0.020, 0.015} }, colors, 0.17, 0.12, 0.03)
		b:edgeFin(0.15, 0.045, { 0.09, 0.055 }, fin)
		b:edgeFin(-0.15, -0.27, { 0.075, 0.055 }, fin)
		b:edgeFin(-0.14, -0.27, { 0.075, 0.05 }, fin, true)
		b:forkTail(0.17, 0.065, fin)
		b:pectoral(0.24, -0.025, 0.11, 0.027, fin)
		b:ellipsoid("ProtrudingJaw", CFrame.new(0.45, -0.045, 0), Vector3.new(0.18, 0.035, 0.06), colors.belly)
		for index = 0, 6 do
		    b:marks(0.18 - index * 0.075, 0.01, 0.025, 0.085, colors.back, v2(0.35, 1))
		end
		b:marks(0.43, -0.025, 0.13, 0.015, dark)
		b:eye(0.37, 0.03, 0.045, rgb(210, 191, 104))
	end,
}
