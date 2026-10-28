-- Paints the live picture on every weather radar table near the camera (placed
-- WeatherRadar furniture and the showroom sample). The map is the area around
-- the table, turned to match the world around it: land from the replicated
-- island chart, and rain sampled from the same deterministic forecast the sky
-- uses (Weather.localConditions), so the radar shows exactly the storm this
-- client sees, tornadoes included.
--
-- It stays cheap: a screen only gets its SurfaceGui while the camera is close,
-- the land is painted once, and the rain layer is resampled every couple of
-- seconds. Each row of same-coloured cells is one frame, so even a supercell
-- over the whole disc is a few hundred frames, and an unchanged picture
-- touches none of them.
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Biomes = require(ReplicatedStorage.Shared.Biomes)
local Weather = require(ReplicatedStorage.Shared.Weather)

local Radar = {}
local started = false
local TAG = "WeatherRadarScreen"
-- Cells across the disc, and studs from the table to the disc's rim.
local CELLS = 40
local RANGE = 2400
local CANVAS = 240
local SHOW_DISTANCE = 70
local HIDE_DISTANCE = 90
local SCAN_INTERVAL = 0.5
local REFRESH_INTERVAL = 1.5
local MAX_TORNADOES = 2

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local SEA = rgb(44, 100, 178)
local SHALLOW = rgb(66, 134, 208)
local LAND = {
	normal = rgb(98, 164, 74),
	swamp = rgb(84, 112, 62),
	tropical = rgb(206, 192, 130),
	volcanic = rgb(98, 86, 80),
	ice = rgb(232, 238, 242),
	open = rgb(98, 164, 74),
}
-- Reflectivity bands, light rain to the hail core of a supercell.
local LEVELS = {
	{ at = 0.06, color = rgb(72, 172, 90), transparency = 0.35 },
	{ at = 0.22, color = rgb(26, 126, 46), transparency = 0 },
	{ at = 0.4, color = rgb(236, 214, 46), transparency = 0 },
	{ at = 0.58, color = rgb(242, 142, 34), transparency = 0 },
	{ at = 0.75, color = rgb(222, 44, 34), transparency = 0 },
	{ at = 0.92, color = rgb(248, 196, 220), transparency = 0 },
}

type Coast = { points: { Vector2 }, inner: { Vector2 }?, min: Vector2, max: Vector2 }
type Cell = { column: number, point: Vector3 }
type Screen = {
	part: BasePart,
	gui: SurfaceGui,
	land: Frame,
	rain: Frame,
	rows: { { Cell } },
	runs: { Frame },
	marks: { Frame },
	right: Vector3,
	back: Vector3,
	landVersion: number,
	-- What each pooled rain frame shows, so unchanged frames are never written.
	keys: { string? },
}

local coasts: { Coast } = {}
local coastVersion = 0

local function make(class: string, parent: Instance?, props: { [string]: any }): any
	local item = Instance.new(class)
	for key, value in props do
		item[key] = value
	end
	item.Parent = parent
	return item
end

-- Even-odd point in polygon.
local function inside(points: { Vector2 }, x: number, z: number): boolean
	local result = false
	local j = #points
	for i, a in points do
		local b = points[j]
		if (a.Y > z) ~= (b.Y > z) and x < (b.X - a.X) * (z - a.Y) / (b.Y - a.Y) + a.X then
			result = not result
		end
		j = i
	end
	return result
end

local function landAt(x: number, z: number): boolean
	for _, coast in coasts do
		if
			x >= coast.min.X
			and x <= coast.max.X
			and z >= coast.min.Y
			and z <= coast.max.Y
			and inside(coast.points, x, z)
			and not (coast.inner and inside(coast.inner, x, z))
		then
			return not Weather.inLake(Vector3.new(x, 0, z))
		end
	end
	return false
end

local function readCoast(record: Instance): Coast?
	if not record:IsA("StringValue") then
		return nil
	end
	local ok, raw = pcall(HttpService.JSONDecode, HttpService, record.Value)
	if not ok or type(raw) ~= "table" or #raw < 3 then
		return nil
	end
	local points, center = {}, Vector2.zero
	local x1, z1, x2, z2 = math.huge, math.huge, -math.huge, -math.huge
	for _, pair in raw do
		local point = Vector2.new(pair[1], pair[2])
		table.insert(points, point)
		center += point
		x1, z1 = math.min(x1, point.X), math.min(z1, point.Y)
		x2, z2 = math.max(x2, point.X), math.max(z2, point.Y)
	end
	local low, high = Vector2.new(x1, z1), Vector2.new(x2, z2)
	center /= #points
	local inner = nil
	-- An atoll is a ring of land round a lagoon, as the sea chart draws it.
	if record:GetAttribute("Atoll") then
		inner = {}
		for _, point in points do
			table.insert(inner, center:Lerp(point, 0.65))
		end
	end
	return { points = points, inner = inner, min = low, max = high }
