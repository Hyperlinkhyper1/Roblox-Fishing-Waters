-- Every rainy player gets an overlapping volumetric cloud deck overhead.
-- Computers also get a distant cloud field: every grid cell may hold one
-- cloud of shaded ellipsoid puffs. Its type is read from the same weather field
-- that drives rain, storms and waves at that spot, so the sky shows the local
-- weather: fair-weather cumulus in clear air, towering congestus where cover
-- builds, low dark nimbostratus with distant rain shafts under rain bands, and
-- anvil-topped cumulonimbus with in-cloud lightning over storm cores. The
-- supercell has its own tower (SupercellWeather); its local rain deck stays filled.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Biomes = require(ReplicatedStorage.Shared.Biomes)
local Weather = require(ReplicatedStorage.Shared.Weather)

local Clouds = {}
local started = false
local TAU = math.pi * 2
local CELL = 560
local VIEW_RADIUS = 3400
local CLOUD_BASE = 430
local LAYOUT_INTERVAL = 0.5
local WEATHER_INTERVAL = 2
local BUILDS_PER_FRAME = 2
local FADE_SECONDS = 4
-- Clouds hold still. Thousands of huge moving puffs (many casting shadows) made
-- the engine re-index every part and redraw shadows each frame: 20 ms spikes in
-- Octree::maintenance and ShadowMapSystem. Parts are placed once, when built.
-- Crossfades rewrite every puff's transparency only once it changes this much.
local FADE_STEP = 0.02
local OPAQUE_BELOW = 0.1
-- Clouds closer than this get their smaller lobes. Beyond it they are hazy shapes
-- in the fog, and a storm sky of a hundred towers held thousands of extra parts.
-- A cloud swaps detail only past the outer radius, so it never flips back and forth.
local DETAIL_RADIUS = 1800
local COARSE_RADIUS = 2200
-- Near shafts would face the camera as a grey wall; the local rain shows there.
local SHAFT_CLEARANCE = 420
local MAX_PART_SIZE = 2048
local CANOPY_CELL = 360
local CANOPY_WIDTH = 760
local CANOPY_HEIGHT = 300
local CANOPY_LIMIT = 36

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

type Spec = {
	width: { number },
	height: { number },
	puffs: { number },
	base: Color3,
	top: Color3,
	altitude: number,
	shaft: number?,
	anvil: boolean?,
	lightning: boolean?,
}

local KINDS: { [string]: Spec } = {
	Fair = {
		width = { 110, 220 },
		height = { 40, 80 },
		puffs = { 6, 9 },
		base = rgb(166, 181, 202),
		top = rgb(255, 255, 255),
		altitude = 0,
	},
	Congestus = {
		width = { 200, 320 },
		height = { 150, 280 },
		puffs = { 10, 14 },
		base = rgb(156, 164, 176),
		top = rgb(250, 251, 253),
		altitude = 0,
	},
	Nimbostratus = {
		width = { 380, 540 },
		height = { 70, 120 },
		puffs = { 11, 15 },
		base = rgb(82, 88, 100),
		top = rgb(150, 156, 168),
		altitude = -60,
		shaft = 0.6,
	},
	Cumulonimbus = {
		width = { 300, 420 },
		height = { 520, 760 },
		puffs = { 14, 18 },
		base = rgb(56, 61, 72),
		top = rgb(232, 234, 240),
		altitude = -40,
		shaft = 0.45,
		anvil = true,
		lightning = true,
	},
}

-- Same integer mixing as Weather: cell layouts must not shimmer between frames.
local function hash(a: number, b: number, c: number): number
	local h = 2166136
	for _, value in { a, b, c } do
		h = (h * 31 + math.floor(value) % 1000003) % 2147483647
		h = (h * 48271) % 2147483647
	end
	return h / 2147483647
end

-- An anchored, non-interactive ellipsoid. Parts stop at 2048 studs, so larger
-- puffs (anvils) stretch their mesh instead.
function Clouds.puff(parent: Instance, color: Color3, size: Vector3, castShadow: boolean): Part
	local part = Instance.new("Part")
	part.Name = "CloudPuff"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = castShadow
	part.Material = Enum.Material.SmoothPlastic
	part.Reflectance = 0
	part.Color = color
	local clamped =
		Vector3.new(math.min(size.X, MAX_PART_SIZE), math.min(size.Y, MAX_PART_SIZE), math.min(size.Z, MAX_PART_SIZE))
	part.Size = clamped
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = size / clamped
	mesh.Parent = part
	part.Parent = parent
	return part
