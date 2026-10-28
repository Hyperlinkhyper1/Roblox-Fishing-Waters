-- The supercell and its tornadoes, drawn from the shared deterministic forecast
-- (Weather.supercell / Weather.tornadoes), so every client sees a funnel exactly
-- where the server throws boats. Client-only parts; they never affect physics.
-- Every device gets the funnels and the storm's dark rotating base; computers
-- with volumetric clouds also get the full tower, anvil and overshooting top.
--
-- Like the cloud field, the storm is soft billows (VolumetricClouds.billows)
-- around a few opaque cores: nine parts on a computer and five on a phone,
-- where it used to move close to a hundred translucent spheres every frame.
-- Billows are locked to their part, so turning the shelf turns its puffs.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Biomes = require(ReplicatedStorage.Shared.Biomes)
local Weather = require(ReplicatedStorage.Shared.Weather)
local Clouds = require(script.Parent.VolumetricClouds)

local Controller = {}
local started = false
local FUNNEL_SEGMENTS = 7
local FUNNEL_BILLOWS = 12
-- Funnel puffs live briefly, so touchdown and roping out show within a second or two.
local FUNNEL_LIFE = { 1.6, 2.6 }
local BASE_HEIGHT = 380
local WALL_HEIGHT = 270
local ROTATION_SPEED = 0.05
-- Opacity and funnel widths are rewritten in steps, not on every frame.
local OPACITY_STEP = 0.05
local WIDTH_STEP = 0.08

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

type Billow = { emitter: ParticleEmitter, opacity: number }
type Piece = { part: BasePart, offset: CFrame, transparency: number?, spins: boolean, billows: { Billow } }
type Storm = { model: Model, pieces: { Piece }, shaft: Beam, detailed: boolean, opacity: number, primed: boolean }
type Funnel = {
	model: Model,
	segments: { BasePart },
	billows: { ParticleEmitter },
	widths: { number },
	base: BasePart,
	spray: ParticleEmitter,
	debris: ParticleEmitter,
	radius: number,
	opacity: number,
}

-- Offsets are relative to the cell center on the water, with -Z pointing along
-- the storm's motion: rain falls on the forward flank, the wall cloud and its
-- tornadoes hang under the rear flank.
local function buildStorm(detailed: boolean): Storm
	local model = Instance.new("Model")
	model.Name = "Supercell"
	local pieces: { Piece } = {}
	local amount = if detailed then 1 else 0.5
	local function piece(part: BasePart, offset: Vector3, transparency: number?, spins: boolean): Piece
		part.Transparency = 1
		local entry =
			{ part = part, offset = CFrame.new(offset), transparency = transparency, spins = spins, billows = {} }
		table.insert(pieces, entry)
		return entry
	end
	local function solid(name: string, color: Color3, size: Vector3, offset: Vector3): Piece
		local part = Clouds.puff(model, color, size, false)
		part.Name = name
		return piece(part, offset, 0, false)
	end
	local function hollow(name: string, size: Vector3, offset: Vector3, spins: boolean): Piece
		return piece(Clouds.anchor(model, name, size), offset, nil, spins)
	end
	local function billows(target: Piece, low: Color3, high: Color3, size: number, count: number, surface: boolean)
		local emitter = Clouds.billows(
			target.part,
			low,
			high,
			size,
			math.max(4, math.round(count * amount)),
			{ surface = surface, locked = true }
		)
		table.insert(target.billows, { emitter = emitter, opacity = 1 })
	end
	local core = Weather.SupercellCoreRadius
	-- The flat-bottomed mesocyclone base, wrapped in a turning shell of billows:
	-- its fluffy shelf edge, and lumpy turbulence when you look up from under it.
	solid("MesocycloneBase", rgb(46, 54, 52), Vector3.new(core * 3.2, 90, core * 3.2), Vector3.new(0, BASE_HEIGHT, 0))
	local shelf = hollow("Shelf", Vector3.new(core * 3.5, 150, core * 3.5), Vector3.new(0, BASE_HEIGHT - 15, 0), true)
	billows(shelf, rgb(48, 58, 56), rgb(78, 88, 88), 100, 80, true)
	local underside =
		hollow("Underside", Vector3.new(core * 2.6, 60, core * 2.6), Vector3.new(0, BASE_HEIGHT - 55, 0), true)
	billows(underside, rgb(38, 46, 45), rgb(62, 72, 70), 100, 50, false)
	-- Matches Weather.tornadoes' mean touchdown point, so funnels hang from it.
	local wall = solid(
		"WallCloud",
		rgb(40, 48, 47),
		Vector3.new(core * 0.8, 90, core * 0.8),
		Vector3.new(core * 0.3, WALL_HEIGHT + 60, core * 0.35)
	)
	billows(wall, rgb(36, 44, 43), rgb(60, 68, 66), 90, 36, true)
	if detailed then
		-- Tower, sheared anvil and the overshooting top above the updraft.
		local lower = solid(
			"TowerLower",
			rgb(86, 94, 100),
			Vector3.new(core * 1.9, 760, core * 1.7),
			Vector3.new(0, BASE_HEIGHT + 460, 0)
		)
		billows(lower, rgb(80, 88, 96), rgb(156, 162, 170), 100, 40, true)
		local upper = solid(
			"TowerUpper",
			rgb(200, 204, 212),
			Vector3.new(core * 1.5, 760, core * 1.35),
			Vector3.new(30, BASE_HEIGHT + 1080, -40)
		)
		billows(upper, rgb(198, 202, 210), rgb(242, 244, 248), 100, 40, true)
		local anvil =
			solid("Anvil", rgb(226, 230, 236), Vector3.new(core * 7, 140, core * 5), Vector3.new(0, 1850, -core * 1.6))
		billows(anvil, rgb(214, 220, 228), rgb(246, 247, 250), 100, 50, true)
		local top = hollow("OvershootingTop", Vector3.new(core * 1.4, 320, core * 1.4), Vector3.new(0, 1960, 0), false)
		billows(top, rgb(232, 236, 240), rgb(250, 251, 253), 100, 18, false)
	end
	local anchor = hollow("ShaftAnchor", Vector3.one, Vector3.new(0, BASE_HEIGHT, -core * 0.9), false)
	local shaft = Clouds.shaft(anchor.part, BASE_HEIGHT, core * 1.6, rgb(70, 78, 82))
	model.Parent = workspace
	return { model = model, pieces = pieces, shaft = shaft, detailed = detailed, opacity = -1, primed = false }
