return function(kit)
	local P = kit.Palette
	local M = kit.Material

	-- Tripod: three legs from a collar down to brass-capped feet
	local apex = Vector3.new(0, 2.8, 0)
	for i = 0, 2 do
		local a = math.rad(i * 120)
		local foot = Vector3.new(math.sin(a) * 0.92, 0.04, math.cos(a) * 0.92)
		local top = apex + Vector3.new(math.sin(a) * 0.12, 0, math.cos(a) * 0.12)
		kit.beam("Leg", top, foot, 0.12, 0.12, P.Wood, M.Wood)
		kit.ball("Foot", 0.16, CFrame.new(foot.X, 0.08, foot.Z), P.Brass, M.Metal)
		local mid = top:Lerp(foot, 0.45)
		kit.beam("LegClamp", mid + (top - foot).Unit * 0.06, mid - (top - foot).Unit * 0.06, 0.17, 0.17, P.Brass, M.Metal)
	end
	kit.cylinder("Collar", 0.46, 0.22, CFrame.new(0, 2.84, 0), P.DarkWood, M.Wood)
	kit.cylinder("Hub", 0.3, 0.2, CFrame.new(0, 3.04, 0), P.Brass, M.Metal)

	-- Yoke and pivot
	local pivot = Vector3.new(0, 3.32, 0.05)
	for _, side in { -1, 1 } do
		kit.block("Yoke", Vector3.new(0.06, 0.34, 0.24), CFrame.new(side * 0.22, 3.25, 0.05), P.Brass, M.Metal)
	end
	kit.cylinder("Pivot", 0.1, 0.56, CFrame.new(pivot) * CFrame.Angles(0, 0, math.pi / 2), P.Iron, M.Metal)

	-- The spyglass, tilted up toward the horizon at the front (-Z)
	local tilt = math.rad(12)
	local dir = Vector3.new(0, math.sin(tilt), -math.cos(tilt))
	local rot = CFrame.Angles(tilt - math.pi / 2, 0, 0)
	local function tube(name, d, length, t, color, material)
		kit.cylinder(name, d, length, CFrame.new(pivot + dir * t) * rot, color, material)
	end
	tube("Objective", 0.42, 0.16, 0.94, P.Brass, M.Metal)
	tube("Lens", 0.32, 0.02, 1.02, Color3.fromRGB(120, 180, 210), M.Glass)
	tube("Barrel", 0.34, 1.0, 0.36, P.Navy, M.SmoothPlastic)
	tube("BarrelBand", 0.38, 0.08, 0.02, P.Brass, M.Metal)
	tube("BarrelBand", 0.38, 0.08, 0.7, P.Brass, M.Metal)
	tube("DrawTube", 0.26, 0.5, -0.38, P.Brass, M.Metal)
	tube("DrawRing", 0.3, 0.06, -0.62, Color3.fromRGB(170, 128, 50), M.Metal)
	tube("Eyepiece", 0.18, 0.3, -0.8, P.Brass, M.Metal)
	tube("Eyecup", 0.22, 0.08, -0.97, P.Iron, M.Metal)
end