end

-- Paints one row as runs of equal colour; `colorAt` returns a colour and a
-- transparency, or nil for an empty cell. Calls `emit(column, length, color,
-- transparency)` per run.
local function eachRun(cells: { Cell }, colorAt: (Cell) -> (Color3?, number), emit)
	local start, color, transparency, last = nil, nil, 0, nil
	local function flush()
		if start and color then
			emit(start, last - start + 1, color, transparency)
		end
	end
	for _, cell in cells do
		local nextColor, nextTransparency = colorAt(cell)
		if nextColor ~= color or nextTransparency ~= transparency or (last and cell.column ~= last + 1) then
			flush()
			start, color, transparency = cell.column, nextColor, nextTransparency
		end
		last = cell.column
	end
	flush()
end

local function runFrame(parent: Instance, row: number, column: number, length: number, z: number): Frame
	return make("Frame", parent, {
		BorderSizePixel = 0,
		Position = UDim2.fromScale(column / CELLS, row / CELLS),
		Size = UDim2.fromScale(length / CELLS, 1 / CELLS),
		ZIndex = z,
	})
end

local function paintLand(screen: Screen)
	screen.land:ClearAllChildren()
	screen.landVersion = coastVersion
	local grid = {}
	for row, cells in screen.rows do
		grid[row] = {}
		for _, cell in cells do
			grid[row][cell.column] = landAt(cell.point.X, cell.point.Z)
		end
	end
	local function nearLand(row: number, column: number): boolean
		for dr = -1, 1 do
			for dc = -1, 1 do
				local line = grid[row + dr]
				if line and line[column + dc] then
					return true
				end
			end
		end
		return false
	end
	for row, cells in screen.rows do
		eachRun(cells, function(cell: Cell): (Color3?, number)
			if grid[row][cell.column] then
				return LAND[Biomes.at(cell.point).id] or LAND.normal, 0
			end
			return if nearLand(row, cell.column) then SHALLOW else SEA, 0
		end, function(column, length, color)
			runFrame(screen.land, row, column, length, 1).BackgroundColor3 = color
		end)
	end
end

local function levelOf(rain: number, storm: number): number
	local value = math.max(rain * 0.8, storm)
	local level = 0
	for index, band in LEVELS do
		if value >= band.at then
			level = index
		end
	end
	return level
end

local function refresh(screen: Screen, state, tornadoes)
	if screen.landVersion ~= coastVersion then
		paintLand(screen)
	end
	-- Only frames whose run changed are written; a settled picture writes nothing.
	local count = 0
	for row, cells in screen.rows do
		eachRun(cells, function(cell: Cell): (Color3?, number)
			local level = levelOf(Weather.localConditions(cell.point, state))
			if level == 0 then
				return nil, 0
			end
			return LEVELS[level].color, LEVELS[level].transparency
		end, function(column, length, color, transparency)
			count += 1
			local key = string.format("%d:%d:%d:%s", row, column, length, tostring(color))
			if screen.keys[count] == key then
				return
			end
			screen.keys[count] = key
			local frame = screen.runs[count]
			if not frame then
				frame = runFrame(screen.rain, row, column, length, 2)
				screen.runs[count] = frame
			else
				frame.Position = UDim2.fromScale(column / CELLS, row / CELLS)
				frame.Size = UDim2.fromScale(length / CELLS, 1 / CELLS)
				frame.Visible = true
			end
			frame.BackgroundColor3 = color
			frame.BackgroundTransparency = transparency
		end)
	end
	for index = count + 1, #screen.runs do
		if screen.keys[index] then
			screen.keys[index] = nil
			screen.runs[index].Visible = false
		end
	end
	local center = screen.part.Position
	for index, mark in screen.marks do
		local tornado = tornadoes[index]
		local shown, u, v = false, 0, 0
		if tornado then
			local offset = tornado.position - Vector3.new(center.X, 0, center.Z)
			u = 0.5 + offset:Dot(screen.right) / (RANGE * 2)
			v = 0.5 + offset:Dot(screen.back) / (RANGE * 2)
			shown = (u - 0.5) ^ 2 + (v - 0.5) ^ 2 < 0.25
		end
		if mark.Visible ~= shown then
			mark.Visible = shown
		end
		if shown then
			mark.Position = UDim2.fromScale(u, v)
		end
	end
end

