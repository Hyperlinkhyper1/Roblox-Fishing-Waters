-- Player cafés in the city's café quarter (ModernCity.cafeSites). One plot per
-- harbour plot (fifteen). Each block is built like the rest of the city: a
-- mixed-use building on the avenue with flats above, and a lower one behind it
-- facing the back street. The café is the avenue building's ground-floor unit, a
-- deliberately plain one-floor café that later updates can furnish: an empty
-- customer floor on the fishing house's 11 x 7 build lattice, a service counter
-- with a till and a coffee machine, and a staff room with one storage rack and
-- the same office PC as the fishing bases.
--
-- A café only shows while a company runs it (CafePlots.setOpen, from
-- CafeService). Until then the unit is an ordinary closed shopfront and the café's
-- frontage, furniture and lights wait in ServerStorage, so nobody sees or walks
-- into an empty café.
--
-- Café-local frame (CafeCatalog): origin on the customer floor's centre at floor
-- level, +Z toward the street. The plot model carries it as "CafeFrame".
-- CafeService claims plots and runs customers; the client (Cafe) shows prompts.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CafeCatalog = require(ReplicatedStorage.Shared.CafeCatalog)
local City = require(script.Parent.ModernCity)
local CityBuildings = require(script.Parent.CityBuildings)
local OfficeDesk = require(script.Parent.OfficeDesk)
local StorageRack = require(script.Parent.StorageRack)
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))

local CafePlots = {}
CafePlots.VERSION = 2 -- 2: cafés are ground-floor units of city buildings, shown only while owned
CafePlots.FOLDER = "CafePlots"
-- Where each plot's hidden half (the café, or its closed shopfront) waits.
local STASH = "CafeStash"

local rgb = Color3.fromRGB
local M = Enum.Material

local HW = CafeCatalog.HALF_WIDTH
local FRONT = CafeCatalog.FRONT
local PARTITION = CafeCatalog.PARTITION
local BACK = CafeCatalog.BACK
local H = CafeCatalog.WALL_HEIGHT
local T = 0.8 -- wall thickness; walls stand just outside the build lattice
local SETBACK = 4 -- the city's pavement: the café front stands on the building line
local YARD = 3 -- service yard between the avenue building and the one behind it

local PLASTER = rgb(236, 228, 210)
local TRIM = rgb(74, 62, 54)
local WOOD_FLOOR = rgb(176, 134, 92)
local TILE = rgb(154, 154, 148)
local PAVEMENT = rgb(150, 148, 140)
local COUNTER = rgb(238, 234, 226)
local COUNTER_TOP = rgb(96, 70, 50)
local CHROME = rgb(176, 178, 180)
local DARK = rgb(42, 40, 40)
local AWNING = rgb(46, 92, 72)
local AWNING_STRIPE = rgb(236, 226, 200)
local GLASS = rgb(170, 200, 210)

-- Plot pieces never take touches; collision and queries only where it matters.
local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, solid: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanTouch = false
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = solid ~= false
	p.CanQuery = solid ~= false
	if solid == false then
		p.CastShadow = math.max(size.X, size.Y, size.Z) > 1.5
	end
	p.Parent = parent
	return p
end

