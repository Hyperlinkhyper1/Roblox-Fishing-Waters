-- Public passenger-ferry landing on the home beach and a stop at the city marina.
-- `ensure` also adds them to older Studio-baked maps without rebuilding either island.
local Biomes = require(game:GetService("ReplicatedStorage").Shared.Biomes)
local Props = require(script.Parent.Props)

local FerryDocks = {}
local rgb = Color3.fromRGB
local M = Enum.Material

-- Bump to replace the landing on maps that already have an older one baked in.
local MAIN_LAYOUT = 3
local LAND = 5 -- level village ground on Harbour Isle
local DECK_TOP = 2.2
local PIER_WIDTH = 12
local WALK_WIDTH = 6

local WOOD = rgb(150, 116, 81)
local WOOD_DARK = rgb(100, 78, 57)
local STONE = rgb(186, 176, 156)
local COPING = rgb(228, 216, 194)
local IRON = rgb(52, 50, 48)
local ROOF = rgb(164, 91, 64)

-- Loose beach and garden props that may sit where the boardwalk now runs.
local CLEARABLE = {
	Palm = true, Bush = true, Tree = true, BeachUmbrella = true, SunLounger = true, Towel = true,
	Driftwood = true, Shells = true, Sandcastle = true, BeachBall = true, Seaweed = true,
	MarramGrass = true, BeachPebbles = true, BucketAndSpade = true, Cabana = true, Boat = true,
}

local function part(parent: Instance, name: string, size: Vector3, position: Vector3 | CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = if typeof(position) == "CFrame" then position else CFrame.new(position)
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function decor(p: Part): Part
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function sign(parent: Instance, name: string, position: Vector3, text: string): Part
	local post = part(parent, name, Vector3.new(1, 6, 1), position, rgb(85, 73, 57), M.Wood)
	post.CanCollide = false
	local board = part(parent, "FerrySign", Vector3.new(12, 4, 0.6), position + Vector3.new(0, 3, 0), rgb(34, 91, 121), M.Wood)
	board.CanCollide = false
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.Text = text
		label.TextColor3 = rgb(248, 246, 228)
		label.TextScaled = true
		label.Parent = gui
	end
	return post
end

-- Height of the island's rendered ground (or seabed) at x, z. Baked maps may hold the ground
-- as several chunked "Ground" models, so every one of them is searched.
local function groundSampler(island: Instance): (number, number) -> number?
	local grounds = {}
	for _, child in island:GetChildren() do
		if child.Name == "Ground" then
			table.insert(grounds, child)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = grounds
	return function(x: number, z: number): number?
		local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -500, 0), params)
		return hit and hit.Position.Y
	end
end

-- Where the boardwalk meets the ring road (or the back lane, or a cross street) walking inland from `fromZ`.
local function findRoad(island: Instance, x: number, fromZ: number): number?
	local village = island:FindFirstChild("Village")
	if not village then return nil end
	local roads = {}
	for _, child in village:GetChildren() do
		if child.Name == "Road" or child.Name == "Lane" or child.Name == "CrossStreets" then
			table.insert(roads, child)
		end
	end
	if #roads == 0 then return nil end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = roads
	for z = fromZ, fromZ - 160, -2 do
		if workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -80, 0), params) then
			return z
		end
	end
	return nil
end

-- Lift umbrellas, palms and the like out of the boardwalk's way; buildings are left alone.
local function clearProps(island: Instance, center: Vector3, size: Vector3)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { island }
	local doomed = {}
	for _, hit in workspace:GetPartBoundsInBox(CFrame.new(center), size, params) do
		local node = hit.Parent
		while node and node ~= island do
			if node:IsA("Model") and CLEARABLE[node.Name] then
				doomed[node] = true
				break
			end
			node = node.Parent
		end
	end
	for model in doomed do
		model:Destroy()
	end
end

