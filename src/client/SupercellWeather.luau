-- The supercell and its tornadoes, drawn from the shared deterministic forecast
-- (Weather.supercell / Weather.tornadoes), so every client sees a funnel exactly
-- where the server throws boats. Client-only parts; they never affect physics.
-- Every device gets the funnels and the storm's dark rotating base; computers
-- with volumetric clouds also get the full tower, anvil and overshooting top.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Biomes = require(ReplicatedStorage.Shared.Biomes)
local Weather = require(ReplicatedStorage.Shared.Weather)
local Clouds = require(script.Parent.VolumetricClouds)

local Controller = {}
local started = false
local TAU = math.pi * 2
local FUNNEL_SEGMENTS = 14
local SPIRAL_POINTS = 16
local BASE_HEIGHT = 380
local WALL_HEIGHT = 270
local ROTATION_SPEED = 0.05

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

type Piece = { part: BasePart, offset: CFrame, transparency: number, spins: boolean }
type Storm = { model: Model, pieces: { Piece }, shaft: Beam, detailed: boolean }
type Funnel = {
	model: Model,
	segments: { BasePart },
	base: BasePart,
	spray: ParticleEmitter,
	debris: ParticleEmitter,
	spirals: { { Attachment } },
	beams: { Beam },
	radius: number,
}

