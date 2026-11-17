-- Kitchen fixtures for the Supermarket path: the processing room's cooking stations,
-- the shop's supermarket shelves and the cooked dishes themselves. Local +Z is the
-- side the cook (or a customer at the shelves) stands on; the floor is y=0.
--
-- Placed kitchen furniture fills two grid cells end to end (FurnitureCatalog),
-- so a run of counters meets in one continuous worktop. The two built-in prep
-- benches keep their shorter BUILT_IN_WIDTH.
local Props = require(script.Parent.Props)

local Kitchen = {}
local rgb = Color3.fromRGB
local M = Enum.Material
local STEEL = rgb(186, 192, 196)
local DARK_STEEL = rgb(62, 68, 72)
local CABINET = rgb(222, 226, 226)
local BLACK = rgb(32, 32, 34)
local WOOD = rgb(148, 108, 70)
local LIGHT_WOOD = rgb(206, 170, 118)
local PLATE = rgb(244, 244, 238)
local TILE = rgb(236, 240, 238)
local GROUT = rgb(196, 202, 200)
local CHARRED = rgb(52, 40, 32)
local SALMON = rgb(240, 132, 96)

Kitchen.WIDTH = 9
Kitchen.BUILT_IN_WIDTH = 6
Kitchen.DEPTH = 2.4
Kitchen.TOP = 3.1
Kitchen.CASE_WIDTH = 9
Kitchen.CASE_DEPTH = 2.6
Kitchen.CASE_SHELF = 0.55
-- Where a cooking fish or finished dish sits, in station-local studs.
Kitchen.WORK_SPOT = CFrame.new(0.6, Kitchen.TOP + 0.02, 0.15)
-- Both supermarket gondolas have three open shelves with two dishes per tier.
-- FoodCase keeps its original two-cell footprint and inventory identity for saves.
Kitchen.SHELF_WIDTH = 4.4
Kitchen.SHELF_DEPTH = 2.2
Kitchen.SHELF_HEIGHT = 5.4
local SHELF_LEVELS = { 0.55, 1.85, 3.15 }
local CASE_LEVELS = { Kitchen.CASE_SHELF, 2.15, 3.75 }
local CASE_COLUMNS = { -2.25, 2.25 }
local SHELF_COLUMNS = { -1.05, 1.05 }
Kitchen.CASE_SPOTS = {}
Kitchen.SHELF_SPOTS = {}
for _, y in CASE_LEVELS do
	for _, x in CASE_COLUMNS do
		table.insert(Kitchen.CASE_SPOTS, CFrame.new(x, y + 0.1, 0.25))
	end
end
for _, y in SHELF_LEVELS do
	for _, x in SHELF_COLUMNS do
		table.insert(Kitchen.SHELF_SPOTS, CFrame.new(x, y + 0.1, 0.25))
	end
end
-- Eight fish spots in the iced pans of the kitchen storage counter: four across, two deep.
local STORAGE_COLUMNS = { -3.15, -1.05, 1.05, 3.15 }
Kitchen.STORAGE_SPOTS = {}
for _, z in { -0.5, 0.45 } do
	for _, x in STORAGE_COLUMNS do
		table.insert(Kitchen.STORAGE_SPOTS, CFrame.new(x, Kitchen.TOP + 0.05, z))
	end
end

local function builder(parent: Instance, name: string, frame: CFrame)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	local function piece(
		label: string,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		material: Enum.Material?,
		solid: boolean?
	): Part
		local result = Props.part(model, size, frame * offset, color, material)
		result.Name = label
		if not solid then
			result.CanCollide = false
			result.CanQuery = false
		end
		return result
	end
	-- An upright cylinder standing on `offset`'s height (its centre).
	local function round(label: string, height: number, diameter: number, offset: CFrame, color: Color3, material: Enum.Material?): Part
		local result = piece(label, Vector3.new(height, diameter, diameter), offset * CFrame.Angles(0, 0, math.pi / 2), color, material)
		result.Shape = Enum.PartType.Cylinder
		return result
	end
	local function ball(label: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): Part
		local result = piece(label, size, offset, color, material)
		result.Shape = Enum.PartType.Ball
		return result
	end
	return model, piece, round, ball
end

-- The cabinet run every station shares: a recessed plinth, a top drawer row over
-- hinged doors, an overhanging worktop and a tiled upstand. `open` leaves the
-- doors off one end, from x = open[1] to open[2], for an open shelf bay.
local function counter(piece, width: number, top: Color3, topMaterial: Enum.Material, body: Color3, open: { number }?)
	local d, h = Kitchen.DEPTH, Kitchen.TOP
	local front = d / 2
	local face = body:Lerp(Color3.new(1, 1, 1), 0.12)
	piece("Plinth", Vector3.new(width - 0.1, 0.3, d - 0.3), CFrame.new(0, 0.15, -0.15), DARK_STEEL, M.Metal, true)
	local bays = math.max(2, math.floor(width / 1.5 + 0.5))
	local bay = (width - 0.2) / bays
	local function isOpen(x: number): boolean
		return open ~= nil and x > open[1] and x < open[2]
	end
	-- The carcass stops where the open bay starts; the bay gets a back, a floor and an end.
	local carcassEnd = width / 2
	for index = 1, bays do
		local x = -width / 2 + 0.1 + (index - 0.5) * bay
		if isOpen(x) then
			carcassEnd = x - bay / 2
			break
		end
	end
	local carcass = carcassEnd + width / 2 - 0.02
	piece("Cabinet", Vector3.new(carcass, h - 0.52, d - 0.02), CFrame.new(-width / 2 + 0.02 + carcass / 2, 0.3 + (h - 0.52) / 2, -0.01), body, M.SmoothPlastic, true)
	if carcassEnd < width / 2 then
		local bayWidth = width / 2 - carcassEnd
		local x = carcassEnd + bayWidth / 2
		local shade = body:Lerp(Color3.new(0, 0, 0), 0.45)
		piece("BayBack", Vector3.new(bayWidth, h - 0.52, 0.1), CFrame.new(x, 0.3 + (h - 0.52) / 2, -d / 2 + 0.06), shade, M.SmoothPlastic, true)
		piece("BayFloor", Vector3.new(bayWidth, 0.1, d - 0.1), CFrame.new(x, 0.35, 0), shade, M.SmoothPlastic, true)
		piece("BayEnd", Vector3.new(0.1, h - 0.52, d - 0.02), CFrame.new(width / 2 - 0.07, 0.3 + (h - 0.52) / 2, -0.01), body, M.SmoothPlastic, true)
	end
	piece("Worktop", Vector3.new(width, 0.22, d + 0.12), CFrame.new(0, h - 0.11, 0.06), top, topMaterial, true)
	piece("WorktopEdge", Vector3.new(width, 0.08, 0.04), CFrame.new(0, h - 0.18, front + 0.13), DARK_STEEL, M.Metal)
	piece("Upstand", Vector3.new(width, 0.9, 0.08), CFrame.new(0, h + 0.45, -front + 0.04), TILE, M.CeramicTiles, true)
	for _, y in { 0.3, 0.6 } do
		piece("UpstandGrout", Vector3.new(width - 0.02, 0.025, 0.02), CFrame.new(0, h + y, -front + 0.09), GROUT, M.SmoothPlastic)
	end
	piece("UpstandCap", Vector3.new(width, 0.06, 0.14), CFrame.new(0, h + 0.93, -front + 0.07), top, topMaterial)
	-- Doors and drawers in matching bays across the run.
	for index = 1, bays do
		local x = -width / 2 + 0.1 + (index - 0.5) * bay
		local inOpenBay = isOpen(x)
		piece("Drawer", Vector3.new(bay - 0.1, 0.42, 0.05), CFrame.new(x, h - 0.5, front + 0.005), face, M.SmoothPlastic)
		piece("DrawerPull", Vector3.new(math.min(0.7, bay * 0.45), 0.06, 0.06), CFrame.new(x, h - 0.5, front + 0.06), DARK_STEEL, M.Metal)
		if not inOpenBay then
			piece("CabinetDoor", Vector3.new(bay - 0.1, h - 1.25, 0.05), CFrame.new(x, 0.3 + (h - 1.25) / 2 + 0.06, front + 0.005), face, M.SmoothPlastic)
			piece("DoorPanel", Vector3.new(bay - 0.42, h - 1.65, 0.03), CFrame.new(x, 0.3 + (h - 1.25) / 2 + 0.06, front + 0.035), body, M.SmoothPlastic)
			local side = if index % 2 == 0 then -1 else 1
			piece("DoorHandle", Vector3.new(0.06, 0.55, 0.06), CFrame.new(x + side * (bay / 2 - 0.22), 1.75, front + 0.08), DARK_STEEL, M.Metal)
		end
	end