local function group(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

-- A box spanning café-local x0..x1, y0..y1, z0..z1.
local function box(parent: Instance, name: string, frame: CFrame, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number, color: Color3, material: Enum.Material, solid: boolean?): Part
	return part(
		parent,
		name,
		Vector3.new(x1 - x0, y1 - y0, z1 - z0),
		frame * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
		color,
		material,
		solid
	)
end

local function sign(board: BasePart, face: Enum.NormalId, text: string, size: number?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.4
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	label.Text = text
	Theme.text(label)
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = rgb(250, 244, 230)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0.04, 0), UDim.new(0.04, 0)
	padding.PaddingTop, padding.PaddingBottom = UDim.new(0.12, 0), UDim.new(0.12, 0)
	padding.Parent = label
	if size then
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = size
		limit.Parent = label
	end
	label.Parent = gui
	gui.Parent = board
	return label
end

local function light(parent: Instance, frame: CFrame, x: number, z: number, range: number)
	local panel = box(parent, "CeilingLight", frame, x - 1.6, x + 1.6, H - 0.55, H - 0.35, z - 1.6, z + 1.6, rgb(255, 246, 226), M.Neon, false)
	local glow = Instance.new("PointLight")
	glow.Range = range
	glow.Brightness = 1.1
	glow.Color = rgb(255, 236, 206)
	glow.Shadows = false
	glow.Parent = panel
end

-- What stays in the building whether or not the café is open: floors, the side,
-- back and partition walls and the ceiling, all hidden behind the shopfront while
-- the unit is closed. The back wall is the building's own at street level.
local function buildShell(plot: Model, frame: CFrame, look)
	local shell = group(plot, "Building")
	-- Floors, flush with the lattice at y = 0.
	box(shell, "CafeFloor", frame, -HW - T, HW + T, -0.3, 0, PARTITION, FRONT + T, WOOD_FLOOR, M.WoodPlanks)
	box(shell, "StaffFloor", frame, -HW - T, HW + T, -0.3, 0, BACK - T, PARTITION, TILE, M.Concrete)
	-- Side and back walls.
	box(shell, "SideWall", frame, -HW - T, -HW, 0, H, BACK - T, FRONT, PLASTER, M.Plaster)
	box(shell, "SideWall", frame, HW, HW + T, 0, H, BACK - T, FRONT, PLASTER, M.Plaster)
	box(shell, "BackWall", frame, -HW, HW, 0, H, BACK - T, BACK, look.wall, look.mat)
	-- The partition between the floor and the staff room, with a staff door.
	local pz0, pz1 = PARTITION - T / 2, PARTITION + T / 2
	box(shell, "Partition", frame, -HW, 17, 0, H, pz0, pz1, PLASTER, M.Plaster)
	box(shell, "Partition", frame, 21.5, HW, 0, H, pz0, pz1, PLASTER, M.Plaster)
	box(shell, "StaffDoorHeader", frame, 17, 21.5, 8.5, H, pz0, pz1, PLASTER, M.Plaster)
	-- The ceiling; the flats above start on top of it.
	box(shell, "Ceiling", frame, -HW, HW, H - 0.3, H, BACK, FRONT, PLASTER, M.Plaster)
end

-- Street-level shopfront dressing in the building's own style (CityBuildings.block):
-- a dark base course and a tinted glass band that lights up after dark.
local function shopfront(parent: Instance, frame: CFrame, look, x0: number, x1: number, seed: number)
	local z = FRONT + T
	box(parent, "Plinth", frame, x0, x1, -0.3, 1.3, z, z + 0.2, look.roof, M.Concrete, false)
	if x1 - x0 < 2 then
		return
	end
	local glass = box(parent, "Shopfront", frame, x0 + 0.6, x1 - 0.6, 1.6, 10.4, z, z + 0.15, look.glass, M.Glass, false)
	glass.Reflectance = 0.05
	glass:AddTag("NightGlow")
	glass:SetAttribute("GlowColor", rgb(232, 200, 150))
	glass:SetAttribute("GlowAt", 0.3 + (seed % 5) * 0.08)
end

-- The rest of the ground floor either side of the café unit: solid, with shop windows.
local function buildGround(plot: Model, frame: CFrame, look, lotW: number, id: number)
	local ground = group(plot, "GroundFloor")
	local edge = lotW / 2
	if edge - (HW + T) < 0.05 then
		return
	end
	for _, side in { -1, 1 } do
		local x0, x1 = if side < 0 then -edge else HW + T, if side < 0 then -HW - T else edge
		box(ground, "Unit", frame, x0, x1, -0.3, H, BACK - T, FRONT + T, look.wall, look.mat)
		shopfront(ground, frame, look, x0, x1, id + side)
	end
end

-- The unit while nobody runs a café in it: a shuttered shopfront like its neighbours.
local function buildClosed(plot: Model, frame: CFrame, look, id: number): Model
	local closed = group(plot, "Closed")
	box(closed, "Front", frame, -HW - T, HW + T, 0, H, FRONT, FRONT + T, look.wall, look.mat)
	shopfront(closed, frame, look, -HW - T, -1, id * 3)
	shopfront(closed, frame, look, 1, HW + T, id * 3 + 1)
	return closed
end

-- Everything that makes the unit a café: its frontage, signs, lights and furniture.
local function buildFront(cafe: Model, frame: CFrame, id: number)
	-- Street front: big windows either side of a central door.
	local fz0, fz1 = FRONT, FRONT + T
	local front = group(cafe, "FrontWall")
	box(front, "Pier", frame, -HW - T, -21, 0, H, fz0, fz1, PLASTER, M.Plaster)
	box(front, "Pier", frame, 21, HW + T, 0, H, fz0, fz1, PLASTER, M.Plaster)
	for _, side in { -1, 1 } do
		local a, b = if side < 0 then -21 else 5, if side < 0 then -5 else 21
		box(front, "Sill", frame, a, b, 0, 2.5, fz0, fz1, TRIM, M.Wood)
		box(front, "Header", frame, a, b, 10, H, fz0, fz1, PLASTER, M.Plaster)
		local pane = box(front, "Window", frame, a, b, 2.5, 10, fz0 + 0.3, fz1 - 0.3, GLASS, M.Glass)
		pane.Transparency = 0.65
		pane:SetAttribute("PreserveGlassMaterial", true)
		box(front, "Mullion", frame, (a + b) / 2 - 0.15, (a + b) / 2 + 0.15, 2.5, 10, fz0 + 0.2, fz1 - 0.2, TRIM, M.Wood)
		local jamb0, jamb1 = if side < 0 then -5 else 3, if side < 0 then -3 else 5
		box(front, "DoorJamb", frame, jamb0, jamb1, 0, H, fz0, fz1, TRIM, M.Wood)
	end
	box(front, "DoorHeader", frame, -3, 3, 9, H, fz0, fz1, PLASTER, M.Plaster)
	box(front, "Plinth", frame, -HW - T - 0.05, -5, 0, 0.9, FRONT + T, FRONT + T + 0.05, TRIM, M.Concrete, false)
	box(front, "Plinth", frame, 5, HW + T + 0.05, 0, 0.9, FRONT + T, FRONT + T + 0.05, TRIM, M.Concrete, false)
	local pz1 = PARTITION + T / 2
	local staffSign = box(cafe, "StaffSign", frame, 17.4, 21.1, 9.2, 10.6, pz1, pz1 + 0.1, TRIM, M.SmoothPlastic, false)
	sign(staffSign, Enum.NormalId.Back, "STAFF ONLY", 28)

	-- Striped awning over the windows and door.
	local awning = group(cafe, "Awning")
	local stripes = 11
	for index = 0, stripes - 1 do
		local x0 = -22 + index * 44 / stripes
		local strip = part(
			awning,
			"AwningStripe",
			Vector3.new(44 / stripes, 0.2, 3.4),
			frame * CFrame.new(x0 + 22 / stripes, 10.2, FRONT + T + 1.55) * CFrame.Angles(math.rad(18), 0, 0),
			if index % 2 == 0 then AWNING else AWNING_STRIPE,
			M.Fabric,
			false
		)
		strip.CanCollide = false
	end
	-- Name board above the awning (CafeService writes the company name).
	local board = box(cafe, "NameBoard", frame, -12, 12, 10.9, 12.7, FRONT + T, FRONT + T + 0.25, AWNING, M.SmoothPlastic, false)
	sign(board, Enum.NormalId.Back, string.format("CAFÉ · %02d", id), 64)

	local lights = group(cafe, "Lights")
	light(lights, frame, -12, 6, 26)
	light(lights, frame, 12, 6, 26)
	light(lights, frame, -12, -8, 24)
	light(lights, frame, 12, -8, 24)
	light(lights, frame, -6, (PARTITION + BACK) / 2, 26)
	light(lights, frame, 12, (PARTITION + BACK) / 2, 22)
end

local function buildCoffeeMachine(parent: Instance, frame: CFrame): Model
	-- frame: on the bench top, +Z toward the barista.
	local machine = group(parent, "CoffeeMachine")
	local body = part(machine, "Body", Vector3.new(2.6, 2.4, 1.6), frame * CFrame.new(0, 1.2, -0.1), CHROME, M.Metal)
	body.CanCollide = false
	part(machine, "Top", Vector3.new(2.7, 0.18, 1.7), frame * CFrame.new(0, 2.49, -0.1), DARK, M.Metal, false)
	part(machine, "Panel", Vector3.new(2.2, 0.6, 0.05), frame * CFrame.new(0, 1.95, 0.72), DARK, M.SmoothPlastic, false)
	for _, x in { -0.55, 0.55 } do
		part(machine, "GroupHead", Vector3.new(0.5, 0.35, 0.5), frame * CFrame.new(x, 1.35, 0.85), DARK, M.Metal, false)
		part(machine, "Lamp", Vector3.new(0.12, 0.12, 0.05), frame * CFrame.new(x, 2.0, 0.76), rgb(255, 140, 60), M.Neon, false)
	end
	part(machine, "DripTray", Vector3.new(2.2, 0.15, 0.7), frame * CFrame.new(0, 0.1, 0.95), DARK, M.Metal, false)
	part(machine, "Cup", Vector3.new(0.35, 0.4, 0.35), frame * CFrame.new(0.55, 0.38, 0.85), rgb(250, 248, 242), M.SmoothPlastic, false)
	local vent = part(machine, "SteamVent", Vector3.new(0.4, 0.1, 0.4), frame * CFrame.new(-0.7, 2.6, -0.3), DARK, M.Metal, false)
	vent.Transparency = 1
	local steam = Instance.new("ParticleEmitter")
	steam.Name = "Steam"
	steam.Enabled = false
	steam.Rate = 18
	steam.Lifetime = NumberRange.new(0.8, 1.4)
	steam.Speed = NumberRange.new(1.5, 2.5)
	steam.SpreadAngle = Vector2.new(12, 12)
	steam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1.2) })
	steam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	steam.Color = ColorSequence.new(rgb(240, 240, 240))
	steam.Parent = vent
	machine.PrimaryPart = body
	return machine
