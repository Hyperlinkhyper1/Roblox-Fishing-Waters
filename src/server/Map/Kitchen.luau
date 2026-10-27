-- Kitchen fixtures for the Supermarket path: the processing room's cooking stations,
-- the shop's food display case and the cooked dishes themselves. Local +Z is the
-- side the cook (or a customer at the case) stands on; the floor is y=0.
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

Kitchen.WIDTH = 6
Kitchen.DEPTH = 2.4
Kitchen.TOP = 3.1
Kitchen.CASE_WIDTH = 6
Kitchen.CASE_DEPTH = 2.6
Kitchen.CASE_SHELF = 2.5
-- Where a cooking fish or finished dish sits, in station-local studs.
Kitchen.WORK_SPOT = CFrame.new(0.6, Kitchen.TOP + 0.02, 0.15)
-- Six dish spots under the glass of a food display case: three across, two deep.
Kitchen.CASE_SPOTS = {}
for _, z in { -0.5, 0.55 } do
	for _, x in { -1.9, 0, 1.9 } do
		table.insert(Kitchen.CASE_SPOTS, CFrame.new(x, Kitchen.CASE_SHELF + 0.14, z))
	end
end
-- Eight fish spots on the ice bed of a kitchen fish storage counter: four across, two deep.
Kitchen.STORAGE_SPOTS = {}
for _, z in { -0.5, 0.45 } do
	for _, x in { -2.1, -0.7, 0.7, 2.1 } do
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
	return model, piece
end

-- The cabinet and worktop every station shares.
local function counter(piece, top: Color3, topMaterial: Enum.Material, body: Color3)
	piece("Cabinet", Vector3.new(Kitchen.WIDTH, Kitchen.TOP - 0.2, Kitchen.DEPTH), CFrame.new(0, (Kitchen.TOP - 0.2) / 2, 0), body, M.SmoothPlastic, true)
	piece("Worktop", Vector3.new(Kitchen.WIDTH + 0.1, 0.2, Kitchen.DEPTH + 0.1), CFrame.new(0, Kitchen.TOP - 0.1, 0), top, topMaterial, true)
	piece("Kickboard", Vector3.new(Kitchen.WIDTH - 0.2, 0.3, 0.05), CFrame.new(0, 0.15, Kitchen.DEPTH / 2 + 0.01), DARK_STEEL, M.Metal)
	for index = -1, 1 do
		piece("CabinetDoor", Vector3.new(1.8, 2.1, 0.06), CFrame.new(index * 1.95, 1.55, Kitchen.DEPTH / 2 + 0.03), body:Lerp(Color3.new(1, 1, 1), 0.15), M.SmoothPlastic)
		piece("DoorHandle", Vector3.new(0.9, 0.08, 0.08), CFrame.new(index * 1.95, 2.4, Kitchen.DEPTH / 2 + 0.1), DARK_STEEL, M.Metal)
	end
end

