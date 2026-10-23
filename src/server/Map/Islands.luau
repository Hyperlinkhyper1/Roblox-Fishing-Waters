-- Faceted islands built as radial heightmaps: a center fan plus rings of quads,
-- each face coloured by its height and slope (shore, cliff or top).

local LowPoly = require(script.Parent.LowPoly)
local Seabed = require(script.Parent.Seabed)

local Islands = {}

export type Materials = { top: Enum.Material, cliff: Enum.Material, shore: Enum.Material }
export type Palette = { top: Color3, cliff: Color3, shore: Color3, materials: Materials? }

local DEFAULT_MATERIALS: Materials =
	{ top = Enum.Material.Grass, cliff = Enum.Material.Rock, shore = Enum.Material.Sand }

export type Spec = {
	position: Vector2,
	radius: number,
	height: number,
	shape: string,
	palette: Palette,
	rng: Random,
	shoreLine: number?, -- faces below this height use the shore colour
	elongation: number?,
	roughness: number?,
	seaFloor: number?, -- local biome bed; defaults to the deep sea floor
}

local TAU = math.pi * 2

-- {t, h}: t runs from 0 at the center to the outermost stop, h is a fraction of the island height.
-- Past the last stop, Seabed.slope continues the surface into the local sea floor.
local PROFILES: { [string]: { { number } } } = {
	plateau = { { 0, 1 }, { 0.45, 0.92 }, { 0.7, 0.2 }, { 0.86, 0.04 } },
	peak = { { 0, 1 }, { 0.3, 0.7 }, { 0.65, 0.22 }, { 0.86, 0.04 } },
	stack = { { 0, 1 }, { 0.55, 0.95 }, { 0.78, 0.15 }, { 0.9, 0.02 } },
	mound = { { 0, 1 }, { 0.5, 0.75 }, { 0.85, 0.15 } },
	berg = { { 0, 1 }, { 0.65, 0.97 }, { 0.78, 0.3 }, { 0.9, 0.05 } },
	volcano = { { 0, 0.42 }, { 0.14, 0.45 }, { 0.24, 1 }, { 0.5, 0.55 }, { 0.8, 0.08 }, { 0.9, 0.02 } },
	atoll = { { 0, -0.9 }, { 0.5, -0.6 }, { 0.66, 0.5 }, { 0.76, 1 }, { 0.86, 0.3 } },
}

local function profileHeight(points: { { number } }, t: number, height: number): number
	local last = points[#points]
	if t >= last[1] then
		return last[2] * height
	end
	for i = 1, #points - 1 do
		local p, q = points[i], points[i + 1]
		if t <= q[1] then
			local alpha = (t - p[1]) / (q[1] - p[1])
			return (p[2] + (q[2] - p[2]) * alpha) * height
		end
	end
	return last[2] * height
end

-- Rings land exactly on the profile's breakpoints so cliffs stay sharp; big islands get extra rings between them.
local function ringStops(points: { { number } }, radius: number): { number }
	local stops = {}
	for i = 2, #points do
		table.insert(stops, points[i][1])
	end
	if radius <= 90 then
		return stops
	end

	local step = if radius > 250 then 0.15 else 0.25
	local dense = {}
	local prev = 0
	for _, t in stops do
		local gap = t - prev
		local extra = math.floor(gap / step)
		for k = 1, extra do
			table.insert(dense, prev + gap * k / (extra + 1))
		end
		table.insert(dense, t)
		prev = t
	end
	return dense
end

function Islands.build(spec: Spec): Model
	local rng = spec.rng
	local points = PROFILES[spec.shape]
	assert(points, `Unknown island shape {spec.shape}`)

	local radius, height = spec.radius, spec.height
	local cx, cz = spec.position.X, spec.position.Y
	local palette = spec.palette
	local shoreLine = spec.shoreLine or 2.2
	local elongation = spec.elongation or rng:NextNumber(0, 0.3)
	local roughness = spec.roughness or 0.4
	local jitter = math.min(height * 0.05, 4)
	local spin = rng:NextNumber(0, TAU)
	local ox, oy, oz = rng:NextNumber(-500, 500), rng:NextNumber(-500, 500), rng:NextNumber(-500, 500)

	local model = Instance.new("Model")
	model.Name = "Island"
	model:SetAttribute("Radius", radius)
	model:SetAttribute("Height", height)
	local ground = Instance.new("Model")
	ground.Name = "Ground"
	ground.Parent = model

	local stops = ringStops(points, radius)
	local segments = math.clamp(math.floor(radius / 12) + 6, 6, 28)
	local center = Vector3.new(cx, profileHeight(points, 0, height) + rng:NextNumber(-jitter, jitter), cz)

	local rings = {}
	for i, t in stops do
		local ring = {}
		for j = 1, segments do
			local angle = (j - 1 + rng:NextNumber(-0.2, 0.2)) / segments * TAU
			local noise = math.noise(math.cos(angle) * 1.3 + ox, math.sin(angle) * 1.3 + oy, oz)
			local shape = 1 + roughness * 2 * noise + elongation * math.cos(2 * (angle - spin))
			local r = radius * t * shape * rng:NextNumber(0.95, 1.05)
			local y = profileHeight(points, t, height)
			y += rng:NextNumber(-jitter, jitter)
			ring[j] = Vector3.new(cx + math.cos(angle) * r, y, cz + math.sin(angle) * r)
		end
		rings[i] = ring
	end

	local inside = Vector3.new(cx, math.min(center.Y, 0) - radius, cz)

	local materials = palette.materials or DEFAULT_MATERIALS
	local function face(a: Vector3, b: Vector3, c: Vector3)
		local normal = (b - a):Cross(c - a).Unit
		local y = (a.Y + b.Y + c.Y) / 3
		local role = if y < 0
			then "shore"
			elseif math.abs(normal.Y) < 0.7 then "cliff"
			elseif y < shoreLine then "shore"
			else "top"
		local color = (palette :: any)[role]
		local shade = rng:NextNumber(0.93, 1.04)
		color = Color3.new(math.min(color.R * shade, 1), math.min(color.G * shade, 1), math.min(color.B * shade, 1))
		LowPoly.triangle(a, b, c, inside, color, ground, materials[role])
	end

	for j = 1, segments do
		local k = j % segments + 1
		face(center, rings[1][j], rings[1][k])
		for i = 1, #rings - 1 do
			local inner, outer = rings[i], rings[i + 1]
			face(inner[j], outer[j], outer[k])
			face(inner[j], outer[k], inner[k])
		end
	end

	Seabed.slope(
		rings[#rings],
		math.clamp(radius * 0.6, 64, 160),
		spec.seaFloor or Seabed.Floor,
		palette.shore,
		ground,
		materials.shore
	)

	return model
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

-- Ground position and normal on an island at (x, z), ignoring props already placed on it.
function Islands.surface(island: Model, x: number, z: number): (Vector3?, Vector3?)
	rayParams.FilterDescendantsInstances = { island:FindFirstChild("Ground") :: Instance }
	local hit = workspace:Raycast(Vector3.new(x, 1500, z), Vector3.new(0, -1600, 0), rayParams)
	if hit then
		return hit.Position, hit.Normal
	end
	return nil, nil
end

return Islands
