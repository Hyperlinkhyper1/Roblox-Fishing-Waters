-- Permanent bare racks, furniture, signs and building details. Built by Map/TechStore so
-- they remain visible to shoppers outside; merchandise is built separately on their client.
local Catalog = require(script.Parent.TechCatalog)
local Layout = require(script.Parent.TechStoreLayout)
local Fixtures = {}
local rgb, M = Color3.fromRGB, Enum.Material
local WHITE, RED, NAVY = rgb(234, 237, 240), rgb(204, 22, 34), rgb(20, 36, 82)
local DARK, STEEL, GOLD = rgb(28, 31, 38), rgb(156, 166, 178), rgb(217, 174, 75)
-- Interior finishes: graphite counters, dark upper walls and an exposed black ceiling keep the
-- hall moody so the lit merchandise and department colours carry the room.
local COUNTER, COUNTER_TOP = rgb(50, 54, 60), rgb(196, 198, 200)
local WALL_UPPER, WAINSCOT = rgb(78, 82, 88), rgb(42, 45, 50)
local CEILING, STRUCTURE = rgb(30, 32, 36), rgb(48, 52, 58)
local GROUT, ROUTE, ROUTE_ALT = rgb(70, 73, 78), rgb(110, 118, 128), rgb(64, 98, 124)
local LAMP = rgb(196, 190, 178)
local ACCENTS = { CPU = rgb(54, 127, 235), GPU = rgb(106, 210, 80), RAM = rgb(206, 92, 231),
	Storage = rgb(250, 162, 55), Cooling = rgb(53, 210, 224), Case = rgb(239, 77, 110), Monitor = rgb(94, 161, 255),
	Motherboard = rgb(70, 190, 150), PSU = rgb(240, 206, 70) }

