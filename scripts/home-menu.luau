-- Appended to the recording menu harness by --home-only.
check(next(Data.decode(nil).Staff) == nil, "Old profiles start without paid staff")
check(not pcall(Data.decode, { Staff = { Seller = 1 } }), "Malformed saved hires are rejected")
check(not pcall(Data.decode, { Staff = { Admin = true } }), "Unknown staff roles are rejected")
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
check(not invoke("HireStaff", "Porter").Ok and not profile.Angler.Staff.Porter and profile.Cash == 750,
	"Failed save preserves cash and staff")
failSave = false
check(invoke("HireStaff", "Porter").Ok and profile.Cash == 350, "Porter can be hired independently")
check(Data.decode(profile.Angler).Staff.Porter and Data.decode(profile.Angler).Staff.Seller, "Hires survive profile decoding")

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
for index = 1, Data.FREEZER_CAPACITY do caught.Freezer[index] = record end
check(not Data.unloadFish(caught, "Rowboat", 2, record) and #caught.Holds.Rowboat == 2,
	"Full freezer preserves boat cargo")

Menu.start()
advance(1)
local gui = playerGui.PlayerMenu
local sidebar, card = gui.LeftNavigation, gui.MenuOverlay.MenuWindow
local content = card.Content
local homeCalls = 0
function goHome:FireServer() homeCalls += 1 end
local function click(name)
	now += 1
	assert(content:FindFirstChild(name, true), "Missing Home control: " .. name).Activated:Fire()
end
local function contains(value)
	for _, item in content:GetDescendants() do
		if type(item.Text) == "string" and string.find(item.Text, value, 1, true) then return true end
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
	check(homeCalls == 0, "Opening Home does not teleport")
	for _, tab in { "Staff", "Upgrades", "Overview", "Achievements" } do
		check(content:FindFirstChild(tab .. "Tab", true) ~= nil, "Home includes " .. tab)
	end
	click("StaffTab")
	check(contains("Seller · Hired") and contains("Porter · Hired"), "Staff shows saved hires")
	check(not content:FindFirstChild("HireSeller", true).Active, "Already hired control is inactive")
	click("OverviewTab")
	check(contains("4 fish in stock · $76 total value"), "Stock totals count fish across storage and round sale values")
	check(contains("Freezer 1/4") and contains("3 fish waiting"), "Freezer count uses authoritative capacity")
	check(contains("Cargo hold") and contains("In hand") and contains("Legacy cooler"), "Stock shows all locations")
	profile.Angler.Freezer, profile.Angler.Hand, profile.Angler.Cooler, profile.Angler.Holds = {}, nil, {}, {}
	now += 1
	player:SetAttribute("AnglerRevision", (player:GetAttribute("AnglerRevision") or 0) + 1)
	advance(1)
	check(contains("No fish in stock yet"), "Open overview refreshes after inventory revision")
	click("UpgradesTab")
	check(contains("No upgrades yet."), "Upgrades remains empty")
	click("AchievementsTab")
	check(contains("No achievements yet."), "Achievements remains empty")
	card.CloseMenu.Activated:Fire()
	check(not gui.MenuOverlay.Visible and sidebar.Visible, "Home closes and restores sidebar")
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
check(not content:FindFirstChild("HirePorter", true).Active, "Insufficient cash disables the hire control")
profile.Cash = 400
player:SetAttribute("AnglerRevision", (player:GetAttribute("AnglerRevision") or 0) + 1)
advance(1)
check(content:FindFirstChild("HirePorter", true).Active, "Funds refresh enables hiring")
click("HirePorter")
check(profile.Angler.Staff.Porter and profile.Cash == 0 and contains("Porter · Hired"), "Hire button saves and updates the visible staff card")
click("GoHome")
check(homeCalls == 1 and not gui.MenuOverlay.Visible, "Separate Go home control teleports and closes menu")
print("Home menu: " .. checks .. " hiring, inventory and desktop/mobile recording checks passed.")
