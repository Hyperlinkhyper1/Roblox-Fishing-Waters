-- Building shells and collision stream normally; their optional facades are reconstructed locally
-- in small batches, nearest first. No full-detail model is replicated during a metro transfer.
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CityDetail = {}
local RADIUS = 350
local PARTS_PER_FRAME = 6
local FRAME_BUDGET = 0.002
local RESORT_INTERVAL = 0.5
local records = {}

local function position(model)
	local part = model:FindFirstChildWhichIsA("BasePart")
	return if part then part.Position else model:GetAttribute("CityDetailAnchor")
end

local function create(data, parent)
	local part = Instance.new("Part")
	part.Name = data[1]
	part.Size = Vector3.new(data[2], data[3], data[4])
	part.CFrame = CFrame.new(table.unpack(data, 5, 16))
	part.Color = Color3.new(data[17], data[18], data[19])
	part.Material = Enum.Material[data[20]]
	part.Shape = Enum.PartType[data[21]]
	part.Transparency, part.Reflectance, part.CastShadow = data[22], data[23], data[24]
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
	part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if data[27] then part:SetAttribute("GlowColor", Color3.new(table.unpack(data[27]))) end
	if data[28] then part:SetAttribute("GlowAt", data[28]) end
	if data[25] then part:AddTag("NightGlow") end
	if data[26] then part:AddTag("AviationBeacon") end
	part.Parent = parent
end

function CityDetail.start()
	local player = Players.LocalPlayer
	local function added(model)
		if records[model] then return end
		-- Tags and attributes need not arrive together. Decode only when a nearby building
		-- gets its turn, rather than decoding a whole streaming burst in one frame.
		records[model] = { model = model, next = 1 }
	end
	local function removed(model)
		local record = records[model]
		if not record then return end
		if record.folder then record.folder:Destroy() end
		records[model] = nil
	end
	CollectionService:GetInstanceAddedSignal("CityDetail"):Connect(added)
	CollectionService:GetInstanceRemovedSignal("CityDetail"):Connect(removed)
	for _, model in CollectionService:GetTagged("CityDetail") do added(model) end

	local candidates, nextSort, lastSlowWork = {}, 0, 0
	local wasRiding, resumeAt = false, 0
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		local riding = player:GetAttribute("MetroRiding") == true
		if wasRiding and not riding then resumeAt = now + 8 end
		wasRiding = riding
		if riding or now < resumeAt then return end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then return end
		if now >= nextSort then
			nextSort = now + RESORT_INTERVAL
			table.clear(candidates)
			for model, record in records do
				if not record.finished and model:IsDescendantOf(workspace) then
					record.position = record.position or position(model)
					if record.position then
						local distance = (record.position - root.Position).Magnitude
						if distance <= RADIUS then
							record.distance = distance
							table.insert(candidates, record)
						end
					end
				end
			end
			table.sort(candidates, function(a, b) return a.distance < b.distance end)
		end
		-- Under heavy load make occasional progress, but do not add six registrations to every slow frame.
		local limit = PARTS_PER_FRAME
		if dt > 1 / 30 then
			if now - lastSlowWork < 0.25 then return end
			lastSlowWork, limit = now, 1
		end
		local started, made = os.clock(), 0
		for _, record in candidates do
			if not record.data then
				local raw = record.model:GetAttribute("CityDetailData")
				if raw then
					local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
					if ok and type(data) == "table" then record.data = data end
				end
				if os.clock() - started >= FRAME_BUDGET then return end
			end
			if not record.data then continue end
			while records[record.model] == record and record.model:IsDescendantOf(workspace) and record.next <= #record.data do
				if not record.folder then
					record.folder = Instance.new("Folder")
					record.folder.Name = "CityLocalDetail"
					record.folder.Parent = record.model
				end
				create(record.data[record.next], record.folder)
				record.next += 1
				made += 1
				if made >= limit or os.clock() - started >= FRAME_BUDGET then return end
			end
			if record.next > #record.data then record.finished = true end
		end
	end)
end

return CityDetail
