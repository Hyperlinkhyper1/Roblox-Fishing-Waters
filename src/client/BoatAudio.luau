-- Each client mixes positional engines for every boat it has streamed in.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local BoatCatalog = require(ReplicatedStorage.Shared.BoatCatalog)

local BoatAudio = {}
local started = false

function BoatAudio.start()
	if started then
		return
	end
	started = true
	local records = {}
	RunService.Heartbeat:Connect(function(dt)
		local folder = workspace:FindFirstChild("PlayerBoats")
		if folder then
			for _, model in folder:GetChildren() do
				local spec = BoatCatalog[model:GetAttribute("BoatId")]
				if spec and spec.EngineSoundId and model:IsA("Model") and not records[model] then
					local root = model.PrimaryPart
					local seat = model:FindFirstChild(spec.DriverSeat, true)
					if root and seat and seat:IsA("VehicleSeat") then
						local sound = Instance.new("Sound")
						sound.Name = "BoatEngine"
						sound.SoundId = spec.EngineSoundId
						sound.Looped = true
						sound.Volume = 0
						sound.PlaybackSpeed = 0.75
						sound.RollOffMode = Enum.RollOffMode.InverseTapered
						sound.RollOffMinDistance = 12
						sound.RollOffMaxDistance = 140
						sound.Parent = root
						records[model] = { sound = sound, root = root, seat = seat, spec = spec }
					end
				end
			end
		end
		local blend = 1 - math.exp(-8 * math.clamp(dt, 0, 0.1))
		for model, record in records do
			local sound = record.sound
			if
				not folder
				or model.Parent ~= folder
				or not record.root:IsDescendantOf(model)
				or not record.seat:IsDescendantOf(model)
			then
				sound:Destroy()
				records[model] = nil
				continue
			end
			local occupant = record.seat.Occupant
			local running = occupant ~= nil and occupant.Health > 0
			local throttle = if running then math.abs(model:GetAttribute("RowThrottle") or 0) else 0
			local velocity = record.root.AssemblyLinearVelocity
			local speed = Vector2.new(velocity.X, velocity.Z).Magnitude
			local rpm = math.clamp(math.max(throttle * 0.8, speed / record.spec.ForwardSpeed), 0, 1)
			local volume = if running then 0.18 + rpm * 0.5 else 0
			sound.Volume += (volume - sound.Volume) * blend
			sound.PlaybackSpeed += (0.75 + rpm * 0.8 - sound.PlaybackSpeed) * blend
			if running then
				if not sound.IsPlaying then
					sound:Play()
				end
			elseif sound.Volume < 0.001 then
				sound.Volume = 0
				if sound.IsPlaying then
					sound:Stop()
				end
			end
		end
	end)
end

return BoatAudio
