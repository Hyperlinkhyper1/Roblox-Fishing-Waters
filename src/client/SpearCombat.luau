-- The server owns shark health and validates every strike. This module supplies
-- an aim point and immediate local feedback for the equipped spear.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SpearSkins = require(ReplicatedStorage:WaitForChild("Shared").SpearSkins)

local SpearCombat = {}
local started = false
local COOLDOWN = 0.6

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
	hint.Size = UDim2.fromOffset(340, 34)
	hint.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
	hint.BackgroundTransparency = 0.25
	hint.BorderSizePixel = 0
	hint.Font = Enum.Font.GothamMedium
	hint.TextSize = 14
	hint.TextColor3 = Color3.fromRGB(240, 240, 236)
	hint.Text = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		then "Tap a nearby shark to strike"
		else "Aim at a nearby shark and click to strike"
	hint.Visible = false
	hint.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = hint

	local function aimPoint(): Vector3?
		local camera = workspace.CurrentCamera
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not camera or not root or not root:IsA("BasePart") then
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
					local point = part.Position + Vector3.new(0, -1.3, 0)
					local offset = point - ray.Origin
					local along = offset:Dot(ray.Direction)
					local miss = (offset - ray.Direction * along).Magnitude
					if along > 0 and miss <= 5.5 and (point - root.Position).Magnitude <= 30 and miss < closest then
						chosen, closest = point, miss
					end
				end
			end
		end
		return chosen or ray.Origin + ray.Direction * 1000
	end

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

	local active: Tool? = nil
	local connections = {}
	local lastAttack = 0
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
						and (part.Position - root.Position).Magnitude <= 35
					then
						local bar = bars[shark]
						if not bar then
							bar = Instance.new("BillboardGui")
							bar.Name = "SharkHealth"
							bar.Adornee = part
							bar.Size = UDim2.fromOffset(120, 26)
							bar.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
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
	local function unbind()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
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
		table.insert(
			connections,
			tool.Activated:Connect(function()
				if tool.Parent ~= player.Character or player:GetAttribute("PlayerMenuOpen") then
					return
				end
				local now = os.clock()
				local boosts = SpearSkins.boosts(player:GetAttribute("SpearSkin"), player:GetAttribute("SpearSkinWear"))
				if now - lastAttack < COOLDOWN / (1 + boosts.fireRate) then
					return
				end
				local point = aimPoint()
				if not point then
					return
				end
				lastAttack = now
				attack:FireServer(point)
				local grip = tool.Grip
				local thrust =
					TweenService:Create(tool, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Grip = grip * CFrame.new(0, 0, -1),
					})
				thrust:Play()
				task.delay(0.12, function()
					if tool.Parent then
						TweenService:Create(tool, TweenInfo.new(0.2), { Grip = grip }):Play()
					end
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
