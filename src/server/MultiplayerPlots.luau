-- A company server uses five spacious waterfront properties. This is prepared
-- before the first owner is assigned; solo/public servers keep all fifteen.
local CollectionService = game:GetService("CollectionService")
local Layout = require(game:GetService("ReplicatedStorage").Shared.MultiplayerPlots)
local Service = {}
local preparing = setmetatable({}, { __mode = "k" })

local function directChildOf(item, container)
	local child = item
	while child and child.Parent ~= container do child = child.Parent end
	return child
end

local function removable(part, island, cached)
	local forest = island:FindFirstChild("Forest")
	local village = island:FindFirstChild("Village")
	local houses = village and village:FindFirstChild("Houses")
	local child = (forest and directChildOf(part, forest)) or (houses and directChildOf(part, houses))
	if not child then return nil end
	if cached[child] ~= nil then return if cached[child] then child else nil end
	cached[child] = false
	-- Public interactive shops and landmarks can never be cleared as scenery.
	for _, item in { child, table.unpack(child:GetDescendants()) } do
		if item:IsA("ProximityPrompt") or item:IsA("ClickDetector") then return nil end
		for _, tag in { "BoatShop", "FurnitureShop", "FurnitureShowroom", "BackpackShop", "FishingRodShop", "MetroStop", "PlayerBase", "CompanyIsland" } do
			if CollectionService:HasTag(item, tag) then return nil end
		end
	end
	cached[child] = true
	return child
end

local function highEnough(part, frame)
	local center = frame:PointToObjectSpace(part.Position)
	local reach = math.abs(frame.UpVector:Dot(part.CFrame.RightVector)) * part.Size.X / 2
		+ math.abs(frame.UpVector:Dot(part.CFrame.UpVector)) * part.Size.Y / 2
		+ math.abs(frame.UpVector:Dot(part.CFrame.LookVector)) * part.Size.Z / 2
	return center.Y + reach > 0.01
end

local function roadPart(part, island)
	local parent = part.Parent
	while parent and parent ~= island do
		if parent.Name == "Road" or parent.Name == "Lane" or parent.Name == "CrossStreets" then return true end
		parent = parent.Parent
	end
	return false
end

local function padHits(part, frame, island)
	if not highEnough(part, frame) and not roadPart(part, island) then return false end
	for _, rect in Layout.PadBounds do
		if Layout.overlaps(frame, rect, part.CFrame, part.Size, 1) then return true end
	end
	return false
end

local function candidate(base, island, bases, obstacles, sceneryCache)
	local house = base:FindFirstChild("BaseHouse")
	local frame = house and house:GetAttribute("HouseFrame")
	if typeof(frame) ~= "CFrame" or typeof(base:GetAttribute("BoatDockFrame")) ~= "CFrame" then return nil end
	local remove = {}
	for _, part in obstacles do
		local delta = part.Position - frame.Position
		local reach = 110 + part.Size.Magnitude / 2
		if delta.X * delta.X + delta.Z * delta.Z > reach * reach or not padHits(part, frame, island) then continue end
		local scenery = removable(part, island, sceneryCache)
		if scenery then remove[scenery] = true else return nil end
	end
	return { base = base, house = house, frame = frame, remove = remove }
end

local function choose(candidates, selected, first)
	if #selected == Layout.COUNT then return true end
	for index = first, #candidates do
		if #candidates - index + 1 < Layout.COUNT - #selected then return false end
		local proposed = candidates[index]
		local clear = true
		for _, previous in selected do
			if not Layout.separated(proposed.frame, previous.frame) then clear = false; break end
		end
		if clear then
			table.insert(selected, proposed)
			if choose(candidates, selected, index + 1) then return true end
			table.remove(selected)
		end
	end
	return false
end

local function part(parent, name, frame, rect, bottom, top, material, color)
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Size = Vector3.new(rect[3] - rect[1], top - bottom, rect[4] - rect[2])
	piece.CFrame = frame * CFrame.new((rect[1] + rect[3]) / 2, (bottom + top) / 2, (rect[2] + rect[4]) / 2)
	piece.Anchored, piece.CanCollide, piece.CanQuery = true, true, true
	piece.Material, piece.Color = material, color
	piece.TopSurface, piece.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	piece.Parent = parent
	return piece
end

