-- Island layouts and set dressing for each biome, plus the open sea between them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Biomes = require(ReplicatedStorage.Shared.Biomes)
local Harbour = require(script.Parent.Harbour)
local Islands = require(script.Parent.Islands)
local Props = require(script.Parent.Props)

type Biome = Biomes.Biome
type Palette = Islands.Palette

type Circle = { position: Vector2, radius: number }

export type Context = {
	rng: Random,
	biome: Biome,
	folder: Folder,
	placed: { Circle }, -- shared across all biomes so nothing overlaps
}

type Built = { model: Model, position: Vector2, radius: number, height: number }

type IslandOptions = { shoreLine: number?, elongation: number?, roughness: number? }

local Regions = {}

local Terrain = workspace.Terrain
local TAU = math.pi * 2
local rgb = Color3.fromRGB
local pick = Props.pick

-- Islands reserve a bit more than their radius because shape noise pushes the coast outward.
local FOOTPRINT = 1.35

----------------------------------------------------------------------------------------------------
-- Palettes

local M = Enum.Material

local function mats(top: Enum.Material, cliff: Enum.Material, shore: Enum.Material): Islands.Materials
	return { top = top, cliff = cliff, shore = shore }
end

local NORMAL = {
	land = { top = rgb(98, 116, 78), cliff = rgb(120, 118, 116), shore = rgb(186, 172, 138) },
	rock = {
		top = rgb(108, 108, 104),
		cliff = rgb(120, 118, 116),
		shore = rgb(140, 134, 120),
		materials = mats(M.Rock, M.Slate, M.Pebble),
	},
	pine = rgb(52, 66, 54),
	autumn = { rgb(184, 112, 56), rgb(150, 84, 44), rgb(122, 98, 58), rgb(170, 128, 62) },
	walls = { rgb(232, 226, 212), rgb(214, 196, 150), rgb(188, 92, 70), rgb(220, 214, 200), rgb(200, 170, 96) },
	roofs = { rgb(140, 52, 44), rgb(110, 44, 40), rgb(84, 74, 70) },
}

local SWAMP = {
	land = {
		top = rgb(96, 94, 52),
		cliff = rgb(84, 64, 40),
		shore = rgb(104, 86, 54),
		materials = mats(M.LeafyGrass, M.Mud, M.Mud),
	},
	bark = rgb(74, 50, 36),
	canopy = { rgb(150, 82, 40), rgb(124, 64, 34), rgb(172, 104, 48), rgb(110, 90, 44) },
	snag = rgb(70, 60, 50),
	walls = { rgb(110, 84, 60), rgb(96, 76, 58), rgb(130, 110, 80) },
	roofs = { rgb(70, 60, 50), rgb(90, 70, 50) },
}

local TROPICAL = {
	land = {
		top = rgb(104, 158, 72),
		cliff = rgb(178, 156, 118),
		shore = rgb(238, 224, 184),
		materials = mats(M.LeafyGrass, M.Sandstone, M.Sand),
	},
	sand = {
		top = rgb(240, 228, 190),
		cliff = rgb(220, 204, 160),
		shore = rgb(236, 222, 184),
		materials = mats(M.Sand, M.Sand, M.Sand),
	},
	rock = {
		top = rgb(150, 140, 120),
		cliff = rgb(168, 156, 130),
		shore = rgb(220, 206, 170),
		materials = mats(M.Sandstone, M.Sandstone, M.Sand),
	},
	bush = { rgb(70, 140, 60), rgb(90, 160, 70), rgb(60, 120, 64) },
	coral = { rgb(240, 110, 110), rgb(250, 160, 80), rgb(190, 110, 200), rgb(250, 210, 90), rgb(90, 200, 190) },
	walls = { rgb(150, 116, 80), rgb(170, 136, 96) },
	thatch = rgb(206, 176, 110),
}

