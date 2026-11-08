-- Boat furniture: decor bought at the drydock refit dock with the Boat
-- Customization gamepass and placed freely on a hull's decks. The catalog and the
-- placement rules are pure (the saved-data tests run them without Roblox); the
-- builder kit, `dress` and `preview` touch Roblox only when called.
--
-- Placed items are saved per boat id as { Id, X, Y, Z, R }: X/Y/Z in studs from
-- the hull's PrimaryPart ("HullRoot", forward is its -Z) and R a yaw in degrees.
-- Bought but unplaced items wait in a shared stock, so furniture can move between
-- boats. Each item's model is built by src/shared/BoatFurnitureModels/<Id>.luau,
-- a `function(kit)` working in item-local studs: the origin is the centre of the
-- item's floor footprint, +Y is up and -Z is the item's front. Every part must
-- stay inside the box Size describes (X across, Y tall, Z deep).
local BoatFurniture = {}

BoatFurniture.PASS = "BoatCustomization"
BoatFurniture.SNAP = 0.25
BoatFurniture.ROTATION_STEP = 15
BoatFurniture.MAX_PARTS = 30
-- Hull-local heights a piece may stand at (the root sits 0.4 under the waterline).
BoatFurniture.MIN_Y = -3
BoatFurniture.MAX_Y = 22
-- How far past the hull's length and beam a footprint may hang (over gunwales).
BoatFurniture.OVERHANG = 1
BoatFurniture.MAX_STOCK = 99

BoatFurniture.Categories = {
	{ Id = "All", Name = "All" },
	{ Id = "Seating", Name = "Seating" },
	{ Id = "Tables", Name = "Tables" },
	{ Id = "Lighting", Name = "Lighting" },
	{ Id = "Plants", Name = "Plants" },
	{ Id = "Nautical", Name = "Nautical" },
	{ Id = "Storage", Name = "Storage" },
	{ Id = "Fishing", Name = "Fishing" },
	{ Id = "Leisure", Name = "Leisure" },
}

BoatFurniture.Order = {
	"DeckChair",
	"SunLounger",
	"DeckBench",
	"CaptainsTable",
	"BistroSet",
	"CoffeeTable",
	"StandingLantern",
	"DeckTorch",
	"StringLights",
	"PalmPlanter",
	"HerbBox",
	"FlowerBarrel",
	"ShipBell",
	"Telescope",
	"Binnacle",
	"SeaChest",
	"CargoCrates",
	"WaterBarrel",
	"FightingChair",
	"RodRack",
	"BaitCooler",
	"KettleGrill",
	"Hammock",
	"Parasol",
	"Flagpole",
	"LifeRingPost",
	"AnchorStatue",
	"HotTub",
	"Jukebox",
	"FirePit",
}

