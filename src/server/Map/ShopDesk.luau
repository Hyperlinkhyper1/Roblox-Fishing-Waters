local ImportedModel = require(script.Parent.ImportedModel)
local DeskGeometry = require(script.Parent.ShopDeskGeometry)
local RegisterGeometry = require(script.Parent.CashRegisterGeometry)

local ShopDesk = {}
local VERSION = 4
local DESK_WIDTH = 7.5
local DESK_HEIGHT = 64 * DESK_WIDTH / 160
local REGISTER_WIDTH = 1.8
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

function ShopDesk.build(parent: Instance, frame: CFrame): Model
	local desk = ImportedModel.build(parent, frame, DeskGeometry, {
		name = "ShopDesk",
		sourceName = "Ingenious Lappi",
		version = VERSION,
		width = DESK_WIDTH,
		appearance = DESK_APPEARANCE,
	})
	-- Local +Z is the desk's front (the supplied cabinet handles). Viewed
	-- from that front, -X is the left side. Both models share that facing.
	ImportedModel.build(desk, frame * CFrame.new(-0.31 * DESK_WIDTH, DESK_HEIGHT, 0), RegisterGeometry, {
		name = "CashRegister",
		sourceName = "Cash Register",
		version = VERSION,
		width = REGISTER_WIDTH,
		canCollide = false,
		appearance = REGISTER_APPEARANCE,
	})
	return desk
end

ShopDesk.WIDTH = DESK_WIDTH
ShopDesk.HEIGHT = DESK_HEIGHT
ShopDesk.DEPTH = 65 * DESK_WIDTH / 160
-- Turn counterclockwise as seen from above. The end meets the front
-- window sill's inside edge (z=14.425) without clipping its stone lip.
-- Customers stand on the desk's local -Z side, facing the shopkeeper.
function ShopDesk.frame(houseFrame: CFrame): CFrame
	return houseFrame * CFrame.new(16, 0.16, 14.425 - DESK_WIDTH / 2) * CFrame.Angles(0, math.pi / 2, 0)
end

function ShopDesk.ensure(shop: Model, houseFrame: CFrame)
	local existing = shop:FindFirstChild("ShopDesk")
	local register = existing and existing:FindFirstChild("CashRegister")
	if
		existing
		and existing:IsA("Model")
		and existing:GetAttribute("ModelVersion") == VERSION
		and existing:GetAttribute("SourceHash") == DeskGeometry.sourceHash
		and register
		and register:IsA("Model")
		and register:GetAttribute("ModelVersion") == VERSION
		and register:GetAttribute("SourceHash") == RegisterGeometry.sourceHash
	then
		return
	end
	if existing then
		existing:Destroy()
	end
	ShopDesk.build(shop, ShopDesk.frame(houseFrame))
end

return ShopDesk