local VOLCANIC = {
	land = {
		top = rgb(74, 66, 64),
		cliff = rgb(44, 40, 42),
		shore = rgb(56, 52, 52),
		materials = mats(M.Basalt, M.Basalt, M.Sand),
	},
	scorched = {
		top = rgb(96, 70, 56),
		cliff = rgb(50, 44, 44),
		shore = rgb(60, 56, 54),
		materials = mats(M.Ground, M.Basalt, M.Sand),
	},
	charred = rgb(34, 30, 30),
	basalt = rgb(40, 38, 42),
}

local ICE = {
	snow = {
		top = rgb(234, 240, 245),
		cliff = rgb(142, 160, 176),
		shore = rgb(206, 220, 230),
		materials = mats(M.Snow, M.Rock, M.Snow),
	},
	berg = {
		top = rgb(242, 248, 252),
		cliff = rgb(166, 208, 230),
		shore = rgb(196, 226, 240),
		materials = mats(M.Snow, M.Glacier, M.Ice),
	},
	pine = rgb(46, 64, 62),
	frost = rgb(236, 242, 246),
	shard = rgb(170, 215, 238),
}

----------------------------------------------------------------------------------------------------
-- Placement helpers

local function isFree(placed: { Circle }, position: Vector2, radius: number, gap: number): boolean
	for _, c in placed do
		if (c.position - position).Magnitude < c.radius + radius + gap then
			return false
		end
	end
	return true
end

-- Random open spot for a circle inside the biome, or nil if it is too crowded.
local function findSpot(ctx: Context, radius: number, gap: number, spread: number?): Vector2?
	local area = ctx.biome.radius * (spread or 0.92)
	for _ = 1, 80 do
		local a = ctx.rng:NextNumber(0, TAU)
		local p = ctx.biome.center + Vector2.new(math.cos(a), math.sin(a)) * area * math.sqrt(ctx.rng:NextNumber())
		if isFree(ctx.placed, p, radius, gap) then
			return p
		end
	end
	return nil
end

local function island(
	ctx: Context,
	position: Vector2,
	radius: number,
	height: number,
	shape: string,
	palette: Palette,
	options: IslandOptions?
): Built
	local model = Islands.build({
		position = position,
		radius = radius,
		height = height,
		shape = shape,
		palette = palette,
		rng = ctx.rng,
		seaFloor = ctx.biome.shelfDepth or Biomes.SeaFloor,
		shoreLine = options and options.shoreLine,
		elongation = options and options.elongation,
		roughness = options and options.roughness,
	})
	model.Parent = ctx.folder
	table.insert(ctx.placed, { position = position, radius = radius * FOOTPRINT })
	task.wait()
	return { model = model, position = position, radius = radius, height = height }
end

-- Scatters `count` islands of a size range across the biome. Returns the ones that fit.
local function archipelago(
	ctx: Context,
	count: number,
	radii: { number },
	heights: { number },
	shapes: { string },
	palette: Palette,
	options: IslandOptions?
): { Built }
	local built = {}
	for _ = 1, count do
		local radius = ctx.rng:NextNumber(radii[1], radii[2])
		local spot = findSpot(ctx, radius * FOOTPRINT, math.max(25, radius * 0.4))
		if spot then
			local height = ctx.rng:NextNumber(heights[1], heights[2])
			table.insert(built, island(ctx, spot, radius, height, pick(ctx.rng, shapes), palette, options))
		end
	end
	return built
end

local function isClear(taken: { Vector3 }, point: Vector3, spacing: number): boolean
	for _, other in taken do
		if Vector2.new(other.X - point.X, other.Z - point.Z).Magnitude < spacing then
			return false
		end
	end
	return true
end

