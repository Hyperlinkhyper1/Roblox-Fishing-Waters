-- Thrown shark spears. The server simulates every throw and owns shark health;
-- this module picks the aim point (leading a moving shark), draws the spear's
-- flight for the thrower and for everyone else, and shows shark health.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local SpearSkins = require(Shared.SpearSkins)
local Spears = require(Shared.Spears)
local Biomes = require(Shared.Biomes)
local Weather = require(Shared.Weather)

local SpearCombat = {}
local started = false
-- Snap the aim to a shark whose body passes this close to the cursor ray.
local AIM_ASSIST = 7
local HEALTH_RANGE = Spears.THROW_RANGE + 15
local STUCK_TIME = 1.2

local function waterHeight(position: Vector3): number
	local now = workspace:GetServerTimeNow()
	local ok, height = pcall(Weather.heightAt, position, now, Weather.getState(now, position))
	return Biomes.WaterLevel + (if ok and type(height) == "number" then height else 0)
end

local function splash(position: Vector3)
	local ring = Instance.new("Part")
	ring.Name = "SpearSplash"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored, ring.CanCollide, ring.CanTouch, ring.CanQuery = true, false, false, false
	ring.CastShadow = false
	ring.Material = Enum.Material.SmoothPlastic
	ring.Color = Color3.fromRGB(236, 246, 250)
	ring.Transparency = 0.25
	ring.Size = Vector3.new(0.15, 0.8, 0.8)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = workspace
	local info = TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(ring, info, { Size = Vector3.new(0.15, 4.5, 4.5), Transparency = 1 }):Play()
	task.delay(0.6, function()
		ring:Destroy()
	end)
end

-- What a throw passes through: the thrower and, like the server, the boat they stand on.
local function throwerIgnore(character: Model?): { Instance }
	local ignore = {}
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not root:IsA("BasePart") then
		return ignore
	end
	table.insert(ignore, character)
	local boats = workspace:FindFirstChild("PlayerBoats")
	if boats then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		local floor = workspace:Raycast(root.Position, Vector3.new(0, -10, 0), params)
		local boat = floor and floor.Instance
		if boat and boat:IsDescendantOf(boats) then
			while boat.Parent and boat.Parent ~= boats do
				boat = boat.Parent
			end
			table.insert(ignore, boat)
		end
	end
	return ignore
end

-- A loose, anchored copy of the spear tool's visible parts, pivoted from its handle.
local function spearModel(skinId: string?, wear: number?): Model
	local tool = Spears.build(if SpearSkins.valid(skinId) then skinId else nil, wear)
	local model = Instance.new("Model")
	model.Name = "ThrownSpear"
	for _, child in tool:GetChildren() do
		if child:IsA("BasePart") then
			child.Anchored = true
			child.Parent = model
		end
	end
	model.PrimaryPart = model:FindFirstChild("Handle") :: BasePart
	tool:Destroy()
	return model
end

local function fadeOut(model: Model, seconds: number)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 then
			TweenService:Create(part, TweenInfo.new(seconds), { Transparency = 1 }):Play()
		end
	end
	task.delay(seconds, function()
		model:Destroy()
	end)
end

-- Spearhead (+Y on the tool) along the direction of travel.
local function along(position: Vector3, velocity: Vector3): CFrame
	if velocity.Magnitude < 1e-3 then
		return CFrame.new(position)
	end
	return CFrame.lookAt(position, position + velocity) * CFrame.Angles(-math.pi / 2, 0, 0)
end

