return function(kit)
	local P = kit.Palette
	local M = kit.Material
	local oak = Color3.fromRGB(150, 98, 56)
	local hoop = Color3.fromRGB(52, 54, 58)

	-- bulging body from stacked staves sections
	local sections = {
		{ 1.42, 0.0, 0.42 },
		{ 1.6, 0.38, 0.98 },
		{ 1.72, 0.94, 2.06 },
		{ 1.6, 2.02, 2.6 },
		{ 1.42, 2.56, 2.96 },
	}
	for i, s in sections do
		local d, y0, y1 = s[1], s[2], s[3]
		kit.cylinder("Stave" .. i, d, y1 - y0, CFrame.new(0, (y0 + y1) / 2, 0), oak, M.WoodPlanks)
	end

	-- iron hoops
	for _, h in { { 1.5, 0.2 }, { 1.68, 0.92 }, { 1.68, 2.08 }, { 1.5, 2.76 } } do
		kit.cylinder("Hoop", h[1], 0.14, CFrame.new(0, h[2], 0), hoop, M.Metal)
	end

	-- lid with a bung and a lifting cleat
	kit.cylinder("Lid", 1.3, 0.04, CFrame.new(0, 2.98, 0), P.DarkWood, M.Wood)
	kit.cylinder("Bung", 0.26, 0.04, CFrame.new(0.38, 3.0, 0.3), P.Brass, M.Metal)
	kit.block("LidCleat", Vector3.new(0.7, 0.1, 0.14), CFrame.new(-0.1, 2.97, -0.1), P.Teak, M.Wood)

	-- brass tap on the front (-Z)
	local ty = 0.66
	kit.cylinder("TapFlange", 0.36, 0.06, CFrame.new(0, ty, -0.8) * CFrame.Angles(math.pi / 2, 0, 0), P.Brass, M.Metal)
	kit.cylinder("TapBody", 0.17, 0.18, CFrame.new(0, ty, -0.9) * CFrame.Angles(math.pi / 2, 0, 0), P.Brass, M.Metal)
	kit.cylinder("TapSpout", 0.1, 0.18, CFrame.new(0, ty - 0.1, -0.94), P.Brass, M.Metal)
	kit.block("TapLever", Vector3.new(0.34, 0.08, 0.08), CFrame.new(0, ty + 0.11, -0.92), P.Brass, M.Metal)
	kit.ball("TapKnob", 0.13, CFrame.new(0.17, ty + 0.11, -0.92), P.Red, M.SmoothPlastic)

	-- tin cup on a hook beside the tap
	kit.block("CupHook", Vector3.new(0.06, 0.16, 0.12), CFrame.new(-0.5, 1.25, -0.74), hoop, M.Metal)
	kit.cylinder("Cup", 0.24, 0.26, CFrame.new(-0.5, 1.08, -0.82), P.Steel, M.Metal)
end
