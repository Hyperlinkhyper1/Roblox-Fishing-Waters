-- Appended to the recording menu harness by --home-only.
check(Data.decode(nil).ShopSign == "", "Old profiles use the default shop sign")
check(not invoke("ShopSign", string.rep("x", 33)).Ok, "Long names are rejected")
check(not invoke("ShopSign", "two\nlines").Ok, "Multiline names are rejected")
check(invoke("ShopSign", "  badword fish  ").Ok, "Shop names can be saved")
check(profile.Angler.ShopSign == "####### fish", "Only filtered names are saved")
check(Data.decode(profile.Angler).ShopSign == "####### fish", "Shop name survives profile decoding")
check(invoke("ShopSign", " ").Ok and profile.Angler.ShopSign == "", "Blank name resets the sign")
check(next(Data.decode(nil).Staff) == nil, "Old profiles start without paid staff")
check(not pcall(Data.decode, { Staff = { Seller = 1 } }), "Malformed saved hires are rejected")
check(not pcall(Data.decode, { Staff = { Admin = true } }), "Unknown staff roles are rejected")
check(
	not invoke("BuyShopUpgrade", {}).Ok and not invoke("BuyShopUpgrade", "PorterSpeed").Ok,
	"Unknown shop upgrades are rejected"
)
profile.Cash = 999
check(
	not invoke("BuyShopUpgrade", "SocialMediaAdvertisement").Ok and profile.Cash == 999,
	"Advertisement requires enough cash"
)
profile.Cash = 1000
failSave = true
check(
	not invoke("BuyShopUpgrade", "SocialMediaAdvertisement").Ok
		and profile.Cash == 1000
		and not profile.Angler.Upgrades.SocialMediaAdvertisement,
	"Failed advertisement purchase preserves data"
)
failSave = false
local adSpent = profile.Angler.Stats.CoinsSpent
check(
	invoke("BuyShopUpgrade", "SocialMediaAdvertisement", 0).Ok
		and profile.Cash == 0
		and profile.Angler.Upgrades.SocialMediaAdvertisement == 1,
	"Advertisement purchase uses server price"
)
check(
	profile.Angler.Stats.CoinsSpent == adSpent + 1000
		and Data.decode(profile.Angler).Upgrades.SocialMediaAdvertisement == 1,
	"Advertisement spending and ownership persist"
)
profile.Cash = 1000
check(
	not invoke("BuyShopUpgrade", "SocialMediaAdvertisement").Ok and profile.Cash == 1000,
	"Advertisement cannot be purchased twice"
)
profile.Angler.Upgrades.SocialMediaAdvertisement = nil
profile.Cash = 0
local savedCash = profile.Cash
check(not invoke("HireStaff", "Seller").Ok and profile.Cash == savedCash, "Insufficient funds cannot hire")
check(not invoke("HireStaff", "Admin").Ok, "Unknown hire rejected")
check(not invoke("HireStaff", {}).Ok, "Malformed role rejected")
profile.Cash = 1000
local spent = profile.Angler.Stats.CoinsSpent
check(invoke("HireStaff", "Seller", 0).Ok, "Seller can be hired")
check(profile.Cash == 750 and profile.Angler.Staff.Seller, "Server price ignores client-supplied price")
check(profile.Angler.Stats.CoinsSpent == spent + 250, "Hire counts spending")
check(not invoke("HireStaff", "Seller").Ok and profile.Cash == 750, "Duplicate hire cannot charge again")
failSave = true
check(
	not invoke("HireStaff", "Porter").Ok and not profile.Angler.Staff.Porter and profile.Cash == 750,
	"Failed save preserves cash and staff"
)
failSave = false
check(invoke("HireStaff", "Porter").Ok and profile.Cash == 350, "Porter can be hired independently")
check(
	Data.decode(profile.Angler).Staff.Porter and Data.decode(profile.Angler).Staff.Seller,
	"Hires survive profile decoding"
)

