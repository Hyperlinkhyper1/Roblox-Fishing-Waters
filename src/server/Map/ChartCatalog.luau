-- Chart records and sailing landmarks stay available outside terrain streaming range.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Biomes = require(ReplicatedStorage.Shared.Biomes)
local CompanyIslands = require(ReplicatedStorage.Shared.CompanyIslands)
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))
local Catalog = {}

local function destination(model: Model): (string?, number?)
	local islandId = model:GetAttribute("IslandId")
	if CompanyIslands.validId(islandId) then
		return CompanyIslands.Names[islandId], 2400
	end
	local name = model.Name
	local label = model:GetAttribute("ChartLabel")
	local radius = model:GetAttribute("Radius")
	if type(label) == "string" and label ~= "" then
		return label, 4200
	end
	if name == "Harbour Isle" or name == "Modern City" then
		return name, 6500
	elseif name == Biomes.PirateCove.name or model:GetAttribute("SmallCityVersion") then
		return name, 4200
	elseif name == "Island" and type(radius) == "number" and radius >= 300 then
		-- The large island at each biome's centre represents that named destination.
		for _, biome in Biomes.list do
			if model.Parent and model.Parent.Name == biome.name then
				return biome.name, 5500
			end
		end
	end
	return nil, nil
end

local function markerPosition(model: Model): Vector3?
	local ground = model:FindFirstChild("Ground")
	if not ground or not ground:IsA("Model") or not ground:FindFirstChildWhichIsA("BasePart", true) then
		return nil
	end
	local frame, size = ground:GetBoundingBox()
	return Vector3.new(frame.X, math.max(Biomes.WaterLevel, frame.Y + size.Y / 2) + 65, frame.Z)
end

local function addMarker(parent: Model, model: Model): BasePart?
	local name, range = destination(model)
	if not name or not range then
		return nil
	end
	local position = markerPosition(model)
	if not position then
		return nil
	end
	local anchor = Instance.new("Part")
	anchor.Name = name
	anchor.Size = Vector3.one
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = false, false, false
	anchor.Position = position

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "IslandName"
	billboard.Size = UDim2.fromOffset(240, 32)
	billboard.MaxDistance = range
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Parent = anchor

	local text = Instance.new("TextLabel")
	text.Name = "Name"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = name
	text.TextSize = if range <= 2400 then 16 else 20
	Theme.text(text)
	text.Parent = billboard
	anchor.Parent = parent
	return anchor
end

function Catalog.start(root: Instance)
	local old = ReplicatedStorage:FindFirstChild("IslandChart")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "IslandChart"
	folder.Parent = ReplicatedStorage
	local previousMarkers = root:FindFirstChild("IslandSkyLabels")
	if previousMarkers then
		previousMarkers:Destroy()
	end
	local markers = Instance.new("Model")
	markers.Name = "IslandSkyLabels"
	-- Only the tiny, non-interactive label anchors need to stay streamed in.
	markers.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	markers.Parent = root

	local seen = {}
	local function add(model)
		if not folder.Parent or not model:IsA("Model") or (model.Name ~= "Island" and model.Name ~= "Harbour Isle" and model.Name ~= "Modern City" and model.Name ~= "Pirate Cove" and not model:GetAttribute("CompanyIslandVersion") and not model:GetAttribute("SmallCityVersion")) or seen[model] then
			return
		end
		seen[model] = true
		local coast = model:GetAttribute("ChartCoast")
		if not coast and model.Name == "Harbour Isle" then
			coast = HttpService:JSONEncode(require(script.Parent.Harbour).chartCoast(Biomes.Normal.center))
		end
		if not coast then
			-- Older Studio-baked islands have no coast metadata. Use their ground
			-- bounds as a chart symbol; never include buildings, trees or LOD shells.
			local ground = model:FindFirstChild("Ground")
			if not ground or not ground:IsA("Model") or not ground:FindFirstChildWhichIsA("BasePart", true) then
				return
			end
			local frame, size = ground:GetBoundingBox()
			local radius = model:GetAttribute("Radius")
			local rx, rz = radius or size.X / 2, radius or size.Z / 2
			local points = {}
			for i = 1, 16 do
				local angle = i / 16 * math.pi * 2
				table.insert(points, { frame.X + math.cos(angle) * rx, frame.Z + math.sin(angle) * rz })
			end
			coast = HttpService:JSONEncode(points)
		end
		local record = Instance.new("StringValue")
		record.Name = model.Name
		record.Value = coast
		record:SetAttribute("Atoll", model:GetAttribute("ChartAtoll") == true)
		record:SetAttribute("ChartLabel", model:GetAttribute("ChartLabel"))
		record.Parent = folder
		local marker = addMarker(markers, model)
		-- A company island's coast changes when it is bought (mountain to village) or freed.
		model:GetAttributeChangedSignal("ChartCoast"):Connect(function()
			local value = model:GetAttribute("ChartCoast")
			if type(value) == "string" then
				record.Value = value
			end
			if marker and marker.Parent then
				marker.Position = markerPosition(model) or marker.Position
			end
		end)
		model.Destroying:Connect(function()
			record:Destroy()
			if marker then
				marker:Destroy()
			end
		end)
	end
	root.DescendantAdded:Connect(add)
	for _, model in root:GetDescendants() do
		add(model)
	end
end

return Catalog
