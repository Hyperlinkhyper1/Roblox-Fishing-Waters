-- Harbour Home, the furniture shop on the east side of the piazza, facing the rod store across the
-- fountain. Outside it is one of the plaza's two-tone townhouses with a shopfront; on the pavement
-- in front stand a sample storage rack and the sales counter where anglers browse the catalogue.
-- The same versioned builder repairs saved Studio maps at startup.
local CollectionService = game:GetService("CollectionService")

local PlazaHouses = require(script.Parent.PlazaHouses)
local Props = require(script.Parent.Props)
local ShopDesk = require(script.Parent.ShopDesk)
local StorageRack = require(script.Parent.StorageRack)

local FurnitureShop = {}
local LAYOUT_VERSION = 1
local rgb = Color3.fromRGB
local M = Enum.Material
local CREAM = rgb(255, 245, 213)

-- Front on local +Z, turned so the door faces the fountain; the door takes the end nearer the bay.
function FurnitureShop.build(plaza: Model, plazaFrame: CFrame): Model
	local existing = plaza:FindFirstChild("FurnitureShop")
	if existing and existing:IsA("Model") and existing:GetAttribute("LayoutVersion") == LAYOUT_VERSION then
		return existing
	elseif existing then
		existing:Destroy()
	end
	local base = plazaFrame * CFrame.new(45, 0, 38) * CFrame.Angles(0, -math.pi / 2, 0)
	local shop = PlazaHouses.house(plaza, base, {
		width = 18,
		depth = 18,
		stories = 2,
		lower = rgb(236, 160, 96),
		upper = rgb(244, 234, 210),
		trim = rgb(250, 242, 224),
		shutter = rgb(64, 140, 120),
		roof = rgb(152, 72, 46),
		door = rgb(60, 98, 130),
		balcony = true,
		shop = "HARBOUR HOME",
		blade = "FURNITURE",
		signColor = CREAM,
		doorSide = 1,
	}, Random.new(5150))
	shop.Name = "FurnitureShop"
	shop:SetAttribute("LayoutVersion", LAYOUT_VERSION)
	-- A promenade palm this close would push its fronds through the walls, and the olive planter
	-- on the corner stands where the house goes
	for _, prop in plaza:GetChildren() do
		local reach = if prop.Name == "Palm" then 10 elseif prop.Name == "Planter" then 4 else nil
		local trunk = reach and prop:IsA("Model") and prop:FindFirstChildWhichIsA("BasePart", true)
		if trunk then
			local p = base:PointToObjectSpace(trunk.Position)
			local dx, dz = math.max(math.abs(p.X) - 9.4, 0), math.max(math.abs(p.Z) - 15, 0)
			if dx * dx + dz * dz < reach * reach then
				prop:Destroy()
			end
		end
	end

	-- Pavement display: a stocked sample rack beside the sales counter.
	local floor = base
	local rackFrame = floor * CFrame.new(-9, 0, 12.6)
	local rack = StorageRack.build(shop, rackFrame)
	rack.Name = "SampleStorageRack"
	StorageRack.fill(rack, rackFrame, 5)
	-- The counter's customer side (its local -Z) faces the street.
	local counterFrame = floor * CFrame.new(-0.5, 0, 12.6) * CFrame.Angles(0, math.pi, 0)
	local counter = ShopDesk.build(shop, counterFrame)
	counter.Name = "SalesCounter"
	local anchor = Props.part(
		shop,
		Vector3.new(ShopDesk.WIDTH, 0.2, ShopDesk.DEPTH),
		counterFrame * CFrame.new(0, ShopDesk.HEIGHT + 0.1, 0),
		rgb(120, 84, 52),
		M.Wood
	)
	anchor.Name = "CounterTop"
	anchor.Transparency, anchor.CanCollide = 1, false
	CollectionService:AddTag(anchor, "FurnitureShop")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BrowseFurniturePrompt"
	prompt.ActionText = "Browse furniture"
	prompt.ObjectText = "Harbour Home"
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = anchor
	-- Where the shopkeeper stands, behind the counter and looking out at the street.
	shop:SetAttribute("KeeperFrame", counterFrame * CFrame.new(0, 0, ShopDesk.DEPTH / 2 + 1.3))

	-- A price board on an easel by the door tells passers-by what is inside
	local easel = floor * CFrame.new(8.5, 0, 13.4)
	for _, side in { -1, 1 } do
		Props.part(
			shop,
			Vector3.new(0.18, 4.2, 0.18),
			easel * CFrame.new(side * 1.1, 2, 0) * CFrame.Angles(-0.12, 0, side * 0.08),
			rgb(102, 70, 44),
			M.Wood
		)
	end
	local slate = Props.part(
		shop,
		Vector3.new(2.6, 2.9, 0.1),
		easel * CFrame.new(0, 2.6, 0.2) * CFrame.Angles(-0.12, 0, 0),
		rgb(36, 44, 40),
		M.Slate
	)
	slate.CanCollide = false
	PlazaHouses.boardText(slate, "FREEZERS\nCOUNTERS\nRACKS\nat the counter", Enum.NormalId.Back)
	return shop
end

function FurnitureShop.ensure(root: Instance)
	for _, plaza in root:GetDescendants() do
		if plaza:IsA("Model") and plaza.Name == "Plaza" then
			local frame = PlazaHouses.pavingFrame(plaza)
			if frame then
				local shop = FurnitureShop.build(plaza, frame)
				-- Tags aren't always kept by saved places; restore the counter's.
				local top = shop:FindFirstChild("CounterTop", true)
				if top then
					CollectionService:AddTag(top, "FurnitureShop")
				end
			end
		end
	end
end

return FurnitureShop
