return function(kit)
	local P = kit.Palette
	local M = kit.Material

	-- Weighted base.
	kit.cylinder("BaseWeight", 1.4, 0.3, CFrame.new(0, 0.15, 0), P.Stone, M.Concrete)
	kit.cylinder("BaseCap", 0.9, 0.2, CFrame.new(0, 0.4, 0), P.Iron, M.Metal)
	kit.cylinder("BaseCollar", 0.3, 0.4, CFrame.new(0, 0.7, 0), P.Iron, M.Metal)

	-- Pole with a crank.
	kit.cylinder("Pole", 0.16, 5.5, CFrame.new(0, 0.5 + 2.75, 0), P.White, M.SmoothPlastic)
	kit.cylinder("PoleJoint", 0.26, 0.2, CFrame.new(0, 3.0, 0), P.Steel, M.Metal)
	kit.block("Crank", Vector3.new(0.35, 0.06, 0.06), CFrame.new(0.2, 3.0, 0), P.Steel, M.Metal)

	-- Striped octagonal canopy: each slice is two flat right-triangle wedges
	-- (apex -> edge midpoint -> corner), so the stripes meet cleanly.
	local panels = 8
	local apothem = 2.4
	local drop = 0.95
	local topY = 5.72
	local half = apothem * math.tan(math.pi / panels)
	local thick = 0.08
	local apex = Vector3.new(0, topY, 0)
	for i = 0, panels - 1 do
		local th = i * 2 * math.pi / panels
		local u = Vector3.new(math.cos(th), 0, math.sin(th))
		local w = Vector3.new(-math.sin(th), 0, math.cos(th))
		local mid = u * apothem + Vector3.new(0, topY - drop, 0)
		local z = (mid - apex).Unit
		local len = (mid - apex).Magnitude
		for _, s in { -1, 1 } do
			local y = w * s
			local x = y:Cross(z)
			local c = apex + y * (half / 2) + z * (len / 2) + Vector3.new(0, -thick / 2, 0)
			kit.wedge(
				"Canopy" .. i .. (s < 0 and "a" or "b"),
				Vector3.new(thick, half, len),
				CFrame.new(c.X, c.Y, c.Z, x.X, y.X, z.X, x.Y, y.Y, z.Y, x.Z, y.Z, z.Z),
				i % 2 == 0 and P.Red or P.White,
				M.Fabric
			)
		end
	end
	kit.cylinder("Hub", 0.4, 0.2, CFrame.new(0, topY - drop - 0.05, 0), P.Steel, M.Metal)
	kit.ball("Finial", 0.25, CFrame.new(0, 5.86, 0), P.Brass, M.Metal)
end
