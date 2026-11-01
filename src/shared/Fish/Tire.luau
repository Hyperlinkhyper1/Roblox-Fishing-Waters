return {
	Name = "tire",
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
		local rubber = rgb(40, 40, 42)
		local rubberDark = rgb(26, 26, 28)
		local rubberLight = rgb(64, 64, 68)
		local treadColor = rgb(20, 20, 22)
		local steel = rgb(158, 162, 168)
		local steelDark = rgb(84, 88, 94)
		local rust = rgb(124, 82, 46)
		local algae = rgb(72, 94, 60)
		local radius, tube, width = 0.345, 0.088, 0.235
		local count = 22
		local arc = 2 * math.pi * radius / count
		local zAxis = Vector3.zAxis
		-- Sidewall depth at a given offset from the tube centreline.
		local function sideZ(offset: number): number
			local t = math.clamp(offset / tube, -0.995, 0.995)
			return width / 2 * math.sqrt(1 - t * t)
		end
		-- Rubber torus: overlapping tube sections with a raised tread band.
		for index = 0, count - 1 do
			local angle = index / count * math.pi * 2
			local radial = Vector3.new(math.cos(angle), math.sin(angle), 0)
			local tangent = Vector3.new(-math.sin(angle), math.cos(angle), 0)
			local frame = CFrame.fromMatrix(radial * radius, tangent, radial, zAxis)
			b:ellipsoid("Tire", frame, Vector3.new(arc * 1.45, tube * 2, width), rubber)
			b:ellipsoid(
				"TreadBand",
				frame * CFrame.new(0, tube * 0.72, 0),
				Vector3.new(arc * 1.12, tube * 0.9, width * 0.86),
				rubberDark
			)
			-- Chevron lugs across the crown of the tread.
			for _, z in { -0.062, 0.062 } do
				b:ellipsoid(
					"TreadLug",
					frame * CFrame.new(0, tube * 0.98, z),
					Vector3.new(arc * 0.66, 0.058, 0.052),
					treadColor
				)
			end
			-- Shoulder blocks bridging the tread onto the sidewalls.
			for _, side in { 1, -1 } do
				b:ellipsoid(
					"Shoulder",
					frame * CFrame.new(0, tube * 0.42, side * width * 0.34),
					Vector3.new(arc * 0.7, 0.07, 0.05),
					rubberDark
				)
			end
		end
		-- Concentric sidewall ribs, plus weathered lettering on both faces.
		for _, side in { 1, -1 } do
			for _, offset in { -0.052, -0.026 } do
				local depth = sideZ(offset)
				for index = 0, count - 1 do
					local angle = (index + 0.5) / count * math.pi * 2
					local radial = Vector3.new(math.cos(angle), math.sin(angle), 0)
					local tangent = Vector3.new(-math.sin(angle), math.cos(angle), 0)
					local position = radial * (radius + offset) + Vector3.new(0, 0, side * (depth + 0.002))
					b:ellipsoid(
						"SidewallRib",
						CFrame.fromMatrix(position, tangent, radial, zAxis),
						Vector3.new(arc * 1.1, 0.022, 0.012),
						if offset < -0.04 then rubberLight else rubber
					)
				end
			end
			local letterDepth = sideZ(0.004)
			for index = 0, count - 1, 2 do
				local angle = index / count * math.pi * 2
				local radial = Vector3.new(math.cos(angle), math.sin(angle), 0)
				local tangent = Vector3.new(-math.sin(angle), math.cos(angle), 0)
				local position = radial * (radius + 0.004) + Vector3.new(0, 0, side * (letterDepth + 0.001))
				b:ellipsoid(
					"SidewallLetter",
					CFrame.fromMatrix(position, tangent, radial, zAxis),
					Vector3.new(0.042, 0.015, 0.005),
					rubberLight,
					0.25
				)
			end
		end
		-- Steel rim: dark inner well, bright lip, five spokes and the hub.
		b:ellipsoid("RimWell", CFrame.new(0, 0, 0), Vector3.new(0.5, 0.5, 0.155), steelDark)
		b:ellipsoid("RimBarrel", CFrame.new(0, 0, 0), Vector3.new(0.46, 0.46, 0.17), steelDark)
		for _, side in { 1, -1 } do
			local z = side * 0.062
			for index = 0, 17 do
				local angle = index / 18 * math.pi * 2
				local radial = Vector3.new(math.cos(angle), math.sin(angle), 0)
				local tangent = Vector3.new(-math.sin(angle), math.cos(angle), 0)
				b:ellipsoid(
					"RimLip",
					CFrame.fromMatrix(radial * 0.234 + Vector3.new(0, 0, z), tangent, radial, zAxis),
					Vector3.new(0.088, 0.046, 0.03),
					steel
				)
			end
			for index = 0, 4 do
				local angle = index / 5 * math.pi * 2 + math.pi / 10
				local radial = Vector3.new(math.cos(angle), math.sin(angle), 0)
				b:limb(
					Vector3.new(radial.X * 0.055, radial.Y * 0.055, z),
					Vector3.new(radial.X * 0.216, radial.Y * 0.216, z),
					0.052,
					steel,
					"Spoke"
				)
			end
			b:ellipsoid("Hub", CFrame.new(0, 0, z), Vector3.new(0.17, 0.17, 0.05), steel)
			b:ellipsoid("HubCenter", CFrame.new(0, 0, z + side * 0.02), Vector3.new(0.075, 0.075, 0.03), steelDark)
			for index = 0, 4 do
				local angle = index / 5 * math.pi * 2 + math.pi / 10
				local radial = Vector3.new(math.cos(angle), math.sin(angle), 0)
				b:ellipsoid(
					"LugNut",
					CFrame.new(radial * 0.054 + Vector3.new(0, 0, z + side * 0.02)),
					Vector3.one * 0.025,
					steel
				)
			end
		end
		-- Valve stem and a few rust blooms where the rim has been sitting wet.
		b:limb(Vector3.new(0.16, -0.13, 0.07), Vector3.new(0.17, -0.19, 0.085), 0.016, steelDark, "ValveStem")
		for _ = 1, 9 do
			local angle = b.random(0, math.pi * 2)
			local radial = Vector3.new(math.cos(angle), math.sin(angle), 0)
			local tangent = Vector3.new(-math.sin(angle), math.cos(angle), 0)
			local reach = b.random(0.06, 0.2)
			local side = if b.random(0, 1) > 0.5 then 1 else -1
			local depth = 0.075 * math.sqrt(math.max(0, 1 - (reach / 0.245) ^ 2))
			b:ellipsoid(
				"Rust",
				CFrame.fromMatrix(radial * reach + Vector3.new(0, 0, side * (depth + 0.002)), tangent, radial, zAxis),
				Vector3.new(b.random(0.02, 0.05), b.random(0.015, 0.04), 0.005),
				rust,
				0.1
			)
		end
		-- Weed and silt clinging to the rubber.
		for _ = 1, 16 do
			local angle = b.random(0, math.pi * 2)
			local offset = b.random(-tube * 0.8, tube * 0.8)
			local side = if b.random(0, 1) > 0.5 then 1 else -1
			local radial = Vector3.new(math.cos(angle), math.sin(angle), 0)
			local tangent = Vector3.new(-math.sin(angle), math.cos(angle), 0)
			local position = radial * (radius + offset) + Vector3.new(0, 0, side * (sideZ(offset) + 0.002))
			local size = b.random(0.018, 0.05)
			b:ellipsoid(
				"Algae",
				CFrame.fromMatrix(position, tangent, radial, zAxis),
				Vector3.new(size, size * 0.72, 0.006),
				algae,
				0.1
			)
		end
		b.model:SetAttribute("ViewDirection", Vector3.new(0.2, 0.5, 1))
	end,
}
