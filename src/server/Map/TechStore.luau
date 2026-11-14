-- Micro Harbour exterior, bare racks/furniture and collision stay visible outside. Only
-- merchandise is generated locally by client/TechStoreInterior while the shopper is inside.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local City = require(script.Parent.ModernCity)
local TechCatalog = require(ReplicatedStorage.Shared.TechCatalog)
local Layout = require(ReplicatedStorage.Shared.TechStoreLayout)
local Fixtures = require(ReplicatedStorage.Shared.TechStoreFixtures)
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))

local TechStore = {}
TechStore.VERSION = 7
TechStore.NAME = "TechStore"

local rgb = Color3.fromRGB
local M = Enum.Material

local X0, X1 = Layout.X0, Layout.X1
local Z0, Z1 = Layout.Z0, Layout.Z1
local H = Layout.Height
local T = 0.8 -- wall thickness
local FY = 0.3 -- shop floor

local WHITE = rgb(236, 236, 232)
-- Muted big-box palette: light grey concrete sides, graphite cladding on the frontage and a
-- dark polished floor, so the store no longer reads as one glaring white box.
local WALL = rgb(176, 178, 178)
local WALL_RIB = rgb(146, 150, 154)
local CLAD = rgb(56, 60, 66)
local ROOF = rgb(72, 74, 78)
local FLOOR = rgb(86, 89, 94)
local LAMP = rgb(255, 226, 182)
local RED = rgb(204, 22, 34)
local RED_DARK = rgb(150, 14, 24)
local NAVY = rgb(20, 36, 82)
local TILE = rgb(204, 206, 204)
local STEEL = rgb(176, 180, 184)
local CHARCOAL = rgb(40, 42, 46)
local GLASS = rgb(170, 204, 220)
local ASPHALT = rgb(56, 58, 60)
local PAVEMENT = rgb(150, 148, 140)
local PAINT = rgb(236, 234, 220)

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, solid: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanTouch = false
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = solid ~= false
	p.CanQuery = solid ~= false
	if solid == false then
		p.CastShadow = math.max(size.X, size.Y, size.Z) > 2
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

-- Signs keep white text: Map.ensureSignText restyles every sign label in the map to the UI
-- theme's white, so the colour lives in the board behind it.
local function sign(board: BasePart, face: Enum.NormalId, text: string, maxSize: number?, font: Enum.Font?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.2
	gui.MaxDistance = 160
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	label.Text = text
	Theme.text(label)
	label.Font = font or Enum.Font.GothamBlack
	label.TextColor3 = rgb(255, 255, 255)
	label.TextStrokeTransparency = 1
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0.04, 0), UDim.new(0.04, 0)
	padding.PaddingTop, padding.PaddingBottom = UDim.new(0.1, 0), UDim.new(0.1, 0)
	padding.Parent = label
	if maxSize then
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = maxSize
		limit.Parent = label
	end
	label.Parent = gui
	gui.Parent = board
	return label
end

local function glow(item: BasePart, color: Color3, at: number)
	item:AddTag("NightGlow")
	item:SetAttribute("GlowColor", color)
	item:SetAttribute("GlowAt", at)
end

-- A department prompt the client turns into the shop window (TechCatalog.PROMPT_NAME).
local function desk(parent: Instance, frame: CFrame, department: string, action: string, object: string)
	local spot = part(parent, "ServicePoint", Vector3.new(2, 1, 2), frame, WHITE, M.SmoothPlastic, false)
	spot.Transparency = 1
	spot.CastShadow = false
	spot:SetAttribute("Department", department)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = TechCatalog.PROMPT_NAME
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = spot
end