-- Calls `place` at up to `count` flat spots on an island at or above `minHeight`.
local function scatterOn(
	ctx: Context,
	built: Built,
	count: number,
	minHeight: number,
	spacing: number,
	place: (Vector3) -> (),
	taken: { Vector3 }?
)
	local spots = taken or {}
	local done = 0
	for _ = 1, count * 6 do
		if done >= count then
			break
		end
		local a = ctx.rng:NextNumber(0, TAU)
		local d = built.radius * 1.1 * math.sqrt(ctx.rng:NextNumber())
		local ground, normal =
			Islands.surface(built.model, built.position.X + math.cos(a) * d, built.position.Y + math.sin(a) * d)
		if ground and normal and ground.Y >= minHeight and normal.Y > 0.8 and isClear(spots, ground, spacing) then
			table.insert(spots, ground)
			place(ground)
			done += 1
		end
	end
end

-- Roughly how many props fit on an island's usable top at a given density (per 1000 square studs).
local function areaCount(built: Built, density: number, cap: number): number
	return math.min(math.floor(math.pi * (built.radius * 0.7) ^ 2 / 1000 * density), cap)
end

-- Random points of open water in the biome (away from islands).
local function openWater(ctx: Context, count: number, spacing: number, place: (Vector3) -> ())
	for _ = 1, count do
		local spot = findSpot(ctx, spacing, 0, 0.95)
		if spot then
			table.insert(ctx.placed, { position = spot, radius = spacing * 0.5 })
			place(Vector3.new(spot.X, Biomes.WaterLevel, spot.Y))
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Gullhaven Sound: temperate home waters around the harbour isle

local function forest(ctx: Context, built: Built, density: number, cap: number, autumnShare: number)
	local rng = ctx.rng
	scatterOn(ctx, built, areaCount(built, density, cap), 4, 8, function(ground)
		if rng:NextNumber() < autumnShare then
			Props.broadleaf(built.model, ground, rng, NORMAL.autumn)
		else
			Props.pine(built.model, ground, rng, NORMAL.pine)
		end
	end)
end

function Regions.normal(ctx: Context, onHarbourReady: ((CFrame) -> ())?): CFrame
	local rng = ctx.rng
	local spawn = Harbour.build(ctx.folder, rng, ctx.biome.center)
	table.insert(ctx.placed, { position = ctx.biome.center, radius = Harbour.FOOTPRINT })
	-- The complete home island has collision, bases, both shops and launch docks.
	-- Surrounding scenery must not hold up the player's first spawn.
	if onHarbourReady then
		onHarbourReady(spawn)
	end

	-- Tall crags crowned with pines, like the cliffs guarding the harbour
	for _, crag in archipelago(ctx, 3, { 110, 160 }, { 80, 120 }, { "stack" }, NORMAL.land, { roughness = 0.3 }) do
		forest(ctx, crag, 3, 40, 0.2)
	end
	for _, isle in archipelago(ctx, 7, { 100, 190 }, { 22, 60 }, { "plateau", "peak" }, NORMAL.land) do
		forest(ctx, isle, 2.5, 60, 0.4)
		scatterOn(ctx, isle, 4, 2, 20, function(ground)
			Props.boulder(isle.model, ground, rng, rng:NextNumber(3, 6), NORMAL.rock.cliff)
		end)
	end
	for _, isle in archipelago(ctx, 18, { 28, 75 }, { 10, 34 }, { "plateau", "stack", "peak" }, NORMAL.land) do
		forest(ctx, isle, 2, 10, 0.35)
	end
	archipelago(ctx, 30, { 6, 22 }, { 5, 28 }, { "stack", "peak" }, NORMAL.rock, { roughness = 0.5 })

	return spawn
end

----------------------------------------------------------------------------------------------------
-- The Sodden Mire: shallow murky water, mangroves and stilt shacks

local function mangrove(ctx: Context, parent: Instance, ground: Vector3, floorY: number)
	Props.mangrove(parent, ground, ctx.rng, floorY, SWAMP.bark, SWAMP.canopy)
end

