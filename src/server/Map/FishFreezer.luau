-- Supplied Tinkercad freezer, scaled for a comfortable shop counter height.
local Geometry = require(script.Parent.FishFreezerGeometry)
local ImportedModel = require(script.Parent.ImportedModel)

local FishFreezer = {}
local VERSION = 3
local rgb = Color3.fromRGB
local M = Enum.Material
local APPEARANCE = {
	obj_0 = { color = rgb(169, 215, 219), material = M.SmoothPlastic, transparency = 0.58, reflectance = 0.08 },
	obj_1 = { color = rgb(211, 233, 226), material = M.Ice },
	obj_2 = { color = rgb(40, 98, 105), material = M.Metal },
}
-- Salmon portions with cream wrapping, retaining all four supplied packages.
for _, name in { "obj_3", "obj_6", "obj_8", "obj_10" } do
	APPEARANCE[name] = { color = rgb(212, 138, 115), material = M.SmoothPlastic }
end
for _, name in { "obj_4", "obj_5", "obj_7", "obj_9" } do
	APPEARANCE[name] = { color = rgb(236, 224, 196), material = M.Fabric }
end

function FishFreezer.build(parent: Instance, frame: CFrame): Model
	return ImportedModel.build(parent, frame, Geometry, {
		name = "FishFreezer",
		sourceName = "Smashing Elzing-Habbi",
		version = VERSION,
		width = 9,
		origin = Vector3.new(-2, 15, 0),
		appearance = APPEARANCE,
	})
end

-- The left wall keeps both entrances and the central shop aisle clear.
function FishFreezer.ensure(shop: Model, houseFrame: CFrame)
	local existing = shop:FindFirstChild("FishFreezer")
	if existing and existing:IsA("Model") and existing:GetAttribute("ModelVersion") == VERSION then
		return
	end
	if existing then
		existing:Destroy()
	end
	FishFreezer.build(shop, houseFrame * CFrame.new(-19, 0.16, 7) * CFrame.Angles(0, math.pi / 2, 0))
end

return FishFreezer
