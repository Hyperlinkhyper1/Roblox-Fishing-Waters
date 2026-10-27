-- Tide & Tackle, the rod store on the west side of the piazza. Outside it is one of the plaza's
-- two-tone townhouses with a shopfront; its street door leads into a two-level hall built away
-- from the map, with a gallery round three sides under open roof trusses. The hall's exit leads
-- back out onto the square. The same versioned builder repairs saved Studio maps at startup.
local CollectionService = game:GetService("CollectionService")

local LowPoly = require(script.Parent.LowPoly)
local PlazaHouses = require(script.Parent.PlazaHouses)
local Props = require(script.Parent.Props)

local RodShop = {}
local LAYOUT_VERSION = 3
local INTERIOR_VERSION = 6
local TAU = math.pi * 2
local rgb = Color3.fromRGB
local M = Enum.Material

-- 1500 studs past the ocean's edge (Biomes.MapHalfSize is 5200), where nothing else is ever built
local INTERIOR_ORIGIN = CFrame.new(6700, 300, 0)
local W, D = 56, 44 -- inner floor of the hall
local GALLERY = 12 -- height of the gallery deck
local EAVES = 24 -- top of the side walls
local RIDGE = 34

local YELLOW = rgb(244, 196, 76)
local MINT = rgb(156, 214, 192)
local FLOOR_WOOD = rgb(150, 104, 64)
local WOOD = rgb(184, 132, 72)
local BEAM = rgb(150, 100, 52)
local DARK_WOOD = rgb(102, 70, 44)
local GREEN_DOOR = rgb(84, 160, 70)
local DOOR_FRAME = rgb(214, 196, 150)
local WINDOW_FRAME = rgb(58, 112, 52)
local DAYLIGHT = rgb(255, 238, 176)
local CREAM = rgb(255, 245, 213)
local IRON = rgb(50, 57, 57)
local LAMP = rgb(255, 214, 150)
local LEAF = { rgb(86, 170, 60), rgb(110, 196, 70), rgb(70, 146, 52) }

local function interiorFolder(): Folder
	local folder = workspace:FindFirstChild("Interiors")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Interiors"
		folder.Parent = workspace
	end
	return folder :: Folder
end

local function doorPrompt(parent: BasePart, action: string, destination: CFrame): ProximityPrompt
	local prompt = parent:FindFirstChild("RodStoreDoorPrompt") :: ProximityPrompt?
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "RodStoreDoorPrompt"
		prompt.ObjectText = "Tide & Tackle"
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.HoldDuration = 0
		prompt.Parent = parent
	end
	local p = prompt :: ProximityPrompt
	p.ActionText = action
	p:SetAttribute("TeleportTo", destination)
	return p
end

----------------------------------------------------------------------------------------------------
-- Interior

