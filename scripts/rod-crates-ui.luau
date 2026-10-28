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
services.RunService = { Heartbeat = heartbeat, RenderStepped = signal() }
UserInputService.InputChanged = signal()
UserInputService.InputEnded = signal()
local newInstance = Instance.new
Instance.new = function(kind)
	local item = newInstance(kind)
	item.InputBegan = signal()
	return item
end
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
local builds = {}
local FishingRod = {
	build = function(skinId, bobber, wear)
		table.insert(builds, { skinId, bobber, wear })
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
	if action == "OpenRodCrate" or action == "OpenBobberCrate" then
		check(not player:GetAttribute("RodCratesOpen"), "Menu closes immediately before purchase request")
	end
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
local RodCaseOpening = (function()
	-- CASE_SOURCE --
end)()
local Client = (function()
	-- CLIENT_SOURCE --
end)()
Client.start()
local screen = playerGui:WaitForChild("RodCrates")
local overlay = screen.CrateOverlay
local window = overlay.RodCrateWindow
local buy = window.Footer.OpenRodCrate
local owned = window.Footer.OpenOwnedCase
local case = overlay.RodCaseOpening
local caption = screen.RewardCaption
feedback.OnClientEvent:Fire("OpenCrates")
check(overlay.Visible and buy.Active and not owned.Active, "Stand opens shop without owned cases")
check(string.find(buy.Text, "BUY", 1, true), "Rod action offers a purchase")
buy.Activated:Fire()
check(
	#requests == 1
		and requests[1][1] == "BuyRodCrate"
		and requests[1][2].CrateId == "TideCrate"
		and requests[1][2].Count == 1,
	"Purchase requests one selected case"
)
buy.Activated:Fire()
check(#requests == 1 and overlay.Visible, "Pending purchase does not double charge or close the shop")
feedback.OnClientEvent:Fire("RodCratePurchaseResult", false, "Purchase failed")
check(window.Visible and not case.Visible, "Failed purchase does not present a case or reward")
advance(1)
buy.Activated:Fire()
player:SetAttribute("RodCrateCountTideCrate", 1)
feedback.OnClientEvent:Fire("RodCratePurchaseResult", true, "Purchased!", "TideCrate", 1)
check(case.Visible and not window.Visible and case.Reel.Visible, "Purchase opens the case screen")
check(case.OpenCase.Active and string.find(case.Subtitle.Text, "NO KEY", 1, true), "Owned case opens without a key")
case.OpenCase.Activated:Fire()
advance(0.6)
check(
	requests[#requests][1] == "OpenOwnedRodCrate" and requests[#requests][2] == "TideCrate",
	"Open consumes the owned case via server"
)
local requestCount = #requests
case.OpenCase.Activated:Fire()
check(#requests == requestCount, "Pending opening cannot submit twice")
overlay.Activated:Fire()
check(overlay.Visible, "Pending opening cannot close before the server result")
advance(61)
check(
	case.OpenCase.Active and string.find(case.Subtitle.Text, "too long", 1, true),
	"Open timeout releases the case for retry"
)
advance(1)
case.OpenCase.Activated:Fire()
advance(0.6)
feedback.OnClientEvent:Fire("CrateResult", false, "Save failed")
check(
	case.Visible and case.OpenCase.Active and case.Subtitle.Text == "Save failed",
	"Failed open can be retried without a reward"
)
advance(1)
case.OpenCase.Activated:Fire()
advance(0.6)
player:SetAttribute("RodCrateCountTideCrate", 0)
feedback.OnClientEvent:Fire("CrateResult", true, "Unboxed!", { SkinId = "BambooRod", Serial = 42, Wear = 0.5 })
check(case.Reel.Visible and not case.InspectRod.Visible, "Awarded result animates before inspection")
advance(5.4)
check(not case.Reel.Visible and case.InspectRod.Visible, "Result reveals the 3D inspection view")
check(
	case.Title.Text == RodSkins.Skins.BambooRod.Name and string.find(case.Subtitle.Text, "#000042", 1, true),
	"Inspection displays the awarded rod and serial"
)
check(
	string.find(case.Description.Text, "Battle-Scarred", 1, true)
		and string.find(case.Description.Text, "0.5000", 1, true),
	"Inspection displays wear state and float"
)
check(
	builds[#builds][1] == "BambooRod" and builds[#builds][3] == 0.5,
	"Inspection builds the rod with its awarded wear"
)
local display = case.InspectRod.WorldModel.Reward
local before = display.PivotFrame
case.InspectRod.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1, Position = { X = 10 } })
UserInputService.InputChanged:Fire({ UserInputType = Enum.UserInputType.MouseMovement, Position = { X = 80 } })
services.RunService.RenderStepped:Fire()
check(display.PivotFrame ~= before, "Dragging rotates the inspected model")
UserInputService.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })
case.OpenCase.Activated:Fire()
check(window.Visible and not case.Visible and not owned.Active, "Done returns to shop after consuming case")
player:SetAttribute("RodCrateCountTideCrate", 2)
check(owned.Active and string.find(owned.Text, "2", 1, true), "Owned cases remain available from shop")
window.Header.CloseCrates.Activated:Fire()
advance(1)
feedback.OnClientEvent:Fire("OpenCrates")
check(owned.Active, "Saved case count remains accessible after reopening the shop")
owned.Activated:Fire()
local beforeCancelledOpen = #requests
case.OpenCase.Activated:Fire()
overlay.Activated:Fire()
feedback.OnClientEvent:Fire("OpenCrates")
owned.Activated:Fire()
advance(0.6)
check(#requests == beforeCancelledOpen, "Closing a queued case screen cancels its delayed open")
case.Back.Activated:Fire()
check(window.Visible and not case.Visible, "Back keeps an unopened case")
window.CrateTabs.SelectNoveltyCrate.Activated:Fire()
check(window.SkinsNoveltyCrate.Visible and not window.SkinsTideCrate.Visible, "Selecting another crate switches grids")
check(string.find(buy.Text, "$750", 1, true), "Selected crate displays its price")
player:SetAttribute("Cash", 749)
check(not buy.Active, "Insufficient funds disable purchase")
player:SetAttribute("Cash", 750)
check(buy.Active, "Exact funds enable purchase")
advance(1)
buy.Activated:Fire()
check(requests[#requests][2].CrateId == "NoveltyCrate", "Purchase sends the selected crate id")
feedback.OnClientEvent:Fire("RodCratePurchaseResult", false, "Purchase failed")
window.Header.CloseCrates.Activated:Fire()
local bobberStand = Instance.new("Part")
bobberStand.Parent, bobberStand.Position = interiors, Vector3.zero
local bobberPrompt = Instance.new("ProximityPrompt")
bobberPrompt.Name, bobberPrompt.Parent = "OpenBobberCratePrompt", bobberStand
local bobberScreen = playerGui:WaitForChild("BobberCrates")
local bobberOverlay = bobberScreen.CrateOverlay
local bobberWindow = bobberOverlay.BobberCrateWindow
local bobberOpen = bobberWindow.Footer.OpenBobberCrate
advance(1)
feedback.OnClientEvent:Fire("OpenBobberCrates")
check(bobberOverlay.Visible and not overlay.Visible, "Bobber stand opens its own case window")
check(
	bobberWindow.SkinsBobberCase.CrownedGoldBobber and bobberWindow.SkinsBobberCase.NeonPurpleBobber,
	"Bobber rewards appear in the case grid"
)
check(string.find(bobberOpen.Text, "$350", 1, true), "Bobber case displays its budget price")
player:SetAttribute("Cash", 349)
check(not bobberOpen.Active, "Bobber case cannot be opened with insufficient cash")
player:SetAttribute("Cash", 350)
player:SetAttribute("BobberSkinCountCrownedGoldBobber", 2)
local bobberEquip = bobberWindow.SkinsBobberCase.CrownedGoldBobber.EquipCrownedGoldBobber
check(bobberOpen.Active and bobberEquip.Active, "Exact funds enable purchase and owned bobbers enable equip")
bobberEquip.Activated:Fire()
check(
	requests[#requests][1] == "EquipBobberSkin" and requests[#requests][2] == "CrownedGoldBobber",
	"Bobber card sends its own equip action"
)
player:SetAttribute("BobberSkin", "CrownedGoldBobber")
feedback.OnClientEvent:Fire("BobberSkinResult", true, "Equipped!")
advance(1)
check(not bobberEquip.Active and bobberEquip.Text == "EQUIPPED", "Bobber selection follows saved attributes")
bobberOpen.Activated:Fire()
check(
	not bobberOverlay.Visible and requests[#requests][1] == "OpenBobberCrate" and requests[#requests][2] == "BobberCase",
	"Purchase targets the bobber case and closes its menu"
)
unavailable = false
feedback.OnClientEvent:Fire("BobberCrateResult", true, "Unboxed!", "NeonPurpleBobber")
revealCallbacks.reward()
check(bobberScreen.RewardCaption.Visible and not caption.Visible, "Saved bobber gets its own reward caption")
revealCallbacks.finish()
heartbeat:Fire(0.3)
check(
	not player:GetAttribute("RodCrateOpening") and bobberWindow:FindFirstChildOfClass("UIScale").Scale < 1,
	"Bobber reveal cleans up and the case fits a phone"
)
print(`Rod and bobber case menus: {checks} checks passed (recording mocks; no Studio rendering)`)
