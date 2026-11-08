-- Visual only: a landed catch is flung out of the water over the angler's head
-- with real physics, lands behind them, flops about and fades out. Nothing here
-- touches the real catch; each client simulates its own copy of the fish
-- (client-made parts are physically owned by that client), gone after LIFETIME.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Biomes = require(ReplicatedStorage.Shared.Biomes)
local FishModels = require(ReplicatedStorage.Shared.FishModels)

local CatchFling = {}

local LIFETIME = 7
local FADE_SECONDS = 0.7
-- Furthest out (studs) the fish leaps from, however far the cast went.
local MAX_LEAP = 18
-- The throw must clear the angler: head top above the root part, plus a small
-- gap and half the fish (it tumbles end over end).
local HEAD_ABOVE_ROOT, HEAD_CLEARANCE = 2.5, 1
-- Air time limits (s). Short air time under game gravity means a fast, flat yank.
local MIN_AIR, MAX_AIR = 0.35, 1
-- End-over-end spin on launch (rad/s).
local MIN_SPIN, MAX_SPIN = 9, 16
-- Light enough to float on water and to barely nudge anyone it touches.
local BODY_PHYSICS = PhysicalProperties.new(0.5, 0.7, 0.3, 1, 1)
local MAX_LENGTH = 12
local VIEW_DISTANCE = 300
local UP = Vector3.yAxis

-- The fish's parts are visual only (no collision, massless). One invisible box
-- body carries the mass and collides with the world; the parts are welded to it
-- once the model is in workspace (welds made outside workspace keep stale offsets).
local function build(payload): (Model?, BasePart?, number)
	local model = FishModels.create(payload.FishId, payload)
	if not model then
		return nil, nil, 0
	end
	local bounds = model:GetAttribute("BoundsSize") :: Vector3
	local longest = math.max(bounds.X, bounds.Y, bounds.Z, 0.1)
	local length = math.clamp(
		FishModels.heldLength(if type(payload.Kg) == "number" then payload.Kg else 1, payload.Size, payload.FishId),
		0.8,
		MAX_LENGTH
	)
	model:ScaleTo(length / longest)
	local box, size = model:GetBoundingBox()
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.Massless = true
			item.CanCollide, item.CanQuery, item.CanTouch = false, false, false
			item:SetAttribute("SeasonExempt", true)
		end
	end
	-- Builders draw the fish head toward +X, so the box is length x height x width;
	-- a slim width lets it come to rest on its side like a real fish.
	local body = Instance.new("Part")
	body.Name = "FlingBody"
	body.Size = Vector3.new(size.X * 0.85, math.max(size.Y * 0.7, 0.25), math.max(size.Z * 0.8, 0.2))
	body.CFrame = box
	body.Transparency = 1
	body.Anchored = true
	body.CanCollide, body.CanQuery, body.CanTouch = false, false, false
	body.CustomPhysicalProperties = BODY_PHYSICS
	body.Parent = model
	model.PrimaryPart = body
	return model, body, length
end

-- Where the fish should come down behind the angler.
local function landing(model: Model, target: Vector3): Vector3
	-- Aims for decks and ground, never anyone's head.
	local ignore: { Instance } = { model }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = false
	-- Starts just above head height, so awnings and roofs overhead don't catch it.
	local hit = workspace:Raycast(target + UP * 4, -UP * 40, params)
	local water = Biomes.WaterLevel
	if not hit then
		return Vector3.new(target.X, math.max(target.Y - 3, water), target.Z)
	end
	return Vector3.new(target.X, math.max(hit.Position.Y, water), target.Z)
end

-- Fades every visible part of the fish, including skins added after the fling began.
local function fade(model: Model, originals: { [BasePart]: number }, amount: number)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			local original = originals[item]
			if original == nil then
				original = item.Transparency
				originals[item] = original
			end
			item.Transparency = original + (1 - original) * amount
		end
	end
end

local function between(low: number, high: number): number
	return low + math.random() * (high - low)
end

