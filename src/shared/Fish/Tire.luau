return {
	Name = "Tire",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 2,
	AverageKg = 7,
	MaxKg = 30,
	BaseValue = 12,
	Fight = 0.02,
	Pools = { "MainLake" },
	Shapes = {
		Normal = { "##" },
		Big = { "###", "###" },
		Huge = { "###", "###", "###" },
	},
	Build = function(b, kit)
		local rgb = kit.rgb
		local rubber = rgb(54, 54, 58)
		local rubberDark = rgb(36, 36, 40)
		local steel = rgb(134, 138, 144)
		local steelDark = rgb(64, 66, 72)
		local recess = rgb(40, 42, 46)
		local rust = rgb(116, 78, 46)
		local algae = rgb(76, 98, 64)
		local zAxis = Vector3.zAxis
		local outerR, tube, halfWidth = 0.345, 0.082, 0.128
		local centerR = outerR - tube
		local segments = 16
		local arc = 2 * math.pi * centerR / segments
		-- Rubber ring: a few long overlapping bands, so the outline stays a
		-- clean circle instead of a chain of beads.
		for index = 0, segments - 1 do
			local angle = index / segments * math.pi * 2
			local radial = Vector3.new(math.cos(angle), math.sin(angle), 0)
			local tangent = Vector3.new(-math.sin(angle), math.cos(angle), 0)
			b:ellipsoid(
				"Tire",
				CFrame.fromMatrix(radial * centerR, tangent, radial, zAxis),
				Vector3.new(arc * 2.4, tube * 2, halfWidth * 2),
				rubber
			)
		end
		-- Tread blocks sitting flush in the hollows between sections.
		for index = 0, segments / 2 - 1 do
			local angle = (index * 2 + 0.5) / segments * math.pi * 2
			local radial = Vector3.new(math.cos(angle), math.sin(angle), 0)
			local tangent = Vector3.new(-math.sin(angle), math.cos(angle), 0)
			b:ellipsoid(
				"TreadBlock",
				CFrame.fromMatrix(radial * (outerR - 0.014), tangent, radial, zAxis),
				Vector3.new(arc * 1.5, 0.042, halfWidth * 1.04),
				rubberDark
			)
		end
		-- Dark drum filling the hub: the open gaps between spokes look straight
		-- through to it, the way a real wheel reads.
		b:ellipsoid("RimDrum", CFrame.new(0, 0, 0), Vector3.new(0.39, 0.39, 0.22), recess)
		local spokes = 10
		for _, side in { 1, -1 } do
			for index = 0, spokes - 1 do
				local angle = index / spokes * math.pi * 2
				local radial = Vector3.new(math.cos(angle), math.sin(angle), 0)
				local z = side * 0.066
				b:limb(
					Vector3.new(radial.X * 0.045, radial.Y * 0.045, z),
					Vector3.new(radial.X * 0.198, radial.Y * 0.198, z),
					0.028,
					steel,
					"Spoke"
				)
			end
			b:ellipsoid("Hub", CFrame.new(0, 0, side * 0.066), Vector3.new(0.13, 0.13, 0.055), steel)
			b:ellipsoid("HubCap", CFrame.new(0, 0, side * 0.085), Vector3.new(0.055, 0.055, 0.04), steelDark)
		end
		b:limb(Vector3.new(0.051, -0.191, 0.07), Vector3.new(0.06, -0.218, 0.098), 0.016, steelDark, "ValveStem")
		-- A little rust on the rim and weed on the tread.
		for _ = 1, 3 do
			local angle = b.random(0, math.pi * 2)
			local radial = Vector3.new(math.cos(angle), math.sin(angle), 0)
			local tangent = Vector3.new(-math.sin(angle), math.cos(angle), 0)
			b:ellipsoid(
				"Rust",
				CFrame.fromMatrix(radial * 0.145 + Vector3.new(0, 0, b.random(0.03, 0.075)), tangent, radial, zAxis),
				Vector3.new(b.random(0.03, 0.055), b.random(0.02, 0.04), 0.012),
				rust,
				0.1
			)
		end
		for _ = 1, 4 do
			local angle = b.random(0, math.pi * 2)
			local radial = Vector3.new(math.cos(angle), math.sin(angle), 0)
			local tangent = Vector3.new(-math.sin(angle), math.cos(angle), 0)
			local size = b.random(0.05, 0.1)
			b:ellipsoid(
				"Algae",
				CFrame.fromMatrix(radial * (outerR - 0.006), tangent, radial, zAxis),
				Vector3.new(size, 0.024, size * 0.7),
				algae,
				0.1
			)
		end
		b.model:SetAttribute("ViewDirection", Vector3.new(0.2, 0.5, 1))
	end,
}
