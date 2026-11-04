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
	-- A continuous shell curls down into six overlapping abdominal plates.
	-- The five-lobed fan, stalked eyes and swept feelers carry the silhouette.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local shell, back = rgb(235, 157, 119), rgb(213, 125, 93)
		local belly, joint = rgb(250, 207, 170), rgb(173, 91, 65)
		local legColor, feeler = rgb(232, 166, 128), rgb(198, 121, 87)
		b:body("Carapace", Vector3.new(0.18, 0.055, 0), Vector3.new(0.33, 0.205, 0.17), shell)
		b:body("CarapaceBack", Vector3.new(0.175, 0.083, 0), Vector3.new(0.315, 0.16, 0.166), back)
		b:body("CarapaceBelly", Vector3.new(0.18, -0.005, 0), Vector3.new(0.27, 0.075, 0.143), belly)
		b:body("Head", Vector3.new(0.305, 0.062, 0), Vector3.new(0.12, 0.12, 0.125), shell)

		-- Frames follow the bend, so the plates overlap rather than forming beads.
		local plates = {
			{ 0.005, 0.058, 0.08, 0.175, 0.18, 0.154 },
			{ -0.095, 0.038, 0.30, 0.17, 0.168, 0.143 },
			{ -0.18, -0.007, 0.62, 0.16, 0.147, 0.127 },
			{ -0.24, -0.075, 1.00, 0.145, 0.123, 0.109 },
			{ -0.262, -0.15, 1.52, 0.13, 0.099, 0.088 },
			{ -0.235, -0.214, 2.02, 0.12, 0.076, 0.068 },
		}
		for index, plate in plates do
			local frame = CFrame.new(plate[1], plate[2], 0) * CFrame.Angles(0, 0, plate[3])
			local length, height, width = plate[4], plate[5], plate[6]
			b:ellipsoid("Segment", frame, Vector3.new(length, height, width), shell)
			b:ellipsoid("SegmentBack", frame * CFrame.new(0, height * 0.12, 0), Vector3.new(length * 0.94, height * 0.8, width * 0.99), back)
			b:ellipsoid("SegmentBelly", frame * CFrame.new(0, -height * 0.28, 0), Vector3.new(length * 0.84, height * 0.48, width * 0.85), belly)
			-- A curved seam wraps over each plate, with a small skirt at the sides.
			local previous
			for step = 0, 4 do
				local angle = math.rad(-105 + step * 52.5)
				local point = frame:PointToWorldSpace(Vector3.new(-length * 0.23, math.cos(angle) * height * 0.47, math.sin(angle) * width * 0.47))
				if previous then
					b:limb(previous, point, 0.0045, joint, "ShellSeam")
				end
				previous = point
			end
			if index <= 5 then
				for _, side in { 1, -1 } do
					local hip = frame:PointToWorldSpace(Vector3.new(0.015, -height * 0.35, side * width * 0.25))
					local knee = frame:PointToWorldSpace(Vector3.new(-0.012, -height * 0.7, side * width * 0.45))
					local tip = frame:PointToWorldSpace(Vector3.new(-0.045, -height * 0.78, side * width * 0.57))
					b:limb(hip, knee, 0.007, legColor, "Swimmeret")
					b:limb(knee, tip, 0.005, belly, "Swimmeret")
				end
			end
		end

		-- Two pairs of broad uropods spread around the central pointed telson.
		local root = Vector3.new(-0.208, -0.256, 0)
		local tailDirection, tailUp = Vector3.new(0.65, -0.76, 0).Unit, Vector3.new(0.76, 0.65, 0).Unit
		for _, angle in { -58, -29, 29, 58 } do
			local radians = math.rad(angle)
			local direction = tailDirection * math.cos(radians) + Vector3.zAxis * math.sin(radians)
			local frame = CFrame.fromMatrix(root + direction * 0.055, direction, tailUp)
			b:ellipsoid("UropodEdge", frame, Vector3.new(0.142, 0.016, 0.061), back)
			b:ellipsoid("Uropod", frame + tailUp * 0.003, Vector3.new(0.133, 0.015, 0.052), shell)
			b:limb(root, root + direction * 0.117, 0.004, joint, "FinRay")
		end
		b:fin({ root + Vector3.zAxis * 0.025, root + tailDirection * 0.15, root - Vector3.zAxis * 0.025 }, shell)
		b:limb(root, root + tailDirection * 0.14, 0.005, back, "Telson")

		-- Thin, upturned rostrum with a serrated upper edge.
		b:fin({ v2(0.275, 0.11), v2(0.49, 0.173), v2(0.34, 0.082) }, shell)
		b:limb(Vector3.new(0.29, 0.119, 0), Vector3.new(0.49, 0.173, 0), 0.009, back, "Spine")
		for tooth = 0, 4 do
			local x = 0.335 + tooth * 0.025
			local y = 0.131 + tooth * 0.0068
			b:fin({ v2(x - 0.008, y), v2(x - 0.003, y + 0.018 - tooth * 0.002), v2(x + 0.009, y + 0.004) }, back)
		end
		for _, side in { 1, -1 } do
			local stalk = Vector3.new(0.357, 0.13, side * 0.069)
			b:limb(Vector3.new(0.31, 0.085, side * 0.04), stalk, 0.015, shell, "EyeStalk")
			b:ellipsoid("Eye", CFrame.new(stalk), Vector3.one * 0.034, rgb(23, 18, 16))
			b:ellipsoid("EyeGlint", CFrame.new(stalk + Vector3.new(0.008, 0.009, side * 0.01)), Vector3.one * 0.008, rgb(255, 244, 224))

			-- A broad scale at the feeler base and a smooth, swept-back antenna.
			b:ellipsoid("AntennaScale", CFrame.new(0.373, 0.055, side * 0.054) * CFrame.Angles(0, side * -0.2, 0.12), Vector3.new(0.105, 0.018, 0.036), belly)
			local p0 = Vector3.new(0.345, 0.06, side * 0.045)
			local p1 = Vector3.new(0.78, 0.29, side * 0.13)
			local p2 = Vector3.new(0.08, 0.36, side * 0.23)
			local p3 = Vector3.new(-0.35, 0.235, side * 0.25)
			local previous = p0
			for step = 1, 8 do
				local t = step / 8
				local u = 1 - t
				local point = p0 * u ^ 3 + p1 * (3 * u * u * t) + p2 * (3 * u * t * t) + p3 * t ^ 3
				b:limb(previous, point, 0.0065 - t * 0.0035, feeler, "Filament")
				previous = point
			end
			local bend = Vector3.new(0.443, 0.065, side * 0.075)
			b:limb(p0, bend, 0.007, legColor, "Filament")
			for _, spread in { 0.015, 0.045 } do
				b:limb(bend, Vector3.new(0.56, 0.09 + spread, side * (0.075 + spread)), 0.004, feeler, "Filament")
			end
			for leg = 0, 4 do
				local x = 0.265 - leg * 0.043
				local hip = Vector3.new(x, -0.012, side * 0.046)
				local knee = Vector3.new(x + 0.025 - leg * 0.012, -0.09, side * 0.09)
				local tip = Vector3.new(x + 0.06 - leg * 0.024, -0.167 + leg * 0.008, side * 0.105)
				b:limb(hip, knee, 0.009, legColor, "Limb")
				b:limb(knee, tip, 0.006, legColor, "Limb")
			end
		end
		b:speckle(10, v2(0.06, 0.28), v2(0.06, 0.125), v2(0.004, 0.009), joint)
	end,
}