check(
	not invoke("UpgradePorter", {}).Ok and not invoke("UpgradePorter", "Cash", 0).Ok,
	"Malformed and unknown porter upgrades are rejected"
)
check(
	not invoke("UpgradePorter", "PorterSpeed", 0).Ok and profile.Cash == 350,
	"Insufficient funds cannot buy a porter upgrade"
)
profile.Cash = 100000
profile.Angler.Staff.Porter = nil
check(not invoke("UpgradePorter", "PorterCapacity", 0).Ok, "A porter must be hired before upgrading")
profile.Angler.Staff.Porter = true
local upgradeCash, upgradeSpent = profile.Cash, profile.Angler.Stats.CoinsSpent
failSave = true
check(
	not invoke("UpgradePorter", "PorterSpeed", 0).Ok
		and profile.Cash == upgradeCash
		and not profile.Angler.Upgrades.PorterSpeed,
	"Failed upgrade save preserves cash and level"
)
failSave = false
check(not invoke("UpgradePorter", "PorterSpeed", -600).Ok, "Client cannot supply its own price or level")
local originalUpdate = BoatService.updateProgress
BoatService.updateProgress = function(_, transform)
	profile.Angler.Upgrades.PorterSpeed = 1
	local ok = pcall(transform, profile)
	return ok, "Level changed during save"
end
check(
	not invoke("UpgradePorter", "PorterSpeed", 0).Ok and profile.Cash == upgradeCash,
	"Transaction rechecks the current upgrade level before charging"
)
BoatService.updateProgress = originalUpdate
profile.Angler.Upgrades.PorterSpeed = nil
for _, id in StaffCatalog.PorterUpgradeOrder do
	for level = 0, 3 do
		local price = StaffCatalog.PorterUpgrades[id].Prices[level + 1]
		local cash = profile.Cash
		check(
			invoke("UpgradePorter", id, level).Ok
				and profile.Cash == cash - price
				and profile.Angler.Upgrades[id] == level + 1,
			"Server sells exactly the next upgrade at its configured price"
		)
		check(
			not invoke("UpgradePorter", id, level).Ok and profile.Cash == cash - price,
			"Replaying an upgrade cannot charge for a different level"
		)
	end
	check(not invoke("UpgradePorter", id, 4).Ok, "Maximum upgrade cannot be purchased again")
end
local decoded = Data.decode(profile.Angler)
local porterSpeed, porterCapacity = StaffCatalog.porterStats(decoded)
check(porterSpeed == 32 and porterCapacity == 5, "Both saved upgrade tracks survive profile decoding")
check(
	profile.Angler.Stats.CoinsSpent - upgradeSpent == upgradeCash - profile.Cash,
	"Upgrade spending matches cash charged"
)
profile.Cash, profile.Angler.Upgrades = 350, {}

