-- Every rainy player gets an overlapping volumetric cloud deck overhead.
-- Soft billowed cloud building blocks for the supercell (SupercellWeather) and
-- the rain deck that hangs under it. The rest of the sky is Terrain.Clouds and
-- the Atmosphere (BiomeAtmosphere): the old distant cloud field of particle
-- billows cost too much frame time and is gone.
--
-- Clouds are soft billows, not solid shapes: a few invisible anchor parts per
-- cloud each carry a particle emitter that keeps a set of camera-facing puffs
-- alive inside its volume. Only the big rain-bearing pieces keep an opaque core,
-- so rain never shows sky through gaps between puffs.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Biomes = require(ReplicatedStorage.Shared.Biomes)
local Weather = require(ReplicatedStorage.Shared.Weather)

local Clouds = {}
local started = false
local TAU = math.pi * 2
local FADE_SECONDS = 4
local MAX_PART_SIZE = 2048
local CANOPY_CELL = 360
local CANOPY_WIDTH = 760
local CANOPY_HEIGHT = 300
local CANOPY_LIMIT = 36
-- The deck only hangs where the supercell covers the sky at least this much.
local CANOPY_SUPERCELL = 0.05
local BILLOW_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
-- Particle sprites stay at or under 100 studs; bigger clouds use more of them.
local BILLOW_MAX = 100
-- Each billow lives this long, so a cloud slowly churns as old puffs fade out
-- and new ones fade in, and a retired cloud dissolves instead of popping.
local BILLOW_LIFE = { 10, 16 }

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- Same integer mixing as Weather: tile layouts must not shimmer between frames.
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
		if detailed then 24 else 10
	)
	layer(
		"RainCloudScud",
		Vector3.new(560, 30, 560),
		Vector3.new(0, -96, 0),
		{ 0.22, 0.58 },
		0.55,
		60,
		if detailed then 8 else 3
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
	-- Entering the supercell rain or teleporting under it gets coverage in the
	-- same rendered frame. Low graphics reduce detail, never remove the deck.
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
			-- Ordinary rain is Terrain.Clouds at full cover; only the supercell
			-- keeps a volumetric deck overhead.
			local cover = Weather.supercellCover(focus, state.supercell)
			if cover < CANOPY_SUPERCELL then
				continue
			end
			local rain, storm = Weather.localConditions(focus, state)
			if rain <= 0.01 then
				continue
			end
			severity = math.max(severity, storm, rain * 0.65)
			green = math.max(green, cover)
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
	startRainCanopy(Players.LocalPlayer)
end

return Clouds
