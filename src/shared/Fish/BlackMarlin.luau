return {
	Name = "Black Marlin",
	Rarity = "Legendary",
	RarityDenominator = 160,
	MinKg = 40,
	AverageKg = 180,
	MaxKg = 750,
	LengthScale = 1.65,
	BaseValue = 1200,
	Fight = 0.12,
	Pools = { "CinderIsles" },
	Seasons = { "Summer", "Autumn" },
	Requires = { "Day" },
	Shapes = {
		Normal = { "#####", ".###." },
		Big = { "######", ".####." },
		Huge = { "#######", "#######" },
	},
	-- Heavy dark shoulders and rigid lateral pectorals distinguish this marlin.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(20, 27, 34), side = rgb(80, 98, 108), belly = rgb(210, 220, 224) }
		local fin = rgb(28, 38, 48)
		b:fishBody(0.235, 0.16, colors, 0.02)
		b:layered("Shoulder", Vector3.new(0.18, 0.02, 0), Vector3.new(0.42, 0.245, 0.17), colors)
		b:edgeFin(0.25, -0.23, { 0.11, 0.13, 0.09, 0.045, 0.025, 0.02, 0.016 }, fin)
		b:edgeFin(-0.25, -0.3, { 0.035 }, fin)
		b:edgeFin(0.0, -0.14, { 0.08, 0.055, 0.025 }, fin, true)
		b:edgeFin(-0.25, -0.3, { 0.03 }, fin, true)
		b:lunateTail(0.24, fin)
		for _, side in { 1, -1 } do
			b:fin({
				Vector3.new(0.24, -0.015, side * 0.075),
				Vector3.new(0.10, -0.055, side * 0.30),
				Vector3.new(0.17, -0.065, side * 0.105),
			}, fin)
			b:limb(Vector3.new(0.16, b:bottom(0.16), side * 0.014), Vector3.new(-0.02, -0.19, side * 0.03), 0.008, fin, "PelvicFin")
			b:ellipsoid("TailKeel", CFrame.new(-0.32, 0, side * 0.025), Vector3.new(0.10, 0.018, 0.03), fin)
		end
		b:stroke({ v2(0.27, 0.02), v2(0.08, 0.015), v2(-0.26, 0.0) }, 0.006, rgb(122, 146, 158))
		b:limb(Vector3.new(0.43, 0.008, 0), Vector3.new(0.78, 0.001, 0), 0.03, colors.back, "Bill")
		b:face(0.37, 0.035, 0.047, rgb(134, 150, 148), rgb(40, 52, 62))
	end,
}
