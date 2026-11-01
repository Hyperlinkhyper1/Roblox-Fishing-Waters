return {
	Name = "Shrimp",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 0.01,
	AverageKg = 0.03,
	MaxKg = 0.12,
	BaseValue = 46,
	Fight = 0.02,
	Pools = { "OpenSea" },
	Seasons = { "Summer", "Autumn", "Winter" },
	Shapes = {
		Normal = { "#" },
		Big = { "#" },
		Huge = { "##" },
	},
	-- Shrimp: a carapace with a pointed rostrum and stalked eyes, a curled,
	-- segmented abdomen ending in a tail fan, walking legs and long antennae.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(212, 132, 110), side = rgb(232, 168, 146), belly = rgb(246, 214, 200) }
		local limbColor, band = rgb(226, 150, 128), rgb(186, 96, 80)
		b:layered("Carapace", Vector3.new(0.19, 0.02, 0), Vector3.new(0.36, 0.17, 0.15), colors)
		local last
		for index = 1, 6 do
			local t = index / 6
			local center = Vector3.new(0.05 - 0.38 * t, 0.02 - 0.11 * t * t, 0)
			b:layered("Segment", center, Vector3.new(0.11, 0.16 * (1 - 0.42 * t), 0.13 * (1 - 0.45 * t)), colors)
			b:marks(center.X + 0.05, center.Y + 0.01, 0.012, 0.11 * (1 - 0.42 * t), band)
			for _, side in { 1, -1 } do
				local under = Vector3.new(center.X, b:bottom(center.X) + 0.01, side * 0.025)
				if index <= 5 then
					b:limb(under, under + Vector3.new(-0.01, -0.035, side * 0.012), 0.008, limbColor, "Limb")
				end
			end
			last = center
		end
		-- Tail fan: central telson and two pairs of uropods, angled down.
		local root = last + Vector3.new(-0.04, -0.005, 0)
		b:fin({ root, root + Vector3.new(-0.1, -0.05, 0.0), root + Vector3.new(-0.06, -0.07, 0) }, colors.side, 0.1)
		for _, side in { 1, -1 } do
			b:fin({
				root,
				root + Vector3.new(-0.11, -0.03, side * 0.05),
				root + Vector3.new(-0.08, -0.07, side * 0.06),
			}, colors.side, 0.1)
		end
		b:limb(Vector3.new(0.35, 0.05, 0), Vector3.new(0.5, 0.075, 0), 0.016, colors.back, "Spine")
		for _, side in { 1, -1 } do
			local stalk = Vector3.new(0.39, 0.07, side * 0.05)
			b:limb(Vector3.new(0.34, 0.05, side * 0.03), stalk, 0.014, colors.back, "Limb")
			b:ellipsoid("Eye", CFrame.new(stalk), Vector3.one * 0.026, rgb(20, 18, 18))
			b:ellipsoid("EyeGlint", CFrame.new(stalk + Vector3.new(0.006, 0.008, side * 0.008)), Vector3.one * 0.007, rgb(255, 255, 255))
			local bend = Vector3.new(0.5, 0.12, side * 0.06)
			b:limb(Vector3.new(0.37, 0.03, side * 0.02), bend, 0.008, limbColor, "Filament")
			b:limb(bend, Vector3.new(0.2, 0.26, side * 0.16), 0.006, limbColor, "Filament")
			b:limb(Vector3.new(0.2, 0.26, side * 0.16), Vector3.new(-0.25, 0.22, side * 0.2), 0.005, limbColor, "Filament")
			b:limb(Vector3.new(0.37, 0.03, side * 0.01), Vector3.new(0.48, 0.05, side * 0.03), 0.007, limbColor, "Filament")
			for leg = 0, 4 do
				local x = 0.27 - leg * 0.035
				local hip = Vector3.new(x, b:bottom(x) + 0.012, side * 0.03)
				local knee = hip + Vector3.new(0.01, -0.05, side * 0.03)
				b:limb(hip, knee, 0.01, limbColor, "Limb")
				b:limb(knee, knee + Vector3.new(-0.012, -0.045, side * 0.015), 0.008, limbColor, "Limb")
			end
		end
		b:speckle(20, v2(-0.3, 0.3), v2(-0.04, 0.08), v2(0.008, 0.014), band)
	end,
}