-- `payload` is CatchService's "Fling" broadcast: the angler's UserId, where the
-- fish was hooked, and the catch's species, weight, size and mutations.
function CatchFling.fling(payload)
	if type(payload) ~= "table" or type(payload.FishId) ~= "string" or type(payload.UserId) ~= "number" then
		return
	end
	local angler = Players:GetPlayerByUserId(payload.UserId)
	local character = angler and angler.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not hrp then
		return
	end
	-- Too far away to see: skip building the model at all.
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - hrp.Position).Magnitude > VIEW_DISTANCE then
		return
	end
	local rod
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("RodId") ~= nil then
			rod = child
			break
		end
	end
	local model, body, length = build(payload)
	if not model or not body then
		warn("[CatchFling] no model for", payload.FishId)
		return
	end

	local facing = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
	facing = if facing.Magnitude > 0.01 then facing.Unit else Vector3.zAxis
	-- Leaps out of the water along the line, at most MAX_LEAP studs out. The rod
	-- tip is the fallback.
	local tip = rod and rod:FindFirstChild("RodTip", true)
	local hooked = if typeof(payload.From) == "Vector3" and (payload.From - hrp.Position).Magnitude < 120
		then payload.From
		else nil
	local start
	if hooked then
		local out = (hooked - hrp.Position) * Vector3.new(1, 0, 1)
		local base = Vector3.new(hrp.Position.X, hooked.Y, hrp.Position.Z)
		start = if out.Magnitude > 0.1 then base + out.Unit * math.min(out.Magnitude, MAX_LEAP) else hooked
	elseif tip and tip:IsA("Attachment") then
		start = tip.WorldPosition
	else
		start = hrp.Position + facing * 3 + UP * 2.5
	end
	-- Thrown on along the line, over the angler and down behind them.
	local flat = (hrp.Position - start) * Vector3.new(1, 0, 1)
	local heading = if flat.Magnitude > 2 then flat.Unit else -facing
	local side = heading:Cross(UP)
	local behind = hrp.Position + heading * between(4.5, 6.5) + side * between(-1.5, 1.5)
	local target = landing(model, behind) + UP * body.Size.Z / 2

	-- Ballistic launch under the game's own gravity. A thrown body passes a
	-- fraction `over` of the way along at height line + g*T^2/2 * over*(1-over),
	-- so pick the air time T that just clears the angler's head; the launch
	-- velocity then follows from the target and T.
	local gravity = workspace.Gravity
	local span = ((target - start) * Vector3.new(1, 0, 1)).Magnitude
	local over = math.clamp(flat.Magnitude / math.max(span, 0.1), 0.15, 0.9)
	local lineY = start.Y + (target.Y - start.Y) * over
	local needed = hrp.Position.Y + HEAD_ABOVE_ROOT + HEAD_CLEARANCE + length / 2 - lineY
	local air = if needed > 0 then math.sqrt(2 * needed / (gravity * over * (1 - over))) else MIN_AIR
	air = math.clamp(air, MIN_AIR, MAX_AIR)
	local velocity = (target - start) / air + UP * (0.5 * gravity * air)
	-- No collisions until it is past the angler, so it can't clip them on the way.
	-- Always on well before touchdown, or it could drop through a thin deck.
	local collideAfter = math.min(over * air + 0.05, air * 0.85)

	-- Head first along the throw, then the parts weld to the body in workspace.
	model:PivotTo(CFrame.fromMatrix(start, heading, UP))
	model.Name = "CatchFling"
	model.Parent = workspace
	for _, item in model:GetDescendants() do
		-- FishMeshes' skins already weld themselves to the body's swatch.
		if item:IsA("BasePart") and item ~= body and item.Name ~= "LoftSkin" then
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = body, item
			weld.Parent = body
		end
	end
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = false
		end
	end
	body.AssemblyLinearVelocity = velocity
	local spin = between(MIN_SPIN, MAX_SPIN) * (if math.random() < 0.5 then -1 else 1)
	body.AssemblyAngularVelocity = side * spin + heading * between(-3, 3)
	print(
		string.format(
			"[CatchFling] %s flung a %s (%.0f studs out, %.2fs air)",
			angler.Name,
			payload.FishId,
			flat.Magnitude,
			air
		)
	)

	local originals = {}
	local began = os.clock()
	local nextFlop = air + between(0.2, 0.4)
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local t = os.clock() - began
		if t >= LIFETIME or not model.Parent or not body.Parent then
			connection:Disconnect()
			model:Destroy()
			return
		end
		if not body.CanCollide and t >= collideAfter then
			body.CanCollide = true
		end
		-- Flops once it has come to rest on something dry: a hop off the ground
		-- with a roll over its back and a kick of the tail, weaker each time.
		local resting = body.AssemblyLinearVelocity.Magnitude < 3
		local dry = body.Position.Y > Biomes.WaterLevel + 0.3
		if t >= nextFlop and resting and dry and t < LIFETIME - 1.2 then
			local energy = math.exp(-(t - air) * 0.3)
			local mass = body.AssemblyMass
			body:ApplyImpulse((UP * between(9, 14) + side * between(-3, 3) + heading * between(-3, 3)) * mass * energy)
			body.AssemblyAngularVelocity = (
				body.CFrame.XVector * between(5, 9) * (if math.random() < 0.5 then -1 else 1) + UP * between(-5, 5)
			) * energy
			nextFlop = t + between(0.3, 0.8)
		end
		local fadeFrom = LIFETIME - FADE_SECONDS
		if t > fadeFrom then
			fade(model, originals, (t - fadeFrom) / FADE_SECONDS)
		end
	end)
end

return CatchFling