-- Size = { across (X), tall (Y), deep (Z) } in studs.
BoatFurniture.Items = {
	DeckChair = {
		Name = "Deck chair",
		Price = 120,
		Category = "Seating",
		Size = { 2.2, 3.2, 3.4 },
		Description = "A folding wooden deck chair with a striped canvas sling.",
	},
	SunLounger = {
		Name = "Sun lounger",
		Price = 260,
		Category = "Seating",
		Size = { 2.4, 2.2, 6 },
		Description = "A reclining lounger with a padded cushion for long sunny crossings.",
	},
	DeckBench = {
		Name = "Deck bench",
		Price = 180,
		Category = "Seating",
		Size = { 5, 3, 1.8 },
		Description = "A slatted teak bench with a backrest and brass-capped legs.",
	},
	CaptainsTable = {
		Name = "Captain's table",
		Price = 300,
		Category = "Tables",
		Size = { 4, 2.8, 4 },
		Description = "A round varnished table on a heavy pedestal, chart pinned on top.",
	},
	BistroSet = {
		Name = "Bistro set",
		Price = 350,
		Category = "Tables",
		Size = { 4.5, 3.2, 4.5 },
		Description = "A little round café table with two matching chairs.",
	},
	CoffeeTable = {
		Name = "Coffee table",
		Price = 150,
		Category = "Tables",
		Size = { 3.6, 1.4, 2.2 },
		Description = "A low table with a lower shelf, for drinks and tackle magazines.",
	},
	StandingLantern = {
		Name = "Standing lantern",
		Price = 140,
		Category = "Lighting",
		Size = { 1.2, 5, 1.2 },
		Description = "A ship's lantern on an iron post. Glows warm after dark.",
	},
	DeckTorch = {
		Name = "Deck torch",
		Price = 110,
		Category = "Lighting",
		Size = { 1, 5.5, 1 },
		Description = "A bamboo tiki torch with a flickering flame.",
	},
	StringLights = {
		Name = "String lights",
		Price = 220,
		Category = "Lighting",
		Size = { 6, 6, 0.6 },
		Description = "Two posts strung with glowing party bulbs.",
	},
	PalmPlanter = {
		Name = "Palm planter",
		Price = 240,
		Category = "Plants",
		Size = { 3, 7, 3 },
		Description = "A potted palm in a wooden tub. Brings the tropics aboard.",
	},
	HerbBox = {
		Name = "Herb box",
		Price = 90,
		Category = "Plants",
		Size = { 3.6, 1.6, 1.4 },
		Description = "A window-box of herbs for the galley.",
	},
	FlowerBarrel = {
		Name = "Flower barrel",
		Price = 110,
		Category = "Plants",
		Size = { 2, 2.6, 2 },
		Description = "Half a barrel overflowing with bright flowers.",
	},
	ShipBell = {
		Name = "Ship's bell",
		Price = 260,
		Category = "Nautical",
		Size = { 1.8, 4, 1.4 },
		Description = "A polished brass bell hung from a wooden frame.",
	},
	Telescope = {
		Name = "Telescope",
		Price = 320,
		Category = "Nautical",
		Size = { 2.2, 4.2, 2.2 },
		Description = "A brass spyglass on a tripod, aimed at the horizon.",
	},
	Binnacle = {
		Name = "Binnacle compass",
		Price = 280,
		Category = "Nautical",
		Size = { 1.6, 3.6, 1.6 },
		Description = "A pedestal compass with brass correcting spheres.",
	},
	SeaChest = {
		Name = "Sea chest",
		Price = 200,
		Category = "Storage",
		Size = { 3, 2.2, 1.8 },
		Description = "An iron-banded chest with a domed lid and a heavy lock.",
	},
	CargoCrates = {
		Name = "Cargo crates",
		Price = 150,
		Category = "Storage",
		Size = { 3.6, 3.6, 3.6 },
		Description = "A stack of stencilled shipping crates under a cargo strap.",
	},
	WaterBarrel = {
		Name = "Water barrel",
		Price = 100,
		Category = "Storage",
		Size = { 2, 3, 2 },
		Description = "A banded oak barrel with a brass tap.",
	},
	FightingChair = {
		Name = "Fighting chair",
		Price = 450,
		Category = "Fishing",
		Size = { 3, 4.2, 3.6 },
		Description = "A big-game fishing chair with a footrest and rod gimbal.",
	},
	RodRack = {
		Name = "Rod rack",
		Price = 160,
		Category = "Fishing",
		Size = { 3.6, 5, 1.2 },
		Description = "A rack of spare rods standing ready.",
	},
	BaitCooler = {
		Name = "Bait cooler",
		Price = 90,
		Category = "Fishing",
		Size = { 2.6, 1.8, 1.6 },
		Description = "A two-tone cooler with a hinged lid and carry handle.",
	},
	KettleGrill = {
		Name = "Kettle grill",
		Price = 230,
		Category = "Leisure",
		Size = { 2.2, 3.4, 2.2 },
		Description = "A round charcoal grill on three legs, coals glowing.",
	},
	Hammock = {
		Name = "Hammock",
		Price = 380,
		Category = "Leisure",
		Size = { 8, 3.6, 2.6 },
		Description = "A rope hammock slung between two curved wooden stands.",
	},
	Parasol = {
		Name = "Parasol",
		Price = 200,
		Category = "Leisure",
		Size = { 5, 6, 5 },
		Description = "A striped sun umbrella on a weighted base.",
	},
	Flagpole = {
		Name = "Flagpole",
		Price = 250,
		Category = "Nautical",
		Size = { 4, 10, 1 },
		Description = "A tall pole flying your crew's colours.",
	},
	LifeRingPost = {
		Name = "Life ring post",
		Price = 90,
		Category = "Nautical",
		Size = { 1.6, 4, 0.8 },
		Description = "A red and white life ring on a short post.",
	},
	AnchorStatue = {
		Name = "Anchor statue",
		Price = 210,
		Category = "Nautical",
		Size = { 2.6, 4, 1.2 },
		Description = "A display anchor wrapped in rope on a timber plinth.",
	},
	HotTub = {
		Name = "Hot tub",
		Price = 1200,
		Category = "Leisure",
		Size = { 6, 2.6, 6 },
		Description = "A steaming wooden hot tub with glowing underwater lights.",
	},
	Jukebox = {
		Name = "Jukebox",
		Price = 600,
		Category = "Leisure",
		Size = { 2.2, 4.4, 1.6 },
		Description = "A chrome and neon jukebox for deck parties.",
	},
	FirePit = {
		Name = "Fire pit",
		Price = 350,
		Category = "Leisure",
		Size = { 3, 1.6, 3 },
		Description = "A stone-ringed fire bowl with real flames.",
	},
}

