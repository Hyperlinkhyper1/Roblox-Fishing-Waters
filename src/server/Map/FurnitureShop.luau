-- Harbour Home's plaza door leads to a furnished showroom away from the map.
-- Versioned builders upgrade saved storefronts and restore door links and shop tags.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Furniture = require(ReplicatedStorage.Shared.FurnitureCatalog)
local FishFreezer = require(script.Parent.FishFreezer)
local PlazaHouses = require(script.Parent.PlazaHouses)
local Props = require(script.Parent.Props)
local ShopDesk = require(script.Parent.ShopDesk)
local StorageRack = require(script.Parent.StorageRack)

local FurnitureShop = {}
local LAYOUT_VERSION = 2
local INTERIOR_VERSION = 1
local ORIGIN = CFrame.new(6700, 300, 160)
local W, D, H = 48, 40, 18
local rgb = Color3.fromRGB
local M = Enum.Material
local CREAM = rgb(255, 245, 213)
local TEAL = rgb(64, 140, 120)
local WOOD = rgb(150, 104, 64)

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

	part("Floor", Vector3.new(W + 2, 1, D + 2), CFrame.new(0, -0.5, 0), WOOD, M.WoodPlanks)
	part("Ceiling", Vector3.new(W + 2, 1, D + 2), CFrame.new(0, H + 0.5, 0), rgb(244, 234, 210), M.Plaster)
	for _, side in { -1, 1 } do
		part("SideWall", Vector3.new(1, H, D + 2), CFrame.new(side * (W / 2 + 0.5), H / 2, 0), rgb(244, 234, 210), M.Plaster)
		part("EndWall", Vector3.new(W, H, 1), CFrame.new(0, H / 2, side * (D / 2 + 0.5)), rgb(236, 160, 96), M.Plaster)
		part("Wainscot", Vector3.new(0.2, 3, D), CFrame.new(side * (W / 2 - 0.1), 1.5, 0), TEAL, M.WoodPlanks)
		part("Skirting", Vector3.new(W, 0.4, 0.25), CFrame.new(0, 0.2, side * (D / 2 - 0.1)), TEAL, M.Wood)
	end
	for _, z in { -12, 0, 12 } do
		part("CeilingBeam", Vector3.new(W, 0.7, 0.7), CFrame.new(0, H - 0.4, z), WOOD, M.Wood)
		for _, x in { -12, 12 } do
			local lamp = Props.lantern(hall, ORIGIN * CFrame.new(x, H - 2.5, z), 22, 0.8)
			for _, piece in lamp:GetChildren() do
				if piece:IsA("BasePart") then piece.CanCollide = false end
			end
		end
	end
	for _, side in { -1, 1 } do
		for _, z in { -10, 4, 14 } do
			part("WindowFrame", Vector3.new(0.3, 7, 6), CFrame.new(side * (W / 2 - 0.25), 10, z), TEAL, M.Wood)
			local pane = part("WindowLight", Vector3.new(0.1, 6, 5), CFrame.new(side * (W / 2 - 0.45), 10, z), CREAM, M.Neon)
			pane.CanCollide = false
			Props.light(pane, CREAM, 14, 0.35)
		end
	end
	sign("WelcomeSign", Vector3.new(24, 2.5, 0.2), CFrame.new(0, 14, D / 2 - 0.3), "HARBOUR HOME", TEAL)
	sign("ShowroomGuide", Vector3.new(26, 1.5, 0.2), CFrame.new(0, 11.5, D / 2 - 0.3), "Browse a display · Buy here · Place at home", rgb(102, 70, 44))
	part("ExitDoor", Vector3.new(4, 8, 0.3), CFrame.new(0, 4, -D / 2 + 0.2), rgb(60, 98, 130), M.WoodPlanks)
	sign("ExitSign", Vector3.new(6, 1.3, 0.2), CFrame.new(0, 9.5, -D / 2 + 0.4) * CFrame.Angles(0, math.pi, 0), "EXIT · PLAZA", TEAL)

	-- Full-size examples of every catalogue item, with clear aisles in front.
	local positions = { Freezer = -15, Register = 0, StorageRack = 15 }
	for _, id in Furniture.Order do
		local item = Furniture.Items[id]
		local x = positions[id]
		assert(x, "Missing furniture showroom display: " .. id)
		local display = Instance.new("Model")
		display.Name = id .. "Display"
		display:SetAttribute("ItemId", id)
		display.Parent = hall
		part("DisplayPlinth", Vector3.new(12, 0.3, 7), CFrame.new(x, 0.15, 9), rgb(224, 207, 174), M.Limestone)
		local frame = ORIGIN * CFrame.new(x, 0.3, 9)
		local sample
		if id == "Freezer" then
			sample = FishFreezer.build(display, frame * CFrame.Angles(0, math.pi, 0))
		elseif id == "Register" then
			sample = ShopDesk.build(display, frame)
		else
			frame *= CFrame.Angles(0, math.pi, 0)
			sample = StorageRack.build(display, frame)
			sample.Parent = display
			StorageRack.fill(sample, frame, StorageRack.CRATES)
		end
		sample.Name = "Sample" .. id
		sign("DisplayDetails", Vector3.new(12, 2.8, 0.15), CFrame.new(x, 8.8, 12.5), item.Description, TEAL)
		local label = sign("PriceLabel", Vector3.new(10, 1.4, 0.2), CFrame.new(x, 1.7, 4.5), string.format("%s\n$%d", item.Name, item.Price), rgb(102, 70, 44))
		label.Parent = display
		label:SetAttribute("ItemId", id)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "BrowseFurniturePrompt"
		prompt.ActionText = "View · $" .. item.Price
		prompt.ObjectText = item.Name
		prompt.MaxActivationDistance = 7
		prompt.RequiresLineOfSight = false
		prompt.HoldDuration = 0
		prompt:SetAttribute("ItemId", id)
		prompt.Parent = label
	end

	-- An indoor service desk also offers the whole catalogue.
	local counterFrame = ORIGIN * CFrame.new(-17, 0, -7)
	local counter = ShopDesk.build(hall, counterFrame)
	counter.Name = "SalesCounter"
	local top = part("CounterTop", Vector3.new(ShopDesk.WIDTH, 0.2, ShopDesk.DEPTH), CFrame.new(-17, ShopDesk.HEIGHT + 0.1, -7), WOOD, M.Wood)
	top.Transparency, top.CanCollide, top.CanQuery, top.CanTouch = 1, false, false, false
	local browse = Instance.new("ProximityPrompt")
	browse.Name, browse.ActionText, browse.ObjectText = "BrowseFurniturePrompt", "Browse furniture", "Harbour Home"
	browse.MaxActivationDistance, browse.RequiresLineOfSight, browse.HoldDuration = 7, false, 0
	browse.Parent = top
	hall:SetAttribute("KeeperFrame", counterFrame * CFrame.new(0, 0, ShopDesk.DEPTH / 2 + 1.3))
	sign("ServiceSign", Vector3.new(10, 2, 0.2), CFrame.new(-17, 8, -3), "Need a hand?\nBrowse at the counter", TEAL)
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

function FurnitureShop.ensure(root: Instance)
	for _, plaza in root:GetDescendants() do
		if plaza:IsA("Model") and plaza.Name == "Plaza" then
			local frame = PlazaHouses.pavingFrame(plaza)
			if frame then FurnitureShop.build(plaza, frame) end
		end
	end
end

return FurnitureShop