local function swampIsland(ctx: Context, built: Built, density: number, cap: number)
	local rng = ctx.rng
	scatterOn(ctx, built, areaCount(built, density, cap), 1, 10, function(ground)
		if rng:NextNumber() < 0.75 then
			mangrove(ctx, built.model, ground, ground.Y - 2)
		else
			Props.deadTree(built.model, ground, rng, SWAMP.snag)
		end
	end)
end

function Regions.swamp(ctx: Context)
	local rng = ctx.rng
	local options = { shoreLine = 1, roughness = 0.5 }

	local heart = island(ctx, ctx.biome.center, 340, 9, "mound", SWAMP.land, options)
	local taken = {}
	scatterOn(ctx, heart, 8, 3, 30, function(ground)
		local wall, roof = pick(rng, SWAMP.walls), pick(rng, SWAMP.roofs)
		Props.house(heart.model, ground, rng:NextNumber(0, TAU), rng, wall, roof, 4)
	end, taken)
	scatterOn(ctx, heart, 60, 1, 10, function(ground)
		if rng:NextNumber() < 0.8 then
			mangrove(ctx, heart.model, ground, ground.Y - 2)
		else
			Props.deadTree(heart.model, ground, rng, SWAMP.snag)
		end
	end, taken)

	for _, isle in archipelago(ctx, 8, { 80, 160 }, { 5, 9 }, { "mound" }, SWAMP.land, options) do
		swampIsland(ctx, isle, 1.5, 18)
	end
	for _, isle in archipelago(ctx, 24, { 16, 50 }, { 3, 6 }, { "mound" }, SWAMP.land, options) do
		swampIsland(ctx, isle, 2, 3)
	end

	-- Mangroves standing straight out of the shallows
	local shelf = ctx.biome.shelfDepth or Biomes.SeaFloor
	openWater(ctx, 170, 10, function(water)
		mangrove(ctx, ctx.folder, water, shelf)
	end)
	openWater(ctx, 130, 6, function(water)
		Props.reeds(ctx.folder, water, rng)
	end)
	openWater(ctx, 200, 4, function(water)
		Props.lilyPad(ctx.folder, water, rng)
	end)
end

----------------------------------------------------------------------------------------------------
-- Coral Shallows: turquoise water, atolls, sandbars and palms

local function palms(ctx: Context, built: Built, count: number)
	local rng = ctx.rng
	scatterOn(ctx, built, count, 1.2, 8, function(ground)
		if rng:NextNumber() < 0.75 then
			Props.palm(built.model, ground, rng)
		else
			Props.bush(built.model, ground, rng, TROPICAL.bush)
		end
	end)
end

function Regions.tropical(ctx: Context)
	local rng = ctx.rng

	local lagoon = island(ctx, ctx.biome.center, 420, 7, "atoll", TROPICAL.land, { elongation = 0.1, roughness = 0.3 })
	local taken = {}
	scatterOn(ctx, lagoon, 6, 2, 40, function(ground)
		Props.house(lagoon.model, ground, rng:NextNumber(0, TAU), rng, pick(rng, TROPICAL.walls), TROPICAL.thatch, 3)
	end, taken)
	scatterOn(ctx, lagoon, 90, 1.2, 8, function(ground)
		if rng:NextNumber() < 0.7 then
			Props.palm(lagoon.model, ground, rng)
		else
			Props.bush(lagoon.model, ground, rng, TROPICAL.bush)
		end
	end, taken)

	for _, atoll in archipelago(ctx, 4, { 120, 200 }, { 5, 7 }, { "atoll" }, TROPICAL.land, { roughness = 0.3 }) do
		palms(ctx, atoll, 25)
	end
	for _, isle in archipelago(ctx, 5, { 80, 140 }, { 14, 30 }, { "mound", "peak" }, TROPICAL.land) do
		palms(ctx, isle, areaCount(isle, 2.5, 30))
	end
	for _, bar in archipelago(ctx, 20, { 16, 45 }, { 1.6, 3 }, { "mound" }, TROPICAL.sand, { shoreLine = 99 }) do
		palms(ctx, bar, rng:NextInteger(0, 3))
	end
	archipelago(ctx, 14, { 6, 18 }, { 6, 20 }, { "stack" }, TROPICAL.rock, { roughness = 0.5 })

	-- Coral gardens on the sandy shelf, visible through the clear water
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Terrain }
	params.IgnoreWater = true
	for _ = 1, 280 do
		local a = rng:NextNumber(0, TAU)
		local d = ctx.biome.radius * 0.95 * math.sqrt(rng:NextNumber())
		local p = ctx.biome.center + Vector2.new(math.cos(a), math.sin(a)) * d
		local hit = workspace:Raycast(Vector3.new(p.X, -1, p.Y), Vector3.new(0, -80, 0), params)
		if hit and hit.Material ~= Enum.Material.Water and hit.Position.Y < -4 then
			Props.coral(ctx.folder, hit.Position, rng, TROPICAL.coral)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Cinder Isles: black rock, a smoking volcano and rivers of lava