end

-- A grey curtain from a cloud base to the sea, thinning towards the water.
function Clouds.shaft(anchor: BasePart, drop: number, width: number, color: Color3): Beam
	local top = Instance.new("Attachment")
	top.Name = "ShaftTop"
	top.Parent = anchor
	local bottom = Instance.new("Attachment")
	bottom.Name = "ShaftBottom"
	bottom.Position = Vector3.new(0, -drop, 0)
	bottom.Parent = anchor
	local beam = Instance.new("Beam")
	beam.Name = "RainShaft"
	beam.Attachment0, beam.Attachment1 = top, bottom
	beam.Width0, beam.Width1 = width * 0.75, width
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Color = ColorSequence.new(color)
	beam.LightInfluence = 1
	beam.LightEmission = 0
	beam.Parent = anchor
	return beam
end

-- Beam transparency for a shaft at a given opacity (0 hides it).
function Clouds.shaftTransparency(opacity: number): NumberSequence
	local function at(value: number): number
		return 1 - (1 - value) * opacity
	end
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, at(0.35)),
		NumberSequenceKeypoint.new(0.7, at(0.55)),
		NumberSequenceKeypoint.new(1, 1),
	})
end

type Cloud = {
	kind: string,
	detailed: boolean,
	model: Model,
	parts: { BasePart },
	frames: { CFrame },
	transparency: { number },
	core: { BasePart },
	colors: { Color3 },
	shaft: Beam?,
	shaftOpacity: number,
	fade: number,
	target: number,
	appliedFade: number,
	placed: boolean,
	flashAt: number,
	flashUntil: number,
	origin: Vector3,
	position: Vector3,
}

