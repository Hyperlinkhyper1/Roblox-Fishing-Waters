-- An open, glass-roofed transit hall between the port and the city centre.
-- The supplied frame is at pavement height and the main entrances face +/-Z.
local CityStation = {}

local rgb = Color3.fromRGB
local brick = rgb(140, 85, 72)
local stone = rgb(210, 196, 175)
local steel = rgb(62, 76, 78)
local glass = rgb(139, 179, 184)
local timber = rgb(119, 89, 66)

local function part(parent: Instance, base: CFrame, name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material, solid: boolean?, rotation: CFrame?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = base * CFrame.new(position) * (rotation or CFrame.new())
	p.Anchored = true
	p.Color = color
	p.Material = material
	p.CanCollide = solid == true
	p.CanTouch = false
	p.CanQuery = solid == true
	p.CastShadow = solid == true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function CityStation.build(parent: Instance, base: CFrame): Model
	local station = Instance.new("Model")
	station.Name = "CityTransitHall"
	station.Parent = parent

	-- Two old brick pavilions flank an open pedestrian passage.
	for _, side in { -1, 1 } do
		local x = side * 41
		part(station, base, "BrickPavilion", Vector3.new(15, 22, 34), Vector3.new(x, 11, 0), brick, Enum.Material.Brick, true)
		part(station, base, "PavilionPlinth", Vector3.new(16, 2, 35), Vector3.new(x, 1, 0), stone, Enum.Material.Concrete)
		part(station, base, "PavilionCornice", Vector3.new(17, 2, 36), Vector3.new(x, 22, 0), stone, Enum.Material.Concrete)
		part(station, base, "PavilionRoof", Vector3.new(16, 2, 35), Vector3.new(x, 24, 0), steel, Enum.Material.Metal)
		for _, face in { -1, 1 } do
			part(station, base, "PavilionWindowFrame", Vector3.new(9, 12, 0.6), Vector3.new(x, 11, face * 17.25), stone, Enum.Material.Concrete)
			local pane = part(station, base, "PavilionWindow", Vector3.new(7.5, 10.5, 0.7), Vector3.new(x, 11, face * 17.55), glass, Enum.Material.Glass)
			pane.Transparency = 0.12
			pane:SetAttribute("PreserveGlassMaterial", true)
			part(station, base, "WindowMullion", Vector3.new(0.5, 10.5, 0.9), Vector3.new(x, 11, face * 17.9), steel, Enum.Material.Metal)
		end
	end

	-- A shallow segmented vault and exposed ribs make the hall recognisable
	-- from both the waterfront and nearby streets without enclosing the route.
	for _, x in { -32, -16, 0, 16, 32 } do
		if x ~= 0 then
			for _, side in { -1, 1 } do
				part(station, base, "VaultColumn", Vector3.new(1.5, 25, 1.5), Vector3.new(x, 12.5, side * 21), steel, Enum.Material.Metal, true)
			end
		end
		for segment = -2, 1 do
			local z0, z1 = segment * 10.5, (segment + 1) * 10.5
			local y0 = 25 + 7 * (1 - (z0 / 21) ^ 2)
			local y1 = 25 + 7 * (1 - (z1 / 21) ^ 2)
			local dy = y1 - y0
			local length = math.sqrt(10.5 ^ 2 + dy ^ 2)
			local rotation = CFrame.Angles(-math.atan2(dy, 10.5), 0, 0)
			part(station, base, "VaultRib", Vector3.new(1.3, 1.2, length), Vector3.new(x, (y0 + y1) / 2, (z0 + z1) / 2), steel, Enum.Material.Metal, false, rotation)
		end
	end
	for segment = -2, 1 do
		local z0, z1 = segment * 10.5, (segment + 1) * 10.5
		local y0 = 25 + 7 * (1 - (z0 / 21) ^ 2)
		local y1 = 25 + 7 * (1 - (z1 / 21) ^ 2)
		local dy = y1 - y0
		local pane = part(station, base, "VaultGlass", Vector3.new(65, 0.35, math.sqrt(10.5 ^ 2 + dy ^ 2)), Vector3.new(0, (y0 + y1) / 2 + 0.1, (z0 + z1) / 2), glass, Enum.Material.Glass, false, CFrame.Angles(-math.atan2(dy, 10.5), 0, 0))
		pane.Transparency = 0.35
		pane:SetAttribute("PreserveGlassMaterial", true)
	end
	for _, side in { -1, 1 } do
		part(station, base, "EntranceBeam", Vector3.new(66, 1.7, 1.7), Vector3.new(0, 25, side * 21), steel, Enum.Material.Metal)
		local sign = part(station, base, "StationSign", Vector3.new(23, 4, 0.7), Vector3.new(0, 20, side * 21.5), steel, Enum.Material.Metal)
		local signGui = Instance.new("SurfaceGui")
		signGui.Face = if side == 1 then Enum.NormalId.Back else Enum.NormalId.Front
		signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		signGui.PixelsPerStud = 24
		signGui.Parent = sign
		local signText = Instance.new("TextLabel")
		signText.Size = UDim2.fromScale(1, 1)
		signText.BackgroundTransparency = 1
		signText.Font = Enum.Font.GothamBold
		signText.TextColor3 = stone
		signText.TextScaled = true
		signText.Text = "HAFEN / MITTE"
		signText.Parent = signGui
		for _, x in { -20, 20 } do
			part(station, base, "BenchSeat", Vector3.new(10, 0.8, 3), Vector3.new(x, 2.8, side * 15), timber, Enum.Material.Wood)
			for _, dx in { -3.5, 3.5 } do
				part(station, base, "BenchLeg", Vector3.new(0.8, 2.5, 2.2), Vector3.new(x + dx, 1.25, side * 15), steel, Enum.Material.Metal)
			end
		end
	end
	return station
end

return CityStation
