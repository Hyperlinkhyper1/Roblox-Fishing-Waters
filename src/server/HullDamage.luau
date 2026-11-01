-- Shark bites leave lasting marks where the shark struck the hull: a splintered
-- breach ringed by tooth punctures, with gouges dragged along the planks. Every
-- piece is found by its own raycast, so marks hug curved and flared hulls, and is
-- a thin cosmetic part welded to the plank under it. Marks ride, bob and sink with
-- the boat and vanish with it. The server builds them so the whole crew sees them.

local HullDamage = {}

HullDamage.FOLDER = "HullDamage"
-- Big hulls can take dozens of bites before sinking; past this the oldest bite
-- makes way, keeping the part count of a long fight bounded.
HullDamage.MAX_BITES = 12

local HOLE = Color3.fromRGB(14, 12, 10)
local GOUGE = Color3.fromRGB(36, 29, 23)
local RAW_WOOD = Color3.fromRGB(181, 146, 101)
local BARE = Color3.fromRGB(226, 222, 214)
local THICKNESS = 0.02
local random = Random.new()

local function isWood(material: Enum.Material): boolean
	return material == Enum.Material.Wood or material == Enum.Material.WoodPlanks
end

-- Seats, glass and invisible helpers (the hull root, collision boxes) are not skin.
local function cast(params: RaycastParams, origin: Vector3, direction: Vector3): RaycastResult?
	local remaining = direction.Magnitude
	local unit = direction.Unit
	for _ = 1, 4 do
		local result = workspace:Raycast(origin, unit * remaining, params)
		if not result then
			return nil
		end
		local part = result.Instance
		if
			part:IsA("BasePart")
			and not part:IsA("Seat")
			and not part:IsA("VehicleSeat")
			and part.Transparency < 0.5
			and math.abs(result.Normal.Y) < 0.8
			and result.Normal:Dot(unit) < 0
		then
			return result
		end
		remaining -= result.Distance + 0.02
		origin = result.Position + unit * 0.02
		if remaining <= 0 then
			return nil
		end
	end
	return nil
end

-- The hull face under a point, approached from outside along that face's normal.
local function land(params: RaycastParams, point: Vector3, normal: Vector3): RaycastResult?
	local result = cast(params, point + normal * 0.5, normal * -1)
	if result and result.Normal:Dot(normal) > 0.5 then
		return result
	end
	return nil
end

-- A frame on the hull face: X runs along the boat, Y up the side, Z out of the hull.
local function surfaceFrame(position: Vector3, normal: Vector3, along: Vector3): CFrame
	local tangent = along - normal * along:Dot(normal)
	if tangent.Magnitude < 0.05 then
		tangent = Vector3.new(0, 1, 0):Cross(normal)
	end
	tangent = tangent.Unit
	local up = normal:Cross(tangent)
	if up.Y < 0 then
		tangent, up = tangent * -1, up * -1
	end
	return CFrame.fromMatrix(position, tangent, up, normal)
end

local function mark(
	class: string,
	name: string,
	size: Vector3,
	frame: CFrame,
	color: Color3,
	material: Enum.Material,
	plank: BasePart,
	parent: Instance
): BasePart
	local piece = Instance.new(class) :: BasePart
	piece.Name = name
	piece.Size = size
	piece.CFrame = frame
	piece.Color = color
	piece.Material = material
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	-- Parked hulls are anchored whole; match the plank so unparking frees both.
	piece.Anchored = plank.Anchored
	piece.CanCollide, piece.CanTouch, piece.CanQuery = false, false, false
	piece.CastShadow = false
	piece.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = plank
	weld.Part1 = piece
	weld.Parent = piece
	piece.Parent = parent
	return piece
end

-- Two back-to-back wedges make a flat isosceles triangle lying on the hull face,
-- its base centred on `base` and its point at `apex`.
local function triangle(
	name: string,
	base: Vector3,
	apex: Vector3,
	halfWidth: number,
	normal: Vector3,
	color: Color3,
	material: Enum.Material,
	plank: BasePart,
	parent: Instance
)
	local length = (apex - base).Magnitude
	local point = (apex - base).Unit
	local side = normal:Cross(point)
	for _, sign in { 1, -1 } do
		local y = side * sign
		local z = point * -1
		mark(
			"WedgePart",
			name,
			Vector3.new(THICKNESS, halfWidth, length),
			CFrame.fromMatrix(base + point * (length / 2) + y * (halfWidth / 2), y:Cross(z), y, z),
			color,
			material,
			plank,
			parent
		)
	end
