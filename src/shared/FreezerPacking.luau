-- Deterministic rectangle packing on the cooler's sloped ice bed. Measurements
-- come from the same scaled models used by the display; records stay in order.
local Packing = {}
Packing.LEFT, Packing.RIGHT = -4.32, 4.44
Packing.BACK, Packing.FRONT = -1.74, 1.8
Packing.SLOPE = math.atan2(17, 59)
Packing.MARGIN = 0.12
Packing.GAP = 0.06
local EPSILON = 1e-7

local function contains(a, b)
	return b.x >= a.x - EPSILON
		and b.y >= a.y - EPSILON
		and b.x + b.w <= a.x + a.w + EPSILON
		and b.y + b.h <= a.y + a.h + EPSILON
end

local function occupy(free, box)
	local nextFree = {}
	for _, rect in free do
		if
			box.x >= rect.x + rect.w - EPSILON
			or box.x + box.w <= rect.x + EPSILON
			or box.y >= rect.y + rect.h - EPSILON
			or box.y + box.h <= rect.y + EPSILON
		then
			table.insert(nextFree, rect)
		else
			if box.x > rect.x + EPSILON then
				table.insert(nextFree, { x = rect.x, y = rect.y, w = box.x - rect.x, h = rect.h })
			end
			if box.x + box.w < rect.x + rect.w - EPSILON then
				table.insert(
					nextFree,
					{ x = box.x + box.w, y = rect.y, w = rect.x + rect.w - box.x - box.w, h = rect.h }
				)
			end
			if box.y > rect.y + EPSILON then
				table.insert(nextFree, { x = rect.x, y = rect.y, w = rect.w, h = box.y - rect.y })
			end
			if box.y + box.h < rect.y + rect.h - EPSILON then
				table.insert(
					nextFree,
					{ x = rect.x, y = box.y + box.h, w = rect.w, h = rect.y + rect.h - box.y - box.h }
				)
			end
		end
	end
	for index = #nextFree, 1, -1 do
		for other, rect in nextFree do
			if other ~= index and contains(rect, nextFree[index]) then
				table.remove(nextFree, index)
				break
			end
		end
	end
	return nextFree
end

function Packing.layout(records, count: number, measure)
	local width = Packing.RIGHT - Packing.LEFT - 2 * Packing.MARGIN
	local depth = (Packing.FRONT - Packing.BACK) / math.cos(Packing.SLOPE) - 2 * Packing.MARGIN
	local beds, items, placements = {}, {}, {}
	for _ = 1, count do
		table.insert(beds, { { x = 0, y = 0, w = width + Packing.GAP, h = depth + Packing.GAP } })
	end
	for index, record in records do
		local size = measure(record)
		if size then
			table.insert(items, { index = index, w = math.max(size.Y, size.Z), h = size.X, flat = size.Z > size.Y })
		end
	end
	-- Large fish go first; small catches then fill the remaining gaps, including
	-- extra rows and rotated spaces. Never shrink a catch to make it fit.
	table.sort(items, function(a, b)
		local areaA, areaB = a.w * a.h, b.w * b.h
		return if areaA == areaB then a.index < b.index else areaA > areaB
	end)
	local fitted, used = 0, 0
	for _, item in items do
		local best, short, long = nil, math.huge, math.huge
		for bed, free in beds do
			for _, rect in free do
				for rotation = 0, 1 do
					local w = (if rotation == 0 then item.w else item.h) + Packing.GAP
					local h = (if rotation == 0 then item.h else item.w) + Packing.GAP
					if w <= rect.w + EPSILON and h <= rect.h + EPSILON then
						local s, l = math.min(rect.w - w, rect.h - h), math.max(rect.w - w, rect.h - h)
						if s < short - EPSILON or (math.abs(s - short) <= EPSILON and l < long - EPSILON) then
							best = { x = rect.x, y = rect.y, w = w, h = h, bed = bed, rotated = rotation == 1 }
							short, long = s, l
						end
					end
				end
			end
		end
		used += item.w * item.h
		if best then
			beds[best.bed] = occupy(beds[best.bed], best)
			placements[item.index] = {
				Freezer = best.bed,
				X = Packing.LEFT + Packing.MARGIN + best.x + (best.w - Packing.GAP) / 2,
				Z = Packing.BACK + (Packing.MARGIN + best.y + (best.h - Packing.GAP) / 2) * math.cos(Packing.SLOPE),
				Rotated = best.rotated,
				Flat = item.flat,
			}
			fitted += 1
		end
	end
	return placements, fitted == #records, used / (width * depth * count)
end

return Packing