function Kitchen.buildStation(parent: Instance, frame: CFrame, station: string): Model
	local model, piece = builder(parent, station, frame)
	if station == "Prep" then
		counter(piece, STEEL, M.Metal, CABINET)
		piece("CuttingBoard", Vector3.new(2, 0.1, 1.3), CFrame.new(0.6, Kitchen.TOP + 0.05, 0.1), LIGHT_WOOD, M.Wood)
		piece("Sink", Vector3.new(1.5, 0.08, 1.4), CFrame.new(-1.9, Kitchen.TOP + 0.01, 0), DARK_STEEL, M.Metal)
		piece("Tap", Vector3.new(0.12, 0.9, 0.12), CFrame.new(-1.9, Kitchen.TOP + 0.45, -0.85), STEEL, M.Metal)
		piece("Spout", Vector3.new(0.12, 0.12, 0.6), CFrame.new(-1.9, Kitchen.TOP + 0.85, -0.6), STEEL, M.Metal)
		piece("KnifeBlock", Vector3.new(0.4, 0.6, 0.5), CFrame.new(2.4, Kitchen.TOP + 0.3, -0.7), WOOD, M.Wood)
	elseif station == "GrillStation" then
		counter(piece, DARK_STEEL, M.Metal, rgb(170, 60, 44))
		piece("GrillBed", Vector3.new(3, 0.12, 1.7), CFrame.new(0.6, Kitchen.TOP + 0.02, 0), BLACK, M.Metal)
		local coals = piece("Coals", Vector3.new(2.8, 0.06, 1.5), CFrame.new(0.6, Kitchen.TOP + 0.06, 0), rgb(255, 120, 40), M.Neon)
		coals.Transparency = 0.25
		for bar = -3, 3 do
			piece("GrillBar", Vector3.new(0.06, 0.06, 1.7), CFrame.new(0.6 + bar * 0.42, Kitchen.TOP + 0.12, 0), DARK_STEEL, M.Metal)
		end
		piece("HoodPost", Vector3.new(0.15, 3, 0.15), CFrame.new(-2.8, Kitchen.TOP + 1.5, -1.05), DARK_STEEL, M.Metal)
		piece("Hood", Vector3.new(4.2, 0.4, 1.8), CFrame.new(0.6, Kitchen.TOP + 3, -0.3), STEEL, M.Metal)
		local glow = Instance.new("PointLight")
		glow.Color, glow.Brightness, glow.Range = rgb(255, 140, 60), 0.8, 8
		glow.Parent = coals
	elseif station == "Smoker" then
		counter(piece, WOOD, M.WoodPlanks, rgb(92, 70, 52))
		piece("SmokeBox", Vector3.new(2.4, 2.2, 1.8), CFrame.new(-1.6, Kitchen.TOP + 1.1, -0.1), rgb(56, 44, 36), M.WoodPlanks, true)
		piece("SmokeDoor", Vector3.new(2, 1.8, 0.08), CFrame.new(-1.6, Kitchen.TOP + 1.1, 0.84), rgb(76, 60, 46), M.Wood)
		piece("Chimney", Vector3.new(0.5, 2.2, 0.5), CFrame.new(-2.2, Kitchen.TOP + 3.3, -0.4), DARK_STEEL, M.Metal)
		local vent = piece("Vent", Vector3.new(0.4, 0.1, 0.4), CFrame.new(-2.2, Kitchen.TOP + 4.42, -0.4), BLACK, M.Metal)
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
		piece("HangingRail", Vector3.new(2.6, 0.08, 0.08), CFrame.new(1.4, Kitchen.TOP + 1.6, -1), DARK_STEEL, M.Metal)
	elseif station == "SushiBar" then
		counter(piece, LIGHT_WOOD, M.Wood, rgb(70, 54, 44))
		piece("BambooMat", Vector3.new(1.6, 0.05, 1.2), CFrame.new(0.6, Kitchen.TOP + 0.03, 0.1), rgb(196, 182, 120), M.Fabric)
		local bowl = Props.cylinder(model, (frame * CFrame.new(-1.6, Kitchen.TOP + 0.25, -0.3)).Position, 0.5, 1, rgb(160, 40, 36), M.SmoothPlastic)
		bowl.Name = "RiceBowl"
		bowl.CanCollide = false
		local rice = Props.cylinder(model, (frame * CFrame.new(-1.6, Kitchen.TOP + 0.52, -0.3)).Position, 0.06, 0.85, PLATE, M.SmoothPlastic)
		rice.Name = "Rice"
		rice.CanCollide = false
		piece("Noren", Vector3.new(4.5, 1, 0.05), CFrame.new(0, Kitchen.TOP + 2.6, -1.1), rgb(34, 52, 92), M.Fabric)
		piece("NorenRod", Vector3.new(4.8, 0.1, 0.1), CFrame.new(0, Kitchen.TOP + 3.15, -1.1), LIGHT_WOOD, M.Wood)
		for _, x in { -2.3, 2.3 } do
			piece("NorenPost", Vector3.new(0.15, 3.2, 0.15), CFrame.new(x, Kitchen.TOP + 1.6, -1.1), LIGHT_WOOD, M.Wood)
		end
	elseif station == "KitchenStorage" then
		return Kitchen.buildStorage(parent, frame)
	else
		error("Unknown kitchen station " .. tostring(station))
	end
	return model
end