function BoatFurniture.matchesCategory(itemId: string, category: string): boolean
	local item = BoatFurniture.Items[itemId]
	return item ~= nil and (category == "All" or item.Category == category)
end

-- How many pieces a hull carries: one per ~24 square studs of deck, 3 to 30.
function BoatFurniture.limit(layout): number
	if type(layout) ~= "table" or type(layout.Length) ~= "number" or type(layout.Beam) ~= "number" then
		return 0
	end
	return math.clamp(math.floor(layout.Length * layout.Beam / 24), 3, 30)
end

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function BoatFurniture.snap(value: number): number
	return math.round(value / BoatFurniture.SNAP) * BoatFurniture.SNAP
end

function BoatFurniture.snapRotation(degrees: number): number
	local step = BoatFurniture.ROTATION_STEP
	return (math.round(degrees / step) * step) % 360
end

-- Half extents of an item's footprint on the hull's X and Z after a yaw of r°.
function BoatFurniture.extents(itemId: string, r: number): (number, number)
	local size = BoatFurniture.Items[itemId].Size
	local angle = math.rad(r)
	local c, s = math.abs(math.cos(angle)), math.abs(math.sin(angle))
	local hx, hz = size[1] / 2, size[3] / 2
	return hx * c + hz * s, hx * s + hz * c
end

-- Whether a saved entry has the right shape. Unknown ids are kept (an item may
-- return) but never built or counted as valid placements.
function BoatFurniture.entryShape(entry: any): boolean
	return type(entry) == "table"
		and type(entry.Id) == "string"
		and #entry.Id <= 40
		and finite(entry.X)
		and finite(entry.Y)
		and finite(entry.Z)
		and finite(entry.R)
end

-- Why `itemId` can't stand at (x, y, z, r) on a hull with `layout`, or nil.
-- The server also casts a ray to be sure a deck is right under it.
function BoatFurniture.check(layout, itemId: any, x: any, y: any, z: any, r: any): string?
	local item = type(itemId) == "string" and BoatFurniture.Items[itemId]
	if not item then
		return "Choose a piece of furniture."
	elseif type(layout) ~= "table" or not finite(layout.Length) or not finite(layout.Beam) then
		return "Launch one of your boats first."
	elseif not (finite(x) and finite(y) and finite(z) and finite(r)) then
		return "That spot isn't on your boat."
	elseif r % BoatFurniture.ROTATION_STEP ~= 0 or r < 0 or r >= 360 then
		return "That rotation isn't allowed."
	elseif y < BoatFurniture.MIN_Y or y > BoatFurniture.MAX_Y then
		return "Place it on one of your boat's decks."
	end
	local hx, hz = BoatFurniture.extents(itemId, r)
	if
		math.abs(x) + hx > layout.Beam / 2 + BoatFurniture.OVERHANG
		or math.abs(z) + hz > layout.Length / 2 + BoatFurniture.OVERHANG
	then
		return "That sticks out too far over the side."
	end
	return nil
