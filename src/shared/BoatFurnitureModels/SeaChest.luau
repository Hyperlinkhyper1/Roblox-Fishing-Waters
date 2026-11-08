return function(kit)
	local P = kit.Palette
	local M = kit.Material
	local band = Color3.fromRGB(46, 48, 52)
	local wood = Color3.fromRGB(120, 72, 40)
	local lidWood = Color3.fromRGB(96, 56, 30)

	-- feet
	for _, x in { -1.2, 1.2 } do
		for _, z in { -0.62, 0.62 } do
			kit.block("Foot", Vector3.new(0.34, 0.14, 0.34), CFrame.new(x, 0.07, z), P.DarkWood, M.Wood)
		end
	end

	-- body and lid
	kit.block("Body", Vector3.new(2.7, 1.22, 1.56), CFrame.new(0, 0.75, 0), wood, M.WoodPlanks)
	kit.block("Plinth", Vector3.new(2.8, 0.14, 1.66), CFrame.new(0, 0.21, 0), lidWood, M.Wood)
	kit.block("LidRim", Vector3.new(2.84, 0.2, 1.68), CFrame.new(0, 1.46, 0), lidWood, M.Wood)
	local dome = CFrame.new(0, 1.42, 0) * CFrame.Angles(0, 0, math.pi / 2)
	kit.cylinder("LidDome", 1.5, 2.8, dome, wood, M.WoodPlanks)

	-- iron bands: two straps round body + dome, one round the waist
	for _, x in { -0.92, 0.92 } do
		kit.block("Strap", Vector3.new(0.18, 1.22, 1.64), CFrame.new(x, 0.75, 0), band, M.Metal)
		kit.block("RimStrap", Vector3.new(0.18, 0.22, 1.72), CFrame.new(x, 1.46, 0), band, M.Metal)
		kit.cylinder("DomeStrap", 1.56, 0.18, CFrame.new(x, 1.42, 0) * CFrame.Angles(0, 0, math.pi / 2), band, M.Metal)
	end
	-- corner caps on the end edges
	for _, x in { -1.31, 1.31 } do
		for _, z in { -0.76, 0.76 } do
			kit.block("CornerBand", Vector3.new(0.12, 1.22, 0.1), CFrame.new(x, 0.75, z), band, M.Metal)
		end
	end

	-- heavy brass lock on the front
	kit.block("LockPlate", Vector3.new(0.5, 0.56, 0.08), CFrame.new(0, 1.2, -0.82), P.Brass, M.Metal)
	kit.block("Keyhole", Vector3.new(0.08, 0.16, 0.04), CFrame.new(0, 1.12, -0.87), Color3.fromRGB(20, 20, 22), M.SmoothPlastic)
	kit.block("Hasp", Vector3.new(0.24, 0.36, 0.08), CFrame.new(0, 1.62, -0.78), P.Brass, M.Metal)
	kit.cylinder("Padlock", 0.32, 0.14, CFrame.new(0, 1.36, -0.88) * CFrame.Angles(math.pi / 2, 0, 0), P.Brass, M.Metal)

	-- carry handles on the ends
	for _, s in { -1, 1 } do
		kit.block("HandleBracket", Vector3.new(0.1, 0.18, 0.12), CFrame.new(s * 1.4, 1.0, -0.3), band, M.Metal)
		kit.block("HandleBracket", Vector3.new(0.1, 0.18, 0.12), CFrame.new(s * 1.4, 1.0, 0.3), band, M.Metal)
		kit.block("Handle", Vector3.new(0.1, 0.1, 0.72), CFrame.new(s * 1.46, 0.92, 0), band, M.Metal)
	end
end
