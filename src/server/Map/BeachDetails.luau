-- Small, walk-through details that follow the beach mesh rather than a flat sand plane.
local Props = require(script.Parent.Props)

local BeachDetails = {}

local rgb = Color3.fromRGB
local M = Enum.Material
local TAU = math.pi * 2
local GRASSES = { rgb(144, 151, 89), rgb(165, 165, 102), rgb(128, 142, 82) }
local PEBBLES = { rgb(181, 174, 156), rgb(153, 149, 135), rgb(205, 194, 171) }
local TOYS = { rgb(214, 86, 65), rgb(50, 143, 163), rgb(232, 183, 70) }

type Frame = (number) -> (Vector2, Vector2)
type Surface = (Vector2, number?) -> Vector3

local function detail(p: Part): Part
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	return p
end

local function newModel(name: string, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

local function openCorridor(along: number, length: number, margin: number): boolean
	return math.abs(along - length * 0.3) > 10 + margin
		and math.abs(along - length * 0.66) > 10 + margin
		and math.abs(along - length * 0.5) > 12 + margin
end

local function grassTuft(parent: Instance, at: Vector2, surface: Surface, rng: Random)
	local model = newModel("MarramGrass", parent)
	local color = Props.pick(rng, GRASSES)
	local spin = rng:NextNumber(0, TAU)
	for blade = 1, rng:NextInteger(4, 6) do
		local angle = spin + blade * 2.4
		local spread = Vector2.new(math.cos(angle), math.sin(angle))
		local base = surface(at + spread * rng:NextNumber(0.1, 0.5), -0.08)
		local height = rng:NextNumber(1.1, 2.3)
		local tip = base + Vector3.new(spread.X * 0.6, height, spread.Y * 0.6)
		detail(Props.beam(model, base, tip, rng:NextNumber(0.1, 0.17), Props.shade(color, rng, 0.07), 0.08, M.Grass))
		if blade <= 2 then
			local seed = tip + Vector3.new(spread.X * 0.1, 0.24, spread.Y * 0.1)
			detail(Props.beam(model, tip, seed, 0.12, rgb(186, 177, 126), 0.12, M.Grass))
		end
	end
end

local function pebbleCluster(parent: Instance, at: Vector2, surface: Surface, rng: Random)
	local model = newModel("BeachPebbles", parent)
	for _ = 1, rng:NextInteger(4, 6) do
		local angle = rng:NextNumber(0, TAU)
		local offset = Vector2.new(math.cos(angle), math.sin(angle)) * rng:NextNumber(0.2, 2.1)
		local size = rng:NextNumber(0.4, 1)
		local height = size * rng:NextNumber(0.35, 0.55)
		local pebble = detail(
			Props.part(
				model,
				Vector3.new(size, height, size * rng:NextNumber(0.7, 1.2)),
				CFrame.new(surface(at + offset, height * 0.34)) * CFrame.Angles(0, angle, 0),
				Props.shade(Props.pick(rng, PEBBLES), rng, 0.05),
				M.Pebble
			)
		)
		pebble.Shape = Enum.PartType.Ball
	end
end

local function bucketAndSpade(parent: Instance, at: Vector2, surface: Surface, facing: number, color: Color3)
	local model = newModel("BucketAndSpade", parent)
	local base = CFrame.new(surface(at, 0.03)) * CFrame.Angles(0, facing, 0)
	-- Open octagonal bucket: the inset sand remains clearly below the rim.
	detail(Props.cylinder(model, base * Vector3.new(0, 0.12, 0), 0.18, 1.3, color, M.SmoothPlastic))
	for side = 0, 7 do
		local angle = side / 8 * TAU
		detail(
			Props.part(
				model,
				Vector3.new(0.57, 1.05, 0.12),
				base * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0.68, 0.65),
				color,
				M.SmoothPlastic
			)
		)
	end
	detail(Props.cylinder(model, base * Vector3.new(0, 0.3, 0), 0.15, 1.08, rgb(221, 203, 162), M.Sand))
	local handle = rgb(239, 228, 203)
	local previous = base * Vector3.new(-0.67, 1, 0)
	for segment = 1, 5 do
		local angle = math.pi - segment / 5 * math.pi
		local nextPoint = base * Vector3.new(math.cos(angle) * 0.67, 1 + math.sin(angle) * 0.6, 0)
		detail(Props.beam(model, previous, nextPoint, 0.11, handle, 0.11, M.SmoothPlastic))
		previous = nextPoint
	end

	-- A spade resting next to the bucket, sampled separately so it follows the local sand height.
	local side = Vector2.new(math.cos(facing), -math.sin(facing))
	local spade = CFrame.new(surface(at + side * 1.45, 0.14)) * CFrame.Angles(0, facing + 0.35, 0)
	detail(Props.part(model, Vector3.new(0.14, 0.15, 1.3), spade, handle, M.SmoothPlastic))
	detail(Props.part(model, Vector3.new(0.64, 0.18, 0.75), spade * CFrame.new(0, 0, -0.95), color, M.SmoothPlastic))
	detail(Props.part(model, Vector3.new(0.5, 0.17, 0.16), spade * CFrame.new(0, 0, 0.72), color, M.SmoothPlastic))
end

function BeachDetails.build(parent: Instance, rng: Random, length: number, frame: Frame, surface: Surface)
	local model = newModel("BeachDetails", parent)
	local function point(along: number, depth: number): (Vector2, Vector2)
		local waterline, inland = frame(along)
		return waterline + inland * depth, inland
	end

	-- Staggered small patches break up the dune edge without filling the walking routes.
	local count = math.clamp(math.floor(length / 18), 8, 26)
	for index = 1, count do
		local along = length * (0.1 + 0.8 * (index - 0.5) / count) + rng:NextNumber(-4, 4)
		local inCabana = false
		for _, start in { length * 0.22, length * 0.36 } do
			inCabana = inCabana or (along > start - 6 and along < start + 30)
		end
		if openCorridor(along, length, 2) and not inCabana then
			local at = point(along, rng:NextNumber(38, 43))
			grassTuft(model, at, surface, rng)
		end
	end

	-- Rounded pebbles collect toward the rocky shoulders, leaving the central bathing sand clear.
	for _, fraction in { 0.1, 0.15, 0.84, 0.89, 0.93 } do
		local along = length * fraction + rng:NextNumber(-4, 4)
		if openCorridor(along, length, 3) then
			local at = point(along, rng:NextNumber(4, 12))
			pebbleCluster(model, at, surface, rng)
		end
	end

	for index, fraction in { 0.19, 0.88 } do
		local along = length * fraction
		if openCorridor(along, length, 3) then
			local at, inland = point(along, 14 + index * 2)
			local facing = math.atan2(-inland.X, -inland.Y) + 0.25
			bucketAndSpade(model, at, surface, facing, TOYS[index])
		end
	end
end

return BeachDetails
