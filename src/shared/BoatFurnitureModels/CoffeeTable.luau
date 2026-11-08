return function(kit)
	local P = kit.Palette
	local M = kit.Material

	-- Low top with a darker edge frame (surface at y 1.06, leaving room for drinks).
	kit.block("TopFrame", Vector3.new(3.6, 0.12, 2.2), CFrame.new(0, 0.95, 0), P.DarkWood, M.Wood)
	kit.block("TopPanel", Vector3.new(3.3, 0.06, 1.9), CFrame.new(0, 1.03, 0), P.Teak, M.WoodPlanks)
	kit.block("ApronFront", Vector3.new(3.0, 0.18, 0.08), CFrame.new(0, 0.8, -0.88), P.DarkWood, M.Wood)
	kit.block("ApronBack", Vector3.new(3.0, 0.18, 0.08), CFrame.new(0, 0.8, 0.88), P.DarkWood, M.Wood)

	-- Legs.
	for i, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		kit.block("Leg" .. i, Vector3.new(0.22, 0.89, 0.22), CFrame.new(c[1] * 1.6, 0.445, c[2] * 0.9), P.DarkWood, M.Wood)
	end

	-- Lower shelf.
	kit.block("Shelf", Vector3.new(3.2, 0.08, 1.8), CFrame.new(0, 0.22, 0), P.Teak, M.WoodPlanks)

	-- Tackle magazines on the shelf.
	kit.block("MagazineA", Vector3.new(0.75, 0.05, 1.0), CFrame.new(-0.8, 0.285, 0.1) * CFrame.Angles(0, 0.15, 0), P.Navy, M.SmoothPlastic)
	kit.block("MagazineB", Vector3.new(0.75, 0.05, 1.0), CFrame.new(-0.75, 0.335, 0.05) * CFrame.Angles(0, -0.2, 0), P.Red, M.SmoothPlastic)
	kit.block("MagazineC", Vector3.new(0.75, 0.05, 1.0), CFrame.new(-0.82, 0.385, 0.08) * CFrame.Angles(0, 0.05, 0), P.Cream, M.SmoothPlastic)
	-- Tackle box.
	kit.block("TackleBox", Vector3.new(0.9, 0.3, 0.55), CFrame.new(0.75, 0.41, 0.1), P.Green, M.SmoothPlastic)
	kit.block("TackleLid", Vector3.new(0.94, 0.07, 0.59), CFrame.new(0.75, 0.595, 0.1), Color3.fromRGB(52, 104, 56), M.SmoothPlastic)
	kit.block("TackleHandle", Vector3.new(0.3, 0.05, 0.08), CFrame.new(0.75, 0.655, 0.1), P.Steel, M.Metal)

	-- Drinks and a magazine on top.
	kit.cylinder("Mug", 0.28, 0.27, CFrame.new(0.9, 1.195, -0.35), P.White, M.SmoothPlastic)
	kit.cylinder("Coffee", 0.22, 0.02, CFrame.new(0.9, 1.325, -0.35), Color3.fromRGB(70, 42, 24), M.SmoothPlastic)
	kit.block("MugHandle", Vector3.new(0.08, 0.15, 0.05), CFrame.new(1.08, 1.2, -0.35), P.White, M.SmoothPlastic)
	kit.block("TopMagazine", Vector3.new(0.8, 0.04, 1.05), CFrame.new(-0.7, 1.08, 0.05) * CFrame.Angles(0, -0.25, 0), P.Teal, M.SmoothPlastic)
	kit.cylinder("Bottle", 0.18, 0.3, CFrame.new(0.35, 1.21, 0.45), Color3.fromRGB(60, 120, 70), M.Glass)
	kit.cylinder("BottleNeck", 0.08, 0.04, CFrame.new(0.35, 1.38, 0.45), Color3.fromRGB(60, 120, 70), M.Glass)
end
