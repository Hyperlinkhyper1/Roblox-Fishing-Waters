return function(kit)
	local P = kit.Palette
	local M = kit.Material

	-- Base plank and a raised plinth
	kit.block("Base", Vector3.new(1.8, 0.2, 1.4), CFrame.new(0, 0.1, 0), P.DarkWood, M.Wood)
	kit.block("Plinth", Vector3.new(1.5, 0.12, 1.0), CFrame.new(0, 0.26, 0), P.Teak, M.Wood)

	-- Uprights with corner braces
	for _, side in { -1, 1 } do
		kit.block("Post", Vector3.new(0.24, 3.5, 0.3), CFrame.new(side * 0.72, 2.07, 0), P.Wood, M.Wood)
		kit.wedge(
			"Brace",
			Vector3.new(0.18, 0.55, 0.4),
			CFrame.new(side * 0.4, 0.595, 0) * CFrame.Angles(0, side * math.pi / 2, 0),
			P.Wood,
			M.Wood
		)
		kit.wedge(
			"TopBrace",
			Vector3.new(0.18, 0.4, 0.3),
			CFrame.new(side * 0.45, 3.42, 0) * CFrame.Angles(math.pi, side * math.pi / 2, 0),
			P.Wood,
			M.Wood
		)
	end

	-- Crossbeam and cap
	kit.block("Crossbeam", Vector3.new(1.8, 0.3, 0.36), CFrame.new(0, 3.77, 0), P.DarkWood, M.Wood)
	kit.block("Cap", Vector3.new(1.8, 0.08, 0.46), CFrame.new(0, 3.96, 0), P.Teak, M.Wood)

	-- Brass hanger
	kit.block("Hanger", Vector3.new(0.34, 0.16, 0.26), CFrame.new(0, 3.54, 0), P.Brass, M.Metal)
	kit.cylinder("Yoke", 0.12, 0.2, CFrame.new(0, 3.38, 0), P.Iron, M.Metal)

	-- The bell: crown, shoulder, waist and flared lip
	kit.cylinder("Crown", 0.36, 0.14, CFrame.new(0, 3.24, 0), P.Brass, M.Metal)
	kit.ball("Shoulder", 0.66, CFrame.new(0, 3.0, 0), P.Brass, M.Metal)
	kit.cylinder("Waist", 0.7, 0.5, CFrame.new(0, 2.78, 0), P.Brass, M.Metal)
	kit.cylinder("Flare", 0.86, 0.16, CFrame.new(0, 2.47, 0), P.Brass, M.Metal)
	kit.cylinder("Lip", 0.98, 0.08, CFrame.new(0, 2.36, 0), P.Brass, M.Metal)
	kit.cylinder("Band", 0.74, 0.05, CFrame.new(0, 2.92, 0), Color3.fromRGB(170, 128, 50), M.Metal)

	-- Clapper and bell rope
	kit.ball("Clapper", 0.2, CFrame.new(0, 2.22, 0), P.Iron, M.Metal)
	kit.cylinder("BellRope", 0.08, 0.95, CFrame.new(0, 1.66, 0), P.Rope, M.Fabric)
	kit.ball("RopeKnot", 0.16, CFrame.new(0, 1.16, 0), P.Rope, M.Fabric)
	kit.cylinder("Tassel", 0.12, 0.22, CFrame.new(0, 0.98, 0), P.Red, M.Fabric)

	-- Name plate on the front of the plinth
	kit.block("Nameplate", Vector3.new(0.6, 0.1, 0.03), CFrame.new(0, 0.26, -0.515), P.Brass, M.Metal)
end
