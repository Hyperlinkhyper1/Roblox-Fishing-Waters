-- Every rainy player gets an overlapping volumetric cloud deck overhead.
-- Computers also get a distant cloud field: every grid cell may hold one
-- cloud. Its type is read from the same weather field that drives rain, storms
-- and waves at that spot, so the sky shows the local weather: fair-weather
-- cumulus in clear air, towering congestus where cover builds, low dark
-- nimbostratus with distant rain shafts under rain bands, and anvil-topped
-- cumulonimbus with in-cloud lightning over storm cores. The supercell has its
-- own tower (SupercellWeather); its local rain deck stays filled.
--
-- Clouds are soft billows, not solid shapes: a few invisible anchor parts per
-- cloud each carry a particle emitter that keeps a set of camera-facing puffs
-- alive inside its volume. A cloud is two to six parts instead of the fifty
-- ellipsoids it used to be. Only the big rain-bearing clouds keep an opaque
-- core, so rain never shows sky through gaps between puffs.
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
-- Crossfades rewrite core transparency only once it changes this much.
local FADE_STEP = 0.02
local OPAQUE_BELOW = 0.1
-- Clouds closer than this get their full billow count. Beyond it they are hazy
-- shapes in the fog. A cloud swaps detail only past the outer radius, so it
-- never flips back and forth.
local DETAIL_RADIUS = 1800
local COARSE_RADIUS = 2200
-- Near shafts would face the camera as a grey wall; the local rain shows there.
local SHAFT_CLEARANCE = 420
local MAX_PART_SIZE = 2048
local CANOPY_CELL = 360
local CANOPY_WIDTH = 760
local CANOPY_HEIGHT = 300
local CANOPY_LIMIT = 36
local BILLOW_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
-- Particle sprites stay at or under 100 studs; bigger clouds use more of them.
local BILLOW_MAX = 100
-- Each billow lives this long, so a cloud slowly churns as old puffs fade out
-- and new ones fade in, and a retired cloud dissolves instead of popping.
local BILLOW_LIFE = { 10, 16 }
-- Enough puffs to cover a layer's largest silhouette about twice over; around an
-- opaque core, which already blocks the sky, about once.
local BILLOW_COVER = 2.2
local CORED_COVER = 1.2
local BILLOW_LIMIT = 32
local COARSE_BILLOWS = 0.4

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

type Layer = {
	name: string,
	scale: Vector3,
	y: number,
	puff: number,
	shade: { number },
	surface: boolean?,
}

type Spec = {
	width: { number },
	height: { number },
	base: Color3,
	top: Color3,
	altitude: number,
	layers: { Layer },
	core: { scale: Vector3, y: number, shade: number }?,
	shaft: number?,
	anvil: boolean?,
	lightning: boolean?,
}

