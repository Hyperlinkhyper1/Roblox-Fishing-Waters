-- Continuous underwater slopes, ending inside the sea floor.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Biomes = require(ReplicatedStorage.Shared.Biomes)
local LowPoly = require(script.Parent.LowPoly)

local Seabed = {}
Seabed.Floor = Biomes.SeaFloor

-- Ease into the shore and flatten into the bed, without ledges or vertical walls.
function Seabed.height(distance: number, run: number, top: number?, floor: number?): number
	local bed = floor or Biomes.SeaFloor
	if distance > run then
		return bed - math.min(distance - run, 8) -- buried overlap after the visible slope flattens
	end
	local t = math.clamp(distance / run, 0, 1)
	local blend = t * t * (3 - 2 * t)
	local start = top or 0
	return start + (bed - start) * blend
end

-- Each ring follows the exact same shore vertices; no independent jitter can
-- open seams or turn the underwater slope back toward the island.
function Seabed.slope(
	rim: { Vector3 },
	run: number,
	floor: number,
	color: Color3,
	parent: Instance,
	material: Enum.Material
)
	local center = Vector3.zero
	for _, point in rim do
		center += point
	end
	center /= #rim
	local inside = Vector3.new(center.X, floor - 40, center.Z)
	local previous = rim
	local steps = 8
	for step = 1, steps + 1 do
		local distance = if step > steps then run + 8 else run * step / steps
		local ring = {}
		for j, point in rim do
			local outward = Vector3.new(point.X - center.X, 0, point.Z - center.Z).Unit
			local offset = point + outward * distance
			ring[j] = Vector3.new(offset.X, Seabed.height(distance, run, point.Y, floor), offset.Z)
		end
		for j = 1, #rim do
			local k = j % #rim + 1
			LowPoly.triangle(previous[j], ring[j], ring[k], inside, color, parent, material)
			LowPoly.triangle(previous[j], ring[k], previous[k], inside, color, parent, material)
		end
		previous = ring
	end
end

-- Preserve the shallow biome beds, with a smooth apron around their perimeter.
function Seabed.shelf(
	position: Vector2,
	radius: number,
	top: number,
	material: Enum.Material,
	color: Color3,
	parent: Instance
)
	local bottom = Biomes.SeaFloor - 8
	workspace.Terrain:FillCylinder(
		CFrame.new(position.X, (top + bottom) / 2, position.Y),
		top - bottom,
		radius,
		material
	)
	local slope = Instance.new("Model")
	slope.Name = "SeabedSlope"
	slope.Parent = parent
	local rim = {}
	for j = 1, 96 do
		local angle = (j - 1) / 96 * math.pi * 2
		rim[j] =
			Vector3.new(position.X + math.cos(angle) * (radius - 4), top, position.Y + math.sin(angle) * (radius - 4))
	end
	Seabed.slope(rim, 128, Biomes.SeaFloor, color, slope, material)
end

return Seabed
