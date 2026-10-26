-- Static marine life built from the same textured, low-poly parts as the islands.
local Props = require(script.Parent.Props)
local LowPoly = require(script.Parent.LowPoly)

local SeabedLife = {}
local TAU = math.pi * 2
local M = Enum.Material
local rgb = Color3.fromRGB

local function model(name: string, parent: Instance): Model
	local result = Instance.new("Model")
	result.Name = name
	result.Parent = parent
	return result
end

-- Short, splayed leaves make soft meadows between the taller rock gardens.
function SeabedLife.grass(parent: Instance, ground: Vector3, rng: Random, color: Color3)
	local meadow = model("Seagrass", parent)
	local spin = rng:NextNumber(0, TAU)
	for clump = 1, 3 do
		local angle = spin + clump / 3 * TAU
		local base = ground + Vector3.new(math.cos(angle) * 0.7, -0.15, math.sin(angle) * 0.7)
		for blade = 1, 3 do
			local facing = angle + blade * 2.4
			local lean = Vector3.new(math.cos(facing), 0, math.sin(facing))
			local tip = base + lean * rng:NextNumber(0.5, 1.1) + Vector3.yAxis * rng:NextNumber(1.2, 2.7)
			Props.beam(meadow, base, tip, 0.16, Props.shade(color, rng, 0.2), 0.07, M.Grass)
		end
	end
end

-- Broad alternating fronds on bent stalks. Depth caps keep the tips submerged.
function SeabedLife.kelp(parent: Instance, ground: Vector3, rng: Random, color: Color3, waterLevel: number)
	local kelp = model("Kelp", parent)
	local spin = rng:NextNumber(0, TAU)
	local height = math.min(rng:NextNumber(8, 14), waterLevel - ground.Y - 3)
	for stalk = 1, 2 do
		local angle = spin + stalk * 2.4
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local base = ground + direction * 0.7 - Vector3.yAxis * 0.25
		local previous = base
		local tint = Props.shade(color, rng, 0.15)
		for step = 1, 4 do
			local t = step / 4
			local tip = base + Vector3.yAxis * height * t + direction * (math.sin(t * 2.3) * 1.4)
			Props.beam(kelp, previous, tip, 0.16, tint, nil, M.Grass)
			local side = Vector3.new(-direction.Z, 0, direction.X) * (if step % 2 == 0 then 1 else -1)
			local endPoint = tip + side * (1.8 - t * 0.6) + direction * 0.35 + Vector3.yAxis * 0.5
			Props.beam(kelp, tip, endPoint, 0.55 * (1 - t * 0.35), tint, 0.09, M.Grass)
			previous = tip
		end
	end
end

-- Flat, spreading fans contrast with the existing upright branching coral.
function SeabedLife.fan(parent: Instance, ground: Vector3, rng: Random, colors: { Color3 })
	local fan = model("SeaFan", parent)
	local color = Props.pick(rng, colors)
	local angle = rng:NextNumber(0, TAU)
	local side = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local base = ground - Vector3.yAxis * 0.15
	local hub = base + Vector3.yAxis * 0.9
	Props.beam(fan, base, hub, 0.28, color, nil, M.Pebble)
	for branch = -2, 2 do
		local elbow = hub + side * branch * 0.7 + Vector3.yAxis * (1.2 - math.abs(branch) * 0.2)
		local tip = elbow + side * branch * 0.2 + Vector3.yAxis * rng:NextNumber(0.6, 1.2)
		Props.beam(fan, hub, elbow, 0.2, color, nil, M.Pebble)
		Props.beam(fan, elbow, tip, 0.12, color, nil, M.Pebble)
		Props.beam(fan, elbow, tip + side * 0.5 - Vector3.yAxis * 0.2, 0.1, color, nil, M.Pebble)
	end
end

function SeabedLife.sponges(parent: Instance, ground: Vector3, rng: Random, colors: { Color3 })
	local sponges = model("TubeSponges", parent)
	local color = Props.pick(rng, colors)
	for tube = 1, 3 do
		local angle = tube / 3 * TAU
		local height = rng:NextNumber(1.1, 2.8)
		local width = rng:NextNumber(0.65, 1.1)
		local base = ground + Vector3.new(math.cos(angle) * 0.6, -0.15, math.sin(angle) * 0.6)
		Props.cylinder(sponges, base + Vector3.yAxis * height / 2, height, width, color, M.Pebble)
		-- Dark inset mouths read as openings without transparent or hollow meshes.
		Props.cylinder(
			sponges,
			base + Vector3.yAxis * (height + 0.01),
			0.04,
			width * 0.65,
			color:Lerp(rgb(25, 32, 36), 0.7),
			M.SmoothPlastic
		)
	end
end

-- A local surface frame keeps small bottom dwellers seated on sloping ground.
local function surfaceFrame(ground: Vector3, normal: Vector3, spin: number): CFrame
	local right = normal:Cross(Vector3.zAxis).Unit
	return CFrame.fromMatrix(ground + normal * 0.05, right, normal, right:Cross(normal)) * CFrame.Angles(0, spin, 0)
end

function SeabedLife.starfish(parent: Instance, ground: Vector3, normal: Vector3, rng: Random)
	local star = model("Starfish", parent)
	local color = Props.pick(rng, { rgb(215, 133, 80), rgb(193, 101, 75), rgb(212, 176, 114) })
	local frame = surfaceFrame(ground, normal, rng:NextNumber(0, TAU))
	local size = rng:NextNumber(0.7, 1.25)
	local center = frame * Vector3.new(0, 0.15, 0)
	local body = Props.ball(star, center, size * 0.65, color, M.Sand)
	body.Size = Vector3.new(size * 0.65, 0.22, size * 0.65)
	body.CFrame = frame * CFrame.new(0, 0.15, 0)
	for arm = 1, 5 do
		local angle = arm / 5 * TAU
		local tip = frame * Vector3.new(math.cos(angle) * size, 0, math.sin(angle) * size)
		local left = frame * Vector3.new(math.cos(angle - 0.5) * size * 0.32, 0, math.sin(angle - 0.5) * size * 0.32)
		local right = frame * Vector3.new(math.cos(angle + 0.5) * size * 0.32, 0, math.sin(angle + 0.5) * size * 0.32)
		LowPoly.triangle(left, tip, right, ground - normal, color, star, M.Sand, 0.1)
	end
end

function SeabedLife.shells(parent: Instance, ground: Vector3, normal: Vector3, rng: Random)
	local shells = model("Seashells", parent)
	local color = Props.pick(rng, { rgb(231, 219, 193), rgb(213, 182, 160), rgb(185, 174, 155) })
	local frame = surfaceFrame(ground, normal, rng:NextNumber(0, TAU))
	local size = rng:NextNumber(0.6, 1)
	local hinge = frame * Vector3.new(0, 0, -size * 0.45)
	for rib = 0, 5 do
		local a, b = rib / 6 * math.pi, (rib + 1) / 6 * math.pi
		local left = frame * Vector3.new(math.cos(a) * size, math.sin(a) * size * 0.28, math.sin(a) * size)
		local right = frame * Vector3.new(math.cos(b) * size, math.sin(b) * size * 0.28, math.sin(b) * size)
		LowPoly.triangle(hinge, left, right, ground - normal, Props.shade(color, rng, 0.07), shells, M.Limestone, 0.08)
	end
end

return SeabedLife
