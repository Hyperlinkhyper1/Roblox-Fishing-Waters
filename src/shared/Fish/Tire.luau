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
		local rubber = rgb(45, 46, 49)
		local sidewall = rgb(53, 54, 57)
		local groove = rgb(27, 28, 30)
		local steel = rgb(126, 130, 133)
		local steelLight = rgb(156, 158, 157)
		local recess = rgb(60, 63, 64)
		local rust = rgb(112, 76, 49)

		-- Cylinders run along local X; turn them to face the wheel's Z axis.
		local function disc(name, z, diameter, width, color)
			local part = b:part(
				name,
				"Part",
				Vector3.new(width, diameter, diameter),
				CFrame.new(0, 0, z) * CFrame.Angles(0, math.pi / 2, 0),
				color
			)
			part.Shape = Enum.PartType.Cylinder
			return part
		end

		-- A continuous tread and narrower sidewalls make a solid, round tire.
		disc("Tread", 0, 0.69, 0.21, rubber)
		disc("Shoulders", 0, 0.65, 0.256, sidewall)
		for _, side in { -1, 1 } do
			-- Layered discs leave narrow concentric rings around the recessed rim.
			disc("SidewallRing", side * 0.129, 0.59, 0.003, groove)
			disc("SidewallInset", side * 0.131, 0.565, 0.003, rubber)
			disc("Bead", side * 0.133, 0.465, 0.004, groove)
			disc("RimLip", side * 0.136, 0.427, 0.008, steelLight)
			disc("RimRecess", side * 0.141, 0.382, 0.004, recess)

			for index = 0, 7 do
				local angle = index * math.pi * 2 / 8
				local radial = Vector3.new(math.cos(angle), math.sin(angle), 0)
				local tangent = Vector3.new(-math.sin(angle), math.cos(angle), 0)
				b:part(
					"Spoke",
					"Part",
					Vector3.new(0.047, 0.137, 0.008),
					CFrame.fromMatrix(radial * 0.109 + Vector3.new(0, 0, side * 0.145), tangent, radial, Vector3.zAxis),
					steel
				)
			end
			disc("Hub", side * 0.15, 0.112, 0.014, steelLight)
			disc("HubCap", side * 0.158, 0.051, 0.004, recess)
			for index = 0, 4 do
				local angle = index * math.pi * 2 / 5
				local position = Vector3.new(math.cos(angle) * 0.042, math.sin(angle) * 0.042, side * 0.159)
				local bolt = b:part(
					"LugNut",
					"Part",
					Vector3.new(0.005, 0.012, 0.012),
					CFrame.new(position) * CFrame.Angles(0, math.pi / 2, 0),
					recess
				)
				bolt.Shape = Enum.PartType.Cylinder
			end
		end

		-- Shallow angled cuts break up the tread without adding rounded bumps.
		local segments = 28
		for index = 0, segments - 1 do
			local angle = index * math.pi * 2 / segments
			local radial = Vector3.new(math.cos(angle), math.sin(angle), 0)
			local tangent = Vector3.new(-math.sin(angle), math.cos(angle), 0)
			for _, side in { -1, 1 } do
				local frame = CFrame.fromMatrix(
					radial * 0.345 + Vector3.new(0, 0, side * 0.051),
					tangent,
					radial,
					Vector3.zAxis
				)
				b:part(
					"TreadGroove",
					"Part",
					Vector3.new(0.009, 0.003, 0.089),
					frame * CFrame.Angles(0, side * 0.28, 0),
					groove
				)
			end
		end

		-- A valve and restrained corrosion give the found wheel some history.
		b:limb(Vector3.new(0.075, -0.17, 0.148), Vector3.new(0.084, -0.192, 0.158), 0.012, groove, "ValveStem")
		for index = 0, 2 do
			local angle = 0.7 + index * 1.9
			local position = Vector3.new(math.cos(angle) * 0.18, math.sin(angle) * 0.18, 0.142)
			local patch = b:part(
				"Rust",
				"Part",
				Vector3.new(0.002, 0.025, 0.025),
				CFrame.new(position) * CFrame.Angles(0, math.pi / 2, 0),
				rust,
				0.15
			)
			patch.Shape = Enum.PartType.Cylinder
		end
		b.model:SetAttribute("ViewDirection", Vector3.new(0.2, 0.5, 1))
	end,
}
