return function(kit)
	local P = kit.Palette
	local M = kit.Material
	local side = CFrame.Angles(0, 0, math.pi / 2) -- cylinder axis along X
	local fwd = CFrame.Angles(math.pi / 2, 0, 0) -- cylinder axis along Z
	local body = Color3.fromRGB(40, 120, 170)

	-- Feet and body
	for i, p in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		kit.block("Foot" .. i, Vector3.new(0.3, 0.1, 0.3), CFrame.new(1.0 * p[1], 0.05, 0.55 * p[2]), P.Iron, M.SmoothPlastic)
	end
	kit.block("Body", Vector3.new(2.5, 1.2, 1.5), CFrame.new(0, 0.7, 0), body, M.SmoothPlastic)
	kit.block("Band", Vector3.new(2.52, 0.1, 1.52), CFrame.new(0, 1.22, 0), P.White, M.SmoothPlastic)

	-- Lid
	kit.block("Lid", Vector3.new(2.6, 0.26, 1.6), CFrame.new(0, 1.43, 0), P.White, M.SmoothPlastic)
	kit.block("LidTop", Vector3.new(2.3, 0.08, 1.3), CFrame.new(0, 1.6, 0), P.White, M.SmoothPlastic)
	kit.cylinder("CupLeft", 0.32, 0.03, CFrame.new(-0.85, 1.645, 0.3), P.Iron, M.SmoothPlastic)
	kit.cylinder("CupRight", 0.32, 0.03, CFrame.new(0.85, 1.645, 0.3), P.Iron, M.SmoothPlastic)

	-- Carry handle across the lid
	kit.block("HandlePivotLeft", Vector3.new(0.16, 0.14, 0.24), CFrame.new(-0.7, 1.71, -0.25), P.Iron, M.SmoothPlastic)
	kit.block("HandlePivotRight", Vector3.new(0.16, 0.14, 0.24), CFrame.new(0.7, 1.71, -0.25), P.Iron, M.SmoothPlastic)
	kit.block("Handle", Vector3.new(1.56, 0.1, 0.2), CFrame.new(0, 1.74, -0.25), P.Iron, M.SmoothPlastic)

	-- Latches, hinges, side grips, drain plug
	kit.block("LatchLeft", Vector3.new(0.3, 0.36, 0.08), CFrame.new(-0.8, 1.3, -0.82), P.White, M.SmoothPlastic)
	kit.block("LatchRight", Vector3.new(0.3, 0.36, 0.08), CFrame.new(0.8, 1.3, -0.82), P.White, M.SmoothPlastic)
	kit.cylinder("Hinge", 0.12, 2.0, CFrame.new(0, 1.3, 0.76) * side, P.Steel, M.Metal)
	kit.block("GripLeft", Vector3.new(0.05, 0.16, 0.7), CFrame.new(-1.27, 1.0, 0), P.White, M.SmoothPlastic)
	kit.block("GripRight", Vector3.new(0.05, 0.16, 0.7), CFrame.new(1.27, 1.0, 0), P.White, M.SmoothPlastic)
	kit.cylinder("DrainPlug", 0.16, 0.08, CFrame.new(0.95, 0.28, -0.77) * fwd, P.White, M.SmoothPlastic)
	kit.block("Label", Vector3.new(0.8, 0.3, 0.03), CFrame.new(0, 0.7, -0.765), P.White, M.SmoothPlastic)
end
