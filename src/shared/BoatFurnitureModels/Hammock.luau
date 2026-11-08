return function(kit)
	local P = kit.Palette
	local M = kit.Material
	local stripeA = P.Canvas
	local stripeB = P.Teal

	-- Base rail and the two cross feet.
	kit.block("BaseRail", Vector3.new(6.4, 0.3, 0.4), CFrame.new(0, 0.15, 0), P.Teak, M.Wood)
	for _, s in { -1, 1 } do
		kit.block("Foot" .. (s < 0 and "L" or "R"), Vector3.new(0.45, 0.25, 2.5), CFrame.new(s * 2.9, 0.125, 0), P.DarkWood, M.Wood)
		for _, z in { -1, 1 } do
			kit.block("FootCap" .. s .. z, Vector3.new(0.5, 0.1, 0.3), CFrame.new(s * 2.9, 0.3, z * 1.05), P.Teak, M.Wood)
		end
	end

	-- Curved arms: three beam segments rising outward to each tip.
	local arc = {
		Vector3.new(2.6, 0.25, 0),
		Vector3.new(3.35, 1.25, 0),
		Vector3.new(3.75, 2.4, 0),
		Vector3.new(3.75, 3.35, 0),
	}
	for _, s in { -1, 1 } do
		for i = 1, 3 do
			local a = arc[i] * Vector3.new(s, 1, 1)
			local b = arc[i + 1] * Vector3.new(s, 1, 1)
			kit.beam("Arm" .. s .. i, a, b, 0.32, 0.32, P.Teak, M.Wood)
		end
	end

	-- Spreader bars and the ropes up to the arm tips.
	local tipY = 3.3
	local barX, barY = 2.75, 2.35
	for _, s in { -1, 1 } do
		kit.block("Spreader" .. s, Vector3.new(0.14, 0.14, 1.9), CFrame.new(s * barX, barY, 0), P.DarkWood, M.Wood)
		for _, z in { -0.85, 0.85 } do
			kit.beam("Rope" .. s .. z, Vector3.new(s * barX, barY, z), Vector3.new(s * 3.7, tipY, 0), 0.06, 0.06, P.Rope, M.Fabric)
		end
	end

	-- Sagging striped bed.
	local pts = {}
	local n = 6
	for i = 0, n do
		local t = i / n
		local x = -barX + t * barX * 2
		local y = barY - 1.05 * (1 - (2 * t - 1) ^ 2)
		pts[i] = Vector3.new(x, y, 0)
	end
	for i = 1, n do
		kit.beam("Bed" .. i, pts[i - 1], pts[i], 1.8, 0.1, i % 2 == 0 and stripeB or stripeA, M.Fabric)
	end

	-- A pillow at the left end.
	kit.block("Pillow", Vector3.new(0.7, 0.28, 1.2), CFrame.new(-1.95, 1.95, 0) * CFrame.Angles(0, 0, math.rad(-30)), P.White, M.Fabric)
end
