return function(kit)
	local P = kit.Palette
	local M = kit.Material
	local aqua = Color3.fromRGB(70, 200, 215)
	local glow = Color3.fromRGB(120, 235, 255)

	-- Dark plinth under the octagonal tub.
	kit.cylinder("Plinth", 5.6, 0.2, CFrame.new(0, 0.1, 0), P.DarkWood, M.WoodPlanks)

	-- Eight stave walls and eight rim boards around an octagon.
	for i = 0, 7 do
		local a = i * math.pi / 4
		local dir = Vector3.new(math.sin(a), 0, -math.cos(a))
		local wallPos = dir * 2.55 + Vector3.new(0, 1.25, 0)
		kit.block("Wall", Vector3.new(2.3, 2.1, 0.4), CFrame.lookAt(wallPos, Vector3.new(0, wallPos.Y, 0)), P.Teak, M.WoodPlanks)
		local rimPos = dir * 2.5 + Vector3.new(0, 2.4, 0)
		kit.block("Rim", Vector3.new(2.35, 0.2, 0.55), CFrame.lookAt(rimPos, Vector3.new(0, rimPos.Y, 0)), P.Wood, M.Wood)
	end


	-- Water surface with a glowing centre from the underwater lights.
	local water = kit.cylinder("Water", 4.8, 0.1, CFrame.new(0, 2.05, 0), aqua, M.Glass)
	kit.cylinder("WaterGlow", 2.6, 0.04, CFrame.new(0, 2.11, 0), glow, M.Neon)
	kit.light(water, glow, 12, 1.6)

	-- Underwater lamps peeking at the waterline on four staves.
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		local p = Vector3.new(math.sin(a), 0, -math.cos(a)) * 2.28 + Vector3.new(0, 2.08, 0)
		kit.ball("Lamp", 0.32, CFrame.new(p), glow, M.Neon)
	end

	-- Front step.
	kit.block("Step", Vector3.new(1.8, 0.5, 0.26), CFrame.new(0, 0.45, -2.86), P.Wood, M.WoodPlanks)

	-- Folded towel on the rim.
	kit.block("Towel", Vector3.new(0.9, 0.14, 0.5), CFrame.new(1.4, 2.57, 1.95) * CFrame.Angles(0, math.rad(-45), 0), P.White, M.Fabric)

	-- Low wisps of steam.
	kit.ball("Steam", 0.7, CFrame.new(-0.6, 2.2, 0.3), Color3.fromRGB(235, 245, 248), M.SmoothPlastic)
	kit.ball("Steam", 0.5, CFrame.new(0.5, 2.25, -0.5), Color3.fromRGB(235, 245, 248), M.SmoothPlastic)
	kit.ball("Steam", 0.4, CFrame.new(0.2, 2.35, 0.7), Color3.fromRGB(235, 245, 248), M.SmoothPlastic)
end
