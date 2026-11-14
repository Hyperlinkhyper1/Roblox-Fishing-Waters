local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Schedule = require(ReplicatedStorage.Shared.MetroSchedule)
local Train = require(ReplicatedStorage.Shared.MetroTrain)

-- Names this module's per-frame work in the MicroProfiler (otherwise it is all "Script_Client").
local function profiled<A...>(label: string, callback: (A...) -> ()): (A...) -> ()
	if not debug.profilebegin then
		return callback -- test runners without the MicroProfiler API
	end
	return function(...: A...)
		debug.profilebegin(label)
		callback(...)
		debug.profileend()
	end
end
local Metro = {}
local started = false
local BUILD_PARTS_PER_STEP = 8
local POSE_INTERVAL = 1 / 30

local function make(class, parent, props)
	local item = Instance.new(class)
	for key, value in props do item[key] = value end
	item.Parent = parent
	return item
end

function Metro.start()
	if started then return end
	started = true
	local player = Players.LocalPlayer
	local transit = ReplicatedStorage:WaitForChild("MetroTransit")
	local remote = transit:WaitForChild("Ride")
	local trains, ride, savedCamera = {}, nil, nil
	local visuals = make("Folder", workspace, { Name = "MetroVisuals" })
	local gui = make("ScreenGui", player:WaitForChild("PlayerGui"), {
		Name = "MetroJourney", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 70, Enabled = false,
	})
	local tunnel = make("Frame", gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(13, 24, 26), BorderSizePixel = 0 })
	local streaks = {}
	for i = 1, 12 do
		streaks[i] = make("Frame", tunnel, {
			Size = UDim2.fromScale(0.08 + i % 3 * 0.07, 0.002), Position = UDim2.fromScale(i / 12, i / 14),
			BackgroundColor3 = Color3.fromRGB(175, 153, 107), BackgroundTransparency = 0.8, BorderSizePixel = 0,
		})
	end
	local card = make("Frame", gui, {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.92), Size = UDim2.new(0.88, 0, 0, 136),
		BackgroundColor3 = Color3.fromRGB(25, 59, 56), BackgroundTransparency = 0.04, BorderSizePixel = 0,
	})
	make("UISizeConstraint", card, { MaxSize = Vector2.new(650, 136) })
	make("UICorner", card, { CornerRadius = UDim.new(0, 8) })
	make("UIStroke", card, { Color = Color3.fromRGB(185, 151, 83), Thickness = 1 })
	local function label(words, y, height, size, color)
		return make("TextLabel", card, {
			Text = words, Position = UDim2.new(0, 22, 0, y), Size = UDim2.new(1, -44, 0, height),
			BackgroundTransparency = 1, TextColor3 = color or Color3.fromRGB(243, 233, 207),
			Font = Enum.Font.GothamMedium, TextSize = size, TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
	end
	local route = label("", 13, 26, 20)
	local status = label("", 43, 23, 15, Color3.fromRGB(214, 193, 142))
	local line = make("Frame", card, { Position = UDim2.new(0, 24, 0, 87), Size = UDim2.new(1, -48, 0, 3), BackgroundColor3 = Color3.fromRGB(89, 115, 103), BorderSizePixel = 0 })
	local progress = make("Frame", line, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(222, 190, 111), BorderSizePixel = 0 })
	local dot = make("Frame", line, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(11, 11), BackgroundColor3 = Color3.fromRGB(250, 229, 171), BorderSizePixel = 0 })
	make("UICorner", dot, { CornerRadius = UDim.new(1, 0) })
	local ends = label("", 102, 18, 12, Color3.fromRGB(180, 201, 183))
	local function restore()
		ride, gui.Enabled = nil, false
		local camera = workspace.CurrentCamera
		if camera and savedCamera then
			camera.CameraType, camera.FieldOfView = savedCamera.kind, savedCamera.fov
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			camera.CameraSubject = humanoid or savedCamera.subject
		end
		savedCamera = nil
	end
	remote.OnClientEvent:Connect(function(action, data)
		if action == "Depart" then
			restore()
			ride, gui.Enabled = data, true
			tunnel.BackgroundTransparency = 1 - Schedule.darkness(workspace:GetServerTimeNow(), data.departure)
			local camera = workspace.CurrentCamera
			if camera then savedCamera = { kind = camera.CameraType, fov = camera.FieldOfView, subject = camera.CameraSubject } end
			route.Text = "1  ·  " .. data.origin .. "  →  " .. data.destination
			ends.Text = data.origin .. "                         " .. data.destination
		elseif action == "Transfer" and ride then
			ride.dock = data.dock
		elseif action == "Arrive" or action == "Cancel" then
			restore()
		end
	end)
	player.CharacterRemoving:Connect(restore)
	player:GetAttributeChangedSignal("MetroRiding"):Connect(function()
		if not player:GetAttribute("MetroRiding") then restore() end
	end)
	local function added(stop)
		if trains[stop] or not stop:FindFirstChild("TrainDock") then return end
		local boards = {}
		for _, p in stop:GetDescendants() do
			if p.Name == "DepartureBoard" then
				for _, label in p:GetDescendants() do
					if label:IsA("TextLabel") then table.insert(boards, { label = label, destination = p:GetAttribute("MetroDestination") }) end
				end
			end
		end
		trains[stop] = { boards = boards, dock = stop.TrainDock.CFrame }
	end
	CollectionService:GetInstanceAddedSignal("MetroStop"):Connect(added)
	CollectionService:GetInstanceRemovedSignal("MetroStop"):Connect(function(stop)
		local train = trains[stop]
		if train then
			if train.model then train.model:Destroy() end
			if train.partial then train.partial:Destroy() end
			trains[stop] = nil
		end
	end)
	for _, stop in CollectionService:GetTagged("MetroStop") do added(stop) end
	-- Build only nearby trains. Their hundreds of parts are registered in small
	-- groups across frames, rather than parenting a whole train on arrival.
	RunService.Heartbeat:Connect(profiled("Metro", function()
		local camera = workspace.CurrentCamera
		if not camera or transit:GetAttribute("Ready") ~= true then return end
		for stop, train in trains do
			if not train.model and not train.building and (camera.CFrame.Position - train.dock.Position).Magnitude < 650 then
				train.building = true
				task.spawn(function()
					local count = 0
					local ok, model, doors = pcall(Train.build, visuals, train.dock, false, function(partial)
						train.partial = partial
						if trains[stop] ~= train then error("Station streamed out", 0) end
						count += 1
						if count % BUILD_PARTS_PER_STEP == 0 then task.wait() end
					end)
					train.building = false
					if ok and trains[stop] == train then
						train.model, train.doors = model, doors
					elseif train.partial then
						train.partial:Destroy()
						if trains[stop] == train then warn("[Metro] Could not build train: " .. tostring(model)) end
					end
					train.partial = nil
				end)
				return
			end
		end
	end))
	local lastSecond = -1
	RunService:BindToRenderStep("Metro", Enum.RenderPriority.Camera.Value + 1, profiled("Metro/2", function()
		local now = workspace:GetServerTimeNow()
		local state, active = Schedule.state(now), transit:GetAttribute("Ready") == true
		local second = math.floor(now)
		local camera = workspace.CurrentCamera
		local focus = camera and camera.CFrame.Position
		for stop, train in trains do
			local nearby = focus and (focus - train.dock.Position).Magnitude < 650
			-- Keep the model registered. Reparenting hundreds of parts every arrival
			-- causes avoidable render-registration spikes on weaker clients.
			if train.model and (train.active ~= active or (nearby and now >= (train.nextPose or 0) and (train.offset ~= state.offset or train.open ~= state.doors))) then
				local frame = if active then Schedule.frame(train.dock, now) else train.dock * CFrame.new(0, -100, 0)
				Train.pose(train.model, train.doors, frame, state.doors)
				train.active, train.offset, train.open = active, state.offset, state.doors
				train.nextPose = now + POSE_INTERVAL
			end
			if second ~= lastSecond then
				local message = if not active then "Service preparing" elseif state.boarding then "Doors open · Departs in " .. state.seconds .. "s"
					elseif state.phase < Schedule.OPEN then "Arriving · Stand back" elseif state.phase < Schedule.TUNNEL then "Doors closed · Next in " .. state.seconds .. "s"
					else "Next train  0:" .. string.format("%02d", state.seconds)
				for _, board in train.boards do board.label.Text = "1  " .. board.destination .. "\n" .. message end
			end
		end
		lastSecond = second
		if not ride then return end
		local amount = math.clamp((now - ride.departure) / (ride.arrival - ride.departure), 0, 1)
		progress.Size, dot.Position = UDim2.fromScale(amount, 1), UDim2.fromScale(amount, 0.5)
		local onArrival = now >= ride.arrival - Schedule.OPEN
		local darkness = Schedule.darkness(now, ride.departure)
		tunnel.BackgroundTransparency = 1 - darkness
		for i, streak in streaks do
			streak.Visible = darkness > 0.9
			streak.Position = UDim2.fromScale(1 - ((now * (0.25 + i * 0.017) + i / 12) % 1), i / 14)
		end
		status.Text = if onArrival then "Arriving at " .. ride.destination elseif state.phase < Schedule.DEPART then "Doors closing · Please stand clear"
			elseif state.phase < Schedule.TUNNEL then "Departing " .. ride.origin else "Travelling to " .. ride.destination .. " · " .. math.max(0, math.ceil(ride.arrival - now)) .. "s"
		if camera then
			if not savedCamera then savedCamera = { kind = camera.CameraType, fov = camera.FieldOfView, subject = camera.CameraSubject } end
			camera.CameraType, camera.FieldOfView = Enum.CameraType.Scriptable, 68
			local frame = Schedule.frame(ride.dock, now)
			camera.CFrame = CFrame.lookAt(frame * Vector3.new(-3, 5.7, 0.8), frame * Vector3.new(2, 5, -12))
		end
		-- A missing completion packet must not leave the player in a scripted camera.
		if now > ride.arrival + 8 then restore() end
	end))
end

return Metro
