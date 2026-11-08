return function(kit)
	local P = kit.Palette
	local M = kit.Material
	local side = CFrame.Angles(0, 0, math.pi / 2) -- cylinder axis along X

	-- Wooden frame
	kit.block("Base", Vector3.new(3.6, 0.45, 1.1), CFrame.new(0, 0.225, 0), P.Teak, M.Wood)
	kit.block("BaseTrim", Vector3.new(3.3, 0.1, 0.9), CFrame.new(0, 0.5, 0), P.DarkWood, M.Wood)
	kit.block("PostLeft", Vector3.new(0.25, 4.0, 0.3), CFrame.new(-1.65, 2.45, 0.35), P.Teak, M.Wood)
	kit.block("PostRight", Vector3.new(0.25, 4.0, 0.3), CFrame.new(1.65, 2.45, 0.35), P.Teak, M.Wood)
	kit.block("HoldRail", Vector3.new(3.55, 0.22, 0.55), CFrame.new(0, 3.4, 0.1), P.Teak, M.Wood)
	kit.block("TopCap", Vector3.new(3.6, 0.14, 0.4), CFrame.new(0, 4.52, 0.35), P.DarkWood, M.Wood)
	kit.block("Plaque", Vector3.new(0.8, 0.22, 0.04), CFrame.new(0, 0.24, -0.57), P.Brass, M.Metal)

	-- Five rods standing in the rack
	local rods = {
		{ x = -1.2, tip = 4.95, blank = P.Navy, grip = P.Rope },
		{ x = -0.6, tip = 4.7, blank = P.Red, grip = P.Iron },
		{ x = 0, tip = 4.9, blank = P.Teal, grip = P.Rope },
		{ x = 0.6, tip = 4.65, blank = P.Green, grip = P.Iron },
		{ x = 1.2, tip = 4.85, blank = P.Brass, grip = P.Rope },
	}
	for i, r in rods do
		kit.cylinder("Grip" .. i, 0.2, 1.0, CFrame.new(r.x, 1.05, 0.1), r.grip, M.Fabric)
		kit.beam("Blank" .. i, Vector3.new(r.x, 1.55, 0.1), Vector3.new(r.x, r.tip, 0.1), 0.08, 0.08, r.blank, M.SmoothPlastic)
		kit.cylinder("Reel" .. i, 0.36, 0.16, CFrame.new(r.x, 1.75, -0.12) * side, P.Steel, M.Metal)
	end
end
