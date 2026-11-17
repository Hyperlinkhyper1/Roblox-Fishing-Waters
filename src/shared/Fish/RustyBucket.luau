return {
	Name = "Rusty Bucket",
	Rarity = "Junk",
	RarityDenominator = 50,
	MinKg = 0.5,
	AverageKg = 1.2,
	MaxKg = 2.5,
	BaseValue = 1,
	Fight = 0,
	Shapes = {
		Normal = { "##", "##" },
	},
	Build = function(b, kit)
		local steel, darkSteel, rust = kit.rgb(122, 132, 133), kit.rgb(71, 82, 80), kit.rgb(139, 79, 43)
		local facets = 16
		local function point(angle, y, radius)
			return Vector3.new(math.cos(angle) * radius, y, math.sin(angle) * radius)
		end
		local function panel(a, c, d, color)
			local first, second = b:triangle(a, c, d, color)
			for _, part in { first, second } do
				part.Name, part.Material = "BucketWall", Enum.Material.Metal
			end
		end
		-- Tapered sheet-metal walls surround an open mouth and recessed floor.
		for index = 0, facets - 1 do
			local a, c = index * math.pi * 2 / facets, (index + 1) * math.pi * 2 / facets
			local bottomA, bottomC = point(a, -0.4, 0.22), point(c, -0.4, 0.22)
			local topA, topC = point(a, 0.15, 0.31), point(c, 0.15, 0.31)
			local color = if index % 4 == 0 then darkSteel else steel
			panel(bottomA, topA, topC, color)
			panel(bottomA, topC, bottomC, color)
			b:limb(topA, topC, 0.024, darkSteel, "RolledRim")
			b:limb(bottomA, bottomC, 0.019, rust, "RustyBaseRim")
		end
		local floor = b:part("BucketFloor", "Part", Vector3.new(0.018, 0.44, 0.44), CFrame.new(0, -0.392, 0) * CFrame.Angles(0, 0, math.pi / 2), darkSteel)
		floor.Shape, floor.Material = Enum.PartType.Cylinder, Enum.Material.Metal
		-- A thin bail handle and small rust patches give the bucket its worn silhouette.
		local previous = Vector3.new(-0.31, 0.11, 0)
		for segment = 1, 16 do
			local angle = math.pi - segment * math.pi / 16
			local nextPoint = Vector3.new(math.cos(angle) * 0.31, 0.11 + math.sin(angle) * 0.34, 0)
			b:limb(previous, nextPoint, 0.014, darkSteel, "BucketHandle")
			previous = nextPoint
		end
		for index = 0, 5 do
			local angle, y = index * math.pi / 3 + 0.2, -0.31 + (index % 3) * 0.135
			local radial = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local center = point(angle, y, 0.22 + (y + 0.4) / 0.55 * 0.09)
			b:ellipsoid("RustPatch", CFrame.lookAt(center, center + radial), Vector3.new(0.065, 0.085, 0.008), rust)
		end
		b.model:SetAttribute("ViewDirection", Vector3.new(0.45, 0.7, 1))
	end,
}