local function surfacePath(built: Built, angle: number, from: number, to: number, rng: Random): { Vector3 }
	local points = {}
	local wobble = 0
	for t = from, to, 0.04 do
		wobble += rng:NextNumber(-0.04, 0.04)
		local a = angle + wobble
		local ground = Islands.surface(
			built.model,
			built.position.X + math.cos(a) * built.radius * t,
			built.position.Y + math.sin(a) * built.radius * t
		)
		if not ground or ground.Y < 0 then
			break
		end
		table.insert(points, ground)
	end
	return points
end

function Regions.volcanic(ctx: Context)
	local rng = ctx.rng

	local volcano = island(ctx, ctx.biome.center, 440, 240, "volcano", VOLCANIC.land, {
		shoreLine = 3,
		elongation = 0.1,
		roughness = 0.25,
	})
	local center = Vector3.new(volcano.position.X, 0, volcano.position.Y)
	local floor = Islands.surface(volcano.model, center.X, center.Z)
	if floor then
		Props.crater(volcano.model, floor + Vector3.new(0, 3, 0), volcano.radius * 0.13, volcano.height)
	end
	for i = 1, 4 do
		local path = surfacePath(volcano, i / 4 * TAU + rng:NextNumber(-0.4, 0.4), 0.26, 0.9, rng)
		if #path > 1 then
			Props.lavaFlow(volcano.model, path)
		end
	end
	scatterOn(ctx, volcano, 18, 4, 14, function(ground)
		Props.deadTree(volcano.model, ground, rng, VOLCANIC.charred)
	end)
	scatterOn(ctx, volcano, 10, 2, 20, function(ground)
		Props.basalt(volcano.model, ground, rng, VOLCANIC.basalt)
	end)

	for _, isle in archipelago(ctx, 6, { 90, 170 }, { 40, 100 }, { "peak", "stack" }, VOLCANIC.scorched) do
		scatterOn(ctx, isle, 4, 2, 15, function(ground)
			Props.basalt(isle.model, ground, rng, VOLCANIC.basalt)
		end)
		scatterOn(ctx, isle, 3, 4, 20, function(ground)
			Props.lavaPool(isle.model, ground, rng)
		end)
		scatterOn(ctx, isle, 6, 4, 10, function(ground)
			Props.deadTree(isle.model, ground, rng, VOLCANIC.charred)
		end)
		scatterOn(ctx, isle, 1, 4, 1, function(ground)
			Props.vent(isle.model, ground)
		end)
	end
	for _, isle in archipelago(ctx, 18, { 25, 65 }, { 15, 50 }, { "stack", "peak" }, VOLCANIC.land) do
		scatterOn(ctx, isle, 1, 2, 1, function(ground)
			Props.basalt(isle.model, ground, rng, VOLCANIC.basalt)
		end)
	end
	-- Jagged spires
	archipelago(ctx, 34, { 6, 18 }, { 8, 34 }, { "stack" }, VOLCANIC.land, { roughness = 0.6 })
