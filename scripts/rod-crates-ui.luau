-- Uses the shared menu recording primitives to execute the production crate UI.
local Font = {
	new = function(family, weight, style)
		return { Family = family, Weight = weight, Style = style }
	end,
}
local colorFromRGB = Color3.fromRGB
Color3.fromRGB = function(r, g, b)
	local color = colorFromRGB(r, g, b)
	color.R, color.G, color.B = r / 255, g / 255, b / 255
	return color
end
function methods:FindFirstChildOfClass(class)
	for _, child in self:GetChildren() do
		if child:IsA(class) then
			return child
		end
	end
	return nil
end
vectorMeta.__sub = function(a, b)
	local x, y, z = a.X - b.X, a.Y - b.Y, a.Z - b.Z
	return { X = x, Y = y, Z = z, Magnitude = math.sqrt(x * x + y * y + z * z) }
end
Vector3.zero = Vector3.new(0, 0, 0)
local heartbeat = signal()
services.RunService = { Heartbeat = heartbeat }
services.TweenService = {
	Create = function(_, item, _, goals)
		return {
			Play = function()
				for key, value in goals do
					item[key] = value
				end
			end,
		}
	end,
}
local TweenInfo = {
	new = function()
		return {}
	end,
}
services.CollectionService = { RemoveTag = function() end }
local Theme = (function()
	-- THEME_SOURCE --
end)()
local RodSkins = (function()
	-- SKINS_SOURCE --
end)()
local FishingRod = {
	build = function()
		local tool = Instance.new("Tool")
		Instance.new("Part").Parent = tool
		return tool
	end,
}
local revealCallbacks, revealCount = nil, 0
local unavailable = false
local CrateReveal = {
	play = function(stand, skin, onReward, onFinished)
		check(not player:GetAttribute("RodCratesOpen"), "Menu closes before world reveal starts")
		if unavailable then
			return nil
		end
		revealCount += 1
		revealCallbacks = { reward = onReward, finish = onFinished, skin = skin }
		return onFinished
	end,
}
Instance.new("Folder").Parent = ReplicatedStorage
local shared = Instance.new("Folder")
shared.Name, shared.Parent = "Shared", ReplicatedStorage
local remotes = Instance.new("Folder")
remotes.Name, remotes.Parent = "Fishing", ReplicatedStorage
local request, feedback = Instance.new("RemoteEvent"), Instance.new("RemoteEvent")
request.Name, request.Parent, request.OnClientEvent = "Request", remotes, signal()
feedback.Name, feedback.Parent, feedback.OnClientEvent = "Feedback", remotes, signal()
local requests = {}
function request:FireServer(action, value)
	table.insert(requests, { action, value })
	check(not player:GetAttribute("RodCratesOpen"), "Menu closes immediately before purchase request")
end
local interiors = Instance.new("Folder")
interiors.Name, interiors.Parent = "Interiors", workspace
local stand = Instance.new("Part")
stand.Parent, stand.Position = interiors, Vector3.zero
local prompt = Instance.new("ProximityPrompt")
prompt.Name, prompt.Parent = "OpenRodCratePrompt", stand
local character = Instance.new("Model")
player.Character = character
local root = Instance.new("Part")
root.Name, root.Parent, root.Position = "HumanoidRootPart", character, Vector3.new(0, 3, 4)
workspace.CurrentCamera = { ViewportSize = Vector2.new(390, 844) }
player:SetAttribute("OwnsStarterRod", true)
player:SetAttribute("Cash", 1000)
local Client = (function()
	-- CLIENT_SOURCE --
end)()
Client.start()
local screen = playerGui:WaitForChild("RodCrates")
local overlay = screen.CrateOverlay
local open = overlay.RodCrateWindow.Footer.OpenRodCrate
local caption = screen.RewardCaption
feedback.OnClientEvent:Fire("OpenCrates")
check(overlay.Visible and open.Active, "Stand opens crate menu")
open.Activated:Fire()
check(not overlay.Visible and player:GetAttribute("RodCrateOpening"), "Opening exits the GUI immediately")
check(#requests == 1 and requests[1][1] == "OpenRodCrate" and requests[1][2] == "TideCrate", "One crate requested")
open.Activated:Fire()
feedback.OnClientEvent:Fire("OpenCrates")
check(#requests == 1 and not overlay.Visible, "Pending opening cannot double charge or reopen the menu")
check(revealCount == 0 and not caption.Visible, "No preview reward before server success")
feedback.OnClientEvent:Fire("CrateResult", true, "You unboxed Bamboo!", "BambooRod", 42)
check(
	revealCount == 1 and revealCallbacks.skin == "BambooRod" and not overlay.Visible,
	"Saved rod starts the world reveal"
)
revealCallbacks.reward()
check(caption.Visible and caption.Parent == screen, "Reward caption is outside the closed menu")
local showsSerial = false
for _, item in caption:GetDescendants() do
	if item:IsA("TextLabel") and string.find(item.Text, "Serial #000042", 1, true) then
		showsSerial = true
	end
end
check(showsSerial, "Crate reveal displays the serial committed by the server")
feedback.OnClientEvent:Fire("OpenCrates")
check(not overlay.Visible, "Menu stays closed throughout the animation")
revealCallbacks.finish()
check(
	not player:GetAttribute("RodCrateOpening") and not overlay.Visible and not caption.Visible,
	"Completion returns directly to play"
)
advance(1)
feedback.OnClientEvent:Fire("OpenCrates")
open.Activated:Fire()
feedback.OnClientEvent:Fire("CrateResult", false, "Not enough coins")
check(
	overlay.Visible and not player:GetAttribute("RodCrateOpening") and revealCount == 1,
	"Failed purchase returns to menu without a fake reward"
)
advance(1)
open.Activated:Fire()
advance(9)
check(overlay.Visible and not player:GetAttribute("RodCrateOpening"), "Request timeout releases opening state")
advance(1)
open.Activated:Fire()
feedback.OnClientEvent:Fire("CrateResult", true, "Unboxed!", "BoneRod")
player.CharacterRemoving:Fire()
check(not player:GetAttribute("RodCrateOpening") and not caption.Visible, "Respawning ends the reveal")
advance(1)
feedback.OnClientEvent:Fire("OpenCrates")
open.Activated:Fire()
unavailable = true
feedback.OnClientEvent:Fire("CrateResult", true, "Unboxed!", "MageStaff")
check(caption.Visible and not overlay.Visible, "Streamed-away stand still reports the saved reward")
advance(3.1)
check(not caption.Visible and not player:GetAttribute("RodCrateOpening"), "Fallback caption cleans up")
heartbeat:Fire(0.3)
check(caption:FindFirstChildOfClass("UIScale").Scale < 1, "Reward caption fits a phone screen")
print(`Rod crate menu: {checks} checks passed (recording mocks; no Studio rendering)`)
