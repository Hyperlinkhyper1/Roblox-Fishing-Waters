return function(kit)
	local P = kit.Palette
	local M = kit.Material

	-- Foot and post
	kit.block("Foot", Vector3.new(1.2, 0.18, 0.76), CFrame.new(0, 0.09, 0), P.DarkWood, M.WoodPlanks)
	kit.block("Post", Vector3.new(0.3, 3.62, 0.3), CFrame.new(0, 1.99, 0.12), P.Teak, M.Wood)
	kit.block("Cap", Vector3.new(0.4, 0.14, 0.4), CFrame.new(0, 3.87, 0.12), P.DarkWood, M.Wood)
	kit.block("Peg", Vector3.new(0.1, 0.1, 0.34), CFrame.new(0, 3.34, -0.12), P.Brass, M.Metal)

	-- The ring: 12 segments in bands of two, red / white
	local cy, cz, r = 2.52, -0.17, 0.66
	local n = 12
	for i = 0, n - 1 do
		local t0 = i / n * math.pi * 2
		local t1 = (i + 1) / n * math.pi * 2
		local a = Vector3.new(math.cos(t0) * r, cy + math.sin(t0) * r, cz)
		local b = Vector3.new(math.cos(t1) * r, cy + math.sin(t1) * r, cz)
		local dir = (b - a).Unit * 0.03
		local color = (math.floor(i / 2) % 2 == 0) and P.Red or P.White
		kit.beam("Ring" .. i, a - dir, b + dir, 0.24, 0.24, color, M.SmoothPlastic)
	end

	-- Grab line looped over the peg
	kit.beam("Line", Vector3.new(-0.04, 3.32, -0.24), Vector3.new(-0.2, 3.12, -0.24), 0.05, 0.05, P.Rope, M.Fabric)
	kit.beam("Line2", Vector3.new(0.04, 3.32, -0.24), Vector3.new(0.2, 3.12, -0.24), 0.05, 0.05, P.Rope, M.Fabric)

	-- Small navy name plate under the ring
	kit.block("Plate", Vector3.new(0.5, 0.26, 0.04), CFrame.new(0, 1.3, -0.05), P.Navy, M.SmoothPlastic)
	kit.block("PlateStripe", Vector3.new(0.36, 0.05, 0.02), CFrame.new(0, 1.3, -0.08), P.Brass, M.Metal)
end
