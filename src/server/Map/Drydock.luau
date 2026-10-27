-- Walk-in industrial boatyard and launch controls. Versioned construction also
-- upgrades drydocks baked into a saved Studio map.
local CollectionService = game:GetService("CollectionService")

local Props = require(script.Parent.Props)
local Shipwright = require(script.Parent.Shipwright)
local DrydockInterior = require(script.Parent.DrydockInterior)
local Rowboat = require(script.Parent.Parent.Rowboat)

local Drydock = {}
local LAYOUT_VERSION = 15
local rgb = Color3.fromRGB
local M = Enum.Material
local STEEL = rgb(47, 58, 64)
local WALL = rgb(105, 123, 130)
local RUST = rgb(121, 73, 45)
local CONCRETE = rgb(137, 143, 140)
local YELLOW = rgb(232, 184, 48)
local BLACK = rgb(30, 34, 35)
local CREAM = rgb(239, 236, 211)
local TEAL = rgb(46, 96, 105)
local DARK_WOOD = rgb(70, 53, 40)

local function boardText(board: BasePart, value: string, color: Color3?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 36
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = color or CREAM
	label.Text = value
	label.Parent = gui
end

local function prompt(parent: BasePart, name: string, action: string, object: string): ProximityPrompt
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("ProximityPrompt") then
		return existing
	end
	local p = Instance.new("ProximityPrompt")
	p.Name, p.ActionText, p.ObjectText = name, action, object
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	p.HoldDuration = 0.35
	p.Parent = parent
	return p
end

-- Clear only beach props occupying the building. A palm/bush is one prop, so
-- remove its entire model when its trunk intersects rather than leaving fronds
-- hanging in the workshop. Long boardwalk/fence sections remain localized.
local function clearApron(plaza: Model, shop: Model, footprintName: string?)
	local beach = plaza.Parent and plaza.Parent:FindFirstChild("Beach")
	local footprint = shop:FindFirstChild(footprintName or "ShopFootprint", true)
	if not footprint or not footprint:IsA("BasePart") then
		return
	end
	local half = footprint.Size / 2
	local candidates = if beach then beach:GetDescendants() else {}
	-- Palms at the plaza edge can overhang the new roof even when their trunks
	-- stand outside the site. Clear whole intersecting plants, keeping nearby ones.
	for _, decoration in plaza:GetChildren() do
		if decoration:IsA("Model") and (decoration.Name == "Palm" or decoration.Name == "Bush") then
			for _, piece in decoration:GetDescendants() do
				table.insert(candidates, piece)
			end
		end
	end
	local remove: { [Instance]: boolean } = {}
	for _, item in candidates do
		if not item:IsA("BasePart") then
			continue
		end
		local low = Vector3.new(math.huge, math.huge, math.huge)
		local high = Vector3.new(-math.huge, -math.huge, -math.huge)
		for _, x in { -0.5, 0.5 } do
			for _, y in { -0.5, 0.5 } do
				for _, z in { -0.5, 0.5 } do
					local p = footprint.CFrame:PointToObjectSpace(
						item.CFrame * Vector3.new(item.Size.X * x, item.Size.Y * y, item.Size.Z * z)
					)
					low = Vector3.new(math.min(low.X, p.X), math.min(low.Y, p.Y), math.min(low.Z, p.Z))
					high = Vector3.new(math.max(high.X, p.X), math.max(high.Y, p.Y), math.max(high.Z, p.Z))
				end
			end
		end
		if
			low.X < half.X
			and high.X > -half.X
			and low.Y < half.Y
			and high.Y > -half.Y
			and low.Z < half.Z
			and high.Z > -half.Z
		then
			local target: Instance = item
			local ancestor = item.Parent
			while ancestor and ancestor ~= beach and ancestor ~= plaza do
				if
					ancestor:IsA("Model")
					and ancestor.Name ~= "Fence"
					and ancestor.Name ~= "Surf"
					and ancestor.Name ~= "BeachDetails"
					and ancestor.Name ~= "FoamRibbon"
				then
					target = ancestor
				end
				ancestor = ancestor.Parent
			end
			remove[target] = true
		end
	end
	for target in remove do
		target:Destroy()
	end
end

-- A raised, open-air repair basin keeps its floor above the beach mesh and water.
-- The hauling slip carries the preview cradle into open launch water.
local function buildRearDrydock(shop: Model, frame: CFrame)
	local rear = Instance.new("Model")
	rear.Name = "RearDrydock"
	rear.Parent = shop
	local function part(
		name: string,
		size: Vector3,
		x: number,
		y: number,
		z: number,
		color: Color3,
		material: Enum.Material?
	): Part
		local p = Props.part(rear, size, frame * CFrame.new(x, y, z), color, material or M.Metal)
		p.Name = name
		return p
	end
	local function beam(
		name: string,
		a: Vector3,
		b: Vector3,
		width: number,
		depth: number,
		color: Color3,
		material: Enum.Material?
	): Part
		local p = Props.beam(rear, frame * a, frame * b, width, color, depth, material or M.Metal)
		p.Name = name
		return p
	end
	local footprint = part("RearDrydockFootprint", Vector3.new(43, 32, 96), 0, 4, 68, CONCRETE, M.Concrete)
	footprint.Transparency, footprint.CanCollide, footprint.CanTouch, footprint.CanQuery = 1, false, false, false
	footprint.CastShadow = false
	rear.PrimaryPart = footprint

	-- Separate floor, retaining walls and quays leave a real four-stud-deep hollow.
	-- Even the highest beach vertex is below this dry floor; no terrain cut is needed.
	part("RearBasinFloor", Vector3.new(22, 0.6, 42), 0, 0.2, 55, rgb(91, 100, 99), M.Concrete)
	part("RearHeadwall", Vector3.new(24, 4, 1), 0, 2.5, 33.5, CONCRETE, M.Concrete)
	for _, side in { -1, 1 } do
		part("RearBasinWall", Vector3.new(1, 4, 42), side * 11.5, 2.5, 55, CONCRETE, M.Concrete)
		part("RearQuayWalkway", Vector3.new(7, 12.5, 32), side * 15.5, -1.75, 64, CONCRETE, M.Concrete)
		part("RearCoping", Vector3.new(0.6, 0.16, 42), side * 11.65, 4.58, 55, BLACK, M.DiamondPlate)
		for z = 35, 75, 2 do
			part("RearHazardStripe", Vector3.new(0.62, 0.04, 0.85), side * 11.65, 4.68, z, YELLOW)
		end
		-- Two independent stairs can be approached from either side of the workshop.
		for i = 1, 23 do
			local top = -4.7 + i * 0.4
			local z = 20.2 + i * 1.2
			part("RearAccessStep", Vector3.new(7, top + 8, 1.4), side * 15.5, (top - 8) / 2, z, CONCRETE, M.Concrete)
			if i % 4 == 1 or i == 23 then
				part("RearStairPost", Vector3.new(0.16, 2.9, 0.16), side * 18.75, top + 1.45, z, STEEL)
			end
		end
		for _, height in { 1.2, 2.8 } do
			beam(
				"RearStairRail",
				Vector3.new(side * 18.75, -4.3 + height, 21.4),
				Vector3.new(side * 18.75, 4.5 + height, 47.8),
				0.14,
				0.14,
				STEEL
			)
		end
		for z = 49, 79, 10 do
			part("RearSafetyPost", Vector3.new(0.16, 3, 0.16), side * 18.75, 6, z, STEEL)
		end
		for _, y in { 5.6, 7.4 } do
			part("RearSafetyRail", Vector3.new(0.14, 0.14, 30), side * 18.75, y, 64, STEEL)
		end
		-- Outboard columns leave the working path beside the basin unobstructed.
		part("OutdoorGantryFoot", Vector3.new(1.4, 0.25, 2.5), side * 18.1, 4.625, 54, STEEL, M.DiamondPlate)
		-- Tall enough for a lifted hull's mast, and clear of the height boats probe for water.
		part("OutdoorGantryColumn", Vector3.new(0.9, 18.8, 1), side * 18.25, 14, 54, STEEL)
		beam(
			"OutdoorGantryBrace",
			Vector3.new(side * 18.25, 20.5, 54),
			Vector3.new(side * 14.5, 23.5, 54),
			0.45,
			0.45,
			YELLOW
		)
	end
	part("OutdoorGantryBeam", Vector3.new(39, 1.25, 1.25), 0, 24, 54, YELLOW)
	part("OutdoorHoistTrolley", Vector3.new(2.5, 0.8, 2), 0, 23, 54, STEEL)
	beam("OutdoorHoistCable", Vector3.new(0, 22.6, 54), Vector3.new(0, 20.8, 54), 0.1, 0.1, BLACK)
	part("OutdoorHookBlock", Vector3.new(0.8, 0.9, 0.7), 0, 20.4, 54, YELLOW)
	beam("OutdoorCraneHook", Vector3.new(0, 20, 54), Vector3.new(-0.45, 19.5, 54), 0.18, 0.18, STEEL)
	beam("OutdoorCraneHook", Vector3.new(-0.45, 19.5, 54), Vector3.new(0.3, 19.5, 54), 0.18, 0.18, STEEL)
	beam("OutdoorCraneHook", Vector3.new(0.3, 19.5, 54), Vector3.new(0.45, 19.85, 54), 0.18, 0.18, STEEL)

	-- Empty keel and bilge blocks make the basin read as a place to work on a hull.
	for z = 39, 71, 8 do
		part("KeelBlock", Vector3.new(2.5, 0.9, 2), 0, 0.95, z, DARK_WOOD, M.Wood)
		for _, side in { -1, 1 } do
			part("BilgeBlock", Vector3.new(1.5, 0.65, 2), side * 6, 0.825, z, DARK_WOOD, M.Wood)
		end
	end
	for _, x in { -3.5, 3.5 } do
		part("HaulRail", Vector3.new(0.22, 0.2, 42), x, 0.6, 55, STEEL)
	end
	part("RearDrainGrate", Vector3.new(1.3, 0.08, 36), -9.5, 0.54, 55, BLACK, M.DiamondPlate)
	for z = 38, 72, 2 do
		part("RearDrainSlot", Vector3.new(1.1, 0.03, 0.12), -9.5, 0.595, z, STEEL)
	end
	-- This is a marine slipway, with continuous rails from the dry basin to below
	-- the waterline. The slab stays above the sloping beach and seabed throughout.
	beam("SlipwayDeck", Vector3.new(0, 0.2, 76), Vector3.new(0, -8.8, 114), 22, 0.6, CONCRETE, M.Concrete)
	for _, x in { -3.5, 3.5 } do
		beam("SlipwayRail", Vector3.new(x, 0.6, 76), Vector3.new(x, -8.4, 114), 0.22, 0.2, STEEL)
	end
	for _, side in { -1, 1 } do
		part("HaulWinchBase", Vector3.new(2.4, 0.3, 2.8), side * 13.7, 4.65, 72, STEEL, M.DiamondPlate)
		part("HaulWinch", Vector3.new(1.8, 1.4, 1.8), side * 13.7, 5.5, 72, TEAL)
		part("HaulWinchDrum", Vector3.new(2.4, 0.65, 0.7), side * 13.7, 5.7, 71.4, RUST)
		local glow =
			part("RearWorkLight", Vector3.new(0.7, 0.35, 0.7), side * 18.25, 22.5, 53.2, rgb(255, 232, 178), M.Neon)
		glow.CanCollide = false
		local light = Instance.new("PointLight")
		light.Color, light.Brightness, light.Range, light.Shadows = rgb(255, 232, 178), 1.1, 28, false
		light.Parent = glow
	end
	local sign = part("RearDrydockSign", Vector3.new(15, 1.5, 0.18), 0, 3.2, 32.9, STEEL)
	boardText(sign, "DRYDOCK  /  REFIT LIFT", CREAM)
	-- These frames share the rowboat's waterline origin and point out to the bay.
	for name, position in
		{
			PreviewOrigin = Vector3.new(0, 2.1, 54),
			FishingBoatPreview = Vector3.new(0, 2.1, 54),
			SpeedboatPreview = Vector3.new(0, 2.1, 54),
			PatrolBoatPreview = Vector3.new(0, 2.1, 54),
			RacingSpeedboatPreview = Vector3.new(0, 2.1, 54),
			TrawlerPreview = Vector3.new(0, 2.1, 54),
			SlipwayTop = Vector3.new(0, 2.1, 54),
			LaunchWater = Vector3.new(0, -frame.Position.Y, 54),
		}
	do
		local point = part(
			if name == "FishingBoatPreview"
				then "FishingBoatDisplayOrigin"
				elseif name == "SpeedboatPreview" then "SpeedboatDisplayOrigin"
				elseif name == "PatrolBoatPreview" then "PatrolBoatDisplayOrigin"
				elseif name == "RacingSpeedboatPreview" then "RacingSpeedboatDisplayOrigin"
				elseif name == "TrawlerPreview" then "TrawlerDisplayOrigin"
				else name,
			Vector3.new(1, 1, 1),
			position.X,
			position.Y,
			position.Z,
			STEEL
		)
		point.CFrame *= CFrame.Angles(0, math.pi, 0)
		shop:SetAttribute(name .. "Frame", point.CFrame)
		point.Transparency, point.CanCollide, point.CanTouch, point.CanQuery = 1, false, false, false
	end
	local cradle = Instance.new("Model")
	cradle.Name = "LaunchCradle"
	cradle.Parent = rear
	for _, z in { 50, 58 } do
		local crossbar = part("LaunchCradleBeam", Vector3.new(8.5, 0.35, 1), 0, 1.3, z, YELLOW)
		crossbar.Parent = cradle
		crossbar.CanCollide = false
		cradle.PrimaryPart = crossbar
		for _, x in { -3.5, 3.5 } do
			local wheel = part("CradleRoller", Vector3.new(0.7, 0.6, 1), x, 0.95, z, STEEL)
			wheel.Parent = cradle
			wheel.CanCollide = false
		end
	end
	-- Reuse the original repair platform, including its blocks, rails,
	-- drainage and attached slipway. The surrounding quays stay fixed.
	local moving = {
		RearBasinFloor = true,
		KeelBlock = true,
		BilgeBlock = true,
		HaulRail = true,
		RearDrainGrate = true,
		RearDrainSlot = true,
		SlipwayDeck = true,
		SlipwayRail = true,
	}
	for _, piece in rear:GetChildren() do
		if moving[piece.Name] then
			piece.Parent = cradle
			if piece.Name == "RearBasinFloor" then
				cradle.PrimaryPart = piece
			end
		end
	end
	-- The cradle rests underwater as the refit lift: owners sail over it and it lifts
	-- their hull into the dry basin (DrydockLaunch.lift). Purchases ride it down too.
	-- Lowered, its keel blocks sit four studs under the surface, below every hull.
	local drop = frame.Position.Y + 6.1
	cradle:PivotTo(cradle:GetPivot() - Vector3.new(0, drop, 0))
	shop:SetAttribute("LiftDrop", drop)
	shop:SetAttribute("LiftKeelHeight", (frame * CFrame.new(0, 1.4, 0)).Position.Y)
	-- A hull counts as over the lift while its root floats between the basin walls.
	shop:SetAttribute("SlipFrame", CFrame.new((frame * CFrame.new(0, 0, 62)).Position * Vector3.new(1, 0, 1)))
	shop:SetAttribute("SlipSize", Vector3.new(20, 30, 56))
	-- With the floor down, the pit wall closes the gap under the headwall.
	part("LiftPitWall", Vector3.new(23, 12, 1), 0, -5.5, 33.5, CONCRETE, M.Concrete)
	-- Reopens the refit menu; each client enables it only while its own boat is over the lift.
	local anchor = part("RefitPromptAnchor", Vector3.new(1, 1, 1), 0, 10, 60, STEEL)
	anchor.Transparency, anchor.CanCollide, anchor.CanQuery, anchor.CastShadow = 1, false, false, false
	local refit = Instance.new("ProximityPrompt")
	refit.Name = "RefitDockPrompt"
	refit.ActionText, refit.ObjectText = "Lift & refit", "Drydock"
	refit.MaxActivationDistance = 40
	refit.RequiresLineOfSight = false
	refit.Enabled = false
	refit.Parent = anchor
	-- Atomic streaming prevents partial hulls while the shop camera watches it.
	rear.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
end

-- plazaFrame is the walkable paving at the square center. The lake is +Z;
-- the north entry opens directly onto the plaza's southern promenade.
function Drydock.build(plaza: Model, plazaFrame: CFrame): Model
	local existing = plaza:FindFirstChild("Drydock")
	if existing and existing:IsA("Model") and existing:GetAttribute("LayoutVersion") == LAYOUT_VERSION then
		-- Saved version-15 shops share this waterline origin; add the new hull without rebuilding the lift.
		if existing:GetAttribute("TrawlerPreviewFrame") == nil then
			existing:SetAttribute("TrawlerPreviewFrame", existing:GetAttribute("FishingBoatPreviewFrame"))
		end
		for _, item in existing:GetDescendants() do
			if item:IsA("Model") and item:FindFirstChild("CoolerLid") then
				Rowboat.ensureCoolerInteraction(item)
			end
		end
		local npc = existing:FindFirstChild("Shipwright")
		if npc and npc:IsA("Model") then
			Shipwright.ensureAppearance(npc)
			Shipwright.ensureInteraction(npc)
		end
		DrydockInterior.ensure(existing, plazaFrame * CFrame.new(0, 0, 82))
		CollectionService:AddTag(existing, "BoatShop")
		CollectionService:AddTag(existing, "RefitDock")
		clearApron(plaza, existing)
		clearApron(plaza, existing, "RearDrydockFootprint")
		return existing
	elseif existing then
		existing:Destroy()
	end
	local shop = Instance.new("Model")
	shop.Name = "Drydock"
	shop:SetAttribute("LayoutVersion", LAYOUT_VERSION)
	shop:SetAttribute("BoatId", "Rowboat")
	shop:SetAttribute("Price", 500)
	local frame = plazaFrame * CFrame.new(0, 0, 82)
	shop:SetAttribute("InteriorFrame", frame * CFrame.new(0, 8, 0))
	shop:SetAttribute("InteriorSize", Vector3.new(40, 16, 36))
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
		local p = Props.part(shop, size, at(x, y, z) * (spin or CFrame.new()), color, material or M.Metal)
		p.Name = name
		return p
	end
	local function beam(name: string, a: Vector3, b: Vector3, width: number, depth: number, color: Color3): Part
		local p = Props.beam(shop, frame * a, frame * b, width, color, depth, M.Metal)
		p.Name = name
		return p
	end
	local function light(x: number, y: number, z: number, size: Vector3)
		part("WorkLightHousing", size + Vector3.new(0.35, 0.15, 0.35), x, y + 0.15, z, STEEL)
		local glow = part("WorkLight", size, x, y, z, rgb(255, 236, 180), M.Neon)
		glow.CanCollide = false
		local l = Instance.new("PointLight")
		l.Color, l.Brightness, l.Range, l.Shadows = rgb(255, 231, 184), 1.15, 22, false
		l.Parent = glow
	end
	local footprint = part("ShopFootprint", Vector3.new(43, 28, 40), 0, 7, 0, CONCRETE, M.Concrete)
	footprint.Transparency, footprint.CanCollide, footprint.CanTouch, footprint.CanQuery = 1, false, false, false
	footprint.CastShadow = false
	shop.PrimaryPart = footprint

	-- Concrete is segmented around a real hollow dry repair basin. The raised
	-- perimeter gives the bay 1.7 studs of visible depth without cutting terrain.
	part("ConcreteWalkway", Vector3.new(8, 8.4, 40), -17.5, -2.2, 0, CONCRETE, M.Concrete)
	part("ConcreteWalkway", Vector3.new(22, 8.4, 40), 10.5, -2.2, 0, CONCRETE, M.Concrete)
	part("ConcreteWalkway", Vector3.new(13, 8.4, 11), -7, -2.2, -14.5, CONCRETE, M.Concrete)
	part("ConcreteWalkway", Vector3.new(13, 8.4, 7), -7, -2.2, 16.5, CONCRETE, M.Concrete)
	part("BasinFloor", Vector3.new(13, 0.6, 22), -7, 0, 2, rgb(81, 91, 90), M.Concrete)
	for _, x in { -13.5, -0.5 } do
		part("BasinWall", Vector3.new(0.6, 2.3, 22.6), x, 1.2, 2, CONCRETE, M.Concrete)
	end
	for _, z in { -9, 13 } do
		part("BasinWall", Vector3.new(13.6, 2.3, 0.6), -7, 1.2, z, CONCRETE, M.Concrete)
	end
	for i = 1, 5 do
		part("EntranceStep", Vector3.new(14, i * 0.4, 1.25), 0, i * 0.2, -24.75 + i * 1.2, CONCRETE, M.Concrete)
	end
	-- A service ladder reaches the dry basin floor from the clear rear walkway.
	for _, x in { -9, -7 } do
		part("BasinLadderRail", Vector3.new(0.14, 2.7, 0.14), x, 1.3, 12.55, STEEL)
	end
	for y = 0.45, 2.45, 0.5 do
		part("BasinLadderRung", Vector3.new(2.1, 0.14, 0.14), -8, y, 12.55, STEEL)
	end
	part("DrainGrate", Vector3.new(1.6, 0.08, 5), -11.2, 0.34, 2, BLACK, M.DiamondPlate)
	for z = 0, 4, 0.5 do
		part("DrainSlot", Vector3.new(1.35, 0.02, 0.08), -11.2, 0.39, z, STEEL)
	end
	for _, x in { -13.1, -0.9 } do
		part("HazardRail", Vector3.new(0.5, 0.08, 22), x, 2.39, 2, BLACK, M.DiamondPlate)
		for z = -8, 12, 1.5 do
			part("HazardStripe", Vector3.new(0.52, 0.04, 0.7), x, 2.45, z, YELLOW)
		end
	end
	for _, z in { -8.7, 12.7 } do
		part("HazardRail", Vector3.new(12, 0.08, 0.5), -7, 2.39, z, BLACK, M.DiamondPlate)
		for x = -12, -2, 1.5 do
			part("HazardStripe", Vector3.new(0.7, 0.04, 0.52), x, 2.45, z, YELLOW)
		end
	end

	-- Corrugated steel walls, a broad permanent entry, and exposed roof portals.
	for _, x in { -21, 21 } do
		part("SideCorrugatedWall", Vector3.new(0.7, 12, 40), x, 8, 0, WALL, M.CorrodedMetal)
		for z = -18, 18, 2 do
			part("WallRib", Vector3.new(0.2, 12, 0.23), x - math.sign(x) * 0.45, 8, z, STEEL)
		end
	end
	part("RearCorrugatedWall", Vector3.new(42, 12, 0.7), 0, 8, 19.5, WALL, M.CorrodedMetal)
	for x = -20, 20, 2 do
		part("WallRib", Vector3.new(0.23, 12, 0.2), x, 8, 19.02, STEEL)
	end
	for _, x in { -14.25, 14.25 } do
		part("FrontCorrugatedWall", Vector3.new(14.5, 10, 0.7), x, 7, -19.5, WALL, M.CorrodedMetal)
	end
	part("EntranceHeader", Vector3.new(43, 2, 0.9), 0, 13, -19.5, STEEL)
	part("RollerDoorHousing", Vector3.new(15.5, 0.8, 1.5), 0, 12.05, -19.1, rgb(125, 136, 138))
	for _, x in { -20, 20 } do
		for _, z in { -18.5, 0, 18.5 } do
			part("ColumnFoot", Vector3.new(2.3, 0.3, 2.3), x, 2.15, z, STEEL, M.DiamondPlate)
			part("SteelColumn", Vector3.new(0.9, 12, 0.9), x, 8, z, STEEL)
			for _, dx in { -0.75, 0.75 } do
				part("AnchorBolt", Vector3.new(0.18, 0.2, 0.18), x + dx, 2.4, z, rgb(153, 160, 159))
			end
		end
	end
	local pitch = math.atan2(6, 21)
	for _, side in { -1, 1 } do
		part(
			"CorrugatedRoof",
			Vector3.new(math.sqrt(21 * 21 + 36) + 0.6, 0.4, 40),
			side * 10.5,
			17,
			0,
			rgb(84, 103, 110),
			M.CorrodedMetal,
			CFrame.Angles(0, 0, -side * pitch)
		)
	end
	for x = -20, 20, 1.5 do
		part("RoofRib", Vector3.new(0.16, 0.16, 40), x, 20.35 - math.abs(x) * 6 / 21, 0, STEEL)
	end
	for _, z in { -18.5, -6, 6, 18.5 } do
		beam("RoofTruss", Vector3.new(-20, 14, z), Vector3.new(0, 19.75, z), 0.45, 0.55, STEEL)
		beam("RoofTruss", Vector3.new(0, 19.75, z), Vector3.new(20, 14, z), 0.45, 0.55, STEEL)
		part("TrussTie", Vector3.new(40, 0.4, 0.45), 0, 14, z, STEEL)
		for x = -15, 15, 10 do
			beam(
				"TrussBrace",
				Vector3.new(x, 14, z),
				Vector3.new(x + 5, 19.5 - math.abs(x + 5) * 0.275, z),
				0.22,
				0.25,
				WALL
			)
		end
	end
	part("RoofRidge", Vector3.new(0.6, 0.5, 40), 0, 20.1, 0, STEEL)
	-- Short gable battens close the triangular ends while retaining ventilation.
	for _, z in { -19.5, 19.5 } do
		for x = -18, 18, 2 do
			local height = 5.7 * (1 - math.abs(x) / 21)
			part("GableBatten", Vector3.new(1.75, height, 0.35), x, 14 + height / 2, z, WALL, M.CorrodedMetal)
		end
	end

	-- Overhead bridge crane, with the hook visibly hoisted above the hull.
	for _, x in { -15, 2 } do
		part("CraneRunway", Vector3.new(0.5, 0.65, 30), x, 12.3, 0, YELLOW)
		part("CraneRail", Vector3.new(0.18, 0.2, 30), x, 12.75, 0, STEEL)
	end
	part("GantryBeam", Vector3.new(19, 1.05, 1.1), -6.5, 13.1, 3, YELLOW)
	part("HoistMotor", Vector3.new(2.3, 1.2, 2.5), -7, 12.5, 3, STEEL)
	part("HoistDrum", Vector3.new(1.7, 0.65, 1.2), -7, 11.7, 3, RUST)
	for y = 8.8, 11.2, 0.3 do
		part("ChainLink", Vector3.new(0.13, 0.34, 0.13), -7, y, 3, BLACK)
	end
	part("HookBlock", Vector3.new(0.75, 0.7, 0.65), -7, 8.4, 3, YELLOW)
	beam("CraneHook", Vector3.new(-7, 8.1, 3), Vector3.new(-7.35, 7.65, 3), 0.16, 0.16, STEEL)
	beam("CraneHook", Vector3.new(-7.35, 7.65, 3), Vector3.new(-6.8, 7.65, 3), 0.16, 0.16, STEEL)
	beam("CraneHook", Vector3.new(-6.8, 7.65, 3), Vector3.new(-6.65, 7.95, 3), 0.16, 0.16, STEEL)
	local craneSign = part("CraneLoadSign", Vector3.new(3.5, 0.7, 0.08), -6.5, 13.05, 2.38, STEEL)
	boardText(craneSign, "1 TONNE", YELLOW)

	for _, z in { -2.4, 6.4 } do
		part("CradleCrossbeam", Vector3.new(8.6, 0.45, 1.2), -7, 0.875, z, STEEL)
		for _, x in { -10.1, -3.9 } do
			part("CradleFoot", Vector3.new(0.75, 0.4, 1.6), x, 0.5, z, RUST)
		end
	end
	local boat = Rowboat.build(at(-7, 1.735, 2), true)
	boat.Name = "DisplayRowboat"
	boat:SetAttribute("DisplayOnly", true)
	boat.Parent = shop

	-- Shop side: a clear customer aisle, staffed counter and workshop behind it.
	part("ShipwrightCounter", Vector3.new(7, 2.5, 2), 12, 3.25, -4, rgb(72, 88, 94), M.Metal)
	part("CounterTop", Vector3.new(7.5, 0.25, 2.5), 12, 4.65, -4, STEEL, M.DiamondPlate)
	local price = part("BoatPrices", Vector3.new(6.5, 2.5, 0.08), 12, 3.3, -5.06, STEEL)
	boardText(
		price,
		"ROWBOAT  $500\nFISHER'S BOAT  $2500\nBLUEWATER  $6500\nRACING SPEEDBOAT  $12500\nPATROL CRUISER  $25000",
		YELLOW
	)
	local npc = Shipwright.build(at(12, 2, -0.5))
	npc.Parent = shop
	-- build applies the outfit before the model is in the DataModel; retry here
	-- for the rare case where a slow asset request failed the first time.
	Shipwright.ensureAppearance(npc)
	part("WorkshopBench", Vector3.new(8, 0.5, 3), 13.5, 5.1, 9, STEEL, M.DiamondPlate)
	for _, x in { 10.3, 16.7 } do
		part("BenchLeg", Vector3.new(0.6, 3, 2), x, 3.5, 9, STEEL)
	end
	part("ToolBackboard", Vector3.new(8.5, 4, 0.3), 13.5, 7.5, 10.5, rgb(71, 83, 87), M.DiamondPlate)
	for x = 10, 16, 1.5 do
		part("HangingWrench", Vector3.new(0.2, 1.4, 0.2), x, 7.6, 10.2, rgb(160, 170, 174))
		part("WrenchJaw", Vector3.new(0.55, 0.3, 0.2), x, 8.3, 10.2, rgb(160, 170, 174))
	end
	part("BenchVise", Vector3.new(1.2, 0.7, 1.3), 15.8, 5.7, 8.8, TEAL)
	part("ViseJaw", Vector3.new(1.6, 0.25, 0.45), 15.8, 6.15, 8.8, STEEL)
	part("WeldingCylinder", Vector3.new(1.5, 3.5, 1.5), 18, 3.75, 13, rgb(70, 111, 101))
	part("CylinderValve", Vector3.new(0.6, 0.6, 0.6), 18, 5.8, 13, STEEL)
	for _, x in { 6, 18.7 } do
		part("StorageUpright", Vector3.new(0.5, 8, 0.5), x, 6, 17.5, STEEL)
	end
	for y = 2.3, 9.3, 3.5 do
		part("PartsRackShelf", Vector3.new(13.5, 0.25, 2.7), 12.3, y, 17.5, WALL)
		for x = 8, 17, 3 do
			part("PartsBin", Vector3.new(2, 1.2, 1.8), x, y + 0.7, 17.5, rgb(137, 95, 61), M.Metal)
		end
	end
	for _, z in { -10, 8 } do
		light(-15.5, 11.7, z, Vector3.new(3.2, 0.2, 1))
		light(13, 11.7, z, Vector3.new(3.2, 0.2, 1))
	end
	light(0, 11.15, -18.5, Vector3.new(5.5, 0.2, 0.6))
	local name = part("DrydockSign", Vector3.new(30, 2.3, 0.22), 0, 15.1, -20, STEEL)
	boardText(name, "INDUSTRIAL DRYDOCK")
	local entrySign = part("ShipwrightSign", Vector3.new(5.8, 1.4, 0.16), 13, 9.2, -20, STEEL)
	boardText(entrySign, "SHIPWRIGHT INSIDE", YELLOW)
	DrydockInterior.ensure(shop, frame)
	buildRearDrydock(shop, frame)
	CollectionService:AddTag(shop, "BoatShop")
	CollectionService:AddTag(shop, "RefitDock")
	clearApron(plaza, shop)
	clearApron(plaza, shop, "RearDrydockFootprint")
	return shop
end

function Drydock.ensureDock(base: Model)
	local stored = base:GetAttribute("BoatDockFrame")
	local frame: CFrame
	if typeof(stored) == "CFrame" then
		frame = stored
	else
		local spawn = base:FindFirstChild("SpawnPoint")
		if not spawn or not spawn:IsA("BasePart") then
			warn("[Drydock] Cannot locate the dock for " .. base:GetFullName())
			return
		end
		-- SpawnPoint preserves the original base yaw, unlike the circular ClaimPad.
		frame = spawn.CFrame * CFrame.new(-4, -6.1, -26)
		base:SetAttribute("BoatDockFrame", frame)
	end
	local marker = base:FindFirstChild("BoatSpawn")
	if not marker then
		marker = Instance.new("Part")
		marker.Name = "BoatSpawn"
		marker.Parent = base
	end
	if marker:IsA("BasePart") then
		marker.Size = Vector3.new(1, 1, 1)
		marker.CFrame = frame * CFrame.new(0, 0, -52)
		marker.Anchored = true
		marker.Transparency = 1
		marker.CanCollide = false
		marker.CanTouch = false
		marker.CanQuery = false
		marker.CastShadow = false
	end
	local terminal = base:FindFirstChild("BoatDockControl")
	if not terminal then
		local control = Props.part(
			base,
			Vector3.new(3.4, 2.1, 0.5),
			frame * CFrame.new(-8, 5, -37.5) * CFrame.Angles(0, math.pi, 0),
			TEAL,
			M.WoodPlanks
		)
		control.Name = "BoatDockControl"
		boardText(control, "YOUR BOATS")
		local support =
			Props.part(base, Vector3.new(0.55, 2.8, 0.55), frame * CFrame.new(-8, 3.6, -37.5), DARK_WOOD, M.Wood)
		support.Name = "BoatControlPost"
		terminal = control
	end
	if terminal:IsA("BasePart") then
		local spawnPrompt = prompt(terminal, "SpawnRowboatPrompt", "Choose boat", "Your boats")
		spawnPrompt.ActionText, spawnPrompt.ObjectText = "Choose boat", "Your boats"
		-- Existing saved terminals keep their panel and receive the updated label.
		for _, label in terminal:GetDescendants() do
			if label:IsA("TextLabel") then
				label.Text = "YOUR BOATS"
			end
		end
	end
end

function Drydock.ensure(root: Instance)
	for _, item in root:GetDescendants() do
		if item:IsA("Model") and item.Name == "Plaza" then
			-- The square's main paving slab is stable across saved maps, so the
			-- retrofitted drydock doesn't depend on the current biome center/seed.
			for _, slab in item:GetChildren() do
				if
					slab:IsA("BasePart")
					and (slab.Size.X == 120 or slab.Size.X == 116)
					and slab.Size.Z == slab.Size.X
				then
					Drydock.build(item, slab.CFrame * CFrame.new(0, slab.Size.Y / 2, 0))
					break
				end
			end
		elseif item:IsA("Model") and CollectionService:HasTag(item, "PlayerBase") then
			Drydock.ensureDock(item)
		end
	end
end

return Drydock