end

local function buildService(plot: Model, frame: CFrame)
	local service = group(plot, "Service")
	-- Counter from the left wall to x = 13.5; the gap on the right leads to the staff door.
	local front = CafeCatalog.COUNTER_FRONT
	box(service, "Counter", frame, -HW, 13.5, 0, 3.4, front - 2.2, front, COUNTER, M.SmoothPlastic)
	box(service, "CounterTop", frame, -HW, 13.7, 3.4, 3.6, front - 2.3, front + 0.15, COUNTER_TOP, M.Wood)
	box(service, "CounterKick", frame, -HW, 13.5, 0, 0.4, front - 0.05, front + 0.02, TRIM, M.Wood, false)
	-- Back bench against the partition, with the coffee machine behind the till.
	local benchZ0 = PARTITION + T / 2
	box(service, "BackBench", frame, -HW, 13.5, 0, 3.4, benchZ0, benchZ0 + 2, COUNTER, M.SmoothPlastic)
	box(service, "BenchTop", frame, -HW, 13.5, 3.4, 3.6, benchZ0, benchZ0 + 2.1, COUNTER_TOP, M.Wood)
	buildCoffeeMachine(service, frame * CFrame.new(CafeCatalog.REGISTER_X, 3.6, benchZ0 + 0.9))
	-- Till on the counter, screen toward the barista.
	local x = CafeCatalog.REGISTER_X
	local till = group(service, "Register")
	part(till, "Base", Vector3.new(1.8, 0.5, 1.3), frame * CFrame.new(x, 3.85, front - 1.1), DARK, M.SmoothPlastic, false)
	part(till, "Screen", Vector3.new(1.4, 0.9, 0.12), frame * CFrame.new(x, 4.5, front - 1.35) * CFrame.Angles(math.rad(-15), math.pi, 0), rgb(30, 60, 40), M.Glass, false)
	-- A stack of cups and a menu board above the bench.
	for index = 0, 3 do
		part(service, "CupStack", Vector3.new(0.4, 0.42, 0.4), frame * CFrame.new(x + 3, 3.81 + index * 0.4, benchZ0 + 1), rgb(250, 248, 242), M.SmoothPlastic, false)
	end
	local menu = box(service, "MenuBoard", frame, x - 5, x + 5, 6.4, 10, benchZ0, benchZ0 + 0.15, DARK, M.SmoothPlastic, false)
	sign(menu, Enum.NormalId.Back, string.format("MENU\nCOFFEE  $%d", CafeCatalog.COFFEE_PRICE), 60)
