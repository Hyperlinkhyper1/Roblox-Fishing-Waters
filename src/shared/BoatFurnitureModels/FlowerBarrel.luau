return function(kit)
	local P = kit.Palette
	local M = kit.Material

	-- Half barrel with iron hoops
	kit.cylinder("BarrelBody", 1.85, 1.15, CFrame.new(0, 0.575, 0), P.Wood, M.WoodPlanks)
	kit.cylinder("BarrelHoopLow", 1.94, 0.12, CFrame.new(0, 0.22, 0), P.Iron, M.Metal)
	kit.cylinder("BarrelHoopHigh", 1.94, 0.12, CFrame.new(0, 0.95, 0), P.Iron, M.Metal)
	kit.cylinder("BarrelRim", 1.9, 0.08, CFrame.new(0, 1.15, 0), P.DarkWood, M.Wood)

	-- Foliage mound spilling over the rim
	kit.ball("Foliage", 1.45, CFrame.new(0, 1.22, 0), P.Green, M.LeafyGrass)
	local crown = Vector3.new(0.05, 1.75, 0.05)
	kit.ball("FoliageTop", 0.9, CFrame.new(crown), P.Leaf, M.LeafyGrass)

	local red = Color3.fromRGB(220, 50, 60)
	local yellow = Color3.fromRGB(250, 205, 60)
	local pink = Color3.fromRGB(240, 120, 180)
	local white = Color3.fromRGB(246, 244, 236)
	local purple = Color3.fromRGB(150, 90, 200)
	local orange = Color3.fromRGB(250, 140, 50)
	local colors = { red, yellow, pink, white, purple, orange }

	-- Ring of blooms around and over the rim (some drooping down the side)
	local ring = 9
	for i = 1, ring do
		local ang = (i - 1) / ring * math.pi * 2 + 0.2
		local y = 1.28 + ((i % 3) - 1) * 0.1
		local cf = CFrame.new(math.cos(ang) * 0.8, y, math.sin(ang) * 0.8)
		kit.ball("Bloom" .. i, 0.38, cf, colors[(i - 1) % #colors + 1], M.Fabric)
	end

	-- Blooms sitting on the crown of the mound
	local topColors = { pink, white, red, yellow, purple }
	for i = 1, 5 do
		local ang = (i - 1) / 5 * math.pi * 2 + 0.9
		local elev = if i % 2 == 0 then 0.75 else 0.35
		local dir = Vector3.new(math.cos(ang) * math.cos(elev), math.sin(elev), math.sin(ang) * math.cos(elev))
		kit.ball("TopBloom" .. i, 0.34, CFrame.new(crown + dir * 0.47), topColors[i], M.Fabric)
	end

	-- Two tall daisies poking up
	local stem = Color3.fromRGB(70, 130, 60)
	local tall = {
		{ Vector3.new(-0.15, 2.0, -0.1), Vector3.new(-0.3, 2.42, -0.25), yellow },
		{ Vector3.new(0.25, 2.0, 0.05), Vector3.new(0.38, 2.38, -0.05), pink },
	}
	for i, t in tall do
		kit.beam("TallStem" .. i, t[1], t[2], 0.06, 0.06, stem, M.Grass)
		local head = CFrame.new(t[2] + Vector3.new(0, 0.04, 0)) * CFrame.Angles(-0.35, 0, 0)
		kit.cylinder("TallPetals" .. i, 0.4, 0.06, head, t[3], M.Fabric)
		kit.ball("TallCentre" .. i, 0.14, head * CFrame.new(0, 0.05, 0), Color3.fromRGB(120, 72, 30), M.SmoothPlastic)
	end
end
