return function(kit)
	local P = kit.Palette
	local M = kit.Material

	-- Stone pad on the deck.
	kit.cylinder("Pad", 3.0, 0.12, CFrame.new(0, 0.06, 0), P.Stone, M.Slate)

	-- Ring of eight stones, alternating shade and height.
	for i = 0, 7 do
		local a = i * math.pi / 4 + math.pi / 8
		local h = (i % 2 == 0) and 0.62 or 0.52
		local p = Vector3.new(math.cos(a) * 1.18, 0.12 + h / 2, math.sin(a) * 1.18)
		local color = (i % 2 == 0) and Color3.fromRGB(125, 120, 112) or Color3.fromRGB(95, 92, 88)
		kit.block("Stone", Vector3.new(0.92, h, 0.5), CFrame.lookAt(p, Vector3.new(0, p.Y, 0)), color, M.Cobblestone)
	end

	-- Iron fire bowl inside the ring.
	kit.cylinder("Basin", 1.75, 0.4, CFrame.new(0, 0.32, 0), P.Iron, M.Metal)
	kit.cylinder("BasinRim", 1.85, 0.08, CFrame.new(0, 0.54, 0), Color3.fromRGB(60, 58, 60), M.Metal)

	-- Glowing embers and a few coals.
	local embers = kit.cylinder("Embers", 1.5, 0.08, CFrame.new(0, 0.56, 0), P.Flame, M.Neon)
	kit.light(embers, P.Flame, 12, 2)
	kit.fire(embers, P.Flame, 2.5)
	kit.ball("Coal", 0.3, CFrame.new(0.45, 0.62, 0.2), Color3.fromRGB(35, 30, 30), M.Basalt)
	kit.ball("Coal", 0.26, CFrame.new(-0.4, 0.62, 0.35), Color3.fromRGB(35, 30, 30), M.Basalt)
	kit.ball("Coal", 0.28, CFrame.new(-0.1, 0.62, -0.5), Color3.fromRGB(35, 30, 30), M.Basalt)

	-- Teepee of four logs.
	local apex = Vector3.new(0, 1.35, 0)
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		local foot = Vector3.new(math.cos(a) * 0.62, 0.62, math.sin(a) * 0.62)
		kit.beam("Log", foot, apex, 0.2, 0.2, P.DarkWood, M.Wood)
	end
end
