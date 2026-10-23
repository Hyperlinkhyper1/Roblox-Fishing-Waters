function CFrame.Angles(x, y, z)
	local cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
	return CFrame.fromMatrix(
		vector(0, 0, 0),
		vector(cy * cz, cx * sz + sx * sy * cz, sx * sz - cx * sy * cz),
		vector(-cy * sz, cx * cz - sx * sy * sz, sx * cz + cx * sy * sz),
		vector(sy, -sx * cy, cx * cy)
	)
end
function frameMeta.__index(self, key)
	if key == "PointToWorldSpace" then
		return function(frame, point)
			return frame.Position + transform(frame, point)
		end
	end
end
Color3.new = Color3.fromRGB
local Random = {}
function Random.new(seed)
	local state = seed + 1
	return {
		NextNumber = function(_, low, high)
			state = state * 16807 % 2147483647
			return (low or 0) + ((high or 1) - (low or 0)) * state / 2147483647
		end,
	}
end

-- MODULES --

local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end
local function area(points)
	local result = 0
	for i, p in points do
		local q = points[i % #points + 1]
		result += p.X * q.Z - q.X * p.Z
	end
	return result / 2
end
local function side(p, a, b)
	return (b.X - a.X) * (p.Z - a.Z) - (b.Z - a.Z) * (p.X - a.X)
end
local function clippedArea(subject, clip)
	local polygon = subject
	local winding = if area(clip) > 0 then 1 else -1
	for i, a in clip do
		if #polygon == 0 then
			return 0
		end
		local b, output = clip[i % #clip + 1], {}
		local previous = polygon[#polygon]
		local pd = side(previous, a, b) * winding
		for _, current in polygon do
			local cd = side(current, a, b) * winding
			if (cd >= 0) ~= (pd >= 0) then
				table.insert(output, previous:Lerp(current, pd / (pd - cd)))
			end
			if cd >= 0 then
				table.insert(output, current)
			end
			previous, pd = current, cd
		end
		polygon = output
	end
	return math.abs(area(polygon))
end
local function faces(model)
	local result = {}
	for _, part in model:GetDescendants() do
		if not part:IsA("BasePart") or part.Shape == Enum.PartType.Cylinder then
			continue
		end
		local h = part.Size / 2
		local points = {
			vector(-h.X, -h.Y, -h.Z),
			vector(h.X, -h.Y, -h.Z),
			vector(h.X, -h.Y, h.Z),
			vector(-h.X, -h.Y, h.Z),
			vector(-h.X, h.Y, -h.Z),
			vector(h.X, h.Y, -h.Z),
			vector(h.X, h.Y, h.Z),
			vector(-h.X, h.Y, h.Z),
		}
		local indices = if part:IsA("WedgePart")
			then { { 1, 4, 3, 2 }, { 1, 2, 6, 5 }, { 1, 5, 4 }, { 2, 3, 6 }, { 4, 5, 6, 3 } }
			else { { 1, 4, 3, 2 }, { 1, 2, 6, 5 }, { 1, 5, 8, 4 }, { 2, 3, 7, 6 }, { 4, 8, 7, 3 }, { 5, 6, 7, 8 } }
		for _, list in indices do
			local world = {}
			for _, index in list do
				table.insert(world, part.CFrame:PointToWorldSpace(points[index]))
			end
			local normal = (world[2] - world[1]):Cross(world[3] - world[1]).Unit
			table.insert(result, { part = part, points = world, normal = normal })
		end
	end
	return result
end
local function overlaps(model)
	local surfaces, count = faces(model), 0
	for i, a in surfaces do
		for j = i + 1, #surfaces do
			local b = surfaces[j]
			-- Opposite normals are ordinary touching joints; same-facing overlapping
			-- surfaces compete for the same pixels and must have no shared area.
			if a.part == b.part or a.normal:Dot(b.normal) < 0.999999 then
				continue
			end
			if math.abs((a.points[1] - b.points[1]):Dot(a.normal)) > 0.00001 then
				continue
			end
			local u = (a.points[2] - a.points[1]).Unit
			local v = a.normal:Cross(u)
			local function project(points)
				local output = {}
				for _, p in points do
					table.insert(output, vector(p:Dot(u), 0, p:Dot(v)))
				end
				return output
			end
			if clippedArea(project(a.points), project(b.points)) > 0.00001 then
				count += 1
			end
		end
	end
	return count
end
local color = Color3.fromRGB(60, 140, 90)
local fixed, legacy = 0, 0
for _, length in { 13, 15, 17 } do
	for _, width in { 4.6, 5.1, 5.6 } do
		for _, mast in { false, true } do
			for _, angle in { 0, 0.71, 2.4 } do
				local parent = Instance.new("Model")
				local boat = Med.boat(
					parent,
					vector(34, 0, -28),
					angle,
					Random.new(0),
					color,
					{ length = length, width = width, mast = mast }
				)
				check(overlaps(boat) == 0, `coplanar face overlap: length={length}, width={width}, mast={mast}`)
				local floor
				for _, p in boat:GetChildren() do
					if p.Name == "BoatFloor" then
						floor = p
					end
					if p:IsA("WedgePart") then
						check(p.Size.X == 0.12, "boat hull thickness")
					end
				end
				check(floor.CFrame.Position.Y - floor.Size.Y / 2 > 0.1, "floor must clear water and waves")
				check(floor.Size.X < width - 0.8, "floor must stay inside hull")
				Med.ensureBoats(parent)
				check(parent:GetChildren()[1] == boat, "new boat must not be replaced on startup")
				fixed += 1
			end
		end
	end
end
for seed = 1, 12 do
	local parent = Instance.new("Model")
	local position, angle = vector(80, if seed % 2 == 0 then 0 else 3, -110), seed * 0.37
	local boat = Med.legacyBoat(parent, position, angle, Random.new(seed), color)
	check(overlaps(boat) > 0, "fixture must reproduce original z-fighting")
	local floor
	local hasMast = false
	for _, p in boat:GetChildren() do
		if p:IsA("Part") and math.abs(p.Size.Y - 0.4) < 0.001 and p.Size.X >= 4.6 and p.Size.X <= 5.6 then
			floor = p
		end
		if p.Shape == Enum.PartType.Cylinder then
			hasMast = true
		end
	end
	Med.ensureBoats(parent)
	local children = parent:GetChildren()
	check(#children == 1 and boat.destroyed, "legacy boat must be replaced once")
	local replacement = children[1]
	check(overlaps(replacement) == 0, "baked boat overlaps")
	local newFloor, newMast
	for _, p in replacement:GetChildren() do
		if p.Name == "BoatFloor" then
			newFloor = p
		end
		if p.Shape == Enum.PartType.Cylinder then
			newMast = true
		end
	end
	check((newFloor.CFrame.Position - (position + vector(0, 0.4, 0))).Magnitude < 0.00001, "baked boat position")
	check((newFloor.CFrame.LookVector - floor.CFrame.LookVector).Magnitude < 0.00001, "baked boat rotation")
	check(math.abs(newFloor.Size.Z - floor.Size.Z) < 0.00001, "baked boat length")
	check(math.abs(newFloor.Size.X + 0.88 - floor.Size.X) < 0.00001, "baked boat beam")
	check((newMast == true) == hasMast, "baked boat mast variant")
	Med.ensureBoats(parent)
	check(parent:GetChildren()[1] == replacement, "baked upgrade must be idempotent")
	legacy += 1
end
print(
	`Painted boats: {checks} checks passed, {fixed} geometry variants with zero coplanar overlaps, {legacy} saved-map upgrades. Mock geometry only; Studio rendering remains unverified.`
)