end

local function buildStaffRoom(plot: Model, frame: CFrame)
	local staff = group(plot, "StaffRoom")
	StorageRack.build(staff, frame * CFrame.new(-18, 0, BACK + 0.05 + StorageRack.DEPTH / 2))
	OfficeDesk.build(staff, frame * CFrame.new(4.5, 0, BACK + 0.05 + OfficeDesk.DEPTH / 2))
end

local function stashFolder(): Folder
	local folder = ServerStorage:FindFirstChild(STASH)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = STASH
		folder.Parent = ServerStorage
	end
	return folder :: Folder
end

-- The holder for one plot's hidden half (plot names are unique: Cafe01…).
local function holderFor(plot: Model): Folder
	local stash = stashFolder()
	local holder = stash:FindFirstChild(plot.Name)
	if not holder then
		holder = Instance.new("Folder")
		holder.Name = plot.Name
		holder.Parent = stash
	end
	return holder :: Folder
end

local function piecesOf(plot: Model, name: string): Instance?
	local found = plot:FindFirstChild(name)
	if found then
		return found
	end
	local holder = stashFolder():FindFirstChild(plot.Name)
	return holder and holder:FindFirstChild(name)
end

-- Anyone standing in the unit when it shuts steps out onto the pavement.
local function evict(plot: Model)
	local frame = plot:GetAttribute("CafeFrame")
	if typeof(frame) ~= "CFrame" then
		return
	end
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local at = frame:PointToObjectSpace(root.Position)
			if math.abs(at.X) <= HW + T + 0.5 and at.Z >= BACK - T - 0.5 and at.Z <= FRONT + T + 0.2 and at.Y > -2 and at.Y < H + 2 then
				character:PivotTo(frame * CFrame.new(CafeCatalog.DOOR_OUTSIDE + Vector3.new(0, 3, 0)) * root.CFrame.Rotation)
			end
		end
	end
