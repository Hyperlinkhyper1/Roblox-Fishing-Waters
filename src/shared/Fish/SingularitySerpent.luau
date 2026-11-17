return {
	Name = "Singularity Serpent",
	Rarity = "Divine",
	RarityDenominator = 1500,
	MinKg = 35,
	AverageKg = 150,
	MaxKg = 1200,
	LengthScale = 1.5,
	BaseValue = 9000,
	Fight = 0.18,
	Pools = { "OpenSea" },
	Seasons = { "Spring", "Summer", "Autumn", "Winter" },
	Requires = { "BlackHole" },
	Shapes = {
		Normal = { "#####", "....#" },
		Big = { "######", "....##" },
		Huge = { "#######", ".....##", ".....##" },
	},
	-- An S-curved dragon eel with a violet crest, comet tail and light organs.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(8, 5, 15), side = rgb(25, 14, 40), belly = rgb(44, 22, 66) }
		local plate, membrane = rgb(14, 8, 24), rgb(64, 24, 101)
		local violet, pale = rgb(153, 42, 255), rgb(216, 133, 255)
		local function glow(part)
			if part then
				part.Material = Enum.Material.Neon
				part:SetAttribute("BlackHoleAccent", true)
			end
			return part
		end
		local function light(a, c, size, color, name)
			return glow(b:limb(a, c, size, color or violet, name or "VoidFilament"))
		end
		-- The fallback sections and smooth loft share the same curved centerline.
		local spine = {
			{ 0.46, 0.045, 0.19, 0.16 },
			{ 0.30, 0.04, 0.22, 0.18 },
			{ 0.10, 0.025, 0.205, 0.15 },
			{ -0.10, -0.025, 0.175, 0.12 },
			{ -0.30, -0.085, 0.145, 0.095 },
			{ -0.49, -0.085, 0.11, 0.075 },
			{ -0.66, -0.03, 0.08, 0.05 },
			{ -0.79, 0.045, 0.045, 0.03 },
		}
		b:beginSkin(colors)
		for index, node in spine do
			b:layered("Coil" .. index, Vector3.new(node[1], node[2], 0), Vector3.new(if index == 1 then 0.27 else 0.31, node[3], node[4]), colors)
		end
		local stations = { { 0.595, 0.055, 0.035, 0.006 } }
		for _, node in spine do
			table.insert(stations, { node[1], node[2] + node[3] * 0.5, node[2] - node[3] * 0.5, node[4] * 0.5 })
		end
		table.insert(stations, { -0.89, 0.079, 0.065, 0.007 })
		b:finishSkin(stations)
		-- One continuous dorsal ribbon follows the back into the rising tail.
		local previousBase, previousTip
		for index, node in spine do
			local base = Vector3.new(node[1], b:top(node[1]) - 0.008, 0)
			local tip = base + Vector3.new(-0.065, 0.12 + math.sin(index * 0.6) * 0.045, 0)
			if previousBase then
				b:fin({ previousBase, previousTip, tip, base }, membrane, 0.08)
				light(previousTip, tip, 0.009, violet, "DorsalRim")
			end
			previousBase, previousTip = base, tip
		end
		-- Two long rear streamers form a comet-shaped caudal fin.
		local tail = Vector3.new(-0.84, 0.063, 0)
		for _, sign in { -1, 1 } do
			local tip = Vector3.new(-1.12, 0.09 + sign * 0.13, sign * 0.035)
			local notch = Vector3.new(-0.95, 0.075 + sign * 0.028, sign * 0.012)
			b:fin({ tail, tip, notch }, membrane)
			light(tail, tip, 0.009, violet, "CometTail")
		end
		-- Armored body rings and paired bioluminescent nodes mark each curve.
		for index = 2, #spine - 1 do
			local node = spine[index]
			for _, side in { -1, 1 } do
				local surface = b:surface(node[1], node[2] + node[3] * 0.1, side)
				if surface then
					b:ellipsoid("SegmentPlate", CFrame.new(surface + Vector3.new(0, 0, side * 0.003)), Vector3.new(0.09, node[3] * 0.60, 0.015), plate)
					glow(b:ellipsoid("VoidNode", CFrame.new(surface + Vector3.new(0.005, 0, side * 0.013)), Vector3.new(0.027, 0.018, 0.012), violet))
				end
			end
		end
		-- Swept fins keep the silhouette recognizably aquatic.
		for _, side in { -1, 1 } do
			b:fin({ Vector3.new(0.28, 0.015, side * 0.075), Vector3.new(0.05, -0.14, side * 0.19), Vector3.new(0.17, -0.04, side * 0.09) }, membrane)
			light(Vector3.new(0.28, 0.015, side * 0.078), Vector3.new(0.05, -0.14, side * 0.19), 0.008, violet, "PectoralRim")
			-- Backward horns and curling whiskers grow from the broad eel head.
			local horn = Vector3.new(0.39, 0.11, side * 0.05)
			local bend = Vector3.new(0.34, 0.23, side * 0.07)
			b:limb(horn, bend, 0.024, plate, "Horn")
			light(bend, Vector3.new(0.20, 0.29, side * 0.09), 0.012, pale, "HornTip")
			local root = Vector3.new(0.52, 0.02, side * 0.045)
			local curl = Vector3.new(0.60, -0.035, side * 0.12)
			light(root, curl, 0.009, pale, "Whisker")
			light(curl, Vector3.new(0.49, -0.10, side * 0.17), 0.006, violet, "Whisker")
		end
		b:eye(0.46, 0.08, 0.037, pale)
		-- A narrow jaw line and two short crystal fangs avoid an angler silhouette.
		for _, side in { -1, 1 } do
			glow(b:mark(0.53, 0.025, side, 0.08, 0.009, violet, v2(1, 0)))
			light(Vector3.new(0.535, 0.025, side * 0.03), Vector3.new(0.54, -0.018, side * 0.035), 0.011, pale, "CrystalFang")
		end
		for _, part in b.model:GetDescendants() do
			if part:IsA("BasePart") and part.Name == "Eye" then glow(part) end
		end
	end,
}