local function build(part: BasePart): Screen
	local gui = make("SurfaceGui", nil, {
		Name = "WeatherRadarGui",
		Face = Enum.NormalId.Top,
		SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
		CanvasSize = Vector2.new(CANVAS, CANVAS),
		LightInfluence = 0,
		Brightness = 1.2,
		MaxDistance = HIDE_DISTANCE,
		ClipsDescendants = true,
	})
	local land = make("Frame", gui, { Name = "Land", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	local rain = make("Frame", gui, { Name = "Rain", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	-- The table's own spot.
	for _, size in { UDim2.new(0, 14, 0, 2), UDim2.new(0, 2, 0, 14) } do
		make("Frame", gui, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = size,
			BorderSizePixel = 0,
			BackgroundColor3 = rgb(20, 20, 24),
			ZIndex = 4,
		})
	end
	local marks = {}
	for _ = 1, MAX_TORNADOES do
		local mark = make("Frame", gui, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(9, 9),
			BackgroundColor3 = rgb(255, 255, 255),
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 3,
		})
		make("UICorner", mark, { CornerRadius = UDim.new(0.5, 0) })
		make("UIStroke", mark, { Color = rgb(150, 20, 120), Thickness = 2 })
		table.insert(marks, mark)
	end
	-- A SurfaceGui on the top face draws its x along the part's +X and its y
	-- along +Z, so the disc is the world around the table seen from above.
	local right = part.CFrame.RightVector
	right = Vector3.new(right.X, 0, right.Z).Unit
	local back = right:Cross(Vector3.yAxis)
	local center = part.Position
	local rows = {}
	local half = CELLS / 2
	for row = 0, CELLS - 1 do
		local cells = {}
		for column = 0, CELLS - 1 do
			local x, y = column + 0.5 - half, row + 0.5 - half
			if x * x + y * y <= half * half then
				local offset = right * (x / half * RANGE) + back * (y / half * RANGE)
				table.insert(
					cells,
					{ column = column, point = Vector3.new(center.X + offset.X, 0, center.Z + offset.Z) }
				)
			end
		end
		rows[row] = cells
	end
	gui.Parent = part
	return {
		part = part,
		gui = gui,
		land = land,
		rain = rain,
		rows = rows,
		runs = {},
		marks = marks,
		right = right,
		back = back,
		landVersion = -1,
		keys = {},
	}
end

function Radar.start()
	if started then
		return
	end
	started = true
	local tracked: { [BasePart]: boolean } = {}
	local screens: { [BasePart]: Screen } = {}
	local function drop(part: BasePart)
		local screen = screens[part]
		if screen then
			screen.gui:Destroy()
			screens[part] = nil
		end
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(part)
		if part:IsA("BasePart") then
			tracked[part] = true
		end
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(part)
		tracked[part] = nil
		drop(part)
	end)
	for _, part in CollectionService:GetTagged(TAG) do
		if part:IsA("BasePart") then
			tracked[part] = true
		end
	end
	-- The chart arrives progressively while islands generate; repaint land once
	-- the records stop changing for a moment.
	task.spawn(function()
		local chart = ReplicatedStorage:WaitForChild("IslandChart")
		local pending = false
		local function reload()
			if pending then
				return
			end
			pending = true
			task.delay(1, function()
				pending = false
				local list = {}
				for _, record in chart:GetChildren() do
					local coast = readCoast(record)
					if coast then
						table.insert(list, coast)
					end
				end
				coasts = list
				coastVersion += 1
			end)
		end
		chart.ChildAdded:Connect(reload)
		chart.ChildRemoved:Connect(reload)
		reload()
	end)
	local scanElapsed, refreshElapsed = SCAN_INTERVAL, 0
	RunService.Heartbeat:Connect(function(dt: number)
		scanElapsed += dt
		refreshElapsed += dt
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		if scanElapsed >= SCAN_INTERVAL then
			scanElapsed = 0
			local eye = camera.CFrame.Position
			for part in tracked do
				-- Inventory thumbnails and replicated templates carry the tag too.
				local live = part.Parent ~= nil and part:IsDescendantOf(workspace)
				local distance = if live then (part.Position - eye).Magnitude else math.huge
				if screens[part] and distance > HIDE_DISTANCE then
					drop(part)
				elseif not screens[part] and distance < SHOW_DISTANCE then
					screens[part] = build(part)
					refreshElapsed = REFRESH_INTERVAL
				end
				if part.Parent == nil then
					tracked[part] = nil
				end
			end
		end
		if refreshElapsed >= REFRESH_INTERVAL and next(screens) then
			refreshElapsed = 0
			local now = workspace:GetServerTimeNow()
			local state = Weather.getState(now)
			local tornadoes = Weather.tornadoes(now)
			for _, screen in screens do
				refresh(screen, state, tornadoes)
			end
		end
	end)
end

return Radar
