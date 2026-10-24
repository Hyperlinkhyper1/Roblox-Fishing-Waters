-- Rows of detailed two-tone townhouses closing in the piazza on its west, north and east sides:
-- a coloured ground floor under a contrasting upper storey, quoins, string courses, rafter tails
-- under the eaves, shuttered arched windows, balconies, wall lanterns, climbing ivy and clutter.
-- The rod store uses the same builder. The rows are placed after the village so they can clear
-- ordinary houses and trees off their plots; any plot that would cover a street is left empty.

local Med = require(script.Parent.Mediterranean)
local Props = require(script.Parent.Props)

local PlazaHouses = {}

local LAYOUT_VERSION = 1
local TAU = math.pi * 2
local rgb = Color3.fromRGB
local M = Enum.Material
local part, beam, pick = Props.part, Props.beam, Props.pick

local STORY = 10
local FLOOR = 0.8
local STONE = rgb(214, 200, 172)
local QUOIN = rgb(196, 182, 156)
local WOOD = rgb(112, 80, 54)
local IRON = rgb(44, 42, 40)
local CREAM = rgb(255, 240, 205)
local LEAVES = { rgb(70, 132, 52), rgb(92, 152, 60), rgb(58, 112, 46), rgb(110, 164, 70) }

local LOWER = {
	rgb(226, 126, 70),
	rgb(240, 182, 66),
	rgb(244, 230, 200),
	rgb(206, 104, 72),
	rgb(236, 160, 96),
}
local UPPER = {
	rgb(244, 234, 210),
	rgb(92, 150, 202),
	rgb(240, 196, 92),
	rgb(108, 168, 170),
	rgb(234, 214, 176),
}
local SHUTTERS = { rgb(48, 112, 116), rgb(70, 120, 66), rgb(130, 82, 54), rgb(44, 86, 140), rgb(64, 140, 120) }
local ROOFS = { rgb(170, 84, 52), rgb(152, 72, 46), rgb(186, 100, 62) }
local DOORS = { rgb(170, 78, 54), rgb(142, 64, 44), rgb(70, 120, 66), rgb(60, 98, 130) }
local AWNINGS = { rgb(180, 52, 44), rgb(36, 92, 168), rgb(56, 120, 70), rgb(214, 160, 50) }
local SHOPS = { "Bakery", "Taverna", "Bait & Tackle", "Fishmonger", "Gelato", "Net Mender", "Chandlery", "Caffè" }

export type Spec = {
	width: number,
	depth: number,
	stories: number,
	lower: Color3,
	upper: Color3,
	trim: Color3,
	shutter: Color3,
	roof: Color3,
	door: Color3,
	balcony: boolean,
	shop: string?, -- shopfront window and awning, with this name on the board above
	blade: string?, -- a sign hung from an iron bracket beside the door
	signColor: Color3?,
	doorSide: number?, -- which end of a shopfront the door takes: 1 is +X (the default), -1 is -X
}

