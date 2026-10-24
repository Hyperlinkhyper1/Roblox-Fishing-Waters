-- Isolated F5 regression with a real client-owned character and terrain water.
-- This file is not shipped by default.project.json. Results appear in Output.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Service = require(script.Parent.BoatService)
local level = require(game.ReplicatedStorage.Shared.Biomes).WaterLevel
local checks = 0
local function check(condition, message)
	checks += 1
	assert(condition, "[BoatIdleRegression] " .. message)
end
local function untilTrue(predicate, seconds)
	local deadline = os.clock() + seconds
	repeat
		RunService.Heartbeat:Wait()
		if predicate() then return true end
	until os.clock() >= deadline
	return false
end
local function run()
	workspace.Terrain:FillBlock(CFrame.new(0, level - 24, 0), Vector3.new(512, 48, 512), Enum.Material.Water)
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(24, 1, 24)
	spawn.CFrame = CFrame.new(0, level + 5, 40)
	spawn.Parent = workspace
	workspace:SetAttribute("WeatherEpoch", workspace:GetServerTimeNow())
	workspace:SetAttribute("WeatherOverride", "Storm")
	Service.start()
	-- Test-only telemetry listener; this action is ignored by the production API.
	game.ReplicatedStorage.Boating.Request.OnServerEvent:Connect(function(player, action, samples, contacts, slip)
		if action == "IdleRegressionSample" then
			player:SetAttribute("BoatRegressionIdleSamples", samples)
			player:SetAttribute("BoatRegressionIdleContacts", contacts)
			player:SetAttribute("BoatRegressionIdleSlip", slip)
		end
	end)
	check(untilTrue(function() return #Players:GetPlayers() > 0 end, 60), "Start with F5 to create a real player")
	local player = Players:GetPlayers()[1]
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")
	local avatarRoot = character:WaitForChild("HumanoidRootPart")
	for index, id in { "Rowboat", "FishingBoat" } do
		workspace:SetAttribute("BoatRegressionPhase", "Stand")
		local boat = Service.launch(player, CFrame.new((index - 1) * 50 - 25, level, 0), nil, id)
		workspace:SetAttribute("BoatRegressionBoatName", boat.model.Name)
		character:PivotTo(boat.root.CFrame * CFrame.new(0, 5, -2))
		avatarRoot.AssemblyLinearVelocity = Vector3.zero
		local held = boat.root.CFrame
		local contactFrames = 0
		for _, phase in { "Stand", "Walk", "Jump" } do
			workspace:SetAttribute("BoatRegressionPhase", phase)
			local deadline = os.clock() + 3
			repeat
				RunService.Heartbeat:Wait()
				check(boat.root.Anchored and boat.parked, id .. " must remain parked during " .. phase)
				check((boat.root.Position - held.Position).Magnitude < 0.001, id .. " deck moved during " .. phase)
				local _, angle = held:ToObjectSpace(boat.root.CFrame):ToAxisAngle()
				check(math.abs(angle) < 0.001, id .. " deck rotated during " .. phase)
				check(not boat.float.Enabled and not boat.lift.Enabled and not boat.heading.Enabled and not boat.velocity.Enabled, "Parked movers must remain disabled")
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = { character }
				params.IgnoreWater = true
				local ground = workspace:Raycast(avatarRoot.Position, Vector3.new(0, -8, 0), params)
				if ground and ground.Instance:IsDescendantOf(boat.model) then contactFrames += 1 end
			until os.clock() > deadline
		end
		check(contactFrames > 60, id .. " character must actually spend time over the deck")
		check(humanoid.Health > 0 and avatarRoot.Position.Y > level, id .. " character fell through the deck")
		workspace:SetAttribute("BoatRegressionPhase", "Board")
		character:PivotTo(boat.seat.CFrame + Vector3.new(0, 3, 0))
		boat.seat:Sit(humanoid)
		check(untilTrue(function() return boat.seat.Occupant == humanoid end, 3), id .. " helm must remain usable while parked")
		workspace:SetAttribute("BoatRegressionPhase", "Drive")
		check(untilTrue(function() return not boat.parked end, 3), id .. " actual client controls must release the boat")
		check(not boat.root.Anchored and boat.root:GetNetworkOwner() == nil, id .. " release must restore server ownership")
		local initialPosition = boat.root.Position
		task.wait(1.5)
		check((boat.root.Position - initialPosition).Magnitude > 1, id .. " must sail after release")
		workspace:SetAttribute("BoatRegressionPhase", "Coast")
		check(untilTrue(function() return boat.parked end, 30), id .. " must coast to a parked stop")
		check(boat.root.AssemblyLinearVelocity.Magnitude < 0.01 and boat.root.AssemblyAngularVelocity.Magnitude < 0.01, id .. " must clear residual velocities")
		workspace:SetAttribute("BoatRegressionPhase", "Stand")
		humanoid.Sit = false
		task.wait(0.3)
		character:PivotTo(boat.root.CFrame * CFrame.new(0, 5, -2))
		local stopped = boat.root.CFrame
		player:SetAttribute("BoatRegressionIdleSamples", 0)
		player:SetAttribute("BoatRegressionIdleContacts", 0)
		player:SetAttribute("BoatRegressionIdleSlip", 0)
		workspace:SetAttribute("BoatRegressionPhase", "IdleAfterDrive")
		task.wait(30)
		check(boat.root.CFrame == stopped and boat.root.Anchored, id .. " must stay fixed after dismounting")
		local samples = player:GetAttribute("BoatRegressionIdleSamples") or 0
		local contacts = player:GetAttribute("BoatRegressionIdleContacts") or 0
		local slip = player:GetAttribute("BoatRegressionIdleSlip") or math.huge
		check(samples > 300, id .. " client must measure idle drift after sailing")
		check(contacts > samples * 0.95, id .. " idle character must stay standing on the animated deck")
		check(slip < 0.3, id .. " idle character drifted " .. tostring(slip) .. " studs across the deck")
		print("[BoatIdleRegression] " .. id .. ": standing, walking, jumping, real client driving, coasting and dismount passed")
		boat.model:Destroy()
	end
	workspace:SetAttribute("BoatRegressionPhase", "Done")
	workspace:SetAttribute("BoatRegressionPassed", true)
	print("[BoatIdleRegression] PASS: " .. checks .. " live engine checks; both boats")
end
task.spawn(function()
	local ok, failure = xpcall(run, debug.traceback)
	if not ok then
		workspace:SetAttribute("BoatRegressionPassed", false)
		warn(failure)
	end
end)