local function invisible(name: string, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.Parent = parent
	return part
end

-- Offsets are relative to the cell center on the water, with -Z pointing along
-- the storm's motion: rain falls on the forward flank, the wall cloud and its
-- tornadoes hang under the rear flank.
local function buildStorm(detailed: boolean): Storm
	local model = Instance.new("Model")
	model.Name = "Supercell"
	local pieces: { Piece } = {}
	local rng = Random.new(9047)
	local function add(color: Color3, size: Vector3, offset: Vector3, transparency: number, spins: boolean)
		local part = Clouds.puff(model, color, size, detailed)
		part.Transparency = 1
		table.insert(pieces, { part = part, offset = CFrame.new(offset), transparency = transparency, spins = spins })
		if detailed then
			for index = 1, 3 do
				local angle = index / 3 * TAU + rng:NextNumber(-0.5, 0.5)
				local lobe = Clouds.puff(
					model,
					color:Lerp(rgb(244, 246, 250), rng:NextNumber(0.02, 0.12)),
					size * rng:NextNumber(0.3, 0.5),
					false
				)
				lobe.Transparency = 1
				table.insert(pieces, {
					part = lobe,
					offset = CFrame.new(offset + Vector3.new(math.cos(angle), 0.35, math.sin(angle)) * size * 0.4),
					transparency = transparency,
					spins = spins,
				})
			end
		end
	end
	local core = Weather.SupercellCoreRadius
	-- The rotating, flat-bottomed mesocyclone base with a lowered wall cloud.
	add(rgb(46, 54, 52), Vector3.new(core * 3.2, 90, core * 3.2), Vector3.new(0, BASE_HEIGHT, 0), 0.04, false)
	for index = 1, if detailed then 12 else 6 do
		local angle = index / (if detailed then 12 else 6) * TAU
		local radius = core * (1.05 + (index % 3) * 0.12)
		add(
			rgb(52, 62, 60),
			Vector3.new(core * 0.9, 110, core * 0.6),
			Vector3.new(math.cos(angle) * radius, BASE_HEIGHT - 20, math.sin(angle) * radius),
			0.12,
			true
		)
	end
	-- Matches Weather.tornadoes' mean touchdown point, so funnels hang from it.
	add(
		rgb(40, 48, 47),
		Vector3.new(core * 1.1, 120, core * 1.1),
		Vector3.new(core * 0.3, WALL_HEIGHT + 60, core * 0.35),
		0.03,
		false
	)
	if detailed then
		-- Tower, sheared anvil and the overshooting top above the updraft.
		for index = 1, 7 do
			local fraction = index / 7
			local width = core * (2.3 - fraction * 0.9)
			add(
				rgb(70, 78, 84):Lerp(rgb(236, 238, 242), fraction),
				Vector3.new(width, 320, width * 0.9),
				Vector3.new(math.sin(index * 1.7) * 60, BASE_HEIGHT + 80 + fraction * 1300, math.cos(index * 1.3) * 60),
				0.05,
				false
			)
		end
		add(rgb(226, 230, 236), Vector3.new(core * 7, 140, core * 5), Vector3.new(0, 1850, -core * 1.6), 0.1, false)
		add(rgb(214, 220, 228), Vector3.new(core * 5, 90, core * 3.6), Vector3.new(0, 1770, -core * 1.2), 0.22, false)
		add(rgb(242, 244, 248), Vector3.new(core * 1.4, 320, core * 1.4), Vector3.new(0, 1960, 0), 0.08, false)
	end
	local anchor = invisible("ShaftAnchor", model)
	table.insert(
		pieces,
		{ part = anchor, offset = CFrame.new(0, BASE_HEIGHT, -core * 0.9), transparency = 1, spins = false }
	)
	local shaft = Clouds.shaft(anchor, BASE_HEIGHT, core * 1.6, rgb(70, 78, 82))
	model.Parent = workspace
	return { model = model, pieces = pieces, shaft = shaft, detailed = detailed }
end

local function buildFunnel(radius: number): Funnel
	local model = Instance.new("Model")
	model.Name = "Tornado"
	local segments = {}
	for index = 1, FUNNEL_SEGMENTS do
		local fraction = (index - 1) / (FUNNEL_SEGMENTS - 1)
		local part = Clouds.puff(model, rgb(118, 116, 108):Lerp(rgb(84, 92, 94), fraction), Vector3.one, false)
		part.Name = "FunnelSegment"
		table.insert(segments, part)
	end
	local base = invisible("TornadoBase", model)
	base.Size = Vector3.new(radius * 3, 1, radius * 3)
	-- Sea spray thrown out in a ring where the vortex meets the water.
	local spray = Instance.new("ParticleEmitter")
	spray.Name = "Spray"
	spray.Texture = "rbxasset://textures/particles/smoke_main.dds"
	spray.Shape = Enum.ParticleEmitterShape.Disc
	spray.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Color = ColorSequence.new(rgb(214, 224, 228))
	spray.LightInfluence = 1
	spray.Lifetime = NumberRange.new(1.6, 2.6)
	spray.Speed = NumberRange.new(18, 34)
	spray.SpreadAngle = Vector2.new(35, 35)
	spray.Acceleration = Vector3.new(0, 6, 0)
	spray.Drag = 1.2
	spray.Rotation = NumberRange.new(0, 360)
	spray.RotSpeed = NumberRange.new(-260, 260)
	spray.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 10), NumberSequenceKeypoint.new(1, 34) })
	spray.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	spray.Parent = base
	local debris = Instance.new("ParticleEmitter")
	debris.Name = "Debris"
	debris.Shape = Enum.ParticleEmitterShape.Disc
	debris.EmissionDirection = Enum.NormalId.Top
	debris.Color = ColorSequence.new(rgb(58, 52, 44))
	debris.LightInfluence = 1
	debris.Lifetime = NumberRange.new(1.5, 3)
	debris.Speed = NumberRange.new(30, 60)
	debris.SpreadAngle = Vector2.new(50, 50)
	debris.Acceleration = Vector3.new(0, -30, 0)
	debris.Rotation = NumberRange.new(0, 360)
	debris.RotSpeed = NumberRange.new(-400, 400)
	debris.Size = NumberSequence.new(1.6)
	debris.Parent = base
	-- Bands of condensation wound around the funnel show its rotation.
	local spirals, beams = {}, {}
	for arm = 1, 3 do
		local points = {}
		for index = 1, SPIRAL_POINTS do
			local point = Instance.new("Attachment")
			point.Name = "SpiralPoint" .. index
			point.Parent = base
			table.insert(points, point)
			if index > 1 then
				local beam = Instance.new("Beam")
				beam.Name = "SpiralBand"
				beam.Attachment0, beam.Attachment1 = points[index - 1], point
				beam.Color = ColorSequence.new(rgb(150, 150, 142))
				beam.LightInfluence = 1
				beam.FaceCamera = true
				beam.Segments = 1
				local width = radius * (0.35 + index / SPIRAL_POINTS * 0.9)
				beam.Width0, beam.Width1 = width, width
				beam.Parent = base
				table.insert(beams, beam)
			end
		end
		spirals[arm] = points
	end
	model.Parent = workspace
	return {
		model = model,
		segments = segments,
		base = base,
		spray = spray,
		debris = debris,
		spirals = spirals,
		beams = beams,
		radius = radius,
	}
end