-- Draw a throw on the same arc the server simulates. It sticks into the first
-- shark or surface it meets, splashes into the sea and fades away.
local function fly(origin: Vector3, velocity: Vector3, skinId: string?, wear: number?, ignore: { Instance })
	local model = spearModel(skinId, wear)
	model:PivotTo(along(origin, velocity))
	model.Parent = workspace
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local excluded = table.clone(ignore)
	table.insert(excluded, model)
	local sharks = workspace:FindFirstChild("Sharks")
	if sharks then
		table.insert(excluded, sharks)
	end
	params.FilterDescendantsInstances = excluded
	params.IgnoreWater = true
	local age, previous, wet = 0, origin, false
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		age = math.min(age + dt, Spears.THROW_LIFETIME)
		local position, speed = Spears.throwAt(origin, velocity, age)
		local path = position - previous
		local stuckTo: BasePart? = nil
		local stopAt: Vector3? = nil
		if path.Magnitude > 1e-4 then
			local bestAlong
			if sharks then
				for _, shark in sharks:GetChildren() do
					local root = if shark:IsA("Model") then shark.PrimaryPart else nil
					if root then
						local hit = Spears.sharkHit(previous, position, root.Position, root.CFrame.LookVector)
						if hit and (not bestAlong or hit < bestAlong) then
							bestAlong, stuckTo = hit, root
						end
					end
				end
			end
			local obstruction = workspace:Raycast(previous, path, params)
			local blockedAt = obstruction and (obstruction.Position - previous).Magnitude / path.Magnitude
			if stuckTo and not (blockedAt and blockedAt < bestAlong) then
				stopAt = previous + path * bestAlong
			elseif obstruction then
				stuckTo, stopAt = nil, obstruction.Position
			end
			if not wet then
				local surface = waterHeight(position)
				if position.Y < surface then
					wet = true
					splash(Vector3.new(position.X, surface, position.Z))
				end
			end
		end
		previous = position
		if stopAt then
			connection:Disconnect()
			-- Bury the head a little so it reads as stuck in, not resting on.
			local frame = along(stopAt + path.Unit * 1.2, speed)
			model:PivotTo(frame)
			if stuckTo then
				local offset = stuckTo.CFrame:ToObjectSpace(frame)
				local follow
				follow = RunService.RenderStepped:Connect(function()
					if model.Parent and stuckTo.Parent then
						model:PivotTo(stuckTo.CFrame * offset)
					else
						follow:Disconnect()
					end
				end)
				task.delay(STUCK_TIME + 0.4, function()
					follow:Disconnect()
				end)
			end
			task.delay(STUCK_TIME, fadeOut, model, 0.4)
			return
		end
		model:PivotTo(along(position, speed))
		if age >= Spears.THROW_LIFETIME or position.Y < Biomes.WaterLevel - Spears.THROW_DEPTH then
			connection:Disconnect()
			fadeOut(model, 0.25)
		end
	end)
end

