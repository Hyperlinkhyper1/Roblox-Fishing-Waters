return function(kit)
	local P = kit.Palette
	local M = kit.Material

	-- Timber plinth with a brass plaque
	kit.block("Plinth", Vector3.new(2.4, 0.46, 1.1), CFrame.new(0, 0.23, 0), P.Teak, M.WoodPlanks)
	kit.block("PlinthTop", Vector3.new(2.2, 0.14, 0.96), CFrame.new(0, 0.53, 0), P.DarkWood, M.Wood)
	kit.block("Plaque", Vector3.new(0.9, 0.22, 0.04), CFrame.new(0, 0.24, -0.56), P.Brass, M.Metal)

	local z = 0
	local th = 0.26 -- anchor thickness in Z

	-- Shank and crown
	kit.block("Shank", Vector3.new(0.26, 2.7, th), CFrame.new(0, 2.05, z), P.Iron, M.Metal)
	kit.ball("Crown", 0.42, CFrame.new(0, 0.82, z), P.Iron, M.Metal)

	-- Curved arms (two segments each side) ending in flukes
	for _, s in { -1, 1 } do
		local p0 = Vector3.new(0, 0.8, z)
		local p1 = Vector3.new(0.5 * s, 0.86, z)
		local p2 = Vector3.new(0.86 * s, 1.18, z)
		local p3 = Vector3.new(1.0 * s, 1.5, z)
		kit.beam("Arm" .. s .. "a", p0, p1 + (p1 - p0).Unit * 0.06, th, 0.24, P.Iron, M.Metal)
		kit.beam("Arm" .. s .. "b", p1, p2 + (p2 - p1).Unit * 0.04, th, 0.22, P.Iron, M.Metal)
		kit.beam("Fluke" .. s, p2, p3, th + 0.02, 0.42, P.Iron, M.Metal)
		kit.wedge(
			"FlukeTip" .. s,
			Vector3.new(th + 0.02, 0.2, 0.22),
			CFrame.lookAt(p3, p3 + (p3 - p2)) * CFrame.new(0, 0, -0.06) * CFrame.Angles(0, math.pi, 0),
			P.Iron,
			M.Metal
		)
	end

	-- Stock across the top with ball ends
	kit.block("Stock", Vector3.new(1.5, 0.2, 0.22), CFrame.new(0, 3.08, z), P.DarkWood, M.Wood)
	kit.ball("StockEndL", 0.28, CFrame.new(-0.78, 3.08, z), P.Brass, M.Metal)
	kit.ball("StockEndR", 0.28, CFrame.new(0.78, 3.08, z), P.Brass, M.Metal)

	-- Brass shackle ring on top
	local cy, rr = 3.64, 0.22
	for i = 0, 5 do
		local t0 = i / 6 * math.pi * 2
		local t1 = (i + 1) / 6 * math.pi * 2
		local a = Vector3.new(math.cos(t0) * rr, cy + math.sin(t0) * rr, z)
		local b = Vector3.new(math.cos(t1) * rr, cy + math.sin(t1) * rr, z)
		local d = (b - a).Unit * 0.02
		kit.beam("Eye" .. i, a - d, b + d, 0.1, 0.08, P.Brass, M.Metal)
	end

	-- Rope wrapped around the shank, then draped down to the plinth
	for i, y in { 1.55, 1.85, 2.15, 2.45 } do
		local tilt = (i % 2 == 0) and 0.22 or -0.22
		kit.block("Wrap" .. i, Vector3.new(0.4, 0.13, 0.4), CFrame.new(0, y, z) * CFrame.Angles(0, 0, tilt), P.Rope, M.Fabric)
	end
	kit.beam("Drape1", Vector3.new(0.12, 3.44, -0.16), Vector3.new(0.46, 2.75, -0.2), 0.11, 0.11, P.Rope, M.Fabric)
	kit.beam("Drape2", Vector3.new(0.46, 2.75, -0.2), Vector3.new(0.18, 2.5, -0.2), 0.11, 0.11, P.Rope, M.Fabric)
end
