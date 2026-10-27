-- Local stern spray for streamed-in, motor-powered player boats.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local BoatCatalog = require(ReplicatedStorage.Shared.BoatCatalog)
local Cargo = require(ReplicatedStorage.Shared.Cargo)
local Biomes = require(ReplicatedStorage.Shared.Biomes)
local Weather = require(ReplicatedStorage.Shared.Weather)

local BoatSpray = {}
local started = false
local MAX_DISTANCE = 280

local function stockMotors(spec): number
	local count = 0
	for _, item in spec.StarterParts or {} do
		local part = Cargo.Parts[item.PartId]
		if part and part.Motor then
			count += 1
		end
	end
	return count
end

local function makeSpray(model: Model, root: BasePart, spec, offset: Vector3)
	local jets = {}
	local transom = model:FindFirstChild("TransomCap", true) or model:FindFirstChild("TransomTrim", true)
	local stern = if transom and transom:IsA("BasePart")
		then root.CFrame:PointToObjectSpace(transom.Position).Z
		else spec.Length / 2 - offset.Z
	for _, side in { -1, 1 } do
		local attachment = Instance.new("Attachment")
		attachment.Name = "MotorSpray"
		-- Builders face -Z; +Z is behind the transom, at the waterline.
		local position = Vector3.new(side * spec.Beam * 0.16 - offset.X, 0.1 - offset.Y, stern + 0.7)
		attachment.CFrame = CFrame.lookAt(position, position + Vector3.new(side * 0.12, 0.32, 1))
		attachment.Parent = root
		local spray = Instance.new("ParticleEmitter")
		spray.Name = "WaterSpray"
		spray.Texture = "rbxasset://textures/particles/smoke_main.dds"
		spray.Color = ColorSequence.new(Color3.fromRGB(224, 244, 248))
		spray.LightInfluence = 0.6
		spray.EmissionDirection = Enum.NormalId.Front
		spray.SpreadAngle = Vector2.new(20, 12)
		spray.Lifetime = NumberRange.new(0.3, 0.65)
		spray.Acceleration = Vector3.new(0, -28, 0)
		spray.Drag = 1.5
		spray.VelocityInheritance = 0.15
		spray.LockedToPart = false
		spray.Rotation = NumberRange.new(0, 360)
		spray.RotSpeed = NumberRange.new(-40, 40)
		spray.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(0.35, 0.8),
			NumberSequenceKeypoint.new(1, 1.5),
		})
		spray.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(0.3, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		})
		spray.Rate = 0
		spray.Enabled = false
		spray.Parent = attachment
		table.insert(jets, { attachment = attachment, spray = spray })
	end
	return jets
end

function BoatSpray.start()
	if started then
		return
	end
	started = true
	local records = {}
	local scan = 0.3
	RunService.Heartbeat:Connect(function(dt)
		local folder = workspace:FindFirstChild("PlayerBoats")
		scan += dt
		if folder and scan >= 0.3 then
			scan = 0
			for _, model in folder:GetChildren() do
				if not model:IsA("Model") or records[model] then
					continue
				end
				local spec = BoatCatalog[model:GetAttribute("BoatId")]
				local root = model.PrimaryPart
				local seat = spec and model:FindFirstChild(spec.DriverSeat, true)
				if root and seat and seat:IsA("VehicleSeat") then
					records[model] = { root = root, seat = seat, spec = spec, stock = stockMotors(spec) }
				end
			end
		end
		local camera = workspace.CurrentCamera
		for model, record in records do
			local root, seat, spec = record.root, record.seat, record.spec
			if
				not folder
				or model.Parent ~= folder
				or not root:IsDescendantOf(model)
				or not seat:IsDescendantOf(model)
			then
				for _, jet in record.jets or {} do
					jet.attachment:Destroy()
				end
				records[model] = nil
				continue
			end
			local motors = model:GetAttribute("MotorCount") or record.stock
			local velocity = root.AssemblyLinearVelocity
			local speed = math.abs(velocity:Dot(root.CFrame.LookVector))
			local nearby = camera and (root.Position - camera.CFrame.Position).Magnitude <= MAX_DISTANCE
			local driver = seat.Occupant
			local active = motors > 0
				and nearby
				and driver
				and driver.Health > 0
				and speed > 2
				and not model:GetAttribute("Parked")
				and not model:GetAttribute("Hoisted")
				and not model:GetAttribute("DisplayOnly")
			if active then
				-- A thrown hull must not spray while away from the surface.
				local wave = Weather.sample(root.Position, workspace:GetServerTimeNow())
				active = math.abs(root.Position.Y - (Biomes.WaterLevel + wave.height)) < 5
			end
			if active and not record.jets then
				record.jets =
					makeSpray(model, root, spec, model:GetAttribute("WaterlineRootOffset") or Vector3.new(0, -0.4, 0))
			end
			local strength = math.clamp(speed / spec.ForwardSpeed, 0, 1)
			for _, jet in record.jets or {} do
				jet.spray.Enabled = active == true
				jet.spray.Rate = if active then 25 + strength * 85 else 0
				jet.spray.Speed = NumberRange.new(7 + strength * 7, 11 + strength * 12)
				if not nearby then
					jet.spray:Clear()
				end
			end
		end
	end)
end

return BoatSpray
