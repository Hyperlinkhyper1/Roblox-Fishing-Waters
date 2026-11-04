-- Walkable termini, including the migration of the old plaza stair and static train.
local Stations = {}
local LowPoly = require(script.Parent.LowPoly)
local CityMetro = require(script.Parent.CityMetro)
local VERSION = 2
local HARBOUR_VERSION = 3
local V, rgb, M = Vector3.new, Color3.fromRGB, Enum.Material
local TILE, TEAL = rgb(234, 223, 197), rgb(35, 88, 81)
local IRON, WHITE = rgb(38, 43, 40), rgb(248, 239, 217)
local STONE, BRASS = rgb(205, 190, 160), rgb(187, 150, 80)
local FLOOR = -28.8

local function part(parent, name, size, frame, color, material, collide)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = name, size, frame
	p.Anchored, p.CanTouch, p.CanCollide = true, false, collide ~= false
	p.Color, p.Material = color, material
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if collide == false then p.CanQuery, p.CastShadow = false, false end
	p.Parent = parent
	return p
end

local function text(board, words, face, color)
	local gui = Instance.new("SurfaceGui")
	gui.Face, gui.SizingMode, gui.PixelsPerStud = face or Enum.NormalId.Back, Enum.SurfaceGuiSizingMode.PixelsPerStud, 35
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	label.Font, label.TextScaled, label.TextColor3 = Enum.Font.GothamBold, true, color or WHITE
	label.Text, label.Parent = words, gui
	return label
end

local function model(name, stop, version)
	local m = Instance.new("Model")
	m.Name, m.ModelStreamingMode = name, Enum.ModelStreamingMode.PersistentPerPlayer
	m:SetAttribute("LodSkip", true)
	m:SetAttribute("MetroVersion", version or VERSION)
	m:SetAttribute("MetroStopId", stop)
	return m
end

local function marker(m, name, frame)
	local p = part(m, name, V(1, 0.1, 1), frame, TILE, M.Concrete, false)
	p.Transparency = 1
	return p
end

local function controls(m, dock, arrival, destination)
	marker(m, "TrainDock", dock)
	marker(m, "Arrival", arrival)
	local board = marker(m, "Boarding", dock * CFrame.new(-11, 3, -7.8))
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name, prompt.ActionText = "MetroBoardPrompt", "Board for " .. destination
	prompt.ObjectText = "Line 1 · Free · Every minute"
	prompt.KeyboardKeyCode, prompt.GamepadKeyCode = Enum.KeyCode.E, Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance, prompt.RequiresLineOfSight, prompt.HoldDuration = 10, false, 0.3
	prompt.Enabled, prompt.Parent = false, board
end

local function indicator(m, frame, destination, size)
	local board = part(m, "DepartureBoard", size or V(15, 3.6, 0.5), frame, IRON, M.Metal, false)
	board:SetAttribute("MetroDestination", destination)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local label = text(board, "LINE 1 · " .. destination .. "\nService preparing", face, rgb(255, 192, 87))
		label.Name, label.Font = "Countdown", Enum.Font.Code
	end
	return board
end

-- Split only axis-aligned flat slabs; keep every fragment, material and prop.
local function cutSlab(p, origin, rect)
	if not p:IsA("Part") or p.Shape ~= Enum.PartType.Block then return end
	if (p.CFrame.RightVector - Vector3.xAxis).Magnitude > 0.001 or (p.CFrame.UpVector - Vector3.yAxis).Magnitude > 0.001 then return end
	local c, h = p.Position - origin, p.Size / 2
	if c.Y + h.Y < -6 or c.Y - h.Y > 0.1 then return end
	local x0, x1, z0, z1 = c.X - h.X, c.X + h.X, c.Z - h.Z, c.Z + h.Z
	local ax, bx, az, bz = math.max(x0, rect[1]), math.min(x1, rect[2]), math.max(z0, rect[3]), math.min(z1, rect[4])
	if ax >= bx or az >= bz then return end
	for _, r in { { x0, ax, z0, z1 }, { bx, x1, z0, z1 }, { ax, bx, z0, az }, { ax, bx, bz, z1 } } do
		local w, d = r[2] - r[1], r[4] - r[3]
		if w > 0.01 and d > 0.01 then
			local clone = p:Clone()
			clone.Size = V(w, p.Size.Y, d)
			clone.CFrame = CFrame.new(origin + V((r[1] + r[2]) / 2, c.Y, (r[3] + r[4]) / 2))
			clone.Parent = p.Parent
		end
	end
	p:Destroy()
