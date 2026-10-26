-- Small, independently streamed underwater gardens. Sample the finished ground so
-- plants follow island slopes and shelves as well as the deep ocean floor.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Biomes = require(ReplicatedStorage.Shared.Biomes)
local LowPoly = require(script.Parent.LowPoly)
local Props = require(script.Parent.Props)
local SeabedLife = require(script.Parent.SeabedLife)

local SeabedDetails = {}
local VERSION = 2
local TAU = math.pi * 2
local M = Enum.Material
local rgb = Color3.fromRGB

type Style = {
	count: number,
	shoreCount: number,
	stone: Color3,
	weed: Color3,
	sand: Color3?,
	coral: { Color3 }?,
	vegetation: number,
}

local STYLES: { [string]: Style } = {
	normal = {
		count = 240,
		shoreCount = 220,
		stone = rgb(158, 151, 130),
		weed = rgb(67, 103, 61),
		sand = rgb(218, 202, 162),
		coral = { rgb(192, 67, 61), rgb(215, 116, 76), rgb(178, 99, 134), rgb(221, 179, 98) },
		vegetation = 1,
	},
	swamp = { count = 75, shoreCount = 60, stone = rgb(91, 89, 67), weed = rgb(77, 91, 40), vegetation = 1 },
	tropical = {
		count = 160,
		shoreCount = 120,
		stone = rgb(180, 172, 139),
		weed = rgb(54, 128, 92),
		sand = rgb(233, 220, 181),
		coral = { rgb(232, 113, 101), rgb(234, 173, 89), rgb(160, 114, 186), rgb(85, 174, 158) },
		vegetation = 0.8,
	},
	volcanic = { count = 60, shoreCount = 40, stone = rgb(61, 58, 55), weed = rgb(72, 79, 54), vegetation = 0.15 },
	ice = { count = 60, shoreCount = 40, stone = rgb(110, 133, 141), weed = rgb(65, 94, 81), vegetation = 0.35 },
	open = { count = 180, shoreCount = 0, stone = rgb(93, 105, 108), weed = rgb(69, 96, 66), vegetation = 0.55 },
}

local function model(name: string, parent: Instance): Model
	local result = Instance.new("Model")
	result.Name = name
	result.Parent = parent
	return result
end

local function sample(params: RaycastParams, x: number, z: number): RaycastResult?
	-- Start above the tallest island: a ray from below sea level can put plants
	-- inside the land above it. Only ground and Terrain participate in these rays.
	local hit = workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -720, 0), params)
	if hit and hit.Position.Y < Biomes.WaterLevel - 8 and hit.Normal.Y > 0.78 then
		return hit
	end
	return nil
end