end

local function buildFunnel(radius: number): Funnel
	local model = Instance.new("Model")
	model.Name = "Tornado"
	local segments, billows, widths = {}, {}, {}
	-- A spinning column of puffs: each segment turns, and its locked billows turn
	-- with it, so the rotation shows without any extra spiral bands.
	for index = 1, FUNNEL_SEGMENTS do
		local fraction = (index - 1) / (FUNNEL_SEGMENTS - 1)
		local part = Clouds.anchor(model, "FunnelSegment", Vector3.one)
		local color = rgb(118, 116, 108):Lerp(rgb(84, 92, 94), fraction)
		local emitter = Clouds.billows(
			part,
			color,
			color:Lerp(rgb(150, 150, 142), 0.35),
			1,
			FUNNEL_BILLOWS,
			{ locked = true, life = FUNNEL_LIFE }
		)
		table.insert(segments, part)
		table.insert(billows, emitter)
		table.insert(widths, 0)
	end
	local base = Clouds.anchor(model, "TornadoBase", Vector3.new(radius * 3, 1, radius * 3))
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
	model.Parent = workspace
	return {
		model = model,
		segments = segments,
		billows = billows,
		widths = widths,
		base = base,
		spray = spray,
		debris = debris,
		radius = radius,
		opacity = -1,
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
	local parts: { BasePart }, frames: { CFrame } = {}, {}
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
		local opacity = math.round(math.clamp(cell.strength * 1.4, 0, 1) / OPACITY_STEP) * OPACITY_STEP
		local refade = opacity ~= active.opacity
		active.opacity = opacity
		table.clear(parts)
		table.clear(frames)
		for _, piece in active.pieces do
			table.insert(parts, piece.part)
			-- The shelf turns about the updraft, carrying its billows round.
			table.insert(frames, center * (if piece.spins then spin * piece.offset else piece.offset))
			if refade then
				if piece.transparency then
					piece.part.Transparency = 1 - (1 - piece.transparency) * opacity
				end
				for _, billow in piece.billows do
					billow.emitter.Transparency = Clouds.billowTransparency(billow.opacity * opacity)
				end
			end
		end
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		if not active.primed then
			active.primed = true
			for _, piece in active.pieces do
				for _, billow in piece.billows do
					Clouds.prime(billow.emitter)
				end
			end
		end
		local dx, dz = cell.position.X - camera.CFrame.Position.X, cell.position.Z - camera.CFrame.Position.Z
		active.shaft.Enabled = dx * dx + dz * dz > (Weather.SupercellCoreRadius * 1.3) ^ 2
		if refade then
			active.shaft.Transparency = Clouds.shaftTransparency(0.75 * opacity)
		end

		local seen = {}
		for _, tornado in Weather.tornadoes(now) do
			seen[tornado.id] = true
			local funnel = funnels[tornado.id] or buildFunnel(tornado.radius)
			funnels[tornado.id] = funnel
			local strength = tornado.strength
			local ground = Vector3.new(tornado.position.X, water, tornado.position.Z)
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
			table.clear(parts)
			table.clear(frames)
			table.insert(parts, funnel.base)
			table.insert(frames, CFrame.new(ground))
			local reach = strength ^ 0.6
			for index, part in funnel.segments do
				local fraction = (index - 1) / (FUNNEL_SEGMENTS - 1)
				-- A narrow column at the sea that widens into the cloud. Touchdown
				-- grows from the top down; roping out thins it again.
				local width = funnel.radius * (0.55 + fraction ^ 2.2 * 2.6) * (0.6 + strength * 0.4)
				local emitter = funnel.billows[index]
				if math.abs(width - funnel.widths[index]) > width * WIDTH_STEP then
					funnel.widths[index] = width
					part.Size = Vector3.new(width * 0.7, WALL_HEIGHT / FUNNEL_SEGMENTS * 1.4, width * 0.7)
					local sprite = math.min(width * 0.8, 100)
					emitter.Size = NumberSequence.new({
						NumberSequenceKeypoint.new(0, sprite * 0.8),
						NumberSequenceKeypoint.new(1, sprite),
					})
				end
				emitter.Enabled = fraction >= 1 - reach
				table.insert(parts, part)
				table.insert(frames, CFrame.new(axis(fraction)) * CFrame.Angles(0, now * 3 + index, 0))
			end
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
			local level = math.round((0.4 + strength * 0.6) / OPACITY_STEP) * OPACITY_STEP
			if level ~= funnel.opacity then
				funnel.opacity = level
				local transparency = Clouds.billowTransparency(level)
				for _, emitter in funnel.billows do
					emitter.Transparency = transparency
				end
			end
			local touching = reach > 0.95
			funnel.spray.Rate = if touching then 40 * strength else 0
			funnel.debris.Rate = if touching then 24 * strength else 0
		end
		clearFunnels(seen)
	end)
end

return Controller