local function build(
	kind: string,
	i: number,
	j: number,
	seed: number,
	windYaw: number,
	parent: Instance,
	detailed: boolean
): Cloud
	local spec = KINDS[kind]
	local rng = Random.new(math.floor(hash(i, j, seed + 17) * 2147483646))
	local model = Instance.new("Model")
	model.Name = kind .. "Cloud"
	local width = rng:NextNumber(spec.width[1], spec.width[2])
	local height = rng:NextNumber(spec.height[1], spec.height[2])
	local count = rng:NextInteger(spec.puffs[1], spec.puffs[2])
	local orientation = CFrame.Angles(0, windYaw + rng:NextNumber(-0.4, 0.4), 0)
	local cloud: Cloud = {
		kind = kind,
		detailed = detailed,
		model = model,
		parts = {},
		frames = {},
		transparency = {},
		core = {},
		colors = {},
		shaft = nil,
		shaftOpacity = spec.shaft or 0,
		fade = 0,
		target = 1,
		appliedFade = -1,
		placed = false,
		flashAt = math.huge,
		flashUntil = 0,
		origin = Vector3.new(
			i * CELL + (hash(i, j, seed) - 0.5) * CELL * 0.8,
			Biomes.WaterLevel + CLOUD_BASE + spec.altitude + (hash(i, j, seed + 3) - 0.5) * 60,
			j * CELL + (hash(i, j, seed + 5) - 0.5) * CELL * 0.8
		),
		position = Vector3.zero,
	}
	local function add(part: BasePart, offset: Vector3, transparency: number)
		table.insert(cloud.parts, part)
		table.insert(cloud.frames, orientation * CFrame.new(offset))
		table.insert(cloud.transparency, transparency)
		part.Transparency = 1
	end
	-- A flat row of base puffs gives the level condensation line real cumulus
	-- have; the rest bulge upwards and inwards, lighter towards the sunlit top.
	local baseCount = math.ceil(count * 0.45)
	for index = 1, count do
		local layer = if index <= baseCount
			then rng:NextNumber(0, 0.08)
			else 0.14 + (index - baseCount - 0.5) / (count - baseCount) * 0.86
		local angle = rng:NextNumber(0, TAU)
		local reach = rng:NextNumber(0, 0.36) * width * (1 - layer * 0.55)
		local size = width * rng:NextNumber(0.34, 0.5) * (1 - layer * 0.35)
		local dims = Vector3.new(
			size,
			if layer < 0.1 then size * 0.32 else math.max(size * 0.78, height / (count - baseCount) * 1.6),
			size * rng:NextNumber(0.8, 1.1)
		)
		local shade = math.clamp(layer * 0.9 + 0.08 + math.cos(angle - windYaw) * 0.1, 0, 1)
		local color = spec.base:Lerp(spec.top, shade)
		-- Rain-bearing decks sit under an overcast sky with no sun to shade from, and
		-- moving shadow casters this size made the engine redraw shadows over the
		-- whole storm every frame.
		local part = Clouds.puff(model, color, dims, not spec.shaft)
		local offset =
			Vector3.new(math.cos(angle) * reach, layer * height + dims.Y * 0.3, math.sin(angle) * reach * 0.8)
		add(part, offset, 0.03)
		-- Smaller lobes intersect the surface of the main volume. Their varied
		-- size and lighting leave scalloped edges and visible shaded creases.
		for detail = 1, 2 do
			local turn = angle + detail * 2.4 + rng:NextNumber(-0.4, 0.4)
			local scale = rng:NextNumber(0.38, 0.62)
			local normal = Vector3.new(math.cos(turn), if layer < 0.1 then 0.18 else 0.55, math.sin(turn))
			local detailColor = spec.base:Lerp(spec.top, math.clamp(shade + rng:NextNumber(-0.12, 0.16), 0, 1))
			-- The random draws above still run, so near and far builds share one shape.
			if not detailed then
				continue
			end
			local billow = Clouds.puff(model, detailColor, dims * scale, false)
			add(billow, offset + normal * dims * 0.4, 0.08)
			if layer > 0.15 and layer < 0.7 then
				table.insert(cloud.core, billow)
				table.insert(cloud.colors, detailColor)
			end
		end
		if layer > 0.15 and layer < 0.7 then
			table.insert(cloud.core, part)
			table.insert(cloud.colors, color)
		end
	end
	if spec.anvil then
		-- Upper winds shear the cumulonimbus top into an anvil leaning downwind.
		for index = 1, 3 do
			local spread = width * (2.4 - index * 0.45)
			local part = Clouds.puff(
				model,
				spec.top:Lerp(rgb(205, 210, 220), 0.4),
				Vector3.new(spread * 1.3, height * 0.1, spread),
				false
			)
			add(part, Vector3.new(0, height * (0.98 + index * 0.03), -spread * 0.3), 0.12 + index * 0.08)
		end
	end
	if spec.shaft then
		local anchor = Instance.new("Part")
		anchor.Name = "ShaftAnchor"
		anchor.Anchored, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = true, false, false, false
		anchor.Transparency, anchor.Size = 1, Vector3.one
		anchor.Parent = model
		local drop = CLOUD_BASE + spec.altitude
		cloud.shaft = Clouds.shaft(anchor, drop, width * 0.7, spec.base:Lerp(rgb(120, 128, 140), 0.5))
		table.insert(cloud.parts, anchor)
		table.insert(cloud.frames, CFrame.new(0, height * 0.05, 0))
		table.insert(cloud.transparency, 1)
	end
	if spec.lightning then
		cloud.flashAt = os.clock() + rng:NextNumber(2, 10)
	end
	model.Parent = parent
	return cloud
end

local function classify(rain: number, storm: number, cover: number): string
	if storm > 0.45 then
		return "Cumulonimbus"
	elseif rain > 0.01 then
		return "Nimbostratus"
	elseif cover > 0.45 then
		return "Congestus"
	end
	return "Fair"
end

type RainPiece = { part: Part, frame: CFrame, shade: number, opacity: number }
type RainTile = {
	model: Model,
	pieces: { RainPiece },
	wisps: ParticleEmitter,
	detailed: boolean,
	fade: number,
	appliedFade: number,
	base: Color3?,
	top: Color3?,
	position: Vector3,
	placed: Vector3?,
}

-- Within one 8-bit step per channel.
local function similar(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) < 1 / 255 and math.abs(a.G - b.G) < 1 / 255 and math.abs(a.B - b.B) < 1 / 255
end

