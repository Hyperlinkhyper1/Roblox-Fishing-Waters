-- Multiplayer properties keep the original house-local origin and grid. Saved
-- furniture and building coordinates never need scaling or translating.
local Plots = {}

Plots.VERSION = 1
Plots.COUNT = 5
Plots.BaseIds = { 1, 3, 4, 6, 11 }
Plots.Bounds = {
	Home = { { -49.5, -33.75, 49.5, 15.75 }, { -24.75, 65.25, 24.75, 83.25 } },
}
-- Foundations extend beyond the editable edge, allowing walls/eaves a margin.
Plots.PadBounds = { { -54, -35.5, 54, 17 } }
-- Includes piers, roof overhangs, launch approach and both property buildings.
-- Expressed in the unchanged house frame (43 studs inland of the dock).
Plots.Envelope = { -60, -147, 60, 93 }

-- Horizontal separating-axis test. It handles rotated properties and pitched
-- scenery boxes, rather than relying on a distance between plot centres.
function Plots.overlaps(frame, rect, box, size, margin)
	local extra = margin or 0
	local center = frame:PointToObjectSpace(box.Position)
	local offset = Vector2.new(center.X - (rect[1] + rect[3]) / 2, center.Z - (rect[2] + rect[4]) / 2)
	local half = Vector2.new((rect[3] - rect[1]) / 2 + extra, (rect[4] - rect[2]) / 2 + extra)
	local reaches = {}
	for _, vector in { box.RightVector * size.X / 2, box.UpVector * size.Y / 2, box.LookVector * size.Z / 2 } do
		local localVector = frame:VectorToObjectSpace(vector)
		table.insert(reaches, Vector2.new(localVector.X, localVector.Z))
	end
	local axes = { Vector2.new(1, 0), Vector2.new(0, 1) }
	for _, reach in reaches do
		if reach.Magnitude > 0.001 then table.insert(axes, reach.Unit) end
	end
	for _, axis in axes do
		local reach = 0
		for _, vector in reaches do reach += math.abs(vector:Dot(axis)) end
		if math.abs(offset:Dot(axis)) >= reach + math.abs(axis.X) * half.X + math.abs(axis.Y) * half.Y then return false end
	end
	return true
end

function Plots.separated(a, b)
	local rect = Plots.Envelope
	local center = CFrame.new((rect[1] + rect[3]) / 2, 0, (rect[2] + rect[4]) / 2)
	return not Plots.overlaps(a, rect, b * center, Vector3.new(rect[3] - rect[1], 0, rect[4] - rect[2]), 8)
end

return Plots
