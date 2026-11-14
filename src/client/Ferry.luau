-- Persistent destination and a compass arrow for an active passenger crossing.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Ferry = {}

function Ferry.start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn = "FerryRoute", false
	gui.Parent = player:WaitForChild("PlayerGui")
	local panel = Instance.new("Frame")
	panel.Name = "Route"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 22)
	panel.Size = UDim2.fromOffset(310, 60)
	panel.BackgroundColor3 = Color3.fromRGB(20, 39, 50)
	panel.BackgroundTransparency = 0.15
	panel.Visible = false
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius, corner.Parent = UDim.new(0, 8), panel
	local arrow = Instance.new("TextLabel")
	arrow.Name, arrow.BackgroundTransparency = "Arrow", 1
	arrow.Position, arrow.Size = UDim2.fromOffset(7, 8), UDim2.fromOffset(42, 42)
	arrow.Text, arrow.TextSize, arrow.Font = "▲", 28, Enum.Font.GothamBold
	arrow.TextColor3, arrow.Parent = Color3.fromRGB(255, 218, 132), panel
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position, title.Size = UDim2.fromOffset(53, 5), UDim2.new(1, -58, 1, -10)
	title.TextXAlignment, title.TextYAlignment = Enum.TextXAlignment.Left, Enum.TextYAlignment.Center
	title.TextColor3, title.Font, title.TextSize = Color3.new(1, 1, 1), Enum.Font.GothamMedium, 14
	title.TextWrapped, title.Parent = true, panel
	local last = 0
	RunService.RenderStepped:Connect(function()
		if os.clock() - last < 0.15 then return end
		last = os.clock()
		local destination = player:GetAttribute("FerryDestination")
		local target = player:GetAttribute("FerryDestinationPosition")
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local camera = workspace.CurrentCamera
		panel.Visible = type(destination) == "string" and typeof(target) == "Vector3" and root ~= nil and camera ~= nil
		if not panel.Visible then return end
		local delta = target - root.Position
		local flat = Vector3.new(delta.X, 0, delta.Z)
		local relative = camera.CFrame:VectorToObjectSpace(flat)
		arrow.Rotation = math.deg(math.atan2(relative.X, -relative.Z))
		title.Text = string.format("FERRY · %s dock\n%d studs · deliver 4 passengers", if destination == "Main" then "Main Island" else "City", math.floor(flat.Magnitude))
	end)
end
return Ferry