function SpearCombat.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local attack = ReplicatedStorage:WaitForChild("SpearAttack") :: RemoteEvent
	local lastTouch: Vector2? = nil
	local lastTouchAt = 0
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.Touch then
			lastTouch = Vector2.new(input.Position.X, input.Position.Y)
			lastTouchAt = os.clock()
		end
	end)

	local gui = Instance.new("ScreenGui")
	gui.Name = "SpearHint"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local hint = Instance.new("TextLabel")
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -96)
	hint.Size = UDim2.fromOffset(360, 34)
	hint.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
	hint.BackgroundTransparency = 0.25
	hint.BorderSizePixel = 0
	hint.Font = Enum.Font.GothamMedium
	hint.TextSize = 14
	hint.TextColor3 = Color3.fromRGB(240, 240, 236)
	hint.Text = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		then "Tap a shark to throw your spear"
		else "Aim at a shark and click to throw your spear"
	hint.Visible = false
	hint.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = hint

	local active: Tool? = nil
	-- Smoothed shark velocities, so throws lead a swimming shark.
	local motion = {}
	RunService.Heartbeat:Connect(function(dt)
		local sharks = workspace:FindFirstChild("Sharks")
		if not active or not sharks or dt <= 0 then
			table.clear(motion)
			return
		end
		local seen = {}
		for _, shark in sharks:GetChildren() do
			local part = if shark:IsA("Model") then shark.PrimaryPart else nil
			if part then
				seen[shark] = true
				local entry = motion[shark]
				local position = part.Position
				if not entry then
					motion[shark] = { position = position, velocity = Vector3.zero }
				else
					local sample = (position - entry.position) / dt
					-- The root replicates in steps; ignore resyncs and streaming jumps.
					if sample.Magnitude < 150 then
						local alpha = 1 - math.exp(-4 * dt)
						entry.velocity = entry.velocity:Lerp(Vector3.new(sample.X, 0, sample.Z), alpha)
					end
					entry.position = position
				end
			end
		end
		for model in motion do
			if not seen[model] then
				motion[model] = nil
			end
		end
	end)

	local function aimPoint(origin: Vector3): Vector3?
		local camera = workspace.CurrentCamera
		if not camera then
			return nil
		end
		local screen = if lastTouch and os.clock() - lastTouchAt < 0.5
			then lastTouch
			else UserInputService:GetMouseLocation()
		local ray = camera:ScreenPointToRay(screen.X, screen.Y)
		local chosen, closest = nil, math.huge
		local sharks = workspace:FindFirstChild("Sharks")
		if sharks then
			for _, shark in sharks:GetChildren() do
				local part = if shark:IsA("Model") then shark.PrimaryPart else nil
				if part then
					local point = part.Position + Vector3.new(0, -Spears.SHARK_DEPTH, 0)
					local offset = point - ray.Origin
					local depth = offset:Dot(ray.Direction)
					local miss = (offset - ray.Direction * depth).Magnitude
					if
						depth > 0
						and miss <= AIM_ASSIST
						and (point - origin).Magnitude <= Spears.THROW_RANGE + 5
						and miss < closest
					then
						chosen, closest = shark, miss
					end
				end
			end
		end
		if chosen then
			-- Lead by flight time plus latency: the server sees the shark further on.
			local center = chosen.PrimaryPart.Position + Vector3.new(0, -Spears.SHARK_DEPTH, 0)
			local velocity = if motion[chosen] then motion[chosen].velocity else Vector3.zero
			local ok, ping = pcall(player.GetNetworkPing, player)
			local delay = if ok and type(ping) == "number" then math.clamp(ping, 0, 0.5) else 0.1
			local target = center
			for _ = 1, 3 do
				target = center + velocity * ((target - origin).Magnitude / Spears.THROW_SPEED + delay)
			end
			return target
		end
		-- No shark under the cursor: throw at whatever the cursor points to.
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character :: Instance }
		params.IgnoreWater = false
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
		return if hit then hit.Position else ray.Origin + ray.Direction * 500
	end

	-- Other players' throws, drawn on the arc the server is simulating.
	task.spawn(function()
		local thrown = ReplicatedStorage:WaitForChild("SpearThrown") :: RemoteEvent
		thrown.OnClientEvent:Connect(function(thrower, origin, velocity, skinId, wear)
			if thrower == player or typeof(origin) ~= "Vector3" or typeof(velocity) ~= "Vector3" then
				return
			end
			local character = if typeof(thrower) == "Instance" and thrower:IsA("Player") then thrower.Character else nil
			fly(origin, velocity, skinId, if type(wear) == "number" then wear else nil, throwerIgnore(character))
		end)
	end)

	-- Rewards can arrive after the spear has been put away.
	task.spawn(function()
		local loot = ReplicatedStorage:WaitForChild("SharkLoot") :: RemoteEvent
		local notice = Instance.new("TextLabel")
		notice.Name = "SharkLootNotice"
		notice.AnchorPoint = Vector2.new(0.5, 1)
		notice.Position = UDim2.new(0.5, 0, 1, -145)
		notice.Size = UDim2.new(0.85, 0, 0, 80)
		notice.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
		notice.BackgroundTransparency = 0.15
		notice.BorderSizePixel = 0
		notice.Font = Enum.Font.GothamMedium
		notice.TextSize = 15
		notice.TextWrapped = true
		notice.TextColor3 = Color3.fromRGB(240, 240, 236)
		notice.Visible = false
		notice.Parent = gui
		local limit = Instance.new("UISizeConstraint")
		limit.MaxSize = Vector2.new(560, 80)
		limit.Parent = notice
		local noticeCorner = Instance.new("UICorner")
		noticeCorner.CornerRadius = UDim.new(0, 6)
		noticeCorner.Parent = notice
		local noticeId = 0
		loot.OnClientEvent:Connect(function(drops, saved, overflow)
			local names = {}
			if type(drops) == "table" then
				for _, drop in drops do
					if type(drop) == "table" and type(drop.Name) == "string" then
						table.insert(names, drop.Name)
					end
				end
			end
			noticeId += 1
			local current = noticeId
			if saved == false then
				notice.Text = "Your shark rewards could not be granted. Please try again."
			else
				notice.Text = "Shark rewards: "
					.. table.concat(names, ", ")
					.. (
						if overflow
							then "\nOverflow was saved in storage. Place a storage rack to collect it if needed."
							else ""
					)
			end
			notice.Visible = true
			task.delay(7, function()
				if noticeId == current then
					notice.Visible = false
				end
			end)
		end)
	end)

	local connections = {}
	local lastAttack = 0
	local throwId = 0
	-- Replicated health gives attackers feedback even when several people hit
	-- the same shark. The server remains authoritative over every hit.
	task.spawn(function()
		local bars = {}
		while gui.Parent do
			local seen = {}
			local sharks = workspace:FindFirstChild("Sharks")
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if active and sharks and root and root:IsA("BasePart") then
				for _, shark in sharks:GetChildren() do
					local part = if shark:IsA("Model") then shark.PrimaryPart else nil
					local health, maximum = shark:GetAttribute("Health"), shark:GetAttribute("MaxHealth")
					if
						part
						and type(health) == "number"
						and type(maximum) == "number"
						and maximum > 0
						and (part.Position - root.Position).Magnitude <= HEALTH_RANGE
					then
						local bar = bars[shark]
						if not bar then
							bar = Instance.new("BillboardGui")
							bar.Name = "SharkHealth"
							bar.Adornee = part
							bar.Size = UDim2.fromOffset(120, 26)
							bar.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
							bar.AlwaysOnTop = true
							local label = Instance.new("TextLabel")
							label.Name = "Label"
							label.Size = UDim2.fromScale(1, 1)
							label.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
							label.BackgroundTransparency = 0.25
							label.BorderSizePixel = 0
							label.Font = Enum.Font.GothamBold
							label.TextColor3 = Color3.fromRGB(240, 240, 236)
							label.TextSize = 13
							label.Parent = bar
							bar.Parent = gui
							bars[shark] = bar
						end
						bar.Label.Text = string.format("SHARK  %.1f / %d", math.max(0, health), maximum)
						seen[shark] = true
					end
				end
			end
			for shark, bar in bars do
				if not seen[shark] then
					bar:Destroy()
					bars[shark] = nil
				end
			end
			task.wait(0.15)
		end
	end)

	-- The held spear vanishes while one is in flight and is drawn again after the cooldown.
	local function showHeld(tool: Tool, visible: boolean)
		for _, part in tool:GetDescendants() do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = if visible then 0 else 1
			end
		end
	end
	local function unbind()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		if active then
			showHeld(active, true)
		end
		active = nil
		hint.Visible = false
	end
	local function bind(tool: Tool)
		if active == tool then
			return
		end
		unbind()
		active = tool
		hint.Visible = true
		local grip = tool.Grip
		table.insert(
			connections,
			tool.Activated:Connect(function()
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if
					tool.Parent ~= character
					or player:GetAttribute("PlayerMenuOpen")
					or not root
					or not root:IsA("BasePart")
				then
					return
				end
				local now = os.clock()
				local boosts = SpearSkins.boosts(player:GetAttribute("SpearSkin"), player:GetAttribute("SpearSkinWear"))
				local cooldown = Spears.THROW_COOLDOWN / (1 + boosts.fireRate)
				if now - lastAttack < cooldown then
					return
				end
				local origin = root.Position + Vector3.new(0, Spears.THROW_HEIGHT, 0)
				local point = aimPoint(origin)
				local velocity = point and Spears.throwVelocity(origin, point)
				if not point or not velocity then
					return
				end
				lastAttack = now
				attack:FireServer(point)
				fly(origin, velocity, tool:GetAttribute("SpearSkin"), tool:GetAttribute("SpearSkinWear"), throwerIgnore(character))
				throwId += 1
				local current = throwId
				showHeld(tool, false)
				task.delay(cooldown * 0.85, function()
					if throwId ~= current or active ~= tool then
						return
					end
					showHeld(tool, true)
					tool.Grip = grip * CFrame.new(0, 1.2, 0)
					TweenService:Create(tool, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Grip = grip,
					}):Play()
				end)
			end)
		)
		table.insert(connections, tool.Unequipped:Connect(unbind))
		table.insert(
			connections,
			tool.AncestryChanged:Connect(function()
				if tool.Parent ~= player.Character then
					unbind()
				end
			end)
		)
	end
	local function watchCharacter(character: Model)
		unbind()
		local function inspect(child: Instance)
			if child:IsA("Tool") and child:GetAttribute("SpearId") == "BasicSpear" then
				bind(child)
			end
		end
		character.ChildAdded:Connect(inspect)
		for _, child in character:GetChildren() do
			inspect(child)
		end
	end
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end
end

return SpearCombat
