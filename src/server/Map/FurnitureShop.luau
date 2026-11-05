-- Harbour Home's plaza door leads to a furnished showroom away from the map.
-- Every catalogue item stands full-size on a plinth facing its aisle, and the
-- indoor service desk sells the whole list. Versioned builders upgrade saved
-- storefronts and restore door links and shop tags.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Furniture = require(ReplicatedStorage.Shared.FurnitureCatalog)
local DiningRoom = require(script.Parent.DiningRoom)
local FishFreezer = require(script.Parent.FishFreezer)
local Kitchen = require(script.Parent.Kitchen)
local PlazaHouses = require(script.Parent.PlazaHouses)
local Props = require(script.Parent.Props)
local ShopDesk = require(script.Parent.ShopDesk)
local StorageRack = require(script.Parent.StorageRack)
local WeatherRadar = require(script.Parent.WeatherRadar)

local FurnitureShop = {}
local LAYOUT_VERSION = 2
local INTERIOR_VERSION = 6
local ORIGIN = CFrame.new(6700, 300, 160)
local W, D, H = 64, 60, 18
local rgb = Color3.fromRGB
local M = Enum.Material
local CREAM = rgb(255, 245, 213)
local TEAL = rgb(64, 140, 120)
local WOOD = rgb(150, 104, 64)
local GOLD = rgb(200, 152, 74)
local RUG = rgb(122, 66, 48)
local LINEN = rgb(236, 226, 204)
local LEAF = rgb(64, 118, 66)
local POT = rgb(164, 96, 62)
local SHADE = rgb(102, 70, 44)

local function interiors(): Instance
	local folder = workspace:FindFirstChild("Interiors")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name, folder.Parent = "Interiors", workspace
	end
	return folder
end

local function doorPrompt(door: BasePart, action: string, destination: CFrame)
	local prompt = door:FindFirstChild("FurnitureStoreDoorPrompt") :: ProximityPrompt?
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "FurnitureStoreDoorPrompt"
		prompt.ObjectText = "Harbour Home"
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.HoldDuration = 0
		prompt.Parent = door
	end
	local p = prompt :: ProximityPrompt
	p.ActionText = action
	p:SetAttribute("TeleportTo", destination)
end

local function restoreTags(hall: Model)
	CollectionService:AddTag(hall, "FurnitureShowroom")
	local top = hall:FindFirstChild("CounterTop")
	if top then CollectionService:AddTag(top, "FurnitureShop") end
end

-- The same builders that furnish a player's house, so displays match the goods.
local function buildSample(id: string, parent: Instance, frame: CFrame): Model
	if id == "Freezer" then
		return FishFreezer.build(parent, frame)
	elseif id == "Register" then
		return ShopDesk.build(parent, frame)
	elseif id == "StorageRack" then
		local sample = StorageRack.build(parent, frame)
		StorageRack.fill(sample, frame, StorageRack.CRATES)
		return sample
	elseif id == "FoodCase" then
		return Kitchen.buildCase(parent, frame)
	elseif id == "KitchenStorage" then
		return Kitchen.buildStorage(parent, frame)
	elseif id == "DiningTable" then
		return DiningRoom.buildTable(parent, frame)
	elseif id == "WeatherRadar" then
		return WeatherRadar.build(parent, frame)
	end
	return Kitchen.buildStation(parent, frame, id)
end

