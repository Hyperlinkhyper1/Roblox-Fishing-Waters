return function(kit)
	local P = kit.Palette
	local M = kit.Material
	local enamel = Color3.fromRGB(32, 32, 36)
	local zc = -0.12 -- bowl centre sits a touch forward so the open lid has room behind
	local rimY = 1.7

	-- Three splayed legs with little feet, plus the ash tray between them.
	for i = 0, 2 do
		local a = math.rad(90 + i * 120)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local top = Vector3.new(0, 1.1, zc) + dir * 0.45
		local foot = Vector3.new(0, 0.08, zc) + dir * 0.85
		kit.beam("GrillLeg" .. i, top, foot, 0.12, 0.12, P.Steel, M.Metal)
		kit.cylinder("GrillFoot" .. i, 0.26, 0.16, CFrame.new(foot.X, 0.08, foot.Z), enamel, M.SmoothPlastic)
	end
	kit.cylinder("AshTray", 1.0, 0.06, CFrame.new(0, 0.45, zc), P.Steel, M.Metal)

	-- Rounded kettle bowl from stacked discs.
	kit.cylinder("KettleBase", 0.9, 0.22, CFrame.new(0, rimY - 0.63, zc), enamel, M.SmoothPlastic)
	kit.cylinder("KettleLow", 1.45, 0.25, CFrame.new(0, rimY - 0.45, zc), enamel, M.SmoothPlastic)
	kit.cylinder("KettleMid", 1.75, 0.25, CFrame.new(0, rimY - 0.25, zc), enamel, M.SmoothPlastic)
	kit.cylinder("KettleRim", 1.85, 0.18, CFrame.new(0, rimY - 0.09, zc), enamel, M.SmoothPlastic)

	-- Glowing coals and the cooking grate.
	local coals = kit.cylinder("Coals", 1.6, 0.06, CFrame.new(0, rimY - 0.12, zc), P.Flame, M.Neon)
	kit.light(coals, Color3.fromRGB(255, 130, 50), 10, 1.4)
	kit.fire(coals, P.Flame, 1)
	for i = -2, 2 do
		local half = math.sqrt(math.max(0.85 ^ 2 - (i * 0.32) ^ 2, 0.05))
		kit.block("GrateBar" .. i, Vector3.new(0.05, 0.05, half * 2), CFrame.new(i * 0.32, rimY + 0.02, zc), P.Steel, M.Metal)
	end
	kit.block("Sausage", Vector3.new(0.5, 0.14, 0.14), CFrame.new(-0.15, rimY + 0.11, zc - 0.25), Color3.fromRGB(150, 70, 45), M.SmoothPlastic)
	kit.block("Burger", Vector3.new(0.38, 0.1, 0.38), CFrame.new(0.3, rimY + 0.09, zc + 0.15), Color3.fromRGB(95, 55, 35), M.SmoothPlastic)

	-- Domed lid propped open on a back hinge.
	local hingeZ = zc + 0.9
	local lid = CFrame.new(0, rimY, hingeZ) * CFrame.Angles(math.rad(55), 0, 0) * CFrame.new(0, 0, -0.9)
	kit.cylinder("LidRim", 1.85, 0.16, lid * CFrame.new(0, 0.08, 0), enamel, M.SmoothPlastic)
	kit.cylinder("LidMid", 1.5, 0.22, lid * CFrame.new(0, 0.27, 0), enamel, M.SmoothPlastic)
	kit.cylinder("LidTop", 0.95, 0.16, lid * CFrame.new(0, 0.45, 0), enamel, M.SmoothPlastic)
	kit.cylinder("LidVent", 0.35, 0.06, lid * CFrame.new(0, 0.55, 0), P.Steel, M.Metal)
	kit.block("LidHandle", Vector3.new(0.5, 0.1, 0.12), lid * CFrame.new(0, 0.5, -0.7), P.DarkWood, M.Wood)

	-- Front handle on the bowl.
	kit.block("KettleHandle", Vector3.new(0.6, 0.1, 0.12), CFrame.new(0, rimY - 0.2, zc - 0.98), P.DarkWood, M.Wood)
end