end

-- Hills use thin triangular wedges rather than slabs. Clip their visible
-- triangle around the open part of the shaft, preserving the surrounding slope.
local function cutWedge(p, origin, rect)
	if not p:IsA("WedgePart") or p.Size.X > 1 or math.abs(p.CFrame.RightVector.Y) < 0.5 then return end
	local h = p.Size / 2
	local x = if p.CFrame.RightVector.Y > 0 then h.X else -h.X
	local polygon = {
		p.CFrame * V(x, -h.Y, -h.Z), p.CFrame * V(x, -h.Y, h.Z), p.CFrame * V(x, h.Y, h.Z),
	}
	local a, b, c = polygon[1] - origin, polygon[2] - origin, polygon[3] - origin
	if math.max(a.X, b.X, c.X) <= rect[1] + 0.001 or math.min(a.X, b.X, c.X) >= rect[2] - 0.001
		or math.max(a.Z, b.Z, c.Z) <= rect[3] + 0.001 or math.min(a.Z, b.Z, c.Z) >= rect[4] - 0.001 then return end
	local pieces = {}
	for _, bound in { { "X", rect[1], 1 }, { "X", rect[2], -1 }, { "Z", rect[3], 1 }, { "Z", rect[4], -1 } } do
		local inside, outside = {}, {}
		for i, a in polygon do
			local b = polygon[i % #polygon + 1]
			local da = (a[bound[1]] - origin[bound[1]] - bound[2]) * bound[3]
			local db = (b[bound[1]] - origin[bound[1]] - bound[2]) * bound[3]
			table.insert(if da >= 0 then inside else outside, a)
			if (da >= 0) ~= (db >= 0) then
				local edge = a:Lerp(b, da / (da - db))
				table.insert(inside, edge); table.insert(outside, edge)
			end
		end
		if #outside >= 3 then table.insert(pieces, outside) end
		polygon = inside
		if #polygon < 3 then return end -- no actual overlap with the opening
	end
	local area = 0
	for i, a in polygon do
		local b = polygon[i % #polygon + 1]
		area += (a.X - origin.X) * (b.Z - origin.Z) - (b.X - origin.X) * (a.Z - origin.Z)
	end
	if math.abs(area) < 0.02 then return end
	for _, poly in pieces do
		for i = 2, #poly - 1 do
			local a, b, c = poly[1], poly[i], poly[i + 1]
			LowPoly.triangle(a, b, c, (a + b + c) / 3 - V(0, 40, 0), p.Color, p.Parent, p.Material, p.Size.X)
		end
	end
	p:Destroy()
end

function Stations.ensureHarbour(island, plaza, frame)
	local existing = island:FindFirstChild("GullhavenMetro")
	-- Ground can be regenerated independently of the saved station.
	local ground = island:FindFirstChild("Ground")
	for _, p in if ground then ground:GetDescendants() else {} do
		cutSlab(p, frame.Position, { 61, 130, -24.6, -11.4 })
		cutWedge(p, frame.Position, { 61, 96.2, -24.6, -11.4 })
	end
	if existing and existing:GetAttribute("MetroVersion") == HARBOUR_VERSION then return existing end
	local restorePlaza = existing and (existing:GetAttribute("MetroVersion") or 1) < 2
	local restored = {}
	if existing then
		-- These fills belong to the old plaza, even when replacing a v2 station.
		for _, p in existing:GetChildren() do
			if string.match(p.Name, "^FormerEntrance") or string.match(p.Name, "^RestoredPlaza") then
				p.Parent = nil
				table.insert(restored, p)
			end
		end
		existing:Destroy()
	end
	local station = model("GullhavenMetro", "Harbour", HARBOUR_VERSION)
	for _, p in restored do p.Parent = station end
	local function box(name, x0, x1, y0, y1, z0, z1, color, material, collide)
		return part(station, name, V(x1 - x0, y1 - y0, z1 - z0), frame * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), color, material, collide)
	end
	local function bar(name, a, b, width, depth, color)
		return part(station, name, V(width, depth, (b - a).Magnitude), frame * CFrame.lookAt((a + b) / 2, b), color, M.Metal, false)
	end
	local function glow(lamp, range, brightness)
		local light = Instance.new("PointLight")
		light.Range, light.Brightness, light.Color, light.Parent = range, brightness, rgb(255, 226, 183), lamp
	end
	-- Restore the hole left by v1 and its cut plaza inlays, including on baked maps.
	if restorePlaza then
		box("FormerEntranceGround", 19, 31, -4.92, -0.92, -62, -24, rgb(118, 140, 92), M.Grass)
		box("FormerEntrancePaving", 19, 31, -0.72, -0.12, -58, -24, TILE, M.Limestone)
		box("FormerEntranceKerb", 19, 31, -0.68, 0.12, -60, -58, rgb(142, 136, 122), M.Slate)
		box("RestoredPlazaBand", 23.3, 24.7, -0.12, 0, -58, -24, rgb(166, 156, 136), M.Cobblestone, false)
		box("RestoredPlazaCrossBand", 19, 23.3, -0.12, 0, -48.7, -47.3, rgb(166, 156, 136), M.Cobblestone, false)
		box("RestoredPlazaCrossBand", 24.7, 31, -0.12, 0, -48.7, -47.3, rgb(166, 156, 136), M.Cobblestone, false)
	end
	-- East-row plot 8 is reserved by PlazaHouses. The level lane precedes the stair.
	box("EntrancePassage", 61, 80, -0.6, 0, -24.6, -11.4, STONE, M.Limestone)
	for x = 62, 78, 2 do
		box("EntrancePaverJoint", x, x + 0.045, 0.015, 0.035, -23.9, -12.1, rgb(163, 149, 124), M.Concrete, false)
	end
	for _, side in { { -26, -24 }, { -12, -10 } } do
		box("PavilionPlinth", 70, 85, -0.8, 1.2, side[1], side[2], STONE, M.Limestone)
		box("PavilionStucco", 71, 84, 1.2, 8.7, side[1] + 0.2, side[2] - 0.2, rgb(229, 185, 125), M.Plaster)
		box("PavilionCornice", 69.6, 85.4, 8.7, 9.3, side[1] - 0.2, side[2] + 0.2, TILE, M.Limestone)
		for x = 71, 83, 3 do
			box("LimestoneQuoin", x - 0.05, x + 0.6, 1.3, 8.7, side[1] - 0.1, side[2] + 0.1, TILE, M.Limestone, false)
		end
	end
	for _, z in { -22.4, -13.6 } do
		box("LanternBracket", 69.9, 70.3, 4.9, 6.8, z - 0.42, z + 0.42, IRON, M.Metal, false)
		local lamp = box("EntranceLantern", 69.65, 69.9, 5.2, 6.5, z - 0.26, z + 0.26, rgb(238, 209, 160), M.Neon, false)
		glow(lamp, 12, 0.45)
	end
	for _, side in { -1, 1 } do
		part(station, "TerracottaCanopy", V(17.8, 0.65, 8.4), frame * CFrame.new(77.5, 10.1, -18 + side * 4.2) * CFrame.Angles(side * 0.2, 0, 0), rgb(158, 79, 48), M.ClayRoofTiles)
	end
	box("RoofRidge", 68.4, 86.6, 10.8, 11.3, -18.45, -17.55, rgb(126, 60, 38), M.ClayRoofTiles)
	box("EntranceLintel", 69.2, 70, 7.3, 9.2, -24, -12, STONE, M.Limestone)
	local entrance = box("MetroEntranceSign", 68.94, 69.14, 7.55, 8.95, -23.3, -12.7, TEAL, M.Metal, false)
	text(entrance, "GULLHAVEN  ·  METRO ↓", Enum.NormalId.Left)
	-- A compact board sits on the inside wall, clear of the approach and camera.
	indicator(station, frame * CFrame.new(75.5, 5.7, -12.18), "Hafen Mitte", V(7.6, 2, 0.28))
	local service = box("EntranceServiceSign", 71.5, 79.3, 2.5, 3.6, -12.17, -12.04, TEAL, M.Metal, false)
	text(service, "1  ·  FREE SERVICE  ·  EVERY MINUTE", Enum.NormalId.Front)
	for _, side in { { -25.2, -24 }, { -12, -10.8 } } do
		box("StairwellTiles", 80, 130, FLOOR - 1, -0.8, side[1], side[2], TILE, M.CeramicTiles)
		box("StoneParapet", 85.02, 95.8, -0.8, 2.6, side[1], side[2], STONE, M.Limestone)
		box("ParapetCoping", 85.07, 95.75, 2.6, 2.85, side[1] - 0.08, side[2] + 0.08, TILE, M.Limestone, false)
	end
	for _, z in { -23.65, -12.35 } do
		bar("StairHandrail", V(79.7, 3.1, z), V(128.6, FLOOR + 3, z), 0.18, 0.18, BRASS)
		for k = 3, 35, 8 do
			local x, y = 80 + (k - 0.5) * 1.35, -k * 0.8
			local wall = if z < -18 then -24 else -12
			bar("HandrailBracket", V(x, y + 2.8, wall), V(x, y + 2.8, z), 0.12, 0.12, IRON)
			box("StairLightHousing", x - 0.55, x + 0.55, y + 4.6, y + 5.25, math.min(z, wall), math.max(z, wall), IRON, M.Metal, false)
			local lamp = box("StairWallLight", x - 0.4, x + 0.4, y + 4.72, y + 5.1, z - 0.04, z + 0.04, WHITE, M.Neon, false)
			glow(lamp, 11, 0.4)
		end
	end
	for k = 1, 36 do
		local x, y = 80 + (k - 1) * 1.35, -k * 0.8
		box("StairTread", x, x + 1.35, y - 0.9, y, -24, -12, TILE, M.Concrete)
		box("StairNosing", x + 1.17, x + 1.35, y + 0.02, y + 0.07, -23.9, -12.1, TEAL, M.Metal, false)
	end
	-- A lined, sloping soffit hides the underside of the hill and joins the hall roof.
	local a, b = V(96.2, -0.6, -18), V(120.2, FLOOR + 14, -18)
	local slope = math.atan2(b.Y - a.Y, b.X - a.X)
	part(station, "StairTunnelCeiling", V((b - a).Magnitude, 0.6, 13.2), frame * CFrame.new((a + b) / 2 + V(-math.sin(slope), math.cos(slope), 0) * 0.3) * CFrame.Angles(0, 0, slope), TILE, M.Concrete)
	box("StairTunnelRoof", 120.2, 130, FLOOR + 14, FLOOR + 15, -24.6, -11.4, TILE, M.Concrete)
	box("TunnelPortalLintel", 95.8, 96.2, -0.6, 1.5, -25.2, -10.8, STONE, M.Limestone)
	local down = box("StairDirectionSign", 95.55, 95.75, -0.2, 1.1, -22.6, -13.4, TEAL, M.Metal, false)
	text(down, "1  HAFEN MITTE  ↓", Enum.NormalId.Left)
	-- Floor slabs and pavers stop at the last tread instead of sharing its top face.
	box("StationFloor", 128.6, 151.5, FLOOR - 2, FLOOR, -110, 62, rgb(179, 167, 143), M.Concrete)
	for _, run in { { -110, -25.2 }, { -10.8, 62 } } do
		box("StationFloor", 110, 128.6, FLOOR - 2, FLOOR, run[1], run[2], rgb(179, 167, 143), M.Concrete)
		box("StationRoof", 109, 170, FLOOR + 14, FLOOR + 15, run[1], run[2], TILE, M.Concrete)
		box("WestWall", 109, 110, FLOOR, FLOOR + 14, run[1], run[2], TILE, M.CeramicTiles)
		box("TileDado", 110, 110.18, FLOOR + 0.12, FLOOR + 3.2, run[1] + 0.1, run[2] - 0.1, TEAL, M.CeramicTiles, false)
		box("WallSkirting", 110.18, 110.3, FLOOR + 0.12, FLOOR + 0.38, run[1] + 0.1, run[2] - 0.1, IRON, M.Metal, false)
		box("TileFrieze", 110, 110.2, FLOOR + 8.7, FLOOR + 9.3, run[1] + 0.1, run[2] - 0.1, TEAL, M.CeramicTiles, false)
		box("FriezeBorder", 110.2, 110.28, FLOOR + 9.3, FLOOR + 9.42, run[1] + 0.1, run[2] - 0.1, BRASS, M.Metal, false)
	end
	box("StationRoof", 130, 170, FLOOR + 14, FLOOR + 15, -25.2, -10.8, TILE, M.Concrete)
	box("EastWall", 169, 170, FLOOR - 4, FLOOR + 14, -110, 62, TILE, M.CeramicTiles)
	for _, ending in { { -110, -110.4, -110 }, { 61, 62, 62.4 } } do
		box("PlatformEndWall", 110, 151.5, FLOOR, FLOOR + 14, ending[1], ending[1] + 1, TILE, M.CeramicTiles)
		box("TunnelMouth", 151.5, 169, FLOOR - 4, FLOOR + 13.8, ending[2], ending[3], rgb(15, 20, 21), M.SmoothPlastic, false)
	end
	for ix = 0, 9 do
		for iz = 0, 42 do
			local x, z = 110.12 + ix * 4, -108.9 + iz * 4
			local x1, z1 = math.min(x + 3.92, 147.08), math.min(z + 3.92, 60.88)
			local color = if (ix + iz) % 2 == 0 then rgb(196, 184, 161) else rgb(210, 200, 180)
			local function paver(ax, bx, az, bz)
				if bx - ax > 0.01 and bz - az > 0.01 then
					box("TerrazzoPaver", ax, bx, FLOOR + 0.02, FLOOR + 0.1, az, bz, color, M.Limestone, false)
				end
			end
			paver(x, math.min(x1, 128.6), z, math.min(z1, -25.2))
			paver(x, math.min(x1, 128.6), math.max(z, -10.8), z1)
			paver(math.max(x, 128.6), x1, z, z1)
		end
	end
	box("PlatformCoping", 150, 151.5, FLOOR + 0.1, FLOOR + 0.22, -109, 61, STONE, M.Concrete, false)
	box("SafetyLine", 148.8, 149.2, FLOOR + 0.1, FLOOR + 0.2, -109, 61, rgb(229, 188, 63), M.SmoothPlastic, false)
	box("TactilePaving", 147.2, 148.4, FLOOR + 0.1, FLOOR + 0.17, -109, 61, rgb(204, 181, 112), M.Pebble, false)
	box("TrackBed", 151.5, 169, FLOOR - 4, FLOOR - 3.5, -110, 62, rgb(49, 52, 50), M.Slate)
	for z = -108, 60, 6 do
		box("Sleeper", 153, 166, FLOOR - 3.5, FLOOR - 3.1, z, z + 0.6, rgb(80, 68, 53), M.Wood, false)
	end
	for _, x in { 155.2, 160.8 } do
		box("Rail", x, x + 0.28, FLOOR - 3.1, FLOOR - 2.6, -110, 62, rgb(143, 148, 141), M.Metal, false)
	end
	for _, z in { -96, -66, -36, 6, 36, 53 } do
		box("ColumnBase", 137, 139.2, FLOOR, FLOOR + 0.6, z - 1.1, z + 1.1, STONE, M.Limestone)
		box("IronColumn", 137.6, 138.6, FLOOR + 0.6, FLOOR + 13.5, z - 0.5, z + 0.5, TEAL, M.Metal)
		box("ColumnCapital", 136.8, 139.4, FLOOR + 13, FLOOR + 14, z - 1.3, z + 1.3, BRASS, M.Metal, false)
		box("RoofCrossbeam", 110, 169, FLOOR + 13.3, FLOOR + 14, z - 0.4, z + 0.4, TEAL, M.Metal, false)
		box("ColumnCollar", 137.48, 138.72, FLOOR + 3.7, FLOOR + 3.95, z - 0.62, z + 0.62, BRASS, M.Metal, false)
		for _, side in { -1, 1 } do
			bar("ColumnBrace", V(138.1, FLOOR + 11.1, z), V(138.1 + side * 3.4, FLOOR + 13.25, z), 0.2, 0.2, TEAL)
			for _, dz in { -0.72, 0.72 } do
				box("ColumnAnchorBolt", 138.1 + side * 0.78 - 0.09, 138.1 + side * 0.78 + 0.09, FLOOR + 0.6, FLOOR + 0.72, z + dz - 0.09, z + dz + 0.09, IRON, M.Metal, false)
			end
		end
		box("LightHousing", 115.7, 133.3, FLOOR + 13.15, FLOOR + 13.35, z - 0.6, z + 0.6, IRON, M.Metal, false)
		local lamp = box("PlatformLight", 116, 133, FLOOR + 13, FLOOR + 13.2, z - 0.45, z + 0.45, WHITE, M.Neon, false)
		glow(lamp, 30, 0.65)
		box("StationSignFrame", 110.22, 110.44, FLOOR + 5.85, FLOOR + 8.55, z - 7.65, z + 7.65, BRASS, M.Metal, false)
		local name = box("StationName", 110.45, 110.6, FLOOR + 6, FLOOR + 8.4, z - 7.5, z + 7.5, TEAL, M.Metal, false)
		text(name, "GULLHAVEN\n1 · HAFEN MITTE", Enum.NormalId.Right)
	end
	-- Services sit against the wall, leaving the stair landing and edge route open.
	for _, z in { -62, 30 } do
		box("LitterBin", 113, 115.8, FLOOR + 0.12, FLOOR + 3, z - 1.2, z + 1.2, TEAL, M.Metal)
		box("BinLid", 112.9, 115.9, FLOOR + 3, FLOOR + 3.3, z - 1.3, z + 1.3, IRON, M.Metal, false)
		box("BinOpening", 115.81, 115.87, FLOOR + 2.1, FLOOR + 2.7, z - 0.8, z + 0.8, rgb(16, 23, 22), M.SmoothPlastic, false)
		local label = box("BinLabel", 115.81, 115.87, FLOOR + 1, FLOOR + 1.75, z - 0.85, z + 0.85, TEAL, M.Metal, false)
		text(label, "LITTER", Enum.NormalId.Right)
	end
	box("RouteMapFrame", 110.25, 110.52, FLOOR + 3.9, FLOOR + 8.3, -56.5, -49, BRASS, M.Metal, false)
	local route = box("RouteMap", 110.53, 110.66, FLOOR + 4.08, FLOOR + 8.12, -56.3, -49.2, WHITE, M.SmoothPlastic, false)
	text(route, "LINE 1\n● GULLHAVEN\n│\n● HAFEN MITTE\nFree · Every minute", Enum.NormalId.Right, TEAL)
	box("TimetableFrame", 110.25, 110.52, FLOOR + 4, FLOOR + 8.25, -10, -4.8, IRON, M.Metal, false)
	local timetable = box("ServiceTimetable", 110.53, 110.66, FLOOR + 4.15, FLOOR + 8.1, -9.85, -4.95, WHITE, M.SmoothPlastic, false)
	text(timetable, "GULLHAVEN METRO\n1 → HAFEN MITTE\nTrains every minute\nNo ticket needed\nMind the platform edge", Enum.NormalId.Right, TEAL)
	for _, z in { -104, 57 } do
		box("TrackCableDuct", 168.6, 169, FLOOR + 3.6, FLOOR + 4.1, z - 3, z + 3, IRON, M.Metal, false)
	end
	for y = 4.35, 5.15, 0.4 do
		box("TrackConduit", 168.76, 168.92, FLOOR + y, FLOOR + y + 0.12, -109, 61, rgb(106, 107, 94), M.Metal, false)
	end
	for _, z in { -80, -45, 15, 45 } do
		box("BenchSeat", 113, 116, FLOOR + 1.6, FLOOR + 1.8, z - 5, z + 5, IRON, M.Metal)
		for x = 113.04, 115.44, 0.6 do
			box("BenchSeatSlat", x, x + 0.52, FLOOR + 1.82, FLOOR + 2.04, z - 5, z + 5, rgb(118, 81, 53), M.Wood)
		end
		for y = 2.2, 3.6, 0.7 do
			box("BenchBackSlat", 112.75, 113.05, FLOOR + y, FLOOR + y + 0.56, z - 5, z + 5, rgb(118, 81, 53), M.Wood)
		end
		for _, dz in { -4, 4 } do
			box("BenchLeg", 113.2, 115.8, FLOOR, FLOOR + 1.6, z + dz - 0.2, z + dz + 0.2, IRON, M.Metal)
			box("BenchBackSupport", 112.65, 112.9, FLOOR + 1.6, FLOOR + 4.2, z + dz - 0.16, z + dz + 0.16, IRON, M.Metal, false)
			box("BenchArmPost", 115.25, 115.5, FLOOR + 2.04, FLOOR + 3, z + dz - 0.16, z + dz + 0.16, IRON, M.Metal, false)
			box("BenchArmrest", 113.1, 115.8, FLOOR + 3, FLOOR + 3.2, z + dz - 0.2, z + dz + 0.2, BRASS, M.Metal, false)
		end
		box("PosterFrame", 110.22, 110.5, FLOOR + 3, FLOOR + 5.7, z - 2.5, z + 2.5, IRON, M.Metal, false)
		local poster = box("TravelPoster", 110.51, 110.65, FLOOR + 3.15, FLOOR + 5.55, z - 2.35, z + 2.35, rgb(153, 80, 48), M.SmoothPlastic, false)
		text(poster, if z < 0 then "GULLHAVEN\nFRESH FROM THE BAY" else "HAFEN MITTE\nEXPLORE THE CITY", Enum.NormalId.Right)
	end
	for _, z in { -62, 24 } do
		indicator(station, frame * CFrame.new(139, FLOOR + 10, z) * CFrame.Angles(0, -math.pi / 2, 0), "Hafen Mitte")
		for _, dz in { -5.5, 5.5 } do
			box("DepartureBoardHanger", 138.88, 139.12, FLOOR + 11.8, FLOOR + 14, z + dz - 0.12, z + dz + 0.12, IRON, M.Metal, false)
		end
	end
	local exit = box("ExitWayfinding", 130.8, 131.1, FLOOR + 8.5, FLOOR + 10.6, -24, -12, TEAL, M.Metal, false)
	text(exit, "EXIT ↑\nPIAZZA · HARBOUR", Enum.NormalId.Right)
	for _, z in { -22.8, -13.2 } do
		box("ExitSignHanger", 130.86, 131.04, FLOOR + 10.6, FLOOR + 14, z - 0.09, z + 0.09, IRON, M.Metal, false)
	end
	controls(station, frame * CFrame.new(158, FLOOR + 0.22, -24) * CFrame.Angles(0, math.pi / 2, 0), frame * CFrame.new(141, FLOOR + 3.5, -18), "Hafen Mitte")
	station.Parent = island
	station:AddTag("MetroStop")
	return station
end

function Stations.ensureCity(city)
	if not city then return end
	local existing = city:FindFirstChild("CityMetroStop")
	if existing and existing:GetAttribute("MetroVersion") == VERSION then
		CityMetro.ensureSurfaces(existing, V(7000, 0, 7000))
		return existing
	end
	if existing then existing:Destroy() end
	local metro = city:FindFirstChild("HafenMitte", true)
	if not metro then return end
	CityMetro.ensureSurfaces(metro, V(7000, 0, 7000))
	local train = metro:FindFirstChild("MetroTrain")
	if train then train:Destroy() end
	local station = model("CityMetroStop", "City")
	local frame = CFrame.new(7000, -34, 7000)
	for _, name in { "MetroTicketHall", "MetroEscalators", "MetroStairwell", "MetroVault", "MetroPlatforms", "MetroTracks", "MetroBridge" } do
		local room = metro:FindFirstChild(name)
		if room then room:RemoveTag("LodPiece"); room.ModelStreamingMode = Enum.ModelStreamingMode.Default; room.Parent = station end
	end
	for _, p in station:GetDescendants() do
		if p.Name == "TrainIndicator" then
			p.Name = "DepartureBoard"
			p:SetAttribute("MetroDestination", "Gullhaven")
			for _, label in p:GetDescendants() do
				if label:IsA("TextLabel") then label.Name, label.Text = "Countdown", "LINE 1 · GULLHAVEN\nService preparing" end
			end
		end
	end
	controls(station, frame * CFrame.new(-250, 0.15, -91.5), frame * CFrame.new(-280, 3.5, -104), "Gullhaven")
	indicator(station, frame * CFrame.new(-280, 10, -104), "Gullhaven")
	station.Parent = city
	station:AddTag("MetroStop")
	return station
end

return Stations
