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
-- Local +Z faces into the shop; the cabinet reaches DEPTH / 2 towards it.
FishFreezer.DEPTH = 3.6
FishFreezer.HEIGHT = 4
function FishFreezer.frame(houseFrame: CFrame): CFrame
	return houseFrame * CFrame.new(-19, 0.16, 7) * CFrame.Angles(0, math.pi / 2, 0)
end

-- The sloped ice bed under the glass (source obj_1) is 40 units high at the
-- front (source y=-15) and rises to 57 at the back (y=44). Source units scale
-- by width / 150 about the build origin (-2, 15, 0).
local UNIT = 9 / 150
local ICE_SLOPE = math.atan2(57 - 40, 44 + 15)
FishFreezer.ICE_X = Vector2.new((-74 + 2) * UNIT, (72 + 2) * UNIT) -- left, right
FishFreezer.ICE_Z = Vector2.new(-(44 - 15) * UNIT, (15 + 15) * UNIT) -- back, front

-- The ice surface at freezer-local (x, z); UpVector is the surface normal.
function FishFreezer.iceSurface(frame: CFrame, x: number, z: number): CFrame
	local back, front = FishFreezer.ICE_Z.X, FishFreezer.ICE_Z.Y
	local height = (40 + (57 - 40) * (front - z) / (front - back)) * UNIT
	return frame * CFrame.new(x, height, z) * CFrame.Angles(ICE_SLOPE, 0, 0)
end

function FishFreezer.ensure(shop: Model, houseFrame: CFrame)
	local existing = shop:FindFirstChild("FishFreezer")
	if existing and existing:IsA("Model") and existing:GetAttribute("ModelVersion") == VERSION then
		return
	end
	if existing then
		existing:Destroy()
	end
	FishFreezer.build(shop, FishFreezer.frame(houseFrame))
end

return FishFreezer
