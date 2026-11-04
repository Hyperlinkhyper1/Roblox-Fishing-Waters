-- Small, independently streamed underwater gardens. Sample the finished ground so
-- plants follow island slopes and shelves as well as the deep ocean floor.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Biomes = require(ReplicatedStorage.Shared.Biomes)
local Harbour = require(script.Parent.Harbour)
local LowPoly = require(script.Parent.LowPoly)
local Props = require(script.Parent.Props)
local Seabed = require(script.Parent.Seabed)
local SeabedLife = require(script.Parent.SeabedLife)

local SeabedDetails = {}
local VERSION = 5
local TAU = math.pi * 2
-- Reuse small patches across the whole ocean, with a closer weave in the lake.
-- Keep each copy independently streamed rather than cloning whole reef gardens.
local CELL = 48
local LAKE_CELL = 24
local PATCH_TEMPLATES = 24
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
	open = {
		count = 480,
		shoreCount = 0,
		stone = rgb(132, 137, 125),
		weed = rgb(69, 96, 66),
		sand = rgb(206, 190, 148),
		coral = { rgb(168, 97, 84), rgb(185, 143, 100), rgb(144, 119, 153) },
		vegetation = 0.7,
	},
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
	if
		hit
		and hit.Position.Y < Biomes.WaterLevel - 8
		and hit.Normal.Y > 0.78
		and Biomes.inOceanBounds(hit.Position)
	then
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

-- Decoration is scenery only: nothing collides with it, and it streams whole.
local function settle(patch: Model)
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
	settle(patch)
end

-- One cheap piece of floor life. Kelp is left out: its height depends on the depth.
local function tuft(parent: Model, ground: Vector3, style: Style, rng: Random)
	local kind = rng:NextNumber()
	if style.coral and kind < 0.3 then
		local pick = rng:NextNumber()
		if pick < 0.35 then
			SeabedLife.fan(parent, ground, rng, style.coral)
		elseif pick < 0.6 then
			SeabedLife.sponges(parent, ground, rng, style.coral)
		else
			coral(parent, ground, rng, style.coral)
		end
	elseif kind < 0.3 + 0.45 * style.vegetation then
		if rng:NextNumber() < 0.6 then
			SeabedLife.grass(parent, ground, rng, style.weed)
		else
			seaweed(parent, ground, rng, style.weed)
		end
	elseif kind < 0.88 then
		pebbles(parent, ground, rng, style.stone)
	elseif kind < 0.95 then
		SeabedLife.shells(parent, ground, Vector3.yAxis, rng)
	else
		SeabedLife.starfish(parent, ground, Vector3.yAxis, rng)
	end
end

-- Built flat around the origin, so a copy can be turned and tilted onto any ground.
local function patchTemplate(style: Style, rng: Random): Model
	local patch = Instance.new("Model")
	patch.Name = "SeabedPatch"
	for index = 1, 2 do
		local angle = rng:NextNumber(0, TAU)
		local distance = if index == 1 then 0 else rng:NextNumber(5, 10)
		local point = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		if index == 1 and rng:NextNumber() < 0.2 then
			stones(patch, point, rng, style.stone)
		else
			tuft(patch, point, style, rng)
		end
	end
	settle(patch)
	patch.WorldPivot = CFrame.new()
	return patch
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
			-- Sample the full ocean footprint, including the remote city approach.
			-- Biome and ocean checks below discard the two unfilled outer corners.
			position = Vector2.new(
				rng:NextNumber(Biomes.OceanMin + 40, Biomes.OceanMax - 40),
				rng:NextNumber(Biomes.OceanMin + 40, Biomes.OceanMax - 40)
			)
		else
			position = biome.center
				+ Vector2.new(math.cos(angle), math.sin(angle)) * (biome.radius - 35) * math.sqrt(rng:NextNumber())
		end
		local world = Vector3.new(position.X, 0, position.Y)
		if Biomes.at(world) ~= biome or not Biomes.inOceanBounds(world) then
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
	return placed
end

local function cellKey(x: number, z: number, cell: number): number
	return math.floor(x / cell) * 100003 + math.floor(z / cell)
end

