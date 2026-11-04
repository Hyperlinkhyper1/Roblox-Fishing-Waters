-- Find exposed, same-facing coplanar block faces, including rotated parts.
-- Buried seams and opposite-facing joints do not cause visible z-fighting.
local function surfaceOverlaps(root)
	local blocks, faces, overlaps = {}, {}, {}
	for _, p in root:GetDescendants() do
		if p:IsA("Part") and p.Shape == Enum.PartType.Block and p.Transparency < 1 then
			local axes, half = { p.CFrame.RightVector, p.CFrame.UpVector, p.CFrame.ZVector }, p.Size / 2
			local sizes = { half.X, half.Y, half.Z }
			table.insert(blocks, { part = p, axes = axes, sizes = sizes })
			for axis = 1, 3 do
				local u, v = axis % 3 + 1, (axis + 1) % 3 + 1
				for _, sign in { -1, 1 } do
					table.insert(faces, {
						part = p, normal = axes[axis] * sign, centre = p.Position + axes[axis] * sizes[axis] * sign,
						u = axes[u], v = axes[v], w = sizes[u], h = sizes[v],
					})
				end
			end
		end
	end
	local function clip(poly, axis, bound, direction)
		local out = {}
		for i, a in poly do
			local b = poly[i % #poly + 1]
			local da, db = (a[axis] - bound) * direction, (b[axis] - bound) * direction
			if da >= 0 then table.insert(out, a) end
			if (da >= 0) ~= (db >= 0) then
				local t = da / (da - db)
				table.insert(out, { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t })
			end
		end
		return out
	end
	local function exposed(point, a, b)
		for _, block in blocks do
			if block.part ~= a and block.part ~= b and block.part.Transparency == 0 then
				local q, inside = point - block.part.Position, true
				for axis = 1, 3 do
					if math.abs(q:Dot(block.axes[axis])) >= block.sizes[axis] - 0.0001 then inside = false; break end
				end
				if inside then return false end
			end
		end
		return true
	end
	for i, a in faces do
		for j = i + 1, #faces do
			local b = faces[j]
			if a.part == b.part or a.normal:Dot(b.normal) < 0.999999 or math.abs((b.centre - a.centre):Dot(a.normal)) > 0.001 then continue end
			local poly = {}
			for _, signs in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
				local q = b.centre + b.u * b.w * signs[1] + b.v * b.h * signs[2] - a.centre
				table.insert(poly, { q:Dot(a.u), q:Dot(a.v) })
			end
			poly = clip(clip(clip(clip(poly, 1, -a.w, 1), 1, a.w, -1), 2, -a.h, 1), 2, a.h, -1)
			local area, cx, cy = 0, 0, 0
			for k, p in poly do
				local q = poly[k % #poly + 1]
				area += p[1] * q[2] - q[1] * p[2]
				cx += p[1]; cy += p[2]
			end
			if math.abs(area) < 0.002 then continue end
			cx /= #poly; cy /= #poly
			local visible = exposed(a.centre + a.u * cx + a.v * cy + a.normal * 0.005, a.part, b.part)
			for _, p in poly do
				if visible then break end
				visible = exposed(a.centre + a.u * (p[1] * 0.95 + cx * 0.05) + a.v * (p[2] * 0.95 + cy * 0.05) + a.normal * 0.005, a.part, b.part)
			end
			if visible then table.insert(overlaps, { a = a.part, b = b.part, normal = a.normal, area = math.abs(area) / 2 }) end
		end
	end
	return overlaps
end