local function build(site): Model
	local store = Instance.new("Model")
	store.Name = TechStore.NAME
	store.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	store:SetAttribute("StoreVersion", TechStore.VERSION)
	store:SetAttribute("District", "Industrial District")
	local base = site.cframe * CFrame.new(0, City.CAFE_CURB - City.CAFE_TOP, 0)
	store:SetAttribute("StoreFrame", base)
	local function box(parent, name, x0, x1, y0, y1, z0, z1, color, material, solid)
		return part(parent, name, Vector3.new(x1-x0, y1-y0, z1-z0),
			base * CFrame.new((x0+x1)/2, (y0+y1)/2, (z0+z1)/2), color, material, solid)
	end
	part(store, "IndustrialLot", Vector3.new(site.w, 0.9, site.d), site.cframe * CFrame.new(0,0.45,0), PAVEMENT, M.Concrete)
	local parking = group(store, "MegaStoreParking")
	box(parking,"Asphalt",-220,220,0,0.06,90,180,ASPHALT,M.Asphalt,false)
	box(parking,"EntranceWalk",-12,12,0.06,0.12,Z1,180,TILE,M.Concrete,false)
	for _, side in {-1,1} do
		for _, z in {102,150} do
			for x=28,208,12 do
				box(parking,"StallLine",side*x-0.08,side*x+0.08,0.07,0.1,z,z+22,PAINT,M.SmoothPlastic,false)
			end
		end
	end
	for index, x in {-190,-142,-82,82,142,190} do
		local z = if index%2==0 then 113 else 161
		local color = if index%3==0 then rgb(170,180,190) elseif index%2==0 then RED_DARK else NAVY
		box(parking,"CarBody",x-2.7,x+2.7,0.7,3,z-5.5,z+5.5,color,M.Metal)
		box(parking,"CarCabin",x-2.4,x+2.4,3,5,z-3,z+3,rgb(40,58,72),M.Glass,false)
		box(parking,"CarRoof",x-2.4,x+2.4,5,5.2,z-3,z+3,color,M.Metal,false)
		for _, dz in {-3.8,3.8} do
			local wheels = part(parking,"CarWheels",Vector3.new(5.9,1.7,1.7),base*CFrame.new(x,1,z+dz),CHARCOAL,M.Rubber,false)
			wheels.Shape = Enum.PartType.Cylinder
		end
	end
	for _, x in {-18,18} do
		box(parking,"Bollard",x-0.3,x+0.3,0,3.5,82,82.6,STEEL,M.Metal)
		box(parking,"BollardCap",x-0.32,x+0.32,3.1,3.6,81.98,82.62,RED,M.SmoothPlastic,false)
	end
	local pylon = group(store,"IndustrialPylon")
	box(pylon,"PylonPole",-208,-206,0,34,167,169,STEEL,M.Metal)
	local board=box(pylon,"PylonBoard",-224,-190,34,49,166,170,RED,M.SmoothPlastic,false)
	sign(board,Enum.NormalId.Back,TechCatalog.STORE_NAME .. "\nMEGASTORE",110)
	sign(board,Enum.NormalId.Front,TechCatalog.STORE_NAME .. "\nMEGASTORE",110)
	glow(board,rgb(255,50,60),0.3)

	-- No two shell faces share a plane: the slab stops inside the walls, the frontage wings stop
	-- at the side walls, the canopy sits below the tower/door header and the doors fill only
	-- the opening instead of overlapping the shop windows.
	local shell = group(store,"WarehouseBuilding")
	box(shell,"Floor",X0,X1,0,FY,Z0,Z1+T,FLOOR,M.SmoothPlastic)
	box(shell,"BackWall",X0-T,X1+T,0,H,Z0-T,Z0,WALL,M.Concrete)
	box(shell,"BackWallBase",X0-T-0.15,X1+T+0.15,0,1.2,Z0-T-0.3,Z0-T,CLAD,M.Concrete,false)
	for _, side in {-1,1} do
		local x=side*X1
		box(shell,"SideWall",math.min(x,x+side*T),math.max(x,x+side*T),0,H,Z0,Z1+T,WALL,M.Concrete)
		for z=Z0+5,Z1-3,12 do
			part(shell,"WallRib",Vector3.new(0.14,H-3,0.18),base*CFrame.new(side*(X1+T+0.08),H/2,z),WALL_RIB,M.Metal,false)
		end
		local outer=side*(X1+T)
		box(shell,"SideWallBase",math.min(outer,outer+side*0.12),math.max(outer,outer+side*0.12),0,1.2,Z0-T,Z1+T,CLAD,M.Concrete,false)
		box(shell,"SideRedBand",math.min(outer,outer+side*0.22),math.max(outer,outer+side*0.22),H-4.5,H-3,Z0-T,Z1+T,RED,M.SmoothPlastic,false)
	end
	box(shell,"Roof",X0-T-0.4,X1+T+0.4,H,H+0.8,Z0-T-0.4,Z1+T+0.4,ROOF,M.Metal)
	box(shell,"Parapet",X0-T-0.4,X1+T+0.4,H+0.8,H+2.2,Z1+T,Z1+T+0.4,CLAD,M.Metal)
	for _, wing in {{X0,-14},{14,X1}} do
		box(shell,"FrontSill",wing[1],wing[2],FY,2,Z1,Z1+T,CHARCOAL,M.Concrete)
		box(shell,"FrontHeader",wing[1],wing[2],15,H,Z1,Z1+T,CLAD,M.Metal)
		for _, y in {17.4,28.6} do
			box(shell,"CladdingReveal",wing[1],wing[2],y-0.1,y+0.1,Z1+T,Z1+T+0.06,CHARCOAL,M.Metal,false)
		end
		box(shell,"WindowTransom",wing[1],wing[2],10.9,11.1,Z1+0.18,Z1+0.57,CHARCOAL,M.Metal,false)
		local width=wing[2]-wing[1]
		local panels=math.ceil(width/18)
		for i=0,panels-1 do
			local x0=wing[1]+i*width/panels
			local x1=wing[1]+(i+1)*width/panels
			local pane=box(shell,"ShopWindow",x0+0.15,x1-0.15,2,15,Z1+0.25,Z1+0.45,GLASS,M.Glass)
			pane.Transparency=0.62; pane:SetAttribute("PreserveGlassMaterial",true)
			box(shell,"Mullion",x0-0.12,x0+0.12,2,15,Z1+0.15,Z1+0.6,CHARCOAL,M.Metal,false)
		end
		box(shell,"Mullion",wing[2]-0.12,wing[2]+0.12,2,15,Z1+0.15,Z1+0.6,CHARCOAL,M.Metal,false)
	end
	box(shell,"DoorHeader",-14,14,13,H,Z1,Z1+T,CLAD,M.Metal)
	box(shell,"DoorTrack",-14,14,12.6,13,Z1+0.1,Z1+0.6,CHARCOAL,M.Metal,false)
	for _, side in {-1,1} do
		local inner, outer = side*0.15, side*13.75
		local x0, x1 = math.min(inner,outer), math.max(inner,outer)
		local door=box(shell,"SlidingDoor",x0+0.25,x1-0.25,FY,12.6,Z1+0.28,Z1+0.42,GLASS,M.Glass,false)
		door.Transparency=0.55; door:SetAttribute("PreserveGlassMaterial",true)
		for _, edge in {x0,x1-0.25} do box(shell,"DoorStile",edge,edge+0.25,FY,12.6,Z1+0.2,Z1+0.5,CHARCOAL,M.Metal,false) end
		local hx=inner+side*0.6
		box(shell,"DoorHandle",hx-0.06,hx+0.06,5,8,Z1+0.42,Z1+0.6,STEEL,M.Metal,false)
	end
	box(shell,"RedFascia",X0-T,X1+T,H-6,H-2,Z1+T,Z1+T+0.15,RED,M.SmoothPlastic,false)
	local tower=group(shell,"EntranceTower")
	box(tower,"Tower",-28,28,13,H+18,Z1+T,Z1+4,CLAD,M.Metal)
	box(tower,"TowerCoping",-28.4,28.4,H+18,H+18.6,Z1+T-0.6,Z1+4.4,CHARCOAL,M.Metal,false)
	local name=box(tower,"NameSign",-26,26,H+1,H+15,Z1+4,Z1+4.2,RED,M.SmoothPlastic,false)
	sign(name,Enum.NormalId.Back,TechCatalog.STORE_NAME .. "\nMEGASTORE",150)
	glow(name,rgb(255,46,56),0.25)
	box(tower,"SignFrame",-26.6,26.6,H+15,H+15.6,Z1+4,Z1+4.4,STEEL,M.Metal,false)
	box(tower,"SignFrame",-26.6,26.6,H+0.4,H+1,Z1+4,Z1+4.4,STEEL,M.Metal,false)
	for _, side in {-1,1} do
		local a, b = side*26, side*26.6
		box(tower,"SignFrame",math.min(a,b),math.max(a,b),H+1,H+15,Z1+4,Z1+4.4,STEEL,M.Metal,false)
		local fa, fb = side*27, side*27.6
		local fin=box(tower,"TowerFin",math.min(fa,fb),math.max(fa,fb),14.2,H+17,Z1+4,Z1+4.3,RED,M.SmoothPlastic,false)
		glow(fin,rgb(255,46,56),0.25)
	end
	local strap=box(tower,"Strapline",-26,26,17,23,Z1+4,Z1+4.2,NAVY,M.SmoothPlastic,false)
	sign(strap,Enum.NormalId.Back,"INDUSTRIAL DISTRICT  /  PC PARTS & TECHNOLOGY",80,Enum.Font.GothamBold)
	box(tower,"EntranceCanopy",-32,32,12.8,13.8,Z1+T,Z1+12,CLAD,M.Metal)
	box(tower,"CanopyEdge",-32.2,32.2,12.6,14,Z1+12,Z1+12.3,RED,M.SmoothPlastic,false)
	for _, x in {-24,-12,0,12,24} do
		for _, z in {Z1+5,Z1+9.5} do
			local spot=box(tower,"CanopyDownlight",x-0.6,x+0.6,12.74,12.8,z-0.6,z+0.6,LAMP,M.Neon,false)
			glow(spot,LAMP,0.3)
		end
	end
	for _, x in {-30,30} do
		box(tower,"CanopyPost",x-0.35,x+0.35,0,12.8,Z1+10.5,Z1+11.2,STEEL,M.Metal)
		box(tower,"PostBase",x-0.6,x+0.6,0,0.5,Z1+10.25,Z1+11.45,CHARCOAL,M.Concrete,false)
	end
	box(tower,"EntranceMat",-14,14,FY,FY+0.05,Z1-5,Z1+T,RED_DARK,M.Fabric,false)
	for _, side in {-1,1} do
		local banner=box(shell,"DepartmentBanner",side*95-48,side*95+48,20,27,Z1+T,Z1+T+0.12,NAVY,M.SmoothPlastic,false)
		sign(banner,Enum.NormalId.Back,if side<0 then "BUILD YOUR OWN PC  /  COMPONENTS" else "MONITORS  /  SOFTWARE  /  EXPERT ADVICE",80,Enum.Font.GothamBold)
	end
	-- Forecourt furniture keeps clear of the doors (x = 0) and the parking aisles.
	local forecourt = group(store,"Forecourt")
	for _, side in {-1,1} do
		local a, b = side*20, side*26
		local planter=box(forecourt,"Planter",math.min(a,b),math.max(a,b),0,2,Z1+2,Z1+9,CHARCOAL,M.Concrete)
		local shrub=part(forecourt,"PlanterShrub",Vector3.new(5,2.6,6),planter.CFrame*CFrame.new(0,1.6,0),rgb(58,92,52),M.Grass,false)
		shrub.Shape=Enum.PartType.Ball
		local bx=side*35
		box(forecourt,"Bin",bx-1,bx+1,0,3.4,Z1+3,Z1+5,CLAD,M.Metal)
		box(forecourt,"BinLid",bx-1.1,bx+1.1,3.4,3.7,Z1+2.9,Z1+5.1,RED,M.SmoothPlastic,false)
	end
	for _, x in {40,52} do box(forecourt,"TrolleyBayPost",x-0.2,x+0.2,0,3.6,Z1+2,Z1+9,STEEL,M.Metal) end
	box(forecourt,"TrolleyBayRail",40.2,51.8,3.2,3.4,Z1+2,Z1+2.2,STEEL,M.Metal,false)
	box(forecourt,"TrolleyBayRoof",39.6,52.4,3.6,3.8,Z1+1.8,Z1+9.2,RED,M.SmoothPlastic,false)
	for _, x in {-160,-100,-40,40,100,160} do
		box(forecourt,"LampPole",x-0.3,x+0.3,0,19.4,136.7,137.3,CLAD,M.Metal)
		box(forecourt,"LampArm",x-3.9,x+3.9,19.4,19.8,136.8,137.2,CLAD,M.Metal,false)
		for _, dx in {-3,3} do
			local head=box(forecourt,"LampHead",x+dx-0.9,x+dx+0.9,19,19.4,136.4,137.6,LAMP,M.Neon,false)
			glow(head,LAMP,0.3)
		end
	end
	for _, x in {-135,-45,45,135} do
		box(shell,"RooftopHVAC",x-6,x+6,H+0.8,H+4,-114,-104,STEEL,M.Metal,false)
		for z=-113,-105,2 do box(shell,"HVACLouvre",x-5.5,x+5.5,H+4,H+4.1,z,z+0.2,CHARCOAL,M.Metal,false) end
	end
	local loading=group(store,"LoadingYard")
	for lane,x in {-115,-57,57,115} do
		local shutter=box(loading,"LoadingShutter",x-11,x+11,1,13,Z0-T-0.12,Z0-T,STEEL,M.Metal,false)
		for y=2,12,2 do box(loading,"ShutterSlat",x-11,x+11,y,y+0.08,Z0-T-0.16,Z0-T-0.12,CHARCOAL,M.Metal,false) end
		box(loading,"DockPlatform",x-13,x+13,0,1,Z0-9,Z0-T,CHARCOAL,M.Concrete)
		sign(shutter,Enum.NormalId.Front,"DELIVERIES\nBAY "..lane,70)
	end

	Fixtures.build(group(store, "StoreFixtures"), base)
	-- Stable collision stays separate from the visible furniture and local merchandise.
	local collision=group(store,"InteriorCollision")
	collision:SetAttribute("LodSkip",true)
	local function collider(name,x,z,width,depth,height,frame)
		local pose = frame or CFrame.new(x, 0, z)
		local p=part(collision,name,Vector3.new(width,height,depth),base*pose*CFrame.new(0,FY+height/2,0),WHITE)
		p.Transparency,p.CastShadow=1,false
	end
	for _, rack in Layout.Racks do collider("RackCollision",rack.X,rack.Z,rack.Width,Layout.RackDepth,13.5,rack.Frame) end
	for _, station in Layout.PrebuiltStations do collider("PrebuiltCollision",0,0,14,8,3.1,station.Frame) end
	for index=1,6 do collider("MonitorCollision",-140+(index-1)*56,Layout.MonitorZ,34,4.3,3) end
	collider("LicenseCollision",Layout.LicenseX,Layout.LicenseZ,68,4,3)
	collider("HelpCollision",Layout.HelpX,Layout.HelpZ,48,6,3)
	for _, x in Layout.Checkouts do collider("CheckoutCollision",x,Layout.CheckoutZ,6,12,3) end
	desk(collision,base*CFrame.new(Layout.HelpX,4.2,Layout.HelpZ+4),"Components","Browse owned parts","Build Desk")
	desk(collision,base*CFrame.new(0,4.2,Layout.MonitorZ+4),"Monitors","Compare monitors","Monitor Experience")
	desk(collision,base*CFrame.new(Layout.LicenseX,4.2,Layout.LicenseZ+3),"Licenses","Browse licenses","Software Department")
	store:AddTag(TechCatalog.STORE_TAG)
	return store
end

-- Builds the store once per server (or replaces an older one). It stands on its own paved lot,
-- so it works before the city finishes generating.
function TechStore.ensure(root: Instance): Model
	local existing = root:FindFirstChild(TechStore.NAME)
	if existing and existing:IsA("Model") and existing:GetAttribute("StoreVersion") == TechStore.VERSION then
		existing:AddTag(TechCatalog.STORE_TAG)
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local store = build(City.techStoreSite())
	store.Parent = root
	return store
end

return TechStore