-- The broad opaque core guarantees coverage. Smaller, overlapping volumes sit
-- below it, so looking up reveals turbulent relief instead of a smooth oval.
local function rainTile(i: number, j: number, seed: number, detailed: boolean, parent: Instance): RainTile
	local model = Instance.new("Model")
	model.Name = "RainCloudTile"
	local rng = Random.new(math.floor(hash(i, j, seed + 61) * 2147483646))
	local pieces: { RainPiece } = {}
	local function add(name: string, size: Vector3, offset: Vector3, shade: number, opacity: number)
		-- A shadow caster this size made the engine redraw shadows across the whole
		-- 760-stud tile whenever it changed. Rain already dims the light.
		local part = Clouds.puff(model, rgb(130, 140, 154), size, false)
		part.Name = name
		part.Transparency = 1
		table.insert(pieces, {
			part = part,
			frame = CFrame.new(offset) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0),
			shade = shade,
			opacity = opacity,
		})
	end
	add("RainCloudBody", Vector3.new(CANOPY_WIDTH, 126, CANOPY_WIDTH), Vector3.zero, 0.16, 1)
	add("RainCloudCrown", Vector3.new(620, 130, 570), Vector3.new(35, 65, -20), 0.8, 0.98, 0)
	-- Jittered rows distribute details across the whole underside. Each lobe
	-- has its own satellites and shading, rather than repeating identical puffs.
	local rows = if detailed then 4 else 2
	for x = 1, rows do
		for z = 1, rows do
			local offset = Vector3.new(
				((x - 0.5) / rows - 0.5) * 590 + rng:NextNumber(-24, 24),
				rng:NextNumber(-52, -23),
				((z - 0.5) / rows - 0.5) * 590 + rng:NextNumber(-24, 24)
			)
			local width = rng:NextNumber(160, 235)
			local size = Vector3.new(width, rng:NextNumber(70, 115), width * rng:NextNumber(0.75, 1.18))
			local shade = rng:NextNumber(0.08, 0.5)
			add("RainCloudBillow", size, offset, shade, 0.96, 0)
			if detailed then
				for lobe = 1, 2 do
					local turn = rng:NextNumber(0, TAU)
					local small = size * rng:NextNumber(0.3, 0.52)
					add(
						"RainCloudFringe",
						small,
						offset
							+ Vector3.new(math.cos(turn) * width * 0.35, -size.Y * 0.3, math.sin(turn) * width * 0.35),
						math.clamp(shade + rng:NextNumber(-0.06, 0.12), 0, 1),
						rng:NextNumber(0.68, 0.9),
						0
					)
				end
			end
		end
	end
	-- Ragged, thin scud beneath the main deck breaks its silhouette.
	for index = 1, if detailed then 9 else 3 do
		local turn = rng:NextNumber(0, TAU)
		local reach = rng:NextNumber(80, 320)
		add(
			"RainCloudScud",
			Vector3.new(rng:NextNumber(100, 190), rng:NextNumber(22, 44), rng:NextNumber(55, 105)),
			Vector3.new(math.cos(turn) * reach, rng:NextNumber(-112, -80), math.sin(turn) * reach),
			rng:NextNumber(0.22, 0.58),
			rng:NextNumber(0.4, 0.7)
		)
	end
	local anchor = Instance.new("Part")
	anchor.Name = "CloudWispAnchor"
	anchor.Size = Vector3.new(620, 1, 620)
	anchor.Anchored, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = true, false, false, false
	anchor.CastShadow, anchor.Transparency = false, 1
	anchor.Parent = model
	table.insert(pieces, { part = anchor, frame = CFrame.new(0, -88, 0), shade = 0.4, opacity = 0 })
	local wisps = Instance.new("ParticleEmitter")
	wisps.Name = "CloudWisps"
	wisps.Texture = "rbxasset://textures/particles/smoke_main.dds"
	wisps.Enabled = false
	wisps.Rate = if detailed then 2 else 0.5
	wisps.Lifetime = NumberRange.new(6, 10)
	wisps.Speed = NumberRange.new(2, 5)
	wisps.EmissionDirection = Enum.NormalId.Bottom
	wisps.SpreadAngle = Vector2.new(45, 45)
	wisps.LightInfluence, wisps.LightEmission = 0.3, 0.04
	wisps.Rotation, wisps.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-8, 8)
	wisps.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 64), NumberSequenceKeypoint.new(1, 145) })
	wisps.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.65),
		NumberSequenceKeypoint.new(0.7, 0.74),
		NumberSequenceKeypoint.new(1, 1),
	})
	wisps.Parent = anchor
	model.Parent = parent
	return {
		model = model,
		pieces = pieces,
		wisps = wisps,
		detailed = detailed,
		fade = 0,
		appliedFade = -1,
		position = Vector3.zero,
	}