end

-- A flat disc on the face; Roblox cylinders run along X, so X takes the normal.
local function disc(name: string, frame: CFrame, diameter: number, lift: number, plank: BasePart, parent: Instance)
	local piece = mark(
		"Part",
		name,
		Vector3.new(THICKNESS, diameter, diameter),
		CFrame.fromMatrix(frame * Vector3.new(0, 0, lift), frame.ZVector, frame.YVector, frame.XVector * -1),
		HOLE,
		Enum.Material.SmoothPlastic,
		plank,
		parent
	) :: Part
	piece.Shape = Enum.PartType.Cylinder
end

local function oldestBite(folder: Instance): Instance?
	local oldest, order = nil, math.huge
	for _, bite in folder:GetChildren() do
		local index = bite:GetAttribute("Order")
		if type(index) == "number" and index < order then
			oldest, order = bite, index
		end
	end
	return oldest
end

local function build(model: Model, params: RaycastParams, hit: RaycastResult, along: Vector3): Instance
	local folder = model:FindFirstChild(HullDamage.FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = HullDamage.FOLDER
		folder.Parent = model
	end
	local order = (folder:GetAttribute("Bites") or 0) + 1
	folder:SetAttribute("Bites", order)
	if #folder:GetChildren() >= HullDamage.MAX_BITES then
		local oldest = oldestBite(folder)
		if oldest then
			oldest:Destroy()
		end
	end
	local bite = Instance.new("Folder")
	bite.Name = "SharkBite"
	bite:SetAttribute("Order", order)

	local plank = hit.Instance :: BasePart
	local normal = hit.Normal
	local frame = surfaceFrame(hit.Position, normal, along)
	local wood = isWood(plank.Material)
	-- Broken edges show the raw core: pale timber, or bare fibreglass and metal.
	local edge = if wood then RAW_WOOD else plank.Color:Lerp(BARE, 0.6)
	local scrape = plank.Color:Lerp(if wood then RAW_WOOD else BARE, 0.55)

	-- Lands a face-local offset (X along the hull, Y up it) of this bite onto the
	-- hull, returning that spot's own face frame and plank.
	local function spot(x: number, y: number): (CFrame?, BasePart?)
		local result = land(params, frame * Vector3.new(x, y, 0), normal)
		if not result then
			return nil, nil
		end
		return surfaceFrame(result.Position, result.Normal, along), result.Instance :: BasePart
	end

	-- The breach: overlapping discs make a ragged hole rather than a neat circle.
	local radius = random:NextNumber(0.36, 0.5)
	disc("BiteHole", frame, radius * 2, 0.012 + THICKNESS / 2, plank, bite)
	for _ = 1, 2 do
		local angle = random:NextNumber(0, math.pi * 2)
		local lobe, lobePlank = spot(math.cos(angle) * radius * 0.5, math.sin(angle) * radius * 0.5)
		if lobe and lobePlank then
			disc("BiteHole", lobe, radius * random:NextNumber(1.1, 1.4), 0.014 + THICKNESS / 2, lobePlank, bite)
		end
	end
	-- Through a thin plank, the hole shows from inside the boat as well.
	local inside = cast(params, hit.Position - normal * 0.6, normal * 0.58)
	if inside and (inside.Position - hit.Position).Magnitude < 0.35 then
		local inner = surfaceFrame(inside.Position, inside.Normal, along)
		disc("BiteHole", inner, radius * 2.1, 0.012 + THICKNESS / 2, inside.Instance :: BasePart, bite)
	end

	-- Splinters pointing into the hole break up its rim.
	local splinters = 6
	for index = 1, splinters do
		local angle = (index + random:NextNumber(-0.3, 0.3)) / splinters * math.pi * 2
		local outward = Vector3.new(math.cos(angle), math.sin(angle), 0)
		local reach = radius * random:NextNumber(1.15, 1.35)
		local at, atPlank = spot(outward.X * reach, outward.Y * reach)
		if at and atPlank then
			local length = random:NextNumber(0.3, 0.5)
			local lift = 0.03 + THICKNESS / 2
			triangle(
				"BiteSplinter",
				at * Vector3.new(0, 0, lift),
				at * Vector3.new(-outward.X * length, -outward.Y * length, lift),
				random:NextNumber(0.07, 0.12),
				at.ZVector,
				edge:Lerp(HOLE, random:NextNumber(0, 0.25)),
				plank.Material,
				atPlank,
				bite
			)
		end
	end

	-- Upper and lower jaws: arcs of triangular punctures pointing into the bite.
	local spanX, spanY = radius + random:NextNumber(0.65, 0.85), radius + random:NextNumber(0.3, 0.42)
	for _, jaw in { { 30, 150 }, { 210, 330 } } do
		local teeth = 5
		for index = 0, teeth - 1 do
			local angle = math.rad(jaw[1] + (jaw[2] - jaw[1]) * index / (teeth - 1) + random:NextNumber(-6, 6))
			local x, y = math.cos(angle) * spanX, math.sin(angle) * spanY
			local at, atPlank = spot(x, y)
			if at and atPlank then
				local inward = Vector3.new(-x, -y, 0).Unit
				local length = random:NextNumber(0.24, 0.34)
				local lift = 0.02 + THICKNESS / 2
				triangle(
					"BiteTooth",
					at * Vector3.new(-inward.X * length / 2, -inward.Y * length / 2, lift),
					at * Vector3.new(inward.X * length / 2, inward.Y * length / 2, lift),
					random:NextNumber(0.065, 0.09),
					at.ZVector,
					HOLE,
					Enum.Material.SmoothPlastic,
					atPlank,
					bite
				)
			end
		end
	end

	-- Gouges where the shark dragged along the hull, fore or aft of the bite:
	-- pale scraped bands, each with a dark scored line, tapering as they trail off.
	local heading = random:NextNumber(-0.35, 0.35) + (if random:NextNumber() < 0.5 then 0 else math.pi)
	local trail = Vector3.new(math.cos(heading), math.sin(heading), 0)
	local across = Vector3.new(-trail.Y, trail.X, 0)
	for gouge = 1, 3 do
		local start = trail * (spanX + 0.15) + across * ((gouge - 2) * 0.26 + random:NextNumber(-0.05, 0.05))
		local length = random:NextNumber(1.6, 2.8)
		local segments = 3
		local points = {}
		for step = 0, segments do
			local offset = start + trail * (length * step / segments)
			local at, atPlank = spot(offset.X, offset.Y)
			points[step] = if at then { frame = at, plank = atPlank } else false
		end
		for step = 0, segments - 1 do
			local from, to = points[step], points[step + 1]
			if not from or not to then
				continue
			end
			local a, b = from.frame.Position, to.frame.Position
			local back = (a - b).Unit
			local face = from.frame.ZVector + to.frame.ZVector
			face = (face - back * face:Dot(back)).Unit
			local side = face:Cross(back)
			local width = 0.11 * (1 - step * 0.25)
			local span = (a - b).Magnitude + 0.04
			local layers = {
				{ width, 0.018, scrape, plank.Material },
				{ width * 0.35, 0.03, GOUGE, Enum.Material.SmoothPlastic },
			}
			for _, layer in layers do
				mark(
					"Part",
					"BiteGouge",
					Vector3.new(layer[1], THICKNESS, span),
					CFrame.fromMatrix((a + b) / 2 + face * (layer[2] + THICKNESS / 2), side, face, back),
					layer[3],
					layer[4],
					from.plank,
					bite
				)
			end
		end
	end

	bite.Parent = folder
	return bite
end

-- Marks the hull where a shark at `from`, on the water surface, lunged along
-- `direction`. Returns the new bite's folder, or nil when no hull face was found.
function HullDamage.bite(model: Model, from: Vector3, direction: Vector3): Instance?
	local root = model.PrimaryPart
	local heading = Vector3.new(direction.X, 0, direction.Z)
	if not root or heading.Magnitude < 0.01 then
		return nil
	end
	heading = heading.Unit
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { model }
	params.IgnoreWater = true
	local hull = math.max(model:GetAttribute("HullLength") or 0, model:GetAttribute("HullBeam") or 0, root.Size.Z)
	-- Sharks strike just above the waterline; drier spots back up a high-sided hull.
	for _, height in { random:NextNumber(0.25, 1.1), 0.6, 1.4, 0.15 } do
		local hit = cast(params, from + Vector3.new(0, height, 0), heading * (hull + 12))
		if hit then
			return build(model, params, hit, root.CFrame.LookVector)
		end
	end
	return nil
end

return HullDamage
