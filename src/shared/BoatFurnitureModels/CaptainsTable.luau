return function(kit)
	local P = kit.Palette
	local M = kit.Material
	local varnish = Color3.fromRGB(122, 74, 40)

	-- Top: varnished round slab with a brass edge band.
	kit.cylinder("Tabletop", 3.9, 0.18, CFrame.new(0, 2.61, 0), varnish, M.Wood)
	kit.cylinder("TopBand", 3.96, 0.08, CFrame.new(0, 2.5, 0), P.Brass, M.Metal)
	kit.cylinder("Apron", 3.2, 0.14, CFrame.new(0, 2.4, 0), P.DarkWood, M.Wood)

	-- Chart pinned on top, slightly askew.
	local chartFrame = CFrame.new(0.05, 2.715, 0.05) * CFrame.Angles(0, math.rad(12), 0)
	kit.block("Chart", Vector3.new(2.2, 0.03, 1.5), chartFrame, P.Cream, M.SmoothPlastic)
	kit.block("ChartSea", Vector3.new(1.0, 0.012, 1.3), chartFrame * CFrame.new(-0.5, 0.02, 0), Color3.fromRGB(150, 196, 214), M.SmoothPlastic)
	kit.block("ChartIsle", Vector3.new(0.4, 0.016, 0.3), chartFrame * CFrame.new(0.55, 0.022, 0.3), Color3.fromRGB(198, 178, 120), M.SmoothPlastic)
	kit.beam("ChartRouteA", (chartFrame * CFrame.new(-0.8, 0.035, -0.45)).Position, (chartFrame * CFrame.new(-0.05, 0.035, 0.05)).Position, 0.04, 0.012, P.Red, M.SmoothPlastic)
	kit.beam("ChartRouteB", (chartFrame * CFrame.new(-0.05, 0.035, 0.05)).Position, (chartFrame * CFrame.new(0.5, 0.035, 0.3)).Position, 0.04, 0.012, P.Red, M.SmoothPlastic)
	for i, c in { { -1.02, -0.67 }, { 1.02, -0.67 }, { -1.02, 0.67 }, { 1.02, 0.67 } } do
		kit.ball("ChartPin" .. i, 0.12, chartFrame * CFrame.new(c[1], 0.04, c[2]), P.Brass, M.Metal)
	end
	-- Brass dividers lying beside the chart.
	kit.beam("DividerA", Vector3.new(-1.1, 2.73, -0.95), Vector3.new(-0.55, 2.73, -1.35), 0.05, 0.03, P.Brass, M.Metal)
	kit.beam("DividerB", Vector3.new(-1.1, 2.73, -0.95), Vector3.new(-0.45, 2.73, -1.15), 0.05, 0.03, P.Brass, M.Metal)

	-- Heavy turned pedestal.
	kit.cylinder("PedestalCollar", 0.9, 0.2, CFrame.new(0, 2.25, 0), P.DarkWood, M.Wood)
	kit.cylinder("PedestalColumn", 0.55, 1.75, CFrame.new(0, 1.3, 0), varnish, M.Wood)
	kit.ball("PedestalBulb", 0.95, CFrame.new(0, 1.0, 0), varnish, M.Wood)
	kit.cylinder("PedestalRing", 0.7, 0.1, CFrame.new(0, 1.65, 0), P.Brass, M.Metal)
	kit.cylinder("PedestalBase", 1.15, 0.45, CFrame.new(0, 0.42, 0), P.DarkWood, M.Wood)

	-- Four splayed claw feet.
	for i = 1, 4 do
		local yaw = CFrame.Angles(0, math.rad(45 + 90 * (i - 1)), 0)
		kit.block("Foot" .. i, Vector3.new(0.38, 0.32, 1.25), yaw * CFrame.new(0, 0.2, -0.95), P.DarkWood, M.Wood)
		kit.ball("FootToe" .. i, 0.3, yaw * CFrame.new(0, 0.15, -1.55), P.Brass, M.Metal)
	end
end