end

local function startRainCanopy(player: Player)
	local folder: Folder? = nil
	local tiles: { [string]: RainTile } = {}
	local parts: { BasePart }, frames: { CFrame } = {}, {}
	local colorElapsed = 1
	local function clear()
		if folder then
			folder:Destroy()
			folder = nil
		end
		table.clear(tiles)
	end
	-- Run independently of the optional distant sky and its two-second sampler.
	-- In particular, rain onset, teleporting and supercell gaps get coverage in
	-- the same rendered frame. Low graphics reduce detail, never remove the deck.
	RunService.RenderStepped:Connect(function(dt: number)
		local camera = workspace.CurrentCamera
		if not camera then
			clear()
			return
		end
		local now = workspace:GetServerTimeNow()
		local state = Weather.getState(now)
		local seed = workspace:GetAttribute("WeatherSeed") or 1847
		local eye = camera.CFrame.Position
		local focuses = { eye }
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			table.insert(focuses, root.Position)
		end
		local wanted = {}
		local severity, green = 0, 0
		for _, focus in focuses do
			local rain, storm = Weather.localConditions(focus, state)
			if rain <= 0.01 then
				continue
			end
			severity = math.max(severity, storm, rain * 0.65)
			green = math.max(green, Weather.supercellCover(focus, state.supercell))
			local ci = math.floor(focus.X / CANOPY_CELL + 0.5)
			local cj = math.floor(focus.Z / CANOPY_CELL + 0.5)
			for i = ci - 1, ci + 1 do
				for j = cj - 1, cj + 1 do
					local key = i .. "," .. j
					local height = math.max(Biomes.WaterLevel + CANOPY_HEIGHT, focus.Y + 200)
					local primary = i == ci and j == cj
					local previous = wanted[key]
					wanted[key] = {
						i = i,
						j = j,
						primary = primary or (previous and previous.primary) or false,
						height = math.max(height, if previous then previous.height else height),
					}
				end
			end
		end
		if next(wanted) and not folder then
			local created = Instance.new("Folder")
			created.Name = "RainClouds"
			created.Parent = workspace
			folder = created
		end
		local detailed = player:GetAttribute("VolumetricCloudsEnabled") == true
		local built = 0
		-- Build the tile directly above each wet focus first, at full opacity.
		-- Its 760-stud diameter covers every corner of its 360-stud grid cell.
		for _, primary in { true, false } do
			for key, request in wanted do
				if request.primary ~= primary then
					continue
				end
				local tile = tiles[key]
				if not tile or tile.detailed ~= detailed then
					if not primary and built >= 2 then
						continue
					end
					local replacement = rainTile(request.i, request.j, seed, detailed, folder :: Folder)
					replacement.fade = if primary then 1 else 0
					if tile then
						tile.model:Destroy()
					end
					tile = replacement
					tiles[key] = tile
					built += 1
				end
				tile.position = Vector3.new(request.i * CANOPY_CELL, request.height, request.j * CANOPY_CELL)
				-- An already fading neighbor becomes opaque as soon as it is
				-- the overhead tile, so grid crossings can never reveal the sky.
				if primary then
					tile.fade = 1
				end
			end
		end
		colorElapsed += dt
		local recolor = colorElapsed >= 0.15 or built > 0
		if recolor then
			colorElapsed = 0
		end
		local base = rgb(124, 134, 148):Lerp(rgb(58, 68, 82), severity):Lerp(rgb(65, 83, 75), green * 0.55)
		local top = rgb(210, 216, 225):Lerp(rgb(137, 148, 166), severity)
		table.clear(parts)
		table.clear(frames)
		local count = 0
		for _ in tiles do
			count += 1
		end
		for key, tile in tiles do
			local request = wanted[key]
			local distance = math.huge
			for _, focus in focuses do
				local delta = tile.position - Vector3.new(focus.X, tile.position.Y, focus.Z)
				distance = math.min(distance, delta.Magnitude)
			end
			local target = if request then 1 else 0
			tile.fade += math.clamp(target - tile.fade, -dt / FADE_SECONDS, dt / FADE_SECONDS)
			if not request and (tile.fade <= 0 or distance > CANOPY_CELL * 2.5 or count > CANOPY_LIMIT) then
				tile.model:Destroy()
				tiles[key] = nil
				count -= 1
				continue
			end
			local frame = CFrame.new(tile.position)
			-- Up to sixteen tiles of sixty pieces: rewrite their transparency and color
			-- only when the fade or the storm shading actually changed.
			local refade = tile.fade ~= tile.appliedFade
			tile.appliedFade = tile.fade
			local reshade = recolor and (not tile.base or not similar(tile.base, base) or not similar(tile.top, top))
			if reshade then
				tile.base, tile.top = base, top
			end
			-- A tile only moves when it is built or its deck height changes.
			local move = tile.placed ~= tile.position
			tile.placed = tile.position
			for _, piece in tile.pieces do
				if move then
					table.insert(parts, piece.part)
					table.insert(frames, frame * piece.frame)
				end
				if refade then
					piece.part.Transparency = 1 - piece.opacity * tile.fade
				end
				if reshade then
					piece.part.Color = base:Lerp(top, piece.shade)
				end
			end
			tile.wisps.Enabled = request ~= nil and detailed and tile.fade > 0.5
			tile.wisps.Acceleration = state.windDirection * 0.4
			if reshade then
				tile.wisps.Color = ColorSequence.new(base:Lerp(top, 0.5))
			end
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
		if folder and next(tiles) == nil then
			clear()
		end
	end)
