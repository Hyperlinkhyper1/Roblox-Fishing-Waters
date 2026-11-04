-- Company islands. Local -Z faces Gullhaven.
--
-- The ground (a sandy shore and a cliff-sided upper terrace), the sale board and
-- the boat marker are permanent. Everything else is a swappable "Dressing": an
-- unowned island is plain wild land with a small jetty, and while someone owns it
-- (Islands.dress) it becomes a detailed harbour village with a quay, two piers, a
-- walled cliff and stone stairs up to an empty fenced plot. The owner furnishes
-- that plot from build mode; FurnitureService builds it under "PlotFurniture".
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Layout = require(game:GetService("ReplicatedStorage").Shared.CompanyIslands)
local LowPoly = require(script.Parent.LowPoly)
local Props = require(script.Parent.Props)
local Lod = require(script.Parent.Lod)

local Islands = { VERSION = 4 }
local rgb, M = Color3.fromRGB, Enum.Material
local ROCK, SAND, GRASS = rgb(100, 107, 105), rgb(191, 177, 142), rgb(107, 123, 80)
local WOOD, TRIM, ROOF = rgb(133, 100, 72), rgb(66, 61, 51), rgb(69, 83, 87)
local STONE, PEBBLE, DIRT = rgb(146, 143, 132), rgb(176, 165, 140), rgb(118, 101, 80)
local LEAVES = { rgb(70, 98, 60), rgb(86, 114, 66), rgb(58, 86, 58), rgb(104, 126, 72) }
local PINES = { rgb(52, 73, 56), rgb(46, 66, 52), rgb(60, 82, 60) }
local ACCENTS = { rgb(116, 150, 147), rgb(170, 118, 95), rgb(178, 157, 107), rgb(125, 148, 115), rgb(136, 144, 169), rgb(179, 144, 120) }
local TERRACE, BEACH = 24.4, 4.4
local v2 = Vector2.new
-- A wide beach in front for the docks; round the back the cliffs drop straight
-- into the sea, so the coast hugs the terrace there.
local COAST = {
	v2(-64, -97), v2(-92, -84), v2(-108, -52), v2(-104, -22), v2(-95, 6), v2(-90, 38), v2(-100, 62),
	v2(-84, 92), v2(-50, 101), v2(-12, 95), v2(22, 105), v2(60, 97), v2(88, 75), v2(101, 40),
	v2(96, 10), v2(106, -20), v2(100, -58), v2(88, -86), v2(64, -97),
}
-- The terrace cliff: a straight front along the square, ragged everywhere else, and a
-- cut (NOTCH wide, back to NOTCH_BACK) that the stair climbs through.
local FRONT, NOTCH, NOTCH_BACK = -26, 9.5, 2
local UPPER = {
	v2(-NOTCH, FRONT), v2(-64, FRONT), v2(-84, -12), v2(-90, 10), v2(-85, 38), v2(-95, 62), v2(-80, 88),
	v2(-48, 97), v2(-12, 91), v2(22, 101), v2(58, 93), v2(84, 72), v2(97, 40), v2(90, 10), v2(95, -14),
	v2(64, FRONT), v2(NOTCH, FRONT), v2(NOTCH, NOTCH_BACK), v2(-NOTCH, NOTCH_BACK),
}
-- Rocky knolls standing above the terrace on either flank of the plot.
local RIDGES = {
	{ top = 35, outline = { v2(-68, 14), v2(-80, 4), v2(-86, 14), v2(-81, 38), v2(-89, 60), v2(-76, 82), v2(-62, 84), v2(-66, 58), v2(-62, 34) } },
	{ top = 32, outline = { v2(66, 40), v2(80, 30), v2(90, 40), v2(82, 60), v2(74, 76), v2(64, 72), v2(68, 56) } },
}
-- Sea stacks standing off the back of the island.
local STACKS = { v2(-124, 66), v2(120, 98), v2(-38, 124) }
-- The stair: 32 risers of 0.625 studs, starting this far out on the beach.
local STAIR_START, STAIR_RUN = -38, 1.25
-- Lod streams a model of up to PIECE_PARTS parts as one piece and splits bigger ones
-- into their children, so big models must not hold loose parts (they'd stream alone).
local PIECE_PARTS, CHUNK_PARTS = 200, 150

local function group(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name, model.Parent = name, parent
	return model
end

local function part(parent, name, size, frame, color, material, collide)
	local piece = Props.part(parent, size, frame, color, material)
	piece.Name = name
	if collide == false then
		piece.CanCollide, piece.CanTouch, piece.CanQuery = false, false, false
	end
	return piece
end

local function sign(parent, frame, name, value, width)
	local board = part(parent, name, Vector3.new(width or 16, 3, 0.35), frame, TRIM, M.WoodPlanks, false)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face, gui.SizingMode, gui.PixelsPerStud = face, Enum.SurfaceGuiSizingMode.PixelsPerStud, 35
		local label = Instance.new("TextLabel")
		label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
		label.Font, label.TextScaled, label.TextColor3 = Enum.Font.Garamond, true, rgb(245, 234, 208)
		label.Text, label.Parent, gui.Parent = value, gui, board
	end
	return board
end

local function prompt(parent, name, action, object, ownerOnly)
	local result = Instance.new("ProximityPrompt")
	result.Name, result.ActionText, result.ObjectText = name, action, object
	result.MaxActivationDistance, result.HoldDuration, result.RequiresLineOfSight = 10, 0.3, false
	result.Parent = parent
	if ownerOnly then
		result:SetAttribute("OwnerUserId", 0)
		CollectionService:AddTag(result, "ShopOwnerPrompt")
	end
	return result
end

local function shade(color: Color3, rng: Random, amount: number): Color3
	local s = 1 + rng:NextNumber(-amount, amount)
	return Color3.new(math.min(color.R * s, 1), math.min(color.G * s, 1), math.min(color.B * s, 1))
end

local function signedArea(outline: { Vector2 }): number
	local sum = 0
	for index, a in outline do
		local b = outline[index % #outline + 1]
		sum += a.X * b.Y - b.X * a.Y
	end
	return sum / 2
end

-- Outward unit normal of each edge, outline[i] -> outline[i + 1].
local function normals(outline: { Vector2 }): { Vector2 }
	local sign = if signedArea(outline) > 0 then 1 else -1
	local result = {}
	for index, a in outline do
		local d = (outline[index % #outline + 1] - a).Unit
		result[index] = Vector2.new(d.Y, -d.X) * sign
	end
	return result
end

-- Ear clipping, so outlines can be concave (coves, the stair cut).
local function triangulate(outline: { Vector2 }): { { Vector2 } }
	local sign = if signedArea(outline) > 0 then 1 else -1
	local function turn(o, a, b)
		return ((a.X - o.X) * (b.Y - o.Y) - (a.Y - o.Y) * (b.X - o.X)) * sign
	end
	local left, result = {}, {}
	for index in outline do
		table.insert(left, index)
	end
	while #left > 3 do
		local clipped = false
		for i = 1, #left do
			local ia, ib, ic = left[(i - 2) % #left + 1], left[i], left[i % #left + 1]
			local a, b, c = outline[ia], outline[ib], outline[ic]
			local ear = turn(a, b, c) > 0
			for _, j in left do
				if ear and j ~= ia and j ~= ib and j ~= ic then
					local p = outline[j]
					ear = not (turn(a, b, p) >= 0 and turn(b, c, p) >= 0 and turn(c, a, p) >= 0)
				end
			end
			if ear then
				table.insert(result, { a, b, c })
				table.remove(left, i)
				clipped = true
				break
			end
		end
		if not clipped then
			break
		end
	end
	if #left == 3 then
		table.insert(result, { outline[left[1]], outline[left[2]], outline[left[3]] })
	end
	return result
end

-- A flat top over `outline` with rock sides falling `spread` studs outward to
-- `bottom`. No terrain edits that could flood nearby rooms.
local function plateau(parent, frame: CFrame, outline: { Vector2 }, top: number, bottom: number, spread: number, color, material)
	for _, tri in triangulate(outline) do
		local a = frame * Vector3.new(tri[1].X, top, tri[1].Y)
		local b = frame * Vector3.new(tri[2].X, top, tri[2].Y)
		local c = frame * Vector3.new(tri[3].X, top, tri[3].Y)
		LowPoly.triangle(a, b, c, (a + b + c) / 3 - frame.UpVector, color, parent, material)
	end
	local edges = normals(outline)
	-- Mitred corner offsets keep neighbouring sides joined.
	local corners = {}
	for index in outline do
		local n1, n2 = edges[(index - 2) % #outline + 1], edges[index]
		corners[index] = (n1 + n2) / math.max(1 + n1:Dot(n2), 0.5)
	end
	for index, p in outline do
		local nextIndex = index % #outline + 1
		local q = outline[nextIndex]
		local pc, qc = p + corners[index] * spread, q + corners[nextIndex] * spread
		local a, b = frame * Vector3.new(p.X, top, p.Y), frame * Vector3.new(q.X, top, q.Y)
		local c, d = frame * Vector3.new(pc.X, bottom, pc.Y), frame * Vector3.new(qc.X, bottom, qc.Y)
		local mid = (p + q) / 2 - edges[index] * 4
		local inside = frame * Vector3.new(mid.X, (top + bottom) / 2, mid.Y)
		LowPoly.triangle(a, c, d, inside, ROCK, parent, M.Slate)
		LowPoly.triangle(a, d, b, inside, ROCK, parent, M.Slate)
	end
end

local function insidePolygon(outline, x: number, z: number): boolean
	local result = false
	for index, a in outline do
		local b = outline[index % #outline + 1]
		if (a.Y > z) ~= (b.Y > z) and x < (b.X - a.X) * (z - a.Y) / (b.Y - a.Y) + a.X then
			result = not result
		end
	end
	return result
end

-- Height of the upper ground (a ridge or the terrace) at island-local x, z; nil off it.
local function groundLevel(x: number, z: number): number?
	for _, ridge in RIDGES do
		if insidePolygon(ridge.outline, x, z) then
			return ridge.top
		end
	end
	return if insidePolygon(UPPER, x, z) then TERRACE else nil
end

local function notchEdge(a: Vector2, b: Vector2): boolean
	return a.X == b.X and math.abs(a.X) == NOTCH
end

local function frontEdge(a: Vector2, b: Vector2): boolean
	return a.Y == FRONT and b.Y == FRONT and not notchEdge(a, b)
end

-- Island-local helpers shared by both dressings. `yaw` turns an island-local
-- heading (0 faces -Z, toward Gullhaven) into the world angle Props expects.
local function kit(frame: CFrame, parent: Model, rng: Random)
	local self = {}
	function self.at(x: number, y: number, z: number): Vector3
		return frame * Vector3.new(x, y, z)
	end
	function self.cf(x: number, y: number, z: number, turn: number?): CFrame
		return frame * CFrame.new(x, y, z) * CFrame.Angles(0, turn or 0, 0)
	end
	function self.yaw(turn: number): number
		local look = frame * Vector3.new(-math.sin(turn), 0, -math.cos(turn)) - frame.Position
		return math.atan2(-look.X, -look.Z)
	end
	-- A random spot on the terrace or a ridge, at least `margin` from any cliff edge and
	-- outside the `avoid` boxes, with the ground height there.
	function self.terraceSpot(margin: number, avoid: { { number } }): (number?, number?, number?)
		for _ = 1, 40 do
			local x, z = rng:NextNumber(-96, 98), rng:NextNumber(-26, 102)
			local level = groundLevel(x, z)
			for _, offset in { { margin, 0 }, { -margin, 0 }, { 0, margin }, { 0, -margin } } do
				if groundLevel(x + offset[1], z + offset[2]) ~= level then
					level = nil
				end
			end
			for _, box in avoid do
				if x > box[1] and x < box[3] and z > box[2] and z < box[4] then
					level = nil
				end
			end
			if level then
				return x, z, level
			end
		end
		return nil, nil, nil
	end
	self.rng, self.parent = rng, parent
	return self
end

-- Wraps the loose parts of every model too big for one piece into chunk models.
local function pack(model: Instance)
	local count = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			count += 1
		end
	end
	if count <= PIECE_PARTS then
		return
	end
	local loose = {}
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(loose, child)
		elseif child:IsA("Model") then
			pack(child)
		end
	end
	local chunk
	for index, piece in loose do
		if (index - 1) % CHUNK_PARTS == 0 then
			chunk = group(model, model.Name .. "Chunk")
		end
		piece.Parent = chunk
	end
end

-- Stacked, slightly tumbled rock blocks facing one cliff edge (island-local a -> b,
-- `normal` pointing out of the cliff) from `bottom` up to a ragged lip at `top`.
-- Lower courses stand further out, so the face leans back like weathered rock.
local function cliffFace(parent: Instance, k, a: Vector2, b: Vector2, normal: Vector2, top: number, bottom: number, out: number)
	local rng = k.rng
	local length = (b - a).Magnitude
	local along = (b - a) / length
	local y = bottom
	while y < top - 0.01 do
		local h = math.min(rng:NextNumber(5, 8.5), top - y)
		if top - y - h < 3 then
			h = top - y
		end
		local lip = y + h >= top - 0.01
		local lean = (top - y - h) / math.max(top - bottom, 1) * out
		local s = -1 - rng:NextNumber(0, 3)
		while s < length + 1 do
			local e = math.min(s + rng:NextNumber(6, 12), length + 1)
			local s0 = math.max(s, -1)
			if e - s0 > 1 then
				local depth = rng:NextNumber(5, 8)
				local height = h + (if lip then rng:NextNumber(-0.5, 0.6) else rng:NextNumber(0.3, 1.2))
				local mid = a + along * ((s0 + e) / 2) + normal * (rng:NextNumber(0.3, out) + lean - depth / 2)
				local center = k.at(mid.X, y + height / 2, mid.Y)
				local facing = k.at(mid.X + normal.X, y + height / 2, mid.Y + normal.Y)
				local tumble = CFrame.Angles(rng:NextNumber(-0.05, 0.05), rng:NextNumber(-0.08, 0.08), rng:NextNumber(-0.05, 0.05))
				local block = part(parent, "CliffBlock", Vector3.new(e - s0 + 0.6, height, depth), CFrame.lookAt(center, facing) * tumble, shade(ROCK, rng, 0.1), M.Slate)
				if lip and rng:NextNumber() < 0.4 then
					part(parent, "CliffMoss", Vector3.new((e - s0) * 0.8, 0.3, depth * 0.7), block.CFrame * CFrame.new(0, height / 2 + 0.1, 0), shade(GRASS, rng, 0.1), M.Grass, false)
				end
			end
			s = e
		end
		y += h
	end
end

-- A tumbled rock: one tilted slab, sometimes with smaller ones leaning on it.
local function stone(parent: Instance, k, x: number, y: number, z: number, size: number): Model
	local rng = k.rng
	local rock = group(parent, "Stone")
	for index = 1, rng:NextInteger(1, 3) do
		local s = if index == 1 then size else size * rng:NextNumber(0.4, 0.7)
		local ox, oz = 0, 0
		if index > 1 then
			ox, oz = rng:NextNumber(-0.6, 0.6) * size, rng:NextNumber(-0.6, 0.6) * size
		end
		local tilt = CFrame.Angles(rng:NextNumber(-0.35, 0.35), 0, rng:NextNumber(-0.35, 0.35))
		part(rock, "StoneBlock", Vector3.new(s, s * rng:NextNumber(0.5, 0.8), s * rng:NextNumber(0.65, 1)), k.cf(x + ox, y + s * 0.15, z + oz, rng:NextNumber(0, math.pi * 2)) * tilt, shade(ROCK, rng, 0.12), M.Slate)
	end
	return rock
end

-- Rocks along the waterline at uneven gaps, in loose clusters, some on the sand
-- and some standing well out in the water. `skip(x, z)` keeps a stretch clear.
local function shoreRocks(k, skip: (number, number) -> boolean)
	local rng = k.rng
	local rocks = group(k.parent, "ShoreRocks")
	local edges = normals(COAST)
	local gap = rng:NextNumber(0, 10)
	for index, a in COAST do
		local b = COAST[index % #COAST + 1]
		local length = (b - a).Magnitude
		local t = gap
		while t < length do
			local out = if rng:NextNumber() < 0.25 then rng:NextNumber(8, 26) else rng:NextNumber(-3, 5)
			local point = a + (b - a) * (t / length) + edges[index] * out
			if not skip(point.X, point.Y) and not insidePolygon(UPPER, point.X, point.Y) then
				local y = if out < 0 then BEACH - 0.6 else rng:NextNumber(-1.2, 1.4)
				stone(rocks, k, point.X, y, point.Y, rng:NextNumber(2.5, if out > 8 then 8 else 6))
			end
			-- Either another rock close by or a long empty stretch.
			t += if rng:NextNumber() < 0.4 then rng:NextNumber(2, 5) else rng:NextNumber(8, 30)
		end
		gap = t - length
	end
	return rocks
end

-- Rocks fallen at the foot of the terrace cliff, onto the beach only.
local function cliffRocks(k, skip: (number, number) -> boolean)
	local rng = k.rng
	local rocks = group(k.parent, "CliffRocks")
	local edges = normals(UPPER)
	for index, a in UPPER do
		local b = UPPER[index % #UPPER + 1]
		local length = (b - a).Magnitude
		local t = rng:NextNumber(0, 12)
		while t < length do
			local point = a + (b - a) * (t / length) + edges[index] * rng:NextNumber(3, 8)
			if insidePolygon(COAST, point.X, point.Y) and not insidePolygon(UPPER, point.X, point.Y) and not skip(point.X, point.Y) then
				stone(rocks, k, point.X, BEACH - 0.5, point.Y, rng:NextNumber(2, 5.5))
			end
			t += rng:NextNumber(6, 28)
		end
	end
	return rocks
end

-- Trees, bushes and mounds scattered over the upper terrace.
local function woodland(k, trees: number, bushes: number, avoid: { { number } })
	local rng = k.rng
	local wood = group(k.parent, "Woodland")
	for index = 1, trees do
		local x, z, y = k.terraceSpot(7, avoid)
		if x then
			if index % 3 == 0 then
				Props.broadleaf(wood, k.at(x, y, z), rng, LEAVES)
			else
				Props.pine(wood, k.at(x, y, z), rng, Props.pick(rng, PINES))
			end
		end
	end
	for index = 1, bushes do
		local x, z, y = k.terraceSpot(3, avoid)
		if x then
			if index % 4 == 0 then
				Props.flowers(wood, k.at(x, y, z), rng)
			elseif index % 5 == 0 then
				stone(wood, k, x, y - 0.5, z, rng:NextNumber(1.8, 3.5))
			else
				Props.bush(wood, k.at(x, y, z), rng, LEAVES)
			end
		end
	end
	return wood
end

-- One wooden plank deck with gaps: `along` X or Z, top at `top`.
local function planks(parent: Instance, k, x1: number, z1: number, x2: number, z2: number, top: number, alongX: boolean, name: string)
	local rng = k.rng
	local span = if alongX then z2 - z1 else x2 - x1
	local count = math.max(1, math.floor(span / 1.6 + 0.5))
	local width = span / count
	for index = 0, count - 1 do
		local c = (if alongX then z1 else x1) + (index + 0.5) * width
		local size = if alongX then Vector3.new(x2 - x1, 0.5, width - 0.12) else Vector3.new(width - 0.12, 0.5, z2 - z1)
		local center = if alongX then Vector3.new((x1 + x2) / 2, top - 0.25, c) else Vector3.new(c, top - 0.25, (z1 + z2) / 2)
		part(parent, name, size, k.cf(center.X, center.Y, center.Z), shade(WOOD, rng, 0.1), M.WoodPlanks)
	end
end

local function pile(parent: Instance, k, x: number, z: number, top: number)
	local piece = Props.cylinder(parent, k.at(x, (top - 9) / 2, z), top + 9, 1.1, shade(TRIM, k.rng, 0.12), M.Wood)
	piece.Name = "PierPile"
	return piece
end

-- A wooden post with a crossarm and a lantern hanging off it.
local function lanternPost(parent: Instance, k, x: number, z: number, y: number, turn: number)
	local post = group(parent, "LanternPost")
	part(post, "Post", Vector3.new(0.7, 9, 0.7), k.cf(x, y + 4.5, z, turn), TRIM, M.Wood)
	part(post, "Arm", Vector3.new(0.4, 0.4, 2.8), k.cf(x, y + 8.6, z, turn) * CFrame.new(0, 0, -1.1), TRIM, M.Wood)
	part(post, "Brace", Vector3.new(0.3, 0.3, 1.8), k.cf(x, y + 7.8, z, turn) * CFrame.new(0, 0, -0.6) * CFrame.Angles(math.rad(40), 0, 0), TRIM, M.Wood, false)
	Props.lantern(post, k.cf(x, y + 7.3, z, turn) * CFrame.new(0, 0, -2.2), 18, 1.1)
	return post
end

local function bollard(parent: Instance, k, x: number, z: number, y: number)
	local piece = Props.cylinder(parent, k.at(x, y + 0.6, z), 1.2, 1, rgb(44, 46, 48), M.Metal)
	piece.Name = "Bollard"
	local cap = Props.cylinder(parent, k.at(x, y + 1.25, z), 0.25, 1.4, rgb(44, 46, 48), M.Metal)
	cap.Name, cap.CanCollide = "BollardCap", false
end

-- Top of the stair's walking surface at island-local z.
local function stairHeight(z: number): number
	return BEACH + math.clamp(math.ceil((z - STAIR_START) / STAIR_RUN), 0, 32) * 0.625
end

-- A rough natural staircase worn into the cut in the cliff, without a jump.
local function roughSteps(k)
	local rng = k.rng
	local steps = group(k.parent, "RoughSteps")
	for step = 1, 32 do
		local height = step * 0.625
		part(steps, "RoughStep", Vector3.new(rng:NextNumber(13, 15.5), height, STAIR_RUN + 0.05), k.cf(rng:NextNumber(-0.4, 0.4), BEACH + height / 2, STAIR_START + (step - 0.5) * STAIR_RUN, rng:NextNumber(-0.03, 0.03)), shade(rgb(122, 120, 112), rng, 0.08), M.Slate)
	end
	-- Loose rock heaped on the cheeks either side of the foot.
	for side = -1, 1, 2 do
		for index = 1, 3 do
			local z = STAIR_START + index * 3.5
			stone(steps, k, side * rng:NextNumber(11, 15), stairHeight(z) + 2.5, z, rng:NextNumber(1.6, 2.8))
		end
	end
	return steps
end

-- Keeps the docks, the stair's foot and the boat approach free of rocks.
local function clearOfLanding(x: number, z: number): boolean
	return (z < -78 and math.abs(x) < 75) or (math.abs(x) < 20 and z < FRONT and z > STAIR_START - 10)
end

local function buildWild(island: Model, frame: CFrame, id: number): Model
	local dressing = Instance.new("Model")
	dressing.Name = "Dressing"
	dressing:SetAttribute("Kind", "Wild")
	local rng = Random.new(5100 + id)
	local k = kit(frame, dressing, rng)
	shoreRocks(k, clearOfLanding)
	cliffRocks(k, clearOfLanding)
	-- Bare rock on the cliff front too; the village lays a harbour wall there instead.
	local front = group(dressing, "CliffFront")
	local edges = normals(UPPER)
	for index, a in UPPER do
		local b = UPPER[index % #UPPER + 1]
		if frontEdge(a, b) then
			cliffFace(front, k, a, b, edges[index], TERRACE, -3, 2.5)
		end
	end
	roughSteps(k)
	woodland(k, 34, 40, { { -14, -30, 14, 10 } })
	-- Mossy mounds roll the flat terrace top into a wooded hill.
	local mounds = group(dressing, "Mounds")
	for _ = 1, 9 do
		local x, z, y = k.terraceSpot(12, { { -16, -30, 16, 12 } })
		if x then
			local radius = rng:NextNumber(6, 11)
			LowPoly.boulder(k.at(x, y - radius * 0.55, z), radius, rng, shade(GRASS, rng, 0.08), mounds, M.Grass)
		end
	end
	-- A bare beach: driftwood, shells and pebbles.
	local beach = group(dressing, "Beach")
	for index = 1, 26 do
		local x, z = rng:NextNumber(-85, 85), rng:NextNumber(-88, -34)
		if insidePolygon(COAST, x * 1.05, z * 1.05) and not (math.abs(x + 20) < 5 and z < -80) and not (math.abs(x) < 20 and z > -46) then
			if index % 4 == 0 then
				Props.driftwood(beach, k.at(x, BEACH, z), rng)
			elseif index % 4 == 1 then
				Props.shells(beach, k.at(x, BEACH, z), rng)
			elseif index % 4 == 2 then
				Props.rock(beach, k.at(x, BEACH, z), rng, rng:NextNumber(1.2, 2.6), ROCK)
			else
				Props.bush(beach, k.at(x, BEACH, z), rng, { rgb(150, 150, 96), rgb(128, 138, 84) })
			end
		end
	end
	-- One old jetty to land on, beside the sale board.
	local jetty = group(dressing, "Jetty")
	planks(jetty, k, -22.5, -128, -17.5, -90, BEACH, true, "JettyPlank")
	for z = -128, -92, 6 do
		for _, x in { -22.6, -17.4 } do
			pile(jetty, k, x, z, BEACH - 0.2)
		end
	end
	bollard(jetty, k, -20, -126.5, BEACH)
	Props.ropeCoil(jetty, k.at(-21.5, BEACH, -122))
	lanternPost(jetty, k, -17.8, -127.4, BEACH, math.pi / 2)
	return dressing
end

-- Big stacked stone blocks facing the cliff behind the square, like an old harbour wall.
local function harbourWall(k)
	local rng = k.rng
	local wall = group(k.parent, "HarbourWall")
	local courses = { { BEACH, 9.4 }, { 9.4, 15.4 }, { 15.4, TERRACE } }
	local far = 64
	for side = -1, 1, 2 do
		-- Each course is laid on its own, so the joints stagger like brickwork.
		for course, span in courses do
			local left = NOTCH - (if course == 2 then rng:NextNumber(0, 2.5) else 0)
			while left < far - 0.2 do
				local right = math.min(left + rng:NextNumber(4.5, 7.5), far)
				local height = span[2] - span[1]
				part(wall, "WallStone", Vector3.new(right - math.max(left, NOTCH) - 0.2, height - 0.2, 4.6 + rng:NextNumber(-0.3, 0.4)), k.cf(side * (math.max(left, NOTCH) + right) / 2, span[1] + height / 2, FRONT - 2.3 + rng:NextNumber(-0.2, 0.2)), shade(STONE, rng, 0.09), M.Slate)
				left = right
			end
		end
		-- Cap stones finish the top of the wall flush with the terrace.
		for capX = NOTCH + 0.5, far - 4, 4 do
			part(wall, "CapStone", Vector3.new(3.9, 0.7, 5.2), k.cf(side * (capX + 2), TERRACE + 0.15, FRONT - 2.1), shade(rgb(158, 154, 142), rng, 0.05), M.Slate)
		end
		-- Moss trailing over the lip.
		for index = 1, 8 do
			local vx = side * rng:NextNumber(NOTCH + 3, far - 3)
			local length = rng:NextNumber(3, 9)
			part(wall, "Vine", Vector3.new(rng:NextNumber(0.8, 2), length, 0.25), k.cf(vx, TERRACE - length / 2, FRONT - 4.75), shade(rgb(74, 104, 60), rng, 0.1), M.LeafyGrass, false)
			if index % 3 == 0 then
				Props.bush(wall, k.at(vx, TERRACE, FRONT + 3), rng, LEAVES)
			end
		end
	end
	return wall
end

local function stairs(k)
	local rng = k.rng
	local steps = group(k.parent, "TerraceStairs")
	-- A wide stone stair climbs exactly twenty studs through the cut, without a jump.
	for step = 1, 32 do
		local height = step * 0.625
		part(steps, "StairTread", Vector3.new(15, height, STAIR_RUN + 0.05), k.cf(0, BEACH + height / 2, STAIR_START + (step - 0.5) * STAIR_RUN), shade(rgb(156, 154, 137), rng, 0.04), M.Cobblestone)
		-- A worn darker nosing on every step.
		part(steps, "StairNosing", Vector3.new(15, 0.12, 0.35), k.cf(0, BEACH + height + 0.06, STAIR_START + (step - 1) * STAIR_RUN + 0.2), shade(rgb(120, 118, 106), rng, 0.04), M.Slate, false)
	end
	for _, x in { -1, 1 } do
		-- Lantern newels at the foot and head, and lamps set into the walls of the cut.
		for _, spot in { { 8.6, STAIR_START - 1.6, BEACH }, { NOTCH + 1.4, NOTCH_BACK + 1.6, TERRACE } } do
			part(steps, "Newel", Vector3.new(2.2, 4, 2.2), k.cf(x * spot[1], spot[3] + 2, spot[2]), shade(STONE, rng, 0.04), M.Slate)
			Props.lantern(steps, k.cf(x * spot[1], spot[3] + 4.9, spot[2]), 18, 1.1)
		end
		for _, z in { -18, -6 } do
			Props.lantern(steps, k.cf(x * 8.2, stairHeight(z) + 5, z), 16, 0.9)
		end
	end
	return steps
end

-- Low irregular stepping stones, laid along a polyline.
local function path(parent: Instance, k, points: { Vector2 }, y: number, width: number, color: Color3)
	local rng = k.rng
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		local length = (b - a).Magnitude
		for step = 0, math.floor(length / 2.6) do
			local p = a:Lerp(b, step * 2.6 / length)
			local side = Vector2.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * width * 0.25
			local stone = Props.cylinder(parent, k.at(p.X + side.X, y + 0.06, p.Y + side.Y), 0.12, rng:NextNumber(width * 0.5, width * 0.8), shade(color, rng, 0.08), M.Pebble)
			stone.Name, stone.CanCollide, stone.CanQuery = "PathStone", false, false
		end
	end
end

local function buildVillage(island: Model, frame: CFrame, id: number, pause: () -> ()): Model
	local dressing = Instance.new("Model")
	dressing.Name = "Dressing"
	dressing:SetAttribute("Kind", "Village")
	local rng = Random.new(6100 + id)
	local k = kit(frame, dressing, rng)
	local accent = ACCENTS[(id - 1) % #ACCENTS + 1]
	shoreRocks(k, clearOfLanding)
	cliffRocks(k, function(x, z) return clearOfLanding(x, z) or z < FRONT - 1 and math.abs(x) < 70 end)
	harbourWall(k)
	stairs(k)
	pause()

	-- Quay, piers and the boat terminal.
	local docks = group(dressing, "Docks")
	planks(docks, k, -52.5, -94, 52.5, -70, BEACH, true, "QuayPlank")
	part(docks, "QuayFascia", Vector3.new(106, 1.4, 0.8), k.cf(0, BEACH - 0.9, -94.3), TRIM, M.Wood)
	for x = -49, 49, 7 do
		pile(docks, k, x, -94.6, BEACH - 0.5)
		if x % 14 == 0 then
			local fender = Props.cylinder(docks, k.at(x + 3.5, BEACH - 1.6, -95.2), 1.1, 1.6, rgb(28, 28, 30), M.Rubber)
			fender.Name = "Fender"
		end
	end
	for _, x in { -47, -12, 12, 47 } do
		bollard(docks, k, x, -92.6, BEACH)
	end
	for _, x in { -30, 30 } do
		local pier = group(docks, if x < 0 then "LeftPier" else "RightPier")
		for z = -158, -98, 4 do
			part(pier, "PierPlank", Vector3.new(12, 0.6, 3.9), k.cf(x, 4.1, z), shade(WOOD, rng, 0.1), M.WoodPlanks)
		end
		part(pier, "PierHead", Vector3.new(21, 0.6, 10), k.cf(x, 4.1, -165), shade(WOOD, rng, 0.06), M.WoodPlanks)
		for z = -160, -88, 18 do
			for _, side in { -6, 6 } do
				part(pier, "PierPile", Vector3.new(0.9, 17, 0.9), k.cf(x + side, -1.5, z), TRIM, M.Wood)
			end
		end
		-- Rope rail along the outer edge, lanterns on every other post.
		local outer = if x < 0 then -6.4 else 6.4
		local previous
		for index, z in { -98, -110, -122, -134, -146, -158 } do
			part(pier, "RailPost", Vector3.new(0.6, 3.4, 0.6), k.cf(x + outer, BEACH + 1.7, z), TRIM, M.Wood)
			local top = k.at(x + outer, BEACH + 3, z)
			if previous then
				local sag = (previous + top) / 2 - Vector3.new(0, 0.6, 0)
				for _, ends in { { previous, sag }, { sag, top } } do
					local rope = part(pier, "RailRope", Vector3.new(0.2, 0.2, (ends[2] - ends[1]).Magnitude), CFrame.lookAt((ends[1] + ends[2]) / 2, ends[2]), rgb(176, 150, 106), M.Fabric, false)
					rope.CanQuery = false
				end
			end
			previous = top
			if index % 2 == 1 then
				Props.lantern(pier, k.cf(x + outer, BEACH + 4.1, z), 16, 0.9)
			end
		end
		Props.ladder(pier, k.cf(x + (if x < 0 then 4 else -4), BEACH, -170.2), -2)
		Props.lifeRing(pier, k.cf(x + outer * 1.06, BEACH + 2, -116, (if x < 0 then -1 else 1) * math.pi / 2))
		for _, hx in { -8, 8 } do
			bollard(pier, k, x + hx, -168.5, BEACH)
		end
		Props.crabPot(pier, k.at(x - 6, BEACH, -162), rng)
		Props.ropeCoil(pier, k.at(x + 6.5, BEACH, -161.5))
		Props.barrel(pier, k.at(x + (if x < 0 then -4 else 4), BEACH, -100.5), rng)
	end
	local terminal = sign(docks, k.cf(20, 7.2, -85), "BoatDockControl", "YOUR BOATS", 10)
	for _, tx in { -4.2, 4.2 } do
		part(docks, "TerminalPost", Vector3.new(0.5, 4.6, 0.5), k.cf(20 + tx, BEACH + 2.3, -85), TRIM, M.Wood)
	end
	prompt(terminal, "SpawnRowboatPrompt", "Choose boat", "Company dock", true)
	for _, spot in { { -40, -76 }, { 40, -76 }, { -49, -88 }, { 49, -73 } } do
		Props.crates(docks, k.at(spot[1], BEACH, spot[2]), rng)
	end
	for _, spot in { { -44, -73 }, { 36, -90 }, { 46, -89 }, { -6, -91 } } do
		Props.barrel(docks, k.at(spot[1], BEACH, spot[2]), rng)
	end
	for _, spot in { { -35, -90 }, { 25, -92 } } do
		Props.crabPot(docks, k.at(spot[1], BEACH, spot[2]), rng)
	end
	Props.ropeCoil(docks, k.at(8, BEACH, -91.5))
	Props.fishRack(docks, k.at(-12, BEACH, -73), k.yaw(0), rng)
	Props.stall(docks, k.at(-38, BEACH, -86), k.yaw(math.pi), rng, accent)
	for _, x in { -52, 52 } do
		Props.lampPost(docks, k.at(x * 0.95, BEACH, -71))
	end
	local buoys = group(dressing, "Buoys")
	for _, spot in { { -48, -150 }, { 48, -150 }, { 0, -178 }, { -70, -118 }, { 70, -118 } } do
		Props.buoy(buoys, k.at(spot[1], 0, spot[2]), rng)
	end
	pause()

	-- The village square on the sand between the quay and the harbour wall.
	local square = group(dressing, "Square")
	-- Straight up from the quay to the foot of the stair.
	path(square, k, { Vector2.new(0, -69), Vector2.new(0, STAIR_START - 3) }, BEACH, 6, PEBBLE)
	path(square, k, { Vector2.new(0, -67), Vector2.new(-6, -69), Vector2.new(-30, -71) }, BEACH, 5.5, PEBBLE)
	path(square, k, { Vector2.new(0, -67), Vector2.new(8, -69), Vector2.new(30, -71) }, BEACH, 5.5, PEBBLE)
	path(square, k, { Vector2.new(-6, -60), Vector2.new(-24, -52), Vector2.new(-46, -46), Vector2.new(-62, -34) }, BEACH, 5, PEBBLE)
	path(square, k, { Vector2.new(6, -60), Vector2.new(26, -50), Vector2.new(48, -42) }, BEACH, 5, PEBBLE)
	for _ = 1, 16 do
		local x, z = rng:NextNumber(-74, 74), rng:NextNumber(-64, -34)
		if math.abs(x) > 20 then
			local patch = Props.cylinder(square, k.at(x, BEACH + 0.04, z), 0.1, rng:NextNumber(6, 12), shade(GRASS, rng, 0.1), M.Grass)
			patch.Name, patch.CanCollide, patch.CanQuery = "GrassPatch", false, false
		end
	end
	Props.well(square, k.at(-44, BEACH, -38))
	Props.signpost(square, k.at(11, BEACH, -63), k.yaw(0), { { "PLOT", math.pi / 2 }, { "DOCKS", 0 }, { "GULLHAVEN", -0.4 } })
	local noticeFrame = k.cf(34, BEACH + 4.2, -36, math.pi)
	sign(square, noticeFrame, "NoticeBoard", "COMPANY NOTICES", 9)
	for _, nx in { -4, 4 } do
		part(square, "NoticePost", Vector3.new(0.5, 6, 0.5), noticeFrame * CFrame.new(nx, -1.2, 0), TRIM, M.Wood)
	end
	for _, spot in { { -32, -46, math.pi }, { 32, -46, math.pi }, { -58, -58, math.pi * 0.85 } } do
		Props.bench(square, k.at(spot[1], BEACH, spot[2]), k.yaw(spot[3]))
	end
	-- A fire pit ringed with stones and log seats.
	local fire = group(square, "FirePit")
	for index = 1, 8 do
		local angle = index / 8 * math.pi * 2
		Props.rock(fire, k.at(52 + math.cos(angle) * 2.8, BEACH, -34 + math.sin(angle) * 2.8), rng, 1.2, STONE)
	end
	local embers = part(fire, "Embers", Vector3.new(2.6, 0.5, 2.6), k.cf(52, BEACH + 0.25, -34), rgb(255, 120, 40), M.Neon, false)
	local glow = Instance.new("PointLight")
	glow.Color, glow.Range, glow.Brightness, glow.Parent = rgb(255, 150, 70), 20, 1.4, embers
	for index = 1, 3 do
		local angle = index / 3 * math.pi * 2 + 0.4
		local seat = k.at(52 + math.cos(angle) * 6, BEACH + 0.7, -34 + math.sin(angle) * 6)
		part(fire, "LogSeat", Vector3.new(4.5, 1.4, 1.4), CFrame.lookAt(seat, k.at(52, BEACH + 0.7, -34)), rgb(104, 76, 52), M.Wood)
	end
	-- Lantern posts round the square, strung with lights.
	local posts = {}
	for _, spot in { { -30, -64 }, { -60, -44 }, { -22, -40 }, { 30, -64 }, { 60, -46 }, { 22, -40 } } do
		lanternPost(square, k, spot[1], spot[2], BEACH, if spot[1] < 0 then -math.pi / 2 else math.pi / 2)
		table.insert(posts, k.at(spot[1], BEACH + 8.8, spot[2]))
	end
	for _, pair in { { 1, 4 }, { 1, 2 }, { 2, 3 }, { 4, 5 }, { 5, 6 }, { 3, 6 } } do
		Props.stringLights(square, posts[pair[1]], posts[pair[2]], rng, 1.6)
	end
	for _, spot in { { -66, -36 }, { 72, -44 }, { -56, -33 }, { -16, -46 }, { 16, -46 }, { 40, -46 } } do
		Props.bush(square, k.at(spot[1], BEACH, spot[2]), rng, LEAVES)
		Props.flowers(square, k.at(spot[1] + 3, BEACH, spot[2] - 2), rng)
	end
	for _, spot in { { -64, -66 }, { 66, -60 }, { 72, -40 } } do
		Props.crates(square, k.at(spot[1], BEACH, spot[2]), rng)
		Props.barrel(square, k.at(spot[1] + 3.5, BEACH, spot[2] + 1), rng)
	end
	Props.fishRack(square, k.at(-68, BEACH, -48), k.yaw(math.pi / 2), rng)
	pause()

	-- The upper terrace: the empty fenced plot, an overlook and trees around it.
	local plotFrame = frame * CFrame.new(0, Layout.PLOT_HEIGHT, Layout.PLOT_Z)
	local plot = group(dressing, "Plot")
	part(plot, "PlotPad", Vector3.new(108.4, 0.3, 63.4), plotFrame * CFrame.new(0, -0.15, 0), DIRT, M.Ground)
	for _, edge in { { 0, -32.1, 109.6, 1 }, { 0, 32.1, 109.6, 1 }, { -54.8, 0, 1, 63.2 }, { 54.8, 0, 1, 63.2 } } do
		part(plot, "PlotCurb", Vector3.new(edge[3], 0.5, edge[4]), plotFrame * CFrame.new(edge[1], -0.1, edge[2]), shade(STONE, rng, 0.04), M.Cobblestone)
	end
	local function fence(x1, z1, x2, z2)
		Props.fence(plot, (plotFrame * CFrame.new(x1, -0.05, z1)).Position, (plotFrame * CFrame.new(x2, -0.05, z2)).Position)
	end
	fence(-55.6, -33, -6, -33)
	fence(6, -33, 55.6, -33)
	fence(-55.6, 33, 55.6, 33)
	fence(-55.6, -33, -55.6, 33)
	fence(55.6, -33, 55.6, 33)
	-- Gate arch with the plot's name over the way in from the stairs.
	for _, gx in { -6, 6 } do
		part(plot, "GatePost", Vector3.new(1, 9, 1), plotFrame * CFrame.new(gx, 4.5, -33), TRIM, M.Wood)
		Props.lantern(plot, plotFrame * CFrame.new(gx, 9.8, -33), 18, 1)
	end
	part(plot, "GateBeam", Vector3.new(13.4, 0.8, 0.8), plotFrame * CFrame.new(0, 8.6, -33), TRIM, M.Wood)
	sign(plot, plotFrame * CFrame.new(0, 7.2, -33.1), "PlotSign", "COMPANY PLOT", 9)
	for _, corner in { { -57.5, -35 }, { 57.5, -35 }, { -57.5, 35 }, { 57.5, 35 } } do
		Props.lampPost(plot, (plotFrame * CFrame.new(corner[1], -0.16, corner[2])).Position)
	end
	path(plot, k, { Vector2.new(0, NOTCH_BACK + 0.5), Vector2.new(0, Layout.PLOT_Z - 34) }, TERRACE, 6, PEBBLE)
	-- Overlook railing along the cliff and round the rim of the stair cut.
	for side = -1, 1, 2 do
		Props.fence(plot, k.at(side * 62, TERRACE, FRONT + 0.6), k.at(side * (NOTCH + 0.7), TERRACE, FRONT + 0.6))
		Props.fence(plot, k.at(side * (NOTCH + 0.7), TERRACE, FRONT + 0.6), k.at(side * (NOTCH + 0.7), TERRACE, NOTCH_BACK - 0.2))
	end
	for _, x in { -34, 34 } do
		Props.bench(plot, k.at(x, TERRACE, FRONT + 4), k.yaw(0))
	end
	Props.flag(plot, k.at(72, TERRACE, -6), accent)
	local around = { { -62, 2, 62, Layout.PLOT_Z + 40 }, { -14, -30, 14, 12 }, { -66, -30, 66, -18 }, { 64, -14, 80, 2 } }
	woodland(k, 22, 30, around)
	pause()

	-- Reeds and driftwood on the open shore beyond the square.
	local shore = group(dressing, "Shore")
	for index = 1, 14 do
		local x, z = rng:NextNumber(-100, 100), rng:NextNumber(-60, 90)
		if insidePolygon(COAST, x * 1.03, z * 1.03) and not (insidePolygon(UPPER, x, z) or insidePolygon(UPPER, x * 0.95, z * 0.95)) and z > -60 then
			if index % 2 == 0 then
				Props.driftwood(shore, k.at(x, BEACH, z), rng)
			else
				Props.shells(shore, k.at(x, BEACH, z), rng)
			end
		end
	end
	return dressing
end

local tokens = setmetatable({}, { __mode = "k" })

local function finish(island: Model, dressing: Model)
	-- Owner prompts built after CompanyIslandService last refreshed still need their owner.
	for _, item in dressing:GetDescendants() do
		if item:IsA("ProximityPrompt") and CollectionService:HasTag(item, "ShopOwnerPrompt") then
			item:SetAttribute("OwnerUserId", island:GetAttribute("OwnerUserId") or 0)
		end
	end
	pack(dressing)
end

-- Swaps the island's scenery to the village while owned and back to wild land.
-- The new dressing is built off-map and cut into streaming pieces before it
-- replaces the old one, so clients receive it piece by piece.
function Islands.dress(island: Model, owned: boolean)
	local kind = if owned then "Village" else "Wild"
	if island:GetAttribute("Dressing") == kind then
		return
	end
	island:SetAttribute("Dressing", kind)
	local token = {}
	tokens[island] = token
	task.spawn(function()
		local frame, id = island:GetAttribute("IslandFrame"), island:GetAttribute("IslandId")
		local resumed = os.clock()
		local function pause()
			if os.clock() - resumed > 0.02 then
				task.wait()
				resumed = os.clock()
			end
		end
		local dressing = if owned then buildVillage(island, frame, id, pause) else buildWild(island, frame, id)
		if tokens[island] ~= token or not island.Parent then
			dressing:Destroy()
			return
		end
		finish(island, dressing)
		Lod.pin(dressing)
		local old = island:FindFirstChild("Dressing")
		if old then
			Lod.release(old)
			old:Destroy()
		end
		dressing.Parent = island
	end)
end

-- The permanent landform both dressings share: the beach, the terrace and its two
-- knolls clad in stacked rock, the cut the stair climbs through and the sea stacks.
-- The straight cliff front is left to the dressing (bare rock or a harbour wall).
local function buildGround(ground: Model, frame: CFrame, id: number)
	local rng = Random.new(4100 + id)
	local k = kit(frame, ground, rng)
	plateau(ground, frame, COAST, BEACH, -20, 7, SAND, M.Sand)
	plateau(ground, frame, UPPER, TERRACE, BEACH, 1, GRASS, M.Grass)
	local edges = normals(UPPER)
	for index, a in UPPER do
		local b = UPPER[index % #UPPER + 1]
		if notchEdge(a, b) then
			cliffFace(ground, k, a, b, edges[index], TERRACE, BEACH, 0.8)
		elseif not frontEdge(a, b) and a.Y ~= NOTCH_BACK then
			cliffFace(ground, k, a, b, edges[index], TERRACE, -3, 2.5)
		end
	end
	for _, ridge in RIDGES do
		plateau(ground, frame, ridge.outline, ridge.top, TERRACE, 1, GRASS, M.Grass)
		local ridgeEdges = normals(ridge.outline)
		for index, a in ridge.outline do
			cliffFace(ground, k, a, ridge.outline[index % #ridge.outline + 1], ridgeEdges[index], ridge.top, TERRACE - 1, 1.8)
		end
	end
	-- Rock cheeks either side of the stair's foot step down with it, so the stair
	-- reads as cut through a spur of the cliff rather than stuck on its front.
	for side = -1, 1, 2 do
		local z = STAIR_START - 2
		while z < FRONT do
			local z2 = math.min(z + rng:NextNumber(3.5, 5.5), FRONT + 1)
			local top = stairHeight(z2) + rng:NextNumber(2.5, 4)
			local width = rng:NextNumber(7, 10)
			part(ground, "StairCheek", Vector3.new(width, top + 3, z2 - z + 0.6), k.cf(side * (8.6 + width / 2), (top - 3) / 2, (z + z2) / 2, rng:NextNumber(-0.05, 0.05)), shade(ROCK, rng, 0.1), M.Slate)
			z = z2
		end
	end
	for _, spot in STACKS do
		local y, radius = -6, rng:NextNumber(7, 10)
		for _ = 1, rng:NextInteger(3, 4) do
			local h = rng:NextNumber(5, 8)
			local tilt = CFrame.Angles(rng:NextNumber(-0.06, 0.06), 0, rng:NextNumber(-0.06, 0.06))
			part(ground, "SeaStack", Vector3.new(radius * rng:NextNumber(1.7, 2.2), h + 0.6, radius * rng:NextNumber(1.7, 2.2)), k.cf(spot.X + rng:NextNumber(-1, 1), y + h / 2, spot.Y + rng:NextNumber(-1, 1), rng:NextNumber(0, math.pi)) * tilt, shade(ROCK, rng, 0.1), M.Slate)
			y += h
			radius *= rng:NextNumber(0.72, 0.88)
		end
		part(ground, "StackMoss", Vector3.new(radius * 1.8, 0.4, radius * 1.8), k.cf(spot.X, y + 0.4, spot.Y, rng:NextNumber(0, math.pi)), shade(GRASS, rng, 0.1), M.Grass, false)
		Props.bush(ground, k.at(spot.X, y + 0.5, spot.Y), rng, LEAVES)
	end
end

local function build(root: Instance, id: number)
	local island = Instance.new("Model")
	island.Name = "Company Island " .. id
	island:SetAttribute("CompanyIslandVersion", Islands.VERSION)
	island:SetAttribute("IslandId", id)
	island:SetAttribute("ChartLabel", Layout.Names[id])
	island:SetAttribute("OwnerUserId", 0)
	island:SetAttribute("LodRoot", true)
	island:SetAttribute("LodRadial", true)
	island:SetAttribute("Radius", 128)
	local frame = Layout.frame(id)
	island:SetAttribute("IslandFrame", frame)
	island:SetAttribute("PlotFrame", Layout.plotFrame(id))
	island:SetAttribute("BoatDockFrame", frame * CFrame.new(0, 0, -92))
	local ground = group(island, "Ground")
	buildGround(ground, frame, id)
	local chart = {}
	for _, point in COAST do
		local world = frame * Vector3.new(point.X, 0, point.Y)
		table.insert(chart, { world.X, world.Z })
	end
	island:SetAttribute("ChartCoast", HttpService:JSONEncode(chart))
	-- The sale board stands on the beach in front of either dressing.
	local board = sign(island, frame * CFrame.new(-20, 8.3, -85), "PropertyBoard", Layout.Names[id] .. " / $50,000", 23)
	prompt(board, "BuyCompanyIslandPrompt", "View island", Layout.Names[id], false)
	local stand = group(island, "PropertySign")
	for _, x in { -10.5, 10.5 } do
		part(stand, "SignPost", Vector3.new(0.6, 5.2, 0.6), frame * CFrame.new(-20 + x, BEACH + 2.6, -85.4), TRIM, M.Wood)
	end
	-- The inner berth stays within jumping distance of the right-hand pier.
	local marker = part(island, "BoatSpawn", Vector3.one, frame * CFrame.new(14, 0, -144), TRIM, M.Wood, false)
	marker.Transparency = 1
	island:SetAttribute("PorterPickup", (frame * CFrame.new(30, BEACH, -116)).Position)
	-- Placed company furniture; one streaming piece, so later additions arrive with it.
	group(island, "PlotFurniture")
	local wild = buildWild(island, frame, id)
	finish(island, wild)
	wild.Parent = island
	island:SetAttribute("Dressing", "Wild")
	CollectionService:AddTag(island, Layout.TAG)
	island.Parent = root
	return island
end

function Islands.reserve(placed)
	for id = 1, Layout.COUNT do
		table.insert(placed, { position = Layout.position(id), radius = Layout.FOOTPRINT })
	end
end

function Islands.ensure(root: Instance)
	local current = true
	for id = 1, Layout.COUNT do
		local island = root:FindFirstChild("Company Island " .. id)
		if not island or island:GetAttribute("CompanyIslandVersion") ~= Islands.VERSION then current = false; break end
	end
	if current then return end
	-- Retrofitting a Studio-baked map removes only unowned procedural scenery
	-- inside the new property reservations; player bases and inventories survive.
	local resumed = os.clock()
	for _, model in root:GetDescendants() do
		if os.clock() - resumed > 0.05 then task.wait(); resumed = os.clock() end
		if model:IsA("Model") and model.Name == "Island" then
			local ground = model:FindFirstChild("Ground")
			if ground and ground:IsA("Model") then
				local bounds, size = ground:GetBoundingBox()
				local center = Vector2.new(bounds.X, bounds.Z)
				for id = 1, Layout.COUNT do
					if (center - Layout.position(id)).Magnitude < Layout.FOOTPRINT + math.max(size.X, size.Z) / 2 then
						model:Destroy()
						break
					end
				end
			end
		end
	end
	for id = 1, Layout.COUNT do
		local existing = root:FindFirstChild("Company Island " .. id)
		if existing and existing:GetAttribute("CompanyIslandVersion") ~= Islands.VERSION then
			existing:Destroy()
			existing = nil
		end
		if not existing then
			build(root, id)
			task.wait()
		end
	end
	-- Repositioned properties and removed scenery invalidate the baked shells.
	-- Startup's deferred LOD pass rebuilds them after the harbour opens.
	local shells = root:FindFirstChild("Lod")
	if shells then shells:Destroy() end
end

-- The company desk: a writing desk with a chair behind it (-Z) and the owner's
-- side at +Z. `frame` is the centre of its base on the plot; desk and chair
-- fill two grid cells (8.2 x 4.1, FurnitureCatalog).
function Islands.buildDesk(parent: Instance, frame: CFrame): Model
	local desk = group(parent, "CompanyDesk")
	local function block(name, size, x, y, z, color, material)
		return part(desk, name, size, frame * CFrame.new(x, y, z), color, material)
	end
	local deskZ = 0.8
	block("DeskTop", Vector3.new(8, 0.35, 2.4), 0, 3, deskZ, WOOD, M.WoodPlanks)
	block("DeskEdge", Vector3.new(8.04, 0.08, 2.44), 0, 2.8, deskZ, TRIM, M.WoodPlanks)
	for _, x in { -3.2, 3.2 } do
		block("DeskPedestal", Vector3.new(1.4, 2.8, 2.2), x, 1.4, deskZ, TRIM, M.WoodPlanks)
		-- Drawers face the chair side.
		for index = 0, 2 do
			block("DeskDrawer", Vector3.new(1.2, 0.75, 0.05), x, 0.55 + index * 0.85, deskZ - 1.12, WOOD, M.WoodPlanks)
			block("DrawerPull", Vector3.new(0.4, 0.07, 0.07), x, 0.75 + index * 0.85, deskZ - 1.17, rgb(186, 150, 84), M.Metal)
		end
	end
	block("ModestyPanel", Vector3.new(5, 2, 0.2), 0, 1.9, deskZ + 1, TRIM, M.WoodPlanks)
	block("DeskMat", Vector3.new(2.4, 0.04, 1.4), 0, 3.19, deskZ - 0.3, rgb(36, 66, 58), M.Fabric)
	block("Ledger", Vector3.new(1.4, 0.22, 1), -0.1, 3.32, deskZ - 0.3, rgb(120, 46, 40), M.Fabric)
	block("Papers", Vector3.new(1.2, 0.05, 1.6), -2.1, 3.2, deskZ, rgb(240, 234, 220), M.SmoothPlastic)
	block("Inkwell", Vector3.new(0.25, 0.25, 0.25), 1.4, 3.3, deskZ + 0.6, rgb(30, 34, 60), M.Glass)
	block("Quill", Vector3.new(0.05, 0.7, 0.05), 1.45, 3.6, deskZ + 0.6, rgb(240, 236, 226), M.Fabric)
	block("LampBase", Vector3.new(0.5, 0.5, 0.5), 3.3, 3.42, deskZ + 0.6, rgb(60, 62, 64), M.Metal)
	block("LampArm", Vector3.new(0.08, 0.7, 0.08), 3.3, 3.95, deskZ + 0.6, rgb(60, 62, 64), M.Metal)
	local lampShade = block("LampShade", Vector3.new(0.9, 0.45, 0.9), 3.3, 4.45, deskZ + 0.5, rgb(250, 222, 160), M.Neon)
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Parent = rgb(255, 223, 172), 12, 1, lampShade
	-- The owner's chair, tucked up to the desk.
	block("ChairSeat", Vector3.new(1.9, 0.35, 1.7), 0, 1.9, -1.0, ROOF, M.Fabric)
	block("ChairBack", Vector3.new(1.9, 2.2, 0.3), 0, 3.1, -1.85, ROOF, M.Fabric)
	block("ChairStem", Vector3.new(0.35, 1.6, 0.35), 0, 0.9, -1.0, rgb(60, 62, 64), M.Metal)
	block("ChairBase", Vector3.new(1.5, 0.12, 1.5), 0, 0.1, -1.0, rgb(60, 62, 64), M.Metal)
	return desk
end

return Islands
