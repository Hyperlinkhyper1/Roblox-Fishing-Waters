services.ReplicatedFirst = Instance.new("ReplicatedFirst")
function methods:FindFirstChildOfClass(class)
	for _, child in self:GetChildren() do if child:IsA(class) then return child end end
	return nil
end
services.StarterGui = { SetCoreGuiEnabled = function() end }
UserInputService.GetFocusedTextBox = function() return nil end
local roster = { player }
function Players:GetPlayers() return roster end
local function companyMember(id, companyId, name, worth, multiplayer)
	local member = Instance.new("Player")
	member.Name, member.DisplayName, member.UserId = "Angler" .. id, "Angler " .. id, id
	member:SetAttribute("BoatDataStatus", "Ready")
	member:SetAttribute("CompanyId", companyId)
	member:SetAttribute("CompanyName", name)
	member:SetAttribute("CompanyNetWorth", worth)
	member:SetAttribute("CompanyMultiplayer", multiplayer ~= false)
	member.Parent = Players
	table.insert(roster, member)
	return member
end
player:SetAttribute("CompanyId", "7_1")
player:SetAttribute("CompanyName", "Shared Company")
player:SetAttribute("CompanyNetWorth", 100)
player:SetAttribute("CompanyMultiplayer", true)
local friend = companyMember(8, "7_1", "Shared Company", 100)
local friend2 = companyMember(9, "7_1", "Shared Company", 100)
local solo = companyMember(10, "10_2", "Solo Company", 120, false)
solo:SetAttribute("CompanyIcon", 9001)
local Theme = (function()
-- THEME --
end)()
local FishingRanks = (function()
-- RANKS --
end)()
local Leaderboard = (function()
-- CLIENT --
end)()
Leaderboard.start()
local gui = playerGui.CustomLeaderboard
local panel = gui.PlayerList
check(panel.Rows.Visible and not panel.Companies.Visible, "People tab remains the default")
panel.CompaniesTab.Activated:Fire()
check(panel.Companies.Visible and panel.CompanyHeader.Visible and not panel.Rows.Visible, "Companies tab changes columns and rows together")
local row = panel.Companies:FindFirstChild("7_1")
check(row and row.CompanyName.Text == "Shared Company" and row.NetWorth.Text == "$100" and row.Crew.Text == "3/5",
	"Three company members display one shared net worth, not three wallets")
check(row.LayoutOrder == 2 and panel.Companies["10_2"].LayoutOrder == 1, "Companies sort by current net worth, including singleplayer saves")
check(string.find(panel.Companies["10_2"].Icon.Image, "id=9001", 1, true) ~= nil and panel.Companies["10_2"].Icon.Initial.Text == "", "Companies tab shows the company icon")
check(row.Icon.Image == "" and row.Icon.Initial.Text == "S", "Companies without an icon show their initial")
friend:SetAttribute("CompanyIcon", 77)
check(string.find(row.Icon.Image, "id=77", 1, true) ~= nil, "A member publishing the icon updates the row")
for _, member in { player, friend, friend2 } do member:SetAttribute("CompanyNetWorth", 140) end
check(row.NetWorth.Text == "$140" and row.LayoutOrder == 1, "Committed company changes update wealth and ordering")
Players.PlayerRemoving:Fire(player)
check(row.Crew.Text == "2/5" and row.NetWorth.Text == "$140", "Company remains visible while its original creator is offline")
friend:SetAttribute("BoatDataStatus", "Selecting")
check(row.Crew.Text == "1/5", "Members without an active save are not counted as online crew")
friend2:SetAttribute("CompanyName", "New Name")
check(row.CompanyName.Text == "New Name", "Save rename updates the company display")
local newcomer = companyMember(11, "7_1", "New Name", 140)
Players.PlayerAdded:Fire(newcomer)
check(row.Crew.Text == "2/5", "Newly joined members update the existing company row")
for _, member in { friend2, newcomer } do Players.PlayerRemoving:Fire(member) end
check(not panel.Companies:FindFirstChild("7_1"), "Last member leaving removes the company from the local roster")
player:SetAttribute("SaveSelectionRequired", true)
check(not panel.Visible and not gui.Toggle.Visible, "Save selection hides the gameplay leaderboard")
player:SetAttribute("SaveSelectionRequired", false)
check(panel.Visible, "Entering a save restores the leaderboard")
panel.PeopleTab.Activated:Fire()
check(panel.Rows.Visible and not panel.Companies.Visible and panel.Header.Visible, "People tab can be restored")
print("Company leaderboard client: " .. checks .. " shared-wallet, offline-owner and tab checks passed (recording mocks).")