-- Layers are fractions of the cloud's width (x, z) and height (y). The flat
-- base gives the level condensation line real cumulus have; layers above bulge
-- upwards and inwards, lighter towards the sunlit top.
local KINDS: { [string]: Spec } = {
	Fair = {
		width = { 110, 220 },
		height = { 40, 80 },
		base = rgb(166, 181, 202),
		top = rgb(255, 255, 255),
		altitude = 0,
		layers = {
			{ name = "Base", scale = Vector3.new(1, 0.35, 0.85), y = 0.15, puff = 0.42, shade = { 0.05, 0.3 } },
			{ name = "Body", scale = Vector3.new(0.75, 0.9, 0.65), y = 0.55, puff = 0.45, shade = { 0.5, 1 } },
		},
	},
	Congestus = {
		width = { 200, 320 },
		height = { 150, 280 },
		base = rgb(156, 164, 176),
		top = rgb(250, 251, 253),
		altitude = 0,
		layers = {
			{ name = "Base", scale = Vector3.new(1, 0.25, 0.85), y = 0.1, puff = 0.38, shade = { 0.05, 0.3 } },
			{ name = "Body", scale = Vector3.new(0.8, 0.75, 0.7), y = 0.45, puff = 0.4, shade = { 0.35, 0.85 } },
			{ name = "Crown", scale = Vector3.new(0.5, 0.35, 0.45), y = 0.82, puff = 0.36, shade = { 0.8, 1 } },
		},
	},
	Nimbostratus = {
		width = { 380, 540 },
		height = { 70, 120 },
		base = rgb(82, 88, 100),
		top = rgb(150, 156, 168),
		altitude = -60,
		shaft = 0.6,
		core = { scale = Vector3.new(0.85, 0.6, 0.75), y = 0.4, shade = 0.35 },
		layers = {
			{ name = "Base", scale = Vector3.new(1, 0.4, 0.9), y = 0.15, puff = 0.25, shade = { 0, 0.25 } },
			{
				name = "Body",
				scale = Vector3.new(0.92, 0.85, 0.8),
				y = 0.5,
				puff = 0.25,
				shade = { 0.3, 0.8 },
				surface = true,
			},
		},
	},
	Cumulonimbus = {
		width = { 300, 420 },
		height = { 520, 760 },
		base = rgb(56, 61, 72),
		top = rgb(232, 234, 240),
		altitude = -40,
		shaft = 0.45,
		anvil = true,
		lightning = true,
		core = { scale = Vector3.new(0.6, 0.8, 0.55), y = 0.45, shade = 0.45 },
		layers = {
			{ name = "Base", scale = Vector3.new(1, 0.15, 0.9), y = 0.07, puff = 0.3, shade = { 0, 0.2 } },
			{
				name = "Body",
				scale = Vector3.new(0.8, 0.85, 0.72),
				y = 0.47,
				puff = 0.3,
				shade = { 0.25, 0.85 },
				surface = true,
			},
			{ name = "Crown", scale = Vector3.new(0.55, 0.22, 0.5), y = 0.88, puff = 0.3, shade = { 0.85, 1 } },
		},
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

local function clampedSize(size: Vector3): Vector3
	return Vector3.new(
		math.min(size.X, MAX_PART_SIZE),
		math.min(size.Y, MAX_PART_SIZE),
		math.min(size.Z, MAX_PART_SIZE)
	)
end

-- An anchored, non-interactive ellipsoid: the opaque core of a big cloud. Parts
-- stop at 2048 studs, so larger cores (anvils) stretch their mesh instead.
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
	local clamped = clampedSize(size)
	part.Size = clamped
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = size / clamped
	mesh.Parent = part
	part.Parent = parent
	return part
end

-- An invisible volume that only holds billows. It is never drawn or queried.
function Clouds.anchor(parent: Instance, name: string, size: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = clampedSize(size)
	part.Parent = parent
	return part
end

-- Billow transparency over a puff's life at a given opacity (0 hides them):
-- each puff fades in, holds and fades out, so births and deaths never pop.
function Clouds.billowTransparency(opacity: number): NumberSequence
	local function at(value: number): number
		return 1 - (1 - value) * opacity
	end
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, at(0.12)),
		NumberSequenceKeypoint.new(0.75, at(0.2)),
		NumberSequenceKeypoint.new(1, 1),
	})
end

-- A puff's colour drifts from `low` to `high` and back over its life; with
-- staggered lifetimes the puffs of one layer show both shades at once.
function Clouds.billowColor(low: Color3, high: Color3): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, low),
		ColorSequenceKeypoint.new(0.5, high),
		ColorSequenceKeypoint.new(1, low),
	})
end

export type BillowOptions = { surface: boolean?, locked: boolean?, life: { number }? }

-- Keeps about `count` soft puffs of `size` studs alive inside `part`'s
-- ellipsoid (or on its surface). Starts disabled: call Clouds.prime once the
-- part is in place, or puffs born at the origin would linger there.
function Clouds.billows(
	part: BasePart,
	low: Color3,
	high: Color3,
	size: number,
	count: number,
	options: BillowOptions?
): ParticleEmitter
	local settings = options or {}
	local life = settings.life or BILLOW_LIFE
	local sprite = math.min(size, BILLOW_MAX)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Billows"
	emitter.Texture = BILLOW_TEXTURE
	emitter.Enabled = false
	emitter.Shape = Enum.ParticleEmitterShape.Sphere
	emitter.ShapeStyle = if settings.surface
		then Enum.ParticleEmitterShapeStyle.Surface
		else Enum.ParticleEmitterShapeStyle.Volume
	emitter.Speed = NumberRange.new(0)
	emitter.Lifetime = NumberRange.new(life[1], life[2])
	emitter.Rate = count / ((life[1] + life[2]) / 2)
	-- A puff swells a little as it lives, so the surface seems to boil slowly.
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, sprite * 0.75),
		NumberSequenceKeypoint.new(1, sprite),
	})
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-5, 5)
	emitter.Color = Clouds.billowColor(low, high)
	emitter.LightInfluence = 1
	emitter.LightEmission = 0
	emitter.LockedToPart = settings.locked == true
	emitter.Transparency = Clouds.billowTransparency(1)
	emitter:SetAttribute("Billows", count)
	emitter.Parent = part
	return emitter
