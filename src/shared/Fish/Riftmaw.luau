return {
	Name = "Riftmaw",
	Rarity = "Exotic",
	RarityDenominator = 650,
	MinKg = 18,
	AverageKg = 70,
	MaxKg = 500,
	LengthScale = 1.2,
	BaseValue = 4600,
	Fight = 0.14,
	Pools = { "OpenSea" },
	Seasons = { "Spring", "Summer", "Autumn", "Winter" },
	Requires = { "BlackHole" },
	Shapes = {
		Normal = { ".###.", "#####", ".###." },
		Big = { ".####.", "######", ".####." },
		Huge = { ".#####.", "#######", "#######", ".#####." },
	},
	-- A heavy obsidian predator, split by violet fault lines and crystal teeth.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(9, 6, 15), side = rgb(27, 16, 40), belly = rgb(42, 22, 59) }
		local armor, membrane = rgb(15, 10, 24), rgb(47, 22, 72)
		local violet, pale = rgb(170, 48, 255), rgb(219, 132, 255)
		local function glow(part)
			if part then
				part.Material = Enum.Material.Neon
				part:SetAttribute("BlackHoleAccent", true)
			end
			return part
		end
		local function crystal(a, c, tip)
			local first, second = b:triangle(a, c, tip, violet)
			glow(first)
			glow(second)
		end
		b:beginSkin(colors)
		b:layered("Shoulders", Vector3.new(0.08, 0.01, 0), Vector3.new(0.66, 0.37, 0.29), colors)
		b:layered("ArmoredHead", Vector3.new(0.29, -0.008, 0), Vector3.new(0.38, 0.31, 0.29), colors)
		b:layered("RearBody", Vector3.new(-0.2, 0.0, 0), Vector3.new(0.35, 0.25, 0.19), colors)
		b:layered("TailStalk", Vector3.new(-0.36, -0.01, 0), Vector3.new(0.18, 0.11, 0.08), colors)
		b:finishSkin()
		b:layered("MassiveJaw", Vector3.new(0.32, -0.14, 0), Vector3.new(0.4, 0.12, 0.3), colors)
		b:ellipsoid("Mouth", CFrame.new(0.425, -0.075, 0), Vector3.new(0.16, 0.15, 0.25), rgb(4, 2, 8))
		-- A chunky split tail carries violet crystal blades along both lobes.
		for _, sign in { 1, -1 } do
			b:fin({ v2(-0.39, 0), v2(-0.58, sign * 0.20), v2(-0.59, sign * 0.10), v2(-0.48, 0) }, membrane)
			crystal(Vector3.new(-0.57, sign * 0.19, 0), Vector3.new(-0.55, sign * 0.10, 0), Vector3.new(-0.64, sign * 0.23, 0))
		end
		-- Six separate jagged dorsal plates read as a broken crown, not a sail.
		for index = 0, 5 do
			local x = 0.28 - index * 0.105
			local y = b:top(x)
			local height = if index < 3 then 0.15 - index * 0.013 else 0.13 - (index - 3) * 0.025
			b:fin({ v2(x + 0.035, y - 0.012), v2(x - 0.04, y + height), v2(x - 0.075, y - 0.015) }, armor)
			glow(b:limb(Vector3.new(x - 0.022, y + 0.045, 0), Vector3.new(x - 0.04, y + height, 0), 0.009, violet, "CrystalSpine"))
		end
		b:edgeFin(-0.08, -0.32, { 0.08, 0.07, 0.035 }, membrane, true)
		b:pectoral(0.18, -0.07, 0.23, 0.14, armor)
		-- Side plates stand just proud of the smooth skin.
		for _, side in { -1, 1 } do
			for index = 0, 2 do
				local x = 0.15 - index * 0.13
				local origin = b:surface(x, 0.045, side)
				if origin then
					b:triangle(origin + Vector3.new(0.04, 0.055, side * 0.007), origin + Vector3.new(-0.07, 0.005, side * 0.01), origin + Vector3.new(0.015, -0.045, side * 0.014), armor)
				end
			end
			-- Upper and lower teeth meet across the open front of the maw.
			for index = 0, 3 do
				local z = side * (0.025 + index * 0.032)
				local x = 0.493 - index * 0.016
				crystal(Vector3.new(x - 0.024, 0.0, z), Vector3.new(x + 0.008, -0.005, z), Vector3.new(x + 0.005, -0.08, z))
				crystal(Vector3.new(x - 0.022, -0.14, z), Vector3.new(x + 0.01, -0.14, z), Vector3.new(x + 0.007, -0.095, z))
			end
		end
		-- Branching, surface-following fault lines stay crisp on either flank.
		local cracks = {
			{ v2(0.25, 0.085), v2(0.14, 0.02) },
			{ v2(0.14, 0.02), v2(0.07, 0.055) },
			{ v2(0.07, 0.055), v2(-0.045, -0.012) },
			{ v2(-0.045, -0.012), v2(-0.17, 0.025) },
			{ v2(-0.17, 0.025), v2(-0.29, -0.005) },
			{ v2(0.14, 0.02), v2(0.16, -0.075) },
			{ v2(-0.045, -0.012), v2(-0.09, -0.075) },
			{ v2(0.07, 0.055), v2(0.035, 0.13) },
		}
		for _, crack in cracks do
			local delta, middle = crack[2] - crack[1], (crack[1] + crack[2]) / 2
			for _, side in { -1, 1 } do
				glow(b:mark(middle.X, middle.Y, side, delta.Magnitude * 1.1, 0.009, violet, delta, 0.012))
			end
		end
		b:eye(0.34, 0.072, 0.047, pale)
		for _, part in b.model:GetDescendants() do
			if part:IsA("BasePart") and part.Name == "Eye" then glow(part) end
		end
	end,
}