-- Where each item stands in the showroom. `side` names the wall it lines:
-- left/right displays face the side aisles, back displays face the centre.
-- `turn` swings the item's customer side toward that aisle.
local DISPLAYS = {
	-- Left wall: the cooking line.
	{ id = "GrillStation", side = "left", x = -27, z = -6, turn = math.pi / 2, plinth = Vector3.new(6, 0.3, 9.6) },
	{ id = "Smoker", side = "left", x = -27, z = 4, turn = math.pi / 2, plinth = Vector3.new(6, 0.3, 9.6) },
	{ id = "SushiBar", side = "left", x = -27, z = 14, turn = math.pi / 2, plinth = Vector3.new(6, 0.3, 9.6) },
	-- Right wall: the shop floor and storage.
	{ id = "Freezer", side = "right", x = 27, z = -7, turn = -math.pi / 2, plinth = Vector3.new(6, 0.3, 9.6) },
	{ id = "FoodCase", side = "right", x = 27, z = 4, turn = -math.pi / 2, plinth = Vector3.new(6, 0.3, 9.6) },
	{ id = "StorageRack", side = "right", x = 27, z = 14, turn = -math.pi / 2, plinth = Vector3.new(8, 0.3, 6.25) },
	-- By the entrance, between the corner plant and the freezer: the one outdoor piece.
	{ id = "WeatherRadar", side = "right", x = 27, z = -18, turn = -math.pi / 2, plinth = Vector3.new(5.5, 0.3, 5.5) },
	-- Back wall: the sales row under the welcome sign.
	{ id = "KitchenStorage", side = "back", x = -12, z = 24, turn = math.pi, plinth = Vector3.new(9.6, 0.3, 6) },
	{ id = "Register", side = "back", x = 0, z = 24, turn = 0, plinth = Vector3.new(9, 0.3, 7) },
	{ id = "DiningTable", side = "back", x = 12, z = 24, turn = math.pi, plinth = Vector3.new(5.5, 0.3, 9.6) },
}

