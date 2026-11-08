return function(kit)
	local P = kit.Palette
	local M = kit.Material

	local paint = Color3.fromRGB(58, 120, 128)
	local soil = Color3.fromRGB(70, 48, 32)

	-- Little feet
	kit.block("BoxFootLeft", Vector3.new(0.3, 0.12, 1.1), CFrame.new(-1.45, 0.06, 0), P.DarkWood, M.Wood)
	kit.block("BoxFootRight", Vector3.new(0.3, 0.12, 1.1), CFrame.new(1.45, 0.06, 0), P.DarkWood, M.Wood)

	-- Window box body
	kit.block("BoxFront", Vector3.new(3.5, 0.72, 0.12), CFrame.new(0, 0.48, -0.6), paint, M.WoodPlanks)
	kit.block("BoxBack", Vector3.new(3.5, 0.72, 0.12), CFrame.new(0, 0.48, 0.6), paint, M.WoodPlanks)
	kit.block("BoxEndLeft", Vector3.new(0.12, 0.72, 1.08), CFrame.new(-1.69, 0.48, 0), paint, M.WoodPlanks)
	kit.block("BoxEndRight", Vector3.new(0.12, 0.72, 1.08), CFrame.new(1.69, 0.48, 0), paint, M.WoodPlanks)
	kit.block("BoxTrim", Vector3.new(3.58, 0.1, 0.16), CFrame.new(0, 0.86, -0.62), P.Cream, M.Wood)
	kit.block("BoxSoil", Vector3.new(3.28, 0.1, 1.08), CFrame.new(0, 0.74, 0), soil, M.Grass)

	-- Basil: big round leaves
	local basil = Color3.fromRGB(84, 168, 64)
	kit.ball("Basil1", 0.55, CFrame.new(-1.25, 1.0, -0.1), basil, M.LeafyGrass)
	kit.ball("Basil2", 0.45, CFrame.new(-0.95, 1.08, 0.18), basil, M.LeafyGrass)
	kit.ball("Basil3", 0.4, CFrame.new(-1.3, 1.25, 0.2), Color3.fromRGB(104, 184, 76), M.LeafyGrass)

	-- Rosemary: thin dark upright sprigs
	local rosemary = Color3.fromRGB(56, 96, 70)
	local sprigs = {
		{ Vector3.new(-0.55, 0.78, 0), Vector3.new(-0.68, 1.5, -0.15) },
		{ Vector3.new(-0.45, 0.78, 0.1), Vector3.new(-0.42, 1.55, 0.2) },
		{ Vector3.new(-0.35, 0.78, -0.05), Vector3.new(-0.15, 1.4, -0.2) },
		{ Vector3.new(-0.5, 0.78, -0.1), Vector3.new(-0.3, 1.3, 0.3) },
	}
	for i, s in sprigs do
		kit.beam("Rosemary" .. i, s[1], s[2], 0.12, 0.12, rosemary, M.LeafyGrass)
	end

	-- Chives with purple flower heads
	local chive = Color3.fromRGB(74, 150, 60)
	local stalks = {
		Vector3.new(0.3, 0, -0.15),
		Vector3.new(0.45, 0, 0.12),
		Vector3.new(0.6, 0, -0.1),
		Vector3.new(0.75, 0, 0.15),
	}
	for i, s in stalks do
		local h = 0.55 + (i % 2) * 0.15
		kit.cylinder("Chive" .. i, 0.07, h, CFrame.new(s.X, 0.78 + h / 2, s.Z), chive, M.Grass)
	end
	local lilac = Color3.fromRGB(170, 110, 200)
	kit.ball("ChiveFlower1", 0.2, CFrame.new(0.3, 1.41, -0.15), lilac, M.Fabric)
	kit.ball("ChiveFlower2", 0.2, CFrame.new(0.6, 1.41, -0.1), lilac, M.Fabric)

	-- Parsley: frilly dark mound
	local parsley = Color3.fromRGB(46, 128, 52)
	kit.ball("Parsley1", 0.45, CFrame.new(1.2, 0.98, -0.12), parsley, M.Grass)
	kit.ball("Parsley2", 0.4, CFrame.new(1.42, 1.02, 0.15), parsley, M.Grass)
	kit.ball("Parsley3", 0.35, CFrame.new(1.05, 1.08, 0.2), Color3.fromRGB(60, 140, 60), M.Grass)
end