end

-- A row of hooks on the upstand with kitchen tools hanging from them.
local function utensils(piece, round, x: number, count: number)
	local back = -Kitchen.DEPTH / 2 + 0.14
	piece("UtensilRail", Vector3.new(count * 0.42 + 0.2, 0.05, 0.05), CFrame.new(x, Kitchen.TOP + 0.82, back), STEEL, M.Metal)
	for index = 1, count do
		local ux = x + (index - (count + 1) / 2) * 0.42
		piece("UtensilHandle", Vector3.new(0.05, 0.5, 0.04), CFrame.new(ux, Kitchen.TOP + 0.55, back + 0.02), DARK_STEEL, M.Metal)
		if index % 2 == 0 then
			piece("Spatula", Vector3.new(0.22, 0.22, 0.02), CFrame.new(ux, Kitchen.TOP + 0.22, back + 0.02), STEEL, M.Metal)
		else
			round("Ladle", 0.1, 0.24, CFrame.new(ux, Kitchen.TOP + 0.26, back + 0.08), STEEL, M.Metal)
		end
	end
end

function Kitchen.buildStation(parent: Instance, frame: CFrame, station: string, width: number?): Model
	if station == "KitchenStorage" then
		return Kitchen.buildStorage(parent, frame)
	end
	local w = width or Kitchen.WIDTH
	local top, back = Kitchen.TOP, -Kitchen.DEPTH / 2
	local model, piece, round, ball = builder(parent, station, frame)
	if station == "Prep" then
		counter(piece, w, STEEL, M.Metal, CABINET)
		-- A deep sink with a drainer at the left end.
		local sinkX = -w / 2 + 1.25
		piece("SinkRim", Vector3.new(1.8, 0.04, 1.6), CFrame.new(sinkX, top + 0.01, 0), STEEL, M.Metal)
		piece("SinkBasin", Vector3.new(1.5, 0.05, 1.3), CFrame.new(sinkX, top + 0.02, 0), DARK_STEEL, M.Metal)
		round("Drain", 0.02, 0.2, CFrame.new(sinkX, top + 0.05, 0), BLACK, M.Metal)
		round("Tap", 0.9, 0.12, CFrame.new(sinkX, top + 0.45, back + 0.35), STEEL, M.Metal)
		piece("Spout", Vector3.new(0.1, 0.1, 0.65), CFrame.new(sinkX, top + 0.86, back + 0.62), STEEL, M.Metal)
		for _, side in { -1, 1 } do
			round("TapHandle", 0.08, 0.16, CFrame.new(sinkX + side * 0.25, top + 0.12, back + 0.35), STEEL, M.Metal)
		end
		for index = 0, 2 do
			piece("DrainerRib", Vector3.new(0.04, 0.02, 1.2), CFrame.new(sinkX + 1.0 + index * 0.15, top + 0.01, 0), DARK_STEEL, M.Metal)
		end
		-- The board the fish is cut on, with a knife and a bowl beside it.
		piece("CuttingBoard", Vector3.new(2.2, 0.1, 1.35), CFrame.new(0.6, top + 0.05, 0.1), LIGHT_WOOD, M.Wood)
		piece("KnifeBlade", Vector3.new(0.8, 0.02, 0.14), CFrame.new(1.25, top + 0.11, 0.6) * CFrame.Angles(0, 0.2, 0), STEEL, M.Metal)
		piece("KnifeHandle", Vector3.new(0.4, 0.06, 0.1), CFrame.new(1.8, top + 0.12, 0.49) * CFrame.Angles(0, 0.2, 0), BLACK, M.SmoothPlastic)
		piece("KnifeBlock", Vector3.new(0.45, 0.65, 0.5), CFrame.new(w / 2 - 0.55, top + 0.32, back + 0.45), WOOD, M.Wood)
		for index = -1, 1 do
			piece("KnifeHilt", Vector3.new(0.07, 0.3, 0.1), CFrame.new(w / 2 - 0.55 + index * 0.12, top + 0.78, back + 0.42), BLACK, M.SmoothPlastic)
		end
		if w >= 8 then
			round("MixingBowl", 0.3, 0.8, CFrame.new(w / 2 - 1.6, top + 0.15, -0.2), STEEL, M.Metal)
			round("BowlInside", 0.02, 0.62, CFrame.new(w / 2 - 1.6, top + 0.3, -0.2), DARK_STEEL, M.Metal)
			utensils(piece, round, -0.6, 4)
			for index, color in { rgb(70, 140, 60), rgb(96, 160, 72) } do
				local x = w / 2 - 2.6 + index * 0.45
				round("HerbPot", 0.35, 0.34, CFrame.new(x, top + 0.18, back + 0.32), rgb(190, 104, 70), M.Concrete)
				ball("Herbs", Vector3.new(0.42, 0.36, 0.42), CFrame.new(x, top + 0.48, back + 0.32), color, M.Grass)
			end
		end
	elseif station == "GrillStation" then
		counter(piece, w, DARK_STEEL, M.Metal, rgb(170, 60, 44))
		-- A charcoal grill set into the worktop, its control knobs on the front.
		piece("GrillFrame", Vector3.new(3.5, 0.2, 1.95), CFrame.new(0.6, top + 0.06, 0), BLACK, M.Metal)
		local coals = piece("Coals", Vector3.new(3.2, 0.06, 1.7), CFrame.new(0.6, top + 0.12, 0), rgb(255, 120, 40), M.Neon)
		coals.Transparency = 0.25
		for bar = -4, 4 do
			piece("GrillBar", Vector3.new(0.06, 0.06, 1.75), CFrame.new(0.6 + bar * 0.36, top + 0.19, 0), DARK_STEEL, M.Metal)
		end
		piece("ControlPanel", Vector3.new(3.4, 0.42, 0.04), CFrame.new(0.6, top - 0.5, Kitchen.DEPTH / 2 + 0.1), STEEL, M.Metal)
		for index = -1, 2 do
			round("GrillKnob", 0.12, 0.22, CFrame.new(0.6 + index * 0.75 - 0.375, top - 0.5, Kitchen.DEPTH / 2 + 0.17) * CFrame.Angles(math.pi / 2, 0, 0), BLACK, M.SmoothPlastic)
		end
		-- A stainless canopy on two back posts draws the smoke up a duct.
		for _, x in { -w / 2 + 0.25, w / 2 - 0.25 } do
			piece("HoodPost", Vector3.new(0.14, 3.3, 0.14), CFrame.new(x, top + 1.65, back + 0.12), DARK_STEEL, M.Metal)
		end
		piece("Hood", Vector3.new(w - 0.3, 0.5, 1.7), CFrame.new(0, top + 3.05, -0.3), STEEL, M.Metal)
		piece("HoodLip", Vector3.new(w - 0.3, 0.12, 0.08), CFrame.new(0, top + 2.75, 0.52), DARK_STEEL, M.Metal)
		piece("HoodFilter", Vector3.new(3.6, 0.04, 1.2), CFrame.new(0.6, top + 2.78, -0.3), DARK_STEEL, M.Metal)
		piece("Duct", Vector3.new(1, 1.2, 0.9), CFrame.new(0.6, top + 3.9, -0.55), STEEL, M.Metal)
		local lamp = piece("HoodLamp", Vector3.new(0.5, 0.04, 0.3), CFrame.new(-2.6, top + 2.79, 0), rgb(255, 238, 200), M.Neon)
		local light = Instance.new("SpotLight")
		light.Face, light.Brightness, light.Range, light.Angle = Enum.NormalId.Bottom, 0.8, 8, 90
		light.Color = rgb(255, 236, 205)
		light.Parent = lamp
		-- Skewers ready on a tray, salt and pepper, tongs resting on the right.
		piece("SkewerTray", Vector3.new(1.6, 0.06, 1), CFrame.new(-2.7, top + 0.03, 0.1), STEEL, M.Metal)
		for index = -1, 1 do
			local z = 0.1 + index * 0.28
			piece("Skewer", Vector3.new(1.4, 0.03, 0.03), CFrame.new(-2.7, top + 0.12, z), LIGHT_WOOD, M.Wood)
			for chunk = -1, 1 do
				piece("SkewerChunk", Vector3.new(0.18, 0.16, 0.16), CFrame.new(-2.7 + chunk * 0.4, top + 0.13, z), if chunk == 0 then rgb(226, 84, 56) else SALMON, M.SmoothPlastic)
			end
		end
		round("Salt", 0.36, 0.16, CFrame.new(-3.9, top + 0.18, back + 0.4), PLATE, M.Glass)
		round("Pepper", 0.36, 0.16, CFrame.new(-3.65, top + 0.18, back + 0.4), BLACK, M.Glass)
		piece("Tongs", Vector3.new(0.9, 0.04, 0.08), CFrame.new(3.3, top + 0.04, 0.4) * CFrame.Angles(0, 0.35, 0), STEEL, M.Metal)
		for index = 0, 2 do
			round("Plate", 0.05, 0.9, CFrame.new(3.4, top + 0.03 + index * 0.06, -0.35), PLATE, M.SmoothPlastic)
		end
		local glow = Instance.new("PointLight")
		glow.Color, glow.Brightness, glow.Range = rgb(255, 140, 60), 0.8, 8
		glow.Parent = coals
	elseif station == "Smoker" then
		-- An open bay at the right end keeps the smoking wood to hand.
		counter(piece, w, WOOD, M.WoodPlanks, rgb(92, 70, 52), { 1.6, w / 2 })
		for row = 0, 2 do
			for index = 0, 3 - row do
				local x = 2.25 + index * 0.55 + row * 0.27
				local log = piece("Log", Vector3.new(1.9, 0.5, 0.5), CFrame.new(x, 0.62 + row * 0.44, 0.1) * CFrame.Angles(0, math.pi / 2, 0), rgb(122, 86, 56), M.Wood)
				log.Shape = Enum.PartType.Cylinder
			end
		end
		-- The smokehouse cabinet: charred planks in iron bands, a window in the door.
		local boxX = -w / 2 + 1.55
		piece("SmokeBox", Vector3.new(2.6, 2.6, 1.9), CFrame.new(boxX, top + 1.3, -0.15), CHARRED, M.WoodPlanks, true)
		for _, y in { 0.25, 2.35 } do
			piece("SmokeBand", Vector3.new(2.66, 0.12, 1.96), CFrame.new(boxX, top + y, -0.15), DARK_STEEL, M.Metal)
		end
		piece("SmokeDoor", Vector3.new(2.1, 1.85, 0.08), CFrame.new(boxX, top + 1.3, 0.83), rgb(76, 60, 46), M.Wood)
		local window = piece("SmokeWindow", Vector3.new(1, 0.6, 0.04), CFrame.new(boxX, top + 1.75, 0.88), rgb(255, 150, 70), M.Glass)
		window.Transparency = 0.3
		piece("SmokeHandle", Vector3.new(0.1, 0.5, 0.1), CFrame.new(boxX + 0.85, top + 1.2, 0.92), DARK_STEEL, M.Metal)
		round("Thermometer", 0.06, 0.42, CFrame.new(boxX - 0.6, top + 2.05, 0.89) * CFrame.Angles(math.pi / 2, 0, 0), PLATE, M.SmoothPlastic)
		piece("Needle", Vector3.new(0.03, 0.16, 0.02), CFrame.new(boxX - 0.6, top + 2.08, 0.93) * CFrame.Angles(0, 0, -0.6), rgb(210, 40, 30), M.Neon)
		piece("SmokeRoof", Vector3.new(2.9, 0.18, 2.2), CFrame.new(boxX, top + 2.69, -0.15), DARK_STEEL, M.Metal)
		round("Chimney", 2, 0.5, CFrame.new(boxX - 0.7, top + 3.7, -0.5), DARK_STEEL, M.Metal)
		piece("ChimneyCap", Vector3.new(0.85, 0.08, 0.85), CFrame.new(boxX - 0.7, top + 4.95, -0.5), BLACK, M.Metal)
		local vent = piece("Vent", Vector3.new(0.4, 0.1, 0.4), CFrame.new(boxX - 0.7, top + 4.72, -0.5), BLACK, M.Metal)
		local smoke = Instance.new("ParticleEmitter")
		smoke.Name = "Smoke"
		smoke.Color = ColorSequence.new(rgb(180, 176, 168))
		smoke.Transparency = NumberSequence.new(0.5, 1)
		smoke.Size = NumberSequence.new(0.6, 2.4)
		smoke.Lifetime = NumberRange.new(2, 3.5)
		smoke.Rate = 4
		smoke.Speed = NumberRange.new(1.5, 2.5)
		smoke.SpreadAngle = Vector2.new(12, 12)
		smoke.Parent = vent
		-- Smoked fish hang from a rail at the back of the open worktop.
		for _, x in { 0.35, w / 2 - 0.35 } do
			piece("RailPost", Vector3.new(0.12, 2.2, 0.12), CFrame.new(x, top + 1.1, back + 0.2), DARK_STEEL, M.Metal)
		end
		piece("HangingRail", Vector3.new(w / 2 - 0.5, 0.08, 0.08), CFrame.new(w / 4, top + 2.15, back + 0.2), DARK_STEEL, M.Metal)
		for index = 0, 3 do
			local x = 1.2 + index * 0.85
			piece("Hook", Vector3.new(0.03, 0.3, 0.03), CFrame.new(x, top + 1.97, back + 0.2), STEEL, M.Metal)
			piece("SmokedFish", Vector3.new(0.45, 0.95, 0.14), CFrame.new(x, top + 1.32, back + 0.2), rgb(176, 96, 44), M.SmoothPlastic)
			piece("FishTail", Vector3.new(0.4, 0.2, 0.1), CFrame.new(x, top + 0.78, back + 0.2), rgb(140, 72, 34), M.SmoothPlastic)
		end
		piece("ChipBucket", Vector3.new(0.7, 0.55, 0.7), CFrame.new(w / 2 - 0.7, top + 0.28, 0.35), rgb(110, 116, 118), M.Metal)
		piece("WoodChips", Vector3.new(0.6, 0.05, 0.6), CFrame.new(w / 2 - 0.7, top + 0.52, 0.35), rgb(170, 120, 74), M.Sand)
	elseif station == "SushiBar" then
		counter(piece, w, LIGHT_WOOD, M.Wood, rgb(70, 54, 44))
		-- A chilled glass neta case along the back shows the day's fish.
		piece("NetaBase", Vector3.new(w - 1.6, 0.35, 0.8), CFrame.new(0, top + 0.17, back + 0.55), DARK_STEEL, M.Metal)
		local glass = piece("NetaGlass", Vector3.new(w - 1.6, 0.6, 0.06), CFrame.new(0, top + 0.62, back + 0.95) * CFrame.Angles(math.rad(-18), 0, 0), rgb(205, 232, 235), M.Glass)
		glass.Transparency = 0.7
		local lid = piece("NetaTop", Vector3.new(w - 1.6, 0.05, 0.75), CFrame.new(0, top + 0.92, back + 0.55), rgb(205, 232, 235), M.Glass)
		lid.Transparency = 0.7
		for index, color in { SALMON, rgb(190, 40, 50), rgb(244, 236, 220), SALMON, rgb(240, 196, 84), rgb(190, 40, 50) } do
			piece("Neta", Vector3.new(0.9, 0.18, 0.4), CFrame.new(-3.1 + (index - 1) * 1.24, top + 0.44, back + 0.55), color, M.SmoothPlastic)
		end
		-- The chef's place: a bamboo mat, the rice tub, soy and a long knife.
		piece("BambooMat", Vector3.new(1.6, 0.05, 1.1), CFrame.new(0.6, top + 0.03, 0.4), rgb(196, 182, 120), M.Fabric)
		round("Hangiri", 0.45, 1.2, CFrame.new(-2.6, top + 0.23, 0.35), LIGHT_WOOD, M.Wood)
		round("HangiriBand", 0.08, 1.24, CFrame.new(-2.6, top + 0.33, 0.35), rgb(184, 115, 51), M.Metal)
		round("Rice", 0.04, 1.05, CFrame.new(-2.6, top + 0.45, 0.35), PLATE, M.SmoothPlastic)
		round("SoyBottle", 0.5, 0.2, CFrame.new(2.6, top + 0.25, 0.3), rgb(40, 20, 12), M.Glass)
		round("SoyCap", 0.1, 0.16, CFrame.new(2.6, top + 0.55, 0.3), rgb(200, 40, 36), M.SmoothPlastic)
		piece("GingerDish", Vector3.new(0.5, 0.05, 0.35), CFrame.new(3.3, top + 0.03, 0.35), PLATE, M.SmoothPlastic)
		ball("Ginger", Vector3.new(0.22, 0.1, 0.2), CFrame.new(3.2, top + 0.09, 0.35), rgb(246, 196, 186), M.SmoothPlastic)
		ball("Wasabi", Vector3.new(0.14, 0.1, 0.14), CFrame.new(3.45, top + 0.09, 0.35), rgb(130, 180, 70), M.SmoothPlastic)
		piece("YanagibaBlade", Vector3.new(1.2, 0.02, 0.12), CFrame.new(1.7, top + 0.05, 0.75), STEEL, M.Metal)
		piece("YanagibaHandle", Vector3.new(0.45, 0.07, 0.09), CFrame.new(2.5, top + 0.06, 0.75), LIGHT_WOOD, M.Wood)
		-- A split noren on a wooden frame, with a paper lantern at each end.
		for _, x in { -w / 2 + 0.2, w / 2 - 0.2 } do
			piece("NorenPost", Vector3.new(0.16, 3.4, 0.16), CFrame.new(x, top + 1.7, back + 0.1), LIGHT_WOOD, M.Wood)
			local lx = x - math.sign(x) * 0.15
			piece("LanternArm", Vector3.new(0.06, 0.06, 0.5), CFrame.new(lx, top + 2.15, back + 0.35), LIGHT_WOOD, M.Wood)
			local lantern = ball("Lantern", Vector3.new(0.55, 0.7, 0.55), CFrame.new(lx, top + 1.75, back + 0.55), rgb(214, 52, 40), M.Fabric)
			piece("LanternCord", Vector3.new(0.03, 0.06, 0.03), CFrame.new(lx, top + 2.12, back + 0.55), BLACK, M.Fabric)
			local glow = Instance.new("PointLight")
			glow.Color, glow.Brightness, glow.Range = rgb(255, 170, 120), 0.4, 6
			glow.Parent = lantern
		end
		piece("NorenRod", Vector3.new(w - 0.1, 0.12, 0.12), CFrame.new(0, top + 3.35, back + 0.1), LIGHT_WOOD, M.Wood)
		local panels = 5
		local panelWidth = (w - 0.8) / panels
		for index = 1, panels do
			local x = -(w - 0.8) / 2 + (index - 0.5) * panelWidth
			piece("Noren", Vector3.new(panelWidth - 0.08, 1.05, 0.04), CFrame.new(x, top + 2.75, back + 0.1), rgb(34, 52, 92), M.Fabric)
			piece("NorenCrest", Vector3.new(0.3, 0.3, 0.05), CFrame.new(x, top + 2.65, back + 0.13), PLATE, M.Fabric)
		end
	else
		error("Unknown kitchen station " .. tostring(station))
	end
	return model