local function ensureInterior(): Model
	local folder = interiors()
	local existing = folder:FindFirstChild("FurnitureStoreInterior")
	if existing and existing:IsA("Model") and existing:GetAttribute("LayoutVersion") == INTERIOR_VERSION then
		restoreTags(existing)
		return existing
	elseif existing then
		existing:Destroy()
	end
	local hall = Instance.new("Model")
	hall.Name = "FurnitureStoreInterior"
	hall.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	hall:SetAttribute("LayoutVersion", INTERIOR_VERSION)
	hall:SetAttribute("InteriorFrame", ORIGIN * CFrame.new(0, H / 2, 0))
	hall:SetAttribute("InteriorSize", Vector3.new(W, H, D))
	hall:SetAttribute("ArrivalFrame", ORIGIN * CFrame.new(0, 3.2, -D / 2 + 5) * CFrame.Angles(0, math.pi, 0))
	local function part(name: string, size: Vector3, frame: CFrame, color: Color3, material: Enum.Material): Part
		local p = Props.part(hall, size, ORIGIN * frame, color, material)
		p.Name = name
		return p
	end
	local function sign(name: string, size: Vector3, frame: CFrame, text: string, color: Color3): Part
		local p = part(name, size, frame, color, M.Wood)
		p.CanCollide = false
		PlazaHouses.boardText(p, text, Enum.NormalId.Front)
		return p
	end

	-- Shell: warm plaster over teal wainscot, an oak floor and trimmed ceiling.
	part("Floor", Vector3.new(W + 2, 1, D + 2), CFrame.new(0, -0.5, 0), WOOD, M.WoodPlanks)
	part("Ceiling", Vector3.new(W + 2, 1, D + 2), CFrame.new(0, H + 0.5, 0), rgb(244, 234, 210), M.Plaster)
	for _, side in { -1, 1 } do
		part("SideWall", Vector3.new(1, H, D + 2), CFrame.new(side * (W / 2 + 0.5), H / 2, 0), rgb(244, 234, 210), M.Plaster)
		part("EndWall", Vector3.new(W, H, 1), CFrame.new(0, H / 2, side * (D / 2 + 0.5)), rgb(225, 189, 155), M.Plaster)
		part("Wainscot", Vector3.new(0.2, 3, D), CFrame.new(side * (W / 2 - 0.1), 1.5, 0), TEAL, M.WoodPlanks)
		part("Skirting", Vector3.new(W, 0.4, 0.25), CFrame.new(0, 0.2, side * (D / 2 - 0.1)), TEAL, M.Wood)
		part("WainscotCap", Vector3.new(0.35, 0.18, D), CFrame.new(side * (W / 2 - 0.22), 3.06, 0), GOLD, M.Wood)
		part("CrownTrim", Vector3.new(0.45, 0.7, D), CFrame.new(side * (W / 2 - 0.25), H - 0.6, 0), CREAM, M.Wood)
		part("CrownTrim", Vector3.new(W, 0.7, 0.45), CFrame.new(0, H - 0.6, side * (D / 2 - 0.25)), CREAM, M.Wood)
	end
	-- Coffered ceiling: transverse beams carry the lanterns, long beams between.
	for _, z in { -22, -8, 6, 20 } do
		part("CeilingBeam", Vector3.new(W, 0.7, 0.7), CFrame.new(0, H - 0.4, z), WOOD, M.Wood)
		for _, x in { -20, 0, 20 } do
			local lamp = Props.lantern(hall, ORIGIN * CFrame.new(x, H - 2.5, z), 22, 0.8)
			for _, piece in lamp:GetChildren() do
				if piece:IsA("BasePart") then piece.CanCollide = false end
			end
		end
	end
	for _, x in { -22, 0, 22 } do
		part("CeilingBeam", Vector3.new(0.7, 0.7, D), CFrame.new(x, H - 0.4, 0), WOOD, M.Wood)
	end
	-- Lower lanterns over the entrance, the sales counter and the back row.
	for _, spot in { Vector3.new(-24, 11, -20), Vector3.new(0, 13.5, -25), Vector3.new(0, 13.5, 24) } do
		local lamp = Props.lantern(hall, ORIGIN * CFrame.new(spot), 18, 0.8)
		for _, piece in lamp:GetChildren() do
			if piece:IsA("BasePart") then piece.CanCollide = false end
		end
	end
	-- Side windows light the aisles; back windows flank the welcome sign and
	-- wear linen curtains.
	for _, side in { -1, 1 } do
		for _, z in { -26, -16 } do
			part("WindowFrame", Vector3.new(0.3, 7, 6), CFrame.new(side * (W / 2 - 0.25), 10, z), TEAL, M.Wood)
			local pane = part("WindowLight", Vector3.new(0.1, 6, 5), CFrame.new(side * (W / 2 - 0.45), 10, z), CREAM, M.Neon)
			pane.CanCollide = false
			Props.light(pane, CREAM, 14, 0.35)
			for _, dz in { -3.2, 3.2 } do
				local curtain = part("Curtain", Vector3.new(0.15, 7.5, 1.25), CFrame.new(side * (W / 2 - 0.65), 9.7, z + dz), LINEN, M.Fabric)
				curtain.CanCollide = false
			end
		end
		local x = side * 25
		part("WindowFrame", Vector3.new(6, 7, 0.3), CFrame.new(x, 10, D / 2 - 0.25), TEAL, M.Wood)
		local pane = part("WindowLight", Vector3.new(5, 6, 0.1), CFrame.new(x, 10, D / 2 - 0.45), CREAM, M.Neon)
		pane.CanCollide = false
		Props.light(pane, CREAM, 14, 0.35)
		for _, dx in { -3.3, 3.3 } do
			local curtain = part("Curtain", Vector3.new(1.5, 7.5, 0.15), CFrame.new(x + dx, 9.4, D / 2 - 0.65), LINEN, M.Fabric)
			curtain.CanCollide = false
		end
	end
	sign("WelcomeSign", Vector3.new(24, 2.5, 0.2), CFrame.new(0, 14, D / 2 - 0.3), "HARBOUR HOME", TEAL)
	sign("ShowroomGuide", Vector3.new(26, 1.5, 0.2), CFrame.new(0, 11.5, D / 2 - 0.3), "Browse a display · Buy here · Place at home", SHADE)
	part("ExitDoor", Vector3.new(4, 8, 0.3), CFrame.new(0, 4, -D / 2 + 0.2), rgb(60, 98, 130), M.WoodPlanks)
	sign("ExitSign", Vector3.new(6, 1.3, 0.2), CFrame.new(0, 9.5, -D / 2 + 0.4) * CFrame.Angles(0, math.pi, 0), "EXIT · PLAZA", TEAL)
	-- Framed art flanks the exit; timber columns and an arch frame the doorway.
	for _, side in { -1, 1 } do
		local frame = part("ArtFrame", Vector3.new(7, 4.5, 0.2), CFrame.new(side * 12, 6, -D / 2 + 0.15), GOLD, M.Wood)
		frame.CanCollide = false
		local canvas = part("ArtCanvas", Vector3.new(6, 3.5, 0.12), CFrame.new(side * 12, 6, -D / 2 + 0.3), TEAL, M.SmoothPlastic)
		canvas.CanCollide = false
		local horizon = part("ArtHorizon", Vector3.new(5.6, 0.65, 0.08), CFrame.new(side * 12, 5.25, -D / 2 + 0.39), rgb(157, 192, 168), M.SmoothPlastic)
		horizon.CanCollide = false
		local sun = part("ArtSun", Vector3.new(0.9, 0.9, 0.08), CFrame.new(side * 12 + 1.4, 6.7, -D / 2 + 0.39), CREAM, M.SmoothPlastic)
		sun.CanCollide = false
		part("DoorColumn", Vector3.new(1.3, 12, 1.3), CFrame.new(side * 5, 6, -D / 2 + 0.8), CREAM, M.Wood)
		part("DoorColumnCap", Vector3.new(1.7, 0.5, 1.7), CFrame.new(side * 5, 12.25, -D / 2 + 0.8), WOOD, M.Wood)
		part("DoorColumnBase", Vector3.new(1.7, 0.6, 1.7), CFrame.new(side * 5, 0.3, -D / 2 + 0.8), WOOD, M.Wood)
	end
	part("DoorArch", Vector3.new(12.3, 1.2, 1.3), CFrame.new(0, 13, -D / 2 + 0.8), WOOD, M.Wood)
	-- Runner rugs warm the aisles; none of it blocks a walking avatar.
	local function rug(name: string, size: Vector3, at: Vector3, color: Color3)
		local carpet = part(name, size, CFrame.new(at), color, M.Fabric)
		carpet.CanCollide = false
	end
	rug("CentreRunnerTrim", Vector3.new(7.8, 0.06, 43.8), Vector3.new(0, 0.03, -3), GOLD)
	rug("CentreRunner", Vector3.new(7, 0.08, 43), Vector3.new(0, 0.05, -3), RUG)
	for _, x in { -18, 18 } do
		rug("AisleRunnerTrim", Vector3.new(4.8, 0.06, 32.8), Vector3.new(x, 0.03, 1), LINEN)
		rug("AisleRunner", Vector3.new(4, 0.08, 32), Vector3.new(x, 0.05, 1), TEAL)
	end
	rug("EntryMat", Vector3.new(6, 0.08, 2.5), Vector3.new(0, 0.05, -D / 2 + 2), TEAL)
	-- Potted greenery softens the entrance and the back corners.
	local rng = Random.new(90210)
	local function plant(x: number, z: number)
		local m = Instance.new("Model")
		m.Name = "PottedPlant"
		local function at(dx: number, y: number, dz: number): Vector3
			return (ORIGIN * CFrame.new(x + dx, y, z + dz)).Position
		end
		Props.cylinder(m, at(0, 0.85, 0), 1.7, 2.2, POT, M.SmoothPlastic)
		Props.cylinder(m, at(0, 1.78, 0), 0.25, 2, rgb(70, 52, 40), M.Ground)
		Props.beam(m, at(0, 1.9, 0), at(0, 3.1, 0), 0.35, rgb(92, 70, 48), 0.35, M.Wood)
		for _, offset in {
			Vector3.new(0, 3.1, 0),
			Vector3.new(0.9, 2.7, 0.4),
			Vector3.new(-0.8, 2.8, -0.5),
			Vector3.new(0.2, 2.6, -0.9),
		} do
			Props.blob(m, at(offset.X, offset.Y, offset.Z), Vector3.new(2.4, 1.1, 1.6), rng, LEAF, M.LeafyGrass)
		end
		for _, piece in m:GetDescendants() do
			if piece:IsA("BasePart") then piece.CanCollide = false end
		end
		m.Parent = hall
	end
	for _, spot in { Vector2.new(-8, -26), Vector2.new(8, -26), Vector2.new(-30, 23), Vector2.new(30, 23) } do
		plant(spot.X, spot.Y)
	end
	-- A little upholstered bench makes the entrance feel like a home, while
	-- leaving the centre and both browsing aisles clear.
	part("WelcomeBench", Vector3.new(7, 0.45, 2.6), CFrame.new(16, 1.55, -27), WOOD, M.Wood)
	part("BenchCushion", Vector3.new(6.7, 0.45, 2.35), CFrame.new(16, 2, -27), LINEN, M.Fabric)
	part("BenchBack", Vector3.new(7, 2.3, 0.35), CFrame.new(16, 2.8, -28.1), WOOD, M.Wood)
	for _, x in { 13.1, 18.9 } do
		for _, z in { -27.9, -26.1 } do
			part("BenchLeg", Vector3.new(0.45, 1.4, 0.45), CFrame.new(x, 0.7, z), WOOD, M.Wood)
		end
	end
	for _, x in { 14, 18 } do
		local cushion = part("BenchPillow", Vector3.new(1.5, 1.2, 0.55), CFrame.new(x, 2.9, -27.75), TEAL, M.Fabric)
		cushion.CanCollide = false
	end

	-- Two room sets turn the middle of the shop into a showroom. The main
	-- runner and the side aisles remain open all the way around the sets.
	for _, x in { -10, 10 } do
		rug("RoomSetRug", Vector3.new(8, 0.08, 14), Vector3.new(x, 0.05, 4), if x < 0 then LINEN else rgb(194, 210, 190))
		part("RoomDivider", Vector3.new(8, 8, 0.35), CFrame.new(x, 4, 11), if x < 0 then rgb(210, 181, 153) else rgb(187, 207, 189), M.WoodPlanks)
		part("RoomDividerCap", Vector3.new(8.2, 0.25, 0.5), CFrame.new(x, 8.1, 11), WOOD, M.Wood)
	end
	-- A small lounge with a sofa, coffee table and dressed shelves.
	part("ShowroomSofaBase", Vector3.new(6.5, 1, 2.7), CFrame.new(-10, 1.1, -1), rgb(183, 154, 126), M.Fabric)
	part("ShowroomSofaBack", Vector3.new(6.5, 2.3, 0.65), CFrame.new(-10, 2.3, -2), rgb(183, 154, 126), M.Fabric)
	for _, x in { -13, -7 } do
		part("ShowroomSofaArm", Vector3.new(0.55, 1.5, 2.7), CFrame.new(x, 1.9, -1), rgb(183, 154, 126), M.Fabric)
	end
	for _, x in { -11.8, -8.2 } do
		local pillow = part("ShowroomPillow", Vector3.new(1.4, 1.2, 0.45), CFrame.new(x, 2.45, -1.55), TEAL, M.Fabric)
		pillow.CanCollide = false
	end
	part("CoffeeTableTop", Vector3.new(4.5, 0.3, 2.2), CFrame.new(-10, 1.7, 3.2), WOOD, M.Wood)
	for _, x in { -11.8, -8.2 } do
		for _, z in { 2.5, 3.9 } do
			part("CoffeeTableLeg", Vector3.new(0.3, 1.55, 0.3), CFrame.new(x, 0.78, z), SHADE, M.Wood)
		end
	end
	local book = part("ShowroomBook", Vector3.new(1.2, 0.16, 0.9), CFrame.new(-10.5, 1.93, 3.2), TEAL, M.SmoothPlastic)
	book.CanCollide = false
	for _, y in { 2.3, 4.4, 6.5 } do
		part("ShowroomShelf", Vector3.new(6.5, 0.22, 1.1), CFrame.new(-10, y, 10.25), WOOD, M.Wood)
		for _, x in { -12, -10, -8 } do
			local box = part("ShelfBox", Vector3.new(1.1, 1.2, 0.8), CFrame.new(x, y + 0.7, 10.2), if x == -10 then TEAL else LINEN, M.Fabric)
			box.CanCollide = false
		end
	end
	-- A dining vignette and stocked shelving suggest how pieces can be used
	-- together, while the actual catalogue samples remain on their plinths.
	part("ShowroomTableTop", Vector3.new(5.5, 0.35, 3.2), CFrame.new(10, 2.6, 2.5), WOOD, M.Wood)
	for _, x in { 7.8, 12.2 } do
		for _, z in { 1.3, 3.7 } do
			part("ShowroomTableLeg", Vector3.new(0.45, 2.4, 0.45), CFrame.new(x, 1.2, z), SHADE, M.Wood)
		end
	end
	for _, z in { -0.4, 5.4 } do
		part("ShowroomSeat", Vector3.new(3.6, 0.4, 1.1), CFrame.new(10, 1.35, z), TEAL, M.Wood)
		for _, x in { 8.5, 11.5 } do
			part("ShowroomSeatLeg", Vector3.new(0.35, 1.2, 0.35), CFrame.new(x, 0.6, z), WOOD, M.Wood)
		end
	end
	for _, y in { 2.3, 4.4, 6.5 } do
		part("ShowroomShelf", Vector3.new(6.5, 0.22, 1.1), CFrame.new(10, y, 10.25), WOOD, M.Wood)
		for _, x in { 8, 10, 12 } do
			local basket = part("ShelfBasket", Vector3.new(1.3, 0.8, 0.8), CFrame.new(x, y + 0.5, 10.2), if x == 10 then POT else LINEN, M.Fabric)
			basket.CanCollide = false
		end
	end
	sign("RoomSetSign", Vector3.new(7, 1.3, 0.15), CFrame.new(-10, 9.2, 10.9), "A COSY CORNER", TEAL)
	sign("RoomSetSign", Vector3.new(7, 1.3, 0.15), CFrame.new(10, 9.2, 10.9), "GATHER & DINE", TEAL)
	sign("ShowroomRouteSign", Vector3.new(13, 1.5, 0.2), CFrame.new(0, 13, -11), "SHOWROOM  ·  FOLLOW THE AISLES", TEAL)
	sign("ShowroomRouteSign", Vector3.new(12, 1.5, 0.2), CFrame.new(0, 13, 15), "MORE IDEAS AHEAD", TEAL)
	for _, x in { -13, -7, 7, 13 } do
		local support = part("RoomSignSupport", Vector3.new(0.16, 0.55, 0.16), CFrame.new(x, 8.4, 10.9), WOOD, M.Wood)
		support.CanCollide = false
	end
	for _, z in { -11, 15 } do
		for _, x in { -5, 5 } do
			local hanger = part("RouteSignHanger", Vector3.new(0.12, 4.1, 0.12), CFrame.new(x, 15.8, z), SHADE, M.Metal)
			hanger.CanCollide = false
		end
	end
	sign("ZoneSign", Vector3.new(12, 2, 0.15), CFrame.new(-(W / 2 - 0.65), 11.8, 8) * CFrame.Angles(0, -math.pi / 2, 0), "COOKING & KITCHEN", TEAL)
	sign("ZoneSign", Vector3.new(12, 2, 0.15), CFrame.new(W / 2 - 0.65, 11.8, 8) * CFrame.Angles(0, math.pi / 2, 0), "SHOP FLOOR & STORAGE", TEAL)

	-- Full-size examples of every catalogue item, each on a plinth facing the
	-- aisle where its customers stand.
	for _, spec in DISPLAYS do
		local item = Furniture.Items[spec.id]
		local display = Instance.new("Model")
		display.Name = spec.id .. "Display"
		display:SetAttribute("ItemId", spec.id)
		local plinth = part("DisplayPlinth", spec.plinth, CFrame.new(spec.x, 0.15, spec.z), rgb(224, 207, 174), M.Limestone)
		plinth.Parent = display
		local trim = part("PlinthTrim", Vector3.new(spec.plinth.X + 0.3, 0.1, spec.plinth.Z + 0.3), CFrame.new(spec.x, 0.32, spec.z), GOLD, M.Wood)
		trim.Parent = display
		local sample = buildSample(spec.id, display, ORIGIN * CFrame.new(spec.x, 0.37, spec.z) * CFrame.Angles(0, spec.turn, 0))
		sample.Name = "Sample" .. spec.id
		sample.Parent = display
		-- The price board stands at the plinth's aisle edge; the description
		-- hangs on the wall above the display.
		local labelFrame, detailFrame, detailSize, customer
		if spec.side == "left" then
			labelFrame = CFrame.new(spec.x + 4.45, 1.9, spec.z) * CFrame.Angles(0, -math.pi / 2, 0)
			detailFrame = CFrame.new(-(W / 2 - 0.65), 8.8, spec.z) * CFrame.Angles(0, -math.pi / 2, 0)
			detailSize = Vector3.new(spec.plinth.Z, 2.8, 0.15)
			customer = Vector3.new(spec.x + 8, 3.2, spec.z)
		elseif spec.side == "right" then
			labelFrame = CFrame.new(spec.x - 4.45, 1.9, spec.z) * CFrame.Angles(0, math.pi / 2, 0)
			detailFrame = CFrame.new(W / 2 - 0.65, 8.8, spec.z) * CFrame.Angles(0, math.pi / 2, 0)
			detailSize = Vector3.new(spec.plinth.Z, 2.8, 0.15)
			customer = Vector3.new(spec.x - 8, 3.2, spec.z)
		else
			labelFrame = CFrame.new(spec.x, 1.9, spec.z - 3.8)
			detailFrame = CFrame.new(spec.x, 8.8, D / 2 - 0.4)
			detailSize = Vector3.new(spec.plinth.X, 2.8, 0.15)
			customer = Vector3.new(spec.x, 3.2, spec.z - 6.5)
		end
		display:SetAttribute("CustomerSpot", customer)
		local labelSize = Vector3.new(math.min(spec.plinth.X, spec.plinth.Z) - 0.5, 2.2, 0.2)
		local backing = part(
			"PriceFrame",
			Vector3.new(labelSize.X + 0.5, labelSize.Y + 0.5, 0.12),
			labelFrame * CFrame.new(0, 0, 0.06),
			GOLD,
			M.Metal
		)
		backing.CanCollide = false
		backing.Parent = display
		local label = sign("PriceLabel", labelSize, labelFrame, string.format("%s\n$%d", item.Name, item.Price), SHADE)
		label.Parent = display
		label:SetAttribute("ItemId", spec.id)
		sign("DisplayDetails", detailSize, detailFrame, item.Description, TEAL).Parent = display
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "BrowseFurniturePrompt"
		prompt.ActionText = "View · $" .. item.Price
		prompt.ObjectText = item.Name
		prompt.MaxActivationDistance = 7
		prompt.RequiresLineOfSight = false
		prompt.HoldDuration = 0
		prompt:SetAttribute("ItemId", spec.id)
		prompt.Parent = label
		display.Parent = hall
	end

	-- An indoor service desk also offers the whole catalogue.
	local counterFrame = ORIGIN * CFrame.new(-24, 0, -20)
	local counter = ShopDesk.build(hall, counterFrame)
	counter.Name = "SalesCounter"
	local top = part("CounterTop", Vector3.new(ShopDesk.WIDTH, 0.2, ShopDesk.DEPTH), CFrame.new(-24, ShopDesk.HEIGHT + 0.1, -20), WOOD, M.Wood)
	top.Transparency, top.CanCollide, top.CanQuery, top.CanTouch = 1, false, false, false
	local browse = Instance.new("ProximityPrompt")
	browse.Name, browse.ActionText, browse.ObjectText = "BrowseFurniturePrompt", "Browse furniture", "Harbour Home"
	browse.MaxActivationDistance, browse.RequiresLineOfSight, browse.HoldDuration = 7, false, 0
	browse.Parent = top
	hall:SetAttribute("KeeperFrame", counterFrame * CFrame.new(0, 0, ShopDesk.DEPTH / 2 + 1.3))
	sign("ServiceSign", Vector3.new(10, 2, 0.2), CFrame.new(-24, 8, -D / 2 + 0.4) * CFrame.Angles(0, math.pi, 0), "Need a hand?\nBrowse at the counter", TEAL)
	-- Tag after parenting so listeners inspect the finished showroom.
	hall.Parent = folder
	restoreTags(hall)
	return hall