local function buildInterior(): Model
	local o = INTERIOR_ORIGIN
	local hall = Instance.new("Model")
	hall.Name = "RodStoreInterior"
	hall:SetAttribute("LayoutVersion", INTERIOR_VERSION)
	hall:SetAttribute("InteriorFrame", o * CFrame.new(0, RIDGE / 2, 0))
	hall:SetAttribute("InteriorSize", Vector3.new(W, RIDGE, D))
	hall:SetAttribute("ArrivalFrame", o * CFrame.new(0, 3.2, -D / 2 + 5) * CFrame.Angles(0, math.pi, 0))
	-- Stream the whole hall in at once so nobody arrives on a half-loaded floor
	hall.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local rng = Random.new(2811)

	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
		local piece = Props.part(hall, size, o * cf, color, material or M.Wood)
		piece.Name = name
		return piece
	end
	local function deco(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
		local piece = part(name, size, cf, color, material)
		piece.CanCollide = false
		return piece
	end
	local function beam(name: string, a: Vector3, b: Vector3, width: number, color: Color3, thickness: number?): Part
		local piece = Props.beam(hall, o * a, o * b, width, color, thickness, M.Wood)
		piece.Name = name
		return piece
	end
	local function glow(piece: BasePart, color: Color3, range: number, brightness: number)
		Props.light(piece, color, range, brightness)
	end
	-- Frame on a wall's inner face at `pos`, with +Z pointing into the room along `normal`
	local function onWall(pos: Vector3, normal: Vector3): CFrame
		return CFrame.lookAt(pos, pos - normal)
	end
	local function disc(name: string, face: CFrame, diameter: number, thickness: number, color: Color3, material)
		local piece = part(
			name,
			Vector3.new(thickness, diameter, diameter),
			face * CFrame.Angles(0, math.pi / 2, 0),
			color,
			material
		)
		piece.Shape = Enum.PartType.Cylinder
		piece.CanCollide = false
		return piece
	end

	-- Shell: plank floor, yellow lower walls, mint upper walls, gables and a tiled roof
	part("Floor", Vector3.new(W + 2, 1, D + 2), CFrame.new(0, -0.5, 0), FLOOR_WOOD, M.WoodPlanks)
	for i = -3, 3 do
		deco("FloorBoardLine", Vector3.new(0.12, 0.02, D), CFrame.new(i * 8, 0.01, 0), DARK_WOOD, M.Wood)
	end
	for _, side in { -1, 1 } do
		part(
			"SideWallLower",
			Vector3.new(1, GALLERY, D + 2),
			CFrame.new(side * (W / 2 + 0.5), GALLERY / 2, 0),
			YELLOW,
			M.Plaster
		)
		part(
			"SideWallUpper",
			Vector3.new(1, EAVES - GALLERY, D + 2),
			CFrame.new(side * (W / 2 + 0.5), (GALLERY + EAVES) / 2, 0),
			MINT,
			M.Plaster
		)
		part(
			"EndWallLower",
			Vector3.new(W, GALLERY, 1),
			CFrame.new(0, GALLERY / 2, side * (D / 2 + 0.5)),
			YELLOW,
			M.Plaster
		)
		part(
			"EndWallUpper",
			Vector3.new(W, EAVES - GALLERY, 1),
			CFrame.new(0, (GALLERY + EAVES) / 2, side * (D / 2 + 0.5)),
			MINT,
			M.Plaster
		)
		for _, x in { -1, 1 } do
			LowPoly.triangle(
				(o * Vector3.new(x * (W / 2 + 1), EAVES, side * (D / 2 + 0.5))),
				(o * Vector3.new(0, RIDGE + 0.5, side * (D / 2 + 0.5))),
				(o * Vector3.new(0, EAVES, side * (D / 2 + 0.5))),
				o * Vector3.new(0, EAVES, 0),
				MINT,
				hall,
				M.Plaster,
				1
			)
		end
		-- Wainscot and the dado rail round the ground floor
		part("Wainscot", Vector3.new(0.2, 3, D), CFrame.new(side * (W / 2 - 0.1), 1.5, 0), WOOD, M.WoodPlanks)
		part("Wainscot", Vector3.new(W, 3, 0.2), CFrame.new(0, 1.5, side * (D / 2 - 0.1)), WOOD, M.WoodPlanks)
		local slope = math.atan2(RIDGE - EAVES, W / 2)
		local run = math.sqrt((W / 2 + 2) ^ 2 + (RIDGE - EAVES) ^ 2)
		part(
			"Roof",
			Vector3.new(run, 1, D + 4),
			CFrame.new(side * W / 4, (EAVES + RIDGE) / 2 + 0.8, 0) * CFrame.Angles(0, 0, -side * slope),
			rgb(176, 98, 64),
			M.WoodPlanks
		)
	end

	-- Exposed trusses: tie beam, king post, rafters and struts, with purlins along the slopes
	for _, z in { -16, -5.5, 5.5, 16 } do
		beam("TieBeam", Vector3.new(-W / 2, EAVES, z), Vector3.new(W / 2, EAVES, z), 1.1, BEAM)
		beam("KingPost", Vector3.new(0, EAVES, z), Vector3.new(0, RIDGE, z), 0.9, BEAM)
		for _, side in { -1, 1 } do
			beam("Rafter", Vector3.new(side * W / 2, EAVES, z), Vector3.new(0, RIDGE, z), 1, BEAM)
			beam(
				"Strut",
				Vector3.new(0, EAVES + 1, z),
				Vector3.new(side * W / 4, EAVES + (RIDGE - EAVES) / 2, z),
				0.6,
				BEAM
			)
		end
	end
	beam("Ridge", Vector3.new(0, RIDGE, -D / 2), Vector3.new(0, RIDGE, D / 2), 1.1, BEAM)
	for _, side in { -1, 1 } do
		for _, t in { 0.35, 0.7 } do
			local x, y = side * W / 2 * (1 - t), EAVES + (RIDGE - EAVES) * t
			beam("Purlin", Vector3.new(x, y, -D / 2), Vector3.new(x, y, D / 2), 0.7, BEAM)
		end
	end

	-- Gallery decks round the back and sides, held up on posts and edge beams
	local inner = W / 2 - 7
	local backEdge = D / 2 - 8
	part("GalleryBack", Vector3.new(W, 0.8, 8), CFrame.new(0, GALLERY - 0.4, D / 2 - 4), WOOD, M.WoodPlanks)
	for _, side in { -1, 1 } do
		part(
			"GallerySide",
			Vector3.new(7, 0.8, backEdge + 6),
			CFrame.new(side * (inner + 3.5), GALLERY - 0.4, (backEdge - 6) / 2),
			WOOD,
			M.WoodPlanks
		)
		beam(
			"GalleryEdgeBeam",
			Vector3.new(side * inner, GALLERY - 1.2, -6),
			Vector3.new(side * inner, GALLERY - 1.2, backEdge),
			1,
			BEAM
		)
		for _, z in { -6, 4, backEdge } do
			part(
				"GalleryPost",
				Vector3.new(1, GALLERY - 0.8, 1),
				CFrame.new(side * inner, (GALLERY - 0.8) / 2, z),
				BEAM
			)
		end
	end
	beam(
		"GalleryEdgeBeam",
		Vector3.new(-inner, GALLERY - 1.2, backEdge),
		Vector3.new(inner, GALLERY - 1.2, backEdge),
		1,
		BEAM
	)
	for _, x in { -11, 11 } do
		part("GalleryPost", Vector3.new(1, GALLERY - 0.8, 1), CFrame.new(x, (GALLERY - 0.8) / 2, backEdge), BEAM)
	end
	-- Turned balusters under a handrail along every open edge
	local function balustrade(a: Vector3, b: Vector3)
		local length = (b - a).Magnitude
		local dir = (b - a).Unit
		for k = 0, math.floor(length / 1.25) do
			local p = a + dir * (k * 1.25) + Vector3.new(0, GALLERY + 1.5, 0)
			part("Baluster", Vector3.new(0.4, 3, 0.4), CFrame.new(p), WOOD)
			deco("BalusterBulb", Vector3.new(0.65, 0.7, 0.65), CFrame.new(p + Vector3.new(0, -0.3, 0)), WOOD)
		end
		beam("Handrail", a + Vector3.new(0, GALLERY + 3.2, 0), b + Vector3.new(0, GALLERY + 3.2, 0), 0.6, BEAM, 0.45)
		beam("BottomRail", a + Vector3.new(0, GALLERY + 0.2, 0), b + Vector3.new(0, GALLERY + 0.2, 0), 0.5, BEAM, 0.3)
	end
	balustrade(Vector3.new(-inner, 0, backEdge), Vector3.new(inner, 0, backEdge))
	for _, side in { -1, 1 } do
		balustrade(Vector3.new(side * inner, 0, -6), Vector3.new(side * inner, 0, backEdge))
	end
	balustrade(Vector3.new(-W / 2, 0, -6), Vector3.new(-inner, 0, -6))

	-- Stairs up the right-hand wall arrive at the open front end of that gallery
	local steps = 15
	local rise = GALLERY / steps
	for i = 1, steps do
		part(
			"Stair",
			Vector3.new(6.5, i * rise, 1),
			CFrame.new(inner + 3.5, i * rise / 2, -6 - (steps - i) - 0.5),
			WOOD,
			M.WoodPlanks
		)
		deco(
			"StairNosing",
			Vector3.new(6.5, 0.15, 0.2),
			CFrame.new(inner + 3.5, i * rise + 0.02, -6 - (steps - i) - 0.95),
			DARK_WOOD
		)
	end
	beam("StairRail", Vector3.new(inner, 3.2, -6 - steps), Vector3.new(inner, GALLERY + 3.2, -6), 0.5, BEAM, 0.45)
	for k = 0, steps - 1, 2 do
		local y = (k + 1) * rise
		part("StairBaluster", Vector3.new(0.35, 3, 0.35), CFrame.new(inner, y + 1.5, -6 - steps + k + 0.5), WOOD)
	end

	-- Windows of small green panes and arched green doors, as on a harbour warehouse
	local function gridWindow(face: CFrame, width: number, height: number)
		deco(
			"WindowSurround",
			Vector3.new(width + 1, height + 1, 0.2),
			face * CFrame.new(0, 0, 0.1),
			DOOR_FRAME,
			M.Limestone
		)
		deco(
			"WindowArch",
			Vector3.new(0.2, width + 1, width + 1),
			face * CFrame.new(0, height / 2, 0.1) * CFrame.Angles(0, math.pi / 2, 0),
			DOOR_FRAME,
			M.Limestone
		).Shape =
			Enum.PartType.Cylinder
		local pane =
			deco("WindowLight", Vector3.new(width, height, 0.2), face * CFrame.new(0, 0, 0.22), DAYLIGHT, M.Neon)
		disc("WindowLightArch", face * CFrame.new(0, height / 2, 0.22), width, 0.2, DAYLIGHT, M.Neon)
		for i = 1, 3 do
			deco(
				"WindowBar",
				Vector3.new(0.18, height + width / 2, 0.3),
				face * CFrame.new(-width / 2 + i * width / 4, width / 4, 0.36),
				WINDOW_FRAME
			)
		end
		for j = 1, 4 do
			deco(
				"WindowBar",
				Vector3.new(width, 0.18, 0.3),
				face * CFrame.new(0, -height / 2 + j * height / 4, 0.36),
				WINDOW_FRAME
			)
		end
		deco(
			"WindowSill",
			Vector3.new(width + 1.6, 0.35, 0.9),
			face * CFrame.new(0, -height / 2 - 0.5, 0.4),
			DOOR_FRAME,
			M.Limestone
		)
		return pane
	end
	local function archDoor(face: CFrame, width: number, height: number): Part
		deco(
			"DoorSurround",
			Vector3.new(width + 1.6, height, 0.25),
			face * CFrame.new(0, height / 2, 0.12),
			DOOR_FRAME,
			M.Limestone
		)
		disc("DoorSurroundArch", face * CFrame.new(0, height, 0.12), width + 1.6, 0.25, DOOR_FRAME, M.Limestone)
		local leaf = part(
			"DoorLeaf",
			Vector3.new(width, height, 0.3),
			face * CFrame.new(0, height / 2, 0.35),
			GREEN_DOOR,
			M.WoodPlanks
		)
		disc("DoorLeafArch", face * CFrame.new(0, height, 0.35), width, 0.3, GREEN_DOOR, M.WoodPlanks)
		for i = 1, 3 do
			deco(
				"DoorPlank",
				Vector3.new(0.12, height + width / 2 - 0.4, 0.4),
				face * CFrame.new(-width / 2 + i * width / 4, height / 2 + width / 4 - 0.2, 0.42),
				rgb(64, 130, 54)
			)
		end
		for _, y in { 0.25, 0.75 } do
			deco(
				"DoorStrap",
				Vector3.new(width * 0.7, 0.4, 0.45),
				face * CFrame.new(-width * 0.12, height * y, 0.45),
				DOOR_FRAME,
				M.Metal
			)
		end
		deco(
			"DoorHandle",
			Vector3.new(0.4, 1.4, 0.35),
			face * CFrame.new(width * 0.3, height * 0.45, 0.62),
			DOOR_FRAME,
			M.Metal
		)
		return leaf
	end

	-- Front wall: the way out between two tall windows, and windows above the gallery line
	local front = onWall(Vector3.new(0, 0, -D / 2), Vector3.new(0, 0, 1))
	local exit = archDoor(front, 6, 9)
	for _, x in { -14, 14 } do
		local glass = gridWindow(front * CFrame.new(x, 6, 0), 5, 6)
		glow(glass, DAYLIGHT, 16, 0.6)
		gridWindow(front * CFrame.new(x, GALLERY + 5, 0), 4, 4.5)
	end
	gridWindow(front * CFrame.new(-24, 6, 0), 3, 5)
	-- Left wall (its local +X runs toward the front): a green door on each level and windows between
	local left = onWall(Vector3.new(-W / 2, 0, 0), Vector3.new(1, 0, 0))
	archDoor(left * CFrame.new(3, 0, 0), 5, 8)
	archDoor(left * CFrame.new(-4, GALLERY, 0), 4.4, 7.4)
	gridWindow(left * CFrame.new(18, 6, 0), 4, 5.5)
	for _, x in { -11, 14 } do
		gridWindow(left * CFrame.new(x, GALLERY + 5, 0), 4, 4.5)
	end
	-- Right wall (local +X runs toward the back): windows above the stairs and along the gallery
	local right = onWall(Vector3.new(W / 2, 0, 0), Vector3.new(-1, 0, 0))
	for _, x in { -14, 0, 12 } do
		gridWindow(right * CFrame.new(x, GALLERY + 5, 0), 4, 4.5)
	end
	gridWindow(right * CFrame.new(9.5, 6, 0), 4, 5.5)
	-- Back wall upstairs
	local back = onWall(Vector3.new(0, 0, D / 2), Vector3.new(0, 0, -1))
	archDoor(back * CFrame.new(0, GALLERY, 0), 4.4, 7.4)
	for _, x in { -14, 14 } do
		gridWindow(back * CFrame.new(x, GALLERY + 5, 0), 4, 4.5)
	end

	-- Glowing brick alcove at the back, where the store keeps its prize rod
	local alcove = back
	for _, x in { -4.2, 4.2 } do
		part("AlcovePier", Vector3.new(1.6, 9, 1.6), alcove * CFrame.new(x, 4.5, 0.8), rgb(196, 176, 150), M.Brick)
	end
	part("AlcoveHeader", Vector3.new(10, 1.6, 1.6), alcove * CFrame.new(0, 9.8, 0.8), rgb(196, 176, 150), M.Brick)
	local alcoveGlow =
		deco("AlcoveGlow", Vector3.new(6.8, 8.8, 0.2), alcove * CFrame.new(0, 4.4, 0.15), rgb(214, 96, 196), M.Neon)
	glow(alcoveGlow, rgb(232, 110, 214), 14, 0.6)
	part("AlcovePlinth", Vector3.new(3, 2.4, 2), alcove * CFrame.new(0, 1.2, 1.4), rgb(120, 110, 130), M.Slate)
	local prizeBase = alcove * CFrame.new(0, 2.4, 1.4)
	beam(
		"PrizeRodBlank",
		(prizeBase * CFrame.new(-0.4, 0.3, 0)).Position,
		(prizeBase * CFrame.new(0.8, 6.6, 0)).Position,
		0.18,
		rgb(255, 196, 60)
	).Material =
		M.Neon
	beam(
		"PrizeRodGrip",
		(prizeBase * CFrame.new(-0.6, 0, 0)).Position,
		(prizeBase * CFrame.new(-0.3, 1.6, 0)).Position,
		0.35,
		DARK_WOOD
	)

	-- The counter, with racks of rods behind it under the back gallery
	part("CounterBase", Vector3.new(16, 3.2, 2.6), CFrame.new(0, 1.6, backEdge - 6), rgb(70, 126, 110), M.WoodPlanks)
	part("CounterTop", Vector3.new(16.6, 0.35, 3.2), CFrame.new(0, 3.37, backEdge - 6), WOOD)
	for _, x in { -6, -2, 2, 6 } do
		deco(
			"CounterPanel",
			Vector3.new(3.2, 2.2, 0.12),
			CFrame.new(x, 1.6, backEdge - 7.35),
			rgb(58, 104, 92),
			M.WoodPlanks
		)
	end
	local menu =
		deco("RodPriceBoard", Vector3.new(6, 1.4, 0.15), CFrame.new(0, 8.8, backEdge - 4.2), DARK_WOOD, M.WoodPlanks)
	PlazaHouses.boardText(menu, "ROD UPGRADES", Enum.NormalId.Front)
	for _, x in { -2.9, 2.9 } do
		deco("BoardHanger", Vector3.new(0.12, 2.5, 0.12), CFrame.new(x, 10.75, backEdge - 4.2), IRON, M.Metal)
	end
	-- A brass bell and a ledger on the counter
	deco("CounterBell", Vector3.new(0.8, 0.6, 0.8), CFrame.new(5.5, 3.85, backEdge - 6), rgb(214, 170, 70), M.Metal).Shape =
		Enum.PartType.Ball
	deco(
		"Ledger",
		Vector3.new(1.8, 0.25, 1.3),
		CFrame.new(-5, 3.67, backEdge - 6) * CFrame.Angles(0, 0.25, 0),
		rgb(120, 40, 36),
		M.Fabric
	)

	local rodColors = { rgb(64, 103, 89), rgb(183, 81, 51), rgb(47, 81, 118), rgb(175, 134, 62), rgb(120, 70, 140) }
	local function rodRack(face: CFrame, count: number)
		local width = count * 1.6 + 1
		part("RackBase", Vector3.new(width, 1.2, 1.4), face * CFrame.new(0, 0.6, 0.8), DARK_WOOD)
		deco("RackRail", Vector3.new(width, 0.35, 0.5), face * CFrame.new(0, 7.2, 0.35), DARK_WOOD)
		for _, x in { -width / 2, width / 2 } do
			part("RackSide", Vector3.new(0.4, 8, 1.4), face * CFrame.new(x, 4, 0.8), DARK_WOOD)
		end
		for i = 1, count do
			local x = -width / 2 + 0.5 + (i - 0.5) * 1.6
			local color = rodColors[(i - 1) % #rodColors + 1]
			local foot = face * Vector3.new(x, 1.2, 0.9)
			local tip = face * Vector3.new(x + 0.3, 10.5, 0.35)
			Props.beam(hall, o * foot, o * tip, 0.14, color, nil, M.SmoothPlastic).CanCollide = false
			Props.beam(hall, o * foot, o * (face * Vector3.new(x + 0.05, 3, 0.85)), 0.3, rgb(196, 150, 96), nil, M.Wood).CanCollide =
				false
			deco("RackReel", Vector3.new(0.45, 0.6, 0.4), face * CFrame.new(x, 3.4, 1.15), IRON, M.Metal)
		end
	end
	rodRack(back * CFrame.new(-11.5, 0, 0), 7)
	rodRack(back * CFrame.new(11.5, 0, 0), 7)
	rodRack(left * CFrame.new(-16.5, 0, 0), 6)
	rodRack(right * CFrame.new(0, 0, 0), 6)

	-- Tackle shelves and a bookcase of fishing almanacs
	local function shelves(face: CFrame, width: number, height: number, tiers: number)
		for _, x in { -width / 2, width / 2 } do
			part("ShelfSide", Vector3.new(0.35, height, 1.8), face * CFrame.new(x, height / 2, 0.9), DARK_WOOD)
		end
		deco("ShelfBack", Vector3.new(width, height, 0.15), face * CFrame.new(0, height / 2, 0.08), WOOD, M.WoodPlanks)
		for t = 0, tiers do
			local y = 0.3 + t * (height - 0.6) / tiers
			part("Shelf", Vector3.new(width, 0.25, 1.8), face * CFrame.new(0, y, 0.9), DARK_WOOD)
			if t == tiers then
				continue
			end
			local x = -width / 2 + 0.5
			while x < width / 2 - 0.6 do
				local roll = rng:NextNumber()
				if roll < 0.55 then
					local bookW = rng:NextNumber(0.35, 0.6)
					local bookH = rng:NextNumber(1.2, 1.8)
					deco(
						"Book",
						Vector3.new(bookW, bookH, 1.3),
						face * CFrame.new(x + bookW / 2, y + 0.12 + bookH / 2, 0.9),
						Props.pick(rng, rodColors),
						M.Fabric
					)
					x += bookW + 0.05
				elseif roll < 0.8 then
					deco(
						"TackleTin",
						Vector3.new(1.1, 0.7, 1.2),
						face * CFrame.new(x + 0.55, y + 0.47, 0.9),
						Props.pick(rng, { rgb(70, 126, 110), rgb(190, 152, 100), rgb(170, 70, 50) }),
						M.SmoothPlastic
					)
					x += 1.2
				else
					local coins = deco(
						"GoldCoins",
						Vector3.new(0.4, 1, 1),
						face * CFrame.new(x + 0.5, y + 0.3, 0.9) * CFrame.Angles(0, 0, math.pi / 2),
						rgb(244, 198, 60),
						M.Metal
					)
					coins.Shape = Enum.PartType.Cylinder
					x += 1.1
				end
			end
		end
	end
	shelves(right * CFrame.new(16, 0, 0), 5, 7.5, 4)
	shelves(left * CFrame.new(11, 0, 0), 4.5, 6, 3)

	-- Floor props: a bench, barrels, crate stacks, display pedestals and a long rug down the aisle
	local function at(x: number, z: number, y: number?): Vector3
		return o * Vector3.new(x, y or 0, z)
	end
	Props.bench(hall, at(-W / 2 + 2.2, 4.5), math.pi / 2)
	for _, p in { { -W / 2 + 2, 9.2 }, { -W / 2 + 4.4, 10 }, { inner - 2, -16 } } do
		Props.barrel(hall, at(p[1], p[2]), rng)
	end
	Props.crates(hall, at(inner - 2, 10), rng)
	Props.crates(hall, at(-inner + 2, -19), rng)
	deco("AisleRug", Vector3.new(7, 0.06, 24), CFrame.new(0, 0.03, -8), rgb(170, 66, 52), M.Fabric)
	deco("AisleRugBorder", Vector3.new(8, 0.04, 25), CFrame.new(0, 0.02, -8), rgb(222, 180, 90), M.Fabric)
	-- A plain wooden crate with an empty inside and a separate hinged lid. Its prompt opens the
	-- crate window; FishingService checks the angler is standing at it.
	-- Bobbers take the opposite side of the aisle, facing the rod cases.
	for _, bobberCase in { false, true } do
		local kind = if bobberCase then "Bobber" else "Rod"
		local stand = CFrame.new(if bobberCase then -10 else 10, 0, -6)
			* CFrame.Angles(0, if bobberCase then -math.pi / 2 else math.pi / 2, 0)
		part("CratePlinth", Vector3.new(3.4, 0.8, 3), stand * CFrame.new(0, 0.4, 0), rgb(120, 116, 112), M.Slate)
		local display = Instance.new("Model")
		display.Name = kind .. "CrateDisplay"
		display:SetAttribute("CrateFrame", o * stand)
		display:SetAttribute("LidHinge", o * stand * CFrame.new(0, 2.4, 0.9))
		display.Parent = hall
		local function cratePart(name: string, size: Vector3, offset: CFrame, color: Color3): Part
			local piece = part(name, size, stand * offset, color, M.WoodPlanks)
			piece.CanQuery = false
			piece.Parent = display
			return piece
		end
		cratePart("CrateBottom", Vector3.new(2.6, 0.18, 1.8), CFrame.new(0, 0.89, 0), DARK_WOOD)
		local crate = cratePart(kind .. "Crate", Vector3.new(2.6, 1.42, 0.16), CFrame.new(0, 1.69, -0.82), WOOD)
		crate.CanQuery = true
		cratePart("CrateBack", Vector3.new(2.6, 1.42, 0.16), CFrame.new(0, 1.69, 0.82), WOOD)
		for _, x in { -1.22, 1.22 } do
			cratePart("CrateSide", Vector3.new(0.16, 1.42, 1.48), CFrame.new(x, 1.69, 0), WOOD)
		end
		for _, x in { -1.05, 1.05 } do
			for _, z in { -0.93, 0.93 } do
				cratePart("CrateBrace", Vector3.new(0.16, 1.6, 0.1), CFrame.new(x, 1.6, z), DARK_WOOD)
			end
		end
		local lid = Instance.new("Model")
		lid.Name = kind .. "CrateLid"
		lid.Parent = display
		local board = cratePart("LidBoard", Vector3.new(2.7, 0.2, 1.9), CFrame.new(0, 2.5, 0), WOOD)
		board.CanCollide = false
		board.Parent = lid
		lid.PrimaryPart = board
		for _, x in { -1.05, 1.05 } do
			local brace = cratePart("LidBrace", Vector3.new(0.16, 0.08, 1.9), CFrame.new(x, 2.64, 0), DARK_WOOD)
			brace.CanCollide = false
			brace.Parent = lid
		end
		local sign = deco(
			kind .. "CrateSign",
			Vector3.new(3, 0.8, 0.12),
			stand * CFrame.new(0, 4.4, 0.6),
			DARK_WOOD,
			M.WoodPlanks
		)
		sign.CanQuery = false
		PlazaHouses.boardText(
			sign,
			if bobberCase then "BOBBERS\n$350" else "ROD CRATES\n$350 / $750",
			Enum.NormalId.Front
		)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Open" .. kind .. "CratePrompt"
		prompt.ActionText = if bobberCase then "Open case" else "Open crates"
		prompt.ObjectText = if bobberCase then "Bobbers · $350" else "Rod Crates"
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.HoldDuration = 0
		prompt.Parent = crate
	end

	-- Up on the gallery: potted palms, barrels and crates
	local function pottedPalm(x: number, z: number)
		local base = at(x, z, GALLERY)
		Props.cylinder(hall, base + Vector3.new(0, 1, 0), 2, 2.6, rgb(184, 96, 60), M.Sandstone)
		local top = base + Vector3.new(rng:NextNumber(-0.6, 0.6), 7, rng:NextNumber(-0.6, 0.6))
		Props.beam(hall, base + Vector3.new(0, 1.5, 0), top, 0.6, rgb(130, 100, 70), nil, M.Wood).CanCollide = false
		for f = 1, 7 do
			local a = f / 7 * TAU + rng:NextNumber(-0.2, 0.2)
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local mid = top + dir * 2.4 + Vector3.new(0, 0.8, 0)
			local tip = top + dir * 4.6 + Vector3.new(0, -1.2, 0)
			Props.beam(hall, top, mid, 1.3, Props.pick(rng, LEAF), 0.15, M.LeafyGrass).CanCollide = false
			Props.beam(hall, mid, tip, 1.1, Props.pick(rng, LEAF), 0.15, M.LeafyGrass).CanCollide = false
		end
	end
	for _, p in { { -18, D / 2 - 3 }, { 18, D / 2 - 3 }, { -W / 2 + 3, 0 }, { W / 2 - 3, 8 } } do
		pottedPalm(p[1], p[2])
	end
	for _, p in { { -8, D / 2 - 2.5 }, { -5.5, D / 2 - 2 }, { 24, D / 2 - 2.5 }, { -W / 2 + 2.5, 9 } } do
		Props.barrel(hall, at(p[1], p[2], GALLERY), rng)
	end
	Props.crates(hall, at(8, D / 2 - 3, GALLERY), rng)
	Props.crates(hall, at(-24, D / 2 - 3, GALLERY), rng)
	Props.crates(hall, at(W / 2 - 3, -2, GALLERY), rng)

	-- Hanging lanterns from the tie beams, and a lamp under each gallery post
	for _, z in { -16, -5.5, 5.5 } do
		for _, x in { -10, 10 } do
			local hook = Vector3.new(x, EAVES - 0.5, z)
			deco("LanternChain", Vector3.new(0.12, 5, 0.12), CFrame.new(hook - Vector3.new(0, 2.5, 0)), IRON, M.Metal)
			local lantern = Props.lantern(hall, o * CFrame.new(hook - Vector3.new(0, 6.6, 0)), 14, 0.6)
			for _, piece in lantern:GetChildren() do
				if piece:IsA("BasePart") then
					piece.CanCollide = false
				end
			end
		end
	end
	for _, p in { { -inner, -6 }, { inner, 4 }, { -inner, 4 }, { -11, backEdge }, { 11, backEdge } } do
		local lantern = Props.lantern(hall, o * CFrame.new(p[1], GALLERY - 3, p[2] - 0.9), 14, 0.6)
		for _, piece in lantern:GetChildren() do
			if piece:IsA("BasePart") then
				piece.CanCollide = false
			end
		end
	end

	-- The exit leads back through the green door; RodShop.build links it to the square
	exit.Name = "ExitDoor"
	CollectionService:AddTag(hall, "FishingRodShop")
	hall.Parent = interiorFolder()
	return hall
end

-- Finn stands centered behind the counter, facing the door below the upgrade sign.
-- FishingService dresses and places him at startup; the frame is at his soles.
local KEEPER_FRAME = INTERIOR_ORIGIN * CFrame.new(0, 0, D / 2 - 8 - 2.8)

-- Crab cages on a pallet left of the aisle, a spare on the floor in front and a
-- few loose floats. Built onto saved halls too, so it needs no interior rebuild.
-- FishingService sells one cage per BuyCrabCagePrompt at the price on the sign.
local function ensureCrabCageStand(hall: Model)
	if hall:FindFirstChild("CrabCageStand") then
		return
	end
	local stand = Instance.new("Model")
	stand.Name = "CrabCageStand"
	-- Local +Z faces the aisle; the cages' long sides run along the hall.
	local base = INTERIOR_ORIGIN * CFrame.new(-15, 0, 2) * CFrame.Angles(0, math.pi / 2, 0)
	local pallet = Props.part(stand, Vector3.new(6.8, 0.5, 3.4), base * CFrame.new(0, 0.25, 0), WOOD, M.WoodPlanks)
	pallet.Name = "Pallet"
	for _, x in { -2.9, 0, 2.9 } do
		Props.part(stand, Vector3.new(0.6, 0.12, 3.4), base * CFrame.new(x, 0.56, 0), DARK_WOOD, M.Wood).CanCollide =
			false
	end
	for _, x in { -1.65, 1.65 } do
		Props.crabCage(stand, base * CFrame.new(x, 0.62, 0))
	end
	Props.crabCage(stand, base * CFrame.new(-1.4, 0, 3.6) * CFrame.Angles(0, 0.45, 0))
	for index, offset in { CFrame.new(2.2, 0.45, 3), CFrame.new(3, 0.45, 3.6), CFrame.new(2.6, 1.3, 3.3) } do
		local floatPart = Props.part(
			stand,
			Vector3.new(1.1, 0.9, 0.9),
			base * offset * CFrame.Angles(0, index * 0.7, 0),
			rgb(240, 112, 38),
			M.SmoothPlastic
		)
		floatPart.Name = "SpareFloat"
		floatPart.Shape = Enum.PartType.Cylinder
		floatPart.CanCollide = false
	end
	for _, x in { -2.6, 2.6 } do
		Props.part(stand, Vector3.new(0.3, 5, 0.3), base * CFrame.new(x, 2.5, -1.9), DARK_WOOD, M.Wood)
	end
	local sign = Props.part(
		stand,
		Vector3.new(5.6, 1.5, 0.15),
		base * CFrame.new(0, 4.6, -1.85) * CFrame.Angles(0, math.pi, 0),
		DARK_WOOD,
		M.WoodPlanks
	)
	sign.Name = "CrabCageSign"
	sign.CanCollide, sign.CanQuery = false, false
	PlazaHouses.boardText(sign, "CRAB CAGES\n$35 · 3 HAULS", Enum.NormalId.Front)
	-- The prompt hangs over the pallet, where nothing blocks the shop's sightline check.
	local anchor = Props.part(stand, Vector3.new(1, 1, 1), base * CFrame.new(0, 3.4, 0.4), WOOD)
	anchor.Name = "CrabCagePromptAnchor"
	anchor.Transparency, anchor.CanCollide, anchor.CastShadow = 1, false, false
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyCrabCagePrompt"
	prompt.ActionText = "Buy · $35"
	prompt.ObjectText = "Crab Cage"
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0.35
	prompt.Parent = anchor
	stand.Parent = hall
end

local function ensureInterior(): Model
	local existing = interiorFolder():FindFirstChild("RodStoreInterior")
	local hall: Model
	if existing and existing:IsA("Model") and existing:GetAttribute("LayoutVersion") == INTERIOR_VERSION then
		hall = existing
	else
		if existing then
			existing:Destroy()
		end
		hall = buildInterior()
	end
	-- Refresh saved interiors too, without rebuilding the shop for a sign change.
	local cratePrompt = hall:FindFirstChild("OpenRodCratePrompt", true)
	if cratePrompt and cratePrompt:IsA("ProximityPrompt") then
		cratePrompt.ObjectText = "Rod Crates"
	end
	local crateSign = hall:FindFirstChild("RodCrateSign", true)
	if crateSign then
		for _, item in crateSign:GetDescendants() do
			if item:IsA("TextLabel") then
				item.Text = "ROD CRATES\n$350 / $750"
			end
		end
	end
	ensureCrabCageStand(hall)
	hall:SetAttribute("KeeperFrame", KEEPER_FRAME)
	CollectionService:AddTag(hall, "FishingRodShop")
	return hall
end

----------------------------------------------------------------------------------------------------
-- Storefront on the square

-- Front on local +Z; turned so the door faces the fountain, clear of the cafe tables to the south.
function RodShop.build(plaza: Model, plazaFrame: CFrame): Model
	local hall = ensureInterior()
	local existing = plaza:FindFirstChild("FishingRodShop")
	local shop: Model
	if existing and existing:IsA("Model") and existing:GetAttribute("LayoutVersion") == LAYOUT_VERSION then
		shop = existing
	else
		if existing then
			existing:Destroy()
		end
		local base = plazaFrame * CFrame.new(-45, 0, 35) * CFrame.Angles(0, math.pi / 2, 0)
		local rng = Random.new(4242)
		local doorFace, leaf
		shop, doorFace, leaf = PlazaHouses.house(plaza, base, {
			width = 22,
			depth = 18,
			stories = 2,
			lower = rgb(244, 232, 206),
			upper = rgb(86, 146, 200),
			trim = rgb(250, 242, 224),
			shutter = rgb(120, 80, 52),
			roof = rgb(170, 84, 52),
			door = rgb(176, 70, 52),
			balcony = true,
			shop = "TIDE & TACKLE",
			blade = "RODS",
			signColor = CREAM,
			-- The door takes the end nearer the bay, clear of the cafe tables
			doorSide = -1,
		}, rng)
		shop.Name = "FishingRodShop"
		shop:SetAttribute("LayoutVersion", LAYOUT_VERSION)
		-- A promenade palm this close would push its fronds through the walls
		for _, palm in plaza:GetChildren() do
			local trunk = palm:IsA("Model") and palm.Name == "Palm" and palm:FindFirstChildWhichIsA("BasePart")
			if trunk then
				local p = base:PointToObjectSpace(trunk.Position)
				local dx, dz = math.max(math.abs(p.X) - 11, 0), math.max(math.abs(p.Z) - 9, 0)
				if dx * dx + dz * dz < 100 then
					palm:Destroy()
				end
			end
		end
		leaf.Name = "StreetDoor"
		shop:SetAttribute("ExitFrame", doorFace * CFrame.new(0, 3.2, 4.5) * CFrame.Angles(0, math.pi, 0))
		-- A chalkboard on the step tells new anglers what is inside
		local board = doorFace * CFrame.new(-5, 0, 4)
		local panel
		for _, side in { -1, 1 } do
			-- The two leaves lean together at the top
			panel = Props.part(
				shop,
				Vector3.new(2.6, 3.6, 0.2),
				board * CFrame.new(0, 1.7, side * 0.55) * CFrame.Angles(-side * 0.3, 0, 0),
				rgb(60, 52, 44),
				M.Wood
			)
		end
		local slate = Props.part(
			shop,
			Vector3.new(2.2, 2.6, 0.06),
			panel.CFrame * CFrame.new(0, 0.2, 0.13),
			rgb(36, 44, 40),
			M.Slate
		)
		slate.CanCollide = false
		PlazaHouses.boardText(slate, "ROD\nUPGRADES\n& CRATES\ninside", Enum.NormalId.Back)
	end
	-- Link both doors every startup, so a rebuilt square and a saved hall always agree
	local leaf = shop:FindFirstChild("StreetDoor", true)
	local arrival = hall:GetAttribute("ArrivalFrame")
	local exitFrame = shop:GetAttribute("ExitFrame")
	if leaf and leaf:IsA("BasePart") and typeof(arrival) == "CFrame" then
		doorPrompt(leaf, "Enter", arrival)
	end
	local exit = hall:FindFirstChild("ExitDoor", true)
	if exit and exit:IsA("BasePart") and typeof(exitFrame) == "CFrame" then
		doorPrompt(exit, "Leave", exitFrame)
	end
	CollectionService:RemoveTag(shop, "FishingRodShop")
	return shop
end

function RodShop.ensure(root: Instance)
	for _, plaza in root:GetDescendants() do
		if plaza:IsA("Model") and plaza.Name == "Plaza" then
			local frame = PlazaHouses.pavingFrame(plaza)
			if frame then
				RodShop.build(plaza, frame)
			end
		end
	end
end

return RodShop
