-- Public ferry crossings. The active crossing belongs to the player and to the exact boat;
-- no remote accepts an award or a destination from the client.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BoatService = require(script.Parent.BoatService)
local Ferry = require(ReplicatedStorage.Shared.Ferry)

local Service = {}
local started = false
local stops = {}
local trips = {}
local unlocked = {}
local busy = {}

local function notify(player, message)
	local boating = ReplicatedStorage:FindFirstChild("Boating")
	local feedback = boating and boating:FindFirstChild("Feedback")
	if feedback and player.Parent == Players then feedback:FireClient(player, "Notice", message) end
end

local function clearTrip(player)
	local trip = trips[player]
	trips[player] = nil
	if trip and trip.passengers then trip.passengers:Destroy() end
	player:SetAttribute("FerryDestination", nil)
	player:SetAttribute("FerryDestinationPosition", nil)
end

-- Lightweight seated figures are welded to the hull, so they travel with it and don't
-- interfere with physics, players, or the boat's driver seat.
local function passengersOn(boat)
	local seats = {}
	for i = 1, Ferry.PASSENGERS do
		local seat = boat:FindFirstChild("FerryPassengerSeat" .. i, true)
		if not seat or not seat:IsA("Seat") or seat.Occupant then return nil end
		table.insert(seats, seat)
	end
	for _, seat in seats do seat.Disabled = true end
	local folder = Instance.new("Folder")
	folder.Destroying:Connect(function()
		for _, seat in seats do
			if seat.Parent then seat.Disabled = false end
		end
	end)
	folder.Name = "FerryPassengers"
	local shirts = { Color3.fromRGB(91, 138, 163), Color3.fromRGB(207, 126, 95), Color3.fromRGB(128, 157, 102), Color3.fromRGB(172, 132, 166) }
	local skins = { Color3.fromRGB(235, 192, 153), Color3.fromRGB(160, 105, 72), Color3.fromRGB(215, 169, 122), Color3.fromRGB(117, 75, 52) }
	local function piece(parent, seat, name, size, offset, color, shape)
		local part = Instance.new("Part")
		part.Name, part.Size, part.Color = name, size, color
		part.Material = Enum.Material.SmoothPlastic
		part.CanCollide, part.CanTouch, part.CanQuery, part.Massless = false, false, false, true
		if shape then part.Shape = shape end
		part.CFrame = seat.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = seat, part, part
		part.Parent = parent
	end
	for i, seat in seats do
		local model = Instance.new("Model")
		model.Name = "Passenger" .. i
		model.Parent = folder
		piece(model, seat, "Torso", Vector3.new(1.7, 1.8, 0.9), CFrame.new(0, 1.4, 0), shirts[i])
		piece(model, seat, "Head", Vector3.new(1.05, 1.05, 1.05), CFrame.new(0, 2.8, 0), skins[i], Enum.PartType.Ball)
		piece(model, seat, "LeftArm", Vector3.new(0.45, 1.5, 0.5), CFrame.new(-1.05, 1.35, 0), shirts[i])
		piece(model, seat, "RightArm", Vector3.new(0.45, 1.5, 0.5), CFrame.new(1.05, 1.35, 0), shirts[i])
		piece(model, seat, "LeftLeg", Vector3.new(0.65, 0.6, 1.6), CFrame.new(-0.43, 0.55, -0.55), Color3.fromRGB(54, 65, 75))
		piece(model, seat, "RightLeg", Vector3.new(0.65, 0.6, 1.6), CFrame.new(0.43, 0.55, -0.55), Color3.fromRGB(54, 65, 75))
	end
	folder.Parent = boat
	return folder
end

local function distance(a, b)
	return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

local function useStop(player, origin, stop)
	if busy[player] then return end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local boatId, boat = BoatService.activeBoat(player)
	if boatId ~= Ferry.BOAT_ID or not boat or not boat.PrimaryPart then
		if trips[player] then clearTrip(player) end
		notify(player, "Launch your Small Ferry and bring it alongside the public ferry dock.")
		return
	end
	local trip = trips[player]
	if trip and trip.boat ~= boat then
		clearTrip(player)
		notify(player, "Your previous passengers left when you changed boats. Start a new crossing.")
		return
	end
	local action, reason = Ferry.action(origin, trip, unlocked[player] == true, trip == nil or trip.boat == boat,
		distance(boat.PrimaryPart.Position, stop.Position), if root then (root.Position - stop.Position).Magnitude else math.huge)
	if action == "reject" then notify(player, reason) return end
	if action == "board" then
		local destination = Ferry.destination(origin)
		local other = stops[destination]
		if not other or not other:IsDescendantOf(workspace) then
			notify(player, "The destination dock is still being prepared. Please try again shortly.")
			return
		end
		local figures = passengersOn(boat)
		if not figures then notify(player, "All four passenger seats must be free before boarding.") return end
		trips[player] = { destination = destination, boat = boat, passengers = figures }
		unlocked[player] = true
		player:SetAttribute("FerryDestination", destination)
		player:SetAttribute("FerryDestinationPosition", other.Position)
		notify(player, "Four passengers are aboard! Sail to the " .. destination .. " ferry dock and collect $" .. Ferry.FARE .. ". Follow the arrow or blue diamond on the map (M).")
		return
	end
	busy[player] = true
	local ok, message = BoatService.updateProgress(player, function(profile)
		profile.Cash += Ferry.FARE
	end)
	busy[player] = nil
	if not ok then notify(player, message) return end
	clearTrip(player)
	notify(player, "Passengers delivered! You earned $" .. Ferry.FARE .. ". Board another crossing here.")
end

local function install(instance)
	local origin = if instance.Name == "FerryMainStop" then "Main" elseif instance.Name == "FerryCityStop" then "City" else nil
	if not origin or not instance:IsA("BasePart") then return end
	stops[origin] = instance
	if instance:FindFirstChild("FerryPrompt") then return end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FerryPrompt"
	prompt.ActionText = "Board / deliver passengers"
	prompt.ObjectText = if origin == "Main" then "Main Island Ferry · $" .. Ferry.FARE .. " per crossing" else "City Ferry · $" .. Ferry.FARE .. " per crossing"
	prompt.MaxActivationDistance = Ferry.PLAYER_RANGE
	prompt.RequiresLineOfSight = false
	prompt.Parent = instance
	prompt.Triggered:Connect(function(player) useStop(player, origin, instance) end)
end

function Service.start()
	if started then return end
	started = true
	workspace.DescendantAdded:Connect(install)
	for index, instance in workspace:GetDescendants() do
		install(instance)
		if index % 1000 == 0 then task.wait() end
	end
	Players.PlayerRemoving:Connect(function(player)
		clearTrip(player)
		unlocked[player], busy[player] = nil, nil
	end)
	-- Clean up if the ferry sinks or is replaced while a crossing is active.
	task.spawn(function()
		while true do
			task.wait(2)
			for player, trip in trips do
				local id, boat = BoatService.activeBoat(player)
				if not busy[player] and (id ~= Ferry.BOAT_ID or boat ~= trip.boat or not trip.boat:IsDescendantOf(workspace)) then
					clearTrip(player)
					notify(player, "Your ferry crossing ended because the ferry was lost or replaced.")
				end
			end
		end
	end)
end
return Service
