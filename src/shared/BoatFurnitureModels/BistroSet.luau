return function(kit)
	local P = kit.Palette
	local M = kit.Material
	local iron = Color3.fromRGB(38, 40, 44)

	-- Little round café table with a marble top.
	kit.cylinder("TableTop", 1.9, 0.1, CFrame.new(0, 2.35, 0), Color3.fromRGB(232, 228, 220), M.Marble)
	kit.cylinder("TableRim", 1.96, 0.06, CFrame.new(0, 2.28, 0), iron, M.Metal)
	kit.cylinder("TableColumn", 0.16, 2.2, CFrame.new(0, 1.15, 0), iron, M.Metal)
	kit.ball("TableKnot", 0.32, CFrame.new(0, 0.9, 0), iron, M.Metal)
	kit.cylinder("TableFoot", 1.0, 0.1, CFrame.new(0, 0.05, 0), iron, M.Metal)

	-- A tiny vase with a flower.
	kit.cylinder("Vase", 0.2, 0.3, CFrame.new(0.2, 2.55, 0.15), P.Teal, M.Glass)
	kit.ball("Flower", 0.22, CFrame.new(0.2, 2.8, 0.15), P.Red, M.SmoothPlastic)
	kit.cylinder("Saucer", 0.36, 0.03, CFrame.new(-0.35, 2.415, -0.2), P.White, M.SmoothPlastic)
	kit.cylinder("Cup", 0.2, 0.18, CFrame.new(-0.35, 2.52, -0.2), P.White, M.SmoothPlastic)

	-- Two matching chairs facing the table from left and right.
	local function chair(tag, s)
		local cx = 1.6 * s
		kit.cylinder(tag .. "Pan", 1.1, 0.08, CFrame.new(cx, 1.42, 0), iron, M.Metal)
		kit.cylinder(tag .. "Cushion", 1.0, 0.12, CFrame.new(cx, 1.52, 0), P.Red, M.Fabric)
		for i, c in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
			local top = Vector3.new(cx + c[1] * 0.3, 1.4, c[2] * 0.3)
			local foot = Vector3.new(cx + c[1] * 0.45, 0.02, c[2] * 0.45)
			kit.beam(tag .. "Leg" .. i, top, foot, 0.08, 0.08, iron, M.Metal)
		end
		-- Back on the outer side, leaning out slightly.
		local bx = cx + 0.48 * s
		kit.beam(tag .. "BackPostA", Vector3.new(bx, 1.45, -0.35), Vector3.new(bx + 0.1 * s, 3.1, -0.38), 0.08, 0.08, iron, M.Metal)
		kit.beam(tag .. "BackPostB", Vector3.new(bx, 1.45, 0.35), Vector3.new(bx + 0.1 * s, 3.1, 0.38), 0.08, 0.08, iron, M.Metal)
		kit.block(tag .. "BackRail", Vector3.new(0.1, 0.32, 0.86), CFrame.new(bx + 0.09 * s, 2.92, 0) * CFrame.Angles(0, 0, -0.06 * s), P.Red, M.SmoothPlastic)
		kit.block(tag .. "BackBand", Vector3.new(0.06, 0.08, 0.74), CFrame.new(bx + 0.05 * s, 2.3, 0), iron, M.Metal)
	end
	chair("Left", -1)
	chair("Right", 1)
end
