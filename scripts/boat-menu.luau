-- Extend the existing menu mocks with viewport geometry and pointer input.
local function typeof(value)
	return if type(value) == "table" and value.ClassName then "Instance" else type(value)
end
local Font = {
	new = function(family)
		return { Family = family }
	end,
}
Vector2.zero = Vector2.new(0, 0)
vectorMeta.__add = function(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
vectorMeta.__sub = function(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
vectorMeta.__mul = function(a, b)
	return Vector3.new(a.X * b, a.Y * b, a.Z * b)
end
vectorMeta.__index = function(a, key)
	if key == "Magnitude" then
		return math.sqrt(a.X * a.X + a.Y * a.Y + a.Z * a.Z)
	end
	if key == "Unit" then
		return a * (1 / a.Magnitude)
	end
	return nil
end
Vector3.zero = Vector3.new(0, 0, 0)
local originalNew = Instance.new
Instance.new = function(kind)
	local item = originalNew(kind)
	item.InputBegan = signal()
	item.DescendantRemoving = signal()
	return item
end
function methods:FindFirstChildOfClass(class)
	for _, child in self:GetChildren() do
		if child:IsA(class) then
			return child
		end
	end
	return nil
end
function methods:GetBoundingBox()
	return CFrame.new(), if self.Name == "FishingBoat" then Vector3.new(10, 12, 24) else Vector3.new(8, 4, 17)
end
UserInputService.InputChanged, UserInputService.InputEnded = signal(), signal()
local heartbeat = signal()
services.RunService = { Heartbeat = heartbeat }
services.TextChatService = Instance.new("TextChatService")
local base = Instance.new("Model")
base:SetAttribute("OwnerUserId", player.UserId)
base.Parent = workspace
local promptPart = Instance.new("Part")
promptPart.Parent, promptPart.Position = base, Vector3.zero
local prompt = Instance.new("ProximityPrompt")
prompt.Name, prompt.Parent, prompt.MaxActivationDistance = "SpawnRowboatPrompt", promptPart, 10
services.CollectionService = {
	GetTagged = function(_, tag)
		return if tag == "PlayerBase" then { base } else {}
	end,
	GetInstanceAddedSignal = function()
		return signal()
	end,
	GetInstanceRemovedSignal = function()
		return signal()
	end,
}
workspace.CurrentCamera = { ViewportSize = Vector2.new(1440, 900) }
local character = Instance.new("Model")
local root = Instance.new("Part")
root.Name, root.Position, root.Parent = "HumanoidRootPart", Vector3.zero, character
player.Character = character
local remotes = Instance.new("Folder")
remotes.Name, remotes.Parent = "Boating", ReplicatedStorage
local request, feedback = Instance.new("RemoteEvent"), Instance.new("RemoteEvent")
request.Name, request.Parent = "Request", remotes
feedback.Name, feedback.Parent, feedback.OnClientEvent = "Feedback", remotes, signal()
local requests = {}
function request:FireServer(action, id)
	table.insert(requests, { action, id })
end
local Theme = (function()
	-- THEME_SOURCE --
end)()
local BoatCatalog = (function()
	-- CATALOG_SOURCE --
end)()
local BoatPreview = (function()
	-- PREVIEW_SOURCE --
end)()
local cameraStops = 0
local DrydockCamera = {
	stop = function()
		cameraStops += 1
	end,
	show = function() end,
}
local Boating = (function()
	-- CLIENT_SOURCE --
end)()
player:SetAttribute("OwnsRowboat", true)
player:SetAttribute("OwnsFishingBoat", true)
Boating.start()
local gui = playerGui:FindFirstChild("Boating")
local overlay = gui:FindFirstChild("ShopOverlay")
local card = overlay:FindFirstChild("DrydockShop")
local dock = card:FindFirstChild("DockBoatChooser")
local view = dock:FindFirstChild("SelectedBoatModel", true)
local world = view:FindFirstChildOfClass("WorldModel")
local launch = dock:FindFirstChild("LaunchSelectedBoat")
local rowboat = dock:FindFirstChild("LaunchRowboat", true)
local fisher = dock:FindFirstChild("LaunchFishingBoat", true)
local speedboat = dock:FindFirstChild("LaunchSpeedboat", true)
local patrol = dock:FindFirstChild("LaunchPatrolBoat", true)
local racing = dock:FindFirstChild("LaunchRacingSpeedboat", true)
check(not overlay.Visible and #world:GetChildren() == 0, "Closed menu starts without rendering a boat")
feedback.OnClientEvent:Fire("OpenDock", base)
check(overlay.Visible and dock.Visible and launch.Active, "Own dock opens the fleet and enables launch")
check(card.Size.X.Offset == 800 and card.Size.Y.Offset == 560, "Desktop uses the wide preview layout")
check(#world:GetChildren() == 0, "Missing replicated templates do not crash or spawn world boats")
local templates = Instance.new("Folder")
templates.Name, templates.Parent = "Previews", remotes
local function addBoat(id)
	local model = Instance.new("Model")
	model.Name = id
	Instance.new("Part").Parent = model
	model.Parent = templates
	return model
end
local rowTemplate = addBoat("Rowboat")
local fishTemplate = addBoat("FishingBoat")
addBoat("RacingSpeedboat")
local patrolTemplate = addBoat("PatrolBoat")
local speedTemplate = addBoat("Speedboat")
check(#world:GetChildren() == 1 and world:FindFirstChild("Rowboat"), "Late replication fills the selected preview")
check(world:FindFirstChild("Rowboat") ~= rowTemplate, "Preview clones the template without moving it")
local firstModel = world:GetChildren()[1]
player:SetAttribute("Cash", 800)
check(world:GetChildren()[1] == firstModel, "Unrelated wallet refreshes do not rebuild the preview")
fisher.Activated:Fire()
check(#world:GetChildren() == 1 and world:FindFirstChild("FishingBoat"), "Boat selection replaces the visible model")
check(#requests == 0 and fishTemplate.Parent == templates, "Browsing is local and preserves the source model")
local initialCamera = view.CurrentCamera.CFrame
heartbeat:Fire(0.1)
check(view.CurrentCamera.CFrame == initialCamera, "Initial view pauses before automatic rotation")
for _ = 1, 35 do
	heartbeat:Fire(0.1)
end
check(view.CurrentCamera.CFrame ~= initialCamera, "Idle preview rotates while open")
local mouse = { UserInputType = Enum.UserInputType.MouseButton1, Position = { X = 100 } }
view.InputBegan:Fire(mouse)
local beforeDrag = view.CurrentCamera.CFrame
UserInputService.InputChanged:Fire({ UserInputType = Enum.UserInputType.MouseMovement, Position = { X = 160 } })
check(view.CurrentCamera.CFrame ~= beforeDrag, "Mouse drag turns the 3D view")
UserInputService.InputEnded:Fire(mouse)
local touch = { UserInputType = Enum.UserInputType.Touch, Position = { X = 120 } }
view.InputBegan:Fire(touch)
local beforeTouch = view.CurrentCamera.CFrame
touch.Position = { X = 180 }
UserInputService.InputChanged:Fire(touch)
check(view.CurrentCamera.CFrame ~= beforeTouch, "Touch drag turns the same model")
UserInputService.InputEnded:Fire(touch)
local function checkFraming(width, height)
	view.AbsoluteSize = Vector2.new(width, height)
	local camera = view.CurrentCamera
	local pos, target = camera.CFrame.Position, camera.CFrame.Target
	local distance = math.sqrt((pos.X - target.X) ^ 2 + (pos.Y - target.Y) ^ 2 + (pos.Z - target.Z) ^ 2)
	local radius = Vector3.new(10, 12, 24).Magnitude / 2
	local halfFov = math.atan(math.tan(math.rad(camera.FieldOfView / 2)) * math.min(1, width / height))
	check(distance * math.sin(halfFov) >= radius, "Entire boat fits at every tested viewport aspect ratio")
end
for _, size in { { 406, 286 }, { 328, 182 }, { 180, 400 }, { 900, 180 } } do
	checkFraming(size[1], size[2])
end
for _, size in { { 390, 844 }, { 360, 640 }, { 844, 390 }, { 1920, 1080 } } do
	workspace.CurrentCamera.ViewportSize = Vector2.new(size[1], size[2])
	heartbeat:Fire(0.01)
	local scale = card:FindFirstChildOfClass("UIScale").Scale
	check(
		card.Size.X.Offset * scale <= size[1] - 31 and card.Size.Y.Offset * scale <= size[2] - 31,
		"Dock menu stays inside phone, landscape and desktop screen bounds"
	)
	local preview = dock:FindFirstChild("BoatPreviewPanel")
	for _, item in { preview, rowboat, fisher, speedboat, patrol, dock:FindFirstChild("SelectedBoatStats"), launch } do
		check(
			item.Position.X.Offset + item.Size.X.Offset <= card.Size.X.Offset
				and item.Position.Y.Offset + item.Size.Y.Offset <= card.Size.Y.Offset,
			"Main dock controls stay within the card"
		)
	end
end
launch.Activated:Fire()
check(
	#requests == 1 and requests[1][1] == "SpawnBoat" and requests[1][2] == "FishingBoat",
	"Launch sends the selected boat ID"
)
check(not overlay.Visible and #world:GetChildren() == 0, "Launching closes and releases the preview")
feedback.OnClientEvent:Fire("OpenDock", base)
player:SetAttribute("OwnsFishingBoat", false)
check(world:FindFirstChild("Rowboat") and not fisher.Active, "Loss of ownership falls back to an owned boat")
fisher.Activated:Fire()
check(world:FindFirstChild("Rowboat"), "Locked choices cannot select or launch an unowned boat")
player:SetAttribute("BoatDataStatus", "Loading")
check(not launch.Active and #world:GetChildren() == 0, "Loading fleet disables launch and clears stale models")
player:SetAttribute("BoatDataStatus", "Unavailable")
check(not launch.Active and launch.Text == "Fleet unavailable", "Load failure has an explicit disabled state")
player:SetAttribute("BoatDataStatus", "Ready")
player:SetAttribute("OwnsRowboat", false)
check(not launch.Active and #world:GetChildren() == 0, "Empty fleet has no stale boat or launch action")
launch.Activated:Fire()
check(#requests == 1, "An empty fleet cannot send spawn requests")
player:SetAttribute("OwnsSpeedboat", true)
check(world:FindFirstChild("Speedboat") and launch.Active and speedboat.Active, "Speedboat-only ownership immediately enables its preview and launch")
local displayedSpeed, displayedCargo = false, false
for _, item in dock:FindFirstChild("SelectedBoatStats"):GetDescendants() do
	if item:IsA("TextLabel") then
		displayedSpeed = displayedSpeed or item.Text == "60"
		displayedCargo = displayedCargo or item.Text == "64"
	end
end
check(displayedSpeed and displayedCargo, "Speedboat preview displays faster speed and unchanged 64-tile cargo capacity")
launch.Activated:Fire()
check(requests[#requests][2] == "Speedboat", "Speedboat launch sends its own ID")
feedback.OnClientEvent:Fire("OpenDock", base)
player:SetAttribute("OwnsSpeedboat", false)
player:SetAttribute("OwnsPatrolBoat", true)
check(world:FindFirstChild("PatrolBoat") and patrol.Active and launch.Active, "Patrol-only ownership immediately enables preview and launch")
local patrolSpeed, patrolCargo = false, false
for _, item in dock:FindFirstChild("SelectedBoatStats"):GetDescendants() do
	if item:IsA("TextLabel") then
		patrolSpeed = patrolSpeed or item.Text == "75"
		patrolCargo = patrolCargo or item.Text == "128"
	end
end
check(patrolSpeed and patrolCargo, "Patrol menu displays faster speed and exactly twice the cargo tiles")
launch.Activated:Fire()
check(requests[#requests][2] == "PatrolBoat", "Patrol launch sends its own ID")
feedback.OnClientEvent:Fire("OpenDock", base)
player:SetAttribute("OwnsPatrolBoat", false)
player:SetAttribute("OwnsRacingSpeedboat", true)
check(world:FindFirstChild("RacingSpeedboat") and racing.Active and launch.Active, "Racing-only ownership enables preview and launch")
local racingSpeed, racingCargo = false, false
for _, item in dock:FindFirstChild("SelectedBoatStats"):GetDescendants() do
	if item:IsA("TextLabel") then
		racingSpeed = racingSpeed or item.Text == "80"
		racingCargo = racingCargo or item.Text == "49"
	end
end
check(racingSpeed and racingCargo, "Racing menu shows fastest speed and 49 cargo tiles")
launch.Activated:Fire()
check(requests[#requests][2] == "RacingSpeedboat", "Racing launch sends its own ID")
feedback.OnClientEvent:Fire("OpenDock", base)
player:SetAttribute("OwnsRacingSpeedboat", false)
player:SetAttribute("OwnsFishingBoat", true)
check(world:FindFirstChild("FishingBoat") and launch.Active, "First owned boat becomes the preview immediately")
UserInputService.InputBegan:Fire({ KeyCode = Enum.KeyCode.Escape })
check(not overlay.Visible and #world:GetChildren() == 0, "Escape releases the preview")
feedback.OnClientEvent:Fire("OpenDock", base)
player.CharacterAdded:Fire(character)
check(not overlay.Visible and #world:GetChildren() == 0, "Respawn releases the preview")
feedback.OnClientEvent:Fire("OpenDock", base)
player:SetAttribute("PlayerMenuOpen", true)
check(not overlay.Visible and #world:GetChildren() == 0, "Opening another menu releases the preview")
player:SetAttribute("PlayerMenuOpen", false)
feedback.OnClientEvent:Fire("OpenDock", base)
local pausedCamera = view.CurrentCamera.CFrame
card:FindFirstChild("CloseShop").Activated:Fire()
heartbeat:Fire(0.1)
check(view.CurrentCamera.CFrame == pausedCamera, "Hidden previews stop updating")
feedback.OnClientEvent:Fire("OpenDialogue")
check(card.Size.X.Offset == 380 and card.Size.Y.Offset == 500, "Shipwright dialogue restores its original card size")
check(cameraStops > 0, "Dismissal retains existing world-camera restoration")
print(string.format("Boat menu and preview: %d checks passed (recording mocks; Studio visuals still required)", checks))