end

function BoatFurniture.placed(entries: any): number
	local count = 0
	if type(entries) == "table" then
		for _, entry in entries do
			if BoatFurniture.entryShape(entry) and BoatFurniture.Items[entry.Id] then
				count += 1
			end
		end
	end
	return count
end

-- The item's frame relative to the hull root.
function BoatFurniture.localFrame(entry): CFrame
	return CFrame.new(entry.X, entry.Y, entry.Z) * CFrame.Angles(0, math.rad(entry.R), 0)
end

------------------------------------------------------------------------------
-- Models (Roblox only)
------------------------------------------------------------------------------

-- Builders by id; filled lazily from the BoatFurnitureModels folder so the pure
-- rules above load without Roblox. Harnesses may assign entries directly.
BoatFurniture.builders = {}

local function builder(id: string)
	local found = BoatFurniture.builders[id]
	if found == nil and script then
		local folder = script.Parent:FindFirstChild("BoatFurnitureModels")
		local module = folder and folder:FindFirstChild(id)
		found = if module then require(module) else false
		BoatFurniture.builders[id] = found
	end
	return found or nil
end

local PALETTE = {
	Wood = Color3.fromRGB(150, 103, 64),
	DarkWood = Color3.fromRGB(86, 58, 39),
	Teak = Color3.fromRGB(176, 122, 74),
	Cream = Color3.fromRGB(236, 224, 196),
	White = Color3.fromRGB(240, 240, 236),
	Brass = Color3.fromRGB(201, 160, 72),
	Iron = Color3.fromRGB(58, 60, 64),
	Steel = Color3.fromRGB(160, 166, 172),
	Rope = Color3.fromRGB(196, 168, 120),
	Canvas = Color3.fromRGB(214, 206, 184),
	Navy = Color3.fromRGB(32, 52, 96),
	Red = Color3.fromRGB(196, 44, 44),
	Teal = Color3.fromRGB(40, 150, 150),
	Green = Color3.fromRGB(70, 132, 72),
	Leaf = Color3.fromRGB(96, 160, 80),
	Terracotta = Color3.fromRGB(190, 96, 58),
	Stone = Color3.fromRGB(128, 124, 118),
	Glow = Color3.fromRGB(255, 205, 120),
	Flame = Color3.fromRGB(255, 140, 40),
}
BoatFurniture.Palette = PALETTE