end

local function buildPlot(parent: Instance, site, id: number): Model
	local plot = Instance.new("Model")
	plot.Name = string.format("Cafe%02d", id)
	plot.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local block = site.cframe
	local curb = City.CAFE_CURB - City.CAFE_TOP
	-- The whole block is the café's lot, paved like the city around it.
	part(plot, "Lot", Vector3.new(site.w, 0.9, site.d), block * CFrame.new(0, 0.45, 0), PAVEMENT, M.Concrete)
	local lotW, lotD = site.w - 2 * SETBACK, site.d - 2 * SETBACK
	local frame = block * CFrame.new(0, curb + 0.3, lotD / 2 - FRONT - T)
	plot:SetAttribute("CafeFrame", frame)
	plot:SetAttribute("PlotId", id)
	plot:SetAttribute("OwnerUserId", 0)
	plot:SetAttribute("CompanyId", "")
	plot:SetAttribute("CafeVersion", CafePlots.VERSION)
	plot:SetAttribute("CafeOpen", false)

	-- The avenue building: the café is its ground floor, flats rise above it.
	local variant = id * 7 + 3
	local look = CityBuildings.blockLook(variant)
	local depth = FRONT - BACK + 2 * T
	CityBuildings.block(plot, frame * CFrame.new(0, -0.3, (FRONT + BACK) / 2), lotW, depth, 4 + id % 3, variant, H + 0.3).Name = "AvenueBuilding"
	buildShell(plot, frame, look)
	buildGround(plot, frame, look, lotW, id)
	-- A lower building behind it faces the back street across a service yard.
	local backDepth = lotD - depth - YARD
	if backDepth >= 8 then
		local z = -lotD / 2 + backDepth / 2
		CityBuildings.block(plot, block * CFrame.new(0, curb, z) * CFrame.Angles(0, math.pi, 0), lotW - 0.3, backDepth, 2 + (id + 1) % 3, variant + 5).Name = "BackBuilding"
	end

	local closed = buildClosed(plot, frame, look, id)
	local cafe = group(plot, "Cafe")
	buildFront(cafe, frame, id)
	buildService(cafe, frame)
	buildStaffRoom(cafe, frame)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnPoint"
	spawn.Anchored = true
	spawn.Size = Vector3.new(5, 0.2, 5)
	spawn.CFrame = frame * CFrame.new(16, 0.2, 4)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = plot
	plot:AddTag(CafeCatalog.PLOT_TAG)
	-- Built shut: the café waits in ServerStorage until a company claims the plot.
	cafe.Parent = holderFor(plot)
	closed.Parent = plot
	plot.Parent = parent
	return plot