end

-- A chilled prep counter holding up to 8 fish for cooking, in iced steel pans.
function Kitchen.buildStorage(parent: Instance, frame: CFrame): Model
	local model, piece, round = builder(parent, "KitchenStorage", frame)
	local w, top, front, back = Kitchen.WIDTH, Kitchen.TOP, Kitchen.DEPTH / 2, -Kitchen.DEPTH / 2
	counter(piece, w, STEEL, M.Metal, rgb(52, 60, 66))

	local ice = piece("IceBed", Vector3.new(w - 0.6, 0.06, 2.0), CFrame.new(0, top + 0.02, 0), rgb(218, 238, 245), M.Ice, true)
	ice.Transparency = 0.15
	-- One pan per pair of fish, rimmed in steel.
	for _, x in STORAGE_COLUMNS do
		piece("PanRim", Vector3.new(1.9, 0.08, 1.95), CFrame.new(x, top + 0.04, 0), STEEL, M.Metal)
		local pan = piece("PanIce", Vector3.new(1.75, 0.04, 1.8), CFrame.new(x, top + 0.07, 0), rgb(232, 246, 250), M.Ice)
		pan.Transparency = 0.1
		piece("PanDivider", Vector3.new(1.75, 0.04, 0.04), CFrame.new(x, top + 0.09, -0.025), DARK_STEEL, M.Metal)
	end
	-- A sneeze guard over the pans, and the ticket rail behind it.
	for _, x in { -w / 2 + 0.3, w / 2 - 0.3 } do
		piece("GuardPost", Vector3.new(0.08, 1.1, 0.08), CFrame.new(x, top + 0.55, back + 0.3), STEEL, M.Metal)
	end
	local guard = piece("SneezeGuard", Vector3.new(w - 0.5, 0.05, 0.9), CFrame.new(0, top + 1.08, back + 0.7) * CFrame.Angles(math.rad(-10), 0, 0), rgb(214, 236, 240), M.Glass)
	guard.Transparency = 0.75
	piece("TicketRail", Vector3.new(w - 1, 0.1, 0.05), CFrame.new(0, top + 0.75, back + 0.11), DARK_STEEL, M.Metal)
	for index = -3, 3 do
		piece("Ticket", Vector3.new(0.45, 0.5, 0.02), CFrame.new(index * 1.1, top + 0.55, back + 0.13), rgb(245, 245, 230), M.SmoothPlastic)
	end
	-- The chiller's controls and grille on the front.
	-- Between the drawer pulls, clear of the doors.
	local display = piece("TempDisplay", Vector3.new(0.6, 0.26, 0.03), CFrame.new(2.93, top - 0.5, front + 0.05), rgb(90, 220, 255), M.Neon)
	display.Transparency = 0.15
	round("TempKnob", 0.06, 0.18, CFrame.new(0, top - 0.5, front + 0.06) * CFrame.Angles(math.pi / 2, 0, 0), BLACK, M.SmoothPlastic)
	for row = 0, 1 do
		piece("GrilleSlat", Vector3.new(2.2, 0.04, 0.03), CFrame.new(0, 0.1 + row * 0.1, front - 0.28), DARK_STEEL, M.Metal)
	end

	local mist = Instance.new("ParticleEmitter")
	mist.Name = "ChillMist"
	mist.Color = ColorSequence.new(rgb(225, 242, 255))
	mist.Transparency = NumberSequence.new(0.65, 1)
	mist.Size = NumberSequence.new(0.3, 0.8)
	mist.Lifetime = NumberRange.new(1.2, 2)
	mist.Rate = 4
	mist.Speed = NumberRange.new(0.2, 0.6)
	mist.SpreadAngle = Vector2.new(180, 0)
	mist.Parent = ice

	return model