-- Low sand drifts with a buried rim. Skip uneven ground rather than bridging it.
local function sandDrift(parent: Model, ground: Vector3, rng: Random, color: Color3, params: RaycastParams)
	local ring = {}
	local radius, spin = rng:NextNumber(9, 19), rng:NextNumber(0, TAU)
	for i = 1, 7 do
		local angle = spin + i / 7 * TAU
		local hit = sample(params, ground.X + math.cos(angle) * radius, ground.Z + math.sin(angle) * radius * 0.7)
		if not hit or math.abs(hit.Position.Y - ground.Y) > 0.5 then
			return
		end
		ring[i] = hit.Position - Vector3.new(0, 0.12, 0)
	end
	local drift = model("SandDrift", parent)
	local top = ground + Vector3.new(0, rng:NextNumber(0.3, 0.65), 0)
	for i, point in ring do
		LowPoly.triangle(point, ring[i % #ring + 1], top, ground - Vector3.yAxis * 2, color, drift, M.Sand, 0.18)
	end
end

local function stones(parent: Model, ground: Vector3, rng: Random, color: Color3)
	local cluster = model("SeabedStones", parent)
	local radius = rng:NextNumber(1.3, 3.8)
	-- Only the exposed crown needs geometry; bury the open base in the bed.
	local ring = {}
	local spin = rng:NextNumber(0, TAU)
	for side = 1, 5 do
		local angle = spin + side / 5 * TAU
		local reach = radius * rng:NextNumber(0.8, 1.1)
		ring[side] = ground + Vector3.new(math.cos(angle) * reach, -radius * 0.8, math.sin(angle) * reach)
	end
	LowPoly.pyramid(ring, ground + Vector3.yAxis * radius * 0.8, Props.shade(color, rng, 0.1), cluster, M.Rock)
	return radius
end

local function pebbles(parent: Model, ground: Vector3, rng: Random, color: Color3)
	local cluster = model("SeabedPebbles", parent)
	for _ = 1, 3 do
		local size = rng:NextNumber(0.5, 1.3)
		local center = ground + Vector3.new(rng:NextNumber(-0.8, 0.8), size * 0.15, rng:NextNumber(-0.8, 0.8))
		local pebble = Props.ball(cluster, center, size, Props.shade(color, rng, 0.12), M.Rock)
		pebble.Size = Vector3.new(size * 1.4, size * 0.65, size)
		pebble.CFrame *= CFrame.Angles(0, rng:NextNumber(0, TAU), 0)
	end
end

-- Curving ribbons rooted in the bottom, distinct from the washed-up beach weed.
local function seaweed(parent: Model, ground: Vector3, rng: Random, color: Color3)
	local weed = model("UnderwaterSeaweed", parent)
	for _ = 1, rng:NextInteger(3, 5) do
		local angle = rng:NextNumber(0, TAU)
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local base = ground + direction * rng:NextNumber(0, 1.3) - Vector3.yAxis * 0.35
		local height = rng:NextNumber(2.5, 6.2)
		local tint = Props.shade(color, rng, 0.18)
		local bend = rng:NextNumber(0.5, 1.5)
		local previous = base
		for step = 1, 2 do
			local t = step / 2
			local tip = base + Vector3.yAxis * height * t + direction * bend * t * t
			Props.beam(weed, previous, tip, 0.45 * (1 - t * 0.6), tint, 0.12, M.Grass)
			previous = tip
		end
	end
end

-- Mediterranean red/orange branching coral, with occasional rounded sponges.
local function coral(parent: Model, ground: Vector3, rng: Random, colors: { Color3 })
	local reef = model("BranchingCoral", parent)
	local color = Props.pick(rng, colors)
	local base = ground - Vector3.yAxis * 0.2
	local height = rng:NextNumber(1.7, 3.5)
	local fork = base + Vector3.new(0.1, height * 0.55, 0)
	Props.beam(reef, base, fork, 0.38, color, nil, M.Pebble)
	local spin = rng:NextNumber(0, TAU)
	for branch = 1, 4 do
		local angle = spin + branch / 4 * TAU
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local elbow = fork + direction * height * 0.38 + Vector3.yAxis * height * 0.15
		local tip = elbow + direction * 0.25 + Vector3.yAxis * height * rng:NextNumber(0.25, 0.5)
		Props.beam(reef, fork, elbow, 0.25, color, nil, M.Pebble)
		Props.beam(reef, elbow, tip, 0.17, color, nil, M.Pebble)
	end
	if rng:NextNumber() < 0.35 then
		Props.ball(reef, ground + Vector3.new(0.8, 0.35, 0.2), 1.1, Props.pick(rng, colors), M.Pebble)
	end
end

local function garden(parent: Instance, hit: RaycastResult, style: Style, rng: Random, params: RaycastParams)
	local patch = model("SeabedGarden", parent)
	local ground = hit.Position
	if style.sand and hit.Normal.Y > 0.98 and rng:NextNumber() < 0.45 then
		sandDrift(patch, ground, rng, Props.shade(style.sand, rng, 0.035), params)
	end
	local radius = stones(patch, ground, rng, style.stone)
	for _ = 1, rng:NextInteger(3, 5) do
		local angle, distance = rng:NextNumber(0, TAU), rng:NextNumber(radius + 1.5, 13)
		local point = sample(params, ground.X + math.cos(angle) * distance, ground.Z + math.sin(angle) * distance)
		if point and math.abs(point.Position.Y - ground.Y) < 4 then
			if style.coral and rng:NextNumber() < 0.42 then
				local kind = rng:NextNumber()
				if kind < 0.35 then
					SeabedLife.fan(patch, point.Position, rng, style.coral)
				elseif kind < 0.6 then
					SeabedLife.sponges(patch, point.Position, rng, style.coral)
				else
					coral(patch, point.Position, rng, style.coral)
				end
			elseif rng:NextNumber() < style.vegetation then
				local kind = rng:NextNumber()
				if kind < 0.3 then
					SeabedLife.kelp(patch, point.Position, rng, style.weed, Biomes.WaterLevel)
				elseif kind < 0.7 then
					SeabedLife.grass(patch, point.Position, rng, style.weed)
				else
					seaweed(patch, point.Position, rng, style.weed)
				end
			else
				pebbles(patch, point.Position, rng, style.stone)
			end
		end
	end
	-- Small finds sit between the vegetation rather than on top of the rocks.
	if rng:NextNumber() < 0.7 then
		local angle = rng:NextNumber(0, TAU)
		local point =
			sample(params, ground.X + math.cos(angle) * (radius + 2), ground.Z + math.sin(angle) * (radius + 2))
		if point and math.abs(point.Position.Y - ground.Y) < 3 then
			if rng:NextNumber() < 0.4 then
				SeabedLife.starfish(patch, point.Position, point.Normal, rng)
			else
				SeabedLife.shells(patch, point.Position, point.Normal, rng)
			end
		end
	end
	for _, part in patch:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.CastShadow = false
		end
	end
	patch.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
end

-- Dress swimming coves and island aprons more densely than the deep sea.
-- Sample actual mesh bounds so the gardens follow saved or regenerated coasts.
local function shoreGardens(
	parent: Instance,
	biome: Biomes.Biome,
	style: Style,
	surfaces: { Instance },
	params: RaycastParams,
	seed: number
)
	local rng = Random.new(seed)
	local candidates: { RaycastResult } = {}
	local harbourCandidates: { RaycastResult } = {}
	for _, ground in surfaces do
		if not ground:IsA("Model") or ground.Name ~= "Ground" then
			continue
		end
		local frame, size = ground:GetBoundingBox()
		if Biomes.at(frame.Position) ~= biome then
			continue
		end
		for x = frame.Position.X - size.X / 2 - 24, frame.Position.X + size.X / 2 + 24, 36 do
			for z = frame.Position.Z - size.Z / 2 - 24, frame.Position.Z + size.Z / 2 + 24, 36 do
				local hit = sample(params, x + rng:NextNumber(-3, 3), z + rng:NextNumber(-3, 3))
				if hit and hit.Position.Y > Biomes.WaterLevel - 44 and Biomes.at(hit.Position) == biome then
					local isHarbour = ground.Parent and ground.Parent.Name == "Harbour Isle"
					table.insert(if isHarbour then harbourCandidates else candidates, hit)
				end
			end
			task.wait()
		end
	end
	for _, list in { candidates, harbourCandidates } do
		for i = #list, 2, -1 do
			local j = rng:NextInteger(1, i)
			list[i], list[j] = list[j], list[i]
		end
	end
	-- Reserve the first gardens for the main swimming coves, then the archipelago.
	local ordered: { RaycastResult } = {}
	for index = 1, math.min(#harbourCandidates, 140) do
		table.insert(ordered, harbourCandidates[index])
	end
	for _, hit in candidates do
		table.insert(ordered, hit)
	end
	for index = 141, #harbourCandidates do
		table.insert(ordered, harbourCandidates[index])
	end
	local placed: { Vector2 } = {}
	for _, hit in ordered do
		if #placed >= style.shoreCount then
			break
		end
		local position = Vector2.new(hit.Position.X, hit.Position.Z)
		local clear = true
		for _, other in placed do
			if (other - position).Magnitude < 30 then
				clear = false
				break
			end
		end
		if not clear then
			continue
		end
		garden(parent, hit, style, rng, params)
		table.insert(placed, position)
		local index = #placed
		if index % 15 == 0 then
			task.wait()
		end
	end
	return placed
end

local function scatter(
	parent: Instance,
	biome: Biomes.Biome,
	style: Style,
	params: RaycastParams,
	seed: number,
	occupied: { Vector2 }?
)
	local rng = Random.new(seed)
	local placed: { Vector2 } = {}
	local blocked = occupied or {}
	for attempt = 1, style.count * 5 do
		if #placed >= style.count then
			break
		end
		local angle = rng:NextNumber(0, TAU)
		local position: Vector2
		if biome == Biomes.OpenSea then
			local half = Biomes.MapHalfSize - 40
			position = Vector2.new(rng:NextNumber(-half, half), rng:NextNumber(-half, half))
		else
			position = biome.center
				+ Vector2.new(math.cos(angle), math.sin(angle)) * (biome.radius - 35) * math.sqrt(rng:NextNumber())
		end
		local world = Vector3.new(position.X, 0, position.Y)
		if Biomes.at(world) ~= biome then
			continue
		end
		local clear = true
		for _, other in blocked do
			if (other - position).Magnitude < 36 then
				clear = false
				break
			end
		end
		if clear then
			local hit = sample(params, position.X, position.Y)
			if hit then
				garden(parent, hit, style, rng, params)
				table.insert(placed, position)
				table.insert(blocked, position)
			end
		end
		if attempt % 20 == 0 then
			task.wait()
		end
	end
end

function SeabedDetails.ensure(root: Instance)
	local old = root:FindFirstChild("SeabedDetails")
	if old and old:GetAttribute("Version") == VERSION then
		return
	end
	if old then
		old:Destroy()
	end

	-- Replace only the existing floor layer beneath the Mediterranean region.
	-- The top stays at SeaFloor, preserving ocean depth and all island geometry.
	local home = Biomes.Normal
	workspace.Terrain:SetMaterialColor(M.Sand, home.seabedColor)
	workspace.Terrain:FillCylinder(
		CFrame.new(home.center.X, Biomes.SeaFloor - 4, home.center.Y),
		8,
		home.radius,
		M.Sand
	)

	local details = Instance.new("Folder")
	details.Name = "SeabedDetails"
	details.Parent = root
	local surfaces: { Instance } = { workspace.Terrain }
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("Model") and (descendant.Name == "Ground" or descendant.Name == "SeabedSlope") then
			table.insert(surfaces, descendant)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = surfaces
	params.IgnoreWater = true

	for index, biome in Biomes.list do
		local folder = Instance.new("Folder")
		folder.Name = biome.name
		folder.Parent = details
		local occupied = shoreGardens(folder, biome, STYLES[biome.id], surfaces, params, Biomes.Seed + 700 + index)
		scatter(folder, biome, STYLES[biome.id], params, Biomes.Seed + 600 + index, occupied)
	end
	local open = Instance.new("Folder")
	open.Name = Biomes.OpenSea.name
	open.Parent = details
	scatter(open, Biomes.OpenSea, STYLES.open, params, Biomes.Seed + 606)
	details:SetAttribute("Version", VERSION)
end

return SeabedDetails