end

----------------------------------------------------------------------------------------------------
-- Frostmere Expanse: snowy islands, icebergs and drifting floes

local function snowForest(ctx: Context, built: Built, density: number, cap: number)
	local rng = ctx.rng
	scatterOn(ctx, built, areaCount(built, density, cap), 4, 8, function(ground)
		Props.pine(built.model, ground, rng, ICE.pine, ICE.frost)
	end)
end

local function shards(ctx: Context, built: Built, count: number)
	local rng = ctx.rng
	scatterOn(ctx, built, count, 3, 12, function(ground)
		Props.spike(built.model, ground, rng, rng:NextNumber(10, 26), rng:NextNumber(2.5, 4.5), ICE.shard)
	end)
end

function Regions.ice(ctx: Context)
	local glacier = island(ctx, ctx.biome.center, 360, 40, "plateau", ICE.snow, { elongation = 0.2 })
	snowForest(ctx, glacier, 2, 70)
	shards(ctx, glacier, 8)

	for _, isle in archipelago(ctx, 4, { 100, 170 }, { 30, 70 }, { "plateau", "peak" }, ICE.snow) do
		snowForest(ctx, isle, 2, 25)
	end
	for _, berg in archipelago(ctx, 9, { 60, 150 }, { 22, 55 }, { "berg" }, ICE.berg, { roughness = 0.5 }) do
		shards(ctx, berg, ctx.rng:NextInteger(1, 3))
	end
	archipelago(ctx, 20, { 18, 55 }, { 8, 28 }, { "berg", "stack" }, ICE.berg, { roughness = 0.5 })
	-- Flat floes drifting between the bergs
	archipelago(ctx, 50, { 6, 22 }, { 0.8, 1.6 }, { "mound" }, ICE.berg, { shoreLine = -1, roughness = 0.6 })
end

----------------------------------------------------------------------------------------------------
-- Open sea between the biomes: lone sea stacks and channel buoys

function Regions.openSea(ctx: Context)
	local rng = ctx.rng
	local limit = Biomes.MapHalfSize - 300

	local function outsideBiomes(p: Vector2): boolean
		for _, biome in Biomes.list do
			if (p - biome.center).Magnitude < biome.radius then
				return false
			end
		end
		return true
	end

	local stacks = 0
	for _ = 1, 2000 do
		if stacks >= 55 then
			break
		end
		local p = Vector2.new(rng:NextNumber(-limit, limit), rng:NextNumber(-limit, limit))
		local radius = rng:NextNumber(8, 40)
		if outsideBiomes(p) and isFree(ctx.placed, p, radius * FOOTPRINT, 60) then
			local palette = if rng:NextNumber() < 0.3 then NORMAL.land else NORMAL.rock
			local stack = island(ctx, p, radius, rng:NextNumber(10, 55), pick(rng, { "stack", "peak" }), palette)
			if palette == NORMAL.land then
				forest(ctx, stack, 2, 4, 0)
			end
			stacks += 1
		end
	end

	-- Buoys marking the routes out from the Sound to each biome
	for _, biome in Biomes.list do
		if biome ~= Biomes.Normal then
			local route = biome.center - Biomes.Normal.center
			local across = Vector2.new(-route.Y, route.X).Unit
			for _, t in { 0.42, 0.5, 0.58 } do
				for _, side in { -1, 1 } do
					local p = Biomes.Normal.center + route * t + across * side * 50
					if isFree(ctx.placed, p, 6, 4) then
						Props.buoy(ctx.folder, Vector3.new(p.X, 0, p.Y), rng)
					end
				end
			end
		end
	end
end

return Regions