end

function FurnitureShop.build(plaza: Model, plazaFrame: CFrame): Model
	local hall = ensureInterior()
	local existing = plaza:FindFirstChild("FurnitureShop")
	local shop: Model
	if existing and existing:IsA("Model") and existing:GetAttribute("LayoutVersion") == LAYOUT_VERSION then
		shop = existing
	else
		if existing then existing:Destroy() end
		local base = plazaFrame * CFrame.new(45, 0, 38) * CFrame.Angles(0, -math.pi / 2, 0)
		local doorFace, leaf
		shop, doorFace, leaf = PlazaHouses.house(plaza, base, {
			width = 18, depth = 18, stories = 2,
			lower = rgb(236, 160, 96), upper = rgb(244, 234, 210), trim = rgb(250, 242, 224),
			shutter = TEAL, roof = rgb(152, 72, 46), door = rgb(60, 98, 130), balcony = true,
			shop = "HARBOUR HOME", blade = "FURNITURE", signColor = CREAM, doorSide = 1,
		}, Random.new(5150))
		shop.Name = "FurnitureShop"
		shop:SetAttribute("LayoutVersion", LAYOUT_VERSION)
		leaf.Name = "StreetDoor"
		shop:SetAttribute("ExitFrame", doorFace * CFrame.new(0, 3.2, 4.5) * CFrame.Angles(0, math.pi, 0))
		for _, prop in plaza:GetChildren() do
			local reach = if prop.Name == "Palm" then 10 elseif prop.Name == "Planter" then 4 else nil
			local trunk = reach and prop:IsA("Model") and prop:FindFirstChildWhichIsA("BasePart", true)
			if trunk then
				local p = base:PointToObjectSpace(trunk.Position)
				local dx, dz = math.max(math.abs(p.X) - 9.4, 0), math.max(math.abs(p.Z) - 15, 0)
				if dx * dx + dz * dz < reach * reach then prop:Destroy() end
			end
		end
		local board = Props.part(shop, Vector3.new(2.8, 3.6, 0.2), doorFace * CFrame.new(-5, 1.8, 4), rgb(36, 44, 40), M.Slate)
		board.CanCollide = false
		PlazaHouses.boardText(board, "FREEZERS\nCOUNTERS\nRACKS\ninside", Enum.NormalId.Back)
	end
	local leaf = shop:FindFirstChild("StreetDoor", true)
	local exit = hall:FindFirstChild("ExitDoor")
	if leaf and leaf:IsA("BasePart") then doorPrompt(leaf, "Enter", hall:GetAttribute("ArrivalFrame")) end
	if exit and exit:IsA("BasePart") then doorPrompt(exit, "Leave", shop:GetAttribute("ExitFrame")) end
	return shop
end

-- Startup repairs scan the whole map (city and islands included) before anyone spawns. Yield a
-- frame every 50 ms so the startup thread stays inside Roblox's ~10 s script timeout.
local breatheAt = os.clock()
local function breathe()
	if task and os.clock() - breatheAt > 0.05 then
		task.wait()
		breatheAt = os.clock()
	end
end

function FurnitureShop.ensure(root: Instance)
	for _, plaza in root:GetDescendants() do
		breathe()
		if plaza:IsA("Model") and plaza.Name == "Plaza" then
			local frame = PlazaHouses.pavingFrame(plaza)
			if frame then FurnitureShop.build(plaza, frame) end
		end
	end
end

return FurnitureShop