end

-- Ordinary open supermarket shelving, shared by the wide and single-cell units.
-- Dishes are added separately; the open front (+Z) faces the shoppers.
local function supermarketShelf(
	parent: Instance,
	frame: CFrame,
	name: string,
	w: number,
	d: number,
	levels: { number },
	columns: { number }
): Model
	local model, piece = builder(parent, name, frame)
	local h = Kitchen.SHELF_HEIGHT
	local white = rgb(236, 238, 236)
	local grey = rgb(196, 200, 200)
	local strip = rgb(214, 74, 58)
	local back = -d / 2

	-- The base plinth is the solid footprint; the kickplate covers its front.
	piece("Base", Vector3.new(w - 0.04, 0.4, d - 0.1), CFrame.new(0, 0.2, 0.03), grey, M.SmoothPlastic, true)
	piece("Kickplate", Vector3.new(w - 0.1, 0.34, 0.04), CFrame.new(0, 0.2, d / 2 - 0.025), DARK_STEEL, M.Metal)
	-- Two end uprights and a pegboard back panel.
	for _, x in { -w / 2 + 0.06, w / 2 - 0.06 } do
		piece("Upright", Vector3.new(0.12, h, 0.2), CFrame.new(x, h / 2, back + 0.14), white, M.Metal, true)
		piece("EndFoot", Vector3.new(0.12, 0.12, d - 0.2), CFrame.new(x, 0.46, 0.06), grey, M.Metal)
	end
	piece("BackPanel", Vector3.new(w - 0.2, h - 0.5, 0.08), CFrame.new(0, (h - 0.5) / 2 + 0.4, back + 0.08), white, M.SmoothPlastic, true)
	for row = 1, 9 do
		for column = -3, 3 do
			piece("PegHole", Vector3.new(0.06, 0.06, 0.02), CFrame.new(column * (w - 1.1) / 6, 0.4 + row * 0.5, back + 0.13), grey, M.SmoothPlastic)
		end
	end
	-- Shelves with a red price strip along each front edge.
	for _, y in levels do
		piece("Shelf", Vector3.new(w - 0.28, 0.08, d - 0.3), CFrame.new(0, y + 0.06, 0.08), white, M.Metal)
		piece("ShelfBracket", Vector3.new(w - 0.28, 0.16, 0.06), CFrame.new(0, y - 0.04, back + 0.17), grey, M.Metal)
		piece("PriceStrip", Vector3.new(w - 0.3, 0.2, 0.04), CFrame.new(0, y + 0.02, d / 2 - 0.04), strip, M.SmoothPlastic)
		for _, x in columns do
			piece("PriceTag", Vector3.new(0.6, 0.13, 0.02), CFrame.new(x, y + 0.02, d / 2 - 0.01), rgb(252, 250, 236), M.SmoothPlastic)
		end
	end
	piece("TopCap", Vector3.new(w, 0.1, 0.4), CFrame.new(0, h + 0.05, back + 0.2), grey, M.Metal)
	-- A header board on top reads as an aisle sign.
	piece("HeaderBoard", Vector3.new(w - 0.6, 0.6, 0.08), CFrame.new(0, h + 0.4, back + 0.2), strip, M.SmoothPlastic)
	piece("HeaderFace", Vector3.new(w - 0.9, 0.36, 0.02), CFrame.new(0, h + 0.4, back + 0.25), rgb(252, 250, 236), M.SmoothPlastic)
	return model