local function boardText(board: BasePart, value: string, face: Enum.NormalId, color: Color3?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = color or CREAM
	label.Text = value
	label.Parent = gui
end
PlazaHouses.boardText = boardText

-- Frame on the outer surface of one wall; side 0 is the front (+Z), 1 is +X, 2 the back, 3 is -X.
local function wallFace(base: CFrame, w: number, d: number, side: number, y: number): (CFrame, number)
	local outward = if side % 2 == 0 then d / 2 else w / 2
	return base * CFrame.Angles(0, side * math.pi / 2, 0) * CFrame.new(0, y, outward), if side % 2 == 0 then w else d
end

-- Ivy climbing a wall from the ground: a wandering stem with leaves either side, spreading near the top.
local function ivy(m: Model, face: CFrame, x: number, height: number, rng: Random)
	local stem = Vector3.new(x, 0.2, 0.18)
	local y = 0.2
	while y < height do
		local spread = 1 + y / height * 1.4
		local nextStem = Vector3.new(stem.X + rng:NextNumber(-0.7, 0.7), y + 1.1, 0.18)
		beam(m, face * stem, face * nextStem, 0.18, rgb(84, 70, 48), nil, M.Wood).CanCollide = false
		for _ = 1, 2 do
			local leaf = part(
				m,
				Vector3.new(rng:NextNumber(0.8, 1.6), rng:NextNumber(0.6, 1.2), 0.2),
				face
					* CFrame.new(stem.X + rng:NextNumber(-1, 1) * spread, y + rng:NextNumber(0, 1), 0.22)
					* CFrame.Angles(0, 0, rng:NextNumber(0, TAU)),
				pick(rng, LEAVES),
				M.LeafyGrass
			)
			leaf.CanCollide = false
			leaf.CastShadow = false
		end
		stem = nextStem
		y += 1.1
	end
end

-- Lantern hanging from an iron bracket on a wall; `face` is the fixing point.
local function wallLantern(m: Model, face: CFrame)
	part(m, Vector3.new(0.5, 0.8, 0.2), face * CFrame.new(0, 0, 0.1), IRON, M.Metal)
	part(m, Vector3.new(0.18, 0.18, 1.5), face * CFrame.new(0, 0.2, 0.75), IRON, M.Metal).CanCollide = false
	beam(m, face * Vector3.new(0, -0.4, 0.15), face * Vector3.new(0, 0.2, 1.1), 0.12, IRON, nil, M.Metal).CanCollide =
		false
	local lantern = Props.lantern(m, face * CFrame.new(0, -1.5, 1.3))
	for _, piece in lantern:GetChildren() do
		if piece:IsA("BasePart") then
			piece.CanCollide = false
		end
	end
end

-- Shopfront: a gridded window glowing with lamplight, a striped awning and a name board.
local function shopfront(m: Model, front: CFrame, x: number, width: number, spec: Spec, rng: Random)
	local frame, awning = spec.shutter, pick(rng, AWNINGS)
	part(m, Vector3.new(width + 1, 5.8, 0.16), front * CFrame.new(x, FLOOR + 3.6, 0.08), frame, M.Wood)
	local glass =
		part(m, Vector3.new(width, 4.8, 0.2), front * CFrame.new(x, FLOOR + 3.7, 0.14), rgb(255, 214, 150), M.Neon)
	Props.light(glass, rgb(255, 214, 150), 18, 0.8)
	local panes = math.max(2, math.floor(width / 1.6))
	for i = 1, panes - 1 do
		part(
			m,
			Vector3.new(0.14, 4.8, 0.3),
			front * CFrame.new(x - width / 2 + i * width / panes, FLOOR + 3.7, 0.3),
			frame,
			M.Wood
		)
	end
	part(m, Vector3.new(width, 0.14, 0.3), front * CFrame.new(x, FLOOR + 4.7, 0.3), frame, M.Wood)
	part(m, Vector3.new(width + 1.4, 0.5, 1.2), front * CFrame.new(x, FLOOR + 1, 0.55), WOOD, M.WoodPlanks)
	local strips = math.max(4, math.floor(width / 1.3))
	for i = 0, strips - 1 do
		part(
			m,
			Vector3.new(width / strips + 0.02, 0.2, 3.4),
			front * CFrame.new(x - width / 2 + (i + 0.5) * width / strips, FLOOR + 7, 1.55) * CFrame.Angles(0.38, 0, 0),
			if i % 2 == 0 then awning else CREAM,
			M.Fabric
		).CanCollide =
			false
	end
	local board =
		part(m, Vector3.new(width * 0.85, 1.3, 0.3), front * CFrame.new(x, FLOOR + 8.4, 0.18), frame, M.WoodPlanks)
	boardText(board, spec.shop :: string, Enum.NormalId.Back, spec.signColor)
end

-- A sign on an iron arm sticking out from the wall, readable from both directions along the street.
local function bladeSign(m: Model, face: CFrame, text: string, color: Color3?)
	part(m, Vector3.new(0.3, 0.3, 3.2), face * CFrame.new(0, 0, 1.6), IRON, M.Metal).CanCollide = false
	beam(m, face * Vector3.new(0, -1.2, 0.1), face * Vector3.new(0, 0, 2.2), 0.16, IRON, nil, M.Metal).CanCollide =
		false
	for _, z in { 0.9, 2.7 } do
		part(m, Vector3.new(0.1, 0.5, 0.1), face * CFrame.new(0, -0.35, z), IRON, M.Metal).CanCollide = false
	end
	local board = part(m, Vector3.new(0.25, 1.6, 2.6), face * CFrame.new(0, -1.4, 1.8), WOOD, M.WoodPlanks)
	board.CanCollide = false
	boardText(board, text, Enum.NormalId.Right, color)
	boardText(board, text, Enum.NormalId.Left, color)
end

-- One townhouse standing on `base` (ground level, front on local +Z). Returns the model and the
-- frame at the foot of its front door, with +Z pointing out into the street.
function PlazaHouses.house(parent: Instance, base: CFrame, spec: Spec, rng: Random): (Model, CFrame, BasePart)
	local m = Instance.new("Model")
	m.Name = "PlazaHouse"
	m.Parent = parent
	local w, d, stories = spec.width, spec.depth, spec.stories
	local h = stories * STORY
	local top = FLOOR + h

	-- A plinth deep enough to meet uneven ground, then the two-tone walls
	part(m, Vector3.new(w + 0.8, 4, d + 0.8), base * CFrame.new(0, FLOOR - 2, 0), STONE, M.Limestone)
	part(m, Vector3.new(w, STORY, d), base * CFrame.new(0, FLOOR + STORY / 2, 0), spec.lower, M.Plaster)
	if stories > 1 then
		part(
			m,
			Vector3.new(w, h - STORY, d),
			base * CFrame.new(0, FLOOR + STORY + (h - STORY) / 2, 0),
			spec.upper,
			M.Plaster
		)
	end
	for s = 1, stories - 1 do
		part(m, Vector3.new(w + 0.7, 0.55, d + 0.7), base * CFrame.new(0, FLOOR + s * STORY, 0), spec.trim, M.Plaster)
		part(
			m,
			Vector3.new(w + 0.35, 0.25, d + 0.35),
			base * CFrame.new(0, FLOOR + s * STORY - 0.4, 0),
			spec.trim,
			M.Plaster
		)
	end
	-- Rusticated quoins on the ground-floor corners
	for _, cx in { -1, 1 } do
		for _, cz in { -1, 1 } do
			for k = 0, 3 do
				local a = if k % 2 == 0 then 1.5 else 1.1
				part(
					m,
					Vector3.new(a, 1.9, a),
					base * CFrame.new(cx * (w / 2 - a / 2 + 0.15), FLOOR + 1.2 + k * 2.1, cz * (d / 2 - a / 2 + 0.15)),
					QUOIN,
					M.Limestone
				)
			end
		end
	end

	-- Cornice, rafter tails under the eaves, tiled roof and a chimney
	part(m, Vector3.new(w + 1.2, 0.8, d + 1.2), base * CFrame.new(0, top + 0.4, 0), spec.trim, M.Plaster)
	for _, z in { -1, 1 } do
		for x = -w / 2 + 1, w / 2 - 0.9, 1.8 do
			part(m, Vector3.new(0.4, 0.4, 1.5), base * CFrame.new(x, top - 0.1, z * (d / 2 + 0.75)), WOOD, M.Wood).CanCollide =
				false
		end
	end
	local rise = Med.gableRoof(m, base, w, d, top + 0.8, math.rad(rng:NextNumber(20, 25)), spec.roof, spec.upper)
	local chimneyX = (if rng:NextNumber() < 0.5 then -1 else 1) * w * 0.28
	local stackH = rise / 2 + 3
	part(
		m,
		Vector3.new(1.8, stackH, 1.8),
		base * CFrame.new(chimneyX, top + 0.8 + stackH / 2, -d / 4),
		spec.trim,
		M.Plaster
	)
	part(
		m,
		Vector3.new(2.4, 0.4, 2.4),
		base * CFrame.new(chimneyX, top + 0.8 + stackH + 0.2, -d / 4),
		spec.trim,
		M.Plaster
	)

	-- Front: door, shopfront or windows on the ground floor; a balcony and windows above
	local front = wallFace(base, w, d, 0, 0)
	local doorSide = spec.doorSide or 1
	local doorX = if spec.shop
		then doorSide * (w / 2 - 3.8)
		else (if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(0, w / 6)
	local doorFace = front * CFrame.new(doorX, FLOOR, 0)
	local leaf = Med.door(m, doorFace, 3.4, 6.6, spec.door, spec.trim, true)
	local n = math.max(2, math.floor(w / 6))
	local windowW, windowH = 2.6, 3.8
	local lit = false
	local function addWindow(at: CFrame, upper: boolean)
		local glow = rng:NextNumber() < 0.3
		local glass = Med.window(m, at, windowW, windowH, spec.trim, spec.shutter, true, glow)
		if glow and not lit then
			Props.light(glass, rgb(255, 210, 140), 18, 0.7)
			lit = true
		end
		if upper and rng:NextNumber() < 0.4 then
			Med.flowerBox(m, at * CFrame.new(0, -windowH / 2 - 0.9, 0), windowW + 0.6, rng)
		end
	end
	if spec.shop then
		shopfront(m, front, -2.4 * doorSide, w - 9, spec, rng)
	else
		for i = 1, n do
			local x = (i - (n + 1) / 2) * (w - 6) / n
			if math.abs(x - doorX) > 5.5 then
				addWindow(front * CFrame.new(x, FLOOR + STORY * 0.5, 0), false)
			end
		end
	end
	local balconyX = if spec.balcony then (if spec.shop then 0 else doorX) else nil
	for s = 2, stories do
		local y = FLOOR + (s - 1) * STORY
		if s == 2 and balconyX then
			local sill = front * CFrame.new(balconyX, y + 0.3, 0)
			Med.door(m, sill, 3, 6.4, spec.shutter, spec.trim, true)
			Med.balcony(m, sill, 9, 2.4, spec.trim)
			for _, side in { -1, 1 } do
				part(m, Vector3.new(0.8, 1.6, 1.8), sill * CFrame.new(side * 3.6, -1.1, 0.9), spec.trim, M.Plaster)
			end
			Med.pot(m, sill:PointToWorldSpace(Vector3.new(-3.4, 0, 1.2)), rng, "flowers")
		end
		for i = 1, n do
			local x = (i - (n + 1) / 2) * (w - 6) / n
			if not (s == 2 and balconyX and math.abs(x - balconyX) < 7.8) then
				addWindow(front * CFrame.new(x, y + STORY * 0.5, 0), true)
			end
		end
	end

	-- Sides and back carry fewer windows, some left blank
	for side = 1, 3 do
		local face, width = wallFace(base, w, d, side, 0)
		local count = math.max(1, math.floor(width / 7))
		for s = 1, stories do
			for i = 1, count do
				if rng:NextNumber() < 0.35 then
					continue
				end
				local x = (i - (count + 1) / 2) * (width - 6) / count
				addWindow(face * CFrame.new(x, FLOOR + (s - 1) * STORY + STORY * 0.5, 0), s > 1)
			end
		end
	end

	-- Street details: lanterns either side of the door, ivy, a sign, pots and barrels on the step
	for _, side in { -1, 1 } do
		-- On a shop the awning takes the place of the lantern nearer the window
		if math.abs(doorX + side * 2.9) < w / 2 - 1 and not (spec.shop and side ~= doorSide) then
			wallLantern(m, doorFace * CFrame.new(side * 2.9, 8.4, 0))
		end
	end
	local ivyX = if doorX > 0 then -w / 2 + rng:NextNumber(1.5, 3) else w / 2 - rng:NextNumber(1.5, 3)
	ivy(m, front, ivyX, math.min(h, STORY * 1.6) + rng:NextNumber(-2, 2), rng)
	if rng:NextNumber() < 0.5 then
		local sideFace = wallFace(base, w, d, if ivyX > 0 then 1 else 3, 0)
		ivy(m, sideFace, (if ivyX > 0 then 1 else -1) * (d / 2 - 2), h * 0.8, rng)
	end
	if spec.blade then
		local bladeX = if doorX > 0 then -w / 2 + 0.8 else w / 2 - 0.8
		bladeSign(m, front * CFrame.new(bladeX, FLOOR + 9.2, 0), spec.blade :: string, spec.signColor)
	end
	-- Kept to a narrow strip by the wall, so nothing spills onto the kerb of the square
	local street = base * CFrame.new(0, 0, d / 2 + 1.6)
	for _ = 1, rng:NextInteger(1, 3) do
		local x = rng:NextNumber(-w / 2 + 1.5, w / 2 - 1.5)
		if math.abs(x - doorX) < 3.5 or (spec.shop and x * doorSide < w / 2 - 6) then
			continue
		end
		local roll = rng:NextNumber()
		local at = street:PointToWorldSpace(Vector3.new(x, 0, rng:NextNumber(-0.4, 0.2)))
		if roll < 0.45 then
			Props.barrel(m, at, rng)
		else
			Med.pot(m, at, rng, if roll < 0.75 then "flowers" else "lemon")
		end
	end
	return m, doorFace, leaf
end

-- A random member of the plaza family, so the rows read as one street of individual houses.
function PlazaHouses.spec(rng: Random, width: number, depth: number, stories: number): Spec
	local lower = pick(rng, LOWER)
	local upper = pick(rng, UPPER)
	if upper == lower then
		upper = UPPER[1]
	end
	local shop = if rng:NextNumber() < 0.3 then pick(rng, SHOPS) else nil
	return {
		width = width,
		depth = depth,
		stories = stories,
		lower = lower,
		upper = upper,
		trim = rgb(248, 240, 222),
		shutter = pick(rng, SHUTTERS),
		roof = pick(rng, ROOFS),
		door = pick(rng, DOORS),
		balcony = stories > 1 and rng:NextNumber() < 0.6,
		shop = shop,
		blade = if shop == nil and rng:NextNumber() < 0.2 then pick(rng, SHOPS) else nil,
	}
end

----------------------------------------------------------------------------------------------------
-- Placement round the piazza

-- Plots in paving coordinates (the square runs to ±60), each { x, z, facing, width, stories }.
-- Width runs along the row; every house is 16 deep and fronts onto the square.
local DEPTH = 16
local function plots(): { { number } }
	local list = {}
	local function row(
		fixed: number,
		from: number,
		widths: { number },
		facing: number,
		axis: string,
		stories: { number }
	)
		local at = from
		for i, width in widths do
			local middle = at + width / 2
			if axis == "z" then
				table.insert(list, { fixed, middle, facing, width, stories[i] })
			else
				table.insert(list, { middle, fixed, facing, width, stories[i] })
			end
			at += width
		end
	end
	-- West and east rows run from the north corner toward the bay; the north row closes the top.
	row(-72, -60, { 18, 16, 18, 16, 14 }, math.pi / 2, "z", { 3, 2, 3, 2, 2 })
	row(72, -60, { 16, 18, 16, 18, 14 }, -math.pi / 2, "z", { 2, 3, 2, 3, 2 })
	row(-72, -80, { 18, 18, 18, 16, 20, 16, 18, 18, 18 }, 0, "x", { 3, 2, 3, 2, 3, 3, 2, 3, 2 })
	return list
end

-- Conservative overlap: the bounds of `item` measured in the footprint box's own space.
local function overlaps(footprint: CFrame, half: Vector3, item: BasePart): boolean
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = -low
	for _, x in { -0.5, 0.5 } do
		for _, y in { -0.5, 0.5 } do
			for _, z in { -0.5, 0.5 } do
				local p = footprint:PointToObjectSpace(
					item.CFrame * Vector3.new(item.Size.X * x, item.Size.Y * y, item.Size.Z * z)
				)
				low, high = low:Min(p), high:Max(p)
			end
		end
	end
	return low.X < half.X
		and high.X > -half.X
		and low.Y < half.Y
		and high.Y > -half.Y
		and low.Z < half.Z
		and high.Z > -half.Z
end

-- The highest ground under a plot's corners, so a house never sinks into a rising slope.
local function groundUnder(island: Instance?, frame: CFrame, w: number, d: number, fallback: number): number
	local groundModel = island and island:FindFirstChild("Ground")
	if not groundModel then
		return fallback
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { groundModel }
	local best = fallback
	for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		local p = frame:PointToWorldSpace(Vector3.new(c[1] * w / 2, 0, c[2] * d / 2))
		local hit = workspace:Raycast(p + Vector3.new(0, 60, 0), Vector3.new(0, -120, 0), params)
		if hit then
			best = math.max(best, hit.Position.Y)
		end
	end
	return math.min(best, fallback + 3)
end

-- pavingFrame is the top of the paving at the centre of the square.
function PlazaHouses.build(plaza: Model, pavingFrame: CFrame): Model
	local existing = plaza:FindFirstChild("PlazaHouses")
	if existing and existing:GetAttribute("LayoutVersion") == LAYOUT_VERSION then
		return existing
	elseif existing then
		existing:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "PlazaHouses"
	model:SetAttribute("LayoutVersion", LAYOUT_VERSION)

	local village = plaza.Parent
	local island = village and village.Parent
	-- Streets, paths, beach, bases and the square itself block a plot. Generated houses and trees
	-- are cleared off it instead.
	local clearable: { Instance } = {}
	for _, name in { "Houses" } do
		local folder = village and village:FindFirstChild(name)
		if folder then
			table.insert(clearable, folder)
		end
	end
	for _, name in { "Hilltops", "Forest" } do
		local folder = island and island:FindFirstChild(name)
		if folder then
			table.insert(clearable, folder)
		end
	end
	local center = pavingFrame.Position
	local blocking, removable = {}, {}
	local function near(item: BasePart): boolean
		local offset = item.Position - center
		return Vector2.new(offset.X, offset.Z).Magnitude < 150 + item.Size.Magnitude / 2
	end
	if village then
		for _, item in village:GetDescendants() do
			if item:IsA("BasePart") and near(item) then
				local owner = nil
				for _, folder in clearable do
					if item:IsDescendantOf(folder) then
						owner = folder
						break
					end
				end
				if owner then
					-- Remove the whole prop (a house, lamp or tree), not just the overlapping part
					local target: Instance = item
					while target.Parent and target.Parent ~= owner do
						target = target.Parent
					end
					table.insert(removable, { item, target })
				else
					table.insert(blocking, item)
				end
			end
		end
	end
	for _, folder in clearable do
		if not folder:IsDescendantOf(village :: Instance) then
			for _, item in folder:GetDescendants() do
				if item:IsA("BasePart") and near(item) then
					local target: Instance = item
					while target.Parent and target.Parent ~= folder do
						target = target.Parent
					end
					table.insert(removable, { item, target })
				end
			end
		end
	end
	local bases = island and island:FindFirstChild("Bases")
	if bases then
		for _, item in bases:GetDescendants() do
			if item:IsA("BasePart") and near(item) then
				table.insert(blocking, item)
			end
		end
	end

	local rng = Random.new(7311)
	local groundY = center.Y - 0.8
	for index, plot in plots() do
		local x, z, facing, width, stories = plot[1], plot[2], plot[3], plot[4], plot[5]
		local spec = PlazaHouses.spec(rng, width, DEPTH, stories)
		local frame = CFrame.new(center.X, groundY, center.Z) * CFrame.new(x, 0, z) * CFrame.Angles(0, facing, 0)
		-- Plots touch along the row, so test each one fractionally inside its own walls
		local footprint = frame * CFrame.new(0, 20, 0)
		local half = Vector3.new(width / 2 - 0.3, 19.5, DEPTH / 2 + 1)
		local clear = true
		for _, item in blocking do
			if item.Parent and item.Transparency < 1 and overlaps(footprint, half, item) then
				clear = false
				break
			end
		end
		if not clear then
			continue
		end
		local doomed: { [Instance]: boolean } = {}
		for _, entry in removable do
			if entry[2].Parent and overlaps(footprint, half, entry[1]) then
				doomed[entry[2]] = true
			end
		end
		for target in doomed do
			target:Destroy()
		end
		local y = groundUnder(island, frame, width, DEPTH, groundY)
		local house = PlazaHouses.house(model, frame + Vector3.new(0, y - groundY, 0), spec, rng)
		house.Name = "PlazaHouse" .. index
	end
	model.Parent = plaza
	return model
end

-- The current paving is 116 studs wide; older baked maps used 120. Its top centre anchors
-- everything added to a saved square.
function PlazaHouses.pavingFrame(plaza: Model): CFrame?
	for _, slab in plaza:GetChildren() do
		if
			slab:IsA("BasePart")
			and slab.Size.X >= 115.9
			and slab.Size.X <= 120.1
			and math.abs(slab.Size.X - slab.Size.Z) < 0.01
			and slab.Size.Y <= 1
		then
			return slab.CFrame * CFrame.new(0, slab.Size.Y / 2, 0)
		end
	end
	return nil
end

function PlazaHouses.ensure(root: Instance)
	for _, plaza in root:GetDescendants() do
		if plaza:IsA("Model") and plaza.Name == "Plaza" then
			local frame = PlazaHouses.pavingFrame(plaza)
			if frame then
				PlazaHouses.build(plaza, frame)
			end
		end
	end
end

return PlazaHouses