-- A chilled prep table holding up to 8 fish for cooking.
function Kitchen.buildStorage(parent: Instance, frame: CFrame): Model
	local model, piece = builder(parent, "KitchenStorage", frame)
	counter(piece, STEEL, M.Metal, rgb(52, 60, 66))

	local ice = piece("IceBed", Vector3.new(5.6, 0.06, 2.1), CFrame.new(0, Kitchen.TOP + 0.02, 0), rgb(218, 238, 245), M.Ice, true)
	ice.Transparency = 0.15

	piece("IceTrimFront", Vector3.new(5.8, 0.08, 0.1), CFrame.new(0, Kitchen.TOP + 0.04, 1.1), STEEL, M.Metal)
	piece("IceTrimBack", Vector3.new(5.8, 0.08, 0.1), CFrame.new(0, Kitchen.TOP + 0.04, -1.1), STEEL, M.Metal)
	piece("IceTrimLeft", Vector3.new(0.1, 0.08, 2.2), CFrame.new(-2.85, Kitchen.TOP + 0.04, 0), STEEL, M.Metal)
	piece("IceTrimRight", Vector3.new(0.1, 0.08, 2.2), CFrame.new(2.85, Kitchen.TOP + 0.04, 0), STEEL, M.Metal)

	piece("Backsplash", Vector3.new(5.9, 0.8, 0.08), CFrame.new(0, Kitchen.TOP + 0.4, -Kitchen.DEPTH / 2 + 0.05), STEEL, M.Metal, true)
	piece("TicketRail", Vector3.new(5.4, 0.1, 0.05), CFrame.new(0, Kitchen.TOP + 0.75, -Kitchen.DEPTH / 2 + 0.1), DARK_STEEL, M.Metal)
	for index = -2, 2 do
		piece("Ticket" .. (index + 3), Vector3.new(0.45, 0.5, 0.02), CFrame.new(index * 1.1, Kitchen.TOP + 0.55, -Kitchen.DEPTH / 2 + 0.12), rgb(245, 245, 230), M.SmoothPlastic)
	end

	for _, x in { -1.4, 0, 1.4 } do
		piece("DividerX" .. x, Vector3.new(0.04, 0.02, 2.0), CFrame.new(x, Kitchen.TOP + 0.05, 0), DARK_STEEL, M.Metal)
	end
	piece("DividerZ", Vector3.new(5.4, 0.02, 0.04), CFrame.new(0, Kitchen.TOP + 0.05, -0.025), DARK_STEEL, M.Metal)

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

-- A glass-topped chilled case. Dishes are added by the shop's display.
function Kitchen.buildCase(parent: Instance, frame: CFrame): Model
	local model, piece = builder(parent, "FoodCase", frame)
	local w, d = Kitchen.CASE_WIDTH, Kitchen.CASE_DEPTH
	piece("CaseBase", Vector3.new(w, Kitchen.CASE_SHELF - 0.1, d), CFrame.new(0, (Kitchen.CASE_SHELF - 0.1) / 2, 0), rgb(46, 92, 110), M.SmoothPlastic, true)
	piece("CaseTrim", Vector3.new(w + 0.1, 0.12, d + 0.1), CFrame.new(0, Kitchen.CASE_SHELF - 0.04, 0), STEEL, M.Metal, true)
	piece("Shelf", Vector3.new(w - 0.2, 0.08, d - 0.2), CFrame.new(0, Kitchen.CASE_SHELF + 0.06, 0), rgb(236, 242, 244), M.SmoothPlastic)
	for _, x in { -w / 2 + 0.05, w / 2 - 0.05 } do
		local side = piece("SideGlass", Vector3.new(0.06, 1.2, d - 0.1), CFrame.new(x, Kitchen.CASE_SHELF + 0.65, 0), rgb(200, 230, 236), M.SmoothPlastic, true)
		side.Transparency = 0.7
	end
	local front = piece("FrontGlass", Vector3.new(w - 0.1, 1.25, 0.06), CFrame.new(0, Kitchen.CASE_SHELF + 0.6, d / 2 - 0.2) * CFrame.Angles(math.rad(-14), 0, 0), rgb(200, 230, 236), M.SmoothPlastic, true)
	front.Transparency = 0.72
	local top = piece("TopGlass", Vector3.new(w - 0.1, 0.06, d - 0.5), CFrame.new(0, Kitchen.CASE_SHELF + 1.24, -0.2), rgb(200, 230, 236), M.SmoothPlastic, true)
	top.Transparency = 0.72
	piece("PriceRail", Vector3.new(w, 0.25, 0.06), CFrame.new(0, Kitchen.CASE_SHELF - 0.25, d / 2 + 0.03), rgb(240, 196, 80), M.SmoothPlastic)
	local light = Instance.new("SurfaceLight")
	light.Face, light.Brightness, light.Range, light.Angle = Enum.NormalId.Bottom, 0.6, 3, 120
	light.Color = rgb(255, 246, 228)
	light.Parent = top
	return model
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
	if look == "Sushi" or look == "Sashimi" then
		piece("ServingBoard", Vector3.new(1.5, 0.12, 0.8), CFrame.new(0, 0.06, 0), WOOD, M.Wood)
	else
		round("Plate", 0.04, 0.08, 1.35, PLATE, M.SmoothPlastic)
		round("PlateRim", 0.09, 0.03, 1.1, rgb(226, 226, 220), M.SmoothPlastic)
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
	end
	return model
end

return Kitchen