end

-- Starts emitting and fills half the layer at once; the rest fades in over
-- the first few seconds, so a new cloud forms rather than appears.
function Clouds.prime(emitter: ParticleEmitter)
	emitter.Enabled = true
	emitter:Emit(math.ceil((emitter:GetAttribute("Billows") or 0) * 0.5))
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
	cores: { BasePart },
	coreTransparency: { number },
	billows: { ParticleEmitter },
	flash: { BasePart },
	flashColors: { Color3 },
	flashBillows: { ParticleEmitter },
	shaft: Beam?,
	shaftOpacity: number,
	fade: number,
	target: number,
	appliedFade: number,
	placed: boolean,
	-- Seconds left until a retired cloud's last billows have faded out.
	linger: number,
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
	local orientation = CFrame.Angles(0, windYaw + rng:NextNumber(-0.4, 0.4), 0)
	local cloud: Cloud = {
		kind = kind,
		detailed = detailed,
		model = model,
		parts = {},
		frames = {},
		cores = {},
		coreTransparency = {},
		billows = {},
		flash = {},
		flashColors = {},
		flashBillows = {},
		shaft = nil,
		shaftOpacity = spec.shaft or 0,
		fade = 0,
		target = 1,
		appliedFade = -1,
		placed = false,
		linger = 0,
		flashAt = math.huge,
		flashUntil = 0,
		origin = Vector3.new(
			i * CELL + (hash(i, j, seed) - 0.5) * CELL * 0.8,
			Biomes.WaterLevel + CLOUD_BASE + spec.altitude + (hash(i, j, seed + 3) - 0.5) * 60,
			j * CELL + (hash(i, j, seed + 5) - 0.5) * CELL * 0.8
		),
		position = Vector3.zero,
	}
	local function place(part: BasePart, offset: Vector3)
		table.insert(cloud.parts, part)
		table.insert(cloud.frames, orientation * CFrame.new(offset))
	end
	local function core(color: Color3, size: Vector3, offset: Vector3): Part
		-- Rain-bearing clouds sit under an overcast sky with no sun to shade from,
		-- and shadow casters this size made the engine redraw shadows each frame.
		local part = Clouds.puff(model, color, size, false)
		part.Transparency = 1
		place(part, offset)
		table.insert(cloud.cores, part)
		table.insert(cloud.coreTransparency, 0)
		return part
	end
	local function billows(part: BasePart, layer: Layer, count: number): ParticleEmitter
		-- Far clouds keep their shape (every random draw is shared) with fewer puffs.
		local amount = if detailed then count else math.max(3, math.round(count * COARSE_BILLOWS))
		local emitter = Clouds.billows(
			part,
			spec.base:Lerp(spec.top, layer.shade[1]),
			spec.base:Lerp(spec.top, layer.shade[2]),
			width * layer.puff,
			amount,
			{ surface = layer.surface }
		)
		table.insert(cloud.billows, emitter)
		return emitter
	end
	if spec.core then
		local color = spec.base:Lerp(spec.top, spec.core.shade)
		local scale = spec.core.scale
		local part = core(
			color,
			Vector3.new(width * scale.X, height * scale.Y, width * scale.Z),
			Vector3.new(0, height * spec.core.y, 0)
		)
		if spec.lightning then
			table.insert(cloud.flash, part)
			table.insert(cloud.flashColors, color)
		end
	end
	for _, layer in spec.layers do
		local size = Vector3.new(width * layer.scale.X, height * layer.scale.Y, width * layer.scale.Z)
		local puff = math.min(BILLOW_MAX, width * layer.puff)
		local area = math.max(size.X * size.Y, size.X * size.Z)
		local cover = if spec.core then CORED_COVER else BILLOW_COVER
		local count = math.clamp(math.round(area / (puff * puff) * cover), 4, BILLOW_LIMIT)
		local offset =
			Vector3.new(rng:NextNumber(-0.06, 0.06) * width, height * layer.y, rng:NextNumber(-0.06, 0.06) * width)
		local part = Clouds.anchor(model, layer.name, size)
		place(part, offset)
		local emitter = billows(part, layer, count)
		if spec.lightning and layer.name == "Body" then
			table.insert(cloud.flashBillows, emitter)
		end
	end
	if spec.anvil then
		-- Upper winds shear the cumulonimbus top into an anvil leaning downwind.
		local spread = width * 1.95
		local anvil = core(
			spec.top:Lerp(rgb(205, 210, 220), 0.4),
			Vector3.new(spread * 1.3, height * 0.1, spread),
			Vector3.new(0, height * 1.01, -spread * 0.3)
		)
		billows(
			anvil,
			{ name = "Anvil", scale = Vector3.one, y = 1, puff = 0.3, shade = { 0.75, 1 }, surface = true },
			BILLOW_LIMIT
		)
	end
	if spec.shaft then
		local anchor = Clouds.anchor(model, "ShaftAnchor", Vector3.one)
		local drop = CLOUD_BASE + spec.altitude
		cloud.shaft = Clouds.shaft(anchor, drop, width * 0.7, spec.base:Lerp(rgb(120, 128, 140), 0.5))
		place(anchor, Vector3.new(0, height * 0.05, 0))
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