-- Builds one item at `frame` (the item origin in world space) under `parent`.
-- options.root: weld every part to this hull root with exact offsets (the item
-- must then also give options.offset, its frame relative to that root).
-- options.ghost: a see-through, unqueryable placement preview with no lights.
-- options.anchored: anchor every part (catalog previews).
function BoatFurniture.build(parent: Instance?, frame: CFrame, id: string, options: any?): Model?
	local item = BoatFurniture.Items[id]
	local make = builder(id)
	if not item or not make then
		return nil
	end
	options = options or {}
	local model = Instance.new("Model")
	model.Name = id
	model:SetAttribute("BoatFurniture", id)
	local root: BasePart? = options.root
	local offset: CFrame = options.offset or CFrame.identity
	local ghost = options.ghost == true
	local count = 0
	local kit = {}
	kit.Palette = PALETTE
	kit.Size = Vector3.new(item.Size[1], item.Size[2], item.Size[3])
	kit.Material = Enum.Material

	local function finish(p: BasePart, name: string, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
		count += 1
		p.Name = name
		p.CFrame = frame * cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = not ghost
		p.Massless = true
		p.Anchored = options.anchored == true or (root == nil and not options.loose)
		local size = p.Size
		if ghost or (size.X < 1 and size.Y < 1 and size.Z < 1) then
			p.CastShadow = false
		end
		if ghost then
			p.Transparency = math.max(p.Transparency, 0.45)
		end
		if root and not p.Anchored then
			local weld = Instance.new("Weld")
			weld.Part0 = root
			weld.Part1 = p
			weld.C0 = offset * cf
			weld.Parent = p
		end
		-- Past the cap a piece is built but never shown, so builders stay simple.
		if count <= BoatFurniture.MAX_PARTS then
			p.Parent = model
		end
		return p
	end

	function kit.block(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
		local p = Instance.new("Part")
		p.Size = size
		return finish(p, name, cf, color, material)
	end
	-- Roblox wedge: full height along its +Z edge, sloping down to the -Z bottom edge.
	function kit.wedge(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
		local p = Instance.new("WedgePart")
		p.Size = size
		return finish(p, name, cf, color, material)
	end
	-- An upright cylinder: its axis runs along cf's Y axis.
	function kit.cylinder(
		name: string,
		diameter: number,
		length: number,
		cf: CFrame,
		color: Color3,
		material: Enum.Material?
	): BasePart
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(length, diameter, diameter)
		return finish(p, name, cf * CFrame.Angles(0, 0, math.pi / 2), color, material)
	end
	function kit.ball(name: string, diameter: number, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(diameter, diameter, diameter)
		return finish(p, name, cf, color, material)
	end
	-- A beam of `width` x `depth` from point a to point b (item-local).
	function kit.beam(
		name: string,
		a: Vector3,
		b: Vector3,
		width: number,
		depth: number,
		color: Color3,
		material: Enum.Material?
	): BasePart
		local length = (b - a).Magnitude
		local p = Instance.new("Part")
		p.Size = Vector3.new(width, depth, math.max(length, 0.05))
		return finish(p, name, CFrame.lookAt((a + b) / 2, b), color, material)
	end
	-- At most one light per item; ghosts get none.
	local lit = false
	function kit.light(part: BasePart, color: Color3, range: number?, brightness: number?)
		if ghost or lit then
			return
		end
		lit = true
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = math.clamp(range or 12, 2, 20)
		light.Brightness = math.clamp(brightness or 1.2, 0.1, 3)
		light.Shadows = false
		light.Parent = part
	end
	function kit.fire(part: BasePart, color: Color3?, size: number?)
		if ghost then
			return
		end
		local fire = Instance.new("Fire")
		fire.Color = color or PALETTE.Flame
		fire.SecondaryColor = Color3.fromRGB(255, 220, 120)
		fire.Size = math.clamp(size or 2, 1, 6)
		fire.Heat = 4
		fire.Parent = part
	end

	local ok, problem = pcall(make, kit)
	if not ok then
		warn("[BoatFurniture] " .. id .. " failed to build: " .. tostring(problem))
	end
	model.Parent = parent
	return model
end

-- Rebuilds a hull's placed furniture (model child "Furniture") from saved entries.
function BoatFurniture.dress(model: Model, entries: any)
	local root = model.PrimaryPart
	local old = model:FindFirstChild("Furniture")
	if old then
		old:Destroy()
	end
	if not root or type(entries) ~= "table" then
		return
	end
	local folder = Instance.new("Model")
	folder.Name = "Furniture"
	for index, entry in entries do
		if BoatFurniture.entryShape(entry) and BoatFurniture.Items[entry.Id] then
			local offset = BoatFurniture.localFrame(entry)
			local item = BoatFurniture.build(folder, root.CFrame * offset, entry.Id, { root = root, offset = offset })
			if item then
				item:SetAttribute("Index", index)
			end
		end
	end
	folder.Parent = model
end

-- Shows an item in a ViewportFrame, framed from the front three-quarter.
function BoatFurniture.preview(viewport: ViewportFrame, id: string)
	viewport:ClearAllChildren()
	local item = BoatFurniture.Items[id]
	if not item then
		return
	end
	BoatFurniture.build(viewport, CFrame.identity, id, { anchored = true })
	local size = item.Size
	local radius = math.sqrt(size[1] ^ 2 + size[2] ^ 2 + size[3] ^ 2) / 2
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	local centre = Vector3.new(0, size[2] / 2, 0)
	local distance = radius / math.tan(math.rad(15)) * 1.05
	camera.CFrame = CFrame.lookAt(centre + Vector3.new(0.55, 0.42, -0.72).Unit * distance, centre)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

return BoatFurniture
