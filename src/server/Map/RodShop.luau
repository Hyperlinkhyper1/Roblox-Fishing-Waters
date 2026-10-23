-- A walk-in tackle shop on the quiet south-west corner of the piazza.
-- The same versioned builder also adds it to saved Studio maps at startup.
local CollectionService = game:GetService("CollectionService")

local Props = require(script.Parent.Props)

local RodShop = {}
local LAYOUT_VERSION = 1
local rgb = Color3.fromRGB
local M = Enum.Material
local PLASTER = rgb(242, 231, 208)
local TEAL = rgb(42, 113, 115)
local DARK_TEAL = rgb(31, 73, 77)
local WOOD = rgb(140, 104, 67)
local OAK = rgb(190, 152, 100)
local CREAM = rgb(255, 245, 213)
local TERRACOTTA = rgb(172, 82, 51)
local IRON = rgb(50, 57, 57)

local function boardText(board: BasePart, value: string, color: Color3?, face: Enum.NormalId?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 45
	gui.Parent = board
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = color or CREAM
	text.Text = value
	text.Parent = gui
end

-- Local -Z is the storefront. Rotating it west-to-east keeps the door facing
-- the fountain, with a clear approach south of the existing cafe tables.
function RodShop.build(plaza: Model, plazaFrame: CFrame): Model
	local existing = plaza:FindFirstChild("FishingRodShop")
	if existing and existing:IsA("Model") and existing:GetAttribute("LayoutVersion") == LAYOUT_VERSION then
		existing:SetAttribute("RodId", "StarterRod")
		existing:SetAttribute("Price", 0)
		CollectionService:AddTag(existing, "FishingRodShop")
		return existing
	elseif existing then
		existing:Destroy()
	end
	local shop = Instance.new("Model")
	shop.Name = "FishingRodShop"
	shop:SetAttribute("LayoutVersion", LAYOUT_VERSION)
	shop:SetAttribute("RodId", "StarterRod")
	shop:SetAttribute("Price", 0)
	local frame = plazaFrame * CFrame.new(-43, 0, 34) * CFrame.Angles(0, -math.pi / 2, 0)
	shop:SetAttribute("InteriorFrame", frame * CFrame.new(0, 6.17, 0))
	shop:SetAttribute("InteriorSize", Vector3.new(20.7, 12, 18.7))
	shop.Parent = plaza
	local function at(x: number, y: number, z: number): CFrame
		return frame * CFrame.new(x, y, z)
	end
	local function part(
		name: string,
		size: Vector3,
		x: number,
		y: number,
		z: number,
		color: Color3,
		material: Enum.Material?,
		spin: CFrame?
	): Part
		local piece = Props.part(shop, size, at(x, y, z) * (spin or CFrame.new()), color, material or M.Wood)
		piece.Name = name
		return piece
	end
	local function beam(name: string, a: Vector3, b: Vector3, width: number, color: Color3): Part
		local piece = Props.beam(shop, frame * a, frame * b, width, color, nil, M.Wood)
		piece.Name = name
		piece.CanCollide = false
		return piece
	end
	local floor = part("ShopFloor", Vector3.new(22, 0.7, 20), 0, -0.18, 0, rgb(221, 202, 167), M.Limestone)
	shop.PrimaryPart = floor
	-- The paving and shop floor meet with a low sill; there is no invisible
	-- facade block or door across the eight-stud-wide opening.
	part("EntranceThreshold", Vector3.new(8, 0.15, 2.1), 3.5, 0.12, -10.25, OAK)
	for _, x in { -10.7, 10.7 } do
		part("SideWall", Vector3.new(0.6, 12, 20), x, 6.17, 0, PLASTER, M.Plaster)
		part("WallSkirting", Vector3.new(0.14, 0.75, 19.4), x - math.sign(x) * 0.35, 0.55, 0, TEAL)
	end
	part("BackWall", Vector3.new(21.4, 12, 0.6), 0, 6.17, 9.7, PLASTER, M.Plaster)
	part("WindowLowWall", Vector3.new(10.5, 2.9, 0.6), -5.75, 1.62, -9.7, PLASTER, M.Plaster)
	part("WindowHighWall", Vector3.new(10.5, 3.2, 0.6), -5.75, 10.57, -9.7, PLASTER, M.Plaster)
	for _, x in { -10, -1.5 } do
		part("WindowPier", Vector3.new(2, 5.9, 0.6), x, 6.02, -9.7, PLASTER, M.Plaster)
	end
	part("FrontRightWall", Vector3.new(3.5, 12, 0.6), 9.25, 6.17, -9.7, PLASTER, M.Plaster)
	part("EntranceHeader", Vector3.new(8, 3.2, 0.7), 3.5, 10.57, -9.7, PLASTER, M.Plaster)
	for _, x in { -0.5, 7.5 } do
		part("DoorJamb", Vector3.new(0.25, 8.7, 0.9), x, 4.52, -9.9, TEAL)
	end
	part("DoorLintel", Vector3.new(8.25, 0.3, 0.9), 3.5, 8.82, -9.9, TEAL)
	local window = part("DisplayWindow", Vector3.new(6.5, 5.65, 0.12), -5.75, 6.02, -9.98, rgb(168, 208, 210), M.Glass)
	window.Transparency = 0.65
	for _, y in { 3.05, 8.98 } do
		part("WindowFrame", Vector3.new(7, 0.24, 0.4), -5.75, y, -10.05, TEAL)
	end
	for _, x in { -9.12, -5.75, -2.38 } do
		part("WindowFrame", Vector3.new(0.2, 6.15, 0.4), x, 6.02, -10.05, TEAL)
	end
	part("WindowSill", Vector3.new(7.3, 0.2, 1), -5.75, 2.94, -10.12, OAK)
	part("Roof", Vector3.new(23.5, 0.6, 21.4), 0, 12.4, 0, TERRACOTTA, M.Brick)
	part("Ceiling", Vector3.new(21.3, 0.14, 19.3), 0, 12.04, 0, PLASTER, M.Plaster)
	for _, z in { -7.5, 0, 7.5 } do
		part("CeilingBeam", Vector3.new(21.4, 0.45, 0.5), 0, 11.75, z, WOOD)
	end
	for _, z in { -10.35, 10.35 } do
		part("RoofCornice", Vector3.new(23, 0.38, 0.35), 0, 11.9, z, OAK)
	end
	for index = 1, 10 do
		part(
			"StripedAwning",
			Vector3.new(2.2, 0.18, 2.5),
			-12.1 + index * 2.2,
			9.2,
			-11.1,
			if index % 2 == 0 then TEAL else CREAM,
			M.Fabric,
			CFrame.Angles(-0.14, 0, 0)
		)
	end
	local sign = part("TackleShopSign", Vector3.new(19.4, 1.55, 0.2), 0, 10.88, -10.14, DARK_TEAL)
	boardText(sign, "TIDE & TACKLE")
	local welcome = part("StarterRodSign", Vector3.new(2.8, 1.8, 0.16), 9.25, 5.8, -10.07, DARK_TEAL)
	boardText(welcome, "FREE\nSTARTER ROD")

	-- A counter at the back makes browsing an indoor interaction. The clear
	-- central aisle reaches it directly from the open doorway.
	part("CounterBase", Vector3.new(13, 3.05, 2.4), 0, 1.7, 5.9, TEAL, M.WoodPlanks)
	local counter = part("CounterTop", Vector3.new(13.5, 0.28, 3), 0, 3.36, 5.9, OAK)
	for _, x in { -5.6, 0, 5.6 } do
		part("CounterTrim", Vector3.new(0.16, 2.8, 0.12), x, 1.7, 4.64, OAK)
	end
	-- Keep the sign below the tabletop so every customer in the aisle has
	-- a clear sightline to the purchase prompt on the counter itself.
	local menu = part("RodPriceBoard", Vector3.new(5, 1.25, 0.15), 0, 1.9, 4.62, DARK_TEAL)
	boardText(menu, "STARTER ROD  |  FREE")
	local browse = Instance.new("ProximityPrompt")
	browse.Name = "BuyFishingRodPrompt"
	browse.ActionText = "Browse rods"
	browse.ObjectText = "Tide & Tackle"
	browse.MaxActivationDistance = 8
	browse.RequiresLineOfSight = false
	browse.HoldDuration = 0
	browse.Parent = counter
	part("BackDisplayRail", Vector3.new(15.5, 0.22, 0.45), -1, 2, 8.86, WOOD)
	part("BackDisplayRail", Vector3.new(15.5, 0.22, 0.45), -1, 6.5, 8.86, WOOD)
	local rodColors = { rgb(64, 103, 89), rgb(183, 81, 51), rgb(47, 81, 118), rgb(175, 134, 62) }
	for index, color in rodColors do
		local x = -6.1 + (index - 1) * 3.2
		beam("DisplayRodBlank", Vector3.new(x, 2.6, 8.5), Vector3.new(x + 0.5, 10.4, 8.5), 0.1, color)
		beam("DisplayRodGrip", Vector3.new(x, 1.5, 8.5), Vector3.new(x + 0.1, 3.2, 8.5), 0.22, OAK)
		part("DisplayReel", Vector3.new(0.4, 0.55, 0.35), x + 0.12, 2.8, 8.15, IRON, M.Metal).CanCollide = false
		for _, y in { 4.4, 6.7, 9 } do
			part("DisplayRodGuide", Vector3.new(0.2, 0.17, 0.12), x + (y - 2.6) * 0.064, y, 8.38, IRON, M.Metal).CanCollide =
				false
		end
	end
	-- Side shelving stays out of the entrance and counter approach.
	for _, y in { 0.7, 3.2, 5.6 } do
		part("TackleShelf", Vector3.new(1.8, 0.22, 11), -9.25, y, -0.5, WOOD)
		for index = 1, 5 do
			local z = -5.1 + (index - 1) * 2.15
			local box = part(
				"TackleTin",
				Vector3.new(1.15, 0.8, 1.45),
				-9.18,
				y + 0.5,
				z,
				if index % 2 == 0 then OAK else TEAL,
				M.SmoothPlastic
			)
			box.CanCollide = false
			part("TackleTinLabel", Vector3.new(0.05, 0.35, 0.7), -8.58, y + 0.5, z, CREAM, M.SmoothPlastic).CanCollide =
				false
		end
	end
	for _, z in { -5.8, 4.8 } do
		part("ShelfUpright", Vector3.new(0.2, 6, 0.3), -9.25, 3.17, z, DARK_TEAL)
	end
	local rug = part("WovenWelcomeMat", Vector3.new(5.7, 0.04, 2.4), 3.5, 0.21, -7.7, rgb(182, 139, 82), M.Fabric)
	rug.CanCollide = false
	for _, z in { -3, 4 } do
		local light = part("ShopLight", Vector3.new(1.4, 0.2, 1.4), 0, 11.32, z, CREAM, M.Neon)
		light.CanCollide = false
		local glow = Instance.new("PointLight")
		glow.Color, glow.Brightness, glow.Range, glow.Shadows = rgb(255, 227, 171), 1.1, 20, false
		glow.Parent = light
	end
	CollectionService:AddTag(shop, "FishingRodShop")
	return shop
end

function RodShop.ensure(root: Instance)
	for _, plaza in root:GetDescendants() do
		if not plaza:IsA("Model") or plaza.Name ~= "Plaza" then
			continue
		end
		-- Current paving is 116 studs wide; older baked maps used 120.
		-- Read its frame so the shop follows the saved island's actual position.
		for _, slab in plaza:GetChildren() do
			if
				slab:IsA("BasePart")
				and slab.Size.X >= 115.9
				and slab.Size.X <= 120.1
				and math.abs(slab.Size.X - slab.Size.Z) < 0.01
				and slab.Size.Y <= 1
			then
				RodShop.build(plaza, slab.CFrame * CFrame.new(0, slab.Size.Y / 2, 0))
				break
			end
		end
	end
end

return RodShop
