local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))
local Service = {}
local started = false

function Service.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "ServerUpdateNotice"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1100
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 12)
	panel.Size = UDim2.new(1, -24, 0, 154)
	panel.Parent = gui
	Theme.panel(panel)
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(540, 154)
	constraint.Parent = panel
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(14, 8)
	title.Size = UDim2.new(1, -28, 0, 26)
	title.TextSize = 20
	Theme.text(title)
	title.Parent = panel
	local description = Instance.new("TextLabel")
	description.BackgroundTransparency = 1
	description.Position = UDim2.fromOffset(14, 38)
	description.Size = UDim2.new(1, -28, 0, 56)
	description.TextSize = 14
	description.TextWrapped = true
	Theme.text(description, Theme.Colors.Muted)
	description.Parent = panel
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, -10)
	button.Size = UDim2.new(1, -28, 0, 38)
	button.TextSize = 16
	Theme.text(button)
	Theme.button(button, "Selected")
	button.Parent = panel
	button.Activated:Connect(function()
		local remote = ReplicatedStorage:FindFirstChild("JoinUpdatedServer")
		if remote and not player:GetAttribute("FishingWatersUpdateStatus") then
			remote:FireServer()
		end
	end)
	local function refresh()
		local status = player:GetAttribute("FishingWatersUpdateStatus")
		gui.Enabled = ReplicatedStorage:GetAttribute("FishingWatersUpdateAvailable") == true or status ~= nil
		local maintenance = ReplicatedStorage:GetAttribute("FishingWatersRestartKind") == "Maintenance"
		title.Text = if maintenance then "Server restarting" else "Update available!"
		description.Text = if status
			then "Taking you to a fresh server. If Roblox is busy, we'll keep trying automatically."
			else "This server is running an older version. Join a newer server to play the latest update."
		local restart = ReplicatedStorage:GetAttribute("FishingWatersRestartAt") or 0
		if not status and restart > 0 then
			description.Text = "This server is restarting soon. You can move to a fresh server now."
		end
		button.Text = if status == "Retrying"
			then "Connection failed — retrying…"
			elseif status then "Joining fresh server…"
			else "Join updated server"
		button.Active = status == nil
		button.AutoButtonColor = status == nil
	end
	for _, attribute in { "FishingWatersUpdateAvailable", "FishingWatersRestartAt", "FishingWatersRestartKind" } do
		ReplicatedStorage:GetAttributeChangedSignal(attribute):Connect(refresh)
	end
	player:GetAttributeChangedSignal("FishingWatersUpdateStatus"):Connect(refresh)
	refresh()
end

return Service