end

-- Keep the saved FoodCase item and its two-cell footprint, now as open shelving.
function Kitchen.buildCase(parent: Instance, frame: CFrame): Model
	return supermarketShelf(parent, frame, "FoodCase", Kitchen.CASE_WIDTH, Kitchen.CASE_DEPTH, CASE_LEVELS, CASE_COLUMNS)
end

function Kitchen.buildShelf(parent: Instance, frame: CFrame): Model
	return supermarketShelf(parent, frame, "FoodShelf", Kitchen.SHELF_WIDTH, Kitchen.SHELF_DEPTH, SHELF_LEVELS, SHELF_COLUMNS)
end

-- One cooked dish, resting with its base on `frame`'s origin. Purely decorative.
function Kitchen.buildDish(recipeId: string, look: string, frame: CFrame): Model
	local model, piece = builder(nil :: any, "Dish", frame)
	model:SetAttribute("RecipeId", recipeId)
	local function round(label: string, y: number, height: number, diameter: number, color: Color3, material: Enum.Material?, x: number?, z: number?): Part
		local part = Props.cylinder(model, (frame * CFrame.new(x or 0, y, z or 0)).Position, height, diameter, color, material)
		part.Name = label
		part.CanCollide, part.CanQuery = false, false
		return part
	end
	if look == "Sushi" or look == "Sashimi" or look == "DragonRoll" then
		piece("ServingBoard", Vector3.new(1.5, 0.12, 0.8), CFrame.new(0, 0.06, 0), WOOD, M.Wood)
	else
		round("Plate", 0.04, 0.08, 1.35, PLATE, M.SmoothPlastic)
		round("PlateRim", 0.09, 0.03, 1.1, rgb(226, 226, 220), M.SmoothPlastic)
	end
	local function bowl(color: Color3, filling: Color3)
		round("Bowl", 0.26, 0.3, 1.05, color, M.SmoothPlastic)
		round("BowlLip", 0.41, 0.06, 1.1, color, M.SmoothPlastic)
		round("BowlFilling", 0.445, 0.01, 0.92, filling, M.SmoothPlastic)
	end
	if look == "Fillet" then
		piece("Fillet", Vector3.new(0.85, 0.14, 0.42), CFrame.new(-0.05, 0.18, 0) * CFrame.Angles(0, 0.3, 0), rgb(240, 160, 130), M.SmoothPlastic)
		local lemon = piece("Lemon", Vector3.new(0.26, 0.26, 0.26), CFrame.new(0.4, 0.22, 0.25), rgb(246, 220, 70), M.SmoothPlastic)
		lemon.Shape = Enum.PartType.Ball
		piece("Herb", Vector3.new(0.3, 0.04, 0.15), CFrame.new(-0.35, 0.13, -0.3), rgb(70, 140, 60), M.Grass)
	elseif look == "Chips" then
		piece("BatteredFish", Vector3.new(0.75, 0.2, 0.36), CFrame.new(-0.18, 0.21, 0) * CFrame.Angles(0, -0.25, 0), rgb(214, 156, 66), M.Sand)
		for index = 1, 6 do
			piece("Chip", Vector3.new(0.45, 0.08, 0.08), CFrame.new(0.32, 0.15 + (index % 2) * 0.07, -0.3 + index * 0.1) * CFrame.Angles(0, index * 0.5, 0), rgb(240, 206, 110), M.SmoothPlastic)
		end
	elseif look == "Grilled" then
		piece("GrilledFish", Vector3.new(1, 0.22, 0.34), CFrame.new(0, 0.2, 0), rgb(158, 120, 84), M.SmoothPlastic)
		piece("Tail", Vector3.new(0.2, 0.18, 0.3), CFrame.new(-0.56, 0.2, 0) * CFrame.Angles(0, math.rad(45), 0), rgb(130, 96, 66), M.SmoothPlastic)
		for index = -1, 1 do
			piece("GrillMark", Vector3.new(0.05, 0.02, 0.32), CFrame.new(index * 0.22, 0.32, 0), BLACK, M.SmoothPlastic)
		end
	elseif look == "Skewers" then
		for _, z in { -0.18, 0.18 } do
			piece("Skewer", Vector3.new(1.2, 0.04, 0.04), CFrame.new(0, 0.2, z), LIGHT_WOOD, M.Wood)
			for index = -1, 1 do
				piece("Chunk", Vector3.new(0.2, 0.2, 0.2), CFrame.new(index * 0.3, 0.2, z), if index == 0 then rgb(226, 84, 56) else rgb(222, 170, 112), M.SmoothPlastic)
			end
		end
	elseif look == "Smoked" then
		for index = 0, 2 do
			piece("SmokedSlice", Vector3.new(0.7, 0.08, 0.3), CFrame.new(0, 0.14 + index * 0.05, -0.2 + index * 0.2) * CFrame.Angles(0, index * 0.25, 0), rgb(176, 92, 40), M.SmoothPlastic)
		end
	elseif look == "Sushi" then
		for index = 0, 5 do
			local x = -0.55 + (index % 3) * 0.55
			local z = if index < 3 then -0.18 else 0.18
			round("Nori", 0.24, 0.24, 0.3, rgb(30, 40, 30), M.SmoothPlastic, x, z)
			round("Rice", 0.37, 0.02, 0.24, PLATE, M.SmoothPlastic, x, z)
			round("Salmon", 0.385, 0.01, 0.1, rgb(240, 120, 80), M.SmoothPlastic, x, z)
		end
	elseif look == "Sashimi" then
		for index = 0, 3 do
			piece("GoldenSlice", Vector3.new(0.3, 0.1, 0.5), CFrame.new(-0.45 + index * 0.3, 0.18, 0) * CFrame.Angles(0, 0, math.rad(-20)), rgb(244, 190, 70), M.Foil)
		end
		piece("Shiso", Vector3.new(0.35, 0.03, 0.4), CFrame.new(0.55, 0.13, 0), rgb(60, 150, 70), M.Grass)
	elseif look == "Sandwich" then
		for _, y in { 0.18, 0.42 } do
			piece("BreadCrust", Vector3.new(0.88, 0.12, 0.65), CFrame.new(0, y, 0), rgb(178, 117, 55), M.SmoothPlastic)
			piece("Bread", Vector3.new(0.77, 0.025, 0.54), CFrame.new(0, y + 0.065, 0), rgb(245, 222, 170), M.SmoothPlastic)
		end
		piece("Lettuce", Vector3.new(0.94, 0.04, 0.7), CFrame.new(0, 0.27, 0) * CFrame.Angles(0, 0.12, 0), rgb(84, 159, 61), M.Grass)
		piece("FishFilling", Vector3.new(0.82, 0.11, 0.52), CFrame.new(0, 0.34, 0), SALMON, M.SmoothPlastic)
	elseif look == "Soup" or look == "Chowder" then
		local chowder = look == "Chowder"
		bowl(if chowder then rgb(119, 63, 42) else rgb(74, 130, 157), if chowder then rgb(239, 217, 170) else rgb(214, 139, 59))
		for index = 0, 3 do
			local angle = index * math.pi / 2 + 0.3
			piece("FishChunk", Vector3.new(0.19, 0.07, 0.13), CFrame.new(math.cos(angle) * 0.24, 0.47, math.sin(angle) * 0.24) * CFrame.Angles(0, angle, 0), if chowder then rgb(181, 105, 58) else rgb(244, 194, 155), M.SmoothPlastic)
		end
		for index = -1, 1 do
			piece(if chowder then "Potato" else "Carrot", Vector3.new(0.1, 0.05, 0.1), CFrame.new(index * 0.23, 0.47, 0.05), if chowder then rgb(248, 230, 184) else rgb(235, 103, 38), M.SmoothPlastic)
		end
		piece("Herb", Vector3.new(0.25, 0.025, 0.08), CFrame.new(0.07, 0.51, -0.12) * CFrame.Angles(0, 0.5, 0), rgb(66, 141, 62), M.Grass)
	elseif look == "Tacos" then
		for _, z in { -0.25, 0.25 } do
			piece("TortillaBase", Vector3.new(0.85, 0.04, 0.2), CFrame.new(0, 0.15, z), rgb(237, 199, 106), M.SmoothPlastic)
			for _, side in { -1, 1 } do
				piece("TortillaSide", Vector3.new(0.85, 0.3, 0.045), CFrame.new(0, 0.26, z + side * 0.14) * CFrame.Angles(side * math.rad(25), 0, 0), rgb(237, 199, 106), M.SmoothPlastic)
			end
			piece("Lettuce", Vector3.new(0.74, 0.08, 0.19), CFrame.new(0, 0.29, z), rgb(76, 151, 54), M.Grass)
			for index = -1, 1 do
				piece("FishBite", Vector3.new(0.2, 0.12, 0.16), CFrame.new(index * 0.24, 0.37, z), rgb(215, 157, 77), M.SmoothPlastic)
			end
			piece("Salsa", Vector3.new(0.1, 0.06, 0.12), CFrame.new(0.12, 0.43, z), rgb(213, 63, 43), M.SmoothPlastic)
		end
	elseif look == "Salad" then
		bowl(PLATE, rgb(80, 147, 58))
		for index = 0, 4 do
			local angle = index * math.pi * 2 / 5
			piece("SaladLeaf", Vector3.new(0.33, 0.05, 0.18), CFrame.new(math.cos(angle) * 0.26, 0.48, math.sin(angle) * 0.26) * CFrame.Angles(0, angle, 0), rgb(111, 178, 67), M.Grass)
		end
		for index = -1, 1 do
			piece("FishStrip", Vector3.new(0.5, 0.08, 0.12), CFrame.new(0, 0.54, index * 0.17) * CFrame.Angles(0, -0.35, 0), SALMON, M.SmoothPlastic)
		end
		round("Tomato", 0.53, 0.1, 0.17, rgb(218, 68, 43), M.SmoothPlastic, 0.29, 0.04)
	elseif look == "Burger" then
		round("BottomBun", 0.2, 0.17, 0.85, rgb(207, 150, 77), M.SmoothPlastic)
		piece("Lettuce", Vector3.new(0.88, 0.05, 0.75), CFrame.new(0, 0.31, 0) * CFrame.Angles(0, 0.15, 0), rgb(86, 157, 58), M.Grass)
		round("FishPatty", 0.41, 0.16, 0.77, rgb(192, 131, 58), M.Sand)
		round("Tomato", 0.51, 0.04, 0.7, rgb(209, 64, 43), M.SmoothPlastic)
		local bun = piece("TopBun", Vector3.new(0.88, 0.32, 0.88), CFrame.new(0, 0.64, 0), rgb(222, 168, 89), M.SmoothPlastic)
		bun.Shape = Enum.PartType.Ball
		for index = -1, 1 do
			piece("Sesame", Vector3.new(0.07, 0.025, 0.035), CFrame.new(index * 0.16, 0.79 - math.abs(index) * 0.02, 0), PLATE, M.SmoothPlastic)
		end
	elseif look == "Steak" then
		round("FishSteak", 0.25, 0.28, 0.75, rgb(210, 147, 109), M.SmoothPlastic, -0.12)
		round("SteakCenter", 0.4, 0.025, 0.15, PLATE, M.SmoothPlastic, -0.12)
		for _, z in { -0.16, 0.16 } do
			piece("SearMark", Vector3.new(0.52, 0.025, 0.04), CFrame.new(-0.12, 0.405, z), CHARRED, M.SmoothPlastic)
		end
		for index = -1, 1 do
			piece("Asparagus", Vector3.new(0.08, 0.07, 0.62), CFrame.new(0.39 + index * 0.08, 0.15, 0), rgb(79, 130, 44), M.Grass)
		end
	elseif look == "Teriyaki" then
		round("RiceMound", 0.21, 0.2, 0.67, PLATE, M.SmoothPlastic, 0.25)
		piece("GlazedFish", Vector3.new(0.47, 0.2, 0.78), CFrame.new(-0.22, 0.27, 0), rgb(139, 70, 32), M.SmoothPlastic)
		for index = -1, 1 do
			piece("GlazeStripe", Vector3.new(0.49, 0.025, 0.045), CFrame.new(-0.22, 0.38, index * 0.2), rgb(86, 42, 24), M.SmoothPlastic)
			piece("Scallion", Vector3.new(0.14, 0.035, 0.045), CFrame.new(-0.23, 0.41, index * 0.18) * CFrame.Angles(0, 0.5, 0), rgb(91, 164, 65), M.Grass)
		end
	elseif look == "Bagel" then
		-- Eight rounded bread segments leave the bagel's centre visibly open.
		for index = 0, 7 do
			local angle = index * math.pi / 4
			local bread = piece("BagelBread", Vector3.new(0.31, 0.25, 0.31), CFrame.new(math.cos(angle) * 0.28, 0.25, math.sin(angle) * 0.28), rgb(205, 147, 78), M.SmoothPlastic)
			bread.Shape = Enum.PartType.Ball
		end
		for _, z in { -0.25, 0.25 } do
			piece("CreamCheese", Vector3.new(0.51, 0.05, 0.16), CFrame.new(0, 0.36, z), PLATE, M.SmoothPlastic)
			piece("SmokedSalmon", Vector3.new(0.53, 0.07, 0.16), CFrame.new(0, 0.42, z) * CFrame.Angles(0, -0.2, 0), rgb(220, 119, 75), M.SmoothPlastic)
		end
		piece("Dill", Vector3.new(0.3, 0.03, 0.07), CFrame.new(0.05, 0.47, -0.25), rgb(64, 130, 59), M.Grass)
	elseif look == "HoneySmoked" then
		piece("SmokedFillet", Vector3.new(0.95, 0.19, 0.45), CFrame.new(-0.05, 0.22, 0), rgb(177, 91, 37), M.SmoothPlastic)
		for index = -1, 1 do
			piece("HoneyGlaze", Vector3.new(0.12, 0.03, 0.47), CFrame.new(-0.05 + index * 0.27, 0.33, 0) * CFrame.Angles(0, -0.2, 0), rgb(242, 177, 43), M.SmoothPlastic)
		end
		for _, z in { -0.33, 0.33 } do
			round("Carrot", 0.15, 0.08, 0.18, rgb(234, 122, 36), M.SmoothPlastic, 0.18, z)
		end
		piece("Rosemary", Vector3.new(0.64, 0.035, 0.07), CFrame.new(-0.1, 0.37, 0.03) * CFrame.Angles(0, 0.25, 0), rgb(67, 122, 53), M.Grass)
	elseif look == "RiceBowl" then
		bowl(rgb(49, 64, 82), PLATE)
		for index = -1, 1 do
			piece("FishSlice", Vector3.new(0.57, 0.08, 0.16), CFrame.new(-0.12, 0.49 + (index + 1) * 0.015, index * 0.18) * CFrame.Angles(0, -0.3, 0), SALMON, M.SmoothPlastic)
		end
		for index = -1, 1 do
			round("Cucumber", 0.48, 0.06, 0.17, rgb(95, 166, 70), M.SmoothPlastic, 0.28, index * 0.17)
		end
		piece("NoriStrip", Vector3.new(0.08, 0.025, 0.42), CFrame.new(-0.1, 0.57, 0), rgb(29, 53, 35), M.SmoothPlastic)
	elseif look == "DragonRoll" then
		for index = 0, 4 do
			local x = -0.5 + index * 0.25
			local z = math.sin(index * 0.8) * 0.13
			round("Nori", 0.23, 0.22, 0.29, rgb(28, 46, 31), M.SmoothPlastic, x, z)
			round("Rice", 0.345, 0.02, 0.24, PLATE, M.SmoothPlastic, x, z)
			round("FishCenter", 0.36, 0.02, 0.11, SALMON, M.SmoothPlastic, x, z)
			piece("Avocado", Vector3.new(0.21, 0.07, 0.17), CFrame.new(x, 0.4, z - 0.06) * CFrame.Angles(0, -0.25, 0), rgb(141, 182, 63), M.SmoothPlastic)
		end
		piece("DragonTail", Vector3.new(0.31, 0.07, 0.15), CFrame.new(0.66, 0.24, -0.06) * CFrame.Angles(0, 0.45, 0), rgb(232, 142, 72), M.SmoothPlastic)
	end
	return model
end

return Kitchen
