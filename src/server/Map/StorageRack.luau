-- Galvanised shelving for a base's storage room. Local +Z is the open front; the
-- floor is y=0. Each stored fish shows as an iced crate on a shelf.
local Props = require(script.Parent.Props)

local StorageRack = {}
local rgb = Color3.fromRGB
local M = Enum.Material
local STEEL = rgb(118, 128, 132)
local DARK_STEEL = rgb(64, 72, 76)
local BOARD = rgb(150, 112, 74)
local CRATE = rgb(212, 226, 230)
local ICE = rgb(226, 244, 248)

StorageRack.WIDTH = 6
StorageRack.DEPTH = 2
StorageRack.HEIGHT = 6.6
local SHELVES = { 0.35, 2.4, 4.45 }
-- Crate spots: four along each shelf.
local CRATE_SPOTS = {}
for _, y in SHELVES do
	for index = 0, 3 do
		table.insert(CRATE_SPOTS, Vector3.new(-2.1 + index * 1.4, y, 0.05))
	end
end

function StorageRack.build(parent: Instance, frame: CFrame): Model
	local rack = Instance.new("Model")
	rack.Name = "StorageRack"
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material): Part
		local result = Props.part(rack, size, frame * offset, color, material)
		result.Name = name
		return result
	end
	local halfW, halfD = StorageRack.WIDTH / 2, StorageRack.DEPTH / 2
	for _, x in { -halfW + 0.12, halfW - 0.12 } do
		for _, z in { -halfD + 0.12, halfD - 0.12 } do
			piece("Upright", Vector3.new(0.22, StorageRack.HEIGHT, 0.22), CFrame.new(x, StorageRack.HEIGHT / 2, z), STEEL, M.Metal)
		end
		-- Diagonal bracing on each end frame.
		local brace = piece(
			"EndBrace",
			Vector3.new(0.1, math.sqrt(StorageRack.DEPTH ^ 2 + 4), 0.1),
			CFrame.new(x, 3.4, 0) * CFrame.Angles(math.atan2(StorageRack.DEPTH - 0.24, 2), 0, 0),
			DARK_STEEL,
			M.Metal
		)
		brace.CanCollide = false
	end
	for _, y in SHELVES do
		piece("Shelf", Vector3.new(StorageRack.WIDTH - 0.1, 0.14, StorageRack.DEPTH - 0.1), CFrame.new(0, y + 0.07, 0), BOARD, M.WoodPlanks)
		for _, z in { -halfD + 0.12, halfD - 0.12 } do
			piece("ShelfBeam", Vector3.new(StorageRack.WIDTH, 0.26, 0.12), CFrame.new(0, y, z), rgb(214, 104, 52), M.Metal)
		end
	end
	piece("TopShelfCap", Vector3.new(StorageRack.WIDTH, 0.12, StorageRack.DEPTH), CFrame.new(0, StorageRack.HEIGHT, 0), DARK_STEEL, M.Metal)
	return rack
end

-- Shows `count` crates on the rack, rebuilding only when the count changes.
function StorageRack.fill(rack: Model, frame: CFrame, count: number)
	count = math.clamp(count, 0, #CRATE_SPOTS)
	local existing = rack:FindFirstChild("Crates")
	if existing and existing:GetAttribute("Count") == count then
		return
	end
	if existing then
		existing:Destroy()
	end
	local crates = Instance.new("Model")
	crates.Name = "Crates"
	crates:SetAttribute("Count", count)
	for index = 1, count do
		local spot = CRATE_SPOTS[index]
		local base = frame * CFrame.new(spot.X, spot.Y + 0.14, spot.Z)
		local box = Props.part(crates, Vector3.new(1.2, 0.7, 1.5), base * CFrame.new(0, 0.35, 0), CRATE, M.SmoothPlastic)
		box.Name = "FishCrate"
		box.CanCollide = false
		local ice = Props.part(crates, Vector3.new(1, 0.12, 1.3), base * CFrame.new(0, 0.66, 0), ICE, M.Ice)
		ice.Name = "CrushedIce"
		ice.CanCollide = false
	end
	crates.Parent = rack
end

StorageRack.CRATES = #CRATE_SPOTS
return StorageRack