end

function Clouds.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	startRainCanopy(player)
	local folder: Folder? = nil
	local clouds: { [string]: Cloud } = {}
	local fading: { Cloud } = {}
	local layoutElapsed, weatherElapsed = LAYOUT_INTERVAL, WEATHER_INTERVAL
	local wanted: { [string]: { i: number, j: number } } = {}
	local requested: { [string]: string } = {}
	local requestedDetail: { [string]: boolean } = {}
	local parts: { BasePart } = {}
	local frames: { CFrame } = {}

	local function clear()
		if folder then
			folder:Destroy()
		end
		folder = nil
		table.clear(clouds)
		table.clear(fading)
		table.clear(wanted)
		table.clear(requested)
		table.clear(requestedDetail)
		table.clear(parts)
		table.clear(frames)
	end

	local function retire(key: string)
		local cloud = clouds[key]
		clouds[key] = nil
		cloud.target = 0
		table.insert(fading, cloud)
	end

	RunService.Heartbeat:Connect(function(dt: number)
		local camera = workspace.CurrentCamera
		if not camera or player:GetAttribute("VolumetricCloudsEnabled") ~= true then
			if folder then
				clear()
			end
			return
		end
		if not folder then
			local created = Instance.new("Folder")
			created.Name = "VolumetricClouds"
			created.Parent = workspace
			folder = created
			layoutElapsed, weatherElapsed = LAYOUT_INTERVAL, WEATHER_INTERVAL
		end
		local now = workspace:GetServerTimeNow()
		local seed = workspace:GetAttribute("WeatherSeed") or 1847
		local angle = (seed % 360) * math.pi / 180
		local wind = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local windYaw = math.atan2(-wind.X, -wind.Z)
		local eye = camera.CFrame.Position
		local function centerOf(i: number, j: number): Vector3
			return Vector3.new(
				i * CELL + (hash(i, j, seed) - 0.5) * CELL * 0.8,
				Biomes.WaterLevel + CLOUD_BASE + (hash(i, j, seed + 3) - 0.5) * 60,
				j * CELL + (hash(i, j, seed + 5) - 0.5) * CELL * 0.8
			)
		end

		layoutElapsed += dt
		weatherElapsed += dt
		if layoutElapsed >= LAYOUT_INTERVAL then
			layoutElapsed = 0
			table.clear(wanted)
			local reach = math.ceil(VIEW_RADIUS / CELL) + 1
			local ci, cj = math.floor(eye.X / CELL), math.floor(eye.Z / CELL)
			for i = ci - reach, ci + reach do
				for j = cj - reach, cj + reach do
					local center = centerOf(i, j)
					local dx, dz = center.X - eye.X, center.Z - eye.Z
					if dx * dx + dz * dz <= VIEW_RADIUS * VIEW_RADIUS then
						wanted[i .. "," .. j] = { i = i, j = j }
					end
				end
			end
			for key in clouds do
				if not wanted[key] then
					retire(key)
				end
			end
		end
		if weatherElapsed >= WEATHER_INTERVAL then
			weatherElapsed = 0
			table.clear(requested)
			table.clear(requestedDetail)
			local state = Weather.getState(now)
			for key, cell in wanted do
				local center = centerOf(cell.i, cell.j)
				local ground = Vector3.new(center.X, 0, center.Z)
				local distance = Vector3.new(center.X - eye.X, 0, center.Z - eye.Z).Magnitude
				local rain, storm, cover = Weather.localConditions(ground, state)
				local occupied = hash(cell.i, cell.j, seed + 11) < 0.18 + cover * 0.75
					and Weather.supercellCover(ground, state.supercell) < Weather.SupercellThreshold * 0.8
				local kind = if occupied then classify(rain, storm, cover) else nil
				local existing = clouds[key]
				local detailed = if existing then existing.detailed else distance < DETAIL_RADIUS
				if existing and (distance < DETAIL_RADIUS or distance > COARSE_RADIUS) then
					detailed = distance < DETAIL_RADIUS
				end
				if existing and (existing.kind ~= kind or existing.detailed ~= detailed) then
					retire(key)
					existing = nil
				end
				if kind and not existing then
					requested[key] = kind
					requestedDetail[key] = detailed
				end
			end
		end
		-- Spread instance creation across frames so weather changes do not build
		-- the entire detailed sky in one frame.
		local built = 0
		for key, kind in requested do
			requested[key] = nil
			local cell = wanted[key]
			if cell and not clouds[key] then
				clouds[key] = build(kind, cell.i, cell.j, seed, windYaw, folder :: Folder, requestedDetail[key] == true)
				built += 1
				if built >= BUILDS_PER_FRAME then
					break
				end
			end
		end
	end)

	-- Fades, lightning and placing new clouds; weather sampling remains on Heartbeat.
	RunService.RenderStepped:Connect(function(dt: number)
		if not folder then
			return
		end
		local clock = os.clock()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local eye = camera.CFrame.Position
		table.clear(parts)
		table.clear(frames)
		local function animate(cloud: Cloud)
			cloud.position = cloud.origin
			local change = dt / FADE_SECONDS
			cloud.fade += math.clamp(cloud.target - cloud.fade, -change, change)
			if cloud.target == 0 and cloud.fade == 0 then
				return
			end
			if not cloud.placed then
				cloud.placed = true
				local base = CFrame.new(cloud.position)
				for index, part in cloud.parts do
					table.insert(parts, part)
					table.insert(frames, base * cloud.frames[index])
				end
			end
			if
				math.abs(cloud.fade - cloud.appliedFade) >= FADE_STEP
				or (cloud.fade == cloud.target and cloud.appliedFade ~= cloud.fade)
			then
				cloud.appliedFade = cloud.fade
				for index, part in cloud.parts do
					local transparency = cloud.transparency[index]
					-- Settled, nearly solid puffs render opaque: thousands of translucent
					-- spheres had to be depth-sorted every frame.
					part.Transparency = if cloud.fade >= 1 and transparency < OPAQUE_BELOW
						then 0
						else 1 - (1 - transparency) * cloud.fade
				end
				if cloud.shaft then
					cloud.shaft.Transparency = Clouds.shaftTransparency(cloud.shaftOpacity * cloud.fade)
				end
			end
			if cloud.shaft then
				local dx, dz = cloud.position.X - eye.X, cloud.position.Z - eye.Z
				cloud.shaft.Enabled = dx * dx + dz * dz > SHAFT_CLEARANCE * SHAFT_CLEARANCE
			end
			-- Lightning inside a distant storm tower lights it up from within.
			if clock >= cloud.flashAt then
				cloud.flashAt = clock + 3 + math.random() * 9
				cloud.flashUntil = clock + 0.12
				for _, part in cloud.core do
					part.Color = rgb(236, 232, 255)
				end
			elseif cloud.flashUntil > 0 and clock >= cloud.flashUntil then
				cloud.flashUntil = 0
				for index, part in cloud.core do
					part.Color = cloud.colors[index]
				end
			end
		end
		for _, cloud in clouds do
			animate(cloud)
		end
		for index = #fading, 1, -1 do
			local cloud = fading[index]
			animate(cloud)
			if cloud.fade <= 0 then
				cloud.model:Destroy()
				table.remove(fading, index)
			end
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

return Clouds