end

-- Shows the café (a company runs it) or the closed shopfront (nobody does).
-- Anyone inside a café that closes is moved out onto the pavement first.
function CafePlots.setOpen(plot: Model, open: boolean)
	local show = piecesOf(plot, if open then "Cafe" else "Closed")
	local hide = piecesOf(plot, if open then "Closed" else "Cafe")
	if not open and hide and hide.Parent == plot then
		evict(plot)
	end
	if hide then
		hide.Parent = holderFor(plot)
	end
	if show then
		show.Parent = plot
	end
	plot:SetAttribute("CafeOpen", open)
end

-- Builds the café plots once per server (or repairs an older baked set). The
-- plots stand on their own paved lots, so they work before the city finishes.
-- Every plot starts closed: nobody owns one until CafeService claims it.
function CafePlots.ensure(root: Instance): Folder
	local existing = root:FindFirstChild(CafePlots.FOLDER)
	local complete = existing ~= nil and existing:GetAttribute("CafeVersion") == CafePlots.VERSION
	if complete then
		-- A baked set whose hidden cafés were not saved with it is rebuilt.
		for _, plot in (existing :: Instance):GetChildren() do
			if plot:IsA("Model") and not (piecesOf(plot, "Cafe") and piecesOf(plot, "Closed")) then
				complete = false
			end
		end
	end
	if existing and complete then
		for _, plot in existing:GetChildren() do
			if plot:IsA("Model") and (plot:GetAttribute("CompanyId") or "") == "" then
				CafePlots.setOpen(plot, false)
			end
		end
		return existing :: Folder
	end
	if existing then
		existing:Destroy()
	end
	local stash = ServerStorage:FindFirstChild(STASH)
	if stash then
		stash:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = CafePlots.FOLDER
	folder:SetAttribute("CafeVersion", CafePlots.VERSION)
	for id, site in City.cafeSites() do
		buildPlot(folder, site, id)
		if id % 3 == 0 then
			task.wait()
		end
	end
	folder.Parent = root
	return folder
end

function CafePlots.plots(): { Model }
	local plots = {}
	for _, plot in CollectionService:GetTagged(CafeCatalog.PLOT_TAG) do
		if plot:IsA("Model") and plot:IsDescendantOf(workspace) then
			table.insert(plots, plot)
		end
	end
	table.sort(plots, function(a, b)
		return (a:GetAttribute("PlotId") or 0) < (b:GetAttribute("PlotId") or 0)
	end)
	return plots
end

return CafePlots