function Controller.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local storm: Storm? = nil
	local funnels: { [number]: Funnel } = {}
	local function clearStorm()
		if storm then
			storm.model:Destroy()
			storm = nil
		end
	end
	local function clearFunnels(keep: { [number]: boolean }?)
		for id, funnel in funnels do
			if not keep or not keep[id] then
				funnel.model:Destroy()
				funnels[id] = nil
			end
		end
	end
	RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()
		local cell = Weather.supercell(now)
		local camera = workspace.CurrentCamera
		if not cell or not camera or player:GetAttribute("WeatherEffectsEnabled") == false then
			clearStorm()
			clearFunnels()
			return
		end
		local water = Biomes.WaterLevel
		local detailed = player:GetAttribute("VolumetricCloudsEnabled") == true
		if storm and storm.detailed ~= detailed then
			clearStorm()
		end
		local active = storm or buildStorm(detailed)
		storm = active
		local speed = math.sqrt(cell.motion.X ^ 2 + cell.motion.Z ^ 2)
		local heading = if speed > 0.01
			then CFrame.lookAt(Vector3.zero, Vector3.new(cell.motion.X, 0, cell.motion.Z))
			else CFrame.identity
		local center = CFrame.new(cell.position.X, water, cell.position.Z) * heading
		local spin = CFrame.Angles(0, now * ROTATION_SPEED, 0)
		local parts, frames = {}, {}
		local opacity = math.clamp(cell.strength * 1.4, 0, 1)
		for _, piece in active.pieces do
			table.insert(parts, piece.part)
			local offset = piece.offset
			if piece.spins then
				-- Rotate about the updraft rather than each puff's own center.
				offset = spin * offset
			end
			table.insert(frames, center * offset)
			if piece.transparency < 1 then
				piece.part.Transparency = 1 - (1 - piece.transparency) * opacity
			end
		end
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		local dx, dz = cell.position.X - camera.CFrame.Position.X, cell.position.Z - camera.CFrame.Position.Z
		active.shaft.Enabled = dx * dx + dz * dz > (Weather.SupercellCoreRadius * 1.3) ^ 2
		active.shaft.Transparency = Clouds.shaftTransparency(0.75 * opacity)

		local seen = {}
		for _, tornado in Weather.tornadoes(now) do
			seen[tornado.id] = true
			local funnel = funnels[tornado.id] or buildFunnel(tornado.radius)
			funnels[tornado.id] = funnel
			local strength = tornado.strength
			local ground = Vector3.new(tornado.position.X, water, tornado.position.Z)
			funnel.base.CFrame = CFrame.new(ground)
			-- Rope-like sway: the funnel bends between the ground and the wall cloud.
			local phase = tornado.age * 0.9 + tornado.id
			local function axis(fraction: number): Vector3
				local bend = math.sin(fraction * math.pi) * funnel.radius * 1.6
				return ground
					+ Vector3.new(
						math.cos(phase + fraction * 2) * bend,
						fraction * (WALL_HEIGHT + 20),
						math.sin(phase * 0.8 + fraction * 2.4) * bend
					)
			end
			local segmentParts, segmentFrames = {}, {}
			local reach = strength ^ 0.6
			for index, part in funnel.segments do
				local fraction = (index - 1) / (FUNNEL_SEGMENTS - 1)
				-- A narrow column at the sea that widens into the cloud. Touchdown
				-- grows from the top down; roping out thins it again.
				local visible = fraction >= 1 - reach
				local width = funnel.radius * (0.55 + fraction ^ 2.2 * 2.6) * (0.6 + strength * 0.4)
				part.Size = Vector3.new(width, WALL_HEIGHT / FUNNEL_SEGMENTS * 1.9, width)
				part.Transparency = if visible then 0.18 + (1 - strength) * 0.5 + fraction * 0.1 else 1
				table.insert(segmentParts, part)
				table.insert(segmentFrames, CFrame.new(axis(fraction)) * CFrame.Angles(0, now * 3 + index, 0))
			end
			workspace:BulkMoveTo(segmentParts, segmentFrames, Enum.BulkMoveMode.FireCFrameChanged)
			local touching = reach > 0.95
			funnel.spray.Rate = if touching then 40 * strength else 0
			funnel.debris.Rate = if touching then 24 * strength else 0
			for arm, points in funnel.spirals do
				for index, point in points do
					local fraction = (index - 1) / (SPIRAL_POINTS - 1)
					local width = funnel.radius * (0.55 + fraction ^ 2.2 * 2.6) * 0.5 + 2
					local turn = arm * TAU / 3 + fraction * TAU * 1.5 + now * 2.6
					point.WorldPosition = axis(fraction)
						+ Vector3.new(math.cos(turn) * width, 0, math.sin(turn) * width)
				end
			end
			for _, beam in funnel.beams do
				beam.Transparency = NumberSequence.new(if reach > 0.5 then 0.55 + (1 - strength) * 0.4 else 1)
			end
		end
		clearFunnels(seen)
	end)
end

return Controller
