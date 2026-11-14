-- One layout for client displays and server collision/purchase checks. No client-supplied
-- instance or position is trusted when buying a product.
local Catalog = require(script.Parent.TechCatalog)

local Layout = {}
Layout.X0, Layout.X1 = -180, 180
Layout.Z0, Layout.Z1 = -150, 75
Layout.Height, Layout.Floor = 36, 0.3
Layout.RackWidth, Layout.RackDepth = 86, 6.4
Layout.MonitorZ, Layout.MonitorPromptZ = -140, -137.5
Layout.LicenseX, Layout.LicenseZ = 122, 52
Layout.HelpX, Layout.HelpZ = -120, -64
Layout.Checkouts = { -153, -139, -125, -111, -97, -83, -69, -55 }
Layout.CheckoutZ = 52
Layout.PromptName = "BuyTechProduct"
Layout.BuyDistance = 6
Layout.HoldDuration = 0.8
Layout.Departments = {
	{ Slot = "CPU", Title = "01   PROCESSORS", X = -120, Z = -94, Turn = 0, Extra = "Motherboard", ExtraTitle = "01B   MOTHERBOARDS" },
	{ Slot = "GPU", Title = "02   GRAPHICS CARDS", X = 0, Z = -94, Turn = math.pi / 2, Width = 72 },
	{ Slot = "RAM", Title = "03   MEMORY", X = 120, Z = -94, Turn = 0 },
	{ Slot = "Storage", Title = "04   STORAGE", X = -120, Z = -14, Turn = math.pi / 2 },
	{ Slot = "Cooling", Title = "05   COOLING", X = 0, Z = -14, Turn = 0, Extra = "PSU", ExtraTitle = "05B   POWER SUPPLIES" },
	{ Slot = "Case", Title = "06   CASES", X = 120, Z = -14, Turn = math.pi / 2 },
}
Layout.Racks = {}
for _, department in Layout.Departments do
	for row = -1, 1 do
		local frame = CFrame.new(department.X, 0, department.Z) * CFrame.Angles(0, department.Turn, 0) * CFrame.new(0, 0, row * 16)
		-- A department with a second product line shows it on its middle rack.
		local extra = if row == 0 then department.Extra else nil
		table.insert(Layout.Racks, { Slot = extra or department.Slot, Title = if extra then department.ExtraTitle else department.Title,
			X = frame.Position.X, Z = frame.Position.Z, Frame = frame,
			Width = department.Width or Layout.RackWidth, Showcase = row == 1 or extra ~= nil })
	end
end

Layout.PrebuiltStations = {
	{ Id = "HarbourHome", Frame = CFrame.new(-32, 0, 22) * CFrame.Angles(0, math.rad(-10), 0) },
	{ Id = "HarbourOffice", Frame = CFrame.new(120, 0, -65) * CFrame.Angles(0, math.pi, 0) },
	{ Id = "ReefCreator", Frame = CFrame.new(-5, 0, 35) * CFrame.Angles(0, math.rad(12), 0) },
	{ Id = "RiptideGaming", Frame = CFrame.new(26, 0, 23) * CFrame.Angles(0, math.rad(-12), 0) },
	{ Id = "ArcticStudio", Frame = CFrame.new(-54, 0, 5) * CFrame.Angles(0, math.rad(18), 0) },
	{ Id = "KrakenUltra", Frame = CFrame.new(54, 0, 4) * CFrame.Angles(0, math.rad(-18), 0) },
}

-- Two branching loops weave past alternating horizontal and vertical departments. Short
-- crossovers let shoppers take a direct route; arrows suggest a tour without forcing it.
local function points(coords)
	local result = {}
	for _, p in coords do table.insert(result, Vector3.new(p[1], 0, p[2])) end
	return result
end
Layout.Paths = {
	{ Name = "EastShowroomLoop", Width = 8, Points = points({ {0,66},{42,42},{65,34},{72,-42},{58,-58},{62,-122},{170,-124},{170,-62},{154,-46},{154,38},{62,38},{0,66} }) },
	{ Name = "WestShowroomLoop", Width = 8, Points = points({ {0,66},{-42,42},{-65,34},{-72,-42},{-58,-58},{-62,-122},{-170,-124},{-170,-62},{-154,-46},{-154,38},{-62,38},{-32,40},{0,52},{0,66} }) },
	{ Name = "DepartmentCrossover", Width = 10, Points = points({ {-72,-42},{0,-44},{72,-42} }) },
	{ Name = "PrebuiltWalk", Width = 8, Points = points({ {0,66},{0,52},{26,42},{65,34} }) },
}
Layout.Displays = {}
local lookup = {}

local function display(kind, id, frame, promptFrame, rack)
	local entry = { Kind = kind, Id = id, Frame = frame, PromptFrame = promptFrame, Rack = rack }
	table.insert(Layout.Displays, entry)
	lookup[kind .. ":" .. id] = entry
end

for rackIndex, rack in Layout.Racks do
	if not rack.Showcase then continue end
	for index, id in Catalog.Order[rack.Slot] do
		local side = if index <= 3 then 1 else -1
		local column = (index - 1) % 3 - 1
		local turn = CFrame.Angles(0, if side == 1 then 0 else math.pi, 0)
		display("Item", id, rack.Frame * CFrame.new(column * 28, 3.4, side * 1.65) * turn,
			rack.Frame * CFrame.new(column * 28, 3.1, side * 3.55) * turn, rackIndex)
	end
end
for index, id in Catalog.Order.Monitor do
	local x = -140 + (index - 1) * 56
	display("Item", id, CFrame.new(x, 3.4, Layout.MonitorZ), CFrame.new(x, 3.1, Layout.MonitorPromptZ), "Monitors")
end
for index, id in Catalog.LicenseOrder do
	local x = Layout.LicenseX - 16 + (index - 1) * 32
	display("License", id, CFrame.new(x, 3.4, Layout.LicenseZ), CFrame.new(x, 3.1, Layout.LicenseZ + 2.3), "Licenses")
end
for _, station in Layout.PrebuiltStations do
	display("Prebuilt", station.Id, station.Frame * CFrame.new(0, 3.4, 0),
		station.Frame * CFrame.new(0, 3.1, 5.3), "Prebuilts")
end

function Layout.inside(frame: CFrame, position: Vector3): boolean
	local p = frame:PointToObjectSpace(position)
	return p.X > Layout.X0 and p.X < Layout.X1
		and p.Z > Layout.Z0 and p.Z < Layout.Z1
		and p.Y >= Layout.Floor and p.Y < Layout.Height
end

function Layout.product(kind: string, id: string)
	return lookup[kind .. ":" .. id]
end

function Layout.nearProduct(frame: CFrame, position: Vector3, kind: string, id: string): boolean
	local entry = Layout.product(kind, id)
	return entry ~= nil and Layout.inside(frame, position)
		and (position - (frame * entry.PromptFrame).Position).Magnitude <= Layout.BuyDistance + 1
end

return Layout