function Fixtures.build(parent: Instance, base: CFrame)
	local function part(name, size, frame, color, material, shape)
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame = name, size, base * frame
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
		p.CastShadow = false
		p.Color, p.Material = color, material or M.SmoothPlastic
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		if shape then p.Shape = shape end
		p.Parent = parent
		return p
	end
	local function box(name, x, y, z, sx, sy, sz, color, material)
		return part(name, Vector3.new(sx, sy, sz), CFrame.new(x, y, z), color, material)
	end
	local function sign(board, text, face, tint)
		local gui = Instance.new("SurfaceGui")
		gui.Name, gui.Face = "ProductSign", face or Enum.NormalId.Back
		gui.SizingMode, gui.PixelsPerStud = Enum.SurfaceGuiSizingMode.PixelsPerStud, 55
		gui.MaxDistance, gui.LightInfluence = if board.Size.X >= 30 then 300 else 75, 0.1
		local label = Instance.new("TextLabel")
		label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
		label.Text, label.TextScaled, label.TextWrapped = text, true, true
		label.Font, label.TextColor3 = Enum.Font.GothamBold, tint or WHITE
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft, padding.PaddingRight = UDim.new(0.04, 0), UDim.new(0.04, 0)
		padding.PaddingTop, padding.PaddingBottom = UDim.new(0.06, 0), UDim.new(0.06, 0)
		padding.Parent, label.Parent, gui.Parent = label, gui, board
	end
	local function badge(text, frame, w, h, color)
		local board = part("DepartmentSign", Vector3.new(w, h, 0.12), frame, color or NAVY)
		sign(board, text)
		return board
	end
	local function localPart(frame, name, x, y, z, sx, sy, sz, color, material, shape, rotation)
		return part(name, Vector3.new(sx, sy, sz), frame * CFrame.new(x, y, z) * (rotation or CFrame.identity), color, material, shape)
	end
	local centerZ = (Layout.Z0 + Layout.Z1) / 2
	local depth = Layout.Z1 - Layout.Z0

	-- Floor markings sit on two clearly separated layers above the slab (top 0.3): grout, then
	-- the main loops (same colour, so their overlaps cannot flicker), then the crossover and
	-- prebuilt walk. Each visible top face is >= 0.02 studs from the next, not 0.002.
	for x = -174, 174, 12 do box("TileGrout", x, 0.31, centerZ, 0.035, 0.02, depth, GROUT) end
	for z = -144, 72, 12 do box("TileGrout", 0, 0.31, z, 360, 0.02, 0.035, GROUT) end
	for index, route in Layout.Paths do
		local upper = index > 2
		local tint = if upper then ROUTE_ALT else ROUTE
		local lift = Vector3.new(0, if upper then 0.37 else 0.335, 0)
		for step = 1, #route.Points - 1 do
			local a, b = route.Points[step], route.Points[step + 1]
			local frame = CFrame.lookAt((a + b) / 2 + lift, b + lift)
			part(route.Name, Vector3.new(route.Width, 0.016, (b - a).Magnitude + route.Width / 2), frame, tint)
			for _, side in {-1, 1} do
				part("RouteArrow", Vector3.new(0.2, 0.012, 1.8),
					frame * CFrame.new(side * 0.5, 0.014, 0) * CFrame.Angles(0, -side * 0.6, 0), rgb(196, 200, 204))
			end
		end
	end
	box("EntranceAvenue", 0, 0.335, 67.5, 24, 0.016, 5, ROUTE)

	-- Interior wall and ceiling liners: the shell's light concrete stays outside, the hall gets
	-- dark upper walls, a charcoal wainscot and a black exposed ceiling.
	for _, side in {-1, 1} do
		box("WallLiner", side * 179.95, 18.15, centerZ + 0.05, 0.1, 35.7, depth - 0.1, WALL_UPPER)
		box("Wainscot", side * 179.85, 4.65, centerZ + 0.1, 0.1, 8.7, depth - 0.2, WAINSCOT)
		box("WallSkirting", side * 179.7, 0.7, centerZ, 0.15, 0.8, depth - 1, DARK)
		box("InteriorBand", side * 179.7, 17, centerZ, 0.12, 1.5, depth - 1, RED)
		-- Steel portal columns on the long walls, clear of every rack and route.
		for z = -138, 58, 28 do box("WallColumn", side * 179.4, 18.1, z, 1, 35.6, 1.2, STRUCTURE, M.Metal) end
	end
	box("WallLiner", 0, 18.15, Layout.Z0 + 0.05, 359.8, 35.7, 0.1, WALL_UPPER)
	box("Wainscot", 0, 4.65, Layout.Z0 + 0.15, 359.6, 8.7, 0.1, WAINSCOT)
	box("WallLiner", 0, 25.5, Layout.Z1 - 0.05, 359.8, 21, 0.1, WALL_UPPER)
	box("WallLiner", 0, 14, Layout.Z1 - 0.05, 28, 2, 0.1, WALL_UPPER)
	box("CeilingDeck", 0, 35.95, centerZ, 360, 0.1, depth, CEILING)
	for x = -165, 165, 30 do box("RoofPurlin", x, 35.6, centerZ, 0.5, 0.6, depth - 0.2, STRUCTURE, M.Metal) end
	for _, x in {-68, 68} do
		part("AirDuct", Vector3.new(depth - 4, 2.6, 2.6), CFrame.new(x, 31.6, centerZ) * CFrame.Angles(0, math.pi / 2, 0),
			rgb(84, 88, 94), M.Metal, Enum.PartType.Cylinder)
	end

	-- Twelve suspended linear fittings, each with one unshadowed warm light: dimmer and warmer
	-- than the old bare neon strips so the hall no longer washes out.
	for _, z in {-128, -72, -16, 40} do
		box("WarehouseBeam", 0, 35, z, 358, 1.2, 0.65, STRUCTURE, M.Metal)
		for _, x in {-120, 0, 120} do
			box("LightHousing", x, 33.65, z, 73, 0.5, 1.6, rgb(36, 38, 42), M.Metal)
			local strip = box("LightDiffuser", x, 33.32, z, 72, 0.16, 1.1, LAMP, M.Neon)
			for _, dx in {-30, 30} do box("LightHanger", x + dx, 34.15, z, 0.08, 0.5, 0.08, STEEL, M.Metal) end
			local light = Instance.new("PointLight")
			light.Color, light.Range, light.Brightness, light.Shadows = rgb(255, 238, 214), 72, 1.15, false
			light.Parent = strip
		end
	end
	for _, x in {-45, 45} do box("CableTray", x, 34.3, -36, 1.2, 0.4, 220, DARK, M.Metal) end
	badge("MICRO HARBOUR  /  THE TECHNOLOGY MEGASTORE",CFrame.new(0,29,-149.6),300,4.5,RED)
	badge("07   MONITOR EXPERIENCE",CFrame.new(0,21,-149.6),200,3.5)
	badge("HOLD E AT A PRICE TAG TO BUY  /  FIT PARTS AT YOUR WORKBENCH",CFrame.new(0,17,74.5)*CFrame.Angles(0,math.pi,0),100,3)

	-- Eighteen long warehouse gondolas across six zones; each zone has a sample rack and
	-- two stocked aisles. Product size stays believable instead of scaling the PC hardware.
	for _, rack in Layout.Racks do
		local accent = ACCENTS[rack.Slot]
		local half = rack.Width / 2
		local function rp(name, x, y, z, sx, sy, sz, color, material)
			return localPart(rack.Frame, name, x, y, z, sx, sy, sz, color, material)
		end
		rp("RackPlinth", 0, 0.65, 0, rack.Width, 0.7, 6.4, DARK, M.Metal)
		rp("RackBackboard", 0, 6.9, 0, rack.Width - 0.4, 12.5, 0.22, rgb(62,68,78), M.Metal)
		for _, dx in {-half + 0.2, -14, 14, half - 0.2} do
			rp("RackUpright", dx, 7.1, 0, 0.2, 13.5, 6.2, STEEL, M.Metal)
		end
		for _, y in {1.15, 3.25, 7.2, 11.2} do
			rp("SteelShelf", 0, y, 0, rack.Width, 0.18, 6.4, STEEL, M.Metal)
			for _, side in {-1, 1} do rp("ShelfLip", 0, y + 0.12, side * 3.2, rack.Width, 0.3, 0.12, accent) end
		end
		-- End caps sit just past the shelf ends, so the shelf, lip and plinth end faces never
		-- share a plane with anything visible.
		for _, e in {-1, 1} do
			rp("RackEndCap", e * (half + 0.09), 7.1, 0, 0.12, 13.6, 6.6, COUNTER, M.Metal)
			local header = rp("EndCapSign", e * (half + 0.18), 12.2, 0, 0.06, 2.4, 6.2, accent:Lerp(DARK, 0.35))
			sign(header, rack.Title, if e > 0 then Enum.NormalId.Right else Enum.NormalId.Left)
		end
		if rack.Showcase then
			for _, side in {-1, 1} do
				local turn = CFrame.Angles(0, if side == 1 then 0 else math.pi, 0)
				badge(rack.Title, rack.Frame * CFrame.new(0, 20, side * 0.25) * turn, 78, 3, accent:Lerp(DARK, 0.45))
			end
			for _, dx in {-30, 30} do rp("SignSuspension", dx, 27.5, 0, 0.07, 12, 0.07, STEEL, M.Metal) end
		end
	end

	-- Six spacious comparison bays, each carrying a purchasable monitor and a video wall.
	for index=1,6 do
		local x=-140+(index-1)*56
		box("MonitorRack",x,1.7,Layout.MonitorZ,34,2.8,4.3,COUNTER)
		box("MonitorDeck",x,3.22,Layout.MonitorZ,34.2,0.25,4.5,DARK)
		box("MonitorShelfLip",x,3.1,Layout.MonitorZ+2.32,34.4,0.35,0.12,RED)
		for _, y in {9,15} do
			box("VideoWallBezel",x,y,-149.4,29,4.5,0.25,DARK)
			box("VideoWallPanel",x,y,-149.2,28.5,4,0.05,ACCENTS.Monitor:Lerp(ACCENTS.Cooling,index/7):Lerp(DARK,0.25),M.Neon)
		end
	end
	box("LicenseRack",Layout.LicenseX,1.7,Layout.LicenseZ,68,2.8,4,COUNTER)
	box("LicenseDeck",Layout.LicenseX,3.22,Layout.LicenseZ,68.2,0.25,4.2,DARK)
	badge("08   SOFTWARE & LICENSES",CFrame.new(Layout.LicenseX,16,Layout.LicenseZ-2),70,3,NAVY)

	-- Angled islands make the front showroom a place to browse complete setups.
	badge("09   PREBUILT PC EXPERIENCE", CFrame.new(0, 17, 31), 90, 3, RED)
	for _, station in Layout.PrebuiltStations do
		local build = Catalog.Prebuilts[station.Id]
		local function sp(name, x, y, z, sx, sy, sz, color, material)
			return localPart(station.Frame, name, x, y, z, sx, sy, sz, color, material)
		end
		sp("PrebuiltIslandBase", 0, 0.55, 0, 13.6, 0.5, 8, DARK, M.Metal)
		for _, dx in {-5.8, 5.8} do sp("PrebuiltIslandLeg", dx, 1.9, 0, 0.35, 2.6, 6, STEEL, M.Metal) end
		sp("PrebuiltDemoDesk", 0, 3.25, 0, 14, 0.25, 8, rgb(150, 118, 88), M.Wood)
		sp("PrebuiltIslandTrim", 0, 3.22, 4.05, 13.8, 0.12, 0.12, build.Accent, M.Neon)
		sp("PrebuiltBrandPanel", 0, 1.8, 3.9, 12, 1.8, 0.12, build.Accent:Lerp(DARK, 0.6))
		badge(build.Name, station.Frame * CFrame.new(0, 1.8, 4), 11, 1.5, NAVY)
	end
	-- Eight checkout lanes, a full build-advice counter and a clear entrance concourse.
	for lane,x in Layout.Checkouts do
		local z=Layout.CheckoutZ
		box("CheckoutBase",x,1.8,z,6,3,12,COUNTER)
		box("CheckoutTop",x,3.33,z,6.1,0.06,12.1,COUNTER_TOP)
		box("CheckoutBelt",x,3.4,z-2,5.8,0.15,7.6,DARK,M.Rubber)
		box("RegisterStand",x+1.8,4,z+4,0.25,1.1,0.25,STEEL,M.Metal)
		local register=box("RegisterScreen",x+1.8,4.6,z+4,1.5,1.1,0.18,NAVY)
		sign(register,"MICRO\nHARBOUR")
		box("Scanner",x+0.7,3.55,z+2,0.6,0.25,0.8,RED)
		box("LanePole",x-2.6,6.3,z+4,0.2,5.9,0.2,STEEL,M.Metal)
		badge("CHECKOUT "..lane,CFrame.new(x,10,z+4),6,1.5,RED)
	end
	box("HelpBench",Layout.HelpX,1.8,Layout.HelpZ,48,3,6,COUNTER)
	box("ESDWorkMat",Layout.HelpX,3.36,Layout.HelpZ,44,0.06,5,rgb(41,107,106),M.Rubber)
	box("ToolBoard",Layout.HelpX,4.65,Layout.HelpZ-3.3,44,8.7,0.15,rgb(62,66,72))
	badge("BUILD DESK  /  EXPERT ADVICE",CFrame.new(Layout.HelpX,10,Layout.HelpZ-3),48,2.5)
	for k=0,7 do box("WorkbenchTool",Layout.HelpX-20+k*2,3.45,Layout.HelpZ,0.15,0.12,0.9,if k%2==0 then RED else STEEL,M.Metal) end
	for _, x in {-12,12} do
		box("SecurityPedestal",x,2.6,72,0.35,4.5,2,STEEL,M.Metal)
		box("GateIndicator",x,4.5,72,0.4,0.16,0.6,rgb(60,220,160),M.Neon)
	end
	badge("CHECKOUTS  01-08",CFrame.new(-104,22,70)*CFrame.Angles(0,math.pi,0),96,4,RED)
	badge("THANK YOU FOR SHOPPING AT MICRO HARBOUR",CFrame.new(0,25,74.5)*CFrame.Angles(0,math.pi,0),120,4,RED)

end

return Fixtures
