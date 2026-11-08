return function(kit)
	local P = kit.Palette
	local M = kit.Material
	local chrome = Color3.fromRGB(205, 210, 220)
	local body = Color3.fromRGB(120, 30, 40)
	local neonPink = Color3.fromRGB(255, 80, 170)
	local neonAmber = Color3.fromRGB(255, 170, 60)

	-- Base and cabinet with a rounded (arched) top.
	kit.block("Plinth", Vector3.new(2.2, 0.2, 1.6), CFrame.new(0, 0.1, 0), chrome, M.Metal)
	kit.block("Cabinet", Vector3.new(2.0, 3.2, 1.3), CFrame.new(0, 1.8, 0), body, M.Wood)
	kit.cylinder("Crown", 2.0, 1.3, CFrame.new(0, 3.4, 0) * CFrame.Angles(math.pi / 2, 0, 0), body, M.Wood)

	-- Neon arch ring and the record window inside it.
	local arch = kit.cylinder("Arch", 2.0, 0.08, CFrame.new(0, 3.4, -0.69) * CFrame.Angles(math.pi / 2, 0, 0), neonPink, M.Neon)
	kit.light(arch, neonPink, 10, 1.4)
	kit.cylinder("Window", 1.5, 0.03, CFrame.new(0, 3.4, -0.745) * CFrame.Angles(math.pi / 2, 0, 0), Color3.fromRGB(40, 50, 70), M.Glass)
	kit.cylinder("Record", 0.74, 0.02, CFrame.new(0, 3.74, -0.77) * CFrame.Angles(math.pi / 2, 0, 0), Color3.fromRGB(20, 20, 24), M.SmoothPlastic)
	kit.cylinder("Label", 0.24, 0.01, CFrame.new(0, 3.74, -0.785) * CFrame.Angles(math.pi / 2, 0, 0), P.Red, M.SmoothPlastic)

	-- Front panel hides the lower half of the arch so the top reads as a dome.
	kit.block("FrontPanel", Vector3.new(2.2, 3.2, 0.1), CFrame.new(0, 1.8, -0.75), body, M.Wood)
	kit.block("Trim", Vector3.new(2.2, 0.08, 0.12), CFrame.new(0, 3.38, -0.75), chrome, M.Metal)

	-- Neon side tubes.
	kit.cylinder("Tube", 0.12, 3.0, CFrame.new(-0.98, 1.85, -0.795), neonAmber, M.Neon)
	kit.cylinder("Tube", 0.12, 3.0, CFrame.new(0.98, 1.85, -0.795), neonAmber, M.Neon)

	-- Song selector panel with buttons.
	kit.block("Selector", Vector3.new(1.4, 0.6, 0.03), CFrame.new(0, 2.75, -0.815), P.Cream, M.SmoothPlastic)
	local buttonColors = { P.Red, neonAmber, P.Teal, P.Green, neonPink }
	for i, c in ipairs(buttonColors) do
		kit.block("Button", Vector3.new(0.18, 0.14, 0.02), CFrame.new(-0.5 + (i - 1) * 0.25, 2.62, -0.84), c, M.SmoothPlastic)
	end
	kit.block("TitleStrip", Vector3.new(1.1, 0.16, 0.02), CFrame.new(0, 2.88, -0.84), neonAmber, M.Neon)

	-- Chrome speaker grille with bars.
	kit.block("Grille", Vector3.new(1.4, 1.2, 0.03), CFrame.new(0, 1.2, -0.815), Color3.fromRGB(45, 40, 45), M.Fabric)
	for i = 0, 3 do
		kit.block("GrilleBar", Vector3.new(1.4, 0.07, 0.02), CFrame.new(0, 0.75 + i * 0.3, -0.84), chrome, M.Metal)
	end
	kit.block("CoinSlot", Vector3.new(0.3, 0.12, 0.02), CFrame.new(0, 2.15, -0.81), chrome, M.Metal)
end