local fish = { Trout = { AverageKg = 2, RarityDenominator = 10 } }
local caught = Data.recordCatch(nil, "Trout", "Normal", 2, 19.8, 100, fish, { Normal = {} }, "Big")
local record = caught.Hand
caught.Holds.Rowboat = { { PartId = "Oar", X = 1, Y = 1, R = 0 }, { Fish = record, X = 2, Y = 1, R = 0 } }
local delivered = Data.unloadFish(caught, "Rowboat", 2, record)
check(delivered and #delivered.Freezer == 1 and #delivered.Holds.Rowboat == 1, "Porter transfers one fish")
check(delivered.Holds.Rowboat[1].PartId == "Oar" and delivered.Hand ~= nil, "Porter preserves parts and carried fish")
check(#caught.Holds.Rowboat == 2 and #caught.Freezer == 0, "Delivery is copy-on-write")
check(not Data.unloadFish(delivered, "Rowboat", 2, record), "Delivery cannot duplicate a fish")
local stale = table.clone(record)
stale.Mutation = "Albino"
check(not Data.unloadFish(caught, "Rowboat", 2, stale), "A replaced fish cannot be delivered from a stale trip")
check(not Data.unloadFish(caught, "Rowboat", 1, record), "Porter never unloads boat parts")
while Data.canFreeze(caught, record) do
	table.insert(caught.Freezer, record)
end
check(
	not Data.unloadFish(caught, "Rowboat", 2, record) and #caught.Holds.Rowboat == 2,
	"Full freezer preserves boat cargo"
)

-- Exercise the actual asynchronous preview loader before the menu fills its cache.
local function previewSurface()
	local holder = Instance.new("Frame")
	holder.Parent = playerGui
	local view, status = Instance.new("ViewportFrame"), Instance.new("TextLabel")
	view.Parent, status.Parent = holder, holder
	view.AbsoluteSize = Vector2.new(150, 200)
	return holder, view, status
end
failPreview = true
local failedHolder, failedView, failedStatus = previewSurface()
StaffPreview.show(failedView, "Seller", failedStatus)
check(
	string.find(failedStatus.Text, "unavailable") and not failedView:FindFirstChildOfClass("WorldModel"),
	"Avatar failure shows a recoverable message without breaking the menu"
)
failPreview = false
local holder, view, status = previewSurface()
local rotate = StaffPreview.show(view, "Seller", status)
local model = view:FindFirstChildOfClass("WorldModel"):FindFirstChildOfClass("Model")
check(not status.Visible and model ~= nil, "Retry loads the staff into a viewport WorldModel")
check(model.Head.face.Texture == "rbxasset://textures/face.png", "Preview shows the worker's friendly smile")
check(
	model:FindFirstChildOfClass("Part").Anchored
		and not model:FindFirstChildOfClass("Part").CanCollide
		and not model:FindFirstChildOfClass("LocalScript"),
	"Preview clones are inert and have no executable scripts"
)
local beforeTurn = view.CurrentCamera.CFrame.Position.X
rotate(1)
check(view.CurrentCamera.CFrame.Position.X ~= beforeTurn, "Turn controls orbit the preview camera")
local beforeResize = view.CurrentCamera.CFrame.Position.Z
view.AbsoluteSize = Vector2.new(70, 200)
check(view.CurrentCamera.CFrame.Position.Z ~= beforeResize, "Camera refits the avatar in narrow previews")
local spawn = task.spawn
local deferred
task.spawn = function(callback)
	deferred = callback
end
local staleHolder, staleView, staleStatus = previewSurface()
StaffPreview.show(staleView, "Porter", staleStatus)
local liveHolder, liveView, liveStatus = previewSurface()
StaffPreview.show(liveView, "Porter", liveStatus)
staleHolder:Destroy()
task.spawn = spawn
deferred()
check(
	#staleView:GetChildren() == 0 and not liveStatus.Visible,
	"An in-flight load skips destroyed views and serves the remaining waiting preview"
)
local cachedLoads = previewLoads
for _, item in { failedHolder, holder, liveHolder } do
	item:Destroy()
end
local portraitHolder, portraitView, portraitStatus = previewSurface()
StaffPreview.show(portraitView, "Seller", portraitStatus, true)
check(
	portraitView.CurrentCamera.CFrame.Target.Y > view.CurrentCamera.CFrame.Target.Y,
	"Portrait framing targets the upper body instead of the full rig"
)
check(portraitView.CurrentCamera.CFrame.Position.X == 0, "Worker portraits face forward")
portraitHolder:Destroy()

Menu.start()
advance(1)
local gui = playerGui.PlayerMenu
local sidebar, card = gui.LeftNavigation, gui.MenuOverlay.MenuWindow
local content = card.Content
local function click(name)
	now += 1
	assert(content:FindFirstChild(name, true), "Missing Home control: " .. name).Activated:Fire()
end
local function contains(value)
	for _, item in content:GetDescendants() do
		if type(item.Text) == "string" and string.find(item.Text, value, 1, true) then
			return true
		end
	end
	return false
end
profile.Angler.Freezer = { record }
profile.Angler.Hand = record
profile.Angler.Cooler = { record }
profile.Angler.Holds.Rowboat = caught.Holds.Rowboat
for _, width in { 1020, 362 } do
	card.AbsoluteSize = Vector2.new(width, 600)
	now += 1
	sidebar.Home.Activated:Fire()
	check(gui.MenuOverlay.Visible and player:GetAttribute("PlayerMenuOpen"), "Home opens management GUI")
	check(content:FindFirstChild("GoHome", true) == nil, "Home has no teleport button")
	for _, tab in { "Staff", "Upgrades", "Overview", "Achievements" } do
		check(content:FindFirstChild(tab .. "Tab", true) ~= nil, "Home includes " .. tab)
	end
	click("StaffTab")
	check(
		card:GetAttribute("GlassSurface") and card.BackgroundTransparency == 0.2,
		"Home uses the same glass window as Settings"
	)
	check(contains("Your crew · 2/" .. #StaffCatalog.Order .. " hired"), "Staff summary counts owned hires")
	local grid = content:FindFirstChild("WorkerGrid", true)
	check(grid and grid:FindFirstChildOfClass("UIGridLayout"), "Workers use a portrait card grid")
	for _, gridWidth in { 700, 300, 230 } do
		grid.AbsoluteSize = Vector2.new(gridWidth, 300)
		local layout = grid.WorkerCards
		check(
			layout.CellSize.X.Offset * layout.FillDirectionMaxCells + (layout.FillDirectionMaxCells - 1) * 10
				<= gridWidth,
			"Responsive worker cards stay inside the available width"
		)
	end
	for _, id in { "Seller", "Porter" } do
		local preview = content:FindFirstChild(id .. "Preview", true)
		check(
			preview and preview.CurrentCamera and preview:FindFirstChildOfClass("WorldModel"),
			"Staff card displays its 3D NPC before any hiring interaction"
		)
		click("Select" .. id)
		check(contains(id .. " · Hired"), "Selecting a portrait shows its saved worker details")
		check(
			content:FindFirstChild(id .. "Staff", true).SelectionAccent.Visible,
			"The selected worker has a visible card accent"
		)
	end
	check(
		contains("Speed · Level 0/4") and contains("1 fish/trip"),
		"Porter details show saved speed and carrying stats"
	)
	check(not content:FindFirstChild("UpgradePorterSpeed", true).Active, "Unaffordable upgrade is disabled")
	profile.Cash = 2000
	player:SetAttribute("AnglerRevision", (player:GetAttribute("AnglerRevision") or 0) + 1)
	advance(1)
	check(content:FindFirstChild("UpgradePorterSpeed", true).Active, "Cash refresh enables porter upgrades")
	click("UpgradePorterSpeed")
	check(
		profile.Angler.Upgrades.PorterSpeed == 1 and profile.Cash == 1400 and contains("20 studs/sec"),
		"Speed purchase refreshes the displayed stat and wallet"
	)
	click("UpgradePorterCapacity")
	check(
		profile.Angler.Upgrades.PorterCapacity == 1 and profile.Cash == 800 and contains("2 fish/trip"),
		"Carry purchase refreshes the displayed stat on desktop and mobile"
	)
	profile.Angler.Upgrades = { PorterSpeed = 4, PorterCapacity = 4 }
	player:SetAttribute("AnglerRevision", (player:GetAttribute("AnglerRevision") or 0) + 1)
	advance(1)
	check(
		not content:FindFirstChild("UpgradePorterSpeed", true).Active
			and not content:FindFirstChild("UpgradePorterCapacity", true).Active
			and contains("Max level"),
		"Maximum levels have no active purchase controls"
	)
	profile.Angler.Upgrades, profile.Cash = {}, 350
	check(not content:FindFirstChild("HireFisherman", true).Active, "Company-locked fisherman cannot be hired")
	click("SelectFisherman")
	check(contains("Unlocks with The Company"), "Selecting a locked worker explains the required path")
	click("WorkerFilter")
	check(
		content:FindFirstChild("FishermanStaff", true) == nil and content:FindFirstChild("SellerStaff", true),
		"Hired filter shows only saved workers"
	)
	click("WorkerFilter")
	check(
		content:FindFirstChild("SellerStaff", true) == nil and content:FindFirstChild("FishermanStaff", true),
		"For hire filter shows only unhired workers"
	)
	click("WorkerFilter")
	check(not content:FindFirstChild("HireSeller", true).Active, "Already hired control is inactive")
	cachedLoads = previewLoads
	click("OverviewTab")
	check(
		contains("4 fish in stock · $76 total value"),
		"Stock totals count fish across storage and round sale values"
	)
	check(contains("Freezer 1 fish") and contains("3 fish waiting"), "Freezer stock shows physical space usage")
	check(contains("Cargo hold") and contains("In hand") and contains("Legacy cooler"), "Stock shows all locations")
	profile.Angler.Freezer, profile.Angler.Hand, profile.Angler.Cooler, profile.Angler.Holds = {}, nil, {}, {}
	now += 1
	player:SetAttribute("AnglerRevision", (player:GetAttribute("AnglerRevision") or 0) + 1)
	advance(1)
	check(contains("No fish in stock yet"), "Open overview refreshes after inventory revision")
	click("UpgradesTab")
	check(
		contains("Social Media Advertisement") and contains("Two customers every 35 seconds"),
		"Upgrades tab describes the advertisement"
	)
	check(
		not contains("Porter upgrades") and not content:FindFirstChild("ManagePorterUpgrades", true),
		"Upgrades tab contains no worker upgrades"
	)
	check(
		not content:FindFirstChild("BuySocialMediaAdvertisement", true).Active,
		"Unaffordable advertisement is disabled"
	)
	profile.Cash = 1000
	player:SetAttribute("AnglerRevision", (player:GetAttribute("AnglerRevision") or 0) + 1)
	advance(1)
	check(content:FindFirstChild("BuySocialMediaAdvertisement", true).Active, "Cash refresh enables advertisement")
	click("BuySocialMediaAdvertisement")
	check(
		profile.Angler.Upgrades.SocialMediaAdvertisement == 1 and profile.Cash == 0 and contains("Owned"),
		"Advertisement purchase refreshes the menu"
	)
	profile.Angler.Upgrades, profile.Cash = {}, 350
	click("AchievementsTab")
	check(contains("No achievements yet."), "Achievements remains empty")
	card.CloseMenu.Activated:Fire()
	check(not gui.MenuOverlay.Visible and sidebar.Visible, "Home closes and restores sidebar")
	check(#content:GetDescendants() == 0, "Closing Home releases hidden viewport worlds")
	profile.Angler.Freezer, profile.Angler.Hand, profile.Angler.Cooler = { record }, record, { record }
	profile.Angler.Holds.Rowboat = caught.Holds.Rowboat
end
now += 1
sidebar.Home.Activated:Fire()
profile.Angler.Staff.Porter = nil
profile.Cash = 100
player:SetAttribute("AnglerRevision", (player:GetAttribute("AnglerRevision") or 0) + 1)
advance(1)
click("StaffTab")
click("SelectPorter")
check(not content:FindFirstChild("HirePorter", true).Active, "Insufficient cash disables the hire control")
check(contains("$300 more needed"), "Hire card explains exactly how much more cash is required")
check(
	not content:FindFirstChild("UpgradePorterSpeed", true).Active and contains("Hire a porter first"),
	"Unhired porter previews upgrades but cannot buy them"
)
profile.Cash = 400
player:SetAttribute("AnglerRevision", (player:GetAttribute("AnglerRevision") or 0) + 1)
advance(1)
check(content:FindFirstChild("HirePorter", true).Active, "Funds refresh enables hiring")
click("HirePorter")
check(
	profile.Angler.Staff.Porter and profile.Cash == 0 and contains("Porter · Hired"),
	"Hire button saves and updates the visible staff card"
)
check(previewLoads == cachedLoads, "Tab changes, resizes and profile refreshes reuse cached staff models")
profile.Cash = 6000
profile.Angler.Paths.Unlocked.Company = true
player:SetAttribute("AnglerRevision", (player:GetAttribute("AnglerRevision") or 0) + 1)
advance(1)
click("SelectFisherman")
click("HireFisherman")
check(
	profile.Angler.Staff.Fisherman and profile.Cash == 0,
	"Fisherman card hires through the server after unlocking Company"
)
check(contains("Buy a boat at the drydock first"), "Fisherman without owned boats has a useful empty state")
profile.OwnedBoats = { Rowboat = true, FishingBoat = true }
BoatService.activeBoat = function()
	return nil
end
player:SetAttribute("AnglerRevision", (player:GetAttribute("AnglerRevision") or 0) + 1)
advance(1)
click("AssignFishingBoat")
check(profile.Angler.FishermanBoat == "FishingBoat", "Selected fisherman's boat button saves the assignment")
check(
	content:FindFirstChild("AssignFishingBoat", true).ThemeFace:GetAttribute("Finish") == "Selected",
	"Assigned boat stays highlighted after profile refresh"
)
click("WorkerFilter")
click("WorkerFilter")
check(contains("No workers in this filter."), "Empty for-hire filter remains usable when all workers are hired")
check(content:FindFirstChild("WorkerGrid", true).Size.Y.Offset >= 0, "Empty worker grid has a valid height")
click("WorkerFilter")
print("Home menu: " .. checks .. " hiring, inventory and desktop/mobile recording checks passed.")