local function boardwalk(parent: Instance, points: { Vector3 }, groundAt: (number, number) -> number?)
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		-- Overlap each run a little so bends in the slope stay closed.
		local dir = (b - a).Unit
		local plank = Props.beam(parent, a - dir * 0.3 - Vector3.new(0, 0.25, 0), b + dir * 0.3 - Vector3.new(0, 0.25, 0), WALK_WIDTH, WOOD, 0.5, M.WoodPlanks)
		plank.Name = "Boardwalk"
		-- Stringers along both edges, and short posts where the walk is lifted off the sand.
		for _, side in { -1, 1 } do
			local offset = Vector3.new(side * (WALK_WIDTH / 2 - 0.3), -0.65, 0)
			decor(Props.beam(parent, a + offset, b + offset, 0.5, WOOD_DARK, 0.4, M.Wood)).Name = "Stringer"
			local floor = groundAt(a.X + offset.X, a.Z)
			if floor and a.Y - floor > 0.9 then
				local height = a.Y - floor + 1
				decor(part(parent, "WalkPost", Vector3.new(0.6, height, 0.6), Vector3.new(a.X + offset.X, a.Y - height / 2, a.Z), WOOD_DARK, M.Wood))
			end
		end
	end
end

local function shelter(parent: Instance, center: Vector3)
	local model = Instance.new("Model")
	model.Name = "FerryShelter"
	model.Parent = parent
	for _, dx in { -3.6, 3.6 } do
		for _, dz in { -3.2, 3.2 } do
			part(model, "ShelterPost", Vector3.new(0.65, 6.5, 0.65), center + Vector3.new(dx, 3.25, dz), COPING, M.Limestone)
		end
	end
	-- Pale masonry and a warm tiled roof belong to the plaza's waterfront.
	decor(part(model, "ShelterCornice", Vector3.new(8.4, 0.45, 7.6), center + Vector3.new(0, 6.55, 0), COPING, M.Limestone))
	decor(part(model, "ShelterRoof", Vector3.new(8.8, 0.35, 8),
		CFrame.new(center + Vector3.new(0, 6.95, 0)) * CFrame.Angles(math.rad(-5), 0, 0), ROOF, M.Slate))
	for _, dz in { -3, -1.5, 0, 1.5, 3 } do
		decor(part(model, "RoofTileCourse", Vector3.new(8.7, 0.08, 0.1),
			CFrame.new(center + Vector3.new(0, 7.14 + dz * 0.087, dz)), rgb(139, 72, 52), M.Slate))
	end
	Props.bench(model, center + Vector3.new(0, 0, 1), 0)
end

local function bollard(parent: Instance, ground: Vector3)
	decor(Props.cylinder(parent, ground + Vector3.new(0, 0.6, 0), 1.2, 0.9, IRON, M.Metal)).Name = "Bollard"
	decor(Props.cylinder(parent, ground + Vector3.new(0, 1.3, 0), 0.25, 1.2, IRON, M.Metal)).Name = "BollardCap"
end

