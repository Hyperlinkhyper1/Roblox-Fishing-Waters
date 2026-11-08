-- The server owns boarding, riders and transfers. Train visuals use the same
-- absolute clock on each client; hundreds of decorative parts never move over the network.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Schedule = require(ReplicatedStorage.Shared.MetroSchedule)
local Train = require(ReplicatedStorage.Shared.MetroTrain)
local Service = {}
local started = false
local stops, rides, cooldown, pins = {}, {}, {}, {}
local transit, remote

local function ready(stop)
	return stop and stop:IsDescendantOf(workspace) and stop:FindFirstChild("Arrival")
		and stop:FindFirstChild("Boarding") and stop:FindFirstChild("TrainDock")
end

local function running()
	return ready(stops.Harbour and stops.Harbour.model) and ready(stops.City and stops.City.model)
end

local function body(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character and character.Parent and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return character, humanoid, root
	end
end

local function releasePin(player, stop)
	if stop and stop.Parent then stop:RemovePersistentPlayer(player) end
end

local function finish(player, ride, destination, cancelled)
	if rides[player] ~= ride then return end
	rides[player] = nil
	local character, _, root = body(player)
	-- Only touch the captured avatar, never a replacement spawned during a yield.
	if root == ride.root then
		if ready(destination) then character:PivotTo(destination.Arrival.CFrame) end
		root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	end
	if ride.root.Parent then ride.root.Anchored = ride.anchored end
	if ride.humanoid.Parent then ride.humanoid.AutoRotate = ride.autoRotate end
	if ride.character.Parent then ride.character:SetAttribute("MetroRiding", nil) end
	player:SetAttribute("MetroRiding", nil)
	if ride.pinned and destination ~= ride.destination then releasePin(player, ride.destination) end
	if destination == ride.destination and ride.pinned then
		if pins[player] ~= destination then releasePin(player, pins[player]) end
		pins[player] = destination
	end
	if player.Parent then remote:FireClient(player, if cancelled then "Cancel" else "Arrive") end
end

local function beginRide(player, source, state)
	local character, humanoid, root = body(player)
	local id = source:GetAttribute("MetroStopId")
	local destination = stops[Schedule.OTHER[id]]
	if rides[player] or not character or humanoid.SeatPart or root.Anchored or not destination then return end
	local offset = source.TrainDock.CFrame:ToObjectSpace(root.CFrame)
	if not Schedule.inside(offset.Position) then return end
	local ride = {
		character = character, humanoid = humanoid, root = root, offset = offset,
		source = source, destination = destination.model, current = source,
		cycle = state.cycle, anchored = root.Anchored, autoRotate = humanoid.AutoRotate,
		transferred = false, pinned = false,
	}
	rides[player] = ride
	root.Anchored, humanoid.AutoRotate = true, false
	character:SetAttribute("MetroRiding", true)
	player:SetAttribute("MetroRiding", true)
	remote:FireClient(player, "Depart", {
		origin = Schedule.NAMES[id], destination = Schedule.NAMES[Schedule.OTHER[id]],
		dock = source.TrainDock.CFrame, departure = state.cycle * Schedule.PERIOD + Schedule.CLOSE,
		arrival = (state.cycle + 1) * Schedule.PERIOD + Schedule.OPEN,
	})
	-- Preload during the actual journey, with a separate task per passenger.
	task.spawn(function()
		local ok = pcall(function()
			ride.destination:AddPersistentPlayer(player)
			ride.pinned = true
			player:RequestStreamAroundAsync(ride.destination.Arrival.Position, 8)
		end)
		if rides[player] ~= ride then
			if ride.destination ~= pins[player] then releasePin(player, ride.destination) end
			return
		end
		ride.streamed = ok
		if ride.recovering then
			finish(player, ride, if ready(ride.destination) then ride.destination else nil, true)
		end
	end)
end

local function board(player, stop)
	local state = Schedule.state(workspace:GetServerTimeNow())
	local character, humanoid, root = body(player)
	if not running() or not state.boarding or rides[player] or not character
		or humanoid.SeatPart or root.Anchored or os.clock() - (cooldown[player] or -math.huge) < 2
		or (root.Position - stop.Boarding.Position).Magnitude > 12 then return end
	local id = stop:GetAttribute("MetroStopId")
	if not stops[id] or stops[id].model ~= stop then return end
	cooldown[player] = os.clock()
	-- This only enters the open carriage. Walking through any door also works.
	character:PivotTo(stop.TrainDock.CFrame * CFrame.new(-11, 3.5, -2.5))
	root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
end

local function setCollision(stop, enabled)
	if stop.collisionEnabled == enabled then return end
	stop.collisionEnabled = enabled
	for _, p in stop.hull:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = enabled and p.Name ~= "SlidingDoor"
		end
	end
end

function Service.start()
	if started then return end
	started = true
	transit = Instance.new("Folder")
	transit.Name = "MetroTransit"
	transit:SetAttribute("Ready", false)
	remote = Instance.new("RemoteEvent")
	remote.Name, remote.Parent = "Ride", transit
	transit.Parent = ReplicatedStorage
	local function added(model)
		local id = model:GetAttribute("MetroStopId")
		if not Schedule.OTHER[id] or not ready(model) or (stops[id] and stops[id].model == model) then return end
		local hull = Train.build(model, model.TrainDock.CFrame, true)
		local stop = { model = model, hull = hull, collisionEnabled = nil }
		stops[id] = stop
		setCollision(stop, false)
		stop.connection = model.Boarding.MetroBoardPrompt.Triggered:Connect(function(player) board(player, model) end)
	end
	CollectionService:GetInstanceAddedSignal("MetroStop"):Connect(added)
	CollectionService:GetInstanceRemovedSignal("MetroStop"):Connect(function(model)
		local id = model:GetAttribute("MetroStopId")
		local stop = stops[id]
		if stop and stop.model == model then
			stop.connection:Disconnect()
			stops[id] = nil
		end
		for player, ride in rides do
			if ride.source == model or ride.destination == model then
				if not ready(ride.source) and ready(ride.destination) and ride.streamed == nil then
					-- Keep the avatar anchored until the already-running preload returns.
					ride.recovering = true
				else
					local other = if ready(ride.source) then ride.source else ride.destination
					finish(player, ride, other, true)
				end
			end
		end
	end)
	for _, model in CollectionService:GetTagged("MetroStop") do added(model) end
	Players.PlayerRemoving:Connect(function(player)
		local ride = rides[player]
		if ride then finish(player, ride, nil, true) end
		releasePin(player, pins[player])
		pins[player], cooldown[player] = nil, nil
	end)
	local elapsed, lastBoarding, lastCycle = 0, false, nil
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.05 then return end
		elapsed = 0
		local now = workspace:GetServerTimeNow()
		local state, active = Schedule.state(now), running() and true or false
		transit:SetAttribute("Ready", active)
		-- Snapshot passengers before disabling the walkable hull at door closure.
		if active and lastBoarding and (not state.boarding or state.cycle ~= lastCycle) then
			for _, stop in stops do
				for _, player in Players:GetPlayers() do beginRide(player, stop.model, state) end
			end
		end
		for _, stop in stops do
			stop.model.Boarding.MetroBoardPrompt.Enabled = active and state.boarding
			setCollision(stop, active and state.boarding)
		end
		lastBoarding, lastCycle = active and state.boarding, state.cycle
		for player, ride in rides do
			local character, _, root = body(player)
			if character ~= ride.character or root ~= ride.root then
				finish(player, ride, ride.source, true)
				continue
			end
			if ride.recovering then continue end
			if not active or not ready(ride.current) then
				finish(player, ride, ride.source, true)
				continue
			end
			if now >= ride.cycle * Schedule.PERIOD + Schedule.TRANSFER and not ride.transferred and ride.streamed then
				ride.current, ride.transferred = ride.destination, true
				remote:FireClient(player, "Transfer", { dock = ride.destination.TrainDock.CFrame })
			end
			if now >= (ride.cycle + 1) * Schedule.PERIOD + Schedule.OPEN then
				finish(player, ride, if ride.transferred then ride.destination else ride.source, not ride.transferred)
			else
				ride.character:PivotTo(Schedule.frame(ride.current.TrainDock.CFrame, now) * ride.offset)
				root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
			end
		end
		-- A missed train cannot strand someone in the track bed beneath the platform.
		for _, player in Players:GetPlayers() do
			if rides[player] then continue end
			local character, _, root = body(player)
			if not character then continue end
			for _, stop in stops do
				local q = stop.model.TrainDock.CFrame:PointToObjectSpace(root.Position)
				if math.abs(q.X) < 95 and math.abs(q.Z) < 8 and q.Y < -0.5 and q.Y > -15 then
					character:PivotTo(stop.model.Arrival.CFrame)
					root.AssemblyLinearVelocity = Vector3.zero
				end
			end
		end
	end)
end

return Service