local function expand(record)
	local old = record.base:FindFirstChild("MultiplayerPlotExtensions")
	if old then old:Destroy() end
	local model = Instance.new("Model")
	model.Name, model.Parent = "MultiplayerPlotExtensions", record.base
	local floor = Color3.fromRGB(132, 102, 74)
	local stone = Color3.fromRGB(150, 140, 126)
	-- Side wings meet the existing quay without another coplanar surface across
	-- the saved house, paths or furnishings. The shop stays across the road.
	for _, side in { -1, 1 } do
		local yard = if side < 0 then { -54, -35.5, -27.5, 17 } else { 27.5, -35.5, 54, 17 }
		local quay = if side < 0 then { -54, -35.5, -29.6, 17 } else { 29.6, -35.5, 54, 17 }
		part(model, "MultiplayerYardFoundation", record.frame, quay, -9.4, -0.4, Enum.Material.Cobblestone, stone)
		part(model, "MultiplayerYardFloor", record.frame, yard, -0.4, 0, Enum.Material.WoodPlanks, floor)
	end
	-- The original quay's two lamps become interior obstacles after widening.
	-- Move only these generated edge lamps; saved furniture stays untouched.
	for _, child in record.base:GetChildren() do
		if child:IsA("Model") and child.Name == "LampPost" then
			local pivot = child:GetPivot()
			local point = record.frame:PointToObjectSpace(pivot.Position)
			if math.abs(point.X) >= 25 and math.abs(point.X) <= 30 and point.Z < -29 then
				child:PivotTo(pivot + record.frame.RightVector * (math.sign(point.X) * 53 - point.X))
			end
		end
	end
	record.base:SetAttribute("MultiplayerPlot", true)
	record.house:SetAttribute("MultiplayerPlot", true)
end

local function prepare(root: Instance): (boolean, string?)
	if not root then return false, "The harbour has not loaded yet. Please try again." end
	local island = if root.Name == "Harbour Isle" then root else root:FindFirstChild("Harbour Isle", true)
	local bases = island and island:FindFirstChild("Bases")
	if not bases then return false, "The harbour plots are not ready. Please try again." end
	local originals = bases:GetChildren()
	if island:GetAttribute("MultiplayerPlotsVersion") == Layout.VERSION and #originals == Layout.COUNT then
		local valid = true
		for _, base in originals do
			local house, extension = base:FindFirstChild("BaseHouse"), base:FindFirstChild("MultiplayerPlotExtensions")
			if not base:GetAttribute("MultiplayerPlot") or not house or not house:GetAttribute("MultiplayerPlot")
				or not extension or #extension:GetChildren() ~= 4 then valid = false; break end
		end
		if valid then return true end
	end
	for _, base in originals do
		if base:GetAttribute("OwnerUserId") ~= 0 then
			return false, "Start a new server to prepare larger multiplayer plots; this harbour already has players on its plots."
		end
	end
	local obstacles = {}
	local resumed = os.clock()
	local function breathe()
		if os.clock() - resumed > 0.05 then task.wait(); resumed = os.clock() end
	end
	for _, item in root:GetDescendants() do
		if item:IsA("BasePart") and not item:IsDescendantOf(bases) then table.insert(obstacles, item) end
		breathe()
	end
	local priority = {}
	for index, id in Layout.BaseIds do priority[id] = index end
	table.sort(originals, function(a, b)
		return (priority[a:GetAttribute("BaseId")] or (100 + (a:GetAttribute("BaseId") or 99)))
			< (priority[b:GetAttribute("BaseId")] or (100 + (b:GetAttribute("BaseId") or 99)))
	end)
	local candidates, sceneryCache = {}, {}
	for _, base in originals do
		local record = candidate(base, island, bases, obstacles, sceneryCache)
		if record then table.insert(candidates, record) end
		breathe()
	end
	local selected = {}
	if not choose(candidates, selected, 1) then
		return false, "This harbour has no safe space for five larger plots. Rejoin to try a fresh server."
	end
	for _, base in originals do
		if base.Parent ~= bases or base:GetAttribute("OwnerUserId") ~= 0 then
			return false, "The harbour changed while preparing multiplayer plots. Please try again."
		end
	end
	-- No mutations occur until all five properties pass their footprint checks.
	local retained, clear = {}, {}
	for _, record in selected do
		retained[record.base] = true
		for item in record.remove do clear[item] = true end
	end
	for _, base in originals do
		if not retained[base] then
			CollectionService:RemoveTag(base, "PlayerBase")
			base:Destroy()
		end
	end
	for item in clear do item:Destroy() end
	for _, record in selected do expand(record) end
	island:SetAttribute("MultiplayerPlotsVersion", Layout.VERSION)
	return true
end

function Service.prepare(root: Instance): (boolean, string?)
	if not root then return false, "The harbour has not loaded yet. Please try again." end
	while preparing[root] do task.wait() end
	preparing[root] = true
	local ok, result, message = pcall(prepare, root)
	preparing[root] = nil
	if not ok then
		warn("[MultiplayerPlots] " .. tostring(result))
		return false, "The larger company plots could not be prepared. Please try again."
	end
	return result, message
end

return Service