function FerryDocks.ensureMain(root: Instance)
	local island = root:FindFirstChild("Harbour Isle", true)
	if not island then return end
	local old = island:FindFirstChild("PublicFerryDock")
	if old and old:GetAttribute("LayoutVersion") == MAIN_LAYOUT then return end
	if old then old:Destroy() end

	local dock = Instance.new("Model")
	dock.Name = "PublicFerryDock"
	dock:SetAttribute("LayoutVersion", MAIN_LAYOUT)
	local center = Biomes.Normal.center
	-- Just west of the plaza and its drydock channel, close to the promenade.
	local x, endZ = center.X - 75, center.Y - 370
	local groundAt = groundSampler(island)

	-- Walk inland from the landing to the waterline, then on to the ring road.
	local waterZ = center.Y - 395
	for z = endZ - 9, endZ - 170, -2 do
		local y = groundAt(x, z)
		if y and y >= 0 then
			waterZ = z
			break
		end
	end
	waterZ = math.min(waterZ, endZ - 30)
	local headZ = waterZ - 2 -- middle of the stone pier head, just up the sand
	local roadZ = findRoad(island, x, headZ - 10) or (headZ - 90)

	clearProps(island, Vector3.new(x, 6, (roadZ + endZ) / 2), Vector3.new(22, 16, endZ - roadZ + 24))
	clearProps(island, Vector3.new(x, 4, endZ), Vector3.new(46, 16, 34))

	-- Landing out in the bay where the ferry comes alongside.
	part(dock, "Landing", Vector3.new(30, 1, 18), Vector3.new(x, DECK_TOP - 0.5, endZ), WOOD, M.WoodPlanks)
	-- Individual board joints and a perimeter rim break up the broad landing surface.
	for z = endZ - 7.5, endZ + 7.5, 2.5 do
		decor(part(dock, "LandingBoardJoint", Vector3.new(29.4, 0.025, 0.055), Vector3.new(x, DECK_TOP + 0.015, z), WOOD_DARK, M.Wood))
	end
	for _, side in { -1, 1 } do
		decor(part(dock, "LandingRim", Vector3.new(0.55, 0.12, 18), Vector3.new(x + side * 14.7, DECK_TOP + 0.06, endZ), WOOD_DARK, M.Wood))
	end
	for _, side in { -1, 1 } do
		decor(part(dock, "LandingFascia", Vector3.new(0.4, 1.2, 18.4), Vector3.new(x + side * 15.2, DECK_TOP - 0.7, endZ), WOOD_DARK, M.Wood))
	end
	decor(part(dock, "LandingFascia", Vector3.new(30.8, 1.2, 0.4), Vector3.new(x, DECK_TOP - 0.7, endZ + 9.2), WOOD_DARK, M.Wood))

	-- Pier from the landing back to the pier head.
	local pierFrom, pierTo = endZ - 9, headZ + 4.5
	part(dock, "PierDeck", Vector3.new(PIER_WIDTH, 1, pierFrom - pierTo), Vector3.new(x, DECK_TOP - 0.5, (pierFrom + pierTo) / 2), WOOD, M.WoodPlanks)

	-- Piles reach the seabed, with a cross brace at each bent.
	local bents = {}
	for z = pierTo + 3, pierFrom, 10 do
		table.insert(bents, { z = z, half = PIER_WIDTH / 2 - 0.6 })
	end
	for _, z in { endZ - 7, endZ, endZ + 7 } do
		table.insert(bents, { z = z, half = 14.2 })
	end
	for _, bent in bents do
		local lowest = DECK_TOP
		for _, side in { -1, 1 } do
			local px = x + side * bent.half
			local floor = math.min(groundAt(px, bent.z) or -10, DECK_TOP - 2)
			local height = DECK_TOP - 1 - floor + 1.5
			part(dock, "PierPile", Vector3.new(1.4, height, 1.4), Vector3.new(px, DECK_TOP - 1 - height / 2, bent.z), WOOD_DARK, M.Wood)
			lowest = math.min(lowest, floor)
		end
		if lowest < -1 then
			decor(part(dock, "PierBrace", Vector3.new(bent.half * 2, 0.6, 0.5), Vector3.new(x, DECK_TOP - 1.6, bent.z), WOOD_DARK, M.Wood))
		end
	end

	-- Railings along the pier and the landing's shore side; the seaward edges stay open for boarding.
	for _, side in { -1, 1 } do
		local rx = x + side * (PIER_WIDTH / 2 - 0.3)
		Props.fence(dock, Vector3.new(rx, DECK_TOP, pierTo + 0.5), Vector3.new(rx, DECK_TOP, pierFrom))
		Props.fence(dock, Vector3.new(rx, DECK_TOP, pierFrom), Vector3.new(x + side * 14.7, DECK_TOP, pierFrom))
		for _, z in { endZ - 6, endZ, endZ + 6 } do
			bollard(dock, Vector3.new(x + side * 14.2, DECK_TOP, z))
		end
	end
	for _, dx in { -10, 0, 10 } do
		bollard(dock, Vector3.new(x + dx, DECK_TOP, endZ + 8.4))
	end

	-- Stone pier head set into the beach, so the pier grows out of the shore instead of stopping on it.
	local headGround = groundAt(x, headZ) or 0.5
	local headBottom = headGround - 4
	-- The coping stands a hair proud of the deck so the two never share a top face.
	part(dock, "PierHead", Vector3.new(18, DECK_TOP - 0.3 - headBottom, 9), Vector3.new(x, (DECK_TOP - 0.3 + headBottom) / 2, headZ), STONE, M.Limestone)
	part(dock, "PierHeadCoping", Vector3.new(18.6, 0.4, 9.6), Vector3.new(x, DECK_TOP - 0.1, headZ), COPING, M.Limestone)
	local rng = Random.new(4127)
	for _ = 1, 10 do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local bx, bz = x + side * rng:NextNumber(8.5, 11.5), headZ + rng:NextNumber(-5, 6)
		local size = rng:NextNumber(2.4, 4.4)
		local floor = groundAt(bx, bz) or 0
		decor(part(dock, "Riprap", Vector3.new(size, size * rng:NextNumber(0.6, 0.9), size * rng:NextNumber(0.8, 1.2)),
			CFrame.new(bx, floor + size * 0.15, bz) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, math.pi), rng:NextNumber(-0.4, 0.4)),
			STONE:Lerp(rgb(150, 140, 120), rng:NextNumber(0, 0.5)), M.Limestone)).CanCollide = true
	end
	for _, side in { -1, 1 } do
		Props.lampPost(dock, Vector3.new(x + side * 7.8, DECK_TOP, headZ - 3))
	end

	-- Boardwalk from the pier head over the sand and up the dune to the road, hugging the ground.
	local walkFrom = headZ - 4.8
	local points = { Vector3.new(x, DECK_TOP + 0.1, walkFrom) }
	local z = walkFrom - 7
	while z > roadZ - 1 do
		table.insert(points, Vector3.new(x, (groundAt(x, z) or LAND) + 0.45, z))
		z -= 6
	end
	table.insert(points, Vector3.new(x, (groundAt(x, roadZ - 1) or LAND) + 0.45, roadZ - 1))
	boardwalk(dock, points, groundAt)

	-- Lamps and a fingerpost where the boardwalk meets the road.
	local top = points[#points]
	Props.lampPost(dock, Vector3.new(x + WALK_WIDTH / 2 + 1.5, top.Y - 0.45, roadZ + 2))
	Props.signpost(dock, Vector3.new(x - WALK_WIDTH / 2 - 1.5, top.Y - 0.45, roadZ + 2), -math.pi / 2, { { "Ferry", 0 } })
	local middle = points[math.max(1, math.floor(#points / 2))]
	Props.lampPost(dock, Vector3.new(x + WALK_WIDTH / 2 + 1.2, middle.Y - 0.45, middle.Z))

	-- Waiting shelter, luggage and a lifebuoy on the landing.
	shelter(dock, Vector3.new(x - 10, DECK_TOP, endZ))
	Props.barrel(dock, Vector3.new(x + 12, DECK_TOP, endZ - 6), rng)
	Props.crates(dock, Vector3.new(x + 10, DECK_TOP, endZ - 6.5), rng)
	local buoyPost = part(dock, "LifebuoyPost", Vector3.new(0.6, 4, 0.6), Vector3.new(x + 13, DECK_TOP + 2, endZ - 1), WOOD_DARK, M.Wood)
	buoyPost.CanCollide = false
	local ring = Instance.new("Part")
	ring.Name = "Lifebuoy"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.Size = Vector3.new(0.5, 2.4, 2.4)
	ring.CFrame = CFrame.new(x + 12.6, DECK_TOP + 2.8, endZ - 1)
	ring.Color = rgb(226, 82, 58)
	ring.Material = M.SmoothPlastic
	decor(ring).Parent = dock
	sign(dock, "FerryMainStop", Vector3.new(x + 10, DECK_TOP + 3, endZ + 1), "PUBLIC FERRY\nCITY SERVICE")

	dock.Parent = island
end

function FerryDocks.ensureCity(root: Instance)
	local city = root:FindFirstChild("Modern City")
	if not city or city:FindFirstChild("PublicFerryStop") then return end
	local stop = Instance.new("Model")
	stop.Name = "PublicFerryStop"
	stop.Parent = city
	-- Existing marina walkway has gangways to the city quay; its north side faces open water.
	sign(stop, "FerryCityStop", Vector3.new(6600, 4.4, 6828), "PUBLIC FERRY\nGULLHAVEN")
end

return FerryDocks
