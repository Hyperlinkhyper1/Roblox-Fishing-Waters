-- Preview mussel net placement and animate placed nets' floats. The server
-- checks and saves every drop.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))
local Biomes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Biomes"))
local MusselNets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MusselNets"))

local MusselNetsClient = {}
local TOOL_ATTRIBUTE = "MusselNetTool"
local CAGE_TAG = "MusselNet"
local BASE_TAG = "PlayerBase"
local VALID = Color3.fromRGB(111, 202, 125)
local INVALID = Color3.fromRGB(238, 107, 111)
local BOB_DISTANCE = 160
local started = false

local function openWater(position: Vector3, parameters: RaycastParams): boolean
	local result = workspace:Raycast(
		Vector3.new(position.X, Biomes.WaterLevel + 12, position.Z),
		Vector3.new(0, -24, 0),
		parameters
	)
	return result ~= nil and result.Instance == workspace.Terrain and result.Material == Enum.Material.Water
end

function MusselNetsClient.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("MusselNets")
	local request = remotes:WaitForChild("Request") :: RemoteEvent
	local update = remotes:WaitForChild("Update") :: RemoteEvent
	update.OnClientEvent:Connect(function(kind, message)
		if kind == "Notice" and type(message) == "string" then
			pcall(StarterGui.SetCore, StarterGui, "SendNotification", {
				Title = "Mussel Nets",
				Text = message,
				Duration = 5,
			})
		end
	end)

	local gui = Instance.new("ScreenGui")
	gui.Name = "MusselNetPlacement"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -118)
	hint.Size = UDim2.fromOffset(480, 26)
	hint.BackgroundTransparency = 1
	hint.TextSize = 18
	hint.TextWrapped = true
	Theme.text(hint)
	hint.Parent = gui

	local tool: Tool? = nil
	local ghost: Model? = nil
	local highlight: Highlight? = nil
	local activated: RBXScriptConnection? = nil
	local lastTouch: Vector2? = nil
	local lastSent = -math.huge

	local function myBase(): (Model?, CFrame?)
		for _, base in CollectionService:GetTagged(BASE_TAG) do
			local frame = base:GetAttribute("BoatDockFrame")
			if
				base:GetAttribute("OwnerUserId") == player.UserId
				and base:IsA("Model")
				and typeof(frame) == "CFrame"
			then
				return base, frame
			end
		end
		return nil, nil
	end

	local function pointerRay(camera: Camera): Ray
		local last = UserInputService:GetLastInputType()
		if last == Enum.UserInputType.Touch and lastTouch then
			return camera:ScreenPointToRay(lastTouch.X, lastTouch.Y)
		elseif string.sub(last.Name, 1, 7) == "Gamepad" then
			local size = camera.ViewportSize
			return camera:ViewportPointToRay(size.X / 2, size.Y / 2)
		end
		local mouse = UserInputService:GetMouseLocation()
		return camera:ViewportPointToRay(mouse.X, mouse.Y)
	end

	-- Where the pointer would drop the cage: the world spot, the cage's frame, and
	-- why it can't go there (nil when it can). Mirrors MusselNetService.place.
	local function evaluate(): (Vector3?, CFrame?, string?)
		local camera = workspace.CurrentCamera
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not camera or not tool or not root or not root:IsA("BasePart") then
			return nil, nil, nil
		end
		local base, dock = myBase()
		if not base or not dock then
			return nil, nil, "You need a dock of your own to set mussel nets."
		end
		local ignore: { Instance } = { ghost :: Instance }
		for _, other in Players:GetPlayers() do
			if other.Character then
				table.insert(ignore, other.Character)
			end
		end
		local parameters = RaycastParams.new()
		parameters.FilterType = Enum.RaycastFilterType.Exclude
		parameters.FilterDescendantsInstances = ignore
		parameters.IgnoreWater = false
		local ray = pointerRay(camera)
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 400, parameters)
		if not hit or hit.Instance ~= workspace.Terrain or hit.Material ~= Enum.Material.Water then
			return nil, nil, "Point at the water by your dock."
		end
		local spot = dock:PointToObjectSpace(hit.Position)
		local x, z = MusselNets.round(spot.X), MusselNets.round(spot.Z)
		local position = dock * Vector3.new(x, 0, z)
		local waterline = tool:GetAttribute("Waterline")
		local size = tool:GetAttribute("CageSize")
		if type(waterline) ~= "number" or typeof(size) ~= "Vector3" then
			return nil, nil, nil
		end
		local frame = CFrame.new(position.X, Biomes.WaterLevel - waterline, position.Z) * dock.Rotation
		local placed = {}
		local folder = base:FindFirstChild("MusselNets")
		for _, model in if folder then folder:GetChildren() else {} do
			local cx, cz = model:GetAttribute("X"), model:GetAttribute("Z")
			if type(cx) == "number" and type(cz) == "number" then
				table.insert(placed, { X = cx, Z = cz })
			end
		end
		-- The hotbar cage only exists while one is in stock.
		local otherPlaced = {}
		local otherFolder = base:FindFirstChild("CrabCages")
		for _, model in if otherFolder then otherFolder:GetChildren() else {} do
			local cx, cz = model:GetAttribute("X"), model:GetAttribute("Z")
			if type(cx) == "number" and type(cz) == "number" then
				table.insert(otherPlaced, { X = cx, Z = cz })
			end
		end
		local problem = MusselNets.placeProblem(
			{ MusselNets = { Stock = 1, Placed = placed }, CrabCages = { Placed = otherPlaced } },
			x,
			z
		)
		local reach = hit.Position - root.Position
		if not problem and Vector3.new(reach.X, 0, reach.Z).Magnitude > MusselNets.REACH then
			problem = "That's too far away. Walk to the edge of your pier."
		end
		if not problem then
			for _, point in MusselNets.footprint(size) do
				if not openWater(frame * point, parameters) then
					problem = "Drop it into open water, clear of the piers."
					break
				end
			end
		end
		return position, frame, problem
	end

	local function clearGhost()
		if ghost then
			ghost:Destroy()
		end
		ghost, highlight = nil, nil
	end

	-- A full-size, see-through copy of the held cage.
	local function makeGhost(from: Tool)
		clearGhost()
		local source = from:FindFirstChild("CageModel")
		if not source or not source:IsA("Model") then
			return
		end
		local copy = source:Clone()
		for _, item in copy:GetDescendants() do
			if item:IsA("WeldConstraint") then
				item:Destroy()
			elseif item:IsA("BasePart") then
				item.Anchored, item.Massless = true, false
				item.CanCollide, item.CanQuery, item.CanTouch = false, false, false
				item.CastShadow = false
				item.Transparency = math.max(item.Transparency, 0.35)
			end
		end
		-- Undo the hotbar shrink whether or not the model's scale factor replicated.
		local shrunk = from:GetAttribute("CageScale")
		copy:ScaleTo(copy:GetScale() / (if type(shrunk) == "number" and shrunk > 0 then shrunk else 1))
		copy.Name = "MusselNetGhost"
		local glow = Instance.new("Highlight")
		glow.FillTransparency, glow.OutlineTransparency = 0.6, 0.15
		glow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		glow.Adornee = copy
		glow.Parent = copy
		ghost, highlight = copy, glow
	end

	local function verb(): string
		local last = UserInputService:GetLastInputType()
		return if last == Enum.UserInputType.Touch
			then "Tap"
			elseif string.sub(last.Name, 1, 7) == "Gamepad" then "Aim at"
			else "Click"
	end

	local function unequip()
		if activated then
			activated:Disconnect()
			activated = nil
		end
		tool = nil
		clearGhost()
		gui.Enabled = false
	end

	local function equip(held: Tool)
		unequip()
		tool = held
		makeGhost(held)
		gui.Enabled = true
		activated = held.Activated:Connect(function()
			-- Re-aim now: a tap moves the pointer just before it activates the tool.
			local position, _, problem = evaluate()
			if position and not problem and os.clock() - lastSent > 0.6 then
				lastSent = os.clock()
				request:FireServer("Place", position)
			elseif problem then
				hint.Text, hint.TextColor3 = problem, INVALID
			end
		end)
	end

	local function bindCharacter(character: Model)
		unequip()
		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") and child:GetAttribute(TOOL_ATTRIBUTE) then
				equip(child)
			end
		end)
		character.ChildRemoved:Connect(function(child)
			if child == tool then
				unequip()
			end
		end)
		for _, child in character:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute(TOOL_ATTRIBUTE) then
				equip(child)
			end
		end
	end
	player.CharacterAdded:Connect(bindCharacter)
	if player.Character then
		bindCharacter(player.Character)
	end
	local function trackTouch(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch then
			lastTouch = Vector2.new(input.Position.X, input.Position.Y)
		end
	end
	UserInputService.InputBegan:Connect(trackTouch)
	UserInputService.InputChanged:Connect(trackTouch)

	-- Where each float sat before this client first moved it. Only this client moves
	-- it, so that stays its resting pivot (a streamed-in copy starts a new entry).
	local floatRest: { [Model]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
	-- Each float part's place relative to that pivot, taken when the part arrives
	-- (still where the server put it). Parts are set from these every frame rather
	-- than nudged from last frame's pose, so a part that replicates late or a
	-- rounding error can't knock one out of line with the rest.
	local partRest: { [BasePart]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
	local moved: { BasePart } = {}
	local poses: { CFrame } = {}
	-- Update anchored parts before physics, as with the other floating objects,
	-- instead of moving them during rendering.
	RunService.PreSimulation:Connect(function()
		local camera = workspace.CurrentCamera
		-- A local clock: the synced server clock can step as it corrects itself,
		-- and nothing else needs to agree with a float's phase.
		local now = os.clock()
		table.clear(moved)
		table.clear(poses)
		-- Floats ride a gentle swell, each on its own phase.
		for _, model in CollectionService:GetTagged(CAGE_TAG) do
			local float = model:FindFirstChild("Float")
			if not float or not float:IsA("Model") or not camera then
				continue
			end
			local rest = floatRest[float]
			if not rest then
				rest = float:GetPivot()
				floatRest[float] = rest
			end
			for _, child in float:GetChildren() do
				if child:IsA("BasePart") and not partRest[child] then
					partRest[child] = rest:ToObjectSpace(child.CFrame)
				end
			end
			if (rest.Position - camera.CFrame.Position).Magnitude > BOB_DISTANCE then
				continue
			end
			local phase = rest.X * 0.37 + rest.Z * 0.61
			local lift = math.sin(now * 1.6 + phase) * 0.12
			local tilt = CFrame.Angles(math.sin(now * 1.1 + phase) * 0.07, 0, math.cos(now * 1.3 + phase) * 0.07)
			local pose = CFrame.new(rest.Position + Vector3.new(0, lift, 0)) * tilt * rest.Rotation
			for _, child in float:GetChildren() do
				local offset = if child:IsA("BasePart") then partRest[child] else nil
				if child:IsA("BasePart") and offset then
					table.insert(moved, child)
					table.insert(poses, pose * offset)
				end
			end
		end
		if #moved > 0 then
			workspace:BulkMoveTo(moved, poses, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not tool or not ghost or not highlight then
			return
		end
		if not camera then
			ghost.Parent = nil
			return
		end
		local position, frame, problem = evaluate()
		if frame then
			ghost:PivotTo(frame)
			ghost.Parent = camera
		else
			ghost.Parent = nil
		end
		local ok = position ~= nil and problem == nil
		highlight.FillColor = if ok then VALID else INVALID
		highlight.OutlineColor = if ok then VALID else INVALID
		hint.Text = if ok then verb() .. " the water to drop your mussel net here." else problem or ""
		hint.TextColor3 = if ok then Theme.Colors.Text else INVALID
	end)
end

return MusselNetsClient
