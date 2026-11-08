return function(kit)
	local P = kit.Palette
	local M = kit.Material

	-- Plinth and pedestal
	kit.block("Plinth", Vector3.new(1.3, 0.2, 1.3), CFrame.new(0, 0.1, 0), P.DarkWood, M.Wood)
	kit.cylinder("Foot", 1.0, 0.22, CFrame.new(0, 0.31, 0), P.Teak, M.Wood)
	kit.cylinder("FootRing", 0.82, 0.12, CFrame.new(0, 0.48, 0), P.Brass, M.Metal)
	kit.cylinder("Column", 0.62, 1.86, CFrame.new(0, 1.47, 0), P.Teak, M.Wood)
	kit.cylinder("ColumnBand", 0.66, 0.08, CFrame.new(0, 1.0, 0), P.Brass, M.Metal)
	kit.cylinder("ColumnBand", 0.66, 0.08, CFrame.new(0, 2.0, 0), P.Brass, M.Metal)
	kit.cylinder("Neck", 0.84, 0.16, CFrame.new(0, 2.48, 0), P.DarkWood, M.Wood)

	-- Flinders bar on the front of the column
	kit.cylinder("FlindersBar", 0.16, 0.9, CFrame.new(0, 1.5, -0.36), P.Brass, M.Metal)
	kit.ball("FlindersCap", 0.18, CFrame.new(0, 1.95, -0.36), P.Brass, M.Metal)

	-- Compass bowl, card and glass dome with a hood
	kit.cylinder("CompassHousing", 0.8, 0.34, CFrame.new(0, 2.73, 0), P.Brass, M.Metal)
	kit.cylinder("CompassRim", 0.86, 0.06, CFrame.new(0, 2.92, 0), Color3.fromRGB(170, 128, 50), M.Metal)
	kit.cylinder("Card", 0.66, 0.04, CFrame.new(0, 2.94, 0), P.Cream, M.SmoothPlastic)
	kit.block("Needle", Vector3.new(0.06, 0.02, 0.5), CFrame.new(0, 2.97, 0), P.Red, M.SmoothPlastic)
	kit.ball("Dome", 0.7, CFrame.new(0, 2.94, 0), Color3.fromRGB(170, 210, 225), M.Glass)
	kit.cylinder("HoodRing", 0.4, 0.08, CFrame.new(0, 3.3, 0), P.Brass, M.Metal)
	kit.ball("Finial", 0.2, CFrame.new(0, 3.42, 0), P.Brass, M.Metal)

	-- Brass correcting spheres on arms
	for _, side in { -1, 1 } do
		kit.block("SphereArm", Vector3.new(0.36, 0.08, 0.14), CFrame.new(side * 0.52, 2.6, 0), P.Brass, M.Metal)
		kit.ball("Corrector", 0.42, CFrame.new(side * 0.58, 2.6, 0), P.Brass, M.Metal)
	end

	-- Small binnacle lamp glowing on the side of the bowl
	local lamp = kit.ball("Lamp", 0.12, CFrame.new(0, 2.78, -0.42), P.Glow, M.Neon)
	kit.light(lamp, P.Glow, 6, 0.8)
end
