return {
	Name = "Wooden Branch",
	Rarity = "Junk",
	RarityDenominator = 50,
	MinKg = 0.2,
	AverageKg = 0.5,
	MaxKg = 1,
	BaseValue = 1,
	Fight = 0,
	Shapes = {
		Normal = { "###" },
	},
	Build = function(b, kit)
		local rgb = kit.rgb
		local bark = { rgb(83, 55, 33), rgb(112, 77, 45), rgb(94, 62, 36), rgb(68, 46, 30), rgb(101, 68, 40) }
		local wood, freshWood, split = rgb(180, 138, 82), rgb(207, 166, 105), rgb(48, 33, 23)
		local function face(a, c, d, color, name)
			local first, second = b:triangle(a, c, d, color)
			for _, part in { first, second } do
				part.Name = name
				part.Material = Enum.Material.Wood
			end
		end

		-- Shared five-sided rings keep each bend joined while tapering the branch.
		-- Uneven ring radii and staggered end vertices make flat, chipped wood faces.
		local facets = 5
		local widths = { 1, 0.88, 1.06, 0.91, 0.97 }
		local chips = { 0.2, -0.12, 0.08, -0.23, 0.14 }
		local function branch(points, radii, roll, isTrunk)
			local axis = (points[#points] - points[1]).Unit
			local side = axis:Cross(Vector3.yAxis).Unit
			local up = side:Cross(axis).Unit
			local rings = {}
			for index, center in points do
				local ring = {}
				for corner = 1, facets do
					local angle = (corner - 1) * math.pi * 2 / facets + roll
					local radial = up * math.cos(angle) + side * math.sin(angle)
					local chip = if index == 1 or index == #points then chips[corner] * radii[index] else 0
					ring[corner] = center + radial * radii[index] * widths[corner] + axis * chip
				end
				table.insert(rings, ring)
			end
			for index = 1, #rings - 1 do
				local a, c = rings[index], rings[index + 1]
				for corner = 1, facets do
					local nextCorner = corner % facets + 1
					local color = bark[corner]
					face(a[corner], c[corner], c[nextCorner], color, "BarkFacet")
					face(a[corner], c[nextCorner], a[nextCorner], color, "BarkFacet")
					if isTrunk then
						-- Tapered cracks sit on the actual sloping bark faces, on all sides.
						local normal = (a[corner] - points[index] + a[nextCorner] - points[index]).Unit
						local start = a[corner]:Lerp(a[nextCorner], 0.36):Lerp(c[corner]:Lerp(c[nextCorner], 0.36), 0.16)
						local finish = a[corner]:Lerp(a[nextCorner], 0.44):Lerp(c[corner]:Lerp(c[nextCorner], 0.44), 0.87)
						local across = (a[nextCorner] - a[corner]).Unit * 0.003
						local lift = normal * 0.003
						face(start - across + lift, start + across + lift, finish + lift, split, "BarkSplit")
					end
				end
			end
			for _, index in { 1, #rings } do
				for corner = 1, facets do
					local color = if corner % 2 == 0 then freshWood else wood
					face(points[index], rings[index][corner], rings[index][corner % facets + 1], color, "ExposedWood")
				end
			end
			return rings, axis
		end

		local points = {
			Vector3.new(-0.5, -0.04, 0),
			Vector3.new(-0.18, 0.018, 0.012),
			Vector3.new(0.14, -0.012, -0.006),
			Vector3.new(0.48, 0.065, -0.028),
		}
		local rings, axis = branch(points, { 0.065, 0.055, 0.041, 0.026 }, 0.23, true)
		branch(
			{ points[2], Vector3.new(-0.09, 0.19, 0.025), Vector3.new(0.015, 0.31, 0.045) },
			{ 0.033, 0.023, 0.009 },
			0.7,
			false
		)
		branch({ points[3], Vector3.new(0.29, -0.205, 0.07) }, { 0.025, 0.011 }, -0.25, false)

		-- A pair of solid triangular splinters extends the snapped thick end.
		for _, corner in { 1, 3 } do
			local ring = rings[1]
			local a, c = ring[corner], ring[corner % facets + 1]
			local root = points[1]:Lerp((a + c) / 2, 0.6)
			local tip = a:Lerp(c, 0.3) - axis * (if corner == 1 then 0.07 else 0.042)
			face(a, c, tip, bark[corner], "BrokenBark")
			face(a, root, tip, wood, "WoodSplinter")
			face(c, tip, root, freshWood, "WoodSplinter")
		end
		b.model:SetAttribute("ViewDirection", Vector3.new(0.35, 0.5, 1))
	end,
}
