-- Building shells and collision stream normally; their optional facades are reconstructed locally
-- in small batches, nearest first. No full-detail model is replicated during a metro transfer.
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CityDetail = {}
local RADIUS = { 112, 160, 224 } -- Performance, Balanced, Quality
local KEEP_MARGIN = 48
local PARTS_PER_FRAME = 3
local FRAME_BUDGET = 0.001
local RESORT_INTERVAL = 0.5

local function position(model)
	local anchor = model:GetAttribute("CityDetailAnchor")
	if typeof(anchor) == "Vector3" then return anchor end
	local part = model:FindFirstChildWhichIsA("BasePart")
	return if part then part.Position else nil
end

local function create(data, parent)
	local part = Instance.new("Part")
	part.Name = data[1]
	part.Size = Vector3.new(data[2], data[3], data[4])
	part.CFrame = CFrame.new(table.unpack(data, 5, 16))
	part.Color = Color3.new(data[17], data[18], data[19])
	part.Material = Enum.Material[data[20]]
	part.Shape = Enum.PartType[data[21]]
	part.Transparency, part.Reflectance, part.CastShadow = data[22], data[23], false
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
	part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if data[27] then part:SetAttribute("GlowColor", Color3.new(table.unpack(data[27]))) end
	if data[28] then part:SetAttribute("GlowAt", data[28]) end
	if data[25] then part:AddTag("NightGlow") end
	if data[26] then part:AddTag("AviationBeacon") end
	part.Parent = parent
	return part
end

function CityDetail.start()
	local player = Players.LocalPlayer
	local records, retiring = {}, {}
	local function retire(record)
		if record.folder then
			retiring[record] = { folder = record.folder, parts = record.parts }
		end
		record.folder, record.parts, record.data, record.next = nil, nil, nil, 1
	end
	local function added(model)
		if records[model] then return end
		-- Tags and attributes need not arrive together. Decode only when a nearby building
		-- gets its turn, rather than decoding a whole streaming burst in one frame.
		records[model] = { model = model, next = 1 }
	end
	local function removed(model)
		local record = records[model]
		if not record then return end
		retire(record)
		records[model] = nil
	end
	CollectionService:GetInstanceAddedSignal("CityDetail"):Connect(added)
	CollectionService:GetInstanceRemovedSignal("CityDetail"):Connect(removed)
	for _, model in CollectionService:GetTagged("CityDetail") do added(model) end

	local candidates, nextSort, hitchUntil, nextSlowBuild = {}, 0, 0, 0
	local wasRiding, resumeAt = false, 0
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		if dt > 0.075 then hitchUntil = now + 0.75 end
		local slow = dt > 1 / 30 or now < hitchUntil
		local limit = if slow then 1 else PARTS_PER_FRAME
		local deadline, work = now + FRAME_BUDGET, 0
		-- Stream-out and distance culling share the construction budget. Destroying a
		-- folder of local parts inside each tag callback used to add to a departure burst.
		for record, old in retiring do
			while #old.parts > 0 do
				if work >= limit or os.clock() >= deadline then return end
				local index = #old.parts
				old.parts[index]:Destroy()
				old.parts[index] = nil
				work += 1
			end
			old.folder:Destroy()
			retiring[record] = nil
		end
		local riding = player:GetAttribute("MetroRiding") == true
		if wasRiding and not riding then resumeAt = now + 8 end
		wasRiding = riding
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then return end
		if now >= nextSort then
			nextSort = now + RESORT_INTERVAL
			table.clear(candidates)
			local tier = player:GetAttribute("GraphicsTier")
			local radius = RADIUS[if type(tier) == "number" then math.clamp(math.floor(tier), 1, #RADIUS) else #RADIUS]
			local focus = root.Position
			for model, record in records do
				if not retiring[record] and model:IsDescendantOf(workspace) then
					record.position = record.position or position(model)
					if record.position then
						local distance = (record.position - focus).Magnitude
						if record.folder and distance > radius + KEEP_MARGIN then
							retire(record)
						elseif distance <= radius and (not record.data or record.next <= #record.data) then
							record.distance = distance
							table.insert(candidates, record)
						end
					end
				end
			end
			table.sort(candidates, function(a, b) return a.distance < b.distance end)
		end
		if riding or now < resumeAt or now < hitchUntil or work >= limit or os.clock() >= deadline then return end
		if slow then
			if now < nextSlowBuild then return end
			nextSlowBuild = now + 0.25
		end
		for _, record in candidates do
			if records[record.model] ~= record or not record.model:IsDescendantOf(workspace) then continue end
			if not record.data then
				local raw = record.model:GetAttribute("CityDetailData")
				if raw then
					local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
					if ok and type(data) == "table" then record.data = data end
				end
				if os.clock() >= deadline then return end
			end
			if not record.data then continue end
			while record.next <= #record.data do
				if not record.folder then
					record.folder = Instance.new("Folder")
					record.folder.Name = "CityLocalDetail"
					record.folder.Parent = record.model
					record.parts = {}
				end
				table.insert(record.parts, create(record.data[record.next], record.folder))
				record.next += 1
				work += 1
				if work >= limit or os.clock() >= deadline then return end
			end
		end
	end)
end

return CityDetail