-- Fill every grid cell the gardens left bare with a copy of a prebuilt patch, seated on
-- the sampled ground. Islands and steep slopes simply fail the sample and stay clear.
local function carpet(details: Folder, params: RaycastParams, seed: number, occupied: { Vector2 })
	local rng = Random.new(seed)
	local lake = Harbour.lakeOutline(Biomes.Normal.center)
	local lakeMin, lakeMax = lake[1], lake[1]
	for _, point in lake do
		lakeMin, lakeMax = lakeMin:Min(point), lakeMax:Max(point)
	end
	local function inLake(position: Vector3): boolean
		if position.X < lakeMin.X or position.X > lakeMax.X or position.Z < lakeMin.Y or position.Z > lakeMax.Y then
			return false
		end
		local inside = false
		local previous = lake[#lake]
		for _, point in lake do
			if
				(point.Y > position.Z) ~= (previous.Y > position.Z)
				and position.X < (previous.X - point.X) * (position.Z - point.Y) / (previous.Y - point.Y) + point.X
			then
				inside = not inside
			end
			previous = point
		end
		return inside
	end
	local pools: { [Style]: { Model } } = {}
	local folders: { [Biomes.Biome]: Folder } = {}
	local lakeFloor = Instance.new("Folder")
	lakeFloor.Name = "LakeFloor"
	lakeFloor.Parent = details:FindFirstChild(Biomes.Normal.name) or details
	local count = 0
	local function cover(cell: number, minimum: number, maximum: number, lakeOnly: boolean)
		local taken: { [number]: boolean } = {}
		for _, position in occupied do
			taken[cellKey(position.X, position.Y, cell)] = true
		end
		-- Align both sampling and occupied keys to the same world-space grid.
		local start = math.floor(minimum / cell) * cell
		for x = start, maximum - 1, cell do
			for z = start, maximum - 1, cell do
				if taken[cellKey(x, z, cell)] then
					continue
				end
				local hit: RaycastResult?
				for _ = 1, 3 do
					-- Bounded jitter leaves room between neighbouring copies.
					local px = math.clamp(x + cell * rng:NextNumber(0.25, 0.75), minimum + 1, maximum - 1)
					local pz = math.clamp(z + cell * rng:NextNumber(0.25, 0.75), minimum + 1, maximum - 1)
					local position = Vector3.new(px, Biomes.WaterLevel - 1, pz)
					if not Biomes.inOceanBounds(position) or inLake(position) ~= lakeOnly then
						continue
					end
					hit = sample(params, px, pz)
					if hit then
						break
					end
				end
				if not hit then
					continue
				end
				local biome = Biomes.at(hit.Position)
				local style = if biome == Biomes.OpenSea then STYLES.open else STYLES[biome.id]
				local pool = pools[style]
				if not pool then
					pool = {}
					for _ = 1, PATCH_TEMPLATES do
						table.insert(pool, patchTemplate(style, rng))
					end
					pools[style] = pool
				end
				local folder = if lakeOnly then lakeFloor else folders[biome]
				if not folder then
					folder = Instance.new("Folder")
					folder.Name = "Floor"
					folder.Parent = details:FindFirstChild(biome.name) or details
					folders[biome] = folder
				end
				local normal = hit.Normal
				local right = normal:Cross(Vector3.zAxis).Unit
				local frame = CFrame.fromMatrix(hit.Position, right, normal, right:Cross(normal))
				local patch = pool[rng:NextInteger(1, #pool)]:Clone()
				patch:ScaleTo(rng:NextNumber(0.9, 1.25))
				patch:PivotTo(frame * CFrame.Angles(0, rng:NextNumber(0, TAU), 0))
				patch.Parent = folder
				count += 1
				if count % 40 == 0 then
					task.wait()
				end
			end
			task.wait()
		end
	end
	-- OceanMax includes the city approaches; inOceanBounds rejects the empty
	-- northeast/southwest corners and dry rooms before any ground ray is cast.
	cover(LAKE_CELL, -Biomes.Normal.radius, Biomes.Normal.radius, true)
	cover(CELL, Biomes.OceanMin, Biomes.OceanMax, false)
	for _, pool in pools do
		for _, template in pool do
			template:Destroy()
		end
	end
end

function SeabedDetails.ensure(root: Instance)
	Seabed.ensureSand(root)
	local old = root:FindFirstChild("SeabedDetails")
	if old and old:GetAttribute("Version") == VERSION then
		return
	end
	if old then
		old:Destroy()
	end

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

	local gardens: { Vector2 } = {}
	for index, biome in Biomes.list do
		local folder = Instance.new("Folder")
		folder.Name = biome.name
		folder.Parent = details
		local occupied = shoreGardens(folder, biome, STYLES[biome.id], surfaces, params, Biomes.Seed + 700 + index)
		-- scatter appends its own gardens to `occupied`
		scatter(folder, biome, STYLES[biome.id], params, Biomes.Seed + 600 + index, occupied)
		table.move(occupied, 1, #occupied, #gardens + 1, gardens)
	end
	local open = Instance.new("Folder")
	open.Name = Biomes.OpenSea.name
	open.Parent = details
	local scattered = scatter(open, Biomes.OpenSea, STYLES.open, params, Biomes.Seed + 606)
	table.move(scattered, 1, #scattered, #gardens + 1, gardens)
	carpet(details, params, Biomes.Seed + 800, gardens)
	details:SetAttribute("Version", VERSION)
end

return SeabedDetails
