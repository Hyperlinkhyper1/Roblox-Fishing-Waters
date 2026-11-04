local ImportedModel = require(script.Parent.ImportedModel)
local DeskGeometry = require(script.Parent.ShopDeskGeometry)

local ShopDesk = {}
local VERSION = 5
-- Fills two grid cells across (FurnitureCatalog), less a sliver at each end.
local DESK_WIDTH = 8.2
local DESK_HEIGHT = 64 * DESK_WIDTH / 160
-- The supplied register mesh came through as ~1,770 sliver wedges per shop, and every
-- base streams in whole, so the harbour arrived as tens of thousands of parts at once.
-- It is block-built instead, in the same footprint and finishes.
local REGISTER_VERSION = 5
local rgb = Color3.fromRGB
local M = Enum.Material
local DESK_APPEARANCE = {
	obj_0 = { color = rgb(105, 69, 43), material = M.Wood },
	obj_1 = { color = rgb(74, 46, 30), material = M.Wood },
	obj_2 = { color = rgb(137, 97, 62), material = M.Wood },
	obj_3 = { color = rgb(137, 97, 62), material = M.Wood },
	obj_4 = { color = rgb(176, 137, 68), material = M.Metal },
	obj_5 = { color = rgb(176, 137, 68), material = M.Metal },
}
local REGISTER_APPEARANCE = {
	obj_0_color_2829873 = { color = rgb(48, 58, 62), material = M.Metal },
	obj_0_color_6383466 = { color = rgb(55, 107, 112), material = M.Metal },
	obj_0_color_10988977 = { color = rgb(181, 190, 187), material = M.Metal },
	obj_0_color_14541540 = { color = rgb(235, 227, 205), material = M.SmoothPlastic },
}

-- Origin on the desktop under the register's middle. The keys slope down towards the
-- shopkeeper (+Z); the customer display stands at the back left.
local KEY_SLOPE = math.atan2(0.8, 0.93)
local REGISTER_PARTS = {
	-- group, kind, size, local frame
	{ "obj_0_color_2829873", "Part", Vector3.new(1.8, 0.42, 1.78), CFrame.new(0, 0.21, 0) },
	{ "obj_0_color_2829873", "Part", Vector3.new(0.12, 0.4, 0.12), CFrame.new(-0.6, 1.42, -0.6) },
	{ "obj_0_color_2829873", "Part", Vector3.new(0.62, 0.29, 0.1), CFrame.new(-0.6, 1.765, -0.6) },
	{ "obj_0_color_6383466", "Part", Vector3.new(1.8, 0.8, 0.85), CFrame.new(0, 0.82, -0.465) },
	{
		"obj_0_color_6383466",
		"WedgePart",
		Vector3.new(1.8, 0.8, 0.93),
		CFrame.new(0, 0.82, 0.425) * CFrame.Angles(0, math.pi, 0),
	},
	{ "obj_0_color_10988977", "Part", Vector3.new(1.5, 0.24, 0.02), CFrame.new(0, 0.21, 0.9) },
	{ "obj_0_color_10988977", "Part", Vector3.new(0.5, 0.05, 0.05), CFrame.new(0, 0.24, 0.935) },
	{ "obj_0_color_10988977", "Part", Vector3.new(0.52, 0.2, 0.02), CFrame.new(-0.6, 1.765, -0.66) },
	{ "obj_0_color_10988977", "Part", Vector3.new(0.45, 0.14, 0.45), CFrame.new(0.55, 1.29, -0.55) },
	{
		"obj_0_color_14541540",
		"Part",
		Vector3.new(1.3, 0.02, 1),
		CFrame.new(0, 0.82, 0.425) * CFrame.Angles(KEY_SLOPE, 0, 0) * CFrame.new(0, 0.011, 0),
	},
	{ "obj_0_color_14541540", "Part", Vector3.new(0.3, 0.12, 0.01), CFrame.new(0.55, 1.42, -0.55) },
}

local function buildRegister(desk: Model, frame: CFrame): Model
	local register = Instance.new("Model")
	register.Name = "CashRegister"
	register:SetAttribute("ModelVersion", REGISTER_VERSION)
	register:SetAttribute("SourceModel", "Cash Register")
	for _, spec in REGISTER_PARTS do
		local name, kind, size, offset = spec[1], spec[2], spec[3], spec[4]
		local group = register:FindFirstChild(name)
		if not group then
			group = Instance.new("Model")
			group.Name = name
			-- The supplied palette stays as metadata, as ImportedModel keeps it.
			local hex = tonumber(string.match(name, "%d+$")) :: number
			group:SetAttribute("SourceColor", Color3.fromRGB(hex // 65536, hex // 256 % 256, hex % 256))
			group.Parent = register
		end
		local finish = REGISTER_APPEARANCE[name]
		local item = Instance.new(kind) :: BasePart
		item.Name = "Solid"
		item.Size = size
		item.CFrame = frame * offset
		item.Color = finish.color
		item.Material = finish.material
		item.Anchored = true
		item.CanCollide = false
		item.CanTouch = false
		item.CastShadow = false
		item.TopSurface = Enum.SurfaceType.Smooth
		item.BottomSurface = Enum.SurfaceType.Smooth
		item.Parent = group
	end
	register.Parent = desk
	return register
end

local function registerFrame(frame: CFrame): CFrame
	-- Local +Z is the desk's front (the supplied cabinet handles). Viewed
	-- from that front, -X is the left side. Both models share that facing.
	return frame * CFrame.new(-0.31 * DESK_WIDTH, DESK_HEIGHT, 0)
end

function ShopDesk.build(parent: Instance, frame: CFrame): Model
	local desk = ImportedModel.build(parent, frame, DeskGeometry, {
		name = "ShopDesk",
		sourceName = "Ingenious Lappi",
		version = VERSION,
		width = DESK_WIDTH,
		appearance = DESK_APPEARANCE,
	})
	buildRegister(desk, registerFrame(frame))
	return desk
end

ShopDesk.WIDTH = DESK_WIDTH
ShopDesk.HEIGHT = DESK_HEIGHT
ShopDesk.DEPTH = 65 * DESK_WIDTH / 160
-- Turned clockwise as seen from above, beside the shop's front window to the
-- right of its door (house-local; the shop stands across the road). The end
-- stays clear of the window sill's stone lip. Customers stand on the desk's
-- local -Z side (toward the aisle), facing the shopkeeper.
function ShopDesk.frame(houseFrame: CFrame): CFrame
	return houseFrame * CFrame.new(-16, 0.16, 66.575 + DESK_WIDTH / 2) * CFrame.Angles(0, -math.pi / 2, 0)
end

function ShopDesk.ensure(shop: Model, houseFrame: CFrame)
	local existing = shop:FindFirstChild("ShopDesk")
	local register = existing and existing:FindFirstChild("CashRegister")
	if
		existing
		and existing:IsA("Model")
		and existing:GetAttribute("ModelVersion") == VERSION
		and existing:GetAttribute("SourceHash") == DeskGeometry.sourceHash
	then
		if not register or not register:IsA("Model") or register:GetAttribute("ModelVersion") ~= REGISTER_VERSION then
			-- Saved maps still hold the sliver-built register; swap just that.
			if register then
				register:Destroy()
			end
			buildRegister(existing, registerFrame(ShopDesk.frame(houseFrame)))
		end
		return
	end
	if existing then
		existing:Destroy()
	end
	ShopDesk.build(shop, ShopDesk.frame(houseFrame))
end

return ShopDesk