-- A solid core part (opacity > 0) or an invisible billow anchor (opacity 0).
type RainPiece = { part: Part, frame: CFrame, shade: number, opacity: number }
type RainBillows = { emitter: ParticleEmitter, shade: { number }, opacity: number }
type RainTile = {
	model: Model,
	pieces: { RainPiece },
	billows: { RainBillows },
	wisps: ParticleEmitter,
	detailed: boolean,
	fade: number,
	appliedFade: number,
	billowFade: number,
	primed: boolean,
	base: Color3?,
	top: Color3?,
	position: Vector3,
	placed: Vector3?,
}

-- Within one 8-bit step per channel.
local function similar(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) < 1 / 255 and math.abs(a.G - b.G) < 1 / 255 and math.abs(a.B - b.B) < 1 / 255
end

-- The broad opaque core guarantees coverage on every graphics level. Billows
-- hang below it, so looking up shows a lumpy, turbulent underside, and thin
-- ragged scud lower still breaks the deck's silhouette.
local function rainTile(i: number, j: number, seed: number, detailed: boolean, parent: Instance): RainTile
	local model = Instance.new("Model")
	model.Name = "RainCloudTile"
	local rng = Random.new(math.floor(hash(i, j, seed + 61) * 2147483646))
	local pieces: { RainPiece } = {}
	local billows: { RainBillows } = {}
	local function core(name: string, size: Vector3, offset: Vector3, shade: number)
		-- A shadow caster this size made the engine redraw shadows across the whole
		-- 760-stud tile whenever it changed. Rain already dims the light.
		local part = Clouds.puff(model, rgb(130, 140, 154), size, false)
		part.Name = name
		part.Transparency = 1
		table.insert(pieces, {
			part = part,
			frame = CFrame.new(offset) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0),
			shade = shade,
			opacity = 1,
		})
	end
	local function layer(
		name: string,
		size: Vector3,
		offset: Vector3,
		shade: { number },
		opacity: number,
		puff: number,
		count: number
	)
		local part = Clouds.anchor(model, name, size)
		table.insert(pieces, { part = part, frame = CFrame.new(offset), shade = 0, opacity = 0 })
		local grey = rgb(130, 140, 154)
		local emitter = Clouds.billows(part, grey, grey, puff, count, { locked = true })
		table.insert(billows, { emitter = emitter, shade = shade, opacity = opacity })
	end
	core("RainCloudBody", Vector3.new(CANOPY_WIDTH, 126, CANOPY_WIDTH), Vector3.zero, 0.16)
	core("RainCloudCrown", Vector3.new(620, 130, 570), Vector3.new(35, 65, -20), 0.8)
	layer(
		"RainCloudBillows",
		Vector3.new(680, 80, 680),
		Vector3.new(0, -48, 0),
		{ 0.08, 0.5 },
		0.95,
		BILLOW_MAX,
		if detailed then 40 else 16
	)
	layer(
		"RainCloudScud",
		Vector3.new(560, 30, 560),
		Vector3.new(0, -96, 0),
		{ 0.22, 0.58 },
		0.55,
		60,
		if detailed then 14 else 5
	)
	local anchor = Clouds.anchor(model, "CloudWispAnchor", Vector3.new(620, 1, 620))
	table.insert(pieces, { part = anchor, frame = CFrame.new(0, -88, 0), shade = 0.4, opacity = 0 })
	local wisps = Instance.new("ParticleEmitter")
	wisps.Name = "CloudWisps"
	wisps.Texture = BILLOW_TEXTURE
	wisps.Enabled = false
	wisps.Rate = if detailed then 2 else 0.5
	wisps.Lifetime = NumberRange.new(6, 10)
	wisps.Speed = NumberRange.new(2, 5)
	wisps.EmissionDirection = Enum.NormalId.Bottom
	wisps.SpreadAngle = Vector2.new(45, 45)
	wisps.LightInfluence, wisps.LightEmission = 0.3, 0.04
	wisps.Rotation, wisps.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-8, 8)
	wisps.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 64), NumberSequenceKeypoint.new(1, BILLOW_MAX) })
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
		billows = billows,
		wisps = wisps,
		detailed = detailed,
		fade = 0,
		appliedFade = -1,
		billowFade = -1,
		primed = false,
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
			-- Rewrite transparency and colour only when the fade or the storm
			-- shading actually changed; billows follow the fade in tenths.
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
				if piece.opacity == 0 then
					continue
				end
				if refade then
					piece.part.Transparency = 1 - piece.opacity * tile.fade
				end
				if reshade then
					piece.part.Color = base:Lerp(top, piece.shade)
				end
			end
			local billowFade = math.round(tile.fade * 10) / 10
			local refadeBillows = billowFade ~= tile.billowFade
			tile.billowFade = billowFade
			for _, layer in tile.billows do
				if refadeBillows then
					layer.emitter.Transparency = Clouds.billowTransparency(layer.opacity * billowFade)
				end
				if reshade then
					layer.emitter.Color =
						Clouds.billowColor(base:Lerp(top, layer.shade[1]), base:Lerp(top, layer.shade[2]))
				end
				-- Billows are locked to their anchor, so they ride along when the deck rises.
				if not tile.primed then
					Clouds.prime(layer.emitter)
				end
				layer.emitter.Enabled = request ~= nil
			end
			tile.primed = true
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
	local primed: { ParticleEmitter } = {}

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

	-- A retired cloud stops making billows; the ones alive dissolve over their
	-- remaining life while its core fades out.
	local function retire(key: string)
		local cloud = clouds[key]
		clouds[key] = nil
		cloud.target = 0
		cloud.linger = BILLOW_LIFE[2]
		for _, emitter in cloud.billows do
			emitter.Enabled = false
		end
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
		table.clear(primed)
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
				-- Billows start only once their anchors stand where the cloud is.
				if cloud.target > 0 then
					for _, emitter in cloud.billows do
						table.insert(primed, emitter)
					end
				end
			end
			local refade = math.abs(cloud.fade - cloud.appliedFade) >= FADE_STEP
				or (cloud.fade == cloud.target and cloud.appliedFade ~= cloud.fade)
			if refade then
				cloud.appliedFade = cloud.fade
				for index, part in cloud.cores do
					local transparency = cloud.coreTransparency[index]
					-- A settled core renders opaque: translucent parts must be depth-sorted every frame.
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
			if clock >= cloud.flashAt and cloud.target > 0 then
				cloud.flashAt = clock + 3 + math.random() * 9
				cloud.flashUntil = clock + 0.12
				for _, part in cloud.flash do
					part.Color = rgb(236, 232, 255)
				end
				for _, emitter in cloud.flashBillows do
					emitter.LightEmission = 0.9
				end
			elseif cloud.flashUntil > 0 and clock >= cloud.flashUntil then
				cloud.flashUntil = 0
				for index, part in cloud.flash do
					part.Color = cloud.flashColors[index]
				end
				for _, emitter in cloud.flashBillows do
					emitter.LightEmission = 0
				end
			end
		end
		for _, cloud in clouds do
			animate(cloud)
		end
		for index = #fading, 1, -1 do
			local cloud = fading[index]
			animate(cloud)
			-- Keep the model until its last billow has dissolved.
			cloud.linger -= dt
			if cloud.fade <= 0 and cloud.linger <= 0 then
				cloud.model:Destroy()
				table.remove(fading, index)
			end
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
		for _, emitter in primed do
			Clouds.prime(emitter)
		end
	end)
end

return Clouds
