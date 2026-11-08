-- Shows the health of the boat the local player is riding or standing on.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Aboard = require(game:GetService("ReplicatedStorage").Shared.Aboard)

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

local BoatHealth = {}
local started = false

local function round(parent: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

function BoatHealth.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "BoatHealthHud"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "BoatHealth"
	panel.AnchorPoint = Vector2.new(1, 1)
	-- Keep clear of the map and cargo buttons along the right edge.
	panel.Position = UDim2.new(1, -142, 1, -24)
	panel.Size = UDim2.fromOffset(220, 58)
	panel.BackgroundColor3 = Color3.fromRGB(26, 23, 20)
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	round(panel, 4)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(150, 118, 72)
	stroke.Thickness = 2
	stroke.Parent = panel

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 25)
	header.BackgroundColor3 = Color3.fromRGB(92, 36, 34)
	header.BorderSizePixel = 0
	header.Parent = panel
	round(header, 4)

	local caption = Instance.new("TextLabel")
	caption.Name = "Caption"
	caption.BackgroundTransparency = 1
	caption.Position = UDim2.fromOffset(12, 5)
	caption.Size = UDim2.new(1, -24, 0, 20)
	caption.Font = Enum.Font.GothamBold
	caption.Text = "SHIP HEALTH"
	caption.TextSize = 12
	caption.TextColor3 = Color3.fromRGB(240, 240, 236)
	caption.TextXAlignment = Enum.TextXAlignment.Left
	caption.Parent = header

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.fromOffset(12, 29)
	track.Size = UDim2.new(1, -24, 0, 17)
	track.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	track.Parent = panel
	round(track, 4)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(84, 192, 92)
	fill.BorderSizePixel = 0
	fill.Parent = track
	round(fill, 4)
	local remaining = Instance.new("TextLabel")
	remaining.Name = "Remaining"
	remaining.BackgroundTransparency = 1
	remaining.Size = UDim2.fromScale(1, 1)
	remaining.Font = Enum.Font.GothamBold
	remaining.TextSize = 11
	remaining.TextColor3 = Color3.new(1, 1, 1)
	remaining.TextStrokeTransparency = 0.5
	remaining.ZIndex = 2
	remaining.Parent = track

	local currentBoat: Model? = nil
	local connections = {}
	local fillTween: Tween? = nil
	local function refresh()
		if not currentBoat then
			panel.Visible = false
			return
		end
		local health = currentBoat:GetAttribute("Health")
		local maximum = currentBoat:GetAttribute("MaxHealth")
		if typeof(health) ~= "number" or typeof(maximum) ~= "number" or maximum <= 0 then
			panel.Visible = false
			return
		end
		local ratio = math.clamp(health / maximum, 0, 1)
		panel.Visible = true
		remaining.Text = string.format("%d / %d", math.ceil(math.max(0, health)), math.ceil(maximum))
		if fillTween then
			fillTween:Cancel()
		end
		fillTween = TweenService:Create(fill, TweenInfo.new(0.2), {
			Size = UDim2.fromScale(ratio, 1),
			BackgroundColor3 = if ratio <= 0.25
				then Color3.fromRGB(226, 72, 60)
				elseif ratio <= 0.5 then Color3.fromRGB(236, 174, 65)
				else Color3.fromRGB(84, 192, 92),
		})
		fillTween:Play()
	end
	local function setBoat(boat: Model?)
		if currentBoat == boat then
			return
		end
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		currentBoat = boat
		if boat then
			for _, attribute in { "Health", "MaxHealth" } do
				table.insert(connections, boat:GetAttributeChangedSignal(attribute):Connect(refresh))
			end
		end
		refresh()
	end

	local elapsed = 0
	local lastFound = 0
	RunService.Heartbeat:Connect(profiled("BoatHealth", function(dt)
		elapsed += dt
		if elapsed < 0.2 then
			return
		end
		elapsed = 0
		local boats = workspace:FindFirstChild("PlayerBoats")
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not boats or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
			setBoat(nil)
			return
		end
		local boat: Model? = nil
		-- Prefer the occupied seat if boats overlap, then use the same deck
		-- detection as cargo and refit.
		local seat = humanoid.SeatPart
		if seat then
			for _, candidate in boats:GetChildren() do
				if candidate:IsA("Model") and seat:IsDescendantOf(candidate) then
					boat = candidate
					break
				end
			end
		end
		if not boat then
			for _, candidate in boats:GetChildren() do
				if candidate:IsA("Model") and Aboard(character, candidate) then
					boat = candidate
					break
				end
			end
		end
		if boat then
			lastFound = os.clock()
			setBoat(boat)
		elseif not currentBoat or not currentBoat:IsDescendantOf(boats) or os.clock() - lastFound > 0.6 then
			setBoat(nil)
		end
	end))
end

return BoatHealth
